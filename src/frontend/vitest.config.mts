import angular from '@analogjs/vite-plugin-angular';
import { defineConfig } from 'vitest/config';

// Angular 19 unit tests run on Vitest + jsdom (no browser) via the AnalogJS
// vite plugin. See .project/stack.yaml for why Vitest over Karma/Jasmine.
export default defineConfig(({ mode }) => ({
  plugins: [angular()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['src/test-setup.ts'],
    include: ['src/**/*.spec.ts'],
    reporters: ['default'],
  },
  define: {
    'import.meta.vitest': mode !== 'production',
  },
}));
