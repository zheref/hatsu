import { test } from 'vitest';
import { amaterasuPreviewCases } from './amaterasu_preview_cases.mts';

for (const c of amaterasuPreviewCases) {
  test(c.name, c.run, 30_000);
}
