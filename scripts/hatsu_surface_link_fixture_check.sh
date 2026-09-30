#!/usr/bin/env bash
# Prove scripts/hatsu_surface_link.sh: fresh links per surface, re-pointing an
# owned link, refusing a foreign destination (left intact), the Claude Code
# marketplace handover (only when recorded), a claude-absent handover refused
# up front when one is owed, a malformed settings.json refused before
# anything links, Codex's foreign-marketplace and version-mismatch refusals,
# a missing required CLI at exit 5, a /plugins/cache/ root refused at exit 2,
# and --dry-run / --status changing nothing on disk and calling no mutating
# CLI subcommand.
#
# Hermetic and offline: every invocation gets its own throwaway
# CLAUDE_CONFIG_DIR / GEMINI_CONFIG_DIR / CODEX_HOME / HOME under mktemp, and
# PATH is prefixed with fake claude/codex/agy binaries that log their argv
# and emulate the documented output shapes -- the real ~/.claude, ~/.codex
# and ~/.gemini are never opened for read or write.

set -euo pipefail
LC_ALL=C
# git hygiene: a hook's GIT_DIR/GIT_WORK_TREE would redirect every git init below
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_CEILING_DIRECTORIES GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
unset HATSU_PLUGIN_ROOT CLAUDE_PLUGIN_ROOT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
hatsu_root="$(CDPATH='' cd -- "$script_dir/.." >/dev/null 2>&1 && pwd -P)"
linker="$hatsu_root/scripts/hatsu_surface_link.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-surface-link.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "hatsu-surface-link-fixture: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "$message: expected '$needle' in: $haystack" ;;
  esac
}

assert_not_contains() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) fail "$message: did not expect '$needle' in: $haystack" ;;
    *) ;;
  esac
}

# assert_line_starts HAYSTACK PREFIX MESSAGE -- true when some line of
# HAYSTACK (not merely some substring anywhere in it) starts with PREFIX.
# Nobunaga BC-9: would_link's own report must be its own line, not text
# folded into the middle of the surface's report line.
assert_line_starts() {
  local haystack="$1" prefix="$2" message="$3"
  case $'\n'"$haystack" in
    *$'\n'"$prefix"*) ;;
    *) fail "$message: no line starts with '$prefix' in: $haystack" ;;
  esac
}

canon() {
  CDPATH='' cd -- "$1" >/dev/null 2>&1 && pwd -P
}

# A Hatsu-shaped, committed git checkout: .claude-plugin/plugin.json names
# hatsu, claude/skills/ exists (is_hatsu's own two conditions), plus the
# .codex-plugin overlay and the generated antigravity surface this guard's
# codex/antigravity paths read.
make_hatsu_checkout() {
  local directory="$1" version="${2:-0.60.0}" overlay="${3:-with-overlay}"
  mkdir -p "$directory/.claude-plugin" "$directory/claude/skills/x" "$directory/surfaces/antigravity"
  printf '%s\n' '{' '  "name": "hatsu",' '  "version": "'"$version"'"' '}' \
    > "$directory/.claude-plugin/plugin.json"
  printf '%s\n' '{"name": "hatsu"}' > "$directory/.claude-plugin/marketplace.json"
  if [ "$overlay" = "with-overlay" ]; then
    mkdir -p "$directory/.codex-plugin"
    printf '%s\n' '{' '  "name": "hatsu",' '  "version": "'"$version"'"' '}' \
      > "$directory/.codex-plugin/plugin.json"
  fi
  printf '%s\n' '---' 'name: x' '---' > "$directory/claude/skills/x/SKILL.md"
  printf '%s\n' '{"name": "hatsu"}' > "$directory/surfaces/antigravity/plugin.json"
  git -C "$directory" init -q --template=
  git -C "$directory" config user.email 'fixture@example.invalid'
  git -C "$directory" config user.name 'Hatsu fixture'
  git -C "$directory" add -A
  git -C "$directory" commit -qm seed >/dev/null
}

# --- fake CLIs: log argv, emulate the documented output shapes -------------
bin_dir="$fixture_root/bin"
mkdir -p "$bin_dir"

cat > "$bin_dir/claude" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${CLAUDE_SHIM_LOG:-/dev/null}"

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
installed_file="$config_dir/plugins/installed_plugins.json"
known_file="$config_dir/plugins/known_marketplaces.json"
settings_file="$config_dir/settings.json"

has_line() {
  local file="$1" line="$2"
  [ -f "$file" ] && grep -qxF "$line" "$file"
}

# remove_block FILE START_EXACT END_REGEX -- deletes the literal line
# START_EXACT through the next line matching END_REGEX (inclusive). Test-only
# and hermetic: this fixture controls every byte these files ever carry, so
# a plain awk pass (rather than a real JSON writer) is enough to simulate
# what a real `claude` mutates.
remove_block() {
  local file="$1" start="$2" end_regex="$3" tmp
  [ -f "$file" ] || return 0
  tmp="$(mktemp "${file}.XXXXXX")"
  awk -v start="$start" -v end_regex="$end_regex" '
    $0 == start { skip = 1; next }
    skip && $0 ~ end_regex { skip = 0; next }
    !skip { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# remove_line FILE LINE_REGEX -- deletes every line matching LINE_REGEX
# (enabledPlugins' entries are single lines, not blocks).
remove_line() {
  local file="$1" line_regex="$2" tmp
  [ -f "$file" ] || return 0
  tmp="$(mktemp "${file}.XXXXXX")"
  awk -v re="$line_regex" '$0 !~ re { print }' "$file" > "$tmp"
  mv "$tmp" "$file"
}

case "$1 $2" in
  "plugin disable")
    if has_line "$installed_file" '    "hatsu@hatsu": ['; then
      exit 0
    fi
    echo 'Error: hatsu@hatsu is not installed' >&2
    exit 1
    ;;
  "plugin uninstall")
    remove_block "$installed_file" '    "hatsu@hatsu": [' '^    \],?$'
    remove_line "$settings_file" '^    "hatsu@hatsu": true,?$'
    exit 0
    ;;
