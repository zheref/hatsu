---
name: jutaisho
description: Ring the bell at the end of a turn — the three escalation rungs from nen/workflow.json (a push notification through the surface, an OS notification, an audible cue), the .nen/last-stop.json marker the Stop hook reads, and the fallback that runs the notifier in-session and says so when no hook is installed. Use when hatsu:ren reaches its sixth step, when hatsu:en reaches Ready, or when the maintainer invokes hatsu:jutaisho [at <gate>]. An ordinary turn rings rung 1 only — rungs 2 and 3 escalate at a gate, or when nen/workflow.json notifications.turn says a turn rings — and a turn that did nothing rings nothing; a genuine gate gets the nen stop banner, the report link, lettered options with a star on the report, and the question through the surface's own option picker. Never prompts for hatsu:aka.
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

> ### RETIRED at nen `0.6`: an ordinary turn may be spelled `--line ""`
>
> **Both spellings now parse identically**, re-verified live at the pinned `v0.7.0`:
>
> ```
> $ nen parse jutaisho --grammar "at [<gate:G1|G1-M|G2|G3|G4|G5>]" --line ""
> gate: (clause absent)                                                            # exit 0
>
> $ nen parse jutaisho --grammar "at [<gate:G1|G1-M|G2|G3|G4|G5>]" --line "at"
> gate: (clause absent)                                                            # exit 0
> ```
>
> Through `v0.5.0` the empty line was exit `2` — *"the line must open with the literal 'at'"* — while
> a bare `at` was exit `0` with the clause absent, so the ORDINARY invocation of the most-invoked step
> in the whole loop was the one a caller had to be told about. A headless Cursor run found it by
> trying both and recorded the working form (`docs/ab/surfaces.md` § 8, F11). **At `0.7.0` a grammar
> whose every slot is bracketed accepts the empty line**, whichever side of the brackets the template
> writes the separator on, and the echo gains a `<name>: (clause absent)` line for an optional slot
> nobody filled — because a slot simply MISSING from the echo cannot be told apart from a template
> that never declared it.
>
> **`--line "at"` stays the documented alternative and is still exactly correct**: it is the same
> parse, and a run that already spells it that way needs no change. What lapses is the rule that it
> was the ONLY spelling. **A grammar carrying a REQUIRED slot is untouched** — an empty line there is
> still exit `2` naming the slot, with the corrected line to paste, which is why this is a narrowing
> of the refusal and not its removal.

**The clause is a gate, and its absence is meaningful, not a default.** With no `at <gate>` the run
is a **turn bell**: nothing is asked and no `nen stop` banner is rendered. With a gate, this is a
**stop**, and § 4's whole shape is owed.

**How loud a turn bell is, exactly, and it is one rung:**

| The run | Rungs that fire | Decided by |
|---|---|---|
| **An ordinary turn** — no `at <gate>` | **rung 1 only** — the surface's own turn-end line | the default, § 2's `notifications.turn` |
| **A turn in a repository that asks for more** | every rung in `notifications.rungs` | `notifications.turn: "all"` (§ 2) |
| **A gate** — `at <gate>` present | every rung in `notifications.rungs`, plus § 4's banner | the clause |

> **This settles a contradiction this file used to carry, and it is recorded rather than quietly
> corrected (finding F8).** § 1 read *"rungs fire per § 2"* for every turn; the hard limits read
> *"never rings for a turn that needs nothing"* — and nothing here defined what a turn "needing
> something" was short of a gate, so both readings were supportable and they disagreed about every
> ordinary turn of every effort. The resolution is the table above, and it is deliberately not a
> judgement call: **rung 1 is a line in a transcript the maintainer is already looking at, and rungs
> 2–3 take over the machine.** A line costs nothing and is worth having every turn. An OS
> notification and a sound every turn is precisely the bell nobody hears — the failure this skill
> opens by naming. **So the escalation is gated on the gate**, and the only way an ordinary turn
> rings rungs 2–3 is a repository saying so in its own policy file, by name.

