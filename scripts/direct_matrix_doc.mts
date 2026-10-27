#!/usr/bin/env node
/** HA341 compatible evidence bootstrap. The stable shell CLI forwards here.
 * Dated prices, benchmark task costs and served metadata are presentation evidence;
 * routing stays with pinned Nen, with offline page claims held to it by --verify.
 * snapshot.evidenceVersion defaults to 0: the trusted guard must land before activation.
 */
import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdtempSync, readFileSync, renameSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve as resolvePath } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REG_PATH = 'contracts/direct.registry.json';
const TAX_PATH = 'contracts/classify.taxonomy.json';
const WF_PATH = 'nen/workflow.json';
const CONTRACT_PATH = 'nen/contract.json';
const OUT_PATH = 'docs/DIRECT-MATRIX.md';
const SCRIPT = join(dirname(fileURLToPath(import.meta.url)), 'direct_matrix_doc.sh');
const FOOTER_OLD = 'Agreement with the verb is proved when `--verify` runs; staleness is caught when the lane runs. Neither ' +
  'runs on its own in CI yet (zheref/hatsu#234). A routing change is a registry edit through a PR, never an edit here; ' +
  'changing what an alias **means** is a maintainer ruling ([`ROSTER.md`](ROSTER.md) § *Rulings of ' +
  '2026-10-04 — classify and direct*).';
const FOOTER_INSTALLED = 'Agreement with the verb is proved when `--verify` runs; staleness is caught both by the lane and by ' +
  'the trusted `surface-mirror-check.yml` PR check, including on data-only edits (zheref/hatsu#234). ' +
  'A routing change is a registry edit through a PR, never an edit here; ' +
  'changing what an alias **means** is a maintainer ruling ([`ROSTER.md`](ROSTER.md) § *Rulings of ' +
  '2026-10-04 — classify and direct*).';

type JsonRecord = Record<string, unknown>;
type Alias = { provider: string; family: string; line?: string | null; surface: string | null; tier: string | null;
  reviewer: boolean; selection: string; escalation?: string | null };
type Surface = { label: string; modelsKey: string; restart: string; effortControl: string; lookup: string; interactive: string };
type NonActionable = { label: string; provider?: string; what: string; lookup: string };
type ListPrice = { input: number; output: number; unit: string; source: string; readOn: string; note?: string;
  until?: string; next?: { input: number; output: number; from: string } };
type Served = string | { id: string | null; readOn: string; lag: string | null; quota: string | null };
type CostPerTask = { value: number; unit: string; basis: string; url: string; readOn: string };
type SnapshotSource = { url: string; readOn: string; costPerTask?: CostPerTask };
type SnapshotAlias = { primary: string; modelId: string | null; fallback: string;
  listPrice?: ListPrice; served?: Record<string, Served>; evidence?: string };
type Side = { alias: string; surface?: string | null; also?: string; interactive?: string | null; note?: string | null };
type Cell = { winner: Side; runnerUp: Side };
type Route = { cells: Record<string, Cell>; phase: string; phaseName: string; alsoPhases?: string[] };
type Job = { key: string; title: string; phases: string[]; weight: number; companion: boolean };
type Lang = { key: string; code: boolean };
type Predicate = { anyOf: Predicate[] } | { repoKind: string[] } | { repoRole: string[] } |
  { issueLabels: { any: string[] } } | { jobs: { anyKey: string[] } | { nonEmpty: true; everyListsOnly: string } };
type DomainRule = { order: number; domain: string; when: 'otherwise' | Predicate; comment: string };
type Example = { title?: string; kind: string; role: string | null; labels: string[]; lang: string[]; job: string[] };
type Result = { undirectable: false; domain: string; winner: string; runner: string | null; weight: number;
  adds: string[]; effort: string; recommended: string; aggFallback: string | null } | { undirectable: true };
type Claim = { t: 'unreachable'; job: string; d: string } |
  { t: 'grid'; job: string; d: string; lang: string; routed: string; winner: string } |
  { t: 'cell'; job: string; d: string; lang: string; routed: string; phase: string; winner: string; runnerUp: string; extra: string[] } |
  { t: 'effort'; job: string; aigov: boolean; level: string } |
  { t: 'example'; ex: Example; domain: string; winner: string; runnerUp: string | null; effort: string; restart: string };
type Registry = {
  aliases: Record<string, Alias>; surfaces: Record<string, Surface>; nonActionable: Record<string, NonActionable>; nonActionableComment: string;
  snapshot: { asOf: string; evidenceVersion: 0 | 1; aliases: Record<string, SnapshotAlias>; sources: Record<string, SnapshotSource> }; routing: Record<string, Record<string, Route>>;
  precedence: string[]; aggregationComment: string; levels: string[]; bands: Record<string, [number, number]>;
  surfaceMap: Record<string, Record<string, string>>; collapsed?: string; effortBase: string; plusOne: { key?: string; when: string }[];
  picks: { comment: string; primary: string; fallback: string; inPool: Record<string, string>; recommended: { describe: string; rule: string }; fallbackRule: string; tiers: string };
  companions: { comment: string; role: Record<string, string> }; sourceDigest: string; emptyJob: string;
  nativeInteractive: Record<string, string>; liveLookup: Record<string, { cli: string | null; effort?: string | null; docs: string[] }>;
};
type Taxonomy = { jobs: Job[]; langs: Lang[]; domains: string[]; rules: DomainRule[]; fallback: string; tablePrefix: Record<string, string> };

