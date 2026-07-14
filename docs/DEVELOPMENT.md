# Desarrollo local

Esta guía te lleva de cero a tener el proyecto corriendo en tu máquina, y después
te muestra los comandos del día a día. Está pensada para alguien que nunca usó
NestJS, Prisma ni Angular: cuando aparece un concepto nuevo lo explicamos en una
línea.

> Idea clave: **todo el código corre adentro de Docker**. Tu máquina (el "host")
> sólo necesita Docker y Node para ejecutar los scripts del root (`npm start`,
> `npm run prisma:*`, etc.). No instalás NestJS ni Angular a mano.

Para entender qué hace cada contenedor, mirá [DOCKER.md](DOCKER.md). Para la
estructura del código, [ARCHITECTURE.md](ARCHITECTURE.md).

## Requisitos

- **Docker** y **Docker Compose** (Docker Desktop o equivalente).
- **Node.js ≥ 20** y **npm ≥ 10** — sólo para los scripts del root (Husky,
  lint-staged, commitlint y los wrappers `npm run ...`). El código de `src/api` y
  `src/frontend` se compila adentro de cada contenedor.
- **mkcert** NO hace falta instalarlo en el host: hay un servicio Docker `mkcert`
  que genera el certificado local automáticamente. Sólo necesitás editar
  `/etc/hosts` si querés usar `https://cusco.local` (ver abajo).

## Primer arranque

Cuatro comandos y la app queda funcionando:

```bash
cp .env.example .env
npm install
npm start
npm run prisma:migrate
npm run prisma:seed
```

Paso a paso:

1. **`cp .env.example .env`** — copia la plantilla de variables de entorno a un
   archivo `.env` real (que Docker Compose lee). Para desarrollo no hace falta
   cambiar nada: los valores por defecto funcionan.
2. **`npm install`** — instala sólo las herramientas del root (Husky para los git
   hooks, lint-staged, commitlint, prettier). Las dependencias de la API y del
   frontend se instalan dentro de cada contenedor cuando levantan por primera vez.
3. **`npm start`** — `docker compose up -d`: levanta los 8 servicios en segundo
   plano (base de datos, API, frontend, Storybook, nginx, redis, pgAdmin,
   Mailhog). La primera vez tarda porque tiene que construir las imágenes.
4. **`npm run prisma:migrate`** — aplica las *migraciones* contra la base de datos
   del contenedor `db`. Una migración es un script versionado que crea/actualiza
   tablas según `src/api/prisma/schema.prisma`. Crea la tabla `users`.
5. **`npm run prisma:seed`** — corre `src/api/prisma/seed.ts` para cargar datos
   iniciales en la base.

### Crear un usuario administrador

Como alternativa (o complemento) al seed general, podés crear/actualizar un
usuario con rol `ADMIN`:

```bash
npm run prisma:seed:admin
```

Este script (`src/api/prisma/seed-admin.ts`) toma `ADMIN_EMAIL` y `ADMIN_PASSWORD`
de tu `.env`. Si dejás `ADMIN_PASSWORD` vacío, genera una contraseña aleatoria y
la imprime una sola vez en la salida del comando: copiala en ese momento.

### Verificar que todo levantó

Si todo arrancó bien, deberían responder estas URLs:

| URL                              | Qué es                                   |
|----------------------------------|------------------------------------------|
| http://localhost:4200            | Frontend Angular (dev server)            |
| http://localhost:3000/api/v1     | API NestJS (prefijo `api/v1`)            |
| http://localhost:3000/api/docs   | Swagger (documentación interactiva de la API) |
| http://localhost:6006            | Storybook (catálogo de componentes)      |
| http://localhost:8082            | pgAdmin (UI de Postgres) — login `admin@cusco.local` / `admin` |
| http://localhost:8025            | Mailhog (bandeja de mails de prueba)     |

> **Swagger** es una página web autogenerada a partir de los decoradores del
> backend: te deja ver y probar los endpoints de la API sin escribir código.

Para usar **`https://cusco.local`** en vez de `localhost`, agregá esta línea a tu
`/etc/hosts`:

```
127.0.0.1 cusco.local
```

El servicio `mkcert` provisiona el certificado local automáticamente; nginx lo
sirve en el puerto 443. Detalles en [DOCKER.md](DOCKER.md).

## Variables de entorno relevantes

Todas las variables viven en `.env` (copiado de `.env.example`). Estas son las que
podés llegar a tocar; el resto controla puertos y nombres de servicios y rara vez
necesita cambios en local.

