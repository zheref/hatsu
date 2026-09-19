# Standalone entry — how a skill starts from a cold checkout

**This file is the authority on what a skill does when nobody called it.**
[`WORKFLOW.md`](WORKFLOW.md) is the authority on the loop; [`ROSTER.md`](ROSTER.md) on who exists;
this one covers the single question neither of them answered: *what happens when the maintainer types
a phase's name into a working directory that no composite is holding.*

> **Redaction notice.** Where this file names a repository that is not public, the name is a stable
> placeholder — see [`PUBLIC-REDACTION.md`](PUBLIC-REDACTION.md).

---

## 1. The problem this closes

Hatsu's phases were authored **from the inside out**. `breath` was written as *step one of `ren`*,
`kokusen` as *step three*, `byakugan` as *the coverage step of `mukai`*. Each one is correct in that
position and each one reads its surroundings from a caller that, in that position, always exists.

The maintainer does not always work that way. Work gets done in the IDE. Work gets done by an agent
in a session that never named a phase. Then the maintainer looks at what they have and wants
**one** phase run over it — verify this, review this, test just what I touched, report on this.

At that moment the phase is standing in a working directory in an **arbitrary** state, and the four
things it was built to inherit are not there:

| # | Inherited state | What it looks like when a phase is called cold |
|---|---|---|
| **S1** | **The turn / effort boundary** — "what this turn changed" | There is no turn. No base was recorded, so *changed* has no referent |
| **S2** | **A mandatory argument the caller always supplied** — a lane, a target, a PR number | The grammar refuses, correctly, and the maintainer is left with a refusal instead of a run |
| **S3** | **A position in an order** — "first turn of a `ren` loop", "after `mukai`'s review step" | The signal that decided a branch of the protocol does not exist, and the default reading is usually the wrong one |
| **S4** | **An artifact a predecessor created** — the Hanten cycle ledger, a pushed branch, an open PR | It is absent, and absence reads as *exhausted*, *nothing to do*, or a crash. **Only the phase that owns an artifact may create it** — a phase that finds one missing routes to that owner and never fabricates it |

**A skill that cannot answer S1–S4 from the checkout in front of it, or ask for what it cannot
derive, is not a skill the maintainer can reach.** That is what this contract fixes.

---

## 2. The two rules that bound it

**Rule 1 — every skill is reachable alone.** A phase named in
[`claude/skills/`](../claude/skills/) can be typed by the maintainer into any checkout, in any state,
and will either run or say precisely which fact it needs and ask for it. *It does not matter that it
was authored as somebody's step.*

**Rule 2 — no skill is ever indefinitely independent.** Standalone entry is an **entry**, not a mode.
A skill is a **wireable** unit: the same run must be identical whether a composite called it or the
maintainer did, and a standalone run therefore:

- **absorbs no later phase.** `kokusen` called alone still does not push. `hanten` called alone still
  does not open a PR. Filling in for a caller that is not there is how a phase becomes a composite
  nobody ratified.
- **creates no standing authority.** Nothing derived in § 3 survives the run. The next invocation
  re-derives it. A go, a grant, a gate crossing, a delegation — none of these are ever a by-product of
  starting cold.
- **crosses no gate the wired run would not cross.** `G1`–`G5` are unmoved by who typed the name.
  `mugetsu` standalone is still `G3`; `aka` standalone is still the maintainer's call alone.
- **ends by naming its successor** (§ 6), so the maintainer can wire the rest by hand or hand it to
  the composite that owns it.

**Rule 2's corollary, on agents.** An agent invokes a skill **only where that skill's own contract
names it as an invoker** — `hanten` raises reviewers, `en` hands to Illumi, `third-hand` runs as
Netero. Standalone entry widens the set of people who can *type* a skill; it widens the set of
**agents** that may *call* one by exactly nothing.

---

## 3. The preamble — five steps, in this order, before the skill's own § 1

Every skill that carries a **`## 0. Standalone entry`** section runs this first when no composite is
holding the run. A skill running *inside* a composite skips it entirely: the caller already
established every one of these, and re-deriving them is how two answers to one question appear.

