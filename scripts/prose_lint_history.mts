#!/usr/bin/env node
// Report shrink in the first-parent history of the canon prose baseline (zheref/hatsu#448).
// Usage: node scripts/prose_lint_history.mts --root <checkout> --history <1..100> [--json]
import { execFileSync } from 'node:child_process';
import { existsSync, lstatSync, readFileSync, realpathSync, statSync } from 'node:fs';
import { join, resolve, sep } from 'node:path';

type Contract = { paths: { include: string[] }; emptyBaseline: string[] };
type BaselineRow = { path: string; rule: string; text: string; count: number };

class Wiring extends Error {}
const wiring = (m: string): never => { throw new Wiring(m); };
function parseArgs(argv: string[]): Map<string, string> {
  const out = new Map<string, string>();
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--json') { out.set(a, 'true'); continue; }
    if (!['--root', '--rules', '--baseline', '--history'].includes(a)) wiring(`unknown flag ${a}`);
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

// Rules and baseline paths stay inside the root, including through symlinked parents.
function inside(root: string, realRoot: string, rel: string): string {
  const abs = resolve(root, rel);
  if (abs !== root && !abs.startsWith(root + sep)) return wiring(`${rel} leaves the root`);
  try { lstatSync(abs); } catch { return abs; }
  let real = '';
  try { real = realpathSync(abs); } catch { return wiring(`symlink ${rel} is dangling`); }
  if (real !== realRoot && !real.startsWith(realRoot + sep)) return wiring(`symlink ${rel} leaves the root`);
  return abs;
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

const sumKeys = (rows: BaselineRow[]): Map<string, number> => {
  const m = new Map<string, number>();
  for (const r of rows) { const k = `${r.path}\u0000${r.rule}\u0000${r.text.toLowerCase()}`; m.set(k, (m.get(k) ?? 0) + r.count); }
  return m;
};

// Paths changed between revisions, NUL-split and unquoted, so a non-ASCII or odd path reads as itself.
function changedPaths(root: string, revs: string[]): string[] {
  return git(root, ['-c', 'core.quotePath=false', 'diff', '--name-only', '-z', ...revs]).split('\u0000').filter(Boolean);
}

// --history <n> (zheref/hatsu#448, AC-4): the shrink of the last <n> merged prose pull requests, read
// from git alone. A pull request is a first-parent `Merge pull request #N` merge or a squash commit
// whose subject ends `(#N)`, newer than the ratchet's start, whose diff touches a canon prose path; its
// removed rows are counted exactly as --base-baseline counts them. A prose commit that names no pull
// request is skipped and counted, never guessed. A cut-short history is said, never read as the start.
const HISTORY_MAX = 100;
type HistoryPr = { number: string; commit: string; kind: 'merge' | 'squash'; files: number; removed: number | null; baselineAbsent: boolean };
function history(root: string, c: Contract, baselineRel: string, nArg: string, json: boolean): string {
  if (!/^[1-9][0-9]{0,2}$/.test(nArg) || Number(nArg) > HISTORY_MAX) wiring(`--history needs a whole number from 1 to ${HISTORY_MAX}, got ${nArg}`);
  const want = Number(nArg);
  const capArg = process.env.HATSU_PROSE_HISTORY_SCAN ?? '5000';
  if (!/^[1-9][0-9]{0,5}$/.test(capArg)) wiring(`HATSU_PROSE_HISTORY_SCAN must be a whole number from 1 to 999999, got ${capArg}`);
  const cap = Number(capArg);
  const include = c.paths.include.map(globToRegex);
  // "Not in that tree" is ls-tree's empty answer; any other git failure is wiring through git().
  const show = (rev: string): BaselineRow[] | null => {
    if (!git(root, ['ls-tree', '--name-only', rev, '--', baselineRel]).trim()) return null;
    return loadBaseline(git(root, ['show', `${rev}:${baselineRel}`]), `${rev.slice(0, 9)}:${baselineRel}`, c.emptyBaseline);
  };
  if (git(root, ['rev-parse', '--is-shallow-repository']).trim() === 'true') wiring('--history needs the full history; this repository is shallow (git fetch --unshallow)');
  const head = git(root, ['rev-parse', 'HEAD']).trim();
  const atHead = show(head) ?? wiring(`--history: HEAD carries no ${baselineRel}; there is no ratchet to report`);
  // The ratchet's start, found once: the oldest first-parent commit that added the baseline. Nothing
  // older is read, so a pre-ratchet commit is never counted as skipped.
  const adds = git(root, ['log', '--first-parent', '--diff-merges=first-parent', '--diff-filter=A', '--no-patch', '--format=%H', head, '--', baselineRel]).split('\n').filter(Boolean);
  const start = adds[adds.length - 1] ?? wiring(`--history: no first-parent commit on HEAD adds ${baselineRel}`);
  const raw = git(root, ['log', '--first-parent', `-n${cap + 1}`, '--format=%H %P%x09%s', head]).split('\n').filter(Boolean);
  const log = raw.slice(0, cap);
  const prs: HistoryPr[] = [];
  let skippedNonMergeProse = 0;
  let skippedNonPrMergeProse = 0;
  let end: 'complete' | 'ratchet-start' | 'history-start' | 'scan-cap' = raw.length > cap ? 'scan-cap' : 'history-start';
  for (const line of log) {
    if (prs.length >= want) break;
    const tab = line.indexOf('\t');
    const [commit, parent, second] = line.slice(0, tab).split(' ');
    const subject = line.slice(tab + 1);
    if (commit === start) { end = parent ? 'ratchet-start' : 'history-start'; break; }
    if (!parent) continue; // unreachable once start is found; kept so a root commit is never diffed
    const prose = changedPaths(root, [parent, commit]).filter((f) => !f.startsWith('surfaces/') && include.some((re) => re.test(f)));
    if (!prose.length) continue;
    const m = second ? /^Merge pull request #([0-9]{1,9}) /.exec(subject) : / \(#([0-9]{1,9})\)$/.exec(subject);
    if (!m) { if (second) skippedNonPrMergeProse++; else skippedNonMergeProse++; continue; }
    // Past the start, a missing baseline on either side is flagged and left out of the sum.
    const was = show(parent);
    const nowRows = show(commit);
    let removed: number | null = null;
    if (was && nowRows) {
      const now = sumKeys(nowRows);
      removed = 0;
      for (const [k, n] of sumKeys(was)) removed += Math.max(0, n - (now.get(k) ?? 0));
    }
    prs.push({ number: m[1], commit, kind: second ? 'merge' : 'squash', files: prose.length, removed, baselineAbsent: removed === null });
  }
  if (prs.length >= want) end = 'complete';
  const findings = atHead.reduce((t, r) => t + r.count, 0);
  const sum = prs.reduce((t, p) => t + (p.removed ?? 0), 0);
  if (json) return JSON.stringify({ contract: 'hatsu.prose-lint.history/v0.1', root, head, requested: want, end, ratchetStart: start, scanned: log.length, pullRequests: prs, removed: sum, skippedNonMergeProse, skippedNonPrMergeProse, baselineFindings: findings }, null, 2) + '\n';
  let out = '';
  for (const p of prs) out += `history · #${p.number} · ${p.commit.slice(0, 9)} · ${p.kind} · ${p.files} prose file${p.files === 1 ? '' : 's'} · ${p.baselineAbsent ? 'baseline absent in its tree or its parent\'s, not counted' : `${p.removed} removed`}\n`;
  const why = {
    complete: '',
    'ratchet-start': ` (the ratchet starts there: ${start.slice(0, 9)} added the baseline)`,
    'history-start': ' (the first-parent history ends there)',
    'scan-cap': ` (cut short: the scan stopped at ${cap} commits, so older pull requests were not read)`,
  }[end];
  const skipped = skippedNonMergeProse + skippedNonPrMergeProse ? ` · skipped ${skippedNonMergeProse} prose commits naming no PR and ${skippedNonPrMergeProse} non-PR merges` : '';
  out += `canon-lint history: last ${prs.length} of ${want} prose pull requests on ${head.slice(0, 9)}${why} · ${sum} removed${skipped} · baseline ${findings} findings\n`;
  return out;
}

export function run(argv: string[]): { status: number; stdout: string; stderr: string } {
  try {
    const args = parseArgs(argv);
    const root = resolve(args.get('--root') ?? wiring('--root <checkout> is required'));
    const count = args.get('--history') ?? wiring('--history <1..100> is required');
    if (!existsSync(root) || !statSync(root).isDirectory()) wiring(`root ${root} is not a directory`);
    const realRoot = realpathSync(root);
    if (!existsSync(join(root, 'nen/contract.json')) || !existsSync(join(root, '.claude-plugin/plugin.json'))) {
      wiring(`root ${root} is not a Hatsu checkout (no nen/contract.json or .claude-plugin/plugin.json)`);
    }
    const rules = args.get('--rules') ?? 'contracts/prose.lint.json';
    const c = readJson(inside(root, realRoot, rules), rules) as Contract;
    if (!Array.isArray(c?.paths?.include) || !c.paths.include.every((glob) => typeof glob === 'string') ||
        !Array.isArray(c.emptyBaseline) || !c.emptyBaseline.every((id) => typeof id === 'string')) {
      wiring(`${rules} lacks a valid paths.include[] or emptyBaseline[]`);
    }
    const baseline = args.get('--baseline') ?? 'contracts/prose.lint.baseline.json';
    inside(root, realRoot, baseline);
    return { status: 0, stdout: history(root, c, baseline, count, args.has('--json')), stderr: '' };
  } catch (error) {
    return { status: 2, stdout: '', stderr: `prose_lint_history: ${(error as Error).message}\n` };
  }
}

if (import.meta.main) {
  const { status, stdout, stderr } = run(process.argv.slice(2));
  process.stdout.write(stdout);
  process.stderr.write(stderr);
  process.exitCode = status;
}
