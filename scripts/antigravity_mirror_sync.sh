#!/usr/bin/env bash
# antigravity_mirror_sync.sh — generate and check the Antigravity surface mirror.
#
# Generates surfaces/antigravity/ from authored claude/skills and claude/agents:
#   - 41 skill directories under surfaces/antigravity/<name>/SKILL.md
#   - Rewrites 'hatsu:<name>' invocations to '/<name>'
#   - Prepends the Antigravity generation marker after the frontmatter fence
#   - Generates surfaces/antigravity/rules/AGENTS.md (consolidated personas)
#   - Generates surfaces/antigravity/agents/<persona>.md (individual subagents)
#   - Generates surfaces/antigravity/plugin.json and hooks.json
#   - In --check mode, verifies zero drift against disk.

set -euo pipefail
LC_ALL=C

mode="generate"
if [ $# -eq 0 ] || [ "${1:-}" = "--generate" ]; then
  mode="generate"
elif [ "${1:-}" = "--check" ]; then
  mode="check"
elif [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "usage: scripts/antigravity_mirror_sync.sh [--check|--generate]"
  exit 0
else
  echo "antigravity-mirror-sync: unknown option '${1:-}'" >&2
  echo "usage: scripts/antigravity_mirror_sync.sh [--check|--generate]" >&2
  exit 2
fi

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
hatsu_root="$(CDPATH='' cd -- "$script_dir/.." >/dev/null 2>&1 && pwd -P)"

source_skills="$hatsu_root/claude/skills"
source_agents="$hatsu_root/claude/agents"
out_dir="$hatsu_root/surfaces/antigravity"

MARKER="<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->"

[ -d "$source_skills" ] || { echo "source skills missing: $source_skills" >&2; exit 2; }
[ -d "$source_agents" ] || { echo "source agents missing: $source_agents" >&2; exit 2; }

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-antigravity-sync.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/rules" "$tmp_dir/agents" "$tmp_dir/skills"

# 1. Generate plugin.json
plugin_version=$(awk '/"version":/ { gsub(/[^0-9.]/, "", $2); print $2; exit }' "$hatsu_root/.claude-plugin/plugin.json")
[ -n "$plugin_version" ] || plugin_version="0.19.0"

cat > "$tmp_dir/plugin.json" <<EOF
{
  "name": "hatsu",
  "version": "$plugin_version",
  "description": "The local plane of the Akatsuki agent system on Antigravity",
  "author": {
    "name": "zheref"
  },
  "keywords": [
    "hatsu",
    "akatsuki",
    "agent",
    "antigravity",
    "gemini",
    "nen"
  ]
}
EOF

# 2. Derive timeouts from canonical hooks/hooks.json and generate hooks.json
stop_timeout=$(awk '/"Stop":/,/"timeout":/ { if ($1 ~ /"timeout":/) { gsub(/[^0-9]/, "", $2); print $2 } }' "$hatsu_root/hooks/hooks.json" | head -n 1)
guard_timeout=$(awk '/"PreToolUse":/,/"timeout":/ { if ($1 ~ /"timeout":/) { gsub(/[^0-9]/, "", $2); print $2 } }' "$hatsu_root/hooks/hooks.json" | head -n 1)
[ -n "$stop_timeout" ] || stop_timeout=15
[ -n "$guard_timeout" ] || guard_timeout=10

mkdir -p "$tmp_dir/hooks"
for hook_script in guard-base-branch.sh stop-bell.sh; do
  {
    printf '#!/bin/sh\n# %s\n' "$MARKER"
    tail -n +2 "$hatsu_root/hooks/$hook_script"
  } > "$tmp_dir/hooks/$hook_script"
  chmod 755 "$tmp_dir/hooks/$hook_script"
done

cat > "$tmp_dir/hooks.json" <<EOF
{
  "description": "$MARKER",
  "hatsu-trunk-guard": {
    "PreToolUse": [
      {
        "matcher": "run_command",
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'if [ -x ./.agents/hooks/guard-base-branch.sh ]; then exec ./.agents/hooks/guard-base-branch.sh \"\$@\"; elif [ -x \"\${GEMINI_CONFIG_DIR:-\$HOME/.gemini}/config/plugins/hatsu/hooks/guard-base-branch.sh\" ]; then exec \"\${GEMINI_CONFIG_DIR:-\$HOME/.gemini}/config/plugins/hatsu/hooks/guard-base-branch.sh\" \"\$@\"; elif [ -n \"\${HATSU_PLUGIN_ROOT:-}\" ] && [ -x \"\$HATSU_PLUGIN_ROOT/hooks/guard-base-branch.sh\" ]; then exec \"\$HATSU_PLUGIN_ROOT/hooks/guard-base-branch.sh\" \"\$@\"; elif [ -f ./.claude-plugin/plugin.json ] && [ -x ./hooks/guard-base-branch.sh ]; then exec ./hooks/guard-base-branch.sh \"\$@\"; fi' --",
            "timeout": $guard_timeout
          }
        ]
      }
    ]
  },
  "hatsu-stop-bell": {
    "Stop": [
      {
        "type": "command",
        "command": "sh -c 'if [ -x ./.agents/hooks/stop-bell.sh ]; then exec ./.agents/hooks/stop-bell.sh \"\$@\"; elif [ -x \"\${GEMINI_CONFIG_DIR:-\$HOME/.gemini}/config/plugins/hatsu/hooks/stop-bell.sh\" ]; then exec \"\${GEMINI_CONFIG_DIR:-\$HOME/.gemini}/config/plugins/hatsu/hooks/stop-bell.sh\" \"\$@\"; elif [ -n \"\${HATSU_PLUGIN_ROOT:-}\" ] && [ -x \"\$HATSU_PLUGIN_ROOT/hooks/stop-bell.sh\" ]; then exec \"\$HATSU_PLUGIN_ROOT/hooks/stop-bell.sh\" \"\$@\"; elif [ -f ./.claude-plugin/plugin.json ] && [ -x ./hooks/stop-bell.sh ]; then exec ./hooks/stop-bell.sh \"\$@\"; fi' --",
        "timeout": $stop_timeout
      }
    ]
  }
}
EOF

