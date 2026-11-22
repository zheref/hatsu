// scripts/shell_coverage.mts's own fixtures (zheref/hatsu#148): hermetic temp repositories, a stub
// `ruby` standing in for the pinned Bashcov, and the real helper. Runs in the unit-tests-ci-guard lane.
import { spawnSync } from 'node:child_process';
import { chmodSync, closeSync, existsSync, mkdtempSync, mkdirSync, openSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { afterEach, expect, it } from 'vitest';

const helper = resolve('scripts/shell_coverage.mts');
const coverageBash = ['/opt/homebrew/bin/bash', '/usr/local/bin/bash', '/usr/bin/bash', '/bin/bash'].find((path) => {
  if (!existsSync(path)) return false;
  const probe = spawnSync(path, ['--version'], { encoding: 'utf8' });
  const major = probe.stdout?.match(/GNU bash, version (\d+)/)?.[1];
  return probe.status === 0 && Number(major) >= 5;
});
const roots: string[] = [];
afterEach(() => { for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true }); });

function fixture(interp = 'bash', body = 'echo ran >> ran.log\n', target?: string | string[], traceSubstitutions = false) {
  const root = mkdtempSync(join(tmpdir(), 'hatsu-shell-coverage-'));
  roots.push(root);
  for (const dir of ['scripts', 'nen', 'bin', 'gems']) mkdirSync(join(root, dir));
  writeFileSync(join(root, 'scripts/fixture.sh'), `#!/usr/bin/env ${interp}\n${body}`);
  const targets = Array.isArray(target) ? target : target ? [target] : [];
  for (const source of targets) writeFileSync(join(root, source), '#!/usr/bin/env bash\necho target\n');
  // Three stand-in .gem files; the contract pins their digests as it pins the real ones.
  const pins: Record<string, string> = { simplecov: '1.3.2', bashcov: '4.0.0', 'simplecov-lcov': '0.9.0' };
  const toolchain: Record<string, { version: string; gemSha256: string }> = {};
  for (const [name, version] of Object.entries(pins)) {
    const gem = join(root, 'gems', `${name}-${version}.gem`);
    writeFileSync(gem, `${name} ${version}\n`);
    toolchain[name] = { version, gemSha256: createHash('sha256').update(readFileSync(gem)).digest('hex') };
  }
  const captureTail = targets.length ? [...targets.flatMap((source) => ['--target', source]), ...(traceSubstitutions ? ['--trace-substitutions'] : [])] : ['--self-test'];
  writeFileSync(join(root, 'nen/contract.json'), JSON.stringify({ project: {
    verbs: { sample: { test: { exe: 'bash', argv: [
      'scripts/fixture_output_guard.sh', 'node', 'scripts/shell_coverage.mts',
      '--capture', 'sample', interp, 'scripts/fixture.sh', ...captureTail,
    ] } } },
    toolchain,
  } }));
  // The stub answers the launcher's --version probe and the .gem lookup, and otherwise writes the
  // LCOV Bashcov would. args[1] is the -e program, so its activation order is recorded too.
  const stub = join(root, 'bin/ruby');
  writeFileSync(stub, `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2);
if (process.env.FAKE_NO_BASHCOV) process.exit(1);
if (args[1].includes('cache_file')) {
  for (let i = 2; i < args.length; i += 2) console.log(path.join(process.cwd(), 'gems', args[i] + '-' + args[i + 1] + '.gem'));
  process.exit(0);
}
fs.writeFileSync('program', args[1]);
fs.writeFileSync('targets-env', JSON.stringify(Object.fromEntries(Object.entries(process.env).filter(([key]) => /^HATSU_SHELL_COVERAGE_(EXEC|TARGET)(_|$)/.test(key)))));
if (args.includes('--version')) { console.log('bashcov ' + args[3]); process.exit(0); }
fs.appendFileSync('invocations', args.slice(2).join(' ') + '\\n');
if (process.env.HATSU_SHELL_COVERAGE_TARGET) fs.writeFileSync('target-env', [
  process.env.HATSU_SHELL_COVERAGE_TARGET,
  process.env.HATSU_SHELL_COVERAGE_TARGET_PATH,
  process.env.HATSU_SHELL_COVERAGE_EXEC,
  fs.existsSync(process.env.HATSU_SHELL_COVERAGE_EXEC),
].join('\\n') + '\\n');
if (process.env.FAKE_RUN_TARGET) {
  const traceEnv = {
    ...process.env,
    HATSU_SHELL_COVERAGE_PS4: '+BASHCOV>TRACESEP\${LINENO-}TRACESEP\${BASH_SOURCE-}TRACESEP\${PWD-}TRACESEP\${OLDPWD-}TRACESEP',
    HATSU_SHELL_COVERAGE_TRACE_FD: '2',
    HATSU_SHELL_COVERAGE_BASH: process.env.FAKE_REAL_BASH,
  };
  if (process.env.FAKE_MISSING_TRACE_TRANSFER) delete traceEnv.HATSU_SHELL_COVERAGE_PS4;
  const traced = require('node:child_process').spawnSync(process.env.HATSU_SHELL_COVERAGE_EXEC, [], {
    encoding: 'utf8', env: traceEnv,
  });
  fs.writeFileSync('target-trace', traced.stderr ?? '');
  if (traced.status !== 0) {
    console.error(traced.error?.message ?? traced.stderr ?? 'target wrapper failed');
    process.exit(traced.status ?? 1);
  }
}
if (process.env.FAKE_ABORT) console.error('bashcov: warning: Aborting early; coverage report will be incomplete.');
if (process.env.FAKE_FAIL) process.exit(3);
const reported = (process.env.FAKE_SFS ?? process.env.FAKE_SF ?? process.cwd() + '/scripts/fixture.sh').split(',');
fs.writeFileSync(process.env.HATSU_COVERAGE_PATH, reported.map((source) => 'SF:' + source + '\\nDA:1,1\\nend_of_record\\n').join(''));
`);
  chmodSync(stub, 0o755);
  const bash = join(root, 'bin/fake-bash');
  writeFileSync(bash, '#!/bin/sh\nif [ "$1" = --version ]; then echo "GNU bash, version 5.2.0(1)-release"; else exec "$FAKE_REAL_BASH" "$@"; fi\n');
  chmodSync(bash, 0o755);
  const run = (args: string[], extra: Record<string, string> = {}) => {
    // A shebang interpreter must be a native executable on macOS. Keep the real Bash behind a
    // fixture-local symlink so the helper still prepends our stub Ruby directory to PATH.
    if (extra.FAKE_REAL_BASH) {
      rmSync(bash, { force: true });
      symlinkSync(extra.FAKE_REAL_BASH, bash);
    }
    return spawnSync(process.execPath, [helper, ...args], {
      cwd: root, encoding: 'utf8', env: { ...process.env, PATH: `${join(root, 'bin')}:${process.env.PATH}`, HATSU_COVERAGE_BASH: bash, ...extra },
    });
  };
  return { root, run, report: join(root, 'coverage/sample/lcov.info') };
}
const capture = ['--capture', 'sample', 'bash', 'scripts/fixture.sh', '--self-test'];

