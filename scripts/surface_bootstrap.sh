#!/usr/bin/env bash
# Install Hatsu's first discoverable skill, or refresh a whole generated surface.
#
# This script exists for the one moment a Hatsu skill cannot run: before Codex or
# Cursor has discovered ten. It deliberately shares the warm-up's
# safety contract: only generated Hatsu destinations may be replaced, tracked
# files always win, and local installation state belongs in info/exclude.

set -euo pipefail
LC_ALL=C

usage() {
  cat <<'EOF'
usage: scripts/surface_bootstrap.sh --surface codex|cursor|antigravity --target <repository> --bootstrap|--install-all [--plugin]

--bootstrap   Install only ten, making the first skill invocation discoverable.
--install-all Refresh the complete generated surface. ten uses this after discovery.
--plugin      Codex only, and only together with --install-all: Codex installs
              Hatsu as a first-party plugin (codex plugin add hatsu@hatsu),
              which already serves the canonical skills and the Codex hooks.
              Places personas (AGENTS.override.md, .codex/agents/*) exactly as
              --install-all does, but places NO skills under .agents/skills and
              NO .codex/hooks.json or hook scripts -- and removes any such
              destination this bootstrap previously placed there.
EOF
}

surface=""
target_input=""
mode=""
plugin_mode=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --surface)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      surface="$2"
      shift 2
      ;;
    --target)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      target_input="$2"
      shift 2
      ;;
    --bootstrap|--install-all)
      [ -z "$mode" ] || { echo "choose exactly one of --bootstrap or --install-all" >&2; exit 2; }
      mode="$1"
      shift
      ;;
    --plugin)
      plugin_mode=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$surface" in codex|cursor|antigravity) ;; *) echo "--surface must be codex, cursor, or antigravity" >&2; exit 2 ;; esac
[ -n "$target_input" ] || { echo "--target is required" >&2; exit 2; }
[ -n "$mode" ] || { echo "choose --bootstrap or --install-all" >&2; exit 2; }
if [ -n "$plugin_mode" ] && { [ "$surface" != "codex" ] || [ "$mode" != "--install-all" ]; }; then
  echo "--plugin is valid only with --surface codex --install-all" >&2
  exit 2
fi

# Canonicalise without letting command substitution erase a trailing newline.
# The final dot keeps pwd's record separator visible until it is checked.
canonical_directory() {
  local candidate="${1:-}" rendered resolved
  [ -n "$candidate" ] || return 1
  rendered="$(CDPATH='' cd -- "$candidate" >/dev/null 2>&1 && { pwd -P; printf .; })" || return 1
  case "$rendered" in *$'\n.') ;; *) return 1 ;; esac
  resolved="${rendered%$'\n.'}"
  [ "$(printf '%s' "$resolved" | wc -l)" -eq 0 ] || return 1
  [ "$resolved/." -ef "$candidate/." ] || return 1
  printf '%s' "$resolved"
}

case "$0" in
  */*) script_base="${0%/*}" ;;
  *) script_base='.' ;;
esac
script_dir="$(canonical_directory "$script_base")" || {
  echo "Hatsu bootstrap cannot canonicalize its script directory" >&2
  exit 2
}
hatsu_root="$(canonical_directory "$script_dir/..")" || {
  echo "Hatsu bootstrap cannot canonicalize its checkout" >&2
  exit 2
}

# Same structural manifest reader as ten: accept only the canonical
# pretty-printed plugin manifest shape, with exactly one top-level name.
manifest_name() {
  awk '
    function scalar(v) { return v ~ /^("([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*"|-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?|true|false|null)$/ }
    function value_ok(v) { return v == "{" || v == "[" || v == "{}" || v == "[]" || scalar(v) }
    NR == 1 { if ($0 != "{") bad = 1; sp = 1; top[1] = "{"; ind[1] = 0; first = 1; comma = 0; next }
    {
      if (bad || done) { bad = 1; next }
      ni = match($0, /[^ ]/) - 1; if (ni < 0) { bad = 1; next }
      body = substr($0, ni + 1)
      if (body ~ /^[}\]],?$/) {
        c = substr(body, 1, 1); tr = (body ~ /,$/)
        if (sp == 0 || ni != ind[sp] || (top[sp] == "{" && c != "}") || (top[sp] == "[" && c != "]") || comma) { bad = 1; next }
        sp--; if (sp == 0) { if (tr) bad = 1; done = 1; next }
        comma = tr; first = 0; next
      }
      if (sp == 0 || ni != ind[sp] + 2 || (!first && !comma)) { bad = 1; next }
      tr = (body ~ /,$/); if (tr) body = substr(body, 1, length(body) - 1)
      if (top[sp] == "{") {
        if (body !~ /^"([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*": /) { bad = 1; next }
        v = body; sub(/^"([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*": /, "", v)
        if (sp == 1 && body ~ /^"name": "/) { s = v; sub(/^"/, "", s); sub(/"$/, "", s); n++; name = s }
      } else v = body
      if (!value_ok(v)) { bad = 1; next }
      if (v == "{" || v == "[") { if (tr) { bad = 1; next }; sp++; top[sp] = v; ind[sp] = ni; first = 1; comma = 0; next }
      comma = tr; first = 0
    }
    END { if (!bad && done && sp == 0 && n == 1) print name }
  ' "$1"
}

is_hatsu() {
  [ -n "${1:-}" ] && [ -f "$1/.claude-plugin/plugin.json" ] && [ -d "$1/claude/skills" ] || return 1
  [ "$(manifest_name "$1/.claude-plugin/plugin.json")" = "hatsu" ]
}

if ! is_hatsu "$hatsu_root"; then
  echo "Hatsu bootstrap must run from the canonical Hatsu checkout" >&2
  exit 2
fi
[ -d "$hatsu_root/surfaces/$surface" ] || {
  echo "Hatsu checkout has no generated $surface surface" >&2
  exit 2
}

# --- skills_source_dir ------------------------------------------------------
# Where THIS surface's mirrored skill directories actually live. codex and
# cursor still mirror them flat, directly under surfaces/<surface>/<name>/;
# nen is moving antigravity's to surfaces/antigravity/skills/<name>/ (the same
# shape codex/cursor's own agents/hooks/rules subdirectories already use).
# Probed rather than hardcoded to either layout, so this script keeps working
# across the transition without a synchronized flag day.
skills_source_dir() {
  if [ -d "$hatsu_root/surfaces/$surface/skills" ]; then
    printf '%s' "$hatsu_root/surfaces/$surface/skills"
  else
    printf '%s' "$hatsu_root/surfaces/$surface"
  fi
}
skills_src="$(skills_source_dir)"

target_rendered="$(git -C "$target_input" rev-parse --show-toplevel 2>/dev/null && printf .)" || {
  echo "--target must name a Git working tree" >&2
  exit 2
}
case "$target_rendered" in *$'\n.') ;; *) echo "--target must name a Git working tree" >&2; exit 2 ;; esac
target_candidate="${target_rendered%$'\n.'}"
target="$(canonical_directory "$target_candidate")" || {
  echo "--target must resolve to a newline-free Git working tree" >&2
  exit 2
}

