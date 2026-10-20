#!/usr/bin/env node
// #326: the Claude-only API grant is anchored to this installed reader path.
import { readFileSync, realpathSync, statSync } from 'node:fs';
import { join } from 'node:path';

type Row = { exe: string; args: string };

function rows(value: unknown, field: string): Row[] {
  if (!Array.isArray(value) || !value.every((row) =>
    typeof row === 'object' && row !== null &&
    typeof row.exe === 'string' && typeof row.args === 'string')) {
    throw new Error(`${field} is not an array of command rows`);
  }
  return value as Row[];
}

function main(args: string[]): void {
  if (args.length !== 3) throw new Error('expected permissions source, Hatsu root, marker');
  const [source, root, marker] = args;
  const doc: unknown = JSON.parse(readFileSync(source, 'utf8'));
  if (typeof doc !== 'object' || doc === null || !('claude_code_api_reader' in doc) ||
      doc.claude_code_api_reader !== 'scripts/gh_api_read.mts') {
    throw new Error('Claude API reader must name the audited entrypoint');
  }
  const installedRoot = realpathSync(root);
  const script = realpathSync(join(installedRoot, doc.claude_code_api_reader));
  if (script !== join(installedRoot, 'scripts/gh_api_read.mts') || !statSync(script).isFile() ||
      /[\x00-\x1f\x7f*()]/.test(script)) {
    throw new Error('Claude API reader path is not a safe installed file');
  }
  const shellLiteral = `'${script.replaceAll("'", "'\\''")}'`;
  const allow = rows('allow' in doc ? doc.allow : undefined, 'allow')
    .map((row) => `Bash(${row.exe} ${row.args})`);
  allow.push(`Bash(node ${shellLiteral} *)`);
  const deny = rows('deny' in doc ? doc.deny : undefined, 'deny')
    .map((row) => `Bash(${row.exe} ${row.args})`);
  const note = 'Patterns, not roots: this surface has no root-scoping syntax. Scope = this file lives in this checkout and applies to sessions opened here; an allowed command pointed at another checkout is not refused by it. Deny rows and hooks/guard-base-branch.sh are the second line.';
  process.stdout.write(`${JSON.stringify({
    $comment: `${marker}. ${note}`,
    permissions: { allow, deny },
  }, null, 2)}\n`);
}

try {
  main(process.argv.slice(2));
} catch (error) {
  console.error(`permissions-pack-claude-render: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 2;
}
