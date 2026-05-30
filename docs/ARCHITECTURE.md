# Arquitectura

Cusco es un **monorepo** (un solo repositorio que contiene varios proyectos
relacionados) gestionado con **npm workspaces**. Adentro conviven un backend
hecho con **NestJS** (`src/api`) y un frontend hecho con **Angular 21**
(`src/frontend`). Todo se orquesta con **Docker Compose** y se sirve detrás de
**Nginx**. La base de datos es **PostgreSQL**, a la que el backend accede a
través de **Prisma**.

Esta página explica cómo encajan las piezas. Si nunca usaste estas
tecnologías, no te preocupes: cada concepto se introduce brevemente la primera
vez que aparece. Para poner el proyecto en marcha mirá
[DEVELOPMENT.md](DEVELOPMENT.md); para el detalle de los contenedores,
[DOCKER.md](DOCKER.md).

---

## Vista de alto nivel

El navegador nunca habla directo con la API ni con el frontend: siempre pasa
por Nginx, que actúa como **reverse proxy** (un portero que recibe todo el
tráfico y lo deriva al servicio interno correcto). La API, a su vez, depende de
tres servicios de infraestructura.

```
                         ┌──────────────┐
                         │   browser    │
                         └──────┬───────┘
                                │ HTTPS
                         ┌──────▼───────┐
                         │    nginx     │  (mkcert en dev / certs reales en cloud)
                         └──┬───────┬───┘
                            │       │
                       ┌────▼──┐ ┌──▼─────┐
                       │  api  │ │frontend│
                       │NestJS │ │Angular │
                       └─┬───┬─┘ └────────┘
                         │   │
              ┌──────────┘   └──────────┐
              │                         │
        ┌─────▼────┐              ┌─────▼────┐
        │ postgres │              │  redis   │
        │ (prisma) │              │  cache   │
        └──────────┘              └──────────┘
              ▲
              │ (en desarrollo, los emails de prueba van a)
        ┌─────┴────┐
        │ mailhog  │ (dev: captura SMTP y los muestra en una web)
        └──────────┘
```

- **postgres** — la base de datos relacional. Prisma traduce el código
  TypeScript a consultas SQL contra ella.
- **redis** — almacén en memoria usado como **cache** genérico (datos que se
  pueden recalcular y conviene guardar temporalmente para responder más rápido).
- **mailhog** — solo en desarrollo: intercepta los correos que la app intenta
  enviar y los muestra en una interfaz web, así nunca se manda un email real
  durante las pruebas.

El listado completo de servicios, puertos y cómo levantarlos está en
[DOCKER.md](DOCKER.md).

---

## Backend (`src/api/src/`)

El backend usa una **arquitectura por capas** (*layered*), no por features. La
idea es que la pregunta "¿dónde va este archivo?" tenga siempre una respuesta
obvia: cada cosa vive en la capa que le corresponde según su responsabilidad,
no según la pantalla o la funcionalidad a la que sirve.

```
main.ts                       # arranque (bootstrap): prefijo /api/v1, CORS,
                              #   ValidationPipe global y Swagger
app.module.ts                 # módulo raíz: ensambla todo lo demás

core/                         # Infraestructura
  config/constants.ts         #   constantes de la app
  setup/prisma.service.ts     #   conexión a Prisma + ciclo de vida
  core.module.ts              #   @Global, exporta PrismaService

modules/                      # Dominio (un módulo por entidad)
  auth/                       #   autenticación: login JWT + guards + decoradores
  users/                      #   CRUD de usuarios

features/                     # Transversal: concepto/convención para piezas que
                              #   cruzan varios módulos (hoy está vacío)

common/                       # Compartido entre módulos
  dto/pagination.dto.ts       #   DTO de paginación reutilizable
  helpers/pagination.helper.ts
  models/  services/  interfaces/   # convención para código compartido
```

> **¿Qué es un módulo de NestJS?** Es una unidad que agrupa, mediante el
> decorador `@Module({...})`, un conjunto de piezas relacionadas: sus
> *controllers* (puntos de entrada HTTP), sus *providers* (servicios con la
> lógica) y los módulos que importa o exporta. El módulo raíz `AppModule` es el
> que NestJS carga primero y desde ahí va importando el resto.

### Path aliases

Para no escribir rutas relativas frágiles como `../../../core/...`, el backend
define **alias de importación** (atajos que apuntan a una carpeta fija):

```json
{
  "@core/*":    ["src/core/*"],
  "@modules/*": ["src/modules/*"],
  "@common/*":  ["src/common/*"]
}
```

Así, `import { PrismaService } from '@core/setup/prisma.service'` funciona desde
cualquier archivo sin importar su profundidad.

