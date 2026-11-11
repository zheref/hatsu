// Run focused CLI fixtures once under Node's descendant-aware coverage.
// The test subprocess receives the declared command without a shell.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync } from 'node:fs';
import { dirname } from 'node:path';
import { test } from 'node:test';

const commandKey = 'HATSU_CLI_COVERAGE_COMMAND';
const [mode, lane, ...args] = process.argv.slice(2);

function verify(report: string, files: string[], shellSource?: string) {
  const captured = [...readFileSync(report, 'utf8').matchAll(/^SF:(.+)$/gm)].map(match => match[1]);
  const hasShell = shellSource !== undefined && captured.includes(shellSource);
  const expected = hasShell ? [...files, shellSource] : [...files];
  assert.deepEqual(captured.sort(), expected.sort(), 'LCOV must contain every declared production source exactly once');
  return hasShell;
}

if (!mode && process.env[commandKey]) {
  test('declared focused CLI fixtures', () => {
    const [exe, ...argv] = JSON.parse(process.env[commandKey]!);
    const result = spawnSync(exe, argv, { stdio: 'inherit' });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.signal ?? 'focused CLI fixtures failed');
  });
} else {
  assert.match(lane ?? '', /^[a-z][a-z0-9-]*$/);
  const shellSource = args[0] === '--shell-source' ? args.splice(0, 2)[1] : undefined;
  const separator = args.indexOf('--');
  const files = separator < 0 ? args : args.slice(0, separator);
  assert.ok(files.length && files.every(path => /^scripts\/[a-z0-9_]+\.m?ts$/.test(path)), 'declare the exact production source paths');
  if (shellSource !== undefined) assert.match(shellSource, /^scripts\/[a-z0-9_]+\.sh$/);
  const report = `coverage/${lane}/cli/lcov.info`;
  const shellReport = `coverage/${lane}/lcov.info`;
  if (mode === '--verify') {
    assert.equal(separator, -1);
    const hasShell = verify(report, files, shellSource);
    console.log(`node-cli-coverage: read ${report} for ${files.length} TypeScript sources`);
    if (shellSource) console.log(`node-cli-coverage: optional shell source ${shellSource} ${hasShell ? 'captured' : 'unmeasured'}`);
  } else {
    assert.equal(mode, '--capture');
    assert.ok(separator >= 0 && args[separator + 1], 'declare a focused fixture command after --');
    mkdirSync(dirname(report), { recursive: true });
    rmSync(report, { force: true });
    const pending = report + '.' + process.pid + '.tmp';
    try {
      const result = spawnSync(process.execPath, [
        '--test', '--experimental-test-coverage',
        ...files.map(path => '--test-coverage-include=' + path),
        '--test-reporter=spec', '--test-reporter=lcov',
        '--test-reporter-destination=stdout', '--test-reporter-destination=' + pending,
        import.meta.filename,
      ], { stdio: 'inherit', env: { ...process.env, [commandKey]: JSON.stringify(args.slice(separator + 1)) } });
      assert.ifError(result.error);
      assert.equal(result.status, 0, result.signal ?? 'coverage capture failed');
      verify(pending, files);
      if (shellSource && existsSync(shellReport)) {
        verify(shellReport, [shellSource]);
        appendFileSync(pending, '\n' + readFileSync(shellReport, 'utf8'));
      } else if (shellSource) {
        console.log(`node-cli-coverage: optional shell source ${shellSource} unmeasured`);
      }
      renameSync(pending, report);
    } finally {
      rmSync(pending, { force: true });
    }
  }
}
