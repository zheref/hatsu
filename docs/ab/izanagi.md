# A/B evidence — `izanagi` (zheref/hatsu#2)

Port of `claude/skills/izanagi/SKILL.md`: the mutating "act until true, under a mandatory cap" loop.
Old mechanics: a hand-authored grammar applied by eye per invocation (split on the last whole-word
`until` and `up to`, refuse a missing cap by remembering to), plus a hand-written 4-step loop
(evaluate, act, re-evaluate, report) with the iteration count tracked in the agent's own head. New
mechanics: `nen parse izanagi` (the invocation split, and the cap refusal) and `nen watch until`
(the read-only condition check, reused single-shot per iteration) — the act itself, and the
1..N iteration count, stay with the skill; see § 4's findings for exactly why.

Run: 2026-09-01, this session. `nen` `0.1.0`
(`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`). `gh` authenticated as `zheref`
(`GH_TOKEN=$(gh auth token)` exported for the one live bankai-core read below). Old skill source:
`refpack/skills/izanagi.SKILL.md` (bankai-core `v0.11.3`-era). No shell oracle exists for izanagi,
same as `izanami` — the old skill's "parse" and "loop" steps were pure agent prose, never a script,
so there is no old-side command to run in parallel; the A/B here is against that prose, by contract,
plus every `nen` transcript below run against the real binary. **Nothing was mutated against
zheref/bankai-core** — every bankai-core call below is a read (`gh pr view … --json state`), and
every genuinely mutating demonstration runs against a disposable local scratch git repository
(`/tmp/izanagi-scratch/repo`), never against bankai-core or hatsu itself.

---

## 1. Command mapping table

