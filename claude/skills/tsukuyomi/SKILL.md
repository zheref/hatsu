---
name: tsukuyomi
description: Run this repository's declared test suites — the ones `workflow.json` calls required, plus any extras named for the run — read the runner's own results, and report health as the exit codes and the runner's summary rather than an impression. Runs automatically inside `murasaki`, `mukai` and `aka`; invoke `hatsu:tsukuyomi` by name to check tests on demand. A red suite is fixed and re-run or stopped at G5 inside `aka`; a test is never patched to make it pass.
---

# Tsukuyomi — the tests, seen for what they are

**Nature: Transmuter** carries every run: tsukuyomi executes declared machinery and reports what it
did. Fixing what the suite found is the surrounding phase's work in that phase's own nature — and
where the fix would be to the *test*, it is a change that has to justify itself out loud (§ 6).

> **Run every suite this repository calls required, and tell me exactly which of them passed, from
> the runner's own words.**

Tsukuyomi is **automatic**: it runs inside `murasaki` after a pull, inside `mukai` before a PR is
composed, and as `aka`'s first step before anything is pushed. It is not human-called and it never
pushes. **The G5 stop on a red suite belongs to `aka`** — tsukuyomi reports red; the phase that was
about to publish decides what that costs.

---

## 1. Invocation

```
hatsu:tsukuyomi [--lane <lane>] [--extra <verb[,verb]>]
```

`--extra` adds suites for one run, on top of `workflow.json → tests.required`; it never subtracts.
There is no flag that narrows the required set — a suite this repository calls required is run or the
run is reported as incomplete (§ 9).

## 2. The parameters, and where they come from

| Value | File → key |
|---|---|
| The suites that must pass | `nen/workflow.json` → `tests.required` |
| Suites run alongside them | `nen/workflow.json` → `tests.extra` |
| Which lane they run in | `nen/workflow.json` → `iteration.lane` |
| What each suite actually runs | `nen/contract.json` → `project.verbs.<lane>.<verb>` (`test`, `ui-test`, …) |
| Where it runs, with what, producing what | `project.lanes.<lane>.cwd`, the row's `env` (names only) and `artifacts` |
| Whether this host may | `nen/contract.json` → `project.hosts` |
| What must be true first | `nen/contract.json` → `project.preconditions` |

**When `nen/workflow.json` is absent, say so in the turn's report, in these words —** *"no
workflow.json: using the built-in defaults from `docs/WORKFLOW.md`"* — and use them:
`tests.required` = `["test"]`, `tests.extra` = `[]`, `iteration.lane` = the declaration's own
`project.defaultLane`.

**A required suite the declaration seats is a disagreement, not a pass.** Where `tests.required`
names `test` and `project.verbs.<lane>.test` is `{"unsupported": "…"}`, `nen shu test` answers exit
`4` with the declaration's own reason — quote it, run the repository's documented test command, say
that you did, and report the disagreement between the two files as a finding for the maintainer. Two
files disagreeing about whether this repository has tests is worth one sentence in the report every
time it happens.

## 3. The dry run, once

```bash
nen shu test --repo <path> [--lane <lane>] --dry-run
```

The exact argv, cwd, env names and declared artifacts, spawning nothing. Once per repository per
session, before the first real run — a test command is the one you least want to discover was not
what you thought.

## 4. The run

Every entry of `tests.required`, then `tests.extra` (plus `--extra`), each through its own verb:

```bash
nen shu test    --repo <path> [--lane <lane>]
nen shu ui-test --repo <path> [--lane <lane>]
```

Never the runner's own command line typed from memory. Under `--json` the report is one document —
`{contract, lane, stack, verb, steps, …, exitCode}` — where **`steps[].exitCode` is the runner's own
code** and the top-level `exitCode` is nen's. Verified live on a red suite: the runner's `1` appears
in `steps[0].exitCode` and nen's own `exitCode` is `1`, with the runner's stdout and stderr relayed
as it finished (`docs/ab/tsukuyomi.md` § 2.3).

**Reactions, by exit code** (`claude/agents/kurapika.md` § *The `shu` verbs* is the authority):

