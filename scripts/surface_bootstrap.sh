#!/usr/bin/env bash
# Install Hatsu's first discoverable skill, or refresh a whole generated surface.
#
# This script exists for the one moment a Hatsu skill cannot run: before Codex or
# Cursor has discovered hatsu-warmup. It deliberately shares the warm-up's
# safety contract: only generated Hatsu destinations may be replaced, tracked
# files always win, and local installation state belongs in info/exclude.

set -euo pipefail
LC_ALL=C

usage() {
  cat <<'EOF'
usage: scripts/surface_bootstrap.sh --surface codex|cursor --target <repository> --bootstrap|--install-all

--bootstrap   Install only hatsu-warmup, making the first skill invocation discoverable.
--install-all Refresh the complete generated surface. hatsu-warmup uses this after discovery.
EOF
}

surface=""
target_input=""
mode=""

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

case "$surface" in codex|cursor) ;; *) echo "--surface must be codex or cursor" >&2; exit 2 ;; esac
[ -n "$target_input" ] || { echo "--target is required" >&2; exit 2; }
[ -n "$mode" ] || { echo "choose --bootstrap or --install-all" >&2; exit 2; }

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

# Same structural manifest reader as hatsu-warmup: accept only the canonical
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

declare -a skill_names=()
if [ "$mode" = "--bootstrap" ]; then
  skill_names=("hatsu-warmup")
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

for name in "${skill_names[@]}"; do
  [ -f "$hatsu_root/surfaces/$surface/$name/SKILL.md" ] || {
    echo "generated $surface mirror is missing $name/SKILL.md" >&2
    exit 2
  }
done

