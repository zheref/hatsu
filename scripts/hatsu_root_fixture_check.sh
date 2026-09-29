#!/usr/bin/env bash
# Prove scripts/hatsu_root.sh: a handed plugin root resolves; a handed SKILL directory inside the
# plugin walks up to its root (zheref/hatsu#105) — one, three and four levels, a symlinked skill
# directory included — and names the walk on stderr; five levels, a look-alike tree without a hatsu
# manifest, and no candidate at all are NOT INSTALLED at exit 1; $HATSU_PLUGIN_ROOT still wins over
# the handed path; --quoted prints the pasteable literal; and THE TREE WINS (zheref/hatsu#67): a Hatsu
# checkout the script runs inside overrules an older handed or exported-by-Claude candidate, never an
# explicit $HATSU_PLUGIN_ROOT, never an older or unorderable checkout, and resolves alone when no
# candidate does. Offline, hermetic, writes only under mktemp.

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
  mkdir -p "$directory/.claude-plugin" "$directory/claude/skills/ten" "$directory/surfaces/cursor/ten" "$directory/surfaces/antigravity/skills/ten"
  printf '%s\n' '{' '  "name": "'"$name"'",' '  "version": "'"${3:-0.1.0}"'"' '}' > "$directory/.claude-plugin/plugin.json"
  printf '%s\n' '---' 'name: ten' '---' > "$directory/claude/skills/ten/SKILL.md"
  printf '%s\n' '---' 'name: ten' '---' > "$directory/surfaces/cursor/ten/SKILL.md"
  printf '%s\n' '---' 'name: ten' '---' > "$directory/surfaces/antigravity/skills/ten/SKILL.md"
}

plugin="$fixture_root/plugin"
make_plugin "$plugin"
canon_plugin="$(CDPATH='' cd -- "$plugin" >/dev/null 2>&1 && pwd -P)"

