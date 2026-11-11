// Hatsu-local open-PR reader until zheref/nen#456. The counted read follows
// port_rule_reserve.sh: search total, bounded PR list, paginated files, then the roster diff.
// These reads inventory visible holders. They cannot reserve against an unpublished writer.
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
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

function run(repo: string, bin: string, args: string[], place: string, input?: string) {
  const result = spawnSync(bin, args, { cwd: repo, encoding: 'utf8', input, maxBuffer: 32 * 1024 * 1024, timeout: 30000,
    env: { ...process.env, GIT_TERMINAL_PROMPT: '0', GH_PROMPT_DISABLED: '1', GH_HOST: 'github.com' } });
  if (result.error || result.status === null) {
    // External diagnostics can contain credentials or control characters. Name the failed read and exit only.
    const code = (result.error as { code?: string } | undefined)?.code;
    unread(place, `${bin} ${code ?? result.signal ?? 'did not exit'}`);
  }
  return { status: result.status, stdout: result.stdout };
}

function command(repo: string, bin: string, args: string[], place: string, input?: string): string {
  const { status, stdout } = run(repo, bin, args, place, input);
  if (status !== 0) return unread(place, `${bin} exit ${status}`);
  return stdout;
}

function hasCommit(repo: string, revision: string, place: string): boolean {
  const query = `${revision}^{commit}`;
  const result = command(repo, 'git', ['cat-file', '--batch-check=%(objecttype)'], place, `${query}\n`);
  if (result === 'commit\n') return true;
  if (result === `${query} missing\n`) return false;
  return unread(place, 'unexpected Git object status');
}

function isAncestor(repo: string, candidate: string, head: string, place: string): boolean {
  if (!hasCommit(repo, candidate, place)) return false;
  const { status } = run(repo, 'git', ['merge-base', '--is-ancestor', candidate, head], place);
  if (status === 0 || status === 1) return status === 0;
  return unread(place, `git exit ${status}`);
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

function escaped(line: string, at: number): boolean {
  let start = at;
  while (line[start - 1] === '\\') start -= 1;
  return (at - start) % 2 === 1;
}

const FENCE = /^(?:(?:[-+*]|\d+[.)])[ \t]+)?(`{3,}|~{3,})(.*)$/;
const BLOCK = /^\s*(?:$|[|>#]|[-+*] +|\d+[.)] +|`{3,}|~{3,})/;
const LIST = /^(?:[-+*]|[0-9]{1,9}[.)])([ 	]{1,4})(?=\S)/;

function indentWidth(prefix: string, start = 0): number {
  let columns = start;
  for (const character of prefix) columns += character === '\t' ? 4 - columns % 4 : 1;
  return columns - start;
}