it('isolates a declared target behind a temporary wrapper and retains only that LCOV source', () => {
  const target = 'scripts/target.sh';
  const { root, run, report } = fixture('bash', 'echo fixture\n', target);
  const result = run(['--capture', 'sample', 'bash', 'scripts/fixture.sh', '--target', target], {
    FAKE_SFS: `scripts/fixture.sh,${target}`,
  });
  expect(result.status, result.stderr).toBe(0);
  expect(readFileSync(report, 'utf8')).toBe('SF:scripts/target.sh\nDA:1,1\nend_of_record\n');
  const [named, path, wrapper, existed] = readFileSync(join(root, 'target-env'), 'utf8').trim().split('\n');
  expect(named).toBe(target);
  expect(path).toBe(realpathSync(join(root, target)));
  expect(existed).toBe('true');
  expect(existsSync(wrapper)).toBe(false);
  const provenance = JSON.parse(readFileSync(join(root, 'coverage/sample/provenance.json'), 'utf8'));
  expect(Object.keys(provenance.files)).toEqual([target]);
});

it('requires every declared target in a multi-source capture and filters fixture records', () => {
  const targets = ['scripts/first.sh', 'scripts/second.sh'];
  const { root, run, report } = fixture('bash', 'echo fixture\n', targets);
  const args = ['--capture', 'sample', 'bash', 'scripts/fixture.sh', ...targets.flatMap((target) => ['--target', target])];
  const captured = run(args, { FAKE_SFS: `scripts/fixture.sh,${targets.join(',')}` });
  expect(captured.status, captured.stderr).toBe(0);
  expect(readFileSync(report, 'utf8').match(/^SF:(.+)$/gm)).toEqual(targets.map((target) => `SF:${target}`));
  expect(Object.keys(JSON.parse(readFileSync(join(root, 'coverage/sample/provenance.json'), 'utf8')).files)).toEqual(targets);
  const env = JSON.parse(readFileSync(join(root, 'targets-env'), 'utf8'));
  expect(env.HATSU_SHELL_COVERAGE_TARGET_2).toBe(targets[1]);
  expect(env.HATSU_SHELL_COVERAGE_EXEC_2).not.toBe(env.HATSU_SHELL_COVERAGE_EXEC);
  expect(existsSync(env.HATSU_SHELL_COVERAGE_EXEC_2)).toBe(false);
  const missing = run(args, { FAKE_SF: targets[0] });
  expect(missing.status).toBe(2);
  expect(missing.stderr).toContain('did not report exactly its declared sources');
  expect(existsSync(report)).toBe(false);
});

