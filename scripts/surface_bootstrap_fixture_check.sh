#!/usr/bin/env bash
# Verify the first-run bootstrap against empty Codex and Cursor repositories.

set -euo pipefail
LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
hatsu_root="$(CDPATH='' cd -- "$script_dir/.." >/dev/null 2>&1 && pwd -P)"
bootstrap="$hatsu_root/scripts/surface_bootstrap.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-surface-bootstrap.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "surface-bootstrap-fixture: $*" >&2
  exit 1
}

count_skills() {
  local directory="$1" entry count=0
  for entry in "$directory"/*; do
    [ -f "$entry/SKILL.md" ] && count=$((count + 1))
  done
  printf '%s\n' "$count"
}

assert_ignored() {
  git -C "$1" check-ignore -q -- "$2" || fail "$2 is not ignored through info/exclude"
}

assert_empty_untracked() {
  [ -z "$(git -C "$1" ls-files --others --exclude-standard)" ] || fail "$1 has non-ignored bootstrap files"
}

new_fixture() {
  local directory="$1"
  git init -q "$directory"
}

codex_fixture="$fixture_root/codex"
new_fixture "$codex_fixture"
"$bootstrap" --surface codex --target "$codex_fixture" --bootstrap
[ -f "$codex_fixture/.agents/skills/hatsu-warmup/SKILL.md" ] || fail "Codex warm-up was not seeded"
[ ! -e "$codex_fixture/.agents/skills/breath" ] || fail "Codex bootstrap installed more than hatsu-warmup"
grep -qx 'name: hatsu-warmup' "$codex_fixture/.agents/skills/hatsu-warmup/SKILL.md" || fail "Codex seed is not discoverable as hatsu-warmup"
assert_ignored "$codex_fixture" '.agents/skills/hatsu-warmup/SKILL.md'
assert_empty_untracked "$codex_fixture"
"$bootstrap" --surface codex --target "$codex_fixture" --bootstrap
"$bootstrap" --surface codex --target "$codex_fixture" --install-all
[ "$(count_skills "$codex_fixture/.agents/skills")" = "$(count_skills "$hatsu_root/surfaces/codex")" ] || fail "Codex full refresh does not match its mirror"
grep -q '^<!-- BEGIN hatsu personas (generated — nen surface mirror, surface: codex) -->$' "$codex_fixture/AGENTS.override.md" || fail "Codex personas were not installed"
assert_ignored "$codex_fixture" 'AGENTS.override.md'
assert_empty_untracked "$codex_fixture"
"$bootstrap" --surface codex --target "$codex_fixture" --install-all

cursor_fixture="$fixture_root/cursor"
new_fixture "$cursor_fixture"
"$bootstrap" --surface cursor --target "$cursor_fixture" --bootstrap
[ -L "$cursor_fixture/.cursor/skills/hatsu-warmup" ] || fail "Cursor warm-up was not linked"
[ ! -e "$cursor_fixture/.cursor/skills/breath" ] || fail "Cursor bootstrap installed more than hatsu-warmup"
grep -qx 'name: hatsu-warmup' "$cursor_fixture/.cursor/skills/hatsu-warmup/SKILL.md" || fail "Cursor seed is not discoverable as hatsu-warmup"
assert_ignored "$cursor_fixture" '.cursor/skills/hatsu-warmup'
assert_empty_untracked "$cursor_fixture"
"$bootstrap" --surface cursor --target "$cursor_fixture" --bootstrap
"$bootstrap" --surface cursor --target "$cursor_fixture" --install-all
[ "$(count_skills "$cursor_fixture/.cursor/skills")" = "$(count_skills "$hatsu_root/surfaces/cursor")" ] || fail "Cursor full refresh does not match its mirror"
[ "$(find "$cursor_fixture/.cursor/agents" -maxdepth 1 -type l | wc -l | tr -d ' ')" = "$(find "$hatsu_root/surfaces/cursor/agents" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')" ] || fail "Cursor personas were not fully installed"
assert_ignored "$cursor_fixture" '.cursor/agents/kurapika.md'
assert_empty_untracked "$cursor_fixture"
"$bootstrap" --surface cursor --target "$cursor_fixture" --install-all

collision_fixture="$fixture_root/collision"
new_fixture "$collision_fixture"
mkdir -p "$collision_fixture/.agents/skills/hatsu-warmup"
printf 'third-party Codex skill\n' > "$collision_fixture/.agents/skills/hatsu-warmup/SKILL.md"
"$bootstrap" --surface codex --target "$collision_fixture" --bootstrap
grep -qx 'third-party Codex skill' "$collision_fixture/.agents/skills/hatsu-warmup/SKILL.md" || fail "Codex collision was overwritten"

tracked_fixture="$fixture_root/tracked"
new_fixture "$tracked_fixture"
mkdir -p "$tracked_fixture/.cursor/skills/hatsu-warmup"
printf 'tracked Cursor skill\n' > "$tracked_fixture/.cursor/skills/hatsu-warmup/SKILL.md"
git -C "$tracked_fixture" add .cursor/skills/hatsu-warmup/SKILL.md
"$bootstrap" --surface cursor --target "$tracked_fixture" --bootstrap
grep -qx 'tracked Cursor skill' "$tracked_fixture/.cursor/skills/hatsu-warmup/SKILL.md" || fail "tracked Cursor skill was overwritten"

echo "surface-bootstrap-fixture: Codex and Cursor first-run bootstrap checks passed"
