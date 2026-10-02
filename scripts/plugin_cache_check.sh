#!/usr/bin/env bash
# plugin_cache_check.sh — is the Hatsu Claude Code serves the source it claims to be? (zheref/hatsu#122)
#
# THE GAP THIS CLOSES
# Claude Code serves Hatsu from a plugin cache (~/.claude/plugins/cache/hatsu/hatsu/<version>) copied
# from the marketplace source at install or update time, or from the first-party skills-directory
# install (~/.claude/skills/hatsu, usually a link to a checkout). Nothing compared that copy with a
# source: `nen surface mirror check --installed` judges a target `.claude/` layout Hatsu never places,
# so against the real cache it read every skill `missing` (docs/ab/ten.md), and `ten` § 5 recorded
# `mirrors: not applicable`. A stale copy served stale skills silently.
#
# A COPY IS NEVER ITS OWN EVIDENCE. `ten` § 0 resolves `--root` from the skill directory the harness
# hands over, which IS the served copy. Comparing a copy with itself proves nothing, so when a served
# copy and `--root` are the same path, the check looks for a source named independently of it, in
# order: $HATSU_PLUGIN_ROOT, the hatsu@<marketplace> entry's `directory` source in Claude Code's
# known_marketplaces.json, then the Hatsu checkout the caller stands in (the git toplevel of $PWD),
# but ONLY when that checkout is on its trunk (nen/workflow.json branch.base, else origin/HEAD, else
# main) or on the branch the served copy itself is checked out at: a feature worktree's tree is the
# change being authored, not what Claude Code should serve, and the warm-up's update (ten § 4b) moves
# the served checkout to the trunk, so judging it against a feature branch could never clear. The
# first one found is the source: when it IS the served copy (a link to that checkout), the copy is
# identical by link; otherwise the copy is compared with it. None found is NOT COMPARABLE (exit 4),
# never identical -- and a skipped feature-branch cwd is named in the verdict.
#
# WHAT IT COMPARES
# The shipped trees, file by file, byte for byte: claude/skills, claude/agents, claude/rules, hooks,
# templates, contracts, scripts, .claude-plugin/plugin.json and .claude-plugin/marketplace.json. A
# file only on one side, or with different bytes, is named. A symlink is never opened: two symlinks
# with the same target are equal, anything else is `differs (symlink)`. A name carrying a control
# character is never compared or printed raw (`unexpected`). `.DS_Store` is ignored on both sides.
#
# USAGE
#   scripts/plugin_cache_check.sh --root <hatsu source root> --cache <copy dir>
#   scripts/plugin_cache_check.sh --root <hatsu source root> --cache auto
#
# `--cache auto` judges every copy Claude Code has recorded for Hatsu: each installPath of each
# `hatsu@<marketplace>` entry in ${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/installed_plugins.json, and
# ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/hatsu when it exists. The record is read with jq; without
# jq it is reported unread and only skills/hatsu is judged -- never a wiring stop.
#
# EXIT CODES (auto mode reports the worst over every copy: 2 > 1 > 5 > 4 > 0)
#   0  identical (every compared file equal, none missing or extra), or served by link to the source
#   1  different -- every differing path named, prefixed by its side
#   2  wiring: a root that is not a Hatsu checkout, an explicit --cache that is not a Hatsu copy, an
#      unreadable file or directory (one find cannot list), a bad argument
#   3  not installed: no hatsu@ entry in the install record and no skills/hatsu at all
#   4  not comparable: a copy is the source root itself and no independent source was found (a cwd on
#      a feature branch is not one), or the record is unread (no jq) and there is no skills/hatsu to
#      judge instead
#   5  broken install: a hatsu@ entry with no usable installPath, a recorded path that is gone (a stale
#      record), a path carrying a control character, a dangling or looping skills/hatsu link
set -u

die() { echo "plugin_cache_check: $*" >&2; exit 2; }
usage() { sed -n '/^# USAGE/,/^# EXIT CODES/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
safe() { printf '%s' "$1" | LC_ALL=C tr '[:cntrl:]' '?'; }   # never print a control byte raw

root="" cache=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)  [ "$#" -ge 2 ] && [ -n "$2" ] || die "--root needs a path"; root="$2"; shift 2 ;;
    --cache) [ "$#" -ge 2 ] && [ -n "$2" ] || die "--cache needs a path or auto"; cache="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unexpected argument '$(safe "$1")'" ;;
  esac
