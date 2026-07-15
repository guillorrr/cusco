import { Component, Input, forwardRef } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR, FormsModule } from '@angular/forms';
import { NgClass } from '@angular/common';

export type InputType = 'text' | 'email' | 'password' | 'number' | 'tel' | 'url' | 'search';

@Component({
  selector: 'app-input',
  standalone: true,
  imports: [NgClass, FormsModule],
  providers: [
    {
      provide: NG_VALUE_ACCESSOR,
      useExisting: forwardRef(() => InputComponent),
      multi: true,
    },
  ],
  template: `
    <div class="mb-3">
      @if (label) {
        <label [for]="id" class="form-label">{{ label }}</label>
      }
      <input
        [id]="id"
        [type]="type"
        [ngClass]="['form-control', error ? 'is-invalid' : '']"
        [placeholder]="placeholder"
        [disabled]="disabled"
        [ngModel]="value"
        (ngModelChange)="onValueChange($event)"
        (blur)="onTouched()"
      />
      @if (error) {
        <div class="invalid-feedback">{{ error }}</div>
      }
      @if (hint && !error) {
        <div class="form-text">{{ hint }}</div>
      }
    </div>
  `,
})
export class InputComponent implements ControlValueAccessor {
  @Input() label = '';
  @Input() type: InputType = 'text';
  @Input() placeholder = '';
  @Input() id = '';
  @Input() error = '';
  @Input() hint = '';
  @Input() disabled = false;

  value = '';
  // No-op until the forms API registers the real callbacks.
  onChange: (value: string) => void = () => undefined;
  onTouched: () => void = () => undefined;

  onValueChange(val: string) {
    this.value = val;
    this.onChange(val);
  }

  writeValue(value: string): void {
    this.value = value || '';
  }

  registerOnChange(fn: (value: string) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(isDisabled: boolean): void {
    this.disabled = isDisabled;
  }
}
