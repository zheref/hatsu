# A/B evidence — `gyo` (new skill, wave 3)

`claude/skills/gyo/SKILL.md`: the coverage bar — measure the files this branch touched, band each one
against `nen/workflow.json → coverage` (80 minimum, 85 recommended, 90 ideal), add tests until the lowest
clears the floor, and stop at **G5** when it cannot be met honestly. The bar is never lowered.

**A new skill, so there is no "old mechanics" column.** What this record establishes is that
`nen shu coverage` is a real, working parser at the pinned `0.3.0` — it ran, parsed an lcov report and
produced a per-target table live — and that **two things gyo needs from it are not there yet**: the
`--touched --base` filter, and a **per-file** `met`. Both are computed by the skill, in the open, and
both are named as residue rather than presented as the verb's output.

Run: 2026-09-10 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
The parsing transcripts ran against a **constructed throwaway fixture** at `<worktree>/.nen-fixture` — a
hand-written `nen/contract.json` `project` block, a hand-written `coverage/lcov.info` with three files at
deliberately different percentages, a local `git init` and two commits on a feature branch — created for
this run and deleted before the branch was committed. The dry run in § 2.2 ran **read-only** against
`zheref/nen`'s own checkout, which carries a real coverage lane; the seat in § 2.5 ran read-only against
this worktree. **No mutating verb touched either.**

Nothing below is redacted; both repositories are public.

---

## 1. The skill

| Step | Owned by | State at `v0.3.0` |
|---|---|---|
| The invocation | `nen parse gyo --grammar "against [<base>]"` | **verb** (§ 2.1) |
| Run the declared coverage command | `nen shu coverage [--lane]` | **verb** (§ 2.2) |
| Parse the report into a table | `nen shu coverage` (same call) | **verb** (§ 2.2) |
| Compare a number to a bar | `nen shu coverage --threshold <n>` | **verb, total only** (§ 2.2, § 4.1) |
| Narrow to the touched files | `nen shu coverage --touched --base <ref>` | **absent** → residue (§ 2.3) |
| Per-file `met` | — | **absent** → residue (§ 4.1) |
| A lane with no coverage | `nen shu coverage` exit `4` | **verb** (§ 2.5) |
| The G5 banner and table | `nen stop --template` / `nen stop --who --gate` | **verb** (§ 2.4) |
| Deciding whether a test asserts anything | — | **judgment** (§ 4.4) |

**Nine rows; five are verbs, two are residue, one is judgment.** The verb half is genuinely complete for
what it claims — it never gates, by design — and every gap is on the *touched-scope* axis, which is
exactly the axis brief § 4.4 closes at `0.4.0`.

---

## 2. Verbs exercised live

### 2.1 — `nen parse gyo`: the base clause

```
$ nen parse gyo --grammar "against [<base>]" --line "against main"
base: main
exit=0

$ nen parse gyo --grammar "against [<base>]" --line "against"
exit=0
```

A bare `against` parses with the clause **absent** at exit `0` — the same behaviour `ao`'s `from` clause
records (`docs/ab/ao.md` § 2.1) — so the literal may be typed without a value and the default applies.
The slot is anchored behind a literal, which is what the engine requires (`docs/ab/rikugan.md` § 2.1).

### 2.2 — `nen shu coverage`: it parses, it reports `met`, and it never gates

**The dry run, read-only against `zheref/nen`'s own checkout** (a real `bun-cli` lane with a real
coverage command and a declared lcov artifact):

```
$ nen shu coverage --repo /Users/zheref/Code/WebStorm/Claude/nen --threshold 80 --dry-run
lane:          nen  (bun-cli)
verb:          coverage
host:          darwin -- supported (the declaration constrains no platform)
preconditions:
  ok    path node_modules
would run:     bunx vitest run --coverage --coverage.provider=v8 --coverage.reporter=text --coverage.reporter=lcov
cwd:           /Users/zheref/Code/WebStorm/Claude/nen
env:           (none added)
artifacts:     coverage/lcov.info (absent)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit
               code to report.
report:        coverage/lcov.info  (lcov)
total:         (nothing parsed -- this was a dry run: nothing ran, so there is no report to read)
threshold:     80% -- not compared -- there is no percentage to compare it with. This is REPORTED and
               never enforced: nen exits 0 here, and the threshold moved that by nothing.
exit=0
```

