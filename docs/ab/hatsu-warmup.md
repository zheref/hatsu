# A/B — `hatsu:hatsu-warmup`

Evidence for the warm-up skill: what the pinned binary and its bootstrap actually do, recorded from
live runs rather than from the contract's prose. The contract itself
([`nen/contract.json`](../../nen/contract.json)) stays the single source of truth for the pin; this
file records what was observed when the pin moved.

## Retired at nen 0.7 — 2026-09-10

Run against the released `zheref/nen` `v0.7.0` binary (`nen-darwin-arm64`, sha256
`a0545d02f1299a6b2aa4e409fcf5aa3ec27a546715a7a310563b1995e7b6c323`), fetched and checksum-verified by
`bootstrap/nen.sh --ref v0.7.0` and symlinked as `nen` first on `PATH` in a scratch directory.
**`~/.local/bin` was not touched**, so the machine's own `nen` stayed at `0.6.0` and both columns
below are real runs rather than one binary described twice.

| Residue retired | Where | Exit |
|---|---|---|
| discovering the bootstrap's exit `7` empirically | `nen bootstrap --help` | `0`, whole table printed |
| a cache path assembled from the ref alone | `bootstrap/nen.sh --ref v0.7.0` | `0`, `<root>/<source>/<ref>/` |
| `--source a/..` neutralised downstream instead of refused | `nen bootstrap --source "a/.."` | **`2`**, refused at the flag |

### The exit-code contract is published by the verb

```text
v0.6.0  $ nen bootstrap --help
          --ref <tag>              The tag to pin to. Required -- no default.
          --source <owner/name>    GitHub repository to fetch release assets from.
          --cache-dir <dir>        Cache root.
          --script <path>          The bootstrap script, when not under --repo.
          --repo <path>            The target repository's working-tree root.
                                                  # ← not one exit code named, anywhere

0.7.0   $ nen bootstrap --help
        …
        Exit codes are a PUBLISHED CONTRACT -- this command relays the script's own,
        and adds exactly one of its own on top (zheref/nen#58). A caller branching on
        them does not have to discover any of these empirically:

          0  the path on stdout is a verified binary.
          2  usage: a flag is missing or malformed. Nothing was attempted.
          3  unsupported host: no binary is published for this OS/arch.
          4  the binary could not be DOWNLOADED. The only retryable one.
          5  SECURITY: the bytes did not verify, or could not be. Never retry --
             a mismatching binary does not become trustworthy by being asked for again.
          6  the SHA256SUMS manifest was unfetchable, missing, malformed, or silent
             about this artifact. Never retry, for the same reason.
          7  THIS WRAPPER could not run the script at all -- no 'bash' on PATH, or no
             'bootstrap/nen.sh' under --repo and none named by --script. It is the one
             code the script itself can never return, which is why it is 7 rather than
             1: "the bootstrap failed" and "the bootstrap never ran" are different
             facts, and only the first says anything about the release you asked for.
```

`7` was the singular outlier among refusals that otherwise use `1` or `2`, and a caller scripting
around the verb had to find it by experiment. **SKILL.md § 2's table stays** — it is the *reaction*
table, and `nen/contract.json` remains the authority on the pin — but it is now a copy of something
the binary publishes, so a drift between them is resolvable by re-reading `--help`.

### The cache slot is keyed on the source as well as the ref

```text
$ BIN=$(bash /…/nen-bootstrap-0.7.sh --ref v0.7.0)
nen bootstrap: fetching nen-darwin-arm64 from zheref/nen release v0.7.0…
nen bootstrap: verified nen-darwin-arm64 for zheref/nen@v0.7.0 (sha256 a0545d02f1299a6b2aa4e409fcf5aa3ec27a546715a7a310563b1995e7b6c323).
$ echo "$BIN"
/Users/<you>/.cache/nen/zheref_nen/v0.7.0/nen-darwin-arm64

$ ls ~/.cache/nen/
v0.3.0   v0.5.0   v0.6.0   zheref_nen        # ← earlier refs still at the flat layout they were written under
```

`<cache-root>/<source>/<ref>/<artifact>`, each key flattened to exactly one path segment by the same
sanitiser. Keyed on the ref alone, two `--source` values at one tag collided in one slot; the
checksum gate meant the collision was **detected rather than executed** — a mismatch is a refusal,
not a wrong binary — so it never cost correctness. It cost a fork or a mirror a permanent cache miss
and a confusing refusal about bytes that were fine. **The operational rule: quote the path the
bootstrap printed; never assemble one from the ref.**

Re-running through the verb, against the now-warm cache:

```text
$ nen bootstrap --ref v0.7.0 --source zheref/nen --script /…/nen-bootstrap-0.7.sh          # exit 0
nen bootstrap: cache hit for zheref/nen@v0.7.0 (nen-darwin-arm64), checksum verified.
/Users/<you>/.cache/nen/zheref_nen/v0.7.0/nen-darwin-arm64
```

A cache hit is **re-verified**, not trusted for having been verified once.

### `--source` is shape-checked at the flag

```text
$ nen bootstrap --ref v0.7.0 --source "a/.." --script /…/nen-bootstrap-0.7.sh              # exit 2
nen bootstrap: --source takes a GitHub 'owner/name' (got 'a/..') — neither half may be empty, '.' or
'..'. It is NOT a filesystem path — 'nen --repo <path>' is the flag that takes one.
```

The leading-dot arm used to examine only the first character, so a traversal segment to the right of
the slash walked through and was neutralised two hundred lines downstream by the cache sanitiser —
which is a second layer, not a shape check. Both halves are examined now, and GitHub accepts none of
those as an owner or a repository name, so nothing legitimate is refused.

### The gates, on this branch, at this pin

```text
$ nen --version                                          0.7.0
$ nen shu tools --repo .                                # exit 0
  ok       nen     0.7.0    pinned >=0.7.0 <0.8.0
  ok       claude  2.1.263  pinned >=2.0.0
$ nen schema check --repo .                             # exit 1 — the expected shape
  ok    nen/contract.json  dependency (nen >= 0.7, pinned v0.7.0), project (1 lane: plugin; 10 verbs; 1 toolchain entry)
  ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}' off 'main', checks: lint
```

**`schema check`'s exit `1` is neither new nor a regression**: Hatsu ships no taxonomy, so
`nen/labels.json`, `nen/repos.json` and `nen/colors.yml` `FAIL` and `nen/gates.json` `warn`s, exactly
as at every pin since `v0.5.0`. The two rows the warm-up reads are `ok`, and the contract row prints
the floor and the pin this file's own `$comment` quotes.
