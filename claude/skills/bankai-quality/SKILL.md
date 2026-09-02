---
name: bankai-quality
description: Resolve the right adversarial-test tooling, performance-measurement tooling, and QA-{n} rules for a repo's bankai_scenario. Use before a release is cut, deployed, or published — when Phinks runs his adversarial pre-release QA, when Uvogin measures a performance budget, when authoring an E2E/adversarial test, or when either needs the scenario's pinned tooling before writing one.
---

# Resolving Bankai quality tooling & rules

`handbooks/quality-baseline.md` (`QA-{n}`), read live from the **frozen** `bankai-core` checkout — Hatsu
ships no handbooks of its own yet, and `docs/ROSTER.md`'s own Sources section directs the same read — is
the **single canonical source** for adversarial-QA method, test tooling, and performance budgets. This
skill is a **resolver**: it resolves *which* tooling, budget thresholds, and rules apply to the repo in
front of you, and no more. The judgment layer — which `QA-{n}` class applies, a finding's severity, the
`Quality-Gate:` verdict itself — is **Phinks**' and **Uvogin**'s (`claude/agents/phinks.md`,
`claude/agents/uvogin.md`), not this skill's; read those files for the full protocol this skill's
resolutions feed.

**This gate is local, on-demand, and advisory.** It runs on the human's own credentials before a tag cut
or a store submission, deploy or publish (`QA-20`). Its verdict informs the human's **G3** (`CON-6`); it
never blocks (`QA-21`). Hatsu's roster carries no CI counterpart — `docs/ROSTER.md` lists no quality gate
among the ratified independents, and there is no scheduled sweep behind Phinks or Uvogin either.

---

## 1. Resolve the scenario — `nen repo scenario`, never a hand-grep

The old mechanic read `bankai_scenario` out of the target repo's own `.github/workflows/bankai.yml` by
eye. That is now a verb:

```
nen repo scenario --repo <path to a checkout carrying schemas/repos.json> --target <owner/name>
```

`--repo` is a **path**, not a slug — today that path is the frozen `bankai-core` checkout, since that is
where the consumer registry Naruto kept (`schemas/repos.json`) lives; `--target` is the product repo's
`owner/name`. The verb reads the scenario **live**, off the same `CON-14`-factual registry
`pr-state`'s `--repo` flag and `warmup`'s stale-pin sweep already read — never a value remembered from a
prior session. **Exits 1**, naming the repo and the registry path, when the target is not a recorded
consumer or carries no scenario (verified live, `docs/ab/bankai-quality.md` § 2.1) — that refusal is
itself a finding about the registry, never a licence to guess a scenario.

> **`bankai-core` itself is the one case this verb cannot resolve, and that is expected, not a defect.**
> A repository cannot be its own consumer, so `bankai-core` carries no entry for itself in
> `schemas/repos.json` — `nen repo scenario --target zheref/bankai-core` refuses identically to an
> unknown repo (verified live, § 2.1). For `bankai-core` as the target, its scenario is the **fixed
> literal `bankai-core`**, stated directly in its own `.github/workflows/bankai.yml` header comment
> (`bankai_scenario: 'bankai-core'`) — read that value directly rather than routing it through this verb.
> This is the one scenario resolution this skill still does by direct read, and only because there is
> structurally no registry entry to resolve it against.

## 2. Load the quality canon — always, live, never from memory

1. `handbooks/quality-baseline.md` (`QA-{n}`) — every scenario, `bankai-core` included.
2. The **existing** testing canon, so a run extends it instead of duplicating it (`QA-9`):
   `handbooks/uzf-core.md` `UZF-18`/`UZF-19`/`UZF-20`/`UZF-26`, plus `handbooks/stacks/<scenario>/rules/`
   — `07-testing.md` (swiftui) or `09-testing.md` (compose, react). A missing unit test or a
   coverage-floor breach is the architecture reviewer's `UZF-19` finding, never a `QA-{n}` one.
3. `handbooks/stacks/<scenario>/architecture.md` — only when a finding needs a stack rule cited
   (`SW-{n}` / `KT-{n}` / `RC-{n}` / `BC-{n}`). Never load another scenario's folder.

All three are read from the frozen `bankai-core` checkout at its snapshot tag, never at a branch, and
never written to — no issue, comment, label, branch, push or PR against it, ever.

## 3. Resolve the scenario's tooling — `nen quality tooling`

```
nen quality tooling --table <path.json> --scenario <name>
```

`--table` is the **target repository's own manifest** — never a table shipped in `nen`, never one
remembered here. Exits 1 when the scenario has no entry: a finding about the manifest, never a licence to
pick a tool by improvisation.

