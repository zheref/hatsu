#!/usr/bin/env node
// prose_ambiguity_check_fixture.mts — the canon-lint lane's fixture (HR-13, HR-4).
// Hermetic and offline: throwaway Hatsu-shaped roots prove every fail rule fires on a planted
// copy by its id and every advisory rule is printed and never counted; the hostile cases (CRLF,
// a heading inside a fence, folded frontmatter, a symlink leaving the root, a marker naming a
// human-gate row, an unparseable contract, an unreadable and a non-UTF-8 file) each read as
// named; the baseline admits, goes stale and refuses to grow under --base; and the committed
// tree reads clean. These cases are the acceptance criteria owed to `nen canon lint`
// (zheref/nen#481). Run: nen shu test --lane canon-lint --repo <hatsu>.
import assert from 'node:assert/strict';
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scripts = dirname(fileURLToPath(import.meta.url));
const repo = dirname(scripts);
const script = join(scripts, 'prose_ambiguity_check.mts');
const scratch = mkdtempSync(join(tmpdir(), 'hatsu-canon-lint-'));
let n = 0;

type Run = { status: number | null; stdout: string; stderr: string };
const lint = (root: string, ...extra: string[]): Run =>
  spawnSync(process.execPath, [script, '--root', root, ...extra], { encoding: 'utf8' }) as Run;

function put(root: string, rel: string, text: string | Buffer): void {
  mkdirSync(dirname(join(root, rel)), { recursive: true });
  writeFileSync(join(root, rel), text);
}

const SKILL_TARGET = `---
name: target
description: >
  A folded description whose second line looks like a heading.
  # 7. Not a heading
---

# Target

## 1. Invocation

**§ 1a · The profile.** A bold numbered lead.

**State the cost plainly:** a bold lead cited by title.

\`\`\`md
## 9. Fenced, never a heading
\`\`\`

## 2 · Where it sits
`;

function base(): string {
  const root = join(scratch, `root-${++n}`);
  put(root, '.claude-plugin/plugin.json', '{"name":"hatsu","version":"0.0.1"}\n');
  put(root, 'nen/contract.json', JSON.stringify({ dependency: { minimum: '0.24', pinned_ref: 'v0.24.0' } }));
  put(root, 'nen/decisions.json', JSON.stringify({ rows: [
    { id: 'missing-maintainer-choice', class: 'ask-once-per-run' },
    { id: 'missing-argument', class: 'ask-once-per-run' },
    { id: 'missing-configuration', class: 'ask-once-per-run' },
    { id: 'ambiguous-intent', class: 'human-gate' },
    { id: 'canon-merge', class: 'human-gate' },
    { id: 'red-lint', class: 'autonomous' },
  ] }));
  put(root, 'nen/workflow.json', JSON.stringify({ monitor: { cap: 20 } }));
  put(root, 'contracts/config-catalogue.json', JSON.stringify({ values: [{ default: 7 }] }));
  copyFileSync(join(repo, 'contracts/prose.lint.json'), join(root, 'contracts/prose.lint.json'));
  put(root, 'contracts/prose.lint.baseline.json', '{"findings":[]}\n');
  put(root, 'docs/ROSTER.md', '# Roster\n\n| HR id | Q | O | P | Status | S |\n|---|---|---|---|---|---|\n' +
    '| <a id="hr-1"></a>**HR-1** | q | o | p | ruled | s |\n| <a id="hr-2"></a>**HR-2** | q | o | p | reading | s |\n');
  put(root, 'claude/skills/target/SKILL.md', SKILL_TARGET);
  put(root, 'claude/skills/citer/SKILL.md', '# Citer\n\nSee [`target`](../target/SKILL.md) § 1, [`target`](../target/SKILL.md) § 1a and\n[`target`](../target/SKILL.md) § *State the cost*, and [`target`](../target/SKILL.md) § 2; HR-1 rules it.\n');
  return root;
}

function expectClean(root: string, name: string): void {
  const r = lint(root);
  assert.equal(r.status, 0, `${name}: expected exit 0, got ${r.status}\n${r.stdout}${r.stderr}`);
  console.log(`ok    ${name}`);
}

