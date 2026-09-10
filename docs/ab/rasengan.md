# Evidence — `rasengan` (new skill, Hatsu workflow fold-in)

`claude/skills/rasengan/SKILL.md`: the iteration checks — every verb `nen/workflow.json` lists under
`iteration.checks`, run through the target repository's own declaration, with one stated reaction per
exit code.

**Not a port.** There is no retired skill behind it; what it replaces is the habit of typing a build
command from memory between edits. § 2 records what each step is at nen `0.3.0`, live, with exit
codes.

**Run:** 2026-09-09/10 (local clock; the session crossed midnight), `nen 0.3.0` at `/Users/zheref/.local/bin/nen`; host `Darwin 25.4.0 arm64`,
`node v24.16.0`. Hatsu at `origin/main` `e158349`. Verbs were exercised against a **constructed**
throwaway git repository under this worktree's `.nen-fixture/` — one `nextjs` lane declaring `build`,
`test` and `dev` rows, a `lint` **seat**, one `toolchain` entry, and a `build` row deliberately
flipped red for § 2.2 — deleted before the commit; and read-only, `--dry-run` only, against the
`zheref/nen` checkout at `8a12b2c`, which declares nothing. No mutating verb was run against any
primary checkout.

*Paths sanitized: this machine's absolute paths appear as `<fixture>` and `<nen checkout>`. Nothing
is redacted — both repositories are public — and the transcripts are otherwise verbatim.*

---

## 1. The skill

| Step | Mechanism | Owner |
|---|---|---|
| 1 | Read `iteration.checks`, `iteration.lane` from `nen/workflow.json` | the skill, as data (§ 3) |
| 2 | Show what will run before it runs — `nen shu <check> --dry-run` | verb |
| 3 | Run each declared check — `nen shu build\|test\|lint\|ui-test [--lane]` | verb |
| 4 | React to `0`/`1`/`2`/`3`/`4`/`5` | the skill's table, from `claude/agents/kurapika.md` § *The `shu` verbs* |
| 5 | A host that cannot build → G5; a missing program → `nen shu tools` | verb + gate |
| 6 | Read the no-declaration fact | off `build`/`test`/`lint`, **never** off `detect` (§ 2.4–2.6) |
| 7 | Build proof, stall guard | residue — neither exists at this pin (§ 3) |

**Count.** Seven steps; **five are verbs**, two are named residue.

## 2. Verbs exercised live

### 2.1 — `nen shu build`, the dry run and the green run

```
$ nen shu build --repo <fixture> --dry-run
lane:          app  (nextjs)
verb:          build
host:          darwin -- supported (the declaration constrains no platform)
preconditions: (none declared)
would run:     node -e 'console.log('\''build ok'\'')'
cwd:           <fixture>
env:           (none added)
artifacts:     dist/app.js (absent)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit
               code to report.
exit=0

$ nen shu build --repo <fixture>
build ok
lane:          app  (nextjs)
verb:          build
host:          darwin -- supported (the declaration constrains no platform)
preconditions: (none declared)
ran:           node -e 'console.log('\''build ok'\'')'  -- exit 0 in 30ms
cwd:           <fixture>
env:           (none added)
artifacts:     dist/app.js (absent)
log:           not captured to a file -- each step's own stdout and stderr were relayed as it
               finished. A .nen/logs/ transcript is not in this release (zheref/nen#91).
exit=0
```

The `would run:` line and the `ran:` line are the same rendering — which is what makes the dry run
worth pasting to a human. Note `artifacts: dist/app.js (absent)` on a **passing** build: nen reports
whether a declared artifact exists and never creates one, so "absent" here is a fact about a fixture
whose build prints instead of writing, not a failure signal.

### 2.2 — a red build: nen's `1`, the tool's own code in `steps[]`

The `build` row was flipped to a command that prints a compiler-shaped error and exits `3`:

```
$ nen shu build --repo <fixture>
TS2345: type error in src/app.js
lane:          app  (nextjs)
verb:          build
ran:           node -e 'console.error('\''TS2345: type error in src/app.js'\''); process.exit(3)'  -- exit 3 in 109ms
...
step 1 of 1 failed: node -e '...' -- exited 3. nen exits 1 whatever the tool's own code was; the
tool's code is in the report above.
exit=1
```

