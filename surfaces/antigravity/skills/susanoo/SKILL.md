---
name: susanoo
description: Produce the distributable this repository declares — run the lane's own `archive` through `nen shu archive`, locally, and report every artifact it named by path and size. Runs inside `/getsuga` to build the release unit, and invoke `/susanoo [--lane <lane>]` by name to package a checkout on demand. It uploads nothing and publishes nothing, and the only thing it ever sends anywhere is one git tag, and only where the consuming repository declares `tags.archive`; a lane that declares `archive` unsupported has its own reason quoted verbatim, and a missing signing identity is the declared precondition refusing, never a gap to fill — nen synthesises no signing material and neither does this skill.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md`,
`docs/LAUNCH-MIGRATION.md` and `docs/STANDALONE-ENTRY.md` belong to the resolved **Hatsu plugin
root**, not the consuming repository. On an installed surface, use the absolute root printed by
`hatsu-warmup` to read those files (re-resolve through that skill if unavailable). Relative links
below identify source locations; a missing consumer `docs/` copy is not a missing policy and must not
trigger a duplicate filing. Never copy or invent a second policy in the target repository.



# Susanoo — the armour around the release unit: the artifact, built here, sent nowhere

**Nature: Transmuter** carries every run: susanoo executes declared machinery — one lane's `archive`
row — and reports what came out. It authors nothing, and **the only thing it moves off this machine is
one declared git tag** (§ 5a) — never the artifact. An
upload is [`/kagutsuchi`](../kagutsuchi/SKILL.md) and a publication is
[`/mugetsu`](../mugetsu/SKILL.md); both are the maintainer's own per-target call, and neither is
this phase.

> **Build the thing this repository says it ships, from its own declaration, and tell me exactly what
> came out and how big it is. The artifact stays here; only the tag I asked for leaves.**

Susanoo is **not human-called**. It runs where a release unit is needed —
[`/getsuga`](../getsuga/SKILL.md) § 3 builds through it — and the maintainer may invoke it alone
to see what a checkout packages to. It opens nothing and deploys nothing, and it pushes nothing but the
one opt-in tag of § 5a.

---

## 0. Standalone entry — already total, and § 1 says so

**Susanoo is explicitly both**: it runs inside [`/getsuga`](../getsuga/SKILL.md) to build the
release unit, **and** it is invoked by name to package a checkout on demand. That is exactly the
wireability [`docs/STANDALONE-ENTRY.md`](../../../../docs/STANDALONE-ENTRY.md) § 2 Rule 2 asks of every skill, and susanoo had it first.

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
| Whether to tag the unit, and with what name | `nen/workflow.json` → `tags.archive` — **the one thing susanoo reads from the workflow file** (§ 5a). Absent, it tags nothing |

Everything else susanoo reads is `nen/contract.json`'s: packaging is what a repository *does*, not
what the workflow *decides*, and the one workflow key above is read because *whether a build gets
marked* is a policy question rather than a packaging one. There is no `archive` entry in
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

## 5a. The build tag — OPT-IN, and only after a green archive

**A repository may ask for the release unit it just built to be marked with a tag.** This is the one
thing susanoo does that leaves the machine, it exists because a build nobody can point at afterwards
is a build nobody can rebuild, and it is **off unless the consuming repository turns it on**
(maintainer's ruling of 2026-09-18). A repository with no `tags.archive` block behaves exactly as it
did before this section existed: no tag, no push, no mention.

### The declaration

`nen/workflow.json` → `tags.archive`, in the **consuming** repository. It is policy, not a command,
which is why it lives there and not in `nen/contract.json`:

```json
"tags": {
  "archive": { "nameFrom": ".nen/archive/tag-name", "push": true }
}
```

| Key | Meaning |
|---|---|
| `nameFrom` | A repo-relative path whose **first line is the tag name**. The repository's own `archive` row writes it. |
| `push` | `true` pushes the tag to `origin`; `false` (or absent) cuts it locally only. |
**Report which of the three the declaration was**, in § 8's block: **absent** (no `tags.archive` —
the default, nothing owed), **present and well-formed**, or **present and malformed**. nen validates
nothing here — an unknown key is preserved, so a typo like `tags.archiv` or a `nameFrom` of the
wrong type produces *no tag and no error*, which is indistinguishable from "off" to a repository that
meant to opt in. Saying which of the three was read is what makes off and broken tell apart.

**The name is the REPOSITORY'S, never this skill's.** Susanoo does not compose a tag name, does not
template one, and does not derive one from a version it read out of an artifact — it cannot know what
a version means in a stack it is forbidden to know the name of. The repository writes the name it
wants while it is building the thing, which is the only moment anything knows both the version and
the build number; susanoo reads that line and cuts it. A `nameFrom` file that is missing, empty, or
holds something `git check-ref-format` rejects is **reported and not worked around** — never a name
invented so that there is something to cut.

