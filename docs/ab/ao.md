# A/B evidence — `ao` (new skill, wave 2)

`claude/skills/ao/SKILL.md`: bring the branch up to date with its base — rebase when nothing is
published, merge when something is, classify every conflict, resolve only the mechanical ones, stop
at **G5** with both sides shown for a semantic one, and **never push**.

**A new skill, so there is no "old mechanics" column.** What this record establishes is the one
load-bearing fact that shapes the whole skill: **`nen pr cascade-main` — the verb that owns this
operation — pushes on a clean merge, has no `--no-push` at `v0.3.0`, never rebases, and reports that
a conflict happened without reporting what conflicted.** Three of ao's four steps are therefore
residue, and this document is why.

Run: 2026-09-09 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
Every mutating verb was exercised against a **constructed throwaway fixture** — a `git init`'d repo
at `<worktree>/.nen-fixture` with a bare `<worktree>/.nen-fixture-origin.git` as its `origin`,
seeded with a trunk, two branches and three deliberately different conflict shapes — created for
this run and deleted before the branch was committed. **No verb was run against any primary
checkout in a way that could write to it, and nothing was pushed to any real remote.**

Nothing below is redacted; both repositories are public.

---

## 1. The skill

| Step | Owned by | State at `v0.3.0` |
|---|---|---|
| Parse the invocation | `nen parse ao --grammar "from [<base>]"` | **verb** (§ 2.1) |
| Read the checkout | `nen wc classify --repo --base --json` | **verb** (§ 2.2) |
| Detect a merge already in progress | — | **no verb** → residue (§ 2.2, § 3.6) |
| Published or not | — | **no verb** → residue (§ 3.3) |
| Merge the base in | `nen pr cascade-main` | **verb that pushes** → residue (§ 2.3, § 3.1) |
| Rebase onto the base | — | **no verb at any flag** → residue (§ 2.3, § 3.2) |
| Enumerate + classify conflicts | `nen pr cascade-main --json` → `conflicts[]` | **absent** → residue (§ 2.3, § 2.4, § 3.4) |
| Show both sides | — | **no verb** → residue (§ 2.4, § 3.5) |
| The G5 stop | `nen stop --who --gate` | **verb** (§ 2.5) |

**Nine steps; three are verbs, six are residue.** Every one of the six is named in the skill file
where it runs.

---

## 2. Verbs exercised live

### 2.1 — `nen parse ao`: the anchored optional base clause

```
$ nen parse ao --grammar "from [<base>]" --line "from release/1.4"
base: release/1.4
exit=0

$ nen parse ao --grammar "from [<base>]" --line "from"
exit=0                                   # parses, clause absent -- branch.base applies
```

Anchored behind the literal `from` for the reason `docs/ab/rikugan.md` § 2.1 records live.

### 2.2 — `nen wc classify`: what it reports, and what it does not

All three cases, plus `--json`, against the fixture:

```
$ echo "dirty" >> README.md                     # on the trunk
$ nen wc classify --repo <fixture> --base main
case: must-move
  on the trunk ('main') with 1 uncommitted path(s) -- this MUST move to a fresh branch cut from the
  target base; nothing is ever committed to the trunk directly
exit=0

$ git checkout -b opus/kurapika/fixture-turn && git commit -am "feat: first turn of the fixture effort"
$ echo "more" >> README.md
$ nen wc classify --repo <fixture> --base main
case: on-branch-dirty
  on 'opus/kurapika/fixture-turn', 1 commit(s) ahead of base, 1 uncommitted path(s) -- whether these
  are the SAME effort as the branch's existing commits is a judgement this module does not make; the
  commit subjects and paths below are the evidence for it
  existing commits: "feat: first turn of the fixture effort"
exit=0

$ git checkout -- README.md
$ nen wc classify --repo <fixture> --base main --json
{
  "state": {
    "branch": "opus/kurapika/fixture-turn",
    "isTrunk": false,
    "dirty": false,
    "aheadOfBase": 1,
    "existingCommitSubjects": ["feat: first turn of the fixture effort"],
    "uncommittedPaths": []
  },
  "result": {
    "case": "on-branch-clean",
    "evidence": ["on 'opus/kurapika/fixture-turn' with nothing uncommitted -- open or report the
                  existing PR"]
  }
}
exit=0
```

**And the finding — run inside an unresolved merge:**

```
$ git merge --no-edit origin/main            # leaves conflicts
$ nen wc classify --repo <fixture> --base main
case: on-branch-dirty
  on 'opus/kurapika/md', 1 commit(s) ahead of base, 2 uncommitted path(s) -- whether these are the
  SAME effort as the branch's existing commits is a judgement this module does not make; ...
exit=0
```

**A half-finished merge reads as ordinary dirt.** The conflicted paths are counted among
"uncommitted path(s)" and nothing in the output mentions a merge in progress. That is consistent
with the verb's stated scope (it answers tensho's four-case question, not "is git mid-operation"),
but it means ao must check `.git/MERGE_HEAD` / `.git/rebase-merge` itself before classifying —
§ 3.6.