and the same run under `--json` (abridged to the load-bearing keys):

```
{
  "contract": "nen.shu.build/v0.1",
  "lane": "app",
  "verb": "build",
  "steps": [ { "exe": "node", "argv": ["-e", "console.error('TS2345: ...'); process.exit(3)"],
               "cwd": "<fixture>", "exitCode": 3, "durationMs": 24 } ],
  "exitCode": 1,
  "artifacts": [ { "kind": "path", "value": "dist/app.js", "exists": false } ],
  "log": { "mode": "streamed", "captured": false, "path": null, "why": "not captured to a file ..." }
}
exit=1
```

**`steps[0].exitCode` is `3` and the document's `exitCode` is `1`.** A skill that reported "the build
exited 3" or "nen exited 3" would be wrong in both directions; rasengan's § 5 says which number is
whose.

### 2.3 — a seat: exit `4`, in the declaration's own words

```
$ nen shu lint --repo <fixture>
nen shu lint: 'lint' is unsupported on lane 'app' (nextjs). The declaration's own reason: this
fixture ships no linter; the lane is a seat on purpose
exit=4
```

and the neighbouring shape — a verb the lane simply never declared:

```
$ nen shu coverage --repo <fixture>
nen shu coverage: lane 'app' (nextjs) declares no 'coverage'. It declares: build, dev, lint, test. A
verb this repository has is a verb this repository states, in nen/contract.json under
project.verbs.app -- nen never substitutes a plausible command for a declared one.
exit=4
```

Both are exit `4`, and the difference between them is worth naming: the first quotes a **reason the
repository wrote**, the second lists what *is* declared. Rasengan's § 5 quotes whichever of the two
it gets, verbatim, and never converts either into "the build failed".

### 2.4 — a repository with no declaration: exit `2` off `shu build`

```
$ nen shu build --repo <nen checkout> --dry-run
nen shu: no such file: <nen checkout>/nen/contract.json. 'nen shu' runs what a repository DECLARES --
lanes, per-verb argv, preconditions -- and this repository declares nothing. Run 'nen shu detect
--repo <nen checkout>' to see a project block proposed from the markers on disk, then write it (or
pass --write) and run this again.
Run 'nen shu --help'.
exit=2
```

### 2.5 — `nen shu detect` on that same repository: exit `1`, a *different* fact

```
$ nen shu detect --repo <nen checkout>
repository:  <nen checkout>
declaration: <nen checkout>/nen/contract.json  (absent)

no lane detected. Nen proposes a lane only from a marker it can see -- a framework config, a
workspace, a wrapper plus its plugin, a project file. ...
exit=1
```

### 2.6 — the case that proves the two must not be conflated

The **fixture** carries a complete, working `project` block — § 2.1 built through it — and `detect`
still answers:

```
$ nen shu detect --repo <fixture>
repository:  <fixture>
declaration: <fixture>/nen/contract.json  (present -- --write will refuse)

no lane detected. Nen proposes a lane only from a marker it can see ...
the scan is bounded, and every bound can hide a real lane: it descends at most 3 directories below
--repo ... so a lane living in a directory named like build output, or one whose application module
sits deeper than 2 directories inside it, is invisible to it by design.
exit=1
```

**`detect` exit `1` on a repository whose `shu build` exits `0`.** A skill that read the
no-declaration fact off `detect` would have called a fully declared, building repository undeclared —
which is exactly the rule `claude/agents/kurapika.md` § *The `shu` verbs* states, here confirmed live
in the direction that actually bites (the agent file's own example runs the other way: an Xcode tree
that `detect` proposes for and `shu build` refuses).

### 2.7 — `nen shu tools`, the pointer for exit `5`

```
$ nen shu tools --repo <fixture>
lane:          app  (nextjs)
mode:          check
  ok       node  24.16.0  pinned >=18.0.0  (tested minimum 20.19.0)
exit=0
```

Exit `5` was not reachable on this host without uninstalling the fixture's only declared tool, so the
`5 → nen shu tools` reaction in the skill's § 5 rests on this verb's own `--help` and on the `0` above
proving the wiring (the toolchain block is read, probed, and reported per tool). Said here rather
than presented as a verified `5`.

## 3. Residue

