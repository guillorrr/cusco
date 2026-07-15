import { Test } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { createHash } from 'crypto';
import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { PrismaService } from '../../core/setup/prisma.service';

const PASSWORD = 'secret123';

const user = {
  id: 42,
  email: 'demo@example.local',
  password: bcrypt.hashSync(PASSWORD, 4),
  role: Role.USER,
};

const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

const hoursFromNow = (hours: number) => new Date(Date.now() + hours * 60 * 60 * 1000);

describe('AuthService', () => {
  let service: AuthService;

  const usersMock = { findByEmail: jest.fn(), findOne: jest.fn() };
  const jwtMock = { sign: jest.fn().mockReturnValue('signed.jwt.token') };
  const prismaMock = {
    refreshToken: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    jwtMock.sign.mockReturnValue('signed.jwt.token');
    prismaMock.refreshToken.create.mockResolvedValue({});
    prismaMock.refreshToken.update.mockResolvedValue({});
    prismaMock.refreshToken.updateMany.mockResolvedValue({ count: 0 });

    const mod = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: usersMock },
        { provide: JwtService, useValue: jwtMock },
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();
    service = mod.get(AuthService);
  });

  describe('login', () => {
    it('returns an access/refresh pair for valid credentials', async () => {
      usersMock.findByEmail.mockResolvedValue(user);

      const result = await service.login({ email: user.email, password: PASSWORD });

      expect(result.access_token).toBe('signed.jwt.token');
      expect(result.refresh_token).toEqual(expect.any(String));
      expect(result.user).toEqual({ id: user.id, email: user.email, role: Role.USER });
      expect(jwtMock.sign).toHaveBeenCalledWith({
        sub: user.id,
        email: user.email,
        role: Role.USER,
      });
    });

    it('persists only the sha256 hash, never the token itself', async () => {
      usersMock.findByEmail.mockResolvedValue(user);

      const result = await service.login({ email: user.email, password: PASSWORD });

      const { data } = prismaMock.refreshToken.create.mock.calls[0][0];
      expect(data.tokenHash).toBe(sha256(result.refresh_token));
      expect(data.tokenHash).not.toBe(result.refresh_token);
      expect(data.userId).toBe(user.id);
      expect(data.expiresAt.getTime()).toBeGreaterThan(Date.now());
    });

    it('rejects a wrong password', async () => {
      usersMock.findByEmail.mockResolvedValue(user);

      await expect(service.login({ email: user.email, password: 'wrong' })).rejects.toThrow(
        UnauthorizedException,
      );
      expect(prismaMock.refreshToken.create).not.toHaveBeenCalled();
    });

    it('rejects an unknown email', async () => {
      usersMock.findByEmail.mockResolvedValue(null);

      await expect(
        service.login({ email: 'nobody@example.local', password: PASSWORD }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('refresh', () => {
    it('rotates the token: revokes the presented one and issues a new pair', async () => {
      prismaMock.refreshToken.findUnique.mockResolvedValue({
        id: 7,
        userId: user.id,
        tokenHash: sha256('current'),
        revokedAt: null,
        expiresAt: hoursFromNow(24),
        user,
      });

      const result = await service.refresh({ refresh_token: 'current' });

      // Looked up by hash, never by the raw token.
      expect(prismaMock.refreshToken.findUnique).toHaveBeenCalledWith({
        where: { tokenHash: sha256('current') },
        include: { user: true },
      });
      // Old token revoked...
      expect(prismaMock.refreshToken.update).toHaveBeenCalledWith({
        where: { id: 7 },
        data: { revokedAt: expect.any(Date) },
      });
      // ...and a different one handed back.
      expect(prismaMock.refreshToken.create).toHaveBeenCalledTimes(1);
      expect(result.refresh_token).not.toBe('current');
      expect(result.access_token).toBe('signed.jwt.token');
    });

    it('rejects an unknown token', async () => {
      prismaMock.refreshToken.findUnique.mockResolvedValue(null);

      await expect(service.refresh({ refresh_token: 'nope' })).rejects.toThrow(
        UnauthorizedException,
      );
      expect(prismaMock.refreshToken.create).not.toHaveBeenCalled();
    });

    it('rejects an expired token without revoking the family', async () => {
      prismaMock.refreshToken.findUnique.mockResolvedValue({
        id: 9,
        userId: user.id,
        revokedAt: null,
        expiresAt: hoursFromNow(-1),
        user,
      });

      await expect(service.refresh({ refresh_token: 'stale' })).rejects.toThrow(
        UnauthorizedException,
      );
      expect(prismaMock.refreshToken.updateMany).not.toHaveBeenCalled();
      expect(prismaMock.refreshToken.create).not.toHaveBeenCalled();
    });

    // The reason rotation is worth the trouble: a replayed token is evidence
    // that a token leaked, so the whole family goes.
    it('revokes every live token of the user when a revoked token is replayed', async () => {
      prismaMock.refreshToken.findUnique.mockResolvedValue({
        id: 3,
        userId: user.id,
        revokedAt: new Date('2026-01-01T00:00:00Z'),
        expiresAt: hoursFromNow(24),
        user,
      });

      await expect(service.refresh({ refresh_token: 'stolen' })).rejects.toThrow(
        UnauthorizedException,
      );

      expect(prismaMock.refreshToken.updateMany).toHaveBeenCalledWith({
        where: { userId: user.id, revokedAt: null },
        data: { revokedAt: expect.any(Date) },
      });
      // No new pair for the attacker, and the victim is logged out too.
      expect(prismaMock.refreshToken.create).not.toHaveBeenCalled();
    });

    it('still refuses a replayed token that is also expired', async () => {
      prismaMock.refreshToken.findUnique.mockResolvedValue({
        id: 4,
        userId: user.id,
        revokedAt: new Date('2026-01-01T00:00:00Z'),
        expiresAt: hoursFromNow(-1),
        user,
      });

      await expect(service.refresh({ refresh_token: 'stolen-and-stale' })).rejects.toThrow(
        UnauthorizedException,
      );
      expect(prismaMock.refreshToken.updateMany).toHaveBeenCalled();
    });
  });

  describe('logout', () => {
    it('revokes the token by hash', async () => {
      await service.logout({ refresh_token: 'current' });

      expect(prismaMock.refreshToken.updateMany).toHaveBeenCalledWith({
        where: { tokenHash: sha256('current'), revokedAt: null },
        data: { revokedAt: expect.any(Date) },
      });
    });

    it('is idempotent: an unknown token resolves without throwing', async () => {
      prismaMock.refreshToken.updateMany.mockResolvedValue({ count: 0 });

      await expect(service.logout({ refresh_token: 'never-existed' })).resolves.toBeUndefined();
    });
  });

  describe('me', () => {
    it('returns the user behind the access token', async () => {
      const profile = { id: user.id, email: user.email, role: Role.USER };
      usersMock.findOne.mockResolvedValue(profile);

      await expect(service.me(user.id)).resolves.toEqual(profile);
      expect(usersMock.findOne).toHaveBeenCalledWith(user.id);
    });
  });
});