export class MatrixInputError extends Error {}
function refuse(message: string): never { throw new MatrixInputError(message); }
function record(value: unknown, at: string): JsonRecord {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) refuse(`${at}: expected an object`);
  return value as JsonRecord;
}
function field(value: JsonRecord, key: string): unknown { return Object.hasOwn(value, key) ? value[key] : undefined; }
function text(value: unknown, at: string): string {
  if (typeof value !== 'string') refuse(`${at}: expected a string`);
  return value;
}
function optionalText(value: unknown, at: string): string | undefined { return value === undefined ? undefined : text(value, at); }
function nullableText(value: unknown, at: string): string | null { return value === null ? null : text(value, at); }
function nonempty(value: unknown, at: string): string {
  const result = text(value, at); if (!result.trim()) refuse(`${at}: expected nonempty text`); return result;
}
function isoDate(value: unknown, at: string): string {
  const result = text(value, at);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(result) || !Number.isFinite(Date.parse(result)) || new Date(result).toISOString().slice(0, 10) !== result)
    refuse(`${at}: expected a real ISO date (YYYY-MM-DD)`);
  return result;
}
function number(value: unknown, at: string): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) refuse(`${at}: expected a finite number`);
  return value;
}
function cost(value: unknown, at: string): number {
  const result = number(value, at); if (result < 0) refuse(`${at}: expected a nonnegative number`); return result;
}
function bool(value: unknown, at: string, fallback = false): boolean {
  if (value === undefined) return fallback;
  if (typeof value !== 'boolean') refuse(`${at}: expected a boolean`);
  return value;
}
function array(value: unknown, at: string): unknown[] { if (!Array.isArray(value)) refuse(`${at}: expected an array`); return value; }
function strings(value: unknown, at: string): string[] { return array(value, at).map((v, i) => text(v, `${at}[${i}]`)); }
function entries(value: unknown, at: string): [string, unknown][] { return Object.entries(record(value, at)).filter(([k]) => !k.startsWith('$')); }
function mapRows<T>(value: unknown, at: string, parse: (value: unknown, at: string, key: string) => T): Record<string, T> {
  const result: Record<string, T> = Object.create(null);
  for (const [k, v] of entries(value, at)) result[k] = parse(v, `${at}.${k}`, k);
  return result;
}
function stringMap(value: unknown, at: string): Record<string, string> { return mapRows(value, at, text); }
function reference<T>(rows: Record<string, T>, key: string, at: string): T {
  if (!Object.hasOwn(rows, key)) refuse(`${at}: unknown reference ${JSON.stringify(key)}`);
  return rows[key];
}
function safeJson(value: unknown, at: string, depth = 0): void {
  if (depth > 100) refuse(`${at}: JSON nesting exceeds 100 levels`);
  if (typeof value === 'number' && !Number.isFinite(value)) refuse(`${at}: expected a finite number`);
  if (value === null || typeof value !== 'object') return;
  for (const [k, v] of Object.entries(value)) {
    if (['__proto__', 'constructor', 'prototype'].includes(k)) refuse(`${at}.${k}: reserved object key`);
    safeJson(v, `${at}.${k}`, depth + 1);
  }
}
function load(root: string, path: string): unknown {
  try {
    const result: unknown = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(readFileSync(join(root, path))));
    safeJson(result, path);
    return result;
  } catch (error) {
    if (error instanceof MatrixInputError) throw error;
    refuse(`${path}: ${error instanceof Error ? error.message : String(error)}`);
  }
}
function predicate(value: unknown, at: string, depth = 0): Predicate {
  if (depth > 50) refuse(`${at}: domain predicate nesting exceeds 50 levels`);
  const r = record(value, at);
  const keys = Object.keys(r).filter(k => k !== '$comment');
  if (keys.length !== 1) refuse(`${at}: domain rule predicate ${JSON.stringify(keys.sort())} is not one known shape`);
  switch (keys[0]) {
    case 'anyOf': return { anyOf: array(r.anyOf, `${at}.anyOf`).map((p, i) => predicate(p, `${at}.anyOf[${i}]`, depth + 1)) };
    case 'repoKind': return { repoKind: strings(r.repoKind, `${at}.repoKind`) };
    case 'repoRole': return { repoRole: strings(r.repoRole, `${at}.repoRole`) };
    case 'issueLabels': return { issueLabels: { any: strings(record(r.issueLabels, `${at}.issueLabels`).any, `${at}.issueLabels.any`) } };
    case 'jobs': {
      const j = record(r.jobs, `${at}.jobs`);
      if (Object.hasOwn(j, 'anyKey')) return { jobs: { anyKey: strings(j.anyKey, `${at}.jobs.anyKey`) } };
      if (j.nonEmpty === true) return { jobs: { nonEmpty: true, everyListsOnly: text(j.everyListsOnly, `${at}.jobs.everyListsOnly`) } };
      refuse(`${at}.jobs: jobs predicate is not one known shape`);
    }
    default: refuse(`${at}: domain rule predicate ${JSON.stringify(keys)} is not one known shape`);
  }
}
function parseRegistry(value: unknown): Registry {
  const r = record(value, REG_PATH);
  const aliases = mapRows(r.aliases, 'aliases', (v, at): Alias => {
    const a = record(v, at);
    return { provider: text(a.provider, `${at}.provider`), family: text(a.family, `${at}.family`),
      line: a.line === undefined ? undefined : nullableText(a.line, `${at}.line`), surface: nullableText(a.surface, `${at}.surface`),
      tier: nullableText(a.tier, `${at}.tier`), reviewer: bool(a.reviewer, `${at}.reviewer`),
      selection: text(a.selection, `${at}.selection`),
      escalation: a.escalation === undefined ? undefined : nullableText(a.escalation, `${at}.escalation`) };
  });
  const surfaces = mapRows(r.surfaces, 'surfaces', (v, at): Surface => {
    const s = record(v, at);
    return { label: text(s.label, `${at}.label`), modelsKey: text(s.modelsKey, `${at}.modelsKey`), restart: text(s.restart, `${at}.restart`),
      effortControl: text(s.effortControl, `${at}.effortControl`), lookup: text(s.lookup, `${at}.lookup`), interactive: text(s.interactive, `${at}.interactive`) };
  });
  const na = field(record(r.surfaces, 'surfaces'), '$nonActionable') ?? {};
  const nonActionable = mapRows(na, 'surfaces.$nonActionable', (v, at): NonActionable => {
    const n = record(v, at);
    return { label: text(n.label, `${at}.label`), provider: optionalText(n.provider, `${at}.provider`), what: text(n.what, `${at}.what`), lookup: text(n.lookup, `${at}.lookup`) };
  });
  const snapshot = record(r.snapshot, 'snapshot');
  const evidenceVersion = snapshot.evidenceVersion ?? 0;
  if (evidenceVersion !== 0 && evidenceVersion !== 1) refuse('snapshot.evidenceVersion: expected 0 (legacy) or 1 (dated evidence)');
  const sources = mapRows(snapshot.sources ?? {}, 'snapshot.sources', (v, at): SnapshotSource => {
    const s = record(v, at); let costPerTask: CostPerTask | undefined;
    if (s.costPerTask !== undefined) {
      const c = record(s.costPerTask, `${at}.costPerTask`); const cp = `${at}.costPerTask`;
      costPerTask = { value: cost(c.value, `${cp}.value`), unit: nonempty(c.unit, `${cp}.unit`), basis: nonempty(c.basis, `${cp}.basis`),
        url: nonempty(c.url, `${cp}.url`), readOn: isoDate(c.readOn, `${cp}.readOn`) };
    }
    return { url: nonempty(s.url, `${at}.url`), readOn: isoDate(s.readOn, `${at}.readOn`), costPerTask };
  });
  const snapshotAliases = mapRows(snapshot.aliases, 'snapshot.aliases', (v, at, name): SnapshotAlias => {
    reference(aliases, name, at);
    const s = record(v, at);
    let listPrice: SnapshotAlias['listPrice'];
    if (s.listPrice !== undefined && s.listPrice !== null) {
      const p = record(s.listPrice, `${at}.listPrice`);
      const pp = `${at}.listPrice`;
      listPrice = { input: cost(p.input, `${pp}.input`), output: cost(p.output, `${pp}.output`), unit: nonempty(p.unit, `${pp}.unit`),
        source: nonempty(p.source, `${pp}.source`), readOn: isoDate(p.readOn, `${pp}.readOn`), note: optionalText(p.note, `${pp}.note`) };
      if ((p.until === undefined) !== (p.next === undefined)) refuse(`${pp}: until and next must be supplied together`);
      if (p.until !== undefined) {
        listPrice.until = isoDate(p.until, `${pp}.until`); const next = record(p.next, `${pp}.next`);
        listPrice.next = { input: cost(next.input, `${pp}.next.input`), output: cost(next.output, `${pp}.next.output`), from: isoDate(next.from, `${pp}.next.from`) };
        if (listPrice.readOn > listPrice.until) refuse(`${pp}.until: precedes readOn ${listPrice.readOn}`);
        const followingDay = new Date(Date.parse(listPrice.until) + 86400000).toISOString().slice(0, 10);
        if (listPrice.next.from !== followingDay) refuse(`${pp}.next.from: must be the day after until ${listPrice.until}`);
      }
    }
    const served = s.served === undefined ? undefined : mapRows(s.served, `${at}.served`, (v, at): Served => {
      if (typeof v === 'string') return nonempty(v, at);
      const row = record(v, at);
      return { id: row.id === null ? null : nonempty(row.id, `${at}.id`), readOn: isoDate(row.readOn, `${at}.readOn`),
        lag: nullableText(row.lag, `${at}.lag`), quota: nullableText(row.quota, `${at}.quota`) };
    });
    for (const sk of Object.keys(served ?? {})) reference(surfaces, sk, `${at}.served`);
    const evidence = optionalText(s.evidence, `${at}.evidence`);
    if (evidence) {
      if (!evidence.startsWith('snapshot.sources.')) refuse(`${at}.evidence: expected a snapshot.sources reference`);
      reference(sources, evidence.slice('snapshot.sources.'.length), `${at}.evidence`);
    }
    return { primary: text(s.primary, `${at}.primary`), modelId: nullableText(s.modelId, `${at}.modelId`), fallback: text(s.fallback, `${at}.fallback`), listPrice, served, evidence };
  });
  for (const [name, a] of Object.entries(aliases)) {
    reference(snapshotAliases, name, 'snapshot.aliases');
    if (a.surface !== null) reference(surfaces, a.surface, `aliases.${name}.surface`);
    if (!a.reviewer && (a.surface === null || a.tier === null)) refuse(`aliases.${name}: an actionable alias needs a surface and tier`);
    if (a.escalation) reference(aliases, a.escalation, `aliases.${name}.escalation`);
  }
  function side(value: unknown, at: string): Side {
    const s = record(value, at); const name = text(s.alias, `${at}.alias`); const a = reference(aliases, name, `${at}.alias`);
    const also = optionalText(s.also, `${at}.also`);
    if (a.reviewer && !also) refuse(`${at}.also: a review bot needs an actionable alias`);
    if (also && reference(aliases, also, `${at}.also`).reviewer) refuse(`${at}.also: expected an actionable alias`);
    return { alias: name, also, surface: s.surface === undefined ? undefined : nullableText(s.surface, `${at}.surface`),
      interactive: s.interactive === undefined ? undefined : nullableText(s.interactive, `${at}.interactive`),
      note: s.note === undefined ? undefined : nullableText(s.note, `${at}.note`) };
  }
  const routing = mapRows(r.routing, 'routing', (v, at) => mapRows(v, at, (v, at): Route => {
    const row = record(v, at);
    const cells = mapRows(row.cells, `${at}.cells`, (v, at): Cell => {
      const c = record(v, at); return { winner: side(c.winner, `${at}.winner`), runnerUp: side(c.runnerUp, `${at}.runnerUp`) };
    });
    if (!Object.hasOwn(cells, '*')) refuse(`${at}.cells: missing shared '*' cell`);
    return { phase: text(row.phase, `${at}.phase`), phaseName: text(row.phaseName, `${at}.phaseName`), cells,
      alsoPhases: row.alsoPhases === undefined ? undefined : strings(row.alsoPhases, `${at}.alsoPhases`) };
  }));
  const agg = record(r.aggregation, 'aggregation'); const precedence = strings(agg.precedence, 'aggregation.precedence');
  if (new Set(precedence).size !== precedence.length || Object.keys(aliases).length !== precedence.length) refuse('aggregation.precedence: must rank every alias exactly once');
  for (const name of precedence) reference(aliases, name, 'aggregation.precedence');
  const effort = record(r.effort, 'effort'); const rule = record(effort.rule, 'effort.rule');
  const levels = strings(effort.levels, 'effort.levels');
  if (levels.length === 0 || new Set(levels).size !== levels.length) refuse('effort.levels: expected distinct nonempty levels');
  const bands = mapRows(rule.bands, 'effort.rule.bands', (v, at): [number, number] => {
    const b = array(v, at); if (b.length !== 2) refuse(`${at}: expected two bounds`);
    const lo = number(b[0], `${at}[0]`); const hi = number(b[1], `${at}[1]`);
    if (!Number.isInteger(lo) || !Number.isInteger(hi) || lo > hi) refuse(`${at}: expected ordered integer bounds`);
    return [lo, hi];
  });
  for (const level of levels) reference(bands, level, 'effort.rule.bands');
  const sm = record(effort.surfaceMap, 'effort.surfaceMap');
  const surfaceMap = mapRows(sm, 'effort.surfaceMap', stringMap);
  for (const [sk, values] of Object.entries(surfaceMap)) {
    reference(surfaces, sk, 'effort.surfaceMap');
    for (const level of levels) reference(values, level, `effort.surfaceMap.${sk}`);
  }
  for (const a of Object.values(aliases)) if (a.surface !== null) reference(surfaceMap, a.surface, 'effort.surfaceMap');
  const picks = record(r.picks, 'picks'); const rec = record(picks.recommended, 'picks.recommended');
  const inPool = stringMap(picks.inPool ?? {}, 'picks.inPool');
  for (const [primary, fallback] of Object.entries(inPool)) {
    const p = reference(aliases, primary, 'picks.inPool'); const f = reference(aliases, fallback, `picks.inPool.${primary}`);
    if (p.reviewer || f.reviewer || primary === fallback || p.provider !== f.provider || p.surface !== f.surface)
      refuse(`picks.inPool.${primary}: expected a distinct actionable alias on the same provider and surface`);
    if (inPool[fallback] !== undefined) refuse(`picks.inPool.${primary}: the quota substitute must be terminal, without another in-pool substitute`);
  }
  const companions = record(r.companions, 'companions');
  return { aliases, surfaces, nonActionable, nonActionableComment: optionalText(record(na, 'surfaces.$nonActionable').$comment, 'surfaces.$nonActionable.$comment') ?? '',
    snapshot: { asOf: isoDate(snapshot.asOf, 'snapshot.asOf'), evidenceVersion, aliases: snapshotAliases, sources }, routing, precedence,
    aggregationComment: text(agg.$comment, 'aggregation.$comment'), levels, bands, surfaceMap,
    collapsed: optionalText(sm.$collapsed, 'effort.surfaceMap.$collapsed'), effortBase: text(rule.base, 'effort.rule.base'),
    plusOne: array(rule.plusOne, 'effort.rule.plusOne').map((v, i) => { const p = record(v, `effort.rule.plusOne[${i}]`); return { key: optionalText(p.key, `effort.rule.plusOne[${i}].key`), when: text(p.when, `effort.rule.plusOne[${i}].when`) }; }),
    picks: { comment: text(picks.$comment, 'picks.$comment'), primary: text(picks.primary, 'picks.primary'), fallback: text(picks.fallback, 'picks.fallback'), inPool,
      recommended: { describe: text(rec.describe, 'picks.recommended.describe'), rule: text(rec.rule, 'picks.recommended.rule') },
      fallbackRule: text(picks.fallbackRule, 'picks.fallbackRule'), tiers: text(picks.tiers, 'picks.tiers') },
    companions: { comment: text(companions.$comment, 'companions.$comment'), role: stringMap(companions.role, 'companions.role') },
    sourceDigest: text(record(r.source, 'source').documentSha256, 'source.documentSha256'), emptyJob: text(record(r.emptyAxis, 'emptyAxis').job, 'emptyAxis.job'),
    nativeInteractive: stringMap(r.nativeInteractive, 'nativeInteractive'),
    liveLookup: mapRows(r.liveLookup, 'liveLookup', (v, at) => { const l = record(v, at); return { cli: nullableText(l.cli, `${at}.cli`),
      effort: l.effort === undefined ? undefined : nullableText(l.effort, `${at}.effort`), docs: strings(l.docs, `${at}.docs`) }; }) };
}
function parseTaxonomy(value: unknown): Taxonomy {
  const tax = record(value, TAX_PATH); const axes = record(tax.axes, 'axes'); const domain = record(tax.domains, 'domains');
  const jobs = array(record(axes.job, 'axes.job').keys, 'axes.job.keys').map((v, i): Job => {
    const at = `axes.job.keys[${i}]`; const j = record(v, at);
    return { key: text(j.key, `${at}.key`), title: text(j.title, `${at}.title`), phases: Object.keys(mapRows(j.phases, `${at}.phases`, strings)),
      weight: number(j.weight, `${at}.weight`), companion: bool(j.companion, `${at}.companion`) };
  });
  const langs = array(record(axes.lang, 'axes.lang').keys, 'axes.lang.keys').map((v, i): Lang => {
    const at = `axes.lang.keys[${i}]`; const l = record(v, at); return { key: text(l.key, `${at}.key`), code: bool(l.code, `${at}.code`, true) };
  });
  const domains = strings(domain.keys, 'domains.keys');
  for (const [name, keys] of [['job', jobs.map(j => j.key)], ['lang', langs.map(l => l.key)], ['domains', domains]] as const) {
    if (keys.length === 0 || new Set(keys).size !== keys.length) refuse(`${name}: expected distinct nonempty keys`);
  }
  const rules = array(domain.rule, 'domains.rule').map((v, i): DomainRule => {
    const at = `domains.rule[${i}]`; const r = record(v, at); const d = text(r.domain, `${at}.domain`);
    if (!domains.includes(d)) refuse(`${at}.domain: unknown domain ${JSON.stringify(d)}`);
    return { order: number(r.order, `${at}.order`), domain: d, comment: text(r.$comment, `${at}.$comment`),
      when: r.when === 'otherwise' ? 'otherwise' : predicate(r.when, `${at}.when`) };
  }).sort((a, b) => a.order - b.order);
  return { jobs, langs, domains, rules, fallback: text(domain.fallback, 'domains.fallback'), tablePrefix: stringMap(domain.tablePrefix, 'domains.tablePrefix') };
}

