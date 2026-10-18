### Changed

- **#289 step three** ([#289](https://github.com/zheref/hatsu/issues/289); `docs/ROSTER.md` § *Rulings of 2026-10-17*). The three guard workflows' digest steps make the closing `nen --version` echo fatal, so a binary that matches its sha256 but cannot run fails the step; the validator's frozen digest form is that body alone and the old echo is refused as a shape change. Plugin bumped to 0.111.7 (three workflows and the validator changed); the mirrors restamped.
