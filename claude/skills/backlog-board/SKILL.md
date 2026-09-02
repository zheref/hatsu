---
name: backlog-board
description: Render the current backlog as the Kurapika gate board — the same sweep, arguments and gate assignment as hatsu:backlog-state, painted as one self-contained HTML page published as an Artifact instead of a markdown table. Use when the maintainer asks to see the board, the gate register, or the state as a page, or invokes hatsu:backlog-board <repo|all>@<G1|G1-M|G2|G3|G4|G5|all> [every <turn|state-change|once>] — the optional trailing clause makes the board re-render on every turn or whenever a scoped item's state (including its gate) changes, instead of the once-and-stop default. Strictly read-only — it never labels, merges, pushes, comments or opens anything.
---

# Backlog board — the same board, painted (ex-`RR-IS-#700`)

**Nature: Manipulator.** The board-facing half of the work. Kurapika says so when he runs it.

`hatsu:backlog-state` answers *"what is at my gate right now, and what does each thing need from
me?"* and paints the answer as a markdown table. **This skill answers the identical question with
the identical computation and paints it as an HTML gate board** — a self-contained page published
as an **Artifact**, so the maintainer reads it in the panel he is already in. Formerly
`scripts/ichigo_board.sh`; this is its Kurapika-native successor.

> **One sentence of scope:** `backlog-state` **computes and tabulates**; `backlog-board`
> **computes the same thing and renders it as the page**. There is no third method, no second
> source of truth and no per-surface variant of the data.

> **Read-only, without exception.** Inherited verbatim from `backlog-state`. This skill renders
> state. It never applies a label, merges, pushes, opens, closes or comments. If reading the board
> makes the next action obvious, **say what the action is on the board** — do not take it.

---

## 1. Invocation

```
hatsu:backlog-board <repo name | all>@<G1 | G1-M | G2 | G3 | G4 | G5 | all> [every <turn | state-change | once>]
```

**The `<repo>@<gate>` half is identical grammar to backlog-state's invocation grammar,
deliberately** — the same repo tokens, the same gate tokens, the same case-insensitivity, the same
optional `@`, the same `G1` ⊇ `G1-M` inclusion, and the same rule that **an unknown repo is an
error, never a guess**. Do not restate that grammar here; read it (§ 2 below links the file) and
obey it.

That includes **the no-repo default** — with no repo token the subject is **the repo you are
standing in**, resolved from the working directory's `origin` against `schemas/repos.json`, named
before the board, and an **error** — never a silent widening to `all` — when it resolves to
nothing.

**The trailing `every <…>` clause is this skill's own** — `backlog-state` renders a table, not a
page kept open in front of the maintainer, so it has nothing here to mirror. Omitting the clause
entirely, and writing it out as `every once`, mean the same thing: **`once`** — render, publish,
say the line, stop.

> **`nen parse` can check the `<repo>@<gate>` shape, but not the whole grammar — verified live.**
> This skill's invocation is not one of `nen parse`'s three built-in grammars (`futon`/`izanagi`/
> `izanami`), so it must supply its own `--grammar` template:
> ```
> nen parse backlog-board \
>   --grammar "<repo>@<gate:G1|G1-M|G2|G3|G4|G5|all> [every <freq:turn|state-change|once>]" \
>   --line "BC@G4 every state-change"
> ```
> Run against the real binary, this correctly accepts `BC@G4`, `BC@G4 every state-change`, refuses
> `BC@G9` naming the enumerated values and a corrected line, and refuses a missing gate. **But it
> cannot express two of § 1's own rules**: the grammar mini-language has no way to say "`@` is
> optional, and a bare `all` means `all@all`" or "an omitted repo token resolves to the working
> directory's `origin`" — tested live, a bare `all` line is refused as "gate is required" rather
> than accepted as `all@all`. **This is a finding, not a defect to route around**: those two rules
> stay exactly what backlog-state's invocation grammar already made them — read from prose, applied
> by hand, identically on every invocation — while the enumerated-token and frequency-clause validation
> `nen parse` **does** cover is worth taking, since it replaces one more hand-checked rule with a
> refusal the binary renders and corrects itself.

