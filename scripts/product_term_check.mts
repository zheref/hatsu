#!/usr/bin/env node
// product_term_check.mts — refuse text that names a product term in a public pair file (zheref/hatsu#354,
// wave 3 of the SDD assessment: porting closes the loop). The rule, the CLI and the exit codes live here;
// scripts/product_term_check.sh is the forwarding shim hatsu:bankai-rule § 4 and the fixture call.
//
// docs/config/ports.md § *Product-level divergence* and claude/skills/bankai-rule/SKILL.md § 1 forbid a
// product, screen, business-rule or object-id word in a pair file's `rationale` and `redraft`: a pair file
// (zheref/bankai-handbooks handbooks/ports/*.md) is public and technology-level, and the product words
// live in the private spec folder's `## Platform decisions`. Until now only the prose asked for it, and
// scripts/private_name_check.sh (frozen under BC-11) matches private REPOSITORY names only. This guard is
// the mechanical half: it compares text against the maintainer's own PRODUCT-TERM LIST, kept outside
// every public tree:
//
//   ${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/product-terms   (--terms-file <path> names another; a fixture's)
//
// One term per line, `#` comments, blanks ignored, ends trimmed. A term is a literal phrase -- a product
// name, a screen, a business rule's words, a tier or plan name -- and it is matched by TOKENS: the term
// and every line are both read lower-case with a camel-case boundary (`OrderReview` → `order review`)
// and every run of non-alphanumerics (space, `-`, `_`, `.`, `/`, `(`) as one separator, and the term's
// words may touch or be one separator apart, so `order review`, `Order-Review`, `order_review`,
// `OrderReview` and `orderreview` are one term (two spellings of one term in the list share one index),
// while `preorder review`, `orders review` and `checkouts` (for `checkout`) are other words: whole tokens,
// never substrings. A plural or an inflection is its own line. A line holding `%`, `&`, `<`, `\`, `*`, a
// backtick or a non-ASCII byte is also read normalised, twice, as private_name_check.sh reads it -- %XX
// decoded, UTF-8 decoded, HTML entities decoded, inline tags and backslash escapes before punctuation
// dropped, NFKC applied, format characters deleted and every dash folded to `-` -- plus this guard's own
// step: combining marks and default-ignorable code points deleted (a combining acute, a variation
// selector, a hangul filler); then once more with HTML comments, `*` and backticks removed -- and a hit
// found only that way says so at its original line. Those transformations are the whole claim: a
// CONFUSABLE letter (a Cyrillic о for a Latin o) is not folded, since no confusables table is applied.
// The token alphabet is ASCII letters and digits on both sides -- a term goes through the same folding
// (`Café` reads `cafe`), and one that leaves fewer than two ASCII letters or digits (a term in another
// script) is refused by name, never held as nothing. An input holding a NUL byte in its first 8 KiB (a
// binary, a UTF-16 file without its BOM) is a refusal, never a skip: a pair row is text by construction.
//
// The one rule that needs no list: an OBJECT REFERENCE in a table row. A line whose first non-blank
// character is `|` is a row of the equivalence or drift table (the only place a pair file carries a
// ruling), and an object id `<CODE>-<IS|PR>-#<n>` or an invocation-grammar ref `<CODE>#<n>`
// (docs/PUBLIC-REDACTION.md § *The object-id rule*; `RA-IS-#12`, `FI#7`; two or three capitals) there is
// a hit by shape, listed or not: a pair row never cites a product's issue or PR. The same shape in a
// header comment or in prose is not a row and is not judged by this rule (the template's header cites a
// Hatsu ruling by object id); a `|`-led line inside a fenced block IS judged as a row -- a safe
// over-count; `PT-<n>`, `SW-{n}` and the other rule ids carry no `#`.
//
// The output NEVER prints a term: a hit is `<file>:<line>: product term #<k>`, an index into the list
// (sorted with LC_ALL=C, a second spelling of one term sharing the first's index); a path or --label that
// contains a term between separators is printed with it replaced by `<term #k>`, and one that holds a
// term inside a camel-case word or only once normalised is withheld whole. `--resolve <k>` prints entry k
// to stderr only when stderr is a terminal and is refused otherwise -- the whole guarantee: a pty wrapper
// (`script`, a terminal recorder, tmux's pipe-pane) defeats it, so `--resolve` is the maintainer's, typed
// at their own terminal, NEVER a session's (the ignore file's rule, docs/PUBLIC-REDACTION.md). The ok line
// carries the list's size only under --verbose.
//
// A list that cannot be read is a refusal, never a pass. NO DEFAULT LIST IS `missing-configuration`
// (exit 2): the guard cannot say a row is product-free with nothing to compare it to, and the file is
// the maintainer's -- written by hand, named in docs/PUBLIC-REDACTION.md § *How it is guarded* and
// docs/config/ports.md § *The product-term guard* -- NEVER by a session, never committed to a public
// tree (it would publish what it guards). An empty or comment-only list is exit 2 unless --allow-empty.
//
// Usage:
//   product_term_check.sh [--terms-file <path>] [--allow-empty] [--label <name>] [--verbose] [<file>|-]...
//   product_term_check.sh [--terms-file <path>] --resolve <k>
//
//   --terms-file   one term per line (`#` comments, blanks ignored), INSTEAD of the default list.
//   --allow-empty  an empty list is clean (exit 0) instead of a refusal; the row rule still runs.
//   --label        the name a stdin read is reported under (default `<stdin>`); a control character in it is refused.
//   -              read stdin (once).
//
// Exit codes: 0 clean, 1 a product term or an object reference in a row found, 2 wiring -- no list
// (missing-configuration), an unreadable list or file, an input that is not text, a term that leaves
// fewer than two ASCII letters or digits, stdin given twice, a bad argument or label, --resolve off a
// terminal, or the scan failing. A guard that cannot read its list never reads green.
//
// BC-11 / HR-171: a three-way verdict is TypeScript's, so this guard is TypeScript behind a shell shim
// (the cleanup_path_admit pattern). Like private_name_check.sh it is owed to a nen verb beside the
// private-name one (unfiled at the time of writing; docs/PROCESS.md § *Residue and owned dependencies*)
// and is frozen to fixes once that verb lands.
import { readFileSync, statSync, lstatSync } from 'node:fs';
import { join } from 'node:path';

