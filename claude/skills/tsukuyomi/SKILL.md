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
| `0` | the suite ran and passed | next suite; when the list is exhausted, report green **for this run** |
| `1` | **red** — the suite ran and failed; the runner's own code is in `steps[].exitCode` | § 6: read what failed, fix the code, re-run. Inside `aka`, an unfixable red is that skill's **G5** |
| `2` | usage: no declaration, no `project` block, unknown lane, unsatisfied precondition | fix the invocation or the declaration; § 5 for the no-declaration case. An unmet precondition is nen's to assert and never to perform — satisfy it and name it |
| `3` | the declaration excludes this host | **G5** naming the host that can. Never a retry, and never "the rest passed so it is green" |
| `4` | a **seat** — the lane declares no such suite | quote the reason verbatim; § 2's disagreement rule |
| `5` | the runner is not on `PATH` | `nen shu tools --repo <path>`, relay the per-tool remedy |

## 5. A repository that declares nothing

`nen shu test` exits `2` naming the missing `nen/contract.json` (or its missing `project` block). Then:
run the repository's own documented test command, **say plainly that no declaration exists yet**, and
treat writing one as a **G4** change to propose. Read that fact off `test`/`build`/`lint` and **never
off `nen shu detect`**, which answers a different question and reports `1` for repositories that test
perfectly well ([`hatsu:rasengan`](../rasengan/SKILL.md) § 6, verified live in both directions).

## 6. Reading the results, and what may be changed

`nen shu test-report` **does not exist at nen `0.3.0`** — verified live: *"unknown 'shu' subcommand
'test-report'. Known: detect, build, test, ui-test, lint, archive, release, dev, run, deploy,
coverage, tools, warmup"*, exit `2` (`docs/ab/tsukuyomi.md` § 2.4). So there is no parsed
`{tests[], passed, failed, skipped}` document at this pin, and tsukuyomi does not pretend there is:

- **Read the runner's own summary** off the output nen relayed, and **quote it** — "`1 passed, 1
  failed`", "`FAIL src/app.test.js > renders`" — rather than restating it as a number of your own.
- **Never state a count nen did not print and the runner did not say.** A pass count nobody produced
  is the exact failure this rule exists to prevent.
- Where the declaration names `artifacts` for the suite (a JUnit XML, an `.xcresult`), say the file
  exists and where; parsing it is residue (§ 7), not a claim to make from its filename.

**Fix the code, not the test.** A failing test is a finding until it is proven otherwise. Never
delete, skip, `.only`-narrow, retry-loop, loosen an assertion or widen a tolerance to get green. A
test that is genuinely wrong is changed **deliberately, in its own commit, with the reason stated in
the message and in the turn's report** — and where the test encodes a rule somebody decided, changing
it is a decision for the maintainer, not for this run.

**Coverage is not tests' health.** The touched-file ladder belongs to `hatsu:gyo`; `nen shu coverage`
is its verb and reports `met`, never gating. A lane declaring no `coverage` answers exit `4` — a fact
about the repository, and not tsukuyomi's to report as a test failure.

## 7. Residue — what has no verb at nen `0.3.0`

- **`nen shu test-report`.** No parsed results document (§ 6). Read the runner's summary; quote it.
- **Parsing a declared test artifact** — JUnit XML, `.xcresult`, a vitest JSON reporter — has no verb
  either. Where the numbers matter, say which file holds them.
- **No log file.** `log:` reports *"not captured to a file … A `.nen/logs/` transcript is not in this
  release (zheref/nen#91)"*; each step's output is relayed as it finishes, so the turn's report is the
  only record.
- **Reading `nen/workflow.json`** — no loader and no `nen schema check` row at this pin
  ([`hatsu:breath`](../breath/SKILL.md) § 2). `tests.required` and `tests.extra` are read as data.
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
