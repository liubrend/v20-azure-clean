import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { AppComponent } from './app.component';

describe('AppComponent', () => {
  it('creates the component', async () => {
    await TestBed.configureTestingModule({
      imports: [AppComponent],
    }).compileComponents();

    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance).toBeTruthy();
  });

  it('renders the title in the template', async () => {
    await TestBed.configureTestingModule({
      imports: [AppComponent],
    }).compileComponents();

    const fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();

    const heading = fixture.nativeElement.querySelector('h1');
    expect(heading.textContent).toContain('v19-GCP-clean-teamsEnabled');
  });
});