const DOT: Record<string, string> = { anthropic: '🟠', openai: '🟢', google: '🔵', cursor: '⚫' };
const PROVIDER_NAME: Record<string, string> = { anthropic: 'Anthropic', openai: 'OpenAI', google: 'Google', cursor: 'Cursor' };
const DOMAIN_NAME: Record<string, string> = { feature: 'Feature development', maintenance: 'Maintenance & operations', parity: 'Cross-platform parity', aigov: 'AI governance', library: 'Reusable library' };
const DOMAIN_SHORT: Record<string, string> = { feature: 'Feature', maintenance: 'Maintenance', parity: 'Parity', aigov: 'AI-gov', library: 'Library' };
const LANG_NAME: Record<string, string> = { swift: 'Swift', kotlin: 'Kotlin', typescript: 'TypeScript', csharp: 'C#', prose: 'Prose' };
const EXAMPLES: Example[] = [
  { title: 'A canon or skill change in Hatsu itself', kind: 'process', role: 'canon', labels: [], lang: ['prose'], job: ['prose-authoring'] },
  { title: 'A SwiftUI feature with its tests', kind: 'product', role: null, labels: [], lang: ['swift'], job: ['ui', 'implementation', 'unit-tests'] },
  { title: 'A TypeScript bug fix', kind: 'product', role: null, labels: ['bug'], lang: ['typescript'], job: ['bug-fix', 'unit-tests'] },
  { title: "Designing a Kotlin library's public API", kind: 'library', role: null, labels: [], lang: ['kotlin'], job: ['api-design'] },
  { title: 'A TypeScript library change and its docs', kind: 'library', role: null, labels: [], lang: ['typescript', 'prose'], job: ['implementation', 'documentation'] },
  { title: 'Porting a screen from Swift to Kotlin', kind: 'product', role: null, labels: [], lang: ['swift', 'kotlin'], job: ['parity', 'ui'] },
  { title: 'A repository-wide mechanical rename in C#', kind: 'product', role: null, labels: [], lang: ['csharp'], job: ['mechanical-edit'] },
  { title: 'A React component and its unit tests', kind: 'product', role: null, labels: [], lang: ['typescript'], job: ['ui', 'unit-tests'] },
  { title: 'A security threat model for a Swift feature', kind: 'product', role: null, labels: [], lang: ['swift'], job: ['security'] },
];
const FORCE: Record<string, [string, string | null, string[]]> = { aigov: ['process', null, []], library: ['library', null, []],
  maintenance: ['product', null, ['bug']], feature: ['product', null, []], parity: ['product', null, []] };
const esc = (x: string | number): string => String(x).replaceAll('|', '\\|');
const lookup = (rows: Record<string, string>, key: string): string | undefined => Object.hasOwn(rows, key) ? rows[key] : undefined;
const dname = (d: string): string => lookup(DOMAIN_NAME, d) ?? d;
const dshort = (d: string): string => lookup(DOMAIN_SHORT, d) ?? d;
const lname = (l: string): string => lookup(LANG_NAME, l) ?? l;
// Python's Unicode \w includes letters and numbers. Keep its original heading anchors.
const slug = (heading: string): string => heading.toLowerCase().replace(/[^\p{L}\p{N}_\- ]/gu, '').replaceAll(' ', '-');
const sameAlias = (x: Side, y: Side): boolean => x.alias === y.alias && x.also === y.also;
const equal = (a: unknown, b: unknown): boolean => JSON.stringify(a) === JSON.stringify(b);

