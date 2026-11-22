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

        // Head branch mismatch refuses push
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
        assert.equal(mismatch.exitCode, 1);
        assert.equal(mismatch.result.status, 'head-branch-mismatch');
        assert.equal(mismatch.result.pushAllowed, false);
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
      assert.deepEqual(ok.result.hantenLedgerEnsureArgv, [
        'review',
        'ledger',
        'ensure',
        '--branch',
        'pro/kurapika/f5-carry',
        '--pr',
        '620',
        '--json',
      ]);
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
];
