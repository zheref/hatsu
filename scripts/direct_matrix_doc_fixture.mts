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
    'the typed renderer must preserve every byte of the committed legacy page');
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
      ['bad served shape', registry, 'served.codex', d => { const snap = d.snapshot as { aliases: Record<string, { served: unknown }> }; snap.aliases.EXECUTION_FRONTIER.served = { codex: { id: 'not activated by this preparer' } }; }],
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
