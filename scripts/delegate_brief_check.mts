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
//   3. A TOOLING FAILURE IS NOT A FINDING: wrong usage, an unreadable brief or canon, a BRIEF path
//      holding `,` `:` or a line break (it is the annotation's file= property, which those would forge),
//      or a CANON path holding a line break (it is written into the annotation's message, where a line
//      break would start a second workflow command; its commas and colons are harmless there and stay
//      allowed, so a checkout under `Code, work/` or a Windows `C:\` path runs) exits 2 on stderr with
//      nothing on stdout, so "could not look" never reads as "looked and found".
//
//   4. THE HOST BLOCK (zheref/hatsu#478) is read the same way, between `<!-- delegate-host:begin -->`
//      and `<!-- delegate-host:end -->` (§ *Host workload budget*). Where the canon carries it, every
//      line must appear in the brief too ("host-block line n of m"), and the brief must carry exactly
//      one line starting `Heavy turn:` (after whitespace and an optional `-`, `*` or `+` bullet), and
//      that line must read `Heavy turn: granted, workers <n>` (n >= 1) or `Heavy turn: withheld` (a
//      `- ` bullet allowed). None, several, or a malformed one fail at exit 1, each malformed line
//      named. A canon with no host markers checks the wait block alone; a host marker missing, doubled
//      or out of order, or an empty host block, is exit 2 as in rule 1. It checks delegate briefs, not
//      hanten's reviewer prompts.
//
// Usage: node scripts/delegate_brief_check.mts [--canon <WORKFLOW.md>] <brief-file>
//        node scripts/delegate_brief_check.mts [--canon <WORKFLOW.md>] --print | --print-host
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const BEGIN = '<!-- delegate-wait:begin -->';
const END = '<!-- delegate-wait:end -->';
const HOST_BEGIN = '<!-- delegate-host:begin -->';
const HOST_END = '<!-- delegate-host:end -->';
const TURN = /^(?:- )?Heavy turn: (?:granted, workers [1-9]\d*|withheld)$/;
// Every line that claims to be a turn line, well formed or not, is counted (P-1: a second, conflicting
// line beside a valid one must not pass).
const TURN_HEAD = /^(?:[-*+]\s*)?Heavy turn:/;
const USAGE = 'usage: delegate_brief_check.mts [--canon <WORKFLOW.md>] (<brief-file> | --print | --print-host)';

function refuse(message: string): never {
  console.error(`delegate-brief-check: ${message}`);
  process.exit(2);
}
function read(path: string, what: string): string {
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
let printHost = false;
for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === '--canon') {
    if (i + 1 >= args.length || args[i + 1] === '') refuse(`--canon needs a path; ${USAGE}`);
    canonPath = args[(i += 1)];
  } else if (arg === '--print') {
    print = true;
  } else if (arg === '--print-host') {
    printHost = true;
  } else if (arg.startsWith('-')) {
    refuse(`unknown flag ${arg}; ${USAGE}`);
  } else if (brief === null && arg !== '') {
    brief = arg;
  } else {
    refuse(USAGE);
  }
}
if ((print ? 1 : 0) + (printHost ? 1 : 0) + (brief !== null ? 1 : 0) !== 1) refuse(USAGE);
if (/[\r\n]/.test(canonPath)) refuse('the canon path holds a line break');

const canonLines = read(canonPath, 'canon').split(/\r?\n/);
const begins = canonLines.flatMap((line, i) => (line.trim() === BEGIN ? [i] : []));
const ends = canonLines.flatMap((line, i) => (line.trim() === END ? [i] : []));
if (begins.length !== 1 || ends.length !== 1 || ends[0] < begins[0]) {
  refuse(`${canonPath} must carry exactly one ${BEGIN} … ${END} block (found ${begins.length} begin, ${ends.length} end)`);
}
const block = canonLines.slice(begins[0] + 1, ends[0]).map((line) => line.trim()).filter((line) => line !== '');
if (block.length === 0) refuse(`${canonPath}'s delegate-wait block is empty`);

const hostBegins = canonLines.flatMap((line, i) => (line.trim() === HOST_BEGIN ? [i] : []));
const hostEnds = canonLines.flatMap((line, i) => (line.trim() === HOST_END ? [i] : []));
let host: string[] = [];
if (hostBegins.length > 0 || hostEnds.length > 0) {
  if (hostBegins.length !== 1 || hostEnds.length !== 1 || hostEnds[0] < hostBegins[0]) {
    refuse(`${canonPath} must carry at most one ${HOST_BEGIN} … ${HOST_END} block (found ${hostBegins.length} begin, ${hostEnds.length} end)`);
  }
  host = canonLines.slice(hostBegins[0] + 1, hostEnds[0]).map((line) => line.trim()).filter((line) => line !== '');
  if (host.length === 0) refuse(`${canonPath}'s delegate-host block is empty`);
}

if (print) {
  process.stdout.write(`${block.join('\n')}\n`);
  process.exit(0);
}
if (printHost) {
  if (host.length === 0) refuse(`${canonPath} carries no ${HOST_BEGIN} … ${HOST_END} block`);
  process.stdout.write(`${host.join('\n')}\n`);
  process.exit(0);
}
const briefPath = brief as string;
// The brief's path is the annotation's file= property, so `,` and `:` are refused there too (rule 3).
if (/[,:\r\n]/.test(briefPath)) refuse('the brief path holds a comma, colon or line break');
const briefLines = read(briefPath, 'brief').split(/\r?\n/).map((line) => line.trim());
const have = new Set(briefLines);
const missing = block.flatMap((line, i) => (have.has(line) ? [] : [i + 1]));
for (const n of missing) {
  console.log(`::error file=${briefPath}::delegate brief lacks wait-block line ${n} of ${block.length} word for word (${canonPath} § Delegate briefs): ${block[n - 1]}`);
}
const hostMissing = host.flatMap((line, i) => (have.has(line) ? [] : [i + 1]));
for (const n of hostMissing) {
  console.log(`::error file=${briefPath}::delegate brief lacks host-block line ${n} of ${host.length} word for word (${canonPath} § Host workload budget): ${host[n - 1]}`);
}
// Brief text is escaped as a workflow-command message the way the Actions toolkit does -- `%`, then `\r`
// and `\n` -- so neither a `%` nor a lone CR inside a line (the brief splits on CRLF or LF, so a bare CR
// survives) can forge a second command on the runner, which reads a CR as a line end.
const escape = (text: string): string => text.replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
const turnLines = host.length > 0 ? briefLines.filter((line) => TURN_HEAD.test(line)) : [];
const malformed = turnLines.filter((line) => !TURN.test(line));
const turnsOk = host.length === 0 || (turnLines.length === 1 && malformed.length === 0);
const turnForm = `exactly one of 'Heavy turn: granted, workers <n>' (n >= 1) or 'Heavy turn: withheld' (${canonPath} § Host workload budget)`;
if (host.length > 0 && turnLines.length !== 1) {
  console.log(`::error file=${briefPath}::delegate brief carries ${turnLines.length} Heavy turn lines; ${turnForm}`);
}
for (const line of malformed) {
  console.log(`::error file=${briefPath}::delegate brief carries a malformed Heavy turn line: ${escape(line)}; ${turnForm}`);
}
if (missing.length > 0 || hostMissing.length > 0 || !turnsOk) process.exit(1);
const hostNote = host.length > 0 ? `, all ${host.length} host-block lines and one Heavy turn line` : '';
console.log(`delegate-brief-check: ${briefPath} carries all ${block.length} wait-block lines${hostNote}`);
