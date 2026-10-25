#!/usr/bin/env node
// zheref/hatsu#473: a delegate's brief carries docs/WORKFLOW.md § *Delegate briefs — how a delegate
// waits*'s wait block word for word, so no delegate waits on its own unbounded watch.
//
//   1. THE CANON IS READ, NEVER COPIED HERE. The block is every line strictly between
//      `<!-- delegate-wait:begin -->` and `<!-- delegate-wait:end -->` in the canon file (default
//      docs/WORKFLOW.md beside this script), blank lines dropped. A canon with no block, a marker
//      missing or doubled, or an empty block is a tooling failure: exit 2.
//   2. EVERY CANON LINE MUST APPEAR AS A LINE OF THE BRIEF, compared after trimming surrounding
//      whitespace and nothing else. A dropped line, a reworded ceiling and a paraphrase each fail:
//      exit 1, one `::error::` line per missing canon line, numbered, on stdout.
//   3. A TOOLING FAILURE IS NOT A FINDING: wrong usage, an unreadable brief or canon, or a path
//      holding `,` `:` or a line break (it would forge annotation properties) exits 2 on stderr with
//      nothing on stdout, so "could not look" never reads as "looked and found".
//
// Usage: node scripts/delegate_brief_check.mts [--canon <WORKFLOW.md>] <brief-file>
//        node scripts/delegate_brief_check.mts [--canon <WORKFLOW.md>] --print
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const BEGIN = '<!-- delegate-wait:begin -->';
const END = '<!-- delegate-wait:end -->';
const USAGE = 'usage: delegate_brief_check.mts [--canon <WORKFLOW.md>] (<brief-file> | --print)';

function refuse(message: string): never {
  console.error(`delegate-brief-check: ${message}`);
  process.exit(2);
}
function read(path: string, what: string): string {
  if (/[,:\r\n]/.test(path)) refuse(`the ${what} path holds a comma, colon or line break`);
  try {
    return readFileSync(path, 'utf8');
  } catch (error) {
    refuse(`cannot read the ${what} ${path}: ${(error as Error).message}`);
  }
}

const args = process.argv.slice(2);
let canonPath = fileURLToPath(new URL('../docs/WORKFLOW.md', import.meta.url));
let brief: string | null = null;
let print = false;
for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === '--canon') {
    if (i + 1 >= args.length || args[i + 1] === '') refuse(`--canon needs a path; ${USAGE}`);
    canonPath = args[(i += 1)];
  } else if (arg === '--print') {
    print = true;
  } else if (arg.startsWith('-')) {
    refuse(`unknown flag ${arg}; ${USAGE}`);
  } else if (brief === null && arg !== '') {
    brief = arg;
  } else {
    refuse(USAGE);
  }
}
if (print === (brief !== null)) refuse(USAGE);

const canonLines = read(canonPath, 'canon').split(/\r?\n/);
const begins = canonLines.flatMap((line, i) => (line.trim() === BEGIN ? [i] : []));
const ends = canonLines.flatMap((line, i) => (line.trim() === END ? [i] : []));
if (begins.length !== 1 || ends.length !== 1 || ends[0] < begins[0]) {
  refuse(`${canonPath} must carry exactly one ${BEGIN} … ${END} block (found ${begins.length} begin, ${ends.length} end)`);
}
const block = canonLines.slice(begins[0] + 1, ends[0]).map((line) => line.trim()).filter((line) => line !== '');
if (block.length === 0) refuse(`${canonPath}'s delegate-wait block is empty`);

if (print) {
  process.stdout.write(`${block.join('\n')}\n`);
  process.exit(0);
}
const briefPath = brief as string;
const have = new Set(read(briefPath, 'brief').split(/\r?\n/).map((line) => line.trim()));
const missing = block.flatMap((line, i) => (have.has(line) ? [] : [i + 1]));
for (const n of missing) {
  console.log(`::error file=${briefPath}::delegate brief lacks wait-block line ${n} of ${block.length} word for word (docs/WORKFLOW.md § Delegate briefs): ${block[n - 1]}`);
}
if (missing.length > 0) process.exit(1);
console.log(`delegate-brief-check: ${briefPath} carries all ${block.length} wait-block lines`);
