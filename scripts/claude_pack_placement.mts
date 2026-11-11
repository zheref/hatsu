import { lstatSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { object, permissionRules, readSettings, type JsonObject } from './claude_permissions.mts';
import { CLAUDE_LOCAL, checkoutPack, userSettingsPath, type PermissionSource } from './claude_routine_permissions.mts';

// Deletion only. These exact historical Hatsu grants are never added to either pack.
const RETIRED = new Set(['Bash(gh api *)', 'Bash(node */scripts/gh_api_read.mts *)']);
const HATSU_CACHE_READER = /^(?:v)?\d+\.\d+\.\d+(?:-[\w.-]+)?\/scripts\/gh_api_read\.mts$/;

function retiredAllow(row: string, incoming: Set<string>, cacheRoot: string): boolean {
  if (incoming.has(row)) return false;
  if (RETIRED.has(row)) return true;
  const prefix = `Bash(node '${cacheRoot.replaceAll("'", "'\\''")}/`;
  const suffix = "' *)";
  return row.startsWith(prefix) && row.endsWith(suffix) &&
    HATSU_CACHE_READER.test(row.slice(prefix.length, -suffix.length));
}

export function installedCacheRoot(): string {
  return join(userSettingsPath(), '..', 'plugins', 'cache', 'hatsu', 'hatsu');
}

// A row's location and executable identify it without logging private arguments.
function foreignName(kind: 'allow' | 'deny' | 'ask', row: string, index: number): string {
  const command = /^(Bash|PowerShell)\(([\w./-]+)(?:[ :)]|$)/.exec(row);
  const tool = /^[A-Za-z][\w.-]{0,32}(?=\(|$)/.exec(row)?.[0];
  const name = command ? `${command[1]} ${command[2].split('/').at(-1)}` : tool ?? 'unrecognized rule';
  return `permissions.${kind}[${index}] (${name})`;
}

export function mergePack(current: unknown, pack: unknown, marker: string, cacheRoot: string) {
  if (!object(current)) throw new Error('settings top level is not an object');
  const rules = permissionRules(current);
  const existing = object(current.permissions) ? current.permissions : {};
  if (!object(pack) || !object(pack.permissions)) throw new Error('rendered pack lacks permissions');
  const incoming = permissionRules(pack);
  const allow = new Set(incoming.allow);
  const deny = new Set(incoming.deny);
  const retired: string[] = [];
  const retained: string[] = [];
  const allowed = rules.allow.filter((row, index) => {
    if (retiredAllow(row, allow, cacheRoot)) {
      retired.push(row);
      return false;
    }
    if (!allow.has(row)) retained.push(foreignName('allow', row, index));
    return true;
  });
  rules.deny.forEach((row, index) => { if (!deny.has(row)) retained.push(foreignName('deny', row, index)); });
  rules.ask.forEach((row, index) => retained.push(foreignName('ask', row, index)));
  const result: JsonObject = {
    ...current,
    permissions: {
      ...existing,
      allow: [...allowed, ...incoming.allow.filter((row) => !allowed.includes(row))],
      deny: [...rules.deny, ...incoming.deny.filter((row) => !rules.deny.includes(row))],
    },
  };
  if (result.$comment === undefined) result.$comment = marker;
  return { document: result, retired: [...new Set(retired)], retained };
}

export function diagnoseCheckoutPack(source: PermissionSource, root: string, repo: string, cacheRoot = installedCacheRoot()) {
  const path = join(repo, CLAUDE_LOCAL);
  try {
    if (lstatSync(dirname(path), { throwIfNoEntry: false })?.isSymbolicLink()) {
      return { status: 'blocked', detail: `${CLAUDE_LOCAL} is under a symbolic link` };
    }
  } catch {
    return { status: 'blocked', detail: `${CLAUDE_LOCAL} directory could not be inspected` };
  }
  const settings = readSettings(path);
  if (settings.state === 'absent') return { status: 'missing', detail: `${CLAUDE_LOCAL} is absent` };
  if (settings.state === 'unreadable') return { status: 'blocked', detail: `${CLAUDE_LOCAL} is unreadable or is not a regular file` };
  const expected = checkoutPack(source, root, '');
  const allow = new Set(expected.permissions.allow);
  const retired = settings.rules.allow.filter((row) => retiredAllow(row, allow, cacheRoot));
  if (retired.length) return { status: 'retired', detail: `retired Claude allow rows: ${retired.join(', ')}` };
  const missing = expected.permissions.allow.filter((row) => !settings.rules.allow.includes(row)).length +
    expected.permissions.deny.filter((row) => !settings.rules.deny.includes(row)).length;
  if (missing) return { status: 'missing', detail: `${CLAUDE_LOCAL} lacks ${missing} checkout pack rows` };
  return { status: 'present', detail: `${CLAUDE_LOCAL} carries the current Claude pack` };
}
