/**
 * Jest configuration for the trusted Cloud Functions package.
 *
 * Tests live alongside source files as `*.test.ts` and exercise the PURE,
 * backend-agnostic helpers (separated from the Firebase trigger wiring) so
 * that `fast-check` property tests can run without any emulator or network.
 */
/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/*.test.ts'],
  clearMocks: true,
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.test.ts', '!src/index.ts'],
};
