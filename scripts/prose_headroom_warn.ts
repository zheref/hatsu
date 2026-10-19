#!/usr/bin/env node
// #166: advisory headroom threshold for the already-declared dieted skills.
// The shell guard keeps its established ceiling verdict and file diagnostics.
import { readFileSync, realpathSync } from 'node:fs';
import { isAbsolute, join, relative, resolve } from 'node:path';

const WARNING_HEADROOM = 512;

function main(args: string[]): number {
  if (args.length < 3) throw new Error('expected root, skill ceiling, and dieted skill names');
  const [rootArg, ceilingArg, ...skills] = args;
  const root = realpathSync(rootArg);
  const ceiling = Number(ceilingArg);
  if (!Number.isSafeInteger(ceiling) || ceiling < WARNING_HEADROOM) {
    throw new Error('skill ceiling is malformed');
  }
  for (const skill of skills) {
    if (!/^[a-z][a-z0-9-]*$/.test(skill)) throw new Error(`invalid dieted skill name: ${skill}`);
    const path = `claude/skills/${skill}/SKILL.md`;
    const candidate = resolve(root, path);
    let actual: string;
    try { actual = realpathSync(candidate); } catch { continue; }
    const rel = relative(root, actual);
    if (!rel || rel.startsWith('..') || isAbsolute(rel)) continue;
    let bytes: number;
    try { bytes = readFileSync(candidate).byteLength; } catch { continue; }
    const left = ceiling - bytes;
    if (left >= 0 && left < WARNING_HEADROOM) {
      console.log(`WARN  ${path} has ${left} bytes headroom (under ${WARNING_HEADROOM}); shorten or move owned prose before the next edit`);
    }
  }
  return 0;
}

try {
  process.exitCode = main(process.argv.slice(2));
} catch (error) {
  console.error(`prose_headroom_warn.ts: ${(error as Error).message}`);
  process.exitCode = 2;
}
