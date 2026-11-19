import eslint from '@eslint/js';
import { defineConfig } from 'eslint/config';
import tseslint from 'typescript-eslint';

export default defineConfig(
  { ignores: ['out/', 'dist/', 'node_modules/'] },
  eslint.configs.recommended,
  tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
    },
    rules: {
      curly: 'error',
      eqeqeq: 'error',
      '@typescript-eslint/no-floating-promises': ['error', {
        // node:test's describe/it return promises the test runner itself awaits.
        allowForKnownSafeCalls: [{ from: 'package', name: ['describe', 'it'], package: 'node:test' }],
      }],
      '@typescript-eslint/consistent-type-imports': ['error', { fixStyle: 'inline-type-imports' }],
    },
  },
  {
    files: ['eslint.config.mjs'],
    extends: [tseslint.configs.disableTypeChecked],
  },
);
