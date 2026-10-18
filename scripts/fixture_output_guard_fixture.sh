#!/usr/bin/env bash
# Prove the wrapper preserves a fixture's exit and names every failure (#243).
set -euo pipefail
wrapper="$(cd "$(dirname "$0")" && pwd)/fixture_output_guard.sh"
fail() { echo "fixture-output-guard-fixture: $*" >&2; exit 1; }
run() { code=0; out="$(bash "$wrapper" bash -c "$1" 2>&1)" || code=$?; }
run 'exit 7'
[ "$code" -eq 7 ] && [[ "$out" == *'-c exited 7'* ]] || fail "silent exit: expected 7 with a named line; got $code: $out"
run 'echo setup-complete; exit 7'
[ "$code" -eq 7 ] && [[ "$out" == *'setup-complete'* ]] && [[ "$out" == *'-c exited 7'* ]] || fail "progress then silent exit: expected 7 with a named line; got $code: $out"
run 'echo named >&2; exit 4'
[ "$code" -eq 4 ] && [[ "$out" == *named* ]] && [[ "$out" == *'-c exited 4'* ]] || fail "named exit: expected 4 and original line plus wrapper line; got $code: $out"
run 'echo clean'
[ "$code" -eq 0 ] && [ "$out" = clean ] || fail "clean exit: expected 0 and original line only; got $code: $out"
echo 'fixture-output-guard-fixture: silent, progress, named, and clean cases passed'
