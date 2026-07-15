# Roles y control de acceso (RBAC)

Este documento explica cómo Cusco controla **quién puede hacer qué** en el backend. Está
escrito para alguien que nunca usó NestJS: primero los conceptos, después el código real.

> **Importante: esto es scaffolding de ejemplo.** Los módulos `auth` y `users` que se
> describen acá vienen incluidos como **muestra** del patrón. El script
> `npm run clean:scaffolding` (`scripts/clean-scaffolding.sh`) los elimina cuando arrancás
> tu propio proyecto a partir de Cusco. Lo que queda como referencia es el **patrón RBAC**:
> el enum de roles, los guards y los decoradores, para que lo reimplementes sobre el dominio
> real de tu fork.

---

## Conceptos básicos

- **JWT (JSON Web Token).** Es una credencial firmada que el cliente manda en cada pedido,
  en el header `Authorization: Bearer <token>`. Adentro lleva información (en Cusco: el id,
  el email y el rol del usuario). Como está firmado con un secreto del servidor
  (`JWT_SECRET`), nadie puede falsificarlo sin conocer ese secreto.
- **RBAC (Role-Based Access Control).** "Control de acceso basado en roles": en vez de
  decidir permiso por permiso, a cada usuario le asignás un **rol** y los permisos se
  derivan del rol. Cusco tiene dos roles: `ADMIN` y `USER`.
- **Guard.** En NestJS, un guard es una clase que se ejecuta **antes** del handler de una
  ruta y decide si el pedido puede pasar (`true`) o se rechaza. Es el portero de cada
  endpoint.
- **Decorador.** Es una anotación que ponés arriba de una clase o método (empieza con `@`)
  para agregarle metadata o comportamiento. Cusco usa decoradores como `@Public()` y
  `@Roles(...)` para marcar cómo se protege cada endpoint.

---

## Modelo de roles

El rol vive en la base de datos como un campo del usuario. Este es el snippet real de
`src/api/prisma/schema.prisma`:

```prisma
model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  password  String
  firstName String?  @map("first_name")
  lastName  String?  @map("last_name")
  role      Role     @default(USER)
  isActive  Boolean  @default(true) @map("is_active")
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  @@map("users")
}

enum Role {
  ADMIN
  USER
}
```

