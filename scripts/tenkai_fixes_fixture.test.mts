import { test, expect, afterAll } from 'vitest';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fixFor, fixRows, guide, OUTSTANDING, resolveAction, type FixRow } from './tenkai_fixes.ts';

// HA#535: every outstanding Tenkai item names its fix, and a re-run after a fix shows the count going down.
const source = resolve(import.meta.dirname, '..');
const rows = fixRows(source);
const made: string[] = [];
afterAll(() => { for (const dir of made) rmSync(dir, { recursive: true, force: true }); });
function temp() { const dir = mkdtempSync(join(tmpdir(), 'hatsu-tenkai-fixes-')); made.push(dir); return dir; }
const tokens = (text: string) => text.match(/<[^<>\s]+>/g) ?? [];
// gh is stubbed to fail, so the runner probe never reaches the network; --visibility overrides it anyway.
const stub = temp();
writeFileSync(join(stub, 'gh'), '#!/bin/sh\nexit 1\n'); chmodSync(join(stub, 'gh'), 0o755);
const env = { ...process.env, PATH: [stub, process.env.PATH].join(delimiter), GH_TOKEN: '', GITHUB_TOKEN: '', GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' };

function git(repo: string, ...args: string[]) {
  const result = spawnSync('git', ['-C', repo, ...args], { encoding: 'utf8', env });
  expect(result.status, result.stderr).toBe(0);
}
// The shape `nen scaffold new --stack nextjs` writes, registered as a product so its lane seats are read.
function scaffold() {
  const repo = temp();
  mkdirSync(join(repo, 'nen'));
  const seat = (verb: string) => ({ unsupported: `PROPOSED SEAT -- replace it. nen shu detect wrote this row because the reference pack proposes no command for '${verb}' on nextjs; nen never invents one.` });
  writeFileSync(join(repo, 'nen/contract.json'), JSON.stringify({ $schema: 'nen.contract/v0.1', project: { lanes: { nextjs: { stack: 'nextjs', cwd: '.' } }, defaultLane: 'nextjs',
    verbs: { nextjs: { 'ui-test': seat('ui-test'), archive: seat('archive'), release: seat('release'), deploy: seat('deploy') } }, hosts: { '*': ['darwin', 'linux', 'win32'] }, targets: {} } }, null, 2) + '\n');
  writeFileSync(join(repo, 'nen/workflow.json'), JSON.stringify({ $schema: 'nen.workflow/v0.1', branch: { template: '{model}/{persona}/{descriptor}', base: 'main' },
    iteration: { checks: ['build'], lane: 'nextjs' }, tests: { required: ['test'], extra: [] }, coverage: { minimum: 80, recommended: 85, ideal: 90, scope: 'touched' } }, null, 2) + '\n');
  writeFileSync(join(repo, 'nen/repos.json'), JSON.stringify({ consumers: [{ repo: 'fixture/widget' }] }) + '\n');
  writeFileSync(join(repo, '.gitignore'), '.nen/\nReports/\n');
  git(repo, 'init', '-q', '-b', 'main');
  git(repo, 'remote', 'add', 'origin', 'https://github.com/fixture/widget.git');
  return repo;
}
function tenkai(repo: string, mode: string, json = true) {
  const result = spawnSync('bash', [join(source, 'scripts/tenkai_adopt.sh'), mode, '--repo', repo, '--visibility', 'private', '--self-hosted', '0', ...(json ? ['--json'] : [])],
    { encoding: 'utf8', env, maxBuffer: 16 * 1024 * 1024 });
  expect([0, 1], result.stderr).toContain(result.status);
  return json ? JSON.parse(result.stdout) : result.stdout;
}

test('every catalogue row is well-formed, and only an owner row takes an answer', () => {
  expect(rows.at(-1)!.id).toBe('^.*$');
  for (const row of rows) {
    expect(['default', 'owner', 'edit'], row.id).toContain(row.fill);
    expect(row.detect, row.id).toBeTruthy();
    const asked = (row.run ?? []).flatMap(tokens);
    if (row.fill === 'owner') { expect(asked.length, row.id).toBeGreaterThan(0); expect(row.asks ?? [], row.id).toEqual([...new Set(asked)]); }
    else { expect(asked, row.id).toEqual([]); expect(row.asks ?? [], row.id).toEqual([]); }
    if (row.fill === 'edit') expect(row.run ?? [], row.id).toEqual([]);
    expect(tokens(row.detect), row.id).toEqual([]);
  }
});

test('every id the engine emits maps to a named fix before the catch-all', () => {
  const context = { repo: '/tmp/a repo', root: '/opt/hatsu', slug: 'acme/widget' };
  const items = [
    ['nen/contract.json', 'routed'], ['nen/workflow.json', 'blocked'], ['nen/gates.json', 'routed'], ['nen/labels.json', 'routed'], ['nen/repos.json', 'routed'],
    ['nen/colors.yml', 'missing'], ['hooks/commit-msg', 'routed'], ['guard/registration', 'routed'], ['scripts/readiness_ci_verdict.mts', 'missing'],
    ['.github/workflows/pr-readiness.yml', 'staged'], ['.github/workflows/forbidden-commit-trailers.yml', 'blocked'], ['scripts/release-publish.sh', 'missing'],
    ['workflow/review-scopes', 'routed'], ['lane/ios/archive', 'routed'], ['workflow/toolchain', 'routed'], ['workflow/evidence', 'routed'],
    ['workflow/release-destination', 'routed'], ['gates/retired-keys', 'drift'], ['config/defaults', 'missing'], ['pr.sections', 'drift'],
  ].map(([id, state]) => ({ id, state, detail: '', action: '' }));
  items.push({ id: 'dirs/reports', state: 'missing', detail: 'Reports/ does not exist', action: '' });
  items.push({ id: 'release/row', state: 'routed', detail: '', action: 'declare it at project.verbs.ios.release — the row' });
  items.push({ id: 'release/row', state: 'blocked', detail: "this repository's role is not recorded", action: '' });
  items.push({ id: 'workflow/test-selection/ui-test', state: 'routed', detail: "lane 'ios' declares ui-test", action: '' });
  items.push({ id: 'workflow/test-results', state: 'routed', detail: '', action: "make lane 'ios' write a Nen-readable test result" });
  items.push({ id: 'workflow/coverage', state: 'routed', detail: "workflow.coverage sets a floor, but lane 'ios' has no coverage row", action: '' });
  items.push({ id: 'config/needed', state: 'routed', detail: '2 value(s) a skill needs have no default: workflow.review.scopes, contract.project.kind; 1 more', action: '' });
  for (const item of items) {
    const fix = fixFor(item, rows, context);
    expect(fix.rule, item.id).not.toBe('^.*$');
    for (const command of fix.run) expect(tokens(command).every((token) => fix.asks.includes(token)), command).toBe(true);
    expect(`${fix.run.join(' ')} ${fix.detect}`, item.id).not.toContain('<path>');
    if (fix.run.length) expect(fix.run.join(' '), item.id).toContain("'/tmp/a repo'");
  }
  const needed = fixFor(items.at(-1)!, rows, context);
  expect(needed.run).toEqual(['bash /opt/hatsu/scripts/config_values.sh set --repo \'/tmp/a repo\' --id workflow.review.scopes --value <answer-json>',
    'bash /opt/hatsu/scripts/config_values.sh set --repo \'/tmp/a repo\' --id contract.project.kind --value <answer-json>']);
  // A scaffold seat is an object nen schema set never replaces, so its fix is the owner's edit; an absent row is added.
  expect(fixFor({ id: 'lane/ios/archive', state: 'routed', detail: 'declared unsupported: PROPOSED SEAT' }, rows, context)).toMatchObject({ run: [], fill: 'edit' });
  expect(fixFor({ id: 'lane/ios/build', state: 'routed', detail: 'but no command is declared' }, rows, context).run[0]).toContain('--pointer /project/verbs/ios/build --value <command-json> --gate-change');
  expect(resolveAction('validate with nen schema check --repo <path>', '/tmp/a repo')).toBe("validate with nen schema check --repo '/tmp/a repo'");
});

test('a template naming an unfilled value is refused, never printed half-filled', () => {
  const broken: FixRow[] = [{ id: '^x$', detect: 'nen schema check --repo {nowhere}', fill: 'edit' }];
  expect(() => fixFor({ id: 'x', state: 'routed' }, broken, { repo: '/r', root: '/h' })).toThrow(/\{nowhere\} is not filled/);
  expect(() => fixFor({ id: 'y', state: 'routed' }, broken, { repo: '/r', root: '/h' })).toThrow(/no row matches y/);
});

test('a scaffolded product: every outstanding item names its fix, and the guided fill accounts for each', () => {
  const repo = scaffold();
  const report = tenkai(repo, 'diagnose');
  const open = report.items.filter((row: any) => OUTSTANDING.includes(row.state));
  expect(report.outstanding).toBe(open.length);
  for (const id of ['lane/nextjs/archive', 'lane/nextjs/deploy', 'lane/nextjs/release', 'lane/nextjs/ui-test', 'lane/nextjs/build']) expect(open.map((row: any) => row.id)).toContain(id);
  for (const row of open) {
    expect(row.fix, row.id).toBeTruthy();
    expect(row.fix.rule, row.id).not.toBe('^.*$');
    expect(row.fix.edit ?? row.fix.run[0], row.id).toBeTruthy();
    expect(row.action ?? '', row.id).not.toContain('--repo <path>');
  }
  const { defaults, owner, manual } = report.guide;
  expect(defaults.length + owner.length + manual.length).toBe(report.outstanding);
  expect(guide(report.items)).toEqual(report.guide);
  const text = tenkai(repo, 'diagnose', false) as string;
  expect(text).toContain(`run:    nen schema set --repo ${repo} --file nen/contract.json --pointer /project/verbs/nextjs/build --value <command-json> --gate-change`);
  expect(text).toContain('edit:   nen/contract.json → project.verbs.nextjs.archive: replace the row');
  expect(text).toContain(`detect: nen shu detect --repo ${repo}`);
  expect(text).toMatch(/guided fill — Tenkai writes only catalogue defaults and values the owner answered/);
  expect(text).toMatch(/1\. defaults \(\d+\): bash .*tenkai_adopt\.sh apply/);
});

test('a re-run after each fix shows the outstanding count going down', () => {
  const repo = scaffold();
  const before = tenkai(repo, 'diagnose');
  // Step 1 of the guided fill: apply writes only defaults and Hatsu seeds, and settles every default item.
  tenkai(repo, 'apply');
  const settled = tenkai(repo, 'diagnose');
  expect(settled.outstanding).toBeLessThan(before.outstanding);
  for (const id of before.guide.defaults) expect(settled.guide.defaults, id).not.toContain(id);
  // Step 2: the owner answers an absent row; the item's own run line, with the answer in its token, settles it.
  const build = settled.items.find((row: any) => row.id === 'lane/nextjs/build');
  expect(build.fix.fill).toBe('owner');
  const answer = JSON.stringify({ exe: 'pnpm', argv: ['run', 'build'] });
  const ran = spawnSync('bash', ['-c', build.fix.run[0].replace('<command-json>', `'${answer}'`)], { encoding: 'utf8', env });
  expect(ran.status, ran.stderr).toBe(0);
  const answered = tenkai(repo, 'diagnose');
  expect(answered.items.find((row: any) => row.id === 'lane/nextjs/build').state).toBe('satisfied');
  expect(answered.outstanding).toBe(settled.outstanding - 1);
  // Step 3: the owner's edit replaces a seat by hand; its detect line still reads, and the count drops again.
  const seat = answered.items.find((row: any) => row.id === 'lane/nextjs/archive');
  expect(seat.fix).toMatchObject({ run: [], fill: 'edit', detect: `nen shu detect --repo ${repo}` });
  const file = join(repo, 'nen/contract.json');
  const contract = JSON.parse(readFileSync(file, 'utf8'));
  contract.project.verbs.nextjs.archive = { exe: 'pnpm', argv: ['run', 'build'] };
  writeFileSync(file, JSON.stringify(contract, null, 2) + '\n');
  const final = tenkai(repo, 'diagnose');
  expect(final.items.find((row: any) => row.id === 'lane/nextjs/archive').state).toBe('satisfied');
  expect(final.outstanding).toBe(answered.outstanding - 1);
});
