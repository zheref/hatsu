---
name: mukai
description: Take a pushed branch through catch-up, review, impacted tests, coverage and evidence to one open PR, render its landing report, then end by immediately handing the PR to En. En owns the capped current-head readiness loop through required CI and review; the invoking turn remains active across that composition. Mukai owns kotoamatsukami's unit/UI/integration tests and byakugan's coverage capture and gating. Gyo is linting on the Ren loop. Mukai gains no squash, first-publish, merge, or review-vote authority from nested phases.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

# Mukai — the branch reaches its pull-request gate

**No fixed mode.** Mukai is a composed run: the mode is whichever the *change* is — **Enhancer** for
product code, **Conjurer** for canon, **Transmuter** for machinery — held for the run and named in
the reply, with **Manipulator** named alongside it from step 6 on — the first step that touches
the remote. Name the mode in play, say when it switches and why, and never blend two under one header
(`claude/agents/kurapika.md`).

> **The work is done and it is on the remote. Prove it, review it, show it, put it up, then hand the
> open PR to En and end. En holds the current-head readiness circle from there.**

Mukai is the **second human call** in the local plane. [`/aka`](../aka/SKILL.md) is the first —
it put the branch on the remote — and this one asks other people to look at it. **The two are
deliberately separate**: a push and a pull request are two decisions, and folding them makes one of
them unaskable.

**This file composes. It does not re-specify.** Every step below is another skill's, named and
linked, and its procedure, its exit-code reactions, its refusals and its residue live there. If you
find a rule here that is really that skill's, it is in the wrong file — go read it where it is
authored, because a rule restated in two places drifts in one of them.

---

## 1. Invocation — and what the call authorizes

```
/mukai
```

**No arguments, so there is nothing for `nen parse` to own** — the branch is the input, the base
comes from `nen/workflow.json`, and every step reads its own configuration. Same reasoning
[`/aka`](../aka/SKILL.md) § 1 states for its own bare verb: inventing an optional clause so
that a parse could be echoed would be ceremony, not a grammar.

**The call is the maintainer's, in their own words or by name**, and it carries three consequences:

- **No agent ever prompts for it.** Not a report, not a bell, not a composite offering it as a next
  step, not a lettered option in a stop. A report may say *the branch is ready to go up*; it may
  not say *shall I open the PR?* An agent that asks for permission it was told to wait for has
  converted a human call into a nudge.
- **This call is the authorization for the pull request itself**, which is why no step below asks
  again before opening it ([`/shibari`](../shibari/SKILL.md) § 1).
- **It is also the authorization for the evidence mechanism's public step.** On a stack whose
  `project.evidence.mechanism` is `public-mirror`, the branch's re-recorded snapshots have to reach
  a public host before the body can embed them — on **KroApple**, the repository's own
  `ci_scripts/pr_screenshots.sh -y`. A maintainer who typed `mukai` asked for a pull request **with
  its evidence attached**, on the mechanism their own repository declares; asking again per scene
  would turn one authorization into a queue of them. **What the call does not cover is anything the
  stack has not declared** — an unregistered mirror, an unnamed host, an image that is not one of
  the branch's own re-recorded artifacts. Step 6 states what it published.

**One call, one Mukai run, one PR, then one immediate En run in the same user turn.** A `yes` for this
pull request is not authority for the next one. Say when Mukai starts, say when it ends at the En
handoff, and do not end the user turn while En still owns an ordinary pending state.

## 2. The run, in order

