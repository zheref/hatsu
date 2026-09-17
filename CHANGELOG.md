# Changelog

## v0.32.0 — plugin updater isolation, focused lane, and refuse paths

- `scripts/hatsu_plugin_update.sh` unsets `GIT_DIR` / `GIT_WORK_TREE` (and related git redirectors) after the filesystem identity check, so `git -C --root` cannot mutate a different checkout.
- A nested Hatsu tree without its own `.git` is not treated as the enclosing repository: `rev-parse --show-toplevel` must match `--root`.
- Stable tags are strict `vX.Y.Z` (digits and dots only); `--auto` will not treat `v1.2.3.4` as a release consumer.
- `--channel release` with no stable `vX.Y.Z` tags refuses instead of silent exit 1; a missing origin and unreadable `.git` are named skip/refuse paths.
- Warm-up cites `$hatsu_root` for updater fixture and SURFACES paths so nested Antigravity mirrors do not get a broken `../../../` link.
- Focused `plugin-update` lane declares the updater fixture; `plugin-bump-guard` asserts the updater glob.

## v0.31.0 — plugin source auto-update across surfaces

- Warm-up keeps a consumer plugin checkout current before it refreshes a target: `scripts/hatsu_plugin_update.sh --auto` fast-forwards trunk or the newest `vX.Y.Z` tag, skips dirty and authoring trees, and never discards.
- Claude Code's versioned cache is not a git checkout; the same script names `claude plugin update hatsu@hatsu`, and warm-up passes `--claude` there.
- Documented per-surface update recipes and how to point each surface at a local checkout so Cursor does not bind a stale Claude plugin cache while authoring this tree.

## v0.30.0 — Hanten cycle ledger fail-closed

- Cycle ledger `init` is Breath's after the branch cut. `decide` / `record` / `show` refuse a missing file instead of treating absence as a new cycle.
- Load-mutate-save is serialized with an exclusive lock and a unique temp path.
- `skipped-exhausted` is refused while `used < max`.
- G5 blocker owner list includes kokusen; first finding separator is sibling-based; blocker captures use the same data-URI rule as evidence.

## v0.29.0 — Illumi Codex spawn; generated inventory

- Illumi's En observation hand-off uses Codex in-session spawn; Hanten's reviewer isolation stays a second `codex exec`.
- Generated surface inventories: 41 skill files (forty plus warmup) and 9 personas.

## v0.28.0 — Third-Hand is a phase after En; Codex and Antigravity pickers

- **Third-Hand** is a separate phase that starts once En has completed. En ends at the gate and does not harvest.
- Codex asks through `request_user_input` (never lettered options) and raises Netero in-session (`spawn_agent`). Antigravity asks through `ask_question` (`is_multi_select: true`) and raises Netero with `invoke_subagent` `Workspace: "inherit"`.

## v0.27.0 — Third-Hand closes the sitting with Netero's harvest

- Added **third-hand**: after En's retained final report, Netero runs in parallel, folds this sitting's process friction into 0–3 issues, the maintainer picks which to file through the surface picker, those are filed, then the session is over. He never implements the filed work. The merge stays a human G2 act with no skill.

## v0.26.0 — cap Hanten reviewer reruns per effort

- **Hanten** records each reviewer invocation in `.nen/hanten/<branch-slug>.cycle.json` for the whole effort. Applicability and remaining budget are separate questions; an exhausted reviewer is skipped, not invoked. Maxima: Feitan 1, Chrollo 1, Phinks 1, Hisoka 2, Uvogin 3. Remediation, a resumed session, and a later Ren or Mukai re-entry reuse the same counts. Only Breath cutting a new branch resets them ([#63](https://github.com/zheref/hatsu/issues/63)).

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
