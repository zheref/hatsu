#!/usr/bin/env node
// cleanup_plan_guard.mts — hatsu:cleanup §§ 4–6 plan classifier, open-PR-base guard,
// merged-ahead extra-commit evidence, and pre-delete live re-read (zheref/hatsu#616, #611 AC-3).
//
// Rules enforced:
//   1. Batched open-PR base read (`gh pr list --repo <owner/name> --state open --json
//      number,baseRefName,headRefName --limit 1000`, one call per pass).
//   2. Named facts outrank cleanup § 5's table and reviewer-ledger rule across remote heads,
//      local branches, and worktrees: `locked yes`, open PR, **`base of open PR`**,
//      `tree unreadable`, refused name, and `no admitted checkout` are classed `named`
//      (`command: null`, never deterministic, never offered for deletion).
//   3. 100% of `remote-head` rows record `base of open PR: #<N>[, ...]` or
//      `base of open PR: none` in their evidence.
//   4. Non-base branches preserve existing § 5 classes identically.
//   5. Merged branches whose tip is ahead of `headRefOid` are never `deterministic` and name
//      each extra commit and where it landed (`on origin/<base>`, `in PR #<N> (<state>)`, or
//      `unlanded`).
//   6. Right before any `push origin --delete`, `pre-delete` live-re-reads open PR bases and
//      remote SHA, refusing exit 1 (0 deletes run) if an open PR was retargeted onto the
//      branch or SHA drifted, and failing closed exit 2 if any read fails.
//
// Usage:
//   node scripts/cleanup_plan_guard.mts classify --input <json> [--repo <path>] [--base <branch.base>] [--json]
//   node scripts/cleanup_plan_guard.mts pre-delete --repo <host-wt> --target <owner/name> --branch <branch> --expected-sha <sha> [--base <trunk>] [--gh <bin>] [--json]
//   node scripts/cleanup_plan_guard.mts merged-ahead --repo <path> --branch-sha <sha> --merged-sha <sha> --base <branch.base> [--prs-json <file>] [--json]
//
// Exit codes:
//   0  classify succeeded; pre-delete allowed (not open PR base + exact remote SHA match); merged-ahead inspected
//   1  pre-delete refused (`refused-open-pr-base` or `refused-sha-mismatch`, delete must NOT run)
//   2  usage/validation error, symlinked/non-git repo, or unreadable open-PR / remote-SHA / input state
import { spawnSync } from 'node:child_process';
import { existsSync, lstatSync, readFileSync, realpathSync } from 'node:fs';
import { resolve } from 'node:path';

const SCRUB_GIT_ENV = [
  'GIT_DIR',
  'GIT_WORK_TREE',
  'GIT_COMMON_DIR',
  'GIT_INDEX_FILE',
  'GIT_OBJECT_DIRECTORY',
  'GIT_NAMESPACE',
  'GIT_PREFIX',
] as const;

const SLUG_RE = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
const SHA_RE = /^[0-9a-f]{40}$/i;

export type CleanupClass = 'deterministic' | 'proposed' | 'named';
export type ObjectKind = 'worktree' | 'local-branch' | 'remote-head';
export type PrRowState = 'MERGED' | 'CLOSED' | 'OPEN' | 'NONE';

export interface OpenPrSummary {
  readonly number: number;
  readonly baseRefName: string;
  readonly headRefName?: string;
}

export interface PrCandidateRef {
  readonly number: number;
  readonly state: 'OPEN' | 'MERGED' | 'CLOSED';
  readonly headRefOid?: string;
  readonly headRefName?: string;
}

export interface ExtraCommitInfo {
  readonly sha: string;
  readonly subject: string;
  readonly landed: string;
}

export interface CleanupPlanCandidate {
  readonly kind: ObjectKind;
  readonly branch: string;
  readonly object: string;
  readonly core?: string;
  readonly host?: string;
  readonly worktreePath?: string;
  readonly worktreeKind?: 'effort' | 'reviewer';
  readonly reviewerLedgerRan?: boolean;
  readonly prNumber?: number | null;
  readonly prState: PrRowState;
  readonly tipSha?: string;
  readonly mergedHeadSha?: string;
  readonly locked?: boolean;
  readonly lockedReason?: string;
  readonly treeState?: 'clean' | 'dirty' | 'unreadable';
  readonly dirtyPaths?: readonly string[];
  readonly admitted?: boolean;
  readonly refusedReason?: string;
  readonly hostMissing?: boolean;
  readonly trunk?: string;
  readonly freesBytes?: number;
  readonly owner: string;
  readonly extraCommits?: readonly ExtraCommitInfo[];
}

