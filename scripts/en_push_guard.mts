#!/usr/bin/env node
// en_push_guard.mts — hatsu:en § 3 pre-push PR-state guard & carrying-PR ledger key
// (zheref/hatsu#611). A prose-ordered precondition of En's push: en § 3 runs it before every push;
// murasaki / publish_gate.sh do not call it.
//
// Calls `nen pr fetch --target <owner/name> --pr <N> --json` (available at nen 0.30.0; no new
// Nen verb is required) BEFORE every En push, failing closed on unread/unknown states and
// refusing any push onto a MERGED or CLOSED pull request (0 commits pushed to that branch).
//
// Carry set (MERGED/CLOSED): only the unpushed commits, the push En was about to make
// (zheref/hatsu#611 AC-1): git log --no-merges <PR headSha>..HEAD --not origin/<base>.
// A CLOSED PR with nothing unpushed is exit 4 (en § 6: closed unmerged, the run ends; HR-367).
// `--carry-from base` (en § 6's base-deletion successor row only, with --base <branch.base>): the
// child's WHOLE unlanded set, git log --no-merges origin/<base>..HEAD, pushed or not. The closed PR's
// last pushed headSha must be a readable ancestor of HEAD (git merge-base --is-ancestor), else exit 2.
// No readable anchor (headSha absent locally, origin/<base> missing) or a git failure is
// "carry list unread" (exit 2), never "nothing to carry".
//
// Post-push re-read (en § 3): re-run `check --require-head <pushed-sha>` once, paced. MERGED or
// CLOSED runs the same carry log from the PR's headSha: exit 4 only when empty (merged at the
// pushed head, nothing after it), else exit 1 naming the commits past that head. An OPEN PR whose
// headSha is not yet the pushed SHA is `pushed-head-unobserved` (exit 2): one more paced re-read,
// then en § 3's stop.
//
// Usage:
//   node scripts/en_push_guard.mts check --repo <path> --target <owner/name> --pr <N> --base <branch.base> [--branch <name>] [--require-head <sha>] [--carry-from head|base] [--nen <bin>] [--json]
//   node scripts/en_push_guard.mts ledger-target --carrying-pr <N> --carrying-branch <branch> [--original-pr <M>] [--code <CODE>] [--json]
//
// Exit codes (check):
//   0  OPEN, headRef matches the branch (pushAllowed: true); with --require-head, also headSha = it
//   1  MERGED/CLOSED with >= 1 unpushed commit to carry (carry-on-successor-pr; en § 6 fallback rows)
//   2  usage/validation error, symlinked/non-git repo, unreadable PR state, OPEN with missing headRef,
//      carry list unread, or pushed-head-unobserved on an OPEN PR (fail closed)
//   3  OPEN but headRef differs from the local branch (head-branch-mismatch): a stop handed back,
//      never the successor fallback
//   4  MERGED/CLOSED with nothing unpushed to carry (nothing-to-carry; en § 6 terminal rows)
// Exit codes (ledger-target): 0 successor key computed; 1 carrying PR equals the predecessor; 2 usage.
// ledger-target computes the key and path only; hanten § 2b owns opening and recording the ledger.
import { spawnSync } from 'node:child_process';
import { existsSync, lstatSync, realpathSync } from 'node:fs';
import { resolve } from 'node:path';
// SEC-12: one redaction rule for both guards (userinfo up to the last '@', percent-encoded too).
import { redactCredentials } from './cleanup_plan_guard.mts';

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
const CODE_RE = /^[A-Z][A-Z0-9-]{0,15}$/;
const SHA_RE = /^[0-9a-f]{40}$/i;

export type PrState = 'OPEN' | 'MERGED' | 'CLOSED';

export interface CarryCommit {
  readonly sha: string;
  readonly subject: string;
}

export interface CarryFallbackPlan {
  readonly action: 'carry-on-successor-pr';
  readonly targetBase: string;
  readonly reason: string;
  readonly steps: readonly string[];
}