`--json` on the same call: `{"contract": "nen.shu.coverage/v0.1", "lane": "nen", "stack": "bun-cli",
"total": null, "targets": [], "threshold": {"value": 80, "met": null}, "report": {"format": "lcov",
"path": "coverage/lcov.info"}, "exitCode": 0}`.

**`exitCode: 0` with `total: null` is how a dry run is told** — there is no `dryRun` boolean, and
nothing else produces that pair.

**A real parse, against the fixture's lcov** (three files: 46/50, 42/50, 71/100):

```
$ nen shu coverage --repo <fixture> --threshold 80
fixture-coverage
lane:          app  (nextjs)
verb:          coverage
…
ran:           echo fixture-coverage  -- exit 0 in 8ms
artifacts:     coverage/lcov.info
report:        coverage/lcov.info  (lcov)
total:         lines 79.50% (159/200)
targets:
  lines            target
  84.00% (42/50)   src/coverage.ts
  92.00% (46/50)   src/gate.ts
  71.00% (71/100)  src/legacy.ts
threshold:     80% -- NOT met. This is REPORTED and never enforced: nen exits 0 here, and the
               threshold moved that by nothing.
exit=0
```

```json
{ "contract": "nen.shu.coverage/v0.1", "lane": "app", "stack": "nextjs",
  "total": { "lines": { "covered": 159, "total": 200, "percent": 79.5 } },
  "targets": [
    { "name": "src/coverage.ts", "lines": { "covered": 42, "total": 50, "percent": 84 } },
    { "name": "src/gate.ts",     "lines": { "covered": 46, "total": 50, "percent": 92 } },
    { "name": "src/legacy.ts",   "lines": { "covered": 71, "total": 100, "percent": 71 } } ],
  "threshold": { "value": 80, "met": false },
  "report": { "format": "lcov", "path": "coverage/lcov.info" },
  "exitCode": 0 }
```

And the same tree, the other side of the bar:

```
$ nen shu coverage --repo <fixture> --threshold 70
…
threshold:     70% -- met. This is REPORTED and never enforced: nen exits 0 here, and the threshold
               moved that by nothing.
exit=0
```

**`met: false` and `met: true` both exit `0`.** That is the single most important fact about this verb
for gyo, and it is stated in the verb's own output rather than inferred: *"nen does not decide whether a
number is good enough. Read `met` and decide"* (`nen shu --help`). The stop at § 7 of the skill is
therefore **entirely the skill's**, and a run that read exit `0` as "coverage passed" would have read the
verb backwards.

### 2.3 — `--touched` is not a known option, and the by-hand filter has a third case

```
$ nen shu coverage --repo <fixture> --touched --base main
nen shu: unknown option '--touched'. Known options here: --branch <value>, --discard, --dry-run,
--from <value>, --help, --install, --json, --lane <value>, --only <value>, --repo <value>, --run,
--target <value>, --tests, --threshold <value>, --write.
Run 'nen shu --help'.
exit=2
```

Brief § 4.4 has `--touched --base <ref>` landing on nen `main` this week and shipping at `0.4.0`. Until
then the filter is git's:

```
$ git diff --name-only main...HEAD
src-touch.txt
src/gate.ts
```

Intersected with § 2.2's `targets[]`, the touched table for this branch is:

| file | percent | band |
|---|---|---|
| `src/gate.ts` | 92.00 | **ideal** (≥ 90) |
| `src-touch.txt` | — | **not measured** — no row in the report |

