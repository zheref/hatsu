---
name: susanoo
description: Produce the distributable this repository declares — run the lane's own `archive` through `nen shu archive`, locally, and report every artifact it named by path and size. Runs inside `/getsuga` to build the release unit, and invoke `/susanoo [--lane <lane>]` by name to package a checkout on demand. It uploads nothing, publishes nothing and pushes nothing — where the consuming repository declares `tags.identity` it NAMES the tag kagutsuchi will cut on a successful upload, and cuts none itself; a lane that declares `archive` unsupported has its own reason quoted verbatim, and a missing signing identity is the declared precondition refusing, never a gap to fill — nen synthesises no signing material and neither does this skill.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md`,
`docs/LAUNCH-MIGRATION.md` and `docs/STANDALONE-ENTRY.md` belong to the resolved **Hatsu plugin
root**, not the consuming repository. On an installed surface, use the absolute root printed by
`hatsu-warmup` to read those files (re-resolve through that skill if unavailable). Relative links
below identify source locations; a missing consumer `docs/` copy is not a missing policy and must not
trigger a duplicate filing. Never copy or invent a second policy in the target repository.



# Susanoo — the armour around the release unit: the artifact, built here, sent nowhere

> **The gate on a declaration change is the REPOSITORY's role, not the file's kind.** Maintainer's
> ruling, 2026-09-18 ([`docs/ROSTER.md`](../../../docs/ROSTER.md) § *Rulings of 2026-09-18 — G4 is
> the repository's role, not the file's kind*): **`G4` (`CON-7`) in a canon repository** —
> `zheref/hatsu`, `zheref/nen`, `zheref/bankai-core`, whose product *is* the process — and **`G2`
> (`CON-5`) in a consumer repository**, where a `nen/contract.json`, `nen/workflow.json` or
> `nen/gates.json` is that repository's own configuration and governs nothing else. **This skill runs
> against consumer checkouts by design**, so read every "**G4**" below as *the declaration gate* and
> resolve it by the target's role. The merge is the maintainer's either way — the ruling moves the
> gate, never the prohibition.

**Nature: Transmuter** carries every run: susanoo executes declared machinery — one lane's `archive`
row — and reports what came out. It authors nothing, and it **moves nothing off this
machine** — not the artifact, and not a tag (§ 5a). An
upload is [`/kagutsuchi`](../kagutsuchi/SKILL.md) and a publication is
[`/mugetsu`](../mugetsu/SKILL.md); both are the maintainer's own per-target call, and neither is
this phase.

> **Build the thing this repository says it ships, from its own declaration, and tell me exactly what
> came out and how big it is. Nothing leaves this machine.**

Susanoo is **not human-called**. It runs where a release unit is needed —
[`/getsuga`](../getsuga/SKILL.md) § 3 builds through it — and the maintainer may invoke it alone
to see what a checkout packages to. It never pushes, never opens anything, and never deploys.

---

## 0. Standalone entry — already total, and § 1 says so

