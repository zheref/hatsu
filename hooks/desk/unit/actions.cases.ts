import assert from 'node:assert/strict'
import type { RegisterCase } from './register-case.ts'

import { GLYPHS, HUMAN_FLAG, LABELS, PAST, READINGS, glyphOf, labelOf, readingOf, stepFor } from '../actions.ts'
import type { EffortState } from '../actions.ts'

const base: EffortState = {
  dirty: 0, ahead: 0, hasUpstream: false, unpushed: 0, pr: null, ref: null, code: 'HA', gate: 'G4', base: 'main',
  isStarted: false, isIdeating: false, isDriven: false, atGate: false, isConflicted: false, hasBase: false,
}
const started = { ...base, isStarted: true }
const labels = (s: EffortState) => stepFor(s).paths.map(p => p.label)
const open = (s: EffortState) => stepFor(s).paths.filter(p => p.blocked === null).map(p => p.label)
const blocked = (s: EffortState) => stepFor(s).paths.filter(p => p.blocked !== null).map(p => p.label)
const starred = (s: EffortState) => stepFor(s).paths.filter(p => p.isPrimary).map(p => p.label)

export function actionsCases(test: RegisterCase): void {
  test('buttons read in plain English from the matrix', () => {
    assert.equal(labelOf('hatsu:ren '), 'Build')
    assert.equal(labelOf('hatsu:emperor-time'), 'Ideate')
    assert.equal(labelOf('hatsu:spiritual-message'), 'Report')
    assert.equal(labelOf('hatsu:en on HA#12'), 'Drive PR')
  })

  test('every labelled skill has an emoji for when it is the starred step', () => {
    for (const skill of Object.keys(LABELS)) assert.ok(GLYPHS[skill])
    assert.equal(glyphOf('hatsu:tensho main'), '🚀')
    assert.equal(glyphOf('not a skill'), null)
    // The your-call flag stays a text symbol: only the starred button carries an emoji.
    assert.equal([...HUMAN_FLAG].some(c => c.codePointAt(0)! >= 0x1f000), false)
  })

  test('an issue offers build before anything is authored, and iterate after', () => {
    assert.deepEqual(stepFor({ ...base, ref: 'HA#473' }).paths.map(p => p.prompt), ['hatsu:build HA#473'])
    const after = labels({ ...started, ref: 'HA#473' })
    assert.equal(after[0], 'Iterate')
    assert.ok(!after.includes('Build'))
    assert.ok(!after.includes('File'))
  })

  test('a raw idea starts at ideation, and building it in flight is always open', () => {
    assert.deepEqual(labels(base), ['Ideate', 'Build', 'File'])
    assert.deepEqual(starred(base), ['Ideate'])
    assert.deepEqual(labels({ ...base, isIdeating: true }), ['Ideate', 'Build', 'File'])
  })

  test('every authored stage shows every path, open ones first, blocked where it must wait', () => {
    const all = ['Iterate', 'Commit', 'Publish', 'Ship', 'Open PR', 'Catch Up', 'Review', 'Lint', 'Launch', 'File', 'Report']
    assert.deepEqual([...labels(started)].sort(), [...all].sort())
    assert.deepEqual(labels(started), [...open(started), ...blocked(started)])
    assert.deepEqual(blocked(started), ['Commit', 'Publish', 'Ship', 'Open PR', 'Review'])
    assert.deepEqual(open(started), ['Iterate', 'Catch Up', 'Lint', 'Launch', 'File', 'Report'])
    assert.deepEqual(starred(started), ['Iterate'])

    const dirty = { ...started, dirty: 3 }
    assert.deepEqual([...labels(dirty)].sort(), [...all].sort())
    assert.deepEqual(labels(dirty), [...open(dirty), ...blocked(dirty)])
    assert.deepEqual(open(dirty), ['Iterate', 'Commit', 'Ship', 'Review', 'Lint', 'Launch', 'File', 'Report'])
    assert.deepEqual(starred(dirty), ['Commit'])

    const committed = { ...started, ahead: 2 }
    assert.deepEqual(open(committed), ['Iterate', 'Publish', 'Ship', 'Catch Up', 'Review', 'Lint', 'Launch', 'File', 'Report'])
    assert.deepEqual(starred(committed), [])

    const pushed = { ...started, ahead: 2, hasUpstream: true }
    assert.deepEqual(blocked(pushed), ['Commit', 'Publish'])
    assert.deepEqual(open(pushed), ['Iterate', 'Ship', 'Open PR', 'Update', 'Review', 'Lint', 'Launch', 'File', 'Report'])

    // Iterating on top of a published, folded commit: Publish is open again.
    assert.ok(open({ ...pushed, unpushed: 1 }).includes('Publish'))
  })

  test('an open PR keeps iterating, committing and updating on its branch', () => {
    const pr = { ...started, ahead: 1, hasUpstream: true, pr: { number: 9, state: 'OPEN' } }
    assert.deepEqual(labels(pr), ['Drive PR', 'Unblock PR', 'Iterate', 'Update', 'Review', 'Lint', 'Launch', 'Summary', 'Report', 'Commit'])
    assert.deepEqual(starred(pr), ['Drive PR'])
    assert.deepEqual(starred({ ...pr, dirty: 2 }), ['Commit'])
    // En having run is not readiness: without its Ready stop the PR is driven again.
    assert.equal(stepFor({ ...pr, isDriven: true }).headline, 'Driven, readiness unread')
    assert.deepEqual(starred({ ...pr, isDriven: true }), ['Drive PR'])
    assert.equal(labels({ ...pr, isDriven: true, atGate: true })[0], 'Unblock PR')
    assert.deepEqual(starred({ ...pr, isDriven: true, atGate: true }), [])
  })

  test('a PR state the desk does not know offers no PR-less path', () => {
    const odd = stepFor({ ...started, ahead: 1, hasUpstream: true, pr: { number: 9, state: 'LOCKED' } })
    assert.equal(odd.headline, 'PR state unread')
    assert.deepEqual(odd.paths.map(p => p.label), ['Report'])
  })

  test('no copy names a human call as what the effort waits on (HR-370)', () => {
    for (const s of [{ ...started, ahead: 2 }, { ...started, ahead: 1, hasUpstream: true }]) {
      assert.doesNotMatch(stepFor(s).why, /waiting|your call|ends only on/i)
    }
  })

  test('the wrap-up shows on a merged PR and names the declaration still owed (HR-371)', () => {
    const merged = stepFor({ ...started, pr: { number: 9, state: 'MERGED' } })
    assert.ok(merged.paths.filter(p => p.blocked === null).map(p => p.label).includes('Clean Up'))
    assert.equal(merged.paths.some(p => p.isPrimary), false)
    assert.ok(merged.why.includes('satisfied'))
  })

  test('after the PR, the next effort is a fresh build', () => {
    assert.deepEqual(labels({ ...started, ahead: 1, pr: { number: 9, state: 'MERGED' } }), ['Clean Up', 'Retro', 'Summary', 'Cut', 'Build', 'Report'])
    assert.deepEqual(labels({ ...started, ahead: 1, pr: { number: 9, state: 'CLOSED' } }), ['Build', 'Report'])
  })

  test("the maintainer's own calls are offered, marked, and never starred", () => {
    const states = [{ ...started, dirty: 1 }, { ...started, ahead: 1 }, { ...started, ahead: 1, hasUpstream: true }]
    for (const s of states) {
      for (const p of stepFor(s).paths) {
        if (/^hatsu:(aka|mukai|tensho)/.test(p.prompt)) {
          assert.equal(p.isHumanCall, true)
          assert.equal(p.isPrimary, false)
        }
      }
    }
    assert.deepEqual(starred({ ...started, pr: { number: 1, state: 'MERGED' } }), [])
  })

  test('a blocked path is never starred and says what it waits on', () => {
    for (const s of [started, { ...started, dirty: 1 }, { ...started, ahead: 1 }]) {
      for (const p of stepFor(s).paths) {
        if (p.blocked !== null) {
          assert.equal(p.isPrimary, false)
          assert.ok(p.blocked.length > 0)
        }
      }
    }
  })

  test('an open PR fills its own ref and gate', () => {
    const prompts = stepFor({ ...started, pr: { number: 9, state: 'OPEN' } }).paths.map(p => p.prompt)
    assert.ok(prompts.includes('hatsu:en on HA#9'))
    assert.ok(prompts.includes('hatsu:sharingan HA#9 to G4'))
    assert.ok(stepFor({ ...started, dirty: 1 }).paths.map(p => p.prompt).includes('hatsu:tensho main'))
  })

  test('no state ever offers a merge, an upload or a publication', () => {
    const states = [base, { ...base, ref: 'HA#1' }, started, { ...started, dirty: 1 }, { ...started, ahead: 1 },
      { ...started, pr: { number: 1, state: 'OPEN' } }, { ...started, pr: { number: 1, state: 'MERGED' } }]
    for (const s of states) {
      for (const p of stepFor(s).paths) assert.doesNotMatch(p.prompt, /mugetsu|kagutsuchi|merge/)
    }
  })

  test("another effort's phase reads as what it is doing, not its skill name", () => {
    assert.equal(readingOf('en'), 'Driving PR')
    assert.equal(readingOf('kokusen'), 'Committing')
    assert.equal(readingOf('hanten-preflight'), 'Reviewing')
    assert.equal(readingOf('aka-publish'), 'Publishing')
    assert.equal(readingOf('final-head-verification'), 'Verifying')
    assert.equal(readingOf('integrate-ha246'), 'Integrating')
    assert.equal(readingOf('kokusen-review-fixes'), 'Remediating')
    assert.equal(readingOf('mukai'), 'Preparing PR')
    assert.equal(readingOf('some-new-step'), 'Some new step')
  })

  test('a reading turns past tense once its step has ended', () => {
    assert.equal(readingOf('en', true), 'Drove PR')
    assert.equal(readingOf('kokusen-review-fixes', true), 'Remediated')
    assert.equal(readingOf('some-new-step', true), 'Some new step')
    for (const present of Object.values(READINGS)) assert.ok(PAST[present])
  })

  test('a conflicted PR stars Update until the base is merged in, then Drive PR; uncommitted work comes first', () => {
    const pr = { ...started, ahead: 1, hasUpstream: true, pr: { number: 9, state: 'OPEN' }, isConflicted: true }
    assert.equal(stepFor(pr).headline, 'Conflicts with main')
    assert.deepEqual(starred(pr), ['Update'])
    assert.deepEqual(starred({ ...pr, isDriven: true, atGate: true }), ['Update'])
    assert.deepEqual(starred({ ...pr, dirty: 1 }), ['Commit'])
    // Caught up locally but not pushed: Update has nothing left to merge, so Drive PR publishes it.
    const caught = { ...pr, hasBase: true, isDriven: true, atGate: true }
    assert.equal(stepFor(caught).headline, 'Conflicts on GitHub, caught up locally')
    assert.deepEqual(starred(caught), ['Drive PR'])
  })
}
