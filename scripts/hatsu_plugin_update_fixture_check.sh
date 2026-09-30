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

read_plugin_version() {
  awk '
    /^  "version": "/ {
      s = $0
      sub(/^  "version": "/, "", s)
      sub(/",?$/, "", s)
      print s
      exit
    }
  ' "$1/.claude-plugin/plugin.json"
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

# --- an IGNORED file that an incoming commit adds: a SKIP naming it, the file intact (Copilot, HA-PR-#121) ---
ignored_clone="$fixture_root/ignored"
git clone -q "$origin" "$ignored_clone"
git -C "$ignored_clone" reset -q --hard HEAD~1
printf 'local.log\n' > "$ignored_clone/.git/info/exclude"
printf 'mine\n' > "$ignored_clone/local.log"
[ -z "$(git -C "$ignored_clone" status --porcelain=v1 -uall)" ] || fail "fixture precondition: local.log must be ignored"
printf 'theirs\n' > "$seed/local.log"
commit_tree "$seed" 'adds local.log'
git -C "$seed" push -q origin HEAD:main
ignored_before="$(git -C "$ignored_clone" rev-parse HEAD)"
ignored_out="$("$updater" --root "$ignored_clone" --auto)"
assert_contains "$ignored_out" 'skipped · fast-forward would overwrite ignored file(s): local.log' 'an ignored file git would overwrite is a skip naming it'
[ "$(git -C "$ignored_clone" rev-parse HEAD)" = "$ignored_before" ] || fail "ignored-collision clone moved"
[ "$(cat "$ignored_clone/local.log")" = mine ] || fail "ignored file was overwritten"
git -C "$seed" rm -q local.log && commit_tree "$seed" 'drops local.log again' && git -C "$seed" push -q origin HEAD:main

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
assert_contains "$mkt_none" 'cached install: retarget in place with scripts/hatsu_surface_link.sh --surface claude-code' 'a successful cache update names the in-place retarget command'

# --- (a)/(b) --claude: the in-place ${CLAUDE_CONFIG_DIR}/skills/hatsu link takes priority over the
# marketplace cache entirely (HA-BAKURYUHA-88d5f6). It is checked before `claude` is even looked up
# on PATH, and `claude plugin marketplace update` / `claude plugin update` are never invoked. ---
link_home="$fixture_root/claude-link-home"
mkdir -p "$link_home/skills" "$link_home/plugins"
link_target="$fixture_root/link-target"
git clone -q "$origin" "$link_target"
git -C "$link_target" config user.email 'fixture@example.invalid'
git -C "$link_target" config user.name 'Hatsu fixture'
git -C "$link_target" reset -q --hard HEAD~1
ln -s "$link_target" "$link_home/skills/hatsu"
link_target_before="$(git -C "$link_target" rev-parse HEAD)"

rm -f "$claude_log"
link_out="$(CLAUDE_CONFIG_DIR="$link_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$link_target" --claude)"
assert_contains "$link_out" 'served in place' '(a) in-place link report names being served in place'
assert_contains "$link_out" '/reload-plugins' '(a) in-place link report carries the apply instruction'
[ "$(git -C "$link_target" rev-parse HEAD)" = "$(git -C "$seed" rev-parse HEAD)" ] || fail "(a) link target did not fast-forward"
[ "$(git -C "$link_target" rev-parse HEAD)" != "$link_target_before" ] || fail "(a) fixture precondition: link target must have been behind origin"
[ ! -e "$claude_log" ] || fail "(a) in-place link invoked claude"

# The REAL v2 registry shape: {"version": 2, "plugins": {"<id>": [ {...} ]}} -- the exact shape
# scripts/hatsu_surface_link.sh greps for (`grep -qxF '    "hatsu@hatsu": ['`), never the flat
# top-level-object shape Claude Code has never written.
printf '%s\n' '{' '  "version": 2,' '  "plugins": {' '    "hatsu@hatsu": [' '      {' \
  '        "scope": "user",' '        "installPath": "/nowhere/cache/hatsu/hatsu/0.1.0",' \
  '        "version": "0.1.0"' '      }' '    ]' '  }' '}' > "$link_home/plugins/installed_plugins.json"
rm -f "$claude_log"
shadow_out="$(CLAUDE_CONFIG_DIR="$link_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$link_target" --claude)"
assert_contains "$shadow_out" 'shadows the in-place link' '(b) a cached hatsu@hatsu install shadowing the link is named'
assert_contains "$shadow_out" 'scripts/hatsu_surface_link.sh --surface claude-code' '(b) the shadow clause names the retarget command'
[ ! -e "$claude_log" ] || fail "(b) shadow-link case invoked claude"
rm -f "$link_home/plugins/installed_plugins.json"

# (b3) Cursor Bugbot on #151: settings.json declarations make the next /reload-plugins reinstall the
# shadowing copy even with no installed_plugins.json row (evidence § 10 F9). The link report names
# the risk and the retarget command, still without invoking claude; a minified settings.json is
# "not verified", never "declares nothing"; an empty object declares nothing.
printf '%s\n' '{' '  "enabledPlugins": {' '    "hatsu@hatsu": true' '  }' '}' > "$link_home/settings.json"
rm -f "$claude_log"
enb_out="$(CLAUDE_CONFIG_DIR="$link_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$link_target" --claude)"
assert_contains "$enb_out" 'until the next reload' '(b3) an enabled hatsu@hatsu in settings.json is named as a reload risk'
assert_contains "$enb_out" 'settings.json enables hatsu@hatsu' '(b3) the reason names the declaration'
assert_contains "$enb_out" 'scripts/hatsu_surface_link.sh --surface claude-code' '(b3) the risk names the retarget command'
[ ! -e "$claude_log" ] || fail "(b3) settings-declaration case invoked claude"
printf '%s\n' '{' '  "extraKnownMarketplaces": {' '    "hatsu": {' '      "source": {' '        "source": "directory",' '        "path": "/nowhere"' '      }' '    }' '  }' '}' > "$link_home/settings.json"
mkt_decl_out="$(CLAUDE_CONFIG_DIR="$link_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$link_target" --claude)"
assert_contains "$mkt_decl_out" 'settings.json declares extraKnownMarketplaces.hatsu' '(b3) a declared hatsu marketplace is named as a reload risk'
printf '%s\n' '{"enabledPlugins":{"hatsu@hatsu":true}}' > "$link_home/settings.json"
min_out="$(CLAUDE_CONFIG_DIR="$link_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$link_target" --claude)"
assert_contains "$min_out" 'not verified (unexpected shape)' '(b3) a minified settings.json is not verified, never read as declaring nothing'
printf '%s\n' '{}' > "$link_home/settings.json"
empty_out="$(CLAUDE_CONFIG_DIR="$link_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$link_target" --claude)"
case "$empty_out" in
  *'until the next reload'*) fail "(b3) an empty settings object was read as a reload risk: $empty_out" ;;
esac
assert_contains "$empty_out" 'served in place' '(b3) an empty settings object declares nothing'
rm -f "$link_home/settings.json"

# (b4) the settings readers are ONE parser in two files: the updater's copy must stay byte-identical
# to scripts/hatsu_surface_link.sh's, from settings_file_shape_ok through settings_declares_enabled_plugin.
settings_readers() {
  awk '/^settings_file_shape_ok\(\) \{$/ { on = 1 } on { print } on && /^settings_declares_enabled_plugin\(\) \{$/ { last = 1 } last && /^\}$/ { exit }' "$1"
}
[ -n "$(settings_readers "$updater")" ] || fail "(b4) the updater carries no settings readers"
[ "$(settings_readers "$updater")" = "$(settings_readers "$(dirname "$updater")/hatsu_surface_link.sh")" ] ||
  fail "(b4) the settings readers differ between scripts/hatsu_plugin_update.sh and scripts/hatsu_surface_link.sh"

# (b2) the OLD flat top-level-object shape ({"hatsu@hatsu": {...}}) is not a shape Claude Code ever
# writes and must NOT be mistaken for a recorded install -- the link is still reported served in
# place, never shadowed.
printf '%s\n' '{' '  "hatsu@hatsu": {' '    "version": "0.1.0"' '  }' '}' > "$link_home/plugins/installed_plugins.json"
rm -f "$claude_log"
flat_out="$(CLAUDE_CONFIG_DIR="$link_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$link_target" --claude)"
assert_contains "$flat_out" 'served in place' '(b2) the old flat shape must not be read as a recorded install'
case "$flat_out" in
  *'shadows the in-place link'*) fail "(b2) the old flat top-level-object shape was mistaken for a v2 recorded install" ;;
