#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 -B "$here/pr_sections_fixture_check.py"
python3 -B "$here/pr_sections.py" validate