it('refuses duplicate target declarations before running a fixture', () => {
  const target = 'scripts/target.sh';
  const { root, run } = fixture('bash', 'echo fixture\n', [target, target]);
  const result = run(['--capture', 'sample', 'bash', 'scripts/fixture.sh', '--target', target, '--target', target]);
  expect(result.status).toBe(2);
  expect(result.stderr).toContain('duplicate coverage target');
  expect(existsSync(join(root, 'invocations'))).toBe(false);
});

it.skipIf(!coverageBash)('fails without a coverage report when target trace transfer state is missing', () => {
  const target = 'scripts/target.sh';
  const { run, report } = fixture('bash', 'echo fixture\n', target);
  const result = run(['--capture', 'sample', 'bash', 'scripts/fixture.sh', '--target', target], {
    FAKE_RUN_TARGET: '1',
    FAKE_MISSING_TRACE_TRANSFER: '1',
    FAKE_REAL_BASH: coverageBash ?? '/bin/bash',
    FAKE_SF: target,
  });
  expect(result.status).toBe(1);
  expect(result.stderr).toContain('HATSU_SHELL_COVERAGE_PS4');
  expect(existsSync(report)).toBe(false);
});

it.skipIf(!coverageBash)('emits parseable target records while nested traces carry no Bashcov fields', () => {
  const target = 'scripts/target.sh';
  const { root, run } = fixture('bash', 'echo fixture\n', target);
  writeFileSync(join(root, target), `#!/usr/bin/env bash
set -euo pipefail
root_value=one
root_function() {
  [[ $BASH_SUBSHELL -eq 0 ]]
  printf 'function\\n' >/dev/null
}
root_function
nested=$(
  depth_two=$(
    [[ $BASH_SUBSHELL -ge 2 ]]
    printf 'nested\\n'
  )
  printf '%s\\n' "$depth_two"
)
child_trace=$(bash -x -c 'set -u; printf "child\\n"' 2>&1)
[[ $child_trace == *child* ]]
[[ $child_trace != *BASHCOV* ]]
[[ $child_trace != *"unbound variable"* ]]
while IFS= read -r item; do
  [[ $item == "$nested" ]]
done < <(printf '%s\\n' "$nested")
`);
  const result = run(['--capture', 'sample', 'bash', 'scripts/fixture.sh', '--target', target], {
    FAKE_RUN_TARGET: '1',
    FAKE_REAL_BASH: coverageBash!,
    FAKE_SF: target,
  });
  expect(result.status, result.stderr).toBe(0);
  const trace = readFileSync(join(root, 'target-trace'), 'utf8').split('\n').filter(Boolean);
  const source = realpathSync(join(root, target)).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  expect(trace.some((line) => new RegExp(`^\\++BASHCOV>TRACESEP\\d+TRACESEP${source}TRACESEP`).test(line))).toBe(true);
  expect(trace.some((line) => line.includes('BASHCOV>') && line.endsWith('root_function'))).toBe(true);
  expect(trace.some((line) => line.includes('BASHCOV>') && line.includes("printf 'function\\n'"))).toBe(true);
  const nested = trace.filter((line) => !line.includes('BASHCOV>'));
  expect(nested.some((line) => line.includes('[[ 2 -ge 2 ]]'))).toBe(true);
  expect(nested.filter((line) => line.includes('printf')).length).toBeGreaterThanOrEqual(3);
  expect(nested.every((line) => !line.includes('TRACESEP'))).toBe(true);
  expect(trace.some((line) => /: unbound variable$/.test(line))).toBe(false);
  const absentSource = spawnSync(coverageBash!, ['-uc', "names=(BASH_SOURCE); PS4='${!names[0]-}'; set -x; :"], { encoding: 'utf8' });
  expect(absentSource.status, absentSource.stderr).toBe(0);
  expect(absentSource.stderr).not.toContain('unbound variable');
});