# A tracked path is never ours, even if it happens to contain Hatsu's marker.
# Moved ahead of the ADOPTION GATE (rather than defined where it is first used
# for a destination) so --plugin's adoption-gate carve-out below can call
# is_ours_override directly instead of duplicating its marker check.
is_tracked() {
  local relative="$1"
  git -C "$target" ls-files --error-unmatch -- "$relative" >/dev/null 2>&1
}

# True only for an untracked destination this bootstrap previously made.
is_ours() {
  local relative="$1" destination="$target/$1" link_target
  is_tracked "$relative" && return 1
  if [ -L "$destination" ]; then
    link_target="$(readlink "$destination")"
    case "$link_target" in
      "$hatsu_root"/surfaces/*) return 0 ;;
    esac
  fi
  [ -f "$destination/SKILL.md" ] && grep -qsE 'GENERATED (by nen surface mirror|for surface: antigravity)' "$destination/SKILL.md" && return 0
  [ -f "$destination" ] && grep -qsE 'GENERATED (by nen surface mirror|for surface: antigravity)' "$destination"
}

is_ours_override() {
  local relative destination
  relative="AGENTS.override.md"
  destination="$target/$relative"
  is_tracked "$relative" && return 1
  [ -f "$destination" ] || return 1
  grep -q '^<!-- BEGIN hatsu personas (generated — nen surface mirror, surface: codex) -->$' "$destination" 2>/dev/null &&
    grep -q '^<!-- END hatsu personas (generated — nen surface mirror, surface: codex) -->$' "$destination" 2>/dev/null
}

is_ours_hooks() {
  local relative=".agents/hooks.json" destination="$target/.agents/hooks.json"
  is_tracked "$relative" && return 1
  [ -f "$destination" ] || return 1
  cmp -s "$destination" "$hatsu_root/surfaces/antigravity/hooks.json" && return 0
  # NOT byte-identical to the tracked mirror is not evidence of a collision:
  # the workspace-mode placement above rewrites this file's
  # HATSU_PLUGIN_ROOT fallback to `./.agents` (so the placed hooks resolve
  # their own scripts rather than a global plugin install that may not
  # exist), which is a deliberate, Hatsu-owned edit of the placed copy, not
  # a foreign one. The generated header line survives that rewrite
  # untouched, so it still identifies a Hatsu-placed antigravity copy.
  grep -qsF 'GENERATED by nen surface mirror (surface: antigravity,' "$destination" && return 0
  grep -qs 'GENERATED for surface: antigravity' "$destination"
}

is_ours_hook_script() {
  local relative="$1" destination="$target/$1" name
  name="$(basename "$relative")"
  is_tracked "$relative" && return 1
  [ -f "$destination" ] || return 1
  cmp -s "$destination" "$hatsu_root/surfaces/$surface/hooks/$name" && return 0
  grep -qsE "GENERATED (by nen surface mirror \\(surface: $surface|for surface: antigravity)" "$destination"
}

# ADOPTION GATE (zheref/hatsu#94), --install-all ONLY. --bootstrap is the
# documented, human-run FIRST step (README.md, docs/SURFACES.md) that seeds
# only ten into a target BEFORE it carries a Nen taxonomy file at
# all, so it is deliberately exempt. --install-all is what places a COMPLETE
# generated surface -- the mode the SessionStart hook calls automatically --
# and it is refused unless the target has already adopted Hatsu: a Nen
# taxonomy file (nen/contract.json or nen/workflow.json) AND a Hatsu-placed
# marker already sitting under this surface's own directory. The same shape
# as scripts/permissions_pack.sh's own adoption guard.
if [ "$mode" = "--install-all" ]; then
  if [ ! -f "$target/nen/contract.json" ] && [ ! -f "$target/nen/workflow.json" ]; then
    echo "Hatsu bootstrap ($surface): $target carries neither nen/contract.json nor nen/workflow.json -- not a Hatsu consumer; nothing placed." >&2
    exit 0
  fi
  # Codex's OWN skills live at `.agents/skills/<name>` too (the shared skills
  # path documented above at "SKILLS LIVE AT .agents/skills/<name> ONLY"),
  # never under `.codex/` -- `.codex/` only ever holds hooks.json, personas
  # and AGENTS.override.md. So a prior --bootstrap (which places only
  # ten's SKILL.md, always under .agents/skills/) is detected there
  # for BOTH codex and antigravity, which share that path; only cursor's own
  # skills live under `.cursor/` itself.
  case "$surface" in
    codex) surface_marker_dir="$target/.agents" ;;
    cursor) surface_marker_dir="$target/.cursor" ;;
    antigravity) surface_marker_dir="$target/.agents" ;;
  esac
  # `find -L | grep`, never a bare `grep -r`: cursor's OWN placements are
  # symlinks (a skill directory symlinked in from surfaces/cursor/<name>/),
  # and grep -r never follows a symlink into the tree it points at -- a
  # cursor target that had only ever seen --bootstrap (which places nothing
  # but a symlinked ten) would read as never-adopted forever.
  #
  # THE MARKER MUST NAME *THIS* SURFACE. Codex and Antigravity both place
  # under `.agents/`, so a marker stamped `(surface: codex, …)` sitting there
  # is evidence Codex was adopted, never that Antigravity was -- a bare
  # substring match on "GENERATED by nen surface mirror" let either one's
  # marker authorize the other's unattended full-surface install.
  has_marker_under() {
    local directory="$1" want_surface="$2" file link_target
    [ -d "$directory" ] || return 1
    while IFS= read -r -d '' file; do
      grep -qsF "GENERATED by nen surface mirror (surface: ${want_surface}," "$file" && return 0
    done < <(find -L "$directory" -type f -print0 2>/dev/null)
    # A DANGLING symlink whose target sits under THIS checkout's generated
    # surface for this very surface is the old bootstrap's own placement,
    # orphaned by a rename of the skill it pointed at (hatsu-warmup -> ten,
    # v0.49.0): `find -L -type f` cannot see through it, but the link's text
    # names our surfaces/<surface>/ tree, which nothing else writes. It is
    # evidence of adoption, and --install-all is exactly what migrates it.
    while IFS= read -r -d '' file; do
      [ -e "$file" ] && continue
      link_target="$(readlink "$file")"
      case "$link_target" in
        "$hatsu_root"/surfaces/"$want_surface"/*) return 0 ;;
      esac
    done < <(find "$directory" -type l -print0 2>/dev/null)
    return 1
  }
  adopted=0
  has_marker_under "$surface_marker_dir" "$surface" && adopted=1
  # --plugin CARVE-OUT. A prior --plugin run legitimately REMOVES every skill
  # under .agents/skills once the Codex plugin is serving them -- including
  # whichever skill's SKILL.md carried the marker has_marker_under looks for
  # -- so that marker can be gone even though this target is adopted. Our own
  # AGENTS.override.md (its BEGIN/END hatsu personas markers, is_ours_override)
  # is left behind by every codex --install-all, plugin mode included, and is
  # accepted as the same evidence in --plugin mode only.
  if [ "$adopted" -eq 0 ] && [ -n "$plugin_mode" ] && is_ours_override; then
    adopted=1
  fi
  if [ "$adopted" -eq 0 ]; then
    echo "Hatsu bootstrap ($surface): $target carries no existing $surface mirror marker under ${surface_marker_dir#"$target/"} -- refusing an unattended full-surface install; run --bootstrap or hatsu:tenkai first." >&2
    exit 0
  fi
fi

declare -a skill_names=()
if [ "$mode" = "--bootstrap" ]; then
  skill_names=("ten")
elif [ -n "$plugin_mode" ]; then
  : # codex plugin mode: Codex's own plugin install already serves hatsu:ten
    # and every other skill (codex plugin add hatsu@hatsu); place none here.
else
  # The canonical Claude source names the complete expected surface. Do not
  # infer it from a possibly partial generated mirror before removing stales.
  for source in "$hatsu_root/claude/skills"/*; do
    [ -d "$source" ] && [ -f "$source/SKILL.md" ] || continue
    skill_names+=("$(basename "$source")")
  done
  [ "${#skill_names[@]}" -gt 0 ] || {
    echo "Hatsu checkout has no canonical skill sources" >&2
    exit 2
  }
fi

# Guarded on count first: bash 3.2 (macOS's own /bin/bash) raises "unbound
# variable" expanding "${skill_names[@]}" under `set -u` when the array is
# truly empty (fixed in bash 4.4+) -- and --plugin mode leaves it exactly that
# empty on purpose (codex plugin mode: place none). Every other
# "${skill_names[@]}" expansion below that --plugin mode can reach is guarded
# the same way, for the same reason.
if [ "${#skill_names[@]}" -gt 0 ]; then
  for name in "${skill_names[@]}"; do
    [ -f "$skills_src/$name/SKILL.md" ] || {
      echo "generated $surface mirror is missing $name/SKILL.md" >&2
      exit 2
    }
  done
fi

declare -a persona_sources=()
# The hook SCRIPTS `nen surface mirror generate` has produced for THIS
# surface -- discovered rather than a fixed pair, because this deliverable
# landed one surface at a time: `hooks/*.sh` under surfaces/antigravity/
# gained guard-base-branch.sh and stop-bell.sh first and session-start.sh
# after, and codex/cursor gained the same three only once this hardening
# pass placed them, so a hardcoded set would have missed whichever arrived
# last. Basenames only; every reader below re-joins them under
# surfaces/<surface>/hooks/ or .<surface>/hooks/ (.agents/hooks/ for
# antigravity) as needed.
declare -a hook_scripts=()
if [ "$mode" = "--install-all" ]; then
  if [ "$surface" = "codex" ]; then
    [ -f "$hatsu_root/surfaces/codex/AGENTS.md" ] || {
      echo "generated codex mirror is missing AGENTS.md" >&2
      exit 2
    }
    if [ -L "$target/AGENTS.md" ]; then
      echo "refusing: target AGENTS.md is a symlink" >&2
      exit 1
    fi
    if [ -e "$target/AGENTS.md" ] && [ ! -f "$target/AGENTS.md" ]; then
      echo "refusing: target AGENTS.md is not a regular file" >&2
      exit 1
    fi
    if [ -z "$plugin_mode" ]; then
      [ -f "$hatsu_root/surfaces/codex/hooks.json" ] || {
        echo "generated codex mirror is missing hooks.json" >&2
        exit 2
      }
    fi
    [ -d "$hatsu_root/claude/agents" ] || {
      echo "Hatsu checkout has no canonical persona sources" >&2
      exit 2
    }
    for source in "$hatsu_root/claude/agents"/*.md; do
      [ -f "$source" ] || continue
      # A leading underscore names a shared PROSE FRAGMENT composed into
      # other agent files at doc-authoring time (_review-preamble.md), never
      # a standalone persona -- nen mirrors no surface agent for it, so a
      # persona_sources entry expecting one would fail every install.
      case "$(basename "$source")" in _*) continue ;; esac
      # nen renders codex personas as TOML (codex's own subagent config
      # format), never as the .md the source is authored in -- so the mirror
      # path swaps the extension rather than keeping the source's basename.
      name="$(basename "$source" .md).toml"
      source="$hatsu_root/surfaces/codex/agents/$name"
      [ -f "$source" ] || {
        echo "generated codex mirror is missing agents/$name" >&2
        exit 2
      }
      persona_sources+=("$source")
    done
    [ "${#persona_sources[@]}" -gt 0 ] || {
      echo "generated codex mirror has no persona sources" >&2
      exit 2
    }
  elif [ "$surface" = "antigravity" ]; then
    [ -f "$hatsu_root/surfaces/antigravity/rules/hatsu.md" ] || {
      echo "generated antigravity mirror is missing rules/hatsu.md" >&2
      exit 2
    }
    [ -f "$hatsu_root/surfaces/antigravity/hooks.json" ] || {
      echo "generated antigravity mirror is missing hooks.json" >&2
      exit 2
    }
    [ -d "$hatsu_root/claude/agents" ] || {
      echo "Hatsu checkout has no canonical persona sources" >&2
      exit 2
    }
    for source in "$hatsu_root/claude/agents"/*.md; do
      [ -f "$source" ] || continue
      # A leading underscore names a shared PROSE FRAGMENT composed into
      # other agent files at doc-authoring time (_review-preamble.md), never
      # a standalone persona -- nen mirrors no surface agent for it, so a
      # persona_sources entry expecting one would fail every install.
      case "$(basename "$source")" in _*) continue ;; esac
      name="$(basename "$source")"
      source="$hatsu_root/surfaces/antigravity/agents/$name"
      [ -f "$source" ] || {
        echo "generated antigravity mirror is missing agents/$name" >&2
        exit 2
      }
      persona_sources+=("$source")
    done
    [ "${#persona_sources[@]}" -gt 0 ] || {
      echo "generated antigravity mirror has no persona sources" >&2
      exit 2
    }
  else
    [ -f "$hatsu_root/surfaces/cursor/rules/hatsu.mdc" ] || {
      echo "generated cursor mirror is missing rules/hatsu.mdc" >&2
      exit 2
    }
    [ -f "$hatsu_root/surfaces/cursor/hooks.json" ] || {
      echo "generated cursor mirror is missing hooks.json" >&2
      exit 2
    }
    [ -d "$hatsu_root/claude/agents" ] || {
      echo "Hatsu checkout has no canonical persona sources" >&2
      exit 2
    }
    for source in "$hatsu_root/claude/agents"/*.md; do
      [ -f "$source" ] || continue
      # A leading underscore names a shared PROSE FRAGMENT composed into
      # other agent files at doc-authoring time (_review-preamble.md), never
      # a standalone persona -- nen mirrors no surface agent for it, so a
      # persona_sources entry expecting one would fail every install.
      case "$(basename "$source")" in _*) continue ;; esac
      name="$(basename "$source")"
      source="$hatsu_root/surfaces/cursor/agents/$name"
      [ -f "$source" ] || {
        echo "generated cursor mirror is missing agents/$name" >&2
        exit 2
      }
      persona_sources+=("$source")
    done
    [ "${#persona_sources[@]}" -gt 0 ] || {
      echo "generated cursor mirror has no persona sources" >&2
      exit 2
    }
  fi
  # Discovered per run, per surface: whichever hatsu_root/surfaces/$surface/hooks/*.sh
  # `nen surface mirror generate` has actually produced so far. --plugin only
  # ever applies to codex (validated above), and codex's hooks are served by
  # the Codex plugin in that mode -- none are placed, so none are discovered.
  if [ -z "$plugin_mode" ] && [ -d "$hatsu_root/surfaces/$surface/hooks" ]; then
    for source in "$hatsu_root/surfaces/$surface/hooks"/*.sh; do
      [ -f "$source" ] || continue
      hook_scripts+=("$(basename "$source")")
    done
  fi
fi

# Create only real, untracked directories below the target. A symlinked parent
# could send an otherwise-safe destination outside the repository, and a
# deleted-but-tracked parent must never be recreated as Hatsu's directory.
is_tracked_parent() {
  git -C "$target" ls-files --stage -- "$1" |
    awk -v path="$1" '$4 == path { found = 1 } END { exit !found }'
}

# CREATE (second arg, default 1) governs only the one branch where a
# component is missing: 1 makes it (the ordinary placement path), 0 leaves
# it alone and returns 1 -- used by --plugin mode's removal pass (Feitan,
# CWE-59), which never creates anything but must refuse the exact same
# tracked-parent and symlinked-parent hazards a placement would, with the
# exact same messages and exit, before it enumerates or removes anything
# under a destination it never validated.
ensure_local_directory() {
  local relative="$1" create="${2:-1}" current="$target" component current_relative=""
  local -a components=()
  IFS='/' read -r -a components <<< "$relative"
  for component in "${components[@]}"; do
    current="$current/$component"
    current_relative="${current_relative:+$current_relative/}$component"
    if is_tracked_parent "$current_relative"; then
      echo "refusing: $relative has a tracked parent ($current_relative)" >&2
      exit 1
    fi
    if [ -L "$current" ]; then
      echo "refusing: $relative has a symlinked parent ($current)" >&2
      exit 1
    fi
    if [ -e "$current" ]; then
      [ -d "$current" ] || {
        echo "refusing: $relative has a non-directory parent ($current)" >&2
        exit 1
      }
    elif [ "$create" -eq 1 ]; then
      mkdir "$current"
    else
      return 1
    fi
  done
  return 0
}

# The discovery entry is required in EVERY mode, not only --bootstrap: an
# --install-all that kept a consumer-owned `ten` and went on to remove the
# working `hatsu-warmup` as stale (v0.49.0 rename) would exit 0 with no
# discoverable Hatsu entry left -- `$ten` / `/ten` (P1 of every phase) would
# run the consumer's skill and the D10 warm-up would be gone. So a blocker on
# the entry refuses the whole run, before any stale removal, leaving whatever
# the target had (the old entry included) exactly where it was.
fail_bootstrap_blocker() {
  local relative="$1"
  if [ "$relative" = '.agents/skills/ten' ] || [ "$relative" = '.cursor/skills/ten' ]; then
    echo "refusing ${mode#--}: $relative blocks required ten discovery" >&2
    exit 1
  fi
}

preflight_bootstrap_destination() {
  local relative="$1" destination="$target/$1"
  if is_tracked "$relative"; then
    fail_bootstrap_blocker "$relative"
  elif { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours "$relative"; then
    fail_bootstrap_blocker "$relative"
  fi
}

preflight_destination() {
  local relative="$1" ownership="$2" destination="$target/$1"
  if is_tracked "$relative"; then
    fail_bootstrap_blocker "$relative"
  elif { [ -e "$destination" ] || [ -L "$destination" ]; } &&
    { [ "$ownership" = "override" ] && ! is_ours_override || [ "$ownership" = "hooks" ] && ! is_ours_hooks || [ "$ownership" = "hook_script" ] && ! is_ours_hook_script "$relative" || [ "$ownership" = "skill" ] && ! is_ours "$relative"; }; then
    fail_bootstrap_blocker "$relative"
  fi
}

preflight_install_destinations() {
  local name source
  if [ "$surface" = "codex" ]; then
    if [ "${#skill_names[@]}" -gt 0 ]; then
      for name in "${skill_names[@]}"; do
        preflight_destination ".agents/skills/$name" skill
      done
    fi
    if [ "$mode" = "--install-all" ]; then
      preflight_destination 'AGENTS.override.md' override
      if [ -z "$plugin_mode" ]; then
        preflight_destination '.codex/hooks.json' skill
        for name in "${hook_scripts[@]}"; do
          preflight_destination ".codex/hooks/$name" hook_script
        done
      fi
      for source in "${persona_sources[@]}"; do
        preflight_destination ".codex/agents/$(basename "$source")" skill
      done
    fi
  elif [ "$surface" = "antigravity" ]; then
    for name in "${skill_names[@]}"; do
      preflight_destination ".agents/skills/$name" skill
    done
    if [ "$mode" = "--install-all" ]; then
      preflight_destination '.agents/rules/hatsu.md' skill
      preflight_destination '.agents/hooks.json' hooks
      # HOOK SCRIPTS ARE WHATEVER THE GENERATOR HAS PRODUCED SO FAR: see
      # hook_scripts's own comment. Nothing is preflighted for a
      # script the generator has not produced yet -- there is no destination
      # this run could ever write for it.
      for name in "${hook_scripts[@]}"; do
        preflight_destination ".agents/hooks/$name" hook_script
      done
      for source in "${persona_sources[@]}"; do
        preflight_destination ".agents/agents/$(basename "$source")" skill
      done
    fi
  else
    for name in "${skill_names[@]}"; do
      preflight_destination ".cursor/skills/$name" skill
    done
    if [ "$mode" = "--install-all" ]; then
      for source in "${persona_sources[@]}"; do
        preflight_destination ".cursor/agents/$(basename "$source")" skill
      done
      preflight_destination '.cursor/rules/hatsu.mdc' skill
      preflight_destination '.cursor/hooks.json' skill
      for name in "${hook_scripts[@]}"; do
        preflight_destination ".cursor/hooks/$name" hook_script
      done
    fi
  fi
}

will_replace() {
  local relative="$1" destination="$target/$1"
  is_tracked "$relative" && return 1
  { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours "$relative" && return 1
  return 0
}

will_replace_override() {
  local relative='AGENTS.override.md' destination="$target/AGENTS.override.md"
  is_tracked "$relative" && return 1
  { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours_override && return 1
  return 0
}

will_replace_hooks() {
  local relative='.agents/hooks.json' destination="$target/.agents/hooks.json"
  is_tracked "$relative" && return 1
  { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours_hooks && return 1
  return 0
}

will_replace_hook_script() {
  local relative="$1" destination="$target/$1"
  is_tracked "$relative" && return 1
  { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours_hook_script "$relative" && return 1
  return 0
}

declare -a exclude_lines=()

exclude="$(git -C "$target" rev-parse --git-path info/exclude)"
case "$exclude" in
  /*) ;;
  *) exclude="$target/$exclude" ;;
esac

exclude_backup=""
exclude_existed=0
staging=""
backup=""
declare -a replaced_paths=() backed_up_paths=()

cleanup() {
  local status=$? relative backup_path
  trap - EXIT
  if [ "$status" -ne 0 ]; then
    if [ "${#replaced_paths[@]}" -gt 0 ]; then
      for relative in "${replaced_paths[@]}"; do
        rm -rf -- "${target:?}/${relative:?}" || :
      done
    fi
    if [ "${#backed_up_paths[@]}" -gt 0 ]; then
      for relative in "${backed_up_paths[@]}"; do
        backup_path="$backup/$relative"
        { [ -e "$backup_path" ] || [ -L "$backup_path" ]; } || continue
        mkdir -p "$(dirname "$target/$relative")" || :
        mv "$backup_path" "$target/$relative" || :
      done
    fi
  fi
  if [ "$status" -ne 0 ] && [ -n "$exclude_backup" ]; then
    if [ "$exclude_existed" -eq 1 ]; then
      cp "$exclude_backup" "$exclude" || :
    else
      rm -f -- "$exclude" || :
    fi
  fi
  [ -z "$staging" ] || rm -rf -- "$staging"
  [ -z "$backup" ] || rm -rf -- "$backup"
  [ -z "$exclude_backup" ] || rm -f -- "$exclude_backup"
  exit "$status"
}

add_exclude_lines() {
  local line exclude_directory probe
  exclude_directory="$(dirname "$exclude")"
  mkdir -p "$exclude_directory"
  exclude_backup="$(mktemp "$exclude_directory/.hatsu-exclude.XXXXXX")"
  if [ -f "$exclude" ]; then
    cp "$exclude" "$exclude_backup"
    exclude_existed=1
  fi
  # Guarded on count first, same reason as skill_names's own guard above:
  # bash 3.2 raises "unbound variable" expanding "${exclude_lines[@]}" under
  # `set -u` when the array is truly empty (Phinks) -- and --plugin mode, or a
  # run where every candidate destination is already tracked or foreign, can
  # leave it exactly that empty.
  if [ "${#exclude_lines[@]}" -gt 0 ]; then
    for line in "${exclude_lines[@]}"; do
      probe="$(exclude_probe "$line")"
      git -C "$target" check-ignore -q -- "$probe" && continue
      if [ -s "$exclude" ] && [ "$(tail -c 1 "$exclude"; printf x)" != $'\nx' ]; then
        printf '\n' >> "$exclude"
      fi
      printf '%s\n' "$line" >> "$exclude"
    done
  fi
}

prepare_staged_surface() {
  local name relative source stage_path
  staging="$(mktemp -d "$target/.hatsu-surface.XXXXXX")"
  backup="$(mktemp -d "$target/.hatsu-backup.XXXXXX")"

  if [ "$surface" = "codex" ]; then
    if [ "${#skill_names[@]}" -gt 0 ]; then
      for name in "${skill_names[@]}"; do
        relative=".agents/skills/$name"
        will_replace "$relative" || continue
        stage_path="$staging/$relative"
        mkdir -p "$(dirname "$stage_path")"
        cp -R "$skills_src/$name" "$stage_path"
      done
    fi
    if [ "$mode" = "--install-all" ]; then
      if will_replace_override; then
        stage_path="$staging/AGENTS.override.md"
        {
          if [ -f "$target/AGENTS.md" ]; then
            cat "$target/AGENTS.md"
            printf '\n\n'
          fi
          printf '%s\n' '<!-- BEGIN hatsu personas (generated — nen surface mirror, surface: codex) -->'
          cat "$hatsu_root/surfaces/codex/AGENTS.md"
          printf '%s\n' '<!-- END hatsu personas (generated — nen surface mirror, surface: codex) -->'
        } > "$stage_path"
      fi
      if [ -z "$plugin_mode" ]; then
        if will_replace '.codex/hooks.json'; then
          stage_path="$staging/.codex/hooks.json"
          mkdir -p "$(dirname "$stage_path")"
          cp "$hatsu_root/surfaces/codex/hooks.json" "$stage_path"
        fi
        # HOOK SCRIPTS, WHICHEVER ONES THE GENERATOR HAS PRODUCED. See
        # hook_scripts's own comment: this is discovered per run, not a fixed set.
        for name in "${hook_scripts[@]}"; do
          relative=".codex/hooks/$name"
          will_replace_hook_script "$relative" || continue
          stage_path="$staging/$relative"
          mkdir -p "$(dirname "$stage_path")"
          cp "$hatsu_root/surfaces/codex/hooks/$name" "$stage_path"
          chmod 755 "$stage_path"
        done
      fi
      for source in "${persona_sources[@]}"; do
        relative=".codex/agents/$(basename "$source")"
        will_replace "$relative" || continue
        stage_path="$staging/$relative"
        mkdir -p "$(dirname "$stage_path")"
        cp "$source" "$stage_path"
      done
    fi
  elif [ "$surface" = "antigravity" ]; then
    for name in "${skill_names[@]}"; do
      relative=".agents/skills/$name"
      will_replace "$relative" || continue
      stage_path="$staging/$relative"
      mkdir -p "$(dirname "$stage_path")"
      cp -R "$skills_src/$name" "$stage_path"
    done
    if [ "$mode" = "--install-all" ]; then
      # SOURCE AND DESTINATION both hatsu.md, as of nen's regenerated mirror:
      # Antigravity's documented layout (.agents/rules/<name>.md, up to 12,000
      # chars each) never names a fixed "AGENTS.md" -- that spelling came from
      # following Codex's convention on a surface that does not use it, and
      # `nen surface mirror generate` now renders under the corrected name too.
      if will_replace '.agents/rules/hatsu.md'; then
        stage_path="$staging/.agents/rules/hatsu.md"
        mkdir -p "$(dirname "$stage_path")"
        cp "$hatsu_root/surfaces/antigravity/rules/hatsu.md" "$stage_path"
      fi
      if will_replace_hooks; then
        stage_path="$staging/.agents/hooks.json"
        mkdir -p "$(dirname "$stage_path")"
        cp "$hatsu_root/surfaces/antigravity/hooks.json" "$stage_path"
        # WORKSPACE-MODE ROOT REWRITE. The tracked mirror's fallback resolves
        # to the GLOBAL plugin directory
        # (${HATSU_PLUGIN_ROOT:-${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu})
        # because `nen surface mirror generate`'s root expression cannot test
        # for existence (it refuses `$(`) and so cannot itself decide between
        # a global install and a workspace one. But THIS placement is a
        # workspace install: the hook SCRIPTS land beside this very file, at
        # `.agents/hooks/`, same as Codex's placed copy already falls back to
        # `./.codex` and Cursor's to `./.cursor` (both by generation, since
        # neither surface shares a directory with another one that also
        # writes there). Antigravity does share `.agents/` with Codex, so its
        # generated mirror cannot default to a bare `./.agents` without also
        # breaking the genuine global-plugin case, and this rewrite is scoped
        # to the PLACED copy only -- the tracked mirror under surfaces/
        # keeps the generated, global-defaulting form untouched.
        tmp_hooks_json="$stage_path.rewrite.$$"
        sed 's#${HATSU_PLUGIN_ROOT:-${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu}#${HATSU_PLUGIN_ROOT:-./.agents}#g' \
          "$stage_path" > "$tmp_hooks_json"
        mv "$tmp_hooks_json" "$stage_path"
      fi
      # HOOK SCRIPTS, WHICHEVER ONES THE GENERATOR HAS PRODUCED. See
      # hook_scripts's own comment: this is discovered per run,
      # not a fixed pair.
      for name in "${hook_scripts[@]}"; do
        relative=".agents/hooks/$name"
        will_replace_hook_script "$relative" || continue
        stage_path="$staging/$relative"
        mkdir -p "$(dirname "$stage_path")"
        cp "$hatsu_root/surfaces/antigravity/hooks/$name" "$stage_path"
        chmod 755 "$stage_path"
      done
      for source in "${persona_sources[@]}"; do
        relative=".agents/agents/$(basename "$source")"
        will_replace "$relative" || continue
        stage_path="$staging/$relative"
        mkdir -p "$(dirname "$stage_path")"
        cp "$source" "$stage_path"
      done
    fi
  else
    for name in "${skill_names[@]}"; do
      relative=".cursor/skills/$name"
      will_replace "$relative" || continue
      stage_path="$staging/$relative"
      mkdir -p "$(dirname "$stage_path")"
      ln -s "$skills_src/$name" "$stage_path"
    done
    if [ "$mode" = "--install-all" ]; then
      for source in "${persona_sources[@]}"; do
        relative=".cursor/agents/$(basename "$source")"
        will_replace "$relative" || continue
        stage_path="$staging/$relative"
        mkdir -p "$(dirname "$stage_path")"
        ln -s "$source" "$stage_path"
      done
      if will_replace '.cursor/rules/hatsu.mdc'; then
        stage_path="$staging/.cursor/rules/hatsu.mdc"
        mkdir -p "$(dirname "$stage_path")"
        ln -s "$hatsu_root/surfaces/cursor/rules/hatsu.mdc" "$stage_path"
      fi
      if will_replace '.cursor/hooks.json'; then
        stage_path="$staging/.cursor/hooks.json"
        mkdir -p "$(dirname "$stage_path")"
        ln -s "$hatsu_root/surfaces/cursor/hooks.json" "$stage_path"
      fi
      # HOOK SCRIPTS, WHICHEVER ONES THE GENERATOR HAS PRODUCED. See
      # hook_scripts's own comment: this is discovered per run, not a fixed set.
      for name in "${hook_scripts[@]}"; do
        relative=".cursor/hooks/$name"
        will_replace_hook_script "$relative" || continue
        stage_path="$staging/$relative"
        mkdir -p "$(dirname "$stage_path")"
        ln -s "$hatsu_root/surfaces/cursor/hooks/$name" "$stage_path"
      done
    fi
  fi
}

transaction_replace() {
  local relative="$1" destination="$target/$1" staged="$staging/$1"
  { [ -e "$destination" ] || [ -L "$destination" ]; } && {
    mkdir -p "$(dirname "$backup/$relative")"
    backed_up_paths+=("$relative")
    mv "$destination" "$backup/$relative"
  }
  replaced_paths+=("$relative")
  mkdir -p "$(dirname "$destination")"
  mv "$staged" "$destination"
}

transaction_remove() {
  local relative="$1" destination="$target/$1"
  mkdir -p "$(dirname "$backup/$relative")"
  backed_up_paths+=("$relative")
  mv "$destination" "$backup/$relative"
}

exclude_probe() {
  case "$1" in
    .agents/skills/*) printf '%s/SKILL.md' "$1" ;;
    *) printf '%s' "$1" ;;
  esac
}

preflight_exclude_lines() {
  local line probe
  # Same bash 3.2 empty-array guard as add_exclude_lines above.
  if [ "${#exclude_lines[@]}" -gt 0 ]; then
    for line in "${exclude_lines[@]}"; do
      probe="$(exclude_probe "$line")"
      git -C "$target" check-ignore -q -- "$probe" || {
        echo "refusing: $line was not excluded through info/exclude" >&2
        exit 1
      }
    done
  fi
}

declare -a installed=() removed=() kept=() plugin_removed=()

is_expected_skill() {
  local expected="$1" name
  for name in "${skill_names[@]}"; do
    [ "$name" = "$expected" ] && return 0
  done
  return 1
}

is_expected_persona() {
  local expected="$1" source
  for source in "${persona_sources[@]}"; do
    [ "$(basename "$source")" = "$expected" ] && return 0
  done
  return 1
}

remove_stale_skills() {
  local skills_root="$1" relative destination name
  for destination in "$skills_root"/*; do
    [ -e "$destination" ] || [ -L "$destination" ] || continue
    name="$(basename "$destination")"
    is_expected_skill "$name" && continue
    relative="${skills_root#"$target/"}/$name"
    is_ours "$relative" || continue
    transaction_remove "$relative"
    removed+=("$name")
  done
}

remove_stale_agents() {
  local agents_root="$1" relative destination name
  for destination in "$agents_root"/*; do
    [ -e "$destination" ] || [ -L "$destination" ] || continue
    name="$(basename "$destination")"
    is_expected_persona "$name" && continue
    relative="${agents_root#"$target/"}/$name"
    is_ours "$relative" || continue
    transaction_remove "$relative"
    removed+=("agents/$name")
  done
}

# Codex and Antigravity share .agents/skills (skills_source_dir's own comment
# above), so a generic is_ours check on an untracked destination there cannot
# tell which surface actually placed it. --plugin mode's removal pass must:
# the Codex plugin now serves CODEX'S OWN placements, never Antigravity's,
# which merely happens to share the directory (Phinks; Feitan's note on the
# same finding). True only for an untracked destination carrying codex's OWN
# stamp -- a marker naming "(surface: codex," or a symlink resolving under
# this checkout's own surfaces/codex/ tree. Every other surface's placement
# -- Antigravity's included -- is left exactly where it is, and reported kept.
is_ours_codex_only() {
  local relative="$1" destination="$target/$1" link_target
  is_tracked "$relative" && return 1
  if [ -L "$destination" ]; then
    link_target="$(readlink "$destination")"
    case "$link_target" in
      "$hatsu_root"/surfaces/codex/*) return 0 ;;
      *) return 1 ;;
    esac
  fi
  [ -f "$destination/SKILL.md" ] && grep -qsF 'GENERATED by nen surface mirror (surface: codex,' "$destination/SKILL.md" && return 0
  [ -f "$destination" ] && grep -qsF 'GENERATED by nen surface mirror (surface: codex,' "$destination"
}

# --plugin ONLY (codex, --install-all): the Codex plugin now serves every
# skill AND the hooks, so nothing of either kind is placed here any more --
# whatever this bootstrap placed there before is removed outright, reported
# under a phrase distinct from ordinary stale-skill replacement ("removed
# (the Codex plugin serves it)" rather than "removed stale"), because the
# reason is not that a skill was renamed or dropped from the canonical set,
# it is that the PLUGIN now owns the destination. A destination that is NOT
# ours (foreign, or tracked -- is_ours_codex_only already returns false for
# both, and for another surface's own placement) is never touched, and is
# reported as kept, exactly like every other collision this script already
# reports.
#
# ensure_local_directory ... 0 guards the ENUMERATION ROOT itself before a
# single entry under it is ever touched (Feitan, CWE-59): --plugin mode skips
# the ordinary ensure_local_directory call that would otherwise create
# .agents/skills / .codex/hooks (there is nothing to place there any more), so
# nothing upstream has yet refused a symlinked or tracked-file .agents,
# .agents/skills, .codex, or .codex/hooks the way placement would. A tracked
# symlink there (his repro: a tracked .agents/skills -> ../../outside) or an
# untracked symlinked directory sends `for destination in "$skills_root"/*`
# enumerating OUTSIDE the target, and transaction_remove's `mv` would then
# move real, outside files into the transaction backup -- which is deleted
# outright on a clean exit. Absent is not a hazard (create=0 returns 1 with
# nothing removed, never created); a tracked or symlinked parent refuses with
# ensure_local_directory's own messages and exit, before any enumeration.
remove_plugin_served_skills() {
  local skills_root="$1" relative destination name skills_relative
  skills_relative="${skills_root#"$target/"}"
  ensure_local_directory "$skills_relative" 0 || return 0
  for destination in "$skills_root"/*; do
    [ -e "$destination" ] || [ -L "$destination" ] || continue
    name="$(basename "$destination")"
    relative="${skills_root#"$target/"}/$name"
    if is_ours_codex_only "$relative"; then
      transaction_remove "$relative"
      plugin_removed+=("$name")
    else
      kept+=("$name")
    fi
  done
}

remove_plugin_served_hooks() {
  local relative=".codex/hooks.json" destination="$target/.codex/hooks.json" name
  # Same CWE-59 guard as remove_plugin_served_skills, on both destinations
  # this function ever touches: '.codex' itself (the parent hooks.json sits
  # directly under) and '.codex/hooks' (the directory this enumerates).
  if ensure_local_directory '.codex' 0; then
    if [ -e "$destination" ] || [ -L "$destination" ]; then
      if is_ours "$relative"; then
        transaction_remove "$relative"
        plugin_removed+=("$relative")
      else
        kept+=("$relative")
      fi
    fi
  fi
  if ensure_local_directory '.codex/hooks' 0; then
    for destination in "$target/.codex/hooks"/*; do
      [ -e "$destination" ] || [ -L "$destination" ] || continue
      name="$(basename "$destination")"
      relative=".codex/hooks/$name"
      if is_ours_hook_script "$relative"; then
        transaction_remove "$relative"
        plugin_removed+=("$relative")
      else
        kept+=("$relative")
      fi
    done
  fi
}

# Ignore only the exact Hatsu entries this invocation will own. Broad surface
# roots would hide an untracked user collision that the installer deliberately
# leaves alone.
collect_exclude_lines() {
  local name relative source
  exclude_lines=()
  if [ "$surface" = "codex" ]; then
    if [ "${#skill_names[@]}" -gt 0 ]; then
      for name in "${skill_names[@]}"; do
        relative=".agents/skills/$name"
        will_replace "$relative" && exclude_lines+=("$relative")
      done
    fi
    if [ "$mode" = "--install-all" ]; then
      if will_replace_override; then
        exclude_lines+=('AGENTS.override.md')
      fi
      if [ -z "$plugin_mode" ]; then
        if will_replace '.codex/hooks.json'; then
          exclude_lines+=('.codex/hooks.json')
        fi
        for name in "${hook_scripts[@]}"; do
          relative=".codex/hooks/$name"
          will_replace_hook_script "$relative" && exclude_lines+=("$relative")
        done
      fi
      for source in "${persona_sources[@]}"; do
        relative=".codex/agents/$(basename "$source")"
        will_replace "$relative" && exclude_lines+=("$relative")
      done
    fi
  elif [ "$surface" = "antigravity" ]; then
    for name in "${skill_names[@]}"; do
      relative=".agents/skills/$name"
      will_replace "$relative" && exclude_lines+=("$relative")
    done
    if [ "$mode" = "--install-all" ]; then
      if will_replace '.agents/rules/hatsu.md'; then
        exclude_lines+=('.agents/rules/hatsu.md')
      fi
      if will_replace_hooks; then
        exclude_lines+=('.agents/hooks.json')
      fi
      for name in "${hook_scripts[@]}"; do
        relative=".agents/hooks/$name"
        will_replace_hook_script "$relative" && exclude_lines+=("$relative")
      done
      for source in "${persona_sources[@]}"; do
        relative=".agents/agents/$(basename "$source")"
        will_replace "$relative" && exclude_lines+=("$relative")
      done
    fi
  else
    for name in "${skill_names[@]}"; do
      relative=".cursor/skills/$name"
      will_replace "$relative" && exclude_lines+=("$relative")
    done
    if [ "$mode" = "--install-all" ]; then
      for source in "${persona_sources[@]}"; do
        relative=".cursor/agents/$(basename "$source")"
        will_replace "$relative" && exclude_lines+=("$relative")
      done
      if will_replace '.cursor/rules/hatsu.mdc'; then
        exclude_lines+=('.cursor/rules/hatsu.mdc')
      fi
      if will_replace '.cursor/hooks.json'; then
        exclude_lines+=('.cursor/hooks.json')
      fi
      for name in "${hook_scripts[@]}"; do
        relative=".cursor/hooks/$name"
        will_replace_hook_script "$relative" && exclude_lines+=("$relative")
      done
    fi
  fi
  # EXPLICIT return, not the last loop's own exit status (Phinks; pre-existing
  # on main): every branch above ends on `will_replace ... && exclude_lines+=(...)`,
  # whose exit status is 1 whenever the LAST candidate in that loop is already
  # tracked or foreign -- a tracked last persona (.codex/agents/uvogin.toml,
  # alphabetically last) made this function itself return 1. Called
  # unconditionally under `set -e`, that silently exited the whole script with
  # no message at all. collect_exclude_lines's job is to populate the array;
  # whether its last candidate happened to need excluding is not this
  # function's own success or failure.
  return 0
}

# Validate every destination root, and the sole required bootstrap destination,
# before changing the shared ignore file or replacing a surface entry.
if [ "$surface" = "codex" ]; then
  # SKILLS LIVE AT `.agents/skills/<name>` ONLY. This is the one skills path
  # this script has ever placed for Codex -- `.codex/skills` is Codex's own
  # directory family for everything ELSE (agents, hooks, config), but Codex
  # discovers skills at the same `.agents/skills` path Antigravity and the
  # documented convention both use, and this script has never written a second,
  # `.codex/skills` copy of them.
  if [ -z "$plugin_mode" ]; then
    ensure_local_directory '.agents/skills'
  fi
  if [ "$mode" = "--install-all" ]; then
    ensure_local_directory '.codex/agents'
    if [ -z "$plugin_mode" ]; then
      ensure_local_directory '.codex/hooks'
    fi
  fi
  if [ "$mode" = "--bootstrap" ]; then
    preflight_bootstrap_destination '.agents/skills/ten'
  fi
elif [ "$surface" = "antigravity" ]; then
  ensure_local_directory '.agents/skills'
  if [ "$mode" = "--install-all" ]; then
    ensure_local_directory '.agents/rules'
    ensure_local_directory '.agents/hooks'
    ensure_local_directory '.agents/agents'
  fi
  if [ "$mode" = "--bootstrap" ]; then
    preflight_bootstrap_destination '.agents/skills/ten'
  fi
else
  ensure_local_directory '.cursor/skills'
  if [ "$mode" = "--install-all" ]; then
    ensure_local_directory '.cursor/agents'
    ensure_local_directory '.cursor/hooks'
    ensure_local_directory '.cursor/rules'
  fi
  if [ "$mode" = "--bootstrap" ]; then
    preflight_bootstrap_destination '.cursor/skills/ten'
  fi
fi
preflight_install_destinations
collect_exclude_lines
trap cleanup EXIT
prepare_staged_surface
add_exclude_lines
preflight_exclude_lines

if [ "$surface" = "codex" ]; then
  if [ "$mode" = "--install-all" ]; then
    if [ -n "$plugin_mode" ]; then
      remove_plugin_served_skills "$target/.agents/skills"
    else
      remove_stale_skills "$target/.agents/skills"
    fi
  fi
  if [ "${#skill_names[@]}" -gt 0 ]; then
    for name in "${skill_names[@]}"; do
      relative=".agents/skills/$name"
      destination="$target/$relative"
      source="$skills_src/$name"
      if is_tracked "$relative"; then
        fail_bootstrap_blocker "$relative"
        kept+=("$name")
        continue
      fi
      if { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours "$relative"; then
        fail_bootstrap_blocker "$relative"
        kept+=("$name")
        continue
      fi
      transaction_replace "$relative"
      installed+=("$name")
    done
  fi

  if [ "$mode" = "--install-all" ]; then
    relative="AGENTS.override.md"
    destination="$target/$relative"
    if is_tracked "$relative"; then
      kept+=("$relative")
    elif { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours_override; then
      kept+=("$relative")
    else
      transaction_replace "$relative"
      installed+=("$relative")
    fi

    if [ -n "$plugin_mode" ]; then
      remove_plugin_served_hooks
    else
      relative=".codex/hooks.json"
      destination="$target/$relative"
      if is_tracked "$relative"; then
        kept+=("$relative")
      elif { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours "$relative"; then
        kept+=("$relative")
      else
        transaction_replace "$relative"
        installed+=("$relative")
      fi

      for name in "${hook_scripts[@]}"; do
        relative=".codex/hooks/$name"
        destination="$target/$relative"
        if is_tracked "$relative"; then
          kept+=("$relative")
        elif { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours_hook_script "$relative"; then
          kept+=("$relative")
        else
          transaction_replace "$relative"
          installed+=("$relative")
        fi
      done
    fi

    remove_stale_agents "$target/.codex/agents"
    for source in "${persona_sources[@]}"; do
      name="$(basename "$source")"
      relative=".codex/agents/$name"
      destination="$target/$relative"
      if is_tracked "$relative"; then
        kept+=("agents/$name")
        continue
      fi
      if { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours "$relative"; then
        kept+=("agents/$name")
        continue
      fi
      transaction_replace "$relative"
      installed+=("agents/$name")
    done
  fi
elif [ "$surface" = "antigravity" ]; then
  if [ "$mode" = "--install-all" ]; then
    remove_stale_skills "$target/.agents/skills"
  fi
  for name in "${skill_names[@]}"; do
    relative=".agents/skills/$name"
    destination="$target/$relative"
    source="$skills_src/$name"
    if is_tracked "$relative"; then
      fail_bootstrap_blocker "$relative"
      kept+=("$name")
      continue
    fi
    if { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours "$relative"; then
      fail_bootstrap_blocker "$relative"
      kept+=("$name")
      continue
    fi
    transaction_replace "$relative"
    installed+=("$name")
  done

  if [ "$mode" = "--install-all" ]; then
    declare -a antigravity_named_destinations=(".agents/rules/hatsu.md" ".agents/hooks.json")
    for name in "${hook_scripts[@]}"; do
      antigravity_named_destinations+=(".agents/hooks/$name")
    done
    for relative in "${antigravity_named_destinations[@]}"; do
      destination="$target/$relative"
      ownership="skill"
      case "$relative" in
        *.json) ownership="hooks" ;;
        *.sh) ownership="hook_script" ;;
      esac
      if is_tracked "$relative"; then
        fail_bootstrap_blocker "$relative"
        kept+=("$relative")
      elif { [ -e "$destination" ] || [ -L "$destination" ]; } &&
        { [ "$ownership" = "hooks" ] && ! is_ours_hooks || [ "$ownership" = "hook_script" ] && ! is_ours_hook_script "$relative" || [ "$ownership" = "skill" ] && ! is_ours "$relative"; }; then
        fail_bootstrap_blocker "$relative"
        kept+=("$relative")
      else
        transaction_replace "$relative"
        installed+=("$relative")
      fi
    done

    remove_stale_agents "$target/.agents/agents"
    for source in "${persona_sources[@]}"; do
      name="$(basename "$source")"
      relative=".agents/agents/$name"
      destination="$target/$relative"
      if is_tracked "$relative"; then
        kept+=("agents/$name")
        continue
      fi
      if { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours "$relative"; then
        kept+=("agents/$name")
        continue
      fi
      transaction_replace "$relative"
      installed+=("agents/$name")
    done
  fi
else
  if [ "$mode" = "--install-all" ]; then
    remove_stale_skills "$target/.cursor/skills"
  fi
  for name in "${skill_names[@]}"; do
    relative=".cursor/skills/$name"
    destination="$target/$relative"
    source="$skills_src/$name"
    if is_tracked "$relative"; then
      fail_bootstrap_blocker "$relative"
      kept+=("$name")
      continue
    fi
    if { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours "$relative"; then
      fail_bootstrap_blocker "$relative"
      kept+=("$name")
      continue
    fi
    transaction_replace "$relative"
    installed+=("$name")
  done

  if [ "$mode" = "--install-all" ]; then
    remove_stale_agents "$target/.cursor/agents"
    for source in "${persona_sources[@]}"; do
      name="$(basename "$source")"
      relative=".cursor/agents/$name"
      destination="$target/$relative"
      if is_tracked "$relative"; then
        kept+=("agents/$name")
        continue
      fi
      if { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours "$relative"; then
        kept+=("agents/$name")
        continue
      fi
      transaction_replace "$relative"
      installed+=("agents/$name")
    done

    for relative in ".cursor/rules/hatsu.mdc" ".cursor/hooks.json"; do
      destination="$target/$relative"
      if is_tracked "$relative"; then
        kept+=("$relative")
      elif { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours "$relative"; then
        kept+=("$relative")
      else
        transaction_replace "$relative"
        installed+=("$relative")
      fi
    done

    for name in "${hook_scripts[@]}"; do
      relative=".cursor/hooks/$name"
      destination="$target/$relative"
      if is_tracked "$relative"; then
        kept+=("$relative")
      elif { [ -e "$destination" ] || [ -L "$destination" ]; } && ! is_ours_hook_script "$relative"; then
        kept+=("$relative")
      else
        transaction_replace "$relative"
        installed+=("$relative")
      fi
    done
  fi
fi

printf 'surface bootstrap: %s %s — installed %s' "$surface" "${mode#--}" "${#installed[@]}"
if [ "${#removed[@]}" -gt 0 ]; then
  printf '; removed stale %s' "$(IFS=', '; echo "${removed[*]}")"
fi
if [ "${#plugin_removed[@]}" -gt 0 ]; then
  printf '; removed (the Codex plugin serves it): %s' "$(IFS=', '; echo "${plugin_removed[*]}")"
fi
if [ "${#kept[@]}" -gt 0 ]; then
  printf '; kept existing %s' "$(IFS=', '; echo "${kept[*]}")"
fi
printf '\n'
if [ -n "$plugin_mode" ]; then
  printf 'codex plugin mode: skills and hooks served by the plugin\n'
fi
