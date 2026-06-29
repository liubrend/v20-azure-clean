import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  standalone: true,
  template: `<h1>{{ title }}</h1>`,
})
export class AppComponent {
  readonly title = 'v20-Azure-clean-teamsEnabled';
}
