---
name: backlog-loop
description: Drive a target repository's backlog to zero open actionable issues, in severity order, as gate-ready PRs. Use when the maintainer asks to work the backlog, clear open issues, run the loop, or keep a repo current. Kurapika triages, sequences build and sharingan across at most two efforts, cuts tags and runs the fan-out at severity-batch boundaries, and renders the per-cycle status board as a Rikugan. Never merges main; G2/G4/G3 stay the maintainer's.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

**Shared policy** (`docs/*.md`) lives at the Hatsu plugin root `hatsu-warmup` prints; a missing
consumer copy is never a filing.

# Backlog loop — drive a backlog to zero, in severity order

**Nature: Manipulator**, with each advanced issue switching to whatever mode
[`build`](../build/SKILL.md) § 3 confirms for it. Name the mode when it switches.

> **Declared process change.** The retired skill spent most of its bulk on a CI plane. **Hatsu holds
> no CI plane at all** — no App, no workflow, no bot identity — so "advance an issue" is almost
> entirely a **pointer**: turning a routable issue into a PR is [`build`](../build/SKILL.md)'s whole
> job, driving that PR to `CON-32` readiness is [`sharingan`](../sharingan/SKILL.md)'s, and **this
> skill's own job over both is the concurrency arbitration, the ordering and the batch-boundary
> layer.** Nothing about either engine is re-described here.

`nen backlog fetch|order`, `nen loop slots`, `nen pr staleness`, `nen tag cut`, `nen fanout
compute|record`, `nen changelog collate|completeness|fragment-required`, `nen report data|render` and
`nen stop` are this skill's own verbs. `build`/`sharingan`'s verbs are never re-invoked here.

## 1. Invocation

```
/backlog-loop <repo_code>
```

```bash
nen parse backlog-loop --grammar "<repo>" --line "<the raw invocation>"
nen repo resolve <CODE> --repo <target repo checkout>
```

A single-slot grammar, so the generic parser's bracket-swallowing gap cannot bite; an empty line is
refused with a corrected line ready to paste. The code resolves against the registry, **never from
memory**, and an unresolved code is an error listing the registry's real codes.

**Say the run has started.** A named run holds a bounded `CON-25` delegation (§ 3); a delegation
nobody announced is one nobody can end.