| # | Old (prose, applied by the agent by hand) | New (`nen`) |
|---|---|---|
| 1 | Split `<task> until <condition> up to <N>` on the LAST whole-word `until` and `up to`, matched case-insensitively — described in prose, performed by the agent reading the line | `nen parse izanagi "<line>"` splits it, echoes `task:`/`until:`/`cap:`, verified live (§ 2.1) |
| 2 | "The cap is required — an invocation without it is refused" — a rule stated in prose, enforced by the agent remembering to check for it every time | `nen parse izanagi` refuses a missing `up to <N>` mechanically, exit `2`, with the corrected line ready to paste — verified live (§ 2.2), the load-bearing case |
| 3 | Reject a non-integer or non-positive cap — implied by "a positive integer" in prose, never mechanically checked | `nen parse izanagi` refuses `up to zero` and `up to 0` identically, exit `2` (§ 2.3) |
| 4 | "Echo the full parse before iteration 1" — the agent's own paraphrase of task/condition/cap | `nen parse izanagi`'s own stdout IS the echo — `task:`/`until:`/`cap:` printed verbatim, nothing to reconstruct |
| 5 | Evaluate the condition each iteration ("re-read live state… evaluate first") — hand-run by the agent, one observation at a time, in its own words. The old skill's step 1 carried an explicit stale-state warning ("Never act on the previous iteration's picture; that is how a loop repeats an action that already succeeded.") — dropped from an earlier draft of the ported SKILL.md's § 3 step 1 and restored verbatim on review | `nen watch until --command "<check>" --true-pattern … --max-iterations 1` runs exactly one observation and reports true/not-yet/error mechanically, reusing `izanami`'s own engine (§ 2.5); the stale-state warning itself stays prose (SKILL.md § 3 step 1) — no `nen` verb owns "don't act on a stale picture" |
| 6 | Track the iteration count against `N` and stop there — done in the agent's head, one increment per loop turn | **Not replaced** — see finding 1, § 4. `nen parse izanagi` gives a parsed, refusal-enforced `N`; no verb counts against it across a running loop |
| 7 | Run the task itself | **Not replaced, and structurally cannot be** — `nen watch until` refuses a mutating/unknown `--command` outright (verified live, § 2.6); the act stays the looped task's own machinery under its own authority |
| 8 | "3 consecutive no-op iterations end the run" — a rule stated in prose | **Not replaced** — no `nen` verb detects a no-op iteration; judgment, unchanged |
| 9 | "A human gate ends the loop, never retried past" — a rule stated in prose | **Not replaced** — judgment, unchanged (`kurapika.md`'s gate discipline) |
| 10 | "An impossible condition is named, not waited on" — a rule stated in prose | **Not replaced** — judgment, unchanged (same discipline `izanami`'s port already carries) |
| 11 | Log every mutating action (object, action, iteration, time) — the agent's own running note | **Not replaced** — the skill's own ledger; no `nen` verb keeps a per-run mutation log for izanagi the way `nen label apply --ledger` does for one label call |

**Count.** Before: **5** steps performed by the agent, in prose, per invocation (rows 1–5: splitting
the line, enforcing the cap's presence, enforcing its shape, echoing the parse, and evaluating the
condition by hand each iteration). After: **0** of those five remain hand-done — `nen parse izanagi`
and `nen watch until` (single-shot, reused per iteration) now compute and enforce all five
mechanically, verified live below. What remains (rows 6–11) is **not** a shortfall of the port: rows
7 and 8–10 are genuinely un-ownable by a read-only/parse-only binary (the act itself, and three
judgment calls the old skill also left to the agent), and row 6 is § 4's explicit finding — a real
gap between what the grammar enforces at parse time and what the loop needs enforced across time.

---

## 2. Live transcript

### 2.1 — `nen parse izanagi`, the one valid shape, both matching rules verified

```
$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core until it is merged up to 3"
task: gh pr merge 925 --repo zheref/bankai-core
until: it is merged
cap: 3
$ echo $?
0
```

Case-insensitive `until`/`up to`, matched as the LAST whole-word occurrence of each — a stray earlier
mention inside the task text does not win:

```
$ nen parse izanagi "gh pr merge 925 UNTIL first mention it is merged UNTIL second mention really merged UP TO 5"
task: gh pr merge 925 UNTIL first mention it is merged
until: second mention really merged
cap: 5
$ echo $?
0
```

`--json` form:

```
$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core until it is merged up to 3" --json
{
  "task": "gh pr merge 925 --repo zheref/bankai-core",
  "condition": "it is merged",
  "cap": 3
}
$ echo $?
0
```

**Only one grammar shape exists** — verified by trying `izanami`'s second (multi-line) form, which
does not parse as task/commands the way it does for `izanami`; it is read as trailing text on the
`up to` clause and fails the integer check:

```
$ nen parse izanagi $'until it is merged up to 3\ngh pr merge 925 --repo zheref/bankai-core'
nen: 'up to 3
gh pr merge 925 --repo zheref/bankai-core' is not a positive integer cap.
  try: until it is merged up to 3
$ echo $?
2
```

`--grammar`/`--line` are refused for the built-in grammars, confirming `izanagi` (like `futon` and
`izanami`) takes no template:

```
$ nen parse izanagi --grammar "<task> until <condition> up to <N>" --line "gh pr merge 925 until it is merged up to 3"
nen parse: parse izanagi takes the invocation string, e.g. 'retry the build until it is green up to 3'.
Run 'nen parse --help'.
$ echo $?
2
```

### 2.2 — the missing-cap REFUSAL (load-bearing case)

```
$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core until it is merged"
nen: no 'up to <N>'. Izanagi is the MUTATING half of the loop pair and the cap is required grammar, never defaulted or inferred -- an invocation without it is refused rather than run once 'to see'.
  try: gh pr merge 925 --repo zheref/bankai-core until it is merged up to <N>
$ echo $?
2
```

This is the case the whole grammar exists to make load-bearing: `nen` refuses to run once "to see",
never infers a cap from the task, and hands back a corrected line rather than a bare error.

### 2.3 — invalid shapes

Missing `until` entirely:

```
$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core up to 3"
nen: no 'until <condition>'. Expected '<task> until <condition> up to <N>'.
  try: gh pr merge 925 --repo zheref/bankai-core until <condition> up to 3
$ echo $?
2
```

Non-integer cap:

```
$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core until it is merged up to zero"
nen: 'up to zero' is not a positive integer cap.
  try: gh pr merge 925 --repo zheref/bankai-core until it is merged up to 3
$ echo $?
2
```

Zero cap — refused identically to a non-integer cap, not treated as "a valid but degenerate N":

```
$ nen parse izanagi "gh pr merge 925 --repo zheref/bankai-core until it is merged up to 0"
nen: 'up to 0' is not a positive integer cap.
  try: gh pr merge 925 --repo zheref/bankai-core until it is merged up to 3
$ echo $?
2
```

**Observation, not a finding:** the corrected line on both invalid-cap cases suggests `up to 3`
verbatim regardless of the input — a fixed placeholder, not a computed suggestion. The SKILL.md (§ 1)
tells the reader never to present this as `nen`'s recommended value.

### 2.4 — `nen watch until --max-iterations`, the cap bound demonstrated (constructed condition)

`--max-iterations` here is `nen watch until`'s **own** safety bound on its read-only polling loop —
not izanagi's mandatory cap (see § 4, finding 1) — but the mechanism it uses to stop is the same one
this evidence leans on to demonstrate a bound being reached. Local scratch repo
(`/tmp/izanagi-scratch/repo`, one committed file `watched.txt`), a background process appends the
matching text after the bound would already have expired:

```
$ git init -q repo && cd repo
$ echo line1 > watched.txt && git add watched.txt && git commit -q -m init
$ ( sleep 15; echo "line2 appended" >> watched.txt ) &
$ nen watch until --command "git diff --stat" --true-pattern "watched.txt" --interval-ms 2000 --max-iterations 3 --cwd .
[1] condition is not yet true (exit 0)
[2] condition is not yet true (exit 0)
[3] condition is not yet true (exit 0)
nen: stopped at the --max-iterations bound (3) without the condition becoming true
$ echo $?
1
```

**Full composed loop, demonstrating izanagi's OWN mandatory cap** (which `nen` does not enforce —
the skill counts it), reusing `nen watch until --max-iterations 1` as the per-iteration condition
check:

Converging before the cap (`cap: 5`, condition becomes true on the act at iteration 3):

```
$ nen parse izanagi "append a line to watched.txt until watched.txt contains DONE up to 5"
task: append a line to watched.txt
until: watched.txt contains DONE
cap: 5

--- iteration 1 ---
$ nen watch until --command "git diff" --true-pattern "DONE" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is not yet true (exit 0)
nen: stopped at the --max-iterations bound (1) without the condition becoming true
$ echo $?
1
$ echo "attempt 1" >> watched.txt
$ nen watch until --command "git diff" --true-pattern "DONE" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is not yet true (exit 0)
$ echo $?
1
report: [1] appended 'attempt 1'; condition not yet true

--- iteration 2 ---
$ echo "attempt 2" >> watched.txt
$ nen watch until --command "git diff" --true-pattern "DONE" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is not yet true (exit 0)
$ echo $?
1
report: [2] appended 'attempt 2'; condition not yet true

--- iteration 3 ---
$ echo DONE >> watched.txt
$ nen watch until --command "git diff" --true-pattern "DONE" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is true (exit 0)
condition became true after 1 observation(s)
$ echo $?
0
report: [3] appended 'DONE'; condition TRUE -- stop, cap (5) not reached
```

Cap-out (`cap: 3`, the condition never becomes true — a fresh scratch file, watching for `FINISHED`
instead of `DONE`):

```
$ nen parse izanagi "append a line to watched.txt until watched.txt contains FINISHED up to 3"
task: append a line to watched.txt
until: watched.txt contains FINISHED
cap: 3

--- iteration 1 ---
$ echo "attempt 1" >> watched.txt
$ nen watch until --command "git diff" --true-pattern "FINISHED" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is not yet true (exit 0)
report: [1] appended 'attempt 1'; condition not yet true

--- iteration 2 ---
$ echo "attempt 2" >> watched.txt
$ nen watch until --command "git diff" --true-pattern "FINISHED" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is not yet true (exit 0)
report: [2] appended 'attempt 2'; condition not yet true

--- iteration 3 ---
$ echo "attempt 3" >> watched.txt
$ nen watch until --command "git diff" --true-pattern "FINISHED" --max-iterations 1 --cwd . --interval-ms 100
[1] condition is not yet true (exit 0)
report: [3] appended 'attempt 3'; condition not yet true

cap (3) reached without the condition becoming true -- stop.
What remains not true: watched.txt does not contain FINISHED.
What iteration 4 would have done: append another attempt line.
```

Both runs are genuine — the mutating "act" (`echo … >> watched.txt`) runs directly in the shell, at
no point handed to any `nen` verb, exactly as § 3's composition boundary requires.

### 2.5 — the condition check, reused against a real bankai-core read (read-only)

```
$ export GH_TOKEN=$(gh auth token)
$ nen watch until --command "gh pr view 925 --repo zheref/bankai-core --json state -q .state" --true-pattern "OPEN" --max-iterations 1 --interval-ms 1000
[1] condition is true (exit 0)
condition became true after 1 observation(s)
$ echo $?
0
```

`zheref/bankai-core#925` was open at run time (`gh pr list --repo zheref/bankai-core --state open`
listed `#925` and `#940` at this run), so the single-shot check reads true on its first observation —
this is a read against the live repository, never a write.

A real (never executed) mutating task parsed against a live bankai-core object, to confirm `nen parse
izanagi` accepts a genuinely mutating task without classifying it (§ 2.6 for why):

```
$ nen parse izanagi "nen wake fire --repo-slug zheref/bankai-core --ref BC-PR-#925 --label bankai:iterate --run until PR 925's checks are all green up to 3"
task: nen wake fire --repo-slug zheref/bankai-core --ref BC-PR-#925 --label bankai:iterate --run
until: PR 925's checks are all green
cap: 3
$ echo $?
0
```

This task was **only parsed, never run** — per the shared brief, a mutating verb is never exercised
against bankai-core from this session.

### 2.6 — the composition boundary: `nen watch until` refuses the act

```
$ nen watch until --command "git add watched.txt" --true-pattern "x" --max-iterations 1 --cwd . --interval-ms 100
nen: 'git add watched.txt' classifies as unknown (matches neither izanami's allowlist nor a named refusal -- an unrecognized command is never assumed safe). izanami watches only; a command that writes needs 'nen parse izanagi <task> until <condition> up to <N>' instead.
$ echo $?
2
```

`git add` is not even on `izanami`'s refused (`push`/`commit`/`merge`/`tag`/`rebase`/`reset`/`clean`)
list — it classifies `unknown` — and is refused identically to a named mutating command. **Every
shape of act is refused by `watch until`**, confirming the act can never be routed through it,
regardless of which specific write it is.

---

## 3. Mapping table with counts

See § 1's table. **Before: 5 hand-applied prose steps per invocation** (split, enforce cap presence,
enforce cap shape, echo the parse, evaluate the condition). **After: 0** — both `nen parse izanagi`
and `nen watch until` (single-shot, reused per iteration) now do all five mechanically, each verified
live above. Six items remain explicitly with the skill (§ 1, rows 6–11): the acting-iteration count
against the cap (finding, § 4), the act itself (structural, § 4), and four judgment calls (no-progress,
human gate, impossible condition, the mutation log) the old skill also left to the agent.

