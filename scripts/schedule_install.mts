#!/usr/bin/env node
// schedule_install.mts — PRINT the steady-state scheduler rows for the maintainer to register
// (zheref/hatsu#448; ruling R-2026-10-23-21, effort HA-IS-#450: Claude Code Desktop's local
// scheduled tasks on the maintainer's own machine, firing while it is awake).
//
// Reads contracts/schedule.json and prints, per `desktop-task` row, the fields of Claude Desktop's
// New scheduled task form (Code tab -> Scheduled -> New task -> Set up manually -> Advanced settings
// -> Only on this computer) and the SKILL.md Desktop keeps at
// ~/.claude/scheduled-tasks/<name>/SKILL.md (frontmatter `name` and `description`, the prompt as the
// body; the schedule, folder, model and permission mode are form fields, not in that file). A `ci`
// row is printed as the workflow job that already carries it. It REGISTERS NOTHING AND WRITES
// NOTHING: no file, no directory, no network, no child process. The machine is the maintainer's;
// an agent prints, the maintainer registers. Page: docs/config/schedule.md.
//
// USAGE  node scripts/schedule_install.mts [--root <hatsu checkout>] [--folder <abs path>]
//          [--spec-folder <abs path>] [--family <slug>] [--repo <owner/name>] [--json]
//   --root         the checkout whose contracts/schedule.json is read (default: this script's)
//   --folder       the Hatsu checkout the drift pass and the morning desk run in (default: --root)
//   --spec-folder  the family's private spec-repository checkout the recapture runs in
//   --family       the family slug the recapture names; printed to stdout only, never written
//   --repo         the owner/name the morning desk renders (default zheref/hatsu)
//   --json         one document: {contract, ruling, scheduler, unfilled[], rows[]}
//
// EXITS  0 every row printed with every placeholder filled;
//        1 every row printed, at least one placeholder unfilled, each named on stderr as
//          `unfilled: <placeholder> (<row>) -- pass <flag>`; the printed text keeps the placeholder,
//          so a task registered from it is visibly incomplete, never silently wrong;
//        2 wiring: an unknown or valueless flag, a relative or missing folder, a family that is not
//          a slug, a repo that is not owner/name, an unreadable, non-JSON or malformed contract (an
//          unknown contract id, a row missing a field its kind needs, a repeated id or name, a cron
//          that is not five fields). Never a printout over a contract it could not read.
import { existsSync, readFileSync, realpathSync, statSync } from 'node:fs';
import { dirname, isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

type Trigger = { form: string; cron: string; reads: string };
type Task = { id: string; kind: 'desktop-task'; name: string; description: string; trigger: Trigger; folder: string; worktree: boolean; permissionMode: string; model: string; prompt: string[] };
type Ci = { id: string; kind: 'ci'; workflow: string; job: string; reads: string };
type Contract = { contract: string; ruling: string; scheduler: string; placeholders: Record<string, string>; rows: Array<Task | Ci> };
class Wiring extends Error {}
const wiring = (m: string): never => { throw new Wiring(m); };

const FLAGS = new Set(['--root', '--folder', '--spec-folder', '--family', '--repo']);
const FORMS = new Set(['Hourly', 'Daily', 'Weekdays', 'Weekly', 'Manual', 'Custom']);

function parseArgs(argv: string[]): Map<string, string> {
  const out = new Map<string, string>();
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--json') { out.set(a, 'true'); continue; }
    if (!FLAGS.has(a)) wiring(`unknown flag ${a}`);
    const v = argv[++i];
    if (v === undefined || v.startsWith('--')) wiring(`${a} needs a value`);
    out.set(a, v);
  }
  return out;
}

function folderFlag(a: Map<string, string>, flag: string): string | undefined {
  const v = a.get(flag);
  if (v === undefined) return undefined;
  if (!isAbsolute(v)) wiring(`${flag} ${v} is not an absolute path`);
  if (!existsSync(v) || !statSync(v).isDirectory()) wiring(`${flag} ${v} is not a directory`);
  return v;
}

