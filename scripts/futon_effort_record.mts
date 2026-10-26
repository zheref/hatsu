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
import { closeSync, existsSync, lstatSync, mkdirSync, openSync, readdirSync, readFileSync, realpathSync, renameSync, writeFileSync } from 'node:fs';
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
  invocation: string; selector: string; startedAt: string; dry?: boolean; idle?: Profile | Idle | null;
  predictions?: Prediction[]; integration?: string; endedAt?: string; endTracked?: boolean };
// A dry run's predicted end states (zheref/hatsu#424): kept on this record, never written into nen's parked[],
// which is HR-5's real park state and carries no dry flag at nen 0.26.0.
type Prediction = { issue: string; row: string; at: string };
type NenStart = { outcome: string; path: string;
  manifest: { id: string; repo: string; startedAt: string; idleAnswers: { [row: string]: Resolution } | null } };
// The answers nen stored must be exactly the map sent: the floor's only durable copy is nen's manifest.
function sameAnswers(stored: { [row: string]: unknown } | null | undefined, sent: { [row: string]: Resolution } | null): boolean {
  if (sent === null || stored === null || stored === undefined) return sent === null && (stored === null || stored === undefined);
  const keys = Object.keys(sent);
  return Object.keys(stored).length === keys.length && keys.every((key) => stored[key] === sent[key]);
}
type Pull = { baseRefName: string; headRefName: string; headRefOid: string; state: string; isCrossRepository: boolean; createdAt: string; body: string };
type Issue = { labels: Array<{ name: string }>; state: string };
type Parsed = { repo: string; label: string | null; band: string | null; idle?: boolean };

