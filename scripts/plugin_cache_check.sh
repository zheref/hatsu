#!/usr/bin/env bash
# plugin_cache_check.sh — tell a stale installed Claude Code copy of Hatsu from a fresh one
# (zheref/hatsu#122).
#
# THE GAP THIS CLOSES
# A marketplace install of Hatsu (`claude plugin install hatsu@hatsu`) COPIES the tree into
# ${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/cache/hatsu/hatsu/<version>/, even from a local directory,
# and a copy never refreshed keeps serving what it was copied with (#118's class). The only signal
# used to be the version string, and a same-version copy with different bytes was invisible.
# `nen surface mirror check --surface claude-code --installed <cache>` cannot see it either: nen's
# claude-code row diffs a target `.claude/` layout Hatsu never places, so against the real cache it
# reads every file `missing` (docs/ab/ten.md, #106). scripts/surface_mirror_check.sh --installed
# refuses and names this script.
#
# WHAT IT COMPARES — the WHOLE plugin tree, minus an explicit ignore list, so a directory the served
# copy starts loading can never fall outside the check: the skills, personas, commands and rules, the
# hooks AND the scripts they execute from the plugin root, nen/contract.json's pin, templates,
# contracts, docs, the manifests. Ignored, each for a stated reason:
#   .git                  the checkout's own repository; a cache has none
#   .nen  Reports         run-local state and reports, git-ignored; copies carry stale residue
#   .claude  .cursor  .codex  .agents  .gemini
#                         a checkout's own harness state and warm-up placements (.claude/worktrees
#                         holds whole other checkouts); none is plugin content
#   surfaces              the other surfaces' generated mirrors; Claude Code never loads them
#   node_modules          never Hatsu's
#   .orphaned_at          Claude Code's marker on a superseded cache version
#   .DS_Store             Finder's, any depth (a FILE of that name; a directory of it is compared)
# Every other entry that is not a directory is listed on both sides (find, sort, comm). For a path
# on both sides the TYPE is compared first (a symlink against a regular file is `differs … (type)`;
# two symlinks compare their link strings, never what they point at; anything else — a FIFO, a
# device — is reported and never opened); for two regular files the executable bit (hooks.json runs
# hook scripts directly, so a lost x bit is a broken hook: `(mode)`) and then the bytes with cmp.
# Nothing is written. Bash 3.2, no python, no jq (BC-11).
#
# THE SOURCE ROOT is the one ten § 0 resolves: scripts/hatsu_root.sh, handed THIS script's own
# plugin root as its candidate 2 exactly as ten § 0 hands it the loaded skill directory, so a § 5
# call that never exported $hatsu_root still resolves one. --root names it outright. A root that is
# a copy — a path under */plugins/cache/*, or the same directory (-ef) as any installPath the
# registry records, however a symlink relocated it — is refused: a copy cannot judge a copy.
#
# WHICH INSTALLED COPY, when --installed is not given — the one Claude Code serves:
#   1. installed_plugins.json (${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/) records a `hatsu@<any
#      marketplace>` entry → its installPath. An INSTALLED marketplace copy shadows the
#      skills-directory link (docs/surfaces/claude-code.md § 9's precedence line; § 8 records that
#      bakuryuha reads `enabled` from `claude plugin list --json` instead). Of several entries, the
#      most specific scope that applies here wins — `local`, then `project`, each only when its
#      projectPath is this checkout (the git toplevel of $PWD), then `user` (or no scope); two at the
#      winning scope is refused as ambiguous. An empty array is "not installed".
#      The registry is read in the ONE shape Claude Code writes (two-space-indented JSON, the v2
#      `"plugins": { "<id>": [ { … } ] }` layout scripts/hatsu_plugin_update.sh reads). A file that
#      mentions `"hatsu@` in any other shape — minified, truncated, an entry with no installPath — is
#      REFUSED at exit 2, never read as "not installed" (which would fall back to the link and
#      report it current while a stale copy shadows it).
#      A chosen installPath that does not resolve is refused at exit 2 too, rather than assuming the
#      link serves instead: the registry still claims the copy, and guessing would hide a shadow.
#   2. else ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/hatsu — the in-place link bakuryuha § 3 makes
#      (scripts/hatsu_surface_link.sh --surface claude-code).
#   3. else nothing to check: exit 2, named.
#
# EXIT CODES — the last stdout line is the verdict ten § 5 quotes, or there is none
#   0  `plugin-cache: linked (identical by construction)` — the install resolves to the source root
#      `plugin-cache: current` — a copy, byte-identical to the source
#   1  `plugin-cache: stale (<n> paths)` — each path named `differs:` (with `(type)`, `(link)` or
#      `(mode)` where that is the difference), `missing:` (in the source, not installed) or
#      `extra:` (installed, not in the source)
#      `plugin-cache: linked to <target> (not <root>)` — a link to ANOTHER checkout: it serves that
#      checkout's branch, not the root this session resolved
#   2  a wiring defect, the reason on stderr and no `plugin-cache:` line — also any unexpected
#      failure, so a crash can never read as `stale`
#
# USAGE
#   scripts/plugin_cache_check.sh [--installed <path>] [--root <checkout>]
#   scripts/plugin_cache_check.sh --self-test
set -euo pipefail
LC_ALL=C
export LC_ALL

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
cleanup_dir=""
finished=""

