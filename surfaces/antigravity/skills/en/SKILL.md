---
name: en
description: Take one open pull request from the moment it opens to verified readiness at its human G2/G4 gate, under a mandatory acting-cycle cap — the landing report, fresh current-head observation, Sharingan remediation, catch-up when behind, and the bell only at Ready. Use when /mukai hands over its PR, or when the maintainer invokes /en on <CODE>#<N> for a PR that is already open. Pending CI or review keeps the run active; quiet polls spend no cycle. En never merges and never casts a review vote. After this run completes, the regular pipeline's next phase is /third-hand — En does not own it.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md`,
`docs/LAUNCH-MIGRATION.md` and `docs/STANDALONE-ENTRY.md` belong to the resolved **Hatsu plugin
root**, not the consuming repository. On an installed surface, use the absolute root printed by
`hatsu-warmup` to read those files (re-resolve through that skill if unavailable). Relative links
below identify source locations; a missing consumer `docs/` copy is not a missing policy and must not
trigger a duplicate filing. Never copy or invent a second policy in the target repository.



# En — the circle held around one PR until it is Ready

**Nature: Manipulator.** Everything en does is board-facing — driving, reporting, ringing, watching.
Kurapika says so when he runs it. **When a cycle sends him back into the change itself** — a
reviewer's finding that needs code — the mode for that fix is the change's own (Enhancer, Conjurer,
Transmuter), named out loud for that cycle and handed back afterwards.

> **Stay with this PR: report it, observe every current-head check and review, drive it to verified
> Ready, ring once at its human gate — and stop after at most N acting cycles.**

En is the last composite of the local plane and the only one that may need to **hold attention past
the moment the PR was opened**. [`/mukai`](../mukai/SKILL.md) ends by starting this handoff; from
there the PR and the still-active user turn belong to En until Sharingan proves it Ready, or a concrete
blocker/cap/terminal state/cancellation ends En's run. The merge itself is the maintainer's later act
and is outside En. **This run does not harvest.** When En has completed, the regular pipeline's next
phase is [`/third-hand`](../third-hand/SKILL.md) — a separate skill, started after this file's
protocol has returned, not as a step of En.

**This file composes. It does not re-specify.** Every step below is another skill's, named and
linked, and its procedure, its exit-code reactions, its refusals and its residue live there. If you
find a rule here that is really that skill's, it is in the wrong file — go read it where it is
authored, because a rule restated in two places drifts in one of them.

**What is genuinely en's own is the cap, the watch's shape, and the boundary at the end of the
session.** Those three are § 2, § 6 and § 7, and they are the only places this file asserts
anything. Third-Hand is not in that boundary.

---

## 1. Invocation

```
/en [on <CODE>#<N>]
```

Started by [`/mukai`](../mukai/SKILL.md) with no clause — the PR is the one step 8 just opened
— or by the maintainer, naming a PR that is already open:

```bash
nen parse en --grammar "on [<ref>]" --line "<the invocation, minus the /en prefix>"
```

Verified live at `v0.3.0` (`docs/ab/en.md` § 2.1): `on HA#41` → `ref: HA#41` at exit `0`, and a bare
`on` parses with the clause absent, also exit `0`. The clause is anchored behind a literal for the
reason [`/spiritual-message`](../spiritual-message/SKILL.md) § 1 records — a lone bracketed slot is refused at the
template.

> **The empty line is refused, and that is why a composite does not parse at all.** Verified live:
> `--line ""` exits `2` with *"the line must open with the literal 'on' — it is what introduces
> `<ref>`"*. **An anchored optional clause requires its anchor**; "no clause" and "empty line" are
> different inputs, and only the first parses. So `mukai` hands the PR over directly and **calls
> `nen parse en` not at all** — echoing a parse of a line nobody typed would be theatre, and
> feeding it `""` would produce a refusal that means nothing. The parse runs when, and only when,
> the maintainer typed a clause.