### El arranque: `main.ts`

`main.ts` es el punto donde la aplicación se enciende. Allí se configura, una
sola vez y para toda la app:

- **Prefijo global** `api/v1` — todos los endpoints cuelgan de `/api/v1/...`.
- **CORS** habilitado (`app.enableCors()`), para que el frontend pueda llamar a
  la API desde otro origen.
- **`ValidationPipe` global** con `whitelist: true`, `forbidNonWhitelisted:
  true` y `transform: true` (ver más abajo en *Decisiones de arquitectura*).
- **Swagger** en `/api/docs`: documentación interactiva de la API generada
  automáticamente. El `DocumentBuilder` registra un esquema **Bearer**
  (`addBearerAuth()`) para poder probar endpoints autenticados desde el navegador.
- El puerto se lee de la variable de entorno `API_PORT` (3000 por defecto).

### Estructura de un módulo de dominio

Un módulo de dominio modela una entidad del negocio. Su estructura típica:

```
modules/<name>/
├── <name>.module.ts          # declara controllers y providers del módulo
├── <name>.controller.ts      # endpoints REST (qué URL hace qué)
├── <name>.service.ts         # lógica de negocio (clase @Injectable)
└── dto/
    ├── create-<name>.dto.ts
    └── update-<name>.dto.ts
```

> **¿Qué es un *service* `@Injectable`?** Es una clase decorada con
> `@Injectable()` que contiene la lógica de negocio. NestJS la instancia una
> vez y la **inyecta** (la entrega ya construida) a quien la pida en su
> constructor. A esto se le llama *inyección de dependencias*: no creás los
> objetos a mano, el framework te los provee.

> **¿Qué es un DTO?** *Data Transfer Object*. Es una clase que describe la
> forma de los datos que entran por la API (el cuerpo de un `POST`, por
> ejemplo). Sus propiedades se anotan con decoradores de `class-validator`
> (`@IsEmail()`, `@IsString()`, etc.) y el `ValidationPipe` global los usa para
> rechazar peticiones mal formadas antes de que lleguen al service.

En cusco hay dos módulos de dominio:

- **`auth/`** — login con JWT. Además de los archivos típicos incluye
  `decorators/` (`public.decorator.ts`, `roles.decorator.ts`), `guards/`
  (`jwt-auth.guard.ts`, `roles.guard.ts`) y `strategies/jwt.strategy.ts`.
  No tiene controller CRUD: su único endpoint es `POST /auth/login`, marcado con
  `@Public()`.
- **`users/`** — CRUD de usuarios. Endpoints: `POST /users`, `GET /users`
  (paginado con `?page` y `?limit`), `GET /users/:id`, `PATCH /users/:id` y
  `DELETE /users/:id`. El controller está anotado con `@ApiTags('users')` y
  `@ApiBearerAuth()` para que aparezca correctamente en Swagger; al no llevar
  `@Public()`, los guards globales exigen token válido en todos sus endpoints.

### Autenticación y autorización

El flujo de login (en `auth.service.ts`) es directo:

1. Busca el usuario por email (`usersService.findByEmail`).
2. Compara la contraseña recibida contra el hash guardado con
   `bcrypt.compare`. **bcrypt** es un algoritmo de *hashing* de contraseñas: la
   contraseña nunca se guarda en texto plano, solo su huella irreversible.
3. Si todo coincide, firma un **JWT** (*JSON Web Token*: un token firmado que
   el cliente guarda y reenvía en cada petición) con el payload
   `{ sub, email, role }`.
4. Devuelve `{ access_token, user: { id, email, role } }`.

En las peticiones siguientes, el cliente manda ese token en la cabecera
`Authorization: Bearer <token>`. La `JwtStrategy` lo extrae, verifica firma y
expiración con `JWT_SECRET`, y deja `{ id, email, role }` disponible en
`request.user`.

### Guards globales

Un **guard** es una clase que decide si una petición puede o no llegar al
handler. En cusco, `auth.module.ts` registra **dos guards globales** mediante
el token `APP_GUARD`, de modo que aplican a **toda** la app sin tener que
repetirlos endpoint por endpoint:

```ts
providers: [
  AuthService,
  JwtStrategy,
  { provide: APP_GUARD, useClass: JwtAuthGuard },   // 1.º se ejecuta este
  { provide: APP_GUARD, useClass: RolesGuard },     // 2.º este
],
```

El orden importa: primero corre `JwtAuthGuard` (autenticación: ¿quién sos?) y
después `RolesGuard` (autorización: ¿podés hacer esto?).

