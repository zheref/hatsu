---
name: futon
description: Work one selector of a repo's backlog — a severity band or one exact label — into PRs with an actor behind them, then run what follows then. Use when the maintainer invokes hatsu:futon <repo>@<severity[+] | label> [then tag | tag+fanout | <skill>[@<target>][+<skill>…] | <prose>], or asks to work a band or a label. every PR is Kurapika's own (Hatsu carries no CI plane), so done means CON-32 Ready and a per-PR merge prompt. Nothing after then runs before that; a typed then step is the maintainer's own call for the skill it names (the advance go, mugetsu § 3). Never merges main, never publishes a release.
---

**Shared policy:** [`PROCESS.md`](../../../docs/PROCESS.md) § *Standalone entry*.

# Futon — one selector, from open issues to PRs with an actor behind them

**No fixed mode**: the mode [`build`](../build/SKILL.md) § 3 confirms per issue while authoring,
**Manipulator** while the PR is driven to its gate. Name it; never blend two.

> **Name a band or a label; I give it back with every issue in it carrying a PR that is `CON-32` Ready and
> prompted for your merge — then, if you typed `then`, what follows it, on your own typed word.**

Per issue, futon is [`build`](../build/SKILL.md) → [`tensho`](../tensho/SKILL.md) →
[`en`](../en/SKILL.md); what follows `then` is § 8's, never futon's own.

Futon is a **scoped, terminated [`backlog-loop`](../backlog-loop/SKILL.md)**: a **selector**, an
**explicit `then`**, and **who is behind every PR**.

> **Hatsu carries no CI plane** ([`WORKFLOW.md`](../../../docs/WORKFLOW.md) § *Building an issue
> with no CI plane*): **Kurapika builds every issue this run releases.** A PR opened *before* this run
> by the target's CI identity keeps its own done rule (open) and the **CI** half of § 6; futon never
> creates one.

## 1. Invocation

**P1 — `hatsu:ten futon` opens this run** ([`ten`](../ten/SKILL.md) § 6).

```
hatsu:futon <repo>@<severity>[+] [then tag | then tag+fanout | then <skill>[@<target>][+<skill>[@<target>]…] | then <prose>]
hatsu:futon <repo>@<label>       [then ...]
```

```bash
nen parse futon --repo <target checkout> "<invocation, minus the prefix>" [--self <owner/name>]
```

