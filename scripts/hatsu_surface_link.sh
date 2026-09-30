#!/usr/bin/env bash
# Point a surface at Hatsu's OWN local checkout through that surface's own
# first-party install -- a symlink discovered in place, never a Claude-shaped
# mirror and (on Claude Code) never a versioned cache copy.
#
# FACTS THIS SCRIPT ACTS ON (observed live 2026-09-29, in isolated homes):
#   Claude Code 2.1.284 -- a symlink at
#   ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/hatsu loads the checkout IN
#   PLACE as `hatsu@skills-dir` (`claude plugin list --json` shows an object
#   with "id": "hatsu@skills-dir", "installPath" the link path, and
#   "enabled": true). An installed `hatsu@hatsu` (a marketplace install,
#   COPIED into the plugin cache) shadows it, so a prior marketplace install
#   is handed over first: `claude plugin uninstall hatsu@hatsu`, then
#   `claude plugin marketplace remove hatsu` when that marketplace is
#   registered.
#   Codex 0.154.0 -- `codex plugin marketplace add <checkout>` reads the
#   checkout's own .claude-plugin/marketplace.json; the checkout also carries
#   .codex-plugin/plugin.json, the Codex overlay manifest that keys Codex's
#   own plugin-cache slot (scripts/plugin_bump_check.sh guards the two
#   manifests' versions staying equal). `codex plugin add hatsu@hatsu`
#   installs FROM that marketplace, and running sessions refresh after an
#   external plugin upgrade (codex-cli 0.154.0) rather than needing a
#   restart.
#   Antigravity (agy 1.0.6) -- a plugin folder placed at
#   ${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/<name> "activates
#   across all workspaces" (its own docs); `agy plugin install` COPIES, so it
#   is never used here -- only a symlink into the checkout's own generated
#   surfaces/antigravity/ keeps it live, and `agy plugin validate <path>`
#   is the read-back this script trusts.
#
# SAFETY CONTRACT, the same one scripts/hatsu_plugin_update.sh and
# scripts/surface_bootstrap.sh keep: only a destination this script itself
# would have created (or one that is currently absent) is ever replaced. A
# real directory, a file, or a symlink into anything but a Hatsu checkout is
# refused and NEVER removed -- the maintainer's own file always wins. --root
# must be a git checkout the maintainer controls: never a path under
# .../plugins/cache/, which is copied by an install rather than authored, and
# which the next `claude plugin update` (or codex/agy equivalent) silently
# replaces out from under a symlink pointed at it.
set -euo pipefail
LC_ALL=C

usage() {
  cat <<'EOF'
usage: scripts/hatsu_surface_link.sh --surface claude-code|codex|antigravity
                                      [--root <checkout>] [--dry-run | --status]

--surface   Which first-party install to point at this checkout:
              claude-code  a symlink at
                           ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/hatsu,
                           then hand over any prior hatsu@hatsu marketplace
                           install (uninstall it, then drop the marketplace).
              codex        this checkout registered as the `hatsu` Codex
                           marketplace (codex plugin marketplace add), then
                           `codex plugin add hatsu@hatsu`.
              antigravity  a symlink at
                           ${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu
                           pointed at <root>/surfaces/antigravity.
--root      The Hatsu checkout to serve. Defaults to $HATSU_PLUGIN_ROOT, else
            this script's own checkout. Must be a Hatsu tree, the toplevel of
            its own git checkout, and never a path under .../plugins/cache/.
--dry-run   Print the plan (`would run:` / `would link:` lines); change
            nothing. Mutually exclusive with --status.
--status    Read-only: report what the named surface serves right now;
            change nothing. Mutually exclusive with --dry-run.

Exit codes: 0 ok; 2 usage, wiring, or --root refused; 3 the destination is
not ours to replace; 5 the surface's required CLI is missing (a missing or
unsatisfied tool is always 5, never 4 -- docs/PROCESS.md); on claude-code
this also covers claude absent while a handover is owed
(installed_plugins.json records hatsu@hatsu, or settings.json declares
enabledPlugins "hatsu@hatsu" or extraKnownMarketplaces.hatsu), refused
before anything is touched -- claude absent with nothing owed still links
and reports the read-back as not done, exit 0; 1 a CLI step (or a
post-install read-back) failed, its last line quoted.
EOF
}

surface=""
root_input=""
dry_run=0
status_mode=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --surface)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      surface="$2"
      shift 2
      ;;
    --root)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      root_input="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --status)
      status_mode=1
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

case "$surface" in
  claude-code|codex|antigravity) ;;
  *)
    echo "hatsu-surface-link: --surface must be claude-code, codex, or antigravity" >&2
    usage >&2
    exit 2
    ;;
esac

if [ "$dry_run" -eq 1 ] && [ "$status_mode" -eq 1 ]; then
  echo "hatsu-surface-link: choose --dry-run or --status, not both" >&2
  exit 2
fi

# --- identity helpers, verbatim from scripts/hatsu_plugin_update.sh --------
# Canonicalise without letting command substitution erase a trailing newline.
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