Also worth noting for ao's § 2 table: `state` carries `branch`, `isTrunk`, `dirty`, `aheadOfBase`,
`existingCommitSubjects[]` and `uncommittedPaths[]` — **and nothing about the remote.** Whether the
branch is published is not answerable from this document.

### 2.3 — `nen pr cascade-main`: it pushes, it never rebases, and `--no-push` does not exist

**Clean merge, against the fixture's real bare origin** (branch `opus/kurapika/clean` cut from
`origin/main~1`, trunk one commit ahead, changes non-overlapping):

```
$ git rev-parse --short HEAD; git rev-parse --short origin/opus/kurapika/clean
10dcea0
10dcea0

$ nen pr cascade-main --repo <fixture> --trunk main --json
{
  "conflicted": false,
  "pushed": true,
  "log": [ "fetched origin/main", "merged origin/main cleanly", "pushed" ],
  "error": null
}
exit=0

$ git fetch -q origin
$ git rev-parse --short HEAD; git rev-parse --short origin/opus/kurapika/clean
99abbb9
99abbb9
$ git log --oneline -1
99abbb9 Merge remote-tracking branch 'origin/main' into opus/kurapika/clean
```

**The remote branch moved.** `"pushed": true` is not advisory.

**Conflicting merge:**

```
$ nen pr cascade-main --repo <fixture> --trunk main
fetched origin/main
merge left conflicts -- resolve them, then commit and push yourself; this cascade never picks a side
exit=1

$ nen pr cascade-main --repo <fixture> --trunk main --json
{
  "conflicted": true,
  "pushed": false,
  "log": [
    "fetched origin/main",
    "merge left conflicts -- resolve them, then commit and push yourself; this cascade never picks a side"
  ],
  "error": null
}
exit=1

$ git status --short
UU src.txt
```

**The flag that would make this usable does not exist:**

```
$ nen pr cascade-main --repo <fixture> --no-push
nen pr: unknown option '--no-push'. Known options here: --add-reviewers <value>, --approvers <value>,
--base <value>, --body-from <value>, --delivery-pr, --exclude-run <value>, --explain, --gates <value>,
--gh-repo <value>, --help, --idle-minutes <value>, --json, --last-activity <value>,
--min-verified-wakes <value>, --now <value>, --policy <value>, --pr <value>, --ready, --repo <value>,
--requirements-from <value>, --reviewers <value>, --round-policy <value>, --target <value>,
--token-env <value>, --trunk <value>, --wakes-from <value>.
Run 'nen pr --help'.
exit=2
```

And the family's own help states the rebase half is not on offer at any flag:

```
$ nen pr cascade-main --help
<the whole 'pr' family usage, on both stdout and stderr>
exit=2
...
cascade-main:
  Merges (never rebases) the trunk into the current branch and pushes on a
  clean merge. Reports a conflict rather than resolving it.
```

*(A subcommand-level `--help` on the `pr` family is itself a usage error at `v0.3.0` — exit `2`,
printing the whole family's usage. The family help is the spec.)*

### 2.4 — Classifying conflicts by hand: three kinds, and the three merge stages

The fixture was seeded with one of each shape. **Both-modified and add-add, together:**

```
$ git merge --no-edit origin/main
$ git status --porcelain | grep -E '^(UU|AA|UD|DU)'
AA BOTH_NEW.md
UU src.txt

$ git diff --name-only --diff-filter=U
BOTH_NEW.md
src.txt

$ git ls-files -u | awk '{print $3, $4}'      # stage, path
2 BOTH_NEW.md
3 BOTH_NEW.md
1 src.txt
2 src.txt
3 src.txt
```

**Delete-modify, on its own fixture** (`MD.md` edited on the branch, deleted on the trunk):

```
$ git merge --no-edit origin/main
$ git status --porcelain | grep -E '^(UU|AA|UD|DU)'
UD MD.md
```

**The three stages of a semantic both-modified path** — base `retries = 3`, the branch raised it to
`5`, the trunk raised it to `9` and moved `timeout` too:

```
$ git show :1:src.txt          # merge base
retries = 3
timeout = 30

$ git show :2:src.txt          # ours
retries = 5
timeout = 30

$ git show :3:src.txt          # theirs
retries = 9
timeout = 60
```

**This is the textbook semantic conflict and the exact shape of the § 6 stop.** Textually it is one
small hunk; semantically two people set a policy number differently, and taking either side quietly
ships somebody's decision that nobody made. `AA` carries **no stage 1** (there is no common
ancestor for a path both sides created) — which is itself a classification signal, and it comes from
`git ls-files -u`, not from any verb.

### 2.5 — `nen stop`, the G5 stop ao renders

