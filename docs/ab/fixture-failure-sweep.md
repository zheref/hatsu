# Named fixture failures — #243

The sweep covered `scripts/*_fixture*.sh` and `scripts/*_red.sh`. A substitution that computes a value an assertion compares must tolerate an expected no-match and reach the fixture's `fail` with expected and actual values. A setup command such as `mktemp`, `git rev-parse`, or the script under test succeeding is a wiring precondition; its nonzero exit is still named by the declared test-seat wrapper.

| Fixture | Check-result substitutions | Disposition |
|---|---|---|
| `surface_mirror_check_fixture.sh` | the three surface root extracts, the placed-hooks sed extract, and the Codex root extract | Root extracts already used `|| true`; the placed-hooks and Codex extracts now do, and the comparison names missing values. |
| `surface_mirror_regenerate_fixture.sh` | generated and checked surface call extracts | Already used `|| fail` for each surface. |
| `prose_size_check_fixture.sh` | headroom skill and edge agent extracts, report row count | Skill and agent extracts now tolerate no match before named assertions; row count already did. |
| `permissions_pack_fixture_check.sh` | the pack and bootstrap placed-hooks sed extracts | Both now tolerate no match; one assertion names the two values. |
| `hatsu_plugin_update_fixture_check.sh` | snapshot registration and plugin add positions | Both now tolerate no match; the order assertion names the two positions. |
| `surface_mirror_wake_fixture.sh` | event, types, paths and job-if fields | `sed -n` succeeds with an empty value; their subsequent assertions name expected and actual values. |
| `getsuga_default_cut_point_red.sh`, `runner_preflight_fixture_check.sh`, `nen_global_fixture_check.sh` | text extracts used as assertion inputs | These do not run under `set -e`; their subsequent checks receive the empty value. |

The rest of the substitutions select a scratch path, derive a fixture's setup data, or invoke the subject whose success is a precondition. `scripts/fixture_output_guard.sh` preserves their exit and emits the fixture path plus exit code for every failed declared test seat, even if earlier progress output obscured a silent failure. The guard's own fixture proves silent failure, progress then silent failure, named failure, and clean success.
