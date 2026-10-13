#!/usr/bin/env bash
# surface_mirror_regenerate.sh — regenerate the three committed mirrors under surfaces/ in one
# plain command (zheref/hatsu#218).
#
# WHAT IT IS
# The three `nen surface mirror generate` calls scripts/surface_mirror_check.sh prints on drift,
# one per surface (codex, cursor, antigravity), at the plugin manifest's version stamp: the job
# great-hiker § 4 and docs/using/mirrors.md § 3 do after every source change and every bump. Typed
# by hand it was a loop, a shape Claude Code's worktree-isolation guard refuses; one call to this
# script is not.
#
# ONE TABLE. This script SOURCES scripts/surface_mirror_check.sh, whose `main` runs only when it is
# executed, and reads its constants (the source, agents, models, permissions, hooks, rules and
# manifest paths, the surface list), its hooks_root_for table, its plugin_stamp and its nen probes.
# There is no second copy to drift; scripts/surface_mirror_regenerate_fixture.sh still proves each
# generate call carries exactly the inputs the check hands `nen surface mirror check`.
#
# IT WRITES surfaces/<s>/ through nen and nothing else. It never edits a mirror by hand, never
# commits, and never judges the result: `bash scripts/surface_mirror_check.sh` is the next step,
# and its verdict is the one that counts (great-hiker § 4, step 1).
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
#   2  wiring: a root that is not a Hatsu checkout, a manifest that is unreadable or carries no
#      version (never an unstamped generation), a nen with no `surface` verb, an unknown argument
#   3  no `nen` on PATH (and NEN_BIN names nothing executable)
#   any other non-zero is nen's own refusal for the surface named, and the surfaces after it are
#   NOT generated (the ones before it are, and the drift check will say so)
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=surface_mirror_check.sh
. "$SELF_DIR/surface_mirror_check.sh"

die() { printf 'surface-mirror-regenerate: %s\n' "$1" >&2; exit "${2:-2}"; }
usage='usage: surface_mirror_regenerate.sh [--dry-run] [repo-root]'

regenerate() {
  local dry=0 root="" nen stamp surface code done_list="" note=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      -*) die "unknown option '$1' ($usage)." ;;
      *)
        [ -z "$root" ] || die "one repo-root at most ($usage)."
        root="$1"; shift
        ;;
    esac
  done
  [ -n "$root" ] || root="$(cd "$SELF_DIR/.." && pwd)"
  [ -d "$root" ] || die "'$root' is not a directory."
  cd "$root"
  [ -d "$SOURCE_DIR" ] || die "'$root' carries no $SOURCE_DIR — wrong root."
  [ -f "$MANIFEST_FILE" ] && [ -r "$MANIFEST_FILE" ] || die "$MANIFEST_FILE is missing or unreadable; a mirror is never generated unstamped."
  stamp="$(plugin_stamp "$MANIFEST_FILE")"
  [ -n "$stamp" ] || die "$MANIFEST_FILE carries no readable version; a mirror is never generated unstamped."

  nen="$(nen_bin)"
  if [ "$dry" -eq 0 ]; then
    nen_present "$nen" || die "no 'nen' on PATH (and NEN_BIN names nothing executable); ten § 2 installs the pin." 3
    has_surface_verb || die "this 'nen' has no 'surface' verb; the mirrors were NOT regenerated (ten § 2 installs the pin)."
  fi

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

regenerate "$@"