1. **`JwtAuthGuard`** (`guards/jwt-auth.guard.ts`) — extiende el guard `jwt` de
   Passport. Por defecto exige un Bearer válido en cada petición; pero primero
   consulta con `Reflector` si el endpoint tiene la metadata de `@Public()` y,
   si la tiene, lo deja pasar sin token.
2. **`RolesGuard`** (`guards/roles.guard.ts`) — lee con `Reflector` la metadata
   que deja `@Roles(...)`. Si el endpoint **no** declara roles, deja pasar; si
   los declara, comprueba que `request.user.role` sea uno de los permitidos y,
   si no, lanza `ForbiddenException`.

Como la autenticación es global, los controllers **no** necesitan `@UseGuards`:
por defecto todo endpoint exige token. Para cambiar ese comportamiento se usan
dos decoradores:

- **`@Public()`** (`decorators/public.decorator.ts`) — marca un endpoint como
  público. Es lo que permite que `POST /auth/login` funcione sin estar logueado.
  Internamente hace `SetMetadata('isPublic', true)`.
- **`@Roles(...rol)`** (`decorators/roles.decorator.ts`) — restringe un endpoint
  (o un controller entero) a uno o más roles del enum `Role`. Sin este
  decorador, basta con estar autenticado.

> No existe un decorador `@CurrentUser`. Para acceder al usuario autenticado se
> lee `request.user`, que la `JwtStrategy` dejó preparado con `{ id, email,
> role }` tras validar el token.

El detalle fino del modelo de roles y quién puede hacer qué está en
[ROLES.md](ROLES.md).

---

## Modelo de datos

La **fuente de verdad** del esquema es `src/api/prisma/schema.prisma`. Cualquier
cambio en la base de datos empieza ahí.

> **¿Qué es Prisma y qué es un modelo Prisma?** Prisma es un **ORM**
> (*Object-Relational Mapper*): una herramienta que te deja describir las tablas
> de la base con sintaxis declarativa y trabajar con ellas como objetos
> TypeScript, sin escribir SQL a mano. Cada `model` en `schema.prisma`
> representa una tabla; cada línea dentro, una columna con su tipo. A partir de
> este archivo, Prisma **genera** un cliente tipado que el `PrismaService`
> expone al resto de la app.

### Mapeo camelCase ↔ snake_case

En el código TypeScript se usa `camelCase` (`firstName`), pero en la base de
datos la convención es `snake_case` (`first_name`). Prisma reconcilia ambos
mundos con dos directivas:

- **`@map("nombre_columna")`** — renombra una columna individual.
- **`@@map("nombre_tabla")`** — renombra la tabla entera.

Así el código queda idiomático en TypeScript y la base queda idiomática en SQL,
sin que tengas que elegir.

### Entidades

El esquema actual es deliberadamente mínimo (es un scaffold): una sola entidad
y un enum.

| Modelo / Enum | Rol                                                                 |
|---------------|---------------------------------------------------------------------|
| `User`        | Identidad de la cuenta: email único, contraseña hasheada, rol y estado |
| `Role` (enum) | Nivel de permisos: `ADMIN` o `USER`                                  |

Campos de `User` (con su mapeo a columnas):

| Campo Prisma | Tipo                | Columna en DB | Notas                              |
|--------------|---------------------|---------------|------------------------------------|
| `id`         | `Int`               | `id`          | `@id @default(autoincrement())`    |
| `email`      | `String`            | `email`       | `@unique`                          |
| `password`   | `String`            | `password`    | hash bcrypt, nunca texto plano     |
| `firstName`  | `String?`           | `first_name`  | opcional (`?`)                     |
| `lastName`   | `String?`           | `last_name`   | opcional                           |
| `role`       | `Role`              | `role`        | `@default(USER)`                   |
| `isActive`   | `Boolean`           | `is_active`   | `@default(true)`                   |
| `createdAt`  | `DateTime`          | `created_at`  | `@default(now())`                  |
| `updatedAt`  | `DateTime`          | `updated_at`  | `@updatedAt` (se actualiza solo)   |

La tabla se llama `users` (`@@map("users")`). Para crear/aplicar migraciones y
cargar datos de ejemplo (`seed.ts`, `seed-admin.ts`) mirá [DEVELOPMENT.md](DEVELOPMENT.md).

---

## Frontend (`src/frontend/src/app/`)

El frontend organiza los componentes con **Atomic Design**: una metodología que
clasifica la UI por nivel de complejidad, desde las piezas más pequeñas hasta
las pantallas completas. La idea es construir de abajo hacia arriba —los
átomos se combinan en moléculas, las moléculas en organismos, etc.— para
maximizar la reutilización.

