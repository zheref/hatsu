/** HA#535: every outstanding Tenkai item names its fix, rendered from contracts/tenkai-fixes.json. */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const FILLS = ['default', 'owner', 'edit', 'route', 'unmapped'] as const;
export type Fill = typeof FILLS[number];
export type FixRow = { id: string; states?: string[]; detail?: string; action?: string; each?: string; run?: string[]; asks?: string[]; edit?: string; guide?: string; detect: string; fill: Fill };
export type Fix = { run: string[]; asks: string[]; edit: string | null; guide: string | null; detect: string; fill: Fill; rule: string; defect?: string };
export type Item = { id: string; state: string; detail?: string | null; action?: string | null };
export const OUTSTANDING = ['missing', 'drift', 'routed', 'staged', 'blocked'];
const SLUG = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;

// The catalogue ships beside this script: read from the Hatsu tree that runs, never from --hatsu-root,
// which only names the templates a consumer is rendered from.
export function fixRows(root = join(dirname(fileURLToPath(import.meta.url)), '..')): FixRow[] {
  const document = JSON.parse(readFileSync(join(root, 'contracts', 'tenkai-fixes.json'), 'utf8'));
  const rows = document.fixes;
  if (!Array.isArray(rows) || !rows.length) throw new Error('contracts/tenkai-fixes.json declares no fixes');
  for (const row of rows) {
    if (typeof row.id !== 'string' || typeof row.detect !== 'string' || !FILLS.includes(row.fill)) throw new Error(`contracts/tenkai-fixes.json: malformed row ${JSON.stringify(row.id)}`);
    for (const pattern of [row.id, row.detail, row.action]) if (pattern !== undefined) new RegExp(pattern);
  }
  if (rows.at(-1).fill !== 'unmapped') throw new Error('contracts/tenkai-fixes.json: the last row must be the unmapped catch-all');
  return rows;
}

// A path or value spliced into a command is quoted once, so a checkout with a space still runs as printed.
export const quote = (value: string) => /^[\w@%+=:,./-]+$/.test(value) ? value : `'${value.replace(/'/g, `'\\''`)}'`;

function fill(template: string, vars: Record<string, string>, shell: boolean): string {
  return template.replace(/\{(\w+)\}/g, (_whole, name) => {
    if (!(name in vars)) throw new Error(`{${name}} is not filled in ${JSON.stringify(template)}`);
    return shell ? quote(vars[name]) : vars[name];
  });
}

export function fixFor(item: Item, rows: FixRow[], context: { repo: string; root: string; slug?: string | null }): Fix {
  const base = { repo: context.repo, root: context.root, slug: context.slug && SLUG.test(context.slug) ? context.slug : '<owner/name>', id: item.id };
  for (const row of rows) {
    const id = new RegExp(row.id).exec(item.id);
    if (!id || (row.states && !row.states.includes(item.state))) continue;
    const detail = row.detail ? new RegExp(row.detail).exec(item.detail ?? '') : null;
    const action = row.action ? new RegExp(row.action).exec(item.action ?? '') : null;
    if ((row.detail && !detail) || (row.action && !action)) continue;
    const vars: Record<string, string> = { ...base, ...id.groups, ...detail?.groups, ...action?.groups };
    try {
      const values = row.each ? vars[row.each].split(',').map((value) => value.trim()).filter(Boolean) : [undefined];
      const run = (row.run ?? []).flatMap((template) => values.map((value) => fill(template, value === undefined ? vars : { ...vars, [row.each!]: value }, true)));
      return { run, asks: row.asks ?? [], edit: row.edit ? fill(row.edit, vars, false) : null, guide: row.guide ? fill(row.guide, vars, false) : null,
        detect: fill(row.detect, vars, true), fill: row.fill, rule: row.id };
    } catch (error) {
      // A row that cannot render is a defect in the catalogue, reported as one rather than half-printed.
      return { run: [], asks: [], edit: null, guide: null, detect: fill(rows.at(-1)!.detect, base, true), fill: 'unmapped', rule: row.id, defect: error instanceof Error ? error.message : String(error) };
    }
  }
  return { run: [], asks: [], edit: null, guide: null, detect: fill(rows.at(-1)!.detect, base, true), fill: 'unmapped', rule: 'none', defect: 'no row matches' };
}

// The frozen engine prints `--repo <path>`, or the bare path; the report prints it once, quoted.
export function resolveAction(action: string | null | undefined, repo: string) {
  if (!action) return action ?? null;
  const shown = `--repo ${quote(repo)}`;
  return action.replaceAll('--repo <path>', shown).replaceAll(`--repo ${repo}`, shown);
}

/** The guided fill: what apply settles, what the owner answers, what Tenkai edits, what goes to its owner, and defects. */
export function guide(items: (Item & { fix?: Fix })[]) {
  const open = items.filter((row) => OUTSTANDING.includes(row.state) && row.fix);
  const ids = (kind: Fill) => open.filter((row) => row.fix!.fill === kind).map((row) => row.id);
  return {
    defaults: ids('default'),
    owner: open.filter((row) => row.fix!.fill === 'owner').map((row) => ({ id: row.id, asks: row.fix!.asks })),
    edits: ids('edit'),
    routed: ids('route'),
    unmapped: ids('unmapped'),
  };
}
