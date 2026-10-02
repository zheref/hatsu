#!/usr/bin/env bash
# plugin_cache_check.sh — tell a stale installed Claude Code copy of Hatsu from a fresh one
# (zheref/hatsu#122).
#
# THE GAP THIS CLOSES
# A marketplace install of Hatsu (`claude plugin install hatsu@hatsu`) COPIES the tree into
# ${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/cache/hatsu/hatsu/<version>/, even from a local directory,
# and a copy never refreshed keeps serving the skills it was copied with (#118's class). The only
# signal used to be the version string, and a same-version copy with different bytes was invisible.
# `nen surface mirror check --surface claude-code --installed <cache>` cannot see it either: nen's
# claude-code row diffs a target `.claude/` layout Hatsu never places, so against the real cache it
# reads every file `missing` (docs/ab/ten.md, #106). scripts/surface_mirror_check.sh --installed now
# refuses and names this script.
#
# WHAT IT DOES
# Byte-compares the installed copy against the SOURCE ROOT `ten` § 0 resolves (scripts/hatsu_root.sh,
# beside this file), over exactly what Claude Code loads from the plugin: claude/skills, claude/agents,
# hooks, templates, contracts and the manifests (.claude-plugin/). Every regular file and symlink is
# listed on both sides (find, sort, comm) and every common path is compared with cmp; nothing is
# written. .DS_Store is ignored. Bash 3.2, no python, no jq (BC-11).
#
# WHICH INSTALLED COPY, when --installed is not given — the one Claude Code actually serves:
#   1. installed_plugins.json records hatsu@hatsu → its installPath. An installed marketplace copy
#      SHADOWS the skills-directory link (docs/surfaces/claude-code.md § 9), so it is the one served.
#   2. else ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/hatsu — the in-place link bakuryuha § 3 makes
#      (scripts/hatsu_surface_link.sh --surface claude-code).
#   3. else nothing to check: exit 2, named.
# An installed surface that RESOLVES to the source root itself (the skills-directory link to the
# checkout) is identical by construction: said, exit 0, nothing compared.
#
# EXIT CODES
#   0  identical (or a link to the source itself) — last stdout line `plugin-cache: current` or
#      `plugin-cache: linked (identical by construction)`
#   1  different — every path named as `differs:`, `missing:` (in the source, not installed) or
#      `extra:` (installed, not in the source); last stdout line `plugin-cache: stale (<n> paths)`
#   2  wiring defect — no source root, a source root that is itself a plugin cache, no installed copy,
#      an installed path that is not a Hatsu tree (a cache's parent directory, say), an unknown flag
#
# USAGE
#   scripts/plugin_cache_check.sh [--installed <path>] [--root <checkout>]
#   scripts/plugin_cache_check.sh --self-test
set -euo pipefail
LC_ALL=C
export LC_ALL

SETS="claude/skills claude/agents hooks templates contracts .claude-plugin"
script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
cleanup_dir=""; tmp=""
nl="$(printf '\nx')"; nl="${nl%x}"

die2() { printf 'plugin-cache-check: %s\n' "$*" >&2; exit 2; }

# canon DIR — absolute, symlinks resolved; non-zero when DIR cannot be entered.
canon() { (CDPATH='' cd -P -- "$1" >/dev/null 2>&1 && pwd -P); }

# manifest_field FILE KEY — a top-level string member of a plugin manifest in the one shape the
# tooling writes (two-space indent); empty when absent.
manifest_field() {
  [ -f "$1" ] || return 0
  awk -v k="$2" 'index($0, "  \"" k "\": \"") == 1 { s = substr($0, length(k) + 8); sub(/".*$/, "", s); print s; exit }' "$1"
}

is_hatsu_tree() {
  [ -f "$1/.claude-plugin/plugin.json" ] && [ -d "$1/claude/skills" ] &&
    [ "$(manifest_field "$1/.claude-plugin/plugin.json" name)" = hatsu ]
}

