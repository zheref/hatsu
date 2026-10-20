# Evidence — `cleanup` (new skill, Hatsu 0.108.0; worktree-path admission 0.119.0)

`claude/skills/cleanup/SKILL.md`: Shizuku's sweep after a session delivery — inventory (§ 4), a plan in
three classes (§ 5), one picker (§ 6), then only the picked rows. This file holds the evidence the skill
cites, so the skill's diet stays spent on rules.

---

## 1. Invocation grammar (moved from SKILL § 1)

Verified at nen `0.21.0` (2026-10-13):

```
nen parse cleanup --grammar "for [<scope>]" --line "for HA#210"   → scope: HA#210, exit 0
nen parse cleanup --grammar "for [<scope>]" --line ""             → the clause absent, exit 0
nen parse cleanup --grammar "for [<scope>]" --line "HA#210"       → exit 2
```

## 2. Worktree-path admission — a path is not a ref ([#333](https://github.com/zheref/hatsu/issues/333))

**The contradiction.** Through 0.118.0, § 4 required every name taken from the repository — "a branch, a
remote head, a worktree path" — to pass `git check-ref-format --branch <name>`. A native worktree path
is absolute, and a leading `/` is not a legal branch name, so every worktree under the declared
`.nen/worktrees/` home was refused into a named row, and § 5's deterministic
`git worktree remove -- <wt>` for a clean merged worktree could never become selectable.

**The correction.** Branches and remote heads keep the ref rule. A worktree path is admitted by
`scripts/cleanup_path_admit.sh`, whose header is the rule: `--core` canonical and the repository's main
worktree; the path absolute, `^/[A-Za-z0-9._/-]+$` under `LC_ALL=C`, no empty, `.` or `..` component and
no trailing slash (traversal refused as spelled, never normalised); strictly under `<core>/.nen/worktrees/`;
no symlink on the way (`.nen`, the home, the path itself, `cd -P` resolving to itself, its own
`--show-toplevel`); listed exactly in `git worktree list --porcelain`; not checked out on the trunk. A
refused path is exit `1` and one named row with the escaped path and no command. With `--pr-state`, an
admitted path is classed by § 5's worktree rows and carries the one literal command,
`git -C '<core>' worktree remove -- '<path>'`, printed and never run — the maintainer's pick runs it.
Nothing in the correction adds a force form, a new object class or a deletion without the pick.

**Hermetic proof** — `nen shu test --repo <hatsu> --lane cleanup-path-guard` (the script's
`--self-test`, a throwaway core under `$TMPDIR`):

| Case | Result |
|---|---|
| `git check-ref-format --branch` on the absolute path | refuses it — why the old rule could not admit it |
| a listed worktree under the home | `admitted`, with the quoted command after `--` |
| clean, on a branch, PR merged | `deterministic` — selectable at the picker |
| clean, PR closed or no PR; clean but detached | `proposed` |
| dirty, PR merged | `proposed`, every dirty path listed on a `dirt` line |
| locked; PR open | `named`, no command |
| core itself; the trunk's worktree; a listed worktree outside the home; an unlisted directory | refused, `named` |
| a symlink to a worktree; a symlinked `.nen`; `..`; `.`; a trailing slash; relative; empty | refused, `named` |
| a space; a single quote; a newline (shown escaped as `?`) | refused, `named` |
| a missing `--base`; an unknown `--pr-state`; a linked worktree or a non-canonical path as `--core` | exit `2` |
| the script itself | removed nothing; the printed command, run by the fixture, removes the worktree |

**Live, read-only** (2026-10-19, this checkout, no `--pr-state`, nothing removed): the effort's own
worktree and its stacked base's under `<core>/.nen/worktrees/claude-code/` were `admitted`; core itself was
refused `outside the cleanup home`. No live cleanup was needed to show the distinction.