declare -a persona_sources=()
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
  else
    [ -d "$hatsu_root/claude/agents" ] || {
      echo "Hatsu checkout has no canonical persona sources" >&2
      exit 2
    }
    for source in "$hatsu_root/claude/agents"/*.md; do
      [ -f "$source" ] || continue
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
fi

# A tracked path is never ours, even if it happens to contain Hatsu's marker.
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
  [ -f "$destination/SKILL.md" ] && grep -qs 'GENERATED by nen surface mirror' "$destination/SKILL.md" && return 0
  [ -f "$destination" ] && grep -qs 'GENERATED by nen surface mirror' "$destination"
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

# Create only real, untracked directories below the target. A symlinked parent
# could send an otherwise-safe destination outside the repository, and a
# deleted-but-tracked parent must never be recreated as Hatsu's directory.
is_tracked_parent() {
  git -C "$target" ls-files --stage -- "$1" |
    awk -v path="$1" '$4 == path { found = 1 } END { exit !found }'
}

ensure_local_directory() {
  local relative="$1" current="$target" component current_relative=""
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
    else
      mkdir "$current"
    fi
  done
}

fail_bootstrap_blocker() {
  local relative="$1"
  if [ "$mode" = "--bootstrap" ] && {
    [ "$relative" = '.agents/skills/hatsu-warmup' ] || [ "$relative" = '.cursor/skills/hatsu-warmup' ]
  }; then
    echo "refusing bootstrap: $relative blocks required hatsu-warmup discovery" >&2
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
    { [ "$ownership" = "override" ] && ! is_ours_override || [ "$ownership" = "skill" ] && ! is_ours "$relative"; }; then
    fail_bootstrap_blocker "$relative"
  fi
}

preflight_install_destinations() {
  local name source
  if [ "$surface" = "codex" ]; then
    for name in "${skill_names[@]}"; do
      preflight_destination ".agents/skills/$name" skill
    done
    [ "$mode" != "--install-all" ] || preflight_destination 'AGENTS.override.md' override
  else
    for name in "${skill_names[@]}"; do
      preflight_destination ".cursor/skills/$name" skill
    done
    if [ "$mode" = "--install-all" ]; then
      for source in "${persona_sources[@]}"; do
        preflight_destination ".cursor/agents/$(basename "$source")" skill
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
  for line in "${exclude_lines[@]}"; do
    probe="$(exclude_probe "$line")"
    git -C "$target" check-ignore -q -- "$probe" && continue
    if [ -s "$exclude" ] && [ "$(tail -c 1 "$exclude"; printf x)" != $'\nx' ]; then
      printf '\n' >> "$exclude"
    fi
    printf '%s\n' "$line" >> "$exclude"
  done
}

prepare_staged_surface() {
  local name relative source stage_path
  staging="$(mktemp -d "$target/.hatsu-surface.XXXXXX")"
  backup="$(mktemp -d "$target/.hatsu-backup.XXXXXX")"

  if [ "$surface" = "codex" ]; then
    for name in "${skill_names[@]}"; do
      relative=".agents/skills/$name"
      will_replace "$relative" || continue
      stage_path="$staging/$relative"
      mkdir -p "$(dirname "$stage_path")"
      cp -R "$hatsu_root/surfaces/codex/$name" "$stage_path"
    done
    if [ "$mode" = "--install-all" ] && will_replace_override; then
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
  else
    for name in "${skill_names[@]}"; do
      relative=".cursor/skills/$name"
      will_replace "$relative" || continue
      stage_path="$staging/$relative"
      mkdir -p "$(dirname "$stage_path")"
      ln -s "$hatsu_root/surfaces/cursor/$name" "$stage_path"
    done
    if [ "$mode" = "--install-all" ]; then
      for source in "${persona_sources[@]}"; do
        relative=".cursor/agents/$(basename "$source")"
        will_replace "$relative" || continue
        stage_path="$staging/$relative"
        mkdir -p "$(dirname "$stage_path")"
        ln -s "$source" "$stage_path"
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
  for line in "${exclude_lines[@]}"; do
    probe="$(exclude_probe "$line")"
    git -C "$target" check-ignore -q -- "$probe" || {
      echo "refusing: $line was not excluded through info/exclude" >&2
      exit 1
    }
  done
}

declare -a installed=() removed=() kept=()

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

# Ignore only the exact Hatsu entries this invocation will own. Broad surface
# roots would hide an untracked user collision that the installer deliberately
# leaves alone.
collect_exclude_lines() {
  local name relative source
  exclude_lines=()
  if [ "$surface" = "codex" ]; then
    for name in "${skill_names[@]}"; do
      relative=".agents/skills/$name"
      will_replace "$relative" && exclude_lines+=("$relative")
    done
    if [ "$mode" = "--install-all" ] && will_replace_override; then
      exclude_lines+=('AGENTS.override.md')
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
    fi
  fi
}

# Validate every destination root, and the sole required bootstrap destination,
# before changing the shared ignore file or replacing a surface entry.
if [ "$surface" = "codex" ]; then
  ensure_local_directory '.agents/skills'
  if [ "$mode" = "--bootstrap" ]; then
    preflight_bootstrap_destination '.agents/skills/hatsu-warmup'
  fi
else
  ensure_local_directory '.cursor/skills'
  if [ "$mode" = "--install-all" ]; then
    ensure_local_directory '.cursor/agents'
  fi
  if [ "$mode" = "--bootstrap" ]; then
    preflight_bootstrap_destination '.cursor/skills/hatsu-warmup'
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
    remove_stale_skills "$target/.agents/skills"
  fi
  for name in "${skill_names[@]}"; do
    relative=".agents/skills/$name"
    destination="$target/$relative"
    source="$hatsu_root/surfaces/codex/$name"
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
  fi
else
  if [ "$mode" = "--install-all" ]; then
    remove_stale_skills "$target/.cursor/skills"
  fi
  for name in "${skill_names[@]}"; do
    relative=".cursor/skills/$name"
    destination="$target/$relative"
    source="$hatsu_root/surfaces/cursor/$name"
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
  fi
fi

printf 'surface bootstrap: %s %s — installed %s' "$surface" "${mode#--}" "${#installed[@]}"
if [ "${#removed[@]}" -gt 0 ]; then
  printf '; removed stale %s' "$(IFS=', '; echo "${removed[*]}")"
fi
if [ "${#kept[@]}" -gt 0 ]; then
  printf '; kept existing %s' "$(IFS=', '; echo "${kept[*]}")"
fi
printf '\n'
