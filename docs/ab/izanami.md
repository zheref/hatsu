# A/B evidence — `izanami` (zheref/hatsu#2)

Port of `claude/skills/izanami/SKILL.md`: the read-only watch loop. Old mechanics: a hand-authored
allow/refuse markdown table applied by eye per invocation, plus a hand-written 5-step loop ("fetch,
evaluate, report, poll in-shell, pace"). New mechanics: `nen parse izanami` (the invocation split and
command classification) and `nen watch until` (the loop itself).

Run: 2026-09-01, this session. `nen` `0.1.0` (`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`).
`gh` authenticated as `zheref` (`GH_TOKEN=$(gh auth token)` exported for every bankai-core read below).
Old skill source: `refpack/skills/izanami.SKILL.md` (bankai-core `v0.11.3`-era). No shell oracle exists
for izanami — the old skill's "loop" and "classify" steps were pure agent prose, never a script, so
there is no old-side command to run in parallel; the A/B here is against that prose, by contract.

---

## 1. Command mapping table

| # | Old (prose, applied by the agent by hand) | New (`nen`) |
|---|---|---|
| 1 | Split `<task> until <condition>` on the LAST whole-word `until`, matched case-insensitively — described in prose, performed by the agent reading the line | `nen parse izanami "<line>"` splits it, echoes `until: <condition>`, verified live (§2.1) |
| 2 | Classify every task/command against the hand-authored allow/refuse table (§2 of the old skill) — one line at a time, by eye | `nen parse izanami` / `nen watch until` tag every command `[read-only]` / `[mutating]` / `[unknown]` mechanically, before iteration 1, verified live to match the old table's `git`/`gh` rows exactly (§2.2) |
| 3 | "Refuse the whole run, not the offending step" — a rule stated in prose, enforced by the agent's own discipline | Both verbs refuse the WHOLE invocation (exit `1`/`2`) the instant any one command fails classification — mechanical, not a discipline the agent has to remember, verified live (§2.1, §2.3) |
| 4 | The 5-step loop ("fetch, evaluate the condition, true⇒stop, false⇒report one line, poll in-shell, pace the interval") — hand-run by the agent, one iteration at a time, in its own words | `nen watch until --command … --true-pattern … --interval-ms …` runs the entire loop, printing exactly one line per iteration and stopping on its own, verified live (§2.4–2.6) |
| 5 | "Stop after 3 consecutive observation errors — a loop that cannot see is not watching" — a rule stated in prose | `nen watch until` counts and stops itself, verified live (§2.6) |
| 6 | `git fetch` special-cased in prose as "allowed and usually required" | Classifies `[read-only]` by the verb's own table, no special-casing needed in the skill text (§2.2) |
| 7 | Echoing the parsed condition "and how it will be decided" before iteration 1 — the agent's own paraphrase | `nen parse izanami` prints `until: <condition>` verbatim as part of its classification output; `nen watch until` takes the same decision explicitly as `--true-pattern` (or exit-code-as-truth, stated) |

**Count.** Before: **4** steps performed by the agent, in prose, per invocation (rows 1, 2, 4, 5 —
splitting the line, classifying every command, running the loop by hand one iteration at a time, and
counting error streaks itself). After: **0** — all four are computed and executed by `nen parse
izanami` and `nen watch until`. What remains is: choosing the interval and truth predicate (a judgment
call the old skill also left to the agent), and the two residue items in § 3/§ 4 that `nen`'s
classifier does not yet cover.

---

## 2. Live A/B transcript (read-only)

