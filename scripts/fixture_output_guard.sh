#!/usr/bin/env bash
# Keep a failing focused fixture visible even if set -e exits before its own fail() line (#243).
# Usage: fixture_output_guard.sh <exe> <fixture-or-self-test> [args...]
set -uo pipefail

if [ "$#" -lt 2 ]; then
  echo 'fixture-output-guard: expected <exe> <fixture> [args...]' >&2
  exit 2
fi
label="$2"
log="$(mktemp "${TMPDIR:-/tmp}/hatsu-fixture-output.XXXXXXXX")" || {
  echo "fixture-output-guard: cannot capture output for $label" >&2
  exit 2
}
trap 'rm -f "$log"' EXIT
"$@" 2>&1 | tee "$log"
statuses=("${PIPESTATUS[@]}")
if [ "${statuses[1]}" -ne 0 ]; then
  echo "fixture-output-guard: could not relay $label output (tee exit ${statuses[1]})" >&2
  exit 2
fi
if [ "${statuses[0]}" -ne 0 ]; then
  echo "fixture-output-guard: $label exited ${statuses[0]}" >&2
fi
exit "${statuses[0]}"
