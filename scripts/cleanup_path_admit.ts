#!/usr/bin/env node
// cleanup_path_admit.ts — hatsu:cleanup § 4's admission of a worktree PATH (zheref/hatsu#333).
// Entry point: scripts/cleanup_path_admit.sh, a forwarding shim (`exec node` on this file).
// This header is the rule; cleanup § 4, Shizuku, docs/ab/cleanup.md and the lane cite it.
//
//   cleanup_path_admit.sh --core <abs> --base <branch.base> --path <abs>
//   cleanup_path_admit.sh --self-test
//
// A worktree path is a filesystem path, never a Git ref, and is never put through
// `git check-ref-format --branch`, which refuses every native absolute path. A branch or a remote head
// keeps § 4's ref rule. This file ADMITS a path and REPORTS FACTS; it never classes a row. The class
// is cleanup § 5's (its precedence, its ledger rule for reviewer checkouts, its table), read from these.
//
// Exit 2 (usage or host; nothing admitted): an unknown or repeated flag, a flag with no value,
// `--self-test` with another argument; --base not a legal branch name, starting `refs/`, containing
// `@{`, or not printed back exactly by `git for-each-ref --format=%(refname) refs/heads/<base>
// refs/remotes/origin/<base>` (every line one of those two names, at least one), so `refs/heads/main`,
// `heads/main`, `@{-1}` and, on a case-insensitive disk, `Main` never dodge the trunk check; --core not
// canonical (its on-disk realpath is itself), outside the charset below, not a git checkout, or not its
// repository's main worktree (the parent of `--git-common-dir`). The shim exits 2 when node is missing
// or below 22.18 (23.x: 23.6), the native type-stripping floor; an uncaught error exits 2. Any exit
// other than 0 admits nothing, and only exit 1 is a refusal.
//
// A path is ADMITTED only when every condition holds; the first that fails refuses it:
//   1. Absolute, in ^/[A-Za-z0-9_./-]+$ (no space, quote, glob, backslash, non-ASCII or control
//      byte), with no empty, `.` or `..` component and no trailing slash: traversal is refused as
//      spelled, never normalised.
//   2. Exactly <core>/.nen/worktrees/<surface>/<name> (§ 4's level). <home>/kagutsuchi is
//      kagutsuchi's fixed worktree, kept; any other single component is refused. The surface's own
//      worktrees are never handed here (§ 4); handed here they are refused `outside the cleanup home`.
//   3. No symlink: <core>/.nen, the home, <surface>, the path itself; the path a directory whose
//      on-disk realpath (`realpathSync.native`, the spelling the disk stores) is itself and its own
//      `rev-parse --show-toplevel`.
//   4. Listed exactly in `git -C <core> worktree list --porcelain -z`, the authoritative inventory, read
//      NUL-split so a newline in any other path never adds a line to this stanza. An unreadable
//      inventory refuses. A `prunable` entry is refused: `git worktree prune` takes no path and is
//      § 5's own row. An unlisted directory (a nested repository included) is somebody's.
//   5. Nothing nested: no other inventory entry whose on-disk realpath sits under the path's (so a
//      registration differing only in case is caught on APFS), and no `.git` file or directory anywhere
//      below the path but <path>/.git — a nested clone or submodule, under an ignored directory too.
//      A directory the scan cannot read refuses.
//   6. Not checked out on refs/heads/<base>.
// Refused: exit 1, one line `refused<TAB><reason><TAB><path>` — a fact, never § 5's class word —
// every character outside the charset shown `?`; no command, and none may be run on it.
//
// Admitted: exit 0, then facts, one `<key><TAB><value>` per line:
//   admitted <path> <command>   the command is literal, single-quoted, after `--`, never `--force`:
//                               git -C '<core>' worktree remove -- '<path>'   (§ 5 cites it word for word)
//   head     branch refs/heads/<b> | detached <sha>
//   locked   no | yes[: <reason>]
//   kind     effort | reviewer     (`reviewer`: <name> starts `hanten-` or `prove-`)
//   tree     clean | dirty <n> | unreadable
//   dirt     <XY> <path>           one per entry of `git status --porcelain -z --ignored --no-renames`,
//                                  ignored ones (`!!`) included and counted, but one:
//   dirt     !! .nen/ (worktree-local ledgers, removed with the worktree; disposable — ROSTER § Rulings of 2026-10-20)
//                                  an ignored `.nen/` at the worktree's root is reported and never
//                                  counted: under the ruling of 2026-10-20 a worktree's own ledgers go
//                                  with it, core's markers suffice. Core's `.nen/` is the record and is
//                                  never a path here. Any other ignored entry counts.
//   dirt     unreadable: <first stderr line>   status failed, or warned (a non-empty stderr)
// `tree clean` means no counted dirt line. The command is printed, never run: the maintainer's pick
// (§ 6) runs it, and a failure is reported, never retried with a wider flag.
import { lstatSync, mkdtempSync, readdirSync, realpathSync, rmSync, mkdirSync, symlinkSync, writeFileSync, chmodSync, existsSync } from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const NAME = 'cleanup_path_admit';
const SAFE = /^[A-Za-z0-9_./-]+$/;
const SCRUB = ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE', 'GIT_OBJECT_DIRECTORY', 'GIT_NAMESPACE', 'GIT_PREFIX'];
const LEDGER = ' (worktree-local ledgers, removed with the worktree; disposable — ROSTER § Rulings of 2026-10-20)';

