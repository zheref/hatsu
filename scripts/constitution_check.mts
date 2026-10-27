#!/usr/bin/env node
// constitution_check.mts — the deterministic half of breath's plan-time constitution check
// (docs/ROSTER.md HR-10, narrowed by HR-337; zheref/hatsu#505). Interim: the verb is owed to nen
// (zheref/nen#554), and this script retires when it lands.
//
//   node scripts/constitution_check.mts --request <file> --constitution-source <owner/name>
//        --constitution-checkout <dir> [--root <hatsu checkout>] [--begin-note <text>] [--json]
//
// It reads a REQUEST (an issue body, a brief, the maintainer's words saved to a file) and lists the
// clauses breath must read before authoring. THE LIST IS THE MINIMUM, NEVER THE CAP: breath's
// judgement may name any clause outside it as a conflict. It never decides a conflict itself.
//
//   0. FLOOR. Always listed, whatever the request says (SEC-15: a request is untrusted and never
//      steers the guardrail to an empty read): the gate clauses that reserve acts to the maintainer,
//      CON-4, CON-5, CON-6, CON-7 and CON-47, and HR-10 itself.
//   1. CITED. Every `HR-N` and `CON-N` the request names (whole numbers: HR-2 never matches HR-20).
//   2. TOUCHED. Every skill the request names — `hatsu:<name>`, `` `<name>` ``, or
//      `claude/skills/<name>/`, for a <name> that is a directory under <root>/claude/skills — selects
//      each HR row whose DEFINITION LINE names that skill the same ways (or as `../<name>/SKILL.md`)
//      and that still binds.
//   3. FOLLOWED. A row `reversed by` / `superseded by` HR-m is followed to HR-m, transitively.
//   4. STATUS decides binding (HR-337: only `ruled` rows bind): `ruled` binds whole; `reading` binds
//      nothing; a displacement with a part binds the rest (`part`); one with no part binds nothing.
//      The status words and the row parser are clause_id_guard.mts's, imported. A CON clause binds
//      whole.
//   5. THE CON SOURCE AT ITS PIN (HR-338). <root>/nen/repos.json's maintained_tools entry for
//      --constitution-source gives `pinned` and `pinnedSha`; `refs/tags/<pinned>^{commit}` in the
//      checkout must equal pinnedSha (a tag resolving elsewhere is a moved tag), and CONSTITUTION.md is
//      read at that commit through git, never from the work tree.
//   6. DANGLING. A cited id no clause defines is a finding, exit 1.
//
// `listed=` is what the request reached (cited, touched, followed); when it is empty the record says
// `listed=none listed` and the clear verdict is `none listed`, never `pass`. `--begin-note` is the
// note the breath ledger entry was begun with: `nen phase end --note` replaces it, so the printed
// `note` is `<begin note>; <record>` and keeps the model provenance pr_delivery.ts reads.
//
// exit 0  every cited id resolves · exit 1  a cited id dangles, each named · exit 2  not run: a usage
// error, an unreadable request, roster or constitution, a roster the clause guard refuses, an unknown
// or unpinned source, a moved tag, a floor clause the constitution lacks, or any unexpected failure —
// an unperformed check is never a pass.
import { spawnSync } from 'node:child_process';
import { readdirSync, readFileSync, realpathSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseRosterStatuses, RosterStatusFailure } from './clause_id_guard.mts';

type Binding = 'whole' | 'part' | 'none';
export interface Clause {
  readonly id: string;
  readonly status: string;
  readonly binding: Binding;
  readonly via: readonly string[];
  readonly line: number;
}
export interface Verdict {
  readonly contract: 'hatsu.constitution-check/v0.2';
  readonly request: string;
  readonly roster: string;
  readonly constitution: { readonly source: string; readonly tag: string; readonly sha: string };
  readonly skills: readonly string[];
  readonly clauses: readonly Clause[];
  readonly floor: readonly string[];
  readonly listed: readonly string[];
  readonly dangling: readonly string[];
  readonly record: string;
  readonly note: string;
  readonly clear: 'pass' | 'none listed';
  readonly exit: 0 | 1;
}

