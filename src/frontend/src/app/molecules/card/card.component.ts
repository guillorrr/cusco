import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-card',
  standalone: true,
  template: `
    <div class="card">
      @if (imageUrl) {
        <img [src]="imageUrl" [alt]="title" class="card-img-top" />
      }
      <div class="card-body">
        @if (title) {
          <h5 class="card-title">{{ title }}</h5>
        }
        @if (subtitle) {
          <h6 class="card-subtitle mb-2 text-body-secondary">{{ subtitle }}</h6>
        }
        <div class="card-text">
          <ng-content />
        </div>
      </div>
      <ng-content select="[card-footer]" />
    </div>
  `,
})
export class CardComponent {
  @Input() title = '';
  @Input() subtitle = '';
  @Input() imageUrl = '';
}
