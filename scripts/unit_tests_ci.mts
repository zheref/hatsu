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
if (existsSync(join(root, 'scripts', 'gh_api_read.mts'))) {
  if (!existsSync(join(root, 'scripts', 'gh_api_read_fixture.mts'))) {
    console.error('unit-tests-ci: gh_api_read.mts has no required fixture');
    process.exit(2);
  }
  lanes.push('gh-api-read-guard');
}
if (existsSync(join(root, 'scripts', 'clause_id_guard.mts'))) {
  if (!existsSync(join(root, 'scripts', 'clause_id_guard_fixture.mts'))) {
    console.error('unit-tests-ci: clause_id_guard.mts has no required fixture');
    process.exit(2);
  }
  lanes.push('clause-guard');
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
