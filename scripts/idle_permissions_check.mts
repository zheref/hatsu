#!/usr/bin/env node
// idle_permissions_check.mts — which commands an idle batch needs that this session does not pre-allow
// (zheref/hatsu#453 AC-3; WORKFLOW § Idle batches rule 0).
//
//   node scripts/idle_permissions_check.mts --repo <checkout> [--settings <file>]... [--needs <file>] [--json]
//
// Reads every exemplar in contracts/idle-permissions.json (or --needs) and the Claude Code settings the
// session loads — <checkout>/.claude/settings.local.json, <checkout>/.claude/settings.json and
// ~/.claude/settings.json, or exactly the --settings files named — and reports each exemplar that no
// `Bash(...)` allow rule matches, or that a `Bash(...)` deny rule matches. It READS and never writes:
// a permission setting is the maintainer's alone. A settings file that is absent is named and skipped;
// one that cannot be read or parsed is a wiring error, never "nothing allowed".
//
// Matching follows Claude Code's Bash rule form: `Bash` alone or `Bash(*)` matches every command;
// `Bash(<pattern>)` matches when the command equals the pattern with each `*` standing for any run of
// characters (the older `prefix:*` form is read as `prefix *` or the bare prefix). Placeholders
// (`<...>`) in an exemplar stand for one word.
//
// exit 0  every exemplar is pre-allowed · exit 1  at least one is not (listed) · exit 2  wiring
import { readFileSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
function wiring(message: string): never { console.error(`idle-permissions: ${message}`); process.exit(2); }

const args = process.argv.slice(2);
let repo: string | null = null;
let needsPath = join(ROOT, 'contracts/idle-permissions.json');
const settings: string[] = [];
let json = false;
for (let i = 0; i < args.length; i++) {
  const flag = args[i];
  const value = args[i + 1];
  if (flag === '--json') { json = true; continue; }
  if ((flag === '--repo' || flag === '--settings' || flag === '--needs') && value !== undefined && !value.startsWith('--')) {
    if (flag === '--repo') repo = resolve(value); else if (flag === '--needs') needsPath = resolve(value); else settings.push(resolve(value));
    i++; continue;
  }
  wiring(`unknown or incomplete argument '${flag}'`);
}
if (repo === null && settings.length === 0) wiring('--repo <checkout> or at least one --settings <file> is required');
const files = settings.length > 0 ? settings : [join(repo as string, '.claude/settings.local.json'), join(repo as string, '.claude/settings.json'), join(homedir(), '.claude/settings.json')];

type Need = { command: string; by: string };
let needs: Need[];
try {
  const document = JSON.parse(readFileSync(needsPath, 'utf8')) as { contract?: unknown; needs?: unknown };
  if (document.contract !== 'hatsu.idle-permissions/v0.1' || !Array.isArray(document.needs)) wiring(`${needsPath}: not a hatsu.idle-permissions/v0.1 document`);
  needs = (document.needs as unknown[]).map((need, index): Need => {
    const n = need as Need;
    if (typeof n?.command !== 'string' || n.command.trim() === '' || typeof n.by !== 'string') wiring(`${needsPath}: needs[${index}] must carry a command and a by`);
    return n;
  });
} catch (error) { wiring(`${needsPath}: could not read (${(error as Error).message})`); }

const allow: string[] = [];
const deny: string[] = [];
const read: Array<{ path: string; state: 'read' | 'absent' }> = [];
for (const file of files) {
  if (!existsSync(file)) { read.push({ path: file, state: 'absent' }); continue; }
  let document: { permissions?: { allow?: unknown; deny?: unknown } };
  try { document = JSON.parse(readFileSync(file, 'utf8')); } catch (error) { wiring(`${file}: could not read or parse (${(error as Error).message})`); }
  const take = (list: unknown, into: string[], key: string): void => {
    if (list === undefined) return;
    if (!Array.isArray(list) || list.some((rule) => typeof rule !== 'string')) wiring(`${file}: permissions.${key} must be an array of strings`);
    into.push(...(list as string[]));
  };
  take(document.permissions?.allow, allow, 'allow');
  take(document.permissions?.deny, deny, 'deny');
  read.push({ path: file, state: 'read' });
}

function bashPattern(rule: string): RegExp | null {
  if (rule === 'Bash') return /^.*$/s;
  const match = /^Bash\((.*)\)$/s.exec(rule);
  if (match === null) return null;
  let pattern = match[1] as string;
  if (pattern.endsWith(':*')) pattern = `${pattern.slice(0, -2)}*`;
  const escaped = pattern.split('*').map((part) => part.replace(/[.+?^${}()|[\]\\]/g, '\\$&')).join('.*');
  return new RegExp(`^${escaped}$`, 's');
}
const allowRx = allow.map((rule) => ({ rule, rx: bashPattern(rule) })).filter((r) => r.rx !== null);
const denyRx = deny.map((rule) => ({ rule, rx: bashPattern(rule) })).filter((r) => r.rx !== null);
const sample = (command: string): string => command.replace(/<[^>]+>/g, 'X');

const rows = needs.map((need) => {
  const command = sample(need.command);
  const denied = denyRx.find((r) => (r.rx as RegExp).test(command))?.rule ?? null;
  const allowed = allowRx.find((r) => (r.rx as RegExp).test(command))?.rule ?? null;
  const verdict = denied !== null ? 'denied' : allowed !== null ? 'allowed' : 'not-pre-allowed';
  return { command: need.command, by: need.by, verdict, rule: denied ?? allowed };
});
const missing = rows.filter((row) => row.verdict !== 'allowed');

if (json) console.log(JSON.stringify({ contract: 'hatsu.idle-permissions.check/v0.1', settings: read, rows, missing: missing.length }, null, 2));
else {
  for (const file of read) console.log(`settings ${file.state}: ${file.path}`);
  for (const row of missing) console.log(`${row.verdict}: ${row.command}  (${row.by})${row.rule ? `  [${row.rule}]` : ''}`);
  console.log(`idle-permissions: ${rows.length - missing.length}/${rows.length} pre-allowed${missing.length > 0 ? `; ${missing.length} would prompt — under --idle each is a harness refusal (row harness-denied)` : ''}`);
}
process.exit(missing.length === 0 ? 0 : 1);
