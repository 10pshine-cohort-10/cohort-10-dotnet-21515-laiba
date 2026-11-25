# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

Linting runs via `npm run lint` (`eslint .`), configured in [`eslint.config.js`](./eslint.config.js). It currently extends `tseslint.configs.recommended` - type-aware lint rules are **not** enabled.

If you are developing a production application, we recommend enabling type-aware lint rules by switching to a type-checked config in `eslint.config.js`:

```js
export default tseslint.config(
  { ignores: ['dist', 'coverage'] },
  {
    extends: [
      js.configs.recommended,
      // Replace tseslint.configs.recommended with one of these:
      ...tseslint.configs.recommendedTypeChecked,
      // ...tseslint.configs.strictTypeChecked,
    ],
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2020,
      globals: globals.browser,
      parserOptions: {
        project: ['./tsconfig.app.json', './tsconfig.node.json'],
        tsconfigRootDir: import.meta.dirname,
      },
    },
    // ...
  },
  eslintConfigPrettier,
)
```

See the [typescript-eslint docs](https://typescript-eslint.io/getting-started/typed-linting/) for details on typed linting.