| Variable                  | Default                  | Para qué sirve                                              |
|---------------------------|--------------------------|------------------------------------------------------------|
| `APP_NAME`                | `cusco`                  | Prefijo de los nombres de contenedores y de la red Docker. |
| `DOMAIN`                  | `cusco.local`            | Dominio para HTTPS local (nginx + mkcert).                 |
| `NODE_ENV`               | `development`            | Modo de ejecución de Node.                                 |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` | `cusco` / `cusco` / `cusco_secret` | Credenciales de Postgres en local (no usar en producción). |
| `DATABASE_URL`            | derivada de las `DB_*`   | Cadena de conexión que usa Prisma.                        |
| `API_PORT`                | `3000`                   | Puerto interno de la API NestJS.                          |
| `API_PREFIX` / `API_VERSION` | `api` / `v1`          | Forman el prefijo global `api/v1`.                        |
| `JWT_SECRET`              | `change-me-in-production` | Clave para firmar los tokens JWT. **Cambiala en producción.** |
| `JWT_EXPIRATION`          | `3600`                   | Expiración del token, en segundos.                        |
| `ADMIN_EMAIL`             | `admin@cusco.local`      | Email del admin que crea `prisma:seed:admin`.            |
| `ADMIN_PASSWORD`          | _(vacío)_                | Si lo dejás vacío, se genera una contraseña al azar y se imprime una vez. |
| `FRONTEND_PORT`           | `4200`                   | Puerto interno del dev server de Angular.                |
| `CLIENT_MAX_BODY_SIZE`    | `32M`                    | Tamaño máximo de request que acepta nginx.               |
| `REDIS_HOST` / `REDIS_PORT` | `redis` / `6379`       | Conexión a Redis (cache).                                |
| `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` | `admin@cusco.local` / `admin` | Login de pgAdmin.                              |
| `MAIL_HOST` / `MAIL_PORT` | `mailhog` / `1025`       | Servidor SMTP de prueba (Mailhog).                       |
| `FORWARD_*_PORT`          | varios                   | Puerto que cada servicio expone en tu host. Cambialos si ya tenés algo ocupando ese puerto. |

> **JWT** (JSON Web Token): un token firmado que la API te devuelve al loguearte y
> que mandás en cada request en el header `Authorization: Bearer <token>`.

## Comandos del día a día

Todos los comandos se corren desde la raíz del repo con `npm run ...`. Por debajo,
casi todos hacen `docker compose ...`, así que los contenedores tienen que estar
levantados (`npm start`).

### Docker

```bash
npm start                 # docker compose up -d (levanta todo en background)
npm stop                  # docker compose down (apaga todo)
npm run restart           # reinicia todos los servicios
npm run dev               # up -d + sigue los logs de api y frontend
npm run logs              # sigue los logs de todos los servicios
npm run logs:api          # sólo los logs del api
npm run logs:frontend     # sólo los logs del frontend
npm run logs:storybook    # sólo los logs de storybook
npm run docker:status     # docker compose ps (estado de los contenedores)
npm run docker:rebuild    # down + build --no-cache + up (reconstruye imágenes)
npm run docker:clean      # down -v --remove-orphans (¡BORRA los volúmenes!)
```

### Prisma (base de datos)

Prisma es el ORM: te deja describir las tablas en `schema.prisma` y trabajar con la
base desde TypeScript.

```bash
npm run prisma:generate   # regenera el cliente tras editar schema.prisma
npm run prisma:migrate    # migrate dev: crea/aplica migraciones en local
npm run prisma:migrate:prod  # migrate deploy: aplica migraciones ya creadas (deploy)
npm run prisma:seed       # corre prisma/seed.ts (datos iniciales)
npm run prisma:seed:admin # crea/actualiza el usuario ADMIN
npm run prisma:studio     # GUI web para ver/editar la base (Prisma Studio, puerto 5555)
npm run prisma:reset      # ¡BORRA la base y reaplica todas las migraciones!
```

### Lint y tests

```bash
npm run lint              # ESLint en api + frontend
npm run lint:fix          # lint con autofix
npm run lint:api          # sólo backend
npm run lint:frontend     # sólo frontend
npm test                  # tests de api + frontend
npm run test:api          # sólo backend (Jest)
npm run test:frontend     # sólo frontend (ng test)
npm run test:e2e          # tests end-to-end del backend
npm run prettier          # chequea formato (sin escribir)
npm run prettier:write    # aplica formato
```

Más sobre la estrategia de testing en [TESTING.md](TESTING.md).

### Shells dentro de los contenedores

A veces necesitás entrar a un contenedor para correr un comando puntual.

```bash
npm run api:shell         # abre una shell (sh) dentro del contenedor api
npm run frontend:shell    # shell dentro del contenedor frontend
npm run db:shell          # abre psql conectado a la base
```

### Backup y restore de la base

```bash
npm run db:backup                       # pg_dump → backups/<timestamp>.sql
npm run db:restore < backups/<archivo>.sql   # restaura desde un dump
```

## Cómo extender el proyecto

### Agregar un módulo de dominio (NestJS)

Un *módulo* agrupa el controlador, el servicio y los DTOs de una entidad. El CLI de
Nest genera todo el andamiaje:

```bash
docker compose exec api npx nest g resource modules/<nombre>
```

Después:

1. Agregá el modelo en `src/api/prisma/schema.prisma`.
2. Creá la migración: `npm run prisma:migrate -- --name add-<nombre>`.
3. Importá el nuevo módulo en `src/api/src/app.module.ts` (en el array `imports`)
   para que NestJS lo cargue.

Los módulos existentes que podés tomar como referencia son `auth` y `users`. Más
detalle de la arquitectura del backend en [ARCHITECTURE.md](ARCHITECTURE.md).

### Agregar una página Angular

```bash
docker compose exec frontend npx ng g c pages/<nombre> --standalone
```

Después registrala en `src/frontend/src/app/app.routes.ts` (preferentemente
lazy-loaded). Si la ruta requiere estar logueado, agregale `canActivate:
[authGuard]`. Componé la página a partir de atoms → molecules → organisms siguiendo
Atomic Design.

### Agregar un componente con Storybook

El flujo recomendado es desarrollar el componente de forma aislada en Storybook
antes de integrarlo en una página. El detalle completo está en
[STORYBOOK.md](STORYBOOK.md). En resumen:

```bash
docker compose exec frontend npx ng g c atoms/<nombre> --standalone
# luego creá atoms/<nombre>/<nombre>.stories.ts junto al componente
```

## Calidad de código y commits

- **Husky** instala git hooks automáticamente con `npm install` (script `prepare`).
- En cada commit, `.husky/pre-commit` corre **lint-staged**: aplica Prettier y
  ESLint sólo a los archivos que estás commiteando.
- `.husky/commit-msg` corre **commitlint**: tu mensaje debe seguir
  [Conventional Commits](https://www.conventionalcommits.org/) (`feat(scope):
  ...`, `fix: ...`, etc.).

Convenciones, flujo de ramas y proceso de PR en [CONTRIBUTING.md](CONTRIBUTING.md)
y [GITFLOW.md](GITFLOW.md). Roles de usuario en [ROLES.md](ROLES.md).

## Git LFS para binarios pesados (opcional)

El scaffold **no** usa [Git LFS](https://git-lfs.com/) por defecto. Actívalo sólo
si tu proyecto va a versionar archivos binarios/pesados (CSV o ZIP de import,
imágenes, videos, PDFs, dumps): git guarda cada versión completa de cada archivo
en el historial, así que un binario que cambia seguido infla el `.git` para
siempre —aunque después lo borres— y cada `clone` se lo baja. LFS guarda en su
lugar un puntero de texto y mueve el archivo real a un almacén aparte.

Para activarlo:

1. Instalá el cliente: `apt install git-lfs` / `brew install git-lfs`, luego
   `git lfs install` una vez por máquina.

2. Declará qué archivos van por LFS en `.gitattributes` (ajustá los patrones a
   tu proyecto):

   ```gitattributes
   # Git LFS para datos de import pesados
   ruta/a/tus/datos/*.csv filter=lfs diff=lfs merge=lfs -text
   ruta/a/tus/datos/*.zip filter=lfs diff=lfs merge=lfs -text
   ```

3. Opcional — verificá LFS antes de cada push agregando un hook `.husky/pre-push`:

   ```sh
   export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
   command -v git-lfs >/dev/null 2>&1 || { echo >&2 "git-lfs no encontrado. Instalalo (apt install git-lfs / brew install git-lfs)."; exit 2; }
   git lfs pre-push "$@"
   ```

   > Ojo: este hook **exige** `git-lfs` instalado (falla con `exit 2` si no está),
   > así que sumalo sólo cuando el equipo realmente vaya a usar LFS.

Los archivos que ya estaban commiteados antes de agregar la regla necesitan
`git lfs migrate` para moverse al almacén; los nuevos ya entran por LFS solos.

## ¿Algo no levanta?

Si un contenedor no arranca, el hot-reload no toma cambios o la base quedó en mal
estado, mirá [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
