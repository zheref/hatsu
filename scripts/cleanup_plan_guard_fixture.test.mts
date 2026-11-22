import { test } from 'vitest';
import { cleanupPlanGuardCases } from './cleanup_plan_guard_cases.mts';

for (const c of cleanupPlanGuardCases) {
  test(c.name, c.run, 30_000);
}
