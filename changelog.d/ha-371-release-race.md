### Fixed

- Getsuga § 4 records the maintainer's reviewed-head cut when a later delivery races the release
  proposal's merge, requires the full preflight at the selected immutable SHA, and reports the
  commits and PRs left for the next release. HA-IS-#371 is partial: automatic selection remains at
  G5 until [NN-IS-#572](https://github.com/zheref/nen/issues/572) supplies a public mechanical
  release-state comparison; no shell substitute or new Nen verb is claimed.
