### Fixed

- Tenkai readiness workflows render the pinned bootstrap script and Linux binary digests from the dependency contract, then verify each artifact before executing it. Trusted consumer pins require their own matching digests; opt-in fallback carries the ref and digests together, and `readiness_checksum_fixture.test.mts` runs with `tenkai-guard` and `test:unit`. Completes the Hatsu renderer side of zheref/nen#407 item 8.
