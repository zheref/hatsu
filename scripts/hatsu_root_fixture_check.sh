#!/usr/bin/env bash
# Prove scripts/hatsu_root.sh: a handed plugin root resolves; a handed SKILL directory inside the
# plugin walks up to its root (zheref/hatsu#105) — one, three and four levels, a symlinked skill
# directory included — and names the walk on stderr; five levels, a look-alike tree without a hatsu
# manifest, and no candidate at all are NOT INSTALLED at exit 1; $HATSU_PLUGIN_ROOT still wins over
# the handed path; --quoted prints the pasteable literal; and THE TREE IS NAMED, NEVER TRUSTED BY
# ITSELF (zheref/hatsu#67): a newer Hatsu checkout the script runs inside never replaces a resolved
# candidate and never resolves alone — it is named on stderr with the quoted export that binds it;
# older, equal, one- or two-field, over-long and pre-release versions are said and change nothing; a
# newline-bearing toplevel and an absent git are said as "tree check not run". Offline, hermetic,
# writes only under mktemp: git's ambient environment is cleared first.

set -euo pipefail
LC_ALL=C
# git hygiene: a hook's GIT_DIR/GIT_WORK_TREE would redirect every `git init` and `rev-parse` below
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_CEILING_DIRECTORIES GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null

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

# Every case runs from a NEUTRAL directory outside any repository — never from the Hatsu checkout
# that carries this fixture, whose own manifest would otherwise be named in every case (#67); the
# tree cases set $run_in. Under /tmp explicitly, so a TMPDIR inside a checkout cannot move it.
neutral="$(mktemp -d /tmp/hatsu-root-neutral.XXXXXX)"; run_in="$neutral"
trap 'rm -rf "$fixture_root" "$neutral"' EXIT
git_init() { git -C "$1" init -q --template= ; }
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
env_out="$(cd "$run_in" && HATSU_PLUGIN_ROOT="$second" CLAUDE_PLUGIN_ROOT= "$resolver" "$plugin/claude/skills/ten" 2>/dev/null)"
env_code=$?
set -e
[ "$env_code" -eq 0 ] || fail "HATSU_PLUGIN_ROOT candidate exited $env_code"
[ "$env_out" = "$canon_second" ] || fail "HATSU_PLUGIN_ROOT did not win: got '$env_out'"

# THE TREE IS NAMED (zheref/hatsu#67). A newer Hatsu checkout the script runs inside NEVER replaces
# the handed candidate; stderr names the pin, the deferral and the quoted export.
checkout="$fixture_root/checkout"
make_plugin "$checkout" hatsu 0.53.0
git_init "$checkout"
canon_checkout="$(CDPATH='' cd -- "$checkout" >/dev/null 2>&1 && pwd -P)"
run_in="$checkout/claude/skills"
run 0 "$plugin"
[ "$out" = "$canon_plugin" ] || fail "a newer checkout replaced the handed candidate: got '$out'"
assert_contains "$err" 'is newer than the root the handed path resolved' 'the newer checkout is named, with the slot that won'
assert_contains "$err" 'the bound pin stays' 'the bound pin is kept'
assert_contains "$err" "read $canon_checkout/claude/skills/<name>/SKILL.md" 'the deferral points at the tree'
assert_contains "$err" "export HATSU_PLUGIN_ROOT='$canon_checkout'" 'the quoted export is offered'
assert_contains "$err" 'not on Claude Code' 'the Claude Code limit is said'

# a handed SKILL directory beside a newer checkout: the walk ends at the pin, and the walk line says so
run 0 "$plugin/claude/skills/ten"
[ "$out" = "$canon_plugin" ] || fail "a handed skill directory beside a newer checkout resolved to '$out'"
assert_contains "$err" "→ $canon_plugin" 'the walk line names where the walk ended, not the checkout'

# a stale $CLAUDE_PLUGIN_ROOT beside a newer checkout: the pin stays, the slot is named
set +e
c_out="$(cd "$run_in" && env -u HATSU_PLUGIN_ROOT CLAUDE_PLUGIN_ROOT="$plugin" "$resolver" 2>"$fixture_root/err")"; c_code=$?
set -e
err="$(cat "$fixture_root/err")"
[ "$c_code" -eq 0 ] && [ "$c_out" = "$canon_plugin" ] || fail "a stale CLAUDE_PLUGIN_ROOT beside a newer checkout: exit $c_code, got '$c_out'"
assert_contains "$err" 'newer than the root $CLAUDE_PLUGIN_ROOT resolved' 'the CLAUDE_PLUGIN_ROOT slot is named'

