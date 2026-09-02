# A/B evidence — `jujisho` (zheref/hatsu#2)

Port of `claude/skills/jujisho/SKILL.md`: split a mixed working copy into up to two stacked
branches and PRs, by axis, leaving nothing behind. Old mechanics: a prose instruction to "prove the
union of the branches' diffs equals the original working-copy diff" with no command given, plus
`gh pr edit --base` for retargeting a stacked PR after its predecessor merges, plus every-branch
`tensho`-style staging discipline improvised the same way `tensho` itself was. New mechanics:
`nen split verify`, `nen pr retarget`, `nen wc classify`, `nen stage triage`, `nen commit format`,
`nen pr cascade-main --trunk <A>`, `nen changelog fragment-required`, `nen ref format`,
`nen repo resolve`.

Run: 2026-09-02T01:42Z (UTC). `nen` `0.1.0` (`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`).
`gh` authenticated as `zheref`.

`split verify` is LOCAL — every transcript in § 2 below runs against a constructed scratch git
repository built for this port, **labeled constructed throughout**, never against bankai-core.
`pr retarget` mutates a PR — § 3 contract-inspects it (`--help` plus refusal behavior against a
bogus target and a nonexistent/wrong-kind object) without touching any real PR's base, live against
`zheref/hatsu` and a nonexistent repository, which is the only "real transcript" this doc contains.

---

## 1. Command mapping table

Every deterministic or hand-reconstructed step the old `SKILL.md` improvised, and what replaces it.

