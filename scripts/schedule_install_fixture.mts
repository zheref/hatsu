#!/usr/bin/env node
// schedule_install_fixture.mts — the cases scripts/schedule_install.mts owes (zheref/hatsu#448).
// Hermetic and offline: the live contracts/schedule.json printed whole, every placeholder filled or
// named, nothing registered or written (HOME pointed at an empty scratch directory stays empty), and
// every wiring refusal at exit 2 against throwaway copies of the contract. Needs node only.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scripts = dirname(fileURLToPath(import.meta.url));
const repo = join(scripts, '..');
const script = join(scripts, 'schedule_install.mts');
const scratch = realpathSync(mkdtempSync(join(tmpdir(), 'schedule-install-')));
const home = join(scratch, 'home');
mkdirSync(home);
type Run = { status: number | null; stdout: string; stderr: string };
const run = (...args: string[]): Run => spawnSync(process.execPath, [script, ...args], { encoding: 'utf8', env: { ...process.env, HOME: home } }) as Run;
const live = JSON.parse(readFileSync(join(repo, 'contracts/schedule.json'), 'utf8'));
const spec = join(scratch, 'spec');
mkdirSync(spec);
const filled = ['--folder', repo, '--spec-folder', spec, '--family', 'fixture-family'];

try {
  // --- the live contract, printed whole ---
  {
    const r = run(...filled);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.match(r.stdout, /NOTHING IS REGISTERED/);
    for (const row of live.rows) assert.match(r.stdout, new RegExp(`=== ${row.id} ===`), `row ${row.id} printed`);
    for (const id of ['drift-pass', 'recapture', 'morning-desk', 'ratchet-shrink']) assert.ok(live.rows.some((x: { id: string }) => x.id === id), `the contract carries ${id}`);
    assert.match(r.stdout, /Trigger: {9}Custom -- .*; as Custom \(Edit form\): 7 9 1 1,4,7,10 \*/);
    assert.match(r.stdout, /not a task: runs in CI, \.github\/workflows\/prose-ambiguity-check\.yml job canon-lint/);
    assert.match(r.stdout, /hatsu:dowsing-chain recapture fixture-family --dry-run/);
    assert.match(r.stdout, /hatsu:rikugan for zheref\/hatsu as register/);
    assert.doesNotMatch(r.stdout, /<(hatsu|spec|family|repo)>/);
    assert.equal(r.stderr, '');
    assert.match(r.stdout, /picked C "Your own machine"/);
    assert.match(r.stdout, /reading \(not part of the record\)/);
    assert.match(r.stdout, /ONE catch-up run for the latest time missed in the last 7 days/);
    assert.match(r.stdout, /The first Run now of drift-pass is a LIVE run/);
    assert.match(r.stdout, /~\/\.claude\/settings\.json apply to these sessions too/);
    const never = live.permissions.neverAlwaysAllow.join(' · ');
    assert.equal(r.stdout.split(`Never always:    ${never}`).length - 1, 3, 'the never list is printed under each of the three tasks');
    assert.match(r.stdout, /=== drift-pass ===[\s\S]*?Worktree: {8}on/);
    console.log('ok    live contract: four rows printed, every placeholder filled, ruling, catch-up window and permission lists said (exit 0)');
  }
  {
    const r = run(...filled, '--json');
    assert.equal(r.status, 0, r.stderr);
    const j = JSON.parse(r.stdout);
    assert.equal(j.registered, false);
    assert.equal(j.ruling.id, 'R-2026-10-23-21');
    assert.equal(j.ruling.pick, 'C');
    const drift = j.rows.find((x: { id: string }) => x.id === 'drift-pass');
    assert.match(drift.skillMd, /^---\nname: hatsu-drift-pass\ndescription: ".+"\n---\n\n/);
    assert.deepEqual(j.unfilled, []);
    console.log('ok    --json: one document, registered false, SKILL.md frontmatter name and description');
  }
  // --- the page's table is the contract's, byte for byte ---
  {
    const r = run('--table');
    assert.equal(r.status, 0, r.stderr);
    const page = readFileSync(join(repo, 'docs/config/schedule.md'), 'utf8');
    const m = page.match(/<!-- schedule-table:begin[^>]*-->\n([\s\S]*?)<!-- schedule-table:end -->/);
    assert.ok(m, 'docs/config/schedule.md carries the schedule-table markers');
    assert.equal(m![1], r.stdout, 'docs/config/schedule.md\'s row table differs from contracts/schedule.json: paste `node scripts/schedule_install.mts --table`');
    console.log('ok    --table: docs/config/schedule.md\'s row table equals the one rendered from the contract');
  }
  // --- unfilled placeholders are named, never silent ---
  {
    const r = run();
    assert.equal(r.status, 1, r.stderr);
    assert.match(r.stderr, /unfilled: <spec> \(recapture\) -- pass --spec-folder/);
    assert.match(r.stderr, /unfilled: <family> \(recapture\) -- pass --family/);
    assert.match(r.stdout, /recapture <family> --dry-run/);
    console.log('ok    unfilled: each placeholder named on stderr, kept in the text (exit 1)');
  }
  // --- nothing is registered or written ---
  assert.deepEqual(readdirSync(home), [], 'HOME stays empty: no ~/.claude/scheduled-tasks written');
  console.log('ok    registers nothing: HOME untouched after every run');
  // --- wiring refusals ---
  const expectWiring = (re: RegExp, label: string, ...args: string[]): void => {
    const r = run(...args);
    assert.equal(r.status, 2, `${label}: ${r.stdout}${r.stderr}`);
    assert.match(r.stderr, re, label);
    assert.equal(r.stdout, '', `${label}: nothing printed over a wiring refusal`);
    console.log(`ok    wiring: ${label} (exit 2)`);
  };
  expectWiring(/unknown flag --register/, 'an unknown flag', '--register');
  expectWiring(/--family needs a value/, 'a valueless flag', '--family');
  expectWiring(/not an absolute path/, 'a relative folder', '--folder', 'relative/path');
  expectWiring(/not a directory/, 'a missing folder', '--spec-folder', join(scratch, 'nope'));
  expectWiring(/not a slug/, 'a family that is not a slug', '--family', 'Two Words');
  expectWiring(/not owner\/name/, 'a repo that is not owner/name', '--repo', 'hatsu');
  const fake = (name: string, body: string): string => {
    const root = join(scratch, name);
    mkdirSync(join(root, 'contracts'), { recursive: true });
    writeFileSync(join(root, 'contracts/schedule.json'), body);
    return root;
  };
  const mutate = (f: (c: any) => void): string => { const c = structuredClone(live); f(c); return JSON.stringify(c); };
  expectWiring(/is missing/, 'no contract', '--root', join(scratch, 'home'));
  expectWiring(/is not JSON/, 'a non-JSON contract', '--root', fake('nonjson', '{'));
  expectWiring(/is not hatsu\.schedule\/v0\.1/, 'an unknown contract id', '--root', fake('id', mutate((c) => { c.contract = 'hatsu.schedule/v9'; })));
  expectWiring(/row id drift-pass repeats/, 'a repeated row id', '--root', fake('dup', mutate((c) => { c.rows.push(c.rows[0]); })));
  expectWiring(/trigger\.cron is not five fields/, 'a cron that is not five fields', '--root', fake('cron', mutate((c) => { c.rows[0].trigger.cron = '0 9 * *'; })));
  expectWiring(/trigger\.form is not one of/, 'an unknown trigger form', '--root', fake('form', mutate((c) => { c.rows[0].trigger.form = 'Quarterly'; })));
  expectWiring(/not lowercase kebab-case/, 'a task name Desktop would rewrite', '--root', fake('name', mutate((c) => { c.rows[0].name = 'Hatsu Drift'; })));
  expectWiring(/has no workflow/, 'a ci row with no workflow', '--root', fake('ci', mutate((c) => { delete c.rows[3].workflow; })));
  expectWiring(/not desktop-task or ci/, 'an unknown row kind', '--root', fake('kind', mutate((c) => { c.rows[0].kind = 'cron'; })));
  expectWiring(/prompt is not a non-empty list/, 'an empty prompt', '--root', fake('prompt', mutate((c) => { c.rows[0].prompt = []; })));
  expectWiring(/uses <owner>, declared in neither/, 'an undeclared <token> in a prompt', '--root', fake('token', mutate((c) => { c.rows[0].prompt.push('Report to <owner>.'); })));
  expectWiring(/alwaysAllow names git push/, 'an always-allow entry the never list refuses', '--root', fake('allow', mutate((c) => { c.rows[0].alwaysAllow.push('git push'); })));
  expectWiring(/ruling\.pick D is none of its options/, 'a ruling pick that is no option', '--root', fake('pick', mutate((c) => { c.ruling.pick = 'D'; })));
  expectWiring(/needs a flag/, 'a placeholder with no flag', '--root', fake('ph', mutate((c) => { c.placeholders['<extra>'] = { means: 'x' }; })));
  {
    // A placeholder the contract adds is filled from its flag or named, never printed silently.
    const root = fake('ph5', mutate((c) => { c.placeholders['<team>'] = { flag: '--family', means: 'x' }; c.rows[0].prompt.push('Tell <team>.'); }));
    const r = run('--root', root);
    assert.equal(r.status, 1, r.stderr);
    assert.match(r.stderr, /unfilled: <team> \(drift-pass\) -- pass --family/);
    console.log('ok    placeholders: a fifth contract placeholder is read from the contract and named when unfilled');
  }
  // --- invoked through a symlinked directory, the printer still runs ---
  {
    const via = join(scratch, 'via-link');
    symlinkSync(scripts, via);
    const r = spawnSync(process.execPath, [join(via, 'schedule_install.mts'), ...filled], { encoding: 'utf8', env: { ...process.env, HOME: home } }) as Run;
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /=== drift-pass ===/);
    console.log('ok    entry: invoked through a symlinked directory, the printer prints');
  }
  console.log('schedule_install_fixture: all cases passed');
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
