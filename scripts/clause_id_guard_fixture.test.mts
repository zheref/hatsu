import { test } from 'vitest';
import { runClauseIdGuardFixture } from './clause_id_guard_fixture.mts';

test('the clause guard holds its parser, CLI and failure boundaries', () => {
  runClauseIdGuardFixture();
  // Spawns ~54 synchronous child node processes; Vitest's 5 s default times out on CI (zheref/hatsu#533).
}, 60_000);
