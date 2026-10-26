#!/usr/bin/env node
// #154: a Futon claim is local to the Git common dir and fails closed when stale.
// HR-5 / zheref/hatsu#423: start opens nen's run manifest (stubbed here) with the same id and the
// pre-answered rows as its idleAnswers; the record keeps ownership and the profile, never prs or parks.
// zheref/hatsu#424: --dry-run beside --idle is lifted off before nen's parse and recorded as dry.
// zheref/hatsu#488: an idle run binds no stacked PR; resume re-opens a run under its own id, answers and terminal.
import assert from 'node:assert/strict';
import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, realpathSync, renameSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { randomBytes } from 'node:crypto';
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
function randomHex(): string { return randomBytes(16).toString('hex'); }
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
if(a[0]==='repo'&&a[1]==='view') console.log(JSON.stringify({nameWithOwner:e.FAKE_REPO||'zheref/hatsu',defaultBranchRef:{name:e.FAKE_DEFAULT||'main'}}));
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
  const idle=/(^|\\s)--idle(\\s|$)/.test(line); const then=(line.match(/(?:^|\\s)then\\s+(.*)$/)||[])[1]||null;
  console.log(JSON.stringify(e.FAKE_NO_IDLE?{repo:'zheref/hatsu',label:'model/gpt',band:null}:{repo:'zheref/hatsu',label:e.FAKE_BAND?null:'model/gpt',band:e.FAKE_BAND||null,idle,then})); }