# manifest_string_field FILE KEY -- FILE's top-level "KEY": "value" line, at
# 2-space indent (the shape every plugin.json here is pretty-printed in, the
# same shape hatsu_plugin_update.sh's own plugin_version reads). Empty when
# the file is absent, unreadable, or carries no such line.
manifest_string_field() {
  local file="$1" key="$2"
  [ -f "$file" ] || { printf ''; return 0; }
  awk -v pat="^  \"${key}\": \"" '
    $0 ~ pat {
      s = $0
      sub(pat, "", s)
      sub(/",?$/, "", s)
      print s
      exit
    }
  ' "$file"
}

# --- --root resolution and validation ---------------------------------------
self_source="${BASH_SOURCE[0]:-$0}"
case "$self_source" in
  */*) script_base="${self_source%/*}" ;;
  *) script_base='.' ;;
esac
script_dir="$(canonical_directory "$script_base")" || {
  echo "hatsu-surface-link: cannot canonicalize its script directory" >&2
  exit 2
}
script_hatsu="$(canonical_directory "$script_dir/..")" || {
  echo "hatsu-surface-link: cannot canonicalize its checkout" >&2
  exit 2
}

root_candidate="${root_input:-${HATSU_PLUGIN_ROOT:-$script_hatsu}}"
root="$(canonical_directory "$root_candidate")" || {
  echo "hatsu-surface-link: --root is not a usable directory: $root_candidate" >&2
  exit 2
}

if ! is_hatsu "$root"; then
  echo "hatsu-surface-link: $root is not a Hatsu checkout (.claude-plugin/plugin.json top-level name must be hatsu, with claude/skills/)" >&2
  exit 2
fi

case "$root" in
  */plugins/cache/*)
    echo "hatsu-surface-link: $root lies under a /plugins/cache/ path -- the first-party install always points at a checkout the maintainer controls, never a versioned plugin cache a future update silently replaces" >&2
    exit 2
    ;;
esac

git_top_raw="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "hatsu-surface-link: $root is not a git checkout (git rev-parse --show-toplevel failed) -- the first-party install always points at a checkout the maintainer controls" >&2
  exit 2
}
git_top="$(canonical_directory "$git_top_raw" 2>/dev/null || printf '%s' "$git_top_raw")"
if [ "$git_top" != "$root" ]; then
  echo "hatsu-surface-link: $root is not the toplevel of its git checkout (toplevel is $git_top) -- point --root at the checkout root" >&2
  exit 2
fi

# --- generic helpers ---------------------------------------------------------
# one_line TEXT -- the last non-empty line of TEXT, control characters
# stripped, capped at 200 characters (Feitan, log hygiene) -- same contract
# as hatsu_plugin_update.sh's own one_line.
one_line() {
  printf '%s\n' "$1" | awk 'NF { line = $0 } END { print line }' | tr -d '\000-\037' | cut -c1-200
}

# line1 TEXT / line2 TEXT -- the first / second line of TEXT, robust against
# command substitution's OWN trailing-newline stripping: a two-line result
# whose second line is genuinely empty (e.g. "ok\n\n", read back through
# `result="$(...)"`) collapses to a single line with no newline in it at
# all, and bash's own `${result%%$'\n'*}` / `${result#*$'\n'}` then silently
# read the WHOLE string back as line 2 instead of empty, because there is no
# newline left for the pattern to match (live bug, 2026-09-29, on the very
# first claude-code case run). Re-splitting through a FRESH awk read of the
# already-captured string sidesteps this: printf adds exactly one line's
# worth of trailing newline back, and `NR==2` on a truly single-line input
# correctly finds nothing.
line1() { printf '%s\n' "$1" | awk 'NR==1'; }
line2() { printf '%s\n' "$1" | awk 'NR==2'; }

would_run() {
  if [ "$dry_run" -eq 1 ]; then
    printf 'would run: %s\n' "$1"
  fi
}

would_link() {
  if [ "$dry_run" -eq 1 ]; then
    printf 'would link: %s\n' "$1"
  fi
}

report() {
  printf 'hatsu-surface-link: %s · %s · serves %s · apply: %s\n' "$1" "$2" "$3" "$4"
}

# run_step DESC CMD... -- runs CMD, combining its stdout and stderr. On
# success prints CMD's own captured output (so a caller can still read it,
# e.g. Codex's "Installed plugin root:" line). On failure prints DESC and
# CMD's last output line to stderr and exits 1 -- the one exit code this
# whole script uses for "a CLI step failed".
run_step() {
  local desc="$1" out rc
  shift
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "hatsu-surface-link: $desc failed: $(one_line "$out")" >&2
    exit 1
  fi
  printf '%s' "$out"
}

# canonical_hatsu_target DEST SUFFIX -- DEST must be a symlink. When SUFFIX
# is empty, DEST's canonical target must itself be a Hatsu checkout (the
# claude-code case: the link points AT the checkout root). When SUFFIX is
# "surfaces/antigravity", DEST's canonical target must END with that path and
# what remains after stripping it must be a Hatsu checkout (the antigravity
# case: the link points at a generated SUBDIRECTORY of a Hatsu checkout).
# Echoes the canonical target and returns 0 when DEST is "ours" under that
# rule; returns 1 (nothing echoed) for a foreign symlink, a dangling one, or
# anything that is not a symlink at all.
canonical_hatsu_target() {
  local dest="$1" suffix="$2" canon base
  [ -L "$dest" ] || return 1
  canon="$(canonical_directory "$dest" 2>/dev/null)" || return 1
  if [ -n "$suffix" ]; then
    case "$canon" in
      */"$suffix") base="${canon%/"$suffix"}" ;;
      *) return 1 ;;
    esac
  else
    base="$canon"
  fi
  is_hatsu "$base" || return 1
  printf '%s' "$canon"
}

# verify_symlink_created DEST TARGET SUFFIX -- proves, right after an `ln`,
# that DEST is actually a symlink and canonicalises to TARGET (per
# canonical_hatsu_target's own SUFFIX rule). Phinks, 2026-09-29: bash 3.2
# drops errexit for a command run INSIDE a command substitution, so the old
# `changes="$(ensure_symlink ...)"` let a failed `ln` still be read back as
# "linked" at exit 0, and the adoption handover then ran against a host that
# served no Hatsu at all. Two distinct refusals, not one: DEST not even a
# symlink is exit 1 (ln itself did not do what it claimed); DEST a symlink
# that resolves to something other than TARGET is exit 3, the same code
# every other "not ours" refusal in this script uses -- a race that let a
# DIFFERENT process win the destination between our own check and our own
# `ln` reads exactly like a foreign destination, because it is one.
verify_symlink_created() {
  local dest="$1" target="$2" suffix="$3" canon
  if [ ! -L "$dest" ]; then
    echo "hatsu-surface-link: $dest was not created as a symlink after ln -- refusing to proceed" >&2
    exit 1
  fi
  if canon="$(canonical_hatsu_target "$dest" "$suffix")" && [ "$canon" = "$target" ]; then
    return 0
  fi
  echo "hatsu-surface-link: $dest is not ours after ln (resolves to ${canon:-a foreign or dangling target}, not $target) -- refusing to proceed" >&2
  exit 3
}

