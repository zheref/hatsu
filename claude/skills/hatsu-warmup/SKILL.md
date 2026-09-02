---
name: hatsu-warmup
description: Satisfy Hatsu's hard Nen dependency (D10) before any Nen-owned work — probe `nen --version` against the range declared in nen.contract.json, and when it is absent or out of range, install the pinned build through nen's own checksum-verified bootstrap. Fail-closed with auto-install. Use at the start of every Hatsu session, and again any time a `nen` invocation reports the binary is missing. It halts with the exact command ONLY if the bootstrap itself fails — and a Nen-owned operation is never improvised in prose.
---

# Hatsu warm-up — the Nen dependency contract, executed

**`nen.contract.json` at the plugin root is the single source of truth.** This file is the procedure that
enforces it. Every version, ref, URL and command below is a **convenience copy** of a value that lives
there; where a copy disagrees with the contract, **the contract wins and the copy is the bug** — fix this
file.

Run this **first, every session**, before any work that touches a Nen verb. Run it again mid-session the
moment a `nen` invocation reports the binary is missing (a cache eviction, a `PATH` change, a different
shell).

**Nature: Transmuter.** Machinery. Kurapika says so when he runs it.

---

## 0 · Read the contract yourself — no jq, no subprocess

```bash
cat "$CLAUDE_PLUGIN_ROOT/nen.contract.json"
```

**You are the JSON parser.** You have just opened the file; read `dependency.minimum`,
`dependency.zero_major_caveat`, `dependency.pinned_ref`, `dependency.source`, `bootstrap.url` and
`install_paths` straight off the page, and substitute the **literal values** into the plain `curl` / `bash` /
`nen` commands below.

**Do not shell out to `jq`, `yq` or `python` to do this.** The ratified plan retires jq/yq as a DX friction —
a machine needs one binary plus `git` and `gh` — and spawning a JSON parser to hand values back to the
entity that just read the file buys a dependency for nothing, on the one code path that has to work on a
machine where nothing is installed yet.

Never hardcode a version in a reply or a commit from memory. A version you remember is a version that has
already drifted.

---

## 1 · Probe

```bash
nen --version
```

Three outcomes, and exactly three:

| Outcome | Meaning | Next |
|---|---|---|
| Exits `0`, prints a semver **inside** the range | Contract satisfied | **§4 — report and proceed** |
| Exits `0`, prints a semver **outside** the range | Out of range, but nen works | **§2b — re-pin through the verb** |
| Not found on `PATH` / non-zero exit / unparseable output | Absent | **§2a — the shell bootstrap** |

### How the range is computed — and the 0.x trap

`minimum` is `MAJOR.MINOR`. **What it means depends on the major, and getting this backwards fails open.**

**While nen's line is `0.x` — which it is today — `minimum: "0.1"` means exactly `>=0.1.0 <0.2.0`.**

**A different minor is out of range in BOTH directions.** `0.2.0` fails it exactly as `0.0.9` does.

> **Why, so nobody "corrects" it back:** SemVer 2.0.0 clause 4 says that at major version zero the public
> API is unstable and **anything MAY change at any time** — at `0.x` the **minor** is the breaking-change
> vehicle, the role `major` plays later. So "backward-compatible within a major" is precisely the wrong rule
> here: applied at `0.x` it would wave through `0.9.0` against a `0.1` minimum, in the one version range
> where compatibility is *least* guaranteed. A higher `0.x` is **not** safer for being higher. Re-pin it.

**From `1.0` onward** the familiar rule takes over: `X.Y` means `>=X.Y.0 <(X+1).0.0`, and a higher minor or
patch satisfies it. The contract is bumped to say so when nen gets there; **until then the `0.x` rule above
is the operative one**, and it is stated in `dependency.zero_major_caveat` rather than left to be inferred.

**An unparseable version is an absent version.** Do not squint at it. Fall through to §2a, which is safe:
the bootstrap is idempotent and cached.

---

## 2 · Auto-install — two cases, two paths

Absent or out of range is **not** a halt. It is an install. **Which path applies is decided by the probe,
never by preference.**

Both start with the same fetch, and **it is always two steps**:

