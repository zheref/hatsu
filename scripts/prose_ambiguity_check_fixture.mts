#!/usr/bin/env node
// prose_ambiguity_check_fixture.mts — the canon-lint lane's fixture (HR-13, HR-4).
// Hermetic and offline: throwaway Hatsu-shaped roots prove every fail rule fires on a planted
// copy by its id and every advisory rule is printed and never counted; the hostile cases (CRLF,
// a heading inside a fence, folded frontmatter, a symlink leaving the root walked or linked, a
// marker naming a human-gate row, an unparseable or renumbered contract, an unreadable and a
// non-UTF-8 file, a 200 KB bracket paragraph) each read as named; the baseline admits, goes
// stale (a deleted file's row too) and refuses to grow, summed per key, under --base and under
// the CI form's --base-baseline; and the committed tree reads clean. These cases are the acceptance criteria owed to `nen canon lint`
// (zheref/nen#481). Run: nen shu test --lane canon-lint --repo <hatsu>.
import assert from 'node:assert/strict';
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
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
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\n[NEEDS missing-configuration: is the cap a catalogue value?] OPEN-9 waits.\n[NEEDS missing-maintainer-choice: which reading?] (zheref/hatsu#9).\n');
    expectClean(root, 'PL-11 well-formed markers on ask-class rows with ledgers are clean');
  }
  planted('PL-11', '# P\n\n[NEEDS ambiguous-intent: which reading?] OPEN-1.\n', /row ambiguous-intent is a human gate/, 'PL-11 every human-gate row is refused, ambiguous-intent included (HR-4)');
  {
    const root = base();
    const c = JSON.parse(readFileSync(join(root, 'contracts/prose.lint.json'), 'utf8'));
    c.markerRows.push('ambiguous-intent');
    put(root, 'contracts/prose.lint.json', JSON.stringify(c));
    expectWiring(root, /markerRows names ambiguous-intent, which is class human-gate/, 'contract: a human-gate marker row is refused (HR-4)');
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
    put(root, 'claude/skills/plant/SKILL.md', '---\nname: plant\ndescription: fixed in #76\n  folded\n  text\n---\n\nFixed in #77.\n');
    const r = lint(root);
    assert.match(r.stdout, /plant\/SKILL\.md:8 · PL-05/, `frontmatter line numbers\n${r.stdout}`);
    assert.match(r.stdout, /plant\/SKILL\.md:3 · PL-05 · .*#76/, `a finding inside the frontmatter names its own line\n${r.stdout}`);
    console.log('ok    hostile: frontmatter findings and lines after folded frontmatter keep their numbers');
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

  // --- parsing edges (Nobunaga, Phinks) ---
  {
    const root = base();
    put(root, 'docs/t.md', '# T\n\n1. **RETIRED.** The old step.\n2. The pin v0.1.0 is current; fixed in #12.\n');
    const r = lint(root);
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stdout, /docs\/t\.md:4 · PL-03 · pin v0\.1\.0/);
    assert.match(r.stdout, /docs\/t\.md:4 · PL-05/);
    console.log('ok    RETIRED: a list item ends at the next item at the same indent');
  }
  {
    const root = base();
    put(root, 'docs/t.md', '# T\n\nUse `"` as the delimiter. See [gone](nowhere.md) and the pin v0.1.0 here. Then "x" ends.\n');
    const r = lint(root);
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stdout, / · PL-04 · nowhere\.md — no such file/);
    assert.match(r.stdout, / · PL-03 · pin v0\.1\.0/);
    put(root, 'docs/u.md', '# U\n\nAn opening " and the pin v0.1.0\nhere, closed " on the next line.\n');
    assert.match(lint(root).stdout, /docs\/u\.md:3 · PL-03 · pin v0\.1\.0/);
    console.log('ok    quoted words: a quote inside a code span pairs nothing, and quotes pair within one line');
  }
  {
    const root = base();
    put(root, 'docs/t.md', '# T\n\n## The `prose_size_check` lane\n\n## A _stressed_ word\n\nSee [a](#the-prose_size_check-lane) and [b](#a-stressed-word).\n');
    expectClean(root, 'slug: GitHub keeps `_` in a code span and drops emphasis underscores');
    put(root, 'docs/t.md', '# T\n\n## The `prose_size_check` lane\n\nSee [a](#the-prosesizecheck-lane).\n');
    expectFinding(root, 'PL-04', /no anchor #the-prosesizecheck-lane/, 'slug: an anchor with the underscore dropped resolves to nothing');
  }
  {
    const root = base();
    const outside = join(scratch, `leak-${n}.md`);
    writeFileSync(outside, '# Secret Heading\n');
    mkdirSync(join(root, 'misc'), { recursive: true });
    symlinkSync(outside, join(root, 'misc/leak.md'));
    put(root, 'docs/t.md', '# T\n\nSee [x](../misc/leak.md#guess-wrong).\n');
    expectWiring(root, /link \.\.\/misc\/leak\.md#guess-wrong in docs\/t\.md resolves through a symlink leaving the root/, 'hostile: a linked symlink leaving the root, outside the walk');
  }
  {
    const root = base();
    put(root, 'docs/t.md', `# T\n\n${'['.repeat(200_000)}\n\n${'word '.repeat(40_000)}by hand.\n`);
    const t0 = Date.now();
    const r = lint(root);
    const ms = Date.now() - t0;
    assert.ok(ms < 15_000, `a 200 KB '[' paragraph took ${ms} ms`);
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stdout, /docs\/t\.md:\d+ · PL-01/);
    console.log(`ok    hostile: a 200 KB '[' paragraph and a 200 KB clause read in ${ms} ms (bounded spans)`);
  }
  {
    const root = base();
    put(root, 'claude/skills/empty/SKILL.md', '');
    put(root, 'docs/with space.md', '# W\n\nFixed in #3.\n');
    put(root, 'docs/fence.md', '# F\n\n```sh\nFixed in #4.\n');
    put(root, 'docs/front.md', '---\nname: x\nFixed in #6.\n');
    const r = lint(root);
    assert.equal(r.status, 1, r.stdout + r.stderr);
    assert.match(r.stdout, /docs\/with space\.md:3 · PL-05/);
    assert.doesNotMatch(r.stdout, /docs\/fence\.md/);
    assert.match(r.stdout, /docs\/front\.md:3 · PL-05/);
    assert.doesNotMatch(r.stdout, /empty\/SKILL\.md/);
    console.log('ok    hostile: an empty file is clean, a spaced path is named, an unclosed fence exempts the rest, an unclosed frontmatter is linted');
  }

  // --- the contract's fixed ids (Chrollo BC-6, Phinks QA-18) ---
  const contractWith = (edit: (c: { rules: Array<Record<string, unknown>>; [k: string]: unknown }) => void): string => {
    const root = base();
    const c = JSON.parse(readFileSync(join(root, 'contracts/prose.lint.json'), 'utf8'));
    edit(c);
    put(root, 'contracts/prose.lint.json', JSON.stringify(c));
    return root;
  };
  expectWiring(contractWith((c) => { c.rules.find((r) => r.id === 'PL-03')!.id = 'PL-13'; }), /PL-13 has no handler; rule ids are fixed/, 'contract: a renumbered rule is refused');
  expectWiring(contractWith((c) => { c.rules.find((r) => r.id === 'PL-05')!.class = 'hedge'; }), /PL-05 is class hedge, but its handler is bare-ref/, 'contract: a reclassed rule is refused');
  expectWiring(contractWith((c) => { delete c.rules.find((r) => r.id === 'PL-03')!.patterns; }), /PL-03 \(stale-version\) lacks patterns/, 'contract: a class missing a key its handler reads is refused');
  expectWiring(contractWith((c) => { delete c.rules.find((r) => r.id === 'PL-12')!.pattern; }), /PL-12 \(reading-cited-as-ruled\) lacks pattern/, 'contract: PL-12 with no pattern is refused, never green');
  expectWiring(contractWith((c) => { delete c.retired; }), /lacks retired\.rules/, 'contract: retired.rules is required');
  {
    const root = contractWith((c) => { (c.retired as { rules: string[] }).rules = ['PL-02', 'PL-03', 'PL-10']; c.extra = 'tolerated'; });
    put(root, 'docs/t.md', '# T\n\n> **RETIRED.** Fixed in #9.\n');
    expectFinding(root, 'PL-05', /#9/, 'contract: a RETIRED block is exempt only from retired.rules (an unknown key is tolerated)');
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
    // The CI form: no --base, the trusted base copy passed as --base-baseline.
    const trusted = join(scratch, `trusted-${n}.json`);
    writeFileSync(trusted, '{"findings":[]}\n');
    const ci = lint(root, '--base-baseline', trusted);
    assert.equal(ci.status, 1, ci.stdout + ci.stderr);
    assert.match(ci.stdout, /added over .*trusted-\d+\.json; the baseline only shrinks/);
    assert.equal(lint(root).status, 0, 'without a base the grown baseline reads clean, which is why CI passes one');
    console.log('ok    baseline: the CI form refuses growth over the trusted base copy with no merge base');
    // A row raised from 1 to 2 (two identical findings) is growth, summed per key.
    writeFileSync(trusted, JSON.stringify({ findings: rows }));
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nFixed in #154 last week.\n\nFixed in #154 last week.\n');
    put(root, 'contracts/prose.lint.baseline.json', JSON.stringify({ findings: rows.map((r) => ({ ...r, count: 2 })) }));
    assert.match(lint(root, '--base-baseline', trusted).stdout, /added over/);
    // The same budget split into two rows of one is a repeated key: refused.
    put(root, 'contracts/prose.lint.baseline.json', JSON.stringify({ findings: [...rows, ...rows] }));
    expectWiring(root, /repeats the row/, 'baseline: a split row is a repeated key, refused', '--base-baseline', trusted);
    console.log('ok    baseline: growth is summed per key');
    // --base scopes findings to changed files: an unchanged file's finding is not reported.
    put(root, 'contracts/prose.lint.baseline.json', '{"findings":[]}\n');
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nClean now.\n');
    put(root, 'docs/old.md', '# O\n\nFixed in #8.\n');
    git('-c', 'user.name=f', '-c', 'user.email=f@f', 'add', '-A'); git('-c', 'user.name=f', '-c', 'user.email=f@f', 'commit', '-qm', 'scope');
    git('branch', '-f', 'fixture-scope');
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nClean still.\n');
    const scoped = lint(root, '--base', 'fixture-scope');
    assert.equal(scoped.status, 0, scoped.stdout + scoped.stderr);
    assert.doesNotMatch(scoped.stdout, /docs\/old\.md/);
    console.log('ok    --base: an unchanged file\'s finding is not reported');
    // A row for a deleted file is stale, under --base and without it.
    put(root, 'contracts/prose.lint.baseline.json', JSON.stringify({ findings: [{ path: 'docs/deleted.md', rule: 'PL-05', text: 'x', count: 3 }] }));
    for (const extra of [[], ['--base', 'fixture-scope']]) {
      const st = lint(root, ...extra);
      assert.equal(st.status, 1, st.stdout + st.stderr);
      assert.match(st.stdout, /baseline · PL-05 · docs\/deleted\.md · x — no longer found/);
    }
    console.log('ok    baseline: a row whose file the walk does not read is stale, with or without --base');
    // A base that carries no baseline says so.
    rmSync(join(root, 'contracts/prose.lint.baseline.json'));
    git('-c', 'user.name=f', '-c', 'user.email=f@f', 'add', '-A'); git('-c', 'user.name=f', '-c', 'user.email=f@f', 'commit', '-qm', 'no baseline');
    git('branch', '-f', 'fixture-bare');
    put(root, 'contracts/prose.lint.baseline.json', '{"findings":[]}\n');
    const bare = lint(root, '--base', 'fixture-bare');
    assert.match(bare.stdout, /notice: fixture-bare carries no contracts\/prose\.lint\.baseline\.json; baseline growth is not checked/);
    console.log('ok    --base: a base with no baseline is said, never silently skipped');
    expectWiring(root, /--base-baseline .*missing/, 'wiring: a missing --base-baseline file', '--base-baseline', join(scratch, 'nope.json'));
  }
  {
    const root = base();
    put(root, 'contracts/pl03.json', JSON.stringify({ findings: [{ path: 'claude/skills/target/SKILL.md', rule: 'PL-03', text: 'pin v0.1.0', count: 1 }] }));
    expectWiring(root, /PL-03 is never baselined/, 'baseline: a PL-03 row is refused (HR-13)', '--baseline', 'contracts/pl03.json');
    put(root, 'contracts/pl04.json', JSON.stringify({ findings: [{ path: 'claude/skills/citer/SKILL.md', rule: 'PL-04', text: 'x — no such file', count: 1 }] }));
    expectWiring(root, /PL-04 is never baselined/, 'baseline: a PL-04 row is refused (HR-13)', '--baseline', 'contracts/pl04.json');
  }

  // --- the committed tree reads clean ---
  expectClean(repo, 'the committed tree, against its frozen baseline');
  console.log(`prose_ambiguity_check_fixture: all cases passed`);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
