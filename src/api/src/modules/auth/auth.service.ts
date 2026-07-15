import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { createHash, randomBytes } from 'crypto';
import * as bcrypt from 'bcryptjs';
import { UsersService } from '../users/users.service';
import { PrismaService } from '../../core/setup/prisma.service';
import { APP_CONSTANTS } from '../../core/config/constants';
import { parseDuration } from '../../common/helpers/duration.helper';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';

/** Bytes of entropy per refresh token. */
const REFRESH_TOKEN_BYTES = 64;

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async login(dto: LoginDto) {
    const user = await this.usersService.findByEmail(dto.email);
    if (!user || !(await bcrypt.compare(dto.password, user.password))) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return this.issueTokens(user);
  }

  /**
   * Rotates a refresh token: the presented token is revoked and a brand new
   * pair is issued. A token is therefore valid exactly once.
   */
  async refresh(dto: RefreshTokenDto) {
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: this.hashToken(dto.refresh_token) },
      include: { user: true },
    });

    if (!stored) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    // A revoked token coming back means someone is replaying a token that was
    // already rotated — the legitimate client would have moved on to the new
    // one. We cannot tell attacker from victim, so we drop the whole family and
    // force a fresh login.
    if (stored.revokedAt) {
      await this.revokeAllForUser(stored.userId);
      throw new UnauthorizedException('Refresh token reuse detected');
    }

    if (stored.expiresAt.getTime() <= Date.now()) {
      throw new UnauthorizedException('Refresh token expired');
    }

    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });

    return this.issueTokens(stored.user);
  }

  /**
   * Revokes a refresh token. Idempotent: unknown or already revoked tokens are
   * a no-op, so a client can always log out without leaking whether the token
   * existed.
   */
  async logout(dto: RefreshTokenDto): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: this.hashToken(dto.refresh_token), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  me(userId: number) {
    return this.usersService.findOne(userId);
  }

  private async issueTokens(user: { id: number; email: string; role: Role }) {
    const refreshToken = randomBytes(REFRESH_TOKEN_BYTES).toString('hex');

    await this.prisma.refreshToken.create({
      data: {
        tokenHash: this.hashToken(refreshToken),
        userId: user.id,
        expiresAt: new Date(
          Date.now() + parseDuration(APP_CONSTANTS.AUTH.REFRESH_TOKEN_EXPIRATION),
        ),
      },
    });

    return {
      access_token: this.jwtService.sign({ sub: user.id, email: user.email, role: user.role }),
      refresh_token: refreshToken,
      user: { id: user.id, email: user.email, role: user.role },
    };
  }

  private revokeAllForUser(userId: number) {
    return this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /** Only the hash is ever stored, so a database leak yields no usable tokens. */
  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}