**P1 · Warm up.** [`hatsu:hatsu-warmup`](../claude/skills/hatsu-warmup/SKILL.md), unconditionally.
Hatsu's hard Nen dependency (`D10`) is satisfied by the composites before they reach a phase; a phase
reached directly has nobody to have done it. A `nen` call on an unwarmed host is the failure this step
exists to prevent, and it is fail-closed with auto-install.

**A phase that WARMS state, rather than merely reading it, runs at most once per session and is never
skipped when it is owed** — maintainer's ruling, 2026-09-18.
[`hatsu:breath`](../claude/skills/breath/SKILL.md) § 0a is the live case, and both halves bind: a
second run in one session is refused as a repeat rather than performed as a no-op, and a session that
never ran it is a session working on an unproven base. **The guard is the session's own record, not a
file on disk**: the ruling is per session, so a later session re-enters the phase and finds the work
already reflected in the checkout — which is what makes the second pass cheap instead of a repeat. An
artifact left behind by an earlier run is evidence of state, never a substitute for the session's own
knowledge of what it has done.

**P1b · A phase that must prove a base proves it on a tree holding none of the effort** —
maintainer's ruling, 2026-09-18. Verifying a base *underneath* work already written produces a red
nobody can attribute: the base may have been broken all along, or the work may have broken it, and no
amount of prose settles which. [`hatsu:breath`](../claude/skills/breath/SKILL.md) § 0c is the live
case and the pattern is general — **preserve, prove, place, restore**:

| Step | What it does | The rule it carries |
|---|---|---|
| **Preserve** | `git stash push --include-untracked`, **SHA captured and printed** | Addressed by SHA, never `stash@{0}` — that index moves. Never `--discard`, never `reset --hard` |
| **Prove** | The declared checks against `origin/<branch.base>`, in an isolated worktree | The tree under test holds none of the effort. A red here is the base's, and it is a **G5** before anything returns |
| **Place** | The maintainer's commits replayed onto the proven tip | Through [`hatsu:ao`](../claude/skills/ao/SKILL.md): rebase when nothing is published, **merge when something is**. A published commit is never rewritten |
| **Restore** | The stash reapplied, still uncommitted | The working copy comes back. On any failure the stash is **not dropped**, and the SHA is printed with the recovery command |

**The guarantee this buys is one sentence: a red after the restore is the effort's.** That is not a
judgement call any more, and it is the reason the extra steps are worth taking. **A phase that cannot
complete the proof reports the base as UNPROVEN and stops** — an unproven base is exactly what this
exists to stop anybody authoring onto.

**P2 · Orient — read the checkout, never assume it.**

```bash
nen wc classify --repo <path> --json
```

Then state, out loud and in one block, before doing anything:

- the **branch**, and whether it is `nen/workflow.json → branch.base` (the trunk) or not;
- **dirty or clean**, with every uncommitted path listed when dirty;
- **commits ahead of the base**, and whether any of them are **published** (`git ls-remote`), because
  published-or-not is what decides rebase-vs-merge everywhere in this system;
- whether an **open PR** exists for this branch, where the skill's work depends on one.

This block is not optional decoration. It is the evidence for every derivation that follows, and the
maintainer reading it is how a wrong derivation gets caught before it costs anything.

**P3 · Establish the delta — the base is `origin/<branch.base>`, fetched.**

**S1's answer.** *Changed* means **changed against the freshly fetched remote trunk**, and it is the
union of two sets, both of which count:

| Set | How it is read |
|---|---|
| **committed delta** | `git diff --name-only origin/<branch.base>...HEAD` |
| **uncommitted delta** | `git status --porcelain` — staged, unstaged and untracked |

```bash
git fetch origin                                   # the ref must be current or the delta is a guess
git diff --name-only origin/<branch.base>...HEAD   # committed
git status --porcelain                             # uncommitted
```

