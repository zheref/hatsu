import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { runInventoryFixture } from './ruling_record_fixture.mts';

// Both child CLI paths inherit Node's native capture. Vitest owns the inventory verdict.
test('capture the historical CLI and real Nen cases', () => {
  const fixture = fileURLToPath(new URL('./ruling_record_fixture.mts', import.meta.url));
  const result = spawnSync(process.execPath, [fixture], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /ruling-record fixture: [1-9]\d* cases passed/);
  process.stdout.write(result.stdout);
});
test('capture the HR inventory and render paths', runInventoryFixture);
