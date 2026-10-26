### Fixed

- `scripts/pr_body_delivery_check.sh` now reads its expectation with `nen report data … --effort <current branch>`, the shape `hatsu:shibari` § 3 renders the Delivery block with. The ledgers are the repository's, shared by every worktree, and a row's index is its position in what nen returns, so the guard's global read numbered rows across every effort and refused a body rendered per effort ("missing ledger row" / "extra or duplicate body row", HA-PR-#490). The guard moved rather than the skill because the block is the effort's (WORKFLOW § *The effort's ledgers*) and `scripts/pr_delivery.ts` already refuses to guess an effort; a detached HEAD is now refused at exit `2` before nen is asked. shibari § 3–4 say the guard reads with the same `--effort <branch>`. Closes #492.
- `hatsu:shibari` § 4 and `hatsu:en` § 5 pass `--catalogue` to `nen pr converge`, where nen 0.28 names `--requirements-from` a deprecated alias; `body-check`, `next-blocker` and `merge` keep `--requirements-from`.

### Added

- The pr-delivery-guard fixture's per-effort case: real `nen phase begin` rows for a sibling effort and the current branch, the block rendered by shibari § 3's exact commands passes the guard, and a block rendered without `--effort` is refused.
