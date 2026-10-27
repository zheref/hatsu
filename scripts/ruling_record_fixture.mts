#!/usr/bin/env node
// zheref/hatsu#443: fixture for scripts/ruling_record.mts. Hermetic cases use synthetic rosters, records
// and a stub nen (its `repo resolve` included, so reference coding is hermetic too); the last cases run
// the REAL nen (NEN, else `nen` on PATH; unit-tests.yml hands its verified binary) through record ->
// export -> render -> check in a throwaway git repository, one coded render against this checkout's
// nen/repos.json, and the check over the live roster. HR-368's cases (zheref/hatsu#506) move the stub registry under a landed row.
import assert from 'node:assert/strict';
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('./ruling_record.mts', import.meta.url));
const scratch = mkdtempSync(join(tmpdir(), 'hatsu-ruling-record-'));
let cases = 0;

interface Run { status: number | null; stdout: string; stderr: string }
function run(args: string[], env: Record<string, string> = {}): Run {
  const r = spawnSync(process.execPath, [script, ...args], { cwd: scratch, encoding: 'utf8', env: { ...process.env, ...env } });
  return { status: r.status, stdout: String(r.stdout), stderr: String(r.stderr) };
}
function expect(name: string, r: Run, status: number, stdout: RegExp | null = null, stderr: RegExp | null = null): void {
  const detail = `${name}: exit ${r.status}\nstdout: ${r.stdout}\nstderr: ${r.stderr}`;
  assert.equal(r.status, status, detail);
  if (stdout) assert.match(r.stdout, stdout, detail);
  if (stderr) assert.match(r.stderr, stderr, detail);
  if (status === 2) assert.equal(r.stdout.includes('::error'), false, `${name}: a wiring refusal prints no annotation\n${detail}`);
  cases += 1;
  console.log(`ok ${cases} - ${name}`);
}

const base = {
  contract: 'nen.stop.answer/v0.1', id: 'R-2026-10-23-01', effortId: 'opus/kurapika/demo', n: 1, gate: 'G4', row: null,
  who: 'kurapika', question: 'Which text wins when two canon documents disagree?\n',
  options: [
    { key: 'A', label: 'One list (Recommended)', consequence: 'the contract carries it' },
    { key: 'B', label: 'Keep prose', consequence: 'nothing *changes*' },
  ],
  kind: 'picked', pick: 'A', typed: null, answeredAt: '2026-10-23T10:00:00.000Z',
};
type Rec = typeof base | Record<string, unknown>;
const stem = (rec: Rec): string => `${String((rec as { effortId: string }).effortId).replace(/[^A-Za-z0-9._-]/g, '-')}--${(rec as { id: string }).id}`;
function recordFile(dir: string, rec: Rec, name = stem(rec)): string {
  mkdirSync(dir, { recursive: true });
  const path = join(dir, `${name}.json`);
  writeFileSync(path, `${JSON.stringify(rec, null, 2)}\n`);
  return path;
}
function renderRow(path: string, hr: string, status = 'ruled', settles = 'what it settles'): string {
  const r = run(['render', '--record', path, '--hr', hr, '--status', status, '--settles', settles]);
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trimEnd();
}
function roster(dir: string, rows: string[]): string {
  mkdirSync(dir, { recursive: true });
  const path = join(dir, 'ROSTER.md');
  writeFileSync(path, ['# roster', '', '| HR id | Question | Options | Picked | Status | Settles |', '|---|---|---|---|---|---|', ...rows, ''].join('\n'));
  return path;
}

