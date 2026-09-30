# Evidence — `kagutsuchi` (new skill, Hatsu workflow fold-in)

`claude/skills/kagutsuchi/SKILL.md`: the non-production upload — one declared destination, one
maintainer call naming it, `nen shu deploy --target <name> --run`. The plan is printed always; the
send happens only on the call.

**Not a port.** There is no retired skill behind it. What it replaces is the assumption that a green
build and a declared target together add up to permission. § 2 records what each step is at nen
`0.3.0`, live, with exit codes — including the **order** in which the verb refuses, which decides
what a mistyped line is told.

**Run:** 2026-09-10 (local clock), `nen 0.3.0` at `/Users/zheref/.local/bin/nen`; host
`Darwin 25.4.0 arm64`, `node v24.16.0`. Hatsu at `2e066ab` (`origin/fable/kurapika/wave-3`). Verbs
were exercised against a **constructed** throwaway fixture under this worktree's `.nen-fixture/` —
lane `app` with a single-step `deploy` row, lane `docs` seating `deploy` in its own words, and three
targets covering the three shapes nen's own docs name from the field (`staging`: a destination that
differs by a flag; `production`: the same plus a `requiresEnv`; `on-push`: a destination with **no
command line at all**) — **deleted before the commit**. The one `--run` in this record was fired at
the fixture's `staging` target, whose declared command is a `node -e` that prints a line. **No real
destination was contacted, and no mutating verb was run against any primary checkout.**

*Paths sanitized: this machine's absolute paths appear as `<fixture>`. Nothing is redacted — both
repositories are public — and the transcripts are otherwise verbatim.*

---

## 1. The skill

| Step | Mechanism | Owner |
|---|---|---|
| 1 | The maintainer names the target | **the human call** — the grammar's required argument, and the authorization |
| 2 | Print the fully resolved plan — `nen shu deploy --target <name> --dry-run` | verb |
| 3 | Send it — the same line with `--run` | verb |
| 4 | React to `0`/`1`/`2`/`3`/`4`/`5`, in nen's refusal order | the skill's table, from `claude/agents/kurapika.md` § *The `shu` verbs* |
| 5 | Refuse to choose a target, ever | verb (exit `2`, no default) **and** the skill |
| 6 | Assert the target's credentials without reading them | verb (`requiresEnv`) |
| 7 | Decide the destination is non-production | **the skill**, off `targets.<name>.why` — no field says so (§ 3) |
| 8 | Record the maintainer's go | **the skill**, quoted verbatim — nothing in nen records one (§ 3) |

**Count.** Eight steps; **five are verbs**, one is the human call itself, two are named residue.

## 2. Verbs exercised live

### 2.1 — the plan: `--dry-run`, exit `0`, nothing sent

```
$ nen shu deploy --repo <fixture> --target staging --dry-run
lane:          app  (nextjs)
verb:          deploy
target:        staging  (appends: --env staging)
host:          darwin -- supported (declared: darwin, linux, win32)
preconditions:
  ok    path signing/identity.p12
would run:     node -e 'console.log('\''sent: '\'' + process.argv.slice(1).join('\'' '\''))' publish --dir dist --env staging
cwd:           <fixture>
env:           (none added)
artifacts:     (none declared)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit code to report.
exit=0
```

The `target:` line is the half a reader needs and the one no other verb in the family prints: the
destination's name, and **which arguments came from it** rather than from the lane's own row.

### 2.2 — the bare form is the same report, plus one sentence

```
$ nen shu deploy --repo <fixture> --target staging
… identical report, byte for byte …
nothing was sent: 'deploy' acts only with --run. The plan above is fully resolved -- the destination substituted into the argv, every precondition asserted -- and no process was started. Re-run the same line with --run to send it.
exit=0
```

Both are exit `0`. **The skill writes `--dry-run` anyway** (its § 3): the two forms differ by a line
on stderr that a transcript pasted into a report may not carry, and a reader who cannot see whether
`--run` was on the line cannot tell a plan from a send. The explicit spelling costs nothing and
removes that reading.

### 2.3 — the refusals about the command line: exit `2`, three shapes

```
$ nen shu deploy --repo <fixture> --target staging --run --dry-run
nen shu: 'deploy' was given both --run and --dry-run. --run sends the build; --dry-run sends nothing and prints what would have been sent. Nen will not pick one of two contradicting instructions on the one verb whose blast radius is other people's users. Drop --run to see the plan (that is what this verb does without it, and --dry-run is its explicit spelling), or drop --dry-run to send it.
exit=2

$ nen shu deploy --repo <fixture>
nen shu: 'deploy' on lane 'app' (nextjs) needs --target, and there is no default -- not even when exactly one target is declared. nen never chooses where a build goes. Declared under project.targets: on-push, production, staging.
exit=2

$ nen shu deploy --repo <fixture> --target beta
nen shu: --target 'beta' is not declared under project.targets. Declared: on-push, production, staging.
exit=2
```

