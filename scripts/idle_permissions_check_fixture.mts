#!/usr/bin/env node
// Hermetic fixture for scripts/idle_permissions_check.mts (zheref/hatsu#453 AC-3): matching, deny
// precedence, absent and unreadable settings, the exit vocabulary, and the shipped exemplar list's shape.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const CHECK = join(ROOT, 'scripts/idle_permissions_check.mts');
const temp = mkdtempSync(join(tmpdir(), 'idle-permissions-'));
const write = (name: string, value: unknown): string => { const path = join(temp, name); writeFileSync(path, typeof value === 'string' ? value : JSON.stringify(value)); return path; };
const run = (...args: string[]): { status: number | null; out: string } => {
  const result = spawnSync(process.execPath, [CHECK, ...args], { encoding: 'utf8' });
  return { status: result.status, out: `${result.stdout}${result.stderr}` };
};
try {
  const needs = write('needs.json', { contract: 'hatsu.idle-permissions/v0.1', needs: [
    { command: 'git push -u origin <branch>', by: 'aka' },
    { command: 'nen run start --id <run>', by: 'futon' },
    { command: 'git push --force origin <branch>', by: 'never' },
  ] });
  const settings = write('settings.json', { permissions: { allow: ['Bash(nen *)', 'Bash(git push:*)'], deny: ['Bash(git push --force *)'] } });
  let r = run('--needs', needs, '--settings', settings, '--json');
  assert.equal(r.status, 1, r.out);
  const document = JSON.parse(r.out) as { rows: Array<{ verdict: string; rule: string | null }>; missing: number };
  assert.deepEqual(document.rows.map((row) => row.verdict), ['allowed', 'allowed', 'denied']);
  assert.equal(document.rows[2]?.rule, 'Bash(git push --force *)');
  assert.equal(document.missing, 1);
  r = run('--needs', needs, '--settings', write('asked.json', { permissions: { allow: ['Bash'], ask: ['Bash(nen run *)'] } }), '--json');
  assert.equal(r.status, 1, 'an ask rule prompts even where an allow matches');
  assert.equal((JSON.parse(r.out) as { rows: Array<{ verdict: string }> }).rows[1]?.verdict, 'asks');
  r = run('--needs', needs, '--settings', write('all.json', { permissions: { allow: ['Bash'] } }));
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /3\/3 pre-allowed/);
  r = run('--needs', needs, '--settings', write('none.json', { permissions: { allow: ['Read(./**)'] } }));
  assert.equal(r.status, 1);
  assert.match(r.out, /not-pre-allowed: git push -u origin <branch>/);
  r = run('--needs', needs, '--settings', join(temp, 'absent.json'));
  assert.equal(r.status, 1);
  assert.match(r.out, /settings absent: /);
  r = run('--needs', needs, '--settings', write('broken.json', '{ not json'));
  assert.equal(r.status, 2, 'an unparseable settings file is wiring, never "nothing allowed"');
  r = run('--needs', needs, '--settings', write('shape.json', { permissions: { allow: 'Bash' } }));
  assert.equal(r.status, 2);
  r = run('--needs', write('bad-needs.json', { contract: 'x', needs: [] }), '--settings', settings);
  assert.equal(r.status, 2);
  assert.equal(run().status, 2);
  assert.equal(run('--bogus').status, 2);
  r = run('--settings', settings, '--json');
  assert.ok([0, 1].includes(r.status ?? -1), 'the shipped exemplar list parses');
  assert.ok((JSON.parse(r.out) as { rows: unknown[] }).rows.length > 0);
  console.log('idle-permissions fixture: matching, deny precedence, absent and unreadable settings, exits and the shipped list passed');
} finally {
  rmSync(temp, { recursive: true, force: true });
}
