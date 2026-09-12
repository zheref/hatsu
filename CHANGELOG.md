# Changelog

## v0.18.0 — complete local workflow and explicit review policy

- Documented the one-request entry path across Claude Code, Codex, and Cursor ([#45](https://github.com/zheref/hatsu/pull/45)).
- Made first-run surface bootstrap transactional and safe around user-owned files, closing [#46](https://github.com/zheref/hatsu/issues/46) in [#47](https://github.com/zheref/hatsu/pull/47).
- Aligned authoring, verification, launch, discovery, regression, coverage, and UI evidence phases; adopted Nen 0.9 device extraction and closed [#48](https://github.com/zheref/hatsu/issues/48) and [#49](https://github.com/zheref/hatsu/issues/49) in [#50](https://github.com/zheref/hatsu/pull/50).
- Preserved canonical Hatsu/Akatsuki agent provenance while excluding model, runtime, surface, and session credits, authored for [#51](https://github.com/zheref/hatsu/issues/51) in stacked [#52](https://github.com/zheref/hatsu/pull/52) and landed on main by [#55](https://github.com/zheref/hatsu/pull/55).
- Moved Hatsu CI to trusted self-hosted macOS runners and denied fork PR runner allocation, closing [#53](https://github.com/zheref/hatsu/issues/53) in [#54](https://github.com/zheref/hatsu/pull/54).
- Adopted published Nen 0.10 and its explicit Copilot-only `review-round-only` readiness policy while retaining the maintainer's separate human merge decision ([#55](https://github.com/zheref/hatsu/pull/55)).

Version history: main advanced through plugin cache versions 0.15.0 (#47) and 0.16.0 (#50). Attribution PR #52 introduced 0.17.0 but merged into the old #50 branch, not main. Release PR #55 preserves that merge and lands its attribution changes on main together with 0.18.0. No 0.15–0.17 official tags were cut; this consolidated release follows v0.14.0.

Nen 0.10 release: [zheref/nen v0.10.0](https://github.com/zheref/nen/releases/tag/v0.10.0).
