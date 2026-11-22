### Added

- **The bankai-fleet roster, `fleet/registry.json`.** One file lists every in-scope maintained zheref repository, 21 of them, with its stack and its owner, and nothing else. Pin values stay in each consumer's own `nen/` configuration, to be read live. The inventory is the one in Fuegoleon's Engineering Hub section of 2026-11-21: every maintained repository minus the exclusions ruled that day. The roster is G4 canon, so a change to it needs the maintainer's G4; `fleet/` joins zheref/hatsu's process set in `contracts/pr-composition.json`, so `nen gate derive` derives G4 for a roster-only change. Validation and the switch of repins and the weekly alignment review onto the roster are the epic's later children (zheref/hatsu#620). Plugin 0.173.0.

### Changed

- **The roster's other fourteen private repositories are named by ruling** (HR-396, a partial supersession of HR-143; governance 1.86.0). Fifteen of its rows are private: `zheref/akatsuki-ai` was already named. They are added to `scripts/private_name_named.txt` beside `zheref/akatsuki-ai`, and the `redaction-guard` fixture pins the wider set. `docs/PUBLIC-REDACTION.md` § *Named private repositories* records this second exception. Names become public; contents stay private. `zheref/kro-pwa` leaves the policy's list of public repositories, because it is private today.
