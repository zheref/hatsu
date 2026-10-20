#!/usr/bin/env bash
# Public entry point for the version-reference helper (zheref/hatsu#158).
set -euo pipefail
here="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
exec node "$here/plugin_version_refs.ts" "$@"
