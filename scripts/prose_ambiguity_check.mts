#!/usr/bin/env node
// prose_ambiguity_check.mts — the canon prose ratchet lint (lane `canon-lint`; HR-13, HR-4).
//
// MEASURES Hatsu's own canon prose — claude/skills/*/SKILL.md, claude/agents/*.md,
// claude/rules/*.md and docs/**/*.md, never surfaces/** (generated) — against the rules
// contracts/prose.lint.json declares, PL-01..PL-12, each implemented here under its fixed id:
// by-hand admissions, stale residues, stale nen version literals (compared with
// nen/contract.json's minimum and pinned_ref read at run time), citations that resolve to no
// heading, anchor or bold paragraph lead, bare #N, undated 'verified live', hedges, adjectives,
// undeclared numbers, unfiled residues, malformed open-question markers, and readings cited as
// ruled. Fenced code and quoted words are exempt from every rule. `fail` findings are counted
// against the shrink-only contracts/prose.lint.baseline.json (keyed path + rule + normalised
// text, never a line number); `advisory` findings are printed and never counted.
//
// USAGE  node scripts/prose_ambiguity_check.mts --root <checkout> [--rules <file>]
//          [--baseline <file>] [--base <ref>] [--base-baseline <file>] [--json] [--self-test]
//   --base <ref>  findings only in files changed since the merge base with <ref>, and the
//                 baseline refused if it gained a row over <ref>'s copy (the hanten form); a
//                 base that carries no baseline is said on stdout, and growth goes unchecked
//   --base-baseline <file>  the baseline refused if it gained a row over <file>, the trusted
//                 base revision's copy (the CI form: the whole tree, growth refused, no git)
//   --self-test   runs scripts/prose_ambiguity_check_fixture.mts and relays its exit
//
// EXITS  0 no fail finding outside the baseline and no stale baseline row;
//        1 at least one, each printed `path:line · PL-nn · text` (a stale row as
//          `baseline · PL-nn · path · text`);
//          A baseline row whose path the walk does not read is stale.
//        2 wiring: no or non-Hatsu root, an unreadable or invalid contract or baseline (a
//          rule id paired with another class than its handler's, a class missing a key it
//          needs, a repeated baseline key, a marker row that is not ask-once-per-run), an
//          unlistable directory, an unreadable or non-UTF-8 file, a symlink leaving the root
//          (walked or linked), an unknown flag. Never green over a file it could not read.
//
// Rule ids are fixed: each PL-nn has one handler here and the contract's class for it must
// match (FIXED below); a renumbered or reclassed rule is a wiring refusal, never a silent skip.
//
// OWED TO NEN: the verdict to `nen canon lint` (zheref/nen#481), its acceptance criteria the
// fixture's cases; the citation resolver to `nen ref resolve --citation` (zheref/nen#482).
// Frozen to fixes the day the verb ships; retired at the repin (the canon_contracts_check
// precedent). Byte headroom is scripts/prose_size_check.sh's, never re-measured here.
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, lstatSync, readdirSync, readFileSync, realpathSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

type Severity = 'fail' | 'advisory';
type Rule = { id: string; class: string; severity: Severity; summary: string; pattern?: string; [k: string]: unknown };
type Contract = {
  paths: { include: string[] };
  exemptions: { codeFences: boolean; quotedWords: boolean };
  records: { paths: string[]; rules: string[] };
  retired: { rules: string[] };
  versionSource: { file: string; minimum: string; pinned: string };
  decisionsFile: string;
  markerRows: string[];
  markerLimit: number;
  emptyBaseline: string[];
  rulingsFile: string;
  declaredValues: string[];
  rules: Rule[];
};
type Finding = { path: string; line: number; rule: string; severity: Severity; text: string; key: string; inBaseline?: boolean };
type BaselineRow = { path: string; rule: string; text: string; count: number };
type Para = { start: number; lines: string[]; text: string; kind: 'prose' | 'heading' | 'table' | 'front' };
type Doc = { path: string; raw: string; lines: string[]; paras: Para[]; anchors: Set<string>; headings: string[]; leads: string[]; retired: Set<number> };

class Wiring extends Error {}
const wiring = (m: string): never => { throw new Wiring(m); };
const CLASSES = ['by-hand', 'stale-residue', 'stale-version', 'citation', 'bare-ref', 'unverified-claim', 'hedge', 'adjective', 'number-not-declared', 'residue-unfiled', 'open-question-shape', 'reading-cited-as-ruled'];
// The fixed id -> class pairing and the keys each class's handler reads (HR-13; BC-6's small option).
const FIXED: Record<string, { cls: string; keys: string[] }> = {
  'PL-01': { cls: 'by-hand', keys: ['pattern', 'negations'] },
  'PL-02': { cls: 'stale-residue', keys: ['pattern', 'requires'] },
  'PL-03': { cls: 'stale-version', keys: ['patterns', 'otherPins', 'pastWords'] },
  'PL-04': { cls: 'citation', keys: [] },
  'PL-05': { cls: 'bare-ref', keys: ['pattern'] },
  'PL-06': { cls: 'unverified-claim', keys: ['pattern', 'date', 'evidence'] },
  'PL-07': { cls: 'hedge', keys: ['pattern'] },
  'PL-08': { cls: 'adjective', keys: ['pattern'] },
  'PL-09': { cls: 'number-not-declared', keys: ['pattern'] },
  'PL-10': { cls: 'residue-unfiled', keys: ['requires'] },
  'PL-11': { cls: 'open-question-shape', keys: ['pattern', 'marker', 'ledger'] },
  'PL-12': { cls: 'reading-cited-as-ruled', keys: ['pattern'] },
};
const here = dirname(fileURLToPath(import.meta.url));

