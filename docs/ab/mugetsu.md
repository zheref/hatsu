# Evidence — `mugetsu` (new skill, Hatsu workflow fold-in)

`claude/skills/mugetsu/SKILL.md`: publication — stores and production — behind **G3** (`CON-6`). One
recorded per-target go from the maintainer, quoted verbatim; `nen release preflight` read at the
tagged commit; then the declared `release` row and/or `nen shu deploy --target <production> --run`,
once.

**Not a port.** There is no retired skill behind it. What it replaces is the assumption that a cut tag
and a merged release PR add up to permission to ship. § 2 records what each step is at nen `0.3.0`,
live, with exit codes — including **two facts about the binary that change how the skill is written**:
`nen shu release` has no `--run` gate, and `release preflight`'s tag row inverts after the cut.

**Run:** 2026-09-10 (local clock), `nen 0.3.0` at `/Users/zheref/.local/bin/nen`; host
`Darwin 25.4.0 arm64`, `node v24.16.0`. Hatsu at `2e066ab` (`origin/fable/kurapika/wave-3`).

Two surfaces were used, and neither was mutated:

- **`nen release preflight` read-only against the real `zheref/nen` checkout** (`2d4d5ed`, tags
  `v0.2.0`/`v0.3.0`/`v0.4.0`), with `GH_TOKEN=$(gh auth token)`. It reads `gh variable get` and
  `git ls-remote origin` and writes nothing. § 2.4's probe created **one local tag and deleted it in
  the same command**; nothing was pushed and no remote ref was touched.
- **A constructed throwaway fixture** under this worktree's `.nen-fixture/` for every `shu` verb —
  lane `app` with `release` and `deploy` rows whose declared commands are a `node -e` that prints a
  line, lane `docs` seating both in its own words, lane `signed` naming a store-upload binary that is
  not on this host, and a `production` target with a `requiresEnv` — **deleted before the commit**.
  **The two `--run`/publish lines in this record were fired at that fixture. No store, no live
  environment and no real destination was contacted.**

*Paths sanitized: this machine's absolute paths appear as `<fixture>` and `<nen checkout>`. Nothing is
redacted — both repositories are public — and the transcripts are otherwise verbatim.*

---

## 1. The skill

| Step | Mechanism | Owner |
|---|---|---|
| 1 | The maintainer records a per-target go, in their own words | **the human gate (G3)** — no verb, and none should exist |
| 2 | Refuse a go with no tag; require the tag to resolve on `origin` | verb, as a side effect (§ 2.3–2.4) — the row that fails is the proof |
| 3 | Read every release precondition — `nen release preflight` | verb |
| 4 | Read the table **by rows**, not by exit code | **the skill** — the tag row inverts after the cut (§ 3) |
| 5 | Print the publication plan — `nen shu release --dry-run` / `nen shu deploy --target … --dry-run` | verb |
| 6 | Publish once — `nen shu release` (bare!) and/or `nen shu deploy --target … --run` | verb |
| 7 | React to `0`/`1`/`2`/`3`/`4`/`5` | the skill's table, from `claude/agents/kurapika.md` § *The `shu` verbs* |
| 8 | Record the go on the release PR — `nen issue comment --body-file` | verb, with the quote assembled by hand |
| 9 | Keep "one target per call" | **the skill** — `shu release` has no `--target` at all (§ 2.5) |

**Count.** Nine steps; **five are verbs**, one is the human gate itself, three are named residue.

## 2. Verbs exercised live

### 2.1 — `nen release preflight`, read-only against the real `zheref/nen`

```
$ export GH_TOKEN=$(gh auth token)
$ nen --repo <nen checkout> release preflight --repo-slug zheref/nen --tag v0.9.9 \
    --range v0.2.0..v0.3.0 --changelog CHANGELOG.md --owner-repo zheref/nen \
    --critical-issues '' --live-chores-from live-chores.json
ok    RELEASE_HOLD -- not set
ok    open critical issues -- none open
ok    CON-36 live chores -- none live (issue open AND branch exists AND an open PR targets it or main)
ok    changelog.d/ empty at cut point -- empty
FAIL  CON-33(c) reconciled -- missing: #96, #136
ok    tag does not already exist -- clear
exit=1
```

(`live-chores.json` was `[]`, asserting none live.) **All six rows, always** — the verb never stops at
the first failure, which is what makes the table quotable whole into a G3 stop. Re-run against
`v0.3.0..v0.4.0` it reports the same shape with `missing: #137, #148`.

### 2.2 — a flag omitted fails its row; it is never skipped

