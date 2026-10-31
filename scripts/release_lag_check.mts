#!/usr/bin/env node
// release_lag_check.mts — how far the latest published release trails `main` (zheref/hatsu#533).
//
// docs/WORKFLOW.md § 4's release cadence declares which versions get a tag and when a cut is owed;
// that paragraph is the one source of the threshold, and --max-minor's default below is its value.
// This guard measures the lag and says it in one line; morning-desk (contracts/schedule.json) quotes
// the line every weekday, so the lag reaches the maintainer without anyone comparing versions by hand.
//
//   node scripts/release_lag_check.mts --root <hatsu> [--ref origin/main] [--repo [HOST/]OWNER/NAME] [--max-minor N] [--json]
//   node scripts/release_lag_check.mts --main X.Y.Z --release vX.Y.Z|none [--tag vX.Y.Z] [--max-minor N] [--json]
//
// The first form reads live: `main`'s version from `git show <ref>:.claude-plugin/plugin.json`
// (the caller fetches first), every tag on origin from `git ls-remote --tags --refs origin`, and the
// latest published release from `gh release view -R <repo>` (drafts and prereleases are never the
// latest), where <repo> is --repo or else origin's own URL, so gh never reads a different repository
// than the tags (an `upstream` remote or GH_REPO would otherwise win). The second form takes the
// three values as given.
//
// Exit 0: in step, or behind within the cadence (a patch, or at most --max-minor minors).
// Exit 1: a cut is owed (more than --max-minor minors, a major, or no release at all), or the
//         release reads ahead of `main` (a version that never landed was tagged).
// Exit 2: a usage error or a read that failed or timed out; stdout stays empty, so "could not look"
//         never reads as "in step". A value the script did not write (a tag gh returned, gh's
//         stderr) is never echoed whole: it is cut to one quoted line of at most 80 characters.
// A --max-minor other than the default is a what-if, not the declared cadence. Beside the verdict,
// never changing the exit: the newest tag at or below main and above the latest release is named as
// cut but not yet published, and the newest tag above main as never having landed on main.
// Read-only: it cuts nothing, publishes nothing and writes nothing.
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
  strayTag: string | null;
  maxMinor: number;
  line: string;
};

const SEMVER = /^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const CADENCE = 'docs/WORKFLOW.md § 4, the release cadence';
// The declared cadence (WORKFLOW § 4): a cut is owed past this many minors.
const DECLARED_MAX_MINOR = '1';
const READ_TIMEOUT_MS = 60_000;
const READ_MAX_BUFFER = 64 * 1024 * 1024;

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

// One quoted line of at most 80 characters, control characters escaped: never a value whole.
export function quoted(text: string): string {
  const first = text.split(/\r?\n/).find((l) => l.trim() !== '') ?? '';
  return JSON.stringify(first.length > 80 ? `${first.slice(0, 80)}…` : first);
}

// Every vX.Y.Z tag, kept; anything else (a non-v scheme, a prerelease, four parts) dropped unprinted.
export function versionTags(tags: readonly string[]): string[] {
  return tags.filter((t) => t.startsWith('v') && parseVersion(t) !== null);
}

function newest(tags: readonly string[], keep: (v: Version) => boolean): string | null {
  let best: { tag: string; v: Version } | null = null;
  for (const tag of versionTags(tags)) {
    const v = parseVersion(tag) as Version;
    if (keep(v) && (!best || compare(v, best.v) > 0)) best = { tag, v };
  }
  return best ? best.tag : null;
}

export function newestTag(tags: readonly string[]): string | null {
  return newest(tags, () => true);
}

// origin's URL as gh's [HOST/]OWNER/NAME, or null when it names no hosted repository (a local path).
export function repoFromRemote(url: string): string | null {
  const u = url.trim();
  const m = /^(?:https?:\/\/(?:[^@/]+@)?|ssh:\/\/(?:[^@/]+@)?|[^@/\s]+@)([A-Za-z0-9.-]+)(?::\d+)?[:/]([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+?)(?:\.git)?\/?$/.exec(u);
  if (!m || m[2].startsWith('.') || m[3].startsWith('.')) return null;
  return m[1] === 'github.com' ? `${m[2]}/${m[3]}` : `${m[1]}/${m[2]}/${m[3]}`;
}

export function judge(main: string, release: string | null, tags: readonly string[], maxMinor: number): Verdict {
  const m = parseVersion(main);
  if (!m || main.startsWith('v')) throw new Error(`main version ${quoted(main)} is not X.Y.Z`);
  const r = release === null ? null : parseVersion(release);
  if (release !== null && (!r || !release.startsWith('v'))) throw new Error(`release ${quoted(release)} is not vX.Y.Z`);
  const tag = newestTag(tags);
  const unpublishedTag = newest(tags, (v) => (!r || compare(v, r) > 0) && compare(v, m) <= 0);
  const strayTag = newest(tags, (v) => compare(v, m) > 0);
  const tail = (unpublishedTag ? `; newest tag ${unpublishedTag} is cut and not yet published (publication is the maintainer's, G3)` : '')
    + (strayTag ? `; tag ${strayTag} is above main and never landed on it` : '');
  const base = { main, release, tag, unpublishedTag, strayTag, maxMinor };
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
  const r = spawnSync(cmd, args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: READ_TIMEOUT_MS, maxBuffer: READ_MAX_BUFFER });
  const err = r.error ? ((r.error as NodeJS.ErrnoException).code === 'ETIMEDOUT' ? `timed out after ${READ_TIMEOUT_MS / 1000} s` : r.error.message) : (r.stderr ?? '');
  return { ok: r.status === 0 && !r.error, out: r.stdout ?? '', err };
}

