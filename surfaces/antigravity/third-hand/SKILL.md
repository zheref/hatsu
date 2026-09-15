---
name: third-hand
description: Harvest one sitting's process friction as Netero — propose 0–3 folded issues, file only what the maintainer picks, then end the session. Use when En wraps the regular Kurapika pipeline after the retained final report, or when the maintainer invokes /third-hand while wrapping. Never merges, never implements the filed work.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md` and
`docs/LAUNCH-MIGRATION.md` belong to the resolved **Hatsu plugin root**, not the consuming
repository. On an installed surface, use the absolute root printed by `hatsu-warmup` to read
those files (re-resolve through that skill if unavailable). Relative links below identify source
locations; a missing consumer `docs/` copy is not a missing policy and must not trigger a duplicate
filing. Never copy or invent a second policy in the target repository.


# Third Hand — the chairman's last look at the sitting

**Nature: Manipulator.** The harvest is GitHub-side filing under
[`claude/agents/netero.md`](../../agents/netero.md). Name **Conjurer** alongside it when a proposal
is constitution or canon prose, **Transmuter** when it is machinery. Never blend two under one
header (`claude/agents/kurapika.md`).

> **Before this sitting closes, have Netero look at what actually slowed us — fold the same
> problems together, show me at most three issues, file only the ones I pick, then stop.**

Third-Hand is [`/en`](../en/SKILL.md)'s session-closing step on the regular Kurapika pipeline
(`ren` → `aka` → `mukai` → `en`). En has already rung at Ready and rendered the retained final
report. The human merge remains **G2** and has **no skill** — this file does not describe a merge
and does not wait for one. What it describes is the wrap-up harvest that runs **in parallel** with
presenting that report, so the page may already be in the maintainer's hands while Netero reads
the sitting.

**Netero files. He never implements the filed work.** Landing a solution is a later Kurapika or
Nen effort, never this skill.

**This file composes. It does not re-specify.** Filing, labels, four-pass reconciliation, and
completeness live in [`/file`](../file/SKILL.md), [`docs/DISCOVERY.md`](../../../docs/DISCOVERY.md)
and Netero's definition. What is genuinely this skill's own is the wrap-up trigger, the parallel
summon, the 0–3 fold-and-priority cap, the picker, and the session-over rule.

---

## 1. Invocation

```
/third-hand [on <CODE>#<N>]
```

```bash
nen parse third-hand --grammar "on [<ref>]" --line "<the invocation, minus the /third-hand prefix>"
```

Verified live at nen `0.10.0` (`docs/ab/third-hand.md` § 2.1): `on HA#62` → `ref: HA#62` at exit
`0`; a bare `on` and an empty line both parse with the clause absent, also exit `0`. **No clause
means this sitting** — the PR En is holding, or the branch this session cut, named out loud.

**En starts this skill with no parse.** Echoing a parse of a line nobody typed is theatre, the
same reason [`/en`](../en/SKILL.md) § 1 does not parse Mukai's handoff. The parse runs when,
and only when, the maintainer typed a clause.

---

## 2. When it runs — wrap-up, not merge

**Started by En** after the retained final report (§ 8 of that file), in parallel with presenting
it, when the regular pipeline is wrapping — the maintainer has decided to merge and close the
sitting, or En has reached a terminus that ends the sitting (verified Ready at the human gate,
merged-before-handoff, closed unmerged, cap-out, or an interruption the maintainer treats as
wrap-up).

**Also invocable by the maintainer** when wrapping a sitting whose En already ended (they merged
on GitHub and came back; they re-opened the conversation after Ready).

**Never a sixth human-called phase, and never a prompt for the merge.** The five phases only the
maintainer calls stay `aka`, `mukai`, **the merge**, `kagutsuchi`, `mugetsu`. Asking "shall I run
third-hand?" is how a composed close becomes an agent-prompted one by attrition — En starts it;
a direct call is wrap-up, not a suggestion at the end of a Ren turn.

**Never auto-starts from a Ren turn or from Aka.** Those sittings are not over. A G5 that the
pipeline still owns is not wrap-up.

**Once per sitting.** If `.nen/third-hand/<slug>.json` already carries a completed harvest for
this PR (or this branch, when no PR was named), skip, say `already-harvested`, and still end the
session. Do not re-ask. `<slug>` is `<CODE>-<N>` from `nen ref format` when a PR is in play,
otherwise the branch slug.

---

## 3. Raise Netero in parallel

On a surface with in-session subagents, raise **one** delegate titled
**`third-hand · netero · <model alias>`**, on Netero's own pin (`model: opus`, effort `high` in
the definition — **do not pass `model`**, the same reconciliation [`/hanten`](../hanten/SKILL.md)
§ 4 records: the harness `model` parameter would silently overrule the frontmatter). **Never the
frontier tier.**

