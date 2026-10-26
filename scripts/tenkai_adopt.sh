#!/usr/bin/env bash
# BC-11: new adoption readings are TypeScript; the existing Python engine stays frozen.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$here/tenkai_adopt.ts" "$@"
