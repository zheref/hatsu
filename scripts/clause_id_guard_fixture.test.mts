import { test } from 'vitest';
import { runClauseIdGuardFixture } from './clause_id_guard_fixture.mts';

test('the clause guard holds its parser, CLI and failure boundaries', () => {
  runClauseIdGuardFixture();
});
