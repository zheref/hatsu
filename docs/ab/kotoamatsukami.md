# A/B evidence — `kotoamatsukami` (new skill, wave 3)

`claude/skills/kotoamatsukami/SKILL.md`: the declared end-to-end / UI suite — run it through
`nen shu ui-test`, read the runner's own result, quote a seat verbatim, and hand the scenes it
re-recorded to the evidence table [`rikugan`](../../claude/skills/rikugan/SKILL.md) and
[`shibari`](../../claude/skills/shibari/SKILL.md) build from.

**A new skill, so there is no "old mechanics" column.** What this record establishes is that the *run*
half is a complete verb at the pinned `0.3.0` — dry run, exit-code table, seat, red-run relay, all
verified live — and the *evidence* half has none: `nen shu evidence` is not a `shu` subcommand here, and
the by-hand replacement has a **silent-failure mode** (§ 4.1) that would have shipped an empty evidence
table as if it were a truthful one.

Run: 2026-09-10 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
Every transcript ran against a **constructed throwaway fixture** at `<worktree>/.nen-fixture` — a
hand-written `nen/contract.json` `project` block with three lanes (a runnable `ui-test`, a **seat**, and
a deliberately red one), a `project.evidence` block, a local `git init` and three commits including three
re-recorded PNGs — created for this run and deleted before the branch was committed. **No verb was run
against KroApple, KroAndroid or kro-pwa in any form, and nothing was pushed anywhere.**

Nothing below is redacted; both repositories are public.

---

## 1. The skill

| Step | Owned by | State at `v0.3.0` |
|---|---|---|
| The invocation | `nen parse kotoamatsukami --grammar "on [<lane>]"` | **verb** (§ 2.1) |
| The pre-flight | `nen shu ui-test --dry-run` | **verb** (§ 2.2) |
| The run | `nen shu ui-test` | **verb** (§ 2.3) |
| A lane with no UI suite | `nen shu ui-test` exit `4` | **verb** (§ 2.2) |
| The runner's parsed results | `nen shu test-report` | **absent** → residue (cited — `docs/ab/tsukuyomi.md` § 2.4) |
| The re-recorded scene set | `nen shu evidence --base <ref>` | **absent** → residue (§ 2.4) |
| `project.evidence` survives the loader | `nen schema check` | **verb** (§ 2.5) |
| Looking at a golden | — | **no verb, and never will be** → boundary (§ 4.3) |

**Eight rows; five are verbs, two are residue, one is a boundary.** The split runs exactly along the
line the skill is built on: nen owns *running the suite* completely, and owns *nothing* about the images
it produced.

---

## 2. Verbs exercised live

### 2.1 — `nen parse kotoamatsukami`: the lane clause

```
$ nen parse kotoamatsukami --grammar "on [<lane>]" --line "on shell"
lane: shell
exit=0
```

The slot is anchored behind the literal `on`, which is what the engine requires
(`docs/ab/rikugan.md` § 2.1). As in `murasaki` (`docs/ab/murasaki.md` § 2.1), a **bare** invocation has
nothing to parse and makes no parse call; the lane then resolves from
`nen/workflow.json → iteration.lane`, defaulting to the declaration's `project.defaultLane`.

### 2.2 — `nen shu ui-test`: the dry run, and the seat

The fixture's `app` lane declares
`ui-test = {exe: "echo", argv: ["fixture-ui-test"], artifacts: ["__Snapshots__/Home-typical.png"]}`:

```
$ nen shu ui-test --repo <fixture> --dry-run
lane:          app  (nextjs)
verb:          ui-test
host:          darwin -- supported (declared: darwin, linux)
preconditions: (none declared)
would run:     echo fixture-ui-test
cwd:           <fixture>
env:           (none added)
artifacts:     __Snapshots__/Home-typical.png (absent)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit
               code to report.
exit=0
```

`--dry-run --json` returns the same facts as one document at exit `0`:

