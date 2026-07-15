# Autenticación: access + refresh tokens

Cómo funciona la sesión en este scaffold: un **access token** corto para pegarle a la API y
un **refresh token** largo para renovarlo, con rotación y detección de reuso.

Si todavía no leíste [ROLES.md](ROLES.md), empezá por ahí: explica qué es un JWT, cómo se
firma y cómo los guards globales protegen los endpoints. Este documento asume eso.

---

## Por qué dos tokens y no uno solo

Un JWT no se puede revocar. Una vez firmado, es válido hasta que expire: el servidor no
guarda nada, solo verifica la firma. Eso es lo que lo hace rápido y sin estado, y es
también su problema.

De ahí sale la tensión:

- **Un token de vida larga es cómodo pero peligroso.** Si te lo roban, el atacante entra
  hasta que expire. No hay forma de cortarlo.
- **Un token de vida corta es seguro pero incómodo.** Si expira en 15 minutos, el usuario
  tendría que loguearse cada 15 minutos.

Los dos tokens resuelven las dos mitades por separado:

| | Access token | Refresh token |
|---|---|---|
| **Formato** | JWT firmado | string opaco aleatorio (64 bytes) |
| **Dura** | `TOKEN_EXPIRATION` (`1h`) | `REFRESH_TOKEN_EXPIRATION` (`7d`) |
| **Se usa para** | cada request a la API | únicamente `POST /auth/refresh` |
| **Lo valida** | la firma; nadie consulta la DB | una fila en `refresh_tokens` |
| **¿Revocable?** | **No** | **Sí** |
| **Se guarda en el server** | no | sí, solo el hash sha256 |

La idea de fondo: la ventana de daño de un access token robado queda acotada a su
expiración, y el refresh token —que sí dura— es revocable porque vive en la base.

Las dos duraciones salen de `src/api/src/core/config/constants.ts`
(`APP_CONSTANTS.AUTH`), que es la fuente de verdad. La variable de entorno
`JWT_EXPIRATION` (en segundos) sigue pisando la del access token si está definida.

## Por qué el refresh token NO es un JWT

Sería fácil firmar otro JWT con más expiración, pero no serviría: volvería a ser
irrevocable, que es justo lo que queremos evitar. Por eso el refresh token es un string
aleatorio sin significado propio; toda su autoridad viene de existir como fila viva en la
tabla. Revocarlo es un `UPDATE`.

## Por qué se guarda hasheado

En la tabla solo va el **sha256** del token, nunca el token en claro. Si alguien se lleva
un dump de la base, se lleva hashes: no puede reconstruir los tokens ni usarlos. Es el
mismo razonamiento que con las contraseñas.

> La diferencia con las contraseñas es que acá alcanza sha256 y no hace falta bcrypt. bcrypt
> es lento **a propósito** para resistir fuerza bruta sobre secretos con poca entropía (una
> contraseña elegida por una persona). Un refresh token son 64 bytes aleatorios: no hay
> diccionario que lo adivine, así que el costo de bcrypt no compraría nada y solo haría más
> lento cada refresh.

Consecuencia práctica: el token en claro se muestra **una sola vez**, en la respuesta que lo
emite. El servidor no puede volver a mostrártelo porque no lo tiene.

---

## La tabla `refresh_tokens`

Modelo `RefreshToken` en `src/api/prisma/schema.prisma`:

| Columna | Tipo | Para qué |
|---|---|---|
| `id` | serial, PK | |
| `token_hash` | text, **único** | sha256 del token. Es por acá que se busca. |
| `user_id` | int, FK → `users.id`, **on delete cascade**, indexado | dueño del token |
| `expires_at` | timestamp | cuándo deja de servir |
| `revoked_at` | timestamp, **nullable** | `NULL` = vivo. Con fecha = revocado. |
| `created_at` | timestamp | cuándo se emitió |

Detalles que importan:

- **`token_hash` es único** porque es la clave de búsqueda real en cada refresh.
- **`user_id` está indexado** porque la detección de reuso revoca por usuario
  (`WHERE user_id = ...`), y eso corre en el peor momento posible.
- **`on delete cascade`**: borrar un usuario se lleva sus tokens. Sin esto quedarían filas
  huérfanas apuntando a un usuario que no existe.
- **Nunca se borran filas, se revocan.** Un token rotado queda con `revoked_at` seteado en
  lugar de desaparecer, y eso es exactamente lo que hace detectable el reuso: si lo
  borráramos, un token robado sería indistinguible de uno inventado.

La tabla y sus columnas van en snake_case vía `@map`, siguiendo la convención del resto del
esquema.

---

## Los endpoints

Todos cuelgan de `/api/v1/auth`.

### `POST /auth/login` — público

```jsonc
// request
{ "email": "demo@example.local", "password": "secret123" }
```
```jsonc
// 201
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "9f2c...ab71",           // 128 chars hex; guardalo, no vuelve a aparecer
  "user": { "id": 1, "email": "demo@example.local", "role": "USER" }
}
```

Credenciales inválidas → `401`. No distingue entre email inexistente y contraseña
incorrecta: sería decirle a un atacante qué emails existen.

### `POST /auth/refresh` — público

```jsonc
// request
{ "refresh_token": "9f2c...ab71" }
```
```jsonc
// 201 — par nuevo; el refresh_token enviado ya no sirve
{ "access_token": "...", "refresh_token": "7d10...9f43", "user": { ... } }
```