**No repo in the reachable estate ships this JSON file today** — verified: the frozen `bankai-core`
checkout carries the tooling matrix only as markdown (`handbooks/quality-baseline.md` § B), and Hatsu
carries no such file at all. This is genuine residue (`docs/ab/bankai-quality.md` § 3), not a defect in
the verb — the manifest is deliberately the caller's, per its own `--help` text. Until a target repo
authors one (conventionally at `docs/Quality/tooling.json`, keyed by scenario, in the shape `nen quality
tooling` expects — see `docs/ab/bankai-quality.md` § 2.2 for a worked, clearly-labelled constructed
example transcribed from the live handbook), the values below are the **reference content to seed it
with**, transcribed from `bankai-core`'s live `quality-baseline.md` § B (current as of `v0.11.3`) — cite
the handbook when reporting a tooling choice, never invent a value, and prefer running the verb the moment
a manifest exists over reading this table by eye.

| Scenario | E2E / UI automation | Adversarial logic layer | Not used |
| --- | --- | --- | --- |
| `swiftui-tca-uzf-v2` | XCUITest via `xcodebuild test -destination …` | swift-testing; `TestStore` for race and effect ordering | Appium, Selenium |
| `compose-uzf-v2` | Compose UI Test on a Gradle Managed Device; Espresso/UIAutomator for cross-app and system dialogs | JUnit5 + Turbine | Appium, Selenium |
| `react-uzf-v1` (web) | Playwright (`page.route` for degradation; `--repeat-each=3` for `QA-4`) | Vitest | Selenium, Cypress |
| `react-uzf-v1` (Expo) | Maestro against a dev-client build | Jest (`jest-expo`) + RNTL | Detox, Appium |
| `bankai-core` | bats over `scripts/*.sh` + `yq` assertions over `.github/workflows/*.yml` | pytest | — |

Selenium and Appium are **never a default** — use one only where a target has no first-party driver (a
legacy browser matrix, a physical-device farm), and say so in the report (`QA-7`).

## 4. Performance thresholds — `nen quality perf-compare`

```
nen quality perf-compare --metric <name> --baseline <n> --measured <n>
```

`QA-13`'s own thresholds, computed rather than reconstructed by hand: a median regression **strictly
greater than 10%** is `high`, **strictly greater than 25%** is `critical` — both are **regression-relative
to `--baseline`**, and **lower is better for every one of the fixed seven metrics**, so there is no metric
here where a bigger measured number is good. Exits 1 when severity is `high` or `critical`; exits 0 on
`ok`, including an **improvement** (a negative regression). A **zero baseline** is refused outright rather
than divided by (verified live, `docs/ab/bankai-quality.md` § 2.3) — record a non-zero baseline or compare
the absolute values by hand.

**Verified live, exactly at both boundaries (§ 2.3):** `10.0%` itself is `ok` (the rule is *strictly*
greater than 10%, not "at least"), and `25.0%` itself is `high`, not `critical` — the same strict-`>`
reading on both edges. Never round a boundary value up to the next severity by hand; relay the verb's own
computed severity.

**Independently, these absolutes hold regardless of baseline** — `perf-compare` does not check them, so
they remain this skill's own citation, never a computation to improvise:

- **P1 ≤ 2000 ms** median on the reference device.
- **P7 ≤ 250 ms** (Apple hang threshold) / **jank frames ≤ 5%** (Android) / **INP ≤ 200 ms** (web).
- **P5 web initial transfer ≤ 300 KB** compressed.

**A number produced by a tool other than the scenario's pinned one (§ 3) is reported as a `diagnostic`,
never fed into `perf-compare` as a budget check** (`QA-12`) — cross-tool numbers are not comparable, and
pinning the tool is the only thing that makes this percentage mean anything.

### Measurement matrix (reference — read live, same residue as § 3's table)

