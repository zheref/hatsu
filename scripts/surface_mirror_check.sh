#!/usr/bin/env bash
# surface_mirror_check.sh — the generated-surface drift guard for Hatsu.
#
# THE MECHANISM THIS PROTECTS
# `claude/skills/**` and `claude/agents/**` are the ONE authored copy of every
# skill and persona. `surfaces/codex/**`, `surfaces/cursor/**` and
# `surfaces/antigravity/**` are generated from them by `nen surface mirror
# generate` and committed, because a Codex, Cursor or Antigravity session has
# no plugin loader: the warm-up places those files into the repository the
# session is standing in (claude/skills/hatsu-warmup/SKILL.md § 5). Edit a
# SKILL.md without regenerating and the other surfaces keep serving the
# previous wording — silently, with no error anywhere, exactly the way an
# un-bumped plugin.json keeps serving the previous plugin.
#
# ONE GENERATOR FOR ALL THREE SURFACES. Antigravity used to run its own
# generator (`scripts/antigravity_mirror_sync.sh`, now retired) — its own
# marker, its own tier remap and an unanchored `gsub(/hatsu:/, "/")`. That
# split meant the codex/cursor drift check was the only one wired as a real
# `nen surface mirror check`, and antigravity's own drift check was advisory
# through a second, unrelated script. There is now exactly one generator and
# one check for every surface, codex, cursor and antigravity alike, each
# invoked with the same shared flags below.
#
# WHAT IT DOES
# Runs `nen surface mirror check` for every surface in SURFACES with whichever
# `nen` is on PATH. That verb REGENERATES IN MEMORY and diffs; it writes
# nothing at all, so this script is safe to run anywhere, including on a dirty
# tree.
#
# EXIT CODES — and the one that matters most is 2.
#   0  every mirror is byte-identical to a fresh generation
#   1  drift, in nen's own drift classes: missing / extra / stale / hand-edited
#   2  the `nen` on PATH HAS NO `surface` VERB — said in those words; also the
#      wiring errors (a root that is not a Hatsu checkout, a refusal from the
#      verb itself), which are invocation defects rather than drift
#   3  no `nen` on PATH at all
#
# USAGE
#   scripts/surface_mirror_check.sh [repo-root]
#   scripts/surface_mirror_check.sh --installed <path> [repo-root]
#   NEN_BIN=/path/to/nen scripts/surface_mirror_check.sh
#
# `--installed <path>` checks the PLUGIN CACHE at <path> instead of the
# in-tree `surfaces/<surface>/` mirrors: it runs
# `nen surface mirror check --installed <path> --surface claude-code` alongside
# the shared flags, so a stale post-cut host re-pin (#90) is caught the same
# way as an in-tree mirror going stale.
#
# 2 is not "nothing to check". A guard that reported success when it could not
# run is an unperformed check rendered as a passing one — the failure
# nen/contract.json § no_improvised_fallback names, and the same failure the
# plugin-bump guard was filed after. The build pinned in nen/contract.json
# CARRIES the verb — it predated it through v0.4.0 (`nen surface` →
# "nen: unknown command 'surface'", exit 2; transcript in docs/surfaces/evidence/surfaces.md
# § 2.3). So 2 is now UNEXPECTED: at this pin it means the nen on PATH is not the
# pinned one, and .github/workflows/surface-mirror-check.yml turns it into an
# ERROR rather than the skip-with-notice it used to be. Verified against the
# pinned build: this script exits 0 for codex, cursor and antigravity against a
# fresh generation (`ok: 62` codex; `ok: 61` cursor/antigravity — skills plus
# personas plus the preamble include, plus the hook, rules, permission and
# manifest files). Re-read the counts a run actually prints after a
# regeneration rather than remember them here: a skill count, a persona
# layout (one include today; nen may fold `_review-preamble.md` into a plain
# `include` and move where antigravity's skills live) and a stamp all shift
# the number without this comment noticing.
#
# NOT A SECOND LINT. nen/contract.json's `plugin` lane keeps exactly one lint
# seat — `claude plugin validate . --strict` — and nen/workflow.json's
# `iteration.checks` keeps exactly that one entry. This is a documented step of
# the loop (docs/WORKFLOW.md § 2 → `iteration`), run beside the regeneration and
# inside `mukai`, not a verb bolted into the declaration.
set -euo pipefail

SOURCE_DIR="claude/skills"
AGENTS_DIR="claude/agents"
INVOCATION_PREFIX="hatsu:"
SURFACES=(codex cursor antigravity)
MODELS_FILE="nen/workflow.json"
PERMISSIONS_FILE="contracts/permissions.json"
HOOKS_FILE="hooks/hooks.json"
RULES_FILE="claude/rules/hatsu.md"
SOURCE_SURFACE="claude"   # the personas carry models.claude aliases; --models reads them back to tiers
MANIFEST_FILE=".claude-plugin/plugin.json"
# The expression every mirrored hook command resolves the plugin root through: the warm-up exports
# HATSU_PLUGIN_ROOT; the workspace copy is the LAST fallback, never ahead of the plugin root, and
# Antigravity's global plugin dir is the fallback there (docs/surfaces/antigravity.md).
hooks_root_for() {
  case "$1" in
    antigravity) printf %s '${HATSU_PLUGIN_ROOT:-${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu}' ;;
    codex) printf %s '${HATSU_PLUGIN_ROOT:-./.codex}' ;;
    cursor) printf %s '${HATSU_PLUGIN_ROOT:-./.cursor}' ;;
  esac
}
installed_path=""

