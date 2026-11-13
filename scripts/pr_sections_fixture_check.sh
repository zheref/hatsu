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
# Use a shallow, single-branch clone like CI. A known process declaration with no
# origin/main makes the implicit policy lookup fail locally without reaching a remote.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
unset GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_TEMPLATE_DIR
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
seed="$scratch/seed"
checkout="$scratch/checkout"
mkdir -p "$seed/contracts"
printf '%s\n' '{"gateDerive":{"fixture/pr-sections":{"processPaths":["contracts/"]}}}' > "$seed/contracts/pr-composition.json"
git -C "$seed" init -q -b fixture --template=
git -C "$seed" add -- contracts/pr-composition.json
git -C "$seed" -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm fixture
git clone -q --depth 1 --single-branch --no-local --template= "$seed" "$checkout"
git -C "$checkout" remote set-url origin https://github.com/fixture/pr-sections.git
if [ "$(git -C "$checkout" rev-parse --is-shallow-repository)" != true ] ||
   git -C "$checkout" show-ref --verify --quiet refs/remotes/origin/main; then
  echo 'pr-sections-fixture: expected a shallow checkout without origin/main' >&2
  exit 1
fi

requirements="$scratch/requirements.json"
resolve_args=(--repo "$checkout" --kind process --jobs machinery --out "$requirements")
status=0
out="$("$resolve" "${resolve_args[@]}" 2>&1)" || status=$?
if [ "$status" -ne 1 ] || [[ "$out" != *'cannot derive policy-hit from the target diff'* ]] || [ -e "$requirements" ]; then
  printf 'pr-sections-fixture: expected implicit policy lookup to refuse, got %s: %s\n' "$status" "$out" >&2
  exit 1
fi
readers="$("$resolve" "${resolve_args[@]}" --policy-hit)"
if [[ " · $readers · " != *' · across · '* ]] || [ ! -s "$requirements" ]; then
  echo 'pr-sections-fixture: expected explicit policy hit to admit the across reader' >&2
  exit 1
fi
status=0
out="$("$check" --body "$scratch/missing-body.md" --requirements "$requirements" --max 7 2>&1)" ||
  status=$?
if [ "$status" -ne 1 ] || [[ "$out" != *'missing-body.md'* ]]; then
  printf 'pr-sections-fixture: expected missing body refusal, got %s: %s\n' "$status" "$out" >&2
  exit 1
fi

echo 'pr-sections-fixture: original checker and resolver passed'