**Susanoo is explicitly both**: it runs inside [`/getsuga`](../getsuga/SKILL.md) to build the
release unit, **and** it is invoked by name to package a checkout on demand. That is exactly the
wireability [`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) § 2 Rule 2 asks of every skill, and susanoo had it first.

The only clause to add is **P1** — [`/hatsu-warmup`](../hatsu-warmup/SKILL.md) when no composite
ran it — plus one line of **P2** in the report: **which commit and whether the tree was clean**, because
an archive built from a dirty checkout is a distributable that matches no commit and the path list alone
does not say so.

**It still uploads nothing and publishes nothing.** A lane declaring `archive` unsupported still has its
own reason quoted verbatim; a missing signing identity is still the declared precondition refusing, never
a gap for a cold run to fill.


**Hand-back.** *Next in the wired run: `/getsuga`, which cuts the tag this unit belongs to.
Uploading and publishing are `/kagutsuchi` and `/mugetsu`, and both are yours alone to call.*

---

## 1. Invocation

```
/susanoo [--lane <lane>]
```

`--lane` overrides `nen/contract.json → project.defaultLane` for one run — for a repository whose
second lane is the one that packages. With neither, the lane is the declaration's own
`defaultLane`, and a declaration whose `defaultLane` is `null` makes `--lane` required (nen's rule,
not this skill's).

**Composition — who calls it, and what it never calls.** It is called by
[`/getsuga`](../getsuga/SKILL.md) (§ 3, to build the release unit before the tag) and by the
maintainer directly. It calls no other skill. It **never** calls
[`/kagutsuchi`](../kagutsuchi/SKILL.md) or [`/mugetsu`](../mugetsu/SKILL.md), and nothing
about a successful archive is authorization for either: a package on disk is a package on disk.

## 2. The parameters, and where they come from

| Value | File → key |
|---|---|
| Which lane packages | `nen/contract.json` → `project.defaultLane`, or `--lane` |
| What `archive` actually runs | `nen/contract.json` → `project.verbs.<lane>.archive` (`{exe, argv}`, `{steps:[…]}` or `{unsupported:"why"}`) |
| Where it runs, and with what | `project.lanes.<lane>.cwd`, the row's `env` (names only) |
| What it is supposed to produce | the row's `artifacts` — the list § 5 reports |
| Whether this host may | `project.hosts` |
| What must be true first | `project.preconditions.<lane>` — nen **asserts** these and never performs them (§ 4) |
| The identity of the tag it ANNOUNCES, and never cuts | `nen/workflow.json` → `tags.identity` — **the one thing susanoo reads from the workflow file** (§ 5a), and the SAME file kagutsuchi cuts from. Absent, § 8's tag line reads `no tag declared` — the line is always written, never omitted |

Everything else susanoo reads is `nen/contract.json`'s: packaging is what a repository *does*, not
what the workflow *decides*, and the one workflow key above is read because *what the coming
tag is called* is a policy question rather than a packaging one. There is no `archive` entry in
`iteration.checks` and there should not be —
the iteration is what [`/rasengan`](../rasengan/SKILL.md) runs as its inner loop while authoring
and what [`/kokusen`](../kokusen/SKILL.md) runs at the commit gate, and an archive is neither.

## 3. The dry run, then the run

```bash
nen shu archive --repo <path> [--lane <lane>] --dry-run     # once, on a repo you have not packaged here
nen shu archive --repo <path> [--lane <lane>]
```

The dry run prints the exact argv, the cwd, the env **names** and the declared artifacts and spawns
nothing — *"the argv printed is the argv that would be spawned, from the same rendering"*. Verified
live at nen `0.3.0` against a constructed declaration, exit `0` both ways
(`docs/ab/susanoo.md` §§ 2.1–2.2).

**The exit table — one reaction per code.** `claude/agents/kurapika.md` § *The `shu` verbs* is the
authority; this is what susanoo does with each.

| Exit | Fact | Reaction |
|---|---|---|
| `0` | the archive ran (or the dry run rendered) | report the artifacts, § 5 |
| `1` | the packaging tool ran and **failed** — its own code is in `steps[].exitCode`, nen's is always `1` | relay the tool's output, name the failing step (`step N of M`), fix it here. A half-written package is never handed onward as a release unit |
| `1` | *also*: `nen/contract.json` present and **malformed** | a repository defect, not a failed archive. Fix the declaration and land it at **G4** |
| `2` | usage, or an **unsatisfied precondition** — § 4 | the plan still prints, the failing rows marked `FAIL`. Satisfy the precondition yourself and say which one it was; never route around it |
| `3` | **unsupported host** — packaging is real, this machine is not on `project.hosts` | **G5.** Name the host the declaration allows and stop. Never retry, never re-target |
| `4` | **a seat** — the lane declares no `archive`, in the declaration's own words | Not a failure. § 6 |
| `5` | the declared program could not be started at all | `nen shu tools --repo <path>` and relay the remedy — but read § 7 before quoting its verdict |

## 4. Preconditions, and the one that is always about signing

A precondition is nen's to **assert** and never to perform. On an archive row that is nearly always
the material that signs the package — a keychain export, a keystore, a provisioning profile, a
notarization credential. Verified live: with the declared signing path absent, `nen shu archive`
reports

```
preconditions:
  FAIL  path signing/identity.p12 -- not present
…
1 precondition on lane 'app' is not satisfied. nen ASSERTS a precondition and never performs it:
satisfy it with this repository's own tooling, then run this again.
exit=2
```

and **spawns nothing** — `steps[].exitCode` is `null` and `log.mode` is `"dry-run"` in the `--json`
document, so a reader can tell a gated run from one that happened (`docs/ab/susanoo.md` § 2.3).

> **A missing signing identity is that refusal, and it is a G5 stop — never a workaround.**
> **nen never synthesises signing material**, and neither does susanoo: no self-signed identity
> conjured to get past the row, no `--no-sign` flag added to a declared argv, no export options plist
> written on the spot, no keychain unlocked, no credential read or printed. The declaration named a
> file; the maintainer's own machine is where it comes from. Stop with
> [`/jutaisho`](../jutaisho/SKILL.md) § 4's rendering — `nen stop --who kurapika --gate G5
> <efforts.md>` — naming the precondition, its `why` from the declaration, and nothing about how to
> forge one.

**The same refusal wearing exit `5`.** Where the *signing tool itself* is not on `PATH`, the code is
`5`, not `2` — verified live: a lane whose `archive` names an absent notarization binary reports
`Executable not found in $PATH: "…"` and *"nen never installs a toolchain on a repository's
say-so"*, exit `5` (`docs/ab/susanoo.md` § 2.5). Both are the same fact in two places: the machine is
not set up to sign. Both are **G5**. Neither is a reason to produce an unsigned artifact and call it
the release unit.

## 5. The artifacts — reported by path and size

The artifacts are **the declaration's `artifacts` list**, not whatever appeared under the build
directory. nen prints each declared path and whether it exists:

```
artifacts:     dist/app.tgz, dist/app.tgz.sha256 (absent)
```

— a bare path means present, `(absent)` means the declared path is not there. Two things follow, and
both are in every report susanoo writes:

- **A declared artifact that is `(absent)` after an exit `0` is a finding**, not a detail. The row
  said the archive produces it; nen never creates one. Say which paths are missing and stop treating
  the run as having produced a release unit.
- **Existence is not freshness.** nen reports whether the path is there *now*, not whether *this run*
  wrote it. Verified live: on the precondition-refused run of § 4, which spawned nothing at all,
  `dist/app.tgz` still reported `"exists": true` — a leftover from the previous green run
  (`docs/ab/susanoo.md` § 2.3). Where it matters, record the mtime and size **before** and after.

**Size is this skill's, by hand** — nen reports existence and nothing else (`docs/ab/susanoo.md`
§ 4.1). For each declared artifact that exists, `ls -l` / `stat` it and report bytes beside the path,
naming the read as by-hand. Residue, not a verb.

## 5a. The tag it ANNOUNCES and does not cut

**A release unit that never leaves this machine does not get a tag.** The maintainer's ruling of
2026-09-18, corrected 2026-09-19: a tag records a build that **landed somewhere**, and an archive has
landed nowhere. So susanoo names the tag that is coming and cuts nothing — it is
[`/kagutsuchi`](../kagutsuchi/SKILL.md) § 4a, on a successful upload, that cuts it.

**This is why susanoo still pushes nothing at all**, which is the property the rest of this file has
always described. An archive is a package on disk; it stays one.

> **The earlier shape had susanoo cutting a build tag here.** That put a permanent, public ref on a
> binary that might never be sent anywhere — and made a second tag species exist for no event anyone
> needed to point at. One artifact that reached a destination is one tag. The corrected rule is the
> symmetry the maintainer stated: **an upload that succeeds becomes a tag, and a release Apple
> approves becomes a GitHub release.**

### The declaration — ONE name source, shared with the cut

`nen/workflow.json` → `tags.identity`, in the **consuming** repository, opt-in like everything else:

```json
"tags": {
  "identity": { "nameFrom": ".nen/archive/tag-name" }
}
```

| Key | Meaning |
|---|---|
| `nameFrom` | A repo-relative path written by the repository's own `archive` row. **Line 1 is the tag's IDENTITY** — `v1.0.0+1217`, no prefix — at the one moment both the version and the build number are known. **Line 2 is the COMMIT SHA the archive was built from.** |

**Two lines, and the second one is load-bearing.** susanoo and
[`/kagutsuchi`](../kagutsuchi/SKILL.md) are separate invocations with a human decision between
them, so `HEAD` can move, and a tag cut at send time against `HEAD` would name a commit the archive
never saw. The archive knows the commit it built; it records it, and the cut uses **that** SHA.

**It is an identity, not a full tag name, and that is the whole point.**
[`/kagutsuchi`](../kagutsuchi/SKILL.md) § 4a reads **this same file** and cuts
`dist/<target>/<identity>` at the recorded SHA, applying the species prefix for the target it was
actually called with.

> **One path is not one value, and the earlier wording over-claimed.** Sharing a file does not make
> drift impossible: the archive can be re-run between the announcement and the send, rewriting both
> lines. What the shared file buys is that there is **no second name to disagree with** — and what
> closes the rest is the cut's own verification (§ 4a): it tags the **recorded SHA** rather than
> `HEAD`, and a repository whose `deploy` row can check the identity against the artifact it is
> sending should do so. Announcing is a statement about the archive that existed when susanoo ran;
> if that archive is replaced, the announcement is stale and the cut follows the file, not the
> memory.

> **An earlier shape gave each skill its own `nameFrom`.** Susanoo announced out of one file and
> kagutsuchi cut out of another, so a repository could report tag A and push tag B — and in the
> reference consumer it actually did: the announced name carried a `build/` prefix that nothing ever
> cut. One file is the fix, and the prefix is the skill's precisely because **only the cut knows its
> target**. An archive does not: it may be sent to several targets, or to none.

### What susanoo does with it

**Reads it, and says it — as an ELIGIBILITY, not a promise.** One line in § 8's block: *this unit is
eligible to be tagged `<identity>` at `<built_at>`, by whichever distribution target declares
`tags.deploy.<target>`*, `no tag declared` where the block is absent, or the declaration error where
it is malformed. Nothing else — susanoo cuts nothing.

**Susanoo cannot promise the tag, and saying it would be a lie it is in no position to detect.**
Tagging is opt-in **per target** on kagutsuchi's side (`tags.deploy.<target>`), and an archive does
not know its target — it may be sent to several, or to none. So a repository that declares
`tags.identity` and no `tags.deploy` entry at all is explicitly allowed to produce no tag ever, and a
report that said *will be tagged* would have promised an event the send phase is required to skip.
**Susanoo deliberately does not read `tags.deploy` to sharpen this line.** It would have to guess the
target to do so, and a guessed target is how a report starts being confidently wrong.

**The name is read as DATA, because reading is where the danger is.** A path out of another
repository's policy file reaches a shell here, and `$(...)` inside double quotes is command
substitution whether or not anything is cut afterwards:

```bash
# Read the VALUE out of the JSON; never template it into shell source. The JSON
# subscripts are DOUBLE-quoted inside the single-quoted -c argument -- single
# quotes there would terminate it, and the command would die before reading
# anything.
wf="$(git -C <path> rev-parse --show-toplevel)/nen/workflow.json"
# A THREE-WAY READ, because § 8 promises three DIFFERENT lines and a direct
# index can only produce one. `["tags"]["identity"]["nameFrom"]` raises KeyError
# on the default workflow that declares no tags block at all; inside a command
# substitution that failure is silent, `nameFrom` comes back empty, and the
# checks below then report `nameFrom is not a regular file` -- so the ORDINARY
# case, a repository that simply declares no tag, was being reported as a
# declaration fault, and a real declaration fault was indistinguishable from it.
# Absent is a no-op report; malformed is a declaration error; neither one fails
# the archive, which has already succeeded.
nameFrom="$(python3 -c 'import json,sys
t=json.load(open(sys.argv[1])).get("tags")
if t is None: sys.exit(3)
if not isinstance(t, dict): sys.exit("tags is %s, not an object" % type(t).__name__)
i=t.get("identity")
if i is None: sys.exit(3)
if not isinstance(i, dict): sys.exit("tags.identity is %s, not an object" % type(i).__name__)
n=i.get("nameFrom")
if not isinstance(n, str) or not n: sys.exit("tags.identity.nameFrom is missing or is not a non-empty string")
print(n)' "$wf")"; rc=$?
case $rc in
  0) : ;;
  3) echo "no tag declared"; tag_line="no tag declared" ;;
  *) echo "tag declaration error -- reported, archive stands"; tag_line="declaration error" ;;