# ensure_symlink DEST TARGET SUFFIX -- the one ownership-respecting linker
# both claude-code and antigravity use. Absent -> links. Ours (per
# canonical_hatsu_target) but pointed elsewhere -> re-points. Anything else
# -- a real directory, a file, or a symlink into a non-Hatsu tree -- is
# refused at exit 3 and left exactly as it was; this script never discards
# what is not its own. Both creating branches use `ln -sfn` (never `ln -s`
# alone): `-n` is what keeps a symlink-to-a-directory DEST from silently
# receiving the new link INSIDE itself, and `-f` is what lets a second `ln`
# win a race against whatever a first one left behind, which
# verify_symlink_created then checks was actually us.
#
# MUST be called directly, never as `x="$(ensure_symlink ...)"` -- see
# verify_symlink_created's own comment for why bash 3.2 makes that unsafe.
# Sets the global ENSURE_SYMLINK_RESULT to one of: linked / already linked /
# re-pointed from <previous target>; callers read that global instead.
ensure_symlink() {
  local dest="$1" target="$2" suffix="$3" canon what
  ENSURE_SYMLINK_RESULT=""
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    would_link "ln -s $target $dest"
    if [ "$dry_run" -eq 0 ]; then
      mkdir -p "$(dirname "$dest")"
      ln -sfn "$target" "$dest"
      verify_symlink_created "$dest" "$target" "$suffix"
    fi
    ENSURE_SYMLINK_RESULT='linked'
    return 0
  fi
  if canon="$(canonical_hatsu_target "$dest" "$suffix")"; then
    if [ "$canon" = "$target" ]; then
      ENSURE_SYMLINK_RESULT='already linked'
    else
      would_link "ln -sfn $target $dest (was $canon)"
      if [ "$dry_run" -eq 0 ]; then
        ln -sfn "$target" "$dest"
        verify_symlink_created "$dest" "$target" "$suffix"
      fi
      ENSURE_SYMLINK_RESULT="re-pointed from $canon"
    fi
    return 0
  fi
  if [ -L "$dest" ]; then
    what="a symlink to $(readlink "$dest" 2>/dev/null || printf '<unreadable>') (not a Hatsu tree, or dangling)"
  elif [ -d "$dest" ]; then
    what="a real directory"
  elif [ -e "$dest" ]; then
    what="a file"
  else
    what="not usable"
  fi
  echo "hatsu-surface-link: $dest is $what -- refusing to replace it; the first-party install never discards what is not its own" >&2
  exit 3
}

# --- Claude Code's own JSON reads, one documented shape (Feitan review on
# hatsu_plugin_update.sh applies here too: read one shape, and an unread one
# fails closed toward "not verified" rather than a false positive). ---------

# claude_list_find_skills_dir -- reads `claude plugin list --json`'s
# pretty-printed output on stdin and echoes the installPath of the object
# whose "id" is "hatsu@skills-dir" AND whose "enabled" is true within that
# SAME object (a later "id" line ends the scan for the current one). Nothing
# when no such enabled object exists.
claude_list_find_skills_dir() {
  awk '
    /"id"[[:space:]]*:[[:space:]]*"hatsu@skills-dir"/ { active = 1; enabled = 0; path = ""; next }
    active && /"id"[[:space:]]*:[[:space:]]*"/ { active = 0 }
    active && /"enabled"[[:space:]]*:[[:space:]]*true/ { enabled = 1 }
    active && /"installPath"[[:space:]]*:[[:space:]]*"/ {
      s = $0
      sub(/^[^"]*"installPath"[[:space:]]*:[[:space:]]*"/, "", s)
      sub(/".*$/, "", s)
      path = s
    }
    active && /^[[:space:]]*\},?[[:space:]]*$/ {
      if (enabled && path != "") print path
      active = 0
    }
  '
}

# claude_list_hatsu_hatsu_enabled -- reads `claude plugin list --json`'s
# pretty-printed output on stdin; echoes "enabled" when an object whose "id"
# is "hatsu@hatsu" also carries "enabled": true, nothing otherwise. This is
# the MARKETPLACE-INSTALLED copy (the one that shadows the skills-dir link,
# zheref/hatsu live incident 2026-09-29): the handover must leave this
# object gone or disabled, never merely "installed".
claude_list_hatsu_hatsu_enabled() {
  awk '
    /"id"[[:space:]]*:[[:space:]]*"hatsu@hatsu"/ { active = 1; enabled = 0; next }
    active && /"id"[[:space:]]*:[[:space:]]*"/ { active = 0 }
    active && /"enabled"[[:space:]]*:[[:space:]]*true/ { enabled = 1 }
    active && /^[[:space:]]*\},?[[:space:]]*$/ {
      if (enabled) found = 1
      active = 0
    }
    END { if (found) print "enabled" }
  '
}

