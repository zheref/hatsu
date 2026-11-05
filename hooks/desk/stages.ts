// Where an effort stands in the Hatsu pipeline, read from the skills that ran, its phase ledger and
// the facts git and GitHub hold. A skill is filed under the earliest stage it runs in and the
// furthest stage seen wins, so a skill a later stage also runs (kokusen, gyo) never pulls an effort
// back; a skill several stages run with nothing to tell them apart is evidence of none of them.

import type { Activity, SessionEffort } from './state'

/** The Hatsu delivery pipeline, as the skills each stage runs first. */
export const STAGES = [
  { label: 'Warm-up', name: 'ten', meaning: 'warm-up', state: 'Warm up', skills: ['ten'] },
  // Conceptually before the warm-up (an idea needs no checkout), drawn after it in the timeline.
  { label: 'Ideate', name: 'emperor-time', meaning: 'ideate', state: 'Ideating', skills: ['emperor-time'] },
  { label: 'Build', name: 'ren', meaning: 'build', state: 'Building', skills: ['build', 'ren', 'breath', 'rasengan', 'kokusen', 'gyo', 'amaterasu'] },
  // tensho composes aka and mukai: having run, it has at least published.
  { label: 'Publish', name: 'aka', meaning: 'publish', state: 'Published', skills: ['aka', 'ao', 'tensho'] },
  // No PR exists yet at this stage: it is being prepared (stateOf names the step inside it).
  { label: 'Review & PR', name: 'mukai', meaning: 'pull request', state: 'Preparing PR', skills: ['mukai', 'byakugan', 'shibari'] },
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

/** The personas hanten raises; a running one means the review is under way. */
export const REVIEWERS = ['Nobunaga', 'Feitan', 'Chrollo', 'Phinks', 'Hisoka', 'Uvogin', 'Leorio'] as const

export const stageAt = (name: string) => STAGES.findIndex(st => st.name === name)

/** How far the Hatsu flow has come on this effort, as the desk and the path matrix read it. */
// Started: a build-stage skill ran, a phase past the warm-up was ledgered, or work exists —
// any file this session edited, inside the repository or not.
export function progressOf(s: SessionEffort, acts: Activity[], edited: number) {
  const seen = new Set([...acts.filter(a => a.kind === 'skill').map(a => a.label), ...s.phases])
  const building = STAGES.slice(stageAt('ren')).some(st => (st.skills as readonly string[]).some(k => seen.has(k)))
  const isStarted = building || s.dirty > 0 || s.ahead > 0 || edited > 0

  return { seen, isStarted, isIdeating: seen.has('emperor-time') && !isStarted && s.ref === null, isDriven: seen.has('en'), atGate: s.atGate }
}

/** The index of the stage this session's effort stands at. */
// The furthest stage whose own skill ran; a finished warm-up with no issue is ideation, with one
// it is the build waiting to start; a pushed branch is published, and its PR moves it further.
// The merge gate is read from the stop En records at Ready, never from En having run: En also
// ends on a G5, its cap or an owed round (sharingan § 4 — readiness is the verb's).
export function stageOf(s: SessionEffort, acts: Activity[], edited: number): number {
  const { seen, isStarted } = progressOf(s, acts, edited)
  let at = 0
  for (const [i, stage] of STAGES.entries()) {
    if ((stage.skills as readonly string[]).some(k => seen.has(k))) at = Math.max(at, i)
  }
  if (seen.has('ten')) at = Math.max(at, s.ref ? stageAt('ren') : stageAt('emperor-time'))
  if (isStarted) at = Math.max(at, stageAt('ren'))
  if (s.hasUpstream && s.ahead > 0) at = Math.max(at, stageAt('aka'))
  switch (s.pr?.state) {
    case undefined:
      break
    case 'OPEN':
      at = Math.max(at, stageAt(s.atGate ? 'gate' : 'en'))
      break
    case 'MERGED':
      at = Math.max(at, stageAt('cleanup'))
      break
    // Closed unmerged: the PR left the sitting's scope (HR-367); the timeline stops where the PR was.
    case 'CLOSED':
      at = Math.max(at, stageAt('en'))
      break
    // A state the read did not recognise says nothing about where the effort is.
    default:
      break
  }

  return at
}

/**
 * What the stage chip reads. Inside Review & PR no PR exists yet, so it is never "Open PR": the
 * review is running while a reviewer is, remediation follows once they have all returned (or a
 * fix round is ledgered), and otherwise the PR is being prepared.
 */
export function stateOf(stage: number, s: SessionEffort, acts: Activity[]): string {
  const st = STAGES[stage]!
  if (s.pr?.state === 'CLOSED') {
    return 'Closed unmerged'
  }
  if (st.name !== 'mukai' || s.pr !== null) {
    return st.state
  }
  // Only what happened since this mukai run began counts.
  const start = acts.map(a => a.kind === 'skill' && a.label === 'mukai').lastIndexOf(true)
  const since = acts.slice(Math.max(0, start))
  const reviews = since.filter(a => a.kind === 'agent' && (REVIEWERS as readonly string[]).includes(a.label))
  const last = s.phases[s.phases.length - 1] ?? ''
  if (reviews.some(a => !a.isDone)) {
    return 'Reviewing'
  }
  // The checkpoint, the impacted suites, coverage or the publish after the review mean the fixes are in.
  const isPastFixes = /^(kokusen|kotoamatsukami|byakugan|murasaki|shibari)/.test(last)
  if (/review-fix|remediat/.test(last) || (reviews.length > 0 && !isPastFixes)) {
    return 'Remediating'
  }

  return st.state
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