export interface EnPushCheckResult {
  readonly contract: 'hatsu.en-push-guard/v0.1';
  readonly command: 'check';
  readonly status:
    | 'allow-push'
    | 'carry-on-successor-pr'
    | 'nothing-to-carry'
    | 'head-branch-mismatch'
    | 'unread-pr-state'
    | 'pushed-head-unobserved'
    | 'unread-carry-list';
  readonly pushAllowed: boolean;
  readonly repo: string;
  readonly target: string;
  readonly prNumber: number;
  readonly prState: PrState | null;
  readonly branch: string;
  readonly base: string;
  readonly prHeadRef: string | null;
  readonly prHeadSha: string | null;
  readonly prBaseRef: string | null;
  readonly anchorUsed: string | null;
  readonly carryListRead: boolean;
  readonly carryCommits: readonly CarryCommit[];
  readonly requireHead: string | null;
  readonly fallback?: CarryFallbackPlan;
  readonly error?: string;
}

export interface LedgerTargetResult {
  readonly contract: 'hatsu.en-push-guard/v0.1';
  readonly command: 'ledger-target';
  readonly status: 'carrying-pr-ledger' | 'predecessor-pr-refused';
  readonly carryingPr: number;
  readonly carryingBranch: string;
  readonly originalPr: number | null;
  readonly branchSlug: string;
  readonly hantenLedgerKey: string;
  readonly hantenLedgerPath: string;
  readonly cleanupScope: string;
  readonly error?: string;
}

export interface CheckOptions {
  readonly repo: string;
  readonly target: string;
  readonly pr: number;
  readonly base: string;
  readonly branch?: string;
  readonly requireHead?: string;
  readonly carryFrom?: 'head' | 'base';
  readonly nen: string;
}

export interface LedgerTargetOptions {
  readonly carryingPr: number;
  readonly carryingBranch: string;
  readonly originalPr?: number;
  readonly code?: string;
}

export interface FetchPrOutput {
  readonly status: number;
  readonly stdout: string;
  readonly stderr: string;
}

export type FetchPrFn = (nenBin: string, target: string, prNumber: number) => FetchPrOutput;

export class EnPushGuardError extends Error {
  readonly exitCode: number;
  constructor(exitCode: number, message: string) {
    super(message);
    this.exitCode = exitCode;
  }
}

