#!/usr/bin/env node
// #326: the fake gh records argv; rejected input must never reach it.
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = mkdtempSync(join(tmpdir(), 'hatsu-gh-api-read-'));
const gh = join(root, 'gh');
const log = join(root, 'argv');
const entry = join(import.meta.dirname, 'gh_api_read.mts');
// A literal copy, not an import: importing the entrypoint would run its CLI. A drifted projection fails here.
const PR_HEAD_PROJECTION = '{number,state,draft,title,head:.head.sha,headRef:.head.ref,headRepo:.head.repo.full_name,baseRef:.base.ref,baseRepo:.base.repo.full_name}';
writeFileSync(gh, '#!/bin/sh\nprintf "%s\\n" "$@" > "$HATSU_GH_CAPTURE"\nprintf "%s" "$HATSU_GH_RESPONSE"\nexit "${HATSU_GH_EXIT:-0}"\n');
chmodSync(gh, 0o755);

function invoke(args: string[], response = '', status = '0') {
  rmSync(log, { force: true });
  return spawnSync(process.execPath, [entry, ...args], {
    encoding: 'utf8',
    env: { ...process.env, PATH: `${root}${delimiter}${process.env.PATH ?? ''}`, HATSU_GH_CAPTURE: log,
      HATSU_GH_RESPONSE: response, HATSU_GH_EXIT: status },
  });
}

function run(args: string[], accepted: boolean, response = ''): string[] {
  const result = invoke(args, response);
  if (accepted && (result.status !== 0 || !existsSync(log))) {
    throw new Error(`valid read rejected: ${args.join(' ')}: ${result.stderr}`);
  }
  if (!accepted && (result.status !== 2 || existsSync(log))) {
    throw new Error(`hostile read reached gh or had wrong exit: ${args.join(' ')}: ${result.stderr}`);
  }
  return accepted ? readFileSync(log, 'utf8').trimEnd().split('\n') : [];
}

