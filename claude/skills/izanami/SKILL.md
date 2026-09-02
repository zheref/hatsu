---
name: izanami
description: Repeat a READ-ONLY task until a condition holds. Use when the maintainer invokes hatsu:izanami <task> until <condition>, or asks to watch, poll, or keep checking something until it changes. Observation only — it reads, reports and stops; it never writes to GitHub, never labels, never merges. For a loop that must act, use hatsu:izanagi, which requires an explicit iteration cap.
---

# Izanami — watch until it is true

**Nature: Manipulator** (GitHub-side ops/observation) unless the thing being watched is product, in
which case say so and switch mode out loud. Either way izanami only ever *looks*. Kurapika says so
when he runs it.

> **Keep checking this until that is true, then tell me.**

Izanami is the **read-only** half of the loop pair. Its mutating twin is
[`hatsu:izanagi`](../izanagi/SKILL.md), which requires an explicit cap in its grammar precisely
because it acts. **The split is the safety property**: a loop that cannot write cannot compound a
mistake, however many times it runs.

The old bankai-core skill enforced that split by an agent reading a hand-authored allow/refuse table
by eye, every invocation. This port replaces both halves of that with `nen`: `nen parse izanami`
splits and classifies the invocation before iteration 1, and `nen watch until` runs the loop itself —
fetch, evaluate, report one line, pace, stop. Judgment stays where the old skill kept it: naming which
mode is in play, deciding whether a condition is genuinely decidable, and saying what the next action
is without taking it.

---

## 1. Invocation — `nen parse izanami` does the split, never prose

```
hatsu:izanami <task> until <condition>
hatsu:izanami until <condition>
<a second read-only command to repeat>
...
```

Before running anything, echo the parse through the verb itself — this is not optional ceremony, it
is the enforcement mechanism:

```bash
nen parse izanami "<the invocation line, or a newline-separated block for the second form>"
```

`nen parse izanami` (no `--grammar` — it is one of the three built-in grammars, alongside `futon` and
`izanagi`) matches `until` **case-insensitively as the LAST whole-word occurrence**, echoes the parsed
condition back as `until: <condition>`, and then prints **every** task/command line with its
classification tag — `[read-only]`, `[mutating]` or `[unknown]` — before anything is allowed to run.

**Verified live**, first form, all read-only:

```
$ nen parse izanami "gh pr checks 925 --repo zheref/bankai-core until they are all green"
until: they are all green
  [read-only] gh pr checks 925 --repo zheref/bankai-core
$ echo $?
0
```

Second form (`until <condition>` with commands on following lines — pass the whole block as one
newline-separated argument):

```
$ nen parse izanami $'until they are all green\ngh pr checks 925 --repo zheref/bankai-core'
until: they are all green
  [read-only] gh pr checks 925 --repo zheref/bankai-core
$ echo $?
0
```

**The task/command line must be a literal, executable command — never a prose description of intent.**
Verified live: a prose task line classifies `[unknown]` and refuses the whole run exactly like a
genuinely unrecognized command does —

```
$ nen parse izanami "watch PR #925 checks until they are all green"
until: they are all green
  [unknown] watch PR #925 checks
nen: at least one command does not classify as read-only -- the WHOLE run is refused. Use 'nen parse
izanagi <task> until <condition> up to <N>' for a loop that must act.
$ echo $?
1
```

This is the same enforcement the loop itself applies (§4) — write the real `gh`/`git` invocation, not
a description of what it does.

**Exit codes, verified live:**

| Exit | Meaning |
|---|---|
| `0` | The line parsed AND every command classifies read-only |
| `1` | The line parsed but at least one command classifies `mutating` or `unknown` — **the whole run is refused**, and the message names `nen parse izanagi <task> until <condition> up to <N>` as the mutating twin |
| `2` | The line itself does not parse — no `until` found at all (`nen: no 'until <condition>'. Expected '<task> until <condition>'.`), or `until <condition>` with no task and no following command at all (`nen: no task and no commands to repeat -- expected a task on the first line, or a command per following line.`) |

Never reconstruct this parse by hand once `nen` is available — echo its output verbatim and act on the
exit code.

## 2. Read-only, enforced before the first iteration — `nen`'s classifier IS the table

