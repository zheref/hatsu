#!/usr/bin/env node
// zheref/hatsu#502: hermetic fixture for scripts/skill_shape_check.mts and
// scripts/canon_coverage_check.mts. Each case builds a throwaway root and asserts the exit code and
// the stream split (findings on stdout, refusals on stderr). The shape cases run the REAL nen pr
// body-check (NEN, else PATH), since the heading match is nen's; one stub nen proves a nen refusal is
// wiring. The last read is this checkout's LIVE read, which fails the lane on a finding (exit 1) and
// on a read that could not run (exit 2): a touched skill's shape is judged against the merge base of
// HATSU_BASE_SHA (the base revision unit_tests_ci.mts hands every lane; fetched into a shallow
// checkout, history unshallowed, when absent) else of origin/main, and with neither it is NOT
// CHECKED, exit 2, never green. `--live <root>` runs that read alone; the hermetic cases run it over
// planted roots to prove each red path.
import assert from 'node:assert/strict';
import { chmodSync, cpSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const shape = fileURLToPath(new URL('./skill_shape_check.mts', import.meta.url));
const coverage = fileURLToPath(new URL('./canon_coverage_check.mts', import.meta.url));
const live = fileURLToPath(new URL('..', import.meta.url));
const nen = process.env.NEN || 'nen';

function gitIn(root: string, argv: string[]): { ok: boolean; out: string } {
  const r = spawnSync('git', ['-C', root, ...argv], { encoding: 'utf8' });
  return { ok: r.status === 0, out: String(r.stdout).trim() };
}
// The base commit and enough history to find the merge base; false when either cannot be had.
function ensureBase(root: string, sha: string): boolean {
  if (!/^[0-9a-f]{7,64}$/.test(sha)) return false;
  if (!gitIn(root, ['cat-file', '-e', `${sha}^{commit}`]).ok && !gitIn(root, ['fetch', '--no-tags', '--quiet', 'origin', sha]).ok) return false;
  if (gitIn(root, ['rev-parse', '--is-shallow-repository']).out === 'true' && !gitIn(root, ['fetch', '--no-tags', '--quiet', '--unshallow', 'origin']).ok) return false;
  return gitIn(root, ['merge-base', sha, 'HEAD']).ok;
}
function liveRead(root: string): number {
  let red = false;
  const relay = (r: ReturnType<typeof spawnSync>): void => {
    process.stdout.write(String(r.stdout));
    process.stderr.write(String(r.stderr));
  };
  const cov = spawnSync(process.execPath, [coverage, '--root', root], { encoding: 'utf8' });
  relay(cov);
  if (cov.status !== 0 && cov.status !== 1) return 2;
  if (cov.status === 1) red = true;
  const sha = process.env.HATSU_BASE_SHA || '';
  let selector: string[] | null = null;
  if (sha) selector = ensureBase(root, sha) ? ['--base', sha] : null;
  else if (gitIn(root, ['rev-parse', '--verify', '--quiet', 'origin/main']).ok) selector = ['--base', 'origin/main'];
  if (!selector) {
    console.error(`NOT CHECKED: live touched-skill shape (${sha ? `base ${sha} or its merge base could not be read` : 'no HATSU_BASE_SHA and no origin/main'}); a read that did not run fails the lane`);
    return 2;
  }
  const sh = spawnSync(process.execPath, [shape, '--root', root, ...selector], { encoding: 'utf8', env: { ...process.env, NEN: nen } });
  relay(sh);
  if (sh.status !== 0 && sh.status !== 1) return 2;
  if (sh.status === 1) red = true;
  return red ? 1 : 0;
}
if (process.argv[2] === '--live') {
  if (!process.argv[3]) {
    console.error('usage: skill_shape_check_fixture.mts [--live <root>]');
    process.exit(2);
  }
  process.exit(liveRead(process.argv[3]));
}

const scratch = mkdtempSync(join(tmpdir(), 'hatsu-skill-shape-fixture-'));
let cases = 0;

type Run = { status: number | null; stdout: string; stderr: string };
function run(script: string, args: string[], env: Record<string, string> = {}): Run {
  const r = spawnSync(process.execPath, [script, ...args], { cwd: scratch, encoding: 'utf8', env: { ...process.env, NEN: nen, ...env } });
  return { status: r.status, stdout: String(r.stdout), stderr: String(r.stderr) };
}
function expect(name: string, script: string, args: string[], status: number, out: RegExp[] = [], notOut: RegExp[] = [], env: Record<string, string> = {}): Run {
  const r = run(script, args, env);
  const detail = `${name}: exit ${r.status}\nstdout: ${r.stdout}\nstderr: ${r.stderr}`;
  assert.equal(r.status, status, detail);
  const stream = status === 2 ? r.stderr : r.stdout;
  for (const re of out) assert.match(stream, re, detail);
  for (const re of notOut) assert.doesNotMatch(r.stdout + r.stderr, re, detail);
  if (status === 2) assert.equal(r.stdout, '', `${name}: a refusal prints nothing on stdout\n${detail}`);
  else assert.equal(r.stderr, '', `${name}: findings go to stdout only\n${detail}`);
  cases += 1;
  console.log(`ok ${cases} - ${name}`);
  return r;
}
function write(path: string, text: string): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text);
}
function git(root: string, ...argv: string[]): void {
  const r = spawnSync('git', ['-C', root, ...argv], { encoding: 'utf8' });
  assert.equal(r.status, 0, `git ${argv.join(' ')}: ${r.stderr}`);
}
const FULL = '# s\n\n## 1. Steps\n\ntext\n\n## 2. Residue\n\nnone\n\n## 3. Authority and hard limits\n\nnone\n';
const NO_AUTHORITY = '# s\n\n## Residue\n\nnone\n\n## Hard limits\n\nnone\n';
const NOTHING = '# s\n\n## Steps\n\ntext\n';
const liveShape = JSON.parse(readFileSync(join(live, 'contracts', 'skill-shape.json'), 'utf8'));