---

## 4. Residue / findings

1. **No `nen` verb enforces izanagi's mandatory N-iteration cap over the acting loop.** `nen parse
   izanagi` extracts and refuses on `N` exactly once, at parse time (§ 2.1–2.3) — it is a parser, not
   a loop, and never sees iteration 2 onward. `nen watch until --max-iterations` is a **different**
   bound, and `--help` says so explicitly: "a SAFETY bound, not izanagi's mandatory cap… izanami needs
   none." Reused single-shot per iteration (§ 2.4–2.5) it bounds one condition *check*, never the count
   of acting iterations. **Verified live** in § 2.4's composed transcripts: both the converging run and
   the cap-out run rely on the skill's own iteration counter (`--- iteration N ---`) — nothing in
   either `nen` call carries that count forward. This is the central finding the shared brief asked
   this port to confirm or refute: **confirmed** — the cap is parsed and refused by `nen`, but enforced
   across the loop by the skill.

2. **The act structurally cannot go through `nen watch until`.** Verified live (§ 2.6): every shape of
   mutating or merely-unrecognized command is refused, redirecting to `nen parse izanagi`. This is not
   a gap to route around — it is the read-only verb's own safety property (the same one `izanami`'s
   port names as its whole reason to exist) doing exactly what it should. The skill runs the act
   directly, between condition checks, under the looped task's own authority (§ 2 of the SKILL.md).

3. **`nen parse izanagi` runs no read/mutate classifier over the task, unlike `nen parse izanami`.**
   Verified live (§ 2.1, and the SKILL.md § 1's `gh pr checks …` example): a read-only-looking task
   parses exactly the same as a mutating one. This is correct, not a shortfall — izanagi's task is
   *expected* to mutate, so there is nothing for a classifier to gate; the one up-front confirmation
   (§ 1) is izanagi's actual guard, and it is a judgment step, not a mechanical one.

4. **The corrected-line placeholder on an invalid cap is fixed (`up to 3`), not computed** (§ 2.3). A
   minor observation, not a routing rule to build around: the SKILL.md instructs never presenting it
   as a recommended value.

5. **No shell oracle exists for this skill**, same as `izanami` (§ 3 of `docs/ab/izanami.md`) — the
   old skill's parse and loop were pure agent prose, never a script. The A/B here is against that
   prose (§ 1's mapping table) plus every `nen` transcript run live above, not a diff of two scripts'
   outputs.

6. **Judgment kept, per the shared brief's boundary list, unchanged from the old skill:** the
   no-progress stop (3 consecutive no-op iterations — no `nen` verb detects this), the human-gate stop
   (`kurapika.md`'s own gate discipline), naming an impossible condition instead of waiting on it (same
   discipline `izanami`'s port already carries), and the per-run mutation log (no `nen` ledger exists
   for izanagi the way `nen label apply --ledger` exists for one label call).

7. **Sibling skills named in § 2's authority section — `build`, `drive`, `file`,
   `backlog-synthesis`, `tensho`, `jujisho`, and (in this doc's own commentary) `getsuga`,
   `backlog-loop` — are not on `origin/main` at this commit.** Of these, only `build`, `drive`,
   `file` and `backlog-synthesis` come from the old skill's own § 2 (it never named `tensho`,
   `jujisho`, `getsuga` or `backlog-loop` as something izanagi loops over); `tensho` and `jujisho`'s
   mention in the ported SKILL.md's § 2, and `getsuga`/`backlog-loop`'s mention above, are this
   port's own additions, not carried forward from the old text. Per the forward-reference ruling,
   all of them are named as plain text annotated "(lands with a later port of hatsu#2)" in the
   ported SKILL.md rather than linked. `hatsu:izanami`, by contrast, has now **merged to `main`**
   (PR #13, `05272f9`) — verified live on the rebased base of this branch:
   `git show HEAD:claude/skills/izanami/SKILL.md` resolves, so the port's `../izanami/SKILL.md`
   links (SKILL.md § 1's "read-only half" line and its "point at `hatsu:izanami`" line) are real,
   working relative links, not a forward reference held on trust.