export function sanitizeText(value: string): string {
  return redactCredentials(value)
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

function parsePositiveInt(raw: string, flag: string): number {
  if (!/^[1-9][0-9]*$/.test(raw)) {
    throw new EnPushGuardError(2, `${flag} must be a positive integer, got ${JSON.stringify(sanitizeText(raw))}`);
  }
  const n = Number(raw);
  if (!Number.isSafeInteger(n) || n <= 0) {
    throw new EnPushGuardError(2, `${flag} exceeds safe integer bounds`);
  }
  return n;
}

export function branchToSlug(branch: string): string {
  return branch.replace(/\//g, '-');
}

export function defaultFetchPr(nenBin: string, target: string, prNumber: number): FetchPrOutput {
  const res = spawnSync(nenBin, ['pr', 'fetch', '--target', target, '--pr', String(prNumber), '--json'], {
    encoding: 'utf8',
  });
  if (res.error) {
    return { status: 2, stdout: '', stderr: res.error.message };
  }
  return { status: res.status ?? 1, stdout: res.stdout ?? '', stderr: res.stderr ?? '' };
}

function resolveCanonicalRepo(repoArg: string): string {
  const abs = resolve(repoArg);
  if (!existsSync(abs)) {
    throw new EnPushGuardError(2, `repository path does not exist: ${sanitizeText(abs)}`);
  }
  const st = lstatSync(abs);
  if (st.isSymbolicLink() || !st.isDirectory()) {
    throw new EnPushGuardError(2, `repository path must be a real non-symlink directory: ${sanitizeText(abs)}`);
  }
  const real = realpathSync.native(abs);
  if (real !== abs) {
    throw new EnPushGuardError(2, `repository path must be canonical without symlink segments: ${sanitizeText(abs)}`);
  }
  const top = runGit(real, ['rev-parse', '--show-toplevel']);
  if (top.status !== 0 || top.stdout.trim() !== real) {
    throw new EnPushGuardError(2, `path is not a git worktree root: ${sanitizeText(real)}`);
  }
  return real;
}

function parsePrStatePayload(stdout: string): {
  state: PrState;
  headRef: string | null;
  headSha: string | null;
  baseRef: string | null;
} {
  let parsed: Record<string, unknown>;
  try {
    const raw = JSON.parse(stdout) as unknown;
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
      throw new Error('PR payload is not a JSON object');
    }
    parsed = raw as Record<string, unknown>;
  } catch (err) {
    throw new EnPushGuardError(2, `malformed JSON from nen pr fetch: ${sanitizeText((err as Error).message)}`);
  }
  const prObj =
    parsed.pr && typeof parsed.pr === 'object' && !Array.isArray(parsed.pr)
      ? (parsed.pr as Record<string, unknown>)
      : parsed;
  const rawState = parsed.state ?? prObj.state;
  if (rawState !== 'OPEN' && rawState !== 'MERGED' && rawState !== 'CLOSED') {
    throw new EnPushGuardError(
      2,
      `unrecognized PR state from nen pr fetch: ${JSON.stringify(sanitizeText(String(rawState ?? 'missing')))}`,
    );
  }
  const headRef = typeof prObj.headRef === 'string' && prObj.headRef.trim() ? sanitizeText(prObj.headRef) : null;
  const headSha = typeof prObj.headSha === 'string' && prObj.headSha.trim() ? sanitizeText(prObj.headSha) : null;
  const baseRef = typeof prObj.baseRef === 'string' && prObj.baseRef.trim() ? sanitizeText(prObj.baseRef) : null;
  return { state: rawState, headRef, headSha, baseRef };
}

function readCommitRef(repo: string, ref: string): string | null {
  const res = runGit(repo, ['rev-parse', '--verify', '--quiet', `${ref}^{commit}`]);
  const sha = res.stdout.trim();
  return res.status === 0 && SHA_RE.test(sha) ? sha : null;
}

function parseLog(stdout: string): CarryCommit[] {
  const commits: CarryCommit[] = [];
  for (const line of stdout.split('\n')) {
    if (!line.trim()) continue;
    const tab = line.indexOf('\t');
    if (tab <= 0) continue;
    commits.push({ sha: sanitizeText(line.slice(0, tab)), subject: sanitizeText(line.slice(tab + 1)) });
  }
  return commits;
}

// The carry set: the unpushed commits only. Non-merge commits on HEAD past the PR's last pushed
// headSha that origin/<base> does not already hold, for MERGED and CLOSED alike (zheref/hatsu#611
// AC-1: "En is about to push"). OPEN lists the same range, informational.
export function collectCarryCommits(
  repo: string,
  state: PrState,
  headSha: string | null,
  base: string,
  carryFrom: 'head' | 'base' = 'head',
): { read: boolean; anchorUsed: string | null; commits: CarryCommit[]; error?: string } {
  const baseSha = readCommitRef(repo, `refs/remotes/origin/${base}`);
  // en § 6's base-deletion successor only: the child's WHOLE unlanded set off origin/<branch.base>.
  if (carryFrom === 'base' && state === 'CLOSED') {
    if (!baseSha) return { read: false, anchorUsed: null, commits: [], error: `origin/${base} is not readable` };
    // The closed PR's last pushed head must be a readable commit this HEAD contains.
    const last = headSha && SHA_RE.test(headSha) ? readCommitRef(repo, headSha) : null;
    if (!last) {
      return { read: false, anchorUsed: null, commits: [], error: 'PR headSha is not a readable local commit' };
    }
    if (runGit(repo, ['merge-base', '--is-ancestor', last, 'HEAD']).status !== 0) {
      return { read: false, anchorUsed: null, commits: [], error: `PR headSha ${last.slice(0, 8)} is not an ancestor of HEAD` };
    }
    const log = runGit(repo, ['log', '--no-merges', '--reverse', '--format=%H%x09%s', `${baseSha}..HEAD`]);
    if (log.status !== 0) {
      return { read: false, anchorUsed: `origin/${base}`, commits: [], error: `git log failed: ${sanitizeText(log.stderr)}` };
    }
    return { read: true, anchorUsed: `origin/${base}`, commits: parseLog(log.stdout) };
  }
  const head = headSha && SHA_RE.test(headSha) ? readCommitRef(repo, headSha) : null;
  if (!head) {
    return { read: false, anchorUsed: null, commits: [], error: 'PR headSha is not a readable local commit' };
  }
  if (state !== 'OPEN' && !baseSha) {
    return { read: false, anchorUsed: null, commits: [], error: `origin/${base} is not readable` };
  }
  const args = ['log', '--no-merges', '--reverse', '--format=%H%x09%s', `${head}..HEAD`];
  if (baseSha) args.push('--not', baseSha);
  const log = runGit(repo, args);
  if (log.status !== 0) {
    return { read: false, anchorUsed: head, commits: [], error: `git log failed: ${sanitizeText(log.stderr)}` };
  }
  return { read: true, anchorUsed: head, commits: parseLog(log.stdout) };
}

export function evaluateEnPushGuard(
  opts: CheckOptions,
  fetchPr: FetchPrFn = defaultFetchPr,
): { exitCode: number; result: EnPushCheckResult } {
  if (!SLUG_RE.test(opts.target)) {
    throw new EnPushGuardError(2, `--target must be <owner/name>, got ${JSON.stringify(sanitizeText(opts.target))}`);
  }
  if (!Number.isSafeInteger(opts.pr) || opts.pr <= 0) {
    throw new EnPushGuardError(2, `--pr must be a positive integer`);
  }
  if (!isValidBranchName(opts.base)) {
    throw new EnPushGuardError(2, `--base is not a valid branch name: ${sanitizeText(opts.base)}`);
  }
  if (opts.requireHead !== undefined && !SHA_RE.test(opts.requireHead)) {
    throw new EnPushGuardError(2, `--require-head must be a 40-char hex SHA`);
  }
  const requireHead = opts.requireHead ? opts.requireHead.toLowerCase() : null;

  const repo = resolveCanonicalRepo(opts.repo);
  let branch = opts.branch;
  if (branch === undefined) {
    const sym = runGit(repo, ['symbolic-ref', '--short', 'HEAD']);
    if (sym.status !== 0 || !sym.stdout.trim()) {
      throw new EnPushGuardError(2, `checkout at ${sanitizeText(repo)} is detached or has unreadable HEAD`);
    }
    branch = sym.stdout.trim();
  }
  if (!isValidBranchName(branch)) {
    throw new EnPushGuardError(2, `--branch is not a valid branch name: ${sanitizeText(branch)}`);
  }
  const theBranch = branch;

  const make = (
    exitCode: number,
    fields: Partial<EnPushCheckResult> & Pick<EnPushCheckResult, 'status'>,
  ): { exitCode: number; result: EnPushCheckResult } => ({
    exitCode,
    result: {
      contract: 'hatsu.en-push-guard/v0.1',
      command: 'check',
      pushAllowed: false,
      repo,
      target: opts.target,
      prNumber: opts.pr,
      prState: null,
      branch: theBranch,
      base: opts.base,
      prHeadRef: null,
      prHeadSha: null,
      prBaseRef: null,
      anchorUsed: null,
      carryListRead: false,
      carryCommits: [],
      requireHead,
      ...fields,
    },
  });

  let fetchOut: FetchPrOutput;
  try {
    fetchOut = fetchPr(opts.nen, opts.target, opts.pr);
  } catch (err) {
    return make(2, {
      status: 'unread-pr-state',
      error: `failed to read PR #${opts.pr} state before push: ${sanitizeText((err as Error).message)}`,
    });
  }
  if (fetchOut.status !== 0) {
    const detail = sanitizeText(fetchOut.stderr || fetchOut.stdout || `nen pr fetch exited ${fetchOut.status}`);
    return make(2, {
      status: 'unread-pr-state',
      error: `failed to read PR #${opts.pr} state before push (fail closed): ${detail}`,
    });
  }
  let parsed: ReturnType<typeof parsePrStatePayload>;
  try {
    parsed = parsePrStatePayload(fetchOut.stdout);
  } catch (err) {
    return make(2, { status: 'unread-pr-state', error: sanitizeText((err as Error).message) });
  }

  const read = {
    prState: parsed.state,
    prHeadRef: parsed.headRef,
    prHeadSha: parsed.headSha,
    prBaseRef: parsed.baseRef,
  };
  const pushedSeen = requireHead !== null && parsed.headSha?.toLowerCase() === requireHead;

  if (parsed.state === 'OPEN') {
    if (!parsed.headRef) {
      return make(2, { ...read, status: 'unread-pr-state', error: `PR #${opts.pr} reads OPEN with no headRef (fail closed)` });
    }
    if (parsed.headRef !== theBranch) {
      return make(3, {
        ...read,
        status: 'head-branch-mismatch',
        error: `local branch '${theBranch}' does not match PR #${opts.pr} headRef '${parsed.headRef}'; stop handed back`,
      });
    }
    if (requireHead !== null && !pushedSeen) {
      return make(2, {
        ...read,
        status: 'pushed-head-unobserved',
        error: `PR #${opts.pr} headSha ${parsed.headSha ?? 'missing'} is not the pushed ${requireHead.slice(0, 8)} yet; one paced re-read, then en § 3's stop`,
      });
    }
    const carry = collectCarryCommits(repo, 'OPEN', parsed.headSha, opts.base);
    return make(0, {
      ...read,
      status: 'allow-push',
      pushAllowed: true,
      anchorUsed: carry.anchorUsed,
      carryListRead: carry.read,
      carryCommits: carry.commits,
    });
  }

  // MERGED or CLOSED: never push. The carry log runs even when merged at the pushed head: commits
  // made after that push are still unpushed.
  const carry = collectCarryCommits(repo, parsed.state, parsed.headSha, opts.base, opts.carryFrom ?? 'head');
  if (!carry.read) {
    return make(2, {
      ...read,
      status: 'unread-carry-list',
      anchorUsed: carry.anchorUsed,
      error: `PR #${opts.pr} is ${parsed.state}; carry list unread (fail closed, push refused): ${carry.error}`,
    });
  }
  if (carry.commits.length === 0) {
    return make(4, {
      ...read,
      status: 'nothing-to-carry',
      anchorUsed: carry.anchorUsed,
      carryListRead: true,
      error: `PR #${opts.pr} is ${parsed.state}; carry list read, nothing to carry past ${carry.anchorUsed && SHA_RE.test(carry.anchorUsed) ? carry.anchorUsed.slice(0, 8) : (carry.anchorUsed ?? `origin/${opts.base}`)} off origin/${opts.base} (en § 6 terminal row)`,
    });
  }
  const shas = carry.commits.map((c) => c.sha.slice(0, 8)).join(', ');
  return make(1, {
    ...read,
    status: 'carry-on-successor-pr',
    anchorUsed: carry.anchorUsed,
    carryListRead: true,
    carryCommits: carry.commits,
    fallback: {
      action: 'carry-on-successor-pr',
      targetBase: `origin/${opts.base}`,
      reason: `PR #${opts.pr} is already ${parsed.state}; refusing push to '${theBranch}' so 0 commits land on the ${parsed.state.toLowerCase()} branch`,
      steps: [
        `Refuse push to '${theBranch}' (PR #${opts.pr} is ${parsed.state}).`,
        `Cut a fresh isolated worktree and branch off origin/${opts.base}.`,
        `Cherry-pick the ${carry.commits.length} ${opts.carryFrom === 'base' ? 'unlanded' : 'unpushed'} commit(s) (${shas}) onto the new branch (a conflict is a stop handed back) and re-verify via kokusen, kotoamatsukami, and byakugan.`,
        `Publish the new branch and open a successor PR via shibari referencing #${opts.pr}.`,
        `Raise hatsu:hanten on the successor PR; hanten § 2b keys its ledger to --pr <successor-N>.`,
      ],
    },
  });
}

export function resolveCarryingLedgerTarget(opts: LedgerTargetOptions): {
  exitCode: number;
  result: LedgerTargetResult;
} {
  if (!Number.isSafeInteger(opts.carryingPr) || opts.carryingPr <= 0) {
    throw new EnPushGuardError(2, `--carrying-pr must be a positive integer`);
  }
  if (!isValidBranchName(opts.carryingBranch)) {
    throw new EnPushGuardError(2, `--carrying-branch is not a valid branch name: ${sanitizeText(opts.carryingBranch)}`);
  }
  if (opts.originalPr !== undefined && (!Number.isSafeInteger(opts.originalPr) || opts.originalPr <= 0)) {
    throw new EnPushGuardError(2, `--original-pr must be a positive integer`);
  }
  if (opts.code !== undefined && !CODE_RE.test(opts.code)) {
    throw new EnPushGuardError(2, `--code must match ^[A-Z][A-Z0-9-]{0,15}$`);
  }

  const branchSlug = branchToSlug(opts.carryingBranch);
  const hantenLedgerKey = `${branchSlug}-pr${opts.carryingPr}`;
  const hantenLedgerPath = `.nen/hanten/${hantenLedgerKey}.cycle.json`;
  const cleanupScope = opts.code ? `for ${opts.code}#${opts.carryingPr}` : `for ${opts.carryingBranch}`;
  if (opts.originalPr !== undefined && opts.originalPr === opts.carryingPr) {
    return {
      exitCode: 1,
      result: {
        contract: 'hatsu.en-push-guard/v0.1',
        command: 'ledger-target',
        status: 'predecessor-pr-refused',
        carryingPr: opts.carryingPr,
        carryingBranch: opts.carryingBranch,
        originalPr: opts.originalPr,
        branchSlug,
        hantenLedgerKey,
        hantenLedgerPath,
        cleanupScope,
        error: `carrying PR #${opts.carryingPr} must differ from merged/closed predecessor PR #${opts.originalPr}`,
      },
    };
  }

  return {
    exitCode: 0,
    result: {
      contract: 'hatsu.en-push-guard/v0.1',
      command: 'ledger-target',
      status: 'carrying-pr-ledger',
      carryingPr: opts.carryingPr,
      carryingBranch: opts.carryingBranch,
      originalPr: opts.originalPr ?? null,
      branchSlug,
      hantenLedgerKey,
      hantenLedgerPath,
      cleanupScope,
    },
  };
}

export type ParsedCli =
  | { readonly subcommand: 'help' }
  | { readonly subcommand: 'check'; readonly opts: CheckOptions; readonly json: boolean }
  | { readonly subcommand: 'ledger-target'; readonly opts: LedgerTargetOptions; readonly json: boolean };

function parseCarryFrom(raw: string | undefined): 'head' | 'base' | undefined {
  if (raw === undefined) return undefined;
  if (raw !== 'head' && raw !== 'base') {
    throw new EnPushGuardError(2, `--carry-from must be head or base, got ${JSON.stringify(sanitizeText(raw))}`);
  }
  return raw;
}

export function parseCliArgs(argv: string[]): ParsedCli {
  if (argv.length === 0 || argv[0] === '--help' || argv[0] === '-h') {
    return { subcommand: 'help' };
  }
  const sub = argv[0];
  if (sub !== 'check' && sub !== 'ledger-target') {
    throw new EnPushGuardError(2, `unknown subcommand ${JSON.stringify(sanitizeText(sub))} (expected check | ledger-target)`);
  }

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
    const allowedCheck = ['--repo', '--target', '--pr', '--base', '--branch', '--require-head', '--carry-from', '--nen'];
    const allowedLedger = ['--carrying-pr', '--carrying-branch', '--original-pr', '--code'];
    const allowed = sub === 'check' ? allowedCheck : allowedLedger;
    if (!allowed.includes(flag)) {
      throw new EnPushGuardError(2, `unknown argument ${JSON.stringify(sanitizeText(flag))} for '${sub}'`);
    }
    if (values.has(flag)) {
      throw new EnPushGuardError(2, `${flag} given more than once`);
    }
    const val = argv[i + 1];
    if (val === undefined) {
      throw new EnPushGuardError(2, `${flag} requires a value`);
    }
    values.set(flag, val);
    i += 1;
  }

  if (sub === 'check') {
    const repo = values.get('--repo');
    const target = values.get('--target');
    const prRaw = values.get('--pr');
    const base = values.get('--base');
    if (!repo || !target || !prRaw || !base) {
      throw new EnPushGuardError(2, 'check requires --repo, --target, --pr, and --base');
    }
    return {
      subcommand: 'check',
      json,
      opts: {
        repo,
        target,
        pr: parsePositiveInt(prRaw, '--pr'),
        base,
        branch: values.get('--branch'),
        requireHead: values.get('--require-head'),
        carryFrom: parseCarryFrom(values.get('--carry-from')),
        nen: values.get('--nen') || process.env.NEN || 'nen',
      },
    };
  }

  const carryingPrRaw = values.get('--carrying-pr');
  const carryingBranch = values.get('--carrying-branch');
  if (!carryingPrRaw || !carryingBranch) {
    throw new EnPushGuardError(2, 'ledger-target requires --carrying-pr and --carrying-branch');
  }
  const originalPrRaw = values.get('--original-pr');
  return {
    subcommand: 'ledger-target',
    json,
    opts: {
      carryingPr: parsePositiveInt(carryingPrRaw, '--carrying-pr'),
      carryingBranch,
      originalPr: originalPrRaw !== undefined ? parsePositiveInt(originalPrRaw, '--original-pr') : undefined,
      code: values.get('--code'),
    },
  };
}

