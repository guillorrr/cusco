# Cómo contribuir

Esta guía explica cómo escribir commits, qué hooks corren automáticamente y
cómo abrir un Pull Request en el proyecto. Está pensada para que cualquiera
—incluso si recién empieza— pueda contribuir sin romper nada.

Si todavía no conocés el modelo de ramas (qué es `main`, `develop`,
`feature/*`, etc.), leé primero [GITFLOW.md](GITFLOW.md).

## Commits

**Conventional Commits es obligatorio.** Cada mensaje de commit se valida
automáticamente con Husky + commitlint en el hook `commit-msg`. Si el mensaje
no cumple el formato, el commit se rechaza y no se guarda.

La configuración vive en `commitlint.config.js` (raíz del repo).

### Formato

```
<type>(<scope>): <resumen>

<cuerpo opcional>

<pie opcional>
```

- `type` — qué clase de cambio es (obligatorio, ver tabla abajo).
- `scope` — qué parte del proyecto toca (opcional pero recomendado).
- `resumen` — descripción corta en imperativo. Máximo 100 caracteres.
  No empezar con mayúscula ni terminar en punto.

### Types permitidos

Estos son los únicos types que acepta `commitlint.config.js`:

| Type       | Cuándo usarlo                                                  |
|------------|----------------------------------------------------------------|
| `feat`     | Funcionalidad nueva                                            |
| `fix`      | Corrección de un bug                                           |
| `refactor` | Cambio interno que no altera el comportamiento                 |
| `perf`     | Mejora de performance, sin cambiar el comportamiento          |
| `chore`    | Tarea de mantenimiento (dependencias, configs)                |
| `docs`     | Solo documentación                                            |
| `test`     | Tests nuevos o ajustes a tests existentes                     |
| `style`    | Formato, espacios, prettier — sin cambio de lógica            |
| `ci`       | Pipelines de integración continua (Bitbucket Pipelines)       |
| `build`    | Sistema de build, Dockerfiles, scripts                        |
| `revert`   | Revertir un commit anterior                                   |

### Scopes habituales

El `scope` indica el área del scaffold afectada. Los más comunes:

`auth`, `users`, `api`, `frontend`, `env`, `ci`, `docker`, `docs`.

No es una lista cerrada: a medida que crezcan los módulos podés sumar scopes
nuevos (por ejemplo el nombre de un módulo de dominio que agregues). Lo
importante es que el scope sea real y describa una parte concreta del
proyecto, no algo genérico.

### Ejemplos

```
feat(auth): agregar guard de roles para endpoints protegidos
fix(users): hashear la contraseña antes de persistir el usuario
refactor(api): extraer la lógica de paginación a un helper común
docs(docs): documentar el flujo de Git Flow
chore(env): actualizar .env.example con las variables de Redis
ci(ci): agregar paso de build del frontend al pipeline
build(docker): fijar la imagen base de la api a node:22
```

### Mensaje multilínea

El resumen va corto (≤72 caracteres recomendados, 100 máximo) en la primera
línea. Si necesitás explicar más, dejá una línea en blanco y escribí el cuerpo
con el **porqué** del cambio. Evitá describir el **qué** —para eso ya está el
diff—. El cuerpo sirve para explicar la motivación, qué se rompía antes, o
decisiones que un revisor no podría deducir mirando el código.

```
fix(auth): rechazar el login de usuarios inactivos

El campo isActive=false solo se respetaba a nivel de fila en la base de
datos, pero auth.service.login() emitía igual un JWT válido. Ahora se
verifica isActive antes de firmar el token, de modo que una cuenta
desactivada no pueda autenticarse.
```

## Hooks (Husky)

Husky instala los git hooks automáticamente al correr `npm install` (vía el
script `prepare`). En este repo existen **dos** hooks:

| Hook         | Acción                                                                  |
|--------------|-------------------------------------------------------------------------|
| `pre-commit` | `npx lint-staged` — corre Prettier + ESLint solo sobre los archivos staged |
| `commit-msg` | `commitlint` — valida el mensaje contra `commitlint.config.js`          |

### Qué hace `lint-staged`

Configurado en `package.json` (clave `lint-staged`). Sobre los archivos que
están en el área de staging:

- `src/api/**/*.ts` → `prettier --write` y luego `eslint --fix` dentro de `src/api`.
- `src/frontend/**/*.ts` → `prettier --write` y luego `eslint --fix` dentro de `src/frontend`.
- `src/**/*.{html,scss,json}` → `prettier --write`.

Cada workspace corre su propio ESLint (flat config), por eso el `eslint --fix`
se ejecuta entrando a la carpeta correspondiente.

### Saltear los hooks

Existe `git commit --no-verify` para hacer bypass, pero **no se recomienda**.
Si un hook falla, **arreglá la causa** en lugar de saltearlo.

## Flujo de Pull Request

El proyecto usa Git Flow (ver [GITFLOW.md](GITFLOW.md)). El flujo típico para
una feature:

1. Branchá desde `develop`:
   `git checkout develop && git pull && git checkout -b feature/descripcion-corta`.
2. Hacé commits chicos y temáticos. Si un cambio mezcla dos temas, partilo en
   dos commits.
3. Antes de pushear, asegurate de que lint y tests pasan localmente:
   `npm run lint && npm test`.
4. Pusheá y abrí el PR contra `develop`:
   `git push -u origin feature/descripcion-corta` y luego `gh pr create --base develop --fill`.
5. La CI (Bitbucket Pipelines) corre automáticamente lint + test + build para
   `api` y `frontend`. El PR no debería mergearse con la CI en rojo.
6. Una vez aprobado el review y con la CI en verde, se mergea.

## Estilo de código

- **Prettier:** configuración única en `.prettierrc` de la raíz
  (`singleQuote`, `trailingComma: all`, `printWidth: 100`, `tabWidth: 2`,
  `semi: true`). Se aplica automáticamente vía lint-staged; podés correrlo a
  mano con `npm run prettier:write`.
- **ESLint:** cada workspace tiene su propia flat config —
  `src/api/eslint.config.js` (backend) y `src/frontend/eslint.config.js`
  (frontend)—. Se corre con `npm run lint` (o `lint:fix` para autoarreglar).
- **TypeScript estricto:** `strictNullChecks`, `noImplicitAny`. Evitá `any`
  sin justificación; preferí `unknown` + narrowing.

## Anti-patrones a evitar

- **Commits "wip" o "fix typo" sueltos.** Reescribí o juntá antes del PR para
  que la historia sea legible.
- **Mensajes en pasado (`fixed`, `added`).** Conventional Commits es
  imperativo: `fix`, `add`, no `fixed`, `added`.
- **Scope inventado** (`misc`, `stuff`, `general`). Si no encaja en un scope
  existente, usá uno que describa de verdad la parte afectada.
- **PRs gigantes que mezclan refactor + feature + fix.** Son difíciles de
  revisar y de revertir. Partilos en commits temáticos o en varios PRs.
- **Pushear con la CI o los tests en rojo.** Corré `npm run lint && npm test`
  antes de abrir el PR.