# --- usage: surface_mirror_check.sh [--installed <path>] [repo-root] -------
# With no argument, the repository this script ships in — however it was
# invoked, so typing `scripts/surface_mirror_check.sh` from a subdirectory still
# checks the mirror rather than failing on a relative path.
#
# The ARGUMENT exists for CI, and for the same hardening reason
# .github/workflows/plugin-bump-check.yml checks its guard out of trusted `main`:
# the script that judges a pull request must not be the copy that pull request
# can rewrite. So CI runs THIS file from a trusted checkout and passes the PR's
# checkout as the root to judge. Locally the two are the same directory and the
# argument is never typed.
repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

nen_bin() {
  # NEN_BIN lets CI point at a bootstrapped binary that is not on PATH; without
  # it, whatever `nen` the developer has. Never a vendored copy, never a guess.
  printf '%s' "${NEN_BIN:-nen}"
}

# --- has_surface_verb -------------------------------------------------------
# Probe rather than parse a version: a version string says which release this
# is, and what we need to know is whether THIS binary carries the verb. The
# probe is the verb's own --help, which prints its family banner on a nen that
# has it and the generic top-level help on one that does not (verified both
# ways, docs/surfaces/evidence/surfaces.md § 2.3).
has_surface_verb() {
  local nen out; nen="$(nen_bin)"
  # Captured into a variable and cased on, not piped into grep: under
  # `set -o pipefail` a nen binary that closes its output early on --help
  # (writes its banner, then exits before grep finishes reading) delivers
  # SIGPIPE to nen's own process, and pipefail turns that into a non-zero
  # pipeline status indistinguishable from "no surface verb".
  out="$("$nen" surface mirror generate --help 2>&1 || true)"
  case $'\n'"$out" in
    *$'\n''nen surface'*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- plugin_stamp MANIFEST_FILE -------------------------------------------
# Reads plugin.json's `version` field with the same structural awk this
# repository already uses elsewhere (no python3 dependency in a bash-3.2 /
# POSIX-sh lane). Empty on a missing or unparsable manifest rather than a hard
# failure: a missing stamp is reported by the invocation it feeds, not guessed
# at here.
plugin_stamp() {
  local manifest="$1"
  [ -f "$manifest" ] || { printf ''; return; }
  awk -F'"' '/"version"[[:space:]]*:/ { for (i = 1; i <= NF; i++) { if ($i == "version") { print $(i + 2); exit } } }' "$manifest"
}

main() {
  local root nen drift=0 stamp
  local args=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --installed)
        [ "$#" -ge 2 ] || { echo "surface-mirror-check: --installed requires a path argument." >&2; exit 2; }
        installed_path="$2"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done
  root="${args[0]:-$(repo_root)}"
  nen="$(nen_bin)"
  [ -d "$root" ] || { echo "surface-mirror-check: '$root' is not a directory." >&2; exit 2; }
  cd "$root"
  [ -d "$SOURCE_DIR" ] || { echo "surface-mirror-check: '$root' carries no $SOURCE_DIR — wrong root." >&2; exit 2; }

  if ! command -v "$nen" >/dev/null 2>&1 && [ ! -x "$nen" ]; then
    echo "surface-mirror-check: no 'nen' on PATH (and NEN_BIN names nothing executable)." >&2
    echo "  Install it the way nen/contract.json's warm-up does, then re-run." >&2
    exit 3
  fi

  if ! has_surface_verb; then
    cat >&2 <<EOF
surface-mirror-check: this 'nen' has no 'surface' verb, so the mirrors under
surfaces/ were NOT checked. This is reported rather than passed: a check that
could not run is not a check that succeeded.

  nen on PATH : $("$nen" --version 2>/dev/null || echo "unreadable")
  the verb     : nen surface mirror generate|check  (present from v0.5.0)
  the pin      : nen/contract.json -> dependency.pinned_ref

Regenerate and check with a nen that carries the verb; the pinned build is
expected to gain it when dependency.pinned_ref moves. docs/SURFACES.md § 3-4.
EOF
    exit 2
  fi

  stamp="$(plugin_stamp "$MANIFEST_FILE")"
  echo "surface-mirror-check: nen $("$nen" --version 2>/dev/null || echo "?") · source $SOURCE_DIR · agents $AGENTS_DIR · stamp ${stamp:-<none>}"

  if [ -n "$installed_path" ]; then
    echo "--- claude-code (installed: $installed_path)"
    local code=0
    # claude-code's row is the source's OWN plugin layout, copied verbatim —
    # never rewritten through a tier-to-alias map or an invocation-prefix
    # rewrite the way codex/cursor/antigravity are. --models and
    # --source-surface are refused here (nen: "'--models' declares no
    # 'models.claude-code'" — there is no claude-code row in nen/workflow.json
    # to read tiers from), so neither is passed on this row.
    "$nen" surface mirror check \
      --source "$SOURCE_DIR" \
      --agents "$AGENTS_DIR" \
      --surface claude-code \
      --installed "$installed_path" \
      --permissions "$PERMISSIONS_FILE" \
      --hooks "$HOOKS_FILE" \
      --rules "$RULES_FILE" \
      --stamp "$stamp" \
      --invocation-prefix "$INVOCATION_PREFIX" || code=$?
    case "$code" in
      0) echo "surface-mirror-check: installed plugin cache matches a fresh generation." ; return 0 ;;
      1)
        echo "surface-mirror-check: the installed plugin cache at '$installed_path' has drifted from a fresh generation. Refresh it the way hatsu-warmup does (docs/SURFACES.md § 4)." >&2
        return 1
        ;;
      *)
        echo "surface-mirror-check: 'nen surface mirror check --installed $installed_path' refused at exit $code — an invocation or declaration defect, not drift." >&2
        exit "$code"
        ;;
    esac
  fi

  local surface code
  for surface in "${SURFACES[@]}"; do
    echo "--- $surface (surfaces/$surface)"
    # `check` writes NOTHING — it regenerates in memory and diffs. Exit 1 is
    # drift and exit 2 is a refusal (a missing --out, a source with no
    # SKILL.md); both are failures here, and the second is not a drift report,
    # so it is not folded into one.
    #
    # `code=0; cmd || code=$?` rather than `if cmd; then … fi; code=$?`: after a
    # false `if` with no `else`, `$?` is the COMPOUND command's status, which is
    # 0 — so the obvious spelling reads every drift as a pass. Under `set -e`
    # the `||` is also what keeps the non-zero from killing the loop.
    code=0
    "$nen" surface mirror check \
      --source "$SOURCE_DIR" \
      --agents "$AGENTS_DIR" \
      --surface "$surface" \
      --out "surfaces/$surface" \
      --models "$MODELS_FILE" \
      --permissions "$PERMISSIONS_FILE" \
      --hooks "$HOOKS_FILE" \
      --rules "$RULES_FILE" \
      --source-surface "$SOURCE_SURFACE" \
      --hooks-root "$(hooks_root_for "$surface")" \
      --manifest "$MANIFEST_FILE" \
      --stamp "$stamp" \
      --invocation-prefix "$INVOCATION_PREFIX" || code=$?

    case "$code" in
      0) ;;
      1) drift=1 ;;
      *)
        echo "surface-mirror-check: 'nen surface mirror check --surface $surface' refused at exit $code — an invocation or declaration defect, not drift." >&2
        exit "$code"
        ;;
    esac
  done

  if [ "$drift" -ne 0 ]; then
    cat >&2 <<EOF

