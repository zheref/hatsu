#!/usr/bin/env bash
# The tenkai-guard lane: the frozen engine's self-test, then the TypeScript readiness-guard and checksum fixtures (BC-11).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
bash "$here/tenkai_adopt.sh" --self-test
mkdir -p "$root/coverage/tenkai-guard/node"
(
  unset PS4 BASH_XTRACEFD GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_COUNT
  node "$root/node_modules/vitest/vitest.mjs" run --root "$root" --maxWorkers=1 --no-file-parallelism --testTimeout 15000 \
    scripts/readiness_checksum_fixture.test.mts scripts/tenkai_readiness_guard_fixture.test.mts
  exec node --test --experimental-test-coverage --test-concurrency=1 \
    --test-coverage-include=scripts/tenkai_readiness_guard.mts \
    --test-reporter=spec --test-reporter=lcov \
    --test-reporter-destination=stdout \
    --test-reporter-destination="$root/coverage/tenkai-guard/node/lcov.info" \
    "$here/tenkai_readiness_guard_coverage.test.mts"
)
