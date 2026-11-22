// Run focused CLI fixtures once under Node's descendant-aware coverage.
// The test subprocess receives the declared command without a shell.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { appendFileSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { test } from 'node:test';

const commandKey = 'HATSU_CLI_COVERAGE_COMMAND';
const [mode, lane, ...args] = process.argv.slice(2);

const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
const sourceDigests = (files: string[]) => Object.fromEntries(files.map(path => [path, sha256(readFileSync(path))]));

function measured(report: Buffer, files: string[], shellSource?: string) {
  const captured = [...report.toString('utf8').matchAll(/^SF:(.+)$/gm)].map(match => match[1]);
  const hasShell = shellSource !== undefined && captured.includes(shellSource);
  const expected = hasShell ? [...files, shellSource] : [...files];
  assert.deepEqual(captured.sort(), expected.sort(), 'LCOV must contain every declared production source exactly once');
  return captured;
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
  const provenance = `coverage/${lane}/cli/provenance.json`;
  const shellReport = `coverage/${lane}/lcov.info`;
  if (mode === '--verify') {
    assert.equal(separator, -1);
    const bytes = readFileSync(report);
    const recorded = JSON.parse(readFileSync(provenance, 'utf8'));
    const rerun = `rerun nen shu test --lane ${lane}`;
    assert.ok(recorded?.lane === lane && recorded?.report === sha256(bytes),
      `LCOV report changed since capture; ${rerun}`);
    const captured = measured(bytes, files, shellSource);
    assert.deepEqual(sourceDigests(captured), recorded.files, `LCOV source changed since capture; ${rerun}`);
    console.log(`node-cli-coverage: read ${report} for ${files.length} TypeScript sources`);
    if (shellSource) console.log(`node-cli-coverage: optional shell source ${shellSource} ${captured.includes(shellSource) ? 'captured' : 'unmeasured'}`);
  } else {
    assert.equal(mode, '--capture');
    assert.ok(separator >= 0 && args[separator + 1], 'declare a focused fixture command after --');
    mkdirSync(dirname(report), { recursive: true });
    rmSync(report, { force: true });
    rmSync(provenance, { force: true });
    if (shellSource) rmSync(shellReport, { force: true });
    const pending = report + '.' + process.pid + '.tmp';
    const pendingProvenance = provenance + '.' + process.pid + '.tmp';
    const before = sourceDigests(shellSource ? [...files, shellSource] : files);
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
      measured(readFileSync(pending), files);
      if (shellSource && existsSync(shellReport)) {
        const shell = readFileSync(shellReport);
        measured(shell, [shellSource]);
        appendFileSync(pending, '\n' + shell.toString('utf8'));
      } else if (shellSource) {
        console.log(`node-cli-coverage: optional shell source ${shellSource} unmeasured`);
      }
      const bytes = readFileSync(pending);
      const captured = measured(bytes, files, shellSource);
      const after = sourceDigests(captured);
      for (const path of captured) assert.equal(after[path], before[path], path + ' changed during coverage capture');
      writeFileSync(pendingProvenance, JSON.stringify({ lane, report: sha256(bytes), files: after }) + '\n');
      renameSync(pending, report);
      renameSync(pendingProvenance, provenance);
    } finally {
      rmSync(pending, { force: true });
      rmSync(pendingProvenance, { force: true });
    }
  }
}