# --- Claude Code's settings.json reads --------------------------------------
#
# THE LIVE INCIDENT THIS SECTION EXISTS FOR (2026-09-29). After a clean
# handover (uninstall hatsu@hatsu, remove the hatsu marketplace, green
# read-back), a LATER /reload-plugins reinstalled hatsu@hatsu and it shadowed
# the skills-dir link again. Cause: the user's settings.json separately
# declared `extraKnownMarketplaces.hatsu` (a git URL, different from the
# Directory source known_marketplaces.json held) and
# `enabledPlugins["hatsu@hatsu"]: true`. `claude plugin marketplace remove
# hatsu` only ever clears the KNOWN (known_marketplaces.json) entry; Claude
# Code documents that a marketplace settings declares but known_marketplaces
# lacks is CLONED again on the next reload, and an enabled-but-uncached
# plugin is then downloaded. So the handover must also read and, where
# possible, clear these two settings.json declarations -- and must never
# silently believe them gone when it cannot actually read the file.
#
# settings_file_shape_ok FILE -- true for either of the two shapes
# JSON.stringify(x, null, 2) actually produces for the objects this script
# reads: the pretty-printed multi-line form (first non-empty line exactly
# "{", last non-empty line exactly "}", at least one line between them), or
# the single-line empty object "{}" that same call prints for `{}` itself
# (Phinks, 2026-09-29: the old check required n >= 2 unconditionally and so
# refused a bare "{}" settings.json -- the exact shape an empty settings
# object legitimately takes -- as unreadable, when it plainly declares
# nothing). A minified or otherwise-shaped settings.json still fails this,
# on purpose: this script does not attempt to parse arbitrary JSON, only to
# recognise the shapes Claude Code itself writes, and anything else must
# read as "not verified" rather than silently as "declares nothing".
settings_file_shape_ok() {
  local file="$1"
  awk '
    NF { if (!seen) { first = $0; seen = 1 }; last = $0; n++ }
    END {
      if (n == 1 && first == "{}") { print "ok"; exit }
      if (n >= 2 && first == "{" && last == "}") { print "ok"; exit }
      print "bad"
    }
  ' "$file"
}

# settings_scan FILE KEY LEAF_REGEX -- FILE absent or unreadable: echoes
# "ok" then an empty line (nothing declared -- an absent settings.json
# declares nothing, confidently). FILE present: first checks
# settings_file_shape_ok; if that fails, echoes "bad" then empty (caller
# fails closed). Otherwise scans for a top-level "KEY": { ... } block (or
# the inline empty "KEY": {} / "KEY": {},) opened and closed each on their
# own 2-space line -- deliberately NOT validating everything between them,
# since both blocks this script reads (extraKnownMarketplaces, enabledPlugins)
# hold further-nested values -- and echoes "declared" as its second line when
# a line inside the block matches LEAF_REGEX. A KEY block opened twice, or
# opened and never closed, is itself "bad" (not the one shape trusted here).
settings_scan() {
  local file="$1" key="$2" leaf_regex="$3" shape
  if [ ! -r "$file" ]; then
    printf 'ok\n\n'
    return 0
  fi
  shape="$(settings_file_shape_ok "$file")"
  if [ "$shape" != "ok" ]; then
    printf 'bad\n\n'
    return 0
  fi
  awk -v key="$key" -v leaf="$leaf_regex" '
    BEGIN { ok = 1; declared = ""; in_block = 0; seen = 0 }
    $0 == "  \"" key "\": {}" || $0 == "  \"" key "\": {}," { next }
    $0 == "  \"" key "\": {" {
      if (seen) { ok = 0 }
      in_block = 1; seen = 1; next
    }
    in_block && ($0 == "  }" || $0 == "  },") { in_block = 0; next }
    in_block {
      if ($0 ~ leaf) declared = "declared"
      next
    }
    END {
      if (in_block) ok = 0
      print (ok ? "ok" : "bad")
      print declared
    }
  ' "$file"
}

# settings_declares_marketplace FILE -- two lines: shape ("ok"/"bad"), then
# "declared"/"" for extraKnownMarketplaces.hatsu.
settings_declares_marketplace() {
  settings_scan "$1" 'extraKnownMarketplaces' '^    "hatsu": \{$'
}

# settings_declares_enabled_plugin FILE -- two lines: shape ("ok"/"bad"),
# then "declared"/"" for enabledPlugins["hatsu@hatsu"] == true.
settings_declares_enabled_plugin() {
  settings_scan "$1" 'enabledPlugins' '^    "hatsu@hatsu": true,?$'
}

# --- Codex's own reads: a fixed-column table, not JSON. --------------------

# codex_marketplace_list_hatsu_root -- reads `codex plugin marketplace
# list`'s output (header `MARKETPLACE  ROOT`, rows `<name>  <root>`) on
# stdin, echoes the ROOT of the row named exactly `hatsu`, or nothing.
#
# NEVER `exit` early here: a real `codex plugin marketplace list` (or
# `codex plugin list`, below) can print thousands of rows, and this function
# is always fed through a PIPE (`printf ... | codex_...`). An early `exit`
# stops reading before the pipe's writer has finished, so that writer's next
# write hits a closed pipe and dies of SIGPIPE (exit 141) -- silently, since
# `pipefail` + `set -e` then kill the whole script with no message even
# though awk itself matched and printed correctly. Every reader in this file
# that is fed through a pipe therefore reads to EOF and prints in END.
codex_marketplace_list_hatsu_root() {
  awk '
    NR == 1 && $0 ~ /^MARKETPLACE[[:space:]]/ { next }
    !found {
      line = $0
      if (match(line, /^hatsu[[:space:]]+/)) {
        root = substr(line, RLENGTH + 1)
        sub(/^[[:space:]]+/, "", root)
        sub(/[[:space:]]+$/, "", root)
        found = 1
      }
    }
    END { if (found) print root }
  '
}