function shapeRoot(name: string, exemptions: unknown[] = []): string {
  const root = join(scratch, name);
  write(join(root, 'claude/skills/good/SKILL.md'), FULL);
  write(join(root, 'claude/skills/bad/SKILL.md'), FULL);
  write(join(root, 'claude/skills/old/SKILL.md'), NOTHING);
  write(join(root, 'contracts/skill-shape.json'), JSON.stringify({ requirements: liveShape.requirements, exemptions }));
  git(root, 'init', '-q');
  git(root, 'add', '-A');
  git(root, '-c', 'user.name=f', '-c', 'user.email=f@example.invalid', 'commit', '-qm', 'base');
  return root;
}

try {
  // AC-1: a touched skill missing a section fails by name; an untouched one is never failed.
  let root = shapeRoot('touched');
  const base = join(scratch, 'touched-base');
  cpSync(root, base, { recursive: true });
  write(join(root, 'claude/skills/bad/SKILL.md'), NO_AUTHORITY);
  expect('--base: a touched skill missing a section is named', shape, ['--root', root, '--base', 'HEAD'], 1,
    [/^skill-shape: bad: missing the authority section \(claude\/skills\/bad\/SKILL\.md\)$/m, /1 skill\(s\) checked .*\(bad\); 1 finding/], [/old/, /residue section/]);
  expect('--base-root: the same verdict against a base tree', shape, ['--root', root, '--base-root', base], 1, [/bad: missing the authority section/], [/old:/]);
  write(join(root, 'claude/skills/fresh/SKILL.md'), NO_AUTHORITY.replace('## Residue\n\nnone\n\n', ''));
  expect('--base: an untracked new skill is touched', shape, ['--root', root, '--base', 'HEAD'], 1, [/fresh: missing the residue section/, /fresh: missing the authority section/, /bad: missing/]);
  expect('--base-root: a skill absent at base is touched', shape, ['--root', root, '--base-root', base], 1, [/fresh: missing the residue section/]);
  rmSync(join(root, 'claude/skills/fresh'), { recursive: true });
  write(join(root, 'claude/skills/bad/SKILL.md'), FULL);
  expect('--base: an untouched tree checks nothing and passes', shape, ['--root', root, '--base', 'HEAD'], 0, [/0 skill\(s\) checked .*; 0 finding/]);
  expect('--base-root: identical bytes check nothing', shape, ['--root', root, '--base-root', base], 0, [/0 skill\(s\) checked/]);
  expect('--skills good passes', shape, ['--root', root, '--skills', 'good'], 0, [/1 skill\(s\) checked .*\(good\)/]);
  expect('--all names the old skill by every missing section', shape, ['--root', root, '--all'], 1,
    [/old: missing the residue section/, /old: missing the authority section/, /old: missing the hard-limits section/], [/good: missing/]);
  // A heading at another level is not the section.
  write(join(root, 'claude/skills/bad/SKILL.md'), FULL.replace('## 2. Residue', '### 2. Residue'));
  expect('a level-3 Residue heading is not the section', shape, ['--root', root, '--skills', 'bad'], 1, [/bad: missing the residue section/]);

  // AC-2: an exemption names its reason; one with none fails.
  root = shapeRoot('exempt', [{ skill: 'old', sections: ['residue', 'authority', 'hard-limits'], reason: 'a fixture skill with no steps' }]);
  expect('a reasoned exemption skips its sections', shape, ['--root', root, '--skills', 'old'], 0, [/0 finding/]);
  root = shapeRoot('partial', [{ skill: 'old', sections: ['residue'], reason: 'r' }]);
  expect('an exemption skips only the sections it names', shape, ['--root', root, '--skills', 'old'], 1, [/old: missing the authority section/], [/old: missing the residue/]);
  root = shapeRoot('noreason', [{ skill: 'old', sections: ['residue'] }]);
  expect('an exemption with no reason fails by name, checked or not', shape, ['--root', root, '--skills', 'good'], 1, [/^skill-shape: exemption old: names no reason$/m]);
  root = shapeRoot('blank', [{ skill: 'old', sections: ['residue'], reason: '   ' }]);
  expect('a blank reason is no reason', shape, ['--root', root, '--base', 'HEAD'], 1, [/exemption old: names no reason/]);
  root = shapeRoot('unknown', [{ skill: 'ghost', sections: ['residue'], reason: 'r' }, { skill: 'old', sections: ['summary'], reason: 'r' }, { skill: 'old', sections: [], reason: 'r' }]);
  expect('an unknown skill, an unknown section and an empty section list are named', shape, ['--root', root, '--base', 'HEAD'], 1,
    [/exemption ghost: names no skill under claude\/skills/, /exemption old: names unknown section "summary"/, /exemption old: names no section/]);
  root = shapeRoot('stale', [{ skill: 'good', sections: ['residue'], reason: 'r' }]);
  expect('an exemption for a section the checked skill carries is stale', shape, ['--root', root, '--skills', 'good'], 1, [/exemption good: stale, the skill carries the residue section/]);

  // A reasoned exemption may be added over the base's list (AC-2); one without a reason fails.
  root = shapeRoot('grow');
  write(join(root, 'contracts/skill-shape.json'), JSON.stringify({ requirements: liveShape.requirements, exemptions: [{ skill: 'old', sections: ['residue', 'authority', 'hard-limits'], reason: 'r' }] }));
  write(join(root, 'claude/skills/old/SKILL.md'), NOTHING + '\ntouched\n');
  expect('--base: an added reasoned exemption passes for a touched skill', shape, ['--root', root, '--base', 'HEAD'], 0, [/\(old\); 0 finding/]);
  write(join(root, 'contracts/skill-shape.json'), JSON.stringify({ requirements: liveShape.requirements, exemptions: [{ skill: 'old', sections: ['residue', 'authority', 'hard-limits'] }] }));
  expect('--base: an added exemption without a reason fails', shape, ['--root', root, '--base', 'HEAD'], 1, [/exemption old: names no reason/]);

  // Only the section's own heading counts, never a heading that mentions the word (N517-10).
  root = shapeRoot('exact');
  for (const [heading, ok] of [['## 1. Invocation and authority', false], ['## 0. In-flight discovery — standing authority', false],
    ['## Residue, authority and hard limits', true], ['## 4. Authority — per iteration', true], ['## 8. Resuming & Residue', false]] as Array<[string, boolean]>) {
    write(join(root, 'claude/skills/bad/SKILL.md'), `# s\n\n## Residue\n\nx\n\n## Hard limits\n\nx\n\n${heading}\n\nx\n`);
    expect(`heading ${JSON.stringify(heading)} ${ok ? 'is' : 'is not'} the Authority section`, shape, ['--root', root, '--skills', 'bad'], ok ? 0 : 1, ok ? [] : [/bad: missing the authority section/]);
  }

  // Wiring is exit 2, never a finding.
  root = shapeRoot('wiring');
  const stub = join(scratch, 'nen-stub');
  write(stub, '#!/bin/sh\necho "stub refused" >&2\nexit 3\n');
  chmodSync(stub, 0o755);
  expect('a nen exit other than 0 or 1 is wiring', shape, ['--root', root, '--skills', 'good', '--nen', stub], 2, [/nen pr body-check exited 3 on good: stub refused/]);
  write(stub, '#!/bin/sh\necho not-json\n');
  expect('a nen verdict that is not JSON is wiring', shape, ['--root', root, '--skills', 'good', '--nen', stub], 2, [/printed no JSON verdict on good/]);
  write(stub, '#!/bin/sh\necho \'{"results":[{"name":"residue","satisfied":true}]}\'\n');
  expect('a verdict missing a requirement row is wiring', shape, ['--root', root, '--skills', 'good', '--nen', stub], 2, [/has no row for authority/]);
  expect('a nen that cannot start is wiring', shape, ['--root', root, '--skills', 'good', '--nen', join(scratch, 'absent-nen')], 2, [/could not run/]);
  const privateTmp = join(scratch, 'tmp');
  mkdirSync(privateTmp);
  write(stub, '#!/bin/sh\nexit 3\n');
  expect('a wiring refusal removes its temporary directory', shape, ['--root', root, '--skills', 'good', '--nen', stub], 2, [/exited 3/], [], { TMPDIR: privateTmp, TMP: privateTmp, TEMP: privateTmp });
  assert.deepEqual(readdirSync(privateTmp), [], 'a refusal left a hatsu-skill-shape-* directory behind');
  expect('no selector is usage', shape, ['--root', root], 2, [/exactly one of/]);
  expect('two selectors are usage', shape, ['--root', root, '--all', '--skills', 'good'], 2, [/exactly one of/]);
  expect('an unknown flag is usage', shape, ['--root', root, '--all', '--json'], 2, [/unknown argument "--json"/]);
  expect('a --base starting with - is refused', shape, ['--root', root, '--base', '-x'], 2, [/starts with '-'/]);
  expect('a --base git cannot resolve is refused', shape, ['--root', root, '--base', 'no-such-ref'], 2, [/git merge-base no-such-ref HEAD failed/]);
  expect('an unknown --skills name is refused', shape, ['--root', root, '--skills', 'nope'], 2, [/has no claude\/skills\/nope\/SKILL\.md/]);
  expect('a missing --base-root is refused', shape, ['--root', root, '--base-root', join(scratch, 'nowhere')], 2, [/is not a directory/]);
  expect('a root with no skills is refused', shape, ['--root', scratch, '--all'], 2, [/has no claude\/skills directory/]);
  write(join(root, 'contracts/skill-shape.json'), '{');
  expect('an unparseable contract is refused', shape, ['--root', root, '--all'], 2, [/cannot read the shape contract/]);
  write(join(root, 'contracts/skill-shape.json'), JSON.stringify({ requirements: [], exemptions: [] }));
  expect('an empty requirement set is refused', shape, ['--root', root, '--all'], 2, [/requirements must be a non-empty array/]);
  write(join(root, 'contracts/skill-shape.json'), JSON.stringify({ requirements: liveShape.requirements }));
  expect('a contract with no exemptions array is refused', shape, ['--root', root, '--all'], 2, [/exemptions must be an array/]);

  // AC-3 and AC-4: decision rows carry their citing list; every lane is named by canon.
  function coverageRoot(name: string, rows: unknown[], lanes: string[], doc: string): string {
    const r = join(scratch, name);
    write(join(r, 'claude/skills/alpha/SKILL.md'), 'Row `row-a` and row `row-b`.\n');
    write(join(r, 'claude/skills/beta/SKILL.md'), 'Row `row-a`, and merge as a plain word.\n');
    write(join(r, 'nen/decisions.json'), JSON.stringify({ rows }));
    write(join(r, 'nen/contract.json'), JSON.stringify({ project: { lanes: Object.fromEntries(lanes.map((l) => [l, { stack: 's', cwd: '.' }])) } }));
    write(join(r, 'contracts/prose.lint.json'), JSON.stringify({ paths: { include: ['claude/skills/*/SKILL.md', 'docs/**/*.md'] } }));
    write(join(r, 'docs/config/lanes.md'), doc);
    write(join(r, 'surfaces/x/docs/lanes.md'), 'The `ghost-lane` lane.\n');
    return r;
  }
  const clean = [
    { id: 'row-a', citedBy: ['alpha', 'beta'] },
    { id: 'row-b', citedBy: ['alpha'] },
    { id: 'merge', citedBy: [], uncitedReason: 'raised in docs/WORKFLOW.md' },
  ];
  const doc = 'Run `lane-one`, and `nen shu test --lane lane-two --repo .`.\n';
  root = coverageRoot('cov-clean', clean, ['lane-one', 'lane-two'], doc);
  expect('a complete citing list and named lanes pass', coverage, ['--root', root], 0, [/3 decision row\(s\), 2 cited by a skill; 2 lane\(s\) over 3 canon file\(s\); 0 finding/]);
  root = coverageRoot('cov-rows', [
    { id: 'row-a', citedBy: ['alpha'] },
    { id: 'row-b' },
    { id: 'merge', citedBy: [] },
    { id: 'row-c', citedBy: ['beta', 'gamma'] },
    { id: 'row-d', citedBy: ['alpha'], uncitedReason: 'x' },
  ], ['lane-one'], doc);
  expect('every citing-list defect is reported by row id', coverage, ['--root', root], 1, [
    /^coverage: decision row-a: cited by beta, which citedBy does not list$/m,
    /^coverage: decision row-b: no citedBy list of skill names \(cited by alpha\)$/m,
    /^coverage: decision merge: cited by no skill, and no uncitedReason says where it is raised$/m,
    /^coverage: decision row-c: citedBy lists beta, which does not cite it$/m,
    /^coverage: decision row-c: citedBy names gamma, which has no claude\/skills\/gamma\/SKILL\.md$/m,
    /^coverage: decision row-d: citedBy lists alpha, which does not cite it$/m,
  ]);
  root = coverageRoot('cov-word', [{ id: 'row-a', citedBy: ['alpha', 'beta'] }, { id: 'row-b', citedBy: ['alpha'] }, { id: 'merge', citedBy: ['alpha'] }], ['lane-one'], doc);
  write(join(root, 'claude/skills/alpha/SKILL.md'), 'Row `row-a` and row `row-b`; the G2 prompt (row\n`merge`).\n');
  write(join(root, 'claude/skills/beta/SKILL.md'), 'Row `row-a`.\n\nGit subcommands: `push`, `merge`, `tag`.\n');
  expect('an ordinary-word id is cited only beside a row context', coverage, ['--root', root], 0, [/0 finding/]);
  root = coverageRoot('cov-word-false', [{ id: 'row-a', citedBy: ['alpha', 'beta'] }, { id: 'row-b', citedBy: ['alpha'] }, { id: 'merge', citedBy: ['beta'] }], ['lane-one'], doc);
  write(join(root, 'claude/skills/beta/SKILL.md'), 'Row `row-a`.\n\nGit subcommands: `push`, `merge`, `tag`.\n');
  expect('a listed skill using the word as a plain code span does not cite it', coverage, ['--root', root], 1, [/^coverage: decision merge: citedBy lists beta, which does not cite it$/m]);
  root = coverageRoot('cov-sort', [{ id: 'row-a', citedBy: ['beta', 'alpha'] }, { id: 'row-b', citedBy: ['alpha', 'alpha'] }, { id: 'merge', citedBy: [], uncitedReason: 'r' }], ['lane-one'], doc);
  expect('an unsorted or repeated citedBy is reported by row id', coverage, ['--root', root], 1, [/decision row-a: citedBy is not sorted/, /decision row-b: citedBy is not sorted, or names a skill twice/]);
  root = coverageRoot('cov-stale', [{ id: 'row-a', citedBy: ['alpha', 'beta'], uncitedReason: 'old' }, { id: 'row-b', citedBy: ['alpha'] }], ['lane-one'], doc);
  expect('an uncitedReason on a cited row is stale', coverage, ['--root', root], 1, [/^coverage: decision row-a: uncitedReason on a row alpha, beta cites \(stale\)$/m]);
  root = coverageRoot('cov-lanes', clean, ['lane-one', 'lane-two', 'ghost-lane', 'lane'], doc);
  expect('a lane named by no canon file is reported by name; surfaces/ never counts', coverage, ['--root', root], 1,
    [/^coverage: lane ghost-lane: named by no canon file/m, /^coverage: lane lane: named by no canon file/m], [/lane lane-one:/, /lane lane-two:/]);
  write(join(root, 'nen/decisions.json'), '{');
  expect('an unparseable decisions file is wiring', coverage, ['--root', root], 2, [/cannot read nen\/decisions\.json/]);
  write(join(root, 'nen/decisions.json'), JSON.stringify({ rows: [{ class: 'x' }] }));
  expect('a row with no id is wiring', coverage, ['--root', root], 2, [/rows\[0\] has no string id/]);
  write(join(root, 'nen/decisions.json'), JSON.stringify({ rows: clean }));
  write(join(root, 'contracts/prose.lint.json'), JSON.stringify({ paths: {} }));
  expect('a lint contract with no include list is wiring', coverage, ['--root', root], 2, [/has no paths\.include list/]);
  expect('an unknown flag is usage', coverage, ['--root', root, '--json'], 2, [/unknown or incomplete argument "--json"/]);

  // The live read over planted roots: every finding and every unrun read fails it (zheref/hatsu#502).
  const fixture = fileURLToPath(import.meta.url);
  function liveRoot(name: string): string {
    const r = coverageRoot(name, clean, ['lane-one', 'lane-two'], doc);
    for (const skill of ['alpha', 'beta']) write(join(r, `claude/skills/${skill}/SKILL.md`), readFileSync(join(r, `claude/skills/${skill}/SKILL.md`), 'utf8') + '\n' + FULL);
    write(join(r, 'claude/skills/old/SKILL.md'), NOTHING);
    write(join(r, 'contracts/skill-shape.json'), JSON.stringify({ requirements: liveShape.requirements, exemptions: [] }));
    git(r, 'init', '-q');
    git(r, 'add', '-A');
    git(r, '-c', 'user.name=f', '-c', 'user.email=f@example.invalid', 'commit', '-qm', 'base');
    return r;
  }
  const head = (r: string): string => gitIn(r, ['rev-parse', 'HEAD']).out;
  function expectLive(name: string, root: string, sha: string, status: number, out: RegExp[] = [], notOut: RegExp[] = []): void {
    const r = spawnSync(process.execPath, [fixture, '--live', root], { cwd: scratch, encoding: 'utf8', env: { ...process.env, NEN: nen, HATSU_BASE_SHA: sha } });
    const detail = `${name}: exit ${r.status}\nstdout: ${r.stdout}\nstderr: ${r.stderr}`;
    assert.equal(r.status, status, detail);
    for (const re of out) assert.match(String(r.stdout) + String(r.stderr), re, detail);
    for (const re of notOut) assert.doesNotMatch(String(r.stdout), re, detail);
    cases += 1;
    console.log(`ok ${cases} - live: ${name}`);
  }
  root = liveRoot('live-clean');
  expectLive('a clean planted root reads green', root, head(root), 0, [/0 finding/]);
  write(join(root, 'claude/skills/alpha/SKILL.md'), 'Row `row-a` and row `row-b`.\n' + NO_AUTHORITY);
  expectLive('a touched skill missing a section is red, the untouched old skill never named', root, head(root), 1, [/alpha: missing the authority section/], [/old:/]);
  root = liveRoot('live-exempt');
  write(join(root, 'contracts/skill-shape.json'), JSON.stringify({ requirements: liveShape.requirements, exemptions: [{ skill: 'old', sections: ['residue'] }] }));
  expectLive('a reasonless exemption is red', root, head(root), 1, [/exemption old: names no reason/]);
  root = liveRoot('live-grown');
  write(join(root, 'contracts/skill-shape.json'), JSON.stringify({ requirements: liveShape.requirements, exemptions: [{ skill: 'old', sections: ['residue'], reason: 'r' }] }));
  expectLive('a reasoned exemption added over the base list reads green', root, head(root), 0, [/0 finding/]);
  root = liveRoot('live-uncited');
  write(join(root, 'nen/decisions.json'), JSON.stringify({ rows: [...clean, { id: 'row-z', citedBy: [] }] }));
  expectLive('an uncited row with no reason is red', root, head(root), 1, [/decision row-z: cited by no skill/]);
  root = liveRoot('live-lane');
  write(join(root, 'nen/contract.json'), JSON.stringify({ project: { lanes: { 'lane-one': {}, 'lane-two': {}, 'lane-three': {} } } }));
  expectLive('an unnamed lane is red', root, head(root), 1, [/lane lane-three: named by no canon file/]);
  root = liveRoot('live-nobase');
  expectLive('no base and no origin/main is NOT CHECKED, exit 2', root, '', 2, [/NOT CHECKED/]);
  expectLive('an unreadable base sha is NOT CHECKED, exit 2', root, 'deadbeefdeadbeef', 2, [/NOT CHECKED: .*base deadbeefdeadbeef/]);
  // A PR behind its base: the base branch edited `old` after the PR branched; only the PR's own
  // changes are touched, so `old` is not failed for an edit the base made (N517-2).
  root = liveRoot('live-behind');
  const branchPoint = head(root);
  git(root, 'checkout', '-q', '-b', 'pr');
  git(root, 'checkout', '-q', '-');
  write(join(root, 'claude/skills/old/SKILL.md'), NOTHING + '\nedited on the base branch\n');
  git(root, '-c', 'user.name=f', '-c', 'user.email=f@example.invalid', 'commit', '-qam', 'base moves');
  const baseTip = head(root);
  git(root, 'checkout', '-q', 'pr');
  assert.notEqual(baseTip, branchPoint);
  expectLive('a PR behind its base is judged from the merge base, not the base tip', root, baseTip, 0, [/0 skill\(s\) checked against the merge base/], [/old:/]);
  write(join(root, 'claude/skills/beta/SKILL.md'), 'Row `row-a`.\n' + NOTHING);
  expectLive('the PR\'s own broken skill is still red behind its base', root, baseTip, 1, [/beta: missing the residue section/], [/old:/]);

  // This checkout's live read: strict, red on any finding, exit 2 when it could not run. A red read
  // prints its red summary and no `ok` line or pass count (N517-12).
  const liveStatus = liveRead(live);
  if (liveStatus !== 0) {
    console.error(`not ok ${cases + 1} - live read of this checkout (exit ${liveStatus})`);
    console.error(`skill-shape fixture: RED, the live read of this checkout exited ${liveStatus}${liveStatus === 1 ? ' (findings above)' : ' (could not run)'}; ${cases} hermetic case(s) held before it`);
    process.exitCode = liveStatus;
  } else {
    cases += 1;
    console.log(`ok ${cases} - live read of this checkout (exit 0)`);
    console.log(`skill-shape fixture: ${cases} case(s) passed`);
  }
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
