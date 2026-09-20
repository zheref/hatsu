---
name: jutaisho
description: Ring the bell at the end of a turn — the three escalation rungs from nen/workflow.json (a push notification through the surface, an OS notification, an audible cue), the .nen/last-stop.json marker the Stop hook reads, and the in-session fallback where no hook is installed. Use when /ren reaches its sixth step, when /en reaches Ready, or when the maintainer invokes /jutaisho [at <gate>]. An ordinary turn rings rung 1 only, a turn that did nothing rings nothing, and a genuine gate gets all four parts of § 4 — the nen stop banner, the report link, lettered options with a star on the recommended decision, and the question through the surface's own option picker. Never prompts for /aka.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

# Jutaisho — the bell

**Nature: Manipulator.** Signalling decides whether the maintainer's attention is spent.

> **When the turn is over, tell me — and only actually interrupt me when it is mine.**

The **last** step of [`ren`](../ren/SKILL.md)'s turn and the step [`en`](../en/SKILL.md) fires at
Ready: the only place in the local plane allowed to make a noise, and **a bell that rings every turn
is a bell nobody hears.**

## 0. Standalone entry

[`docs/STANDALONE-ENTRY.md`](../../../../docs/STANDALONE-ENTRY.md) § 4 lists jutaisho as already total,
so cold entry adds only **P1** ([`hatsu-warmup`](../hatsu-warmup/SKILL.md)), shared policy resolved at
the plugin root as that skill's § 0 says. A standalone call also says **whether anything happened**:
ring for a gate a run actually reached, and over a quiet checkout say the bell has nothing to announce
rather than ringing to prove the skill works. **This phase is terminal** — the successor to a gate is
the maintainer's own decision, named in the options and never prompted for again.

## 1. Invocation

```
/jutaisho [at <G1 | G1-M | G2 | G3 | G4 | G5>]
nen parse jutaisho --grammar "at [<gate:G1|G1-M|G2|G3|G4|G5>]" --line "<the invocation, minus the prefix>"
```

An empty `--line` and a bare `at` parse identically, both exit `0` with `gate: (clause absent)`; a
grammar carrying a **required** slot still refuses an empty line at `2`. **The clause's absence is
meaningful, not a default**: no `at <gate>` is a **turn bell**, nothing asked and no banner; with a
gate it is a **stop** and § 4's whole shape is owed.

| The run | Rungs that fire |
|---|---|
| **An ordinary turn** — no `at <gate>` | **rung 1 only** — the surface's own turn-end line |
| **A repository that asks for more** (`notifications.turn: "all"`) | every rung in `notifications.rungs` |
| **A gate** — `at <gate>` present | every rung in `notifications.rungs`, plus § 4's banner |

**Rung 1 is a line in a transcript the maintainer is already reading; rungs 2–3 take over the
machine**, so the only way an ordinary turn rings 2–3 is a repository saying so by name. **"A turn
that needs nothing" is narrow** — no `at <gate>` **and** nothing to say, no commit, no report
rendered, no step refused — and that turn rings *nothing at all*, not even rung 1.

## 2. The three rungs — `nen/workflow.json` → `notifications`

| Key | Meaning | Default when absent |
|---|---|---|
| `notifications.rungs` | which rungs **may** fire, in order | `["push", "os", "sound"]` |
| `notifications.sound` | the macOS system sound for rung 3 | `Glass` |
| `notifications.turn` | how loud an ordinary turn is: `"rung1"` or `"all"`, a **closed set** validated by `nen schema check` and refused by pointer on anything else | `"rung1"` |

| Rung | What it is | Who fires it |
|---|---|---|
| **1 · `push`** | the *surface's* own turn-end notification | the harness, or this skill through the surface; **never nen** |
| **2 · `os`** | an OS notification, title plus one line | the `Stop` hook off § 3's marker; § 5 in-session where there is none |
| **3 · `sound`** | an audible cue, `notifications.sound` | the same |
| — | the banner and efforts table | `nen stop` (§ 4) |

