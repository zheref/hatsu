---
name: rikugan
description: Render the FINAL STATE of a just-completed workflow — or any named scope — as a Rikugan page upon delivery. The `final` variant by default (one effort, the desk cleared or the asks still open, one register row per issue and PR the workflow touched with the `nen pr ready` verdict quoted verbatim, spend, legend), `register` on request, through hatsu:backlog-board § 3's render path, written to <reports.dir>/<YYYY-MM-DD>-<effort>.html and published as the surface's artifact. Use when the maintainer invokes hatsu:rikugan [for <CODE>#<N>[,<CODE>#<N>…] | <repo>] [as final|register], types `then rikugan` on a futon run, asks for the final state or the delivery summary, or when any composite reaches its final report. Strictly read-only — never labels, merges, pushes or comments; readiness is the quoted verdict, never the eye's.
---

**Shared policy:** [`PROCESS.md`](../../../docs/PROCESS.md) § *Standalone entry*.

# Rikugan — the final state, seen once, upon delivery

**Nature: Manipulator.** The nature of the work *reported* is stated on the page, never adopted.

> **What did this workflow leave behind — what is Ready, what merged, and what is still on your desk?**

[`spiritual-message`](../spiritual-message/SKILL.md) is the **turn** and the **landing** — what one
request did; **this skill is the state a workflow leaves when it completes** — one effort or one
scope, every object it touched, each with its verdict. The name returned as a skill at `v0.69.0` for
the Rikugan page (`templates/rikugan.html`, the `final` and `register` variants), distinct from its
pre-`v0.42.0` meaning ([`ROSTER.md`](../../../docs/ROSTER.md) § *Rulings of 2026-09-30 — rikugan*).

## 0. Standalone entry

From a composite, skip this: the caller hands over the scope (§ 6). Bare, the contract is
[`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md): **`P1`** `hatsu:ten rikugan`,
unconditionally; **`P2`** the orient line; **`P3` is declined** — the subject is a state, not a delta,
so no base is fetched and `(fetched <sha>)` is never asserted; **`P4`** derives the scope (`S3`/`S4`,
§ 2) from the session's last completed workflow, else from the checkout — the branch's open or merged
PR and the issues its body closes — and asks for it as **free text** only when neither yields one
(row `missing-argument`); **`P5`** declares the entry and the scope's source. The page is terminal in
its own pipeline: the hand-back line says so and names no successor.

## 1. Invocation

```
hatsu:rikugan [for <CODE>#<N>[,<CODE>#<N>…] | for <owner/name>] [as <final | register>]
```

```bash
nen parse rikugan --grammar "for [<scope>] as [<variant:final|register>]" --line "<line>"
```

Verified at nen `0.16.0`: `for HA#171,HA#172 as final` → `scope: HA#171,HA#172 · variant: final`; an
empty line → both `(clause absent)`; `for zheref/hatsu` → the repo, variant absent; `as register` →
scope absent; `for HA#171 as bogus` → exit `2`, *`<variant> is one of final | register`*; a bare
`HA#171` → exit `2`, *the line must open with 'for' to supply <scope>*. Exit `2` **asks, never ends**:
the corrected line goes to the picker and the answer is re-parsed. Default variant **`final`**. A
missing argument or configuration item is asked for and set up inline (`missing-argument`,
`missing-configuration`; [`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 4 *Ask, set up, continue*).

## 2. The scope — the objects the workflow touched, stated with its source

**The first line of every run names the scope and where it came from.** A typed `for` clause always
wins — a comma-separated object list, or a repo whose every open issue and PR is the scope. Untyped,
the scope is **what the session's last completed workflow touched**, read from that run's own record:

| Last completed workflow | The scope |
|---|---|
| [`futon`](../futon/SKILL.md) | the selector's issues, every PR the run authored, triage in and out, the `then` outcome |
| [`build`](../build/SKILL.md) | the issue and its delivery PR |
| [`en`](../en/SKILL.md) | the PR and the issues its body closes |
| [`backlog-loop`](../backlog-loop/SKILL.md) | the cycle's queue, every PR standing at a gate |
| [`getsuga`](../getsuga/SKILL.md) | the release unit: the release-proposal PR, the range's PRs, the tag and the fan-out PRs |
| [`black-voice`](../black-voice/SKILL.md) | the validated PR and the issues it closed |
| none, and none typed | ask for the scope as free text (`missing-argument`) — never the whole backlog by default |

A workflow that **stopped** rather than ended is still a scope: the page then carries its asks
(§ 4). The source is echoed as `scope: HA#171,HA#172 · from: futon zheref/hatsu@bug, ended` or
`· from: typed`. **The scope is read, never remembered**: the run's record and the checkout say what
was touched; the session's impression of it does not.

## 3. Compute the rows — fresh, from the verbs

```bash
nen report data --repo <path> --target <owner/name> --backlog --json          # open objects
nen report data --repo <path> --target <owner/name> --prs <n,...> --json      # the scope's PRs, merged ones included
nen pr ready --repo <path> --pr <N> [--explain]                               # per PR, quoted verbatim
```

`objects[]` filtered to the scope is the register; a scoped object the sweep does not return is
**fetched by number, never dropped** — a merged PR is a row that reads `merged` with its merge SHA, a
closed issue a row that reads `closed` with what closed it. Every PR row's `verdict` is `nen pr ready`'s
output **verbatim** (`readiness{verdict,reason,source}`, [`backlog-board`](../backlog-board/SKILL.md)
§ 2): a PR the sweep marks Ready is still quoted, never summarised. The gate per row is
[`backlog-state`](../backlog-state/SKILL.md)'s classification, unchanged; the labels and their times
are the run's own record. **Nothing is recomputed by eye, and nothing comes from session memory.**

## 4. Render — through backlog-board § 3, by name

The page is [`backlog-board`](../backlog-board/SKILL.md) § 3's render — its data shape, its escaping
rules, its verb — **composed, never restated and never hand-authored**:

```bash
nen report render --variant final --template "$hatsu_root/templates/rikugan.html" \
  --data <the § 3 document> --out <reports.dir>/<YYYY-MM-DD>-<effort>.html --repo <path> [--graph <file>]
```

`$hatsu_root` is set in the block as [`ten`](../ten/SKILL.md) § 0 says; `generatedAtLocal` is
`"$hatsu_root/scripts/report_time.sh"`; the blocks are `reports.sections.final.blocks`
(masthead, tally, desk, register, spend, legend), never a remembered list; the `title` is the effort's
headline ([`WORKFLOW.md`](../../../docs/WORKFLOW.md) § *Report titles*). **`final` is the one render
kept on disk** (`reports.retain: final-only`, ruling 2026-09-19) — the dated file, one per effort,
re-rendered at the same path when the same effort is reported again. **`as register`** renders the
same rows at `<reports.dir>/current.html`, transient, and is what a workflow's *progress* board is;
`final` is for delivery.

**The desk is the point.** A workflow that ended with nothing owed renders `deskCleared`; one that
stopped renders every ask still open — a merge prompt per PR short of merged (`MERGE`), a briefed
policy call (`DECIDE`), a host act only the maintainer performs (`DO`) — grouped by gate, ranked by
unblocking power, each with lettered options and **exactly one star**, the same list the surface's
picker will show. **A gate with nothing owed is rendered cleared, not omitted.** The spend block is the
effort's ledgers ([`spiritual-message`](../spiritual-message/SKILL.md) § 4 builds `spendEfforts[]`);
a graph is optional and only where the scope has a shape worth drawing.

## 5. Publish it, say one line, ring nothing

Published as [`PROCESS.md`](../../../docs/PROCESS.md) § *Publishing a report* says — an **Artifact** on
Claude Code (one URL per effort, headline title), Antigravity's native artifact, the dated file
elsewhere. **Say one line in chat and stop**: the scope and its source, how many rows read `merged`,
`ready`, `open` or `blocked`, what is on the maintainer's plate, the link. **A requested Rikugan is not a
gate event** ([`PROCESS.md`](../../../docs/PROCESS.md) § *Reporting a phase*): no banner, no `nen stop`,
no bell — a composite that owed a bell rang it before this step ([`jutaisho`](../jutaisho/SKILL.md)).

## 6. Where it is reached from

- **Typed**, in any checkout — § 0 runs.
- **A `futon` `then` step**: `nen parse futon` classifies `then rikugan` and `then getsuga+rikugan` as
  `kind: skills` steps (verified at nen `0.16.0`: `steps: [{skill: "rikugan"}]`, and after `getsuga`
  with its own `gate`); `then tag+rikugan` is refused at exit `2` — `tag` is the terminal's own
  vocabulary — so the cut and the page are `then getsuga+rikugan`. The step runs after futon § 8's gate,
  under this skill's own authority, its scope the run's (§ 2), the typed word already the maintainer's.
- **The closing step of a composite** — `en` § 8, `futon` § 10, `backlog-loop` § 10, `getsuga`'s own
  proposal, `build`'s delivery: the caller names it by `hatsu:rikugan`, passes the scope, and this
  skill's § 0 is skipped. It is the dated final report those skills owe; none of them renders it another way.

## 7. When the pipeline cannot run

`nen report render` or `report data` unavailable (nen out of range is `ten`'s D10 contract), or the
sweep failing for its own reasons: **relay it in one line, then fall back to
[`backlog-state`](../backlog-state/SKILL.md)'s markdown table over the same scope**, saying so. Never a
hand-authored page, never a chat recap standing in for the file.

## Residue

1. **The scope derivation has no verb.** Which objects a run touched is read from the run's own
   record and the checkout (`gh pr list --head <branch> --state all`, the PR body's closing lines);
   `nen report data --prs` fetches them once known. Named here so the by-hand read is visible.
2. **`nen report data --backlog` returns open objects only**; a merged PR or closed issue in the scope
   is fetched by number (§ 3). One sweep that takes a scope list is a nen request, not a workaround.

## Authority

**Permitted:** reading the checkout, the run's record, `nen/*.json` and GitHub through the verbs above;
publishing this effort's report artifact; writing `<reports.dir>/<YYYY-MM-DD>-<effort>.html` and
`current.html`. **Not permitted:** any other write on disk, any GitHub write, any delegation
([`PROCESS.md`](../../../docs/PROCESS.md) § *Authority every phase shares*).

## Hard limits

- **Never labels, merges, pushes, comments, opens or closes anything.**
- **Never claims readiness `nen pr ready` did not give**, quoted; an absent verdict reads `not-ready`.
- **Never hand-authors the page**, restates backlog-board § 3's shape, or lets a chat summary stand in
  for the artifact.
- **Never renders from session memory**: every row is a fresh sweep or a fetch by number.
- **Never widens the scope** past the run's record or the typed clause — a bare invocation with no
  completed workflow asks, it never renders the whole backlog.
- **Never fires the banner, `nen stop` or the bell**, and never omits a cleared gate from the desk.
- **Never writes outside `<reports.dir>`**, and never gives a `register` render a dated file.

*Dated live verifications: `docs/ab/backlog-board.md` (the render path); the grammar and futon parses
above, 2026-09-30.*
