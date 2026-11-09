### Fixed

- `scripts/stop_bell_fixture.mts`'s decoy `osascript` is now a symlink to node rather than to `sleep`. GitHub's `ubuntu-latest` moved to Ubuntu 26.04, whose multicall uutils coreutils dispatches on argv[0], so a `sleep` invoked as `osascript` exited at once and `stop-bell-guard` failed every PR with `the decoy is visible to a match by name`. The name check now polls briefly for the exec to land.
