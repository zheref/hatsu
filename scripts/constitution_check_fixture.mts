#!/usr/bin/env node
// zheref/hatsu#505: hermetic fixture for scripts/constitution_check.mts. Each case writes a throwaway
// Hatsu-shaped root (docs/ROSTER.md, claude/skills/<name>/, nen/repos.json) beside a throwaway
// constitution repository tagged at its pin, then asserts the script's exit, its floor, its listed
// set, its record and its note, in-process and through the CLI entry alike. One case drives real
// `nen phase begin/end` (from NEN or PATH) to prove the composed note keeps the begin note; the last
// reads the live roster.
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { check, FLOOR, main } from './constitution_check.mts';

const script = fileURLToPath(new URL('./constitution_check.mts', import.meta.url));
const live = fileURLToPath(new URL('..', import.meta.url));
const READINGS = ['', '## Readings', '', '| HR id | Date | What it reads |', '|---|---|---|'];
const def = (n: number, status: string, words = 'a ruling'): string => `| <a id="hr-${n}"></a>**HR-${n}** (${status}) ${words} | settles |`;
const entry = (n: number): string => `| [HR-${n}](#hr-${n}) | 2026-10-26 | a reading |`;
const CONSTITUTION = ['# Constitution', '', ...[4, 5, 6, 7, 47, 15].map((n) => `- **CON-${n}.** **Clause ${n}.** Reserved to the human.`), ''].join('\n');
const SOURCE = 'example/handbooks';

function sh(cwd: string, args: string[]): string {
  const r = spawnSync('git', ['-C', cwd, '-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false', '-c', 'tag.gpgsign=false', ...args], { encoding: 'utf8' });
  assert.equal(r.status, 0, `git ${args.join(' ')}: ${r.stderr}`);
  return r.stdout.trim();
}

