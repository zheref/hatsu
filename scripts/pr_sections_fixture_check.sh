#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
node --test "$here/pr_sections_fixture_check.ts"
node "$here/pr_sections.ts" validate
