/** HA#370: two shipped catalogues, offline ownership, opt-in refresh and the real Nen resolver. */
import { afterAll, expect, test } from 'vitest';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { catalogue, defaults } from './pr_sections.ts';
import { checkStamp, documentSha256, history, readSections } from './pr_sections_history.ts';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SCRIPT = join(ROOT, 'scripts/config_values.sh');
const temporary: string[] = [];
const clone = <T>(value: T): T => structuredClone(value);
const json = (value: unknown) => JSON.stringify(value, null, 2) + '\n';
function fresh(): string { const root = mkdtempSync(join(tmpdir(), 'ha370-')); temporary.push(root); return root; }
afterAll(() => { for (const path of temporary) rmSync(path, { recursive: true, force: true }); });

function fixture() {
  const root = fresh(); mkdirSync(join(root, 'contracts'));
  for (const name of ['claude', 'docs']) symlinkSync(join(ROOT, name), join(root, name), 'dir');
  cpSync(join(ROOT, 'templates'), join(root, 'templates'), { recursive: true });
  cpSync(join(ROOT, 'contracts/classify.taxonomy.json'), join(root, 'contracts/classify.taxonomy.json'));
  const config = JSON.parse(readFileSync(join(ROOT, 'contracts/config-catalogue.json'), 'utf8'));
  config.values = config.values.filter((row: any) => ['workflow.pr.sections', 'workflow.pr.sections.max'].includes(row.id));
  writeFileSync(join(root, 'contracts/config-catalogue.json'), json(config));
  const current = JSON.parse(readFileSync(join(ROOT, 'contracts/pr-sections.json'), 'utf8'));
  const previous = clone(current);
  previous.$comment += ' Previous fixture catalogue.';
  previous.variants['process.build'] = ['changes', 'why', 'how', 'improves', 'verify'];
  previous.sections.push({ ...previous.sections[2], id: 'retired-section' });
  previous.variants['product.verify'] = previous.variants['product.verify'].map((id: string) => id === 'evidence' ? 'retired-section' : id);
  previous.variants['process.retired'] = ['changes', 'why', 'how', 'improves', 'verify'];
  previous.documentSha256 = documentSha256(previous);
  writeFileSync(join(root, 'contracts/pr-sections.json'), json(current));
  writeFileSync(join(root, 'contracts/pr-sections.history.json'), json({ contract: 'hatsu.pr-sections.history/v1', catalogues: { [previous.documentSha256]: previous, [current.documentSha256]: current } }));
  const repo = fresh(); mkdirSync(join(repo, 'nen'));
  const value = { max: 7, variants: clone(previous.variants), $canon: { contract: previous.contract, sha256: previous.documentSha256 } };
  value.variants['library.fix'] = ['changes', 'why', 'how', 'improves', 'verify'];
  delete value.variants['process.canon'];
  const write = (sections: unknown = value) => writeFileSync(join(repo, 'nen/workflow.json'), json({ consumerNote: 'keep this', pr: { sections, $sections: 'old option list' } }));
  write();
  return { root, repo, current, previous, value, write };
}
function run(f: ReturnType<typeof fixture>, mode: string, ...extra: string[]) {
  return spawnSync('bash', [SCRIPT, mode, '--repo', f.repo, '--hatsu-root', f.root, ...extra], { encoding: 'utf8' });
}
const text = (f: ReturnType<typeof fixture>) => readFileSync(join(f.repo, 'nen/workflow.json'), 'utf8');
const workflow = (f: ReturnType<typeof fixture>) => JSON.parse(text(f));

test('canonical bytes ignore formatting and object-key order, include array order, and reject digest drift', () => {
  const raw = JSON.parse(readFileSync(join(ROOT, 'contracts/pr-sections.json'), 'utf8'));
  expect(checkStamp(raw)).toBe(raw.documentSha256);
  expect(documentSha256(Object.fromEntries(Object.entries(raw).reverse()))).toBe(raw.documentSha256);
  raw.variants['process.build'].reverse();
  expect(() => checkStamp(raw)).toThrow(/documentSha256 drifts/);
  const f = fixture(); mkdirSync(join(f.root, '.claude-plugin'));
  cpSync(join(ROOT, '.claude-plugin/plugin.json'), join(f.root, '.claude-plugin/plugin.json'));
  for (const name of ['pr-composition.json', 'pr-body.requirements.json']) cpSync(join(ROOT, 'contracts', name), join(f.root, 'contracts', name));
  f.current.$comment += ' Unstamped catalogue edit.';
  writeFileSync(join(f.root, 'contracts/pr-sections.json'), json(f.current));
  const guard = spawnSync('bash', [join(ROOT, 'scripts/pr_composition_check.sh'), '--root', f.root], { encoding: 'utf8' });
  expect(guard.status).not.toBe(0);
  expect(guard.stdout + guard.stderr).toContain('documentSha256 drifts from canonical bytes');
});