export function createMatrix(root: string, options: { today?: string; workflowRoot?: string } = {}) {
  const reg = parseRegistry(load(root, REG_PATH)); const tax = parseTaxonomy(load(root, TAX_PATH));
  const today = isoDate(options.today ?? new Date().toISOString().slice(0, 10), 'today');
  const wf = record(load(options.workflowRoot ?? root, WF_PATH), WF_PATH);
  const rawModels = record(wf.models ?? {}, 'models');
  const models: Record<string, Record<string, string>> = Object.create(null);
  for (const key of new Set([...Object.values(reg.surfaces).map(s => s.modelsKey), 'roles'])) {
    const value = field(rawModels, key);
    if (value !== undefined) models[key] = stringMap(value, `models.${key}`);
  }
  const { aliases, surfaces, routing, precedence, bands, levels, surfaceMap, picks, companions, liveLookup } = reg;
  const snap = reg.snapshot; const { jobs, langs, domains, rules } = tax;
  const evidenceEnabled = snap.evidenceVersion === 1;
  const jobByKey = Object.fromEntries(jobs.map(j => [j.key, j])); const langKeys = langs.map(l => l.key);
  const codeLang = Object.fromEntries(langs.map(l => [l.key, l.code])); const surfaceKeys = Object.keys(surfaces);
  const companionJobs = jobs.filter(j => j.companion).map(j => j.key);
  const actionable = precedence.filter(a => !aliases[a].reviewer);
  const escalations = actionable.filter(a => aliases[a].tier === 'frontier');
  for (const j of jobs) if (!Object.hasOwn(routing, j.key)) refuse(`job '${j.key}' has no routing row in ${REG_PATH}`);
  for (const d of domains) { reference(FORCE, d, 'domains.keys'); reference(tax.tablePrefix, d, 'domains.tablePrefix'); }
  for (const [j, doms] of Object.entries(routing)) {
    if (!Object.hasOwn(jobByKey, j)) refuse(`routing.${j}: unknown job`);
    for (const [d, row] of Object.entries(doms)) {
      if (!domains.includes(d)) refuse(`routing.${j}.${d}: unknown domain`);
      for (const l of Object.keys(row.cells)) if (l !== '*' && !langKeys.includes(l)) refuse(`routing.${j}.${d}.cells.${l}: unknown language`);
    }
  }
  if (!tax.fallback.includes(':')) refuse('domains.fallback has no colon to read the order after');
  const tail = tax.fallback.slice(tax.fallback.indexOf(':') + 1);
  const positions = domains.map(d => {
    const escaped = d.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return { d, at: tail.search(new RegExp(`\\b${escaped}\\b`, 'u')) };
  });
  const fbOrder = positions.filter(p => p.at >= 0).sort((a, b) => a.at - b.at).map(p => p.d);
  function typed(alias: string): string | null {
    const a = reference(aliases, alias, 'alias');
    if (a.surface === null) return null;
    const m = models[surfaces[a.surface].modelsKey]; return m && a.tier !== null ? m[a.tier] ?? null : null;
  }
  function label(alias: string, surface = false): string {
    const a = aliases[alias]; if (a.reviewer) return `🔍 ${snap.aliases[alias].primary}`;
    let s = `${lookup(DOT, a.provider) ?? '⚪'} \`${typed(alias) || 'unspelled'}\``;
    if (surface) s += ` · ${surfaces[a.surface!].label}`;
    return s;
  }
  function cellText(c: Side, surface = false): string { return label(c.alias, surface) + (c.also ? ` → ${label(c.also, surface)}` : ''); }
  function effective(c: Side): string { return aliases[c.alias].reviewer ? c.also! : c.alias; }
  function band(score: number): string {
    for (const lvl of levels) { const [lo, hi] = bands[lvl]; if (lo <= score && score <= hi) return lvl; }
    refuse(`effort score ${score} falls in no band of effort.rule.bands`);
  }
  function cellFor(job: string, dom: string, lang: string): Cell { const cells = routing[job][dom].cells; return cells[lang] ?? cells['*']; }
  function routeDomain(job: string, dom: string): string {
    for (const d of [dom, ...fbOrder]) if (Object.hasOwn(routing[job], d)) return d;
    refuse(`job ${job} routes in no domain of the fallback order`);
  }
  function match(w: Predicate, kind: string, role: string | null, labels: string[], jl: string[]): boolean {
    if ('anyOf' in w) return w.anyOf.some(x => match(x, kind, role, labels, jl));
    if ('repoKind' in w) return w.repoKind.includes(kind);
    if ('repoRole' in w) return role !== null && w.repoRole.includes(role);
    if ('issueLabels' in w) return w.issueLabels.any.some(pat => labels.some(l => l === pat || (pat.startsWith('*:') && l.endsWith(pat.slice(1)) && l.length > pat.length - 1)));
    if ('anyKey' in w.jobs) return w.jobs.anyKey.some(x => jl.includes(x));
    const only = w.jobs.everyListsOnly;
    return jl.length > 0 && jl.every(x => { const phases = reference(jobByKey, x, 'jobs').phases; return new Set(phases).size === 1 && phases.includes(only); });
  }
  function deriveDomain(kind: string, role: string | null, labels: string[], jl: string[]): string {
    for (const row of rules) if (row.when === 'otherwise' || match(row.when, kind, role, labels, jl)) return row.domain;
    refuse("no domain rule matched and the taxonomy names no 'otherwise' row");
  }
  const full = jobs.filter(j => Object.keys(routing[j.key]).length === domains.length).map(j => j.key);
  function reach(k: string, d: string): string[] | null {
    const [kind, role, labels] = FORCE[d]; const jl = d !== 'parity' || k === 'parity' ? [k] : ['parity', k];
    if (deriveDomain(kind, role, labels, jl) === d) return jl;
    const comp = full.find(x => x !== k); if (!comp) refuse('no job routes in every domain, so a companion job cannot be chosen');
    const more = [...jl, comp]; return deriveDomain(kind, role, labels, more) === d ? more : null;
  }
  function unreachInputs(k: string, d: string): string[][] {
    const base = d !== 'parity' || k === 'parity' ? [k] : ['parity', k];
    return [base, ...full.filter(c => c !== k).slice(0, 1).map(c => [...base, c])];
  }
  function rank(tally: Map<string, number>): string[] { return [...tally.keys()].sort((a, b) => tally.get(b)! - tally.get(a)! || precedence.indexOf(a) - precedence.indexOf(b)); }
  function aggregate(pairs: Cell[]): [string, string | null] {
    const tally = new Map<string, number>(); for (const c of pairs) { const a = effective(c.winner); tally.set(a, (tally.get(a) ?? 0) + 1); }
    const ranked = rank(tally); if (ranked.length === 0) refuse('no actionable winner in routing pairs');
    const winner = ranked[0]; if (ranked.length > 1) return [winner, ranked[1]];
    const rt = new Map<string, number>(); for (const c of pairs) { const a = effective(c.runnerUp); if (a !== winner) rt.set(a, (rt.get(a) ?? 0) + 1); }
    return [winner, rank(rt)[0] ?? null];
  }
  function samePool(a: string, b: string): boolean { return aliases[a].provider === aliases[b].provider && aliases[a].surface === aliases[b].surface; }
  function aggFallback(pairs: Cell[], winner: string, runner: string | null): string | null {
    if (runner && !samePool(winner, runner)) return runner;
    const pool = new Set(pairs.flatMap(c => [effective(c.winner), effective(c.runnerUp)]));
    return [...pool].filter(a => !samePool(winner, a)).sort((a, b) => precedence.indexOf(a) - precedence.indexOf(b))[0] ?? null;
  }
  function recommended(primary: string, maxWeight: number, level: string): string { const up = aliases[primary].escalation; return up && (maxWeight === 4 || level === 'max') ? up : primary; }
  function resolve(ex: Example): Result {
    if (ex.job.length === 0) return { undirectable: true };
    const dom = deriveDomain(ex.kind, ex.role, ex.labels, ex.job);
    const ls = [...new Set((ex.lang.length ? ex.lang : ['prose']).map(l => l === 'prose' ? '*' : l))];
    const pairs = ex.job.flatMap(j => ls.map(l => cellFor(j, routeDomain(j, dom), l)));
    const [winner, runner] = aggregate(pairs); const weight = Math.max(...ex.job.map(j => reference(jobByKey, j, 'job').weight));
    const adds: string[] = [];
    if (ex.job.length >= 3) adds.push('three or more jobs');
    if (ex.lang.filter(l => codeLang[l] ?? true).length >= 2) adds.push('two or more code languages');
    if (dom === 'aigov') adds.push('aigov domain');
    const level = band(weight + adds.length);
    return { undirectable: false, domain: dom, winner, runner, weight, adds, effort: level, recommended: recommended(winner, weight, level), aggFallback: aggFallback(pairs, winner, runner) };
  }
  function resolved(ex: Example) { const r = resolve(ex); if (r.undirectable) refuse('a printed example has no job'); return r; }
  function fallbackOk(c: Cell): boolean { return !samePool(effective(c.winner), effective(c.runnerUp)); }
  // :g in the old renderer uses six significant digits. Current prices use at most three.
  function general(n: number): string {
    const rounded = Number(n.toPrecision(6));
    if (rounded !== 0 && (Math.abs(rounded) < 0.0001 || Math.abs(rounded) >= 1e6)) return rounded.toExponential().replace(/e([+-])(\d)$/, 'e$10$2');
    return String(rounded);
  }
  function price(alias: string): string {
    const lp = snap.aliases[alias].listPrice;
    if (!lp) return '—';
    let result = `$${general(lp.input)} / $${general(lp.output)}`;
    if (evidenceEnabled && lp.next) result += ` through ${lp.until}; $${general(lp.next.input)} / $${general(lp.next.output)} from ${lp.next.from}`;
    return result;
  }
  function priceFindings(): string[] {
    if (!evidenceEnabled) return [];
    return actionable.flatMap(alias => {
      const lp = snap.aliases[alias].listPrice;
      return lp?.until && lp.until < today ? [
        `${alias}: listPrice.until ${lp.until} has passed as of ${today}; refresh the stored price from next (from ${lp.next!.from}) and remove or advance until/next before regenerating`
      ] : [];
    });
  }
  function taskCost(alias: string): CostPerTask | undefined {
    const ref = snap.aliases[alias].evidence;
    return ref ? snap.sources[ref.slice('snapshot.sources.'.length)].costPerTask : undefined;
  }
  function servedRows(alias: string) {
    return Object.entries(snap.aliases[alias].served ?? {}).map(([surface, row]) => {
      if (typeof row === 'string') return { surface, id: row, readOn: null, lag: null, quota: null, legacy: true,
        line: `served ${surfaces[surface].label}: ${row} (legacy snapshot text; separate lag and quota unread)` };
      return { surface, ...row, legacy: false,
        line: `served ${surfaces[surface].label}: ${row.id ?? 'id unread'} · snapshot ${row.readOn} · lag: ${row.lag ?? 'none recorded'} · quota: ${row.quota ?? 'unread'}` };
    });
  }
  function restartWarning(alias: string, product?: string): string | null {
    if (!product) return null;
    const target = product.trim().replace(/\s+/g, ' ').toLowerCase();
    const unavailable = servedRows(alias).find(row => row.surface === aliases[alias].surface && row.lag &&
      row.lag.toLowerCase().match(/not served on ([^:;\n.]+)/)?.[1]?.trim().replace(/\s+/g, ' ') === target);
    return unavailable ? `not served on ${product.trim()} as of ${unavailable.readOn}` : null;
  }
  function restart(alias: string, level: string): string {
    const a = aliases[alias]; const sk = a.surface!; const dial = surfaceMap[sk][level];
    return surfaces[sk].restart.replaceAll('<alias>', typed(alias) || '<alias>').replaceAll('<level>', dial);
  }
  function evidenceRow(alias: string, level: string, product?: string) {
    const a = reference(aliases, alias, 'evidence.alias');
    if (a.reviewer) refuse(`evidence.alias: ${alias} is a reviewer, not an actionable pick`);
    const spelled = typed(alias);
    if (!spelled) refuse(`models.${surfaces[a.surface!].modelsKey}.${a.tier}: a typed alias is required for ${alias}`);
    const lp = snap.aliases[alias].listPrice; const task = taskCost(alias); const substitute = picks.inPool[alias];
    return { alias, surface: a.surface, typedAlias: spelled, snapshotAsOf: snap.asOf,
      price: lp ? { ...lp, line: `${price(alias)} · ${lp.unit} · snapshot ${lp.readOn} · ${lp.source}` } : null,
      costPerTask: task ? { ...task, line: `$${general(task.value)} ${task.unit} · snapshot ${task.readOn} · basis: ${task.basis} · ${task.url}` } : null,
      served: servedRows(alias), restart: restart(alias, level), restartWarning: restartWarning(alias, product),
      inPool: substitute ? { alias: substitute, typedAlias: typed(substitute), surface: aliases[substitute].surface,
        line: `in-pool: ${substitute} (${typed(substitute) ?? 'unspelled'}); quota-only substitute for ${alias}, only after its own availability and quota are read` } : null };
  }
  function verdictEvidence(primary: string, fallback: string | null, rec: string, level: string, product?: string) {
    if (!evidenceEnabled) refuse('snapshot.evidenceVersion: dated evidence is not activated; the trusted bootstrap must merge before the registry opts in');
    if (!levels.includes(level)) refuse(`evidence.effort: unknown level ${JSON.stringify(level)}`);
    const rows = { primary: evidenceRow(primary, level, product), fallback: fallback ? evidenceRow(fallback, level, product) : null,
      recommended: evidenceRow(rec, level, product) };
    if (fallback && samePool(primary, fallback)) refuse('evidence.fallback: expected the cross-provider or cross-surface fallback, not an in-pool substitute');
    return { snapshotAsOf: snap.asOf, costBasis: picks.comment, product: product ?? null, ...rows };
  }
  function render(): { page: string; claims: Claim[] } {
    const o: string[] = []; const claims: Claim[] = []; const w = (s: string): void => { o.push(s); };
    const nRoutes = Object.values(routing).reduce((n, v) => n + Object.keys(v).length, 0);
    const nCells = Object.values(routing).flatMap(v => Object.values(v)).reduce((n, r) => n + Object.keys(r.cells).length, 0);
    const H = { how: 'How a recommendation is made', models: `The models — ${precedence.length} aliases`,
      picks: 'Primary, fallback, recommended — the three picks', grid: 'The grid — every job in every domain',
      domain: 'Which domain am I in?', matrix: 'Job × language — one matrix per domain', effort: 'How hard — the effort rule',
      agg: 'Several jobs or languages on one issue', examples: 'Worked examples', surfaces: 'Surfaces, restart lines and interactive equivalents',
      versions: 'Where the version comes from', sync: 'Keeping this page true' };
    w('# Direct — the model matrix'); w('');
    w('<!-- GENERATED by scripts/direct_matrix_doc.sh from contracts/direct.registry.json, ' +
      'contracts/classify.taxonomy.json and nen/workflow.json -> models. Do not edit by hand: ' +
      'change the data, then run `bash scripts/direct_matrix_doc.sh --write`. -->'); w('');
    w(`> **Which model will \`hatsu:direct\` pick for my work — without running it?** Find the issue's job ` +
      `in [the grid](#${slug(H.grid)}), read across to its domain, and that is the model, the surface it ` +
      'runs on and what you type. The tables and rule text on this page are rendered from the same data ' +
      '`nen direct resolve` reads, and `--verify` asks the verb about every cell, level and example printed here.'); w('');
    w(`Snapshot **${snap.asOf}** · ${jobs.length} jobs · ${domains.length} domains · ${nRoutes} job × ` +
      `domain routes · ${nCells} cells · source digest \`${reg.sourceDigest.slice(0, 12)}…\` · ` +
      'skills: [`classify`](../claude/skills/classify/SKILL.md), [`direct`](../claude/skills/direct/SKILL.md)'); w('');
    w('## Contents'); w(''); for (const h of Object.values(H)) w(`- [${h}](#${slug(h)})`); w('');
    w(`## ${H.how}`); w(''); w('```');
    w('issue labels ──► lang/<key> + job/<key>        (hatsu:classify writes them)');
    w('repo kind/role + issue labels + jobs ──► domain (first matching rule wins)');
    w('(job, domain, language) ──► routing cell       (winner + runner-up, each an ALIAS)');
    w('alias ──► provider · model family · surface · tier ──► the name you type');
    w('job weights + counts + domain ──► effort       (' + levels.join(' | ') + ')'); w('```'); w('');
    w('1. **Two labels decide it.** `lang/` is what the work is written in (`' + langKeys.join('`, `') +
      `\`); \`job/\` is the kind of work (${jobs.length} keys, below). \`hatsu:classify\` applies them; \`direct\` only reads them.`);
    w("2. **The domain is derived, never labelled** — from the repository's kind and role, the issue's " +
      `labels and its jobs ([rules](#${slug(H.domain)})).`);
    w('3. **One cell per (job, language), three picks.** Every cell names a *winner* — the **primary**, the ' +
      'cost-aligned best — and a *runner-up* — the **fallback**, on another provider or surface; the ' +
      `**recommended** (cost-agnostic) pick follows by rule ([the three picks](#${slug(H.picks)})). A language ` +
      'column only exists in the data where that language is routed differently; otherwise the shared `*` ' +
      'cell applies (and `prose` always reads `*`).');
    w('4. **An alias is stable; a version is not.** The alias names a provider, a model line, a model family, ' +
      'the Hatsu surface it runs on and its tier. The name you type comes from `nen/workflow.json` → ' +
      '`models.<modelsKey>.<tier>` (`claude`, `codex`, `cursor`, `antigravity`); the newest version and the ' +
      'effort dial are read live when `direct` runs, with the dated snapshot below as the fallback.');
    w('5. **No `job/` label, no recommendation** — `emptyAxis.job`: *' + reg.emptyJob + '*'); w('');
    w('*This walkthrough is a hand-written summary; every section below it is rendered from the data.*'); w('');
    w(`## ${H.models}`); w('');
    w(`Model versions are the snapshot of **${snap.asOf}**; \`direct\` reports the newest live version of the ` +
      "same family when it can read one. *You type* is Hatsu's own `models` spelling — a consumer repository " +
      'may spell a tier differently in its own `nen/workflow.json`.'); w('');
    w('| | Alias | Provider · line | Family | Surface | You type | Escalation | List price in / out | Model (snapshot) | If unavailable | What it is for |');
    w('|---|---|---|---|---|---|---|---|---|---|---|');
    for (const name of precedence) {
      const a = aliases[name]; const s = snap.aliases[name]; const dot = a.reviewer ? '🔍' : lookup(DOT, a.provider) ?? '⚪';
      const surf = a.surface ? surfaces[a.surface].label : 'PR review bot'; const t = typed(name);
      const tt = t ? `\`${t}\` (tier \`${a.tier}\`)` : '—'; const mid = s.modelId ? ` \`${s.modelId}\`` : '';
      const line = a.line ? `${a.provider} · \`${a.line}\`` : a.provider;
      const up = a.escalation ? `\`${a.escalation}\`` : a.tier === 'frontier' ? '*(a frontier alias)*' : '—';
      w(`| ${dot} | \`${name}\` | ${line} | \`${a.family}\` | ${surf} | ${tt} | ${up} | ${price(name)} | **${esc(s.primary)}**${mid} | ` +
        `${esc(s.fallback)} | ${esc(a.selection)} |`);
    }
    w(''); const providers = [...new Set(precedence.filter(n => !aliases[n].reviewer).map(n => aliases[n].provider))];
    if (evidenceEnabled) {
      w('Legend: ' + providers.map(p => `${lookup(DOT, p) ?? '⚪'} ${lookup(PROVIDER_NAME, p) ?? p}`).join(' · ') +
      ' · 🔍 a PR review bot — never a session recommendation; where one wins a cell, the actionable alias ' +
      'after its arrow is what you run. Row order is the tie-break `precedence`. **Price** is the input/output ' +
      'snapshot in USD per million tokens: each row keeps its own `readOn`, source and unit in the registry. ' +
      '`until` includes its date; `next` prints the following price and `from` date. An expired stored price ' +
      'fails the self-test and CI drift check; it is refreshed by a registry PR before this page is regenerated. ' +
      '**Cost per task** below carries a benchmark value, unit, basis, source URL and read date; it is a ' +
      'different measure from list price, with the deep-tier tie basis stated under the three picks. ' +
      '**Served** names the id, read date, lag and quota per pick. Legacy served strings remain readable with ' +
      'their separate lag/quota marked unread. A lag explicitly saying `not served on <product>` attaches ' +
      '`not served on <product> as of <readOn>` beside the restart for that session product; unobserved ' +
      'availability is not an outage. These are dated observations, never current quota balances. The frontier aliases (' + escalations.map(a => `\`${a}\``).join(', ') +
      ') are reached only as the *recommended* pick, for **your own** session, never for a subagent.'); w('');
    } else {
      // The first landing is judged by main's old trusted renderer. Keep its output exact.
      w('Legend: ' + providers.map(p => `${lookup(DOT, p) ?? '⚪'} ${lookup(PROVIDER_NAME, p) ?? p}`).join(' · ') +
        ' · 🔍 a PR review bot — never a session recommendation; where one wins a cell, the actionable alias ' +
        'after its arrow is what you run. Row order is the tie-break `precedence`. List prices are the snapshot ' +
        `of **${snap.asOf}** in USD per million tokens, each row\'s source in the registry — evidence for the ` +
        "cost-aligned ordering, never today's price. The frontier aliases (" + escalations.map(a => `\`${a}\``).join(', ') +
        ') are reached only as the *recommended* pick, for **your own** session, never for a subagent.'); w('');
    }
    const taskCosts = evidenceEnabled ? actionable.filter(n => taskCost(n)) : [];
    if (taskCosts.length) {
      w('Cost per task (dated benchmark observations; repository-specific estimates and ranges remain unestimated where the basis says so):'); w('');
      w('| Alias | Cost per task | Basis / method | Source / read on |'); w('|---|---|---|---|');
      for (const n of taskCosts) { const t = taskCost(n)!; w(`| \`${n}\` | $${general(t.value)} ${esc(t.unit)} | ${esc(t.basis)} | ${esc(t.url)} · ${t.readOn} |`); }
      w('');
    }
    const served = actionable.filter(n => Object.keys(snap.aliases[n].served ?? {}).length > 0);
    if (served.length) {
      if (evidenceEnabled) {
        w('What each surface lookup served (each structured row has its own read date; a legacy row keeps its original text):'); w('');
        w('| Alias | Surface | Served id | Read on | Lag | Quota |'); w('|---|---|---|---|---|---|');
        for (const n of served) for (const row of servedRows(n)) w(`| \`${n}\` | ${surfaces[row.surface].label} | ${esc(row.id ?? 'id unread')} | ${row.readOn ?? 'legacy text'} | ${esc(row.legacy ? 'unread; see served text' : row.lag ?? 'none recorded')} | ${esc(row.quota ?? 'unread')} |`);
      } else {
        w(`What each surface's own lookup served on ${snap.asOf} (the alias you type resolves to this id, which may lag the provider's newest):`); w('');
        w('| Alias | Surface | Served id |'); w('|---|---|---|');
        for (const n of served) for (const [sk, row] of Object.entries(snap.aliases[n].served!)) w(`| \`${n}\` | ${surfaces[sk].label} | ${esc(typeof row === 'string' ? row : row.id ?? 'id unread')} |`);
      }
      w('');
    }
    w(`## ${H.picks}`); w(''); w(`> ${picks.comment}`); w('');
    w('| Pick | What it is | Where it comes from |'); w('|---|---|---|');
    w(`| **primary** | ${esc(picks.primary)} | the cell's \`winner\`, \`nen direct resolve\`'s winner |`);
    w(`| **fallback** | ${esc(picks.fallback)} | the cell's \`runnerUp\`, the verb's runner-up |`);
    w(`| **recommended** | ${esc(picks.recommended.describe)} | ${esc(picks.recommended.rule)} |`); w('');
    w(`\`picks.fallbackRule\`: *${esc(picks.fallbackRule)}*`); w('');
    if (evidenceEnabled && Object.keys(picks.inPool).length) {
      w('Quota-only substitutes appear as `in-pool: <alias>` beside the fallback row, while the cross-provider fallback stays in place. Read the substitute\'s own availability and quota before use:'); w('');
      w('| Pick alias | In-pool substitute | Scope |'); w('|---|---|---|');
      for (const [n, substitute] of Object.entries(picks.inPool)) w(`| \`${n}\` | in-pool: \`${substitute}\` (${label(substitute, true)}) | quota-only; separate availability/quota unread until checked |`);
      w('');
    }
    w('What each primary escalates to when the rule fires:'); w(''); w('| Primary | Recommended on a weight-4 job or a `max` effort |'); w('|---|---|');
    for (const a of actionable) { const up = aliases[a].escalation; w(`| ${label(a, true)} | ` + (up ? label(up, true) : 'itself — nothing above it') + ' |'); }
    w(''); w(`\`picks.tiers\`: *${esc(picks.tiers)}*`); w('');
    w('**Companion jobs** (`companion: true` in the taxonomy): ' + companionJobs.map(j => `\`${j}\``).join(', ') + `. ${esc(companions.comment)}`); w('');
    w("| Companion job | Runs on the primary's surface at |"); w('|---|---|');
    for (const [j, role] of Object.entries(companions.role)) { const tier = models.roles?.[role]; w(`| \`${j}\` | \`models.roles.${role}\`` + (tier ? ` → tier \`${tier}\`` : '') + ' |'); }
    w(''); w(`## ${H.grid}`); w('');
    w("The **winner** of each job's own cell — for every language, unless a language is named beneath it " +
      'with its own winner. *↪ italics* means the job has no phase in that domain and borrows the route of ' +
      `the domain named. *—* means no issue can put that job in that domain: the [domain rules](#${slug(H.domain)}) ` +
      "decide before the job does. *Effort alone* is that job's level when it is the issue's only job " +
      '(and in AI governance, where the domain adds one). Runner-ups are in ' + `[the job × language matrices](#${slug(H.matrix)}).`); w('');
    const key = precedence.filter(n => !aliases[n].reviewer).map(n => `${label(n)} **${snap.aliases[n].primary}** on ${surfaces[aliases[n].surface!].label}`);
    w('**Key** — ' + key.join(' · ')); w('');
    w('| Job | ' + domains.map(dshort).join(' | ') + ' | Weight | Effort alone |'); w('|' + '---|'.repeat(domains.length + 3));
    const aigovAdd = reg.plusOne.some(p => p.key === 'aigov');
    for (const j of jobs) {
      const k = j.key; const row = [`**\`${k}\`**<br><sub>${esc(j.title)}</sub>`];
      for (const d of domains) {
        if (reach(k, d) === null) { row.push('—'); claims.push({ t: 'unreachable', job: k, d }); continue; }
        const rd = routeDomain(k, d); const r = routing[k][rd]; const starW = r.cells['*'].winner; let txt = cellText(starW);
        if (rd !== d) txt = `*↪ ${dshort(rd).toLowerCase()}: ${txt}*`;
        for (const l of langKeys) {
          let shown = starW; const lc = l !== 'prose' ? r.cells[l] : undefined;
          if (lc && !sameAlias(lc.winner, starW)) { shown = lc.winner; txt += `<br><sub>${lname(l)}: ${cellText(shown)}</sub>`; }
          claims.push({ t: 'grid', job: k, d, lang: l, routed: rd, winner: effective(shown) });
        }
        row.push(txt);
      }
      const wt = j.weight; const e1 = band(wt); const e2 = aigovAdd ? band(wt + 1) : e1;
      claims.push({ t: 'effort', job: k, aigov: false, level: e1 }, { t: 'effort', job: k, aigov: true, level: e2 });
      row.push(String(wt), e1 === e2 ? e1 : `${e1} · ${e2} in AI-gov`); w('| ' + row.join(' | ') + ' |');
    }
    w(''); w(`## ${H.domain}`); w(''); w('Rules are checked in `order`; **the first match wins** (`domains.rule`).'); w('');
    w('| # | Domain | When |'); w('|---|---|---|'); for (const r of rules) w(`| ${r.order} | **${dname(r.domain)}** (\`${r.domain}\`) | ${esc(r.comment)} |`);
    w(''); w(`\`domains.fallback\`: *${tax.fallback}*`); w(''); w(`## ${H.matrix}`); w('');
    w(`The registry's routing is keyed **(job, domain, language)** — ${domains.length} tables, one per domain, ` +
      "each varying by language. Pick your domain, find your job's row, read your language's column. " +
      "Each cell is that pair's **winner**, then its runner-up, then the interactive tool the source prefers " +
      'where it names one. A **bold** winner is routed for that language specifically, unlike the shared ' +
      'cell. A row in *↪ italics* has no phase in this domain and borrows the route of the domain named — ' +
      "you meet it when the issue's other jobs put it in this domain. `prose` always reads the shared cell."); w('');
    for (const d of domains) {
      w(`### ${dname(d)} (\`${d}\` · \`${tax.tablePrefix[d]}\`)`); w(''); w('| Job | Phase | ' + langKeys.map(lname).join(' | ') + ' |'); w('|---|---|' + '---|'.repeat(langKeys.length));
      for (const j of jobs) {
        const k = j.key; if (reach(k, d) === null) continue;
        const rd = routeDomain(k, d); const r = routing[k][rd]; const star = r.cells['*']; let ph = `\`${r.phase}\` ${esc(r.phaseName)}`;
        if (r.alsoPhases?.length) ph += '<br><sub>also ' + r.alsoPhases.map(p => `\`${p}\``).join(', ') + '</sub>';
        let jc = `\`${k}\``; if (rd !== d) { jc = `*\`${k}\`<br>↪ ${dshort(rd).toLowerCase()}*`; ph = `*${ph}*`; }
        const cols: string[] = [];
        for (const l of langKeys) {
          const c = (l !== 'prose' ? r.cells[l] : undefined) ?? star; const wn = c.winner; const ru = c.runnerUp;
          let win = cellText(wn); if (!sameAlias(wn, star.winner)) win = `**${win}**`;
          let s = win + `<br><sub>runner-up ${cellText(ru)}</sub>`; const extra: string[] = [];
          for (const x of [wn, ru]) for (const f of ['interactive', 'note'] as const) if (x[f] && !extra.includes(x[f]!)) extra.push(x[f]!);
          if (extra.length) s += '<br><sub><i>' + extra.map(esc).join(' · ') + '</i></sub>';
          cols.push(s); claims.push({ t: 'cell', job: k, d, lang: l, routed: rd, phase: r.phase, winner: effective(wn), runnerUp: effective(ru), extra });
        }
        w(`| ${jc} | ${ph} | ` + cols.join(' | ') + ' |');
      }
      w('');
    }
    w(`## ${H.effort}`); w(''); w(`**score = the ${reg.effortBase}**, plus one for each of:`); w(''); for (const p of reg.plusOne) w(`- ${p.when}`); w('');
    w('| Score | Effort |'); w('|---|---|');
    for (const lvl of levels) { const [lo, hi] = bands[lvl]; const rng = lo === 0 ? `≤ ${hi}` : hi >= 99 ? `≥ ${lo}` : lo === hi ? String(lo) : `${lo}–${hi}`; w(`| ${rng} | **${lvl}** |`); }
    w(''); w('Job weights:'); w(''); w('| Weight | Jobs |'); w('|---|---|');
    for (const wt of [...new Set(jobs.map(j => j.weight))].sort((a, b) => b - a)) w(`| ${wt} | ` + jobs.filter(j => j.weight === wt).map(j => `\`${j.key}\``).join(', ') + ' |');
    w(''); w('How each surface spells the level (`effort.surfaceMap`):'); w('');
    const sk = Object.keys(surfaceMap); w('| Level | ' + sk.map(s => surfaces[s].label).join(' | ') + ' |'); w('|---|' + '---|'.repeat(sk.length));
    for (const lvl of levels) w(`| ${lvl} | ` + sk.map(s => `\`${surfaceMap[s][lvl]}\``).join(' | ') + ' |');
    w(''); if (reg.collapsed) { w(`\`effort.surfaceMap.$collapsed\`: *${reg.collapsed}*`); w(''); }
    w(`## ${H.agg}`); w(''); w('Every (job, language) pair gets its own cell; one recommendation comes out. The rule, as ' + '`aggregation.$comment` states it:'); w('');
    w(`> ${reg.aggregationComment}`); w(''); w('`precedence`, earliest first: ' + precedence.map(a => `\`${a}\``).join(' › ') + '.'); w('');
    w('Where no other alias is left the verb returns no runner-up, and `direct` reports it as ' +
      "*fallback: none distinct* ([`direct`](../claude/skills/direct/SKILL.md) § 5). Where the verb's runner-up " +
      "shares the primary's provider and surface, the aggregate fallback is the highest-precedence alias in another " +
      "pool among the pairs' winners and runner-ups, named beside it (`picks.fallback`; zheref/nen#389)."); w('');
    w(`## ${H.examples}`); w('');
    w('Domain, primary, the verb\'s runner-up, effort and restart line are checked against `nen direct resolve` by ' +
      "`--verify`; the recommended column and the aggregate fallback are this page's reading of `picks.recommended` " +
      'and `picks.fallback`, which the verb does not compute yet (zheref/nen#389).'); w('');
    w('| Work | Labels | Domain | Primary | Fallback | Recommended | Effort | Restart line |'); w('|---|---|---|---|---|---|---|---|');
    for (const ex of EXAMPLES) {
      const r = resolved(ex); let lbl = ex.lang.map(l => `\`lang/${l}\``).join(' ') + ' ' + ex.job.map(j => `\`job/${j}\``).join(' ');
      if (ex.labels.length) lbl += ' ' + ex.labels.map(l => `\`${l}\``).join(' ');
      const why = `weight ${r.weight}` + r.adds.map(a => ` + ${a}`).join(''); const line = restart(r.winner, r.effort);
      let ru = r.runner ? label(r.runner, true) : 'none distinct';
      if (r.aggFallback && r.aggFallback !== r.runner) ru += `<br><sub>verb's runner-up, same pool · aggregate fallback ${label(r.aggFallback, true)}</sub>`;
      const rec = r.recommended === r.winner ? 'the primary' : label(r.recommended, true);
      w(`| ${ex.title}<br><sub>repo kind \`${ex.kind}\`</sub> | ${lbl} | ${dshort(r.domain)} | ` +
        `${label(r.winner, true)} | ${ru} | ${rec} | **${r.effort}**<br><sub>${why}</sub> | \`${line}\` |`);
      claims.push({ t: 'example', ex, domain: r.domain, winner: r.winner, runnerUp: r.runner, effort: r.effort, restart: line });
    }
    w(''); w(`## ${H.surfaces}`); w('');
    w(`The actionable recommendation is always one of Hatsu's ${surfaceKeys.length} surfaces. \`direct\` fills ` +
      '`<alias>` from `models` and `<level>` from the effort map — never a version.'); w('');
    w('| Surface | Restart line | Effort control | Model lookup | Interactive twin |'); w('|---|---|---|---|---|');
    for (const s of surfaceKeys) { const v = surfaces[s]; w(`| **${esc(v.label)}** | \`${esc(v.restart)}\` | ${esc(v.effortControl)} | ${esc(v.lookup)} | ${esc(v.interactive)} |`); }
    w(''); const na = Object.entries(reg.nonActionable);
    if (na.length) {
      w('Surfaces `direct` knows of and never recommends as actionable (`surfaces.$nonActionable`): ' + esc(reg.nonActionableComment)); w('');
      w('| Surface | Provider | What it is | Lookup |'); w('|---|---|---|---|');
      for (const [k, v] of na) w(`| **${esc(v.label)}** (\`${k}\`) | ${esc(v.provider ?? '—')} | ${esc(v.what)} | ${esc(v.lookup)} |`); w('');
    }
    w('Native IDE equivalents by language (offered beside the winner as the *interactive* row):'); w(''); w('| Language | Native interactive option |'); w('|---|---|');
    for (const [l, v] of Object.entries(reg.nativeInteractive)) w(`| ${lname(l)} | ${esc(v)} |`); w('');
    w(`## ${H.versions}`); w('');
    w("At run time `direct` reads the newest version of each pick's family and the effort dial its surface " +
      "offers — the surface's own lookup first, then the provider's model page, quoted with its URL and date. " +
      `Only when neither can be read does it quote the snapshot above, **with its date (${snap.asOf})**, ` + "and the effort map's dial."); w('');
    w('| Provider | Surface lookup | Effort dial, read live | Model pages |'); w('|---|---|---|---|');
    for (const [p, v] of Object.entries(liveLookup)) w(`| ${p} | ${esc(v.cli || '—')} | ${esc(v.effort || 'no dial')} | ` + v.docs.map(esc).join('<br>') + ' |');
    w(''); w(`## ${H.sync}`); w(''); w('```bash');
    w('bash scripts/direct_matrix_doc.sh --write      # re-render after any registry, taxonomy or models edit');
    w('bash scripts/direct_matrix_doc.sh --check      # exit 1 when this page is stale (lane direct-matrix-guard)');
    w('bash scripts/direct_matrix_doc.sh --verify     # every printed cell, level and example against nen direct resolve');
    w("bash scripts/direct_matrix_doc.sh --self-test  # the guard's own fixtures, then --check"); w('```'); w(''); w(FOOTER_INSTALLED);
    return { page: o.join('\n') + '\n', claims };
  }
  function verify(): number {
    const nenBin = process.env.NEN ?? 'nen'; const contract = record(load(root, CONTRACT_PATH), CONTRACT_PATH);
    const pin = text(record(contract.dependency, 'dependency').pinned_ref, 'dependency.pinned_ref').replace(/^v+/, '');
    const versionRun = spawnSync(nenBin, ['--version'], { encoding: 'utf8' });
    if (versionRun.error) refuse(`--verify: '${nenBin}' not found or could not run (set NEN=<path> or put nen on PATH): ${versionRun.error.message}`);
    const version = versionRun.stdout.trim();
    if (version !== pin) refuse(`--verify: ${nenBin} --version reads '${version}', the contract pins '${pin}'`);
    type NenSide = { alias: string; restart?: string; interactive?: string | null; note?: string | null };
    type NenOutput = { domain: string; pairs: { job: string; domain: string; phase: string; winner: NenSide; runnerUp: NenSide }[];
      winner: NenSide; runnerUp: NenSide | null; effort: string };
    const cache = new Map<string, NenOutput>();
    function nen(kind: string, role: string | null, labels: string[], lang: string[], job: string[]): NenOutput {
      const key = JSON.stringify([kind, role, labels, lang, job]); const cached = cache.get(key); if (cached) return cached;
      const argv = ['direct', 'resolve', '--registry', REG_PATH, '--taxonomy', TAX_PATH, '--repo', root, '--kind', kind, '--job', job.join(','), '--json'];
      if (role) argv.push('--role', role); if (labels.length) argv.push('--labels', labels.join(',')); if (lang.length) argv.push('--lang', lang.join(','));
      const p = spawnSync(nenBin, argv, { cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
      if (p.error) refuse(`--verify: '${nenBin}' not found or could not run (set NEN=<path> or put nen on PATH): ${p.error.message}`);
      if (p.status !== 0) refuse(`--verify: nen direct resolve failed (${[nenBin, ...argv].join(' ')}): ${p.stderr.trim()}`);
      let value: unknown; try { value = JSON.parse(p.stdout); } catch { refuse('--verify: nen direct resolve returned invalid JSON'); }
      const r = record(value, '--verify result');
      function side(v: unknown, pair = false): NenSide { const s = record(v, '--verify side'); return { alias: text(s.alias, '--verify side.alias'),
        restart: optionalText(s.restart, '--verify side.restart'), interactive: !pair || s.interactive === undefined ? undefined : nullableText(s.interactive, '--verify side.interactive'),
        note: !pair || s.note === undefined ? undefined : nullableText(s.note, '--verify side.note') }; }
      const out: NenOutput = { domain: text(record(r.domain, '--verify domain').domain, '--verify domain.domain'),
        pairs: array(r.pairs, '--verify pairs').map(v => { const q = record(v, '--verify pair'); return { job: text(q.job, '--verify pair.job'),
          domain: text(q.domain, '--verify pair.domain'), phase: text(q.phase, '--verify pair.phase'), winner: side(q.winner, true), runnerUp: side(q.runnerUp, true) }; }),
        winner: side(r.winner), runnerUp: r.runnerUp === null || r.runnerUp === undefined ? null : side(r.runnerUp), effort: text(record(r.effort, '--verify effort').level, '--verify effort.level') };
      cache.set(key, out); return out;
    }
    const { claims } = render(); const bad: string[] = [];
    for (const c of claims) {
      if (c.t === 'cell' || c.t === 'grid') {
        const [kind, role, labels] = FORCE[c.d]; const jl = reach(c.job, c.d); if (!jl) refuse('--verify: a reachable claim has no input');
        const out = nen(kind, role, labels, [c.lang], jl); const pair = out.pairs.find(p => p.job === c.job); const where = `${c.t} ${c.job}/${c.d}/${c.lang}`;
        if (out.domain !== c.d || !pair) { bad.push(`${where}: nen derived ${out.domain}`); continue; }
        if (pair.domain !== c.routed) bad.push(`${where}: page routes on ${c.routed} · nen on ${pair.domain}`);
        if (pair.winner.alias !== c.winner) bad.push(`${where} winner: page ${c.winner} · nen ${pair.winner.alias}`);
        if (c.t === 'cell') {
          if (pair.runnerUp.alias !== c.runnerUp) bad.push(`${where} runner-up: page ${c.runnerUp} · nen ${pair.runnerUp.alias}`);
          if (pair.phase !== c.phase) bad.push(`${where} phase: page ${c.phase} · nen ${pair.phase}`);
          const theirs: string[] = [];
          for (const x of [pair.winner, pair.runnerUp]) for (const f of ['interactive', 'note'] as const) if (x[f] && !theirs.includes(x[f]!)) theirs.push(x[f]!);
          if (!equal(theirs, c.extra)) bad.push(`${where} interactive/note: page ${JSON.stringify(c.extra)} · nen ${JSON.stringify(theirs)}`);
        }
      } else if (c.t === 'unreachable') {
        const [kind, role, labels] = FORCE[c.d];
        for (const jl of unreachInputs(c.job, c.d)) { const got = nen(kind, role, labels, ['prose'], jl).domain; if (got === c.d) bad.push(`unreachable ${c.job}/${c.d}: nen derives ${got} for jobs ${JSON.stringify(jl)}`); }
      } else if (c.t === 'effort') {
        const [kind, role, labels] = FORCE[c.aigov ? 'aigov' : 'maintenance']; const got = nen(kind, role, labels, ['prose'], [c.job]).effort;
        if (got !== c.level) bad.push(`effort alone ${c.job} (aigov=${c.aigov}): page ${c.level} · nen ${got}`);
      } else {
        const ex = c.ex; const out = nen(ex.kind, ex.role, ex.labels, ex.lang, ex.job);
        const got = [out.domain, out.winner.alias, out.runnerUp?.alias ?? null, out.effort, out.winner.restart];
        const want = [c.domain, c.winner, c.runnerUp, c.effort, c.restart];
        if (!equal(got, want)) bad.push(`example '${ex.title}': page ${JSON.stringify(want)} · nen ${JSON.stringify(got)}`);
      }
    }
    if (bad.length) {
      console.error(`direct_matrix_doc --verify: ${bad.length} disagreement(s) of ${claims.length} printed claims (nen ${version})`);
      for (const b of bad) console.error('  ' + b); return 1;
    }
    const kinds = new Map<string, number>(); for (const c of claims) kinds.set(c.t, (kinds.get(c.t) ?? 0) + 1);
    console.log(`direct_matrix_doc --verify: ${claims.length} printed claims agree with nen direct resolve ${version} (${[...kinds].map(([k, v]) => `${v} ${k}`).join(', ')}; ${cache.size} resolves)`);
    return 0;
  }
  function selfTest(): number {
    const fails: string[] = [];
    function ok(cond: boolean, what: string): void { console.log((cond ? '  ok    ' : '  FAIL  ') + what); if (!cond) fails.push(what); }
    function run(args: string[], r: string, env?: NodeJS.ProcessEnv) { const p = spawnSync('bash', [SCRIPT, ...args, r], { encoding: 'utf8', env: env ?? process.env }); return { code: p.status, out: p.stdout + p.stderr }; }
    for (const finding of priceFindings()) ok(false, finding);
    const tmp = mkdtempSync(join(tmpdir(), 'direct-matrix-selftest.'));
    try {
      for (const p of [REG_PATH, TAX_PATH, WF_PATH]) { mkdirSync(dirname(join(tmp, p)), { recursive: true }); copyFileSync(join(root, p), join(tmp, p)); }
      mkdirSync(join(tmp, 'docs')); const page = join(tmp, OUT_PATH);
      function edit(path: string, fn: (d: JsonRecord) => void): void { const d = record(load(tmp, path), path); fn(d); writeFileSync(join(tmp, path), JSON.stringify(d)); }
      console.log('fixtures under a temp dir:');
      ok(run(['--check'], tmp).code === 1, '--check exits 1 when the page is missing');
      ok(run(['--write'], tmp).code === 0 && existsSync(page), '--write writes the page');
      ok(run(['--check'], tmp).code === 0, '--check exits 0 on a fresh page');
      const originalPage = readFileSync(page, 'utf8'); writeFileSync(page, originalPage.replace(FOOTER_INSTALLED, FOOTER_OLD));
      ok(run(['--check'], tmp).code === 1, '--check rejects the pre-installation footer after the CI step lands'); writeFileSync(page, originalPage);
      const hostile = join(tmp, 'preload.cjs'); writeFileSync(hostile, "require('node:fs').writeFileSync(" + JSON.stringify(join(tmp, 'injected.marker')) + ", 'ran'); throw Error('PR preload ran');\n");
      mkdirSync(join(tmp, 'scripts')); writeFileSync(join(tmp, 'scripts/direct_matrix_doc.mts'), "throw Error('PR renderer ran');\n");
      writeFileSync(join(tmp, 'json.py'), "open('injected.marker', 'w').write('ran')\nraise RuntimeError('PR module ran')\n");
      const shadowed = run(['--check'], tmp, { ...process.env, NODE_OPTIONS: `--require=${hostile}`, NODE_PATH: tmp, PYTHONPATH: tmp });
      ok(shadowed.code === 0 && !existsSync(join(tmp, 'injected.marker')), '--check uses trusted sibling code and ignores PR modules and Node preloads');
      writeFileSync(page, originalPage + 'x\n'); ok(run(['--check'], tmp).code === 1, '--check exits 1 on a hand-edited page'); run(['--write'], tmp);
      edit(REG_PATH, d => { const a = record(d.aliases, 'aliases'); const routes = record(d.routing, 'routing'); const job = record(routes['bug-fix'], 'routing.bug-fix');
        const cells = record(record(job.maintenance, 'maintenance').cells, 'cells'); const c = record(record(cells['*'], '*').winner, 'winner');
        c.alias = c.alias !== 'EXECUTION_VALUE' ? 'EXECUTION_VALUE' : 'BALANCED_AUTHOR'; c.surface = record(a[text(c.alias, 'alias')], 'alias').surface; });
      ok(run(['--check'], tmp).code === 1, '--check exits 1 after one routing cell moves'); copyFileSync(join(root, REG_PATH), join(tmp, REG_PATH));
      edit(TAX_PATH, d => { const keys = array(record(record(d.axes, 'axes').job, 'job').keys, 'keys'); keys.push({ ...record(keys[0], 'job'), key: 'zz-new-job' }); });
      let result = run(['--check'], tmp); ok(result.code === 2 && result.out.includes('zz-new-job'), 'a job with no routing row refuses by name, exit 2'); copyFileSync(join(root, TAX_PATH), join(tmp, TAX_PATH));
      edit(TAX_PATH, d => { const dom = record(d.domains, 'domains'); dom.rule = array(dom.rule, 'rule').filter(r => record(r, 'rule').when !== 'otherwise'); });
      result = run(['--check'], tmp); ok(result.code === 2 && result.out.includes('otherwise'), "no 'otherwise' domain row refuses by name, exit 2"); copyFileSync(join(root, TAX_PATH), join(tmp, TAX_PATH));
      edit(REG_PATH, d => { record(record(record(d.effort, 'effort').rule, 'rule').bands, 'bands').medium = [9, 9]; });
      result = run(['--check'], tmp); ok(result.code === 2 && result.out.includes('no band'), 'an unbanded effort score refuses, exit 2');
      rmSync(join(tmp, REG_PATH)); result = run(['--check'], tmp); ok(result.code === 2 && result.out.includes(REG_PATH), 'a missing registry refuses by name, exit 2');
      ok(run(['--check', '--write'], tmp).code === 2, 'two modes at once are refused, exit 2');
    } finally { rmSync(tmp, { recursive: true, force: true }); }
    console.log('the re-implemented rules, at their edges (real data, in process):');
    const pj = jobs.find(j => j.key !== 'parity')!.key; const maintOnly = jobs.find(j => new Set(j.phases).size === 1 && j.phases.includes('maintenance'))?.key;
    ok(deriveDomain('process', null, [], [pj]) === 'aigov', 'kind process derives aigov');
    ok(deriveDomain('product', 'canon', [], [pj]) === 'aigov', 'role canon derives aigov');
    ok(deriveDomain('library', null, ['bug'], ['parity']) === 'library', 'kind library outranks bug and parity');
    ok(deriveDomain('product', null, ['bug'], ['parity']) === 'parity', 'job/parity outranks bug');
    ok(deriveDomain('product', null, ['team:bug'], [pj]) === 'maintenance', "'<ns>:bug' matches '*:bug'");
    ok(deriveDomain('product', null, [':bug'], [pj]) !== 'maintenance', "':bug' (empty namespace) does not");
    ok(deriveDomain('product', null, ['Bug'], ['architecture']) === 'feature', "'Bug' is not 'bug'");
    if (maintOnly) ok(deriveDomain('product', null, [], [maintOnly]) === 'maintenance', 'a maintenance-only job derives maintenance');
    ok(deriveDomain('product', null, [], ['architecture']) === 'feature', 'otherwise derives feature');
    ok(equal(Array.from({ length: 7 }, (_, s) => band(s)), ['low', 'low', 'low', 'medium', 'high', 'max', 'max']), 'effort bands at every edge');
    ok(resolve({ kind: 'product', role: null, labels: [], lang: [], job: [] }).undirectable, 'an empty job axis is undirectable');
    const lib: Example = { kind: 'library', role: null, labels: [], lang: ['typescript', 'prose'], job: ['delivery-ops', 'implementation'] };
    ok(resolved(lib).runner === 'SEMANTIC_FRONTIER', 'prose beside a code language keeps its own pair');
    const sec = resolved({ kind: 'library', role: null, labels: [], lang: ['prose'], job: ['security'] });
    ok(sec.runner !== null && sec.runner !== sec.winner, "a review bot's also never shares the winner's pool, so the fallback stays distinct (picks.fallbackRule)");
    const same: Cell[] = [{ winner: { alias: 'SEMANTIC_FRONTIER' }, runnerUp: { alias: 'SEMANTIC_FRONTIER' } }];
    ok(equal(aggregate(same), ['SEMANTIC_FRONTIER', null]), 'a runner-up equal to the winner leaves none distinct (fixture)');
    ok(aggFallback(same, 'SEMANTIC_FRONTIER', null) === null, 'no other-pool alias among the pairs leaves no aggregate fallback (fixture)');
    const mixed: Cell[] = [{ winner: { alias: 'BALANCED_AUTHOR' }, runnerUp: { alias: 'EDITOR_FRONTIER' } }, { winner: { alias: 'SEMANTIC_FRONTIER' }, runnerUp: { alias: 'EXECUTION_FRONTIER' } }];
    ok(equal(aggregate(mixed), ['SEMANTIC_FRONTIER', 'BALANCED_AUTHOR']) && aggFallback(mixed, 'SEMANTIC_FRONTIER', 'BALANCED_AUTHOR') === 'EXECUTION_FRONTIER',
      'a same-pool aggregate runner-up yields the highest-precedence other-pool alias as the fallback (fixture)');
    ok(EXAMPLES.map(resolved).every(r => !r.aggFallback || !samePool(r.winner, r.aggFallback)), "every worked example's aggregate fallback sits in another pool than its primary");
    ok(effective({ alias: 'PR_QUALITY_REVIEW', also: 'EXECUTION_FRONTIER' }) === 'EXECUTION_FRONTIER', "a review bot's cell counts for its also");
    console.log("the registry's own invariants (picks, companions), over every cell:");
    const broken: string[] = [];
    for (const [j, doms] of Object.entries(routing)) for (const [d, r] of Object.entries(doms)) for (const [l, c] of Object.entries(r.cells)) if (!fallbackOk(c)) broken.push(`${j}/${d}/${l}`);
    ok(!broken.length, 'picks.fallbackRule: every fallback is on another provider or surface' + (broken.length ? ` (broken: ${broken.slice(0, 5).join(', ')})` : ''));
    ok(actionable.every(a => Boolean(aliases[a].line)), 'every actionable alias names its model line');
    ok(actionable.every(a => !aliases[a].escalation || actionable.includes(aliases[a].escalation!)), 'every escalation names an actionable alias or is null');
    const tiers = ['fast', 'deep', 'frontier'];
    ok(actionable.filter(a => aliases[a].escalation).every(a => { const up = aliases[aliases[a].escalation!]; return tiers.indexOf(up.tier!) === tiers.indexOf(aliases[a].tier!) + 1 && up.surface === aliases[a].surface; }),
      'every escalation climbs exactly one tier on the same surface');
    ok(actionable.filter(a => !aliases[a].escalation).every(a => aliases[a].tier === 'frontier' || !actionable.some(b => aliases[b].tier === tiers[tiers.indexOf(aliases[a].tier!) + 1] && aliases[b].surface === aliases[a].surface)),
      'an alias with no escalation has no actionable alias one tier above it on its surface');
    ok(Object.values(routing).flatMap(v => Object.values(v)).flatMap(r => Object.values(r.cells)).every(c => !escalations.includes(c.winner.alias)),
      'no cell names a frontier alias as its primary (frontier is reached only as recommended)');
    ok(equal(Object.keys(companions.role).sort(), [...companionJobs].sort()), "companions.role names exactly the taxonomy's companion jobs");
    ok(companionJobs.every(j => Object.hasOwn(routing, j)), 'every companion job still has its own routing row');
    ok(recommended('SEMANTIC_FRONTIER', 4, 'high') === 'SEMANTIC_MAX' && recommended('SEMANTIC_FRONTIER', 3, 'high') === 'SEMANTIC_FRONTIER' &&
      recommended('BALANCED_AUTHOR', 2, 'max') === 'SEMANTIC_FRONTIER' && recommended('EDITOR_FRONTIER', 4, 'max') === 'EDITOR_FRONTIER',
      'picks.recommended at its edges: weight 4 or max climbs, else the primary; nothing above stays');
    ok(actionable.every(a => Boolean(snap.aliases[a].listPrice?.source)), "every actionable alias's list price cites its source");
    console.log('the committed page:'); const pageNow = render().page; const ragged: number[] = []; let hdr: number | null = null;
    const lines = pageNow.split('\n'); for (const [i, line] of lines.entries()) {
      if (!line.startsWith('|')) { hdr = null; continue; }
      const cells = line.trim().split(/(?<!\\)\|/).length - 2; if (hdr === null) hdr = cells; else if (cells !== hdr) ragged.push(i + 1);
    }
    ok(!ragged.length, "every table row has its header's cell count" + (ragged.length ? ` (ragged at lines ${JSON.stringify(ragged.slice(0, 5))})` : ''));
    const cur = existsSync(join(root, OUT_PATH)) ? readFileSync(join(root, OUT_PATH), 'utf8') : null; ok(cur === pageNow, `${OUT_PATH} is current`);
    if (fails.length) { console.error(`direct_matrix_doc --self-test: ${fails.length} failed`); return 1; }
    console.log('direct_matrix_doc --self-test: all passed'); return 0;
  }
  return { render, verify, selfTest, priceFindings, verdictEvidence, evidenceEnabled };
}

/** The historical matrix modes keep their shell CLI. Direct calls the typed evidence mode
 * with aliases already selected by Nen; this mode reports evidence and never resolves a pick.
 */
export function main(argv: string[]): number {
  const [mode, root, ...args] = argv;
  if (!root || !['print', 'write', 'check', 'verify', 'self-test', 'evidence'].includes(mode) || (mode !== 'evidence' && args.length))
    refuse('expected a mode and repo-root from direct_matrix_doc.sh, or evidence <hatsu-root> --repo <consumer> --primary <alias> --fallback <alias|none> --recommended <alias> --effort <level> [--product <product>]');
  const flags: Record<string, string> = Object.create(null);
  if (mode === 'evidence') {
    const admitted = ['--repo', '--primary', '--fallback', '--recommended', '--effort', '--product'];
    for (let i = 0; i < args.length; i += 2) {
      const key = args[i]; const value = args[i + 1];
      if (!admitted.includes(key) || Object.hasOwn(flags, key) || !value?.trim() || value.startsWith('--')) refuse(`evidence: unknown, duplicate or missing argument ${JSON.stringify(key)}`);
      flags[key] = value;
    }
    for (const key of admitted.filter(k => k !== '--product')) if (!flags[key]) refuse(`evidence: required ${key}`);
  }
  const matrix = createMatrix(root, { workflowRoot: flags['--repo'] });
  if (mode === 'evidence' && !matrix.evidenceEnabled) {
    process.stdout.write(JSON.stringify({ enabled: false, evidenceVersion: 0,
      reason: 'Compatible bootstrap only; activate snapshot.evidenceVersion=1 in a follow-up after the trusted renderer has merged on main.' }, null, 2) + '\n');
    return 0;
  }
  const expired = matrix.priceFindings();
  for (const finding of expired) console.error(`direct_matrix_doc: ${finding}`);
  if (mode === 'evidence') {
    const evidence = matrix.verdictEvidence(flags['--primary'], flags['--fallback'] === 'none' ? null : flags['--fallback'],
      flags['--recommended'], flags['--effort'], flags['--product']);
    process.stdout.write(JSON.stringify({ enabled: true, evidenceVersion: 1, ...evidence, expiredPriceEvidence: expired }, null, 2) + '\n');
    return expired.length ? 1 : 0;
  }
  if (expired.length) return 1;
  if (mode === 'verify') return matrix.verify();
  if (mode === 'self-test') return matrix.selfTest();
  const { page } = matrix.render(); const target = join(root, OUT_PATH);
  if (mode === 'print') process.stdout.write(page);
  else if (mode === 'write') {
    // An exclusive temporary directory keeps both creation and rename on the target filesystem.
    const temp = mkdtempSync(join(dirname(target), '.direct-matrix.'));
    try { const path = join(temp, 'page'); writeFileSync(path, page, { encoding: 'utf8', mode: 0o600, flag: 'wx' }); renameSync(path, target); }
    finally { rmSync(temp, { recursive: true, force: true }); }
    console.log(`wrote ${OUT_PATH}`);
  } else {
    if (!existsSync(target)) { console.error(`${OUT_PATH} is missing: run bash scripts/direct_matrix_doc.sh --write ${root}`); return 1; }
    if (readFileSync(target, 'utf8') !== page) { console.error(`${OUT_PATH} is stale: run bash scripts/direct_matrix_doc.sh --write ${root}`); return 1; }
    console.log(`${OUT_PATH} is current`);
  }
  return 0;
}
if (process.argv[1] && pathToFileURL(resolvePath(process.argv[1])).href === import.meta.url) {
  try { process.exitCode = main(process.argv.slice(2)); }
  catch (error) { console.error(`direct_matrix_doc: ${error instanceof Error ? error.message : String(error)}`); process.exitCode = 2; }
}
