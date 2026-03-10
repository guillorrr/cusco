import type { Meta, StoryObj } from '@storybook/angular';
import { InputComponent } from './input.component';

const meta: Meta<InputComponent> = {
  title: 'Atoms/Input',
  component: InputComponent,
  tags: ['autodocs'],
  argTypes: {
    type: {
      control: 'select',
      options: ['text', 'email', 'password', 'number', 'tel', 'url', 'search'],
    },
  },
};

export default meta;
type Story = StoryObj<InputComponent>;

export const Default: Story = {
  args: {
    label: 'Email',
    type: 'email',
    placeholder: 'you@example.com',
    id: 'email-input',
  },
};

export const WithHint: Story = {
  args: {
    label: 'Password',
    type: 'password',
    placeholder: '••••••••',
    hint: 'Minimum 6 characters',
    id: 'password-input',
  },
};

export const WithError: Story = {
  args: {
    label: 'Email',
    type: 'email',
    placeholder: 'you@example.com',
    error: 'Please enter a valid email address',
    id: 'email-error',
  },
};

export const Disabled: Story = {
  args: {
    label: 'Username',
    type: 'text',
    placeholder: 'Disabled field',
    disabled: true,
    id: 'disabled-input',
  },
};

export const AllStates: Story = {
  render: () => ({
    template: `
      <div style="display: flex; flex-direction: column; gap: 16px; min-width: 320px;">
        <app-input label="Default" placeholder="Type something..." id="s-default"></app-input>
        <app-input label="With hint" placeholder="you@example.com" hint="We won't share your email" id="s-hint"></app-input>
        <app-input label="With error" placeholder="you@example.com" error="This field is required" id="s-error"></app-input>
        <app-input label="Disabled" placeholder="Can't touch this" [disabled]="true" id="s-disabled"></app-input>
        <app-input label="Password" type="password" placeholder="••••••••" id="s-password"></app-input>
      </div>
    `,
  }),
};