**The default is the LATEST state of the trunk** — maintainer's ruling, 2026-09-18. `git fetch origin`
runs first, and the base is `origin/<branch.base>`. The **local** ref is used only where that fetch has
just proved it equal, which is the same commit by a shorter name and not a different rule. A local
`main` nobody fetched is never the base: it produces a delta that silently folds in other people's
work, and a phase that measures, tests or reviews that delta reports on a change set the maintainer
never made.

**The clause is `against <base>`, and it is now declared by every skill that reads a delta** —
maintainer's ruling, 2026-09-18, which closed this as a grammar question rather than leaving it open.
Verified live at nen `0.10.0`, including the two-clause and enum-plus-base shapes:

| Relation | Clause | Skills |
|---|---|---|
| **A delta measured against a base** | **`against <base>`** | [`byakugan`](../claude/skills/byakugan/SKILL.md), [`kokusen`](../claude/skills/kokusen/SKILL.md), [`tsukuyomi`](../claude/skills/tsukuyomi/SKILL.md), [`kotoamatsukami`](../claude/skills/kotoamatsukami/SKILL.md), [`rikugan`](../claude/skills/rikugan/SKILL.md), [`hanten`](../claude/skills/hanten/SKILL.md) |
| **A branch brought up to date *from* a base** | **`from <base>`** | [`ao`](../claude/skills/ao/SKILL.md), [`murasaki`](../claude/skills/murasaki/SKILL.md) |

**Two prepositions, because they name two different relations**, not because the grammars drifted.
A delta is read *against* a reference; a catch-up pulls *from* a source. Unifying them would make one
of the two inaccurate, so each grammar keeps the word its own operation earns — and no skill documents
a clause `nen parse` would refuse, which is the defect this table replaced. Where a clause sits beside
another, it is one grammar with two optional anchored clauses (`on [<lane>] against [<base>]`,
`as [<variant>] against [<base>]`, `for [<scope>] against [<base>]`), each verified live.

**The resolved base is named out loud, every run, clause or no clause.**

**A fetch that does not happen is a stop, never a silent fall-back to the local ref.** *Latest* is a
claim, and only the fetch establishes it — so each of these **stops, names the condition, and offers
the `against <base>` clause as the explicit override**:

| Condition | What the skill does |
|---|---|
| `git fetch origin` **fails** (offline, auth, a dead remote) | Stop. Quote the failure. **Never** measure, test or review against an unfetched local ref, which cannot be known to be latest |
| The checkout has **no `origin`** | Stop, and say which remotes it does have |
| `origin/<branch.base>` **does not resolve** after a successful fetch | Stop, and name the base that was looked for |
| A **detached `HEAD`** | Classified and reported, never refused outright — [`hatsu:breath`](../claude/skills/breath/SKILL.md) § 3 is the shape |

**P5's declaration line asserts `(fetched <sha>)` only for a fetch that actually ran.** A phase that
prints it after a failed fetch has stated a fact it does not have, which is worse than the stop it
avoided.

**An empty delta is a finding, not a failure.** Say so, say what would make it non-empty, and stop
without inventing work.

**P4 · Elicit only what P2 and P3 could not derive.**

**S2 and S3's answer.** Derive first; ask second; **never default silently**. What can be derived —
a lane from the changed paths, a gate from the base branch, a target from the declaration — is derived
and **named**. What cannot is asked, through **the surface's own native option picker**, with the
derived recommendation **starred** and the evidence for it in the question — **never lettered options
in the reply** when that picker exists.

**[`SURFACES.md`](SURFACES.md) § 1 is the authority on which tool that is on each surface and what
flags it takes.** It is not copied here: a capability table reproduced in a second file is the shape
that goes stale the next time a surface adds a flag. Two Codex-specific behaviours are worth carrying
because they change what may be asked rather than how: `questions` is capped at **1–3** with
`isBlocking: true`, and **no *Other* option is supplied** — the client adds it. **Headless, or a
stripped tool set with no picker at all: do not proceed on a guess.** Say the picker could not run and
name the flag or clause that would have answered the question.

**One question, at most three.** A phase that interrogates the maintainer for four facts it could
have read off the checkout has moved the cost of the preamble onto them, which is the opposite of what
it is for. Where three is not enough, ask the one that unblocks the most and re-derive from the answer.

