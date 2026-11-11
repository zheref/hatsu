import { test } from 'node:test';
import { runHistoryFixture } from './prose_lint_history_fixture.mts';

test('Report the canon baseline shrink from merged prose pull requests', runHistoryFixture);
