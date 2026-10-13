### Changed

- Every self-hosted runner pool now requires its own `pool-<id>` label in the workflow policy and readiness rendering ([#204](https://github.com/zheref/hatsu/issues/204)). Tenkai derives a single declared pool, asks for an explicit choice when several are declared, and refuses GitHub's default labels alone. The runner preflight fixture proves that a defaults-only rendering fails. Jusshin names `nen runner relabel` for existing runners and retires the same-architecture desktop overlap question.
- The existing `zheref/nen` `windows-x64` pool (NZ-NNR1..3) and `zheref/KroWindows` `windows-x64` pool (NZ-KWIR1..5) still need their declarations, registered runner labels, preflight workflows, and readiness workflows migrated before their jobs are enabled. This Hatsu change does not alter either consumer.
- Plugin bumped to 0.108.0; generated surfaces restamped.
