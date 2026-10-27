import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createMatrix, main } from './direct_matrix_doc.mts';

const scripts = dirname(fileURLToPath(import.meta.url));
const root = dirname(scripts);

// One set of meaningful cases: authoritative Vitest and supplemental native capture
// both call these functions. The process fixtures keep the stable shell entry involved.
export function runTypedMatrixFixture(): void {
  const current = createMatrix(root).render();
  const canonExample = current.claims.find(c => c.t === 'example' && c.ex.kind === 'process');
  assert.equal(canonExample?.t === 'example' ? canonExample.ex.role : undefined, 'canon', 'preserve the legacy canon example input, even though process kind also derives aigov');
  assert.equal(current.page, readFileSync(join(root, 'docs/DIRECT-MATRIX.md'), 'utf8'),
    'the committed generated page must match the typed renderer');
  // The trusted renderer is always the sibling of the wrapper, never code in the data root.
  // Each case starts from current data and keeps its page untouched, so malformed data must
  // refuse with exit 2 rather than quietly rendering a stale-page verdict (exit 1).
  const data = mkdtempSync(join(tmpdir(), 'hatsu-direct-matrix-data-'));
  const paths = ['contracts/direct.registry.json', 'contracts/classify.taxonomy.json', 'nen/workflow.json', 'docs/DIRECT-MATRIX.md'];
  const originals = new Map(paths.map(p => [p, readFileSync(join(root, p))]));
  try {
    for (const p of paths) mkdirSync(dirname(join(data, p)), { recursive: true });
    function reset() { for (const [p, bytes] of originals) writeFileSync(join(data, p), bytes); }
    function edit(path: string, change: (value: Record<string, unknown>) => void) {
      const value = JSON.parse(readFileSync(join(data, path), 'utf8')) as Record<string, unknown>;
      change(value); writeFileSync(join(data, path), JSON.stringify(value));
    }
    function run(...args: string[]) { return spawnSync('bash', [join(scripts, 'direct_matrix_doc.sh'), ...args, data], { encoding: 'utf8', cwd: data }); }
    const registry = 'contracts/direct.registry.json';
    const taxonomy = 'contracts/classify.taxonomy.json';
    // These fixture casts operate on known source JSON, never production input.
    const cases: Array<[string, string, string, (d: Record<string, unknown>) => void]> = [
      ['alias shape', registry, 'aliases.SEMANTIC_MAX', d => { (d.aliases as Record<string, unknown>).SEMANTIC_MAX = []; }],
      ['unknown alias', registry, 'UNKNOWN_ALIAS', d => { const routing = d.routing as Record<string, Record<string, { cells: Record<string, { winner: { alias: string } }> }>>; routing['bug-fix'].maintenance.cells['*'].winner.alias = 'UNKNOWN_ALIAS'; }],
      ['missing shared cell', registry, "shared '*'", d => { const routing = d.routing as Record<string, Record<string, { cells: Record<string, unknown> }>>; delete routing['bug-fix'].maintenance.cells['*']; }],
      ['bad list price', registry, 'listPrice.input', d => { const snap = d.snapshot as { aliases: Record<string, { listPrice: { input: unknown } }> }; snap.aliases.SEMANTIC_MAX.listPrice.input = 'cheap'; }],
      ['bad served shape', registry, 'served.codex', d => { const snap = d.snapshot as { aliases: Record<string, { served: unknown }> }; snap.aliases.EXECUTION_FRONTIER.served = { codex: { id: 'missing required metadata' } }; }],
      ['bad precedence', registry, 'aggregation.precedence', d => { (d.aggregation as { precedence: string[] }).precedence.push('SEMANTIC_MAX'); }],
      ['unknown predicate', taxonomy, 'not one known shape', d => { (d.domains as { rule: Array<{ when: unknown }> }).rule[0].when = { run: 'touch injected.marker' }; }],
      ['bad models shape', 'nen/workflow.json', 'models.codex', d => { (d.models as Record<string, unknown>).codex = []; }],
      ['prototype key', registry, 'reserved object key', d => { (d.aliases as Record<string, unknown>).constructor = {}; }],
    ];
    for (const [name, path, message, mutate] of cases) {
      reset(); edit(path, mutate); const result = run('--check');
      assert.equal(result.status, 2, `${name}: ${result.stdout}${result.stderr}`);
      assert.ok(result.stderr.includes(message), `${name} lacks its data pointer: ${result.stderr}`);
      assert.equal(readFileSync(join(data, 'docs/DIRECT-MATRIX.md'), 'utf8'), originals.get('docs/DIRECT-MATRIX.md')!.toString(), `${name} changed the page`);
    }
    for (const bytes of [Buffer.from('null'), Buffer.from('{invalid'), Buffer.from('{"x":"\xff"}', 'latin1')]) {
      reset(); writeFileSync(join(data, registry), bytes); const result = run('--check');
      assert.equal(result.status, 2, `malformed JSON/UTF-8: ${result.stdout}${result.stderr}`);
    }
    reset(); mkdirSync(join(data, 'scripts'));
    writeFileSync(join(data, 'scripts/direct_matrix_doc.mts'), "throw Error('untrusted renderer executed');\n");
    const check = run('--check'); assert.equal(check.status, 0, check.stdout + check.stderr);
    const print = run(); assert.equal(print.status, 0, print.stdout + print.stderr);
    assert.equal(print.stdout, originals.get('docs/DIRECT-MATRIX.md')!.toString(), 'the historical no-mode CLI changed');
    reset(); edit('nen/workflow.json', d => { const models = d.models as Record<string, { deep: string }>; models.codex.deep = 'fixture-new-name'; });
    assert.equal(run('--check').status, 1, 'a model spelling edit must make the page stale');
    reset(); writeFileSync(join(data, 'docs/DIRECT-MATRIX.md'), 'stale');
    const written = run('--write'); assert.equal(written.status, 0, written.stdout + written.stderr);
    assert.equal(readFileSync(join(data, 'docs/DIRECT-MATRIX.md'), 'utf8'), originals.get('docs/DIRECT-MATRIX.md')!.toString(), '--write changed page bytes');
    assert.equal(main(['check', data]), 0, 'in-process check must accept the fresh page');
    assert.equal(main(['write', data]), 0, 'in-process write must preserve the fresh page');
    assert.throws(() => main(['unsupported', data]), /expected a mode/);
    assert.equal(run('--check', '--write').status, 2, 'multiple modes must refuse');
    assert.equal(run('--unknown').status, 2, 'unknown flags must refuse');
    assert.equal(run(data).status, 2, 'multiple roots must refuse');
    assert.equal(run('--help').status, 0, 'historical help must remain available');
    const trusted = spawnSync(process.execPath, [join(scripts, 'direct_matrix_ci_check.mts'), data], { encoding: 'utf8', cwd: data });
    assert.equal(trusted.status, 0, trusted.stdout + trusted.stderr);
    reset(); writeFileSync(join(data, 'docs/DIRECT-MATRIX.md'), 'stale');
    const stale = spawnSync(process.execPath, [join(scripts, 'direct_matrix_ci_check.mts'), data], { encoding: 'utf8', cwd: data });
    assert.equal(stale.status, 1, stale.stdout + stale.stderr);
    reset(); writeFileSync(join(data, registry), '{invalid');
    const malformed = spawnSync(process.execPath, [join(scripts, 'direct_matrix_ci_check.mts'), data], { encoding: 'utf8', cwd: data });
    assert.equal(malformed.status, 2, malformed.stdout + malformed.stderr);
    assert.ok(!existsSync(join(data, 'injected.marker')), 'data executed as a command');
    console.log('ok    malformed data fails closed; trusted code, exact page bytes, CLI modes, model drift and CI verdicts hold');
  } finally { rmSync(data, { recursive: true, force: true }); }
}

