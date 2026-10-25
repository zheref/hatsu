### Fixed

- The `unit-tests-ci-guard` and `gh-api-read-guard` lanes now refuse before spawning when Vitest is absent, naming `node_modules/vitest/vitest.mjs` and the locked `npm ci --ignore-scripts` install that CI already performs. Closes #416.