done
[ -n "$root" ] || die "--root is required"
[ -n "$cache" ] || die "--cache is required (a path, or auto)"

# manifest_field FILE KEY -- the first "KEY": "value" in a plugin manifest, without jq
manifest_field() {
  [ -f "$1" ] || return 0
  awk -F'"' -v k="$2" '{ for (i = 1; i <= NF; i++) if ($i == k) { print $(i + 2); exit } }' "$1"
}
is_hatsu() {   # a Hatsu source tree: a manifest naming hatsu, and claude/skills
  [ -d "$1" ] && [ -f "$1/.claude-plugin/plugin.json" ] && [ -d "$1/claude/skills" ] \
    && [ "$(manifest_field "$1/.claude-plugin/plugin.json" name)" = hatsu ]
}
realdir() { ( cd "$1" 2>/dev/null && pwd -P ); }

is_hatsu "$root" || die "--root '$(safe "$root")' is not a Hatsu checkout (no .claude-plugin/plugin.json naming hatsu, or no claude/skills)"
root="$(realdir "$root")" || die "cannot resolve --root"

TREES="claude/skills claude/agents claude/rules hooks templates contracts scripts"
FILES=".claude-plugin/plugin.json .claude-plugin/marketplace.json"
work="$(mktemp -d)" || die "mktemp failed"
trap 'rm -rf "$work"' EXIT HUP INT TERM

# list_side BASE OUT -- every regular file and symlink under the compared trees, relative and sorted,
# names with a control character set aside in OUT.bad (one find per tree, NUL-safe)
list_side() {
  local base="$1" out="$2" t s0
  : > "$out"; : > "$out.bad"
  ( cd "$base" || exit 2
    rc=0
    for t in $TREES; do
      [ -e "$t" ] || continue
      find "$t" \( -type f -o -type l \) ! -name .DS_Store -print0 2>/dev/null || rc=2
    done
    for t in $FILES; do [ -e "$t" ] || [ -L "$t" ] && printf '%s\0' "$t"; done
    exit "$rc"
  ) | while IFS= read -r -d '' p; do
    case "$p" in
      *[[:cntrl:]]*) printf '%s\n' "$(safe "$p")" >> "$out.bad" ;;
      *) printf '%s\n' "$p" ;;
    esac
  done | LC_ALL=C sort > "$out.tmp"
  s0="${PIPESTATUS[0]}"
  if [ "$s0" != 0 ]; then
    echo "plugin_cache_check: unreadable: a directory under $(safe "$base") could not be listed" >&2
    return 2
  fi
  mv "$out.tmp" "$out"
}

# compare SRC COPY -- 0 identical, 1 different, 2 unreadable
compare() {
  local s="$1" c="$2" rc=0 p a b
  list_side "$s" "$work/src" || return 2
  list_side "$c" "$work/copy" || return 2
  [ -s "$work/src" ] || { echo "plugin_cache_check: the source listed no files" >&2; return 2; }
  while IFS= read -r p; do echo "unexpected:     $p (a name with a control character is never compared)"; rc=1; done < "$work/copy.bad"
  while IFS= read -r p; do echo "unexpected in source: $p (a name with a control character)"; rc=1; done < "$work/src.bad"
  while IFS= read -r p; do echo "only in source: $p"; rc=1; done < <(LC_ALL=C comm -23 "$work/src" "$work/copy")
  while IFS= read -r p; do echo "only in cache:  $p"; rc=1; done < <(LC_ALL=C comm -13 "$work/src" "$work/copy")
  while IFS= read -r p; do
    if [ -L "$s/$p" ] || [ -L "$c/$p" ]; then
      a="$(readlink "$s/$p" 2>/dev/null)"; b="$(readlink "$c/$p" 2>/dev/null)"
      if [ -L "$s/$p" ] && [ -L "$c/$p" ] && [ "$a" = "$b" ]; then continue; fi
      echo "differs:        $p (symlink; never opened)"; rc=1; continue
    fi
    if [ ! -f "$s/$p" ] || [ ! -f "$c/$p" ] || [ ! -r "$s/$p" ] || [ ! -r "$c/$p" ]; then
      echo "plugin_cache_check: unreadable: $p" >&2; return 2
    fi
    cmp -s "$s/$p" "$c/$p" || { echo "differs:        $p"; rc=1; }
  done < <(LC_ALL=C comm -12 "$work/src" "$work/copy")
  return "$rc"
}

