import { expect, test } from 'claude-code/testing'

import { STAGES, STAGE_NEUTRAL, isStageDone, progressOf, stageAt, stageOf, stateOf } from '../stages'
import type { Activity } from '../state'
import type { Pr, SessionEffort } from '../state'

const effort: SessionEffort = {
  branch: 'opus/kurapika/hatsu-desk-pane', title: 'Hatsu desk pane', ref: null, repo: null,
  dirty: 0, ahead: 1, hasUpstream: false, unpushed: 0, pr: null, phases: [], atGate: false, hasBase: false, nature: null,
}
const pr = (state: string): Pr => ({ number: 9, state, title: 'x', url: 'https://example.invalid', isDraft: false })
const at = (s: SessionEffort) => STAGES[stageOf(s, [], 0)]!.name

test("a committed ren turn stays at Build, whatever its report and bell recorded", async () => {
  const turn = { ...effort, phases: ['breath', 'rasengan', 'kokusen', 'amaterasu', 'spiritual-message', 'jutaisho'] }
  expect(at(turn)).toBe('ren')
  expect(at({ ...turn, phases: [...turn.phases, 'hanten', 'murasaki', 'kotoamatsukami', 'rikugan'] })).toBe('ren')
})

test('no stage-neutral skill is evidence of a stage', async () => {
  for (const st of STAGES) {
    for (const skill of STAGE_NEUTRAL) expect((st.skills as readonly string[]).includes(skill)).toBe(false)
  }
})

test('a pushed branch with no PR is published, and the PR moves it on', async () => {
  expect(at({ ...effort, hasUpstream: true })).toBe('aka')
  expect(at({ ...effort, hasUpstream: true, phases: ['mukai'] })).toBe('mukai')
  expect(at({ ...effort, hasUpstream: true, pr: pr('OPEN') })).toBe('en')
  // En having run is not readiness; its Ready stop is.
  expect(at({ ...effort, hasUpstream: true, pr: pr('OPEN'), phases: ['en'] })).toBe('en')
  expect(at({ ...effort, hasUpstream: true, pr: pr('OPEN'), phases: ['en'], atGate: true })).toBe('gate')
  expect(at({ ...effort, hasUpstream: true, phases: ['tensho'] })).toBe('aka')
  expect(at({ ...effort, pr: pr('MERGED') })).toBe('cleanup')
})

test('Publish is drawn done only once the branch is pushed or has a PR', async () => {
  const aka = stageAt('aka')
  const mukai = stageAt('mukai')
  expect(isStageDone(aka, mukai, effort)).toBe(false)
  expect(isStageDone(aka, mukai, { ...effort, hasUpstream: true })).toBe(true)
  expect(isStageDone(aka, stageAt('en'), { ...effort, pr: pr('OPEN') })).toBe(true)
  expect(isStageDone(stageAt('ren'), mukai, effort)).toBe(true)
  expect(isStageDone(mukai, mukai, effort)).toBe(false)
})

test('an issue on the branch draws ideation as done', async () => {
  expect(isStageDone(stageAt('emperor-time'), stageAt('ren'), { ...effort, ref: 'HA#1' })).toBe(true)
  expect(isStageDone(stageAt('emperor-time'), stageAt('ten'), effort)).toBe(false)
})

test('a PR closed unmerged is named, and an unknown state moves nothing', async () => {
  const closed = { ...effort, hasUpstream: true, pr: pr('CLOSED') }
  expect(at(closed)).toBe('en')
  expect(stateOf(stageOf(closed, [], 0), closed, [])).toBe('Closed unmerged')
  expect(at({ ...effort, hasUpstream: true, pr: pr('LOCKED') })).toBe('aka')
})

test('an issue on the branch outranks ideation', async () => {
  expect(progressOf({ ...effort, ahead: 0, ref: 'HA#1' }, [{ id: 'a', at: 1, kind: 'skill', label: 'emperor-time', detail: null, isDone: true }], 0).isIdeating).toBe(false)
})

test('before a PR exists the stage reads Preparing PR, Reviewing or Remediating, never Open PR', async () => {
  const s = { ...effort, hasUpstream: true, phases: ['aka'] }
  const skill = (label: string): Activity => ({ id: label, at: 1, kind: 'skill', label, detail: null, isDone: true })
  const agent = (label: string, isDone: boolean): Activity => ({ id: label, at: 2, kind: 'agent', label, detail: null, isDone })
  const mukai = stageAt('mukai')
  expect(stateOf(mukai, s, [skill('mukai')])).toBe('Preparing PR')
  expect(stateOf(mukai, s, [skill('mukai'), agent('Nobunaga', false), agent('Chrollo', true)])).toBe('Reviewing')
  expect(stateOf(mukai, s, [skill('mukai'), agent('Nobunaga', true), agent('Chrollo', true)])).toBe('Remediating')
  expect(stateOf(mukai, { ...s, phases: ['aka', 'kokusen'] }, [skill('mukai'), agent('Nobunaga', true)])).toBe('Preparing PR')
  expect(stateOf(mukai, { ...s, phases: ['aka', 'kokusen-review-fixes'] }, [skill('mukai')])).toBe('Remediating')
  expect(STAGES.map(st => st.state)).not.toContain('Open PR')
})
