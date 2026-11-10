### Added

- Declare the five canonical install-only model labels (`families.model` in `contracts/classify.taxonomy.json`) beside the two classification axes, and name `nen classify install` as their declaration route in `contracts/direct.registry.json` (zheref/hatsu#538). The mechanism first shipped in Nen v0.30.0, which Hatsu already pins; no pin changes and no GitHub label is mutated. `scripts/model_family_fixture.test.mts` runs in the `direct-matrix-guard` lane. Plugin 0.163.2, mirrors regenerated with the pinned nen v0.30.0.
