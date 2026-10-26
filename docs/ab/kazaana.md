# A/B evidence — `kazaana`

## Dated verification, 2026-10-23 — crash-and-resume (zheref/hatsu#444)

Kazaana composes `futon` and writes no ledger of its own, so its resume state is futon's: nen's run manifest,
proved idempotent across an interruption in `docs/ab/futon.md` (2026-10-23):

```text
converged futon (and kazaana)  killed after a park, re-invoked      re-start existing, re-park unchanged, manifest bytes unchanged
```

Its later steps (`getsuga`, `mugetsu`) are each their own composite; see their files. **Finding:** kazaana
records no phase of its own, so a crash between its futon run and its release step leaves only GitHub state and
the manifest to resume from; whether that is enough is unproved. **Not proved here:** a live kazaana killed and
re-invoked.
