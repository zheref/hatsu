---
name: gyo
description: Measure line coverage of the files this branch touched, band each one against the repository's ladder — 80 the minimum, 85 recommended, 90 ideal — and add tests until the lowest one clears the floor. Use when the maintainer invokes hatsu:gyo [against <base>], asks what the coverage is on this branch, or whenever hatsu:mukai reaches its coverage step before the pull request is composed. A touched file under the minimum is a G5 stop with the options laid out; the bar is never lowered to clear it and a test is never patched to raise a number.
---

# Gyo — the lines that are actually exercised

**Nature: Transmuter.** Gyo runs declared machinery, parses what it produced and reports it. Writing
the tests that close a gap is the same nature that authored the code — named as it switches, never
blended (`claude/agents/kurapika.md`).

> **Show me the coverage of the files I touched — file by file, against the ladder — and do not let
> me move the ladder.**

Gyo is [`hatsu:mukai`](../mukai/SKILL.md)'s fourth step, after the suites have run and before the
evidence is assembled. It is also invocable alone. Its whole discipline is **one direction of
travel**: the number rises to meet the bar, and the bar never falls to meet the number.

**Coverage is not tests' health.** Whether the suites pass is
[`hatsu:tsukuyomi`](../tsukuyomi/SKILL.md)'s and [`hatsu:kotoamatsukami`](../kotoamatsukami/SKILL.md)'s;
gyo assumes they are green and asks a different question — *how much of what I changed did they
actually run?*

---

## 1. Invocation

```
hatsu:gyo [against <base>]
```

```bash
nen parse gyo --grammar "against [<base>]" --line "<the invocation, minus the hatsu:gyo prefix>"
```

Verified live at `v0.3.0` (`docs/ab/gyo.md` § 2.1): `against main` → `base: main`, exit `0`; a bare
`against` parses with the clause absent, exit `0`. The clause is anchored behind a literal for the
reason [`hatsu:rikugan`](../rikugan/SKILL.md) § 1 records. **With no clause the base is
`nen/workflow.json` → `branch.base`, default `main`**, and the base is named out loud — the whole
measurement is *relative to it*, so a base nobody stated is a number nobody can check.

## 2. The ladder — `nen/workflow.json` → `coverage`

```json
"coverage": { "minimum": 80, "recommended": 85, "ideal": 90, "scope": "touched" }
```

| Key | Default | What it means here |
|---|---|---|
| `minimum` | `80` | **the stop.** A touched file under it is a **G5** (§ 7) |
| `recommended` | `85` | the band gyo aims for and reports against |
| `ideal` | `90` | the band worth saying out loud when it is reached |
| `scope` | `touched` | line coverage of the **touched set** (§ 4), derived from `git diff --name-only origin/<base>...HEAD` — **not** the repository total |

**Three numbers rather than one, because a single threshold becomes either a gate that blocks honest
work or a number nobody looks at** (`docs/WORKFLOW.md` § 2). The ladder reports bands and stops only
at the bottom rung.

**The bands, and the word for each:**

| Band | Condition | Reported as |
|---|---|---|
| **ideal** | `percent ≥ ideal` | `ideal` — said out loud, once, without ceremony |
| **recommended** | `recommended ≤ percent < ideal` | `recommended` |
| **above the floor** | `minimum ≤ percent < recommended` | `over minimum` — fine, and named as the band it is |
| **under the floor** | `percent < minimum` | **`under minimum` — § 7** |
| **not measured** | the report has no row for this file | § 4's rules 2, 2b and 3 — three different reasons, and never a band |

`nen schema check` does not validate `nen/workflow.json` at `v0.3.0` (verified live,
`docs/ab/rikugan.md` § 2.4); it is read as data, and the defaults above are stated whenever they are
what applied.

## 3. Measure — `nen shu coverage`, which reports and never gates

```bash
nen shu coverage --repo <path> [--lane <lane>] --threshold <minimum> --dry-run   # once per repo per session
nen shu coverage --repo <path> [--lane <lane>] --threshold <minimum>
```