else if(a[0]==='run'&&a[1]==='start'){
  if(e.FAKE_NEN_START==='refuse'){ console.error('nen run: refused'); process.exit(1); }
  const at=(f)=>a[a.indexOf(f)+1]; const answers=a.includes('--idle-answers')?JSON.parse(at('--idle-answers')):null;
  // Stateful like nen 0.28: a new id writes its manifest; a known id with the same answers is 'existing',
  // with other answers a 'conflict' at exit 1. FAKE_NEN_START forces an outcome and writes nothing.
  const fs=require('fs'); const file='.git/.nen/runs/'+at('--id')+'.json';
  let manifest={contract:'nen.run/v0.1',id:at('--id'),repo:at('--target'),startedAt:e.FAKE_STARTED||new Date().toISOString(),idleAnswers:answers,prs:[],parked:[]};
  let outcome=e.FAKE_NEN_START||'started';
  if(!e.FAKE_NEN_START){ if(fs.existsSync(file)){ manifest=JSON.parse(fs.readFileSync(file,'utf8'));
      if(JSON.stringify(manifest.idleAnswers)!==JSON.stringify(answers)){ console.log(JSON.stringify({outcome:'conflict',reason:'launch answers are fixed at start (HR-5)'})); process.exit(1); }
      outcome='existing'; }
    else { fs.mkdirSync('.git/.nen/runs',{recursive:true}); fs.writeFileSync(file,JSON.stringify(manifest)); } }
  const shown=JSON.parse(JSON.stringify(manifest)); if(shown.idleAnswers&&e.FAKE_TAMPER) shown.idleAnswers['publish-offer']='default';
  console.log(JSON.stringify({outcome,path:'<common>/.nen/runs/'+at('--id')+'.json',manifest:shown})); }
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
  assert.ok(nenCalls().some((argv) => argv[0] === 'parse' && argv[4] === 'hatsu@model/gpt --idle then rikugan'), 'nen parses the line with --idle in it');
  assert.match(String(idleStarted.stdout), /pre-answered publish-offer → refuse/, 'publish-offer is refused under idle');
  assert.match(String(idleStarted.stdout), /pre-answered wrap-up → refuse/, 'the wrap-up is refused under idle (HR-366), whatever its star');
  assert.match(String(idleStarted.stdout), /pre-answered direct-mismatch → default/, 'a starred row takes its default');
  const idleOpen = runStarts().find((argv) => argv.includes(idleId));
  const answers = JSON.parse(idleOpen?.[idleOpen.indexOf('--idle-answers') + 1] ?? 'null');
  assert.equal(answers['publish-offer'], 'refuse', 'the answers travel to nen as idleAnswers');
  assert.ok(Object.values(answers).every((r) => ['default', 'hold', 'refuse'].includes(r as string)));
  const fresh = record(idleId);
  assert.equal(fresh.idle.localSlotFrees, 'ready+prompted');
  assert.equal(fresh.idle.terminal, 'ready-at-prompt-or-integration');
  assert.equal('decisions' in fresh.idle, false, 'the answers live in nen\'s manifest, not the record');
  assert.match(String(idleStarted.stdout), /budget --max-minutes 480 --max-tokens 4000000/);
  // zheref/hatsu#488: an unattended run delivers through its integration PR; it never binds a stacked one.
  // A PR no other effort holds, so the exit status alone proves the refusal (red against the previous script).
  const idleBind = execute(process.execPath, [script, 'bind', '--repo', root, '--pr', '41', ...bind.map((part) => part === runId ? idleId : part)]);
  expectStatus(idleBind, 1, 'an idle run binds no stacked delivery PR');
  assert.match(String(idleBind.stderr), /unattended: it delivers through its integration PR/);
  // zheref/hatsu#488: a resume re-opens the same id with the answers nen stored, the recorded terminal and branch.
  const resume = (id: string | null, line: string, env: Record<string, string> = {}) =>
    manifestCall(['resume', '--repo', root, ...(id ? ['--run', id] : []), '--invocation', line], env);
  const idleLine = 'hatsu:futon hatsu@model/gpt --idle then rikugan';
  const manifestFile = (id: string) => join(root, '.git', '.nen', 'runs', `${id}.json`);
  assert.ok(existsSync(manifestFile(idleId)), 'the stub, like nen, wrote the manifest at start');
  const integrated = manifestCall(['integrate', '--repo', root, '--run', idleId, '--branch', 'gpt/kurapika/futon-model-gpt-2026-10-25']);
  expectStatus(integrated, 0, 'the run records its one integration branch at the cut');
  assert.equal(record(idleId).integration, 'gpt/kurapika/futon-model-gpt-2026-10-25');
  expectStatus(manifestCall(['integrate', '--repo', root, '--run', idleId, '--branch', 'gpt/kurapika/futon-model-gpt-2026-10-25']), 0, 'the same branch again is unchanged');
  expectStatus(manifestCall(['integrate', '--repo', root, '--run', idleId, '--branch', 'gpt/kurapika/futon-other']), 1, 'a second integration branch is refused');
  expectStatus(manifestCall(['integrate', '--repo', root, '--run', runId, '--branch', 'main']), 1, 'the default branch is never an integration branch');
  for (const spelling of ['refs/heads/main', 'heads/main', 'origin/main', 'remotes/origin/main', 'HEAD', '-f', '-x', 'main.lock', 'x.', 'a..b'])
    expectStatus(manifestCall(['integrate', '--repo', root, '--run', runId, '--branch', spelling]), 1, `integrate refuses the spelling ${spelling}`);
  expectStatus(manifestCall(['integrate', '--repo', root, '--run', runId, '--branch', 'gpt/kurapika/x'], { FAKE_REPO: 'zheref/other' }), 1, 'integrate refuses a run of another repository');
  const resumed = resume(idleId, idleLine);
  expectStatus(resumed, 0, 'an interrupted idle run resumes under its own id');
  assert.match(String(resumed.stdout), new RegExp(`run ${idleId} resumed for zheref/hatsu@model/gpt \\(idle\\)`));
  assert.match(String(resumed.stdout), /terminal ready-at-prompt-or-integration · delivery: gpt\/kurapika\/futon-model-gpt-2026-10-25 and its one PR/);
  assert.doesNotMatch(String(resumed.stdout), /now differs from launch/, 'an unmoved profile reports no drift');
  const reopened = runStarts().filter((argv) => argv.includes(idleId)).at(-1) ?? [];
  assert.deepEqual(JSON.parse(reopened[reopened.indexOf('--idle-answers') + 1] ?? 'null'), answers, 'the resume sends the launch answers nen stored');
  const found = resume(null, idleLine);
  expectStatus(found, 0, 'with no --run, the newest run typed as the same line resumes');
  assert.match(String(found.stdout), new RegExp(`run ${idleId} resumed`));
  // Bugbot on HA-PR-#490: identity is nen's parse, not the spelling -- --idle placed elsewhere is the same run.
  const placed = resume(null, 'hatsu:futon --idle hatsu@model/gpt then rikugan');
  expectStatus(placed, 0, '--idle typed before @ finds the same run');
  assert.match(String(placed.stdout), new RegExp(`run ${idleId} resumed`));
  // Bugbot on HA-PR-#490: a v0.3 record written before end tracking is never auto-picked; --run still reaches it.
  const untracked = join(root, '.git', 'hatsu', 'futon', `run-${idleId}.json`);
  const trackedText = readFileSync(untracked, 'utf8');
  const { endTracked: _drop, ...legacy } = JSON.parse(trackedText);
  writeFileSync(untracked, JSON.stringify(legacy));
  expectStatus(resume(null, idleLine), 3, 'a record without end tracking is never picked by line');
  expectStatus(resume(idleId, idleLine), 0, 'but resumes by an explicit --run');
  writeFileSync(untracked, trackedText);
  const none = resume(null, 'hatsu:futon hatsu@model/gpt --idle then getsuga');
  expectStatus(none, 3, 'a line no open run was typed as exits 3: start a new run');
  assert.match(String(none.stderr), /start a new run/);
  expectStatus(resume(idleId, 'hatsu:futon hatsu@model/gpt then rikugan'), 1, 'a resume typed as another line is refused');
  expectStatus(resume(idleId, idleLine, { FAKE_NEN_START: 'started' }), 1, 'a resume nen reports as a new start is refused');
  expectStatus(resume(idleId, idleLine, { FAKE_REPO: 'zheref/other' }), 1, 'a resume resolving to another repository is refused');
  const kept = readFileSync(manifestFile(idleId), 'utf8');
  rmSync(manifestFile(idleId));
  const startsBefore = runStarts().length;
  const orphan = resume(idleId, idleLine);
  expectStatus(orphan, 1, 'a resume with no manifest on disk is refused');
  assert.match(String(orphan.stderr), /nothing to resume, and none is created/);
  assert.equal(runStarts().length, startsBefore, 'a refused resume never calls nen run start, so no empty manifest opens the then gate');
  assert.equal(existsSync(manifestFile(idleId)), false, 'and no manifest is written');
  writeFileSync(manifestFile(idleId), kept);
  // A claim written before bind refused idle runs is never vouched for by verify (En § 5 reads it).
  const legacyClaim = join(root, '.git', 'hatsu', 'futon', 'pr-31.json');
  writeFileSync(legacyClaim, JSON.stringify({ ...JSON.parse(readFileSync(saved, 'utf8')), runId: idleId, pr: 31,
    invocation: record(idleId).invocation, selector: 'model/gpt' }));
  const legacyVerify = execute(process.execPath, [script, 'verify', '--repo', root, '--pr', '31'], { FAKE_SHA: 'b'.repeat(40) });
  expectStatus(legacyVerify, 1, 'verify refuses a claim bound to an idle run');
  assert.match(String(legacyVerify.stderr), /an unattended run: it owns no stacked delivery PR/);
  rmSync(legacyClaim);
  expectStatus(resume(idleId, idleLine, { FAKE_TAMPER: '1' }), 1, 'a resume whose answers nen reports differently is refused');
  const moved = JSON.parse(kept);
  writeFileSync(manifestFile(idleId), JSON.stringify({ ...moved, startedAt: '2000-01-01T00:00:00.000Z' }));
  expectStatus(resume(idleId, idleLine), 1, 'a manifest started at another time is another run');
  writeFileSync(manifestFile(idleId), JSON.stringify({ ...moved, idleAnswers: null }));
  expectStatus(resume(idleId, idleLine), 1, 'a manifest that is not idle for an idle record is refused');
  writeFileSync(manifestFile(idleId), JSON.stringify({ ...JSON.parse(kept), idleAnswers: { ...JSON.parse(kept).idleAnswers, 'publish-offer': 'default' } }));
  writeFileSync(manifestFile(idleId), 'null');
  const nullManifest = resume(idleId, idleLine);
  expectStatus(nullManifest, 1, 'a null manifest is refused');
  assert.match(String(nullManifest.stderr), /is not a run manifest/);
  writeFileSync(manifestFile(idleId), JSON.stringify({ ...JSON.parse(kept), idleAnswers: { ...JSON.parse(kept).idleAnswers, 'publish-offer': 'default' } }));
  const floored = resume(idleId, idleLine);
  expectStatus(floored, 1, 'a stored answer edited past the floor never resumes');
  assert.match(String(floored.stderr), /publish-offer may not be default/);
  writeFileSync(manifestFile(idleId), kept);
  const idRecord = join(root, '.git', 'hatsu', 'futon', `run-${idleId}.json`);
  const idKept = readFileSync(idRecord, 'utf8');
  writeFileSync(idRecord, JSON.stringify({ ...JSON.parse(idKept), id: 'b'.repeat(32) }));
  expectStatus(resume(idleId, idleLine), 1, 'a record whose id is not the --run is refused');
  writeFileSync(idRecord, idKept);
  const again = manifestCall(['start', '--repo', root, '--invocation', idleLine]);
  expectStatus(again, 0, 'the same line typed again starts a new run');
  assert.match(String(again.stdout), new RegExp(`note: run ${idleId} was typed as this same line; this is a new run`), 'and names the earlier one');
  const againId = /run ([0-9a-f]{32}) recorded/.exec(String(again.stdout))?.[1] ?? '';
  const newest = resume(null, idleLine);
  expectStatus(newest, 0, 'with no --run the newest run typed as the line resumes');
  assert.match(String(newest.stdout), new RegExp(`run ${againId} resumed`));
  // A record whose id is not its filename's is never picked: resume by line refuses naming it, start only notes it.
  const forged = join(root, '.git', 'hatsu', 'futon', `run-${'c'.repeat(32)}.json`);
  writeFileSync(forged, JSON.stringify({ ...record(idleId), id: againId, startedAt: '2099-01-01T00:00:00.000Z' }));
  const forgedPick = resume(null, idleLine);
  expectStatus(forgedPick, 1, 'a forged sibling record refuses a resume by line');
  assert.match(String(forgedPick.stderr), new RegExp(`run-${'c'.repeat(32)}\\.json is unreadable \\(its id is not its filename's\\)`));
  const noted = manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt']);
  expectStatus(noted, 0, 'a bad sibling never refuses a start');
  assert.match(String(noted.stdout), /note: run record .* is unreadable .*; skipped/);
  rmSync(forged);
  const foreign = join(root, '.git', 'hatsu', 'futon', `run-${'d'.repeat(32)}.json`);
  writeFileSync(foreign, JSON.stringify({ contract: 'hatsu.futon.run/v0.4' }));
  expectStatus(manifestCall(['start', '--repo', root, '--invocation', 'hatsu:futon hatsu@model/gpt']), 0, 'a foreign sibling never refuses a start');
  rmSync(foreign);
  // futon § 10's end is recorded once; an ended run is never picked, so the same line again is a new run.
  expectStatus(manifestCall(['end', '--repo', root, '--run', againId]), 0, 'the run records its end');
  assert.ok(record(againId).endedAt, 'endedAt written');
  expectStatus(resume(againId, idleLine), 1, 'an ended run is never resumed by id');
  const afterEnd = resume(null, idleLine);
  expectStatus(afterEnd, 0, 'by line, the newest unended run is the one');
  assert.match(String(afterEnd.stdout), new RegExp(`run ${idleId} resumed`), 'the ended newer run is skipped');
  expectStatus(manifestCall(['end', '--repo', root, '--run', idleId]), 0, 'end the older one too');
  expectStatus(resume(null, idleLine), 3, 'with every run of the line ended, exit 3: start a new run');
  const idEnded = JSON.parse(readFileSync(idRecord, 'utf8'));
  delete idEnded.endedAt;
  writeFileSync(idRecord, JSON.stringify(idEnded));
  // A policy edit on main after launch never strands the run: the stored answers and the recorded terminal hold.
  commitWorkflow({ idle: { terminal: 'ready-at-prompt', decisions: { 'direct-mismatch': 'hold' } } }, 'profile moved');
  const drifted = resume(idleId, idleLine);
  expectStatus(drifted, 0, 'a moved committed profile does not refuse the resume');
  assert.match(String(drifted.stdout), /terminal ready-at-prompt-or-integration/, 'the recorded terminal holds');
  assert.match(String(drifted.stdout), /now differs from launch; this run keeps its launch answers and terminal/);
  const resent = runStarts().filter((argv) => argv.includes(idleId)).at(-1) ?? [];
  assert.equal(JSON.parse(resent[resent.indexOf('--idle-answers') + 1] ?? 'null')['direct-mismatch'], 'default', 'the launch answer is resent, never the moved one');
  commitWorkflow({}, 'profile restored');
  const legacyRun = randomHex();
  writeFileSync(join(root, '.git', 'hatsu', 'futon', `run-${legacyRun}.json`), JSON.stringify({ ...record(idleId), contract: 'hatsu.futon.run/v0.2', id: legacyRun }));
  const legacyResume = resume(legacyRun, idleLine);
  expectStatus(legacyResume, 1, 'a v0.2 run, which opened no nen manifest, is never resumed');
  assert.match(String(legacyResume.stderr), /opened no nen manifest/);
  expectStatus(resume(runId, invocation), 0, 'an attended run resumes too, with no answers');
  expectStatus(call('bind', bind), 0, 'the resumed attended run still binds its stacked PR');
  // zheref/hatsu#424: --dry-run beside --idle, before or after it; nen never sees the token.
  for (const line of ['hatsu:futon hatsu@model/gpt --idle --dry-run', 'hatsu:futon hatsu@model/gpt --dry-run --idle then rikugan']) {
    const dry = manifestCall(['start', '--repo', root, '--invocation', line]);
    expectStatus(dry, 0, `a dry run starts: ${line}`);
    assert.match(String(dry.stdout), /\(idle\) \(dry: nothing is authored\)/);
    const dryId = /run ([0-9a-f]{32}) recorded/.exec(String(dry.stdout))?.[1] ?? '';
    assert.equal(record(dryId).dry, true, 'the record says the run was dry');
    assert.equal(record(dryId).invocation, line, 'the typed line is kept whole');
    expectStatus(call('bind', bind.map((part) => part === runId ? dryId : part)), 1, 'a dry run binds no PR (zheref/hatsu#424/AC-2)');
    expectStatus(resume(dryId, line), 1, 'a dry run is rehearsed again, never resumed');
    expectStatus(manifestCall(['integrate', '--repo', root, '--run', dryId, '--branch', 'gpt/kurapika/x']), 1, 'a dry run cuts no integration branch');
    const predicted = manifestCall(['predict', '--repo', root, '--run', dryId, '--issue', 'HA#154', '--row', 'dry-prompt']);
    expectStatus(predicted, 0, 'a dry run records its prediction on the record');
    assert.deepEqual(record(dryId).predictions.map((p: { issue: string; row: string }) => [p.issue, p.row]), [['HA#154', 'dry-prompt']]);
    expectStatus(manifestCall(['predict', '--repo', root, '--run', dryId, '--issue', 'HA#155', '--row', 'g5:decide']), 1, 'a colon row refused');
    expectStatus(manifestCall(['predict', '--repo', root, '--run', dryId, '--issue', '155', '--row', 'g5-decide']), 1, 'a bare number refused');
  }
  expectStatus(manifestCall(['predict', '--repo', root, '--run', runId, '--issue', 'HA#154', '--row', 'dry-prompt']), 1,
    'a real run records no prediction: its stops are nen run park\'s');
  assert.equal(nenCalls().some((argv) => argv[0] === 'run' && argv[1] === 'park'), false, 'predictions never reach nen\'s parked[]');
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
  // The ruling of 2026-10-23: unattended except an irreversible act. The floor is publish-offer refuse,
  // wrap-up and cleanup-plan refuse (HR-366, ruled 2026-10-26) and missing-maintainer-choice at most hold;
  // a row that stars nothing can never be default.
  for (const [row, resolution] of [['publish-offer', 'default'], ['publish-offer', 'hold'],
      ['wrap-up', 'default'], ['wrap-up', 'hold'], ['cleanup-plan', 'default'], ['cleanup-plan', 'hold'],
      ['missing-maintainer-choice', 'default'], ['port-siblings', 'default']]) {
    commitWorkflow({ idle: { decisions: { [row]: resolution } } }, `${row} ${resolution}`);
    expectStatus(idleStart(), 1, `the floor refuses ${row}: ${resolution}`);
  }
  // cleanup-plan left this list on 2026-10-26: HR-366 ruled puts it on the floor with wrap-up (both refuse).
  for (const row of ['host-nen-link', 'harness-attribution-switch', 'direct-mismatch']) {
    commitWorkflow({ idle: { decisions: { [row]: 'default' } } }, `${row} default`);
    const lifted = idleStart();
    expectStatus(lifted, 0, `${row}: default is admitted, a reversible act (ruling of 2026-10-23)`);
    assert.match(String(lifted.stdout), new RegExp(`pre-answered ${row} → default`));
  }
  commitWorkflow({}, 'no idle map');
  expectStatus(idleStart({ FAKE_TAMPER: '1' }), 1, 'nen storing other answers than the floor resolved refuses the start');
  const stamped = idleStart({ FAKE_STARTED: '2026-02-03T04:05:06.000Z' });
  expectStatus(stamped, 0, 'a start with nen\'s own startedAt');
  const stampedId = /run ([0-9a-f]{32}) recorded/.exec(String(stamped.stdout))?.[1] ?? '';
  assert.equal(record(stampedId).startedAt, '2026-02-03T04:05:06.000Z', 'the record copies nen\'s startedAt: one owner');
  // zheref/hatsu#425 (HR-353, record R-2026-10-23-20): ready+prompted is the one value; merged and stacked-open are refused.
  for (const value of ['merged', 'stacked-open']) {
    commitWorkflow({ monitor: { localSlotFrees: value } }, `slot ${value}`);
    expectStatus(idleStart(), 1, `monitor.localSlotFrees ${value} refused: the ruled value is ready+prompted`);
    commitWorkflow({ idle: { localSlotFrees: value } }, `idle slot ${value}`);
    expectStatus(idleStart(), 1, `a declared idle.localSlotFrees ${value} is held to the same rule`);
  }
  commitWorkflow({ monitor: { localSlotFrees: 'ready+prompted' }, idle: { localSlotFrees: 'ready+prompted' } }, 'slot ruled');
  expectStatus(idleStart(), 0, 'localSlotFrees: ready+prompted starts');
  commitWorkflow({ branch: { base: 'main' }, idle: { decisions: { 'direct-mismatch': 'hold', 'mode-unknown': 'default' } } }, 'partial map');
  const partial = idleStart();
  expectStatus(partial, 0, 'a partial idle.decisions with valid values starts');
  const partialOut = String(partial.stdout);
  assert.match(partialOut, /pre-answered direct-mismatch → hold/);
  assert.match(partialOut, /pre-answered mode-unknown → default/);
  assert.match(partialOut, /pre-answered spec-capture-scope → default/, 'an unnamed starred row takes its default (ruling of 2026-10-23)');
  assert.match(partialOut, /pre-answered cleanup-plan → refuse/, 'an unnamed cleanup-plan refuses (HR-366, ruled 2026-10-26)');
  assert.match(partialOut, /pre-answered wrap-up → refuse/, 'an unnamed wrap-up refuses (HR-366)');
  assert.match(partialOut, /pre-answered port-drift → hold/, 'an unnamed row that stars nothing holds');
  assert.match(partialOut, /pre-answered missing-maintainer-choice → hold/, 'the never-derived choice holds');
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
  commitWorkflow({ branch: { base: 'evil' }, idle: { decisions: { 'mode-unknown': 'hold' } } }, 'base redirected', false);
  expectStatus(git(['update-ref', 'refs/remotes/origin/evil', 'HEAD']), 0, 'push the redirect target');
  const redirected = idleStart();
  expectStatus(redirected, 0, 'a branch.base on HEAD never redirects the read');
  assert.match(String(redirected.stdout), new RegExp(`idle profile read from origin/main at ${good}`));
  assert.match(String(redirected.stdout), /pre-answered mode-unknown → default/, 'the redirected map never applies');
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
  // zheref/hatsu#488 (SC-4): the batch endings agree on WORKFLOW § Batch delivery and none ends on "blocked" again.
  const canon = (rel: string) => readFileSync(fileURLToPath(new URL(`../${rel}`, import.meta.url)), 'utf8');
  const section = (text: string, heading: string, next = '\n## ') => text.slice(text.indexOf(heading), text.indexOf(next, text.indexOf(heading) + heading.length));
  const endings = { 'futon § 10': section(canon('claude/skills/futon/SKILL.md'), '## 10. Ending the run'),
    'kazaana § 7': section(canon('claude/skills/kazaana/SKILL.md'), '## 7. Ending the run'),
    'backlog-loop § 10': section(canon('claude/skills/backlog-loop/SKILL.md'), '## 10. Ending the run') };
  for (const [where, text] of Object.entries(endings)) {
    assert.ok(text.length > 100, `${where} was found`);
    assert.match(text, /Batch delivery/, `${where} cites WORKFLOW § Batch delivery`);
    assert.match(text, /\*\*held\*\* with its three facts/, `${where} ends on held with its three facts`);
    assert.doesNotMatch(text, /blocked with its blocker named|or blocked\b/, `${where} no longer ends on "blocked"`);
  }
  const rules = section(canon('docs/WORKFLOW.md'), '### Batch delivery', '\n### ');
  for (const state of ['driving', 'ready', 'merged', 'closed', 'held-approval', 'held-gate', 'held-credential', 'held-cap',
      'held-handback', 'held-stranded'])
    assert.match(rules, new RegExp(`\`${state}\``), `WORKFLOW § Batch delivery names ${state}`);
  for (const where of ['claude/skills/en/SKILL.md', 'claude/skills/dowsing-chain/SKILL.md'])
    assert.match(canon(where), /Batch delivery/, `${where} cites WORKFLOW § Batch delivery`);
  console.log('futon-effort: start (nen run start, same id), bind, refresh, missing/stale/default/foreign-selector refusals, the retired manifest verbs, the dry-run modifier, the idle floor, the idle bind refusal, resume, integrate and the batch-ending canon passed');
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