1. **Build proof.** No `.nen/proof/<lane>.json`, no `nen commit check --require-proof <lane>` at this
   pin. The proof is the transcript in the turn's report — which is precisely why
   `hatsu:kokusen` re-runs this skill before every commit instead of reading a file.
2. **Stall guard.** No per-step `stallTimeoutMs`, no declared `onStall` step. A hung check hangs;
   watching it is the skill's, and running a declared stall procedure is by hand and named.
3. **No log file.** `log: not captured to a file … A .nen/logs/ transcript is not in this release
   (zheref/nen#91)` — verified live in § 2.1 and § 2.2. The turn's report is the only record.
4. **Reading `nen/workflow.json`** — no loader and no `nen schema check` row at `0.3.0`
   (`docs/ab/breath.md` § 2.6).
5. **Counting anything inside a check's output** — warnings, tests, coverage — is not this skill's;
   rasengan reports exit codes and quotes what the tool printed.

## 4. Findings against the binary

1. **`nen shu detect`'s answer is about markers, not declarations, and the two diverge in *both*
   directions** (§ 2.4–2.6). Confirmed live: a declared, building repository reports `no lane
   detected` at exit `1`. The header line does say `declaration: … (present -- --write will refuse)`,
   so the information is there — but the verdict line and the exit code both say the opposite of the
   header. A `detect` that reported "declared, not detected" as its own state would remove a real
   foot-gun. Recorded, not filed.
2. **A red build's two exit codes are easy to cross** (§ 2.2). nen's `1` and the tool's `3` are both
   in the output, and the plain-text tail says which is which — good — but under `--json` a reader
   that pulls the top-level `exitCode` for "what did the build return" gets nen's, not the tool's.
   Not a defect; a naming hazard worth stating in every skill that reads the document.
3. **`artifacts: … (absent)` reads like a failure on a green build** (§ 2.1). It is a report, not a
   verdict — nen never creates an artifact — but the word sits directly under a passing run. Cosmetic;
   recorded because a skill quoting the block to a human should say what it means.
4. **No missing verb.** Every deterministic step of the iteration loop that is not in § 3 is a verb,
   exercised live above with its exit code.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| build proof — no `.nen/proof/<lane>.json` | `nen shu build --repo <fixture> --lane app` | `0`, and the file written |
| no `nen commit check --require-proof` | `nen commit check --repo <fixture> --require-proof app` | `0` |
| the stall guard — no `stallTimeoutMs`, no `onStall` | a declared `stall` block, rendered by the same build | `0` |

```
$ nen shu build --repo <fixture> --lane app
ran:           sh -c 'echo built'  -- exit 0 in 4ms
on stall:      after 60000ms elapsed AND 30000ms with no output: sh -c 'echo kill'  (up to 2 times)
proof:         .nen/proof/app.json  tree c5b7212497b7ba97f127a65af56c29e2ed7a54b4 at 2026-09-10T09:09:52.482Z
exit=0

$ cat <fixture>/.nen/proof/app.json
{ "contract": "nen.shu.proof/v0.1", "lane": "app", "verb": "build",
  "treeHash": "c5b7212497b7ba97f127a65af56c29e2ed7a54b4",
  "at": "2026-09-10T09:09:52.482Z", "exitCode": 0 }

$ nen commit check --repo <fixture> --require-proof app
lane:      app
tree:      c5b7212497b7ba97f127a65af56c29e2ed7a54b4
proof:     .nen/proof/app.json  tree c5b7212497b7ba97f127a65af56c29e2ed7a54b4 at 2026-09-10T09:09:52.482Z
verdict:   OK -- this working copy is the one the build proved green.
exit=0
```

**The two hashes are computed the same way on both sides** — git's tree object for the *working copy*,
through a scratch index under `.nen/` — which is what lets the check run a moment before a commit with
everything staged and still agree.

**Against hatsu's own checkout the pair answers differently, and correctly**: `nen shu build --repo .
--lane plugin` is exit `4` (the lane declares a `build` **seat**) and
`nen commit check --repo . --require-proof plugin` is exit `1` (*"NOT PROVED -- there is no build proof
for lane 'plugin'"*). A lane that declares no build never produces a proof, so kokusen says so and runs
the lane's real checks instead.

**Still residue:** watching a lane that declares **no** `stall` block, and running that declaration's
prose remedy by hand.