esac
case "$*" in
  'plugin marketplace remove hatsu')
    if has_line "$known_file" '  "hatsu": {'; then
      remove_block "$known_file" '  "hatsu": {' '^  \},?$'
    elif [ "${CLAUDE_SHIM_NEVER_CLEAR_SETTINGS_MARKETPLACE:-0}" != "1" ]; then
      remove_block "$settings_file" '    "hatsu": {' '^    \},?$'
    fi
    exit 0
    ;;
  'plugin marketplace update') exit 0 ;;
  'plugin list --json')
    printf '%s\n' '[' '  {' '    "id": "hatsu@skills-dir",' '    "name": "hatsu",' \
      '    "enabled": true,' '    "installPath": "'"${CLAUDE_SHIM_INSTALL_PATH:-/nowhere}"'"' '  },'
    if has_line "$installed_file" '    "hatsu@hatsu": ['; then
      printf '%s\n' '  {' '    "id": "hatsu@hatsu",' '    "name": "hatsu",' \
        '    "enabled": true,' '    "installPath": "/nowhere/cache/hatsu/hatsu/0.49.0"' '  }'
    fi
    printf '%s\n' ']'
    exit 0
    ;;
esac
exit 0
SHIM
chmod +x "$bin_dir/claude"

cat > "$bin_dir/codex" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${CODEX_SHIM_LOG:-/dev/null}"
# CODEX_SHIM_FILLER_ROWS: when set, print this many non-matching filler rows
# BEFORE the real row on every list-shaped subcommand -- yes|head, not a
# shell loop, so a large count (>10,000) is fast. This is what a real
# `codex plugin list` / `codex plugin marketplace list` looks like on a host
# with a lot of other plugins installed, and it is exactly the shape that
# makes an early-exiting awk reader kill this script with SIGPIPE (141) if
# the pipe's writer is still writing when the reader stops early.
filler() {
  local n="${CODEX_SHIM_FILLER_ROWS:-0}"
  [ "$n" -gt 0 ] || return 0
  yes "$1" | head -n "$n"
}
case "$1 $2" in
  "plugin marketplace")
    case "$3" in
      list)
        printf '%s\n' 'MARKETPLACE  ROOT'
        filler 'filler-marketplace  /nowhere/filler'
        if [ -n "${CODEX_SHIM_MARKETPLACE_ROOT:-}" ]; then
          printf '%s\n' "hatsu        ${CODEX_SHIM_MARKETPLACE_ROOT}"
        fi
        exit 0
        ;;
      add)
        exit "${CODEX_SHIM_MARKETPLACE_ADD_EXIT:-0}"
        ;;
    esac
    ;;
  "plugin add")
    filler 'Downloading dependency filler-package...'
    printf '%s\n' "Installed plugin root: ${CODEX_SHIM_CACHE_PATH:-/nowhere/cache}"
    exit "${CODEX_SHIM_ADD_EXIT:-0}"
    ;;
  "plugin list")
    filler 'filler@plugin  installed, enabled  9.9.9  /nowhere/filler'
    printf '%s\n' "hatsu@hatsu  ${CODEX_SHIM_STATUS:-installed, enabled}  ${CODEX_SHIM_VERSION:-0.60.0}  ${CODEX_SHIM_CACHE_PATH:-/nowhere/cache}"
    exit 0
    ;;
esac
exit 0
SHIM
chmod +x "$bin_dir/codex"

cat > "$bin_dir/agy" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${AGY_SHIM_LOG:-/dev/null}"
if [ "$1 $2" = "plugin validate" ]; then
  exit "${AGY_SHIM_VALIDATE_EXIT:-0}"
fi
exit 0
SHIM
chmod +x "$bin_dir/agy"

claude_log="$fixture_root/claude.log"
codex_log="$fixture_root/codex.log"
agy_log="$fixture_root/agy.log"

claude_home="$fixture_root/claude-home"
gemini_home="$fixture_root/gemini-home"
codex_home="$fixture_root/codex-home"
home_unused="$fixture_root/home-unused"
mkdir -p "$claude_home" "$gemini_home" "$codex_home" "$home_unused"

# Two throwaway Hatsu checkouts: checkout1 is the one under test throughout;
# checkout2 stands in for "some OTHER Hatsu tree" for the re-point and
# foreign-marketplace cases. checkout_no_overlay is a pre-v0.62.0-shaped tree
# that never carried .codex-plugin/plugin.json at all.
checkout1_raw="$fixture_root/checkout-a"; make_hatsu_checkout "$checkout1_raw" '0.60.0'
checkout1="$(canon "$checkout1_raw")"
checkout2_raw="$fixture_root/checkout-b"; make_hatsu_checkout "$checkout2_raw" '0.61.0'
checkout2="$(canon "$checkout2_raw")"
checkout_no_overlay_raw="$fixture_root/checkout-no-overlay"; make_hatsu_checkout "$checkout_no_overlay_raw" '0.59.0' 'no-overlay'
checkout_no_overlay="$(canon "$checkout_no_overlay_raw")"
[ ! -e "$checkout_no_overlay/.codex-plugin" ] || fail "fixture precondition: checkout_no_overlay must carry no .codex-plugin/"