# an explicit $HATSU_PLUGIN_ROOT — given as the root AND as a skill directory — is kept and named as the word
for exp in "$plugin" "$plugin/claude/skills/ten"; do
  set +e
  env_out="$(cd "$run_in" && HATSU_PLUGIN_ROOT="$exp" CLAUDE_PLUGIN_ROOT= "$resolver" 2>"$fixture_root/err")"; env_code=$?
  set -e
  err="$(cat "$fixture_root/err")"
  [ "$env_code" -eq 0 ] && [ "$env_out" = "$canon_plugin" ] || fail "explicit export '$exp' beside a newer checkout: exit $env_code, got '$env_out'"
  assert_contains "$err" 'newer than the root $HATSU_PLUGIN_ROOT resolved' 'the export slot is named'
done

# a hostile tree naming itself hatsu at 999.0.0, with NO candidate, never binds itself: NOT INSTALLED, named
hostile="$fixture_root/hostile"
make_plugin "$hostile" hatsu 999.0.0
git_init "$hostile"
canon_hostile="$(CDPATH='' cd -- "$hostile" >/dev/null 2>&1 && pwd -P)"
run_in="$hostile/claude"
run 1
assert_contains "$err" 'NOT INSTALLED' 'a checkout with no candidate is NOT INSTALLED'
assert_contains "$err" 'a tree never binds itself' 'the checkout is named as a checkout, never resolved'
assert_contains "$err" "export HATSU_PLUGIN_ROOT='$canon_hostile'" 'the quoted export is offered'
run 0 "$plugin"
[ "$out" = "$canon_plugin" ] || fail "a 999.0.0 tree replaced the handed candidate: got '$out'"

# an OLDER and an EQUAL checkout are said and change nothing
older="$fixture_root/older"; make_plugin "$older" hatsu 0.0.9; git_init "$older"
run_in="$older"; run 0 "$plugin"
[ "$out" = "$canon_plugin" ] || fail "an older checkout changed the resolution: got '$out'"
assert_contains "$err" 'is not newer' 'an older checkout is named'
same="$fixture_root/same"; make_plugin "$same" hatsu 0.1.0; git_init "$same"
run_in="$same"; run 0 "$plugin"
[ "$out" = "$canon_plugin" ] || fail "an equal checkout changed the resolution: got '$out'"
assert_contains "$err" 'is not newer' 'an equal checkout is named'

# versions this script does not order: a pre-release, two fields, one field, an over-long field — all "cannot be ordered", no shell noise
for v in 1.0.0-rc.1 0.53 1 99999999999999999999.0.0; do
  d="$fixture_root/v-$(printf '%s' "$v" | tr -c 'A-Za-z0-9' '_')"
  make_plugin "$d" hatsu "$v"; git_init "$d"
  run_in="$d"; run 0 "$plugin"
  [ "$out" = "$canon_plugin" ] || fail "an unorderable version '$v' changed the resolution: got '$out'"
  assert_contains "$err" 'cannot be ordered' "version '$v' is named unorderable"
  case "$err" in *"integer expression"*|*"expected"*) fail "version '$v' produced shell noise: $err" ;; esac
done

# a checkout whose path carries a space and a semicolon: the export line is a single-quoted literal
odd="$fixture_root/My Plugins;echo PASTED"
make_plugin "$odd" hatsu 0.53.0; git_init "$odd"
canon_odd="$(CDPATH='' cd -- "$odd" >/dev/null 2>&1 && pwd -P)"
run_in="$odd"; run 0 "$plugin"
assert_contains "$err" "export HATSU_PLUGIN_ROOT='$canon_odd'" 'the export literal is quoted whole'

# a toplevel whose name carries a newline beside a Hatsu sibling: the tree check is refused, the candidate stays
twin="$fixture_root/twin"; make_plugin "$twin" hatsu 0.53.0; git_init "$twin"
mkdir -p "$fixture_root/twin
"; git_init "$fixture_root/twin
"
run_in="$fixture_root/twin
"; run 0 "$plugin"
[ "$out" = "$canon_plugin" ] || fail "a newline-bearing toplevel changed the resolution: got '$out'"
assert_contains "$err" 'tree check not run' 'a newline-bearing toplevel is refused, said'
case "$err" in *"is newer"*) fail "the sibling was taken for the toplevel: $err" ;; esac

# git absent from PATH (a PATH carrying only the tools the resolver itself needs): said, and the candidate stays
nogit="$fixture_root/nogit"; mkdir -p "$nogit"
for t in sh awk sed wc tr; do ln -s "$(command -v "$t")" "$nogit/$t"; done
run_in="$checkout"
set +e
g_out="$(cd "$run_in" && env -u HATSU_PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT PATH="$nogit" "$resolver" "$plugin" 2>"$fixture_root/err")"; g_code=$?
set -e
err="$(cat "$fixture_root/err")"
[ "$g_code" -eq 0 ] && [ "$g_out" = "$canon_plugin" ] || fail "without git: exit $g_code, got '$g_out'"
assert_contains "$err" 'tree check not run' 'an absent git is said'

# a git repository that is NOT a Hatsu checkout changes nothing and says nothing
plain="$fixture_root/plain"; mkdir -p "$plain"; git_init "$plain"
run_in="$plain"; run 0 "$plugin"
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