# detect_installed CONFIG_DIR — sets inst and inst_how to the copy Claude Code serves, or leaves
# inst empty.
detect_installed() {
  local cfg="$1" f="$1/plugins/installed_plugins.json" p=""
  if [ -f "$f" ]; then
    p="$(awk '
      /"hatsu@hatsu"[[:space:]]*:/ { a = 1; next }
      a && /"installPath"[[:space:]]*:/ { s = $0; sub(/^[^"]*"installPath"[[:space:]]*:[[:space:]]*"/, "", s); sub(/".*$/, "", s); print s; exit }
      a && /^[[:space:]]*\]/ { exit }
    ' "$f")"
  fi
  if [ -n "$p" ]; then
    inst="$p"; inst_how="hatsu@hatsu from installed_plugins.json, which shadows any skills-directory link"
  elif [ -e "$cfg/skills/hatsu" ] || [ -L "$cfg/skills/hatsu" ]; then
    inst="$cfg/skills/hatsu"; inst_how="the skills-directory install, hatsu@skills-dir"
  fi
}

# list_files BASE OUT — every regular file and symlink under BASE's compared sets, relative, sorted.
list_files() {
  local base="$1" out="$2" set
  : > "$out.unsorted"
  for set in $SETS; do
    [ -e "$base/$set" ] || continue
    if [ -n "$(cd "$base" && find "$set" -name "*$nl*" -print 2>/dev/null | head -c 1)" ]; then
      die2 "a path under $base/$set carries a newline; refused rather than mis-listed"
    fi
    (cd "$base" && find "$set" \( -type f -o -type l \) ! -name .DS_Store -print) >> "$out.unsorted" ||
      die2 "could not list $base/$set"
  done
  sort -u "$out.unsorted" > "$out"
  rm -f "$out.unsorted"
}

check() {
  local root_arg="" inst_arg="" root root_c inst="" inst_how="" inst_c link="" vr vi
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --root) [ "$#" -ge 2 ] || die2 "--root requires a path"; root_arg="$2"; shift 2 ;;
      --installed) [ "$#" -ge 2 ] || die2 "--installed requires a path"; inst_arg="$2"; shift 2 ;;
      -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
      *) die2 "unknown argument '$1' (usage: [--installed <path>] [--root <checkout>] | --self-test)" ;;
    esac
  done

  # The source root: the one ten § 0 resolves, unless named.
  if [ -n "$root_arg" ]; then
    root="$root_arg"
  else
    root="$("$script_dir/hatsu_root.sh")" ||
      die2 "ten § 0's resolver found no source root (its reason is above); export HATSU_PLUGIN_ROOT='<checkout>' or pass --root"
  fi
  root_c="$(canon "$root")" || die2 "source root '$root' is not a directory"
  is_hatsu_tree "$root_c" || die2 "source root '$root' is not a Hatsu checkout (no .claude-plugin/plugin.json naming hatsu beside claude/skills/)"
  case "$root_c" in
    */plugins/cache/*) die2 "the source root resolved to a plugin cache ($root_c), not a checkout — a copy cannot judge a copy; export HATSU_PLUGIN_ROOT='<checkout>' or pass --root" ;;
  esac

  # The installed copy.
  if [ -n "$inst_arg" ]; then
    inst="$inst_arg"; inst_how="named by --installed"
  else
    detect_installed "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    [ -n "$inst" ] || die2 "no installed Hatsu under ${CLAUDE_CONFIG_DIR:-$HOME/.claude} (installed_plugins.json records no hatsu@hatsu and skills/hatsu is absent); pass --installed <path>"
  fi
  if [ -L "$inst" ]; then link="$(readlink "$inst" 2>/dev/null || printf '<unreadable>')"; fi
  inst_c="$(canon "$inst")" || die2 "installed path '$inst' ($inst_how) does not resolve to a directory${link:+ (a link to $link)}"

  if [ "$inst_c/." -ef "$root_c/." ]; then
    echo "plugin-cache-check: $inst ($inst_how) resolves to the source checkout itself ($root_c): nothing is copied, so nothing can be stale. Whatever that checkout holds is what is served (docs/surfaces/claude-code.md § 1)."
    echo "plugin-cache: linked (identical by construction)"
    return 0
  fi
  if ! is_hatsu_tree "$inst_c"; then
    local versions="" d
    for d in "$inst_c"/*; do
      [ -d "$d" ] && is_hatsu_tree "$d" && versions="$versions ${d##*/}"
    done
    die2 "installed path '$inst' is not an installed Hatsu (no .claude-plugin/plugin.json naming hatsu beside claude/skills/)${versions:+; it holds the versions$versions — name one of them}"
  fi

  vr="$(manifest_field "$root_c/.claude-plugin/plugin.json" version)"
  vi="$(manifest_field "$inst_c/.claude-plugin/plugin.json" version)"
  echo "plugin-cache-check: source $root_c (v${vr:-?}) · installed $inst${link:+ → $link} (v${vi:-?}, $inst_how)"
  echo "  compared: $SETS"

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/plugin-cache-check.XXXXXX")"; cleanup_dir="$tmp"
  trap 'rm -rf "${cleanup_dir:-}"' EXIT
  list_files "$root_c" "$tmp/src"
  list_files "$inst_c" "$tmp/inst"

  local p n_diff=0 n_miss=0 n_extra=0 n_same=0
  while IFS= read -r p; do
    if cmp -s "$root_c/$p" "$inst_c/$p"; then n_same=$((n_same + 1)); else echo "  differs: $p"; n_diff=$((n_diff + 1)); fi
  done < <(comm -12 "$tmp/src" "$tmp/inst")
  while IFS= read -r p; do echo "  missing: $p"; n_miss=$((n_miss + 1)); done < <(comm -23 "$tmp/src" "$tmp/inst")
  while IFS= read -r p; do echo "  extra: $p"; n_extra=$((n_extra + 1)); done < <(comm -13 "$tmp/src" "$tmp/inst")

  local total=$((n_diff + n_miss + n_extra))
  if [ "$total" -eq 0 ]; then
    echo "plugin-cache-check: the installed copy matches the source, $n_same files byte for byte."
    echo "plugin-cache: current"
    return 0
  fi
  echo "plugin-cache-check: the installed copy is NOT the source: $n_diff differ, $n_miss missing, $n_extra extra ($n_same identical)." >&2
  if [ -n "$vr" ] && [ "$vr" = "$vi" ]; then
    echo "  Same version (v$vr), different bytes: a stale same-version copy (zheref/hatsu#118's class), which the version string alone never shows." >&2
  fi
  echo "  Refresh it: hatsu:bakuryuha moves Claude Code onto the in-place link (docs/surfaces/claude-code.md § 1); on a host that keeps the cache, scripts/hatsu_plugin_update.sh --claude." >&2
  echo "plugin-cache: stale ($total paths)"
  return 1
}