test('diagnose reads all six cell states without changing a packaged source or consumer', () => {
  const f = fixture(); const before = text(f);
  expect(existsSync(join(f.root, '.git'))).toBe(false);
  const result = run(f, 'diagnose', '--json');
  expect(result.status, result.stderr).toBe(0);
  const reading = JSON.parse(result.stdout).values.find((row: any) => row.id === 'workflow.pr.sections').prSections;
  const states = Object.fromEntries(reading.cells.map((row: any) => [row.cell, row.state]));
  expect(states['product.fix']).toBe('current default');
  expect(states['process.build']).toBe('stale default');
  expect(states['library.fix']).toBe('consumer-owned');
  expect(states['process.canon']).toBe('missing');
  expect(states['process.retired']).toBe('retired');
  expect(reading.counts).toMatchObject({ staleDefault: 2, consumerOwned: 1, missing: 1, retired: 1 });
  expect(reading.stampedSha7).toBe(f.previous.documentSha256.slice(0, 7));
  expect(reading.catalogueSha7).toBe(f.current.documentSha256.slice(0, 7));
  expect(text(f)).toBe(before);
  const unstamped: any = clone(f.value); delete unstamped.$canon; f.write(unstamped);
  const legacy = run(f, 'diagnose', '--json');
  expect(legacy.status, legacy.stderr).toBe(0);
  const row = JSON.parse(legacy.stdout).values.find((row: any) => row.id === 'workflow.pr.sections');
  expect(row.detail).toMatch(/^pr.sections: unstamped/);
  expect(row.detail).not.toContain('; process.build: unstamped');
  expect(row.detail.split('\n')).toHaveLength(1);
  expect(row.prSections.cells.find((cell: any) => cell.cell === 'process.build')).toMatchObject({ state: 'unstamped', matchesCurrent: false, ownership: 'unknown' });
});

test('plain fill keeps a present partial matrix byte-identical; absent fill stamps the full matrix', () => {
  const f = fixture(); const partial: any = clone(f.value); delete partial.max; f.write(partial);
  const before = text(f);
  expect(run(f, 'fill', '--json').status).toBe(0);
  expect(text(f)).toBe(before);
  writeFileSync(join(f.repo, 'nen/workflow.json'), '{}\n');
  expect(run(f, 'fill', '--json').status).toBe(0);
  expect(workflow(f).pr.sections).toEqual(defaults(catalogue(f.root)));
  expect(workflow(f).pr.$sections).toContain('available sections:');
});

test('refresh advances defaults, missing cells, options and stamp; preserves edited cells and cap', () => {
  const f = fixture(); f.value.max = 6; f.write();
  const result = run(f, 'fill', '--refresh', '--json');
  expect(result.status, result.stderr).toBe(0);
  expect(JSON.parse(result.stdout).prSections.kept).toContain('library.fix');
  const pr = workflow(f).pr;
  expect(pr.sections.variants['process.build']).toEqual(f.current.variants['process.build']);
  expect(pr.sections.variants['product.verify']).toEqual(f.current.variants['product.verify']);
  expect(pr.sections.variants['process.canon']).toEqual(f.current.variants['process.canon']);
  expect(pr.sections.variants).not.toHaveProperty('process.retired');
  expect(pr.sections.variants['library.fix']).toEqual(f.value.variants['library.fix']);
  expect(pr.sections.max).toBe(6);
  expect(pr.sections.$canon).toMatchObject({ contract: f.current.contract, sha256: f.current.documentSha256, owned: ['library.fix'] });
  expect(pr.$sections).toContain('available sections: delivery');
  expect(workflow(f).consumerNote).toBe('keep this');
  const before = text(f);
  expect(run(f, 'fill', '--refresh', '--json').status).toBe(0);
  expect(text(f)).toBe(before);
});