esac
[ ! -e "$claude_log" ] || fail "(b2) old-flat-shape case invoked claude"
rm -f "$link_home/plugins/installed_plugins.json"

# --- (c) a --root under a surface's plugins/cache/ directory is NEVER git-pulled, even when it
# carries a real .git (Codex copies the whole plugin root, .git included, into its own cache). ---
cache_git_root="$fixture_root/surface-caches/claude/plugins/cache/hatsu/hatsu/0.1.0"
mkdir -p "$(dirname "$cache_git_root")"
git clone -q "$origin" "$cache_git_root"
git -C "$cache_git_root" reset -q --hard HEAD~1
cache_git_before="$(git -C "$cache_git_root" rev-parse HEAD)"
set +e
cache_git_err="$("$updater" --root "$cache_git_root" 2>&1)"
cache_git_code=$?
set -e
[ "$cache_git_code" -eq 4 ] || fail "(c) surface cache with a real .git exited $cache_git_code, expected 4"
assert_contains "$cache_git_err" 'surface plugin cache' '(c) a plugins/cache root with a real .git is named a surface plugin cache'
[ "$(git -C "$cache_git_root" rev-parse HEAD)" = "$cache_git_before" ] || fail "(c) surface cache with a real .git was git-pulled"
cache_git_auto="$("$updater" --root "$cache_git_root" --auto)"
assert_contains "$cache_git_auto" 'skipped · surface plugin cache' '(c) --auto on a plugins/cache root with a real .git skips, naming the surface cache'
[ "$(git -C "$cache_git_root" rev-parse HEAD)" = "$cache_git_before" ] || fail "(c) surface cache with a real .git moved under --auto"

