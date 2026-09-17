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
