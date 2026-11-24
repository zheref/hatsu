// In-process replay for exact-source Node LCOV over scripts/tenkai_readiness_guard.mts (tenkai-guard).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { applyReader, readerState, workflowGate } from './tenkai_readiness_guard.mts';
import {
  adoptionRole, adoptLegacyRequiredContext, adoptPortableReadiness, BOOTSTRAP_ABSENT, bootstrapPins, consumerPinsBlocked,
  PIN_ABSENT, READINESS_WORKFLOW, readBootstrapIntegrity, readinessInputs, readinessRunnerBlocked, readPinnedRef,
  readReadinessTemplate, registryText, type AdoptionRunner,
} from './tenkai_readiness_policy.mts';

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

const slug = 'acme/widget';
const runnerFor = (runsOn: string): AdoptionRunner =>
  ({ runs_on: runsOn, fallback: 'ubuntu-latest', reason: 'fixture', labels_required: false, derived_from: { visibility: 'private' } });

// A git repository registered under the given role, so the portable route's registry check holds.
function registered(work: string, name: string, role: 'process' | 'product') {
  const repo = join(work, name);
  mkdirSync(join(repo, 'nen'), { recursive: true });
  writeFileSync(join(repo, 'nen', 'repos.json'), JSON.stringify(role === 'process' ? { maintained_tools: [slug] } : { consumers: [slug] }));
  assert.equal(spawnSync('git', ['-C', repo, 'init', '-q'], { encoding: 'utf8' }).status, 0);
  return { repo, registry: adoptionRole(registryText(repo), slug).digest };
}