## 1a. Rendering frequency — `once` / `every turn` / `every state-change`

The frequency clause controls **how many times this session loops through §§ 2–4** for the
invocation's `<repo>@<gate>` scope. It changes nothing about *what* gets computed or how a row is
classified.

- **`once` (default).** Sweep, render, publish, say the line, stop.
- **`every turn`.** Re-run §§ 2–4 — full sweep, full render, republished to the **same** Artifact
  URL (§ 5's reuse rule) — before responding to each of the maintainer's subsequent messages in
  this session, for as long as the scope stays in play. Echo the parsed mode back before the first
  render. After that, a re-render that changed nothing is silent; a re-render that changed
  something gets the one line § 5 already specifies, never a restated summary of the board
  underneath it.
- **`every state-change`.** The same loop, gated on a diff instead of a turn boundary. **This is
  now `nen board diff`'s job, not a by-hand field comparison** — see § 3a. Before the first poll —
  independent of whether that poll finds anything — echo the parsed mode, the interval chosen and
  why, and what counts as a change (exactly the fields `nen board diff` compares: `gate`, `status`,
  `needs`, and a row appearing in or dropping out of the scoped set). Only *after* that echo does
  "nothing moved ⇒ no render, no line, no Artifact write" apply to a poll tick.
- **Both repeating modes borrow `izanami`'s loop discipline** — no iteration cap (nothing here
  writes to GitHub), one line per render and no line when nothing rendered, and the loop lives in
  the session — no background timer, no cron, no deferral primitive.
- **What ends the loop:** the maintainer says stop; the maintainer moves on to something the loop
  isn't scoped to; a fresh `hatsu:backlog-board` invocation, which replaces whatever loop was
  running; or the session itself ending. A rendering-frequency mode is **session-scoped**, never a
  standing one.
- **§ 6 still holds on every repeat, not only the first render.** No banner, no `nen stop`, no
  push notification, on any pass. A **real** stop firing during the loop is never suppressed by it.

## 2. Compute the picture — `hatsu:backlog-state`, unchanged

Follow [`claude/skills/backlog-state/SKILL.md`](../backlog-state/SKILL.md) end to end for
**everything about what the rows are**: the repo set, the fetch (`nen backlog fetch`/`nen backlog
order`), the gate (`nen gate derive` composed with `nen pr ready`'s verdict), status colour (`nen
color status`), synthesized titles, the expected-action line, session · lane, and ordering.

**Nothing about the computation changes because the output is HTML.** If you find yourself
deciding a gate differently because a page has more room than a table, you have started a second
method. `backlog-state`'s rows, once computed, are the **only** input the rest of this skill
touches.

## 3. Map that picture onto `nen board build`'s row shape

`nen board build --repo-slug <owner/name> --rows-from <path>` assembles a `Board` from **already-
computed** rows — verified live (`nen board build --help`): *"a row's gate from `nen gate derive`,
its colour from `nen color status`. `--rows-from` is a JSON array of BoardRow: `{ id, title, refs,
gate, status, needs }`."* It does not fetch, derive a gate, or resolve a colour itself — it only
assembles and echoes back what you already decided in § 2, plus a `repo` / `generatedAt` header.
Confirmed live against the real `<reference-repo>` backlog:

```
$ nen board build --repo-slug <reference-repo> --rows-from boardrows.json --json
{
  "repo": "<reference-repo>",
  "generatedAt": "2026-09-02T00:57:42.267Z",
  "rows": [ { "id": "918", "title": "…", "refs": ["RR-IS-#918", "RR-IS-#939", "RR-IS-#877",
             "RR-PR-#925"], "gate": null, "status": "in_progress", "needs": "…" }, … ]
}
```

Field by field, from a row `backlog-state` already produced:

- **`id`** ← a stable per-effort id (the anchor issue's number is enough).
- **`title`** ← the synthesized title, unchanged.
- **`refs`** ← every object on the row in `<CODE>-<IS|PR>-#<N>` notation (`nen ref format`), as
  **plain strings**. Board build does not carry a `url` or a `state` mark per ref the way the old
  script's `objects[]` did — verified live, `board render`'s output lists the bare strings with no
  links and no ✓/✗/✎ marks. Re-attach the URL and state yourself when you author the HTML in § 4;
  `backlog-state`'s own rows already carry both, so nothing is lost, only re-threaded.
- **`gate`** ← the row's already-decided `G1`/`G1-M`/`G2`/`G3`/`G4`/`G5`/`null` — the **composition**
  of `nen gate derive`'s diff-half (verified live against the real open PR, `BC#925`: touches
  `.github/workflows/`, `scripts/`, `tests/` → `"gate": "G4"`, `"basis": "the diff touches the
  process surface … in a repository whose product is its process, that is a policy change"`) with
  `nen pr ready`'s readiness verdict, per backlog-state's gate-derivation tree. **`gate derive` itself says
  so** — its own `readinessNote` reads: *"This is the diff's half of the derivation only. A pull
  request that is not ready has NO GATE … so compose this with a readiness verdict before putting
  a row in anyone's queue."* `#925` is `not-ready` (`CON-32a`), so the composed gate is `null`
  (in progress), not the `G4` `gate derive` alone would suggest — do not stop at the diff half.
