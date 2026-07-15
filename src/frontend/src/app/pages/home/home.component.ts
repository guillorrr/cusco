import { Component } from '@angular/core';
import { environment } from '@env/environment';

@Component({
  selector: 'app-home',
  standalone: true,
  template: `
    <div class="container py-5">
      <h1>{{ appName }}</h1>
      <p class="lead">Scaffold ready. Start building.</p>
    </div>
  `,
})
export class HomeComponent {
  readonly appName = environment.appName;
}
