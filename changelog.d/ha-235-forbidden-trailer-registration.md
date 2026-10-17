### Register forbidden commit trailer guard ahead of its required check ([#235](https://github.com/zheref/hatsu/issues/235), 0.109.0)

The authorship guard can read `commits.forbiddenTrailers` from trusted configuration and inspect every PR commit. The workflow policy admits the upcoming required-check step while retaining the current shape during the two-step landing.