export function renderHuman(result: EnPushCheckResult | LedgerTargetResult): string {
  if (result.command === 'ledger-target') {
    const lines = [
      `en-push-guard: ${result.status}`,
      `carrying PR: #${result.carryingPr} (${result.carryingBranch})`,
      `hanten ledger: ${result.hantenLedgerPath}`,
      `cleanup scope: ${result.cleanupScope}`,
    ];
    if (result.error) lines.push(`error: ${result.error}`);
    return lines.join('\n');
  }
  const lines = [
    `en-push-guard: ${result.status} (pushAllowed: ${String(result.pushAllowed)})`,
    `pr: ${result.target}#${result.prNumber} (${result.prState ?? 'UNREAD'})`,
    `branch: ${result.branch} -> base ${result.base}`,
  ];
  if (!result.carryListRead && result.prState !== null && result.prState !== 'OPEN') {
    lines.push('carry list: unread');
  } else if (result.carryCommits.length > 0) {
    lines.push(
      `carry commits (${result.carryCommits.length}): ${result.carryCommits.map((c) => `${c.sha.slice(0, 8)} ${c.subject}`).join('; ')}`,
    );
  }
  if (result.fallback) {
    lines.push(`fallback: ${result.fallback.reason}`);
    for (const step of result.fallback.steps) lines.push(`  - ${step}`);
  }
  if (result.error) lines.push(`error: ${result.error}`);
  return lines.join('\n');
}

