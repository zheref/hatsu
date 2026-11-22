#!/usr/bin/env node
// en_push_guard.mts — hatsu:en § 3 pre-push PR-state guard & carrying-PR ledger target
// (zheref/hatsu#611).
//
// Calls `nen pr fetch --target <owner/name> --pr <N> --json` (available at nen 0.30.0; no new
// Nen verb is required) BEFORE every En push, failing closed on unread/unknown states and
// refusing any push onto a MERGED or CLOSED pull request (0 commits pushed to merged branch).
// When MERGED or CLOSED, emits the deterministic carrying-PR fallback and computes the successor
// carrying PR's hanten cycle ledger target (--pr <successor-N>) and cleanup scope.
//
// Usage:
//   node scripts/en_push_guard.mts check --repo <path> --target <owner/name> --pr <N> --base <branch.base> [--branch <name>] [--nen <bin>] [--json]
//   node scripts/en_push_guard.mts ledger-target --carrying-pr <N> --carrying-branch <branch> [--original-pr <M>] [--code <CODE>] [--json]
//
// Exit codes:
//   0  check: PR state is OPEN and head branch matches (pushAllowed: true); ledger-target: valid successor target
//   1  check: PR is MERGED/CLOSED (carry-on-successor-pr fallback) or head branch mismatch (pushAllowed: false);
//      ledger-target: carrying PR matches predecessor PR (predecessor-pr-refused)
//   2  usage/validation error, symlinked/non-git repo, or unreadable PR state (fail closed, pushAllowed: false)
import { spawnSync } from 'node:child_process';
import { existsSync, lstatSync, realpathSync } from 'node:fs';
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
  readonly status: 'allow-push' | 'carry-on-successor-pr' | 'head-branch-mismatch' | 'unread-pr-state';
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
  readonly carryCommits: readonly CarryCommit[];
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
  readonly hantenLedgerEnsureArgv: readonly string[];
  readonly hantenLedgerRecordArgv: readonly string[];
  readonly cleanupScope: string;
  readonly error?: string;
}