function readLive(root: string, ref: string, repoArg: string | undefined): { main: string; release: string | null; tags: string[] } {
  const manifest = run('git', ['-C', root, 'show', '--end-of-options', `${ref}:.claude-plugin/plugin.json`], root);
  if (!manifest.ok) throw new Error(`cannot read .claude-plugin/plugin.json at ${ref}: ${quoted(manifest.err)}`);
  let main: unknown;
  try {
    main = (JSON.parse(manifest.out) as { version?: unknown }).version;
  } catch {
    throw new Error(`.claude-plugin/plugin.json at ${ref} is not JSON`);
  }
  if (typeof main !== 'string') throw new Error(`.claude-plugin/plugin.json at ${ref} carries no version string`);
  let repo = repoArg;
  if (repo === undefined) {
    const url = run('git', ['-C', root, 'remote', 'get-url', 'origin'], root);
    if (!url.ok) throw new Error(`cannot read origin's URL: ${quoted(url.err)}`);
    const parsed = repoFromRemote(url.out);
    if (parsed === null) throw new Error("origin's URL names no hosted repository; pass --repo [HOST/]OWNER/NAME");
    repo = parsed;
  }
  const remote = run('git', ['-C', root, 'ls-remote', '--tags', '--refs', 'origin'], root);
  if (!remote.ok) throw new Error(`git ls-remote --tags origin failed: ${quoted(remote.err)}`);
  const tags = remote.out.split('\n').map((l) => l.split('\t')[1] ?? '').filter((r) => r.startsWith('refs/tags/')).map((r) => r.slice('refs/tags/'.length).trim());
  const gh = run('gh', ['release', 'view', '-R', repo, '--json', 'tagName', '--jq', '.tagName'], root);
  let release: string | null;
  if (gh.ok) release = gh.out.trim();
  else if (/release not found/i.test(gh.err)) release = null;
  else throw new Error(`gh release view -R ${repo} failed: ${quoted(gh.err)}`);
  if (release !== null && !(release.startsWith('v') && parseVersion(release))) {
    throw new Error(`the latest release's tag from gh is not vX.Y.Z (${release.length} characters)`);
  }
  return { main, release, tags };
}

export function main(argv: string[]): number {
  const opts: Record<string, string> = {};
  let json = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--json') { json = true; continue; }
    if (!['--root', '--ref', '--repo', '--max-minor', '--main', '--release', '--tag'].includes(a)) {
      console.error(`release-lag: unknown argument ${quoted(a)}`);
      return 2;
    }
    const v = argv[++i];
    if (v === undefined || v.startsWith('-')) { console.error(`release-lag: ${a} needs a value that does not start with '-'`); return 2; }
    if (a in opts) { console.error(`release-lag: ${a} given twice`); return 2; }
    opts[a] = v;
  }
  const live = '--root' in opts;
  const given = '--main' in opts || '--release' in opts || '--tag' in opts;
  if (live === given || (given && !('--main' in opts && '--release' in opts)) || (!live && ('--ref' in opts || '--repo' in opts))) {
    console.error('release-lag: pass --root <hatsu> [--ref <ref>] [--repo <repo>], or --main X.Y.Z --release vX.Y.Z|none [--tag vX.Y.Z]');
    return 2;
  }
  if ('--repo' in opts && !/^(?:[A-Za-z0-9.-]+\/)?[A-Za-z0-9_-][A-Za-z0-9_.-]*\/[A-Za-z0-9_-][A-Za-z0-9_.-]*$/.test(opts['--repo'])) {
    console.error(`release-lag: --repo ${quoted(opts['--repo'])} is not [HOST/]OWNER/NAME`);
    return 2;
  }
  const maxText = opts['--max-minor'] ?? DECLARED_MAX_MINOR;
  if (!/^(0|[1-9]\d{0,2})$/.test(maxText)) { console.error(`release-lag: --max-minor ${quoted(maxText)} is not a whole number below 1000`); return 2; }
  try {
    let values: { main: string; release: string | null; tags: string[] };
    if (live) {
      const root = opts['--root'];
      try {
        if (!statSync(root).isDirectory()) throw new Error();
      } catch {
        throw new Error(`--root ${quoted(root)} is not a directory`);
      }
      values = readLive(root, opts['--ref'] ?? 'origin/main', opts['--repo']);
    } else {
      const tag = opts['--tag'];
      if (tag !== undefined && !(tag.startsWith('v') && parseVersion(tag))) throw new Error(`tag ${quoted(tag)} is not vX.Y.Z`);
      values = { main: opts['--main'], release: opts['--release'] === 'none' ? null : opts['--release'], tags: tag === undefined ? [] : [tag] };
    }
    const verdict = judge(values.main, values.release, values.tags, Number(maxText));
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