- **A rung the workflow does not list does not fire** — a configuration, reported as configured.
- **`rungs` and `turn` are different questions**: `rungs` says which exist here at all, `turn` how
  many an *ungated* run may use. `turn` can only **withhold**, never conjure, and a gate rings
  everything `rungs` lists regardless of it.
- **nen fires none of rungs 1–3** and only reports rung 1, so **`--notified` is a claim about what
  this skill already did** — passed only after rung 1 went out.
- **nen's own numbering calls the banner rung 4**; the two compose, and "rung 2" means the OS
  notification both ways.
- **`HATSU_ATTENTION=off` rings rungs 2 and 3 nowhere** and still consumes the marker.

## 3. The marker — `.nen/last-stop.json`

Rungs 2 and 3 are fired by the harness `Stop` hook, and **the skill writes the marker; the hook reads
it, fires, and removes it.** **The marker is written only when rungs 2–3 are actually owed** — a gate,
or `notifications.turn: "all"` — because a marker on disk is a request to interrupt.

```bash
nen stop --who Kurapika --gate <gate> --notified --mark \
  --title "<one short line — what happened>" --body "<one line — the ask>" \
  --report-url "<the spiritual-message report's link>" \
  --options <options.json> [--propose-issue <issue.json>] <efforts.md>
```

**From nen `0.11.0` the marker is nen's file** (`nen.stop.mark/v0.2`, its fields the verb's own, one
`options[]` entry `recommended`); the hand-written `hatsu.stop-marker/v0.1` shape is still read and
**never written again**. `sound` and `rungs` are not in it — the hook reads them from
`nen/workflow.json` — and `nen stop show` validates a marker while `nen stop clear` consumes one where
there is no hook.

- **`.nen/` is git-ignored**, and the marker is the only file this skill writes anywhere.
- **A marker older than 10 minutes is stale**, decided from **mtime** and removed without firing, so
  **the marker is written whole, in the turn it describes** — never amended, never carried over.
- **`who` is the persona**, never the name the surface introduced itself as.
- **One marker, overwritten**: no queue, because a backlog of notifications is what this skill
  prevents.
- **The hook is `hooks/hooks.json`'s**, a harness file this skill never edits and never installs.

## 4. A stop — the four parts, all four or it is not a stop

**1 · The `nen stop` banner and efforts table.**

```bash
nen stop --who Kurapika --gate <G1|G1-M|G2|G3|G4|G5> --notified <efforts.md>
```

`<efforts.md>` is a markdown pipe table; `nen stop --template` emits the blank five-column shape
(`Effort | Open issues & PRs | Status (gate) | Thought flow | Session / lane`). Pass `--notified`
**only if rung 1 actually fired**.

