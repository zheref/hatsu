#!/usr/bin/env bash
# Run the Hatsu desk module's tests (hooks/desk/tests) under the engine's own kit.
# `claude plugin test <dir>` loads the mod at <dir> and runs every *.test.ts beneath it, so pointed at
# this repository it would also pick up the Vitest fixtures under scripts/. The desk is staged instead
# into a scratch mod of its own, laid out as the plugin lays it out, and tested there.
# Usage: desk_mod_test.sh   (exit 0 every test passed; 1 a test failed; 2 the stage could not be built)
set -uo pipefail

if [ "$#" -ne 0 ]; then
  echo 'desk-mod-test: takes no arguments' >&2
  exit 2
fi
if ! command -v claude >/dev/null 2>&1; then
  echo 'desk-mod-test: needs the claude CLI on PATH (claude plugin test runs the module)' >&2
  exit 2
fi
root="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
desk="$root/hooks/desk"
if [ ! -f "$desk/register.tsx" ] || [ ! -d "$desk/tests" ]; then
  echo "desk-mod-test: no desk module at $desk" >&2
  exit 2
fi
stage="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-desk-test.XXXXXXXX")" || {
  echo 'desk-mod-test: cannot create the stage' >&2
  exit 2
}
trap 'rm -rf "$stage"' EXIT

# The module's files keep their relative imports: hooks/ holds them, hooks/tests the tests.
mkdir -p "$stage/.claude-plugin" "$stage/hooks/tests" || exit 2
cp "$desk"/*.ts "$desk"/*.tsx "$stage/hooks/" || exit 2
cp "$desk"/tests/*.ts "$stage/hooks/tests/" || exit 2
printf '{ "modules": ["./register.tsx"] }\n' >"$stage/hooks/hooks.json" || exit 2
# Named hatsu, as the module's state contract is: the same namespace the installed plugin gives it.
printf '{ "name": "hatsu", "version": "0.0.0", "description": "Hatsu desk test stage", "types": "./hooks/state.d.ts" }\n' \
  >"$stage/.claude-plugin/plugin.json" || exit 2

# The engine's own code is not this script's contract: any failure of the run is a failed test.
if claude plugin test "$stage"; then
  exit 0
fi
exit 1