| # | Step | The skill that owns it | Why it is here |
|---|---|---|---|
| 1 | **catch up** | [`/murasaki`](../murasaki/SKILL.md) | the base underneath the branch; iteration checks only. A changed tree invalidates later evidence; this step does not run regression |
| 2 | **adversarial review** | [`/hanten`](../hanten/SKILL.md) | one reviewer subagent per scope, findings in the fixed shape; Kurapika fixes or pushes back with a reason |
| 3 | **checkpoint review mutations** | [`/kokusen`](../kokusen/SKILL.md), then [`/ao`](../ao/SKILL.md) if the tree still needs catch-up | focused tests and a local commit for review/snapshot edits; no project-wide suite |
| 4 | **impacted tests** | [`/kotoamatsukami`](../kotoamatsukami/SKILL.md) | the sole project-wide test run: unit, UI and integration suites this change can affect. No coverage capture |
| 5 | **the coverage bar** | [`/byakugan`](../byakugan/SKILL.md) | capture and measure independently of those suites; if byakugan adds tests, repeat steps 3–5 |
| 6 | **publish the proved tree** | [`/murasaki`](../murasaki/SKILL.md) | final catch-up check; if it changes any tree path, invalidate regression and coverage and return to steps 3–5; only an unchanged, fully proved tree is pushed |
| 7 | **collect the evidence** | [`/kotoamatsukami`](../kotoamatsukami/SKILL.md)'s existing artifacts | build the `UZF-26` table without rerunning UI regression |
| 8 | **compose and open** | [`/shibari`](../shibari/SKILL.md) | the body, checks, evidence, reviewers, and PR from the last pushed commit |
| 9 | **the landing report** | [`/rikugan`](../rikugan/SKILL.md) `as landing` | rendered after step 8 because the PR body and readiness result are its inputs; **00** is this mukai request |
| → | **hand over and end Mukai** | [`/en`](../en/SKILL.md) | Mukai immediately starts En on the open PR and ends; En owns the capped drive to verified Ready at G2/G4 while the invoking user turn remains active |

**The order is load-bearing in eight places, and those eight are the only ones mukai asserts:**

- **1 before 2.** A review of a branch that is behind its base is a review of a diff nobody will
  merge. Reviewers cost real tokens and real attention; spending them on a stale tree is spending
  them twice.
- **2 before 3.** Review fixes need a focused checkpoint before anybody spends the slow suite on
  them.
- **3 before 4.** Kotoamatsukami runs tests on the checkpointed tree. Aka did not run those
  suites, so step 4 is the first project-wide test run of the effort even when review changed
  nothing.
- **4 before 5.** Byakugan captures and measures independently of the suites. It never executes
  tests; kotoamatsukami already did.
- **5 before 6.** Coverage must match the tree being pushed. Step 6 checks the base once more. If
  catch-up changes the tree, it pushes nothing and returns to steps 3–5; tests alone cannot
  bless a tree whose coverage was measured before the merge.
- **6 before 7.** Evidence is selected from artifacts for the pushed tree.
- **7 before 8.** The PR body's evidence table needs its rows.
- **8 before 9.** [`rikugan`](../rikugan/SKILL.md) § 5's `landing` variant is 00–07 **plus 08 PR
  body and 09 Readiness**, and both are step 8's outputs. **The landing report is
  rendered once, here, after the PR exists** — not rendered early and re-rendered later.
  Rikugan fills **00 This last turn** from this mukai request: corrections (who asked, why,
  handled or pushed back), local checks that brought work back, and any half-run stop with
  the policy and the autonomy fix. Architecture delta is the structural diagram, not the
  file list.

**Step 3 is the step a review makes necessary, and step 4 is not optional even when review
changed nothing.** Aka no longer proves the suites. Steps 2–5 may edit:
[`hanten`](../hanten/SKILL.md) § 6 has Kurapika settle each finding in the working copy, and
[`byakugan`](../byakugan/SKILL.md) adds tests to reach the bar, and those tests then re-run through
[`kotoamatsukami`](../kotoamatsukami/SKILL.md). None of those skills may commit, and none
may push — hanten's Authority bars *"push, commit, PR, label, merge, tag, deploy"* outright.
Step 6 is the only post-review publish. Without it the run arrives at step 8 with `HEAD` ahead of
`origin/<branch>`, and [`shibari`](../shibari/SKILL.md) § 4 **refuses to
open a PR** in exactly that state and hard-limits *"never pushes to satisfy its own precondition"* —
a PR opened from the last pushed commit would otherwise describe a tree that does not exist on the
remote, evidence and all. If review changed nothing, step 4 still runs: there is no aka capture
to reuse.