export interface CheckOptions {
  readonly repo: string;
  readonly target: string;
  readonly pr: number;
  readonly base: string;
  readonly branch?: string;
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

function collectCarryCommits(
  repo: string,
  headSha: string | null,
  branch: string,
  base: string,
): { anchorUsed: string | null; commits: CarryCommit[] } {
  const candidates: string[] = [];
  if (headSha && SHA_RE.test(headSha)) {
    const verifyHead = runGit(repo, ['cat-file', '-e', `${headSha}^{commit}`]);
    if (verifyHead.status === 0) candidates.push(headSha);
  }
  for (const ref of [`refs/remotes/origin/${branch}`, `refs/remotes/origin/${base}`]) {
    const res = runGit(repo, ['rev-parse', '--verify', '--quiet', `${ref}^{commit}`]);
    if (res.status === 0 && res.stdout.trim()) candidates.push(res.stdout.trim());
  }
  const anchorUsed = candidates[0] ?? null;
  if (!anchorUsed) return { anchorUsed: null, commits: [] };
  const log = runGit(repo, ['log', '--reverse', '--format=%H%x09%s', `${anchorUsed}..HEAD`]);
  if (log.status !== 0) return { anchorUsed, commits: [] };
  const commits: CarryCommit[] = [];
  for (const line of log.stdout.split('\n')) {
    if (!line.trim()) continue;
    const tab = line.indexOf('\t');
    if (tab <= 0) continue;
    commits.push({
      sha: sanitizeText(line.slice(0, tab)),
      subject: sanitizeText(line.slice(tab + 1)),
    });
  }
  return { anchorUsed, commits };
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

  let fetchOut: FetchPrOutput;
  try {
    fetchOut = fetchPr(opts.nen, opts.target, opts.pr);
  } catch (err) {
    const msg = sanitizeText((err as Error).message);
    return {
      exitCode: 2,
      result: {
        contract: 'hatsu.en-push-guard/v0.1',
        command: 'check',
        status: 'unread-pr-state',
        pushAllowed: false,
        repo,
        target: opts.target,
        prNumber: opts.pr,
        prState: null,
        branch,
        base: opts.base,
        prHeadRef: null,
        prHeadSha: null,
        prBaseRef: null,
        anchorUsed: null,
        carryCommits: [],
        error: `failed to read PR #${opts.pr} state before push: ${msg}`,
      },
    };
  }

  if (fetchOut.status !== 0) {
    const detail = sanitizeText(fetchOut.stderr || fetchOut.stdout || `nen pr fetch exited ${fetchOut.status}`);
    return {
      exitCode: 2,
      result: {
        contract: 'hatsu.en-push-guard/v0.1',
        command: 'check',
        status: 'unread-pr-state',
        pushAllowed: false,
        repo,
        target: opts.target,
        prNumber: opts.pr,
        prState: null,
        branch,
        base: opts.base,
        prHeadRef: null,
        prHeadSha: null,
        prBaseRef: null,
        anchorUsed: null,
        carryCommits: [],
        error: `failed to read PR #${opts.pr} state before push (fail closed): ${detail}`,
      },
    };
  }

  let parsed: ReturnType<typeof parsePrStatePayload>;
  try {
    parsed = parsePrStatePayload(fetchOut.stdout);
  } catch (err) {
    const msg = sanitizeText((err as Error).message);
    return {
      exitCode: 2,
      result: {
        contract: 'hatsu.en-push-guard/v0.1',
        command: 'check',
        status: 'unread-pr-state',
        pushAllowed: false,
        repo,
        target: opts.target,
        prNumber: opts.pr,
        prState: null,
        branch,
        base: opts.base,
        prHeadRef: null,
        prHeadSha: null,
        prBaseRef: null,
        anchorUsed: null,
        carryCommits: [],
        error: msg,
      },
    };
  }

  const { anchorUsed, commits } = collectCarryCommits(repo, parsed.headSha, branch, opts.base);

  if (parsed.state === 'MERGED' || parsed.state === 'CLOSED') {
    return {
      exitCode: 1,
      result: {
        contract: 'hatsu.en-push-guard/v0.1',
        command: 'check',
        status: 'carry-on-successor-pr',
        pushAllowed: false,
        repo,
        target: opts.target,
        prNumber: opts.pr,
        prState: parsed.state,
        branch,
        base: opts.base,
        prHeadRef: parsed.headRef,
        prHeadSha: parsed.headSha,
        prBaseRef: parsed.baseRef,
        anchorUsed,
        carryCommits: commits,
        fallback: {
          action: 'carry-on-successor-pr',
          targetBase: `origin/${opts.base}`,
          reason: `PR #${opts.pr} is already ${parsed.state}; refusing push to '${branch}' so 0 commits land on the ${parsed.state.toLowerCase()} branch`,
          steps: [
            `Refuse push to '${branch}' (PR #${opts.pr} is ${parsed.state}).`,
            `Cut a fresh isolated worktree and branch off origin/${opts.base}.`,
            commits.length > 0
              ? `Carry ${commits.length} unpushed commit(s) (${commits.map((c) => c.sha.slice(0, 8)).join(', ')}) onto the new branch and re-verify via kokusen, kotoamatsukami, and byakugan.`
              : `No unpushed local commit remains ahead of origin/${opts.base}; verify whether anything still needs a successor branch.`,
            `Publish the new branch and open a successor PR via shibari referencing #${opts.pr}.`,
            `Record hanten's review-cycle ledger against --pr <successor-N> (hanten § 2b) and scope cleanup to that carrying PR.`,
          ],
        },
      },
    };
  }

  if (parsed.headRef && parsed.headRef !== branch) {
    return {
      exitCode: 1,
      result: {
        contract: 'hatsu.en-push-guard/v0.1',
        command: 'check',
        status: 'head-branch-mismatch',
        pushAllowed: false,
        repo,
        target: opts.target,
        prNumber: opts.pr,
        prState: parsed.state,
        branch,
        base: opts.base,
        prHeadRef: parsed.headRef,
        prHeadSha: parsed.headSha,
        prBaseRef: parsed.baseRef,
        anchorUsed,
        carryCommits: commits,
        error: `local branch '${branch}' does not match PR #${opts.pr} headRef '${parsed.headRef}'`,
      },
    };
  }

  return {
    exitCode: 0,
    result: {
      contract: 'hatsu.en-push-guard/v0.1',
      command: 'check',
      status: 'allow-push',
      pushAllowed: true,
      repo,
      target: opts.target,
      prNumber: opts.pr,
      prState: 'OPEN',
      branch,
      base: opts.base,
      prHeadRef: parsed.headRef,
      prHeadSha: parsed.headSha,
      prBaseRef: parsed.baseRef,
      anchorUsed,
      carryCommits: commits,
    },
  };
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
  const hantenLedgerEnsureArgv = [
    'review',
    'ledger',
    'ensure',
    '--branch',
    opts.carryingBranch,
    '--pr',
    String(opts.carryingPr),
    '--json',
  ];
  const hantenLedgerRecordArgv = [
    'review',
    'ledger',
    'record',
    '--branch',
    opts.carryingBranch,
    '--pr',
    String(opts.carryingPr),
    '--json',
  ];

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
        hantenLedgerEnsureArgv,
        hantenLedgerRecordArgv,
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
      hantenLedgerEnsureArgv,
      hantenLedgerRecordArgv,
      cleanupScope,
    },
  };
}

export type ParsedCli =
  | { readonly subcommand: 'help' }
  | { readonly subcommand: 'check'; readonly opts: CheckOptions; readonly json: boolean }
  | { readonly subcommand: 'ledger-target'; readonly opts: LedgerTargetOptions; readonly json: boolean };

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
    const allowedCheck = ['--repo', '--target', '--pr', '--base', '--branch', '--nen'];
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
  if (result.carryCommits.length > 0) {
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
  '  node scripts/en_push_guard.mts check --repo <path> --target <owner/name> --pr <N> --base <branch.base> [--branch <name>] [--nen <bin>] [--json]',
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
