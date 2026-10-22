#!/usr/bin/env node
// Tenkai's process-publisher ownership and rendering decisions (BC-11).
// The Python Tenkai engine passes paths and relays this row without deciding it.
import { chmodSync, closeSync, lstatSync, mkdirSync, openSync, readFileSync, renameSync, unlinkSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { join } from 'node:path';

type State = 'satisfied' | 'missing' | 'drift' | 'blocked' | 'repaired';
type Row = { state: State; detail: string; action: string | null };
const FILES = [
  { rel: 'scripts/release-publish.sh', template: 'release-publish.sh', marker: 'RENDERED BY hatsu:tenkai from `templates/release-publish.sh`', mode: 0o755 },
  { rel: 'scripts/release_changelog.mts', template: 'release_changelog.mts', marker: 'RENDERED BY hatsu:tenkai from `templates/release_changelog.mts`', mode: 0o644 },
] as const;

function row(state: State, detail: string, action: string | null = null): Row {
  return { state, detail, action };
}
function stat(path: string): ReturnType<typeof lstatSync> | null {
  try { return lstatSync(path); }
  catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return null;
    throw error;
  }
}
function sources(hatsuRoot: string): string[] | null {
  const texts: string[] = [];
  for (const file of FILES) {
    const path = join(hatsuRoot, 'templates', file.template);
    const info = stat(path);
    if (!info?.isFile() || info.isSymbolicLink()) return null;
    const value = readFileSync(path, 'utf8');
    if (!value.includes(file.marker)) return null;
    texts.push(value);
  }
  return texts;
}
function inspect(repo: string, hatsuRoot: string, snapshot?: Array<string | null>): Row {
  const expected = sources(hatsuRoot);
  if (!expected) return row('blocked', 'Hatsu release publisher templates are missing, linked or malformed', 'repair the Hatsu installation');
  const parent = join(repo, 'scripts');
  const parentInfo = stat(parent);
  if (parentInfo?.isSymbolicLink() || (parentInfo && !parentInfo.isDirectory())) {
    return row('blocked', 'scripts/ is not a regular directory; Tenkai will not write through it');
  }
  const actual: Array<string | null> = [];
  for (const file of FILES) {
    const path = join(repo, file.rel);
    const info = stat(path);
    if (info?.isSymbolicLink()) return row('blocked', `${file.rel} is a symlink — Tenkai does not follow one out of the repository`);
    if (info && !info.isFile()) return row('blocked', `${file.rel} is not a regular file`);
    const value = info ? readFileSync(path, 'utf8') : null;
    if (value !== null && !value.includes(file.marker)) {
      return row('drift', `a ${file.rel} is present that Tenkai did not render — it will not be overwritten`, 'review by hand, then delete it and re-run apply');
    }
    actual.push(value);
  }
  snapshot?.push(...actual);
  if (actual[0] === null) return row('missing', 'absent — a process/system repository has no publisher for nen shu release', 'render both release publisher templates');
  if (actual.some((value, index) => value !== expected[index])) {
    return row('drift', 'the rendered publisher or its TypeScript helper differs from the shipped templates — it was rendered by an older Tenkai, or hand-edited since', 're-render both release publisher templates');
  }
  return row('satisfied', 'publisher and TypeScript helper present, both byte-identical to the shipped templates');
}
function atomicWrite(path: string, value: string, mode: number): void {
  const parent = join(path, '..');
  const temp = join(parent, `.release-publisher-${randomBytes(16).toString('hex')}.tmp`);
  const fd = openSync(temp, 'wx', mode);
  try { writeFileSync(fd, value, 'utf8'); }
  finally { closeSync(fd); }
  try { renameSync(temp, path); chmodSync(path, mode); }
  finally { if (stat(temp)) unlinkSync(temp); }
}
function apply(repo: string, hatsuRoot: string): Row {
  const baseline: Array<string | null> = [];
  const before = inspect(repo, hatsuRoot, baseline);
  if (before.state !== 'missing' && (before.state !== 'drift' || !before.action?.startsWith('re-render'))) return before;
  const parent = join(repo, 'scripts');
  mkdirSync(parent, { recursive: true });
  if (!stat(parent)?.isDirectory() || stat(parent)?.isSymbolicLink()) return row('blocked', 'scripts/ became unsafe before the write');
  const expected = sources(hatsuRoot);
  if (!expected) return row('blocked', 'Hatsu release publisher templates changed before the write');
  const checked: Array<string | null> = [];
  const current = inspect(repo, hatsuRoot, checked);
  if (current.state !== before.state || current.detail !== before.detail ||
      baseline.some((value, index) => value !== checked[index])) {
    return row('blocked', 'publisher changed during inspection; re-run Tenkai');
  }
  for (const [index, file] of FILES.entries()) {
    const path = join(repo, file.rel);
    const info = stat(path);
    if (info?.isSymbolicLink() || (info && !info.isFile())) return row('blocked', `${file.rel} became unsafe before the write`);
    const value = info ? readFileSync(path, 'utf8') : null;
    if (value !== baseline[index]) return row('blocked', `${file.rel} changed before the write; re-run Tenkai`);
    atomicWrite(path, expected[index], file.mode);
  }
  return row('repaired', 'rendered to scripts/release-publish.sh and scripts/release_changelog.mts — declare the publisher as the lane release row');
}

const [mode, repo, hatsuRoot] = process.argv.slice(2);
if (!repo || !hatsuRoot || !['diagnose', 'apply'].includes(mode)) {
  console.error('usage: tenkai_release_guard.mts <diagnose|apply> <repo> <hatsu-root>');
  process.exit(2);
}
process.stdout.write(JSON.stringify(mode === 'apply' ? apply(repo, hatsuRoot) : inspect(repo, hatsuRoot)) + '\n');
