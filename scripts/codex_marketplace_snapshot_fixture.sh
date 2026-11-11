#!/usr/bin/env bash
# Exercise the checked-in materializer against a committed scratch plugin.
set -euo pipefail
snapshot=(bash "$(cd "$(dirname "$0")" && pwd -P)/codex_marketplace_snapshot.sh")
if [ -n "${HATSU_SHELL_COVERAGE_EXEC:-}" ]; then
  set +x
  export HATSU_SHELL_COVERAGE_PS4="${PS4-}" HATSU_SHELL_COVERAGE_TRACE_FD="${BASH_XTRACEFD-}"
  export -n PS4 BASH_XTRACEFD SHELLOPTS
  [ "${HATSU_SHELL_COVERAGE_TARGET:-}" = scripts/codex_marketplace_snapshot.sh ] || exit 2
  snapshot=("$HATSU_SHELL_COVERAGE_EXEC")
fi

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
scratch="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-snapshot-fixture.XXXXXXXX")"
trap 'rm -rf "$scratch"' EXIT
scratch="$(cd "$scratch" && pwd -P)"
repo="$scratch/source plugin"
base="$scratch/snapshots"
fail() { printf 'codex-marketplace-snapshot-fixture: %s\n' "$*" >&2; exit 1; }
reject() {
  local expected="$1" diagnostic="$2" status=0 out
  shift 2
  out="$("${snapshot[@]}" "$@" 2>&1)" || status=$?
  [ "$status" = "$expected" ] && [[ "$out" == *"$diagnostic"* ]] ||
    fail "expected exit $expected and '$diagnostic', got $status: $out"
}

mkdir -p "$repo/.claude-plugin" "$repo/claude/skills" "$scratch/not-plugin"
git -C "$repo" init -q
printf '{"name":"hatsu"}\n' > "$repo/.claude-plugin/plugin.json"
printf '#!/bin/sh\nexit 0\n' > "$repo/claude/skills/action"
chmod +x "$repo/claude/skills/action"
printf 'committed\n' > "$repo/claude/skills/README.md"
ln -s README.md "$repo/claude/skills/alias"
git -C "$repo" add .
git -C "$repo" -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm fixture
commit="$(git -C "$repo" rev-parse HEAD)"
destination="$base/$commit"
printf 'working copy only\n' > "$repo/claude/skills/README.md"

[ "$("${snapshot[@]}" --root "$repo" --base "$base" --dry-run)" = "$destination" ] &&
  [ ! -e "$base" ] || fail 'dry run must print the commit path without creating it'
[ "$("${snapshot[@]}" --root "$repo" --base "$base")" = "$destination" ] ||
  fail 'materialization did not print the commit path'
[ "$(cat "$destination/claude/skills/README.md")" = committed ] &&
  [ -x "$destination/claude/skills/action" ] &&
  [ "$(readlink "$destination/claude/skills/alias")" = README.md ] &&
  [ "$(cat "$destination.source")" = "$repo" ] || fail 'snapshot lost committed bytes, modes, link, or source'
[ "$("${snapshot[@]}" --root "$repo" --base "$base")" = "$destination" ] ||
  fail 'reusing an intact snapshot must succeed'

touch "$destination/extra"
reject 3 'existing commit snapshot differs' --root "$repo" --base "$base"
[ -f "$destination/extra" ] || fail 'refusal rewrote the snapshot'
rm "$destination/extra"
chmod -x "$destination/claude/skills/action"
reject 3 'existing commit snapshot differs' --root "$repo" --base "$base"
chmod +x "$destination/claude/skills/action"
rm "$destination/claude/skills/alias"
ln -s action "$destination/claude/skills/alias"
reject 3 'existing commit snapshot differs' --root "$repo" --base "$base"
rm "$destination/claude/skills/alias"
ln -s README.md "$destination/claude/skills/alias"

rm "$destination.source"
mkdir "$destination.source"
reject 3 'source record is not a plain file' --root "$repo" --base "$base"
rmdir "$destination.source"
ln -s "$repo" "$destination.source"
reject 3 'source record is a symlink' --root "$repo" --base "$base"
ln -s "$base" "$scratch/linked-base"
reject 3 'snapshot base is a symlink' --root "$repo" --base "$scratch/linked-base"
mkdir "$scratch/wrong-path"
touch "$scratch/wrong-path/$commit"
reject 3 'commit path is not a plain directory' --root "$repo" --base "$scratch/wrong-path"
reject 2 'source is not a Hatsu plugin tree' --root "$scratch/not-plugin" --base "$base"
reject 2 '--root is required' --base "$base"
reject 2 '--base must be absolute' --root "$repo" --base relative
reject 2 'unknown argument' --unknown

mkdir -p "$repo/claude/skills/nested/.claude-plugin" "$repo/claude/skills/nested/claude/skills"
cp "$repo/.claude-plugin/plugin.json" "$repo/claude/skills/nested/.claude-plugin/plugin.json"
reject 2 'source must be a git checkout root' --root "$repo/claude/skills/nested" --base "$base"
git -C "$repo" rm --cached -q .claude-plugin/plugin.json
git -C "$repo" -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm no-manifest
reject 2 'committed tree lacks its plugin manifest' --root "$repo" --base "$base"
[ -z "$(find "$base" -name '.stage.*' -o -name '.source.*')" ] || fail 'temporary snapshot data leaked'
echo 'codex-marketplace-snapshot-fixture: committed bytes, reuse, refusal, and cleanup passed'
