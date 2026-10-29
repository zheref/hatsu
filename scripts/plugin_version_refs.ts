#!/usr/bin/env node
// #158: inspect tracked references to a version and rewrite only exact,
// unambiguous forms. --body-file additionally rewrites an explicit local draft;
// generated mirrors and remote PR objects are never edited.
// --check-nen-pin: docs/NEN-CONTRACT.md's echoed pin line must name
// nen/contract.json's dependency.minimum and pinned_ref (0 agree, 1 drift,
// 2 a side missing, unparseable, duplicated or resolving outside the root).
import { lstatSync, readFileSync, readlinkSync, realpathSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
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
  let bodyArg: string | undefined;
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    if (flag === '--write') { write = true; continue; }
    if (!['--root', '--from', '--to', '--body-file'].includes(flag)) refuse(`unknown argument ${flag}`);
    const value = args[++i];
    if (!value) refuse(`${flag} needs a value`);
    if (flag === '--root') rootArg = value;
    else if (flag === '--from') from = value;
    else if (flag === '--body-file') bodyArg = value;
    else to = value;
  }
  if (!from || !to || !/^\d+\.\d+\.\d+$/.test(from) || !/^\d+\.\d+\.\d+$/.test(to)) {
    refuse('use --from X.Y.Z --to X.Y.Z [--body-file DRAFT] [--write], or --check-nen-pin');
  }
  if (from === to) refuse('old and new versions are the same');
  let root: string;
  try { root = realpathSync(rootArg); } catch { refuse('root is not a directory'); }
  const top = git(root, 'rev-parse', '--show-toplevel').toString('utf8').trim();
  if (top !== root) refuse('root is not a Git checkout');
  const paths = git(root, 'ls-files', '-z').toString('utf8').split('\0').filter(Boolean);
  const escaped = from.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  // Validate the entire explicitly named local draft before any tracked write.
  // A draft may live outside the checkout, but must be a regular UTF-8 file.
  let body: { path: string; content: string } | undefined;
  if (bodyArg !== undefined) {
    const path = resolve(root, bodyArg);
    let content: string;
    try {
      if (!lstatSync(path).isFile()) refuse('--body-file must name a regular file, not a symlink');
      const real = realpathSync(path);
      const draftPaths = [relative(root, path), relative(root, real)];
      // A checkout may be entered through a filesystem alias such as /var.
      // Preserve its lexical suffix even when a lower directory points outside.
      let ancestor = dirname(path);
      for (;;) {
        if (realpathSync(ancestor) === root) {
          draftPaths.push(relative(ancestor, path));
          break;
        }
        const parent = dirname(ancestor);
        if (parent === ancestor) break;
        ancestor = parent;
      }
      if (draftPaths.some((candidate) => candidate === 'surfaces' || candidate.startsWith(`surfaces${sep}`))) {
        refuse('--body-file cannot name a generated mirror');
      }
      content = new TextDecoder('utf-8', { fatal: true }).decode(readFileSync(path));
      if (content.includes('\0')) refuse('--body-file contains NUL bytes');
    } catch (error) { refuse(`--body-file: ${(error as Error).message}`); }
    body = { path, content };
  }
  // A suffix makes the reference a different version; even a trailing dot is
  // left for review, since it may be another numeric component.
  const newIn = new RegExp(`(new in v)${escaped}(?![A-Za-z0-9_.-])`, 'i');
  const heading = new RegExp(`^## v${escaped}(?=\\s|$)`);
  const manifestValue = new RegExp(`^\\s*"version"\\s*:\\s*"${escaped}"\\s*,?\\s*$`);
  let found = 0;
  let rewritten = 0;
  for (const path of paths) {
    const full = resolve(root, path);
    if (body?.path === full) continue; // Handle a tracked draft only as a draft below.
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
  if (body) {
    // All occurrences on a line must be exact version tokens. A prefix/suffix
    // such as 11.2.3 or 1.2.3-rc makes the whole line ambiguous, never half-edited.
    const exact = new RegExp(`(^|[^A-Za-z0-9_.-])(v?)${escaped}(?![A-Za-z0-9_.-])`, 'g');
    const lines = body.content.match(/[^\n]*\n|[^\n]+$/g) ?? [];
    let mentions = 0;
    let rewrites = 0;
    let changed = false;
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index];
      if (!line.includes(from)) continue;
      mentions++;
      const count = line.split(from).length - 1;
      const matches = [...line.matchAll(exact)];
      const safe = matches.length === count;
      console.log(`${body.path}:${index + 1}: ${safe ? 'rewrite' : 'review'}: ${line.trim()}`);
      if (write && safe) {
        lines[index] = line.replace(exact, (_match, prefix: string, v: string) => `${prefix}${v}${to}`);
        rewrites += count;
        changed = true;
      }
    }
    if (changed) writeFileSync(body.path, lines.join(''));
    console.log(`plugin-version-refs: ${mentions} draft line(s) mention ${from}; ${write ? `rewrote ${rewrites} occurrence(s)` : 'list only'}`);
  } else {
    console.log('plugin-version-refs: use --body-file <local-draft> to list draft references; add --write to rewrite exact versions.');
  }
  console.log('plugin-version-refs: this command does not edit a PR; publish the reviewed local draft through nen pr edit-body.');
}

try { main(process.argv.slice(2)); }
catch (error) {
  console.error(`plugin-version-refs: ${(error as Error).message}`);
  process.exitCode = 2;
}
