#!/usr/bin/env node
// #154: a Futon claim is local to the Git common dir and fails closed when stale.
import assert from 'node:assert/strict';
import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, renameSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('./futon_effort_record.mts', import.meta.url));
const scratch = mkdtempSync(join(tmpdir(), 'hatsu-futon-effort-'));
const root = join(scratch, 'repo');
const bin = join(scratch, 'bin');
mkdirSync(root);
mkdirSync(bin);
function execute(exe: string, argv: string[], env: Record<string, string> = {}): ReturnType<typeof spawnSync> {
  return spawnSync(exe, argv, { cwd: root, encoding: 'utf8', env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, ...env } });
}
function call(verb: 'bind' | 'verify', extra: string[] = [], env: Record<string, string> = {}): ReturnType<typeof spawnSync> {
  return execute(process.execPath, [script, verb, '--repo', root, '--pr', '21', ...extra], env);
}
function expectStatus(result: ReturnType<typeof spawnSync>, status: number, name: string): void {
  assert.equal(result.status, status, `${name}: ${result.stdout}${result.stderr}`);
}
try {
  expectStatus(execute('git', ['init', '-q']), 0, 'git init');
  const gh = join(bin, 'gh');
  writeFileSync(gh, `#!/usr/bin/env node
const a=process.argv.slice(2); const e=process.env;
if(a[0]==='repo'&&a[1]==='view') console.log(JSON.stringify({nameWithOwner:'zheref/hatsu',defaultBranchRef:{name:e.FAKE_DEFAULT||'main'}}));
else if(a[0]==='pr'&&a[1]==='view') console.log(JSON.stringify({baseRefName:e.FAKE_BASE||'stack',headRefName:'gpt/kurapika/feature',headRefOid:e.FAKE_SHA||'a'.repeat(40),state:e.FAKE_STATE||'OPEN',isCrossRepository:false,createdAt:e.FAKE_CREATED||'2099-01-01T00:00:00Z',body:e.FAKE_BODY||'Closes #154'}));
else if(a[0]==='issue'&&a[1]==='view') console.log(JSON.stringify({state:'OPEN',labels:[{name:e.FAKE_LABEL||'model/gpt'}]}));
else process.exit(2);
`);
  chmodSync(gh, 0o755);
  const nen = join(bin, 'nen');
  writeFileSync(nen, `#!/usr/bin/env node
if(process.argv[2]==='parse'&&process.argv[3]==='futon') console.log(JSON.stringify({repo:'zheref/hatsu',label:process.env.FAKE_BAND?null:'model/gpt',band:process.env.FAKE_BAND||null}));
else process.exit(2);
`);
  chmodSync(nen, 0o755);
  const invocation = 'hatsu:futon hatsu@model/gpt then getsuga+mugetsu';
  const started = execute(process.execPath, [script, 'start', '--repo', root, '--invocation', invocation]);
  expectStatus(started, 0, 'run start');
  const runId = /run ([0-9a-f]{32}) recorded/.exec(String(started.stdout))?.[1];
  assert.ok(runId, 'start returns a run id');
  const bind = ['--run', runId, '--issue', '154',
    '--base', 'stack', '--head', 'gpt/kurapika/feature', '--sha', 'a'.repeat(40)];
  expectStatus(call('bind', bind), 0, 'initial bind');
  const saved = join(root, '.git', 'hatsu', 'futon', 'pr-21.json');
  assert.ok(existsSync(saved), 'claim lives in Git common directory');
  assert.equal(JSON.parse(readFileSync(saved, 'utf8')).issue, 154);
  const original = readFileSync(saved, 'utf8');
  writeFileSync(saved, JSON.stringify({ ...JSON.parse(original), pr: 22 }));
  expectStatus(call('verify'), 1, 'wrong PR in saved record refused');
  writeFileSync(saved, original);
  expectStatus(execute(process.execPath, [script, 'verify', '--repo', root, '--pr', '22']),
    1, 'missing record refused');
  expectStatus(call('verify'), 0, 'live claim');
  expectStatus(call('verify', [], { FAKE_SHA: 'b'.repeat(40) }), 1, 'stale head refused');
  expectStatus(call('verify', [], { FAKE_BASE: 'main' }), 1, 'default branch refused');
  expectStatus(call('verify', [], { FAKE_LABEL: 'model/other' }), 1, 'selector mismatch refused');
  expectStatus(call('bind', bind, { FAKE_CREATED: '2000-01-01T00:00:00Z' }), 1,
    'run created after PR refused');
  expectStatus(call('bind', bind, { FAKE_BODY: 'Closes #155' }), 1,
    'PR without selected issue reference refused');
  const bandStarted = execute(process.execPath, [script, 'start', '--repo', root,
    '--invocation', 'hatsu:futon hatsu@high'], { FAKE_BAND: 'high' });
  expectStatus(bandStarted, 0, 'band run starts');
  const bandRunId = /run ([0-9a-f]{32}) recorded/.exec(String(bandStarted.stdout))?.[1];
  assert.ok(bandRunId);
  expectStatus(call('bind', bind.map((part) => part === runId ? bandRunId : part),
    { FAKE_BAND: 'high' }), 1, 'unmigrated severity band refused');
  expectStatus(call('bind', bind.map((part) => part === '154' ? '155' : part),
    { FAKE_BODY: 'Closes #155' }), 1, 'ownership rewrite refused');
  expectStatus(call('bind', bind.map((part) => part === 'a'.repeat(40) ? 'b'.repeat(40) : part),
    { FAKE_SHA: 'b'.repeat(40) }), 0, 'same effort refreshes head');
  expectStatus(call('verify', [], { FAKE_SHA: 'b'.repeat(40) }), 0, 'refreshed head verifies');
  const metadata = join(root, '.git', 'hatsu');
  const parked = join(scratch, 'parked-metadata');
  renameSync(metadata, parked);
  symlinkSync(parked, metadata);
  expectStatus(call('verify', [], { FAKE_SHA: 'b'.repeat(40) }), 1, 'symlinked metadata parent refused');
  console.log('futon-effort: start, bind, refresh, and missing/stale/default/foreign-selector refusals passed');
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
