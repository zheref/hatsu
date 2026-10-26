#!/usr/bin/env node
// Offline executable proof of the prepared readiness and shipped Cloud bootstrap snippets.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, chmodSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { test } from 'vitest';
test('reviewed bootstrap pins gate prepared readiness and shipped Cloud execution', () => {
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const contract = JSON.parse(readFileSync(join(root, 'nen/contract.json'), 'utf8')).dependency;
const digest = (bytes: string) => createHash('sha256').update(bytes).digest('hex');
const policy = readFileSync(join(root, 'scripts/workflow_runner_policy_check.rb'), 'utf8');
const prepared = policy.split('READINESS_INTEGRITY_BOOTSTRAP = {')[1];
assert.ok(prepared, 'validator preparation must carry a literal integrity form');
const body = prepared.split(`"run" => <<~'RUN'.strip\n`)[1].split('\n  RUN')[0]
  .split('\n').map(line => line.slice(4)).join('\n');
const cloudDoc = readFileSync(join(root, 'docs/using/cursor.md'), 'utf8').split('### Cursor Cloud agents')[1];
const cloud = JSON.parse(cloudDoc.split('```json\n')[1].split('\n```')[0]).install as string;
assert.ok(cloud.includes(contract.bootstrap.scriptSha256), 'Cloud script pin must move with the contract');
assert.ok(cloud.includes(contract.bootstrap.sha256['linux-x64']), 'Cloud binary pin must move with the contract');
assert.ok(cloud.includes(`--ref ${contract.pinned_ref} --source ${contract.source}`), 'Cloud ref and source must move with the contract');
const provenance = contract.bootstrap.scriptSha256Provenance;
assert.equal(provenance.ref, contract.pinned_ref);
assert.equal(provenance.path, contract.bootstrap.script_path_in_source);
assert.equal(provenance.sha256, contract.bootstrap.scriptSha256);
assert.match(provenance.commit, /^[0-9a-f]{40}$/);
const work = mkdtempSync(join(tmpdir(), 'bootstrap-integrity-'));
try {
  for (const mode of ['prepared-readiness', 'cloud']) {
    for (const failure of ['none', 'script', 'binary', 'missing-script-pin', 'malformed-binary-pin']) {
      const dir = join(work, `${mode}-${failure}`);
      mkdirSync(join(dir, 'tools'), { recursive: true });
      const bin = join(dir, 'nen');
      const binary = '#!/bin/sh\ntouch "$BINARY_RAN"\necho 0.28.0\n';
      writeFileSync(bin, binary); chmodSync(bin, 0o755);
      const script = '#!/bin/sh\ntouch "$SCRIPT_RAN"\nprintf "%s\\n" "$FAKE_BINARY"\n';
      writeFileSync(join(dir, 'download'), failure === 'script' ? script + '# changed bytes\n' : script);
      const curl = '#!/bin/sh\nwhile [ "$1" != -o ]; do shift; done\ncp "$DOWNLOAD" "$2"\n';
      writeFileSync(join(dir, 'tools/curl'), curl); chmodSync(join(dir, 'tools/curl'), 0o755);
      // Linux's sha256sum is shasum's -c mode on a Darwin fixture host.
      if (spawnSync('sh', ['-c', 'command -v sha256sum']).status !== 0) {
        writeFileSync(join(dir, 'tools/sha256sum'), '#!/bin/sh\nexec shasum -a 256 "$@"\n');
        chmodSync(join(dir, 'tools/sha256sum'), 0o755);
      }
      const scriptSha = failure === 'missing-script-pin' ? '' : digest(script);
      const binarySha = failure === 'malformed-binary-pin' ? 'bad' : failure === 'binary' ? '0'.repeat(64) : digest(binary);
      let command = mode === 'prepared-readiness' ? body : cloud;
      if (mode === 'cloud') {
        command = command.replaceAll(contract.bootstrap.scriptSha256, scriptSha)
          .replaceAll(contract.bootstrap.sha256['linux-x64'], binarySha);
      }
      const output = join(dir, 'output');
      writeFileSync(output, '');
      const ran = spawnSync('bash', ['-c', command], { cwd: dir, encoding: 'utf8', env: {
        ...process.env, HOME: dir, PATH: `${join(dir, 'tools')}:${process.env.PATH}`,
        DOWNLOAD: join(dir, 'download'), FAKE_BINARY: bin, RUNNER_TEMP: dir,
        SCRIPT_RAN: join(dir, 'script-ran'), BINARY_RAN: join(dir, 'binary-ran'),
        GITHUB_OUTPUT: output, PINNED_REF: contract.pinned_ref,
        SCRIPT_SHA256: scriptSha, BINARY_SHA256: binarySha,
      }});
      if (failure === 'none') {
        assert.equal(ran.status, 0, `${mode}: ${ran.stdout}${ran.stderr}`);
        assert.ok(existsSync(join(dir, 'script-ran')));
        assert.ok(existsSync(join(dir, 'binary-ran')));
      } else {
        assert.notEqual(ran.status, 0, `${mode}/${failure} must refuse`);
        assert.ok(!existsSync(join(dir, 'binary-ran')), `${mode}/${failure} executed binary`);
        assert.ok(!existsSync(join(dir, '.local/bin/nen')), `${mode}/${failure} linked binary`);
        if (failure !== 'binary') assert.ok(!existsSync(join(dir, 'script-ran')), `${mode}/${failure} executed bootstrap`);
        if (mode === 'prepared-readiness') assert.equal(readFileSync(output, 'utf8'), '', 'must not publish binary output before verification');
      }
    }
  }
  console.log('PASS bootstrap integrity: prepared readiness and shipped Cloud reject changed scripts, wrong binaries and absent/malformed digests before execution/link');
} finally { rmSync(work, { recursive: true, force: true }); }

});
