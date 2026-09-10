# Evidence — `susanoo` (new skill, Hatsu workflow fold-in)

`claude/skills/susanoo/SKILL.md`: archive and packaging — the lane's declared `archive` row, run
locally through `nen shu archive`, with the declared artifacts reported by path and size and nothing
sent anywhere.

**Not a port.** There is no retired skill behind it. What it replaces is the habit of typing a
packaging command between a green build and a tag, and of quietly producing an unsigned artifact when
the signing material is not on the machine. § 2 records what each step is at nen `0.3.0`, live, with
exit codes.

**Run:** 2026-09-10 (local clock), `nen 0.3.0` at `/Users/zheref/.local/bin/nen`; host
`Darwin 25.4.0 arm64`, `node v24.16.0`. Hatsu at `2e066ab` (`origin/fable/kurapika/wave-3`). Verbs
were exercised against a **constructed** throwaway git-less fixture under this worktree's
`.nen-fixture/` — three lanes (`app` with real `archive`/`release`/`deploy` rows, `docs` seating all
three in its own words, `signed` naming a notarization binary that is not on this host), a
`path` precondition standing in for a signing identity, one `toolchain` entry — **deleted before the
commit**. No mutating verb was run against any primary checkout.

*Paths sanitized: this machine's absolute paths appear as `<fixture>`. Nothing is redacted — both
repositories are public — and the transcripts are otherwise verbatim.*

---

## 1. The skill

| Step | Mechanism | Owner |
|---|---|---|
| 1 | Read the lane, the `archive` row, its `artifacts` and the lane's preconditions | the declaration, through the verb |
| 2 | Show what will run before it runs — `nen shu archive --dry-run` | verb |
| 3 | Run it — `nen shu archive --repo <path> [--lane]` | verb |
| 4 | React to `0`/`1`/`2`/`3`/`4`/`5` | the skill's table, from `claude/agents/kurapika.md` § *The `shu` verbs* |
| 5 | A seat → quote the declaration's own reason | verb (exit `4`) |
| 6 | A missing signing identity → refuse and stop | verb (exit `2` precondition, or `5` program) + **G5** |
| 7 | A program that will not start → `nen shu tools` | verb, with the limit in § 2.6 stated |
| 8 | Report each declared artifact by path **and size** | verb for the path and existence; **size is by hand** (§ 3) |
| 9 | Build proof tying the package to the tree | residue — does not exist at this pin (§ 3) |

**Count.** Nine steps; **seven are verbs**, two are named residue.

## 2. Verbs exercised live

### 2.1 — `nen shu archive`, the dry run

```
$ nen shu archive --repo <fixture> --dry-run
lane:          app  (nextjs)
verb:          archive
host:          darwin -- supported (declared: darwin, linux, win32)
preconditions:
  ok    path signing/identity.p12
would run:     node -e 'require('\''fs'\'').writeFileSync('\''dist/app.tgz'\'','\''x'\''.repeat(4096)); console.log('\''archived'\'')'
cwd:           <fixture>
env:           (none added)
artifacts:     dist/app.tgz (absent), dist/app.tgz.sha256 (absent)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit code to report.
exit=0
```

### 2.2 — the real run, and what "artifacts" actually reports

```
$ nen shu archive --repo <fixture>
archived
lane:          app  (nextjs)
verb:          archive
host:          darwin -- supported (declared: darwin, linux, win32)
preconditions:
  ok    path signing/identity.p12
ran:           node -e '…'  -- exit 0 in 26ms
cwd:           <fixture>
env:           (none added)
artifacts:     dist/app.tgz, dist/app.tgz.sha256 (absent)
log:           not captured to a file -- each step's own stdout and stderr were relayed as it finished. A .nen/logs/ transcript is not in this release (zheref/nen#91).
exit=0
```

and the same run under `--json`, abridged to the load-bearing keys:

```json
{
  "contract": "nen.shu.archive/v0.1",
  "lane": "app", "verb": "archive", "target": null,
  "steps": [ { "exe": "node", "argv": ["-e", "…"], "cwd": "<fixture>", "exitCode": 0, "durationMs": 22 } ],
  "preconditions": [ { "kind": "path", "value": "signing/identity.p12", "satisfied": true } ],
  "exitCode": 0,
  "artifacts": [ { "kind": "path", "value": "dist/app.tgz", "exists": true },
                 { "kind": "path", "value": "dist/app.tgz.sha256", "exists": false } ]
}
exit=0
```

**Two facts the skill is built on.** The artifact record is `{kind, value, exists}` — **a path and a
boolean, and no size anywhere**, in the text rendering or in the document. And the declaration
listed two artifacts while the row produces one, so a green archive reports a declared artifact as
`(absent)` — which the skill's § 5 treats as a finding rather than a detail, because nen never
creates an artifact and the row is what claimed it.

### 2.3 — the signing precondition, unsatisfied: exit `2`, plan printed, nothing spawned

The declared signing path was moved aside and the identical line re-run:

```
$ nen shu archive --repo <fixture>
lane:          app  (nextjs)
verb:          archive
host:          darwin -- supported (declared: darwin, linux, win32)
preconditions:
  FAIL  path signing/identity.p12 -- not present
would run:     node -e '…'
cwd:           <fixture>
env:           (none added)
artifacts:     dist/app.tgz, dist/app.tgz.sha256 (absent)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit code to report.
1 precondition on lane 'app' is not satisfied. nen ASSERTS a precondition and never performs it: satisfy it with this repository's own tooling, then run this again.
exit=2
```

`--json` on the same refusal carries `"exitCode": 2`, `steps[0].exitCode: null`,
`log.mode: "dry-run"` and `preconditions[0].satisfied: false`.

**And the trap the skill's § 5 names:** `artifacts[0].exists` is **`true`** on this run — nothing was
spawned, and the path is the one § 2.2 wrote a moment earlier. **Existence is not freshness**, and a
reader taking `exists: true` as "the archive produced it" would be wrong on exactly the run where it
matters most.

### 2.4 — a seat: exit `4`, in the declaration's own words

```
$ nen shu archive --repo <fixture> --lane docs
nen shu archive: 'archive' is unsupported on lane 'docs' (nextjs). The declaration's own reason: The documentation site is served from the repository at a ref; there is no package to produce, so there is nothing for `archive` to name.
exit=4
```

The same shape as the two seats already in the field: Hatsu's own `nen/contract.json`
(*"A Claude Code plugin is distributed by git ref through a marketplace, never as a built package"*)
and KroApple's (*"No repository invokes `xcodebuild archive` … heavy builds are delegated to Xcode
Cloud, whose workflows live server-side and have no command line here"*, read at
`opus/kurapika/nen-declaration`). **Across the stacks this family serves, the seat is the common
case**, which is why the skill's § 6 is a section rather than a footnote.

### 2.5 — the signing *tool* absent: exit `5`, the same fact wearing a different code

A third lane declares a notarization binary that does not exist on this host:

```
$ nen shu archive --repo <fixture> --lane signed
Executable not found in $PATH: "kro-codesign-notarize"
lane:          signed  (nextjs)
verb:          archive
host:          darwin -- supported (declared: darwin, linux, win32)
preconditions: (none declared)
ran:           kro-codesign-notarize --identity 'Developer ID Application'  -- did not start
cwd:           <fixture>
env:           (none added)
artifacts:     dist/Signed.app.zip (absent)
log:           not captured to a file -- …
nen shu archive: step 1 of 1 could not be started: 'kro-codesign-notarize'. This repository's declaration names it for 'archive' on lane 'signed'; install it, or put it on PATH. nen never installs a toolchain on a repository's say-so.
exit=5
```

*"nen never installs a toolchain on a repository's say-so"* is the binary's own sentence, and it is
the same posture the skill states for signing material: the declaration names it, the machine
provides it, and nothing synthesises it.

### 2.6 — `nen shu tools` is only as wide as `project.toolchain`

Run against the lane that had just exited `5`, on the same host, in the same second:

```
$ nen shu tools --repo <fixture> --lane signed
lane:          signed  (nextjs)
mode:          check
  ok       node  24.16.0  pinned >=18.0.0  (tested minimum 20.19.0)
exit=0
```