**Which skill pushes is the branch's state, not a preference.** The branch reached mukai through
[`/aka`](../aka/SKILL.md), so it is published, and the push half of
[`murasaki`](../murasaki/SKILL.md) — step 3 there, `git push origin HEAD`, no `-u`, no squash, no
force — is the whole of it. Aka is not called again. A branch found unpublished is a G5 ownership
error for mukai. **The commit is
[`kokusen`](../kokusen/SKILL.md)'s**, with its
`nen stage triage` pass and its trailer rule, and neither skill's protocol is restated here.

**Step 6 is where the base is checked a final time.** `origin/<branch.base>` moves while the
review runs — three times in one recorded run (`docs/ab/mukai.md`) — and a branch that was level at
step 1 need not be level now. Murasaki must return without pushing if this catch-up changes the tree:
steps 3–5 regenerate focused tests, impacted tests and coverage first. It may push only when
its catch-up is a no-op.

**Step 7 is conditional.** Where the repository declares no `ui-test` verb, or selection skipped
it with proof,
[`/kotoamatsukami`](../kotoamatsukami/SKILL.md) says so and step 7 has no rows
to lay out — which is the **logic-only** case `UZF-26` exempts, stated in the body. That is an
answer, not a gap, and it is not converted into one by adding hand-staged captures.

**A step that stops ends the run where it stopped.** Coverage under the minimum, hanten with an unsettled
finding, murasaki's `ao` on a semantic conflict, kotoamatsukami on a red required suite — each is
that skill's own G5, rendered by
[`/jutaisho`](../jutaisho/SKILL.md) § 4, and mukai neither retries past it nor smooths it over.
**No PR is opened by a run that stopped**, and the answer to the stop resumes the run at the step
that stopped, not at step 1.

## 3. What the run produces, and what it never produces

**Produces:** a branch level with its base and pushed; a reviewed, tested, covered change; a landing
report; **one** pull request with its body, its evidence and its reviewers; and an immediate handoff
that starts `en`/`sharingan`. **That handoff is Mukai's successful terminus.** En's separate run ends
only when the pull request is verified Ready at its derived human gate or reaches one of En's governed
non-success termini.

**Never produces:** a merge, a gate label, a review vote, a tag, a release, a deploy. Opening the PR is
followed by the landing report and immediate En handoff; **that completed handoff ends Mukai**. It does
not end the invoking user turn or make the PR Ready. `en` and
[`/sharingan`](../sharingan/SKILL.md) take ownership from there, and En's successful terminus is
their current-head verdict: `nen pr ready` says `ready`, `nen pr body-check` passes, the adversarial
confirmation pass agrees, and the gate is handed to the maintainer. A required check still pending,
an owed reviewer round, or an assistant choosing to end its turn leaves **En** in progress.

Pending remote work is held as observation through [`/en`](../en/SKILL.md), not returned to the
maintainer as *"CI remains pending"*. After every push, En observes the new head until all required CI
and every reviewer round the deterministic gate says is owed at that head have settled. Every inline and
summary finding is then fixed or rebutted with evidence, replied to in its proper channel, and resolved
where a thread exists before readiness is tested again. The only non-ready termini are the concrete ones
En owns: a genuine evidenced blocker, the acting-cycle cap, a closed/drafted PR that makes the condition
impossible, or explicit cancellation/interruption. Elapsed time and quiet observations are none of them.

**It opens exactly one PR.** A branch that turns out to carry two unrelated efforts is reported and
handed to [`/jujisho`](../jujisho/SKILL.md), which is the split-shaped verb — never filed as
one PR carrying two concerns because the run had already started.

## 4. The stops — four are possible, and all four are somebody else's

| Stop | Owned by | Rendered as |
|---|---|---|
| a semantic conflict pulling the base in | [`/ao`](../ao/SKILL.md), inside step 1 | G5, `jutaisho` § 4 |
| an unsettled adversarial finding | [`/hanten`](../hanten/SKILL.md), step 2 | G5, same |
| red required tests | [`/kotoamatsukami`](../kotoamatsukami/SKILL.md), step 4 | G5, same |
| touched-file coverage under `coverage.minimum` | [`/byakugan`](../byakugan/SKILL.md), step 5 | G5, same |