// A stub nen: answers `stop answer show` from STUB_SHOW (a file) with STUB_EXIT, `repo resolve <token>` from
// STUB_RESOLVE (token -> repos[] or a raw string; absent -> exit 1; STUB_RESOLVE_EXIT forces a code), and logs every argv.
const stubJs = join(scratch, 'stub-nen.mjs');
writeFileSync(stubJs, `import { appendFileSync, readFileSync } from 'node:fs';
appendFileSync(process.env.STUB_LOG, JSON.stringify(process.argv.slice(2)) + '\\n');
if (process.argv[2] === 'repo' && process.argv[3] === 'resolve') {
  if (process.env.STUB_RESOLVE_EXIT) process.exit(Number(process.env.STUB_RESOLVE_EXIT));
  const reply = JSON.parse(readFileSync(process.env.STUB_RESOLVE, 'utf8'))[process.argv[4]];
  if (!reply) process.exit(1);
  process.stdout.write(typeof reply === 'string' ? reply : JSON.stringify({ token: process.argv[4], origin: null, repos: reply }));
  process.exit(0);
}
if (process.argv[4] === 'show') process.stdout.write(readFileSync(process.env.STUB_SHOW, 'utf8'));
else process.stdout.write('recorded R-2026-10-23-09 -> /stub\\n');
process.exit(Number(process.env.STUB_EXIT || 0));
`);
const stub = join(scratch, 'stub-nen');
writeFileSync(stub, `#!/bin/sh\nexec "${process.execPath}" "${stubJs}" "$@"\n`);
chmodSync(stub, 0o755);