# --- (d)/(e)/(f)/(h) --codex: a fake `codex` on PATH mirrors the fake `claude` above. It logs argv
# and answers the row shapes codex-cli 0.154.0 prints for `plugin marketplace list` / `plugin list`,
# reading the live marketplace root's plugin.json from a state file each call so the read-back
# reflects whatever the fixture just fast-forwarded it to. `plugin list`'s VERSION column reads the
# overlay manifest at <mkt_root>/.codex-plugin/plugin.json when one exists (Codex keys its slot on
# it), else the shared .claude-plugin/plugin.json's -- mirroring codex_expected_version. Two more
# state files let individual cases force what a real `codex` would otherwise only produce through
# genuine staleness or failure: codex_report_version_file, when present, overrides the VERSION
# column outright (a stale/mismatched Codex-reported version); codex_add_fail_file, when present, is
# echoed to stderr and `plugin add hatsu@hatsu` exits 1. Neither is set by default, so every
# existing case keeps reading the real files as before. ---
codex_log="$fixture_root/codex-calls.log"
codex_mkt_root_file="$fixture_root/codex-mkt-root.txt"
codex_report_version_file="$fixture_root/codex-report-version.txt"
codex_add_fail_file="$fixture_root/codex-add-fail.txt"
cat > "$fixture_root/bin/codex" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$codex_log"
mkt_root="\$(cat "$codex_mkt_root_file" 2>/dev/null || true)"
case "\$*" in
  'plugin marketplace list')
    printf 'MARKETPLACE  ROOT\n'
    [ -n "\$mkt_root" ] && printf 'hatsu        %s\n' "\$mkt_root"
    ;;
  'plugin list')
    printf 'PLUGIN       STATUS              VERSION  SOURCE\n'
    ver=""
    if [ -f "$codex_report_version_file" ]; then
      ver="\$(cat "$codex_report_version_file")"
    elif [ -n "\$mkt_root" ] && [ -f "\$mkt_root/.codex-plugin/plugin.json" ]; then
      ver="\$(awk '/^  "version": "/ { s = \$0; sub(/^  "version": "/, "", s); sub(/",?\$/, "", s); print s; exit }' "\$mkt_root/.codex-plugin/plugin.json")"
    elif [ -n "\$mkt_root" ] && [ -f "\$mkt_root/.claude-plugin/plugin.json" ]; then
      ver="\$(awk '/^  "version": "/ { s = \$0; sub(/^  "version": "/, "", s); sub(/",?\$/, "", s); print s; exit }' "\$mkt_root/.claude-plugin/plugin.json")"
    fi
    [ -n "\$ver" ] && printf 'hatsu@hatsu  installed, enabled  %s   %s\n' "\$ver" "\$mkt_root"
    ;;
  'plugin add hatsu@hatsu')
    if [ -f "$codex_add_fail_file" ]; then
      cat "$codex_add_fail_file" >&2
      exit 1
    fi
    ;;
