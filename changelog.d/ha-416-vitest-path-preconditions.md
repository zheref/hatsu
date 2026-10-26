### Fixed

- The `unit-tests-ci-guard` and `gh-api-read-guard` lanes now refuse before spawning when Vitest is absent, name `node_modules/vitest/vitest.mjs`, and carry the locked `npm ci --ignore-scripts` install reason that CI already satisfies. Printing that reason in Nen's refusal is pending [zheref/nen#542](https://github.com/zheref/nen/issues/542) and a later repin. Part of #416.
