#!/usr/bin/env node
// #156: permission membership and render/install equality belong to TypeScript (BC-11).
import { readFileSync } from 'node:fs';
import { isDeepStrictEqual } from 'node:util';

function permissionsAt(path: string): { allow: string[]; deny: string[]; [key: string]: unknown } {
  const value: unknown = JSON.parse(readFileSync(path, 'utf8'));
  if (typeof value !== 'object' || value === null || !('permissions' in value)) {
    throw new Error(`${path}: missing permissions`);
  }
  const permissions = value.permissions;
  if (typeof permissions !== 'object' || permissions === null || !('allow' in permissions) ||
      !Array.isArray(permissions.allow) || !permissions.allow.every((row) => typeof row === 'string') ||
      !('deny' in permissions) || !Array.isArray(permissions.deny) ||
      !permissions.deny.every((row) => typeof row === 'string')) {
    throw new Error(`${path}: malformed permissions`);
  }
  return permissions as { allow: string[]; deny: string[]; [key: string]: unknown };
}

function main(args: string[]): void {
  if (args.length !== 3) throw new Error('expected installed and rendered Claude Code settings paths, then Hatsu root');
  const [installed, rendered] = args.slice(0, 2).map(permissionsAt);
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
  const delivery = installed.allow.filter((row) => row.startsWith('Bash(nen pr merge '));
  const boundedDelivery = 'Bash(nen pr merge * --delivery --requirements-from * --repo * --require-head * --run)';
  if (delivery.length !== 1 || delivery[0] !== boundedDelivery ||
      installed.allow.some((row) => row.startsWith('Bash(gh pr merge ')) ||
      installed.allow.includes('Bash(gh api *)') ||
      !installed.deny.includes('Bash(gh pr merge *)')) {
    throw new Error('Claude Code pack grants an unbounded or direct delivery merge');
  }
  const script = `${args[2]}/scripts/gh_api_read.mts`;
  const shellLiteral = `'${script.replaceAll("'", "'\\''")}'`;
  const reader = `Bash(node ${shellLiteral} *)`;
  const matches = (rule: string, command: string): boolean => {
    const escaped = rule.slice(5, -1).replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replaceAll('\\*', '.*');
    return new RegExp(`^${escaped}$`).test(command);
  };
  if (!installed.allow.includes(reader) ||
      installed.allow.some((row) => row.startsWith('Bash(gh api ') ||
        row === 'Bash(node */scripts/gh_api_read.mts *)') ||
      !matches(reader, `node ${shellLiteral} branch-rules zheref/hatsu main`) ||
      matches(reader, `node --require /tmp/payload.cjs ${shellLiteral} branch-rules zheref/hatsu main`) ||
      matches(reader, `node --eval 'process.exit()' ${shellLiteral} branch-rules zheref/hatsu main`) ||
      matches(reader, `node '/tmp/scripts/gh_api_read.mts' branch-rules zheref/hatsu main`)) {
    throw new Error('Claude Code pack lacks the audited API reader or grants raw gh api');
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
