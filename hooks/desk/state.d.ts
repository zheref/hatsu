/** One effort as its newest phase in the nen phase ledger reads. */
export type Effort = {
  id: string
  title: string
  ref: string | null
  surface: string | null
  model: string | null
  persona: string | null
  phase: string
  isOpen: boolean
  isStale: boolean
  /** Minutes since the phase began (open) or ended (closed). */
  ageMin: number
  exitCode: number | null
  note: string | null
  phases: string[]
  /** Every phase the ledger holds, oldest first: the card's activity rows. */
  records: PhaseRecord[]
  /** The local branch the effort's id names, if one exists. */
  branch: string | null
  /** The worktree folder that branch is checked out in, if any. */
  worktree: string | null
  /** The branch's newest PR, from the cached `gh pr list` of the repository. */
  pr: { number: number; state: string } | null
}

/** One phase of another effort's ledger, as its activity list shows it. */
export type PhaseRecord = {
  phase: string
  /** When the phase began, in epoch milliseconds. */
  at: number
  isOpen: boolean
  exitCode: number | null
  note: string | null
}

/** One unrung gate marker, as `nen stop list --json` reads it. */
export type Gate = {
  gate: string
  effort: string | null
  effortTitle: string | null
  at: string
  title: string | null
}

/** `mergeable` is GitHub's: MERGEABLE, CONFLICTING, or UNKNOWN while it computes. */
export type Pr = { number: number; state: string; title: string; url: string; isDraft: boolean; labels?: { name: string }[]; mergeable?: string }

/** This session's own effort: its branch, working copy and PR. */
export type SessionEffort = {
  branch: string
  title: string
  ref: string | null
  repo: { slug: string; code: string; role: string | null; kind: string | null } | null
  dirty: number
  ahead: number
  hasUpstream: boolean
  /** Commits not yet on the upstream; 0 when there is none. */
  unpushed: number
  pr: Pr | null
  /** Phases the nen ledger recorded for this effort, in order. */
  phases: string[]
  /** A G2/G4 stop for this branch is unrung: En left it at Ready, at the maintainer's merge prompt. */
  atGate: boolean
  /** The nature of the work (feature, machinery, governance…) and what it was read from. */
  nature: { label: string; source: string } | null
}

/** Something this session did: a Hatsu skill call or a subagent. */
export type Activity = {
  id: string
  /** When the desk saw it; null for a call read back from the transcript at load. */
  at: number | null
  kind: 'skill' | 'agent'
  /** The skill without its `hatsu:` prefix, or the subagent's persona. */
  label: string
  detail: string | null
  isDone: boolean
}

declare module 'claude-code' {
  interface PluginState {
    /** The desk pane's own values (hooks/desk/register.tsx), each key prefixed `desk`. */
    hatsu: {
      deskSession: SessionEffort | null
      deskEfforts: Effort[]
      deskGates: Gate[]
      deskActivity: Activity[]
      /** File edits (Write, Edit, MultiEdit, NotebookEdit) this session made, anywhere. */
      deskEdits: number
      deskShowOthers: boolean
      /** The activity lists expanded: `session`, or another effort's id. All start collapsed. */
      deskOpenActivity: string[]
      deskUsd: number | null
      deskContextPercent: number | null
      deskUpdatedAt: number
      deskError: string | null
    }
  }
}
