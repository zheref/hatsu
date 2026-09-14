# Changelog

## v0.25.0 — Netero; Breath cuts a new branch; G5 reports explain the stop

- Ratified **Netero** as process chairman: he observes Hunter execution and files complete, labelled issues when constitution, canon, or machinery need enhancement, with cross-references for deployment, fan-out and provisioning (roster ruling 2026-09-14).
- **Breath** and **Ren** treat a new request as a new effort: fetch the configured base and cut a freshly rendered branch even from a clean unrelated feature branch. An existing branch is reused only for an explicit continuation ([#60](https://github.com/zheref/hatsu/issues/60)).
- **G5 stop reports** carry a `blocker` payload on the Rikugan `turn` page — step, rule, expected versus actual, this-run visual evidence — and Jutaisho verifies that content before the stop handoff links it ([#56](https://github.com/zheref/hatsu/issues/56)).

## v0.24.0 — byakugan owns coverage; kotoamatsukami owns tests

- Added **byakugan** for coverage capture and measurement at mukai, independent of unit, UI and integration testing. Grammar `against [<base>]`. Never runs `test` or `ui-test`.
- Restored **kotoamatsukami** to tests only (plus UI evidence). Mukai still runs tests then coverage, as two skills.
- Left **gyo** as linting on every Ren turn.

## v0.23.0 — gyo is linting; kotoamatsukami owns coverage

- Renamed **gyo** to the linting process (`nen shu lint`) on every Ren turn: breath on the tip, rasengan may, kokusen must, aka before squash and after catch-up.
- Folded coverage capture, extraction, banding and the under-minimum G5 onto **kotoamatsukami**, still at mukai, still after the impacted suites. Behaviors did not move; the names did.

## v0.22.0 — rikugan session archive vs last-turn board

- Kept **00 This last turn** as the last human request only.
- Required **01–07** (accomplished, challenges, not delivered, architecture, screenshots, launch, decisions) to cover the whole session against the base, on every process or product effort. A later turn that rewrites those lists from only the latest request is a defective page.

## v0.21.0 — rikugan last-turn highlights and structural architecture delta

- Opened every Rikugan page with **00 This last turn**: highlights against the last human request (`done` / `not-done` / `partial`). A mukai-triggered page also names what was corrected (who asked, why, handled or pushed back), local checks that brought work back, and any half-run stop with the policy and how later iterations can go further unattended.
- Made **04 Architecture delta** a change-highlighted board of conceptual nodes and relations. `files[]` remains a supporting path inventory, not the glance target.

## v0.20.0 — focused tests at ren, impacted regression at mukai

- Moved project-wide regression off aka. Aka now lints, squashes unpublished history, catches up, re-lints if that moved the tree, and pushes.
- Made tsukuyomi the focused-test executor on every ren turn; kokusen still owns the checkpoint.
- Made kotoamatsukami the sole owner of pre-mukai project-wide tests, selecting only declared suites the change can affect, immediately before gyo extracts coverage.

## v0.18.0 — complete local workflow and explicit review policy

- Documented the one-request entry path across Claude Code, Codex, and Cursor ([#45](https://github.com/zheref/hatsu/pull/45)).
- Made first-run surface bootstrap transactional and safe around user-owned files, closing [#46](https://github.com/zheref/hatsu/issues/46) in [#47](https://github.com/zheref/hatsu/pull/47).
- Aligned authoring, verification, launch, discovery, regression, coverage, and UI evidence phases; adopted Nen 0.9 device extraction and closed [#48](https://github.com/zheref/hatsu/issues/48) and [#49](https://github.com/zheref/hatsu/issues/49) in [#50](https://github.com/zheref/hatsu/pull/50).
- Preserved canonical Hatsu/Akatsuki agent provenance while excluding model, runtime, surface, and session credits, authored for [#51](https://github.com/zheref/hatsu/issues/51) in stacked [#52](https://github.com/zheref/hatsu/pull/52) and landed on main by [#55](https://github.com/zheref/hatsu/pull/55).
- Moved Hatsu CI to trusted self-hosted macOS runners and denied fork PR runner allocation, closing [#53](https://github.com/zheref/hatsu/issues/53) in [#54](https://github.com/zheref/hatsu/pull/54).
- Adopted published Nen 0.10 and its explicit Copilot-only `review-round-only` readiness policy while retaining the maintainer's separate human merge decision ([#55](https://github.com/zheref/hatsu/pull/55)).

Version history: main advanced through plugin cache versions 0.15.0 (#47) and 0.16.0 (#50). Attribution PR #52 introduced 0.17.0 but merged into the old #50 branch, not main. Release PR #55 preserves that merge and lands its attribution changes on main together with 0.18.0. No 0.15–0.17 official tags were cut; this consolidated release follows v0.14.0.

Nen 0.10 release: [zheref/nen v0.10.0](https://github.com/zheref/nen/releases/tag/v0.10.0).
