#!/usr/bin/env bash
# surface_mirror_check.sh — the generated-surface drift guard for Hatsu.
#
# THE MECHANISM THIS PROTECTS
# `claude/skills/**` and `claude/agents/**` are the ONE authored copy of every
# skill and persona. `surfaces/codex/**` and `surfaces/cursor/**` are generated
# from them by `nen surface mirror generate` and committed, because a Codex or
# Cursor session has no plugin loader: the warm-up places those files into the
# repository the session is standing in (claude/skills/hatsu-warmup/SKILL.md
# § 5). Edit a SKILL.md without regenerating and the two other surfaces keep
# serving the previous wording — silently, with no error anywhere, exactly the
# way an un-bumped plugin.json keeps serving the previous plugin.
#
# WHAT IT DOES
# Runs `nen surface mirror check` for both surfaces with whichever `nen` is on
# PATH. That verb REGENERATES IN MEMORY and diffs; it writes nothing at all, so
# this script is safe to run anywhere, including on a dirty tree.
#
# EXIT CODES — and the one that matters most is 2.
#   0  both mirrors are byte-identical to a fresh generation
#   1  drift, in nen's own four classes: missing / extra / stale / hand-edited
#   2  the `nen` on PATH HAS NO `surface` VERB — said in those words; also the
#      wiring errors (a root that is not a Hatsu checkout, a refusal from the
#      verb itself), which are invocation defects rather than drift
#   3  no `nen` on PATH at all
#
# USAGE
#   scripts/surface_mirror_check.sh [repo-root]
#   NEN_BIN=/path/to/nen scripts/surface_mirror_check.sh
#
# 2 is not "nothing to check". A guard that reported success when it could not
# run is an unperformed check rendered as a passing one — the failure
# nen/contract.json § no_improvised_fallback names, and the same failure the
# plugin-bump guard was filed after. The build pinned in nen/contract.json
# CARRIES the verb — it predated it through v0.4.0 (`nen surface` →
# "nen: unknown command 'surface'", exit 2; transcript in docs/ab/surfaces.md
# § 2.3). So 2 is now UNEXPECTED: at this pin it means the nen on PATH is not the
# pinned one, and .github/workflows/surface-mirror-check.yml turns it into an
# ERROR rather than the skip-with-notice it used to be. Verified against the
# pinned build: this script exits 0 with `codex ok: 40` and `cursor ok: 47`.
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
SURFACES=(codex cursor)

# --- usage: surface_mirror_check.sh [repo-root] -----------------------------
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
# ways, docs/ab/surfaces.md § 2.3).
has_surface_verb() {
  local nen; nen="$(nen_bin)"
  "$nen" surface mirror generate --help 2>&1 | grep -q '^nen surface'
}

main() {
  local root nen drift=0
  root="${1:-$(repo_root)}"
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

  echo "surface-mirror-check: nen $("$nen" --version 2>/dev/null || echo "?") · source $SOURCE_DIR · agents $AGENTS_DIR"

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
    --surface codex  --out surfaces/codex  --invocation-prefix "$INVOCATION_PREFIX"
  nen surface mirror generate --source $SOURCE_DIR --agents $AGENTS_DIR \\
    --surface cursor --out surfaces/cursor --invocation-prefix "$INVOCATION_PREFIX"

then commit the regenerated files in the same commit as the source change.
EOF
    exit 1
  fi

  echo "surface-mirror-check: both mirrors match a fresh generation."
}

main "$@"
