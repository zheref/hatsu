# A/B evidence — `kage-bunshin`

## Dated verification, 2026-10-31 — the kage-bunshin parse grammar (zheref/hatsu#536)

Run at nen 0.28.0 (the pin) from a Hatsu checkout, `nen parse kage-bunshin --grammar "<urls>{ } --<mode:sequential|parallel> [--cap <cap>]"`:

```text
--line "<url1> <url2> --sequential"                 urls: <url1> <url2> · mode: sequential · cap: (clause absent)   exit 0
--line "<url1> <url2> <url3> --parallel --cap 3"    urls: one value, no items · mode: parallel · cap: 3            exit 0
--line "<url1> --parallel --cap 9"                  cap: 9 — the grammar reads any number; the skill holds 7         exit 0
--line "<url1>"                                     <mode> is required; corrected line "kage-bunshin <url1>--<mode: …>"  exit 2
--line "<url1> --fast"                              <mode> is one of sequential | parallel; 'fast' is none            exit 2
--line='--sequential'                               <urls> is required                                                 exit 2
```

where `<url1>` is `https://github.com/zheref/hatsu/issues/470`, `<url2>` `https://github.com/zheref/nen/issues/300`
and `<url3>` `https://github.com/fixture-owner/fixture-web/issues/4` (a fictional slug from docs/PUBLIC-REDACTION.md standing in for the private repository the run typed; the refusal is the same for any unregistered slug). The three refusals are the trigger to ask (row
`missing-argument`). Two findings went to nen as one issue (zheref/nen#593): the space-joined list slot
returns one value with no `items` where the comma-joined `<urls>{,}` form returns them, and the corrected
line splices the mode placeholder onto the last URL with no space. Until it ships, kage-bunshin § 1 splits
the value on whitespace itself and names that as residue.

`nen repo resolve` at 0.28.0 takes a product code, an `owner/name` slug or a short name, never a URL:
`nen repo resolve https://github.com/zheref/nen/issues/300 --repo <hatsu>` is the registry refusal listing
the codes, while `nen repo resolve zheref/nen --repo <hatsu>` answers `zheref/nen (NN) via slug`. A URL whose
repository the registry does not carry (`fixture-owner/fixture-web` here) is the same refusal, which kage-bunshin § 1 reads
as a row blocked at the start.

**Not proved here:** a live run of the skill, sequential or parallel; the skill shipped as prose with no
run of its own, and its first dated run belongs in this file.
