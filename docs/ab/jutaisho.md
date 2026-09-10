# A/B evidence — `jutaisho` (new skill, wave 2)

`claude/skills/jutaisho/SKILL.md`: the bell — the three escalation rungs `nen/workflow.json`
declares, the `.nen/last-stop.json` marker the harness `Stop` hook reads, and the in-session
fallback when no hook is installed.

**A new skill, so there is no "old mechanics" column.** What this record establishes is a boundary
rather than a port: **`nen` renders the banner and refuses to make a noise**, and it says so in its
own words on every run. Everything above rung 4 is the caller's, and this document is where that
division is proved rather than assumed.

Run: 2026-09-09 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
Verbs were run pure (`nen stop`, `nen parse`) or against a **constructed throwaway fixture** at
`<worktree>/.nen-fixture`, created for this run and deleted before the branch was committed. No
verb was run against any primary checkout in a way that could write to it.

Nothing below is redacted; both repositories are public.

---

## 1. The skill

Jutaisho is `hatsu:ren`'s sixth and last step, and the step `hatsu:en` fires at Ready. It decides
whether the maintainer's attention is spent, and it holds one rule against itself: **a bell that
rings every turn is a bell nobody hears.**

| Step | Owned by | State at `v0.3.0` |
|---|---|---|
| Parse the invocation | `nen parse jutaisho --grammar "at [<gate:…>]"` | **verb** (§ 2.1) |
| Read `notifications.rungs` / `.sound` | `nen/workflow.json` | **read as data** — unvalidated (`docs/ab/rikugan.md` § 2.4) |
| Rung 1 — push notification | the surface | **not nen's** — nen *reports* it (§ 2.2) |
| Rung 2 — OS notification | the `Stop` hook, or § 2.3's fallback | **not nen's, by design** (§ 2.2, § 2.3) |
| Rung 3 — audible cue | the same | **not nen's, by design** |
| Rung 4 — banner + efforts table | `nen stop` | **verb** (§ 2.2) |
| The `.nen/last-stop.json` marker | — | **no verb** → residue (§ 3.1) |
| The question | the surface's option picker (AskUserQuestion) | **not nen's, ever** |

**Eight steps; two are verbs, and six are outside nen's declared reach.** That is not a gap: nen
shells out to git and gh only, and a notification primitive is a host capability. The value of this
record is that the boundary is *verified*, so nobody re-litigates it later as a missing verb.

---

## 2. Verbs exercised live

### 2.1 — `nen parse jutaisho`: the anchored optional gate clause

```
$ nen parse jutaisho --grammar "at [<gate:G1|G1-M|G2|G3|G4|G5>]" --line "at G5"
gate: G5
exit=0

$ nen parse jutaisho --grammar "at [<gate:G1|G1-M|G2|G3|G4|G5>]" --line "at"
exit=0                                   # parses, clause absent -- a turn bell, not a stop
```

The clause is anchored behind the literal `at` for the reason `docs/ab/rikugan.md` § 2.1 records
live: a lone bracketed slot is refused **at the template**, naming the fix.

### 2.2 — `nen stop`: the banner, and nen saying which rungs it will not fire

```
$ nen stop --template
| Effort  | Open issues & PRs | Status (gate)   | Thought flow | Session / lane |
| ------- | ----------------- | --------------- | ------------ | -------------- |
| <title> | <link>            | <status (gate)> | <one line>   | <session>      |
exit=0
```

```
$ cat efforts.md
| Effort | State | Gate | Needs | Owner |
| ------ | ----- | ---- | ----- | ----- |
| ren turn 3 — semantic conflict in src/session.ts | ao halted mid-merge | G5 | pick a side; both shown | maintainer |

$ nen stop --who Kurapika --gate G5 efforts.md
=== YOUR INPUT IS NEEDED ==============================
who: Kurapika
gate: G5 -- decision / human-only action
rung 1 (push notification): NOT fired -- the caller's to have sent, before this renders.
rungs 2-3 (OS notification, audible cue): not fired by nen -- only git/gh subprocesses are ever
shelled out to.
see the table below. No banner above => nothing needs you right now.

| Effort                                           | State               | Gate | Needs                   | Owner      |
| ------------------------------------------------ | ------------------- | ---- | ----------------------- | ---------- |
| ren turn 3 — semantic conflict in src/session.ts | ao halted mid-merge | G5   | pick a side; both shown | maintainer |
exit=0
```