### The order, and it is not negotiable

1. **The archive came back exit `0`.** A red, seated, host-refused or precondition-refused run tags
   nothing, ever.
2. **Every declared artifact is present** (§ 5). A tag pointing at a commit whose release unit was
   never produced is worse than no tag: it is a claim.
3. **The working tree is CLEAN at `--at`.** § 0's P2 already computes this and § 0 already names the
   hazard — *"an archive built from a dirty checkout is a distributable that matches no commit"*. A
   tag is the thing that makes that mismatch permanent and public: `--at HEAD` on a dirty tree
   attests a commit whose bytes are not the bytes that were archived. Read the classification; a
   dirty tree is a reported tag refusal, and the archive still stands.
4. **Then, and only then**, the tag is cut:

```bash
# nameFrom is DATA, never a command fragment. Resolve it against --repo's root,
# refuse it if it escapes that root, read the name with the path QUOTED and
# `--` terminating options, and validate the name BEFORE anything is spawned
# with it. A declaration is a policy file from another repository; it is
# untrusted input, and `--name "$(head -n1 $nameFrom)"` would be one metacharacter
# away from running that repository's shell command on this machine.
root="$(git -C <path> rev-parse --show-toplevel)"
file="$root/<nameFrom>"                       # relative to the REPO, not the process
case "$(cd "$(dirname -- "$file")" && pwd -P)/" in
  "$root"/*) : ;;
  *) echo "nameFrom resolves outside the repository -- refused"; exit 2 ;;
esac
name="$(head -n1 -- "$file" | tr -d '\r')"
[ -n "$name" ] || { echo "nameFrom's first line is empty -- refused"; exit 2; }
git -C <path> check-ref-format "refs/tags/$name" \
  || { echo "the declared tag name is not a legal git ref -- refused"; exit 2; }
nen tag cut --repo <path> --name "$name" --at <HEAD sha> --trunk <branch.base> [--push]
```

**`--trunk` is passed, never defaulted.** `nen tag cut` defaults it to `main`, and a consuming
repository whose trunk is `master` would otherwise fail with *"Not a valid object name
origin/main"* — the feature inoperable for a reason that names the wrong thing. The value is
`nen/workflow.json` → `branch.base`, one key from the `tags` block already being read.

`nen tag cut` is the verb and it is never improvised around: the tag is annotated, the name is
refused if it already exists locally or on `origin` (**re-tagging is never the fix**), and `--at` is
refused unless it is an ancestor of `origin/<trunk>`.

### The ancestor rule — what it actually says, which is NOT "not on a feature branch"

**It is a rule about the COMMIT, not about the branch, and stating it as a branch rule is wrong.**
`--at` is refused unless that commit is an ancestor of `origin/<trunk>`. A feature branch cut at the
trunk's tip and carrying no commits of its own has a `HEAD` that **is** such an ancestor, so it tags
successfully; a branch carrying its own unpushed work does not. The honest sentence is: **a commit
that is not yet on `origin/<trunk>` cannot be tagged.**

This correction matters because the wrong version is reassuring in the wrong direction — it reads as
though being on a branch were itself the protection, and it is not. What protects the tag from
attesting the wrong bytes is the clean-tree condition in the order above, not the branch name.

susanoo does not route around the refusal either way — not by tagging a different commit, not by
pushing the branch first, not by dropping `--push` so that a local tag stands in for one nobody else
can resolve.

**A tag refusal never retroactively fails the archive.** The archive already succeeded; the release
unit is on disk and § 8's block still reports it. The tag is reported as its **own line with its own
verdict** — cut and pushed, cut locally, or refused with nen's reason quoted — and a run that
archived cleanly and could not tag says both things, in that order. What is never done is letting the
tag's failure read as the archive's, or the archive's success read as though the tag happened.

### The name must not be able to impersonate a release tag

**A build or distribution tag and [`/getsuga`](../getsuga/SKILL.md)'s release tag share one
namespace on `origin`, and that is a hazard the declaration has to close.** `mugetsu` proves a
release tag exists by its NAME resolving on `origin` — sound while only `getsuga` could put a name
there, and a coincidence once anything else can. Worse, the collision is permanent: a build tag that
takes `v1.2.0` makes the real `v1.2.0` uncuttable forever, and `mugetsu` forbids deleting or moving
a tag to recover.

So the declared name **must carry a species prefix** — `build/` for § 5a, `dist/<target>/` for
[`/kagutsuchi`](../kagutsuchi/SKILL.md) § 4a — and a `nameFrom` first line that does not is a
**reported refusal**, not a tag. A name matching a release-tag shape (`v<semver>`) is refused for the
same reason even if the prefix is absent by accident rather than design.

