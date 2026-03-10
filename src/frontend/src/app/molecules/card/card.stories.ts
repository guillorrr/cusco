import type { Meta, StoryObj } from '@storybook/angular';
import { CardComponent } from './card.component';
import { ButtonComponent } from '../../atoms/button/button.component';

const meta: Meta<CardComponent> = {
  title: 'Molecules/Card',
  component: CardComponent,
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<CardComponent>;

export const Default: Story = {
  args: { title: 'Card title' },
  render: (args) => ({
    props: args,
    template: `
      <div style="max-width: 320px;">
        <app-card [title]="title">
          <p>Some quick example text to build on the card title and make up the bulk of the card's content.</p>
        </app-card>
      </div>
    `,
  }),
};

export const WithSubtitle: Story = {
  args: { title: 'Card title', subtitle: 'Card subtitle' },
  render: (args) => ({
    props: args,
    template: `
      <div style="max-width: 320px;">
        <app-card [title]="title" [subtitle]="subtitle">
          <p>Some quick example text to build on the card title.</p>
        </app-card>
      </div>
    `,
  }),
};

export const WithFooter: Story = {
  args: { title: 'Card title' },
  render: (args) => ({
    moduleMetadata: { imports: [ButtonComponent] },
    props: args,
    template: `
      <div style="max-width: 320px;">
        <app-card [title]="title">
          <p>Some quick example text.</p>
          <div card-footer class="card-footer">
            <app-button variant="primary" size="sm">Action</app-button>
          </div>
        </app-card>
      </div>
    `,
  }),
};

export const CardGrid: Story = {
  render: () => ({
    template: `
      <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; max-width: 960px;">
        <app-card title="Feature One">
          <p>Description of the first feature.</p>
        </app-card>
        <app-card title="Feature Two">
          <p>Description of the second feature.</p>
        </app-card>
        <app-card title="Feature Three">
          <p>Description of the third feature.</p>
        </app-card>
      </div>
    `,
  }),
};
