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
assert_fails "diverged trunk dry-run planned a fast-forward" "$updater" --root "$consumer" --channel trunk --dry-run
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

# GIT_DIR/GIT_WORK_TREE must not redirect mutations away from --root
write_plugin_json "$seed" '0.3.0'
printf 'third\n' > "$seed/README.md"
commit_tree "$seed" 'v0.3.0'
git -C "$seed" push -q origin HEAD:main
git -C "$consumer" checkout -q main
decoy="$fixture_root/decoy"
git clone -q "$origin" "$decoy"
git -C "$decoy" config user.email 'fixture@example.invalid'
git -C "$decoy" config user.name 'Hatsu fixture'
# decoy is already at origin/main; rewind it so a redirected update would move it
git -C "$decoy" reset -q --hard HEAD~1
decoy_before="$(git -C "$decoy" rev-parse HEAD)"
GIT_DIR="$decoy/.git" GIT_WORK_TREE="$decoy" \
  "$updater" --root "$consumer" --channel trunk >/dev/null
[ "$(git -C "$decoy" rev-parse HEAD)" = "$decoy_before" ] || fail "GIT_DIR decoy moved"
[ "$(git -C "$consumer" rev-parse HEAD)" = "$(git -C "$seed" rev-parse HEAD)" ] || fail "GIT_DIR redirected --root away from the consumer"

# missing origin: refuse / --auto skip
no_origin="$fixture_root/no-origin"
git clone -q "$origin" "$no_origin"
git -C "$no_origin" remote remove origin
assert_fails "missing origin was updated" "$updater" --root "$no_origin" --channel trunk
no_origin_auto="$("$updater" --root "$no_origin" --auto)"
assert_contains "$no_origin_auto" 'skipped · no origin remote' '--auto missing origin skip'

# --channel release with only a pre-release tag must refuse, not silent-exit.
# Own origin so fetch --tags cannot restore the shared clone's stable tags.
rc_only="$fixture_root/rc-only"
git clone -q "$origin" "$rc_only"
git -C "$rc_only" tag -d v0.1.0 v0.2.0 >/dev/null 2>&1 || true
git -C "$rc_only" tag v0.1.0-rc.1
rc_origin="$fixture_root/rc-origin.git"
git init -q --bare "$rc_origin"
git -C "$rc_only" remote remove origin
git -C "$rc_only" remote add origin "$rc_origin"
git -C "$rc_only" push -q origin HEAD:main
git -C "$rc_only" push -q origin v0.1.0-rc.1
set +e
rc_err="$("$updater" --root "$rc_only" --channel release 2>&1)"
rc_code=$?
set -e
[ "$rc_code" -eq 2 ] || fail "release with no stable tags exited $rc_code, expected 2"
assert_contains "$rc_err" 'no vX.Y.Z release tags' 'release channel names missing stable tags'

# nested Hatsu tree without its own .git must not mutate the enclosing repo
host_repo="$fixture_root/host-repo"
init_repo "$host_repo"
printf 'outer\n' > "$host_repo/README.md"
commit_tree "$host_repo" 'outer'
host_before="$(git -C "$host_repo" rev-parse HEAD)"
nested="$host_repo/vendor/hatsu"
write_plugin_json "$nested" '0.1.0'
nested_auto="$("$updater" --root "$nested" --auto)"
assert_contains "$nested_auto" 'skipped · Claude versioned plugin cache' '--auto nested non-git skip'
[ "$(git -C "$host_repo" rev-parse HEAD)" = "$host_before" ] || fail "nested updater moved enclosing repo"

# malformed extra-segment tag is not a stable release
malformed="$fixture_root/malformed-tag"
git clone -q "$origin" "$malformed"
git -C "$malformed" tag v1.2.3.4
git -C "$malformed" checkout -q --detach v1.2.3.4
malformed_auto="$("$updater" --root "$malformed" --auto)"
assert_contains "$malformed_auto" 'skipped · authoring checkout' '--auto malformed tag is authoring'
# --channel release must still pick a real vX.Y.Z, never v1.2.3.4
malformed_rel="$("$updater" --root "$malformed" --channel release)"
assert_contains "$malformed_rel" 'updated release' 'release channel moves off malformed tag'
case "$(git -C "$malformed" describe --tags --exact-match 2>/dev/null || true)" in
  v[0-9]*.[0-9]*.[0-9]*.*) fail "release channel landed on extra-segment tag" ;;
