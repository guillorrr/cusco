# Testing

## ¿Test unitario vs e2e? (para empezar de cero)

- Un **test unitario** prueba una pieza chica de código (por ejemplo, un service o un componente) **en aislamiento**. Sus dependencias (base de datos, otros servicios, la red) se reemplazan por **mocks** (objetos falsos). Es rápido y determinístico.
- Un **mock** es ese objeto falso. En vez de hablar con Postgres de verdad, le damos a un service un `PrismaService` simulado cuyos métodos devuelven lo que nosotros decidamos. Así el test no depende de tener la DB levantada.
- Un **test e2e** (end-to-end, "de punta a punta") prueba el sistema **integrado**: levanta la aplicación NestJS completa y le pega a los endpoints HTTP reales. Es más lento pero verifica que las piezas encajan.

Regla práctica: la mayoría de tus tests deberían ser unitarios (rápidos, muchos); los e2e son pocos y cubren los flujos críticos.

## Resumen

| Capa     | Runner | Comando                | Convención de nombre        |
|----------|--------|------------------------|-----------------------------|
| Backend  | Jest   | `npm run test:api`     | `*.spec.ts` co-localizado   |
| Backend (e2e) | Jest | `npm run test:e2e`  | `test/*.e2e-spec.ts`        |
| Frontend | Karma + Jasmine | `npm run test:frontend` | `*.spec.ts` co-localizado |

Para correr backend + frontend de una sola pasada:

```bash
npm test
```

Esto encadena `test:api && test:frontend`. En CI conviene correrlos como pasos separados (el pipeline incluido en el repo es Bitbucket Pipelines, `bitbucket-pipelines.yml`).

> Los comandos `test:api` / `test:frontend` corren `npm run test` dentro de cada workspace. Si el stack está dockerizado y querés correrlos en el contenedor, antepoé `docker compose exec api ...` o `docker compose exec frontend ...` (ver [DOCKER.md](DOCKER.md)).

## Backend (Jest)

### Estructura

Los `.spec.ts` viven **al lado** del archivo que testean (co-localizados). La configuración de Jest está en `src/api/package.json`: `rootDir: src`, `testRegex: .*\.spec\.ts$`, con los alias `@core/*`, `@modules/*` y `@common/*` resueltos vía `moduleNameMapper`.

Los módulos de dominio reales de Cusco son `auth` y `users` (ver [ARCHITECTURE.md](ARCHITECTURE.md)). Por ejemplo, una suite para el service de usuarios viviría en:

```
src/api/src/modules/users/users.service.spec.ts
src/api/src/modules/auth/auth.service.spec.ts
```

### Patrones

- **Los tests unitarios usan mocks, no la DB.** El `PrismaService` se mockea con `jest.fn()` por cada método que el service llama (`user.findUnique`, `user.create`, etc.). Esto mantiene la suite rápida y determinística.
- **Integración / e2e** (en `src/api/test/`, por convención `*.e2e-spec.ts`) levantan el módulo completo con `Test.createTestingModule(...).createNestApplication()` y golpean los endpoints reales. La DB se usa efímera o una de test aislada.
- **Afirmá comportamiento concreto:** valores de retorno, excepciones lanzadas, y que se haya llamado al mock con los argumentos correctos.

### Ejemplo: `UsersService` con `PrismaService` mockeado

El `UsersService` real (`src/api/src/modules/users/users.service.ts`) recibe `PrismaService` por inyección de dependencias, hashea la contraseña con `bcrypt` al crear, y lanza `ConflictException` si el email ya existe. Lo testeamos mockeando Prisma:

```ts
import { Test } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { UsersService } from './users.service';
import { PrismaService } from '@core/setup/prisma.service';

describe('UsersService', () => {
  let service: UsersService;

  // Mock: solo los métodos de Prisma que el service usa.
  const prismaMock = {
    user: {
      findUnique: jest.fn(),
      create: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const mod = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();
    service = mod.get(UsersService);
  });

  it('crea un usuario y no devuelve el password', async () => {
    prismaMock.user.findUnique.mockResolvedValue(null); // email libre
    prismaMock.user.create.mockResolvedValue({
      id: 1,
      email: 'demo@cusco.local',
      password: 'hash',
      role: 'USER',
    });

    const result = await service.create({
      email: 'demo@cusco.local',
      password: 'secret123',
    } as any);

    expect(prismaMock.user.create).toHaveBeenCalled();
    expect(result.email).toBe('demo@cusco.local');
    expect((result as any).password).toBeUndefined(); // sanitizado
  });

  it('rechaza un email duplicado con ConflictException', async () => {
    prismaMock.user.findUnique.mockResolvedValue({ id: 1, email: 'demo@cusco.local' });

    await expect(
      service.create({ email: 'demo@cusco.local', password: 'x' } as any),
    ).rejects.toThrow(ConflictException);
  });

  it('lanza NotFoundException si el usuario no existe', async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);

    await expect(service.findOne(999)).rejects.toThrow(NotFoundException);
  });
});
```

### Ejemplo: `AuthService` (suite real del repo)

Esta suite **existe de verdad** en `src/api/src/modules/auth/auth.service.spec.ts`; abrila
para verla entera. El `AuthService` depende de `UsersService`, `JwtService` y
`PrismaService`, y los tres se mockean:

```ts
import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { PrismaService } from '../../core/setup/prisma.service';

const usersMock = { findByEmail: jest.fn(), findOne: jest.fn() };
const jwtMock = { sign: jest.fn().mockReturnValue('signed.jwt.token') };
const prismaMock = {
  refreshToken: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
};

const mod = await Test.createTestingModule({
  providers: [
    AuthService,
    { provide: UsersService, useValue: usersMock },
    { provide: JwtService, useValue: jwtMock },
    { provide: PrismaService, useValue: prismaMock },
  ],
}).compile();
```