function load(root: string): Contract {
  const path = join(root, 'contracts/schedule.json');
  if (!existsSync(path)) wiring(`${path} is missing`);
  let c: Contract;
  try { c = JSON.parse(readFileSync(path, 'utf8')) as Contract; } catch (e) { return wiring(`contracts/schedule.json is not JSON: ${(e as Error).message}`); }
  if (c?.contract !== 'hatsu.schedule/v0.1') wiring(`contracts/schedule.json: contract ${JSON.stringify(c?.contract)} is not hatsu.schedule/v0.1`);
  for (const k of ['ruling', 'scheduler'] as const) if (typeof c[k] !== 'string' || !c[k]) wiring(`contracts/schedule.json: ${k} is missing`);
  if (!c.placeholders || typeof c.placeholders !== 'object') wiring('contracts/schedule.json: placeholders is missing');
  if (!Array.isArray(c.rows) || c.rows.length === 0) wiring('contracts/schedule.json: rows is missing or empty');
  const seen = new Set<string>();
  for (const r of c.rows) {
    const str = (k: string): void => { if (typeof (r as Record<string, unknown>)[k] !== 'string' || !(r as Record<string, unknown>)[k]) wiring(`contracts/schedule.json: row ${r?.id ?? '?'} has no ${k}`); };
    str('id');
    if (seen.has(r.id)) wiring(`contracts/schedule.json: row id ${r.id} repeats`);
    seen.add(r.id);
    if (r.kind === 'ci') { for (const k of ['workflow', 'job', 'reads']) str(k); continue; }
    if (r.kind !== 'desktop-task') wiring(`contracts/schedule.json: row ${r.id} has kind ${JSON.stringify((r as { kind: unknown }).kind)}, not desktop-task or ci`);
    for (const k of ['name', 'description', 'folder', 'permissionMode', 'model']) str(k);
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(r.name)) wiring(`contracts/schedule.json: row ${r.id} name ${r.name} is not lowercase kebab-case (Desktop's folder name)`);
    if (seen.has(`name:${r.name}`)) wiring(`contracts/schedule.json: task name ${r.name} repeats`);
    seen.add(`name:${r.name}`);
    if (typeof r.worktree !== 'boolean') wiring(`contracts/schedule.json: row ${r.id} worktree is not a boolean`);
    const t = r.trigger;
    if (!t || !FORMS.has(t.form)) wiring(`contracts/schedule.json: row ${r.id} trigger.form is not one of ${[...FORMS].join(', ')}`);
    if (typeof t.cron !== 'string' || t.cron.trim().split(/\s+/).length !== 5) wiring(`contracts/schedule.json: row ${r.id} trigger.cron is not five fields`);
    if (typeof t.reads !== 'string' || !t.reads) wiring(`contracts/schedule.json: row ${r.id} trigger.reads is missing`);
    if (!Array.isArray(r.prompt) || r.prompt.length === 0 || r.prompt.some((p) => typeof p !== 'string' || !p)) wiring(`contracts/schedule.json: row ${r.id} prompt is not a non-empty list of lines`);
  }
  return c;
}

