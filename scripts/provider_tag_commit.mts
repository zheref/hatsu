#!/usr/bin/env node
// HA#331 (kuchiyose § 2): the COMMIT a provider release tag names, peeled. `git/ref/tags/<tag>` answers the
// tag OBJECT for an annotated tag, so comparing it with a commit refuses every annotated pin; this reads
// `git ls-remote --tags <remote> refs/tags/<tag> refs/tags/<tag>^{}` and takes the peeled line when present.
//
//   node scripts/provider_tag_commit.mts <remote> <tag>
//
// <remote> is https://github.com/<owner>/<repo>.git or an absolute local path. Prints one JSON line:
// { tag, kind: "annotated" | "lightweight", object, commit }.
// exit 0 resolved · 1 no such tag on the remote (found nothing) · 2 usage · 3 the remote could not be read
import { spawnSync } from 'node:child_process';
import { isAbsolute } from 'node:path';

const TAG = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const REMOTE = /^https:\/\/github\.com\/[A-Za-z0-9][A-Za-z0-9_.-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*\.git$/;
const SHA = /^[0-9a-f]{40}$/;

export function peel(listing: string, tag: string): { kind: string; object: string; commit: string } | null {
  let object = '', peeled = '';
  for (const line of listing.split('\n')) {
    if (!line.trim()) continue;
    const [sha, ref] = line.split('\t');
    if (!SHA.test(sha ?? '')) throw new Error(`unreadable ls-remote line: ${JSON.stringify(line)}`);
    if (ref === `refs/tags/${tag}`) object = sha;
    else if (ref === `refs/tags/${tag}^{}`) peeled = sha;
    else throw new Error(`ls-remote answered a ref that was not asked for: ${JSON.stringify(ref)}`);
  }
  if (!object) return null;
  return peeled ? { kind: 'annotated', object, commit: peeled } : { kind: 'lightweight', object, commit: object };
}

function main(argv: string[]): number {
  const [remote, tag, extra] = argv;
  if (extra !== undefined || !remote || !tag || !TAG.test(tag) || !(REMOTE.test(remote) || (isAbsolute(remote) && !remote.startsWith('-')))) {
    console.error('provider-tag-commit: usage: provider_tag_commit.mts <https://github.com/<owner>/<repo>.git | absolute path> <tag>');
    return 2;
  }
  const run = spawnSync('git', ['ls-remote', '--tags', remote, `refs/tags/${tag}`, `refs/tags/${tag}^{}`], {
    encoding: 'utf8', env: { ...process.env, GIT_TERMINAL_PROMPT: '0' },
  });
  if (run.error || run.status !== 0) {
    console.error(`provider-tag-commit: could not read ${remote}: ${(run.error?.message ?? run.stderr ?? '').trim().split('\n')[0]}`);
    return 3;
  }
  let result;
  try { result = peel(run.stdout, tag); } catch (error) {
    console.error(`provider-tag-commit: could not read ${remote}: ${(error as Error).message}`);
    return 3;
  }
  if (!result) { console.error(`provider-tag-commit: ${remote} has no tag ${tag}`); return 1; }
  console.log(JSON.stringify({ tag, ...result }));
  return 0;
}

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].split('/').pop() ?? '')) process.exitCode = main(process.argv.slice(2));
