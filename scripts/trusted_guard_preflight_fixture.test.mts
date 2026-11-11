import { mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { expect, test } from 'vitest';

const scripts = import.meta.dirname;
const preflight = join(scripts, 'trusted_guard_preflight.rb');
const baseRef = 'origin/preflight-fixture';

function withCheckout(extraGuards: Record<string, string>, run: (root: string) => void): void {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'hatsu-preflight runtime-')));
  function git(...args: string[]): void {
    const result = spawnSync('git', ['-C', root, ...args], { encoding: 'utf8', timeout: 5_000 });
    expect(result.error, result.stderr).toBeUndefined();
    expect(result.status, result.stderr).toBe(0);
  }
  try {
    mkdirSync(join(root, 'scripts'));
    mkdirSync(join(root, '.github', 'workflows'), { recursive: true });
    const guards = {
      'plugin_bump_api_retry.mts': readFileSync(join(scripts, 'plugin_bump_api_retry.mts'), 'utf8'),
      'prose_size_check.sh': '#!/bin/sh\nprintf "fixture prose guard ran\\n"\n',
      'readiness_ci_verdict.mts': 'throw new Error("PR-only guard must stay deferred");\n',
      'workflow_runner_policy_check.rb': 'puts "fixture policy guard ran"\n',
      ...extraGuards,
    };
    for (const [name, source] of Object.entries(guards)) {
      writeFileSync(join(root, 'scripts', name), source);
    }
    const commands = Object.keys(guards).map((name) => {
      const executable = name.endsWith('.rb') ? 'ruby' : name.endsWith('.mts') ? 'node' : 'bash';
      return `          ${executable} .trusted/scripts/${name}`;
    });
    // Duplicate workflow references still represent one derived guard.
    commands.push('          bash .trusted/scripts/prose_size_check.sh');
    writeFileSync(join(root, '.github', 'workflows', 'guards.yml'),
      `on:\n  pull_request_target: {}\njobs:\n  guards:\n    steps:\n      - run: |\n${commands.join('\n')}\n`);
    git('init', '-q');
    git('config', 'user.name', 'Hatsu fixture');
    git('config', 'user.email', 'fixture@example.invalid');
    git('add', '.');
    git('-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture trusted guards');
    git('update-ref', `refs/remotes/${baseRef}`, 'HEAD');
    run(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function invoke(root: string, ...args: string[]) {
  const result = spawnSync('ruby', [preflight, '--root', root, ...args], {
    encoding: 'utf8',
    timeout: 10_000,
    env: { ...process.env, GH_TOKEN: '', GITHUB_TOKEN: '' },
  });
  expect(result.error, result.stderr).toBeUndefined();
  return result;
}

function reportedNames(output: string): string[] {
  return [...output.matchAll(/^  ([A-Za-z0-9_.-]+): (?:exit |not run \()/gm)].map((match) => match[1]);
}

const knownGuards = [
  'plugin_bump_api_retry.mts',
  'prose_size_check.sh',
  'readiness_ci_verdict.mts',
  'workflow_runner_policy_check.rb',
];

test('preflight executes the archived API CLI offline and explicitly defers PR-only guards', () => {
  withCheckout({}, (root) => {
    // The archived revision supplies executable code even when the candidate changes it.
    writeFileSync(join(root, 'scripts', 'plugin_bump_api_retry.mts'),
      'throw new Error("candidate code must not execute");\n');
    const result = invoke(root, '--base-ref', baseRef);
    expect(result.status, result.stderr).toBe(0);
    expect(result.stdout).toContain('  plugin_bump_api_retry.mts: exit 0\n    changed files: 1\n');
    expect(result.stdout).toContain('  readiness_ci_verdict.mts: not run (');
    expect(result.stdout).toContain('every runnable trusted guard passed');
    expect(reportedNames(result.stdout)).toEqual(knownGuards);
  });
});

test('unknown adapters fail candidate checks while runtime reports every derived guard once', () => {
  withCheckout({ 'unrecognized_guard.sh': '#!/bin/sh\nexit 0\n' }, (root) => {
    const candidate = invoke(root, '--check-adapters');
    expect(candidate.status).toBe(2);
    expect(candidate.stderr).toContain('unrecognized_guard.sh: no local invocation');

    const result = invoke(root, '--base-ref', baseRef);
    expect(result.status, result.stderr).toBe(2);
    expect(result.stdout).toContain('  unrecognized_guard.sh: not run (no local invocation)\n');
    expect(result.stdout).toContain('  plugin_bump_api_retry.mts: exit 0\n');
    expect(result.stdout).toContain('  workflow_runner_policy_check.rb: exit 0\n    fixture policy guard ran\n');
    expect(reportedNames(result.stdout)).toEqual([...knownGuards, 'unrecognized_guard.sh'].sort());
    expect(result.stdout).not.toContain('every runnable trusted guard passed');
  });
});

test('a failed guard reports its exit and still runs later guards', () => {
  withCheckout({ 'prose_size_check.sh': '#!/bin/sh\nexit 7\n' }, (root) => {
    const result = invoke(root, '--base-ref', baseRef);
    expect(result.status).toBe(1);
    expect(result.stdout).toContain('  prose_size_check.sh: exit 7\n');
    expect(result.stdout).toContain('  workflow_runner_policy_check.rb: exit 0\n');
    expect(reportedNames(result.stdout)).toEqual(knownGuards);
    expect(result.stdout).not.toContain('every runnable trusted guard passed');
  });
});

test('an API guard that exits silently is reported as not run and cannot pass', () => {
  withCheckout({ 'plugin_bump_api_retry.mts': 'process.exitCode = 0;\n' }, (root) => {
    const result = invoke(root, '--base-ref', baseRef);
    expect(result.status).toBe(1);
    expect(result.stdout).toContain('  plugin_bump_api_retry.mts: not run (exited 0 without its verdict line');
    expect(result.stdout).not.toContain('  plugin_bump_api_retry.mts: exit 0');
    expect(result.stdout).toContain('  workflow_runner_policy_check.rb: exit 0\n');
    expect(reportedNames(result.stdout)).toEqual(knownGuards);
    expect(result.stdout).not.toContain('every runnable trusted guard passed');
  });
});
