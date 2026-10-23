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
names. **The `.ts` header is the rule** — the exit codes, the six admission conditions, the refusal line
and the facts — stated once there and cited here, never restated.

**One classifier** (hanten round 1, Chrollo and Nobunaga). The script admits and reports facts and the
one literal command, and prints no class: cleanup § 5 is the only class owner. The earlier `--pr-state`
flag, which made the script a second classifier, is gone and refused as an unknown argument.

**Round 2** (Chrollo, Feitan, Nobunaga, Phinks at `3727e0a`). § 5 gains its precedence (named facts,
then the reviewer ledger rule, then the table); a refusal prints `refused`, a fact, never the class
word `named`; nesting is compared on the disk's own spelling and any `.git` below the path refuses, so
an APFS case variant or a nested clone under an ignored directory is never deleted with its host; the
base must be spelled as `for-each-ref` prints it (`Main` refused); the shim exits `2`, never `1`, on a
missing node or one below 22.18; `_` joins the charset. An ignored worktree-local `.nen/` is reported
and not counted, under ROSTER § *Rulings of 2026-10-20*.

**Why TypeScript.** BC-11 admits no new three-way verdict script in shell, and the ruling of
2026-10-17 (#290 q3) freezes only the shell scripts that already existed. The admission is therefore
`node` on the `.ts` file, the `scripts/plugin_version_refs.ts` pattern, with the `.sh` shim keeping the
path § 4's call names (Shizuku cites that call).

**Hermetic proof** — `nen shu test --repo <hatsu> --lane cleanup-path-guard` (the script's
`--self-test`, a throwaway core under `$TMPDIR`, removed on every path; an interrupted run prints one
line naming the signal and exits non-zero). Every refusal asserts its reason, carries no command and
prints no class word; every exit-`2` case asserts its stderr reason and an empty stdout.

| Case | Asserted |
|---|---|
| `git check-ref-format --branch` on the absolute path | refuses it — why the old rule could not admit it |
| a listed worktree at `<home>/<surface>/<name>` | `admitted` with the quoted command after `--`; `head branch …`, `locked no`, `kind effort`, `tree clean`; no class printed |
| the same through the `sh` shim; a node reporting 22.14.0; no node on `PATH` | the same admission; exit `2` with `node >= 22.18 required (found v22.14.0…`; exit `2` with `node not found` |
| `_` in the core path and the name | `admitted` |
| dirty | `tree dirty 1`, `dirt ?? uncommitted.txt` |
| an ignored worktree-local `.nen/`; an ignored `.env` | `dirt !! .nen/ (worktree-local ledgers, removed with the worktree; disposable — …)` and `tree clean`; `dirt !! .env` and `tree dirty 1` |
| `git status` warns | `tree unreadable`, `dirt unreadable: …` |
| locked with a reason; a bare `git worktree lock`; detached; `hanten-chrollo-b`; `prove-1` | `locked yes: <reason>`; `locked yes`; `head detached`; `kind reviewer` twice |
| a detached worktree beside a sibling whose path forges `worktree`/`branch` lines | still `head detached`; no forged branch reaches its stanza |
| core; the trunk; outside the home | `refused outside the cleanup home`; `refused checked out on the trunk main` |
| `<home>/kagutsuchi`; `<home>/top` | `kagutsuchi's fixed worktree, kept`; `not at <home>/<surface>/<name>` |
| an unlisted directory; a nested repository under the home | `not listed by git worktree list` |
| a worktree holding a nested dirty worktree; the same registered in another case (APFS) | `contains another worktree: <escaped>` (the case row is printed `skip` on a case-sensitive disk) |
| a nested clone under an ignored `.nen/`; a directory the scan cannot read | `contains a nested repository: .nen/vendor/repo/.git`; `a directory below it could not be read: notes` |
| a prunable registration; a locked worktree whose directory is gone | `prunable: …`; `not a directory on disk` |
| a symlink; a symlinked `<surface>`; a symlinked `.nen`; a symlinked home | `the path is a symlink`; `the surface directory is a symlink`; `… .nen is a symlink`; `the cleanup home is a symlink` |
| an inventory `git worktree list` cannot read | `the worktree inventory is unreadable` |
| `..`; `.`; a trailing slash; relative; empty | the component reason; `not an absolute path` |
| a space; a single quote; a newline | the charset reason, the newline shown escaped as `?` |
| `--base` `refs/heads/main`, `heads/main`, `Main`, `@{-1}`, `a..b`; no `--base`; a flag with no value; core not a git checkout, a linked worktree, non-canonical, a symlink to core; an unknown or repeated flag; `--self-test x` | exit `2`, its reason on stderr, nothing on stdout |
| the script itself | removed nothing; the printed command, run by the fixture, removes the worktree |

**Live, read-only** (2026-10-19, before round 1, this checkout, nothing removed): the effort's own
worktree and its stacked base's under `<core>/.nen/worktrees/claude-code/` were `admitted`; core itself was
refused `outside the cleanup home`. No live cleanup was needed to show the distinction.