# codex_plugin_list_row -- reads `codex plugin list`'s output on stdin and,
# for the `hatsu@hatsu` row, echoes two lines: its STATUS verbatim (may
# itself carry a comma and a space, e.g. "installed, enabled"), then its
# VERSION. Nothing when the row is absent. Never exits early -- see
# codex_marketplace_list_hatsu_root's comment on why: a real `codex plugin
# list` can print thousands of rows, and this function is always fed
# through a pipe.
codex_plugin_list_row() {
  awk '
    !found {
      line = $0
      if (match(line, /^hatsu@hatsu[[:space:]]+/)) {
        rest = substr(line, RLENGTH + 1)
        status = ""
        version = ""
        if (match(rest, /^[A-Za-z]+, [A-Za-z]+[[:space:]]+/)) {
          status = substr(rest, 1, RLENGTH)
          sub(/[[:space:]]+$/, "", status)
          after = substr(rest, RLENGTH + 1)
          n = split(after, parts, /[[:space:]]+/)
          if (n >= 1) version = parts[1]
        } else {
          n2 = split(rest, parts2, /[[:space:]]+/)
          if (n2 >= 1) status = parts2[1]
        }
        found = 1
      }
    }
    END { if (found) { print status; print version } }
  '
}

claude_code_apply="claude-code: type /reload-plugins in the running session, or open a new session"
codex_apply="codex: running sessions refresh after an external plugin upgrade (codex-cli 0.154.0), else open a new session"
antigravity_apply="antigravity: open a new conversation"

# ============================================================================
# claude-code
# ============================================================================

# claude_disable_hatsu_hatsu INSTALLED_FLAG -- runs `claude plugin disable
# hatsu@hatsu --scope user`. INSTALLED_FLAG is "1" when installed_plugins.json
# already confirmed hatsu@hatsu is installed, "0" otherwise (only
# settings.json's enabledPlugins declared it). Echoes "disabled hatsu@hatsu"
# on success, or "disable skipped (not installed)" on a refusal that LOOKS
# LIKE "not installed" -- and ONLY when INSTALLED_FLAG is "0": the same
# message while installed_plugins.json says it IS installed is a real defect
# and is never tolerated. Any other failure exits 1, as run_step does.
claude_disable_hatsu_hatsu() {
  local installed_flag="$1" out rc
  set +e
  out="$(claude plugin disable hatsu@hatsu --scope user 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    printf 'disabled hatsu@hatsu'
    return 0
  fi
  if [ "$installed_flag" = "0" ]; then
    case "$out" in
      *[Nn]ot\ installed*|*not-installed*|*[Nn]o\ such\ plugin*)
        printf 'disable skipped (not installed)'
        return 0
        ;;
    esac
  fi
  echo "hatsu-surface-link: claude plugin disable hatsu@hatsu --scope user failed: $(one_line "$out")" >&2
  exit 1
}

status_claude_code() {
  local dest="$1" config_dir="$2" desc canon raw readback found_path list_out rc
  if [ -L "$dest" ]; then
    if canon="$(canonical_hatsu_target "$dest" "")"; then
      if [ "$canon" = "$root" ]; then
        desc="linked to this checkout ($canon)"
      else
        desc="linked to another Hatsu checkout ($canon)"
      fi
    else
      raw="$(readlink "$dest" 2>/dev/null || printf '<unreadable>')"
      desc="a symlink to $raw (not a Hatsu tree, or dangling)"
    fi
  elif [ -e "$dest" ]; then
    desc="occupied by a real path (not a symlink)"
  else
    desc="absent"
  fi

  local live_enabled=""
  if command -v claude >/dev/null 2>&1; then
    set +e
    list_out="$(claude plugin list --json 2>&1)"
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
      found_path="$(printf '%s\n' "$list_out" | claude_list_find_skills_dir)"
      if [ -n "$found_path" ]; then
        readback="hatsu@skills-dir enabled, installPath $found_path"
      else
        readback="no enabled hatsu@skills-dir entry"
      fi
      live_enabled="$(printf '%s\n' "$list_out" | claude_list_hatsu_hatsu_enabled)"
    else
      readback="claude plugin list --json failed: $(one_line "$list_out")"
    fi
  else
    readback="claude not on PATH"
  fi

  # THE RELOAD-RISK WARNING (live incident 2026-09-29). A settings.json
  # declaration -- or a still-enabled hatsu@hatsu -- is exactly what makes
  # Claude Code re-clone and re-download the marketplace copy on the NEXT
  # /reload-plugins, even after a clean uninstall + marketplace remove. This
  # is read-only and never fails the status call: an unverifiable
  # settings.json is itself reported, rather than silently skipped.
  local settings_file="$config_dir/settings.json" suffix=""
  local mkt_result mkt_shape mkt_declared enb_result enb_shape enb_declared
  mkt_result="$(settings_declares_marketplace "$settings_file")"
  mkt_shape="$(line1 "${mkt_result}")"
  mkt_declared="$(line2 "${mkt_result}")"
  enb_result="$(settings_declares_enabled_plugin "$settings_file")"
  enb_shape="$(line1 "${enb_result}")"
  enb_declared="$(line2 "${enb_result}")"

  if [ "$mkt_shape" != "ok" ] || [ "$enb_shape" != "ok" ]; then
    suffix=" · $settings_file: not verified (unexpected shape)"
  else
    local reasons=""
    if [ -n "$mkt_declared" ]; then
      reasons="settings.json declares extraKnownMarketplaces.hatsu"
    fi
    if [ "$live_enabled" = "enabled" ] || [ -n "$enb_declared" ]; then
      reasons="${reasons:+$reasons, }hatsu@hatsu is enabled"
    fi
    [ -n "$reasons" ] && suffix=" · will reinstall on reload: $reasons"
  fi

  report "claude-code" "status: $desc · $readback$suffix" "$dest" "$claude_code_apply"
}

