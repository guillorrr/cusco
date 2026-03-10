# Cusco

Scaffold para proyectos full-stack **Node.js + Angular** con arquitectura limpia, Atomic Design y entorno Dockerizado.

## Stack

| Capa       | Tecnología                              |
|------------|----------------------------------------|
| Backend    | NestJS + TypeScript                    |
| Frontend   | Angular 19 (standalone, signals)       |
| Base datos | PostgreSQL 16 + Prisma ORM             |
| Cache      | Redis 7                                |
| Proxy      | Nginx (SSL con mkcert)                 |
| Email      | Mailhog (testing)                      |
| DB UI      | pgAdmin 4                              |
| Contenedor | Docker Compose                         |
| Monorepo   | npm workspaces                         |

## Arquitectura

El proyecto sigue una **arquitectura por capas** en el backend y **Atomic Design** en el frontend, organizados como monorepo con npm workspaces.

```
cusco/
├── docker/                          # Dockerfiles y configuración
│   ├── api/Dockerfile               # Node 20 Alpine para NestJS
│   ├── frontend/Dockerfile          # Node 20 Alpine + Angular CLI
│   ├── nginx/templates/             # Reverse proxy con SSL
│   ├── db/init/                     # Scripts inicialización PostgreSQL
│   └── mkcert/Dockerfile            # Generación certificados SSL
│
├── src/
│   ├── api/                         # Backend NestJS
│   │   ├── prisma/
│   │   │   ├── schema.prisma        # Modelos de datos (source of truth)
│   │   │   └── seed.ts              # Datos iniciales de desarrollo
│   │   └── src/
│   │       ├── main.ts              # Entry point
│   │       ├── app.module.ts        # Root module
│   │       ├── core/                # Capa de infraestructura
│   │       │   ├── config/          #   Constantes y configuración
│   │       │   ├── setup/           #   PrismaService, conexión a BD
│   │       │   └── plugins/         #   Integraciones con servicios externos
│   │       ├── modules/             # Módulos de dominio (uno por entidad)
│   │       │   ├── auth/            #   Autenticación JWT
│   │       │   └── users/           #   CRUD usuarios
│   │       ├── features/            # Funcionalidades transversales
│   │       └── common/              # Código compartido entre módulos
│   │           ├── dto/             #   Validación de datos de entrada
│   │           ├── helpers/         #   Utilidades
│   │           ├── models/          #   Modelos de datos
│   │           ├── services/        #   Servicios compartidos
│   │           └── interfaces/      #   Interfaces TypeScript
│   │
│   └── frontend/                    # Frontend Angular
│       └── src/app/
│           ├── atoms/               # Elementos básicos (botones, inputs)
│           ├── molecules/           # Combinaciones de atoms (cards, formularios)
│           ├── organisms/           # Secciones complejas (header, footer)
│           ├── templates/           # Layouts de página con slots de contenido
│           ├── pages/               # Componentes por ruta
│           │   ├── home/
│           │   └── login/
│           └── core/                # Infraestructura Angular
│               ├── services/        #   ApiService, AuthService
│               ├── guards/          #   Route guards
│               ├── interceptors/    #   HTTP interceptors (JWT)
│               ├── models/          #   Interfaces TypeScript
│               └── styles/          #   SCSS global (variables, base, tipografía)
│
├── docker-compose.yml               # Orquestación (7 servicios)
├── package.json                     # Root workspace
├── .env.example                     # Variables de entorno
├── .prettierrc                      # Configuración Prettier
├── commitlint.config.js             # Conventional commits
├── .husky/                          # Git hooks
│   ├── pre-commit                   #   lint-staged
│   └── commit-msg                   #   commitlint
├── CLAUDE.md                        # Instrucciones para Claude AI
└── README.md                        # Este archivo
```

### Patrones y principios

- **Layered Architecture** (backend): separación clara entre infraestructura (`core/`), dominio (`modules/`), funcionalidades transversales (`features/`) y código compartido (`common/`)
- **Atomic Design** (frontend): jerarquía de componentes desde los más simples (atoms) hasta páginas completas, promoviendo reutilización y consistencia visual
- **Module-per-feature**: cada entidad de dominio se encapsula en su propio módulo NestJS con controller, service y DTOs
- **DTO validation**: validación de datos de entrada con `class-validator` en los DTOs, aplicada globalmente vía `ValidationPipe`
- **Path aliases**: `@core/*`, `@modules/*`, `@common/*` en el backend; `@atoms/*`, `@molecules/*`, `@pages/*`, `@core/*` en el frontend

## Inicio rápido

### Requisitos

- Docker & Docker Compose
- Node.js >= 20 & npm >= 10 (para scripts de root)