esac

# --- untracked files never block a trunk fast-forward (#118) ---
# Rewind a clean trunk clone one commit, drop an untracked .claude/ beside it (what every Claude
# Code marketplace checkout carries), and the updater must still fast-forward it.
untracked="$fixture_root/untracked"
git clone -q "$origin" "$untracked"
git -C "$untracked" reset -q --hard HEAD~1
# A plain untracked file, not a .claude/ path: a host's global excludes may ignore .claude/, and an
# ignored path is not what this case is about.
printf 'scratch\n' > "$untracked/scratch-notes.txt"
[ "$(git -C "$untracked" status --porcelain=v1 -uall)" = '?? scratch-notes.txt' ] || fail "fixture precondition: scratch-notes.txt must read as untracked"
untracked_out="$("$updater" --root "$untracked" --channel trunk)"
assert_contains "$untracked_out" 'updated trunk main' 'untracked files must not block a fast-forward'
assert_contains "$untracked_out" '1 untracked, not blocking' 'the report names the untracked count'
[ "$(git -C "$untracked" rev-parse HEAD)" = "$(git -C "$seed" rev-parse HEAD)" ] || fail "untracked clone did not fast-forward"
[ -f "$untracked/scratch-notes.txt" ] || fail "fast-forward removed an untracked file"

# --- an untracked file git would overwrite: a SKIP with its reason, never a bare git death ---
collide="$fixture_root/collide"
git clone -q "$origin" "$collide"
git -C "$collide" reset -q --hard HEAD~1
printf 'mine\n' > "$collide/README.md.new"
write_plugin_json "$seed" "$(git -C "$seed" show HEAD:.claude-plugin/plugin.json | sed -n 's/.*"version": "\(.*\)".*/\1/p')"
printf 'theirs\n' > "$seed/README.md.new"
commit_tree "$seed" 'adds README.md.new'
git -C "$seed" push -q origin HEAD:main
collide_before="$(git -C "$collide" rev-parse HEAD)"
collide_out="$("$updater" --root "$collide" --auto)"
assert_contains "$collide_out" 'skipped · fast-forward refused by git' 'a colliding untracked file is a skip with its reason'
[ "$(git -C "$collide" rev-parse HEAD)" = "$collide_before" ] || fail "colliding clone moved"
[ "$(cat "$collide/README.md.new")" = mine ] || fail "colliding untracked file was overwritten"
assert_fails "colliding untracked file was fast-forwarded without --auto" "$updater" --root "$collide" --channel trunk

# --- --claude on a versioned cache brings the Directory-source marketplace current first (#118) ---
# A fake `claude` on PATH records its calls and answers the way the real one did in #118; the
# marketplace registry is Claude Code's own shape, pointed at a clone that is behind origin.
fake_home="$fixture_root/claude-config"
mkdir -p "$fake_home/plugins" "$fixture_root/bin"
claude_log="$fixture_root/claude-calls.log"
cat > "$fixture_root/bin/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$claude_log"
case "\$*" in
  'plugin update hatsu@hatsu -y') echo 'Plugin hatsu is already at the latest version' ;;
esac
exit 0
EOF
chmod +x "$fixture_root/bin/claude"
write_registry() {
  # \$1 = the directory the `hatsu` marketplace points at (JSON-escaped for a plain path)
  printf '%s\n' '{
  "claude-plugins-official": {
    "source": {
      "source": "github",
      "repo": "anthropics/claude-plugins-official"
    },
    "installLocation": "/nowhere/claude-plugins-official",
    "lastUpdated": "2026-09-29T00:00:00.000Z"
  },
  "hatsu": {
    "source": {
      "source": "directory",
      "path": "'"$1"'"
    },
    "installLocation": "'"$1"'",
    "lastUpdated": "2026-09-29T00:00:00.000Z"
  }
}' > "$fake_home/plugins/known_marketplaces.json"
}

mkt="$fixture_root/marketplace-src"
git clone -q "$origin" "$mkt"
mkt="$(CDPATH='' cd -- "$mkt" >/dev/null 2>&1 && pwd -P)"   # the updater reports the canonical path
git -C "$mkt" reset -q --hard HEAD~1
mkdir -p "$mkt/.claude/worktrees"     # the untracked dir every marketplace checkout carries
write_registry "$mkt"
cache2="$fixture_root/cache2/hatsu/0.14.0"
write_plugin_json "$cache2" '0.14.0'
mkt_before="$(git -C "$mkt" rev-parse HEAD)"

