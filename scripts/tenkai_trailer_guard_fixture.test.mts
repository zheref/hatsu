import { test, expect } from 'vitest';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync, copyFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const source = resolve(import.meta.dirname, '..');
const relative = '.github/workflows/forbidden-commit-trailers.yml';
const template = readFileSync(join(source, 'templates/forbidden-commit-trailers.yml'), 'utf8');
const pin = '16ff11b07b69305cf6a420972ca3d3926b44be67';
// Download stubs use exact published bytes, independently of mutable local code
// and the checkout's Git depth. The publisher still verifies this digest.
const helper = { stdout: readFileSync(join(source, 'scripts/fixtures/consumer-trailers/published-reader-v0.142.0.sh'), 'utf8') };
function temp() { return mkdtempSync(join(tmpdir(), 'hatsu-trailers-')); }
function run(repo: string, mode = 'diagnose') {
  const result = spawnSync(process.execPath, [join(source, 'scripts/tenkai_trailer_guard.mts'), mode, repo, source], { encoding: 'utf8' });
  expect(result.status, result.stderr).toBe(0);
  return JSON.parse(result.stdout) as { state: string; detail: string };
}
function policy(repo: string, keys: unknown = ['Co-Authored-By']) {
  mkdirSync(join(repo, 'nen'), { recursive: true });
  writeFileSync(join(repo, 'nen/workflow.json'), JSON.stringify({ commits: { forbiddenTrailers: keys } }));
}
function git(repo: string, ...args: string[]) {
  const result = spawnSync('git', ['-C', repo, ...args], { encoding: 'utf8', env: { ...process.env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' } });
  expect(result.status, result.stderr).toBe(0);
  return result.stdout.trim();
}
function init(repo: string) {
  mkdirSync(repo, { recursive: true });
  git(repo, 'init', '-q'); git(repo, 'config', 'user.name', 'Fixture'); git(repo, 'config', 'user.email', 'fixture@example.test');
}
function commit(repo: string, message: string) {
  git(repo, 'add', '.'); git(repo, 'commit', '--allow-empty', '-q', '-m', message);
  return git(repo, 'rev-parse', 'HEAD');
}
const yaml = spawnSync('ruby', ['-rpsych', '-rjson', '-e', 'puts Psych.load_file(ARGV[0]).to_json', join(source, 'templates/forbidden-commit-trailers.yml')], { encoding: 'utf8' });
expect(yaml.status, yaml.stderr).toBe(0);
const document = JSON.parse(yaml.stdout);
const job = document.jobs['trailer-policy-runner'];
const publisher = readFileSync(join(source, 'scripts/consumer_trailer_ci.mts'), 'utf8');
const check = job.steps.at(-1).run as string;

test('offline reader bytes match the immutable published artifact', () => {
  expect(createHash('sha256').update(helper.stdout).digest('hex')).toBe('d7cbb1dd4c6d8d5ff472b96922c5f5d3eda7fdcd69ea8e485becbfe8629e0da8');
});

test('workflow has one read-only job, exact base/head data, immutable verified reader and no PR code execution', () => {
  expect(Object.keys(document.on ?? document.true)).toEqual(['pull_request_target']);
  expect((document.on ?? document.true).pull_request_target.types).toEqual(['opened', 'synchronize', 'reopened', 'ready_for_review', 'edited']);
  expect(document.permissions).toEqual({ contents: 'read', checks: 'write' });
  expect(Object.keys(document.jobs)).toEqual(['trailer-policy-runner']);
  expect(job['runs-on']).toBe('ubuntu-latest');
  expect(job.steps[0].with).toMatchObject({ ref: '${{ github.event.pull_request.base.sha }}', path: '.base', 'persist-credentials': false, 'fetch-depth': 0 });
  expect(job.steps).toHaveLength(3);
  expect(template).not.toContain('allow-unsafe-pr-checkout');
  expect(template).not.toContain('path: .pr');
  expect(check).toBe('node .base/scripts/consumer_trailer_ci.mts "$PWD"');
  expect(publisher).toContain(`const PIN = '${pin}'`);
  expect(publisher).toContain('d7cbb1dd4c6d8d5ff472b96922c5f5d3eda7fdcd69ea8e485becbfe8629e0da8');
  expect(publisher).toContain("'show', 'HEAD:nen/workflow.json'");
  expect(publisher).toContain("'--forbidden-only', '--forbid-trailers-from'");
  expect(publisher).toContain('::stop-commands::');
  expect(publisher).toContain("check.app?.slug !== 'github-actions'");
  expect(publisher).toContain('check.external_id !== external');
  expect(publisher).toContain('check.head_sha !== head');

});

test('adoption renders, detects drift, repairs and stays idempotent; preserves foreign files and refuses links', () => {
  const repo = temp();
  try {
    policy(repo);
    expect(run(repo).state).toBe('missing');
    expect(run(repo, 'apply').state).toBe('repaired');
    expect(readFileSync(join(repo, relative), 'utf8')).toBe(template);
    expect(run(repo, 'apply').state).toBe('satisfied');
    writeFileSync(join(repo, relative), template + '# stale\n');
    expect(run(repo).state).toBe('drift');
    expect(run(repo, 'apply').state).toBe('repaired');
    writeFileSync(join(repo, relative), 'foreign\n');
    expect(run(repo, 'apply').state).toBe('blocked');
    expect(readFileSync(join(repo, relative), 'utf8')).toBe('foreign\n');
    rmSync(join(repo, relative)); symlinkSync(join(source, 'templates/forbidden-commit-trailers.yml'), join(repo, relative));
    expect(run(repo, 'apply').state).toBe('blocked');
    rmSync(join(repo, '.github'), { recursive: true });
    symlinkSync(join(source, 'templates'), join(repo, '.github'));
    expect(run(repo, 'apply').state).toBe('blocked');
  } finally { rmSync(repo, { recursive: true, force: true }); }
});

test.each([[], null, 'Co-Authored-By', ['Bad:Key'], [3], ['$(touch owned)']])('invalid policy is blocked: %j', keys => {
  const repo = temp();
  try { policy(repo, keys); expect(run(repo, 'apply').state).toBe('blocked'); }
  finally { rmSync(repo, { recursive: true, force: true }); }
});

test('actual consumer validator admission gates the write, including a misleading comment', () => {
  const repo = temp();
  try {
    policy(repo); mkdirSync(join(repo, 'scripts'));
    const guard = join(repo, 'scripts/workflow_runner_policy_check.rb');
    writeFileSync(guard, '# forbidden-commit-trailers.yml is mentioned but refused\nexit 1\n');
    expect(run(repo, 'apply').state).toBe('staged');
    writeFileSync(guard, 'exit File.read(File.join(ARGV.fetch(0), ".github/workflows/forbidden-commit-trailers.yml")).include?("contents: read") ? 0 : 1\n');
    expect(run(repo, 'apply').state).toBe('repaired');
    copyFileSync(join(source, 'scripts/workflow_runner_policy_check.rb'), guard);
    expect(run(repo).state).toBe('staged');
  } finally { rmSync(repo, { recursive: true, force: true }); }
});

// Run the actual rendered shell, with curl supplying the real published helper
// bytes offline. No alternate implementation of the range reader is tested.
function exercise(message: string, options: { corrupt?: boolean; baseKeys?: unknown; symlinkPolicy?: boolean; merge?: boolean; advanceBase?: boolean; producer?: string; wrongHead?: boolean; wrongExternal?: boolean; wrongId?: boolean; failPatch?: boolean; retarget?: boolean } = {}) {
  const root = temp();
  try {
    const base = join(root, '.base'); const pr = join(root, '.pr'); const bin = join(root, 'bin'); const runner = join(root, 'runner');
    init(base); mkdirSync(join(base, 'scripts')); writeFileSync(join(base, 'scripts/consumer_trailer_ci.mts'), publisher); policy(base, options.baseKeys ?? ['Co-Authored-By', 'Reviewed-By']);
    if (options.symlinkPolicy) { rmSync(join(base, 'nen/workflow.json')); symlinkSync('/dev/null', join(base, 'nen/workflow.json')); }
    let sha = commit(base, 'base');
    let destination: string | undefined;
    if (options.retarget) {
      policy(base, ['Co-Authored-By']);
      destination = commit(base, 'destination base forbids attribution');
    }
    git(root, 'clone', '-q', base, pr); git(pr, 'config', 'user.name', 'Fixture'); git(pr, 'config', 'user.email', 'fixture@example.test');
    // Head policy and helper cannot waive the base's keys or execute code.
    policy(pr, ['Unrelated']);
    writeFileSync(join(pr, 'scripts/consumer_trailer_ci.mts'), 'touch PR_CODE_EXECUTED\n');
    writeFileSync(join(pr, 'scripts/branch_authorship_check.sh'), 'touch "$RUNNER_TEMP/PR_CODE_EXECUTED"\nexit 0\n');
    let bad: string;
    if (options.merge) {
      git(pr, 'checkout', '-q', '-b', 'side'); writeFileSync(join(pr, 'side'), 'side'); bad = commit(pr, message);
      git(pr, 'checkout', '-q', '-'); writeFileSync(join(pr, 'main-side'), 'main'); commit(pr, 'clean parallel commit');
      git(pr, 'merge', '--no-ff', '-m', 'clean merge', 'side');
    } else { bad = commit(pr, message); }
    commit(pr, 'clean final commit');
    if (options.advanceBase) { writeFileSync(join(base, 'base-only'), 'new base'); sha = commit(base, 'advance base after fork'); }
    mkdirSync(bin); mkdirSync(runner);
    const published = join(root, 'published.sh'); writeFileSync(published, options.corrupt ? 'exit 0\n' : helper.stdout);
    writeFileSync(join(bin, 'curl'), '#!/bin/sh\nwhile [ "$#" -gt 0 ]; do if [ "$1" = -o ]; then cp "$PUBLISHED_HELPER" "$2"; exit; fi; shift; done\nexit 2\n', { mode: 0o755 });
    const log = join(root, 'api.jsonl');
    const realGit = spawnSync('which', ['git'], { encoding: 'utf8' }).stdout.trim();
    // The production publisher fetches only a fixed GitHub URL's numeric PR ref
    // into a bare store. Replace that remote with fixture Git objects offline.
    writeFileSync(join(bin, 'git'), `#!/usr/bin/env node
const { spawnSync } = require('node:child_process');
const args = process.argv.slice(2);
const remote = args.indexOf('https://github.com/acme/widget.git');
if (remote !== -1) {
  if (process.env.GH_TOKEN || process.env.GITHUB_TOKEN || !process.env.GIT_CONFIG_VALUE_0?.startsWith('AUTHORIZATION: basic ')) process.exit(98);
  if (!args.includes('refs/pull/7/head:refs/heads/pr')) process.exit(97);
  args[remote] = process.env.GIT_FIXTURE_PR;
  args[args.indexOf('refs/pull/7/head:refs/heads/pr')] = 'HEAD:refs/heads/pr';
} else if (process.env.GH_TOKEN || process.env.GITHUB_TOKEN || process.env.GIT_CONFIG_VALUE_0) process.exit(96);
const result = spawnSync(process.env.REAL_GIT, args, { stdio: 'inherit', env: process.env });
process.exit(result.status ?? 99);
`, { mode: 0o755 });
    writeFileSync(join(bin, 'gh'), `#!/usr/bin/env node
const fs = require('node:fs');
const body = JSON.parse(fs.readFileSync(0, 'utf8'));
const post = process.argv.includes('POST');
const state = process.env.API_LOG + '.state';
fs.appendFileSync(process.env.API_LOG, JSON.stringify({ args: process.argv.slice(2), body, token: process.env.GH_TOKEN }) + '\\n');
if (!post && process.env.FAIL_PATCH === 'yes') process.exit(1);
const result = post ? { ...body, id: 17, app: { slug: process.env.PRODUCER || 'github-actions' } } : { ...JSON.parse(fs.readFileSync(state)), ...body };
if (process.env.WRONG_HEAD === 'yes') result.head_sha = '0'.repeat(40);
if (process.env.WRONG_EXTERNAL === 'yes') result.external_id = 'another workflow';
if (!post && process.env.WRONG_ID === 'yes') result.id = 99;
fs.writeFileSync(state, JSON.stringify(result));
process.stdout.write(JSON.stringify(result));
`, { mode: 0o755 });
    const head = git(pr, 'rev-parse', 'HEAD');
    const invoke = (baseSha: string, attempt = '1') => spawnSync('bash', ['-c', check], { cwd: root, encoding: 'utf8', env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, BASE_SHA: baseSha, RUNNER_TEMP: runner, PUBLISHED_HELPER: published, PR_NUMBER: '7', REAL_GIT: realGit, GIT_FIXTURE_PR: pr, GH_TOKEN: 'trusted-test-token', GITHUB_TOKEN: '', HEAD_SHA: head, GITHUB_REPOSITORY: 'acme/widget', GITHUB_RUN_ID: '123', GITHUB_RUN_ATTEMPT: attempt, GITHUB_WORKFLOW_REF: 'acme/widget/.github/workflows/forbidden-commit-trailers.yml@refs/heads/main', API_LOG: log, PRODUCER: options.producer ?? '', WRONG_HEAD: options.wrongHead ? 'yes' : '', WRONG_EXTERNAL: options.wrongExternal ? 'yes' : '', WRONG_ID: options.wrongId ? 'yes' : '', FAIL_PATCH: options.failPatch ? 'yes' : '' } });
    // Both bases are already ancestors of this exact head. Retargeting must
    // rescan it against the destination policy rather than retain old success.
    if (destination) {
      git(pr, 'merge-base', '--is-ancestor', sha, head);
      git(pr, 'merge-base', '--is-ancestor', destination, head);
      git(base, 'checkout', '-q', '--detach', sha);
    }
    const result = invoke(sha);
    let retarget: { status: number | null; text: string } | undefined;
    if (destination) {
      git(base, 'checkout', '-q', '--detach', destination);
      const rescanned = invoke(destination, '2');
      retarget = { status: rescanned.status, text: rescanned.stdout + rescanned.stderr };
    }
    expect(spawnSync('test', ['-e', join(runner, 'PR_CODE_EXECUTED')]).status).toBe(1);
    expect(spawnSync('test', ['-e', join(runner, 'COMMIT_EXECUTED')]).status).toBe(1);
    return { status: result.status, text: result.stdout + result.stderr, bad, retarget, calls: readFileSync(log, 'utf8').trim().split('\n').map(line => JSON.parse(line)), head };
  } finally { rmSync(root, { recursive: true, force: true }); }
}

test.each(['bad\n\nCo-Authored-By: assistant', 'bad\n\n  cO-aUtHoReD-bY : assistant\n\nlater prose', 'bad\n\nReviewed-By: reviewer'])('rendered job rejects an earlier forbidden commit despite clean final commit: %s', message => {
  const result = exercise(message);
  expect(result.status, result.text).toBe(1);
  expect(result.text).toContain(result.bad.slice(0, 7));
  expect(result.text).toContain('forbidden trailer');
});
test('all PR commits includes side history carried by a merge', () => {
  const result = exercise('bad side\n\nCo-Authored-By: assistant', { merge: true });
  expect(result.status, result.text).toBe(1); expect(result.text).toContain(result.bad.slice(0, 7));
});
test('clean range passes without head provenance policy', () => {
  const result = exercise('clean\n\nHatsu-Agent: kurapika'); expect(result.status, result.text).toBe(0);
});
test('digest mismatch refuses to execute the fetched reader', () => {
  const result = exercise('clean', { corrupt: true }); expect(result.status, result.text).not.toBe(0); expect(result.text).toContain('digest mismatch');
});
test('stored base symlink and malformed base policy fail closed', () => {
  expect(exercise('clean', { symlinkPolicy: true }).status).not.toBe(0);
  expect(exercise('clean', { baseKeys: [] }).status).not.toBe(0);
});

test('consumer custom keys and hostile values are data', () => {
  const custom = exercise('custom\n\nConsumer-Key: value', { baseKeys: ['Consumer-Key'] });
  expect(custom.status, custom.text).toBe(1);
  const hostile = exercise('::error::untrusted\n\nCo-Authored-By: $(touch "$RUNNER_TEMP/COMMIT_EXECUTED")');
  expect(hostile.status, hostile.text).toBe(1);
});
test('fork history missing the current base obtains that exact object from the trusted checkout', () => {
  const result = exercise('clean', { advanceBase: true }); expect(result.status, result.text).toBe(0);
});

test('Tenkai apply relays the trailer item and renders a real consumer workflow', () => {
  const repo = temp();
  try {
    init(repo); policy(repo);
    git(repo, 'remote', 'add', 'origin', 'https://github.com/acme/widget.git');
    writeFileSync(join(repo, 'nen/repos.json'), JSON.stringify({ consumers: [{ repo: 'acme/widget' }] }));
    const adopt = () => {
      const result = spawnSync('bash', [join(source, 'scripts/tenkai_adopt.sh'), 'apply', '--repo', repo, '--slug', 'acme/widget', '--visibility', 'public', '--self-hosted', '0', '--json'], { encoding: 'utf8', timeout: 30_000 });
      expect([0, 1], result.stderr).toContain(result.status);
      return JSON.parse(result.stdout).items.find((item: { id: string }) => item.id === relative);
    };
    expect(adopt().state).toBe('repaired');
    expect(readFileSync(join(repo, relative), 'utf8')).toBe(template);
    expect(adopt().state).toBe('satisfied');
  } finally { rmSync(repo, { recursive: true, force: true }); }
});

test('published check is bound to the exact head, GitHub Actions producer and this workflow run', () => {
  const result = exercise('clean');
  expect(result.status, result.text).toBe(0);
  expect(result.calls).toHaveLength(2);
  expect(result.calls[0].body).toMatchObject({ name: 'forbidden-commit-trailers', head_sha: result.head, status: 'in_progress', external_id: 'acme/widget/.github/workflows/forbidden-commit-trailers.yml@refs/heads/main:123:1' });
  expect(result.calls[1].args).toContain('repos/acme/widget/check-runs/17');
  expect(result.calls[1].body).toMatchObject({ status: 'completed', conclusion: 'success' });
  const forbidden = exercise('bad\n\nCo-Authored-By: assistant');
  expect(forbidden.calls[1].body.conclusion).toBe('failure');
});
test.each([{ producer: 'other-app' }, { wrongHead: true }, { wrongExternal: true }, { wrongId: true }, { failPatch: true }])('wrong producer, head, run identity or publication failure is never a successful job: %j', options => {
  const result = exercise('clean', options); expect(result.status, result.text).not.toBe(0);
});


test('retargeting the unchanged head rescans against a destination base with stricter trailer policy', () => {
  const result = exercise('previously accepted\n\nCo-Authored-By: assistant', { baseKeys: ['Unrelated'], retarget: true });
  expect(result.status, result.text).toBe(0);
  expect(result.retarget?.status, result.retarget?.text).toBe(1);
  expect(result.retarget?.text).toContain('forbidden trailer co-authored-by');
  expect(result.calls).toHaveLength(4);
  expect(result.calls[0].body.head_sha).toBe(result.head);
  expect(result.calls[2].body.head_sha).toBe(result.head);
  expect(result.calls[1].body.conclusion).toBe('success');
  expect(result.calls[3].body.conclusion).toBe('failure');
});
