### Changed

- Retire Hatsu's duplicate kagutsuchi worktree engine and its focused lane in favour of the pinned `nen wc worktree` API: § 3b checks core and swap state, expands `project.fromCore[]` into repeated `--copy-from-core` arguments, previews, then runs the fixed `kagutsuchi` worktree with Nen's native refusals and retention. A hermetic real-Nen transcript replaces the retired fixture. Part of #246.
- Route Hatsu's `claude-code-plugin` stack through the existing Node OSV audit row. The real npm lock contains 60 non-root development entries and is exercised by the resolver fixture; it is never declared scanned-empty. This is an npm-lock verdict only: the pinned Ruby coverage gems remain SHA256 integrity-checked but not advisory-scanned. Part of #246.

### Fixed

- `config_values.sh diagnose` now reports a standing `deploy.defaultTarget` as invalid when its declared target does not clearly say non-production or lacks `nonProduction: true`, names the contract repair, preserves unread/null states, and keeps plain and JSON outstanding counts aligned. Part of #246.
- HA#246's desktop-overlap question needs no new ruling: HR-330 already retired `jusshin <desktop-overlap>` after per-pool `pool-<id>` labels removed the overlap. The unnamed iOS consumer's `testflight` declaration and linked issue or PR remain owed until the maintainer identifies the eligible repository; no consumer repository is changed or falsely reported complete here.