function expectFinding(root: string, rule: string, needle: RegExp, name: string): void {
  const r = lint(root);
  assert.equal(r.status, 1, `${name}: expected exit 1, got ${r.status}\n${r.stdout}${r.stderr}`);
  const hit = r.stdout.split('\n').some((l) => l.includes(` · ${rule} · `) && needle.test(l));
  assert.ok(hit, `${name}: no ${rule} line matching ${needle}\n${r.stdout}`);
  console.log(`ok    ${name} (${rule})`);
}

function expectWiring(root: string, needle: RegExp, name: string, ...extra: string[]): void {
  const r = lint(root, ...extra);
  assert.equal(r.status, 2, `${name}: expected exit 2, got ${r.status}\n${r.stdout}${r.stderr}`);
  assert.match(r.stderr, needle, `${name}: stderr does not name the cause\n${r.stderr}`);
  console.log(`ok    ${name} (exit 2)`);
}

function planted(rule: string, text: string, needle: RegExp, name: string, rel = 'claude/skills/plant/SKILL.md'): void {
  const root = base();
  put(root, rel, text);
  expectFinding(root, rule, needle, name);
}

try {
  // --- the clean shape: citations to headings, bold leads and numbered leads resolve ---
  expectClean(base(), 'a clean tree with headings, bold leads and a numbered bold lead resolving');

  // --- every fail rule fires on a planted copy, by id ---
  planted('PL-01', '# P\n\nThe body is assembled by hand from the ledger.\n', /by hand/, 'PL-01 an affirmative by-hand admission');
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nThe body is never assembled by hand; the maintainer merges by hand.\n');
    expectClean(root, 'PL-01 a refusal and a human act are not admissions');
  }
  planted('PL-02', '# P\n\nThe lookup stays here until nen grows a verb.\n', /until nen/, 'PL-02 until nen with no zheref/nen#N');
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nThe lookup stays here until nen grows a verb (zheref/nen#9).\nThe flag was unnamed until nen `0.7`.\n');
    expectClean(root, 'PL-02 a filed residue and a version history are clean');
  }
  planted('PL-03', '# P\n\nSelectors need nen v0.15.1+ (pin\nv0.21.0); older binaries exit 2.\n', /pin\s*v0\.21\.0/, 'PL-03 a stale pin wrapped across lines');
  planted('PL-03', '# P\n\nAt the pinned nen `0.7.0` the hook refuses.\n', /0\.7\.0/, 'PL-03 a present-tense pin claim');
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nThe pin is v0.24.0 and the floor needs nen 0.24. The hook arrived in nen 0.19\n(zheref/nen#357); through the pinned v0.6.0 it refused.\n\n> **RETIRED at nen `0.5`.** Once pinned v0.5.0.\n\n```sh\nnen v0.1.0+ (pin v0.1.0)\n```\n\nThe maintainer typed "need nen v0.1+ (pin v0.1.0)".\n');
    put(root, 'docs/ab/old.md', '# Old\n\nThe pin v0.3.0 was current then.\n');
    expectClean(root, 'PL-03 the pin, provenance, a past pin, RETIRED, a fence, quoted words and a record are clean');
  }
  planted('PL-04', '# P\n\nSee [`target`](../target/SKILL.md) § 3.\n', /§ 3 — no such heading/, 'PL-04 a numbered citation with no heading');
  planted('PL-04', '# P\n\nSee [`target`](../target/SKILL.md) § *Never there*.\n', /no heading or bold lead/, 'PL-04 a titled citation with no heading or lead');
  planted('PL-04', '# P\n\nSee [`gone`](../gone/SKILL.md).\n', /no such file/, 'PL-04 a relative link to no file');
  planted('PL-04', '# P\n\nSee [`target`](../target/SKILL.md#nowhere).\n', /no anchor #nowhere/, 'PL-04 a link to a missing anchor');
  planted('PL-04', '# P\n\nSee [`out`](../../../../outside.md).\n', /leaves the root/, 'PL-04 a link leaving the root');
  planted('PL-05', '# P\n\nFixed in #154 last week.\n', /#154/, 'PL-05 a bare #N');
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nFixed in zheref/hatsu#154, HA#12 and HA-PR-#303; see [x](#p).\n');
    expectClean(root, 'PL-05 coded references and a same-file anchor are clean');
  }
  planted('PL-06', '# P\n\nThe exit was verified live against the binary.\n', /verified live/, 'PL-06 an undated verified-live claim');
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nThe exit was verified live 2026-10-20 (docs/ab/plant.md).\n');
    expectClean(root, 'PL-06 a dated claim with its evidence path is clean');
  }
  planted('PL-11', '# P\n\nTBD: who reviews this.\n', /TBD/, 'PL-11 a to-do word is not a marker');
  planted('PL-11', '# P\n\n[NEEDS canon-merge: may this merge?] OPEN-1.\n', /human gate/, 'PL-11 a marker naming a human-gate row');
  planted('PL-11', '# P\n\n[NEEDS red-lint: retry?] OPEN-1.\n', /not an ask-class marker row/, 'PL-11 a marker naming an autonomous row');
  planted('PL-11', '# P\n\n[NEEDS missing-argument: which base?]\n', /no OPEN-n/, 'PL-11 a marker with no ledger reference');
  planted('PL-11', '# P\n\n[NEEDS missing-argument: a?] OPEN-1.\n\n[NEEDS missing-argument: b?] OPEN-2.\n\n[NEEDS missing-argument: c?] OPEN-3.\n\n[NEEDS missing-argument: d?] OPEN-4.\n', /over the limit of 3/, 'PL-11 a fourth marker in one skill');
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\n[NEEDS missing-configuration: is the cap a catalogue value?] OPEN-9 waits.\n[NEEDS ambiguous-intent: which reading?] (zheref/hatsu#9).\n');
    expectClean(root, 'PL-11 well-formed markers on ask-class rows with ledgers are clean');
  }
  planted('PL-12', '# P\n\nThe push path is HR-2.\n', /HR-2 is status reading/, 'PL-12 a reading cited as ruled');
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nHR-2 is a reading, never a push path; HR-1 and HR-20 are not it.\n');
    expectClean(root, 'PL-12 a reading named as one is clean, and HR-2 never matches HR-20');
  }

  // --- advisory rules print in --json and never count ---
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nThis might be fast for now.\nRun `nen loop slots --local-cap 9` today.\n\n## Residue\n\n1. The fetch is spelt in shell.\n');
    const r = lint(root, '--json');
    assert.equal(r.status, 0, `advisory: expected exit 0\n${r.stdout}${r.stderr}`);
    const j = JSON.parse(r.stdout) as { advisory: Array<{ rule: string }>; counts: Record<string, { new: number }> };
    for (const rule of ['PL-07', 'PL-08', 'PL-09', 'PL-10']) assert.ok(j.advisory.some((f) => f.rule === rule), `advisory ${rule} missing`);
    assert.equal(j.counts['PL-09'].new, 0);
    console.log('ok    PL-07..PL-10 advisory: printed in --json, never counted');
  }

  // --- hostile cases ---
  {
    const root = base();
    put(root, 'claude/skills/crlf/SKILL.md', '# C\r\n\r\n## 4. Real\r\n\r\nSee [`target`](../target/SKILL.md) § 5.\r\n');
    put(root, 'claude/skills/ok/SKILL.md', 'See [`crlf`](../crlf/SKILL.md) § 4.\n');
    const r = lint(root);
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stdout, /claude\/skills\/crlf\/SKILL\.md:5 · PL-04 · claude\/skills\/target\/SKILL\.md § 5/);
    assert.doesNotMatch(r.stdout, /ok\/SKILL\.md/);
    console.log('ok    hostile: CRLF headings resolve and a CRLF finding names its line');
  }
  planted('PL-04', 'See [`target`](../target/SKILL.md) § 9.\n', /§ 9 — no such heading/, 'hostile: a heading inside a fence is no heading');
  planted('PL-04', 'See [`target`](../target/SKILL.md) § 7.\n', /§ 7 — no such heading/, 'hostile: folded frontmatter carries no heading');
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '---\nname: plant\ndescription: >\n  folded\n  text\n---\n\nFixed in #77.\n');
    const r = lint(root);
    assert.match(r.stdout, /plant\/SKILL\.md:8 · PL-05/, `frontmatter line numbers\n${r.stdout}`);
    console.log('ok    hostile: lines after folded frontmatter keep their numbers');
  }
  {
    const root = base();
    const outside = join(scratch, `outside-${n}.md`);
    writeFileSync(outside, '# Outside\n');
    symlinkSync(outside, join(root, 'docs/linked.md'));
    expectWiring(root, /symlink docs\/linked\.md leaves the root/, 'hostile: a symlink leaving the root');
  }
  {
    const root = base();
    put(root, 'contracts/prose.lint.json', '{ "rules": [ ');
    expectWiring(root, /prose\.lint\.json is not valid JSON/, 'hostile: an unparseable contract');
  }
  {
    const root = base();
    put(root, 'contracts/prose.lint.json', JSON.stringify({ paths: { include: [] }, rules: [{ id: 'PL-01', class: 'nonsense', severity: 'fail' }] }));
    expectWiring(root, /lacks|unknown class/, 'hostile: a contract of the wrong shape');
  }
  {
    const root = base();
    put(root, 'claude/skills/bad/SKILL.md', Buffer.from([0x23, 0x20, 0xff, 0xfe, 0x0a]));
    expectWiring(root, /not valid UTF-8/, 'hostile: a non-UTF-8 file is never read as clean');
  }
  if (process.getuid?.() !== 0) {
    const root = base();
    put(root, 'claude/skills/locked/SKILL.md', '# L\n');
    chmodSync(join(root, 'claude/skills/locked/SKILL.md'), 0o000);
    expectWiring(root, /cannot read claude\/skills\/locked\/SKILL\.md/, 'hostile: an unreadable file is never read as clean');
    chmodSync(join(root, 'claude/skills/locked/SKILL.md'), 0o644);
  }
  {
    const root = base();
    put(root, 'contracts/prose.lint.baseline.json', '[');
    expectWiring(root, /baseline\.json is not valid JSON/, 'wiring: an unparseable baseline');
  }
  expectWiring(base(), /unknown flag --nope/, 'wiring: an unknown flag', '--nope');
  {
    const notHatsu = join(scratch, 'plain');
    mkdirSync(notHatsu);
    expectWiring(notHatsu, /not a Hatsu checkout/, 'wiring: a root that is not a Hatsu checkout');
  }

  // --- the ratchet ---
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nFixed in #154 last week.\n');
    const j = JSON.parse(lint(root, '--json').stdout) as { findings: Array<{ path: string; rule: string; text: string }> };
    const rows = j.findings.map((f) => ({ path: f.path, rule: f.rule, text: f.text, count: 1 }));
    put(root, 'contracts/prose.lint.baseline.json', JSON.stringify({ findings: rows }));
    expectClean(root, 'baseline: a baselined finding reads clean');
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nFixed in zheref/hatsu#154 last week.\n');
    const stale = lint(root);
    assert.equal(stale.status, 1);
    assert.match(stale.stdout, /baseline · PL-05 · claude\/skills\/plant\/SKILL\.md .* no longer found/);
    console.log('ok    baseline: a fixed finding leaves a stale row that must be removed');
    const git = (...a: string[]): void => { const r = spawnSync('git', ['-C', root, ...a], { encoding: 'utf8' }); assert.equal(r.status, 0, r.stderr); };
    put(root, 'contracts/prose.lint.baseline.json', '{"findings":[]}\n');
    git('init', '-q'); git('-c', 'user.name=f', '-c', 'user.email=f@f', 'add', '-A'); git('-c', 'user.name=f', '-c', 'user.email=f@f', 'commit', '-qm', 'base');
    git('branch', 'fixture-base');
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nFixed in #154 last week.\n');
    put(root, 'contracts/prose.lint.baseline.json', JSON.stringify({ findings: rows }));
    const grown = lint(root, '--base', 'fixture-base');
    assert.equal(grown.status, 1, grown.stdout + grown.stderr);
    assert.match(grown.stdout, /added over fixture-base; the baseline only shrinks/);
    console.log('ok    baseline: --base refuses a row the base did not carry');
  }
  {
    const root = base();
    put(root, 'contracts/pl03.json', JSON.stringify({ findings: [{ path: 'claude/skills/target/SKILL.md', rule: 'PL-03', text: 'pin v0.1.0', count: 1 }] }));
    expectWiring(root, /PL-03 is never baselined/, 'baseline: a PL-03 row is refused (HR-13)', '--baseline', 'contracts/pl03.json');
  }

  // --- the committed tree reads clean ---
  expectClean(repo, 'the committed tree, against its frozen baseline');
  console.log(`prose_ambiguity_check_fixture: all cases passed`);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