Resolve the code once, up front, and keep the slug for every later call — never re-derive it a
second way (`claude/agents/kurapika.md` § *How you work*):

```bash
nen repo resolve <CODE> --repo <path to the target repo's own checkout>
nen ref format --code <CODE> --kind PR --number <N>
```

**A closed or merged PR ends the run immediately** with what happened to it. There is nothing to
land.

**The phases this composite calls SKIP their own `## 0. Standalone entry` sections.** [`docs/STANDALONE-ENTRY.md`](../../../../docs/STANDALONE-ENTRY.md) is the
contract for a phase typed by hand into an arbitrary checkout; a phase reached from here inherits P1–P4
from this run — the warm-up, the orientation, the change set and every derived argument — and
re-deriving them would produce a second answer to a question this composite already settled. Each phase
says which composite is holding it instead.

## 2. The cap — grammar, not a default

**En acts.** Steps 2 and 4 drive; a cycle that finds a new review finding goes back into the change
and pushes a fix. That makes en the **mutating** half of the loop pair, and
[`/izanagi`](../izanagi/SKILL.md)'s whole discipline binds: *a loop that writes needs a bound a
loop that reads does not, and making the bound part of the grammar means it can never be defaulted,
inherited, or forgotten.*

| Key | File | Used for | Default when the key (or the file) is absent |
|---|---|---|---|
| `monitor.maxCycles` | `nen/workflow.json` | **the cap** — the count of *acting* cycles (§ 6) | `20` |
| `monitor.pollSeconds` | `nen/workflow.json` | the interval between observations, as `--interval-ms` | `300` (→ `--interval-ms 300000`) |
| `branch.base` | `nen/workflow.json` | what step 3 catches up from, and what "behind" means | `main` |
| `reports.dir` / `.sections` / `.retain` | `nen/workflow.json` | step 7's file — [`backlog-board`](../backlog-board/SKILL.md) § 3's keys | `Reports` / five variants / `final-only` |
| `notifications.rungs` / `.sound` | `nen/workflow.json` | step 6's rungs — [`/jutaisho`](../jutaisho/SKILL.md)'s keys | `["push","os","sound"]` / `Glass` |

**Before cycle 1, the cap is spelled out through the verb that refuses a missing one:**

```bash
nen parse izanagi "take <CODE>-PR-#<N> to its human gate until it is Ready up to <monitor.maxCycles>"
```

Verified live at `v0.3.0` (`docs/ab/en.md` § 2.2), both ways:

```
$ nen parse izanagi "take HA-PR-#41 to its human gate until it is Ready up to 20"
task: take HA-PR-#41 to its human gate
until: it is Ready
cap: 20
exit=0

$ nen parse izanagi "take HA-PR-#41 to its human gate until it is Ready"
nen: no 'up to <N>'. Izanagi is the MUTATING half of the loop pair and the cap is required grammar,
never defaulted or inferred -- an invocation without it is refused rather than run once 'to see'.
  try: take HA-PR-#41 to its human gate until it is Ready up to <N>
exit=2
```

**The value comes from `monitor.maxCycles`; the requirement comes from the grammar.** Those are two
different things and the distinction is the point: the file supplies a number, and the verb refuses
to run without one. **A repository whose `monitor` block is missing gets `20`, stated out loud** —
it does not get an unbounded watch, because "the file said nothing" is exactly the case an
inherited-and-forgotten default is dangerous in.

