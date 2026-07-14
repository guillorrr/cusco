import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import * as crypto from 'crypto';

/**
 * Idempotent admin seed.
 *
 * Reads ADMIN_EMAIL (default 'admin@cusco.local') and ADMIN_PASSWORD from env.
 *   · If ADMIN_PASSWORD is set, that value is used.
 *   · If it's empty, a random 20-char password is generated and printed ONCE.
 *
 * Re-running is safe: if the admin user already exists, this script does NOT
 * touch its password. Once stored, the bcrypt hash cannot be recovered — reset
 * manually if it's lost.
 *
 * Usage:
 *   Local / dev   → npm run prisma:seed:admin
 *                   (equivalent: docker compose exec api npx ts-node prisma/seed-admin.ts)
 *   Production    → inside the API container/pod, ONCE on first deploy:
 *                     npx ts-node prisma/seed-admin.ts
 *                   Requires DATABASE_URL to point at the target database.
 *                   Capture the printed password immediately — it is not stored
 *                   in plaintext anywhere.
 */

const DEFAULT_EMAIL = 'admin@cusco.local';

const PASSWORD_CHARSET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
const PASSWORD_LENGTH = 20;
const BCRYPT_ROUNDS = 10;

function generatePassword(): string {
  const chars: string[] = [];
  for (let i = 0; i < PASSWORD_LENGTH; i++) {
    chars.push(PASSWORD_CHARSET[crypto.randomInt(PASSWORD_CHARSET.length)]);
  }
  return chars.join('');
}

async function main(): Promise<void> {
  const email = (process.env.ADMIN_EMAIL || DEFAULT_EMAIL).trim();
  const providedPassword = (process.env.ADMIN_PASSWORD || '').trim();

  const prisma = new PrismaClient();
  try {
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      printSkipped(email, existing.role);
      return;
    }

    const password = providedPassword || generatePassword();
    const hashed = await bcrypt.hash(password, BCRYPT_ROUNDS);

    await prisma.user.create({
      data: {
        email,
        password: hashed,
        firstName: 'Admin',
        lastName: 'User',
        role: Role.ADMIN,
      },
    });

    printCreated(email, password, !providedPassword);
  } finally {
    await prisma.$disconnect();
  }
}

function printSkipped(email: string, role: string): void {
  const sep = '─'.repeat(80);
  console.log();
  console.log(sep);
  console.log('Admin seed — nothing to do');
  console.log(sep);
  console.log(`Admin user already exists: ${email}  (${role})`);
  console.log('Password cannot be recovered. Reset it manually if it was lost.');
  console.log(sep);
}

function printCreated(email: string, password: string, generated: boolean): void {
  const sep = '─'.repeat(80);
  console.log();
  console.log(sep);
  console.log('Admin seed — created');
  console.log(sep);
  console.log(`Email:    ${email}`);
  console.log(`Password: ${password}`);
  console.log(`Source:   ${generated ? 'generated (random)' : 'ADMIN_PASSWORD env var'}`);
  console.log();
  if (generated) {
    console.log(
      'SAVE THIS PASSWORD NOW — it is not stored in plaintext and will not be shown again.',
    );
  }
  console.log(sep);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