Es `@Public()` **a propósito**: se lo llama justo cuando el access token venció, así que no
hay credencial válida con la cual autenticarlo. Lo que autoriza el pedido es el refresh
token del body.

Devuelve `401` si el token es desconocido, si expiró, o si ya estaba revocado (ver reuso).
Si el body no trae `refresh_token`, el `ValidationPipe` global corta con `400`.

### `POST /auth/logout` — público

```jsonc
// request
{ "refresh_token": "7d10...9f43" }
// 204 sin body
```

**Idempotente**: siempre `204`, exista el token o no, esté ya revocado o no. Dos razones.
Una, cerrar sesión no debería fallar nunca —un logout que tira error deja al cliente sin
saber qué hacer—. Dos, responder distinto según si el token existía convertiría el endpoint
en un oráculo para saber si un token es válido.

Ojo: revoca el refresh token, pero **el access token sigue siendo válido hasta que
expire**, porque un JWT no se puede revocar. Es la contracara de que sea sin estado. Por eso
conviene que `TOKEN_EXPIRATION` sea corto. Si necesitás corte inmediato, la salida es una
denylist de JWTs (por ejemplo en Redis, que el scaffold ya levanta), y ahí resignás lo
stateless.

### `GET /auth/me` — requiere Bearer

```
Authorization: Bearer <access_token>
```
```jsonc
// 200
{ "id": 1, "email": "demo@example.local", "firstName": null, "lastName": null,
  "role": "USER", "isActive": true, "createdAt": "2026-07-15T12:00:00.000Z" }
```

No lleva `@Public()`: lo protege el `JwtAuthGuard` global. Relee el usuario de la base en
lugar de devolver lo que dice el token, así que refleja cambios de rol o de `isActive` que
el JWT todavía tiene viejos (ver la advertencia sobre esto en [ROLES.md](ROLES.md)).

---

## Rotación y detección de reuso

### La rotación

Cada refresh consume el token: se revoca el presentado y se emite uno nuevo. **Un refresh
token sirve exactamente una vez.**

```
login    →  R1 (vivo)
refresh(R1)  →  R1 revocado, entrega R2 (vivo)
refresh(R2)  →  R2 revocado, entrega R3 (vivo)
```

Esto acota la ventana: un refresh token robado sirve hasta que el usuario legítimo haga su
próximo refresh, no siete días.

### La detección de reuso

La rotación además deja una señal aprovechable. En condiciones normales **un token revocado
nunca debería volver**: el cliente legítimo ya pasó al siguiente. Si vuelve, algo se filtró.

```
                 R1 ─refresh─→ R2        (usuario legítimo, R1 queda revocado)
   atacante roba R1
                 R1 ─refresh─→ 401       ← R1 ya estaba revocado: REUSO DETECTADO
                                           se revoca toda la familia del usuario
                 R2 ─refresh─→ 401       ← el usuario legítimo también queda afuera
```

Al detectarlo, se revocan **todos** los tokens vivos de ese usuario, no solo el
presentado. El motivo: el servidor no puede distinguir al atacante de la víctima. Los dos
llegan con un token que salió de la misma cadena. Ante la duda, se corta todo y se obliga a
un login nuevo —donde hace falta la contraseña, que el atacante no tiene—.

Sí, esto desloguea al usuario legítimo. Es deliberado: es preferible una fricción molesta
pero recuperable (volver a loguearse) a que un atacante mantenga la sesión viva rotando
tokens para siempre.

Un caso vale la pena señalar: si el atacante roba R1 y hace refresh **antes** que el
usuario, obtiene un R2 válido y no se detecta nada todavía. La detección salta cuando el
usuario legítimo intenta usar **su** R1, que ya estaba revocado. El esquema no evita el
robo: garantiza que no pase inadvertido y que la sesión robada muera apenas el usuario
vuelva.

### En el código

`AuthService.refresh()` (`src/api/src/modules/auth/auth.service.ts`), en orden:

1. Hashea el token recibido y busca la fila por `token_hash`.
2. No existe → `401`.
3. **Tiene `revoked_at` → reuso**: revoca toda la familia del usuario y tira `401`.
4. Está vencido → `401`.
5. Si no, revoca el presentado, emite un par nuevo y lo devuelve.

El orden importa: el chequeo de reuso va **antes** que el de expiración, para que un token
robado y encima vencido igual dispare la alarma en lugar de morir como un vencimiento
cualquiera.

---

## Qué falta / por dónde seguir

Cosas que el scaffold deliberadamente no hace, para no imponer decisiones:

- **No limpia tokens vencidos.** Las filas se acumulan. En producción querés un job
  periódico que borre lo que ya venció hace rato.
- **No loguea ni alerta el reuso.** Hoy solo revoca y rechaza. Detectar reuso es una señal
  fuerte de robo: vale la pena mandarla a tu sistema de observabilidad.
- **No limita la cantidad de sesiones por usuario.** Cada login abre una familia nueva y no
  hay tope.
- **No chequea `isActive` al refrescar**, igual que hoy tampoco lo chequea al loguear (ver
  [ROLES.md](ROLES.md)).
- **No hay rate limiting** en `/auth/login` ni en `/auth/refresh`.

## Tests

`src/api/src/modules/auth/auth.service.spec.ts` cubre el servicio con Prisma mockeado:
rotación, token desconocido, vencido, logout idempotente, que se persista solo el hash y
—el caso que justifica todo este diseño— que un token revocado revoque la familia entera.

```bash
npm run test:api
```
