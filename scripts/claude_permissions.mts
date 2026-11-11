// Shared settings reader and Bash pattern check. This models visible text rules only.
import { lstatSync, readFileSync } from 'node:fs';

export type JsonObject = Record<string, unknown>;
export function object(value: unknown): value is JsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
export function strings(value: unknown, name: string): string[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || !value.every((entry) => typeof entry === 'string')) {
    throw new Error(`${name} is not an array of strings`);
  }
  return value;
}

export type PermissionRules = { allow: string[]; deny: string[]; ask: string[] };
export function permissionRules(document: unknown): PermissionRules {
  if (!object(document)) throw new Error('settings top level is not an object');
  const permissions = document.permissions === undefined ? {} : document.permissions;
  if (!object(permissions)) throw new Error('settings permissions is not an object');
  return {
    allow: strings(permissions.allow, 'permissions.allow'),
    deny: strings(permissions.deny, 'permissions.deny'),
    ask: strings(permissions.ask, 'permissions.ask'),
  };
}

export type Settings =
  | { state: 'absent' | 'unreadable'; path: string }
  | { state: 'read'; path: string; document: JsonObject; rules: PermissionRules };

export function readSettings(path: string): Settings {
  try {
    const stat = lstatSync(path, { throwIfNoEntry: false });
    if (!stat) return { state: 'absent', path };
    if (!stat.isFile()) return { state: 'unreadable', path };
    const document = JSON.parse(readFileSync(path, 'utf8')) as JsonObject;
    return { state: 'read', path, document, rules: permissionRules(document) };
  } catch {
    // JSON parser errors may quote the user's settings.
    return { state: 'unreadable', path };
  }
}

const escapeRegex = (text: string): string => text.replace(/[.+?^${}()|[\]\\]/g, '\\$&');

export function bashPattern(rule: string): RegExp | null {
  if (rule === 'Bash') return /^.*$/s;
  const match = /^Bash\((.*)\)$/s.exec(rule);
  if (!match) return null;
  const pattern = match[1].endsWith(':*') ? match[1].slice(0, -2) + ' *' : match[1];
  // A trailing space-star or the previously supported colon-star matches a whole prefix.
  if (pattern.endsWith(' *') && !pattern.slice(0, -2).includes('*')) {
    const prefix = pattern.slice(0, -2).split('*').map(escapeRegex).join('.*');
    return new RegExp(`^${prefix}(?: .*)?$`, 's');
  }
  return new RegExp(`^${pattern.split('*').map(escapeRegex).join('.*')}$`, 's');
}

export const sampleCommand = (command: string): string => command.replace(/<[^>]+>/g, 'X');

export function matchPermissions(command: string, rules: PermissionRules) {
  const find = (rows: string[]) => rows.find((rule) => bashPattern(rule)?.test(command)) ?? null;
  const denied = find(rules.deny);
  const asked = find(rules.ask);
  const allowed = find(rules.allow);
  const verdict = denied ? 'denied' : asked ? 'asks' : allowed ? 'allowed' : 'not-pre-allowed';
  return { verdict, rule: denied ?? asked ?? allowed };
}
