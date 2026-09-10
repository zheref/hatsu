# A/B evidence — `en` (new skill, wave 3)

`claude/skills/en/SKILL.md`: the capped landing watch — `rikugan`¹ landing → `sharingan`² →
`murasaki`³ when behind base → `sharingan`⁴ → `jutaisho`⁵ at Ready → watch⁶ until merged, reacting
to new reviews and new conflicts by going back to step 2 → `rikugan`⁷ final, written to
`Reports/<date>-<branch>-final.html`.

**A composite, so most of it is a reference — but three things are genuinely en's own and all three
are verified live below:** the invocation's anchored-optional grammar, **the cap** (the value from
`nen/workflow.json` → `monitor.maxCycles`, the *requirement* from `nen parse izanagi`'s grammar), and
**the watch's shape** (the polling verb classifies read-only, and the merge classifies mutating —
so the verb that polls this loop structurally cannot be the verb that ends it).

Run: 2026-09-10 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
`nen parse` is pure; `nen watch until` was invoked once in a form that is refused **before** the first
observation, so nothing was spawned; `nen stop --template` and `nen schema check` are read-only. The
throwaway fixture at `<worktree>/.nen-fixture` was deleted before this branch was committed.
**No GitHub call of any kind was made, and no verb was run against any primary checkout in a way
that could write to it.**

Nothing below is redacted; both repositories are public.

---

## 1. The skill

