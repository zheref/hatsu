---
name: ao
description: Bring the branch up to date with its base — rebase when nothing has been published, merge when it has, resolve the mechanical conflicts, and stop at G5 with both sides shown for a semantic one. Use when the maintainer invokes hatsu:ao [from <base>], asks to pull main in, catch the branch up, or rebase onto main, or whenever hatsu:aka, hatsu:murasaki or hatsu:en needs the branch current. Kurapika classifies every conflicted path before touching one and never picks a side on a conflict of meaning. Never pushes, never force-pushes, never rewrites a commit that is already on the remote.
---

# Ao — the branch, caught up

**Nature: Manipulator.** Reconciling a branch against its base is git-side operation on a body of
work that is not only yours, whichever nature authored the diff.

> **Put the base underneath me, resolve what is only text, and hand me anything that is meaning.**

Ao is [`hatsu:murasaki`](../murasaki/SKILL.md)'s first step, [`hatsu:aka`](../aka/SKILL.md)'s third,
and the step [`hatsu:en`](../en/SKILL.md) runs when a PR falls behind. It is also invocable alone.
The whole of its discipline is one distinction — **text versus meaning** — and one refusal: it never
pushes what it produced.

---

## 1. Invocation

```
hatsu:ao [from <base>]
```

```bash
nen parse ao --grammar "from [<base>]" --line "<the invocation, minus the hatsu:ao prefix>"
```

Verified live at `v0.3.0` (`docs/ab/ao.md` § 2.1): `from release/1.4` → `base: release/1.4`; a bare
`from` parses with the clause absent, exit `0`. The clause is anchored behind a literal for the
reason [`hatsu:rikugan`](../rikugan/SKILL.md) § 1 records.

**With no clause the base is `nen/workflow.json` → `branch.base`, default `main`** when the key or
the file is absent. Name the base out loud before fetching it — a branch quietly caught up against
the wrong base is a diff nobody can read afterwards.

## 2. Read the checkout first

```bash
nen wc classify --repo <path> --base <base> --json
```

Verified live at `v0.3.0` (`docs/ab/ao.md` § 2.2), `--json` carries exactly what this skill needs
before it touches anything: `state.branch`, `state.isTrunk`, `state.dirty`, `state.aheadOfBase`,
`state.existingCommitSubjects[]`, `state.uncommittedPaths[]`.

| `nen wc classify` case | What ao does |
|---|---|
| `must-move` — on the trunk | **Refuse.** There is nothing to catch up: the trunk *is* the base. Say so and hand the caller to [`hatsu:breath`](../breath/SKILL.md) or [`hatsu:tensho`](../tensho/SKILL.md), whichever the situation wants |
| `on-branch-dirty` | **Refuse, naming the uncommitted paths the verb printed.** A merge or a rebase over uncommitted work either refuses at git's own hands or buries the work in a conflict nobody can untangle. Commit it ([`hatsu:kokusen`](../kokusen/SKILL.md)) or stash it deliberately, then re-run |
| `on-branch-clean` | Proceed to § 3 |

> **`nen wc classify` is not a conflict detector, and a half-finished merge reads as ordinary
> dirt — verified live (`docs/ab/ao.md` § 2.2).** Run inside an unresolved merge it reports
> `on-branch-dirty` with the conflicted paths counted among "uncommitted path(s)", saying nothing
> about the merge in progress. So **check for one before classifying**: a `.git/MERGE_HEAD` or
> `.git/rebase-merge` present means a previous run stopped here, and this run reports that state
> rather than starting a second operation on top of it.

## 3. Which operation — rebase or merge, decided by whether anything was published

**Rebase when nothing on this branch has been published. Merge when something has.** Rewriting a
commit somebody else may already have fetched is the one git operation that costs other people
work, and the local plane never does it.

```bash
git -C <path> fetch origin <base>
git -C <path> rev-parse --verify --quiet refs/remotes/origin/<branch>   # published?
```

- **Resolves** → the branch exists on the remote → **merge**: `git merge --no-edit origin/<base>`.
- **Does not resolve** → nothing published → **rebase**: `git rebase origin/<base>`.

Say which one and why, in one line, before running it: *"`opus/kurapika/knobs` is on origin, so this
is a merge, not a rebase."*