export interface ClassifiedPlanRow {
  readonly id: string;
  readonly class: CleanupClass;
  readonly kind: ObjectKind;
  readonly object: string;
  readonly branch: string;
  readonly exactCommand: string | null;
  readonly freesBytes: number;
  readonly evidence: string;
  readonly owner: string;
  readonly namedFacts: readonly string[];
  readonly openBasePrs: readonly number[];
  readonly extraCommits: readonly ExtraCommitInfo[];
}

export interface ClassifyResult {
  readonly contract: 'hatsu.cleanup-plan-guard/v0.1';
  readonly command: 'classify';
  readonly rows: readonly ClassifiedPlanRow[];
  readonly counts: { readonly deterministic: number; readonly proposed: number; readonly named: number };
}

export interface PreDeleteResult {
  readonly contract: 'hatsu.cleanup-plan-guard/v0.1';
  readonly command: 'pre-delete';
  readonly status: 'allow-delete' | 'refused-open-pr-base' | 'refused-sha-mismatch' | 'unread-open-prs' | 'unread-remote-sha';
  readonly deleteAllowed: boolean;
  readonly repo: string;
  readonly target: string;
  readonly branch: string;
  readonly expectedSha: string;
  readonly remoteSha: string | null;
  readonly openBasePrs: readonly number[];
  readonly reason: string;
}

export interface MergedAheadResult {
  readonly contract: 'hatsu.cleanup-plan-guard/v0.1';
  readonly command: 'merged-ahead';
  readonly repo: string;
  readonly branchSha: string;
  readonly mergedHeadSha: string;
  readonly aheadCount: number;
  readonly extraCommits: readonly ExtraCommitInfo[];
  readonly summary: string;
}

export interface GhRunOutput {
  readonly status: number;
  readonly stdout: string;
  readonly stderr: string;
}

export type FetchOpenPrsFn = (ghBin: string, target: string) => GhRunOutput;

export class CleanupPlanGuardError extends Error {
  readonly exitCode: number;
  constructor(exitCode: number, message: string) {
    super(message);
    this.exitCode = exitCode;
  }
}

export function sanitizeText(value: string): string {
  return value
    .replace(/\x1b\[[0-9;?]*[ -/]*[@-~]/g, '')
    .replace(/\x1b\][^\x07]*(?:\x07|\x1b\\)/g, '')
    .replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff]/g, ' ')
    .trim();
}

function cleanGitEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = { ...process.env, GIT_OPTIONAL_LOCKS: '0' };
  for (const key of SCRUB_GIT_ENV) delete env[key];
  return env;
}

function runGit(repo: string, args: string[]): { status: number; stdout: string; stderr: string } {
  const res = spawnSync('git', ['-C', repo, ...args], { env: cleanGitEnv(), encoding: 'utf8' });
  if (res.error) return { status: 2, stdout: '', stderr: res.error.message };
  return { status: res.status ?? 1, stdout: res.stdout ?? '', stderr: res.stderr ?? '' };
}

function isValidBranchName(name: string): boolean {
  if (!name || name.startsWith('-') || name.startsWith('refs/') || name.includes('@{') || name.includes('..')) {
    return false;
  }
  if (/[\s\x00-\x1f\x7f~^:?*[\]\\]/.test(name)) return false;
  const check = spawnSync('git', ['check-ref-format', '--branch', name], { env: cleanGitEnv(), encoding: 'utf8' });
  return check.status === 0;
}

function resolveCanonicalRepo(repoArg: string): string {
  const abs = resolve(repoArg);
  if (!existsSync(abs)) {
    throw new CleanupPlanGuardError(2, `repository path does not exist: ${sanitizeText(abs)}`);
  }
  const st = lstatSync(abs);
  if (st.isSymbolicLink() || !st.isDirectory()) {
    throw new CleanupPlanGuardError(2, `repository path must be a real non-symlink directory: ${sanitizeText(abs)}`);
  }
  const real = realpathSync.native(abs);
  if (real !== abs) {
    throw new CleanupPlanGuardError(2, `repository path must be canonical without symlink segments: ${sanitizeText(abs)}`);
  }
  const top = runGit(real, ['rev-parse', '--show-toplevel']);
  if (top.status !== 0 || top.stdout.trim() !== real) {
    throw new CleanupPlanGuardError(2, `path is not a git worktree root: ${sanitizeText(real)}`);
  }
  return real;
}