esac
exit 0
EOF
chmod +x "$fixture_root/bin/codex"

# (d) a local marketplace root (not --root, not under $CODEX_HOME) behind origin is fast-forwarded.
codex_local_mkt="$fixture_root/codex-local-mkt"
git clone -q "$origin" "$codex_local_mkt"
git -C "$codex_local_mkt" reset -q --hard HEAD~1
printf '%s\n' "$codex_local_mkt" > "$codex_mkt_root_file"
codex_root_d="$fixture_root/codex-root-d"
git clone -q "$origin" "$codex_root_d"
: > "$codex_log"
codex_out_d="$(CODEX_HOME="$fixture_root/codex-home-unused" PATH="$fixture_root/bin:$PATH" "$updater" --root "$codex_root_d" --codex)"
[ "$(git -C "$codex_local_mkt" rev-parse HEAD)" = "$(git -C "$seed" rev-parse HEAD)" ] || fail "(d) codex local marketplace root did not fast-forward"
grep -qx 'plugin add hatsu@hatsu' "$codex_log" || fail "(d) codex plugin add was not invoked"
assert_contains "$codex_out_d" "codex plugin hatsu@hatsu at v$(read_plugin_version "$codex_local_mkt")" '(d) report shows the read-back version'

# (e) a marketplace root under $CODEX_HOME is a Codex-managed snapshot: `codex plugin marketplace
# upgrade hatsu` is what brings it current, never a git fast-forward run by this script.
codex_home_e="$fixture_root/codex-home-e"
codex_managed_mkt="$codex_home_e/marketplaces/hatsu"
mkdir -p "$(dirname "$codex_managed_mkt")"
git clone -q "$origin" "$codex_managed_mkt"
git -C "$codex_managed_mkt" reset -q --hard HEAD~1
printf '%s\n' "$codex_managed_mkt" > "$codex_mkt_root_file"
codex_root_e="$fixture_root/codex-root-e"
git clone -q "$origin" "$codex_root_e"
: > "$codex_log"
CODEX_HOME="$codex_home_e" PATH="$fixture_root/bin:$PATH" "$updater" --root "$codex_root_e" --codex >/dev/null 2>&1 \
  || fail "(e) --codex on a codex-managed marketplace root should succeed"
