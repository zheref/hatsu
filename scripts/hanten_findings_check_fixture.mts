#!/usr/bin/env node
// Hermetic focused fixture for the status-aware HR finding policy (HR-10,
// HR-337). Each hostile criterion fails by finding id; unread input stays exit 2.
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { main as checkMain } from './hanten_findings_check.mts';

export function runHantenFindingsFixture(): void {
const checker = fileURLToPath(new URL('./hanten_findings_check.mts', import.meta.url));
const scratch = mkdtempSync(join(tmpdir(), 'hatsu-hanten-findings-'));
const roster = join(scratch, 'ROSTER.md');
const statusRows = [
  '| HR id | Question | Status | Settles |',
  '|---|---|---|---|',
  '| <a id="hr-1"></a>**HR-1** | q | ruled | x |',
  '| <a id="hr-2"></a>**HR-2** | q | reading | x |',
  '| <a id="hr-3"></a>**HR-3** | q | reversed by HR-1 | x |',
  '| <a id="hr-4"></a>**HR-4** | q | superseded by HR-1 (one part) | x |',
  '',
  '## Readings — every reading-status clause, indexed',
  '',
  '| HR id | Date | What it reads |',
  '|---|---|---|',
  '| [HR-2](#hr-2) | 2026-10-25 | x |',
].join('\n');
writeFileSync(roster, `${statusRows}\n`);

const base = (id: string, rule: string, severity = 'critical', state = 'fixed', detail?: string) => ({
  id, scope: 'architecture', persona: 'Chrollo', rule, severity, path: 'x', line: 1,
  evidence: 'observed', proposedFix: 'fix it', disposition: { state, ...(detail === undefined ? {} : { detail }) },
});
let cases = 0;

function exercise(name: string, args: string[], status: number, stdout: RegExp | null, stderr: RegExp | null): void {
  const directStdout: string[] = [];
  const directStderr: string[] = [];
  const originalLog = console.log;
  const originalError = console.error;
  console.log = (...values: unknown[]) => directStdout.push(values.map(String).join(' '));
  console.error = (...values: unknown[]) => directStderr.push(values.map(String).join(' '));
  let directStatus: number;
  try {
    directStatus = checkMain(args);
  } finally {
    console.log = originalLog;
    console.error = originalError;
  }
  const directDetail = `${name} (direct): exit ${directStatus}\nstdout: ${directStdout.join('\n')}\nstderr: ${directStderr.join('\n')}`;
  assert.equal(directStatus, status, directDetail);
  if (stdout) assert.match(directStdout.join('\n'), stdout, directDetail);
  if (stderr) assert.match(directStderr.join('\n'), stderr, directDetail);
  if (status === 2) assert.equal(directStdout.length, 0, `direct tooling failures carry no finding annotation\n${directDetail}`);
  else assert.equal(directStderr.length, 0, `direct policy findings stay on stdout\n${directDetail}`);

  // Keep the executable boundary covered separately: direct calls make built-in
  // Node coverage honest, while this spawn pins argv, process exit and streams.
  const result = spawnSync(process.execPath, [checker, ...args], { encoding: 'utf8' });
  const detail = `${name}: exit ${result.status}\nstdout: ${result.stdout}\nstderr: ${result.stderr}`;
  assert.equal(result.status, status, detail);
  if (stdout) assert.match(String(result.stdout), stdout, detail);
  if (stderr) assert.match(String(result.stderr), stderr, detail);
  if (status === 2) assert.equal(String(result.stdout), '', `tooling failures carry no finding annotation\n${detail}`);
  else assert.equal(String(result.stderr), '', `policy findings stay on stdout\n${detail}`);
  cases += 1;
  console.log(`ok ${cases} - ${name}`);
}

function run(name: string, findings: unknown[], status: number, stdout: RegExp | null, stderr: RegExp | null, rosterPath = roster): void {
  const file = join(scratch, `${name}.json`);
  writeFileSync(file, `${JSON.stringify({ scopes: [], findings })}\n`);
  exercise(name, [file, rosterPath], status, stdout, stderr);
}

function raw(name: string, contents: string, stderr: RegExp): void {
  const file = join(scratch, `${name}.json`);
  writeFileSync(file, contents);
  exercise(name, [file, roster], 2, null, stderr);
}

function record(name: string, document: unknown, status: number, stdout: RegExp | null, stderr: RegExp | null, rosterPath = roster): void {
  const file = join(scratch, `${name}.json`);
  writeFileSync(file, `${JSON.stringify(document)}\n`);
  exercise(name, [file, rosterPath], status, stdout, stderr);
}

try {
  run('ruled rows require critical and fixed-or-deferred', [
    base('ruled-severity', 'HR-1', 'low'),
    base('ruled-pushback', 'HR-1', 'critical', 'pushed-back', 'because'),
  ], 1, /ruled-severity.*HR-1.*severity must be critical[\s\S]*ruled-pushback.*HR-1.*disposition must be fixed or deferred/, null);
  run('reading reversed and superseded rows may be pushed back with reasons', [
    base('reading-ok', 'HR-2', 'low', 'pushed-back', 'the reading is not binding'),
    base('reversed-ok', 'HR-3', 'nit', 'pushed-back', 'HR-1 reversed it'),
    base('superseded-ok', 'HR-4', 'medium', 'pushed-back', 'HR-1 superseded this part'),
    base('non-hr-ignored', 'UX-1', 'low', 'pushed-back', 'the non-HR rule does not hold'),
  ], 0, /every HR-cited finding/, null);
  run('a pushed-back non-ruled row needs a reason', [base('reading-empty-reason', 'HR-2', 'low', 'pushed-back', '   ')], 1, /invalid findings record: \$\.findings\[0\]\.disposition\.detail has an invalid format/, null);
  run('an undefined HR id is a finding', [base('undefined-row', 'HR-99')], 1, /undefined-row cites HR-99, which no ROSTER row defines/, null);
  run('a padded HR citation is a bad record before roster lookup', [base('padded-row', 'HR-337 ', 'low', 'pushed-back', 'not binding')], 1, /invalid findings record: \$\.findings\[0\]\.rule must use canonical HR-N form/, null, join(scratch, 'absent.md'));
  run('a leading-zero HR citation is a bad record', [base('zero-row', 'HR-0337')], 1, /invalid findings record: \$\.findings\[0\]\.rule must use canonical HR-N form/, null);
  run('a non-string rule is a bad record', [{ ...base('number-rule', 'HR-1'), rule: 337 }], 1, /invalid findings record: \$\.findings\[0\]\.rule must be string/, null);
  const { disposition: _readingDisposition, ...readingWithoutDisposition } = base('reading-no-disposition', 'HR-2', 'low');
  run('a reading finding missing disposition is a bad record', [readingWithoutDisposition], 1, /invalid findings record: \$\.findings\[0\]\.disposition is required/, null);
  run('malformed structural fields are bad records', [{ ...base('bad-fields', 'UX-1'), line: 'one', evidence: '' }], 1, /invalid findings record: \$\.findings\[0\]\.line must be integer[\s\S]*invalid findings record: \$\.findings\[0\]\.evidence is too short/, null);
  run('the schema-owned CON branch remains enforced', [base('constitutional', 'CON-1', 'low', 'pushed-back', 'no')], 1, /invalid findings record: \$\.findings\[0\]\.severity must equal its schema constant[\s\S]*invalid findings record: \$\.findings\[0\]\.disposition\.state is not an admitted value/, null);
  run('an unread roster is tooling exit 2', [base('not-a-finding', 'HR-1')], 2, null, /cannot read roster/, join(scratch, 'absent.md'));
  exercise('wrong arity is tooling exit 2', [], 2, null, /usage/);
  exercise('an unsafe findings path is tooling exit 2', [join(scratch, 'forged,line.json'), roster], 2, null, /refusing a findings path/);
  exercise('an unread findings file is tooling exit 2', [join(scratch, 'absent.json'), roster], 2, null, /cannot read .* as JSON/);
  raw('invalid JSON is tooling exit 2', '{', /cannot read .* as JSON/);
  record('a missing findings array is a bad record', { scopes: [] }, 1, /invalid findings record: \$\.findings is required/, null);
  record('a non-object finding is a bad record', { scopes: [], findings: [null] }, 1, /invalid findings record: \$\.findings\[0\] must be object/, null);
  console.log(`hanten-findings-check fixture: ${cases} cases passed`);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
}