| Surface | How he is raised | Isolation |
|---|---|---|
| **Claude Code** | the harness Agent tool, `subagent_type` the Netero persona (`/netero`) | **omitted** — he needs this sitting's report, last-stop, cycle ledger and transcript, not an isolated checkout of the plugin |
| **Cursor** | the netero definition under `.cursor/agents/netero.md`, invoked as that surface documents; if the harness only offers a generic worker, load the definition into it and keep the title | omitted, same reason |
| **Antigravity** | `invoke_subagent`, `Workspace` that does **not** hide this sitting's `.nen/` and `Reports/` | do not send him to a blank branch workspace that cannot see the harvest inputs |
| **Codex** | **no in-session subagent** (`docs/SURFACES.md` § 1) — Kurapika applies Netero's protocol in the foreground after the report is presented, names the switch, cites the definition. Sequential, not parallel, and said out loud | n/a |

**Two passes, one persona.**

1. **Harvest (parallel with the retained report).** Netero reads the sitting and returns **0–3
   complete drafts**. He files nothing on this pass.
2. **File (after the pick).** Only the drafts the maintainer selected, through
   [`/file`](../file/SKILL.md) under Netero's completeness. Reconciliation still runs; a
   duplicate is `updated` / `folded` / `unchanged`, never double-created.

Pass 1's prompt names: the PR or branch, the retained report path if it exists, `.nen/last-stop.json`
if present, `.nen/hanten/<branch-slug>.cycle.json` if present, the En loop ledger if present, this
skill's § 4 inputs and § 5 output shape, and *"file nothing until the maintainer picks"*.

**A second-process `codex exec` is not this harvest.** Hanten's isolated reviewer run exists because
reviewers must not share the author's tree. Netero must share the sitting. Do not repurpose that
mechanism.

---

## 4. What he reads — the sitting, not the backlog

Every class in Netero's observation table is in play, including ones the maintainer did not name:

| Input | Where | What it is for |
|---|---|---|
| Session challenges, not delivered, decisions | the retained final report, else `Reports/current.html` | what the Hunter already admitted was hard |
| Duration | turn times, watch length, suite length, warm-up seats | jobs that cost more than they returned |
| Redundancy | the same hand pipeline run more than once this sitting | work a verb should own |
| Autonomy gaps | G5 stops, extra asks, midwifed steps the maintainer expected to run unattended | bottlenecks against autonomous delivery |
| Determinism | improvised shell standing in for a Nen verb; residue sections actually exercised | predictability |
| Toolchain | `nen shu tools` seats, missing versions, utilities the agent lacked | provisioning |
| Other roster friction | Hanten budgets exhausted, En cap pressure, missing verbs named in residue | fold into the classes above when they are the same problem |

Sanitize. No credentials, no private logs, no personal-device identifiers, no unrelated consumer
data. Do not invent a finding from another sitting. Do not file a UI finding as the chairman's
(Hisoka), a security finding (Feitan), architecture (Chrollo), a number-without-method-block
(Uvogin), or a long-watch provision (Illumi) — note it in one line and skip.

---

## 5. Zero to three proposals — fold similar, drop the rest

**Cap: 0, 1, 2 or 3.** Zero is a valid harvest: the sitting was clean enough that nothing rises
to an issue. Say so, skip the picker, write the marker, end the session.

**Fold.** Similar problems of the **same owner** and the **same missing capability** become one
proposal — repeated warm-up seats, the same improvised pipeline, the same missing verb hit three
times. That is the wrap-up exception to Netero's in-execution rule *"one finding, one issue"*.
Distinct owners stay distinct (Hatsu prose and Nen machinery are still two issues, cross-linked).
Distinct classes stay distinct until the cap forces a drop.

**Prioritize.** Rank by how much they blocked autonomous delivery this sitting, then by how
cheaply a verb or a skill-prose fix would remove the class, then by recurrence. Drop what does
not make the three. Dropped findings are listed in the harvest marker as `not_proposed` with one
line why — they are not silently filed later.

**Each proposal is a complete draft**, not a title:

1. `id` — `p1` / `p2` / `p3` in priority order
2. `owner` — Hatsu or Nen, resolved with `nen repo resolve`, never guessed
3. `class` — duration / redundancy / autonomy-gap / determinism / toolchain / other
4. `title`
5. `why` — one line for the picker label
6. the full issue body Netero's completeness owes (problem, sanitized evidence, who it matters
   to, observable acceptance criteria, scope boundaries, deployment / fan-out / provisioning
   cross-references)
7. labels from the **target** `nen/labels.json`, none invented

Return them in that shape. Do not file them on pass 1.

---

## 6. The picker — then file only the pick

