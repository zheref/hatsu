# Model-family adoption on the released Nen pin

This change supplies Hatsu#538's canonical data and installer route: the five
`families.model` labels in `contracts/classify.taxonomy.json`, installed by
`nen classify install` beside the `lang/` and `job/` axes and never classified on.

Acceptance criterion 3 asked for a released Nen containing the install-only
`families` mechanism and a real Hatsu repin. Both hold: NN597 merged on
2026-11-02 (UTC) as `d070a1da` and first shipped in Nen `v0.30.0`, and
`nen/contract.json` pins `v0.30.0` (minimum `0.30`) since the 2026-11-05 repin.
This change adds no pin, version range, bootstrap digest or executable dependency.

Proofs with the released, pinned `nen 0.30.0` binary (2026-11-09):

- `nen classify labels --taxonomy contracts/classify.taxonomy.json` reports
  `49 label(s): 5 lang, 39 job, 5 model`.
- `nen classify install --json` against a scratch consumer whose
  `nen/labels.json` declares only `bug` lists all five `model/` labels as
  `absent`, to be written by `--write`. No GitHub labels were changed.

The model-data fixture and the existing matrix fixture tests pass with the
repository's pinned Vitest, and the generated mirrors match a fresh generation.

NN590 closes once this lands. A closing keyword cannot cross repositories, so
the maintainer closes NN590 after the merge.
