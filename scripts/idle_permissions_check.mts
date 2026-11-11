#!/usr/bin/env node
// idle_permissions_check.mts — which commands an idle batch needs that this session does not pre-allow
// (zheref/hatsu#453 AC-3; WORKFLOW § Idle batches rule 0).
//
//   node scripts/idle_permissions_check.mts --repo <checkout> [--settings <file>]... [--needs <file>] [--json]
//
// Reads every exemplar in contracts/idle-permissions.json (or --needs) and the Claude Code settings the
// session loads — <checkout>/.claude/settings.local.json, <checkout>/.claude/settings.json and
// the Claude user settings, or exactly the --settings files named — and reports each exemplar that no
// `Bash(...)` allow rule matches, or that a `Bash(...)` deny or ask rule matches (both prompt or refuse). It READS and never writes:
// a permission setting is the maintainer's alone. A settings file that is absent is named and skipped;
// one that cannot be read or parsed is a wiring error, never "nothing allowed".
//
// Matching follows Claude Code's Bash rule form: `Bash` alone or `Bash(*)` matches every command;
// `Bash(<pattern>)` matches when the command equals the pattern with each `*` standing for any run of
// characters (the older `prefix:*` form is read as `prefix *` or the bare prefix). Placeholders
// (`<...>`) in an exemplar stand for one word.
//
// exit 0  every exemplar is pre-allowed · exit 1  at least one is not (listed) · exit 2  wiring
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { type PermissionRules, matchPermissions, readSettings, sampleCommand } from './claude_permissions.mts';
import { permissionSource, userSettingsPath } from './claude_routine_permissions.mts';

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
const files = settings.length > 0 ? settings : [join(repo as string, '.claude/settings.local.json'), join(repo as string, '.claude/settings.json'), userSettingsPath()];

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
  if (needsPath === join(ROOT, 'contracts/idle-permissions.json')) {
    needs.push(...permissionSource(join(ROOT, 'contracts/permissions.json')).claude_routine_writes);
  }
} catch (error) { wiring(`${needsPath}: could not read (${(error as Error).message})`); }

const rules: PermissionRules = { allow: [], deny: [], ask: [] };
const read = files.map((path) => {
  const settings = readSettings(path);
  if (settings.state === 'unreadable') wiring(`${path}: could not read or parse settings`);
  if (settings.state === 'read') {
    for (const key of ['allow', 'deny', 'ask'] as const) rules[key].push(...settings.rules[key]);
  }
  return { path, state: settings.state };
});
const rows = needs.map((need) => ({
  command: need.command, by: need.by, ...matchPermissions(sampleCommand(need.command), rules),
}));
const missing = rows.filter((row) => row.verdict !== 'allowed');

if (json) console.log(JSON.stringify({ contract: 'hatsu.idle-permissions.check/v0.1', settings: read, rows, missing: missing.length }, null, 2));
else {
  for (const file of read) console.log(`settings ${file.state}: ${file.path}`);
  for (const row of missing) console.log(`${row.verdict}: ${row.command}  (${row.by})${row.rule ? `  [${row.rule}]` : ''}`);
  console.log(`idle-permissions: ${rows.length - missing.length}/${rows.length} pre-allowed${missing.length > 0 ? `; ${missing.length} would prompt — under --idle each is a harness refusal (row harness-denied)` : ''}`);
}
process.exit(missing.length === 0 ? 0 : 1);
