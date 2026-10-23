### Added

- **The steady-state schedule (zheref/hatsu#448; ruling R-2026-10-23-21, effort HA-IS-#450).** `contracts/schedule.json` (`hatsu.schedule/v0.1`) holds the four rows on the ruled scheduler, Claude Desktop's local scheduled tasks on the maintainer's machine: `drift-pass` (quarterly, `great-hiker evolve` over every surface, dry first, nothing filed twice on the same day through `nen issue search`), `recapture` (weekly `dowsing-chain recapture <family> --dry-run`; a local task carries no tag event), `morning-desk` (weekdays, `rikugan for <repo> as register`, the last idle run first) and `ratchet-shrink` (CI, `canon-lint` on every pull request). Page: `docs/config/schedule.md`. No row names a release step (HR-5).
- **`scripts/schedule_install.mts` prints the tasks and registers nothing.** Per task, the fields of Desktop's *New scheduled task* form and the `SKILL.md` Desktop keeps at `~/.claude/scheduled-tasks/<name>/SKILL.md`; exit `0` every placeholder filled, `1` one unfilled (named), `2` wiring. `--family` reaches stdout only. Its hermetic fixture is the `schedule-printer` lane, run in `unit-tests.yml` through `scripts/unit_tests_ci.mts`. Dry run: `docs/ab/schedule-install.md`.
- **`canon-lint` counts the shrink.** Against `--base` or `--base-baseline`, `scripts/prose_ambiguity_check.mts` prints `<n> removed over <base>` in its summary line and `removedBaseline` in `--json` (null with no base), summed per key.

### Changed

- `great-hiker` § Residue 1 and `docs/WORKFLOW.md` § *Idle batches* name the schedule page.