*"nen never chooses where a build goes"* is the binary's own sentence, and the skill's § 1 takes the
stronger version of it: **nor does this skill**, because the target the maintainer typed *is* the
authorization, so a target nobody typed has nothing to inherit.

### 2.4 — `requiresEnv` unsatisfied: exit `2`, **with** the report, and no value anywhere

```
$ env -u FIXTURE_DEPLOY_TOKEN nen shu deploy --repo <fixture> --target production
lane:          app  (nextjs)
verb:          deploy
target:        production  (appends: --env production)  requires env: FIXTURE_DEPLOY_TOKEN
host:          darwin -- supported (declared: darwin, linux, win32)
preconditions:
  ok    path signing/identity.p12
  FAIL  env  FIXTURE_DEPLOY_TOKEN -- not set in this environment
would run:     node -e '…' publish --dir dist --env production
cwd:           <fixture>
env:           (none added)
artifacts:     (none declared)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit code to report.
1 precondition on lane 'app' is not satisfied. nen ASSERTS a precondition and never performs it: satisfy it with this repository's own tooling, then run this again.
exit=2
```

and the `--json` head of the same line, showing where the destination is recorded:

```json
{
  "contract": "nen.shu.deploy/v0.1",
  "lane": "app", "stack": "nextjs", "verb": "deploy",
  "target": { "name": "production", "args": ["--env", "production"],
              "requiresEnv": ["FIXTURE_DEPLOY_TOKEN"] },
  …
}
```

**A name, never a value** — in the text report, in the document, in the refusal. This is the one
refusal in the family that prints a document rather than a bare stderr line, and deliberately: a
caller debugging *why this will not run* needs the table more here than anywhere.

### 2.5 — the two seats, and the order that decides which one a mistyped line gets

A destination that has no command line at all:

```
$ nen shu deploy --repo <fixture> --target on-push
nen shu deploy: target 'on-push' has no command line at all, so there is nothing for nen to run on lane 'app' (nextjs). The declaration's own reason: the push to main IS the deploy, through the host's own integration. There is no command line for nen to run.
exit=4
```

and a lane that declares no `deploy` — asked with a target that **does not exist**:

```
$ nen shu deploy --repo <fixture> --lane docs --target beta
nen shu deploy: 'deploy' is unsupported on lane 'docs' (nextjs). The declaration's own reason: The docs lane sends nothing anywhere: the push to main IS the deploy, through the host's own integration. There is no command line for nen to run.
exit=4
```

**The seat wins over the mistyped target**, live — the same line on the `app` lane answered
`--target 'beta' is not declared` at exit `2` in § 2.3. That ordering is documented in nen's own
USAGE (the destination is resolved *after* the lane, verb, host and placeholders) and it is the right
trade: sending someone to write a `targets` block on a lane that will never deploy is worse than
costing them a retype. The skill's § 5 states it so a reader is not surprised that a mistyped target
is invisible on a seated lane.

### 2.6 — the send: `--run`, exit `0`, exactly the plan

```
$ nen shu deploy --repo <fixture> --target staging --run
sent: publish --dir dist --env staging
lane:          app  (nextjs)
verb:          deploy
target:        staging  (appends: --env staging)
host:          darwin -- supported (declared: darwin, linux, win32)
preconditions:
  ok    path signing/identity.p12
ran:           node -e '…' publish --dir dist --env staging  -- exit 0 in 22ms
cwd:           <fixture>
env:           (none added)
artifacts:     (none declared)
log:           not captured to a file -- each step's own stdout and stderr were relayed as it finished. A .nen/logs/ transcript is not in this release (zheref/nen#91).
exit=0
```

**The `ran:` line and § 2.1's `would run:` line are the same rendering** — which is what makes
printing the plan first worth doing, and what lets the skill promise that what was sent is what was
shown.

## 3. Residue

1. **Nothing marks a target as production.** A target row carries `args`, `requiresEnv`, `why` and
   `unsupported`, and no field states which side of **G3** a destination sits on. The skill reads it
   out of the `why` prose by hand and refuses a target that carries no `why` at all, because
   *"this is not production"* is a claim and an unstated claim is not one anybody made.
2. **Nothing checks a target against the lane it is used on.** Project-level targets are a deliberate
   choice in nen (a per-target `targets.<name>.lanes` allowlist is named as the follow-up if the
   shape turns out to be common). Until then the guard is reading the composed `would run:` in the
   plan, by hand.
