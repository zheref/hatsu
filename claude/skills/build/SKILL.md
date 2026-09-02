---
name: build
description: Take one issue from wherever it sits to a delivery PR standing ready at its human gate. Use when the maintainer invokes hatsu:build <CODE>#<issue>, or asks to build, start, release or deliver an issue. Kurapika confirms the mode, builds the issue himself — Hatsu holds no CI plane to route it to — and drives the resulting PR to CON-32 readiness, escalating a stuck effort to G5. Never merges, never applies a G1 mode label.
---

# Build — from an issue to a PR standing at the gate

**Nature: Transmuter** for a machinery-shaped issue, **Conjurer** for a canon/governance one,
occasionally **Enhancer** where the issue is genuinely product code. Kurapika names the mode at
§ 3 and says so out loud when it switches mid-run.

The contract:

> **Give me an issue; I give you back a PR that is `CON-32`-Ready at its human gate — or a G5
> stop that says exactly why it could not get there.**

`build` is the issue-shaped verb. Its PR-shaped half is [`drive`](../drive/SKILL.md) —
**everything after the first PR appears is that skill's engine**: the readiness call
(`nen pr ready` — see [`pr-state`](../pr-state/SKILL.md)), the unblocking channels and the
escalation ladder are inherited from it, not restated here. Where the two disagree, `drive` wins
on PR mechanics and this skill wins on what happens before a PR exists.