# Any exit that is not a deliberate verdict (0, or 1 with $finished set) or a die2 becomes exit 2.
# shellcheck disable=SC2329 # invoked by the EXIT trap
on_exit() {
  local rc=$?
  [ -z "$cleanup_dir" ] || rm -rf "$cleanup_dir"
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ] && [ -z "$finished" ]; then
    printf 'plugin-cache-check: unexpected failure (exit %s) — a wiring defect, not a verdict\n' "$rc" >&2
    exit 2
  fi
}
trap on_exit EXIT

die2() { printf 'plugin-cache-check: %s\n' "$*" >&2; exit 2; }
safe() { printf '%s' "$1" | tr -cd '[:print:]'; }

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

# read_registry FILE — prints one `id<TAB>scope<TAB>projectPath<TAB>installPath` line per recorded
# hatsu@<any> entry. Exit 0 read (possibly no entries), 3 a shape this check cannot read.
read_registry() {
  awk '
    function val(line, key,   s) {
      if (line !~ ("^        \"" key "\": \"[^\"\\\\]*\",?$")) { bad = 1; return "" }
      s = line; sub("^        \"" key "\": \"", "", s); sub(/",?$/, "", s); return s
    }
    /^    "hatsu@[^"]*": \[\],?$/ { seen++; next }
    /^    "hatsu@[^"]*": \[$/ { if (inb) bad = 1; inb = 1; seen++; id = $0; sub(/^    "/, "", id); sub(/": \[$/, "", id); next }
    inb && /^    \],?$/ { if (ine) bad = 1; inb = 0; next }
    inb && /^      \{$/ { if (ine) bad = 1; ine = 1; sc = ""; pp = ""; ip = ""; next }
    inb && ine && /^      \},?$/ { ine = 0; if (ip == "") bad = 1; else print id "\t" sc "\t" pp "\t" ip; next }
    inb && ine && /^        "installPath":/ { ip = val($0, "installPath"); next }
    inb && ine && /^        "scope":/ { sc = val($0, "scope"); next }
    inb && ine && /^        "projectPath":/ { pp = val($0, "projectPath"); next }
    /"hatsu@/ && !inb { bad = 1 }
    END { if (inb || ine || bad || !seen) exit 3 }
  ' "$1"
}

# list_files BASE OUT — every non-directory under BASE outside the ignore list, relative, sorted.
PRUNE='( -path ./.git -o -path ./.nen -o -path ./Reports -o -path ./.claude -o -path ./.cursor -o -path ./.codex -o -path ./.agents -o -path ./.gemini -o -path ./surfaces -o -path ./node_modules ) -prune'
list_files() {
  local base="$1" out="$2" bad
  # shellcheck disable=SC2086 # $PRUNE is a deliberate word list of find primaries
  bad="$(cd "$base" && find . $PRUNE -o -name '*[[:cntrl:]]*' -print 2>/dev/null | head -n 1 | tr -cd '[:print:]' || true)"  # an unreadable dir is the listing's to name
  [ -z "$bad" ] || die2 "a path under $(safe "$base") carries a newline or another control byte (${bad}); refused rather than mis-listed"
  # shellcheck disable=SC2086
  (cd "$base" && find . $PRUNE -o ! -type d ! -name .DS_Store ! -path ./.orphaned_at -print) > "$out.unsorted" ||
    die2 "could not list $(safe "$base") (an unreadable directory?)"
  sed 's|^\./||' "$out.unsorted" | sort -u > "$out"
  rm -f "$out.unsorted"
}

