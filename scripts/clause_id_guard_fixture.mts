#!/usr/bin/env node
// HR-2: hermetic fixture for scripts/clause_id_guard.mts. Each case writes a
// throwaway roster and asserts the guard's exit code and stream split.
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const guard = fileURLToPath(new URL('./clause_id_guard.mts', import.meta.url));
const scratch = mkdtempSync(join(tmpdir(), 'hatsu-clause-id-'));
const def = (n: number | string, label: number | string = n): string => `| <a id="hr-${n}"></a>**HR-${label}** | a ruling | ruled |`;
let cases = 0;

function run(args: string[]): ReturnType<typeof spawnSync> {
  return spawnSync(process.execPath, [guard, ...args], { cwd: scratch, encoding: 'utf8' });
}
function roster(name: string, lines: string[]): string {
  const path = join(scratch, `${name}.md`);
  writeFileSync(path, `${lines.join('\n')}\n`);
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
  const live = fileURLToPath(new URL('../docs/ROSTER.md', import.meta.url));
  expect('the live roster holds a unique id space', [live], 0, /HR definitions, unique/, null);
  console.log(`clause-id-guard fixture: ${cases} cases passed`);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
