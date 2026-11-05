// What each Hatsu skill reads as on a button, and which buttons each state of an effort offers.
// The label matrix is the maintainer's to tune: one row per skill, plain English, no prefix.
//
// The desk mirrors the canon, it never extends it (docs/WORKFLOW.md § 4, STANDALONE-ENTRY § 6):
// - the merge, kagutsuchi and mugetsu are never a button;
// - aka and mukai (and tensho, which composes them) are the maintainer's calls: a button only
//   fills the prompt, never starred, flagged, and pressing it is the maintainer's own typed call
//   (docs/ROSTER.md HR-370); the copy describes the state and never names one as awaited;
// - ren ends only on the maintainer's aka or tensho, so a committed ren turn stars nothing;
// - the wrap-up buttons show only once every PR in the sitting reads MERGED, naming the
//   satisfied declaration as still owed (HR-366, HR-371). The desk's sitting is this session's
//   effort: it reads one branch, so a session spanning several PRs is not seen whole.

export const LABELS: Record<string, string> = {
  ten: 'Warm Up',
  'emperor-time': 'Ideate',
  build: 'Build',
  direct: 'Route',
  classify: 'Classify',
  file: 'File',
  ren: 'Build',
  rasengan: 'Author',
  gyo: 'Lint',
  kokusen: 'Commit',
  amaterasu: 'Launch',
  aka: 'Publish',
  ao: 'Catch Up',
  tensho: 'Ship',
  murasaki: 'Update',
  hanten: 'Review',
  mukai: 'Open PR',
  en: 'Drive PR',
  sharingan: 'Unblock PR',
  rikugan: 'Summary',
  'spiritual-message': 'Report',
  cleanup: 'Clean Up',
  'third-hand': 'Retro',
  getsuga: 'Cut',
}

/** The emoji that leads the starred button: what the recommended step does, at a glance. Other
 * buttons carry no glyph, so the one the canon offers next stands out. Tuned with the labels. */
export const GLYPHS: Record<string, string> = {
  ten: '🔥',
  'emperor-time': '💡',
  build: '🔨',
  direct: '🧭',
  classify: '🗂️',
  file: '📝',
  ren: '🔨',
  rasengan: '✍️',
  gyo: '✨',
  kokusen: '📌',
  amaterasu: '▶️',
  aka: '⬆️',
  ao: '🔄',
  tensho: '🚀',
  murasaki: '🔁',
  hanten: '🔍',
  mukai: '🔀',
  en: '🚦',
  sharingan: '🔓',
  rikugan: '📊',
  'spiritual-message': '📄',
  cleanup: '🧹',
  'third-hand': '💬',
  getsuga: '🏷️',
}

/** The flag after a button that is the maintainer's own call. */
export const HUMAN_FLAG = '⚑'

/** A button's leading glyph, or none for a prompt outside the matrix. */
export const glyphOf = (prompt: string) => GLYPHS[skillOf(prompt) ?? ''] ?? null

/** The phases only the maintainer calls; a button for one is offered, never recommended. */
export const HUMAN_CALLS = new Set(['aka', 'mukai', 'tensho'])

/** The skill a prompt invokes: `hatsu:en on HA#12` → `en`. */
export const skillOf = (prompt: string) => /^hatsu:([\w-]+)/.exec(prompt.trim())?.[1] ?? null

/** A button's label: the matrix row for its skill, else the prompt itself. */
export const labelOf = (prompt: string) => {
  const skill = skillOf(prompt)

  return (skill && LABELS[skill]) ?? prompt.trim()
}

export type EffortState = {
  dirty: number
  ahead: number
  hasUpstream: boolean
  /** Commits not yet on the upstream; 0 when there is none. */
  unpushed: number
  pr: { number: number; state: PrState } | null
  /** The issue ref the branch names, e.g. `HA#473`. */
  ref: string | null
  /** The repository's object code, e.g. `HA`. */
  code: string
  /** The gate this repository's merges stop at. */
  gate: 'G2' | 'G4'
  /** The base branch, from `nen/workflow.json` → `branch.base`. */
  base: string
  /** The Hatsu flow has begun on this effort: a build skill ran, a phase was ledgered, or work exists. */
  isStarted: boolean
  /** emperor-time ran and nothing has been built yet. */
  isIdeating: boolean
  /** En has run in this session; not, by itself, readiness. */
  isDriven: boolean
  /** En's Ready stop for this branch is unrung: the PR stands at the maintainer's merge prompt. */
  atGate: boolean
  /** GitHub reads the open PR as CONFLICTING with its base. */
  isConflicted: boolean
  /** The local branch already contains `origin/<base>`: a catch-up has nothing left to merge. */
  hasBase: boolean
}