- **`status`** ← `nen color status --present <values> --category status --json`'s `resolved.name`.
  Verified live for the same row: `--present in_progress` resolves `{"name": "in_progress", "emoji":
  "🟠", "label": "In progress", …}` from the target repo's own `schemas/colors.yml` precedence — no
  glyph is hard-coded here or anywhere in this pipeline.
- **`needs`** ← backlog-state's expected-action line, one string, naming the action and its actor.

**One collapsing step `nen backlog fetch` does NOT do for you — a finding, not a missing verb.**
Verified live: three real open issues on `<reference-repo>` (`#918`, `#939`, `#877`) all reference
the **same** open PR (`#925`) and `nen backlog fetch` returns **three separate rows**, one per
issue, each carrying `prNumbers: [925]` — it assembles "an issue plus the PRs that reference it,
or a lone PR", one row **per issue-anchor**, not one row per shared PR. `backlog-state`'s own rule
("an issue and the PRs that serve it are ONE row") still has to collapse these three into one
effort before they reach `board build` — that collapsing is `backlog-state`'s job, inherited by
reference in § 2, and it does not happen automatically inside the fetch.

## 3a. `nen board diff` — the state-change engine

`nen board diff --before <path> --after <path>` is a **field-level diff of two Board snapshots, by
row id** — exactly what § 1a's `every state-change` mode needs, and it replaces the old skill's
"compare status colour, gate and expected action by hand" instruction outright.

Verified live, two ways:

- **A real null-diff.** Diffing a snapshot against itself: `{"rows": [], "changed": false}` —
  nothing to say, nothing to render.
- **A doctored two-snapshot diff**, built from the same 3-row sample above with two rows changed
  (one PR turning `CON-32`-Ready, one issue moving from routed-not-building to building):
  ```
  changed  918: gate '' -> 'G4', status 'in_progress' -> 'ready_g2_g4', needs '…' -> '…'
  changed  936: gate 'G1-M' -> '', status 'ready_g1' -> 'in_progress', needs '…' -> '…'
  ```
  The unchanged row (`937`) is silently absent from the diff — no need to eyeball which of three
  rows moved.

**Untested in this port, noted rather than assumed:** `nen watch until` could in principle drive
the whole poll (its `--command` runs an arbitrary shell command and `--true-pattern` tests its
stdout, so a command chaining fetch → `board build` → `board diff` and matching `"changed": true`
is plausible) but this was not exercised live here, and the loop as specified in § 1a runs directly
under the session's own pacing instead, per `izanami`'s borrowed discipline. Do not assume `nen
watch` composes cleanly with a multi-step pipeline until it has actually been run that way.

## 4. Author the HTML — this is now a skill-authored step, not a verb call

**Finding: `nen board render` does not emit HTML.** Verified live against the real binary —
`nen board --help` lists exactly three verbs, `build` / `render` / `diff`, no fourth, and no
`--format` flag on any of them. `render`'s own help text is explicit: *"Renders a Board … as the
padded-markdown table this port's source repository established."* Run on the exact 3-row sample
above, the output is a plain pipe table with raw status strings (`ready_g1 (G1-M)`, not 🟡) and no
links:

