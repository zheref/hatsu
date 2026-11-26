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

## Dated verification, 2026-11-26 — a live kazaana killed mid-run and re-invoked (zheref/hatsu#444)

Fixture, method and comparison reads: `docs/ab/build.md` § *Dated verification, 2026-11-26*. `hatsu:kazaana SB`
ran twice; its queue was SB#6 alone (SB#1–SB#5 each already had an open PR from the runs above, and were left).

| Kill | Boundary (UTC) | What the next session did |
|---|---|---|
| 1 | SB#6's `kotoamatsukami` and `byakugan` ended (14:50:03), branch pushed, no PR | resumed run `0c5da071…` (0 PRs), opened SB-PR-#13, `nen run append`, held `then getsuga` at § 5 (1 open, 0 merged) |

Published: 1 PR, 0 labels, **0 slice comments** — the resumed session skipped step 8a, reporting that nen
`0.31.0` has no `ledger` verb, which is false (`nen pr --help` lists `nen pr ledger post`). That is the session's
error, not the skill's text. `nen pr ready`: SB-PR-#13 `ready` at
`b859cdddc3bd6c3a59755a9019f17d6ca70267b2`.

**Verdict: PARTIAL.** AC-2 holds (no second PR, no label). The ledger has the same gap as futon's (only the two
self-recording steps), addressed (not re-proved live) by this PR's kazaana § 3 line. Usage: 1 entry for two
sessions, so HA#444/AS-2's separate entry is not met. getsuga, the chain's second half, did not start:
no delivery was merged; see `docs/ab/getsuga.md` for its own live attempt.
