#!/usr/bin/env node
// #158: inspect tracked references to a version and rewrite only exact,
// unambiguous forms. Mirrors and PR bodies require separate human steps.
// --check-nen-pin: docs/NEN-CONTRACT.md's echoed pin line must name
// nen/contract.json's dependency.minimum and pinned_ref (0 agree, 1 drift,
// 2 a side missing, unparseable, duplicated or resolving outside the root).
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

const PIN_LINE = '*Current pin, echoed for convenience:*';

function readInside(root: string, path: string): string {
  let real: string;
  try { real = realpathSync(join(root, path)); } catch { refuse(`${path} is missing`); }
  if (!inside(root, real)) refuse(`${path} resolves outside the root; refused`);
  return readFileSync(real, 'utf8');
}

function checkNenPin(root: string): void {
  let contract: { dependency?: Record<string, unknown> };
  try { contract = JSON.parse(readInside(root, 'nen/contract.json')); }
  catch (error) { refuse(`nen/contract.json is unreadable: ${(error as Error).message}`); }
  const dep = contract.dependency ?? {};
  const { minimum, pinned_ref: pinned } = dep;
  if (typeof minimum !== 'string' || typeof pinned !== 'string') {
    refuse('nen/contract.json has no dependency.minimum or dependency.pinned_ref string');
  }
  const page = readInside(root, 'docs/NEN-CONTRACT.md').split('\n');
  const hits = page.filter((line) => line.startsWith(PIN_LINE));
  if (hits.length !== 1) refuse(`docs/NEN-CONTRACT.md carries ${hits.length} pin line(s), expected 1`);
  const echoedMin = /`nen >= ([0-9.]+)`/.exec(hits[0])?.[1];
  const echoedRef = /installing \*\*`(v[0-9.]+)`\*\*/.exec(hits[0])?.[1];
  if (echoedMin === undefined || echoedRef === undefined) {
    refuse('docs/NEN-CONTRACT.md pin line does not parse (expected `nen >= X.Y` and installing **`vX.Y.Z`**)');
  }
  if (echoedMin === minimum && echoedRef === pinned) {
    console.log(`plugin-version-refs: nen pin echo agrees (nen >= ${minimum}, ${pinned})`);
    return;
  }
  console.log(`plugin-version-refs: drift: docs/NEN-CONTRACT.md echoes nen >= ${echoedMin} installing ${echoedRef}; nen/contract.json says minimum ${minimum}, pinned_ref ${pinned}`);
  process.exitCode = 1;
}

function main(args: string[]): void {
  let rootArg = process.cwd();
  if (args.includes('--check-nen-pin')) {
    const rest = args.filter((arg) => arg !== '--check-nen-pin');
    if (rest.length && !(rest.length === 2 && rest[0] === '--root')) refuse('use --check-nen-pin [--root DIR]');
    if (rest.length) rootArg = rest[1];
    try { checkNenPin(realpathSync(rootArg)); }
    catch (error) { refuse((error as Error).message); }
    return;
  }
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
    refuse('use --from X.Y.Z --to X.Y.Z [--write], or --check-nen-pin');
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