surface-mirror-check: the committed mirror is not what the source generates.

  missing      the source has a skill the mirror does not
  extra        the mirror carries a generated file no source produces
  stale        generated, but for the OTHER surface
  hand-edited  somebody edited the mirror instead of the source

Fix it by regenerating — never by editing surfaces/ (docs/SURFACES.md § 2):

  nen surface mirror generate --source $SOURCE_DIR --agents $AGENTS_DIR \\
    --surface codex      --out surfaces/codex      --models $MODELS_FILE --permissions $PERMISSIONS_FILE --hooks $HOOKS_FILE --rules $RULES_FILE --source-surface $SOURCE_SURFACE --hooks-root '$(hooks_root_for codex)' --manifest $MANIFEST_FILE --stamp "$stamp" --invocation-prefix "$INVOCATION_PREFIX"
  nen surface mirror generate --source $SOURCE_DIR --agents $AGENTS_DIR \\
    --surface cursor      --out surfaces/cursor      --models $MODELS_FILE --permissions $PERMISSIONS_FILE --hooks $HOOKS_FILE --rules $RULES_FILE --source-surface $SOURCE_SURFACE --hooks-root '$(hooks_root_for cursor)' --manifest $MANIFEST_FILE --stamp "$stamp" --invocation-prefix "$INVOCATION_PREFIX"
  nen surface mirror generate --source $SOURCE_DIR --agents $AGENTS_DIR \\
    --surface antigravity --out surfaces/antigravity --models $MODELS_FILE --permissions $PERMISSIONS_FILE --hooks $HOOKS_FILE --rules $RULES_FILE --source-surface $SOURCE_SURFACE --hooks-root '$(hooks_root_for antigravity)' --manifest $MANIFEST_FILE --stamp "$stamp" --invocation-prefix "$INVOCATION_PREFIX"

then commit the regenerated files in the same commit as the source change.
EOF
    exit 1
  fi

  echo "surface-mirror-check: all mirrors match a fresh generation."
}

main "$@"
