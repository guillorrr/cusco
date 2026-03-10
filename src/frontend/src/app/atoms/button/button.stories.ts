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

export const Danger: Story = {
  args: { variant: 'danger', size: 'md' },
  render: (args) => ({
    props: args,
    template: `<app-button [variant]="variant" [size]="size">Danger</app-button>`,
  }),
};

export const Small: Story = {
  args: { variant: 'primary', size: 'sm' },
  render: (args) => ({
    props: args,
    template: `<app-button [variant]="variant" [size]="size">Small</app-button>`,
  }),
};

export const Large: Story = {
  args: { variant: 'primary', size: 'lg' },
  render: (args) => ({
    props: args,
    template: `<app-button [variant]="variant" [size]="size">Large</app-button>`,
  }),
};

export const Disabled: Story = {
  args: { variant: 'primary', size: 'md', disabled: true },
  render: (args) => ({
    props: args,
    template: `<app-button [variant]="variant" [size]="size" [disabled]="disabled">Disabled</app-button>`,
  }),
};

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