function visibleLines(text: string): string[] {
  const lines = text.split(/\r?\n/);
  // A code span can cross a line break in a paragraph. Match complete delimiter runs
  // once in reverse, with table rows and other block starts as paragraph boundaries.
  const closes = new Map<string, [number, number]>();
  const next = new Map<number, [number, number]>();
  for (let row = lines.length - 1; row >= 0; row -= 1) {
    const line = lines[row];
    const boundary = BLOCK.test(line);
    if (boundary) next.clear();
    for (const run of [...line.matchAll(/`+/g)].reverse()) {
      const end = next.get(run[0].length);
      if (end) closes.set(`${row}:${run.index}`, end);
      next.set(run[0].length, [row, run.index + run[0].length]);
    }
    if (boundary) next.clear();
  }

  const visible: string[] = [];
  let comment = false;
  let fence: { quoteDepth: number; indent: number; marker: string } | undefined;
  let quoteContext = 0;
  let paragraph = false;
  let indentedCode = false;
  const listColumns = [0];
  let codeEnd: [number, number] | undefined;
  for (const [row, line] of lines.entries()) {
    const quote = /^((?: {0,3}> ?)*)/.exec(line)?.[1] ?? '';
    const quoteMarkers = [...quote.matchAll(/ {0,3}> ?/g)];
    const quoteDepth = quoteMarkers.length;
    const body = line.slice(quote.length);
    const space = /^[ \t]*/.exec(body)?.[0] ?? '';
    const indent = indentWidth(space, quote.length);
    const blank = body.length === space.length;
    if (fence && quoteDepth >= fence.quoteDepth) {
      // Strip only the fence's opening quote container. Deeper quote marks are content.
      const marker = quoteMarkers[fence.quoteDepth - 1];
      const bodyStart = marker ? marker.index + marker[0].length : 0;
      const fenceBody = line.slice(bodyStart);
      const prefix = /^[ \t]*/.exec(fenceBody)?.[0] ?? '';
      const relativeIndent = indentWidth(prefix, bodyStart) - fence.indent;
      if (fenceBody.length === prefix.length || relativeIndent >= 0) {
        if (quoteDepth === fence.quoteDepth && relativeIndent <= 3) {
          const close = /^(`+|~+)[ \t]*$/.exec(fenceBody.slice(prefix.length))?.[1];
          if (close?.[0] === fence.marker[0] && close.length >= fence.marker.length) fence = undefined;
        }
        continue;
      }
    }
    fence = undefined;
    if (quoteContext !== quoteDepth) {
      quoteContext = quoteDepth;
      listColumns.length = 1;
      paragraph = false;
      indentedCode = false;
    }
    if (!comment && !codeEnd) {
      if (blank) {
        paragraph = false;
        continue;
      }
      const item = LIST.exec(body.slice(space.length));
      while (listColumns.length > 1 && indent < listColumns.at(-1)! && (item || !paragraph || BLOCK.test(body))) {
        listColumns.pop();
      }
      const container = listColumns.at(-1)!;
      if (indent >= container + 4 && (indentedCode || !paragraph)) {
        indentedCode = true;
        continue;
      }
      indentedCode = false;
      if (item && indent - container < 4) listColumns.push(indent + indentWidth(item[0], quote.length + indent));
      const opening = indent - container < 4 ? FENCE.exec(body.slice(space.length)) : null;
      if (opening && (opening[1][0] !== '`' || !opening[2].includes('`'))) {
        fence = { quoteDepth, indent: listColumns.at(-1)!, marker: opening[1] };
        paragraph = false;
        continue;
      }
      paragraph = Boolean(item) || !BLOCK.test(body);
    }
    if (codeEnd && row < codeEnd[0]) continue;
    let cursor = codeEnd?.[1] ?? 0;
    codeEnd = undefined;
    let content = '';
    const tokens = /<!--|-->|\x60+/g;
    for (const token of line.matchAll(tokens)) {
      const position = token.index;
      if (position < cursor) continue;
      if (comment) {
        if (token[0] === '-->') {
          comment = false;
          cursor = position + token[0].length;
        }
        continue;
      }
      if (escaped(line, position)) continue;
      if (token[0] === '<!--') {
        content += line.slice(cursor, position) + '\uFFFD';
        comment = true;
      } else {
        const end = closes.get(`${row}:${position}`);
        if (!end) continue;
        content += line.slice(cursor, position) + '\uFFFD';
        if (end[0] !== row) {
          codeEnd = end;
          break;
        }
        cursor = end[1];
      }
    }
    if (!comment && !codeEnd) content += line.slice(cursor);
    visible.push(content);
  }
  return visible;
}

// Historical roster rows use the same anchor inline, including multiple rulings on one table line.
// Plain references and literal examples cannot claim an id.
function anchors(text: string, place: string): Anchor[] {
  const rows: Anchor[] = [];
  for (const line of visibleLines(text)) {
    for (const anchor of line.matchAll(/<a id="hr-/g)) {
      if (escaped(line, anchor.index)) continue;
      const match = /^<a id="hr-([1-9]\d{0,5})"><\/a>\s*\*\*HR-\1\*\*(?!\w)(?: · \[([^\]]+)\]\(ruling-records\/([A-Za-z0-9._-]+--R-\d{4}-\d{2}-\d{2}-\d{2,})\.json\))?/.exec(line.slice(anchor.index));
      if (!match) return unread(place, 'a ruling anchor and its HR id disagree or are malformed');
      rows.push({ number: Number(match[1]), record: match[2] === match[3] ? match[3] : undefined });
    }
  }
  return rows;
}

function diffBlobs(diff: string, file: PullFile, place: string): { before: string; after: string } {
  const header = 'diff --git ';
  const start = `${header}a/${ROSTER} b/${ROSTER}`;
  const lines = diff.split(/\r?\n/);
  const index = lines.indexOf(start);
  if (index < 0 || lines.lastIndexOf(start) !== index) return unread(place, `missing or repeated diff section for ${ROSTER}`);
  let added = 0;
  let removed = 0;
  let blobIds: RegExpExecArray | null = null;
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
      if (line.startsWith('index ')) {
        if (blobIds) return unread(place, `repeated blob ids for ${ROSTER}`);
        blobIds = /^index ([0-9a-f]{7,40})\.\.([0-9a-f]{7,40})(?: [0-7]{6})?$/.exec(line);
        if (!blobIds) return unread(place, `invalid blob ids for ${ROSTER}`);
      }
      oldHeader ||= line === `--- ${file.status === 'added' ? '/dev/null' : `a/${ROSTER}`}`;
      newHeader ||= line === `+++ ${file.status === 'removed' ? '/dev/null' : `b/${ROSTER}`}`;
    } else if (line.startsWith('+')) {
      added += 1;
      after -= 1;
    } else if (line.startsWith('-')) {
      removed += 1;
      before -= 1;
    } else if (line.startsWith(' ')) {
      before -= 1;
      after -= 1;
    } else return unread(place, `unexpected diff line for ${ROSTER}`);
    if (before < 0 || after < 0) return unread(place, `incorrect diff hunk length for ${ROSTER}`);
  }
  if (!blobIds || !inHunk || before !== 0 || after !== 0 || added !== file.additions || removed !== file.deletions) {
    return unread(place, `incomplete diff for ${ROSTER} (${added}/${file.additions} additions, ${removed}/${file.deletions} deletions)`);
  }
  return { before: blobIds[1], after: blobIds[2] };
}