3. **What state a failed deploy left the destination in.** Exit `1` reports the tool's own code and
   nothing about the far end; nen never queries a destination. *"I do not know what state the
   destination is in"* is the honest sentence, and it is by hand.
4. **A record of the go.** Nothing in nen records that a maintainer authorised a target.
   `nen stop --notified` writes `.nen/last-stop.json` for the bell and is not that record. The call
   is quoted verbatim in the report, by hand.
5. **A per-run log file.** `A .nen/logs/ transcript is not in this release (zheref/nen#91)` —
   verified live in § 2.6.

## 4. Findings against the binary

1. **A destination cannot declare that it is production.** `project.targets.<name>` has no field for
   it, so the one distinction the whole G3 boundary turns on lives in free prose (`why`) or nowhere.
   A `"production": true` (or a `gate: "G3"`) on the target row would let a verb refuse what a skill
   currently has to refuse by reading a sentence. **This is the finding worth acting on**, and the
   skill's § 2 and `hatsu:mugetsu` both compensate for it by hand today. Recorded, not filed.
2. **The bare form and `--dry-run` are indistinguishable in a pasted transcript** (§ 2.2). The
   difference is one stderr line, and stderr is exactly what gets lost when a report quotes a
   command's output. A `mode: plan|sent` line inside the report body — where `log:` already lives —
   would make a copied transcript self-describing. Recorded, not filed.
3. **The seat/target refusal order is correct and surprising** (§ 2.5). A mistyped `--target` is
   invisible on a seated lane. nen's own USAGE argues the trade and the skill restates it; noted here
   because a reader debugging a typo will otherwise conclude the flag was ignored.
4. **The `requiresEnv` row prints a name and never a value**, in text and in `--json` (§ 2.4) —
   verified, and worth recording as a property that held rather than only as a claim in the docs.
5. **No missing verb.** Every deterministic step of the upload phase that is not in § 3 is a verb,
   exercised live above with its exit code.

---

## Dated 2026-09-30 — the freshness gate (zheref/hatsu#146)

**Run:** `nen 0.16.0`, host `Darwin 27.0.0 arm64`, Hatsu at `fable/kurapika/kamui-fresh-send` off
`origin/main` `5df0bc37`. `claude/skills/kagutsuchi/SKILL.md` § 3a now runs
`scripts/send_freshness_check.sh --repo <path>` after the plan and before `--run`. Nothing was sent.

### The hermetic half — `--self-test`, exit `0`, 33 assertions (lane `freshness-guard`)

A bare `origin.git` plus a `core` clone whose `dist/identity.txt` (line 2) records the commit the
archive "ran" at, so the fetch in check 4 is real and offline. Every refusal the gate exists to make
is proven: a dirty tree before the send; an absent, symlinked, SHA-less or non-hex `nameFrom`; a
build SHA that is not `HEAD` (both named); one at `HEAD` behind `origin/main` (both named, the
distance counted); a `--base` origin does not carry; and the two verdicts that are not refusals —
`fresh`, and exit `3` `unverified` where no `tags.identity` is declared.

### The live half — zheref/KroApple, exactly as the maintainer left it

```
$ scripts/send_freshness_check.sh --repo /Users/zheref/Code/Apple/KroApple
send_freshness_check.sh: the working tree is dirty -- refused before the send, not at the tag:
     M Kro.xcodeproj/project.pbxproj
     M Kro.xcodeproj/xcshareddata/xcschemes/PreviewHost.xcscheme
     M KroTests/Application/Do/DoDayContextSnapshotTests.swift
     … (22 paths)
exit=2
```

**This is the issue's core checkout** — the one whose `v1.0.0+1251` archive, built from `6589c870`,
would have gone to TestFlight on 2026-09-29 with every plan row `ok`. The gate refuses it on the
first check, before the archive's commit is even read.

```
$ scripts/send_freshness_check.sh --repo /Users/zheref/Code/Apple/KroApple/.claude/worktrees/hatsu-ao-kagu-b49b3f
send_freshness_check.sh: the archive was built from dd490bed6a946be31484b1c8f81647f3728716f2, which is
not the tip of origin/main (dfce334ea31296b803b4c2fbcb5c501237840b5f; 8 commit(s) behind) -- refused;
catch the checkout up, re-run the archive, then send
exit=2
```

**The worktree the maintainer cut at `main`'s tip on 2026-09-29** — clean, with an archive built from
its own `HEAD` (`dd490bed`) — and the trunk has moved 8 commits since. Check 3 passed (built ==
`HEAD`); check 4 refused after the fetch, both SHAs and the distance named. This is the case the
issue's *"Why it matters"* describes: a build that reaches testers matches a known commit **at the
trunk's tip**, and a day-old tip is not it.

