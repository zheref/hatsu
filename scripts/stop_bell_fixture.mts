#!/usr/bin/env node
// stop_bell_fixture.mts — hooks/stop-bell.sh rings once per gate and clears only what it rang
// (zheref/hatsu#453 AC-2, AC-4; nen > 0.26.0, zheref/nen#513).
//
// Hermetic and offline: a throwaway git repository, and stub `nen`, `osascript`, `afplay` and `uname`
// first on PATH (the stubs are fixture data; `uname` answers Darwin so rung 2 is osascript on every
// host). The stub nen answers `stop list --json` from a canned file and logs every `stop clear` argv,
// so the hook's own parsing and its clear calls are what is asserted, never nen's behaviour.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, utimesSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const HOOK = join(ROOT, 'hooks/stop-bell.sh');
const temp = mkdtempSync(join(tmpdir(), 'stop-bell-'));
const bin = join(temp, 'bin');
const log = join(temp, 'calls.log');
mkdirSync(bin);
const stub = (name: string, body: string): void => { writeFileSync(join(bin, name), `#!/bin/sh\n${body}\n`); chmodSync(join(bin, name), 0o755); };
stub('osascript', `printf 'osascript %s\\n' "$*" >> "${log}"`);
stub('afplay', `printf 'afplay\\n' >> "${log}"`);
stub('uname', 'echo Darwin');
stub('nen', `case "$1 $2" in
  "stop list") [ -n "$NEN_STUB_LIST" ] && cat "$NEN_STUB_LIST"; exit "\${NEN_STUB_LIST_EXIT:-0}" ;;
  "stop clear") shift 2; printf 'clear %s\\n' "$*" >> "${log}"; exit 0 ;;
esac
exit 2`);

let cases = 0;
function repo(): string {
  const dir = mkdtempSync(join(temp, 'repo-'));
  assert.equal(spawnSync('git', ['init', '-q', dir]).status, 0);
  return dir;
}
function mark(dir: string, effort: string, gate: string, title: string | null): string {
  const folder = join(dir, '.git/.nen/marks', effort === '' ? '_' : encodeURIComponent(effort));
  mkdirSync(folder, { recursive: true });
  const path = join(folder, `${gate}.json`);
  writeFileSync(path, `${JSON.stringify({ contract: 'nen.stop.mark/v0.3', who: 'kurapika', gate, notified: false, at: '2026-10-23T00:00:00.000Z', title, body: null, reportUrl: null, options: null, proposedIssue: null, effort: effort === '' ? null : effort }, null, 2)}\n`);
  return path;
}
function listing(dir: string, rows: Array<{ source: string; path: string; gate: string }>, unreadable: string[] = []): string {
  const path = join(dir, 'list.json');
  writeFileSync(path, `${JSON.stringify({ contract: 'nen.stop.list/v0.1', dir: join(dir, '.git/.nen/marks'), marks: rows.map((r) => ({ source: r.source, path: r.path, contract: 'nen.stop.mark/v0.3', gate: r.gate, effort: null, who: 'kurapika', at: '2026-10-23T00:00:00.000Z', title: null })), unreadable: unreadable.map((p) => ({ path: p, reason: 'unparseable' })) }, null, 2)}\n`);
  return path;
}
function hook(dir: string, env: Record<string, string> = {}, path = `${bin}:/usr/bin:/bin`): string[] {
  rmSync(log, { force: true });
  const result = spawnSync('sh', [HOOK], { input: JSON.stringify({ cwd: dir }), encoding: 'utf8', env: { PATH: path, HOME: temp, TMPDIR: temp, ...env } });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, '', 'the hook never writes to stdout');
  cases++;
  return existsSync(log) ? readFileSync(log, 'utf8').trim().split('\n').filter(Boolean) : [];
}