**A question is never asked twice in one run**, and a question the maintainer already answered in the
invocation is never asked at all — that is [`hatsu:kagutsuchi`](../claude/skills/kagutsuchi/SKILL.md)
§ 1's rule, and it generalizes: *asking again would be theatre*.

**P5 · Declare the entry, and say what is NOT running.**

One line, in the report and before the work:

> **Standalone entry** · no composite is holding this run · base `origin/main` (fetched <sha>) ·
> delta 7 files (4 committed, 3 uncommitted) · <what was derived> · <what was asked>

Then name the phases of the wired run that are **not** happening, because the maintainer's mental
model of the pipeline is the thing most likely to be wrong at this moment. `kokusen` alone is not
`ren`. `hanten` alone is not `mukai`. Saying so costs one line and prevents the class of mistake
where a maintainer believes a change has been reviewed, tested and reported because one of the three ran.

---

## 4. Where the preamble does NOT run

- **Inside ANY composite.** A composite establishes P1–P4 itself, so the phase it calls **skips § 0
  entirely** and **says which composite is holding it**. The condition is generic on purpose: a phase
  must not carry a list of its callers, because the list is what goes stale — `sharingan` naming only
  `en` while `build`, `futon`, `getsuga`, `backlog-loop` and `jujisho` all reach it is exactly that
  failure. **Both sides state it**: every composite that calls a `## 0.`-bearing phase carries the
  skip clause — `ren`, `mukai`, `en`, `build`, `futon`, `getsuga`, `backlog-loop`, `tensho`,
  `jujisho`, `senkei` — and every phase states the generic condition rather than a caller list.
  **The failure this prevents is a composite and a § 0 deriving the same value two ways**: a `build`
  run that passes `sharingan` a PR number must not have § 0 re-derive one from `gh pr list`.
- **In a skill whose grammar or reading is already total** — it resolves everything from its own
  arguments, the declaration, or the tree in front of it, and inherits no caller state at all.
  **Carrying a `## 0.` that says only that** — P1 still applies, and here is what the argument does not
  cover: [`hatsu:gyo`](../claude/skills/gyo/SKILL.md), [`hatsu:ao`](../claude/skills/ao/SKILL.md),
  [`hatsu:susanoo`](../claude/skills/susanoo/SKILL.md), [`hatsu:aka`](../claude/skills/aka/SKILL.md),
  [`hatsu:jutaisho`](../claude/skills/jutaisho/SKILL.md), [`hatsu:shibari`](../claude/skills/shibari/SKILL.md).
  **Total and carrying no `## 0.` at all**, because there is nothing for one to say:
  [`hatsu:pr-state`](../claude/skills/pr-state/SKILL.md),
  [`hatsu:backlog-state`](../claude/skills/backlog-state/SKILL.md),
  [`hatsu:bankai-handbooks`](../claude/skills/bankai-handbooks/SKILL.md) — read-only resolvers over a
  registry, which P1 reaches through whatever called them.
  [`hatsu:sharingan`](../claude/skills/sharingan/SKILL.md) is **not** in either group: its grammar is
  total, but its `## 0.` carries a real derivation (§ 7), because an omitted `#<PR>` is recoverable
  from the checkout.
- **In a skill deliberately bound to a caller.** [`hatsu:rasengan`](../claude/skills/rasengan/SKILL.md)
  authors what `ren` step 2 was asked for — the request is the input, and no checkout supplies it. This
  is **not** an independence gap: it is a phase whose whole contract is a relationship, and the honest
  answer when it is typed without a request is to ask for the request rather than infer one.
  **`rasengan` is the only skill in this class.** **`murasaki` is not**: typed alone it does its own
  step 1 — catch this branch up with the fetched remote base, resolving the mechanical conflicts and
  stopping at `G5` on a semantic one — which is complete work, and it declines only the phases that
  were never its.

---

## 5. The gates standalone entry never moves

**`G1`–`G5` are unmoved by who typed a skill's name** (§ 2, Rule 2). Four are worth naming explicitly,
because a cold entry is where each is most likely to be quietly re-read:

