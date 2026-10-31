#!/usr/bin/env node
// release_lag_check_fixture.mts — the cases scripts/release_lag_check.mts owes (zheref/hatsu#533).
// Hermetic and offline: the given form over every verdict, every refusal at exit 2 with stdout empty,
// and the live form over a throwaway origin (a bare repository on disk) with a stubbed `gh` first on
// PATH, so no read reaches GitHub. Needs node, git and a POSIX shell.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scripts = dirname(fileURLToPath(import.meta.url));
const script = join(scripts, 'release_lag_check.mts');
const scratch = realpathSync(mkdtempSync(join(tmpdir(), 'release-lag-')));
type Run = { status: number | null; stdout: string; stderr: string };
const run = (args: string[], env: NodeJS.ProcessEnv = process.env): Run =>
  spawnSync(process.execPath, [script, ...args], { encoding: 'utf8', env }) as Run;
const git = (cwd: string, ...args: string[]): void => {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8', env: { ...process.env, GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_SYSTEM: '/dev/null' } });
  assert.equal(r.status, 0, `git ${args.join(' ')}: ${r.stderr}`);
};
const given = (main: string, release: string, ...more: string[]): Run => run(['--main', main, '--release', release, ...more]);

try {
  // --- the given form: each verdict and its exit ---
  {
    const r = given('0.152.0', 'v0.152.0');
    assert.equal(r.status, 0, r.stderr);
    assert.equal(r.stdout, 'release-lag: main 0.152.0, latest release v0.152.0: in step\n');
    console.log('ok    in step: exit 0');
  }
  {
    const r = given('0.152.3', 'v0.152.0');
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /a patch behind, within the cadence \(rides the next cut\)$/m);
    console.log('ok    a patch behind: within the cadence, exit 0');
  }
  {
    const r = given('0.153.1', 'v0.152.0');
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /: 1 minor behind, within the cadence of 1 \(rides the next cut\)$/m);
    console.log('ok    one minor behind: within the default cadence, exit 0');
  }
  {
    const r = given('0.154.1', 'v0.152.0');
    assert.equal(r.status, 1, r.stderr);
    assert.equal(r.stdout, "release-lag: main 0.154.1, latest release v0.152.0: 2 minors behind, a cut is owed (more than 1, docs/WORKFLOW.md § 4, the release cadence; the cut is the maintainer's call)\n");
    console.log("ok    the issue's own case, 0.154.1 over v0.152.0: a cut is owed, exit 1");
  }
  {
    const r = given('0.154.1', 'v0.152.0', '--max-minor', '2');
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /2 minors behind, within the cadence of 2/);
    const z = given('0.152.1', 'v0.151.9', '--max-minor', '0');
    assert.equal(z.status, 1, z.stderr);
    console.log('ok    --max-minor widens and narrows the cadence (2 admits two minors, 0 refuses one)');
  }
  {
    const r = given('1.0.0', 'v0.152.0');
    assert.equal(r.status, 1, r.stderr);
    assert.match(r.stdout, /a major behind, a cut is owed/);
    console.log('ok    a major behind: a cut is owed, exit 1');
  }
  {
    const r = given('0.155.0', 'none');
    assert.equal(r.status, 1, r.stderr);
    assert.match(r.stdout, /main 0\.155\.0, no published release: a cut is owed/);
    console.log('ok    no published release: a cut is owed, exit 1');
  }
  {
    const r = given('0.152.0', 'v0.153.0');
    assert.equal(r.status, 1, r.stderr);
    assert.match(r.stdout, /latest release v0\.153\.0 is ahead of main 0\.152\.0/);
    console.log('ok    a release ahead of main: refused by name, exit 1');
  }
  {
    const r = given('0.155.0', 'v0.152.0', '--tag', 'v0.154.0');
    assert.equal(r.status, 1, r.stderr);
    assert.match(r.stdout, /; newest tag v0\.154\.0 is cut but unpublished \(publication owed, G3\)$/m);
    const s = given('0.152.0', 'v0.152.0', '--tag', 'v0.152.0');
    assert.doesNotMatch(s.stdout, /unpublished/);
    const ahead = given('0.152.0', 'v0.152.0', '--tag', 'v0.160.0');
    assert.doesNotMatch(ahead.stdout, /unpublished/, 'a tag above main is not a cut of main');
    const within = given('0.153.0', 'v0.152.0', '--tag', 'v0.153.0');
    assert.equal(within.status, 0, 'the unpublished tag never changes the exit');
    assert.match(within.stdout, /within the cadence.*newest tag v0\.153\.0 is cut but unpublished/);
    console.log('ok    an unpublished tag is named beside the verdict, never changing the exit');
  }
  {
    const r = given('0.155.0', 'v0.152.0', '--json');
    assert.equal(r.status, 1);
    const j = JSON.parse(r.stdout);
    assert.equal(j.state, 'cut-owed');
    assert.equal(j.minorsBehind, 3);
    assert.equal(j.maxMinor, 1);
    assert.equal(j.release, 'v0.152.0');
    assert.equal(j.unpublishedTag, null);
    assert.match(j.line, /^release-lag: /);
    console.log('ok    --json: one document carrying state, minorsBehind, maxMinor and the line');
  }

  // --- refusals: exit 2, stdout empty ---
  {
    const cases: Array<[string, string[]]> = [
      ['no arguments', []],
      ['both forms', ['--root', scratch, '--main', '0.1.0', '--release', 'v0.1.0']],
      ['--main without --release', ['--main', '0.1.0']],
      ['--tag alone', ['--tag', 'v0.1.0']],
      ['--ref without --root', ['--main', '0.1.0', '--release', 'v0.1.0', '--ref', 'main']],
      ['an unknown flag', ['--main', '0.1.0', '--release', 'v0.1.0', '--force']],
      ['a flag without its value', ['--main', '0.1.0', '--release']],
      ['a flag given twice', ['--main', '0.1.0', '--main', '0.2.0', '--release', 'v0.1.0']],
      ['main spelled with a v', ['--main', 'v0.1.0', '--release', 'v0.1.0']],
      ['a release without its v', ['--main', '0.1.0', '--release', '0.1.0']],
      ['a two-part version', ['--main', '0.1', '--release', 'v0.1.0']],
      ['a leading zero', ['--main', '0.01.0', '--release', 'v0.1.0']],
      ['a prerelease suffix', ['--main', '0.1.0', '--release', 'v0.1.0-rc.1']],
      ['a malformed tag', ['--main', '0.1.0', '--release', 'v0.1.0', '--tag', 'latest']],
      ['a negative cadence', ['--main', '0.1.0', '--release', 'v0.1.0', '--max-minor', '-1']],
      ['a fractional cadence', ['--main', '0.1.0', '--release', 'v0.1.0', '--max-minor', '1.5']],
      ['a missing root', ['--root', join(scratch, 'absent')]],
    ];
    for (const [label, args] of cases) {
      const r = run(args);
      assert.equal(r.status, 2, `${label}: ${r.stdout}${r.stderr}`);
      assert.equal(r.stdout, '', `${label}: stdout stays empty`);
      assert.match(r.stderr, /^release-lag: /, `${label}: the refusal is named`);
    }
    console.log(`ok    ${cases.length} refusals: exit 2, stdout empty, the refusal named on stderr`);
  }

  // --- the live form over a throwaway origin and a stubbed gh ---
  {
    const origin = join(scratch, 'origin.git');
    const work = join(scratch, 'work');
    const bin = join(scratch, 'bin');
    mkdirSync(work);
    mkdirSync(bin);
    git(scratch, 'init', '-q', '--bare', origin);
    git(work, 'init', '-q', '-b', 'main');
    git(work, 'config', 'user.email', 'fixture@example.invalid');
    git(work, 'config', 'user.name', 'fixture');
    mkdirSync(join(work, '.claude-plugin'));
    const commit = (version: string): void => {
      writeFileSync(join(work, '.claude-plugin/plugin.json'), JSON.stringify({ name: 'hatsu', version }) + '\n');
      git(work, 'add', '.');
      git(work, 'commit', '-q', '-m', `chore: ${version}`);
    };
    commit('0.152.0');
    git(work, 'tag', 'v0.152.0');
    commit('0.153.0');
    git(work, 'tag', 'v0.153.0');
    git(work, 'tag', 'not-a-version');
    commit('0.155.0');
    git(work, 'remote', 'add', 'origin', origin);
    git(work, 'push', '-q', 'origin', 'main', '--tags');
    git(work, 'fetch', '-q', 'origin');
    // The working tree moves on; the guard reads <ref>, never the working file.
    writeFileSync(join(work, '.claude-plugin/plugin.json'), JSON.stringify({ name: 'hatsu', version: '9.9.9' }) + '\n');
    const gh = join(bin, 'gh');
    const env = (mode: string): NodeJS.ProcessEnv => ({ ...process.env, PATH: bin + delimiter + (process.env.PATH ?? ''), GH_STUB: mode });
    writeFileSync(gh, [
      '#!/bin/sh',
      '[ "$1 $2 $3 $4 $5 $6" = "release view --json tagName --jq .tagName" ] || { echo "stub gh: unexpected $*" >&2; exit 9; }',
      'case "$GH_STUB" in',
      '  latest) echo v0.152.0 ;;',
      '  none) echo "release not found" >&2; exit 1 ;;',
      '  down) echo "HTTP 502" >&2; exit 1 ;;',
      'esac',
      '',
    ].join('\n'));
    chmodSync(gh, 0o755);

    const r = run(['--root', work], env('latest'));
    assert.equal(r.status, 1, r.stderr);
    assert.match(r.stdout, /^release-lag: main 0\.155\.0, latest release v0\.152\.0: 3 minors behind, a cut is owed/);
    assert.match(r.stdout, /; newest tag v0\.153\.0 is cut but unpublished \(publication owed, G3\)$/m);
    console.log('ok    live: main read at origin/main (not the working file), the release from gh, the newest vX.Y.Z tag from origin');

    const ref = run(['--root', work, '--ref', 'v0.153.0'], env('latest'));
    assert.equal(ref.status, 0, ref.stderr);
    assert.match(ref.stdout, /main 0\.153\.0, latest release v0\.152\.0: 1 minor behind, within the cadence/);
    console.log('ok    live --ref: the version is read at the named ref');

    const none = run(['--root', work], env('none'));
    assert.equal(none.status, 1, none.stderr);
    assert.match(none.stdout, /no published release: a cut is owed/);
    console.log('ok    live: gh\'s "release not found" reads as no published release, exit 1');

    const down = run(['--root', work], env('down'));
    assert.equal(down.status, 2);
    assert.equal(down.stdout, '');
    assert.match(down.stderr, /gh release view failed: HTTP 502/);
    const badRef = run(['--root', work, '--ref', 'origin/absent'], env('latest'));
    assert.equal(badRef.status, 2);
    assert.equal(badRef.stdout, '');
    git(work, 'remote', 'set-url', 'origin', join(scratch, 'gone.git'));
    const gone = run(['--root', work], env('latest'));
    assert.equal(gone.status, 2);
    assert.equal(gone.stdout, '');
    assert.match(gone.stderr, /git ls-remote --tags origin failed/);
    console.log('ok    live: a gh failure, an unreadable ref and an unreachable origin exit 2 with stdout empty');
  }
  console.log('release-lag-guard: every case passed');
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