```
$ nen stop --who Kurapika --gate G5 efforts.md
=== YOUR INPUT IS NEEDED ==============================
who: Kurapika
gate: G5 -- decision / human-only action
rung 1 (push notification): NOT fired -- the caller's to have sent, before this renders.
rungs 2-3 (OS notification, audible cue): not fired by nen -- only git/gh subprocesses are ever
shelled out to.
see the table below. No banner above => nothing needs you right now.

| Effort                                           | State               | Gate | Needs                   | Owner      |
| ------------------------------------------------ | ------------------- | ---- | ----------------------- | ---------- |
| ren turn 3 — semantic conflict in src/session.ts | ao halted mid-merge | G5   | pick a side; both shown | maintainer |
exit=0
```

Full rung behaviour, including `--notified`, is in `docs/ab/jutaisho.md` § 2.2 — cited, not re-proved
here.

---

## 3. Residue

1. **The merge** — `git fetch origin <base>` + `git merge --no-edit origin/<base>`.
   `nen pr cascade-main` owns it but **pushes on success** (§ 2.3, `"pushed": true`, the remote ref
   moved) and **has no `--no-push`** (exit `2`). Ao's hard limit is that it never pushes, so the
   verb cannot run inside it at this pin. `--no-push` is P1 (brief § 4.7); the day it lands this
   entry is deleted, not kept as a shim.
2. **The rebase** — `git rebase origin/<base>`. The cascade verb *"merges (never rebases)"* by its
   own help; there is no rebase verb at any flag.
3. **The published test** — `git rev-parse --verify --quiet refs/remotes/origin/<branch>`.
   `nen wc classify --json` reports the branch, its dirt and its distance from the base, and nothing
   about the remote (§ 2.2).
4. **The conflict enumeration and kinds** — `git status --porcelain`,
   `git diff --name-only --diff-filter=U`, `git ls-files -u` (§ 2.4). `nen pr cascade-main --json`
   carries no `conflicts[]` at this pin (§ 4.1).
5. **Showing both sides** — `git show :1:` / `:2:` / `:3:<path>` (§ 2.4). No verb renders a merge
   stage.
6. **The merge-in-progress check** — `.git/MERGE_HEAD` / `.git/rebase-merge` on disk;
   `nen wc classify` folds an unresolved merge into `on-branch-dirty` (§ 2.2).

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — `nen pr cascade-main --json` says a conflict happened and nothing about what conflicted

§ 2.3: the entire conflict document is
`{"conflicted": true, "pushed": false, "log": [...], "error": null}`. There is no `conflicts[]`, no
`path`, no `kind`, no `ours[]`/`theirs[]`. A caller that wants to *classify* conflicts — which is
the only way to tell a mechanical one from a semantic one, and therefore the only way to know
whether a human is needed — has to re-derive all of it from git's porcelain (§ 2.4). The
`{path, kind (both-modified|add-add|delete-modify), ours[], theirs[]}` shape is already scoped as P1
(brief § 4.7); this run is the live confirmation that it is not there yet.

**One thing the verb already gets right and should keep when the shape lands:** its refusal text is
*"resolve them, then commit and push yourself; this cascade never picks a side."* That instinct is
ao's whole § 5, in nen's own words.

### 4.2 — `--no-push` is the difference between a usable cascade and an unusable one

§ 2.3 verifies both halves: a clean merge pushes, and `--no-push` is an unknown option. For a plane
whose entire design principle is that **agents never push** (brief § 1), a merge verb that pushes is
a verb no local skill can call. This is the single highest-value P1 item for this wave's skills —
it converts three of ao's residue entries into one verb call.

### 4.3 — `nen pr <subcommand> --help` is a usage error, not a help page

§ 2.3: `nen pr cascade-main --help` exits `2` and prints the *family's* usage on both streams. Every
other family this port has touched behaves the same way (`nen wc squash --onto …` in
`docs/ab/aka.md` § 2.2 likewise refuses at the option level). Not a defect — the family help is
complete and does document `cascade-main` — but a caller reaching for per-verb help gets a non-zero
exit and may read it as "the verb does not exist". Worth one line in nen's own usage text.

### 4.4 — `nen wc classify` is blind to an operation in progress, deliberately

§ 2.2: inside an unresolved merge it reports `on-branch-dirty` and counts the conflicted paths as
uncommitted. Its `--help` scopes it to *"tensho's four-case table"*, so this is in-scope behaviour,
not a bug — but it is a real trap for any caller that treats `on-branch-clean`/`on-branch-dirty` as
a complete description of the working copy. **Recorded as a caller's obligation, not a defect:** ao
checks for `.git/MERGE_HEAD` itself, and says so.

### 4.5 — Not a finding: `git` stage numbers are not something nen should wrap

`git show :1:|:2:|:3:<path>` and `git ls-files -u` are git's own index model, stable for decades and
already the vocabulary every reviewer of a conflict uses. A nen verb over them would add a name
without adding a fact. **The verb ao actually wants is `conflicts[]` on the cascade** (§ 4.1) —
classification, not a re-spelling of `git show`.
