#!/usr/bin/env node
// zheref/hatsu#505: hermetic fixture for scripts/constitution_check.mts. Each case writes a throwaway
// Hatsu-shaped root (docs/ROSTER.md, claude/skills/<name>/) and a request, then asserts the script's
// exit, its read set and its record line, in-process and through the CLI entry alike. Its last case
// reads the live roster.
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { check, main } from './constitution_check.mts';

const script = fileURLToPath(new URL('./constitution_check.mts', import.meta.url));
const live = fileURLToPath(new URL('..', import.meta.url));
const READINGS = ['', '## Readings', '', '| HR id | Date | What it reads |', '|---|---|---|'];
const def = (n: number, status: string, words = 'a ruling'): string => `| <a id="hr-${n}"></a>**HR-${n}** (${status}) ${words} | settles |`;
const entry = (n: number): string => `| [HR-${n}](#hr-${n}) | 2026-10-26 | a reading |`;

export function runConstitutionCheckFixture(): void {
  const scratch = mkdtempSync(join(tmpdir(), 'hatsu-constitution-check-'));
  let cases = 0;
  const root = (name: string, rows: string[], readings: number[] = [], skills = ['breath', 'ren', 'en']): string => {
    const dir = join(scratch, name);
    mkdirSync(join(dir, 'docs'), { recursive: true });
    for (const skill of skills) mkdirSync(join(dir, 'claude', 'skills', skill), { recursive: true });
    writeFileSync(join(dir, 'docs', 'ROSTER.md'), ['# Roster', '', '| HR | What | Settles |', '|---|---|---|', ...rows, ...READINGS, ...readings.map(entry), ''].join('\n'));
    return dir;
  };
  const request = (name: string, text: string): string => {
    const path = join(scratch, `${name}.request.md`);
    writeFileSync(path, text);
    return path;
  };
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

  try {
    const base = root('base', [
      def(1, 'ruled'),
      def(2, 'reading', 'a reading row naming `breath`'),
      def(3, 'superseded by HR-4 (its first half; the rest stands)'),
      def(4, 'ruled'),
      def(5, 'reversed by HR-6'),
      def(6, 'ruled'),
      def(7, 'ruled', 'a ruling on [`breath`](../claude/skills/breath/)'),
      def(8, 'ruled', 'a ruling on `breathe`, a different word'),
      def(20, 'ruled'),
    ], [2]);

    // A ruled row cited binds whole; HR-2 never matches HR-20.
    let verdict = check({ request: request('ruled', 'Leans on HR-1 and on HR-20.'), root: base, constitution: null });
    assert.deepEqual(verdict.read, ['HR-1', 'HR-20']);
    assert.equal(verdict.exit, 0);
    cases += 1;

    // A reading cited is listed and never binds (HR-337).
    verdict = check({ request: request('reading', 'Cites HR-2.'), root: base, constitution: null });
    assert.deepEqual(verdict.read, []);
    assert.equal(verdict.clauses[0]?.binding, 'none');
    assert.match(verdict.record, /not-binding=HR-2;/);
    cases += 1;

    // A partly displaced row binds its rest and is followed to the displacing row.
    verdict = check({ request: request('part', 'Implements HR-3.'), root: base, constitution: null });
    assert.deepEqual(verdict.read, ['HR-3(part)', 'HR-4']);
    assert.deepEqual(verdict.clauses.find((c) => c.id === 'HR-4')?.via, ['follows HR-3']);
    cases += 1;

    // A wholly reversed row binds nothing; its reversing row is read instead.
    verdict = check({ request: request('reversed', 'Per HR-5.'), root: base, constitution: null });
    assert.deepEqual(verdict.read, ['HR-6']);
    assert.match(verdict.record, /not-binding=HR-5;/);
    cases += 1;

    // A skill the request names selects the binding rows that name it; a reading row and a longer
    // word are not selected, and a skill name inside a longer one is not a mention.
    verdict = check({ request: request('touched', 'Change `breath` so it checks more. Not `breathe`.'), root: base, constitution: null });
    assert.deepEqual(verdict.skills, ['breath']);
    assert.deepEqual(verdict.read, ['HR-7']);
    assert.deepEqual(verdict.clauses.find((c) => c.id === 'HR-7')?.via, ['touched breath']);
    verdict = check({ request: request('hatsu-form', 'Run hatsu:ren then hatsu:en-like.'), root: base, constitution: null });
    assert.deepEqual(verdict.skills, ['ren']);
    cases += 2;

    // The record line is the breath note's shape.
    run(['--request', request('record', 'HR-1, HR-3 and HR-2.'), '--root', base], 0,
      /record: constitution-check: read=HR-1,HR-3\(part\),HR-4; not-binding=HR-2; dangling=none/);

    // A cited id no row defines is a finding, exit 1.
    run(['--request', request('dangling', 'Cites HR-1 and HR-99.'), '--root', base], 1, /dangling HR-99 · cited/);

    // --json carries the contract and the same verdict.
    const json = JSON.parse(run(['--request', request('json', 'HR-1'), '--root', base, '--json'], 0)) as { contract: string; read: string[]; exit: number };
    assert.equal(json.contract, 'hatsu.constitution-check/v0.1');
    assert.deepEqual(json.read, ['HR-1']);

    // A CON id: no --constitution is wiring (never read from memory), a defined one binds whole,
    // an undefined one dangles, and a file with no CON clause is refused.
    const conRequest = request('con', 'Bound by CON-5 and CON-47.');
    run(['--request', conRequest, '--root', base], 2, /cites CON-5, CON-47 and no --constitution/);
    const constitution = join(scratch, 'CONSTITUTION.md');
    writeFileSync(constitution, '# Constitution\n\n- **CON-5.** **G2 — merge.** Only the human merges.\n- **CON-47.** **G5.**\n');
    verdict = check({ request: conRequest, root: base, constitution });
    assert.deepEqual(verdict.read, ['CON-5', 'CON-47']);
    run(['--request', request('con-dangling', 'CON-9'), '--root', base, '--constitution', constitution], 1, /dangling CON-9/);
    const empty = join(scratch, 'EMPTY.md');
    writeFileSync(empty, '# nothing here\n');
    run(['--request', conRequest, '--root', base, '--constitution', empty], 2, /defines no CON clause/);

    // Wiring: usage, an unreadable request, a directory, a roster the clause guard refuses, no skills dir.
    run([], 2, /--request is required/);
    run(['--request'], 2, /valueless argument '--request'/);
    run(['--bogus', 'x'], 2, /unknown or valueless argument '--bogus'/);
    run(['--request', join(scratch, 'absent.md'), '--root', base], 2, /cannot read the request/);
    run(['--request', scratch, '--root', base], 2, /not a regular file/);
    const broken = root('broken', [def(1, 'ruled'), def(1, 'ruled')]);
    run(['--request', request('broken', 'HR-1'), '--root', broken], 2, /the clause guard refuses it/);
    const badStatus = root('bad-status', [def(1, 'pending')]);
    run(['--request', request('bad-status', 'HR-1'), '--root', badStatus], 2, /the clause guard refuses it/);
    const noSkills = join(scratch, 'no-skills');
    mkdirSync(join(noSkills, 'docs'), { recursive: true });
    writeFileSync(join(noSkills, 'docs', 'ROSTER.md'), ['| x | y |', '|---|---|', def(1, 'ruled'), ...READINGS, ''].join('\n'));
    run(['--request', request('no-skills', 'HR-1'), '--root', noSkills], 2, /not a Hatsu checkout/);

    // Live: HR-10 is partly superseded by HR-337, so a request citing it reads both (zheref/hatsu#505).
    verdict = check({ request: request('live', 'Implements HR-10 for `breath`.'), root: live, constitution: null });
    assert.ok(verdict.read.includes('HR-10(part)'), `live roster: HR-10 not read in part (${verdict.record})`);
    assert.ok(verdict.read.includes('HR-337'), `live roster: HR-337 not followed (${verdict.record})`);
    assert.ok(verdict.skills.includes('breath'));
    cases += 1;

    console.log(`constitution-check-fixture: ${cases} cases pass`);
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
}

const invoked = process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1];
if (invoked) runConstitutionCheckFixture();
