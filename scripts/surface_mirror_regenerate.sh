#!/usr/bin/env bash
# surface_mirror_regenerate.sh — regenerate the three committed mirrors under surfaces/ in one
# plain command (zheref/hatsu#218).
#
# WHAT IT IS
# The three `nen surface mirror generate` calls scripts/surface_mirror_check.sh prints on drift,
# one per surface (codex, cursor, antigravity), at the plugin manifest's version stamp: the job
# great-hiker § 4 does after every source change and a bump does to every generated marker. Before
# this script every run typed them by hand or as a loop, and a loop is a shape Claude Code's
# worktree-isolation guard refuses; one call to this script is not.
#
# IT WRITES surfaces/<s>/ through nen and nothing else. It never edits a mirror by hand, never
# commits, and never judges the result: `bash scripts/surface_mirror_check.sh` is the next step,
# and its verdict is the one that counts (great-hiker § 4, step 1).
#
# PARITY. The flags are the check's, in the check's order, with the same hooks-root expression per
# surface; scripts/surface_mirror_regenerate_fixture.sh proves each generate call carries exactly
# the inputs the check hands `nen surface mirror check` for that surface, so the two cannot drift
# apart without that lane going red.
#
# USAGE
#   scripts/surface_mirror_regenerate.sh [--dry-run] [repo-root]
#   NEN_BIN=/path/to/nen scripts/surface_mirror_regenerate.sh
#
#   --dry-run   print the three argv lines and run nothing (no nen needed)
#   repo-root   the Hatsu checkout to regenerate; default the one this script ships in
#
# EXIT CODES — the check's, so a caller reads both the same way:
#   0  all three surfaces regenerated (or, with --dry-run, printed)
#   2  wiring: a root that is not a Hatsu checkout, a manifest with no readable version (never an
#      unstamped generation), a nen with no `surface` verb, or an unknown argument
#   3  no `nen` on PATH (and NEN_BIN names nothing executable)
#   any other non-zero is nen's own refusal for the surface named, and the surfaces after it are
#   NOT generated (the ones before it are, and the drift check will say so)
set -euo pipefail

SOURCE_DIR="claude/skills"
AGENTS_DIR="claude/agents"
INVOCATION_PREFIX="hatsu:"
SURFACES=(codex cursor antigravity)
MODELS_FILE="nen/workflow.json"
PERMISSIONS_FILE="contracts/permissions.json"
HOOKS_FILE="hooks/hooks.json"
RULES_FILE="claude/rules/hatsu.md"
SOURCE_SURFACE="claude"
MANIFEST_FILE=".claude-plugin/plugin.json"

# The same expressions scripts/surface_mirror_check.sh's hooks_root_for prints, verbatim (its
# comment is the rationale); the fixture compares them call by call.
hooks_root_for() {
  case "$1" in
    antigravity) printf %s '${HATSU_PLUGIN_ROOT:-${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu}' ;;
    codex) printf %s '${PLUGIN_ROOT:-${HATSU_PLUGIN_ROOT:-./.codex}}' ;;
    cursor) printf %s '${HATSU_PLUGIN_ROOT:-./.cursor}' ;;
  esac
}

die() { printf 'surface-mirror-regenerate: %s\n' "$1" >&2; exit "${2:-2}"; }

plugin_stamp() {
  [ -f "$1" ] || { printf ''; return; }
  awk -F'"' '/"version"[[:space:]]*:/ { for (i = 1; i <= NF; i++) { if ($i == "version") { print $(i + 2); exit } } }' "$1"
}

main() {
  local dry=0 root="" nen stamp surface code done_list=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      -*) die "unknown option '$1' (usage: surface_mirror_regenerate.sh [--dry-run] [repo-root])." ;;
      *)
        [ -z "$root" ] || die "one repo-root at most (usage: surface_mirror_regenerate.sh [--dry-run] [repo-root])."
        root="$1"; shift
        ;;
    esac
  done
  [ -n "$root" ] || root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  [ -d "$root" ] || die "'$root' is not a directory."
  cd "$root"
  [ -d "$SOURCE_DIR" ] || die "'$root' carries no $SOURCE_DIR — wrong root."
  stamp="$(plugin_stamp "$MANIFEST_FILE")"
  [ -n "$stamp" ] || die "$MANIFEST_FILE carries no readable version; a mirror is never generated unstamped."

  nen="${NEN_BIN:-nen}"
  if [ "$dry" -eq 0 ]; then
    if ! command -v "$nen" >/dev/null 2>&1 && [ ! -x "$nen" ]; then
      die "no 'nen' on PATH (and NEN_BIN names nothing executable); ten § 2 installs the pin." 3
    fi
    local help
    help="$("$nen" surface mirror generate --help 2>&1 || true)"
    case $'\n'"$help" in
      *$'\n''nen surface'*) : ;;
      *) die "this 'nen' has no 'surface' verb; the mirrors were NOT regenerated (ten § 2 installs the pin)." ;;
    esac
  fi

  local note=""
  [ "$dry" -eq 0 ] || note=" · dry run, nothing written"
  echo "surface-mirror-regenerate: root $PWD · stamp $stamp$note"
  for surface in "${SURFACES[@]}"; do
    local argv=(surface mirror generate
      --source "$SOURCE_DIR"
      --agents "$AGENTS_DIR"
      --surface "$surface"
      --out "surfaces/$surface"
      --models "$MODELS_FILE"
      --permissions "$PERMISSIONS_FILE"
      --hooks "$HOOKS_FILE"
      --rules "$RULES_FILE"
      --source-surface "$SOURCE_SURFACE"
      --hooks-root "$(hooks_root_for "$surface")"
      --manifest "$MANIFEST_FILE"
      --stamp "$stamp"
      --invocation-prefix "$INVOCATION_PREFIX")
    if [ "$dry" -eq 1 ]; then
      printf 'would run: nen'; printf " %q" "${argv[@]}"; printf '\n'
      continue
    fi
    echo "--- $surface (surfaces/$surface)"
    code=0
    "$nen" "${argv[@]}" || code=$?
    if [ "$code" -ne 0 ]; then
      echo "surface-mirror-regenerate: 'nen surface mirror generate --surface $surface' refused at exit $code; regenerated before it: ${done_list:-none}; the surfaces after it were NOT generated." >&2
      exit "$code"
    fi
    done_list="${done_list:+$done_list, }$surface"
  done
  [ "$dry" -eq 1 ] && return 0
  echo "surface-mirror-regenerate: regenerated $done_list at stamp $stamp. Next: bash scripts/surface_mirror_check.sh (great-hiker § 4, step 1), then commit surfaces/ with the change that caused it."
}

main "$@"
