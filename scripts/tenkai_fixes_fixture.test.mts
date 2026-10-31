import { test, expect, afterAll } from 'vitest';
import { chmodSync, cpSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fixFor, fixRows, guide, OUTSTANDING, quote, resolveAction, type FixRow } from './tenkai_fixes.ts';

// HA#535: every outstanding Tenkai item names its fix, and a re-run after a fix shows the count going down.
const source = resolve(import.meta.dirname, '..');
const rows = fixRows(source);
const made: string[] = [];
afterAll(() => { for (const dir of made) rmSync(dir, { recursive: true, force: true }); });
function temp(prefix = 'hatsu-tenkai-fixes-') { const dir = mkdtempSync(join(tmpdir(), prefix)); made.push(dir); return dir; }
const tokens = (text: string) => text.match(/<[^<>\s]+>/g) ?? [];
// gh is stubbed to fail, so the runner probe never reaches the network; --visibility overrides it anyway.
const stub = temp();
writeFileSync(join(stub, 'gh'), '#!/bin/sh\nexit 1\n'); chmodSync(join(stub, 'gh'), 0o755);
const env = { ...process.env, PATH: [stub, process.env.PATH].join(delimiter), GH_TOKEN: '', GITHUB_TOKEN: '', GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' };

function git(repo: string, ...args: string[]) {
  const result = spawnSync('git', ['-C', repo, ...args], { encoding: 'utf8', env });
  expect(result.status, result.stderr).toBe(0);
}
const seat = (verb: string) => ({ unsupported: `PROPOSED SEAT -- replace it. nen shu detect wrote this row because the reference pack proposes no command for '${verb}' on nextjs; nen never invents one.` });
// The shape `nen scaffold new --stack nextjs` writes; `role` registers it, `gitInit: false` keeps the scaffold's own non-repository state.
function scaffold({ role = 'consumers', gitInit = true, dir = temp() }: { role?: string | null; gitInit?: boolean; dir?: string } = {}) {
  const repo = dir;
  mkdirSync(join(repo, 'nen'), { recursive: true });
  writeFileSync(join(repo, 'nen/contract.json'), JSON.stringify({ $schema: 'nen.contract/v0.1', project: { lanes: { nextjs: { stack: 'nextjs', cwd: '.' } }, defaultLane: 'nextjs',
    verbs: { nextjs: { 'ui-test': seat('ui-test'), archive: seat('archive'), release: seat('release'), deploy: seat('deploy') } }, hosts: { '*': ['darwin', 'linux', 'win32'] }, targets: {} } }, null, 2) + '\n');
  writeFileSync(join(repo, 'nen/workflow.json'), JSON.stringify({ $schema: 'nen.workflow/v0.1', branch: { template: '{model}/{persona}/{descriptor}', base: 'main' },
    iteration: { checks: ['build'], lane: 'nextjs' }, tests: { required: ['test'], extra: [] }, coverage: { minimum: 80, recommended: 85, ideal: 90, scope: 'touched' } }, null, 2) + '\n');
  if (role) writeFileSync(join(repo, 'nen/repos.json'), JSON.stringify({ [role]: [{ repo: 'fixture/widget' }] }) + '\n');
  writeFileSync(join(repo, '.gitignore'), '.nen/\nReports/\n');
  if (gitInit) {
    git(repo, 'init', '-q', '-b', 'main');
    git(repo, 'remote', 'add', 'origin', 'https://github.com/fixture/widget.git');
  } else mkdirSync(join(repo, '.git', 'hooks'), { recursive: true });
  return repo;
}
function tenkai(repo: string, mode: string, json = true, extra: string[] = []) {
  const result = spawnSync('bash', [join(source, 'scripts/tenkai_adopt.sh'), mode, '--repo', repo, '--visibility', 'private', '--self-hosted', '0', ...extra, ...(json ? ['--json'] : [])],
    { encoding: 'utf8', env, maxBuffer: 16 * 1024 * 1024 });
  expect([0, 1], result.stderr).toContain(result.status);
  return json ? JSON.parse(result.stdout) : result.stdout;
}

test('every catalogue row is well-formed, and only an owner row takes an answer', () => {
  expect(rows.at(-1)!.fill).toBe('unmapped');
  expect(rows.filter((row) => row.fill === 'unmapped')).toHaveLength(1);
  for (const row of rows) {
    const asked = (row.run ?? []).flatMap(tokens);
    if (row.fill === 'owner') { expect(asked.length, row.id).toBeGreaterThan(0); expect(row.asks ?? [], row.id).toEqual([...new Set(asked)]); }
    else { expect(asked, row.id).toEqual([]); expect(row.asks ?? [], row.id).toEqual([]); }
    if (row.fill === 'default') expect(row.run?.length, row.id).toBeGreaterThan(0);
    // An edit is tenkai § 6c's: only nen/contract.json or nen/workflow.json, and never a run line.
    if (row.fill === 'edit') { expect(row.run ?? [], row.id).toEqual([]); expect(row.edit, row.id).toMatch(/nen\/(contract|workflow|\{file\})\.json/); }
    expect(tokens(row.detect), row.id).toEqual([]);
  }
});

test('engine strings map to a named fix; an unrenderable or unmatched item is unmapped, never a crash', () => {
  const context = { repo: '/tmp/a repo', root: '/opt/hatsu', slug: 'acme/widget' };
  const items = [
    { id: 'release/row', state: 'routed', detail: 'nen/contract.json is absent, so there is no lane to declare a `release` row on yet', action: 'nen scaffold init --repo /tmp/a repo, then re-run' },
    { id: 'release/row', state: 'blocked', detail: '`project.defaultLane` is not declared, so which lane owes the `release` row cannot be derived', action: 'declare project.defaultLane, then re-run' },
    { id: 'release/row', state: 'routed', detail: "product lane 'ios' (stack 'xcode-ios') has absent for `release`; Tenkai cannot call this product release-ready", action: 'choose the destinations' },
    { id: 'release/row', state: 'routed', detail: "lane 'tools''s `release` row is absent. nen owns this file", action: 'declare it at project.verbs.tools.release — the row' },
    { id: 'release/row', state: 'blocked', detail: "this repository's role is not recorded in `nen/repos.json`", action: '' },
    { id: '.github/workflows/pr-readiness.yml', state: 'blocked', detail: "installed, but this repository's slug could not be read", action: 'pass --slug <owner/name>' },
    { id: '.github/workflows/pr-readiness.yml', state: 'blocked', detail: "Hatsu's dependency.pinned_ref is absent or malformed", action: '' },
    { id: '.github/workflows/pr-readiness.yml', state: 'staged', detail: 'not installed, and the policy guard has not registered it yet', action: '' },
    { id: 'effort/review-ledger', state: 'routed', detail: "no branch-keyed review ledger for 'x'", action: '' },
    { id: 'config/defaults', state: 'blocked', detail: 'not read — nen/workflow.json cannot be read safely', action: '' },
    { id: 'config/needed', state: 'routed', detail: '2 value(s) a skill needs have no default: workflow.review.scopes, contract.project.kind; 1 more', action: '' },
    { id: 'workflow/test-results', state: 'routed', detail: '', action: "make lane 'ios' write a Nen-readable test result" },
    { id: 'lane/ios/build', state: 'routed', detail: "iteration.checks requires 'build' on lane 'ios', but no command is declared", action: '' },
    { id: 'lane/ios/archive', state: 'routed', detail: 'declared unsupported: PROPOSED SEAT', action: '' },
  ];
  for (const item of items) {
    const fix = fixFor(item, rows, context);
    expect(fix.fill, `${item.id} ${item.detail}`).not.toBe('unmapped');
    for (const command of fix.run) expect(tokens(command).every((token) => fix.asks.includes(token)), command).toBe(true);
    if (fix.run.length) expect(fix.run.join(' '), item.id).toContain("'/tmp/a repo'");
  }
  expect(fixFor(items[0], rows, context).run[0]).toContain('nen scaffold init');
  expect(fixFor(items[1], rows, context).run[0]).toContain('--id contract.project.defaultLane');
  expect(fixFor(items[2], rows, context)).toMatchObject({ fill: 'edit', run: [] });
  expect(fixFor(items[3], rows, context).run[0]).toContain('--pointer /project/verbs/tools/release');
  expect(fixFor(items[8], rows, context).fill).toBe('route');
  expect(fixFor(items[10], rows, context).run).toEqual(['bash /opt/hatsu/scripts/config_values.sh set --repo \'/tmp/a repo\' --id workflow.review.scopes --value <answer-json>',
    'bash /opt/hatsu/scripts/config_values.sh set --repo \'/tmp/a repo\' --id contract.project.kind --value <answer-json>']);
  expect(fixFor(items[13], rows, context)).toMatchObject({ fill: 'edit', run: [], detect: "nen schema check --repo '/tmp/a repo'" });
  // A target-controlled lane name never reaches a command: it falls to the catch-all instead.
  expect(fixFor({ id: 'lane/a\nb/build', state: 'routed', detail: 'no command is declared' }, rows, context).fill).toBe('unmapped');
  expect(fixFor({ id: "lane/x';touch y'/build", state: 'routed', detail: 'no command is declared' }, rows, context).fill).toBe('unmapped');
  // Only a well-formed slug is printed; anything else is the owner's placeholder.
  const role = { id: 'scripts/release-publish.sh', state: 'blocked', detail: 'role is not recorded' };
  expect(fixFor(role, rows, { ...context, slug: 'a/b"; rm -rf x' }).edit).toContain('{"repo": "<owner/name>"}');
  expect(fixFor(role, rows, context).edit).toContain('{"repo": "acme/widget"}');
  expect(resolveAction('validate with nen schema check --repo <path>', '/tmp/a repo')).toBe("validate with nen schema check --repo '/tmp/a repo'");
  expect(resolveAction('nen scaffold init --repo /tmp/a repo, then', '/tmp/a repo')).toBe("nen scaffold init --repo '/tmp/a repo', then");
  expect(quote("it's")).toBe(`'it'\\''s'`);
});

test('a catalogue row that cannot render is reported unmapped with its defect', () => {
  const broken: FixRow[] = [{ id: '^x$', detect: 'nen schema check --repo {nowhere}', fill: 'route' }, { id: '^[\\s\\S]*$', detect: 'diagnose {repo}', fill: 'unmapped' }];
  expect(fixFor({ id: 'x', state: 'routed' }, broken, { repo: '/r', root: '/h' })).toMatchObject({ fill: 'unmapped', defect: expect.stringMatching(/\{nowhere\} is not filled/) });
  expect(fixFor({ id: 'y', state: 'routed' }, broken, { repo: '/r', root: '/h' })).toMatchObject({ fill: 'unmapped', detect: 'diagnose /r' });
  const bad = temp();
  mkdirSync(join(bad, 'contracts'));
  writeFileSync(join(bad, 'contracts/tenkai-fixes.json'), JSON.stringify({ fixes: [{ id: '^x$', detect: 'd', fill: 'route' }] }));
  expect(() => fixRows(bad)).toThrow(/last row must be the unmapped catch-all/);
});

test('every item a real engine run reports outstanding names a fix, across repository shapes', () => {
  const shapes: Record<string, string> = {
    'scaffolded product': scaffold(),
    'scaffold before git init': scaffold({ gitInit: false }),
    'process repository': scaffold({ role: 'maintained_tools' }),
    'unregistered repository': scaffold({ role: null }),
  };
  const blocked = scaffold(); writeFileSync(join(blocked, 'nen/workflow.json'), '{ not json'); shapes['unparseable workflow'] = blocked;
  const linked = scaffold(); symlinkSync(temp(), join(linked, 'Reports')); shapes['symlinked Reports'] = linked;
  const noLane = scaffold({ role: 'maintained_tools' });
  const contract = JSON.parse(readFileSync(join(noLane, 'nen/contract.json'), 'utf8')); delete contract.project.defaultLane;
  writeFileSync(join(noLane, 'nen/contract.json'), JSON.stringify(contract)); shapes['no defaultLane'] = noLane;
  const bare = temp(); git(bare, 'init', '-q', '-b', 'main'); shapes['bare repository'] = bare;
  const reader = scaffold(); mkdirSync(join(reader, 'scripts')); symlinkSync(join(source, 'scripts/readiness_ci_verdict.mts'), join(reader, 'scripts/readiness_ci_verdict.mts')); shapes['symlinked reader'] = reader;
  const trailers = scaffold(); mkdirSync(join(trailers, '.github/workflows'), { recursive: true });
  writeFileSync(join(trailers, '.github/workflows/forbidden-commit-trailers.yml'), 'name: hand-written\n');
  const policy = JSON.parse(readFileSync(join(trailers, 'nen/workflow.json'), 'utf8')); policy.commits = { forbiddenTrailers: ['Co-Authored-By'] };
  writeFileSync(join(trailers, 'nen/workflow.json'), JSON.stringify(policy)); shapes['hand-written trailer workflow'] = trailers;
  const gates = scaffold(); writeFileSync(join(gates, 'nen/gates.json'), JSON.stringify({ check_exclusions: [] })); shapes['retired gates key'] = gates;
  const linkedGates = scaffold(); const outside = join(temp(), 'gates.json'); writeFileSync(outside, '{}'); symlinkSync(outside, join(linkedGates, 'nen/gates.json')); shapes['symlinked gates'] = linkedGates;
  const applied = scaffold(); tenkai(applied, 'apply'); shapes['scaffolded product after apply'] = applied;
  for (const [shape, repo] of Object.entries(shapes)) {
    const report = tenkai(repo, 'diagnose');
    const open = report.items.filter((row: any) => OUTSTANDING.includes(row.state));
    expect(report.outstanding, shape).toBe(open.length);
    for (const row of open) {
      expect(row.fix?.fill, `${shape}: ${row.id} ${row.state} — ${row.detail}`).not.toBe('unmapped');
      // Only the trailer policy itself is Tenkai's edit; a hand-written or linked workflow is routed.
      if (row.id.endsWith('forbidden-commit-trailers.yml') && !/forbiddenTrailers/.test(row.detail)) expect(row.fix.fill, `${shape}: ${row.detail}`).toBe('route');
      expect(row.fix.edit ?? row.fix.run[0], `${shape}: ${row.id}`).toBeTruthy();
      expect(row.action ?? '', `${shape}: ${row.id}`).not.toContain('--repo <path>');
    }
    const { defaults, owner, edits, routed, unmapped } = report.guide;
    expect(defaults.length + owner.length + edits.length + routed.length + unmapped.length, shape).toBe(report.outstanding);
    expect(guide(report.items), shape).toEqual(report.guide);
  }
  // The scaffold's own non-repository state routes every git-dependent item to `git init`, not a false fix.
  const pre = tenkai(shapes['scaffold before git init'], 'diagnose');
  for (const id of ['dirs/reports', 'hooks/commit-msg']) expect(pre.items.find((row: any) => row.id === id).fix.run, id).toEqual([`git -C ${quote(realpathSync(shapes['scaffold before git init']))} init`]);
  expect(tenkai(shapes['symlinked reader'], 'diagnose').items.find((row: any) => row.id === 'scripts/readiness_ci_verdict.mts')).toMatchObject({ state: 'blocked', fix: { fill: 'route' } });
  expect(tenkai(shapes['retired gates key'], 'diagnose').items.find((row: any) => row.id === 'gates/retired-keys').fix.edit).toContain('remove check_exclusions');
  expect(tenkai(shapes['symlinked gates'], 'diagnose').items.find((row: any) => row.id === 'gates/retired-keys').fix.edit).toContain('replace a link');
});

test('the report names each fix as a line, quoted, with the guided fill in its groups', () => {
  const repo = scaffold({ dir: join(temp(), 'a repo') });
  const text = tenkai(repo, 'diagnose', false) as string;
  // macOS's temp directory is a symlink: the report prints the real path, quoted, everywhere.
  const shown = quote(realpathSync(repo));
  for (const line of text.split('\n').filter((entry) => entry.includes('--repo '))) expect(line, line).not.toContain(`--repo ${realpathSync(repo)}`);
  expect(text).toContain(`run:    nen schema set --repo ${shown} --file nen/contract.json --pointer /project/verbs/nextjs/build --value <command-json> --gate-change`);
  expect(text).toContain('edit:   nen/contract.json → project.verbs.nextjs.archive: replace the row');
  expect(text).toContain(`detect: nen schema check --repo ${shown}`);
  expect(text).toMatch(/guided fill — Tenkai writes only catalogue defaults and values the owner answered/);
  expect(text).toMatch(/1\. defaults \(\d+\), settling .*:\n {7}bash .*tenkai_adopt\.sh apply --repo /);
  expect(text).toMatch(/2\. owner answers \(\d+\): .* single-quoted in place of its <token>/);
  expect(text).toMatch(/4\. routed to their owner \(\d+\): .*nen\/gates\.json/);
  expect(text).not.toMatch(/5\. unmapped/);
  // The printed guided-fill line runs verbatim, even with a space in the path; it is the line after the heading.
  const lines = text.split('\n');
  const command = lines[lines.findIndex((entry) => entry.startsWith('  1. defaults')) + 1].trim();
  const ran = spawnSync('bash', ['-c', command], { encoding: 'utf8', env });
  expect([0, 1], ran.stderr).toContain(ran.status);
  expect(ran.stdout).toMatch(/item\(s\) outstanding|every item is satisfied/);
});

test('a --hatsu-root without the catalogue still reports: the catalogue is read from the running tree', () => {
  const repo = scaffold();
  const root = temp();
  cpSync(join(source, 'templates'), join(root, 'templates'), { recursive: true });
  cpSync(join(source, 'nen'), join(root, 'nen'), { recursive: true });
  const report = tenkai(repo, 'diagnose', true, ['--hatsu-root', root]);
  expect(report.outstanding).toBeGreaterThan(0);
  for (const row of report.items.filter((item: any) => OUTSTANDING.includes(item.state))) expect(row.fix, row.id).toBeTruthy();
});

test('a re-run after each fix shows the outstanding count going down', () => {
  const repo = scaffold();
  const before = tenkai(repo, 'diagnose');
  // Step 1 of the guided fill: apply writes only defaults and Hatsu seeds, and settles every default item.
  tenkai(repo, 'apply');
  const settled = tenkai(repo, 'diagnose');
  expect(settled.outstanding).toBeLessThan(before.outstanding);
  for (const id of before.guide.defaults) expect(settled.guide.defaults, id).not.toContain(id);
  // Step 2: the owner answers an absent row; the item's own run line, with the answer single-quoted, settles it.
  const build = settled.items.find((row: any) => row.id === 'lane/nextjs/build');
  expect(build.fix.fill).toBe('owner');
  const answer = JSON.stringify({ exe: 'pnpm', argv: ['run', 'build'] });
  const ran = spawnSync('bash', ['-c', build.fix.run[0].replace('<command-json>', quote(answer))], { encoding: 'utf8', env });
  expect(ran.status, ran.stderr).toBe(0);
  const answered = tenkai(repo, 'diagnose');
  expect(answered.items.find((row: any) => row.id === 'lane/nextjs/build').state).toBe('satisfied');
  expect(answered.outstanding).toBe(settled.outstanding - 1);
  // Step 3: Tenkai's § 6c edit replaces a seat after the owner decides; its detect reads it, and the count drops again.
  const archive = answered.items.find((row: any) => row.id === 'lane/nextjs/archive');
  expect(archive.fix).toMatchObject({ run: [], fill: 'edit', detect: `nen schema check --repo ${quote(realpathSync(repo))}` });
  const file = join(repo, 'nen/contract.json');
  const contract = JSON.parse(readFileSync(file, 'utf8'));
  contract.project.verbs.nextjs.archive = { exe: 'pnpm', argv: ['run', 'build'] };
  writeFileSync(file, JSON.stringify(contract, null, 2) + '\n');
  // nen schema check reads every declaration; the item's own file is the line that must read ok.
  expect(spawnSync('bash', ['-c', archive.fix.detect], { encoding: 'utf8', env }).stdout).toMatch(/ok +nen\/contract\.json/);
  const final = tenkai(repo, 'diagnose');
  expect(final.items.find((row: any) => row.id === 'lane/nextjs/archive').state).toBe('satisfied');
  expect(final.outstanding).toBe(answered.outstanding - 1);
});