**Mukai adds no stop of its own**, and it never converts one of these into a warning. In particular
**step 5's bar is never lowered to clear it** — that is byakugan's rule and the one move it will not
make; a repository that cannot honestly reach `minimum` is a G5, not a smaller number.

**A stop is all four of `jutaisho` § 4's parts or it is not a stop**: the `nen stop` banner, the
report link, lettered options with a ⭐ on the report, and the question through the surface's own
native option picker (`AskUserQuestion` on Claude Code). A stop typed as prose in the middle of a
reply is one the maintainer can scroll past, and one they scroll past is one that did not happen.

## 5. The parameters — read by the steps, named here

Mukai reads **no** `nen/workflow.json` key for itself. It names which step owns which, so a
maintainer tuning the file knows where the effect lands:

| Key | File | The step it configures |
|---|---|---|
| `branch.base` | `nen/workflow.json` | steps 1 and 6 catch-up; step 8's PR base |
| `iteration.checks`, `iteration.lane` | `nen/workflow.json` | step 1's proof of the merged tree, through [`/murasaki`](../murasaki/SKILL.md) § 5 |
| `tests.required`, `tests.extra` | `nen/workflow.json` | step 4 — [`/kotoamatsukami`](../kotoamatsukami/SKILL.md) |
| `coverage.minimum` / `.recommended` / `.ideal` / `.scope` | `nen/workflow.json` | step 5 — [`/byakugan`](../byakugan/SKILL.md) |
| `models.*`, `models.roles.reviewer` | `nen/workflow.json` | step 2's reviewer tier — [`/hanten`](../hanten/SKILL.md) |
| `commits.allowedAttributionTrailers` / `.forbiddenTrailers` | `nen/workflow.json` | step 3's message — [`/kokusen`](../kokusen/SKILL.md) |
| `reports.dir`, `.template`, `.captures`, `.retain` | `nen/workflow.json` | step 9 — [`/rikugan`](../rikugan/SKILL.md) `as landing` |
| `project.evidence.globs` / `.scene` / `.mechanism` | `nen/contract.json` | steps 7 and 8 — the table's rows and how they reach the body |
| `project.verbs` (`test`, `ui-test`, `coverage`, `build`) | `nen/contract.json` | whatever the step's own verb spawns |

**Each step states its own default when a key is absent.** Mukai neither supplies a default nor
overrides one — a composite that quietly substituted a value would make the file a lie for the step
that owns it.

> **`nen schema check` VALIDATES `nen/workflow.json` at the pinned build** — verified live
> (`docs/ab/mukai.md` § *Retired at nen 0.5*): six rows, the sixth the workflow file, `ok`. A
> malformed key is a FAIL by pointer, so no step here checks the shape by eye; every step still reads
> the values and states the defaults it fell back to.

## 6. Reporting the run

**One line per step as it completes, then the handover.** Which step, what it found, and — for step
2 — the reviewer subagents by their full title (`hanten · <persona> · <model alias>`) with the
finding count and how each was disposed. **Step 6's line names the commits it pushed and the ref it
pushed** (`<old>..<new>`), or says the tree was already clean and level, so a reader can tell a run
that published a review's fixes from one that had nothing to publish.

Then the handover line, which is [`/shibari`](../shibari/SKILL.md) § 10's and is not restated
here: the object notation, the base, the derived gate as a **forecast**, the three body checks, the
evidence mechanism used and what it published, the reviewers requested, and that `en` has the PR.
That is a progress line, not Mukai's closing line. The closing line comes only from En's verified gate
handoff or one of its evidenced non-ready termini.

**Not a prose recap of the landing report** — step 8 exists to replace exactly that, and duplicating
it is how the page stops being read.

## Residue

**One entry, and it is a boundary rather than a gap:**