test('owned cells remain owned when their edits coincide with a newer default', () => {
  const f = fixture();
  f.value.variants['library.fix'] = clone(f.current.variants['library.fix']);
  f.previous.variants['library.fix'] = ['changes', 'why', 'improves', 'verify'];
  f.previous.documentSha256 = documentSha256(f.previous);
  f.value.$canon.sha256 = f.previous.documentSha256;
  writeFileSync(join(f.root, 'contracts/pr-sections.history.json'), json({ contract: 'hatsu.pr-sections.history/v1', catalogues: { [f.previous.documentSha256]: f.previous, [f.current.documentSha256]: f.current } }));
  f.write();
  expect(run(f, 'fill', '--refresh', '--json').status).toBe(0);
  const reading = readSections(workflow(f).pr.sections, catalogue(f.root), history(f.root, catalogue(f.root)));
  expect(reading.cells.find(row => row.cell === 'library.fix')?.state).toBe('consumer-owned');
});

test('owned retired ids are named and refuse before any declaration or option annotation is written', () => {
  const f = fixture(); f.value.variants['library.maintain'].push('retired-section'); f.write();
  writeFileSync(join(f.repo, 'nen/gates.json'), '{}\n');
  const before = text(f);
  const result = run(f, 'fill', '--refresh', '--json');
  expect(result.status).toBe(1);
  expect(result.stderr).toContain('library.maintain: retired id(s) retired-section');
  expect(result.stderr).toContain('library.fix');
  expect(text(f)).toBe(before);
  expect(readFileSync(join(f.repo, 'nen/gates.json'), 'utf8')).toBe('{}\n');
});

test('unknown/malformed stamps, duplicate JSON, blocked paths and invalid retained caps write nothing', () => {
  for (const malformed of [{ contract: 'wrong', sha256: 'a'.repeat(64) }, { contract: 'hatsu.pr-sections/v1', sha256: 'a'.repeat(64) }]) {
    const f = fixture(); f.write({ ...f.value, $canon: malformed }); const before = text(f);
    expect(run(f, 'fill', '--refresh', '--json').status).toBe(2); expect(text(f)).toBe(before);
    const unrelated = run(f, 'diagnose', '--domain', 'deployment', '--json');
    expect(unrelated.status, unrelated.stderr).toBe(0);
    expect(JSON.parse(unrelated.stdout).values).toEqual([]);
  }
  const duplicate = fixture(); writeFileSync(join(duplicate.repo, 'nen/workflow.json'), '{"pr":{},"pr":{}}\n');
  expect(run(duplicate, 'fill', '--refresh').status).toBe(2); expect(text(duplicate)).toBe('{"pr":{},"pr":{}}\n');
  const linked = fixture(); const outside = fresh(); const victim = join(outside, 'workflow.json');
  writeFileSync(victim, text(linked)); rmSync(join(linked.repo, 'nen/workflow.json')); symlinkSync(victim, join(linked.repo, 'nen/workflow.json'));
  const saved = readFileSync(victim, 'utf8'); expect(run(linked, 'fill', '--refresh').status).toBe(2); expect(readFileSync(victim, 'utf8')).toBe(saved);
  const cap = fixture(); cap.value.max = 5; cap.write(); const before = text(cap);
  expect(run(cap, 'fill', '--refresh').status).toBe(2); expect(text(cap)).toBe(before);
});

test('unstamped refresh preserves every existing cell and remembers ownership on later refreshes', () => {
  const f = fixture(); const legacy: any = defaults(catalogue(f.root)); delete legacy.$canon;
  legacy.variants['library.fix'] = ['changes', 'why', 'improves', 'verify'];
  delete legacy.variants['process.canon']; f.write(legacy);
  const before = clone(legacy.variants);
  const first = run(f, 'fill', '--refresh', '--json');
  expect(first.status, first.stderr).toBe(0);
  expect(JSON.parse(first.stdout).prSections.detail).toContain('provenance unknown');
  const adopted = workflow(f).pr.sections;
  for (const [cell, ids] of Object.entries(before)) expect(adopted.variants[cell]).toEqual(ids);
  expect(adopted.variants['process.canon']).toEqual(f.current.variants['process.canon']);
  expect(adopted.$canon.owned).toEqual(Object.keys(before));
  f.current.variants['process.build'] = ['changes', 'why', 'improves', 'verify'];
  f.current.documentSha256 = documentSha256(f.current);
  writeFileSync(join(f.root, 'contracts/pr-sections.json'), json(f.current));
  const ledger = JSON.parse(readFileSync(join(f.root, 'contracts/pr-sections.history.json'), 'utf8'));
  ledger.catalogues[f.current.documentSha256] = f.current;
  writeFileSync(join(f.root, 'contracts/pr-sections.history.json'), json(ledger));
  expect(run(f, 'fill', '--refresh', '--json').status).toBe(0);
  expect(workflow(f).pr.sections.variants['process.build']).toEqual(before['process.build']);
  expect(workflow(f).pr.sections.$canon.owned).toContain('process.build');
});