function addedAnchors(oldRoster: string, newRoster: string, place: string): Anchor[] {
  const key = (anchor: Anchor) => `${anchor.number}:${anchor.record ?? ''}`;
  const gone = new Map<string, number>();
  for (const row of anchors(oldRoster, place)) gone.set(key(row), (gone.get(key(row)) ?? 0) + 1);
  return anchors(newRoster, place).filter((row) => {
    const prior = gone.get(key(row)) ?? 0;
    if (prior === 0) return true;
    gone.set(key(row), prior - 1);
    return false;
  });
}

function githubSlug(output: string): string | undefined {
  const remote = output.endsWith('\n') ? output.slice(0, -1) : output;
  if (/[\r\n]/.test(remote)) return undefined;
  return /^(?:git@github\.com:|ssh:\/\/git@github\.com\/|https:\/\/github\.com\/)([A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*?)(?:\.git)?$/.exec(remote)?.[1];
}

type GithubRead = (args: string[], place: string) => string;

function prRosters(gh: GithubRead, slug: string, pr: Pull, file: PullFile, diff: string, place: string): [string, string] {
  const blobs = diffBlobs(diff, file, place);
  const readRoster = (revision: string, prefix: string, role: string): string => {
    const at = `${place} ${role} roster`;
    const text = gh(['api', `repos/${slug}/contents/${ROSTER}?ref=${revision}`, '-H', 'Accept: application/vnd.github.raw+json'], at);
    const oid = createHash('sha1').update(`blob ${Buffer.byteLength(text)}\0`).update(text).digest('hex');
    if (!oid.startsWith(prefix)) return unread(at, 'the immutable roster does not match the diff blob id');
    return text;
  };
  const absent = /^0+$/;
  if (absent.test(blobs.before) !== (file.status === 'added') || absent.test(blobs.after) !== (file.status === 'removed')) {
    return unread(place, 'the diff blob ids disagree with the file status');
  }
  let oldRoster = '';
  if (file.status !== 'added') {
    const at = `${place} merge base`;
    const mergeBase = gh(['api', `repos/${slug}/compare/${pr.baseRefOid}...${pr.headRefOid}?per_page=1`, '--jq', '.merge_base_commit.sha'], at).trim();
    if (!OID.test(mergeBase)) return unread(at, 'expected a commit SHA');
    oldRoster = readRoster(mergeBase, blobs.before, 'old');
  }
  const newRoster = file.status === 'removed' ? '' : readRoster(pr.headRefOid, blobs.after, 'head');
  return [oldRoster, newRoster];
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

// An absent stage-zero record can be an export that has not been staged yet. An unmerged,
// symlink, or unreadable indexed record must never borrow the working copy's identity.
export function readIndexBlob(repo: string, path: string): string | undefined {
  const place = `${path} at effort index`;
  const entry = command(repo, 'git', ['ls-files', '--stage', '-z', '--', path], place);
  if (entry === '') return undefined;
  const match = /^(?:100644|100755) ([0-9a-f]{40}) 0\t([^\0]+)\0$/.exec(entry);
  if (!match || match[2] !== path) return unread(place, 'expected one staged regular file');
  return command(repo, 'git', ['cat-file', 'blob', match[1]], place);
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
  const configured = githubSlug(command(repo, 'git', ['config', '--get-all', 'remote.origin.url'], 'origin URL'));
  const slug = githubSlug(command(repo, 'git', ['remote', 'get-url', '--all', 'origin'], 'effective origin URL'));
  if (!configured || !slug || configured.toLowerCase() !== slug.toLowerCase()) {
    return unread('origin URL', 'expected one GitHub fetch URL with the configured repository identity');
  }

  const tipPlace = `base origin/${base}`;
  const readTip = (): string => {
    const remoteTip = command(repo, 'git', ['ls-remote', '--exit-code', 'origin', ref], tipPlace).trim().split('\t');
    const [revision, reportedRef] = remoteTip;
    if (!revision || !OID.test(revision) || reportedRef !== ref || remoteTip.length !== 2) return unread(tipPlace, 'unexpected ref response');
    return revision;
  };
  const revision = readTip();
  if (!hasCommit(repo, revision, tipPlace)) {
    command(repo, 'git', ['fetch', '--no-tags', '--no-write-fetch-head', 'origin', ref], tipPlace);
  }
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
      && isAncestor(repo, pr.headRefOid, head, `${where} head ancestry`);
    const [oldRoster, newRoster] = prRosters(gh, slug, pr, file, diff, place);
    holders.push(...addedAnchors(oldRoster, newRoster, place).map((row) => ({ ...row, where, own, revision: pr.headRefOid })));
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
