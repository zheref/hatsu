import { test } from 'vitest';
import { runInventoryFixture } from './ruling_record_fixture.mts';

test('allocates from visible HR holders and refuses ambiguous reads and competing claims', runInventoryFixture, 30_000);
