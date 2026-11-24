import { test } from 'node:test';
import { cleanupPlanGuardCases } from './cleanup_plan_guard_cases.mts';

// Exact-source instrumentation for scripts/cleanup_plan_guard.mts (UZF-19);
// Vitest owns the authoritative BC-9 suite in cleanup_plan_guard_fixture.test.mts.
for (const c of cleanupPlanGuardCases) {
  test(c.name, c.run);
}
