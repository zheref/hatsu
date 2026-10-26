#!/usr/bin/env bash
# Thin lane entry; all HA#321 fixture logic is TypeScript (BC-11).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The lane passes Node's exact-source coverage flags through this same fixture run.
mkdir -p "$here/../coverage/pr-delivery-guard/node"
exec node "$@" "$here/pr_body_delivery_check_fixture.ts"
