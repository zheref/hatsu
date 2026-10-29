#!/usr/bin/env bash
# Public entry point for the version-reference helper (zheref/hatsu#158, #494).
# --from X.Y.Z --to X.Y.Z [--body-file LOCAL-DRAFT] [--write]
# Lists by default; --write may edit tracked references and the local draft, never a PR.
set -euo pipefail
here="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
exec node "$here/plugin_version_refs.ts" "$@"
