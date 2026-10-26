#!/usr/bin/env node
// Consumer trailer workflow adoption decisions live in TypeScript (BC-11).
import { closeSync, copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, openSync, readFileSync, readdirSync, renameSync, rmSync, unlinkSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

type Row = { state: string; detail: string; action: string | null };
const READER = 'scripts/consumer_trailer_ci.mts';
const READER_MARKER = '// RENDERED BY hatsu:tenkai from scripts/consumer_trailer_ci.mts';
const REL = '.github/workflows/forbidden-commit-trailers.yml';
const MARKER = '# RENDERED BY hatsu:tenkai from templates/forbidden-commit-trailers.yml';
function row(state: string, detail: string, action: string | null = null): Row { return { state, detail, action }; }
function stat(path: string): ReturnType<typeof lstatSync> | null {
  try { return lstatSync(path); }
  catch (error) { if ((error as NodeJS.ErrnoException).code === 'ENOENT') return null; throw error; }
}
function safeParents(repo: string): boolean {
  return ['.github', '.github/workflows', 'scripts'].every(rel => {
    const info = stat(join(repo, rel));
    return !info || (info.isDirectory() && !info.isSymbolicLink());
  });
}
function source(root: string): string | null {
  const path = join(root, 'templates/forbidden-commit-trailers.yml');
  if (!stat(path)?.isFile() || stat(path)?.isSymbolicLink()) return null;
  const value = readFileSync(path, 'utf8');
  return value.startsWith(MARKER + '\n') ? value : null;
}
function readerSource(root: string): string | null {
  const path = join(root, READER);
  if (!stat(path)?.isFile() || stat(path)?.isSymbolicLink()) return null;
  const text = readFileSync(path, 'utf8');
  return text.startsWith('#!/usr/bin/env node\n') ? text.replace('#!/usr/bin/env node\n', `#!/usr/bin/env node\n${READER_MARKER}\n`) : null;
}
function atomicWrite(path: string, text: string): void {
  const temporary = join(path, '..', `.trailer-${randomBytes(16).toString('hex')}.tmp`);
  const fd = openSync(temporary, 'wx', 0o644);
  try { writeFileSync(fd, text, 'utf8'); } finally { closeSync(fd); }
  try { renameSync(temporary, path); } finally { if (existsSync(temporary)) unlinkSync(temporary); }
}
function policy(repo: string): boolean {
  const path = join(repo, 'nen/workflow.json');
  if (stat(join(repo, 'nen'))?.isSymbolicLink() || !stat(path)?.isFile() || stat(path)?.isSymbolicLink()) return false;
  try {
    const keys: unknown = JSON.parse(readFileSync(path, 'utf8')).commits?.forbiddenTrailers;
    return Array.isArray(keys) && keys.length > 0 && keys.every(key => typeof key === 'string' && /^[A-Za-z0-9][A-Za-z0-9-]*$/.test(key));
  } catch { return false; }
}
function admission(repo: string, expected: string): Row | null {
  const guard = join(repo, 'scripts/workflow_runner_policy_check.rb');
  if (stat(join(repo, 'scripts'))?.isSymbolicLink() || stat(guard)?.isSymbolicLink()) return row('blocked', 'workflow guard is linked; its admission cannot be trusted');
  if (!existsSync(guard)) return null;
  if (!stat(guard)?.isFile()) return row('blocked', 'workflow guard is not a regular file');
  // Ask the consumer's actual validator about the proposed workflows; naming the
  // new file in a comment is not registration. Do not mutate its checkout to probe.
  const temporary = mkdtempSync(join(tmpdir(), 'hatsu-trailer-admission-'));
  try {
    const workflows = join(temporary, '.github/workflows');
    mkdirSync(workflows, { recursive: true });
    if (existsSync(join(repo, '.github/workflows'))) {
      for (const name of readdirSync(join(repo, '.github/workflows'))) {
        if (!/\.ya?ml$/.test(name)) continue;
        const path = join(repo, '.github/workflows', name);
        if (!stat(path)?.isFile() || stat(path)?.isSymbolicLink()) return row('blocked', 'workflow inventory contains a non-regular file');
        copyFileSync(path, join(workflows, name));
      }
    }
    writeFileSync(join(temporary, REL), expected);
    const result = spawnSync('ruby', [guard, temporary], { encoding: 'utf8', timeout: 30_000, maxBuffer: 1024 * 1024 });
    if (result.status !== 0 || result.error) return row('staged', 'the consumer workflow guard does not admit the proposed trailer workflow', 'land that consumer guard registration first, then re-run Tenkai');
    return null;
  } finally { rmSync(temporary, { recursive: true, force: true }); }
}
function inspect(repo: string, root: string): Row {
  const expected = source(root);
  if (!expected || !readerSource(root)) return row('blocked', 'Hatsu trailer workflow or trusted publisher source is missing, linked or malformed');
  if (!safeParents(repo)) return row('blocked', 'workflow parent is not a regular directory');
  const target = join(repo, REL);
  const info = stat(target);
  if (info && (!info.isFile() || info.isSymbolicLink())) return row('blocked', 'workflow path is not a regular file');
  const actual = info ? readFileSync(target, 'utf8') : null;
  if (actual !== null && !actual.startsWith(MARKER + '\n')) return row('blocked', 'workflow was not rendered by Tenkai; review it before replacement');
  const reader = stat(join(repo, READER));
  if (reader && (!reader.isFile() || reader.isSymbolicLink())) return row('blocked', 'trusted publisher path is not a regular file');
  const readerText = reader ? readFileSync(join(repo, READER), 'utf8') : null;
  if (readerText !== null && !readerText.includes(READER_MARKER)) return row('blocked', 'trusted publisher was not rendered by Tenkai; review it before replacement');
  if (!policy(repo)) return row('blocked', 'commits.forbiddenTrailers must be a non-empty array of plain keys', 'configure the consumer policy before adopting this workflow');
  const gate = admission(repo, expected);
  if (gate) return gate;
  if (actual === expected && readerText === readerSource(root)) return row('satisfied', 'trailer workflow matches the pinned reader template');
  return actual === null ? row('missing', 'consumer has no forbidden trailer job', 'render the trailer workflow')
    : row('drift', 'rendered trailer workflow differs from the current template', 're-render the trailer workflow');
}
function apply(repo: string, root: string): Row {
  const before = inspect(repo, root);
  if (!['missing', 'drift'].includes(before.state)) return before;
  const expected = source(root)!;
  const target = join(repo, REL);
  const snapshot = existsSync(target) ? readFileSync(target, 'utf8') : null;
  const reader = readerSource(root)!;
  const readerPath = join(repo, READER);
  const readerSnapshot = existsSync(readerPath) ? readFileSync(readerPath, 'utf8') : null;
  mkdirSync(join(repo, '.github/workflows'), { recursive: true });
  mkdirSync(join(repo, 'scripts'), { recursive: true });
  if (!safeParents(repo)) return row('blocked', 'workflow parent became unsafe before the write');
  const current = inspect(repo, root);
  if (current.state !== before.state || source(root) !== expected || readerSource(root) !== reader ||
      (existsSync(readerPath) ? readFileSync(readerPath, 'utf8') : null) !== readerSnapshot ||
      (existsSync(target) ? readFileSync(target, 'utf8') : null) !== snapshot) return row('blocked', 'workflow changed during inspection; re-run Tenkai');
  atomicWrite(readerPath, reader);
  if (!safeParents(repo) || (existsSync(target) ? readFileSync(target, 'utf8') : null) !== snapshot) return row('blocked', 'workflow changed before installation; re-run Tenkai');
  atomicWrite(target, expected);
  return row('repaired', 'rendered forbidden-commit-trailers; make its check required after the adoption PR');
}
const [mode, repo, root] = process.argv.slice(2);
if (!repo || !root || !['diagnose', 'apply'].includes(mode)) throw new Error('usage: tenkai_trailer_guard.mts <diagnose|apply> <repo> <hatsu-root>');
process.stdout.write(JSON.stringify(mode === 'apply' ? apply(repo, root) : inspect(repo, root)) + '\n');