```
<reference-repo> -- generated 2026-09-02T00:57:50.925Z

| Effort              | Refs         | Status (gate)   | Needs        |
| -------------------- | ------------ | --------------- | ------------ |
| Cancelled build …     | RR-IS-#918, …| in_progress     | PR #925 is … |
| Record the ruling …   | RR-IS-#937   | ready_g1 (G1-M) | Routed to …  |
```

The **same 3-row content**, run read-only through the retired `scripts/ichigo_board.sh` (extracted
via `git show v0.11.3:scripts/ichigo_board.sh` into a scratch dir, never written back to
`<reference-repo>`) at the OLD schema it actually consumes, produces a **28,092-byte self-contained HTML
page** — design shell, per-gate desk with ranked `DECIDE`/`DO`/`MERGE` asks, a tally strip, a
legend, a footer, and the identity sprite. `nen board`'s markdown table has none of that: no gate
grouping, no DECIDE/DO/MERGE grammar, no options tables, no tally, no legend, no sprite. The exact
input JSON behind that byte count — the constructed old-schema `board.json` for this 3-row sample —
is embedded in `docs/ab/backlog-board.md` § 2.4, so the claim is independently re-runnable rather
than asserted from a discarded file.

**This is the load-bearing finding of this port.** The old script's whole reason to exist — quoted
in its own header — was that its ~2.8k-token design shell **never changes**, so generating it from
a cached python3 renderer was affordable where hand-authoring it every time was not (measured
there at old-table ≈14,000 bytes/≈3.7k tokens vs. the board's fixed shell ≈10,582 bytes/≈2.8k
tokens). **Nen owns none of that renderer.** There is no verb that turns a Board into HTML, and
this port's own file set (`SKILL.md` + `docs/ab/backlog-board.md` only) forbids shipping a
replacement generator script inside the skill directory. So: **the HTML page is authored directly
by Kurapika, fresh, from `nen board build --json`'s rows, every render** — via the Artifact tool,
loading the `artifact-design` skill first per its own trigger rule, never a cached template kept
between runs. The cost saving the old generator existed for has no home in this port; that is
disclosed here rather than hidden, and the fix — if one is wanted — is a `nen board render --html`
or equivalent verb, which does not exist today.

What still carries over as **judgment**, unchanged from the old skill, now applied while authoring
the page rather than while assembling JSON for a generator to consume:

- **Rows the human must act on go to the desk, grouped by gate, ranked by unblocking power** —
  widest blast radius first, pure hygiene last. A gate with no rows renders **cleared, with a
  note**, never omitted.
- **Rows that need nobody go to `G0`, which sorts last** — real, worth showing, not his.
- **backlog-state's expected-action line is the ask, promoted to a real ask** — leading with its
  kind (`DECIDE`/`DO`/`MERGE`, uppercase, first word), and a `DECIDE` owes `The question:`, lettered
  options and a ⭐ recommendation.
- **The register is every row**, collapsible, one per effort, carrying the evidence `nen` computed
  (readiness objection, colour reason, diff basis) — never restating the row, only backing it.
- **The header carries what the one-line summary carried — every one of these derived, never
  asserted.** `dek` ← the resolved `<repo>@<gate>` scope this render answered, stated as the repo
  set and the gate filter (the same words §1 uses to name it before the board). `live` ← the count
  of rows on the desk, i.e. rows whose gate is the maintainer's (`G1`/`G1-M`/`G2`/`G3`/`G4`/`G5`),
  never rows at `G0`. `tally` ← one count per status/gate band actually present on this render —
  bucket the rendered rows and count each bucket; never a fixed set of buckets restated from a
  previous render. `generated` ← the render's own absolute ISO-8601 UTC timestamp, taken verbatim
  from `nen board build --json`'s `generatedAt`, never a relative string ("3 minutes ago") computed
  by hand.
