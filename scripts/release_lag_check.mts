#!/usr/bin/env node
// release_lag_check.mts — how far the latest published release trails `main` (zheref/hatsu#533).
//
// docs/WORKFLOW.md § 4's release cadence declares which versions get a tag: a getsuga cut tags the
// version `main` declares at the cut point, the versions between two cuts ride the next one, and a
// cut is owed once `main` is more than one minor ahead of the latest published release. This guard
// measures that and says it in one line; morning-desk (contracts/schedule.json) quotes the line every
// weekday, so the lag reaches the maintainer without anyone comparing versions by hand.
//
//   node scripts/release_lag_check.mts --root <hatsu> [--ref origin/main] [--max-minor 1] [--json]
//   node scripts/release_lag_check.mts --main X.Y.Z --release vX.Y.Z|none [--tag vX.Y.Z] [--max-minor 1] [--json]
//
// The first form reads live: `main`'s version from `git show <ref>:.claude-plugin/plugin.json`
// (the caller fetches first), the latest published release from `gh release view --json tagName`
// run in <root> (drafts and prereleases are never the latest), and the newest vX.Y.Z tag on origin
// from `git ls-remote --tags --refs origin`. The second form takes the three values as given.
//
// Exit 0: in step, or behind within the cadence (a patch, or at most --max-minor minors).
// Exit 1: a cut is owed (more than --max-minor minors, a major, or no release at all), or the
//         release reads ahead of `main` (a version that never landed was tagged).
// Exit 2: a usage error or a read that failed; stdout stays empty, so "could not look" never reads
//         as "in step".
// A newest tag above the latest release adds that the tag is cut but unpublished (publication at G3); it
// never changes the exit. Read-only: it cuts nothing, publishes nothing and writes nothing.
import { spawnSync } from 'node:child_process';
import { realpathSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

type Version = [number, number, number];
export type Verdict = {
  main: string;
  release: string | null;
  tag: string | null;
  state: 'in-step' | 'within-cadence' | 'cut-owed' | 'release-ahead';
  minorsBehind: number | null;
  unpublishedTag: string | null;
  maxMinor: number;
  line: string;
};

const SEMVER = /^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const CADENCE = 'docs/WORKFLOW.md § 4, the release cadence';

export function parseVersion(text: string): Version | null {
  const m = SEMVER.exec(text);
  if (!m) return null;
  const v = [Number(m[1]), Number(m[2]), Number(m[3])] as Version;
  return v.every(Number.isSafeInteger) ? v : null;
}

function compare(a: Version, b: Version): number {
  for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1;
  return 0;
}

export function newestTag(tags: readonly string[]): string | null {
  let best: { tag: string; v: Version } | null = null;
  for (const tag of tags) {
    if (!tag.startsWith('v')) continue;
    const v = parseVersion(tag);
    if (v && (!best || compare(v, best.v) > 0)) best = { tag, v };
  }
  return best ? best.tag : null;
}

export function judge(main: string, release: string | null, tag: string | null, maxMinor: number): Verdict {
  const m = parseVersion(main);
  if (!m || main.startsWith('v')) throw new Error(`main version '${main}' is not X.Y.Z`);
  const r = release === null ? null : parseVersion(release);
  if (release !== null && (!r || !release.startsWith('v'))) throw new Error(`release '${release}' is not vX.Y.Z`);
  const t = tag === null ? null : parseVersion(tag);
  if (tag !== null && (!t || !tag.startsWith('v'))) throw new Error(`tag '${tag}' is not vX.Y.Z`);
  const unpublishedTag = t && (!r || compare(t, r) > 0) && compare(t, m) <= 0 ? tag : null;
  const tail = unpublishedTag ? `; newest tag ${unpublishedTag} is cut but unpublished (publication owed, G3)` : '';
  const base = { main, release, tag, unpublishedTag, maxMinor };
  if (!r) {
    return { ...base, state: 'cut-owed', minorsBehind: null,
      line: `release-lag: main ${main}, no published release: a cut is owed (${CADENCE})${tail}` };
  }
  const order = compare(r, m);
  if (order > 0) {
    return { ...base, state: 'release-ahead', minorsBehind: null,
      line: `release-lag: latest release ${release} is ahead of main ${main}: a version that never landed on main was tagged; read the tag before the next cut${tail}` };
  }
  if (order === 0) {
    return { ...base, state: 'in-step', minorsBehind: 0, line: `release-lag: main ${main}, latest release ${release}: in step${tail}` };
  }
  if (r[0] !== m[0]) {
    return { ...base, state: 'cut-owed', minorsBehind: null,
      line: `release-lag: main ${main}, latest release ${release}: a major behind, a cut is owed (${CADENCE})${tail}` };
  }
  const minors = m[1] - r[1];
  if (minors === 0) {
    return { ...base, state: 'within-cadence', minorsBehind: 0,
      line: `release-lag: main ${main}, latest release ${release}: a patch behind, within the cadence (rides the next cut)${tail}` };
  }
  const word = minors === 1 ? 'minor' : 'minors';
  if (minors <= maxMinor) {
    return { ...base, state: 'within-cadence', minorsBehind: minors,
      line: `release-lag: main ${main}, latest release ${release}: ${minors} ${word} behind, within the cadence of ${maxMinor} (rides the next cut)${tail}` };
  }
  return { ...base, state: 'cut-owed', minorsBehind: minors,
    line: `release-lag: main ${main}, latest release ${release}: ${minors} ${word} behind, a cut is owed (more than ${maxMinor}, ${CADENCE}; the cut is the maintainer's call)${tail}` };
}

function run(cmd: string, args: string[], cwd: string): { ok: boolean; out: string; err: string } {
  const r = spawnSync(cmd, args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  return { ok: r.status === 0 && !r.error, out: r.stdout ?? '', err: (r.stderr ?? '') + (r.error ? String(r.error.message) : '') };
}

function readLive(root: string, ref: string): { main: string; release: string | null; tag: string | null } {
  const manifest = run('git', ['-C', root, 'show', `${ref}:.claude-plugin/plugin.json`], root);
  if (!manifest.ok) throw new Error(`cannot read .claude-plugin/plugin.json at ${ref}: ${manifest.err.trim()}`);
  let main: unknown;
  try {
    main = (JSON.parse(manifest.out) as { version?: unknown }).version;
  } catch {
    throw new Error(`.claude-plugin/plugin.json at ${ref} is not JSON`);
  }
  if (typeof main !== 'string') throw new Error(`.claude-plugin/plugin.json at ${ref} carries no version string`);
  const gh = run('gh', ['release', 'view', '--json', 'tagName', '--jq', '.tagName'], root);
  let release: string | null;
  if (gh.ok) release = gh.out.trim();
  else if (/release not found/i.test(gh.err)) release = null;
  else throw new Error(`gh release view failed: ${gh.err.trim()}`);
  const remote = run('git', ['-C', root, 'ls-remote', '--tags', '--refs', 'origin'], root);
  if (!remote.ok) throw new Error(`git ls-remote --tags origin failed: ${remote.err.trim()}`);
  const tags = remote.out.split('\n').map((l) => l.split('\t')[1] ?? '').filter((r) => r.startsWith('refs/tags/')).map((r) => r.slice('refs/tags/'.length));
  return { main, release, tag: newestTag(tags) };
}

export function main(argv: string[]): number {
  const opts: Record<string, string> = {};
  let json = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--json') { json = true; continue; }
    if (!['--root', '--ref', '--max-minor', '--main', '--release', '--tag'].includes(a)) {
      console.error(`release-lag: unknown argument '${a}'`);
      return 2;
    }
    const v = argv[++i];
    if (v === undefined || v.startsWith('--')) { console.error(`release-lag: ${a} needs a value`); return 2; }
    if (a in opts) { console.error(`release-lag: ${a} given twice`); return 2; }
    opts[a] = v;
  }
  const live = '--root' in opts;
  const given = '--main' in opts || '--release' in opts || '--tag' in opts;
  if (live === given || (given && !('--main' in opts && '--release' in opts)) || (!live && '--ref' in opts)) {
    console.error('release-lag: pass --root <hatsu> [--ref <ref>], or --main X.Y.Z --release vX.Y.Z|none [--tag vX.Y.Z]');
    return 2;
  }
  const maxText = opts['--max-minor'] ?? '1';
  if (!/^(0|[1-9]\d{0,2})$/.test(maxText)) { console.error(`release-lag: --max-minor '${maxText}' is not a whole number below 1000`); return 2; }
  try {
    let values: { main: string; release: string | null; tag: string | null };
    if (live) {
      const root = opts['--root'];
      try {
        if (!statSync(root).isDirectory()) throw new Error();
      } catch {
        throw new Error(`--root '${root}' is not a directory`);
      }
      values = readLive(root, opts['--ref'] ?? 'origin/main');
    } else {
      values = { main: opts['--main'], release: opts['--release'] === 'none' ? null : opts['--release'], tag: opts['--tag'] ?? null };
    }
    const verdict = judge(values.main, values.release, values.tag, Number(maxText));
    console.log(json ? JSON.stringify(verdict) : verdict.line);
    return verdict.state === 'cut-owed' || verdict.state === 'release-ahead' ? 1 : 0;
  } catch (e) {
    console.error(`release-lag: ${(e as Error).message}`);
    return 2;
  }
}

// argv keeps the installed alias spelling; module URLs resolve to the real file.
let invoked = false;
try {
  invoked = process.argv[1] !== undefined && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  if (!invoked && import.meta.main === true) throw new Error('entry mismatch');
} catch {
  if (import.meta.main === true) {
    console.error('release-lag: cannot resolve CLI entry to this module');
    process.exitCode = 2;
  }
}
if (invoked) process.exitCode = main(process.argv.slice(2));
