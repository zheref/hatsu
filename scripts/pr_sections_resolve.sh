#!/usr/bin/env bash
# HA#351 interim; catalogue content is contracts/pr-sections.json. NN#448 owns the released successor.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec python3 -B "$here/pr_sections.py" resolve "$@"