```
$ nen --repo <nen checkout> release preflight … --live-chores-from live-chores.json   # no --critical-issues
ok    RELEASE_HOLD -- not set
FAIL  open critical issues -- not supplied -- not checked (pass --critical-issues, or --critical-issues '' to assert none)
ok    CON-36 live chores -- none live (issue open AND branch exists AND an open PR targets it or main)
…
```

*"not supplied -- not checked"* is the honesty this whole gate depends on: **an unperformed check is
never rendered as a clean one.** The caller gathers the GitHub facts (`hatsu:getsuga` § 2 owns how);
nen owns the AND-logic and refuses to guess the inputs.

### 2.3 — the row that inverts: the tag mugetsu needs is the tag this row forbids

Same command, `--tag v0.4.0` — a tag that exists:

```
ok    changelog.d/ empty at cut point -- empty
FAIL  CON-33(c) reconciled -- missing: #137, #148
FAIL  tag does not already exist -- 'v0.4.0' already exists -- re-tagging is never the fix
exit=1
```

**`preflight` is a pre-*cut* table.** `hatsu:getsuga` runs it before cutting, where *the tag does not
exist yet* is the right assertion. `hatsu:mugetsu` runs after the cut, where the same assertion must
be **false** — the tag is exactly what it is publishing. So the skill's green is *"every row `ok`
except this one, and this one `FAIL … already exists`"*, and the exit code — `1` in both the good and
the bad case — is never read as the verdict.

### 2.4 — and that row reads **origin**, not this checkout

A tag was created locally only, the preflight run against it, and the tag deleted, in one command:

```
$ git -C <nen checkout> tag zz-nen-local-only-probe HEAD
$ nen --repo <nen checkout> release preflight … --tag zz-nen-local-only-probe …
…
ok    tag does not already exist -- clear
$ git -C <nen checkout> tag -d zz-nen-local-only-probe
Deleted tag 'zz-nen-local-only-probe' (was 2d4d5ed)
```

**A tag present locally reports `clear`.** So § 2.3's `FAIL` is not merely "some tag with that name
exists somewhere" — it is positive evidence the tag is **on the remote**, which is the thing
`CON-14` and the skill's § 3 actually require before anything names it. One call proves both.

### 2.5 — `nen shu release`: no `--run`, no `--target`, and the bare form publishes

```
$ nen shu release --repo <fixture> --run
nen shu: --run is not read by 'shu release'. A flag accepted and ignored is worse than one refused: the ignored thing is the instruction you gave.
Run 'nen shu --help'.
exit=2

$ nen shu release --repo <fixture> --target production
nen shu: --target is not read by 'shu release'. A flag accepted and ignored is worse than one refused: the ignored thing is the instruction you gave.
Run 'nen shu --help'.
exit=2

$ nen shu release --repo <fixture> --dry-run
lane:          app  (nextjs)
verb:          release
host:          darwin -- supported (declared: darwin, linux, win32)
preconditions:
  ok    path signing/identity.p12
would run:     node -e 'console.log('\''published to the store'\'')'
cwd:           <fixture>
env:           (none added)
artifacts:     (none declared)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit code to report.
exit=0

$ nen shu release --repo <fixture>
published to the store
lane:          app  (nextjs)
verb:          release
…
ran:           node -e 'console.log('\''published to the store'\'')'  -- exit 0 in 26ms
…
exit=0
```

**Three facts, and the skill is shaped around all three.**

1. **The bare line is the publication.** `shu deploy`'s two-flag discipline — *"no single-flag path to
   acting"* — does **not** exist on `shu release`. `--dry-run` is the only plan-first form, and
   typing it is a rule this skill keeps, not a guard the binary provides.
2. **`--run` is refused, not ignored** — which is the right behaviour and also a trap: a reader who
   assumes symmetry with `deploy` will type `--run`, get exit `2`, drop the flag, and *then* publish.
3. **There is no per-destination vocabulary.** `--target` is refused, so "one target per call" cannot
   be expressed to this verb at all: a repository with several publication destinations models them
   as separate lanes or as `deploy` targets, and a `release` row that fans out to several in one run
   is a declaration to fix at **G4**.

### 2.6 — the other publication shape: `deploy --target production`

The plan, with the credential asserted and never read:

```
$ env -u FIXTURE_DEPLOY_TOKEN nen shu deploy --repo <fixture> --target production
target:        production  (appends: --env production)  requires env: FIXTURE_DEPLOY_TOKEN
preconditions:
  ok    path signing/identity.p12
  FAIL  env  FIXTURE_DEPLOY_TOKEN -- not set in this environment
would run:     node -e '…' publish --dir dist --env production
1 precondition on lane 'app' is not satisfied. nen ASSERTS a precondition and never performs it: …
exit=2
```

