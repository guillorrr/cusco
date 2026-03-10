# Cusco — Project Instructions for Claude

## Project Overview

Cusco is a production-ready monorepo scaffold for full-stack TypeScript applications. It provides a NestJS backend, Angular frontend, PostgreSQL + Prisma ORM, and Docker orchestration following clean architecture and Atomic Design principles.

## Tech Stack

- **Backend**: NestJS (TypeScript) — `src/api/`
- **Frontend**: Angular 19 (standalone components, signals) — `src/frontend/`
- **Database**: PostgreSQL 16 + Prisma ORM
- **Cache**: Redis 7
- **Containerization**: Docker Compose (7 services)
- **Package Management**: npm workspaces (root + api + frontend)

## Architecture

The project follows a layered architecture with clear separation of concerns.

### Backend (`src/api/src/`)

```
core/           → Infrastructure layer
  config/       → App constants and configuration
  setup/        → PrismaService, database connection
  plugins/      → Third-party service integrations
modules/        → Domain modules, each self-contained (one per entity/domain)
  auth/         → Authentication (JWT + Passport)
  users/        → Users CRUD
features/       → Cross-cutting concerns (logging, caching, notifications)
common/         → Shared code across modules
  dto/          → Data Transfer Objects (input validation)
  helpers/      → Utility functions
  models/       → Data models
  services/     → Shared services
  interfaces/   → TypeScript interfaces
```

### Frontend (`src/frontend/src/app/`)

Follows [Atomic Design](https://bradfrost.com/blog/post/atomic-web-design/) methodology:

```
atoms/          → Basic UI elements (buttons, inputs, labels)
molecules/      → Combinations of atoms (cards, form groups, search bars)
organisms/      → Complex UI sections (header, footer, sidebars)
templates/      → Page layouts with content slots
pages/          → Route-level components (one per route)
core/           → App infrastructure
  services/     → API service, auth service
  guards/       → Route guards
  interceptors/ → HTTP interceptors
  models/       → TypeScript interfaces
  styles/       → Global SCSS (variables, base, typography)
shared/         → Shared pipes, directives
```

## Conventions

### Naming

- **Modules**: PascalCase for classes, kebab-case for files (`users.service.ts`)
- **DTOs**: `create-{entity}.dto.ts`, `update-{entity}.dto.ts`
- **Components**: kebab-case (`home.component.ts`)
- **SCSS**: `_partial.scss` for imports, variables prefix with `$`

### Code Style

- Strict TypeScript (`strictNullChecks`, `noImplicitAny`)
- Prettier + ESLint enforced via pre-commit hooks
- Conventional commits: `type(scope): message`
  - Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`, `perf`, `ci`, `build`
- Angular: standalone components, signals over RxJS where possible
- NestJS: dependency injection, decorators, class-validator for DTOs

### Adding a New Domain Module

1. Generate: `npx nest g resource modules/{name}`
2. Add Prisma model in `prisma/schema.prisma`
3. Run: `npx prisma migrate dev --name add-{name}`
4. Import module in `app.module.ts`

### Adding a New Angular Page

1. Create component in `src/frontend/src/app/pages/{name}/`
2. Add route in `app.routes.ts` (lazy-loaded)
3. Compose from atoms → molecules → organisms following Atomic Design

## Key Commands

```bash
npm start                   # docker compose up
npm run dev                 # start + follow logs
npm run prisma:migrate      # run database migrations
npm run prisma:seed         # seed initial data
npm run prisma:studio       # visual DB editor
npm run lint                # lint both api + frontend
npm run test                # test both api + frontend
npm run build               # production build
npm run docker:rebuild      # full rebuild from scratch
```

## API

- Base URL: `/api/v1`
- Swagger docs: `/api/docs`
- Auth: JWT Bearer token via `Authorization` header

## Docker Services

| Service    | Port  | Purpose            |
|------------|-------|--------------------|
| api        | 3000  | NestJS backend     |
| frontend   | 4200  | Angular dev server |
| nginx      | 80/443| Reverse proxy      |
| db         | 5432  | PostgreSQL         |
| redis      | 6379  | Cache              |
| pgadmin    | 8082  | Database UI        |
| mailhog    | 8025  | Email testing      |

## Important Files

- `docker-compose.yml` — Service orchestration
- `.env.example` — Environment template (copy to `.env`)
- `src/api/prisma/schema.prisma` — Database schema (source of truth)
- `src/api/src/app.module.ts` — Backend root module
- `src/frontend/src/app/app.routes.ts` — Frontend routing
- `src/frontend/src/app/app.config.ts` — Angular providers