| Exit | Fact | Reaction |
|---|---|---|
| `0` | the suite ran and passed | next suite; when a **non-empty** list is exhausted, report green **for this run** |
| `1` | **red** — the suite ran and failed; the runner's own code is in `steps[].exitCode` | § 6: read what failed, fix the code, re-run. Inside `aka`, an unfixable red is that skill's **G5** |
| `2` | usage: no declaration, no `project` block, unknown lane, unsatisfied precondition | fix the invocation or the declaration; § 5 for the no-declaration case. An unmet precondition is nen's to assert and never to perform — satisfy it and name it |
| `3` | the declaration excludes this host | **G5** naming the host that can. Never a retry, and never "the rest passed so it is green" |
| `4` | a **seat** — the lane declares no such suite | quote the reason verbatim; § 2's disagreement rule |
| `5` | the runner is not on `PATH` | `nen shu tools --repo <path>`, relay the per-tool remedy |

### An empty configured set is `not applicable`, and never green

**`tests.required` empty and `tests.extra` empty is a legitimate declaration — and nothing ran, so
nothing passed.** Report it in these words:

> **`not applicable — no tests configured`**, naming `nen/workflow.json → tests.required` as the
> empty list, and `tests.extra` with it.

Never `green`, never `passed`, never a tick. **Green is a claim about a run; there was no run.** The
distinction matters because of who reads it: [`hatsu:aka`](../aka/SKILL.md) takes tsukuyomi's word
as its test proof before a push, and *"green"* would let a push claim a proof that does not exist.
**`aka` treats `not applicable` as *nothing to prove* and says so in the report** — it does not
convert it into a pass, and it does not stop for it either: an empty required set is not a red
suite, and G5 belongs to red.

Hatsu's own `nen/workflow.json` is exactly this case, and says so in its own `$comment`: *"An empty
`required` is a statement, not an omission."* A repository that ships no automated suite is entitled
to say so; what it is not entitled to is a green tick for saying it.

This is **not** § 5's case. An empty `tests.required` is a repository that declared no suites; § 5
is a repository that declared nothing at all, and answers exit `2`.

## 5. A repository that declares nothing

`nen shu test` exits `2` naming the missing `nen/contract.json` (or its missing `project` block). Then:
run the repository's own documented test command, **say plainly that no declaration exists yet**, and
treat writing one as a **G4** change to propose. Read that fact off `test`/`build`/`lint` and **never
off `nen shu detect`**, which answers a different question and reports `1` for repositories that test
perfectly well ([`hatsu:rasengan`](../rasengan/SKILL.md) § 7, verified live in both directions).

## 6. Reading the results, and what may be changed

**`nen shu test-report` is the verb that reads the results, and it exists at the pinned build:**

```bash
nen shu test-report --repo <path> [--lane <lane>] [--from-artifacts] [--json]
```

It declares nothing of its own — it runs `project.verbs.<lane>.test` and reads *that* row's
`artifacts` — and parses JUnit XML (one file, or a whole directory of them, merged), the
`testResults[].assertionResults[]` JSON a JavaScript runner writes, and the JSON summary a **declared**
result-bundle extraction step writes, into `nen.shu.test-report/v0.1`: a row per test (`name`, `suite`,
`status`, `durationMs`) and the four counts. Verified live at `v0.5.0` against a declared `test` row,
exit `1` with the report absent — *"no test report at Reports/junit.xml. The declaration names it
under the lane's 'test' verb 'artifacts' and it is not there: either the runner writes its report
somewhere else -- correct the path -- or no run has produced one"* — which is the shape of its
refusals: a damaged or absent report is named, never folded into a number
(`docs/ab/tsukuyomi.md` § *Retired at nen 0.5*).

Three rules of the verb that this skill relies on:

- **A run that FAILED is still parsed** — the one place this verb disagrees with `nen shu coverage`,
  because a failing suite is the report anybody asked for. A run that started *nothing* (a dry run, an
  unmet precondition, a program that would not spawn) parses nothing, since the file on disk is then
  certainly an earlier run's.
