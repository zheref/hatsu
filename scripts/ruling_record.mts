#!/usr/bin/env node
// Ruling capture, Hatsu half (zheref/hatsu#443; SDD plan wave 1, ruling capture). nen 0.26.0 records
// every picker answer as data (`nen stop answer --record`, nen's own verb, never reimplemented here);
// this script is what Hatsu owns on top of it (HR-2: anchors live in docs/ROSTER.md):
//
//   export     copy one record out of the effort's ledger, read ONLY through `nen stop answer show
//              <effort> --json`, into docs/ruling-records/<R-id>.json, so a reviewer holds the same
//              bytes the row is rendered from. An existing copy with other content is refused.
//   render     print one ROSTER ruling row from a committed record: the HR id cell (anchor plus the
//              record link), the question, every option with its consequence, and the answer with its
//              capture class. Status and what it settles are the lead's words, passed in.
//   check      the guard lane (nen shu test --lane ruling-record): every ROSTER line citing a record is
//              re-rendered and compared cell by cell, reported by HR id; an orphan, a twice-cited or an
//              unreadable record is a finding too.
//   preanswer  an idle pre-answer (HR-5, WORKFLOW § Idle batches): one `nen stop answer --record` call
//              composed from the decisions row's preferred[] with its starred key picked and the source
//              named in the question, so the pre-answer is recorded the same way and no picker is shown.
//
// Capture classes, rendered in the answer cell: `picked (K): `label`` for a pick; `typed, word for word
// (K): `label`` for a typed reply nen matched to a label; `typed (verbatim): *"…"*` for any other typed
// reply. "verbatim" is reserved for typed text.
//
// Exit codes: 0 ok · 1 a finding (a differing, unreadable, orphan or twice-cited record; an export id
// not in the ledger or a conflicting copy) · 2 wiring (usage, an unreadable roster or records directory,
// a ledger nen could not read, a path that would forge an annotation, a row that cannot be pre-answered).
// "Could not read" is never "found nothing": a roster with no record-citing line says so at exit 0.
//
// Usage:
//   node scripts/ruling_record.mts export --effort <id> --id <R-id> [--repo <checkout>] [--out <dir>]
//   node scripts/ruling_record.mts render --record <file.json> --hr <HR-n> --status <text> (--settles <text> | --settles-file <path>)
//   node scripts/ruling_record.mts check [--roster <docs/ROSTER.md>] [--records <docs/ruling-records>]
//   node scripts/ruling_record.mts preanswer --effort <id> --row <row-id> --source <text> [--repo <checkout>]
//                                  [--decisions <nen/decisions.json>] [--who <persona>] [--dry-run]
// The nen binary is $NEN, else `nen` on PATH.
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const CONTRACT = 'nen.stop.answer/v0.1';
const RECORD_ID = /^R-\d{4}-\d{2}-\d{2}-\d{2,}$/;
const LINK_DIR = 'ruling-records';
const ROW = /^\| <a id="hr-(\d+)"><\/a>\*\*HR-(\d+)\*\* · \[(R-[^\]]*)\]\(ruling-records\/([^)]*)\.json\) \|/;

interface Option { key: string; label: string; consequence: string }
interface AnswerRecord {
  contract: string; id: string; effortId: string; n: number; gate: string | null; row: string | null;
  who: string; question: string; options: Option[]; kind: 'picked' | 'typed'; pick: string | null;
  typed: string | null; answeredAt: string;
}

class Wiring extends Error {}

function nenBin(): string { return process.env.NEN || 'nen'; }

// A record is held to nen's documented shape; anything else is unreadable, never rendered from.
function validate(value: unknown): AnswerRecord {
  const r = value as Partial<AnswerRecord> | null;
  const str = (v: unknown): v is string => typeof v === 'string' && v.trim() !== '';
  if (!r || typeof r !== 'object' || Array.isArray(r)) throw new Error('not a JSON object');
  if (r.contract !== CONTRACT) throw new Error(`contract is not ${CONTRACT}`);
  if (!str(r.id) || !RECORD_ID.test(r.id)) throw new Error('id is not R-YYYY-MM-DD-nn');
  if (!str(r.question)) throw new Error('question is empty');
  if (!Array.isArray(r.options) || r.options.length === 0) throw new Error('no options');
  const keys = new Set<string>();
  for (const o of r.options) {
    if (!o || !str(o.key) || !str(o.label) || !str(o.consequence)) throw new Error('an option is not { key, label, consequence } strings');
    keys.add(o.key);
  }
  if (r.kind === 'picked') {
    if (!str(r.pick) || !keys.has(r.pick)) throw new Error('pick is none of the option keys');
    if (r.typed !== null && typeof r.typed !== 'string') throw new Error('typed is neither text nor null');
  } else if (r.kind === 'typed') {
    if (r.pick !== null || !str(r.typed)) throw new Error('a typed record carries no typed text, or a pick');
  } else throw new Error('kind is neither picked nor typed');
  return r as AnswerRecord;
}