```bash
case "$name" in
  build/*) : ;;
  *) echo "the declared tag name does not carry the 'build/' species prefix -- refused"; exit 2 ;;
esac
```

### When the push fails after the tag was cut

`nen tag cut --push` is **not atomic**: it creates the tag locally and then pushes, so a rejected
push (a protected-tag rule, a lost credential, a process killed between the two) leaves the name
taken locally and absent on `origin`. The verb then refuses that name forever — *"already exists
locally -- never re-tagged"* — and every escape this section otherwise names is closed.

**That one state has a sanctioned remedy, and it is the only one:** a local tag of the same name, at
the same SHA, that is **not** on `origin` may be deleted and re-cut, because nothing was ever
published and there is no history for anyone to have fetched. Verify both facts before touching it —
`git tag --points-at` for the SHA and `git ls-remote --tags origin <name>` for the absence — and say
that it was done. This is not a re-tag; it is the completion of one that never finished.

### Inside `getsuga`, the tag step does not run

[`/getsuga`](../getsuga/SKILL.md) § 3 builds the release unit **through susanoo**, before its
release PR is merged — and getsuga's own § *Composition* states the invariant that makes that safe:
*"A tag cut without a merged release PR would be a tag on a commit nobody approved."* A § 5a cut
inside that run would be exactly such a tag, and it would also be a **push from inside a composite**,
which no composite in this plane performs.

**So when susanoo runs as getsuga's step 3, § 5a is skipped**, and the report says so in one line.
The build tag is for a susanoo invoked on its own; the release tag is getsuga's, after the merge.

### Why the declaration is enough, and no separate per-run word is asked

`nen tag cut` makes `--push` an explicit per-invocation flag on purpose — *"a tag that exists only
locally can be inspected and discarded; one already pushed to a shared remote cannot be un-cut"* —
and `tags.archive.push` turns that per-invocation decision into a standing key. That is a real
widening, and it is worth naming rather than glossing.

**What makes it acceptable is that the carve-out above removes the only non-human path.** Susanoo
reaches § 5a from exactly two places: inside [`/getsuga`](../getsuga/SKILL.md), where the tag
step is now skipped, and from the maintainer invoking `/susanoo` directly — which is a human
call naming this repository, at this moment, on this checkout. So every remaining path to a pushed
tag has a person at the start of it, and a second confirmation inside the run would be the theatre
[`/kagutsuchi`](../kagutsuchi/SKILL.md) § 1 refuses for the same reason.

**If that ever stops being true** — a composite reaching susanoo without the carve-out, or a
delegated session — the standing key is not enough on its own and this section is where the extra
gate belongs.

### What this does NOT become

A cut tag is **not** authorization to send anything. [`/kagutsuchi`](../kagutsuchi/SKILL.md) is
still the maintainer's own per-target call and [`/mugetsu`](../mugetsu/SKILL.md) is still
**G3**. Susanoo gained one narrow, declared, opt-in push; it gained nothing else, and § 8's
`built locally; nothing was uploaded` is still said on every run.

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

**One line for the tag, always** (§ 5a): which of *cut and pushed* / *cut locally* / *refused, with
nen's reason* / *not declared* / *skipped inside getsuga* happened, and — where the declaration was
present but malformed — that it was read and rejected rather than silently ignored. A block that
omits the tag line cannot be told apart from a run that never tried.

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
  `nen shu tools`; read the declared artifacts' paths and sizes; report every code. **And, where the
  consuming repository declares `tags.archive`, cut that one tag through `nen tag cut` after a green
  archive — pushing it when the declaration says `push` (§ 5a).**
- **Not permitted:** `nen shu deploy` in any form, with or without `--run`; `nen shu release` in any
  form; any upload, any publication, any commit, any PR, any label. **Any push or tag other than the
  single declared one of § 5a** — that block is the whole of the permission, it is opt-in, and a
  repository that does not declare it gets exactly the old behaviour. Also: no edit to a declaration
  on the fly — a wrong `archive` row is a **G4** PR of its own, and so is adding a `tags.archive`
  block so that a tag will be cut.
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
  archive read as authorization to send it anywhere — **a cut tag included** (§ 5a).
- **Never tags a repository that did not declare `tags.archive`**, never composes or templates a tag
  name of its own, and never tags after anything but an exit `0` with every declared artifact
  present.
- **Never re-tags, and never routes around a tag refusal** — not by tagging another commit, not by
  pushing a branch to make `--at` an ancestor, not by dropping `--push` so a local tag stands in for
  one that resolves on `origin`.
- **Never lets a tag refusal read as a failed archive, or a green archive read as a cut tag.** Two
  verdicts, reported separately, every time (§ 5a).
