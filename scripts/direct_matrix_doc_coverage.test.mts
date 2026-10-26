import { test } from 'node:test';
import { runTypedMatrixFixture, runMatrixRuleFixture } from './direct_matrix_doc_fixture.mts';

// Supplemental exact-source instrumentation only; Vitest owns the fixture verdict.
// No coverage is inherited or claimed from the authoritative Vitest process.
test('replay the typed renderer fixtures in this Node process for native LCOV', () => {
  runTypedMatrixFixture();
  runMatrixRuleFixture();
});