> **Both commands are residue, and the reason is a verified property of the verb that owns this
> step.** `nen pr cascade-main --repo <path> [--trunk main]` is the cascade verb, and at `v0.3.0` it
> does two things ao must not do:
>
> 1. **It pushes.** Verified live against a constructed fixture with a real origin
>    (`docs/ab/ao.md` § 2.3): a clean merge returns `{"conflicted": false, "pushed": true, "log":
>    ["fetched origin/main", "merged origin/main cleanly", "pushed"]}`, exit `0`, and the branch's
>    remote ref moved. **`--no-push` does not exist** — verified live, exit `2`, *"unknown option
>    '--no-push'"*, listing every option the family does have. It is P1 (brief § 4.7); until it
>    lands, a verb that pushes cannot run inside a skill whose hard limit is that it never pushes.
> 2. **It merges, never rebases** — its own `--help` says so verbatim: *"Merges (never rebases) the
>    trunk into the current branch and pushes on a clean merge."* So the unpublished half of § 3 has
>    no verb at all, at any flag.
>
> Both halves are therefore run as named residue — `git fetch` + `git merge --no-edit` /
> `git rebase` — and reported as by-hand. **The day `--no-push` lands, the merge half becomes
> `nen pr cascade-main --repo <path> --trunk <base> --no-push` and this paragraph is deleted, not
> kept as a shim.**
>
> `nen pr cascade-main --help` is not a way to read this: verified live, a subcommand-level
> `--help` on the `pr` family exits `2` and prints the whole family's usage. The family help is the
> spec here.

## 4. Classify every conflicted path before resolving one

```bash
git -C <path> status --porcelain                    # the conflict rows
git -C <path> diff --name-only --diff-filter=U      # the conflicted paths, alone
git -C <path> ls-files -u                           # which stages each path has
```

Verified live against a constructed fixture carrying one of each (`docs/ab/ao.md` § 2.4):

| Porcelain | Kind | Stages present |
|---|---|---|
| `UU` | **both-modified** — both sides changed the same file | `1` base, `2` ours, `3` theirs |
| `AA` | **add-add** — both sides created the same path | `2` ours, `3` theirs; **no base** |
| `UD` / `DU` | **delete-modify** — one side deleted what the other edited | the surviving side only |
| `DD`, `AU`, `UA` | the rarer shapes; classify by the same table and name them | as git reports |

> **`nen pr cascade-main --json` reports *that* there was a conflict and nothing about *what* — a
> finding, verified live (`docs/ab/ao.md` § 2.3).** Its whole conflict document is
> `{"conflicted": true, "pushed": false, "log": ["fetched origin/main", "merge left conflicts —
> resolve them, then commit and push yourself; this cascade never picks a side"], "error": null}` at
> exit `1`. **There is no `conflicts[]` array**, no `path`, no `kind`, no `ours[]`/`theirs[]` — the
> `{path, kind, ours[], theirs[]}` shape is P1 (brief § 4.7) and is not there yet. So § 4's
> enumeration is residue, run through git's own porcelain, and it is named as such every run. The
> verb's own instinct is right and worth quoting where it lands: *"this cascade never picks a
> side."*

**Classify every path before resolving any of them, and print the table.** A run that resolves the
first three and discovers the fourth is semantic has already spent the maintainer's trust on the
first three.

## 5. Mechanical, or semantic

**Mechanical** — the resolution is *determined*, by the repository, not chosen by anyone:

- an append-only region both sides appended to (an import block, a `.gitignore`, a changelog list) —
  keep both, in the order the file's own convention gives;
- a generated or locked file the repository regenerates (a lockfile, a snapshot, a mirror) — take
  the base's side and **regenerate**, then prove it with the declared build
  ([`hatsu:rasengan`](../rasengan/SKILL.md));
- a pure formatting or whitespace divergence with no behavioural difference;
- an identical change made on both sides.

**Semantic** — anything where a *person* has to prefer one intent to another. **`UD`/`DU` is always
semantic**: "deleted" and "still being edited" are two beliefs about whether a thing exists, and no
merge algorithm holds the belief. So is a `UU` where both sides changed the same behaviour, and an
`AA` whose two files are not the same file.

> **The textbook case, verified live (`docs/ab/ao.md` § 2.4).** Base has `retries = 3`; the branch
> raised it to `5`; the trunk raised it to `9` and also moved `timeout`. Textually this is one small
> hunk. Semantically it is two people deciding a policy number, and taking either side silently
> ships somebody's decision that nobody made. `git show :1:` / `:2:` / `:3:` on the path prints the
> three versions exactly — base, ours, theirs — and that is what the stop shows.

**Resolve the mechanical ones, one at a time, saying what each was and why the resolution was
determined.** Then re-run the declared build before the merge is committed — a green merge that was
never built is a claim, not a result.

## 6. A semantic conflict is a stop, at G5

**Never pick a side.** Not "ours is newer", not "theirs is bigger", not `-X ours`, not `-X theirs`,
and never a blend that is neither side's intent.

