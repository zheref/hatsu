#!/usr/bin/env node
// Local, durable evidence that a delivery PR belongs to one typed Futon run (#154): the run's ownership
// record (invocation, selector, start time, dry flag, the resolved idle profile) and one claim per stacked
// delivery PR, under the Git common directory, outside every PR-controlled tree. The run MANIFEST -- every
// PR the run opened and every parked effort, with the pre-answered rows (HR-5) -- is nen's alone:
// `start` opens it through `nen run start` with the same id, and nothing here appends, parks or reads it
// (zheref/hatsu#423). The idle profile is read from the COMMITTED nen/workflow.json of the remote default
// branch only (origin/HEAD, else gh's defaultBranchRef; SEC-15), never HEAD or a ref HEAD names, never the
// working tree; a default branch with no nen/workflow.json refuses the start, and the commit read is
// recorded in idle.source.
import { execFileSync } from 'node:child_process';
import { closeSync, existsSync, lstatSync, mkdirSync, openSync, readFileSync, realpathSync, renameSync, writeFileSync } from 'node:fs';
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
type Resolution = 'default' | 'hold' | 'refuse';
type Idle = { decisions: Array<{ row: string; resolution: Resolution }>; localSlotFrees: string; terminal: string;
  budget: { minutes: number; tokens: number }; source: { ref: string; commit: string } };
// The profile kept beside ownership; the decisions travel to nen's manifest as idleAnswers and are not kept here.
type Profile = Omit<Idle, 'decisions'>;
// v0.1 and v0.2 runs still read for ownership (their manifest half is never written again); a new start
// writes v0.3, which carries no prs, no parked rows and no answers: those are nen's manifest's.
type RunRecord = { contract: 'hatsu.futon.run/v0.1' | 'hatsu.futon.run/v0.2' | 'hatsu.futon.run/v0.3'; id: string; repo: string;
  invocation: string; selector: string; startedAt: string; dry?: boolean; idle?: Profile | Idle | null };