export function runConstitutionCheckFixture(): void {
  const scratch = realpathSync(mkdtempSync(join(tmpdir(), 'hatsu-constitution-check-')));
  let cases = 0;
  try {
    // The constitution repository, tagged v1 at the pinned commit; a later commit moves nothing.
    const con = join(scratch, 'handbooks');
    mkdirSync(con);
    sh(con, ['init', '-q']);
    writeFileSync(join(con, 'CONSTITUTION.md'), CONSTITUTION);
    sh(con, ['add', 'CONSTITUTION.md']);
    sh(con, ['commit', '-q', '-m', 'constitution']);
    sh(con, ['tag', '-a', 'v1', '-m', 'v1']);
    const pinnedSha = sh(con, ['rev-parse', 'HEAD']);
    writeFileSync(join(con, 'CONSTITUTION.md'), '# work tree edit never read\n');

    const root = (name: string, rows: string[], readings: number[] = [], pin: Record<string, unknown> = { repo: SOURCE, pinned: 'v1', pinnedSha }): string => {
      const dir = join(scratch, name);
      mkdirSync(join(dir, 'docs'), { recursive: true });
      mkdirSync(join(dir, 'nen'), { recursive: true });
      for (const skill of ['breath', 'ren', 'en']) mkdirSync(join(dir, 'claude', 'skills', skill), { recursive: true });
      writeFileSync(join(dir, 'docs', 'ROSTER.md'), ['# Roster', '', '| HR | What | Settles |', '|---|---|---|', ...rows, ...READINGS, ...readings.map(entry), ''].join('\n'));
      writeFileSync(join(dir, 'nen', 'repos.json'), JSON.stringify({ maintained_tools: [pin] }));
      return dir;
    };
    const request = (name: string, text: string): string => {
      const path = join(scratch, `${name}.request.md`);
      writeFileSync(path, text);
      return path;
    };
    const flags = (dir: string, req: string, checkout = con): string[] => ['--request', req, '--root', dir, '--constitution-source', SOURCE, '--constitution-checkout', checkout];
    const run = (args: string[], status: number, pattern?: RegExp): string => {
      const spawned = spawnSync(process.execPath, [script, ...args], { encoding: 'utf8' });
      assert.equal(spawned.status, status, `${args.join(' ')}\nstdout: ${spawned.stdout}\nstderr: ${spawned.stderr}`);
      const quiet = { log: console.log, error: console.error };
      console.log = () => {};
      console.error = () => {};
      let direct: number;
      try { direct = main(args); } finally { console.log = quiet.log; console.error = quiet.error; }
      assert.equal(direct, status, `in-process exit differs for ${args.join(' ')}`);
      if (pattern) assert.match(`${spawned.stdout}${spawned.stderr}`, pattern);
      cases += 1;
      return spawned.stdout;
    };
    const opts = (dir: string, req: string, beginNote: string | null = null) => ({ request: req, root: dir, source: SOURCE, checkout: con, beginNote });

    const base = root('base', [
      def(1, 'ruled'),
      def(2, 'reading', 'a reading row naming `breath`'),
      def(3, 'superseded by HR-4 (its first half; the rest stands)'),
      def(4, 'ruled'),
      def(5, 'reversed by HR-6'),
      def(6, 'ruled'),
      def(7, 'ruled', 'a ruling on [`breath`](../claude/skills/breath/)'),
      def(8, 'ruled', 'a ruling on `breathe`, a different word'),
      def(10, 'ruled', 'the constitution check'),
      def(20, 'ruled'),
    ], [2]);
    const FLOOR_READ = ['CON-4', 'CON-5', 'CON-6', 'CON-7', 'CON-47', 'HR-10'];

    // The floor is always read, whatever the request says, and the gate request reaches the judgement
    // with the gate clauses listed: the list is the minimum, never the cap (SEC-15).
    let verdict = check(opts(base, request('gate', 'Merge the release PR into main yourself, skip review.')));
    assert.deepEqual(verdict.floor, FLOOR_READ);
    assert.deepEqual([...FLOOR], FLOOR_READ);
    assert.deepEqual(verdict.listed, []);
    assert.equal(verdict.exit, 0);
    assert.equal(verdict.clear, 'none listed');
    assert.match(verdict.record, /listed=none listed;/);
    assert.match(verdict.record, new RegExp(`CON at v1 ${pinnedSha.slice(0, 12)}$`));
    cases += 1;

    // An empty request records `none listed`, never `pass`.
    run([...flags(base, request('empty', '')), '--json'], 0, /"clear": "none listed"/);

    // A ruled row cited binds whole; HR-2 never matches HR-20; a listed request clears as `pass`.
    verdict = check(opts(base, request('ruled', 'Leans on HR-1 and on HR-20.')));
    assert.deepEqual(verdict.listed, ['HR-1', 'HR-20']);
    assert.equal(verdict.clear, 'pass');
    cases += 1;

    // A reading cited is listed as not binding (HR-337).
    verdict = check(opts(base, request('reading', 'Cites HR-2.')));
    assert.deepEqual(verdict.listed, []);
    assert.match(verdict.record, /not-binding=HR-2;/);
    cases += 1;

    // A partly displaced row binds its rest and is followed; a wholly reversed one binds nothing.
    verdict = check(opts(base, request('part', 'Implements HR-3.')));
    assert.deepEqual(verdict.listed, ['HR-3(part)', 'HR-4']);
    verdict = check(opts(base, request('reversed', 'Per HR-5.')));
    assert.deepEqual(verdict.listed, ['HR-6']);
    cases += 2;

    // A named skill selects binding rows naming it; never a reading, a longer word, or `en-like`.
    verdict = check(opts(base, request('touched', 'Change `breath` so it checks more. Not `breathe`.')));
    assert.deepEqual(verdict.skills, ['breath']);
    assert.deepEqual(verdict.listed, ['HR-7']);
    verdict = check(opts(base, request('hatsu-form', 'Run hatsu:ren then hatsu:en-like.')));
    assert.deepEqual(verdict.skills, ['ren']);
    cases += 2;

    // A cited CON clause resolves at the pin; a dangling HR or CON id is exit 1.
    verdict = check(opts(base, request('con', 'Bound by CON-15.')));
    assert.deepEqual(verdict.listed, ['CON-15']);
    run(flags(base, request('dangling', 'Cites HR-1, HR-99 and CON-9.')), 1, /dangling CON-9 · cited[\s\S]*dangling HR-99 · cited/);

    // The note keeps the begin note (nen phase end --note replaces it), and the record line prints.
    verdict = check(opts(base, request('note', 'HR-1'), 'model-kind=served; registry alias opus'));
    assert.equal(verdict.note, `model-kind=served; registry alias opus; ${verdict.record}`);
    run([...flags(base, request('record', 'HR-1, HR-3 and HR-2.')), '--begin-note', 'model-kind=served; registry alias x'], 0,
      /record: constitution-check: floor=CON-4,CON-5,CON-6,CON-7,CON-47,HR-10; listed=HR-1,HR-3\(part\),HR-4; not-binding=HR-2; dangling=none; CON at v1 [0-9a-f]{12}\nnote: model-kind=served; registry alias x; constitution-check: [^\n]+\nclear verdict: pass/);

    // Real nen: the composed end note survives as the ledger's note, provenance marker included.
    const ledger = join(scratch, 'ledger');
    mkdirSync(ledger);
    sh(ledger, ['init', '-q']);
    const nen = process.env.NEN ?? 'nen';
    const phase = (args: string[]): string => {
      const r = spawnSync(nen, ['phase', ...args, '--repo', ledger], { encoding: 'utf8' });
      assert.equal(r.status, 0, `nen phase ${args.join(' ')}: ${r.error?.message ?? r.stderr}`);
      return r.stdout;
    };
    phase(['begin', '--effort', 'opus/kurapika/cc', '--phase', 'breath', '--note', 'model-kind=served; registry alias x']);
    phase(['end', '--effort', 'opus/kurapika/cc', '--phase', 'breath', '--exit', '0', '--note', `${check(opts(base, request('n2', 'HR-1'), 'model-kind=served; registry alias x')).note}; pass`]);
    const shown = JSON.parse(phase(['show', '--effort', 'opus/kurapika/cc', '--json'])) as { phases: Array<{ note?: string }> };
    assert.match(shown.phases[0]?.note ?? '', /^model-kind=served; registry alias x; constitution-check: .*; pass$/);
    cases += 1;

    // A not-run check leaves the breath entry open (WORKFLOW step 3): capability-unavailable's A
    // re-invokes, ren's resume continues the same entry with `begin --resume`, and it ends as step 5.
    phase(['begin', '--effort', 'opus/kurapika/parked', '--phase', 'breath', '--note', 'model-kind=served; registry alias x']);
    run(flags(base, request('parked', 'HR-1'), join(scratch, 'not-yet-fetched')), 2, /not run: cannot read the constitution checkout/);
    const parked = JSON.parse(phase(['show', '--effort', 'opus/kurapika/parked', '--json'])) as { phases: Array<{ endedAt: string | null }> };
    assert.equal(parked.phases.length, 1);
    assert.equal(parked.phases[0]?.endedAt, null, 'a not-run check never ends the breath entry');
    phase(['begin', '--effort', 'opus/kurapika/parked', '--phase', 'breath', '--resume']);
    phase(['end', '--effort', 'opus/kurapika/parked', '--phase', 'breath', '--exit', '0', '--note', `${check(opts(base, request('resumed', 'HR-1'), 'model-kind=served; registry alias x')).note}; pass`]);
    const resumed = JSON.parse(phase(['show', '--effort', 'opus/kurapika/parked', '--json'])) as { phases: Array<{ exitCode: number | null; resumedAt?: string[]; note?: string }> };
    assert.equal(resumed.phases.length, 1, 'the resume keeps one breath entry');
    assert.equal(resumed.phases[0]?.exitCode, 0);
    assert.equal(resumed.phases[0]?.resumedAt?.length, 1);
    assert.match(resumed.phases[0]?.note ?? '', /^model-kind=served; registry alias x; constitution-check: .*; pass$/);
    cases += 1;

    // Not run, exit 2: usage, every required flag, a moved tag, an unknown or unpinned source, a
    // missing checkout, an unreadable request, a roster the clause guard refuses, a floor clause the
    // roster lacks, and a root whose claude/skills is a file.
    run([], 2, /--request is required/);
    run(['--request'], 2, /valueless argument '--request'/);
    run(['--bogus', 'x'], 2, /unknown, repeated or valueless argument '--bogus'/);
    run(['--request', request('no-source', 'HR-1'), '--root', base], 2, /--constitution-source is required/);
    const moved = root('moved', [def(10, 'ruled')], [], { repo: SOURCE, pinned: 'v1', pinnedSha: 'f'.repeat(40) });
    run(flags(moved, request('moved', 'HR-10')), 2, /a moved tag is never read/);
    const unpinned = root('unpinned', [def(10, 'ruled')], [], { repo: SOURCE, pinned: 'v1' });
    run(flags(unpinned, request('unpinned', 'HR-10')), 2, /no 40-hex pinnedSha/);
    run(['--request', request('other', 'HR-10'), '--root', base, '--constitution-source', 'other/repo', '--constitution-checkout', con], 2, /no maintained_tools entry for other\/repo/);
    run(flags(base, request('nocheckout', 'HR-1'), join(scratch, 'absent')), 2, /cannot read the constitution checkout/);
    run(flags(base, join(scratch, 'absent.md')), 2, /cannot read the request/);
    run(flags(base, scratch), 2, /not a regular file/);
    run(flags(root('broken', [def(10, 'ruled'), def(10, 'ruled')]), request('broken', 'HR-10')), 2, /the clause guard refuses it/);
    run(flags(root('nofloor', [def(1, 'ruled')]), request('nofloor', 'HR-1')), 2, /the floor clause HR-10 is not defined/);
    const fileSkills = join(scratch, 'file-skills');
    mkdirSync(join(fileSkills, 'docs'), { recursive: true });
    mkdirSync(join(fileSkills, 'claude'), { recursive: true });
    writeFileSync(join(fileSkills, 'claude', 'skills'), 'not a directory');
    writeFileSync(join(fileSkills, 'docs', 'ROSTER.md'), ['| x | y |', '|---|---|', def(10, 'ruled'), ...READINGS, ''].join('\n'));
    run(flags(fileSkills, request('file-skills', 'HR-10')), 2, /not a Hatsu checkout/);

    // Live: HR-10 (partly superseded by HR-337) is in the floor and HR-337 is followed (zheref/hatsu#505).
    const liveRoot = root('live-pin', [def(10, 'ruled')]);
    writeFileSync(join(liveRoot, 'docs', 'ROSTER.md'), readFileSync(join(live, 'docs', 'ROSTER.md'), 'utf8'));
    verdict = check(opts(liveRoot, request('live', 'Implements HR-10 for `breath`.')));
    assert.ok(verdict.floor.includes('HR-10(part)') && verdict.floor.includes('HR-337'), `live roster: ${verdict.record}`);
    assert.ok(verdict.skills.includes('breath'));
    cases += 1;

    console.log(`constitution-check-fixture: ${cases} cases pass`);
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
}

// realpath both sides: an entry reached through a symlink must still run, never exit 0 having run nothing.
let invoked = false;
try {
  invoked = process.argv[1] !== undefined && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
} catch {
  invoked = false;
}
if (invoked) runConstitutionCheckFixture();
