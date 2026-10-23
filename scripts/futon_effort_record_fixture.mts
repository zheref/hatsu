#!/usr/bin/env node
// #154: a Futon claim is local to the Git common dir and fails closed when stale.
// HR-5 / zheref/hatsu#423: start opens nen's run manifest (stubbed here) with the same id and the
// pre-answered rows as its idleAnswers; the record keeps ownership and the profile, never prs or parks.
// zheref/hatsu#424: --dry-run beside --idle is lifted off before nen's parse and recorded as dry.
import assert from 'node:assert/strict';
import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, realpathSync, renameSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
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
  const nenLog = join(scratch, 'nen.log');
  // parse futon reads --idle itself (nen 0.26.0) and knows no --dry-run: exit 3 proves the record lifted it.
  writeFileSync(nen, `#!/usr/bin/env node
const a=process.argv.slice(2); const e=process.env;
require('fs').appendFileSync(${JSON.stringify(nenLog)}, JSON.stringify(a)+'\\n');
if(a[0]==='parse'&&a[1]==='futon'){ const line=a[4]||'';
  if(/(^|\\s)--dry-run(\\s|$)/.test(line)) process.exit(3);
  const idle=/(^|\\s)--idle(\\s|$)/.test(line);
  console.log(JSON.stringify(e.FAKE_NO_IDLE?{repo:'zheref/hatsu',label:'model/gpt',band:null}:{repo:'zheref/hatsu',label:e.FAKE_BAND?null:'model/gpt',band:e.FAKE_BAND||null,idle})); }
else if(a[0]==='run'&&a[1]==='start'){
  if(e.FAKE_NEN_START==='refuse'){ console.error('nen run: refused'); process.exit(1); }
  const at=(f)=>a[a.indexOf(f)+1]; const answers=a.includes('--idle-answers')?JSON.parse(at('--idle-answers')):null;
  console.log(JSON.stringify({outcome:e.FAKE_NEN_START||'started',path:'<common>/.nen/runs/'+at('--id')+'.json',
    manifest:{contract:'nen.run/v0.1',id:at('--id'),repo:at('--target'),startedAt:'2026-01-01T00:00:00Z',idleAnswers:answers,prs:[],parked:[]}})); }
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
  const nenCalls = () => readFileSync(nenLog, 'utf8').trim().split('\n').map((line) => JSON.parse(line) as string[]);
  const runStarts = () => nenCalls().filter((argv) => argv[0] === 'run' && argv[1] === 'start');
  // The attended start above opened nen's manifest with the same id and no answers.
  const attended = runStarts().find((argv) => argv.includes(runId));
  assert.ok(attended, 'start opens nen run start with the record\'s own id');
  assert.equal(attended.includes('--idle-answers'), false, 'an attended run hands nen no answers');
  assert.deepEqual([attended[attended.indexOf('--target') + 1], attended[attended.indexOf('--repo') + 1]], ['zheref/hatsu', realpathSync(root)]);
  const record = (id: string) => JSON.parse(readFileSync(join(root, '.git', 'hatsu', 'futon', `run-${id}.json`), 'utf8'));
  assert.equal(record(runId).contract, 'hatsu.futon.run/v0.3');
  assert.equal(record(runId).dry, false);
  assert.equal(record(runId).idle, null);
  for (const gone of ['prs', 'parked']) assert.equal(gone in record(runId), false, `the record carries no ${gone}: nen's manifest does`);
  for (const verb of ['append', 'park', 'status']) {
    const retired = manifestCall([verb, '--repo', root, '--run', runId]);
    expectStatus(retired, 1, `${verb} is retired`);
    assert.match(String(retired.stderr), /retired: the run manifest is nen's/);
  }
  const shown = manifestCall(['profile', '--repo', root, '--run', runId]);
  expectStatus(shown, 0, 'profile prints the ownership record');
  assert.equal(JSON.parse(String(shown.stdout)).manifest, 'nen');
  expectStatus(manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt --idle --idle']),
    1, 'a doubled --idle refused (nen folds the second into the label)');
  expectStatus(manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt then getsuga --idle']),
    1, '--idle after then refused');
  const before = runStarts().length;
  expectStatus(manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt'], { FAKE_NEN_START: 'refuse' }),
    1, 'a refused nen run start refuses the start');
  expectStatus(manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt'], { FAKE_NEN_START: 'existing' }),
    1, 'a nen start that did not create the run refuses the start');
  expectStatus(manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt'], { FAKE_NO_IDLE: '1' }),
    1, 'a nen with no idle field (older than 0.26.0) refuses the start');
  assert.equal(runStarts().length, before + 2, 'the refused starts reached nen only where the parse passed');
  const idleStarted = manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt --idle then rikugan']);
  expectStatus(idleStarted, 0, 'idle run starts with --idle read by nen, never stripped');
  const idleId = /run ([0-9a-f]{32}) recorded/.exec(String(idleStarted.stdout))?.[1];
  assert.ok(idleId, 'idle start returns a run id');
  const idleParse = nenCalls().filter((argv) => argv[0] === 'parse').at(-1);
  assert.equal(idleParse?.[4], 'hatsu@model/gpt --idle then rikugan', 'nen parses the line with --idle in it');
  assert.match(String(idleStarted.stdout), /pre-answered publish-offer → refuse/, 'publish-offer is refused under idle');
  assert.match(String(idleStarted.stdout), /pre-answered wrap-up → default/, 'a starred row takes its default');
  const idleOpen = runStarts().find((argv) => argv.includes(idleId));
  const answers = JSON.parse(idleOpen?.[idleOpen.indexOf('--idle-answers') + 1] ?? 'null');
  assert.equal(answers['publish-offer'], 'refuse', 'the answers travel to nen as idleAnswers');
  assert.ok(Object.values(answers).every((r) => ['default', 'hold', 'refuse'].includes(r as string)));
  const fresh = record(idleId);
  assert.equal(fresh.idle.localSlotFrees, 'merged');
  assert.equal(fresh.idle.terminal, 'ready-at-prompt-or-integration');
  assert.equal('decisions' in fresh.idle, false, 'the answers live in nen\'s manifest, not the record');
  assert.match(String(idleStarted.stdout), /budget --max-minutes 480 --max-tokens 4000000/);
  // zheref/hatsu#424: --dry-run beside --idle, before or after it; nen never sees the token.
  for (const line of ['hatsu:futon hatsu@model/gpt --idle --dry-run', 'hatsu:futon hatsu@model/gpt --dry-run --idle then rikugan']) {
    const dry = manifestCall(['start', '--repo', root, '--invocation', line]);
    expectStatus(dry, 0, `a dry run starts: ${line}`);
    assert.match(String(dry.stdout), /\(idle\) \(dry: nothing is authored\)/);
    const dryId = /run ([0-9a-f]{32}) recorded/.exec(String(dry.stdout))?.[1] ?? '';
    assert.equal(record(dryId).dry, true, 'the record says the run was dry');
    assert.equal(record(dryId).invocation, line, 'the typed line is kept whole');
  }
  for (const [line, why] of [['hatsu:futon hatsu@model/gpt --dry-run', 'a dry run without --idle'],
      ['hatsu:futon hatsu@model/gpt --idle --dry-run --dry-run', 'a doubled --dry-run'],
      ['hatsu:futon hatsu@model/gpt --idle then rikugan --dry-run', '--dry-run after then'],
      ['hatsu:futon hatsu@model/gpt --idle --fast', 'an unknown modifier'],
      ['hatsu:futon hatsu@model/gpt --idle --dry-run --fast', 'an unknown modifier beside both']])
    expectStatus(manifestCall(['start', '--repo', root, '--invocation', line]), 1, `${why} is refused, never folded into the label`);
  expectStatus(manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon --idle hatsu@model/gpt']), 0,
    '--idle typed before @ reaches nen as typed');
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
  commitWorkflow({ idle: { localSlotFrees: 'stacked-open' } }, 'idle slot widened');
  expectStatus(idleStart(), 1, 'a declared idle.localSlotFrees is held to the same floor (HR-257)');
  commitWorkflow({ idle: { localSlotFrees: 'merged' } }, 'idle slot ruled');
  expectStatus(idleStart(), 0, 'idle.localSlotFrees: merged starts');
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
  // SEC-15: refs/remotes/origin/HEAD is read first; gh's defaultBranchRef only when it is absent.
  const originHead = (target: string) => expectStatus(git(['symbolic-ref', 'refs/remotes/origin/HEAD', `refs/remotes/origin/${target}`]), 0, `origin/HEAD → ${target}`);
  originHead('main');
  const viaHead = idleStart();
  expectStatus(viaHead, 0, 'origin/HEAD set: the profile is read through it');
  assert.match(String(viaHead.stdout), new RegExp(`idle profile read from origin/main at ${good}`), 'origin/HEAD → origin/main is the read');
  const overGh = idleStart({ FAKE_DEFAULT: 'trunk' });
  expectStatus(overGh, 0, 'origin/HEAD wins over gh, whose unfetched default would refuse');
  assert.match(String(overGh.stdout), new RegExp(`idle profile read from origin/main at ${good}`));
  const evil = String(git(['rev-parse', 'refs/remotes/origin/evil']).stdout).trim();
  originHead('evil');
  const symbolicWins = idleStart();
  expectStatus(symbolicWins, 0, 'origin/HEAD naming a branch other than gh\'s default is the read');
  assert.match(String(symbolicWins.stdout), new RegExp(`idle profile read from origin/evil at ${evil}`), 'the symbolic ref wins over FAKE_DEFAULT');
  originHead('bare');
  const headBare = idleStart();
  expectStatus(headBare, 1, 'origin/HEAD at a commit with no nen/workflow.json refuses the start');
  assert.match(String(headBare.stderr), /origin\/bare at [0-9a-f]{40} has no nen\/workflow\.json/, 'the refusal names the symbolic ref');
  expectStatus(git(['symbolic-ref', '--delete', 'refs/remotes/origin/HEAD']), 0, 'drop origin/HEAD');
  console.log('futon-effort: start (nen run start, same id), bind, refresh, missing/stale/default/foreign-selector refusals, the retired manifest verbs, the dry-run modifier and the idle floor passed');
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