> ### RETIRED at nen `0.7`: counting the acting cycles by hand
>
> **Every acting cycle is CLAIMED before it acts, and the cap is enforced by the claim being
> refused** — [`izanagi`](../izanagi/SKILL.md) § 3's retirement, inherited whole:
>
> ```bash
> nen loop iterate --id en-<CODE>-<N> \
>   --line "take <CODE>-PR-#<N> to its human gate until it is Ready up to <monitor.maxCycles>" \
>   --repo <path>
> ```
>
> Exit `0` prints `iteration <n>/<cap>` and how many remain — the verb's own word is *iteration*, and
> en's cycle is what it is claiming; **exit `1` IS the cap** and ends the run at § 6's cap-out row,
> with the invocation named in nen's own refusal. The `--line` is the same string
> `nen parse izanagi` echoed above, restated on every claim, so **`monitor.maxCycles` cannot be
> quietly raised mid-run**: a claim carrying a different `N` is exit `2` naming both lines (verified
> live against exactly this shape — `up to 3` running, `up to 20` claimed —
> `docs/ab/izanagi.md` § *Retired at nen 0.7*).
>
> **The `--id` is the PULL REQUEST, not the session**, and that is a decision with a consequence
> worth stating: the ledger is `.nen/loop/en-<CODE>-<N>.json` under `--repo`, it outlives the
> session (§ 7), so **a re-invoked `/en` on the same PR resumes the same cap rather than
> starting again at cycle 1**. That is the honest reading of "twenty acting cycles to ready this PR" — a cap
> a session boundary reset would be a cap nobody has. When the readiness drive genuinely ends — Ready,
> closed, or handed to the maintainer at a gate — close the ledger with
> `nen loop iterate --id en-<CODE>-<N> --line "<same line>" --release "<why>"`; a loop at its cap can
> always still be released, and a fresh cap after that is a **new `--id`**, chosen deliberately and
> said out loud, never a re-typed line.

**The cap is a ceiling, not a target.** Reaching it is a failure to reach Ready and is reported as one:
what is still not true, and what the next cycle would have done. `izanagi` § 4's rule, unchanged.
**The reviewer-round policy is [`/sharingan`](../sharingan/SKILL.md) § 5's, written there in
full and carried here in four lines:**

- **One Copilot round is requested after [`/hanten`](../hanten/SKILL.md) settles, never before.**
- **Arrivals are remediated up to `nen/gates.json` → `round_policy.maxRounds`; an owed round inside
  the max is re-requested on the maintainer's behalf without asking** (ruling 2026-09-19,
  `nen/decisions.json` row `cap-reached`), then en keeps watching.
- **Never re-request after a push that changed nothing reviewable** — count commits ahead and the
  diff since the last reviewed head first (`git rev-list --count <reviewed-head>..HEAD`,
  `git diff --stat <reviewed-head>..HEAD`); zero reviewable change means no request.
- **Copilot auto-reviews every push, so the cap governs requests, not arrivals**; an arrival past the
  cap is still remediated and its threads settled.

Past the maximum the run ends at not-ready with the board. Neither is a G5. `nen/workflow.json` →
`monitor.maxCycles` is en's acting-cycle cap, a different number.

## 3. The run, in order

| # | Step | The skill that owns it | When |
|---|---|---|---|
| 1 | **landing report** | [`/spiritual-message`](../spiritual-message/SKILL.md) `as landing` | once, at the start — 00–07 plus **08 PR body** and **09 Readiness**. If this En was started by mukai in the same sitting with no newer human request, **00** still answers that mukai request |
| 2 | **drive** | [`/sharingan`](../sharingan/SKILL.md) | first blocking condition, threads, checks, the confirmation pass |
| 3 | **catch up** | [`/murasaki`](../murasaki/SKILL.md) | **only when the branch is behind `branch.base`** |
| 4 | **drive again** | [`/sharingan`](../sharingan/SKILL.md) | after step 3 moved the tree underneath it |
| 5 | **observe** | this file, § 6 | while CI or a reviewer round is pending; rebuild the current-head snapshot on every change, returning to steps 2–4 when action is needed |
| 6 | **the bell and gate handoff** | [`/jutaisho`](../jutaisho/SKILL.md) | **after verified Ready**, and only then |
| 7 | **the dated final report** | [`/backlog-board`](../backlog-board/SKILL.md) § 3, `--variant final` | after the bell; this is En's successful terminus |