type NenStart = { outcome: string; path: string; manifest: { id: string; repo: string; idleAnswers: { [row: string]: Resolution } | null } };
type Pull = { baseRefName: string; headRefName: string; headRefOid: string; state: string; isCrossRepository: boolean; createdAt: string; body: string };
type Issue = { labels: Array<{ name: string }>; state: string };
type Parsed = { repo: string; label: string | null; band: string | null; idle?: boolean };

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
  if ((run.contract !== 'hatsu.futon.run/v0.1' && run.contract !== 'hatsu.futon.run/v0.2' && run.contract !== 'hatsu.futon.run/v0.3') ||
      typeof run.id !== 'string' ||
      !/^[0-9a-f]{32}$/.test(run.id) || typeof run.repo !== 'string' ||
      typeof run.invocation !== 'string' || typeof run.selector !== 'string' ||
      typeof run.startedAt !== 'string' || !Number.isFinite(Date.parse(run.startedAt)))
    fail('malformed Futon run metadata');
  if (run.contract === 'hatsu.futon.run/v0.3' && (typeof run.dry !== 'boolean' ||
      (run.idle !== null && (typeof run.idle !== 'object' || typeof run.idle?.terminal !== 'string'))))
    fail('malformed Futon run metadata');
  return run as RunRecord;
}
function writeRecord(path: string, value: Record | RunRecord): void {
  const temp = join(dirname(path), `.futon-${randomBytes(8).toString('hex')}.tmp`);
  const fd = openSync(temp, 'wx', 0o600);
  try { writeFileSync(fd, `${JSON.stringify(value, null, 2)}\n`); }
  finally { closeSync(fd); }
  renameSync(temp, path);
}
// nen reads `--idle` itself from 0.26.0 (zheref/nen#491) and nothing here strips it. `--dry-run`
// (zheref/hatsu#424) is no nen grammar at 0.26.0: the one standalone token before the `then` clause is
// lifted off here, beside `--idle` only, until `nen parse futon` reads it. Any other `--` token, a doubled
// modifier or a modifier after `then` is refused, never folded into the label nen would read.
function modifiers(line: string): { invocation: string; dry: boolean } {
  const invocation = line.replace(/^hatsu:futon\s+/, '');
  if (invocation === line || !invocation) fail('invocation must start with hatsu:futon');
  const at = invocation.indexOf('@');
  const then = at < 0 ? -1 : invocation.slice(at).search(/(?:^|\s)then(?:\s|$)/);
  const cut = then < 0 ? invocation.length : at + then;
  const head = invocation.slice(0, cut);
  const count = (flag: string) => (head.match(new RegExp(`(?:^|\\s)${flag}(?=\\s|$)`, 'g')) ?? []).length;
  for (const flag of ['--idle', '--dry-run']) {
    if (count(flag) > 1) fail(`${flag} is typed once`);
    if (new RegExp(`(?:^|\\s)${flag}(?=\\s|$)`).test(invocation.slice(cut))) fail(`${flag} belongs before the then clause`);
  }
  const rest = head.replace(/(?:^|\s)--dry-run(?=\s|$)/, '');
  const other = /(?:^|\s)(--(?!idle(?:\s|$))[A-Za-z][A-Za-z0-9-]*)(?=\s|$)/.exec(rest);
  if (other) fail(`${other[1]} is not a futon modifier: only --idle and --dry-run are read before the then clause`);
  const dry = count('--dry-run') === 1;
  if (dry && count('--idle') !== 1) fail('--dry-run rehearses an idle run: type it beside --idle (zheref/hatsu#424)');
  return { invocation: (rest + invocation.slice(cut)).replace(/\s+/g, ' ').trim(), dry };
}
function parseFuton(root: string, line: string): Parsed {
  return json<Parsed>('nen', ['parse', 'futon', '--repo', root, modifiers(line).invocation, '--json'], root);
}
// The committed nen/workflow.json the idle profile is read from: the REMOTE DEFAULT branch only
// (origin/HEAD, else gh's defaultBranchRef), never a ref HEAD's own commit names, never HEAD, never the
// working tree, never a symlink (SEC-15). A default ref with no nen/workflow.json refuses the start.
function committedWorkflow(root: string): { declared: unknown; ref: string; commit: string } {
  const tryRun = (args: string[]): string | null => { try { return run('git', args, root); } catch { return null; } };
  const symbolic = tryRun(['symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD']);
  let branch = symbolic?.startsWith('refs/remotes/origin/') ? symbolic.slice('refs/remotes/origin/'.length) : null;
  if (!branch) {
    try { branch = json<{ defaultBranchRef: { name: string } }>('gh', ['repo', 'view', '--json', 'defaultBranchRef'], root).defaultBranchRef.name; }
    catch { fail('idle profile unread: the remote default branch is unknown (no origin/HEAD, gh repo view failed)'); }
  }
  if (!branch || !/^[A-Za-z0-9._/-]+$/.test(branch)) fail(`idle profile unread: default branch name ${branch} is malformed`);
  const ref = `origin/${branch}`;
  const commit = tryRun(['rev-parse', '--verify', '--quiet', `refs/remotes/${ref}^{commit}`]);
  if (!commit) fail(`idle profile unread: ${ref} is not fetched`);
  const entry = tryRun(['ls-tree', commit, 'nen/workflow.json']);
  if (!entry) fail(`idle profile unread: ${ref} at ${commit} has no nen/workflow.json`);
  if (entry.startsWith('120000')) fail(`nen/workflow.json at ${ref} is a symlink`);
  return { declared: JSON.parse(run('git', ['show', `${commit}:nen/workflow.json`], root)), ref, commit };
}
// Rows an idle run may never pre-answer past a floor: publish-offer is always refuse (HR-5, never a release);
// the maintainer's own host and harness acts, and the never-derived maintainer choice (2026-09-23), at most hold.
const FLOOR: { [row: string]: Resolution } = { 'publish-offer': 'refuse', 'host-nen-link': 'hold',
  'harness-attribution-switch': 'hold', 'missing-maintainer-choice': 'hold' };
