import assert from 'node:assert/strict'
import type { RegisterCase } from './register-case.ts'

import { STAGES, STAGE_NEUTRAL, isStageDone, progressOf, stageAt, stageOf, stateOf } from '../stages.ts'
import type { Activity } from '../state.ts'
import type { Pr, SessionEffort } from '../state.ts'

const effort: SessionEffort = {
  branch: 'opus/kurapika/hatsu-desk-pane', title: 'Hatsu desk pane', ref: null, repo: null,
  dirty: 0, ahead: 1, hasUpstream: false, unpushed: 0, pr: null, phases: [], atGate: false, hasBase: false, nature: null,
}
const pr = (state: string): Pr => ({ number: 9, state, title: 'x', url: 'https://example.invalid', isDraft: false })
const at = (s: SessionEffort) => STAGES[stageOf(s, [], 0)]!.name

export function stagesCases(test: RegisterCase): void {
  test("a committed ren turn stays at Build, whatever its report and bell recorded", () => {
    const turn = { ...effort, phases: ['breath', 'rasengan', 'kokusen', 'amaterasu', 'spiritual-message', 'jutaisho'] }
    assert.equal(at(turn), 'ren')
    assert.equal(at({ ...turn, phases: [...turn.phases, 'hanten', 'murasaki', 'kotoamatsukami', 'rikugan'] }), 'ren')
  })

  test('no stage-neutral skill is evidence of a stage', () => {
    for (const st of STAGES) {
      for (const skill of STAGE_NEUTRAL) assert.equal((st.skills as readonly string[]).includes(skill), false)
    }
  })

  test('a pushed branch with no PR is published, and the PR moves it on', () => {
    assert.equal(at({ ...effort, hasUpstream: true }), 'aka')
    assert.equal(at({ ...effort, hasUpstream: true, phases: ['mukai'] }), 'mukai')
    assert.equal(at({ ...effort, hasUpstream: true, pr: pr('OPEN') }), 'en')
    // En having run is not readiness; its Ready stop is.
    assert.equal(at({ ...effort, hasUpstream: true, pr: pr('OPEN'), phases: ['en'] }), 'en')
    assert.equal(at({ ...effort, hasUpstream: true, pr: pr('OPEN'), phases: ['en'], atGate: true }), 'gate')
    assert.equal(at({ ...effort, hasUpstream: true, phases: ['tensho'] }), 'aka')
    assert.equal(at({ ...effort, pr: pr('MERGED') }), 'cleanup')
  })

  test('Publish is drawn done only once the branch is pushed or has a PR', () => {
    const aka = stageAt('aka')
    const mukai = stageAt('mukai')
    assert.equal(isStageDone(aka, mukai, effort), false)
    assert.equal(isStageDone(aka, mukai, { ...effort, hasUpstream: true }), true)
    assert.equal(isStageDone(aka, stageAt('en'), { ...effort, pr: pr('OPEN') }), true)
    assert.equal(isStageDone(stageAt('ren'), mukai, effort), true)
    assert.equal(isStageDone(mukai, mukai, effort), false)
  })

  test('an issue on the branch draws ideation as done', () => {
    assert.equal(isStageDone(stageAt('emperor-time'), stageAt('ren'), { ...effort, ref: 'HA#1' }), true)
    assert.equal(isStageDone(stageAt('emperor-time'), stageAt('ten'), effort), false)
  })

  test('a PR closed unmerged is named, and an unknown state moves nothing', () => {
    const closed = { ...effort, hasUpstream: true, pr: pr('CLOSED') }
    assert.equal(at(closed), 'en')
    assert.equal(stateOf(stageOf(closed, [], 0), closed, []), 'Closed unmerged')
    assert.equal(at({ ...effort, hasUpstream: true, pr: pr('LOCKED') }), 'aka')
  })

  test('an issue on the branch outranks ideation', () => {
    assert.equal(progressOf({ ...effort, ahead: 0, ref: 'HA#1' }, [{ id: 'a', at: 1, kind: 'skill', label: 'emperor-time', detail: null, isDone: true }], 0).isIdeating, false)
  })

  test('before a PR exists the stage reads Preparing PR, Reviewing or Remediating, never Open PR', () => {
    const s = { ...effort, hasUpstream: true, phases: ['aka'] }
    const skill = (label: string): Activity => ({ id: label, at: 1, kind: 'skill', label, detail: null, isDone: true })
    const agent = (label: string, isDone: boolean): Activity => ({ id: label, at: 2, kind: 'agent', label, detail: null, isDone })
    const mukai = stageAt('mukai')
    assert.equal(stateOf(mukai, s, [skill('mukai')]), 'Preparing PR')
    assert.equal(stateOf(mukai, s, [skill('mukai'), agent('Nobunaga', false), agent('Chrollo', true)]), 'Reviewing')
    assert.equal(stateOf(mukai, s, [skill('mukai'), agent('Nobunaga', true), agent('Chrollo', true)]), 'Remediating')
    assert.equal(stateOf(mukai, { ...s, phases: ['aka', 'kokusen'] }, [skill('mukai'), agent('Nobunaga', true)]), 'Preparing PR')
    assert.equal(stateOf(mukai, { ...s, phases: ['aka', 'kokusen-review-fixes'] }, [skill('mukai')]), 'Remediating')
    assert.ok(!STAGES.map(st => st.state).includes('Open PR'))
  })
}
