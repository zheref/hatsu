#!/usr/bin/env bash
# Inspect the scratch plugin received by a stub CLI. The real engine has its own lane.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
runner=("$(command -v bash)" "$root/scripts/desk_mod_test.sh")
if [ -n "${HATSU_SHELL_COVERAGE_EXEC:-}" ]; then
  set +x
  export HATSU_SHELL_COVERAGE_PS4="${PS4-}" HATSU_SHELL_COVERAGE_TRACE_FD="${BASH_XTRACEFD-}"
  export -n PS4 BASH_XTRACEFD SHELLOPTS
  [ "${HATSU_SHELL_COVERAGE_TARGET:-}" = scripts/desk_mod_test.sh ] || exit 2
  runner=("$HATSU_SHELL_COVERAGE_EXEC")
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-desk-fixture.XXXXXXXX")"
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/bin" "$scratch/empty" "$scratch/stages"
export DESK_SOURCE="$root/hooks/desk" STAGE_RECORD="$scratch/last-stage"
cat > "$scratch/bin/claude" <<'STUB'
#!/bin/bash
set -euo pipefail
[ "$#" = 3 ] && [ "$1" = plugin ] && [ "$2" = test ] || exit 92
stage="$3"
printf '%s\n' "$stage" > "$STAGE_RECORD"
for path in "$DESK_SOURCE"/*.ts "$DESK_SOURCE"/*.tsx; do
  cmp -s "$path" "$stage/hooks/${path##*/}" || exit 93
done
for path in "$DESK_SOURCE"/tests/*.ts; do
  cmp -s "$path" "$stage/hooks/tests/${path##*/}" || exit 94
done
jq -e '.name == "hatsu" and .types == "./hooks/state.d.ts"' "$stage/.claude-plugin/plugin.json" >/dev/null || exit 95
jq -e '.modules == ["./register.tsx"]' "$stage/hooks/hooks.json" >/dev/null || exit 96
[ ! -e "$stage/scripts" ] || exit 97
echo 'stub claude: stage verified'
exit "${DESK_CHILD_EXIT:-0}"
STUB
chmod +x "$scratch/bin/claude"

fail() { printf 'desk-mod-test-fixture: %s\n' "$*" >&2; exit 1; }
check() {
  local expected="$1" diagnostic="$2" status=0 out
  shift 2
  out="$("$@" 2>&1)" || status=$?
  [ "$status" = "$expected" ] && [[ "$out" == *"$diagnostic"* ]] ||
    fail "expected exit $expected and '$diagnostic', got $status: $out"
}
check 2 'takes no arguments' "${runner[@]}" --unexpected
check 2 'needs the claude CLI' env PATH="$scratch/empty" "${runner[@]}"
check 2 'cannot create the stage' env PATH="$scratch/bin:$PATH" TMPDIR="$scratch/missing" "${runner[@]}"
[ ! -e "$STAGE_RECORD" ] || fail 'a staging refusal called the engine'

check 0 'stage verified' env PATH="$scratch/bin:$PATH" TMPDIR="$scratch/stages" "${runner[@]}"
stage="$(cat "$STAGE_RECORD")"
[ ! -e "$stage" ] || fail 'success left its stage behind'
check 1 'stage verified' env PATH="$scratch/bin:$PATH" TMPDIR="$scratch/stages" DESK_CHILD_EXIT=7 "${runner[@]}"
stage="$(cat "$STAGE_RECORD")"
[ ! -e "$stage" ] || fail 'engine failure left its stage behind'

# A symlink keeps the real script bytes while giving its plain entry a root without a desk.
mkdir "$scratch/scripts"
ln -s "$root/scripts/desk_mod_test.sh" "$scratch/scripts/desk_mod_test.sh"
check 2 'no desk module' env PATH="$scratch/bin:$PATH" bash "$scratch/scripts/desk_mod_test.sh"
echo 'desk-mod-test-fixture: staged layout, exits, and cleanup passed'
