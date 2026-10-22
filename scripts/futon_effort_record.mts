#!/usr/bin/env node
// Local, durable evidence that a delivery PR belongs to one typed Futon run, and the run manifest:
// every PR the run opened, whatever its base, and an idle run's pre-answered and parked rows (HR-5).
// Stored under the Git common directory, outside every PR-controlled tree.
import { execFileSync } from 'node:child_process';
import { closeSync, existsSync, lstatSync, mkdirSync, openSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';

type Record = {
  contract: 'hatsu.futon.effort/v0.1';
  runId: string;
  repo: string;
  invocation: string;
  selector: string;
  issue: number;
  pr: number;
  base: string;
  head: string;
  headSha: string;
  createdAt: string;
  updatedAt: string;
};
type Kind = 'delivery' | 'integration' | 'release';
type Opened = { issue: number | null; pr: number; base: string; kind: Kind; head: string };
type Resolution = 'default' | 'hold' | 'refuse';
type Idle = { decisions: Array<{ row: string; resolution: Resolution }>; localSlotFrees: string; terminal: string;
  budget: { minutes: number; tokens: number } };
type Parked = { issue: number; row: string; at: string };
// v0.1 runs (no manifest) still read; every new start writes v0.2.
type RunRecord = { contract: 'hatsu.futon.run/v0.1' | 'hatsu.futon.run/v0.2'; id: string; repo: string; invocation: string;
  selector: string; startedAt: string; idle?: Idle | null; prs?: Opened[]; parked?: Parked[] };
type Pull = { baseRefName: string; headRefName: string; headRefOid: string; state: string; isCrossRepository: boolean; createdAt: string; body: string };
type Issue = { labels: Array<{ name: string }>; state: string };
type Parsed = { repo: string; label: string | null; band: string | null };

function fail(message: string): never { throw new Error(message); }
function run(exe: string, args: string[], cwd: string): string {
  return execFileSync(exe, args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
}
function json<T>(exe: string, args: string[], cwd: string): T {
  return JSON.parse(run(exe, args, cwd)) as T;
}
function positive(raw: string | undefined, name: string): number {
  const n = Number(raw);
  if (!raw || !Number.isSafeInteger(n) || n < 1) fail(`${name} must be a positive integer`);
  return n;
}
function flags(argv: string[]): Map<string, string> {
  const out = new Map<string, string>();
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i];
    if (!key?.startsWith('--') || !argv[i + 1] || out.has(key)) fail(`invalid or repeated flag ${key ?? '<missing>'}`);
    out.set(key, argv[i + 1]);
  }
  return out;
}
function requireFlag(args: Map<string, string>, name: string): string {
  return args.get(name) ?? fail(`missing ${name}`);
}
function checkKeys(args: Map<string, string>, allowed: string[]): void {
  for (const key of args.keys()) if (!allowed.includes(key)) fail(`unknown flag ${key}`);
}
function commonDirectory(root: string): string {
  const raw = run('git', ['rev-parse', '--git-common-dir'], root);
  const dir = realpathSync(isAbsolute(raw) ? raw : resolve(root, raw));
  if (!lstatSync(dir).isDirectory()) fail('Git common directory is not a directory');
  return dir;
}
function metadataDirectory(root: string, create: boolean): string {
  const parent = join(commonDirectory(root), 'hatsu');
  if (existsSync(parent) && (lstatSync(parent).isSymbolicLink() || !lstatSync(parent).isDirectory()))
    fail('Hatsu metadata directory is unsafe');
  const dir = join(parent, 'futon');
  if (create) mkdirSync(dir, { recursive: true, mode: 0o700 });
  if (lstatSync(parent).isSymbolicLink() || !lstatSync(parent).isDirectory())
    fail('Hatsu metadata directory is unsafe');
  if (!existsSync(dir) || lstatSync(dir).isSymbolicLink() || !lstatSync(dir).isDirectory())
    fail('Futon record directory is missing or unsafe');
  return dir;
}
function safeRecordPath(dir: string, name: string): string {
  const path = join(dir, name);
  if (existsSync(path) && (!lstatSync(path).isFile() || lstatSync(path).isSymbolicLink()))
    fail('Futon record path is not a regular file');
  return path;
}
function recordPath(root: string, pr: number, create: boolean): string {
  return safeRecordPath(metadataDirectory(root, create), `pr-${pr}.json`);
}
function runPath(root: string, id: string, create: boolean): string {
  if (!/^[0-9a-f]{32}$/.test(id)) fail('invalid Futon run id');
  return safeRecordPath(metadataDirectory(root, create), `run-${id}.json`);
}
function readRecord(path: string): Record {
  if (!existsSync(path)) fail(`missing Futon effort metadata: ${path}`);
  const value: unknown = JSON.parse(readFileSync(path, 'utf8'));
  if (typeof value !== 'object' || value === null) fail('malformed Futon effort metadata');
  const record = value as Partial<Record>;
  if (record.contract !== 'hatsu.futon.effort/v0.1' ||
      typeof record.runId !== 'string' || !/^[0-9a-f]{32}$/.test(record.runId) ||
      typeof record.repo !== 'string' || typeof record.invocation !== 'string' ||
      typeof record.selector !== 'string' || typeof record.issue !== 'number' ||
      !Number.isSafeInteger(record.issue) || typeof record.pr !== 'number' ||
      !Number.isSafeInteger(record.pr) || typeof record.base !== 'string' ||
      typeof record.head !== 'string' || !/^[0-9a-f]{40}$/i.test(record.headSha ?? '') ||
      typeof record.createdAt !== 'string' || typeof record.updatedAt !== 'string')
    fail('malformed Futon effort metadata');
  return record as Record;
}
function readRun(path: string): RunRecord {
  if (!existsSync(path)) fail(`missing Futon run metadata: ${path}`);
  const value: unknown = JSON.parse(readFileSync(path, 'utf8'));
  if (typeof value !== 'object' || value === null) fail('malformed Futon run metadata');
  const run = value as Partial<RunRecord>;
  if ((run.contract !== 'hatsu.futon.run/v0.1' && run.contract !== 'hatsu.futon.run/v0.2') || typeof run.id !== 'string' ||
      !/^[0-9a-f]{32}$/.test(run.id) || typeof run.repo !== 'string' ||
      typeof run.invocation !== 'string' || typeof run.selector !== 'string' ||
      typeof run.startedAt !== 'string' || !Number.isFinite(Date.parse(run.startedAt)))
    fail('malformed Futon run metadata');
  if (run.contract === 'hatsu.futon.run/v0.2' && (!Array.isArray(run.prs) || !Array.isArray(run.parked) ||
      (run.idle !== null && (typeof run.idle !== 'object' || !Array.isArray(run.idle?.decisions)))))
    fail('malformed Futon run manifest');
  return run as RunRecord;
}
function writeRecord(path: string, value: Record | RunRecord): void {
  const temp = join(dirname(path), `.futon-${randomBytes(8).toString('hex')}.tmp`);
  const fd = openSync(temp, 'wx', 0o600);
  try { writeFileSync(fd, `${JSON.stringify(value, null, 2)}\n`); }
  finally { closeSync(fd); }
  renameSync(temp, path);
}
// nen 0.24 reads `--idle` as part of an exact label (`model/claude --idle`), so the one standalone
// token before the `then` clause is stripped before parsing; the grammar request is filed on zheref/nen.
function splitIdle(line: string): { invocation: string; idle: boolean } {
  const invocation = line.replace(/^hatsu:futon\s+/, '');
  if (invocation === line || !invocation) fail('invocation must start with hatsu:futon');
  const at = invocation.indexOf('@');
  const then = at < 0 ? -1 : invocation.slice(at).search(/(?:^|\s)then(?:\s|$)/);
  const cut = then < 0 ? invocation.length : at + then;
  const head = invocation.slice(0, cut);
  const marks = head.match(/(?:^|\s)--idle(?=\s|$)/g) ?? [];
  if (marks.length > 1) fail('--idle is typed once');
  if (/(?:^|\s)--idle(?=\s|$)/.test(invocation.slice(cut))) fail('--idle belongs before the then clause');
  const stripped = (head.replace(/(?:^|\s)--idle(?=\s|$)/, '') + invocation.slice(cut)).replace(/\s+/g, ' ').trim();
  return { invocation: stripped, idle: marks.length === 1 };
}
function parseFuton(root: string, line: string): Parsed {
  return json<Parsed>('nen', ['parse', 'futon', '--repo', root, splitIdle(line).invocation, '--json'], root);
}
// The idle profile: the target's nen/workflow.json `idle` block over the plugin's catalogue defaults;
// every ask-once-per-run row of the plugin's nen/decisions.json gets one resolution, unnamed rows `hold`.
function idleProfile(root: string): Idle {
  const plugin = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const rows = (JSON.parse(readFileSync(join(plugin, 'nen', 'decisions.json'), 'utf8')) as { rows: Array<{ id: string; class: string }> })
    .rows.filter((row) => row.class === 'ask-once-per-run').map((row) => row.id);
  const catalogue = JSON.parse(readFileSync(join(plugin, 'contracts', 'config-catalogue.json'), 'utf8')) as
    { values: Array<{ id: string; default?: unknown }> };
  const fallback = (id: string): unknown => catalogue.values.find((row) => row.id === `workflow.idle.${id}`)?.default;
  const workflow = join(root, 'nen', 'workflow.json');
  if (existsSync(workflow) && lstatSync(workflow).isSymbolicLink()) fail('nen/workflow.json is a symlink');
  const declared = (existsSync(workflow) ? (JSON.parse(readFileSync(workflow, 'utf8')) as { idle?: Record<string, unknown> }).idle : undefined) ?? {};
  const pick = (id: string): unknown => {
    let value: unknown = declared;
    for (const key of id.split('.')) value = value && typeof value === 'object' ? (value as Record<string, unknown>)[key] : undefined;
    return value ?? fallback(id);
  };
  const map = pick('decisions') ?? {};
  if (typeof map !== 'object' || map === null || Array.isArray(map)) fail('idle.decisions must be an object');
  const decisions = rows.map((row) => {
    const resolution = (map as Record<string, unknown>)[row] ?? 'hold';
    if (resolution !== 'default' && resolution !== 'hold' && resolution !== 'refuse')
      fail(`idle.decisions.${row} must be default, hold or refuse`);
    return { row, resolution: resolution as Resolution };
  });
  const localSlotFrees = pick('localSlotFrees');
  if (localSlotFrees !== 'ready+prompted' && localSlotFrees !== 'merged' && localSlotFrees !== 'stacked-open')
    fail('idle.localSlotFrees must be ready+prompted, merged or stacked-open');
  const terminal = pick('terminal');
  if (terminal !== 'ready-at-prompt-or-integration' && terminal !== 'ready-at-prompt')
    fail('idle.terminal must be ready-at-prompt-or-integration or ready-at-prompt');
  const minutes = pick('budget.minutes');
  const tokens = pick('budget.tokens');
  if (!Number.isSafeInteger(minutes) || (minutes as number) < 1 || !Number.isSafeInteger(tokens) || (tokens as number) < 1)
    fail('idle.budget.minutes and idle.budget.tokens must be positive integers');
  return { decisions, localSlotFrees, terminal, budget: { minutes: minutes as number, tokens: tokens as number } };
}
// One writer at a time on a manifest: appends from two sessions must not lose each other's rows.
function withLock<T>(path: string, act: () => T): T {
  const lock = `${path}.lock`;
  for (let attempt = 0; ; attempt++) {
    try { closeSync(openSync(lock, 'wx', 0o600)); break; }
    catch (cause) {
      if ((cause as { code?: string }).code !== 'EEXIST' || attempt >= 50) fail(`Futon run manifest is locked: ${lock}`);
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100);
    }
  }
  try { return act(); } finally { unlinkSync(lock); }
}
function openedPull(root: string, pr: number): { repo: string; pull: Pull } {
  const repository = json<{ nameWithOwner: string }>('gh', ['repo', 'view', '--json', 'nameWithOwner'], root);
  const pull = json<Pull>('gh', ['pr', 'view', String(pr), '--repo', repository.nameWithOwner,
    '--json', 'baseRefName,headRefName,headRefOid,state,isCrossRepository,createdAt,body'], root);
  if (pull.isCrossRepository) fail(`PR #${pr} is cross-repository`);
  if (!/^[0-9a-f]{40}$/i.test(pull.headRefOid)) fail(`PR #${pr} has no full head SHA`);
  if (!Number.isFinite(Date.parse(pull.createdAt))) fail(`PR #${pr} has no creation time`);
  return { repo: repository.nameWithOwner, pull };
}
function checkIssue(root: string, repo: string, issueNumber: number, parsed: Parsed): void {
  const issue = json<Issue>('gh', ['issue', 'view', String(issueNumber), '--repo', repo, '--json', 'labels,state'], root);
  const labels = new Set(issue.labels.map((label) => label.name));
  if (issue.state !== 'OPEN') fail(`issue #${issueNumber} is not open`);
  if (parsed.label && !labels.has(parsed.label)) fail(`issue #${issueNumber} lacks selected label ${parsed.label}`);
  if (parsed.band) fail('severity-band ownership needs a migrated Hatsu taxonomy; use an exact label selector');
}
function live(root: string, pr: number): { repo: string; defaultBranch: string; pull: Pull } {
  const repository = json<{ nameWithOwner: string; defaultBranchRef: { name: string } }>('gh',
    ['repo', 'view', '--json', 'nameWithOwner,defaultBranchRef'], root);
  const pull = json<Pull>('gh', ['pr', 'view', String(pr), '--repo', repository.nameWithOwner,
    '--json', 'baseRefName,headRefName,headRefOid,state,isCrossRepository,createdAt,body'], root);
  if (pull.state !== 'OPEN' || pull.isCrossRepository) fail(`PR #${pr} is closed or cross-repository`);
  if (pull.baseRefName === repository.defaultBranchRef.name) fail(`PR #${pr} targets the default branch`);
  if (!/^[0-9a-f]{40}$/i.test(pull.headRefOid)) fail(`PR #${pr} has no full head SHA`);
  if (!Number.isFinite(Date.parse(pull.createdAt))) fail(`PR #${pr} has no creation time`);
  return { repo: repository.nameWithOwner, defaultBranch: repository.defaultBranchRef.name, pull };
}
function checkAssociation(pull: Pull, issue: number, run: RunRecord): void {
  // GitHub rounds PR creation to seconds; a start made after PR creation is never accepted.
  if (Date.parse(run.startedAt) >= Date.parse(pull.createdAt))
    fail('Futon run metadata was created after this PR opened');
  const reference = new RegExp(`(?:^|[^0-9])#${issue}(?![0-9])`);
  if (!reference.test(pull.body ?? '')) fail(`PR body does not cite selected issue #${issue}`);
}
function verify(root: string, record: Record): void {
  const current = live(root, record.pr);
  if (record.repo !== current.repo || record.base !== current.pull.baseRefName ||
      record.head !== current.pull.headRefName || record.headSha !== current.pull.headRefOid)
    fail(`stale Futon ownership for PR #${record.pr}: recorded repo/base/head/SHA differs from GitHub`);
  const run = readRun(runPath(root, record.runId, false));
  if (run.id !== record.runId || run.repo !== record.repo ||
      run.invocation !== record.invocation || run.selector !== record.selector)
    fail(`Futon run metadata differs from PR #${record.pr}'s ownership record`);
  checkAssociation(current.pull, record.issue, run);
  const parsed = parseFuton(root, run.invocation);
  if (parsed.repo !== record.repo || (parsed.label ?? parsed.band) !== record.selector)
    fail(`Futon invocation no longer matches PR #${record.pr}'s recorded selector/repository`);
  checkIssue(root, record.repo, record.issue, parsed);
}
function main(argv: string[]): void {
  const command = argv.shift();
  const allowed: { [verb: string]: string[] } = {
    start: ['--repo', '--invocation'], bind: ['--repo', '--pr', '--run', '--issue', '--base', '--head', '--sha'],
    verify: ['--repo', '--pr'], append: ['--repo', '--run', '--pr', '--kind', '--issue'],
    park: ['--repo', '--run', '--issue', '--row'], status: ['--repo', '--run'] };
  if (!command || !Object.hasOwn(allowed, command))
    fail('usage: futon_effort_record.mts start|bind|verify|append|park|status --repo ROOT [flags]');
  const args = flags(argv);
  checkKeys(args, allowed[command]);
  const root = realpathSync(requireFlag(args, '--repo'));
  if (command === 'append' || command === 'park' || command === 'status') { manifest(root, command, args); return; }
  if (command === 'start') {
    const invocation = requireFlag(args, '--invocation');
    const parsed = parseFuton(root, invocation);
    const repository = json<{ nameWithOwner: string }>('gh', ['repo', 'view', '--json', 'nameWithOwner'], root);
    if (parsed.repo !== repository.nameWithOwner) fail('Futon invocation resolves to another repository');
    const selector = parsed.label ?? parsed.band ?? fail('Futon selector is missing');
    const id = randomBytes(16).toString('hex');
    const idle = splitIdle(invocation).idle ? idleProfile(root) : null;
    const run: RunRecord = { contract: 'hatsu.futon.run/v0.2', id, repo: parsed.repo,
      invocation, selector, startedAt: new Date().toISOString(), idle, prs: [], parked: [] };
    writeRecord(runPath(root, id, true), run);
    console.log(`futon-effort: run ${id} recorded for ${run.repo}@${selector}${idle ? ' (idle)' : ''}`);
    for (const row of idle?.decisions ?? []) console.log(`futon-effort: pre-answered ${row.row} → ${row.resolution}`);
    return;
  }
  const pr = positive(requireFlag(args, '--pr'), '--pr');
  const path = recordPath(root, pr, command === 'bind');
  if (command === 'verify') {
    const record = readRecord(path);
    if (record.pr !== pr) fail(`Futon metadata PR #${record.pr} differs from requested PR #${pr}`);
    verify(root, record);
    console.log(`futon-effort: PR #${pr} belongs to recorded Futon issue #${record.issue} at ${record.headSha}`);
    return;
  }
  const runId = requireFlag(args, '--run');
  const runRecord = readRun(runPath(root, runId, false));
  if (runRecord.id !== runId) fail('Futon run id mismatch');
  const invocation = runRecord.invocation;
  const issueNumber = positive(requireFlag(args, '--issue'), '--issue');
  const parsed = parseFuton(root, invocation);
  const current = live(root, pr);
  if (parsed.repo !== current.repo || runRecord.repo !== current.repo ||
      runRecord.selector !== (parsed.label ?? parsed.band))
    fail('Futon run resolves to another repository or selector');
  checkIssue(root, current.repo, issueNumber, parsed);
  checkAssociation(current.pull, issueNumber, runRecord);
  const base = requireFlag(args, '--base');
  const head = requireFlag(args, '--head');
  const sha = requireFlag(args, '--sha');
  if (base !== current.pull.baseRefName || head !== current.pull.headRefName || sha !== current.pull.headRefOid)
    fail(`PR #${pr} does not match the supplied base, head branch and SHA`);
  const selector = parsed.label ?? parsed.band ?? fail('Futon selector is missing');
  const prior = existsSync(path) ? readRecord(path) : null;
  if (prior && (prior.runId !== runId || prior.repo !== current.repo || prior.invocation !== invocation ||
      prior.selector !== selector || prior.issue !== issueNumber || prior.pr !== pr ||
      prior.base !== base || prior.head !== head)) fail(`PR #${pr} already belongs to a different Futon effort`);
  const now = new Date().toISOString();
  const record: Record = { contract: 'hatsu.futon.effort/v0.1', runId, repo: current.repo,
    invocation, selector, issue: issueNumber, pr, base, head, headSha: sha,
    createdAt: prior?.createdAt ?? now, updatedAt: now };
  writeRecord(path, record);
  console.log(`futon-effort: recorded PR #${pr}, issue #${issueNumber}, ${base}, ${sha}`);
}

