import { test } from 'node:test';
import { pluginBumpApiRetryFixtureCases } from './plugin_bump_api_retry_fixture.mts';

// Supplemental exact-source instrumentation only. Vitest owns the verdict;
// this serial replay runs the same exported behavior cases solely for LCOV.
for (const fixture of pluginBumpApiRetryFixtureCases) {
  test(fixture.name, fixture.run);
}