1. **The composition itself has no verb, and is not expected to get one.** nen owns operations, not
   conversations — the finding [`/ren`](../ren/SKILL.md) § 4 records and `docs/ab/ren.md`
   § 2.2 proves live: `nen watch until` spawns **one** program with no shell and refuses a mutating
   one, and `nen loop slots` counts concurrency across efforts. A mukai run is six skills, many
   programs, most of them mutating, and four of them able to stop and ask the maintainer something.
   **Mukai adds no residue of its own**, and every deterministic step inside the run is a verb or a
   named residue *in the skill that owns it* — `nen pr cascade-main --no-push` and the `git push` that
   is still residue (steps 1 and 6, named in [`ao`](../ao/SKILL.md)), the Agent tool (step 2),
   `nen shu test` and `nen shu test-report` (step 4, named in [`kotoamatsukami`](../kotoamatsukami/SKILL.md)), `nen shu coverage --touched --base` (step 5, named in [`byakugan`](../byakugan/SKILL.md)),
   `nen commit format --repo` gated on its own exit code and `git commit --file`, still residue
   (step 3, named in [`kokusen`](../kokusen/SKILL.md)), `nen shu evidence` (step 7), `gh pr create`,
   still residue, and `nen pr edit-body` (step 8, named in [`shibari`](../shibari/SKILL.md)), and
   `nen report data` / `nen report render` (step 9, named in [`rikugan`](../rikugan/SKILL.md)).

   > **RETIRED at nen `0.5`.** Six of the verbs this list used to call *missing* are in the pinned
   > binary — `pr cascade-main --no-push`, `shu test-report`, `shu coverage --touched`,
   > `shu evidence`, `pr edit-body`, and both `report` verbs — each verified live before the entry
   > was rewritten, with the exit codes in the owning skill's `docs/ab/` file under *Retired at nen
   > 0.5*. What is still residue in this run is `git push`, `git commit --file` and `gh pr create`,
   > all three named where they are run.

## Authority

- **Permitted, and only on the maintainer's own call:** everything the composed skills are each
  permitted, under their own authority, one at a time, in § 2's order — including step 6's update
  push, step 8's single `gh pr create` and, where the stack declares `public-mirror`, its own
  evidence-publish step (§ 1).
- **Not permitted:** anything none of them may do — and specifically **no merge, no gate label, no
  review vote, no tag, no release, no deploy, no force-push**, whatever the run turns up. A finding
  that would need one of those is reported and the run stops.
- **Mukai grants no delegation of its own.** Composing a skill does not widen what that skill may
  do; each step runs under exactly the authority its own file gives it, and a run-scoped delegation
  granted inside a step **expires with that step**, not with the run. Step 2's reviewer subagents
  hold [`hanten`](../hanten/SKILL.md)'s own limits — they never edit non-test source and never vote
  — and being spawned from inside mukai does not lend them more.

## Hard limits

- **Never runs unasked**, and **never prompts for itself** — no agent, skill, report or stop option
  proposes `/mukai` (§ 1).
- **Never merges**, never applies a gate label, never casts a review vote (§ 3).
- **Never opens more than one pull request**, and never one carrying two unrelated efforts (§ 3).
- **Never opens a PR from a run that stopped** at any of § 4's four G5s.
- **Never lowers the coverage bar to clear step 5**, and never re-reads a stale coverage artifact as
  this run's number.
- **Never skips step 2 because the change looks small.** The review is where a small change that is
  not small gets found; skipping it on a size judgment is the judgment being made by the thing
  being judged.
- **Never converts step 7's absent `ui-test` declaration into hand-staged captures** — the
  logic-only exemption is stated, not filled in.
- **Never claims readiness itself or by eye.** Mukai ends after it starts [`/en`](../en/SKILL.md)
  with the open PR and landing report. En obtains the `nen pr ready` + `nen pr body-check` +
  confirmation verdict and owns the G2/G4 handoff.
- **Never restates another skill's protocol.** If mukai and a composed skill disagree, the composed
  skill is right and this file is the bug.
- **Never lets Mukai's own completion end the user turn.** The handoff starts `en` immediately; from
  that point En, not Mukai, owns the still-active readiness work. If the host actually interrupts the
  session, report En as interrupted and resumable from fresh state; never rewrite an unfinished En wait
  as successful readiness (`en` §§ 6–7).