# Every case runs from a NEUTRAL directory — not from the Hatsu checkout that carries this fixture,
# whose own newer manifest would otherwise win every case (#67); the tree-wins cases set $run_in.
neutral="$fixture_root/neutral"; mkdir -p "$neutral"; run_in="$neutral"
run() {
  # run <expected exit> <args...>; stdout to $out, stderr to $err
  local expected="$1"; shift
  set +e
  out="$(cd "$run_in" && env -u HATSU_PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT "$resolver" "$@" 2>"$fixture_root/err")"
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
assert_contains "$err" 'resolved by walking up from' 'the walk is named on stderr, on its own line'
assert_contains "$err" "$canon_plugin" 'the walk names where it ended'

# one level, three levels on a flat mirror, and FOUR levels on the nested antigravity mirror
run 0 "$plugin/claude"
[ "$out" = "$canon_plugin" ] || fail "one level up resolved to '$out'"
run 0 "$plugin/surfaces/cursor/ten"
[ "$out" = "$canon_plugin" ] || fail "a flat mirrored skill directory (three levels) resolved to '$out'"
run 0 "$plugin/surfaces/antigravity/skills/ten"
[ "$out" = "$canon_plugin" ] || fail "a nested mirrored skill directory (four levels) resolved to '$out'"

# a plugin whose path carries a space resolves like any other
spaced="$fixture_root/with space/plugin"
make_plugin "$spaced"
canon_spaced="$(CDPATH='' cd -- "$spaced" >/dev/null 2>&1 && pwd -P)"
run 0 "$spaced/claude/skills/ten"
[ "$out" = "$canon_spaced" ] || fail "a path with a space resolved to '$out', expected '$canon_spaced'"

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

# a candidate carrying a trailing newline is refused BEFORE the walk: a Hatsu-shaped `p<LF>` beside a
# plain `p` must never resolve to `p` (the command substitution would strip the newline)
nldir="$fixture_root/nl"
mkdir -p "$nldir/p"
make_plugin "$nldir/p
"
run 1 "$nldir/p
"
assert_contains "$err" 'unusable' 'a newline-bearing candidate is unusable'
assert_contains "$err" 'NOT INSTALLED' 'a newline-bearing candidate is NOT INSTALLED'

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

# THE TREE WINS (zheref/hatsu#67). A Hatsu checkout (a git repository whose manifest is newer) the
# script runs inside overrules an older handed candidate, and says which pin was passed over.
checkout="$fixture_root/checkout"
make_plugin "$checkout" hatsu 0.53.0
git -C "$checkout" init -q
canon_checkout="$(CDPATH='' cd -- "$checkout" >/dev/null 2>&1 && pwd -P)"
run_in="$checkout/claude/skills"
run 0 "$plugin"
[ "$out" = "$canon_checkout" ] || fail "a newer checkout did not win over the handed 0.1.0 plugin: got '$out'"
assert_contains "$err" 'the tree wins' 'the tree-wins line is on stderr'
assert_contains "$err" "$canon_plugin" 'the passed-over pin is named'
assert_contains "$err" 'export HATSU_PLUGIN_ROOT=' 'the explicit form is offered'

# an OLDER checkout does not win: the handed candidate stays, and the line says so
older="$fixture_root/older"
make_plugin "$older" hatsu 0.0.9
git -C "$older" init -q
run_in="$older"
run 0 "$plugin"
[ "$out" = "$canon_plugin" ] || fail "an older checkout overruled the handed plugin: got '$out'"
assert_contains "$err" 'is not newer' 'an older checkout is named and passed over'

# an EQUAL version stays with the candidate too
same="$fixture_root/same"
make_plugin "$same" hatsu 0.1.0
git -C "$same" init -q
run_in="$same"
run 0 "$plugin"
[ "$out" = "$canon_plugin" ] || fail "an equal-version checkout overruled the handed plugin: got '$out'"
assert_contains "$err" 'is not newer' 'an equal checkout is named and passed over'

# a checkout whose version this script cannot order (a pre-release) leaves the candidate in place
pre="$fixture_root/pre"
make_plugin "$pre" hatsu 1.0.0-rc.1
git -C "$pre" init -q
run_in="$pre"
run 0 "$plugin"
[ "$out" = "$canon_plugin" ] || fail "an unorderable checkout version overruled the handed plugin: got '$out'"
assert_contains "$err" 'cannot be ordered' 'an unorderable version is named, and the candidate stays'

# an explicit $HATSU_PLUGIN_ROOT is never overruled, even by a newer checkout; the line names it
run_in="$checkout"
set +e
env_out="$(cd "$run_in" && HATSU_PLUGIN_ROOT="$plugin" CLAUDE_PLUGIN_ROOT= "$resolver" 2>"$fixture_root/err")"
env_code=$?
set -e
err="$(cat "$fixture_root/err")"
[ "$env_code" -eq 0 ] || fail "explicit export beside a newer checkout exited $env_code"
[ "$env_out" = "$canon_plugin" ] || fail "a newer checkout overruled an explicit HATSU_PLUGIN_ROOT: got '$env_out'"
assert_contains "$err" 'the export is your word' 'the export is kept and the newer checkout is named'

# with NO candidate, a Hatsu checkout in front of you resolves on its own
run_in="$checkout/claude"
run 0
[ "$out" = "$canon_checkout" ] || fail "no candidate inside a checkout did not resolve to it: got '$out'"
assert_contains "$err" 'no candidate resolved; the checkout in front of you' 'the self-resolution is named'

# a git repository that is NOT a Hatsu checkout changes nothing
plain="$fixture_root/plain"
mkdir -p "$plain" && git -C "$plain" init -q
run_in="$plain"
run 0 "$plugin"
[ "$out" = "$canon_plugin" ] || fail "a plain repository changed the resolution: got '$out'"
[ -z "$err" ] || fail "a plain repository wrote to stderr: $err"
run 1
assert_contains "$err" 'NOT INSTALLED' 'no candidate in a plain repository is NOT INSTALLED'
run_in="$neutral"

# --quoted: the root, a label line, then the single-quoted literal
run 0 --quoted "$plugin/claude/skills/ten"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 3 ] || fail "--quoted printed $(printf '%s\n' "$out" | wc -l) lines, expected 3"
[ "$(printf '%s\n' "$out" | sed -n 1p)" = "$canon_plugin" ] || fail "--quoted's first line is not the root"
[ "$(printf '%s\n' "$out" | sed -n 3p)" = "'$canon_plugin'" ] || fail "--quoted's literal is not single-quoted"

echo 'hatsu-root-fixture: ok'