| Scenario | Harness | Diagnosis |
| --- | --- | --- |
| `swiftui-tca-uzf-v2` | `XCTMetric` in an XCTest perf test — `XCTApplicationLaunchMetric`, `XCTMemoryMetric`, `XCTClockMetric`, `XCTOSSignpostMetric` over `os_signpost` intervals; App Thinning size report; `URLSession` metrics via a test-only `URLProtocol` recorder (P6 network) | Instruments (Time Profiler, Allocations, Animation Hitches, Hangs) |
| `compose-uzf-v2` | Jetpack Macrobenchmark — `StartupTimingMetric`, `FrameTimingMetric`, `MemoryUsageMetric`, `TraceSectionMetric` around the HTTP span + OkHttp `EventListener`, with a `BaselineProfile`; AAB analyzer for size | Perfetto |
| `react-uzf-v1` (web) | Lighthouse CI on a pinned mobile preset (Moto-G-class, 4× CPU, Slow 4G) + Web Vitals (LCP/INP/CLS/TBT) collected in the Playwright run; a CDP heap sample via Playwright (P4 memory); Playwright `page.on('request'\|'response')` totals (P6 network); `next build` + `@next/bundle-analyzer` for bytes | Lighthouse CI (`@lhci/cli`), pinned mobile preset |
| `react-uzf-v1` (Expo) | Reuse the Apple/Android row for the native build under test (P1/P2); EAS build artifact size (P5); RN network inspector, as web (P6) | — |
| `bankai-core` | wall-clock of `make test` from a clean checkout + per-guard-script wall clock | `gh run view --json jobs` durations |

## 5. Method-block validation — `nen quality method-check`

```
nen quality method-check --input <path.json>
```

`QA-15`'s five fields, validated rather than eyeballed: device/OS stated, Release config with **no
debugger**, sample size **≥ 5** with the first discarded, **median and p90** reported, thermal and network
conditions stated. **Exits 1 on any gap** and names every missing field (verified live, both a passing and
a failing block, `docs/ab/bankai-quality.md` § 2.4) — there is no partial credit: a block missing even one
field is reported as a measurement that could not be completed, never as a number.

The verb's input is the exact `MethodBlock` shape:

```json
{
  "device": "<string>", "os": "<string>",
  "releaseConfig": true, "debuggerAttached": false,
  "sampleSize": 6, "firstDiscarded": true,
  "median": 1180, "p90": 1340,
  "thermalState": "nominal", "networkCondition": "Wi-Fi, unshaped"
}
```

Report the verb's verdict rather than a hand-reading of the block — a block that *looks* complete but
fails validation (a stray empty string in `networkCondition`, a `sampleSize` of exactly 5 with the first
discarded miscounted) is exactly the class of gap this verb exists to catch instead of missing by eye.

## 6. Machinery scenario (`bankai-core`) — `QA-16`–`QA-18`

- `make lint` and `make test` green **from a clean checkout**.
- Drive changed `scripts/*.sh` with the hostile-input corpus — empty, missing, malformed
  JSON/YAML, non-UTF-8, oversized, a path with spaces, an extra field — and require **fail-closed**.
- Assert every privileged or wake-bearing workflow `if:` **conjunct by conjunct** with `yq` in a
  bats case; `tests/wake_label_iterate.bats` is the shape.
- Every guard needs at least one **negative** test; happy-path-only counts as untested.
- Its wall-clock budget flows through the same § 4 mechanics: `make test` ≤ 120 s, any single guard
  ≤ 5 s on the recorded machine, both regression-relative via `perf-compare` against the prior release.

## Rules this resolver still carries

- **Cite findings by rule id, never invent one.** A gap no `QA-{n}` covers is a canon question. But
  `bankai-core` is **frozen** — no issue, comment, label, branch, push or PR against it, ever — and Hatsu
  ships no handbooks of its own yet, so `quality-baseline.md` cannot be amended through any PR today.
  **Record the gap, do not invent a landing repository for it, and do not treat it as silently resolved.**
  Where the rewritten constitution lands is itself an **open item** tracked at the P3 rewrite
  ([zheref/akatsuki-ai#5](https://github.com/zheref/akatsuki-ai/issues/5)) — an OPEN item stays OPEN.
- **Extend, never duplicate** the stack's existing test minimums (`QA-9`) — a coverage-floor breach
  routes to the architecture reviewer, never here.
- **One default tool per scenario per layer** (`QA-7`); a deviation states its reason in the report.
- **Measurement is tool-pinned per scenario** (`QA-12`) — a cross-tool number is a `diagnostic`, never a
  budget check, and stays labelled as one.
- **The verdict marker is `Quality-Gate:`, never `Verdict:`** (`QA-21`) — that marker is reserved for the
  CI review gates (Sasuke, Tenma, Bisky) that still run in the consuming product repos' own CI today, and
  a quality report must never collide with it. This resolver produces the tooling choice and the
  threshold/method-block computations that feed that line; Phinks emits it, per his own file.
- **No LLM-improvised fallback for a Nen-owned operation, ever.** If `nen` is unavailable and the
  bootstrap failed, the resolution does not happen — say so; never approximate a scenario, a tooling
  choice, a severity, or a method-block verdict by hand in its place.