```bash
curl -fsSL https://raw.githubusercontent.com/zheref/nen/v0.1.0/bootstrap/nen.sh -o /tmp/nen-bootstrap.sh
```

> ### ⚠️ Fetch to a file. **Never pipe the script into bash.**
>
> ```bash
> # WRONG — dies before it starts:
> curl -fsSL <url> | bash -s -- --ref v0.1.0
> ```
>
> The script runs under `set -u` and reads `${BASH_SOURCE[0]}`. Piped into `bash -s --` there is no
> `BASH_SOURCE`, so it fails with `BASH_SOURCE[0]: unbound variable` and **exits 1 — a code that appears in
> no table in this file**, from a script that never reached its own argument parsing. It reads like an
> ordinary failure and is not one: it means the *invocation form* was wrong, and retrying or halting on it
> would both be the wrong response. Reproduced against the pinned ref.

### 2a · nen is **absent** → run the shell bootstrap directly

```bash
bash /tmp/nen-bootstrap.sh --ref v0.1.0
```

**Why shell is permitted here, and only here.** Chicken-and-egg: `nen bootstrap` is a `nen` subcommand, so
invoking it presupposes the binary that is precisely what is missing. The script exists because a bootstrap
written in the language its own output provides cannot run before that output exists. **This is the sole
carve-out and it does not generalize** — no other operation on any Hatsu path may reach for shell on the
grounds that this one does.

### 2b · nen is **present but out of range** → re-pin through nen's own verb

```bash
nen bootstrap --ref v0.1.0 --source zheref/nen --script /tmp/nen-bootstrap.sh
```

A working `nen` is on `PATH`, so the chicken-and-egg rationale does not apply and the shell path is **not**
the one to reach for. The verb is the Nen-first rule applied to Hatsu's own bootstrap.

**`--script` is required, and the verb's name misleads about this.** `nen bootstrap` does **not** fetch the
script — it *runs* the checksum bootstrap rather than reimplementing it, so it needs `bootstrap/nen.sh`
**on disk**: from a checkout carrying it (`--repo`), or named with `--script` / `$NEN_BOOTSTRAP_SH`. A Hatsu
user has no nen checkout, so `--script` pointed at the file you just fetched is the form that works.
**Without it the verb exits `7`** with a message saying exactly this. That is deliberate on nen's part: a
compiled binary has no sibling `bootstrap/` directory, and guessing one is how a path that does not exist
becomes a silent failure.

The verb **propagates the script's exit codes unchanged** — a forced failure through it returns `6`,
verified — plus its own `7`.

### What both paths guarantee, and must not re-implement

- **Hatsu never vendors the script.** It lives in `zheref/nen` at `bootstrap/nen.sh` and is fetched at the
  pinned ref every time. A copy in this repo would be a second, unreviewed supply chain drifting from the
  manifest it verifies against.
- **It fails closed, always.** An unfetchable, missing, malformed or artifact-silent `SHA256SUMS` refuses; a
  missing `sha256sum`/`shasum`/`openssl` refuses; bytes that disagree are **deleted** and refused. Never
  warn-and-continue, and never a path to a binary it did not verify.
- **On success it prints the verified binary path on stdout, and nothing else.** Execute exactly that path —
  or put its directory on `PATH` — and re-probe §1 to confirm.

### The exit codes are a contract, not a label

