### Fixed

- `hatsu:dowsing-chain` and its conventions page (`docs/config/spec-repo.md`) now read the pinned nen `v0.28.0`: every `nen spec` verb and `nen run record` ship at the pin, so no passage calls one owed or due in a later release, and the conventions page's verb table carries each verb's usage line as nen `v0.28.0`'s `docs/USAGE.md` § *Family spec* prints it.
- Clarification follows HR-351: one run asks up to `spec.clarify.maxRounds` rounds of at most `spec.clarify.maxQuestions` each, and `maxRounds` bounds that run, never successive runs (skill § 5, row `spec-clarify`, the keys table).
- Dispatch follows HR-344: no per-dispatch G1, the typed dispatch wave is the go (skill § 8, row `spec-dispatch`); the conventions page lists only the `wave` and `spec.autonomy.*` design as unruled. Closes #504.
