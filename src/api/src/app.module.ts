import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CoreModule } from './core/core.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';

/**
 * Root module — application entry point
 *
 * Layered architecture:
 *   core/      → Infrastructure (config, database, integrations)
 *   modules/   → Domain modules (one per entity/feature)
 *   features/  → Cross-cutting concerns
 *   common/    → Shared code (DTOs, helpers, models)
 */
@Module({
  imports: [
    // Global configuration from .env
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', '../../.env'],
    }),

    // Infrastructure
    CoreModule,

    // Domain modules
    AuthModule,
    UsersModule,
  ],
})
export class AppModule {}
