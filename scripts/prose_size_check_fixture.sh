#!/usr/bin/env bash
# Prove scripts/prose_size_check.sh (zheref/hatsu#119): a tree within every ceiling is exit 0; one file
# over is exit 1 naming the file, its size and its ceiling; a dieted skill missing from disk is named;
# kurapika.md is exempt; a rules file is measured in characters; --headroom prints one row per measured
# file, smallest margin first, with the same exit code as the plain run; an unknown flag and a root that
# is not a Hatsu checkout are wiring refusals at exit 2. Offline, hermetic, writes only under mktemp.

set -euo pipefail
export LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
guard="$script_dir/prose_size_check.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-prose-size.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "prose-size-fixture: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "$message: expected '$needle' in: $haystack" ;;
  esac
}

assert_lacks() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) fail "$message: did not expect '$needle' in: $haystack" ;;
  esac
}

# run <expected exit> <args...>: stdout+stderr in $out
run() {
  local expected="$1"; shift
  set +e
  out="$(sh "$guard" "$@" 2>&1)"
  code=$?
  set -e
  [ "$code" -eq "$expected" ] || fail "'$*' exited $code, expected $expected: $out"
}

# bytes <path> <n>: a file of exactly n bytes (n-1 'x' plus a newline)
bytes() {
  local path="$1" n="$2"
  mkdir -p "$(dirname -- "$path")"
  head -c "$((n - 1))" /dev/zero | tr '\0' 'x' > "$path"
  printf '\n' >> "$path"
}

DIETED="amaterasu backlog-board backlog-loop black-voice breath build futon great-hiker hanten
ten jujutsu jutaisho kagutsuchi kokusen spiritual-message sharingan shibari"

# make_root <dir>: every dieted skill at 100 bytes, two agents at 100 bytes, kurapika.md far over its
# would-be ceiling, one rules file of 11950 characters (the smallest margin in the tree).
make_root() {
  local r="$1" s
  for s in $DIETED; do bytes "$r/claude/skills/$s/SKILL.md" 100; done
  bytes "$r/claude/agents/chrollo.md" 100
  bytes "$r/claude/agents/_review-preamble.md" 100
  bytes "$r/claude/agents/kurapika.md" 9000
  bytes "$r/claude/rules/hatsu.md" 11950
}

# --- within every ceiling: exit 0, kurapika exempt, the count agrees ---
clean="$fixture_root/clean"
make_root "$clean"
run 0 "$clean"
assert_contains "$out" 'prose ok: 20 files within their ceilings' 'seventeen skills, two agents and one rules file are counted; kurapika.md is not'
assert_lacks "$out" 'kurapika' 'the exempt persona is never named'

# --- --headroom: one row per file, smallest margin first, exit unchanged ---
run 0 --headroom "$clean"
assert_contains "$out" 'headroom  file' 'the report carries its header'
first_row="$(printf '%s\n' "$out" | sed -n '2p')"
assert_contains "$first_row" 'claude/rules/hatsu.md' 'the rules file (11950 of 12000 chars) has the smallest margin and sorts first'
assert_contains "$first_row" '11950/12000  chars' 'a rules row carries size/ceiling in characters'
assert_contains "$out" '  6044 claude/agents/chrollo.md' 'an agent row carries its byte margin'
skill_row="$(printf '%s\n' "$out" | grep 'claude/skills/breath/SKILL.md')"
assert_contains "$skill_row" ' 12188 claude/skills/breath/SKILL.md' 'a skill row carries its margin and path'
assert_contains "$skill_row" '100/12288  bytes' 'a skill row carries size/ceiling and unit'
rows="$(printf '%s\n' "$out" | grep -c -E ' (bytes|chars)$' || true)"
[ "$rows" -eq 20 ] || fail "expected 20 report rows, got $rows: $out"
assert_contains "$out" 'prose ok: 20 files' 'the verdict line follows the report'
run 0 "$clean" --headroom
assert_contains "$out" 'headroom  file' 'the flag is read in either position'

# --- exactly at the ceiling is within it; one byte over is named with size and ceiling ---
edge="$fixture_root/edge"
make_root "$edge"
bytes "$edge/claude/skills/hanten/SKILL.md" 12288
bytes "$edge/claude/agents/chrollo.md" 6144
run 0 "$edge"
run 0 --headroom "$edge"
edge_row="$(printf '%s\n' "$out" | grep 'claude/agents/chrollo.md')"
assert_contains "$edge_row" '     0 claude/agents/chrollo.md' 'zero headroom is a row, not an offence'
assert_contains "$edge_row" '6144/6144   bytes' 'the edge row carries size/ceiling'
over="$fixture_root/over"
make_root "$over"
bytes "$over/claude/skills/hanten/SKILL.md" 12289
bytes "$over/claude/agents/chrollo.md" 6145
run 1 "$over"
assert_contains "$out" 'OVER  claude/skills/hanten/SKILL.md  12289 > 12288 bytes' 'an over skill is named with size and ceiling'
assert_contains "$out" 'OVER  claude/agents/chrollo.md  6145 > 6144 bytes' 'an over agent is named with size and ceiling'
assert_contains "$out" '2 file(s) over the ceiling' 'the count of offenders'
run 1 --headroom "$over"
assert_contains "$out" '    -1 claude/skills/hanten/SKILL.md' 'a negative margin heads the report'
assert_contains "$out" 'OVER  claude/agents/chrollo.md' 'the report never hides the offence'

# --- a rules file is measured in characters, not bytes ---
rules="$fixture_root/rules"
make_root "$rules"
mkdir -p "$rules/claude/rules"
{ i=0; while [ "$i" -lt 12001 ]; do printf 'é'; i=$((i + 1)); done; } > "$rules/claude/rules/hatsu.md"
run 1 "$rules"
assert_contains "$out" 'OVER  claude/rules/hatsu.md  12001 > 12000 chars' 'a rules file over by one character is over, in characters'

# --- a dieted skill missing from disk is named, never skipped ---
missing="$fixture_root/missing"
make_root "$missing"
rm "$missing/claude/skills/futon/SKILL.md"
run 1 "$missing"
assert_contains "$out" 'MISSING  claude/skills/futon/SKILL.md -- named on the diet list and not on disk' 'the missing skill is named'

# --- wiring refusals: an unknown flag, a root that is not a Hatsu checkout ---
run 2 --bogus "$clean"
assert_contains "$out" 'unknown flag --bogus (known: --headroom)' 'an unknown flag is refused by name'
run 2 "$fixture_root/nowhere"
assert_contains "$out" 'is not a Hatsu checkout' 'a root without claude/agents and claude/skills is refused'

echo "prose-size-fixture: ok (clean, headroom report and its order, the ceiling edge, over by one, characters, a missing diet entry, two refusals)"
