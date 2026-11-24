// In-process replay for exact-source Node LCOV over scripts/tenkai_readiness_guard.mts (tenkai-guard).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, copyFileSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { applyReader, readerState, workflowGate } from './tenkai_readiness_guard.mts';
import {
  adoptionRole, adoptLegacyRequiredContext, adoptPortableReadiness, BOOTSTRAP_ABSENT, bootstrapPins, CONSUMER_BAD_REF,
  CONSUMER_UNREADABLE, consumerPinsBlocked, KEPT_RUNNER, PIN_ABSENT, PROCESS_NO_PIN, READINESS_WORKFLOW, readBootstrapIntegrity,
  readinessInputs, readinessRunnerBlocked, readPinnedRef, readReadinessTemplate, registryText, type AdoptionRunner,
} from './tenkai_readiness_policy.mts';
import { POLICY_CONTRACT, POLICY_PATH, policyText, workflowDigest } from './readiness_workflow_policy.mts';

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
const runnerFor = (runsOn: string, visibility: string | null = 'private'): AdoptionRunner =>
  ({ runs_on: runsOn, fallback: 'ubuntu-latest', reason: 'fixture', labels_required: false, derived_from: { visibility } });

// A git repository registered under the given role, so the portable route's registry check holds.
// A process repository carries its own pin and digests: its rendered pin step has no fallback to Hatsu's.
function registered(work: string, name: string, role: 'process' | 'product') {
  const repo = join(work, name);
  mkdirSync(join(repo, 'nen'), { recursive: true });
  writeFileSync(join(repo, 'nen', 'repos.json'), JSON.stringify(role === 'process' ? { maintained_tools: [slug] } : { consumers: [slug] }));
  if (role === 'process') writeFileSync(join(repo, 'nen', 'contract.json'), JSON.stringify({ dependency: liveContract.dependency }));
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

// The candidate template's own "Read the pinned nen ref" step, run under bash against a contract.
function pinStep(): string {
  const text = readFileSync(join(root, 'templates', 'pr-readiness.yml'), 'utf8');
  const start = text.indexOf('      - name: Read the pinned nen ref from trusted nen/contract.json\n');
  assert.ok(start >= 0, 'the template carries its pin step');
  const run = text.indexOf('        run: |\n', start) + '        run: |\n'.length;
  const end = text.indexOf('\n      - name: ', run);
  return text.slice(run, end).split('\n').map(line => line.startsWith('          ') ? line.slice(10) : line).join('\n');
}

type Contract = { bytes: Buffer | null; link?: boolean; mode?: number };
function placeContract(dir: string, { bytes, link, mode }: Contract) {
  mkdirSync(join(dir, 'nen'), { recursive: true });
  if (!bytes) return;
  const target = join(dir, 'nen', 'contract.json');
  if (link) {
    writeFileSync(join(dir, 'real.json'), bytes);
    symlinkSync('../real.json', target);
  } else writeFileSync(target, bytes);
  if (mode !== undefined) chmodSync(target, mode);
}

test('consumerPinsBlocked admits exactly the consumer contracts the rendered pin step accepts, per role (QA-18)', () => {
  const work = mkdtempSync(join(tmpdir(), 'hatsu-readiness-parity-'));
  try {
    const step = join(work, 'pin-step.sh');
    writeFileSync(step, pinStep());
    const hex = (c: string) => c.repeat(64);
    const ok = { scriptSha256: hex('a'), sha256: { 'linux-x64': hex('b') } };
    const j = (value: unknown): Contract => ({ bytes: Buffer.from(JSON.stringify(value)) });
    const root0 = process.getuid?.() === 0;
    // `strict`: Tenkai's bounded reader refuses these even where jq would read them, so only admit => accept is owed.
    const corpus: Array<[string, Contract, boolean?]> = [
      ['no contract', { bytes: null }],
      ['empty object', j({})],
      ['empty dependency', j({ dependency: {} })],
      ['null pinned_ref', j({ dependency: { pinned_ref: null } })],
      ['valid pin + digests', j({ dependency: { pinned_ref: 'v1', bootstrap: ok } })],
      ['valid pin, bad other-platform key (HR-399)', j({ dependency: { pinned_ref: 'v1', bootstrap: { ...ok, sha256: { ...ok.sha256, 'darwin-arm64': 'zz' } } } })],
      ['pin without digests', j({ dependency: { pinned_ref: 'v1' } })],
      ['pin with uppercase digest', j({ dependency: { pinned_ref: 'v1', bootstrap: { ...ok, sha256: { 'linux-x64': hex('B') } } } })],
      ['pin with a string bootstrap', j({ dependency: { pinned_ref: 'v1', bootstrap: 'x' } })],
      ['empty-string pinned_ref', j({ dependency: { pinned_ref: '' } })],
      ['numeric pinned_ref', j({ dependency: { pinned_ref: 5, bootstrap: ok } })],
      ['boolean pinned_ref', j({ dependency: { pinned_ref: false } })],
      ['null dependency', j({ dependency: null })],
      ['string dependency', j({ dependency: 'v1' })],
      ['array root', j([{ dependency: { pinned_ref: 'v1', bootstrap: ok } }])],
      ['string root', j('v1')],
      ['malformed JSON', { bytes: Buffer.from('{"dependency": {"pinned_ref": "v1",') }],
      ["'..' ref + digests", j({ dependency: { pinned_ref: 'v1..2', bootstrap: ok } })],
      ["'//' ref + digests", j({ dependency: { pinned_ref: 'a//b', bootstrap: ok } })],
      ['spaced ref + digests', j({ dependency: { pinned_ref: 'v1 2', bootstrap: ok } })],
      ['leading-dot ref + digests', j({ dependency: { pinned_ref: '.v1', bootstrap: ok } })],
      ['101-character ref + digests', j({ dependency: { pinned_ref: 'v'.repeat(101), bootstrap: ok } })],
      ['shell-shaped ref + digests', j({ dependency: { pinned_ref: 'v1;$(x)', bootstrap: ok } })],
      ['non-UTF-8 contract', { bytes: Buffer.concat([Buffer.from('{"$comment":"'), Buffer.from([0xff, 0xfe]),
        Buffer.from('","dependency":{"pinned_ref":"v1","bootstrap":' + JSON.stringify(ok) + '}}')]) }, true],
      ['oversized contract', j({ pad: 'x'.repeat(2 * 1024 * 1024 + 10), dependency: { pinned_ref: 'v1', bootstrap: ok } }), true],
      ['symlinked contract', { ...j({ dependency: { pinned_ref: 'v1', bootstrap: ok } }), link: true }, true],
      ...(root0 ? [] : [['mode-000 contract', { ...j({ dependency: { pinned_ref: 'v1', bootstrap: ok } }), mode: 0o000 }] as [string, Contract]]),
    ];
    for (const role of ['product', 'process'] as const) {
      for (const [name, contract, strict] of corpus) {
        const label = role + ': ' + name;
        const repo = mkdtempSync(join(work, 'repo-'));
        const run = mkdtempSync(join(work, 'run-'));
        placeContract(repo, contract);
        placeContract(join(run, '.trusted'), contract);
        const admits = consumerPinsBlocked(repo, role) === null;
        const exit = spawnSync('bash', [step], { cwd: run, encoding: 'utf8', env: { PATH: process.env.PATH!,
          TENKAI_PIN_FALLBACK_ALLOWED: role === 'process' ? 'false' : 'true', TENKAI_FALLBACK_REF: 'v0.30.0',
          TENKAI_FALLBACK_SCRIPT_SHA256: hex('c'), TENKAI_FALLBACK_BINARY_SHA256: hex('d'), GITHUB_OUTPUT: join(run, 'out') } }).status;
        if (admits) assert.equal(exit, 0, label + ': Tenkai admits it, but the rendered pin step exits ' + exit);
        else if (!strict) assert.notEqual(exit, 0, label + ': the rendered pin step accepts it, but Tenkai blocks it');
        else assert.notEqual(consumerPinsBlocked(repo, role), null, label);
      }
    }
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});

test('each refused consumer contract names its own defect and the action that clears it', () => {
  const work = mkdtempSync(join(tmpdir(), 'hatsu-readiness-consumer-rows-'));
  try {
    const repo = join(work, 'repo');
    const ok = { scriptSha256: 'a'.repeat(64), sha256: { 'linux-x64': 'b'.repeat(64) } };
    const put = (text: string) => { mkdirSync(join(repo, 'nen'), { recursive: true }); writeFileSync(join(repo, 'nen', 'contract.json'), text); };
    assert.equal(consumerPinsBlocked(repo, 'product'), null, 'no contract: a product keeps the rendered fallback');
    assert.deepEqual(consumerPinsBlocked(repo, 'process')?.detail, PROCESS_NO_PIN, 'no contract: a process repository has none');
    put('{"dependency": {}}');
    assert.equal(consumerPinsBlocked(repo, 'product'), null);
    assert.equal(consumerPinsBlocked(repo), null, 'a bare call with no role cannot judge the fallback');
    assert.match(consumerPinsBlocked(repo, 'process')!.action!, /add dependency\.pinned_ref and its reviewed/);
    put('{not json');
    assert.deepEqual(consumerPinsBlocked(repo, 'product'), { state: 'blocked', detail: CONSUMER_UNREADABLE,
      action: "make this repository's nen/contract.json one regular, unlinked, readable UTF-8 JSON file under 2 MiB, then re-run diagnose" });
    put('[]');
    assert.match(consumerPinsBlocked(repo, 'product')!.detail, /root must be a JSON object/);
    put('{"dependency": null}');
    assert.match(consumerPinsBlocked(repo, 'product')!.detail, /dependency must be a JSON object/);
    put(JSON.stringify({ dependency: { pinned_ref: 'v1;$(x)', bootstrap: ok } }));
    const bad = consumerPinsBlocked(repo, 'product')!;
    assert.equal(bad.detail, CONSUMER_BAD_REF);
    assert.ok(!bad.detail.includes('$(x)') && !bad.action!.includes('$(x)'), 'an unsafe ref is never echoed');
    assert.match(bad.action!, /^repair the ref: .*or remove it to use Hatsu's rendered fallback$/);
    assert.match(consumerPinsBlocked(repo, 'process')!.action!, /^repair the ref: .* with its reviewed digests$/);
    put(JSON.stringify({ dependency: { pinned_ref: 'v1.2.3' } }));
    const digests = consumerPinsBlocked(repo, 'product')!;
    assert.match(digests.detail, /pins v1\.2\.3 but carries no valid dependency\.bootstrap/);
    assert.match(digests.action!, /^add the digests: .*, or drop its dependency\.pinned_ref$/);
    assert.ok(!consumerPinsBlocked(repo, 'process')!.action!.includes('drop its'), 'a process repository cannot drop its pin');
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});

test('a non-Linux runner kept under an unread visibility names the step that clears it, on both TS routes (BC-9)', () => {
  const work = mkdtempSync(join(tmpdir(), 'hatsu-readiness-kept-'));
  try {
    const template = readReadinessTemplate(root)!;
    const mac = '[self-hosted, macOS, ARM64, pool-mac]';
    const kept = readinessRunnerBlocked(mac, true)!;
    assert.equal(kept.state, 'blocked');
    assert.ok(kept.detail.includes(KEPT_RUNNER) && kept.detail.includes(mac), kept.detail);
    assert.match(kept.action!, /--visibility <public\|private> --self-hosted <n>/);
    assert.equal(readinessRunnerBlocked('ubuntu-latest', true), null);
    const onMac = (text: string) => text.replace(/^    runs-on: [^\n]+$/m, '    runs-on: ' + mac);

    // Legacy-context route: a Tenkai-rendered workflow with a renamed job, installed on a macOS pool.
    const legacy = registered(work, 'legacy', 'product');
    const hosted = readinessInputs(template, 'product', legacy.registry, slug, runnerFor('ubuntu-latest')).rendered!;
    const installed = onMac(hosted.replace('\n  readiness:\n', '\n  renamed:\n'));
    mkdirSync(join(legacy.repo, '.github', 'workflows'), { recursive: true });
    writeFileSync(join(legacy.repo, READINESS_WORKFLOW), installed);
    const unread = readinessInputs(template, 'product', legacy.registry, slug, runnerFor('ubuntu-latest', null));
    assert.equal(unread.runnerKnown, false);
    for (const mode of ['probe', 'diagnose', 'apply'] as const) {
      assert.deepEqual(adoptLegacyRequiredContext(legacy.repo, root, unread, mode), kept, 'legacy ' + mode);
    }
    assert.equal(readFileSync(join(legacy.repo, READINESS_WORKFLOW), 'utf8'), installed, 'the legacy workflow is untouched');
    // The advised step: a readable (or passed) visibility re-derives the runner and the repair lands.
    const read = readinessInputs(template, 'product', legacy.registry, slug, runnerFor('ubuntu-latest', 'public'));
    assert.equal(adoptLegacyRequiredContext(legacy.repo, root, read, 'apply')?.state, 'repaired');

    // Portable route: an adopted workflow whose admitted rendering runs on a macOS pool.
    const portable = registered(work, 'portable', 'process');
    const known = readinessInputs(template, 'process', portable.registry, slug, runnerFor('ubuntu-latest', 'public'));
    assert.equal(adoptPortableReadiness(portable.repo, root, known, 'apply', true)?.state, 'repaired');
    const macWorkflow = onMac(readFileSync(join(portable.repo, READINESS_WORKFLOW), 'utf8'));
    writeFileSync(join(portable.repo, READINESS_WORKFLOW), macWorkflow);
    writeFileSync(join(portable.repo, POLICY_PATH), policyText({ contract: POLICY_CONTRACT, repository: slug,
      workflows: { [READINESS_WORKFLOW]: { current: workflowDigest(macWorkflow) } } }));
    const manifest = readFileSync(join(portable.repo, POLICY_PATH), 'utf8');
    const portableUnread = readinessInputs(template, 'process', portable.registry, slug, runnerFor('ubuntu-latest', null));
    for (const mode of ['diagnose', 'apply'] as const) {
      assert.deepEqual(adoptPortableReadiness(portable.repo, root, portableUnread, mode, true), kept, 'portable ' + mode);
    }
    assert.equal(readFileSync(join(portable.repo, READINESS_WORKFLOW), 'utf8'), macWorkflow, 'the portable workflow is untouched');
    assert.equal(readFileSync(join(portable.repo, POLICY_PATH), 'utf8'), manifest, 'the portable manifest is untouched');
    assert.notEqual(adoptPortableReadiness(portable.repo, root, known, 'diagnose', true)?.state, 'blocked', 'a read visibility clears it');
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});