The verb runs the lane's declared coverage command and then **parses the report it produced** into
one shape: a total, a row per target, and — with `--threshold` — whether the number cleared the bar.
The report is the first path under the verb's `artifacts` whose format nen reads.

> **`--threshold` REPORTS `met` and never changes the exit code, in either direction.** Verified live
> at this pin (`docs/ab/gyo.md` § 2.2): a real parse totalling **79.50%** against `--threshold 80`
> prints *"80% — NOT met. This is REPORTED and never enforced: nen exits `0` here, and the threshold
> moved that by nothing"* and exits **`0`**. **Nen does not decide whether a number is good enough**,
> and that is the correct division: the *number* is the machine's, the *bar* is the repository's
> policy, and the *stop* is this skill's. A run that treated exit `0` as "coverage passed" would have
> read the verb backwards.

Under `--json` the document is `nen.shu.coverage/v0.1`:
`{ contract, lane, stack, total, targets[], threshold: {value, met}, report: {format, path}, exitCode }`,
where each `targets[]` row is `{name, lines: {covered, total, percent}}` and `percent` is **computed
from the counts**, to two decimals, and is `null` for a report about no lines — 0 of 0 is neither
100% nor 0%.

**Exit codes** (`claude/agents/kurapika.md` § *The `shu` verbs*): `1` the coverage command ran and
failed, or the lane declares no artifact nen can read; `2` usage or declaration; `3` this host may
not; `4` a **seat** (§ 8); `5` the tool is not on `PATH` → `nen shu tools`.

**A dry run is told by `exitCode: 0` with `total: null`** — there is no `dryRun` boolean, and nothing
else produces that pair. Verified live against `zheref/nen`'s own checkout (`docs/ab/gyo.md` § 2.2).

## 4. Filter to the touched files — and say what could not be matched

**The scope is `touched`, and the verb has no flag for it at this pin.** The per-target table is
whole-repository, so the filter is by hand:

```bash
git -C <path> fetch origin <base>
git -C <path> diff --name-only origin/<base>...HEAD
```

> **The range is `origin/<base>...HEAD`, after that fetch — never the bare branch name.**
> `branch.base` is a **branch name** (`main`), and nothing in the local plane fast-forwards *local*
> `main` after [`hatsu:breath`](../breath/SKILL.md) cut the branch from it. Measured live: a checkout
> whose local `main` was 13 commits behind answered **43** changed files where the branch's own
> change was **8** (`docs/ab/mukai.md`) — so a literal `main...HEAD` bands a week of somebody else's
> files against this branch's ladder and can stop the run on a file this branch never opened.
> `git merge-base origin/<base> HEAD` is the same set as a SHA, and is the form to quote in the
> report. **A base named in § 1 is a branch name; the range is that branch's remote ref.**

The result is the **changed set**. The **touched set** — what the ladder is applied to — is the
changed set minus what rules 2 and 2b remove. Then intersect it with `targets[].name`. Rules, and the
last is the one that gets skipped:

1. **Match on the path the report gives, resolved against the lane's `cwd`** — never on a basename. A
   repository with `src/gate.ts` and `legacy/gate.ts` has two files whose basenames are identical and
   whose coverage is not, and a basename match silently reports one for the other.
2. **A changed file the tool does not measure is excluded, and the exclusion is stated** — a
   markdown file, a JSON fixture, an image, a lockfile, a declaration. It is not `0%` and it is not a
   band; it is *not a thing this tool measures*, and saying so is a complete answer. Verified live
   (`docs/ab/gyo.md` § 2.3): the touched set carried two entries and the coverage report had a row
   for exactly one of them.
