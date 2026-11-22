#!/usr/bin/env node
// amaterasu_preview.mts — explicit standalone local preview from a maintainer-selected checkout or worktree
// (zheref/hatsu#617). Launches directly in the selected tree on disk (uncommitted edits included) with 0 core swaps,
// reports checkout/target/verbatim command, preserves nen exit codes, checks core swap status when targeting core,
// supports launch.fallback for disconnected default devices, and refuses occupied resources before spawning while
// leaving existing sessions intact. Retains § 3 deferral when invoked with --automatic from a non-core worktree.
import { spawn, spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import {
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  renameSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { createConnection, createServer } from 'node:net';
import { dirname, isAbsolute, join, resolve } from 'node:path';

export interface PreviewOptions {
  repo: string;
  target?: string;
  automatic: boolean;
  dryRun: boolean;
  json: boolean;
  nen: string;
  quiet?: boolean;
}

export interface StepCommand {
  exe: string;
  argv: string[];
  cwd: string;
  formatted: string;
}

export interface ConflictDetail {
  resource: string;
  reason: string;
  holder?: {
    pid: number;
    checkout: string;
    target: string;
    branch: string;
  };
}

export interface PreviewResult {
  contract: 'hatsu.amaterasu-preview/v0.1';
  status:
    | 'preview launched'
    | 'dry-run plan ready'
    | 'core launch deferred; explicit maintainer call required'
    | 'no launch target declared; skipped'
    | 'resource conflict'
    | 'preview interrupted'
    | 'launch failed'
    | 'error';
  executed: boolean;
  deferred: boolean;
  dryRun: boolean;
  checkout: string;
  branch: string;
  uncommittedPaths: string[];
  coreCheckout: string;
  coreBranch: string;
  coreSwaps: 0;
  target: string | null;
  lane: string | null;
  verb: 'dev' | 'run' | null;
  command: string | null;
  steps: StepCommand[];
  conflicts: ConflictDetail[];
  fallbackFrom?: string;
  coreSwapStatus?: string;
  stdout: string;
  stderr: string;
  error?: string;
}

interface SessionEntry {
  id: string;
  pid: number;
  checkout: string;
  branch: string;
  target: string;
  verb: 'dev' | 'run';
  lane: string;
  resources: string[];
  startedAt: string;
}

interface LockOwner {
  token: string;
  pid: number;
  createdAt: number;
}

interface ContractPrecondition {
  kind?: string;
  value?: unknown;
  expect?: string;
}

interface LaunchTargetSpec {
  lane?: string;
  verb?: string;
  unsupported?: string;
  device?: string | { name?: string; kind?: string } | null;
}

interface LaunchContract {
  project?: {
    defaultLane?: string;
    launch?: Record<string, LaunchTargetSpec>;
    preconditions?: Record<string, ContractPrecondition[]>;
  };
}

interface WorkflowLaunchConfig {
  launch?: {
    default?: unknown;
    fallback?: unknown;
  };
}

interface DryRunJson {
  lane?: string;
  verb?: string;
  cwd?: string;
  steps?: Array<{ exe?: string; argv?: string[]; cwd?: string }>;
  preconditions?: Array<{ kind?: string; value?: unknown; expect?: string; satisfied?: boolean }>;
  target?: { name?: string; verb?: string; lane?: string; device?: { name?: string } | string | null };
}

interface WorktreesJson {
  core?: string;
  worktrees?: Array<{ path?: string; mark?: string | null; branch?: string | null }>;
}

const LOCK_STALE_MS = 60_000;
const LOCK_OWNER_GRACE_MS = 500;
const LOCK_WAIT_MS = 5_000;
const PORT_PROBE_TIMEOUT_MS = 350;

class PreviewFatalError extends Error {
  exitCode: number;
  constructor(exitCode: number, message: string) {
    super(message);
    this.exitCode = exitCode;
  }
}

function usageError(message: string): never {
  console.error(`amaterasu-preview: ${message}`);
  process.exit(2);
}

export function parseCliArgs(argv: string[]): PreviewOptions {
  const opts: PreviewOptions = {
    repo: '.',
    automatic: false,
    dryRun: false,
    json: false,
    nen: process.env.NEN || 'nen',
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') {
      console.log(
        'Usage: node scripts/amaterasu_preview.mts --repo <checkout> [--target <name>] [--automatic] [--dry-run] [--json] [--nen <bin>]',
      );
      process.exit(0);
    }
    if (arg === '--repo' || arg === '--target' || arg === '--nen') {
      const value = argv[i + 1];
      if (!value || value.startsWith('-')) usageError(`${arg} requires a value`);
      if (arg === '--repo') opts.repo = value;
      else if (arg === '--target') opts.target = value;
      else opts.nen = value;
      i += 1;
      continue;
    }
    if (arg === '--automatic') {
      opts.automatic = true;
      continue;
    }
    if (arg === '--dry-run') {
      opts.dryRun = true;
      continue;
    }
    if (arg === '--json') {
      opts.json = true;
      continue;
    }
    usageError(`unknown argument '${arg}'`);
  }
  return opts;
}

export function sanitizeTerminal(value: string): string {
  // Strip ANSI CSI/OSC sequences and ASCII control bytes except newlines cleanly before human rendering.
  return value
    .replace(/\x1b\[[0-9;?]*[ -/]*[@-~]/g, '')
    .replace(/\x1b\][^\x07]*(?:\x07|\x1b\\)/g, '')
    .replace(/[\x00-\x09\x0b-\x1f\x7f]/g, ' ');
}

export function formatShellArg(value: string): string {
  if (/^[A-Za-z0-9_./:=,@+-]+$/.test(value)) return value;
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

export function formatCommand(exe: string, argv: string[]): string {
  return [exe, ...argv].map(formatShellArg).join(' ');
}

function safeRealpath(targetPath: string): string | null {
  try {
    return realpathSync(targetPath);
  } catch {
    return null;
  }
}

function lstatOrNull(targetPath: string) {
  try {
    return lstatSync(targetPath);
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') return null;
    throw err;
  }
}

function assertNotSymlink(targetPath: string, label: string): void {
  const st = lstatOrNull(targetPath);
  if (st?.isSymbolicLink()) {
    throw new PreviewFatalError(2, `refusing symlinked ${label}: ${targetPath}`);
  }
}

function runGit(cwd: string, args: string[]): { status: number; stdout: string; stderr: string } {
  const res = spawnSync('git', ['-C', cwd, ...args], { encoding: 'utf8' });
  return {
    status: res.status ?? 1,
    stdout: res.stdout ?? '',
    stderr: res.stderr ?? '',
  };
}

function runNenSync(
  nenBin: string,
  args: string[],
  cwd?: string,
): { status: number; stdout: string; stderr: string; error?: Error } {
  const res = spawnSync(nenBin, args, { cwd, encoding: 'utf8' });
  if (res.error) return { status: 2, stdout: '', stderr: res.error.message, error: res.error };
  return {
    status: res.status ?? 1,
    stdout: res.stdout ?? '',
    stderr: res.stderr ?? '',
  };
}

function parsePorcelainZ(stdout: string): string[] {
  if (!stdout) return [];
  const tokens = stdout.split('\0').filter((token) => token.length > 0);
  const paths: string[] = [];
  for (let i = 0; i < tokens.length; i += 1) {
    const entry = tokens[i];
    if (entry.length < 4) continue;
    const status = entry.slice(0, 2);
    paths.push(entry.slice(3));
    if (status[0] === 'R' || status[0] === 'C' || status[1] === 'R' || status[1] === 'C') {
      i += 1;
    }
  }
  return paths;
}

function readGitBranch(root: string): string {
  const sym = runGit(root, ['symbolic-ref', '--short', 'HEAD']);
  if (sym.status === 0 && sym.stdout.trim()) return sym.stdout.trim();
  const rev = runGit(root, ['rev-parse', '--short', 'HEAD']);
  if (rev.status === 0 && rev.stdout.trim()) return rev.stdout.trim();
  return 'HEAD';
}

function safeJsonParse<T>(text: string): T | null {
  const trimmed = text.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
  try {
    return JSON.parse(trimmed) as T;
  } catch {
    return null;
  }
}

function readStrictJsonFile<T>(filePath: string, label: string): T {
  assertNotSymlink(filePath, label);
  const raw = readFileSync(filePath, 'utf8');
  try {
    return JSON.parse(raw) as T;
  } catch (err) {
    throw new PreviewFatalError(2, `malformed JSON in ${filePath}: ${(err as Error).message}`);
  }
}

function isPidAlive(pid: number): boolean {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return (err as NodeJS.ErrnoException).code === 'EPERM';
  }
}

interface PortProbeOutcome {
  occupied: boolean;
  unreadable?: string;
}

function probeHostBindOccupied(port: number, host: string): Promise<PortProbeOutcome> {
  return new Promise((resolvePromise) => {
    let settled = false;
    const srv = createServer();
    const finish = (outcome: PortProbeOutcome): void => {
      if (settled) return;
      settled = true;
      resolvePromise(outcome);
    };
    srv.once('error', (err) => {
      const code = (err as NodeJS.ErrnoException).code;
      if (code === 'EADDRINUSE') {
        finish({ occupied: true });
        return;
      }
      if (code === 'EADDRNOTAVAIL' || code === 'EAFNOSUPPORT') {
        finish({ occupied: false });
        return;
      }
      if (code === 'EACCES' || code === 'EPERM') {
        finish({ occupied: false, unreadable: `loopback probe on ${host}:${port} denied (${code})` });
        return;
      }
      finish({ occupied: false });
    });
    srv.listen({ port, host, exclusive: true }, () => {
      srv.close(() => finish({ occupied: false }));
    });
  });
}

function probeHostConnectOccupied(port: number, host: string): Promise<PortProbeOutcome> {
  return new Promise((resolvePromise) => {
    let settled = false;
    const socket = createConnection({ host, port });
    const finish = (outcome: PortProbeOutcome): void => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolvePromise(outcome);
    };
    socket.setTimeout(PORT_PROBE_TIMEOUT_MS);
    socket.once('connect', () => finish({ occupied: true }));
    socket.once('timeout', () => finish({ occupied: false }));
    socket.once('error', (err) => {
      const code = (err as NodeJS.ErrnoException).code;
      if (code === 'EADDRNOTAVAIL' || code === 'EAFNOSUPPORT' || code === 'ECONNREFUSED') {
        finish({ occupied: false });
        return;
      }
      if (code === 'EPERM' || code === 'EACCES') {
        if (settled) return;
        settled = true;
        socket.destroy();
        void probeHostBindOccupied(port, host).then(resolvePromise);
        return;
      }
      finish({ occupied: false });
    });
  });
}

