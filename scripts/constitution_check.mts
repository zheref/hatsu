#!/usr/bin/env node
// constitution_check.mts — the deterministic half of breath's plan-time constitution check
// (docs/ROSTER.md HR-10, narrowed by HR-337; zheref/hatsu#505). Interim: the verb is owed to nen
// (zheref/nen#554), and this script retires when it lands.
//
//   node scripts/constitution_check.mts --request <file> [--root <hatsu checkout>]
//        [--constitution <CONSTITUTION.md>] [--json]
//
// It reads a REQUEST (an issue body, a brief, the maintainer's words saved to a file) and answers,
// per clause, what the request leans on. It never decides a conflict: whether the plan contradicts a
// clause it lists is the caller's reading of that clause's words, recorded by breath § 4a.
//
//   1. CITED. Every `HR-N` and `CON-N` the request names (whole numbers: HR-2 never matches HR-20).
//   2. TOUCHED. Every skill the request names — `hatsu:<name>`, `` `<name>` ``, or
//      `claude/skills/<name>/`, for a <name> that is a directory under <root>/claude/skills — selects
//      each HR row whose DEFINITION LINE names that skill the same ways (or as `../<name>/SKILL.md`)
//      and that still binds. CON clauses name no Hatsu skill, so only a cited CON id is read.
//   3. FOLLOWED. A row `reversed by` / `superseded by` HR-m is followed to HR-m, transitively.
//   4. STATUS decides binding (HR-337: only `ruled` rows bind): `ruled` binds whole; `reading` binds
//      nothing; a displacement with a part, `(…; the rest stands)`, binds the rest (`part`); one with
//      no part binds nothing. The status words and the row parser are clause_id_guard.mts's,
//      imported, never repeated. A CON clause at the pinned tag binds whole.
//   5. DANGLING. A cited id no row (or no CON clause) defines is a finding, exit 1.
//
// The `record:` line is what breath passes to `nen phase end --note`.
//
// exit 0  every cited id resolves · exit 1  a cited id dangles, each named · exit 2  wiring: a usage
// error, an unreadable request, roster or constitution, a roster whose status rows the clause guard
// refuses, a CON id cited with no --constitution, or a constitution defining no CON clause — an
// unperformed check is never a pass.
import { existsSync, readdirSync, readFileSync, realpathSync, statSync } from 'node:fs';
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
  readonly contract: 'hatsu.constitution-check/v0.1';
  readonly request: string;
  readonly roster: string;
  readonly constitution: string | null;
  readonly skills: readonly string[];
  readonly clauses: readonly Clause[];
  readonly read: readonly string[];
  readonly dangling: readonly string[];
  readonly record: string;
  readonly exit: 0 | 1;
}

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
  if (status === 'ruled') return { binding: 'whole', displacedBy: [] };
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

