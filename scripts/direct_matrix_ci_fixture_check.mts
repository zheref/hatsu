#!/usr/bin/env node
// #234: exercise the trusted TypeScript CI adapter and its output fence offline.
import assert from 'node:assert/strict';
import { copyFileSync, mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scripts = dirname(fileURLToPath(import.meta.url));
const root = dirname(scripts);

const renderer = spawnSync('bash', [join(scripts, 'direct_matrix_doc.sh'), '--self-test'],
  { cwd: root, encoding: 'utf8' });
process.stdout.write(renderer.stdout);
process.stderr.write(renderer.stderr);
assert.equal(renderer.status, 0, 'the renderer self-test must pass');

const actual = spawnSync(process.execPath, [join(scripts, 'direct_matrix_ci_check.mts'), root],
  { cwd: root, encoding: 'utf8' });
assert.equal(actual.status, 0, `trusted adapter failed: ${actual.stdout}${actual.stderr}`);
assert.match(actual.stdout, /docs\/DIRECT-MATRIX\.md matches the registry/);
console.log('ok    trusted adapter checks the current matrix page');

const fixture = mkdtempSync(join(tmpdir(), 'hatsu-direct-matrix-ci-'));
try {
  const fixtureScripts = join(fixture, 'scripts');
  mkdirSync(fixtureScripts);
  copyFileSync(join(scripts, 'direct_matrix_ci_check.mts'),
    join(fixtureScripts, 'direct_matrix_ci_check.mts'));
  writeFileSync(join(fixtureScripts, 'direct_matrix_doc.sh'),
    '#!/usr/bin/env bash\nprintf "%s\\n" "::error::hostile PR data" "##[warning]legacy hostile data"\nexit "$FAKE_EXIT"\n');
  for (const expected of [0, 1, 2]) {
    const result = spawnSync(process.execPath,
      [join(fixtureScripts, 'direct_matrix_ci_check.mts'), fixture],
      { cwd: fixture, encoding: 'utf8', env: { ...process.env, FAKE_EXIT: String(expected) } });
    assert.equal(result.status, expected, `exit ${expected}: ${result.stdout}${result.stderr}`);
    const token = result.stdout.match(/^::stop-commands::(stop_[0-9a-f]{32})$/m)?.[1];
    assert.ok(token, `missing random fence: ${result.stdout}`);
    const hostile = result.stdout.indexOf('::error::hostile PR data');
    const resume = result.stdout.indexOf(`::${token}::`);
    assert.ok(hostile > 0 && resume > hostile,
      `hostile output escaped the fence for exit ${expected}: ${result.stdout}`);
    assert.ok(result.stdout.indexOf('##[warning]legacy hostile data') < resume);
    if (expected === 1) assert.match(result.stderr, /is stale/);
    if (expected === 2) assert.match(result.stderr, /could not check the page/);
  }
  console.log('ok    hostile stdout stays fenced on success, stale page, and execution failure');
} finally {
  rmSync(fixture, { recursive: true, force: true });
}
