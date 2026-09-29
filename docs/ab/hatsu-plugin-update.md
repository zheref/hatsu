# Evidence — plugin source update (`hatsu_plugin_update.sh`)

Hatsu `0.32.0`. The checked command behind [`hatsu-warmup`](../../claude/skills/hatsu-warmup/SKILL.md)
§ 4b: keep a consumer plugin checkout on trunk or the newest release tag, and name (or run) Claude
Code's `claude plugin update` for a versioned cache that is not a git checkout.

**Run:** 2026-09-17, branch `grok/kurapika/plugin-update-across-surfaces`, GNU bash 3.2 on darwin-arm64.
Every transcript below is `scripts/hatsu_plugin_update_fixture_check.sh` (or the named invocation on
the same throwaway layout). Paths are the fixture tempdir, written `<tmp>`.

## What it must do

- Fast-forward a clean clone that sits on the trunk when `origin/<branch.base>` has moved.
- Move a clean checkout that is detached at a `vX.Y.Z` tag to the newest such tag.
- Refuse (exit 2) a dirty tree, a feature branch asked to update `--channel trunk`, a diverged
  trunk, and a non-Hatsu directory (exit 3).
- `--auto`: skip those cases at exit 0, quoting the reason, so warm-up never halts on them.
- `--dry-run`: print the git plan and leave `HEAD` where it was.
- A Claude versioned cache (plugin.json + `claude/skills/`, no `.git`) is exit 4 without `--auto`,
  and a skip that names `claude plugin update hatsu@hatsu` with `--auto`. Never `git pull` a cache.

## Fixture, passing

```text
$ bash scripts/hatsu_plugin_update_fixture_check.sh
From <tmp>/origin
   <sha>..<sha>  main       -> origin/main
 * [new tag]         v0.2.0     -> v0.2.0
hatsu-plugin-update-fixture: ok
```

(exit `0`; git fetch progress is stderr from the live fast-forward inside the fixture.)

Cases the fixture asserted, in order: non-Hatsu refused; trunk already-current; `--dry-run` did not
move `HEAD` while origin was ahead; live fast-forward advanced the consumer and the reported plugin
version; `--auto` on a current trunk; dirty tree refused without `--auto` and skipped with it;
authoring branch skipped with `--auto` and refused for explicit `--channel trunk`; diverged trunk
refused; release channel dry-run left `v0.1.0` and the live run moved to `v0.2.0`; release
already-current; cache without `--auto` exited 4 naming `claude plugin update`; `--auto` on a cache
skipped; bad `--channel` refused; `GIT_DIR`/`GIT_WORK_TREE` left a decoy clone unmoved while `--root`
fast-forwarded; missing origin refused/`--auto` skipped; `--channel release` with only a pre-release
tag refused (exit 2) instead of silent exit 1.

## Hard limits recorded rather than implied

`--auto` on a commit that is both tagged `v0.2.0` *and* checked out as `feat/work` is an authoring
skip, not a release update. A named branch that is not the trunk is never a consumer channel, even
when `git describe --exact-match` would return a tag. That order was the first fixture failure, then
the detection rule.

## 2026-09-28 — the marketplace source is part of the claim (zheref/hatsu#118)

Observed on the maintainer's host: the `hatsu` marketplace is a Directory source
(`~/.claude/plugins/known_marketplaces.json` → `"source": "directory", "path": "/Users/zheref/Code/Agents/hatsu"`),
so `claude plugin update hatsu@hatsu -y` compares the versioned cache against that checkout and
reports "already at the latest version" whenever the two agree — 23 commits and four releases behind
`origin/main` on 2026-09-26..28, because nothing fast-forwarded the checkout. `--claude` now reads that
registry (one JSON shape, the `hatsu` entry's `source.path` when `source.source` is `directory`),
re-enters this script on the checkout with `--channel auto --auto` (a clean trunk fast-forwards; an
authoring branch, a diverged trunk, tracked changes, no origin or a failed fetch skip with the reason),
and carries the verdict in the report line beside the Claude refresh:

```text
$ scripts/hatsu_plugin_update.sh --root ~/.claude/plugins/cache/hatsu/hatsu/0.49.0 --auto --claude --dry-run
would run: git fetch origin
would run: git merge --ff-only origin/main
would run: claude plugin marketplace update
would run: claude plugin update hatsu@hatsu -y
hatsu-plugin-update: marketplace source /Users/zheref/Code/Agents/hatsu: dry-run · would fast-forward main from e2b704b · dry-run · claude plugin update hatsu@hatsu · plugin 0.49.0
```

Untracked files no longer read as dirty: only tracked modifications (`git status --untracked-files=no`)
skip or refuse, because a marketplace checkout always carries an untracked `.claude/` and `git merge
--ff-only` itself refuses a fast-forward that would overwrite an untracked file. The fixture gained
five cases: an untracked file beside a behind trunk still fast-forwards (and the count is reported); a
fake `claude` on `PATH` plus a fixture `CLAUDE_CONFIG_DIR` registry prove the dry run plans the
marketplace fast-forward and moves nothing, the live run fast-forwards the marketplace clone before
`claude plugin update` and compares the source manifest with the cache slot, an authoring-branch
marketplace clone is named `NOT brought current` and left unmoved, and a GitHub-sourced marketplace is
reported `not a Directory source` while the cache still refreshes. The first fixture run caught a real
defect — `${dry_run:+--dry-run}` passed `--dry-run` to the sub-run whenever `dry_run` was `0` — fixed
before this note was written.

**After the pre-PR review (2026-09-28).** Chrollo and Nobunaga both reproduced the one path the
untracked-file relaxation opened: an untracked file that an incoming commit also adds makes `git merge
--ff-only` refuse, and under `set -e` the script died with git's text and no report line. The refusal is
now a skip with its reason (`skipped · fast-forward refused by git (a working-tree file would be
overwritten) · staying at main @<sha>`), fixture-proven with the file left intact. Feitan showed the self
re-entry took its path from `$0`, which under `bash -s < script` is `bash` and would have executed
`./bash` from the working directory: the script now locates itself through `BASH_SOURCE`, re-enters as
`bash "$self_script"` only when that is a regular file, and otherwise reports the source as not examined;
the fallback report clause carries one bounded line of the sub-run's output (exit code, last line,
control characters stripped, 200 characters), never the whole stream; a relative registry path is
refused; and a registry that exists but is not in the one shape Claude Code writes is named as such,
distinct from an absent one. The trust anchor is stated in the header: the marketplace checkout's own
`origin` and branch protection, exactly as for `--channel trunk` on any consumer checkout.