- **`G1` (`CON-4`) — product intake**, and **`G1-M`**, the mode label. A standalone run files nothing
  and labels nothing it was not asked to; [`hatsu:file`](../claude/skills/file/SKILL.md)'s own
  one-confirmation rule is unchanged, and `G1-M` is never applied by a phase that merely started cold.
- **`G2` — the merge.** It has no skill, and standalone entry does not give it one.
- **`G3` (`CON-6`) — publication.** [`hatsu:mugetsu`](../claude/skills/mugetsu/SKILL.md) is *already*
  standalone-only: no composite may reach it and no agent may propose it. Its § 0 therefore adds
  **nothing** to what it may do — it only makes the preamble's orientation and refusals legible, so a
  cold invocation prints the preflight and the plan and reports that it has no go, exactly as before.
- **`G4` (`CON-7`) — canon and machinery, *in a canon repository*.** The gate is the repository's role,
  not the file's kind (maintainer's ruling, 2026-09-18 — [`ROSTER.md`](ROSTER.md) § *Rulings of
  2026-09-18*): it is `zheref/hatsu`, `zheref/nen` and `zheref/bankai-core`, whose product is the process,
  and a consumer repository's own `nen/*.json` or CI workflow is configuration standing at `G2`. This is
  the gate this document itself sits at, and the one
  a `## 0.` section is most tempted to cross by accident. **Standalone entry authors no canon.** A rule
  a cold run finds missing, a grammar it wishes were wider, a threshold it would rather not fail — each
  is a question for the maintainer through [`hatsu:file`](../claude/skills/file/SKILL.md), never a
  clause written into a skill in passing. A `## 0.` that widens a touched set, a budget, or a base
  clause has changed policy from inside a phase, which is the failure this bullet exists to name.

**A G5 (`CON-47`) reached from a standalone entry is a real G5**: the `nen stop` banner, the report
link, lettered options with ⭐ on the recommendation, and the question through the surface's own
picker — [`hatsu:jutaisho`](../claude/skills/jutaisho/SKILL.md) § 4's four parts, all four. **And its
population never widens**: the five conditions are the five, measured over exactly the set the wired
run would have measured.

---

## 6. The hand-back line — Rule 2, made mechanical

**Every standalone run ends by naming its successor**, whether or not it succeeded:

> **Next in the wired run:** `hatsu:<phase>` — <what it would do with this>.
> This run did not do it, and starting it is your call.

Where the successor differs by outcome, all applicable ones are named. Where the phase is terminal in
its own pipeline (`jutaisho`, `mugetsu`, `kagutsuchi`, `third-hand`), **it says that instead** — the
terminal statement discharges this clause exactly as a hand-back line does.

**Naming is not offering, and where a skill's own prose forbids even the naming, its prose wins.**
[`hatsu:murasaki`](../claude/skills/murasaki/SKILL.md) § 7 is the live case: it forbids naming
`hatsu:aka` or `hatsu:mukai` *as a next step it is waiting on*, on the ground that a composite ending
that way converts a human call into a nudge. Its hand-back therefore ends at the state of the branch
and names neither. **A rule restated in two places drifts in one of them**, so this document states
the general rule and the skill states its own stricter one.

**It never offers to run the successor.** The five phases that are the maintainer's alone —
`aka`, `mukai`, the merge, `kagutsuchi`, `mugetsu` — are never prompted for, from a standalone run
least of all, because a cold entry is exactly where a prompt reads as *the pipeline knows what it is
doing* (`ROSTER.md` § *Rulings of 2026-09-09*, 1).

---

## 7. The skills that carry a `## 0. Standalone entry`

**Twenty do**, and they fall into two groups. The split is the useful fact: a reader asking *what
will this derive if I type it cold* needs the first table, and a reader asking *does P1 apply* needs
both.

### 7a · Thirteen whose `## 0.` derives state (S1–S4)