The old skill's allow/refuse table was **hand-applied prose**. Verified against the real binary, `nen
parse izanami` / `nen watch until` implement a fixed classifier that reproduces the same shape
mechanically — every row below is a live-verified `[read-only]` or `[mutating]` tag, not a
transcription from memory:

| Allowed — verified `[read-only]` | Refused — verified `[mutating]` |
|---|---|
| `gh pr view`, `gh pr checks`, `gh pr list`, `gh pr diff`, `gh pr status` | `gh pr merge`, `gh pr comment`, `gh pr close`, `gh pr reopen` |
| `gh issue view`, `gh issue list` | `gh issue create`, `gh issue edit`, `gh issue close` |
| `gh run view`, `gh run list`, `gh run watch` | `gh label create`, `gh label edit`, `gh label delete` |
| `gh repo view` | `gh release create`, `gh release edit`, `gh release delete` |
| `gh api` (a plain GET, no `-X`) | `gh api` with `-X POST`/`PUT`/`PATCH`/`DELETE` |
| `git fetch`, `git log`, `git diff`, `git status`, `git ls-tree`, `git show` | `git push`, `commit`, `merge`, `tag`, `rebase`, `reset`, `clean` (the classifier's own refused pattern: `^git\s+(push\|commit\|merge\|tag\|rebase\|reset\|clean)\b`) |
| `git branch` — **listing forms only**: bare, `-a`, `--list` | `git branch -D`, `git branch -m` (same family, delete/rename mutate) |
| `git remote` — **listing forms only**: bare, `-v`, `show` | `git remote add`, `remove`, `rm`, `set-url`, `rename`, `prune`, `set-head` (same family, every mutating subcommand) |
| | `git checkout -b` (branch creation) |
| | any invocation `nen parse izanagi` would need instead |

**This table is a sample, spot-verified live against the shipped binary, not an exhaustive
transcription** — a command not listed here is checked with `nen parse izanami` before it is ever
handed to `nen watch until`, never assumed from this table by analogy. Note in particular that
`git branch` and `git remote` split **within the same family**: the bare/listing form is
`[read-only]`, a specific mutating subcommand of the same command is `[mutating]` — the classifier
looks at the full shape, not just the leading verb.

**Where `nen` is stricter than the old skill's prose table — a behavior change, not a bug:** the old
allow table admitted "reading a file, running a checker script" by category. `nen`'s classifier has
no such category — anything it does not recognize as one of the specific `git`/`gh` shapes above is
`[unknown]`, and **`[unknown]` refuses exactly like `[mutating]`** (§ 4 finding 1). A command the old
skill would have allowed by eye can now be refused outright. This is disclosed, not routed around.

**`git fetch` is allowed and is usually required** — it writes only to local refs, and a watch that
never fetches watches a frozen picture. It is the one write-shaped thing that is genuinely
observation, and it classifies `[read-only]` exactly as the old skill's table said it should.

Skill-level refusals the classifier cannot see — because they are not shell commands at all — stay a
judgment rule, unchanged from the old skill: never run [`drive`](../drive/SKILL.md),
[`build`](../build/SKILL.md), [`file`](../file/SKILL.md), [`tensho`](../tensho/SKILL.md),
[`jujisho`](../jujisho/SKILL.md), [`getsuga`](../getsuga/SKILL.md),
[`backlog-synthesis`](../backlog-synthesis/SKILL.md) or [`backlog-loop`](../backlog-loop/SKILL.md)
inside a watch, and never post a comment, apply a label or publish an Artifact as part of one.
[`backlog-state`](../backlog-state/SKILL.md), reading a page, and a genuinely read-only checker script
remain allowed **in spirit** — but see the finding below: not every one of those actually classifies
`[read-only]` when handed to `nen` as a `--command`.

**Two findings against the binary, not routed around (full detail in `docs/ab/izanami.md` § 4):**

1. **A plain file read or a local checker script classifies `[unknown]`, not `[read-only]`** — `cat`,
   `type`, `test -f`, and an arbitrary script all refuse, even though the old skill's own allow table
   names "reading a file, running a checker script" as allowed. `nen`'s classifier only recognizes the
   specific `git`/`gh` shapes in the table above; anything else is `unknown`, and unknown is refused
   exactly like mutating (`nen: at least one command does not classify as read-only`). **A watch over a
   local file's contents cannot go through `nen watch until` today** — poll it by hand, in-shell,
   applying this skill's own judgment about read-only-ness, or express the same fact through a `git`
   read against a tracked file instead (`docs/ab/izanami.md` § 2.4's live transcript does exactly
   that).
2. **`nen`'s own verb surface is not recognized by izanami's classifier at all** — `nen pr ready`,
   `nen backlog fetch`, `nen board build`, and even a genuinely *mutating* `nen label apply --run` all
   come back `[unknown]` and are refused, regardless of what the verb itself does. **A watch cannot poll
   a computed `nen` verdict directly** — it must instead poll the underlying `gh`/`git` read the verb
   itself would consult (e.g., watch `gh pr checks` rather than `nen pr ready`), or fall back to
   judgment-driven manual iteration outside `nen watch until` entirely.

**Refuse the whole run, not the offending step.** Both `nen parse izanami` and `nen watch until` do
this themselves — a mixed command list refuses before iteration 1 ever runs, verified live in
`docs/ab/izanami.md` § 2.2.

## 3. The condition

**`nen parse izanami` echoes the parsed condition back** as `until: <condition>` before iteration 1 —
say how it will be decided (the exact `--true-pattern`, or "exit code 0" when none is given) alongside
that echo.

A good condition is **decidable from one observation** and expressible as either a regex against
stdout or a command's own exit code. If the condition as typed is not decidable this way, say what is
ambiguous and offer the concrete predicate you propose to use — do not guess and proceed.

**Conditions that can never become true are named, not waited on.** Watching a closed PR for a green
check, or a deleted branch for a push, ends the run with *"this cannot become true, because…"* rather
than looping until a bound.

## 4. The loop — `nen watch until` runs it, not hand-rolled prose

```bash
nen watch until --command "<the classified read-only command>" \
  [--true-pattern <regex>] [--interval-ms 5000] [--max-iterations <n>] \
  [--cwd <path>] [--error-exit-threshold <n>]
