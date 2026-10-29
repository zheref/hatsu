// Where an effort stands in the Hatsu pipeline, read from the skills that ran, its phase ledger and
// the facts git and GitHub hold. A skill counts as evidence only for the stage that alone runs it;
// one that several stages run says nothing about where the effort is.

import type { Activity, SessionEffort } from './state'

/** The Hatsu delivery pipeline, as the skills only that stage runs. */
export const STAGES = [
  { label: 'Warm-up', name: 'ten', meaning: 'warm-up', state: 'Warm up', skills: ['ten'] },
  // Conceptually before the warm-up (an idea needs no checkout), drawn after it in the timeline.
  { label: 'Ideate', name: 'emperor-time', meaning: 'ideate', state: 'Ideating', skills: ['emperor-time'] },
  { label: 'Build', name: 'ren', meaning: 'build', state: 'Building', skills: ['build', 'ren', 'breath', 'rasengan', 'kokusen', 'gyo', 'amaterasu', 'tensho'] },
  { label: 'Publish', name: 'aka', meaning: 'publish', state: 'Published', skills: ['aka', 'ao'] },
  { label: 'Review & PR', name: 'mukai', meaning: 'pull request', state: 'Open PR', skills: ['mukai', 'byakugan', 'shibari'] },
  { label: 'Readiness', name: 'en', meaning: 'drive', state: 'Driving PR', skills: ['en', 'sharingan'] },
  { label: 'Your merge', name: 'gate', meaning: 'merge', state: 'Human Review', skills: [] },
  { label: 'Wrap-up', name: 'cleanup', meaning: 'wrap-up', state: 'Wrapping Up', skills: ['cleanup', 'third-hand'] },
] as const

/**
 * Skills more than one stage runs, so none of them moves the effort: ren's own turn ends on the
 * report (spiritual-message) and the bell (jutaisho), the review (hanten) and the catch-up of a
 * published branch (murasaki) run before or after a PR, the impacted suites (kotoamatsukami) run
 * on a thorough ren turn as well as at mukai, and rikugan renders any scope on request.
 */
export const STAGE_NEUTRAL = ['spiritual-message', 'jutaisho', 'hanten', 'murasaki', 'kotoamatsukami', 'tsukuyomi', 'rikugan', 'direct', 'classify', 'file'] as const

export const stageAt = (name: string) => STAGES.findIndex(st => st.name === name)

/** How far the Hatsu flow has come on this effort, as the desk and the path matrix read it. */
// Started: a build-stage skill ran, a phase past the warm-up was ledgered, or work exists —
// any file this session edited, inside the repository or not.
export function progressOf(s: SessionEffort, acts: Activity[], edited: number) {
  const seen = new Set([...acts.filter(a => a.kind === 'skill').map(a => a.label), ...s.phases])
  const building = STAGES.slice(stageAt('ren')).some(st => (st.skills as readonly string[]).some(k => seen.has(k)))
  const isStarted = building || s.dirty > 0 || s.ahead > 0 || edited > 0

  return { seen, isStarted, isIdeating: seen.has('emperor-time') && !isStarted, isDriven: seen.has('en') }
}

/** The index of the stage this session's effort stands at. */
// The furthest stage whose own skill ran; a finished warm-up with no issue is ideation, with one
// it is the build waiting to start; a pushed branch is published, and its PR moves it further.
export function stageOf(s: SessionEffort, acts: Activity[], edited: number): number {
  const { seen, isStarted, isDriven } = progressOf(s, acts, edited)
  let at = 0
  for (const [i, stage] of STAGES.entries()) {
    if ((stage.skills as readonly string[]).some(k => seen.has(k))) at = Math.max(at, i)
  }
  if (seen.has('ten')) at = Math.max(at, s.ref ? stageAt('ren') : stageAt('emperor-time'))
  if (isStarted) at = Math.max(at, stageAt('ren'))
  if (s.hasUpstream && s.ahead > 0) at = Math.max(at, stageAt('aka'))
  if (s.pr?.state === 'OPEN') at = Math.max(at, stageAt(isDriven ? 'gate' : 'en'))
  if (s.pr?.state === 'MERGED') at = Math.max(at, stageAt('cleanup'))

  return at
}

/**
 * Whether the timeline draws stage `i` as done while the effort stands at `stage`. Passing a stage
 * is not proof it ran: Publish is done only once the branch is pushed or has a PR, and an issue on
 * the branch means its idea was already shaped and filed.
 */
export function isStageDone(i: number, stage: number, s: SessionEffort): boolean {
  if (i === stage) {
    return false
  }
  if (STAGES[i]?.name === 'aka') {
    return s.hasUpstream || s.pr !== null
  }
  if (STAGES[i]?.name === 'emperor-time' && s.ref !== null) {
    return true
  }

  return i < stage
}
