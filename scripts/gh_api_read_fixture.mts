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
writeFileSync(gh, '#!/bin/sh\nprintf "%s\\n" "$@" > "$HATSU_GH_CAPTURE"\n');
chmodSync(gh, 0o755);

function run(args: string[], accepted: boolean): string[] {
  rmSync(log, { force: true });
  const result = spawnSync(process.execPath, [entry, ...args], {
    encoding: 'utf8',
    env: { ...process.env, PATH: `${root}${delimiter}${process.env.PATH ?? ''}`, HATSU_GH_CAPTURE: log },
  });
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
  const branch = run(['branch-rules', 'zheref/hatsu', 'feature/read'], true);
  if (branch.join(' ') !== 'api --method GET repos/zheref/hatsu/rules/branches/feature%2Fread') {
    throw new Error('branch rules did not encode the branch in a fixed GET path');
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
