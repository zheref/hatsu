# A/B evidence — `bankai-quality` (zheref/hatsu#2)

Port of `claude/skills/bankai-quality/SKILL.md`: resolving a repo's `bankai_scenario`, its pinned
adversarial-test and performance tooling, and its `QA-{n}` rules, pre-release. Old mechanics: a hand-grep
of `.github/workflows/bankai.yml` for `bankai_scenario`, a markdown tooling table read by eye, and two
prose rules (`>10%`/`>25%` regression severity; the five-field `QA-15` method block) verified by hand,
never computed. New mechanics: `nen repo scenario`, `nen quality tooling`, `nen quality perf-compare`,
`nen quality method-check`.

Run: 2026-09-02T01:01Z (UTC). `nen` `0.1.0` (`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`).
Oracle/registry checkout: `zheref/bankai-core` tag `v0.11.3`
(`2269fe723e355dc69bf535ab40f22556e4fe4081`, working tree clean, read-only throughout — no issue,
comment, label, branch, push or PR against it at any point in this run).

---

## 1. Command mapping table

Every deterministic-but-improvised step the old `SKILL.md` carried, and what replaces it.

| # | Old (prose / hand-eyeball) | New (`nen`) |
|---|---|---|
| 1 | "Read `bankai_scenario` from the repo's `.github/workflows/bankai.yml`" — no command given, a hand-grep of a YAML comment/field, per invocation | `nen repo scenario --repo <path carrying schemas/repos.json> --target <owner/name>` — reads the same fact **live** off the `CON-14`-factual registry, and refuses by name when the target is not a recorded consumer (verified live, § 2.1) |
| 2 | The **Tooling matrix** (§ 2 of the old skill) was a markdown table baked into the skill file, matched **by eye** against the resolved scenario | `nen quality tooling --table <path.json> --scenario <name>` — looks the scenario up in the **target repository's own JSON manifest**, exits 1 with the known-scenarios list when absent (verified live, § 2.2) |
| 3 | The `>10%`/`>25%` regression rule was prose ("Budgets are regression-relative … `>10%` median regression is `high`, `>25%` is `critical`") applied by the agent doing the percentage arithmetic and the threshold comparison by hand | `nen quality perf-compare --metric <name> --baseline <n> --measured <n>` — computes the percentage and the severity, exits 1 on `high`/`critical` (verified live at and around both boundaries, § 2.3) |
| 4 | The `QA-15` five-field method block was prose ("device/OS · Release config, no debugger · `n ≥ 5` … · median and p90 · thermal/network conditions") the agent checked off by reading the reported number's write-up | `nen quality method-check --input <path.json>` — validates all five fields against the exact `MethodBlock` shape, exits 1 naming every gap (verified live, both a passing and a failing block, § 2.4) |

**Count.** Before: **4** steps where a deterministic fact or comparison was computed **by the agent's own
eye or arithmetic**, per invocation, with no command backing any of them — the scenario grep, the
table match, the percentage/threshold check, and the method-block field checklist. After: **0** — all
four are now a verb invocation with a fixed exit-code contract. What remains, unchanged and correctly so,
is the **judgment layer**: which `QA-2` hypothesis class applies, a finding's severity, the recommended
action, and the `Quality-Gate:` verdict itself — all Phinks'/Uvogin's (`docs/ROSTER.md`), never this
resolver's.

---

## 2. Live A/B transcript (read-only)

Every command below was actually run this session, against the real, frozen `bankai-core` checkout for
the registry- and canon-backed verbs, and against clearly-labelled **constructed** sample inputs for the
three verbs (`quality tooling`, `quality perf-compare`, `quality method-check`) whose data — a per-repo
tooling manifest, a measured number, a method block — has no live counterpart to read (§ 3 explains why).
No output below is fabricated or replayed from a prior run; every line is this session's actual stdout.

### 2.1 — `nen repo scenario`, live against `bankai-core`'s own registry

```
$ nen repo scenario --repo <bankai-core checkout> --target zheref/KroApple
swiftui-tca-uzf-v2
$ echo exit: $?
exit: 0

$ nen repo scenario --repo <bankai-core checkout> --target zheref/KroAndroid
compose-uzf-v2
exit: 0

$ nen repo scenario --repo <bankai-core checkout> --target zheref/bankai-scaffold
bankai-core
exit: 0
```

All three match the `scenario` field recorded for that repo in `schemas/repos.json` at `v0.11.3`,
read directly from the same file to confirm (`zheref/KroApple` → `"scenario": "swiftui-tca-uzf-v2"`,
`zheref/KroAndroid` → `"compose-uzf-v2"`, `zheref/bankai-scaffold` → `"bankai-core"`). **Same, on all
three.**