**Four orderings are en's own assertions:**

- **3 before 4.** Driving a branch that is behind its base produces a readiness verdict against a
  tree that is about to change. Catch up first, then re-decide.
- **4 before 6.** The bell carries a verdict. Ringing before the second drive would ring on a
  reading the catch-up already invalidated.
- **5 before 6.** Pending is not Ready. Required CI and every reviewer round owed at the current head
  must settle, and every incoming finding must be disposed, before the bell or handoff exists.
- **6 before 7.** The dated final report records the gate event the bell announced; rendering it first
  would preserve a readiness handoff that had not happened yet.

**Step 3 is conditional and stays conditional.** A branch level with its base does not get a
catch-up "to be safe": `murasaki` would re-run the declared iteration checks for nothing, and on a
published branch it would push a commit that changes no content.

**En's equivalent of mukai steps 3–5 runs whenever the tree this watch is about to treat as
current has changed**, not only when step 3's catch-up moved a path. That includes a review fix
authored in steps 2/4 while the branch is still level with `branch.base` (step 3 then stays
skipped), a catch-up that returns without pushing, and a later murasaki that was meant to
publish but itself changed a path. Claim an acting cycle, then run
[`/kokusen`](../kokusen/SKILL.md), [`/kotoamatsukami`](../kotoamatsukami/SKILL.md)
and [`/byakugan`](../byakugan/SKILL.md), then call murasaki again. It may push only when
that catch-up is a no-op; if it changed any path, this paragraph repeats rather than handing a
stale tree to readiness. That is the same owner map [`/sharingan`](../sharingan/SKILL.md)
§ 5 already names when Kurapika authored the PR; En does not invent a fourth suite.

## 4. Readiness is never en's claim

Steps 2 and 4 are [`/sharingan`](../sharingan/SKILL.md)'s whole engine, not a substitute for
it, and **this file restates none of its protocol** — the first-blocking-condition order, the
channel decided by who authored the PR, the escalation ladder, the `round_policy.maxRounds` request
cap and the completed-round prerequisite, the thread hygiene run through `nen pr threads`, the
one-directional confirmation pass that may only veto. Read it there.

Two things en relies on and does not re-derive:

- **A PR is Ready iff `nen pr ready` says `ready` AND `nen pr body-check` says every requirement is
  satisfied**, both deterministic, neither re-derived by eye. `sharingan` § 4's rule, and
  [`/pr-state`](../pr-state/SKILL.md)'s before it: **a readiness claim is that verdict, quoted,
  or it is not made.**
- **`sharingan`'s escalation is a G5 and it ends this run's cycle**, not just its step. A PR that
  will not reach Ready is one of the plane's five genuine stops
  ([`docs/WORKFLOW.md`](../../../../docs/WORKFLOW.md) § 4), and en does not spend the rest of its cap
  re-driving past it.

**En never casts a review vote.** Kurapika runs on the maintainer's credentials, so GitHub would
record the vote as **theirs** — a governance vote on a PR they have not read. That holds even when
the finding is real and even when it is the only path visible. `sharingan` § 5's rule, binding here
because a long watch is where the temptation compounds.

## 5. The bell — once, at Ready

Step 6 is [`/jutaisho`](../jutaisho/SKILL.md) `at <G2|G4>`, with the gate
[`shibari`](../shibari/SKILL.md) derived and `sharingan` confirmed. It owes all four of that skill's
parts — the `nen stop` banner, the report link, lettered options with a ⭐ on the recommended decision — the report linked, never an option (Crazy Slots), and the
question through the surface's own native option picker.

`nen stop --template` emits the blank five-column shape the efforts table is filled into — verified
live at `v0.3.0`, exit `0` (`docs/ab/en.md` § 2.4):

```
| Effort  | Open issues & PRs | Status (gate)   | Thought flow | Session / lane |
| ------- | ----------------- | --------------- | ------------ | -------------- |
| <title> | <link>            | <status (gate)> | <one line>   | <session>      |
```

