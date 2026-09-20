---
name: futon
description: Take one whole severity band of a repo's backlog from open issues to PRs that have an actor driving them, then run the terminal step the maintainer typed. Use when the maintainer invokes hatsu:futon <repo>@<severity>[+] [then tag | then tag+fanout], or asks to build all the mediums, work the highs and cut a tag, or clear a severity band. Kurapika scopes backlog-loop's engine to one band; every PR this run produces is his own, because Hatsu carries no CI plane, so done means CON-32 Ready and a per-PR merge prompt. Cuts only on a typed then clause, and the cut itself is getsuga's. Never merges main, never publishes a release.
---

**Shared policy** (`docs/*.md`) lives at the Hatsu plugin root `hatsu-warmup` prints; a missing
consumer copy is never a filing.

# Futon — one severity band, from open issues to PRs with an actor behind them

**No fixed mode.** Futon is a composed run: **Conjurer/Transmuter** (sometimes **Enhancer**) while
an issue is authored — the mode [`build`](../build/SKILL.md) § 3 confirms, per issue — and
**Manipulator** while the PR is driven to its gate. Name the mode; never blend two.

> **Name a severity band; I give it back with every issue in it carrying a PR that is `CON-32` Ready
> and prompted for your merge — then, if you typed a terminal, the cut that follows. Never past G3.**

Per issue, futon is [`build`](../build/SKILL.md) → [`tensho`](../tensho/SKILL.md) →
[`en`](../en/SKILL.md); a `then` clause's terminal goes to [`getsuga`](../getsuga/SKILL.md), never
performed here. **Nothing past the tag is reachable:** [`kagutsuchi`](../kagutsuchi/SKILL.md) never
runs from a composite, and [`mugetsu`](../mugetsu/SKILL.md) is **G3**.

Futon is a **scoped, terminated [`backlog-loop`](../backlog-loop/SKILL.md)**: the engine is that
skill's, and futon wins on three things only — a **severity filter**, an **explicit terminal**, and
**who is behind every PR**.

> **Declared process change.** The retired skill routed issues to a CI lane agent. **Hatsu carries
> no CI plane** — no App, no workflow, no bot identity — so **every issue this run releases, Kurapika
> builds himself**, in the mode § 3 confirms, and done collapses to one rule: `CON-32` Ready,
> prompted (§ 5). **One qualification:** a band can hold a PR opened *before* this run by a CI
> identity of the target's own machinery — detected mechanically, a `[bot]` suffix or `app/` prefix
> on `gh pr view --json author`. It keeps its own done rule (open is its milestone) and occupies the
> **CI** half of § 6's budgets. Futon never creates a new one.

## 1. Invocation

```
hatsu:futon <repo>@<severity>[+] [then tag | then tag+fanout]
```

```bash
nen parse futon --repo <target repo's own checkout> "<the invocation, minus the prefix>" [--self <owner/name>]
```

**`futon` is one of the three grammars `nen parse` ships built in and takes no `--grammar`.** It
resolves the repo token, expands `+`, reads the terminal and enforces the terminal's scope rule in
one call. A refusal is exit `2` with the corrected line ready to paste; take it, never re-parse.

**Echo the full parse before anything is fetched** — repo, band expanded with its severities named,
terminal or *build-only* — and **say the run has started**. A named run holds a bounded `CON-25`
delegation (§ 7); a delegation nobody announced is one nobody can end.

## 2. The queue is the band — and only the band

`nen backlog fetch --repo-slug <owner/name> --json` — never cached, never `--limit`; a capped fetch
is reported **truncated**, never as complete. Then:

- **Select** every issue whose `bankai:severity/*` label is in the band; with `+`, that severity
  **and every severity above it**.
- **Triage the untriaged** as `backlog-loop` § 4 does. **A triaged severity inside the band joins the
  queue; outside it the issue is recorded as triaged-and-out-of-scope and left alone.** Say which,
  every time — a run that silently widened its band is a run whose scope nobody agreed to.