**And that second row is the point.** The branch touched two files; the coverage report has a row for
one. The repository total (79.50%, `met: false`) is *not* the verdict — it is dragged down entirely by
`src/legacy.ts`, which this branch never touched — and the one file that *was* touched is at `ideal`.
Reporting the total here would have produced a false stop; reporting only the matched row would have
produced a false clear. Both rows go in the table, and the unmatched one carries its reason (a `.txt`
file is not something this tool measures — the skill's § 4 rule 2). The dangerous variant of the same
shape is § 4.3.

### 2.4 — `nen stop --template`: the G5 table

```
$ nen stop --template
| Effort  | Open issues & PRs | Status (gate)   | Thought flow | Session / lane |
| ------- | ----------------- | --------------- | ------------ | -------------- |
| <title> | <link>            | <status (gate)> | <one line>   | <session>      |
exit=0
```

`nen stop --help` states the division this skill relies on: *"Rungs 2-3 of the escalation ladder (an OS
notification, an audible cue) are NOT fired by this command … this command renders rung 4 (the banner and
table) and states rung 1's status, which is the caller's to have fired."* So gyo's stop is `nen stop`'s
banner plus [`jutaisho`](../../claude/skills/jutaisho/SKILL.md)'s rungs plus the surface's own option
picker, and none of those three substitutes for the others.

### 2.5 — A coverage seat, read against Hatsu's own checkout

```
$ nen shu coverage --repo <this worktree> --threshold 80
nen shu coverage: 'coverage' is unsupported on lane 'plugin' (claude-code-plugin). The declaration's
own reason: Nothing here executes, so nothing here is covered. gyo reports Hatsu's touched files as
`not measurable` against the ladder in nen/workflow.json rather than against a number, and the ladder
still governs every repository Hatsu drives that declares none of its own.
exit=4
```

**Hatsu's own declaration names this skill by name, and it was written before the skill existed** (wave
1, `nen/contract.json`). The seat is therefore doing exactly what a seat is for: it answers *"what is the
coverage here?"* with the repository's own sentence rather than with a number nobody could have produced.
`not measurable here` is neither `0%` nor green nor a G5.

---

## 3. Residue

1. **`nen shu coverage --touched --base <ref>`** (§ 2.3, exit `2`). Replaced by `git diff --name-only
   <base>...HEAD` intersected with `targets[].name`, matched on the report's own path form and never on
   a basename. Landed on nen `main` this week; ships at `0.4.0`.
2. **Per-file `met`** (§ 4.1). `threshold` is one object about the **total**; every per-file band in the
   skill's § 4 table is computed by the skill from `targets[].lines.percent` against the ladder.
3. **`nen shu test-report`** — absent at this pin (`docs/ab/tsukuyomi.md` § 2.4).
4. **`nen/workflow.json` read as data** — no schema row at `v0.3.0` (`docs/ab/rikugan.md` § 2.4). The
   ladder defaults to 80 / 85 / 90 / `touched`, stated when it applied. From `0.4.0` the verb reads the
   ladder itself for its default threshold.
5. **Judging whether a test asserts anything** — § 4.4.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — `--threshold` compares the **total**, and gyo's whole ladder is per file

§ 2.2 is the finding. Against a table whose files ran **92 / 84 / 71**, `--threshold 80` produced exactly
one verdict — `{"value": 80, "met": false}` — computed from the 79.50% **total**. There is no `met` on a
`targets[]` row, and there is no flag that puts one there.

