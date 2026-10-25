#!/usr/bin/env node
// HR-2: the HR id space in docs/ROSTER.md stays unique. Ported from
// zheref/akatsuki-ai's clause_id_guard (ninjutsu/src/ports/clause_id_guard.ts),
// its CON-{n} heading keyed on Hatsu's HR anchor instead:
//
//   1. DEFINITIONS ARE COUNTED, CITATIONS NEVER ARE. A definition is the anchor
//      `<a id="hr-N"></a>**HR-N**`; `[HR-N](#hr-N)`, a bare `HR-N` and a
//      `reversed by HR-N` status are citations and are never counted.
//   2. A DUPLICATE ID EXITS 1 — two efforts minting the same HR id merge cleanly
//      at different offsets and leave every citation of it ambiguous. An anchor
//      whose `hr-N` and `**HR-M**` disagree is refused the same way. Every
//      `id="hr-…"` in the file counts as an anchor, case-insensitively: one not in
//      the canonical form above (a space before the label, single quotes, an
//      upper-case `HR-`, no label at all) exits 1, and so does a second anchor of
//      the same id in any form.
//   3. GAPS ARE REPORTED, NEVER FAILED: one `::notice::` line, exit 0, listing
//      the first 20 missing ids and a count of the rest.
//   4. ORDER IS NOT ASSERTED.
//   5. A TOOLING FAILURE IS NOT A FINDING: wrong arity, an unreadable file, a
//      path holding `,` `:` or a line break (it would forge annotation
//      properties), an id that is not a safe integer, or an id above the
//      definition count plus 1000 exits 2 on stderr with nothing on stdout, so
//      "could not look" never reads as "looked and found". A node too old to
//      strip TypeScript types (below 22.18, or 23.0 to 23.5; nen/contract.json →
//      toolchain.node) fails in node's own loader with exit 1 and no `::error::`
//      line on stdout: an exit 1 without an `::error::` line is a toolchain
//      failure, never a finding. No refusal shim fronts this guard.
//   6. Ids are whole numbers: HR-2 never matches HR-20.
//   7. EVERY DEFINITION CARRIES AN ADMITTED STATUS (zheref/hatsu#452). The status
//      is the table's `Status` cell where the header names one, else the
//      parenthesis right after `**HR-N**`. The words are ROSTER § *How HR ids are
//      read*'s: `ruled`, `reading`, or `reversed by` / `superseded by` one or more
//      `HR-m` (comma-separated), optionally followed by ONE balanced parenthesis
//      naming the displaced part and ending the status. Anything else, or no
//      status at all, exits 1 naming the row and the word; so does a table row
//      whose `Status` cell and parenthesis both exist and differ.
//   8. NO CITATION DANGLES: every `HR-N` and every `(#hr-N)` link target in the
//      file names a defined row, else exit 1 naming the citing line and the id,
//      once per line and id (a `[HR-N](#hr-N)` link is one citation).
//   9. THE READINGS INDEX MATCHES THE STATUSES: every `reading` row has an entry
//      in § *Readings*' table (a `| [HR-N](#hr-N) |` first cell), and every entry
//      names a `reading` row; either side missing exits 1 naming the row, and so
//      does an entry whose label `HR-N` and link `#hr-M` disagree. A
//      roster with no `## Readings` heading is a tooling failure (exit 2): an
//      index that could not be found is never an index that matched.
//
// Usage: node scripts/clause_id_guard.mts [<roster.md>]   (default docs/ROSTER.md)
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFINITION = /<a id="hr-(\d+)"><\/a>\*\*HR-(\d+)\*\*/g;
const ANCHOR = /\bid\s*=\s*["']?hr-([^"'\s>]*)/gi;
const CITATION = /\bHR-(\d+)\b|\]\(#hr-(\d+)\)/g;
const INDEX_ENTRY = /^\|\s*\[HR-(\d+)\]\(#hr-(\d+)\)\s*\|/;
const STATUS_HEAD = /^(?:reversed|superseded) by HR-\d+(?:, HR-\d+)*/;
const GAP_LISTING = 20;
const ID_HEADROOM = 1000;

interface Anchor { readonly line: number; readonly column: number; readonly raw: string; readonly canonical: boolean }

interface Verdict {
  readonly ids: readonly number[];
  readonly duplicates: readonly { id: string; count: number }[];
  readonly mismatches: readonly { line: number; anchor: string; bold: string }[];
  readonly nonCanonical: readonly Anchor[];
  readonly gaps: readonly number[];
  readonly gapCount: number;
  readonly badStatus: readonly { line: number; id: string; word: string }[];
  readonly twoStatuses: readonly { line: number; id: string; cell: string; paren: string }[];
  readonly labelMismatch: readonly { line: number; label: string; link: string }[];
  readonly dangling: readonly { line: number; id: string }[];
  readonly unindexed: readonly { line: number; id: string }[];
  readonly misindexed: readonly { line: number; id: string; status: string }[];
  readonly definitions: readonly Definition[];
}

interface Definition { readonly id: string; readonly line: number; readonly status: string | null; readonly paren: string | null }

export interface RosterStatus { readonly id: string; readonly line: number; readonly status: string }

// The parenthesis opening at `open`, balanced, or null when it never closes on the line.
function balanced(text: string, open: number): string | null {
  let depth = 0;
  for (let i = open; i < text.length; i += 1) {
    if (text[i] === '(') depth += 1;
    else if (text[i] === ')' && --depth === 0) return text.slice(open + 1, i);
  }
  return null;
}

// ROSTER § How HR ids are read: `ruled`, `reading`, or a reversal/supersession by one or more rows,
// optionally followed by exactly one balanced parenthesis that ends the status.
function admitted(status: string): boolean {
  if (status === 'ruled' || status === 'reading') return true;
  const head = STATUS_HEAD.exec(status);
  if (!head) return false;
  const rest = status.slice(head[0].length);
  if (rest === '') return true;
  if (!rest.startsWith(' (')) return false;
  const part = balanced(rest, 1);
  return part !== null && part.trim() !== '' && rest.length === part.length + 3;
}

function cells(row: string): string[] {
  return row.split(/(?<!\\)\|/).slice(1, -1).map((c) => c.trim());
}

export class RosterStatusFailure extends Error {}

function scan(contents: string): Verdict {
  const definitions: string[] = [];
  const anchors: Anchor[] = [];
  const mismatches: { line: number; anchor: string; bold: string }[] = [];
  const defined: Definition[] = [];
  const citations: { line: number; id: string }[] = [];
  const indexed: { line: number; id: string }[] = [];
  const labelMismatch: { line: number; label: string; link: string }[] = [];
  let statusColumn = -1;
  let inTable = false;
  let readings: boolean | null = null; // null: no `## Readings` heading seen
  contents.split('\n').forEach((text, offset) => {
    const line = offset + 1;
    const row = text.startsWith('|');
    if (row && !inTable) statusColumn = cells(text).findIndex((c) => c.toLowerCase() === 'status');
    inTable = row;
    if (/^## /.test(text)) readings = /^## Readings\b/.test(text) ? true : readings === null ? null : false;
    const canonicalAt = new Set<number>();
    for (const match of text.matchAll(DEFINITION)) {
      const [, anchor = '', bold = ''] = match;
      if (anchor !== bold) mismatches.push({ line, anchor, bold });
      definitions.push(anchor);
      canonicalAt.add((match.index ?? 0) + '<a '.length);
      const after = (match.index ?? 0) + match[0].length;
      const open = /^\s*\(/.exec(text.slice(after));
      const paren = open ? balanced(text, after + open[0].length - 1) : null;
      let status: string | null = paren;
      if (row && statusColumn >= 0) status = cells(text)[statusColumn] ?? null;
      defined.push({ id: String(Number(anchor)), line, status: status === null ? null : status.trim(), paren: paren === null ? null : paren.trim() });
    }
    for (const match of text.matchAll(CITATION)) {
      const digits = match[1] ?? match[2] ?? '';
      if (/^\d{1,15}$/.test(digits)) citations.push({ line, id: String(Number(digits)) });
    }
    const entry = readings === true ? INDEX_ENTRY.exec(text) : null;
    if (entry) {
      indexed.push({ line, id: String(Number(entry[1])) });
      if (Number(entry[1]) !== Number(entry[2])) labelMismatch.push({ line, label: String(Number(entry[1])), link: String(Number(entry[2])) });
    }
    for (const match of text.matchAll(ANCHOR)) {
      const column = match.index ?? 0;
      anchors.push({ line, column: column + 1, raw: match[1] ?? '', canonical: canonicalAt.has(column) });
    }
  });
  const ids: number[] = [];
  for (const digits of definitions) {
    const id = Number(digits);
    if (digits.length > 15 || !Number.isSafeInteger(id)) {
      throw new RosterStatusFailure(`HR id ${digits.slice(0, 24)}${digits.length > 24 ? '...' : ''} is not a safe integer`);
    }
    ids.push(id);
  }
  const ceiling = ids.length + ID_HEADROOM;
  for (const id of ids) {
    if (id > ceiling) throw new RosterStatusFailure(`HR-${id} exceeds the definition count plus ${ID_HEADROOM} (${ceiling})`);
  }
  const counts = new Map<string, number>();
  for (const { raw } of anchors) {
    const key = /^\d{1,15}$/.test(raw) ? String(Number(raw)) : raw.toLowerCase();
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  const duplicates = [...counts]
    .filter(([, n]) => n > 1)
    .map(([id, count]) => ({ id, count }))
    .sort((a, b) => a.id.localeCompare(b.id, 'en', { numeric: true }));
  const present = new Set(ids);
  const max = ids.length ? Math.max(...ids) : 0;
  const gaps: number[] = [];
  let gapCount = 0;
  for (let id = 1; id <= max; id += 1) {
    if (present.has(id)) continue;
    gapCount += 1;
    if (gaps.length < GAP_LISTING) gaps.push(id);
  }
  if (readings === null) throw new RosterStatusFailure('no `## Readings` heading, so the readings index cannot be read');
  const badStatus = defined
    .filter((d) => d.status === null || !admitted(d.status))
    .map((d) => ({ line: d.line, id: d.id, word: d.status ?? '' }));
  const known = new Set(defined.map((d) => d.id));
  const twoStatuses = defined
    .filter((d) => d.paren !== null && d.status !== null && d.paren !== d.status)
    .map((d) => ({ line: d.line, id: d.id, cell: d.status ?? '', paren: d.paren ?? '' }));
  const seen = new Set<string>();
  const dangling = citations.filter((c) => {
    const key = `${c.line}:${c.id}`;
    if (known.has(c.id) || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
  const reading = new Map(defined.filter((d) => d.status === 'reading').map((d) => [d.id, d]));
  const listed = new Set(indexed.map((e) => e.id));
  const unindexed = [...reading.values()].filter((d) => !listed.has(d.id)).map(({ line, id }) => ({ line, id }));
  const statusOf = new Map(defined.map((d) => [d.id, d.status ?? '']));
  const misindexed = indexed
    .filter((e) => !reading.has(e.id))
    .map(({ line, id }) => ({ line, id, status: statusOf.has(id) ? statusOf.get(id) || 'no status' : 'not defined' }));
  return { ids, duplicates, mismatches, nonCanonical: anchors.filter((a) => !a.canonical), gaps, gapCount, badStatus, twoStatuses, labelMismatch, dangling, unindexed, misindexed, definitions: defined };
}

// One parser owns the status vocabulary and row extraction. Consumers that need
// status-aware policy receive only a complete, unambiguous status map; a roster
// whose status rows cannot be trusted is unread, never a partly useful table.
export function parseRosterStatuses(contents: string): readonly RosterStatus[] {
  const verdict = scan(contents);
  if (verdict.ids.length === 0) throw new RosterStatusFailure('no HR definitions');
  const statusFindings = verdict.duplicates.length + verdict.mismatches.length + verdict.nonCanonical.length
    + verdict.badStatus.length + verdict.twoStatuses.length;
  if (statusFindings) throw new RosterStatusFailure(`the roster has ${statusFindings} HR definition or status finding(s)`);
  return verdict.definitions.map(({ id, line, status }) => ({ id, line, status: status ?? '' }));
}

function main(argv: string[]): number {
  if (argv.length > 1) {
    console.error('clause-id-guard: usage: clause_id_guard.mts [<roster.md>]');
    return 2;
  }
  const path = argv[0] ?? 'docs/ROSTER.md';
  if (/[,:\r\n]/.test(path)) {
    console.error('clause-id-guard: refusing a path holding a comma, colon or line break; an annotation cannot name it');
    return 2;
  }
  let contents: string;
  try {
    contents = readFileSync(path, 'utf8');
  } catch (error) {
    console.error(`clause-id-guard: cannot read ${path}: ${(error as Error).message}`);
    return 2;
  }
  let verdict: Verdict;
  try {
    verdict = scan(contents);
  } catch (error) {
    if (!(error instanceof RosterStatusFailure)) throw error;
    console.error(`clause-id-guard: ${error.message} in ${path}; refusing to read it as a gap`);
    return 2;
  }
  if (verdict.ids.length === 0) {
    console.error(`clause-id-guard: no HR definitions in ${path}; refusing to read an empty id space as clean`);
    return 2;
  }
  for (const { id, count } of verdict.duplicates) {
    console.log(`::error file=${path}::HR-${id} is anchored ${count} times; an HR id is never reused (HR-2)`);
  }
  for (const { line, anchor, bold } of verdict.mismatches) {
    console.log(`::error file=${path},line=${line}::anchor hr-${anchor} labels HR-${bold}; the two must agree`);
  }
  for (const { line, column } of verdict.nonCanonical) {
    console.log(`::error file=${path},line=${line},col=${column}::an HR anchor not in the canonical form <a id="hr-N"></a>**HR-N** (HR-2)`);
  }
  for (const { line, id, word } of verdict.badStatus) {
    const shown = word ? `"${word.length > 80 ? `${word.slice(0, 80)}...` : word}"` : 'no status';
    console.log(`::error file=${path},line=${line}::HR-${id} has ${shown}, not an admitted status: ruled, reading, or reversed by / superseded by HR-m with an optional (part) (How HR ids are read)`);
  }
  const clip = (t: string): string => (t.length > 80 ? `${t.slice(0, 80)}...` : t);
  for (const { line, id, cell, paren } of verdict.twoStatuses) {
    console.log(`::error file=${path},line=${line}::HR-${id} carries two statuses: its Status cell "${clip(cell)}" and its parenthesis "${clip(paren)}"; a row has one`);
  }
  for (const { line, label, link } of verdict.labelMismatch) {
    console.log(`::error file=${path},line=${line}::§ Readings' index entry on line ${line} labels HR-${label} but links #hr-${link}; the two must agree`);
  }
  for (const { line, id } of verdict.dangling) {
    console.log(`::error file=${path},line=${line}::line ${line} cites HR-${id}, which no row defines`);
  }
  for (const { line, id } of verdict.unindexed) {
    console.log(`::error file=${path},line=${line}::HR-${id} is a reading with no entry in § Readings' index`);
  }
  for (const { line, id, status } of verdict.misindexed) {
    console.log(`::error file=${path},line=${line}::§ Readings' index lists HR-${id}, whose row is not a reading (${status.length > 80 ? `${status.slice(0, 80)}...` : status})`);
  }
  if (verdict.gapCount) {
    const more = verdict.gapCount - verdict.gaps.length;
    const listed = verdict.gaps.map((id) => `HR-${id}`).join(', ');
    console.log(`::notice file=${path}::HR id gaps (reported, never failed): ${listed}${more ? `, and ${more} more` : ''}`);
  }
  const findings = verdict.duplicates.length + verdict.mismatches.length + verdict.nonCanonical.length
    + verdict.badStatus.length + verdict.twoStatuses.length + verdict.labelMismatch.length + verdict.dangling.length + verdict.unindexed.length + verdict.misindexed.length;
  if (findings) return 1;
  console.log(`clause-id-guard: ${verdict.ids.length} HR definitions, unique, each with an admitted status, no dangling citation, the readings index in parity, in ${path}`);
  return 0;
}

const invoked = process.argv[1] !== undefined && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invoked) process.exit(main(process.argv.slice(2)));