2b. **A changed file the tool's own configuration excludes from instrumentation leaves the touched
   set the same way, and for the same reason.** Rule 2 is about a *format* the tool does not measure;
   this is about a *file* the tool was configured not to measure, in a language it does measure. Read
   the exclusions from where the repository declares them — vitest/v8 `coverage.exclude`, jest
   `coveragePathIgnorePatterns`, JaCoCo `excludes`, an `.xcscheme`'s coverage target membership,
   `.coveragerc` `omit` — and name the ones that fired.

   **Test files are always in this set, whatever the configuration says**, because no coverage tool
   instruments the files it is executing: they are the measurer, not the measured. A test file is
   **measured** in the ordinary sense — it runs, and gyo cares very much whether it does — but it is
   **never itself under the bar**, and there is no number for it to be under one with. Proved rather
   than assumed, on the report in hand: `grep -c '^SF:.*\.test\.ts' coverage/lcov.info` → **0** of
   **194** `SF:` records (`docs/ab/mukai.md`). **Say so in the exclusion rows**, once, with the count
   — *"`src/shu/run.test.ts` — a test file; 0 of 194 `SF:` records are test files"* — rather than
   leaving a reader to wonder why the file this branch added is not in the table.

3. **A NON-TEST source file in a measured language, not excluded by rule 2 or 2b, with no row is a
   finding, never a silent drop.** Two tools, two behaviours: some emit a `0%` row for a source file
   no test ever loaded, and some emit **no row at all** — and the second case looks exactly like rule
   2 from the outside. Say which file, say that the report has no row for it, and treat it as
   **`under minimum` until proven otherwise**. A file with no test that never appears in the table is
   precisely the file the ladder exists to catch, and dropping it is how a branch clears a floor it
   never touched.

   **Rule 3 is scoped to what survives rules 2 and 2b, and the scope is load-bearing.** Read without
   it, rule 3 is categorical — *any* touched file in a measured language with no row — and then
   **every branch that adds a test is a G5**, because the test it added is TypeScript, or Swift, or
   Kotlin, and has no row. That happened, and the run continued only because the reader could see the
   rule was wrong (`docs/ab/mukai.md`). A rule nobody can follow is a rule everybody skips, and rule
   3 is far too useful to spend that way. **The order is the rule: exclude, then find what the report
   dropped anyway.**

**Print the filtered table, always**: `file · percent · band`, one row per touched file, plus a row
for each exclusion with its reason. It is what [`hatsu:rikugan`](../rikugan/SKILL.md) § 4's `final`
variant renders as `{{#each coverage}}` → `{file, percent, band}`, and it is the same table.

**The repository total is reported alongside and is never the verdict.** A branch that touched three
files does not get to hide behind a large well-covered codebase, and it does not get punished for a
small poorly-covered one.

## 5. Add tests until every touched file clears the minimum

**Write the tests. Re-measure with the verb. Repeat.** Two rules on the loop:

- **Every number is `nen shu coverage`'s, every time.** Never an estimate, never "that should be
  about 85 now", never a number from an earlier run in the same session — the last measurement is
  about the tree it measured.
- **A test written to raise a number is still a test, and it has to assert something.** A test that
  executes a function and asserts nothing raises coverage by exactly as much as a real one and proves
  nothing at all. If the honest test for a line is hard to write, that is § 7's conversation, not a
  reason to write a fake one.

**What gyo may change: test files.** Not the code under test, not a configuration to exclude a path,
not a coverage threshold anywhere.

## 6. Report the bands

One line, then the table. The base, the lane, the report format and path the verb parsed, the
repository total, the per-touched-file rows with their bands, the exclusions with their reasons, and
the lowest band reached. Where every touched file is at `ideal`, say so once.

**Never a coverage number nen did not print.** The same rule
[`hatsu:tsukuyomi`](../tsukuyomi/SKILL.md) § 6 states for test counts, and for the same reason.

## 7. Under the minimum is a **G5**, with the options laid out

**A touched file below `coverage.minimum` after § 5 has been genuinely attempted is a stop.** Not a
note in the PR body, not "the rest are above 90 so the average is fine" — the ladder is per file, and
an average is how one untested file disappears.

The stop is [`hatsu:jutaisho`](../jutaisho/SKILL.md)'s shape, in full: the `nen stop` banner and
efforts table (`nen stop --who Kurapika --gate G5 <efforts.md>`; `nen stop --template` emits the blank
five-column table to fill — verified live, exit `0`, `docs/ab/gyo.md` § 2.4), the
[`hatsu:rikugan`](../rikugan/SKILL.md) report's link, lettered options with a ⭐ on the report, and
**the question through the surface's own native option picker** (`AskUserQuestion` on Claude Code).

