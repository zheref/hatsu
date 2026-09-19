---
name: tsukuyomi
description: Execute the repository's declared focused tests for the behavior this turn actually changed. Rasengan may use it for feedback; kokusen must use it at every local checkpoint. It never runs project-wide regression, never measures coverage, and a test is never patched to pass.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md`,
`docs/LAUNCH-MIGRATION.md` and `docs/STANDALONE-ENTRY.md` belong to the resolved **Hatsu plugin
root**, not the consuming repository. On an installed surface, use the absolute root printed by
`hatsu-warmup` to read those files (re-resolve through that skill if unavailable). Relative links
below identify source locations; a missing consumer `docs/` copy is not a missing policy and must not
trigger a duplicate filing. Never copy or invent a second policy in the target repository.



# Tsukuyomi — the focused tests, seen for what they are

> **The gate on a declaration change is the REPOSITORY's role, not the file's kind.** Maintainer's
> ruling, 2026-09-18 ([`docs/ROSTER.md`](../../../../docs/ROSTER.md) § *Rulings of 2026-09-18 — G4 is
> the repository's role, not the file's kind*): **`G4` (`CON-7`) in a canon repository** —
> `zheref/hatsu`, `zheref/nen`, `zheref/bankai-core`, whose product *is* the process — and **`G2`
> (`CON-5`) in a consumer repository**, where a `nen/contract.json`, `nen/workflow.json` or
> `nen/gates.json` is that repository's own configuration and governs nothing else. **This skill runs
> against consumer checkouts by design**, so every declaration-gate instruction below names both
> halves explicitly rather than asking you to reinterpret a bare "G4". The merge is the maintainer's
> either way — the ruling moves the gate, never the prohibition.

**Nature: Transmuter** carries every run: tsukuyomi executes declared machinery and reports what it
did. Fixing what the suite found is the surrounding phase's work in that phase's own nature — and
where the fix would be to the *test*, it is a change that has to justify itself out loud (§ 6).

> **Run the scoped tests that cover the behavior I just changed, and tell me exactly which of them
> passed, from the runner's own words.**

Tsukuyomi is **automatic on every [`/ren`](../ren/SKILL.md) turn that changes executable
behavior**: [`/rasengan`](../rasengan/SKILL.md) may call it for feedback while authoring, and
[`/kokusen`](../kokusen/SKILL.md) must call it at the local checkpoint before it commits.
**It is not the project-wide regression.** That run belongs to
[`/kotoamatsukami`](../kotoamatsukami/SKILL.md) at [`/mukai`](../mukai/SKILL.md). Coverage
capture and measurement belong to [`/byakugan`](../byakugan/SKILL.md), also at mukai. Linting is
[`/gyo`](../gyo/SKILL.md), on every Ren turn.
A direct named invocation is diagnostic and
creates no publication proof. It never pushes.

---

## 0. Standalone entry — when no composite is holding the run

**Tsukuyomi is normally called by [`/rasengan`](../rasengan/SKILL.md) for feedback or by
[`/kokusen`](../kokusen/SKILL.md) at the commit checkpoint, and this section is what it does when
neither did.** The contract is [`docs/STANDALONE-ENTRY.md`](../../../../docs/STANDALONE-ENTRY.md).
**Reached from ANY composite, skip this section entirely** — the composite established P1–P4, and re-deriving them is how two answers to one question appear. Say which composite is holding the run. Called by `rasengan` or `kokusen` — or by any composite above them — the caller named the lane, which is the whole argument.

**The state class tsukuyomi inherits is `S2` — a mandatory argument.** § 1 refuses a bare invocation
rather than defaulting to `iteration.lane`, and that refusal is **correct inside the loop**: a caller
that did not name the lane did not think about it, and silently running the repository lane runs the
full suite under a focused skill's name. Typed by hand, the same refusal is a dead end, because the
maintainer has no caller to go and fix.

**So cold, the lane is DERIVED from the delta rather than defaulted from the declaration.** The
distinction is the section's reason for existing: a derived lane is read off the files that actually
changed and is **named with the paths that selected it**; a defaulted lane is read off a config key
and is named with nothing.

**P3 · The delta — committed and uncommitted, against the fetched remote trunk.**

```bash
git fetch origin
git diff --name-only origin/<branch.base>...HEAD   # committed since the base
git status --porcelain                             # staged, unstaged, untracked
```

**Both halves count**, and **`against <base>` overrides the base** (§ 1); with no clause it is the
latest `branch.base`, fetched. Tsukuyomi run cold runs **only what this delta can move** — it is still never project-
wide regression, and the union above is what bounds it.

**P4 · Map the delta onto declared scoped lanes, then take one of exactly three exits:**

| What the mapping found | What tsukuyomi does |
|---|---|
| **Exactly one** declared scoped lane whose argv selects the changed behavior | Name it, name the paths that selected it, run it. No question |
| **Several** applicable lanes | Run **every** applicable one, once each, and say why each was selected. Ask only when two lanes overlap such that running both is ambiguous rather than merely thorough |
| **None** — changed executable behavior with no declared focused route | **§ 0a**, below. This is the interesting case and it is not a refusal |

