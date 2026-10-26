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

## Dated verification, 2026-10-26 — the kazaana parse grammar (zheref/hatsu#481)

Run at nen 0.28.0 (the pin) from a Hatsu checkout, `nen parse kazaana --grammar "<repo> [on <line:claude|gpt|gemini|grok|composer>]"`:

```text
--line "zheref/hatsu"            repo: zheref/hatsu · line: (clause absent)      exit 0
--line "zheref/hatsu on llama"   the usage line (an undeclared line value)        exit 2
--line ""                        the usage line (no repository)                   exit 2
```

The bare repository parses with the line clause absent, which kazaana § 1 reads from the registry; the two refusals
are the trigger to ask (row `missing-argument`). This record replaces the transcript kazaana § 1 carried until
the ha-481 effort trimmed it for the prose ceiling.
