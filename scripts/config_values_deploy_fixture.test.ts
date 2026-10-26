#!/usr/bin/env node
/** HA#246: diagnose catches an unsafe standing deploy.defaultTarget without weakening blocked/null reads. */
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterAll, test } from 'vitest';

const HATSU_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SCRIPT = join(HATSU_ROOT, 'scripts/config_values.sh');
const temporary: string[] = [];
const outstanding = new Set(['unannotated', 'invalid', 'default-unwritten', 'required-missing', 'file-missing', 'blocked']);

afterAll(() => { for (const dir of temporary) rmSync(dir, { recursive: true, force: true }); });

function repoWith(workflow: string, contract: string): string {
  const repo = mkdtempSync(join(tmpdir(), 'hatsu-config-deploy-'));
  temporary.push(repo);
  mkdirSync(join(repo, 'nen'));
  writeFileSync(join(repo, 'nen/workflow.json'), workflow);
  writeFileSync(join(repo, 'nen/contract.json'), contract);
  return repo;
}
const document = (value: unknown): string => `${JSON.stringify(value)}\n`;
const workflow = (target: unknown): string => document({ deploy: { defaultTarget: target } });
const contract = (target: unknown): string => document({ project: { targets: { beta: target } } });
function runArgs(args: string[]) {
  return spawnSync('bash', [SCRIPT, 'diagnose', ...args], { encoding: 'utf8' });
}
function run(repo: string, json: boolean) {
  return runArgs(['--repo', repo, '--domain', 'deployment', ...(json ? ['--json'] : [])]);
}
function readResult(result: ReturnType<typeof runArgs>) {
  const parsed = JSON.parse(result.stdout);
  assert.equal(parsed.outstanding, parsed.values.filter((row: { state: string }) => outstanding.has(row.state)).length, 'JSON outstanding count drifted from its rows');
  assert.equal(result.status, parsed.outstanding === 0 ? 0 : 1, `${result.stdout}${result.stderr}`);
  return parsed;
}
function read(repo: string) { return readResult(run(repo, true)); }
const row = (parsed: any, id: string) => parsed.values.find((value: { id: string }) => value.id === id);

test('a standing default whose target lacks nonProduction: true is invalid, with the repair and both counts', () => {
  const repo = repoWith(workflow('beta'), contract({ why: 'non-production TestFlight upload' }));
  const parsed = read(repo);
  const target = row(parsed, 'workflow.deploy.defaultTarget');
  assert.equal(target.state, 'invalid');
  assert.match(target.detail, /project\.targets\.beta\.nonProduction to true in nen\/contract\.json/);
  assert.equal(parsed.outstanding, 1);
  const plain = run(repo, false);
  assert.equal(plain.status, 1, plain.stderr);
  assert.match(plain.stdout, /BAD   nen\/workflow\.json → deploy\.defaultTarget/);
  assert.match(plain.stdout, /1 value\(s\) outstanding/);
  assert.match(plain.stdout, /nonProduction to true/);
});

test('a target explicitly typed non-production stays set and does not change the count', () => {
  const repo = repoWith(workflow('beta'), contract({ why: 'non-production TestFlight upload', nonProduction: true }));
  const parsed = read(repo);
  assert.equal(row(parsed, 'workflow.deploy.defaultTarget').state, 'set');
  assert.equal(parsed.outstanding, 0);
  assert.match(run(repo, false).stdout, /every settable value is written out and every needed one is set/);
});

test('duplicate --repo uses the last unsafe repository (safe → unsafe)', () => {
  const safe = repoWith(workflow('beta'), contract({ why: 'non-production TestFlight upload', nonProduction: true }));
  const unsafe = repoWith(workflow('beta'), contract({ why: 'non-production TestFlight upload' }));
  const parsed = readResult(runArgs(['--repo', safe, '--repo', unsafe, '--domain', 'deployment', '--json']));
  assert.equal(row(parsed, 'workflow.deploy.defaultTarget').state, 'invalid');
  assert.equal(parsed.outstanding, 1);
});

test('duplicate --repo uses the last safe repository (unsafe → safe)', () => {
  const unsafe = repoWith(workflow('beta'), contract({ why: 'non-production TestFlight upload' }));
  const safe = repoWith(workflow('beta'), contract({ why: 'non-production TestFlight upload', nonProduction: true }));
  const parsed = readResult(runArgs(['--repo', unsafe, '--repo', safe, '--domain', 'deployment', '--json']));
  assert.equal(row(parsed, 'workflow.deploy.defaultTarget').state, 'set');
  assert.equal(parsed.outstanding, 0);
});

test('an option value equal to --repo is consumed, not mistaken for a later repository option', () => {
  const unsafe = repoWith(workflow('beta'), contract({ why: 'non-production TestFlight upload' }));
  const parsed = readResult(runArgs(['--repo', unsafe, '--skill', '--repo', '--domain', 'deployment', '--json']));
  assert.equal(row(parsed, 'workflow.deploy.defaultTarget').state, 'invalid');
  assert.equal(parsed.outstanding, 1);
});

test('null remains the deliberate answer even when a declared target is not flagged', () => {
  const repo = repoWith(workflow(null), contract({ why: 'non-production TestFlight upload' }));
  const parsed = read(repo);
  assert.equal(row(parsed, 'workflow.deploy.defaultTarget').state, 'optional');
  assert.equal(parsed.outstanding, 0);
});

test('the why still has to say non-production even when the typed flag is true', () => {
  const repo = repoWith(workflow('beta'), contract({ why: 'App Store release', nonProduction: true }));
  const target = row(read(repo), 'workflow.deploy.defaultTarget');
  assert.equal(target.state, 'invalid');
  assert.match(target.detail, /why does not clearly say non-production/);
});

test('an unreadable declaration keeps the frozen engine blocked; the overlay never invents a verdict', () => {
  const repo = repoWith(workflow('beta'), '{ not json\n');
  const parsed = read(repo);
  assert.equal(row(parsed, 'workflow.deploy.defaultTarget').state, 'not-applicable');
  assert.equal(row(parsed, 'contract.project.targets').state, 'blocked');
  assert.equal(parsed.outstanding, 1);
  const plain = run(repo, false);
  assert.match(plain.stdout, /BLOK  nen\/contract\.json → project\.targets/);
  assert.doesNotMatch(plain.stdout, /before keeping deploy\.defaultTarget/);
  assert.equal(readFileSync(join(repo, 'nen/workflow.json'), 'utf8'), workflow('beta'));
});
