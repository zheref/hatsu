---
name: backlog-synthesis
description: Reconcile a long backlog into a smaller one — group open issues that target the same rule/clause, machinery file or root cause, propose a consolidation plan as an iterable Artifact, and on approval file one consolidated issue, attach the originals as sub-issues and close them with a reference. Use when the maintainer invokes hatsu:backlog-synthesis <critical|high|medium|low|all> [<repo>], or asks to consolidate, synthesize, dedupe or shrink a backlog.
---

# Backlog synthesis — turn a long backlog into a short one

**Nature: Manipulator, with Conjurer named alongside.** The choreography that writes — filing,
attaching, closing, labelling — is GitHub-side ops, Manipulator's lane. The judgment that decides
*what* to write — grouping by clause, machinery file or root cause; the consolidated title and
body; the DECIDE options — is governance reasoning over the whole open set, Conjurer's lane. Name
which leads: Conjurer leads §§ 3–4 (the plan), Manipulator leads § 5 (the execution).

The problem this exists for, in the maintainer's framing: a backlog large enough that **work
overtakes work**. Three issues filed six weeks apart against the same clause are three PRs that
conflict, and the last one to land silently supersedes the other two — after all three were built.

> **Read the whole open set, group what genuinely converges, propose the consolidation as a plan I
> can argue with, and only then rewrite the backlog.**

The output is not a report. It is **fewer, better issues**.

The old (bankai-core) version of this skill computed every deterministic step below by improvised
prose and hand-typed `gh` — the four searches were eyeballed, the sub-issue attach was a raw `gh
api .../sub_issues` call the agent had to remember takes an id and not a number, and the close
choreography was a manually-ordered sequence of separate `gh issue comment`/`gh issue close`
calls with no guard against orphaning an issue that carries an open PR. This port replaces every
one of those with a `nen` verb — `nen backlog fetch`, `nen issue search`, `nen issue
open-pr-check`, `nen issue file`, `nen issue attach-sub`, `nen issue consolidate-close`, `nen ref
format` — per zheref/hatsu#2. What remains genuinely un-mechanizable (grouping judgment, root-cause
analysis, the drafted consolidated body, the plan, the approval gate) stays this skill's, same as
before. See `docs/ab/backlog-synthesis.md` for the full mapping, the live evidence and every
finding filed against the binary along the way.

---

## 1. Invocation

```
hatsu:backlog-synthesis <critical | high | medium | low | all> [<repo>]
```

**The severity filter is required — there is no default**, because `all` and `critical` are
enormously different runs and neither is a safe assumption:

- `critical` / `high` / `medium` / `low` — the open issues carrying that severity label
  (`bankai:severity/*` in the target repo's own taxonomy).
- `all` — **every** open issue, **including untriaged ones** (no severity label). Untriaged issues
  are listed separately in the plan with a proposed severity, because an issue nobody triaged is
  exactly the kind that gets consolidated by accident.

A token that does not match the closed enum above (case-insensitively) is a parsing error — ask
for a valid filter rather than guessing which one was meant.

**The repo, when given**, is resolved the same way `hatsu:file` § 1 resolves its own trailing
token — never hand-typed, never guessed:

```bash
nen repo resolve <token>
```

Exit `0` → that is the target. **The repo, when omitted:** `nen repo resolve` with no token,
against the standing checkout's own `origin` — see
[`hatsu:file`](../file/SKILL.md) § 1 and
[`hatsu:backlog-state`](../backlog-state/SKILL.md) § 1 for the exact refusal shape (an unknown
token or an unregistered origin is an error that lists the registry's own codes, never a fallback
to `all` and never a guess).

> **This skill reconciles a repository's process/system backlog** — governance, canon and
> machinery — the same distinction the old skill drew: product backlogs converge on features, not
> on clauses or machinery files, and the grouping signals in § 3 would not hold there. If the
> resolved repo's issues plainly converge on product features rather than process, say so plainly
> and ask whether this is really the intended target, rather than running the wrong analysis.

> ⚠️ **The resolved target must never be `bankai-core` (`BC`).** bankai-core is **frozen** —
> every sibling port that touches it says so, and this skill's whole job in § 5 is to *write*
> (file, attach, close, label). If `nen repo resolve` resolves to `zheref/bankai-core`, **refuse
> the run** and say why: bankai-core's own process backlog no longer takes writes from any tool,
> this skill included. Read-only reference against bankai-core (as evidence, as a worked example,
> as a second opinion) is fine — § 2–§ 4 may run against it to *plan* — but § 5 never executes
> there. The live A/B evidence in `docs/ab/backlog-synthesis.md` reads bankai-core's real backlog
> for exactly this reason: it is the richest real dataset available, read-only throughout.

## 2. Fetch the whole set — no caps, no samples

```bash
export GH_TOKEN=$(gh auth token)
nen backlog fetch --repo-slug <owner/name>
```

Fetches every open issue **and** open PR fresh over the GitHub API — **never cached**, and
**paginated**: it follows `?page=N` until a short page comes back rather than stopping at GitHub's
100-row clamp. **Omit `--limit`** — a capped fetch is always reported `truncated: true`, never
presented as complete, and a consolidation computed over a truncated set closes issues it never
read.

- **State the resolved set before the plan**: *"88 open issues; 7 `high`, 60 `medium`, 14 `low`, 7
  untriaged."* (Real counts, from a live, uncapped fetch against `zheref/bankai-core` — § 1 of
  `docs/ab/backlog-synthesis.md`.) A reader who cannot see what was swept cannot tell a small
  backlog from a short fetch.