**"A turn that needs nothing" is now defined, and it is narrow:** a turn with **no `at <gate>`** and
**nothing to say** — no commit, no report rendered, no step refused. That turn rings *nothing at
all*, not even rung 1, because rung 1 announces a turn's end and there was no turn. Every other
ordinary turn rings rung 1.

## 2. The three rungs — `nen/workflow.json` → `notifications`

| Key | Meaning | Default when the key (or the file) is absent |
|---|---|---|
| `notifications.rungs` | which rungs **may** fire, in order | `["push", "os", "sound"]` |
| `notifications.sound` | the macOS system sound name for rung 3 | `Glass` |
| `notifications.turn` | **how loud an ordinary turn is**: `"rung1"` — rung 1 only — or `"all"` — every rung `rungs` lists | `"rung1"` |

**A rung the workflow does not list does not fire.** A repository that declares
`"rungs": ["push"]` gets the surface notification and silence; that is a configuration, not a
degradation, and it is reported as configured rather than as missing.

> **`notifications.turn` is the key that decides whether an ordinary turn escalates, and it is the
> only one.** Not a heuristic about how long the turn was, not a guess about whether the change
> looked important, not the presence of a report — one declared value, two admitted strings, read
> off the repository's own policy file. `"rung1"` is the default and the answer for every repository
> that says nothing; `"all"` is a maintainer choosing to be interrupted every turn, in writing, in a
> file they can change back. **`rungs` and `turn` are different questions** and both are asked:
> `rungs` says which rungs exist for this repository at all, `turn` says how many of them an
> *ungated* run may use. A repository with `"rungs": ["push"]` and `"turn": "all"` still rings only
> rung 1, because `turn` cannot conjure a rung `rungs` withheld.
>
> **RETIRED at nen `0.5`: `notifications.turn` IS in `nen.workflow/v0.1`.** The loader admits
> `"rung1"` (the default, and what an absent key reads as) or `"all"` — a **closed two-value set**,
> refused by pointer on anything else. Verified live at the pinned `v0.7.0`: a policy file declaring
> `"turn": "loud"` FAILs `nen schema check` with *"at notifications.turn, 'loud' is not one nen
> implements. It is one of a CLOSED set: rung1, all"*, and `"turn": "all"` validates `ok`
> (`docs/ab/jutaisho.md` § *Retired at nen 0.5*). `nen scaffold init`/`new` now write the key into
> every fresh policy file, explicitly `"rung1"`.
>
> **nen reads and validates the key and fires none of the three rungs itself**, exactly as the rest
> of `notifications` already works: this is policy data for whichever host hook rings them. And the
> two rules § 1 states are nen's own words now — a gate always rings everything `rungs` lists
> regardless of `turn`, and `turn` can only **withhold** an escalation `rungs` already grants, never
> conjure a rung `rungs` does not list. A repository whose file omits the key is not malformed; the
> default applies and is stated.

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

**The marker is written only when rungs 2–3 are actually owed** — a gate, or `notifications.turn:
"all"` (§ 1). An ordinary turn under the default rings rung 1 and writes **no marker at all**: a
marker on disk is a request to interrupt, and writing one for every turn would hand the hook the
escalation § 1 just withheld.

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
- **The hook treats a marker older than 10 minutes as stale**: it decides from the file's **mtime**
  (`find "$marker" -mmin -10`, `hooks/stop-bell.sh`) and removes it without firing. A stale bell for a turn
  that ended while the machine was asleep is worse than no bell. **So the marker is written whole, in the
  turn it describes** — never amended later, never carried over from a previous turn with its content
  edited, because the freshness the hook reads is the mtime and not the `at` field.
