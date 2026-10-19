#!/usr/bin/env node
// #158: inspect tracked references to a version and rewrite only exact,
// unambiguous forms. Mirrors and PR bodies require separate human steps.
import { lstatSync, readFileSync, readlinkSync, realpathSync, writeFileSync } from 'node:fs';
import { isAbsolute, join, relative, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

function refuse(message: string): never {
  throw new Error(message);
}

function git(root: string, ...args: string[]): Buffer {
  const result = spawnSync('git', ['-C', root, ...args], { encoding: 'buffer', maxBuffer: 64 * 1024 * 1024 });
  if (result.error || result.status !== 0) {
    refuse(`git ${args[0]} failed: ${result.error?.message ?? result.stderr.toString('utf8').trim()}`);
  }
  return result.stdout;
}

function inside(root: string, candidate: string): boolean {
  const rel = relative(root, candidate);
  return !!rel && !rel.startsWith('..') && !isAbsolute(rel);
}

function main(args: string[]): void {
  let rootArg = process.cwd();
  let from: string | undefined;
  let to: string | undefined;
  let write = false;
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    if (flag === '--write') { write = true; continue; }
    if (!['--root', '--from', '--to'].includes(flag)) refuse(`unknown argument ${flag}`);
    const value = args[++i];
    if (!value) refuse(`${flag} needs a value`);
    if (flag === '--root') rootArg = value;
    else if (flag === '--from') from = value;
    else to = value;
  }
  if (!from || !to || !/^\d+\.\d+\.\d+$/.test(from) || !/^\d+\.\d+\.\d+$/.test(to)) {
    refuse('use --from X.Y.Z --to X.Y.Z');
  }
  if (from === to) refuse('old and new versions are the same');
  let root: string;
  try { root = realpathSync(rootArg); } catch { refuse('root is not a directory'); }
  const top = git(root, 'rev-parse', '--show-toplevel').toString('utf8').trim();
  if (top !== root) refuse('root is not a Git checkout');
  const paths = git(root, 'ls-files', '-z').toString('utf8').split('\0').filter(Boolean);
  const escaped = from.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  // A suffix makes the reference a different version; even a trailing dot is
  // left for review, since it may be another numeric component.
  const newIn = new RegExp(`(new in v)${escaped}(?![A-Za-z0-9_.-])`, 'i');
  const heading = new RegExp(`^## v${escaped}(?=\\s|$)`);
  const manifestValue = new RegExp(`^\\s*"version"\\s*:\\s*"${escaped}"\\s*,?\\s*$`);
  let found = 0;
  let rewritten = 0;
  for (const path of paths) {
    const full = resolve(root, path);
    if (!inside(root, full)) refuse(`tracked path escapes root: ${path}`);
    let stat;
    try { stat = lstatSync(full); } catch { continue; }
    if (!stat.isFile() && !stat.isSymbolicLink()) continue;
    if (!stat.isSymbolicLink() && !inside(root, realpathSync(full))) {
      refuse(`tracked path escapes root: ${path}`);
    }
    const bytes = stat.isSymbolicLink() ? Buffer.from(readlinkSync(full)) : readFileSync(full);
    if (!bytes.includes(Buffer.from(from))) continue;
    let content: string;
    try { content = new TextDecoder('utf-8', { fatal: true }).decode(bytes); }
    catch { console.log(`${path}: review: non-UTF-8 tracked file mentions ${from}`); continue; }
    const lines = content.match(/[^\n]*\n|[^\n]+$/g) ?? [];
    let changed = false;
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index];
      if (!line.includes(from)) continue;
      found++;
      const generated = path.startsWith('surfaces/');
      const single = line.split(from).length === 2;
      let replacement: string | undefined;
      if (!generated && !stat.isSymbolicLink() && !content.includes('\0') && single) {
        if (['.claude-plugin/plugin.json', '.codex-plugin/plugin.json'].includes(path) && manifestValue.test(line)) {
          replacement = line.replace(from, to);
        } else if (path === 'CHANGELOG.md' && heading.test(line)) {
          replacement = line.replace(`## v${from}`, `## v${to}`);
        } else if (newIn.test(line)) {
          replacement = line.replace(newIn, (_match, prefix: string) => `${prefix}${to}`);
        }
      }
      const kind = generated ? 'generated' : replacement ? 'rewrite' : 'review';
      console.log(`${path}:${index + 1}: ${kind}: ${line.trim().slice(0, 180)}`);
      if (write && replacement !== undefined) {
        lines[index] = replacement;
        changed = true;
        rewritten++;
      }
    }
    if (changed) writeFileSync(full, lines.join(''));
  }
  console.log(`plugin-version-refs: ${found} tracked line(s) mention ${from}; ${write ? `rewrote ${rewritten}` : 'list only'}`);
  console.log('plugin-version-refs: generated mirrors are never rewritten; run bash scripts/surface_mirror_regenerate.sh and its check.');
  console.log(`plugin-version-refs: update the PR body to ${to} by hand; this command does not edit a PR.`);
}

try { main(process.argv.slice(2)); }
catch (error) {
  console.error(`plugin-version-refs: ${(error as Error).message}`);
  process.exitCode = 2;
}