### Setup

```bash
# 1. Configurar entorno
cp .env.example .env

# 2. Instalar dependencias root
npm install

# 3. Levantar servicios
npm start

# 4. Crear base de datos y migrar
npm run prisma:migrate

# 5. Seed de datos iniciales
npm run prisma:seed
```

### URLs de desarrollo

| Servicio | URL |
|---|---|
| Frontend | https://cusco.local (o http://localhost:4200) |
| API | https://cusco.local/api/v1 (o http://localhost:3000/api/v1) |
| Swagger docs | http://localhost:3000/api/docs |
| pgAdmin | http://localhost:8082 |
| Mailhog | http://localhost:8025 |

> Para usar `cusco.local`, añade `127.0.0.1 cusco.local` a tu `/etc/hosts`.

## Comandos disponibles

### Docker

```bash
npm start                    # Levantar servicios
npm stop                     # Parar servicios
npm run dev                  # Levantar + seguir logs api/frontend
npm run logs                 # Ver logs de todos los servicios
npm run logs:api             # Ver logs del API
npm run logs:frontend        # Ver logs del frontend
npm run docker:rebuild       # Reconstruir todo desde cero
npm run docker:clean         # Eliminar todo (volúmenes incluidos)
npm run docker:status        # Estado de los servicios
```

### Base de datos (Prisma)

```bash
npm run prisma:migrate       # Ejecutar migraciones pendientes
npm run prisma:generate      # Regenerar Prisma Client
npm run prisma:seed          # Cargar datos de ejemplo
npm run prisma:reset         # Reset completo de la base de datos
npm run prisma:studio        # Editor visual de base de datos
npm run db:backup            # Backup de la base de datos
npm run db:shell             # Consola PostgreSQL
```

### Calidad de código

```bash
npm run lint                 # Lint api + frontend
npm run lint:fix             # Auto-fix lint errors
npm run prettier             # Check formatting
npm run prettier:write       # Auto-format
npm test                     # Tests api + frontend
npm run test:e2e             # Tests end-to-end
```

### Shells

```bash
npm run api:shell            # Shell dentro del contenedor API
npm run frontend:shell       # Shell dentro del contenedor Frontend
npm run db:shell             # Consola PostgreSQL
```

## Cómo extender

### Crear un nuevo módulo de dominio

Cada entidad de negocio se modela como un módulo NestJS autocontenido:

```bash
# 1. Generar módulo NestJS completo (controller + service + DTOs + tests)
docker compose exec api npx nest g resource modules/products

# 2. Añadir modelo en prisma/schema.prisma
model Product {
  id          Int      @id @default(autoincrement())
  name        String
  slug        String   @unique
  description String?
  price       Decimal  @db.Decimal(10, 2)
  isActive    Boolean  @default(true) @map("is_active")
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  @@map("products")
}

# 3. Migrar
npm run prisma:migrate

# 4. Importar el módulo en app.module.ts
```

### Crear componentes Angular (Atomic Design)

Los componentes se organizan por nivel de complejidad:

```bash
# Atom — elemento básico reutilizable
docker compose exec frontend npx ng g c atoms/button --standalone

# Molecule — combinación de atoms
docker compose exec frontend npx ng g c molecules/card --standalone

# Organism — sección compleja de UI
docker compose exec frontend npx ng g c organisms/header --standalone

# Page — componente a nivel de ruta
docker compose exec frontend npx ng g c pages/products --standalone
# Luego añadir la ruta en app.routes.ts (lazy-loaded)
```

### Crear un servicio Angular

```bash
docker compose exec frontend npx ng g s core/services/products
```

## Convenciones

### Commits

Conventional Commits obligatorio (validado por Husky + commitlint):

```
feat(users): add user profile endpoint
fix(auth): handle expired refresh tokens
refactor(api): extract pagination logic to helper
chore(docker): update Node image to v20
docs(readme): add deployment instructions
test(users): add unit tests for users service
```

### Estructura de un módulo NestJS

Cada módulo sigue esta estructura estándar:

```
modules/{name}/
├── {name}.module.ts         # Declaración del módulo
├── {name}.controller.ts     # Endpoints REST
├── {name}.service.ts        # Lógica de negocio
└── dto/
    ├── create-{name}.dto.ts # Validación para crear
    └── update-{name}.dto.ts # Validación para actualizar
```

### API REST

- Prefijo global: `/api/v1`
- Swagger auto-generado en `/api/docs`
- Validación: `class-validator` + `ValidationPipe` global
- Auth: JWT Bearer token vía header `Authorization`
- Paginación: `?page=1&limit=10` en todos los listados
