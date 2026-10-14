/** Jest runs native ES modules (see the `test` script's --experimental-vm-modules flag). */
export default {
  testEnvironment: 'node',
  transform: {},
  testMatch: ['**/tests/**/*.test.js'],
  globalSetup: './tests/helpers/globalSetup.js',
  globalTeardown: './tests/helpers/globalTeardown.js',
  setupFiles: ['./tests/helpers/env.js'],
  testTimeout: 30000,
};
