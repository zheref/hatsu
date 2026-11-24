import { test, expect } from 'vitest';
import { copyFileSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const guardScript = join(root, 'scripts', 'tenkai_readiness_guard.mts');
const adoptScript = join(root, 'scripts', 'tenkai_adopt.sh');
const readerRel = 'scripts/readiness_ci_verdict.mts';
const policyRel = 'scripts/workflow_runner_policy_check.rb';
const liveContract = JSON.parse(readFileSync(join(root, 'nen', 'contract.json'), 'utf8'));

function tempDir(prefix: string): string {
  return mkdtempSync(join(tmpdir(), prefix));
}

function guardClosure(): string[] {
  const seen = new Set<string>();
  const visit = (script: string) => {
    if (seen.has(script)) return;
    seen.add(script);
    const text = readFileSync(join(root, 'scripts', script), 'utf8');
    for (const match of text.matchAll(/\bfrom\s+['"]\.\/([A-Za-z0-9_.-]+\.m?ts)['"]/g)) visit(match[1]!);
  };
  visit('tenkai_readiness_guard.mts');
  return [...seen];
}

function makeHatsu(base: string, contractOverride?: unknown): string {
  const hatsu = join(base, 'hatsu');
  mkdirSync(join(hatsu, 'nen'), { recursive: true });
  mkdirSync(join(hatsu, 'scripts'), { recursive: true });
  mkdirSync(join(hatsu, 'templates'), { recursive: true });
  copyFileSync(join(root, readerRel), join(hatsu, readerRel));
  // The frozen engine runs the guard from --hatsu-root, so copy it with its relative import closure.
  for (const script of guardClosure()) copyFileSync(join(root, 'scripts', script), join(hatsu, 'scripts', script));
  copyFileSync(join(root, 'templates', 'pr-readiness.yml'), join(hatsu, 'templates', 'pr-readiness.yml'));
  writeFileSync(join(hatsu, 'nen', 'contract.json'),
    typeof contractOverride === 'string'
      ? contractOverride
      : JSON.stringify(contractOverride ?? { dependency: liveContract.dependency }));
  return hatsu;
}

function makeConsumer(base: string, slug = 'acme/widget', installReader = true): string {
  const repo = join(base, 'consumer');
  mkdirSync(join(repo, 'nen'), { recursive: true });
  mkdirSync(join(repo, 'scripts'), { recursive: true });
  writeFileSync(join(repo, 'nen', 'repos.json'), JSON.stringify({ consumers: [{ repo: slug }] }));
  const git = (args: string[]) => spawnSync('git', ['-C', repo, ...args], {
    encoding: 'utf8',
    env: { ...process.env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' },
  });
  expect(git(['init', '-q']).status).toBe(0);
  expect(git(['remote', 'add', 'origin', `https://github.com/${slug}.git`]).status).toBe(0);
  if (installReader) {
    const readerText = readFileSync(join(root, readerRel), 'utf8')
      .replace('#!/usr/bin/env node\n', '#!/usr/bin/env node\n// RENDERED BY hatsu:tenkai from scripts/readiness_ci_verdict.mts\n');
    writeFileSync(join(repo, readerRel), readerText);
  }
  return repo;
}

function runGuard(mode: string, repo: string, hatsuRoot: string) {
  return spawnSync(process.execPath, [guardScript, mode, repo, hatsuRoot], { encoding: 'utf8' });
}

test('tenkai_readiness_guard stages outdated workflow policy guards and blocks missing/malformed contract integrity', () => {
  const work = tempDir('tenkai-readiness-guard-');
  try {
    const hatsu = makeHatsu(work);
    const repo = makeConsumer(work, 'acme/widget', false);

    // Reader missing -> apply installs, workflow-gate transitions staged -> satisfied
    expect(JSON.parse(runGuard('workflow-gate', repo, hatsu).stdout).state).toBe('staged');
    expect(JSON.parse(runGuard('apply', repo, hatsu).stdout).state).toBe('repaired');
    expect(JSON.parse(runGuard('diagnose', repo, hatsu).stdout).state).toBe('satisfied');
    expect(JSON.parse(runGuard('workflow-gate', repo, hatsu).stdout).state).toBe('satisfied');

    // Legacy READINESS_FROZEN_VERDICT without _NEXT -> staged
    writeFileSync(join(repo, policyRel), 'READINESS_FROZEN_VERDICT = :text\n');
    const frozenRow = JSON.parse(runGuard('workflow-gate', repo, hatsu).stdout);
    expect(frozenRow.state).toBe('staged');
    expect(frozenRow.detail).toContain('JSON reader step');

    // #131 READINESS_RENDERED_STEPS without READINESS_INTEGRITY_STEPS -> staged (two-PR ordering)
    writeFileSync(join(repo, policyRel), 'READINESS_FROZEN_VERDICT_NEXT = {}\nREADINESS_RENDERED_STEPS = {}\n');
    const integrityStagedRow = JSON.parse(runGuard('workflow-gate', repo, hatsu).stdout);
    expect(integrityStagedRow.state).toBe('staged');
    expect(integrityStagedRow.detail).toContain('workflow guard');
    expect(integrityStagedRow.detail).toContain('checksum-verified bootstrap step');

    // Consumer guard carrying READINESS_INTEGRITY_STEPS -> satisfied
    writeFileSync(join(repo, policyRel), 'READINESS_RENDERED_STEPS = {}\nREADINESS_INTEGRITY_STEPS = {}\n');
    expect(JSON.parse(runGuard('workflow-gate', repo, hatsu).stdout).state).toBe('satisfied');

    // Symlinked guard -> staged
    rmSync(join(repo, policyRel));
    symlinkSync(join(root, policyRel), join(repo, policyRel));
    expect(JSON.parse(runGuard('workflow-gate', repo, hatsu).stdout).state).toBe('staged');
    rmSync(join(repo, policyRel));

    // bootstrap-pins succeeds cleanly on valid contract
    const pinsRes = runGuard('bootstrap-pins', repo, hatsu);
    expect(pinsRes.status, pinsRes.stderr).toBe(0);
    expect(JSON.parse(pinsRes.stdout)).toEqual({
      ref: liveContract.dependency.pinned_ref,
      scriptSha256: liveContract.dependency.bootstrap.scriptSha256,
      binarySha256: liveContract.dependency.bootstrap.sha256['linux-x64'],
    });

    // Missing or malformed pinned_ref -> blocked naming dependency.pinned_ref
    for (const badRef of [undefined, '', 'v1..v2', 'a//b', 123]) {
      const badHatsu = makeHatsu(tempDir('hatsu-bad-ref-'), {
        dependency: { pinned_ref: badRef, bootstrap: liveContract.dependency.bootstrap },
      });
      try {
        const row = JSON.parse(runGuard('workflow-gate', repo, badHatsu).stdout);
        expect(row.state).toBe('blocked');
        expect(row.detail).toContain('dependency.pinned_ref');
        expect(runGuard('bootstrap-pins', repo, badHatsu).status).toBe(1);
      } finally { rmSync(dirname(badHatsu), { recursive: true, force: true }); }
    }

    // Missing or malformed bootstrap checksums -> blocked naming dependency.bootstrap checksums
    const validSha = 'a'.repeat(64);
    for (const badBootstrap of [
      undefined,
      {},
      { scriptSha256: 'bad', sha256: { 'linux-x64': validSha } },
      { scriptSha256: validSha, sha256: { 'darwin-arm64': validSha } },
      { scriptSha256: validSha, sha256: { 'linux-x64': validSha, 'BAD_KEY': validSha } },
      { scriptSha256: validSha, sha256: { 'linux-x64': validSha, 'windows-x64': 'UPPER' + '0'.repeat(59) } },
    ]) {
      const badHatsu = makeHatsu(tempDir('hatsu-bad-boot-'), {
        dependency: { pinned_ref: 'v0.30.0', ...(badBootstrap !== undefined ? { bootstrap: badBootstrap } : {}) },
      });
      try {
        const row = JSON.parse(runGuard('workflow-gate', repo, badHatsu).stdout);
        expect(row.state).toBe('blocked');
        expect(row.detail).toContain('bootstrap checksums');
        expect(runGuard('bootstrap-pins', repo, badHatsu).status).toBe(1);
      } finally { rmSync(dirname(badHatsu), { recursive: true, force: true }); }
    }
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});

test('tenkai_adopt.sh diagnose relays STAGED integrity guard and BLOCKED bootstrap checksums with mapped fixes', () => {
  const work = tempDir('tenkai-adopt-relay-');
  try {
    const repo = makeConsumer(work, 'acme/widget', true);
    const badHatsu = makeHatsu(work, { dependency: { pinned_ref: liveContract.dependency.pinned_ref } });

    const blockedRun = spawnSync('bash', [adoptScript, 'diagnose', '--repo', repo, '--hatsu-root', badHatsu, '--visibility', 'public', '--self-hosted', '0', '--json'], {
      encoding: 'utf8',
    });
    expect([0, 1]).toContain(blockedRun.status);
    const blockedDoc = JSON.parse(blockedRun.stdout);
    const blockedItem = blockedDoc.items.find((item: any) => item.id === '.github/workflows/pr-readiness.yml');
    expect(blockedItem.state).toBe('blocked');
    expect(blockedItem.detail).toContain('bootstrap checksums');
    expect(blockedItem.fix.fill).toBe('route');
    expect(blockedItem.fix.detect).toContain('tenkai_adopt.sh diagnose');

    // With valid Hatsu root and READINESS_RENDERED_STEPS guard lacking READINESS_INTEGRITY_STEPS -> staged
    writeFileSync(join(repo, policyRel), 'READINESS_RENDERED_STEPS = {}\n');
    const stagedRun = spawnSync('bash', [adoptScript, 'diagnose', '--repo', repo, '--hatsu-root', root, '--visibility', 'public', '--self-hosted', '0', '--json'], {
      encoding: 'utf8',
    });
    expect([0, 1]).toContain(stagedRun.status);
    const stagedDoc = JSON.parse(stagedRun.stdout);
    const stagedItem = stagedDoc.items.find((item: any) => item.id === '.github/workflows/pr-readiness.yml');
    expect(stagedItem.state).toBe('staged');
    expect(stagedItem.detail).toContain('checksum-verified bootstrap step');
    expect(stagedItem.fix.fill).toBe('route');
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});
