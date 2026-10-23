### Added

- `nen/workflow.json` → `release.proposalMerge` (`self` · `human`, default `self`): a repository can
  keep its release-proposal merge with the maintainer. `hatsu:getsuga` § 3a reads it at the
  merge-time re-check's `<baseNow>` SHA and, on anything but `self`, runs no merge and stops at the declaration gate
  quoting the line it read (the opt-out Akatsuki's `CON-5` row 5 asks for). Catalogued as
  `workflow.release.proposalMerge`; `config_values.sh set` refuses a value outside the two.
  Addresses HA#414.
- `scripts/config_values.sh get --repo <path> --id <catalogue id> [--ref <git ref>] [--json]` prints
  one catalogued value's effective reading (declared, default, invalid, unset) at a ref or in the
  working tree; a parent key that is not an object is `invalid` (exit `1`), and an unreadable file
  or ref, or a symlink or submodule anywhere on the file's path, is exit `2`, never a default. Fixture
  `scripts/config_values_get_fixture.ts` in lane `config-values-guard`.

### Fixed

- `templates/ports/INDEX.md` defines one row per directed pair file, the wording the rendered
  `handbooks/ports/INDEX.md` carries, so a fresh `hatsu:bankai-rule` render no longer puts the
  "pair that carries rulings" sentence back; bankai-rule § 4 says every pair file gets its row, at
  `0` rulings too. `port-rule-guard` holds the template wording (T16) and, in its own fixture, that a
  render over a `0`-rulings pair file indexes every pair file once (T15b, with a red case); the
  reserve guard itself still never compares INDEX rows to files. Addresses HA#406.