process.on('uncaughtException', (e) => {
  process.stderr.write(`${NAME}: internal error, nothing admitted: ${String((e as Error).message).replace(/[^\x20-\x7e]/g, '?')}\n`);
  process.exit(2);
});

function gitEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = { ...process.env, GIT_OPTIONAL_LOCKS: '0' };
  for (const key of SCRUB) delete env[key];
  return env;
}

function git(args: string[]): { status: number | null; out: Buffer; err: string } {
  const r = spawnSync('git', args, { env: gitEnv(), maxBuffer: 256 * 1024 * 1024 });
  return { status: r.error ? null : r.status, out: r.stdout ?? Buffer.alloc(0), err: (r.stderr ?? Buffer.alloc(0)).toString('latin1') };
}

const shown = (s: string): string => s.replace(/[^A-Za-z0-9_./-]/g, '?');

function safeAbs(p: string): boolean {
  if (!p.startsWith('/') || !SAFE.test(p) || p.endsWith('/')) return false;
  return p.slice(1).split('/').every((c) => c !== '' && c !== '.' && c !== '..');
}

function usage(msg: string): never {
  process.stderr.write(`${NAME}: ${msg}\nusage: cleanup_path_admit.sh --core <abs> --base <branch> --path <abs>\n       cleanup_path_admit.sh --self-test\n`);
  process.exit(2);
}

function linkState(p: string): 'link' | 'dir' | 'other' | 'missing' {
  try {
    const st = lstatSync(p);
    return st.isSymbolicLink() ? 'link' : st.isDirectory() ? 'dir' : 'other';
  } catch {
    return 'missing';
  }
}

// The on-disk spelling: realpath(3), which on APFS returns each component as the disk stores it.
function real(p: string): string | null {
  try { return realpathSync.native(p); } catch { return null; }
}

// A `.git` below root other than root/.git, or a directory the walk cannot read. Symlinks are not followed.
function nestedRepo(root: string): { what: 'repo' | 'unreadable'; rel: string } | null {
  const stack = [root];
  while (stack.length > 0) {
    const dir = stack.pop() as string;
    let ents;
    try { ents = readdirSync(dir, { withFileTypes: true }); } catch { return { what: 'unreadable', rel: dir.slice(root.length + 1) }; }
    for (const e of ents) {
      const p = `${dir}/${e.name}`;
      if (e.name === '.git') { if (dir === root) continue; return { what: 'repo', rel: p.slice(root.length + 1) }; }
      if (e.isDirectory()) stack.push(p);
    }
  }
  return null;
}

type Entry = { path: string; attrs: string[] };

function parsePorcelainZ(buf: Buffer): Entry[] {
  const entries: Entry[] = [];
  let cur: Entry | null = null;
  for (const field of buf.toString('latin1').split('\0')) {
    if (field === '') { cur = null; continue; }
    if (field.startsWith('worktree ')) { cur = { path: field.slice(9), attrs: [] }; entries.push(cur); continue; }
    if (cur) cur.attrs.push(field);
  }
  return entries;
}