restricted_path="/usr/bin:/bin:/usr/sbin:/sbin"

# run <expected exit> <args...> -- combined stdout+stderr to $out
run() {
  local expected="$1"
  shift
  set +e
  out="$(CLAUDE_CONFIG_DIR="$claude_home" GEMINI_CONFIG_DIR="$gemini_home" CODEX_HOME="$codex_home" HOME="$home_unused" PATH="$bin_dir:$PATH" "$linker" "$@" 2>&1)"
  code=$?
  set -e
  [ "$code" -eq "$expected" ] || fail "'$*' exited $code, expected $expected: $out"
}

# run_restricted <expected exit> <args...> -- same, but PATH excludes the
# shim directory (and the host's own codex/claude/agy) entirely: coreutils
# only. Proves the "CLI absent" paths without deleting anything real.
run_restricted() {
  local expected="$1"
  shift
  set +e
  out="$(CLAUDE_CONFIG_DIR="$claude_home" GEMINI_CONFIG_DIR="$gemini_home" CODEX_HOME="$codex_home" HOME="$home_unused" PATH="$restricted_path" "$linker" "$@" 2>&1)"
  code=$?
  set -e
  [ "$code" -eq "$expected" ] || fail "restricted '$*' exited $code, expected $expected: $out"
}

# ============================================================================
# usage / wiring
# ============================================================================

run 2 --surface bogus --root "$checkout1"
run 2 --root "$checkout1"
run 2 --surface claude-code --root "$checkout1" --dry-run --status

not_hatsu="$fixture_root/not-hatsu"
mkdir -p "$not_hatsu"
git -C "$not_hatsu" init -q --template= >/dev/null
run 2 --surface claude-code --root "$not_hatsu"
assert_contains "$out" 'is not a Hatsu checkout' 'a non-Hatsu root is refused'

no_git="$fixture_root/no-git-copy"
make_hatsu_checkout "$no_git" '0.60.0'
rm -rf "$no_git/.git"
run 2 --surface claude-code --root "$no_git"
assert_contains "$out" 'is not a git checkout' 'a Hatsu-shaped tree with no .git is refused'

cache_root="$fixture_root/plugins/cache/hatsu/hatsu/0.1.0"
make_hatsu_checkout "$cache_root" '0.1.0'
run 2 --surface claude-code --root "$cache_root"
assert_contains "$out" '/plugins/cache/' 'a root under /plugins/cache/ is refused exit 2 naming why'

# ============================================================================
# claude-code
# ============================================================================

# --- fresh link: no prior marketplace install, no uninstall/remove calls ---
rm -rf "$claude_home"; mkdir -p "$claude_home"
: > "$claude_log"
export CLAUDE_SHIM_LOG="$claude_log" CLAUDE_SHIM_INSTALL_PATH="$claude_home/skills/hatsu"
run 0 --surface claude-code --root "$checkout1"
unset CLAUDE_SHIM_LOG CLAUDE_SHIM_INSTALL_PATH
assert_contains "$out" 'hatsu-surface-link: claude-code' 'report line names the surface'
assert_contains "$out" 'linked' 'a fresh destination is linked'
assert_contains "$out" "serves $claude_home/skills/hatsu" 'serves the read-back installPath'
assert_contains "$out" 'apply: claude-code: type /reload-plugins' 'the claude-code apply clause'
[ -L "$claude_home/skills/hatsu" ] || fail "claude-code dest was not created as a symlink"
[ "$(canon "$claude_home/skills/hatsu")" = "$checkout1" ] || fail "claude-code dest does not resolve to the checkout"
grep -qxF 'plugin list --json' "$claude_log" || fail "fresh link did not read back via claude plugin list --json"
assert_not_contains "$(cat "$claude_log")" 'uninstall' 'a fresh link with no prior install must not call uninstall'
assert_not_contains "$(cat "$claude_log")" 'marketplace remove' 'a fresh link with no prior marketplace must not remove one'

# --- idempotent: already linked at the intended root ------------------------
: > "$claude_log"
export CLAUDE_SHIM_LOG="$claude_log" CLAUDE_SHIM_INSTALL_PATH="$claude_home/skills/hatsu"
run 0 --surface claude-code --root "$checkout1"
unset CLAUDE_SHIM_LOG CLAUDE_SHIM_INSTALL_PATH
assert_contains "$out" 'already linked' 'a link already at the intended root is reported unchanged'

# --- ours, pointed elsewhere: re-pointed ------------------------------------
rm -rf "$claude_home"; mkdir -p "$claude_home/skills"
ln -s "$checkout2" "$claude_home/skills/hatsu"
: > "$claude_log"
export CLAUDE_SHIM_LOG="$claude_log" CLAUDE_SHIM_INSTALL_PATH="$claude_home/skills/hatsu"
run 0 --surface claude-code --root "$checkout1"
unset CLAUDE_SHIM_LOG CLAUDE_SHIM_INSTALL_PATH
assert_contains "$out" 're-pointed from' 'an owned link pointing elsewhere is re-pointed'
[ "$(canon "$claude_home/skills/hatsu")" = "$checkout1" ] || fail "re-point did not land on the intended root"

