#!/usr/bin/env node
// prose_ambiguity_check_fixture.mts — the canon-lint lane's fixture (HR-13, HR-4).
// Hermetic and offline: throwaway Hatsu-shaped roots prove every fail rule fires on a planted
// copy by its id and every advisory rule is printed and never counted; the hostile cases (CRLF,
// a heading inside a fence, folded frontmatter, a symlink leaving the root walked or linked, a
// marker naming a human-gate row, an unparseable or renumbered contract, an unreadable and a
// non-UTF-8 file, a 200 KB bracket paragraph) each read as named; the baseline admits, goes
// stale (a deleted file's row too) and refuses to grow, summed per key, under --base and under
// the CI form's --base-baseline; --history sums the last merged prose pull requests' shrink and says a cut-short walk; and the committed tree reads clean. These cases are the acceptance criteria owed to `nen canon lint`
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
  {
    const root = base();
    put(root, 'docs/ruling-records/e--R-2026-10-23-01.json', '{}\n');
    const row = (settles: string): string => `| <a id="hr-3"></a>**HR-3** · [e--R-2026-10-23-01](ruling-records/e--R-2026-10-23-01.json) | akatsuki-ai #69 OQ-1? | (A) Stage it — *see #70* | picked (A): \`Stage it\` | ruled | ${settles} |`;
    put(root, 'docs/ROSTER.md', `# Roster\n\n| HR id | Q | O | P | Status | S |\n|---|---|---|---|---|---|\n${row('Carried by zheref/akatsuki-ai#70')}\n`);
    expectClean(root, 'PL-05 a rendered record row: its question, options and answer are the record\'s text');
    put(root, 'docs/ROSTER.md', `# Roster\n\n| HR id | Q | O | P | Status | S |\n|---|---|---|---|---|---|\n${row('Carried by #71')}\n`);
    expectFinding(root, 'PL-05', /#71/, 'PL-05 a rendered record row still lints what it settles');
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
  // SEC-7: a contract-named read never follows a symlink out of the root, and never echoes bytes.
  for (const rel of ['nen/zz.json', 'nen/decisions.json', 'contracts/prose.lint.baseline.json']) {
    const root = base();
    const outside = join(scratch, `contract-leak-${n}.json`);
    writeFileSync(outside, 'SYNTHETIC_PLACEHOLDER\n');
    rmSync(join(root, rel), { force: true });
    symlinkSync(outside, join(root, rel));
    const r = lint(root);
    assert.equal(r.status, 2, `${rel}: expected exit 2, got ${r.status}\n${r.stdout}${r.stderr}`);
    assert.match(r.stderr, new RegExp(`symlink ${rel.replace(/[.]/g, '\\.')} leaves the root`), `${rel}: the refusal names it\n${r.stderr}`);
    assert.ok(!r.stderr.includes('SYNTHETIC'), `${rel}: a byte from outside the root reached the log\n${r.stderr}`);
    console.log(`ok    hostile: a contract-named read of ${rel} through a symlink leaving the root (exit 2, nothing echoed)`);
  }
  {
    const root = base();
    put(root, 'nen/zz.json', 'SYNTHETIC_PLACEHOLDER\n');
    const r = lint(root);
    assert.equal(r.status, 2, r.stdout + r.stderr);
    assert.match(r.stderr, /nen\/zz\.json is not valid JSON\n$/, r.stderr);
    assert.ok(!r.stderr.includes('SYNTHETIC'), `the invalid-JSON message quoted the file\n${r.stderr}`);
    console.log('ok    hostile: an invalid JSON file is named, never quoted');
  }
  {
    const root = base();
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nFixed in #154 last week.\n');
    put(root, 'contracts/prose.lint.baseline.json', JSON.stringify({ findings: [{ path: 'claude/skills/plant/SKILL.md', rule: 'PL-05', text: '#154', count: 1, extra: 1 }] }));
    expectWiring(root, /a row with an unknown key "extra"/, 'QA-16: a baseline row with an unexpected field');
    put(root, 'contracts/prose.lint.baseline.json', JSON.stringify({ findings: [], zzz: 1 }));
    expectWiring(root, /unknown top-level key "zzz"/, 'QA-16: a baseline with an unexpected top-level key');
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
    put(root, 'docs/t.md', `# T\n\n${'[a]('.repeat(250_000)}\n`);
    const t0 = Date.now();
    const r = lint(root);
    const ms = Date.now() - t0;
    assert.ok(ms < 15_000, `a 1 MB '[a](' line took ${ms} ms (QA-15)`);
    assert.ok(r.status === 0 || r.status === 1, r.stdout + r.stderr);
    console.log(`ok    hostile: a 1 MB '[a](' line with no ')' read in ${ms} ms (bounded link targets, QA-15)`);
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
    const git = (...a: string[]): void => { const r = spawnSync('git', ['-C', root, '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', ...a], { encoding: 'utf8' }); assert.equal(r.status, 0, r.stderr); };
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
    // The shrink is counted (zheref/hatsu#448, AC-4): a row the trusted base carried and this baseline dropped.
    writeFileSync(trusted, JSON.stringify({ findings: rows }));
    put(root, 'claude/skills/plant/SKILL.md', '# P\n\nFixed in zheref/hatsu#154 last week.\n');
    put(root, 'contracts/prose.lint.baseline.json', '{"findings":[]}\n');
    const shrunk = lint(root, '--base-baseline', trusted);
    assert.equal(shrunk.status, 0, shrunk.stdout + shrunk.stderr);
    assert.match(shrunk.stdout, / · 1 removed over .*trusted-\d+\.json · /);
    assert.equal(JSON.parse(lint(root, '--base-baseline', trusted, '--json').stdout).removedBaseline, 1);
    assert.equal(JSON.parse(lint(root, '--json').stdout).removedBaseline, null);
    assert.doesNotMatch(lint(root).stdout, /removed over/);
    console.log('ok    baseline: the rows a pull request removed are counted against the trusted base, and null with no base');
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
  // --- --history: the shrink of the last <n> merged prose pull requests (zheref/hatsu#448, AC-4) ---
  {
    const G = ['-c', 'user.name=f', '-c', 'user.email=f@f', '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null'];
    const gitIn = (root: string, ...a: string[]): void => { const r = spawnSync('git', ['-C', root, ...G, ...a], { encoding: 'utf8' }); assert.equal(r.status, 0, r.stderr); };
    const hist = (root: string, env: Record<string, string>, ...a: string[]): Run =>
      spawnSync(process.execPath, [script, '--root', root, ...a], { encoding: 'utf8', env: { ...process.env, ...env } }) as Run;
    const merge = (root: string, n: string, branch: string, edit: () => void): void => {
      gitIn(root, 'checkout', '-qb', branch); edit(); gitIn(root, 'add', '-A'); gitIn(root, 'commit', '-qm', branch);
      gitIn(root, 'checkout', '-q', 'main'); gitIn(root, 'merge', '-q', '--no-ff', '-m', `Merge pull request #${n} from f/${branch}`, branch);
    };
    const direct = (root: string, subject: string, edit: () => void): void => { edit(); gitIn(root, 'add', '-A'); gitIn(root, 'commit', '-qm', subject); };
    const row = { path: 'claude/skills/plant/SKILL.md', rule: 'PL-05', text: 'fixed in #154 last week.', count: 2 };
    const root = base();
    // The ratchet's start: a first commit with no baseline, then the baseline lands on a merge.
    rmSync(join(root, 'contracts/prose.lint.baseline.json'));
    gitIn(root, 'init', '-q', '-b', 'main'); gitIn(root, 'add', '-A'); gitIn(root, 'commit', '-qm', 'before the ratchet');
    merge(root, '1', 'ratchet', () => { put(root, 'docs/plant.md', '# P\n'); put(root, 'contracts/prose.lint.baseline.json', JSON.stringify({ findings: [row] })); });
    merge(root, '2', 'shrink', () => { put(root, 'claude/skills/plant/SKILL.md', '# P\n\nFixed.\n'); put(root, 'contracts/prose.lint.baseline.json', JSON.stringify({ findings: [{ ...row, count: 1 }] })); });
    merge(root, '3', 'code-only', () => { put(root, 'scripts/x.mts', '// x\n'); });
    merge(root, '4', 'non-ascii', () => { put(root, 'docs/café.md', '# C\n'); });
    direct(root, 'docs: squash-merged shrink (#5)', () => { put(root, 'claude/skills/plant/SKILL.md', '# P\n\nFixed again.\n'); put(root, 'contracts/prose.lint.baseline.json', '{"findings":[]}\n'); });
    direct(root, 'docs: a rebase-merged commit naming no PR', () => { put(root, 'docs/plant.md', '# P\n\nRebased.\n'); });
    gitIn(root, 'checkout', '-qb', 'local'); put(root, 'docs/local.md', '# L\n'); gitIn(root, 'add', '-A'); gitIn(root, 'commit', '-qm', 'local');
    gitIn(root, 'checkout', '-q', 'main'); gitIn(root, 'merge', '-q', '--no-ff', '-m', 'Merge branch local', 'local');
    merge(root, '6', 'drops-baseline', () => { put(root, 'docs/plant.md', '# P\n\nDropped.\n'); rmSync(join(root, 'contracts/prose.lint.baseline.json')); });
    direct(root, 'chore: restore the baseline', () => { put(root, 'contracts/prose.lint.baseline.json', '{"findings":[]}\n'); });
    const all = hist(root, {}, '--history', '10');
    assert.equal(all.status, 0, all.stdout + all.stderr);
    assert.match(all.stdout, /^history · #6 · [0-9a-f]{9} · merge · 1 prose file · baseline absent in its tree, not counted$/m);
    assert.match(all.stdout, /^history · #5 · [0-9a-f]{9} · squash · 1 prose file · 1 removed$/m);
    assert.match(all.stdout, /^history · #4 · [0-9a-f]{9} · merge · 1 prose file · 0 removed$/m, 'a non-ASCII prose path reads as itself');
    assert.match(all.stdout, /^history · #2 · [0-9a-f]{9} · merge · 1 prose file · 1 removed$/m);
    assert.doesNotMatch(all.stdout, /#3 |#1 |local/, 'a code-only merge, a non-PR merge and the ratchet\'s own landing are not counted as PRs');
    assert.match(all.stdout, /^canon-lint history: last 4 of 10 prose pull requests on [0-9a-f]{9} \(the ratchet starts there: an earlier pull request's parent carries no baseline\) · 2 removed · skipped 1 prose commits naming no PR and 1 non-PR merges · baseline 0 findings$/m);
    const one = JSON.parse(hist(root, {}, '--history', '1', '--json').stdout);
    assert.equal(one.contract, 'hatsu.prose-lint.history/v0.1');
    assert.equal(one.end, 'complete');
    assert.deepEqual(one.pullRequests.map((p: { number: string; removed: number | null; baselineAbsent: boolean }) => [p.number, p.removed, p.baselineAbsent]), [['6', null, true]]);
    assert.equal(one.removed, 0, 'a PR whose tree has no baseline is left out of the sum');
    assert.equal(one.baselineFindings, 0);
    const full = JSON.parse(hist(root, {}, '--history', '10', '--json').stdout);
    assert.equal(full.skippedNonMergeProse, 1);
    assert.equal(full.skippedNonPrMergeProse, 1);
    console.log('ok    --history: merge and squash PRs counted, a baseline-less tree flagged and left out, a non-ASCII path read, skipped commits counted, the ratchet start said');
    // history-start: a baseline from the first commit, fewer PRs than asked.
    const short = base();
    gitIn(short, 'init', '-q', '-b', 'main'); gitIn(short, 'add', '-A'); gitIn(short, 'commit', '-qm', 'root');
    merge(short, '9', 'one', () => { put(short, 'docs/one.md', '# O\n'); });
    merge(short, '10', 'two', () => { put(short, 'docs/two.md', '# T\n'); });
    assert.equal(JSON.parse(hist(short, {}, '--history', '5', '--json').stdout).end, 'history-start');
    assert.match(hist(short, {}, '--history', '5').stdout, /last 2 of 5 prose pull requests on [0-9a-f]{9} \(the first-parent history ends there\)/);
    // scan-cap: the scan stops before the history does, and says so.
    const capped = hist(short, { HATSU_PROSE_HISTORY_SCAN: '1' }, '--history', '5');
    assert.equal(capped.status, 0, capped.stderr);
    assert.match(capped.stdout, /last 1 of 5 prose pull requests on [0-9a-f]{9} \(cut short: the scan stopped at 1 commits, so older pull requests were not read\)/);
    const badCap = hist(short, { HATSU_PROSE_HISTORY_SCAN: '0' }, '--history', '5');
    assert.equal(badCap.status, 2, badCap.stdout + badCap.stderr);
    assert.match(badCap.stderr, /HATSU_PROSE_HISTORY_SCAN must be a whole number/);
    console.log('ok    --history: history-start and scan-cap are each said, never read as the ratchet start');
    // A shallow clone and a HEAD with no baseline are wiring, never a short history.
    const shallow = join(scratch, `shallow-${++n}`);
    const cl = spawnSync('git', ['clone', '-q', '--depth', '1', `file://${short}`, shallow], { encoding: 'utf8' });
    assert.equal(cl.status, 0, cl.stderr);
    expectWiring(shallow, /this repository is shallow/, 'wiring: --history in a shallow clone', '--history', '5');
    const noBase = base();
    rmSync(join(noBase, 'contracts/prose.lint.baseline.json'));
    gitIn(noBase, 'init', '-q', '-b', 'main'); gitIn(noBase, 'add', '-A'); gitIn(noBase, 'commit', '-qm', 'root');
    expectWiring(noBase, /HEAD carries no contracts\/prose\.lint\.baseline\.json/, 'wiring: --history with no baseline at HEAD', '--history', '5');
    expectWiring(root, /--history needs a whole number from 1 to 100/, 'wiring: --history 0', '--history', '0');
    expectWiring(root, /--history needs a whole number from 1 to 100/, 'wiring: --history 101', '--history', '101');
    expectWiring(root, /takes neither --base nor --base-baseline/, 'wiring: --history with --base-baseline', '--history', '3', '--base-baseline', join(scratch, 'x.json'));
    expectWiring(root, /--self-test takes no other flag/, 'wiring: --history with --self-test', '--history', '3', '--self-test');
    expectWiring(root, /--self-test takes no other flag/, 'wiring: --self-test with --root', '--self-test');
    const bare = base();
    expectWiring(bare, /git rev-parse --is-shallow-repository failed/, 'wiring: --history outside a git checkout', '--history', '3');
    // --base reads a non-ASCII changed path as itself (NUL-split, unquoted).
    gitIn(short, 'branch', '-f', 'fixture-b');
    direct(short, 'a finding in a non-ASCII path', () => { put(short, 'docs/né.md', '# N\n\nFixed in #8.\n'); });
    const nb = lint(short, '--base', 'fixture-b');
    assert.equal(nb.status, 1, nb.stdout + nb.stderr);
    assert.match(nb.stdout, /^docs\/né\.md:3 · PL-05 · /m);
    console.log('ok    --base: a non-ASCII changed path is in scope');
  }
  {
    const root = base();
    put(root, 'contracts/pl03.json', JSON.stringify({ findings: [{ path: 'claude/skills/target/SKILL.md', rule: 'PL-03', text: 'pin v0.1.0', count: 1 }] }));
    expectWiring(root, /PL-03 is never baselined/, 'baseline: a PL-03 row is refused (HR-13)', '--baseline', 'contracts/pl03.json');
    put(root, 'contracts/pl04.json', JSON.stringify({ findings: [{ path: 'claude/skills/citer/SKILL.md', rule: 'PL-04', text: 'x — no such file', count: 1 }] }));
    expectWiring(root, /PL-04 is never baselined/, 'baseline: a PL-04 row is refused (HR-13)', '--baseline', 'contracts/pl04.json');
  }

  // --- invoked through a symlinked directory, the guard still runs ---
  // The entry guard compares REAL paths: a caller handing the script a path through a symlink
  // (a mktmpdir under /var on macOS) must get a verdict, never an empty exit 0.
  {
    const root = base();
    const viaLink = join(scratch, 'via-link');
    symlinkSync(scripts, viaLink);
    const r = spawnSync(process.execPath, [join(viaLink, 'prose_ambiguity_check.mts'), '--root', root], { encoding: 'utf8' }) as Run;
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /^canon-lint: \d+ files · 0 new · 0 stale · 0 grown/m);
    console.log('ok    entry: invoked through a symlinked directory, the lint runs and prints its verdict');
  }

  // --- the committed tree reads clean ---
  expectClean(repo, 'the committed tree, against its frozen baseline');
  console.log(`prose_ambiguity_check_fixture: all cases passed`);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