function parseArgs(argv: string[]): Map<string, string> {
  const out = new Map<string, string>();
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--json' || a === '--self-test') { out.set(a, 'true'); continue; }
    if (!['--root', '--rules', '--baseline', '--base', '--base-baseline'].includes(a)) wiring(`unknown flag ${a}`);
    const v = argv[i + 1];
    if (v === undefined || v.startsWith('--') || out.has(a)) wiring(`flag ${a} needs one value`);
    out.set(a, v); i++;
  }
  return out;
}

function readText(abs: string, rel: string): string {
  let buf: Buffer;
  try { buf = readFileSync(abs); } catch (e) { return wiring(`cannot read ${rel}: ${(e as Error).message}`); }
  try { return new TextDecoder('utf-8', { fatal: true }).decode(buf); } catch { return wiring(`${rel} is not valid UTF-8`); }
}

function readJson(abs: string, rel: string): unknown {
  const t = readText(abs, rel);
  // The file is named, never quoted: a parser's message echoes the bytes it read (SEC-7).
  try { return JSON.parse(t); } catch { return wiring(`${rel} is not valid JSON`); }
}

// SEC-7: every contract-named read (the rules contract, versionSource.file, decisionsFile, the rulings
// file, declaredValues matches, the baseline) passes the walk's check: inside the root, and a symlink,
// or a symlinked parent, whose real path leaves the root is wiring (exit 2). An absent path returns its
// absolute path for the caller's own missing-file message.
function inside(root: string, realRoot: string, rel: string): string {
  const abs = resolve(root, rel);
  if (abs !== root && !abs.startsWith(root + sep)) return wiring(`${rel} leaves the root`);
  try { lstatSync(abs); } catch { return abs; }
  let real = '';
  try { real = realpathSync(abs); } catch { return wiring(`symlink ${rel} is dangling`); }
  if (real !== realRoot && !real.startsWith(realRoot + sep)) return wiring(`symlink ${rel} leaves the root`);
  return abs;
}

function pointer(obj: unknown, ptr: string): unknown {
  let cur: unknown = obj;
  for (const part of ptr.split('/').slice(1)) {
    if (!cur || typeof cur !== 'object') return undefined;
    cur = (cur as Record<string, unknown>)[part];
  }
  return cur;
}

function compile(src: unknown, where: string, flags = 'gi'): RegExp {
  if (typeof src !== 'string' || !src) return wiring(`${where} is not a pattern string`);
  try { return new RegExp(src, flags); } catch (e) { return wiring(`${where} does not compile: ${(e as Error).message}`); }
}

function loadContract(abs: string, rel: string): Contract {
  const c = readJson(abs, rel) as Contract;
  if (!c || typeof c !== 'object' || !Array.isArray(c.rules) || !c.paths || !Array.isArray(c.paths.include)) wiring(`${rel} lacks rules[] or paths.include[]`);
  for (const k of ['decisionsFile', 'rulingsFile'] as const) if (typeof c[k] !== 'string') wiring(`${rel} lacks ${k}`);
  if (!c.records || !Array.isArray(c.records.paths) || !Array.isArray(c.records.rules)) wiring(`${rel} lacks records.paths[] / records.rules[]`);
  if (!c.retired || !Array.isArray(c.retired.rules)) wiring(`${rel} lacks retired.rules[]`);
  if (!c.versionSource || typeof c.versionSource.file !== 'string') wiring(`${rel} lacks versionSource`);
  if (!Array.isArray(c.markerRows) || !Array.isArray(c.emptyBaseline) || !Number.isInteger(c.markerLimit) || !Array.isArray(c.declaredValues)) wiring(`${rel} lacks markerRows, markerLimit or declaredValues`);
  const seen = new Set<string>();
  for (const r of c.rules) {
    if (!/^PL-\d\d$/.test(r.id) || seen.has(r.id)) wiring(`${rel}: rule id ${String(r.id)} is malformed or repeated`);
    seen.add(r.id);
    if (!CLASSES.includes(r.class)) wiring(`${rel}: ${r.id} has unknown class ${String(r.class)}`);
    const fixed = FIXED[r.id];
    if (!fixed) wiring(`${rel}: ${r.id} has no handler; rule ids are fixed (PL-01 … PL-12)`);
    if (fixed.cls !== r.class) wiring(`${rel}: ${r.id} is class ${r.class}, but its handler is ${fixed.cls}; rule ids are fixed`);
    for (const k of fixed.keys) if (!(k in r)) wiring(`${rel}: ${r.id} (${r.class}) lacks ${k}`);
    if (r.severity !== 'fail' && r.severity !== 'advisory') wiring(`${rel}: ${r.id} has severity ${String(r.severity)}`);
    for (const k of ['pattern', 'negations', 'requires', 'date', 'evidence', 'marker', 'ledger', 'otherPins']) if (k in r) compile(r[k], `${rel}: ${r.id}.${k}`);
    if ('patterns' in r) { if (!Array.isArray(r.patterns) || !r.patterns.length) wiring(`${rel}: ${r.id}.patterns is not a list`); (r.patterns as unknown[]).forEach((x, i) => compile(x, `${rel}: ${r.id}.patterns[${i}]`)); }
    if ('pastWords' in r && !Array.isArray(r.pastWords)) wiring(`${rel}: ${r.id}.pastWords is not a list`);
  }
  for (const cls of CLASSES) if (!c.rules.some((r) => r.class === cls)) wiring(`${rel}: no rule of class ${cls}`);
  for (const id of c.retired.rules) if (!seen.has(id)) wiring(`${rel}: retired.rules names ${String(id)}, which is no rule`);
  return c;
}

