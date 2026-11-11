#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
if [ "$#" -eq 0 ]; then
  node --test "$here/pr_sections_fixture_check.ts"
  node "$here/pr_sections.ts" validate
  exit 0
fi
if [ "$#" -ne 1 ] || [ "$1" != --shell-only ]; then
  echo 'pr-sections-fixture: expected no arguments or --shell-only' >&2
  exit 2
fi
check="$here/pr_body_sections_check.sh"
resolve="$here/pr_sections_resolve.sh"
if [ -n "${HATSU_SHELL_COVERAGE_EXEC:-}" ]; then
  set +x
  export HATSU_SHELL_COVERAGE_PS4="${PS4-}" HATSU_SHELL_COVERAGE_TRACE_FD="${BASH_XTRACEFD-}"
  export -n PS4 BASH_XTRACEFD SHELLOPTS
  [ "${HATSU_SHELL_COVERAGE_TARGET:-}" = scripts/pr_body_sections_check.sh ] &&
    [ "${HATSU_SHELL_COVERAGE_TARGET_2:-}" = scripts/pr_sections_resolve.sh ] || exit 2
  check="$HATSU_SHELL_COVERAGE_EXEC"
  resolve="${HATSU_SHELL_COVERAGE_EXEC_2:?}"
fi

# Exercise each original shell entry directly. The native lane separately covers
# the Node engine and broader valid and invalid PR-body cases.
scratch="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-pr-sections-shell.XXXXXXXX")"
trap 'rm -rf "$scratch"' EXIT
"$resolve" --repo "$here/.." --kind process --jobs machinery --out "$scratch/requirements.json"
[ -s "$scratch/requirements.json" ] || exit 1
status=0
out="$("$check" --body "$scratch/missing-body.md" --requirements "$scratch/requirements.json" --max 7 2>&1)" ||
  status=$?
if [ "$status" -ne 1 ] || [[ "$out" != *'missing-body.md'* ]]; then
  printf 'pr-sections-fixture: expected missing body refusal, got %s: %s\n' "$status" "$out" >&2
  exit 1
fi

echo 'pr-sections-fixture: original checker and resolver passed'
