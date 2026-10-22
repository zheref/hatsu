### Added

- **`docs/history/nen-repins.md`** — one row per nen pin (version, minimum, nen floor, date, commit, PR) with each repin's adopted verbs and absorbed breaking notes, moved verbatim from `nen/contract.json` → `dependency.minimum_semantics`, which now reads one sentence and a pointer.
- **`scripts/plugin_version_refs.sh --check-nen-pin`** — exits `1` when `docs/NEN-CONTRACT.md`'s echoed pin line disagrees with the contract's `dependency.minimum` or `pinned_ref`, `2` when either side is unreadable; the `plugin-version-refs` fixture covers agreement, both drifts and both refusals.

### Fixed

- **`hatsu:great-hiker` § 2** routes prose to `models.<surface>.deep` (Opus on Claude Code, `pro` on Antigravity), no longer a Fable subsession its own Hard limits and `models.rule` forbid.
- **`docs/NEN-CONTRACT.md` § *The range*** echoes `nen >= 0.24` installing `v0.24.0`, names the v0.24.0 adoption and floor, and drops a stale skill count.
- **Hand-typed counts** dropped from `README.md`, `claude/skills/README.md` and `docs/surfaces/codex.md`; **`hatsu:futon`'s residue** no longer restates the pin. Plugin bumped to 0.131.4.
