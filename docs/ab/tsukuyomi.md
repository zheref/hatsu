# Evidence — `tsukuyomi` (new skill, Hatsu workflow fold-in)

`claude/skills/tsukuyomi/SKILL.md`: tests health — run every suite `nen/workflow.json` calls required,
read the runner's own results, report the exit codes as facts.

**Phase ruling, 2026-09-12.** Full-regression mode belongs to aka's final
`prepublication-verification`; murasaki and mukai do not own independent suite runs. Focused mode is
exactly one explicit scoped lane at kokusen and never iterates `tests.required` or `tests.extra`;
a direct invocation is diagnostic. Instrumented artifacts
are captured here for aka but measured later by gyo.

**Not a port.** What it replaces is a test command typed from memory and a pass/fail read by eye. § 2
records the live behaviour at nen `0.3.0` — including the verb this skill was designed around, which
does not exist yet.

**Run:** 2026-09-09/10 (local clock; the session crossed midnight), `nen 0.3.0` at `/Users/zheref/.local/bin/nen`; host `Darwin 25.4.0 arm64`,
`node v24.16.0`. Hatsu at `origin/main` `e158349`. Verbs were exercised against a **constructed**
throwaway git repository under this worktree's `.nen-fixture/` — one `nextjs` lane whose `test` row
was run green, then flipped red — deleted before the commit. No primary checkout was touched.

*Paths sanitized: this machine's absolute paths appear as `<fixture>`. Nothing is redacted — both
repositories are public — and the transcripts are otherwise verbatim.*

---

## 1. The skill

| Step | Mechanism | Owner |
|---|---|---|
| 1 | Route by mode; full regression reads `tests.required` / `tests.extra`, focused uses its explicit lane | the skill, as data (§ 3) |
| 2 | Show the suite before running it — `nen shu test --dry-run` | verb |
| 3a | Focused mode: run exactly one explicit scoped lane, independent of required/extra | verb |
| 3b | Full-regression mode: run each required/extra suite — `nen shu test`, `nen shu ui-test [--lane]` | verb |
| 4 | React to `0`/`1`/`2`/`3`/`4`/`5` | the skill's table, from `claude/agents/kurapika.md` § *The `shu` verbs* |
| 5 | Read the results | residue — `nen shu test-report` does not exist (§ 2.4) |
| 6 | A required suite the declaration seats | quoted as a two-file disagreement (§ 2.5) |
| 7 | Fix the code, re-run; never patch a test | the skill |

**Count.** Eight rows; **four are verb uses**, one is a stated reaction table, and the results-parsing
step is residue at this pin.

The focused/full split is a routing scenario, not a new Nen flag: focused mode invokes only
`nen shu test --lane <explicit-scoped-lane>` and refuses `--extra`; full-regression mode alone reads
and iterates `tests.required` and `tests.extra`. A focused run therefore cannot fall through into
the default lane's full suite.

## 2. Verbs exercised live

### 2.1 — `nen shu test --dry-run`, then a green run

```
$ nen shu test --repo <fixture> --dry-run
lane:          app  (nextjs)
verb:          test
host:          darwin -- supported (the declaration constrains no platform)
preconditions: (none declared)
would run:     node -e 'console.log('\''2 passed, 0 failed'\'')'
cwd:           <fixture>
env:           (none added)
artifacts:     (none declared)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit
               code to report.
exit=0

$ nen shu test --repo <fixture>
2 passed, 0 failed
lane:          app  (nextjs)
verb:          test
ran:           node -e 'console.log('\''2 passed, 0 failed'\'')'  -- exit 0 in 26ms
cwd:           <fixture>
artifacts:     (none declared)
log:           not captured to a file -- each step's own stdout and stderr were relayed as it
               finished. A .nen/logs/ transcript is not in this release (zheref/nen#91).
exit=0
```

`2 passed, 0 failed` is the **runner's** line, relayed. nen printed no count of its own and parsed
nothing — which is exactly the boundary § 2.4 makes unavoidable.

### 2.2 — a red suite

```
$ nen shu test --repo <fixture>
1 passed, 1 failed
FAIL src/app.test.js > renders
lane:          app  (nextjs)
verb:          test
ran:           node -e '...'  -- exit 1 in 33ms
cwd:           <fixture>
...
step 1 of 1 failed: node -e '...' -- exited 1. nen exits 1 whatever the tool's own code was; the
tool's code is in the report above.
exit=1
```

### 2.3 — the same red suite as one document

```
$ nen shu test --repo <fixture> --json
{
  "contract": "nen.shu.test/v0.1",
  "lane": "app",
  "verb": "test",
  "steps": [ { "exe": "node",
               "argv": ["-e", "console.log('1 passed, 1 failed'); console.error('FAIL src/app.test.js > renders'); process.exit(1)"],
               "cwd": "<fixture>", "exitCode": 1, "durationMs": 23 } ],
  "exitCode": 1
}
```

`steps[0].exitCode` is the **runner's** code and the top-level `exitCode` is **nen's**; here they
coincide at `1`, and on a runner that exits `3` they do not (`docs/ab/rasengan.md` § 2.2 shows that
pair). The document carries no test names, no counts and no per-case status — there is nothing in it
to report a suite's contents from.

### 2.4 — `nen shu test-report` does not exist at this pin

