import { test } from 'vitest';
import { runConstitutionCheckFixture } from './constitution_check_fixture.mts';

test('the constitution check lists its read set, its record and its refusals', () => {
  runConstitutionCheckFixture();
});
