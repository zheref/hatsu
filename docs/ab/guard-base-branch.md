# Evidence — the base-branch guard judges the directory git targets

[`hooks/guard-base-branch.sh`](../../hooks/guard-base-branch.sh), the `PreToolUse` hook on `Bash`
declared in [`hooks/hooks.json`](../../hooks/hooks.json).

This file is not a skill A/B — it is the **hook's own acceptance evidence**, the companion to the case
list in the script's header. Every transcript below was produced by feeding the committed script a real
JSON payload on stdin, the way Claude Code feeds it; nothing is reconstructed.

**Run:** 2026-09-10 (local clock), branch `opus/kurapika/hook-worktree-fix` cut from
`fable/kurapika/wave-3` at `2e066ab`. `/bin/sh` is bash `3.2.57` in POSIX mode (`arm64-apple-darwin`,
macOS 26.4.1), git `2.50.1`. No `jq`, no `python` in the hook itself — `python3` appears only in the
harness that *builds* the payloads, standing in for the harness that normally does.

*The fixture root — a throwaway directory under the session scratchpad, deleted after this run — appears
below as `$FIX`. Nothing else is altered; both repositories are public and nothing here is redacted.*

---

## 1. The defect

The guard refuses `git commit` / `git push` while the checkout stands on `branch.base`. It read that
branch from **the session's working directory**, and a worktree effort does not work that way: the
session's cwd is the primary checkout, sitting on `main`, and every write is aimed elsewhere with
`git -C <worktree> …`. Judging the session's own branch answers the wrong question in both directions —
it can refuse a write that would land on a feature branch, and it can wave through one that would land
on the trunk.

The single-`-C` form was already handled before this change (§ 3 records it passing against the
pre-fix script too, so the incident as reported did **not** reproduce in its simplest shape — see § 5).
Three shapes were genuinely misjudged, and all three are shapes a worktree effort types:

| shape | pre-fix | why it was wrong |
|---|---|---|
| `git -C <a> -C <b> commit` | last `-C` wins | git applies them **cumulatively** — the command runs in `a/b`, not in `b` |
| `git --git-dir=<worktree>/.git push` | not judged at all | a linked worktree's `.git` is a **file**; the guard tested `-d` and skipped |
| `git --nonsense-flag commit -m x` | walked past | an unknown global option may swallow the next token, which is what decides where the subcommand and the `-C` path are |

The last of those also made the script's own header **untrue**: it claimed exit `2` for
`git --nonsense-flag commit -m x` on a feature branch, and the script returned `0`.

## 2. The fixture

Three repositories, five checkouts, built by a script (so that seeding them does not itself trip the
live guard) and deleted afterwards:

| path | branch | `branch.base` declared |
|---|---|---|
| `$FIX/trunk` | `main` | `main` |
| `$FIX/feature` — a **linked worktree** of `trunk` | `feat/x` | `main` |
| `$FIX/spaced dir/repo` | `main` | `main` |
| `$FIX/dev-repo` | `main` | `develop` |
| `$FIX/dev-repo-wt` — a **linked worktree** of `dev-repo` | `develop` | `develop` |

`$FIX/feature/.git` is a file holding `gitdir: $FIX/trunk/.git/worktrees/feature`, which is the whole
point of the fourth and fifth rows: `git --git-dir=<that file> branch --show-current` answers `feat/x`,
and `rev-parse --path-format=absolute --git-common-dir` gives `$FIX/trunk/.git`, whose parent is where
`nen/workflow.json` is read from when no `--work-tree` was given.

## 3. Cases exercised live

Invoked exactly as documented — payload on stdin, exit code read straight after:

```
$ printf '{"cwd":"$FIX/trunk","tool_input":{"command":"git -C $FIX/feature push -u origin feat/x"}}' \
    | hooks/guard-base-branch.sh; echo "exit $?"
exit 0
```

A session standing on `main`, pushing a worktree that stands on `feat/x`: **allowed**. The mirror:

```
$ printf '{"cwd":"$FIX/feature","tool_input":{"command":"git -C $FIX/trunk commit -m x"}}' \
    | hooks/guard-base-branch.sh; echo "exit $?"
hatsu: refusing git commit on main — main is the workflow base (nen/workflow.json branch.base) and is
only ever reached through a merged PR; cut {model}/{persona}/{descriptor} with the breath skill (nen shu
warmup --repo <path> --branch <name>) and commit there.
exit 2
```

Two `-C` flags, applied cumulatively — the pair arrives on `main` and is refused, and the pair that
arrives on `feat/x` is allowed, from a cwd whose own branch would have answered the other way each time:

```
$ printf '{"cwd":"$FIX/feature","tool_input":{"command":"git -C $FIX -C trunk commit -m x"}}' \
    | hooks/guard-base-branch.sh; echo "exit $?"
hatsu: refusing git commit on main — main is the workflow base (nen/workflow.json branch.base) and is
only ever reached through a merged PR; cut {model}/{persona}/{descriptor} with the breath skill (nen shu
warmup --repo <path> --branch <name>) and commit there.
exit 2

$ printf '{"cwd":"$FIX/trunk","tool_input":{"command":"git -C $FIX -C feature push"}}' \
    | hooks/guard-base-branch.sh; echo "exit $?"
exit 0
```

`--git-dir` is **followed, not refused** — the transcript below is the proof that the `.git` *file* of a
linked worktree is read, and that the base is taken from the repository that owns it (`develop`, not the
default `main`):

