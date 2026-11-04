import { test, expect } from 'vitest';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
const template = readFileSync(new URL('../templates/pr-readiness.yml', import.meta.url), 'utf8');
const step = (id: string) => template.split(`        id: ${id}\n`)[1]!.split('\n      - name:')[0]!.split('        run: |\n')[1]!.split('\n').map(line => line.slice(10)).join('\n');
const script = step('nen');
const pinScript = step('pin');
const digest = (text: string) => createHash('sha256').update(text).digest('hex');
for (const kind of ['valid', 'script mismatch', 'binary mismatch', 'missing digest', 'fallback forbidden', 'trusted valid', 'trusted missing digest'] as const) {
  test(`readiness bootstrap: ${kind}`, () => {
    const root = mkdtempSync(join(tmpdir(), 'readiness-integrity-'));
    try {
      mkdirSync(join(root, 'bin')); mkdirSync(join(root, 'tmp'));
      const binary = '#!/bin/sh\ntouch "$TEST_ROOT/versioned"\necho fixture\n';
      writeFileSync(join(root, 'nen'), binary, { mode: 0o755 });
      const bootstrap = '#!/bin/sh\ntouch "$TEST_ROOT/executed"\nprintf "%s\\n" "$TEST_ROOT/nen"\n';
      writeFileSync(join(root, 'bootstrap'), bootstrap);
      writeFileSync(join(root, 'bin', 'curl'), '#!/bin/sh\nwhile [ "$1" != "-o" ]; do shift; done\ncp "$TEST_ROOT/bootstrap" "$2"\n', { mode: 0o755 });
      const integrity = { scriptSha256: kind === 'script mismatch' ? '0'.repeat(64) : digest(bootstrap), sha256: { 'darwin-arm64': digest(binary), 'linux-x64': digest(binary), 'windows-x64': digest(binary) } };
      if (kind === 'binary mismatch') for (const key of Object.keys(integrity.sha256)) integrity.sha256[key as keyof typeof integrity.sha256] = '0'.repeat(64);
      if (kind.startsWith('trusted')) {
        mkdirSync(join(root, '.trusted', 'nen'), { recursive: true });
        writeFileSync(join(root, '.trusted', 'nen', 'contract.json'), JSON.stringify({ dependency: { pinned_ref: 'v1', bootstrap: kind === 'trusted valid' ? integrity : {} } }));
      }
      const env = { ...process.env, PATH: `${join(root, 'bin')}:${process.env.PATH}`, TEST_ROOT: root, RUNNER_TEMP: join(root, 'tmp'), GITHUB_OUTPUT: join(root, 'pin-out'), TENKAI_FALLBACK_REF: 'v1', TENKAI_PIN_FALLBACK_ALLOWED: kind === 'fallback forbidden' ? 'false' : 'true', TENKAI_FALLBACK_SCRIPT_SHA256: kind === 'missing digest' || kind.startsWith('trusted') ? '' : integrity.scriptSha256, TENKAI_FALLBACK_BINARY_SHA256: kind === 'missing digest' || kind.startsWith('trusted') ? '' : integrity.sha256['linux-x64'] };
      const pin = spawnSync('bash', ['-c', pinScript], { cwd: root, encoding: 'utf8', env });
      let result = pin;
      if (pin.status === 0) {
        const output = Object.fromEntries(readFileSync(join(root, 'pin-out'), 'utf8').trim().split('\n').map(line => line.split('=')));
        result = spawnSync('bash', ['-c', script], { cwd: root, encoding: 'utf8', env: { ...env, GITHUB_OUTPUT: join(root, 'out'), PINNED_REF: output.ref!, SCRIPT_SHA256: output.script_sha!, BINARY_SHA256: output.binary_sha! } });
      }
      if ((kind === 'valid' || kind === 'trusted valid')) expect(result.status, result.stderr + result.stdout).toBe(0);
      else expect(result.status, result.stderr + result.stdout).not.toBe(0);
      if ((kind === 'valid' || kind === 'trusted valid')) expect(readFileSync(join(root, 'out'), 'utf8')).toContain(`bin=${root}/nen`);
      if (kind !== 'valid' && kind !== 'trusted valid') expect(spawnSync('test', ['-e', join(root, 'versioned')]).status).toBe(1);
      if (kind === 'script mismatch' || kind === 'missing digest' || kind === 'fallback forbidden') expect(spawnSync('test', ['-e', join(root, 'executed')]).status).toBe(1);
    } finally { rmSync(root, { recursive: true, force: true }); }
  });
}