**The one structural gap, verified live — `bankai-core` cannot resolve its own scenario this way:**

```
$ nen repo scenario --repo <bankai-core checkout> --target zheref/bankai-core
nen: 'zheref/bankai-core' is not a consumer in <bankai-core checkout>\schemas\repos.json. Its
scenario cannot be read from a registry that does not know it.
exit: 1

$ nen repo scenario --repo <bankai-core checkout> --target zheref/NotARepo
nen: 'zheref/NotARepo' is not a consumer in <bankai-core checkout>\schemas\repos.json. Its
scenario cannot be read from a registry that does not know it.
exit: 1
```

`bankai-core` is not listed as its own consumer (a repo cannot consume itself), so the refusal is
identical in shape to a genuinely unknown repo — this is **expected, not a defect** (§ 3), and the ported
skill's § 1 carve-out reads `bankai-core`'s scenario directly off its own workflow's hardcoded
`bankai_scenario: 'bankai-core'` instead, since there is structurally no registry row to resolve it
against.

### 2.2 — `nen quality tooling`, against a constructed manifest

No repository in the reachable estate ships the JSON manifest `--table` wants (§ 3), so this transcribes
the live `handbooks/quality-baseline.md` § B "Tooling matrix" (`bankai-core` `v0.11.3`) into JSON,
labelled `tooling-table.CONSTRUCTED.json`, to prove the verb against real canon content rather than
placeholder strings:

```
$ nen quality tooling --table tooling-table.CONSTRUCTED.json --scenario swiftui-tca-uzf-v2
scenario: swiftui-tca-uzf-v2
  e2e: XCUITest (XCUIApplication, launch arguments for seeded state) via xcodebuild test -scheme
       {{SCHEME}} -destination 'platform=iOS Simulator,name={{SNAPSHOT_DEVICE}},OS={{SNAPSHOT_OS}}'
  adversarial: swift-testing (@Test) for hostile-input and boundary suites; TestStore for race and
       effect-ordering hypotheses
  not used: Appium, Selenium
  perf harness: XCTMetric (XCTApplicationLaunchMetric, XCTMemoryMetric, XCTClockMetric,
       XCTOSSignpostMetric)
  perf diagnosis: Instruments (Time Profiler, Allocations, Animation Hitches, Hangs)
exit: 0

$ nen quality tooling --table tooling-table.CONSTRUCTED.json --scenario dotnet-winui-uzf-v1
nen: 'dotnet-winui-uzf-v1' has no entry in this tooling table. Known scenarios:
  swiftui-tca-uzf-v2, compose-uzf-v2, react-uzf-v1, bankai-core
exit: 1

$ nen quality tooling --table tooling-table.CONSTRUCTED.json --scenario bankai-core --json
{
  "ok": true,
  "scenario": "bankai-core",
  "tooling": {
    "e2e": "bats (tests/*.bats) driving scripts/*.sh, plus yq assertions over .github/workflows/*.yml",
    "adversarial": "pytest for the Python guards (tests/test_*.py)",
    "notUsed": [],
    "perfHarness": "wall-clock of make test from a clean checkout + per-guard wall clock",
    "perfDiagnosis": "gh run view --json jobs durations"
  },
  "reason": null
}
exit: 0
```

**Old-side comparison:** the old skill had no command here at all — the agent matched the resolved
scenario against the markdown table by eye. There is no read-only old-side invocation to run in
parallel; the comparison is that the verb's output for `swiftui-tca-uzf-v2` and `bankai-core`
reproduces the same content the handbook's own markdown table states for those rows, field for field —
confirmed by re-reading `handbooks/quality-baseline.md` § B alongside the JSON above.

### 2.3 — `nen quality perf-compare`, both sides of the `10%`/`25%` lines

```
$ nen quality perf-compare --metric P1-cold-launch --baseline 1000 --measured 1050
P1-cold-launch: 5.0% vs baseline -- ok           exit: 0

$ nen quality perf-compare --metric P1-cold-launch --baseline 1000 --measured 1100
P1-cold-launch: 10.0% vs baseline -- ok          exit: 0   # exactly 10% is STILL ok — the rule reads >10%

$ nen quality perf-compare --metric P1-cold-launch --baseline 1000 --measured 1150
P1-cold-launch: 15.0% vs baseline -- high        exit: 1

$ nen quality perf-compare --metric P1-cold-launch --baseline 1000 --measured 1250
P1-cold-launch: 25.0% vs baseline -- high        exit: 1   # exactly 25% is HIGH, not critical — >25%

$ nen quality perf-compare --metric P1-cold-launch --baseline 1000 --measured 1300
P1-cold-launch: 30.0% vs baseline -- critical    exit: 1

$ nen quality perf-compare --metric P1-cold-launch --baseline 1000 --measured 900
P1-cold-launch: -10.0% vs baseline -- ok         exit: 0   # improvement, lower is better

$ nen quality perf-compare --metric P1-cold-launch --baseline 0 --measured 500
nen: 'P1-cold-launch' has a zero baseline, so a percentage regression is not a defined number.
Record a non-zero baseline, or compare the absolute values yourself.
exit: 1
```

