import { test } from 'node:test';
import { checkUnitTestsDispatcher } from './unit_tests_ci_fixture.mts';

test('trusted runner selects focused lanes and fails closed', { timeout: 60_000 }, checkUnitTestsDispatcher);
