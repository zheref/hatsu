#!/usr/bin/env node
// Run the focused machinery fixtures in CI. The workflow invokes this trusted
// copy with a PR checkout as data; that checkout's tests execute with a
// read-only pull_request token and no checkout credentials.
import { existsSync } from 'node:fs';
import { isAbsolute, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';

const [rootArg, nenArg] = process.argv.slice(2);
if (!rootArg || !nenArg || !isAbsolute(rootArg) || !isAbsolute(nenArg)) {
  console.error('unit-tests-ci: expected absolute PR root and verified nen binary paths');
  process.exit(2);
}
const root = resolve(rootArg);
if (!existsSync(join(root, 'nen', 'contract.json'))) {
  console.error('unit-tests-ci: PR checkout has no nen/contract.json');
  process.exit(2);
}
const lanes = ['unit-tests-ci-guard', 'workflow-policy-guard', 'permissions-pack-guard'];
// Each executable guard runs here once it exists, and refuses without its fixture (BC-9: a guard's
// suite must actually execute in unit-tests.yml).
const gated: Array<[string, string, string]> = [
  ['gh_api_read.mts', 'gh_api_read_fixture.mts', 'gh-api-read-guard'],
  ['clause_id_guard.mts', 'clause_id_guard_fixture.mts', 'clause-guard'],
  ['prose_ambiguity_check.mts', 'prose_ambiguity_check_fixture.mts', 'canon-lint'],
  ['issue_body_check.mts', 'issue_body_check_fixture.mts', 'issue-shape'],
  ['pr_criteria_check.mts', 'pr_criteria_check_fixture.mts', 'criteria'],
  ['futon_effort_record.mts', 'futon_effort_record_fixture.mts', 'futon-effort-guard'],
];
for (const [script, fixture, lane] of gated) {
  if (!existsSync(join(root, 'scripts', script))) continue;
  if (!existsSync(join(root, 'scripts', fixture))) {
    console.error(`unit-tests-ci: ${script} has no required fixture`);
    process.exit(2);
  }
  lanes.push(lane);
}
const fence = `unit_tests_${randomBytes(16).toString('hex')}`;
for (const lane of lanes) {
  console.log(`unit-tests-ci: ${lane}`);
  const result = spawnSync(nenArg, ['shu', 'test', '--repo', root, '--lane', lane], {
    cwd: root,
    encoding: 'utf8',
    env: { ...process.env, GH_TOKEN: '', GITHUB_TOKEN: '' },
  });
  console.log(`::stop-commands::${fence}`);
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  console.log(`::${fence}::`);
  if (result.error || result.status !== 0) {
    console.error(`unit-tests-ci: ${lane} failed (${result.error?.message ?? `exit ${result.status}`})`);
    process.exit(1);
  }
}
console.log(`unit-tests-ci: ${lanes.length} focused lanes passed`);