- **`bankai:handbook-question` items and design calls are briefed, never guessed**, and never hold
  the band open.
- **Order within the band** with `nen backlog order`, as `backlog-loop` § 5 does. With `+` the higher
  severity is worked first, and **`critical` pre-empts everything**.

**State the queue before advancing anything** — the count, every issue in it, what was excluded and
why. The band is the run's whole scope; a reader who cannot see it cannot audit it.

## 3. The engine is `backlog-loop`'s, invoked

Triage and briefing, ordering, the monitor and its fetch triggers, conflict discipline (one worktree
per effort, cascading `main`, never two efforts on one file) and the hard limits are that skill's; if
its engine changes, futon changes with it. **Where the retired routing table named CI lane labels,
that label now picks Kurapika's MODE** ([`build`](../build/SKILL.md) § 3): governance/`CON-{n}` or
handbook/schema/agent-def means **Conjurer**, a machinery-only label an existing rule sanctions means
**Transmuter**. An issue carrying none gets a proposal and a `DECIDE` (`CON-37`).

## 4. Releasing into build

```bash
nen label apply <CODE>-IS-#<N> --label bankai:stage/building --repo-slug <owner/name> --reason "<why>" --run
```

**Then Kurapika builds it, this session, in the mode just confirmed** — no wake to verify, no job to
poll. The build runs through the verbs the target declares, as [`build`](../build/SKILL.md)
§ 5 lays them out: `nen shu warmup --branch kurapika/<slug>` (`--dry-run` first, in that effort's own
worktree), `nen shu tools` once on a fresh host, then `nen shu build`/`test`/`lint` — exit `4` quoted
as the lane's seat, exit `5` back to `shu tools`, exit `3` a **G5** naming the host. Work a local
session structurally cannot do is a **G5 immediately**, with the gap named.

## 5. Done is `CON-32` Ready and prompted

> Every PR futon produces is Kurapika's own, so it is **not done at PR-open**. It is done when
> `nen pr ready` **and** `nen pr body-check` both pass, quoted verbatim, and the maintainer has been
> prompted to merge it — and it **holds its slot** until then.

## 6. Two concurrency budgets, counted separately

```bash
nen loop slots --efforts efforts.json --ci-cap 2 --local-cap 7 --json
```

The **CI** plane caps at 2 and frees when the PR **opens** — only the legacy-CI exception populates
it. The **local** plane caps at 7 and frees only when the PR is **Ready and prompted**; every PR this
run authors sits there. **`--local-cap 7` is futon's own policy and must be passed** — nen removed
the local default so a guard is chosen rather than inherited, and omitting it is exit `2`.
`--efforts` resolves against `--repo`'s root, so pass an absolute path from a worktree. **The two
budgets are never traded against each other**: a full local budget is back-pressure. Never let two
efforts touch one file.

## 7. Authority — the same CON-25 delegation, opened and closed out loud

**Futon may** apply `bankai:stage/building` on issues in the band, and `bankai:severity/*` on an
untriaged one with its reasoning, logged. **No Route row and no Wake row** — no CI lane to route to,
no CI builder to wake; a stalled review round on a Kurapika-authored PR is
[`sharingan`](../sharingan/SKILL.md)'s channel, never a label fire.

**Futon may not** apply a G1 mode label (`CON-4`), merge `main` or its own PR (`CON-5`/`CON-7`), cast
any review or `request_changes` (`CON-26`), publish a release (**G3**, `CON-6`), or widen its band —
an out-of-band issue is reported, never worked. Every application is logged: object, label, time.
**Say when the run ends**, so the delegation lapses.

## 8. The terminal — futon gates it; getsuga cuts it

**No `then` clause: there is no terminal.** Do not cut because a band looks finished.

**Futon's own job at the terminal is exactly one gate**: no PR this run authored is short of
`CON-32` Ready (§ 5). Nothing else drives those PRs, so cutting past one is the half-done release a
terminal exists to avoid — hold the cut, name every PR still short with its verdict, keep driving
them. A legacy-CI PR does not hold it.

