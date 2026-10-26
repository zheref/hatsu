import { test } from 'vitest';
import { pluginBumpApiRetryFixtureCases } from './plugin_bump_api_retry_fixture.mts';

for (const fixture of pluginBumpApiRetryFixtureCases) {
  test(fixture.name, fixture.run);
}