export function defaultFetchOpenPrs(ghBin: string, target: string): GhRunOutput {
  const res = spawnSync(
    ghBin,
    ['pr', 'list', '--repo', target, '--state', 'open', '--json', 'number,baseRefName,headRefName', '--limit', '1000'],
    { encoding: 'utf8' },
  );
  if (res.error) {
    return { status: 2, stdout: '', stderr: res.error.message };
  }
  return { status: res.status ?? 1, stdout: res.stdout ?? '', stderr: res.stderr ?? '' };
}

export function indexOpenPrBases(openPrs: readonly OpenPrSummary[]): Map<string, number[]> {
  const byBase = new Map<string, number[]>();
  for (const pr of openPrs) {
    if (!Number.isSafeInteger(pr.number) || pr.number <= 0 || typeof pr.baseRefName !== 'string' || !pr.baseRefName) {
      throw new CleanupPlanGuardError(2, 'open PR list entry must carry positive number and non-empty baseRefName');
    }
    const existing = byBase.get(pr.baseRefName) ?? [];
    if (!existing.includes(pr.number)) {
      existing.push(pr.number);
      existing.sort((a, b) => a - b);
      byBase.set(pr.baseRefName, existing);
    }
  }
  return byBase;
}

export function formatOpenBaseEvidence(openBasePrs: readonly number[]): string {
  if (openBasePrs.length === 0) return 'base of open PR: none';
  return `base of open PR: ${openBasePrs.map((n) => `#${n}`).join(', ')}`;
}