```
app.config.ts                 # providers: router, HttpClient + interceptors
app.routes.ts                 # rutas con lazy-loading
app.component.ts              # shell de la app + <router-outlet>

atoms/                        # ladrillos básicos: button, input
molecules/                    # composiciones de átomos: card, form-field
organisms/                    # secciones complejas (nivel conceptual)
templates/                    # layouts con slots (nivel conceptual)
pages/                        # una por ruta: home, login

core/                         # infraestructura Angular
  services/                   #   api.service.ts, auth.service.ts
  guards/                     #   auth.guard.ts
  interceptors/               #   auth.interceptor.ts (añade el Bearer)
  models/                     #   user.model.ts (interfaces TypeScript)
  styles/                     #   SCSS global (_variables, _base, _typography, _utilities)

shared/                       # pipes y directivas reutilizables (nivel conceptual)
```

> `organisms/`, `templates/` y `shared/` son **niveles de la metodología** que
> quizá todavía no tengan archivos en el scaffold. Existen como convención: ahí
> es donde irían esos componentes cuando hagan falta.

### Path aliases (frontend)

Igual que el backend, el frontend define atajos de importación:

```json
{
  "@atoms/*":     ["src/app/atoms/*"],
  "@molecules/*": ["src/app/molecules/*"],
  "@pages/*":     ["src/app/pages/*"],
  "@core/*":      ["src/app/core/*"]
}
```

### Componentes standalone y signals

Los componentes son **standalone**: no se agrupan en `NgModule`, sino que cada
uno declara sus propias dependencias en `imports`. Para el estado reactivo se
prefieren **signals** (la API de reactividad moderna de Angular) sobre RxJS
cuando aplica.

Ejemplo real: `atoms/button/button.component.ts` es un componente standalone
con selector `app-button` que importa `NgClass`. Sus *inputs* son `variant`
(`'primary' | 'secondary' | 'outline' | 'danger' | 'ghost'`, por defecto
`'primary'`), `size` (`'sm' | 'md' | 'lg'`, por defecto `'md'`), `disabled`
(`false`) y `type` (`'button' | 'submit' | 'reset'`, por defecto `'button'`).
Emite un *output* `onClick: EventEmitter<Event>`. El texto del botón se pasa
por **proyección de contenido** (`<ng-content/>`), no por un input `label`:

```html
<app-button variant="primary" size="lg">Guardar</app-button>
```

El flujo de desarrollo de componentes en aislamiento se documenta en
[STORYBOOK.md](STORYBOOK.md).

### Rutas y providers

- `app.routes.ts` define rutas con **lazy-loading** (`loadComponent`): el código
  de cada página se descarga solo cuando se navega a ella. Hoy hay `''` (home)
  y `login`, más un comodín `**` que redirige al home.
- `app.config.ts` registra los *providers* globales: el router, `HttpClient` y
  el `authInterceptor` (un **interceptor** que intercepta cada petición HTTP
  saliente para inyectarle la cabecera `Authorization: Bearer`).

---

## Decisiones que sostienen la arquitectura

- **Capas, no feature-folders.** Organizar por capa (`core` ← `modules` ←
  `common`) mantiene la dirección de las dependencias siempre "hacia adentro" y
  evita ciclos de importación. La ubicación de cada archivo es predecible.

- **Validación por DTO + `ValidationPipe` global.** Con `whitelist: true` se
  descartan las propiedades que el DTO no declara; con `forbidNonWhitelisted:
  true` directamente se rechaza la petición si trae campos de más; con
  `transform: true` los datos llegan ya convertidos a sus tipos. Resultado:
  nada que no esté en el DTO llega al service.

- **Autenticación JWT con Bearer.** El estado de sesión vive en un token firmado
  que el cliente reenvía; la API no guarda sesiones en memoria, lo que facilita
  escalar horizontalmente.

- **Guards explícitos por endpoint.** Al no usar `APP_GUARD` global, cada
  controller declara sus reglas con `@UseGuards` y `@Roles`. Es más verboso
  pero más legible: el contrato de seguridad de un endpoint se lee junto al
  endpoint.

- **Swagger desde el código.** La documentación de la API se genera a partir de
  los decoradores (`@ApiTags`, `@ApiBearerAuth`, los DTOs…), así nunca queda
  desactualizada respecto al código real.

---

## Para seguir

- [DEVELOPMENT.md](DEVELOPMENT.md) — instalar dependencias, migraciones, seeds y
  el día a día de desarrollo.
- [DOCKER.md](DOCKER.md) — los servicios, puertos y comandos de Docker Compose.
- [STORYBOOK.md](STORYBOOK.md) — desarrollo de componentes en aislamiento.
- [ROLES.md](ROLES.md) — el modelo de roles y permisos en detalle.
