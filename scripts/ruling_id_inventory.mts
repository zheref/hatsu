// Hatsu-local open-PR reader until zheref/nen#456. The counted read follows
// port_rule_reserve.sh: search total, bounded PR list, paginated files, then the roster diff.
// These reads inventory visible holders. They cannot reserve against an unpublished writer.
import { spawnSync } from 'node:child_process';
import { lstatSync, readFileSync, realpathSync } from 'node:fs';
import { join } from 'node:path';

const ROSTER = 'docs/ROSTER.md';
const OID = /^[0-9a-f]{40}$/;
export const MAX_HR = 999999;
export class InventoryError extends Error {}

interface Anchor { number: number; record: string | undefined }
interface Holder extends Anchor { where: string; revision?: string; own?: boolean }
interface Pull {
  number: number;
  changedFiles: number;
  headRefName: string;
  headRefOid: string;
  baseRefName: string;
  baseRefOid: string;
  isCrossRepository: boolean;
}
interface PullFile { filename: string; previous_filename?: string; additions: number; deletions: number; status: string }

function unread(place: string, detail: string): never {
  throw new InventoryError(`${place} could not be read: ${detail}`);
}

function command(repo: string, bin: string, args: string[], place: string): string {
  const result = spawnSync(bin, args, { cwd: repo, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024, timeout: 30000,
    env: { ...process.env, GIT_TERMINAL_PROMPT: '0', GH_PROMPT_DISABLED: '1', GH_HOST: 'github.com' } });
  if (result.status !== 0 || result.error) {
    // External diagnostics can contain credentials or control characters. Name the failed read and exit only.
    const code = (result.error as { code?: string } | undefined)?.code;
    unread(place, `${bin} ${code ?? `exit ${result.status ?? result.signal}`}`);
  }
  return result.stdout;
}

function json(data: string, place: string): unknown {
  try { return JSON.parse(data); } catch { return unread(place, 'invalid JSON'); }
}

