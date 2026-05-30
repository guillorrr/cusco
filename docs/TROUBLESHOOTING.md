# Troubleshooting

Problemas que aparecen seguido cuando trabajás en local con Cusco y cómo destrabarlos.
Está pensado para alguien que recién arranca: cada sección explica **qué pasa** y **qué
comando correr**.

Si todavía no levantaste el stack, mirá primero [DOCKER.md](DOCKER.md) (cómo se orquestan
los contenedores) y [DEVELOPMENT.md](DEVELOPMENT.md) (flujo de desarrollo día a día).

> **Nota sobre los comandos.** Casi todo se maneja con scripts de npm definidos en el
> `package.json` de la raíz. Por ejemplo `npm run prisma:migrate` por debajo corre
> `docker compose exec api npx prisma migrate dev`. No hace falta entrar al contenedor a
> mano salvo que se indique.

---

## El stack no levanta

### `port is already allocated`

Docker pide un puerto del host (3000, 4200, 5432, etc.) que ya está ocupado por otro
proceso. Cusco expone varios puertos a la vez (ver la tabla de servicios en
[DOCKER.md](DOCKER.md)), así que el choque puede ser con cualquiera de ellos.

```bash
# Identificar quién tiene el puerto (ejemplo con el 3000 del API)
lsof -i :3000
sudo ss -tlnp | grep 3000
```

Tenés dos salidas:

- Matar el proceso que lo ocupa, si no lo necesitás.
- Cambiar el puerto que usa Cusco editando el `.env` (copiado de `.env.example`) y
  reiniciando con `npm run restart`.

### `https://cusco.local` da `NET::ERR_CERT_AUTHORITY_INVALID`

Cusco puede servirse por HTTPS en `https://cusco.local` usando un certificado local que
genera el servicio `mkcert`. Si el navegador se queja del certificado, lo más probable es
que el cert no se haya generado todavía:

```bash
docker compose up mkcert     # genera los certificados
ls -la certs/                # deberían aparecer cusco.local.pem y cusco.local-key.pem
```

Además, el dominio `cusco.local` tiene que resolver a tu propia máquina. Agregá esta línea
a `/etc/hosts`:

```
127.0.0.1 cusco.local
```

Mientras tanto siempre podés usar `http://localhost:4200` (frontend) y
`http://localhost:3000/api/v1` (API) sin HTTPS.

### `npm start` falla con `EACCES` en `dist/`

Pasa cuando un build previo corrió como `root` dentro del contenedor y dejó archivos cuyo
dueño es root en una carpeta compartida con tu host (bind mount). Tu usuario ya no puede
escribir ahí.

```bash
# Devolverte la propiedad de las carpetas de build
sudo chown -R "$USER":"$USER" src/api/dist src/frontend/dist

# o, si no te importa perder el build, borralas (se regeneran solas)
sudo rm -rf src/api/dist src/frontend/dist
```

---

## Base de datos

La base es PostgreSQL corriendo en el contenedor `db`. El esquema vive en
`src/api/prisma/schema.prisma` y se aplica con migraciones de Prisma.

### `prisma migrate dev` dice que la DB no está disponible (`db is not reachable`)

El contenedor `db` todavía no terminó de arrancar (Postgres tarda unos segundos en quedar
"healthy"). Esperá un momento y reintentá:

```bash
docker compose logs db | tail
docker compose ps db          # debería decir "(healthy)"
npm run prisma:migrate
```

### Quiero empezar la DB local de cero

`docker:clean` baja todo y **borra los volúmenes**, así que perdés todos los datos locales.
Después volvés a levantar, migrás y sembrás el admin de ejemplo:

```bash
npm run docker:clean          # baja contenedores y BORRA volúmenes (datos incluidos)
npm start                     # vuelve a levantar el stack
npm run prisma:migrate        # crea las tablas
npm run prisma:seed:admin     # crea el usuario admin de ejemplo
```

### Después de un `prisma:reset` el API sigue viendo el esquema viejo

`npm run prisma:reset` borra la base y vuelve a aplicar todas las migraciones. Pero el
Prisma Client que el contenedor `api` ya tenía cargado en memoria puede quedar apuntando al
esquema anterior. Reiniciá solo ese contenedor:

```bash
npm run prisma:reset
docker compose restart api
```

---

## Backend (NestJS, contenedor `api`)

### Cambios en archivos `.ts` no se reflejan

El API corre en modo watch (`nest start --watch`), que recompila cuando detecta cambios. En
algunos entornos (WSL, macOS con Docker Desktop) los eventos del sistema de archivos no
cruzan bien el bind mount y el watcher no se entera. La salida rápida es reiniciar el
contenedor:

```bash
docker compose restart api
```

### `Cannot find module '@modules/...'` (o `@core`, `@common`)

El backend usa **path aliases** (`@core/*`, `@modules/*`, `@common/*`) configurados en el
`tsconfig.json` de `src/api`. Si ves este error:

- Verificá que el `paths` del `tsconfig.json` siga teniendo esos alias.
- Confirmá que el archivo que estás importando exista realmente y que la ruta esté bien
  escrita.
- Si tocaste el esquema de Prisma, regenerá el cliente para que el tipo importado vuelva a
  existir:

```bash
npm run prisma:generate
```

---

## Frontend (Angular, contenedor `frontend`)

### `ng serve` no reconstruye al guardar

Mismo problema que en el backend: bind mount + watcher que no detecta cambios. El compose ya
arranca Angular con polling para mitigarlo. Si aun así no rebuildea, reiniciá el contenedor:

```bash
docker compose restart frontend
```

### Storybook carga en blanco

Storybook (contenedor `storybook`, puerto 6006) compila **todas** las stories juntas: si una
sola `.stories.ts` tiene un error de compilación, se rompe la vista entera y queda en blanco.
Mirá los logs para encontrar cuál falla:

```bash
docker compose logs storybook | tail -50
```

Lo más común es un error en una story recién creada. Más sobre el flujo de componentes en
[STORYBOOK.md](STORYBOOK.md).

### El navegador bloquea las llamadas al API por CORS

El API ya habilita CORS de forma global (`app.enableCors()` en `main.ts`). Si igual ves un
error de CORS, casi siempre es porque el **origin no coincide**: el navegador cargó el
frontend desde `https://cusco.local` pero el código está pegándole al API en
`http://localhost:3000` (o al revés). Para el navegador son orígenes distintos.

Solución: usá un solo host de punta a punta. O todo por `localhost`, o todo por
`cusco.local`. Revisá la URL base del API que usa el frontend y que coincida con el host
desde el que abriste la app.

---

## Cuando nada de lo anterior funciona

Reset total: bajar todo, borrar volúmenes, limpiar imágenes huérfanas de Docker, y volver a
construir desde cero.

```bash
npm run docker:clean          # baja contenedores + borra volúmenes
docker system prune -a        # ¡cuidado! borra imágenes que no estén en uso
npm run docker:rebuild        # reconstruye las imágenes sin caché
npm start
npm run prisma:migrate
npm run prisma:seed:admin
```

Si después de esto sigue roto, juntá esta información antes de pedir ayuda o abrir un issue:

- `npm run docker:status` (estado de los contenedores)
- `docker compose logs api | tail -200` (últimos logs del API)
- el contenido relevante de tu `.env`, **con los secretos tapados**
