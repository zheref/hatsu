/** HA#370: offline catalogue provenance and per-cell ownership. No Git checkout is required. */
import { createHash } from 'node:crypto';
import { lstatSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { isDeepStrictEqual } from 'node:util';
import type { Catalogue } from './pr_sections.ts';

type ObjectValue = Record<string, any>;
export const CONTRACT = 'hatsu.pr-sections/v1';
const HASH = /^[a-f0-9]{64}$/;
export function object(value: unknown, where: string): ObjectValue {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(`${where} must be an object`);
  return value as ObjectValue;
}
/** The taxonomy pattern: recursively sorted object keys, compact UTF-8 JSON, hash field excluded. */
export function documentSha256(value: unknown): string {
  const raw = { ...object(value, 'catalogue') };
  delete raw.documentSha256;
  const sorted = (node: any): any => Array.isArray(node) ? node.map(sorted)
    : node && typeof node === 'object' ? Object.fromEntries(Object.keys(node).sort().map(key => [key, sorted(node[key])])) : node;
  return createHash('sha256').update(JSON.stringify(sorted(raw)), 'utf8').digest('hex');
}
export function checkStamp(raw: unknown): string {
  const cat = object(raw, 'catalogue');
  const actual = documentSha256(cat);
  if (cat.documentSha256 !== actual) throw new Error(`contracts/pr-sections.json: documentSha256 drifts from canonical bytes (expected ${actual})`);
  return actual;
}
export interface Snapshot { max: number; variants: Record<string, string[]>; sections: Array<{ id: string }> }
export function history(root: string, cat: Catalogue): Record<string, Snapshot> {
  const path = join(root, 'contracts/pr-sections.history.json');
  const info = lstatSync(path);
  if (info.isSymbolicLink() || !info.isFile()) throw new Error('PR-section history must be a regular file; symlinks are refused');
  let parsed: unknown;
  try { parsed = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(readFileSync(path))); }
  catch { throw new Error('PR-section history is not readable UTF-8 JSON'); }
  const document = object(parsed, 'PR-section history');
  if (document.contract !== 'hatsu.pr-sections.history/v1') throw new Error('expected hatsu.pr-sections.history/v1');
  const entries = object(document.catalogues, 'PR-section history catalogues');
  for (const [sha, value] of Object.entries(entries)) {
    const entry = object(value, `history ${sha}`);
    if (!HASH.test(sha) || entry.contract !== CONTRACT || entry.documentSha256 !== sha || documentSha256(entry) !== sha) throw new Error(`PR-section history: invalid catalogue ${sha}`);
    if (!Number.isInteger(entry.max) || entry.max < 1 || entry.max > 7 || !Array.isArray(entry.sections)) throw new Error(`PR-section history ${sha}: invalid max/sections`);
    const ids = entry.sections.map((row: any) => object(row, 'historical section').id);
    if (ids.some((id: unknown) => typeof id !== 'string' || !id) || new Set(ids).size !== ids.length) throw new Error(`PR-section history ${sha}: invalid section ids`);
    for (const [cell, values] of Object.entries(object(entry.variants, 'historical variants'))) {
      if (!/^(product|library|process|unknown)\.[a-z][a-z0-9-]*$/.test(cell) || !Array.isArray(values) || values.some(id => !ids.includes(id)) || values.length > entry.max || new Set(values).size !== values.length) throw new Error(`PR-section history ${sha}: invalid cell ${cell}`);
    }
  }
  const current = entries[cat.documentSha256];
  if (!current || !isDeepStrictEqual(current.variants, cat.variants) || current.max !== cat.max || !isDeepStrictEqual(current.sections.map((row: any) => row.id), cat.sections.map(row => row.id))) throw new Error('PR-section history: current catalogue is missing or differs');
  return entries as Record<string, Snapshot>;
}
export type CellState = 'current default' | 'stale default' | 'consumer-owned' | 'missing' | 'retired' | 'unstamped';
export interface CellReading { cell: string; state: CellState; retiredIds: string[]; ownership?: 'default' | 'consumer-owned' | 'unknown'; matchesCurrent?: boolean }
export interface Reading {
  status: 'current' | 'stale' | 'unstamped'; stampedSha: string | null; catalogueSha: string;
  stampedSha7: string | null; catalogueSha7: string; cells: CellReading[];
  counts: { currentDefault: number; staleDefault: number; consumerOwned: number; missing: number; retired: number; unstamped: number };
}
function validCell(value: unknown, cell: string): string[] {
  if (!Array.isArray(value) || value.some(id => typeof id !== 'string' || !id) || new Set(value).size !== value.length) throw new Error(`pr.sections.variants.${cell}: expected unique section ids`);
  return value;
}
export function readSections(value: unknown, cat: Catalogue, entries: Record<string, Snapshot>): Reading {
  const config = object(value, 'pr.sections');
  if (config.max !== undefined && (!Number.isInteger(config.max) || config.max < 1 || config.max > cat.max)) throw new Error(`pr.sections.max must be from 1 through ${cat.max}`);
  const variants = config.variants === undefined ? {} : object(config.variants, 'pr.sections.variants');
  let stampedSha: string | null = null;
  let previous: Snapshot | undefined;
  let owned: string[] = [];
  if (Object.hasOwn(config, '$canon')) {
    const stamp = object(config.$canon, 'pr.sections.$canon');
    if (stamp.contract !== CONTRACT || typeof stamp.sha256 !== 'string' || !HASH.test(stamp.sha256)) throw new Error('pr.sections.$canon: invalid contract or sha256; ownership is unknown');
    stampedSha = stamp.sha256;
    previous = entries[stampedSha];
    if (!previous) throw new Error(`pr.sections.$canon: unknown catalogue ${stampedSha}; ownership is unknown; nothing refreshed`);
    if (stamp.owned !== undefined) {
      if (!Array.isArray(stamp.owned) || stamp.owned.some(cell => typeof cell !== 'string' || !Object.hasOwn(variants, cell)) || new Set(stamp.owned).size !== stamp.owned.length) throw new Error('pr.sections.$canon.owned: expected unique present cell names');
      owned = stamp.owned;
    }
  }
  const knownIds = new Set(cat.sections.map(row => row.id));
  const cells: CellReading[] = [];
  for (const cell of new Set([...Object.keys(cat.variants), ...Object.keys(variants)])) {
    if (cell.startsWith('$')) continue;
    const present = Object.hasOwn(variants, cell);
    const current = cat.variants[cell];
    if (!present) { cells.push({ cell, state: 'missing', retiredIds: [] }); continue; }
    const ids = validCell(variants[cell], cell);
    const retiredIds = ids.filter(id => !knownIds.has(id));
    const ownership = previous ? !owned.includes(cell) && isDeepStrictEqual(ids, previous.variants[cell]) ? 'default' : 'consumer-owned' : 'unknown';
    const state: CellState = !current ? 'retired' : !previous ? 'unstamped'
      : ownership === 'consumer-owned' ? 'consumer-owned' : isDeepStrictEqual(ids, current) ? 'current default' : 'stale default';
    cells.push({ cell, state, retiredIds, ownership, matchesCurrent: isDeepStrictEqual(ids, current) });
  }
  const count = (state: CellState) => cells.filter(cell => cell.state === state).length;
  const counts = { currentDefault: count('current default'), staleDefault: count('stale default'), consumerOwned: count('consumer-owned'), missing: count('missing'), retired: count('retired'), unstamped: count('unstamped') };
  const status = !previous ? 'unstamped' : stampedSha !== cat.documentSha256 || counts.staleDefault + counts.missing + counts.retired > 0 ? 'stale' : 'current';
  return { status, stampedSha, catalogueSha: cat.documentSha256, stampedSha7: stampedSha?.slice(0, 7) ?? null, catalogueSha7: cat.documentSha256.slice(0, 7), cells, counts };
}
export function summary(reading: Reading): string {
  if (reading.status === 'unstamped') return `pr.sections: unstamped — compared with current catalogue; differing cells: ${reading.cells.filter(cell => cell.matchesCurrent === false).map(cell => cell.cell).join(', ') || 'none'}; ${reading.counts.missing} missing; ownership unknown; present cells retained`;
  return `pr.sections: ${reading.status} (${reading.counts.staleDefault} stale default cell(s), ${reading.counts.missing} missing; stamped ${reading.stampedSha7}, catalogue ${reading.catalogueSha7})`;
}
export class RefreshRefusal extends Error {}
export function refreshed(value: unknown, cat: Catalogue, entries: Record<string, Snapshot>): { value: ObjectValue; reading: Reading; kept: string[] } {
  const config = object(value, 'pr.sections');
  const reading = readSections(config, cat, entries);
  const variants = { ...(config.variants ?? {}) };
  const kept: string[] = [];
  const refusals: string[] = [];
  for (const row of reading.cells) {
    if (row.ownership === 'consumer-owned' || row.ownership === 'unknown') {
      kept.push(row.cell);
      if (row.retiredIds.length || row.state === 'retired') refusals.push(`${row.cell}: retired ${row.retiredIds.length ? 'id(s) '+row.retiredIds.join(', ') : 'cell'}`);
    } else if (row.state === 'missing' || row.state === 'stale default') variants[row.cell] = cat.variants[row.cell];
    else if (row.state === 'retired') delete variants[row.cell];
  }
  if (refusals.length) throw new RefreshRefusal(`pr.sections: retained ${kept.join(', ')}; ${refusals.join('; ')}; resolve owned cells explicitly; nothing written`);
  // An unstamped copy supplies no provenance: retain every present cell explicitly as owned.
  // Missing cells alone receive defaults, so adoption never guesses which old cells were edited.
  const maximum = config.max ?? cat.max;
  for (const [cell, ids] of Object.entries(variants) as Array<[string, string[]]>) {
    if (cell.startsWith('$')) continue;
    if (ids.length > maximum || ids[0] !== 'changes' || ['why', 'verify', ...(cell.endsWith('.release') ? [] : ['improves'])].some(id => !ids.includes(id))) throw new Error(`pr.sections.variants.${cell}: invalid readers for retained max ${maximum}; nothing written`);
  }
  return { value: { ...config, ...(config.max === undefined ? { max: cat.max } : {}), variants, $canon: { contract: CONTRACT, sha256: cat.documentSha256, ...(kept.length ? { owned: kept } : {}) } }, reading, kept };
}
