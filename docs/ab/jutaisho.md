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