and the send, with it set (the fixture's declared command prints a line):

```
$ FIXTURE_DEPLOY_TOKEN=… nen shu deploy --repo <fixture> --target production --run
sent: publish --dir dist --env production
target:        production  (appends: --env production)  requires env: FIXTURE_DEPLOY_TOKEN
preconditions:
  ok    path signing/identity.p12
  ok    env  FIXTURE_DEPLOY_TOKEN
ran:           node -e '…' publish --dir dist --env production  -- exit 0 in 67ms
exit=0
```

Every mechanic here is `hatsu:kagutsuchi`'s and is recorded in `docs/ab/kagutsuchi.md`; what makes
this one **G3** is not the verb but the destination, and the destination is a fact the declaration
states in prose (§ 4.3).

### 2.7 — a seat: this repository does not publish through nen

```
$ nen shu release --repo <fixture> --lane docs
nen shu release: 'release' is unsupported on lane 'docs' (nextjs). The declaration's own reason: Publication is the host reading this repository at a ref. There is no publication step to run, and nen never synthesises signing material.
exit=4
```

and the same code where the *store-upload program* is simply not installed:

```
$ nen shu release --repo <fixture> --lane signed
Executable not found in $PATH: "kro-store-upload"
…
ran:           kro-store-upload --channel appstore  -- did not start
nen shu release: step 1 of 1 could not be started: 'kro-store-upload'. This repository's declaration names it for 'release' on lane 'signed'; install it, or put it on PATH. nen never installs a toolchain on a repository's say-so.
exit=5
```

Hatsu's own declaration carries the seat shape verbatim — *"Publication is a git tag plus the
marketplace entry that already points at this repository … G3 (`CON-6`) holds the tag decision
anyway"* — and so does KroApple's, at `opus/kurapika/nen-declaration`: *"no fastlane, no altool, and
no `xcrun notarytool` … Publishing is a human action through App Store Connect and Xcode Cloud, and
**nen never synthesises signing material**."*

## 3. Residue

1. **Nothing records the go.** No verb writes "the maintainer authorised `production` for `v1.2.0`";
   `.nen/last-stop.json` is a bell marker. The verbatim quote in the report and in the release PR's
   comment is the record, assembled by hand and posted with `nen issue comment --body-file`.
2. **`nen shu release` has no `--run` gate** (§ 2.5). The show-it-before-you-do-it discipline on the
   publication verb is entirely the skill's.
3. **`nen shu release` has no `--target`** (§ 2.5). "One target per call" is the skill's discipline
   and cannot be expressed to the verb.
4. **`release preflight`'s tag row inverts after the cut** (§ 2.3). Reading the table by rows rather
   than by exit code is by hand; there is no post-cut mode and no `--expect-tag-exists`.
5. **Nothing marks a destination as production** (`docs/ab/kagutsuchi.md` § 3.1). The split between
   `hatsu:kagutsuchi` and this skill is read out of `targets.<name>.why` prose.
6. **What state a failed publication left the destination in.** nen reports the tool's exit code and
   never queries the far end.
7. **A per-run log file.** `A .nen/logs/ transcript is not in this release (zheref/nen#91)`.

## 4. Findings against the binary

1. **`nen shu release` publishes on the bare form while `nen shu deploy` requires `--run`** (§ 2.5).
   Both are defensible in isolation — `release` is one of eleven executing verbs and `deploy` is the
   documented exception — but they are the family's **two publication verbs**, and they disagree
   about which invocation acts. The asymmetry is also actively misleading: `--run` on `release` is
   *refused*, so the natural correction is to drop the flag, which publishes. Extending
   `write-flag-gated` to `shu release` (or, failing that, saying in `--help` that this verb has no
   such gate) would remove the sharpest edge in this whole phase. **The finding worth acting on.**
2. **`release preflight` has no post-cut mode** (§ 2.3–2.4). Its sixth row is written for the caller
   that cuts, and the caller that publishes needs the opposite assertion — so the one verb that
   exists to fold a table into one call hands the publication phase a table it must re-interpret by
   hand. An `--expect-tag` / `--after-cut` flag inverting that single row would let a publication
   read `exit 0` and mean it.
3. **A destination cannot declare that it is production** — the same finding
   `docs/ab/kagutsuchi.md` § 4.1 records, and it lands harder here: the boundary between an upload and
   a publication is the boundary between two skills and two gates, and it lives in free prose.
4. **The tag row reads `origin`, which is more useful than its wording suggests** (§ 2.4). *"tag does
   not already exist"* reads like a local check; it is a remote one, and that is exactly what makes
   its failure usable as proof of reachability. Worth stating in the row's own detail text.
5. **No missing verb for the publication itself.** Every deterministic step that is not in § 3 is a
   verb, exercised live above with its exit code.
