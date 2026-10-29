import { expect, test } from 'claude-code/testing'

import { GLYPHS, HUMAN_FLAG, LABELS, PAST, READINGS, glyphOf, labelOf, readingOf, stepFor } from '../actions'
import type { EffortState } from '../actions'

const base: EffortState = {
  dirty: 0, ahead: 0, hasUpstream: false, unpushed: 0, pr: null, ref: null, code: 'HA', gate: 'G4', base: 'main',
  isStarted: false, isIdeating: false, isDriven: false, atGate: false, isConflicted: false,
}
const started = { ...base, isStarted: true }
const labels = (s: EffortState) => stepFor(s).paths.map(p => p.label)
const open = (s: EffortState) => stepFor(s).paths.filter(p => p.blocked === null).map(p => p.label)
const blocked = (s: EffortState) => stepFor(s).paths.filter(p => p.blocked !== null).map(p => p.label)
const starred = (s: EffortState) => stepFor(s).paths.filter(p => p.isPrimary).map(p => p.label)

test('buttons read in plain English from the matrix', async () => {
  expect(labelOf('hatsu:ren ')).toBe('Build')
  expect(labelOf('hatsu:emperor-time')).toBe('Ideate')
  expect(labelOf('hatsu:spiritual-message')).toBe('Report')
  expect(labelOf('hatsu:en on HA#12')).toBe('Drive PR')
})

test('every labelled skill has an emoji for when it is the starred step', async () => {
  for (const skill of Object.keys(LABELS)) expect(GLYPHS[skill]).toBeTruthy()
  expect(glyphOf('hatsu:tensho main')).toBe('🚀')
  expect(glyphOf('not a skill')).toBe(null)
  // The your-call flag stays a text symbol: only the starred button carries an emoji.
  expect([...HUMAN_FLAG].some(c => c.codePointAt(0)! >= 0x1f000)).toBe(false)
})

test('an issue offers build before anything is authored, and iterate after', async () => {
  expect(stepFor({ ...base, ref: 'HA#473' }).paths.map(p => p.prompt)).toEqual(['hatsu:build HA#473'])
  const after = labels({ ...started, ref: 'HA#473' })
  expect(after[0]).toBe('Iterate')
  expect(after).not.toContain('Build')
  expect(after).not.toContain('File')
})

test('a raw idea starts at ideation, and building it in flight is always open', async () => {
  expect(labels(base)).toEqual(['Ideate', 'Build', 'File'])
  expect(starred(base)).toEqual(['Ideate'])
  expect(labels({ ...base, isIdeating: true })).toEqual(['Ideate', 'Build', 'File'])
})

test('every authored stage shows every path, open ones first, blocked where it must wait', async () => {
  const all = ['Iterate', 'Commit', 'Publish', 'Ship', 'Open PR', 'Catch Up', 'Review', 'Lint', 'Launch', 'File', 'Report']
  expect([...labels(started)].sort()).toEqual([...all].sort())
  expect(labels(started)).toEqual([...open(started), ...blocked(started)])
  expect(blocked(started)).toEqual(['Commit', 'Publish', 'Ship', 'Open PR', 'Review'])
  expect(open(started)).toEqual(['Iterate', 'Catch Up', 'Lint', 'Launch', 'File', 'Report'])
  expect(starred(started)).toEqual(['Iterate'])

  const dirty = { ...started, dirty: 3 }
  expect([...labels(dirty)].sort()).toEqual([...all].sort())
  expect(labels(dirty)).toEqual([...open(dirty), ...blocked(dirty)])
  expect(open(dirty)).toEqual(['Iterate', 'Commit', 'Ship', 'Review', 'Lint', 'Launch', 'File', 'Report'])
  expect(starred(dirty)).toEqual(['Commit'])

  const committed = { ...started, ahead: 2 }
  expect(open(committed)).toEqual(['Iterate', 'Publish', 'Ship', 'Catch Up', 'Review', 'Lint', 'Launch', 'File', 'Report'])
  expect(starred(committed)).toEqual([])

  const pushed = { ...started, ahead: 2, hasUpstream: true }
  expect(blocked(pushed)).toEqual(['Commit', 'Publish'])
  expect(open(pushed)).toEqual(['Iterate', 'Ship', 'Open PR', 'Update', 'Review', 'Lint', 'Launch', 'File', 'Report'])

  // Iterating on top of a published, folded commit: Publish is open again.
  expect(open({ ...pushed, unpushed: 1 })).toContain('Publish')
})

test('an open PR keeps iterating, committing and updating on its branch', async () => {
  const pr = { ...started, ahead: 1, hasUpstream: true, pr: { number: 9, state: 'OPEN' } }
  expect(labels(pr)).toEqual(['Drive PR', 'Unblock PR', 'Iterate', 'Update', 'Review', 'Lint', 'Launch', 'Summary', 'Report', 'Commit'])
  expect(starred(pr)).toEqual(['Drive PR'])
  expect(starred({ ...pr, dirty: 2 })).toEqual(['Commit'])
  // En having run is not readiness: without its Ready stop the PR is driven again.
  expect(stepFor({ ...pr, isDriven: true }).headline).toBe('Driven, readiness unread')
  expect(starred({ ...pr, isDriven: true })).toEqual(['Drive PR'])
  expect(labels({ ...pr, isDriven: true, atGate: true })[0]).toBe('Unblock PR')
  expect(starred({ ...pr, isDriven: true, atGate: true })).toEqual([])
})

