import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { expect, test } from 'vitest';

const scripts = import.meta.dirname;
const preflight = join(scripts, 'trusted_guard_preflight.rb');
const baseRef = 'origin/preflight-fixture';

function withCheckout(extraGuards: Record<string, string>, run: (root: string) => void, prepare?: (root: string) => void): void {
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
    prepare?.(root);
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
  return invokeWithEnv(root, {}, ...args);
}

function invokeWithEnv(root: string, env: NodeJS.ProcessEnv, ...args: string[]) {
  const result = spawnSync('ruby', [preflight, '--root', root, ...args], {
    encoding: 'utf8',
    timeout: 10_000,
    env: { ...process.env, GH_TOKEN: '', GITHUB_TOKEN: '', HATSU_TRUSTED_BASE_NEN: undefined, ...env },
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

function writeNenPin(root: string, ref: string, binary: string): void {
  const digest = createHash('sha256').update(readFileSync(binary)).digest('hex');
  writeFileSync(join(root, 'nen', 'contract.json'), JSON.stringify({
    dependency: {
      pinned_ref: ref,
      bootstrap: { sha256: { 'darwin-arm64': digest, 'linux-x64': digest, 'windows-x64': digest } },
    },
  }));
}

test('candidate repin and trusted runtime use their respective Nen wiring', () => {
  withCheckout({}, (root) => {
    const baseBinary = join(root, 'fixture-base-nen');
    const newerBinary = join(root, 'fixture-newer-nen');
    writeNenPin(root, 'v0.30.99', newerBinary);

    const candidate = invokeWithEnv(root, { NEN: baseBinary }, '--check-adapters');
    expect(candidate.status, candidate.stderr).toBe(0);

    const runtime = invokeWithEnv(root, { NEN: newerBinary, HATSU_TRUSTED_BASE_NEN: baseBinary }, '--base-ref', baseRef);
    expect(runtime.status, runtime.stderr).toBe(0);
    expect(runtime.stdout).toContain('  nen-canon-lint: exit 0\n    canon lint: fixture\n');
    expect(existsSync(join(root, 'ordinary-ran'))).toBe(false);

    const wrong = invokeWithEnv(root, { NEN: baseBinary, HATSU_TRUSTED_BASE_NEN: newerBinary }, '--base-ref', baseRef);
    expect(wrong.status).toBe(2);
    expect(wrong.stdout).toContain('selected Nen does not match the trusted');
    expect(existsSync(join(root, 'ordinary-ran'))).toBe(false);

    const missing = invokeWithEnv(root, { NEN: baseBinary, HATSU_TRUSTED_BASE_NEN: join(root, 'missing') }, '--base-ref', baseRef);
    expect(missing.status).toBe(2);
    expect(missing.stdout).toContain('no executable Nen');
  }, (root) => {
    const baseBinary = join(root, 'fixture-base-nen');
    const newerBinary = join(root, 'fixture-newer-nen');
    writeFileSync(baseBinary, '#!/bin/sh\nprintf "canon lint: fixture\\n"\n', { mode: 0o700 });
    writeFileSync(newerBinary, '#!/bin/sh\nprintf ran > "$4/ordinary-ran"\nexit 42\n', { mode: 0o700 });
    mkdirSync(join(root, 'nen'));
    mkdirSync(join(root, 'contracts'));
    writeFileSync(join(root, 'contracts', 'prose.lint.json'), '{}');
    writeFileSync(join(root, 'contracts', 'prose.lint.baseline.json'), '{}');
    writeNenPin(root, 'v0.30.0', baseBinary);
    writeFileSync(join(root, '.github', 'workflows', 'prose-ambiguity-check.yml'), `on:
  pull_request_target: {}
jobs:
  canon-lint:
    steps:
      - name: Canon prose lint
        run: |
          "$NEN_BIN" canon lint --root "$PWD" --rules "$PWD/$rules" --baseline contracts/prose.lint.baseline.json --base-baseline "$PWD/$base" --skill-paths 'claude/skills/*/SKILL.md' 2>&1 || code=$?
`);
  });
});