> **Declared process change — read this before § 5.** The old skill released a routed issue to a
> CI builder (`bankai:stage/building` woke Kisuke, Sasuke, Naruto or Yamamoto's workflow) and then
> spent a whole section (§ 5) verifying the wake actually fired. **Hatsu has no CI plane at all** —
> no App, no workflow, no bot identity (`claude/agents/kurapika.md` header) — and Gon, the one
> agent whose *proposed* delegation grammar would let a mission cross a gate on its own, is
> **ratified as an agent but unratified for that grammar** (`docs/ROSTER.md` § Gon,
> `docs/delegation-grammar-DRAFT.md`): "**Gon does the work, takes it to the gate, and stops
> there**," same as every agent by default. So there is nothing left to route a released issue
> *to* — this port follows the precedent [`bankai-handbooks`](../bankai-handbooks/SKILL.md) set for
> the identical structural gap under `CON-37` (§ 4): **where the old skill would wake
> a CI builder, this one states the local-only reality outright.** Kurapika builds the issue
> himself, in this same session, in the mode § 3 confirms — or, where the work is something a
> local session structurally cannot do at all, this run stops at **G5** and says so, rather than
> pretending a wake occurred. This is a declared change from the retired skill's behaviour, not a
> silent one — per the ratified migration plan and `zheref/akatsuki-ai#1`.

---

## 1. Invocation

```
hatsu:build <product|repo_code>#<issue_number>
```

Split it mechanically rather than by hand:

```bash
nen parse build --grammar "<code>#<n>" --line "<the raw invocation>"
```

Verified live: `nen parse build --grammar "<code>#<n>" --line "BC#918"` returns `code: BC`,
`n: 918` (and the identical structured `slots[]` under `--json`); an unparseable line — no `#`, or
no trailing number — is refused with a corrected line ready to paste (`docs/ab/build.md` § 2.1).
This is a genuinely usable two-slot grammar, unlike `backlog-state`'s single-slot template (see
that port's own A/B doc § 3) — no bracket-swallowing bug was found here.

Resolve `<code>` against the registry, never from memory:

```bash
nen repo resolve <CODE> --repo <bankai-core checkout>
```

case-insensitive (`bc` and `BC` both resolve to `zheref/bankai-core` — `docs/ab/build.md` § 2.2);
**an unresolved code is an error and never a guess.**

**If `#<N>` is a PR, hand straight to [`hatsu:drive <CODE>#<N>`](../drive/SKILL.md) and say so.** `nen issue chain-position`/`nen issue terminus` do **not** make this check
for you — verified live, `docs/ab/build.md` § 2.3: pointed at a real PR number
(`zheref/bankai-core#925`), `chain-position` answers `routable` and `terminus` answers `own-pr` as
if it were an ordinary issue, with no error and no hint that the number names a PR. **This is a
finding against the binary, filed, not routed around silently** (§ 10) — the issue-vs-PR check
stays a plain read this skill performs first: `gh api repos/<owner>/<repo>/issues/<N> --jq
'.pull_request'` (a populated object means it is a PR; empty output means it is an issue —
`gh issue view <N> --json pull_request` is **not** a substitute: there is no such JSON field on
that command and it errors on every object — verified live, `docs/ab/build.md` § 2.3), before
either verb is ever called on `<N>`.

**Say the run has started.** A named skill run holds a bounded `CON-25` delegation (§ 6), and a
delegation nobody announced is a delegation nobody can end.

## 2. Read the issue before touching it — where is it on the chain?

```bash
nen issue chain-position --target <owner/name> --issue <N> --repo <bankai-core checkout> \
  --chain-labels "idea=bankai:stage/idea,researched=bankai:stage/researched,\
approved-team=bankai:stage/ready-for-bankai,approved-direct=bankai:stage/ready-for-shikai,\
building=bankai:stage/building,in-review=bankai:stage/in-review,epic=bankai:epic"
```

`--chain-labels` is caller data — bankai-core's own label names for each chain role, read from its
`schemas/labels.json`, never guessed. Its taxonomy carries **no `chore` label** at all (verified:
`gh label list` names none) — omit the `chore=` entry; that is this repository's own fact, not a
gap in the verb. **Supply every role your repo actually uses.** Verified live, an incomplete map is
refused outright rather than half-answered: with no `--chain-labels` at all, a real `in-review`
issue (`zheref/bankai-core#918`) comes back `undecidable: role(s) building, in-review, idea, epic
were never mapped … a run that reads a building issue as routable releases it twice` (exit `1`) —
and an unknown role name in the map (`bogus=foo`) is refused outright at exit `2` (`docs/ab/build.md`
§ 2.7). Never guess past either refusal.

This one call replaces the old skill's "decide from labels, body and linked objects, never the
title" prose. Its seven reported states map onto the same first moves, verified live against real
objects (`docs/ab/build.md` §§ 2.4, 2.4a, 2.5, 2.7, 2.7a):

| `chain-position` reports | The issue is… | First move |
|---|---|---|
| `closed` | closed | **The run ends** with what closed it and which PR delivered it (verified live, `zheref/bankai-core#733` — a closed epic — reports exactly this). Re-opening is the maintainer's call |
| `building` | already released — **with or without an open PR**, `in-review` folds into this same bucket (verified live, `zheref/bankai-core#918`/`#337`/`#879` all report `building` — `docs/ab/build.md` §§ 2.4, 2.4a) | Skip straight to § 4's drive step — the release already happened |
| `idea` | a raw brief (`bankai:stage/idea`) | Wake **Gon** so it is decomposed into an epic — his delegation grammar is **unratified** (`docs/ROSTER.md`), so this itself does not cross a gate on its own; he hands the decomposition back and this run takes it to § 3/§ 4 |
| `epic-awaiting-approval` | an epic that carries the epic label but no mode label yet | **Stop at G1.** The mode label is the maintainer's and is never delegated (`CON-4`) — § 3/§ 4 |
| `epic-approved` | an epic that carries the epic label **and** a mode label (`approved-team` or `approved-direct`) | Children advance wave by wave — § 4's epic-wave release step |
| `routable` | a routable child or a standalone task (no idea/epic/release label at all — verified live, `#673`/`#710`/`#494`) | Confirm the mode (§ 3), release it (§ 5), then build it |
| `undecidable` | a role in play was never mapped in `--chain-labels`, so this issue's true position cannot be told apart from another (verified live, `zheref/bankai-core#918` with no `--chain-labels` at all — § 2.7) | **Refuse the guess.** Supply the missing role and re-run; never proceed on a guess |

**No open `bankai-core` issue currently carries `bankai:stage/idea`, `bankai:stage/researched`,
`bankai:stage/ready-for-bankai` or `bankai:stage/ready-for-shikai`** (verified live, `gh issue list
--state all --label ...` for all four returns empty — `docs/ab/build.md` § 2.7). The `idea`,
`epic-awaiting-approval` and `epic-approved` rows are therefore contract-verified against `nen
issue chain-position --help` and the label taxonomy plus a **live run against a constructed role
map on a real object** (`zheref/akatsuki-ai#31` — `docs/ab/build.md` § 2.7a), not against a
`bankai-core` issue that natively carries those labels; say so rather than silently presenting
every row as proven against `bankai-core` itself.

An epic reported `epic-approved` is further split by which mode label it actually carries —
`bankai:stage/ready-for-bankai` vs `ready-for-shikai` — read directly off the issue;
`chain-position` folds both into the single `epic-approved` state and does not distinguish the two
itself (both are stops the maintainer already resolved at G1, and § 4 reads which one from the
labels present). Note also that `researched` is an **input role name** — one of the
`--chain-labels` keys the caller supplies (`researched=<label>`) — never a `chain-position` output
state; do not confuse the two.

## 3. The mode is confirmed before anything is released

**The issue is expected to carry its `bankai:agent/*` label already** — the same scope label the
retired skill read to choose a CI agent. In Hatsu it chooses Kurapika's **mode** instead, since he
is the only builder there is:

| Label present | Scope | Kurapika's mode |
|---|---|---|
| `bankai:agent/naruto` | needs a constitution/governance (`CON-{n}`) change | **Conjurer** |
| `bankai:agent/yamamoto` | needs a handbook / Stack Matrix / schema / agent-def change | **Conjurer** (his mode already covers both halves of the retired split — `claude/agents/kurapika.md` § Conjurer) |
| `bankai:agent/kisuke` | machinery only — a workflow, script, hook or scaffolder change an existing rule already sanctions | **Transmuter** |
| several labels, spanning lanes | the change genuinely spans lanes, and if it then needs more than one PR it is a `CON-36` chore on an `integration/<chore>` branch | Say so in the ask — it changes what "done" looks like: the delivery PR is `integration/<chore> → main`, not a child |

**When the issue carries none of these, propose one and ask** — routing decides which authority and
which handbook the work is built under, and a wrong mode produces a plausible PR in the wrong
shape. Ask it as a **`DECIDE`** through the harness's question interface, with the lettered
options, the ⭐ recommendation and its basis, and what would tip it (`CON-37`).

**A G1 stop is never a mode question.** If the issue is an unapproved epic (`chain-position`
reports `epic-awaiting-approval`), the ask is the mode label — `bankai:stage/ready-for-bankai` (integration-
branch team delivery) or `bankai:stage/ready-for-shikai` (direct-to-main) — and **only the
maintainer applies it** (`CON-4`). Present the trade-off; never apply either, inside a run or
outside it.

## 4. Driving the whole chain

Where the target is an epic, `build` follows it all the way down rather than stopping at the first
child:

1. **Gon decomposes** the idea into an epic with sequenced children (§ 2). His grammar is
   unratified, so this step is watched in-session, not delegated unattended.
2. **G1 is the maintainer's.** Stop (`nen stop --gate G1 ...`), brief the epic, ask for the mode
   label. Nothing below happens until it exists.
3. **Waves advance — this run's job, always.** Hatsu carries no `CON-23`-style epic-coordinator
   workflow (`docs/ROSTER.md` names no such standing process; the closest proposed role, Illumi, is
   **OPEN**, not adopted). There is no "watch, don't duplicate" branch to take here — releasing the
   next wave is mechanized directly:
   ```bash
   gh issue view <epic-N> --repo <owner/name> --json body -q .body > epic-body.md
   nen epic next-wave --body-file epic-body.md --citation <the clause the progress footer cites> \
     [--completed <n>] [--inflight <a,b>] --cap 2 --out epic-body-out.md --json
   ```
   Verified live end-to-end, including the redraw: a checklist item is only counted when the
   checkbox is *immediately* followed by `#<N>` (`- [ ] #101 …`) — a trailing `#<N>` elsewhere in
   the line is **not** recognised (`docs/ab/build.md` § 2.8, a finding worth knowing before
   authoring or reformatting an epic body by hand). A child releases only when every blocker named
   in its `(blocked by #a, #b)` annotation is a known, checked sibling; a duplicate child id refuses
   the whole computation at exit `1` rather than guessing a tie-break (verified live). **`--out`
   only rewrites the local file** — posting the redrawn body back to the real epic issue is a plain
   `gh issue edit <epic-N> --repo <owner/name> --body-file epic-body-out.md`, since no `nen` verb
   owns writing an issue body back to GitHub (residue, § 11).

   **This repository's own live epics do not use the checklist shape `nen` expects.** Both real
   epics checked (`zheref/bankai-core#733`, closed; `#568`, closed) write their phases as a
   markdown table or bold-prefixed bullets with a markdown-linked reference
   (`[BC-IS-#570](url)`), never a bare `- [ ] #<N>`, and `nen epic next-wave` reads `{"total":0,
   "done":0}` against both — zero children recognised (`docs/ab/build.md` § 2.9). Any epic this
   skill decomposes going forward (§ 2's Gon step) must write its checklist in the shape `nen`
   parses, stated to Gon explicitly, or this verb never sees a child at all.
4. **Each child's PR is driven** by [`drive`](../drive/SKILL.md)'s engine to `CON-32` readiness —
   reported, never eyeballed, via `nen pr ready` (see [`pr-state`](../pr-state/SKILL.md)).
5. **The delivery PR is the terminus.** Compute it, never infer it:
   ```bash
   nen issue terminus --target <owner/name> --issue <N> --chain-labels "<same map as § 2, minus role prefixes that don't apply>" \
     --integration-prefix "integration/" --trunk main
   ```
   Verified live: an issue with no epic/chore label answers `own-pr` — "the terminus is this
   issue's own PR into `main`" (`zheref/bankai-core#918`/`#673`/`#337`, and the real PR `#925`
   too — the same PR-vs-issue gap § 1 already flags; `#918` and `#337` transcribed in
   `docs/ab/build.md` §§ 2.6, 2.4a); a closed issue answers `run-already-ended`
   (`#733`, `docs/ab/build.md` § 2.6). For a `bankai`-mode epic that is the single
   `integration/* → main` PR the maintainer merges at G2; for shikai mode it is each child's own PR;
   for a `CON-36` chore it is the `integration/<chore> → main` delivery PR — **no live epic or
   chore-labelled object exists today to confirm those two branches on the real backlog**
   (`bankai:epic` has zero open issues, and bankai-core's taxonomy carries no chore label at all —
   § 2); they stand contract-verified against `nen issue terminus --help` only. **A sub-PR merged
   onto a chore or integration branch is not the gate** and never ends the run.

**Never drive more than two efforts concurrently.** Mechanized, not eyeballed:

```bash
nen loop slots --efforts efforts.json --local-cap 2 --json
```

**Every effort here is `"plane":"local"`** — Hatsu holds no `ci` plane at all, so a slot never frees
on "the PR opened" (that rule exists for a plane Hatsu doesn't have); it frees only once a PR is
both `"ready":true` **and** `"prompted":true` — the maintainer has actually been shown the `MERGE`
ask (§ 8) — exactly `nen loop slots --help`'s own local-plane rule: *"nothing else is behind a
locally-authored PR."* Verified live: two efforts with neither ready nor prompted report
`local: 2/2 occupied, 0 free <- BINDING` at exit `1`; flip one to `ready:true, prompted:true` and it
frees, `local: 1/2 occupied, 1 free` at exit `0` (`docs/ab/build.md` § 2.10).

**Always pass `--local-cap 2` explicitly.** Verified live, the verb's own **default is `7`**, not
`2` (and `--ci-cap` defaults to `2`, a plane this skill never populates) — omitting the flag would
silently triple this skill's own concurrency limit rather than enforcing it (`docs/ab/build.md`
§ 2.10, a finding). Say which effort is waiting when the cap binds — a PR **Ready and handed to the
maintainer frees its slot**, otherwise the run deadlocks the moment two PRs are waiting on a human.

**Never let two children touch the same file at once.** Sequence them and say so — no verb governs
this; it stays this run's own judgment.

## 5. Releasing into build — no CI plane to release *to*

Release is still `bankai:stage/building` — the G1-M go-signal (`CON-25`) — because the label is
still real bookkeeping: [`backlog-state`](../backlog-state/SKILL.md)/[`backlog-board`](../backlog-board/SKILL.md)
(both already landed) read it to place the issue on the board, and `CON-9` still requires exactly
one stage label at a time. Applying it is
logged, contract-verified against the binary (never exercised live against `bankai-core` — the
shared brief's read-only rule):

```bash
nen label apply BC-IS-#<N> --label bankai:stage/building --repo-slug <owner/name> \
  --reason "<why, for the ledger>" --run
```

Inside this run it may be applied without a further prompt, under the fourth carve-out (§ 6), **for
the named issue and for children created beneath it**. Every application is logged: object, label,
time, exactly as `--reason`/the ledger record (defaulting to `<repo>/label-ledger.jsonl`).

**Then — the declared change (see the callout above § 1): Kurapika builds it himself, in this same
session, in the mode § 3 confirmed.** There is no separate wake to verify, no `build` job to poll,
no `probe` run to distinguish from a swallowed one — those all describe a CI plane Hatsu does not
have. Say plainly that the build is local, and proceed to author it.

**Where the work is something a local session structurally cannot do at all** — it needs a
credential only a retired CI identity held, or the decision is one only that now-nonexistent plane
could make — **stop at G5 immediately** and name the gap, the same move
[`bankai-handbooks`](../bankai-handbooks/SKILL.md) makes for its own identical structural hole
(§ 4: *"Surface the
gap as a finding instead ... stop at G5 for the human to decide."*). This is the **only** shape this
port's version of the old "local authorship on structural impossibility" exception takes — inverted
from the retired skill's, where CI was the default and local authorship was the escape hatch; here
local authorship *is* the default, and there is no CI escape hatch left to fall back to.

**Exactly one stage label at a time (`CON-9`), and zero before release** — an issue that is
routed but not released correctly carries none. No verb enforces the mutual exclusivity across
`bankai:stage/*` itself; `nen label apply` applies one label and logs one decision — keeping only
one on the object at a time stays this run's own discipline (residue, § 11).

## 6. Authority — what this run may and may not do

`CON-25`'s fourth carve-out: a human-invoked skill run holds the delegation its purpose requires,
bounded by the same three conditions as any named loop run — **logged, run-scoped, and those label
classes only**.

| | `build` may |
|---|---|
| **Release** | `bankai:stage/building` on the named issue and on children created beneath it |
| **Route** | `bankai:agent/*` on **children it creates**, by scope (§ 3) |

**No `Wake` row.** The retired skill's third row — `bankai:wake/iterate`, fired alone — existed to
re-fire a *CI builder's* stalled loop. Hatsu has no CI builder for `build` to hold that authority
over; a wake against some other automated participant on a PR (a stalled review round, say) is
[`drive`](../drive/SKILL.md)'s authority, not this skill's. Dropping the row here is itself part of the
declared change (§ 1 callout) — say so rather than quietly carrying an authority forward that no
longer has anything to act on.

| | `build` may **not** |
|---|---|
| **Route the named issue itself** | If it carries no mode label, § 3 **asks**. The entry point's mode is the maintainer's read, not the run's |
| **G1 mode labels** | `ready-for-bankai` / `ready-for-shikai` — never delegated, inside a run or outside it |
| **Merge** | Not `main` (`CON-5`/`CON-7`), not a chore delivery PR, not its own PR anywhere |
| **Vote** | No review, ever — and never `request_changes` (`CON-26`) |
| **Release a release** | G3 is the maintainer's (`CON-6`) |

**The delegation expires when the run ends. Say when it ends.**

## 7. When it will not move

There is no CI-wake ladder for an effort Kurapika builds himself — that ladder (`drive` § 6 in the
retired skill) exists to distinguish a builder that never woke from one still working, and Hatsu has
no builder to distinguish. A stall in Kurapika's own work is reported plainly, in-session: what is
blocking it, and whether it can be worked around now or needs the maintainer's decision. Where it
cannot be resolved in this session, **stop at G5** and say exactly what is missing — a credential, a
tool, a decision only the maintainer can make. There is no "two verified wakes" threshold to clear
first, because there is nothing to verify a wake *of*.

Two shapes that still deserve their own naming, carried over from the retired skill with the same
inversion § 5 describes:

- **A routed-and-released issue Kurapika could not finish building in this session** is the
  closest analogue to the old "never produced a PR" stall. Report it as `🔵 on hold` naming exactly
  what is blocking it, rather than as silently abandoned.
- **The retired skill's "local authorship on structural impossibility" exception is now the only
  path, not the fallback** (§ 5) — so its own escape hatch (falling back to CI) has nothing left to
  fall back to. Where Hatsu cannot do the work at all, that is a **G5** stop naming the gap, full
  stop, not a routing decision.

**Filing an issue is a legitimate outcome of a build run.** If what blocks the delivery is a real
defect elsewhere, file it with [`file`](../file/SKILL.md), link it, and say the build is held on
it — a `🔵 on hold` effort naming what it waits on, not an abandoned one.

## 8. Reporting and the stop

**Progress turns carry no banner.** Report a compact status line — the issue, the mode, the PR, its
checks and rounds, what is next — and keep going.

**Every gate stop is the full protocol:**

```bash
nen stop --who Kurapika --gate <Gn> [--notified] efforts.md
```

Verified live: rendered the `YOUR INPUT IS NEEDED` banner, the rung-1/rungs-2-3 notification-status
lines, and the padded-markdown efforts table from a plain pipe-table input, unchanged
(`docs/ab/build.md` § 2.11) — plus the board published as an Artifact, ~5 lines of chat, and the
question — if there is one — through the harness's question interface. The gates this run reaches:

| Gate | When | Ask kind |
|---|---|---|
| **G1** | an epic awaits its mode label (`CON-4`) | `DECIDE` — bankai vs shikai, with the trade-off |
| **G2 / G4** | the delivery PR is `CON-32`-Ready | `MERGE` — the verdict says everything |
| **G5** | a stuck local build, a mode question, a missing capability | `DECIDE` or `DO`, with options |

The run **ends** when the delivery PR stands Ready at its gate, when the issue closes, or when it
stops at a G5 it cannot pass. Say which — and say the delegation has lapsed.

## 9. Resuming

Resumable **by re-invocation**: `hatsu:build <CODE>#<issue>` run again re-reads live state (§ 2's
`chain-position` call is idempotent — it reads, never writes) and picks up where the objects
actually are. Write run state to `docs/Loop/<run-id>/` — decisions, every logged label application,
and (since there is no wake to track any more) every local build session's own progress — so a
fresh session does not re-derive it, and **never trust it over a fetch**.

## 10. Findings against the binary (report, never route around)

1. **`nen issue chain-position` and `nen issue terminus` never check whether the number they were
   given names an issue or a pull request.** Verified live against a real PR
   (`zheref/bankai-core#925`): both answer as if it were an ordinary issue (`routable` /
   `own-pr`), with no error and no distinguishing signal — § 1's manual `gh api
   repos/<owner>/<repo>/issues/<N> --jq '.pull_request'` check exists because of this gap.
2. **A `--chain-labels` map missing any role in play is not a partial answer — it is
   `undecidable`** (exit `1`), and an unknown role name is refused outright (exit `2`). Both
   verified live (§ 2). Supply the full map every time; there is no safe subset.
3. **`nen epic next-wave`'s checklist recognises only `- [ ] #<N> …` / `- [x] #<N> …`** — the
   checkbox immediately followed by the child reference. A trailing `#<N>`, a markdown-linked
   reference, or a bold-prefixed label before the number are all invisible to it, silently
   contributing zero children rather than erroring (§ 4). Neither of `bankai-core`'s own two real
   epics uses the shape this verb expects.
4. **`nen loop slots`'s local-plane default cap is `7`**, not `2` — this skill's own hard limit
   must be passed explicitly every time (§ 4).

## 11. Residue — what stays this skill's own judgment, or has no verb yet

- **Severity/mode reasoning, the `DECIDE` brief at § 3, and the G5 diagnosis at § 7** stay
  judgment — `nen` computes and verifies; it never decides what only judgment can (the shared
  brief's boundary list).
- **Posting an epic's redrawn body back to GitHub** (§ 4) has no `nen` verb — `gh issue edit
  --body-file` remains a necessary raw call, same as the retired skill's own coordinator would have
  needed.
- **Keeping exactly one `bankai:stage/*` label on an object at a time** (§ 5, `CON-9`) is not
  enforced by `nen label apply` itself, which only ever applies and logs the one label it was given.
- **The issue-vs-PR check** (§ 1, finding 1) stays a plain `gh` read until `nen` grows one.

## 12. Hard limits

- **Never merges `main`**, never merges its own PR, never merges the chore/integration delivery PR.
- **Never applies a G1 mode label**, and never routes the entry issue without an answer.
- **Never self-reviews, never impersonates a reviewer, never casts `request_changes`.**
- **Never exceeds two concurrently-driven efforts** (`nen loop slots --local-cap 2`, § 4), and never
  lets two children touch one file.
- **Never claims a CI builder is doing the work.** Hatsu has none — say plainly, every time, that
  Kurapika builds it himself (§ 5).
- **Never publishes a release** — G3 is the maintainer's.
- **Never leaves the delegation open** — the run says when it ends.