try {
  // 1. Three gates, three bells, three clears: each its own gate and effort; a legacy row is bare clear.
  {
    const dir = repo();
    const a = mark(dir, 'HA-IS-#1', 'G2', 'merge one');
    const b = mark(dir, '', 'G4', null);
    mkdirSync(join(dir, '.nen'));
    const single = join(dir, '.nen/last-stop.json');
    writeFileSync(single, `${JSON.stringify({ contract: 'nen.stop.mark/v0.1', who: 'kurapika', gate: 'G5', notified: false, at: '2026-10-22T00:00:00.000Z' }, null, 2)}\n`);
    const calls = hook(dir, { NEN_STUB_LIST: listing(dir, [{ source: 'gate', path: a, gate: 'G2' }, { source: 'gate', path: b, gate: 'G4' }, { source: 'legacy', path: single, gate: 'G5' }]) });
    assert.deepEqual(calls.filter((c) => c.startsWith('osascript')).map((c) => /Hatsu — (G\d): ([^ ]+ ?[^ ]*)/.exec(c)?.[1]), ['G2', 'G4', 'G5']);
    assert.ok(calls.some((c) => c.includes('Hatsu — G2: merge one')));
    assert.deepEqual(calls.filter((c) => c.startsWith('clear')), [`clear --gate G2 --effort HA-IS-#1 --repo ${dir}`, `clear --gate G4 --repo ${dir}`, `clear --repo ${dir}`]);
  }
  // 2. A stale marker is cleared and never rung; an unreadable row is neither rung nor cleared.
  {
    const dir = repo();
    const stale = mark(dir, 'HA-IS-#2', 'G5', 'old');
    const old = new Date(Date.now() - 3600_000);
    utimesSync(stale, old, old);
    const calls = hook(dir, { NEN_STUB_LIST: listing(dir, [{ source: 'gate', path: stale, gate: 'G5' }], [join(dir, '.git/.nen/marks/x/G2.json')]), NEN_STUB_LIST_EXIT: '1' });
    assert.equal(calls.filter((c) => c.startsWith('osascript')).length, 0);
    assert.deepEqual(calls.filter((c) => c.startsWith('clear')), [`clear --gate G5 --effort HA-IS-#2 --repo ${dir}`]);
  }
  // 3. HATSU_ATTENTION=off rings nothing and still consumes.
  {
    const dir = repo();
    const a = mark(dir, 'HA-IS-#3', 'G2', 'quiet');
    const calls = hook(dir, { HATSU_ATTENTION: 'off', NEN_STUB_LIST: listing(dir, [{ source: 'gate', path: a, gate: 'G2' }]) });
    assert.equal(calls.filter((c) => c.startsWith('osascript')).length, 0);
    assert.equal(calls.filter((c) => c.startsWith('clear')).length, 1);
  }
  // 4. A nen without `stop list` (0.26.0): the single file rings once and is consumed by bare clear.
  {
    const dir = repo();
    mkdirSync(join(dir, '.nen'));
    writeFileSync(join(dir, '.nen/last-stop.json'), `${JSON.stringify({ contract: 'nen.stop.mark/v0.2', who: 'kurapika', gate: 'G5', notified: true, at: '2026-10-23T00:00:00.000Z', title: 'one file', body: 'b', reportUrl: null, options: [], proposedIssue: null }, null, 2)}\n`);
    const calls = hook(dir, { NEN_STUB_LIST_EXIT: '2' });
    assert.equal(calls.filter((c) => c.startsWith('osascript')).length, 1);
    assert.ok(calls.some((c) => c.includes('Hatsu — G5: one file')));
    assert.deepEqual(calls.filter((c) => c.startsWith('clear')), [`clear --repo ${dir}`]);
  }
  // 5. No nen on PATH at all: the single file is rung and removed by the hook itself.
  {
    const dir = repo();
    mkdirSync(join(dir, '.nen'));
    const single = join(dir, '.nen/last-stop.json');
    writeFileSync(single, `${JSON.stringify({ contract: 'nen.stop.mark/v0.1', who: 'kurapika', gate: 'G2', notified: false, at: '2026-10-23T00:00:00.000Z' }, null, 2)}\n`);
    const nonen = join(temp, 'nonen');
    mkdirSync(nonen, { recursive: true });
    for (const name of ['osascript', 'afplay', 'uname']) writeFileSync(join(nonen, name), readFileSync(join(bin, name)), { mode: 0o755 });
    const calls = hook(dir, {}, `${nonen}:/usr/bin:/bin`);
    assert.equal(calls.filter((c) => c.startsWith('osascript')).length, 1);
    assert.equal(existsSync(single), false);
  }
  // 6. Nothing marked: the hook exits before calling nen.
  {
    const dir = repo();
    const calls = hook(dir, { NEN_STUB_LIST: listing(dir, []) });
    assert.deepEqual(calls, []);
  }
  console.log(`stop-bell fixture: ${cases} cases passed (one bell per gate, per-gate clears, stale and off consumed, unreadable untouched, 0.26 and no-nen fallbacks, idle exit)`);
} finally {
  rmSync(temp, { recursive: true, force: true });
}
