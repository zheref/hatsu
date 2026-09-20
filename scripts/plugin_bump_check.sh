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
#                       feitan, chrollo, illumi; from Hatsu 0.25.0, netero), `commands` (/kurapika), and
#                       `skills` (the 40 skills + hatsu-warmup — 35 until
#                       Hatsu 0.6.0 added susanoo, kagutsuchi and mugetsu, 38
#                       until 0.24.0 added byakugan, 39 until 0.27.0 added
#                       third-hand), plus
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
#   docs/AGENT-ATTRIBUTION.md
#                     — the PR-body participant ledger canon linked by commit
#                       and PR skills. A stale copy can misstate who acted.
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
#   scripts/hanten_cycle_ledger.sh
#                     — Hanten's per-effort reviewer-budget writer (Hatsu 0.26.0,
#                       zheref/hatsu#63). An installed copy runs it from
#                       `$hatsu_root/scripts/` on every hanten invocation; a
#                       stale copy would reset or ignore cycle counts and
#                       re-raise Chrollo after remediation.
#   scripts/hatsu_plugin_update.sh
#                     — the plugin-source updater (Hatsu 0.31.0). Warm-up § 4b
#                       runs it with --auto from `$hatsu_root/scripts/` on every
#                       session; a stale copy would skip the refresh or apply the
#                       wrong channel, so this runtime script is covered; the
#                       fixture check beside it is test-only and is not.
#   .mcp.json         — forward-proofing, same reasoning: an MCP server
#                       declaration is read by the installed plugin at start-up.
#
# Deliberately NOT covered — nothing installed reads them at run time:
#   README.md, docs/ab/** (the evidence records; read by humans on GitHub, never
#   by an installed copy), scripts/surface_bootstrap_fixture_check.sh and other
#   scripts/** (CI-only; the runtime bootstrap, hanten cycle ledger and plugin
#   updater are the explicit exceptions above),
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
  'docs/AGENT-ATTRIBUTION.md'
  'docs/STANDALONE-ENTRY.md'
  'docs/GATE-CONFIGURATION.md'
  'hooks/*'
  'templates/*'
  'surfaces/*'
  'scripts/surface_bootstrap.sh'
  'scripts/hanten_cycle_ledger.sh'
  'scripts/hatsu_plugin_update.sh'
  'scripts/tenkai_adopt.sh'
  'scripts/release-publish.sh'
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
  # `|| [ -n "$path" ]`: a changed-files list whose LAST line carries no
  # trailing newline still has that line handed to `read`, which sets $path
  # from it before returning failure at EOF -- the bare `while read` form
  # never enters the loop body for that final read, so an unterminated last
  # line was silently dropped from the scan (QA-16).
  while IFS= read -r path || [ -n "$path" ]; do
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

# --- semver_parts VERSION ----------------------------------------------------
# Echoes "MAJOR MINOR PATCH PRERELEASE" (space-separated; PRERELEASE may be
# empty) for a well-formed `MAJOR.MINOR.PATCH[-PRERELEASE]` string, or nothing
# at all for anything else. Deliberately narrow: this guard's job is to compare
# two versions it already trusts are meant to be semver, not to accept
# arbitrary plugin.json content as one. Build metadata (a trailing `+...`) is
# not accepted — plugin.json has never carried one and a guard that silently
# ignored it would compare the wrong string.
semver_parts() {
  local version="$1"
  case "$version" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) return 1 ;;
  esac
  local core="$version" prerelease=""
  case "$version" in
    *-*) core="${version%%-*}"; prerelease="${version#*-}" ;;
  esac
  local major="${core%%.*}" rest="${core#*.}"
  local minor="${rest%%.*}" patch="${rest#*.}"
  case "$major" in ''|*[!0-9]*) return 1 ;; esac
  case "$minor" in ''|*[!0-9]*) return 1 ;; esac
  case "$patch" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s %s %s %s\n' "$major" "$minor" "$patch" "$prerelease"
}

# --- version_greater BASE HEAD -----------------------------------------------
# Returns 0 if HEAD is a strict semver INCREASE over BASE: MAJOR, then MINOR,
# then PATCH, compared numerically in that order, with a lower or equal triple
# failing regardless of any pre-release suffix. A malformed HEAD or BASE is
# never "greater" — it fails closed, which is what version_bumped's caller
# turns into the named refusal rather than a silent pass.
#
# WHY NOT `!=`. The guard this replaces accepted ANY change, including a
# DOWNGRADE — v0.40.0 was never tagged because a later PR's plugin.json still
# read a version two releases behind, `!=` was satisfied, and the guard passed
# a PR that made the manifest wrong in the other direction. An increase is the
# only change that keeps Claude Code's plugin-cache key ahead of what shipped.
version_greater() {
  local base="$1" head="$2" base_parts head_parts
  base_parts="$(semver_parts "$base")" || return 1
  head_parts="$(semver_parts "$head")" || return 1
  local bmaj bmin bpat hmaj hmin hpat n
  IFS=' ' read -r bmaj bmin bpat _ <<< "$base_parts"
  IFS=' ' read -r hmaj hmin hpat _ <<< "$head_parts"
  # A component longer than 18 digits is outside bash's signed 64-bit integer
  # range: `[ "$x" -gt "$y" ]` on one would not compare, it would print
  # `[: integer expression expected` to stderr and this guard's -e would take
  # that as a crash rather than a refusal. semver has never needed a
  # major/minor/patch this large, so a value that large fails closed instead.
  for n in "$bmaj" "$bmin" "$bpat" "$hmaj" "$hmin" "$hpat"; do
    [ "${#n}" -le 18 ] || return 1
  done
  [ "$hmaj" -gt "$bmaj" ] && return 0
  [ "$hmaj" -lt "$bmaj" ] && return 1
  [ "$hmin" -gt "$bmin" ] && return 0
  [ "$hmin" -lt "$bmin" ] && return 1
  [ "$hpat" -gt "$bpat" ] && return 0
  return 1
}