// The run manifest: append every PR the run opened (any base), park an effort, print the manifest.
function manifest(root: string, command: string, args: Map<string, string>): void {
  const runId = requireFlag(args, '--run');
  const path = runPath(root, runId, false);
  if (command === 'status') {
    const run = readRun(path);
    const elapsedMinutes = Math.floor((Date.now() - Date.parse(run.startedAt)) / 60000);
    console.log(JSON.stringify({ ...run, idle: run.idle ?? null, prs: run.prs ?? [], parked: run.parked ?? [], elapsedMinutes,
      overBudget: run.idle ? elapsedMinutes >= run.idle.budget.minutes : false }, null, 2));
    return;
  }
  if (command === 'park') {
    const issue = positive(requireFlag(args, '--issue'), '--issue');
    const row = requireFlag(args, '--row');
    if (!/^[a-z0-9][a-z0-9:+-]{0,80}$/.test(row)) fail('--row must be a decisions row id or a parked reason (budget, residue:<skill>, g5:<class>)');
    withLock(path, () => {
      const run = readRun(path);
      if (run.contract !== 'hatsu.futon.run/v0.2') fail('a v0.1 run carries no manifest; start a new run');
      const parked = (run.parked ?? []).filter((entry) => entry.issue !== issue);
      writeRecord(path, { ...run, parked: [...parked, { issue, row, at: new Date().toISOString() }] });
    });
    console.log(`futon-effort: issue #${issue} parked:${row}`);
    return;
  }
  const pr = positive(requireFlag(args, '--pr'), '--pr');
  const kind = requireFlag(args, '--kind');
  if (kind !== 'delivery' && kind !== 'integration' && kind !== 'release') fail('--kind must be delivery, integration or release');
  const rawIssue = args.get('--issue');
  if (kind === 'delivery' && !rawIssue) fail('a delivery PR names its --issue');
  const issue = rawIssue ? positive(rawIssue, '--issue') : null;
  const current = openedPull(root, pr);
  withLock(path, () => {
    const run = readRun(path);
    if (run.contract !== 'hatsu.futon.run/v0.2') fail('a v0.1 run carries no manifest; start a new run');
    if (run.repo !== current.repo) fail(`PR #${pr} is in ${current.repo}, not the run's ${run.repo}`);
    if (Date.parse(run.startedAt) >= Date.parse(current.pull.createdAt)) fail(`PR #${pr} opened before this run started`);
    if (issue !== null && !new RegExp(`(?:^|[^0-9])#${issue}(?![0-9])`).test(current.pull.body ?? ''))
      fail(`PR body does not cite issue #${issue}`);
    const prior = (run.prs ?? []).find((entry) => entry.pr === pr);
    if (prior && (prior.issue !== issue || prior.kind !== kind))
      fail(`PR #${pr} is already recorded as ${prior.kind} for issue ${prior.issue ?? 'none'}`);
    const entry: Opened = { issue, pr, base: current.pull.baseRefName, kind, head: current.pull.headRefOid };
    writeRecord(path, { ...run, prs: [...(run.prs ?? []).filter((item) => item.pr !== pr), entry] });
  });
  console.log(`futon-effort: run ${runId} records ${kind} PR #${pr} onto ${current.pull.baseRefName} at ${current.pull.headRefOid}`);
}

try { main(process.argv.slice(2)); }
catch (cause) {
  console.error(`futon-effort: ${cause instanceof Error ? cause.message : String(cause)}`);
  process.exitCode = 1;
}
