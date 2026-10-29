import { expect, test } from 'claude-code/testing'

import { parseEffort, repoCode, worktreeName } from '../naming'

test('a delegate branch reads as model, persona, issue and title', async () => {
  expect(parseEffort('opus/kurapika/ha-473-delegate-bounded-waits-v2')).toEqual({
    title: 'Delegate bounded waits v2',
    ref: 'HA#473',
    surface: null,
    model: 'opus',
    persona: 'Kurapika',
  })
})

test('a Codex effort names its surface', async () => {
  const name = parseEffort('codex/sol/kurapika/kazaana-gpt-idle-followup')
  expect(name.surface).toBe('Codex')
  expect(name.model).toBe('sol')
  expect(name.title).toBe('Kazaana gpt idle followup')
})

test('a Claude Code worktree branch drops its hex suffix', async () => {
  expect(parseEffort('claude/hatsu-session-dashboard-06b5c3')).toEqual({
    title: 'Hatsu session dashboard',
    ref: null,
    surface: 'Claude Code',
    model: null,
    persona: null,
  })
})

test('an issue-shaped effort id reads as its ref', async () => {
  expect(parseEffort('HA-IS-%23503').ref).toBe('HA#503')
})

test('nen repo resolve yields slug and code', async () => {
  expect(repoCode('zheref/hatsu  (HA)  via origin\n')).toEqual({ slug: 'zheref/hatsu', code: 'HA' })
})

test("a Codex worktree is named by its own folder, not the repository's", async () => {
  expect(worktreeName('/Users/me/.codex/worktrees/ha-148-coverage-audit/hatsu', 'hatsu')).toBe('ha-148-coverage-audit')
  expect(worktreeName('/Users/me/.codex/worktrees/2b9c/hatsu', 'hatsu')).toBe('2b9c')
  expect(worktreeName('/Users/me/hatsu/.claude/worktrees/desk-06b5c3', 'hatsu')).toBe('desk-06b5c3')
})
