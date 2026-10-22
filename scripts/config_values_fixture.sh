#!/usr/bin/env bash
# The config-values-guard lane: the frozen engine's self-test, then the TypeScript adapter's own fixtures (BC-11).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
bash "$here/config_values.sh" --self-test
node --test "$here/config_values_examiner_fixture.ts"