async function probeTcpPortOccupied(port: number): Promise<PortProbeOutcome> {
  for (const host of ['127.0.0.1', '::1']) {
    const outcome = await probeHostConnectOccupied(port, host);
    if (outcome.occupied || outcome.unreadable) return outcome;
  }
  return { occupied: false };
}

function sleepSync(ms: number): void {
  const view = new Int32Array(new SharedArrayBuffer(4));
  Atomics.wait(view, 0, 0, ms);
}

function ensureRealDir(dirPath: string, label: string): void {
  assertNotSymlink(dirPath, label);
  const st = lstatOrNull(dirPath);
  if (!st) {
    mkdirSync(dirPath, { recursive: true });
    return;
  }
  if (!st.isDirectory()) {
    throw new PreviewFatalError(2, `${label} is not a directory: ${dirPath}`);
  }
}

function isValidSessionEntry(item: unknown): item is SessionEntry {
  if (!item || typeof item !== 'object') return false;
  const candidate = item as Record<string, unknown>;
  return (
    typeof candidate.id === 'string' &&
    candidate.id.length > 0 &&
    typeof candidate.pid === 'number' &&
    Number.isInteger(candidate.pid) &&
    candidate.pid > 0 &&
    typeof candidate.checkout === 'string' &&
    typeof candidate.branch === 'string' &&
    typeof candidate.target === 'string' &&
    (candidate.verb === 'dev' || candidate.verb === 'run') &&
    typeof candidate.lane === 'string' &&
    Array.isArray(candidate.resources) &&
    candidate.resources.every((r) => typeof r === 'string')
  );
}