function globToRegex(g: string): RegExp {
  let s = '';
  for (let i = 0; i < g.length; i++) {
    const ch = g[i];
    if (ch === '*' && g[i + 1] === '*') { s += '.*'; i++; if (g[i + 1] === '/') { s = s.slice(0, -2) + '(?:.*/)?'; i++; } }
    else if (ch === '*') s += '[^/]*';
    else s += ch.replace(/[.+?^${}()|[\]\\]/g, '\\$&');
  }
  return new RegExp(`^${s}$`);
}

// Walk the root (never surfaces/, .git/, node_modules/), refusing a symlink that leaves it.
function walk(root: string, realRoot: string, globs: string[]): string[] {
  const include = globs.map(globToRegex);
  const prefixes = globs.map((g) => g.slice(0, g.indexOf('*') < 0 ? g.length : g.indexOf('*')));
  const out: string[] = [];
  const visit = (relDir: string): void => {
    let names: string[] = [];
    try { names = readdirSync(join(root, relDir)); } catch (e) { wiring(`cannot list ${relDir || '.'}: ${(e as Error).message}`); }
    for (const name of names.sort()) {
      const rel = relDir ? `${relDir}/${name}` : name;
      if (!relDir && ['surfaces', '.git', 'node_modules', '.nen', '.claude'].includes(name)) continue;
      const abs = join(root, rel);
      let st = lstatSync(abs);
      if (st.isSymbolicLink()) {
        let real = '';
        try { real = realpathSync(abs); } catch { wiring(`symlink ${rel} is dangling`); }
        if (real !== realRoot && !real.startsWith(realRoot + sep)) wiring(`symlink ${rel} leaves the root (${real})`);
        st = statSync(abs);
        if (st.isDirectory()) continue; // a linked directory is read through its real path, never twice
      }
      if (st.isDirectory()) {
        if (prefixes.some((p) => p.startsWith(`${rel}/`) || `${rel}/`.startsWith(p))) visit(rel);
      } else if (st.isFile() && include.some((re) => re.test(rel))) out.push(rel);
    }
  };
  visit('');
  return out;
}

// QA-15: every link-target quantifier is bounded (2,048 characters), as the label is (600), so a
// line of '[a](' with no ')' costs linear time, never quadratic.
const mask = (s: string, a: number, b: number): string => s.slice(0, a) + s.slice(a, b).replace(/[^\n]/g, ' ') + s.slice(b);