test('a PR state the desk does not know offers no PR-less path', async () => {
  const odd = stepFor({ ...started, ahead: 1, hasUpstream: true, pr: { number: 9, state: 'LOCKED' } })
  expect(odd.headline).toBe('PR state unread')
  expect(odd.paths.map(p => p.label)).toEqual(['Report'])
})

test('no copy names a human call as what the effort waits on (HR-370)', async () => {
  for (const s of [{ ...started, ahead: 2 }, { ...started, ahead: 1, hasUpstream: true }]) {
    expect(stepFor(s).why).not.toMatch(/waiting|your call|ends only on/i)
  }
})

test('the wrap-up shows on a merged PR and names the declaration still owed (HR-371)', async () => {
  const merged = stepFor({ ...started, pr: { number: 9, state: 'MERGED' } })
  expect(merged.paths.filter(p => p.blocked === null).map(p => p.label)).toContain('Clean Up')
  expect(merged.paths.some(p => p.isPrimary)).toBe(false)
  expect(merged.why).toContain('satisfied')
})

test('after the PR, the next effort is a fresh build', async () => {
  expect(labels({ ...started, ahead: 1, pr: { number: 9, state: 'MERGED' } })).toEqual(['Clean Up', 'Retro', 'Summary', 'Cut', 'Build', 'Report'])
  expect(labels({ ...started, ahead: 1, pr: { number: 9, state: 'CLOSED' } })).toEqual(['Build', 'Report'])
})

test("the maintainer's own calls are offered, marked, and never starred", async () => {
  const states = [{ ...started, dirty: 1 }, { ...started, ahead: 1 }, { ...started, ahead: 1, hasUpstream: true }]
  for (const s of states) {
    for (const p of stepFor(s).paths) {
      if (/^hatsu:(aka|mukai|tensho)/.test(p.prompt)) {
        expect(p.isHumanCall).toBe(true)
        expect(p.isPrimary).toBe(false)
      }
    }
  }
  expect(starred({ ...started, pr: { number: 1, state: 'MERGED' } })).toEqual([])
})

test('a blocked path is never starred and says what it waits on', async () => {
  for (const s of [started, { ...started, dirty: 1 }, { ...started, ahead: 1 }]) {
    for (const p of stepFor(s).paths) {
      if (p.blocked !== null) {
        expect(p.isPrimary).toBe(false)
        expect(p.blocked.length).toBeGreaterThan(0)
      }
    }
  }
})

test('an open PR fills its own ref and gate', async () => {
  const prompts = stepFor({ ...started, pr: { number: 9, state: 'OPEN' } }).paths.map(p => p.prompt)
  expect(prompts).toContain('hatsu:en on HA#9')
  expect(prompts).toContain('hatsu:sharingan HA#9 to G4')
  expect(stepFor({ ...started, dirty: 1 }).paths.map(p => p.prompt)).toContain('hatsu:tensho main')
})

test('no state ever offers a merge, an upload or a publication', async () => {
  const states = [base, { ...base, ref: 'HA#1' }, started, { ...started, dirty: 1 }, { ...started, ahead: 1 },
    { ...started, pr: { number: 1, state: 'OPEN' } }, { ...started, pr: { number: 1, state: 'MERGED' } }]
  for (const s of states) {
    for (const p of stepFor(s).paths) expect(p.prompt).not.toMatch(/mugetsu|kagutsuchi|merge/)
  }
})

test("another effort's phase reads as what it is doing, not its skill name", async () => {
  expect(readingOf('en')).toBe('Driving PR')
  expect(readingOf('kokusen')).toBe('Committing')
  expect(readingOf('hanten-preflight')).toBe('Reviewing')
  expect(readingOf('aka-publish')).toBe('Publishing')
  expect(readingOf('final-head-verification')).toBe('Verifying')
  expect(readingOf('integrate-ha246')).toBe('Integrating')
  expect(readingOf('kokusen-review-fixes')).toBe('Remediating')
  expect(readingOf('mukai')).toBe('Preparing PR')
  expect(readingOf('some-new-step')).toBe('Some new step')
})

test('a reading turns past tense once its step has ended', async () => {
  expect(readingOf('en', true)).toBe('Drove PR')
  expect(readingOf('kokusen-review-fixes', true)).toBe('Remediated')
  expect(readingOf('some-new-step', true)).toBe('Some new step')
  for (const present of Object.values(READINGS)) expect(PAST[present]).toBeTruthy()
})

test('a conflicted PR stars Update, whatever En has done; uncommitted work comes first', async () => {
  const pr = { ...started, ahead: 1, hasUpstream: true, pr: { number: 9, state: 'OPEN' }, isConflicted: true }
  expect(stepFor(pr).headline).toBe('Conflicts with main')
  expect(starred(pr)).toEqual(['Update'])
  expect(starred({ ...pr, isDriven: true, atGate: true })).toEqual(['Update'])
  expect(starred({ ...pr, dirty: 1 })).toEqual(['Commit'])
})