```
$ nen shu test-report --repo <fixture>
nen shu: unknown 'shu' subcommand 'test-report'. Known: detect, build, test, ui-test, lint, archive,
release, dev, run, deploy, coverage, tools, warmup.
Run 'nen shu --help'.
exit=2
```

Thirteen verbs, and no results parser among them. So the `{tests[], passed, failed, skipped}`
document the skill was designed around does not exist, and § 6 of the skill says what happens
instead: quote the runner's own summary, never state a count nobody printed.

### 2.5 — a suite the declaration seats, and one it never declared

```
$ nen shu lint --repo <fixture>
nen shu lint: 'lint' is unsupported on lane 'app' (nextjs). The declaration's own reason: this
fixture ships no linter; the lane is a seat on purpose
exit=4

$ nen shu coverage --repo <fixture>
nen shu coverage: lane 'app' (nextjs) declares no 'coverage'. It declares: build, dev, lint, test. A
verb this repository has is a verb this repository states, in nen/contract.json under
project.verbs.app -- nen never substitutes a plausible command for a declared one.
exit=4
```

Both exit `4`. Where `tests.required` names a verb that answers like this, the two files disagree
about whether this repository has that suite — the skill's § 2 quotes the reason and reports the
disagreement rather than treating either file as authoritative on its own.

The second transcript is also the coverage boundary: a lane declaring no `coverage` is a fact about
the repository, not a test failure, and the touched-file ladder belongs to `hatsu:gyo` anyway.

### 2.6 — the stop this skill reports into

```
$ nen stop --who kurapika --gate G5 efforts.md
=== YOUR INPUT IS NEEDED ==============================
who: kurapika
gate: G5 -- decision / human-only action
rung 1 (push notification): NOT fired -- the caller's to have sent, before this renders.
rungs 2-3 (OS notification, audible cue): not fired by nen -- only git/gh subprocesses are ever
shelled out to.
see the table below. No banner above => nothing needs you right now.

| Effort      | State                                | Gate | Needs                        | Owner      |
| ----------- | ------------------------------------ | ---- | ---------------------------- | ---------- |
| fixture-app | red build (step 1 of 1, tool exit 3) | G5   | a decision on the type error | maintainer |
exit=0
```

Rendered here to record the shape, **not** because tsukuyomi prints it: the G5 on a red required
suite is `aka`'s, raised at the moment a push was about to happen. tsukuyomi reports red and hands it
over.

## 3. Residue

1. **`nen shu test-report`** (§ 2.4). No parsed results document at this pin: read the runner's own
   summary off the relayed output and quote it.
2. **Parsing a declared test artifact** — JUnit XML, `.xcresult`, a vitest JSON reporter — has no verb
   either. Where numbers matter, name the file that holds them; do not infer them from its existence.
3. **No log file.** `log: not captured to a file … (zheref/nen#91)` (§ 2.1), so the turn's report is
   the only record of what a suite printed.
4. **Reading `nen/workflow.json`** — no loader and no `nen schema check` row at `0.3.0`
   (`docs/ab/breath.md` § 2.6). `tests.required` / `tests.extra` are read as data.
5. **Deciding that a failing test is itself wrong** stays judgment — and, per the skill's § 6, a loud
   one: its own commit, with the reason in the message and in the report.

## 4. Findings against the binary

1. **There is no way to learn what a suite contains from nen at this pin** (§ 2.3, § 2.4). The
   `--json` document carries argv, cwd, durations and two exit codes, and nothing about tests. Any
   claim about counts or named cases comes from the runner's stdout, parsed by eye — the exact place
   a plausible-sounding number can be invented. `nen shu test-report` is the fix; until it lands the
   skill's rule is to quote and not to count.
2. **A `--json` reader cannot tell a green suite that printed nothing from one that ran no tests**
   (§ 2.1, § 2.3). Both are `exitCode: 0` with no rows. A runner that silently matched zero files is
   the classic false green, and nothing in the document distinguishes it. Recorded; the skill's
   mitigation is to quote the runner's summary line, which usually does.
3. **`4` covers two different sentences** (§ 2.5) — a declared seat with a reason, and a verb the lane
   never mentioned — and the skill has to read the text to tell them apart. Same observation as
   `docs/ab/rasengan.md` § 4.1's neighbour; noted once more because for a *required* suite the
   difference is the difference between "this repository chose not to" and "nobody wrote it down".
4. **No missing verb otherwise.** Running the declared suites, the host check and the stop banner are
   all verbs, exercised live above with their exit codes.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| no parsed results document | `nen shu test-report --repo <fixture> --lane app` | `1` — the run went, the report was absent, and the refusal NAMES it |

```
$ nen shu test-report --repo <fixture> --lane app
ran:           sh -c 'echo tested'  -- exit 0 in 3ms
report:        Reports/junit.xml  (junit)
totals:        (nothing parsed -- the report could not be read -- see below)
no test report at Reports/junit.xml. The declaration names it under the lane's 'test' verb 'artifacts'
and it is not there: either the runner writes its report somewhere else -- correct the path -- or no run
has produced one.
exit=1
```

That is the shape of the verb's refusals: a damaged or absent report is **named**, never folded into a
number. Through `v0.4.0` the same invocation answered *"unknown 'shu' subcommand 'test-report'"* at exit
`2` (§ 2.4). **What stays residue** is the extraction step for a result bundle: nen opens no `.xcresult`
itself, because the only supported way to read one is a program no declaration named.