- **The failures never move the exit code**, in either direction: it is the run's, and under
  `--from-artifacts` — which reads the declared results and starts no process at all — it is about the
  read, so a report full of failures that parsed cleanly exits `0`. **So the verdict is still read off
  the counts, never off the exit code.**
- **An outcome word nen has not met is a refusal naming it**, rather than a guess that could make a
  red suite look green.

**Where the verb answers a seat or a refusal, the old discipline is exactly what to fall back to:**

- **Read the runner's own summary** off the output nen relayed, and **quote it** — "`1 passed, 1
  failed`", "`FAIL src/app.test.js > renders`" — rather than restating it as a number of your own.
- **Never state a count nen did not print and the runner did not say.** A pass count nobody produced
  is the exact failure this rule exists to prevent.

**Fix the code, not the test.** A failing test is a finding until it is proven otherwise. Never
delete, skip, `.only`-narrow, retry-loop, loosen an assertion or widen a tolerance to get green. A
test that is genuinely wrong is changed **deliberately, in its own commit, with the reason stated in
the message and in the turn's report** — and where the test encodes a rule somebody decided, changing
it is a decision for the maintainer, not for this run.

**Coverage is not tests' health.** The touched-file ladder belongs to `hatsu:gyo`; `nen shu coverage`
is its verb and reports `met`, never gating. A lane declaring no `coverage` answers exit `4` — a fact
about the repository, and not tsukuyomi's to report as a test failure.

## 7. Residue — what has no verb at the pinned build

- **RETIRED at nen `0.5`: `nen shu test-report`** (§ 6) — the parsed `{tests[], passed, failed,
  skipped}` document is a verb, exit `0` on a report that parsed and a named refusal on one that did
  not.
- **RETIRED at nen `0.5`: parsing a declared test artifact** — JUnit XML (a file or a directory of
  them), a JavaScript runner's JSON, and the JSON summary a **declared** result-bundle extraction step
  writes are all read by that verb. **What stays residue is the extraction step itself**: nen opens no
  `.xcresult` bundle, because the only supported way to read one is a program no declaration named —
  so a repository on that toolchain declares the `xcrun xcresulttool` step (and, at this pin, may
  point its `stdoutTo` at the file `test-report` then reads).
- **No log file.** `log:` reports *"not captured to a file … A `.nen/logs/` transcript is not in this
  release (zheref/nen#91)"*; each step's output is relayed as it finishes, so the turn's report is the
  only record.
- **RETIRED at nen `0.5`: validating `nen/workflow.json`** — `nen schema check` carries the row
  ([`hatsu:breath`](../breath/SKILL.md) § 2). `tests.required` and `tests.extra` are still read here;
  a read is not a residue.
- **Deciding whether a failing test is wrong** stays judgment, and a loud one (§ 6).

## 8. Authority

- **Permitted:** run the declared `test` and `ui-test` rows for the lane, probe the host through
  `nen shu tools`, report every code and quote the runner.
- **Not permitted:** push, commit, PR, label, merge, deploy, or edit a declaration on the fly. Also
  not permitted: **weakening a suite to make it pass** (§ 9).
- **Not a gate event of its own.** Red is reported; the **G5** on a red required suite is `aka`'s,
  raised at the moment a push was about to happen. An unsupported host (exit `3`) is a G5 wherever it
  blocks delivery.

## 9. Hard limits

- **Never patches a test to pass** — no skip, no `.only`, no loosened assertion, no retry loop, no
  deletion.
- **Never narrows the required set.** A suite `tests.required` names is run, or the run is reported as
  **incomplete**; an unperformed check is never rendered as a clean one.
- **Never states a pass/fail count nen did not print and the runner did not say** (§ 6).
- **Never reads the no-declaration fact off `nen shu detect`** (§ 5).
- **Never treats exit `4` as red or exit `5` as a failing suite** — a seat is the repository speaking,
  and a missing runner is a host that is not set up.
- **Never runs a test command from memory** in a repository that declares one.
- **Never reports green from an earlier turn.** Green is a statement about the run that just happened.
- **Never reports green for an empty configured set.** No required and no extra suites is
  `not applicable — no tests configured`, naming the empty list (§ 4). Green is a claim about a run,
  and there was none — a push must not inherit a proof nothing produced.
