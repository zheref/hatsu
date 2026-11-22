#!/usr/bin/env node
// amaterasu_preview.mts — explicit standalone local preview from a maintainer-selected checkout or worktree
// (zheref/hatsu#617). Launches directly in the selected tree on disk (uncommitted edits included) with 0 core swaps,
// reports checkout/target/verbatim command, and refuses occupied resources before spawning while leaving existing
// sessions intact. Retains § 3 deferral when invoked with --automatic from a non-core worktree.
import { spawn, spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import {
  existsSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  renameSync,
  rmSync,
  statSync,
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

interface ContractPrecondition {
  kind?: string;
  value?: unknown;
  expect?: string;
}

interface LaunchTargetSpec {
  lane?: string;
  verb?: string;
  device?: string | { name?: string } | null;
}

interface LaunchContract {
  project?: {
    defaultLane?: string;
    launch?: Record<string, LaunchTargetSpec>;
    preconditions?: Record<string, ContractPrecondition[]>;
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
const LOCK_WAIT_MS = 5_000;
const PORT_PROBE_TIMEOUT_MS = 350;

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

export function formatShellArg(value: string): string {
  if (/^[A-Za-z0-9_./:=,@+-]+$/.test(value)) return value;
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

export function formatCommand(exe: string, argv: string[]): string {
  return [exe, ...argv].map(formatShellArg).join(' ');
}

function runGit(cwd: string, args: string[]): { status: number; stdout: string; stderr: string } {
  const res = spawnSync('git', ['-C', cwd, ...args], { encoding: 'utf8' });
  return {
    status: res.status ?? 1,
    stdout: res.stdout ?? '',
    stderr: res.stderr ?? '',
  };
}

function runNenSync(nenBin: string, args: string[], cwd?: string): { status: number; stdout: string; stderr: string; error?: Error } {
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
    // Renamed/copied NUL entries emit an extra NUL token for the source path.
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

function isPidAlive(pid: number): boolean {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return (err as NodeJS.ErrnoException).code === 'EPERM';
  }
}

function probeTcpPortBindOccupied(port: number): Promise<boolean> {
  return new Promise((resolvePromise) => {
    let settled = false;
    const srv = createServer();
    const finish = (occupied: boolean): void => {
      if (settled) return;
      settled = true;
      resolvePromise(occupied);
    };
    srv.once('error', (err) => {
      const code = (err as NodeJS.ErrnoException).code;
      finish(code === 'EADDRINUSE' || code === 'EACCES');
    });
    srv.listen({ port, host: '127.0.0.1', exclusive: true }, () => {
      srv.close(() => finish(false));
    });
  });
}

function probeTcpPortOccupied(port: number): Promise<boolean> {
  return new Promise((resolvePromise) => {
    let settled = false;
    const socket = createConnection({ host: '127.0.0.1', port });
    const finish = (occupied: boolean): void => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolvePromise(occupied);
    };
    socket.setTimeout(PORT_PROBE_TIMEOUT_MS);
    socket.once('connect', () => finish(true));
    socket.once('timeout', () => finish(false));
    socket.once('error', (err) => {
      const code = (err as NodeJS.ErrnoException).code;
      if (code === 'EPERM' || code === 'EACCES') {
        if (settled) return;
        settled = true;
        socket.destroy();
        void probeTcpPortBindOccupied(port).then(resolvePromise);
        return;
      }
      finish(false);
    });
  });
}

function sleepSync(ms: number): void {
  const view = new Int32Array(new SharedArrayBuffer(4));
  Atomics.wait(view, 0, 0, ms);
}

function withSessionLedger<T>(
  ledgerPath: string,
  fn: (sessions: SessionEntry[]) => { changed: boolean; next: SessionEntry[]; result: T },
): T {
  const dir = dirname(ledgerPath);
  mkdirSync(dir, { recursive: true });
  const lockDir = `${ledgerPath}.lock`;
  const deadline = Date.now() + LOCK_WAIT_MS;
  while (true) {
    try {
      mkdirSync(lockDir);
      break;
    } catch (err) {
      const code = (err as NodeJS.ErrnoException).code;
      if (code !== 'EEXIST') throw err;
      try {
        const st = statSync(lockDir);
        if (Date.now() - st.mtimeMs > LOCK_STALE_MS) {
          rmSync(lockDir, { recursive: true, force: true });
          continue;
        }
      } catch {
        continue;
      }
      if (Date.now() > deadline) {
        throw new Error(`timed out waiting for amaterasu session lock at ${lockDir}`);
      }
      sleepSync(20);
    }
  }
  try {
    let rawSessions: SessionEntry[] = [];
    let pruned = false;
    if (existsSync(ledgerPath)) {
      const parsed = safeJsonParse<SessionEntry[]>(readFileSync(ledgerPath, 'utf8'));
      if (Array.isArray(parsed)) {
        rawSessions = parsed.filter((item) => item && typeof item.id === 'string' && isPidAlive(item.pid));
        pruned = rawSessions.length !== parsed.length;
      } else {
        pruned = true;
      }
    }
    const { changed, next, result } = fn(rawSessions);
    if (changed || pruned) {
      const tmp = `${ledgerPath}.${process.pid}.${randomUUID()}.tmp`;
      writeFileSync(tmp, `${JSON.stringify(next, null, 2)}\n`, 'utf8');
      renameSync(tmp, ledgerPath);
    }
    return result;
  } finally {
    rmSync(lockDir, { recursive: true, force: true });
  }
}

function resolveCommonDir(selectedRoot: string): string {
  const commonRes = runGit(selectedRoot, ['rev-parse', '--git-common-dir']);
  if (commonRes.status !== 0) {
    throw new Error(`could not resolve git common dir for ${selectedRoot}: ${commonRes.stderr.trim()}`);
  }
  const raw = commonRes.stdout.trim();
  const abs = isAbsolute(raw) ? raw : resolve(selectedRoot, raw);
  return realpathSync(abs);
}

function readContractAndWorkflow(checkoutRoot: string): {
  contract: LaunchContract;
  workflowDefaultTarget: string | null;
} {
  const contractPath = join(checkoutRoot, 'nen', 'contract.json');
  if (!existsSync(contractPath)) {
    throw new Error(`missing declaration: ${contractPath}`);
  }
  const contract = safeJsonParse<LaunchContract>(readFileSync(contractPath, 'utf8'));
  if (!contract) {
    throw new Error(`invalid JSON in ${contractPath}`);
  }
  let workflowDefaultTarget: string | null = null;
  const workflowPath = join(checkoutRoot, 'nen', 'workflow.json');
  if (existsSync(workflowPath)) {
    const wf = safeJsonParse<{ launch?: { default?: string | null } }>(readFileSync(workflowPath, 'utf8'));
    if (wf?.launch && typeof wf.launch.default === 'string' && wf.launch.default.length > 0) {
      workflowDefaultTarget = wf.launch.default;
    }
  }
  return { contract, workflowDefaultTarget };
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
): number[] {
  const ports = new Set<number>();
  const addFromList = (items?: ContractPrecondition[]): void => {
    for (const item of items ?? []) {
      if (item?.kind === 'port' && item?.expect === 'free' && typeof item.value === 'number' && Number.isInteger(item.value)) {
        ports.add(item.value);
      }
    }
  };
  addFromList(contract.project?.preconditions?.[lane]);
  addFromList(dryJson?.preconditions);
  return [...ports];
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

function spawnNenAsync(
  nenBin: string,
  args: string[],
  onSpawned: (pid: number) => void,
): Promise<{ status: number; stdout: string; stderr: string }> {
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
    child.stdout.on('data', (chunk: Buffer) => stdoutChunks.push(chunk));
    child.stderr.on('data', (chunk: Buffer) => stderrChunks.push(chunk));
    child.once('error', (err) => {
      process.off('SIGINT', forwardSigint);
      process.off('SIGTERM', forwardSigterm);
      rejectPromise(err);
    });
    child.once('close', (code) => {
      process.off('SIGINT', forwardSigint);
      process.off('SIGTERM', forwardSigterm);
      resolvePromise({
        status: code ?? 1,
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

export async function runAmaterasuPreview(opts: PreviewOptions): Promise<{ exitCode: number; output: PreviewResult }> {
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
  const selectedRoot = realpathSync(topRes.stdout.trim());
  const branch = readGitBranch(selectedRoot);
  const statusRes = runGit(selectedRoot, ['status', '--porcelain=v1', '-z']);
  const uncommittedPaths = statusRes.status === 0 ? parsePorcelainZ(statusRes.stdout) : [];

  const wtRes = runNenSync(opts.nen, ['wc', 'worktrees', '--repo', selectedRoot, '--json']);
  const wtJson = wtRes.status === 0 ? safeJsonParse<WorktreesJson>(wtRes.stdout) : null;
  if (wtRes.status !== 0 || !wtJson?.core) {
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
  const coreRoot = realpathSync(wtJson.core);
  const isWorktree = selectedRoot !== coreRoot;
  const coreEntry = wtJson.worktrees?.find((w) => w.path && realpathSync(w.path) === coreRoot);
  const coreBranch = coreEntry?.branch || readGitBranch(coreRoot);

  let contract: LaunchContract;
  let workflowDefaultTarget: string | null;
  try {
    ({ contract, workflowDefaultTarget } = readContractAndWorkflow(selectedRoot));
  } catch (err) {
    return {
      exitCode: 2,
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

  const targetName = opts.target ?? workflowDefaultTarget;
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
  const targetSpec = launchMap?.[targetName];
  if (!targetSpec) {
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

  const lane = targetSpec.lane || contract.project?.defaultLane || null;
  const rawVerb = targetSpec.verb;
  if (rawVerb !== 'dev' && rawVerb !== 'run') {
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
        error: `launch target '${targetName}' declares unsupported verb '${String(rawVerb)}' (expected dev or run)`,
      }),
    };
  }
  const verb: 'dev' | 'run' = rawVerb;

  // Preserve § 3 automatic ren deferral when invoked automatically inside a worktree.
  if (opts.automatic && isWorktree) {
    const coreContract = safeJsonParse<LaunchContract>(
      existsSync(join(coreRoot, 'nen', 'contract.json'))
        ? readFileSync(join(coreRoot, 'nen', 'contract.json'), 'utf8')
        : '',
    );
    const coreTargetSpec = coreContract?.project?.launch?.[targetName];
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

  const dryArgs = ['shu', verb, '--repo', selectedRoot, '--target', targetName, '--dry-run', '--json'];
  const dryRes = runNenSync(opts.nen, dryArgs);
  const dryJson = safeJsonParse<DryRunJson>(dryRes.stdout);
  const steps = extractSteps(dryJson, selectedRoot);
  const resolvedLane = dryJson?.lane || lane || 'default';
  const liveArgs = ['shu', verb, '--repo', selectedRoot, '--target', targetName];
  const verbatimCommand = formatCommand(opts.nen, liveArgs);

  // Detect precondition and resource conflicts BEFORE executing anything.
  const conflicts: ConflictDetail[] = [];
  for (const pre of dryJson?.preconditions ?? []) {
    if (pre.satisfied === false) {
      const resource =
        pre.kind === 'port' ? `port ${String(pre.value)}` : `${String(pre.kind ?? 'resource')} ${String(pre.value ?? '')}`.trim();
      conflicts.push({
        resource,
        reason: `precondition expect '${String(pre.expect ?? 'satisfied')}' not satisfied`,
      });
    }
  }

  const declaredPorts = collectDeclaredFreePorts(contract, resolvedLane, dryJson);
  for (const port of declaredPorts) {
    if (conflicts.some((c) => c.resource === `port ${port}`)) continue;
    if (await probeTcpPortOccupied(port)) {
      conflicts.push({
        resource: `port ${port}`,
        reason: 'TCP listener already accepting connections on 127.0.0.1',
      });
    }
  }

  const deviceName = extractDeviceName(targetSpec, dryJson);
  const resourceKeys = buildResourceKeys(coreRoot, resolvedLane, targetName, verb, declaredPorts, deviceName);
  const commonDir = resolveCommonDir(selectedRoot);
  const ledgerPath = join(commonDir, '.nen', 'amaterasu', 'sessions.json');

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

  const activeConflicts = withSessionLedger(ledgerPath, (sessions) => ({
    changed: false,
    next: sessions,
    result: checkSessionConflicts(sessions),
  }));
  for (const conflict of activeConflicts) {
    if (!conflicts.some((c) => c.resource === conflict.resource)) {
      conflicts.push(conflict);
    }
  }

  if (conflicts.length > 0) {
    return {
      exitCode: 2,
      output: baseResult({
        status: 'resource conflict',
        executed: false,
        dryRun: opts.dryRun,
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
        stderr: dryRes.stderr.trim(),
        error: formatConflictMessage(conflicts),
      }),
    };
  }

  if (dryRes.status !== 0) {
    return {
      exitCode: 2,
      output: baseResult({
        status: 'error',
        executed: false,
        dryRun: opts.dryRun,
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
        stderr: dryRes.stderr.trim(),
        error: dryRes.stderr.trim() || `nen shu ${verb} --dry-run failed with exit ${dryRes.status}`,
      }),
    };
  }

  if (opts.dryRun) {
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
      }),
    };
  }

  // Acquire session lease atomically right before spawning, re-checking conflicts under lock.
  const leaseId = randomUUID();
  const acquireConflict = withSessionLedger<ConflictDetail[]>(ledgerPath, (sessions) => {
    const raced = checkSessionConflicts(sessions);
    if (raced.length > 0) {
      return { changed: false, next: sessions, result: raced };
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
        error: formatConflictMessage(acquireConflict),
      }),
    };
  }

  let runRes: { status: number; stdout: string; stderr: string };
  try {
    runRes = await spawnNenAsync(opts.nen, liveArgs, (childPid) => {
      withSessionLedger(ledgerPath, (sessions) => ({
        changed: true,
        next: sessions.map((s) => (s.id === leaseId ? { ...s, pid: childPid } : s)),
        result: undefined,
      }));
    });
  } finally {
    withSessionLedger(ledgerPath, (sessions) => {
      const filtered = sessions.filter((s) => s.id !== leaseId);
      return { changed: filtered.length !== sessions.length, next: filtered, result: undefined };
    });
  }

  if (runRes.status !== 0) {
    return {
      exitCode: runRes.status || 1,
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
        stdout: runRes.stdout,
        stderr: runRes.stderr,
        error: runRes.stderr.trim() || `launch exited with code ${runRes.status}`,
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
      stdout: runRes.stdout,
      stderr: runRes.stderr,
    }),
  };
}

function renderHuman(result: PreviewResult): string {
  const lines = [
    `amaterasu-preview: ${result.status}`,
    `checkout: ${result.checkout} (${result.branch})`,
    `core: ${result.coreCheckout} (${result.coreBranch}, coreSwaps: ${result.coreSwaps})`,
    `uncommitted: ${result.uncommittedPaths.length > 0 ? result.uncommittedPaths.join(', ') : 'none'}`,
  ];
  if (result.target) lines.push(`target: ${result.target} (${result.verb ?? 'none'} on ${result.lane ?? 'default'})`);
  if (result.command) lines.push(`command: ${result.command}`);
  for (const step of result.steps) {
    lines.push(`step (${step.cwd}): ${step.formatted}`);
  }
  for (const conflict of result.conflicts) {
    const holder = conflict.holder
      ? ` [held by pid ${conflict.holder.pid} from ${conflict.holder.checkout} (${conflict.holder.target})]`
      : '';
    lines.push(`occupied resource: ${conflict.resource} — ${conflict.reason}${holder}`);
  }
  if (result.error) lines.push(`error: ${result.error}`);
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
