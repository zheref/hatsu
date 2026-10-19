#!/usr/bin/env node
// #156: permission membership and render/install equality belong to TypeScript (BC-11).
import { readFileSync } from 'node:fs';
import { isDeepStrictEqual } from 'node:util';

function permissionsAt(path: string): { allow: string[]; [key: string]: unknown } {
  const value: unknown = JSON.parse(readFileSync(path, 'utf8'));
  if (typeof value !== 'object' || value === null || !('permissions' in value)) {
    throw new Error(`${path}: missing permissions`);
  }
  const permissions = value.permissions;
  if (typeof permissions !== 'object' || permissions === null || !('allow' in permissions) ||
      !Array.isArray(permissions.allow) || !permissions.allow.every((row) => typeof row === 'string')) {
    throw new Error(`${path}: malformed permissions.allow`);
  }
  return permissions as { allow: string[]; [key: string]: unknown };
}

function main(args: string[]): void {
  if (args.length !== 2) throw new Error('expected installed and rendered Claude Code settings paths');
  const [installed, rendered] = args.map(permissionsAt);
  const release = installed.allow.filter((row) => row.startsWith('Bash(nen shu release '));
  const expected = [
    'Bash(nen shu release --repo * --lane plugin --dry-run)',
    'Bash(nen shu release --repo * --lane plugin)',
  ];
  if (release.length !== 2 || expected.some((row) => !release.includes(row))) {
    throw new Error('Claude Code pack lacks the two bounded plugin release forms');
  }
  if (installed.allow.some((row) => row.startsWith('Bash(nen shu deploy ') ||
      row.startsWith('Bash(gh release '))) {
    throw new Error('Claude Code pack grants a deploy or direct release form');
  }
  if (!isDeepStrictEqual(installed, rendered)) {
    throw new Error('Claude Code installed permissions differ from the rendered permission pack');
  }
}

try {
  main(process.argv.slice(2));
} catch (error) {
  console.error(`permissions-pack-release-fixture: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
}
