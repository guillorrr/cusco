# Docker

Toda la stack del proyecto corre en **Docker Compose**, incluso en desarrollo. Tu
máquina (el "host") sólo necesita Docker y Node para los scripts del root. Así,
todos los que trabajan en el proyecto usan exactamente las mismas versiones de
Postgres, Node, Redis, etc., sin instalarlas a mano.

Para el flujo de trabajo (primer arranque, comandos del día a día), ver
[DEVELOPMENT.md](DEVELOPMENT.md). Para la estructura del código,
[ARCHITECTURE.md](ARCHITECTURE.md).

## Conceptos rápidos

Si nunca usaste Docker, alcanza con estas tres ideas:

- **Contenedor**: una "mini-máquina" aislada que corre un servicio (la base de
  datos, la API, etc.). Se crea a partir de una *imagen*.
- **Volumen**: almacenamiento gestionado por Docker que **sobrevive** aunque borres
  y recrees el contenedor. Sirve para datos que no querés perder (los datos de
  Postgres, por ejemplo).
- **Bind mount**: una carpeta de tu host montada dentro del contenedor. Como es la
  misma carpeta, cuando editás un archivo en tu editor el contenedor lo ve al
  instante. Eso es lo que hace posible el **hot reload** (recargar la app sin
  reconstruir la imagen).

## Compose files

| Archivo                     | Para qué sirve                                                        |
|-----------------------------|----------------------------------------------------------------------|
| `docker-compose.yml`        | **Desarrollo** — los 8 servicios + mkcert, con hot-reload y puertos expuestos. Es el que usan todos los scripts (`npm start`, etc.). |
| `docker-compose.cloud.yml`  | **Cloud / deploy** — *overrides* puntuales sobre el de dev para entornos desplegados. Se aplica con `-f docker-compose.yml -f docker-compose.cloud.yml`. |

> Compose superpone los archivos en orden: lo que define `docker-compose.cloud.yml`
> pisa lo del base. No es un archivo completo, sólo las diferencias.

## Servicios (desarrollo)

Son 8 servicios más `mkcert` (que no expone puerto: sólo genera certificados).

| Servicio    | Imagen / Dockerfile             | Puerto host | Rol                                          |
|-------------|---------------------------------|-------------|----------------------------------------------|
| `db`        | `postgres:16-alpine`            | 5432        | Base de datos PostgreSQL.                    |
| `api`       | `docker/api/Dockerfile`         | 3000        | Backend NestJS (`npm run start:dev`).        |
| `frontend`  | `docker/frontend/Dockerfile`    | 4200        | Dev server de Angular (`ng serve --poll`).   |
| `storybook` | `docker/storybook/Dockerfile`   | 6006        | Catálogo de componentes (Storybook).         |
| `nginx`     | `nginx:alpine`                  | 80 / 443    | Reverse proxy + SSL local (con mkcert).      |
| `redis`     | `redis:7-alpine`                | 6379        | Cache.                                       |
| `pgadmin`   | `dpage/pgadmin4`                | 8082        | UI web para administrar Postgres.            |
| `mailhog`   | `mailhog/mailhog`               | 8025 / 1025 | SMTP de testing + bandeja web (8025 = web, 1025 = SMTP). |
| `mkcert`    | `docker/mkcert/Dockerfile`      | —           | Genera certificados locales en `./certs`.    |

> Un **reverse proxy** (nginx) recibe el tráfico en los puertos 80/443 y lo
> redirige internamente al frontend o a la API según la URL.

Los puertos del host se pueden remapear con las variables `FORWARD_*_PORT` de
`.env` (útil si tu host ya tiene algo escuchando en, por ejemplo, el 3000). Ver la
tabla de variables en [DEVELOPMENT.md](DEVELOPMENT.md).

## Volúmenes

Definidos al final de `docker-compose.yml`:

