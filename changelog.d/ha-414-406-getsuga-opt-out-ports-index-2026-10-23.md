### Added

- `nen/workflow.json` → `release.proposalMerge` (`self` · `human`, default `self`): a repository can
  keep its release-proposal merge with the maintainer. `hatsu:getsuga` § 3a reads it at
  `origin/<branch.base>` and, on anything but `self`, runs no merge and stops at the declaration gate
  quoting the line it read (the opt-out Akatsuki's `CON-5` row 5 asks for). Catalogued as
  `workflow.release.proposalMerge`; `config_values.sh set` refuses a value outside the two.
  Addresses HA#414.
- `scripts/config_values.sh get --repo <path> --id <catalogue id> [--ref <git ref>] [--json]` prints
  one catalogued value's effective reading (declared, default, invalid, unset) at a ref or in the
  working tree; an unreadable file, ref or symlink is exit `2`, never a default. Fixture
  `scripts/config_values_get_fixture.ts` in lane `config-values-guard`.

### Fixed

- `templates/ports/INDEX.md` defines one row per directed pair file, the wording the rendered
  `handbooks/ports/INDEX.md` carries, so a fresh `hatsu:bankai-rule` render no longer puts the
  "pair that carries rulings" sentence back; bankai-rule § 4 says every pair file gets its row, at
  `0` rulings too, and `port-rule-guard` checks both. Addresses HA#406.