The stop is [`hatsu:jutaisho`](../jutaisho/SKILL.md)'s shape, in full — the `nen stop` banner and
efforts table (`nen stop --who Kurapika --gate G5 <efforts.md>`, verified live, `docs/ab/ao.md`
§ 2.5), the [`hatsu:rikugan`](../rikugan/SKILL.md) report's link, lettered options with a ⭐ on the
report, and the question through the surface's own option picker. What this skill adds to it:

- **Both sides shown, verbatim** — `git show :2:<path>` and `git show :3:<path>`, with `:1:` where a
  base stage exists — never summarised, never paraphrased into "they disagree about retries".
- **The options are the actual resolutions**, one per side plus any genuine third: *"A — keep
  `retries = 5` (ours)", "B — take `retries = 9` (theirs)", "C — 9 with the branch's timeout"*.
- **The tree is left conflicted, and that is stated**, with the one-line undo printed:
  `git -C <path> merge --abort` (or `git rebase --abort`). Leaving it is deliberate — the conflict
  markers and the three stages are what the maintainer needs in front of them — but a checkout left
  mid-merge without anyone saying so is a trap.

**The run ends there.** A G5 stop is not a thing to retry past; the answer resumes it.

## 7. Then hand it back — never pushed

Ao finishes with a branch that is current and a working copy that is clean, **and nothing on the
remote has moved.** Push is [`hatsu:aka`](../aka/SKILL.md)'s, on the maintainer's call, and
`murasaki`'s third step for a branch that is already published. **Ao invoked from inside either of
them still does not push**: the caller pushes, after ao returns, having seen what ao did.

Report, in one line: the base and its resolved SHA, rebase-or-merge and why, the conflicts by kind,
which were mechanical and how each was resolved, and that the build was re-proved.

## Residue

1. **`git fetch` + `git merge --no-edit origin/<base>`** (§ 3) — `nen pr cascade-main` owns the merge
   but pushes on success and has no `--no-push` at `v0.3.0` (verified live, exit `2`).
2. **`git rebase origin/<base>`** (§ 3) — the cascade verb *"merges (never rebases)"* by its own
   `--help`, so the unpublished half has no verb at any flag.
3. **The published/unpublished test** (§ 3) — `git rev-parse --verify --quiet
   refs/remotes/origin/<branch>`. `nen wc classify --json` reports the branch, its dirt and its
   distance from the base, and nothing about the remote.
4. **The conflict enumeration and its kinds** (§ 4) — `git status --porcelain`,
   `git diff --diff-filter=U`, `git ls-files -u`. `nen pr cascade-main --json` carries no
   `conflicts[]` at `v0.3.0` (verified live).
5. **Showing both sides** (§ 6) — `git show :1:|:2:|:3:<path>`. No verb renders a merge stage.
6. **The in-progress-merge check** (§ 2) — `.git/MERGE_HEAD` / `.git/rebase-merge` on disk;
   `nen wc classify` folds an unresolved merge into `on-branch-dirty` (verified live).

Every one of these is run in the open and reported as by-hand, per the Nen-first rule's second half
(`claude/agents/kurapika.md`): a missing verb is a finding, not a gap to route around silently.

## Authority

- **Permitted:** fetch; rebase an **unpublished** branch; merge the base into a published one;
  resolve a **mechanical** conflict; re-run the declared build; write the working copy and the local
  branch ref.
- **Not permitted:** push of any kind, force-push above all; rewriting any commit that exists on the
  remote; resolving a semantic conflict; `--no-verify`; touching `main`.
- **Carries no delegation**, and being invoked inside [`hatsu:aka`](../aka/SKILL.md),
  [`hatsu:murasaki`](../murasaki/SKILL.md) or [`hatsu:en`](../en/SKILL.md) does not lend it one.

## Hard limits

- **Never pushes.** Not on a clean merge, not "to save a step", not because the caller was going to
  push anyway. This is why `nen pr cascade-main` cannot be the verb here yet, and it is not
  negotiable for the convenience of using it.
- **Never rewrites a published commit** — the published/unpublished test (§ 3) runs before either
  operation, every time, and its answer is stated.
- **Never picks a side on a semantic conflict**, and never `-X ours` / `-X theirs` on any merge.
- **Never resolves anything before every conflicted path is classified and the table printed** (§ 4).
- **Never starts a second operation on top of a merge or rebase somebody already left in progress.**
- **Never commits a resolved merge without re-proving the declared build.**
- **Never leaves a conflicted checkout without saying so** and printing the abort line.
- **Never presents by-hand git as a verb's output** — every step in § Residue is named where it runs.
