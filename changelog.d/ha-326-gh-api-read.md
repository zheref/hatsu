### Fixed

- **#326 Read-only GitHub API access** ([#326](https://github.com/zheref/hatsu/issues/326)). Claude Code's permission pack now grants a named TypeScript reader for audited REST GETs and a fixed GraphQL query. The reader rejects caller-supplied methods, endpoints, bodies, and mutation text before invoking `gh`. Installing the pack removes the retired `gh api *` allow rule from older local settings while preserving unrelated entries. Local trusted-guard preflight also runs the newly required private-name fixture.