**The ask at Ready is a `MERGE` kind and takes no options** — the verdict says everything
(`sharingan` § 8). **En never proposes the merge as something it could do**; it says the PR is
Ready and which gate it stands at, and stops there.

**It rings at Ready exactly once for this run, and at no other time.** A quiet observation rings
nothing — a bell that rings every poll of a four-hour wait is a bell nobody hears.

## 6. The observation hold — `nen watch until` on `nen pr ready`, and what a cycle is

The condition is polled by the same read-only observation engine
[`/izanami`](../izanami/SKILL.md) uses. **The verb owns the wait between observations**; a caller
does not repeatedly invoke a one-iteration command and pretend `--interval-ms` paced those invocations.
Each refresh window has exactly two observations: the first establishes the window and the verb waits
`monitor.pollSeconds` before the second. The window then returns to Sharingan's full snapshot, because
`nen pr ready` alone cannot expose new review activity that leaves its verdict unchanged:

```bash
export GH_TOKEN=$(gh auth token)
nen watch until --command "nen pr ready <CODE>#<N> --repo <path> <identity flags>" \
  --max-iterations 2 --interval-ms <monitor.pollSeconds × 1000> # one paced refresh window
```

`<identity flags>` is selected by [`sharingan`](../sharingan/SKILL.md) § 4 for the target: omit it
when the target ships `nen/gates.json`; use `--gates "$hatsu_root/contracts/reference.gates.json"`
only for `<reference-repo>`; otherwise pass the target's hand-supplied `--reviewers` and explicit
`--approvers`. **Never point one repository's gates file at another repository.**

**`nen pr ready` classifies `[read-only]`** — verified live at `v0.3.0` (`docs/ab/en.md` § 2.3):
`nen parse izanami "nen pr ready HA#41 --repo /path --gates /abs/gates.json until it is ready"` →
`[read-only]`, exit `0`. So does the merge-state read,
`gh pr view <n> --repo <owner/name> --json state -q .state`. **And the merge itself does not**:
`nen watch until --command "gh pr merge 41"` is refused before the first observation, exit `2` —
*"'gh pr merge 41' classifies as mutating … izanami watches only"*. **The verb that polls this loop
structurally cannot be the verb that ends it**, which is a property worth having rather than a
limitation to route around.

> **`--max-iterations` is still not the cap.** Its own `--help` says so — *"a SAFETY bound, not
> izanagi's mandatory cap"* — and it bounds **watch observations**, not the count of acting cycles.
> **The cap is `nen loop iterate`'s from nen `0.7`** (§ 2): a cycle is claimed against
> `monitor.maxCycles` before it acts, and the claim is refused at the cap. Two different verbs, two
> different bounds, and neither substitutes for the other.

