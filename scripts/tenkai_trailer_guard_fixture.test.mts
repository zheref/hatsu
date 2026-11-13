import { test, expect } from 'vitest';
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync, copyFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { assertRequiredJobContexts } from './tenkai_required_job_contexts.mts';

const source = resolve(import.meta.dirname, '..');
const relative = '.github/workflows/forbidden-commit-trailers.yml';
const template = readFileSync(join(source, 'templates/forbidden-commit-trailers.yml'), 'utf8');
const pin = '16ff11b07b69305cf6a420972ca3d3926b44be67';
// Download stubs use exact published bytes, independently of mutable local code
// and the checkout's Git depth. The publisher still verifies this digest.
const helper = { stdout: readFileSync(join(source, 'scripts/fixtures/consumer-trailers/published-reader-v0.142.0.sh'), 'utf8') };
function temp() { return mkdtempSync(join(tmpdir(), 'hatsu-trailers-')); }
function run(repo: string, mode = 'diagnose', root = source) {
  const result = spawnSync(process.execPath, [join(source, 'scripts/tenkai_trailer_guard.mts'), mode, repo, root], { encoding: 'utf8' });
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
const job = document.jobs['forbidden-commit-trailers'];
const publisherSource = join(source, 'scripts/consumer_trailer_ci.mts');
const publisher = readFileSync(publisherSource, 'utf8');
const check = job.steps.at(-1).run as string;

test('offline reader bytes match the immutable published artifact', () => {
  expect(createHash('sha256').update(helper.stdout).digest('hex')).toBe('d7cbb1dd4c6d8d5ff472b96922c5f5d3eda7fdcd69ea8e485becbfe8629e0da8');
});

test('workflow has one read-only job, exact base/head data, immutable verified reader and no PR code execution', () => {
  expect(Object.keys(document.on ?? document.true)).toEqual(['pull_request_target']);
  expect((document.on ?? document.true).pull_request_target.types).toEqual(['opened', 'synchronize', 'reopened', 'ready_for_review', 'edited']);
  expect(document.permissions).toEqual({ contents: 'read', checks: 'write' });
  expect(Object.keys(document.jobs)).toEqual(['forbidden-commit-trailers']);
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

test.each([
  ['a mismatched job name', template.replace('  forbidden-commit-trailers:', '  trailer-policy-runner:'), 'must equal one static workflow job name'],
  ['an empty job', 'jobs:\n  forbidden-commit-trailers: {}\n', 'needs a runner and executable workflow steps'],
  ['a runner without steps', 'jobs:\n  forbidden-commit-trailers:\n    runs-on: ubuntu-latest\n', 'needs a runner and executable workflow steps'],
])('adoption refuses a trailer template with %s', (_case, workflow, reason) => {
  const repo = temp();
  const root = temp();
  try {
    policy(repo);
    for (const directory of ['templates', 'scripts', 'contracts']) mkdirSync(join(root, directory));
    for (const path of ['scripts/consumer_trailer_ci.mts', 'contracts/required-job-contexts.json']) {
      copyFileSync(join(source, path), join(root, path));
    }
    writeFileSync(join(root, 'templates/forbidden-commit-trailers.yml'),
      workflow.startsWith('#') ? workflow : template.split('jobs:')[0] + workflow);
    expect(run(repo, 'apply', root)).toMatchObject({
      state: 'blocked',
      detail: relative + ': required context "forbidden-commit-trailers" ' + reason,
    });
    expect(existsSync(join(repo, relative))).toBe(false);
  } finally {
    rmSync(repo, { recursive: true, force: true });
    rmSync(root, { recursive: true, force: true });
  }
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
function exercise(message: string, options: { corrupt?: boolean; baseKeys?: unknown; symlinkPolicy?: boolean; merge?: boolean; advanceBase?: boolean; producer?: string; wrongHead?: boolean; wrongExternal?: boolean; wrongName?: boolean; badId?: unknown; wrongId?: boolean; failPatch?: boolean; retarget?: boolean; wrongDetails?: string } = {}) {
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
    // The ordinary fixture executes the copied trusted checkout. During native
    // coverage, verify those exact bytes and execute their repository path so
    // LCOV identifies the production source, independent of the fixture's path.
    if (process.env.HATSU_CLI_COVERAGE_COMMAND) {
      writeFileSync(join(bin, 'node'), `#!/bin/sh
if [ "$1" = .base/scripts/consumer_trailer_ci.mts ]; then
  cmp -s "$1" "$HATSU_FIXTURE_PUBLISHER" || exit 97
  shift
  set -- "$HATSU_FIXTURE_PUBLISHER" "$@"
fi
exec "$HATSU_FIXTURE_NODE" "$@"
`, { mode: 0o755 });
    }
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
const result = post ? { ...body, id: process.env.BAD_ID ? JSON.parse(process.env.BAD_ID) : 17, app: { slug: process.env.PRODUCER || 'github-actions' } } : { ...JSON.parse(fs.readFileSync(state)), ...body };
// GitHub replaces a github-actions check's details_url with its own run page (HA#562).
result.details_url = 'https://github.com/acme/widget/runs/' + result.id;
if (process.env.WRONG_HEAD === 'yes') result.head_sha = '0'.repeat(40);
if (process.env.WRONG_EXTERNAL === 'yes') result.external_id = 'another workflow';
if (process.env.WRONG_NAME === 'yes') result.name = 'other-check';
if (!post && process.env.WRONG_ID === 'yes') result.id = 99;
// A test may replace the rewrite with any other URL to prove it is refused.
if (process.env.WRONG_DETAILS) result.details_url = process.env.WRONG_DETAILS;
fs.writeFileSync(state, JSON.stringify(result));
process.stdout.write(JSON.stringify(result));
`, { mode: 0o755 });
    const head = git(pr, 'rev-parse', 'HEAD');
    const invoke = (baseSha: string, attempt = '1') => spawnSync('bash', ['-c', check], { cwd: root, encoding: 'utf8', env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, BASE_SHA: baseSha, RUNNER_TEMP: runner, PUBLISHED_HELPER: published, HATSU_FIXTURE_PUBLISHER: publisherSource, HATSU_FIXTURE_NODE: process.execPath, PR_NUMBER: '7', REAL_GIT: realGit, GIT_FIXTURE_PR: pr, GH_TOKEN: 'trusted-test-token', GITHUB_TOKEN: '', HEAD_SHA: head, GITHUB_REPOSITORY: 'acme/widget', GITHUB_RUN_ID: '123', GITHUB_RUN_ATTEMPT: attempt, GITHUB_WORKFLOW_REF: 'acme/widget/.github/workflows/forbidden-commit-trailers.yml@refs/heads/main', API_LOG: log, PRODUCER: options.producer ?? '', WRONG_HEAD: options.wrongHead ? 'yes' : '', WRONG_EXTERNAL: options.wrongExternal ? 'yes' : '', WRONG_NAME: options.wrongName ? 'yes' : '', BAD_ID: options.badId === undefined ? '' : JSON.stringify(options.badId), WRONG_ID: options.wrongId ? 'yes' : '', FAIL_PATCH: options.failPatch ? 'yes' : '', WRONG_DETAILS: options.wrongDetails ?? '' } });
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
  expect(result.calls[1].body.output.text).toContain(result.bad.slice(0, 7));
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
  expect(hostile.calls[1].body.output.text).toMatch(/^Commits failing the base trailer policy: [0-9a-f]{7,40}$/);
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
    const readiness = '.github/workflows/pr-readiness.yml';
    const pr = '.github/workflows/pr.yml';
    writeFileSync(join(repo, pr), 'name: PR\non: pull_request\njobs:\n  shu:\n    runs-on: ubuntu-latest\n    steps: [{ run: npm test }]\n  browser:\n    name: typecheck-and-e2e\n    runs-on: ubuntu-latest\n    steps: [{ run: npm test }]\n');
    const required = {
      [relative]: ['forbidden-commit-trailers'],
      [readiness]: ['readiness'],
      [pr]: ['shu', 'typecheck-and-e2e'],
    };
    for (const [workflow, contexts] of Object.entries(required)) {
      const rendered = readFileSync(join(repo, workflow), 'utf8');
      assertRequiredJobContexts(workflow, rendered, contexts);
    }
    const rendered = readFileSync(join(repo, pr), 'utf8');
    expect(() => assertRequiredJobContexts(pr, rendered.replace('  browser:', '  "invalid job":'), required[pr]))
      .toThrow(pr + ': required context "typecheck-and-e2e"');
    expect(() => assertRequiredJobContexts(pr, rendered.replace('name: typecheck-and-e2e', 'name: browser'), required[pr]))
      .toThrow(pr + ': required context "typecheck-and-e2e"');
    expect(() => assertRequiredJobContexts(pr, rendered.replace('  shu:', '  lint:'), required[pr]))
      .toThrow(pr + ': required context "shu"');
    expect(adopt().state).toBe('satisfied');
  } finally { rmSync(repo, { recursive: true, force: true }); }
});

test.each([
  ['a missing runner', 'steps: [{ run: echo ok }]'],
  ['an empty runner', 'runs-on: []\n    steps: [{ run: echo ok }]'],
  ['a malformed runner map', 'runs-on: { group: 123 }\n    steps: [{ run: echo ok }]'],
  ['an empty steps list', 'runs-on: ubuntu-latest\n    steps: []'],
  ['a display-only step', 'runs-on: ubuntu-latest\n    steps: [{ name: Display only }]'],
  ['a blank command', 'runs-on: ubuntu-latest\n    steps: [{ run: " " }]'],
])('native context rejects %s', (_case, body) => {
  expect(() => assertRequiredJobContexts(relative, 'jobs:\n  check:\n    ' + body, ['check']))
    .toThrow(relative + ': required context "check" needs a runner and executable workflow steps');
});

test.each(['ubuntu-latest', '[self-hosted, linux]', '{ group: pool-ci, labels: linux }', '"${{ inputs.runner }}"'])(
  'native context accepts runner %s with an action-only step', runner => {
    expect(() => assertRequiredJobContexts(relative,
      'jobs:\n  check:\n    runs-on: ' + runner + '\n    steps: [{ uses: actions/checkout@v4 }]', ['check'])).not.toThrow();
  },
);

test('published check is bound to the exact head, GitHub Actions producer and this workflow run', () => {
  const result = exercise('clean');
  expect(result.status, result.text).toBe(0);
  expect(result.calls).toHaveLength(2);
  expect(result.calls[0].body).toMatchObject({ name: 'forbidden-commit-trailers verdict', head_sha: result.head, status: 'in_progress', external_id: 'acme/widget/.github/workflows/forbidden-commit-trailers.yml@refs/heads/main:123:1' });
  expect(result.calls[1].args).toContain('repos/acme/widget/check-runs/17');
  expect(result.calls[1].body).toMatchObject({ status: 'completed', conclusion: 'success' });
  const forbidden = exercise('bad\n\nCo-Authored-By: assistant');
  expect(forbidden.calls[1].body.conclusion).toBe('failure');
  expect(forbidden.calls[1].body.output.summary).toContain('https://github.com/acme/widget/actions/runs/123/attempts/1');
  expect(forbidden.calls[1].body.output.text).toMatch(new RegExp(`^Commits failing the base trailer policy: ${forbidden.bad.slice(0, 7)}[0-9a-f]*$`));
  expect(result.calls[1].body.output.text).toBeUndefined();
});
test.each([{ wrongId: true }, { failPatch: true }])('a wrong PATCH id or a failed publication is never a successful job: %j', options => {
  const result = exercise('clean', options); expect(result.status, result.text).not.toBe(0);
});
test('GitHub rewriting details_url to its own run page still identifies the check (HA#562)', () => {
  const result = exercise('clean');
  expect(result.status, result.text).toBe(0);
  expect(result.text).not.toContain('does not identify');
  expect(result.calls[0].body.details_url).toBe('https://github.com/acme/widget/actions/runs/123/attempts/1');
  expect(result.calls[1].args).toContain('repos/acme/widget/check-runs/17');
  expect(result.calls[1].body).toMatchObject({ status: 'completed', conclusion: 'success' });
});
test.each([{ producer: 'other-app' }, { wrongHead: true }, { wrongExternal: true }, { wrongName: true }])('a refused check identity still completes the created check with failure: %j', options => {
  const result = exercise('clean', options);
  expect(result.status, result.text).toBe(1);
  expect(result.text).toContain('does not identify this producer');
  expect(result.calls).toHaveLength(2);
  expect(result.calls[1].args).toContain('repos/acme/widget/check-runs/17');
  expect(result.calls[1].body).toMatchObject({ status: 'completed', conclusion: 'failure' });
});

// GitHub never echoes the details_url a GitHub Actions token requests on a check run; it answers
// with the check's own page, https://github.com/<repo>/runs/<check id>. The publisher accepts
// exactly that rewrite on the create and the completion responses, still requests the run URL,
// and still binds the producer, workflow run and attempt through external_id.
test('published check accepts the details_url GitHub rewrites to the check page', () => {
  const result = exercise('clean');
  expect(result.status, result.text).toBe(0);
  expect(result.calls).toHaveLength(2);
  expect(result.calls[0].body.details_url).toBe('https://github.com/acme/widget/actions/runs/123/attempts/1');
  expect(result.calls[1].body).toMatchObject({ status: 'completed', conclusion: 'success' });
  const forbidden = exercise('bad\n\nCo-Authored-By: assistant');
  expect(forbidden.status, forbidden.text).toBe(1);
  expect(forbidden.text).not.toContain('does not identify');
  expect(forbidden.calls[1].body.conclusion).toBe('failure');
});
test.each([
  'https://github.com/acme/widget/runs/99',
  'https://github.com/other/widget/runs/17',
  'https://github.com/acme/widget/actions/runs/123/attempts/2',
  'https://github.com/acme/widget/actions/runs/124/attempts/1',
  'http://github.com/acme/widget/runs/17',
  'https://github.com/acme/widget/runs/17/',
])('a check response with any other details_url is still refused: %s', wrongDetails => {
  const result = exercise('clean', { wrongDetails });
  expect(result.status, result.text).not.toBe(0);
  expect(result.text).toContain('does not identify');
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
test.each([null, 0, -17, '17', 17.5, 2 ** 53])('a POST response without a usable check id is refused and never PATCHed: %j', badId => {
  const result = exercise('clean', { badId });
  expect(result.status, result.text).toBe(1);
  expect(result.text).toContain('does not identify this producer');
  expect(result.calls).toHaveLength(1);
});