**A delta of documentation, prose or configuration with no executable change is `no focused route
required`** — stated with the paths, and it is an answer rather than a gap.

### 0a · No route for the change — offer to author one

**Cold, a missing focused route is not the end of the run.** Inside `kokusen` it is a refusal,
because the authoring phase sat immediately before it and owed the test. Typed by hand over somebody
else's tree, there is nobody to refuse back to, so tsukuyomi **offers**, through the surface's own
picker, with the recommendation starred:

| Option | What it means |
|---|---|
| ⭐ **Author the focused tests, then run them** | Hand to [`/rasengan`](../rasengan/SKILL.md) to write tests for the changed behavior on the stack the declaration names, register the scoped lane where the repository's conventions put one, and return here to run it. Tsukuyomi does **not** write them itself — it is the runner, and a runner that authors its own evidence is not evidence |
| **Run the nearest declared lane instead** | Named explicitly, with what it does **not** cover stated. Never presented as coverage of the change |
| **Report the gap and stop** | The delta, the uncovered paths, no run. The honest zero |

**No option silently widens to the repository lane**, and none of them patches a test to pass — § 1's
rule, unchanged and unchangeable by entry point.

**Hand-back.** *Next in the wired run: `/kokusen` — verify the finished tree and commit it.
This run only executed tests; nothing is staged.*

---

## 1. Invocation

```
/tsukuyomi [against <base>] [--lane <explicit-scoped-lane>]
```

```bash
nen parse tsukuyomi --grammar "against [<base>]" --line "<the invocation, minus the /tsukuyomi prefix and the flags>"
```

Verified live at nen `0.10.0`: `against origin/main` → `base: origin/main`, exit `0`; an empty line
parses with the clause absent, also exit `0`. The parse runs only when the maintainer typed a clause.

**`against <base>` names the base every delta in this skill is read from.** With no clause the base
is **the latest state of `nen/workflow.json` → `branch.base`** — `git fetch origin` first, then
`origin/<branch.base>`; the local ref is used only where that fetch proves it already equal, and a
fetch that cannot run is a stop rather than a silent fall-back
([`docs/STANDALONE-ENTRY.md`](../../../../docs/STANDALONE-ENTRY.md) § 3 · P3). The resolved base is
named out loud either way.

`--lane` is required for a real run. It names one declared scoped lane whose `test` argv selects
the changed behavior. There is no `--mode`, no `--extra`, and no walk of
`nen/workflow.json → tests.required`. Those keys belong to kotoamatsukami.

A bare invocation without `--lane` is diagnostic only when the caller already named the lane in
prose and tsukuyomi repeats it; otherwise refuse rather than defaulting to `iteration.lane`, which
is the repository lane and usually the full suite.

## 2. The parameters, and where they come from

| Value | File → key |
|---|---|
| Which scoped lane to run | the caller's `--lane`, mapped by kokusen / rasengan from the changed behavior |
| What that lane actually runs | `nen/contract.json` → `project.verbs.<scoped-lane>.test` |
| Where it runs, with what, producing what | `project.lanes.<scoped-lane>.cwd`, the row's `env` (names only) and `artifacts` |
| Whether this host may | `nen/contract.json` → `project.hosts` |
| What must be true first | `nen/contract.json` → `project.preconditions` |

**Tsukuyomi does not read `tests.required` or `tests.extra`.** Those lists are kotoamatsukami's
candidate set for impacted regression. Reading them here would smuggle the slow suite into every
ren turn, which is the cost this split exists to stop.

**When `nen/workflow.json` is absent, say so in the turn's report, in these words —** *"no
workflow.json: using the built-in defaults from `docs/WORKFLOW.md`"* — and still require an
explicit scoped lane. An absent policy file is not a licence to run the default lane's whole
suite.

**A focused lane the declaration seats is a disagreement, not a pass.** Where the caller named a
lane whose `test` row is `{"unsupported": "…"}`, `nen shu test` answers exit `4` with the
declaration's own reason — quote it. If executable behavior changed and every candidate lane is a
seat, kokusen records the missing route and stops at G5 before staging; tsukuyomi reports the seat
and does not invent a runner.

## 3. The dry run, once

```bash
nen shu test --repo <path> --lane <explicit-scoped-lane> --dry-run
```

The exact argv, cwd, env names and declared artifacts, spawning nothing. Once per repository per
session, before the first real focused run — a test command is the one you least want to discover
was not what you thought. Confirm the printed argv is scoped to the changed behavior. If it is
the whole default-lane suite, stop and treat that as a missing focused route, never as a focused
run.

## 4. The run

Kokusen (and rasengan, for feedback) supplies the lane. Run exactly that lane:

```bash
nen shu test --repo <path> --lane <explicit-scoped-lane>
```

Its declared `test` argv must itself select the changed behavior. `--lane` is Nen's supported
routing mechanism. There is no `--scope` flag. Never infer scope from the lane name alone. Never
replace a missing focused lane with `tests.required`, with `iteration.lane`, or with the full
suite.

