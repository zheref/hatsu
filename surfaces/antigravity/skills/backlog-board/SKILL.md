---
name: backlog-board
description: Render the current backlog as the Kurapika gate board — the same sweep, arguments and gate assignment as /backlog-state, painted as a Rikugan page by nen report render --variant register instead of a markdown table. Use when the maintainer asks to see the board, the gate register, or the state as a page, or invokes /backlog-board <repo|all>@<G1|G1-M|G2|G3|G4|G5|all> [every <turn|state-change|once>] — the trailing clause makes the board re-render on every turn or whenever a scoped item's state changes, instead of the once-and-stop default. This skill also owns the render path futon, backlog-loop and the dated final report use. Strictly read-only — it never labels, merges, pushes, comments or opens anything.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

**Shared policy** (`docs/*.md`) lives at the Hatsu plugin root `hatsu-warmup` prints; a missing
consumer copy is never a filing.

# Backlog board — the same board, painted

**Nature: Manipulator.** The board-facing half of the work.

[`backlog-state`](../backlog-state/SKILL.md) answers *"what is at my gate right now, and what does
each thing need from me?"* as a markdown table. **This skill answers the identical question with the
identical computation and paints it as a Rikugan page.** There is no third method and no
second source of truth.

> **Read-only, without exception.** Inherited verbatim from `backlog-state`. If reading the board
> makes the next action obvious, **say what the action is on the board** — do not take it.

## 1. Invocation

```
/backlog-board <repo | all>@<G1 | G1-M | G2 | G3 | G4 | G5 | all> [every <turn | state-change | once>]
```

```bash
nen parse backlog-board \
  --grammar "<repo>[@<gate:G1|G1-M|G2|G3|G4|G5|all>] [every <freq:turn|state-change|once>]" --line "<the invocation>"
```

**The `<repo>@<gate>` half is `backlog-state`'s grammar, deliberately** — same tokens, same
case-insensitivity, same optional `@`, same `G1 ⊇ G1-M` inclusion, same rule that **an unknown repo
is an error, never a guess**. Read it there; do not restate it. Two rules live in prose because the
grammar cannot say them: an absent `@<gate>` means **`all`**, and an omitted repo token is **the
repository you are standing in**, resolved from the working directory's `origin` — an error, never a
silent widening to `all`, when it resolves to nothing.

## 1a. Rendering frequency

The clause controls **how many times this session loops through §§ 2–4** for the scope. It changes
nothing about what is computed.

- **`once` (default, and what an omitted clause means).** Sweep, render, publish, say the line, stop.
- **`every turn`.** Re-run §§ 2–4 before each subsequent maintainer message, republished to the
  **same** URL. Echo the parsed mode before the first render; afterwards a re-render that changed
  nothing is silent.
- **`every state-change`.** The same loop gated on `nen board diff` (§ 2a), never on a by-hand field
  comparison. Before the first poll, echo the mode, the interval and what counts as a change —
  exactly the fields `board diff` compares: `gate`, `status`, `needs`, and a row entering or leaving
  the scoped set. Only after that echo does *nothing moved ⇒ no render, no line* apply.
- Both repeating modes borrow [`izanami`](../izanami/SKILL.md)'s loop discipline: no iteration cap
  (nothing here writes), one line per render, and the loop lives in the session — no timer, no cron.
- **What ends it:** the maintainer says stop, moves on, invokes this skill again, or the session
  ends. A frequency mode is **session-scoped**, never standing.

## 2. Compute the picture

