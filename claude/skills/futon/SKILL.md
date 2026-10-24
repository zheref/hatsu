---
name: futon
description: Work one severity band or exact backlog label into delivery PRs, then run the typed then chain. Use for hatsu:futon <repo>@<selector> [then ...]. Record stacked delivery ownership for En’s bounded Ready-only merge. Main-bound merges remain the maintainer’s; release publication belongs to Mugetsu.
---

**Shared policy:** [`PROCESS.md`](../../../docs/PROCESS.md) § *Standalone entry*.

# Futon — one selector, from open issues to PRs with an actor behind them

**No fixed mode**: the mode [`build`](../build/SKILL.md) § 3 confirms per issue while authoring,
**Manipulator** while the PR is driven to its gate. Name it; never blend.

Per issue, futon is [`build`](../build/SKILL.md) → [`tensho`](../tensho/SKILL.md) →
[`en`](../en/SKILL.md), cut short by an integration branch (§ 5).

Futon is a **scoped, terminated [`backlog-loop`](../backlog-loop/SKILL.md)**: a **selector**, an
**explicit `then`**, and **who is behind every PR**.

> **Hatsu carries no CI plane** ([`WORKFLOW.md`](../../../docs/WORKFLOW.md) § *Building an issue
> with no CI plane*): **Kurapika builds every issue.**

## 1. Invocation

**P1 — `hatsu:ten futon` opens this run** ([`ten`](../ten/SKILL.md) § 6).

```
hatsu:futon <repo>@<severity>[+] [--idle [--dry-run]] [then tag | then tag+fanout | then <skill>[@<target>][+<skill>[@<target>]…] | then <prose>]
hatsu:futon <repo>@<label>       [--idle [--dry-run]] [then ...]
```

```bash
nen parse futon --repo <target checkout> "<invocation, minus the prefix and a --dry-run>" [--self <owner/name>]
```

**`futon` is a built-in `nen parse` grammar** — one call resolves the repo,
reads the **selector**, classifies `then` (§ 8) and enforces a terminal's scope rule. A severity name
(`critical`, `high`, `medium`, `low`) is a **band**, `+` that severity **and above**; **any other token
is a label**, matched as `nen parse futon --help` says and **never expanded**, a lifted `--dry-run` said at the echo. **Exit `2` asks, never ends**: the corrected line, if any, goes to the picker, the answer is re-parsed, a missing argument or
configuration item set up inline (`missing-argument`, `missing-configuration`). **A re-parsed answer never carries a `then`
step**; the maintainer retypes it. **The selector
is the maintainer's word: never derived.**

**Echo the full parse before anything is fetched** — repo, selector, the `then` clause as classified or
*build-only*, the integration branch if one is cut — and **say the run has started** (a bounded `CON-25`
delegation, § 7).

Before PR-open, run WORKFLOW § *Recorded Futon delivery ownership* `start`: it opens nen's run
manifest under its run ID (HA#154, HA#423). After every PR this run opens, whatever its base, `nen run append`.

## 2. The queue is the selector's scope — and only that

`nen backlog fetch --repo-slug <owner/name> --json` — never cached or `--limit`ed; a capped fetch
reads **truncated**. Then:

- **Select** — by band: every issue whose `bankai:severity/*` label is in the band; with `+`, that
  severity **and every severity above it**. By label: **every open issue carrying that exact label**,
  whatever its severity.
- **Triage the untriaged** as `backlog-loop` § 4 does. Under a band, **a triaged severity inside it
  joins the queue; outside, it is recorded out of scope.** Under a
  label, triage **orders only, never selects**. Say which, every time.
- **`bankai:handbook-question` items and design calls are briefed, never guessed**, and never hold
  the scope open.
- **Shape** (HR-4): `build` § 2's check per selected issue. **Nothing blocks the batch** (`R-2026-10-23-02`):
  an open or unread `OQ-{n}` row skips the issue, parked `needs-clarification` (`g5-shape-unread`), the
  queue continuing; a miss is listed, never skips (WORKFLOW § *Idle batches* rule 9).
- **Order within the scope** with `nen backlog order` (§ 3).

**State the queue before advancing anything** — count, issues, exclusions and why.

## 3. The engine is `backlog-loop`'s, invoked

Triage and briefing, ordering, the monitor and its fetch triggers, conflict discipline and the hard
limits are its. **A CI-lane label picks Kurapika's MODE**
(`build` § 3); an issue carrying none gets a proposal and a `DECIDE` (`CON-37`).

## 4. Releasing into build

```bash
nen label apply <CODE>-IS-#<N> --label bankai:stage/building --repo-slug <owner/name> --repo <target checkout> --reason "<why>" --run
```

No stage family (`nen stage check` exit `2`) → the label is skipped, said (WORKFLOW § *A target
repository with no delivery-stage taxonomy*); an unloadable `nen/labels.json` is a G5. **Then Kurapika builds it, in this session and the mode confirmed**, through the verbs the target
declares as `build` § 5 lays them out, in the effort's own worktree; work a local session cannot do is a **G5**, gap named.

## 5. Done is merged into `branch.base`

> **Not done at PR-open, nor at Ready**: the maintainer merges at en § 5's prompt (ruling 2026-09-30;
> "main" reads as `branch.base`).