| # | Old (prose / shell) | New (`nen`) |
|---|---|---|
| 1 | "Before opening anything, prove it: the union of the branches' diffs equals the original working-copy diff" — stated as a rule with **no command**, left to the agent to eyeball three diffs side by side | `nen split verify --original <path> --branches <path,path,...>` — a real proof, hunk-identity comparison, exits non-zero on any missing/duplicated/altered hunk (§ 2; **defect found and workaround mandated**, § 4 finding 1) |
| 2 | `gh pr edit <B> --base main`, run by hand after A merges | `nen pr retarget --target <owner/name> --pr <B> --base <branch>` (§ 3) |
| 3 | "Cascade A into B in the same pass... merge, never rebase" — no command, left to the agent's own `git merge` | `nen pr cascade-main --repo <path> --trunk <A's-branch-name>` while B is checked out — merges (never rebases) whatever branch `--trunk` names into the current branch and pushes on a clean merge |
| 4 | Reading the current checkout's state ("On `main`, dirty" / "on a feature branch...") was a hand-read table in `tensho`'s own prose, inherited by jujisho's "decide the base before cutting branches" step | `nen wc classify --repo <path> --base <target base>` — `must-move` / `on-branch-dirty` / `on-branch-clean`, exits 0 for all three (report, not a guard) |
| 5 | Every-file staging review ("secrets, ignored files, binaries, out-of-scope files, local config, unmentioned deletions... flagged and asked about") was `tensho`'s own hand-applied checklist, inherited unchanged by jujisho § 5 | `nen stage triage --repo <path> [--scope ...] [--mentions "..."]` — detects five of the old six shapes (secrets, ignored, binary, out-of-scope, unmentioned-deletion), decides none of them, exits 1 on any flag; **local-config has no detector** (§ 4 finding 2, § 5 residue) |
| 6 | Conventional-commit formatting was written by hand per commit, per axis | `nen commit format --type ... --subject "..." [--scope] [--body] [--trailer ...]` — validates shape, never content |
| 7 | The `changelog.d/` fragment requirement (`CON-33(a)`) was a fixed path-glob list the agent matched against the diff by eye: `CONSTITUTION.md`, `handbooks/*`, `schemas/*`, `agents/*`, `.github/workflows/*` | `nen changelog fragment-required --files <paths> --spec-paths <list> --fragment-dir changelog.d --head-changelog CHANGELOG.md` — same glob, now a computed answer per axis instead of a memorized list applied twice by hand |
| 8 | The sibling-PR reference in each body ("`BC-PR-#<A>`") was hand-typed object notation | `nen ref format --code <CODE> --kind PR --number <N> [--state <s>]` |
| 9 | Resolving the `owner/name` slug for a retarget/cascade call was left to reading `git remote -v` by hand | `nen repo resolve [<token>] --from <dir>` — resolves a product code, slug, short name or the working directory's own `origin`, against the registry, never guessed |

**Count.** Before: 6 steps performed **by prose or raw git/gh, per invocation, with no verb backing
them at all** (rows 1–6: the union proof had no command whatsoever, the retarget and cascade were
raw `git`/`gh`, the working-copy read and the staging checklist were hand-applied tables, commit
formatting was freehand). After: **0** carry no verb — all nine rows above now resolve to a named
`nen` invocation. What remains genuinely improvised is the changelog spec-paths list itself (row 7:
`--spec-paths` is still data the caller supplies, same as the old glob was), which is registry-style
caller data rather than a computed step, same category the pr-state port already accepted for
`--gates`/`--reviewers`.

---

## 2. Constructed A/B — `nen split verify` (LOCAL, no bankai-core involvement)

**Scratch repo**: initialized fresh at
`C:\Users\zhere\.claude\jobs\4f1fdef1\tmp\jujisho-scratch`, one commit seeding `src/parser.py` and
`docs/readme.md`, then a mixed uncommitted change touching both files — a parser perf tweak plus a
new `normalize()` function in `src/parser.py` (axis "parser"), and a documentation addition in
`docs/readme.md` (axis "docs"). Every transcript below is against this constructed repo, never
against a real product repository.

### 2.1 — the split is genuinely correct, and the verb says so, per file

Cut `axis-parser` and `axis-docs` from `main`, each carrying only its own file's hunk. Diffed each
against `main`, then verified per file (the § 2.2 finding below is why per-file, not combined):

```
$ nen split verify --original docs-only-original.diff --branches axis-docs.diff
files: 1 in original, 1 across branches
OK -- every hunk in the original lands in exactly one branch, unaltered, and nothing extra was found.
```
Exit `0`.

A genuinely **missing** axis is caught cleanly when the branch set is short a whole file (the
"doctor one branch to drop a hunk" case, done here by omitting the docs branch's diff entirely from
`--branches`):

```
$ nen split verify --original original.diff --branches axis-parser.diff
files: 2 in original, 1 across branches
MISSING (in original, in no branch): docs/readme.md  @@ -1,3 +1,7 @@
nen: the split is incomplete -- see the missing/duplicated/altered/extra hunks above.
```
Exit `1`. This is the real failure mode the skill is built to catch — a leftover hunk invisible in
either PR — and it works exactly as documented when the original diff (here) is being compared
against a branch set that omits a whole file.

A genuinely **truncated** hunk (a real, on-purpose content difference) is caught cleanly too, in a
single-file, two-hunk construction (`src/two_hunks.py`, two edits far enough apart to produce two
separate hunks) where the branch diff is doctored to keep only the first hunk's full, correct text
and the second hunk is dropped outright:

```
$ nen split verify --original two_hunks_original.diff --branches two_hunks_branch_dropped.diff
files: 1 in original, 1 across branches
MISSING (in original, in no branch): src/two_hunks.py  @@ -17,6 +17,6 @@ def d():
ALTERED (in branch 1, header matches but the body does not): src/two_hunks.py  @@ -1,5 +1,5 @@
  line 8: original "(absent)" vs branch ""
```
Exit `1`. (The `ALTERED` row alongside the correct `MISSING` row here is itself an instance of
finding 1 below — read on.)

### 2.2 — the defect: a correct multi-file split is reported broken

The same `axis-parser.diff` / `axis-docs.diff` pair from § 2.1, this time verified **together** in
one combined run — the form the skill would naturally reach for first:

```
$ nen split verify --original original.diff --branches axis-parser.diff,axis-docs.diff
files: 2 in original, 2 across branches
ALTERED (in branch 2, header matches but the body does not): docs/readme.md  @@ -1,3 +1,7 @@
  line 9: original "(absent)" vs branch ""
```
Exit `1` — **on a split that is genuinely, byte-for-byte correct.** `original.diff` and
`axis-docs.diff` were confirmed identical for every line of the `docs/readme.md` hunk before this
run (`diff` on the two files' shared line range: no output). Swapping the branch order
(`axis-docs.diff,axis-parser.diff`) moves the false failure to whichever file is now **not last**:

```
$ nen split verify --original original.diff --branches axis-docs.diff,axis-parser.diff
ALTERED (in branch 1, header matches but the body does not): docs/readme.md  @@ -1,3 +1,7 @@
  line 9: original "(absent)" vs branch ""
```

Reversing which file comes last **inside `--original` itself** (parser hunk first, docs hunk
second) moves the false failure onto `src/parser.py` instead — confirming the defect tracks "not
the last file named in `--original`", not any one file or branch position:

```
$ nen split verify --original reversed-original.diff --branches axis-parser.diff,axis-docs.diff
ALTERED (in branch 1, header matches but the body does not): src/parser.py  @@ -1,5 +1,10 @@
  line 13: original "(absent)" vs branch ""
```

A three-file `--original` (parser + docs + a brand-new `README3.md`) confirms the pattern holds at
scale: the first two files (non-last) are both falsely `ALTERED`, the third (last) is not flagged
at all:

```
$ nen split verify --original original3.diff --branches axis-parser.diff,axis-docs.diff,file3.diff
files: 3 in original, 3 across branches
ALTERED (in branch 2, header matches but the body does not): docs/readme.md  @@ -1,3 +1,7 @@
  line 9: original "(absent)" vs branch ""
ALTERED (in branch 1, header matches but the body does not): src/parser.py  @@ -1,5 +1,10 @@
  line 13: original "(absent)" vs branch ""
```

And the single-file, two-hunk case (§ 2.1's `two_hunks.py`, both hunks assigned to one branch,
identical text) verifies clean when nothing is actually missing — confirming a complete single-file
diff parses correctly regardless of hunk count. **This is not proof the defect is confined to file
boundaries**: § 2.1's other `two_hunks.py` transcript (same file, same two hunks, second hunk
genuinely dropped from the branch side) already shows the identical false `ALTERED` firing at a
hunk boundary within this same single file, alongside the correctly-reported `MISSING` line for the
hunk that really is gone. The defect fires whenever a hunk — a whole file's worth, or one hunk
within a file — is genuinely absent from the branch side being compared; never when the two sides
are complete and byte-identical:

```
$ nen split verify --original two_hunks_original.diff --branches two_hunks_branch.diff
files: 1 in original, 1 across branches
OK -- every hunk in the original lands in exactly one branch, unaltered, and nothing extra was found.
```

**Root cause characterization** (behavioral, not sourced from `nen`'s TypeScript — not inspected for
this port): `nen split verify` appends a phantom trailing line to a hunk's body whenever that hunk
is not the last one the parser accounts for in the comparison — the last **file** named in a
multi-file `--original` (this section), or, within one file, the last hunk the parser can actually
match once the branch side is short a hunk for that file (§ 2.1's dropped-hunk transcript). Either
way the phantom line never matches the branch-side parse of that same, correctly-terminated hunk,
producing the false `ALTERED`. Filed as finding 1, § 4.

---

## 3. Contract-inspection — `nen pr retarget` (no mutation attempted)

Per the shared brief: `pr retarget` mutates a PR, so it is never exercised against bankai-core, and
here only against a bogus/nonexistent target — verified to fail closed, before touching anything,
in three shapes:

```
$ export GH_TOKEN=$(gh auth token)
$ nen pr retarget --target zheref/this-repo-does-not-exist-xyz123 --pr 999999 --base main
could not retarget zheref/this-repo-does-not-exist-xyz123#999999 to 'main': GraphQL: Could not resolve to a Repository with the name 'zheref/this-repo-does-not-exist-xyz123'. (repository)
```
Exit `1`.

```
$ nen pr retarget --target zheref/hatsu --pr 999999 --base main
could not retarget zheref/hatsu#999999 to 'main': GraphQL: Could not resolve to a PullRequest with the number of 999999. (repository.pullRequest)
```
Exit `1` — a real repository, a PR number that does not exist.

```
$ nen pr retarget --target zheref/hatsu --pr 1 --base this-branch-does-not-exist-xyz
could not retarget zheref/hatsu#1 to 'this-branch-does-not-exist-xyz': GraphQL: Could not resolve to a PullRequest with the number of 1. (repository.pullRequest)
```
Exit `1` — `zheref/hatsu#1` is an **issue**, not a PR (same shape as `pr-state`'s own documented
issue-vs-PR finding); `nen pr retarget` refuses on object-type resolution before it can reach a
`gh pr edit`-equivalent mutation, for all three shapes (bad repo, bad PR number, wrong object kind).
**No real PR's base was read, let alone written, at any point in this section.**

`nen pr retarget --help` (via `nen pr --help`, which lists every `pr` subcommand together) confirms
the flag surface used above matches the shipped verb exactly:
`nen pr retarget --target <owner/name> --pr <n> --base <branch>` — documented one-line, `gh pr edit
--base` under the hood, no dry-run flag offered or needed since a bogus target already fails closed
ahead of the mutating call.

---

## 4. Findings (report separately, do not route around)

1. **`nen split verify` produces a false `ALTERED` on an otherwise byte-identical hunk whenever a
   hunk is genuinely absent elsewhere in the comparison** — at the `diff --git` file boundary when
   `--original` spans more than one file (every file misparses except the one named last), and
   equally **at a hunk boundary within a single file** when that file's branch-side diff is itself
   short a hunk (the surviving hunk is falsely `ALTERED` alongside the correctly-reported `MISSING`
   line for the one truly missing). Reproduced independently five ways (§ 2.1–2.2): two-file order
   A, the same two files reversed, a three-file original, a single-file two-hunk case with a hunk
   genuinely dropped, and the same single-file two-hunk case with nothing dropped — which verifies
   clean, confirming the defect needs a genuine gap to fire; a complete diff, single-file or
   multi-hunk, never trips it. **This is the verb this skill's core proof step depends on**, so the
   port does not route around it silently: § 2's SKILL.md text mandates running `split verify` once
   per touched file plus a separate plain file-set equality check. A per-file slice is not immune to
   the same false `ALTERED` — the hunk-boundary case can still fire inside one — **but the
   workaround stays safe**, because a real gap always also produces its own `MISSING` line: the
   split is never reported as a clean `OK` when a hunk has genuinely been left behind, so together
   the per-file runs plus the file-set check reconstruct the same guarantee a correct combined run
   would give. Worth filing against `nen` directly (likely in the original-diff hunk-body
   extraction that determines where one file's, or one hunk's, parsed body ends).

2. **No local-config detector in `nen stage triage`** — the same finding as `hatsu:tensho`'s own
   (`docs/ab/tensho.md` § 4.3): a `.claude/settings.local.json`-shaped file that is neither
   git-ignored nor out of a declared `--scope` reports **clean**, verified live against the same
   binary tensho verified against (`nen stage triage --help` names five detectors; local-config is
   not one of them). The old jujisho staging checklist (§ 5, inherited unchanged from tensho's own
   checklist) named local config as its own flagged category — the port does not silently drop the
   check: § 5 of the SKILL.md now states it as a by-eye judgement item, same as tensho does, and
   this is the disclosure for § 1 row 5's now-corrected "detects five of the old six shapes" line
   above.

---

## 5. Residue

- **Judgment kept, per the shared brief's boundary list:** naming every axis and what makes it one
  thing (§ 2 of the SKILL.md); deciding which two axes to keep when there are three or more, and the
  *ask* that follows (§ 3); ordering the stack by dependency and unblocking power (§ 4); recognizing
  the `CON-36` chore case; the *ask* on every flagged staging file (`nen stage triage` detects,
  never decides); and the content of every commit message and PR body (the verbs validate shape
  only). None of this is Nen's to decide, and nothing above hands it any of that.
- **One flag category from the old six-shape staging checklist has no `nen stage triage` detector:
  local config.** Same finding as `hatsu:tensho`'s own § 4.3 — this skill's § 5 explicitly asks
  about a local-config path by name, per axis, rather than treating the verb as if it still covered
  it.
- **`nen` exposes no read-back for a PR's current base branch.** After `nen pr retarget`, confirming
  the base actually changed has no verb counterpart; `gh pr view <B> --json baseRefName` remains,
  unmigrated, as the confirmation step (SKILL.md § 4). This is a small residual raw-`gh` read, not a
  mutation, and not one of the six rows counted in § 1.
- **`nen pr cascade-main --trunk <name>` is a repurposing, not a dedicated verb.** The verb is
  written and documented as "merge the trunk into the current branch"; jujisho's actual need
  ("cascade A into B") is satisfied by passing A's branch name as `--trunk` while B is checked out,
  which the verb's own flag semantics permit generically (it merges *whatever* `--trunk` names) but
  its help text does not describe this use case. Not exercised live for this port — doing so would
  require two real branches and a real merge, out of scope for a contract-inspection-only verb per
  the shared brief, and this repurposing itself is worth flagging to `nen`'s maintainers as either
  confirmation the flag is meant to be this general, or a documentation gap.
- **`nen parse jujisho` does not apply.** `jujisho`'s own invocation carries no arguments to
  validate — `nen parse` checks a skill's *own* flag grammar (or one of the three built-in ones,
  `futon`/`izanagi`/`izanami`), and there is nothing here to parse. Checked live (`nen parse
  --help`) before concluding this, per the shared brief's "check what applies" instruction.
- **`nen stop` does not apply here either.** jujisho reports and hands off to `hatsu:drive` (§ 7);
  it does not itself sit at a human gate awaiting confirmation the way a `G`-gate stop does. The old
  skill never called the equivalent gate-stop script either.
- **No missing verb beyond finding 1.** Every other deterministic step jujisho needs — the working-
  copy read, per-branch staging triage, commit formatting, the changelog-fragment check, object
  notation, and repository-token resolution — has a `nen` verb, confirmed against the live binary
  (`nen <family> --help`) before being written into the SKILL.md.