/** A PR state as gh reports it; anything else is a read the desk did not understand. */
export type PrState = 'OPEN' | 'CLOSED' | 'MERGED' | (string & {})

/** One way forward. A blocked path is still shown, so every branch the canon allows is visible;
 * its `blocked` says what it waits on, and pressing it says so instead of filling the prompt. */
export type Path = { prompt: string; label: string; isPrimary: boolean; isHumanCall: boolean; blocked: string | null }

/** What the desk says about the effort and every path the maintainer can take from it. */
export type Step = { headline: string; why: string; paths: Path[] }

const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`

/** A path the canon offers here: a prompt, or a prompt with what it waits on, or nothing. */
type Offer = string | [prompt: string, blocked: string | null] | null

/**
 * The effort's state as the canon reads it, and every path it allows: the open ones first, then
 * the blocked ones, each group in one fixed order so a button keeps its place from stage to stage. `star` names the one path the canon itself offers
 * next, if any; a maintainer's call is never it.
 */
export function stepFor(s: EffortState): Step {
  const pr = s.pr ? `${s.code}#${s.pr.number}` : null
  const report = 'hatsu:spiritual-message'
  const ren = 'hatsu:ren '
  // Build until something has been authored; from then on every ren turn iterates on it.
  const hasAuthored = s.isStarted || s.dirty > 0 || s.ahead > 0
  const step = (headline: string, why: string, offers: Offer[], star: string | null = null, isNew = false): Step => ({
    headline,
    why,
    paths: offers
      .filter((o): o is string | [string, string | null] => o !== null)
      .map(o => {
        const [prompt, blocked] = typeof o === 'string' ? [o, null] : o
        const isHumanCall = HUMAN_CALLS.has(skillOf(prompt) ?? '')
        const label = prompt === ren && hasAuthored && !isNew ? 'Iterate' : labelOf(prompt)
        return { prompt, label, isPrimary: prompt === star && !isHumanCall && blocked === null, isHumanCall, blocked }
      })
      // What can run now comes first; the blocked paths follow, each still in its fixed order.
      .sort((a, b) => Number(a.blocked !== null) - Number(b.blocked !== null)),
  })

  // The paths every authored, pre-merge stage shares, each blocked by what it waits on.
  const unpushed = s.hasUpstream ? s.unpushed : s.ahead
  const commit: Offer = ['hatsu:kokusen', s.dirty > 0 ? null : 'Nothing to commit: the working tree is clean.']
  const review: Offer = ['hatsu:hanten', s.dirty > 0 || s.ahead > 0 ? null : 'Nothing to review yet.']
  const lint: Offer = 'hatsu:gyo'
  const launch: Offer = 'hatsu:amaterasu'

  if (s.pr !== null && !['OPEN', 'CLOSED', 'MERGED'].includes(s.pr.state)) {
    return step('PR state unread', `PR ${pr} reads "${s.pr.state}", a state the desk does not know. Refresh, or read it on GitHub.`, [report], null, true)
  }
  if (s.pr?.state === 'MERGED') {
    return step(
      'Merged',
      `PR ${pr} is merged, and with it every PR the desk sees in this sitting. Wrap-up still waits on you declaring the sitting satisfied (HR-366); pressing Clean Up is that call. Or start the next effort.`,
      ['hatsu:cleanup', 'hatsu:third-hand', `hatsu:rikugan for ${pr}`, 'hatsu:getsuga', ren, report],
      null,
      true,
    )
  }
  if (s.pr?.state === 'CLOSED') {
    return step('Closed without merging', `PR ${pr} was closed unmerged, so it has left the sitting's scope.`, [ren, report], null, true)
  }
  if (s.pr?.state === 'OPEN') {
    // More work on a PR branch is still ren and kokusen; Drive PR (en) publishes it onto the PR, since
    // a standalone Update (murasaki) catches up locally and pushes nothing (murasaki § 0).
    const paths: Offer[] = [
      s.atGate && !s.isConflicted ? null : `hatsu:en on ${pr}`,
      `hatsu:sharingan ${pr} to ${s.gate}`,
      ren,
      commit,
      'hatsu:murasaki',
      review,
      lint,
      launch,
      `hatsu:rikugan for ${pr}`,
      report,
    ]
    if (s.dirty > 0) {
      return step(
        'Uncommitted work on the PR branch',
        `${plural(s.dirty, 'file')} not committed. Commit them, then Drive PR publishes them onto PR ${pr}.`,
        paths,
        'hatsu:kokusen',
      )
    }
    // A conflicted PR runs no checks, so it can look quiet. Update (murasaki) merges the base into the
    // local branch, settling mechanical conflicts and stopping on a semantic one, and pushes nothing
    // when called on its own; Drive PR (en) then publishes the caught-up branch. Unblock PR
    // (sharingan) pushes only a clean merge and leaves a real conflict unresolved.
    if (s.isConflicted) {
      return s.hasBase
        ? step(
            `Conflicts on GitHub, caught up locally`,
            `This branch already holds ${s.base}, but PR ${pr} still reads as conflicting: the catch-up is not pushed. Drive PR publishes it onto the PR and drives it to readiness.`,
            paths,
            `hatsu:en on ${pr}`,
          )
        : step(
            `Conflicts with ${s.base}`,
            `PR ${pr} cannot merge: its branch conflicts with ${s.base}. Update merges ${s.base} into the local branch, resolving mechanical conflicts and stopping for you on a semantic one; Drive PR then publishes it.`,
            paths,
            'hatsu:murasaki',
          )
    }
    if (s.atGate) {
      return step(`At your merge gate (${s.gate})`, `En left PR ${pr} at your ${s.gate} prompt. The merge is yours, outside the session, never a button.`, paths)
    }
    return s.isDriven
      ? step(
          'Driven, readiness unread',
          `En ran on PR ${pr} but recorded no Ready stop: it may have stopped on a blocker, its cap or an owed round. Drive it again or unblock it.`,
          paths,
          `hatsu:en on ${pr}`,
        )
      : step(
          'Drive the PR to readiness',
          `PR ${pr} is open. En watches CI and the owed review until it stands at your ${s.gate} gate.`,
          paths,
          `hatsu:en on ${pr}`,
        )
  }

  if (hasAuthored) {
    const publish: Offer = [
      'hatsu:aka',
      s.dirty > 0 ? 'Commit the open changes first: Publish folds only commits.' : unpushed === 0 ? 'Nothing unpushed to publish.' : null,
    ]
    const ship: Offer = [`hatsu:tensho ${s.base}`, s.dirty > 0 || unpushed > 0 || s.hasUpstream ? null : 'Nothing to ship yet.']
    const openPr: Offer = [
      'hatsu:mukai',
      !s.hasUpstream ? 'Publish first: a PR opens from a pushed branch.' : s.dirty > 0 ? 'Commit the open changes first.' : null,
    ]
    const paths: Offer[] = [
      ren,
      commit,
      publish,
      ship,
      openPr,
      s.hasUpstream ? 'hatsu:murasaki' : ['hatsu:ao', s.dirty > 0 ? 'Commit first: catching up needs a clean tree.' : null],
      review,
      lint,
      launch,
      s.ref ? null : 'hatsu:file ',
      report,
    ]
    if (s.dirty > 0) {
      return step(
        'Uncommitted work',
        `${plural(s.dirty, 'file')} not committed. Commit verifies and commits them locally; or keep iterating first.`,
        paths,
        'hatsu:kokusen',
      )
    }
    if (unpushed > 0) {
      return step(
        s.hasUpstream ? 'Local commits on a published branch' : 'Committed, not published',
        `${plural(unpushed, 'commit')} on this machine only, local to this checkout. Publish would fold them into one and push it; more ren turns iterate on top.`,
        paths,
      )
    }
    if (s.hasUpstream) {
      return step('Pushed, no PR', 'The branch is published and no PR exists yet. Open PR would review, test and open it; more ren turns iterate on the published branch.', paths)
    }
    return step('Building', 'The flow has started and nothing is committed yet. Each request is one ren turn.', paths, ren)
  }

  if (s.isIdeating) {
    return step(
      'Ideating',
      'Emperor-time is shaping the brief. It files the issue only on your confirmation; or build the idea straight away.',
      ['hatsu:emperor-time', ren, 'hatsu:file '],
      'hatsu:emperor-time',
    )
  }

  return s.ref
    ? step(`Build ${s.ref}`, 'Nothing has started on this issue. Build takes it end to end to a PR at your gate.', [`hatsu:build ${s.ref}`], `hatsu:build ${s.ref}`)
    : step(
        'Start from an idea',
        'No issue and nothing started. Ideate into a brief, build the idea in flight, or file what was discussed.',
        ['hatsu:emperor-time ', ren, 'hatsu:file '],
        'hatsu:emperor-time ',
      )
}