# --- version_bumped BASE_PLUGIN_JSON HEAD_PLUGIN_JSON ------------------------
# Returns 0 if HEAD's `version` field is a STRICT SEMVER INCREASE over BASE's —
# not merely different. A HEAD that is malformed, equal to, or lower than BASE
# fails; the CLI below reports which and why.
#
# THE ONLY LEGITIMATE "NO PRIOR VERSION" IS THE REPOSITORY'S FIRST COMMIT, AND
# IT IS MARKED, NEVER GUESSED. `.github/workflows/plugin-bump-check.yml` writes
# a `<base>.absent` sentinel file ONLY when the API told it the manifest
# genuinely does not exist at BASE_SHA (a 404) — never on an auth failure, a
# rate limit, or a network blip, all of which also leave the base manifest
# unreadable but are not evidence of anything about the head version. Before
# that sentinel existed, ANY unreadable base — including the workflow's own
# `... || echo '{}' > base_plugin.json` fallback on ANY API failure — read as
# "first commit" and returned bumped: a fail-open on the exact input this
# guard cannot re-derive (QA-15/QA-16, the hostile fixture's base-manifest
# corpus). Now an empty, absent, malformed, or unreadable base with NO
# sentinel fails CLOSED, the same as a base that parses but carries no
# `version` field.
version_bumped() {
  local base="$1" head="$2" base_version head_version
  head_version="$(plugin_version "$head")"
  [ -n "$head_version" ] || return 1
  if [ ! -e "$base" ]; then
    [ -f "${base}.absent" ] && return 0
    return 1
  fi
  base_version="$(plugin_version "$base")"
  [ -n "$base_version" ] || return 1
  version_greater "$base_version" "$head_version"
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
# An invisible declaration is not a declaration. Two ways markdown hides
# text from the rendered PR while still handing it to this grep verbatim:
#   - an HTML comment (`<!-- no plugin bump: … -->`), which can span multiple
#     lines and is never shown by GitHub's renderer;
#   - a fenced code block (``` … ```), where the phrase is being QUOTED as an
#     example (this file's own refusal message ends with the phrase) rather
#     than stated as a declaration.
# Both are stripped, in one pass with awk (no python), before the grep below
# ever sees the text.
strip_invisible_markdown() {
  awk '
    BEGIN { in_comment = 0; in_fence = 0 }
    {
      line = $0
      if (in_comment) {
        if (index(line, "-->") > 0) { sub(/^.*-->/, "", line); in_comment = 0 } else { next }
      }
      while (!in_comment && index(line, "<!--") > 0) {
        pre = substr(line, 1, index(line, "<!--") - 1)
        rest = substr(line, index(line, "<!--") + 4)
        if (index(rest, "-->") > 0) {
          line = pre substr(rest, index(rest, "-->") + 3)
        } else {
          line = pre
          in_comment = 1
        }
      }
      if (line ~ /^[[:space:]]*```/) { in_fence = !in_fence; next }
      if (in_fence) next
      print line
    }
  '
}

pr_body_has_opt_out() {
  local file="$1"
  [ -f "$file" ] || return 1
  strip_invisible_markdown < "$file" \
    | grep -qiE '^[[:space:]]*(>[[:space:]]*|-[[:space:]]+)*no plugin bump:[[:space:]]*[^[:space:]]'
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
  [ -r "$changed_files" ] || {
    echo "error: changed-files-file '$changed_files' exists but is not readable — refusing to fail-open on a bad workflow wiring input" >&2
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

  base_version_reported="$(plugin_version "$base_plugin")"
  head_version_reported="$(plugin_version "$head_plugin")"
  {
    echo "plugin.json version is not a strict increase: base ${base_version_reported:-<none>} -> head ${head_version_reported:-<none>}"
    echo "a version that does not increase is how v0.40.0 went untagged"
  } >&2

  # Generated FROM the array rather than transcribed: a hand-copied list
  # drifts the moment a glob is added to PLUGIN_SURFACE_GLOBS and nobody
  # remembers to update this message too (it had fallen to 18 of 21).
  globs_list="$(IFS=', '; echo "${PLUGIN_SURFACE_GLOBS[*]}")"

  {
    echo "This PR changes a plugin-shipped surface ($globs_list)"
    echo "but $head_plugin's \`version\` does not carry a strictly higher"
    echo "version than $base_plugin's — equal, lower (a downgrade), or"
    echo "unparseable all fail this check the same way."
    echo
    echo "Claude Code keys its plugin cache on that field. An already-installed Hatsu"
    echo "will never pick this change up until the version is bumped — no error, no"
    echo "warning, the change simply does not ship. (Ported from the frozen reference"
    echo "implementation's own guard, filed after exactly this omission shipped a"
    echo "four-surface change to nobody.)"
    echo
    echo 'Bump `.claude-plugin/plugin.json`'"'"'s `version` (semver):'
    echo "  - patch  — wording/fix-only change to a shipped surface."
    echo "  - minor  — an agent definition's or a skill's BEHAVIOUR changes; a new skill;"
    echo "             a new pinned nen ref in nen/contract.json."
    echo "  - major  — a breaking change to the plugin's public interface (a command, an"
    echo "             agent's invocation contract, the shape of the Nen contract) — on a"
    echo "             0.x plugin, the MINOR carries these, per SemVer 2.0.0 clause 4."
    echo
    echo "Or, if this change provably does not affect the shipped plugin surface (e.g. a"
    echo 'comment-only edit), state `no plugin bump: <reason>` in the PR body.'
  } >&2
  exit 1
fi