esac
[ $rc -eq 0 ] || return 0 2>/dev/null || true

root="$(git -C <path> rev-parse --show-toplevel)"
file="$root/$nameFrom"
[ -L "$file" ] && { echo "nameFrom is a symlink -- refused"; exit 2; }
[ -f "$file" ] || { echo "nameFrom is not a regular file -- refused"; exit 2; }
case "$(cd -P -- "$(dirname -- "$file")" && pwd -P)/" in
  "$root"/*) : ;;
  *) echo "nameFrom resolves outside the repository -- refused"; exit 2 ;;
esac
identity="$(sed -n '1p' -- "$file" | tr -d '\r')"
built_at="$(sed -n '2p' -- "$file" | tr -d '\r')"   # the commit the archive was built from
```

A missing, empty, symlinked or out-of-tree `nameFrom` is **reported and the line says so** — never
worked around, and it never fails the archive, which has already succeeded.

### What this does NOT become

Announcing a tag is not authorization to send anything. [`/kagutsuchi`](../kagutsuchi/SKILL.md)
is still the maintainer's own per-target call and [`/mugetsu`](../mugetsu/SKILL.md) is still
**G3**. § 8's `built locally; nothing was uploaded` is still said on every run, and it is still
literally true — **no tag, no push, nothing off this machine.**

## 6. A seat — exit `4`, in the declaration's own words

```
$ nen shu archive --repo <fixture> --lane docs
nen shu archive: 'archive' is unsupported on lane 'docs' (nextjs). The declaration's own reason: The
documentation site is served from the repository at a ref; there is no package to produce, so there
is nothing for `archive` to name.
exit=4
```

**Quote that sentence verbatim** and stop being an archive phase for this repository. It is not a
failure and it is not a gap: across the stacks this family serves, most lanes really do declare
`{"unsupported": "<why>"}` here. The two seats in the field today say it plainly — Hatsu's own
(*"A Claude Code plugin is distributed by git ref through a marketplace, never as a built package …
There is no artifact to produce"*, `nen/contract.json`) and KroApple's (*"No repository invokes
`xcodebuild archive` … heavy builds are delegated to Xcode Cloud, whose workflows live server-side
and have no command line here"*).

Where the seat **should** be a real row, that is a declaration change to land as its own PR at
**G4** — never an argv improvised here for one run. And where the repository has a documented
packaging command outside its declaration, run *that*, say plainly that no `archive` row exists, and
propose the row.

## 7. Exit `5`, and the limit of `nen shu tools`

`nen shu tools --repo <path>` is the pointer for exit `5`, and its answer is only as wide as
`project.toolchain`. Verified live, in the direction that bites: on the very lane whose `archive`
program could not be started, `nen shu tools` reported `ok node … pinned >=18.0.0` and **exit `0`**,
because the toolchain block declares `node` and never declared the notarization binary
(`docs/ab/susanoo.md` § 2.6).

So: run it, relay its per-tool remedy — and where it comes back clean on a lane that just exited `5`,
**say that too**, and name the program from the `ran: … -- did not start` line as a tool the
declaration's `project.toolchain` does not carry. A green `tools` is not evidence that the archive's
program is installed. Never `sudo`, never a version the declaration did not pin, never an install nen
was not asked for.

## 8. What susanoo hands back

One block, and it is the whole product of the phase: the lane, the argv that ran (copied out of the
report, not re-typed), each step's own exit code and nen's, every declared artifact by **path and
size** with the by-hand read named, and — where any is `(absent)` — that fact first. On a run inside
[`/getsuga`](../getsuga/SKILL.md) this block is the release unit's evidence and goes into the
release PR body.

**One line for the tag, always** (§ 5a): *this unit is eligible to be tagged `<name>` at a
distribution target that declares `tags.deploy.<target>`*, or `no tag declared`, or the declaration
error where the block is malformed. **Eligible, never `will be`** — the opt-in is per target and
belongs to the send, which has not happened yet.
Susanoo cuts nothing, so the line is a statement of intent — never a verdict on a cut.

**Say `built locally; nothing was uploaded`, every time.** Not as ceremony: an archive and an upload
are one flag apart in most people's heads and the whole point of splitting the phases is that they
are not one flag apart here.

## Residue

1. **Artifact size.** nen reports a declared artifact's **existence**, never its size — the text
   report prints the path with `(absent)` or without it, and `--json` carries
   `{kind, value, exists}` (verified live, `docs/ab/susanoo.md` § 2.2). The byte count in § 5 is a
   by-hand `stat`/`ls -l`, named as by-hand wherever it is reported.
2. **Artifact freshness.** Nothing distinguishes a path this run wrote from one a previous run left
   (§ 5, verified live at § 2.3 — `exists: true` on a run that spawned nothing). Recording mtime or
   size before and after is by hand.
3. **RETIRED at nen `0.5`: build proof.** A green `nen shu build` writes
   `.nen/proof/<lane>.json` (`nen.shu.proof/v0.1`: `contract`, `lane`, `verb`, `treeHash`, `at`,
   `exitCode`), a red one removes it, and `nen commit check --repo <path> --require-proof <lane>`
   reads it back against **this working copy's** tree — all verified live at the pin, exit `0`
   (`docs/ab/susanoo.md` § *Retired at nen 0.5*). So before archiving, run that check and quote its
   verdict: it is the answer to "is the tree I am packaging the tree the build proved".

   **What is still residue is the ARTIFACT side of that question.** The proof binds a *tree* to a
   *build*, not a *package* to a tag: nothing records that `dist/app.tgz` came out of the proved
   tree rather than an earlier one. Freshness (2) and a manifest (4) are still the answer there, and
   still by hand.
4. **A checksum or manifest of what was produced.** Nothing in nen hashes an artifact. Where a
   repository wants one, it is a step of its own `archive` row (the fixture in `docs/ab/susanoo.md`
   declares `dist/app.tgz.sha256` for exactly that reason) — never a hash computed here and reported
   as though the declaration produced it.
5. **A per-run log file.** `log: not captured to a file … A .nen/logs/ transcript is not in this
   release (zheref/nen#91)` — each step's output is relayed as it finishes, so the report is the only
   record. Quote what matters; do not claim a log exists.

## Authority

- **Permitted:** run the lane's declared `archive` row, locally; probe the host through
  `nen shu tools`; read the declared artifacts' paths and sizes; **read `tags.identity` and NAME the
  tag that is coming** (§ 5a); report every code.
- **Not permitted:** `nen shu deploy` in any form, with or without `--run`; `nen shu release` in any
  form; any upload, any publication, any push, any commit, any PR, any label, **and any tag** — the
  cut is [`/kagutsuchi`](../kagutsuchi/SKILL.md) § 4a's, on an upload that actually succeeded,
  because a unit that landed nowhere has nothing to record. Also: no edit to a declaration on the
  fly — a wrong `archive` row is a **G4** PR of its own.
- **Never synthesises signing material**, of any kind, for any reason (§ 4).
- **Not a gate event**, with two exceptions it raises rather than owns: exit `3` (unsupported host)
  and the signing refusals of § 4 (exit `2` or `5`) are **G5** stops for the phase that called it.

## Hard limits

- **Never uploads, deploys or publishes.** The verb is `archive`; `deploy` is
  [`/kagutsuchi`](../kagutsuchi/SKILL.md)'s and `release` is
  [`/mugetsu`](../mugetsu/SKILL.md)'s, and both are the maintainer's own per-target call.
- **Never synthesises, forges, unlocks or reads signing material**, and never adds a flag to a
  declared argv to skip signing. A missing identity is exit `2` (or `5`) and a **G5** stop, quoted
  with the declaration's own `why`.
- **Never packages from a remembered command line** in a repository that declares one, and never
  substitutes a plausible packaging command for a declared one.
- **Never treats exit `4` as a failure or exit `5` as a failed archive.** A seat is the repository
  speaking; a program that will not start is a host that is not set up.
- **Never retries an exit `3`**, on any host, for any reason.
- **Never reports a declared artifact as produced because it exists** (§ 5) — existence is not
  freshness, and a leftover from the last run reads identically.
- **Never claims an artifact's size came from a verb.** nen reports existence; the byte count is
  by hand and says so.
- **Never hands a failed or partial archive onward as a release unit**, and never lets a green
  archive read as authorization to send it anywhere.
- **Never cuts a tag, and never pushes one** (§ 5a). It names the tag that is coming; the cut is
  `kagutsuchi`'s, on an upload that succeeded.
- **Never composes or templates a tag name of its own.** The name is the repository's, read from
  `tags.identity.nameFrom` as data — symlink refused, out-of-tree refused, never templated into
  shell source.
- **Never lets a missing or malformed `tags.identity` read as a failed archive.** The archive
  succeeded; the tag line says what it found.