do_claude_code() {
  local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local dest="$config_dir/skills/hatsu"

  if [ "$status_mode" -eq 1 ]; then
    status_claude_code "$dest" "$config_dir"
    return 0
  fi

  # EVERY PRECONDITION IS READ BEFORE ANYTHING IS LINKED (Phinks/Nobunaga,
  # 2026-09-29). A settings.json this script cannot verify, or a handover
  # claude cannot perform, must change nothing -- not even the destination
  # symlink -- so both are decided here, ahead of ensure_symlink.
  local installed_file="$config_dir/plugins/installed_plugins.json"
  local marketplaces_file="$config_dir/plugins/known_marketplaces.json"
  local settings_file="$config_dir/settings.json"

  local is_installed=0
  if [ -r "$installed_file" ] && grep -qxF '    "hatsu@hatsu": [' "$installed_file"; then
    is_installed=1
  fi

  local enb_result enb_shape enb_declared
  enb_result="$(settings_declares_enabled_plugin "$settings_file")"
  enb_shape="$(line1 "${enb_result}")"
  enb_declared="$(line2 "${enb_result}")"
  if [ "$enb_shape" != "ok" ]; then
    echo "hatsu-surface-link: $settings_file is not in the one shape read (JSON.stringify(x, null, 2)) -- could not verify enabledPlugins" >&2
    exit 1
  fi

  local mkt_result mkt_shape mkt_declared
  mkt_result="$(settings_declares_marketplace "$settings_file")"
  mkt_shape="$(line1 "${mkt_result}")"
  mkt_declared="$(line2 "${mkt_result}")"
  if [ "$mkt_shape" != "ok" ]; then
    echo "hatsu-surface-link: $settings_file is not in the one shape read (JSON.stringify(x, null, 2)) -- could not verify extraKnownMarketplaces" >&2
    exit 1
  fi

  # A HANDOVER claude CANNOT PERFORM (Nobunaga N6 / Phinks, 2026-09-29):
  # without claude on PATH there is no CLI to run the disable/uninstall/
  # marketplace-remove sequence below, so a recorded install or declaration
  # is a hard refusal, before $dest is even touched -- never linked and left
  # to keep silently shadowing. Nothing owed is unchanged from before:
  # link, and say the read-back could not be done.
  if ! command -v claude >/dev/null 2>&1; then
    local owed=""
    [ "$is_installed" -eq 1 ] && owed="installed_plugins.json records hatsu@hatsu"
    if [ -n "$enb_declared" ]; then
      owed="${owed:+$owed, }settings.json declares enabledPlugins \"hatsu@hatsu\": true"
    fi
    if [ -n "$mkt_declared" ]; then
      owed="${owed:+$owed, }settings.json declares extraKnownMarketplaces.hatsu"
    fi
    if [ -n "$owed" ]; then
      echo "hatsu-surface-link: claude is not on PATH, but a handover is owed ($owed) -- refusing before $dest is touched" >&2
      exit 5
    fi
  fi

  local changes list_out found_path
  ensure_symlink "$dest" "$root" ""
  changes="$ENSURE_SYMLINK_RESULT"

  if ! command -v claude >/dev/null 2>&1; then
    if [ "$dry_run" -eq 1 ]; then
      report "claude-code" "$changes · dry-run" "$dest" "$claude_code_apply"
      return 0
    fi
    changes="$changes · claude not on PATH: read-back not done"
    report "claude-code" "$changes" "$dest" "$claude_code_apply"
    return 0
  fi

  # ADOPTION HANDOVER. A prior marketplace install of hatsu@hatsu is COPIED
  # into the plugin cache and SHADOWS a skills-dir symlink loaded in place,
  # so it is handed over before the read-back below can mean anything.
  # settings.json's own declarations (see the section comment above
  # claude_list_hatsu_hatsu_enabled) are read alongside the registry files,
  # because either alone can bring the shadow back on the next reload. Every
  # check reads a FILE directly (never a `claude` query) so the plan is
  # knowable, and identical, under --dry-run. is_installed/enb_declared/
  # mkt_declared were already read above, ahead of ensure_symlink.
  local did_clear=0

  if [ "$is_installed" -eq 1 ] || [ -n "$enb_declared" ]; then
    would_run "claude plugin disable hatsu@hatsu --scope user"
    [ "$is_installed" -eq 1 ] && would_run "claude plugin uninstall hatsu@hatsu"
    if [ "$dry_run" -eq 0 ]; then
      local disable_result
      disable_result="$(claude_disable_hatsu_hatsu "$is_installed")"
      changes="$changes · $disable_result"
      [ "$disable_result" = "disabled hatsu@hatsu" ] && did_clear=1

      if [ "$is_installed" -eq 1 ]; then
        run_step "claude plugin uninstall hatsu@hatsu" claude plugin uninstall hatsu@hatsu >/dev/null
        changes="$changes · uninstalled hatsu@hatsu"
        did_clear=1
      fi
    fi
  fi

  local known_declared
  known_declared=0
  if [ -r "$marketplaces_file" ] && grep -qxF '  "hatsu": {' "$marketplaces_file"; then
    known_declared=1
  fi

  if [ "$known_declared" -eq 1 ] || [ -n "$mkt_declared" ]; then
    would_run "claude plugin marketplace remove hatsu"
    if [ "$dry_run" -eq 0 ]; then
      # UP TO TWICE (live incident 2026-09-29): the first remove clears only
      # the KNOWN (known_marketplaces.json) entry; a settings.json
      # declaration survives that alone. Re-reading both after every attempt
      # is what lets a second remove -- now that the known entry, if any,
      # reflects the declared source -- clear the settings declaration too.
      local mkt_attempt=0 mkt_cleared=0
      while [ "$mkt_attempt" -lt 2 ]; do
        mkt_attempt=$((mkt_attempt + 1))
        run_step "claude plugin marketplace remove hatsu" claude plugin marketplace remove hatsu >/dev/null
        known_declared=0
        if [ -r "$marketplaces_file" ] && grep -qxF '  "hatsu": {' "$marketplaces_file"; then
          known_declared=1
        fi
        mkt_result="$(settings_declares_marketplace "$settings_file")"
        mkt_shape="$(line1 "${mkt_result}")"
        mkt_declared="$(line2 "${mkt_result}")"
        if [ "$mkt_shape" != "ok" ]; then
          echo "hatsu-surface-link: $settings_file is not in the one shape read (JSON.stringify(x, null, 2)) -- could not verify extraKnownMarketplaces" >&2
          exit 1
        fi
        if [ "$known_declared" -eq 0 ] && [ -z "$mkt_declared" ]; then
          mkt_cleared=1
          break
        fi
      done
      if [ "$mkt_cleared" -eq 0 ]; then
        local remaining=""
        [ "$known_declared" -eq 1 ] && remaining="$marketplaces_file's top-level \"hatsu\""
        if [ -n "$mkt_declared" ]; then
          remaining="${remaining:+$remaining and }$settings_file's extraKnownMarketplaces.hatsu"
        fi
        echo "hatsu-surface-link: hatsu marketplace declaration still present after 2 removal attempts: $remaining -- never editing settings.json by hand, refusing" >&2
        exit 1
      fi
      changes="$changes · removed marketplace hatsu"
      did_clear=1
    fi
  fi

  if [ "$dry_run" -eq 1 ]; then
    report "claude-code" "$changes · dry-run" "$dest" "$claude_code_apply"
    return 0
  fi

  list_out="$(run_step "claude plugin list --json" claude plugin list --json)"
  found_path="$(printf '%s\n' "$list_out" | claude_list_find_skills_dir)"
  if [ -z "$found_path" ]; then
    echo "hatsu-surface-link: claude plugin list --json has no enabled hatsu@skills-dir entry after linking $dest" >&2
    exit 1
  fi
  if [ "$(printf '%s\n' "$list_out" | claude_list_hatsu_hatsu_enabled)" = "enabled" ]; then
    echo "hatsu-surface-link: claude plugin list --json still shows hatsu@hatsu enabled -- the marketplace-installed shadow was not fully cleared" >&2
    exit 1
  fi

  enb_result="$(settings_declares_enabled_plugin "$settings_file")"
  enb_shape="$(line1 "${enb_result}")"
  enb_declared="$(line2 "${enb_result}")"
  if [ "$enb_shape" != "ok" ]; then
    echo "hatsu-surface-link: $settings_file is not in the one shape read (JSON.stringify(x, null, 2)) -- could not verify enabledPlugins" >&2
    exit 1
  fi
  if [ -n "$enb_declared" ]; then
    echo "hatsu-surface-link: $settings_file still declares enabledPlugins \"hatsu@hatsu\": true after the handover" >&2
    exit 1
  fi

  mkt_result="$(settings_declares_marketplace "$settings_file")"
  mkt_shape="$(line1 "${mkt_result}")"
  mkt_declared="$(line2 "${mkt_result}")"
  if [ "$mkt_shape" != "ok" ]; then
    echo "hatsu-surface-link: $settings_file is not in the one shape read (JSON.stringify(x, null, 2)) -- could not verify extraKnownMarketplaces" >&2
    exit 1
  fi
  if [ -n "$mkt_declared" ]; then
    echo "hatsu-surface-link: $settings_file still declares extraKnownMarketplaces.hatsu after the handover" >&2
    exit 1
  fi

  changes="$changes · read back hatsu@skills-dir enabled"
  [ "$did_clear" -eq 1 ] && changes="$changes · declarations cleared"
  report "claude-code" "$changes" "$found_path" "$claude_code_apply"
}

