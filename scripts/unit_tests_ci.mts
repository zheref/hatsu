#!/usr/bin/env node
// Run the focused machinery fixtures in CI. The workflow invokes this trusted
// copy with a PR checkout as data; that checkout's tests execute with a
// read-only pull_request token and no checkout credentials.
import { existsSync } from 'node:fs';
import { delimiter, dirname, isAbsolute, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';

const [rootArg, nenArg] = process.argv.slice(2);
if (!rootArg || !nenArg || !isAbsolute(rootArg) || !isAbsolute(nenArg)) {
  console.error('unit-tests-ci: expected absolute PR root and verified nen binary paths');
  process.exit(2);
}
if (dirname(nenArg).includes(delimiter)) {
  // Its directory goes first on PATH below; a delimiter inside it would split off a relative entry.
  console.error(`unit-tests-ci: the verified nen's directory may not contain '${delimiter}'`);
  process.exit(2);
}
const root = resolve(rootArg);
if (!existsSync(join(root, 'nen', 'contract.json'))) {
  console.error('unit-tests-ci: PR checkout has no nen/contract.json');
  process.exit(2);
}
// The criteria lane holds Hatsu's wiring around `nen pr converge` (zheref/hatsu#413) and the HR-10
// findings-schema invariants; it runs unconditionally, so deleting its fixture fails the lane, never drops it.
const lanes = ['unit-tests-ci-guard', 'workflow-policy-guard', 'permissions-pack-guard', 'criteria'];
// The mechanical declaration is data rather than a runtime script, so its real-Nen fixture is
// required directly. Deleting it is a wiring refusal, never a smaller green CI selection (#415).
const requiredFixtures: Array<[string, string]> = [
  ['mechanical_conflicts_fixture.test.mts', 'mechanical-conflicts-guard'],
];
for (const [fixture, lane] of requiredFixtures) {
  if (!existsSync(join(root, 'scripts', fixture))) {
    console.error(`unit-tests-ci: required fixture ${fixture} is missing`);
    process.exit(2);
  }
  lanes.push(lane);
}
// Each executable guard runs here once it exists, and refuses without its fixture (BC-9: a guard's
// suite must actually execute in unit-tests.yml).
const gated: Array<[string, string | string[], string]> = [
  ['gh_api_read.mts', 'gh_api_read_fixture.mts', 'gh-api-read-guard'],
  ['plugin_bump_api_retry.mts', 'plugin_bump_api_retry_fixture.test.mts', 'plugin-bump-api-retry-guard'],
  ['clause_id_guard.mts', 'clause_id_guard_fixture.mts', 'clause-guard'],
  // Its live case calls `nen stop answer` from PATH (zheref/hatsu#443).
  ['ruling_record.mts', 'ruling_record_fixture.mts', 'ruling-record'],
  ['prose_ambiguity_check.mts', 'prose_ambiguity_check_fixture.mts', 'canon-lint'],
  ['futon_effort_record.mts', 'futon_effort_record_fixture.mts', 'futon-effort-guard'],
  ['product_term_check.mts', 'product_term_check_fixture.sh', 'product-term-guard'],
  // Its last case runs --check-nen-pin on the PR checkout itself, so a repin that leaves
  // docs/NEN-CONTRACT.md's echoed pin line stale fails unit-tests.yml on every pull request.
  ['plugin_version_refs.ts', 'plugin_version_refs_fixture.sh', 'plugin-version-refs-guard'],
  ['dependency_audit_resolve.mts', 'dependency_audit_resolve_fixture.mts', 'dependency-audit-guard'],
  // The settable-values engine's self-test plus the HR-23 examiner refusal (zheref/hatsu#397, BC-9).
  ['config_values.ts', 'config_values_examiner_fixture.ts', 'config-values-guard'],
  ['schedule_install.mts', 'schedule_install_fixture.mts', 'schedule-printer'],
  // The tenkai engine's fixture is its own --self-test; its review-ledger cases call `nen review
  // ledger` from PATH (zheref/hatsu#427).
  ['tenkai_adopt.sh', 'tenkai_adopt.sh', 'tenkai-guard'],
  // The spec-family fixture reads (zheref/hatsu#405): the script is its own fixture, as tenkai's is.
  ['spec_family_fixture_check.sh', 'spec_family_fixture_check.sh', 'spec-family-guard'],
  // The Development-link guard is its own fixture (--self-test): bash, jq, awk and perl's Encode,
  // all on the runner image (zheref/hatsu#440).
  ['pr_development_link_check.sh', 'pr_development_link_check.sh', 'development-link-guard'],
  // The issue-shape fixture runs the verified nen's body-check and questions over the catalogue and
  // templates; the interim checker it once tested is retired (zheref/hatsu#423).
  ['issue_sections_fixture.mts', 'issue_sections_fixture.mts', 'issue-shape'],
  // Host pin negatives plus shipped Cloud/prepared readiness bootstrap checks (#247, BC-9).
  // This selection becomes automatic only after this trusted runner is adopted on the base.
  ['nen_global.sh', ['nen_global_fixture_check.sh', 'bootstrap_integrity_fixture.test.mts'], 'nen-global-guard'],
];
for (const [script, fixture, lane] of gated) {
  if (!existsSync(join(root, 'scripts', script))) continue;
  const required = Array.isArray(fixture) ? fixture : [fixture];
  const missing = required.find((name) => !existsSync(join(root, 'scripts', name)));
  if (missing) {
    console.error(`unit-tests-ci: ${script} has no required fixture: ${missing}`);
    process.exit(2);
  }
  lanes.push(lane);
}
const fence = `unit_tests_${randomBytes(16).toString('hex')}`;
// A lane whose fixture calls nen itself resolves the workflow-installed binary this runner was handed,
// first on PATH and as NEN, ahead of any nen the PR checkout ships (the workflow installs it with --rc
// none). PR code runs in the same job and user, so this is correctness, not an isolation boundary.
const nenPath = [dirname(nenArg), process.env.PATH].filter(Boolean).join(delimiter);
for (const lane of lanes) {
  console.log(`unit-tests-ci: ${lane}`);
  const result = spawnSync(nenArg, ['shu', 'test', '--repo', root, '--lane', lane], {
    cwd: root,
    encoding: 'utf8',
    env: { ...process.env, PATH: nenPath, NEN: nenArg, GH_TOKEN: '', GITHUB_TOKEN: '' },
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
