# Evidence — `kamui` (new composite, zheref/hatsu#146)

`claude/skills/kamui/SKILL.md`: the clean-worktree build-and-send — fetch, one idempotent detached
worktree at `origin/<branch.base>`, the maintainer's own gitignored files copied from the core
checkout, `susanoo` then `kagutsuchi` **there**, on the maintainer's typed `hatsu:kamui [<target>]`.

**Not a port.** What it replaces is the assumption that the archive sitting in a checkout is a build
of that checkout. The evidence that started it (HA-IS-#146, 2026-09-29): a `hatsu:kagutsuchi
testflight` from a fresh KroApple worktree found no archive there and one in core — identity
`v1.0.0+1251`, built 2026-09-20 from `6589c870`, **95 commits behind `origin/main`**, core dirty on
22 paths — and every plan row read `ok`.

**Run:** 2026-09-30 (local clock, the night of 2026-09-29), `nen 0.16.0` bound by `ten` § 2 at the
pinned build; host `Darwin 27.0.0 arm64`. Hatsu at `fable/kurapika/kamui-fresh-send` off
`origin/main` `5df0bc37`. The hermetic half ran against the scripts' own `--self-test` fixtures; the
live half against **zheref/KroApple**'s real core checkout at `/Users/zheref/Code/Apple/KroApple`
(dirty, on `opus/do-ui-revisit`, exactly as the maintainer left it — nothing there was touched but
the gitignored `.nen/worktrees/kamui` the script owns). **No archive was built and nothing was sent:**
every `nen shu` line below is a `--dry-run`.

*Paths are real: both repositories are the maintainer's own and this record is theirs.*

---

## 1. The skill

| Step | Mechanism | Owner |
|---|---|---|
| 1 | The maintainer types `hatsu:kamui [<target>]` | **the human call** — kagutsuchi § 1's authorization, carried whole |
| 2 | Resolve the target: typed, or `nen/workflow.json` → `deploy.defaultTarget` | the skill, as data (kagutsuchi § 1) |
| 3 | Resolve core — `nen wc worktrees --repo <any> --json` → `core`; refuse an active swap | verb (`wc worktrees`, `wc swap --status`) |
| 4 | Fetch; one detached worktree at `<core>/.nen/worktrees/kamui` at `origin/<base>`, created / reused / moved, dirty refused | **`scripts/kamui_worktree.sh`** — residue: nen has no worktree verb |
| 5 | Copy every `project.fromCore[].path` from core, each proven untracked, gitignored, present, not a symlink | the same script |
| 6 | Archive — `nen shu archive --repo <worktree>` (`susanoo`, its `## 0.` skipped) | verb |
| 7 | Plan, freshness gate, send — `kagutsuchi` in the worktree | verb + `scripts/send_freshness_check.sh` |
| 8 | Report: core, tip, worktree state, each copied path, both blocks, the call quoted | the skill |

**Count.** Eight steps; **three are verbs**, two are one script named as residue, one is the human
call, two are the skill's own reads. The ratio is honest: nen reads worktrees and never writes one.

## 2. The hermetic half — `scripts/kamui_worktree.sh --self-test`, exit `0`, 40 assertions

```
$ nen shu test --repo <hatsu> --lane kamui-guard
kamui_worktree.sh --self-test
  ok    --repo with no value is refused (exit 2)
  ok    --dry-run on a fresh core prints the plan and creates nothing (exit 0)
  ok    and the worktree does not exist after the dry run
  ok    a fresh core gets one worktree at origin/main's tip with the declared file copied (exit 0)
  ok    and says created
  ok    and names the copied path
  ok    and the worktree is clean after the copy (the path is ignored)
  ok    a second run at the same tip reuses the worktree (exit 0)
  ok    and there is still exactly one kamui worktree beside core
  ok    invoked from the worktree, core is resolved and the run is a no-op (exit 0)
  ok    when origin/main moves, a clean worktree is moved to the new tip (exit 0)
  ok    a dirty kamui worktree is refused with its paths, never discarded (exit 2)
  ok    a fromCore path that is tracked is refused (exit 2)
  ok    a fromCore path that is not gitignored is refused (exit 2)
  ok    a fromCore path absent in core is refused: nothing is synthesised (exit 2)
  ok    a fromCore path that leaves the tree is refused (exit 2)
  ok    a symlinked fromCore source is refused (exit 2)
  ok    no fromCore block copies nothing and says so (exit 0)
  ok    a directory at the fixed path that is not a worktree is refused (exit 2)
  ok    a registered worktree whose directory vanished is pruned and re-created (exit 0)
kamui_worktree.sh --self-test: all assertions held; nothing left this machine.
ran:           sh scripts/kamui_worktree.sh --self-test  -- exit 0 in 2207ms
```

(Abridged to one line per case; the fixture prints 40.) The fixture is a bare `origin.git` plus a
`core` clone declaring `project.fromCore: [{ "path": "Kro/Config.xcconfig", … }]` and ignoring it,
so the fetch in step 4 is real and offline.

## 3. The live half — zheref/KroApple

### 3.1 — core resolves through the verb; no swap is active

```
$ nen wc worktrees --repo /Users/zheref/Code/Apple/KroApple --json
core: /Users/zheref/Code/Apple/KroApple   swap: null
```

### 3.2 — the plan, then the creation, then the idempotent re-run

```
$ scripts/kamui_worktree.sh --repo /Users/zheref/Code/Apple/KroApple --dry-run
core:            /Users/zheref/Code/Apple/KroApple
origin/main:   dfce334ea31296b803b4c2fbcb5c501237840b5f (as last fetched; --dry-run fetches nothing)
worktree:        /Users/zheref/Code/Apple/KroApple/.nen/worktrees/kamui (would create)
head:            dfce334ea31296b803b4c2fbcb5c501237840b5f
copied:          none declared (nen/contract.json -> project.fromCore)
exit=0

$ scripts/kamui_worktree.sh --repo /Users/zheref/Code/Apple/KroApple
core:            /Users/zheref/Code/Apple/KroApple
origin/main:   dfce334ea31296b803b4c2fbcb5c501237840b5f
worktree:        /Users/zheref/Code/Apple/KroApple/.nen/worktrees/kamui (created)
head:            dfce334ea31296b803b4c2fbcb5c501237840b5f
copied:          none declared (nen/contract.json -> project.fromCore)
exit=0

$ scripts/kamui_worktree.sh --repo /Users/zheref/Code/Apple/KroApple
…
worktree:        /Users/zheref/Code/Apple/KroApple/.nen/worktrees/kamui (reused)
exit=0
```

**Steps 1 and 2 collapsed and idempotent, live**: one worktree, detached at the tip the fetch
returned, the second run a no-op. Core's own dirty tree (22 paths, `opus/do-ui-revisit`) was never
read as an obstacle — the worktree is cut from `origin/main`, not from core's HEAD — and never
touched. The worktree was clean after both runs (`git status --porcelain` empty).

### 3.3 — the archive's plan in the worktree, and the finding it produces

```
$ nen shu archive --repo /Users/zheref/Code/Apple/KroApple/.nen/worktrees/kamui --dry-run
lane:          apple  (xcode-ios)
verb:          archive
host:          darwin -- supported (declared: darwin)
preconditions:
  FAIL  path Kro/Config.xcconfig -- not present
would run:     rm -rf .nen/archive .nen/export
would run:     bash ci_scripts/nen_archive.sh
cwd:           /Users/zheref/Code/Apple/KroApple/.nen/worktrees/kamui
artifacts:     .nen/export/Kro.ipa (absent)
```

**This is the `missing-configuration` ask kamui § 2 describes, seen live**: the precondition FAILs in
the worktree on a path that exists, gitignored, in core (`/Kro/Config.xcconfig` in KroApple's
`.gitignore`; the file is there, 674 bytes, 2026-09-16), and **KroApple declares no
`project.fromCore` yet**. The composite copies only what the declaration names — *"ALWAYS copy own
file from core checkout"* is honoured by declaring which file — so the row KroApple owes, through its
own declaration PR at **G2** (a consumer), is:

```json
"fromCore": [
  { "path": "Kro/Config.xcconfig",
    "why": "The gitignored base configuration carrying SUPABASE_URL and SUPABASE_ANON_KEY -- the same file project.preconditions asserts on every Apple lane. It exists only in the maintainer's core checkout (CI recreates it from secrets); kamui copies it from there into its worktree so the archive's precondition holds, and synthesises nothing." }
]
```

**Not written by this run**: a write to another repository's tracked declaration needs the
maintainer's answer ([`WORKFLOW.md`](../WORKFLOW.md) § 4 *Ask, set up, continue*, step 3), and this
session was headless. With that row landed, the self-test's copy case (§ 2) is the live shape: the
worktree stays clean because the path is ignored, and the precondition row reads `ok`.

### 3.4 — the deploy plan in the worktree

```
$ nen shu deploy --repo /Users/zheref/Code/Apple/KroApple/.nen/worktrees/kamui --target testflight --dry-run
target:        testflight  (appends no argument)  requires env: ASC_ISSUER_ID, ASC_KEY_ID, ASC_PRIVATE_KEY_PATH
preconditions:
  FAIL  path Kro/Config.xcconfig -- not present
  FAIL  env  ASC_ISSUER_ID -- not set in this environment
  FAIL  env  ASC_KEY_ID -- not set in this environment
  FAIL  env  ASC_PRIVATE_KEY_PATH -- not set in this environment
would run:     bash ci_scripts/nen_testflight_upload.sh
```

The three `env` rows are the maintainer's own shell (unset in this headless session, exactly as in
the issue's evidence); the `path` row is § 3.3's declaration. **The acceptance criterion's
"every row `ok`" is therefore reached on the maintainer's machine once KroApple's `fromCore` row
lands and the App Store Connect variables are exported** — both are theirs to set, and neither is a
gap in the composite: the plan named each one by name.

### 3.5 — what kagutsuchi § 3a would have said in the worktree

No archive ran (§ 3.3), so `nameFrom` is absent there; the gate refuses *"no archive has run in this
checkout"* at exit `2` — the correct answer for a worktree nothing built in. The gate's own live runs
are in [`kagutsuchi.md`](kagutsuchi.md) § *Dated 2026-09-30*.

## 4. Residue

1. **nen has no worktree verb.** `git worktree add --detach`, `git checkout --detach`,
   `git worktree prune`, `git check-ignore` and `cp -p` are the script's raw calls; core is resolved
   the way `nen wc worktrees` resolves it (`git rev-parse --path-format=absolute --git-common-dir`),
   and the verb's own row is what the report quotes. An owned dependency for nen.
2. **`project.fromCore` is Hatsu's block.** nen's loader preserves it (verified: `nen schema check`
   and `nen shu lint --dry-run` both accept a contract carrying it) and reads it by nothing; the
   precondition assertion in the worktree is still nen's.
3. **The per-stack `deploy.defaultTarget` in `nen shu detect`'s reference pack** is nen's to add.
4. **The worktree lives under core's gitignored `.nen/`.** A consumer whose `.gitignore` does not
   ignore `.nen/` would show it as untracked; reported, never added to `.gitignore` by this skill.

## 5. Findings

1. **KroApple owes a `project.fromCore` row** (§ 3.3) — a declaration PR at G2 there. Pending until
   the maintainer answers; the composite's report names it on every run until then.
2. **The dry run's tip is "as last fetched"** — deliberate, so the plan mutates nothing, and said on
   the line. A stale `origin/<base>` in core reads stale in the plan and fresh in the bare run.
3. **No missing verb beyond residue 1.** Every other deterministic step is a verb or the human call.
