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
`scripts/cleanup_path_admit.ts`, behind the forwarding shim `scripts/cleanup_path_admit.sh` that § 4
names; the `.ts` header is the rule, stated once there and cited, never restated: `--core` canonical
and the repository's main worktree; `--base` a short trunk name that exists (`refs/…`, `heads/main`
and `@{-1}` refused at exit `2`); the path absolute, `^/[A-Za-z0-9._/-]+$` (locale-free), no empty,
`.` or `..` component and no trailing slash (traversal refused as spelled, never normalised); exactly
`<core>/.nen/worktrees/<surface>/<name>` (kagutsuchi's fixed `<home>/kagutsuchi` kept); no symlink on
the way; listed exactly in `git worktree list --porcelain -z`, read NUL-split; not prunable; holding no
other worktree; not checked out on the trunk. A refused path is exit `1` and one named row with its
reason, the escaped path and no command.

**One classifier** (hanten round 1, Chrollo and Nobunaga). The script admits and reports facts —
`head`, `locked`, `kind` (`reviewer` for `hanten-*` and `prove-*`), `tree` and one `dirt` line per
`git status --porcelain -z --ignored` entry or status warning — and prints the one literal command,
`git -C '<core>' worktree remove -- '<path>'`, which § 5 cites word for word. It prints no class:
cleanup § 5's table, read from these facts and `nen wc classify`, is the only class owner, and a
reviewer checkout is classed by the ledger rule alone. The earlier `--pr-state` flag, which made the
script a second classifier, is gone and refused as an unknown argument.

**Why TypeScript.** BC-11 admits no new three-way verdict script in shell, and the ruling of
2026-10-17 (#290 q3) freezes only the shell scripts that already existed. The admission is therefore
`node` on the `.ts` file, the `scripts/plugin_version_refs.ts` pattern, with the `.sh` shim keeping the
path § 4 and Shizuku cite.

**Hermetic proof** — `nen shu test --repo <hatsu> --lane cleanup-path-guard` (the script's
`--self-test`, a throwaway core under `$TMPDIR`, removed on every path; an interrupted run prints one
line naming the signal and exits non-zero):

| Case | Asserted |
|---|---|
| `git check-ref-format --branch` on the absolute path | refuses it — why the old rule could not admit it |
| a listed worktree at `<home>/<surface>/<name>` | `admitted` with the quoted command after `--`; `head branch …`, `locked no`, `kind effort`, `tree clean`; no class printed |
| the same through the `sh` shim | the same admission |
| dirty | `tree dirty 1`, `dirt ?? uncommitted.txt` |
| an ignored worktree-local `.nen/`; an ignored `.env` | `dirt !! .nen/ (worktree-local ledgers, kept)`; `dirt !! .env`; never `tree clean` |
| `git status` warns it could not open a directory | `tree unreadable`, `dirt unreadable: …` |
| locked with a reason; detached; `hanten-chrollo-b` | `locked yes: <reason>`; `head detached`; `kind reviewer` |
| a detached worktree beside a sibling whose path forges `worktree`/`branch` lines | still `head detached`; no forged branch reaches its stanza |
| core; the trunk; outside the home | `refused: outside the cleanup home`; `refused: checked out on the trunk main` |
| `<home>/kagutsuchi`; `<home>/top` | `refused: kagutsuchi's fixed worktree, kept`; `refused: not at <home>/<surface>/<name>` |
| an unlisted directory; a nested repository under the home | `refused: not listed by git worktree list` |
| a worktree holding a nested dirty worktree | `refused: contains another worktree: <escaped>` |
| a prunable registration | `refused: prunable: …` |
| a symlink; a symlinked `.nen`; a symlinked home | `refused: the path is a symlink`; `… .nen is a symlink`; `the cleanup home is a symlink` |
| an inventory `git worktree list` cannot read | `refused: the worktree inventory is unreadable` |
| `..`; `.`; a trailing slash; relative; empty | the component reason; `not an absolute path` |
| a space; a single quote; a newline | the charset reason, the newline shown escaped as `?` |
| every refusal | carries no command |
| `--base refs/heads/main`, `heads/main`, `@{-1}`; no `--base`; core not a git checkout; a linked or non-canonical core; an unknown or repeated flag | exit `2`, nothing printed on stdout |
| the script itself | removed nothing; the printed command, run by the fixture, removes the worktree |

**Live, read-only** (2026-10-19, before round 1, this checkout, nothing removed): the effort's own
worktree and its stacked base's under `<core>/.nen/worktrees/claude-code/` were `admitted`; core itself was
refused `outside the cleanup home`. No live cleanup was needed to show the distinction.
