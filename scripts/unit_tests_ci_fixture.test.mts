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
writeFileSync(nen, '#!/bin/sh\nprintf "%s|%s|%s\\n" "$6" "${GH_TOKEN:-}" "${GITHUB_TOKEN:-}" >> "$HATSU_LANE_LOG"\n[ -z "${HATSU_PATH_LOG:-}" ] || printf "%s|%s|%s\\n" "$6" "${PATH%%:*}" "${NEN:-}" >> "$HATSU_PATH_LOG"\necho "::warning title=forged::from PR code"\n[ "$6" != "${HATSU_FAIL_LANE:-}" ]\n');
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

  writeFileSync(join(repo, 'scripts', 'clause_id_guard.mts'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('clause_id_guard.mts has no required fixture'), 'missing clause-guard fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'clause_id_guard_fixture.mts'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `clause-guard path refused: ${result.stderr}`);
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||,gh-api-read-guard||,clause-guard||', 'clause-guard lane not selected');

  writeFileSync(join(repo, 'scripts', 'prose_ambiguity_check.mts'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('prose_ambiguity_check.mts has no required fixture'), 'missing canon-lint fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'prose_ambiguity_check_fixture.mts'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `canon-lint path refused: ${result.stderr}`);
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||,gh-api-read-guard||,clause-guard||,canon-lint||', 'canon-lint lane not selected');

  let expected = 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||,gh-api-read-guard||,clause-guard||,canon-lint||';
  for (const [script, fixture, lane] of [['pr_criteria_check.mts', 'pr_criteria_check_fixture.mts', 'criteria'],
    ['futon_effort_record.mts', 'futon_effort_record_fixture.mts', 'futon-effort-guard'],
    ['product_term_check.mts', 'product_term_check_fixture.sh', 'product-term-guard'],
    ['plugin_version_refs.ts', 'plugin_version_refs_fixture.sh', 'plugin-version-refs-guard'],
    ['dependency_audit_resolve.mts', 'dependency_audit_resolve_fixture.mts', 'dependency-audit-guard']]) {
    writeFileSync(join(repo, 'scripts', script), '');
    result = run();
    assert(result.status === 2 && result.stderr.includes(`${script} has no required fixture`), `missing ${lane} fixture did not refuse`);
    writeFileSync(join(repo, 'scripts', fixture), '');
    writeFileSync(log, '');
    result = run();
    assert(result.status === 0, `${lane} path refused: ${result.stderr}`);
    expected += `,${lane}||`;
    calls = readFileSync(log, 'utf8').trim().split('\n');
    assert(calls.join(',') === expected, `${lane} lane not selected (BC-9)`);
  }

  // The tenkai engine is its own fixture (--self-test), so its lane is selected by the script alone,
  // with the verified nen's directory first on PATH and as NEN for its review-ledger cases (#427).
  writeFileSync(join(repo, 'scripts', 'tenkai_adopt.sh'), '');
  writeFileSync(log, '');
  const pathLog = join(dir, 'paths');
  result = run({ HATSU_PATH_LOG: pathLog, PATH: `/usr/bin:/bin` });
  assert(result.status === 0, `tenkai-guard path refused: ${result.stderr}`);
  expected += ',tenkai-guard||';
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === expected, 'tenkai-guard lane not selected (BC-9)');
  const paths = readFileSync(pathLog, 'utf8').trim().split('\n');
  assert(paths.length === calls.length && paths.every((line) => line.endsWith(`|${dir}|${nen}`)),
    `a lane did not get the verified nen first on PATH and as NEN: ${paths.join(' ; ')}`);
  result = run({ HATSU_FAIL_LANE: 'tenkai-guard' });
  assert(result.status === 1 && result.stderr.includes('tenkai-guard failed'), 'failing tenkai-guard was not red');

  // The issue-shape fixture is selected by itself: it runs the verified nen over the catalogue (#423).
  writeFileSync(join(repo, 'scripts', 'issue_sections_fixture.mts'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `issue-shape path refused: ${result.stderr}`);
  expected += ',issue-shape||';
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === expected, 'issue-shape lane not selected (BC-9)');

  result = run({}, join(dir, 'nen bin:x', 'nen'));
  assert(result.status === 2 && result.stderr.includes('may not contain'), 'a delimiter in the nen directory was not refused');

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