grep -qx 'plugin marketplace upgrade hatsu' "$codex_log" || fail "(e) codex plugin marketplace upgrade hatsu was not invoked"
grep -qx 'plugin add hatsu@hatsu' "$codex_log" || fail "(e) codex plugin add hatsu@hatsu was not invoked"
upgrade_at="$(grep -n '^plugin marketplace upgrade hatsu$' "$codex_log" | head -1 | cut -d: -f1)"
add_at="$(grep -n '^plugin add hatsu@hatsu$' "$codex_log" | head -1 | cut -d: -f1)"
[ -n "$upgrade_at" ] && [ -n "$add_at" ] && [ "$upgrade_at" -lt "$add_at" ] || fail "(e) marketplace upgrade must precede plugin add"

# (f) no `codex` on PATH: --auto skips (exit 0) naming the reason, never fails the warm-up.
minimal_bin="$fixture_root/minimal-bin"
mkdir -p "$minimal_bin"
for tool in bash git awk sed grep cat cut tr wc sort; do
  tool_path="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$tool_path" ] && ln -sf "$tool_path" "$minimal_bin/$tool"
done
codex_root_f="$fixture_root/codex-root-f"
git clone -q "$origin" "$codex_root_f"
codex_f_out="$(PATH="$minimal_bin" "$updater" --root "$codex_root_f" --codex --auto)"
assert_contains "$codex_f_out" 'skipped' '(f) --codex --auto with no codex on PATH skips rather than fails'
assert_contains "$codex_f_out" 'codex not on PATH' '(f) the skip names the reason'

# (g) --claude and --codex together refuse at exit 2, before --root is even resolved.
assert_fails "(g) --claude and --codex together were accepted" "$updater" --root "$fixture_root" --claude --codex
set +e
g_err="$("$updater" --root "$fixture_root" --claude --codex 2>&1)"
g_code=$?
set -e
[ "$g_code" -eq 2 ] || fail "(g) --claude --codex exited $g_code, expected 2"

# (h) --dry-run --codex: only `would run:` lines, and the codex binary itself is never invoked
# (mirrors --claude's own zero-invocation dry run) — a plain non-git Hatsu tree reaches --codex
# regardless of --dry-run, the same route the #118 --claude cache tests use.
codex_cache_h="$fixture_root/codex-cache-h/hatsu/0.1.0"
write_plugin_json "$codex_cache_h" '0.1.0'
: > "$codex_log"
codex_dry="$(PATH="$fixture_root/bin:$PATH" "$updater" --root "$codex_cache_h" --codex --dry-run)"
assert_contains "$codex_dry" 'would run: codex plugin marketplace list' '(h) dry-run codex plan lists the marketplace resolution step'
assert_contains "$codex_dry" 'would run: codex plugin marketplace upgrade hatsu' '(h) dry-run codex plan lists the upgrade step'
assert_contains "$codex_dry" 'would run: codex plugin add hatsu@hatsu' '(h) dry-run codex plan lists the plugin add step'
[ ! -s "$codex_log" ] || fail "(h) dry-run --codex invoked the codex binary"

# --- (i)/(j) a --dry-run whose git path itself would change (trunk behind origin) must fall
# through to --claude / --codex instead of exiting before ever reaching them: one dry run prints
# the git `would run:` lines, then the surface's own `would run:` lines, then ONE report line
# (HA-BAKURYUHA-88d5f6 follow-up). Without --claude/--codex this git-path dry-run text is unchanged
# (already proven above by the existing dirty/diverged/release --dry-run cases). ---

# (i) trunk-behind + --claude --dry-run with the skills/hatsu link: the report carries both the
# would-fast-forward clause and the link's own "served in place" / "/reload-plugins" clauses,
# nothing is mutated, and the claude shim is never invoked.
link_target_dry="$fixture_root/link-target-dry"
git clone -q "$origin" "$link_target_dry"
git -C "$link_target_dry" reset -q --hard HEAD~1
link_target_dry_before="$(git -C "$link_target_dry" rev-parse HEAD)"
rm -f "$link_home/skills/hatsu"
ln -s "$link_target_dry" "$link_home/skills/hatsu"
rm -f "$claude_log"
link_dry_out="$(CLAUDE_CONFIG_DIR="$link_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$link_target_dry" --channel trunk --claude --dry-run)"
assert_contains "$link_dry_out" 'would fast-forward' '(i) trunk-behind --claude --dry-run names the git plan'
assert_contains "$link_dry_out" 'served in place' '(i) trunk-behind --claude --dry-run still names the in-place link'
assert_contains "$link_dry_out" '/reload-plugins' '(i) trunk-behind --claude --dry-run still carries the apply instruction'
[ "$(git -C "$link_target_dry" rev-parse HEAD)" = "$link_target_dry_before" ] || fail "(i) trunk-behind --claude --dry-run mutated the link target"
[ ! -e "$claude_log" ] || fail "(i) trunk-behind --claude --dry-run invoked claude"

