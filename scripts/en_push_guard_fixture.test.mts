import { test } from 'vitest';
import { enPushGuardCases } from './en_push_guard_cases.mts';

for (const c of enPushGuardCases) {
  test(c.name, c.run, 30_000);
}