- **The row schema is thin by design** (`{issueNumber, title, labels, prNumbers[], createdAt}` —
  same shape [`hatsu:backlog-state`](../backlog-state/SKILL.md) § 3 already documents). Severity
  is read off `labels`. **Body, comments and the sub-issue graph are NOT in this row** — no `nen`
  verb fetches those in bulk; per-issue `gh issue view <n> --json body,comments` remains a
  necessary raw call for the grouping read in § 3 (residue, `docs/ab/backlog-synthesis.md` § 3 —
  the same class of gap `backlog-state`'s own doc records for PR-level detail).
- **Never work from a remembered list.** Severities and labels move under you, and this run
  closes things.

## 3. Grouping — what converges, and what only looks like it

Unchanged from the old skill — this is the judgment layer, and no `nen` verb replaces it. A group
is a set of open issues that **one unit of work would resolve together**. Four convergence
signals, strongest first:

1. **The same rule or clause.** Two issues both amending the same numbered rule (`CON-{n}` in this
   repo's own constitution, or the equivalent citation form its canon uses) are one amendment;
   landing them separately means the second rewrites the first's text.
2. **The same machinery file or surface.** Two issues both changing the same script, or both adding
   a guard to the same workflow, will conflict in the diff.
3. **The same root cause.** Different symptoms, one defect. This is the highest-value grouping and
   the one a label-based sweep never finds — it needs the bodies read.
4. **The same acceptance criteria, differently worded.** A near-duplicate that the original filing
   missed.

**Use `nen issue search` to confirm a suspected cluster, never to invent one.** Once a read of the
fetched set surfaces candidates that might share signal 1 or 2, confirm mechanically rather than
trusting a skim:

```bash
nen issue search --target <owner/name> --subject "<shared topic>" \
  --files <shared file,another file> --rule-ids <shared clause,another clause> \
  --lane-labels <shared lane label>
```

This is the same verb [`hatsu:file`](../file/SKILL.md) § 3 uses for duplicate reconciliation,
turned here toward clustering instead of deduplication: the `files-and-rule-ids` and `lane` passes
surface every other open issue sharing a file, a clause or a lane, mechanically, without
re-deriving the query by hand. **Verified live against the real `zheref/bankai-core` backlog**
(`docs/ab/backlog-synthesis.md` § 2.2): a search on `scripts/pr_ready_gate.sh` + `CON-32` surfaced
a nine-issue cluster sharing both signals — real grouping input, not a fabricated example.

**Four anti-rules, and they matter more than the signals** — an over-eager grouping destroys
information that took weeks to accumulate:

- **Never group across authority levels without saying what that makes it.** A governance change,
  the canon it implies, and the machinery that implements it are a dependency chain. They may
  legitimately consolidate — but into a **chore** delivered on an `integration/<chore>` branch, not
  into one PR. If a group needs more than one PR, the plan says so and the consolidated issue is
  written as a chore.
- **Never group on topic alone.** "Both about labels" is a shelf, not a unit of work. If the group
  cannot be given **one** set of acceptance criteria, it is not a group.
- **Never group an issue whose scope you would have to shrink to make it fit.** Consolidation must
  preserve every acceptance criterion; anything dropped in the merge is scope silently deleted.
- **Never group away a disagreement.** Two issues proposing *opposite* fixes for one problem do not
  consolidate into one requirement — they consolidate into one **decision**, which is a `DECIDE`
  ask, not a merged body.

**A group of one is not a group.** Leave it alone; the plan says how many issues were examined and
left standing, because "not consolidated" is a result.

## 4. The plan — an Artifact you can argue with

Publish the plan as a **single Artifact**, and **iterate it in place**: each round redeploys the
same URL with a version label, so there is one plan with a history rather than five plans.

The plan carries, per proposed group:

| Section | Content |
|---|---|
| **The group** | Every member in object notation (`nen ref format --code <CODE> --kind IS --number <n> --state <s>`), linked, with severity, lane labels, age and any open PR |
| **Why these converge** | Which signal from § 3 fired, **quoting the shared clause, file or root cause** — and the `nen issue search` query that confirmed it, when one was run. Not "related" — the actual convergence |
| **The consolidated issue** | Its drafted title and full body: the merged problem statement, and **every** member's acceptance criteria preserved and attributed to the issue it came from |
| **Shape** | One PR, or a chore with its legs named |
| **Severity** | The **highest** in the group, with the member that sets it named |
| **Lanes** | The **union** of the members' agent/lane labels |
| **Disposition per member** | `close-and-link` · `link-only` (an open PR — flagged by `nen issue open-pr-check`, § 5) · `excluded`, each with its reason |
| **What is lost** | Anything the merge does not carry forward, stated explicitly. If nothing, say nothing is lost |

And, once across the whole plan: **the issues examined and deliberately left standing**, with a
one-line reason each. A synthesis that only shows what it wants to change cannot be audited.

**The stop is a `G5` gate event**, rendered with the shared verb rather than reconstructed by hand:

```bash
nen stop --who Kurapika --gate G5 efforts.md
```

(or `-` to pipe a one-row efforts table through stdin). Keep the chat to ~5 lines, link the plan,
and put the **`DECIDE`** ask through the harness's own question interface — *execute plan vN* /
*revise group X* / *split group Y* / *abandon* — with the ⭐ recommendation and what would tip it.

> **Why the plan page, and not a gate board, is the rich surface here.** The board briefs a
> decision in a few lines per ask; this decision is a document — dozens of issues, their criteria,
> and what each merge would cost. The plan page carries strictly more of the same information, in
> the same panel, under the same identity, and a board beside it would duplicate one ask and
> nothing else. The banner still fires, the question still goes through the harness, and the gate
> is still `G5`. This substitution is for **this** skill's plan stop only — every other stop in
> every other skill renders the board.

**Iterate until the maintainer is satisfied.** Their revisions are instructions about the plan, and
each round republishes the same Artifact. **Nothing is written to GitHub during iteration** — not a
comment, not a label, not a close.

## 5. Execution — only after approval, and in this order

**Split each approved group's members into two sets before touching anything**, per the plan's own
disposition column:

- **`closeSet`** — members disposed `close-and-link` (no open PR).
- **`linkOnlySet`** — members disposed `link-only` (an open PR in flight).

`nen issue consolidate-close`'s own open-PR guard is **all-or-nothing across the children it is
given** (`--allow-open-pr` overrides it for the *whole* call, never selectively) — so a mixed group
is never handed to one call. Partitioning first, and handing each set to the verb that matches its
disposition, is what makes the choreography exact instead of an override the plan never asked for.

Per approved group:

**1 — File the consolidated issue**, labels **in the create call**, matching
[`hatsu:file`](../file/SKILL.md) § 5's own discipline exactly:

```bash
nen issue file --target <owner/name> --repo <path to a checkout carrying schemas/*.json> \
  --title "<title>" --body-file <path> \
  --label <severity>,<lane-union>,<kind> --assignee <human> \
  --forbid-family <the target repo's stage-label family>
```

Body carries: the merged problem statement; every member's acceptance criteria, attributed; the
shape (one PR, or a chore with its legs); the convergence rationale (§ 3's signal, quoted); and the
full member list (both sets) in object notation. **`--forbid-family` on every call** — no stage
label on the consolidated issue either (§ 6).

**2 — Re-guard immediately before closing anything.** The plan's disposition was computed when the
plan was drafted; the backlog may have moved since. Re-run the guard live, right before executing:

```bash
nen issue open-pr-check --target <owner/name> --issues <closeSet, comma-separated>
```

Exit `1` here is not a bug in the plan — it is the backlog having changed. Move whichever candidate
now carries an open PR from `closeSet` into `linkOnlySet` and say so; **never override the guard to
force the plan's original classification through**.

**3 — Attach and close the `closeSet`, atomically, guarded:**

```bash
nen issue consolidate-close --target <owner/name> --parent <consolidated#> \
  --children <closeSet> --repo <path>
```

This **is** the file→attach→close choreography's second and third acts in one call: it resolves
each child's id (the sub-issues API takes an id, not a number — the old skill's own parenthetical
about this is now the verb's job, not a step to remember), attaches every child as a sub-issue of
the parent, runs the **same** `open-pr-check` guard over the whole set **again** immediately before
closing (refusing the *entire* close and naming the blocking PRs if anything slipped through step
2), and only then closes each child — reporting the **label union** and **severity maximum** it
computed from the children's own current labels as it goes. **Cross-check that computed union
against the plan's own union and severity call** — a mismatch means a child's labels moved between
the plan and this execution, and that discrepancy is surfaced, never silently reconciled by
trusting whichever number is newer.

**4 — Attach the `linkOnlySet`, without closing:**

```bash
nen issue attach-sub --target <owner/name> --parent <consolidated#> --children <linkOnlySet>
```

Same id resolution, same sub-issue attach — but this verb never closes anything, so a member with
an open PR in flight is linked into the consolidated issue's graph and **left open**, exactly as
the plan's `link-only` disposition promised. If the maintainer's approved plan explicitly said to
close one of these anyway (their call, made with the open PR in front of them), that member moves
to step 3's `closeSet` instead, with `--allow-open-pr` passed to `consolidate-close` for that call
only — never applied blanket to a set the plan did not name it for.

> **`nen issue attach-sub`'s JSON result carries a `fallbackTaskList` field** — when the sub-issues
> API is unavailable for the target repository, the verb falls back to a task-list block in the
> parent's body and reports which form it used, rather than the caller needing to detect the
> failure and improvise the fallback itself. **Not verified live**: every repo this port's A/B
> pass tested (`zheref/bankai-core`, and a refused nonexistent-repo probe) supports the sub-issues
> API natively or fails before the fallback path is reached, so the fallback never fired in
> practice — `docs/ab/backlog-synthesis.md` § 3 records this as inferred from the JSON schema, not
> observed. **Relay whichever form the JSON reports** — a claimed sub-issue graph that does not
> exist misleads every later sweep, same warning the old skill's own prose carried.

**5 — Report**: the consolidated issues filed, the members closed and the members link-only-attached
(each in object notation via `nen ref format`), the count before and after, the label union/severity
max each `consolidate-close` call computed, and every label application.

**Order matters.** File before attach, attach before close — a close comment that points at an
issue that does not exist yet is a dead reference, and `nen issue consolidate-close`'s own
choreography enforces exactly this order internally (its own `--help` text names it: "file (already
done by the caller) -> attach -> close"). A failure halfway through (step 3 refusing mid-group)
leaves that group's members attached but still open — report it as partial, never as failed
silently.

## 6. Authority

`CON-25`'s fourth carve-out, at its narrowest:

- **Permitted:** the lane/agent and severity labels on the consolidated issue, **exactly as the
  approved plan states**; the attach and close calls the plan names; `--allow-open-pr` only where
  the plan explicitly named that member for it.
- **Not permitted:** any stage label (`--forbid-family` on `nen issue file` makes this a call
  refusal, not a rule to remember — § 5 step 1) — synthesis reorganizes the backlog, it does not
  start work; any G1 mode label; any merge; any review vote.
- **Log every application**, and say when the run ends so the delegation lapses.

## 7. After — offer the build

For each consolidated issue, offer the next verb in one line:

```
hatsu:build <CODE>#<N>
```

(lands with a later port of hatsu#2). **Offer it; never start it.** Releasing into build is a
separate go-signal.

## 8. Hard limits

- **Never runs § 5 against `bankai-core`.** It is frozen; a resolved target of `zheref/bankai-core`
  refuses at § 1, before the fetch even runs.
- **Never closes an issue the approved plan did not name**, and never before the consolidated issue
  exists and links it.
- **Never hands a mixed close/link-only group to one `consolidate-close` call.** Partition first
  (§ 5); `--allow-open-pr` is all-or-nothing per call, and applying it to a set the plan did not
  clear for it overrides the guard the plan's own approval depended on.
- **Never drops an acceptance criterion** in a merge. If it cannot be carried, the plan says so
  before approval, not the close comment afterwards.
- **Never groups on topic alone**, across authority levels without naming the chore, or over a
  genuine disagreement.
- **Never writes anything to GitHub during plan iteration.**
- **Never runs on a truncated fetch** (`nen backlog fetch`'s own `truncated` field) without saying
  so.
- **Never applies a stage label, merges, or votes.**
- **Never re-links a stale plan.** Each iteration republishes the same Artifact with fresh counts;
  an old page presented as current carries stale numbers with a fresh page's authority.
- **Never trusts a re-guard's absence.** Step 2's `open-pr-check` runs immediately before step 3,
  never reused from the plan's own earlier run — the backlog moves under a long-running synthesis.