El caso que más valor tiene es el de **reuso de un refresh token revocado**: comprueba que
se revoque la familia entera del usuario y que no se emita ningún par nuevo (el porqué está
en [auth-refresh-tokens.md](auth-refresh-tokens.md)).

```ts
it('revokes every live token of the user when a revoked token is replayed', async () => {
  prismaMock.refreshToken.findUnique.mockResolvedValue({
    id: 3, userId: 42, revokedAt: new Date('2026-01-01T00:00:00Z'),
    expiresAt: hoursFromNow(24), user,
  });

  await expect(service.refresh({ refresh_token: 'stolen' })).rejects.toThrow(UnauthorizedException);

  expect(prismaMock.refreshToken.updateMany).toHaveBeenCalledWith({
    where: { userId: 42, revokedAt: null },
    data: { revokedAt: expect.any(Date) },
  });
  expect(prismaMock.refreshToken.create).not.toHaveBeenCalled();
});
```

> **Importá con rutas relativas, no con los alias.** Los `@core/*` y `@modules/*` existen en
> el `tsconfig.json` del API, pero Jest no tiene `moduleNameMapper`, así que dentro de un
> `.spec.ts` no resuelven. El código del repo también usa rutas relativas.

## Frontend (Karma + Jasmine)

El frontend usa el setup estándar de Angular CLI: **Karma** como runner y **Jasmine** como framework de aserciones (builder `@angular-devkit/build-angular:karma`, configurado en `src/frontend/angular.json`). Los `.spec.ts` se co-localizan junto al componente, igual que las stories. El comando corre los tests una sola vez (sin modo watch) con Chromium headless dentro del contenedor de frontend:

```bash
npm run test:frontend     # ng test --watch=false
```

### Testear un componente standalone

Los componentes de Cusco son **standalone** (sin NgModule), así que se importan directo en el `TestBed`. Ejemplo con el `ButtonComponent` real (`src/frontend/src/app/atoms/button/button.component.ts`), que recibe el texto por `<ng-content />` y emite `onClick`:

```ts
import { TestBed } from '@angular/core/testing';
import { ButtonComponent } from './button.component';

describe('ButtonComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ButtonComponent], // standalone: se importa directamente
    }).compileComponents();
  });

  it('aplica las clases de variant y size', () => {
    const fixture = TestBed.createComponent(ButtonComponent);
    fixture.componentRef.setInput('variant', 'danger');
    fixture.componentRef.setInput('size', 'lg');
    fixture.detectChanges();

    // El getter `classes` arma clases de Bootstrap: 'btn', 'btn-danger', 'btn-lg'.
    const btn: HTMLButtonElement = fixture.nativeElement.querySelector('button');
    expect(btn.classList).toContain('btn');
    expect(btn.classList).toContain('btn-danger');
    expect(btn.classList).toContain('btn-lg');
  });

  it('emite onClick al hacer click', () => {
    const fixture = TestBed.createComponent(ButtonComponent);
    const spy = jasmine.createSpy('onClick');
    fixture.componentInstance.onClick.subscribe(spy);
    fixture.detectChanges();

    fixture.nativeElement.querySelector('button').click();
    expect(spy).toHaveBeenCalled();
  });
});
```

### Tips

- **Componente standalone:** importalo en el array `imports` del `TestBed`, sin module.
- **Signals:** se leen con `()` igual que en el componente. Para `@Input()` clásicos usá `componentRef.setInput(...)`; para inputs de signal idem.
- **HTTP:** mockeá las llamadas con `HttpTestingController`, registrando `provideHttpClient()` y `provideHttpClientTesting()` en el `TestBed`. Así un service como `ApiService` (`src/frontend/src/app/core/services/api.service.ts`) se testea sin pegar a la API real:
  ```ts
  TestBed.configureTestingModule({
    providers: [provideHttpClient(), provideHttpClientTesting()],
  });
  const http = TestBed.inject(HttpTestingController);
  // ... disparar la llamada, luego:
  http.expectOne('/api/v1/users').flush({ items: [], total: 0 });
  ```
- **Stories como sanity check:** si el componente compila en Storybook (ver [STORYBOOK.md](STORYBOOK.md)), ya tenés garantía de que tipa OK y los inputs están bien definidos. No reemplaza a los tests, pero es un primer filtro.

## Coverage

El coverage de backend se genera con Jest:

```bash
docker compose exec api npm run test:cov
```

Genera el reporte en `src/api/coverage/`. Todavía no hay umbral mínimo configurado; cuando la suite madure se puede agregar `coverageThreshold` en la config de Jest (`src/api/package.json`).

## Anti-patrones

- **Tests unitarios que necesitan la DB real.** Lentos y flaky en CI. Si el caso lo requiere de verdad, ponelo en `test:e2e`, no en unit.
- **Mockear tanto que el test no prueba nada.** Si el mock contradice el contrato real del service, el test pasa pero el sistema rompe. Para esos casos vale más un e2e corto.
- **`expect(...).toBeDefined()` y nada más.** No prueba comportamiento. Afirmá valores concretos, excepciones esperadas, o llamadas a los mocks con argumentos puntuales.

## Relacionado

- [ARCHITECTURE.md](ARCHITECTURE.md) — módulos del backend y niveles del frontend.
- [DEVELOPMENT.md](DEVELOPMENT.md) — flujo de desarrollo y cómo agregar módulos/componentes.
- [DOCKER.md](DOCKER.md) — correr comandos dentro de los contenedores.
- [STORYBOOK.md](STORYBOOK.md) — banco de trabajo de componentes (complementa a los tests de frontend).