# ============================================================================
# codex
# ============================================================================

status_codex() {
  local mkt_out mkt_root desc list_out row status_val version_val readback rc
  if ! command -v codex >/dev/null 2>&1; then
    report "codex" "status: codex not on PATH" "$root" "$codex_apply"
    return 0
  fi

  set +e
  mkt_out="$(codex plugin marketplace list 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    report "codex" "status: codex plugin marketplace list failed: $(one_line "$mkt_out")" "$root" "$codex_apply"
    return 0
  fi
  mkt_root="$(printf '%s\n' "$mkt_out" | codex_marketplace_list_hatsu_root)"
  if [ -z "$mkt_root" ]; then
    desc="no hatsu marketplace registered"
  else
    local mkt_root_canon
    mkt_root_canon="$(canonical_directory "$mkt_root" 2>/dev/null || printf '%s' "$mkt_root")"
    if [ "$mkt_root_canon" = "$root" ]; then
      desc="marketplace hatsu at this checkout"
    else
      desc="marketplace hatsu at $mkt_root_canon (not this checkout)"
    fi
  fi

  set +e
  list_out="$(codex plugin list 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    readback="codex plugin list failed: $(one_line "$list_out")"
  else
    row="$(printf '%s\n' "$list_out" | codex_plugin_list_row)"
    if [ -z "$row" ]; then
      readback="no hatsu@hatsu row"
    else
      status_val="$(line1 "$row")"
      version_val="$(line2 "$row")"
      readback="hatsu@hatsu $status_val $version_val"
    fi
  fi
  report "codex" "status: $desc · $readback" "$root" "$codex_apply"
}