# compare_one PATH — prints the difference suffix for a path present on both sides, or nothing.
compare_one() {
  local a="$root_c/$1" b="$inst_c/$1" ta=O tb=O
  if [ -L "$a" ]; then ta=L; elif [ -f "$a" ]; then ta=F; fi
  if [ -L "$b" ]; then tb=L; elif [ -f "$b" ]; then tb=F; fi
  if [ "$ta" != "$tb" ]; then printf ' (type)'; return; fi
  case "$ta" in
    O) printf ' (type: not a regular file or link, not opened)'; return ;;
    L) [ "$(readlink "$a")" = "$(readlink "$b")" ] || printf ' (link)'; return ;;
  esac
  local m="" c="" xa=0 xb=0
  if [ -x "$a" ]; then xa=1; fi
  if [ -x "$b" ]; then xb=1; fi
  [ "$xa" -eq "$xb" ] || m="mode"
  cmp -s "$a" "$b" || c="content"
  if [ -n "$m" ] && [ -n "$c" ]; then printf ' (mode, content)'; elif [ -n "$m" ]; then printf ' (mode)'; elif [ -n "$c" ]; then printf ' '; fi
}

verdict() { # CODE LINE — the last stdout line, then exit
  echo "$2"
  finished=1
  exit "$1"
}

