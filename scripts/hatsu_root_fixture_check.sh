#!/usr/bin/env bash
# Prove scripts/hatsu_root.sh: a handed plugin root resolves; a handed SKILL directory inside the
# plugin walks up to its root (zheref/hatsu#105) — one, three and four levels, a symlinked skill
# directory included — and names the walk on stderr; five levels, a look-alike tree without a hatsu
# manifest, and no candidate at all are NOT INSTALLED at exit 1; $HATSU_PLUGIN_ROOT still wins over
# the handed path; --quoted prints the pasteable literal. Offline, hermetic, writes only under mktemp.

set -euo pipefail
LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
resolver="$script_dir/hatsu_root.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-root.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "hatsu-root-fixture: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "$message: expected '$needle' in: $haystack" ;;
  esac
}

# A Hatsu-shaped tree: the manifest names hatsu at its top level, claude/skills/ exists.
make_plugin() {
  local directory="$1" name="${2:-hatsu}"
  mkdir -p "$directory/.claude-plugin" "$directory/claude/skills/ten" "$directory/surfaces/cursor/ten"
  printf '%s\n' '{' '  "name": "'"$name"'",' '  "version": "0.1.0"' '}' > "$directory/.claude-plugin/plugin.json"
  printf '%s\n' '---' 'name: ten' '---' > "$directory/claude/skills/ten/SKILL.md"
  printf '%s\n' '---' 'name: ten' '---' > "$directory/surfaces/cursor/ten/SKILL.md"
}

plugin="$fixture_root/plugin"
make_plugin "$plugin"
canon_plugin="$(CDPATH='' cd -- "$plugin" >/dev/null 2>&1 && pwd -P)"

run() {
  # run <expected exit> <args...>; stdout to $out, stderr to $err
  local expected="$1"; shift
  set +e
  out="$(env -u HATSU_PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT "$resolver" "$@" 2>"$fixture_root/err")"
  code=$?
  set -e
  err="$(cat "$fixture_root/err")"
  [ "$code" -eq "$expected" ] || fail "'$*' exited $code, expected $expected (stderr: $err)"
}

# the root itself: no walk, nothing on stderr
run 0 "$plugin"
[ "$out" = "$canon_plugin" ] || fail "root resolved to '$out', expected '$canon_plugin'"
[ -z "$err" ] || fail "resolving the root itself wrote to stderr: $err"

# the skill directory Claude Code prints (three levels) walks up, and says so
run 0 "$plugin/claude/skills/ten"
[ "$out" = "$canon_plugin" ] || fail "skill directory resolved to '$out', expected '$canon_plugin'"
assert_contains "$err" 'walked up from a skill directory to its plugin root' 'the walk is named on stderr'
assert_contains "$err" "$canon_plugin" 'the walk names where it ended'

# one level and four levels
run 0 "$plugin/claude"
[ "$out" = "$canon_plugin" ] || fail "one level up resolved to '$out'"
run 0 "$plugin/surfaces/cursor/ten"
[ "$out" = "$canon_plugin" ] || fail "a mirrored skill directory (four levels) resolved to '$out'"

# a symlinked skill directory (Cursor's .cursor/skills/<name>) walks up through its TARGET
target="$fixture_root/target/.cursor/skills"
mkdir -p "$target"
ln -s "$plugin/surfaces/cursor/ten" "$target/ten"
run 0 "$target/ten"
[ "$out" = "$canon_plugin" ] || fail "a symlinked skill directory resolved to '$out', expected '$canon_plugin'"

# five levels is too many
mkdir -p "$plugin/claude/skills/ten/x/y"
run 1 "$plugin/claude/skills/ten/x/y"
assert_contains "$err" 'NOT INSTALLED' 'five levels deep is NOT INSTALLED'
assert_contains "$err" 'within four levels' 'the refusal names the depth bound'

# a look-alike tree whose manifest names another plugin is never accepted, at any level
other="$fixture_root/other"
make_plugin "$other" 'not-hatsu'
run 1 "$other/claude/skills/ten"
assert_contains "$err" 'NOT INSTALLED' 'another plugin is NOT INSTALLED'
run 1 "$other"

# no candidate at all
run 1
assert_contains "$err" 'NOT INSTALLED' 'no candidate is NOT INSTALLED'

# $HATSU_PLUGIN_ROOT wins over the handed path
second="$fixture_root/second"
make_plugin "$second"
canon_second="$(CDPATH='' cd -- "$second" >/dev/null 2>&1 && pwd -P)"
set +e
env_out="$(HATSU_PLUGIN_ROOT="$second" CLAUDE_PLUGIN_ROOT= "$resolver" "$plugin/claude/skills/ten" 2>/dev/null)"
env_code=$?
set -e
[ "$env_code" -eq 0 ] || fail "HATSU_PLUGIN_ROOT candidate exited $env_code"
[ "$env_out" = "$canon_second" ] || fail "HATSU_PLUGIN_ROOT did not win: got '$env_out'"

# --quoted: the root, a label line, then the single-quoted literal
run 0 --quoted "$plugin/claude/skills/ten"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 3 ] || fail "--quoted printed $(printf '%s\n' "$out" | wc -l) lines, expected 3"
[ "$(printf '%s\n' "$out" | sed -n 1p)" = "$canon_plugin" ] || fail "--quoted's first line is not the root"
[ "$(printf '%s\n' "$out" | sed -n 3p)" = "'$canon_plugin'" ] || fail "--quoted's literal is not single-quoted"

echo 'hatsu-root-fixture: ok'
