---
name: jutaisho
description: Ring the bell at the end of a turn — the three escalation rungs from nen/workflow.json (a push notification through the surface, an OS notification, an audible cue), the .nen/last-stop.json marker the Stop hook reads, and the fallback that runs the notifier in-session and says so when no hook is installed. Use when hatsu:ren reaches its sixth step, when hatsu:en reaches Ready, or when the maintainer invokes hatsu:jutaisho [at <gate>]. A turn that needs nothing rings nothing; a genuine gate gets the nen stop banner, the report link, lettered options with a star on the report, and the question through the surface's own option picker. Never prompts for hatsu:aka.
---

# Jutaisho — the bell

**Nature: Manipulator.** Signalling is board-facing work: it decides whether the maintainer's
attention is spent. Kurapika says so when he runs it.

> **When the turn is over, tell me — and only actually interrupt me when it is mine.**

Jutaisho is the **last** step of [`hatsu:ren`](../ren/SKILL.md)'s turn and the step
[`hatsu:en`](../en/SKILL.md) fires at Ready. It is the only place in the local plane that is allowed
to make a noise, and the discipline that makes it worth having is the one it enforces on itself:
**a bell that rings every turn is a bell nobody hears.**

---

## 1. Invocation

```
hatsu:jutaisho [at <G1 | G1-M | G2 | G3 | G4 | G5>]
```

```bash
nen parse jutaisho --grammar "at [<gate:G1|G1-M|G2|G3|G4|G5>]" --line "<the invocation, minus the hatsu:jutaisho prefix>"
```

Verified live at `v0.3.0` (`docs/ab/jutaisho.md` § 2.1): `at G5` → `gate: G5`; a bare `at` parses
with the clause absent, exit `0`. The clause is anchored behind a literal for the reason
[`hatsu:rikugan`](../rikugan/SKILL.md) § 1 records — a lone bracketed slot is refused at the
template, so every optional clause in this wave gets an introducing word.

**The clause is a gate, and its absence is meaningful, not a default.** With no `at <gate>` the run
is a **turn bell**: rungs fire per § 2, nothing is asked, and no `nen stop` banner is rendered. With
a gate, this is a **stop**, and § 4's whole shape is owed.

## 2. The three rungs — `nen/workflow.json` → `notifications`

| Key | Meaning | Default when the key (or the file) is absent |
|---|---|---|
| `notifications.rungs` | which rungs fire, in order | `["push", "os", "sound"]` |
| `notifications.sound` | the macOS system sound name for rung 3 | `Glass` |

**A rung the workflow does not list does not fire.** A repository that declares
`"rungs": ["push"]` gets the surface notification and silence; that is a configuration, not a
degradation, and it is reported as configured rather than as missing.

| Rung | What it is | Who fires it |
|---|---|---|
| **1 · `push`** | the notification the *surface* sends — Claude Code's own turn-end notification | the harness, or this skill through the surface; **never nen** |
| **2 · `os`** | an OS notification with the title and one line of body | the `Stop` hook, off the § 3 marker; § 5 in-session when there is no hook |
| **3 · `sound`** | an audible cue, `notifications.sound` | the same |
| — | the banner and efforts table | `nen stop` (§ 4) |

> **`nen` fires none of rungs 1–3, and says so in its own words — verified live
> (`docs/ab/jutaisho.md` § 2.2).** `nen stop` prints, every run: *"rungs 2-3 (OS notification,
> audible cue): not fired by nen — only git/gh subprocesses are ever shelled out to."* And rung 1 it
> reports rather than performs: without `--notified` it prints *"rung 1 (push notification): NOT
> fired — the caller's to have sent, before this renders"*, and **`nen stop --notified` changes that
> one line** to *"reported sent by the caller."* Verified live both ways, exit `0` each time. So
> `--notified` is a **claim this skill makes about what it already did**, never an instruction to
> nen — pass it only after rung 1 has actually gone out, or the banner records a notification
> nobody sent.
>
> **nen's own numbering calls the banner rung 4.** This skill's three rungs are the workflow's
> three; the two numberings compose (`push`/`os`/`sound` = nen's 1/2-3, the banner = nen's 4) and
> neither renumbers the other. Say "rung 2" and mean the OS notification, both ways.

## 3. The marker — `.nen/last-stop.json`

Rungs 2 and 3 are fired by the harness `Stop` hook, and the hook needs to be told. **The skill
writes the marker; the hook reads it, fires, and removes it.**