# --- foreign real directory: refused exit 3, left intact --------------------
rm -rf "$claude_home"; mkdir -p "$claude_home/skills/hatsu"
printf 'mine\n' > "$claude_home/skills/hatsu/keep.txt"
run 3 --surface claude-code --root "$checkout1"
assert_contains "$out" 'refusing to replace it' 'a real directory destination is refused'
[ -d "$claude_home/skills/hatsu" ] && [ ! -L "$claude_home/skills/hatsu" ] || fail "the foreign directory destination was altered"
[ -f "$claude_home/skills/hatsu/keep.txt" ] || fail "the foreign directory's contents were removed"

# --- foreign symlink (not a Hatsu tree): refused exit 3, left intact --------
rm -rf "$claude_home"; mkdir -p "$claude_home/skills" "$fixture_root/not-hatsu-target"
ln -s "$fixture_root/not-hatsu-target" "$claude_home/skills/hatsu"
run 3 --surface claude-code --root "$checkout1"
[ "$(readlink "$claude_home/skills/hatsu")" = "$fixture_root/not-hatsu-target" ] || fail "the foreign symlink destination was altered"

# --- the marketplace handover: uninstall + remove ONLY when recorded -------
rm -rf "$claude_home"; mkdir -p "$claude_home/plugins"
printf '%s\n' '{' '  "version": 2,' '  "plugins": {' '    "hatsu@hatsu": [' '      {' \
  '        "scope": "user",' '        "installPath": "'"$fixture_root/elsewhere/cache/hatsu/hatsu/0.49.0"'",' \
  '        "version": "0.49.0"' '      }' '    ]' '  }' '}' > "$claude_home/plugins/installed_plugins.json"
printf '%s\n' '{' '  "hatsu": {' '    "source": {' '      "source": "directory",' \
  '      "path": "'"$checkout1"'"' '    },' '    "installLocation": "'"$checkout1"'"' '  }' '}' \
  > "$claude_home/plugins/known_marketplaces.json"
: > "$claude_log"
export CLAUDE_SHIM_LOG="$claude_log" CLAUDE_SHIM_INSTALL_PATH="$claude_home/skills/hatsu"
run 0 --surface claude-code --root "$checkout1"
unset CLAUDE_SHIM_LOG CLAUDE_SHIM_INSTALL_PATH
grep -qxF 'plugin uninstall hatsu@hatsu' "$claude_log" || fail "a recorded hatsu@hatsu install was not uninstalled"
grep -qxF 'plugin marketplace remove hatsu' "$claude_log" || fail "a recorded hatsu marketplace was not removed"
assert_contains "$out" 'uninstalled hatsu@hatsu' 'the report names the uninstall'
assert_contains "$out" 'removed marketplace hatsu' 'the report names the marketplace removal'

# --- the maintainer's host, 2026-09-29: settings.json declarations ------------
# The known marketplace was the checkout (directory source), settings.json
# declared the same name as a git source and enabled hatsu@hatsu. One remove
# cleared only the known entry, and the next reload re-cloned the declared
# marketplace and reinstalled the copy over the link (evidence § 10 F9).
# write_host_state -- that exact state, in a fresh $claude_home.
write_host_state() {
  rm -rf "$claude_home"; mkdir -p "$claude_home/plugins"
  printf '%s\n' '{' '  "version": 2,' '  "plugins": {' '    "hatsu@hatsu": [' '      {' \
    '        "scope": "user",' '        "installPath": "'"$fixture_root/elsewhere/cache/hatsu/hatsu/0.61.0"'",' \
    '        "version": "0.61.0"' '      }' '    ]' '  }' '}' > "$claude_home/plugins/installed_plugins.json"
  printf '%s\n' '{' '  "hatsu": {' '    "source": {' '      "source": "directory",' \
    '      "path": "'"$checkout1"'"' '    },' '    "installLocation": "'"$checkout1"'"' '  }' '}' \
    > "$claude_home/plugins/known_marketplaces.json"
  printf '%s\n' '{' '  "enabledPlugins": {' '    "hatsu@hatsu": true,' '    "warp@claude-code-warp": true' '  },' \
    '  "extraKnownMarketplaces": {' '    "hatsu": {' '      "source": {' '        "source": "git",' \
    '        "url": "https://github.com/zheref/hatsu.git"' '      }' '    }' '  }' '}' > "$claude_home/settings.json"
}

# (c) --status on that state names the reinstall risk, and changes nothing.
write_host_state
mkdir -p "$claude_home/skills"; ln -s "$checkout1" "$claude_home/skills/hatsu"
: > "$claude_log"
export CLAUDE_SHIM_LOG="$claude_log" CLAUDE_SHIM_INSTALL_PATH="$claude_home/skills/hatsu"
run 0 --surface claude-code --root "$checkout1" --status
unset CLAUDE_SHIM_LOG CLAUDE_SHIM_INSTALL_PATH
assert_contains "$out" 'will reinstall on reload' '(c) status names the reinstall risk the declarations carry'
assert_contains "$out" 'extraKnownMarketplaces.hatsu' '(c) status names the declared marketplace'
grep -qxF '    "hatsu@hatsu": true,' "$claude_home/settings.json" || fail "(c) status mode altered settings.json"
assert_not_contains "$(cat "$claude_log")" 'uninstall' '(c) status mode must not uninstall'

