# Model-family adoption is held for a containing Nen release

This proposal supplies Hatsu#538's canonical data and installer route. It is
not ready to merge: acceptance criterion 3 requires an actually released Nen
version containing the install-only `families` mechanism, followed by the real
Hatsu dependency repin.

On 2026-11-03 (America/Bogota), Hatsu declares `v0.28.0`; the newest published Nen
release is `v0.29.0` (2026-10-29). NN597's mechanism merged on 2026-10-31 as
`d070a1da`, after that release. No published containing release was found.
No pin, version range, bootstrap digest or executable dependency is changed
here. Never substitute a guessed future tag or a source build for the release
and pin criterion.

The current Nen source at `65613133` was used only for bounded compatibility
proofs: `classify labels` reports 49 labels (5 lang, 39 job, 5 model), and
`classify install --dry-run --json` reports all 49 present, zero foreign labels,
`written: null`, `sync: null`. No GitHub labels were changed. The three exact
model-data tests and the existing three matrix fixture tests pass using the
repository's pinned Vitest 5.0.5. Canonical mirror regeneration/check also pass.

Before converting the draft to a merge candidate:

1. Publish and verify a Nen release containing NN597 through the release owner's
   normal process; that release is external to this proposal.
2. Repin Hatsu with the actual release and its verified bootstrap/binary hashes,
   preserving the dependency contract's existing requirements.
3. Run the label listing and installer dry run with that released, pinned binary.
4. Refresh the candidate plugin patch version and generated mirrors against the
   then-current main, then rerun focused guards. Another proposal may consume the
   current candidate patch number before this held adoption lands.

NN590 remains open until this ordering is satisfied and Hatsu#538 lands.