const USAGE = `product_term_check -- refuse text that names a product term in a public pair file.

Usage:
  product_term_check.sh [--terms-file <path>] [--allow-empty] [--label <name>] [--verbose] [<file>|-]...
  product_term_check.sh [--terms-file <path>] --resolve <k>

  --terms-file   one term per line (\`#\` comments, blanks ignored), INSTEAD of the default list
                 (\${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/product-terms, the maintainer's).
  --allow-empty  an empty list is clean (exit 0) instead of a refusal; the row rule still runs.
  --label        the name a stdin read is reported under (default \`<stdin>\`).
  -              read stdin (once).

Exit codes: 0 clean, 1 a product term or an object reference in a row found, 2 wiring (no list is
missing-configuration; an unreadable list or file; an input that is not text; a term with fewer than two
ASCII letters or digits; stdin twice; a bad argument or label; --resolve off a terminal).
docs/config/ports.md section The product-term guard.`;

const DOC = 'docs/config/ports.md section The product-term guard';

class Die extends Error {}
function die(msg: string): never {
  throw new Die(msg);
}

// --- the token reading -------------------------------------------------------------------------------
// A camel-case boundary and every run of non-alphanumerics become one space; lower-case; trimmed.
function tokens(s: string): string {
  return s
    .replace(/(?<=[a-z0-9])(?=[A-Z])/g, ' ')
    .replace(/(?<=[A-Z])(?=[A-Z][a-z])/g, ' ')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/^ /, '')
    .replace(/ $/, '');
}