python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$tmp_dir/plugin.json" || { echo "malformed plugin.json" >&2; exit 2; }
python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$tmp_dir/hooks.json" || { echo "malformed hooks.json" >&2; exit 2; }

# 3. Generate individual skills
for skill_dir in "$source_skills"/*; do
  [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ] || continue
  skill_name="$(basename "$skill_dir")"
  target_skill_dir="$tmp_dir/$skill_name"
  mkdir -p "$target_skill_dir"

  # Process SKILL.md:
  # - keep YAML frontmatter
  # - insert MARKER as the first line after frontmatter closing fence
  # - rewrite hatsu:<name> to /<name>
  awk -v marker="$MARKER" '
    BEGIN { in_fm = 0; fm_done = 0 }
    NR == 1 && /^---$/ { in_fm = 1; print; next }
    in_fm && /^---$/ {
      in_fm = 0; fm_done = 1;
      print;
      print marker;
      next
    }
    {
      line = $0
      gsub(/hatsu:/, "/", line)
      print line
    }
  ' "$skill_dir/SKILL.md" > "$target_skill_dir/SKILL.md"

  # Also link or copy into skills/ for plugin structure
  mkdir -p "$tmp_dir/skills/$skill_name"
  cp "$target_skill_dir/SKILL.md" "$tmp_dir/skills/$skill_name/SKILL.md"
done

# 4. Generate individual persona subagents
for agent_file in "$source_agents"/*.md; do
  [ -f "$agent_file" ] || continue
  agent_name="$(basename "$agent_file")"
  awk -v marker="$MARKER" '
    BEGIN { in_fm = 0; fm_done = 0 }
    NR == 1 && /^---$/ { in_fm = 1; print; next }
    in_fm && /^model:/ {
      sub(/: *opus$/, ": pro")
      sub(/: *sonnet$/, ": flash")
      sub(/: *haiku$/, ": flash_lite")
      sub(/: *fable$/, ": ultra")
    }
    in_fm && /^---$/ {
      in_fm = 0; fm_done = 1;
      print;
      print marker;
      next
    }
    {
      line = $0
      gsub(/hatsu:/, "/", line)
      print line
    }
  ' "$agent_file" > "$tmp_dir/agents/$agent_name"
done

# 5. Generate consolidated rules/AGENTS.md
{
  printf '%s\n\n' "$MARKER"
  printf '# Hatsu Personas for Antigravity\n\n'
  # Kurapika first
  if [ -f "$source_agents/kurapika.md" ]; then
    printf '## kurapika\n\n'
    awk '
      BEGIN { in_fm = 0; started = 0 }
      NR == 1 && /^---$/ { in_fm = 1; next }
      in_fm && /^---$/ { in_fm = 0; started = 1; next }
      started {
        line = $0
        gsub(/hatsu:/, "/", line)
        print line
      }
    ' "$source_agents/kurapika.md"
    printf '\n---\n\n'
  fi
  # Other agents sorted
  for agent_file in "$source_agents"/*.md; do
    [ -f "$agent_file" ] || continue
    name="$(basename "$agent_file" .md)"
    [ "$name" != "kurapika" ] || continue
    printf '## %s\n\n' "$name"
    awk '
      BEGIN { in_fm = 0; started = 0 }
      NR == 1 && /^---$/ { in_fm = 1; next }
      in_fm && /^---$/ { in_fm = 0; started = 1; next }
      started {
        line = $0
        gsub(/hatsu:/, "/", line)
        print line
      }
    ' "$agent_file"
    printf '\n---\n\n'
  done
} > "$tmp_dir/rules/AGENTS.md"

# Copy root AGENTS.md for direct workspace rules discovery
cp "$tmp_dir/rules/AGENTS.md" "$tmp_dir/AGENTS.md"

if [ "$mode" = "check" ]; then
  drift=0
  if [ ! -d "$out_dir" ]; then
    echo "antigravity-mirror-check: $out_dir does not exist." >&2
    exit 1
  fi

  # Check diff
  if ! diff -ru --exclude='.DS_Store' "$tmp_dir" "$out_dir" >/dev/null 2>&1; then
    echo "antigravity-mirror-check: drift detected between generated and committed surfaces/antigravity:" >&2
    diff -ru --exclude='.DS_Store' --brief "$tmp_dir" "$out_dir" >&2 || true
    exit 1
  fi
  echo "antigravity-mirror-check: surfaces/antigravity matches fresh generation."
  exit 0
else
  # Generate
  mkdir -p "$out_dir"
  if [ -d "$out_dir" ]; then
    # Refuse unowned files in out_dir
    while IFS= read -r -d '' existing_file; do
      [ -f "$existing_file" ] || continue
      case "$(basename "$existing_file")" in
        plugin.json|hooks.json|guard-base-branch.sh|stop-bell.sh|AGENTS.md|SKILL.md|*.md)
          ;;
        *)
          echo "antigravity-mirror-sync: unrecognized unowned file in $out_dir: $existing_file" >&2
          exit 2
          ;;
      esac
    done < <(find "$out_dir" -type f -print0)
  fi
  cp -R "$tmp_dir"/* "$out_dir"/
  echo "antigravity-mirror-sync: generated complete surfaces/antigravity successfully."
fi
