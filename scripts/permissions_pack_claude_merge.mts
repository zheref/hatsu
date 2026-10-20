#!/usr/bin/env node
// #326: merge the Claude pack while retiring the one unsafe legacy grant.
import { existsSync, lstatSync, readFileSync, renameSync, writeFileSync, chmodSync, unlinkSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { randomBytes } from 'node:crypto';

type Permissions = { allow: string[]; deny: string[] };

function object(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function rows(value: unknown, name: string): string[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || !value.every((row) => typeof row === 'string')) {
    throw new Error(`${name} is not an array of strings`);
  }
  return value;
}

function packPermissions(value: unknown): Permissions {
  if (!object(value) || !object(value.permissions)) throw new Error('rendered pack lacks permissions');
  return {
    allow: rows(value.permissions.allow, 'pack permissions.allow'),
    deny: rows(value.permissions.deny, 'pack permissions.deny'),
  };
}

export function merge(current: unknown, pack: unknown, marker: string): Record<string, unknown> {
  if (!object(current)) throw new Error('settings top level is not an object');
  const result = { ...current };
  const existing = result.permissions === undefined ? {} : result.permissions;
  if (!object(existing)) throw new Error('settings permissions is not an object');
  const incoming = packPermissions(pack);
  const allowed = rows(existing.allow, 'settings permissions.allow').filter((row) =>
    row !== 'Bash(gh api *)' && row !== 'Bash(node */scripts/gh_api_read.mts *)' &&
    !/^Bash\(node '\/[^*()\n]+\/scripts\/gh_api_read\.mts' \*\)$/.test(row));
  const denied = rows(existing.deny, 'settings permissions.deny');
  result.permissions = {
    ...existing,
    allow: [...new Set([...allowed, ...incoming.allow])],
    deny: [...new Set([...denied, ...incoming.deny])],
  };
  if (result.$comment === undefined) result.$comment = marker;
  return result;
}

function main(args: string[]): void {
  if (args.length !== 3) throw new Error('expected settings path, rendered pack JSON, marker');
  const [path, packText, marker] = args;
  const destination = lstatSync(path, { throwIfNoEntry: false });
  if (destination?.isSymbolicLink()) throw new Error('settings is a symlink');
  if (destination && !destination.isFile()) throw new Error('settings is not a regular file');
  const dir = dirname(path);
  if (lstatSync(dir).isSymbolicLink()) throw new Error('settings directory is a symlink');
  const current = destination ? JSON.parse(readFileSync(path, 'utf8')) as unknown : {};
  const pack = JSON.parse(packText) as unknown;
  const merged = merge(current, pack, marker);
  const temp = join(dir, `.settings.local.json.${randomBytes(8).toString('hex')}.tmp`);
  try {
    writeFileSync(temp, `${JSON.stringify(merged, null, 2)}\n`, { flag: 'wx', mode: 0o600 });
    if (destination) chmodSync(temp, destination.mode & 0o777);
    renameSync(temp, path);
  } finally {
    if (existsSync(temp)) unlinkSync(temp);
  }
}

try {
  main(process.argv.slice(2));
} catch (error) {
  console.error(`permissions-pack-claude-merge: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 3;
}
