#!/usr/bin/env node
import { existsSync, lstatSync, readFileSync, renameSync, writeFileSync, chmodSync, unlinkSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { randomBytes } from 'node:crypto';
import { mergePack } from './claude_pack_placement.mts';

function main(args: string[]): void {
  if (args.length !== 3) throw new Error('expected checkout settings path, rendered pack JSON, marker');
  const [path, packText, marker] = args;
  const dir = dirname(path);
  if (basename(path) !== 'settings.local.json' || basename(dir) !== '.claude') {
    throw new Error('only checkout .claude/settings.local.json can be merged');
  }
  if (lstatSync(dir).isSymbolicLink()) throw new Error('settings directory is a symlink');
  const destination = lstatSync(path, { throwIfNoEntry: false });
  if (destination?.isSymbolicLink()) throw new Error('settings is a symlink');
  if (destination && !destination.isFile()) throw new Error('settings is not a regular file');
  let current: unknown = {};
  if (destination) {
    try { current = JSON.parse(readFileSync(path, 'utf8')); }
    catch { throw new Error('settings could not be read or parsed'); }
  }
  const pack = JSON.parse(packText) as unknown;
  const merged = mergePack(current, pack, marker);
  const temp = join(dir, `.settings.local.json.${randomBytes(8).toString('hex')}.tmp`);
  try {
    writeFileSync(temp, `${JSON.stringify(merged.document, null, 2)}\n`, { flag: 'wx', mode: 0o600 });
    if (destination) chmodSync(temp, destination.mode & 0o777);
    const latest = lstatSync(path, { throwIfNoEntry: false });
    if (latest?.ino !== destination?.ino || latest?.dev !== destination?.dev ||
        latest?.mtimeMs !== destination?.mtimeMs || latest?.ctimeMs !== destination?.ctimeMs) {
      throw new Error('settings changed during merge');
    }
    renameSync(temp, path);
  } finally {
    if (existsSync(temp)) unlinkSync(temp);
  }
  for (const row of merged.retired) console.log(`permissions pack (claude-code): removed retired pack row ${row}`);
  for (const row of merged.unknown) console.log(`permissions pack (claude-code): kept row with unknown ownership ${row}; review it manually`);
  for (const row of merged.retained.filter((row) => !merged.unknown.includes(row))) console.log(`permissions pack (claude-code): kept foreign ${row}`);
}

try {
  main(process.argv.slice(2));
} catch (error) {
  console.error(`permissions-pack-claude-merge: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 3;
}