export function check(options: { request: string; root: string; constitution: string | null }): Verdict {
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
  const rows = new Map(statuses.map((s) => [`HR-${s.id}`, s]));
  const lines = rosterText.split('\n');
  const skillsDir = join(options.root, 'claude', 'skills');
  if (!existsSync(skillsDir)) throw new Wiring(`${options.root} is not a Hatsu checkout (no claude/skills)`);
  const skills = readdirSync(skillsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && /^[a-z0-9][a-z0-9-]*$/.test(d.name))
    .map((d) => d.name)
    .filter((name) => names(requestText, name, false))
    .sort();

  const clauses = new Map<string, { id: string; status: string; binding: Binding; via: string[]; line: number }>();
  const dangling: string[] = [];
  const visit = (id: string, via: string): void => {
    const known = clauses.get(id);
    if (known) {
      if (!known.via.includes(via)) known.via.push(via);
      return;
    }
    const row = rows.get(id);
    if (!row) return;
    const { binding, displacedBy } = bindingOf(row.status);
    clauses.set(id, { id, status: row.status, binding, via: [via], line: row.line });
    for (const next of displacedBy) visit(next, `follows ${id}`);
  };
  for (const id of ids(requestText, 'HR')) {
    if (rows.has(id)) visit(id, 'cited');
    else dangling.push(id);
  }
  for (const skill of skills) {
    for (const [id, row] of rows) {
      if (bindingOf(row.status).binding === 'none') continue;
      if (names(lines[row.line - 1] ?? '', skill, true)) visit(id, `touched ${skill}`);
    }
  }

  const cons = ids(requestText, 'CON');
  let constitution: string | null = null;
  if (cons.length) {
    if (options.constitution === null) {
      throw new Wiring(`the request cites ${cons.join(', ')} and no --constitution names CONSTITUTION.md at the pinned tag (HR-338); a CON id is never read from memory`);
    }
    constitution = options.constitution;
    const text = read(constitution, 'constitution');
    const defined = new Map<string, number>();
    text.split('\n').forEach((line, offset) => {
      const match = /^- \*\*CON-(\d{1,15})\./.exec(line);
      if (match && !defined.has(`CON-${Number(match[1])}`)) defined.set(`CON-${Number(match[1])}`, offset + 1);
    });
    if (defined.size === 0) throw new Wiring(`${constitution} defines no CON clause (- **CON-N.**); refusing to read it as clean`);
    for (const id of cons) {
      const line = defined.get(id);
      if (line === undefined) dangling.push(id);
      else clauses.set(id, { id, status: 'constitution', binding: 'whole', via: ['cited'], line });
    }
  }

  const order = (a: string, b: string): number => a.localeCompare(b, 'en', { numeric: true });
  const list = [...clauses.values()].sort((a, b) => order(a.id, b.id));
  const readIds = list.filter((c) => c.binding !== 'none').map((c) => (c.binding === 'part' ? `${c.id}(part)` : c.id));
  const unbound = list.filter((c) => c.binding === 'none').map((c) => c.id);
  dangling.sort(order);
  const record = `constitution-check: read=${readIds.join(',') || 'none'}; not-binding=${unbound.join(',') || 'none'}; dangling=${dangling.join(',') || 'none'}`;
  return {
    contract: 'hatsu.constitution-check/v0.1',
    request: options.request,
    roster: rosterPath,
    constitution,
    skills,
    clauses: list,
    read: readIds,
    dangling,
    record,
    exit: dangling.length ? 1 : 0,
  };
}

const USAGE = 'usage: constitution_check.mts --request <file> [--root <hatsu checkout>] [--constitution <CONSTITUTION.md>] [--json]';

export function main(argv: string[]): number {
  let request: string | null = null;
  let root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  let constitution: string | null = null;
  let json = false;
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (flag === '--json') { json = true; continue; }
    if ((flag === '--request' || flag === '--root' || flag === '--constitution') && value !== undefined && value !== '' && !value.startsWith('--')) {
      if (flag === '--request') request = value;
      else if (flag === '--root') root = value;
      else constitution = value;
      i += 1;
      continue;
    }
    console.error(`constitution-check: unknown or valueless argument '${flag}'\n${USAGE}`);
    return 2;
  }
  if (request === null) {
    console.error(`constitution-check: --request is required\n${USAGE}`);
    return 2;
  }
  let verdict: Verdict;
  try {
    verdict = check({ request, root, constitution });
  } catch (error) {
    if (!(error instanceof Wiring)) throw error;
    console.error(`constitution-check: ${error.message}`);
    return 2;
  }
  if (json) {
    console.log(JSON.stringify(verdict, null, 2));
    return verdict.exit;
  }
  console.log(`constitution-check: request ${verdict.request}; roster ${verdict.roster}; constitution ${verdict.constitution ?? 'none (no CON id cited)'}; skills named ${verdict.skills.join(', ') || 'none'}`);
  for (const c of verdict.clauses) {
    const where = c.status === 'constitution' ? `${verdict.constitution}:${c.line}` : `docs/ROSTER.md:${c.line}`;
    console.log(`${c.binding === 'none' ? 'not binding' : `read (${c.binding})`} ${c.id} · ${c.status} · ${c.via.join('; ')} · ${where}`);
  }
  for (const id of verdict.dangling) console.log(`dangling ${id} · cited · no clause defines it`);
  console.log(`record: ${verdict.record}`);
  return verdict.exit;
}

let invoked = false;
try {
  invoked = process.argv[1] !== undefined && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
} catch {
  invoked = false;
}
if (invoked) process.exitCode = main(process.argv.slice(2));
