# Evidence — `breath` (new skill, Hatsu workflow fold-in)

`claude/skills/breath/SKILL.md`: the local warm-up taken once per effort — classify the checkout,
check the host toolchain, fast-forward the trunk, cut this effort's branch from its fresh tip, prove
the declared build on it.

**This is not a port.** There is no retired skill behind it and no "old mechanics" column to compare
against: `breath` is phase one of the `ren` composite, and the shape it replaces is the thing every
session used to do by hand at the top of a turn — `git status`, `git fetch`, `git checkout -b`, and a
build command typed from memory. So § 2 records what each step **is** at nen `0.3.0`, live, with exit
codes, rather than an A/B of two mechanisms.

**Run:** 2026-09-09/10 (local clock; the session crossed midnight), `nen 0.3.0` at `/Users/zheref/.local/bin/nen`; host `Darwin 25.4.0 arm64`,
`node v24.16.0`. Hatsu at `origin/main` `e158349`. Verbs were exercised against a **constructed**
throwaway git repository built under this worktree's `.nen-fixture/` (a bare `origin.git` beside a
`repo/` declaring one `nextjs` lane with `build`, `test` and `dev` rows, a `lint` seat and one
`toolchain` entry), deleted before the commit; and, read-only and in `--dry-run` form only, against
the `zheref/nen` checkout at `8a12b2c`, which carries **no `project` declaration** — itself one of
the facts recorded below. No mutating verb was run against any primary checkout.

*Paths sanitized: this machine's absolute paths appear as `<fixture>` (the throwaway repo) and
`<nen checkout>`. Nothing is redacted — `zheref/hatsu` and `zheref/nen` are both public — and the
transcripts are otherwise verbatim.*

---

## 1. The skill

| Step | Mechanism | Owner |
|---|---|---|
| 1 | Read `branch.template`, `branch.base`, `iteration.checks`, `iteration.lane` from `nen/workflow.json` | the skill, as data (§ 3) |
| 2 | Where the checkout sits — `nen wc classify --repo --base` | verb |
| 3 | The host toolchain — `nen shu tools --repo [--dry-run] [--install]` | verb |
| 4 | Render `{model}/{persona}/{descriptor}` into a branch name | the skill (§ 3) |
| 5 | Fetch, fast-forward, cut, prove — `nen shu warmup --repo --branch [--from] [--tests]`, `--dry-run` first | verb |
| 6 | Anything in `iteration.checks` beyond `build` | handed to `hatsu:rasengan` |
| 7 | Carrying a dirty trunk onto the new branch | residue — `git stash` / `stash pop`, named (§ 3) |

**Count.** Seven steps; **five are verbs or a hand-off to a skill that is verbs**, two are named
residue. Nothing here is improvised shell presented as if a verb produced it.

## 2. Verbs exercised live

### 2.1 — `nen wc classify`, on the trunk, clean and dirty

```
$ nen wc classify --repo <fixture> --base main
case: on-branch-clean
  on the trunk ('main') with nothing uncommitted -- nothing to move
exit=0

$ echo "scratch line" >> <fixture>/src/app.js
$ nen wc classify --repo <fixture> --base main
case: must-move
  on the trunk ('main') with 1 uncommitted path(s) -- this MUST move to a fresh branch cut from the
  target base; nothing is ever committed to the trunk directly
exit=0
```

Note the wording of the clean case: `on-branch-clean` is reported **on the trunk too**, with its own
sentence. The skill's § 3 table therefore splits that one verb case into two rows by where the
checkout is, rather than treating `on-branch-clean` as proof that an effort branch exists.

### 2.2 — `nen shu warmup --dry-run`, then the real run

Dry run against the dirty fixture (abridged to the step list; each line carries its own refusal
condition in the real output):