**What counts as a cycle — and it is what en CLAIMS, not what the watch observes.** A cycle is spent
when en **acts**: goes back to step 2, pushes a fix, re-requests a review. **An observation that
finds nothing changed is not a cycle and is never claimed**, and neither is the pre-check before the
first act (`izanagi`'s *iteration 0*). Otherwise a four-hour poll at five-minute intervals would
exhaust a cap of 20 in under two hours without a single thing having happened — and since nen `0.7`
that is a mistake with a ledger behind it rather than a miscount nobody can see: claim only where
en acts, and the `<n>/<cap>` the verb prints is the number the report carries.

**What the observation hold reacts to:**

| Observed | What en does |
|---|---|
| **a new review, comment or thread** | inspect and classify it first. If it requires remediation or a reviewer re-request, claim an acting cycle, then return to step 2; an approval or informational event that needs only a read spends no cycle. [`/sharingan`](../sharingan/SKILL.md) addresses every inline and summary finding through its own channel |
| **the branch fell behind, or the PR went `dirty`** | claim an acting cycle, then step 3 and step 4 — catch up, then re-decide. A conflicted PR gets *no checks at all*, which reads as "clean" rather than "broken" (`sharingan` § 5) |
| the PR becomes Ready | step 6 — bell and stop at the human gate |
| the PR merged before the gate handoff | end as a terminal external state, naming that readiness was not the run's observed terminus |
| the PR closed unmerged | the run ends, saying so — there is nothing to land, and reopening is the maintainer's call |
| nothing changed | **one line, or no line.** Not a status screenful; `nen watch until` already prints one line per observation |

**Four stops apply here**: the condition true (verified Ready); the **cap reached**, reported with what
is still not true; **a human gate**, which is never retried past; and an **impossible condition**, named
rather than waited on — a closed PR will not become Ready. `izanagi`'s generic three-no-op stop does
not apply to En: quiet observations claim no cycle, and three unchanged pending reads cannot terminate
the current-head readiness promise. Three consecutive **observation errors** still stop `nen watch until`
as an unread capability failure, exactly as the verb documents; that is not a pending-state success.

## 7. The session boundary — and the Illumi hand-off

**A watch lives in the session that started it.** `nen watch until` is a foreground process, the
observations are this conversation's, and there is no timer, no background pass, no deferral primitive and
no self-continuation anywhere in this plane — the same boundary [`/ren`](../ren/SKILL.md) § 4
records for its own loop and `docs/ab/ren.md` § 2.2 proves live.

**A model choosing to finish a response is not a session boundary and not a run outcome.** While the
task is alive, pending CI/review remains under observation. If the host or maintainer actually interrupts
the session, say the acting-cycle count reached, the last verdict, and that the run was interrupted; it is
**resumable by
re-invocation** — `/en on <CODE>#<N>` re-fetches everything and re-decides from live evidence
(`sharingan` § 9's rule). Notes worth keeping go in the run's transcript, never trusted over a
fetch.

**One thing does survive the session, deliberately: the cap.** `.nen/loop/en-<CODE>-<N>.json` is a
file, so a re-invocation on the same PR resumes the same count (§ 2) — the watch is per session, the
cap is per readiness drive. Say the resumed `<n>/<cap>` out loud on the first claim of a resumed run, so the
maintainer sees a budget being continued rather than one silently restarting.

> **A pre-Ready observation hold measured in hours is [`Illumi`](../../agents/illumi.md)'s, and from `v0.5.0` he has a
> definition to be raised as.** The roster's ruling of 2026-09-09 **partially closes `OPEN-1`** —
> *"Illumi is provisioned for `en`'s long watch, and only when one is needed"* — and
> [`claude/agents/illumi.md`](../../agents/illumi.md) **landed in this same wave**, because a
> provision that cannot be executed is a provision in name only (`docs/ROSTER.md` § *Rulings*, 5).
> On a surface with in-session subagents, step 5 is **handed over**, not abandoned: a subagent titled
> **`en · illumi · <model alias>`**, on the **fast** tier at effort `medium`, holding the same
> `monitor` policy this file reads. He never
> claims or spends En's acting-cycle cap: each quiet poll is an observation, not an Izanagi iteration.
> He records the five facts per observation, compares them, and **wakes Kurapika** — naming what changed and
> the act it needs. **He performs none of it**, and the readiness hand-off stays **G2/G4**.
>
> **What the hand-off buys is attention, not persistence, and the difference is stated rather than
> blurred.** A delegate is still raised *from* a session: the paragraph above still holds — no
> timer, no background pass, no deferral primitive, no self-continuation. What Illumi gives is a
> watcher whose entire job is the watch, at a tier that can afford to hold it for the hours an
> overnight CI queue or a reviewer in another timezone takes. **An observation hold that needs to survive the
> maintainer closing the session still has no mechanism anywhere in this plane** — that is named,
> reported as an interruption, and never simulated.
>
> **Codex has in-session subagents** (`spawn_agent`, skill-requested delegation; ChatGPT app, CLI,
> and IDE). En may hand this watch to `en · illumi` there the same way. The second-process
> `codex exec` worktree remains Hanten's isolation for a reviewer who must not share the author's
> tree; it is not this watch and is not a persistence mechanism. If the Codex task is interrupted,
> the resumable ledger is reported exactly as above.
>
> **And the hand-off widens nothing.** Illumi is provisioned for *this* watch and no other loop —
> not `backlog-loop`, not `futon`, not `senkei`; that half of `OPEN-1`, and the whole of Killua's
> row, stay **OPEN** and stay the maintainer's G4-class ruling to make. **What must never happen is
> en running unattended to fill a gap**: an unbounded, unwatched acting loop is precisely the shape
> the cap exists to make impossible, and improvising one would close a maintainer's OPEN question by
> attrition rather than by ruling.

## 8. The dated final report

After the deterministic Ready verdict and step 6's bell, render the **`final`** variant — a
**one-effort Rikugan with a cleared desk**, this effort's register, spend and legend —
through [`backlog-board`](../backlog-board/SKILL.md) § 3, which owns that render path (maintainer's
ruling, 2026-09-19). **There is no `spiritual-message as final` any more**; hand over and say so.

```
<reports.dir>/<YYYY-MM-DD>-<effort>.html
```

That path is `backlog-board` § 3's and `reports.retain: final-only`'s, not en's invention: turn and
landing renders live at their Artifact address (or the transient `current.html` on a surface with
none), and only this one gets a dated file. **`<reports.dir>` is git-ignored**, and neither skill
writes anywhere else in the tree.

**Then the run ends at the gate.** Say the object notation, current head SHA, quoted readiness verdict,
acting-cycle count spent out of the cap, and final report path. The human merge or vote remains outside
the run. If the PR merged externally before this hand-off, report that terminal state without rewriting it
as an observed Ready success.

**Do not start [`/third-hand`](../third-hand/SKILL.md) from this file.** When this run has
completed, the regular pipeline's next phase is Third-Hand, started by the caller after En has
returned. Harvesting is that phase's, not En's.

## Residue

1. **The composition itself has no verb, and is not expected to get one.** nen owns operations, not
   conversations (`docs/ab/ren.md` § 2.2, verified live). **En adds no residue of its own** — every
   deterministic step inside a cycle is a verb or a named residue *in the skill that owns it*: the
   absent `nen report data` / `nen report render` (step 1 and the readiness report, named in
   [`spiritual-message`](../spiritual-message/SKILL.md)), `nen pr ready` / `nen pr body-check` / `nen pr staleness` and
   the two verbs `sharingan` refuses to call for a verdict (steps 2 and 4), `nen pr cascade-main`
   and its missing `--no-push` (step 3, named in [`ao`](../ao/SKILL.md)), `nen stop` plus the
   `osascript`/`afplay` fallback and the `.nen/last-stop.json` marker (step 6, named in
   [`jutaisho`](../jutaisho/SKILL.md)).
2. **RETIRED at nen `0.7`: counting cycles against the cap.** `nen loop iterate --id en-<CODE>-<N>
   --line "<the invocation>"` claims each acting cycle and REFUSES the claim at
   `monitor.maxCycles`, exit `1` (§ 2, § 6; `izanagi` § 3's retirement, verified live in
   `docs/ab/izanagi.md` § *Retired at nen 0.7*). `nen parse izanagi` still refuses a missing `N`
   once at parse time and `nen watch until --max-iterations` still bounds one observation — three
   different jobs, and only the middle one used to be this skill's. **What stays en's is DECIDING
   which cycles to claim** (§ 6: en acts, so en claims; an observation that changed nothing does
   not), and that is judgment rather than residue.
3. **RETIRED at nen `0.5`: `nen/workflow.json` is validated.** `nen schema check --repo <path>` carries
   an `ok  nen/workflow.json` row at the pinned build (verified live, `docs/ab/en.md` § *Retired at
   nen 0.5*), and a malformed `monitor` block is a FAIL by pointer. § 2's keys are still read here;
   reading a file is not residue.
4. **A watch that survives the session has no mechanism at all** (§ 7) — not a missing verb: no
   timer, no background pass, no deferral primitive anywhere in this plane. **The long watch itself
   is no longer a gap** — [`illumi.md`](../../agents/illumi.md) landed at `v0.5.0` and step 5 hands
   to `en · illumi`, which buys attention for hours; **persistence past the session is what remains
   unavailable *in this plane*, and it is named rather than improvised around. **In `zheref/hatsu`
   only**, one half of it is now supplied from OUTSIDE the plane:
   `.github/workflows/pr-readiness.yml` re-runs `nen pr ready` on every event that can change the
   answer and publishes the verdict as the `readiness` check run (that file's header is the
   authority; no consumer repository carries it). It is **not** a watch and grants En nothing — it
   never merges, votes, comments or wakes, and En still claims and caps its own cycles exactly as
   above. **Be precise about which half it supplies:** the verdict now PERSISTS on the pull request
   and can be read without a session. Nobody is NOTIFIED — the check is always `success`, so nothing
   is pushed to the maintainer. **Persistence was the half a session could never supply; being told
   is still unsupplied, and stays named here rather than claimed.** The rest of Illumi's row
   (`backlog-loop`, `futon`, `senkei`) stays `OPEN-1` and unreachable from here.

## Authority

- **Permitted:** everything the composed skills are each permitted, under their own authority,
  one at a time, in § 3's order — and **per cycle, resolved fresh**. `izanagi` § 2's rule:
  authority never accumulates across iterations, and a run-scoped delegation granted inside a step
  expires with that step.
- **Not permitted:** **any merge**; any gate label; any review vote — `request_changes` above all;
  any force-push; any `--no-verify`; any tag, release or deploy. A landing that would need one of
  those is reported and the run stops.
- **En grants no delegation of its own**, and its own long run does not become standing authority
  for the acts inside it. Anything a composed skill would have asked for on its own, it still asks
  for.
- **Log every mutating action** — object, action, cycle number, time — and report the whole log when
  the run ends (`izanagi` § 2). An unlogged write inside a loop is the one thing nobody can
  reconstruct afterwards.

## Hard limits

- **Never merges.** Not on `nen pr staleness`'s own `mergePermitted` field, not at the cap, not
  because the PR has been Ready for hours. G2 and G4 are the maintainer's (`CON-5`/`CON-7`), and
  this is the skill standing closest to that gate for the longest, which is exactly why the limit is
  first.
- **Never casts a review vote, never self-reviews, never impersonates an automated reviewer** (§ 4).
- **Never runs without a cap** — the value from `monitor.maxCycles`, the requirement from the
  grammar (§ 2). Never raises its own cap mid-run and never restarts itself to get more cycles.
- **Never runs unattended, and never promises persistence it was not given** (§ 7). A watch measured
  in hours is handed to `en · illumi`; if the session is actually interrupted, report the interruption
  and resumable live state. Do not misname interruption as success or cap exhaustion.
- **Never counts an observation that found nothing as a cycle**, and never fabricates one to
  manufacture a cap-out (§ 6).
- **Never rings outside Ready** (§ 5), and never rings twice for the same transition.
- **Never claims readiness by eye** — `nen pr ready` + `nen pr body-check`, quoted, or it is not
  claimed (§ 4).
- **Never renders the final report while required CI or the owed current-head review round is pending**,
  and never gives a turn render a kept file (§ 8).
- **Never starts Third-Hand from inside this run.** Harvesting is the next phase, after En has completed.
- **Never retries past a human gate**, and never spends the rest of the cap re-driving past a
  `sharingan` escalation (§ 4).
- **Never restates another skill's protocol.** If en and a composed skill disagree, the composed
  skill is right and this file is the bug.