- **The footer states the old page's shape line, adapted, and derived fresh from these rows —
  never asserted.** The old page's own wording was *"31 rows. 9 close on one tag cut. 6 are one
  merge away. 2 need only you."* — say the same shape for Kurapika's board: `<N>` = the register's
  total row count; "close on one tag cut" = rows whose only remaining blocker is a release/tag;
  "one merge away" = rows blocked on exactly one open, otherwise-`CON-32`-ready PR; "need only you"
  = the same count as `live` above. Every number is counted straight off the rows this render just
  produced, never carried over from a prior render and never estimated.
- **No shipped Kurapika sprite exists yet in this repository** (`hatsu`'s roster carries agent
  definitions, not a pixel-map asset). Render the identity as Kurapika's own text badge — 🟨
  **Kurapika · Manipulator** — rather than inventing or porting an ASCII sprite file this port was
  never given; that is a finding for whoever eventually wants one, not something to fabricate here.

## 5. Publish it

Publish the authored page as an **Artifact**, titled **Gate Register**.

- **Reuse the repo's existing Gate Register artifact — republish to the same URL.** Find it (list
  the user's artifacts) and update in place, so the maintainer keeps one durable address per repo
  that is always current. Publish a new URL only for a repo that has no board yet.
- **Read before you overwrite.** A republish notice, or a `list` showing a version you did not
  publish, means the page moved under you — re-read it first. A republish notice is itself a
  reason to repaint: re-resolve the repo's backlog and render it again, never report what this
  session happens to be holding.
- **Say the one line in chat, and stop.** The repo and gate filter, the count needing him, the
  link. Not a prose summary of the board underneath it.

## 6. This is NOT a gate event — no banner

A board rendered because the maintainer **asked for one** carries **no banner, no `nen stop`, no
push notification** — he is already looking at it. This is the single carve-out from the rule that
a drawn identity is the only "I need you" signal.

- **Requesting a board never suppresses a real stop.** If a gate comes due while he reads it, that
  stop fires normally, with its banner.
- **Rendering a board here is never itself a reason to act.** Read-only means read-only even when
  the page makes the merge obvious.

## 7. When the pipeline cannot run

There is no longer a `python3`-on-the-host failure mode to degrade around — § 4's finding is that
the HTML is authored by Kurapika through the Artifact tool, which carries no such local-runtime
dependency, so that entire old degradation path is retired by this port, not merely relocated.

What can still fail is the **data pipeline** itself: `nen board build`/`render`/`diff` unavailable
because `nen` is missing or out of the pinned range (D10 — `hatsu-warmup`'s contract, not this
skill's to re-litigate), or the underlying `backlog-state` sweep itself failing for any of its own
reasons (§ 2). **Relay the failure in one line, then fall back to `hatsu:backlog-state`'s markdown
table with the same arguments** — never silently render the table as though it were what was asked
for.

**Inside a repeating (`every turn` / `every state-change`) loop, the same failure ends the loop —
it does not retry blind.** Relay it once on the pass it happened, fall back to the markdown table
for that one pass, and stop.

## 8. What this skill must never do

Everything in `backlog-state`'s own "never" list, verbatim — plus:

- **Hand-author a cached HTML template kept between runs.** § 4 authors the page fresh from `nen
  board build`'s JSON every time; it does not stand up a shim file this port's scope forbids.
- **Publish a board whose rows came from session memory** rather than a fresh `backlog-state`
  sweep, on the first render or any repeat.
- **Fire the banner, `nen stop`, or a push notification** for a board that was requested, including
  every re-render a repeating mode produces.
- **Silently substitute the markdown table** when the pipeline failed, without saying so.
- **Diverge from `backlog-state`'s grammar or classification** while advertising them as the same.
- **Skip `nen board diff` and re-derive "what changed" by eye** in `every state-change` mode — that
  is exactly the by-hand comparison § 3a exists to retire.
- **Run a repeating mode with no stated pace, no echoed frequency, or no visible way to end it.**
- **Carry a rendering-frequency loop past the session it was started in**, or promise a persistence
  this skill was never given.
- **Invent a Kurapika sprite or port the old Ichigo pixel map** — neither exists in this
  repository; say so (§ 4) rather than fabricating one.
