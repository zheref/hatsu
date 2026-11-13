#!/usr/bin/env bash
# The typed suite exercises the renderer. This fixture holds the shell entry to its CLI contract.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
renderer=("$(command -v bash)" "$root/scripts/direct_matrix_doc.sh")
if [ -n "${HATSU_SHELL_COVERAGE_EXEC:-}" ]; then
  set +x
  export HATSU_SHELL_COVERAGE_PS4="${PS4-}" HATSU_SHELL_COVERAGE_TRACE_FD="${BASH_XTRACEFD-}"
  export -n PS4 BASH_XTRACEFD SHELLOPTS
  [ "${HATSU_SHELL_COVERAGE_TARGET:-}" = scripts/direct_matrix_doc.sh ] || exit 2
  renderer=("$HATSU_SHELL_COVERAGE_EXEC")
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-matrix-shell.XXXXXXXX")"
trap 'rm -rf "$scratch"' EXIT
scratch="$(cd "$scratch" && pwd -P)"
mkdir "$scratch/bin" "$scratch/empty" "$scratch/data root"
# Provide only the platform utilities the wrapper needs. The host's Node stays off this PATH.
ln -s "$(command -v basename)" "$scratch/empty/basename"
ln -s "$(command -v dirname)" "$scratch/empty/dirname"
cat > "$scratch/bin/node" <<'STUB'
#!/bin/sh
if [ "$1" = --version ]; then
  printf '%s\n' "$FIXTURE_NODE_VERSION"
  exit 0
fi
[ "${NODE_OPTIONS+x}${NODE_PATH+x}" = '' ] || exit 90
printf '%s\n' "$@"
STUB
chmod +x "$scratch/bin/node"
fail() { printf 'direct-matrix-shell-fixture: %s\n' "$*" >&2; exit 1; }
check() {
  local expected="$1" diagnostic="$2" status=0
  shift 2
  out="$("$@" 2>&1)" || status=$?
  [ "$status" = "$expected" ] && [[ "$out" == *"$diagnostic"* ]] ||
    fail "expected exit $expected and '$diagnostic', got $status: $out"
}
check 0 'render the model matrix' "${renderer[@]}" --help
check 2 'one mode at a time' "${renderer[@]}" --write --check
check 2 'unknown flag' "${renderer[@]}" --unrecognized
check 2 'one repo-root at a time' "${renderer[@]}" "$root" "$scratch"
check 2 'is not a directory' "${renderer[@]}" "$scratch/missing"
check 2 'node not found' env PATH="$scratch/empty" "${renderer[@]}"

path="$scratch/bin:$scratch/empty"
for version in broken v22.17.0 v23.5.0; do
  check 2 'node >= 22.18 required' env PATH="$path" FIXTURE_NODE_VERSION="$version" "${renderer[@]}"
done
for version in v22.18.0 v23.6.0 v24.0.0; do
  check 0 "$root/scripts/direct_matrix_doc.mts" env PATH="$path" FIXTURE_NODE_VERSION="$version" \
    NODE_OPTIONS='--require /missing' NODE_PATH=/missing "${renderer[@]}" --check "$scratch/data root"
  [ "$out" = "$(printf '%s\n' "$root/scripts/direct_matrix_doc.mts" check "$scratch/data root")" ] ||
    fail "trusted sibling or forwarded args differ: $out"
done
check 0 "$root/scripts/direct_matrix_doc.mts" env PATH="$path" FIXTURE_NODE_VERSION=v24.0.0 "${renderer[@]}"
[ "$out" = "$(printf '%s\n' "$root/scripts/direct_matrix_doc.mts" print "$root")" ] ||
  fail "default invocation did not select print and the plugin root: $out"
check 0 'docs/DIRECT-MATRIX.md is current' "${renderer[@]}" --check "$root"
echo 'direct-matrix-shell-fixture: flags, Node boundaries, and trusted sibling passed'