function readLockOwner(lockDir: string): LockOwner | null {
  try {
    const ownerFile = join(lockDir, 'owner.json');
    const st = lstatOrNull(ownerFile);
    if (!st || st.isSymbolicLink() || !st.isFile()) return null;
    const parsed = safeJsonParse<Partial<LockOwner>>(readFileSync(ownerFile, 'utf8'));
    if (
      !parsed ||
      typeof parsed.token !== 'string' ||
      typeof parsed.pid !== 'number' ||
      typeof parsed.createdAt !== 'number'
    ) {
      return null;
    }
    return { token: parsed.token, pid: parsed.pid, createdAt: parsed.createdAt };
  } catch {
    return null;
  }
}

function tryReclaimStaleLock(lockDir: string): boolean {
  let st;
  try {
    st = lstatSync(lockDir);
  } catch {
    return false;
  }
  if (st.isSymbolicLink()) {
    throw new PreviewFatalError(2, `refusing symlinked amaterasu lock: ${lockDir}`);
  }
  if (!st.isDirectory()) {
    throw new PreviewFatalError(2, `amaterasu lock path is not a directory: ${lockDir}`);
  }
  const ageMs = Date.now() - st.mtimeMs;
  const owner = readLockOwner(lockDir);
  const deadOwner = owner !== null && !isPidAlive(owner.pid);
  const expiredUnowned = owner === null && ageMs > LOCK_OWNER_GRACE_MS;
  const expiredAge = ageMs > LOCK_STALE_MS;
  if (!deadOwner && !expiredUnowned && !expiredAge) {
    return false;
  }
  const reclaimed = `${lockDir}.reclaim.${process.pid}.${randomUUID()}`;
  try {
    renameSync(lockDir, reclaimed);
  } catch {
    return false;
  }
  rmSync(reclaimed, { recursive: true, force: true });
  return true;
}

function withSessionLedger<T>(
  commonDir: string,
  fn: (sessions: SessionEntry[]) => { changed: boolean; next: SessionEntry[]; result: T },
): T {
  const nenDir = join(commonDir, '.nen');
  const amaDir = join(nenDir, 'amaterasu');
  ensureRealDir(nenDir, '.nen directory');
  ensureRealDir(amaDir, 'amaterasu state directory');

  const ledgerPath = join(amaDir, 'sessions.json');
  assertNotSymlink(ledgerPath, 'sessions.json');
  const initialLedgerStat = lstatOrNull(ledgerPath);
  if (initialLedgerStat && !initialLedgerStat.isFile()) {
    throw new PreviewFatalError(2, `sessions.json is not a regular file: ${ledgerPath}`);
  }

  const lockDir = `${ledgerPath}.lock`;
  assertNotSymlink(lockDir, 'sessions.json.lock');
  const lockToken = randomUUID();
  const deadline = performance.now() + LOCK_WAIT_MS;

  while (true) {
    try {
      assertNotSymlink(lockDir, 'sessions.json.lock');
      mkdirSync(lockDir);
      const ownerPath = join(lockDir, 'owner.json');
      const tmpOwner = join(amaDir, `.owner.${process.pid}.${randomUUID()}.tmp`);
      writeFileSync(
        tmpOwner,
        `${JSON.stringify({ token: lockToken, pid: process.pid, createdAt: Date.now() })}\n`,
        'utf8',
      );
      renameSync(tmpOwner, ownerPath);
      break;
    } catch (err) {
      if (err instanceof PreviewFatalError) throw err;
      const code = (err as NodeJS.ErrnoException).code;
      if (code === 'ENOENT' || code === 'ENOTDIR') {
        if (performance.now() > deadline) {
          throw new PreviewFatalError(2, `timed out waiting for amaterasu session lock at ${lockDir}`);
        }
        sleepSync(10);
        continue;
      }
      if (code !== 'EEXIST') {
        throw new PreviewFatalError(2, `failed to acquire amaterasu session lock at ${lockDir}: ${String(err)}`);
      }
      if (tryReclaimStaleLock(lockDir)) {
        if (performance.now() > deadline) {
          throw new PreviewFatalError(2, `timed out waiting for amaterasu session lock at ${lockDir}`);
        }
        sleepSync(10);
        continue;
      }
      if (performance.now() > deadline) {
        throw new PreviewFatalError(2, `timed out waiting for amaterasu session lock at ${lockDir}`);
      }
      sleepSync(20);
    }
  }

  try {
    let rawSessions: SessionEntry[] = [];
    let pruned = false;
    assertNotSymlink(ledgerPath, 'sessions.json');
    if (lstatOrNull(ledgerPath)) {
      const parsed = readStrictJsonFile<unknown>(ledgerPath, 'sessions.json');
      if (!Array.isArray(parsed) || !parsed.every(isValidSessionEntry)) {
        throw new PreviewFatalError(2, `invalid schema in ${ledgerPath}: expected valid SessionEntry[]`);
      }
      rawSessions = parsed.filter((item) => isPidAlive(item.pid));
      pruned = rawSessions.length !== parsed.length;
    }
    const { changed, next, result } = fn(rawSessions);
    if (changed || pruned) {
      const tmp = join(amaDir, `sessions.${process.pid}.${randomUUID()}.tmp`);
      writeFileSync(tmp, `${JSON.stringify(next, null, 2)}\n`, 'utf8');
      renameSync(tmp, ledgerPath);
    }
    return result;
  } finally {
    try {
      const currentOwner = readLockOwner(lockDir);
      if (currentOwner?.token === lockToken) {
        rmSync(lockDir, { recursive: true, force: true });
      }
    } catch {
      // Never throw over primary outcome while checking lock cleanup.
    }
  }
}

function resolveCommonDir(selectedRoot: string): string {
  const commonRes = runGit(selectedRoot, ['rev-parse', '--git-common-dir']);
  if (commonRes.status !== 0) {
    throw new PreviewFatalError(2, `could not resolve git common dir for ${selectedRoot}: ${commonRes.stderr.trim()}`);
  }
  const raw = commonRes.stdout.trim();
  const abs = isAbsolute(raw) ? raw : resolve(selectedRoot, raw);
  const resolved = safeRealpath(abs);
  if (!resolved) {
    throw new PreviewFatalError(2, `git common dir does not exist: ${abs}`);
  }
  return resolved;
}