**What this skill puts in the options.** Name the file, the number, the floor, and what was already
tried — then the genuine ways forward, which are these and not others:

- **A — keep going.** The gap is ordinary and the tests are writable; the cost is time and the
  maintainer may simply want it paid. ⭐ where that is true.
- **B — this is a spike branch.** The change is exploratory and is not intended to land as it is. Then
  the coverage answer is *"not yet"*, and the branch is not the thing to hold to the floor — but that
  is a **statement the maintainer makes**, and the PR says it.
- **C — the code is generated.** Generated output is covered by testing its generator, not itself.
  The exemption is real, and it belongs in the repository's own coverage configuration as an
  exclusion — which is a **declaration change, at G4**, not a flag added to this run.
- **D — a canon-sanctioned exemption applies**, and **the PR must state it**: which exemption, whose
  ruling, and what tracked item trues it up. An exemption nobody can point at is not one.

**Never an option that lowers `minimum`, `recommended` or `ideal`.** Not for this run, not "just for
this file", not by adding an exclusion pattern to make a file vanish from the denominator. That is the
one move gyo will not make, and it is not on the list for the maintainer to pick either — a repository
that cannot honestly reach `minimum` is a G5, not a smaller number. Changing the ladder itself is a
**deliberate, separate decision** in `nen/workflow.json`, argued on its own merits, at **G4**.

**The run ends at the stop.** A G5 is not a thing to retry past; the answer resumes it.

## 8. `not measurable here` — a lane that declares no coverage

```
$ nen shu coverage --repo <hatsu> --threshold 80
nen shu coverage: 'coverage' is unsupported on lane 'plugin' (claude-code-plugin). The declaration's
own reason: Nothing here executes, so nothing here is covered. gyo reports Hatsu's touched files as
`not measurable` against the ladder in nen/workflow.json rather than against a number, and the ladder
still governs every repository Hatsu drives that declares none of its own.
exit=4
```

Verified live against Hatsu's own checkout (`docs/ab/gyo.md` § 2.5). **Quote the seat and report
`not measurable here`.** It is not `0%`, it is not green, and it is not a G5 — nothing was measured,
so nothing failed and nothing passed. The ladder still ships, because it is the policy every
repository Hatsu drives inherits when it declares none of its own.

**Exit `1` is the near neighbour, and § 3's table gives it two arms — so read which one before
reacting.** *"The coverage command ran and failed, **or** the lane declares no artifact nen can
read"*: two different repositories' problems behind one number, with two different answers, and the
verb's own message says which.

| The arm | How it reads | What gyo does |
|---|---|---|
| **the command ran and failed** — the tool's own error on stderr: a missing dependency, a compile error, a runner that could not start | the message is the *tool's*, not nen's, and names a thing on this host | **repair the host and re-measure.** A stale or partial install is fixed where it broke (`bun install --frozen-lockfile`, `pod install`, `./gradlew --refresh-dependencies`) and the measurement is run again. Say what was repaired |
| **no artifact whose format nen reads** — nen's own sentence, naming the artifacts the row declares | the command never ran, or ran and produced nothing nen parses | **a declaration defect** — say which artifacts the row names, and treat fixing it as a **G4** change to propose |

**The first arm is not a G4 proposal, and treating it as one is the failure this table exists to
prevent.** Hit live: `MISSING DEPENDENCY  Cannot find dependency '@vitest/coverage-v8'` at exit `1`,
where `@vitest/coverage-v8` was already in the repository's own `devDependencies` and simply was not
installed. Following the second arm's advice there would have proposed a declaration change, at a
gate, for a `bun install` (`docs/ab/mukai.md`). Worth knowing alongside it: nen's declared
precondition for that lane is `path node_modules`, and **a stale `node_modules` satisfies it** — the
precondition asks whether the directory exists, not whether what is in it matches the lockfile.

**Neither arm is a coverage verdict.** Exit `1` means the number does not exist yet, so there is
nothing to band and nothing to stop on; § 7's G5 is for a number that exists and is under the floor.
A run that cannot produce a number after the repair says that, and says which arm it hit.

