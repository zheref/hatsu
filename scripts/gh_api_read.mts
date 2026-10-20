#!/usr/bin/env node
// #326: named GitHub API reads. Callers never supply an HTTP method, endpoint,
// gh option, request body, or GraphQL source.
import { spawnSync } from 'node:child_process';

const usage = 'usage: node scripts/gh_api_read.mts <private-repos|branch-rules|required-checks|issue-pr|workflow-content|actions-timing|actions-caches|actions-artifacts|tag-ref|issue-edits> [arguments]';

function fail(reason: string): never {
  throw new Error(`${reason}\n${usage}`);
}

function slug(value: string | undefined): [string, string] {
  if (!value || !/^[A-Za-z0-9][A-Za-z0-9_.-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(value)) {
    fail('expected owner/repository');
  }
  const [owner, repo] = value.split('/');
  if (owner === '..' || repo === '..') fail('invalid owner/repository');
  return [owner, repo];
}

function positive(value: string | undefined): string {
  if (!value || !/^[1-9][0-9]*$/.test(value) || !Number.isSafeInteger(Number(value))) {
    fail('expected a positive integer');
  }
  return value;
}

function segment(value: string | undefined): string {
  if (!value || value.startsWith('-') || /[\x00-\x1f\x7f]/.test(value) ||
      value.split('/').some((part) => part === '' || part === '.' || part === '..')) {
    fail('expected a nonempty path segment');
  }
  return encodeURIComponent(value);
}

function exact(args: string[], count: number): void {
  if (args.length !== count) fail('wrong number of arguments');
}

export function readCommand(args: string[]): string[] {
  const [operation, ...values] = args;
  switch (operation) {
    case 'private-repos':
      exact(values, 0);
      return ['api', '--method', 'GET', 'user/repos?visibility=private&per_page=100', '--paginate', '--jq', '.[].full_name'];
    case 'branch-rules': {
      exact(values, 2);
      const [owner, repo] = slug(values[0]);
      return ['api', '--method', 'GET', `repos/${owner}/${repo}/rules/branches/${segment(values[1])}`];
    }
    case 'required-checks': {
      exact(values, 2);
      const [owner, repo] = slug(values[0]);
      return ['api', '--method', 'GET', `repos/${owner}/${repo}/branches/${segment(values[1])}/protection/required_status_checks`];
    }
    case 'issue-pr': {
      exact(values, 2);
      const [owner, repo] = slug(values[0]);
      return ['api', '--method', 'GET', `repos/${owner}/${repo}/issues/${positive(values[1])}`, '--jq', '.pull_request'];
    }
    case 'workflow-content': {
      exact(values, 2);
      const [owner, repo] = slug(values[0]);
      return ['api', '--method', 'GET', `repos/${owner}/${repo}/contents/nen/workflow.json?ref=${segment(values[1])}`, '-H', 'Accept: application/vnd.github.raw'];
    }
    case 'actions-timing':
    case 'actions-caches':
    case 'actions-artifacts': {
      exact(values, operation === 'actions-timing' ? 2 : 1);
      const [owner, repo] = slug(values[0]);
      const endpoint = operation === 'actions-timing' ? `runs/${positive(values[1])}/timing` : operation.slice('actions-'.length);
      return ['api', '--method', 'GET', `repos/${owner}/${repo}/actions/${endpoint}`];
    }
    case 'tag-ref': {
      exact(values, 2);
      const [owner, repo] = slug(values[0]);
      return ['api', '--method', 'GET', `repos/${owner}/${repo}/git/ref/tags/${segment(values[1])}`];
    }
    case 'issue-edits': {
      exact(values, 2);
      const [owner, repo] = slug(values[0]);
      const issue = positive(values[1]);
      const query = 'query ReadIssueEdits($owner:String!,$repo:String!,$issue:Int!){repository(owner:$owner,name:$repo){issue(number:$issue){userContentEdits(first:50){totalCount}}}}';
      return ['api', 'graphql', '-f', `query=${query}`, '-F', `owner=${owner}`, '-F', `repo=${repo}`, '-F', `issue=${issue}`];
    }
    default:
      return fail('unknown read operation');
  }
}

try {
  const command = readCommand(process.argv.slice(2));
  const result = spawnSync('gh', command, { stdio: 'inherit', shell: false });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} catch (error) {
  console.error(`gh-api-read: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 2;
}