do_codex() {
  if [ "$status_mode" -eq 1 ]; then
    status_codex
    return 0
  fi

  if ! command -v codex >/dev/null 2>&1; then
    echo "hatsu-surface-link: codex is not on PATH" >&2
    exit 5
  fi

  local mkt_out mkt_root changes
  mkt_out="$(run_step "codex plugin marketplace list" codex plugin marketplace list)"
  mkt_root="$(printf '%s\n' "$mkt_out" | codex_marketplace_list_hatsu_root)"

  if [ -n "$mkt_root" ]; then
    local mkt_root_canon
    mkt_root_canon="$(canonical_directory "$mkt_root" 2>/dev/null || printf '%s' "$mkt_root")"
    if [ "$mkt_root_canon" = "$root" ]; then
      changes="marketplace hatsu already at this checkout"
    else
      echo "hatsu-surface-link: codex marketplace 'hatsu' already points at $mkt_root_canon, not $root -- refusing to override the maintainer's existing marketplace" >&2
      exit 3
    fi
  else
    would_run "codex plugin marketplace add $root"
    if [ "$dry_run" -eq 0 ]; then
      run_step "codex plugin marketplace add $root" codex plugin marketplace add "$root" >/dev/null
    fi
    changes="added marketplace hatsu"
  fi

  would_run "codex plugin add hatsu@hatsu"
  local add_out=""
  if [ "$dry_run" -eq 0 ]; then
    add_out="$(run_step "codex plugin add hatsu@hatsu" codex plugin add hatsu@hatsu)"
    changes="$changes · installed hatsu@hatsu"
  fi

  if [ "$dry_run" -eq 1 ]; then
    report "codex" "$changes · dry-run" "$root" "$codex_apply"
    return 0
  fi

  # Never `exit` early on a piped reader (see codex_marketplace_list_hatsu_root's
  # comment): read to EOF, keep only the FIRST match, print in END.
  local cache_path
  cache_path="$(printf '%s\n' "$add_out" | awk '
    !found && /^Installed plugin root: / {
      s = $0
      sub(/^Installed plugin root: /, "", s)
      result = s
      found = 1
    }
    END { if (found) print result }
  ')"

  local list_out row status_val version_val
  list_out="$(run_step "codex plugin list" codex plugin list)"
  row="$(printf '%s\n' "$list_out" | codex_plugin_list_row)"
  if [ -z "$row" ]; then
    echo "hatsu-surface-link: codex plugin list has no hatsu@hatsu row after install" >&2
    exit 1
  fi
  status_val="$(line1 "$row")"
  version_val="$(line2 "$row")"

  if [ "$status_val" != "installed, enabled" ]; then
    echo "hatsu-surface-link: codex plugin list shows hatsu@hatsu status '$status_val', expected 'installed, enabled'" >&2
    exit 1
  fi

  # WHICH MANIFEST CODEX ACTUALLY KEYS ITS SLOT ON. .codex-plugin/plugin.json
  # is Hatsu's own Codex overlay, but it did not exist before v0.64.0: a
  # checkout cut before then has no overlay at all, and Codex reads
  # .claude-plugin/plugin.json instead (there is no other manifest to read).
  # Comparing against an overlay that does not exist would refuse every such
  # checkout at exit 2 for carrying no defect -- so the compare falls back to
  # the Claude manifest, and the report says which one was used.
  local overlay_path="$root/.codex-plugin/plugin.json" compare_path compare_manifest compare_version
  if [ -f "$overlay_path" ]; then
    compare_path="$overlay_path"
    compare_manifest=".codex-plugin/plugin.json"
  else
    compare_path="$root/.claude-plugin/plugin.json"
    compare_manifest=".claude-plugin/plugin.json"
  fi
  compare_version="$(manifest_string_field "$compare_path" version)"
  if [ -z "$compare_version" ]; then
    echo "hatsu-surface-link: $compare_path has no readable version" >&2
    exit 2
  fi
  if [ "$version_val" != "$compare_version" ]; then
    echo "hatsu-surface-link: codex plugin list shows hatsu@hatsu version $version_val, but $compare_path's version is $compare_version" >&2
    exit 1
  fi

  changes="$changes · read back installed, enabled $version_val (compared against $compare_manifest)"
  local serves="${cache_path:-$root}"
  report "codex" "$changes" "$serves" "$codex_apply"
}

# ============================================================================
# antigravity
# ============================================================================

status_antigravity() {
  local dest="$1" desc canon raw readback out rc
  if [ -L "$dest" ]; then
    if canon="$(canonical_hatsu_target "$dest" "surfaces/antigravity")"; then
      if [ "$canon" = "$root/surfaces/antigravity" ]; then
        desc="linked to this checkout's surfaces/antigravity ($canon)"
      else
        desc="linked to another checkout's surfaces/antigravity ($canon)"
      fi
    else
      raw="$(readlink "$dest" 2>/dev/null || printf '<unreadable>')"
      desc="a symlink to $raw (not a Hatsu surfaces/antigravity, or dangling)"
    fi
  elif [ -e "$dest" ]; then
    desc="occupied by a real path (not a symlink)"
  else
    desc="absent"
  fi

  if command -v agy >/dev/null 2>&1; then
    set +e
    out="$(agy plugin validate "$dest" 2>&1)"
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
      readback="agy plugin validate: ok"
    else
      readback="agy plugin validate failed: $(one_line "$out")"
    fi
  else
    readback="agy not on PATH"
  fi

  report "antigravity" "status: $desc · $readback" "$dest" "$antigravity_apply"
}

do_antigravity() {
  local target="$root/surfaces/antigravity"
  if [ ! -d "$target" ] || [ ! -f "$target/plugin.json" ]; then
    echo "hatsu-surface-link: $target does not exist or has no plugin.json -- this checkout carries no generated Antigravity surface" >&2
    exit 2
  fi
  local dest="${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu"

  if [ "$status_mode" -eq 1 ]; then
    status_antigravity "$dest"
    return 0
  fi

  local changes out rc
  ensure_symlink "$dest" "$target" "surfaces/antigravity"
  changes="$ENSURE_SYMLINK_RESULT"

  if [ "$dry_run" -eq 1 ]; then
    report "antigravity" "$changes · dry-run" "$dest" "$antigravity_apply"
    return 0
  fi

  if command -v agy >/dev/null 2>&1; then
    set +e
    out="$(agy plugin validate "$dest" 2>&1)"
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
      echo "hatsu-surface-link: agy plugin validate $dest failed: $(one_line "$out")" >&2
      exit 1
    fi
    changes="$changes · agy plugin validate: ok"
  else
    changes="$changes · agy not on PATH: validate not done"
  fi
  report "antigravity" "$changes" "$dest" "$antigravity_apply"
}

case "$surface" in
  claude-code) do_claude_code ;;
  codex) do_codex ;;
  antigravity) do_antigravity ;;
esac
