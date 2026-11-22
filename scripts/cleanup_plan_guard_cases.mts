// Shared behavior & guard cases for scripts/cleanup_plan_guard.mts (zheref/hatsu#616, #611 AC-3).
// Executed by both scripts/cleanup_plan_guard_fixture.test.mts (Vitest) and
// scripts/cleanup_plan_guard_coverage.test.mts (Node --test --experimental-test-coverage).
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  CleanupPlanGuardError,
  classifyCleanupPlan,
  evaluatePreDelete,
  inspectMergedAhead,
  parseCliArgs,
  renderHuman,
} from './cleanup_plan_guard.mts';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const GUARD_SCRIPT = join(ROOT, 'scripts', 'cleanup_plan_guard.mts');

function mustGit(cwd: string, args: string[]): string {
  const res = spawnSync('git', ['-C', cwd, ...args], { encoding: 'utf8' });
  assert.equal(res.status, 0, `git ${args.join(' ')} failed: ${res.stderr}`);
  return res.stdout.trim();
}

function setupStackFixtureRepo() {
  const tmp = realpathSync(mkdtempSync(join(tmpdir(), 'cleanup-plan-guard-')));
  const bare = join(tmp, 'origin.git');
  const core = join(tmp, 'core');
  const wtHost = join(tmp, 'wt-host');
  mustGit(tmp, ['init', '--bare', bare]);
  mustGit(tmp, ['clone', bare, core]);
  mustGit(core, ['config', 'user.email', 'test@example.com']);
  mustGit(core, ['config', 'user.name', 'Test User']);
  mustGit(core, ['checkout', '-b', 'main']);
  writeFileSync(join(core, 'base.txt'), 'base\n', 'utf8');
  mustGit(core, ['add', 'base.txt']);
  mustGit(core, ['commit', '-m', 'init main']);
  mustGit(core, ['push', '-u', 'origin', 'main']);

  // Lower PR #101 branch stack-a (merged to main, remote head still kept on origin)
  mustGit(core, ['checkout', '-b', 'pro/kurapika/stack-a']);
  writeFileSync(join(core, 'a.txt'), 'stack a\n', 'utf8');
  mustGit(core, ['add', 'a.txt']);
  mustGit(core, ['commit', '-m', 'feat: stack a']);
  const stackAMergedSha = mustGit(core, ['rev-parse', 'HEAD']);
  mustGit(core, ['push', '-u', 'origin', 'pro/kurapika/stack-a']);

  // Merge stack-a into main on origin, keeping refs/heads/pro/kurapika/stack-a alive on origin
  mustGit(core, ['checkout', 'main']);
  mustGit(core, ['merge', '--no-ff', 'pro/kurapika/stack-a', '-m', 'Merge PR #101']);
  mustGit(core, ['push', 'origin', 'main']);

  // Upper PR #102 stacked on pro/kurapika/stack-a
  mustGit(core, ['checkout', '-b', 'pro/kurapika/stack-b', 'pro/kurapika/stack-a']);
  writeFileSync(join(core, 'b.txt'), 'stack b\n', 'utf8');
  mustGit(core, ['add', 'b.txt']);
  mustGit(core, ['commit', '-m', 'feat: stack b']);
  mustGit(core, ['push', '-u', 'origin', 'pro/kurapika/stack-b']);

  // Unrelated non-base merged branch late-base (initially safe, later retargeted in AC-3 test)
  mustGit(core, ['checkout', 'main']);
  mustGit(core, ['checkout', '-b', 'pro/kurapika/late-base']);
  writeFileSync(join(core, 'late.txt'), 'late\n', 'utf8');
  mustGit(core, ['add', 'late.txt']);
  mustGit(core, ['commit', '-m', 'feat: late base']);
  const lateSha = mustGit(core, ['rev-parse', 'HEAD']);
  mustGit(core, ['push', '-u', 'origin', 'pro/kurapika/late-base']);
  mustGit(core, ['checkout', 'main']);
  mustGit(core, ['merge', '--no-ff', 'pro/kurapika/late-base', '-m', 'Merge PR #204']);
  mustGit(core, ['push', 'origin', 'main']);

  // Host worktree
  mustGit(core, ['worktree', 'add', wtHost, 'pro/kurapika/stack-b']);

  return { tmp, bare, core, wtHost, stackAMergedSha, lateSha };
}