**Verified live, at exactly the boundary on both sides**: the rule is a **strict** `>10%`/`>25%`, never
`>=` — a value landing exactly on either threshold reads one severity **lower** than a careless
`>=`-reading agent would assign it. This is the single most valuable thing to have confirmed against the
real binary rather than assumed from the prose (`QA-13`'s own text: "`>10%` … is `high`, `>25%` … is
`critical`" — ambiguous on the boundary in prose; unambiguous in the verb).

### 2.4 — `nen quality method-check`, a passing and a failing `QA-15` block

Passing block (`method-block-PASS.CONSTRUCTED.json`, values invented for this test run):

```
{
  "device": "iPhone 15, Simulator", "os": "iOS 17.5",
  "releaseConfig": true, "debuggerAttached": false,
  "sampleSize": 6, "firstDiscarded": true,
  "median": 1180, "p90": 1340,
  "thermalState": "nominal", "networkCondition": "Wi-Fi, unshaped"
}
```

```
$ nen quality method-check --input method-block-PASS.CONSTRUCTED.json
OK -- method block is complete.
exit: 0
```

Failing block (`method-block-FAIL.CONSTRUCTED.json` — every one of the five requirements broken at once,
deliberately, to exercise every refusal line in one run):

```
{
  "device": "iPhone 15, Simulator", "os": "iOS 17.5",
  "releaseConfig": false, "debuggerAttached": true,
  "sampleSize": 3, "firstDiscarded": false,
  "median": 1180, "p90": null,
  "thermalState": null, "networkCondition": ""
}
```

```
$ nen quality method-check --input method-block-FAIL.CONSTRUCTED.json
gap: not measured in a Release configuration
gap: measured with a debugger attached -- QA-15 requires none
gap: sample size is 3, under the QA-15 minimum of 5
gap: the first run was not discarded (warm-up/cold-cache skew)
gap: no p90 reported
gap: no thermal state reported
gap: no network condition reported
exit: 1
```

Every one of the seven printed gaps corresponds to a distinct field of the constructed block, with no
gap printed for `device`/`os` (both non-empty in this block) and none for `median` (non-null) — the
validator reports **exactly** the fields that fail, never a blanket "invalid block".

---

## 3. Residue

- **Canon-set resolution is deliberately not duplicated here.** `nen canon resolve --repo … --target …
  --always-load … --stack-dir …` exists and could compute § 2's "always-load + exactly one stack
  handbook" derivation — but `claude/skills/README.md` names **two resolvers** for hatsu#2 (this one and
  a sibling), and the shared brief's own boundary is that this port's Scope is *tooling, performance
  tooling, and `QA-{n}` rules* specifically, not general handbook-set resolution. Adopting `canon
  resolve` here would duplicate the sibling resolver's lane rather than this skill's own. § 2 of the
  ported `SKILL.md` therefore stays a plain, live file read — unchanged from the old skill's own
  mechanic — and is flagged here rather than silently left inconsistent with the rest of this doc's
  "mechanize everything deterministic" thrust.
- **No repository in the reachable estate ships a JSON tooling manifest.** Verified: `bankai-core`
  `v0.11.3`'s tree carries the tooling and measurement matrices only as markdown inside
  `handbooks/quality-baseline.md`; Hatsu's own tree carries no such file at all
  (`git ls-tree -r origin/main` has no `docs/Quality/` path). This is **not a defect in `nen quality
  tooling`** — the verb's own `--help` and source (`src/quality/tooling.ts`'s header comment) are explicit
  that the table is deliberately the caller's, never one shipped in the binary, precisely so a
  per-repository vocabulary never leaks into shared code. It is a **real gap in the estate**: the first
  repo actually run through this resolver in earnest will need to author `docs/Quality/tooling.json` (or
  wherever its own canon-values convention points) before `nen quality tooling` can do anything for it.
  § 2.2's constructed table demonstrates the verb is correct and ready the moment that manifest exists.
- **Absolute performance ceilings have no verb, and are not expected to.** `perf-compare` computes only
  the regression-relative half of `QA-13`; the flat ceilings (`P1 ≤ 2000 ms`, `P7 ≤ 250 ms`/`≤5%`
  jank/`≤200 ms` INP, `P5 web ≤ 300 KB`) stay skill-stated citations, unchanged from the old skill, because
  the verb's own scope never claimed to cover them (confirmed against `src/quality/perf.ts`: no ceiling
  constant exists in that module at all).