function readContractAndWorkflow(checkoutRoot: string): {
  contract: LaunchContract;
  workflowDefaultTarget: string | null;
  workflowFallbackTarget: string | null;
} {
  const contractPath = join(checkoutRoot, 'nen', 'contract.json');
  if (!lstatOrNull(contractPath)) {
    throw new PreviewFatalError(2, `missing declaration: ${contractPath}`);
  }
  const contract = readStrictJsonFile<LaunchContract>(contractPath, 'nen/contract.json');

  let workflowDefaultTarget: string | null = null;
  let workflowFallbackTarget: string | null = null;
  const workflowPath = join(checkoutRoot, 'nen', 'workflow.json');
  if (lstatOrNull(workflowPath)) {
    const wf = readStrictJsonFile<WorkflowLaunchConfig>(workflowPath, 'nen/workflow.json');
    if (wf?.launch && typeof wf.launch.default === 'string' && wf.launch.default.length > 0) {
      workflowDefaultTarget = wf.launch.default;
    }
    if (wf?.launch && typeof wf.launch.fallback === 'string' && wf.launch.fallback.length > 0) {
      workflowFallbackTarget = wf.launch.fallback;
    }
  }
  return { contract, workflowDefaultTarget, workflowFallbackTarget };
}

function extractDeviceName(targetSpec: LaunchTargetSpec, dryJson: DryRunJson | null): string | null {
  const fromDry = dryJson?.target?.device;
  if (typeof fromDry === 'string' && fromDry.trim()) return fromDry.trim();
  if (fromDry && typeof fromDry === 'object' && typeof fromDry.name === 'string' && fromDry.name.trim()) {
    return fromDry.name.trim();
  }
  const fromSpec = targetSpec.device;
  if (typeof fromSpec === 'string' && fromSpec.trim()) return fromSpec.trim();
  if (fromSpec && typeof fromSpec === 'object' && typeof fromSpec.name === 'string' && fromSpec.name.trim()) {
    return fromSpec.name.trim();
  }
  return null;
}

function buildResourceKeys(
  coreRoot: string,
  lane: string,
  targetName: string,
  verb: 'dev' | 'run',
  ports: number[],
  deviceName: string | null,
): string[] {
  const keys = new Set<string>();
  for (const port of ports) keys.add(`port:${port}`);
  if (deviceName) keys.add(`device:${deviceName}`);
  if (verb === 'dev' && keys.size === 0) {
    keys.add(`dev-session:${coreRoot}:${lane}:${targetName}`);
  }
  return [...keys];
}

function collectDeclaredFreePorts(
  contract: LaunchContract,
  lane: string,
  dryJson: DryRunJson | null,
): { ports: number[]; invalidPort: string | null } {
  const ports = new Set<number>();
  let invalidPort: string | null = null;
  const checkList = (items?: ContractPrecondition[]): void => {
    for (const item of items ?? []) {
      if (item?.kind !== 'port' || item?.expect !== 'free') continue;
      if (typeof item.value !== 'number' || !Number.isInteger(item.value) || item.value < 1 || item.value > 65535) {
        if (!invalidPort) invalidPort = `invalid free-port precondition value '${String(item.value)}' (expected integer 1..65535)`;
        continue;
      }
      ports.add(item.value);
    }
  };
  const preconditionsMap = contract.project?.preconditions;
  if (preconditionsMap && Object.hasOwn(preconditionsMap, lane)) {
    checkList(preconditionsMap[lane]);
  }
  checkList(dryJson?.preconditions);
  return { ports: [...ports], invalidPort };
}

function extractSteps(dryJson: DryRunJson | null, fallbackCwd: string): StepCommand[] {
  return (dryJson?.steps ?? []).map((step) => {
    const exe = step.exe ?? '';
    const argv = Array.isArray(step.argv) ? step.argv.map(String) : [];
    const cwd = step.cwd ? String(step.cwd) : fallbackCwd;
    return {
      exe,
      argv,
      cwd,
      formatted: formatCommand(exe, argv),
    };
  });
}

function looksLikeDisconnectedDeviceRefusal(stderr: string, stdout: string, targetSpec: LaunchTargetSpec): boolean {
  if (!targetSpec.device) return false;
  const combined = `${stderr}\n${stdout}`.toLowerCase();
  if (
    combined.includes('readywhen') ||
    combined.includes('could not be started') ||
    combined.includes('command not found') ||
    combined.includes('not executable') ||
    combined.includes('on path')
  ) {
    return false;
  }
  return (
    combined.includes('not among the probe') ||
    combined.includes('no device') ||
    combined.includes('not connected') ||
    combined.includes('did not match') ||
    combined.includes('no matching') ||
    /\bdevice\b[^\n]*(?:not found|absent)/.test(combined)
  );
}

function spawnNenAsync(
  nenBin: string,
  args: string[],
  streamToTerminal: boolean,
  onSpawned: (pid: number) => void,
): Promise<{ status: number | null; signal: NodeJS.Signals | null; stdout: string; stderr: string }> {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(nenBin, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];
    if (typeof child.pid === 'number') {
      onSpawned(child.pid);
    }
    const forwardSigint = (): void => {
      if (typeof child.pid === 'number') child.kill('SIGINT');
    };
    const forwardSigterm = (): void => {
      if (typeof child.pid === 'number') child.kill('SIGTERM');
    };
    process.on('SIGINT', forwardSigint);
    process.on('SIGTERM', forwardSigterm);
    child.stdout.on('data', (chunk: Buffer) => {
      stdoutChunks.push(chunk);
      if (streamToTerminal) process.stdout.write(sanitizeTerminal(chunk.toString('utf8')));
    });
    child.stderr.on('data', (chunk: Buffer) => {
      stderrChunks.push(chunk);
      if (streamToTerminal) process.stderr.write(sanitizeTerminal(chunk.toString('utf8')));
    });
    child.once('error', (err) => {
      process.off('SIGINT', forwardSigint);
      process.off('SIGTERM', forwardSigterm);
      rejectPromise(err);
    });
    child.once('close', (code, signal) => {
      process.off('SIGINT', forwardSigint);
      process.off('SIGTERM', forwardSigterm);
      resolvePromise({
        status: code,
        signal,
        stdout: Buffer.concat(stdoutChunks).toString('utf8'),
        stderr: Buffer.concat(stderrChunks).toString('utf8'),
      });
    });
  });
}

