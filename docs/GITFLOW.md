# Git Flow — modelo de ramas

Este repo sigue el modelo clásico de **Git Flow** (Vincent Driessen). Si nunca
trabajaste con este flujo, la idea es simple: hay **dos ramas permanentes** que
nunca se borran y **tres tipos de ramas temporales** que se crean, se mergean y
se eliminan.

## Ramas permanentes (long-lived)

| Rama      | Para qué sirve                                                                 |
| --------- | ------------------------------------------------------------------------------ |
| `main`    | Código listo para producción. Solo se mergean acá ramas `release/*` y `hotfix/*`. Los tags de versión viven en esta rama. |
| `develop` | Rama de integración. Las features nuevas se mergean acá primero. Lo que está en `develop` es el próximo candidato a release. |

En la práctica: programás contra `develop`, y `main` siempre refleja lo que
está (o estuvo) en producción.

## Ramas temporales (short-lived)

| Prefijo     | Sale de    | Se mergea en             | Para qué                                                |
| ----------- | ---------- | ------------------------ | ------------------------------------------------------- |
| `feature/*` | `develop`  | `develop`                | Funcionalidad nueva, refactors, documentación          |
| `release/*` | `develop`  | `main` **y** `develop`   | Estabilizar una versión (bump de versión, fixes finales) |
| `hotfix/*`  | `main`     | `main` **y** `develop`   | Arreglo urgente que no puede esperar al próximo release |

`chore/*` y `fix/*` se aceptan como alias cosméticos de `feature/*` cuando el
cambio no es realmente una "feature" pero sigue el mismo flujo (sale de
`develop` y vuelve a `develop`).

### ¿Por qué `release/*` y `hotfix/*` se mergean en dos ramas?

Porque el arreglo o la versión tiene que quedar tanto en producción (`main`)
como en la línea de desarrollo (`develop`), para que el próximo release no
"pierda" ese cambio.

## Comandos del día a día

### Empezar una feature

```sh
git checkout develop
git pull origin develop
git checkout -b feature/descripcion-corta
# … trabajás, hacés commits …
git push -u origin feature/descripcion-corta
gh pr create --base develop --fill
```

### Preparar un release

```sh
git checkout develop
git pull origin develop
git checkout -b release/0.4.0
# subís la versión, actualizás el CHANGELOG, fixes de último momento
git push -u origin release/0.4.0
# Abrís dos PRs: release/0.4.0 → main Y release/0.4.0 → develop
# Cuando ambos están mergeados, taggeás main:
git checkout main && git pull
git tag -a v0.4.0 -m "0.4.0"
git push origin v0.4.0
```

### Hotfix

```sh
git checkout main
git pull origin main
git checkout -b hotfix/0.4.1
# … arreglás, hacés commits …
git push -u origin hotfix/0.4.1
# Abrís dos PRs: hotfix/0.4.1 → main Y hotfix/0.4.1 → develop
# Taggeás main después del merge.
```

## Integración continua (CI)

El repo incluye `bitbucket-pipelines.yml` (**Bitbucket Pipelines**). El
pipeline corre **gates de calidad** —lint + test + build de `api` y `frontend`
en paralelo— en estos casos:

- En **cada Pull Request** (hacia cualquier rama).
- En cada push a **`main`** y a **`develop`**.

El pipeline base no incluye paso de deploy a propósito: cada fork despliega en
un entorno distinto. Los pasos de deploy se agregan encima de este archivo una
vez que se conoce el entorno destino.

## Protección de ramas

El proyecto **no trae protección server-side ni un hook `pre-push`** por
defecto: los únicos git hooks presentes son `pre-commit` y `commit-msg` (ver
[CONTRIBUTING.md](CONTRIBUTING.md)). La regla de no pushear directo a `main` /
`develop` se sostiene por convención del equipo, reforzada por los gates de la
CI.

Si querés endurecerlo, hay dos caminos (ambos **opcionales**):

### Opción A — Protección server-side (recomendada)

El upstream vive en GitHub (`git@github.com:guillorrr/cusco.git`). Cuando el
repo sea público o tenga GitHub Pro, podés aplicar protección de rama
server-side con `gh`:

```sh
gh api --method PUT repos/<owner>/<repo>/branches/main/protection \
  --input docs/branch-protection-main.json
```

Esto requiere crear primero el archivo `docs/branch-protection-main.json` con
el payload de la regla (requerir PR, requerir checks de CI en verde, etc.).
Hoy ese archivo **no existe** en el repo; lo agregás vos si tomás este camino.

### Opción B — Protección local con un hook `pre-push`

Como alternativa (o complemento) podés agregar un hook `.husky/pre-push` que
bloquee, por ejemplo:

1. Cualquier push directo a `main` o `develop` (forzando a pasar por PR).
2. El borrado de `main` o `develop`.
3. Pushes con `--force` (no fast-forward) sobre ramas compartidas.

Este hook **tampoco existe hoy** en el repo; es algo que podés sumar si querés
la protección sin depender de GitHub. En una emergencia, un hook local se
saltea con `git push --no-verify` (no recomendado).

## Commits

Conventional Commits, igual que siempre: `feat`, `fix`, `chore`, `refactor`,
`docs`, `test`, `style`, `perf`, `ci`, `build`, `revert`, seguidos de un scope
opcional y un resumen de una línea. El detalle del formato, los scopes y los
hooks que validan los mensajes está en [CONTRIBUTING.md](CONTRIBUTING.md).
