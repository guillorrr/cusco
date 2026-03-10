import { Global, Module } from '@nestjs/common';
import { PrismaService } from './setup/prisma.service';

/**
 * Core module — provides infrastructure services globally
 *
 * Services registered here are available across all modules:
 *   PrismaService  → database connection and query client
 *   ConfigModule   → environment variables and app configuration
 */
@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class CoreModule {}