export function runMatrixRuleFixture(): void {
  assert.equal(createMatrix(root).selfTest(), 0, 'legacy renderer rules, edge cases and invariants must hold');
}

export function runDatedEvidenceFixture(): void {
  const data = mkdtempSync(join(tmpdir(), 'hatsu-direct-evidence-'));
  const paths = ['contracts/direct.registry.json', 'contracts/classify.taxonomy.json', 'nen/workflow.json', 'docs/DIRECT-MATRIX.md'];
  const originals = new Map(paths.map(p => [p, readFileSync(join(root, p))]));
  type FixtureRegistry = { snapshot: { evidenceVersion?: unknown; aliases: Record<string, { listPrice: Record<string, unknown>; served: Record<string, unknown>; evidence?: string }>;
    sources: Record<string, { costPerTask: Record<string, unknown> }> }; picks: { inPool: Record<string, string> }; routing: unknown;
    aliases: Record<string, Record<string, unknown>> };
  const activation = JSON.parse(readFileSync(join(scripts, 'fixtures/direct-evidence.activation.json'), 'utf8')) as FixtureRegistry;
  try {
    for (const p of paths) mkdirSync(dirname(join(data, p)), { recursive: true });
    function reset(active = true) {
      for (const [p, bytes] of originals) writeFileSync(join(data, p), bytes);
      if (!active) return;
      const value = JSON.parse(originals.get('contracts/direct.registry.json')!.toString()) as FixtureRegistry;
      value.snapshot.evidenceVersion = activation.snapshot.evidenceVersion;
      for (const [name, row] of Object.entries(activation.snapshot.aliases)) value.snapshot.aliases[name] = { ...value.snapshot.aliases[name], ...row };
      for (const [name, row] of Object.entries(activation.snapshot.sources)) value.snapshot.sources[name] = { ...value.snapshot.sources[name], ...row };
      for (const [name, row] of Object.entries(activation.aliases)) value.aliases[name] = { ...value.aliases[name], ...row };
      value.picks = { ...value.picks, ...activation.picks };
      writeFileSync(join(data, 'contracts/direct.registry.json'), JSON.stringify(value));
    }
    function edit(change: (value: FixtureRegistry) => void) {
      const value = JSON.parse(readFileSync(join(data, 'contracts/direct.registry.json'), 'utf8')) as FixtureRegistry;
      change(value); writeFileSync(join(data, 'contracts/direct.registry.json'), JSON.stringify(value));
    }
    function run(...args: string[]) { return spawnSync('bash', [join(scripts, 'direct_matrix_doc.sh'), ...args, data], { encoding: 'utf8', cwd: data }); }
    reset(false);
    const inactive = createMatrix(data, { today: '2026-10-27' });
    assert.equal(inactive.evidenceEnabled, false, 'absent evidenceVersion defaults to legacy behavior');
    assert.equal(inactive.render().page, originals.get('docs/DIRECT-MATRIX.md')!.toString(), 'bootstrap preserves the live page byte for byte');
    assert.throws(() => inactive.verdictEvidence('VISUAL_MAX', null, 'VISUAL_MAX', 'max'), /not activated/);
    const inactiveCli = spawnSync(process.execPath, [join(scripts, 'direct_matrix_doc.mts'), 'evidence', data, '--repo', data,
      '--primary', 'VISUAL_ORCHESTRATOR', '--fallback', 'SEMANTIC_FRONTIER', '--recommended', 'VISUAL_MAX', '--effort', 'max'], { encoding: 'utf8' });
    assert.equal(inactiveCli.status, 0, inactiveCli.stdout + inactiveCli.stderr);
    assert.equal(JSON.parse(inactiveCli.stdout).enabled, false, 'the skill cannot silently activate dated reports');
    reset();
    const current = createMatrix(data, { today: '2026-10-27' });
    assert.deepEqual(current.priceFindings(), []);
    const page = current.render().page;
    assert.match(page, /\$2 \/ \$10 through 2026-11-30; \$4 \/ \$20 from 2026-12-01/);
    assert.match(page, /\$0\.75 \/ \$3\.75 through 2026-12-31; \$1\.5 \/ \$7\.5 from 2027-01-01/);
    assert.match(page, /\$3\.98 USD per Artificial Analysis Intelligence Index task/);
    assert.match(page, /\$0\.72 USD per Artificial Analysis Intelligence Index task/);
    assert.match(page, /Basis \/ method/);
    const verdict = current.verdictEvidence('VISUAL_ORCHESTRATOR', 'SEMANTIC_FRONTIER', 'VISUAL_MAX', 'max', 'Antigravity CLI');
    assert.equal(verdict.primary.restartWarning, 'not served on Antigravity CLI as of 2026-10-19');
    assert.equal(verdict.primary.served[0].id, null, 'a missing model must not be reported as served');
    assert.match(verdict.primary.restart, /Model: pro/, 'the restart uses the consumer tier spelling');
    assert.equal(verdict.primary.inPool?.alias, 'VISUAL_FALLBACK');
    assert.equal(verdict.recommended.inPool?.alias, 'VISUAL_FALLBACK', 'Argon also exposes the quota-only Flash option');
    assert.match(verdict.recommended.served[0].quota!, /weekly-only/);
    assert.equal(verdict.fallback?.alias, 'SEMANTIC_FRONTIER', 'the required cross-provider fallback is unchanged');
    assert.equal(verdict.recommended.restartWarning, null, 'unobserved IDE availability and historical CLI lag are not current absence');
    assert.equal(current.verdictEvidence('VISUAL_ORCHESTRATOR', null, 'VISUAL_MAX', 'max', 'Antigravity IDE').primary.restartWarning, null,
      'a CLI refusal must not become an IDE refusal');
    assert.equal(current.verdictEvidence('VISUAL_ORCHESTRATOR', null, 'VISUAL_MAX', 'max').primary.restartWarning, null,
      'an unread product must not be guessed');
    const sol = current.verdictEvidence('EXECUTION_FRONTIER', 'SEMANTIC_FRONTIER', 'EXECUTION_MAX', 'max');
    assert.equal(sol.primary.served[0].id, 'gpt-5.6-sol');
    assert.equal(sol.primary.served[0].readOn, '2026-10-05');
    assert.equal(sol.primary.costPerTask?.value, 0.72);
    assert.match(sol.primary.costPerTask!.basis, /not the older served Sol id/);
    assert.equal(sol.primary.served[0].quota, null, 'null quota remains unread');
    const legacy = current.verdictEvidence('MECHANICAL_EDITOR', 'BALANCED_AUTHOR', 'EDITOR_FRONTIER', 'low');
    assert.equal(legacy.primary.served[0].legacy, true, 'unmigrated served strings remain readable');
    assert.match(legacy.primary.served[0].line, /composer-2\.5/);
    assert.equal(legacy.primary.served[0].readOn, null, 'a legacy string does not inherit a fabricated read date');
    assert.equal(legacy.primary.costPerTask, null, 'list price is not substituted for an absent task cost');
    assert.throws(() => current.verdictEvidence('UNKNOWN_ALIAS', null, 'VISUAL_MAX', 'low'), /unknown reference/);
    assert.throws(() => current.verdictEvidence('PR_QUALITY_REVIEW', null, 'VISUAL_MAX', 'low'), /reviewer/);
    assert.throws(() => current.verdictEvidence('VISUAL_MAX', 'VISUAL_FALLBACK', 'VISUAL_MAX', 'low'), /cross-provider/);
    assert.throws(() => current.verdictEvidence('VISUAL_MAX', null, 'VISUAL_MAX', 'ultra'), /unknown level/);
    assert.deepEqual(createMatrix(data, { today: '2026-11-30' }).priceFindings(), [], 'until includes its own date');
    assert.match(createMatrix(data, { today: '2026-12-01' }).priceFindings().join('\n'), /VISUAL_MAX.*2026-11-30/);
    assert.equal(createMatrix(data, { today: '2027-01-01' }).priceFindings().length, 2, 'both dated price steps eventually expire');
    const rejects: Array<[string, (d: FixtureRegistry) => void, RegExp]> = [
      ['unknown evidence version', d => { d.snapshot.evidenceVersion = 2; }, /snapshot.evidenceVersion/],
      ['invalid calendar date', d => { d.snapshot.aliases.VISUAL_MAX.listPrice.until = '2026-02-30'; }, /VISUAL_MAX.*until.*real ISO date/],
      ['missing next', d => { delete d.snapshot.aliases.VISUAL_MAX.listPrice.next; }, /until and next/],
      ['step gap', d => { (d.snapshot.aliases.VISUAL_MAX.listPrice.next as Record<string, unknown>).from = '2026-12-02'; }, /next.from.*day after/],
      ['negative next price', d => { (d.snapshot.aliases.VISUAL_MAX.listPrice.next as Record<string, unknown>).input = -1; }, /next.input.*nonnegative/],
      ['missing method', d => { d.snapshot.sources.artificialAnalysis.costPerTask.basis = ''; }, /costPerTask.basis.*nonempty/],
      ['malformed method date', d => { d.snapshot.sources.artificialAnalysis.costPerTask.readOn = 'today'; }, /costPerTask.readOn.*ISO date/],
      ['bad served lag', d => { (d.snapshot.aliases.VISUAL_MAX.served.antigravity as Record<string, unknown>).lag = []; }, /served.antigravity.lag/],
      ['missing quota', d => { delete (d.snapshot.aliases.VISUAL_MAX.served.antigravity as Record<string, unknown>).quota; }, /served.antigravity.quota/],
      ['unknown evidence', d => { d.snapshot.aliases.EXECUTION_FRONTIER.evidence = 'snapshot.sources.missing'; }, /evidence.*unknown reference/],
      ['foreign in-pool fallback', d => { d.picks.inPool.VISUAL_MAX = 'SEMANTIC_FRONTIER'; }, /inPool.VISUAL_MAX.*same provider and surface/],
      ['recursive in-pool fallback', d => { d.picks.inPool.VISUAL_FALLBACK = 'VISUAL_MAX'; }, /inPool.*terminal/],
    ];
    for (const [name, mutate, message] of rejects) { reset(); edit(mutate); assert.throws(() => createMatrix(data), message, name); }
    reset();
    const consumer = join(data, 'consumer'); mkdirSync(join(consumer, 'nen'), { recursive: true });
    const workflow = JSON.parse(originals.get('nen/workflow.json')!.toString()) as { models: { antigravity: { deep: string } } };
    workflow.models.antigravity.deep = 'fixture-pro'; writeFileSync(join(consumer, 'nen/workflow.json'), JSON.stringify(workflow));
    assert.match(createMatrix(data, { workflowRoot: consumer }).verdictEvidence('VISUAL_ORCHESTRATOR', null, 'VISUAL_MAX', 'max').primary.restart,
      /Model: fixture-pro/, 'registry evidence and the consumer workflow are separate inputs');
    const evidenceArgs = ['evidence', data, '--repo', consumer, '--primary', 'VISUAL_ORCHESTRATOR', '--fallback', 'SEMANTIC_FRONTIER',
      '--recommended', 'VISUAL_MAX', '--effort', 'max', '--product', 'Antigravity CLI'];
    const cli = spawnSync(process.execPath, [join(scripts, 'direct_matrix_doc.mts'), ...evidenceArgs], { encoding: 'utf8' });
    assert.equal(cli.status, 0, cli.stdout + cli.stderr);
    const cliEvidence = JSON.parse(cli.stdout) as typeof verdict;
    assert.equal(cliEvidence.primary.restartWarning, verdict.primary.restartWarning);
    assert.equal(cliEvidence.primary.typedAlias, 'fixture-pro');
    assert.throws(() => main([...evidenceArgs, '--product', 'duplicate']), /duplicate/);
    assert.throws(() => main(['evidence', data]), /required --repo/);
    const now = new Date().toISOString().slice(0, 10);
    const yesterday = new Date(Date.parse(now) - 86400000).toISOString().slice(0, 10);
    reset(); edit(d => { const lp = d.snapshot.aliases.VISUAL_MAX.listPrice; lp.readOn = yesterday; lp.until = yesterday;
      (lp.next as Record<string, unknown>).from = now; });
    const unchanged = readFileSync(join(data, 'contracts/direct.registry.json'), 'utf8');
    for (let attempt = 1; attempt <= 3; attempt++) {
      const expired = run('--self-test');
      assert.equal(expired.status, 1, `expired step attempt ${attempt}: ${expired.stdout}${expired.stderr}`);
      assert.ok(expired.stderr.includes('VISUAL_MAX') && expired.stderr.includes(yesterday), 'the failure names the alias and expired date');
    }
    assert.equal(run('--write').status, 1, 'an expired price cannot silently regenerate a plausible fresh page');
    const expiredEvidence = spawnSync(process.execPath, [join(scripts, 'direct_matrix_doc.mts'), ...evidenceArgs], { encoding: 'utf8' });
    assert.equal(expiredEvidence.status, 1);
    assert.match(expiredEvidence.stdout, /expiredPriceEvidence/);
    assert.equal(JSON.parse(expiredEvidence.stdout).recommended.price.input, 2, 'the report retains the dated observation, never auto-promotes next');
    const trusted = spawnSync(process.execPath, [join(scripts, 'direct_matrix_ci_check.mts'), data], { encoding: 'utf8' });
    assert.equal(trusted.status, 1, trusted.stdout + trusted.stderr);
    assert.ok(trusted.stdout.includes('VISUAL_MAX') && trusted.stdout.includes(yesterday), 'trusted CI carries the expired-price diagnostic inside its fence');
    assert.match(trusted.stderr, /expired price evidence/);
    assert.equal(readFileSync(join(data, 'contracts/direct.registry.json'), 'utf8'), unchanged, 'no check silently promotes next');
    assert.equal(readFileSync(join(data, 'docs/DIRECT-MATRIX.md'), 'utf8'), originals.get('docs/DIRECT-MATRIX.md')!.toString(), 'expiry leaves the committed page intact');
    console.log('ok    legacy mode stays byte-compatible; opted-in fixture prices expire (yesterday 3/3); method, served/product, quota and trusted CI behavior hold');
  } finally { rmSync(data, { recursive: true, force: true }); }
}
