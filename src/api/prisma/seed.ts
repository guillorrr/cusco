import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

/**
 * Database seeder — populates initial development data
 */
async function main() {
  const hashedPassword = await bcrypt.hash('admin123', 10);

  await prisma.user.upsert({
    where: { email: 'admin@cusco.local' },
    update: {},
    create: {
      email: 'admin@cusco.local',
      password: hashedPassword,
      firstName: 'Admin',
      lastName: 'Cusco',
      role: Role.ADMIN,
    },
  });

  console.log('Seed completed');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