try {
  const privateRepos = run(['private-repos'], true);
  if (privateRepos.join(' ') !== 'api --method GET user/repos?visibility=private&per_page=100 --paginate --jq .[].full_name') {
    throw new Error('private repository list lost GET, query, pagination or projection');
  }
  const methods = run(['repo-merge-methods', 'zheref/hatsu'], true);
  if (methods.join(' ') !== 'api --method GET repos/zheref/hatsu --jq {allow_merge_commit,allow_squash_merge,allow_rebase_merge}') {
    throw new Error('repository merge methods must use the fixed GET and projection');
  }
  const protection = run(['branch-protection', 'zheref/hatsu', 'feature/read'], true);
  if (protection.join(' ') !== 'api --method GET repos/zheref/hatsu/branches/feature%2Fread/protection --jq {required_linear_history: .required_linear_history.enabled}') {
    throw new Error('branch protection must use the fixed GET and linear history projection');
  }
  const branchArgs = ['branch-rules', 'zheref/hatsu', 'feature/read'];
  const branch = run(branchArgs, true, '[]\n');
  const pageFilter = 'if type == "array" then @json else error("expected branch rules array") end';
  if (branch.join(' ') !== 'api --method GET repos/zheref/hatsu/rules/branches/feature%2Fread --paginate --jq ' + pageFilter) {
    throw new Error('branch rules must use the fixed GET and compact page filter supported by older gh');
  }
  const empty = invoke(branchArgs, '[]\n');
  if (empty.status !== 0 || empty.stdout.trim() !== '[]') throw new Error('an empty page is a valid rules result');
  const rules = [
    {type: 'commit_message_pattern', parameters: {pattern: 'first\nsecond'}},
    {type: 'pull_request', parameters: {allowed_merge_methods: ['squash']}},
  ];
  const complete = invoke(branchArgs, JSON.stringify([rules[0]]) + '\n' + JSON.stringify([rules[1]]) + '\n');
  if (complete.status !== 0 || complete.stdout.trim() !== JSON.stringify(rules)) {
    throw new Error('branch rules lost a later page, an escaped newline or the flat response');
  }
  for (const [response, status] of [
    ['[{"type":"deletion"}]\n{}\n', '0'],
    ['[{"type":"deletion"}]\n[\n', '0'],
    ['', '0'],
    ['[{"type":"deletion"}]\n', '1'],
  ]) {
    const incomplete = invoke(branchArgs, response, status);
    if (incomplete.status === 0 || incomplete.stdout !== '') throw new Error('an incomplete branch rules response escaped');
  }
  const queue = run(['pr-merge-queue', 'zheref/hatsu', '42'], true);
  if (queue.slice(0, 3).join(' ') !== 'api graphql -f' ||
      !queue[3].startsWith('query=query ReadMergeQueue(') || !queue[3].includes('headRefOid baseRefName mergeQueue{id}') ||
      queue.slice(4).join(' ') !== '-f owner=zheref -f repo=hatsu -F number=42' ||
      queue.some(part => /\bmutation\b/.test(part))) {
    throw new Error('PR merge queue read must use the fixed, ref-pinned query');
  }
  const checks = run(['required-checks', 'zheref/hatsu', 'main'], true);
  if (checks.join(' ') !== 'api --method GET repos/zheref/hatsu/branches/main/protection/required_status_checks') {
    throw new Error('required checks are not a fixed GET path');
  }
  const issue = run(['issue-pr', 'zheref/hatsu', '326'], true);
  if (issue.join(' ') !== 'api --method GET repos/zheref/hatsu/issues/326 --jq .pull_request') {
    throw new Error('issue-to-PR lookup is not a fixed GET');
  }
  const head = run(['pr-head', 'zheref/hatsu', '577'], true);
  if (head.slice(0, 4).join(' ') !== 'api --method GET repos/zheref/hatsu/pulls/577' || head[4] !== '--jq' ||
      head[5] !== PR_HEAD_PROJECTION || head.length !== 6 || !/head:\.head\.sha/.test(PR_HEAD_PROJECTION) ||
      !/headRepo:\.head\.repo\.full_name/.test(PR_HEAD_PROJECTION) || !/baseRepo:\.base\.repo\.full_name/.test(PR_HEAD_PROJECTION)) {
    throw new Error('PR head read is not a fixed GET projecting head SHA and both repositories');
  }
  const workflow = run(['workflow-content', 'zheref/hatsu', 'main'], true);
  if (workflow.join(' ') !== 'api --method GET repos/zheref/hatsu/contents/nen/workflow.json?ref=main -H Accept: application/vnd.github.raw') {
    throw new Error('workflow content lost the fixed ref query or raw header');
  }
  for (const [operation, expected] of [
    ['actions-timing', 'api --method GET repos/zheref/hatsu/actions/runs/42/timing'],
    ['actions-caches', 'api --method GET repos/zheref/hatsu/actions/caches'],
    ['actions-artifacts', 'api --method GET repos/zheref/hatsu/actions/artifacts'],
    ['tag-ref', 'api --method GET repos/zheref/hatsu/git/ref/tags/v1.2.3'],
  ]) {
    const args = operation === 'actions-timing' ? [operation, 'zheref/hatsu', '42'] :
      operation === 'tag-ref' ? [operation, 'zheref/hatsu', 'v1.2.3'] : [operation, 'zheref/hatsu'];
    if (run(args, true).join(' ') !== expected) throw new Error(`${operation} is not a fixed GET`);
  }
  const edits = run(['issue-edits', 'zheref/hatsu', '326'], true);
  if (edits[0] !== 'api' || edits[1] !== 'graphql' || !edits[3].startsWith('query=query ReadIssueEdits(') ||
      edits.some((part) => /\bmutation\b|mergePullRequest/i.test(part))) {
    throw new Error('GraphQL operation is not the fixed read query');
  }
  for (const args of [
    ['--method', 'POST', 'repos/zheref/hatsu/issues'],
    ['private-repos', '--method', 'POST'],
    ['private-repos', '-X', 'PUT'],
    ['private-repos', '--input', '/tmp/body'],
    ['private-repos', '-f', 'x=y'],
    ['private-repos', '-F', 'x=y'],
    ['branch-rules', 'zheref/hatsu', 'main', '--method', 'PATCH'],
    ['branch-rules', 'zheref/hatsu', '--method'],
    ['repo-merge-methods', 'zheref/hatsu', '--method', 'PATCH'],
    ['branch-protection', 'zheref/hatsu', 'main', '--method', 'DELETE'],
    ['pr-merge-queue', 'zheref/hatsu', '42', 'mutation'],
    ['issue-pr', 'zheref/hatsu', '1/pulls/1/merge'],
    ['issue-pr', 'zheref/hatsu', '0'],
    ['tag-ref', 'zheref/hatsu', '../pulls/1/merge'],
    ['pr-head', 'zheref/hatsu', '1/merge'],
    ['pr-head', 'zheref/hatsu', '577', '--method', 'PUT'],
    ['graphql', 'mutation { mergePullRequest(input:{pullRequestId:"x"}) { clientMutationId } }'],
    ['issue-edits', 'zheref/hatsu', '326', 'mutation { mergePullRequest }'],
    ['actions-timing', 'zheref/hatsu', '123', '--method', 'DELETE'],
  ]) run(args, false);
  console.log('gh-api-read-fixture: fixed REST and GraphQL reads pass; hostile arguments never invoke gh');
} finally {
  rmSync(root, { recursive: true, force: true });
}