```
.nen/last-stop.json
{
  "contract":  "hatsu.stop-marker/v0.1",
  "at":        "<absolute ISO-8601 UTC timestamp>",
  "gate":      "G5" | null,
  "who":       "kurapika",
  "title":     "<one short line — what happened>",
  "body":      "<one line — what is needed, or what finished>",
  "reportUrl": "<the rikugan report's link or path>",
  "sound":     "<notifications.sound>",
  "rungs":     ["os", "sound"]
}
```

- **`.nen/` is git-ignored**, and the marker is the only file this skill writes anywhere.
- **The hook treats a marker older than 10 minutes as stale**: it removes it without firing. A stale
  bell for a turn that ended while the machine was asleep is worse than no bell.
- **One marker, overwritten.** A second turn's marker replaces the first; there is no queue, because
  a backlog of notifications is exactly what this skill exists to prevent.
- **The hook is `hooks/hooks.json`'s** — a harness hook, POSIX `sh`, documented as the harness's and
  **not as a nen-owned step**. This skill never edits it and never installs it.

> **Writing this file is residue: `nen stop` does not write it.** Verified live — `nen stop`'s
> `--help` names one output, the banner and table, and its own text says nen shells out to git and
> gh only. `nen stop --notified` records that rung 1 fired; it records nothing about rungs 2–3 and
> creates nothing on disk. The marker is this skill's own file, written by hand, named here.

## 4. A stop — the four parts, all four or it is not a stop

When the `at <gate>` clause is present, the bell is a **gate stop** and owes every one of these:

**1 · The `nen stop` banner and efforts table.**

```bash
nen stop --who Kurapika --gate <G1|G1-M|G2|G3|G4|G5> --notified <efforts.md>
```

`<efforts.md>` is a markdown pipe table; `nen stop --template` emits the blank five-column shape to
fill (`Effort | Open issues & PRs | Status (gate) | Thought flow | Session / lane`), verified live at
exit `0`. Pass `--notified` **only if rung 1 actually fired** (§ 2). Both forms verified live,
`docs/ab/jutaisho.md` § 2.2.

**2 · The report link.** [`hatsu:rikugan`](../rikugan/SKILL.md) has already rendered and published
the turn's page (`ren` step 5 runs before this one). The link goes in the stop; the stop never
restates the page's contents.

**3 · Lettered options, with a ⭐ on the report.** The recommendation is always *read the report
first* — the maintainer deciding without having opened the page is the failure this whole ordering
exists to prevent. Options are concrete acts, not moods: *"⭐ A — open the report", "B — take side
`ours` on `src/session.ts`", "C — stop here and hand it back."*

**4 · The question through the surface's own option picker.** On Claude Code that is
**AskUserQuestion**, not a paragraph ending in a question mark. A stop rendered as prose is a stop
the maintainer has to compose an answer to, and it is not this skill's shape.

**Only a genuine G5-class stop interrupts.** Red required tests inside [`hatsu:aka`](../aka/SKILL.md),
coverage under the minimum inside `hatsu:gyo`, a semantic conflict inside [`hatsu:ao`](../ao/SKILL.md),
an unsettled finding inside `hatsu:hanten`, a `hatsu:sharingan` escalation — plus the named human
gates G1/G2/G3/G4 when one is genuinely due. Everything else is a turn bell.

## 5. No hook installed — the fallback, said out loud

If `hooks/hooks.json` is not installed on this machine, rungs 2 and 3 have nobody to fire them.
**Then this skill runs the notifier itself, in-session, and says which rungs it fired that way:**

```sh
osascript -e 'display notification "<body>" with title "<title>"'
afplay /System/Library/Sounds/<notifications.sound>.aiff
```

> **Every value substituted into those two lines is sanitised first, exactly the way
> [`hooks/stop-bell.sh`](../../../hooks/stop-bell.sh) sanitises it — the fallback is the same bell,
> so it carries the same rule.** A stop title and body come from the effort: a branch name, a test
> name, a conflicted path, a finding quoted from a reviewer. They are repository-controlled, and
> here they land in **two nested quoting contexts at once** — a single-quoted shell word and, inside
> it, a double-quoted AppleScript literal — where a stray `'`, `"` or `\` does not merely garble
> the notification but ends the argument and hands the rest of the string to the shell.
>
> - **`<title>` and `<body>`**: strip `"` and `\` and every newline, and pass the result as one
>   argument — the hook's `sanitize()` is `tr -d '"\\' | tr -d '\n'`, and this is that function
>   written out. Never interpolate a raw value into the `-e` string.
> - **`<notifications.sound>`**: it becomes a **path**, so reduce it to `[A-Za-z0-9_-]` before it is
>   used — the hook's own rule — and fall back to `Glass` when nothing survives or the file does not
>   exist. A sound name is not a place to accept `../`.
>
> **A value that cannot be sanitised is not rung with**: fall back to the rung's generic line
> (*"A decision is waiting."*) and say that the title was dropped. The bell exists to interrupt a
> human, and a bell that executes what it was asked to announce is a worse failure than a silent one.

