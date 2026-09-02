#!/usr/bin/env bash
# plugin_bump_check.sh — plugin-version bump guard for Hatsu.
#
# THE MECHANISM THIS PROTECTS
# Claude Code keys its plugin cache on `.claude-plugin/plugin.json`'s `version`
# field. Change a plugin-shipped surface without changing that field and the
# change is real in the repository and invisible on every machine that already
# has the plugin installed: the cached copy is never refreshed, so the fix ships
# to nobody. There is no error, no warning, and no way to tell from the PR that
# it happened.
#
# THE INCIDENT RECORD (inherited, kept deliberately)
# This guard is a port of bankai-core's `scripts/plugin_bump_check.sh`, filed
# there as BC-IS-#557 item 5 after BC-PR-#546 changed four plugin-shipped
# surfaces — an agent definition, a skill, a script, and the registry read at
# warm-up — without bumping the version. The fix never reached an installed
# plugin until BC-PR-#578 bumped it retroactively. The guard moves to Hatsu
# because guards live beside the surface they guard, and this is now that
# surface (zheref/hatsu#3; the migration plan's §3 and §10).
#
# WHAT IT DOES
# A PR whose diff touches a plugin-shipped surface but leaves
# `.claude-plugin/plugin.json`'s `version` unchanged FAILS — unless the PR body
# carries a documented `no plugin bump: <reason>` opt-out.
#
# SHAPE
# Pure comparison logic above, CLI at the bottom. Everything above the
# `BASH_SOURCE` guard runs without git, gh or a network, so it can be sourced
# and exercised directly (see docs/ab/plugin-bump-guard.md for the recorded
# refuse/pass transcripts). The CLI is what
# `.github/workflows/plugin-bump-check.yml` calls, after that workflow has
# already computed the changed-files list, the base `plugin.json` and the PR
# body from the event payload and the API.
set -euo pipefail

# --- The plugin-shipped surface ---------------------------------------------
# Derived from what `.claude-plugin/plugin.json` actually declares, plus the
# files an installed copy READS AT RUN TIME. Staleness in either is the same
# failure: the repository is right and the installed plugin is wrong.
#
#   .claude-plugin/*  — the manifests themselves (plugin.json, marketplace.json).
#   claude/*          — everything plugin.json points at: `agents` (kurapika,
#                       gon, hisoka, phinks, uvogin), `commands` (/kurapika),
#                       and `skills` (the 17 ported skills + hatsu-warmup).
#   nen.contract.json — the D10 dependency contract. Read at run time through
#                       `$CLAUDE_PLUGIN_ROOT/nen.contract.json` by the warm-up
#                       skill and by the agent definitions, and it is the single
#                       source of truth for the pinned nen ref. A stale copy
#                       pins an installed plugin to the wrong nen build.
#   contracts/*       — `bankai-core.gates.json`, passed as `nen pr ready
#                       --gates "$CLAUDE_PLUGIN_ROOT/contracts/…"` by pr-state,
#                       drive, backlog-state, futon and tensho. Stale reviewer
#                       identities produce a wrong readiness verdict, silently.
#   docs/ROSTER.md    — cited by `claude/agents/kurapika.md` and
#                       `claude/commands/kurapika.md` as *the authority* on who
#                       exists and what standing they have. An installed plugin
#                       reading a stale roster can act as an agent whose row was
#                       changed, or miss one that was added.
#   docs/delegation-grammar-DRAFT.md
#                     — SAME CRITERION AS ROSTER, and it was wrong to exclude it
#                       for being "a draft": `claude/agents/gon.md` § mandates
#                       "Read `docs/delegation-grammar-DRAFT.md` before your
#                       first act of any run", and `claude/agents/kurapika.md`
#                       cites it for the unratified-grant rule. An installed
#                       copy reads it AT RUN TIME. Being a draft is a statement
#                       about its authority, not about whether it ships — a
#                       stale draft is exactly as invisible as a stale roster.
#   hooks/*           — forward-proofing. Nothing lives here today; the day a
#                       hook is added it is plugin-shipped and executed on every
#                       session, and a guard that had to be remembered at that
#                       moment is a guard that is not there.
#   .mcp.json         — forward-proofing, same reasoning: an MCP server
#                       declaration is read by the installed plugin at start-up.
#
# Deliberately NOT covered — nothing installed reads them at run time:
#   README.md, docs/ab/** (the evidence records; read by humans on GitHub, never
#   by an installed copy), scripts/** (CI-only; no agent or skill invokes
#   anything here), .github/**.
#
# Bash `[[ == glob ]]` matches `*` across `/` — it is pattern matching, not
# filename globbing — so `claude/*` and `.claude-plugin/*` cover any depth.
PLUGIN_SURFACE_GLOBS=(
  '.claude-plugin/*'
  'claude/*'
  'nen.contract.json'
  'contracts/*'
  'docs/ROSTER.md'
  'docs/delegation-grammar-DRAFT.md'
  'hooks/*'
  '.mcp.json'
)

