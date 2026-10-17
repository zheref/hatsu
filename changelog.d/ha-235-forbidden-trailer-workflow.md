### Enforce forbidden commit trailers at the required PR check ([#235](https://github.com/zheref/hatsu/issues/235), 0.110.0)

The required plugin-bump check now runs the trusted authorship guard over every PR commit, reading the forbidden keys from the trusted workflow configuration. It catches commits made outside Kokusen.