> **Both lines are residue, and nen classifies them as such — verified live
> (`docs/ab/jutaisho.md` § 2.3).** `nen parse izanami "osascript -e display until …"` and the same
> for `afplay` both report **`[unknown]`** and refuse at exit `1`: *"at least one command does not
> classify as read-only — the WHOLE run is refused."* nen cannot read what a program it does not
> know will do, so it will not certify one — the same boundary
> [`hatsu:izanami`](../izanami/SKILL.md) § 2 records for checker scripts. **This is not a defect and
> not a gap to route around**: a notification primitive is a *host* capability, not a repository
> operation, and nen deliberately shells out to git and gh and nothing else. It stays harness-level
> shell, named here, with the reason. By contrast `nen stop` itself classifies **`[read-only]`**
> (verified live, exit `0`) — the banner is nen's, the noise is not.

- **macOS only, and rung by rung.** Each rung is reported **not fired**, by name, with the missing
  tool as the reason: no `osascript` (or a host that is not macOS) unfires rung 2 **and leaves rung 3
  to fire on its own** if `afplay` is there. One absent tool never unfires the other rung, and
  `hooks/stop-bell.sh` consumes the marker either way. **An unfired rung is never rendered as fired.**
- **The fallback is announced, every time.** *"No Stop hook is installed; rungs 2–3 were fired
  in-session."* A maintainer who thinks the hook is working when it is not will eventually miss a
  gate.

## Residue

1. **`.nen/last-stop.json` is written by this skill, not by nen** (§ 3). `nen stop` renders the
   banner and states rung 1's status; it creates no file.
2. **`osascript` / `afplay` are harness-level shell** (§ 5), classified `[unknown]` by nen's own
   table and refused by `nen watch until` — named, with the reason, never presented as a verb.
3. **The `Stop` hook and the `PreToolUse` trunk guard are `hooks/hooks.json`'s**, this repository's
   harness files. This skill reads whether one exists; it never writes one.
4. **`nen/workflow.json` is unvalidated at `v0.3.0`** — `nen schema check` reports five rows and no
   workflow row (verified live, `docs/ab/rikugan.md` § 2.4). § 2's keys are read as data with the
   defaults stated.

## Authority

- **Permitted:** write `.nen/last-stop.json`; run `nen stop`; fire the workflow's declared rungs;
  ask the maintainer a question through the surface's option picker.
- **Not permitted:** any git write, any GitHub write, any label, any merge, any push. Jutaisho ends
  a turn; it never advances one.
- **Carries no delegation**, and being invoked from inside [`hatsu:ren`](../ren/SKILL.md) or
  [`hatsu:en`](../en/SKILL.md) does not lend it one.

## Hard limits

- **Never prompts for [`hatsu:aka`](../aka/SKILL.md).** `aka` is human-called (brief § 2). Offering
  it as an option, hinting at it, or ending a turn with *"shall I push?"* converts a human call into
  an agent's suggestion, which is exactly the inversion the local plane forbids. If the branch is
  ready to go out, the report says the branch is ready to go out — and stops there.
- **Never rings for a turn that needs nothing.** No gate, no banner, no `nen stop`, no interruption.
- **Never renders a stop with fewer than § 4's four parts** — banner, report link, lettered options
  with ⭐ on the report, and the question through the surface's own picker.
- **Never passes `--notified` for a push notification that did not go out.**
- **Never claims a rung fired that did not** — an absent `osascript`, a hook that is not installed,
  a rung the workflow does not list, are each reported by name.
- **Never queues or replays a stale bell** — a marker older than ten minutes is removed, not fired.
- **Never interpolates an unsanitised value into the § 5 fallback.** The title and body lose `"`,
  `\` and every newline and are passed as one argument; the sound name is reduced to
  `[A-Za-z0-9_-]` before it becomes a path. The in-session fallback is held to
  `hooks/stop-bell.sh`'s rule, not to a looser one for being typed rather than installed.
- **Never suppresses a real stop** because a turn bell already rang, and never fires a real stop's
  noise twice.
