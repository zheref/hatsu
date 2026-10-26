#!/usr/bin/env node
// Hermetic, real-Nen proof for Hatsu's top-level mechanical conflict declaration (#415).
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { expect, test } from 'vitest';

type Run = { status: number | null; stdout: string; stderr: string };
type CatchUp = {
  declaration: string;
  classes: { manifest: number; changelog: number; mirror: number; other: number };
  mechanical: boolean;
  conflicted: Array<{ path: string; class: string }>;
  resolve: Array<{ class: string; steps: string[][] }>;
};

const root = resolve(import.meta.dirname, '..');
const nen = process.env.NEN || 'nen';
const liveContract = JSON.parse(readFileSync(join(root, 'nen', 'contract.json'), 'utf8')) as { mechanical?: unknown };

// One identity for every git the fixture or nen spawns: a GitHub-hosted runner has none, and nen's own
// 'git merge' refused with "empty ident name" there (HA-PR-#483's unit-tests run 40369572869).
const fixtureEnv: NodeJS.ProcessEnv = {
  ...process.env,
  GIT_CONFIG_GLOBAL: '/dev/null',
  GIT_CONFIG_SYSTEM: '/dev/null',
  GIT_AUTHOR_NAME: 'Hatsu fixture',
  GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
  GIT_COMMITTER_NAME: 'Hatsu fixture',
  GIT_COMMITTER_EMAIL: 'fixture@example.invalid',
};

function run(cwd: string, exe: string, args: string[], env: NodeJS.ProcessEnv = fixtureEnv): Run {
  const result = spawnSync(exe, args, { cwd, encoding: 'utf8', env });
  if (result.error) throw result.error;
  return { status: result.status, stdout: result.stdout, stderr: result.stderr };
}

function git(cwd: string, ...args: string[]): string {
  const result = run(cwd, 'git', args);
  if (result.status !== 0) throw new Error(`git ${args.join(' ')} failed (${result.status}): ${result.stderr}`);
  return result.stdout.trim();
}

function write(repo: string, path: string, value: string): void {
  mkdirSync(dirname(join(repo, path)), { recursive: true });
  writeFileSync(join(repo, path), value);
}

function conflictRepo(parent: string, name: string, includeOther: boolean): string {
  const origin = join(parent, `${name}.git`);
  const repo = join(parent, name);
  git(parent, 'init', '--bare', '--initial-branch=main', origin);
  git(parent, 'clone', origin, repo);
  write(repo, 'nen/contract.json', `${JSON.stringify({ $schema: 'nen.contract/v0.1', mechanical: liveContract.mechanical }, null, 2)}\n`);
  write(repo, '.claude-plugin/plugin.json', '{"version":"0.0.1"}\n');
  write(repo, 'changelog.d/415.md', 'base changelog\n');
  write(repo, 'surfaces/codex/skills/example/SKILL.md', 'base mirror\n');
  if (includeOther) write(repo, 'manual.txt', 'base manual\n');
  git(repo, 'add', '--', '.');
  git(repo, 'commit', '-m', 'fixture base');
  git(repo, 'push', '-u', 'origin', 'main');

  git(repo, 'checkout', '-b', 'feature');
  write(repo, '.claude-plugin/plugin.json', '{"version":"0.0.2-feature"}\n');
  write(repo, 'changelog.d/415.md', 'feature changelog\n');
  write(repo, 'surfaces/codex/skills/example/SKILL.md', 'feature mirror\n');
  if (includeOther) write(repo, 'manual.txt', 'feature manual\n');
  git(repo, 'add', '--', '.');
  git(repo, 'commit', '-m', 'fixture feature');
  git(repo, 'push', '-u', 'origin', 'feature');

  git(repo, 'checkout', 'main');
  write(repo, '.claude-plugin/plugin.json', '{"version":"0.0.2-main"}\n');
  write(repo, 'changelog.d/415.md', 'main changelog\n');
  write(repo, 'surfaces/codex/skills/example/SKILL.md', 'main mirror\n');
  if (includeOther) write(repo, 'manual.txt', 'main manual\n');
  git(repo, 'add', '--', '.');
  git(repo, 'commit', '-m', 'fixture main moves');
  git(repo, 'push', 'origin', 'main');
  git(repo, 'checkout', 'feature');
  return repo;
}

test('real Nen classes Hatsu mechanical conflicts and fails closed on one other path', () => {
  expect(liveContract.mechanical).toEqual({
    manifests: ['.claude-plugin/plugin.json', '.codex-plugin/plugin.json'],
    changelog: ['changelog.d/**'],
    mirrors: [
      { paths: ['surfaces/codex/**'], regenerate: ['bash', 'scripts/surface_mirror_regenerate.sh'] },
      { paths: ['surfaces/cursor/**'], regenerate: ['bash', 'scripts/surface_mirror_regenerate.sh'] },
      { paths: ['surfaces/antigravity/**'], regenerate: ['bash', 'scripts/surface_mirror_regenerate.sh'] },
    ],
  });
  const scratch = mkdtempSync(join(tmpdir(), 'hatsu-mechanical-conflicts-'));
  try {
    for (const [name, includeOther, expectedExit] of [['mechanical', false, 3], ['mixed', true, 1]] as const) {
      const repo = conflictRepo(scratch, name, includeOther);
      const stopped = run(repo, nen, ['wc', 'catch-up', '--repo', repo, '--base', 'main', '--json']);
      expect(stopped.status, stopped.stderr).toBe(expectedExit);
      const report = JSON.parse(stopped.stdout) as CatchUp;
      expect(report.declaration).toBe('declared');
      expect(report.classes).toEqual({ manifest: 1, changelog: 1, mirror: 1, other: includeOther ? 1 : 0 });
      expect(report.mechanical).toBe(!includeOther);
      expect(report.conflicted.map(({ path, class: kind }) => [path, kind]).sort()).toEqual([
        ['.claude-plugin/plugin.json', 'manifest'],
        ['changelog.d/415.md', 'changelog'],
        ...(includeOther ? [['manual.txt', 'other']] : []),
        ['surfaces/codex/skills/example/SKILL.md', 'mirror'],
      ].sort());
      const mirror = report.resolve.find((group) => group.class === 'mirror');
      expect(mirror?.steps).toContainEqual(['bash', 'scripts/surface_mirror_regenerate.sh']);

      const printed = run(repo, nen, ['wc', 'catch-up', '--repo', repo, '--base', 'main']);
      expect(printed.status).toBe(expectedExit);
      expect(printed.stdout).toContain('$ bash scripts/surface_mirror_regenerate.sh');
      for (const path of report.conflicted.map((row) => row.path)) expect(printed.stdout).toContain(path);
    }
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
});