- **`who` is the persona, and it stays the persona whatever the surface calls itself.** On a host whose
  own instructions give the session another name, the transcript may open as that name while the work is
  done as Kurapika (`docs/SURFACES.md` § 1). `who` here, `--who` on `nen stop`, and the `Hatsu-Agent`
  trailer are Hatsu's record of who acted; **none of them is ever set from what the surface introduced
  itself as.**
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

**This section applies only when rungs 2 and 3 are owed at all** — a gate, or `notifications.turn:
"all"` (§ 1). An ordinary turn under the default has nothing here to fall back to, because it never
asked for rungs 2–3 in the first place.

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
- **A present tool is not a delivered notification.** `osascript` exits `0` on a session with no
  Notification Center seat and reports the failure on **stderr** only — so capture stderr from both lines
  and read it, on every surface, before saying a rung fired. § 6 carries the measured output and the
  exact wording to report; the rule is the same here.
- **The fallback is announced, every time.** *"No Stop hook is installed; rungs 2–3 were fired
  in-session."* A maintainer who thinks the hook is working when it is not will eventually miss a
  gate.

## 6. Surfaces — Codex and Cursor have no `Stop` hook, so this skill rings

**§ 3 and § 5 assume a harness that fires a hook when a turn ends. Only Claude Code does.**
[`hooks/hooks.json`](../../../hooks/hooks.json) is a *Claude Code* manifest — a `Stop` event and a
`PreToolUse` matcher, discovered by that host at the plugin's own `hooks/` path. **Neither Codex nor Cursor
reads it, and neither documents a turn-end hook of its own** ([`docs/SURFACES.md`](../../../docs/SURFACES.md)
§ *What each surface reads*). So on those two surfaces § 5 is not a fallback for a hook that failed to
install — **it is the only path there is**, and it is taken every time rungs 2–3 are owed.

| Surface | Who fires rungs 2–3 | What this skill does |
|---|---|---|
| **Claude Code** | [`hooks/stop-bell.sh`](../../../hooks/stop-bell.sh), off the § 3 marker | writes the marker, and stops |
| **Codex** (`$jutaisho`) | **this skill, in-session** | writes the marker, then runs `osascript` and `afplay` itself, and says so |
| **Cursor** (`/jutaisho`) | **this skill, in-session** | the same |

**The order is marker first, then the two rungs — and the marker is still written.** It is not bookkeeping
for a hook that is not there: it is the record that this stop happened, at what instant, at which gate, and
whether rung 1 had already fired, and the next thing to read the working copy (a resumed session, a
`sharingan` pass, the maintainer) reads it. A bell rung with no marker is a bell with no evidence.

```sh
# 1 · the marker — § 3's BY-HAND WRITE of .nen/last-stop.json, whole and fresh.
#     NOT `nen stop --mark`. At the pinned 0.7.0 that option DOES exist and writes
#     (exit 0, verified live) — and it is still not the one used here, because its
#     nen.stop.mark/v0.1 document carries no `title`, so every bell it rings says
#     "A decision is waiting." and drops the report link. That is a kept residue
#     taken on purpose (§ Residue 1), not a pin that has yet to move: the box below
#     is the reason, and the shape is the condition that has not been met.

# 2 · rung 2, in-session, values sanitised exactly as § 5 requires. READ STDERR, NOT THE EXIT CODE
osascript -e 'display notification "<body>" with title "<title>"' 2>&1

# 3 · rung 3
afplay /System/Library/Sounds/<notifications.sound>.aiff 2>&1

# 4 · the marker is removed once the stop has been answered — nothing else will remove it here
rm -f .nen/last-stop.json
```