# (a) the handover clears both declarations: disable, uninstall, then remove
# the marketplace twice (known entry first, then the settings declaration).
write_host_state
: > "$claude_log"
export CLAUDE_SHIM_LOG="$claude_log" CLAUDE_SHIM_INSTALL_PATH="$claude_home/skills/hatsu"
run 0 --surface claude-code --root "$checkout1"
unset CLAUDE_SHIM_LOG CLAUDE_SHIM_INSTALL_PATH
grep -qxF 'plugin disable hatsu@hatsu --scope user' "$claude_log" || fail "(a) hatsu@hatsu was not disabled before the uninstall"
grep -qxF 'plugin uninstall hatsu@hatsu' "$claude_log" || fail "(a) hatsu@hatsu was not uninstalled"
[ "$(grep -cxF 'plugin marketplace remove hatsu' "$claude_log")" -eq 2 ] \
  || fail "(a) expected two marketplace removals (known, then declared): $(cat "$claude_log")"
assert_contains "$out" 'declarations cleared' '(a) the report says the declarations were cleared'
assert_not_contains "$(cat "$claude_home/settings.json")" '"hatsu@hatsu"' '(a) settings.json no longer enables hatsu@hatsu'
assert_not_contains "$(cat "$claude_home/settings.json")" '    "hatsu": {' '(a) settings.json no longer declares the hatsu marketplace'

# (b) a declaration the CLI will not clear is a refusal naming the file,
# never a green report and never a hand edit.
write_host_state
: > "$claude_log"
export CLAUDE_SHIM_LOG="$claude_log" CLAUDE_SHIM_INSTALL_PATH="$claude_home/skills/hatsu" CLAUDE_SHIM_NEVER_CLEAR_SETTINGS_MARKETPLACE=1
run 1 --surface claude-code --root "$checkout1"
unset CLAUDE_SHIM_LOG CLAUDE_SHIM_INSTALL_PATH CLAUDE_SHIM_NEVER_CLEAR_SETTINGS_MARKETPLACE
assert_contains "$out" "$claude_home/settings.json" '(b) the refusal names settings.json'
assert_contains "$out" 'extraKnownMarketplaces.hatsu' '(b) the refusal names the key left declared'
grep -qxF '    "hatsu": {' "$claude_home/settings.json" || fail "(b) the script edited settings.json by hand"

# --- a malformed settings.json shape is refused before anything links ------
# (Phinks, 2026-09-29): every shape check runs BEFORE ensure_symlink now, so
# a refusal changes nothing -- not even the destination symlink.
rm -rf "$claude_home"; mkdir -p "$claude_home"
printf '%s' '{"enabledPlugins":{"hatsu@hatsu":true}}' > "$claude_home/settings.json"
: > "$claude_log"
export CLAUDE_SHIM_LOG="$claude_log" CLAUDE_SHIM_INSTALL_PATH="$claude_home/skills/hatsu"
run 1 --surface claude-code --root "$checkout1"
unset CLAUDE_SHIM_LOG CLAUDE_SHIM_INSTALL_PATH
assert_contains "$out" 'not in the one shape read' 'a minified settings.json is refused for its shape'
[ ! -e "$claude_home/skills/hatsu" ] || fail "a settings.json shape refusal must not create the destination"
[ ! -s "$claude_log" ] || fail "a settings.json shape refusal must not call claude at all: $(cat "$claude_log")"

# --- settings.json holding exactly "{}" (JSON.stringify({}, null, 2)) is ---
# accepted as declaring nothing (Phinks: the old shape check required at
# least two lines unconditionally, and so refused the one line an empty
# settings object legitimately is).
rm -rf "$claude_home"; mkdir -p "$claude_home"
printf '{}\n' > "$claude_home/settings.json"
: > "$claude_log"
export CLAUDE_SHIM_LOG="$claude_log" CLAUDE_SHIM_INSTALL_PATH="$claude_home/skills/hatsu"
run 0 --surface claude-code --root "$checkout1"
unset CLAUDE_SHIM_LOG CLAUDE_SHIM_INSTALL_PATH
assert_contains "$out" 'linked' 'a settings.json holding only "{}" is accepted as declaring nothing'

# --- --dry-run changes nothing, calls nothing --------------------------------
rm -rf "$claude_home"; mkdir -p "$claude_home"
: > "$claude_log"
run 0 --surface claude-code --root "$checkout1" --dry-run
assert_contains "$out" 'would link:' 'dry-run prints the would-link plan'
assert_line_starts "$out" 'would link: ' 'the would-link plan is its own line, not folded into the report line'
assert_contains "$out" 'dry-run' 'the report is marked dry-run'
[ ! -e "$claude_home/skills/hatsu" ] || fail "dry-run created the destination"
[ ! -s "$claude_log" ] || fail "dry-run invoked claude: $(cat "$claude_log")"

# --- --status is read-only ---------------------------------------------------
rm -rf "$claude_home"; mkdir -p "$claude_home/skills"
ln -s "$checkout1" "$claude_home/skills/hatsu"
: > "$claude_log"
export CLAUDE_SHIM_LOG="$claude_log" CLAUDE_SHIM_INSTALL_PATH="$claude_home/skills/hatsu"
run 0 --surface claude-code --root "$checkout1" --status
unset CLAUDE_SHIM_LOG CLAUDE_SHIM_INSTALL_PATH
assert_contains "$out" 'status:' 'status mode reports "status:"'
[ "$(canon "$claude_home/skills/hatsu")" = "$checkout1" ] || fail "status mode altered the destination"
assert_not_contains "$(cat "$claude_log")" 'uninstall' 'status mode must never call uninstall'
assert_not_contains "$(cat "$claude_log")" 'marketplace remove' 'status mode must never remove a marketplace'

