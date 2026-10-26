import { test } from 'vitest';
import { runHantenFindingsFixture } from './hanten_findings_check_fixture.mts';

test('the Hanten findings checker holds its policy, CLI and failure boundaries', () => {
  runHantenFindingsFixture();
});
