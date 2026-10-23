// scripts/shell_coverage.mts's own fixtures (zheref/hatsu#148): hermetic temp repositories, a stub
// `ruby` standing in for the pinned Bashcov, and the real helper. Runs in the unit-tests-ci-guard lane.
import { spawnSync } from 'node:child_process';
import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { afterEach, expect, it } from 'vitest';

const helper = resolve('scripts/shell_coverage.mts');
const roots: string[] = [];
afterEach(() => { for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true }); });

function fixture(interp = 'bash', body = 'echo ran >> ran.log\n') {
  const root = mkdtempSync(join(tmpdir(), 'hatsu-shell-coverage-'));
  roots.push(root);
  for (const dir of ['scripts', 'nen', 'bin']) mkdirSync(join(root, dir));
  writeFileSync(join(root, 'scripts/fixture.sh'), `#!/usr/bin/env ${interp}\n${body}`);
  writeFileSync(join(root, 'nen/contract.json'), JSON.stringify({ project: {
    verbs: { sample: { test: { exe: 'bash', argv: [
      'scripts/fixture_output_guard.sh', 'node', 'scripts/shell_coverage.mts',
      '--capture', 'sample', interp, 'scripts/fixture.sh', '--self-test',
    ] } } },
    toolchain: { bashcov: { version: '4.0.0' }, 'simplecov-lcov': { version: '0.9.0' } },
  } }));
  // The stub answers the launcher's --version probe, and otherwise writes the LCOV Bashcov would.
  const stub = join(root, 'bin/ruby');
  writeFileSync(stub, `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
if (process.env.FAKE_NO_BASHCOV) process.exit(1);
if (args.includes('--version')) { console.log('bashcov ' + args[2]); process.exit(0); }
fs.appendFileSync('invocations', args.slice(2).join(' ') + '\\n');
if (process.env.FAKE_FAIL) process.exit(3);
if (process.env.FAKE_ABORT) console.error('bashcov: warning: Aborting early; coverage report will be incomplete.');
fs.writeFileSync(process.env.HATSU_COVERAGE_PATH, 'SF:' + (process.env.FAKE_SF ?? process.cwd() + '/scripts/fixture.sh') + '\\nDA:1,1\\nend_of_record\\n');
`);
  chmodSync(stub, 0o755);
  const bash = join(root, 'bin/fake-bash');
  writeFileSync(bash, '#!/bin/sh\necho "GNU bash, version 5.2.0(1)-release"\n');
  chmodSync(bash, 0o755);
  const run = (args: string[], extra: Record<string, string> = {}) => spawnSync(process.execPath, [helper, ...args], {
    cwd: root, encoding: 'utf8', env: { ...process.env, PATH: `${join(root, 'bin')}:${process.env.PATH}`, HATSU_COVERAGE_BASH: bash, ...extra },
  });
  return { root, run, report: join(root, 'coverage/sample/lcov.info') };
}
const capture = ['--capture', 'sample', 'bash', 'scripts/fixture.sh', '--self-test'];

it('captures the declared fixture at the pinned version and verifies it without rerunning', () => {
  const { root, run, report } = fixture();
  const captured = run(capture);
  expect(captured.status, captured.stderr).toBe(0);
  expect(readFileSync(report, 'utf8')).toContain('SF:scripts/fixture.sh\n');
  const invocations = readFileSync(join(root, 'invocations'), 'utf8');
  expect(invocations).toMatch(/^4\.0\.0 --skip-uncovered --bash-path \S+fake-bash --root \S+ -- scripts\/fixture\.sh --self-test\n$/);
  const verified = run(['--verify', 'sample']);
  expect(verified.status).toBe(0);
  expect(verified.stdout).toContain('no fixture ran');
  expect(readFileSync(join(root, 'invocations'), 'utf8')).toBe(invocations);
});

it('refuses an undeclared invocation, a symlinked fixture and a missing report', () => {
  const { root, run } = fixture();
  expect(run(['--capture', 'sample', 'bash', 'scripts/fixture.sh']).stderr).toContain('does not declare');
  expect(run(['--capture', 'sample', 'sh', 'scripts/fixture.sh', '--self-test']).stderr).toContain('does not declare');
  const verify = run(['--verify', 'sample']);
  expect(verify.status).toBe(2);
  expect(verify.stderr).toContain('holds no shell coverage');
  rmSync(join(root, 'scripts/fixture.sh'));
  symlinkSync(join(root, 'nen/contract.json'), join(root, 'scripts/fixture.sh'));
  expect(run(capture).stderr).toContain('regular file');
});

it('refuses an LCOV source outside the repository and leaves no report', () => {
  const { run, report } = fixture();
  const result = run(capture, { FAKE_SF: '/tmp/outside.sh' });
  expect(result.status).toBe(2);
  expect(result.stderr).toContain('outside the repository');
  expect(existsSync(report)).toBe(false);
});

it('fails red and keeps no report when the instrumented fixture fails', () => {
  const { run, report } = fixture();
  const result = run(capture, { FAKE_FAIL: '1' });
  expect(result.status).toBe(1);
  expect(result.stderr).toContain('fixture failed under Bashcov');
  expect(existsSync(report)).toBe(false);
});

it('keeps a passing fixture green but captures nothing when the trace is incomplete', () => {
  const { run, report } = fixture();
  const result = run(capture, { FAKE_ABORT: '1' });
  expect(result.status).toBe(0);
  expect(result.stderr).toContain("Bashcov's trace is incomplete; no coverage captured");
  expect(existsSync(report)).toBe(false);
});

it('runs uninstrumented without Bashcov, says so, removes a stale report, and keeps the fixture red', () => {
  const { root, run, report } = fixture();
  expect(run(capture).status).toBe(0);
  const plain = run(capture, { FAKE_NO_BASHCOV: '1' });
  expect(plain.status).toBe(0);
  expect(plain.stderr).toContain('ran uninstrumented (bashcov 4.0.0 is not installed');
  expect(existsSync(report)).toBe(false);
  expect(readFileSync(join(root, 'ran.log'), 'utf8')).toBe('ran\n');
  expect(run(capture, { HATSU_SHELL_COVERAGE: '0' }).stderr).toContain('HATSU_SHELL_COVERAGE=0');
  expect(run(capture, { FAKE_NO_BASHCOV: '1', HATSU_SHELL_COVERAGE: 'require' }).status).toBe(2);
  expect(run(capture, { HATSU_SHELL_COVERAGE: 'maybe' }).status).toBe(2);
  writeFileSync(join(root, 'scripts/fixture.sh'), '#!/usr/bin/env bash\nexit 1\n');
  expect(run(capture, { FAKE_NO_BASHCOV: '1' }).status).toBe(1);
});

it('runs a POSIX sh fixture under sh first, then instrumented', () => {
  const { root, run, report } = fixture('sh');
  const result = run(['--capture', 'sample', 'sh', 'scripts/fixture.sh', '--self-test']);
  expect(result.status, result.stderr).toBe(0);
  expect(readFileSync(join(root, 'ran.log'), 'utf8')).toBe('ran\n');
  expect(readFileSync(join(root, 'invocations'), 'utf8').split('\n').filter(Boolean)).toHaveLength(1);
  expect(existsSync(report)).toBe(true);
});