```

- **`--command`** is classified against izanami's table (§2) **before the first run** — a mutating or
  unknown command is refused outright, naming `nen parse izanagi` instead. Never hand it a raw string
  you have not already checked with `nen parse izanami`.
- **`--true-pattern <regex>`** — tested against stdout. Omit it to treat exit code `0` as true (the
  default a check-style command uses). **When given, a non-zero exit is an OBSERVATION ERROR**, not a
  false reading — the pattern alone decides truth.
- **`--error-exit-threshold <n>`** — only meaningful when `--true-pattern` is **not** given: an exit
  code at or above this is an observation error rather than false. Default `2` (codes `0`/`1` are the
  ordinary true/false pair most CLIs use).
- **`--interval-ms`** — default `5000`. Pace to what is being watched: CI checks move on the order of
  minutes, a merge on the order of a human's attention. Say the interval chosen and why.
- **`--max-iterations`** — a **safety bound**, never izanagi's mandatory cap. Omit it for an unbounded
  watch — izanami can compound no mistake, so an unbounded watch costs time and nothing else. **Three
  consecutive observation errors stop the run regardless of this bound**, verified live below.
- **`--cwd <path>`** — where a `git` command needs to run against a specific checkout (a `gh` command
  instead takes its target via its own `--repo`/`-R` flag, so `--cwd` is rarely needed alongside `gh`).

**One line per iteration, no banner** — `nen` renders this itself:

```
[1] condition is not yet true (exit 0)
[2] condition is not yet true (exit 0)
...
[5] condition is true (exit 0)
condition became true after 5 observation(s)
```

A watch is not a gate event; the drawn Kurapika header fires only when the run **ends** and the
maintainer is needed. Do not restate this per-iteration output as a screenful of status yourself — it
already prints one line and stops there.

**Exit codes, verified live:**

| Exit | Meaning |
|---|---|
| `0` | The condition became true |
| `1` | A 3-consecutive-observation-error streak, or `--max-iterations` reached without becoming true |
| `2` | The invocation itself was refused before the loop ever started (a mutating/unknown `--command`) |

**Verified live A/B transcripts backing every row above are in `docs/ab/izanami.md` § 2** — a genuine
false→true multi-iteration watch over a real `git diff --stat` condition, a bankai-core read-only watch
that is already true on the first observation (`gh pr view … --json state`), a refused mutating
`--command` (`git push origin main`), and a 3-consecutive-error stop against a nonexistent PR number.

**Stops that are not the condition, each said plainly:**

| Stop | Reported as |
|---|---|
| The condition became true | ✅ with the evidence (the matching stdout / exit code) and the elapsed time |
| The condition became **impossible** | ⛔ with why, e.g. the PR closed unmerged — say this instead of starting `nen watch until` at all |
| The observation itself keeps failing | ⛔ `nen` itself stops after 3 consecutive observation errors — relay its own line, don't reclassify it |
| The maintainer interrupts | reported as interrupted, with the last observation |

## 5. Authority

**None.** izanami applies no label, opens nothing, comments nowhere, merges nothing and publishes
nothing. It carries no `CON-25`-equivalent delegation of any kind, and being invoked inside another run
does not lend it one.

**If the watch makes the next action obvious, say what the action is — do not take it.** That is
[`backlog-state`](../backlog-state/SKILL.md)'s discipline and it holds here for the same reason: a
"watch this" request that mutates the repo is a betrayal of the request.

## 6. Hard limits

- **Never writes to GitHub** — no comment, label, merge, push, tag, issue, PR or Artifact.
- **Never runs a mutating skill**, and never a mutating step "just once to check".
- **Never hands `nen watch until` a command it has not first checked with `nen parse izanami`** — both
  enforce the same classification, but the parse step is the one that lets you see the whole list
  before anything runs.
- **Never guesses an ambiguous condition** — it asks.
- **Never loops on a condition that cannot become true.**
- **Never fires the gate banner mid-watch**, and never reports a condition met without the evidence.
- **Never routes around a `[unknown]` refusal** by hand-rolling the same observation outside `nen watch
  until` and presenting it as though the verb had run it — a file read or a `nen`-verb poll that the
  classifier refuses (§2's two findings) is reported as a finding, not quietly worked around.
