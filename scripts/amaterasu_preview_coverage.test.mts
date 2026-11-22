import { test } from 'node:test';
import { amaterasuPreviewCases } from './amaterasu_preview_cases.mts';

// Exact-source instrumentation for scripts/amaterasu_preview.mts (UZF-19);
// Vitest owns the authoritative BC-9 suite in amaterasu_preview_fixture.test.mts.
for (const c of amaterasuPreviewCases) {
  test(c.name, c.run);
}
