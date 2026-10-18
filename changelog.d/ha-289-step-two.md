### Changed

- **#289 step two** ([#289](https://github.com/zheref/hatsu/issues/289); `docs/ROSTER.md` § *Rulings of 2026-10-17*). The three guard workflows' digest steps make the closing `nen --version` echo fatal, so a binary that matches its sha256 but cannot run fails the step; the validator's frozen digest form is that body alone and the old echo is refused as a shape change in each workflow. Plugin bumped to 0.112.1 (three workflows and the validator changed); the mirrors restamped.
