#!/usr/bin/env bash
# Prove the wrapper preserves a fixture's exit and names every failure (#243).
set -euo pipefail
wrapper=(bash "$(cd "$(dirname "$0")" && pwd -P)/fixture_output_guard.sh")
# The prose guard also calls this fixture and passes its own target in the environment.
if [ "${HATSU_SHELL_COVERAGE_TARGET:-}" = scripts/fixture_output_guard.sh ]; then
  set +x
  export HATSU_SHELL_COVERAGE_PS4="${PS4-}" HATSU_SHELL_COVERAGE_TRACE_FD="${BASH_XTRACEFD-}"
  export -n PS4 BASH_XTRACEFD SHELLOPTS
  wrapper=("${HATSU_SHELL_COVERAGE_EXEC:?}")
fi
fail() { echo "fixture-output-guard-fixture: $*" >&2; exit 1; }
run() { code=0; out="$("${wrapper[@]}" "$@" 2>&1)" || code=$?; }
run bash -c 'exit 7'
[ "$code" -eq 7 ] && [[ "$out" == *'-c exited 7'* ]] || fail "silent exit: expected 7 with a named line; got $code: $out"
run bash -c 'echo setup-complete; exit 7'
[ "$code" -eq 7 ] && [[ "$out" == *'setup-complete'* ]] && [[ "$out" == *'-c exited 7'* ]] || fail "progress then silent exit: expected 7 with a named line; got $code: $out"
run bash -c 'echo named >&2; exit 4'
[ "$code" -eq 4 ] && [[ "$out" == *named* ]] && [[ "$out" == *'-c exited 4'* ]] || fail "named exit: expected 4 and original line plus wrapper line; got $code: $out"
run bash -c 'echo clean'
[ "$code" -eq 0 ] && [ "$out" = clean ] || fail "clean exit: expected 0 and original line only; got $code: $out"
run bash
[ "$code" -eq 2 ] && [[ "$out" == *'expected <exe> <fixture>'* ]] || fail "usage: got $code: $out"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-fixture-guard-test.XXXXXXXX")"
trap 'rm -rf "$scratch"' EXIT
cat > "$scratch/tee" <<'STUB'
#!/bin/sh
cat >/dev/null
exit 9
STUB
chmod +x "$scratch/tee"
TMPDIR="$scratch/missing" run bash -c 'echo should-not-run'
[ "$code" -eq 2 ] && [[ "$out" == *'cannot capture output'* ]] && [[ "$out" != *should-not-run* ]] ||
  fail "capture refusal: got $code: $out"
PATH="$scratch:$PATH" TMPDIR="$scratch" run bash -c 'echo clean'
[ "$code" -eq 2 ] && [[ "$out" == *'tee exit 9'* ]] || fail "relay refusal: got $code: $out"
[ -z "$(find "$scratch" -name 'hatsu-fixture-output.*')" ] || fail 'relay failure left a log behind'
echo 'fixture-output-guard-fixture: fixture exits, usage, and relay cases passed'