check() {
  local root_arg="" inst_arg="" root inst="" inst_how="" link="" vr vi tmp
  local cfg reg entries="" reg_state="absent" e id sc pp ip ctx best=0 tier n_best=0 chosen=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --root) [ "$#" -ge 2 ] || die2 "--root requires a path"; root_arg="$2"; shift 2 ;;
      --installed) [ "$#" -ge 2 ] || die2 "--installed requires a path"; inst_arg="$2"; shift 2 ;;
      -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; finished=1; exit 0 ;;
      *) die2 "unknown argument '$(safe "$1")' (usage: [--installed <path>] [--root <checkout>] | --self-test)" ;;
    esac
  done

  # The registry, read first: the root's copy-identity test needs every installPath it records.
  cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  reg="$cfg/plugins/installed_plugins.json"
  if [ -f "$reg" ] && grep -q '"hatsu@' "$reg" 2>/dev/null; then
    if entries="$(read_registry "$reg")"; then reg_state="read"; else entries=""; reg_state="unreadable"; fi
  fi
  if [ "$reg_state" = unreadable ] && [ -z "$inst_arg" ]; then
    die2 "$(safe "$reg") records a hatsu@ install in a shape this check cannot read (it reads Claude Code's own two-space-indented v2 layout only); refused rather than read as not installed — pass --installed <path>"
  fi

  # The source root: the one ten § 0 resolves, handed this script's own plugin root, unless named.
  if [ -n "$root_arg" ]; then
    root="$root_arg"
  else
    root="$("$script_dir/hatsu_root.sh" "$script_dir/..")" ||
      die2 "ten § 0's resolver found no source root (its reason is above); export HATSU_PLUGIN_ROOT='<checkout>' or pass --root"
  fi
  root_c="$(canon "$root")" || die2 "source root '$(safe "$root")' is not a directory"
  is_hatsu_tree "$root_c" || die2 "source root '$(safe "$root")' is not a Hatsu checkout (no .claude-plugin/plugin.json naming hatsu beside claude/skills/)"
  case "$root/:$root_c/" in
    */plugins/cache/*) die2 "the source root resolved to a plugin cache ($(safe "$root_c")), not a checkout — a copy cannot judge a copy; export HATSU_PLUGIN_ROOT='<checkout>' or pass --root" ;;
  esac
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    ip="${e##*	}"
    if [ -d "$ip" ] && [ "$root_c/." -ef "$ip/." ]; then
      die2 "the source root ($(safe "$root_c")) is the copy installed_plugins.json records at $(safe "$ip") — a copy cannot judge a copy; export HATSU_PLUGIN_ROOT='<checkout>' or pass --root"
    fi
  done <<EOF
$entries
EOF
  [ "$reg_state" != unreadable ] || echo "plugin-cache-check: note — $(safe "$reg") was not readable, so the copy-identity test used the path alone" >&2

  # The installed copy.
  if [ -n "$inst_arg" ]; then
    inst="$inst_arg"; inst_how="named by --installed"
  else
    ctx="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      id="${e%%	*}"; e="${e#*	}"; sc="${e%%	*}"; e="${e#*	}"; pp="${e%%	*}"; ip="${e#*	}"
      case "$sc" in
        local|project) if [ -n "$pp" ] && [ -d "$pp" ] && [ "$pp/." -ef "$ctx/." ]; then
                         if [ "$sc" = local ]; then tier=3; else tier=2; fi; else tier=0; fi ;;
        user|managed|"") tier=1 ;;
        *) tier=0 ;;
      esac
      [ "$tier" -gt 0 ] || continue
      if [ "$tier" -gt "$best" ]; then best=$tier; n_best=1; chosen="$id	$sc	$ip"
      elif [ "$tier" -eq "$best" ]; then n_best=$((n_best + 1)); chosen="$chosen
$id	$sc	$ip"; fi
    done <<EOF
$entries
EOF
    if [ "$n_best" -gt 1 ]; then
      die2 "installed_plugins.json records $n_best hatsu entries at the same scope for this checkout ($(printf '%s' "$chosen" | tr '\n\t' '; ' | tr -cd '[:print:]')); ambiguous — pass --installed <path>"
    fi
    if [ "$n_best" -eq 1 ]; then
      id="${chosen%%	*}"; sc="${chosen#*	}"; sc="${sc%%	*}"; inst="${chosen##*	}"
      inst_how="$id (${sc:-no} scope) from installed_plugins.json — an installed copy shadows the skills-directory link (docs/surfaces/claude-code.md § 8)"
      [ -d "$inst" ] || die2 "installed_plugins.json records $id at $(safe "$inst"), which does not resolve to a directory; refused rather than assume $(safe "$cfg")/skills/hatsu serves instead — reinstall or uninstall $id (hatsu:bakuryuha § 3)"
    elif [ -e "$cfg/skills/hatsu" ] || [ -L "$cfg/skills/hatsu" ]; then
      inst="$cfg/skills/hatsu"; inst_how="the skills-directory install, hatsu@skills-dir"
    else
      die2 "no installed Hatsu under $(safe "$cfg") (installed_plugins.json records no hatsu@ entry for this checkout and skills/hatsu is absent); pass --installed <path>"
    fi
  fi
  if [ -L "$inst" ]; then link="$(readlink "$inst" 2>/dev/null || printf '<unreadable>')"; fi
  inst_c="$(canon "$inst")" || die2 "installed path '$(safe "$inst")' ($inst_how) does not resolve to a directory${link:+ (a link to $(safe "$link"))}"

  if [ "$inst_c/." -ef "$root_c/." ]; then
    echo "plugin-cache-check: $(safe "$inst") ($inst_how) resolves to the source checkout itself ($(safe "$root_c")): nothing is copied, so nothing can be stale. Whatever that checkout holds is what is served (docs/surfaces/claude-code.md § 1)."
    verdict 0 "plugin-cache: linked (identical by construction)"
  fi
  if ! is_hatsu_tree "$inst_c"; then
    local versions="" d
    for d in "$inst_c"/*; do
      if [ -d "$d" ] && is_hatsu_tree "$d"; then versions="$versions ${d##*/}"; fi
    done
    die2 "installed path '$(safe "$inst")' is not an installed Hatsu (no .claude-plugin/plugin.json naming hatsu beside claude/skills/)${versions:+; it holds the versions$(safe "$versions") — name one of them}"
  fi
  if [ -n "$link" ]; then
    case "$inst_c/" in
      */plugins/cache/*) ;;
      *)
        echo "plugin-cache-check: $(safe "$inst") ($inst_how) is a link to another checkout, $(safe "$inst_c"), not the source root $(safe "$root_c"). The link serves $(safe "$inst_c")'s branch as it stands (docs/surfaces/claude-code.md § 1); point it at the root with hatsu:bakuryuha, or bind that checkout with export HATSU_PLUGIN_ROOT." >&2
        verdict 1 "plugin-cache: linked to $(safe "$inst_c") (not $(safe "$root_c"))"
        ;;
    esac
  fi

  vr="$(manifest_field "$root_c/.claude-plugin/plugin.json" version)"
  vi="$(manifest_field "$inst_c/.claude-plugin/plugin.json" version)"
  echo "plugin-cache-check: source $(safe "$root_c") (v$(safe "${vr:-?}")) · installed $(safe "$inst")${link:+ → $(safe "$link")} (v$(safe "${vi:-?}"), $inst_how)"
  echo "  compared: the whole tree, minus .git .nen Reports .claude .cursor .codex .agents .gemini surfaces node_modules .orphaned_at .DS_Store"

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/plugin-cache-check.XXXXXX")"; cleanup_dir="$tmp"
  list_files "$root_c" "$tmp/src"
  list_files "$inst_c" "$tmp/inst"
  comm -12 "$tmp/src" "$tmp/inst" > "$tmp/both"
  comm -23 "$tmp/src" "$tmp/inst" > "$tmp/missing"
  comm -13 "$tmp/src" "$tmp/inst" > "$tmp/extra"

  local p how n_diff=0 n_miss=0 n_extra=0 n_same=0
  while IFS= read -r p; do
    how="$(compare_one "$p")"
    if [ -z "$how" ]; then n_same=$((n_same + 1)); else echo "  differs: $(safe "$p")${how% }"; n_diff=$((n_diff + 1)); fi
  done < "$tmp/both"
  while IFS= read -r p; do echo "  missing: $(safe "$p")"; n_miss=$((n_miss + 1)); done < "$tmp/missing"
  while IFS= read -r p; do echo "  extra: $(safe "$p")"; n_extra=$((n_extra + 1)); done < "$tmp/extra"

  local total=$((n_diff + n_miss + n_extra))
  if [ "$total" -eq 0 ]; then
    echo "plugin-cache-check: the installed copy matches the source, $n_same files."
    verdict 0 "plugin-cache: current"
  fi
  echo "plugin-cache-check: the installed copy is NOT the source: $n_diff differ, $n_miss missing, $n_extra extra ($n_same identical)." >&2
  if [ -n "$vr" ] && [ "$vr" = "$vi" ]; then
    echo "  Same version (v$(safe "$vr")), different bytes: a stale same-version copy (zheref/hatsu#118's class), which the version string alone never shows." >&2
  fi
  echo "  Refresh it: hatsu:bakuryuha moves Claude Code onto the in-place link (docs/surfaces/claude-code.md § 1); on a host that keeps the cache, scripts/hatsu_plugin_update.sh --auto --claude (ten § 4b)." >&2
  verdict 1 "plugin-cache: stale ($total paths)"
}

# --- self-test: hermetic, offline, throwaway trees under mktemp ------------------------------------
# Every run uses a COPY of this script and of hatsu_root.sh placed inside the fixture's source tree,
# so the root a bare call resolves (its own plugin root, ten § 0's candidate 2) is the fixture's.
self_test() {
  local fx self code out
  fx="$(mktemp -d "${TMPDIR:-/tmp}/plugin-cache-check-selftest.XXXXXX")"
  fx="$(canon "$fx")"; cleanup_dir="$fx"

  fail() { echo "plugin-cache-check self-test: $*" >&2; finished=1; exit 1; }
  mktree() { # mktree DIR VERSION
    mkdir -p "$1/.claude-plugin" "$1/claude/skills/ten" "$1/claude/agents" "$1/claude/commands" "$1/claude/rules" \
      "$1/hooks" "$1/templates" "$1/contracts" "$1/docs" "$1/scripts" "$1/nen"
    printf '{\n  "name": "hatsu",\n  "version": "%s"\n}\n' "$2" > "$1/.claude-plugin/plugin.json"
    printf '# ten\nbody\n' > "$1/claude/skills/ten/SKILL.md"
    printf '# kurapika\n' > "$1/claude/agents/kurapika.md"
    printf '# /kurapika\n' > "$1/claude/commands/kurapika.md"
    printf '# rules\n' > "$1/claude/rules/hatsu.md"
    printf '{}\n' > "$1/hooks/hooks.json"
    printf '#!/bin/sh\nexit 0\n' > "$1/hooks/guard.sh"; chmod 755 "$1/hooks/guard.sh"
    printf 'tpl\n' > "$1/templates/report.html"
    printf '{}\n' > "$1/contracts/permissions.json"
    printf 'notes\n' > "$1/docs/notes.md"
    printf '{\n  "dependency": {\n    "pinned_ref": "v1.0.0"\n  }\n}\n' > "$1/nen/contract.json"
    printf '#!/bin/sh\n' > "$1/scripts/nen_global.sh"
    cp "$script_dir/hatsu_root.sh" "$script_dir/plugin_cache_check.sh" "$1/scripts/"
  }
  # run NAME EXPECTED ARGS... — from $fx (not a git tree), no ambient plugin roots, no host config.
  run() {
    local name="$1" expected="$2"; shift 2
    code=0
    out="$(cd "$fx" && env -u HATSU_PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT CLAUDE_CONFIG_DIR="$fx/cfg-none" "$@" 2>&1)" || code=$?
    [ "$code" -eq "$expected" ] || fail "$name: exit $code, expected $expected. Output: $out"
  }
  has() { case "$2" in *"$3"*) ;; *) fail "$1: expected '$3' in: $2" ;; esac; }
  hasnt() { case "$2" in *"$3"*) fail "$1: did not expect '$3' in: $2" ;; *) ;; esac; }
  last_is() { [ "$(printf '%s\n' "$2" | tail -n 1)" = "$3" ] || fail "$1: last line is not '$3': $2"; }
  fresh() { rm -rf "$fx/inst"; cp -Rp "$fx/src" "$fx/inst"; }
  reg() { # reg CFG ENTRY_BODY... — a registry in Claude Code's own shape, one hatsu@hatsu entry per body
    mkdir -p "$1/plugins"; local f="$1/plugins/installed_plugins.json" first=1 b; shift
    { printf '{\n  "version": 2,\n  "plugins": {\n    "hatsu@hatsu": [\n'
      for b in "$@"; do [ "$first" -eq 1 ] || printf ',\n'; first=0; printf '      {\n%s\n      }' "$b"; done
      printf '\n    ]\n  }\n}\n'; } > "$f"
  }

  mktree "$fx/src" 1.2.0
  self="$fx/src/scripts/plugin_cache_check.sh"

  # -- the verdicts
  fresh; run identical 0 bash "$self" --root "$fx/src" --installed "$fx/inst"
  last_is identical "$out" 'plugin-cache: current'
  fresh; printf 'old body\n' > "$fx/inst/claude/skills/ten/SKILL.md"
  run one-differs 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has one-differs "$out" 'differs: claude/skills/ten/SKILL.md'
  last_is one-differs "$out" 'plugin-cache: stale (1 paths)'
  has one-differs "$out" 'Same version (v1.2.0)'
  has one-differs "$out" 'hatsu_plugin_update.sh --auto --claude'
  fresh; rm "$fx/inst/claude/agents/kurapika.md"
  run one-missing 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has one-missing "$out" 'missing: claude/agents/kurapika.md'
  fresh; printf 'gone\n' > "$fx/inst/hooks/retired.sh"
  run one-extra 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has one-extra "$out" 'extra: hooks/retired.sh'
  # #118's class: the manifest is byte-identical (same version), a template is not.
  fresh; printf 'tpl v2\n' > "$fx/inst/templates/report.html"
  run same-version-bytes 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has same-version-bytes "$out" 'differs: templates/report.html'
  has same-version-bytes "$out" 'a stale same-version copy'
  hasnt same-version-bytes "$out" '.claude-plugin/plugin.json'
  fresh; printf '{\n  "name": "hatsu",\n  "version": "1.1.0"\n}\n' > "$fx/inst/.claude-plugin/plugin.json"
  run older-version 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has older-version "$out" 'differs: .claude-plugin/plugin.json'
  hasnt older-version "$out" 'Same version'

  # -- the whole tree is compared (Phinks: commands, hook-executed scripts, the nen pin)
  fresh; printf 'stale\n' >> "$fx/inst/claude/commands/kurapika.md"
  run commands-differ 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has commands-differ "$out" 'differs: claude/commands/kurapika.md'
  fresh; printf '# stale\n' >> "$fx/inst/scripts/nen_global.sh"
  run scripts-differ 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has scripts-differ "$out" 'differs: scripts/nen_global.sh'
  fresh; sed 's/v1.0.0/v0.9.0/' "$fx/src/nen/contract.json" > "$fx/inst/nen/contract.json"
  run contract-pin-differs 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has contract-pin-differs "$out" 'differs: nen/contract.json'
  fresh; printf 'x\n' > "$fx/inst/claude/rules/extra.md"
  run rules-extra 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has rules-extra "$out" 'extra: claude/rules/extra.md'
  # ...minus the ignore list: residue a real cache carries never counts.
  fresh; mkdir -p "$fx/inst/.nen/hanten" "$fx/inst/Reports" "$fx/inst/surfaces/codex" "$fx/inst/.claude/worktrees/x" "$fx/inst/.git"
  : > "$fx/inst/.nen/hanten/l.json"; : > "$fx/inst/Reports/r.md"; : > "$fx/inst/surfaces/codex/a.md"
  : > "$fx/inst/.claude/worktrees/x/f"; : > "$fx/inst/.git/HEAD"; : > "$fx/inst/.orphaned_at"; : > "$fx/inst/hooks/.DS_Store"
  run ignored-residue 0 bash "$self" --root "$fx/src" --installed "$fx/inst"
  fresh; mkdir "$fx/inst/claude/skills/.DS_Store"; : > "$fx/inst/claude/skills/.DS_Store/x"
  run ds-store-dir-counted 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has ds-store-dir-counted "$out" 'extra: claude/skills/.DS_Store/x'

  # -- types, links, modes (Feitan, Phinks)
  fresh; chmod a-x "$fx/inst/hooks/guard.sh"
  run hook-mode 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has hook-mode "$out" 'differs: hooks/guard.sh (mode)'
  fresh; rm "$fx/inst/hooks/hooks.json"; cp "$fx/src/hooks/hooks.json" "$fx/real-hooks.json"; ln -s "$fx/real-hooks.json" "$fx/inst/hooks/hooks.json"
  run link-vs-file 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has link-vs-file "$out" 'differs: hooks/hooks.json (type)'
  fresh; ln -s a "$fx/src/hooks/l"; ln -s b "$fx/inst/hooks/l"
  run link-strings 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has link-strings "$out" 'differs: hooks/l (link)'
  rm "$fx/src/hooks/l"
  fresh; rm "$fx/inst/hooks/hooks.json"; mkfifo "$fx/inst/hooks/hooks.json"
  run fifo-never-opened 1 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has fifo-never-opened "$out" 'differs: hooks/hooks.json (type)'
  fresh; printf 'x\n' > "$fx/inst/hooks/a$(printf '\001')b"
  run control-byte-name 2 bash "$self" --root "$fx/src" --installed "$fx/inst"
  has control-byte-name "$out" 'control byte'
  hasnt control-byte-name "$out" 'plugin-cache:'

  # -- wiring defects
  fresh; run missing-root 2 bash "$self" --root "$fx/nope" --installed "$fx/inst"
  has missing-root "$out" "source root '$fx/nope' is not a directory"
  mkdir -p "$fx/loose/scripts"; cp "$script_dir/hatsu_root.sh" "$script_dir/plugin_cache_check.sh" "$fx/loose/scripts/"
  run no-resolvable-root 2 bash "$fx/loose/scripts/plugin_cache_check.sh" --installed "$fx/inst"
  has no-resolvable-root "$out" "ten § 0's resolver found no source root"
  mkdir -p "$fx/cache-parent/1.2.0" && cp -Rp "$fx/src/." "$fx/cache-parent/1.2.0/"
  run cache-parent 2 bash "$self" --root "$fx/src" --installed "$fx/cache-parent"
  has cache-parent "$out" 'it holds the versions 1.2.0'
  mkdir -p "$fx/plugins/cache/hatsu/hatsu" && cp -Rp "$fx/src" "$fx/plugins/cache/hatsu/hatsu/1.2.0"
  run root-is-cache 2 bash "$self" --root "$fx/plugins/cache/hatsu/hatsu/1.2.0" --installed "$fx/inst"
  has root-is-cache "$out" 'resolved to a plugin cache'
  run unknown-flag 2 bash "$self" --bogus
  fresh; cp -Rp "$fx/src" "$fx/src2"; mkdir "$fx/src2/docs/locked"; chmod 000 "$fx/src2/docs/locked"
  run unreadable-dir 2 bash "$self" --root "$fx/src2" --installed "$fx/inst"
  has unreadable-dir "$out" 'could not list'
  chmod 755 "$fx/src2/docs/locked"; rm -rf "$fx/src2"

  # -- ten § 5 as written: $hatsu_root is never exported, both plugin roots unset; the root resolves
  fresh; run root-from-own-location 0 bash "$self" --installed "$fx/inst"
  last_is root-from-own-location "$out" 'plugin-cache: current'

  # -- links: to the source itself, and to another checkout
  ln -s "$fx/src" "$fx/link"
  run symlinked-install 0 bash "$self" --root "$fx/src" --installed "$fx/link"
  last_is symlinked-install "$out" 'plugin-cache: linked (identical by construction)'
  cp -Rp "$fx/src" "$fx/other"; ln -s "$fx/other" "$fx/link-other"
  run linked-to-other 1 bash "$self" --root "$fx/src" --installed "$fx/link-other"
  last_is linked-to-other "$out" "plugin-cache: linked to $fx/other (not $fx/src)"
  has linked-to-other "$out" "serves $fx/other's branch"

  # -- detection: the link, and the registry (Nobunaga, Feitan, Chrollo, Phinks)
  mkdir -p "$fx/cfg/skills" && ln -s "$fx/src" "$fx/cfg/skills/hatsu"
  run detected-link 0 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  has detected-link "$out" 'hatsu@skills-dir'
  fresh; printf 'old body\n' > "$fx/inst/claude/skills/ten/SKILL.md"
  reg "$fx/cfg" "        \"scope\": \"user\",
        \"installPath\": \"$fx/inst\""
  run detected-shadowing-cache 1 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  has detected-shadowing-cache "$out" 'shadows the skills-directory link'
  has detected-shadowing-cache "$out" 'differs: claude/skills/ten/SKILL.md'
  reg "$fx/cfg" "        \"scope\": \"user\",
        \"installPath\": \"$fx/inst\",
        \"unexpected\": {
          \"nested\": [
            1,
            2
          ]
        }"
  run registry-extra-field 1 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  has registry-extra-field "$out" 'differs: claude/skills/ten/SKILL.md'
  printf '{"version":2,"plugins":{"hatsu@hatsu":[{"scope":"user","installPath":"%s"}]}}\n' "$fx/inst" > "$fx/cfg/plugins/installed_plugins.json"
  run minified-registry 2 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  has minified-registry "$out" 'shape this check cannot read'
  printf '{"plugins": {"hatsu@hatsu": [ {\n' > "$fx/cfg/plugins/installed_plugins.json"
  run truncated-registry 2 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  printf '{\n  "version": 2,\n  "plugins": {\n    "hatsu@hatsu": [\n      {\n        "scope": "user"\n      }\n    ]\n  }\n}\n' > "$fx/cfg/plugins/installed_plugins.json"
  run entry-without-path 2 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  sed 's/"hatsu@hatsu"/"hatsu@hatsu-dev"/' > "$fx/cfg/plugins/installed_plugins.json" <<EOF
{
  "version": 2,
  "plugins": {
    "hatsu@hatsu": [
      {
        "installPath": "$fx/inst"
      }
    ]
  }
}
EOF
  run other-marketplace 1 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  has other-marketplace "$out" 'hatsu@hatsu-dev'
  cp -Rp "$fx/src" "$fx/fresh-copy"
  reg "$fx/cfg" "        \"scope\": \"project\",
        \"projectPath\": \"$fx/another-project\",
        \"installPath\": \"$fx/fresh-copy\"" "        \"scope\": \"user\",
        \"installPath\": \"$fx/inst\""
  run several-scopes 1 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  has several-scopes "$out" 'differs: claude/skills/ten/SKILL.md'
  reg "$fx/cfg" "        \"scope\": \"user\",
        \"installPath\": \"$fx/fresh-copy\"" "        \"scope\": \"user\",
        \"installPath\": \"$fx/inst\""
  run ambiguous-scopes 2 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  has ambiguous-scopes "$out" 'ambiguous'
  printf '{\n  "version": 2,\n  "plugins": {\n    "hatsu@hatsu": [],\n    "warp@w": [\n      {\n        "installPath": "/x"\n      }\n    ]\n  }\n}\n' > "$fx/cfg/plugins/installed_plugins.json"
  run empty-array-falls-to-link 0 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  last_is empty-array-falls-to-link "$out" 'plugin-cache: linked (identical by construction)'
  reg "$fx/cfg" "        \"scope\": \"user\",
        \"installPath\": \"$fx/gone\""
  run dangling-installPath 2 env CLAUDE_CONFIG_DIR="$fx/cfg" bash "$self"
  has dangling-installPath "$out" 'does not resolve'
  run detected-nothing 2 env CLAUDE_CONFIG_DIR="$fx/cfg-empty" bash "$self"
  has detected-nothing "$out" 'no installed Hatsu under'

  # -- a copy judging itself: the cache's OWN script, run through a symlinked cache directory
  mkdir -p "$fx/elsewhere/hatsu/hatsu" "$fx/cfg2/plugins"; cp -Rp "$fx/src" "$fx/elsewhere/hatsu/hatsu/1.2.0"
  ln -s "$fx/elsewhere" "$fx/cfg2/plugins/cache"
  reg "$fx/cfg2" "        \"scope\": \"user\",
        \"installPath\": \"$fx/cfg2/plugins/cache/hatsu/hatsu/1.2.0\""
  run copy-judges-itself 2 env CLAUDE_CONFIG_DIR="$fx/cfg2" CLAUDE_PLUGIN_ROOT="$fx/cfg2/plugins/cache/hatsu/hatsu/1.2.0" \
    bash "$fx/elsewhere/hatsu/hatsu/1.2.0/scripts/plugin_cache_check.sh"
  has copy-judges-itself "$out" 'a copy cannot judge a copy'

  echo 'plugin-cache-check self-test: ok (verdicts: identical, one differs, one missing, one extra, same-version bytes, older version; whole tree: commands, scripts, nen pin, rules, ignored residue, .DS_Store dir; types: mode, link vs file, link strings, fifo, control byte; wiring: missing root, unresolvable root, cache parent, root is a cache, unknown flag, unreadable dir; root from own location; links: to the source, to another checkout; detection: link, shadowing cache, extra field, minified, truncated, entry without path, other marketplace, several scopes, ambiguous, empty array, dangling, nothing; copy judging itself)'
  finished=1
}

if [ "${1:-}" = --self-test ]; then
  [ "$#" -eq 1 ] || die2 "--self-test takes no other argument"
  self_test
  exit 0
else
  check "$@"
fi