> ### On a headless session both rungs are `not applicable — no seat`, and rung 2 LIES ABOUT IT
>
> A `codex exec` (or any `cursor-agent -p`) run has no Notification Center session and no audio device.
> Measured live inside `codex exec -s workspace-write` on this host (`docs/ab/surfaces.md` § 7, F8):
>
> | rung | command | exit | what actually happened |
> |---|---|---:|---|
> | 2 | `osascript -e 'display notification …'` | **`0`** | **nothing was delivered.** stderr: *"NSNotificationCenter connection invalid"*, *"Connection to notification center invalid. ServerConnectionFailure: 1"* |
> | 3 | `afplay …/Glass.aiff` | `1` | nothing was played. stderr: *"Error: AudioQueueStart failed (-66680)"* |
>
> **Rung 2's exit code is not evidence it fired**, and a skill that checks the exit code alone reports a
> bell that never rang — which is the one failure this file's hard limits single out
> (*"never claims a rung fired that did not"*). So on any surface:
>
> - **Capture stderr and read it.** Non-empty stderr from `osascript` containing `notification center`,
>   `Connection invalid` or `ServerConnectionFailure` means **rung 2 did not fire**, whatever the exit code
>   said. `afplay`'s exit `1` with `AudioQueueStart failed` means the same for rung 3.
> - **Report it as `not applicable — no seat`, by name, per rung**, exactly the way § 5 reports an absent
>   `osascript`. Not "fired", not "failed" — there is nobody at this machine's Notification Center to fire
>   at, and that is a property of the session rather than a fault to retry.
> - **Then the stop still stands.** § 4's four parts are the real bell on a headless surface: the banner,
>   the report link, the lettered options, the question. Rungs 2–3 were always the *escalation*, and an
>   escalation with no seat to escalate to costs nothing to skip and everything to fake.
> - **Never retry them, and never substitute another noise-maker** (`say`, `terminal-notifier`, a bell
>   character). A rung is what `notifications.rungs` declares; anything else is a new rung nobody policy'd.

> ### The marker is a live fact, not a log — write it fresh, and remove it when the stop is answered
>
> **`hooks/stop-bell.sh` decides freshness from the file's mtime** — `find "$marker" -mmin -10` — and a
> marker older than ten minutes is removed **without ringing**. Two consequences, and both were observed:
>
> - **A marker re-used across turns must be re-written, not amended in place by a reader.** Every write of
>   `.nen/last-stop.json` is a whole-file write in this turn, so its mtime is this turn's. A marker whose
>   content is current but whose mtime is stale is a bell that silently will not ring.
> - **On a surface with no hook, nothing ever removes it, so this skill does.** After a headless run that
>   ended successfully with the branch pushed, `.nen/last-stop.json` still read `gate: "G5"` with a blocker
>   answered three passes earlier (`docs/ab/surfaces.md` § 7, F13). A later reader — a resumed session, a
>   `sharingan` pass, or a `hooks/stop-bell.sh` that runs in *some other* session standing in that
>   directory — sees a gate that is not open. **Where this skill wrote the marker itself and fired the
>   rungs itself, this skill removes it** once the stop has been answered or the run has moved past it.
>   On Claude Code it does **not**: the hook consumes the marker, and removing it first is removing the
>   bell.

> **`nen stop --mark` exists at the pinned `0.7.0`, and § 3's by-hand write is KEPT anyway — the
> decision this section said was due is taken here, with its reason.** Verified live at the pin, exit
> `0`: `nen stop --mark --repo <path> --who kurapika --gate G5` prints `marked: <path>/.nen/last-stop.json
> -- a host hook may ring rungs 2-3 off it` and writes
>
> ```json
> { "contract": "nen.stop.mark/v0.1", "who": "kurapika", "gate": "G5", "notified": false,
>   "at": "2026-09-10T09:10:05.340Z" }
> ```
>
> **That shape carries no `title`, no `body`, no `reportUrl`, no `sound` and no `rungs`** — and it
> **replaces** an existing marker, because the latest stop is the one to ring for. `hooks/stop-bell.sh`
> reads `gate` and `title` and falls back to *"A decision is waiting."* when `title` is absent, so
> adopting nen's marker would ring the generic line **every time**, on every gate, and would drop the
> report link out of the notification entirely. That is a downgrade, not a retirement, so § 3's
> `hatsu.stop-marker/v0.1` stays and § Residue 1 says why — and the § 6 block above therefore spells
> the by-hand write rather than the verb (Copilot review thread `PRRT_kwDOUKPjxM6hAjMh`).
>
> **What DOES change at the pin, and is worth knowing:** `--mark` is the only form of this verb that
> writes, so `nen parse izanami` classifies `stop` **write-flag-gated** on it rather than plain
> read-only; the marker is written **last**, after every refusal; `--mark --template` is exit `2`; and
> a marker that cannot be written is exit `1` with the errno. Where a *nen-driven* flow has written
> nen's marker into a checkout, read it as the fact of a stop and expect the generic line.

