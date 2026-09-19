---
name: byakugan
description: Capture instrumented coverage and measure touched-file coverage at mukai, independently of unit, UI and integration tests. Kotoamatsukami runs those suites; gyo is linting. The declared coverage row may extract or parse a matching capture but must not rerun tests. Each test remediation invalidates evidence and returns through kokusen and kotoamatsukami before recapture and remeasurement.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md`,
`docs/LAUNCH-MIGRATION.md` and `docs/STANDALONE-ENTRY.md` belong to the resolved **Hatsu plugin
root**, not the consuming repository. On an installed surface, use the absolute root printed by
`hatsu-warmup` to read those files (re-resolve through that skill if unavailable). Relative links
below identify source locations; a missing consumer `docs/` copy is not a missing policy and must not
trigger a duplicate filing. Never copy or invent a second policy in the target repository.



# Byakugan — the coverage, seen apart from the tests

> **The gate on a declaration change is the REPOSITORY's role, not the file's kind.** Maintainer's
> ruling, 2026-09-18 ([`docs/ROSTER.md`](../../../docs/ROSTER.md) § *Rulings of 2026-09-18 — G4 is
> the repository's role, not the file's kind*): **`G4` (`CON-7`) in a canon repository** —
> `zheref/hatsu`, `zheref/nen`, `zheref/bankai-core`, whose product *is* the process — and **`G2`
> (`CON-5`) in a consumer repository**, where a `nen/contract.json`, `nen/workflow.json` or
> `nen/gates.json` is that repository's own configuration and governs nothing else. **This skill runs
> against consumer checkouts by design**, so read every "**G4**" below as *the declaration gate* and
> resolve it by the target's role. The merge is the maintainer's either way — the ruling moves the
> gate, never the prohibition.

**Nature: Transmuter.** Byakugan captures instrumented results and parses what they produced. Writing
the tests that close a gap is the same nature that authored the code — named as it switches, never
blended (`claude/agents/kurapika.md`). Running the suites that produced the instrumentation is
[`/kotoamatsukami`](../kotoamatsukami/SKILL.md)'s.

> **Show me the coverage of the files I touched — file by file, against the ladder — without
> turning that into another test run.**

Byakugan is [`/mukai`](../mukai/SKILL.md)'s coverage step, after kotoamatsukami has run the
impacted **unit, UI and integration** suites and before the evidence is assembled. It is also
invocable alone. **Capture and measurement are this skill's. The tests are not.** That split is
the point: a coverage number is not tests' health, and a green suite is not a coverage pass.

This is what used to be named [`/gyo`](../gyo/SKILL.md) when gyo meant coverage. Gyo is
linting now, on every Ren turn. The ladder, the capture file, the extract, and the G5 under
`minimum` live here.

**Coverage is not tests' health.** Whether the suites pass is kotoamatsukami's (project-wide) and
[`/tsukuyomi`](../tsukuyomi/SKILL.md)'s (focused). Byakugan assumes they already ran on this
tree and asks a different question — *how much of what I changed did they actually exercise?*

---

## 0. Standalone entry — when no composite is holding the run

**Byakugan already takes its base as an argument** — `against <base>`, § 1 — so it is close to total
already. The contract is [`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md), and this
section states the two things § 1 left to the caller. **Reached from ANY composite, skip this section entirely** — the composite established P1–P4, and re-deriving them is how two answers to one question appear. Say which composite is holding the run. `mukai` and `en` both reach it.

**P1 · Warm up.** [`/hatsu-warmup`](../hatsu-warmup/SKILL.md), unconditionally.

**P3 · With no `against` clause the base is `origin/<branch.base>`, fetched — the REMOTE trunk.**
§ 1 resolves the clause-less case to `nen/workflow.json → branch.base`; cold, that name is resolved
against `origin` and the fetch happens first:

```bash
git fetch origin
```

The whole measurement is relative to that ref, and an unfetched local `main` measures the touched set
against a week-old tree — the touched set grows, files nobody touched enter the ladder, and the number
reported is not the number the change earned. **Name the resolved base and the fetch out loud.**