function admit(argv: string[]): never {
  const v: Record<string, string> = {};
  for (let i = 0; i < argv.length; i += 2) {
    const flag = argv[i];
    if (!['--core', '--base', '--path'].includes(flag)) usage(`unknown argument '${shown(flag)}'`);
    if (flag in v) usage(`${flag} given twice`);
    if (i + 1 >= argv.length) usage(`${flag} needs a value`);
    v[flag] = argv[i + 1];
  }
  const core = v['--core'], base = v['--base'], path = v['--path'];
  if (core === undefined || base === undefined || path === undefined) usage('--core, --base and --path are all required');

  if (base.startsWith('refs/') || base.includes('@{') || !SAFE.test(base)) usage('--base must be the short trunk name (no refs/, no @{)');
  if (git(['check-ref-format', '--branch', base]).status !== 0) usage('--base is not a legal branch name');

  if (!safeAbs(core)) usage('--core is not a plain absolute path');
  if (real(core) !== core) usage('--core does not resolve to itself');
  const common = git(['-C', core, 'rev-parse', '--path-format=absolute', '--git-common-dir']);
  if (common.status !== 0) usage('--core is not a git checkout');
  if (real(dirname(common.out.toString('latin1').replace(/\n$/, ''))) !== core) usage("--core is not its repository's main worktree");
  const want = [`refs/heads/${base}`, `refs/remotes/origin/${base}`];
  const refs = git(['-C', core, 'for-each-ref', '--format=%(refname)', ...want]);
  const names = refs.out.toString('latin1').split('\n').filter((l) => l !== '');
  if (refs.status !== 0 || names.length === 0 || !names.every((n) => want.includes(n))) {
    usage(`--base is spelled as no refs/heads/${base} nor refs/remotes/origin/${base}`);
  }

  const refuse = (reason: string): never => {
    process.stdout.write(`refused\t${reason}\t${shown(path)}\n`);
    process.exit(1);
  };

  // 1 — the spelling
  if (!path.startsWith('/')) refuse('not an absolute path');
  if (!SAFE.test(path)) refuse('a character outside [A-Za-z0-9_./-] (space, quote, control or non-ASCII)');
  if (!safeAbs(path)) refuse("an empty, '.' or '..' component, or a trailing slash");

  // 2 — the home, at § 4's <surface>/<name> level
  const home = `${core}/.nen/worktrees`;
  if (!path.startsWith(`${home}/`)) refuse(`outside the cleanup home ${home}`);
  const rest = path.slice(home.length + 1).split('/');
  if (rest.length === 1 && rest[0] === 'kagutsuchi') refuse("kagutsuchi's fixed worktree, kept");
  if (rest.length !== 2) refuse('not at <home>/<surface>/<name>');
  const surfaceDir = `${home}/${rest[0]}`;

  // 3 — no symlink on the way (the directory checks wait for the inventory: a prunable entry has none)
  if (linkState(`${core}/.nen`) === 'link') refuse(`${core}/.nen is a symlink`);
  if (linkState(home) === 'link') refuse('the cleanup home is a symlink');
  if (linkState(surfaceDir) === 'link') refuse('the surface directory is a symlink');
  if (linkState(path) === 'link') refuse('the path is a symlink');

  // 4 — the inventory
  const inv = git(['-C', core, 'worktree', 'list', '--porcelain', '-z']);
  if (inv.status !== 0) refuse('the worktree inventory is unreadable');
  const entries = parsePorcelainZ(inv.out);
  const mine = entries.filter((e) => e.path === path);
  if (mine.length !== 1) refuse('not listed by git worktree list');
  const entry = mine[0];
  if (entry.attrs.some((a) => a === 'prunable' || a.startsWith('prunable '))) refuse("prunable: git worktree prune's row, which takes no path");
  if (linkState(path) !== 'dir') refuse('not a directory on disk');
  if (real(path) !== path) refuse('does not resolve to itself on disk (a symlinked component or another case)');
  const top = git(['-C', path, 'rev-parse', '--show-toplevel']);
  if (top.status !== 0 || top.out.toString('latin1').replace(/\n$/, '') !== path) refuse('not a worktree root');

  // 5 — nothing nested, compared on the disk's own spelling
  const nested = entries.find((e) => {
    if (e === entry) return false;
    const r = real(e.path);
    return (r ?? e.path).startsWith(`${path}/`) || e.path.startsWith(`${path}/`);
  });
  if (nested) refuse(`contains another worktree: ${shown(nested.path)}`);
  const below = nestedRepo(path);
  if (below?.what === 'repo') refuse(`contains a nested repository: ${shown(below.rel)}`);
  if (below?.what === 'unreadable') refuse(`a directory below it could not be read: ${shown(below.rel)}`);

  // 6 — the trunk
  if (entry.attrs.includes(`branch refs/heads/${base}`)) refuse(`checked out on the trunk ${base}`);

  // Facts.
  const lines: string[] = [`admitted\t${path}\tgit -C '${core}' worktree remove -- '${path}'`];
  const branch = entry.attrs.find((a) => a.startsWith('branch '));
  const sha = (entry.attrs.find((a) => a.startsWith('HEAD ')) ?? 'HEAD ?').slice(5);
  lines.push(branch ? `head\tbranch ${shown(branch.slice(7))}` : `head\tdetached ${shown(sha)}`);
  const locked = entry.attrs.find((a) => a === 'locked' || a.startsWith('locked '));
  lines.push(locked === undefined ? 'locked\tno' : locked === 'locked' ? 'locked\tyes' : `locked\tyes: ${shown(locked.slice(7))}`);
  lines.push(`kind\t${/^(hanten|prove)-/.test(rest[1]) ? 'reviewer' : 'effort'}`);
  const status = git(['-C', path, 'status', '--porcelain=v1', '-z', '--ignored', '--no-renames', '--untracked-files=normal']);
  const dirt: string[] = [];
  let counted = 0;
  let unreadable = false;
  if (status.status !== 0 || status.err.trim() !== '') {
    unreadable = true;
    const first = status.err.split('\n').find((l) => l.trim() !== '') ?? `git status exit ${status.status}`;
    dirt.push(`dirt\tunreadable: ${first.replace(/[^\x20-\x7e]/g, '?')}`);
  }
  if (status.status === 0) {
    for (const field of status.out.toString('latin1').split('\0')) {
      if (field.length < 4) continue;
      const xy = field.slice(0, 2).replace(/[^A-Z?! ]/g, '?');
      const p = field.slice(3);
      const ledger = xy === '!!' && (p === '.nen/' || p === '.nen');
      if (!ledger) counted++;
      dirt.push(`dirt\t${xy} ${shown(p)}${ledger ? LEDGER : ''}`);
    }
  }
  lines.push(unreadable ? 'tree\tunreadable' : counted === 0 ? 'tree\tclean' : `tree\tdirty ${counted}`);
  process.stdout.write(`${[...lines, ...dirt].join('\n')}\n`);
  process.exit(0);
}