# --- claude absent from PATH: still links, says so, exit 0 ------------------
rm -rf "$claude_home"; mkdir -p "$claude_home"
run_restricted 0 --surface claude-code --root "$checkout1"
assert_contains "$out" 'claude not on PATH: read-back not done' 'an absent claude is reported, never fatal'
[ -L "$claude_home/skills/hatsu" ] || fail "linking did not happen without claude on PATH"

# --- claude absent AND a handover is owed: refused at exit 5, before any ---
# change (Nobunaga N6 / Phinks, 2026-09-29): without claude on PATH there is
# no CLI to run the handover, so a recorded install or declaration is a hard
# refusal rather than a link left silently shadowed. Three independent
# triggers, each named in the refusal.
rm -rf "$claude_home"; mkdir -p "$claude_home/plugins"
printf '%s\n' '{' '  "version": 2,' '  "plugins": {' '    "hatsu@hatsu": [' '      {' \
  '        "scope": "user",' '        "installPath": "'"$fixture_root/elsewhere/cache/hatsu/hatsu/0.49.0"'",' \
  '        "version": "0.49.0"' '      }' '    ]' '  }' '}' > "$claude_home/plugins/installed_plugins.json"
run_restricted 5 --surface claude-code --root "$checkout1"
assert_contains "$out" 'installed_plugins.json records hatsu@hatsu' 'a claude-absent handover names what installed_plugins.json records'
[ ! -e "$claude_home/skills/hatsu" ] || fail "a claude-absent handover refusal must not create the destination"

rm -rf "$claude_home"; mkdir -p "$claude_home"
printf '%s\n' '{' '  "enabledPlugins": {' '    "hatsu@hatsu": true' '  }' '}' > "$claude_home/settings.json"
run_restricted 5 --surface claude-code --root "$checkout1"
assert_contains "$out" 'enabledPlugins "hatsu@hatsu": true' 'a claude-absent handover names the enabledPlugins declaration'
[ ! -e "$claude_home/skills/hatsu" ] || fail "a claude-absent handover refusal must not create the destination"

rm -rf "$claude_home"; mkdir -p "$claude_home"
printf '%s\n' '{' '  "extraKnownMarketplaces": {' '    "hatsu": {' '      "source": {' \
  '        "source": "git",' '        "url": "https://github.com/zheref/hatsu.git"' '      }' '    }' '  }' '}' \
  > "$claude_home/settings.json"
run_restricted 5 --surface claude-code --root "$checkout1"
assert_contains "$out" 'extraKnownMarketplaces.hatsu' 'a claude-absent handover names the extraKnownMarketplaces declaration'
[ ! -e "$claude_home/skills/hatsu" ] || fail "a claude-absent handover refusal must not create the destination"

# --- claude absent, NOTHING owed: unchanged -- links, says so, exit 0 ------
rm -rf "$claude_home"; mkdir -p "$claude_home"
run_restricted 0 --surface claude-code --root "$checkout1"
assert_contains "$out" 'claude not on PATH: read-back not done' 'a claude-absent run with nothing owed is unchanged'
[ -L "$claude_home/skills/hatsu" ] || fail "linking did not happen without claude on PATH when nothing was owed"

# ============================================================================
# antigravity
# ============================================================================

# --- fresh link -------------------------------------------------------------
rm -rf "$gemini_home"; mkdir -p "$gemini_home"
: > "$agy_log"
export AGY_SHIM_LOG="$agy_log"
run 0 --surface antigravity --root "$checkout1"
unset AGY_SHIM_LOG
assert_contains "$out" 'hatsu-surface-link: antigravity' 'report line names the surface'
assert_contains "$out" 'linked' 'a fresh destination is linked'
assert_contains "$out" 'apply: antigravity: open a new conversation' 'the antigravity apply clause'
[ -L "$gemini_home/config/plugins/hatsu" ] || fail "antigravity dest was not linked"
[ "$(canon "$gemini_home/config/plugins/hatsu")" = "$checkout1/surfaces/antigravity" ] || fail "antigravity dest does not resolve to surfaces/antigravity"
grep -qxF "plugin validate $gemini_home/config/plugins/hatsu" "$agy_log" || fail "agy plugin validate was not invoked"

# --- ours, pointed at another checkout's surface: re-pointed ----------------
rm -rf "$gemini_home"; mkdir -p "$gemini_home/config/plugins"
ln -s "$checkout2/surfaces/antigravity" "$gemini_home/config/plugins/hatsu"
: > "$agy_log"
export AGY_SHIM_LOG="$agy_log"
run 0 --surface antigravity --root "$checkout1"
unset AGY_SHIM_LOG
assert_contains "$out" 're-pointed from' 'an owned antigravity link elsewhere is re-pointed'
[ "$(canon "$gemini_home/config/plugins/hatsu")" = "$checkout1/surfaces/antigravity" ] || fail "re-point did not land on this checkout's surface"

# --- a failing validate is named, exit 1 (the link itself already landed) --
rm -rf "$gemini_home"; mkdir -p "$gemini_home"
: > "$agy_log"
export AGY_SHIM_LOG="$agy_log" AGY_SHIM_VALIDATE_EXIT=1
run 1 --surface antigravity --root "$checkout1"
unset AGY_SHIM_LOG AGY_SHIM_VALIDATE_EXIT
assert_contains "$out" 'agy plugin validate' 'a validate failure is named'

# --- foreign real directory: refused exit 3, left intact --------------------
rm -rf "$gemini_home"; mkdir -p "$gemini_home/config/plugins/hatsu"
printf 'mine\n' > "$gemini_home/config/plugins/hatsu/keep.txt"
run 3 --surface antigravity --root "$checkout1"
[ -f "$gemini_home/config/plugins/hatsu/keep.txt" ] || fail "the foreign antigravity directory's contents were removed"