try {
  const d1 = join(scratch, 'd1', 'ruling-records');
  const picked = recordFile(d1, base);
  const row = renderRow(picked, 'HR-334');
  assert.equal(row, '| <a id="hr-334"></a>**HR-334** · [opus-kurapika-demo--R-2026-10-23-01](ruling-records/opus-kurapika-demo--R-2026-10-23-01.json) | Which text wins when two canon documents disagree? | (A) One list (Recommended) — *the contract carries it* · (B) Keep prose — *nothing \\*changes\\** | picked (A): `One list (Recommended)` | ruled | what it settles |');
  cases += 1; console.log(`ok ${cases} - a pick renders the question, every option with its consequence, and the picked label`);

  const typed = recordFile(join(scratch, 't'), { ...base, id: 'R-2026-10-23-02', kind: 'typed', pick: null, typed: 'Neither | do C\nand say so' });
  assert.match(renderRow(typed, 'HR-335'), /\| typed \(verbatim\): \*"Neither \\\| do C<br>and say so"\* \|/);
  cases += 1; console.log(`ok ${cases} - a typed reply renders verbatim, its line break and pipe kept in the cell`);

  const matched = recordFile(join(scratch, 'm'), { ...base, id: 'R-2026-10-23-03', typed: 'Keep prose', pick: 'B' });
  assert.match(renderRow(matched, 'HR-336'), /\| typed, word for word \(B\): `Keep prose` \|/);
  cases += 1; console.log(`ok ${cases} - a typed reply nen matched to a label renders as that pick, never as verbatim`);

  const tick = recordFile(join(scratch, 'k'), { ...base, id: 'R-2026-10-23-04', options: [{ key: 'A', label: 'run `cleanup`', consequence: 'swept' }] });
  assert.match(renderRow(tick, 'HR-337'), /picked \(A\): `` run `cleanup` `` \|/);
  cases += 1; console.log(`ok ${cases} - a label holding a backtick renders in a double-backtick span`);

  const pre = recordFile(join(scratch, 'p'), { ...base, id: 'R-2026-10-23-07', question: 'Pre-answered under the typed --idle profile (HR-5); no picker was shown.\nSource: idle.source abc123\nRow wrap-up: ask once\n' });
  assert.match(renderRow(pre, 'HR-339'), /\| pre-answered \(idle\.source abc123\) \(A\): `One list \(Recommended\)` \|/);
  cases += 1; console.log(`ok ${cases} - an idle pre-answer renders as pre-answered with its source, never as a pick`);

  const ref = recordFile(join(scratch, 'r'), { ...base, id: 'R-2026-10-23-08', options: [{ key: 'ref', label: 'typed by design (no option)', consequence: 'the typed words are the answer' }], kind: 'typed', pick: null, typed: 'staging-eu' });
  const refRow = renderRow(ref, 'HR-340');
  assert.match(refRow, /\| none: typed by design \| typed \(verbatim\): \*"staging-eu"\* \|/);
  cases += 1; console.log(`ok ${cases} - a row typed by design renders its reference option as none and the answer as typed`);

  const html = recordFile(join(scratch, 'h'), { ...base, id: 'R-2026-10-23-09', question: 'Use <a id="hr-5"></a> or [x](https://e.x)?' });
  const htmlRow = renderRow(html, 'HR-341');
  assert.match(htmlRow, /\| Use &lt;a id="hr-5"&gt;&lt;\/a&gt; or \\\[x\\\]\(https:\/\/e\.x\)\? \|/);
  assert.equal(htmlRow.includes('<a id="hr-5">'), false, 'a record never renders an anchor');
  cases += 1; console.log(`ok ${cases} - markup and link brackets in a record are escaped, never rendered`);

  // PL-05, hermetic: `repo resolve` is the stub's. A `<repository> #N` in the record's prose and the picked
  // label renders coded (code spans too: PL-05 reads inside them); an unknown word, `all` (every
  // repository) and the maintainer's typed words are left as written; a coded slug passes the
  // private-name guard (the named list exempts zheref/akatsuki-ai), and a private one is refused unnamed.
  const one = (repo: string): { repo: string; code: null; kind: string; entry: null }[] => [{ repo, code: null, kind: 'name', entry: null }];
  const resolveMap = join(scratch, 'resolve.json');
  writeFileSync(resolveMap, JSON.stringify({ hatsu: one('zheref/hatsu'), nen: one('zheref/nen'), 'akatsuki-ai': one('zheref/akatsuki-ai'), zzp: one('zheref/zz-private-fixture'),
    all: [...one('zheref/hatsu'), ...one('zheref/nen')], junk: 'not json', bare: '{"token":"bare"}', slugless: one('noslash') }));
  const privList = join(scratch, 'private-list.txt');
  writeFileSync(privList, 'zheref/zz-private-fixture\nzheref/akatsuki-ai\n');
  const refsLog = join(scratch, 'refs-stub.log'); writeFileSync(refsLog, '');
  const refEnv = { NEN: stub, STUB_LOG: refsLog, STUB_RESOLVE: resolveMap, STUB_EXIT: '0' };
  const renderRef = (rec: Rec, env: Record<string, string> = refEnv): Run => run(['render', '--record', recordFile(join(scratch, 'refs'), rec), '--hr', 'HR-342', '--status', 'ruled', '--settles', 'x', '--names-file', privList], env);
  {
    const r = renderRef({ ...base, id: 'R-2026-10-23-10', question: 'hatsu #5 Q1, issue #6, all #3, `run hatsu #4`?', options: [{ key: 'A', label: 'nen #7', consequence: 'akatsuki-ai #8 moves' }], pick: 'A' });
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.match(r.stdout, /\| zheref\/hatsu#5 Q1, issue #6, all #3, `run zheref\/hatsu#4`\? \| \(A\) zheref\/nen#7 — \*zheref\/akatsuki-ai#8 moves\* \| picked \(A\): `zheref\/nen#7` \|/);
    cases += 1; console.log(`ok ${cases} - a repository-named #N renders coded in the question, a code span, the options and the picked label; an unknown word and all as written`);
    const t = renderRef({ ...base, id: 'R-2026-10-23-11', question: 'hatsu #5?', kind: 'typed', pick: null, typed: 'hatsu #9 stands' });
    assert.match(t.stdout, /\| zheref\/hatsu#5\? \|.*\| typed \(verbatim\): \*"hatsu #9 stands"\* \|/);
    cases += 1; console.log(`ok ${cases} - the maintainer's typed words are never coded`);
  }
  {
    // HR-368 (zheref/hatsu#506): a nen/repos.json change that moves a landed row's coding fails the lane by
    // HR id until that same PR re-renders the row. One rule whether a reference is renamed, stops resolving
    // or newly resolves; the record and the maintainer's typed words never change.
    const dir = join(scratch, 'hr368');
    const rec = recordFile(join(dir, 'ruling-records'), { ...base, id: 'R-2026-10-27-02', question: 'hatsu #5, nen #6 or bankai #7?', kind: 'typed', pick: null, typed: 'hatsu #9 stands' });
    const recordBytes = readFileSync(rec, 'utf8');
    const renderUnder = (env: Record<string, string>): string => {
      const r = run(['render', '--record', rec, '--hr', 'HR-368', '--status', 'ruled', '--settles', 'x', '--names-file', privList], env);
      assert.equal(r.status, 0, r.stdout + r.stderr);
      return r.stdout.trimEnd();
    };
    const landed = renderUnder(refEnv);
    assert.match(landed, /\| zheref\/hatsu#5, zheref\/nen#6 or bankai #7\? \|/);
    const landedRoster = roster(dir, [landed]);
    expect('HR-368: a landed coded row matches under the registry it landed with', run(['check', '--roster', landedRoster], refEnv), 0, /1 ROSTER rows match their records/);
    const registry = (name: string, map: Record<string, unknown>): Record<string, string> => {
      const file = join(scratch, `resolve-${name}.json`);
      writeFileSync(file, JSON.stringify(map));
      return { ...refEnv, STUB_RESOLVE: file };
    };
    const moves: [string, Record<string, string>][] = [
      ['a renamed repository', registry('renamed', { hatsu: one('zheref/hatsu-next'), nen: one('zheref/nen') })],
      ['a reference that stops resolving', registry('stops', { hatsu: one('zheref/hatsu') })],
      ['a word that newly resolves', registry('starts', { hatsu: one('zheref/hatsu'), nen: one('zheref/nen'), bankai: one('zheref/bankai-handbooks') })],
      ['a word that becomes ambiguous', registry('ambiguous', { hatsu: one('zheref/hatsu'), nen: [...one('zheref/nen'), ...one('zheref/nen-fork')] })],
    ];
    for (const [what, env] of moves) {
      expect(`HR-368: ${what} fails the landed row by HR id, naming the re-render`, run(['check', '--roster', landedRoster], env), 1, /HR-368: the question cell differs from record opus-kurapika-demo--R-2026-10-27-02; re-render it in this PR \(its coded references moved with nen\/repos\.json, HR-368\)/);
      const again = renderUnder(env);
      expect(`HR-368: ${what}, the row re-rendered in the same PR, passes`, run(['check', '--roster', roster(join(dir, what.replace(/\W+/g, '-')), [again]), '--records', join(dir, 'ruling-records')], env), 0, /1 ROSTER rows match their records/);
      assert.match(again, /\| typed \(verbatim\): \*"hatsu #9 stands"\* \|/, `${what}: the typed words never change\n${again}`);
    }
    {
      const retyped = run(['check', '--roster', roster(join(dir, 'retyped'), [landed.replace(' or bankai #7?', ' or bankai #7 instead?')]), '--records', join(dir, 'ruling-records')], refEnv);
      expect('HR-368: a hand-retyped row under an unchanged registry is a plain mismatch', retyped, 1, /HR-368: the question cell differs from record opus-kurapika-demo--R-2026-10-27-02; re-render it$/m);
      assert.equal(retyped.stdout.includes('nen/repos.json'), false, `a retyped row names no registry cause\n${retyped.stdout}`);
    }
    assert.equal(readFileSync(rec, 'utf8'), recordBytes, 'HR-368: the record is never rewritten');
    cases += 1; console.log(`ok ${cases} - HR-368: the record and the maintainer's typed words are unchanged by every re-render`);
  }
  {
    const r = renderRef({ ...base, id: 'R-2026-10-23-12', question: 'zzp #3?' });
    expect('a coded slug naming a private repository is refused, the name never printed', r, 1, /HR-342: record opus-kurapika-demo--R-2026-10-23-12 would be rendered with a private repository/);
    assert.equal((r.stdout + r.stderr).includes('zz-private'), false, `the private name is never printed\n${r.stdout}${r.stderr}`);
  }
  expect('an unparseable exit-0 resolve reply is wiring', renderRef({ ...base, id: 'R-2026-10-23-13', question: 'junk #3?' }), 2, null, /nen repo resolve junk --json did not parse/);
  expect('an exit-0 resolve reply with no repos[] is wiring', renderRef({ ...base, id: 'R-2026-10-23-13', question: 'bare #3?' }), 2, null, /nen repo resolve bare --json carries no repos\[\]/);
  expect('nen failing to resolve a repository word is wiring, never a guess', renderRef({ ...base, id: 'R-2026-10-23-13', question: 'hatsu #3?' }, { ...refEnv, STUB_RESOLVE_EXIT: '2' }), 2, null, /nen repo resolve hatsu could not run \(exit 2\)/);
  expect('an exit-0 resolve reply naming no owner/name is wiring', renderRef({ ...base, id: 'R-2026-10-23-13', question: 'slugless #3?' }), 2, null, /nen repo resolve slugless --json names no owner\/name/);
  {
    const r = renderRef({ ...base, id: 'R-2026-10-23-15', question: 'Which?', options: [{ key: 'A', label: 'nen #7', consequence: 'it lands' }], pick: 'A', typed: 'nen #7' });
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.match(r.stdout, /\| \(A\) zheref\/nen#7 — \*it lands\* \| typed, word for word \(A\): `nen #7` \|/);
    cases += 1; console.log(`ok ${cases} - a typed reply matched to a label keeps the maintainer's words in the answer cell; the option is coded`);
  }
  {
    // A guard exit other than 0 or 1 (127: the guard is missing) is wiring, never a private hit: the
    // script runs from a scratch root whose scripts/private_name_check.sh exits as told.
    const fake = join(scratch, 'fake-root');
    mkdirSync(join(fake, 'scripts'), { recursive: true });
    writeFileSync(join(fake, 'scripts', 'ruling_record.mts'), readFileSync(script, 'utf8'));
    writeFileSync(join(fake, 'scripts', 'private_name_check.sh'), 'exit "${FAKE_GUARD_EXIT:-127}"\n');
    const fakeRun = (args: string[], env: Record<string, string>): Run => {
      const r = spawnSync(process.execPath, [join(fake, 'scripts', 'ruling_record.mts'), ...args], { cwd: scratch, encoding: 'utf8', env: { ...process.env, ...env } });
      return { status: r.status, stdout: String(r.stdout), stderr: String(r.stderr) };
    };
    const rec = recordFile(join(scratch, 'refs'), { ...base, id: 'R-2026-10-23-16', question: 'hatsu #3?' });
    expect('render: a guard exit of 127 is wiring, never a private hit', fakeRun(['render', '--record', rec, '--hr', 'HR-342', '--status', 'ruled', '--settles', 'x'], refEnv), 2, null, /private-name guard could not run \(exit 127\)/);
    const fakeShow = join(scratch, 'fake-show.json');
    writeFileSync(fakeShow, JSON.stringify({ effortId: base.effortId, directory: '/x', records: [base] }));
    expect('export: a guard exit of 3 is wiring, never a private hit', fakeRun(['export', '--effort', base.effortId, '--id', base.id, '--repo', scratch, '--out', join(scratch, 'fake-out')], { NEN: stub, STUB_LOG: refsLog, STUB_SHOW: fakeShow, STUB_EXIT: '0', FAKE_GUARD_EXIT: '3' }), 2, null, /private-name guard could not run \(exit 3\)/);
  }

  const bad = recordFile(join(scratch, 'b'), { ...base, id: 'R-2026-10-23-05', contract: 'nen.stop.answer/v9' });
  {
    const lead = renderRow(picked, 'HR-7', 'superseded by HR-8 (a part; the rest stands)', 'Reverses [HR-3](#hr-3); `models.<surface>.frontier` a|b');
    assert.ok(lead.endsWith('| superseded by HR-8 (a part; the rest stands) | Reverses [HR-3](#hr-3); `models.<surface>.frontier` a\\|b |'), `the lead's cells stay markdown, a pipe escaped\n${lead}`);
    assert.ok(!lead.includes('\\[HR-3') && !lead.includes('&lt;surface'), `the lead's link and code span are not escaped\n${lead}`);
    console.log('ok - the status and settles cells are the lead\'s markdown, only a pipe escaped');
  }
  expect('a record of another contract is refused, never rendered', run(['render', '--record', bad, '--hr', 'HR-1', '--status', 'ruled', '--settles', 'x']), 2, null, /contract is not nen\.stop\.answer\/v0\.1/);
  const badPick = recordFile(join(scratch, 'bp'), { ...base, id: 'R-2026-10-23-06', pick: 'Z' });
  expect('a pick that is no option key is refused', run(['render', '--record', badPick, '--hr', 'HR-1', '--status', 'ruled', '--settles', 'x']), 2, null, /pick is none of the option keys/);
  expect('a malformed --hr is refused', run(['render', '--record', picked, '--hr', 'HR-x', '--status', 'ruled', '--settles', 'x']), 2, null, /--hr must be HR-<n>/);
  expect('both settles forms are refused', run(['render', '--record', picked, '--hr', 'HR-1', '--status', 'ruled', '--settles', 'x', '--settles-file', 'y']), 2, null, /exactly one of --settles/);
  expect('an unknown verb is usage', run(['frobnicate']), 2, null, /usage/);

  expect('a rendered row matches its record', run(['check', '--roster', roster(join(scratch, 'd1'), [row])]), 0, /1 ROSTER rows match their records/);
  expect('a retyped question is reported by HR id', run(['check', '--roster', roster(join(scratch, 'd1'), [row.replace('disagree?', 'differ?')])]), 1, /line=5::HR-334: the question cell differs from record opus-kurapika-demo--R-2026-10-23-01/);
  expect('a dropped option is reported', run(['check', '--roster', roster(join(scratch, 'd1'), [row.replace(/ · \(B\)[^|]*/, ' ')])]), 1, /HR-334: the options cell differs/);
  expect('a changed pick is reported', run(['check', '--roster', roster(join(scratch, 'd1'), [row.replace('picked (A)', 'picked (B)')])]), 1, /HR-334: the answer cell differs/);
  expect('an empty status cell is reported', run(['check', '--roster', roster(join(scratch, 'd1'), [row.replace('| ruled |', '|  |')])]), 1, /status and what-it-settles cells must be filled/);
  expect('a record cited by no row is an orphan finding', run(['check', '--roster', roster(join(scratch, 'd1'), ['| plain row |'])]), 1, /record opus-kurapika-demo--R-2026-10-23-01 is cited by no ROSTER row/);
  expect('one record cited twice is a finding', run(['check', '--roster', roster(join(scratch, 'd1'), [row, row.replace(/hr-334/, 'hr-338').replace(/HR-334/, 'HR-338')])]), 1, /cited by 2 rows/);
  expect('a citing line outside the rendered form is a finding', run(['check', '--roster', roster(join(scratch, 'd1'), [row, '| **HR-9** [R-2026-10-23-01](ruling-records/R-2026-10-23-01.json) | x |'])]), 1, /outside the rendered row form/);
  expect('a missing record is unreadable, a finding by HR id', run(['check', '--roster', roster(join(scratch, 'd2'), [row])]), 1, /HR-334: record opus-kurapika-demo--R-2026-10-23-01 is unreadable/);
  const d4 = join(scratch, 'd4', 'ruling-records');
  recordFile(d4, { ...base, effortId: 'other/clone' }, stem(base));
  expect('a record whose effort and id disagree with its file name is a collision', run(['check', '--roster', roster(join(scratch, 'd4'), [row])]), 1, /holds record other-clone--R-2026-10-23-01; a collision/);
  const d5 = join(scratch, 'd5', 'ruling-records');
  recordFile(d5, { ...base, contract: 'nen.stop.answer/v0.2' });
  expect('a record of a newer contract is wiring in check', run(['check', '--roster', roster(join(scratch, 'd5'), [row])]), 2, null, /frozen at the nen pin/);
  const d6 = join(scratch, 'd6', 'ruling-records');
  recordFile(d6, base);
  writeFileSync(join(d6, 'x\n::warning::forged.json'), '{}');
  const forged = run(['check', '--roster', roster(join(scratch, 'd6'), [row])]);
  assert.equal(forged.status, 1, forged.stdout);
  assert.equal(/^::warning::/m.test(forged.stdout), false, `a file name never forges an annotation: ${forged.stdout}`);
  cases += 1; console.log(`ok ${cases} - a file name holding a line break forges no annotation`);
  const d7 = join(scratch, 'd7', 'ruling-records');
  recordFile(d7, base);
  writeFileSync(join(d7, `${stem(base)}.json`), 'x\n::warning::forged');
  const parse = run(['check', '--roster', roster(join(scratch, 'd7'), [row])]);
  assert.match(parse.stdout, /is unreadable \(not readable as JSON\)/);
  assert.equal(/^::warning::/m.test(parse.stdout), false, `a parse error never echoes the file: ${parse.stdout}`);
  cases += 1; console.log(`ok ${cases} - a parse failure prints a fixed reason`);
  expect('a roster citing nothing says so, never clean by silence', run(['check', '--roster', roster(join(scratch, 'd3'), ['| plain |'])]), 0, /no ROSTER row cites a record yet/);
  expect('an unreadable roster is wiring', run(['check', '--roster', join(scratch, 'absent.md')]), 2, null, /cannot read/);
  expect('a path holding a comma is wiring', run(['check', '--roster', join(scratch, 'a,b.md')]), 2, null, /comma, colon or line break/);
  writeFileSync(join(scratch, 'not-a-dir'), 'x');
  expect('a records path that is a file is wiring', run(['check', '--roster', roster(join(scratch, 'd3'), ['| plain |']), '--records', join(scratch, 'not-a-dir')]), 2, null, /cannot list/);

  const log = join(scratch, 'stub.log');
  const show = join(scratch, 'show.json');
  writeFileSync(show, JSON.stringify({ effortId: base.effortId, directory: '/x', records: [{ ...base, hostPath: '/Users/someone/private' }] }));
  const stubEnv = { NEN: stub, STUB_LOG: log, STUB_SHOW: show, STUB_EXIT: '0' };
  const names = join(scratch, 'names.txt');
  writeFileSync(names, 'zz-secret\n');
  const out = join(scratch, 'export');
  const exp = (env: Record<string, string> = stubEnv, id = base.id): Run => run(['export', '--effort', base.effortId, '--id', id, '--repo', scratch, '--out', out, '--names-file', names], env);
  expect('export copies the record nen shows', exp(), 0, /exported R-2026-10-23-01/);
  assert.deepEqual(JSON.parse(readFileSync(join(out, `${stem(base)}.json`), 'utf8')), base, 'only the record\'s own keys are written');
  assert.deepEqual(JSON.parse(readFileSync(log, 'utf8').trim().split('\n').at(-1) ?? '[]'), ['stop', 'answer', 'show', base.effortId, '--repo', scratch, '--json']);
  expect('a second identical export is a no-op', exp(), 0, /already holds/);
  writeFileSync(join(out, `${stem(base)}.json`), '{}\n');
  expect('a conflicting copy is never replaced', exp(), 1, /exists with other content/);
  expect('an id not in the ledger is a finding', exp(stubEnv, 'R-2026-10-23-77'), 1, /not in effort/);
  expect('a ledger nen could not read is wiring', exp({ ...stubEnv, STUB_EXIT: '1' }), 2, null, /could not read the ledger \(exit 1\)/);
  writeFileSync(show, JSON.stringify({ records: [{ ...base, id: 'R-2026-10-23-11', typed: 'Ask zz-secret\nfirst', kind: 'typed', pick: null }] }));
  expect('export refuses a record naming a private repository, after a line break', exp(stubEnv, 'R-2026-10-23-11'), 1, /names a private repository/);
  writeFileSync(show, JSON.stringify({ records: [{ ...base, id: 'R-2026-10-23-12', typed: `use ghp_${'a'.repeat(36)}`, kind: 'typed', pick: null }] }));
  expect('export refuses a secret-shaped string', exp(stubEnv, 'R-2026-10-23-12'), 1, /secret-shaped/);
  assert.equal(existsSync(join(out, `${stem(base).replace('01', '12')}.json`)), false, 'nothing is written on a refusal');
  writeFileSync(show, 'not json');
  expect('unparseable nen output is wiring', exp(), 2, null, /did not parse/);

  const decisions = join(scratch, 'decisions.json');
  writeFileSync(decisions, JSON.stringify({ rows: [
    { id: 'wrap-up', class: 'ask-once-per-run', default: 'ask once', preferred: [
      { key: 'A', label: 'run cleanup', consequence: 'swept', recommended: true },
      { key: 'B', label: 'continue', command: 'nothing runs' }] },
    { id: 'publish-offer', class: 'ask-once-per-run', preferred: [{ key: 'A', label: 'publish', consequence: 'published' }] },
    { id: 'merge', class: 'human-gate', gate: 'G2' }] }));
  writeFileSync(log, '');
  expect('a pre-answer records the starred option through nen, the source named', run(['preanswer', '--effort', 'e/1', '--row', 'wrap-up', '--source', 'idle.source abc123', '--repo', scratch, '--decisions', decisions, '--dry-run'], stubEnv), 0, /recorded R-2026-10-23-09/);
  const call = JSON.parse(readFileSync(log, 'utf8').trim()) as string[];
  assert.deepEqual(call.slice(0, 7), ['stop', 'answer', '--record', 'e/1', '--row', 'wrap-up', '--who']);
  assert.deepEqual(call.filter((_, i) => call[i - 1] === '--option'), ['A=run cleanup::swept', 'B=continue::nothing runs']);
  assert.equal(call[call.indexOf('--pick') + 1], 'A');
  assert.equal(call.includes('--dry-run'), true);
  assert.equal(call.includes('--gate'), false, 'an ask-once pre-answer names its row alone');
  cases += 1; console.log(`ok ${cases} - the pre-answer call carries the row, every option, the starred pick and --dry-run`);
  expect('a human-gate row is never pre-answered', run(['preanswer', '--effort', 'e', '--row', 'merge', '--source', 's', '--decisions', decisions], stubEnv), 2, null, /never is \(HR-5\)/);
  expect('a row starring nothing cannot be pre-answered', run(['preanswer', '--effort', 'e', '--row', 'publish-offer', '--source', 's', '--decisions', decisions], stubEnv), 2, null, /stars 0 options/);
  expect('an unknown row is wiring', run(['preanswer', '--effort', 'e', '--row', 'nope', '--source', 's', '--decisions', decisions], stubEnv), 2, null, /not in/);
  expect('a nen refusal passes through', run(['preanswer', '--effort', 'e', '--row', 'wrap-up', '--source', 's', '--decisions', decisions], { ...stubEnv, STUB_EXIT: '2' }), 2);

  // Live: the real nen records, the script exports, renders and checks.
  const nen = process.env.NEN || 'nen';
  const repo = join(scratch, 'live');
  mkdirSync(repo);
  assert.equal(spawnSync('git', ['init', '-q', repo]).status, 0);
  const q = join(repo, 'q.md');
  writeFileSync(q, 'Pick one?\n');
  const typedFile = join(repo, 't.txt');
  writeFileSync(typedFile, 'Neither: ask me again\n');
  const rec = (extra: string[], opts = ['--option', 'A=Go (Recommended)::it lands', '--option', 'B=Hold::nothing lands']): string => {
    const r = spawnSync(nen, ['stop', 'answer', '--record', 'opus/kurapika/live', '--gate', 'G4', '--who', 'kurapika', '--question-file', q,
      ...opts, ...extra, '--repo', repo, '--json'], { encoding: 'utf8' });
    assert.equal(r.status, 0, `nen stop answer: ${r.stderr}`);
    return (JSON.parse(r.stdout) as { record: { id: string } }).record.id;
  };
  const pickedId = rec(['--pick', 'A']);
  const typedId = rec(['--typed-file', typedFile]);
  const designId = rec(['--typed-file', typedFile], ['--option', 'ref=typed by design (no option)::the typed words are the answer']);
  const liveDocs = join(repo, 'docs');
  const ids = [pickedId, typedId, designId];
  for (const id of ids) {
    const r = run(['export', '--effort', 'opus/kurapika/live', '--id', id, '--repo', repo, '--out', join(liveDocs, 'ruling-records'), '--names-file', names]);
    assert.equal(r.status, 0, r.stdout + r.stderr);
  }
  const liveRows = ids.map((id, i) => renderRow(join(liveDocs, 'ruling-records', `opus-kurapika-live--${id}.json`), `HR-${901 + i}`));
  assert.match(liveRows[1] ?? '', /typed \(verbatim\): \*"Neither: ask me again"\*/);
  assert.match(liveRows[2] ?? '', /\| none: typed by design \| typed \(verbatim\)/);
  expect('live: nen records (a typed-by-design row included), the rows render and check against their records', run(['check', '--roster', roster(liveDocs, liveRows)]), 0, /3 ROSTER rows match/);

  {
    // The REAL nen resolves against this checkout's nen/repos.json: the render path the live roster uses.
    const r = run(['render', '--record', recordFile(join(scratch, 'live-refs'), { ...base, id: 'R-2026-10-23-14', question: 'hatsu #5, issue #6?' }), '--hr', 'HR-343', '--status', 'ruled', '--settles', 'x', '--names-file', privList]);
    expect('live: nen repo resolve codes a registry repository and leaves an unknown word', r, 0, /\| zheref\/hatsu#5, issue #6\? \|/);
  }
  const live = fileURLToPath(new URL('../docs/ROSTER.md', import.meta.url));
  expect('the live roster matches every record it cites', run(['check', '--roster', live]), 0, /ruling-record: /);
  console.log(`ruling-record fixture: ${cases} cases passed`);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