const LATITUDE: { [r in Resolution]: number } = { refuse: 0, hold: 1, default: 2 };
// The idle profile: the committed idle block over the plugin's catalogue defaults; every ask-once-per-run
// row of the plugin's nen/decisions.json gets one resolution, unnamed rows hold (publish-offer refuse).
function idleProfile(root: string): Idle {
  const plugin = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const rows = (JSON.parse(readFileSync(join(plugin, 'nen', 'decisions.json'), 'utf8')) as
    { rows: Array<{ id: string; class: string; preferred?: Array<{ recommended?: boolean }> }> })
    .rows.filter((row) => row.class === 'ask-once-per-run')
    .map((row) => ({ id: row.id, starred: (row.preferred ?? []).some((option) => option.recommended === true) }));
  const catalogue = JSON.parse(readFileSync(join(plugin, 'contracts', 'config-catalogue.json'), 'utf8')) as
    { values: Array<{ id: string; default?: unknown }> };
  const fallback = (id: string): unknown => catalogue.values.find((row) => row.id === `workflow.idle.${id}`)?.default;
  const source = committedWorkflow(root);
  const idleBlock = source.declared && typeof source.declared === 'object' ? (source.declared as { idle?: unknown }).idle : undefined;
  const declared = idleBlock ?? {};
  const pick = (id: string): unknown => {
    let value: unknown = declared;
    for (const key of id.split('.')) value = value && typeof value === 'object' ? (value as { [key: string]: unknown })[key] : undefined;
    return value ?? fallback(id);
  };
  const map = pick('decisions') ?? {};
  if (typeof map !== 'object' || map === null || Array.isArray(map)) fail('idle.decisions must be an object');
  const decisions = rows.map(({ id: row, starred }) => {
    const resolution = (map as { [key: string]: unknown })[row] ?? FLOOR[row] ?? 'hold';
    if (resolution !== 'default' && resolution !== 'hold' && resolution !== 'refuse')
      fail(`idle.decisions.${row} must be default, hold or refuse`);
    const floor = FLOOR[row];
    if (floor && LATITUDE[resolution] > LATITUDE[floor]) fail(`idle.decisions.${row} may not be ${resolution}: at most ${floor}`);
    if (resolution === 'default' && !starred) fail(`idle.decisions.${row} may not be default: the row stars no option`);
    return { row, resolution: resolution as Resolution };
  });
  // HR-257 binds every futon run, so the key lives in monitor, the block nen loop slots reads; nen reads an
  // idle.localSlotFrees first where a consumer declares one, so a declared value there is held to the same floor.
  const monitor = source.declared && typeof source.declared === 'object' ? (source.declared as { monitor?: { localSlotFrees?: unknown } }).monitor : undefined;
  const idleSlot = (declared as { localSlotFrees?: unknown }).localSlotFrees;
  if (idleSlot !== undefined && idleSlot !== 'merged')
    fail('idle.localSlotFrees must be merged where declared (HR-257, Slots and stops)');
  const localSlotFrees = monitor?.localSlotFrees ?? catalogue.values.find((row) => row.id === 'workflow.monitor.localSlotFrees')?.default;
  if (localSlotFrees !== 'merged')
    fail('monitor.localSlotFrees must be merged (HR-257, Slots and stops)');
  const terminal = pick('terminal');
  if (terminal !== 'ready-at-prompt-or-integration' && terminal !== 'ready-at-prompt')
    fail('idle.terminal must be ready-at-prompt-or-integration or ready-at-prompt');
  const minutes = pick('budget.minutes');
  const tokens = pick('budget.tokens');
  if (!Number.isSafeInteger(minutes) || (minutes as number) < 1 || !Number.isSafeInteger(tokens) || (tokens as number) < 1)
    fail('idle.budget.minutes and idle.budget.tokens must be positive integers');
  return { decisions, localSlotFrees: localSlotFrees as string, terminal, budget: { minutes: minutes as number, tokens: tokens as number },
    source: { ref: source.ref, commit: source.commit } };
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
  // append, park and status were the manifest half; nen run append|park|verify|budget own it (zheref/hatsu#423).
  const allowed: { [verb: string]: string[] } = {
    start: ['--repo', '--invocation'], bind: ['--repo', '--pr', '--run', '--issue', '--base', '--head', '--sha'],
    verify: ['--repo', '--pr'], profile: ['--repo', '--run'] };
  if (!command || !Object.hasOwn(allowed, command))
    fail(['append', 'park', 'status'].includes(command ?? '')
      ? `${command} is retired: the run manifest is nen's (nen run ${command === 'status' ? 'verify' : command}; zheref/hatsu#423)`
      : 'usage: futon_effort_record.mts start|bind|verify|profile --repo ROOT [flags]');
  const args = flags(argv);
  checkKeys(args, allowed[command]);
  const root = realpathSync(requireFlag(args, '--repo'));
  if (command === 'profile') {
    const runId = requireFlag(args, '--run');
    const run = readRun(runPath(root, runId, false));
    // A v0.1/v0.2 run opened no nen manifest: nen run verify finds no run, and futon § 8 holds its gate.
    console.log(JSON.stringify({ ...run, manifest: run.contract === 'hatsu.futon.run/v0.3' ? 'nen' : 'absent' }, null, 2));
    return;
  }
  if (command === 'start') {
    const invocation = requireFlag(args, '--invocation');
    const { dry } = modifiers(invocation);
    const parsed = parseFuton(root, invocation);
    const repository = json<{ nameWithOwner: string }>('gh', ['repo', 'view', '--json', 'nameWithOwner'], root);
    if (parsed.repo !== repository.nameWithOwner) fail('Futon invocation resolves to another repository');
    const selector = parsed.label ?? parsed.band ?? fail('Futon selector is missing');
    if (parsed.idle !== true && parsed.idle !== false) fail('nen parse futon returned no idle field: nen 0.26.0 or later reads --idle');
    if (dry && !parsed.idle) fail('--dry-run rehearses an idle run, and nen did not read --idle');
    const id = randomBytes(16).toString('hex');
    const idle = parsed.idle ? idleProfile(root) : null;
    const startedAt = new Date().toISOString();
    // The manifest is nen's: opened with this id, the pre-answered rows its idleAnswers. Written first, so
    // a refused nen start leaves no ownership record naming a run nen never opened.
    const answers = idle ? Object.fromEntries(idle.decisions.map((row) => [row.row, row.resolution])) : null;
    let opened: NenStart;
    try {
      opened = json<NenStart>('nen', ['run', 'start', '--id', id, '--target', parsed.repo, '--repo', root,
        ...(answers ? ['--idle-answers', JSON.stringify(answers)] : []), '--json'], root);
    } catch (cause) {
      const detail = (cause as { stderr?: string }).stderr?.trim();
      fail(`nen run start refused the run${detail ? `: ${detail}` : ''}`);
    }
    if (opened.outcome !== 'started' || opened.manifest?.id !== id || opened.manifest.repo !== parsed.repo)
      fail(`nen run start did not create run ${id} (outcome ${opened.outcome ?? 'unread'})`);
    const profile: Profile | null = idle ? { localSlotFrees: idle.localSlotFrees, terminal: idle.terminal,
      budget: idle.budget, source: idle.source } : null;
    const run: RunRecord = { contract: 'hatsu.futon.run/v0.3', id, repo: parsed.repo,
      invocation, selector, startedAt, dry, idle: profile };
    writeRecord(runPath(root, id, true), run);
    console.log(`futon-effort: run ${id} recorded for ${run.repo}@${selector}${idle ? ' (idle)' : ''}${dry ? ' (dry: nothing is authored)' : ''}`);
    console.log(`futon-effort: manifest ${opened.path} (nen.run/v0.1)`);
    if (profile) {
      console.log(`futon-effort: idle profile read from ${profile.source.ref} at ${profile.source.commit}`);
      console.log(`futon-effort: terminal ${profile.terminal} · budget --max-minutes ${profile.budget.minutes} --max-tokens ${profile.budget.tokens}`);
    }
    // Echoed from the manifest nen wrote, never from this script's own map.
    for (const [row, resolution] of Object.entries(opened.manifest.idleAnswers ?? {}))
      console.log(`futon-effort: pre-answered ${row} → ${resolution}`);
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

try { main(process.argv.slice(2)); }
catch (cause) {
  console.error(`futon-effort: ${cause instanceof Error ? cause.message : String(cause)}`);
  process.exitCode = 1;
}