function shellQuoteSingle(value: string): string {
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

function isPatchEquivalentInRef(repo: string, targetRef: string, commitSha: string): boolean {
  const hasParent = runGit(repo, ['rev-parse', '--verify', '--quiet', `${commitSha}^`]);
  const args = hasParent.status === 0
    ? ['cherry', targetRef, commitSha, `${commitSha}^`]
    : ['cherry', targetRef, commitSha];
  const res = runGit(repo, args);
  if (res.status !== 0) return false;
  return res.stdout
    .split('\n')
    .some((line) => line.trim() === `- ${commitSha}`);
}

function classifyLandedCommit(
  repo: string,
  commitSha: string,
  baseBranch: string,
  prs: readonly PrCandidateRef[],
): string {
  for (const pr of prs) {
    if (pr.headRefOid && SHA_RE.test(pr.headRefOid)) {
      const anc = runGit(repo, ['merge-base', '--is-ancestor', commitSha, pr.headRefOid]);
      if (anc.status === 0) {
        return `in PR #${pr.number} (${pr.state})`;
      }
      if (isPatchEquivalentInRef(repo, pr.headRefOid, commitSha)) {
        return `in PR #${pr.number} (${pr.state}, cherry-picked)`;
      }
    }
  }

  const baseRef = `refs/remotes/origin/${baseBranch}`;
  const hasBase = runGit(repo, ['rev-parse', '--verify', '--quiet', `${baseRef}^{commit}`]);
  if (hasBase.status === 0) {
    const ancBase = runGit(repo, ['merge-base', '--is-ancestor', commitSha, baseRef]);
    if (ancBase.status === 0) return `on origin/${baseBranch}`;
    if (isPatchEquivalentInRef(repo, baseRef, commitSha)) {
      return `on origin/${baseBranch} (patch-equivalent)`;
    }
  }
  return `unlanded (not on origin/${baseBranch})`;
}

export function inspectMergedAhead(opts: {
  readonly repo: string;
  readonly branchSha: string;
  readonly mergedHeadSha: string;
  readonly base: string;
  readonly prs?: readonly PrCandidateRef[];
}): MergedAheadResult {
  if (!SHA_RE.test(opts.branchSha)) {
    throw new CleanupPlanGuardError(2, `--branch-sha must be a 40-char hex SHA`);
  }
  if (!SHA_RE.test(opts.mergedHeadSha)) {
    throw new CleanupPlanGuardError(2, `--merged-sha must be a 40-char hex SHA`);
  }
  if (!isValidBranchName(opts.base)) {
    throw new CleanupPlanGuardError(2, `--base is not a valid branch name`);
  }
  const repo = resolveCanonicalRepo(opts.repo);
  const log = runGit(repo, ['log', '--reverse', '--format=%H%x09%s', `${opts.mergedHeadSha}..${opts.branchSha}`]);
  if (log.status !== 0) {
    throw new CleanupPlanGuardError(2, `could not read commit range ${opts.mergedHeadSha}..${opts.branchSha}: ${sanitizeText(log.stderr)}`);
  }

  const prs = opts.prs ?? [];
  const extraCommits: ExtraCommitInfo[] = [];
  for (const line of log.stdout.split('\n')) {
    if (!line.trim()) continue;
    const tab = line.indexOf('\t');
    if (tab <= 0) continue;
    const sha = sanitizeText(line.slice(0, tab));
    const subject = sanitizeText(line.slice(tab + 1));
    const landed = classifyLandedCommit(repo, sha, opts.base, prs);
    extraCommits.push({ sha, subject, landed });
  }

  const summary =
    extraCommits.length === 0
      ? `no extra commit ahead of merged head ${opts.mergedHeadSha.slice(0, 8)}`
      : `merged ahead of ${opts.mergedHeadSha.slice(0, 8)}: ${extraCommits
          .map((c) => `${c.sha.slice(0, 8)} ("${c.subject}") -> ${c.landed}`)
          .join('; ')}`;

  return {
    contract: 'hatsu.cleanup-plan-guard/v0.1',
    command: 'merged-ahead',
    repo,
    branchSha: opts.branchSha,
    mergedHeadSha: opts.mergedHeadSha,
    aheadCount: extraCommits.length,
    extraCommits,
    summary,
  };
}

export function classifyCleanupPlan(opts: {
  readonly openPrs: readonly OpenPrSummary[];
  readonly candidates: readonly CleanupPlanCandidate[];
  readonly repo?: string;
  readonly base?: string;
  readonly prs?: readonly PrCandidateRef[];
}): ClassifyResult {
  const openBaseMap = indexOpenPrBases(opts.openPrs);
  const repo = opts.repo ? resolveCanonicalRepo(opts.repo) : undefined;
  const baseBranch = opts.base ?? 'main';
  const prs = opts.prs ?? [];

  const rows: ClassifiedPlanRow[] = [];
  let counts = { deterministic: 0, proposed: 0, named: 0 };

  opts.candidates.forEach((cand, idx) => {
    const num = idx + 1;
    const openBasePrs = openBaseMap.get(cand.branch) ?? [];
    const namedFacts: string[] = [];

    if (cand.trunk && cand.branch === cand.trunk) namedFacts.push(`trunk ${cand.trunk}`);
    if (cand.locked) namedFacts.push(cand.lockedReason ? `locked yes: ${sanitizeText(cand.lockedReason)}` : 'locked yes');
    if (cand.prState === 'OPEN') namedFacts.push(cand.prNumber ? `open PR #${cand.prNumber}` : 'open PR');
    if (openBasePrs.length > 0) namedFacts.push(formatOpenBaseEvidence(openBasePrs));
    if (cand.treeState === 'unreadable') namedFacts.push('tree unreadable');
    if (cand.admitted === false) namedFacts.push(cand.refusedReason ? sanitizeText(cand.refusedReason) : 'refused name');
    if (cand.kind === 'remote-head' && cand.hostMissing) namedFacts.push('no admitted checkout');

    let extraCommits: ExtraCommitInfo[] = [...(cand.extraCommits ?? [])];
    const shaDiffersFromMerged =
      cand.prState === 'MERGED' &&
      Boolean(cand.tipSha) &&
      Boolean(cand.mergedHeadSha) &&
      cand.tipSha !== cand.mergedHeadSha;

    if (
      shaDiffersFromMerged &&
      extraCommits.length === 0 &&
      repo &&
      SHA_RE.test(cand.tipSha!) &&
      SHA_RE.test(cand.mergedHeadSha!)
    ) {
      extraCommits = inspectMergedAhead({
        repo,
        branchSha: cand.tipSha!,
        mergedHeadSha: cand.mergedHeadSha!,
        base: cand.trunk ?? baseBranch,
        prs,
      }).extraCommits as ExtraCommitInfo[];
    }

    const isAheadOfMergedHead = shaDiffersFromMerged || extraCommits.length > 0;

    let cls: CleanupClass;
    let exactCommand: string | null = null;

    if (namedFacts.length > 0) {
      cls = 'named';
      exactCommand = null;
    } else if (cand.kind === 'worktree') {
      const wtPath = cand.worktreePath ?? cand.object;
      const corePath = cand.core ?? '<core>';
      const baseCmd = `git -C ${shellQuoteSingle(corePath)} worktree remove -- ${shellQuoteSingle(wtPath)}`;
      if (cand.worktreeKind === 'reviewer') {
        if (cand.treeState === 'clean' && cand.reviewerLedgerRan === true) {
          cls = 'deterministic';
          exactCommand = baseCmd;
        } else {
          cls = 'proposed';
          exactCommand = baseCmd;
        }
      } else if (cand.treeState === 'clean' && cand.prState === 'MERGED' && !isAheadOfMergedHead) {
        cls = 'deterministic';
        exactCommand = baseCmd;
      } else {
        cls = 'proposed';
        exactCommand = baseCmd;
      }
    } else if (cand.kind === 'local-branch') {
      const corePath = cand.core ?? '<core>';
      cls = 'proposed';
      exactCommand = `git -C ${shellQuoteSingle(corePath)} branch -d -- ${shellQuoteSingle(cand.branch)}`;
    } else {
      // remote-head
      const hostPath = cand.host ?? '<host>';
      const delCmd = `git -C ${shellQuoteSingle(hostPath)} push origin --delete -- ${shellQuoteSingle(cand.branch)}`;
      if (cand.prState === 'MERGED' && cand.tipSha && cand.mergedHeadSha && cand.tipSha === cand.mergedHeadSha && !isAheadOfMergedHead) {
        cls = 'deterministic';
        exactCommand = delCmd;
      } else {
        cls = 'proposed';
        exactCommand = delCmd;
      }
    }

    const prefix = cls === 'deterministic' ? 'D' : cls === 'proposed' ? 'P' : 'N';
    const id = `${prefix}${num}`;
    if (cls === 'deterministic') counts = { ...counts, deterministic: counts.deterministic + 1 };
    else if (cls === 'proposed') counts = { ...counts, proposed: counts.proposed + 1 };
    else counts = { ...counts, named: counts.named + 1 };

    const evidenceParts: string[] = [
      `PR ${cand.prNumber ? `#${cand.prNumber} ` : ''}${cand.prState}`,
    ];
    if (cand.tipSha) evidenceParts.push(`sha ${cand.tipSha.slice(0, 8)}`);
    if (cand.mergedHeadSha) evidenceParts.push(`mergedHead ${cand.mergedHeadSha.slice(0, 8)}`);
    if (cand.kind === 'worktree' && cand.treeState) {
      evidenceParts.push(
        cand.treeState === 'dirty' && cand.dirtyPaths && cand.dirtyPaths.length > 0
          ? `tree dirty (${cand.dirtyPaths.join(', ')})`
          : `tree ${cand.treeState}`,
      );
    }
    if (cand.kind === 'worktree' && cand.worktreeKind === 'reviewer') {
      evidenceParts.push(cand.reviewerLedgerRan ? 'reviewer ledger ran' : 'reviewer ledger missing');
    }
    if (cand.kind === 'remote-head' || openBasePrs.length > 0) {
      evidenceParts.push(formatOpenBaseEvidence(openBasePrs));
    }
    for (const fact of namedFacts) {
      if (!evidenceParts.includes(fact)) evidenceParts.push(fact);
    }
    if (isAheadOfMergedHead) {
      if (extraCommits.length > 0) {
        evidenceParts.push(
          `merged ahead of ${cand.mergedHeadSha?.slice(0, 8) ?? 'headRefOid'}: ${extraCommits
            .map((c) => `${c.sha.slice(0, 8)} ("${sanitizeText(c.subject)}") -> ${sanitizeText(c.landed)}`)
            .join('; ')}`,
        );
      } else {
        evidenceParts.push(
          `tip ${cand.tipSha?.slice(0, 8) ?? '?'} differs from mergedHead ${cand.mergedHeadSha?.slice(0, 8) ?? '?'}`,
        );
      }
    }

    rows.push({
      id,
      class: cls,
      kind: cand.kind,
      object: sanitizeText(cand.object),
      branch: sanitizeText(cand.branch),
      exactCommand,
      freesBytes: cand.freesBytes ?? 0,
      evidence: evidenceParts.join('; '),
      owner: sanitizeText(cand.owner),
      namedFacts,
      openBasePrs,
      extraCommits,
    });
  });

  return {
    contract: 'hatsu.cleanup-plan-guard/v0.1',
    command: 'classify',
    rows,
    counts,
  };
}

export function evaluatePreDelete(
  opts: {
    readonly repo: string;
    readonly target: string;
    readonly branch: string;
    readonly expectedSha: string;
    readonly base?: string;
    readonly gh?: string;
  },
  fetchOpenPrs: FetchOpenPrsFn = defaultFetchOpenPrs,
): { exitCode: number; result: PreDeleteResult } {
  if (!SLUG_RE.test(opts.target)) {
    throw new CleanupPlanGuardError(2, `--target must be <owner/name>, got ${JSON.stringify(sanitizeText(opts.target))}`);
  }
  if (!isValidBranchName(opts.branch)) {
    throw new CleanupPlanGuardError(2, `--branch is not a valid branch name: ${sanitizeText(opts.branch)}`);
  }
  const base = opts.base ?? 'main';
  if (!isValidBranchName(base)) {
    throw new CleanupPlanGuardError(2, `--base is not a valid branch name: ${sanitizeText(base)}`);
  }
  if (opts.branch === base) {
    throw new CleanupPlanGuardError(2, `refusing pre-delete against trunk branch '${opts.branch}'`);
  }
  if (!SHA_RE.test(opts.expectedSha)) {
    throw new CleanupPlanGuardError(2, `--expected-sha must be a 40-char hex SHA`);
  }

  const repo = resolveCanonicalRepo(opts.repo);
  const ghBin = opts.gh || 'gh';

  let ghOut: GhRunOutput;
  try {
    ghOut = fetchOpenPrs(ghBin, opts.target);
  } catch (err) {
    return {
      exitCode: 2,
      result: {
        contract: 'hatsu.cleanup-plan-guard/v0.1',
        command: 'pre-delete',
        status: 'unread-open-prs',
        deleteAllowed: false,
        repo,
        target: opts.target,
        branch: opts.branch,
        expectedSha: opts.expectedSha,
        remoteSha: null,
        openBasePrs: [],
        reason: `could not re-read open PR bases before delete (fail closed): ${sanitizeText((err as Error).message)}`,
      },
    };
  }

  if (ghOut.status !== 0) {
    return {
      exitCode: 2,
      result: {
        contract: 'hatsu.cleanup-plan-guard/v0.1',
        command: 'pre-delete',
        status: 'unread-open-prs',
        deleteAllowed: false,
        repo,
        target: opts.target,
        branch: opts.branch,
        expectedSha: opts.expectedSha,
        remoteSha: null,
        openBasePrs: [],
        reason: `could not re-read open PR bases before delete (fail closed): ${sanitizeText(ghOut.stderr || ghOut.stdout)}`,
      },
    };
  }

  let openPrs: OpenPrSummary[];
  try {
    const parsed = JSON.parse(ghOut.stdout) as unknown;
    if (!Array.isArray(parsed)) throw new Error('expected JSON array of open PRs');
    openPrs = parsed as OpenPrSummary[];
    indexOpenPrBases(openPrs);
  } catch (err) {
    return {
      exitCode: 2,
      result: {
        contract: 'hatsu.cleanup-plan-guard/v0.1',
        command: 'pre-delete',
        status: 'unread-open-prs',
        deleteAllowed: false,
        repo,
        target: opts.target,
        branch: opts.branch,
        expectedSha: opts.expectedSha,
        remoteSha: null,
        openBasePrs: [],
        reason: `malformed open PR list before delete (fail closed): ${sanitizeText((err as Error).message)}`,
      },
    };
  }

  const matchingPrs = indexOpenPrBases(openPrs).get(opts.branch) ?? [];
  if (matchingPrs.length > 0) {
    return {
      exitCode: 1,
      result: {
        contract: 'hatsu.cleanup-plan-guard/v0.1',
        command: 'pre-delete',
        status: 'refused-open-pr-base',
        deleteAllowed: false,
        repo,
        target: opts.target,
        branch: opts.branch,
        expectedSha: opts.expectedSha,
        remoteSha: null,
        openBasePrs: matchingPrs,
        reason: `refused remote delete of '${opts.branch}': open PR ${matchingPrs.map((n) => `#${n}`).join(', ')} now targets it as baseRefName; delete did not run`,
      },
    };
  }

  const ref = `refs/heads/${opts.branch}`;
  const lsRemote = runGit(repo, ['ls-remote', '--heads', 'origin', '--', ref]);
  if (lsRemote.status !== 0) {
    return {
      exitCode: 2,
      result: {
        contract: 'hatsu.cleanup-plan-guard/v0.1',
        command: 'pre-delete',
        status: 'unread-remote-sha',
        deleteAllowed: false,
        repo,
        target: opts.target,
        branch: opts.branch,
        expectedSha: opts.expectedSha,
        remoteSha: null,
        openBasePrs: [],
        reason: `git ls-remote failed before delete: ${sanitizeText(lsRemote.stderr)}`,
      },
    };
  }

  const lines = lsRemote.stdout
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l.length > 0);
  const expectedLine = `${opts.expectedSha.toLowerCase()}\t${ref}`;
  if (lines.length !== 1 || lines[0].toLowerCase() !== expectedLine) {
    const actualSha = lines[0]?.split(/\s+/)[0] ?? 'absent';
    return {
      exitCode: 1,
      result: {
        contract: 'hatsu.cleanup-plan-guard/v0.1',
        command: 'pre-delete',
        status: 'refused-sha-mismatch',
        deleteAllowed: false,
        repo,
        target: opts.target,
        branch: opts.branch,
        expectedSha: opts.expectedSha,
        remoteSha: lines.length === 1 ? sanitizeText(actualSha) : null,
        openBasePrs: [],
        reason: `refused remote delete of '${opts.branch}': expected ${opts.expectedSha.slice(0, 8)}, saw ${sanitizeText(actualSha)}`,
      },
    };
  }

  return {
    exitCode: 0,
    result: {
      contract: 'hatsu.cleanup-plan-guard/v0.1',
      command: 'pre-delete',
      status: 'allow-delete',
      deleteAllowed: true,
      repo,
      target: opts.target,
      branch: opts.branch,
      expectedSha: opts.expectedSha,
      remoteSha: opts.expectedSha,
      openBasePrs: [],
      reason: `verified '${opts.branch}' is the base of no open PR and matches ${opts.expectedSha.slice(0, 8)}`,
    },
  };
}

