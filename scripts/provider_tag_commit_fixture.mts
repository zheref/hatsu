#!/usr/bin/env node
// Hermetic fixture for scripts/provider_tag_commit.mts: a lightweight and an annotated tag each resolve to
// their COMMIT (the annotated one is never answered with its tag object), a missing tag is exit 1,
// a bad argument exit 2, an unreadable remote exit 3.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = join(resolve(dirname(fileURLToPath(import.meta.url))), 'provider_tag_commit.mts');
const repo = mkdtempSync(join(tmpdir(), 'hatsu-provider-tag-'));
const git = (...args: string[]) => {
  const r = spawnSync('git', ['-C', repo, '-c', 'user.name=fixture', '-c', 'user.email=fixture@invalid', '-c', 'tag.gpgSign=false', '-c', 'commit.gpgSign=false', ...args], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
};
const run = (...args: string[]) => spawnSync('node', [SCRIPT, ...args], { encoding: 'utf8' });
try {
  git('init', '-q');
  writeFileSync(join(repo, 'a'), '1\n'); git('add', 'a'); git('commit', '-q', '-m', 'one');
  const first = git('rev-parse', 'HEAD'); git('tag', 'v1.0.0');
  writeFileSync(join(repo, 'a'), '2\n'); git('commit', '-q', '-am', 'two');
  const second = git('rev-parse', 'HEAD'); git('tag', '-a', 'v2.0.0', '-m', 'annotated');
  const tagObject = git('rev-parse', 'v2.0.0');
  assert.notEqual(tagObject, second, 'the fixture must hold a real annotated tag object');

  const light = run(repo, 'v1.0.0');
  assert.equal(light.status, 0, light.stderr);
  assert.deepEqual(JSON.parse(light.stdout), { tag: 'v1.0.0', kind: 'lightweight', object: first, commit: first });

  const annotated = run(repo, 'v2.0.0');
  assert.equal(annotated.status, 0, annotated.stderr);
  assert.deepEqual(JSON.parse(annotated.stdout), { tag: 'v2.0.0', kind: 'annotated', object: tagObject, commit: second });

  const missing = run(repo, 'v9.9.9');
  assert.equal(missing.status, 1); assert.match(missing.stderr, /has no tag v9\.9\.9/);

  for (const bad of [[], [repo], ['relative/path', 'v1.0.0'], [repo, '--upload-pack=x'], [repo, 'v1;rm'], ['http://github.com/a/b.git', 'v1.0.0'], [repo, 'v1.0.0', 'extra']]) {
    const r = run(...bad); assert.equal(r.status, 2, `${JSON.stringify(bad)}: ${r.stderr}`);
  }
  const unreadable = run(join(repo, 'no-such-repository'), 'v1.0.0');
  assert.equal(unreadable.status, 3); assert.match(unreadable.stderr, /could not read/);
  console.log('provider-tag-commit: lightweight and annotated tags peel to their commits; 1/2/3 refusals hold');
} finally { rmSync(repo, { recursive: true, force: true }); }
