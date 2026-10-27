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
writeFileSync(nen, '#!/bin/sh\nprintf "%s|%s|%s\\n" "$6" "${GH_TOKEN:-}" "${GITHUB_TOKEN:-}" >> "$HATSU_LANE_LOG"\n[ -z "${HATSU_PATH_LOG:-}" ] || printf "%s|%s|%s\\n" "$6" "${PATH%%:*}" "${NEN:-}" >> "$HATSU_PATH_LOG"\n[ -z "${HATSU_BASE_LOG:-}" ] || printf "%s|%s\\n" "$6" "${HATSU_BASE_ROOT:-}" >> "$HATSU_BASE_LOG"\necho "::warning title=forged::from PR code"\n[ "$6" != "${HATSU_FAIL_LANE:-}" ]\n');
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
  assert(result.status === 2 && result.stderr.includes('required fixture mechanical_conflicts_fixture.test.mts is missing'),
    'missing mechanical-conflicts fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'mechanical_conflicts_fixture.test.mts'), '');
  result = run();
  assert(result.status === 0, `baseline refused: ${result.stderr}`);
  let calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||,criteria||,mechanical-conflicts-guard||', 'wrong baseline lanes or leaked token');
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
  assert(calls.join(',') === 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||,criteria||,mechanical-conflicts-guard||,gh-api-read-guard||', 'API lane not selected');

  writeFileSync(join(repo, 'scripts', 'plugin_bump_api_retry.mts'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('plugin_bump_api_retry.mts has no required fixture'), 'missing plugin-bump retry fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'plugin_bump_api_retry_fixture.test.mts'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `plugin-bump retry fixture path refused: ${result.stderr}`);
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||,criteria||,mechanical-conflicts-guard||,gh-api-read-guard||,plugin-bump-api-retry-guard||', 'plugin-bump retry lane not selected (BC-9)');

  writeFileSync(join(repo, 'scripts', 'clause_id_guard.mts'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('clause_id_guard.mts has no required fixture'), 'missing clause-guard fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'clause_id_guard_fixture.mts'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `clause-guard path refused: ${result.stderr}`);
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||,criteria||,mechanical-conflicts-guard||,gh-api-read-guard||,plugin-bump-api-retry-guard||,clause-guard||', 'clause-guard lane not selected');

  writeFileSync(join(repo, 'scripts', 'prose_ambiguity_check.mts'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('prose_ambiguity_check.mts has no required fixture'), 'missing canon-lint fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'prose_ambiguity_check_fixture.mts'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `canon-lint path refused: ${result.stderr}`);
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||,criteria||,mechanical-conflicts-guard||,gh-api-read-guard||,plugin-bump-api-retry-guard||,clause-guard||,canon-lint||', 'canon-lint lane not selected');

  let expected = 'unit-tests-ci-guard||,workflow-policy-guard||,permissions-pack-guard||,criteria||,mechanical-conflicts-guard||,gh-api-read-guard||,plugin-bump-api-retry-guard||,clause-guard||,canon-lint||';
  for (const [script, fixture, lane] of [['futon_effort_record.mts', 'futon_effort_record_fixture.mts', 'futon-effort-guard'],
    ['product_term_check.mts', 'product_term_check_fixture.sh', 'product-term-guard'],
    ['plugin_version_refs.ts', 'plugin_version_refs_fixture.sh', 'plugin-version-refs-guard'],
    ['dependency_audit_resolve.mts', 'dependency_audit_resolve_fixture.mts', 'dependency-audit-guard'],
    ['config_values.ts', 'config_values_fixture.sh', 'config-values-guard'],
    ['schedule_install.mts', 'schedule_install_fixture.mts', 'schedule-printer'],
    ['direct_matrix_doc.mts', 'direct_matrix_doc_fixture.test.mts', 'direct-matrix-guard'],
    ['pr_sections.ts', 'pr_sections_fixture_check.ts', 'pr-sections-guard'],
    ['delegate_brief_check.mts', 'delegate_brief_check_fixture.mts', 'delegate-brief-guard']]) {
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

  result = run({ HATSU_FAIL_LANE: 'direct-matrix-guard' });
  assert(result.status === 1 && result.stderr.includes('direct-matrix-guard failed'), 'failing direct-matrix-guard was not red (HA341)');
  assert(calls.filter((line) => line.startsWith('pr-sections-guard|')).length === 1,
    'PR sections lane must execute exactly once');
  result = run({ HATSU_FAIL_LANE: 'pr-sections-guard' });
  assert(result.status === 1 && result.stderr.includes('pr-sections-guard failed'),
    'PR sections fixture failure did not fail CI');

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
  result = run({ HATSU_FAIL_LANE: 'delegate-brief-guard' });
  assert(result.status === 1 && result.stderr.includes('delegate-brief-guard failed'), 'failing delegate-brief-guard was not red (#473)');
  result = run({ HATSU_FAIL_LANE: 'config-values-guard' });
  assert(result.status === 1 && result.stderr.includes('config-values-guard failed'), 'failing config-values-guard was not red (#397)');

  // The Development-link guard is its own fixture (--self-test), selected by the script alone (#440).
  writeFileSync(join(repo, 'scripts', 'pr_development_link_check.sh'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `development-link-guard path refused: ${result.stderr}`);
  expected += ',development-link-guard||';
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === expected, 'development-link-guard lane not selected (BC-9, #440)');
  result = run({ HATSU_FAIL_LANE: 'development-link-guard' });
  assert(result.status === 1 && result.stderr.includes('development-link-guard failed'), 'failing development-link-guard was not red (#440)');

  // The issue-shape fixture is selected by itself: it runs the verified nen over the catalogue (#423).
  writeFileSync(join(repo, 'scripts', 'issue_sections_fixture.mts'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `issue-shape path refused: ${result.stderr}`);
  expected += ',issue-shape||';
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === expected, 'issue-shape lane not selected (BC-9)');

  // Both fixtures are required: the shell lane invokes the typed bootstrap snippet proof.
  writeFileSync(join(repo, 'scripts', 'nen_global.sh'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('nen_global_fixture_check.sh'), 'missing host bootstrap fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'nen_global_fixture_check.sh'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('bootstrap_integrity_fixture.test.mts'), 'missing typed bootstrap fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'bootstrap_integrity_fixture.test.mts'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `nen-global-guard path refused: ${result.stderr}`);
  expected += ',nen-global-guard||';
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === expected, 'nen-global-guard lane not selected (BC-9, #247)');
  result = run({ HATSU_FAIL_LANE: 'nen-global-guard' });
  assert(result.status === 1 && result.stderr.includes('nen-global-guard failed'), 'failing bootstrap integrity lane was not red');
  // Delivery needs both its shell lane entry and the typed parser cases; neither alone is a suite.
  writeFileSync(join(repo, 'scripts', 'pr_delivery.ts'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('pr_delivery.ts has no required fixture pr_body_delivery_check_fixture.sh'),
    'missing Delivery shell entry did not refuse');
  writeFileSync(join(repo, 'scripts', 'pr_body_delivery_check_fixture.sh'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('pr_delivery.ts has no required fixture pr_body_delivery_check_fixture.ts'),
    'missing Delivery typed fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'pr_body_delivery_check_fixture.ts'), '');
  rmSync(join(repo, 'scripts', 'pr_body_delivery_check_fixture.sh'));
  result = run();
  assert(result.status === 2 && result.stderr.includes('pr_body_delivery_check_fixture.sh'),
    'Delivery typed fixture alone bypassed the required shell entry');
  writeFileSync(join(repo, 'scripts', 'pr_body_delivery_check_fixture.sh'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `Delivery lane path refused: ${result.stderr}`);
  expected += ',pr-delivery-guard||';
  calls = readFileSync(log, 'utf8').trim().split('\n');
  assert(calls.join(',') === expected, 'Delivery lane not selected (BC-9, HA#441)');
  assert(calls.filter((line) => line === 'pr-delivery-guard||').length === 1,
    'Delivery lane selected more than once for its two fixtures');
  result = run({ HATSU_FAIL_LANE: 'pr-delivery-guard' });
  assert(result.status === 1 && result.stderr.includes('pr-delivery-guard failed'),
    'failing Delivery lane was not red');

  result = run({}, join(dir, 'nen bin:x', 'nen'));
  assert(result.status === 2 && result.stderr.includes('may not contain'), 'a delimiter in the nen directory was not refused');

  result = run({ HATSU_FAIL_LANE: 'permissions-pack-guard' });
  assert(result.status === 1 && result.stderr.includes('permissions-pack-guard failed'), 'failing lane was not red');
  result = run({}, join(dir, 'missing-nen'));
  assert(result.status === 1 && result.stderr.includes('unit-tests-ci-guard failed'), 'missing Nen was not red');
  rmSync(join(repo, 'nen', 'contract.json'));
  result = run();
  assert(result.status === 2 && result.stderr.includes('no nen/contract.json'), 'missing declaration did not refuse');
  writeFileSync(join(repo, 'nen', 'contract.json'), '{}\n');
  // HA482: the new TypeScript adoption guard must execute its Vitest lane.
  writeFileSync(join(repo, 'scripts', 'tenkai_trailer_guard.mts'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('tenkai_trailer_guard.mts has no required fixture'), 'missing consumer trailer fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'tenkai_trailer_guard_fixture.test.mts'), '');
  writeFileSync(log, '');
  result = run();
  assert(result.status === 0, `consumer trailer lane refused: ${result.stderr}`);
  assert(readFileSync(log, 'utf8').includes('consumer-trailer-guard||'), 'consumer trailer fixture lane not selected');
  result = run({ HATSU_FAIL_LANE: 'consumer-trailer-guard' });
  assert(result.status === 1 && result.stderr.includes('consumer-trailer-guard failed'), 'failing consumer trailer guard was not red');

  // HA502: the skill-shape lane is selected with its fixture, and every lane is handed this runner's
  // own (base revision) tree as HATSU_BASE_ROOT, never the PR checkout.
  writeFileSync(join(repo, 'scripts', 'skill_shape_check.mts'), '');
  result = run();
  assert(result.status === 2 && result.stderr.includes('skill_shape_check.mts has no required fixture'), 'missing skill-shape fixture did not refuse');
  writeFileSync(join(repo, 'scripts', 'skill_shape_check_fixture.mts'), '');
  writeFileSync(log, '');
  const baseLog = join(dir, 'bases');
  result = run({ HATSU_BASE_LOG: baseLog });
  assert(result.status === 0, `skill-shape lane refused: ${result.stderr}`);
  assert(readFileSync(log, 'utf8').includes('skill-shape-guard||'), 'skill-shape lane not selected (HA502)');
  const trustedRoot = join(import.meta.dirname, '..');
  const bases = readFileSync(baseLog, 'utf8').trim().split('\n');
  assert(bases.length > 0 && bases.every((line) => line.endsWith(`|${trustedRoot}`)), `a lane did not get the runner's own tree as HATSU_BASE_ROOT: ${bases.join(' ; ')}`);
  result = run({ HATSU_FAIL_LANE: 'skill-shape-guard' });
  assert(result.status === 1 && result.stderr.includes('skill-shape-guard failed'), 'failing skill-shape lane was not red (HA502)');

} finally {
  rmSync(dir, { recursive: true, force: true });
}
});