function exempt(text: string): string {
  // Quoted words: "…", “…”, *"…"* — the maintainer's words are never linted (HR-13). Quotes pair
  // within one line, and never across an inline code span (a `"` in code is no quotation); the
  // spans are found on a copy with code blanked and blanked in the text itself.
  const probe = text.replace(/`[^`\n]*`/g, (x) => ' '.repeat(x.length));
  let t = text;
  for (const re of [/"[^"\n]{1,600}"/g, /“[^”\n]{1,600}”/g]) for (const m of probe.matchAll(re)) t = mask(t, m.index ?? 0, (m.index ?? 0) + m[0].length);
  return t;
}

// GitHub's slugger: lower case, drop what is not a letter, mark, number, connector punctuation
// (`_`), space or hyphen, spaces to hyphens. `_` is kept, inside code spans always and outside
// them unless it is emphasis markup at a word edge.
export function slug(heading: string): string {
  const t = heading.trim().toLowerCase().replace(/<[^>]+>/g, '').replace(/\[([^\]]{0,600})\]\([^)]{0,2048}\)/g, '$1')
    .split(/(`[^`]*`)/).map((part) => part.startsWith('`') ? part.replace(/`/g, '')
      : part.replace(/[*~]/g, '').replace(/(?<![\p{L}\p{N}])_+|_+(?![\p{L}\p{N}])/gu, '')).join('');
  return t.replace(/[^\p{L}\p{M}\p{N}\p{Pc} -]/gu, '').replace(/ /g, '-');
}

export function norm(s: string): string {
  return s.replace(/\[([^\]]{0,600})\]\([^)]{0,2048}\)/g, '$1').replace(/[*`_"“”‘’']/g, '').replace(/…/g, '').replace(/\s+/g, ' ').trim().toLowerCase().replace(/^[^\p{L}\p{N}§]+/u, '').replace(/[.:,;]+$/, '');
}

function parseDoc(rel: string, raw: string): Doc {
  const lines = raw.replace(/\r\n?/g, '\n').split('\n');
  const paras: Para[] = [];
  const anchors = new Set<string>();
  const headings: string[] = [];
  const leads: string[] = [];
  const retired = new Set<number>();
  const slugCount = new Map<string, number>();
  let i = 0;
  if (lines[0] === '---') {
    let j = 1;
    while (j < lines.length && lines[j] !== '---') j++;
    for (let k = 1; k < j; k++) paras.push({ start: k + 1, lines: [lines[k]], text: lines[k], kind: 'front' });
    i = j + 1;
  }
  let fence: string | null = null;
  let cur: Para | null = null;
  let retiredKind: 'quote' | 'para' | null = null;
  let retiredIndent = 0;
  const flush = (): void => { if (cur) { cur.text = cur.lines.join('\n'); paras.push(cur); cur = null; } };
  for (; i < lines.length; i++) {
    const l = lines[i];
    const f = /^\s*(`{3,}|~{3,})/.exec(l);
    if (fence) { if (f && f[1][0] === fence[0] && f[1].length >= fence.length && /^\s*[`~]+\s*$/.test(l)) fence = null; continue; }
    if (f) { flush(); fence = f[1]; continue; }
    for (const m of l.matchAll(/<a\s+(?:id|name)="([^"]+)"/g)) anchors.add(m[1]);
    const h = /^(#{1,6})\s+(.*?)\s*#*\s*$/.exec(l);
    // RETIRED blocks: a `> **RETIRED…` quote runs while lines start with `>`; a `N. **RETIRED`
    // list item or a `**RETIRED` paragraph runs to the next blank line, heading, or list item at
    // the same or a shallower indent.
    const item = /^(\s*)(?:\d+\.|[-*+])\s+/.exec(l);
    if (/^\s*>\s*(?:#+\s*)?\**\s*RETIRED/.test(l)) retiredKind = 'quote';
    else if (/^\s*(?:\d+\.\s+|[-*+]\s+)?\*\*RETIRED/.test(l)) { retiredKind = 'para'; retiredIndent = (/^\s*/.exec(l) ?? [''])[0].length; }
    else if (retiredKind === 'quote' && !/^\s*>/.test(l)) retiredKind = null;
    else if (retiredKind === 'para' && (l.trim() === '' || h || (item && item[1].length <= retiredIndent))) retiredKind = null;
    const inRetired = retiredKind !== null;
    if (inRetired) retired.add(i + 1);
    if (h) {
      flush();
      const text = h[2];
      headings.push(text);
      const s = slug(text);
      const n = slugCount.get(s) ?? 0;
      anchors.add(n ? `${s}-${n}` : s);
      slugCount.set(s, n + 1);
      paras.push({ start: i + 1, lines: [l], text: l, kind: 'heading' });
      continue;
    }
    if (l.trim() === '') { flush(); continue; }
    if (/^\s*\|/.test(l)) { flush(); paras.push({ start: i + 1, lines: [l], text: l, kind: 'table' }); continue; }
    if (cur && /^\s*(?:[-*+]|\d+\.)\s+/.test(l)) flush();
    if (!cur) {
      cur = { start: i + 1, lines: [], text: '', kind: 'prose' };
      const lead = /^\s*(?:>\s*)*(?:[-*+]\s+|\d+\.\s+)?\*\*([^*]+?)\*\*/.exec(l);
      if (lead) leads.push(lead[1]);
    }
    cur.lines.push(l);
  }
  flush();
  return { path: rel, raw, lines, paras, anchors, headings, leads, retired };
}

function lineAt(p: Para, offset: number): number {
  let n = p.start, acc = 0;
  for (const l of p.lines) { if (offset <= acc + l.length) return n; acc += l.length + 1; n++; }
  return p.start + p.lines.length - 1;
}

function headingNumber(h: string): string | null {
  const m = /^(?:§\s*)?(\d+[a-z]?(?:\.\d+)*)(?=$|[\s.·:)—–-])/.exec(h.replace(/[*`]/g, '').trim());
  return m ? m[1] : null;
}

function titleMatches(candidate: string, title: string): boolean {
  const c = norm(candidate).replace(/^(?:§\s*)?\d+[a-z]?(?:\.\d+)*[.·:)]?\s*(?:[·—–-]\s*)?/, '');
  const full = norm(candidate);
  const t = norm(title);
  if (!t) return false;
  const pre = (x: string): boolean => x === t || (x.startsWith(t) && /^[\s.,:;·—–(-]/.test(x.slice(t.length)));
  return pre(c) || pre(full);
}

type Ctx = { root: string; realRoot: string; c: Contract; rules: Map<string, Rule>; min: string; pin: string; docs: Map<string, Doc>; reading: Set<string>; declared: Set<string>; markerOk: Set<string>; humanGate: Set<string> };

function loadDoc(ctx: Ctx, rel: string): Doc | null {
  if (ctx.docs.has(rel)) return ctx.docs.get(rel) ?? null;
  const abs = inside(ctx.root, ctx.realRoot, rel);
  if (!existsSync(abs) || !statSync(abs).isFile()) return null;
  const d = parseDoc(rel, readText(abs, rel));
  ctx.docs.set(rel, d);
  return d;
}

function resolveTarget(ctx: Ctx, from: string, target: string): { rel: string | null; why?: string } {
  const path = decodeURIComponent(target.split('#')[0]);
  if (!path) return { rel: from };
  const abs = resolve(ctx.root, dirname(from), path);
  if (abs !== ctx.root && !abs.startsWith(ctx.root + sep)) return { rel: null, why: 'leaves the root' };
  if (!existsSync(abs)) return { rel: null, why: 'no such file' };
  let real = '';
  try { real = realpathSync(abs); } catch { return wiring(`link ${target} in ${from} cannot be resolved`); }
  if (real !== ctx.realRoot && !real.startsWith(ctx.realRoot + sep)) wiring(`link ${target} in ${from} resolves through a symlink leaving the root (${real})`);
  return { rel: relative(ctx.root, abs).split(sep).join('/') };
}

function check(ctx: Ctx, d: Doc): Finding[] {
  const out: Finding[] = [];
  const isSkill = /^claude\/(skills\/[^/]+\/SKILL\.md|agents\/[^/]+\.md|rules\/[^/]+\.md)$/.test(d.path);
  const recordRe = ctx.c.records.paths.map(globToRegex);
  const isRecord = recordRe.some((re) => re.test(d.path));
  const add = (rule: string, p: Para, off: number, text: string): void => {
    const r = ctx.rules.get(rule);
    if (!r) return;
    const line = lineAt(p, off);
    if (d.retired.has(line) && ctx.c.retired.rules.includes(rule)) return;
    if (isRecord && ctx.c.records.rules.includes(rule)) return;
    const t = text.replace(/\s+/g, ' ').trim().slice(0, 160);
    out.push({ path: d.path, line, rule, severity: r.severity, text: t, key: `${d.path}\u0000${rule}\u0000${t.toLowerCase()}` });
  };
  const re = (id: string, k = 'pattern'): RegExp | null => { const r = ctx.rules.get(id); return r && typeof r[k] === 'string' ? new RegExp(r[k] as string, 'gi') : null; };
  let markers = 0;
  let section = '';
  for (const p of d.paras) {
    if (p.kind === 'heading') { const m = /^##\s+(.*)$/.exec(p.text); if (m) section = m[1]; continue; }
    const masked = ctx.c.exemptions.quotedWords ? exempt(p.text) : p.text;
    const flat = masked.replace(/\n/g, ' ');
    const ctxOf = (off: number, len: number): string => flat.slice(Math.max(0, off - 24), off + len + 24);
    // PL-01 — the clause before `by hand` must not refuse, retire or name a human.
    const by = re('PL-01'); const neg = re('PL-01', 'negations');
    if (by && neg) for (const m of flat.matchAll(by)) {
      const clause = flat.slice(Math.max(0, (m.index ?? 0) - 400), m.index).split(/[.;:!?—–]\s|\(/).pop() ?? '';
      neg.lastIndex = 0;
      if (!neg.test(clause)) add('PL-01', p, m.index ?? 0, ctxOf(m.index ?? 0, m[0].length));
    }
    for (const [id, req] of [['PL-02', 'requires']] as const) {
      const r = re(id); const q = re(id, req);
      if (r && q && !q.test(flat)) for (const m of flat.matchAll(r)) add(id, p, m.index ?? 0, ctxOf(m.index ?? 0, m[0].length));
    }
    const r3 = ctx.rules.get('PL-03');
    if (r3 && Array.isArray(r3.patterns)) (r3.patterns as string[]).forEach((src, n) => {
      for (const m of flat.matchAll(new RegExp(src, 'gi'))) {
        const [maj, min, pat] = [m[1], m[2], m[3]];
        const off = m.index ?? 0;
        if (n === 0) { // a pin claim: nen's (no other tool's pin named nearby), not after a past word
          const near = flat.slice(Math.max(0, off - 80), off + m[0].length + 40);
          if (new RegExp(r3.otherPins as string, 'i').test(near)) continue;
          const prev = (flat.slice(0, off).match(/[A-Za-z]+/g) ?? []).slice(-2).map((w) => w.toLowerCase());
          if (prev.some((w) => ((r3.pastWords as string[]) ?? []).includes(w))) continue;
          if (`${maj}.${min}` === ctx.min && pat === undefined) continue;
          if (`${maj}.${min}.${pat}` === ctx.pin.replace(/^v/, '')) continue;
        } else if (`${maj}.${min}` === ctx.min) continue; // a floor claim equal to the minimum
        add('PL-03', p, off, m[0]);
      }
    });
    // PL-04 — relative links and the `§` citation a link carries.
    const unspanned = masked.replace(/`[^`\n]*`/g, (x) => ' '.repeat(x.length)); // a link inside a code span is text
    for (const m of unspanned.matchAll(/\[[^\]]{0,600}?\]\(([^)\s]{1,2048})\)((?:'s)?\s*§§?\s*(?:(\d+[a-z]?(?:\.\d+)*)|\*([^*\n]+)\*))?/g)) {
      const target = m[1];
      if (/^[a-z][a-z0-9+.-]*:/i.test(target) || target.startsWith('<')) continue;
      const res = resolveTarget(ctx, d.path, target);
      if (!res.rel) { add('PL-04', p, m.index ?? 0, `${target} — ${res.why}`); continue; }
      const anchor = target.includes('#') ? decodeURIComponent(target.slice(target.indexOf('#') + 1)) : '';
      if (!res.rel.endsWith('.md')) continue;
      const doc = loadDoc(ctx, res.rel);
      if (!doc) continue;
      if (anchor && !doc.anchors.has(anchor)) add('PL-04', p, m.index ?? 0, `${target} — no anchor #${anchor}`);
      if (m[3]) {
        if (![...doc.headings, ...doc.leads].some((h) => headingNumber(h) === m[3])) add('PL-04', p, m.index ?? 0, `${res.rel} § ${m[3]} — no such heading`);
      } else if (m[4]) {
        if (!doc.headings.some((h) => titleMatches(h, m[4])) && !doc.leads.some((l) => titleMatches(l, m[4]))) add('PL-04', p, m.index ?? 0, `${res.rel} § *${m[4]}* — no heading or bold lead`);
      }
    }
    const bare = re('PL-05');
    if (bare) for (const m of flat.matchAll(bare)) {
      if (/\]\([^)\s]{0,2048}$/.test(flat.slice(Math.max(0, m.index - 2051), m.index))) continue; // inside a link target
      add('PL-05', p, m.index ?? 0, ctxOf(m.index ?? 0, m[0].length));
    }
    const ver6 = re('PL-06'); const date = re('PL-06', 'date'); const ev = re('PL-06', 'evidence');
    if (ver6 && date && ev && !(date.test(flat) && ev.test(flat))) for (const m of flat.matchAll(ver6)) add('PL-06', p, m.index ?? 0, ctxOf(m.index ?? 0, m[0].length));
    for (const id of ['PL-07', 'PL-08']) { const r = re(id); if (r) for (const m of flat.matchAll(r)) add(id, p, m.index ?? 0, ctxOf(m.index ?? 0, m[0].length)); }
    const num = re('PL-09');
    if (num && /\bnen [a-z]/.test(flat)) for (const m of flat.matchAll(num)) if (!ctx.declared.has(m[1])) add('PL-09', p, m.index ?? 0, m[0]);
    if (/^Residue\b/i.test(section) && p.kind === 'prose' && /^\s*(?:\d+\.|[-*+])\s+/.test(p.lines[0])) {
      const q = re('PL-10', 'requires');
      if (q && !q.test(flat)) add('PL-10', p, 0, flat.slice(0, 120));
    }
    const oq = re('PL-11'); const mk = re('PL-11', 'marker'); const led = re('PL-11', 'ledger');
    if (oq && mk && led) for (const m of flat.matchAll(oq)) {
      const off = m.index ?? 0;
      mk.lastIndex = off;
      const whole = new RegExp((ctx.rules.get('PL-11')?.marker as string), 'y');
      whole.lastIndex = off;
      const marker = whole.exec(flat);
      if (!marker) { add('PL-11', p, off, `${ctxOf(off, m[0].length)} — not [NEEDS <row-id>: question]`); continue; }
      markers++;
      const row = marker[1];
      if (ctx.humanGate.has(row)) add('PL-11', p, off, `${marker[0]} — row ${row} is a human gate: a stop, not a question`);
      else if (!ctx.markerOk.has(row)) add('PL-11', p, off, `${marker[0]} — row ${row} is not an ask-class marker row`);
      led.lastIndex = 0;
      if (!led.test(flat)) add('PL-11', p, off, `${marker[0]} — no OPEN-n or zheref/<repo>#N ledger reference`);
      if (isSkill && markers > ctx.c.markerLimit) add('PL-11', p, off, `${marker[0]} — marker ${markers} over the limit of ${ctx.c.markerLimit}`);
    }
    const hr = re('PL-12');
    if (hr && isSkill && !/\breading\b/i.test(flat)) for (const m of flat.matchAll(hr)) if (ctx.reading.has(m[1])) add('PL-12', p, m.index ?? 0, `HR-${m[1]} is status reading`);
  }
  return out;
}

function readingRows(ctx: Ctx): Set<string> {
  const d = loadDoc(ctx, ctx.c.rulingsFile);
  if (!d) return wiring(`rulings file ${ctx.c.rulingsFile} is missing`);
  const out = new Set<string>();
  for (const l of d.lines) {
    const m = /^\|\s*<a id="hr-(\d+)"><\/a>\*\*HR-\d+\*\*/.exec(l);
    if (!m) continue;
    const cells = l.split(/(?<!\\)\|/).map((c) => c.trim());
    if (/^reading\b/i.test(cells[5] ?? '')) out.add(m[1]);
  }
  return out;
}

function declaredNumbers(ctx: Ctx): Set<string> {
  const out = new Set<string>();
  const add = (v: unknown): void => {
    if (typeof v === 'number') out.add(String(v));
    else if (typeof v === 'string' && /^\d+$/.test(v)) out.add(v);
    else if (Array.isArray(v)) v.forEach(add);
    else if (v && typeof v === 'object') Object.values(v).forEach(add);
  };
  for (const g of ctx.c.declaredValues) {
    const re = globToRegex(g);
    const dir = g.includes('/') ? g.slice(0, g.lastIndexOf('/')) : '.';
    let names: string[] = [];
    try { names = readdirSync(inside(ctx.root, ctx.realRoot, dir)); } catch (e) { if (e instanceof Wiring) throw e; wiring(`declaredValues directory ${dir} cannot be listed`); }
    for (const n of names) { const rel = dir === '.' ? n : `${dir}/${n}`; if (re.test(rel)) add(readJson(inside(ctx.root, ctx.realRoot, rel), rel)); }
  }
  return out;
}

function git(root: string, args: string[]): string {
  try { return execFileSync('git', ['-C', root, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }); } catch (e) { return wiring(`git ${args.join(' ')} failed: ${(e as Error).message.split('\n')[0]}`); }
}

function loadBaseline(text: string, rel: string, empty: string[]): BaselineRow[] {
  let b: unknown;
  try { b = JSON.parse(text); } catch { return wiring(`${rel} is not valid JSON`); }
  if (!b || typeof b !== 'object' || Array.isArray(b)) return wiring(`${rel} is not an object`);
  // QA-16: an unexpected field is refused, never ignored.
  for (const k of Object.keys(b)) if (!['$comment', 'frozenAt', 'findings'].includes(k)) wiring(`${rel} has an unknown top-level key ${JSON.stringify(k)}`);
  const rows = (b as { findings?: unknown }).findings;
  if (!Array.isArray(rows)) return wiring(`${rel} lacks findings[]`);
  const keys = new Set<string>();
  for (const r of rows as BaselineRow[]) {
    if (r && typeof r.path === 'string' && typeof r.rule === 'string' && typeof r.text === 'string') {
      const k = `${r.path}\u0000${r.rule}\u0000${r.text.toLowerCase()}`;
      if (keys.has(k)) wiring(`${rel} repeats the row ${r.path} · ${r.rule} · ${r.text}; one row per key, its count the total`);
      keys.add(k);
    }
    if (typeof r.path !== 'string' || typeof r.rule !== 'string' || typeof r.text !== 'string' || !Number.isInteger(r.count) || r.count < 1) wiring(`${rel} has a malformed row`);
    for (const k of Object.keys(r)) if (!['path', 'rule', 'text', 'count'].includes(k)) wiring(`${rel} has a row with an unknown key ${JSON.stringify(k)}`);
    if (empty.includes(r.rule)) wiring(`${rel}: ${r.rule} is never baselined (HR-13); fix the prose instead`);
  }
  return rows as BaselineRow[];
}

export function run(argv: string[]): { code: number; out: string; err: string } {
  let out = ''; let err = '';
  try {
    const a = parseArgs(argv);
    if (a.has('--self-test')) {
      const r = spawnSync(process.execPath, [join(here, 'prose_ambiguity_check_fixture.mts')], { stdio: 'inherit' });
      return { code: r.status ?? 2, out, err };
    }
    const rootArg = a.get('--root') ?? wiring('--root <checkout> is required');
    if (!existsSync(rootArg) || !statSync(rootArg).isDirectory()) wiring(`root ${rootArg} is not a directory`);
    const root = resolve(rootArg);
    const realRoot = realpathSync(root);
    if (!existsSync(join(root, 'nen/contract.json')) || !existsSync(join(root, '.claude-plugin/plugin.json'))) wiring(`root ${root} is not a Hatsu checkout (no nen/contract.json or .claude-plugin/plugin.json)`);
    const rulesRel = a.get('--rules') ?? 'contracts/prose.lint.json';
    const c = loadContract(inside(root, realRoot, rulesRel), rulesRel);
    const nenContract = readJson(inside(root, realRoot, c.versionSource.file), c.versionSource.file);
    const min = pointer(nenContract, c.versionSource.minimum);
    const pin = pointer(nenContract, c.versionSource.pinned);
    if (typeof min !== 'string' || typeof pin !== 'string') wiring(`${c.versionSource.file} lacks the minimum or pinned_ref the contract names`);
    const decisions = readJson(inside(root, realRoot, c.decisionsFile), c.decisionsFile) as { rows?: Array<{ id: string; class: string }> };
    if (!Array.isArray(decisions.rows)) wiring(`${c.decisionsFile} lacks rows[]`);
    for (const r of c.markerRows) {
      const row = (decisions.rows ?? []).find((x) => x.id === r);
      if (!row) wiring(`markerRows names ${r}, which ${c.decisionsFile} does not carry`);
      else if (row.class !== 'ask-once-per-run') wiring(`markerRows names ${r}, which is class ${row.class} in ${c.decisionsFile}; a marker row is ask-once-per-run (HR-4)`);
    }
    const ctx: Ctx = {
      root, realRoot, c, rules: new Map(c.rules.map((r) => [r.id, r])), min: min as string, pin: pin as string, docs: new Map(),
      reading: new Set(), declared: new Set(), markerOk: new Set(c.markerRows),
      humanGate: new Set((decisions.rows ?? []).filter((r) => r.class === 'human-gate').map((r) => r.id)),
    };
    ctx.reading = readingRows(ctx);
    ctx.declared = declaredNumbers(ctx);
    const walked = walk(root, realRoot, c.paths.include);
    let files = walked;
    const baseRef = a.get('--base');
    let baseRows: BaselineRow[] | null = null;
    let notice = '';
    const baselineRel = a.get('--baseline') ?? 'contracts/prose.lint.baseline.json';
    const keyOf = (r: BaselineRow): string => `${r.path}\u0000${r.rule}\u0000${r.text.toLowerCase()}`;
    if (baseRef) {
      const mb = git(root, ['merge-base', baseRef, 'HEAD']).trim();
      const changed = new Set(git(root, ['diff', '--name-only', mb]).split('\n').filter(Boolean));
      files = files.filter((f) => changed.has(f));
      const shown = spawnSync('git', ['-C', root, 'show', `${mb}:${baselineRel}`], { encoding: 'utf8' });
      if (shown.status === 0) baseRows = loadBaseline(shown.stdout, `${baseRef}:${baselineRel}`, c.emptyBaseline);
      else notice = `notice: ${baseRef} carries no ${baselineRel}; baseline growth is not checked\n`;
    }
    const baseBaseline = a.get('--base-baseline');
    if (baseBaseline) {
      const abs = resolve(baseBaseline);
      if (!existsSync(abs)) wiring(`--base-baseline ${baseBaseline} is missing`);
      baseRows = loadBaseline(readText(abs, baseBaseline), baseBaseline, c.emptyBaseline);
    }
    const findings: Finding[] = [];
    for (const f of files) findings.push(...check(ctx, loadDoc(ctx, f) ?? wiring(`cannot read ${f}`)));
    const baselineAbs = inside(root, realRoot, baselineRel);
    const rows = existsSync(baselineAbs) ? loadBaseline(readText(baselineAbs, baselineRel), baselineRel, c.emptyBaseline) : wiring(`baseline ${baselineRel} is missing`);
    const budget = new Map<string, number>();
    for (const r of rows) budget.set(keyOf(r), (budget.get(keyOf(r)) ?? 0) + r.count);
    const fails = findings.filter((f) => f.severity === 'fail');
    for (const f of fails) { const n = budget.get(f.key) ?? 0; f.inBaseline = n > 0; if (n > 0) budget.set(f.key, n - 1); }
    // Stale: a row whose path the walk does not read (deleted, renamed, out of scope), or a
    // row in a read file with budget left over.
    const read = new Set(walked);
    const scoped = new Set(files);
    const stale = rows.filter((r) => !read.has(r.path) || (scoped.has(r.path) && (budget.get(keyOf(r)) ?? 0) > 0));
    const grown: BaselineRow[] = [];
    if (baseRows) {
      const was = new Map<string, number>();
      for (const r of baseRows) was.set(keyOf(r), (was.get(keyOf(r)) ?? 0) + r.count);
      const now = new Map<string, number>();
      for (const r of rows) now.set(keyOf(r), (now.get(keyOf(r)) ?? 0) + r.count);
      for (const r of rows) if ((now.get(keyOf(r)) ?? 0) > (was.get(keyOf(r)) ?? 0)) grown.push(r);
    }
    const against = baseBaseline ?? baseRef;
    const fresh = fails.filter((f) => !f.inBaseline);
    const counts: Record<string, { total: number; baselined: number; new: number }> = {};
    for (const r of c.rules) counts[r.id] = { total: 0, baselined: 0, new: 0 };
    for (const f of findings) { counts[f.rule].total++; if (f.inBaseline) counts[f.rule].baselined++; else if (f.severity === 'fail') counts[f.rule].new++; }
    const code = fresh.length || stale.length || grown.length ? 1 : 0;
    if (a.has('--json')) {
      out = JSON.stringify({
        contract: 'hatsu.prose-lint.result/v0.1', root, base: baseRef ?? null, files: files.length, exit: code, counts,
        findings: findings.filter((f) => f.severity === 'fail').map(({ key: _k, ...f }) => f),
        advisory: findings.filter((f) => f.severity === 'advisory').map(({ key: _k, inBaseline: _i, ...f }) => f),
        staleBaseline: stale, grownBaseline: grown, notice: notice.trim() || null,
      }, null, 2) + '\n';
    } else {
      out += notice;
      for (const f of fresh) out += `${f.path}:${f.line} · ${f.rule} · ${f.text}\n`;
      for (const r of stale) out += `baseline · ${r.rule} · ${r.path} · ${r.text} — no longer found; remove the row\n`;
      for (const r of grown) out += `baseline · ${r.rule} · ${r.path} · ${r.text} — added over ${against}; the baseline only shrinks\n`;
      if (baseRef) for (const f of findings.filter((x) => x.severity === 'advisory')) out += `advisory ${f.path}:${f.line} · ${f.rule} · ${f.text}\n`;
      const sum = c.rules.map((r) => `${r.id} ${counts[r.id].total}${r.severity === 'advisory' ? 'a' : `/${counts[r.id].baselined}b`}`).join(' · ');
      out += `canon-lint: ${files.length} files · ${fresh.length} new · ${stale.length} stale · ${grown.length} grown · ${sum}\n`;
    }
    return { code, out, err };
  } catch (e) {
    if (e instanceof Wiring) return { code: 2, out, err: `prose_ambiguity_check: ${e.message}\n` };
    return { code: 2, out, err: `prose_ambiguity_check: internal error: ${(e as Error).stack ?? e}\n` };
  }
}

// Compared as REAL paths: invoked through a symlinked directory (/var -> /private/var on macOS, the
// shape a mktmpdir hands a caller) the unresolved argv path never equals the resolved module URL, and a
// guard that then runs nothing exits 0 -- a false pass, never a verdict (found by the trusted preflight's
// fixture, 2026-10-22).
function samePath(a: string, b: string): boolean {
  try { return realpathSync(a) === realpathSync(b); } catch { return a === b; }
}
if (process.argv[1] && samePath(resolve(process.argv[1]), fileURLToPath(import.meta.url))) {
  const r = run(process.argv.slice(2));
  process.stdout.write(r.out);
  process.stderr.write(r.err);
  process.exitCode = r.code;
}