# (j) trunk-behind + --codex --dry-run: the git would-run lines plus `would run: codex plugin add
# hatsu@hatsu`, nothing mutated, the codex shim log stays empty.
codex_root_trunk_dry="$fixture_root/codex-root-trunk-dry"
git clone -q "$origin" "$codex_root_trunk_dry"
git -C "$codex_root_trunk_dry" reset -q --hard HEAD~1
codex_trunk_dry_before="$(git -C "$codex_root_trunk_dry" rev-parse HEAD)"
: > "$codex_log"
codex_trunk_dry_out="$(PATH="$fixture_root/bin:$PATH" "$updater" --root "$codex_root_trunk_dry" --channel trunk --codex --dry-run)"
assert_contains "$codex_trunk_dry_out" 'would fast-forward' '(j) trunk-behind --codex --dry-run names the git plan'
assert_contains "$codex_trunk_dry_out" 'would run: codex plugin add hatsu@hatsu' '(j) trunk-behind --codex --dry-run names the codex plan'
[ "$(git -C "$codex_root_trunk_dry" rev-parse HEAD)" = "$codex_trunk_dry_before" ] || fail "(j) trunk-behind --codex --dry-run mutated the root"
[ ! -s "$codex_log" ] || fail "(j) trunk-behind --codex --dry-run invoked the codex binary"

# --- (k) SIGPIPE safety: a real `codex plugin list` can print thousands of rows (observed live at
# 5,344 on one host, where a sibling script's `awk '...exit'` died silently with exit 141 under
# `pipefail` because it stopped reading the pipe while `codex` was still writing it). A dedicated
# shim answers both `plugin marketplace list` and `plugin list` with >10,000 filler rows before the
# real hatsu row; --codex must still exit 0 with the correct read-back version. ---
bin_big="$fixture_root/bin-big"
mkdir -p "$bin_big"
codex_big_log="$fixture_root/codex-big-calls.log"
codex_big_mkt_root_file="$fixture_root/codex-big-mkt-root.txt"
cat > "$bin_big/codex" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$codex_big_log"
mkt_root="\$(cat "$codex_big_mkt_root_file" 2>/dev/null || true)"
case "\$*" in
  'plugin marketplace list')
    printf 'MARKETPLACE  ROOT\n'
    awk 'BEGIN { for (i = 1; i <= 10001; i++) printf "filler-%d        /nowhere/filler-%d\n", i, i }'
    [ -n "\$mkt_root" ] && printf 'hatsu        %s\n' "\$mkt_root"
    ;;
  'plugin list')
    printf 'PLUGIN       STATUS              VERSION  SOURCE\n'
    awk 'BEGIN { for (i = 1; i <= 10001; i++) printf "filler-plugin-%d  installed, enabled  0.0.%d   /nowhere/filler-%d\n", i, i, i }'
    if [ -n "\$mkt_root" ] && [ -f "\$mkt_root/.claude-plugin/plugin.json" ]; then
      ver="\$(awk '/^  "version": "/ { s = \$0; sub(/^  "version": "/, "", s); sub(/",?\$/, "", s); print s; exit }' "\$mkt_root/.claude-plugin/plugin.json")"
      printf 'hatsu@hatsu  installed, enabled  %s   %s\n' "\${ver:-unknown}" "\$mkt_root"
    fi
    ;;
