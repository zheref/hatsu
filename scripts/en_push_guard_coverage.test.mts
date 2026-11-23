import { test } from 'node:test';
import { enPushGuardCases } from './en_push_guard_cases.mts';

// Exact-source instrumentation for scripts/en_push_guard.mts (UZF-19);
// Vitest owns the authoritative BC-9 suite in en_push_guard_fixture.test.mts.
for (const c of enPushGuardCases) {
  test(c.name, c.run);
}
