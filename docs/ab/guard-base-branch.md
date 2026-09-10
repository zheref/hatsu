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

**§ 3.3 and § 3.4 were added on 2026-09-10 on `fable/kurapika/wave-4`**, settling the two threads
Copilot opened against this script on PR #32. Same host, same git, a sixth checkout added to the
fixture; the whole header sweep was re-run against the amended script, not just the new rows.

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

Three repositories, six checkouts, built by a script (so that seeding them does not itself trip the
live guard) and deleted afterwards:

| path | branch | `branch.base` declared |
|---|---|---|
| `$FIX/trunk` | `main` | `main` |
| `$FIX/feature` — a **linked worktree** of `trunk` | `feat/x` | `main` |
| `$FIX/spaced dir/repo` | `main` | `main` |
| `$FIX/dev-repo` | `main` | `develop` |
| `$FIX/dev-repo-wt` — a **linked worktree** of `dev-repo` | `develop` | `develop` |
| `$FIX/wt2` — a second **linked worktree** of `trunk` (added for § 3.4) | `b2` | `b2` |

`$FIX/feature/.git` is a file holding `gitdir: $FIX/trunk/.git/worktrees/feature`, which is the whole
point of the second, fifth and sixth rows: `git --git-dir=<that file> branch --show-current` answers `feat/x`,
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

All fifty-seven cases in the script's header were run against the fixed script in one pass and every one
matched the exit code the header records: fourteen standing on the base branch, twenty-one standing on a
feature branch, two in the `develop`-declaring checkout, fourteen in the directory-git-targets group, and
the six added by the two Copilot threads below. Nothing that
passed before this change regresses — the compound-command refusal (`git switch main && git commit`,
`git checkout main; git push`, `git branch -f main HEAD && git push`), the shell-wrapper unwrapping
(`bash -c "cd <main> && git push"` → `2`, `sh -c 'git status'` → `0`), the quoted-span masking
(`echo 'git commit'` → `0`, `git log --format='git push'` → `0`), `git commit-tree` → `0`, the declared
`develop` base, and detached HEAD / non-repository paths passing through (`git -C <a path that does not
exist> push` → `0`) all hold.

### 3.3 A quoted selector in more than one segment (Copilot review round 1, PR #32)

Recovery is **line-global**: the masked segment holds `@`, and the path is read back out of the raw
command line with a greedy `sed`, which finds the LAST such span whichever segment wrote it. Copilot's
thread on `hooks/guard-base-branch.sh:410-413` said so, and it reproduces in both directions against
this fixture — cwd on `feat/x`, `$T` = `$FIX/trunk` (on `main`), `$W` = `$FIX/feature` (on `feat/x`):

| payload | before | after |
|---|---|---|
| `git -C '$T' commit -m x && git -C '$W' status` | **`0`** — a commit on `main` allowed | **`2`** |
| `git -C '$W' commit -m x && git -C '$T' status` | `2` — but *on the wrong repository's branch* | `2` — on the ambiguity |
| `git -C '$W' commit -m x && git -C '$W' push` | `0` | `0` — one distinct path, read |
| `git -C '$T' commit -m x && git -C '$T' push` | `2` | `2` |

The first row is the one that mattered: the write segment targeted the trunk and was judged against the
worktree, so the guard waved a commit on the base branch through. The second row reached `2` for a
reason that was not true. Both now refuse on the fact that is true:

```
$ printf '{"cwd":"$W","tool_input":{"command":"git -C '\''$T'\'' commit -m x && git -C '\''$W'\'' status"}}' \
    | hooks/guard-base-branch.sh; echo "exit $?"
hatsu: refusing this command — it writes more than one different quoted `-C` path, and this guard
cannot tell which segment each of them belongs to, so the branch the write would land on cannot be
established; run the git command directly, from inside the repository it targets.
exit 2
```

**Two IDENTICAL quoted paths are not ambiguous and are still read** (row 3) — which keeps the shape a
worktree effort with a spaced path actually types, `git -C '<wt>' commit … && git -C '<wt>' push`,
working. The check is `selector_conflicts`, which walks every quoted span for the flag with
`${rest#*"$flag"}` (shortest-prefix, so forwards) instead of one greedy match, and refuses only when two
of them differ. It runs in the script's own shell, not in a `$( … )`, because an `exit` inside a command
substitution ends the subshell and lets the script carry on.

### 3.4 The policy behind a bare `--git-dir` (Copilot review round 1, PR #32)

The branch was read out of the worktree's `.git` file; `branch.base` was read out of the **primary**
checkout, because `root` came from the parent of the *common* git dir. The two are different working
trees, and a worktree that has a different `nen/workflow.json` checked out is judged against a base
nobody declared for it. A sixth checkout was added to the fixture to show it — `$FIX/wt2`, a linked
worktree of `trunk` standing on `b2`, whose own committed `nen/workflow.json` declares
`"base": "b2"`, while `trunk`'s declares `main`:

```
$ printf '{"cwd":"$FIX/trunk","tool_input":{"command":"git --git-dir=$FIX/wt2/.git commit -m x"}}' \
    | hooks/guard-base-branch.sh; echo "exit $?"
exit 0                                         # before: branch b2 vs trunk's base main
```

```
hatsu: refusing git commit on b2 — b2 is the workflow base (nen/workflow.json branch.base) and is only
ever reached through a merged PR; cut {model}/{persona}/{descriptor} with the breath skill (nen shu
warmup --repo <path> --branch <name>) and commit there.
exit 2                                         # after: b2 vs wt2's own base b2
```

The resolution is git's own data, not a guess. `git --git-dir=<wt>/.git rev-parse
--path-format=absolute --git-dir` answers `$FIX/trunk/.git/worktrees/wt2`, and the `gitdir` file sitting
in that directory holds `$FIX/wt2/.git` — the worktree's own `.git` file, whose directory is the
checkout the branch came from. Only when the resolved git dir carries no `/worktrees/` segment (a
primary checkout, or a bare repository) does the common dir's parent still answer, exactly as before, so
`--git-dir=<primary>/.git` and `--git-dir=<worktree on feat/x>/.git` are unchanged.

## 4. Residue

- **Two DIFFERENT quoted paths for one flag fail closed, wherever on the line they sit.** Recovery is
  line-global, so `git -C '<a>' -C '<b>' commit` and `git -C '<a>' commit && git -C '<b>' status` are
  both refused (`exit 2`) rather than answered from a span that belongs to the other segment (§ 3.3).
  Reading the *n*th quoted span positionally would need a pass this script does not want; the refusal
  names the reason and the fix is to run the command from inside the repository it targets. Two
  identical ones carry no ambiguity and are read.
- **`rev-parse --show-toplevel` still cannot be used under a bare `--git-dir`** — it answers about the
  cwd. The checkout is instead recovered from the resolved git dir's own `gitdir` file for a linked
  worktree (§ 3.4), and from the common dir's parent otherwise. A `--git-dir` pointing at a **bare**
  repository therefore reads `nen/workflow.json` from that repository's parent directory, where there
  will not be one, and the default `main` applies. No repository in bounds is bare.
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
