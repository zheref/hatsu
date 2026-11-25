import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, chmodSync, readFileSync, renameSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
export function checkSlots(): void {
  const dir = mkdtempSync(join(tmpdir(), 'hatsu-mixed-gates-'));
  const root = join(dir, 'repo'), bin = join(dir, 'bin'), id = 'a'.repeat(32);
  const script = fileURLToPath(new URL('./futon_effort_record.mts', import.meta.url));
  try {
    mkdirSync(root); mkdirSync(bin);
    assert.equal(spawnSync('git', ['init', '-q', root]).status, 0);
    mkdirSync(join(root, '.git/hatsu/futon'), { recursive: true });
    mkdirSync(join(root, '.git/.nen/runs'), { recursive: true });
    const manifest = join(root, '.git/.nen/runs', `${id}.json`);
    writeFileSync(manifest, JSON.stringify({ id, repo: 'zheref/hatsu', prs: [1, 2, 3].map(pr => ({ pr, kind: 'delivery' })) }));
    writeFileSync(join(root, '.git/hatsu/futon', `run-${id}.json`), JSON.stringify({
      contract: 'hatsu.futon.run/v0.3', id, repo: 'zheref/hatsu', invocation: 'hatsu:futon hatsu@model/gpt',
      selector: 'model/gpt', startedAt: '2026-11-25T00:00:00Z', dry: false, idle: null }));
    const log = join(dir, 'calls.jsonl');
    const common = `const fs=require('fs'),a=process.argv.slice(2),e=process.env;const at=f=>a[a.indexOf(f)+1];\n`;
    writeFileSync(join(bin, 'gh'), '#!/usr/bin/env node\n' + common + `
if(a[0]==='repo') console.log(JSON.stringify({nameWithOwner:e.WRONG_TARGET?'other/repo':'ZHEREF/Hatsu'}));
else if(a[0]==='pr') {
 let head='b'.repeat(40);const counter=${JSON.stringify(join(dir, 'reads'))};
 let n=fs.existsSync(counter)?Number(fs.readFileSync(counter,'utf8')):0;fs.writeFileSync(counter,String(n+1));
 if(e.MOVED&&n>=6) head='c'.repeat(40);
 if(e.LATE_CLAIM&&n===8) fs.appendFileSync(${JSON.stringify(manifest)},' ');
 console.log(JSON.stringify({headRefOid:head,baseRefOid:'d'.repeat(40),baseRefName:'main',headRefName:'p'+a[2],state:e.TERMINAL?'MERGED':'OPEN',changedFiles:e.TERMINAL?0:e.TRUNCATED?2:1}));
} else if(a[0]==='api'&&a[1].includes('/commits/')) console.log('e'.repeat(40));
else if(a[0]==='api'&&a[1].includes('/contents/')) console.log(JSON.stringify({consumers:[{repo:'zheref/hatsu'}]}));
else if(a[0]==='api'&&!a[1].includes('/pulls/')) console.log(JSON.stringify({default_branch:'main'}));
else if(a[0]==='api') {
 const pr=Number(a[1].split('/').at(-2));
 console.log(JSON.stringify([[{filename:pr===2?'docs/change.md':'README.md',...(e.RENAMED&&pr===1?{previous_filename:'nen/gates.json'}:{})}]]));
} else process.exit(2);
`);
    writeFileSync(join(bin, 'nen'), '#!/usr/bin/env node\n' + common + `
fs.appendFileSync(${JSON.stringify(log)},JSON.stringify(a)+'\\n');
if(a[0]==='repo') console.log(JSON.stringify({target:'zheref/hatsu',role:e.CONSUMER?(at('--repo').includes('hatsu-prompt-gates-')?(e.UNREGISTERED?'unregistered':e.SPEC?'spec':'consumer'):'unregistered'):'canon',defaultGate:'G4'}));
else if(a[0]==='gate') { const names=fs.readFileSync(at('--files-from'),'utf8');
 console.log(JSON.stringify({gate:/docs\\/|nen\\//.test(names)?'G4':'G2'})); }
else if(a[0]==='loop') {
 if(e.REFUSE) { console.error('refused'); process.exit(Number(e.REFUSE)); }
 const gate=at('--prompt-gate');
 const efforts=[1,2,3].map(pr=>({id:'HA#'+pr+' #'+pr,pr,issue:'HA#'+pr,plane:'local',prOpen:true,
 ready:pr!==2,prompted:gate===(pr===2?'G4':'G2'),...(pr===2?{sixthStopHead:'b'.repeat(40)}:{}),...(pr===3?{repairHold:true}:{}),facts:'Nen evidence'}));
 efforts.push({id:'HA#4 (claimed)',pr:null,issue:'HA#4',plane:'local',prOpen:false,ready:false,prompted:false,facts:'claimed'});
 if(e.TERMINAL) for(const x of efforts) if(x.pr!==null){x.ready=true;x.prompted=true;x.merged=true;delete x.repairHold;}
 const held=efforts.filter(x=>x.pr===null||x.repairHold||!x.prompted), done=efforts.filter(x=>!held.includes(x)).map(x=>x.id);
 const holding=held.map(x=>({id:x.id,why:x.repairHold?'sixth-stop evidence unread or held for repair':'Nen held'}));
 const plane=(name,cap,h)=>({plane:name,cap,occupied:h.length,free:e.UNREAD&&name==='local'?0:Math.max(0,cap-h.length),holding:h,binding:!!(e.UNREAD&&name==='local')||h.length>=cap});
 const report={ci:plane('ci',2,[]),local:plane('local',7,holding),done,localSlotFrees:{rule:e.RULE||'ready+prompted',source:'fixture'},
 fromRun:{run:at('--from-run'),efforts,notEfforts:[],closedUnmerged:[],unread:[],claims:e.UNREAD?'unread':'read',parkedClaims:[],claimsUnread:e.UNREAD?'claims unread':null}};
 if(e.MISSING) report.done=[];
 if(e.DUPLICATE) report.fromRun.efforts.push(efforts[0]);
 if(e.CLAIM_DRIFT&&gate==='G4') report.fromRun.parkedClaims=['HA#99'];
 if(e.RULE_DRIFT&&gate==='G4') report.localSlotFrees.rule='merged';
 if(e.MANIFEST_MOVED&&gate==='G4') fs.appendFileSync(${JSON.stringify(manifest)},' ');
 console.log(JSON.stringify(report));process.exit(report.local.binding?1:0);
} else process.exit(2);
`);
    chmodSync(join(bin, 'nen'), 0o755); chmodSync(join(bin, 'gh'), 0o755);
    const run = (env: Record<string, string> = {}) => {
      writeFileSync(log, ''); writeFileSync(join(dir, 'reads'), '0');
      return spawnSync(process.execPath, [script, 'slots', '--repo', root, '--run', id], {
        encoding: 'utf8', env: { ...process.env, PATH: bin + ':' + process.env.PATH, ...env } });
    };
    let result = run();
    assert.equal(result.status, 0, result.stderr);
    let report = JSON.parse(result.stdout);
    assert.deepEqual(report.promptGates.map((x: any) => x.gate), ['G2', 'G4', 'G2']);
    assert.deepEqual(report.done, ['HA#1 #1', 'HA#2 #2']);
    assert.equal(report.local.occupied, 2); assert.equal(report.local.free, 5);
    assert.deepEqual(report.local.holding.map((x: any) => x.id), ['HA#3 #3', 'HA#4 (claimed)']);
    assert.equal(report.fromRun.efforts.find((x: any) => x.pr === 2).ready, false, 'sixth-stop release never called Ready');
    assert.equal(report.fromRun.efforts.find((x: any) => x.pr === 2).sixthStopHead, 'b'.repeat(40));
    let calls = readFileSync(log, 'utf8').trim().split('\n').map(x => JSON.parse(x));
    assert.deepEqual(calls.filter(a => a[0] === 'loop').map(a => a[a.indexOf('--prompt-gate') + 1]), ['G2', 'G4']);
    assert.ok(calls.filter(a => a[0] === 'repo').every(a => a.includes('--target')), 'classification binds trusted target');
    result = run({ TERMINAL: '1' }); assert.equal(result.status, 0, result.stderr);
    assert.equal(JSON.parse(result.stdout).local.occupied, 1, 'terminal decisions selected once plus claim');
    result = run({ RENAMED: '1' }); assert.equal(result.status, 0, result.stderr);
    assert.equal(JSON.parse(result.stdout).promptGates[0].gate, 'G4', 'rename old side derives gate');
    result = run({ CONSUMER: '1' }); assert.equal(result.status, 0, result.stderr);
    calls = readFileSync(log, 'utf8').trim().split('\n').map(x => JSON.parse(x));
    assert.equal(calls.filter(a => a[0] === 'gate').length, 0, 'consumer role settles G2');
    assert.equal(calls.filter(a => a[0] === 'loop').length, 1);
    assert.equal(JSON.parse(result.stdout).registryRef, 'e'.repeat(40), 'fallback binds immutable default registry');
    result = run({ CONSUMER: '1', SPEC: '1' }); assert.equal(result.status, 0, result.stderr);
    assert.equal(JSON.parse(result.stdout).role, 'spec');
    assert.equal(run({ CONSUMER: '1', UNREGISTERED: '1' }).status, 1, 'unresolved role refuses');
    for (const rule of ['merged', 'stacked-open']) assert.equal(run({ RULE: rule }).status, 1, 'non-Futon release rule refuses');
    result = run({ UNREAD: '1' }); assert.equal(result.status, 1, result.stderr);
    assert.equal(JSON.parse(result.stdout).local.free, 0, 'unread claims retain Nen hold');
    for (const key of ['WRONG_TARGET', 'TRUNCATED', 'MOVED', 'MISSING', 'DUPLICATE', 'CLAIM_DRIFT', 'RULE_DRIFT', 'MANIFEST_MOVED', 'LATE_CLAIM']) {
      result = run({ [key]: '1' }); assert.equal(result.status, 1, `${key}: ${result.stdout}${result.stderr}`);
      assert.equal(result.stdout, '', `${key} emits no partial free-slot report`);
    }
    for (const code of [1, 2]) assert.equal(run({ REFUSE: String(code) }).status, code);
    const legacy = join(root, '.git/hatsu/runs', `${id}.json`);
    mkdirSync(join(root, '.git/hatsu/runs'));
    renameSync(manifest, legacy);
    result = run(); assert.equal(result.status, 0, result.stderr);
    assert.ok(readFileSync(legacy, 'utf8'), 'legacy remains in place');
    writeFileSync(manifest, readFileSync(legacy));
    assert.equal(run().status, 1, 'duplicate manifest homes refused');
    console.log('futon slots: mixed gates, rename, claims, sixth-stop, repair hold and stale reads passed');
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