esac
exit 0
EOF
chmod +x "$bin_big/codex"

codex_big_root="$fixture_root/codex-big-root"
git clone -q "$origin" "$codex_big_root"
printf '%s\n' "$codex_big_root" > "$codex_big_mkt_root_file"
: > "$codex_big_log"
set +e
big_out="$(PATH="$bin_big:$PATH" "$updater" --root "$codex_big_root" --codex 2>&1)"
big_code=$?
set -e
[ "$big_code" -eq 0 ] || fail "(k) --codex with >10,000 filler rows before the hatsu rows exited $big_code, expected 0: $big_out"
assert_contains "$big_out" "codex plugin hatsu@hatsu at v$(read_plugin_version "$codex_big_root")" '(k) report shows the read-back version even amid a huge codex plugin list'

# --- (l) --claude in-place link reenter: when --root differs from the link target and re-entering a
# DIRTY link target refuses, THIS run must refuse too (exit 2) without --auto, and skip (exit 0)
# with --auto, naming the dirty reason either way -- never folded into a silent "served in place"
# (finding 2, hanten Nobunaga/Phinks). ---
link_dirty_home="$fixture_root/claude-link-dirty-home"
mkdir -p "$link_dirty_home/skills" "$link_dirty_home/plugins"
link_dirty_target="$fixture_root/link-dirty-target"
git clone -q "$origin" "$link_dirty_target"
git -C "$link_dirty_target" config user.email 'fixture@example.invalid'
git -C "$link_dirty_target" config user.name 'Hatsu fixture'
printf 'dirty\n' > "$link_dirty_target/README.md"
ln -s "$link_dirty_target" "$link_dirty_home/skills/hatsu"
link_dirty_other_root="$fixture_root/link-dirty-other-root"
git clone -q "$origin" "$link_dirty_other_root"

rm -f "$claude_log"
set +e
link_dirty_err="$(CLAUDE_CONFIG_DIR="$link_dirty_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$link_dirty_other_root" --claude 2>&1)"
link_dirty_code=$?
set -e
[ "$link_dirty_code" -eq 2 ] || fail "(l) --claude reenter of a dirty link target exited $link_dirty_code, expected 2: $link_dirty_err"
assert_contains "$link_dirty_err" 'dirty working copy' '(l) the refusal names the dirty reason'
[ ! -e "$claude_log" ] || fail "(l) --claude reenter refusal invoked claude"

link_dirty_auto_out="$(CLAUDE_CONFIG_DIR="$link_dirty_home" PATH="$fixture_root/bin:$PATH" "$updater" --root "$link_dirty_other_root" --claude --auto)"
assert_contains "$link_dirty_auto_out" 'in-place link' '(l) --auto still names the in-place link'
assert_contains "$link_dirty_auto_out" 'dirty working copy' '(l) --auto skip still carries the dirty reason'
[ ! -e "$claude_log" ] || fail "(l) --claude --auto reenter invoked claude"

# --- (m) --codex reenter of a DIRTY, non-managed marketplace root that differs from --root: this
# run must refuse too (exit 2) without --auto, before `codex plugin add` is ever invoked; with
# --auto it still skips (exit 0), naming the reason, and `plugin add` still runs -- today's skip
# semantics, unchanged (finding 2). ---
codex_dirty_mkt="$fixture_root/codex-dirty-mkt"
git clone -q "$origin" "$codex_dirty_mkt"
printf 'dirty\n' > "$codex_dirty_mkt/README.md"
printf '%s\n' "$codex_dirty_mkt" > "$codex_mkt_root_file"
codex_root_dirty="$fixture_root/codex-root-dirty"
git clone -q "$origin" "$codex_root_dirty"
: > "$codex_log"
set +e
codex_dirty_err="$(CODEX_HOME="$fixture_root/codex-home-unused" PATH="$fixture_root/bin:$PATH" "$updater" --root "$codex_root_dirty" --codex 2>&1)"
codex_dirty_code=$?
set -e
[ "$codex_dirty_code" -eq 2 ] || fail "(m) --codex reenter of a dirty marketplace root exited $codex_dirty_code, expected 2: $codex_dirty_err"
assert_contains "$codex_dirty_err" 'dirty working copy' '(m) the refusal names the dirty reason'
if grep -qx 'plugin add hatsu@hatsu' "$codex_log"; then
  fail "(m) --codex refusal still ran plugin add"
