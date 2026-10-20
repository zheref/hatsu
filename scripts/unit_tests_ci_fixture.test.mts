#!/usr/bin/env node
// Hermetic tests for the trusted CI runner's decisions and failure boundary.
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { test } from 'vitest';

test('trusted runner selects focused lanes and fails closed', () => {
const dir = mkdtempSync(join(tmpdir(), 'hatsu-unit-tests-ci-'));
const repo = join(dir, 'pr');
const nen = join(dir, 'nen-stub');
const log = join(dir, 'lanes');
const runner = join(import.meta.dirname, 'unit_tests_ci.mts');
mkdirSync(join(repo, 'nen'), { recursive: true });
mkdirSync(join(repo, 'scripts'));
writeFileSync(join(repo, 'nen', 'contract.json'), '{}\n');
writeFileSync(nen, '#!/bin/sh\nprintf "%s|%s|%s\\n" "$6" "${GH_TOKEN:-}" "${GITHUB_TOKEN:-}" >> "$HATSU_LANE_LOG"\necho "::warning title=forged::from PR code"\n[ "$6" != "${HATSU_FAIL_LANE:-}" ]\n');
chmodSync(nen, 0o755);

function run(extraEnv: Record<string, string> = {}, nenPath = nen) {
  return spawnSync(process.execPath, [runner, repo, nenPath], {
    encoding: 'utf8',
    env: { ...process.env, HATSU_LANE_LOG: log, GH_TOKEN: 'host-secret', GITHUB_TOKEN: 'host-token', ...extraEnv },
  });
}
function assert(ok: boolean, message: string): void {
  if (!ok) throw new Error(message);
}
try {
  let result = run();
  assert(result.status === 0, `baseline refused: ${result.stderr}`);
  let calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||', 'wrong baseline lanes or leaked token');
  const fence = result.stdout.match(/::stop-commands::(unit_tests_[0-9a-f]{32})/);
  assert(!!fence && result.stdout.includes(`::${fence[1]}::`) &&
    result.stdout.indexOf(`::stop-commands::${fence[1]}`) < result.stdout.indexOf('::warning title=forged::') &&
    result.stdout.indexOf('::warning title=forged::') < result.stdout.indexOf(`::${fence[1]}::`),
  'PR-controlled output was not fenced');

  writeFileSync(join(repo, 'scripts', 'gh_api_read.mts'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('no required fixture'), 'missing API fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'gh_api_read_fixture.mts'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `API fixture path refused: ${result.stderr}`);
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||,gh-api-read-guard||', 'API lane not selected');

  result = run({ HATSU_FAIL_LANE: 'permissions-pack-guard' });
  assert(result.status === 1 && result.stderr.includes('permissions-pack-guard failed'), 'failing lane was not red');
  result = run({}, join(dir, 'missing-nen'));
  assert(result.status === 1 && result.stderr.includes('unit-tests-ci-guard failed'), 'missing Nen was not red');
  rmSync(join(repo, 'nen', 'contract.json'));
  result = run();
  assert(result.status === 2 && result.stderr.includes('no nen/contract.json'), 'missing declaration did not refuse');
} finally {
  rmSync(dir, { recursive: true, force: true });
}
});