### What changed in the skill, and what did not

`--target` is now typed **or** `nen/workflow.json` → `deploy.defaultTarget` (§ 1; the report says
which); `nen shu deploy` is unchanged and still receives `--target` explicitly. § 3a is a script,
not a verb — named as residue in [`docs/PROCESS.md`](../PROCESS.md) § *Residue and owned
dependencies*. § 2.3's *"nen never chooses where a build goes"* is still nen's own sentence, and
still true: the choice moved into configuration the maintainer wrote, not into the binary.

### § 3b, live — the clean worktree the rebuild runs in (`scripts/kagutsuchi_worktree.sh`)

**Hermetic half**: `nen shu test --repo <hatsu> --lane fresh-worktree-guard` → `all assertions held;
nothing left this machine.`, 58 `ok` lines: the dry run creates nothing; a first run creates one detached
worktree at `origin/main`'s tip and copies the declared gitignored file from core; a second run reuses it;
a moved trunk moves a clean worktree; a dirty one is refused and never discarded; a tracked, unignored,
absent, escaping, symlinked, glob-shaped or whitespace-bearing `fromCore` path is refused; **at the tip**,
a tracked parent symlink, a tracked leaf symlink, a tracked regular file and an untracked symlink at the
destination are each refused with the outside file untouched (Feitan's round, 2026-09-30); a stray
directory beside a sibling `kagutsuchi2` registration is refused with core's `HEAD` and branch unmoved;
a symlinked `.nen/worktrees` is refused; a vanished registration is dropped and re-created.

**Live half, zheref/KroApple** (core at `/Users/zheref/Code/Apple/KroApple`, dirty on 22 paths on
`opus/do-ui-revisit`, exactly as the maintainer left it; nothing touched but the gitignored
`.nen/worktrees/` the script owns; every `nen shu` line a `--dry-run`, nothing built, nothing sent):

```
$ nen wc worktrees --repo /Users/zheref/Code/Apple/KroApple --json   → core: /Users/zheref/Code/Apple/KroApple, swap: null
$ scripts/kagutsuchi_worktree.sh --repo /Users/zheref/Code/Apple/KroApple --dry-run
origin/main:   dfce334ea31296b803b4c2fbcb5c501237840b5f (as last fetched; --dry-run fetches nothing)
worktree:        …/KroApple/.nen/worktrees/<name> (would create)
copied:          none declared (nen/contract.json -> project.fromCore)
$ scripts/kagutsuchi_worktree.sh --repo /Users/zheref/Code/Apple/KroApple          → (created), head dfce334e
$ scripts/kagutsuchi_worktree.sh --repo /Users/zheref/Code/Apple/KroApple          → (reused)
$ nen shu archive --repo <worktree> --dry-run
preconditions:
  FAIL  path Kro/Config.xcconfig -- not present
artifacts:     .nen/export/Kro.ipa (absent)
```

(The run predates the rename: the worktree was created as `.nen/worktrees/kamui`; the script now names
`.nen/worktrees/kagutsuchi`, and the earlier directory is the maintainer's to remove with `git -C
<core> worktree remove --force .nen/worktrees/kamui`.) **Steps 1 and 2 collapsed and idempotent, live**;
core's dirty tree was never an obstacle, since the worktree is cut from `origin/main`. **The archive
precondition FAILs in the worktree on a path that exists gitignored in core** — KroApple declares no
`project.fromCore` yet, and the composite copies only what a declaration names. That is the
`missing-configuration` ask kagutsuchi § 2 describes, and the row KroApple owes, through its own
declaration PR at **G2**:

```json
"fromCore": [ { "path": "Kro/Config.xcconfig",
  "why": "The gitignored base configuration carrying SUPABASE_URL and SUPABASE_ANON_KEY -- the file project.preconditions asserts on every Apple lane. It exists only in the maintainer's core checkout (CI recreates it from secrets); kagutsuchi § 3b copies it from there into its worktree so the fresh archive's precondition holds, and synthesises nothing." } ]
```

Not written by this run: a write to another repository's tracked declaration needs the maintainer's
answer (`WORKFLOW.md` § 4 *Ask, set up, continue*, step 3). With that row landed, the self-test's copy
case is the live shape, and the three App Store Connect `requiresEnv` rows are the maintainer's shell.

**Residue for § 3b**: nen has no worktree verb — `git worktree add|remove --force`, `git checkout
--detach`, `git check-ignore`, `mktemp`, `cp -p`, `mv -f` are the script's raw calls; `project.fromCore`
is Hatsu's block, preserved by nen's loader and read by nothing in nen; the per-stack
`deploy.defaultTarget` in `nen shu detect`'s reference pack is nen's to add.
