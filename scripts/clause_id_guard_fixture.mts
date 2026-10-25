#!/usr/bin/env node
// HR-2: hermetic fixture for scripts/clause_id_guard.mts. Each case writes a
// throwaway roster and asserts the guard's exit code and stream split.
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { main as guardMain } from './clause_id_guard.mts';

export function runClauseIdGuardFixture(): void {
const guard = fileURLToPath(new URL('./clause_id_guard.mts', import.meta.url));
const scratch = mkdtempSync(join(tmpdir(), 'hatsu-clause-id-'));
const def = (n: number | string, label: number | string = n, status = 'ruled'): string => `| <a id="hr-${n}"></a>**HR-${label}** (${status}) a ruling | settles |`;
// Every synthetic roster ends in a § Readings index; `index` lists its entries.
const READINGS = ['', '## Readings — every reading-status clause, indexed', '', '| HR id | Date | What it reads |', '|---|---|---|'];
const entry = (n: number): string => `| [HR-${n}](#hr-${n}) | 2026-10-23 | a reading |`;
const STATUS_TABLE = ['| HR id | Question as asked | Status | What it settles |', '|---|---|---|---|'];
const row = (n: number, status: string): string => `| <a id="hr-${n}"></a>**HR-${n}** | a question | ${status} | settles |`;
let cases = 0;

function run(args: string[]): ReturnType<typeof spawnSync> {
  const stdout: string[] = [];
  const stderr: string[] = [];
  const originalLog = console.log;
  const originalError = console.error;
  console.log = (...values: unknown[]) => stdout.push(values.map(String).join(' '));
  console.error = (...values: unknown[]) => stderr.push(values.map(String).join(' '));
  let status: number;
  try {
    status = guardMain(args);
  } finally {
    console.log = originalLog;
    console.error = originalError;
  }
  // Retain every pre-existing CLI case as an executable-boundary assertion.
  const spawned = spawnSync(process.execPath, [guard, ...args], { cwd: scratch, encoding: 'utf8' });
  const detail = `direct/CLI mismatch for ${args.join(' ')}\ndirect stdout: ${stdout.join('\n')}\ndirect stderr: ${stderr.join('\n')}\nCLI stdout: ${spawned.stdout}\nCLI stderr: ${spawned.stderr}`;
  assert.equal(spawned.status, status, detail);
  assert.equal(String(spawned.stdout).trimEnd(), stdout.join('\n'), detail);
  assert.equal(String(spawned.stderr).trimEnd(), stderr.join('\n'), detail);
  return spawned;
}
function roster(name: string, lines: string[], index: (number | string)[] = [], readings = true): string {
  const path = join(scratch, `${name}.md`);
  writeFileSync(path, `${[...lines, ...(readings ? [...READINGS, ...index.map((e) => (typeof e === 'number' ? entry(e) : e))] : [])].join('\n')}\n`);
  return path;
}
function expect(name: string, args: string[], status: number, stdout: RegExp | null, stderr: RegExp | null): void {
  const result = run(args);
  const detail = `${name}: exit ${result.status}\nstdout: ${result.stdout}\nstderr: ${result.stderr}`;
  assert.equal(result.status, status, detail);
  if (stdout) assert.match(String(result.stdout), stdout, detail);
  if (stderr) assert.match(String(result.stderr), stderr, detail);
  if (status !== 2) assert.equal(String(result.stderr), '', `${name}: findings go to stdout only\n${detail}`);
  if (status === 2) assert.equal(String(result.stdout), '', `${name}: a tooling failure prints no annotation\n${detail}`);
  cases += 1;
  console.log(`ok ${cases} - ${name}`);
}

try {
  expect('unique ids pass', [roster('clean', [def(1), def(2), def(3)])], 0, /3 HR definitions, unique/, null);
  expect('citations are never counted', [roster('cites', [def(1), def(2), 'See [HR-1](#hr-1) and HR-2; status (reversed by HR-1).', '| x | superseded by HR-2 |'])], 0, /2 HR definitions, unique/, null);
  expect('a duplicate id exits 1', [roster('dup', [def(1), def(2), def(2)])], 1, /::error file=.*::HR-2 is anchored 2 times/, null);
  expect('HR-2 never matches HR-20', [roster('twenty', [def(1), def(2), ...Array.from({ length: 18 }, (_, i) => def(i + 3))])], 0, /20 HR definitions, unique/, null);
  const twentyTwice = run([roster('twenty-dup', [def(2), def(20), def(20)])]);
  assert.equal(twentyTwice.status, 1, String(twentyTwice.stdout));
  assert.match(String(twentyTwice.stdout), /HR-20 is anchored 2 times/);
  assert.doesNotMatch(String(twentyTwice.stdout), /HR-2 is anchored/, 'HR-2 is not HR-20');
  cases += 1;
  console.log(`ok ${cases} - a duplicated HR-20 never reports HR-2`);
  expect('two anchors on one line both count', [roster('inline', [`${def(1)} <a id="hr-1"></a>**HR-1** (reading)`])], 1, /HR-1 is anchored 2 times/, null);
  expect('an anchor and label that disagree exit 1', [roster('mismatch', [def(1), def(2, 3)])], 1, /::error file=.*,line=2::anchor hr-2 labels HR-3/, null);
  expect('a gap is a notice, exit 0', [roster('gap', [def(1), def(2), def(5)])], 0, /::notice file=.*::HR id gaps \(reported, never failed\): HR-3, HR-4$/m, null);
  expect('a long gap lists 20 and counts the rest', [roster('long-gap', [def(1), def(100)])], 0, /::notice file=.*::HR id gaps \(reported, never failed\): HR-2, .*HR-21, and 78 more$/m, null);
  expect('order is not asserted', [roster('order', [def(3), def(1), def(2)])], 0, /3 HR definitions, unique/, null);
  expect('a spaced label is a non-canonical anchor', [roster('spaced', [def(1), '| <a id="hr-2"></a> **HR-2** | a ruling | ruled |'])], 1, /::error file=.*,line=2,col=\d+::an HR anchor not in the canonical form/, null);
  expect('an upper-case anchor is non-canonical', [roster('upper', [def(1), '| <a id="HR-2"></a>**HR-2** | a ruling | ruled |'])], 1, /::error file=.*,line=2,col=\d+::an HR anchor not in the canonical form/, null);
  expect('a single-quoted anchor is non-canonical', [roster('quoted', [def(1), "| <a id='hr-2'></a>**HR-2** | a ruling | ruled |"])], 1, /an HR anchor not in the canonical form/, null);
  const bare = run([roster('bare-dup', [def(1), '<a id="hr-1"></a> a second, unlabelled anchor'])]);
  assert.equal(bare.status, 1, String(bare.stdout));
  assert.match(String(bare.stdout), /HR-1 is anchored 2 times/);
  assert.match(String(bare.stdout), /line=2,col=\d+::an HR anchor not in the canonical form/);
  assert.equal(String(bare.stderr), '');
  cases += 1;
  console.log(`ok ${cases} - a bare second anchor is a duplicate and non-canonical`);
  expect('an id far above the count exits 2', [roster('huge', [def(1), def(50000000)])], 2, null, /HR-50000000 exceeds the definition count plus 1000/);
  expect('an id that is not a safe integer exits 2', [roster('digits', [def(1), def('9'.repeat(400))])], 2, null, /is not a safe integer/);
  expect('a path with a comma exits 2', [roster('a,line=1', [def(1)])], 2, null, /comma, colon or line break/);
  expect('a path with a colon exits 2', [join(scratch, 'x::y.md')], 2, null, /comma, colon or line break/);
  expect('a path with a newline exits 2', [join(scratch, 'x\n::error::forged.md')], 2, null, /comma, colon or line break/);
  expect('an unreadable file exits 2', [join(scratch, 'absent.md')], 2, null, /cannot read/);
  const dir = join(scratch, 'a-directory');
  mkdirSync(dir);
  expect('a directory exits 2', [dir], 2, null, /cannot read/);
  expect('wrong arity exits 2', ['one.md', 'two.md'], 2, null, /usage/);
  expect('no definitions exits 2, never clean', [roster('empty', ['# nothing here', 'HR-1 cited only'])], 2, null, /no HR definitions/);
  // zheref/hatsu#452 AC-1: the status word.
  expect('a Status column and a parenthesised status both read', [roster('status-ok', [...STATUS_TABLE, row(1, 'ruled'), row(2, 'reversed by HR-1 (the option; the rest stands)'), '', def(3, 3, 'superseded by HR-1, HR-2 (the key (its name); the rest stands)'), `<a id="hr-4"></a>**HR-4** (reading) a paragraph reading`], [4])], 0, /4 HR definitions, unique, each with an admitted status/, null);
  expect('a misspelled status word exits 1 naming the row and the word', [roster('status-typo', [def(1), def(2, 2, 'ruling')])], 1, /::error file=.*,line=2::HR-2 has "ruling", not an admitted status/, null);
  expect('a bad Status cell exits 1 naming the row and the word', [roster('status-cell', [...STATUS_TABLE, row(1, 'ruled'), row(2, 'Ruled')])], 1, /::error file=.*,line=4::HR-2 has "Ruled", not an admitted status/, null);
  expect('a definition with no status exits 1', [roster('status-none', [def(1), '<a id="hr-2"></a>**HR-2** a paragraph with no status'])], 1, /::error file=.*,line=2::HR-2 has no status, not an admitted status/, null);
  expect('reversed by with no target id exits 1', [roster('status-bare', [def(1), def(2, 2, 'reversed by the next sitting')])], 1, /HR-2 has "reversed by the next sitting", not an admitted status/, null);
  expect('text after the part parenthesis exits 1', [roster('status-trailing', [def(1), def(2, 2, 'reversed by HR-1 (x) then anything (y)')])], 1, /HR-2 has "reversed by HR-1 \(x\) then anything \(y\)", not an admitted status/, null);
  expect('an empty part parenthesis exits 1', [roster('status-empty-part', [def(1), def(2, 2, 'superseded by HR-1 ( )')])], 1, /HR-2 has "superseded by HR-1 \( \)", not an admitted status/, null);
  expect('a Status cell and a parenthesis that differ exit 1 naming the row', [roster('status-two', [...STATUS_TABLE, row(1, 'ruled'), '| <a id="hr-2"></a>**HR-2** (bogus) | a question | ruled | settles |'])], 1, /::error file=.*,line=4::HR-2 carries two statuses: its Status cell "ruled" and its parenthesis "bogus"/, null);
  expect('a Status cell and a parenthesis that agree pass', [roster('status-agree', [...STATUS_TABLE, row(1, 'ruled'), '| <a id="hr-2"></a>**HR-2** (ruled) | a question | ruled | settles |'])], 0, /2 HR definitions/, null);
  // AC-2: a citation whose target no row defines.
  expect('a bare citation of an undefined id exits 1 naming the line and the id', [roster('dangle-bare', [def(1), def(2), 'Prose citing HR-999 and HR-2.'])], 1, /::error file=.*,line=3::line 3 cites HR-999, which no row defines/, null);
  expect('a link target of an undefined id exits 1', [roster('dangle-link', [def(1), 'See [the ruling](#hr-77).'])], 1, /::error file=.*,line=2::line 2 cites HR-77, which no row defines/, null);
  expect('a reversed-by target no row defines exits 1', [roster('dangle-status', [def(1), def(2, 2, 'reversed by HR-9')])], 1, /::error file=.*,line=2::line 2 cites HR-9, which no row defines/, null);
  const linked = run([roster('dangle-once', [def(1), 'See [HR-7](#hr-7).'])]);
  assert.equal(linked.status, 1, String(linked.stdout));
  assert.equal((String(linked.stdout).match(/cites HR-7, which no row defines/g) ?? []).length, 1, `a linked citation reports once\n${String(linked.stdout)}`);
  cases += 1;
  console.log(`ok ${cases} - a dangling [HR-N](#hr-N) link is reported once per line`);
  const twentyDangle = run([roster('dangle-twenty', [def(2), 'cites HR-20'])]);
  assert.equal(twentyDangle.status, 1, String(twentyDangle.stdout));
  assert.match(String(twentyDangle.stdout), /cites HR-20, which no row defines/);
  assert.doesNotMatch(String(twentyDangle.stdout), /cites HR-2,/, 'HR-2 is defined and is not HR-20');
  cases += 1;
  console.log(`ok ${cases} - a dangling HR-20 is never read as HR-2`);
  // AC-3: the § Readings index against the statuses.
  expect('a reading absent from the index exits 1 naming the row', [roster('index-missing', [def(1), def(2, 2, 'reading')])], 1, /::error file=.*,line=2::HR-2 is a reading with no entry in § Readings' index/, null);
  expect('an index entry whose row is ruled exits 1 naming the row', [roster('index-ruled', [def(1), def(2, 2, 'reading')], [1, 2])], 1, /::error file=.*,line=\d+::§ Readings' index lists HR-1, whose row is not a reading \(ruled\)/, null);
  expect('a reversed reading still in the index exits 1', [roster('index-reversed', [def(1), def(2, 2, 'reversed by HR-1')], [2])], 1, /index lists HR-2, whose row is not a reading \(reversed by HR-1\)/, null);
  expect('an index entry no row defines exits 1', [roster('index-undefined', [def(1)], [5])], 1, /index lists HR-5, whose row is not a reading \(not defined\)/, null);
  expect('an index entry whose label and link disagree exits 1 naming the line', [roster('index-label', [def(1), def(2, 2, 'reading')], ['| [HR-2](#hr-1) | 2026-10-23 | a reading |'])], 1, /::error file=.*,line=8::§ Readings' index entry on line 8 labels HR-2 but links #hr-1/, null);
  expect('an index-shaped row outside § Readings is not an entry', [roster('index-outside', ['## Rulings', '', entry(1), '', def(1)])], 0, /1 HR definitions/, null);
  expect('a roster with no § Readings heading exits 2', [roster('no-readings', [def(1)], [], false)], 2, null, /no `## Readings` heading/);
  const live = fileURLToPath(new URL('../docs/ROSTER.md', import.meta.url));
  expect('the live roster holds a unique id space, admitted statuses, no dangling citation and a matching index', [live], 0, /HR definitions, unique, each with an admitted status, no dangling citation, the readings index in parity/, null);
  console.log(`clause-id-guard fixture: ${cases} cases passed`);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
}