// --- self-test -------------------------------------------------------------------------------------
async function selfTest(): Promise<number> {
  const self = fileURLToPath(import.meta.url);
  const shim = join(dirname(self), 'cleanup_path_admit.sh');
  const tmpBase = [process.env.TMPDIR ?? '', '/tmp'].map((d) => real(d.replace(/\/+$/, '') || '/')).find((d) => d !== null && safeAbs(d)) ?? null;
  if (tmpBase === null) { process.stderr.write(`${NAME} --self-test: no temp directory inside the charset\n`); return 2; }
  const tmp = real(mkdtempSync(join(tmpBase, 'cleanup-path-admit.'))) as string;
  const children = new Set<ReturnType<typeof spawn>>();
  const clean = () => { try { spawnSync('chmod', ['-R', 'u+rwx', tmp]); rmSync(tmp, { recursive: true, force: true }); } catch { /* best effort */ } };
  for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP'] as const) {
    process.on(sig, () => {
      for (const c of children) c.kill('SIGKILL');
      clean();
      process.stderr.write(`${NAME} --self-test: interrupted by ${sig}; no assertion is reported after it\n`);
      process.exit(sig === 'SIGINT' ? 130 : sig === 'SIGTERM' ? 143 : 129);
    });
  }
  const env: NodeJS.ProcessEnv = {
    ...gitEnv(), GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null',
    GIT_AUTHOR_NAME: 'selftest', GIT_AUTHOR_EMAIL: 'selftest@example.invalid',
    GIT_COMMITTER_NAME: 'selftest', GIT_COMMITTER_EMAIL: 'selftest@example.invalid',
  };
  const run = (exe: string, args: string[], extraEnv: NodeJS.ProcessEnv = {}): Promise<{ code: number; out: string; err: string }> =>
    new Promise((resolveRun) => {
      const c = spawn(exe, args, { env: { ...env, ...extraEnv }, stdio: ['ignore', 'pipe', 'pipe'] });
      children.add(c);
      const chunks: Buffer[] = [];
      const errs: Buffer[] = [];
      c.stdout.on('data', (d: Buffer) => chunks.push(d));
      c.stderr.on('data', (d: Buffer) => errs.push(d));
      c.on('error', () => { children.delete(c); resolveRun({ code: 127, out: '', err: '' }); });
      c.on('close', (code) => { children.delete(c); resolveRun({ code: code ?? 128, out: Buffer.concat(chunks).toString('utf8'), err: Buffer.concat(errs).toString('utf8') }); });
    });
  let fails = 0;
  const ok = (label: string) => process.stdout.write(`  ok    ${label}\n`);
  const skip = (label: string, why: string) => process.stdout.write(`  skip  ${label} (${why}; not asserted here)\n`);
  const fail = (label: string, why: string) => { process.stderr.write(`  FAIL  ${label} (${why})\n`); fails++; };
  let last = '';
  let lastErr = '';
  const adm = async (wantExit: number, wantFirst: string, label: string, args: string[], extraEnv: NodeJS.ProcessEnv = {}) => {
    const r = await run(process.execPath, [self, ...args], extraEnv);
    last = r.out;
    lastErr = r.err;
    const first = r.out.split('\n')[0];
    if (r.code === wantExit && (wantFirst === '' ? true : first.startsWith(wantFirst))) ok(label);
    else fail(label, `exit ${r.code}, want ${wantExit}; first line '${first}', want '${wantFirst}…'`);
  };
  const has = (text: string, label: string) => (last.includes(text) ? ok(label) : fail(label, `no '${text}' in: ${last.trim()}`));
  const lacks = (text: string, label: string) => (!last.includes(text) ? ok(label) : fail(label, `'${text}' present in: ${last.trim()}`));
  const step = async (exe: string, args: string[]) => {
    const r = await run(exe, args);
    if (r.code !== 0) throw new Error(`${exe} ${args.join(' ')} exited ${r.code}`);
  };

  const core = join(tmp, 'core');
  const home = `${core}/.nen/worktrees`;
  const H = `${home}/claude-code`;
  const wt = async (...args: string[]) => step('git', ['-C', core, 'worktree', 'add', '-q', ...args]);
  let fakePath = '';
  let warnPath = '';
  let caseless = false;
  const coreU = join(tmp, 'core_u');
  const nodeOld = join(tmp, 'nodeold');
  const noNode = join(tmp, 'nonode');
  try {
    await step('git', ['init', '-q', '-b', 'main', core]);
    writeFileSync(join(core, '.gitignore'), '.nen/\n.env\n');
    await step('git', ['-C', core, 'add', '.gitignore']);
    await step('git', ['-C', core, 'commit', '-q', '-m', 'base']);
    await step('git', ['-C', core, 'switch', '-q', '-c', 'scratch']);
    mkdirSync(H, { recursive: true });
    for (const n of ['merged', 'dirty', 'locked', 'barelock', 'lockgone', 'ledger', 'dotenv', 'unreadable', 'gone', 'outer', 'outer5', 'clonehost']) await wt('-b', `feat-${n}`, `${H}/${n}`, 'main');
    await wt('--detach', `${H}/detached`, 'main');
    await wt('--detach', `${H}/hanten-chrollo-b`, 'main');
    await wt('--detach', `${H}/prove-1`, 'main');
    await wt(`${H}/trunk`, 'main');
    await wt('-b', 'feat-outside', join(tmp, 'outside'), 'main');
    await wt('-b', 'feat-kagutsuchi', `${home}/kagutsuchi`, 'main');
    await wt('-b', 'feat-top', `${home}/top`, 'main');
    await wt('-b', 'feat-inner', `${H}/outer/inner`, 'main');
    writeFileSync(`${H}/outer/inner/work.txt`, 'x\n');
    // On a case-insensitive disk OUTER5 is outer5: the inner registration is spelled in another case.
    caseless = existsSync(`${home}/CLAUDE-CODE`);
    await wt('-b', 'feat-inner5', `${H}/OUTER5/.nen/w/inner5`, 'main');
    writeFileSync(`${H}/OUTER5/.nen/w/inner5/work.txt`, 'x\n');
    // A nested clone under an ignored directory: git status shows only `!! .nen/`.
    await step('git', ['init', '-q', '-b', 'main', `${H}/clonehost/.nen/vendor/repo`]);
    await wt('-b', 'feat-victim', `${H}/victim`, 'main');
    await step('git', ['-C', `${H}/victim`, 'switch', '-q', '--detach']);
    await wt('-b', 'evil', `${tmp}/x\nworktree ${H}/victim\nbranch refs/heads/feat-fake`, 'main');
    await step('git', ['-C', core, 'worktree', 'lock', '--reason', 'kept by hand', `${H}/locked`]);
    await step('git', ['-C', core, 'worktree', 'lock', `${H}/barelock`]);
    await step('git', ['-C', core, 'worktree', 'lock', '--reason', 'gone', `${H}/lockgone`]);
    rmSync(`${H}/lockgone`, { recursive: true, force: true });
    writeFileSync(`${H}/dirty/uncommitted.txt`, 'x\n');
    mkdirSync(`${H}/ledger/.nen/hanten`, { recursive: true });
    writeFileSync(`${H}/ledger/.nen/hanten/k.cycle.json`, '{}\n');
    writeFileSync(`${H}/dotenv/.env`, 'TOKEN=redacted\n');
    mkdirSync(`${H}/unreadable/notes`);
    writeFileSync(`${H}/unreadable/notes/draft.txt`, 'work\n');
    chmodSync(`${H}/unreadable/notes`, 0o300);
    rmSync(`${H}/gone`, { recursive: true, force: true });
    mkdirSync(`${H}/stray`);
    await step('git', ['init', '-q', '-b', 'main', `${H}/nested-repo`]);
    symlinkSync(`${H}/merged`, `${H}/link`);
    symlinkSync(H, `${home}/linked`);
    symlinkSync(core, join(tmp, 'corelink'));
    // core_u: an underscore in the core and the name.
    await step('git', ['init', '-q', '-b', 'main', coreU]);
    await step('git', ['-C', coreU, 'commit', '-q', '--allow-empty', '-m', 'base']);
    await step('git', ['-C', coreU, 'worktree', 'add', '-q', '-b', 'feat-u', `${coreU}/.nen/worktrees/claude-code/w_1`, 'main']);
    // core2: a symlinked .nen; core3: a symlinked home; notgit: no repository at all.
    for (const [c, linkAt] of [['core2', '.nen'], ['core3', '.nen/worktrees']] as const) {
      const cc = join(tmp, c);
      await step('git', ['init', '-q', '-b', 'main', cc]);
      await step('git', ['-C', cc, 'commit', '-q', '--allow-empty', '-m', 'base']);
      const away = join(tmp, `${c}-away`);
      mkdirSync(join(away, 'worktrees', 'claude-code'), { recursive: true });
      if (linkAt === '.nen/worktrees') { mkdirSync(join(cc, '.nen')); symlinkSync(join(away, 'worktrees'), join(cc, linkAt)); }
      else symlinkSync(away, join(cc, linkAt));
      await step('git', ['-C', cc, 'worktree', 'add', '-q', '-b', 'feat-x', join(cc, '.nen/worktrees/claude-code/x'), 'main']);
    }
    mkdirSync(join(tmp, 'notgit'));
    const realGit = spawnSync('sh', ['-c', 'command -v git'], { env }).stdout.toString().trim();
    for (const [dir, body] of [
      ['fakebin', `case " $* " in *" worktree list "*) echo 'fatal: simulated unreadable inventory' >&2; exit 128 ;; esac\n`],
      ['warnbin', `case " $* " in *" status "*) echo 'warning: could not open directory notes/: Permission denied' >&2 ;; esac\n`],
    ] as const) {
      mkdirSync(join(tmp, dir));
      writeFileSync(join(tmp, dir, 'git'), `#!/bin/sh\n${body}exec '${realGit}' "$@"\n`);
      chmodSync(join(tmp, dir, 'git'), 0o755);
    }
    // The shim's node floor: a node that reports 22.14.0, and a PATH holding only dirname.
    mkdirSync(nodeOld);
    writeFileSync(join(nodeOld, 'node'), '#!/bin/sh\necho v22.14.0\n');
    chmodSync(join(nodeOld, 'node'), 0o755);
    mkdirSync(noNode);
    symlinkSync(spawnSync('sh', ['-c', 'command -v dirname'], { env }).stdout.toString().trim(), join(noNode, 'dirname'));
    fakePath = `${join(tmp, 'fakebin')}:${process.env.PATH ?? ''}`;
    warnPath = `${join(tmp, 'warnbin')}:${process.env.PATH ?? ''}`;
  } catch (e) {
    clean();
    process.stderr.write(`${NAME} --self-test: could not build the fixture: ${(e as Error).message}\n`);
    return 2;
  }
  const a = ['--core', core, '--base', 'main'];
  const cmd = (p: string) => `git -C '${core}' worktree remove -- '${p}'`;
  process.stdout.write(`${NAME} --self-test\n`);

  const why = spawnSync('git', ['check-ref-format', '--branch', `${H}/merged`], { env });
  why.status !== 0 ? ok('git check-ref-format --branch refuses the absolute path (why the ref rule cannot admit it)')
    : fail('check-ref-format refuses the absolute path', 'it admitted it');

  // --- admission and its facts ---------------------------------------------------------------------
  await adm(0, `admitted\t${H}/merged\t${cmd(`${H}/merged`)}`, 'a listed worktree under <home>/<surface>/ is admitted with the one quoted command', [...a, '--path', `${H}/merged`]);
  has('head\tbranch refs/heads/feat-merged\n', 'its head fact names the branch');
  has('locked\tno\n', 'and it is not locked');
  has('kind\teffort\n', 'and it is an effort checkout');
  has('tree\tclean\n', 'and the tree is clean');
  lacks('class', 'and no class is printed: the class is cleanup § 5\'s');
  {
    const r = await run('sh', [shim, ...a, '--path', `${H}/merged`]);
    r.code === 0 && r.out.startsWith('admitted\t') ? ok('run through the sh shim, the same admission') : fail('the sh shim', `exit ${r.code}`);
    for (const [label, bin, reason] of [
      ['a node below the type-stripping floor exits 2 in the shim, never 1', nodeOld, 'node >= 22.18 required (found v22.14.0'],
      ['no node on PATH exits 2 in the shim, never 1', noNode, 'node not found'],
    ] as const) {
      const s = await run('/bin/sh', [shim, ...a, '--path', `${H}/merged`], { PATH: bin });
      s.code === 2 && s.out === '' && s.err.includes(reason) ? ok(label) : fail(label, `exit ${s.code}, stderr '${s.err.trim()}'`);
    }
  }
  await adm(0, `admitted\t${coreU}/.nen/worktrees/claude-code/w_1`, 'an underscore in the core path and the name is admitted', ['--core', coreU, '--base', 'main', '--path', `${coreU}/.nen/worktrees/claude-code/w_1`]);
  await adm(0, 'admitted', 'a dirty worktree is admitted', [...a, '--path', `${H}/dirty`]);
  has('tree\tdirty 1\n', 'its tree fact is dirty');
  has('dirt\t?? uncommitted.txt\n', 'with every dirty path on a dirt line');
  await adm(0, 'admitted', 'an ignored worktree-local .nen/ ledger is admitted', [...a, '--path', `${H}/ledger`]);
  has(`dirt\t!! .nen/${LEDGER}\n`, 'and reported as disposable ledgers on a dirt line (ROSTER § Rulings of 2026-10-20)');
  lacks('kept', 'and never called kept');
  has('tree\tclean\n', 'and, alone, it does not make the tree dirty');
  await adm(0, 'admitted', 'an ignored .env is admitted', [...a, '--path', `${H}/dotenv`]);
  has('dirt\t!! .env\n', 'and listed on a dirt line');
  has('tree\tdirty 1\n', 'and any other ignored entry makes the tree dirty');
  await adm(0, 'admitted', 'a tree git status warns about is admitted', [...a, '--path', `${H}/merged`], { PATH: warnPath });
  has('tree\tunreadable\n', 'and its tree is unreadable, never clean');
  has('dirt\tunreadable: warning: could not open directory', 'with the warning on a dirt line');
  await adm(0, 'admitted', 'a locked worktree is admitted', [...a, '--path', `${H}/locked`]);
  has('locked\tyes: kept?by?hand\n', 'with its lock and reason as a fact');
  await adm(0, 'admitted', 'a bare git worktree lock (no reason) is admitted', [...a, '--path', `${H}/barelock`]);
  has('locked\tyes\n', 'and reads locked yes, no reason');
  await adm(0, 'admitted', 'a detached worktree is admitted', [...a, '--path', `${H}/detached`]);
  has('head\tdetached ', 'and its head fact says detached');
  await adm(0, 'admitted', 'a hanten reviewer checkout is admitted', [...a, '--path', `${H}/hanten-chrollo-b`]);
  has('kind\treviewer\n', 'and its kind is reviewer (the ledger rule classes it)');
  await adm(0, 'admitted', 'a prove- checkout is admitted', [...a, '--path', `${H}/prove-1`]);
  has('kind\treviewer\n', 'and its kind is reviewer');
  await adm(0, 'admitted', 'a detached victim beside a newline-bearing worktree path is admitted', [...a, '--path', `${H}/victim`]);
  has('head\tdetached ', 'and still reads detached (the porcelain is NUL-split)');
  lacks('feat-fake', 'and no forged branch line reached its stanza');

  // --- refusals, each with its reason ---------------------------------------------------------------
  const no = async (label: string, p: string, reason: string, args: string[] = a, extraEnv: NodeJS.ProcessEnv = {}) => {
    await adm(1, `refused\t${reason}`, label, [...args, '--path', p], extraEnv);
    lacks('worktree remove', '  and carries no command');
    lacks('named', '  and prints no class word');
  };
  await no('core itself is refused', core, 'outside the cleanup home');
  await no("the trunk's worktree is refused", `${H}/trunk`, 'checked out on the trunk main');
  await no('a listed worktree outside the home is refused', join(tmp, 'outside'), 'outside the cleanup home');
  await no("kagutsuchi's fixed worktree is kept", `${home}/kagutsuchi`, "kagutsuchi's fixed worktree, kept");
  await no('a worktree at the home\'s top level is refused', `${home}/top`, 'not at <home>/<surface>/<name>');
  await no('a directory git does not list is refused', `${H}/stray`, 'not listed by git worktree list');
  await no('a nested repository under the home, unlisted, is refused', `${H}/nested-repo`, 'not listed by git worktree list');
  await no('a worktree holding a nested dirty worktree is refused', `${H}/outer`, `contains another worktree: ${H}/outer/inner`);
  if (caseless) await no('a nested registration differing only in case is refused (on-disk spelling)', `${H}/outer5`, `contains another worktree: ${H}/OUTER5/.nen/w/inner5`);
  else skip('a nested registration differing only in case', 'this disk is case-sensitive');
  await no('a nested clone under an ignored directory is refused', `${H}/clonehost`, 'contains a nested repository: .nen/vendor/repo/.git');
  await no('a directory the nested-repository scan cannot read is refused', `${H}/unreadable`, 'a directory below it could not be read: notes');
  await no('a prunable registration is refused (prune takes no path)', `${H}/gone`, 'prunable: ');
  await no('a locked worktree whose directory is gone is refused', `${H}/lockgone`, 'not a directory on disk');
  await no('a symlink to an admitted worktree is refused', `${H}/link`, 'the path is a symlink');
  await no('a symlinked <surface> directory is refused', `${home}/linked/merged`, 'the surface directory is a symlink');
  await no('a symlinked .nen in core is refused', join(tmp, 'core2/.nen/worktrees/claude-code/x'), `${join(tmp, 'core2')}/.nen is a symlink`, ['--core', join(tmp, 'core2'), '--base', 'main']);
  await no('a symlinked home is refused', join(tmp, 'core3/.nen/worktrees/claude-code/x'), 'the cleanup home is a symlink', ['--core', join(tmp, 'core3'), '--base', 'main']);
  await no('an unreadable inventory is refused', `${H}/merged`, 'the worktree inventory is unreadable', a, { PATH: fakePath });
  const spelling = "an empty, '.' or '..' component, or a trailing slash";
  const charset = 'a character outside [A-Za-z0-9_./-]';
  await no("'..' traversal is refused as spelled, never normalised", `${H}/../claude-code/merged`, spelling);
  await no("a '.' component is refused", `${H}/./merged`, spelling);
  await no('a trailing slash is refused', `${H}/merged/`, spelling);
  await no('a relative path is refused', 'claude-code/merged', 'not an absolute path');
  await no('an empty path is refused', '', 'not an absolute path');
  await no('a space is refused', `${H}/mer ged`, charset);
  await no('a single quote is refused', `${H}/mer'ged`, charset);
  await no('a newline is refused', `${H}/mer\nged`, charset);
  has(`${H}/mer?ged`, 'and the refused name is shown escaped');

  // --- usage: exit 2, nothing admitted, each with its reason ------------------------------------------
  const two = async (label: string, args: string[], reason: string) => {
    await adm(2, '', label, args);
    last.trim() === '' ? ok('  and admits nothing') : fail(label, `printed ${last.trim()}`);
    lastErr.includes(reason) ? ok(`  because: ${reason}`) : fail(label, `stderr lacks '${reason}': ${lastErr.trim()}`);
  };
  const p = ['--path', `${H}/merged`];
  await two('--base refs/heads/main is refused, so it cannot dodge the trunk check', ['--core', core, '--base', 'refs/heads/main', '--path', `${H}/trunk`], 'no refs/, no @{');
  await two('--base heads/main is refused (no refs/heads/heads/main)', ['--core', core, '--base', 'heads/main', '--path', `${H}/trunk`], 'is spelled as no refs/heads/heads/main');
  await two('--base Main is refused (a case-insensitive disk resolves it, for-each-ref does not)', ['--core', core, '--base', 'Main', '--path', `${H}/trunk`], 'is spelled as no refs/heads/Main');
  await two('--base @{-1} is refused', ['--core', core, '--base', '@{-1}', '--path', `${H}/trunk`], 'no refs/, no @{');
  await two('--base a..b is refused', ['--core', core, '--base', 'a..b', ...p], 'not a legal branch name');
  await two('a missing --base is refused', ['--core', core, ...p], 'are all required');
  await two('a flag with no value is refused', [...a, '--path'], '--path needs a value');
  await two('a core that is not a git checkout is refused', ['--core', join(tmp, 'notgit'), '--base', 'main', ...p], 'not a git checkout');
  await two('a linked worktree as --core is refused', ['--core', `${H}/merged`, '--base', 'main', '--path', `${H}/dirty`], "not its repository's main worktree");
  await two('a non-canonical --core is refused', ['--core', `${core}/.nen/..`, '--base', 'main', ...p], 'not a plain absolute path');
  await two('a symlink to core as --core is refused', ['--core', join(tmp, 'corelink'), '--base', 'main', ...p], 'does not resolve to itself');
  await two('an unknown argument is refused', [...a, ...p, '--force', 'x'], "unknown argument '--force'");
  await two('a repeated flag is refused', [...a, ...p, '--path', `${H}/dirty`], '--path given twice');
  await two('--self-test with another argument is refused', ['--self-test', 'x'], '--self-test takes no other argument');

  // The printed command is literal and runs as printed; the script itself removed nothing.
  existsSync(`${H}/merged`) ? ok('the script removed nothing') : fail('the script removed nothing', 'merged is gone');
  const rm = await run('git', ['-C', core, 'worktree', 'remove', '--', `${H}/merged`]);
  rm.code === 0 && !existsSync(`${H}/merged`) ? ok('the printed command removes the clean worktree') : fail('the printed command', `exit ${rm.code}`);
  existsSync(H) ? ok('and leaves the .nen/ home in place') : fail('the home survives', 'it is gone');

  clean();
  if (fails === 0) {
    process.stdout.write(`${NAME} --self-test: all assertions held; nothing left this machine.\n`);
    return 0;
  }
  process.stderr.write(`${NAME} --self-test: ${fails} assertion(s) failed\n`);
  return 1;
}

const args = process.argv.slice(2);
if (args[0] === '--self-test') {
  if (args.length !== 1) usage('--self-test takes no other argument');
  selfTest().then((code) => process.exit(code));
} else {
  admit(args);
}