**Everything else is [`getsuga`](../getsuga/SKILL.md)'s lane** — the whole-repo `critical` check
regardless of band, the `CON-36` live-chore check, an active `RELEASE_HOLD`, `changelog.d/`,
`latest`, the tag and the `CON-22` fan-out, with `nen release preflight` and `nen fanout
compute/record` its own verbs. **`then tag`** hands off for the cut with **fan-out skipped and its
issues left open** — say so, because consumers stay pinned to the previous tag; **`then tag+fanout`**
is the same hand-off with the fan-out. **If the tag capability is refused, HALT and hand the
maintainer the exact command**; never route around a refusal, and this run never writes `latest`
(`CON-14`).

## 9. Reporting — the register, every cycle

**Progress turns carry no banner.** The per-cycle status board is a **Spiritual Message**, rendered
through the register variant, via [`backlog-board`](../backlog-board/SKILL.md) § 3 — no hand-authored
HTML. Rows are the band's issues and their PRs; the desk carries this cycle's asks. State every cycle
the briefed items awaiting a decision, the blocked items and their blockers, what was triaged into
and out of the band, and every label applied with its time. Objects use `<CODE>-<IS|PR>-#<N>` from
`nen ref format`, never memory. A local row's verdict is `nen pr ready`'s output verbatim; a
`CI (legacy)` row is reported, never driven.

**Every gate stop is the full protocol**: `nen stop --who Kurapika --gate <Gn> [--notified]
efforts.md`, the register as an Artifact, ~5 lines of chat, the question through the surface's own
picker. The gates reached are **G4/G2** when a PR this run authored goes `CON-32` Ready (a `MERGE`
ask, one prompt per PR) and **G5** for a build Kurapika structurally cannot do, a stall past the
escalation ladder, or a briefed policy call (`DECIDE`/`DO`, one ⭐). **When the maintainer is needed,
do not stop the whole run** — notify, record, keep advancing.

## 10. Ending the run

The run ends when **every issue in the band** is a PR that is `CON-32` Ready and prompted (or, under
the legacy-CI exception, open with its own actor), or briefed awaiting a decision, or blocked with
its blocker named — **and the terminal, if typed, has run or is explicitly held at its gate**.

> **A run that ends with one of its own PRs short of Ready has not ended — it has stopped.**

Say the run has ended so the delegation lapses. The final report is the **`final` Spiritual
Message** (backlog-board § 3) at `<reports.dir>/<YYYY-MM-DD>-<effort>.html`: the band and every issue
with its plane, every authored PR's verdict verbatim, what was triaged in and out, every label with
its time, the terminal's outcome, and what is on the maintainer's plate. **Futon never resumes
itself** — re-invoke it.

## 11. Hard limits

- **Never merges `main` or its own PR**, never self-reviews, never impersonates a reviewer, never
  casts `request_changes`; **never publishes a release** — G3 is the maintainer's and the cut is
  getsuga's lane; **never cuts without a typed `then` clause**, nor one `nen parse futon` refuses.
- **Never claims a CI author for a PR it opened**, and never abandons one of its own at PR-open — it
  holds its slot until Ready and prompted.
- **Never claims readiness it did not get from `nen pr ready` + `nen pr body-check`**, quoted.
- **Never exceeds 2 CI-plane objects or 7 local worktrees**, and never lets two efforts share a file.
- **Never widens its band**, and never treats a bare severity as if it carried `+`.
- **Never applies a G1 mode label**, inside a run or outside it.
- **Never batches the merge prompts** — one prompt and one gate stop per PR.
- **Never invokes `nen release preflight` or `nen fanout compute/record`**, never runs
  `nen shu deploy --run`, and never reaches `kagutsuchi` or `mugetsu` by any route.
- **Never hand-authors the status board** (§ 9), and **never leaves the delegation open** — the run
  says when it ends.

*History, retired findings and residue moved to this effort's history file; `docs/ab/futon.md` has
the dated verifications.*