fi

: > "$codex_log"
codex_dirty_auto_out="$(CODEX_HOME="$fixture_root/codex-home-unused" PATH="$fixture_root/bin:$PATH" "$updater" --root "$codex_root_dirty" --codex --auto)"
assert_contains "$codex_dirty_auto_out" 'marketplace root' '(m) --auto still names the marketplace root'
assert_contains "$codex_dirty_auto_out" 'dirty working copy' '(m) --auto skip still carries the dirty reason'
grep -qx 'plugin add hatsu@hatsu' "$codex_log" || fail "(m) --auto skip must still run plugin add (today's skip semantics)"

# --- (n) --codex read-back MISMATCH: `codex plugin add` succeeds but `codex plugin list` reports a
# version that differs from codex_expected_version's verdict for the marketplace root -- refused,
# naming both values (finding 3). ---
codex_mismatch_mkt="$fixture_root/codex-mismatch-mkt"
git clone -q "$origin" "$codex_mismatch_mkt"
printf '%s\n' "$codex_mismatch_mkt" > "$codex_mkt_root_file"
codex_root_n="$fixture_root/codex-root-n"
git clone -q "$origin" "$codex_root_n"
mismatch_expected="$(read_plugin_version "$codex_mismatch_mkt")"
printf '9.9.9-stale\n' > "$codex_report_version_file"
: > "$codex_log"
set +e
codex_mismatch_err="$(PATH="$fixture_root/bin:$PATH" "$updater" --root "$codex_root_n" --codex 2>&1)"
codex_mismatch_code=$?
set -e
rm -f "$codex_report_version_file"
[ "$codex_mismatch_code" -eq 2 ] || fail "(n) --codex read-back mismatch exited $codex_mismatch_code, expected 2: $codex_mismatch_err"
assert_contains "$codex_mismatch_err" "read back version '9.9.9-stale'" '(n) the refusal quotes the read-back value'
assert_contains "$codex_mismatch_err" "expected '$mismatch_expected'" '(n) the refusal quotes the expected value'
grep -qx 'plugin add hatsu@hatsu' "$codex_log" || fail "(n) codex plugin add was not invoked before the read-back check"

# --- (o) --codex `codex plugin add` FAILS: refused, quoting one_line of its captured output (never
# discarded) -- codex_plugin_version / codex_expected_version are never even reached (finding 3). ---
codex_addfail_mkt="$fixture_root/codex-addfail-mkt"
git clone -q "$origin" "$codex_addfail_mkt"
printf '%s\n' "$codex_addfail_mkt" > "$codex_mkt_root_file"
codex_root_o="$fixture_root/codex-root-o"
git clone -q "$origin" "$codex_root_o"
printf 'error: hatsu@hatsu could not be added: disk full\n' > "$codex_add_fail_file"
: > "$codex_log"
set +e
codex_addfail_err="$(PATH="$fixture_root/bin:$PATH" "$updater" --root "$codex_root_o" --codex 2>&1)"
codex_addfail_code=$?
set -e
rm -f "$codex_add_fail_file"
[ "$codex_addfail_code" -eq 2 ] || fail "(o) --codex plugin add failure exited $codex_addfail_code, expected 2: $codex_addfail_err"
assert_contains "$codex_addfail_err" 'codex plugin add hatsu@hatsu failed' '(o) the refusal names the failed step'
assert_contains "$codex_addfail_err" 'disk full' '(o) the refusal quotes the captured output'

echo 'hatsu-plugin-update-fixture: ok'