- **Where a `QA-{n}` gap lands is now genuinely open, and this port does not resolve it.** The old skill
  closed with "`quality-baseline.md` and `INDEX.md` change only through a PR the human merges at G4" —
  true while `bankai-core` was live. `bankai-core` is now frozen (no PR against it, ever), and Hatsu ships
  no handbooks of its own, so that sentence is no longer true as written and is **not carried forward**.
  The ported `SKILL.md`'s "Rules" section names this as an open item rather than inventing a landing
  repository for a canon amendment — consistent with `docs/ROSTER.md`'s own OPEN-item discipline
  (`CONSTITUTION.md`'s eventual rewrite is tracked at
  [zheref/akatsuki-ai#5](https://github.com/zheref/akatsuki-ai/issues/5), not here).
- **Judgment kept, per the shared brief's boundary list:** which of the eight `QA-2` hypothesis classes
  applies, a finding's severity, the recommended action (`hold`/`ship-with-known-issue`/`fix-first`), and
  the `Quality-Gate:`/severity-routing logic all stay with Phinks and Uvogin (`docs/ROSTER.md`,
  `claude/agents/phinks.md`, `claude/agents/uvogin.md`) — this resolver only ever answers "which
  scenario, which tooling, which threshold severity, which method-block gaps", never "is this a
  release-blocking finding".
- **No missing verb.** `nen repo scenario`, `nen quality tooling`, `nen quality perf-compare`, and `nen
  quality method-check` cover every deterministic step this skill's Scope names. Nothing was found that
  the old skill did deterministically that has no `nen` counterpart at all.

---

## 4. Findings (report separately, do not route around)

**None against the `nen` binary itself in this port.** Every verb exercised — `nen repo scenario`, `nen
quality tooling`, `nen quality perf-compare`, `nen quality method-check` — behaved, live, exactly as its
`--help` text and pinned-`v0.1.0` source describe, including the two boundary checks in § 2.3 that are
easiest to get wrong (`10.0%` reading `ok`, `25.0%` reading `high` and not `critical`) and the zero-
baseline refusal. The estate-level gap recorded in § 3 (no committed JSON tooling manifest anywhere
reachable) is a finding about **the estate**, not about `nen` — the verb's refusal to ship a built-in
table is a deliberate design choice, confirmed against its own source comment, not an omission.

---

## 5. Corrections from adversarial review

The ported `SKILL.md`'s § 4 Measurement matrix was carried over from the old skill file **unverified**
against the frozen `bankai-core` snapshot rather than re-read from it. An adversarial review caught the
drift below; each cell was then re-checked row-by-row against `handbooks/quality-baseline.md` § C at
`v0.11.3` and corrected in place (never silently — recorded here per this port's own "record the gap,
don't route around it" discipline).

- **`react-uzf-v1` (web) Diagnosis cell was wrong.** It read "Chrome DevTools performance trace" — no such
  tool appears in the canon row at all. Canon (§ C, Measurement matrix) reads: `Lighthouse CI
  (`@lhci/cli`), pinned mobile preset`. Fixed to match verbatim.
- **`swiftui-tca-uzf-v2`'s P6 network harness was silently dropped.** Canon lists `URLSession` metrics via
  a test-only `URLProtocol` recorder; the ported row omitted it entirely. Restored.
- **Re-checking every remaining row surfaced three further silent drops, not separately flagged by the
  review but the same class of error:**
  - `react-uzf-v1` (web) also silently dropped its **P4 memory harness** (a CDP heap sample via Playwright)
    and its **P6 network harness** (Playwright `page.on('request'|'response')` totals) — both restored.
  - `compose-uzf-v2`'s P6 cell dropped the `+ OkHttp EventListener` half of canon's `TraceSectionMetric
    around the HTTP span + OkHttp EventListener` — restored.
  - `bankai-core`'s Diagnosis cell read `—`; canon's actual Diagnosis value for that row is `` `gh run
    view --json jobs` durations `` — the ported row had instead folded that text into the Harness cell
    and left Diagnosis empty. Diagnosis and Harness were each corrected to carry the right content.
  - **The entire `react-uzf-v1` (Expo) row was missing** from the ported Measurement matrix (it is present,
    correctly, in § 3's Tooling matrix, but the Measurement matrix table simply had no row for it at all).
    Canon's row (P1/P2 reuse the Apple/Android row for the native build under test; P5 EAS build artifact
    size; P6 RN network inspector, as web; Diagnosis `—`) is now restored.

No other cell in § 4's table diverges from `handbooks/quality-baseline.md` § C at `v0.11.3`, verified by a
full re-read of that section alongside the corrected table above.