/** What an effort is doing, read from its ledger's phase name: `en` → `Driving PR`. Ledgers name
 * skills and also free-form sub-steps (`publish-reviewed`, `final-head-verification`). */
export const READINGS: Record<string, string> = {
  ten: 'Warming up',
  breath: 'Warming up',
  'emperor-time': 'Ideating',
  build: 'Building',
  ren: 'Building',
  rasengan: 'Authoring',
  author: 'Authoring',
  gyo: 'Linting',
  tsukuyomi: 'Testing',
  kokusen: 'Committing',
  amaterasu: 'Launching',
  aka: 'Publishing',
  publish: 'Publishing',
  ao: 'Catching up',
  'catch-up': 'Catching up',
  murasaki: 'Updating',
  tensho: 'Shipping',
  hanten: 'Reviewing',
  kotoamatsukami: 'Testing',
  integration: 'Testing',
  byakugan: 'Measuring coverage',
  mukai: 'Preparing PR',
  shibari: 'Opening PR',
  pr: 'Opening PR',
  en: 'Driving PR',
  sharingan: 'Unblocking PR',
  jutaisho: 'At your gate',
  rikugan: 'Summarizing',
  report: 'Reporting',
  'spiritual-message': 'Reporting',
  cleanup: 'Cleaning up',
  'third-hand': 'Running retro',
  getsuga: 'Cutting release',
}