test('a tampered packaged history fails closed', () => {
  const f = fixture();
  f.write(); const ledger = JSON.parse(readFileSync(join(f.root, 'contracts/pr-sections.history.json'), 'utf8'));
  ledger.catalogues[f.previous.documentSha256].variants['process.build'] = ['changed'];
  writeFileSync(join(f.root, 'contracts/pr-sections.history.json'), json(ledger));
  expect(run(f, 'fill', '--refresh').status).toBe(2);
  const path = join(f.root, 'contracts/pr-sections.history.json');
  rmSync(path); symlinkSync(join(ROOT, 'contracts/pr-sections.history.json'), path);
  expect(run(f, 'fill', '--refresh').status).toBe(2);
  expect(run(f, 'fill', '--refresh').stderr).toContain('symlinks are refused');
});

test('Tenkai JSON inbox carries counts and both hashes while current diagnosis has no finding', () => {
  const f = fixture(); const script = join(ROOT, 'scripts/tenkai_adopt.sh');
  const args = ['diagnose', '--repo', f.repo, '--hatsu-root', f.root, '--slug', 'fixture/consumer', '--visibility', 'public', '--self-hosted', '0', '--json'];
  const before = text(f);
  const first = spawnSync('bash', [script, ...args], { encoding: 'utf8' });
  expect([0, 1]).toContain(first.status);
  const report = JSON.parse(first.stdout); const row = report.items.find((item: any) => item.id === 'pr.sections');
  expect(row.detail).toContain(`stamped ${f.previous.documentSha256.slice(0, 7)}, catalogue ${f.current.documentSha256.slice(0, 7)}`);
  expect(row.prSections.counts).toMatchObject({ staleDefault: 2, missing: 1 });
  expect(report.outstanding).toBe(report.items.filter((item: any) => ['missing', 'drift', 'routed', 'staged', 'blocked'].includes(item.state)).length);
  expect(text(f)).toBe(before);
  f.write(defaults(catalogue(f.root)));
  const current = spawnSync('bash', [script, ...args], { encoding: 'utf8' });
  expect(JSON.parse(current.stdout).items.some((item: any) => item.id === 'pr.sections')).toBe(false);
});

test('Tenkai apply explicitly refreshes known defaults and refuses owned retired ids before adopting', () => {
  const script = join(ROOT, 'scripts/tenkai_adopt.sh');
  const apply = (f: ReturnType<typeof fixture>) => spawnSync('bash', [script, 'apply', '--repo', f.repo, '--hatsu-root', f.root, '--slug', 'fixture/consumer', '--visibility', 'public', '--self-hosted', '0', '--json'], { encoding: 'utf8' });
  const f = fixture();
  const result = apply(f);
  expect([0, 1]).toContain(result.status);
  expect(workflow(f).pr.sections.$canon.sha256).toBe(f.current.documentSha256);
  expect(workflow(f).pr.sections.variants['process.build']).toEqual(f.current.variants['process.build']);
  expect(workflow(f).pr.sections.variants['library.fix']).toEqual(f.value.variants['library.fix']);
  expect(JSON.parse(result.stdout).items.find((row: any) => row.id === 'pr.sections').state).toBe('repaired');
  const refused = fixture(); refused.value.variants['library.maintain'].push('retired-section'); refused.write();
  const before = text(refused);
  const blocked = apply(refused);
  expect(blocked.status).toBe(1);
  expect(JSON.parse(blocked.stdout).items.find((row: any) => row.id === 'pr.sections')).toMatchObject({ state: 'blocked' });
  expect(text(refused)).toBe(before);
  expect(existsSync(join(refused.repo, '.github'))).toBe(false);
  expect(existsSync(join(refused.repo, 'scripts'))).toBe(false);
  const invalid = fixture(); const original = text(invalid);
  const invocation = spawnSync('bash', [script, 'apply', '--repo', invalid.repo, '--hatsu-root', invalid.root, '--slug', "fixture/consumer'", '--visibility', 'public', '--self-hosted', '0', '--json'], { encoding: 'utf8' });
  expect(invocation.status).toBe(2);
  expect(text(invalid)).toBe(original);
  expect(existsSync(join(invalid.repo, '.github'))).toBe(false);
});