function readRecord(path: string): AnswerRecord {
  return validate(JSON.parse(readFileSync(path, 'utf8')));
}

// Table-cell text: line breaks become <br>, a pipe is escaped, the ends trimmed.
const flat = (s: string): string => s.replace(/\r\n?/g, '\n').trim().replace(/\n/g, '<br>').replace(/\|/g, '\\|');
const em = (s: string): string => flat(s).replace(/\*/g, '\\*');
const code = (s: string): string => {
  const t = flat(s);
  return t.includes('`') ? `\`\` ${t} \`\`` : `\`${t}\``;
};

function cells(record: AnswerRecord, hr: number): string[] {
  const options = record.options.map((o) => `(${o.key}) ${flat(o.label)} — *${em(o.consequence)}*`).join(' · ');
  let answer: string;
  if (record.kind === 'typed') answer = `typed (verbatim): *"${em(record.typed ?? '')}"*`;
  else {
    const label = record.options.find((o) => o.key === record.pick)?.label ?? '';
    answer = `${record.typed === null ? 'picked' : 'typed, word for word'} (${record.pick}): ${code(label)}`;
  }
  return [`<a id="hr-${hr}"></a>**HR-${hr}** · [${record.id}](${LINK_DIR}/${record.id}.json)`, flat(record.question), options, answer];
}

// Split a table line on unescaped pipes; the leading and trailing empties dropped.
function splitRow(line: string): string[] {
  const out: string[] = [];
  let cur = '';
  for (let i = 0; i < line.length; i += 1) {
    if (line[i] === '\\' && line[i + 1] === '|') { cur += '\\|'; i += 1; continue; }
    if (line[i] === '|') { out.push(cur); cur = ''; continue; }
    cur += line[i];
  }
  out.push(cur);
  return out.slice(1, -1).map((c) => c.trim());
}

function parseArgs(argv: string[], known: Set<string>, flags = new Set<string>()): Map<string, string> {
  const out = new Map<string, string>();
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i] ?? '';
    if (flags.has(a)) { out.set(a, 'true'); continue; }
    if (!known.has(a)) throw new Wiring(`unknown argument ${a}`);
    const v = argv[i + 1];
    if (v === undefined || v === '') throw new Wiring(`${a} needs a value`);
    if (out.has(a)) throw new Wiring(`${a} given twice`);
    out.set(a, v);
    i += 1;
  }
  return out;
}

function need(args: Map<string, string>, key: string): string {
  const v = args.get(key);
  if (v === undefined) throw new Wiring(`${key} is required`);
  return v;
}

function hrNumber(text: string): number {
  const m = /^HR-([1-9]\d{0,5})$/.exec(text);
  if (!m) throw new Wiring(`--hr must be HR-<n>, got ${text}`);
  return Number(m[1]);
}

function render(argv: string[]): number {
  const args = parseArgs(argv, new Set(['--record', '--hr', '--status', '--settles', '--settles-file']));
  const hr = hrNumber(need(args, '--hr'));
  const status = need(args, '--status');
  if (args.has('--settles') === args.has('--settles-file')) throw new Wiring('give exactly one of --settles and --settles-file');
  let settles: string;
  try { settles = args.get('--settles') ?? readFileSync(need(args, '--settles-file'), 'utf8'); } catch (e) { throw new Wiring(`cannot read --settles-file: ${(e as Error).message}`); }
  if (!settles.trim() || !status.trim()) throw new Wiring('--status and the settles text must be non-empty');
  let record: AnswerRecord;
  try { record = readRecord(need(args, '--record')); } catch (e) { if (e instanceof Wiring) throw e; throw new Wiring(`cannot read --record: ${(e as Error).message}`); }
  console.log(`| ${[...cells(record, hr), flat(status), flat(settles)].join(' | ')} |`);
  return 0;
}

