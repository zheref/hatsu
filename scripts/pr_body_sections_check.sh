#!/usr/bin/env bash
# Exact heading/order/reader-cap checks and non-gating prose measurement (HA#351).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec node "$here/pr_sections.ts" check "$@"