export function run(argv: string[]): { code: number; out: string; err: string } {
  try {
    const a = parseArgs(argv);
    const root = resolve(a.get('--root') ?? join(dirname(fileURLToPath(import.meta.url)), '..'));
    const c = load(root);
    const family = a.get('--family');
    if (family !== undefined && !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(family)) wiring(`--family ${family} is not a slug`);
    const repo = a.get('--repo') ?? 'zheref/hatsu';
    if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo)) wiring(`--repo ${repo} is not owner/name`);
    const values: Record<string, string | undefined> = {
      '<hatsu>': folderFlag(a, '--folder') ?? root,
      '<spec>': folderFlag(a, '--spec-folder'),
      '<family>': family,
      '<repo>': repo,
    };
    const flagOf: Record<string, string> = { '<hatsu>': '--folder', '<spec>': '--spec-folder', '<family>': '--family', '<repo>': '--repo' };
    const unfilled: Array<{ placeholder: string; row: string; flag: string }> = [];
    const fill = (row: string, s: string): string => s.replace(/<hatsu>|<spec>|<family>|<repo>/g, (p) => {
      const v = values[p];
      if (v === undefined) { if (!unfilled.some((u) => u.placeholder === p && u.row === row)) unfilled.push({ placeholder: p, row, flag: flagOf[p] }); return p; }
      return v;
    });
    const rows = c.rows.map((r) => r.kind === 'ci' ? r : {
      ...r, folder: fill(r.id, r.folder), prompt: r.prompt.map((p) => fill(r.id, p)),
      skillMd: `---\nname: ${r.name}\ndescription: ${JSON.stringify(r.description)}\n---\n\n${r.prompt.map((p) => fill(r.id, p)).join('\n\n')}\n`,
    });
    const code = unfilled.length ? 1 : 0;
    const err = unfilled.map((u) => `unfilled: ${u.placeholder} (${u.row}) -- pass ${u.flag}\n`).join('');
    if (a.has('--json')) {
      return { code, err, out: JSON.stringify({ contract: c.contract, ruling: c.ruling, scheduler: c.scheduler, registered: false, unfilled, rows }, null, 2) + '\n' };
    }
    let out = `schedule_install: ${rows.length} rows from contracts/schedule.json (ruling ${c.ruling}; scheduler ${c.scheduler}).\n`;
    out += 'NOTHING IS REGISTERED. Register each task yourself in Claude Desktop: Code tab -> Scheduled -> New task -> Set up manually;\n';
    out += 'under Advanced settings turn on "Only on this computer", then fill the fields below. After Create, press Run now once and\n';
    out += 'answer each permission prompt, so later runs do not stall. A task fires only while Desktop is open and the machine is awake.\n';
    for (const r of rows) {
      out += `\n=== ${r.id} ===\n`;
      if (r.kind === 'ci') { out += `not a task: runs in CI, ${r.workflow} job ${r.job}\nwhen: ${r.reads}\n`; continue; }
      const t = r as Task & { skillMd: string };
      out += `Name:            ${t.name}\nDescription:     ${t.description}\n`;
      out += `Trigger:         ${t.trigger.form} -- ${t.trigger.reads}; as Custom (Edit form): ${t.trigger.cron}\n`;
      out += `Local folder:    ${t.folder}\nWorktree:        ${t.worktree ? 'on (Edit form)' : 'off'}\n`;
      out += `Permission mode: ${t.permissionMode}\nModel:           ${t.model}\n`;
      out += `SKILL.md, as Desktop keeps it at ~/.claude/scheduled-tasks/${t.name}/SKILL.md (the instructions box):\n`;
      out += t.skillMd.trimEnd().split('\n').map((l) => (l ? `  | ${l}` : '  |')).join('\n') + '\n';
    }
    return { code, out, err };
  } catch (e) {
    if (e instanceof Wiring) return { code: 2, out: '', err: `schedule_install: ${e.message}\n` };
    return { code: 2, out: '', err: `schedule_install: internal error: ${(e as Error).stack ?? e}\n` };
  }
}

// Compared as REAL paths, the prose_ambiguity_check.mts precedent: invoked through a symlinked
// directory the unresolved argv path never equals the module URL, and a guard that then prints
// nothing exits 0 -- a false pass, never a verdict.
function samePath(x: string, y: string): boolean {
  try { return realpathSync(x) === realpathSync(y); } catch { return x === y; }
}
if (process.argv[1] && samePath(process.argv[1], fileURLToPath(import.meta.url))) {
  const r = run(process.argv.slice(2));
  process.stdout.write(r.out);
  process.stderr.write(r.err);
  process.exit(r.code);
}
