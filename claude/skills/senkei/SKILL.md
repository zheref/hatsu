---
name: senkei
description: Inventory a consuming product repo's own backlog — open epics, live integration branches, and open PRs — classify each effort, and drive every open PR to a CON-32/G2-readiness determination. Use when the maintainer asks for the status of a product repo (KroApple, KroAndroid, or any other Bankai consumer), wants its existing efforts driven forward, or invokes `hatsu:senkei`. Kurapika (Manipulator) enumerates the target repo's backlog, classifies each effort (delivering/building/stalled/queued/idle/undecidable), states a Ready/not-Ready call with the reason for every open PR, and reports one status table per pass. Carries no CON-25 delegation and never merges — G2 stays the maintainer's.
---

# Senkei — inventory and drive a product repo's own backlog to G2-readiness

**Nature: Manipulator.** GitHub-side ops/reporting over a product repo's own backlog. Kurapika
says so when he runs it.

This is the **product-repo counterpart** of `backlog-loop` (plain text — lands with a later port
of hatsu#2). `backlog-loop` will drive bankai-core's own backlog to zero as G4-ready PRs; `senkei`
inventories **one consuming product repo's** backlog — its open epics, live `integration/*`
branches, and open PRs — and drives those PRs to `CON-32`/**G2**-readiness. It never touches
bankai-core's own backlog, and it never mutates the target repo's product code.

The old (bankai-core) version of this skill computed every one of §§2–4 below by improvised prose
and raw `gh`: hand-listing epics and their children over `gh issue list`, hand-computing
ahead/behind for each `integration/*` branch, hand-reasoning the five-class taxonomy from labels,
and re-running a dead reviewer job with a bare `gh run rerun <id> --failed`. This port replaces
those steps with `nen repo inventory`, `nen effort classify` and `nen run rerun-failed` — the three
verbs zheref/hatsu#2 names for this port — plus `nen pr ready` for readiness (unchanged pointer,
shared with every other ported skill via [`hatsu:pr-state`](../pr-state/SKILL.md)) and
`nen parse` for the invocation grammar. What remains genuinely un-mechanizable (the five-class
label→input reshape, the Ready/not-Ready narrative, the escalation channel, the closing table)
stays this skill's judgment. See `docs/ab/senkei.md` for the full mapping, the live evidence
against two real consumer repos, and every finding filed against the binary along the way.

> **Read the target repo's own backlog only.** Never bankai-core's — that is `backlog-loop`'s job
> (plain text — lands with a later port of hatsu#2), and this skill carries no delegation to touch
> it, read or write.

---

## 1. Invocation

```
hatsu:senkei <repo>
```

`<repo>` is a product code, a short name, or a full `owner/repo` — take it from the invocation
(`hatsu:senkei KroApple`, or `hatsu:senkei zheref/KroApple`); **never guess it**. Mechanized:

```
nen parse senkei --grammar "<repo>" --line "<what the maintainer typed>"
```

Verified live (`docs/ab/senkei.md` § 2.1): a single mandatory slot with no bracketed optional
clause parses correctly both ways (`KroApple`, `zheref/KroApple`) and refuses cleanly with a
corrected line when the slot is empty. This is the same generic `--grammar` path
[`backlog-state`](../backlog-state/SKILL.md) found broken for a *bracketed* clause — the defect is
specific to `[ ... ]`, not to `nen parse` as a whole, and senkei's own grammar has no bracket to
trip it.

**When no repo is given**, resolve the registry and ask:

```
nen repo resolve all --repo <path to a checkout carrying schemas/repos.json>
```

An unknown repo is an error that names the token and lists the codes `nen repo resolve`'s own
refusal prints — never a guess, never a prefix match.

**Product repos do not reliably ship their own registry.** Verified live against the real
`zheref/KroApple`: it carries no `schemas/` directory at all — no `repos.json`, no `gates.json`,
no `colors.yml`, no `labels.json` (`docs/ab/senkei.md` § 2.2, two `404`s). The registry that names
its product code (`KP`) and its Nen scenario (`swiftui-tca-uzf-v2`) lives in **bankai-core's own**
`schemas/repos.json`, under `consumers`, alongside `KroAndroid` (`KN`). So `--repo <path>` for
resolution and object notation points at a local bankai-core checkout, never at the product repo
itself — resolve once, up front, and carry the resolved `owner/repo` slug forward:

```
nen repo resolve KP --repo <bankai-core checkout>          # zheref/KroApple  (KP)  via code
nen repo scenario --repo <bankai-core checkout> --target zheref/KroApple   # swiftui-tca-uzf-v2
```

## 2. Enumerate the target repo's backlog — `nen repo inventory`

```
export GH_TOKEN=$(gh auth token)
nen repo inventory --target <owner/name> --epic-label <label> --integration-prefix <prefix> [--trunk main]
```

This is senkei's own live enumeration, named as such in the verb's own `--help`: every open issue
carrying `--epic-label` with its children, every branch under `--integration-prefix` with its
ahead/behind vs `--trunk`, and every open PR. **Always fetched live** — never work from a cached
list; labels, branches and PRs change under you.

- **`--epic-label`** is the target repo's own epic marker (`bankai:epic` on KroApple/KroAndroid —
  confirm against the repo's label set rather than assuming the bankai-core name matches).
- **`--integration-prefix` has no default.** The naming convention for a live integration branch
  (`integration/` on KroApple) is the target repository's own; never hard-code a literal here.
- **`--trunk`** defaults to `main`.

**Verified live against the real `zheref/KroApple`** (`docs/ab/senkei.md` § 3.1):

```
nen repo inventory --target zheref/KroApple --epic-label "bankai:epic" \
                   --integration-prefix "integration/" --trunk main
```

returned **7 open epics** (34 children total, a mix of open/closed), **4 live integration
branches**, **1 open PR**. Two of the four integration branches — `integration/epic-193` and
`integration/epic-213` — belong to epics **already closed** (confirmed independently against the
live issues, `docs/ab/senkei.md` § 3.2): exactly the **idle** class in § 3 below, found on real
data, not constructed. This is the same defect shape `bankai-core#929`
(`docs/ab/backlog-state.md` § 5) names for a different skill: state that outlives the object it was
opened for, left alive because nothing swept it.

## 3. Classify each effort — `nen effort classify`

| Class | Meaning |
| --- | --- |
| **delivering** | A delivery PR is open at **G2** — the final `integration/<epic> → trunk` PR, or a shikai-mode child PR. |
| **building** | A child issue is released (`bankai:stage/building`) to a builder; no PR yet, or a PR is in review. |
| **stalled** | Released with no branch/PR ever opened, or a reviewer job that never posted a `Verdict:` line. |
| **queued** | G1-approved (a mode label picked) but not yet released with `bankai:stage/building`. |
| **idle** | An `integration/*` branch is still alive but its epic is closed — flag for cleanup. |
| **undecidable** | *(new in this port — the verb's own sixth class.)* No stage label, no mode label, no PR, no live branch: a genuinely untriaged issue, never silently folded into `queued`. |

```
nen effort classify --input <path.json>
```

The input is a JSON array of `{kind:"epic"|"child", issueState, stageLabels[], modeLabelPresent,
hasPr, prOpen, prIsDelivery, integrationBranchAlive, reviewerVerdictMissing}` per effort — reshape
`nen repo inventory`'s rows into this shape before calling it (the verb classifies; it does not
fetch). `state-machine-violation` (two stage labels on one object) is flagged, never resolved by
guessing which is authoritative.

> **The `stageLabels` / `modeLabelPresent` split is load-bearing, and getting it wrong
> misclassifies real data.** `modeLabelPresent` is whether a **G1 mode label**
> (`bankai:stage/ready-for-bankai` / `bankai:stage/ready-for-shikai`) was picked; `stageLabels` is
> every **other** `bankai:stage/*` label the object carries. Verified live, three ways
> (`docs/ab/senkei.md` § 3.3–3.5):
>
> - **Feeding the mode label itself into `stageLabels`** (as it literally appears in GitHub's own
>   label list — both live under the same `bankai:stage/*` prefix) makes a G1-approved-but-not-yet-
>   released epic misclassify as `building`, because the verb reads *any* non-empty `stageLabels`
>   as "released" — regardless of which label it is. Reproduced against the real
>   `KP-IS-#17` / `KP-IS-#178` epics: feeding their real `bankai:stage/ready-for-bankai` label into
>   `stageLabels` reports `building`; excluding it (mode label → `modeLabelPresent: true`,
>   `stageLabels: []`) reports the correct `queued` — *"G1-approved (a mode label was picked) but
>   not yet released with a stage label"* — matching the old skill's own taxonomy exactly.
> - **A pre-G1 label** (`bankai:stage/researched`, `bankai:stage/idea`) fed into `stageLabels`
>   reports `stalled` — *"released, but no branch or PR was ever opened"* — even though the old
>   skill's own taxonomy defines `queued`/`stalled` as states an effort reaches only **after** G1
>   approval. An issue still at `researched`/`idea`/`triage` has not yet entered senkei's
>   classification universe at all: **do not feed it to `nen effort classify`** — report it
>   separately as "not yet G1-approved," never as `stalled`.
> - **`queued` is reachable ONLY when `stageLabels` is empty** and `modeLabelPresent` is `true` —
>   confirmed true even with an alive integration branch (`KP-IS-#17`/`#178` again): an alive
>   branch does not upgrade a `queued` row to `building` on its own; only a genuine (non-mode)
>   stage label does.
>
> **Never pass the raw GitHub label list straight through as `stageLabels`.** Strip the G1 mode
> labels into `modeLabelPresent` first, and exclude pre-G1 labels from the classification pass
> entirely — feeding either wrong is a silent misclassification, not a refusal, so there is no
> error to catch it for you.

**`stalled`'s live-signal half is caller-supplied, not fetched here.** A reviewer job that died
mid-run or a builder that burned its turn cap is read from `reviewerVerdictMissing` — the verb's
own `--help` says so plainly. The mechanical rule (released, no branch, no PR) still reaches
`stalled` without it; set `reviewerVerdictMissing: true` only when you have independently confirmed
the dead-reviewer signal (§ 4).

**A child carrying two stage labels at once** is `state-machine-violation` — flagged, never
resolved by guessing which one is authoritative (`agents/_conventions.md` § State machine).

## 4. Drive every open PR to `CON-32`, not to "checks green"

For each open PR, state a **Ready / not-Ready** determination **with the reason** — never
"required checks are green" alone.

**The determination comes from `nen pr ready`** — the same pointer every other ported skill uses
(`hatsu:pr-state`, `docs/ab/pr-state.md`):

```
export GH_TOKEN=$(gh auth token)
nen pr ready <ref> --gh-repo <owner/name> [--gates <path> | --reviewers a,b,c [--approvers a,b]] --explain
```

**Most product repos ship no `schemas/gates.json` of their own — verified against KroApple, not
assumed.** Without `--gates` or `--reviewers`, `nen pr ready` refuses outright: *"no reviewer
identities. This gate never falls back to a built-in reviewer set..."* (exit `2`) — reproduced
live against the real `zheref/KroApple#509` (`docs/ab/senkei.md` § 4.1). This is the same refusal
[`pr-state`](../pr-state/SKILL.md) documents for bankai-core, and the fix is the same shape but a
**different file**: hatsu's `contracts/bankai-core.gates.json` is bankai-core's own reviewer
identities and must **never** be reused for a different repo's PR — that would judge one repo
against another's vocabulary. For a product repo with no `--gates` file of its own:

- If the repo ships `schemas/gates.json`, no flag is needed at all.
- Otherwise, pass `--reviewers`/`--approvers` naming **that repo's own** configured reviewer
  bots — readable off its `.github/workflows/*.yml` review-pair jobs, or stated by the maintainer.
  **Never guess a reviewer set and never substitute bankai-core's.** Verified live: KroApple's
  review-pair reuses the same `sasuke`/`tenma`/`copilot` identities bankai-core's does (its
  `bankai:stage/in-review` label literally reads *"Sasuke and Tenma reviewing"*), which is a fact
  about *this* consumer's CI wiring, not a rule this skill assumes holds for every consumer.
- If neither is available, the refusal **is** the report — surface it verbatim (`nen pr` never
  falls back to a guess), never route around it with an assumed identity set.

**Real verdict, verified live** against `zheref/KroApple#509` with its actual reviewer identities
supplied (`docs/ab/senkei.md` § 4.2): `not-ready: required checks reported but are not all green
(CON-32a)` — the conjunct table (`--explain`) shows exactly which check rollup entries are not yet
green, at the current head, short-circuited before any reviewer-round conjunct is evaluated.

Two rules unchanged from [`pr-state`](../pr-state/SKILL.md) and
[`backlog-state`](../backlog-state/SKILL.md): **never re-derive readiness from the check rollup by
eye** (the current-head rule catches what a glance at the checks page misses), and **the
adversarial confirmation pass may only veto a `ready` verdict, never promote a `not-ready` one**.

Product repos hit failure modes bankai-core's own backlog does not surface as often — check for
these explicitly, by name, in the determination:

- **A reviewer job that died mid-run**, leaving a stale `CHANGES_REQUESTED` on a required check.
  Re-run the failed job — **mechanized**:

  ```
  nen run rerun-failed --target <owner/name> --run-id <n>
  ```

  This is `'gh run rerun <n> --failed'`, exactly — the verb's own `--help` names it *"senkei's
  dead-reviewer recovery."* **Never re-label to force a re-vote.** Verified live and safely: run
  against a real `zheref/hatsu` workflow run whose jobs had all already succeeded — nothing to
  rerun, so the call refuses cleanly with no mutation (`docs/ab/senkei.md` § 5.1): *"run … cannot
  be rerun; This workflow run cannot be retried"* (exit `1`). This is the refusal shape a caller
  sees when there is nothing dead to recover — the affirmative "actually reran a failed job" path
  was **not** exercised (this verb mutates GitHub with no dry-run mode at all, unlike `nen label
  apply`/`nen wake fire`/`nen labels sync`), and this port never exercises it against a real
  consumer repo's PR — only the refusal shape is confirmed, per the shared brief's mutation
  boundary.
- **A builder that burned its turn cap** and pushed nothing — the PR looks "in progress" but is
  actually stalled; call it `stalled` in the classify pass (§ 3), not `building`.
- **A child carrying two `bankai:stage/*` labels** at once — `state-machine-violation` (§ 3);
  flag it, don't guess which one is authoritative.

**Where a PR is stuck for a reason `nen run rerun-failed` doesn't cover** (a swallowed wake, a
`request_changes` vote substituted for one), use the same unblock channel as `backlog-loop`/`drive`
(plain text — both land with a later port of hatsu#2): `bankai:wake/iterate`, fired ALONE, never in
the same breath as a comment. That mechanization (`nen wake fire`) is outside this port's own
Scope (zheref/hatsu#2 names only `nen repo inventory`, `nen effort classify`, `nen run
rerun-failed` for `senkei`) and is left as prose here, exactly as the old skill carried it — see
`docs/ab/senkei.md` § 6 residue.

**Verify the wake reached the builder** — `<agent> / build` having *run*. A `probe` that is
`cancelled` with no `build` job is a **failed wake**, not an attempt, and must be re-fired rather
than counted.

## 5. Report

One status table per pass, `<CODE>-<IS|PR>-#<N>` notation (`nen ref format`), gate named per row:

```
nen ref format --repo <bankai-core checkout> --code KP --kind IS --number 178 --state open \
              --url https://github.com/zheref/KroApple/issues/178
# 📄 [KP-IS-#178](https://github.com/zheref/KroApple/issues/178)
```

| Issue | Class | PR | Checks | Reviews | Ready? | Awaiting |
| --- | --- | --- | --- | --- | --- | --- |
| [KP-IS-#178](https://github.com/zheref/KroApple/issues/178) | queued | — | — | — | — | Release to a builder — G1-M |
| [KP-PR-#509](https://github.com/zheref/KroApple/pull/509) | building | [KP-PR-#509](https://github.com/zheref/KroApple/pull/509) | not all green | — | ❌ not-Ready | `CON-32(a)` — checks |

Draw the gate-stop banner (`nen stop`) only when the maintainer must actually act on something in
the table — a status-only pass reports plainly, no banner.

## Explicitly out of scope

- **No new authority.** `CON-25`'s third carve-out (run-scoped label delegation) belongs to
  `backlog-loop` by name (plain text — lands with a later port of hatsu#2); `senkei` applies **no**
  `bankai:agent/*` or `bankai:stage/*` label without the maintainer's explicit per-action
  confirmation, same as Kurapika outside a named run.
- **No merging, anywhere.** G2 is the target repo's maintainer's, same as it is on bankai-core.
- **No writes to product code by this skill.** It **inventories and drives** — it never edits the
  target repo's product source itself.

## Hard limits

- Never merge, on any repo, for any reason.
- Never apply a label without the maintainer's per-action confirmation — this skill carries no
  run-scoped delegation.
- Never cast a `request_changes` review to move a stuck PR — use `bankai:wake/iterate` (prose
  channel, § 4).
- Never guess the target repo when none is given (§ 1).
- Never feed a pre-G1 or mode-carrying label straight into `nen effort classify`'s `stageLabels`
  without the reshape § 3 requires — verified live to misclassify.
- Never reuse `contracts/bankai-core.gates.json` (or any other repo's reviewer identities) for a
  different repo's `nen pr ready` call (§ 4).
- Never exercise `nen run rerun-failed`'s affirmative rerun path against a repo whose PRs you do
  not control the consequences of — this port only confirms the refusal shape (§ 4).
- 5-round cap per PR (`agents/_conventions.md` § Discipline 2), then escalate to the maintainer.