No shell oracle exists to run in parallel (izanami's old "mechanics" were agent prose, never a script),
so every transcript below is `nen`'s own behavior, verified directly against the real binary and,
where the loop's *content* was tested against a live target, against the real `zheref/bankai-core`
backlog.

### 2.1 — `nen parse izanami`, valid invocations, both grammar forms

```
$ nen parse izanami "gh pr checks 925 --repo zheref/bankai-core until they are all green"
until: they are all green
  [read-only] gh pr checks 925 --repo zheref/bankai-core
$ echo $?
0
```

```
$ nen parse izanami $'until they are all green\ngh pr checks 925 --repo zheref/bankai-core'
until: they are all green
  [read-only] gh pr checks 925 --repo zheref/bankai-core
$ echo $?
0
```

Second form alone, with no command lines at all, is refused rather than silently accepted as "nothing
to watch":

```
$ nen parse izanami "until the PR merges"
nen: no task and no commands to repeat -- expected a task on the first line, or a command per following line.
$ echo $?
2
```

### 2.2 — `nen parse izanami`, invalid invocations

No `until` at all:

```
$ nen parse izanami "watch PR #925 checks"
nen: no 'until <condition>'. Expected '<task> until <condition>'.
$ echo $?
2
```

A prose task line (not a literal command) classifies unknown and refuses the whole run:

```
$ nen parse izanami "watch PR #925 checks until they are all green"
until: they are all green
  [unknown] watch PR #925 checks
nen: at least one command does not classify as read-only -- the WHOLE run is refused. Use 'nen parse
izanagi <task> until <condition> up to <N>' for a loop that must act.
$ echo $?
1
```

A genuinely mutating command mixed with a read-only one — the WHOLE run refuses, not just the mutating
line:

```
$ nen parse izanami $'until the PR merges\ngh pr checks 925 --repo zheref/bankai-core\ngh pr merge 925 --repo zheref/bankai-core'
until: the PR merges
  [read-only] gh pr checks 925 --repo zheref/bankai-core
  [mutating] gh pr merge 925 --repo zheref/bankai-core
nen: at least one command does not classify as read-only -- the WHOLE run is refused. Use 'nen parse
izanagi <task> until <condition> up to <N>' for a loop that must act.
$ echo $?
1
```

### 2.3 — classifier surface, enumerated live (backs the SKILL.md § 2 table)

Every command below was run as `nen parse izanami "until X\n<command>"` and the classification tag
read off:

```
[read-only]  gh pr view 925 --repo zheref/bankai-core
[read-only]  gh pr checks 925 --repo zheref/bankai-core
[read-only]  gh pr list --repo zheref/bankai-core
[read-only]  gh issue view 918 --repo zheref/bankai-core
[read-only]  gh issue list --repo zheref/bankai-core
[read-only]  gh run view 123 --repo zheref/bankai-core
[read-only]  gh run list --repo zheref/bankai-core
[read-only]  gh api /repos/zheref/bankai-core/issues/918
[read-only]  git fetch origin
[read-only]  git log -1
[read-only]  git diff main
[read-only]  git status
[read-only]  git ls-tree HEAD
[read-only]  git show HEAD:file
[unknown]    cat somefile.txt
[unknown]    type somefile.txt
[unknown]    test -f somefile.txt
[mutating]   gh api -X POST /repos/x/y/labels
[mutating]   git push origin main
[mutating]   git commit -m x
[mutating]   git merge foo
[mutating]   git tag v1
[mutating]   git checkout -b foo
[unknown]    nen pr ready 925 --gh-repo zheref/bankai-core
[unknown]    nen backlog fetch --repo-slug zheref/bankai-core
[unknown]    nen board build --repo-slug zheref/bankai-core --rows-from x.json
[unknown]    nen label apply BC-IS-#1 --label x --repo-slug zheref/bankai-core --run
```

The `git`/`gh` rows reproduce the old skill's allow/refuse table exactly — **same verdicts** on every
row that table names. The `cat`/`type`/`test -f` and `nen <verb>` rows are new information the old
skill's table did not anticipate (it was never mechanically checked before); both are recorded as
findings in § 4, not silently absorbed.

### 2.4 — `nen watch until`, a genuine false→true multi-iteration watch (local, read-only)

A scratch git repo, one committed file, condition: `git diff --stat` names the watched file (false
while clean, true once a background step appends to it — a real uncommitted change, never staged or
committed, so the observation stays read-only throughout):

```
$ git init -q /tmp/izanami-scratch-repo && cd /tmp/izanami-scratch-repo
$ echo "line1" > watched.txt && git add watched.txt && git commit -q -m init
$ ( sleep 7; echo "line2 appended" >> watched.txt ) &
$ nen watch until --command "git diff --stat" --true-pattern "watched.txt" --interval-ms 2000 --cwd . --max-iterations 10
[1] condition is not yet true (exit 0)
[2] condition is not yet true (exit 0)
[3] condition is not yet true (exit 0)
[4] condition is not yet true (exit 0)
[5] condition is true (exit 0)
condition became true after 5 observation(s)
$ echo $?
0
```

### 2.5 — `nen watch until`, a real bankai-core read-only condition, already true

```
$ export GH_TOKEN=$(gh auth token)
$ nen watch until --command "gh pr view 925 --repo zheref/bankai-core --json state -q .state" --true-pattern "OPEN" --interval-ms 2000 --max-iterations 3
[1] condition is true (exit 0)
condition became true after 1 observation(s)
$ echo $?
0
```

`zheref/bankai-core#925` was open at run time (confirmed separately: `gh pr list --repo
zheref/bankai-core --state open` listed `#925` and `#940`), so the condition was true on the first
observation — a degenerate but genuine case, the same shape the pr-state port's § 2.2 recorded for
closed PRs.

### 2.6 — refusal and error-streak cases

A mutating `--command` is refused before the loop ever starts:

```
$ nen watch until --command "git push origin main" --true-pattern "done" --interval-ms 2000
nen: 'git push origin main' classifies as mutating (matches a refused pattern
(^git\s+(push|commit|merge|tag|rebase|reset|clean)\b)). izanami watches only; a command that writes
needs 'nen parse izanagi <task> until <condition> up to <N>' instead.
$ echo $?
2
```

Three consecutive observation errors stop the run, regardless of `--max-iterations`:

```
$ nen watch until --command "gh pr view 999999 --repo zheref/bankai-core --json state -q .state" --true-pattern "OPEN" --interval-ms 1000
[1] observation failed: GraphQL: Could not resolve to a PullRequest with the number of 999999. (repository.pullRequest)
[2] observation failed: GraphQL: Could not resolve to a PullRequest with the number of 999999. (repository.pullRequest)
[3] observation failed: GraphQL: Could not resolve to a PullRequest with the number of 999999. (repository.pullRequest)
nen: stopped after 3 consecutive observation errors -- a loop that cannot see is not watching
$ echo $?
1
```

**Verdict across all six live scenarios above: `nen` behaves exactly as `--help` documents it**, and
reproduces every rule the old skill stated in prose (the `until` split, the allow/refuse classification,
one-line-per-iteration reporting, no banner, the 3-error stop, the exit-code contract) mechanically.

---

## 3. Residue

- **Judgment kept, per the shared brief's boundary list:** naming which Kurapika mode is in play
  (Manipulator vs. product), deciding whether a condition is genuinely decidable before starting a
  watch, naming a condition that can never become true instead of looping on it, and saying what the
  next action is without taking it — `nen` computes and enforces the mechanics; the skill keeps every
  one of these calls.
- **Skill-level refusals `nen` cannot see, because they are not shell commands:** running
  `drive`/`build`/`file`/`tensho`/`jujisho`/`getsuga`/`backlog-synthesis`/`backlog-loop` inside a watch,
  posting a comment, applying a label, or publishing an Artifact. These stay a prose rule in the ported
  SKILL.md (§ 2) exactly as they were in the old one, since `nen watch until`'s `--command` only ever
  classifies a literal shell invocation.
- **No missing verb for the loop or the parse itself.** `nen parse izanami` and `nen watch until`
  together cover every deterministic step the old skill's § 1–4 described. The two gaps found are in
  the *classifier's coverage*, not in the existence of the verbs — see § 4.

---

## 4. Findings (report separately, do not route around)

1. **The classifier does not recognize a plain file read or a checker script as read-only.** `cat
   somefile.txt`, `type somefile.txt`, and `test -f somefile.txt` all classify `[unknown]`, not
   `[read-only]`, and an unknown command is refused by both `nen parse izanami` (exit `1`, "at least one
   command does not classify as read-only") and `nen watch until` (exit `2`, "matches neither izanami's
   allowlist nor a named refusal — an unrecognized command is never assumed safe"). The old skill's own
   allow table explicitly names "reading a file, running a checker script" as allowed — this is a real
   gap between what the skill has always permitted and what the binary's classifier currently
   recognizes. Verified live in § 2.3. **Not routed around**: the ported SKILL.md (§ 2) documents that a
   file-read watch cannot go through `nen watch until` today and must be run by hand (or reframed as a
   `git` read against a tracked file, as § 2.4's own transcript does).

2. **`nen`'s own verb surface is entirely unrecognized by izanami's classifier**, including genuinely
   read-only verbs (`nen pr ready`, `nen backlog fetch`, `nen board build`) and even a genuinely
   *mutating* one (`nen label apply --run`) — every one comes back `[unknown]` and is refused
   identically, regardless of what the verb itself does. Verified live in § 2.3. This means a watch
   cannot poll a computed `nen`-verb verdict directly (e.g., "watch until `nen pr ready` says ready");
   it must poll the underlying `gh`/`git` read the verb consults instead. **Not routed around**: the
   ported SKILL.md (§ 2) states this as a hard limit of the current binary, not a rule to work past by
   hand-rolling the verb's own logic inside a watch loop.

3. **No shell oracle exists for this skill**, unlike `pr-state`'s `pr_ready_gate.sh` — the old skill's
   loop and classification were pure agent prose, never a script. So there is no "old side output" to
   paste alongside the `nen` transcripts above; the A/B here is against the old skill's stated rules
   (the mapping table in § 1), confirmed by running the new mechanics live rather than by diffing two
   scripts' outputs.