| Skill | What it derives cold | What it asks for |
|---|---|---|
| [`breath`](../claude/skills/breath/SKILL.md) | S3 — the starting state, then **preserve → prove → place → restore** (P1b): the base proven on a tree holding none of the effort, the commits replayed onto it, the working copy restored. Runs at most once per session | only where it would **rewrite a commit** — the plan with its counts. Stash-and-restore is not asked, being reversible |
| [`kokusen`](../claude/skills/kokusen/SKILL.md) | S1 — the delta; the scoped lanes the delta touches | which lane, when the mapping is ambiguous; the flagged files, as always |
| [`tsukuyomi`](../claude/skills/tsukuyomi/SKILL.md) | S2 — `--lane` from the delta | the lane; **or** offers to author the missing focused tests |
| [`amaterasu`](../claude/skills/amaterasu/SKILL.md) | S2 — the target, from the declaration | which target, only where the declaration leaves it open |
| [`kotoamatsukami`](../claude/skills/kotoamatsukami/SKILL.md) | S1 — the delta, hence the impacted suites | nothing, where the declaration is complete |
| [`byakugan`](../claude/skills/byakugan/SKILL.md) | S1 — the touched set against the remote base | nothing |
| [`sharingan`](../claude/skills/sharingan/SKILL.md) | S2 — the PR from the branch, when `#N` is omitted | which PR, when the branch has none or several |
| [`hanten`](../claude/skills/hanten/SKILL.md) | S4 — routes a missing cycle ledger to `breath`, its only writer, and reports a lost ledger when it is still absent; S1 — the scope classification | nothing about the ledger (breath asks that once); the review scope, when the delta does not classify cleanly |
| [`rikugan`](../claude/skills/rikugan/SKILL.md) | S1 + S3 — turns and session context, read from git and the session | which variant, when it is not derivable |
| [`kagutsuchi`](../claude/skills/kagutsuchi/SKILL.md) | nothing new — the target is required grammar | nothing. **The call is the maintainer's** |
| [`mugetsu`](../claude/skills/mugetsu/SKILL.md) | nothing new — `G3` | nothing. **The go is the maintainer's** |
| [`third-hand`](../claude/skills/third-hand/SKILL.md) | S3 — "this sitting", from the branch and any open PR | the harvest pick, as it always did |
| [`murasaki`](../claude/skills/murasaki/SKILL.md) | S1 — the base, hence the catch-up; conflicts classified before one is touched | only a dirty working copy, before git state moves |


### 7b · Seven whose `## 0.` adds P1, orientation and expectations only

These inherit no caller state. Their `## 0.` says P1 still applies, states what their run does **not**
cover, and — for the two the contract used to mis-file — names why.

| Skill | What its `## 0.` says |
|---|---|
| [`gyo`](../claude/skills/gyo/SKILL.md) | Already total: lint reads the tree, not a delta. P1 only |
| [`ao`](../claude/skills/ao/SKILL.md) | Already total: `from <base>`, and § 3 reads the checkout. P1, and the base resolves against the **fetched** `origin/` ref |
| [`susanoo`](../claude/skills/susanoo/SKILL.md) | Already total, and § 1 says so — it runs inside `getsuga` **and** by name. P1, plus which commit and whether the tree was clean |
| [`aka`](../claude/skills/aka/SKILL.md) | **Always the maintainer's call**, never wired. P1, plus the unpushed/published boundary § 4 squashes on |
| [`jutaisho`](../claude/skills/jutaisho/SKILL.md) | Already total. P1, plus: a run that did nothing rings nothing |
| [`shibari`](../claude/skills/shibari/SKILL.md) | Already total, and both-ways by § 1. P1, plus the one cold precondition — the branch must already be pushed — and the rule that a missing evidence section says so rather than being filled |
| [`rasengan`](../claude/skills/rasengan/SKILL.md) | **Deliberately caller-bound** (§ 4): the request is the input. P1, plus *ask for the request, never infer it* |

**The skills with no `## 0.` at all** are the composites, the loop engines, and the three read-only
resolvers § 4 names — `pr-state`, `backlog-state`, `bankai-handbooks` — which reach P1 through
whatever called them.