**The phases this composite calls skip their own standalone-entry sections.**
[`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) is for a phase typed by hand into an
arbitrary checkout; a phase reached from here inherits P1–P4 from this run.

## 2. The cycle

Re-run on every fetch trigger: at start, whenever an issue reaches its gate (a PR merges or goes
Ready), and whenever the monitor (§ 6) sees a PR state change.

1. **Fetch** every open issue, fresh — `nen backlog fetch --repo-slug <owner/name> --json`, **never
   cached, never capped**; omit `--limit` entirely, and never render a `truncated: true` fetch as
   complete.
2. **Triage** anything with no `bankai:severity/*` label (§ 4).
3. **Order** the queue (§ 5).
4. **Advance** up to **two** efforts (§ 5a).
5. **Check batch boundaries** — a severity batch fully merged fires a tag-cut and fan-out (§ 7).
6. **Report** the status board (§ 8).

## 3. Authority

`CON-25`'s **third carve-out** — the run-scoped standing delegation the constitution names for this
skill by name, not the fourth carve-out's per-skill table.

**It may** propose and apply `bankai:severity/*` on an untriaged issue, logged, and hand an issue to
`build`, which applies `bankai:stage/building` under its own delegation.

**It may not** apply a G1 mode label, inside a run or outside it; merge `main`, a chore/integration
branch, or its own PR anywhere; cast any review or `request_changes`; publish a release — the GitHub
Release is **G3, the maintainer's alone** (`CON-6`), and § 7 prepares it and stops; **cut a tag
outside a § 7 boundary** — permitted only there, after the changelog-collation release PR the
maintainer merges, never past a refused tag capability, never on an `--at` that is not an ancestor of
`origin/main`, and a cut because a band "looks finished" is not a boundary; or fire or verify a wake,
which lives entirely in `sharingan`.

> **`CON-46(c-i)`'s stale-chore-merge carve-out is retired here, not restated.** It lets a local
> persona merge a stale CI author's Ready sub-PR onto an `integration/<chore>` branch; Hatsu holds no
> CI plane, so no such sub-PR can go stale in the sense that rule requires.

**The delegation expires when the run ends. Say when it ends.**

## 4. Triage & briefing

**Untriaged (no `bankai:severity/*`).** Propose a severity with one line of reasoning, then apply
it under the carve-out:

```bash
nen label apply <CODE>-IS-#<N> --label bankai:severity/<level> --repo-slug <owner/name> \
  --reason "<why, for the ledger>" --run
```

The severity taxonomy is read from the **target's** `nen/labels.json` and nowhere else, never
hard-coded. Pass `--repo <the target's checkout>` so the label validates against that file, not
against the checkout the loop happens to run from.

**`bankai:handbook-question` items and design calls need a decision, not a fix.** Brief the
maintainer at G5 (§ 8) with a `DECIDE` ask: what is being asked, the options, the recommendation and
why. **Never guess a policy call and never close one unanswered** — an unanswered question is a
briefed row, not a resolved one.

**Routing an issue to a mode is `build`'s § 3 question, not this skill's.** This skill decides only
*when* an issue's turn comes up.

## 5. Priority order

```bash
nen backlog order --rows-from <path> --severity-order critical,high,medium,low \
  --blocks <ids> --affects-consumers <ids>
```

`--rows-from` is **not** `backlog fetch --json`'s output: reshape each row to
`{id, severity, createdAt, number}` first, severity read off the label. The verb validates that file
at the read seam and refuses a fetch document, or a row missing `id`, at exit `2` naming file, row
and field. What stays this skill's judgment on top: **`critical` pre-empts everything in flight**, a
`low` is deferred behind anything higher still open, and an issue that blocks another or affects
consumers is named as such rather than merely ranked.

## 5a. Advancing an effort

**Work at most TWO efforts at a time. Never three.** Mechanized, not eyeballed:

```bash
nen loop slots --efforts efforts.json --local-cap 2 --json
```

Every effort here is `"plane":"local"` — Hatsu holds no `ci` plane, so a slot frees only once a PR is
both `"ready":true` **and** `"prompted":true`, meaning the maintainer has actually been shown the
ask. **`--local-cap 2` is required** — nen removed the inherited default so a guard is chosen rather
than assumed, and omitting it is exit `2`. `--efforts` resolves against the process cwd, so pass an
absolute path.

**When a slot is free**, take the next row `nen backlog order` returned (respecting § 5's judgment
layer) and hand it to [`build`](../build/SKILL.md) (`/build <CODE>#<N>`); once a PR exists,
[`sharingan`](../sharingan/SKILL.md) (`/sharingan <CODE>#<N> to <G2|G4>`) takes it the rest of
the way. Neither engine is restated.

**`nen pr staleness`** is reconfirmed here because a backlog-wide loop keeps the wake-attempt log
across many efforts at once. This skill reads the same two conjuncts `sharingan` reads and **never
the `mergePermitted` field**: this run carries no merge delegation, ever.

**The wake channel is narrower, not dead — and it lives in `sharingan`.** The PRs this loop drives
are Kurapika-authored by default, which sharingan addresses directly; a PR by a genuinely external
automated participant is the shape sharingan § 5 fires `nen wake fire`/`verify` for. **This skill
never calls either verb** — it only recognises, from what sharingan reports back, that the effort is
CI-authored, and keeps counting it against the same two-slot cap.

**Never two efforts touching the same file.** No verb governs this; sequence them and say so.

## 6. The monitor

Between cycles keep watching PR check transitions, new reviews, new comments, merges, and new or
relabelled issues. A merge or a state change is a fetch trigger — go back to § 2. There is no
scheduled sweep behind this run; polling is in-shell and in-session, exactly as sharingan does.

## 7. Tag-cut, fan-out and release

| Trigger | Action |
|---|---|
| All `critical` **merged** | tag-cut + fan-out. Nothing releases while a `critical` is open |
| All `high` **merged**, changes unreleased | tag-cut + fan-out; do **not** pause `medium` work |
| All `medium` **merged**, no `critical`/`high` open | tag-cut + fan-out + prepare the official release with developer-facing notes — then **stop at G3** |
| `low` merged | tag-cut, **hold** the fan-out |

The cut itself, the `CON-36` live-chore check, an active `RELEASE_HOLD`, `changelog.d/`, `latest`
and the `CON-22` fan-out computation are [`getsuga`](../getsuga/SKILL.md)'s lane; this skill reaches
a boundary and hands over. **If the tag capability is refused, HALT and hand the maintainer the exact
command** — never route around a refusal, never write `latest` for a tag that does not resolve
(`CON-14`).

## 8. The status board — the register, every cycle

**Rendered, never hand-formatted.** The per-cycle status board is a **Rikugan**, rendered
through the register variant, via [`backlog-board`](../backlog-board/SKILL.md) § 3 — one collapsible
row per issue and PR in the queue, the desk carrying this cycle's asks, grouped by gate and ranked.
No hand-authored HTML and no markdown table standing in for it.

Beyond the register, state every cycle the briefed items awaiting a decision, the blocked items and
what blocks them, and every label applied under the delegation (issue, label, time). Objects use
`<CODE>-<IS|PR>-#<N>` from `nen ref format`, never memory.

**Every place this run reaches a gate is a gate event** — `nen stop --who Kurapika --gate <Gn>
[--notified] board.md` renders the banner, the register is published as an Artifact, and the question
goes through the surface's own option picker. The banner is the "I need you" signal, never printed
for a plain progress report.

**When the maintainer is needed, do not stop.** Notify, record it on the register, and continue on
other efforts. Only a genuinely empty actionable queue ends a cycle.

## 9. Conflict discipline

**One worktree per effort**, per `build`/`sharingan`'s conventions; **cascade `main` whenever it
moves** (`nen pr cascade-main --repo <path> [--trunk main]`); **never two efforts on one file**.

## 10. Ending the run

The run ends when the actionable queue is empty: every open issue delivered as a PR standing at its
gate, briefed and awaiting a decision, or blocked with its blocker named. Say the run has ended so
the delegation lapses. **The final report is the `final` Rikugan** (backlog-board § 3) —
one effort, a cleared desk, written to `<reports.dir>/<YYYY-MM-DD>-<effort>.html` — carrying every
issue with its state, every PR's verdict verbatim, every label with its time, and what is on the
maintainer's plate. **This skill never resumes itself** — re-invoke it.

## 11. Hard limits

- **Never merges `main`**, a chore/integration branch, or its own PR anywhere.
- **Never self-reviews, never impersonates a reviewer, never casts `request_changes`** — binding even
  when the finding is real; sharingan's wake channel exists so no vote is ever needed.
- **Never applies a G1 mode label** — human-only, inside a run or outside it.
- **Never fires or verifies a wake itself** (§ 5a).
- **Never cuts a tag outside a § 7 boundary**, never auto-pushes one without `--push`, and never
  publishes the release — that is **G3**, the maintainer's alone.
- **Never exceeds two concurrently-driven efforts**, and never lets two touch one file.
- **Never hand-formats the status board** — it is the register variant (§ 8).
- **Never closes a briefed policy call unanswered.**
- **The run-scoped delegation expires when the run ends.** Say when it ends.

*History, retired findings and residue lists moved to this effort's history file;
`docs/ab/backlog-loop.md` has the dated live verifications.*