# --- a checkout with no generated antigravity surface: exit 2 --------------
no_antigravity="$fixture_root/no-antigravity"
make_hatsu_checkout "$no_antigravity" '0.60.0'
rm -rf "$no_antigravity/surfaces/antigravity"
run 2 --surface antigravity --root "$no_antigravity"
assert_contains "$out" 'surfaces/antigravity' 'a missing generated antigravity surface is named'

# --- --dry-run changes nothing, calls nothing --------------------------------
rm -rf "$gemini_home"; mkdir -p "$gemini_home"
: > "$agy_log"
run 0 --surface antigravity --root "$checkout1" --dry-run
[ ! -e "$gemini_home/config/plugins/hatsu" ] || fail "dry-run created the antigravity destination"
[ ! -s "$agy_log" ] || fail "dry-run invoked agy"

# --- --status is read-only ---------------------------------------------------
rm -rf "$gemini_home"; mkdir -p "$gemini_home/config/plugins"
ln -s "$checkout1/surfaces/antigravity" "$gemini_home/config/plugins/hatsu"
: > "$agy_log"
export AGY_SHIM_LOG="$agy_log"
run 0 --surface antigravity --root "$checkout1" --status
unset AGY_SHIM_LOG
assert_contains "$out" 'status:' 'status mode reports "status:"'
[ "$(canon "$gemini_home/config/plugins/hatsu")" = "$checkout1/surfaces/antigravity" ] || fail "status mode altered the destination"

# --- agy absent from PATH: still links, says so, exit 0 ---------------------
rm -rf "$gemini_home"; mkdir -p "$gemini_home"
run_restricted 0 --surface antigravity --root "$checkout1"
assert_contains "$out" 'agy not on PATH: validate not done' 'an absent agy is reported, never fatal'
[ -L "$gemini_home/config/plugins/hatsu" ] || fail "linking did not happen without agy on PATH"

# ============================================================================
# codex
# ============================================================================

# --- missing codex: exit 5, named (Chrollo: a missing/unsatisfied tool is --
# always exit 5, never 4 -- docs/PROCESS.md) ---------------------------------
run_restricted 5 --surface codex --root "$checkout1"
assert_contains "$out" 'codex is not on PATH' 'a missing codex is named at exit 5'

# --- fresh install: no existing marketplace row -----------------------------
: > "$codex_log"
export CODEX_SHIM_LOG="$codex_log" CODEX_SHIM_VERSION='0.60.0' CODEX_SHIM_CACHE_PATH="$fixture_root/codex-cache/hatsu/0.60.0"
run 0 --surface codex --root "$checkout1"
unset CODEX_SHIM_LOG CODEX_SHIM_VERSION CODEX_SHIM_CACHE_PATH
grep -qxF "plugin marketplace add $checkout1" "$codex_log" || fail "a fresh install did not add the marketplace"
grep -qxF 'plugin add hatsu@hatsu' "$codex_log" || fail "a fresh install did not add the plugin"
assert_contains "$out" 'added marketplace hatsu' 'the report names the marketplace add'
assert_contains "$out" 'installed hatsu@hatsu' 'the report names the plugin add'
assert_contains "$out" "serves $fixture_root/codex-cache/hatsu/0.60.0" 'serves the Installed plugin root cache path'
assert_contains "$out" 'apply: codex: running sessions refresh' 'the codex apply clause'

# --- marketplace already at this checkout: kept, not re-added --------------
: > "$codex_log"
export CODEX_SHIM_LOG="$codex_log" CODEX_SHIM_MARKETPLACE_ROOT="$checkout1" \
  CODEX_SHIM_VERSION='0.60.0' CODEX_SHIM_CACHE_PATH="$fixture_root/codex-cache/hatsu/0.60.0"
run 0 --surface codex --root "$checkout1"
unset CODEX_SHIM_LOG CODEX_SHIM_MARKETPLACE_ROOT CODEX_SHIM_VERSION CODEX_SHIM_CACHE_PATH
assert_not_contains "$(cat "$codex_log")" 'marketplace add' 'an already-registered marketplace must not be re-added'
grep -qxF 'plugin add hatsu@hatsu' "$codex_log" || fail "plugin add still runs when the marketplace was already registered"
assert_contains "$out" 'marketplace hatsu already at this checkout' 'the report names the kept marketplace'

# --- foreign marketplace root: refused exit 3, nothing mutated -------------
: > "$codex_log"
export CODEX_SHIM_LOG="$codex_log" CODEX_SHIM_MARKETPLACE_ROOT="$checkout2"
run 3 --surface codex --root "$checkout1"
unset CODEX_SHIM_LOG CODEX_SHIM_MARKETPLACE_ROOT
assert_contains "$out" "$checkout2" 'the foreign marketplace root is named'
assert_not_contains "$(cat "$codex_log")" 'marketplace add' 'a foreign marketplace must never be overridden'
assert_not_contains "$(cat "$codex_log")" 'plugin add' 'a foreign marketplace refusal must not install the plugin either'

# --- version mismatch: refused, both versions named -------------------------
: > "$codex_log"
export CODEX_SHIM_LOG="$codex_log" CODEX_SHIM_MARKETPLACE_ROOT="$checkout1" \
  CODEX_SHIM_VERSION='0.59.0' CODEX_SHIM_CACHE_PATH="$fixture_root/codex-cache/hatsu/0.59.0"
