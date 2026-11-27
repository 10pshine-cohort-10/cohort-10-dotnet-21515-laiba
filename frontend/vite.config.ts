/// <reference types="vitest/config" />
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/setupTests.ts',
    // No tests exist yet in Phase 0 (no screens/logic) - don't fail the run for that.
    passWithNoTests: true,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      reportsDirectory: './coverage',
      include: ['src/**/*.{ts,tsx}'],
      exclude: [
        'src/main.tsx',
        '**/*.test.*',
        '**/*.spec.*',
        '**/*.d.ts',
        // src/types/ holds only type definitions per the frontend-conventions
        // skill - no runtime logic is ever placed there.
        'src/types/**',
      ],
    },
  },
})
