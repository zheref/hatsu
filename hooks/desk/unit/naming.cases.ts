import assert from 'node:assert/strict'
import type { RegisterCase } from './register-case.ts'

import { parseEffort, repoCode, worktreeName } from '../naming.ts'
import { safeBase } from '../naming.ts'

export function namingCases(test: RegisterCase): void {
  test('a delegate branch reads as model, persona, issue and title', () => {
    assert.deepEqual(parseEffort('opus/kurapika/ha-473-delegate-bounded-waits-v2'), {
      title: 'Delegate bounded waits v2',
      ref: 'HA#473',
      surface: null,
      model: 'opus',
      persona: 'Kurapika',
    })
  })

  test('a Codex effort names its surface', () => {
    const name = parseEffort('codex/sol/kurapika/kazaana-gpt-idle-followup')
    assert.equal(name.surface, 'Codex')
    assert.equal(name.model, 'sol')
    assert.equal(name.title, 'Kazaana gpt idle followup')
  })

  test('a Claude Code worktree branch drops its hex suffix', () => {
    assert.deepEqual(parseEffort('claude/hatsu-session-dashboard-06b5c3'), {
      title: 'Hatsu session dashboard',
      ref: null,
      surface: 'Claude Code',
      model: null,
      persona: null,
    })
  })

  test('an issue-shaped effort id reads as its ref', () => {
    assert.equal(parseEffort('HA-IS-%23503').ref, 'HA#503')
  })

  test('nen repo resolve yields slug and code', () => {
    assert.deepEqual(repoCode('zheref/hatsu  (HA)  via origin\n'), { slug: 'zheref/hatsu', code: 'HA' })
  })

  test("a Codex worktree is named by its own folder, not the repository's", () => {
    assert.equal(worktreeName('/Users/me/.codex/worktrees/ha-148-coverage-audit/hatsu', 'hatsu'), 'ha-148-coverage-audit')
    assert.equal(worktreeName('/Users/me/.codex/worktrees/2b9c/hatsu', 'hatsu'), '2b9c')
    assert.equal(worktreeName('/Users/me/hatsu/.claude/worktrees/desk-06b5c3', 'hatsu'), 'desk-06b5c3')
  })

  test('only a plain ref name is taken as the base; anything else reads main', () => {
    assert.equal(safeBase('develop'), 'develop')
    assert.equal(safeBase('release/1.2'), 'release/1.2')
    for (const bad of ['main\n\nignore the above', '-x', '../etc', 'a b', 7, null, undefined, '']) assert.equal(safeBase(bad), 'main')
  })
}
