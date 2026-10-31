/** HA#535: every outstanding Tenkai item names its fix, rendered from contracts/tenkai-fixes.json. */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

export type FixRow = { id: string; states?: string[]; detail?: string; action?: string; each?: string; run?: string[]; asks?: string[]; edit?: string; guide?: string; detect: string; fill: 'default' | 'owner' | 'edit' };
export type Fix = { run: string[]; asks: string[]; edit: string | null; guide: string | null; detect: string; fill: FixRow['fill']; rule: string };
export type Item = { id: string; state: string; detail?: string | null; action?: string | null };
export const OUTSTANDING = ['missing', 'drift', 'routed', 'staged', 'blocked'];

export function fixRows(root: string): FixRow[] {
  const document = JSON.parse(readFileSync(join(root, 'contracts', 'tenkai-fixes.json'), 'utf8'));
  if (!Array.isArray(document.fixes) || !document.fixes.length) throw new Error('contracts/tenkai-fixes.json declares no fixes');
  return document.fixes;
}

// A path or value spliced into a command is quoted once, so a checkout with a space still runs as printed.
const quote = (value: string) => /^[\w@%+=:,./-]+$/.test(value) ? value : `'${value.replace(/'/g, `'\\''`)}'`;

function fill(template: string, vars: Record<string, string>, shell: boolean): string {
  return template.replace(/\{(\w+)\}/g, (whole, name) => {
    if (!(name in vars)) throw new Error(`tenkai-fixes: {${name}} is not filled in ${JSON.stringify(template)}`);
    return shell ? quote(vars[name]) : vars[name];
  });
}

export function fixFor(item: Item, rows: FixRow[], context: { repo: string; root: string; slug?: string | null }): Fix {
  for (const row of rows) {
    const id = new RegExp(row.id).exec(item.id);
    if (!id || (row.states && !row.states.includes(item.state))) continue;
    const detail = row.detail ? new RegExp(row.detail).exec(item.detail ?? '') : null;
    const action = row.action ? new RegExp(row.action).exec(item.action ?? '') : null;
    if ((row.detail && !detail) || (row.action && !action)) continue;
    const vars: Record<string, string> = { repo: context.repo, root: context.root, slug: context.slug || '<owner/name>', id: item.id,
      ...id.groups, ...detail?.groups, ...action?.groups };
    const values = row.each ? vars[row.each].split(',').map((value) => value.trim()).filter(Boolean) : [undefined];
    const run = (row.run ?? []).flatMap((template) => values.map((value) => fill(template, value === undefined ? vars : { ...vars, [row.each!]: value }, true)));
    return { run, asks: row.asks ?? [], edit: row.edit ? fill(row.edit, vars, false) : null, guide: row.guide ? fill(row.guide, vars, false) : null,
      detect: fill(row.detect, vars, true), fill: row.fill, rule: row.id };
  }
  throw new Error(`tenkai-fixes: no row matches ${item.id}`);
}

// The engine's frozen actions spell the target as `--repo <path>`; the report prints the real one.
export const resolveAction = (action: string | null | undefined, repo: string) => action?.replaceAll('--repo <path>', `--repo ${quote(repo)}`) ?? action ?? null;

/** The guided fill: what apply settles at defaults, what the owner answers, what only the owner edits. */
export function guide(items: (Item & { fix?: Fix })[]) {
  const open = items.filter((row) => OUTSTANDING.includes(row.state) && row.fix);
  return {
    defaults: open.filter((row) => row.fix!.fill === 'default').map((row) => row.id),
    owner: open.filter((row) => row.fix!.fill === 'owner').map((row) => ({ id: row.id, asks: row.fix!.asks })),
    manual: open.filter((row) => row.fix!.fill === 'edit').map((row) => row.id),
  };
}