it.skipIf(!coverageBash)('retains real nested source records only for a declared serial-target opt-in', () => {
  const target = 'scripts/target.sh';
  const { root, run } = fixture('bash', 'echo fixture\n', target, true);
  writeFileSync(join(root, target), `set -eu
value=$(
  target_function() { printf nested; }
  target_function
)
[ "$value" = nested ]
`);
  const result = run(['--capture', 'sample', 'bash', 'scripts/fixture.sh', '--target', target, '--trace-substitutions'], {
    FAKE_RUN_TARGET: '1', FAKE_REAL_BASH: coverageBash!, FAKE_SF: target,
  });
  expect(result.status, result.stderr).toBe(0);
  const trace = readFileSync(join(root, 'target-trace'), 'utf8').split('\n');
  expect(trace.some((line) => line.includes(`TRACESEP${realpathSync(join(root, target))}TRACESEP`) && line.endsWith('target_function'))).toBe(true);
  expect(trace.some((line) => line.includes('BASHCOV>') && line.endsWith('printf nested'))).toBe(true);
});

it('refuses nested-trace opt-in without a declared target', () => {
  const { run } = fixture();
  const result = run(['--capture', 'sample', 'bash', 'scripts/fixture.sh', '--trace-substitutions']);
  expect(result.status).toBe(2);
  expect(result.stderr).toContain('--trace-substitutions requires exactly one target');
});