**An integration branch** takes hanten-settled efforts by local merge, no sub-PR or
`gh pr merge` (ROSTER § *Rulings of 2026-09-30*). The other shape is stacked per-issue
PRs, default on overlap — `nen wc overlap`'s verdict, cited, once branches exist (WORKFLOW § *Stacked pull requests*); the maintainer picks.

Before En, bind and verify each stacked delivery PR, refreshing after head changes
(WORKFLOW § *Recorded Futon delivery ownership*, #154).
Never record a main-bound or integration PR.

## 6. Two concurrency budgets, counted separately

```bash
nen loop slots --from-run <run id> --target <owner/name> --ci-cap 2 --local-cap 7 --repo <target checkout> --json
nen loop slots --efforts <abs path> --ci-cap 2 --local-cap 7 --repo <target checkout> --json
```

Both counted, summed: delivery PRs from the manifest, and the claimed efforts with none or merged only locally (WORKFLOW § *Idle batches* rule 4).

The **CI** plane (legacy-CI PRs only) caps at 2, frees at PR-open. The **local** plane caps
at 7 and frees at **`ready+prompted`** (PR Ready, prompt shown); a claimed effort with no PR holds its slot till then or its local merge (`monitor.localSlotFrees`, `R-2026-10-23-20`, WORKFLOW § 2). **`--local-cap 7` is futon's own policy,
always passed**; omitted, exit `2`. **The budgets are never traded**: a full local one is back-pressure.

## 7. Authority — the CON-25 delegation

**Futon may** apply `bankai:stage/building` on issues in scope, and `bankai:severity/*` on an
untriaged one with its reasoning, logged: object, label, time. **No Route or Wake row**; a stalled
review round is `sharingan`'s channel, never a label fire. **The typed line
is the publish call** for each effort's branch (aka § 0, HR-20). **Futon may not** do what § 11 forbids; out-of-scope work is reported, never worked. **Under `--dry-run` none of §§ 4–7's acts run** (WORKFLOW § *Idle batches* rule 7).

## 8. The `then` clause — futon gates it, never performs it

**No `then` clause, nothing after the run** (§ 11). The clause starts at the first whole-word `then` after `@`; a bare `then` is exit `2`.

**Futon's own job at the clause is exactly one gate**: nothing after `then` runs until every PR this
run authored — `nen run verify --id <run id> --target <owner/name>`, never memory; an exit other than `0` holds it — is **merged into `branch.base`** (§ 5) — an integration-branch effort once the
integration PR merges. Till then hold it, keep each merge prompt standing on the register desk (mugetsu § 3), every
PR still short named with its verdict. A legacy-CI PR does not hold it. Then, as `nen parse futon`
classified it:

- **`then tag` / `then tag+fanout`** (`terminal`) go to [`getsuga`](../getsuga/SKILL.md) under its rules:
  fan-out only with `+fanout`, said; a refused tag capability **HALTS** with the exact command; never `latest` (`CON-14`).
- **`then <skill>[@<target>][+…]`** (`kind: skills`) run **in order**, each resolved against the
  installed skills (an unresolved token makes the clause prose) and run
  **under its own authority, gates and grammar**, never futon's delegation (§ 7), `@<target>` its
  argument (getsuga's token, `branch.base` with none; a destination otherwise); **`then rikugan`** is
  § 10's final render — **one render, after the `then` outcome**, said at the echo (`rikugan` § 6). The typed invocation is the **advance go** of
  [`mugetsu`](../mugetsu/SKILL.md) § 3, quoted at the echo; a merge into `main` is the
  maintainer's, and only a **G5 or a halt** ends it. **The gate is the parse's**: a step `futon.advanceGo` lists runs only with `gate: allowed: true`, else fails closed, its `refused:` line relayed at the echo, never re-judged; the rest of the chain runs.
- **`then <prose>`**: Kurapika states which skills and verbs the words map to **before acting**,
  then runs them; fan-out prose maps to getsuga's `CON-22` lane. **Prose never maps to `kagutsuchi`
  or `mugetsu`** (§ 11). Words no skill or verb covers are a **G5
  `DECIDE`** brief, never improvised shell.

## 9. Reporting — the register, every cycle

**Progress turns carry no banner.** The board is the **Rikugan** register, via [`backlog-board`](../backlog-board/SKILL.md) § 3: rows are the scope's issues and their
PRs, the desk this cycle's asks. State every cycle the briefed and blocked items,
triage in and out, and every label with its time. A local row's verdict is
`nen pr ready`'s output verbatim; a `CI (legacy)` row is reported, never driven.

**Every gate stop is [`jutaisho`](../jutaisho/SKILL.md) § 4's full four parts**, the register as its
report: **G4/G2** at en § 5's prompt per PR into `branch.base`, **G5** for what Kurapika cannot do.
**A needed maintainer never stops the whole run** — notify, record, keep advancing.

## 10. Ending the run

The run ends when **every issue in the selector's scope** is merged into `branch.base` — none stranded (en § 6) — (or, legacy-CI, open with its own actor), or briefed awaiting
a decision, or blocked with its blocker named — **and the `then` clause, if typed, has run or is
held at its gate**. Under `--idle`, § 12: it ends at `idle.terminal`, efforts `parked:<row>`, render `register`.

Say the run has ended; the delegation lapses. The closing report lists each skipped issue's open `OQ-{n}`
rows and ends **offering**, never starting, the open-question flow (WORKFLOW § *Idle batches* rule 9). The final report is [`hatsu:rikugan`](../rikugan/SKILL.md)
over this run's scope — its § 2 futon row, the `then` outcome included (§ 8's one render); `final` only if every PR merged, else `register` with the asks. Then the
**wrap-up picker** ([`cleanup`](../cleanup/SKILL.md) § 2, row `wrap-up`). **Futon never resumes itself**; re-invoke it.

## 11. Hard limits

- **Futon itself merges only locally into its own integration branch** (§ 5); En's recorded-ownership
  delivery exception is `en` § 5 and never reaches `main`;
  never self-reviews, impersonates a reviewer or casts `request_changes`; **never publishes a release
  itself** — the cut is getsuga's, publication mugetsu's; **never cuts without a typed `then`**.
- **Never claims a CI author for a PR it opened**, never abandons its own at PR-open (§ 5), never claims readiness `nen pr ready` + `nen pr body-check` did not give.
- **Never exceeds 2 CI-plane objects or 7 local slots**; never lets two efforts share a file concurrently.
- **Never widens its selector** (§ 1).
- **Never applies a G1 mode label.**
- **Never batches the merges** — one merge and report per effort.
- **Never runs `nen release preflight`, `nen fanout compute/record` or `nen shu deploy --run`
  itself**, and reaches `kagutsuchi` or `mugetsu` **only as a typed `then` step** whose parse `gate`
  reads `allowed: true`, never from prose (§ 8).
- **Never hand-authors the status board** (§ 9); **never leaves the delegation open.**

## 12. `--idle` — the unattended profile (HR-5)

WORKFLOW § *Idle batches* is the protocol (ruling 2026-10-23; pre-answers via `nen stop answer`), `--dry-run` its rehearsal; every decision taken for you is listed (rule 8). Never `main`, `getsuga`, `mugetsu` or `kagutsuchi`.

*Residue: PROCESS § Residue; `docs/ab/futon.md`.*
