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

### Changed

- **Handbook canon repinned from `zheref/bankai-handbooks` `v0.11.0` to `v0.12.0`** (commit
  `5f0b2f4b`, recorded as `pinnedSha` by hand until zheref/nen#506), so Akatsuki's pin can equal
  Hatsu's (HR-8). The always-load set, the spec handbook and the pair files are unchanged; the
  `react-uzf-v1` Electron desktop shell (`RC-64`–`RC-69`) and its `QA-7`/`QA-12` rows are new, and
  `hatsu:bankai-quality`'s tooling table carries the desktop row. History in
  `docs/ab/bankai-handbooks.md` § *Repin to v0.12.0*.
- **Pair files are shipped, never created** (`CON-13` as amended, zheref/bankai-handbooks#21): the
  INDEX template's lead matches that PR's `handbooks/ports/INDEX.md` byte for byte;
  `port_rule_reserve.sh --handbooks-tag <pin>` refuses a pair file missing at the tip at a tag at or
  above `v0.11.0` (exit `2`, naming the pair and the tag); `hatsu:bankai-rule` appends rows only and
  its receipt drops `created`; `hatsu:bankai-handbooks` reads an absent pair file at such a pin as
  that refusal, no longer `port rulings: none`. Fixture T17.
