#!/usr/bin/env node
// Verify the Git-only history used by the morning desk.
import assert from 'node:assert/strict';
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { run } from './prose_lint_history.mts';

const scripts = dirname(fileURLToPath(import.meta.url));
const repo = dirname(scripts);
const script = join(scripts, 'prose_lint_history.mts');

type Run = { status: number | null; stdout: string; stderr: string };
function invoke(root: string, extra: string[], scan?: string): Run {
  const previous = process.env.HATSU_PROSE_HISTORY_SCAN;
  try {
    if (scan === undefined) delete process.env.HATSU_PROSE_HISTORY_SCAN;
    else process.env.HATSU_PROSE_HISTORY_SCAN = scan;
    return run(['--root', root, ...extra]);
  } finally {
    if (previous === undefined) delete process.env.HATSU_PROSE_HISTORY_SCAN;
    else process.env.HATSU_PROSE_HISTORY_SCAN = previous;
  }
}

function put(root: string, rel: string, text: string | Buffer): void {
  mkdirSync(dirname(join(root, rel)), { recursive: true });
  writeFileSync(join(root, rel), text);
}

export function runHistoryFixture(): void {
  const scratch = mkdtempSync(join(tmpdir(), 'hatsu-prose-history-'));
  let n = 0;
  function base(): string {
    const root = join(scratch, `root-${++n}`);
    put(root, '.claude-plugin/plugin.json', '{"name":"hatsu"}\n');
    put(root, 'nen/contract.json', '{}\n');
    mkdirSync(join(root, 'contracts'), { recursive: true });
    copyFileSync(join(repo, 'contracts/prose.lint.json'), join(root, 'contracts/prose.lint.json'));
    put(root, 'contracts/prose.lint.baseline.json', '{"findings":[]}\n');
    return root;
  }

  function expectWiring(root: string, needle: RegExp, name: string, ...extra: string[]): void {
    const r = invoke(root, extra);
    assert.equal(r.status, 2, `${name}: expected exit 2, got ${r.status}\n${r.stdout}${r.stderr}`);
    assert.match(r.stderr, needle, `${name}: stderr does not name the cause\n${r.stderr}`);
    console.log(`ok    ${name} (exit 2)`);
  }

  try {
    const G = ['-c', 'user.name=f', '-c', 'user.email=f@f', '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null'];
    const gitIn = (root: string, ...a: string[]): void => { const r = spawnSync('git', ['-C', root, ...G, ...a], { encoding: 'utf8' }); assert.equal(r.status, 0, r.stderr); };
    const clean = Object.fromEntries(Object.entries(process.env).filter(([k]) => k !== 'HATSU_PROSE_HISTORY_SCAN' && !k.startsWith('GIT_')));
    const hist = (root: string, env: Record<string, string>, ...a: string[]): Run =>
      invoke(root, a, env.HATSU_PROSE_HISTORY_SCAN);
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
    merge(root, '8', 'after-the-drop', () => { put(root, 'docs/plant.md', '# P\n\nAfter.\n'); });
    direct(root, 'chore: restore the baseline', () => { put(root, 'contracts/prose.lint.baseline.json', '{"findings":[]}\n'); });
    const all = hist(root, {}, '--history', '10');
    const cli = spawnSync(process.execPath, [script, '--root', root, '--history', '10'], { encoding: 'utf8', env: clean });
    assert.equal(cli.status, 0, cli.stderr);
    assert.equal(cli.stdout, all.stdout);
    assert.equal(all.status, 0, all.stdout + all.stderr);
    assert.match(all.stdout, /^history · #8 · [0-9a-f]{9} · merge · 1 prose file · baseline absent in its tree or its parent's, not counted$/m, 'a parent with no baseline past the start is flagged, never the start');
    assert.match(all.stdout, /^history · #6 · [0-9a-f]{9} · merge · 1 prose file · baseline absent in its tree or its parent's, not counted$/m);
    assert.match(all.stdout, /^history · #5 · [0-9a-f]{9} · squash · 1 prose file · 1 removed$/m);
    assert.match(all.stdout, /^history · #4 · [0-9a-f]{9} · merge · 1 prose file · 0 removed$/m, 'a non-ASCII prose path reads as itself');
    assert.match(all.stdout, /^history · #2 · [0-9a-f]{9} · merge · 1 prose file · 1 removed$/m);
    assert.doesNotMatch(all.stdout, /#3 |#1 |local/, 'a code-only merge, a non-PR merge and the ratchet\'s own landing are not counted as PRs');
    assert.match(all.stdout, /^canon-lint history: last 5 of 10 prose pull requests on [0-9a-f]{9} \(the ratchet starts there: [0-9a-f]{9} added the baseline\) · 2 removed · skipped 1 prose commits naming no PR and 1 non-PR merges · baseline 0 findings$/m);
    const one = JSON.parse(hist(root, {}, '--history', '1', '--json').stdout);
    assert.equal(one.contract, 'hatsu.prose-lint.history/v0.1');
    assert.equal(one.end, 'complete');
    assert.deepEqual(one.pullRequests.map((p: { number: string; removed: number | null; baselineAbsent: boolean }) => [p.number, p.removed, p.baselineAbsent]), [['8', null, true]]);
    assert.equal(one.removed, 0, 'a PR whose tree has no baseline is left out of the sum');
    assert.equal(one.baselineFindings, 0);
    const full = JSON.parse(hist(root, {}, '--history', '10', '--json').stdout);
    assert.equal(full.skippedNonMergeProse, 1);
    assert.equal(full.skippedNonPrMergeProse, 1);
    assert.equal(full.end, 'ratchet-start');
    assert.equal(full.ratchetStart, spawnSync('git', ['-C', root, 'rev-parse', ':/^Merge pull request #1 '], { encoding: 'utf8' }).stdout.trim(), 'the start is the oldest commit adding the baseline, not the restore');
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
    const atCap = hist(short, { HATSU_PROSE_HISTORY_SCAN: '3' }, '--history', '5');
    assert.match(atCap.stdout, /\(the first-parent history ends there\)/, 'a history of exactly the cap is not cut short');
    console.log('ok    --history: history-start and scan-cap are each said, never read as the ratchet start; exactly the cap is not scan-cap');
    // The baseline lands on a direct commit: that commit is the start, and an older prose commit is never read.
    const direct1 = base();
    rmSync(join(direct1, 'contracts/prose.lint.baseline.json'));
    gitIn(direct1, 'init', '-q', '-b', 'main'); gitIn(direct1, 'add', '-A'); gitIn(direct1, 'commit', '-qm', 'root');
    direct(direct1, 'docs: before the ratchet', () => { put(direct1, 'docs/before.md', '# B\n'); });
    direct(direct1, 'chore: land the ratchet', () => { put(direct1, 'docs/landing.md', '# L\n'); put(direct1, 'contracts/prose.lint.baseline.json', '{"findings":[]}\n'); });
    merge(direct1, '7', 'after', () => { put(direct1, 'docs/after.md', '# A\n'); });
    const d = JSON.parse(hist(direct1, {}, '--history', '5', '--json').stdout);
    assert.equal(d.end, 'ratchet-start');
    assert.deepEqual(d.pullRequests.map((p: { number: string }) => p.number), ['7']);
    assert.equal(d.skippedNonMergeProse, 0, 'pre-ratchet commits and the landing itself are never counted as skipped');
    console.log('ok    --history: a baseline landing on a direct commit is the start, and nothing older is counted');
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
    const bare = base();
    expectWiring(bare, /git rev-parse --is-shallow-repository failed/, 'wiring: --history outside a git checkout', '--history', '3');
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
}