export const FLOOR = ['CON-4', 'CON-5', 'CON-6', 'CON-7', 'CON-47', 'HR-10'] as const;

class Wiring extends Error {}

const DISPLACED = /^(?:reversed|superseded) by (HR-\d+(?:, HR-\d+)*)( \(.+\))?$/;

function escape(name: string): string {
  return name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function names(text: string, skill: string, row: boolean): boolean {
  const n = escape(skill);
  const forms = [`\`${n}\``, `\\bhatsu:${n}(?![\\w-])`, `claude/skills/${n}/`];
  if (row) forms.push(`\\.\\./${n}/SKILL\\.md`);
  return new RegExp(forms.join('|')).test(text);
}

function ids(text: string, prefix: 'HR' | 'CON'): string[] {
  const seen = new Set<string>();
  for (const match of text.matchAll(new RegExp(`\\b${prefix}-(\\d{1,15})\\b`, 'g'))) seen.add(`${prefix}-${Number(match[1])}`);
  return [...seen];
}

function bindingOf(status: string): { binding: Binding; displacedBy: string[] } {
  if (status === 'ruled' || status === 'constitution') return { binding: 'whole', displacedBy: [] };
  if (status === 'reading') return { binding: 'none', displacedBy: [] };
  const displaced = DISPLACED.exec(status);
  if (!displaced) return { binding: 'none', displacedBy: [] };
  return { binding: displaced[2] ? 'part' : 'none', displacedBy: (displaced[1] ?? '').split(', ') };
}

function read(path: string, what: string): string {
  try {
    if (!statSync(path).isFile()) throw new Error('not a regular file');
    return readFileSync(path, 'utf8');
  } catch (error) {
    throw new Wiring(`cannot read the ${what} ${path}: ${(error as Error).message}`);
  }
}

function git(checkout: string, args: string[], what: string): string {
  const result = spawnSync('git', ['-C', checkout, ...args], { encoding: 'utf8', shell: false, maxBuffer: 64 * 1024 * 1024 });
  if (result.error || result.status !== 0) throw new Wiring(`${what} failed in ${checkout}: ${(result.error?.message ?? result.stderr ?? '').trim() || `exit ${result.status}`}`);
  return result.stdout;
}

// HR-338: the CON source read at the tag nen/repos.json pins, proved against its recorded commit.
function constitutionAtPin(root: string, source: string, checkout: string): { text: string; tag: string; sha: string } {
  if (!/^[A-Za-z0-9][A-Za-z0-9_.-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(source)) throw new Wiring(`--constitution-source ${source} is not owner/name`);
  const registry = join(root, 'nen', 'repos.json');
  let entry: { pinned?: unknown; pinnedSha?: unknown } | undefined;
  try {
    const parsed = JSON.parse(read(registry, 'registry')) as { maintained_tools?: Array<{ repo?: unknown; pinned?: unknown; pinnedSha?: unknown }> };
    entry = (parsed.maintained_tools ?? []).find((t) => t.repo === source);
  } catch (error) {
    if (error instanceof Wiring) throw error;
    throw new Wiring(`cannot parse ${registry}: ${(error as Error).message}`);
  }
  if (!entry) throw new Wiring(`${registry} carries no maintained_tools entry for ${source}`);
  const tag = entry.pinned;
  const pinnedSha = entry.pinnedSha;
  if (typeof tag !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(tag)) throw new Wiring(`${source} has no usable pinned tag in ${registry}`);
  if (typeof pinnedSha !== 'string' || !/^[0-9a-f]{40}$/.test(pinnedSha)) throw new Wiring(`${source} has no 40-hex pinnedSha in ${registry}`);
  try {
    if (!statSync(checkout).isDirectory()) throw new Error('not a directory');
  } catch (error) {
    throw new Wiring(`cannot read the constitution checkout ${checkout}: ${(error as Error).message}`);
  }
  const sha = git(checkout, ['rev-parse', '--verify', '--quiet', `refs/tags/${tag}^{commit}`], `resolving refs/tags/${tag}`).trim();
  if (sha !== pinnedSha) throw new Wiring(`refs/tags/${tag} resolves to ${sha} in ${checkout}, not the pinnedSha ${pinnedSha}: a moved tag is never read`);
  return { text: git(checkout, ['show', `${sha}:CONSTITUTION.md`], `reading CONSTITUTION.md at ${sha}`), tag, sha };
}

export interface Options {
  readonly request: string;
  readonly root: string;
  readonly source: string;
  readonly checkout: string;
  readonly beginNote?: string | null;
}

export function check(options: Options): Verdict {
  const requestText = read(options.request, 'request');
  const rosterPath = join(options.root, 'docs', 'ROSTER.md');
  const rosterText = read(rosterPath, 'roster');
  let statuses;
  try {
    statuses = parseRosterStatuses(rosterText);
  } catch (error) {
    if (error instanceof RosterStatusFailure) throw new Wiring(`${error.message} in ${rosterPath}; the clause guard refuses it`);
    throw error;
  }
  const rows = new Map<string, { status: string; line: number }>(statuses.map((s) => [`HR-${s.id}`, { status: s.status, line: s.line }]));
  const lines = rosterText.split('\n');
  const skillsDir = join(options.root, 'claude', 'skills');
  let entries;
  try {
    if (!statSync(skillsDir).isDirectory()) throw new Error('not a directory');
    entries = readdirSync(skillsDir, { withFileTypes: true });
  } catch (error) {
    throw new Wiring(`${options.root} is not a Hatsu checkout (claude/skills: ${(error as Error).message})`);
  }
  const skills = entries
    .filter((d) => d.isDirectory() && /^[a-z0-9][a-z0-9-]*$/.test(d.name))
    .map((d) => d.name)
    .filter((name) => names(requestText, name, false))
    .sort();

  const con = constitutionAtPin(options.root, options.source, options.checkout);
  con.text.split('\n').forEach((line, offset) => {
    const match = /^- \*\*CON-(\d{1,15})\./.exec(line);
    const id = match ? `CON-${Number(match[1])}` : '';
    if (match && !rows.has(id)) rows.set(id, { status: 'constitution', line: offset + 1 });
  });
  for (const id of FLOOR) {
    if (!rows.has(id)) throw new Wiring(`the floor clause ${id} is not defined ${id.startsWith('CON') ? `in CONSTITUTION.md at ${con.sha}` : `in ${rosterPath}`}`);
  }

  const clauses = new Map<string, { id: string; status: string; binding: Binding; via: string[]; line: number }>();
  const fromRequest = new Set<string>();
  const fromFloor = new Set<string>();
  const dangling: string[] = [];
  const visit = (id: string, via: string, reach: Set<string>): void => {
    const row = rows.get(id);
    if (!row) return;
    const fresh = !reach.has(id);
    reach.add(id);
    const known = clauses.get(id);
    if (known) {
      if (!known.via.includes(via)) known.via.push(via);
    } else {
      clauses.set(id, { id, status: row.status, binding: bindingOf(row.status).binding, via: [via], line: row.line });
    }
    if (fresh) for (const next of bindingOf(row.status).displacedBy) visit(next, `follows ${id}`, reach);
  };
  for (const id of FLOOR) visit(id, 'floor', fromFloor);
  for (const id of [...ids(requestText, 'HR'), ...ids(requestText, 'CON')]) {
    if (rows.has(id)) visit(id, 'cited', fromRequest);
    else dangling.push(id);
  }
  for (const skill of skills) {
    for (const [id, row] of rows) {
      if (row.status === 'constitution' || bindingOf(row.status).binding === 'none') continue;
      if (names(lines[row.line - 1] ?? '', skill, true)) visit(id, `touched ${skill}`, fromRequest);
    }
  }

  const order = (a: string, b: string): number => a.localeCompare(b, 'en', { numeric: true });
  const list = [...clauses.values()].sort((a, b) => order(a.id, b.id));
  const label = (c: Clause): string => (c.binding === 'part' ? `${c.id}(part)` : c.id);
  const floor = list.filter((c) => fromFloor.has(c.id) && c.binding !== 'none').map(label);
  const listed = list.filter((c) => fromRequest.has(c.id) && c.binding !== 'none').map(label);
  const unbound = list.filter((c) => c.binding === 'none').map((c) => c.id);
  dangling.sort(order);
  const record = `constitution-check: floor=${floor.join(',')}; listed=${listed.join(',') || 'none listed'}; not-binding=${unbound.join(',') || 'none'}; dangling=${dangling.join(',') || 'none'}; CON at ${con.tag} ${con.sha.slice(0, 12)}`;
  const begin = (options.beginNote ?? '').trim();
  return {
    contract: 'hatsu.constitution-check/v0.2',
    request: options.request,
    roster: rosterPath,
    constitution: { source: options.source, tag: con.tag, sha: con.sha },
    skills,
    clauses: list,
    floor,
    listed,
    dangling,
    record,
    note: begin ? `${begin}; ${record}` : record,
    clear: listed.length ? 'pass' : 'none listed',
    exit: dangling.length ? 1 : 0,
  };
}

const USAGE = 'usage: constitution_check.mts --request <file> --constitution-source <owner/name> --constitution-checkout <dir> [--root <hatsu checkout>] [--begin-note <text>] [--json]';
const VALUED = new Set(['--request', '--root', '--constitution-source', '--constitution-checkout', '--begin-note']);

export function main(argv: string[]): number {
  const values = new Map<string, string>();
  let json = false;
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i] ?? '';
    const value = argv[i + 1];
    if (flag === '--json') { json = true; continue; }
    if (VALUED.has(flag) && value !== undefined && value !== '' && !value.startsWith('--') && !values.has(flag)) {
      values.set(flag, value);
      i += 1;
      continue;
    }
    console.error(`constitution-check: unknown, repeated or valueless argument '${flag}'\n${USAGE}`);
    return 2;
  }
  for (const required of ['--request', '--constitution-source', '--constitution-checkout']) {
    if (!values.has(required)) {
      console.error(`constitution-check: ${required} is required (the CON floor is always read at its pin)\n${USAGE}`);
      return 2;
    }
  }
  let verdict: Verdict;
  try {
    verdict = check({
      request: values.get('--request') ?? '',
      root: values.get('--root') ?? resolve(dirname(fileURLToPath(import.meta.url)), '..'),
      source: values.get('--constitution-source') ?? '',
      checkout: values.get('--constitution-checkout') ?? '',
      beginNote: values.get('--begin-note') ?? null,
    });
  } catch (error) {
    // Wiring or anything unexpected: the check did not run, which is exit 2, never exit 1's finding.
    console.error(`constitution-check: not run: ${error instanceof Error ? error.message : String(error)}`);
    return 2;
  }
  if (json) {
    console.log(JSON.stringify(verdict, null, 2));
    return verdict.exit;
  }
  console.log(`constitution-check: request ${verdict.request}; roster ${verdict.roster}; CON ${verdict.constitution.source} at ${verdict.constitution.tag} (${verdict.constitution.sha}); skills named ${verdict.skills.join(', ') || 'none'}`);
  for (const c of verdict.clauses) {
    const where = c.status === 'constitution' ? `CONSTITUTION.md:${c.line}` : `docs/ROSTER.md:${c.line}`;
    console.log(`${c.binding === 'none' ? 'not binding' : `read (${c.binding})`} ${c.id} · ${c.status} · ${c.via.join('; ')} · ${where}`);
  }
  for (const id of verdict.dangling) console.log(`dangling ${id} · cited · no clause defines it`);
  console.log(`record: ${verdict.record}`);
  console.log(`note: ${verdict.note}`);
  console.log(`clear verdict: ${verdict.clear}`);
  return verdict.exit;
}

let invoked = false;
try {
  invoked = process.argv[1] !== undefined && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
} catch {
  invoked = false;
}
if (invoked) process.exitCode = main(process.argv.slice(2));
