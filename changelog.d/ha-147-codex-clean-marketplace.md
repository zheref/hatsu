### Codex installs from a committed, clean marketplace snapshot ([#147](https://github.com/zheref/hatsu/issues/147), 0.108.1)

- `hatsu_surface_link.sh --surface codex` archives the served commit before registering its marketplace. Codex's copied plugin slot excludes `.git`, ignored settings, worktrees, `.nen/` and `Reports/`. An existing direct-checkout marketplace is migrated to the snapshot.
- `hatsu_plugin_update.sh --codex` resolves the source checkout from the snapshot's adjacent record, updates it, re-registers the new committed snapshot and reads back the installed version. A changed snapshot refuses installation; the fixture suites cover migration, excluded local files and tampering.
- The Codex guides explain what is copied and how to remove an old marketplace registration, snapshot and cache slot.