```
$ printf '{"cwd":"$FIX/trunk","tool_input":{"command":"git --git-dir=$FIX/dev-repo-wt/.git commit -m x"}}' \
    | hooks/guard-base-branch.sh; echo "exit $?"
hatsu: refusing git commit on develop — develop is the workflow base (nen/workflow.json branch.base) and
is only ever reached through a merged PR; cut {model}/{persona}/{descriptor} with the breath skill (nen
shu warmup --repo <path> --branch <name>) and commit there.
exit 2

$ printf '{"cwd":"$FIX/trunk","tool_input":{"command":"git --git-dir=$FIX/feature/.git push"}}' \
    | hooks/guard-base-branch.sh; echo "exit $?"
exit 0
```

And the option the walk cannot follow, named in its own refusal:

```
$ printf '{"cwd":"$FIX/trunk","tool_input":{"command":"git --nonsense-flag -C $FIX/feature push"}}' \
    | hooks/guard-base-branch.sh; echo "exit $?"
hatsu: refusing this command — it carries the git global option `--nonsense-flag`, which this guard does
not know; an unknown option may or may not take the token after it, so neither the subcommand nor the
directory git would run in can be established. Run the git command directly, from inside the repository
it targets.
exit 2
```

### 3.1 The same payloads against the pre-fix script

Run against `fable/kurapika/wave-3`'s copy, unchanged, to show which of these the fix actually moved:

| payload | pre-fix | post-fix |
|---|---|---|
| `-C <worktree> push`, cwd on `main` | `0` | `0` |
| `-C <trunk> commit`, cwd on `feat/x` | `2` | `2` |
| `-C $FIX -C trunk commit`, cwd on `feat/x` | **`0`** | **`2`** |
| `-C $FIX -C feature push`, cwd on `main` | `0` (by accident — the path resolved to nothing) | `0` (by arriving in the worktree) |
| `--git-dir=<worktree on develop>/.git commit` | **`0`** | **`2`** |
| `--nonsense-flag -C <worktree> push`, cwd on `main` | `0` | **`2`** |
| `--nonsense-flag commit -m x`, cwd on `feat/x` | **`0`** (header claimed `2`) | **`2`** |

### 3.2 The full sweep

All fifty-one cases in the script's header were run against the fixed script in one pass and every one
matched the exit code the header records: fourteen standing on the base branch, twenty-one standing on a
feature branch, two in the `develop`-declaring checkout, and fourteen in the new group. Nothing that
passed before this change regresses — the compound-command refusal (`git switch main && git commit`,
`git checkout main; git push`, `git branch -f main HEAD && git push`), the shell-wrapper unwrapping
(`bash -c "cd <main> && git push"` → `2`, `sh -c 'git status'` → `0`), the quoted-span masking
(`echo 'git commit'` → `0`, `git log --format='git push'` → `0`), `git commit-tree` → `0`, the declared
`develop` base, and detached HEAD / non-repository paths passing through (`git -C <a path that does not
exist> push` → `0`) all hold.

## 4. Residue

- **A second quoted `-C` on one segment fails closed.** Recovery reads one quoted span per flag, so
  `git -C '<a>' -C '<b>' commit` cannot be told apart and is refused (`exit 2`) rather than assembled
  from the wrong half. Recovering the *n*th quoted span would need an `awk` pass this script does not
  want; the refusal names the reason and the fix is to run the command from inside the repository.
- **The `nen/workflow.json` read behind a bare `--git-dir`** comes from the parent of the *common* git
  dir — the primary checkout — because `rev-parse --show-toplevel` under `--git-dir` alone answers about
  the cwd instead. A repository whose primary checkout declares a different `branch.base` than the
  worktree's own checked-out copy would be judged by the primary's. No repository in bounds does that.
- **`--path-format=absolute` needs git ≥ 2.31**; below that the script falls back to the parent of the
  path given to `--git-dir`, which is the worktree root for the `.git`-file form and the repository root
  for the directory form. Both carry `nen/workflow.json`. Not exercised here (this host is 2.50.1).

## 5. Findings against the binary

Filed nowhere, listed here.

1. **The incident that prompted this change did not reproduce in its stated form.** A session with its
   cwd on `main` running `git -C <feature worktree> push …` is allowed by the *pre-fix* script (§ 3.1,
   row 1), and so are the realistic dressings of it that were tried: `&&` chains of `-C` commands, a
   trailing `2>&1 | tail -5`, a `$( … )` subshell, a quoted `-C` path, `--no-pager` before the `-C`, and
   `-c user.name=…` after it. The three defects in § 1 are real and are fixed; **which of them the
   observed session actually hit was not established**, and it may have been a shape none of these
   reproduce. Anyone who sees it again should keep the exact command line.
2. **A refusal reaches the model as a hook error, not as a tool result.** During this work the live
   guard refused the fixture's own seed commit (correctly — the fixture repository was on `main`), which
   is how the hook was confirmed to be running from this checkout rather than an installed copy. Worth
   knowing that a fixture that needs a commit on a trunk must do it from inside a script file, where the
   guard sees `sh setup-fixture.sh` and nothing else.
3. **The guard is still blind to what a script file contains.** That is the same fact as (2) seen from
   the other side, and it is by design — the guard parses the command line it is given, not the
   filesystem — but it means the reflex is defeated by one indirection. It is a reflex under the skills,
   not a boundary.
