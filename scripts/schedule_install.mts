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
// row is printed as the workflow job that already carries it. Under each task it prints the row's
// always-allow list and the contract's never-always-allow list (SEC-9: an unattended run pre-approves
// reads only; every write asks every run). It REGISTERS NOTHING AND WRITES
// NOTHING: no file, no directory, no network, no child process. The machine is the maintainer's;
// an agent prints, the maintainer registers. Page: docs/config/schedule.md.
//
// USAGE  node scripts/schedule_install.mts [--root <hatsu checkout>] [--folder <abs path>]
//          [--spec-folder <abs path>] [--family <slug>] [--repo <owner/name>] [--json | --table]
//   --root         the checkout whose contracts/schedule.json is read (default: this script's)
//   --folder       the Hatsu checkout the drift pass and the morning desk run in (default: --root)
//   --spec-folder  the family's private spec-repository checkout the recapture runs in
//   --family       the family slug the recapture names; printed to stdout only, never written
//   --repo         the owner/name the morning desk renders (default zheref/hatsu)
//   --json         one document: {contract, ruling, scheduler, registered, unfilled[], rows[]}
//   --table        the page's row table only, rendered from the contract (docs/config/schedule.md
//                  holds the same bytes between its schedule-table markers; the fixture compares)
//   The placeholders and their flags are the contract's `placeholders`; any other <token> in a
//   folder or prompt must be one of its `literalTokens`, or the contract is refused.
//
// EXITS  0 every row printed with every placeholder filled;
//        1 every row printed, at least one placeholder unfilled, each named on stderr as
//          `unfilled: <placeholder> (<row>) -- pass <flag>`; the printed text keeps the placeholder,
//          so a task registered from it is visibly incomplete, never silently wrong;
//        2 wiring: an unknown or valueless flag, a relative or missing folder, a family that is not
//          a slug, a repo that is not owner/name, an unreadable, non-JSON or malformed contract (an
//          unknown contract id, a row missing a field its kind needs, a repeated id or name, a cron
//          that is not five fields, a ruling pick that is none of its options, an undeclared <token>,
//          an always-allow entry the never list refuses). Never a printout over a contract it could
//          not read.
import { existsSync, readFileSync, realpathSync, statSync } from 'node:fs';
import { dirname, isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

type Trigger = { form: string; cron: string; reads: string };
type Task = { id: string; kind: 'desktop-task'; name: string; description: string; trigger: Trigger; folder: string; worktree: boolean; permissionMode: string; model: string; alwaysAllow: string[]; prompt: string[] };
type Ci = { id: string; kind: 'ci'; description: string; cadence: string; workflow: string; job: string; reads: string };
type Placeholder = { flag: string; default?: string; means: string };
type Ruling = { id: string; effort: string; question: string; options: Array<{ key: string; label: string; consequence: string }>; pick: string; reading: string };
type Contract = { contract: string; ruling: Ruling; scheduler: string; placeholders: Record<string, Placeholder>; literalTokens: Record<string, string>; permissions: { neverAlwaysAllow: string[] }; rows: Array<Task | Ci> };
class Wiring extends Error {}
const wiring = (m: string): never => { throw new Wiring(m); };

const FLAGS = new Set(['--root', '--folder', '--spec-folder', '--family', '--repo']);
const FOLDER_FLAGS = new Set(['--folder', '--spec-folder']);
const FORMS = new Set(['Hourly', 'Daily', 'Weekdays', 'Weekly', 'Manual', 'Custom']);
const TOKEN = /<[a-z][a-z0-9-]*>/g;
const C = 'contracts/schedule.json';

function parseArgs(argv: string[]): Map<string, string> {
  const out = new Map<string, string>();
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--json' || a === '--table') { out.set(a, 'true'); continue; }
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

const strList = (v: unknown): boolean => Array.isArray(v) && v.length > 0 && v.every((x) => typeof x === 'string' && x);

export function load(root: string): Contract {
  const path = join(root, C);
  if (!existsSync(path)) wiring(`${path} is missing`);
  let c: Contract;
  try { c = JSON.parse(readFileSync(path, 'utf8')) as Contract; } catch (e) { return wiring(`${C} is not JSON: ${(e as Error).message}`); }
  if (c?.contract !== 'hatsu.schedule/v0.1') wiring(`${C}: contract ${JSON.stringify(c?.contract)} is not hatsu.schedule/v0.1`);
  if (typeof c.scheduler !== 'string' || !c.scheduler) wiring(`${C}: scheduler is missing`);
  const r0 = c.ruling;
  if (!r0 || ['id', 'effort', 'question', 'pick', 'reading'].some((k) => typeof (r0 as Record<string, unknown>)[k] !== 'string' || !(r0 as Record<string, unknown>)[k])) wiring(`${C}: ruling needs id, effort, question, pick and reading`);
  if (!Array.isArray(r0.options) || !r0.options.some((o) => o?.key === r0.pick)) wiring(`${C}: ruling.pick ${r0.pick} is none of its options`);
  if (!c.placeholders || typeof c.placeholders !== 'object') wiring(`${C}: placeholders is missing`);
  for (const [tok, p] of Object.entries(c.placeholders)) {
    if (!/^<[a-z][a-z0-9-]*>$/.test(tok)) wiring(`${C}: placeholder ${tok} is not <name>`);
    if (!p || !FLAGS.has(p.flag) || p.flag === '--root' || typeof p.means !== 'string') wiring(`${C}: placeholder ${tok} needs a flag (one of --folder, --spec-folder, --family, --repo) and means`);
  }
  const literals = c.literalTokens ?? {};
  if (typeof literals !== 'object') wiring(`${C}: literalTokens is not an object`);
  if (!strList(c.permissions?.neverAlwaysAllow)) wiring(`${C}: permissions.neverAlwaysAllow is missing or empty`);
  if (!Array.isArray(c.rows) || c.rows.length === 0) wiring(`${C}: rows is missing or empty`);
  const seen = new Set<string>();
  for (const r of c.rows) {
    const str = (k: string): void => { if (typeof (r as Record<string, unknown>)[k] !== 'string' || !(r as Record<string, unknown>)[k]) wiring(`${C}: row ${r?.id ?? '?'} has no ${k}`); };
    str('id');
    if (seen.has(r.id)) wiring(`${C}: row id ${r.id} repeats`);
    seen.add(r.id);
    str('description');
    if (r.kind === 'ci') { for (const k of ['workflow', 'job', 'reads', 'cadence']) str(k); continue; }
    if (r.kind !== 'desktop-task') wiring(`${C}: row ${r.id} has kind ${JSON.stringify((r as { kind: unknown }).kind)}, not desktop-task or ci`);
    for (const k of ['name', 'folder', 'permissionMode', 'model']) str(k);
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(r.name)) wiring(`${C}: row ${r.id} name ${r.name} is not lowercase kebab-case (Desktop's folder name)`);
    if (seen.has(`name:${r.name}`)) wiring(`${C}: task name ${r.name} repeats`);
    seen.add(`name:${r.name}`);
    if (typeof r.worktree !== 'boolean') wiring(`${C}: row ${r.id} worktree is not a boolean`);
    const t = r.trigger;
    if (!t || !FORMS.has(t.form)) wiring(`${C}: row ${r.id} trigger.form is not one of ${[...FORMS].join(', ')}`);
    if (typeof t.cron !== 'string' || t.cron.trim().split(/\s+/).length !== 5) wiring(`${C}: row ${r.id} trigger.cron is not five fields`);
    if (typeof t.reads !== 'string' || !t.reads) wiring(`${C}: row ${r.id} trigger.reads is missing`);
    if (!strList(r.prompt)) wiring(`${C}: row ${r.id} prompt is not a non-empty list of lines`);
    if (!strList(r.alwaysAllow)) wiring(`${C}: row ${r.id} alwaysAllow is missing or empty`);
    const clash = r.alwaysAllow.filter((x) => c.permissions.neverAlwaysAllow.includes(x));
    if (clash.length) wiring(`${C}: row ${r.id} alwaysAllow names ${clash.join(', ')}, which permissions.neverAlwaysAllow refuses`);
    // Every <token> must be a declared placeholder or a declared literal: an undeclared one would
    // print at exit 0, neither filled nor named -- silently wrong.
    for (const s of [r.folder, ...r.prompt]) for (const m of s.match(TOKEN) ?? []) {
      if (!(m in c.placeholders) && !(m in literals)) wiring(`${C}: row ${r.id} uses ${m}, declared in neither placeholders nor literalTokens`);
    }
  }
  return c;
}

// The page's table of rows, rendered from the contract; the fixture holds docs/config/schedule.md's
// copy (between its schedule-table markers) equal to this, so the page never drifts from the file.
export function pageTable(c: Contract): string {
  const rows = c.rows.map((r) => r.kind === 'ci'
    ? `| \`${r.id}\` | CI, job \`${r.job}\` | ${r.cadence} | ${r.description} |`
    : `| \`${r.id}\` | Desktop, \`${r.trigger.form}\` \`${r.trigger.cron}\` | ${r.trigger.reads} | ${r.description} |`);
  return ['| Row | Trigger | Cadence | What it does |', '|---|---|---|---|', ...rows].join('\n') + '\n';
}

export function run(argv: string[]): { code: number; out: string; err: string } {
  try {
    const a = parseArgs(argv);
    const root = resolve(a.get('--root') ?? join(dirname(fileURLToPath(import.meta.url)), '..'));
    const c = load(root);
    if (a.has('--table')) return { code: 0, out: pageTable(c), err: '' };
    const family = a.get('--family');
    if (family !== undefined && !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(family)) wiring(`--family ${family} is not a slug`);
    const repoFlag = a.get('--repo');
    if (repoFlag !== undefined && !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repoFlag)) wiring(`--repo ${repoFlag} is not owner/name`);
    const given = (flag: string): string | undefined => (FOLDER_FLAGS.has(flag) ? folderFlag(a, flag) : a.get(flag));
    const values: Record<string, string | undefined> = {};
    for (const [tok, p] of Object.entries(c.placeholders)) values[tok] = given(p.flag) ?? (p.default === '@root' ? root : p.default);
    const unfilled: Array<{ placeholder: string; row: string; flag: string }> = [];
    const fill = (row: string, s: string): string => s.replace(TOKEN, (p) => {
      if (!(p in c.placeholders)) return p;
      const v = values[p];
      if (v === undefined) { if (!unfilled.some((u) => u.placeholder === p && u.row === row)) unfilled.push({ placeholder: p, row, flag: c.placeholders[p].flag }); return p; }
      return v;
    });
    const never = c.permissions.neverAlwaysAllow;
    const rows = c.rows.map((r) => r.kind === 'ci' ? r : {
      ...r, folder: fill(r.id, r.folder), prompt: r.prompt.map((p) => fill(r.id, p)), neverAlwaysAllow: never,
      skillMd: `---\nname: ${r.name}\ndescription: ${JSON.stringify(r.description)}\n---\n\n${r.prompt.map((p) => fill(r.id, p)).join('\n\n')}\n`,
    });
    const code = unfilled.length ? 1 : 0;
    const err = unfilled.map((u) => `unfilled: ${u.placeholder} (${u.row}) -- pass ${u.flag}\n`).join('');
    if (a.has('--json')) {
      return { code, err, out: JSON.stringify({ contract: c.contract, ruling: c.ruling, scheduler: c.scheduler, registered: false, unfilled, rows }, null, 2) + '\n' };
    }
    const picked = c.ruling.options.find((o) => o.key === c.ruling.pick)!;
    let out = `schedule_install: ${rows.length} rows from ${C}; scheduler ${c.scheduler}.\n`;
    out += `ruling ${c.ruling.id} (effort ${c.ruling.effort}): picked ${picked.key} "${picked.label}" -- ${picked.consequence}.\n`;
    out += `reading (not part of the record): ${c.ruling.reading}\n`;
    out += 'NOTHING IS REGISTERED. Register each task yourself in Claude Desktop: Code tab -> Scheduled -> New task -> Set up manually;\n';
    out += 'under Advanced settings turn on "Only on this computer", then fill the fields below. A task fires only while Desktop is open\n';
    out += 'and the machine is awake; on wake Desktop starts ONE catch-up run for the latest time missed in the last 7 days and drops\n';
    out += 'anything older, so a machine off for more than 7 days around a run loses that run (the task\'s History shows it skipped).\n';
    out += 'PERMISSIONS. After Create, press Run now once and answer each prompt: "always allow" ONLY for a tool on the row\'s\n';
    out += 'always-allow list, "allow once" for anything on the never list, so every write asks on every run. Desktop saves each\n';
    out += '"always allow" for all later runs, and the allow rules in ~/.claude/settings.json apply to these sessions too.\n';
    out += 'The first Run now of drift-pass is a LIVE run: it fetches every surface\'s pages and may file issues on confirmation.\n';
    for (const r of rows) {
      out += `\n=== ${r.id} ===\n`;
      if (r.kind === 'ci') { out += `not a task: runs in CI, ${r.workflow} job ${r.job}\nwhen: ${r.reads}\n`; continue; }
      const t = r as Task & { skillMd: string };
      out += `Name:            ${t.name}\nDescription:     ${t.description}\n`;
      out += `Trigger:         ${t.trigger.form} -- ${t.trigger.reads}; as Custom (Edit form): ${t.trigger.cron}\n`;
      out += `Local folder:    ${t.folder}\nWorktree:        ${t.worktree ? 'on (select Worktree in the Edit form after Create)' : 'off'}\n`;
      out += `Permission mode: ${t.permissionMode}\nModel:           ${t.model}\n`;
      out += `Always allow:    ${t.alwaysAllow.join(' · ')}\nNever always:    ${never.join(' · ')}\n`;
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