# --- self-test: hermetic, offline, throwaway trees under mktemp ------------------------------------
self_test() {
  local fx self code out
  fx="$(mktemp -d "${TMPDIR:-/tmp}/plugin-cache-check-selftest.XXXXXX")"
  fx="$(canon "$fx")"; cleanup_dir="$fx"
  trap 'rm -rf "${cleanup_dir:-}"' EXIT
  self="$script_dir/$(basename -- "$0")"

  fail() { echo "plugin-cache-check self-test: $*" >&2; exit 1; }
  mktree() { # mktree DIR VERSION
    mkdir -p "$1/.claude-plugin" "$1/claude/skills/ten" "$1/claude/agents" "$1/hooks" "$1/templates" "$1/contracts" "$1/docs"
    printf '{\n  "name": "hatsu",\n  "version": "%s"\n}\n' "$2" > "$1/.claude-plugin/plugin.json"
    printf '# ten\nbody\n' > "$1/claude/skills/ten/SKILL.md"
    printf '# kurapika\n' > "$1/claude/agents/kurapika.md"
    printf '{}\n' > "$1/hooks/hooks.json"
    printf 'tpl\n' > "$1/templates/report.html"
    printf '{}\n' > "$1/contracts/permissions.json"
    printf 'not compared\n' > "$1/docs/notes.md"
  }
  # run NAME EXPECTED ARGS... — runs the check from $fx (not a git tree) with a clean environment.
  run() {
    local name="$1" expected="$2"; shift 2
    code=0
    out="$(cd "$fx" && env -u HATSU_PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT CLAUDE_CONFIG_DIR="$fx/cfg-none" "$@" 2>&1)" || code=$?
    [ "$code" -eq "$expected" ] || fail "$name: exit $code, expected $expected. Output: $out"
  }
  has() { case "$2" in *"$3"*) ;; *) fail "$1: expected '$3' in: $2" ;; esac; }
  hasnt() { case "$2" in *"$3"*) fail "$1: did not expect '$3' in: $2" ;; *) ;; esac; }
  fresh() { rm -rf "$fx/inst"; cp -R "$fx/src" "$fx/inst"; }

  mktree "$fx/src" 1.2.0

  fresh; run identical 0 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has identical "$out" 'plugin-cache: current'

  fresh; printf 'old body\n' > "$fx/inst/claude/skills/ten/SKILL.md"
  run one-differs 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has one-differs "$out" 'differs: claude/skills/ten/SKILL.md'
  has one-differs "$out" 'plugin-cache: stale (1 paths)'
  has one-differs "$out" 'Same version (v1.2.0)'

  fresh; rm "$fx/inst/claude/agents/kurapika.md"
  run one-missing 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has one-missing "$out" 'missing: claude/agents/kurapika.md'

  fresh; printf 'gone\n' > "$fx/inst/hooks/retired.sh"
  run one-extra 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has one-extra "$out" 'extra: hooks/retired.sh'

  # #118's class: the manifest is byte-identical (same version), a template is not.
  fresh; printf 'tpl v2\n' > "$fx/src/templates/report.html"
  run same-version-bytes 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has same-version-bytes "$out" 'differs: templates/report.html'
  has same-version-bytes "$out" 'a stale same-version copy'
  hasnt same-version-bytes "$out" '.claude-plugin/plugin.json'
  printf 'tpl\n' > "$fx/src/templates/report.html"

  # A file outside the compared sets never counts; a newer version is named but not "same version".
  fresh; printf 'other\n' > "$fx/inst/docs/notes.md"
  run outside-sets 0 bash "$self" --root "$fx/src" --installed "$fx/inst"
  fresh; printf '{\n  "name": "hatsu",\n  "version": "1.1.0"\n}\n' > "$fx/inst/.claude-plugin/plugin.json"
  run older-version 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has older-version "$out" 'differs: .claude-plugin/plugin.json'
  hasnt older-version "$out" 'Same version'

  # Wiring defects.
  fresh; run missing-root 2 bash "$self" --root "$fx/nope" --installed "$fx/inst"
  has missing-root "$out" "source root '$fx/nope' is not a directory"
  run no-resolvable-root 2 bash "$self" --installed "$fx/inst"
  has no-resolvable-root "$out" "ten § 0's resolver found no source root"
  mkdir -p "$fx/cache-parent/1.2.0" && cp -R "$fx/src/." "$fx/cache-parent/1.2.0/"
  run cache-parent 2 bash "$self" --root "$fx/src" --installed "$fx/cache-parent"
  has cache-parent "$out" 'it holds the versions 1.2.0'
  mkdir -p "$fx/plugins/cache/hatsu/hatsu" && cp -R "$fx/src" "$fx/plugins/cache/hatsu/hatsu/1.2.0"
  run root-is-cache 2 bash "$self" --root "$fx/plugins/cache/hatsu/hatsu/1.2.0" --installed "$fx/inst"
  has root-is-cache "$out" 'resolved to a plugin cache'
  run unknown-flag 2 bash "$self" --bogus

  # The symlinked install: a link to the source checkout itself is identical by construction.
  ln -s "$fx/src" "$fx/link"
  run symlinked-install 0 bash "$self" --root "$fx/src" --installed "$fx/link"
  has symlinked-install "$out" 'plugin-cache: linked (identical by construction)'

  # The root ten § 0 resolves ($HATSU_PLUGIN_ROOT here), and the auto-detected install.
  mkdir -p "$fx/cfg/skills" && ln -s "$fx/src" "$fx/cfg/skills/hatsu"
  run detected-link 0 env HATSU_PLUGIN_ROOT="$fx/src" CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  has detected-link "$out" 'hatsu@skills-dir'
  has detected-link "$out" 'plugin-cache: linked'
  fresh; printf 'old body\n' > "$fx/inst/claude/skills/ten/SKILL.md"
  mkdir -p "$fx/cfg/plugins"
  printf '{\n  "version": 2,\n  "plugins": {\n    "hatsu@hatsu": [\n      {\n        "scope": "user",\n        "installPath": "%s"\n      }\n    ]\n  }\n}\n' "$fx/inst" > "$fx/cfg/plugins/installed_plugins.json"
  run detected-shadowing-cache 1 env HATSU_PLUGIN_ROOT="$fx/src" CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  has detected-shadowing-cache "$out" 'shadows any skills-directory link'
  has detected-shadowing-cache "$out" 'differs: claude/skills/ten/SKILL.md'
  run detected-nothing 2 env HATSU_PLUGIN_ROOT="$fx/src" CLAUDE_CONFIG_DIR="$fx/cfg-empty" bash "$self"
  has detected-nothing "$out" 'no installed Hatsu under'

  echo 'plugin-cache-check self-test: ok (identical, one differs, one missing, one extra, same-version bytes, outside the sets, older version, missing root, unresolvable root, cache parent, root is a cache, unknown flag, symlinked install, detected link, detected shadowing cache, nothing detected)'
}

if [ "${1:-}" = --self-test ]; then
  [ "$#" -eq 1 ] || die2 "--self-test takes no other argument"
  self_test
else
  check "$@"
fi