run 1 --surface codex --root "$checkout1"
unset CODEX_SHIM_LOG CODEX_SHIM_MARKETPLACE_ROOT CODEX_SHIM_VERSION CODEX_SHIM_CACHE_PATH
assert_contains "$out" '0.59.0' 'the installed (lagging) version is named'
assert_contains "$out" '0.60.0' "the checkout's own .codex-plugin/plugin.json version is named"

# --- a status other than "installed, enabled": refused ----------------------
: > "$codex_log"
export CODEX_SHIM_LOG="$codex_log" CODEX_SHIM_MARKETPLACE_ROOT="$checkout1" \
  CODEX_SHIM_STATUS='installed, disabled' CODEX_SHIM_VERSION='0.60.0'
run 1 --surface codex --root "$checkout1"
unset CODEX_SHIM_LOG CODEX_SHIM_MARKETPLACE_ROOT CODEX_SHIM_STATUS CODEX_SHIM_VERSION
assert_contains "$out" 'installed, disabled' 'the unexpected status is named verbatim'

# --- --dry-run changes nothing: only the read-only marketplace list runs ---
: > "$codex_log"
export CODEX_SHIM_LOG="$codex_log"
run 0 --surface codex --root "$checkout1" --dry-run
unset CODEX_SHIM_LOG
assert_contains "$out" 'would run: codex plugin marketplace add' 'dry-run plans the marketplace add'
assert_contains "$out" 'would run: codex plugin add hatsu@hatsu' 'dry-run plans the plugin add'
assert_contains "$out" 'dry-run' 'the report is marked dry-run'
assert_not_contains "$(cat "$codex_log")" 'marketplace add' 'dry-run must not actually add the marketplace'
assert_not_contains "$(cat "$codex_log")" 'plugin add' 'dry-run must not actually install the plugin'
grep -qxF 'plugin marketplace list' "$codex_log" || fail "dry-run should still query the current marketplace state to plan accurately"

# --- --status is read-only ---------------------------------------------------
: > "$codex_log"
export CODEX_SHIM_LOG="$codex_log" CODEX_SHIM_MARKETPLACE_ROOT="$checkout1" CODEX_SHIM_VERSION='0.60.0'
run 0 --surface codex --root "$checkout1" --status
unset CODEX_SHIM_LOG CODEX_SHIM_MARKETPLACE_ROOT CODEX_SHIM_VERSION
assert_contains "$out" 'status:' 'status mode reports "status:"'
assert_not_contains "$(cat "$codex_log")" 'marketplace add' 'status mode must never add a marketplace'
assert_not_contains "$(cat "$codex_log")" 'plugin add' 'status mode must never install the plugin'

# --- SIGPIPE: a real codex prints thousands of rows before the hatsu@hatsu /
# hatsu marketplace row. An awk reader that `exit`s on first match stops
# consuming while the shim (still writing through `yes | head`) gets SIGPIPE
# on its next write; pipefail + set -e then kill this whole script at 141
# with no output, even though the match itself was already correct. Every
# piped reader in the linker must read to EOF (see codex_marketplace_list_
# hatsu_root's own comment) so this never happens, on the install path and
# on --status alike. -----------------------------------------------------
: > "$codex_log"
export CODEX_SHIM_LOG="$codex_log" CODEX_SHIM_FILLER_ROWS=12000 \
  CODEX_SHIM_VERSION='0.60.0' CODEX_SHIM_CACHE_PATH="$fixture_root/codex-cache/hatsu/0.60.0"
run 0 --surface codex --root "$checkout1"
unset CODEX_SHIM_LOG CODEX_SHIM_FILLER_ROWS CODEX_SHIM_VERSION CODEX_SHIM_CACHE_PATH
assert_contains "$out" 'read back installed, enabled 0.60.0' 'the install path survives >10,000 filler rows in marketplace list and plugin list'
assert_contains "$out" "serves $fixture_root/codex-cache/hatsu/0.60.0" 'the cache path is still found correctly through filler output'

: > "$codex_log"
export CODEX_SHIM_LOG="$codex_log" CODEX_SHIM_FILLER_ROWS=12000 \
  CODEX_SHIM_MARKETPLACE_ROOT="$checkout1" CODEX_SHIM_VERSION='0.60.0'
run 0 --surface codex --root "$checkout1" --status
unset CODEX_SHIM_LOG CODEX_SHIM_FILLER_ROWS CODEX_SHIM_MARKETPLACE_ROOT CODEX_SHIM_VERSION
assert_contains "$out" 'hatsu@hatsu installed, enabled 0.60.0' '--status survives >10,000 filler rows in marketplace list and plugin list'

# --- pre-overlay checkouts (before v0.62.0): no .codex-plugin/plugin.json at
# all. Codex then reads .claude-plugin/plugin.json, so the compare falls
# back to it rather than refusing every such checkout at exit 2 for a file
# it was never going to carry -- and the report names which manifest it used.
: > "$codex_log"
export CODEX_SHIM_LOG="$codex_log" CODEX_SHIM_VERSION='0.59.0' \
  CODEX_SHIM_CACHE_PATH="$fixture_root/codex-cache/hatsu/0.59.0"
run 0 --surface codex --root "$checkout_no_overlay"
unset CODEX_SHIM_LOG CODEX_SHIM_VERSION CODEX_SHIM_CACHE_PATH
assert_contains "$out" 'read back installed, enabled 0.59.0 (compared against .claude-plugin/plugin.json)' 'a checkout with no overlay reads back green against the Claude manifest, and names it'

echo 'hatsu-surface-link-fixture: ok'
