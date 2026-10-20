#!/usr/bin/env bash
# BC-11: new configuration logic is TypeScript; the existing Python engine stays frozen.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$here/config_values.ts" "$@"