```json
{ "contract": "nen.shu.ui-test/v0.1", "lane": "app", "stack": "nextjs", "verb": "ui-test",
  "target": null,
  "steps": [ { "exe": "echo", "argv": ["fixture-ui-test"], "cwd": "<fixture>",
               "exitCode": null, "durationMs": null } ],
  "cwd": "<fixture>", "env": [],
  "host": { "platform": "darwin", "supported": true, "declared": ["darwin", "linux"] },
  "preconditions": [], "exitCode": 0, "durationMs": 0,
  "artifacts": [ { "kind": "path", "value": "__Snapshots__/Home-typical.png", "exists": false } ],
  "log": { "mode": "dry-run", "captured": false, "path": null, "why": "…" } }
```

**`steps[].exitCode: null` is how a `--json` reader tells a dry run from a real one** — there is no
`dryRun` boolean, deliberately.

**The seat.** The fixture's `shell` lane declares `ui-test` as `{"unsupported": "…"}`:

```
$ nen shu ui-test --repo <fixture> --lane shell
nen shu ui-test: 'ui-test' is unsupported on lane 'shell' (xcode-ios). The declaration's own reason:
The UI-test targets are not wired into a runnable scheme yet; the seat is here so the absence is
stated rather than omitted.
exit=4
```

```
$ nen shu ui-test --repo <fixture> --lane shell --json
exit=4
```