function baseResult(fields: Partial<PreviewResult>): PreviewResult {
  return {
    contract: 'hatsu.amaterasu-preview/v0.1',
    status: 'error',
    executed: false,
    deferred: false,
    dryRun: false,
    checkout: '',
    branch: '',
    uncommittedPaths: [],
    coreCheckout: '',
    coreBranch: '',
    coreSwaps: 0,
    target: null,
    lane: null,
    verb: null,
    command: null,
    steps: [],
    conflicts: [],
    stdout: '',
    stderr: '',
    ...fields,
  };
}

function formatConflictMessage(conflicts: ConflictDetail[]): string {
  const details = conflicts
    .map((conflict) => {
      if (conflict.holder) {
        return `${conflict.resource} (${conflict.reason}; held by pid ${conflict.holder.pid} from ${conflict.holder.checkout} [${conflict.holder.target}])`;
      }
      return `${conflict.resource} (${conflict.reason})`;
    })
    .join('; ');
  return `resource conflict — occupied: ${details}. Refusing launch and leaving existing session intact.`;
}

async function runAmaterasuPreviewInner(opts: PreviewOptions): Promise<{ exitCode: number; output: PreviewResult }> {
  const candidate = resolve(opts.repo);
  if (!existsSync(candidate)) {
    return {
      exitCode: 2,
      output: baseResult({ error: `checkout path does not exist: ${candidate}` }),
    };
  }
  const topRes = runGit(candidate, ['rev-parse', '--show-toplevel']);
  if (topRes.status !== 0 || !topRes.stdout.trim()) {
    return {
      exitCode: 2,
      output: baseResult({ error: `not a git checkout: ${candidate}` }),
    };
  }
  const selectedRoot = safeRealpath(topRes.stdout.trim());
  if (!selectedRoot) {
    return {
      exitCode: 2,
      output: baseResult({ error: `could not resolve checkout root: ${topRes.stdout.trim()}` }),
    };
  }
  const branch = readGitBranch(selectedRoot);
  const statusRes = runGit(selectedRoot, ['status', '--porcelain=v1', '-z']);
  const uncommittedPaths = statusRes.status === 0 ? parsePorcelainZ(statusRes.stdout) : [];

  const wtRes = runNenSync(opts.nen, ['wc', 'worktrees', '--repo', selectedRoot, '--json']);
  const wtJson = wtRes.status === 0 ? safeJsonParse<WorktreesJson>(wtRes.stdout) : null;
  const coreRoot = wtJson?.core ? safeRealpath(wtJson.core) : null;
  if (wtRes.status !== 0 || !coreRoot) {
    return {
      exitCode: 2,
      output: baseResult({
        checkout: selectedRoot,
        branch,
        uncommittedPaths,
        error: `could not resolve core checkout through nen wc worktrees: ${wtRes.stderr.trim() || wtRes.stdout.trim()}`,
      }),
    };
  }
  const isWorktree = selectedRoot !== coreRoot;
  const coreEntry = wtJson?.worktrees?.find((w) => (w.path ? safeRealpath(w.path) === coreRoot : false));
  const coreBranch = coreEntry?.branch || readGitBranch(coreRoot);

  let contract: LaunchContract;
  let workflowDefaultTarget: string | null;
  let workflowFallbackTarget: string | null;
  try {
    ({ contract, workflowDefaultTarget, workflowFallbackTarget } = readContractAndWorkflow(selectedRoot));
  } catch (err) {
    const code = err instanceof PreviewFatalError ? err.exitCode : 2;
    return {
      exitCode: code,
      output: baseResult({
        checkout: selectedRoot,
        branch,
        uncommittedPaths,
        coreCheckout: coreRoot,
        coreBranch,
        error: (err as Error).message,
      }),
    };
  }

  const launchMap = contract.project?.launch;
  const declaredTargets = launchMap ? Object.keys(launchMap) : [];
  if (declaredTargets.length === 0) {
    return {
      exitCode: 0,
      output: baseResult({
        status: 'no launch target declared; skipped',
        dryRun: opts.dryRun,
        checkout: selectedRoot,
        branch,
        uncommittedPaths,
        coreCheckout: coreRoot,
        coreBranch,
      }),
    };
  }

  let targetName = opts.target ?? workflowDefaultTarget;
  if (!targetName) {
    return {
      exitCode: 2,
      output: baseResult({
        checkout: selectedRoot,
        branch,
        uncommittedPaths,
        coreCheckout: coreRoot,
        coreBranch,
        error: `no target selected and workflow launch.default is null; pass --target <name> (declared: ${declaredTargets.join(', ')})`,
      }),
    };
  }
  if (!launchMap || !Object.hasOwn(launchMap, targetName)) {
    return {
      exitCode: 2,
      output: baseResult({
        checkout: selectedRoot,
        branch,
        uncommittedPaths,
        coreCheckout: coreRoot,
        coreBranch,
        target: targetName,
        error: `undeclared launch target '${targetName}' in ${selectedRoot} (declared: ${declaredTargets.join(', ')})`,
      }),
    };
  }

  let targetSpec = launchMap[targetName];
  if (typeof targetSpec.unsupported === 'string' && targetSpec.unsupported.trim()) {
    return {
      exitCode: 4,
      output: baseResult({
        checkout: selectedRoot,
        branch,
        uncommittedPaths,
        coreCheckout: coreRoot,
        coreBranch,
        target: targetName,
        error: `launch target '${targetName}' is unsupported: ${targetSpec.unsupported.trim()}`,
      }),
    };
  }
  let lane = targetSpec.lane || contract.project?.defaultLane || null;
  if (targetSpec.verb !== 'dev' && targetSpec.verb !== 'run') {
    return {
      exitCode: 2,
      output: baseResult({
        checkout: selectedRoot,
        branch,
        uncommittedPaths,
        coreCheckout: coreRoot,
        coreBranch,
        target: targetName,
        lane,
        error: `launch target '${targetName}' declares unsupported verb '${String(targetSpec.verb)}' (expected dev or run)`,
      }),
    };
  }
  let verb: 'dev' | 'run' = targetSpec.verb;

  // Preserve § 3 automatic ren deferral when invoked automatically inside a worktree.
  if (opts.automatic && isWorktree) {
    const coreContractPath = join(coreRoot, 'nen', 'contract.json');
    let coreTargetSpec: LaunchTargetSpec | undefined;
    if (lstatOrNull(coreContractPath)) {
      const coreContract = readStrictJsonFile<LaunchContract>(coreContractPath, 'core nen/contract.json');
      const coreLaunch = coreContract.project?.launch;
      if (coreLaunch && Object.hasOwn(coreLaunch, targetName)) {
        coreTargetSpec = coreLaunch[targetName];
      }
    }
    let coreCommand: string | null = null;
    let coreSteps: StepCommand[] = [];
    let coreStderr = '';
    if (coreTargetSpec && (coreTargetSpec.verb === 'dev' || coreTargetSpec.verb === 'run')) {
      const coreArgs = ['shu', coreTargetSpec.verb, '--repo', coreRoot, '--target', targetName, '--dry-run'];
      coreCommand = formatCommand(opts.nen, coreArgs);
      const dryCore = runNenSync(opts.nen, [...coreArgs, '--json']);
      const dryCoreJson = safeJsonParse<DryRunJson>(dryCore.stdout);
      coreSteps = extractSteps(dryCoreJson, coreRoot);
      coreStderr = dryCore.stderr.trim();
    } else {
      coreStderr = `core checkout ${coreRoot} does not declare launch target '${targetName}'`;
    }
    return {
      exitCode: 0,
      output: baseResult({
        status: 'core launch deferred; explicit maintainer call required',
        executed: false,
        deferred: true,
        dryRun: true,
        checkout: coreRoot,
        branch: coreBranch,
        uncommittedPaths,
        coreCheckout: coreRoot,
        coreBranch,
        target: targetName,
        lane,
        verb,
        command: coreCommand,
        steps: coreSteps,
        stderr: coreStderr,
      }),
    };
  }

  let fallbackFrom: string | undefined;
  let fallbackDiagnostic = '';

  for (let attempt = 0; attempt < 2; attempt += 1) {
    targetSpec = launchMap[targetName];
    if (typeof targetSpec.unsupported === 'string' && targetSpec.unsupported.trim()) {
      return {
        exitCode: 4,
        output: baseResult({
          checkout: selectedRoot,
          branch,
          uncommittedPaths,
          coreCheckout: coreRoot,
          coreBranch,
          target: targetName,
          fallbackFrom,
          error: `launch target '${targetName}' is unsupported: ${targetSpec.unsupported.trim()}`,
        }),
      };
    }
    lane = targetSpec.lane || contract.project?.defaultLane || null;
    if (targetSpec.verb !== 'dev' && targetSpec.verb !== 'run') {
      return {
        exitCode: 2,
        output: baseResult({
          checkout: selectedRoot,
          branch,
          uncommittedPaths,
          coreCheckout: coreRoot,
          coreBranch,
          target: targetName,
          lane,
          fallbackFrom,
          error: `launch target '${targetName}' declares unsupported verb '${String(targetSpec.verb)}' (expected dev or run)`,
        }),
      };
    }
    verb = targetSpec.verb;

    const canFallbackToTarget = (): boolean =>
      attempt === 0 &&
      !opts.dryRun &&
      !opts.target &&
      Boolean(workflowFallbackTarget) &&
      workflowFallbackTarget !== targetName &&
      Object.hasOwn(launchMap, workflowFallbackTarget!);

    const dryRes = runNenSync(opts.nen, ['shu', verb, '--repo', selectedRoot, '--target', targetName, '--dry-run', '--json']);
    if (dryRes.status === 5 && canFallbackToTarget() && looksLikeDisconnectedDeviceRefusal(dryRes.stderr, dryRes.stdout, targetSpec)) {
      fallbackDiagnostic = dryRes.stderr.trim() || dryRes.stdout.trim();
      fallbackFrom = targetName;
      targetName = workflowFallbackTarget!;
      continue;
    }

    const dryJson = safeJsonParse<DryRunJson>(dryRes.stdout);
    const steps = extractSteps(dryJson, selectedRoot);
    const resolvedLane = dryJson?.lane || lane || 'default';
    const liveArgs = ['shu', verb, '--repo', selectedRoot, '--target', targetName];
    const verbatimCommand = formatCommand(opts.nen, liveArgs);

    // Separate port precondition conflicts from non-resource errors and preserve nen exits 3/4/5.
    const portConflicts: ConflictDetail[] = [];
    let hasNonPortPreconditionFailure = false;
    for (const pre of dryJson?.preconditions ?? []) {
      if (pre.satisfied !== false) continue;
      if (pre.kind === 'port') {
        portConflicts.push({
          resource: `port ${String(pre.value)}`,
          reason: `precondition expect '${String(pre.expect ?? 'free')}' not satisfied`,
        });
      } else {
        hasNonPortPreconditionFailure = true;
      }
    }

    // Under --dry-run, render plan cleanly even if runtime ports are busy, while still preserving structural/host/seat refusals.
    if (opts.dryRun) {
      const onlyBusyPortPlan =
        dryRes.status === 2 && portConflicts.length > 0 && !hasNonPortPreconditionFailure && steps.length > 0;
      if (dryRes.status === 0 || onlyBusyPortPlan) {
        return {
          exitCode: 0,
          output: baseResult({
            status: 'dry-run plan ready',
            executed: false,
            dryRun: true,
            checkout: selectedRoot,
            branch,
            uncommittedPaths,
            coreCheckout: coreRoot,
            coreBranch,
            target: targetName,
            lane: resolvedLane,
            verb,
            command: verbatimCommand,
            steps,
            fallbackFrom,
            stdout: dryRes.stdout,
            stderr: dryRes.stderr.trim(),
          }),
        };
      }
      return {
        exitCode: dryRes.status,
        output: baseResult({
          status: 'error',
          executed: false,
          dryRun: true,
          checkout: selectedRoot,
          branch,
          uncommittedPaths,
          coreCheckout: coreRoot,
          coreBranch,
          target: targetName,
          lane: resolvedLane,
          verb,
          command: verbatimCommand,
          steps,
          fallbackFrom,
          stdout: dryRes.stdout,
          stderr: dryRes.stderr.trim(),
          error: dryRes.stderr.trim() || dryRes.stdout.trim() || `nen shu ${verb} --dry-run failed with exit ${dryRes.status}`,
        }),
      };
    }

    if (portConflicts.length > 0) {
      return {
        exitCode: 2,
        output: baseResult({
          status: 'resource conflict',
          executed: false,
          dryRun: false,
          checkout: selectedRoot,
          branch,
          uncommittedPaths,
          coreCheckout: coreRoot,
          coreBranch,
          target: targetName,
          lane: resolvedLane,
          verb,
          command: verbatimCommand,
          steps,
          conflicts: portConflicts,
          fallbackFrom,
          stdout: dryRes.stdout,
          stderr: dryRes.stderr.trim(),
          error: formatConflictMessage(portConflicts),
        }),
      };
    }

    if (dryRes.status !== 0) {
      return {
        exitCode: dryRes.status,
        output: baseResult({
          status: 'error',
          executed: false,
          dryRun: false,
          checkout: selectedRoot,
          branch,
          uncommittedPaths,
          coreCheckout: coreRoot,
          coreBranch,
          target: targetName,
          lane: resolvedLane,
          verb,
          command: verbatimCommand,
          steps,
          fallbackFrom,
          stdout: dryRes.stdout,
          stderr: dryRes.stderr.trim(),
          error: dryRes.stderr.trim() || dryRes.stdout.trim() || `nen shu ${verb} --dry-run failed with exit ${dryRes.status}`,
        }),
      };
    }

    // Amaterasu § 3: check swap status before launching when running in core checkout.
    let coreSwapStatus: string | undefined;
    if (!isWorktree) {
      const swapRes = runNenSync(opts.nen, ['wc', 'swap', '--status', '--repo', coreRoot]);
      if (swapRes.status !== 0) {
        return {
          exitCode: 2,
          output: baseResult({
            status: 'error',
            executed: false,
            dryRun: false,
            checkout: selectedRoot,
            branch,
            uncommittedPaths,
            coreCheckout: coreRoot,
            coreBranch,
            target: targetName,
            lane: resolvedLane,
            verb,
            command: verbatimCommand,
            steps,
            fallbackFrom,
            stdout: swapRes.stdout,
            stderr: swapRes.stderr.trim(),
            error: `core swap status check refused (exit ${swapRes.status}): ${swapRes.stderr.trim() || swapRes.stdout.trim()}`,
          }),
        };
      }
      coreSwapStatus = swapRes.stdout.trim() || undefined;
    }

    const { ports: declaredPorts, invalidPort } = collectDeclaredFreePorts(contract, resolvedLane, dryJson);
    if (invalidPort) {
      return {
        exitCode: 2,
        output: baseResult({
          status: 'error',
          executed: false,
          dryRun: false,
          checkout: selectedRoot,
          branch,
          uncommittedPaths,
          coreCheckout: coreRoot,
          coreBranch,
          target: targetName,
          lane: resolvedLane,
          verb,
          command: verbatimCommand,
          steps,
          fallbackFrom,
          error: invalidPort,
        }),
      };
    }

    const conflicts: ConflictDetail[] = [];
    for (const port of declaredPorts) {
      const probe = await probeTcpPortOccupied(port);
      if (probe.unreadable) {
        return {
          exitCode: 2,
          output: baseResult({
            status: 'error',
            executed: false,
            dryRun: false,
            checkout: selectedRoot,
            branch,
            uncommittedPaths,
            coreCheckout: coreRoot,
            coreBranch,
            target: targetName,
            lane: resolvedLane,
            verb,
            command: verbatimCommand,
            steps,
            fallbackFrom,
            error: probe.unreadable,
          }),
        };
      }
      if (probe.occupied) {
        conflicts.push({
          resource: `port ${port}`,
          reason: 'TCP listener already accepting connections on loopback',
        });
      }
    }

    const deviceName = extractDeviceName(targetSpec, dryJson);
    const resourceKeys = buildResourceKeys(coreRoot, resolvedLane, targetName, verb, declaredPorts, deviceName);
    const commonDir = resolveCommonDir(selectedRoot);

    const checkSessionConflicts = (sessions: SessionEntry[]): ConflictDetail[] => {
      const found: ConflictDetail[] = [];
      for (const key of resourceKeys) {
        const holder = sessions.find((s) => s.resources.includes(key));
        if (holder) {
          const label = key.startsWith('port:')
            ? `port ${key.slice(5)}`
            : key.startsWith('device:')
              ? `device ${key.slice(7)}`
              : `session ${targetName}`;
          found.push({
            resource: label,
            reason: 'active preview session holds resource',
            holder: {
              pid: holder.pid,
              checkout: holder.checkout,
              target: holder.target,
              branch: holder.branch,
            },
          });
        }
      }
      return found;
    };

    if (conflicts.length > 0) {
      return {
        exitCode: 2,
        output: baseResult({
          status: 'resource conflict',
          executed: false,
          dryRun: false,
          checkout: selectedRoot,
          branch,
          uncommittedPaths,
          coreCheckout: coreRoot,
          coreBranch,
          target: targetName,
          lane: resolvedLane,
          verb,
          command: verbatimCommand,
          steps,
          conflicts,
          fallbackFrom,
          error: formatConflictMessage(conflicts),
        }),
      };
    }

    const leaseId = randomUUID();
    const acquireConflict = withSessionLedger<ConflictDetail[]>(commonDir, (sessions) => {
      const existing = checkSessionConflicts(sessions);
      if (existing.length > 0) {
        return { changed: false, next: sessions, result: existing };
      }
      const next: SessionEntry[] = [
        ...sessions,
        {
          id: leaseId,
          pid: process.pid,
          checkout: selectedRoot,
          branch,
          target: targetName,
          verb,
          lane: resolvedLane,
          resources: resourceKeys,
          startedAt: new Date().toISOString(),
        },
      ];
      return { changed: true, next, result: [] };
    });

    if (acquireConflict.length > 0) {
      return {
        exitCode: 2,
        output: baseResult({
          status: 'resource conflict',
          executed: false,
          dryRun: false,
          checkout: selectedRoot,
          branch,
          uncommittedPaths,
          coreCheckout: coreRoot,
          coreBranch,
          target: targetName,
          lane: resolvedLane,
          verb,
          command: verbatimCommand,
          steps,
          conflicts: acquireConflict,
          fallbackFrom,
          error: formatConflictMessage(acquireConflict),
        }),
      };
    }

    const streamHuman = !opts.json && !opts.quiet;
    if (streamHuman) {
      console.log(
        sanitizeTerminal(
          `amaterasu-preview: launching\ncheckout: ${selectedRoot} (${branch})\ntarget: ${targetName} (${verb} on ${resolvedLane})\ncommand: ${verbatimCommand}`,
        ),
      );
    }

    let runRes: { status: number | null; signal: NodeJS.Signals | null; stdout: string; stderr: string };
    try {
      runRes = await spawnNenAsync(opts.nen, liveArgs, streamHuman, (childPid) => {
        withSessionLedger(commonDir, (sessions) => ({
          changed: true,
          next: sessions.map((s) => (s.id === leaseId ? { ...s, pid: childPid } : s)),
          result: undefined,
        }));
      });
    } finally {
      withSessionLedger(commonDir, (sessions) => {
        const filtered = sessions.filter((s) => s.id !== leaseId);
        return { changed: filtered.length !== sessions.length, next: filtered, result: undefined };
      });
    }

    if (
      runRes.status === 5 &&
      canFallbackToTarget() &&
      looksLikeDisconnectedDeviceRefusal(runRes.stderr, runRes.stdout, targetSpec)
    ) {
      fallbackDiagnostic = runRes.stderr.trim() || runRes.stdout.trim();
      fallbackFrom = targetName;
      targetName = workflowFallbackTarget!;
      continue;
    }

    if (runRes.signal) {
      const signalExit = runRes.signal === 'SIGINT' ? 130 : runRes.signal === 'SIGTERM' ? 143 : 1;
      return {
        exitCode: signalExit,
        output: baseResult({
          status: 'preview interrupted',
          executed: true,
          dryRun: false,
          checkout: selectedRoot,
          branch,
          uncommittedPaths,
          coreCheckout: coreRoot,
          coreBranch,
          target: targetName,
          lane: resolvedLane,
          verb,
          command: verbatimCommand,
          steps,
          fallbackFrom,
          stdout: runRes.stdout,
          stderr: [fallbackDiagnostic, runRes.stderr.trim()].filter(Boolean).join('\n'),
          error: `preview interrupted by signal ${runRes.signal}`,
        }),
      };
    }

    if (runRes.status !== 0) {
      return {
        exitCode: runRes.status ?? 1,
        output: baseResult({
          status: 'launch failed',
          executed: true,
          dryRun: false,
          checkout: selectedRoot,
          branch,
          uncommittedPaths,
          coreCheckout: coreRoot,
          coreBranch,
          target: targetName,
          lane: resolvedLane,
          verb,
          command: verbatimCommand,
          steps,
          fallbackFrom,
          stdout: runRes.stdout,
          stderr: [fallbackDiagnostic, runRes.stderr.trim()].filter(Boolean).join('\n'),
          error: runRes.stderr.trim() || runRes.stdout.trim() || `launch exited with code ${runRes.status}`,
        }),
      };
    }

    return {
      exitCode: 0,
      output: baseResult({
        status: 'preview launched',
        executed: true,
        dryRun: false,
        checkout: selectedRoot,
        branch,
        uncommittedPaths,
        coreCheckout: coreRoot,
        coreBranch,
        target: targetName,
        lane: resolvedLane,
        verb,
        command: verbatimCommand,
        steps,
        fallbackFrom,
        coreSwapStatus,
        stdout: runRes.stdout,
        stderr: [fallbackDiagnostic, runRes.stderr.trim()].filter(Boolean).join('\n'),
      }),
    };
  }

  return {
    exitCode: 2,
    output: baseResult({
      checkout: selectedRoot,
      branch,
      uncommittedPaths,
      coreCheckout: coreRoot,
      coreBranch,
      target: targetName,
      fallbackFrom,
      error: fallbackDiagnostic || 'fallback launch did not complete',
    }),
  };
}