**The question is the harvest, not a G5 stop and not the merge.** Do not call `nen stop`. Do not
re-render [`/file`](../file/SKILL.md) § 4's DECIDE banner. The pick **is** the confirmation
for those drafts.

Present **one** question through the surface's own native option picker:

| Surface | Picker |
|---|---|
| **Claude Code** | `AskUserQuestion`, multiple selection |
| **Cursor** | `AskQuestion`, `allow_multiple: true` |
| **Codex** | no native picker — lettered options in the reply, wait for the typed pick (`docs/SURFACES.md`) |

Prompt: Netero folded this sitting's process findings into N proposal(s). Pick which to file.
Unselected are not filed. File none ends the session with no new issue.

Options: one per proposal, label `[Hatsu|Nen] <title> — <why>`, plus **`none`**: *File none —
session over without new issues*.

**`none` wins over every other selection.** If the maintainer ticks proposals and `none`, file
nothing.

**Zero proposals: no question.** Do not ask them to confirm the empty set.

After the answer, pass 2 files each selected draft through `/file` under Netero's
completeness and DISCOVERY standing authority. Four-pass reconciliation still runs immediately
before each write. Unselected drafts are not filed, not parked as pending issues, not offered as
`/build`.

**Do not offer `/build` after a harvest filing.** File's § 6 offer starts a new effort; this
sitting is over. Report each created or updated URL in the target's object notation and stop.

---

## 7. The harvest marker, and session over

Write (or overwrite only when this sitting had not completed) `.nen/third-hand/<slug>.json`:

```json
{
  "contract": "hatsu.third-hand.harvest/v0.1",
  "at": "<ISO-8601>",
  "ref": "<CODE>#<N or branch slug>",
  "proposed": [{ "id": "p1", "owner": "Hatsu", "class": "determinism", "title": "…" }],
  "not_proposed": [{ "why": "dropped under the cap" }],
  "picked": ["p1"],
  "filed": ["<url>"],
  "result": "filed"
}
```

`result` is one of `filed` · `none-proposed` · `none-picked` · `already-harvested`. The directory
is gitignored with the rest of `.nen/`; [`hatsu-warmup`](../hatsu-warmup/SKILL.md) never deletes
it. **This is Hatsu residue, not a Nen verb.**

**Then the session is officially over.** Say the object notation of anything filed (or that
nothing was), the harvest `result`, and that the sitting is closed. Do not wait for the merge.
Do not start the next Ren turn. Do not prompt for `aka`, `mukai`, merge, `kagutsuchi` or
`mugetsu`. A later human request is a later sitting.

---

## Residue

1. **Raising Netero has no nen verb, and is not expected to get one.** nen owns operations, not
   conversations (`docs/ab/ren.md` § 2.2). Named here, the same class as Hanten's Agent-tool raise
   and En's Illumi hand-off.
2. **The harvest marker is Hatsu-owned JSON** at `.nen/third-hand/<slug>.json`, contract
   `hatsu.third-hand.harvest/v0.1`. No verb writes it. A missing file means "not yet harvested",
   never "no findings".
3. **The picker is the surface's**, never nen's (`docs/ab/jutaisho.md`). Codex's lettered-options
   fallback is named rather than dressed up as a native control.
4. **The composition itself has no verb.** Filing inside pass 2 is `/file`'s verbs; owner
   resolve is `nen repo resolve`; ref formatting is `nen ref format`.

## Authority

- **Permitted:** raise Netero under § 3; read the sitting's report and `.nen/` inputs; present
  the picker; file only picked drafts through `/file` under Netero's completeness.
- **Not permitted:** any merge; any review vote; any implementation of a filed issue; any
  `/build` started from this skill; any stage or release label; any push, tag, or deploy;
  inventing a finding, a label, a slug, or a fourth proposal.
- **Standing discovery authority covers the writes the maintainer picked.** It does not cover
  filing unselected drafts "because they were good".

## Hard limits

- **Never merges, never votes, never implements the filed work.**
- **Never files more than three issues from one harvest**, and never files a draft the
  maintainer did not pick.
- **Never prompts for the merge**, and never waits for it to close the sitting.
- **Never raises Netero on the frontier tier**, and never omits the title
  `third-hand · netero · <model alias>`.
- **Never isolates him from this sitting's evidence** in a worktree that hides `Reports/` or
  `.nen/`.
- **Never skips the four-pass reconciliation** because the draft was already written on pass 1.
- **Never offers `/build`**, and never starts one.
- **Never auto-starts from Ren or Aka**, and never asks "shall I run third-hand?" to smuggle a
  composed close into a human-called phase.
- **Never restates `file` or Netero's completeness.** If this file and those disagree, those
  are right and this file is the bug.