**Whether an ordinary turn escalates at all is still `notifications.turn`'s answer, on every surface**
(§ 1, § 2). The default `"rung1"` means a Codex or Cursor turn rings the surface's own turn-end line and
runs neither command below it; only a gate, or a repository declaring `"turn": "all"`, reaches this section
at all. **A surface without a hook is not a reason to be louder.**

> **RETIRED at nen `0.5`: `notifications.turn` is validated.** It arrived in the release the pin now
> names — the loader admits `"rung1"` and `"all"` and refuses anything else by pointer (§ 2, verified
> live). So the key is no longer a Hatsu extension the schema does not know about: it is policy nen
> reads, validates and fires nothing off, which is exactly the division this section describes.

**The report says which surface rang, and how.** One line, every time rungs 2–3 are owed on a surface with
no hook: *"Codex: no Stop hook on this surface — rung 2 not applicable (no Notification Center seat:
`osascript` exit 0, stderr `NSNotificationCenter connection invalid`), rung 3 not applicable (`afplay`
exit 1, `AudioQueueStart failed`); marker written by hand at `.nen/last-stop.json` in Hatsu's own
`hatsu.stop-marker/v0.1` shape (§ 6) and removed once the stop was answered."* The maintainer must be able to tell a bell the
harness rang from a bell the model rang **from a bell nobody rang**, on every surface, without asking.

**Rung 1 is the surface's own, and it is not this skill's to fake.** Codex and Cursor each end a turn with
their own signal; that is rung 1, and `nen stop --notified` may be passed **only** if it actually went out
(§ 2). A surface whose turn-end signal is a line in a terminal nobody is watching has rung rung 1 all the
same — that is what rungs 2 and 3 are for.

## Residue

1. **KEPT residue, deliberately: `.nen/last-stop.json` is written by this skill, in Hatsu's own
   shape** (§ 3). `nen stop --mark` exists at the pinned `0.7.0` and writes
   `nen.stop.mark/v0.1` — `{ contract, who, gate, notified, at }`, verified live at exit `0` — but
   that document carries no `title`, `body`, `reportUrl`, `sound` or `rungs`, and it **replaces** an
   existing marker. `hooks/stop-bell.sh` would then ring *"A decision is waiting."* on every gate,
   with no report link. **This is a residue kept on purpose rather than one nobody noticed**: the
   choice was named as due in § 6 and is taken here. It lapses the day nen's marker carries a title,
   or the day Hatsu decides a generic bell is acceptable — neither of which is a default.
2. **`osascript` / `afplay` are harness-level shell** (§ 5), classified `[unknown]` by nen's own
   table and refused by `nen watch until` — named, with the reason, never presented as a verb.
3. **The `Stop` hook and the `PreToolUse` trunk guard are `hooks/hooks.json`'s**, this repository's
   harness files. This skill reads whether one exists; it never writes one.
4. **RETIRED at nen `0.5`: `nen/workflow.json` is validated** — `nen schema check --repo <path>`
   carries an `ok  nen/workflow.json` row at the pinned build, so a malformed policy file is a
   FAIL by pointer. § 2's keys are still read here; a read is not a residue.