export async function runAmaterasuPreview(opts: PreviewOptions): Promise<{ exitCode: number; output: PreviewResult }> {
  try {
    return await runAmaterasuPreviewInner(opts);
  } catch (err) {
    const exitCode = err instanceof PreviewFatalError ? err.exitCode : 2;
    return {
      exitCode,
      output: baseResult({
        error: err instanceof Error ? err.message : String(err),
      }),
    };
  }
}

export function renderHuman(result: PreviewResult): string {
  const clean = (s: string) => sanitizeTerminal(s);
  const lines = [
    `amaterasu-preview: ${clean(result.status)}`,
    `checkout: ${clean(result.checkout)} (${clean(result.branch)})`,
    `core: ${clean(result.coreCheckout)} (${clean(result.coreBranch)}, coreSwaps: ${result.coreSwaps})`,
    `uncommitted: ${result.uncommittedPaths.length > 0 ? result.uncommittedPaths.map(clean).join(', ') : 'none'}`,
  ];
  if (result.fallbackFrom) {
    lines.push(`fallback: ${clean(result.fallbackFrom)} device absent -> ${clean(result.target ?? '')}`);
  }
  if (result.coreSwapStatus) {
    lines.push(`core-swap-status: ${clean(result.coreSwapStatus)}`);
  }
  if (result.target) lines.push(`target: ${clean(result.target)} (${clean(result.verb ?? 'none')} on ${clean(result.lane ?? 'default')})`);
  if (result.command) lines.push(`command: ${clean(result.command)}`);
  for (const step of result.steps) {
    lines.push(`step (${clean(step.cwd)}): ${clean(step.formatted)}`);
  }
  for (const conflict of result.conflicts) {
    const holder = conflict.holder
      ? ` [held by pid ${conflict.holder.pid} from ${clean(conflict.holder.checkout)} (${clean(conflict.holder.target)})]`
      : '';
    lines.push(`occupied resource: ${clean(conflict.resource)} — ${clean(conflict.reason)}${holder}`);
  }
  if (result.error) lines.push(`error: ${clean(result.error)}`);
  return lines.join('\n');
}

if (import.meta.main) {
  const opts = parseCliArgs(process.argv.slice(2));
  const { exitCode, output } = await runAmaterasuPreview(opts);
  if (opts.json) {
    console.log(JSON.stringify(output, null, 2));
  } else {
    const text = renderHuman(output);
    if (exitCode === 0) console.log(text);
    else console.error(text);
  }
  process.exit(exitCode);
}