**`futon` is a built-in `nen parse` grammar** — one call resolves the repo,
reads the **selector**, classifies `then` (§ 8) and enforces a terminal's scope rule. A severity name
(`critical`, `high`, `medium`, `low`) is a **band**, `+` that severity **and above**; **any other token
is a label**, matched exactly as typed (case and spaces kept, quotes stripped) and **never expanded**
— a trailing `+` on a non-severity token is part of the label (`c++`); `--json` sets `band` or
`label`, never both. **Exit `2` asks, never ends**: the corrected line goes to the picker (an empty
selector gets none), the answer is re-parsed, and a missing argument or configuration item is set up
inline (`missing-argument`, `missing-configuration`; [`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 4).
**A re-parsed picker answer never carries a `then` step**: a corrected line is offered with its whole
`then` clause stripped, and the maintainer retypes it. **The selector is the maintainer's word: never derived.** No `then` clause is not a
gap (§ 8).

**Echo the full parse before anything is fetched** — repo, the selector (a band with its severities
named, or the label verbatim), the `then` clause as classified or *build-only* — and **say the run
has started**: a named run holds a bounded `CON-25` delegation (§ 7), announced so it can end.

## 2. The queue is the selector's scope — and only that

`nen backlog fetch --repo-slug <owner/name> --json` — never cached, never `--limit`; a capped fetch
is reported **truncated**. Then:

- **Select** — by band: every issue whose `bankai:severity/*` label is in the band; with `+`, that
  severity **and every severity above it**. By label: **every open issue carrying that exact label**,
  whatever its severity; one without it is out of scope, reported, never worked.
- **Triage the untriaged** as `backlog-loop` § 4 does. Under a band, **a triaged severity inside it
  joins the queue; outside, the issue is recorded triaged-and-out-of-scope and left alone.** Under a
  label, triage **orders only, never selects**: no severity brings an unlabelled issue in. Say which,
  every time.
- **`bankai:handbook-question` items and design calls are briefed, never guessed**, and never hold
  the scope open.
- **Order within the scope** with `nen backlog order`, as `backlog-loop` § 5 does: higher severity
  first, **`critical` pre-empting everything**.

**State the queue before advancing anything** — the count, every issue, every exclusion and why: the
run's auditable scope.

## 3. The engine is `backlog-loop`'s, invoked

Triage and briefing, ordering, the monitor and its fetch triggers, conflict discipline and the hard
limits are its. **A CI-lane label picks Kurapika's MODE**
([`build`](../build/SKILL.md) § 3); an issue carrying none gets a proposal and a `DECIDE` (`CON-37`).

## 4. Releasing into build

```bash
nen label apply <CODE>-IS-#<N> --label bankai:stage/building --repo-slug <owner/name> --reason "<why>" --run
```

**Then Kurapika builds it, this session, in the mode just confirmed**, through the verbs the target
declares as [`build`](../build/SKILL.md) § 5 lays them out, in the effort's own worktree, exits read per
kurapika.md § *The `shu` verbs*; work a local session cannot do is a **G5**, gap named.

## 5. Done is merged

> Every PR futon produces is Kurapika's own: **not done at PR-open**, but when
> `nen pr ready` **and** `nen pr body-check` both pass, quoted, and en § 5 has merged it
> **on `branch.base`** (ruling 2026-09-29 (3)) — it **holds its slot** till then.

## 6. Two concurrency budgets, counted separately

```bash
nen loop slots --efforts efforts.json --ci-cap 2 --local-cap 7 --json
```

The **CI** plane caps at 2, frees at PR-open, and holds only legacy-CI PRs. The **local** plane caps
at 7 and frees only when the PR is **merged**; every PR this run authors sits there. **`--local-cap 7` is futon's own policy, always passed**; omitting it is exit `2`;
`--efforts` resolves against `--repo`'s root (absolute from a worktree). **The budgets are
never traded**: a full local one is back-pressure.

## 7. Authority — the CON-25 delegation

**Futon may** apply `bankai:stage/building` on issues in scope, and `bankai:severity/*` on an
untriaged one with its reasoning, logged: object, label, time. **No Route or Wake row**; a stalled
review round is [`sharingan`](../sharingan/SKILL.md)'s channel, never a label fire. **Futon may not** do what § 11 forbids; an out-of-scope issue is reported, never worked.

## 8. The `then` clause — futon gates it, never performs it

**No `then` clause, nothing after the run**: never a cut because the scope looks done. The clause
starts at the first whole-word `then` after `@`; a bare `then` is exit `2`.

**Futon's own job at the clause is exactly one gate**: nothing after `then` runs while a PR this run
authored is short of `CON-32` Ready (§ 5) — hold it, name every PR still short with its verdict, keep
driving them. A legacy-CI PR does not hold it. Then, as `nen parse futon` classified it:

- **`then tag` / `then tag+fanout`** (`terminal`) go to [`getsuga`](../getsuga/SKILL.md), whose lane
  the whole cut is. `then tag` hands off with **fan-out skipped, its issues left open** — say so:
  consumers stay on the previous tag; `tag+fanout` adds it. **A refused tag capability HALTS, the exact
  command handed over**; never route around it; this run never writes `latest` (`CON-14`).
- **`then <skill>[@<target>][+…]`** (`kind: skills`, `steps` inside; bare or `hatsu:`-prefixed) run
  **in order**, each resolved against the installed skills (bare `name` as `hatsu:name`; an
  unresolved token makes the clause prose) and run **under its own authority, gates and grammar**,
  never futon's delegation (§ 7), `@<target>` its argument (getsuga's token, `branch.base` with none; a
  destination otherwise); **`then rikugan`** is § 10's final render — **one render, after the `then`
  outcome exists**, said at the echo ([`rikugan`](../rikugan/SKILL.md) § 6). The typed invocation is the **advance go** of [`mugetsu`](../mugetsu/SKILL.md)
  § 3, not restated — quoted at the echo; a delivery merge is en's,
  and only a **G5 or a halt** ends it. **The gate is the parse's**: a step of a skill
  `futon.advanceGo` lists (`nen/workflow.json`, or nen's default) is refused **unless** it carries
  `gate: allowed: true` — no `gate` or `allowed: false` fails closed — relayed at the echo by its
  `refused: <skill> (<reason>) [default|declared]` line, never re-judged; the rest of the chain runs.
- **`then <prose>`**: Kurapika states which skills and verbs the words map to **before acting**,
  then runs them; fan-out prose maps to getsuga's `CON-22` lane. **Prose never maps to `kagutsuchi`
  or `mugetsu`** — those are typed steps or nothing. Words no skill or verb covers are a **G5
  `DECIDE`** brief, never improvised shell for a Nen-owned operation.

## 9. Reporting — the register, every cycle

**Progress turns carry no banner.** The board is the **Rikugan** register,
rendered via [`backlog-board`](../backlog-board/SKILL.md) § 3: rows are the scope's issues and their
PRs, the desk this cycle's asks. State every cycle the briefed and blocked items,
triage in and out, and every label with its time; notations per
[`PROCESS.md`](../../../docs/PROCESS.md) § *Publishing a report*. A local row's verdict is
`nen pr ready`'s output verbatim; a `CI (legacy)` row is reported, never driven.

**Every gate stop is [`jutaisho`](../jutaisho/SKILL.md) § 4's full four parts**, the register as its
report: **G4/G2** only for a PR the run did not author (its own it merges, en § 5),
**G5** for a build Kurapika cannot do, a stall past the escalation ladder, or a briefed policy call.
**A needed maintainer never stops the whole run** — notify, record, keep
advancing.

## 10. Ending the run

The run ends when **every issue in the selector's scope** is a merged PR (or, legacy-CI,
open with its own actor), or briefed awaiting a decision, or blocked with
its blocker named — **and the `then` clause, if typed, has run or is held at its gate**.

> **A run that ends with one of its own PRs short of merged has not ended — it has stopped.**

Say the run has ended; the delegation lapses. The final report is [`hatsu:rikugan`](../rikugan/SKILL.md)
over this run's scope — its § 2 futon row, the `then` outcome included — **the one render a typed
`then rikugan` is, never a second**; `final` only if every PR merged, else `register` with the asks.
**Futon never resumes itself**; re-invoke it.

## 11. Hard limits

- **Merges only its own PR, at its terminus, through en § 5** (ruling 2026-09-29 (3)); never self-reviews, impersonates a reviewer or casts
  `request_changes`; **never publishes a release itself** — the cut is getsuga's,
  publication mugetsu's; **never cuts without a typed `then`**.
- **Never claims a CI author for a PR it opened**, and never abandons its own at PR-open — it holds
  the slot until merged.
- **Never claims readiness `nen pr ready` + `nen pr body-check` did not give**, quoted.
- **Never exceeds 2 CI-plane objects or 7 local worktrees**; never lets two efforts share a file.
- **Never widens its selector**: a bare severity never carries an implied `+`, and **a label is never
  expanded**.
- **Never applies a G1 mode label.**
- **Never batches the merges** — one merge and report per PR.
- **Never runs `nen release preflight`, `nen fanout compute/record` or `nen shu deploy --run`
  itself** — those stay inside the invoked skill — and reaches `kagutsuchi` or `mugetsu` **only as a
  typed `then` step** (mugetsu § 3) whose parse `gate` reads `allowed: true`, never from prose.
- **Never hand-authors the status board** (§ 9); **never leaves the delegation open**.

*History and residue: this effort's history file; dated verifications: `docs/ab/futon.md`. The label
selector, `then` chain and fail-closed `gate` need nen v0.15.1+ (pin v0.18.1); an older
binary's exit `2` is relayed, never worked around.*