export type ParsedCleanupCli =
  | { readonly subcommand: 'help' }
  | {
      readonly subcommand: 'classify';
      readonly inputFile: string;
      readonly repo?: string;
      readonly base?: string;
      readonly json: boolean;
    }
  | {
      readonly subcommand: 'pre-delete';
      readonly opts: Parameters<typeof evaluatePreDelete>[0];
      readonly json: boolean;
    }
  | {
      readonly subcommand: 'merged-ahead';
      readonly opts: {
        readonly repo: string;
        readonly branchSha: string;
        readonly mergedHeadSha: string;
        readonly base: string;
        readonly prsJsonFile?: string;
      };
      readonly json: boolean;
    };

export function parseCliArgs(argv: string[]): ParsedCleanupCli {
  if (argv.length === 0 || argv[0] === '--help' || argv[0] === '-h') {
    return { subcommand: 'help' };
  }
  const sub = argv[0];
  if (sub !== 'classify' && sub !== 'pre-delete' && sub !== 'merged-ahead') {
    throw new CleanupPlanGuardError(
      2,
      `unknown subcommand ${JSON.stringify(sanitizeText(sub))} (expected classify | pre-delete | merged-ahead)`,
    );
  }

  const allowedBySub: Record<typeof sub, readonly string[]> = {
    classify: ['--input', '--repo', '--base'],
    'pre-delete': ['--repo', '--target', '--branch', '--expected-sha', '--base', '--gh'],
    'merged-ahead': ['--repo', '--branch-sha', '--merged-sha', '--base', '--prs-json'],
  };

  const values = new Map<string, string>();
  let json = false;
  for (let i = 1; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--json') {
      json = true;
      continue;
    }
    if (flag === '--help' || flag === '-h') {
      return { subcommand: 'help' };
    }
    if (!allowedBySub[sub].includes(flag)) {
      throw new CleanupPlanGuardError(2, `unknown argument ${JSON.stringify(sanitizeText(flag))} for '${sub}'`);
    }
    if (values.has(flag)) {
      throw new CleanupPlanGuardError(2, `${flag} given more than once`);
    }
    const val = argv[i + 1];
    if (val === undefined) {
      throw new CleanupPlanGuardError(2, `${flag} requires a value`);
    }
    values.set(flag, val);
    i += 1;
  }

  if (sub === 'classify') {
    const inputFile = values.get('--input');
    if (!inputFile) throw new CleanupPlanGuardError(2, 'classify requires --input <json>');
    return {
      subcommand: 'classify',
      inputFile,
      repo: values.get('--repo'),
      base: values.get('--base'),
      json,
    };
  }

  if (sub === 'pre-delete') {
    const repo = values.get('--repo');
    const target = values.get('--target');
    const branch = values.get('--branch');
    const expectedSha = values.get('--expected-sha');
    if (!repo || !target || !branch || !expectedSha) {
      throw new CleanupPlanGuardError(2, 'pre-delete requires --repo, --target, --branch, and --expected-sha');
    }
    return {
      subcommand: 'pre-delete',
      json,
      opts: {
        repo,
        target,
        branch,
        expectedSha,
        base: values.get('--base'),
        gh: values.get('--gh'),
      },
    };
  }

  const repo = values.get('--repo');
  const branchSha = values.get('--branch-sha');
  const mergedHeadSha = values.get('--merged-sha');
  const base = values.get('--base');
  if (!repo || !branchSha || !mergedHeadSha || !base) {
    throw new CleanupPlanGuardError(2, 'merged-ahead requires --repo, --branch-sha, --merged-sha, and --base');
  }
  return {
    subcommand: 'merged-ahead',
    json,
    opts: {
      repo,
      branchSha,
      mergedHeadSha,
      base,
      prsJsonFile: values.get('--prs-json'),
    },
  };
}

