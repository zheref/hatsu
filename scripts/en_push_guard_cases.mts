// Shared behavior & guard cases for scripts/en_push_guard.mts (zheref/hatsu#611).
// Executed by both scripts/en_push_guard_fixture.test.mts (Vitest) and
// scripts/en_push_guard_coverage.test.mts (Node --test --experimental-test-coverage).
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  EnPushGuardError,
  branchToSlug,
  evaluateEnPushGuard,
  parseCliArgs,
  renderHuman,
  resolveCarryingLedgerTarget,
  sanitizeText,
} from './en_push_guard.mts';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const GUARD_SCRIPT = join(ROOT, 'scripts', 'en_push_guard.mts');

function mustGit(cwd: string, args: string[]): string {
  const res = spawnSync('git', ['-C', cwd, ...args], { encoding: 'utf8' });
  assert.equal(res.status, 0, `git ${args.join(' ')} failed: ${res.stderr}`);
  return res.stdout.trim();
}

function setupRepoWithCarryCommits() {
  const tmp = realpathSync(mkdtempSync(join(tmpdir(), 'en-push-guard-')));
  const bare = join(tmp, 'origin.git');
  const work = join(tmp, 'work');
  mustGit(tmp, ['init', '--bare', bare]);
  mustGit(tmp, ['clone', bare, work]);
  mustGit(work, ['config', 'user.email', 'test@example.com']);
  mustGit(work, ['config', 'user.name', 'Test User']);
  mustGit(work, ['checkout', '-b', 'main']);
  writeFileSync(join(work, 'README.md'), 'base\n', 'utf8');
  mustGit(work, ['add', 'README.md']);
  mustGit(work, ['commit', '-m', 'base commit']);
  mustGit(work, ['push', '-u', 'origin', 'main']);

  mustGit(work, ['checkout', '-b', 'pro/kurapika/feat-a']);
  writeFileSync(join(work, 'feat.txt'), 'v1\n', 'utf8');
  mustGit(work, ['add', 'feat.txt']);
  mustGit(work, ['commit', '-m', 'feat: initial pr commit']);
  mustGit(work, ['push', '-u', 'origin', 'pro/kurapika/feat-a']);
  const prHeadSha = mustGit(work, ['rev-parse', 'HEAD']);

  // En commits a local fix that has NOT yet been pushed.
  writeFileSync(join(work, 'feat.txt'), 'v2 fix\n', 'utf8');
  mustGit(work, ['add', 'feat.txt']);
  mustGit(work, ['commit', '-m', 'fix: unpushed en follow-up']);
  const unpushedSha = mustGit(work, ['rev-parse', 'HEAD']);

  return { tmp, bare, work, prHeadSha, unpushedSha };
}

export interface EnPushGuardCase {
  readonly name: string;
  readonly run: () => void | Promise<void>;
}