test('the readiness checksum check admits only hosted ubuntu-latest or a self-hosted Linux X64 pool', () => {
  assert.equal(readinessRunnerBlocked('ubuntu-latest'), null);
  assert.equal(readinessRunnerBlocked('[self-hosted, Linux, X64, pool-ci]'), null);
  for (const runner of ['[self-hosted, macOS, ARM64, pool-mac]', '[self-hosted, Linux, ARM64, pool-arm]',
    '[self-hosted, Windows, X64, pool-win]', 'self-hosted', 'macos-latest', undefined]) {
    const row = readinessRunnerBlocked(runner);
    assert.equal(row?.state, 'blocked', String(runner));
    assert.match(row!.detail, /^the readiness checksum check is Linux-only \(linux-x64\): this repository's readiness pool /);
    assert.match(row!.action!, /\[self-hosted, Linux, X64, pool-<id>\]/);
  }
  assert.match(readinessRunnerBlocked('[x]\n  evil: 1')!.detail, /\(an unreadable selector\)/);
});

test('portable and legacy-context routes block a non-Linux readiness runner and write nothing', () => {
  const work = mkdtempSync(join(tmpdir(), 'hatsu-readiness-linux-'));
  try {
    const template = readReadinessTemplate(root);
    assert.ok(template);
    for (const runner of ['[self-hosted, macOS, ARM64, pool-mac]', '[self-hosted, Linux, ARM64, pool-arm]']) {
      const name = runner.match(/pool-(\w+)/)![1]!;
      const portable = registered(work, 'portable-' + name, 'process');
      const input = readinessInputs(template, 'process', portable.registry, slug, runnerFor(runner));
      for (const mode of ['diagnose', 'apply'] as const) {
        const row = adoptPortableReadiness(portable.repo, root, input, mode, true);
        assert.equal(row?.state, 'blocked', mode + ' ' + runner);
        assert.ok(row!.detail.includes('Linux-only (linux-x64)') && row!.detail.includes(runner), row!.detail);
      }
      assert.equal(existsSync(join(portable.repo, READINESS_WORKFLOW)), false, 'no portable workflow was written');
      assert.equal(existsSync(join(portable.repo, 'scripts')), false, 'no portable guard or manifest was written');

      // A Tenkai-rendered legacy workflow with a renamed job owes a context repair, but not onto this pool.
      const legacy = registered(work, 'legacy-' + name, 'product');
      const hosted = readinessInputs(template, 'product', legacy.registry, slug, runnerFor('ubuntu-latest')).rendered!;
      const installed = hosted.replace('\n  readiness:\n', '\n  renamed:\n');
      assert.notEqual(installed, hosted);
      mkdirSync(join(legacy.repo, '.github', 'workflows'), { recursive: true });
      writeFileSync(join(legacy.repo, READINESS_WORKFLOW), installed);
      const legacyInput = readinessInputs(template, 'product', legacy.registry, slug, runnerFor(runner));
      for (const mode of ['probe', 'diagnose', 'apply'] as const) {
        const row = adoptLegacyRequiredContext(legacy.repo, root, legacyInput, mode);
        assert.equal(row?.state, 'blocked', mode + ' ' + runner);
        assert.ok(row!.detail.includes('Linux-only (linux-x64)'), row!.detail);
      }
      assert.equal(readFileSync(join(legacy.repo, READINESS_WORKFLOW), 'utf8'), installed, 'the installed workflow is untouched');
      // The same repair onto hosted ubuntu-latest still lands.
      const hostedInput = readinessInputs(template, 'product', legacy.registry, slug, runnerFor('ubuntu-latest'));
      assert.equal(adoptLegacyRequiredContext(legacy.repo, root, hostedInput, 'apply')?.state, 'repaired');
    }
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});

test('an unfilled placeholder and missing Hatsu bootstrap checksums block before any readiness write (BC-9)', () => {
  const work = mkdtempSync(join(tmpdir(), 'hatsu-readiness-arms-'));
  try {
    // adoptLegacyRequiredContext refuses a rendering that still carries @@, whatever the mode.
    const template = readReadinessTemplate(root)!;
    const legacy = registered(work, 'legacy', 'product');
    const input = readinessInputs(template, 'product', legacy.registry, slug, runnerFor('ubuntu-latest'));
    input.rendered += '# @@NEN_LEFTOVER@@\n';
    for (const mode of ['probe', 'diagnose', 'apply'] as const) {
      const row = adoptLegacyRequiredContext(legacy.repo, root, input, mode);
      assert.equal(row?.state, 'blocked', mode);
      assert.match(row!.detail, /unfilled @@ placeholder/);
    }
    assert.equal(existsSync(join(legacy.repo, READINESS_WORKFLOW)), false, 'nothing was written');

    // The portable route on a Hatsu root whose contract cannot render a verified bootstrap.
    const hatsu = join(work, 'hatsu');
    mkdirSync(join(hatsu, 'nen'), { recursive: true });
    mkdirSync(join(hatsu, 'templates'), { recursive: true });
    copyFileSync(join(root, 'templates', 'pr-readiness.yml'), join(hatsu, 'templates', 'pr-readiness.yml'));
    const portable = registered(work, 'portable', 'process');
    for (const [dependency, detail] of [
      [{ pinned_ref: liveContract.dependency.pinned_ref }, BOOTSTRAP_ABSENT],
      [{ bootstrap: liveContract.dependency.bootstrap }, PIN_ABSENT],
    ] as const) {
      writeFileSync(join(hatsu, 'nen', 'contract.json'), JSON.stringify({ dependency }));
      const unrendered = readinessInputs(readReadinessTemplate(hatsu), 'process', portable.registry, slug, runnerFor('ubuntu-latest'));
      assert.equal(unrendered.rendered, null);
      for (const mode of ['diagnose', 'apply'] as const) {
        const row = adoptPortableReadiness(portable.repo, hatsu, unrendered, mode, true);
        assert.deepEqual(row, { state: 'blocked', detail, action: "repair Hatsu's nen/contract.json" }, mode);
      }
    }
    // Valid pins with no rendering means Hatsu's inputs moved after the caller read them.
    const raced = readinessInputs(null, 'process', portable.registry, slug, runnerFor('ubuntu-latest'));
    assert.match(adoptPortableReadiness(portable.repo, root, raced, 'apply', true)!.detail, /changed during adoption/);
    const product = registered(work, 'product', 'product');
    assert.match(workflowGate(product.repo, root, { repo: product.repo, slug, role: 'product', registry: product.registry!,
      templateDigest: 'stale' }).detail, /changed during adoption/);
    assert.equal(existsSync(join(portable.repo, READINESS_WORKFLOW)), false, 'no workflow was written');
    assert.equal(existsSync(join(portable.repo, 'scripts')), false, 'no portable guard or manifest was written');
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});

test('a consumer pinning its own Nen without linux-x64 digests is blocked on the portable route', () => {
  const work = mkdtempSync(join(tmpdir(), 'hatsu-readiness-consumer-'));
  try {
    const portable = registered(work, 'portable', 'process');
    const template = readReadinessTemplate(root)!;
    const input = readinessInputs(template, 'process', portable.registry, slug, runnerFor('ubuntu-latest'));
    assert.equal(consumerPinsBlocked(portable.repo), null, 'no contract keeps the fallback');
    writeFileSync(join(portable.repo, 'nen', 'contract.json'), JSON.stringify({ dependency: { pinned_ref: 'v1.2.3',
      bootstrap: { scriptSha256: 'e'.repeat(64), sha256: { 'darwin-arm64': 'f'.repeat(64) } } } }));
    for (const mode of ['diagnose', 'apply'] as const) {
      const row = adoptPortableReadiness(portable.repo, root, input, mode, true);
      assert.equal(row?.state, 'blocked', mode);
      assert.ok(row!.detail.startsWith("this repository's nen/contract.json pins v1.2.3 but carries no valid dependency.bootstrap"), row!.detail);
    }
    assert.equal(existsSync(join(portable.repo, READINESS_WORKFLOW)), false, 'no workflow was written');
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});