**That is a shape mismatch with the policy, not a bug.** `nen/workflow.json → coverage.scope` is
`touched` and the ladder is explicitly per file (`docs/WORKFLOW.md` § 2: *"a touched file under it is a
G5"*), precisely because an average is how one untested file disappears behind a well-covered codebase.
The fixture demonstrates both failure directions in one table: the total says `NOT met` while the only
touched file is at `ideal` (a false stop), and a branch touching only `src/legacy.ts` at 71% would ride a
healthier total to a false clear.

**Brief § 4.4 already promises the fix** — *"per-file `met` against `--threshold` or the workflow
ladder"* — so this is a pin that has not moved rather than a defect to file. **What to check the day it
lands:** that `met` appears **on the row** and not only on the total; that a `targets[]` row for a file
with `lines.total: 0` reports `percent: null` and `met: null` rather than `100`; and that the
whole-repository total is still reported alongside, because gyo prints it and never treats it as the
verdict.

### 4.2 — The exit-code invariance is the right design, and it is the thing most likely to be broken by `--touched`

`--threshold` moves the exit code by nothing, in either direction, and the verb says so in its own
output twice (§ 2.2). That division — nen produces the number, the repository owns the bar, the skill
owns the stop — is what lets one binary serve repositories with different ladders without any of them
being written into it.

**`--touched` is where that could quietly change.** A flag whose name implies "the files that matter"
invites an implementation that exits non-zero when one of them is under the bar, and that would convert
a reporting verb into a gate — silently promoting `nen shu coverage` into a decision-maker in every
caller that already treats non-zero as failure. **Check the exit code first when the pin moves**, before
reading the table: `met: false` must still be exit `0`.

Ranked against the other wave-3 findings, this is the one with the largest blast radius if it goes wrong,
and the cheapest to verify.

### 4.3 — A touched source file with **no row** is indistinguishable from a touched file the tool ignores

§ 2.3 showed the benign version: `src-touch.txt` is touched, has no row, and is a `.txt` file — *not a
thing this tool measures*, a complete answer.

The dangerous version has the identical shape. A `.ts` file that no test ever loads is emitted as a `0%`
row by some tools and **omitted entirely** by others (v8/lcov coverage of files never `import`ed is the
classic case, and the fixture's declaration would behave that way). From the intersection's point of
view the two are the same: a touched path with no `targets[]` entry.

**The verb cannot resolve this and should not try** — it reports what the tool produced. So the rule is
the skill's (§ 4, rule 3): name the file, say the report has no row for it, and treat it as **under the
floor until proven otherwise**. Recorded here because it is the one place in gyo where doing the obvious
thing — dropping unmatched paths — hands a branch a floor it never cleared.

Worth one sentence in `nen shu coverage`'s `--touched` documentation when it lands: whether a touched
file absent from the report appears in the filtered rows at all, and with what.

### 4.4 — Not a finding: no verb can tell a real test from a coverage-shaped one

A test that calls a function and asserts nothing raises the number by exactly as much as a real one.
Nothing in nen, and nothing in any coverage tool, can distinguish them — coverage measures execution, and
assertion is a different property entirely.

So § 5 of the skill is judgment, stated loudly, and it is the reason the G5 at § 7 offers "keep going" and
"say this is a spike" as *real* options: the pressure that produces empty tests is the pressure of a floor
that has to be cleared today, and giving that pressure an honest exit is the only structural defence
available. Recorded as a boundary, not a gap — the same class as `kotoamatsukami`'s "look at the golden"
(`docs/ab/kotoamatsukami.md` § 4.3).


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| the touched-file filter, done by hand | `nen shu coverage --repo <fixture> --lane app --touched --base main` | `0` |
| the per-file band, computed by this skill | the same call, ladder read from `nen/workflow.json` | `0` |
| `nen/workflow.json` unvalidated | `nen schema check --repo .` → `ok  nen/workflow.json` | `1` overall, that row `ok` |

```
$ nen shu coverage --repo <fixture> --lane app --touched --base main
report:        coverage/lcov.info  (lcov)
total:         lines 71.43% (5/7)
ladder:        nen/workflow.json -- minimum 80% / recommended 85% / ideal 90%. REPORTED per row as
               'band', and never enforced: nen exits 0 here, whatever the bands say.
touched:       base main: 1 file (0 matched, 1 unmatched)
  unmatched: src/__Snapshots__/test_snapshot_Settings.png
exit=0
```

**`--touched` requires `--base`, and either without the other is exit `2`** — verified both ways:

```
$ nen shu coverage --repo <fixture> --lane app --touched
nen shu: --touched requires --base <ref>: nen filters the per-target rows to the files 'git diff
--name-only <base>...HEAD' reports, and there is no base to diff against without one.
exit=2

$ nen shu coverage --repo <fixture> --lane app --base main
nen shu: --base is read only with --touched -- it names the ref '--touched' diffs against, and does
nothing on its own. Add --touched, or drop --base.
exit=2
```

The `unmatched` line is the
input to the skill's rules 2 and 2b — nen reports the list, and naming *why* each entry is unmatched
stays the skill's, which is why that entry is **kept** in § Residue rather than retired.