# the record, read once (jq when present)
config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
record="$config/plugins/installed_plugins.json"
known="$config/plugins/known_marketplaces.json"
have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1

# trunk_of DIR -- the trunk of a checkout: nen/workflow.json branch.base (jq), else origin/HEAD, else main
trunk_of() {
  local d="$1" t=""
  [ "$have_jq" = 1 ] && [ -f "$d/nen/workflow.json" ] \
    && t="$(jq -r '.branch.base // empty | strings' "$d/nen/workflow.json" 2>/dev/null)"
  [ -n "$t" ] || { t="$(git -C "$d" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"; t="${t#origin/}"; }
  printf '%s' "${t:-main}"
}

# independent_source COPY -- print the first source named independently of the copy, and how; with
# none, return 1 and print the feature branch a cwd was skipped for, if one was
independent_source() {
  local c="$1" cand how mk p br served skipped=""
  for how in env marketplace cwd; do
    cand=""
    case "$how" in
      env) cand="${HATSU_PLUGIN_ROOT:-}" ;;
      marketplace)
        [ "$have_jq" = 1 ] && [ -f "$record" ] && [ -f "$known" ] || continue
        for mk in $(jq -r '.plugins // {} | keys[] | select(startswith("hatsu@")) | sub("^hatsu@"; "")' "$record" 2>/dev/null); do
          p="$(jq -r --arg m "$mk" '.[$m].source | select(.source == "directory") | .path // empty' "$known" 2>/dev/null)"
          case "$p" in *[[:cntrl:]]*) continue ;; esac
          [ -n "$p" ] && is_hatsu "$p" && { cand="$p"; break; }
        done ;;
      cwd)
        cand="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)"
        [ -n "$cand" ] || continue
        br="$(git -C "$cand" symbolic-ref --quiet --short HEAD 2>/dev/null)"
        served="$(git -C "$c" symbolic-ref --quiet --short HEAD 2>/dev/null)"
        if [ -z "$br" ] || { [ "$br" != "$(trunk_of "$cand")" ] && [ "$br" != "$served" ]; }; then
          skipped="${br:-a detached HEAD}"; continue
        fi ;;
    esac
    [ -n "$cand" ] && is_hatsu "$cand" || continue
    printf '%s\t%s\n' "$how" "$(realdir "$cand")"
    return 0
  done
  printf '%s' "$skipped"
  return 1
}

# judge COPY -- 0 identical, 1 different, 2 unreadable, 4 not comparable
judge() {
  local c="$1" src="$root" how="" ind rc sv cv skipped_cwd
  if [ "$c" = "$root" ]; then
    ind="$(independent_source "$c")" || { skipped_cwd="$ind"
      echo "plugin_cache_check: not comparable -- $(safe "$c") is the served copy AND the source given; no source named independently of it (HATSU_PLUGIN_ROOT, a directory marketplace, or a Hatsu checkout on its trunk as the working directory)${skipped_cwd:+; the working directory is on $(safe "$skipped_cwd"), a feature branch, which is the change being authored, not what should be served}"
      return 4; }
    how="${ind%%	*}"; src="${ind#*	}"
    if [ "$src" = "$c" ]; then
      if [ -e "$c/.git" ]; then
        echo "plugin_cache_check: identical -- $(safe "$c") is served by link to the source named by $how (a git checkout)"
        return 0
      fi
      echo "plugin_cache_check: not comparable -- $(safe "$c") is named by $how but is not a git checkout, so it is no independent source"
      return 4
    fi
  fi
  compare "$src" "$c"; rc=$?
  [ "$rc" -le 1 ] || return "$rc"
  sv="$(manifest_field "$src/.claude-plugin/plugin.json" version)"
  cv="$(manifest_field "$c/.claude-plugin/plugin.json" version)"
  if [ "$rc" -eq 0 ]; then
    echo "plugin_cache_check: identical -- $(safe "$c") (plugin ${cv:-?}) matches the source $(safe "$src")${how:+ (named by $how)} (plugin ${sv:-?})"
  else
    echo "plugin_cache_check: different -- $(safe "$c") (plugin ${cv:-?}) is not the source $(safe "$src")${how:+ (named by $how)} (plugin ${sv:-?}); refresh it (docs/SURFACES.md § 4)"
  fi
  return "$rc"
}