4b. **RETIRED at nen `0.6`: the empty `--line` refusal** (§ 1). `nen parse jutaisho --grammar
   "at [<gate:…>]" --line ""` is exit `0` with `gate: (clause absent)`, identical to `--line "at"`
   (`docs/ab/jutaisho.md` § *Retired at nen 0.6*). The bare `at` stays documented and stays correct;
   what lapses is having to know it.
5. **RETIRED at nen `0.5`: `notifications.turn` is in `nen.workflow/v0.1`** — a closed set of
   `"rung1"` and `"all"`, refused by pointer on anything else and written into every scaffolded
   policy file (§ 2, verified live both ways: `"loud"` FAILs naming the set, `"all"` validates `ok`).
   It is no longer this skill's private extension.
6. **KEPT residue, deliberately: the marker's SHAPE** — see 1. `nen stop --mark` is available and is
   not adopted, because `nen.stop.mark/v0.1` carries neither `title` nor `sound` nor `rungs` and
   would ring the generic line on every gate.
7. **No surface but Claude Code has a turn-end hook** (§ 6). That is a fact about those products, not a
   missing verb — nen shells out to git and gh and owns no notifier on any surface — so it is named here
   and never filed.
8. **Removing the marker on a hookless surface is this skill's own `rm -f`** (§ 6), and **genuinely
   still residue at the pinned `0.7.0`**: `nen stop --mark` writes and never removes — its own help
   calls it *"the ONLY form of this verb that writes"* — and
   `hooks/stop-bell.sh`, which does remove, is a Claude Code manifest nothing else reads. So on Codex and
   Cursor the cleanup is by hand, named here, and it is the reason a stop answered three passes ago does
   not keep reading as open (`docs/ab/surfaces.md` § 7, F13).
9. **`osascript`'s exit code is not a delivery receipt, and nothing on any surface gives one** (§ 6). The
   only evidence available is its stderr, read by this skill. That is a property of the macOS notification
   API rather than a gap in nen, so it is named and never filed.

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
- **Never escalates an ordinary turn past rung 1.** No gate and no `notifications.turn: "all"` means
  the surface's own line and nothing else: no OS notification, no sound, no marker, no banner, no
  `nen stop` (§ 1, § 3). And **a turn that did nothing rings nothing at all** — § 1's narrow case.
- **Never renders a stop with fewer than § 4's four parts** — banner, report link, lettered options
  with ⭐ on the report, and the question through the surface's own picker.
- **Never passes `--notified` for a push notification that did not go out.**
- **Never claims a rung fired that did not** — an absent `osascript`, a hook that is not installed,
  a rung the workflow does not list, are each reported by name. **And never reads `osascript`'s exit `0`
  as proof it fired**: on a headless session it exits `0` with the notification undelivered and says so
  only on stderr (§ 6, verified). Read the stderr; report `not applicable — no seat`.
- **Never queues or replays a stale bell** — a marker older than ten minutes is removed, not fired.
- **Never leaves its own marker behind on a surface with no hook** (§ 6). Where this skill wrote it and
  rang the rungs itself, this skill removes it once the stop is answered; nothing else there will.
- **Never writes `who` from the name the surface introduced itself as** (§ 3). The persona is Hatsu's
  record, and a host-level identity instruction does not change who acted.
- **Never interpolates an unsanitised value into the § 5 fallback.** The title and body lose `"`,
  `\` and every newline and are passed as one argument; the sound name is reduced to
  `[A-Za-z0-9_-]` before it becomes a path. The in-session fallback is held to
  `hooks/stop-bell.sh`'s rule, not to a looser one for being typed rather than installed.
- **Never suppresses a real stop** because a turn bell already rang, and never fires a real stop's
  noise twice.
- **Never rings rungs 2–3 in-session without saying so** (§ 5, § 6). On Codex and Cursor that line is
  owed on *every* stop, because on those surfaces there is no hook that could have rung them instead.
- **Never escalates an ordinary turn just because a surface has no hook** (§ 6). `notifications.turn`
  decides, on all three surfaces, and its default is `"rung1"`.