export function renderHuman(result: ClassifyResult | PreDeleteResult | MergedAheadResult): string {
  if (result.command === 'classify') {
    const lines = [
      `cleanup-plan-guard: ${result.rows.length} row(s) (${result.counts.deterministic} deterministic, ${result.counts.proposed} proposed, ${result.counts.named} named)`,
    ];
    for (const r of result.rows) {
      lines.push(`${r.id} [${r.class}] ${r.kind} ${r.object} — ${r.evidence}`);
    }
    return lines.join('\n');
  }
  if (result.command === 'pre-delete') {
    return [
      `cleanup-plan-guard: ${result.status} (deleteAllowed: ${String(result.deleteAllowed)})`,
      `branch: ${result.branch} (${result.target})`,
      `reason: ${result.reason}`,
    ].join('\n');
  }
  return [
    `cleanup-plan-guard: merged-ahead (${result.aheadCount} extra commit(s))`,
    `summary: ${result.summary}`,
  ].join('\n');
}

function readJsonFile<T>(filePath: string): T {
  try {
    return JSON.parse(readFileSync(filePath, 'utf8')) as T;
  } catch (err) {
    throw new CleanupPlanGuardError(2, `cannot read JSON file ${sanitizeText(filePath)}: ${sanitizeText((err as Error).message)}`);
  }
}

