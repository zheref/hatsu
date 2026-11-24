#!/usr/bin/env bash
# The tenkai-guard lane: the frozen engine's self-test, then the TypeScript readiness-guard and checksum fixtures (BC-11).
# The lane's test row runs this under scripts/node_cli_coverage_fixture.mts, whose descendant-aware Node LCOV
# (coverage/tenkai-guard/cli/lcov.info) measures every child below; nothing here captures coverage itself.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
engine=(bash "$here/tenkai_adopt.sh")
coverage_exec="${HATSU_SHELL_COVERAGE_EXEC:-}"
if [ -n "$coverage_exec" ]; then
  # Under scripts/shell_coverage.mts --target, only the engine entry writes Bashcov's trace (zheref/hatsu#599).
  set +x
  export HATSU_SHELL_COVERAGE_PS4="${PS4-}" HATSU_SHELL_COVERAGE_TRACE_FD="${BASH_XTRACEFD-}"
  export -n PS4 BASH_XTRACEFD SHELLOPTS
  [ "${HATSU_SHELL_COVERAGE_TARGET:-}" = "scripts/tenkai_adopt.sh" ] ||
    { echo "tenkai-guard-fixture: coverage wrapper target is not scripts/tenkai_adopt.sh" >&2; exit 1; }
  [ -x "$coverage_exec" ] || { echo "tenkai-guard-fixture: coverage wrapper is not executable" >&2; exit 1; }
  engine=("$coverage_exec")
fi
"${engine[@]}" --self-test
(
  unset PS4 BASH_XTRACEFD GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_COUNT
  node "$root/node_modules/vitest/vitest.mjs" run --root "$root" --maxWorkers=1 --no-file-parallelism --testTimeout 15000 \
    scripts/readiness_checksum_fixture.test.mts scripts/tenkai_readiness_guard_fixture.test.mts
  # The outer capture's node:test context must not turn this run into its child reporter.
  unset NODE_TEST_CONTEXT
  exec node --test --test-concurrency=1 --test-reporter=spec "$here/tenkai_readiness_guard_coverage.test.mts"
)
