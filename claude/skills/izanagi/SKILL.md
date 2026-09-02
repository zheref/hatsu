---
name: izanagi
description: Repeat a task that ACTS until a condition holds, under a mandatory iteration cap. Use when the maintainer invokes hatsu:izanagi <task> until <condition> up to <N>, or asks to keep doing something until it is done. The cap is required grammar, not a default — an invocation without "up to <N>" is refused. Each iteration runs under its own authority; a human gate ends the loop rather than being retried past.
---

# Izanagi — act until it is true, and never more than N times

**Nature:** whatever the looped task is — name Kurapika's work-mode for it (Enhancer, Conjurer,
Transmuter, Manipulator, Emitter, Specialist), and name it again if an iteration's task switches
modes.

> **Keep doing this until that is true — and stop after N tries no matter what.**

Izanagi is the **mutating** half of the loop pair; [`hatsu:izanami`](../izanami/SKILL.md) is the
read-only half. The split is deliberate: a loop that writes needs a bound a loop that reads does
not, and **making the bound part of the grammar means it can never be defaulted, inherited, or
forgotten.**

The old bankai-core skill enforced the cap and the parse by an agent reading its own prose grammar
by eye, every invocation. This port replaces the parse and the per-iteration condition check with
`nen`: `nen parse izanagi` splits the line and refuses outright when the cap is missing or
malformed, and `nen watch until` — the same read-only observation engine `izanami`'s port uses —
evaluates the condition, run single-shot per iteration. **What `nen` does not own, verified live
below, is the loop's mutating half**: the act itself, and counting acting-iterations 1..N against
the cap. Both stay exactly where the old skill's prose kept them — with the skill.

---

## 1. Invocation — `nen parse izanagi` does the split, the cap is required

```
hatsu:izanagi <task description> until <condition> up to <N>
```

Before iteration 1, echo the parse through the verb itself:

```bash
nen parse izanagi "<the invocation line>"
```

