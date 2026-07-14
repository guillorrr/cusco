import { Component, Input, Output, EventEmitter } from '@angular/core';
import { NgClass } from '@angular/common';

export type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'danger' | 'ghost';
export type ButtonSize = 'sm' | 'md' | 'lg';

@Component({
  selector: 'app-button',
  standalone: true,
  imports: [NgClass],
  template: `
    <button [ngClass]="classes" [disabled]="disabled" [type]="type" (click)="clicked.emit($event)">
      <ng-content />
    </button>
  `,
  styles: [
    `
      :host {
        display: inline-block;
      }
    `,
  ],
})
export class ButtonComponent {
  @Input() variant: ButtonVariant = 'primary';
  @Input() size: ButtonSize = 'md';
  @Input() disabled = false;
  @Input() type: 'button' | 'submit' | 'reset' = 'button';
  @Output() clicked = new EventEmitter<Event>();

  get classes(): string[] {
    return [
      'btn',
      `btn-${this.variant === 'outline' ? 'outline-primary' : this.variant}`,
      this.size === 'sm' ? 'btn-sm' : this.size === 'lg' ? 'btn-lg' : '',
    ].filter(Boolean);
  }
}
