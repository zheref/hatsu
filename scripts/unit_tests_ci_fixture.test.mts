import { test } from 'vitest';
import { checkUnitTestsDispatcher } from './unit_tests_ci_fixture.mts';

// The fixture starts the dispatcher repeatedly, so give it room on a loaded host (zheref/hatsu#533).
test('trusted runner selects focused lanes and fails closed', checkUnitTestsDispatcher, 60_000);
