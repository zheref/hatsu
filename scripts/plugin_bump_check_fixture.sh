#!/usr/bin/env bash
# Focused, declared verification for scripts/plugin_bump_check.sh.
# Requires Bash, mktemp and jq (invoked by the guard to read plugin versions).
# Invoked only through `nen shu test --lane plugin-bump-guard --repo <hatsu>`.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$repo_root/scripts/plugin_bump_check.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-plugin-bump-guard.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

printf '%s\n' '{"version":"0.16.0"}' > "$fixture_root/base.json"
printf '%s\n' '{"version":"0.16.0"}' > "$fixture_root/head-unchanged.json"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/head-bumped.json"
printf '%s\n' 'No opt-out is declared by this focused fixture.' > "$fixture_root/body.md"
printf '%s\n' 'docs/DISCOVERY.md' > "$fixture_root/changed-discovery.txt"
printf '%s\n' 'docs/LAUNCH-MIGRATION.md' > "$fixture_root/changed-launch-migration.txt"
printf '%s\n' 'docs/WORKFLOW.md' > "$fixture_root/changed-workflow.txt"
printf '%s\n' 'docs/AGENT-ATTRIBUTION.md' > "$fixture_root/changed-agent-attribution.txt"
printf '%s\n' 'docs/ab/plugin-bump-guard.md' > "$fixture_root/changed-unrelated.txt"

run_case() {
  local name="$1" expected_status="$2" changed="$3" head="$4" expected_text="$5"
  local actual_status output

  if output="$(bash "$guard" "$changed" "$fixture_root/base.json" "$head" "$fixture_root/body.md" 2>&1)"; then
    actual_status=0
  else
    actual_status=$?
  fi

  if [ "$actual_status" -ne "$expected_status" ]; then
    printf '%s: expected exit %s, got %s\n%s\n' "$name" "$expected_status" "$actual_status" "$output" >&2
    exit 1
  fi
  if ! printf '%s\n' "$output" | grep -Fq "$expected_text"; then
    printf '%s: missing expected output %s\n%s\n' "$name" "$expected_text" "$output" >&2
    exit 1
  fi
  printf '%s: exit %s\n' "$name" "$actual_status"
}

run_case 'DISCOVERY unchanged version' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-unchanged.json" 'docs/LAUNCH-MIGRATION.md'
run_case 'LAUNCH-MIGRATION unchanged version' 1 "$fixture_root/changed-launch-migration.txt" "$fixture_root/head-unchanged.json" 'docs/LAUNCH-MIGRATION.md'
run_case 'WORKFLOW unchanged version' 1 "$fixture_root/changed-workflow.txt" "$fixture_root/head-unchanged.json" 'docs/WORKFLOW.md'
run_case 'AGENT-ATTRIBUTION unchanged version' 1 "$fixture_root/changed-agent-attribution.txt" "$fixture_root/head-unchanged.json" 'docs/AGENT-ATTRIBUTION.md'
run_case 'DISCOVERY bumped version' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/head-bumped.json" 'plugin.json version bumped'
run_case 'unrelated docs unchanged version' 0 "$fixture_root/changed-unrelated.txt" "$fixture_root/head-unchanged.json" 'no plugin-shipped surface changed'
