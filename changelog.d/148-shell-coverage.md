### Fixed

- Shell coverage now traces only the declared target for the plugin-update, surface-link, surface-bootstrap and prose guard fixtures, preserving their asserted output while recording exact-source LCOV with stale and partial-report refusal. Part of #148; other focused script lanes still have undeclared or unsupported line coverage.
