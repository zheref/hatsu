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
//
// Usage: node scripts/clause_id_guard.mts [<roster.md>]   (default docs/ROSTER.md)
import { readFileSync } from 'node:fs';

const DEFINITION = /<a id="hr-(\d+)"><\/a>\*\*HR-(\d+)\*\*/g;
const ANCHOR = /\bid\s*=\s*["']?hr-([^"'\s>]*)/gi;
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
}

class ToolingFailure extends Error {}

function scan(contents: string): Verdict {
  const definitions: string[] = [];
  const anchors: Anchor[] = [];
  const mismatches: { line: number; anchor: string; bold: string }[] = [];
  contents.split('\n').forEach((text, index) => {
    const canonicalAt = new Set<number>();
    for (const match of text.matchAll(DEFINITION)) {
      const [, anchor = '', bold = ''] = match;
      if (anchor !== bold) mismatches.push({ line: index + 1, anchor, bold });
      definitions.push(anchor);
      canonicalAt.add((match.index ?? 0) + '<a '.length);
    }
    for (const match of text.matchAll(ANCHOR)) {
      const column = match.index ?? 0;
      anchors.push({ line: index + 1, column: column + 1, raw: match[1] ?? '', canonical: canonicalAt.has(column) });
    }
  });
  const ids: number[] = [];
  for (const digits of definitions) {
    const id = Number(digits);
    if (digits.length > 15 || !Number.isSafeInteger(id)) {
      throw new ToolingFailure(`HR id ${digits.slice(0, 24)}${digits.length > 24 ? '...' : ''} is not a safe integer`);
    }
    ids.push(id);
  }
  const ceiling = ids.length + ID_HEADROOM;
  for (const id of ids) {
    if (id > ceiling) throw new ToolingFailure(`HR-${id} exceeds the definition count plus ${ID_HEADROOM} (${ceiling})`);
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
  return { ids, duplicates, mismatches, nonCanonical: anchors.filter((a) => !a.canonical), gaps, gapCount };
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
    if (!(error instanceof ToolingFailure)) throw error;
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
  if (verdict.gapCount) {
    const more = verdict.gapCount - verdict.gaps.length;
    const listed = verdict.gaps.map((id) => `HR-${id}`).join(', ');
    console.log(`::notice file=${path}::HR id gaps (reported, never failed): ${listed}${more ? `, and ${more} more` : ''}`);
  }
  if (verdict.duplicates.length || verdict.mismatches.length || verdict.nonCanonical.length) return 1;
  console.log(`clause-id-guard: ${verdict.ids.length} HR definitions, unique, in ${path}`);
  return 0;
}

process.exit(main(process.argv.slice(2)));
