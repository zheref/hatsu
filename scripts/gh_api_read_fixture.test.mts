import { test } from 'vitest';

test('audited GitHub reads accept fixed queries and reject mutations before gh runs', async () => {
  await import('./gh_api_read_fixture.mts');
});
