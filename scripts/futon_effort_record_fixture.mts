#!/usr/bin/env node
// #154: a Futon claim is local to the Git common dir and fails closed when stale.
// HR-5: the run manifest records every PR the run opened, whatever its base, and an idle run's rows.
import assert from 'node:assert/strict';
import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, renameSync, rmSync, symlinkSync, utimesSync, writeFileSync } from 'node:fs';
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
  const git = (argv: string[]) => execute('git', ['-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid', ...argv]);
  mkdirSync(join(root, 'nen'));
  // SEC-15: the idle profile is read from the remote default branch only; publish to origin/main.
  const commitWorkflow = (value: unknown, message: string, publish = true) => {
    writeFileSync(join(root, 'nen', 'workflow.json'), JSON.stringify(value));
    expectStatus(git(['add', 'nen/workflow.json']), 0, `stage ${message}`);
    expectStatus(git(['commit', '-q', '-m', message]), 0, `commit ${message}`);
    if (publish) expectStatus(git(['update-ref', 'refs/remotes/origin/main', 'HEAD']), 0, `publish ${message}`);
  };
  commitWorkflow({}, 'empty declaration');
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
if(process.argv.some((a)=>/(^|\s)--idle(\s|$)/.test(a))) process.exit(3);
else if(process.argv[2]==='parse'&&process.argv[3]==='futon') console.log(JSON.stringify({repo:'zheref/hatsu',label:process.env.FAKE_BAND?null:'model/gpt',band:process.env.FAKE_BAND||null}));
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
  rmSync(metadata);
  renameSync(parked, metadata);
  const manifestCall = (argv: string[], env: Record<string, string> = {}) =>
    execute(process.execPath, [script, ...argv], env);
  expectStatus(manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt --idle --idle']),
    1, 'a doubled --idle refused');
  expectStatus(manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt then getsuga --idle']),
    1, '--idle after then refused');
  const idleStarted = manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt --idle then rikugan']);
  expectStatus(idleStarted, 0, 'idle run starts with --idle stripped before nen parse');
  const idleId = /run ([0-9a-f]{32}) recorded/.exec(String(idleStarted.stdout))?.[1];
  assert.ok(idleId, 'idle start returns a run id');
  assert.match(String(idleStarted.stdout), /pre-answered publish-offer → refuse/, 'publish-offer is refused under idle');
  assert.match(String(idleStarted.stdout), /pre-answered wrap-up → default/, 'a starred row takes its default');
  const status = () => JSON.parse(String(manifestCall(['status', '--repo', root, '--run', idleId]).stdout));
  const fresh = status();
  assert.equal(fresh.contract, 'hatsu.futon.run/v0.2');
  assert.equal(fresh.idle.localSlotFrees, 'merged');
  assert.equal(fresh.idle.terminal, 'ready-at-prompt-or-integration');
  assert.ok(fresh.idle.decisions.length > 0 && fresh.idle.decisions.every((d: { resolution: string }) =>
    ['default', 'hold', 'refuse'].includes(d.resolution)), 'every ask-once row carries one resolution');
  const append = (argv: string[], env: Record<string, string> = {}) =>
    manifestCall(['append', '--repo', root, '--run', idleId, ...argv], env);
  expectStatus(append(['--pr', '21', '--kind', 'delivery', '--issue', '154']), 0, 'delivery PR appended');
  expectStatus(append(['--pr', '30', '--kind', 'integration'], { FAKE_BASE: 'main', FAKE_BODY: 'integration' }), 0,
    'a PR into the default branch is appended too');
  expectStatus(append(['--pr', '21', '--kind', 'delivery', '--issue', '154'], { FAKE_SHA: 'c'.repeat(40) }), 0,
    'a re-append refreshes the head, never duplicates');
  expectStatus(append(['--pr', '21', '--kind', 'integration']), 1, 'a recorded PR cannot change kind');
  expectStatus(append(['--pr', '31', '--kind', 'delivery']), 1, 'a delivery PR names its issue');
  expectStatus(append(['--pr', '32', '--kind', 'delivery', '--issue', '154'], { FAKE_CREATED: '2000-01-01T00:00:00Z' }), 1,
    'a PR opened before the run is refused');
  expectStatus(append(['--pr', '33', '--kind', 'other']), 1, 'an unknown kind refused');
  expectStatus(manifestCall(['park', '--repo', root, '--run', idleId, '--issue', '160', '--row', 'port-siblings']), 0, 'effort parked');
  expectStatus(manifestCall(['park', '--repo', root, '--run', idleId, '--issue', '161', '--row', 'Bad Row']), 1, 'a malformed row refused');
  const after = status();
  assert.deepEqual(after.prs.map((e: { pr: number; base: string; kind: string; head: string }) => [e.pr, e.base, e.kind, e.head]),
    [[30, 'main', 'integration', 'a'.repeat(40)], [21, 'stack', 'delivery', 'c'.repeat(40)]]);
  assert.deepEqual(after.parked.map((e: { issue: number; row: string }) => [e.issue, e.row]), [[160, 'port-siblings']]);
  assert.equal(after.overBudget, false);
  writeFileSync(join(root, '.git', 'hatsu', 'futon', `run-${runId}.json`), JSON.stringify({
    contract: 'hatsu.futon.run/v0.1', id: runId, repo: 'zheref/hatsu', invocation, selector: 'model/gpt', startedAt: '1999-01-01T00:00:00Z' }));
  expectStatus(manifestCall(['append', '--repo', root, '--run', runId, '--pr', '21', '--kind', 'delivery', '--issue', '154']), 1,
    'a v0.1 run still refuses an append');
  expectStatus(manifestCall(['park', '--repo', root, '--run', runId, '--issue', '160', '--row', 'wrap-up']), 1,
    'a v0.1 run refuses a park');
  const legacy = manifestCall(['status', '--repo', root, '--run', runId]);
  expectStatus(legacy, 2, 'status on a v0.1 run exits 2: the then gate is held, never vacuously met');
  const legacyOut = JSON.parse(String(legacy.stdout));
  assert.equal(legacyOut.manifest, 'absent');
  assert.equal('prs' in legacyOut, false, 'a v0.1 status omits prs');
  const overId = 'f'.repeat(32);
  writeFileSync(join(root, '.git', 'hatsu', 'futon', `run-${overId}.json`), JSON.stringify({
    contract: 'hatsu.futon.run/v0.2', id: overId, repo: 'zheref/hatsu', invocation, selector: 'model/gpt',
    startedAt: '1999-01-01T00:00:00Z', idle: { ...fresh.idle, budget: { minutes: 1, tokens: 1 } }, prs: [], parked: [] }));
  assert.equal(JSON.parse(String(manifestCall(['status', '--repo', root, '--run', overId]).stdout)).overBudget, true,
    'a run past idle.budget.minutes reads overBudget');
  const lock = join(root, '.git', 'hatsu', 'futon', `run-${idleId}.json.lock`);
  writeFileSync(lock, '');
  utimesSync(lock, new Date('2000-01-01T00:00:00Z'), new Date('2000-01-01T00:00:00Z'));
  expectStatus(manifestCall(['park', '--repo', root, '--run', idleId, '--issue', '162', '--row', 'budget']), 0,
    'a crashed writer\'s stale lock is cleared');
  assert.equal(existsSync(lock), false, 'the stale lock is gone after the park');
  expectStatus(manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon --idle hatsu@model/gpt']), 0,
    '--idle typed before @ is stripped before nen parse');
  const idleStart = (env: Record<string, string> = {}) => manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt --idle'], env);
  commitWorkflow({ idle: { decisions: { 'wrap-up': 'always' } } }, 'out of vocabulary');
  expectStatus(idleStart(), 1, 'a resolution outside default|hold|refuse refused');
  for (const [row, resolution] of [['publish-offer', 'default'], ['publish-offer', 'hold'], ['host-nen-link', 'default'],
      ['harness-attribution-switch', 'default'], ['missing-maintainer-choice', 'default'], ['port-siblings', 'default']]) {
    commitWorkflow({ idle: { decisions: { [row]: resolution } } }, `${row} ${resolution}`);
    expectStatus(idleStart(), 1, `the floor refuses ${row}: ${resolution}`);
  }
  commitWorkflow({ monitor: { localSlotFrees: 'ready+prompted' } }, 'slot widened');
  expectStatus(idleStart(), 1, 'monitor.localSlotFrees is the ruled merged only (HR-257)');
  commitWorkflow({ branch: { base: 'main' }, idle: { decisions: { 'wrap-up': 'hold', 'mode-unknown': 'default' } } }, 'partial map');
  const partial = idleStart();
  expectStatus(partial, 0, 'a partial idle.decisions with valid values starts');
  const partialOut = String(partial.stdout);
  assert.match(partialOut, /pre-answered wrap-up → hold/);
  assert.match(partialOut, /pre-answered mode-unknown → default/);
  assert.match(partialOut, /pre-answered cleanup-plan → hold/, 'an unnamed row holds');
  assert.match(partialOut, /pre-answered publish-offer → refuse/, 'an unnamed publish-offer refuses');
  assert.match(partialOut, /idle profile read from origin\/main at [0-9a-f]{40}/, 'the committed source is recorded');
  writeFileSync(join(root, 'nen', 'workflow.json'), JSON.stringify({ idle: { decisions: { 'publish-offer': 'default' } } }));
  expectStatus(idleStart(), 0, 'an uncommitted working-tree edit is never read');
  const good = String(git(['rev-parse', 'HEAD']).stdout).trim();
  expectStatus(git(['commit', '-q', '-a', '-m', 'bad on HEAD']), 0, 'commit a forbidden map on HEAD');
  const based = idleStart();
  expectStatus(based, 0, 'the default branch\'s committed copy wins over HEAD');
  assert.match(String(based.stdout), new RegExp(`idle profile read from origin/main at ${good}`));
  // SEC-15: HEAD's branch.base never picks the ref; a pushed branch it names is never read.
  commitWorkflow({ branch: { base: 'evil' }, idle: { decisions: { 'cleanup-plan': 'default' } } }, 'base redirected', false);
  expectStatus(git(['update-ref', 'refs/remotes/origin/evil', 'HEAD']), 0, 'push the redirect target');
  const redirected = idleStart();
  expectStatus(redirected, 0, 'a branch.base on HEAD never redirects the read');
  assert.match(String(redirected.stdout), new RegExp(`idle profile read from origin/main at ${good}`));
  assert.match(String(redirected.stdout), /pre-answered cleanup-plan → hold/, 'the redirected default never applies');
  expectStatus(idleStart({ FAKE_DEFAULT: 'trunk' }), 1, 'an unfetched default branch refuses the start, never falls back to HEAD');
  const empty = String(git(['hash-object', '-t', 'tree', '/dev/null']).stdout).trim();
  const bare = String(git(['commit-tree', empty, '-m', 'no declaration']).stdout).trim();
  expectStatus(git(['update-ref', 'refs/remotes/origin/bare', bare]), 0, 'a default branch with no nen/workflow.json');
  const refused = idleStart({ FAKE_DEFAULT: 'bare' });
  expectStatus(refused, 1, 'a default branch with no nen/workflow.json refuses the start');
  assert.match(String(refused.stderr), /has no nen\/workflow\.json/, 'the refusal names its reason');
  console.log('futon-effort: start, bind, refresh, missing/stale/default/foreign-selector refusals, the run manifest and the idle floor passed');
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