```
$ nen stop --who Kurapika --gate G5 --notified efforts.md
=== YOUR INPUT IS NEEDED ==============================
who: Kurapika
gate: G5 -- decision / human-only action
rung 1 (push notification): reported sent by the caller.
rungs 2-3 (OS notification, audible cue): not fired by nen -- only git/gh subprocesses are ever
shelled out to.
...
exit=0
```

```
$ nen stop --notified
=== YOUR INPUT IS NEEDED ==============================
rung 1 (push notification): reported sent by the caller.
rungs 2-3 (OS notification, audible cue): not fired by nen -- only git/gh subprocesses are ever
shelled out to.
see the table below. No banner above => nothing needs you right now.
exit=0
```

**Three facts this pins down, all in nen's own words:**

1. **`--notified` changes exactly one line** — `NOT fired -- the caller's to have sent, before this
   renders.` becomes `reported sent by the caller.` It is a **claim the caller makes**, never an
   instruction to nen, so passing it before rung 1 has actually gone out records a notification
   nobody sent.
2. **Rungs 2–3 are never nen's**, stated on every run with the reason: *"only git/gh subprocesses
   are ever shelled out to."*
3. **`nen stop` exits `0` in every form**, including with no efforts file at all — it is a renderer,
   not a guard. `--who` and `--gate` are optional and their absence simply omits those lines. So
   nothing about the *shape* of a stop is enforced by the verb; § 4 of the skill file enforces it.

### 2.3 — The fallback notifier, classified by nen's own table

```
$ nen parse izanami "osascript -e display until it is done"
until: it is done
  [unknown] osascript -e display
nen: at least one command does not classify as read-only -- the WHOLE run is refused. Use 'nen parse
izanagi <task> until <condition> up to <N>' for a loop that must act.
exit=1

$ nen parse izanami "afplay /System/Library/Sounds/Glass.aiff until it is done"
until: it is done
  [unknown] afplay /System/Library/Sounds/Glass.aiff
nen: at least one command does not classify as read-only -- the WHOLE run is refused. ...
exit=1
```

Against the same classifier, in the same run:

```
$ nen parse izanami "nen stop --who Kurapika --gate G5 efforts.md until it is done"
until: it is done
  [read-only] nen stop --who Kurapika --gate G5 efforts.md
exit=0
```

**The split is exactly the boundary the skill draws.** `nen stop` is a nen verb and classifies
`[read-only]`; the two notification programs are `[unknown]` — nen cannot read what a program it
does not know will do, the same seam `claude/skills/izanami/SKILL.md` § 2 records for checker
scripts — and are therefore **harness-level shell, named as residue**, not a verb call in disguise.

---

## 3. Residue

1. **`.nen/last-stop.json` is written by this skill.** `nen stop --help` names one output — the
   banner and the padded-markdown efforts table — and § 2.2 shows it creating nothing on disk in any
   form, including `--notified`. The marker's shape is the skill file's § 3; `.nen/` is git-ignored.
2. **`osascript` / `afplay`** (§ 2.3) — classified `[unknown]` by nen's own table and refused by
   `nen watch until` on that basis. Run as harness-level shell in the no-hook fallback, announced
   every time, and reported **not fired** by name on a host that has neither.
3. **The `Stop` hook and the `PreToolUse` trunk guard** live in `hooks/hooks.json` — this
   repository's harness files, owned elsewhere in this wave. Jutaisho reads whether a hook exists;
   it never writes one.