test('released Nen schema and actual resolver accept stamps and every dollar-prefixed metadata key', () => {
  const nen = process.env.NEN;
  expect(nen, 'run the declared config-values-guard lane with its verified NEN binary').toBeTruthy();
  const f = fixture(); const cat = catalogue(f.root);
  f.write(defaults(cat));
  const stamped = join(f.repo, 'nen/workflow.json'); const unstamp = join(f.repo, 'unstamped.json');
  const value = workflow(f); delete value.pr.sections.$canon; writeFileSync(unstamp, json(value));
  const args = ['pr', 'sections', 'resolve', '--catalogue', join(f.root, 'contracts/pr-sections.json'), '--kind', 'process', '--family', 'build', '--json', '--overrides'];
  const before = spawnSync(nen!, [...args, unstamp], { encoding: 'utf8' });
  const after = spawnSync(nen!, [...args, stamped], { encoding: 'utf8' });
  expect(before.status, before.stderr).toBe(0); expect(after.status, after.stderr).toBe(0);
  expect(JSON.parse(after.stdout)).toEqual(JSON.parse(before.stdout));
  const metadata = workflow(f); metadata.pr.sections.$future = { arbitrary: true }; metadata.pr.sections.variants.$future = { ignored: true };
  writeFileSync(stamped, json(metadata));
  const extra = spawnSync(nen!, [...args, stamped], { encoding: 'utf8' });
  expect(extra.status, extra.stderr).toBe(0); expect(JSON.parse(extra.stdout)).toEqual(JSON.parse(before.stdout));
  const schema = spawnSync(nen!, ['schema', 'check', '--repo', f.repo], { encoding: 'utf8' });
  expect(schema.stdout + schema.stderr).toMatch(/nen\/workflow\.json.*ok|ok.*nen\/workflow\.json/);
});