const USAGE = [
  'Usage:',
  '  node scripts/en_push_guard.mts check --repo <path> --target <owner/name> --pr <N> --base <branch.base> [--branch <name>] [--require-head <sha>] [--carry-from head|base] [--nen <bin>] [--json]',
  '  node scripts/en_push_guard.mts ledger-target --carrying-pr <N> --carrying-branch <branch> [--original-pr <M>] [--code <CODE>] [--json]',
].join('\n');

if (import.meta.main) {
  try {
    const parsed = parseCliArgs(process.argv.slice(2));
    if (parsed.subcommand === 'help') {
      console.log(USAGE);
      process.exit(0);
    }
    const outcome =
      parsed.subcommand === 'check'
        ? evaluateEnPushGuard(parsed.opts)
        : resolveCarryingLedgerTarget(parsed.opts);
    if (parsed.json) {
      console.log(JSON.stringify(outcome.result, null, 2));
    } else {
      const text = renderHuman(outcome.result);
      if (outcome.exitCode === 0) console.log(text);
      else console.error(text);
    }
    process.exit(outcome.exitCode);
  } catch (err) {
    const code = err instanceof EnPushGuardError ? err.exitCode : 2;
    const msg = sanitizeText(err instanceof Error ? err.message : String(err));
    console.error(`en-push-guard: ${msg}`);
    process.exit(code);
  }
}