4. **`nen/workflow.json` read as data** — no schema row at `v0.3.0` (`docs/ab/rikugan.md` § 2.4).
   `notifications.rungs` defaults to `["push","os","sound"]` and `notifications.sound` to `Glass`,
   stated whenever a default applied.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — `nen stop` enforces nothing about a stop's shape, and does not claim to

§ 2.2: every invocation exits `0`, including `nen stop --notified` with **no efforts file, no
`--who` and no `--gate`** — which renders a banner header, two rung lines and nothing else. The verb
is a renderer. So the four-part discipline a stop owes (banner, report link, lettered options with
a ⭐ on the report, the question through the surface's own picker) is **entirely the skill's**, and
a hand-written banner that skipped `nen stop` would be indistinguishable to the verb. Recorded so
that "the banner rendered" is never read as "the stop was well-formed".

### 4.2 — nen's rung numbering and the workflow's rung numbering are different scales

nen's own output numbers the push notification **rung 1** and the banner **rung 4**, with the OS
notification and the audible cue as **rungs 2–3**. `nen/workflow.json` → `notifications.rungs` lists
**three** members (`push`, `os`, `sound`) and does not name the banner at all, because the banner is
not optional. The two compose cleanly — workflow rung 1 = nen rung 1, workflow rungs 2 and 3 = nen's
"rungs 2-3", and nen's rung 4 is `nen stop` itself — but they are not the same list, and a reader
who assumes they are will look for a fourth workflow rung that does not exist. **Not a defect;** a
documentation seam worth stating once, which the skill file's § 2 does.

### 4.3 — `nen stop`'s closing line reads oddly when nen has just printed a banner header

Every run prints `=== YOUR INPUT IS NEEDED ==============================` and then, four lines
later, *"see the table below. No banner above => nothing needs you right now."* The "banner" that
sentence refers to is the **caller's drawn identity banner**, not the ASCII header nen just emitted,
so the two are consistent — but read cold, on a run where the caller drew nothing, the output
appears to contradict itself. **Minor wording finding, no behavioural impact**; recorded because a
maintainer reading a stop for the first time will notice it before anyone explains it.

### 4.4 — Not a finding: nen will never fire a notification, and jutaisho does not want it to

The temptation, on seeing rungs 2–3 declared as residue, is to file "nen should notify". It should
not. `nen` deliberately spawns git and gh and nothing else — the property that makes
`nen parse izanami`'s classifier meaningful at all — and a verb that shelled out to `osascript`
would put an unclassifiable host program inside the binary whose whole job is to classify host
programs. **The correct home for rungs 2–3 is the harness hook**, which is where this wave puts it.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| `notifications.turn` in no schema, validated by nothing | `nen schema check` against a fixture declaring `"turn": "loud"` | that row `FAIL`, by pointer |
| the same, with a legal value | `"turn": "all"` | that row `ok` |
| `nen/workflow.json` unvalidated | `nen schema check --repo .` | that row `ok` |

```
FAIL  nen/workflow.json  …/nen/workflow.json: at notifications.turn, 'loud' is not one nen implements.
                          It is one of a CLOSED set: rung1, all
```

So the key this skill defined to settle finding F8 is now nen's, refused by pointer on anything outside
the two-value set and written into every policy file `nen scaffold init` generates. Hatsu's own
`nen/workflow.json` declares it explicitly, `"rung1"`, in this same change.

### `nen stop --mark` — available, and deliberately NOT adopted

```
$ nen stop --mark --repo <fixture> --who kurapika --gate G5
=== YOUR INPUT IS NEEDED ==============================
who: kurapika
gate: G5 -- decision / human-only action
rung 1 (push notification): NOT fired -- the caller's to have sent, before this renders.
rungs 2-3 (OS notification, audible cue): not fired by nen -- only git/gh subprocesses are ever shelled
out to.
marked: <fixture>/.nen/last-stop.json -- a host hook may ring rungs 2-3 off it.
exit=0

$ cat <fixture>/.nen/last-stop.json
{ "contract": "nen.stop.mark/v0.1", "who": "kurapika", "gate": "G5", "notified": false,
  "at": "2026-09-10T09:10:05.340Z" }
```

**The verb works and the marker is the wrong shape for this bell.** It carries no `title`, no `body`, no
`reportUrl`, no `sound` and no `rungs`, and it **replaces** an existing marker. `hooks/stop-bell.sh`
reads `gate` and `title` and falls back to *"A decision is waiting."* when `title` is absent — so
adopting nen's marker would ring the generic line on every gate and drop the report link out of the
notification entirely.

**The decision the skill recorded as due is therefore taken, and it is to keep `hatsu.stop-marker/v0.1`.**
Recorded here as a **kept residue with its reason**, not an oversight. It lapses the day nen's marker
carries a title, or the day Hatsu decides a generic bell is acceptable — neither of which is a default.
What *is* adopted from the release: `nen parse izanami` now classifies `stop` **write-flag-gated** on
`--mark`, `--mark --template` is exit `2`, and a marker that cannot be written is exit `1` with the errno.

## Retired at nen 0.6 — 2026-09-10

Run against the released `zheref/nen` `v0.6.0` binary (`nen-darwin-arm64`, sha256
`2674dc58…151737e1`, fetched and checksum-verified by `bootstrap/nen.sh --ref v0.6.0`, on `PATH` as
`nen`; `nen --version` → `0.6.0`).

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| the empty `--line` refusal on an all-optional grammar | `nen parse jutaisho --grammar "at [<gate:…>]" --line ""` | **`0`** |
| — the documented alternative, unchanged | the same, `--line "at"` | `0` |
| — a supplied clause, unchanged | the same, `--line "at G5"` | `0` |

```text
$ nen parse jutaisho --grammar "at [<gate:G1|G1-M|G2|G3|G4|G5>]" --line ""
gate: (clause absent)                                                                             # exit 0

$ nen parse jutaisho --grammar "at [<gate:G1|G1-M|G2|G3|G4|G5>]" --line "at"
gate: (clause absent)                                                                             # exit 0

$ nen parse jutaisho --grammar "at [<gate:G1|G1-M|G2|G3|G4|G5>]" --line "at G5"
gate: G5                                                                                          # exit 0
```

**Both spellings parse identically now.** Through `v0.5.0` the empty line was exit `2` — *"the line
must open with the literal 'at' — it is what introduces `<gate>`"*, with the corrected line printed —
while a bare `at` was exit `0` with the clause absent. So the **ordinary** invocation of the
most-invoked step in the whole loop was the one a caller had to be told about, and the refusal read
like a malformed invocation rather than like a spelling note. A headless Cursor run found it by
trying both and recorded the working form (`docs/ab/surfaces.md` § 8, F11 — now marked closed).

**Three things worth carrying into § 1.** The rule is *every slot bracketed*, and it holds whichever
side of the brackets the template writes the separator on (`[onto <slot>]` already worked; `at
[<gate>]` did not). The echo gains a `<name>: (clause absent)` line for an optional slot nobody
filled — because a slot simply MISSING from the echo cannot be told apart from a template that never
declared it, which is how a successful parse of such a grammar used to print nothing at all;
`slots[]` under `--json` is unchanged and still carries only what the line supplied. And a grammar
with a **required** slot is untouched: `nen parse backlog-state --grammar "<repo>[@<gate:…>]" --line
""` still refuses at exit `2` naming `<repo>`.

**`--line "at"` stays documented and stays correct.** It is the same parse; what lapses is having to
know it. § 1 keeps both spellings so a run already written the long way needs no change.

### Nothing retired: the marker's shape, and the hookless-surface cleanup

§ Residue 1, 6 and 8 are unchanged at this pin. `nen stop --mark` still writes
`nen.stop.mark/v0.1` — no `title`, no `body`, no `reportUrl`, no `sound`, no `rungs` — and still
replaces an existing marker, so `hooks/stop-bell.sh` would ring the generic line on every gate.
`hatsu.stop-marker/v0.1` is kept **on purpose**, and the `rm -f` on Codex and Cursor is still by
hand because `nen stop --mark` writes and never removes.