/** Each reading once its step has ended, completed or failed: `Driving PR` → `Drove PR`. */
export const PAST: Record<string, string> = {
  'Warming up': 'Warmed up',
  Ideating: 'Ideated',
  Building: 'Built',
  Authoring: 'Authored',
  'Authoring canon': 'Authored canon',
  Linting: 'Linted',
  Testing: 'Tested',
  Committing: 'Committed',
  Launching: 'Launched',
  Publishing: 'Published',
  'Catching up': 'Caught up',
  Updating: 'Updated',
  Shipping: 'Shipped',
  Reviewing: 'Reviewed',
  'Measuring coverage': 'Measured coverage',
  'Opening PR': 'Opened PR',
  'Driving PR': 'Drove PR',
  'Unblocking PR': 'Unblocked PR',
  'At your gate': 'Reached your gate',
  Summarizing: 'Summarized',
  Reporting: 'Reported',
  'Cleaning up': 'Cleaned up',
  'Running retro': 'Ran retro',
  'Cutting release': 'Cut release',
  Integrating: 'Integrated',
  'Watching CI': 'Watched CI',
  Remediating: 'Remediated',
  'Preparing PR': 'Prepared PR',
  'Fixing CI': 'Fixed CI',
  'Taking inventory': 'Took inventory',
  Verifying: 'Verified',
}

const PATTERNS: [RegExp, string][] = [
  [/review-fix|^remediat/, 'Remediating'],
  [/^repair.*ci/, 'Fixing CI'],
  [/^readiness/, 'Driving PR'],
  [/^integrat/, 'Integrating'],
  [/(^|-)ci(-|$)/, 'Watching CI'],
  [/^great-hiker/, 'Authoring canon'],
  [/^commit/, 'Committing'],
  [/^inventory/, 'Taking inventory'],
  [/^(final|focused|parent-focused|source)-/, 'Verifying'],
]

/** What a phase reads as: present while it runs, past once it has ended. A name the desk does not
 * know reads as its own words either way. */
export function readingOf(phase: string, hasEnded = false): string {
  const now = presentOf(phase)

  return hasEnded ? (PAST[now] ?? now) : now
}

function presentOf(phase: string): string {
  const key = phase.toLowerCase()
  if (READINGS[key]) {
    return READINGS[key]
  }
  // Free-form steps, matched before the skill they name: `kokusen-review-fixes` is a fix round.
  for (const [pattern, reading] of PATTERNS) {
    if (pattern.test(key)) {
      return reading
    }
  }
  // A sub-step reads as its skill: `hanten-preflight` → Reviewing, `aka-publish` → Publishing.
  const head = Object.keys(READINGS).find(k => key.startsWith(`${k}-`) || key.endsWith(`-${k}`))
  if (head) {
    return READINGS[head]!
  }
  if (/verif|proof|checkpoint|ready/.test(key)) {
    return 'Verifying'
  }
  const words = key.replace(/[-_]+/g, ' ').trim()

  return words.charAt(0).toUpperCase() + words.slice(1)
}