When kokusen maps several changed behaviors onto several scoped lanes, invoke this skill once per
distinct applicable lane. One lane is sufficient only when its declared argv covers all changed
behavior.

Never the runner's own command line typed from memory. Under `--json` the report is one document —
`{contract, lane, stack, verb, steps, …, exitCode}` — where **`steps[].exitCode` is the runner's own
code** and the top-level `exitCode` is nen's. Verified live on a red suite: the runner's `1` appears
in `steps[0].exitCode` and nen's own `exitCode` is `1`, with the runner's stdout and stderr relayed
as it finished (`docs/ab/tsukuyomi.md` § 2.3).

**Reactions, by exit code** (`claude/agents/kurapika.md` § *The `shu` verbs* is the authority):

| Exit | Fact | Reaction |
|---|---|---|
| `0` | the focused suite ran and passed | report green **for this lane, this run** |
| `1` | **red** — the suite ran and failed; the runner's own code is in `steps[].exitCode` | § 6: read what failed, fix the code, re-run. Inside kokusen, an unfixable red ends the commit |
| `2` | usage: no declaration, no `project` block, unknown lane, unsatisfied precondition | fix the invocation or the declaration; § 5 for the no-declaration case. An unmet precondition is nen's to assert and never to perform — satisfy it and name it |
| `3` | the declaration excludes this host | **G5** naming the host that can. Never a retry, and never "the rest passed so it is green" |
| `4` | a **seat** — the lane declares no such suite | quote the reason verbatim; § 2's disagreement rule |
| `5` | the runner is not on `PATH` | `nen shu tools --repo <path>`, relay the per-tool remedy |

### Focused tests that do not apply are `not applicable`, and never green

**Prose-only, data-only, or other non-executable changes with no relevant runnable behavior report
`focused tests: not applicable — <reason>`.** Hatsu's own Markdown-only changes are this case.
Never `green`, never `passed`, never a tick. **Green is a claim about a run; there was no run.**
Kokusen carries that word through unchanged and continues to the commit.

This is **not** § 5's case. A change with no focused lane is a repository that declared no scoped
route for this behavior; § 5 is a repository that declared nothing at all, and answers exit `2`.

## 5. A repository that declares nothing

`nen shu test` exits `2` naming the missing `nen/contract.json` (or its missing `project` block). Then:
run the repository's own documented test command, **say plainly that no declaration exists yet**, and
treat writing one as a change to propose at the **declaration gate** (**G4** in a canon repository, **G2** in a consumer one). Read that fact off `test`/`build`/`lint` and **never
off `nen shu detect`**, which answers a different question and reports `1` for repositories that test
perfectly well ([`/rasengan`](../rasengan/SKILL.md) § 7, verified live in both directions).

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

**Coverage is not tests' health.** The touched-file ladder belongs to
`/byakugan`; `nen shu coverage` is its extract verb and reports `met`, never gating.
A lane declaring no `coverage` answers exit `4` — a fact about the repository, and not
tsukuyomi's to report as a test failure. Instrumented capture for that ladder is the same
skill's, at mukai. Gyo is linting.

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
- **RETIRED at nen `0.5`: validating `nen/workflow.json`.** `nen schema check` carries the row
  ([`/breath`](../breath/SKILL.md) § 2). Tsukuyomi no longer reads `tests.required`; a read it
  does not do is not a residue.
- **Deciding whether a failing test is wrong** stays judgment, and a loud one (§ 6).

## 8. Authority

- **Permitted:** run one declared scoped `test` row at a time, probe the host through
  `nen shu tools`, report every code and quote the runner.
- **Not permitted:** push, commit, PR, label, merge, deploy, or edit a declaration on the fly. Also
  not permitted: **weakening a suite to make it pass** (§ 9), **running `tests.required`**, or
  **capturing instrumented results for coverage**.
- **Not a gate event of its own.** Red is reported; the **G5** on a red focused run at the
  checkpoint is `kokusen`'s, raised at the moment a commit was about to happen. An unsupported host
  (exit `3`) is a G5 wherever it blocks delivery.

## 9. Hard limits

- **Never patches a test to pass** — no skip, no `.only`, no loosened assertion, no retry loop, no
  deletion.
- **Never runs `tests.required`, `tests.extra`, or the default lane's whole suite** as a focused
  run. A missing scoped route is reported as missing, never substituted.
- **Never states a pass/fail count nen did not print and the runner did not say** (§ 6).
- **Never reads the no-declaration fact off `nen shu detect`** (§ 5).
- **Never acts as the project-wide regression inside aka, murasaki, or mukai.** That run is
  [`/kotoamatsukami`](../kotoamatsukami/SKILL.md)'s.
- **Never treats exit `4` as red or exit `5` as a failing suite** — a seat is the repository speaking,
  and a missing runner is a host that is not set up.
- **Never runs a test command from memory** in a repository that declares one.
- **Never reports green from an earlier turn.** Green is a statement about the run that just happened.
- **Never reports green for a change that had no focused run.** `focused tests: not applicable —
  <reason>` is the whole answer (§ 4).
