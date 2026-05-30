# Storybook

## ¿Qué es Storybook y qué es una "story"?

Storybook es un "banco de trabajo" para construir componentes de UI **aislados** de la app. En lugar de levantar todo Angular, hacer login y navegar hasta la pantalla donde aparece un botón, lo ves directamente en un catálogo en el navegador.

Una **story** (historia) es un ejemplo concreto de un componente en un estado puntual: "el botón primario", "el botón deshabilitado", "el botón chico". Un mismo componente suele tener varias stories, una por estado relevante. Storybook lee esas stories y arma una galería navegable.

¿Por qué nos importa? Porque desacopla la maquetación del estado del backend. Podés diseñar y validar un átomo o una molécula **antes** de integrarlos en una page, sin depender de la base de datos ni de la API.

En Cusco usamos Storybook 10 con el framework de Angular. El proyecto sigue [Atomic Design](ARCHITECTURE.md): los componentes se organizan en `atoms/`, `molecules/`, `organisms/`, `templates/` y `pages/`, y las stories reflejan esa jerarquía.

## URL

http://localhost:6006 (con el stack arriba; ver [DOCKER.md](DOCKER.md)).

## Levantarlo

Storybook ya viene como servicio del Docker Compose, así que `npm start` lo deja andando junto con el resto. Si querés solo Storybook:

```bash
npm run storybook         # levanta el servicio storybook + sigue sus logs
```

Para un build estático (sirve para chequear que todo compila sin el dev server, por ejemplo en CI):

```bash
npm run storybook:build
```

Si necesitás seguir los logs aparte:

```bash
npm run logs:storybook
```

## Estructura de un componente con su story

Las stories se **co-localizan**: viven al lado del componente que documentan. Storybook las detecta con el patrón `src/**/*.stories.ts` (definido en `src/frontend/.storybook/main.ts`).

```
src/frontend/src/app/atoms/button/
├── button.component.ts
├── button.component.scss
└── button.stories.ts          ← la story vive acá, junto al componente
```

## Ejemplo real: el ButtonComponent de Cusco

Antes de escribir una story conviene mirar el componente. Este es el `ButtonComponent` real de Cusco (`src/frontend/src/app/atoms/button/button.component.ts`):

- Es **standalone** (sin NgModule), selector `app-button`.
- Recibe el texto por **proyección de contenido** con `<ng-content />`. Es decir, el texto va *adentro* de la etiqueta (`<app-button>Texto</app-button>`), **no** por un `@Input` `label`.
- `@Input()` disponibles:
  - `variant`: `'primary' | 'secondary' | 'outline' | 'danger' | 'ghost'` (default `'primary'`)
  - `size`: `'sm' | 'md' | 'lg'` (default `'md'`)
  - `disabled`: `boolean` (default `false`)
  - `type`: `'button' | 'submit' | 'reset'` (default `'button'`)
- `@Output()`: `onClick: EventEmitter<Event>` — emite el evento de click.

Como el texto va por `<ng-content />`, las stories usan un `render` con `template` para poder proyectar contenido (los `args` por sí solos no pueden insertar contenido proyectado). Así se ve la story real (`button.stories.ts`):

```ts
import type { Meta, StoryObj } from '@storybook/angular';
import { ButtonComponent } from './button.component';

const meta: Meta<ButtonComponent> = {
  title: 'Atoms/Button',
  component: ButtonComponent,
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: ['primary', 'secondary', 'outline', 'danger', 'ghost'],
    },
    size: {
      control: 'select',
      options: ['sm', 'md', 'lg'],
    },
    disabled: { control: 'boolean' },
    type: {
      control: 'select',
      options: ['button', 'submit', 'reset'],
    },
  },
};

export default meta;
type Story = StoryObj<ButtonComponent>;

// Una story por estado. El texto va por proyección (<ng-content />),
// por eso cada story usa un `render` con `template` en vez de solo `args`.
export const Primary: Story = {
  args: { variant: 'primary', size: 'md', disabled: false },
  render: (args) => ({
    props: args,
    template: `<app-button [variant]="variant" [size]="size" [disabled]="disabled">Button</app-button>`,
  }),
};

export const Secondary: Story = {
  args: { variant: 'secondary', size: 'md' },
  render: (args) => ({
    props: args,
    template: `<app-button [variant]="variant" [size]="size">Secondary</app-button>`,
  }),
};

export const Outline: Story = {
  args: { variant: 'outline', size: 'md' },
  render: (args) => ({
    props: args,
    template: `<app-button [variant]="variant" [size]="size">Outline</app-button>`,
  }),
};

export const Disabled: Story = {
  args: { variant: 'primary', size: 'md', disabled: true },
  render: (args) => ({
    props: args,
    template: `<app-button [variant]="variant" [size]="size" [disabled]="disabled">Disabled</app-button>`,
  }),
};

// También se pueden comparar variaciones en una sola story:
export const AllVariants: Story = {
  render: () => ({
    template: `
      <div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap;">
        <app-button variant="primary">Primary</app-button>
        <app-button variant="secondary">Secondary</app-button>
        <app-button variant="outline">Outline</app-button>
        <app-button variant="danger">Danger</app-button>
        <app-button variant="ghost">Ghost</app-button>
        <app-button variant="primary" [disabled]="true">Disabled</app-button>
      </div>
    `,
  }),
};
```

