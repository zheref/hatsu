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
//      whose `hr-N` and `**HR-M**` disagree is refused the same way.
//   3. GAPS ARE REPORTED, NEVER FAILED: one `::notice::` line, exit 0.
//   4. ORDER IS NOT ASSERTED.
//   5. A TOOLING FAILURE IS NOT A FINDING: wrong arity or an unreadable file exits
//      2 on stderr, so "could not look" never reads as "looked and found".
//   6. Ids are whole numbers: HR-2 never matches HR-20.
//
// Usage: node scripts/clause_id_guard.mts [<roster.md>]   (default docs/ROSTER.md)
import { readFileSync } from 'node:fs';

const DEFINITION = /<a id="hr-(\d+)"><\/a>\*\*HR-(\d+)\*\*/g;

interface Verdict {
  readonly ids: readonly number[];
  readonly duplicates: readonly { id: number; count: number }[];
  readonly mismatches: readonly { line: number; anchor: string; bold: string }[];
  readonly gaps: readonly number[];
}

function scan(contents: string): Verdict {
  const ids: number[] = [];
  const mismatches: { line: number; anchor: string; bold: string }[] = [];
  contents.split('\n').forEach((text, index) => {
    for (const match of text.matchAll(DEFINITION)) {
      const [, anchor = '', bold = ''] = match;
      if (anchor !== bold) mismatches.push({ line: index + 1, anchor, bold });
      ids.push(Number(anchor));
    }
  });
  const counts = new Map<number, number>();
  for (const id of ids) counts.set(id, (counts.get(id) ?? 0) + 1);
  const duplicates = [...counts].filter(([, n]) => n > 1).map(([id, count]) => ({ id, count })).sort((a, b) => a.id - b.id);
  const max = ids.length ? Math.max(...ids) : 0;
  const gaps: number[] = [];
  for (let id = 1; id <= max; id += 1) if (!counts.has(id)) gaps.push(id);
  return { ids, duplicates, mismatches, gaps };
}

function main(argv: string[]): number {
  if (argv.length > 1) {
    console.error('clause-id-guard: usage: clause_id_guard.mts [<roster.md>]');
    return 2;
  }
  const path = argv[0] ?? 'docs/ROSTER.md';
  let contents: string;
  try {
    contents = readFileSync(path, 'utf8');
  } catch (error) {
    console.error(`clause-id-guard: cannot read ${path}: ${(error as Error).message}`);
    return 2;
  }
  const verdict = scan(contents);
  if (verdict.ids.length === 0) {
    console.error(`clause-id-guard: no HR definitions in ${path}; refusing to read an empty id space as clean`);
    return 2;
  }
  for (const { id, count } of verdict.duplicates) {
    console.log(`::error file=${path}::HR-${id} is defined ${count} times; an HR id is never reused (HR-2)`);
  }
  for (const { line, anchor, bold } of verdict.mismatches) {
    console.log(`::error file=${path},line=${line}::anchor hr-${anchor} labels HR-${bold}; the two must agree`);
  }
  if (verdict.gaps.length) {
    console.log(`::notice file=${path}::HR id gaps (reported, never failed): ${verdict.gaps.map((id) => `HR-${id}`).join(', ')}`);
  }
  if (verdict.duplicates.length || verdict.mismatches.length) return 1;
  console.log(`clause-id-guard: ${verdict.ids.length} HR definitions, unique, in ${path}`);
  return 0;
}

process.exit(main(process.argv.slice(2)));