| En's own step | Owned by | Evidence lives in |
|---|---|---|
| Parse `on <CODE>#<N>` | `nen parse en --grammar "on [<ref>]"` | **§ 2.1, here** |
| **The cap** | `nen parse izanagi` (grammar) + `monitor.maxCycles` (value) | **§ 2.2, here** |
| **The watch's classification** | `nen parse izanami` / `nen watch until` | **§ 2.3, here** |
| The bell's table shape | `nen stop --template` | **§ 2.4, here** |
| The parameter table's pin caveat | `nen schema check` | **§ 2.5, here** |
| Counting cycles 1..N | **nothing — the skill's own bookkeeping** | **§ 2.6, here** |
| 1, 7 · landing and final reports | `hatsu:rikugan` | `docs/ab/rikugan.md` |
| 2, 4 · drive | `hatsu:sharingan` | `docs/ab/drive.md` (that skill's record, under its original name) |
| 3 · catch up | `hatsu:murasaki` | that skill's A/B file |
| 5 · the bell | `hatsu:jutaisho` | `docs/ab/jutaisho.md` |

---

## 2. Verbs exercised live

### 2.1 — `nen parse en`: an anchored optional clause, and why a composite never calls it

```
$ nen parse en --grammar "on [<ref>]" --line "on HA#41"
ref: HA#41
exit=0

$ nen parse en --grammar "on [<ref>]" --line "on"
exit=0

$ nen parse en --grammar "on [<ref>]" --line ""
nen parse: the line must open with the literal 'on' -- it is what introduces <ref>.

Corrected line:
  en on
exit=2

$ nen parse en --grammar "[<ref>]" --line ""
nen parse: template '[<ref>]' is refused: its leading slot <ref> is bracketed but nothing introduces
it, so an omitted value cannot be told apart from a mistyped one. Anchor it behind a literal ('word
[<ref>]') or drop the brackets.
Run 'nen parse --help'.
exit=2
```

**Four transcripts, and the third is the load-bearing one.** The engine's rule — a lone bracketed
slot is refused at the template, so an optional clause needs an introducing literal — is
`docs/ab/rikugan.md` § 2.1's finding, re-confirmed here (fourth transcript). What is **new** is the
third: once the clause is anchored, **the anchor itself becomes required**. `"no clause"` and
`"an empty line"` are different inputs, and only the first parses.

**That is why `mukai` hands the PR to `en` directly and calls `nen parse en` not at all.** Echoing a
parse of a line nobody typed would be theatre; feeding the verb `""` would produce a refusal that
means nothing about the run. The parse runs when, and only when, the maintainer typed a clause —
which is stated in `SKILL.md` § 1 rather than left for a reader to discover from a confusing exit
`2`.

### 2.2 — The cap: the value is configuration, the requirement is grammar

```
$ nen parse izanagi "take HA-PR-#41 to Ready and keep it there until it is merged up to 20"
task: take HA-PR-#41 to Ready and keep it there
until: it is merged
cap: 20
exit=0

$ nen parse izanagi "take HA-PR-#41 to Ready and keep it there until it is merged"
nen: no 'up to <N>'. Izanagi is the MUTATING half of the loop pair and the cap is required grammar,
never defaulted or inferred -- an invocation without it is refused rather than run once 'to see'.
  try: take HA-PR-#41 to Ready and keep it there until it is merged up to <N>
exit=2
```

**Two different things, and the distinction is the design.** `nen/workflow.json` →
`monitor.maxCycles` supplies the **number** (`20`, the default when the key or the file is absent).
`nen parse izanagi` supplies the **requirement**: it refuses a line with no cap, by name, with the
corrected line printed. A repository whose `monitor` block is missing therefore gets `20` **stated
out loud** rather than an unbounded watch — "the file said nothing" being exactly the case where an
inherited-and-forgotten default does damage.

*(This is `izanagi`'s own § 1 transcript set, re-run here against `en`'s actual task text rather
than cited, because the line `en` will spell is the thing being verified — a cap grammar that works
for `gh pr merge … up to 3` and not for a nine-word task description would be a fact worth knowing.
It works.)*

### 2.3 — The watch's classification: the poll is read-only, the merge is not

```
$ nen parse izanami "nen pr ready HA#41 --repo /path --gates /abs/gates.json until it is ready"
until: it is ready
  [read-only] nen pr ready HA#41 --repo /path --gates /abs/gates.json
exit=0

$ nen parse izanami "gh pr view 31 --repo zheref/hatsu --json state -q .state until it is MERGED"
until: it is MERGED
  [read-only] gh pr view 31 --repo zheref/hatsu --json state -q .state
exit=0

$ nen watch until --command "gh pr merge 41" --max-iterations 1
nen: 'gh pr merge 41' classifies as mutating (matches a refused pattern
(^gh\s+(pr|issue)\s+(create|edit|close|merge|comment|review|reopen)\b)). izanami watches only; a
command that writes needs 'nen parse izanagi <task> until <condition> up to <N>' instead.
exit=2
```

And, for completeness, the body write `shibari` § 8 does by hand:

```
$ nen parse izanami "gh pr edit 31 --body-file body.md until it is written"
until: it is written
  [mutating] gh pr edit 31 --body-file body.md
nen: at least one command does not classify as read-only -- the WHOLE run is refused. Use 'nen parse
izanagi <task> until <condition> up to <N>' for a loop that must act.
exit=1
```

**The property worth naming: the verb that polls this loop structurally cannot be the verb that ends
it.** `nen pr ready` and the merge-state read both classify `[read-only]`, so both are legal
`--command`s for `nen watch until`; `gh pr merge` is refused **before the first observation**, at
exit `2`, with the classifier's own regex printed. En's watch can therefore observe its way to the
merge but can never perform it — which is the same rule `SKILL.md`'s first hard limit states, except
that here the tooling enforces it rather than the prose asking for it.

**Note the exit-code split**, which matters when a caller reads these programmatically: `nen watch
until` refuses at `2` (an invocation refused before the loop started), while `nen parse izanami`
reports at `1` (the line parsed; a command failed classification). `izanami` § 1's table has both.

### 2.4 — `nen stop --template`: the five-column shape the bell fills

```
$ nen stop --template
| Effort  | Open issues & PRs | Status (gate)   | Thought flow | Session / lane |
| ------- | ----------------- | --------------- | ------------ | -------------- |
| <title> | <link>            | <status (gate)> | <one line>   | <session>      |
exit=0
```

Read-only, spawns nothing. The banner and the table are `jutaisho` § 4's, not en's — this transcript
is here because `SKILL.md` § 5 quotes the shape, and a quoted shape that nobody ran is a shape that
drifts. **En restates none of the four-part stop protocol**; it names the step and the gate.

### 2.5 — `nen schema check` still has no `nen/workflow.json` row

```
$ nen schema check --repo .
repository: <worktree>
  FAIL  nen/labels.json    ... no such file ...
  FAIL  nen/repos.json     ... no such file ...
  FAIL  nen/colors.yml     ... no such file ...
  warn  nen/gates.json     ... no such file ...
  ok    nen/contract.json  dependency (nen >= 0.3, pinned v0.3.0), project (1 lane: plugin; 10 verbs; 1 toolchain entry)
nen: this repository's taxonomy could not be read. …
exit=1
```

**`monitor.maxCycles` and `monitor.pollSeconds` are unvalidated at this pin** — the loader is P1 and
lands with the `v0.4` line. En reads them as data and states the defaults (`20`, `300`) whenever they
are what applied. Same five rows as `docs/ab/rikugan.md` § 2.4 and `docs/ab/mukai.md` § 2.2.

### 2.6 — Nothing counts the cycles, and `--max-iterations` is not the cap

`nen watch until --help`, read live, in the verb's own words:

```
  --max-iterations  a SAFETY bound, not izanagi's mandatory cap (izanami needs
                  none -- it can compound no mistake). Omit for an unbounded
                  watch; three consecutive observation ERRORS stop the run
                  regardless.
exit=0
```

**The verb says it itself, which is why `SKILL.md` § 6 can state it without a rule of its own.**
`--max-iterations` bounds **one observation** — en passes `1`, making each poll single-shot, exactly
as `izanagi` § 3 composes it. **Counting acting cycles 1..N against `monitor.maxCycles` is the
skill's own bookkeeping**, and no verb does it: `nen parse izanagi` extracts and refuses on `N` once,
at parse time, before cycle 1, and never sees a cycle. That is `izanagi` § 3's finding, inherited
here unchanged, and it is en's residue entry 2.

The same `--help` also documents the two flags en's watch depends on, and both are quoted rather
than paraphrased in the skill: `--interval-ms` (default `5000`; en passes
`monitor.pollSeconds × 1000`, so `300000`) and the direct, shell-less spawn — *"`<bin>` must be a
real executable on PATH … a pipeline is not a command it can classify — one observation, one
program."*

---

## 3. Residue

1. **The composition itself has no verb** — `docs/ab/ren.md` § 2.2, cited rather than re-proven.
   **En adds no residue of its own**: every deterministic step inside a cycle is a verb or a named
   residue *in the skill that owns it* — the absent `nen report data` / `nen report render`
   (steps 1 and 7, `docs/ab/rikugan.md` § 3), `nen pr ready`/`body-check`/`staleness` plus the two
   verbs `sharingan` refuses to call for a verdict (steps 2 and 4, `docs/ab/drive.md`),
   `nen pr cascade-main` and its missing `--no-push` (step 3, `docs/ab/ao.md`), `nen stop` plus the
   `osascript`/`afplay` fallback and the `.nen/last-stop.json` marker (step 5,
   `docs/ab/jutaisho.md`).
2. **Counting cycles against the cap is the skill's own bookkeeping** (§ 2.6). Nen supplies a
   parsed, refusal-enforced `N` and a mechanical per-check truth reading; the ledger and the stop at
   `N` are en's.
3. **`nen/workflow.json` is unvalidated at `v0.3.0`** (§ 2.5) — `monitor` included.
4. **A watch that survives the session has no mechanism at all** — and this one is not a missing
   *verb*. At the time of the run it was also a missing **role**; `claude/agents/illumi.md` landed
   later in this same wave and closed that half. See § 4.2 and its § *Update*.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — An anchored optional clause makes its anchor mandatory, and nothing says so up front

§ 2.1's third transcript. `nen parse --help` and the template refusal both push a caller toward
`word [<slot>]` as the fix for a bare bracketed slot, and that is correct — but neither says that the
resulting grammar then **refuses an empty line**. The refusal itself is clear once you hit it
(*"the line must open with the literal 'on'"*, with a corrected line), so this is a documentation
observation and not a defect: the engine is consistent, and "an omitted clause" in this grammar means
*the anchor with nothing after it*, not *nothing at all*. **Recorded because every optional clause in
this wave and the last one has the same shape** (`rikugan as`, `jutaisho at`, `ao from`, `en on`), so
any composite invoking one of those skills programmatically will meet it.

### 4.2 — `en`'s long watch is a missing ROLE, not a missing verb, and it is a maintainer's OPEN question

**Read as of the run above — 2026-09-10, at the point in this wave where `en` was written and before
`claude/agents/illumi.md` had been added to the branch.** The § *Update* below says what changed and
when; the reading is left standing rather than rewritten, because a record that describes a tree it
never saw is not evidence.

`docs/ROSTER.md` § *Rulings* 5 partially closes `OPEN-1`: *"Illumi is provisioned for `en`'s long
watch, and only when one is needed … Provisioned means he may be stood up for that work when the work
exists; it does not mean a definition exists."* **There was no `claude/agents/illumi.md` when this was
observed**, and no primitive anywhere in this plane defers work past a session — `docs/ab/ren.md`
§ 2.2 establishes that neither of nen's two loop primitives can, and a harness `Stop` hook fires after
a turn rather than scheduling one.

**So the honest behaviour is to name the gap and hand back at the cap**, which `SKILL.md` § 7 stated
and § *Hard limits* enforced. **Filing this as a nen defect would be the wrong move**: nen supplying
an unattended long-running watch would close a maintainer's OPEN roster question by shipping a
capability, which is exactly the attrition `claude/agents/kurapika.md` § *An OPEN item stays OPEN*
forbids. Recorded here so the absence reads as a ruling waiting to be made rather than a tool waiting
to be built.

> **Update — later in this same wave, `v0.5.0`.** `claude/agents/illumi.md` **landed on this branch**,
> on the reasoning `docs/ROSTER.md` § *Rulings* 5 gives: a provision that cannot be executed is a
> provision in name only, and `en` shipped in the same wave. **So the half of this finding about the
> missing role is closed**, and `SKILL.md` § 7 now describes the hand-off — step 6 to a subagent
> titled `en · illumi · <model alias>`, read-only, waking Kurapika and acting on nothing.
> **The other half stands unchanged, and it is the half that was ever about a mechanism**: a delegate
> is still raised *from* a session, so nothing in this plane makes a watch survive one. And the rest
> of Illumi's row — `backlog-loop`, `futon`, `senkei` — plus the whole of Killua's, remain **OPEN**.
> Nothing is filed against the binary here either way. Raised by the Copilot review round on
> `zheref/hatsu#31`
> ([thread](https://github.com/zheref/hatsu/pull/31#discussion_r3976460616)), which caught the record
> reading as though it described the shipped tree.

### 4.3 — The classifier makes en's first hard limit mechanical, which is unusual and worth preserving

§ 2.3. Almost every "never" in this plane's skills is prose with nothing under it — `docs/ab/ren.md`
§ 4.4 makes the general point. **En's is the exception**: its sharpest limit (*never merges*) is
enforced by the one verb its watch is built on, because `gh pr merge` is on `nen watch until`'s
refused list and is rejected before the first observation. That is an accident of composition rather
than a designed guarantee — en could still shell out to `gh pr merge` outside the watch — but the
loop's *natural* shape has no path to the merge, and a natural shape with no path is worth more than
a rule with one. **Recorded as a property to preserve** the day someone proposes letting `watch
until` take a mutating command "just for the terminal step".

### 4.4 — A cycle is not an observation, and no verb can tell them apart

`SKILL.md` § 6 defines a cycle as an **act** — a return to step 2, a pushed fix, a re-requested
review — and explicitly excludes an observation that found nothing, plus `izanagi`'s *iteration 0*
pre-check. **Nothing mechanical distinguishes these**: `nen watch until` prints one line per
observation and knows nothing about whether the caller acted afterwards. The arithmetic matters —
at the defaults, a poll every `300` seconds would exhaust a cap of `20` in **100 minutes** if every
observation counted, which for a PR waiting on a human reviewer is a cap-out that says nothing about
the PR. **The rule is stated in the skill and counted by the skill**, and this entry exists so a
reader knows the number in the report is a count of *actions*, not of *minutes*.
