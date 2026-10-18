### Changed

- **#289 step two** ([#289](https://github.com/zheref/hatsu/issues/289); `docs/ROSTER.md` § *Rulings of 2026-10-17*). The workflow validator admits the *Surface-mirror drift check* step only in its frozen form (`DRIFT_STEP_FROZEN` flipped), and opens item 3's own two-step landing: `require_frozen_step` takes a list of admitted forms, and the digest step's next form — the closing `--version` echo made fatal — is admitted beside the current one in all three guard workflows; the workflows flip in the next PR. Plugin bumped to 0.111.6 (the validator changed); the mirrors restamped.
