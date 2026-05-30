# Documentación de Cusco

Esta carpeta reúne la documentación del scaffold **Cusco**: cómo está armado el
proyecto, cómo trabajar en él día a día y cómo operarlo. Está pensada para que
alguien que **nunca usó NestJS, Prisma, Swagger o Angular** pueda entender la
arquitectura y empezar a contribuir.

> El [README principal](../README.md) tiene el resumen del stack y el inicio rápido.
> Esta carpeta es la versión extendida y explicada.

## Por dónde empezar

Si es tu primer día en el proyecto, leé en este orden:

1. [ARCHITECTURE.md](ARCHITECTURE.md) — el mapa mental: qué es cada cosa y por qué.
2. [DEVELOPMENT.md](DEVELOPMENT.md) — levantá el proyecto y conocé los comandos.
3. [STORYBOOK.md](STORYBOOK.md) — cómo construir componentes de UI aislados.
4. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — qué hacer cuando algo no arranca.

## Índice completo

### Primeros pasos

| Doc | De qué trata |
|-----|--------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Arquitectura por capas (backend) y Atomic Design (frontend), modelo de datos y decisiones de diseño. |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Requisitos, primer arranque, variables de entorno, comandos día a día y cómo extender el código. |

### Desarrollo

| Doc | De qué trata |
|-----|--------------|
| [STORYBOOK.md](STORYBOOK.md) | Desarrollo y validación de componentes Angular de forma aislada. |
| [ROLES.md](ROLES.md) | Patrón de control de acceso (RBAC): roles, guards y decoradores de autenticación. |
| [TESTING.md](TESTING.md) | Tests unitarios y e2e en backend (Jest) y frontend, con ejemplos. |

### Operaciones

| Doc | De qué trata |
|-----|--------------|
| [DOCKER.md](DOCKER.md) | Servicios del Compose, volúmenes, hot reload y diferencias dev vs cloud. |

### Calidad y colaboración

| Doc | De qué trata |
|-----|--------------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Conventional Commits, hooks de Husky, flujo de PR y estilo de código. |
| [GITFLOW.md](GITFLOW.md) | Modelo de ramas Git Flow y protección de ramas. |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Problemas frecuentes en desarrollo y cómo destrabarlos. |

## Nota sobre el código de ejemplo

Cusco es un **scaffold**: incluye módulos de ejemplo (`auth`, `users`) y componentes
de ejemplo (`button`, `input`, `card`, `form-field`, páginas `home`/`login`) para mostrar
la arquitectura en acción. Varios docs los usan como referencia.

El script `npm run clean:scaffolding` elimina ese código de ejemplo cuando arrancás un
proyecto nuevo a partir del fork (ver el [README principal](../README.md#uso-como-scaffold-forks)).
Después de limpiarlo, estos docs siguen siendo válidos como **guía de los patrones** del
scaffold, aunque los módulos/componentes concretos que citan ya no estén: reimplementá
esos patrones en el dominio de tu proyecto.

## Personalización en forks

Estos docs usan el nombre genérico **Cusco** / `cusco`. Al limpiar el scaffolding, el script
`clean-scaffolding` ofrece **personalizar la documentación** reemplazando ese nombre por el de
tu proyecto. También podés correrlo manualmente:

```bash
# Reemplaza "Cusco"/"cusco" por el nombre de tu proyecto en docs/
PROJECT_NAME="MiApp" PROJECT_SLUG="miapp" bash scripts/personalize-docs.sh
```