# dry-run plans the marketplace fast-forward and moves nothing
mkt_dry="$(CLAUDE_CONFIG_DIR="$fake_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$cache2" --auto --claude --dry-run)"
assert_contains "$mkt_dry" "marketplace source $mkt" 'dry-run names the marketplace source'
assert_contains "$mkt_dry" 'would run: git merge --ff-only origin/main' 'dry-run plans the marketplace fast-forward'
[ "$(git -C "$mkt" rev-parse HEAD)" = "$mkt_before" ] || fail "dry-run moved the marketplace checkout"
[ ! -e "$claude_log" ] || fail "dry-run invoked claude"

# live: the marketplace checkout is fast-forwarded BEFORE claude plugin update, and the line says so
mkt_live="$(CLAUDE_CONFIG_DIR="$fake_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$cache2" --auto --claude)"
assert_contains "$mkt_live" "marketplace source $mkt: updated trunk main" 'live run fast-forwards the marketplace source'
assert_contains "$mkt_live" 'claude plugin updated' 'live run still refreshes the cache'
assert_contains "$mkt_live" 'marketplace source at v0.3.0, this cache slot is v0.14.0' 'live run compares the source manifest with the cache slot'
[ "$(git -C "$mkt" rev-parse HEAD)" = "$(git -C "$seed" rev-parse HEAD)" ] || fail "marketplace checkout was not fast-forwarded"
grep -qx 'plugin update hatsu@hatsu -y' "$claude_log" || fail "claude plugin update was not invoked"
grep -qx 'plugin marketplace update' "$claude_log" || fail "claude plugin marketplace update was not invoked"

# the marketplace source on an authoring branch is NOT fast-forwarded, and the line says why
git -C "$mkt" checkout -q -b feat/mkt-work
git -C "$mkt" reset -q --hard HEAD~1
mkt_branch_before="$(git -C "$mkt" rev-parse HEAD)"
mkt_branch="$(CLAUDE_CONFIG_DIR="$fake_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$cache2" --auto --claude)"
assert_contains "$mkt_branch" "marketplace source $mkt NOT brought current: authoring checkout (feat/mkt-work)" 'authoring marketplace source is named, not fast-forwarded'
assert_contains "$mkt_branch" 'compares against that checkout as it stands' 'the claim is qualified'
[ "$(git -C "$mkt" rev-parse HEAD)" = "$mkt_branch_before" ] || fail "authoring marketplace checkout was moved"

# no hatsu Directory source in the registry: said, never a bare claim
write_registry_github() {
  printf '%s\n' '{
  "hatsu": {
    "source": {
      "source": "github",
      "repo": "zheref/hatsu"
    },
    "installLocation": "/nowhere/hatsu",
    "lastUpdated": "2026-09-29T00:00:00.000Z"
  }
}' > "$fake_home/plugins/known_marketplaces.json"
}
printf '%s\n' '{"hatsu":{"source":{"source":"directory","path":"/nowhere"}}}' > "$fake_home/plugins/known_marketplaces.json"   # minified: not the one shape
mkt_minified="$(CLAUDE_CONFIG_DIR="$fake_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$cache2" --auto --claude)"
assert_contains "$mkt_minified" 'registry is present but no hatsu Directory source parsed' 'a registry not in the one shape is named as such, never as current'
rm -rf "$fake_home/plugins/known_marketplaces.json"
mkt_noreg="$(CLAUDE_CONFIG_DIR="$fake_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$cache2" --auto --claude)"
assert_contains "$mkt_noreg" 'no readable known_marketplaces.json' 'an absent registry is named as such'

write_registry_github
mkt_none="$(CLAUDE_CONFIG_DIR="$fake_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$cache2" --auto --claude)"
assert_contains "$mkt_none" 'registry is present but no hatsu Directory source parsed' 'a GitHub-sourced marketplace is reported as unverified'
assert_contains "$mkt_none" 'claude plugin updated' 'a GitHub-sourced marketplace still refreshes the cache'

echo 'hatsu-plugin-update-fixture: ok'