`nen parse izanagi` (no `--grammar` — it is one of the three built-in grammars, alongside `futon`
and `izanami`; verified live, `--grammar`/`--line` are refused for it with "parse izanagi takes the
invocation string") matches `until` and `up to` **case-insensitively, as the LAST whole-word
occurrence of each**, and echoes `task:` / `until:` / `cap:` back before anything runs.

**Verified live, a well-formed invocation:**

```
$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core until it is merged up to 3"
task: gh pr merge 925 --repo zheref/bankai-core
until: it is merged
cap: 3
$ echo $?
0
```

**Case-insensitive, last-occurrence matching of both `until` and `up to` — verified live** (an
earlier stray "UNTIL"/"UP TO" inside the task text does not win):

```
$ nen parse izanagi "gh pr merge 925 UNTIL first mention it is merged UNTIL second mention really merged UP TO 5"
task: gh pr merge 925 UNTIL first mention it is merged
until: second mention really merged
cap: 5
$ echo $?
0
```

**There is only ONE grammar shape** — unlike `izanami`, which publishes a second `until
<condition>` + following-command-lines form, `nen parse izanagi` accepts no such alternate; the
single-line form above is the whole grammar (verified live: feeding it `izanami`'s two-line shape
does not parse as a task/commands split — it is read as trailing text after `up to`, and fails the
integer-cap check instead). Never offer a second form to the maintainer; there isn't one.

**The missing-cap case — the load-bearing refusal, verified live:**

```
$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core until it is merged"
nen: no 'up to <N>'. Izanagi is the MUTATING half of the loop pair and the cap is required grammar, never defaulted or inferred -- an invocation without it is refused rather than run once 'to see'.
  try: gh pr merge 925 --repo zheref/bankai-core until it is merged up to <N>
$ echo $?
2
```

Do not infer a cap from the task, do not offer to pick one, and do not run "just once" to see. Relay
this refusal and its corrected line **exactly** — this is the one case that makes the whole grammar
mean something, and it is `nen`'s to enforce now, not the agent's to remember.

**Missing `until`, and a malformed cap — both refused, verified live:**

```
$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core up to 3"
nen: no 'until <condition>'. Expected '<task> until <condition> up to <N>'.
  try: gh pr merge 925 --repo zheref/bankai-core until <condition> up to 3
$ echo $?
2

$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core until it is merged up to zero"
nen: 'up to zero' is not a positive integer cap.
  try: gh pr merge 925 --repo zheref/bankai-core until it is merged up to 3
$ echo $?
2

$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core until it is merged up to 0"
nen: 'up to 0' is not a positive integer cap.
  try: gh pr merge 925 --repo zheref/bankai-core until it is merged up to 3
$ echo $?
2
```

**Minor observation, not a routing rule:** the corrected line on an invalid (non-integer or zero)
cap always suggests `up to 3` verbatim, regardless of what was typed — it is a syntactic placeholder,
not a proposed value. Never present it to the maintainer as `nen`'s recommended cap; ask for a real
one instead.

If the task is entirely read-only, say so and point at [`hatsu:izanami`](../izanami/SKILL.md), which
needs no cap and no confirmation. Running a read-only watch through izanagi is harmless but buys a
ceiling nobody needed.

**`nen parse izanagi` runs no classifier over the task — verified live**, unlike `nen parse izanami`
(which tags every command `[read-only]`/`[mutating]`/`[unknown]` and refuses on a bad tag). Feeding
`izanagi` a task that looks read-only still parses fine — there is nothing here to gate, because
izanagi's task is *expected* to mutate:

```
$ nen parse izanagi "gh pr checks 925 --repo zheref/bankai-core until all green up to 4"
task: gh pr checks 925 --repo zheref/bankai-core
until: all green
cap: 4
$ echo $?
0
```

This is why **§ 1's single confirmation is what stands guard here instead of a classifier** — echo
the full parse (task, condition, cap) and take **one confirmation** before iteration 1. This is the
only confirmation the run takes on its own account, and it is what makes the rest of it autonomous,
so it must show exactly what will happen up to N times.

## 2. Authority — per iteration, never accumulated

**Izanagi grants nothing of its own.** Every iteration runs the looped task under **that task's own
authority, resolved fresh** — hatsu carries no ratified run-scoped delegation grammar yet
(`docs/delegation-grammar-DRAFT.md` is explicitly **DRAFT, NOT RATIFIED**), so nothing about
izanagi's own up-front confirmation stands in for, or widens, what Kurapika's own per-action rule
already requires (`claude/agents/kurapika.md`: "Gate labels: per action by default… a 'go ahead' for
one issue is not authority for the next"):

- A looped `hatsu:build` *(lands with a later port of hatsu#2)* would hold `build`'s own delegation
  for that iteration only, lapsing when the iteration ends.
- A looped `hatsu:drive` *(lands with a later port of hatsu#2)* holds no routing or release
  delegation at all — that is `drive`'s own scope.
- A looped `hatsu:file` or a backlog-synthesis skill *(both land with a later port of hatsu#2)* still
  **present their plan and take their own confirmation** — izanagi's single up-front confirmation
  does **not** stand in for it. A loop that pre-approves N unseen plans is not a loop with oversight.
- A looped `hatsu:tensho` or `hatsu:jujisho` *(both land with a later port of hatsu#2)* — same rule:
  their own PR-posting and split confirmations are never waived by izanagi's.

**The confirmation in § 1 authorizes the repetition, not the contents.** Anything the looped task
would have asked for on its own, it still asks for.

**Log every mutating action** — object, action, iteration number, time — and report the whole log
when the run ends. An unlogged write inside a loop is the one thing nobody can reconstruct
afterwards. No `nen` verb keeps this ledger for izanagi the way `nen label apply`'s own ledger does
for a single label call; it is the skill's own bookkeeping across the whole run.

## 3. The loop — what `nen` owns, and what stays with the skill

Each iteration, in order:

1. **Re-read live state and evaluate the condition FIRST**, before acting. Never act on the
   previous iteration's picture; that is how a loop repeats an action that already succeeded. If
   the condition already holds, stop — iteration 0 counts.
2. **Run the task**, under § 2.
3. **Re-evaluate**, and report **one line**: iteration number, what was done, what changed, and the
   condition's current value.

**Step 1 and step 3's condition check reuse `nen watch until`, single-shot, per iteration** — the
exact same read-only observation engine and truth semantics `izanami`'s port uses, rather than
hand-rolled pattern matching:

```bash
nen watch until --command "<the read-only condition check>" [--true-pattern <regex>] \
  --max-iterations 1 [--interval-ms <ms>] [--cwd <path>]
```

`--max-iterations 1` makes this exactly one observation: exit `0` means the condition is already
true, exit `1` means "not yet true" (never treated as an error), and an observation error is
reported and relayed as such, never silently folded into "not yet". **Verified live**, the same
condition false, then true, then reused against a real target:

```
$ nen watch until --command "git diff" --true-pattern "DONE" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is not yet true (exit 0)
nen: stopped at the --max-iterations bound (1) without the condition becoming true
$ echo $?
1

$ echo DONE >> watched.txt
$ nen watch until --command "git diff" --true-pattern "DONE" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is true (exit 0)
condition became true after 1 observation(s)
$ echo $?
0

$ export GH_TOKEN=$(gh auth token)
$ nen watch until --command "gh pr view 925 --repo zheref/bankai-core --json state -q .state" --true-pattern "OPEN" --max-iterations 1 --interval-ms 1000
[1] condition is true (exit 0)
condition became true after 1 observation(s)
$ echo $?
0
```

**The composition boundary, verified live: `nen watch until` REFUSES the act itself.** Handing it
the task instead of the condition check — even a plain `git add`, which is not on the classifier's
refused list, only its unrecognized one — is refused outright, redirecting to `izanagi`'s own parse
verb:

```
$ nen watch until --command "git add watched.txt" --true-pattern "x" --max-iterations 1 --cwd . --interval-ms 100
nen: 'git add watched.txt' classifies as unknown (matches neither izanami's allowlist nor a named refusal -- an unrecognized command is never assumed safe). izanami watches only; a command that writes needs 'nen parse izanagi <task> until <condition> up to <N>' instead.
$ echo $?
2
```

**This proves the act can never be routed through `nen watch until` — by design, not by omission.**
The verb that owns condition-polling is read-only on purpose (`izanami`'s whole safety property); a
loop that acts needs a different mechanism for the act, and `nen` does not supply one, because the
act is exactly the part that only the looped task's own machinery (a skill invocation, a `gh`/`git`
mutation under its own review) can be trusted to run under its own authority (§ 2). **The skill runs
the act directly, between condition checks — never through `watch until`.**

**Finding: no `nen` verb enforces izanagi's mandatory N-iteration cap over the acting loop.**
`nen parse izanagi` extracts and refuses on `N` exactly once, at parse time, before iteration 1 — it
does not run a loop and cannot enforce anything across iterations it never sees. `nen watch until
--max-iterations` is a **different, unrelated bound**: `--help` states it plainly — "a SAFETY bound,
not izanagi's mandatory cap" — and it belongs to the read-only watch verb's own internal polling.
Reused single-shot per iteration above, it bounds *one condition check*, not the count of *acting*
iterations. **Counting 1..N mutating iterations and stopping at the cap is the skill's own
responsibility**, exactly as it was in the old skill's prose loop — `nen` gives it a parsed,
refusal-enforced `N` to count against, and a mechanical per-check truth reading, but the counting
itself is not delegated to any verb.

**Verified live — the full composed loop, converging before the cap** (`cap: 5`, condition becomes
true on the act itself, at iteration 3):

```
$ nen parse izanagi "append a line to watched.txt until watched.txt contains DONE up to 5"
task: append a line to watched.txt
until: watched.txt contains DONE
cap: 5

--- iteration 1 ---
$ nen watch until --command "git diff" --true-pattern "DONE" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is not yet true (exit 0)
$ echo "attempt 1" >> watched.txt
$ nen watch until --command "git diff" --true-pattern "DONE" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is not yet true (exit 0)
report: [1] appended 'attempt 1'; condition not yet true

--- iteration 2 ---
$ echo "attempt 2" >> watched.txt
$ nen watch until --command "git diff" --true-pattern "DONE" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is not yet true (exit 0)
report: [2] appended 'attempt 2'; condition not yet true

--- iteration 3 ---
$ echo DONE >> watched.txt
$ nen watch until --command "git diff" --true-pattern "DONE" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is true (exit 0)
report: [3] appended 'DONE'; condition TRUE -- stop, cap (5) not reached
```

**Verified live — the cap-out case** (`cap: 3`, the condition never becomes true; full transcript in
`docs/ab/izanagi.md` § 2.4):

```
report: [1] appended 'attempt 1'; condition not yet true
report: [2] appended 'attempt 2'; condition not yet true
report: [3] appended 'attempt 3'; condition not yet true
cap (3) reached without the condition becoming true -- stop.
```

## 4. Stopping — five ways, and four of them are not the cap

| Stop | Rule | What's mechanical vs. judgment |
|---|---|---|
| **Condition true** | The success case. Report what became true and the evidence | The evidence is `nen watch until`'s own matching stdout / exit code (§ 3) |
| **Cap reached** | Stop at `N`. Report **what is still not true and what the next iteration would have done** — a cap-out that only says "gave up" wastes everything the run learned | The count-to-`N` is the skill's own bookkeeping (§ 3's finding); `nen` supplies the parsed, refused-if-missing `N` to count against |
| **No progress** | **3 consecutive iterations that change nothing** end the run, even below the cap. A loop repeating a no-op is not converging; it is burning the cap to reach the same place | Pure judgment — no `nen` verb detects "no-op"; the skill compares each iteration's before/after state itself |
| **A human gate** | **G1–G5 ends the loop.** It is never retried past, never worked around, and never "tried once more in case". A gate is a stop for the maintainer; looping through one would manufacture consent by repetition | Pure judgment — `kurapika.md`'s gate discipline, unchanged by looping |
| **Impossible condition** | Named, not waited on — a closed PR will not go green. Stop and say why | Pure judgment, same discipline `izanami`'s port keeps (its own § 4) |

**The cap is a ceiling, not a target.** Reaching it is a failure to converge and is reported as one.

## 5. Reporting

**One line per iteration, no banner** — a loop in progress is not a gate event. `nen watch until`'s
own per-check line (`[1] condition is/is not yet true (exit N)`) is internal to the condition-check
step (§ 3); the skill's own reported line per iteration is the one in the transcripts above —
iteration number, what was done, what changed, the condition's current value.

**The banner fires when the run ends and the maintainer is needed**: a gate stop, a cap-out, a
no-progress stop, or an impossible condition. Render it with `nen stop` (`--who`, `--gate`, an
efforts table) exactly as every other Kurapika stop does. The end-of-run report carries the outcome,
the iteration count, **every mutating action logged** (§ 2), and — where it did not converge — what
remains and the recommended next step.

## 6. Hard limits

- **Never runs without an explicit `up to <N>`** — `nen parse izanagi` refuses it (§ 1); relay the
  refusal, never route around it.
- **Never raises its own cap mid-run**, and never restarts itself to get more iterations.
- **Never retries past a human gate.**
- **Never substitutes its confirmation for a looped skill's own** plan confirmation (§ 2).
- **Never accumulates authority across iterations** — each resolves fresh and lapses (§ 2).
- **Never routes the act through `nen watch until`** — verified live (§ 3) to refuse it outright;
  the act runs directly, under the looped task's own machinery.
- **Never merges `main`, never applies a G1 mode label, never casts a review vote** — the looped
  task's limits are the loop's limits, and looping cannot widen them (`kurapika.md`'s Manipulator
  rules, unchanged by looping).
- **Never reports convergence it did not observe** — the condition's evidence from `nen watch until`,
  or it did not happen.
