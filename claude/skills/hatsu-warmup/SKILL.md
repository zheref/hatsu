---
name: hatsu-warmup
description: Satisfy Hatsu's hard Nen dependency (D10) before any Nen-owned work — probe `nen --version` against the minimum declared in nen.contract.json, and when it is absent or below minimum, run nen's own checksum-verified bootstrap at the pinned ref. Fail-closed with auto-install. Use at the start of every Hatsu session, and again any time a `nen` invocation reports the binary is missing. It halts with the exact command ONLY if the bootstrap itself fails — and a Nen-owned operation is never improvised in prose.
---

# Hatsu warm-up — the Nen dependency contract, executed

**This skill is the contract, running.** `nen.contract.json` at the plugin root is the machine-readable
statement of D10; this file is the procedure that enforces it. Where the two disagree, the contract file
is the data and this file is wrong — fix this file.

Run this **first, every session**, before any work that touches a Nen verb. Run it again mid-session the
moment a `nen` invocation reports the binary is missing (a cache eviction, a `PATH` change, a different
shell).

**Nature: Transmuter.** Machinery. Kurapika says so when he runs it.

---

## 0 · Read the contract, never this file's memory

```bash
cat "$CLAUDE_PLUGIN_ROOT/nen.contract.json"
```

Take `dependency.minimum`, `dependency.pinned_ref`, `dependency.source` and `bootstrap.url` **from that
file**. Never hardcode a version in a reply, a command, or a commit — the contract file is bumped in one
place and every reader follows. A version you remember is a version that has already drifted.

---

## 1 · Probe

```bash
nen --version
```

Three outcomes, and exactly three:

| Outcome | Meaning | Next |
|---|---|---|
| Exits `0`, prints a semver satisfying `minimum` | Contract satisfied | **§4 — report and proceed** |
| Exits `0`, prints a semver **below** `minimum`, or a **different major** | Below minimum | **§2 — bootstrap** |
| Not found on `PATH` / non-zero exit / unparseable output | Absent | **§2 — bootstrap** |

**How `minimum` is compared.** `minimum` is `MAJOR.MINOR`. It is satisfied when the installed major
**equals** the minimum's major **and** the installed minor is **>=** the minimum's minor. Backward
compatibility holds *within* a major: `0.2.0` satisfies a `0.1` minimum, `0.1.7` satisfies it, `0.0.9`
does not, and `1.0.0` does **not** — a major bump is a break until the contract says otherwise.

**An unparseable version is an absent version.** Do not squint at it, do not assume it is new enough.
Fall through to §2, which is safe: the bootstrap is idempotent and cached.

---

## 2 · Bootstrap — auto-install, checksum-verified, fail-closed

Absent or below minimum is **not** a halt. It is an install. Fetch nen's own published bootstrap script
at the pinned ref and run it:

```bash
curl -fsSL "$(jq -r .bootstrap.url "$CLAUDE_PLUGIN_ROOT/nen.contract.json")" \
  | bash -s -- --ref "$(jq -r .dependency.pinned_ref "$CLAUDE_PLUGIN_ROOT/nen.contract.json")"
```

If `jq` is not available, read the two values out of the contract file yourself and substitute them
literally — but read them, do not recall them.

Three properties of that script this skill relies on, and must not re-implement:

- **Hatsu never vendors it.** The script lives in `zheref/nen` at `bootstrap/nen.sh` and is fetched at the
  pinned ref every time. A copy in this repo would be a second, unreviewed supply chain drifting from the
  manifest it verifies against.
- **It fails closed, always.** An unfetchable, missing, malformed or artifact-silent `SHA256SUMS` refuses;
  a missing `sha256sum`/`shasum`/`openssl` refuses; bytes that disagree are **deleted** and refused. It
  never warns-and-continues, and it never prints a path to a binary it did not verify.
- **On success it prints the verified binary path on stdout, and nothing else.** Execute exactly that
  path — or add its directory to `PATH` — and re-probe §1 to confirm.

### The exit codes are a contract, not a label