const CELL_NAMES = ['HR id and record link', 'question', 'options', 'answer'];

function check(argv: string[]): number {
  const args = parseArgs(argv, new Set(['--roster', '--records']));
  const roster = args.get('--roster') ?? join(ROOT, 'docs', 'ROSTER.md');
  const records = args.get('--records') ?? join(dirname(roster), LINK_DIR);
  for (const p of [roster, records]) if (/[,:\r\n]/.test(p)) throw new Wiring('refusing a path holding a comma, colon or line break: an annotation cannot name it');
  let text: string;
  try { text = readFileSync(roster, 'utf8'); } catch (e) { throw new Wiring(`cannot read ${roster}: ${(e as Error).message}`); }
  let files: string[] = [];
  if (existsSync(records)) {
    try {
      if (!statSync(records).isDirectory()) throw new Error('not a directory');
      files = readdirSync(records).filter((f) => f.endsWith('.json')).sort();
    } catch (e) { throw new Wiring(`cannot list ${records}: ${(e as Error).message}`); }
  }
  let findings = 0;
  const cited = new Map<string, number>();
  const err = (line: number, msg: string): void => { findings += 1; console.log(`::error file=${roster},line=${line}::${msg}`); };
  let rows = 0;
  text.split('\n').forEach((line, index) => {
    if (!line.includes(`](${LINK_DIR}/`)) return;
    const n = index + 1;
    const m = ROW.exec(line);
    if (!m) { err(n, `a line cites a ${LINK_DIR}/ record outside the rendered row form; re-render it (scripts/ruling_record.mts render)`); return; }
    const [, anchor = '', bold = '', id = '', file = ''] = m;
    const hr = `HR-${bold}`;
    rows += 1;
    if (anchor !== bold || id !== file || !RECORD_ID.test(id)) { err(n, `${hr}: the anchor, the record id and its file name must agree`); return; }
    cited.set(id, (cited.get(id) ?? 0) + 1);
    let record: AnswerRecord;
    try { record = readRecord(join(records, `${id}.json`)); } catch (e) { err(n, `${hr}: record ${id} is unreadable (${(e as Error).message}); the row cannot be checked`); return; }
    if (record.id !== id) { err(n, `${hr}: ${id}.json holds record ${record.id}`); return; }
    const want = cells(record, Number(bold));
    const got = splitRow(line);
    if (got.length < 6) { err(n, `${hr}: the row has ${got.length} cells, a ruling row has 6`); return; }
    for (let i = 0; i < want.length; i += 1) {
      if (got[i] !== want[i]) err(n, `${hr}: the ${CELL_NAMES[i]} cell differs from record ${id}; re-render it`);
    }
    if (!got[4] || !got[5]) err(n, `${hr}: the status and what-it-settles cells must be filled`);
  });
  for (const [id, count] of cited) if (count > 1) { findings += 1; console.log(`::error file=${roster}::record ${id} is cited by ${count} rows; one record renders one row`); }
  for (const f of files) {
    const id = f.slice(0, -'.json'.length);
    if (!cited.has(id)) { findings += 1; console.log(`::error file=${join(records, f)}::record ${id} is cited by no ROSTER row: a row retyped by hand loses its link`); }
  }
  if (findings) return 1;
  console.log(rows ? `ruling-record: ${rows} ROSTER rows match their records in ${records}` : `ruling-record: no ROSTER row cites a record yet (${roster}); nothing to compare`);
  return 0;
}

