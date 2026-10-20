#!/usr/bin/env bash
# HA#351 catalogue resolver; Node 24 executes the TypeScript source directly.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec node "$here/pr_sections.ts" resolve "$@"