**Exit `0`, one green row, and no mention of the program that would not start.** `project.toolchain`
hangs off the *project* and declares `node`; the notarization binary appears only inside a verb's
argv, which this verb does not read. The skill's § 7 says so out loud rather than letting a green
`tools` be quoted as evidence that an exit `5` is fixed.

### 2.7 — the ordinary green build beside it, for the contrast

```
$ nen shu build --repo <fixture>
build ok
…
artifacts:     dist/app.js (absent)
exit=0
```

Recorded because it is the neighbouring verb the caller ran a moment earlier: `build` and `archive`
are two rows, two artifact lists and two exit codes, and susanoo never reports one as the other.

## 3. Residue

1. **Artifact size.** No verb reports it (§ 2.2 — `{kind, value, exists}`, and the text rendering
   prints the path with or without `(absent)`). The byte count in the skill's § 5 is a by-hand
   `stat`/`ls -l`, named as by-hand wherever it appears.
2. **Artifact freshness.** Nothing distinguishes a path this run wrote from a leftover (§ 2.3).
   Recording mtime or size before and after is by hand.
3. **Build proof.** `.nen/proof/<lane>.json` and `nen commit check --require-proof <lane>` are not in
   this release — they arrive at nen `≥ 0.5`. There is therefore no mechanical tie between the
   package and the tree that gets tagged; the transcript in the phase's report is the tie, and the
   caller carries it. Same residue `hatsu:rasengan` § 10 names for the build.
4. **A checksum or manifest of what was produced.** Nothing in nen hashes an artifact. The fixture
   declares `dist/app.tgz.sha256` to make the point that this belongs in the repository's own
   `archive` row, not in a hash computed here and reported as the declaration's output.
5. **A per-run log file.** `A .nen/logs/ transcript is not in this release (zheref/nen#91)` —
   verified live in §§ 2.2 and 2.5.

## 4. Findings against the binary

1. **`shu archive` reports artifact *existence*, never size — and existence is not freshness**
   (§§ 2.2–2.3). Both halves are defensible on their own (nen never creates an artifact, so it
   reports what is there), but together they produce the one misreading that matters: on a run that
   spawned **nothing**, `artifacts[0].exists` was `true`. A `{ size, mtime }` beside `exists`, or a
   `producedByThisRun` boolean, would close it. Recorded, not filed.
2. **`nen shu tools` answers for `project.toolchain` and is silent about a verb's own argv** (§ 2.6).
   Exit `0` on a lane whose declared program had just failed to start is correct by the verb's
   contract and misleading as the documented remedy for exit `5` — which is exactly where the exit-5
   message sends a caller. A row synthesised from the failing step's `exe`, marked as *named by a
   verb, not by the toolchain block*, would remove the gap. Recorded, not filed.
3. **A seat's refusal prints no document** — exit `4` is a line on stderr and an empty stdout
   (§ 2.4), consistent with the rest of the CLI. Noted because a `--json` caller reading a seat gets
   nothing to parse and must read the exit code; the skill quotes the stderr sentence verbatim for
   that reason.
4. **No missing verb for the archive itself.** Every deterministic step of the packaging phase that
   is not in § 3 is a verb, exercised live above with its exit code.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| build proof tying the package to a proved tree | `nen shu build` writes `.nen/proof/<lane>.json`; `nen commit check --require-proof <lane>` reads it | `0` / `0` |

The transcripts are in `docs/ab/rasengan.md` § *Retired at nen 0.5*. Row 9 of § 3's table — *"Build proof
tying the package to the tree — residue, does not exist at this pin"* — is **half retired**: the proof
binds a **tree** to a **build**, and `commit check` says whether this working copy is that tree, so
susanoo can now state that fact before it archives instead of asserting it.

**What stays residue is the ARTIFACT side of the same question.** Nothing records that `dist/app.tgz`
came out of the proved tree rather than an earlier run — that is rows 1, 2 and 4 of the same table
(size, freshness, a checksum), all still by hand, all still named where they are reported.