Cosas a notar:

- **`title: 'Atoms/Button'`** ubica el componente en la galería bajo el grupo `Atoms`.
- **`tags: ['autodocs']`** genera automáticamente una página de documentación a partir de los tipos del componente.
- **`argTypes`** convierte los inputs en controles interactivos (un `select` para `variant`, `size` y `type`, un toggle para `disabled`) que podés tocar en vivo en el panel de Storybook.
- **El `render` con `template`** es necesario porque el texto del botón se proyecta con `<ng-content />`: los `args` por sí solos no pueden insertar contenido proyectado.

Para una molécula, mirá el `CardComponent` real (`src/frontend/src/app/molecules/card/card.component.ts`): tiene `@Input()` `title`, `subtitle` e `imageUrl`, proyecta el cuerpo con `<ng-content />` y un footer con `<ng-content select="[card-footer]" />`. Su story (`card.stories.ts`) usa `title: 'Molecules/Card'` y stories como `Default`, `WithSubtitle`, `WithFooter` y `CardGrid`.

## Convenciones

- **Title:** `Atoms/<Nombre>`, `Molecules/<Nombre>`, `Organisms/<Nombre>`, `Pages/<Nombre>`. Refleja el nivel de Atomic Design (ver [ARCHITECTURE.md](ARCHITECTURE.md)).
- **Tag `autodocs`:** todo componente lo lleva (`tags: ['autodocs']`); genera la página de docs automáticamente desde el TS.
- **Stories por estado, no por uso:** `Primary`, `Disabled`, `Sizes`, `Loading`, `Error`... NO `EnLaHome`, `EnElLogin`. La story describe *cómo se ve el componente*, no *dónde se usa*.
- **No mockear el backend en una story.** Si un componente necesita datos, pasáselos por `@Input`. Si necesita un service, mockealo con `applicationConfig` (ver abajo).

## ¿Qué es un mock y cómo mockear un service en una story?

Un **mock** es un objeto falso que reemplaza a una dependencia real para una prueba. En vez del `AuthService` de verdad (que llamaría a la API), le damos un objeto con apenas lo que el componente usa. Así la story queda determinística y no depende de la red ni de la base de datos.

En Storybook, los servicios se inyectan con `applicationConfig`, que pisa los providers de Angular solo para esa story:

```ts
import type { Meta } from '@storybook/angular';
import { applicationConfig } from '@storybook/angular';
import { AuthService } from '@core/services/auth.service';
import { HeaderComponent } from './header.component';

const meta: Meta<HeaderComponent> = {
  title: 'Organisms/Header',
  component: HeaderComponent,
  decorators: [
    applicationConfig({
      providers: [
        // Mock: solo lo que el componente realmente lee.
        { provide: AuthService, useValue: { user: { email: 'demo@cusco.local' } } },
      ],
    }),
  ],
};

export default meta;
```

(El `HeaderComponent` es ilustrativo; usá el alias `@core/*` para importar servicios, según las convenciones del proyecto.)

## Workflow recomendado

1. Decidí el nivel Atomic Design correcto: un botón es `atom`; un `<form>` que combina varios atoms es `molecule`; el header completo es `organism`.
2. Generá el componente dentro del contenedor de frontend:
   ```bash
   docker compose exec frontend npx ng g c atoms/<nombre> --standalone
   ```
3. Co-localizá `<nombre>.stories.ts` al lado del componente.
4. Desarrollalo en Storybook hasta que se vea bien en sus estados clave (`Default`, `Disabled`, etc.).
5. Validá visualmente con UX/UI sobre http://localhost:6006.
6. Recién entonces integralo en una page (ver el flujo en [DEVELOPMENT.md](DEVELOPMENT.md)).

## Addons habilitados

En `src/frontend/.storybook/main.ts` está habilitado un único addon:

- **`@storybook/addon-a11y`** — chequeo de accesibilidad sobre cada story.

Es deliberadamente mínimo: solo a11y, nada más. Más addons = más superficie de mantenimiento; agregá uno solo cuando un caso concreto lo justifique.

## Anti-patrones

- **Stories con datos reales del backend.** Rompen la independencia del dev server y se vuelven flaky. Mockeá todo (inputs o `applicationConfig`).
- **Lógica de negocio en componentes de UI.** Los atoms y molecules deben ser "tontos": reciben `@Input` y emiten `@Output`. Si un átomo necesita un service, es señal de que pertenece a un nivel más arriba.
- **Componentes "Page" en Storybook.** Las pages se prueban end-to-end con la app, no en Storybook. Excepción: templates/layouts que valga la pena documentar visualmente.
- **Pasar texto del botón por un `@Input` inexistente.** El `ButtonComponent` usa `<ng-content />`; el texto va dentro de la etiqueta, no por `label`.

## Relacionado

- [ARCHITECTURE.md](ARCHITECTURE.md) — niveles de Atomic Design del frontend.
- [DEVELOPMENT.md](DEVELOPMENT.md) — flujo de trabajo para agregar componentes y pages.
- [DOCKER.md](DOCKER.md) — servicios del stack, incluido `storybook`.
- [TESTING.md](TESTING.md) — cómo testear los componentes que diseñás acá.