| Exit | Name | Meaning | Retry? |
|---|---|---|---|
| `0` | — | verified; the stdout path is safe to execute | — |
| `2` | `EXIT_USAGE` | the invocation is wrong; nothing was attempted | **No** |
| `3` | `EXIT_UNSUPPORTED_HOST` | this platform/arch ships no nen binary | **No** |
| `4` | `EXIT_DOWNLOAD` | the binary asset could not be retrieved | **Once** |
| `5` | `EXIT_CHECKSUM` | **SECURITY** — bytes did not verify, or could not be verified | **NEVER** |
| `6` | `EXIT_MANIFEST` | `SHA256SUMS` unfetchable, missing, malformed, or silent about the artifact | **NEVER** |
| `7` | *(the verb's own)* | no `bootstrap/nen.sh` on disk — a wiring failure, not a supply-chain one. Supply `--script` | **No** — fix the invocation |
| `1` | *(not ours)* | you piped the script into bash. Not a failure to report — a form to fix. See §2 | **No** — re-run the two-step form |

`4` is the transport failure and may be retried **once**. `5` and `6` are never retried: retrying a checksum
failure is exactly how a fail-closed guard becomes a fail-open one by attrition, and a manifest that is
absent, stripped or malformed does not become present by being asked again. `3` will not change on this host
at all. `2` and `7` are invocation errors — re-running the **same** command is pointless, but the **fixed**
command (correct usage; for `7`, `--script <fetched file>` supplied) is expected to succeed: fix and re-run,
never halt on them as if they were bootstrap failures.

---

## 3 · Halt — only when the bootstrap itself failed

**This is the only halt in this skill.** Not "nen was missing" — that was §2's job and §2 did it. Only a
non-zero exit *from the bootstrap* halts, and `1` and `7` are not that: they are your invocation to fix.

Print `halt.message_template` from the contract, with the code and its meaning filled in:

> Nen is unavailable and the checksum-verified bootstrap failed (exit `5` — EXIT_CHECKSUM: bytes did not
> verify, or could not be verified). This operation is Nen-owned and will not be improvised. Run this
> yourself, then re-invoke:
>
> ```
> curl -fsSL https://raw.githubusercontent.com/zheref/nen/v0.1.0/bootstrap/nen.sh -o /tmp/nen-bootstrap.sh
> bash /tmp/nen-bootstrap.sh --ref v0.1.0
> ```
>
> Two steps, never a pipe: the script reads `${BASH_SOURCE[0]}` under `set -u`, so `curl … | bash` dies
> before it starts.

Then **stop**. Report the halt as a **G5** — a checksum or manifest failure is a supply-chain event the
maintainer needs to see, and an unsupported host is a machine fact only they can change.

**What stopping means, precisely.** The Nen-owned operation **does not happen**. Not with raw `gh`, not with
a shell equivalent assembled on the spot, not "approximately, from what the verb usually returns", not by
reading the numbers off a previous transcript. There is **no LLM-improvised fallback for a Nen-owned
operation, ever** — that is D10, and it is the whole reason the dependency is hard rather than soft. A report
that the operation could not be performed is the *correct* outcome. A plausible-looking answer produced
another way is the failure this rule exists to prevent, and it is worse than no answer because it cannot be
told apart from a real one.

A Nen-owned operation is any operation a `nen` verb covers — readiness, backlog fetch and ordering, board
assembly and render, gate derivation, label application, changelog collation and completeness, fan-out
computation, method-block validation, perf comparison, and the rest of `nen --help`.

---

## 4 · Report, in one line

State the outcome before doing anything else, so the maintainer knows which of the four happened:

- `Nen 0.1.0 · in range (>=0.1.0 <0.2.0) · warm-up clear`
- `Nen absent · bootstrapped to v0.1.0 (checksum verified) · warm-up clear`
- `Nen 0.0.9 out of range (>=0.1.0 <0.2.0) · re-pinned to v0.1.0 via nen bootstrap (checksum verified) · warm-up clear`
- `Nen unavailable · bootstrap failed (exit 6, EXIT_MANIFEST) · HALTED — G5`

**Silence is not one of the four.** A warm-up that did not run is reported as *not run*, never rendered as
clear — the same discipline `nen warmup`'s own `--questions-from` omission follows, where a skipped sweep
reports `{"checked": false}` rather than an empty finding set.

---

## What this skill is not

It is **not** `nen warmup`. That verb is a different thing entirely: it detects stale pins across a target
repository's `schemas/repos.json` (default pins *and* per-caller overrides) and optionally sweeps handbook
questions. It presupposes a working `nen` — it cannot run when `nen` is the thing that is missing, which is
precisely the case this skill exists to handle.

The two compose, in order: **this skill first** (is there a `nen` at all, in a version the contract accepts),
**then** `nen warmup --current <vX.Y.Z>` against the target repository (is that repository's policy inbox
clear). Kurapika runs both at session start; see `claude/agents/kurapika.md` § Session warm-up.