| Exit | Name | Meaning | Retry? |
|---|---|---|---|
| `0` | — | verified; the stdout path is safe to execute | — |
| `2` | `EXIT_USAGE` | the invocation is wrong; nothing was attempted | **No** |
| `3` | `EXIT_UNSUPPORTED_HOST` | this platform/arch ships no nen binary | **No** |
| `4` | `EXIT_DOWNLOAD` | the binary asset could not be retrieved | **Once** |
| `5` | `EXIT_CHECKSUM` | **SECURITY** — bytes did not verify, or could not be verified | **NEVER** |
| `6` | `EXIT_MANIFEST` | `SHA256SUMS` unfetchable, missing, malformed, or silent about the artifact | **NEVER** |

`4` is the transport failure and may be retried **once**. `5` and `6` are never retried: retrying a
checksum failure is exactly how a fail-closed guard becomes a fail-open one by attrition, and a manifest
that is absent, stripped or malformed does not become present by being asked again. `2` and `3` will not
change either.

---

## 3 · Halt — only when the bootstrap itself failed

**This is the only halt in this skill.** Not "nen was missing" — that was §2's job and §2 did it. Only a
non-zero exit *from the bootstrap* halts.

Print `halt.message_template` from the contract, with the code and its meaning filled in:

> Nen is unavailable and the checksum-verified bootstrap failed (exit `5` — EXIT_CHECKSUM: bytes did not
> verify, or could not be verified). This operation is Nen-owned and will not be improvised. Run this
> yourself, then re-invoke:
>
> ```
> curl -fsSL https://raw.githubusercontent.com/zheref/nen/v0.1.0/bootstrap/nen.sh | bash -s -- --ref v0.1.0
> ```

Then **stop**. Report the halt to the maintainer as a **G5** — a human-only action, since a checksum or
manifest failure is a supply-chain event they need to see, and an unsupported host is a machine fact only
they can change.

**What stopping means, precisely.** The Nen-owned operation **does not happen**. Not with raw `gh`, not
with a shell equivalent assembled on the spot, not "approximately, from what the verb usually returns",
not by reading the numbers off a previous transcript. There is **no LLM-improvised fallback for a
Nen-owned operation, ever** — that is D10, and it is the whole reason the dependency is hard rather than
soft. A report that the operation could not be performed is the *correct* outcome. A plausible-looking
answer produced another way is the failure this rule exists to prevent, and it is worse than no answer
because it cannot be told apart from a real one.

A Nen-owned operation is any operation a `nen` verb covers — readiness, backlog fetch and ordering, board
assembly and render, gate derivation, label application, changelog collation and completeness, fan-out
computation, method-block validation, perf comparison, and the rest of `nen --help`.

---

## 4 · Report, in one line

State the outcome before doing anything else, so the maintainer knows which of the four happened:

- `Nen 0.1.0 · contract 0.1 satisfied · warm-up clear`
- `Nen absent · bootstrapped to v0.1.0 (checksum verified) · warm-up clear`
- `Nen 0.0.9 below minimum 0.1 · bootstrapped to v0.1.0 (checksum verified) · warm-up clear`
- `Nen unavailable · bootstrap failed (exit 6, EXIT_MANIFEST) · HALTED — G5`

**Silence is not one of the four.** A warm-up that did not run is reported as *not run*, never rendered as
clear — the same discipline `nen warmup`'s own `--questions-from` omission follows, where a skipped sweep
reports `{"checked": false}` rather than an empty finding set.

---

## What this skill is not

It is **not** `nen warmup`. That verb is a different thing entirely: it detects stale pins across a target
repository's `schemas/repos.json` (default pins *and* per-caller overrides) and optionally sweeps handbook
questions. It presupposes a working `nen` — it cannot run when `nen` is the thing that is missing, which
is precisely the case this skill exists to handle.

The two compose, in order: **this skill first** (is there a `nen` at all, at a version the contract
accepts), **then** `nen warmup --current <vX.Y.Z>` against the target repository (is that repository's
policy inbox clear). Kurapika runs both at session start; see `claude/agents/kurapika.md` § Session
warm-up.
