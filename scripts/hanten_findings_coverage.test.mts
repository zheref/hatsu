import { test } from 'node:test';
import { runClauseIdGuardFixture } from './clause_id_guard_fixture.mts';
import { runHantenFindingsFixture } from './hanten_findings_check_fixture.mts';

// Supplemental exact-source instrumentation only. Vitest owns the guard verdict;
// this serial replay neither inherits nor claims coverage from Vitest's process.
test('capture the Hanten checker and reused clause parser in this Node process', () => {
  runHantenFindingsFixture();
  runClauseIdGuardFixture();
});
