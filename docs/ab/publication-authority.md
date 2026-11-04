# A/B evidence — delegated publication authority across handoffs

[`claude/skills/aka/SKILL.md`](../../claude/skills/aka/SKILL.md) § 0's second carve-out (HR-20) and
its five-fact handoff record (zheref/hatsu#529, SC-1/SC-2), with [`docs/WORKFLOW.md`](../WORKFLOW.md)
§ *Delegate briefs* and [`docs/surfaces/codex.md`](../surfaces/codex.md) § *Publication requests*.

## Dated verification, 2026-11-03 — eight bounded cases walked through the canon

**Method.** Each case is a push taken through aka § 0's Covered, Not-covered and Lapses rows and the
five-fact record, to the one outcome the canon names. A desk walk-through of the prose, not an executed
run; no host approval was requested for it. Case 8 restates the 2026-10-28/29 Codex record on
zheref/hatsu#529, sanitized; the rest are constructed. The record is: the typed invocation quoted, any
maintainer-approved prerequisite quoted, the target repository, the effort's own working branch, and the
scope line.

| # | Case | Walk | Outcome |
|---|---|---|---|
| 1 | Queued initial publication | A builder delegate's `aka` first-publishes its effort branch; the host asks for approval. | The request carries the record; no new human answer is asked for. |
| 2 | An explicitly approved prerequisite | The maintainer answered yes to a prerequisite declaration PR; its builder publishes. | Covered: the maintainer's own words added it to the queue, and the answer is quoted in the record beside the invocation. An agent-proposed, unanswered prerequisite would be refused. |
| 3 | A later remediation commit | `en` pushes a review fix; the commit SHA differs from the first publication. | Covered: the scope is the destination, never the SHA; no new answer. |
| 4 | Parent-to-builder handoff | The parent raises the builder with its brief. | The brief carries all five facts (WORKFLOW § *Delegate briefs*); a brief missing one narrows nothing, but the push request then lacks its evidence and the parent supplies it. |
| 5 | Maintenance handoff | A maintenance delegate, a new worktree, takes over a catch-up push. | Covered: a changed actor or worktree is no reason to ask again; the record travels with the handoff. |
| 6 | Idle integration publication | An `--idle` run publishes its one integration delivery branch. | Covered under futon § 5's own rule for that branch, the record naming it as the destination; never forced. |
| 7 | Out-of-scope destination | A delegate is about to push to `branch.base`, another repository, or a tag. | Not covered: refused or behind its own gate, whatever the record says. |
| 8 | Real refusal, supported recovery | The host's reviewer rejects a first publication as insufficiently authorized. | The decision and reason are kept; independent work continues; the parent retries **through the same supported route** only with the record and the maintainer's newly given words. No permission setting, force push or other route. |

**SC-2.** No case asks for renewed human permission solely because the actor, worktree or commit
changed (cases 3–5); no case bypasses a host denial (case 8) or crosses a protected merge or release
boundary (case 7).
