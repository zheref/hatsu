import { test, expect } from 'vitest';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

test('Tenkai renders only its own publisher and helper', () => {
  const root = mkdtempSync(join(tmpdir(), 'hatsu-release-adopt-'));
  const source = join(root, 'hatsu');
  const repo = join(root, 'consumer');
  const scripts = join(repo, 'scripts');
  const guard = join(import.meta.dirname, 'tenkai_release_guard.mts');
  const marker = (name: string) => `// RENDERED BY hatsu:tenkai from \`templates/${name}\`\n`;
  const run = (mode: string, nodeArgs: string[] = [], extraEnv: Record<string, string> = {}) => {
    const result = spawnSync(process.execPath, [...nodeArgs, guard, mode, repo, source], {
      encoding: 'utf8', env: { ...process.env, ...extraEnv },
    });
    expect(result.status, result.stderr).toBe(0);
    return JSON.parse(result.stdout) as { state: string; detail: string };
  };
  try {
    mkdirSync(join(source, 'templates'), { recursive: true });
    mkdirSync(scripts, { recursive: true });
    writeFileSync(join(source, 'templates', 'release-publish.sh'), marker('release-publish.sh') + 'echo release\n');
    writeFileSync(join(source, 'templates', 'release_changelog.mts'), marker('release_changelog.mts') + 'export {};\n');
    expect(run('diagnose').state).toBe('missing');
    expect(run('apply').state).toBe('repaired');
    expect(run('diagnose').state).toBe('satisfied');
    expect(readFileSync(join(scripts, 'release_changelog.mts'), 'utf8')).toContain('export {}');

    writeFileSync(join(scripts, 'release_changelog.mts'), marker('release_changelog.mts') + 'old\n');
    expect(run('diagnose').state).toBe('drift');
    expect(run('apply').state).toBe('repaired');
    expect(run('diagnose').state).toBe('satisfied');

    writeFileSync(join(scripts, 'release_changelog.mts'), 'foreign helper\n');
    expect(run('apply').state).toBe('drift');
    expect(readFileSync(join(scripts, 'release_changelog.mts'), 'utf8')).toBe('foreign helper\n');
    rmSync(join(scripts, 'release_changelog.mts'));
    symlinkSync(join(source, 'templates', 'release_changelog.mts'), join(scripts, 'release_changelog.mts'));
    expect(run('apply').state).toBe('blocked');

    rmSync(join(scripts, 'release_changelog.mts'));
    const preload = join(root, 'race.mjs');
    writeFileSync(preload, `import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
const rename = fs.renameSync;
fs.renameSync = (from, to) => {
  rename(from, to);
  if (to.endsWith('/release-publish.sh')) fs.writeFileSync(process.env.HATSU_TEST_HELPER, 'foreign race\\n');
};
syncBuiltinESMExports();
`);
    expect(run('apply', ['--import', preload], { HATSU_TEST_HELPER: join(scripts, 'release_changelog.mts') }).state).toBe('blocked');
    expect(readFileSync(join(scripts, 'release_changelog.mts'), 'utf8')).toBe('foreign race\n');

    writeFileSync(join(scripts, 'release_changelog.mts'), marker('release_changelog.mts') + 'old\n');
    const inspectRace = join(root, 'inspect-race.mjs');
    writeFileSync(inspectRace, `import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
const read = fs.readFileSync;
let seen = 0;
fs.readFileSync = (path, ...args) => {
  const value = read(path, ...args);
  if (String(path) === process.env.HATSU_TEST_HELPER && ++seen === 2) fs.writeFileSync(path, 'foreign during inspect\\n');
  return value;
};
syncBuiltinESMExports();
`);
    expect(run('apply', ['--import', inspectRace], { HATSU_TEST_HELPER: join(scripts, 'release_changelog.mts') }).state).toBe('blocked');
    expect(readFileSync(join(scripts, 'release_changelog.mts'), 'utf8')).toBe('foreign during inspect\n');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
