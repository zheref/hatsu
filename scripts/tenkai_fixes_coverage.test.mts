// HA#535: replays the fix renderer's cases in-process under native Node solely for exact-source LCOV over
// scripts/tenkai_fixes.ts. The authoritative cases are scripts/tenkai_fixes_fixture.test.mts (Vitest).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { adoptionNotices, fixFor, fixRows, guide, quote, resolveAction, type FixRow } from './tenkai_fixes.ts';

const rows = fixRows(resolve(import.meta.dirname, '..'));
const context = { repo: '/tmp/a repo', root: '/opt/hatsu', slug: 'acme/widget' };

test('every fill renders, and an unmatched or unrenderable item is unmapped', () => {
  const cases: [string, string, string, string, string][] = [
    ['dirs/reports', 'missing', 'Reports/ does not exist', '', 'default'],
    ['dirs/reports', 'blocked', 'not a git repository — nothing to ignore', '', 'route'],
    ['nen/workflow.json', 'routed', 'absent', '', 'owner'],
    ['lane/ios/archive', 'routed', 'declared unsupported: PROPOSED SEAT', '', 'edit'],
    ['config/needed', 'routed', '1 value(s) a skill needs have no default: workflow.review.scopes', '', 'owner'],
    ['lane/a\nb/build', 'routed', 'no command is declared', '', 'unmapped'],
  ];
  for (const [id, state, detail, action, fill] of cases) assert.equal(fixFor({ id, state, detail, action }, rows, context).fill, fill, id);
  assert.equal(fixFor({ id: 'scripts/release-publish.sh', state: 'blocked', detail: 'role' }, rows, { ...context, slug: 'bad slug' }).edit?.includes('<owner/name>'), true);
  const broken: FixRow[] = [{ id: '^x$', detect: '{nowhere}', fill: 'route' }, { id: '^[\\s\\S]*$', detect: 'd {repo}', fill: 'unmapped' }];
  assert.match(fixFor({ id: 'x', state: 'routed' }, broken, context).defect ?? '', /not filled/);
  assert.equal(fixFor({ id: 'y', state: 'routed' }, broken, context).rule, '^[\\s\\S]*$');
  assert.equal(fixFor({ id: 'y', state: 'routed' }, [{ id: '^x$', detect: 'd {repo}', fill: 'route' }], context).defect, 'no row matches');
});

test('actions, quoting and the guide', () => {
  assert.equal(resolveAction('x --repo <path>', '/a b'), "x --repo '/a b'");
  assert.equal(resolveAction(null, '/a'), null);
  assert.equal(quote('/plain/path'), '/plain/path');
  const items = [{ id: 'dirs/reports', state: 'missing', fix: fixFor({ id: 'dirs/reports', state: 'missing', detail: 'Reports/ does not exist' }, rows, context) }];
  assert.deepEqual(guide(items).defaults, ['dirs/reports']);
});

test('a malformed catalogue is refused before any write', () => {
  const root = mkdtempSync(join(tmpdir(), 'hatsu-tenkai-fixes-cov-'));
  try {
    mkdirSync(join(root, 'contracts'));
    for (const fixes of [[], [{ id: '^x$', detect: 'd', fill: 'nope' }], [{ id: '^x$', detect: 'd', fill: 'route' }]]) {
      writeFileSync(join(root, 'contracts/tenkai-fixes.json'), JSON.stringify({ fixes }));
      assert.throws(() => fixRows(root));
    }
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('adoptionNotices covers absent, partial, complete, unreadable and symlinked declarations', () => {
  const root = mkdtempSync(join(tmpdir(), 'hatsu-tenkai-notices-cov-'));
  try {
    // Missing workflow -> only missing nen/gates.json and nen/decisions.json.
    assert.deepEqual(adoptionNotices(root).map((n) => n.id), ['nen/gates.json', 'nen/decisions.json']);

    mkdirSync(join(root, 'nen'));
    writeFileSync(join(root, 'nen/workflow.json'), JSON.stringify({ review: { scopes: { code: {} } } }));
    assert.deepEqual(adoptionNotices(root).map((n) => n.id), ['reports.sections', 'review.scopes.architecture', 'nen/gates.json', 'nen/decisions.json']);

    // Symlinked and unparseable workflow do not crash and refuse unsafe paths.
    const linked = mkdtempSync(join(tmpdir(), 'hatsu-tenkai-notices-link-'));
    try {
      mkdirSync(join(linked, 'nen'));
      symlinkSync(join(root, 'nen/workflow.json'), join(linked, 'nen/workflow.json'));
      symlinkSync(join(root, 'nen/missing-gates.json'), join(linked, 'nen/gates.json'));
      symlinkSync(join(root, 'nen/missing-decisions.json'), join(linked, 'nen/decisions.json'));
      assert.deepEqual(adoptionNotices(linked), []);
    } finally { rmSync(linked, { recursive: true, force: true }); }

    // Nonexistent repo and symlinked nen/ directory return [] safely.
    assert.deepEqual(adoptionNotices(join(root, 'does-not-exist')), []);
    const linkDir = mkdtempSync(join(tmpdir(), 'hatsu-tenkai-notices-nendir-'));
    try {
      symlinkSync(join(root, 'nen'), join(linkDir, 'nen'));
      assert.deepEqual(adoptionNotices(linkDir), []);
    } finally { rmSync(linkDir, { recursive: true, force: true }); }

    writeFileSync(join(root, 'nen/workflow.json'), '{ bad json');
    assert.deepEqual(adoptionNotices(root).map((n) => n.id), ['nen/gates.json', 'nen/decisions.json']);

    // Non-file workflow directory refuses cleanly.
    const dirRepo = mkdtempSync(join(tmpdir(), 'hatsu-tenkai-notices-dir-'));
    try {
      mkdirSync(join(dirRepo, 'nen/workflow.json'), { recursive: true });
      writeFileSync(join(dirRepo, 'nen/gates.json'), '{}\n');
      writeFileSync(join(dirRepo, 'nen/decisions.json'), '{}\n');
      assert.deepEqual(adoptionNotices(dirRepo), []);
    } finally { rmSync(dirRepo, { recursive: true, force: true }); }

    // Complete configuration yields zero notices.
    writeFileSync(join(root, 'nen/workflow.json'), JSON.stringify({ reports: { sections: { turn: {} } }, review: { scopes: { architecture: {} } } }));
    writeFileSync(join(root, 'nen/gates.json'), '{}\n');
    writeFileSync(join(root, 'nen/decisions.json'), '{"rows":[]}\n');
    assert.deepEqual(adoptionNotices(root), []);

    // Unknown stamp fix row matches route.
    assert.equal(fixFor({ id: 'pr.sections', state: 'blocked', detail: 'stamp bbbbbbb is newer or unknown' }, rows, context).fill, 'route');
  } finally { rmSync(root, { recursive: true, force: true }); }
});