function exportRecord(argv: string[]): number {
  const args = parseArgs(argv, new Set(['--effort', '--id', '--repo', '--out']));
  const effort = need(args, '--effort');
  const id = need(args, '--id');
  if (!RECORD_ID.test(id)) throw new Wiring(`--id must be R-YYYY-MM-DD-nn, got ${id}`);
  const repo = args.get('--repo') ?? process.cwd();
  const out = args.get('--out') ?? join(ROOT, 'docs', LINK_DIR);
  const shown = spawnSync(nenBin(), ['stop', 'answer', 'show', effort, '--repo', repo, '--json'], { encoding: 'utf8' });
  if (shown.error || shown.status !== 0) {
    throw new Wiring(`nen stop answer show could not read the ledger (${shown.error?.message ?? `exit ${shown.status}`}): ${String(shown.stderr ?? '').trim()}`);
  }
  let records: unknown[];
  try { records = (JSON.parse(shown.stdout) as { records: unknown[] }).records; if (!Array.isArray(records)) throw new Error('no records[]'); } catch (e) { throw new Wiring(`nen's --json output did not parse: ${(e as Error).message}`); }
  const found = records.find((r) => (r as { id?: unknown })?.id === id);
  if (!found) { console.log(`ruling-record: ${id} is not in effort ${effort}'s ledger`); return 1; }
  let record: AnswerRecord;
  try { record = validate(found); } catch (e) { throw new Wiring(`record ${id} from nen is not ${CONTRACT}: ${(e as Error).message}`); }
  const body = `${JSON.stringify(record, null, 2)}\n`;
  const target = join(out, `${id}.json`);
  if (existsSync(target)) {
    if (readFileSync(target, 'utf8') === body) { console.log(`ruling-record: ${target} already holds ${id}`); return 0; }
    console.log(`ruling-record: ${target} exists with other content; a record id is never reused, and a copy is never replaced`);
    return 1;
  }
  mkdirSync(out, { recursive: true });
  writeFileSync(target, body, { flag: 'wx' });
  console.log(`ruling-record: exported ${id} -> ${target}`);
  return 0;
}

interface Preferred { key?: string; label?: string; consequence?: string; command?: string; recommended?: boolean }

function preanswer(argv: string[]): number {
  const args = parseArgs(argv, new Set(['--effort', '--row', '--source', '--repo', '--decisions', '--who']), new Set(['--dry-run']));
  const effort = need(args, '--effort');
  const rowId = need(args, '--row');
  const source = need(args, '--source');
  const repo = args.get('--repo') ?? process.cwd();
  const decisions = args.get('--decisions') ?? join(ROOT, 'nen', 'decisions.json');
  let rows: { id?: string; class?: string; default?: string; preferred?: Preferred[] }[];
  try { rows = (JSON.parse(readFileSync(decisions, 'utf8')) as { rows: typeof rows }).rows; if (!Array.isArray(rows)) throw new Error('no rows[]'); } catch (e) { throw new Wiring(`cannot read ${decisions}: ${(e as Error).message}`); }
  const row = rows.find((r) => r.id === rowId);
  if (!row) throw new Wiring(`row ${rowId} is not in ${decisions}`);
  if (row.class !== 'ask-once-per-run') throw new Wiring(`row ${rowId} is ${row.class}: only an ask-once-per-run row is pre-answered; a human-gate row never is (HR-5)`);
  const preferred = row.preferred ?? [];
  const starred = preferred.filter((p) => p.recommended === true);
  if (starred.length !== 1 || !starred[0]?.key) throw new Wiring(`row ${rowId} stars ${starred.length} options: its default cannot be pre-answered as a pick; it parks (hold)`);
  const options = preferred.map((p) => {
    const consequence = p.consequence ?? p.command;
    if (!p.key || !p.label || !consequence) throw new Wiring(`row ${rowId} has an option with no key, label or consequence`);
    return `${p.key}=${p.label}::${consequence}`;
  });
  const scratch = mkdtempSync(join(tmpdir(), 'hatsu-preanswer-'));
  try {
    const question = join(scratch, 'question.md');
    writeFileSync(question, `Pre-answered under the typed --idle profile (HR-5); no picker was shown.\nSource: ${source}\nRow ${rowId}: ${row.default ?? ''}\n`);
    const call = ['stop', 'answer', '--record', effort, '--row', rowId, '--who', args.get('--who') ?? 'kurapika',
      '--question-file', question, ...options.flatMap((o) => ['--option', o]), '--pick', starred[0].key, '--repo', repo];
    if (args.has('--dry-run')) call.push('--dry-run');
    const result = spawnSync(nenBin(), call, { encoding: 'utf8' });
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) throw new Wiring(`nen could not be run: ${result.error.message}`);
    return result.status ?? 2;
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
}

function main(argv: string[]): number {
  const [verb, ...rest] = argv;
  try {
    switch (verb) {
      case 'export': return exportRecord(rest);
      case 'render': return render(rest);
      case 'check': return check(rest);
      case 'preanswer': return preanswer(rest);
      default: throw new Wiring('usage: ruling_record.mts export|render|check|preanswer … (see the header)');
    }
  } catch (e) {
    if (!(e instanceof Wiring)) throw e;
    console.error(`ruling-record: ${e.message}`);
    return 2;
  }
}

process.exit(main(process.argv.slice(2)));
