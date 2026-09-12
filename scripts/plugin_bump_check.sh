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
# This guard is a port of the frozen reference implementation's own
# `scripts/plugin_bump_check.sh`, filed there after a prior incident in which a
# single PR changed four plugin-shipped surfaces — an agent definition, a skill,
# a script, and the registry read at warm-up — without bumping the version. The
# fix never reached an installed plugin until a later PR bumped it retroactively.
# The guard moves to Hatsu because guards live beside the surface they guard, and
# this is now that surface (zheref/hatsu#3; the migration plan, private).
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
# `.github/workflows/plugin-bump-check.yml` calls, after that workflow has already
# computed the changed-files list, the base `plugin.json` and the PR body from the
# event payload and the API.
#
# Strict mode is gated to the EXECUTED path: sourcing this file to exercise
# the pure functions must not mutate the caller shell's options (an inherited
# `-u`/`-e` in a sourcing harness is a side effect, not a safety).
if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  set -euo pipefail
fi

# --- The plugin-shipped surface ---------------------------------------------
# Derived from what `.claude-plugin/plugin.json` actually declares, plus the
# files an installed copy READS AT RUN TIME. Staleness in either is the same
# failure: the repository is right and the installed plugin is wrong.
#
#   .claude-plugin/*  — the manifests themselves (plugin.json, marketplace.json).
#   claude/*          — everything plugin.json points at: `agents` (kurapika,
#                       gon, hisoka, phinks, uvogin, and — from Hatsu 0.5.0 —
#                       feitan, chrollo, illumi), `commands` (/kurapika), and
#                       `skills` (the 38 skills + hatsu-warmup — 35 until
#                       Hatsu 0.6.0 added susanoo, kagutsuchi and mugetsu), plus
#                       `templates/` where a skill renders from one.
#   nen/*             — the D10 dependency contract, `nen/contract.json`. Read
#                       at run time through `$CLAUDE_PLUGIN_ROOT/nen/contract.json`
#                       by the warm-up skill and by the agent definitions, and it
#                       is the single source of truth for the pinned nen ref. A
#                       stale copy pins an installed plugin to the wrong nen
#                       build. (It was `nen.contract.json` at the root until
#                       Hatsu 0.3.0; the directory is nen's own location for a
#                       repository's contract and taxonomy, so the glob covers
#                       any taxonomy file that ever lands beside it.)
#   contracts/*       — `reference.gates.json`, passed as `nen pr ready
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
#   docs/WORKFLOW.md  — the two-file configuration model and workflow authority
#                       read by phase skills. A stale installed copy can apply
#                       an obsolete workflow rule.
#   docs/DISCOVERY.md — the shared discovery and filing protocol linked by the
#                       filing, review, and orchestration surfaces. A stale copy
#                       can repeat an unreconciled external write.
#   docs/LAUNCH-MIGRATION.md
#                     — the launch/extraction transition and current release
#                       boundary linked by launch skills. A stale copy can
#                       suggest an unsupported migration or release state.
#   hooks/*           — the harness hooks, discovered by Claude Code at the
#                       plugin's default `hooks/hooks.json` and executed on
#                       EVERY session: a Stop bell and a PreToolUse refusal to
#                       commit on the trunk (Hatsu 0.4.0). The glob predated
#                       them by a version, deliberately — a guard that had to be
#                       remembered on the day the first hook landed is a guard
#                       that is not there.
#   templates/*       — the report templates a skill renders from through
#                       `$CLAUDE_PLUGIN_ROOT/templates/<name>.html`
#                       (`nen/workflow.json` → `reports.template`). SAME
#                       CRITERION AS docs/ROSTER.md: an installed copy reads it
#                       at run time, so a stale template renders a stale report
#                       on every machine that already has the plugin.
#   surfaces/*        — the GENERATED Codex and Cursor mirrors (Hatsu 0.7.0).
#                       SAME CRITERION AS templates/ AND docs/ROSTER.md, and it
#                       is the run-time read that puts them here rather than
#                       their being generated: on Codex and Cursor there is no
#                       plugin loader, so `hatsu-warmup` § 5 reads
#                       `$CLAUDE_PLUGIN_ROOT/surfaces/<surface>/` and links (or
#                       copies) it into the repository the session is standing
#                       in. An installed copy whose mirrors are stale therefore
#                       serves stale skills to two of the three surfaces —
#                       invisibly, because the SOURCE under claude/skills/ is
#                       right and only the mirror is wrong, which is the harder
#                       version of the failure this guard exists for. And
#                       BECAUSE they are generated, they change on exactly the
#                       PRs that change claude/**, which the glob above already
#                       covers: this row is what makes a regeneration-only
#                       commit (a mirror re-run with no source edit) bump the
#                       version too.
#   scripts/surface_bootstrap.sh
#                     — the one non-skill first-run installer for Codex and
#                       Cursor. It is invoked from an installed checkout before
#                       hatsu-warmup can be discovered, then by that warm-up for
#                       each complete surface refresh. A stale installed copy
#                       recreates the first-run failure this guard exists to
#                       prevent, so this one runtime script is covered; the
#                       fixture check beside it is test-only and is not.
#   .mcp.json         — forward-proofing, same reasoning: an MCP server
#                       declaration is read by the installed plugin at start-up.
#
# Deliberately NOT covered — nothing installed reads them at run time:
#   README.md, docs/ab/** (the evidence records; read by humans on GitHub, never
#   by an installed copy), scripts/surface_bootstrap_fixture_check.sh and other
#   scripts/** (CI-only; the runtime bootstrap is the explicit exception above),
#   .github/**.
#
# Bash `[[ == glob ]]` matches `*` across `/` — it is pattern matching, not
# filename globbing — so `claude/*` and `.claude-plugin/*` cover any depth.
PLUGIN_SURFACE_GLOBS=(
  '.claude-plugin/*'
  'claude/*'
  'nen/*'
  'contracts/*'
  'docs/ROSTER.md'
  'docs/delegation-grammar-DRAFT.md'
  'docs/WORKFLOW.md'
  'docs/DISCOVERY.md'
  'docs/LAUNCH-MIGRATION.md'
  'hooks/*'
  'templates/*'
  'surfaces/*'
  'scripts/surface_bootstrap.sh'
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
# Returns 0 if PR_BODY_FILE DECLARES the `no plugin bump: <reason>` opt-out (for
# a change that provably does not affect the shipped plugin surface). Two things
# make a declaration, and both are required:
#
#   1. A REASON. A bare `no plugin bump:` with nothing after it is not an
#      opt-out — the reason is the point.
#   2. THE LINE STARTS WITH IT. The opt-out is a statement the PR body makes,
#      not a phrase it contains. The unanchored pattern this replaces matched
#      PROSE that merely mentioned the phrase, so a body writing
#      "claims no `no plugin bump:` opt-out" — or a review comment quoting the
#      refusal message, which itself ends with the sentence
#      "state `no plugin bump: <reason>` in the PR body" — SATISFIED the guard
#      and skipped the version check. A guard defeated by describing it is not
#      a guard. (Recorded with the refuse/pass transcripts in
#      docs/ab/plugin-bump-guard.md § 8.)
#
# The prefix a real declaration may carry is bookkeeping only: leading
# whitespace, blockquote `>` markers and `-` list bullets, in any order. Nothing
# else — a backtick, a `*` bullet inside a sentence, or any other character
# before the phrase means it is being talked about rather than declared.
#
# The two markers are NOT spelled the same way, and the asymmetry is the point:
#
#   `>`  needs no following whitespace. `>no plugin bump: …` is a valid
#        blockquote, and `>` is not a character that starts an English word.
#   `-`  REQUIRES whitespace after it, because a list bullet has some and a
#        hyphen does not. Accepting a bare `-` re-opened the same hole one
#        character narrower: `-no plugin bump: …` (a hyphenated phrase),
#        `--no plugin bump: …` (a CLI flag) and `-> no plugin bump: …` (an
#        arrow) all matched, and none of them declares anything. Found by
#        Copilot on zheref/hatsu#34; transcripts in
#        docs/ab/plugin-bump-guard.md § 8.
pr_body_has_opt_out() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -qiE '^[[:space:]]*(>[[:space:]]*|-[[:space:]]+)*no plugin bump:[[:space:]]*[^[:space:]]' "$file"
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
nen/**, contracts/**, docs/ROSTER.md,
docs/delegation-grammar-DRAFT.md, docs/WORKFLOW.md, docs/DISCOVERY.md,
docs/LAUNCH-MIGRATION.md, hooks/**, templates/**, surfaces/**,
scripts/surface_bootstrap.sh, or .mcp.json)
but leaves
.claude-plugin/plugin.json's `version` field unchanged.

Claude Code keys its plugin cache on that field. An already-installed Hatsu
will never pick this change up until the version is bumped — no error, no
warning, the change simply does not ship. (Ported from the frozen reference
implementation's own guard, filed after exactly this omission shipped a
four-surface change to nobody.)

Bump `.claude-plugin/plugin.json`'s `version` (semver):
  - patch  — wording/fix-only change to a shipped surface.
  - minor  — an agent definition's or a skill's BEHAVIOUR changes; a new skill;
             a new pinned nen ref in nen/contract.json.
  - major  — a breaking change to the plugin's public interface (a command, an
             agent's invocation contract, the shape of the Nen contract) — on a
             0.x plugin, the MINOR carries these, per SemVer 2.0.0 clause 4.

Or, if this change provably does not affect the shipped plugin surface (e.g. a
comment-only edit), state `no plugin bump: <reason>` in the PR body.
EOF
  exit 1
fi
