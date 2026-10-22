import { test, expect } from 'vitest';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

test('release notes follow the changelog level and refuse a mixed previous boundary', () => {
  const dir = mkdtempSync(join(tmpdir(), 'hatsu-release-changelog-'));
  const source = join(dir, 'CHANGELOG.md');
  const notes = join(dir, 'notes.md');
  const title = join(dir, 'title.txt');
  const count = join(dir, 'count.txt');
  const helper = join(import.meta.dirname, 'release_changelog.mts');
  const run = (tag: string, previous = '') =>
    spawnSync(process.execPath, [helper, source, tag, previous, notes, title, count], { encoding: 'utf8' });
  try {
    writeFileSync(source, '# Changelog\n### Unreleased\n### v2.0.0 — current\n- new\n### v1.0.0 — previous\n- old\n');
    expect(run('v2.0.0', 'v1.0.0').status).toBe(0);
    expect(readFileSync(notes, 'utf8')).toContain('- new');
    expect(readFileSync(notes, 'utf8')).not.toContain('- old');
    expect(readFileSync(title, 'utf8')).toBe('v2.0.0 — current\n');
    expect(readFileSync(count, 'utf8')).toBe('1\n');

    writeFileSync(source, '# Changelog\n## v2026 — annual\n- shipped\n');
    expect(run('v2026').status).toBe(0);
    expect(readFileSync(title, 'utf8')).toBe('v2026 — annual\n');

    writeFileSync(source, '# Changelog\n### Unreleased\n### v2.0.0 — current\n- new\n## v1.0.0 — previous\n- old\n');
    expect(run('v2.0.0', 'v1.0.0').status).toBe(3);
    writeFileSync(source, '# Changelog\nNo release section.\n');
    expect(run('v2.0.0').status).toBe(4);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