**2 · The report link — always, everywhere, never an option**: the banner line, the chat line, the
marker's `reportUrl` and the OS notification body. A report is read, not decided, so the picker lists
only decisions that move the workflow. **And the page must actually explain this stop**:
[`spiritual-message`](../spiritual-message/SKILL.md) rendered it at `ren` step 5, and before the link goes in, **verify
the rendered HTML carries the readable `#g5-blocker` content spiritual-message § 4 specifies**
(zheref/hatsu#56). Lacking it, re-render through spiritual-message with `blocker` filled and verify again;
**never hand off a link whose page does not explain the stop.** The stop never restates the page.

**3 · Crazy Slots — lettered options, at least three, ⭐ on the recommended decision.** Composed by
the model from the session's context and the workflow's state, **seeded by the matching row's
`preferred[]` in `nen/decisions.json`** and never limited to it. Every option is an executable act
with its exact command line and its consequence — never a mood, never the report. Exactly one carries
the star, and the line says what would tip it. **Every real stop also carries a proposed process
issue** (`--propose-issue`, Netero's completeness shape) so the next session does not hit the same
stop; the third-hand harvest picks it up. *"⭐ A — carry the tree onto the branch (`nen shu warmup
--carry`)", "B — take side `ours` on `src/session.ts`", "C — stop here and hand it back."* **A
condition whose row is `autonomous` never reaches this part**: it was resolved by its default, and the
turn page says so with the row id.

**4 · The question through the surface's own option picker** — Claude Code **AskUserQuestion**, Codex
`request_user_input`, Cursor `AskQuestion`, Antigravity `ask_question` (`nen surface capabilities
--surface <s>` names it) — never a paragraph ending in a question mark. The picker's options are the
marker's, verbatim, same letters, same order. **A `DO` or `MERGE` ask takes no picker**, the act being
the maintainer's outside the session.

**Only a genuine G5-class stop interrupts**: red required tests inside
[`kotoamatsukami`](../kotoamatsukami/SKILL.md), coverage under the minimum inside
[`byakugan`](../byakugan/SKILL.md), a semantic conflict inside [`ao`](../ao/SKILL.md), an unsettled
finding inside `hanten`, a `sharingan` escalation — plus G1/G2/G3/G4 when one is genuinely due.
Everything else is a turn bell.

## 5. Surfaces, and the fallback where no hook is installed

**Which surface fires rungs 2–3, the in-session fallback's two commands, their sanitising rules, the
read-stderr-not-the-exit-code rule and the marker's removal are
[`docs/SURFACES.md`](../../../../docs/SURFACES.md) § 9** — Claude Code and Antigravity have the `Stop`
hook, **Codex and Cursor have only the fallback**. What is this skill's: **the fallback is announced
every time**, **an unfired rung is never rendered as fired**, and **the stop still stands** whichever
path rang, § 4's four parts being the real bell.

## Residue

`osascript` and `afplay` are harness-level shell, classified `[unknown]` by nen and refused by
`nen watch until` — a notification primitive is a host capability, not a repository operation — and
`osascript`'s exit code is not a delivery receipt, its stderr being the only evidence. The `Stop` hook
and the `PreToolUse` trunk guard are `hooks/hooks.json`'s: this skill reads whether one exists and
never writes one. No surface but Claude Code and Antigravity has a turn-end hook.

## Authority

**Permitted:** write `.nen/last-stop.json` through `nen stop --mark`; run `nen stop`; fire the
workflow's declared rungs; ask through the surface's option picker. **Not permitted:** any git or
GitHub write, any label, merge or push — jutaisho ends a turn, it never advances one — and it
**carries no delegation**, being invoked from `ren` or `en` lending it none.

## Hard limits

- **Never prompts for [`aka`](../aka/SKILL.md)** — offering it, hinting at it, or ending a turn with
  *"shall I push?"* converts a human call into an agent's suggestion.
- **Never escalates an ordinary turn past rung 1** with no gate and no `notifications.turn: "all"` —
  no OS notification, no sound, no marker, no banner, no `nen stop` — and **a turn that did nothing
  rings nothing at all**, not even rung 1.
- **Never renders a stop with fewer than § 4's four parts**, with ⭐ on the **recommended decision**
  and never on the report, which is linked and never an option.
- **Never hands off a G5 report link whose page lacks § 4's blocker verification** (zheref/hatsu#56).
- **Never passes `--notified` for a push notification that did not go out**, **never claims a rung
  fired that did not**, and **never reads `osascript`'s exit `0` as proof it fired** (SURFACES § 9).
- **Never queues or replays a stale bell** — a marker older than ten minutes is removed, not fired.
- **Never leaves its own marker behind on a surface with no hook** (SURFACES § 9).
- **Never writes `who` from the name the surface introduced itself as** (§ 3).
- **Never interpolates an unsanitised value into the fallback (SURFACES § 9).**
- **Never suppresses a real stop** because a turn bell already rang, and never fires its noise twice.
- **Never rings rungs 2–3 in-session without saying so**, and **never escalates an ordinary turn just
  because a surface has no hook**.