- `role` define el rol del usuario. Por defecto un usuario nuevo es `USER`.
- `isActive` es un flag pensado para habilitar/deshabilitar cuentas. **Ojo:** en el
  scaffolding actual este campo existe pero **el código todavía no lo chequea** en login ni
  en los guards. Si lo necesitás, sos vos quien tiene que agregar la validación (ver
  [Cómo extender](#cómo-extender-el-control-de-acceso) abajo).

---

## Cómo se firma y se lee el token

### Al loguearse (`auth.service.ts`)

`AuthService.login` busca el usuario por email, compara la contraseña con bcrypt y, si todo
está bien, firma un JWT con `{ sub, email, role }` y lo devuelve junto a un refresh token:

```ts
return {
  access_token: this.jwtService.sign({ sub: user.id, email: user.email, role: user.role }),
  refresh_token: refreshToken,
  user: { id: user.id, email: user.email, role: user.role },
};
```

El rol queda **dentro** del token. Eso significa que el rol viaja con el token hasta que el
token expire.

El `refresh_token` es lo que permite renovar el access token cuando expira, sin volver a
pedir la contraseña. Cómo funciona la rotación y qué pasa si te roban uno está en
[auth-refresh-tokens.md](auth-refresh-tokens.md).

### Al validar cada request (`strategies/jwt.strategy.ts`)

Cuando llega un pedido con un Bearer token, la `JwtStrategy` lo verifica con el `JWT_SECRET`
y, si la firma y la expiración son válidas, devuelve un objeto que NestJS pega en
`request.user`:

```ts
async validate(payload: { sub: number; email: string; role: string }) {
  return { id: payload.sub, email: payload.email, role: payload.role };
}
```

Punto clave a entender: la estrategia **NO vuelve a leer el usuario de la base de datos**.
Confía en lo que dice el token. Consecuencia práctica: si a un usuario le cambiás el rol en
la DB, su token actual **sigue teniendo el rol viejo** hasta que expire y se loguee de
nuevo. Si necesitás que un cambio de rol o un `isActive=false` corte el acceso al instante,
tenés que modificar `JwtStrategy.validate` para que relea el `User` de la DB en cada
request.

### Cómo obtener el usuario en un handler

Usá el decorador `@CurrentUser`, que lee el usuario del request —que es donde Passport lo
dejó— y te lo entrega tipado:

```ts
import { AuthenticatedUser, CurrentUser } from '../auth/decorators/current-user.decorator';

@Get('algo')
hacerAlgo(@CurrentUser() user: AuthenticatedUser) {
  // user: { id, email, role }
}
```

Es azúcar sobre `@Req() req` + `req.user`: no hace ninguna consulta extra ni valida nada,
eso ya lo hizo el `JwtAuthGuard` antes de llegar al handler.

---

## Los guards globales

Cusco registra **dos guards de forma global** usando `APP_GUARD` en
`src/api/src/modules/auth/auth.module.ts`. "Global" quiere decir que se aplican a **todos**
los endpoints de la app automáticamente, sin tener que decorarlos uno por uno:

```ts
providers: [
  AuthService,
  JwtStrategy,
  { provide: APP_GUARD, useClass: JwtAuthGuard },
  { provide: APP_GUARD, useClass: RolesGuard },
],
```

### 1. `JwtAuthGuard` (`guards/jwt-auth.guard.ts`)

Exige un Bearer token válido en **todos** los endpoints, **salvo** los marcados con
`@Public()`. Por dentro mira la metadata `IS_PUBLIC_KEY`: si está, deja pasar sin pedir
token; si no, delega en la estrategia JWT de Passport.

```ts
const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
  context.getHandler(),
  context.getClass(),
]);
if (isPublic) {
  return true;
}
return super.canActivate(context);
```

### 2. `RolesGuard` (`guards/roles.guard.ts`)

Corre después del anterior. Mira si el endpoint (o su controller) tiene `@Roles(...)`:

- Si **no** hay `@Roles`, deja pasar (cualquier usuario autenticado puede entrar).
- Si **sí** hay `@Roles`, exige que el rol del usuario esté en la lista; si no, tira
  `403 Forbidden` (`Insufficient role`).

```ts
const requiredRoles = this.reflector.getAllAndOverride<Role[] | undefined>(ROLES_KEY, [
  context.getHandler(),
  context.getClass(),
]);
if (!requiredRoles || requiredRoles.length === 0) {
  return true;
}
const { user } = context.switchToHttp().getRequest<{ user?: { role?: Role } }>();
if (!user?.role || !requiredRoles.includes(user.role)) {
  throw new ForbiddenException('Insufficient role');
}
return true;
```

**Resumen del comportamiento por defecto:** todo endpoint pide login (JWT válido). Para
abrir uno al público usás `@Public()`; para restringir uno a ciertos roles usás `@Roles(...)`.

---

## Los decoradores disponibles

Cusco trae **dos** decoradores propios para el control de acceso. (No existe `@CurrentUser`.)

### `@Public()` — `decorators/public.decorator.ts`

```ts
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
```

Marca un endpoint como abierto: el `JwtAuthGuard` lo deja pasar sin token. Típico para el
login o un health check.

### `@Roles(...)` — `decorators/roles.decorator.ts`

```ts
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
```

Declara qué roles pueden acceder. Acepta uno o varios:

```ts
@Roles(Role.ADMIN)              // solo admin
@Roles(Role.ADMIN, Role.USER)   // cualquiera de esos dos
```

---

## Patrón de uso

### Restringir un endpoint a admins

```ts
import { Controller, Get } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../auth/decorators/roles.decorator';

@Controller('reportes')
export class ReportesController {
  @Roles(Role.ADMIN)
  @Get()
  soloAdmin() {
    return 'visible solo para admins';
  }
}
```

Como los guards son globales, no hace falta agregar `@UseGuards(...)`: con poner `@Roles`
alcanza. También podés decorar **la clase entera** para que aplique a todos sus métodos:

```ts
@Roles(Role.ADMIN)
@Controller('reportes')
export class ReportesController { /* todos los endpoints exigen ADMIN */ }
```

### Abrir un endpoint al público

```ts
import { Controller, Post } from '@nestjs/common';
import { Public } from '../auth/decorators/public.decorator';

@Controller('auth')
export class AuthController {
  @Public()
  @Post('login')
  login(/* ... */) { /* accesible sin token */ }
}
```

### Cómo está protegido el `users` de ejemplo

El `users.controller` del scaffolding **no** usa `@Roles` ni `@Public`. Por lo tanto, gracias
a los guards globales, todos sus endpoints (`POST /users`, `GET /users`, `GET /users/:id`,
`PATCH /users/:id`, `DELETE /users/:id`) requieren simplemente **un JWT válido**, sin exigir
rol específico. Tampoco hay endpoint `/me` ni protecciones de "no podés borrarte a vos
mismo": es deliberadamente mínimo, como punto de partida. Si querés que ese CRUD sea solo
para admins, agregale `@Roles(Role.ADMIN)` a la clase del controller.

---

## Bootstrap del primer admin

Como un usuario nuevo nace con rol `USER`, necesitás una forma de crear el **primer** admin.
Cusco trae un seed para eso: `src/api/prisma/seed-admin.ts`, que se corre con:

```bash
npm run prisma:seed:admin
```

Qué hace, según el código real:

- Lee `ADMIN_EMAIL` (default `admin@cusco.local`) y `ADMIN_PASSWORD` del entorno (`.env`).
- Si `ADMIN_PASSWORD` está seteado, usa ese valor. Si está vacío, **genera un password
  aleatorio de 20 caracteres y lo imprime una sola vez** por consola. Guardalo en ese
  momento: el password no queda almacenado en texto plano en ningún lado (solo el hash
  bcrypt), así que no se puede recuperar después.
- Crea el usuario con `role: ADMIN`.
- Es **idempotente**: si el usuario con ese email ya existe, **no toca nada** (ni el
  password), solo informa que ya estaba. Correrlo de nuevo es seguro.

Por dentro corre `docker compose exec api npx ts-node prisma/seed-admin.ts`. En producción
se ejecuta una sola vez, dentro del contenedor/pod del API, en el primer deploy.

> En entornos reales, definí `ADMIN_EMAIL`/`ADMIN_PASSWORD` en tu `.env` antes de sembrar (o
> dejá `ADMIN_PASSWORD` vacío y anotá el password generado). No uses el email por defecto en
> prod.

---

## Cómo extender el control de acceso

Para agregar control de acceso a un módulo nuevo de tu dominio:

1. **Protegé los endpoints.** Por defecto ya piden JWT (guards globales). Agregá
   `@Roles(Role.ADMIN)` donde quieras restringir por rol, o `@Public()` donde quieras abrir.
2. **Obtené el usuario** del request con `@Req() req` y `req.user` (`{ id, email, role }`).
3. **Si necesitás más roles**, agregalos al `enum Role` en `schema.prisma` y corré una
   migración (`npm run prisma:migrate`). El `RolesGuard` y `@Roles` ya soportan cualquier
   valor del enum.
4. **Si necesitás revocación inmediata** (que un cambio de rol o un `isActive=false` corte el
   acceso sin esperar a que expire el token), modificá `JwtStrategy.validate` para releer el
   `User` de la base en cada request y rechazar si la cuenta está inactiva o el rol cambió.
   Hoy la estrategia confía solo en el contenido del token.

Para el contexto general de la arquitectura del backend y dónde encaja el módulo `auth`,
mirá [ARCHITECTURE.md](ARCHITECTURE.md). Para el flujo de desarrollo, [DEVELOPMENT.md](DEVELOPMENT.md).