test('HA#560 AC-1/AC-2/AC-3/SC-1: an unknown or newer pr.sections stamp reports that row alone without aborting diagnose', () => {
  const f = fixture();
  symlinkSync(join(ROOT, 'scripts'), join(f.root, 'scripts'), 'dir');
  const fullCatalogue = JSON.parse(readFileSync(join(ROOT, 'contracts/config-catalogue.json'), 'utf8'));
  fullCatalogue.values = fullCatalogue.values.filter((row: any) =>
    ['workflow.branch.base', 'workflow.branch.template', 'workflow.pr.sections', 'workflow.pr.sections.max'].includes(row.id));
  writeFileSync(join(f.root, 'contracts/config-catalogue.json'), json(fullCatalogue));

  const unknownSha = 'b'.repeat(64);
  f.write({ ...f.value, $canon: { contract: f.current.contract, sha256: unknownSha } });
  const before = text(f);

  const diagJson = run(f, 'diagnose', '--json');
  expect([0, 1], diagJson.stderr).toContain(diagJson.status);
  const parsed = JSON.parse(diagJson.stdout);
  expect(parsed.values.map((row: any) => row.id)).toEqual(
    expect.arrayContaining(['workflow.branch.base', 'workflow.branch.template', 'workflow.pr.sections', 'workflow.pr.sections.max']),
  );
  const prRow = parsed.values.find((row: any) => row.id === 'workflow.pr.sections');
  expect(prRow.state).not.toBe('blocked');
  expect(prRow.detail).toMatch(/newer or unknown/i);
  expect(prRow.detail).toMatch(/bakuryuha|update the Hatsu plugin/i);
  expect(prRow.prSections).toMatchObject({
    status: 'unknown-catalogue',
    stampedSha: unknownSha,
    stampedSha7: 'bbbbbbb',
    catalogueSha: f.current.documentSha256,
    catalogueSha7: f.current.documentSha256.slice(0, 7),
    cells: [],
  });
  expect(parsed.values.find((row: any) => row.id === 'workflow.branch.base').state).toBe('default-unwritten');

  const diagText = run(f, 'diagnose');
  expect([0, 1], diagText.stderr).toContain(diagText.status);
  expect(diagText.stdout).toContain('branch.base');
  expect(diagText.stdout).toMatch(/newer or unknown/i);
  expect(diagText.stdout).toMatch(/update the Hatsu plugin/i);
  expect(text(f)).toBe(before);

  const tenkaiScript = join(ROOT, 'scripts/tenkai_adopt.sh');
  const tenkaiDiag = spawnSync('bash', [tenkaiScript, 'diagnose', '--repo', f.repo, '--hatsu-root', f.root, '--slug', 'fixture/consumer', '--visibility', 'public', '--self-hosted', '0', '--json'], { encoding: 'utf8' });
  expect(tenkaiDiag.status, tenkaiDiag.stderr).toBe(1);
  const inbox = JSON.parse(tenkaiDiag.stdout);
  expect(inbox.items.find((row: any) => row.id === 'config/defaults').state).not.toBe('blocked');
  expect(inbox.items.find((row: any) => row.id === 'config/needed')).toBeTruthy();
  const sectionItem = inbox.items.find((row: any) => row.id === 'pr.sections');
  expect(sectionItem).toMatchObject({
    state: 'blocked',
    prSections: { status: 'unknown-catalogue', stampedSha7: 'bbbbbbb' },
    fix: { fill: 'route' },
  });
  expect(sectionItem.detail).toMatch(/newer or unknown/i);
  expect(sectionItem.fix.edit).toMatch(/bakuryuha|update the installed Hatsu plugin/i);

  // AC-3: refresh and apply write nothing.
  expect(run(f, 'fill', '--refresh', '--json').status).toBe(2);
  expect(text(f)).toBe(before);
  const tenkaiApply = spawnSync('bash', [tenkaiScript, 'apply', '--repo', f.repo, '--hatsu-root', f.root, '--slug', 'fixture/consumer', '--visibility', 'public', '--self-hosted', '0', '--json'], { encoding: 'utf8' });
  expect(tenkaiApply.status).toBe(1);
  expect(JSON.parse(tenkaiApply.stdout).items.find((row: any) => row.id === 'pr.sections').state).toBe('blocked');
  expect(text(f)).toBe(before);
  expect(existsSync(join(f.repo, '.github'))).toBe(false);
  expect(existsSync(join(f.repo, 'scripts'))).toBe(false);

  // Phinks QA-16: newer stamp with raised cap (max: 8) and newer contract version (v2) still classifies unknown-catalogue,
  // and malformed pr.sections leaves unrelated keys diagnosed cleanly.
  f.write({ max: 8, variants: clone(f.previous.variants), $canon: { contract: 'hatsu.pr-sections/v2', sha256: unknownSha } });
  const raisedCap = run(f, 'diagnose', '--json');
  expect([0, 1], raisedCap.stderr).toContain(raisedCap.status);
  const raisedParsed = JSON.parse(raisedCap.stdout);
  expect(raisedParsed.values.find((row: any) => row.id === 'workflow.branch.base').state).toBe('default-unwritten');
  expect(raisedParsed.values.find((row: any) => row.id === 'workflow.pr.sections').prSections.status).toBe('unknown-catalogue');

  f.write('oops');
  const malformedRow = run(f, 'diagnose', '--json');
  expect([0, 1], malformedRow.stderr).toContain(malformedRow.status);
  const malformedParsed = JSON.parse(malformedRow.stdout);
  expect(malformedParsed.values.find((row: any) => row.id === 'workflow.branch.base').state).toBe('default-unwritten');
  expect(malformedParsed.values.find((row: any) => row.id === 'workflow.pr.sections').detail).toMatch(/^pr\.sections: invalid/);

  // Feitan SEC-7: Object.prototype property names (e.g. toString) are never mistaken for catalogued cells.
  const protoVal: any = clone(f.value);
  protoVal.variants.toString = ['changes', 'why', 'improves', 'verify'];
  const protoReading = readSections(protoVal, catalogue(f.root), history(f.root, catalogue(f.root)));
  expect(protoReading.cells.find((c: any) => c.cell === 'toString')).toMatchObject({ state: 'retired', ownership: 'consumer-owned' });
});