function object(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function count(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
}

function pull(value: unknown): value is Pull {
  return object(value) && count(value.number) && value.number > 0 && count(value.changedFiles)
    && typeof value.headRefName === 'string' && value.headRefName !== ''
    && typeof value.headRefOid === 'string' && OID.test(value.headRefOid)
    && typeof value.baseRefName === 'string' && value.baseRefName !== ''
    && typeof value.baseRefOid === 'string' && OID.test(value.baseRefOid)
    && typeof value.isCrossRepository === 'boolean';
}

function pullFile(value: unknown): value is PullFile {
  return object(value) && typeof value.filename === 'string' && value.filename !== ''
    && (value.previous_filename === undefined || typeof value.previous_filename === 'string')
    && count(value.additions) && count(value.deletions) && typeof value.status === 'string';
}

// Historical roster rows use the same anchor inline, including multiple rulings on one table line.
// Plain references and prose examples without that anchor cannot claim an id.
function anchors(text: string, place: string): Anchor[] {
  const rows: Anchor[] = [];
  for (const line of text.split(/\r?\n/)) {
    for (const anchor of line.matchAll(/<a id="hr-/g)) {
      const match = /^<a id="hr-([1-9]\d{0,5})"><\/a>\s*\*\*HR-\1\*\*(?!\w)(?: · \[([^\]]+)\]\(ruling-records\/([A-Za-z0-9._-]+--R-\d{4}-\d{2}-\d{2}-\d{2,})\.json\))?/.exec(line.slice(anchor.index));
      if (!match) return unread(place, 'a ruling anchor and its HR id disagree or are malformed');
      rows.push({ number: Number(match[1]), record: match[2] === match[3] ? match[3] : undefined });
    }
  }
  return rows;
}

function diffAnchors(diff: string, file: PullFile, place: string): Anchor[] {
  const header = 'diff --git ';
  const start = `${header}a/${ROSTER} b/${ROSTER}`;
  const lines = diff.split(/\r?\n/);
  const index = lines.indexOf(start);
  if (index < 0 || lines.lastIndexOf(start) !== index) return unread(place, `missing or repeated diff section for ${ROSTER}`);
  const added: string[] = [];
  const removed: string[] = [];
  let before = 0;
  let after = 0;
  let inHunk = false;
  let oldHeader = false;
  let newHeader = false;
  for (const line of lines.slice(index + 1)) {
    if (line.startsWith(header) || line === '') break;
    if (line === '\\ No newline at end of file') continue;
    const hunk = /^@@ -\d+(?:,(\d+))? \+\d+(?:,(\d+))? @@(?: .*)?$/.exec(line);
    if (hunk) {
      if (before !== 0 || after !== 0 || !oldHeader || !newHeader) return unread(place, `incomplete diff hunk for ${ROSTER}`);
      inHunk = true;
      before = Number(hunk[1] ?? 1);
      after = Number(hunk[2] ?? 1);
    } else if (!inHunk) {
      oldHeader ||= line === `--- ${file.status === 'added' ? '/dev/null' : `a/${ROSTER}`}`;
      newHeader ||= line === `+++ ${file.status === 'removed' ? '/dev/null' : `b/${ROSTER}`}`;
    } else if (line.startsWith('+')) {
      added.push(line.slice(1));
      after -= 1;
    } else if (line.startsWith('-')) {
      removed.push(line.slice(1));
      before -= 1;
    } else if (line.startsWith(' ')) {
      before -= 1;
      after -= 1;
    } else return unread(place, `unexpected diff line for ${ROSTER}`);
    if (before < 0 || after < 0) return unread(place, `incorrect diff hunk length for ${ROSTER}`);
  }
  if (!inHunk || before !== 0 || after !== 0 || added.length !== file.additions || removed.length !== file.deletions) {
    return unread(place, `incomplete diff for ${ROSTER} (${added.length}/${file.additions} additions, ${removed.length}/${file.deletions} deletions)`);
  }
  // A changed line retaining the same id and record link is a re-render, not a new claimant.
  const key = (anchor: Anchor) => `${anchor.number}:${anchor.record ?? ''}`;
  const gone = new Map<string, number>();
  for (const row of anchors(removed.join('\n'), place)) gone.set(key(row), (gone.get(key(row)) ?? 0) + 1);
  return anchors(added.join('\n'), place).filter((row) => {
    const prior = gone.get(key(row)) ?? 0;
    if (prior === 0) return true;
    gone.set(key(row), prior - 1);
    return false;
  });
}

export function readLocal(repo: string, path: string): string {
  const file = join(repo, path);
  try {
    if (realpathSync(file) !== file || !lstatSync(file).isFile()) throw new Error();
    return readFileSync(file, 'utf8');
  } catch { return unread(path, 'expected a readable regular file within the checkout'); }
}

export function readBlob(repo: string, revision: string, path: string): string {
  return command(repo, 'git', ['show', `${revision}:${path}`], `${path} at ${revision || 'effort index'}`);
}

export function inventory(repo: string): Holder[] {
  const root = command(repo, 'git', ['rev-parse', '--show-toplevel'], 'the checkout root').trim();
  if (root !== repo) return unread('the checkout root', '--repo must name the root of the ruling worktree');
  const workflow = json(readLocal(repo, 'nen/workflow.json'), 'nen/workflow.json');
  const base = object(workflow) && object(workflow.branch) ? workflow.branch.base : undefined;
  if (typeof base !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9._/-]*$/.test(base)) {
    return unread('nen/workflow.json', 'branch.base must name a branch');
  }
  const ref = `refs/heads/${base}`;
  command(repo, 'git', ['check-ref-format', ref], 'the base ref');
  const remote = command(repo, 'git', ['config', '--get', 'remote.origin.url'], 'origin URL').trim();
  const slug = /^(?:git@github\.com:|ssh:\/\/git@github\.com\/|https:\/\/github\.com\/)([A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*?)(?:\.git)?$/.exec(remote)?.[1];
  if (!slug) return unread('origin URL', 'expected a github.com owner/repository');

  const tipPlace = `base origin/${base}`;
  const readTip = (): string => {
    const remoteTip = command(repo, 'git', ['ls-remote', '--exit-code', 'origin', ref], tipPlace).trim().split('\t');
    const [revision, reportedRef] = remoteTip;
    if (!revision || !OID.test(revision) || reportedRef !== ref || remoteTip.length !== 2) return unread(tipPlace, 'unexpected ref response');
    return revision;
  };
  const revision = readTip();
  const hasTip = spawnSync('git', ['cat-file', '-e', `${revision}^{commit}`], { cwd: repo });
  if (hasTip.status !== 0) command(repo, 'git', ['fetch', '--no-tags', '--no-write-fetch-head', 'origin', ref], tipPlace);
  const baseRows: Holder[] = anchors(readBlob(repo, revision, ROSTER), tipPlace).map((row) => ({ ...row, where: tipPlace, revision }));
  const head = command(repo, 'git', ['rev-parse', 'HEAD'], 'effort HEAD').trim();
  const branch = command(repo, 'git', ['branch', '--show-current'], 'effort branch').trim();
  const headRows = anchors(readBlob(repo, head, ROSTER), 'effort HEAD');
  const indexRows = anchors(readBlob(repo, '', ROSTER), 'effort index');
  const workRows = anchors(readLocal(repo, ROSTER), 'effort worktree');
  const baseClaims = new Map(baseRows.map((row) => [row.number, row.record]));
  const newLocal = (row: Anchor) => !baseClaims.has(row.number) || baseClaims.get(row.number) !== row.record;
  const local: Holder[] = [
    ...headRows.filter(newLocal).map((row) => ({ ...row, where: 'effort HEAD', own: true, revision: head })),
    ...indexRows.filter(newLocal).map((row) => ({ ...row, where: 'effort index', own: true, revision: '' })),
    ...workRows.filter(newLocal).map((row) => ({ ...row, where: 'effort worktree', own: true })),
  ];

  const gh = (args: string[], place: string) => command(repo, 'gh', args, place);
  const prPlace = `the open-PR inventory of ${slug}`;
  const total = json(gh(['api', `search/issues?q=repo:${slug}+is:pr+is:open`], `${prPlace} total`), prPlace);
  if (!object(total) || !count(total.total_count) || total.incomplete_results !== false) return unread(prPlace, 'incomplete search total');
  const openCount = total.total_count;
  const readPulls = (): Pull[] => {
    const pulls = json(gh(['pr', 'list', '--repo', slug, '--state', 'open', '--limit', '1000', '--json',
      'number,headRefName,isCrossRepository,changedFiles,headRefOid,baseRefName,baseRefOid'], prPlace), prPlace);
    if (!Array.isArray(pulls) || !pulls.every(pull)) return unread(prPlace, 'invalid pull request list');
    if (new Set(pulls.map((pr) => pr.number)).size !== openCount || pulls.length !== openCount) {
      return unread(prPlace, `${pulls.length} listed for ${openCount} open, or duplicate PR numbers`);
    }
    return pulls.sort((first, second) => first.number - second.number);
  };
  const pulls = readPulls();
  const holders = [...baseRows, ...local];
  for (const pr of pulls) {
    const where = `PR #${pr.number}`;
    const pages = json(gh(['api', '--paginate', '--slurp', `repos/${slug}/pulls/${pr.number}/files?per_page=100`], `${where} file list`), `${where} file list`);
    if (!Array.isArray(pages) || pages.length === 0 || !pages.every(Array.isArray)) return unread(`${where} file list`, 'invalid file pages');
    const files: unknown[] = pages.flat();
    if (!files.every(pullFile) || new Set(files.map((file) => file.filename)).size !== pr.changedFiles || files.length !== pr.changedFiles) {
      return unread(`${where} file list`, `${files.length} listed for ${pr.changedFiles} changed, or malformed or duplicate filenames`);
    }
    const file = files.find((entry) => entry.filename === ROSTER || entry.previous_filename === ROSTER);
    if (!file) continue;
    const place = `${where} diff`;
    if (!['added', 'modified', 'removed'].includes(file.status)) return unread(place, `unsupported ${ROSTER} change`);
    const diff = gh(['pr', 'diff', String(pr.number), '--repo', slug], place);
    const own = !pr.isCrossRepository && branch !== '' && pr.headRefName === branch
      && spawnSync('git', ['merge-base', '--is-ancestor', pr.headRefOid, head], { cwd: repo }).status === 0;
    holders.push(...diffAnchors(diff, file, place).map((row) => ({ ...row, where, own, revision: pr.headRefOid })));
  }
  // A counted diff can still match stale metadata after a force update. Re-read the PR
  // heads and bases as a set, and refuse any observed drift without printing an allocation.
  const after = readPulls();
  for (const [index, pr] of pulls.entries()) {
    const current = after[index];
    if (pr.number !== current.number || pr.headRefOid !== current.headRefOid
        || pr.baseRefOid !== current.baseRefOid || pr.headRefName !== current.headRefName
        || pr.baseRefName !== current.baseRefName || pr.changedFiles !== current.changedFiles
        || pr.isCrossRepository !== current.isCrossRepository) {
      return unread(prPlace, `PR #${pr.number} changed during the inventory; rerun the command`);
    }
  }
  if (readTip() !== revision) return unread(tipPlace, 'the tip changed during the inventory; rerun the command');
  return holders;
}