```
$ nen shu warmup --repo <fixture> --branch opus/kurapika/fixture-demo --dry-run
repo:          <fixture>
remote:        origin
trunk:         main
branch:        opus/kurapika/fixture-demo
discard:       no -- a dirty working copy refuses
lane:          app
would run:     git branch --show-current
would run:     git rev-list --count HEAD --not --branches --remotes
would run:     git rev-list --ignore-missing -1 MERGE_HEAD REBASE_HEAD CHERRY_PICK_HEAD
would run:     git -c core.quotePath=false status --porcelain=v1 -z -uall
would run:     git remote
would run:     git show-ref --verify --quiet refs/heads/main
would run:     git check-ref-format --branch opus/kurapika/fixture-demo
would run:     git show-ref --verify --quiet refs/heads/opus/kurapika/fixture-demo
would run:     git fetch origin
would run:     git merge-base --is-ancestor main origin/main
would run:     git branch --force main origin/main
would run:     git ls-remote --heads origin refs/heads/opus/kurapika/fixture-demo
would run:     git switch -c opus/kurapika/fixture-demo origin/main
would run:     node -e 'console.log('\''build ok'\'')'
               the lane's declared 'build', run through the executor in this process -- nen never spawns itself
exit=0
```

Thirteen git steps and the declared build, in order, **with the tree still dirty** — the dry run reads
no git state, which is why it also says which fast-forward shape it cannot know
(`git branch --force` vs `git merge --ff-only`) and that `main` is an assumption.

The same invocation without `--dry-run`, on that same dirty tree:

```
$ nen shu warmup --repo <fixture> --branch opus/kurapika/fixture-demo
nen shu warmup: the working copy at <fixture> carries 1 uncommitted path(s), and warmup destroys
nothing nobody asked it to.
   M src/app.js
Commit them, stash them, or pass --discard to throw them away -- that runs 'git reset --hard' and
then 'git clean -fd', in that order, printing this same list first and re-reading the tree
afterwards.
Ignored files are NEVER touched: 'git clean' is run without -x, because an ignored file is this
developer's cache and not this verb's to delete.
exit=2
```