## Residue

1. **`nen shu coverage --touched --base <ref>`** — **`--touched` is not a known option at `v0.3.0`**,
   verified live: exit `2`, *"unknown option '--touched'"*, listing the family's whole option surface
   (`docs/ab/gyo.md` § 2.3). **It landed on nen `main` during the week of 2026-09-08 and ships at
   `0.4.0`** (brief § 4.4) — a pin that has not moved, not a feature to file. Until it does, § 4's
   filter is `git diff --name-only origin/<base>...HEAD` intersected with `targets[].name` by hand,
   with the per-file `met` decided against § 2's ladder by this skill, and reported as by-hand.
2. **Per-file `met`** — at this pin `--threshold` compares against the report's **total** only
   (`threshold: {value, met}` is one object, not a column on `targets[]`). Verified live: a table
   whose files ran 92 / 84 / 71 reported one `met: false` for the 79.50% total. Every per-file band in
   § 4's table is therefore computed by this skill from `targets[].lines.percent`.
3. **`nen shu test-report`** — absent at this pin (`docs/ab/tsukuyomi.md` § 2.4). Where a coverage gap
   turns out to be a suite that did not run, the evidence is the runner's own summary, quoted.
4. **`nen/workflow.json` is unvalidated at `v0.3.0`** — no row in `nen schema check`. § 2's ladder is
   read as data with the defaults stated. From `0.4.0` `nen shu coverage` reads the ladder itself for
   its default threshold (brief § 4.1).
5. **The touched set's exclusions** (§ 4, rules 2 and 2b) — read out of the repository's own
   coverage configuration by hand and named in the table. No verb reports what a coverage tool was
   configured not to instrument, and `--touched` at `0.4.0` filters the rows nen parsed rather than
   deriving the set: a file the tool never instrumented has no row either way, so the exclusion is
   still this skill's to state.
6. **Deciding whether a test asserts anything** stays judgment (§ 5), and a loud one.

Each is run in the open and reported as by-hand, per the Nen-first rule's second half
(`claude/agents/kurapika.md`): a missing verb is a finding, not a gap to route around silently.

## Authority

- **Permitted:** run the lane's declared `coverage` row; read the working copy and its git history;
  **write test files**; re-run the measurement; render the stop.
- **Not permitted:** editing the code under test to make it easier to cover; editing any coverage
  configuration, exclusion list or threshold; push, commit, PR, label, merge, deploy. Gyo is a step
  inside somebody else's run and holds none of that run's authority.
- **Carries no delegation**, and being invoked inside [`hatsu:mukai`](../mukai/SKILL.md) does not lend
  it one.

## Hard limits

- **Never lowers the bar** — not `minimum`, not `recommended`, not `ideal`, not for one file, not for
  one run (§ 7). Changing the ladder is a separate, argued decision at G4.
- **Never adds an exclusion, an ignore comment or a config pattern to make a file leave the
  denominator.** That is lowering the bar with extra steps.
- **Never patches a test to move a number** — and never writes a test that executes code without
  asserting anything (§ 5).
- **Never averages the touched files** or reports the repository total as the verdict (§ 4).
- **Never silently drops a non-test source file the report has no row for** — § 4's rule 3: name it,
  and treat it as under the floor until proven otherwise.
- **Never holds a test file to the bar.** No coverage tool instruments the files it is running; a
  test file leaves the touched set under § 4's rule 2b, with the count that proves it (§ 4).
- **Never files a host's own broken install as a declaration defect** — § 8's exit `1` has two arms
  and the verb's message says which.
- **Never matches a coverage row to a touched file by basename** (§ 4).
- **Never reports a number `nen shu coverage` did not print**, and never carries one from an earlier
  run (§ 5, § 6).
- **Never reads `nen shu coverage`'s exit `0` as a pass** — the verb reports `met` and never gates
  (§ 3).
- **Never treats a seat (exit `4`) as `0%` or as green** — it is `not measurable here`, quoted (§ 8).
- **Never presents by-hand filtering as a verb's output** — § Residue is named where it runs.
