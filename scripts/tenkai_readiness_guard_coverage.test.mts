// In-process replay for exact-source Node LCOV over scripts/tenkai_readiness_guard.mts (tenkai-guard).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { copyFileSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { applyReader, bootstrapPins, readBootstrapIntegrity, readerState, readPinnedRef, workflowGate } from './tenkai_readiness_guard.mts';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const readerRel = 'scripts/readiness_ci_verdict.mts';
const policyRel = 'scripts/workflow_runner_policy_check.rb';
const liveContract = JSON.parse(readFileSync(join(root, 'nen', 'contract.json'), 'utf8'));

test('tenkai_readiness_guard decision, pin validation, and staged guard paths', () => {
  const work = mkdtempSync(join(tmpdir(), 'hatsu-readiness-guard-cov-'));
  try {
    const hatsu = join(work, 'hatsu');
    const repo = join(work, 'repo');
    mkdirSync(join(hatsu, 'nen'), { recursive: true });
    mkdirSync(join(hatsu, 'scripts'), { recursive: true });
    copyFileSync(join(root, readerRel), join(hatsu, readerRel));
    writeFileSync(join(hatsu, 'nen', 'contract.json'), JSON.stringify({ dependency: liveContract.dependency }));
    mkdirSync(join(repo, 'scripts'), { recursive: true });

    assert.equal(workflowGate(repo, hatsu).state, 'staged');
    assert.equal(readerState(repo, hatsu).state, 'missing');
    assert.equal(applyReader(repo, hatsu).state, 'repaired');
    assert.equal(readerState(repo, hatsu).state, 'satisfied');

    writeFileSync(join(repo, readerRel), readFileSync(join(root, readerRel), 'utf8'));
    assert.equal(readerState(repo, hatsu).state, 'satisfied');

    writeFileSync(join(repo, readerRel), '// RENDERED BY hatsu:tenkai from scripts/readiness_ci_verdict.mts\nstale\n');
    assert.equal(readerState(repo, hatsu).state, 'drift');
    assert.equal(applyReader(repo, hatsu).state, 'repaired');

    writeFileSync(join(repo, readerRel), 'foreign\n');
    assert.equal(readerState(repo, hatsu).state, 'blocked');
    assert.equal(applyReader(repo, hatsu).state, 'blocked');

    rmSync(join(repo, readerRel));
    symlinkSync(join(hatsu, readerRel), join(repo, readerRel));
    assert.equal(readerState(repo, hatsu).state, 'blocked');
    rmSync(join(repo, readerRel));
    applyReader(repo, hatsu);

    writeFileSync(join(repo, policyRel), 'READINESS_FROZEN_VERDICT = :text\n');
    assert.equal(workflowGate(repo, hatsu).state, 'staged');
    writeFileSync(join(repo, policyRel), 'READINESS_RENDERED_STEPS = {}\n');
    assert.equal(workflowGate(repo, hatsu).state, 'staged');
    writeFileSync(join(repo, policyRel), 'READINESS_INTEGRITY_STEPS = {}\n');
    assert.equal(workflowGate(repo, hatsu).state, 'satisfied');

    assert.equal(bootstrapPins(hatsu)?.ref, liveContract.dependency.pinned_ref);
    rmSync(join(repo, policyRel));
    symlinkSync(join(root, policyRel), join(repo, policyRel));
    assert.equal(workflowGate(repo, hatsu).state, 'staged');
    rmSync(join(repo, policyRel));

    const brokenRef = join(work, 'broken-ref');
    mkdirSync(join(brokenRef, 'nen'), { recursive: true });
    mkdirSync(join(brokenRef, 'scripts'), { recursive: true });
    copyFileSync(join(root, readerRel), join(brokenRef, readerRel));
    writeFileSync(join(brokenRef, 'nen', 'contract.json'), '{not json');
    assert.equal(readPinnedRef(brokenRef), null);
    assert.equal(readBootstrapIntegrity(brokenRef), null);
    assert.equal(bootstrapPins(brokenRef), null);
    assert.equal(workflowGate(repo, brokenRef).state, 'blocked');

    writeFileSync(join(brokenRef, 'nen', 'contract.json'), JSON.stringify({ dependency: { pinned_ref: 'v0.30.0', bootstrap: {} } }));
    assert.equal(readPinnedRef(brokenRef), 'v0.30.0');
    assert.equal(readBootstrapIntegrity(brokenRef), null);
    assert.equal(workflowGate(repo, brokenRef).state, 'blocked');
    assert.equal(bootstrapPins(brokenRef), null);

    rmSync(join(brokenRef, readerRel));
    assert.equal(readerState(repo, brokenRef).state, 'blocked');

    const linkedScriptsRepo = join(work, 'linked-scripts');
    mkdirSync(linkedScriptsRepo, { recursive: true });
    symlinkSync(work, join(linkedScriptsRepo, 'scripts'));
    assert.equal(readerState(linkedScriptsRepo, hatsu).state, 'blocked');
    assert.equal(applyReader(linkedScriptsRepo, hatsu).state, 'blocked');
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});