**The touched set is the COMMITTED diff, and a cold entry does not widen it.** § 5's narrowing is
`nen`'s — `git diff --name-only <base>...HEAD`, driven by `--touched --base <ref>` — and
[`docs/WORKFLOW.md`](../../../docs/WORKFLOW.md) § 2 defines `coverage.scope: touched` as exactly that
set. There is no input through which `git status --porcelain` reaches the verb, and inventing one here
would widen the population of a **G5** (§ 8) from inside a `## 0.` section, which
[`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) § 2 Rule 2 and § 5 both forbid.
**Report uncommitted paths as uncommitted** — they are not measured, and saying so is the honest
answer; changing what `touched` means is a **G4** question plus a `nen` capability, never a clause
written in passing.

**P4 · Nothing to ask.** The ladder is `nen/workflow.json → coverage`, the base has a default and an
override, and the touched set is derived. § 9's `not measurable here` — a lane that declares no
coverage verb — is an answer, not a gap, cold as well as wired.

**What does not change, and this is the one that matters.** § 6 and § 8 are untouched: touched-file
coverage under the ladder's `minimum` is a **G5** stop with the options laid out, and **the bar is
never lowered because the run was started by hand**. Capture is collection, never a test run — a cold
byakugan that finds no capture says so and points at
[`/kotoamatsukami`](../kotoamatsukami/SKILL.md); it does not execute a suite to make one.

**Hand-back.** *Next in the wired run: `/rikugan as landing`, then `/shibari` — the PR.
Neither ran here.*

---

## 1. Invocation

```
/byakugan [against <base>]
```

```bash
nen parse byakugan --grammar "against [<base>]" --line "<the invocation, minus the /byakugan prefix>"
```

The clause is anchored behind a literal for the reason [`/rikugan`](../rikugan/SKILL.md) § 1
records. **With no clause the base is `nen/workflow.json` → `branch.base`, default `main`**, and
the base is named out loud — the whole measurement is *relative to it*.

This is the grammar gyo-as-coverage used. Gyo's live grammar is now `on [<lane>]` (lint).

## 2. The ladder — `nen/workflow.json` → `coverage`

```json
"coverage": { "minimum": 80, "recommended": 85, "ideal": 90, "scope": "touched" }
```

| Key | Default | What it means here |
|---|---|---|
| `minimum` | `80` | **the stop.** A touched file under it is a **G5** (§ 8) |
| `recommended` | `85` | the band this skill aims for and reports against |
| `ideal` | `90` | the band worth saying out loud when it is reached |
| `scope` | `touched` | line coverage of the **touched set** (§ 5) — **not** the repository total |

`nen schema check --repo <path>` VALIDATES this file. A malformed key is a FAIL **by pointer**.

| Band | Condition | Reported as |
|---|---|---|
| **ideal** | `percent ≥ ideal` | `ideal` |
| **recommended** | `recommended ≤ percent < ideal` | `recommended` |
| **above the floor** | `minimum ≤ percent < recommended` | `over minimum` |
| **under the floor** | `percent < minimum` | **`under minimum` — § 8** |
| **not measured** | the report has no row for this file | § 5's rules 2, 2b and 3 |

## 3. Capture — collection, not a test run

Where kotoamatsukami's selected run produced coverage instrumentation, preserve that result and
record its provenance: final tree hash, every selected lane/verb, exact argv, artifact path, run
time, and the selection table (ran and skipped, with proofs). **Byakugan collects instrumented
execution data. It does not run `nen shu test` or `nen shu ui-test`.**

Nen can parse coverage artifacts, but the pinned interface does not emit one durable
regression-plus-coverage provenance envelope. Save those observed fields as transient JSON at
`.nen/regression/<lane>.json`, with contract `hatsu.regression-capture/v0.1`; this is Hatsu
residue, not Nen output, and must never claim fields the invocation and git tree did not prove.

A mismatch against the current tree is stale evidence and returns to
[`/kotoamatsukami`](../kotoamatsukami/SKILL.md), not into a second suite hidden inside
`nen shu coverage`. A consumer whose `coverage` row reruns tests must split collection from
extraction before mukai can honor the boundary.

**No matching instrumentation is not a licence to run the suites.** Say so, and treat it as
missing capture. Mukai's order (kotoamatsukami before byakugan) exists so the artifacts are
there; this skill does not fill the gap by becoming the test runner.

## 4. Measure the captured result — never execute a suite

```bash
git -C <path> fetch origin <base>
nen shu coverage --repo <path> [--lane <lane>] --touched --base origin/<base> --dry-run   # once per repo per session
nen shu coverage --repo <path> [--lane <lane>] --touched --base origin/<base>
```

The declared `coverage` row must only extract or parse the instrumented result § 3 produced; it
must not invoke a test runner, delete the captured result, or create a new one. Match the result's
recorded tree hash, lane, regression verb/argv, artifact path, and run time from
`.nen/regression/<lane>.json` to the current tree.

The pinned Nen has no `coverage --from-artifacts` switch. The supported route is an
extraction-only `coverage` row whose artifact points at this capture. If the row runs a suite or
provenance cannot be tied to this tree, report the exact missing declaration/capability as a
**G4** to propose — that is a declaration defect, not a coverage number under `minimum`. The
only coverage G5 this skill owns is a touched file under the ladder (§ 8). Never run duplicate
regression and call it coverage.

**`--touched` requires `--base`.** With `--threshold` absent — which is how this skill runs it —
nen loads the workflow ladder and bands every row itself. **`--threshold` REPORTS `met` and never
changes the exit code.** Nen does not decide whether a number is good enough; the *stop* is this
skill's.

**A dry run is told by `exitCode: 0` with `total: null`.** Exit codes: `1` the command ran and
failed, or no readable artifact; `2` usage; `3` host; `4` a **seat** (§ 9); `5` not on `PATH`.

The range is `origin/<base>...HEAD` after that fetch — never the bare branch name.

## 5. The touched set — nen narrows it, this skill states what it could not match

After the run, nen computes `git diff --name-only <base>...HEAD` and narrows `targets`.
**`unmatched` is the line this skill reads hardest.**

Nen's `touched.files` is the **changed set**. The **touched set** is that set minus what rules 2
and 2b remove:

1. **Match on the path the report gives, resolved against the lane's `cwd`** — never on a basename.
2. **A changed file the tool does not measure is excluded, and the exclusion is stated.**
2b. **A changed file the tool's own configuration excludes** leaves the same way. **Test files
    are always in this set** and **never themselves under the bar**.
3. **A NON-TEST source file in a measured language, not excluded by rule 2 or 2b, with no row is a
   finding**, treated as **`under minimum` until proven otherwise.** Rule 3 is scoped to what
   survives 2 and 2b.

**Print the filtered table, always**: `file · percent · band`, plus a row for each exclusion.
The repository total is reported alongside and is never the verdict.

## 6. Add tests until every touched file clears the minimum

**Write the tests. Checkpoint, rerun kotoamatsukami's suites, then recapture and re-measure.
Repeat.**

- **Every number is `nen shu coverage`'s, every time.**
- **A test written to raise a number still has to assert something.**

**What this skill may change for the bar: test files.** Not the code under test, not a coverage
configuration or threshold. Every test edit invalidates regression and coverage evidence;
[`/kokusen`](../kokusen/SKILL.md) commits it, [`/kotoamatsukami`](../kotoamatsukami/SKILL.md)
runs the suites again, and only then may this skill capture and parse again. Byakugan does not
run those suites itself.

## 7. Report the bands

One line, then the table. The base, the lane, the report format and path, the repository total,
the per-touched-file rows with their bands, the exclusions, and the lowest band reached.

**Never a coverage number nen did not print.**

## 8. Under the minimum is a **G5**, with the options laid out

**A touched file below `coverage.minimum` after § 6 has been genuinely attempted is a stop.**
The ladder is per file. The stop is [`/jutaisho`](../jutaisho/SKILL.md)'s shape, in full.

- **A — keep going.** The tests are writable. ⭐ where that is true.
- **B — this is a spike branch.** The maintainer says so; the PR says it.
- **C — the code is generated.** Exemption belongs in the repository's coverage configuration — a
  **declaration change, at G4**.
- **D — a canon-sanctioned exemption applies**, and **the PR must state it**.

**Never an option that lowers `minimum`, `recommended` or `ideal`.** Changing the ladder is a
separate G4 decision. The run ends at the stop.

## 9. `not measurable here` — a lane that declares no coverage

A seat (exit `4`) is quoted and reported `not measurable here`. It is not `0%`, not green, and
not a G5. Hatsu's `plugin` lane seats `coverage`; the ladder still ships for every repository
Hatsu drives that declares none of its own.

Exit `1` has two arms — the command ran and failed (repair the host and re-measure) versus no
artifact nen reads (a declaration defect, G4 to propose). Neither arm is a coverage verdict.

## Residue

1. **The capture file** (`.nen/regression/<lane>.json`, `hatsu.regression-capture/v0.1`) — Hatsu
   residue, not Nen output (§ 3).
2. **The touched set's exclusions** (§ 5, rules 2 and 2b) — read from the repository's own
   coverage configuration by hand.
3. **Deciding whether a test asserts anything** stays judgment (§ 6).
4. **RETIRED at nen `0.5`: `nen shu coverage --touched --base <ref>`**, per-file bands, and the
   ladder read — those are the verb's. What stays this skill's is naming *why* each `unmatched`
   entry is unmatched, and the G5 when a number is under the floor.

Historical coverage transcripts remain in `docs/ab/gyo.md` (gyo-as-coverage) and are dated.
`docs/ab/byakugan.md` is this skill's own record.

## Authority

- **Permitted:** write the capture file; run an extraction-only declared `coverage` row over that
  capture; **write test files** to reach the bar; re-measure after kotoamatsukami has re-run;
  read the working copy and its git history; render the coverage stop.
- **Not permitted:** running `test` or `ui-test`; editing the code under test to make it easier
  to cover; editing any coverage configuration, exclusion list or threshold; push, commit, PR,
  label, merge, deploy.
- **The G5 on a touched file under `coverage.minimum`** is this skill's. The G5 on a red required
  suite is mukai's, via kotoamatsukami.

## Hard limits

- **Never runs unit, UI or integration tests.** Those are kotoamatsukami's (project-wide) and
  tsukuyomi's (focused).
- **Never executes tests inside the coverage row**, and never accepts a coverage row that
  executes them.
- **Never lowers the coverage bar.**
- **Never adds an exclusion to make a file leave the denominator.**
- **Never patches a test to move a number**, and never writes a test that executes code without
  asserting anything.
- **Never averages the touched files** or reports the repository total as the verdict.
- **Never silently drops a non-test source file the report has no row for.**
- **Never holds a test file to the bar.**
- **Never reads `nen shu coverage`'s exit `0` as a pass.**
- **Never treats a coverage seat as `0%` or as green** — it is `not measurable here`.
- **Never runs as part of aka.** Gyo (lint), squash, ao and push do not include this phase.
- **Never presents by-hand filtering as a verb's output.**