// --- the normalised reading, as the private-name guard reads a line, plus this guard's own step -------
const ENTITIES: Record<string, string> = {
  amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ',
  hyphen: '-', dash: '-', minus: '-', ndash: '-', mdash: '-', lowbar: '_',
  UnderBar: '_', period: '.', sol: '/', bsol: '\\', colon: ':', commat: '@',
  num: '#', percnt: '%', shy: '', zwsp: '', zwj: '', zwnj: '', NewLine: ' ',
};
function cp(c: number): string {
  return c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff) ? '�' : String.fromCodePoint(c);
}
const utf8 = new TextDecoder('utf-8', { fatal: false });
// `line` is the raw bytes read as latin1 (one char per byte), so %XX decoding runs on bytes.
function norm(line: string): string {
  const bytes = line.replace(/%([0-9A-Fa-f]{2})/g, (_m, h: string) => String.fromCharCode(parseInt(h, 16)));
  let s = utf8.decode(Buffer.from(bytes, 'latin1'));
  for (let i = 0; i < 2; i++) {
    s = s.replace(/&#[xX]([0-9A-Fa-f]{1,6});/g, (_m, h: string) => cp(parseInt(h, 16)));
    s = s.replace(/&#([0-9]{1,7});/g, (_m, d: string) => cp(parseInt(d, 10)));
    s = s.replace(/&([A-Za-z][A-Za-z0-9]{1,31});/g, (m, name: string) => (name in ENTITIES ? ENTITIES[name] : m));
  }
  s = s.replace(/<\/?[A-Za-z][^<>]*>/g, '');
  s = s.replace(/\\(?=[!-\/:-@\[-`{-~])/g, '');
  s = s.normalize('NFKC');
  // This guard's own step, beyond the frozen sibling's: combining marks and default-ignorable code
  // points go, so a combining acute, a variation selector or a hangul filler inside a word still reads
  // as the term. No confusables table: a Cyrillic letter for a Latin one stays what it is.
  s = s.normalize('NFKD').replace(/\p{Mn}/gu, '').replace(/\p{Default_Ignorable_Code_Point}/gu, '').normalize('NFKC');
  s = s.replace(/\p{Cf}/gu, '');
  s = s.replace(/\p{Pd}/gu, '-');
  return s;
}
function norm2(s: string): string {
  return s.replace(/<!--.*?-->/g, '').replace(/[*`]/g, '');
}
function trig(s: string): boolean {
  return /[%&<\\*`]|[^\x00-\x7F]/.test(s);
}

// --- the list ------------------------------------------------------------------------------------------
type List = { raw: string[]; index: Map<string, number>; words: Map<number, string[]>; re: RegExp | null; n: number };
function buildList(raw: string[]): List {
  const index = new Map<string, number>();
  const words = new Map<number, string[]>();
  const pats: string[] = [];
  raw.forEach((entry, i) => {
    // The term goes through the same normalised reading a line does (NFKD, marks deleted), so `Café`
    // reads `cafe` on both sides; the token alphabet is ASCII letters and digits, so a term written in
    // another script cannot be held and is refused by name, never read as nothing.
    const t = tokens(norm(Buffer.from(entry, 'utf8').toString('latin1')));
    if (t.length < 2) {
      die(
        `entry ${i + 1} of the sorted, comment-stripped list (the --resolve index, not a file line) normalises to ` +
          `${t.length ? 'one' : 'no'} ASCII letter or digit -- the token alphabet is [a-z0-9] after NFKD folding (${DOC}), so it ` +
          `would ${t.length ? 'flag everything' : 'never match'}; remove it, or write it in ASCII`,
      );
    }
    const key = t.replace(/ /g, '');
    if (index.has(key)) return; // a second spelling of one term shares the first's index
    index.set(key, i + 1);
    const w = t.split(' ');
    words.set(i + 1, w);
    pats.push(w.join(' ?'));
  });
  pats.sort((a, b) => b.length - a.length);
  const re = pats.length ? new RegExp(`(?<![a-z0-9])(${pats.join('|')})(?![a-z0-9])`, 'g') : null;
  return { raw, index, words, re, n: index.size };
}
function keyOf(list: List, match: string): number {
  return list.index.get(match.replace(/ /g, '')) ?? 0;
}
function* hitsIn(list: List, tokenised: string): Generator<number> {
  if (!list.re) return;
  list.re.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = list.re.exec(tokenised)) !== null) yield keyOf(list, m[1]);
}

// --- what a shown path or label may print --------------------------------------------------------------
function redact(list: List, s: string): string {
  if (!list.re) return s;
  const hit = new Set<number>();
  for (const k of hitsIn(list, tokens(s))) hit.add(k);
  let r = s;
  for (const k of [...hit].sort((a, b) => a - b)) {
    const w = list.words.get(k)!;
    const p = new RegExp(`(?<![A-Za-z0-9])${w.join('[^A-Za-z0-9]*')}(?![A-Za-z0-9])`, 'gi');
    r = r.replace(p, `<term #${k}>`);
  }
  return r;
}
function safe(list: List, s: string, kind: string): string {
  if (!list.re) return s;
  const r = redact(list, s);
  // A term the separator-bounded rewrite could not reach (inside a camel-case word, `myOrderReview`)
  // still reads on the token reading: the whole path or label is withheld, never printed.
  for (const k of hitsIn(list, tokens(r))) return `<${kind} withheld: term #${k}>`;
  if (!trig(r)) return r;
  const m = norm(Buffer.from(r, 'utf8').toString('latin1'));
  for (const v of [m, norm2(m)]) for (const k of hitsIn(list, tokens(v))) return `<${kind} withheld: term #${k}>`;
  return r;
}

// --- the scan --------------------------------------------------------------------------------------------
const OID = /(?<![A-Za-z0-9])[A-Z]{2,3}(?:-(?:IS|PR)-)?#[0-9]+(?![A-Za-z0-9])/;
const HOW = ' (spelt through an escape, entity, encoding, markup or invisible character)';
type Scan = { list: List; out: string[]; hits: number; bad: boolean };
function hitTerm(sc: Scan, shown: string, n: number, k: number, how: string): void {
  sc.out.push(`${shown}:${n}: product term #${k}${how} -- restate it technology-level, or move the words to the spec folder (${DOC})`);
  sc.hits++;
}
function hitOid(sc: Scan, shown: string, n: number, how: string): void {
  sc.out.push(`${shown}:${n}: object reference in a row${how} -- a pair row never cites a product object (${DOC})`);
  sc.hits++;
}
// `l` is the line's bytes as latin1.
function scanLine(sc: Scan, l: string, shown: string, n: number): void {
  const seen = new Set<number>();
  let oidSeen = false;
  const row = /^\s*\|/.test(l);
  for (const k of hitsIn(sc.list, tokens(l))) {
    if (seen.has(k)) continue;
    hitTerm(sc, shown, n, k, '');
    seen.add(k);
  }
  if (row && OID.test(l)) {
    hitOid(sc, shown, n, '');
    oidSeen = true;
  }
  if (!trig(l)) return;
  const m = norm(l);
  for (const v of [m, norm2(m)]) {
    for (const k of hitsIn(sc.list, tokens(v))) {
      if (seen.has(k)) continue;
      hitTerm(sc, shown, n, k, HOW);
      seen.add(k);
    }
    const vrow = /^\s*\|/.test(v);
    if ((row || vrow) && !oidSeen && OID.test(v)) {
      hitOid(sc, shown, n, HOW);
      oidSeen = true;
    }
  }
}
function scanBytes(sc: Scan, buf: Buffer, shown: string): void {
  const head = buf.subarray(0, 8192);
  let text: Buffer = buf;
  if (head.length >= 2 && ((head[0] === 0xff && head[1] === 0xfe) || (head[0] === 0xfe && head[1] === 0xff))) {
    const le = head[0] === 0xff;
    const decoded = new TextDecoder(le ? 'utf-16le' : 'utf-16be', { fatal: false }).decode(buf.subarray(2));
    text = Buffer.from(decoded, 'utf8');
  } else if (head.includes(0)) {
    // A pair row and a pair file are text by construction: a NUL byte (a binary, a UTF-16 file without
    // its BOM) is a refusal, never a skip that reads green (Phinks, hanten on 68eef8cf).
    process.stderr.write(`product_term_check: ${shown} is not text (a NUL byte in its first 8 KiB); a pair row is text, so nothing is clean\n`);
    sc.bad = true;
    return;
  }
  const lines = text.toString('latin1').split('\n');
  if (lines.length && lines[lines.length - 1] === '') lines.pop();
  lines.forEach((raw, i) => scanLine(sc, raw.replace(/\r$/, ''), shown, i + 1));
}
function scanPath(sc: Scan, path: string, shown: string): void {
  let buf: Buffer;
  try {
    if (!statSync(path).isFile()) throw new Error('not a regular file');
    buf = readFileSync(path);
  } catch {
    process.stderr.write(`product_term_check: cannot read ${shown}\n`);
    sc.bad = true;
    return;
  }
  scanBytes(sc, buf, shown);
}

// --- main --------------------------------------------------------------------------------------------------
function main(argv: string[]): number {
  let termsFile: string | undefined;
  let termsExplicit = false;
  if (process.env.XDG_CONFIG_HOME) termsFile = join(process.env.XDG_CONFIG_HOME, 'hatsu', 'product-terms');
  else if (process.env.HOME) termsFile = join(process.env.HOME, '.config', 'hatsu', 'product-terms');
  let allowEmpty = false;
  let label = '<stdin>';
  let verbose = false;
  let resolve: string | undefined;
  const inputs: string[] = [];
  let stdinSeen = false;
  const needs = (flag: string, what: string, i: number): string => {
    const v = argv[i + 1];
    if (v === undefined || v === '') die(`${flag} needs ${what}`);
    return v;
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--terms-file') { termsFile = needs(a, 'a path', i); termsExplicit = true; i++; }
    else if (a === '--allow-empty') allowEmpty = true;
    else if (a === '--label') { label = needs(a, 'a name', i); if (/[\x00-\x1f\x7f]/.test(label)) die('--label holds a control character (a newline would forge hit lines); pass a plain name'); i++; }
    else if (a === '--verbose') verbose = true;
    else if (a === '--resolve') { resolve = needs(a, 'an index', i); i++; }
    else if (a === '--help' || a === '-h') { process.stdout.write(USAGE + '\n'); return 0; }
    else if (a === '--') { for (const rest of argv.slice(i + 1)) { if (rest === '-') { if (stdinSeen) die("stdin ('-') given twice"); stdinSeen = true; } inputs.push(rest); } break; }
    else if (a === '-') { if (stdinSeen) die("stdin ('-') given twice"); stdinSeen = true; inputs.push(a); }
    else if (a.startsWith('-')) die(`unknown option '${a}'`);
    else inputs.push(a);
  }
  if (resolve === undefined && inputs.length === 0) die("nothing to check: pass files or '-'");

  // --- the list: the maintainer's file, never a session's
  if (!termsFile) die('neither XDG_CONFIG_HOME nor HOME is set, so there is no default product-term list; pass --terms-file <path>');
  if (!termsExplicit) {
    let present = true;
    try { lstatSync(termsFile); } catch { present = false; }
    if (!present) {
      die(`missing-configuration: no product-term list at ${termsFile} -- the maintainer writes it by hand (${DOC}), one term per line; a session never does, and nothing is clean until it exists`);
    }
  }
  let listBytes: Buffer;
  try {
    if (!statSync(termsFile).isFile()) throw new Error('not a regular file');
    listBytes = readFileSync(termsFile);
  } catch {
    die(`cannot read the product-term list '${termsFile}'`);
  }
  const rawLines = utf8
    .decode(listBytes)
    .split('\n')
    .map((l) => l.replace(/\r$/, '').replace(/#.*/, '').trim())
    .filter((l) => l.length > 0);
  // LC_ALL=C: byte order, unique
  const sorted = [...new Set(rawLines)].sort((a, b) => Buffer.compare(Buffer.from(a, 'utf8'), Buffer.from(b, 'utf8')));
  if (sorted.length === 0 && !allowEmpty) die('the product-term list holds no terms; pass --allow-empty if that is meant (an empty list checks nothing)');
  const sourceDesc = termsExplicit ? 'the --terms-file list' : "the maintainer's list";
  const list = buildList(sorted);

  // --- --resolve: one entry, to a terminal only
  if (resolve !== undefined) {
    if (!/^[1-9][0-9]*$/.test(resolve)) die(`--resolve needs a positive index, got '${resolve}'`);
    if (!process.stderr.isTTY) die('--resolve prints only to a terminal (stderr is not one), so a term never reaches a log');
    const k = Number(resolve);
    if (k > sorted.length) die(`--resolve ${k}: the list has ${sorted.length} entries`);
    process.stderr.write(`#${k}: ${sorted[k - 1]}\n`);
    return 0;
  }

  // --- the scan
  const sc: Scan = { list, out: [], hits: 0, bad: false };
  for (const a of inputs) {
    if (a === '-') {
      let buf: Buffer;
      try { buf = readFileSync(0); } catch { die('cannot read stdin'); }
      scanBytes(sc, buf, safe(list, label, 'label'));
    } else {
      scanPath(sc, a, safe(list, a, 'path'));
    }
  }
  for (const line of sc.out) process.stdout.write(line + '\n');
  if (sc.bad) die('an input could not be read as text; nothing is clean until every one is');
  const size = verbose ? ` (${list.n} term(s))` : '';
  if (sc.hits) {
    process.stderr.write(`product_term_check: ${sc.hits} mention(s) of a product term or an object reference in a row; the row is restated technology-level, or its words moved to the spec folder, before anything is written (${DOC})\n`);
    return 1;
  }
  process.stdout.write(`product_term_check: ok -- no product term and no object reference in a row (${sourceDesc}${size}; every input read as text)\n`);
  return 0;
}

try {
  process.exitCode = main(process.argv.slice(2));
} catch (e) {
  const msg = e instanceof Error ? e.message : String(e);
  process.stderr.write(`product_term_check: ${msg}\n`);
  process.exitCode = 2;
}