Then, with the tree clean, the real warm-up (abridged; every step's own note is in the real output):

```
$ nen shu warmup --repo <fixture> --branch opus/kurapika/fixture-demo
build ok
repo:          <fixture>
remote:        origin
trunk:         main
branch:        opus/kurapika/fixture-demo
lane:          app
ran:           git branch --show-current  -- exit 0 in 15ms          on 'main'
ran:           git rev-list --ignore-missing -1 MERGE_HEAD REBASE_HEAD CHERRY_PICK_HEAD  -- exit 0
ran:           git -c core.quotePath=false status --porcelain=v1 -z -uall  -- exit 0    clean
ran:           git remote  -- exit 0                                  remotes: origin
ran:           git show-ref --verify --quiet refs/heads/main  -- exit 0
ran:           git check-ref-format --branch opus/kurapika/fixture-demo  -- exit 0
ran:           git show-ref --verify --quiet refs/heads/opus/kurapika/fixture-demo  -- exit 1
               no local branch ... exit 1 here is the ANSWER, not a failure
ran:           git fetch origin  -- exit 0
ran:           git merge-base --is-ancestor main origin/main  -- exit 0
               ... This step's exit code IS the verdict: 0 ancestor, 1 diverged
ran:           git merge --ff-only origin/main  -- exit 0
               the checkout is on 'main', so the fast-forward happens in the working tree
ran:           git ls-remote --heads origin refs/heads/opus/kurapika/fixture-demo  -- exit 0
ran:           git switch -c opus/kurapika/fixture-demo origin/main  -- exit 0
               cut from origin/main, the tip this run just fetched
ran:           node -e 'console.log('\''build ok'\'')'  -- exit 0 in 138ms
exit=0
```

The dry run's twelfth line said `git branch --force main origin/main`; the real run did
`git merge --ff-only origin/main` instead, exactly as the dry run warned it might — a checkout that
is *on* the trunk fast-forwards in the working tree. Worth knowing before quoting a dry run to a
maintainer as though it were a transcript.

### 2.3 — the same verb against a repository with no declaration (read-only)

```
$ nen shu warmup --repo <nen checkout> --branch opus/kurapika/probe-only --dry-run
repo:          <nen checkout>
...
lane:          (none -- no declaration, so build/test verification was skipped)
would run:     git branch --show-current
... (the same thirteen git steps) ...
would run:     git switch -c opus/kurapika/probe-only origin/main
no declaration -- build/test verification skipped. <nen checkout> carries no nen/contract.json
"project" block, so this repository has not said how it is built, and the git half above is the whole
of what would run. That is not a failure: warming a working copy is useful on its own, and this
exits 0. Run 'nen shu detect --repo <nen checkout>' to see a project block proposed from the markers
on disk.
exit=0
```

Exit `0`, `lane: (none)`, the git half intact — the behaviour `claude/agents/kurapika.md` § *The `shu`
verbs* describes, confirmed at this pin against a real undeclared repository rather than quoted from
its `--help`.

### 2.4 — `nen shu tools`, dry run and check

```
$ nen shu tools --repo <fixture> --dry-run
lane:          app  (nextjs)
mode:          dry-run
  ?        node  --     pinned >=18.0.0  (tested minimum 20.19.0)
                 would probe: node --version
                 verify-only: install by hand -- nen probes this tool and reports it; installing it
                 is a system-wide decision with several common answers, and picking one for a
                 developer is the line this verb does not cross. Install node >=18.0.0 the way this
                 machine already installs such things.
exit=0

$ nen shu tools --repo <fixture>
lane:          app  (nextjs)
mode:          check
  ok       node  24.16.0  pinned >=18.0.0  (tested minimum 20.19.0)
exit=0
```

The `--dry-run` form spawns nothing at all, probes included — the one form of this verb a watcher can
certify read-only, which is why breath's § 4 runs it first on an unfamiliar host.

### 2.5 — `nen stop`, the banner breath does *not* print

```
$ nen stop --template
| Effort  | Open issues & PRs | Status (gate)   | Thought flow | Session / lane |
| ------- | ----------------- | --------------- | ------------ | -------------- |
| <title> | <link>            | <status (gate)> | <one line>   | <session>      |
exit=0
```

Recorded because breath's § 9 says the drawing is not its to print for a progress turn: the only
banner it ever renders is a **G5** for an unsupported host (`shu warmup` exit `3`), and the template
above is what that stop is filled from.

### 2.6 — `nen schema check` has no `nen/workflow.json` row at `0.3.0`

```
$ nen schema check --repo <fixture>
repository: <fixture>
  FAIL  nen/labels.json    ... no such file ...
  FAIL  nen/repos.json     ... no such file ...
  FAIL  nen/colors.yml     ... no such file ...
  warn  nen/gates.json     ... no such file ...
  ok    nen/contract.json  project (1 lane: app; 4 verbs; 1 toolchain entry)
nen: this repository's taxonomy could not be read. ...
exit=1
```

Five rows, four taxonomy files and the contract — and **no row for `nen/workflow.json`**, absent or
otherwise. The verb reports a file it looks for even when the file does not exist (three `FAIL`s and
a `warn` above are exactly that), so the absence of the row is the absence of the check. This is why
breath § 2 reads `workflow.json` as data and reports a malformed one as a finding: nothing validates
it at this pin.

## 3. Residue

1. **Rendering the branch template.** `nen shu warmup --branch` is required with no default — nen
   never invents a branch name — so substituting `{model}`/`{persona}`/`{descriptor}` from
   `workflow.json` is the skill's own string work. `nen parse` is a grammar engine for *invocations*
   and does not template a name.
2. **Reading `nen/workflow.json`.** No loader, no schema row (§ 2.6). The skill reads the file, states
   the built-in defaults from `docs/WORKFLOW.md` out loud when it is absent, and reports a malformed
   one rather than assuming.
3. **Carrying a dirty trunk onto the new branch.** `nen shu warmup` offers refuse or `--discard`, and
   `--discard` destroys. `git stash` → warm-up → `git stash pop`, by hand and named, is the only path
   that preserves the work; the skill never reaches for `--discard` on its own account.
4. **"Is this dirty branch this effort?"** stays judgment. `nen wc classify`'s `on-branch-dirty` case
   prints the commit subjects and the paths and says outright the call is not the module's.

## 4. Findings against the binary

*Filed nowhere yet — this is the list, per the brief's instruction to record and not file.*

1. **`nen shu warmup`'s dry run cannot tell which fast-forward it would do** (§ 2.2). It says so
   itself, and the real run took the other branch. Not a defect — a dry run reads no git state by
   design — but it means a pasted dry run is a *plan*, not a transcript, and a skill quoting one to a
   human should say which it is. Recorded as a boundary, not a bug.
2. **`on-branch-clean` covers both "on the trunk, nothing to do" and "already on an effort branch"**
   (§ 2.1). One case name, two situations a warm-up must treat differently. The distinguishing detail
   is in the sentence rather than the case, so a caller reading only the case is one substring away
   from cutting a second branch on an effort that already has one. Worth a case of its own, or a
   `branch` field under `--json`.
3. **Nothing validates `nen/workflow.json`** (§ 2.6). Expected — the file is a Hatsu key at this pin
   and its schema row is scheduled — but until it lands, every skill reading it carries the same
   unchecked-input risk, and each one says so in its own § 2.
4. **No other gap.** Every deterministic step of this warm-up that is not in § 3 is a verb, exercised
   live above with its exit code.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| `nen/workflow.json` read by eye, validated by nothing | `nen schema check --repo .` | `1` overall, six rows, the workflow row `ok` |

```
$ nen schema check --repo .
  FAIL  nen/labels.json   … no such file …
  FAIL  nen/repos.json    … no such file …
  FAIL  nen/colors.yml    … no such file …
  warn  nen/gates.json    … no such file …
  ok    nen/contract.json  dependency (nen >= 0.6, pinned v0.6.0), project (1 lane: plugin; 10 verbs; 1 toolchain entry)
  ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}' off 'main', checks: lint
exit=1
```

**Six rows, not five** (§ 2.6 recorded five). The overall exit `1` and the four taxonomy rows are
unchanged and are still not a warm-up failure: Hatsu ships no taxonomy. What is new is that a malformed
policy key is a **FAIL by pointer** from a verb rather than something this skill notices — proved on a
fixture whose `notifications.turn` read `"loud"`:

```
FAIL  nen/workflow.json  …: at notifications.turn, 'loud' is not one nen implements.
                            It is one of a CLOSED set: rung1, all
```

**Reading the values is still this skill's**, and that is a read rather than a residue.

## Retired at nen 0.6 — 2026-09-10

Run against the released `zheref/nen` `v0.6.0` binary (`nen-darwin-arm64`, sha256
`2674dc58…151737e1`, fetched and checksum-verified by `bootstrap/nen.sh --ref v0.6.0`, on `PATH` as
`nen`; `nen --version` → `0.6.0`). Two residues retire here and both were found by real runs rather
than by reading the changelog: one stopped a headless Codex run dead (`docs/ab/surfaces.md` § 7, F4),
the other is the shape every delegated effort in this repository actually has.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| a detached `HEAD` refused by `wc classify` | `nen wc classify --repo <detached worktree> --base main` | **`0`**, with a case |
| cutting by hand when another worktree holds the trunk | `nen shu warmup --repo <linked worktree> --branch … --from main --dry-run` | **`0`**, decision printed |

### `nen wc classify` CLASSIFIES a detached `HEAD`

A throwaway repository with a primary checkout on `main` and a second worktree added with
`git worktree add --detach`:

```text
$ nen wc classify --repo <detached> --base main
case: on-branch-clean
branch: (detached HEAD at bafd762)
  on a detached HEAD at bafd762 with nothing uncommitted -- open or report the existing PR      # exit 0
```

```json
{ "state": { "branch": null, "detachedAt": "bafd762", "isTrunk": false, "dirty": false,
             "aheadOfBase": 0, "existingCommitSubjects": [], "uncommittedPaths": [] },
  "result": { "case": "on-branch-clean",
              "evidence": ["on a detached HEAD at bafd762 with nothing uncommitted -- open or report the existing PR"] } }
```

Through `v0.5.0` the identical call was exit **`1`** — the code this family reserves for *the tree is
not clean* — printing its prose on **stdout** under `--json`, so a caller could tell neither "not
clean" from "cannot classify" nor parse the answer at all. **The branch is a field of the answer
now**, not a precondition of it: `state.branch` is `string | null`, `state.detachedAt` carries the
short sha, `isTrunk` is false there whatever `--base` says (`must-move` cannot apply — a commit made
on a detached `HEAD` lands on no branch), and the text output carries a `branch:` line on every path.
**One refusal remains and it says what it means**: a `HEAD` that names no branch *and* resolves to no
commit — a repository with no commits yet — has no working copy to classify.

**Why this one mattered here.** `hanten` § 9a makes a `git worktree add --detach` for every Codex
reviewer, so the surface Hatsu ships to was the surface whose ordinary starting state stopped § 3
before it began. The skill used to route that refusal to § 5 and let `shu warmup` speak; § 3 now
reads the classification like any other and § 5 still owns the one genuine stop — a detached `HEAD`
carrying **unreachable commits**, which is exit `2` and **G5**, because the cut would orphan them.

### `nen shu warmup` survives a trunk held by ANOTHER worktree

The ordinary shape of this whole way of working — a primary checkout standing on `main`, every effort
in its own `git worktree` beside it — is the shape git refuses to force-move the trunk in. Against a
throwaway repository built that way, with `--from main` and the trunk held by the primary checkout:

```text
$ nen shu warmup --repo <effort worktree> --branch demo/kurapika/x --from main --dry-run
…
would run:     git show-ref --verify --quiet refs/heads/main
               --from names the LOCAL branch this warm-up fast-forwards, and it must already exist
ran:           git worktree list --porcelain  -- exit 0 in 12ms
               which worktree of this repository has 'main' checked out. Git refuses to force-move a branch
               that is checked out ANYWHERE ('fatal: cannot force update the branch ... used by worktree at
               ...'), and the local ref is not needed for the cut: the new branch comes off origin/main
               either way
               trunk held by worktree <…>/primary; cutting from origin/main directly. The local 'main' is
               left exactly where it is -- moving it is git's to refuse, and nothing here needs it moved
would run:     git check-ref-format --branch demo/kurapika/x
…
would run:     git switch -c demo/kurapika/x origin/main                                          # exit 0
```

**Three things this settles.** The `worktree list` read sits **before the fetch**, among the checks
that need no mutation, so a list that cannot be read refuses at exit `2` before anything moves rather
than after. The fast-forward now has **three** shapes rather than two — a merge when this checkout is
on the trunk, a ref move when no worktree holds it, and **nothing at all** when another one does. And
the cut is unchanged: `origin/main` either way, because it never read the local ref, which is exactly
why the local fast-forward was never needed for it.

**`--dry-run`'s guarantee changed with it, and `--json` says so.** It is *mutates nothing* rather than
*runs nothing* — one closed-list read-only command — and the `worktree list` row carries a real exit
code while every planned row is `null`:

```text
$ nen shu warmup --repo <effort worktree> --branch demo/kurapika/y --from main --dry-run --json
contract: nen.shu.warmup/v0.1 | dryRun: true | discard: false
worktree row exitCode: 0
null-exitCode rows: 12 of 13
top-level keys: contract, repo, trunk, remote, branch, discard, dryRun, steps, lane, exitCode
```

**Read `dryRun`, never the exit codes**, when a report has to say which form produced it — that is
the whole reason the key was added.

### Re-verified at this pin, not carried forward: the `nen/workflow.json` row

§ 2's six-row claim is a **statement about the current pin**, so it was re-run rather than inherited
from the v0.5 section above. Against this repository's own checkout, with the `v0.6.0` binary:

```text
$ nen schema check --repo <this checkout>
  FAIL  nen/labels.json   … no such file …
  FAIL  nen/repos.json    … no such file …
  FAIL  nen/colors.yml    … no such file …
  warn  nen/gates.json    … no such file …
  ok    nen/contract.json  dependency (nen >= 0.6, pinned v0.6.0), project (1 lane: plugin; 10 verbs; 1 toolchain entry)
  ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}' off 'main', checks: lint
                                                                                                  # exit 1
```

**Six rows, the two this skill reads both `ok`, and the exit `1` is Hatsu shipping no taxonomy** —
identical in shape to the same call against `origin/main` before this repin (also exit `1`, also four
non-`ok` rows), so nothing here regressed. `hatsu-warmup` § 1 is the authority on all six.