if [ "$cache" != auto ]; then
  case "$cache" in *[[:cntrl:]]*) die "--cache carries a control character" ;; esac
  [ -d "$cache" ] || die "cache '$(safe "$cache")' is not a directory"
  [ -f "$cache/.claude-plugin/plugin.json" ] || die "cache '$(safe "$cache")' holds no .claude-plugin/plugin.json"
  judge "$(realdir "$cache")"; exit $?
fi

rank() { case "$1" in 2) echo 5 ;; 1) echo 4 ;; 5) echo 3 ;; 4) echo 2 ;; 0) echo 1 ;; *) echo 6 ;; esac; }
worst=0 seen=0 judged=" "
note() { local code="$1"; seen=1; [ "$(rank "$code")" -gt "$(rank "$worst")" ] && worst="$code"; }
broken() { echo "plugin_cache_check: broken install -- $*"; note 5; }

judge_path() {   # judge_path PATH LABEL
  local p="$1" label="$2" r code
  if [ ! -e "$p" ] && [ ! -L "$p" ]; then broken "$label $(safe "$p") does not exist (a stale record)"; return; fi
  if [ -L "$p" ] && ! r="$(realdir "$p")"; then broken "$label $(safe "$p") is a dangling or looping link"; return; fi
  [ -d "$p" ] || { broken "$label $(safe "$p") is not a directory"; return; }
  r="$(realdir "$p")" || { broken "$label $(safe "$p") cannot be resolved"; return; }
  [ -f "$r/.claude-plugin/plugin.json" ] && [ -d "$r/claude/skills" ] \
    || { broken "$label $(safe "$p") holds no Hatsu plugin (.claude-plugin/plugin.json and claude/skills)"; return; }
  case "$judged" in *" $r "*) return ;; esac   # the same copy reached twice is judged once
  judged="$judged$r "
  judge "$r"; code=$?
  note "$code"
}

if [ -e "$record" ]; then
  if [ "$have_jq" = 1 ]; then
    entries="$(jq -r '
      .plugins // {} | to_entries[] | select(.key | startswith("hatsu@")) as $e
      | if ($e.value | type) != "array" or ($e.value | length) == 0 then "EMPTY\t\($e.key)"
        else $e.value[] | (.installPath // null) as $p
          | if ($p | type) != "string" or $p == "" then "EMPTY\t\($e.key)"
            elif ($p | explode | any(. < 32 or . == 127)) then "CNTRL\t\($e.key)"
            else "PATH\t\($e.key)\t\($p)" end end' "$record" 2>/dev/null)" \
      || { echo "plugin_cache_check: the install record $(safe "$record") is not readable as JSON"; note 5; entries=""; }
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      kind="${line%%	*}"; rest="${line#*	}"
      case "$kind" in
        EMPTY) broken "the $(safe "$rest") entry carries no usable installPath" ;;
        CNTRL) broken "the $(safe "$rest") entry's installPath carries a control character; never read" ;;
        PATH)  judge_path "${rest#*	}" "the ${rest%%	*} installPath" ;;
      esac
    done <<EOF
$entries
EOF
  else
    echo "plugin_cache_check: the install record is unread -- no jq; judging $(safe "$config")/skills/hatsu only"
    note 4
  fi
fi
# the first-party in-place install (bakuryuha): <config>/skills/hatsu, usually a link to a checkout
if [ -e "$config/skills/hatsu" ] || [ -L "$config/skills/hatsu" ]; then
  judge_path "$config/skills/hatsu" "skills/hatsu"
fi
if [ "$seen" = 0 ]; then
  echo "plugin_cache_check: not installed -- no hatsu@ entry in $(safe "$record") and no $(safe "$config")/skills/hatsu"
  exit 3
fi
exit "$worst"