# --- path_is_plugin_surface PATH --------------------------------------------
# Returns 0 (true) if PATH is a plugin-shipped surface this guard covers.
path_is_plugin_surface() {
  local path="$1" glob
  for glob in "${PLUGIN_SURFACE_GLOBS[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$path" == $glob ]]; then
      return 0
    fi
  done
  return 1
}

# --- any_path_is_plugin_surface CHANGED_FILES_FILE --------------------------
# CHANGED_FILES_FILE: one changed path per line. Returns 0 if ANY line is a
# plugin-shipped surface path, 1 otherwise.
any_path_is_plugin_surface() {
  local file="$1" path
  [ -f "$file" ] || return 1
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    path_is_plugin_surface "$path" && return 0
  done < "$file"
  return 1
}

# --- plugin_version FILE -----------------------------------------------------
# Echoes plugin.json's top-level `version` field (empty if the file is absent,
# unreadable, or has none).
plugin_version() {
  local file="$1"
  [ -f "$file" ] || { echo ""; return; }
  jq -r '.version // empty' "$file" 2>/dev/null || echo ""
}

# --- version_bumped BASE_PLUGIN_JSON HEAD_PLUGIN_JSON ------------------------
# Returns 0 if the `version` field actually changed between BASE and HEAD:
# HEAD carries a non-empty version different from BASE's.
version_bumped() {
  local base="$1" head="$2" base_version head_version
  head_version="$(plugin_version "$head")"
  [ -n "$head_version" ] || return 1
  base_version="$(plugin_version "$base")"
  [ "$head_version" != "$base_version" ]
}

# --- pr_body_has_opt_out PR_BODY_FILE ----------------------------------------
# Returns 0 if PR_BODY_FILE carries the `no plugin bump: <reason>` opt-out (for
# a change that provably does not affect the shipped plugin surface). A bare
# `no plugin bump:` with nothing after it is NOT an opt-out — the reason is the
# point.
pr_body_has_opt_out() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -qiE 'no plugin bump:[[:space:]]*[^[:space:]]' "$file"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  [ "$#" -eq 4 ] || {
    echo "usage: $0 <changed-files-file> <base-plugin-json> <head-plugin-json> <pr-body-file>" >&2
    exit 2
  }
  changed_files="$1" base_plugin="$2" head_plugin="$3" pr_body="$4"

  [ -f "$changed_files" ] || {
    echo "error: changed-files-file '$changed_files' does not exist — refusing to fail-open on a bad workflow wiring input" >&2
    exit 2
  }

  if ! any_path_is_plugin_surface "$changed_files"; then
    echo "no plugin-shipped surface changed — plugin-bump guard does not apply"
    exit 0
  fi

  if pr_body_has_opt_out "$pr_body"; then
    echo "plugin-bump opt-out present in PR body — skipping version check"
    exit 0
  fi

  if version_bumped "$base_plugin" "$head_plugin"; then
    echo "plugin.json version bumped — plugin-bump guard satisfied"
    exit 0
  fi

  cat >&2 <<'EOF'
This PR changes a plugin-shipped surface (.claude-plugin/**, claude/**,
nen.contract.json, contracts/**, docs/ROSTER.md,
docs/delegation-grammar-DRAFT.md, hooks/**, or .mcp.json) but leaves
.claude-plugin/plugin.json's `version` field unchanged.

Claude Code keys its plugin cache on that field. An already-installed Hatsu
will never pick this change up until the version is bumped — no error, no
warning, the change simply does not ship. (Ported from bankai-core's
BC-IS-#557 item 5, filed after exactly this omission shipped BC-PR-#546 to
nobody.)

Bump `.claude-plugin/plugin.json`'s `version` (semver):
  - patch  — wording/fix-only change to a shipped surface.
  - minor  — an agent definition's or a skill's BEHAVIOUR changes; a new skill;
             a new pinned nen ref in nen.contract.json.
  - major  — a breaking change to the plugin's public interface (a command, an
             agent's invocation contract, the shape of the Nen contract).

Or, if this change provably does not affect the shipped plugin surface (e.g. a
comment-only edit), state `no plugin bump: <reason>` in the PR body.
EOF
  exit 1
fi