export interface CleanupPlanCase {
  readonly name: string;
  readonly run: () => void | Promise<void>;
}

export const cleanupPlanGuardCases: CleanupPlanCase[] = [
  {
    name: 'HA#616 AC-1, AC-2, AC-4, SC-1, SC-2: 2-PR stack marks base-of-open-PR remote/local/worktree as named, preserves non-base classes, and 100% of remote heads record open-PR base',
    run: () => {
      const { tmp, core, wtHost, stackAMergedSha, lateSha } = setupStackFixtureRepo();
      try {
        const openPrs = [
          { number: 102, baseRefName: 'pro/kurapika/stack-a', headRefName: 'pro/kurapika/stack-b' },
        ];
        const plan = classifyCleanupPlan({
          openPrs,
          candidates: [
            // Stacked lower PR #101: remote head, local branch, clean worktree -> ALL named!
            {
              kind: 'remote-head',
              branch: 'pro/kurapika/stack-a',
              object: 'origin/pro/kurapika/stack-a',
              host: wtHost,
              prNumber: 101,
              prState: 'MERGED',
              tipSha: stackAMergedSha,
              mergedHeadSha: stackAMergedSha,
              owner: 'this sitting',
            },
            {
              kind: 'local-branch',
              branch: 'pro/kurapika/stack-a',
              object: 'pro/kurapika/stack-a',
              core,
              prNumber: 101,
              prState: 'MERGED',
              owner: 'this sitting',
            },
            {
              kind: 'worktree',
              branch: 'pro/kurapika/stack-a',
              object: `${core}/.nen/worktrees/antigravity/stack-a`,
              worktreePath: `${core}/.nen/worktrees/antigravity/stack-a`,
              core,
              worktreeKind: 'effort',
              treeState: 'clean',
              prNumber: 101,
              prState: 'MERGED',
              owner: 'this sitting',
            },
            // Non-base rows preserve AC-4 classes:
            {
              kind: 'remote-head',
              branch: 'pro/kurapika/late-base',
              object: 'origin/pro/kurapika/late-base',
              host: wtHost,
              prNumber: 204,
              prState: 'MERGED',
              tipSha: lateSha,
              mergedHeadSha: lateSha,
              owner: 'this sitting',
            },
            {
              kind: 'worktree',
              branch: 'pro/kurapika/late-base',
              object: `${core}/.nen/worktrees/antigravity/late-base`,
              worktreePath: `${core}/.nen/worktrees/antigravity/late-base`,
              core,
              worktreeKind: 'effort',
              treeState: 'clean',
              prNumber: 204,
              prState: 'MERGED',
              owner: 'this sitting',
            },
            {
              kind: 'local-branch',
              branch: 'pro/kurapika/late-base',
              object: 'pro/kurapika/late-base',
              core,
              prNumber: 204,
              prState: 'MERGED',
              owner: 'this sitting',
            },
            {
              kind: 'remote-head',
              branch: 'pro/kurapika/closed-one',
              object: 'origin/pro/kurapika/closed-one',
              host: wtHost,
              prNumber: 205,
              prState: 'CLOSED',
              tipSha: lateSha,
              owner: 'prior: pro/kurapika/closed-one',
            },
            {
              kind: 'remote-head',
              branch: 'pro/kurapika/stack-b',
              object: 'origin/pro/kurapika/stack-b',
              host: wtHost,
              prNumber: 102,
              prState: 'OPEN',
              tipSha: lateSha,
              owner: 'this sitting',
            },
            {
              kind: 'worktree',
              branch: 'pro/kurapika/reviewer-check',
              object: `${core}/.nen/worktrees/antigravity/hanten-nobunaga`,
              worktreePath: `${core}/.nen/worktrees/antigravity/hanten-nobunaga`,
              core,
              worktreeKind: 'reviewer',
              reviewerLedgerRan: true,
              treeState: 'clean',
              prState: 'NONE',
              owner: 'this sitting',
            },
          ],
        });

        const [rRemoteA, rLocalA, rWtA, rRemoteLate, rWtLate, rLocalLate, rRemoteClosed, rRemoteB, rWtReviewer] = plan.rows;
        // AC-1 & AC-2: stacked lower branch is named on remote-head, local-branch, AND clean worktree!
        assert.equal(rRemoteA.class, 'named');
        assert.equal(rRemoteA.exactCommand, null);
        assert(rRemoteA.evidence.includes('base of open PR: #102'));
        assert.equal(rLocalA.class, 'named');
        assert.equal(rLocalA.exactCommand, null);
        assert(rLocalA.evidence.includes('base of open PR: #102'));
        assert.equal(rWtA.class, 'named');
        assert.equal(rWtA.exactCommand, null);
        assert(rWtA.evidence.includes('base of open PR: #102'));

        // AC-4: non-base rows retain existing classes
        assert.equal(rRemoteLate.class, 'deterministic');
        assert(rRemoteLate.exactCommand?.includes("push origin --delete -- 'pro/kurapika/late-base'"));
        assert.equal(rWtLate.class, 'deterministic');
        assert.equal(rLocalLate.class, 'proposed');
        assert.equal(rRemoteClosed.class, 'proposed');
        assert.equal(rRemoteB.class, 'named');
        assert.equal(rWtReviewer.class, 'deterministic');

        // SC-1: 0 remote delete commands target any open-PR base
        const openBases = new Set(openPrs.map((p) => p.baseRefName));
        const deletesTargetingOpenBase = plan.rows.filter(
          (r) => r.kind === 'remote-head' && openBases.has(r.branch) && r.exactCommand !== null,
        );
        assert.equal(deletesTargetingOpenBase.length, 0);

        // SC-2: 100% of remote-head rows carry base of open PR status in evidence
        const remoteRows = plan.rows.filter((r) => r.kind === 'remote-head');
        assert.equal(remoteRows.length, 4);
        assert(remoteRows.every((r) => /base of open PR: (#\d+|none)/.test(r.evidence)));
        assert(renderHuman(plan).includes('cleanup-plan-guard: 9 row(s)'));
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'HA#616 AC-3: mid-run open PR retarget onto remote branch blocks delete at pass 2, reports why, and preserves remote ref; fail-closed on unread gh / SHA drift',
    run: () => {
      const { tmp, core, wtHost, lateSha } = setupStackFixtureRepo();
      try {
        // Happy pre-delete when no open PR targets late-base -> exit 0
        const okPre = evaluatePreDelete(
          {
            repo: wtHost,
            target: 'zheref/hatsu',
            branch: 'pro/kurapika/late-base',
            expectedSha: lateSha,
          },
          () => ({ status: 0, stdout: JSON.stringify([{ number: 102, baseRefName: 'pro/kurapika/stack-a' }]), stderr: '' }),
        );
        assert.equal(okPre.exitCode, 0);
        assert.equal(okPre.result.deleteAllowed, true);
        assert.equal(okPre.result.status, 'allow-delete');
        assert(renderHuman(okPre.result).includes('allow-delete (deleteAllowed: true)'));

        // Race: open PR #205 is retargeted onto pro/kurapika/late-base before picked delete runs -> exit 1!
        const blockedPre = evaluatePreDelete(
          {
            repo: wtHost,
            target: 'zheref/hatsu',
            branch: 'pro/kurapika/late-base',
            expectedSha: lateSha,
          },
          () => ({
            status: 0,
            stdout: JSON.stringify([
              { number: 102, baseRefName: 'pro/kurapika/stack-a' },
              { number: 205, baseRefName: 'pro/kurapika/late-base' },
            ]),
            stderr: '',
          }),
        );
        assert.equal(blockedPre.exitCode, 1);
        assert.equal(blockedPre.result.deleteAllowed, false);
        assert.equal(blockedPre.result.status, 'refused-open-pr-base');
        assert.deepEqual(blockedPre.result.openBasePrs, [205]);
        assert(blockedPre.result.reason.includes('#205'));
        assert(renderHuman(blockedPre.result).includes('refused-open-pr-base'));
        // Remote branch still exists intact in real bare origin!
        const lsAfter = mustGit(core, ['ls-remote', '--heads', 'origin', 'refs/heads/pro/kurapika/late-base']);
        assert(lsAfter.startsWith(lateSha));

        // SHA drift on origin refuses delete -> exit 1
        const fakeOldSha = '0'.repeat(40);
        const shaMismatch = evaluatePreDelete(
          {
            repo: wtHost,
            target: 'zheref/hatsu',
            branch: 'pro/kurapika/late-base',
            expectedSha: fakeOldSha,
          },
          () => ({ status: 0, stdout: '[]', stderr: '' }),
        );
        assert.equal(shaMismatch.exitCode, 1);
        assert.equal(shaMismatch.result.status, 'refused-sha-mismatch');
        assert.equal(shaMismatch.result.deleteAllowed, false);

        // Unreadable gh open-PR list fails closed -> exit 2
        const ghErr = evaluatePreDelete(
          {
            repo: wtHost,
            target: 'zheref/hatsu',
            branch: 'pro/kurapika/late-base',
            expectedSha: lateSha,
          },
          () => ({ status: 1, stdout: '', stderr: 'auth timeout' }),
        );
        assert.equal(ghErr.exitCode, 2);
        assert.equal(ghErr.result.status, 'unread-open-prs');
        assert.equal(ghErr.result.deleteAllowed, false);

        const ghMalformed = evaluatePreDelete(
          {
            repo: wtHost,
            target: 'zheref/hatsu',
            branch: 'pro/kurapika/late-base',
            expectedSha: lateSha,
          },
          () => ({ status: 0, stdout: '{not-array', stderr: '' }),
        );
        assert.equal(ghMalformed.exitCode, 2);
        assert.equal(ghMalformed.result.status, 'unread-open-prs');
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'HA#611 AC-3: merged branch tip ahead of headRefOid refuses deterministic delete and names extra commits + where they landed (on origin/main, in successor PR, or unlanded)',
    run: () => {
      const tmp = realpathSync(mkdtempSync(join(tmpdir(), 'cleanup-ahead-')));
      const bare = join(tmp, 'origin.git');
      const repo = join(tmp, 'repo');
      try {
        mustGit(tmp, ['init', '--bare', bare]);
        mustGit(tmp, ['clone', bare, repo]);
        mustGit(repo, ['config', 'user.email', 'test@example.com']);
        mustGit(repo, ['config', 'user.name', 'Test User']);
        mustGit(repo, ['checkout', '-b', 'main']);
        writeFileSync(join(repo, 'README.md'), 'init\n', 'utf8');
        mustGit(repo, ['add', 'README.md']);
        mustGit(repo, ['commit', '-m', 'init']);
        mustGit(repo, ['push', '-u', 'origin', 'main']);

        mustGit(repo, ['checkout', '-b', 'pro/kurapika/pr-merged']);
        writeFileSync(join(repo, 'work.txt'), 'merged pr part\n', 'utf8');
        mustGit(repo, ['add', 'work.txt']);
        mustGit(repo, ['commit', '-m', 'feat: original merged commit']);
        const mergedHeadSha = mustGit(repo, ['rev-parse', 'HEAD']);

        // Extra commit 1: carried on successor PR #620
        writeFileSync(join(repo, 'carry.txt'), 'carry commit\n', 'utf8');
        mustGit(repo, ['add', 'carry.txt']);
        mustGit(repo, ['commit', '-m', 'fix: post-merge follow-up carried']);
        const extraCarriedSha = mustGit(repo, ['rev-parse', 'HEAD']);

        // Extra commit 2: directlycherry-picked onto origin/main
        writeFileSync(join(repo, 'landed.txt'), 'landed elsewhere\n', 'utf8');
        mustGit(repo, ['add', 'landed.txt']);
        mustGit(repo, ['commit', '-m', 'chore: landed on main']);
        const extraMainSha = mustGit(repo, ['rev-parse', 'HEAD']);

        // Extra commit 3: unlanded anywhere
        writeFileSync(join(repo, 'orphan.txt'), 'orphan edit\n', 'utf8');
        mustGit(repo, ['add', 'orphan.txt']);
        mustGit(repo, ['commit', '-m', 'wip: unlanded follow-up']);
        const branchTipSha = mustGit(repo, ['rev-parse', 'HEAD']);

        // Create successor PR #620 head containing extraCarriedSha (cherry-pick)
        mustGit(repo, ['checkout', '-b', 'pro/kurapika/successor-620', 'main']);
        mustGit(repo, ['cherry-pick', extraCarriedSha]);
        const succ620HeadSha = mustGit(repo, ['rev-parse', 'HEAD']);

        // Cherry-pick extraMainSha onto origin/main
        mustGit(repo, ['checkout', 'main']);
        mustGit(repo, ['cherry-pick', extraMainSha]);
        mustGit(repo, ['push', 'origin', 'main']);

        const plan = classifyCleanupPlan({
          openPrs: [],
          repo,
          base: 'main',
          prs: [{ number: 620, state: 'OPEN', headRefOid: succ620HeadSha, headRefName: 'pro/kurapika/successor-620' }],
          candidates: [
            {
              kind: 'remote-head',
              branch: 'pro/kurapika/pr-merged',
              object: 'origin/pro/kurapika/pr-merged',
              host: repo,
              prNumber: 579,
              prState: 'MERGED',
              tipSha: branchTipSha,
              mergedHeadSha,
              owner: 'prior: pro/kurapika/pr-merged',
            },
          ],
        });

        assert.equal(plan.rows.length, 1);
        const row = plan.rows[0];
        assert.equal(row.class, 'proposed');
        assert.equal(row.extraCommits.length, 3);
        assert(row.evidence.includes(extraCarriedSha.slice(0, 8)));
        assert(row.evidence.includes('PR #620 (OPEN'));
        assert(row.evidence.includes(extraMainSha.slice(0, 8)));
        assert(row.evidence.includes('on origin/main'));
        assert(row.evidence.includes(branchTipSha.slice(0, 8)));
        assert(row.evidence.includes('unlanded'));
        assert(/base of open PR: none/.test(row.evidence));

        const aheadDirect = inspectMergedAhead({
          repo,
          branchSha: branchTipSha,
          mergedHeadSha,
          base: 'main',
          prs: [{ number: 620, state: 'OPEN', headRefOid: succ620HeadSha }],
        });
        assert.equal(aheadDirect.aheadCount, 3);
        assert(renderHuman(aheadDirect).includes('3 extra commit(s)'));

        const prsJson = join(tmp, 'prs.json');
        writeFileSync(prsJson, JSON.stringify([{ number: 620, state: 'OPEN', headRefOid: succ620HeadSha }]), 'utf8');
        const cliAhead = spawnSync(
          'node',
          [
            GUARD_SCRIPT,
            'merged-ahead',
            '--repo',
            repo,
            '--branch-sha',
            branchTipSha,
            '--merged-sha',
            mergedHeadSha,
            '--base',
            'main',
            '--prs-json',
            prsJson,
            '--json',
          ],
          { encoding: 'utf8' },
        );
        assert.equal(cliAhead.status, 0, cliAhead.stderr);
        const aheadJson = JSON.parse(cliAhead.stdout);
        assert.equal(aheadJson.aheadCount, 3);
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'CLI subprocess + validation edge cases (classify, pre-delete, merged-ahead, symlinks, invalid flags)',
    run: () => {
      const { tmp, wtHost, lateSha } = setupStackFixtureRepo();
      try {
        const stubGh = join(tmp, 'gh-stub');
        writeFileSync(
          stubGh,
          `#!/bin/sh
printf '%s\\n' '[{"number":300,"baseRefName":"pro/kurapika/late-base","headRefName":"pro/kurapika/child"}]'
`,
          'utf8',
        );
        chmodSync(stubGh, 0o755);

        const cliPre = spawnSync(
          'node',
          [
            GUARD_SCRIPT,
            'pre-delete',
            '--repo',
            wtHost,
            '--target',
            'zheref/hatsu',
            '--branch',
            'pro/kurapika/late-base',
            '--expected-sha',
            lateSha,
            '--gh',
            stubGh,
            '--json',
          ],
          { encoding: 'utf8' },
        );
        assert.equal(cliPre.status, 1, `stderr: ${cliPre.stderr}`);
        const preJson = JSON.parse(cliPre.stderr);
        assert.equal(preJson.status, 'refused-open-pr-base');
        assert.equal(preJson.deleteAllowed, false);
        assert.deepEqual(preJson.openBasePrs, [300]);

        const inputJson = join(tmp, 'plan-in.json');
        writeFileSync(
          inputJson,
          JSON.stringify({
            openPrs: [{ number: 300, baseRefName: 'pro/kurapika/late-base' }],
            candidates: [
              {
                kind: 'remote-head',
                branch: 'pro/kurapika/late-base',
                object: 'origin/pro/kurapika/late-base',
                host: wtHost,
                prNumber: 204,
                prState: 'MERGED',
                tipSha: lateSha,
                mergedHeadSha: lateSha,
                owner: 'this sitting',
              },
            ],
          }),
          'utf8',
        );
        const cliClassify = spawnSync('node', [GUARD_SCRIPT, 'classify', '--input', inputJson, '--json'], {
          encoding: 'utf8',
        });
        assert.equal(cliClassify.status, 0, cliClassify.stderr);
        const classJson = JSON.parse(cliClassify.stdout);
        assert.equal(classJson.rows[0].class, 'named');
        assert.equal(classJson.rows[0].exactCommand, null);

        // Parser & validation errors exit 2
        assert.equal(parseCliArgs([]).subcommand, 'help');
        assert.equal(parseCliArgs(['classify', '--help']).subcommand, 'help');
        assert.throws(() => parseCliArgs(['bogus']), CleanupPlanGuardError);
        assert.throws(() => parseCliArgs(['classify']), CleanupPlanGuardError);
        assert.throws(() => parseCliArgs(['pre-delete', '--repo', wtHost]), CleanupPlanGuardError);
        assert.throws(() => parseCliArgs(['merged-ahead', '--repo', wtHost]), CleanupPlanGuardError);
        assert.throws(
          () =>
            evaluatePreDelete({
              repo: wtHost,
              target: 'zheref/hatsu',
              branch: 'main',
              expectedSha: lateSha,
            }),
          CleanupPlanGuardError,
        );
        const sym = join(tmp, 'sym-wt');
        symlinkSync(wtHost, sym);
        assert.throws(
          () =>
            evaluatePreDelete({
              repo: sym,
              target: 'zheref/hatsu',
              branch: 'pro/kurapika/late-base',
              expectedSha: lateSha,
            }),
          CleanupPlanGuardError,
        );
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    },
  },
];
