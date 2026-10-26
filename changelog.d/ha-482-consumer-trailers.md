### Added

- Tenkai renders a consumer `forbidden-commit-trailers` job that checks every PR commit against the exact base policy using a published, digest-verified Hatsu reader and trusted base publisher, which binds the check to the exact PR head and GitHub Actions producer. Consumer workflow-guard admission is checked before installation; adoption PRs and required-check rules remain per consumer, with required rules scoped to destination branches already carrying both the workflow and trusted publisher (HA#482).
