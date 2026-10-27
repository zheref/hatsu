import { test } from 'vitest';
import { runTypedMatrixFixture, runMatrixRuleFixture, runDatedEvidenceFixture } from './direct_matrix_doc_fixture.mts';

test('typed renderer preserves page bytes and refuses malformed or hostile input', () => {
  runTypedMatrixFixture();
});

test('typed renderer preserves the existing rule edges and registry invariants', () => {
  runMatrixRuleFixture();
});

test('dated evidence reaches the verdict and expired steps fail the renderer and trusted CI', () => {
  runDatedEvidenceFixture();
});