Follow [`backlog-state`](../backlog-state/SKILL.md) end to end for **everything about what the rows
are**: the repo set, `nen backlog fetch` / `nen backlog order`, the gate (`nen gate derive` composed
with `nen pr ready`'s verdict), status colour (`nen color status`), the expected-action line, session
· lane, and ordering. **Nothing about the computation changes because the output is HTML.** Deciding
a gate differently because a page has more room is a second method.

Then take the object rows from the verb that owns them:

```bash
nen report data --repo <path> --target <owner/name> --backlog --json
```

`objects[]` is one row per open issue and pull request:
`{ kind, number, title, url, state, labels[], head, mergeStateStatus, checks{}, threads{},
reviewRequests[], linked[], readiness{verdict,reason,source} }`, with `readiness` read from the head
SHA's `readiness` check where there is one, else computed from the in-process gate, else `null` with
the reason on stderr. `nen board build --repo-slug <owner/name> --rows-from <path>` assembles the
same rows into a `Board` for the diff; it fetches nothing and derives nothing itself.

## 2a. `nen board diff` — the state-change engine

`nen board diff --before <path> --after <path>` is a **field-level diff of two Board snapshots by row
id**, and it is what `every state-change` runs on. A null diff is `{"rows": [], "changed": false}`;
unchanged rows are silently absent. A malformed snapshot is **refused at exit `2` naming the file,
row and field**, never diffed — that is a caller bug in the § 2 mapping, so fix the row and re-run.

**`nen watch until` cannot drive this poll.** Its `--command` is spawned with no shell, and a fetch →
`board build` → `board diff` chain is three programs, so it has no single command to classify (a
pipeline classifies `[unknown]` and refuses). The loop runs under the session's own pacing.

## 3. Render — the Rikugan, never hand-authored HTML

**There is no by-hand HTML step any more.** The page is
[`templates/rikugan.html`](../../../../templates/rikugan.html), filled by the verb:

```bash
nen report render --variant register --template templates/rikugan.html \
  --data <the data document> --out <reports.dir>/current.html --repo <path> [--graph <file>]
```

The variant's blocks come from `reports.sections.register` in `nen/workflow.json`
(masthead, tally, desk, register, spend, legend), injected as presence flags before the fill. The
data document is § 2's `objects[]` ∪ `nen board build`'s rows ∪ the desk asks you compose:

```
{ variant, title, scope, gate, generatedAt, footerNote, footerCount,
  tallyScope, tallyNeedsYou, tallyBlockers, tallyReady, tallyInFlight,
  gates[{ gate, label, cleared, asks[{ kind: DECIDE|DO|MERGE, rank, title, why, verdict,
          options[{letter,label,command,consequence,star,starredClass}], objects[{label,url}] }] }],
  objects[ <a § 2 row> ∪ { notation, marks, gate, gateClass, verdict, needs, session, lane, thought,
                           labelsLine, checksLine, threadsLine, linkedLine, head,
                           notes: string[] } ],
  architectureCaption, graphJson, graphMermaid, graphNodes[], graphEdges[],
  spendEfforts[{name, usage, note, phases[{lane,percent,amount}]}], legendRows[{mark,meaning}] }
```

Every key is always present, empty where there is nothing: a token the data has not got is exit `2`
by design, because a blank cell in a published register reads as a fact. The four `…Line` strings are
flattened for display, so an issue row and a PR row carry the same keys; `notes` is the row's free
lines and is `[]`, never absent, when there are none. `spendEfforts[].note` is `not reported` where
no ledger was read. `notation` is `nen ref format`'s output — **never typed from
memory**; on a repository with no `nen/repos.json` it falls back to `<owner>/<name>#<n>` and the
failed resolution goes into `footerNote`.

**The desk is the board's point.** Asks grouped by gate then ranked by unblocking power, each opening
`DECIDE`, `DO` or `MERGE`, each carrying lettered options with **exactly one star** — the same list,
same order, same letters the surface's own picker will show. **A gate with nothing owed is rendered
cleared, not omitted.** The page briefs; the picker asks.

**Three validations escaping cannot do stay this skill's**, run before the document is handed to the
verb: a capture source against `^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$`, a bar
percentage against `^(100|[0-9]{1,2})(\.[0-9]+)?$`, and **every `url` field** — `objects[].url`,
`gates[].asks[].objects[].url` — against `^(https?://|mailto:|#|/)`. Escaping makes a `javascript:`
href harmless as text and as nothing else. **A failing value is dropped and named in *Not
delivered***, never rendered.

**A drawing is optional.** Where the scope has a shape worth seeing — a chore's PR graph, an epic's
child tree — author a `nen.report.graph/v0.1` document and pass `--graph`; the template draws it and
keeps the node and edge list under `<details>` as the fallback. Leave `graphNodes` empty otherwise
and the block does not render.

### The other callers of this path

[`futon`](../futon/SKILL.md) and [`backlog-loop`](../backlog-loop/SKILL.md) render their per-cycle
status board through this exact line, **the register variant, via backlog-board § 3**. The **dated
final report** is the same template at `--variant final`: one effort, a cleared desk, written to
`<reports.dir>/<YYYY-MM-DD>-<effort>.html` (maintainer's ruling, 2026-09-19). That is the one render
of this template that is kept on disk.

## 4. Publish it

Publish as an **Artifact**, titled *Gate Register*, **republished to the same URL per repository** —
find the existing one and update in place; a new URL only for a repository with no board yet. **Read
before you overwrite**: a republish notice, or a listing showing a version this session did not
publish, means the page moved, so re-read it and re-resolve the backlog rather than repainting what
this session happens to be holding.

**Say the one line in chat and stop** — the repo and gate filter, the count needing him, the link.
Not a prose summary of the board underneath it.

## 5. Not a gate event

A board rendered because the maintainer asked for one carries **no banner, no `nen stop`, no push
notification** — he is already looking at it. That holds on every repeat, not only the first render.
A real gate coming due while he reads it fires normally; rendering never suppresses one, and a board
that makes the merge obvious is still not a reason to act.

## 6. When the pipeline cannot run

`nen report render`, `board build` or `board diff` unavailable (nen missing or out of the pinned
range — `hatsu-warmup`'s D10 contract, not this skill's to re-litigate), or the `backlog-state` sweep
failing for its own reasons: **relay it in one line, then fall back to `backlog-state`'s markdown
table with the same arguments**, saying that is what happened. Inside a repeating loop the same
failure **ends the loop** — one fallback pass, then stop; it never retries blind.

## Hard limits

Everything in `backlog-state`'s own never-list, verbatim, plus:

- **Never hand-authors the page.** § 3 is a verb call over a fixed template; a hand-filled page and a
  rendered one are not the same bytes and only one is checkable.
- **Never publishes a board whose rows came from session memory** rather than a fresh sweep, on the
  first render or any repeat.
- **Never fires the banner, `nen stop` or a push notification** for a requested board.
- **Never silently substitutes the markdown table** when the pipeline failed.
- **Never diverges from `backlog-state`'s grammar or classification** while advertising them as one.
- **Never re-derives "what changed" by eye** in `every state-change` mode (§ 2a).
- **Never runs a repeating mode with no stated pace, no echoed frequency or no way to end it**, and
  never carries one past the session it started in.
- **Never omits a cleared gate from the desk**, and never renders an ask without a starred option.
- **Never writes outside `<reports.dir>`**, and never gives a `register` render a dated file — only
  `final` gets one.
- **Never labels, merges, pushes, comments, opens or closes anything.**

*History, retired findings and verified-live transcripts moved to this effort's history file;
`docs/ab/backlog-board.md` has the dated live verifications.*