const USAGE = [
  'Usage:',
  '  node scripts/cleanup_plan_guard.mts classify --input <json> [--repo <path>] [--base <branch.base>] [--json]',
  '  node scripts/cleanup_plan_guard.mts pre-delete --repo <host-wt> --target <owner/name> --branch <branch> --expected-sha <sha> [--base <trunk>] [--gh <bin>] [--json]',
  '  node scripts/cleanup_plan_guard.mts merged-ahead --repo <path> --branch-sha <sha> --merged-sha <sha> --base <branch.base> [--prs-json <file>] [--json]',
].join('\n');

if (import.meta.main) {
  try {
    const parsed = parseCliArgs(process.argv.slice(2));
    if (parsed.subcommand === 'help') {
      console.log(USAGE);
      process.exit(0);
    }
    if (parsed.subcommand === 'classify') {
      const input = readJsonFile<{
        openPrs: OpenPrSummary[];
        candidates: CleanupPlanCandidate[];
        prs?: PrCandidateRef[];
      }>(parsed.inputFile);
      const res = classifyCleanupPlan({
        openPrs: input.openPrs ?? [],
        candidates: input.candidates ?? [],
        prs: input.prs,
        repo: parsed.repo,
        base: parsed.base,
      });
      console.log(parsed.json ? JSON.stringify(res, null, 2) : renderHuman(res));
      process.exit(0);
    }
    if (parsed.subcommand === 'pre-delete') {
      const outcome = evaluatePreDelete(parsed.opts);
      const output = parsed.json ? JSON.stringify(outcome.result, null, 2) : renderHuman(outcome.result);
      if (outcome.exitCode === 0) console.log(output);
      else console.error(output);
      process.exit(outcome.exitCode);
    }
    const prs = parsed.opts.prsJsonFile ? readJsonFile<PrCandidateRef[]>(parsed.opts.prsJsonFile) : [];
    const res = inspectMergedAhead({
      repo: parsed.opts.repo,
      branchSha: parsed.opts.branchSha,
      mergedHeadSha: parsed.opts.mergedHeadSha,
      base: parsed.opts.base,
      prs,
    });
    console.log(parsed.json ? JSON.stringify(res, null, 2) : renderHuman(res));
    process.exit(0);
  } catch (err) {
    const code = err instanceof CleanupPlanGuardError ? err.exitCode : 2;
    const msg = sanitizeText(err instanceof Error ? err.message : String(err));
    console.error(`cleanup-plan-guard: ${msg}`);
    process.exit(code);
  }
}
