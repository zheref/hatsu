#!/usr/bin/env node
// Hermetic fixture for scripts/ledger_findings_prepare.mts (HA-PR-#463 review, SEC-3 and SEC-8): the
// security hold, the relativised copy carrying no /Users/ or /private/ path, the record untouched, and
// the 0/1/2 exits.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SCRIPT = join(ROOT, 'scripts/ledger_findings_prepare.mts');
const temp = mkdtempSync(join(tmpdir(), 'ledger-findings-'));
const repo = join(temp, 'repo');
mkdirSync(repo);
const run = (...args: string[]): { status: number | null; out: string } => {
  const r = spawnSync(process.execPath, [SCRIPT, ...args], { encoding: 'utf8' });
  return { status: r.status, out: `${r.stdout}${r.stderr}` };
};
const finding = (id: string, scope: string, severity: string, state: string, path: string): object => ({
  id, scope, persona: 'feitan', rule: 'SEC-8', severity, path, line: 1,
  evidence: `seen at ${path} and ${homedir()}/notes.txt and /private/var/folders/x/y.json`, proposedFix: 'fix it',
  disposition: { state, detail: 'reason', tracked: 'HA#1' },
});
const record = (findings: object[]): string => {
  const path = join(temp, `record-${Math.random().toString(16).slice(2)}.json`);
  writeFileSync(path, JSON.stringify({ scopes: [], findings, reports: [{ scope: 'security', persona: 'feitan', invocation: 'ran', head: 'abc', path: `${realpathSync(repo)}/.nen/hanten/x.cycle.json` }] }));
  return path;
};
try {
  // 1. Relativised: no absolute machine path in the copy; the record is untouched.
  const src = record([finding('F1', 'security', 'medium', 'pushed-back', `${repo}/scripts/a.ts`), finding('C1', 'code', 'high', 'deferred', '/Users/someone/elsewhere/b.ts')]);
  const before = readFileSync(src, 'utf8');
  const out = join(temp, 'copy.json');
  let r = run('--findings', src, '--repo', repo, '--out', out);
  assert.equal(r.status, 0, r.out);
  const copy = readFileSync(out, 'utf8');
  assert.ok(!copy.includes('/Users/') && !copy.includes('/private/') && !copy.includes(homedir()), copy);
  assert.match(copy, /"\.\/scripts\/a\.ts"/);
  assert.match(copy, /~\/notes\.txt/);
  assert.match(copy, /<path>/);
  assert.equal(readFileSync(src, 'utf8'), before, 'the record is never changed');
  // 2. A security high not fixed holds the post, naming it; nothing written.
  const held = join(temp, 'held.json');
  r = run('--findings', record([finding('F2', 'security', 'high', 'deferred', 'a'), finding('F3', 'security', 'critical', 'fixed', 'b')]), '--repo', repo, '--out', held, '--json');
  assert.equal(r.status, 1, r.out);
  assert.deepEqual(JSON.parse(r.out), { contract: 'hatsu.ledger-findings/v0.1', verdict: 'security-unsettled', ids: ['F2'] });
  assert.equal(existsSync(held), false);
  // 3. Security high and critical all fixed: prepared.
  r = run('--findings', record([finding('F4', 'security', 'critical', 'fixed', 'a')]), '--repo', repo, '--out', join(temp, 'ok.json'));
  assert.equal(r.status, 0, r.out);
  // 4. Wiring.
  assert.equal(run('--findings', src, '--repo', repo).status, 2);
  assert.equal(run('--findings', src, '--repo', repo, '--out', 'relative.json').status, 2);
  assert.equal(run('--findings', join(temp, 'missing.json'), '--repo', repo, '--out', out).status, 2);
  writeFileSync(join(temp, 'bad.json'), '{"findings": 3}');
  assert.equal(run('--findings', join(temp, 'bad.json'), '--repo', repo, '--out', out).status, 2);
  assert.equal(run('--bogus').status, 2);
  console.log('ledger-findings fixture: relativised copy (no /Users/ or /private/), record untouched, security hold, exits passed');
} finally {
  rmSync(temp, { recursive: true, force: true });
}
