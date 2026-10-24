import { test } from 'vitest';

test('a provider tag resolves to its commit, annotated or lightweight', async () => {
  await import('./provider_tag_commit_fixture.mts');
});