**Under `--json` a seat prints no document at all** — stdout is empty and the sentence goes to stderr.
That is the family-wide property (`nen shu --help`: *"a REFUSAL PRINTS NO DOCUMENT … so a --json reader
never has to tell a report from an error object on one stream"*), and it is why the skill's § 5 quotes
the **stderr sentence** rather than reading a field out of a document that is not there.

### 2.3 — A red run: the runner's own code, and its own words

The fixture's `web` lane declares a deliberately failing multi-step row:

```
$ nen shu ui-test --repo <fixture> --lane web
1 failed, 3 passed
lane:          web  (nextjs)
verb:          ui-test
host:          darwin -- supported (declared: darwin, linux)
preconditions: (none declared)
ran:           sh -c 'echo "1 failed, 3 passed"; exit 1'  -- exit 1 in 3ms
cwd:           <fixture>
env:           (none added)
artifacts:     (none declared)
log:           not captured to a file -- each step's own stdout and stderr were relayed as it
               finished. A .nen/logs/ transcript is not in this release (zheref/nen#91).
step 1 of 1 failed: sh -c 'echo "1 failed, 3 passed"; exit 1' -- exited 1. nen exits 1 whatever the
tool's own code was; the tool's code is in the report above.
exit=1
```

Under `--json`, `steps[0].exitCode` is `1` (**the runner's**) and the top-level `exitCode` is `1`
(**nen's**), with `log.mode: "streamed"`.

**What this pins down for the skill:** the line `1 failed, 3 passed` is the runner's, relayed as it
finished, and it is the *only* count that exists — there is no parsed results document at this pin
(§ 3.2). So § 8's rule, *"never a pass/fail count nen did not print and the runner did not say"*, has
teeth: the quotable string is right there and a restated number would be invention.

### 2.4 — `nen shu evidence` is absent — and the by-hand replacement fails **silently**

```
$ nen shu evidence --repo <fixture> --base main
nen shu: unknown option '--base'. Known options here: --branch <value>, --discard, --dry-run,
--from <value>, --help, --install, --json, --lane <value>, --only <value>, --repo <value>, --run,
--target <value>, --tests, --threshold <value>, --write.
Run 'nen shu --help'.
exit=2
```

**The refusal lands on the option, not the subcommand** — `--base` is unknown to `nen shu` as a whole,
so `evidence` is not a subcommand that exists with different flags; it is not there. (`nen shu --help`
lists thirteen verbs and it is not among them.) Brief § 4.6 has it landing on nen `main` this week and
shipping at `0.4.0`.

**So the enumeration is by hand — and this is the finding.** The fixture's declaration carries
`"globs": ["**/__Snapshots__/**/*.png"]`, and three snapshots were added on the branch. Passing the
declared glob to git as a pathspec, verbatim:

```
$ git diff --name-status main...HEAD -- '**/__Snapshots__/**/*.png'
exit=0
rows=0
```

**Zero rows, exit `0`, no warning — against a tree that plainly contains three of them:**

```
$ git diff --name-status main...HEAD
A	Tests/HomeTests/__Snapshots__/Home-empty.png
A	Tests/HomeTests/__Snapshots__/Home-typical.png
A	Tests/SettingsTests/__Snapshots__/Settings-typical.png
A	src-touch.txt
A	src/gate.ts
```

With git's `:(glob)` pathspec magic, the same string matches all three:

```
$ git diff --name-status main...HEAD -- ':(glob)**/__Snapshots__/**/*.png'
A	Tests/HomeTests/__Snapshots__/Home-empty.png
A	Tests/HomeTests/__Snapshots__/Home-typical.png
A	Tests/SettingsTests/__Snapshots__/Settings-typical.png
rows=3
```

and so does a pattern written for git's **default** matcher, where a bare `*` already crosses
separators:

```
$ git diff --name-status main...HEAD -- '*__Snapshots__/*.png'
A	Tests/HomeTests/__Snapshots__/Home-empty.png
A	Tests/HomeTests/__Snapshots__/Home-typical.png
A	Tests/SettingsTests/__Snapshots__/Settings-typical.png
```

The two matchers disagree about `**` in opposite directions, which is exactly how a declared glob and a
git pathspec come apart. See § 4.1.

### 2.5 — `project.evidence` and `project.launch` survive the loader untouched

```
$ nen schema check --repo <fixture>
repository: <fixture>
  FAIL  nen/labels.json  … no such file …
  FAIL  nen/repos.json   … no such file …
  FAIL  nen/colors.yml   … no such file …
  warn  nen/gates.json   … no such file …
  ok    nen/contract.json  project (2 lanes: app, shell; 5 verbs; 0 toolchain entries)
nen: this repository's taxonomy could not be read. …
exit=1
```

**The `nen/contract.json` row is `ok`** with both `project.evidence` and `project.launch` present in the
file — the loader preserves Hatsu-authored keys verbatim and validates the block it knows
(`docs/WORKFLOW.md` § 3). The four failing rows are about the fixture shipping no taxonomy files at all,
which is a property of a throwaway fixture and says nothing about `evidence`; the exit `1` is the
taxonomy's, not the contract's. (Run against a real checkout the taxonomy rows pass — `docs/ab/rikugan.md`
§ 2.4 records Hatsu's own five-row output.)

**What this pins down for the skill:** declaring `project.evidence` today is safe at the pinned `0.3.0`,
so a repository can carry it before `nen shu evidence` exists to read it.

---

## 3. Residue

1. **`nen shu evidence --base <ref>`** (§ 2.4, exit `2`). Replaced by
   `git diff --name-status <base>...HEAD` against `project.evidence.globs` — **with `:(glob)` magic, or
   filtered in the reader** — grouped by `project.evidence.scene`'s `{suite}-{scene}` read by eye.
   Landed on nen `main` this week; ships at `0.4.0`.
2. **`nen shu test-report`** — absent at this pin (`docs/ab/tsukuyomi.md` § 2.4). The verdict is the
   runner's own summary, quoted (§ 2.3).
3. **Parsing a declared UI-test artifact** — `.xcresult`, JUnit XML, a Playwright JSON report — has no
   verb. Where the numbers matter, say which file holds them.
4. **`nen/workflow.json` read as data** — no schema row at `v0.3.0`. `iteration.lane` defaults to
   `project.defaultLane`, stated when it applied.
5. **Looking at a re-recorded image** — a boundary, not a gap; see § 4.3.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — A declared glob is not a git pathspec, and the mismatch is silent

§ 2.4 is the whole finding. `project.evidence.globs` is written in shell-glob terms, where `**` crosses
directory separators. Git's **default** pathspec matcher treats `*` as already crossing separators and
does *not* give `**` the meaning the declaration intends, so the declared string matched nothing — at
**exit `0`, with no warning, against a tree containing three matches.**

**This is the worst failure shape available here.** An empty evidence table is indistinguishable from
the truthful "this change re-recorded nothing", so the pull request loses its `UZF-26` evidence and
every downstream reader — [`rikugan`](../../claude/skills/rikugan/SKILL.md)'s screenshot section,
[`shibari`](../../claude/skills/shibari/SKILL.md)'s body, [`hisoka`](../../claude/agents/hisoka.md)'s
read — is told a falsehood by omission rather than shown an error.

Two consequences, both recorded in the skill:

- **For the residue path today:** `:(glob)` on every declared glob, or filter the full
  `git diff --name-status` output in the reader (which is what `rikugan` § 3's own residue row does, and
  which is the form to prefer because it has no matcher to get wrong).
- **For `nen shu evidence` when it lands:** this is a **contract question the verb must answer
  explicitly** — in which dialect is `project.evidence.globs` written, and does the implementation
  translate or delegate? A verb that hands the declared string to `git diff --` unchanged inherits this
  bug and makes it nen's. **Check it the day the pin moves**, the same way `rikugan` § 4 asks the nested
  `{{#each}}` and the default escaping to be checked when `nen report render` arrives. Worth one line in
  nen's own `USAGE.md` either way, because "glob" is a word two tools mean differently.

### 4.2 — The `shu` family refuses on the **option**, which hides whether a subcommand exists

Both § 2.4's probe and `docs/ab/murasaki.md` § 2.2's got the same shape of answer: *"unknown option
'--base'"* / *"unknown option '--no-push'"*, listing the whole family's option surface. It is a good
refusal — it names what *is* available — but it answers a different question than the one asked, and a
caller cannot tell *"this verb does not exist"* from *"this verb exists and does not take that flag"*
without a second probe against `--help`'s verb list.

Not a defect: `nen shu --help` does enumerate the thirteen verbs, so the answer is available, and
`docs/ab/aka.md` § 2.3 records the identical shape on `nen wc` and reads it correctly. Recorded so that
the reading is written down once: **the option-level refusal is not evidence about the subcommand**, and
this record's § 2.4 confirms `evidence`'s absence against the verb list rather than against the flag
error.

### 4.3 — Not a finding: no verb will ever look at a golden, and that must be said rather than skipped

§ 6 of the skill turns on a person looking at every re-recorded image. There is no verb for it, there is
no residue command that substitutes for it, and there will not be one — the same class of boundary
`rikugan` § Residue 7 names for the Artifact publish and `ren` § 4 names for the turn loop.

What matters is the failure mode: on a surface that cannot display an image, the honest report is
**"the goldens were not looked at"**, enumerated. `hisoka`'s own `unread` marker exists for exactly this
(*"`unread` is never rendered as clean — an undeclared skip is how a check quietly stops happening"*),
and kotoamatsukami borrows the discipline rather than the marker.

### 4.4 — Not a finding: `nen shu ui-test` is a complete verb, and its exit codes carry the whole policy

§ 2.2 and § 2.3: the dry run prints the argv, cwd, env names and declared artifacts and spawns nothing;
a real run relays the runner's own output and puts the runner's code in `steps[].exitCode`; a seat is
exit `4` with the declaration's sentence and no document; the family's five codes already distinguish
*the suite failed* (`1`), *the declaration is wrong* (`2`), *this host cannot* (`3`), *this lane declares
a seat* (`4`) and *the runner is not installed* (`5`).

**Nothing about the run half is missing.** Which of those five is a G5 and which is a fix is policy, and
policy is the skill's. Noted as the counter-example to § 4.1: where nen owns a step it owns it
completely, and the gap is precisely and only at the images.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| the evidence enumeration, `git diff` + `:(glob)` by hand | `nen shu evidence --repo <fixture> --base main` | `0` |
| `project.evidence` preserved and unread | `nen schema check --repo <fixture>` → `ok nen/contract.json project (…)`, block parsed | row `ok` |

```
$ nen shu evidence --repo <fixture> --base main
evidence: 1 changed file across 1 suite (public-mirror), against main...HEAD

suite: __Snapshots__
  added    Settings                 src/__Snapshots__/test_snapshot_Settings.png
exit=0
```

The fixture declares `globs: ["**/__Snapshots__/**/*.png"]`, `mechanism: "public-mirror"` and
`scene: "{suite}-{scene}"`, and the branch adds one snapshot over `main`. **The verb carries its own
dependency-free glob matcher**, in which `**` matches zero directories on either side — which is exactly
the trap § 2.4 recorded against a bare git pathspec, closed at the source rather than worked around. From
this release the block KEY is also guarded against a near-miss (`evidences`, `Evidence`, `evidenc`),
refused by pointer instead of preserved and read by nobody.
