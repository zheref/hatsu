### Changed

- **#234 direct matrix check** ([#234](https://github.com/zheref/hatsu/issues/234)). `surface-mirror-check` now runs the trusted TypeScript matrix adapter against every PR checkout, so data-only registry, taxonomy and model changes fail on a stale `docs/DIRECT-MATRIX.md`. Nen repin PRs must run `--verify` at the new pin and quote its agreement line. Plugin bumped to 0.114.7 and the three surface mirrors restamped.