function fail(message: string): never { throw new Error(message); }
// Exit 3 is "no run to resume: start one" -- the one answer futon § 1 starts on; every other refusal is exit 1 (HA#488).
class NoRun extends Error {}
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
  if ((run.integration !== undefined && typeof run.integration !== 'string') ||
      (run.endedAt !== undefined && (typeof run.endedAt !== 'string' || !Number.isFinite(Date.parse(run.endedAt)))) ||
      (run.endTracked !== undefined && typeof run.endTracked !== 'boolean'))
    fail('malformed Futon run metadata');
  return run as RunRecord;
}
// The newest real, unended v0.3 run typed as exactly this line; a resume with no --run continues it (HA#488).
// A record that does not read, or whose id is not its filename's, is never picked: resume refuses naming it,
// start only notes it.
function priorRun(root: string, invocation: string, strict: boolean): string | null {
  const wanted = identity(root, invocation);
  const parent = join(commonDirectory(root), 'hatsu', 'futon');
  if (!existsSync(parent)) return null;
  const dir = metadataDirectory(root, false);
  const runs: RunRecord[] = [];
  for (const name of readdirSync(dir).filter((entry) => /^run-[0-9a-f]{32}\.json$/.test(entry))) {
    try {
      const run = readRun(safeRecordPath(dir, name));
      if (run.id !== name.slice(4, 36)) fail('its id is not its filename\'s');
      runs.push(run);
    } catch (cause) {
      const why = `run record ${join(dir, name)} is unreadable (${cause instanceof Error ? cause.message : String(cause)})`;
      if (strict) fail(why);
      console.log(`futon-effort: note: ${why}; skipped`);
    }
  }
  // Only a record start wrote with end tracking is picked: one written before `end` existed carries no end
  // mark and may long be finished, so it resumes by an explicit --run alone.
  const candidates = runs.filter((run) => run.contract === 'hatsu.futon.run/v0.3' && run.dry !== true && !run.endedAt && run.endTracked === true);
  const open = candidates.filter((run) => run.invocation === invocation || identity(root, run.invocation) === wanted)
    .sort((a, b) => Date.parse(b.startedAt) - Date.parse(a.startedAt));
  return open[0]?.id ?? null;
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
// A run's identity is what nen reads from its line -- repository, selector, terminal, then clause, idle -- plus the
// lifted --dry-run, never the spelling: two placements of --idle nen parses alike are one run (HA#488, Bugbot).
function identity(root: string, line: string): string {
  const parsed = parseFuton(root, line) as Parsed & { terminal?: unknown; then?: unknown };
  return JSON.stringify([parsed.repo, parsed.band ?? null, parsed.label ?? null, parsed.terminal ?? null,
    parsed.then ?? null, parsed.idle === true, modifiers(line).dry]);
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
// The maintainer's ruling of 2026-10-23 (WORKFLOW § 2 idle): an idle run is unattended except for an act
// that may not be reversed. So the floor holds publish-offer at refuse (a published release is not
// undone; HR-5), wrap-up and cleanup-plan at refuse (HR-366, ruled 2026-10-26: the maintainer's declared
// satisfaction is never met unattended, so neither is offered nor run) and the never-derived maintainer
// choice (2026-09-23, HR-4) at most hold.
const FLOOR: { [row: string]: Resolution } = { 'publish-offer': 'refuse', 'wrap-up': 'refuse', 'cleanup-plan': 'refuse', 'missing-maintainer-choice': 'hold' };
const LATITUDE: { [r in Resolution]: number } = { refuse: 0, hold: 1, default: 2 };
// The idle profile: the committed idle block over the plugin's catalogue defaults; every ask-once-per-run
// row of the plugin's nen/decisions.json gets one resolution; an unnamed row takes its starred default,
// holds where it stars none, and the floor applies (publish-offer, wrap-up and cleanup-plan refuse;
// missing-maintainer-choice hold).
function askRows(): Array<{ id: string; starred: boolean }> {
  const plugin = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  return (JSON.parse(readFileSync(join(plugin, 'nen', 'decisions.json'), 'utf8')) as
    { rows: Array<{ id: string; class: string; preferred?: Array<{ recommended?: boolean }> }> })
    .rows.filter((row) => row.class === 'ask-once-per-run')
    .map((row) => ({ id: row.id, starred: (row.preferred ?? []).some((option) => option.recommended === true) }));
}
// The floor start enforces, re-read on answers a resume takes from nen's manifest, which nen checks only for
// spelling: an answer edited after start never resumes more permissive than the floor (hanten, HA#488).
function floorCheck(answers: { [row: string]: unknown }): void {
  const starred = new Map(askRows().map((row) => [row.id, row.starred]));
  for (const [row, resolution] of Object.entries(answers)) {
    if (resolution !== 'default' && resolution !== 'hold' && resolution !== 'refuse') fail(`stored answer ${row} must be default, hold or refuse`);
    const floor = FLOOR[row];
    if (floor && LATITUDE[resolution] > LATITUDE[floor]) fail(`stored answer ${row} may not be ${resolution}: at most ${floor}`);
    if (resolution === 'default' && starred.get(row) === false) fail(`stored answer ${row} may not be default: the row stars no option`);
  }
  for (const row of Object.keys(FLOOR)) if (!(row in answers)) fail(`stored answers name no ${row}: the floor row is missing`);
}
function idleProfile(root: string): Idle {
  const plugin = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const rows = askRows();
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
    const resolution = (map as { [key: string]: unknown })[row] ?? FLOOR[row] ?? (starred ? 'default' : 'hold');
    if (resolution !== 'default' && resolution !== 'hold' && resolution !== 'refuse')
      fail(`idle.decisions.${row} must be default, hold or refuse`);
    const floor = FLOOR[row];
    if (floor && LATITUDE[resolution] > LATITUDE[floor]) fail(`idle.decisions.${row} may not be ${resolution}: at most ${floor}`);
    if (resolution === 'default' && !starred) fail(`idle.decisions.${row} may not be default: the row stars no option`);
    return { row, resolution: resolution as Resolution };
  });
  // The slot rule binds every futon run, so the key lives in monitor, the block nen loop slots reads; nen reads an
  // idle.localSlotFrees first where a consumer declares one, so a declared value there is held to the same rule.
  // ready+prompted is the maintainer's pick on zheref/hatsu#425 (HR-353, record R-2026-10-23-20), superseding HR-257's merged in part.
  const monitor = source.declared && typeof source.declared === 'object' ? (source.declared as { monitor?: { localSlotFrees?: unknown } }).monitor : undefined;
  const idleSlot = (declared as { localSlotFrees?: unknown }).localSlotFrees;
  if (idleSlot !== undefined && idleSlot !== 'ready+prompted')
    fail('idle.localSlotFrees must be ready+prompted where declared (HR-353, record R-2026-10-23-20, zheref/hatsu#425)');
  const localSlotFrees = monitor?.localSlotFrees ?? catalogue.values.find((row) => row.id === 'workflow.monitor.localSlotFrees')?.default;
  if (localSlotFrees !== 'ready+prompted')
    fail('monitor.localSlotFrees must be ready+prompted (HR-353, record R-2026-10-23-20, zheref/hatsu#425)');
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
  // The shapes bind refuses are never vouched for, whatever a claim written before the refusal says (zheref/hatsu#488).
  if (run.dry === true || run.idle) fail(`run ${run.id} is ${run.dry === true ? 'a dry' : 'an unattended'} run: it owns no stacked delivery PR`);
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
    start: ['--repo', '--invocation'], resume: ['--repo', '--run', '--invocation'], integrate: ['--repo', '--run', '--branch'], end: ['--repo', '--run'],
    bind: ['--repo', '--pr', '--run', '--issue', '--base', '--head', '--sha'],
    verify: ['--repo', '--pr'], profile: ['--repo', '--run'], predict: ['--repo', '--run', '--issue', '--row'] };
  if (!command || !Object.hasOwn(allowed, command))
    fail(['append', 'park', 'status'].includes(command ?? '')
      ? `${command} is retired: the run manifest is nen's (nen run ${command === 'status' ? 'verify' : command}; zheref/hatsu#423)`
      : 'usage: futon_effort_record.mts start|resume|integrate|end|bind|verify|profile|predict --repo ROOT [flags]');
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
  if (command === 'predict') {
    const runId = requireFlag(args, '--run');
    const path = runPath(root, runId, false);
    const run = readRun(path);
    if (run.contract !== 'hatsu.futon.run/v0.3' || run.dry !== true)
      fail(`run ${runId} is not a dry run: a real stop is parked with nen run park`);
    const issue = requireFlag(args, '--issue');
    const row = requireFlag(args, '--row');
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]*(?:\/[A-Za-z0-9._-]+)?#[1-9][0-9]*$/.test(issue)) fail('--issue must be <CODE>#<N>');
    if (!/^[a-z0-9][a-z0-9-]{0,80}$/.test(row)) fail('--row must be [a-z0-9-]+ (a decisions row, g5-<class>, residue-<skill>, dry-prompt, dry-waiting-slot)');
    const predictions = (run.predictions ?? []).filter((entry) => entry.issue !== issue);
    writeRecord(path, { ...run, predictions: [...predictions, { issue, row, at: new Date().toISOString() }] });
    console.log(`futon-effort: dry ${issue} predicted:${row}`);
    return;
  }
  // zheref/hatsu#488: a re-invoked run after an interruption continues under its own id, manifest and delivery
  // shape -- never a fresh start that would split an unattended run's integration delivery in two. The typed
  // line must be the recorded one, and nen must already hold the manifest with the same launch answers.
  if (command === 'end') {
    // futon § 10's end, recorded once: an ended run is never picked by a resume, so the same line typed again
    // after it is a new run (HA#488).
    const runId = requireFlag(args, '--run');
    const path = runPath(root, runId, false);
    const record = readRun(path);
    if (record.id !== runId) fail('Futon run id mismatch');
    if (!record.endedAt) writeRecord(path, { ...record, endedAt: new Date().toISOString() });
    console.log(`futon-effort: run ${runId} ended${record.endedAt ? ` at ${record.endedAt} (unchanged)` : ''}`);
    return;
  }
  if (command === 'integrate') {
    // The run's one integration branch, recorded once at its cut so a resume on another day keeps it (HA#488).
    const runId = requireFlag(args, '--run');
    const path = runPath(root, runId, false);
    const run = readRun(path);
    if (run.contract !== 'hatsu.futon.run/v0.3') fail(`run ${runId} opened no nen manifest (${run.contract})`);
    if (run.dry === true) fail(`run ${runId} is a dry run: it cuts no integration branch (zheref/hatsu#424)`);
    if (run.id !== runId) fail('Futon run id mismatch');
    const branch = requireFlag(args, '--branch');
    if (branch.startsWith('-') || branch === 'HEAD' || /^(?:refs|heads|remotes|origin)\//.test(branch)) fail(`--branch ${branch} must be a bare branch name`);
    try { execFileSync('git', ['check-ref-format', '--branch', branch], { cwd: root, stdio: 'ignore' }); }
    catch { fail(`--branch ${branch} is not a branch name (git check-ref-format)`); }
    const repository = json<{ nameWithOwner: string; defaultBranchRef: { name: string } }>('gh', ['repo', 'view', '--json', 'nameWithOwner,defaultBranchRef'], root);
    if (repository.nameWithOwner !== run.repo) fail('Futon run belongs to another repository');
    if (branch === repository.defaultBranchRef?.name) fail(`${branch} is the default branch: an integration branch is never main`);
    if (run.integration && run.integration !== branch) fail(`run ${runId} already integrates through ${run.integration}`);
    if (!run.integration) writeRecord(path, { ...run, integration: branch });
    console.log(`futon-effort: run ${runId} integrates through ${branch}${run.integration ? ' (unchanged)' : ''}`);
    return;
  }
  // zheref/hatsu#488: a re-invoked run continues under its own id, manifest, launch answers, terminal and integration
  // branch -- never a fresh start that would split an unattended run's integration delivery in two. With no --run,
  // the newest v0.3 record typed as the same line is the one; none means a new run. The answers resent are the ones
  // nen stored at start, never re-derived from a profile that may have moved since; a drift is reported, not obeyed.
  if (command === 'resume') {
    const invocation = requireFlag(args, '--invocation');
    const runId = args.get('--run') ?? priorRun(root, invocation, true) ?? (() => { throw new NoRun(`no open run was typed as '${invocation}': start a new run`); })();
    const run = readRun(runPath(root, runId, false));
    if (run.id !== runId) fail('Futon run id mismatch');
    if (run.contract !== 'hatsu.futon.run/v0.3') fail(`run ${runId} opened no nen manifest (${run.contract}): it is never resumed`);
    if (run.endedAt) fail(`run ${runId} ended at ${run.endedAt}: it is never resumed`);
    if (run.dry === true) fail(`run ${runId} is a dry run: a rehearsal is never resumed (zheref/hatsu#424)`);
    if (invocation !== run.invocation && identity(root, invocation) !== identity(root, run.invocation))
      fail(`run ${runId} was typed as '${run.invocation}': a resume re-types that line (nen must parse it alike)`);
    const parsed = parseFuton(root, invocation);
    const repository = json<{ nameWithOwner: string }>('gh', ['repo', 'view', '--json', 'nameWithOwner'], root);
    if (parsed.repo !== repository.nameWithOwner || parsed.repo !== run.repo) fail('Futon invocation resolves to another repository');
    if ((parsed.label ?? parsed.band) !== run.selector || parsed.idle !== Boolean(run.idle))
      fail(`run ${runId}'s line now parses to another selector or idle flag than its record`);
    // nen run start WRITES a manifest for an unknown id, and an empty one would open futon § 8's gate: prove the
    // manifest is there before the call, never after (hanten, HA#488).
    const manifest = join(commonDirectory(root), '.nen', 'runs', `${runId}.json`);
    if (!existsSync(manifest) || lstatSync(manifest).isSymbolicLink() || !lstatSync(manifest).isFile())
      fail(`nen holds no manifest for run ${runId} at ${manifest}: nothing to resume, and none is created`);
    let stored: { idleAnswers?: { [row: string]: Resolution } | null };
    try { stored = JSON.parse(readFileSync(manifest, 'utf8')); }
    catch { fail(`nen's manifest ${manifest} does not read as JSON`); }
    if (typeof stored !== 'object' || stored === null || Array.isArray(stored)) fail(`nen's manifest ${manifest} is not a run manifest`);
    const answers = stored.idleAnswers ?? null;
    if (answers) floorCheck(answers);
    if ((answers === null) !== !run.idle) fail(`nen's manifest ${manifest} and run ${runId}'s record disagree on whether the run is idle`);
    let opened: NenStart;
    try {
      opened = json<NenStart>('nen', ['run', 'start', '--id', runId, '--target', run.repo, '--repo', root,
        ...(answers ? ['--idle-answers', JSON.stringify(answers)] : []), '--json'], root);
    } catch (cause) {
      const detail = (cause as { stderr?: string }).stderr?.trim();
      fail(`nen run start refused the resume${detail ? `: ${detail}` : ''}`);
    }
    if (opened.outcome !== 'existing' || opened.manifest?.id !== runId || opened.manifest.repo !== run.repo ||
        opened.manifest.startedAt !== run.startedAt || !sameAnswers(opened.manifest.idleAnswers, answers))
      fail(`nen holds no matching manifest for run ${runId} (outcome ${opened.outcome ?? 'unread'}): nothing to resume`);
    console.log(`futon-effort: run ${runId} resumed for ${run.repo}@${run.selector}${run.idle ? ' (idle)' : ''}, started ${run.startedAt}`);
    console.log(`futon-effort: manifest ${opened.path} (nen.run/v0.1)`);
    if (run.idle) {
      console.log(`futon-effort: terminal ${run.idle.terminal} · delivery: ${run.integration ?? 'the run\'s one integration branch (not cut yet)'} and its one PR · budget --max-minutes ${run.idle.budget.minutes} --max-tokens ${run.idle.budget.tokens}`);
      let live: Idle | null = null;
      try { live = idleProfile(root); } catch { /* an unreadable live profile changes nothing fixed at start */ }
      const liveAnswers = live ? Object.fromEntries(live.decisions.map((row) => [row.row, row.resolution])) : null;
      if (!live || live.terminal !== run.idle.terminal || !sameAnswers(answers, liveAnswers))
        console.log('futon-effort: note: the committed idle profile now differs from launch; this run keeps its launch answers and terminal');
    } else if (run.integration) console.log(`futon-effort: integration ${run.integration}`);
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
    const prior = dry ? null : priorRun(root, invocation, false);
    const id = randomBytes(16).toString('hex');
    const idle = parsed.idle ? idleProfile(root) : null;
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
    if (!sameAnswers(opened.manifest.idleAnswers, answers))
      fail(`nen's manifest ${opened.path} stores other idle answers than the floor resolved; the run is refused (orphan manifest left for cleanup)`);
    // One owner for the run's start time: nen's, which append, budget and the catalogue row count from.
    const startedAt = opened.manifest.startedAt;
    if (typeof startedAt !== 'string' || !Number.isFinite(Date.parse(startedAt)))
      fail(`nen's manifest ${opened.path} carries no readable startedAt`);
    const profile: Profile | null = idle ? { localSlotFrees: idle.localSlotFrees, terminal: idle.terminal,
      budget: idle.budget, source: idle.source } : null;
    const run: RunRecord = { contract: 'hatsu.futon.run/v0.3', id, repo: parsed.repo,
      invocation, selector, startedAt, dry, idle: profile, ...(dry ? { predictions: [] } : { endTracked: true }) };
    try { writeRecord(runPath(root, id, true), run); }
    catch (cause) {
      fail(`the ownership record could not be written (${cause instanceof Error ? cause.message : String(cause)}); nen's manifest ${opened.path} is an orphan, left for cleanup`);
    }
    console.log(`futon-effort: run ${id} recorded for ${run.repo}@${selector}${idle ? ' (idle)' : ''}${dry ? ' (dry: nothing is authored)' : ''}`);
    console.log(`futon-effort: manifest ${opened.path} (nen.run/v0.1)`);
    if (prior) console.log(`futon-effort: note: run ${prior} was typed as this same line; this is a new run (resume continues that one)`);
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
  if (runRecord.dry === true) fail(`run ${runId} is a dry run: it authors nothing, so no PR is bound to it (zheref/hatsu#424)`);
  if (runRecord.idle) fail(`run ${runId} is unattended: it delivers through its integration PR, never a stacked delivery PR (zheref/hatsu#488)`);
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
  process.exitCode = cause instanceof NoRun ? 3 : 1;
}
