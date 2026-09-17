#!/usr/bin/env bash
# Prove scripts/hatsu_plugin_update.sh: trunk fast-forward, release-tag catch-up,
# dirty/authoring/cache refusals, --auto skips, --dry-run mutates nothing.

set -euo pipefail
LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
hatsu_root="$(CDPATH='' cd -- "$script_dir/.." >/dev/null 2>&1 && pwd -P)"
updater="$hatsu_root/scripts/hatsu_plugin_update.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-plugin-update.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "hatsu-plugin-update-fixture: $*" >&2
  exit 1
}

assert_fails() {
  local message="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$message"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "$message: expected '$needle' in: $haystack" ;;
  esac
}

write_plugin_json() {
  local directory="$1" version="${2:-0.1.0}"
  mkdir -p "$directory/.claude-plugin" "$directory/claude/skills/demo"
  printf '%s\n' '{
  "name": "hatsu",
  "version": "'"$version"'"
}' > "$directory/.claude-plugin/plugin.json"
  printf '%s\n' '---' 'name: demo' '---' > "$directory/claude/skills/demo/SKILL.md"
}

init_repo() {
  local directory="$1"
  git init -q "$directory"
  git -C "$directory" config user.email 'fixture@example.invalid'
  git -C "$directory" config user.name 'Hatsu fixture'
  git -C "$directory" checkout -q -b main
}

commit_tree() {
  local directory="$1" message="$2"
  git -C "$directory" add -A
  git -C "$directory" commit -qm "$message"
}

# --- not a Hatsu checkout ---
not_hatsu="$fixture_root/not-hatsu"
init_repo "$not_hatsu"
printf 'nope\n' > "$not_hatsu/README.md"
commit_tree "$not_hatsu" 'not hatsu'
assert_fails "non-Hatsu checkout was accepted" "$updater" --root "$not_hatsu"

# --- origin + consumer clone on trunk ---
origin="$fixture_root/origin.git"
git init -q --bare "$origin"

seed="$fixture_root/seed"
init_repo "$seed"
write_plugin_json "$seed" '0.1.0'
printf 'first\n' > "$seed/README.md"
commit_tree "$seed" 'v0.1.0 seed'
git -C "$seed" tag v0.1.0
git -C "$seed" remote add origin "$origin"
git -C "$seed" push -q origin HEAD:main
git -C "$seed" push -q origin v0.1.0

consumer="$fixture_root/consumer"
git clone -q "$origin" "$consumer"
git -C "$consumer" config user.email 'fixture@example.invalid'
git -C "$consumer" config user.name 'Hatsu fixture'

# already current
current_out="$("$updater" --root "$consumer" --channel trunk)"
assert_contains "$current_out" 'already current' 'trunk already-current report'
assert_contains "$current_out" 'plugin 0.1.0' 'plugin version on already-current'

# dry-run does not move HEAD when origin is ahead
write_plugin_json "$seed" '0.2.0'
printf 'second\n' > "$seed/README.md"
commit_tree "$seed" 'v0.2.0'
git -C "$seed" tag v0.2.0
git -C "$seed" push -q origin HEAD:main
git -C "$seed" push -q origin v0.2.0

before="$(git -C "$consumer" rev-parse HEAD)"
dry_out="$("$updater" --root "$consumer" --channel trunk --dry-run)"
assert_contains "$dry_out" 'would run: git fetch origin' 'dry-run fetch'
assert_contains "$dry_out" 'would run: git merge --ff-only origin/main' 'dry-run merge'
[ "$(git -C "$consumer" rev-parse HEAD)" = "$before" ] || fail "dry-run moved HEAD"

# actual fast-forward
ff_out="$("$updater" --root "$consumer" --channel trunk)"
assert_contains "$ff_out" 'updated trunk main' 'trunk fast-forward report'
assert_contains "$ff_out" 'plugin 0.2.0' 'plugin version after ff'
[ "$(git -C "$consumer" rev-parse HEAD)" = "$(git -C "$seed" rev-parse HEAD)" ] || fail "consumer did not fast-forward to origin"

# --auto on already current
auto_current="$("$updater" --root "$consumer" --auto)"
assert_contains "$auto_current" 'already current' '--auto already current'

# dirty tree refuses without --auto, skips with --auto
printf 'dirty\n' > "$consumer/README.md"
assert_fails "dirty tree was updated" "$updater" --root "$consumer" --channel trunk
dirty_auto="$("$updater" --root "$consumer" --auto)"
assert_contains "$dirty_auto" 'skipped · dirty working copy' '--auto dirty skip'
git -C "$consumer" checkout -q -- README.md

# authoring branch: --auto skips, explicit trunk refuses
git -C "$consumer" checkout -q -b feat/work
auto_feat="$("$updater" --root "$consumer" --auto)"
assert_contains "$auto_feat" 'skipped · authoring checkout' '--auto authoring skip'
assert_fails "feature branch accepted for explicit trunk" "$updater" --root "$consumer" --channel trunk
git -C "$consumer" checkout -q main

# diverged trunk refuses
git -C "$consumer" commit --allow-empty -qm 'local-only'
assert_fails "diverged trunk was fast-forwarded" "$updater" --root "$consumer" --channel trunk
git -C "$consumer" reset -q --hard origin/main

# release channel: pin to v0.1.0, catch up to v0.2.0
git -C "$consumer" checkout -q v0.1.0
rel_dry="$("$updater" --root "$consumer" --channel release --dry-run)"
assert_contains "$rel_dry" 'would check out release v0.2.0' 'release dry-run'
[ "$(git -C "$consumer" describe --tags --exact-match)" = 'v0.1.0' ] || fail "release dry-run left the tag"
rel_out="$("$updater" --root "$consumer" --channel release)"
assert_contains "$rel_out" 'updated release v0.1.0 → v0.2.0' 'release catch-up'
[ "$(git -C "$consumer" describe --tags --exact-match)" = 'v0.2.0' ] || fail "release channel did not check out latest tag"
rel_current="$("$updater" --root "$consumer" --channel release)"
assert_contains "$rel_current" 'already current · release v0.2.0' 'release already-current'

# versioned cache (plugin tree, no git) — not a git checkout
cache="$fixture_root/cache/hatsu/0.14.0"
write_plugin_json "$cache" '0.14.0'
set +e
cache_err="$("$updater" --root "$cache" 2>&1)"
cache_code=$?
set -e
[ "$cache_code" -eq 4 ] || fail "cache without --auto exited $cache_code, expected 4"
assert_contains "$cache_err" 'not a git checkout' 'cache refusal names the cache'
assert_contains "$cache_err" 'claude plugin update hatsu@hatsu' 'cache refusal names the Claude command'

# --auto on a cache skips (or attempts claude); must not exit 4
cache_auto="$("$updater" --root "$cache" --auto)"
assert_contains "$cache_auto" 'skipped · Claude versioned plugin cache' '--auto cache skip'
assert_contains "$cache_auto" 'claude plugin update hatsu@hatsu' '--auto cache names the Claude command'

# usage
assert_fails "bad channel was accepted" "$updater" --root "$consumer" --channel sideways

echo 'hatsu-plugin-update-fixture: ok'
