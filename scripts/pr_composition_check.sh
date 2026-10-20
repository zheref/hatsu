#!/usr/bin/env bash
# BC-11: section validation is TypeScript; the frozen path-set guard only shrinks.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$here/pr_composition_check.ts" "$@"
