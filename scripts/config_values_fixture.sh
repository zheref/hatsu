#!/usr/bin/env bash
# The config-values-guard lane: the frozen engine's self-test, then the TypeScript adapter's own fixtures (BC-11).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
bash "$here/config_values.sh" --self-test
node --test "$here/config_values_examiner_fixture.ts"
node "$here/../node_modules/vitest/vitest.mjs" run --root "$here/.." --testTimeout 15000 scripts/config_values_deploy_fixture.test.ts
node --test "$here/config_values_get_fixture.ts"
node --test "$here/config_values_owned_fixture.ts"