export const enPushGuardCases: EnPushGuardCase[] = [
  {
    name: 'HA#611 SC-1 & AC-1: OPEN PR allows push after state read; MERGED & CLOSED PRs refuse push (0 commits pushed) with carrying-PR fallback',
    run: () => {
      const { tmp, work, prHeadSha, unpushedSha } = setupRepoWithCarryCommits();
      try {
        let reads = 0;
        const openRes = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => {
            reads += 1;
            return {
              status: 0,
              stdout: JSON.stringify({
                state: 'OPEN',
                pr: { number: 611, headRef: 'pro/kurapika/feat-a', headSha: prHeadSha, baseRef: 'main' },
              }),
              stderr: '',
            };
          },
        );
        assert.equal(reads, 1);
        assert.equal(openRes.exitCode, 0);
        assert.equal(openRes.result.status, 'allow-push');
        assert.equal(openRes.result.pushAllowed, true);
        assert.equal(openRes.result.prState, 'OPEN');
        assert.equal(openRes.result.carryCommits.length, 1);
        assert.equal(openRes.result.carryCommits[0].sha, unpushedSha);
        assert(renderHuman(openRes.result).includes('allow-push (pushAllowed: true)'));

        const mergedRes = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({
            status: 0,
            stdout: JSON.stringify({
              state: 'MERGED',
              pr: { number: 611, headRef: 'pro/kurapika/feat-a', headSha: prHeadSha, baseRef: 'main' },
            }),
            stderr: '',
          }),
        );
        assert.equal(mergedRes.exitCode, 1);
        assert.equal(mergedRes.result.status, 'carry-on-successor-pr');
        assert.equal(mergedRes.result.pushAllowed, false);
        assert.equal(mergedRes.result.prState, 'MERGED');
        assert.equal(mergedRes.result.fallback?.action, 'carry-on-successor-pr');
        assert.equal(mergedRes.result.fallback?.targetBase, 'origin/main');
        assert.equal(mergedRes.result.carryCommits[0].sha, unpushedSha);
        assert(mergedRes.result.fallback?.steps.some((s) => s.includes('--pr <successor-N>')));
        assert(renderHuman(mergedRes.result).includes('carry-on-successor-pr (pushAllowed: false)'));
        // Origin branch still points at prHeadSha (0 commits pushed to merged branch)
        assert.equal(mustGit(work, ['rev-parse', 'origin/pro/kurapika/feat-a']), prHeadSha);

        const closedRes = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({
            status: 0,
            stdout: JSON.stringify({
              state: 'CLOSED',
              pr: { number: 611, headRef: 'pro/kurapika/feat-a', headSha: prHeadSha, baseRef: 'main' },
            }),
            stderr: '',
          }),
        );
        assert.equal(closedRes.exitCode, 1);
        assert.equal(closedRes.result.status, 'carry-on-successor-pr');
        assert.equal(closedRes.result.pushAllowed, false);
        assert.equal(closedRes.result.prState, 'CLOSED');
        // Round 2 F: CLOSED carries only the unpushed commit, anchored on the PR's last pushed head.
        assert.equal(closedRes.exitCode, 1);
        assert.equal(closedRes.result.anchorUsed, prHeadSha);
        assert.deepEqual(closedRes.result.carryCommits.map((c) => c.sha), [unpushedSha]);
        assert(closedRes.result.fallback?.steps.some((s) => s.includes('a conflict is a stop handed back')));
        // Round 2 F: a CLOSED PR with nothing pending (local tip = its last pushed head) -> exit 4
        const closedIdle = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({
            status: 0,
            stdout: JSON.stringify({
              state: 'CLOSED',
              pr: { number: 611, headRef: 'pro/kurapika/feat-a', headSha: unpushedSha, baseRef: 'main' },
            }),
            stderr: '',
          }),
        );
        assert.equal(closedIdle.exitCode, 4);
        assert.equal(closedIdle.result.status, 'nothing-to-carry');
        assert.equal(closedIdle.result.fallback, undefined);

        // R3: head branch mismatch on an OPEN PR is its own exit (3), a stop handed back
        const mismatch = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({
            status: 0,
            stdout: JSON.stringify({
              state: 'OPEN',
              pr: { number: 611, headRef: 'pro/kurapika/other-branch', headSha: prHeadSha, baseRef: 'main' },
            }),
            stderr: '',
          }),
        );
        assert.equal(mismatch.exitCode, 3);
        assert.equal(mismatch.result.status, 'head-branch-mismatch');
        assert.equal(mismatch.result.pushAllowed, false);
        assert.equal(mismatch.result.fallback, undefined);

        // R3: OPEN with a missing or empty headRef is unread (exit 2)
        for (const headRef of [undefined, '', '   ']) {
          const noHead = evaluateEnPushGuard(
            { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
            () => ({
              status: 0,
              stdout: JSON.stringify({ state: 'OPEN', pr: { number: 611, headRef, headSha: prHeadSha } }),
              stderr: '',
            }),
          );
          assert.equal(noHead.exitCode, 2);
          assert.equal(noHead.result.status, 'unread-pr-state');
          assert.equal(noHead.result.pushAllowed, false);
        }
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'HA#611 AC-2: hanten and cleanup ledgers key to the carrying successor PR and refuse predecessor PR',
    run: () => {
      assert.equal(branchToSlug('pro/kurapika/f5-carry'), 'pro-kurapika-f5-carry');
      const ok = resolveCarryingLedgerTarget({
        carryingPr: 620,
        carryingBranch: 'pro/kurapika/f5-carry',
        originalPr: 611,
        code: 'HA',
      });
      assert.equal(ok.exitCode, 0);
      assert.equal(ok.result.status, 'carrying-pr-ledger');
      assert.equal(ok.result.hantenLedgerKey, 'pro-kurapika-f5-carry-pr620');
      assert.equal(ok.result.hantenLedgerPath, '.nen/hanten/pro-kurapika-f5-carry-pr620.cycle.json');
      // Finding 13: the key and path only; hanten § 2b owns opening and recording the ledger.
      assert.equal('hantenLedgerEnsureArgv' in ok.result, false);
      assert.equal('hantenLedgerRecordArgv' in ok.result, false);
      assert.equal(ok.result.cleanupScope, 'for HA#620');
      assert(renderHuman(ok.result).includes('.nen/hanten/pro-kurapika-f5-carry-pr620.cycle.json'));

      // Without --code falls back to branch scope
      const branchScope = resolveCarryingLedgerTarget({
        carryingPr: 620,
        carryingBranch: 'pro/kurapika/f5-carry',
      });
      assert.equal(branchScope.exitCode, 0);
      assert.equal(branchScope.result.cleanupScope, 'for pro/kurapika/f5-carry');

      // Refuses when carrying PR equals predecessor PR
      const same = resolveCarryingLedgerTarget({
        carryingPr: 611,
        carryingBranch: 'pro/kurapika/feat-a',
        originalPr: 611,
      });
      assert.equal(same.exitCode, 1);
      assert.equal(same.result.status, 'predecessor-pr-refused');
      assert(renderHuman(same.result).includes('must differ'));
    },
  },
  {
    name: 'Fail-closed on unread PR state, malformed JSON, unknown state, symlinked repo, detached HEAD, and bad CLI args',
    run: () => {
      const { tmp, work } = setupRepoWithCarryCommits();
      try {
        // Non-zero fetch exit -> exit 2 pushAllowed: false
        const netFail = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({ status: 1, stdout: '', stderr: 'rate limit' }),
        );
        assert.equal(netFail.exitCode, 2);
        assert.equal(netFail.result.status, 'unread-pr-state');
        assert.equal(netFail.result.pushAllowed, false);

        // Reader exception -> exit 2 pushAllowed: false
        const throwFail = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => {
            throw new Error('spawn ENOENT');
          },
        );
        assert.equal(throwFail.exitCode, 2);
        assert.equal(throwFail.result.status, 'unread-pr-state');
        assert.equal(throwFail.result.pushAllowed, false);

        // Malformed JSON -> exit 2
        const badJson = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({ status: 0, stdout: '{bad', stderr: '' }),
        );
        assert.equal(badJson.exitCode, 2);
        assert.equal(badJson.result.status, 'unread-pr-state');

        // Unknown PR state -> exit 2
        const unknownState = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({ status: 0, stdout: JSON.stringify({ state: 'DRAFT' }), stderr: '' }),
        );
        assert.equal(unknownState.exitCode, 2);
        assert.equal(unknownState.result.status, 'unread-pr-state');

        // Symlinked repo refused -> exit 2
        const symRepo = join(tmp, 'sym-work');
        symlinkSync(work, symRepo);
        assert.throws(
          () => evaluateEnPushGuard({ repo: symRepo, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' }),
          (e) => e instanceof EnPushGuardError && e.exitCode === 2,
        );

        // Detached HEAD without --branch -> exit 2
        mustGit(work, ['checkout', '--detach', 'HEAD']);
        assert.throws(
          () => evaluateEnPushGuard({ repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' }),
          (e) => e instanceof EnPushGuardError && e.exitCode === 2,
        );

        // Validation & CLI parser edge cases
        assert.equal(parseCliArgs([]).subcommand, 'help');
        assert.equal(parseCliArgs(['--help']).subcommand, 'help');
        assert.equal(parseCliArgs(['check', '--help']).subcommand, 'help');
        const parsedCheck = parseCliArgs([
          'check',
          '--repo',
          work,
          '--target',
          'zheref/hatsu',
          '--pr',
          '611',
          '--base',
          'main',
          '--json',
        ]);
        assert.equal(parsedCheck.subcommand, 'check');
        assert.throws(() => parseCliArgs(['bogus']), EnPushGuardError);
        assert.throws(() => parseCliArgs(['check', '--repo', work]), EnPushGuardError);
        assert.throws(
          () => parseCliArgs(['check', '--repo', work, '--target', 'bad', '--pr', '0', '--base', 'main']),
          EnPushGuardError,
        );
        assert.throws(
          () => parseCliArgs(['ledger-target', '--carrying-pr', 'abc', '--carrying-branch', 'b']),
          EnPushGuardError,
        );
        assert.throws(
          () => resolveCarryingLedgerTarget({ carryingPr: 10, carryingBranch: 'ok', code: 'bad' }),
          EnPushGuardError,
        );
        assert.equal(sanitizeText('ok\x1b[31mred\x07\x00clean'), 'okred  clean');
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'CLI subprocess exercises real stub nen binary for check (MERGED -> exit 1) and ledger-target (exit 0)',
    run: () => {
      const { tmp, work, prHeadSha } = setupRepoWithCarryCommits();
      try {
        const stubBin = join(tmp, 'nen-stub');
        writeFileSync(
          stubBin,
          `#!/bin/sh
if [ "$1" = "pr" ] && [ "$2" = "fetch" ]; then
  printf '%s\\n' '{"state":"MERGED","pr":{"number":611,"headRef":"pro/kurapika/feat-a","headSha":"${prHeadSha}","baseRef":"main"}}'
  exit 0
fi
exit 2
`,
          'utf8',
        );
        chmodSync(stubBin, 0o755);

        const cliCheck = spawnSync(
          'node',
          [GUARD_SCRIPT, 'check', '--repo', work, '--target', 'zheref/hatsu', '--pr', '611', '--base', 'main', '--nen', stubBin, '--json'],
          { encoding: 'utf8' },
        );
        assert.equal(cliCheck.status, 1, `stderr: ${cliCheck.stderr}`);
        const checkJson = JSON.parse(cliCheck.stdout);
        assert.equal(checkJson.status, 'carry-on-successor-pr');
        assert.equal(checkJson.pushAllowed, false);

        const cliLedger = spawnSync(
          'node',
          [
            GUARD_SCRIPT,
            'ledger-target',
            '--carrying-pr',
            '620',
            '--carrying-branch',
            'pro/kurapika/feat-carry',
            '--original-pr',
            '611',
            '--code',
            'HA',
            '--json',
          ],
          { encoding: 'utf8' },
        );
        assert.equal(cliLedger.status, 0, cliLedger.stderr);
        const ledgerJson = JSON.parse(cliLedger.stdout);
        assert.equal(ledgerJson.hantenLedgerPath, '.nen/hanten/pro-kurapika-feat-carry-pr620.cycle.json');
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'HA#611 finding 11: carry set excludes commits already on origin/<base> and merge commits after the branch merged origin/main post-merge',
    run: () => {
      const { tmp, work, prHeadSha } = setupRepoWithCarryCommits();
      try {
        // The PR merges on origin, main advances, and the local branch merges origin/main back in.
        const other = join(tmp, 'other');
        mustGit(tmp, ['clone', join(tmp, 'origin.git'), other]);
        mustGit(other, ['config', 'user.email', 'test@example.com']);
        mustGit(other, ['config', 'user.name', 'Test User']);
        mustGit(other, ['checkout', 'main']);
        mustGit(other, ['merge', '--no-ff', 'origin/pro/kurapika/feat-a', '-m', 'Merge PR #611']);
        writeFileSync(join(other, 'later.txt'), 'later\n', 'utf8');
        mustGit(other, ['add', 'later.txt']);
        mustGit(other, ['commit', '-m', 'chore: later main commit']);
        const laterMainSha = mustGit(other, ['rev-parse', 'HEAD']);
        mustGit(other, ['push', 'origin', 'main']);
        mustGit(work, ['fetch', 'origin']);
        mustGit(work, ['merge', '--no-edit', 'origin/main']);
        writeFileSync(join(work, 'fix2.txt'), 'second fix\n', 'utf8');
        mustGit(work, ['add', 'fix2.txt']);
        mustGit(work, ['commit', '-m', 'fix: second unpushed follow-up']);
        const secondSha = mustGit(work, ['rev-parse', 'HEAD']);
        const firstSha = mustGit(work, ['rev-parse', 'HEAD~1^1']);

        const merged = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({
            status: 0,
            stdout: JSON.stringify({ state: 'MERGED', pr: { headRef: 'pro/kurapika/feat-a', headSha: prHeadSha } }),
            stderr: '',
          }),
        );
        assert.equal(merged.exitCode, 1);
        const carried = merged.result.carryCommits.map((c) => c.sha);
        assert.deepEqual(carried, [firstSha, secondSha]);
        assert.equal(carried.includes(laterMainSha), false);
        assert(merged.result.carryCommits.every((c) => !c.subject.startsWith('Merge')));
        assert(merged.result.fallback?.steps.some((s) => s.includes('Cherry-pick the 2 unpushed commit(s)')));
        assert(merged.result.fallback?.steps.some((s) => s.includes('hanten § 2b keys its ledger to --pr <successor-N>')));
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'HA#611 finding 12 and R1: nothing to carry (exit 4) is distinct from carry list unread (exit 2)',
    run: () => {
      const { tmp, work, unpushedSha } = setupRepoWithCarryCommits();
      try {
        // Merged at the local tip: nothing unpushed -> en § 6 terminal row, exit 4
        const nothing = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({
            status: 0,
            stdout: JSON.stringify({ state: 'MERGED', pr: { headRef: 'pro/kurapika/feat-a', headSha: unpushedSha } }),
            stderr: '',
          }),
        );
        assert.equal(nothing.exitCode, 4);
        assert.equal(nothing.result.status, 'nothing-to-carry');
        assert.equal(nothing.result.carryListRead, true);
        assert.equal(nothing.result.pushAllowed, false);
        assert.equal(nothing.result.fallback, undefined);
        assert(renderHuman(nothing.result).includes('nothing-to-carry'));

        // MERGED with a headSha this checkout does not hold: no anchor -> unread, exit 2
        const noAnchor = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({
            status: 0,
            stdout: JSON.stringify({ state: 'MERGED', pr: { headRef: 'pro/kurapika/feat-a', headSha: 'a'.repeat(40) } }),
            stderr: '',
          }),
        );
        assert.equal(noAnchor.exitCode, 2);
        assert.equal(noAnchor.result.status, 'unread-carry-list');
        assert.equal(noAnchor.result.carryListRead, false);
        assert(renderHuman(noAnchor.result).includes('carry list: unread'));

        // CLOSED with origin/<base> missing: unread, exit 2
        const noBase = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'gone-base', nen: 'nen' },
          () => ({ status: 0, stdout: JSON.stringify({ state: 'CLOSED', pr: { headRef: 'pro/kurapika/feat-a' } }), stderr: '' }),
        );
        assert.equal(noBase.exitCode, 2);
        assert.equal(noBase.result.status, 'unread-carry-list');

        // MERGED with origin/<base> missing: unread, exit 2
        const mergedNoBase = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'gone-base', nen: 'nen' },
          () => ({
            status: 0,
            stdout: JSON.stringify({ state: 'MERGED', pr: { headRef: 'pro/kurapika/feat-a', headSha: unpushedSha } }),
            stderr: '',
          }),
        );
        assert.equal(mergedNoBase.exitCode, 2);
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'HA#611 SC-2 finding 15: post-push re-read with --require-head routes a merge at another head to the carrying fallback naming the stranded commit',
    run: () => {
      const { tmp, work, prHeadSha, unpushedSha } = setupRepoWithCarryCommits();
      try {
        const base = { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen', requireHead: unpushedSha };
        const reply = (state: string, headSha: string) => () => ({
          status: 0,
          stdout: JSON.stringify({ state, pr: { headRef: 'pro/kurapika/feat-a', headSha } }),
          stderr: '',
        });
        // Merged at the pre-push head: the pushed commit is stranded -> carry, exit 1
        const stranded = evaluateEnPushGuard(base, reply('MERGED', prHeadSha));
        assert.equal(stranded.exitCode, 1);
        assert.equal(stranded.result.requireHead, unpushedSha);
        assert.deepEqual(stranded.result.carryCommits.map((c) => c.sha), [unpushedSha]);
        // Merged at the pushed head: nothing stranded, exit 4
        const landed = evaluateEnPushGuard(base, reply('MERGED', unpushedSha));
        assert.equal(landed.exitCode, 4);
        assert.equal(landed.result.status, 'nothing-to-carry');
        // OPEN, head observed: exit 0; OPEN, head not yet observed: unread, exit 2
        assert.equal(evaluateEnPushGuard(base, reply('OPEN', unpushedSha)).exitCode, 0);
        const lag = evaluateEnPushGuard(base, reply('OPEN', prHeadSha));
        assert.equal(lag.exitCode, 2);
        assert.equal(lag.result.status, 'pushed-head-unobserved');
        // Round 2 G: merged AT the pushed head while HEAD is ahead of it -> exit 1 naming what is past it
        const ahead = evaluateEnPushGuard({ ...base, requireHead: prHeadSha }, reply('MERGED', prHeadSha));
        assert.equal(ahead.exitCode, 1);
        assert.equal(ahead.result.status, 'carry-on-successor-pr');
        assert.deepEqual(ahead.result.carryCommits.map((c) => c.sha), [unpushedSha]);
        assert.throws(
          () => evaluateEnPushGuard({ ...base, requireHead: 'nope' }),
          (e) => e instanceof EnPushGuardError && e.exitCode === 2,
        );
        const parsed = parseCliArgs([
          'check', '--repo', work, '--target', 'zheref/hatsu', '--pr', '611', '--base', 'main', '--require-head', unpushedSha,
        ]);
        assert.equal(parsed.subcommand === 'check' && parsed.opts.requireHead, unpushedSha);
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'Round 3 K: the base-deletion successor carries the child WHOLE unlanded set with --carry-from base (fully pushed, and with one unpushed commit too)',
    run: () => {
      const { tmp, work, prHeadSha, unpushedSha } = setupRepoWithCarryCommits();
      try {
        const closedAt = (headSha: string) => () => ({
          status: 0,
          stdout: JSON.stringify({ state: 'CLOSED', pr: { headRef: 'pro/kurapika/feat-a', headSha, baseRef: 'pro/kurapika/parent' } }),
          stderr: '',
        });
        const base = { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' };
        // Child fully pushed (PR head = local tip): the HEAD-anchored set is empty (exit 4) ...
        assert.equal(evaluateEnPushGuard(base, closedAt(unpushedSha)).exitCode, 4);
        // ... but the base-deletion row's --carry-from base carries every commit not on origin/main.
        const full = evaluateEnPushGuard({ ...base, carryFrom: 'base' }, closedAt(unpushedSha));
        assert.equal(full.exitCode, 1);
        assert.equal(full.result.anchorUsed, 'origin/main');
        assert.deepEqual(full.result.carryCommits.map((c) => c.sha), [prHeadSha, unpushedSha]);
        assert(full.result.fallback?.steps.some((s) => s.includes('2 unlanded commit(s)')));
        // One commit unpushed too: still all of them, never only the unpushed one.
        const mixed = evaluateEnPushGuard({ ...base, carryFrom: 'base' }, closedAt(prHeadSha));
        assert.equal(mixed.exitCode, 1);
        assert.deepEqual(mixed.result.carryCommits.map((c) => c.sha), [prHeadSha, unpushedSha]);
        const headOnly = evaluateEnPushGuard(base, closedAt(prHeadSha));
        assert.deepEqual(headOnly.result.carryCommits.map((c) => c.sha), [unpushedSha]);
        // MERGED keeps the HEAD-anchored set whatever the flag; an unreadable base is unread.
        const merged = evaluateEnPushGuard({ ...base, carryFrom: 'base' }, () => ({
          status: 0,
          stdout: JSON.stringify({ state: 'MERGED', pr: { headRef: 'pro/kurapika/feat-a', headSha: prHeadSha } }),
          stderr: '',
        }));
        assert.equal(merged.result.anchorUsed, prHeadSha);
        assert.deepEqual(merged.result.carryCommits.map((c) => c.sha), [unpushedSha]);
        const noBase = evaluateEnPushGuard({ ...base, base: 'gone-base', carryFrom: 'base' }, closedAt(prHeadSha));
        assert.equal(noBase.exitCode, 2);
        assert.equal(noBase.result.status, 'unread-carry-list');
        const parsed = parseCliArgs([
          'check', '--repo', work, '--target', 'zheref/hatsu', '--pr', '611', '--base', 'main', '--carry-from', 'base',
        ]);
        assert.equal(parsed.subcommand === 'check' && parsed.opts.carryFrom, 'base');
        assert.throws(
          () => parseCliArgs(['check', '--repo', work, '--target', 'zheref/hatsu', '--pr', '1', '--base', 'main', '--carry-from', 'tip']),
          (e) => e instanceof EnPushGuardError && e.exitCode === 2,
        );
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'Round 3 Q (SEC-12): a credentialed URL in nen stderr is redacted in the guard result and its human text',
    run: () => {
      const { tmp, work } = setupRepoWithCarryCommits();
      try {
        const token = 'PLACEHOLDER_TOKEN_0000';
        const res = evaluateEnPushGuard(
          { repo: work, target: 'zheref/hatsu', pr: 611, base: 'main', nen: 'nen' },
          () => ({ status: 1, stdout: '', stderr: `fatal: https://x-access-token:${token}@PART2@github.com/zheref/hatsu.git` }),
        );
        assert.equal(res.exitCode, 2);
        const all = JSON.stringify(res.result) + renderHuman(res.result);
        assert.equal(all.includes(token) || all.includes('PART2') || all.includes('x-access-token'), false);
        assert(all.includes('//<redacted>@github.com'));
        assert.equal(sanitizeText('a%2F%2Fu%3ATOK%40github.com'), 'a%2F%2F<redacted>%40github.com');
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
];
