import { Component, Input } from '@angular/core';
import { InputComponent, InputType } from '../../atoms/input/input.component';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-form-field',
  standalone: true,
  imports: [InputComponent, FormsModule],
  template: `
    <app-input
      [label]="label"
      [type]="type"
      [placeholder]="placeholder"
      [id]="id"
      [error]="error"
      [hint]="hint"
      [disabled]="disabled"
      [(ngModel)]="value"
    />
  `,
})
export class FormFieldComponent {
  @Input() label = '';
  @Input() type: InputType = 'text';
  @Input() placeholder = '';
  @Input() id = '';
  @Input() error = '';
  @Input() hint = '';
  @Input() disabled = false;
  @Input() value = '';
}