it('captures the declared fixture at the pinned version and verifies it without rerunning', () => {
  const { root, run, report } = fixture();
  const captured = run(capture);
  expect(captured.status, captured.stderr).toBe(0);
  expect(readFileSync(report, 'utf8')).toContain('SF:scripts/fixture.sh\n');
  const invocations = readFileSync(join(root, 'invocations'), 'utf8');
  expect(invocations).toMatch(/^1\.3\.2 4\.0\.0 --skip-uncovered --bash-path \S+fake-bash --root \S+ -- scripts\/fixture\.sh --self-test\n$/);
  // SimpleCov is activated at its pin before Bashcov, so Bashcov's '~> 1.1' cannot float to a newer one.
  expect(readFileSync(join(root, 'program'), 'utf8')).toMatch(/^gem 'simplecov', ARGV\.shift; gem 'bashcov', ARGV\.shift;/);
  expect(readFileSync(join(root, 'program'), 'utf8')).toContain('~Fcntl::O_NONBLOCK');
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

it('refuses a report the tree has moved past, and one with no provenance', () => {
  const { root, run } = fixture();
  expect(run(capture).status).toBe(0);
  writeFileSync(join(root, 'scripts/fixture.sh'), '#!/usr/bin/env bash\necho changed\n');
  const stale = run(['--verify', 'sample']);
  expect(stale.status).toBe(2);
  expect(stale.stderr).toContain('is stale: scripts/fixture.sh changed since the capture');
  expect(run(capture).status).toBe(0);
  rmSync(join(root, 'coverage/sample/provenance.json'));
  expect(run(['--verify', 'sample']).stderr).toContain('so its tree is unknown');
});

it('refuses a gem whose checksum differs from its pin, and a pin that is not exact', () => {
  const { root, run, report } = fixture();
  writeFileSync(join(root, 'gems/simplecov-1.3.2.gem'), 'tampered\n');
  const tampered = run(capture);
  expect(tampered.status).toBe(2);
  expect(tampered.stderr).toContain('simplecov 1.3.2 at');
  expect(tampered.stderr).toContain('does not match its pinned gemSha256');
  expect(existsSync(report)).toBe(false);
  expect(existsSync(join(root, 'invocations'))).toBe(false);
  expect(existsSync(join(root, 'program'))).toBe(false); // no gem code ran before the digests matched
  const contract = JSON.parse(readFileSync(join(root, 'nen/contract.json'), 'utf8'));
  contract.project.toolchain.simplecov.version = '~> 1.1';
  writeFileSync(join(root, 'nen/contract.json'), JSON.stringify(contract));
  expect(run(capture).stderr).toContain('to an exact version and a gemSha256');
});

it('runs uninstrumented, still testable, when a gem cache is absent', () => {
  const { root, run, report } = fixture();
  rmSync(join(root, 'gems/bashcov-4.0.0.gem'));
  const result = run(capture);
  expect(result.status).toBe(0);
  expect(result.stderr).toContain('ran uninstrumented (gem cache absent for bashcov 4.0.0');
  expect(readFileSync(join(root, 'ran.log'), 'utf8')).toBe('ran\n');
  expect(existsSync(report)).toBe(false);
  expect(existsSync(join(root, 'program'))).toBe(false);
  expect(run(capture, { HATSU_SHELL_COVERAGE: 'require' }).status).toBe(2);
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

it('keeps a passing fixture green and retains valid partial LCOV when trace aborts, or exits 2 under require if 0 coverage was captured', () => {
  const { root, run, report } = fixture();
  const abortMsg = 'bashcov: Encountered an error parsing Bash\'s output (expected integer for LINENO, got "bad-token"). Report this bug. Aborting early; coverage report will be incomplete.';
  writeFileSync(join(root, 'bin/ruby'), `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2);
if (args[1].includes('cache_file')) {
  for (let i = 2; i < args.length; i += 2) console.log(path.join(process.cwd(), 'gems', args[i] + '-' + args[i + 1] + '.gem'));
  process.exit(0);
}
if (args.includes('--version')) { console.log('bashcov ' + args[3]); process.exit(0); }
console.error(process.env.FAKE_ABORT_MSG || 'bashcov: warning: Aborting early; coverage report will be incomplete.');
if (process.env.FAKE_FAIL) process.exit(3);
if (!process.env.FAKE_NO_REPORT) {
  const reported = (process.env.FAKE_SFS ?? process.env.FAKE_SF ?? process.cwd() + '/scripts/fixture.sh').split(',');
  fs.writeFileSync(process.env.HATSU_COVERAGE_PATH, reported.map((source) => 'SF:' + source + '\\nDA:1,1\\nend_of_record\\n').join(''));
}
`);
  const partial = run(capture, { FAKE_ABORT_MSG: abortMsg });
  expect(partial.status).toBe(0);
  expect(partial.stderr).toContain('expected integer for LINENO, got "bad-token"');
  expect(partial.stderr).toContain('retained partial coverage');
  expect(existsSync(report)).toBe(true);
  const provenance = JSON.parse(readFileSync(join(root, 'coverage/sample/provenance.json'), 'utf8'));
  expect(provenance.partial).toBe(true);
  const verifiedPartial = run(['--verify', 'sample']);
  expect(verifiedPartial.status).toBe(0);
  expect(verifiedPartial.stdout).toContain('(partial capture)');

  rmSync(report, { force: true });
  const emptyAuto = run(capture, { FAKE_SF: 'unrelated.txt' });
  expect(emptyAuto.status).toBe(0);
  expect(emptyAuto.stderr).toContain('unmeasured');
  expect(existsSync(report)).toBe(false);

  const emptyReq = run(capture, { FAKE_SF: 'unrelated.txt', HATSU_SHELL_COVERAGE: 'require' });
  expect(emptyReq.status).toBe(2);
  expect(emptyReq.stderr).toContain('unmeasured');
  expect(existsSync(report)).toBe(false);

  const noReportAuto = run(capture, { FAKE_NO_REPORT: '1' });
  expect(noReportAuto.status).toBe(0);
  expect(noReportAuto.stderr).toContain('unmeasured');
  const noReportReq = run(capture, { FAKE_NO_REPORT: '1', HATSU_SHELL_COVERAGE: 'require' });
  expect(noReportReq.status).toBe(2);
  expect(noReportReq.stderr).toContain('unmeasured');

  const nonzeroAbortReq = run(capture, { FAKE_FAIL: '1', HATSU_SHELL_COVERAGE: 'require' });
  expect(nonzeroAbortReq.status).toBe(2);
  expect(nonzeroAbortReq.stderr).toContain('re-running it uninstrumented');
});

it('retains partial multi-target coverage on trace abort instead of deleting it', () => {
  const targets = ['scripts/first.sh', 'scripts/second.sh'];
  const { run, report } = fixture('bash', 'echo fixture\n', targets);
  const args = ['--capture', 'sample', 'bash', 'scripts/fixture.sh', ...targets.flatMap((target) => ['--target', target])];
  const partial = run(args, { FAKE_ABORT: '1', FAKE_SF: targets[0] });
  expect(partial.status, partial.stderr).toBe(0);
  expect(partial.stderr).toContain('retained partial coverage');
  expect(readFileSync(report, 'utf8')).toBe('SF:scripts/first.sh\nDA:1,1\nend_of_record\n');
});

it('fails non-zero without plain fallback when child stderr merely contains generic exception text', () => {
  const { root, run, report } = fixture();
  writeFileSync(join(root, 'bin/ruby'), `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2);
if (args[1].includes('cache_file')) {
  for (let i = 2; i < args.length; i += 2) console.log(path.join(process.cwd(), 'gems', args[i] + '-' + args[i + 1] + '.gem'));
  process.exit(0);
}
if (args.includes('--version')) { console.log('bashcov ' + args[3]); process.exit(0); }
console.error('worker terminated with exception: boom');
process.exit(3);
`);
  const result = run(capture);
  expect(result.status).toBe(1);
  expect(result.stderr).toContain('fixture failed under Bashcov');
  expect(result.stderr).not.toContain('re-running it uninstrumented');
  expect(existsSync(report)).toBe(false);
});

it('fails --verify cleanly with exit 2 when a recorded source path is replaced by a directory', () => {
  const { root, run } = fixture();
  expect(run(capture).status).toBe(0);
  rmSync(join(root, 'scripts/fixture.sh'));
  mkdirSync(join(root, 'scripts/fixture.sh'));
  const verified = run(['--verify', 'sample']);
  expect(verified.status).toBe(2);
  expect(verified.stderr).toContain('is stale: scripts/fixture.sh changed since the capture');
});

it('treats benign bashcov deleted-cwd warnings as full captures without trace-incomplete status', () => {
  const { root, run, report } = fixture();
  writeFileSync(join(root, 'bin/ruby'), `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2);
if (args[1].includes('cache_file')) {
  for (let i = 2; i < args.length; i += 2) console.log(path.join(process.cwd(), 'gems', args[i] + '-' + args[i + 1] + '.gem'));
  process.exit(0);
}
if (args.includes('--version')) { console.log('bashcov ' + args[3]); process.exit(0); }
console.error('bashcov: warning: . was executed but has been deleted since then - it will not be reported in coverage.');
fs.writeFileSync(process.env.HATSU_COVERAGE_PATH, 'SF:' + process.cwd() + '/scripts/fixture.sh\\nDA:1,1\\nend_of_record\\n');
`);
  const result = run(capture);
  expect(result.status, result.stderr).toBe(0);
  expect(result.stdout).toContain('wrote coverage/sample/lcov.info for 1 script files');
  expect(result.stderr).not.toContain('trace incomplete');
  expect(existsSync(report)).toBe(true);
});

it('re-runs plain when an incomplete trace comes with a non-zero exit, and takes that exit', () => {
  const { root, run, report } = fixture();
  const result = run(capture, { FAKE_ABORT: '1', FAKE_FAIL: '1' });
  expect(result.status).toBe(0);
  expect(result.stderr).toContain('re-running it uninstrumented');
  expect(readFileSync(join(root, 'ran.log'), 'utf8')).toBe('ran\n');
  expect(existsSync(report)).toBe(false);
  writeFileSync(join(root, 'scripts/fixture.sh'), '#!/usr/bin/env bash\nexit 4\n');
  expect(run(capture, { FAKE_ABORT: '1', FAKE_FAIL: '1' }).status).toBe(4);
});

it.skipIf(!coverageBash)('isolates concurrent pipelines, >6KB commands, process substitutions, FD>2 closure, BASH_ENV isolation, and error cleanup (HA#599 AC-3)', () => {
  const target = 'scripts/target.sh';
  const { root, run } = fixture('bash', 'echo fixture\n', target);
  const longArg = 'x'.repeat(6500);
  const bashEnvProbe = join(root, 'bash-env-ran.log');
  const bashEnvScript = join(root, 'evil-bash-env.sh');
  writeFileSync(bashEnvScript, `echo BASH_ENV_EXECUTED >> ${JSON.stringify(bashEnvProbe)}\n`);
  writeFileSync(join(root, target), `#!/usr/bin/env bash
set -euo pipefail
if { true >&3; } 2>/dev/null; then
  printf 'parent fd 3 leaked into target child\\n' >&2
  exit 99
fi
: "${longArg}"
printf 'a\\nb\\nc\\n' | cat | wc -l >/dev/null
while IFS= read -r line; do
  [[ "$line" == "ok" ]]
done < <(printf 'ok\\nok\\n')
exit 7
`);
  writeFileSync(join(root, 'bin/ruby'), `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const args = process.argv.slice(2);
if (args[1].includes('cache_file')) {
  for (let i = 2; i < args.length; i += 2) console.log(path.join(process.cwd(), 'gems', args[i] + '-' + args[i + 1] + '.gem'));
  process.exit(0);
}
if (args.includes('--version')) { console.log('bashcov ' + args[3]); process.exit(0); }
const sharedTrace = path.join(process.cwd(), 'target-trace');
const fd = fs.openSync(sharedTrace, 'a');
const baseEnv = {
  ...process.env,
  HATSU_SHELL_COVERAGE_PS4: '+BASHCOV>TRACESEP\${LINENO-}TRACESEP\${BASH_SOURCE-}TRACESEP\${PWD-}TRACESEP\${OLDPWD-}TRACESEP',
  HATSU_SHELL_COVERAGE_TRACE_FD: '3',
  HATSU_SHELL_COVERAGE_BASH: process.env.FAKE_REAL_BASH,
  BASH_ENV: process.env.FAKE_BASH_ENV,
};
const runOne = () => new Promise((resolve) => {
  const child = spawn(process.env.HATSU_SHELL_COVERAGE_EXEC, [], { env: baseEnv, stdio: ['ignore', 'pipe', 'pipe', fd] });
  let err = '';
  child.stderr.on('data', (chunk) => { err += chunk; });
  child.on('close', (status) => resolve({ status, err }));
});
Promise.all([runOne(), runOne()]).then(([r1, r2]) => {
  fs.closeSync(fd);
  const badFd = spawnSync(process.env.HATSU_SHELL_COVERAGE_EXEC, [], { encoding: 'utf8', env: { ...baseEnv, HATSU_SHELL_COVERAGE_TRACE_FD: 'abc' } });
  const closedDrainFd = spawnSync(process.env.HATSU_SHELL_COVERAGE_EXEC, [], { encoding: 'utf8', env: { ...baseEnv, HATSU_SHELL_COVERAGE_TRACE_FD: '9' }, stdio: ['ignore', 'pipe', 'pipe'] });
  fs.writeFileSync('wrapper-exit', [r1.status, r2.status, badFd.status, closedDrainFd.status].join(','));
  fs.writeFileSync('wrapper-errors', (r1.err + '\\n' + r2.err + '\\n' + badFd.stderr).trim());
  const traceDirFiles = fs.readdirSync(path.dirname(process.env.HATSU_SHELL_COVERAGE_EXEC));
  fs.writeFileSync('wrapper-leftovers', JSON.stringify(traceDirFiles.filter((f) => !f.startsWith('run-'))));
  fs.writeFileSync(process.env.HATSU_COVERAGE_PATH, 'SF:' + process.cwd() + '/scripts/target.sh\\nDA:1,1\\nend_of_record\\n');
  process.exit(0);
});
`);
  const result = run(['--capture', 'sample', 'bash', 'scripts/fixture.sh', '--target', target], {
    FAKE_REAL_BASH: coverageBash!,
    FAKE_BASH_ENV: bashEnvScript,
    BASH_ENV: bashEnvScript,
  });
  expect(result.status, result.stderr).toBe(0);
  expect(readFileSync(join(root, 'wrapper-exit'), 'utf8')).toBe('7,7,1,1');
  expect(JSON.parse(readFileSync(join(root, 'wrapper-leftovers'), 'utf8'))).toEqual([]);
  expect(existsSync(bashEnvProbe)).toBe(false);
  const trace = readFileSync(join(root, 'target-trace'), 'utf8');
  expect(trace).toContain(longArg);
  const bashcovLines = trace.split('\n').filter((line) => /^\++BASHCOV>/.test(line));
  expect(bashcovLines.length).toBeGreaterThanOrEqual(16);
  expect(bashcovLines.every((line) => line.split('TRACESEP').length >= 5)).toBe(true);
});

it.skipIf(!coverageBash)('forwards SIGTERM to a target trapping TERM, preserves its exit status, and cleans wrapper temp files', () => {
  const target = 'scripts/target.sh';
  const { root, run } = fixture('bash', 'echo fixture\n', target);
  writeFileSync(join(root, target), `#!/usr/bin/env bash
touch ready.flag
on_term() {
  echo "caught-term" >&2
  kill "$kid" 2>/dev/null || true
  exit 5
}
trap on_term TERM
sleep 30 &
kid=$!
wait "$kid"
`);
  writeFileSync(join(root, 'bin/ruby'), `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const args = process.argv.slice(2);
if (args[1].includes('cache_file')) {
  for (let i = 2; i < args.length; i += 2) console.log(path.join(process.cwd(), 'gems', args[i] + '-' + args[i + 1] + '.gem'));
  process.exit(0);
}
if (args.includes('--version')) { console.log('bashcov ' + args[3]); process.exit(0); }
const child = spawn(process.env.HATSU_SHELL_COVERAGE_EXEC, [], {
  env: {
    ...process.env,
    HATSU_SHELL_COVERAGE_PS4: '+BASHCOV>TRACESEP\${LINENO-}TRACESEP\${BASH_SOURCE-}TRACESEP\${PWD-}TRACESEP\${OLDPWD-}TRACESEP',
    HATSU_SHELL_COVERAGE_TRACE_FD: '2',
    HATSU_SHELL_COVERAGE_BASH: process.env.FAKE_REAL_BASH,
  },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let err = '';
child.stderr.on('data', (chunk) => { err += chunk; });
const timer = setInterval(() => {
  if (fs.existsSync('ready.flag')) {
    clearInterval(timer);
    child.kill('SIGTERM');
  }
}, 20);
child.on('close', (status) => {
  clearInterval(timer);
  const leftovers = fs.readdirSync(path.dirname(process.env.HATSU_SHELL_COVERAGE_EXEC)).filter((f) => !f.startsWith('run-'));
  fs.writeFileSync('term-result', JSON.stringify({ status, err, leftovers }));
  fs.writeFileSync(process.env.HATSU_COVERAGE_PATH, 'SF:' + process.cwd() + '/scripts/target.sh\\nDA:1,1\\nend_of_record\\n');
  process.exit(0);
});
`);
  const result = run(['--capture', 'sample', 'bash', 'scripts/fixture.sh', '--target', target], {
    FAKE_REAL_BASH: coverageBash!,
  });
  expect(result.status, result.stderr).toBe(0);
  const termResult = JSON.parse(readFileSync(join(root, 'term-result'), 'utf8'));
  expect(termResult.status).toBe(5);
  expect(termResult.err).toContain('caught-term');
  expect(termResult.leftovers).toEqual([]);
});

it('runs uninstrumented without Bashcov, says so, removes a stale report, and keeps the fixture red', () => {
  const { root, run, report } = fixture();
  expect(run(capture).status).toBe(0);
  const plain = run(capture, { FAKE_NO_BASHCOV: '1' });
  expect(plain.status).toBe(0);
  expect(plain.stderr).toContain('ran uninstrumented (bashcov 4.0.0 with simplecov 1.3.2 and simplecov-lcov 0.9.0 is not installed');
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