| Volumen                  | Contenedor   | Qué persiste                                              |
|--------------------------|--------------|----------------------------------------------------------|
| `db-data`                | `db`         | Los datos de Postgres (tus tablas y registros).          |
| `redis-data`             | `redis`      | Los datos de Redis.                                      |
| `api-node-modules`       | `api`        | `node_modules` del backend, separado del bind del repo.  |
| `frontend-node-modules`  | `frontend`   | `node_modules` del frontend, separado del bind del repo. |
| `pgadmin-data`           | `pgadmin`    | Configuración y servidores guardados en pgAdmin.         |

### ¿Por qué un volumen aparte para `node_modules`?

El código se monta con bind mounts (`./src/api:/app` y `./src/frontend:/app`) para
tener hot-reload. Pero `node_modules` se instala **dentro** del contenedor (puede
tener binarios compilados para Linux que no querés mezclar con los de tu host). Por
eso se monta encima un volumen propio (`...-node-modules:/app/node_modules`): así el
bind del código no pisa los módulos instalados en el contenedor.

## Cómo se inicializa la base de datos

El servicio `db` monta `./docker/db/init` en `/docker-entrypoint-initdb.d`. Postgres
ejecuta los scripts (`.sql` o `.sh`) de esa carpeta **una sola vez**: cuando el
volumen `db-data` está vacío (es decir, en el primer arranque). La carpeta empieza
vacía en el scaffold: dejá ahí los scripts que necesites correr al inicializar la
base (por ejemplo habilitar extensiones de Postgres). El esquema de tablas NO se
crea acá, sino con las migraciones de Prisma (`npm run prisma:migrate`).

Para **forzar** que se vuelvan a correr (re-inicializar desde cero):

```bash
npm run docker:clean   # borra los volúmenes, incluido db-data
npm start              # vuelve a levantar; la DB se inicializa de nuevo
```

> Ojo: `docker:clean` borra **todos** los datos. Después tenés que volver a correr
> `npm run prisma:migrate` y los seeds.

## Hot reload

- **API**: el contenedor corre `npm run start:dev` (Nest en modo *watch*). Detecta
  cambios en `src/api/src/` y reinicia el proceso solo.
- **Frontend**: corre `npx ng serve --host 0.0.0.0 --poll 2000`. El flag `--poll`
  hace que Angular revise los archivos cada 2 segundos en vez de depender de los
  eventos del sistema de archivos: es necesario porque esos eventos no siempre
  atraviesan los bind mounts (sobre todo en WSL o Mac con Docker Desktop).

Si editás un archivo y no se refleja el cambio, revisá [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Diferencias entre dev y cloud

`docker-compose.cloud.yml` aplica overrides mínimos sobre el de dev, pensados para
entornos desplegados:

- **`api`**: cambia el comando de arranque a
  `npx prisma generate && npx prisma migrate deploy && npm run start:dev`. En cloud
  el volumen `api-node-modules` persiste entre rebuilds, así que el cliente de
  Prisma puede quedar desfasado del schema; regenerarlo y aplicar migraciones en
  cada arranque mantiene el contenedor coherente con la base sin depender del
  pipeline de CI.
- **`nginx`**: setea `SWAGGER_EDGE_POLICY` para **bloquear Swagger** (`/api/docs`)
  en el edge, devolviendo 404. En local esa variable queda vacía y Swagger se sirve
  normalmente.

El resto de los servicios, puertos y volúmenes se heredan tal cual del
`docker-compose.yml` base.

## Tips

```bash
# Logs de un solo servicio
docker compose logs -f api

# Reiniciar uno solo (útil después de tocar .env)
docker compose restart api

# Reconstruir la imagen de uno solo
docker compose build --no-cache api

# Abrir una shell adentro de un contenedor
docker compose exec api sh
docker compose exec db psql -U cusco -d cusco

# Ver el estado de todos los contenedores
docker compose ps

# Levantar combinando el override de cloud
docker compose -f docker-compose.yml -f docker-compose.cloud.yml up -d
```

La mayoría de estos comandos tienen un atajo `npm run ...` en el root; ver
[DEVELOPMENT.md](DEVELOPMENT.md).
