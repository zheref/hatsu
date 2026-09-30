#!/usr/bin/env bash
# Keep a Hatsu plugin source current — a git checkout on trunk or the latest
# release tag, or Claude Code's versioned plugin cache via `claude plugin update`.
#
# ten calls this with --auto after Nen is satisfied and before it
# refreshes a target repository, so Codex/Cursor/Antigravity copies cannot
# silently serve last month's canon. Explicit invocation is the same command
# without --auto: dirty trees, authoring branches and missing remotes refuse
# instead of skipping.
#
# This script never discards work, never force-updates a diverged history, and
# never treats a Claude versioned plugin cache as a git checkout.
#
# THE MARKETPLACE SOURCE IS PART OF THE CLAIM (zheref/hatsu#118). `claude plugin
# update hatsu@hatsu` compares the versioned cache against the marketplace the
# plugin was installed from; for a Directory-source marketplace that is a git
# checkout, "already at the latest version" only means "the same version as
# that checkout", which nobody fast-forwards. So --claude first resolves the
# `hatsu` marketplace's directory from Claude Code's own registry
# (${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/known_marketplaces.json), and when it
# is a git checkout brings it current the same way this script brings any
# checkout current (trunk fast-forward, --auto semantics, never a discard) —
# or says, in the report line, exactly why it could not be verified (an
# authoring branch, a diverged trunk, a dirty tree, no origin, no fetch). The
# report never prints a bare "already at the latest version": the marketplace
# verdict rides beside it every time.
#
# Untracked files never block a trunk fast-forward: `git merge --ff-only`
# refuses on its own any fast-forward that would overwrite one (and that
# refusal is reported as a skip with its reason; an IGNORED file git would
# overwrite is caught by comparing the incoming paths with the ignored set
# before the merge), so only tracked modifications
# (staged or not) read as dirty. A checkout that is also a Claude Code
# marketplace source always carries an untracked .claude/ (worktrees,
# settings.local.json), and treating that as dirty is what left the checkout in
# #118 stale forever.
#
# TRUST. The marketplace checkout's `origin` is whatever the maintainer
# registered; nothing here checks it against zheref/hatsu, and what is
# fast-forwarded there is what `claude plugin update` installs next. That is the
# trunk channel by design: the trust anchors are that checkout's remote and its
# branch protection, exactly as for `--channel trunk` on any consumer checkout.
#
# THE IN-PLACE LINK TAKES PRIORITY OVER THE CACHE (observed live, 2026-09-29).
# Claude Code 2.1.284 copies a local-directory marketplace install into
# plugins/cache/hatsu/hatsu/<version>; a symlink at
# ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/hatsu onto a Hatsu git checkout loads
# that checkout IN PLACE as hatsu@skills-dir instead, and an installed
# hatsu@hatsu SHADOWS it. So --claude checks that link first: when it resolves
# to a Hatsu git checkout, THAT checkout is what gets brought current — never
# `claude plugin update`, which only ever compares a versioned cache slot — and
# the report says whether a shadowing hatsu@hatsu cache install needs
# retargeting instead (scripts/hatsu_surface_link.sh --surface claude-code).
# --codex mirrors the same idea for Codex 0.154.0's own `codex plugin add
# hatsu@hatsu`, which copies the WHOLE plugin root — .git included — into its
# own cache slot under $CODEX_HOME, by resolving the `hatsu` marketplace root
# through `codex plugin marketplace list` and bringing THAT current first.
#
# A SURFACE'S OWN PLUGIN CACHE IS NEVER GIT-PULLED, even when it carries a real
# .git (Codex's copy does): any --root whose path runs through a
# `plugins/cache/` directory is routed straight to the not-a-git-checkout
# report, naming itself a surface plugin cache, rather than fast-forwarded as
# if it were the maintainer's own checkout.

set -euo pipefail
LC_ALL=C

usage() {
  cat <<'EOF'
usage: scripts/hatsu_plugin_update.sh [--root <path>] [--channel auto|trunk|release]
                                      [--from <branch>] [--auto] [--dry-run]
                                      [--claude | --codex]

--root      Plugin checkout to update. Defaults to $HATSU_PLUGIN_ROOT, else this
            script's own Hatsu checkout.
--channel   auto (default): trunk if HEAD is on the trunk, release if HEAD is at
            a vX.Y.Z tag, otherwise skip (with --auto) or refuse.
            trunk: fast-forward origin/<from>.
            release: check out the newest vX.Y.Z tag (no pre-release suffix).
--from      Trunk branch for --channel trunk. Defaults to nen/workflow.json
            branch.base, else main.
--auto      Warm-up mode: skip (exit 0) when the checkout is not a consumer
            channel, is dirty, diverged, or cannot fetch. Never discards.
--dry-run   Print the plan; mutate nothing.
--claude    After a git update — or instead of one, when --root is a surface's
            own plugin cache — refresh what Claude Code serves. When
            ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/hatsu is a symlink onto a
            Hatsu git checkout (the in-place `hatsu@skills-dir` install), THAT
            checkout is what gets brought current instead (never `claude
            plugin marketplace update` / `claude plugin update` in this case),
            and the report names whether a cached `hatsu@hatsu` install
            shadows it (retarget: scripts/hatsu_surface_link.sh --surface
            claude-code). Otherwise, bring the `hatsu` marketplace's Directory
            source current when it is a git checkout (or say why it could not
            be), then run `claude plugin marketplace update` and
            `claude plugin update hatsu@hatsu -y`. Apply: type /reload-plugins
            in the running session, or open a new session. Mutually exclusive
            with --codex.
--codex     After a git update — or instead of one, when --root is a surface's
            own plugin cache — resolve the `hatsu` marketplace root from
            `codex plugin marketplace list`, bring it current (`codex plugin
            marketplace upgrade hatsu` when Codex manages it under
            ${CODEX_HOME:-~/.codex}, otherwise a git fast-forward of that
            checkout, unless it is already --root), then run `codex plugin add
            hatsu@hatsu` and read back the installed version. Apply: a running
            Codex session refreshes skills and hooks after an external plugin
            upgrade (codex-cli 0.154.0); open a new one if it does not.
            Mutually exclusive with --claude.
EOF
}

root_input=""
channel="auto"
from_input=""
auto=0
dry_run=0
claude_update=0
codex_update=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      root_input="$2"
      shift 2
      ;;
    --channel)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      channel="$2"
      shift 2
      ;;
    --from)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      from_input="$2"
      shift 2
      ;;
    --auto)
      auto=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --claude)
      claude_update=1
      shift
      ;;
    --codex)
      codex_update=1
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

case "$channel" in auto|trunk|release) ;; *)
  echo "--channel must be auto, trunk, or release" >&2
  exit 2
  ;;
esac

if [ "$claude_update" -eq 1 ] && [ "$codex_update" -eq 1 ]; then
  echo "hatsu-plugin-update: --claude and --codex are mutually exclusive" >&2
  usage >&2
  exit 2
fi

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

plugin_version() {
  awk '
    /^  "version": "/ {
      s = $0
      sub(/^  "version": "/, "", s)
      sub(/",?$/, "", s)
      print s
      exit
    }
  ' "$1/.claude-plugin/plugin.json"
}

trunk_from_workflow() {
  [ -f "$1/nen/workflow.json" ] || return 0
  awk '
    $0 ~ /^  "branch": \{/ { inb = 1; next }
    inb && $0 ~ /^  \}/ { exit }
    inb && $0 ~ /^    "base": "/ {
      s = $0
      sub(/^    "base": "/, "", s)
      sub(/",?$/, "", s)
      print s
      exit
    }
  ' "$1/nen/workflow.json"
}

is_stable_release_tag() {
  printf '%s\n' "$1" | awk '/^v[0-9]+\.[0-9]+\.[0-9]+$/ { found=1 } END { exit found ? 0 : 1 }'
}

latest_release_tag() {
  local tag
  while IFS= read -r tag; do
    if is_stable_release_tag "$tag"; then
      printf '%s\n' "$tag"
      return 0
    fi
  done <<EOF
$(git -C "$1" tag --list 'v[0-9]*' --sort=-v:refname)
EOF
  return 1
}

# Where THIS script is, from BASH_SOURCE and never $0: under `bash -s < script` or when sourced,
# $0 is `bash`, and a self re-entry built from it would execute `./bash` from the working directory
# (Feitan, zheref/hatsu#118 review). self_script is re-entered as `bash "$self_script"` so neither
# an executable bit nor a shebang is trusted, and only when it is a regular file at that path.
self_source="${BASH_SOURCE[0]:-$0}"
case "$self_source" in
  */*) script_base="${self_source%/*}" ;;
  *) script_base='.' ;;
esac
script_dir="$(canonical_directory "$script_base")" || {
  echo "hatsu-plugin-update: cannot canonicalize its script directory" >&2
  exit 2
}
self_script="$script_dir/${self_source##*/}"
[ -f "$self_script" ] || self_script=""
script_hatsu="$(canonical_directory "$script_dir/..")" || {
  echo "hatsu-plugin-update: cannot canonicalize its checkout" >&2
  exit 2
}

root_candidate="${root_input:-${HATSU_PLUGIN_ROOT:-$script_hatsu}}"
root="$(canonical_directory "$root_candidate")" || {
  echo "hatsu-plugin-update: --root is not a usable directory: $root_candidate" >&2
  exit 2
}

if ! is_hatsu "$root"; then
  echo "hatsu-plugin-update: $root is not a Hatsu checkout (.claude-plugin/plugin.json top-level name must be hatsu, with claude/skills/)" >&2
  exit 3
fi

# is_hatsu is a filesystem identity check. git -C does not win over an already-set
# GIT_DIR / GIT_WORK_TREE, so clear the redirectors before any git mutation.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_INDEX_FILE GIT_PREFIX

plugin_ver="$(plugin_version "$root")"
[ -n "$plugin_ver" ] || plugin_ver='unknown'

report() {
  printf 'hatsu-plugin-update: %s · plugin %s\n' "$1" "$plugin_ver"
}

skip_or_refuse() {
  local why="$1"
  if [ "$auto" -eq 1 ]; then
    report "skipped · $why"
    exit 0
  fi
  echo "hatsu-plugin-update: refused · $why" >&2
  exit 2
}

would() {
  if [ "$dry_run" -eq 1 ]; then
    printf 'would run: %s\n' "$1"
  fi
}

# marketplace_directory_source — the ABSOLUTE directory the `hatsu` marketplace points at in Claude
# Code's own registry, or nothing (no registry, no `hatsu` entry, a GitHub-sourced one, a registry
# not in the one shape read, or a relative path). One shape is read, the JSON.stringify(x, null, 2)
# Claude Code writes; JSON's \\ and \" in the path are undone, any other escape is left as is (the
# path then does not exist and reads as not verified, the safe direction).
marketplace_directory_source() {
  local registry="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/known_marketplaces.json"
  [ -r "$registry" ] || return 1
  awk '
    /^  "hatsu": \{$/ { inm = 1; next }
    inm && /^  \},?$/ { exit }
    inm && /^    "source": \{$/ { ins = 1; next }
    inm && ins && /^    \},?$/ { ins = 0; next }
    inm && ins && /^      "source": "directory",?$/ { isdir = 1; next }
    inm && ins && /^      "path": "/ {
      s = $0; sub(/^      "path": "/, "", s); sub(/",?$/, "", s)
      gsub(/\\"/, "\"", s); gsub(/\\\\/, "\\", s); path = s; next
    }
    END { if (isdir && path ~ /^\//) print path }
  ' "$registry"
}

# one_line TEXT — the last non-empty line of TEXT, control characters stripped, capped at 200
# characters: what a report line may carry of a subprocess's output (Feitan, log hygiene).
one_line() {
  printf '%s\n' "$1" | awk 'NF { line = $0 } END { print line }' | tr -d '\000-\037' | cut -c1-200
}

# marketplace_verdict — sets MKT_VERDICT, one clause for the report line: what happened to the
# marketplace source. A git checkout is brought current by THIS script (trunk channel, --auto
# semantics, never a discard); anything else is stated as unverified with its reason. Never silent,
# never a claim. The sub-run's own `would run:` lines pass straight through to stdout.
MKT_VERDICT=""
marketplace_verdict() {
  local mkt canon_mkt sub_out sub_line sub_rc
  mkt="$(marketplace_directory_source || true)"
  if [ -z "$mkt" ]; then
    if [ -r "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/known_marketplaces.json" ]; then
      MKT_VERDICT="marketplace source: the registry is present but no hatsu Directory source parsed from it (no hatsu entry, GitHub-sourced, not an absolute path, or not the one shape Claude Code writes) — not verified against origin"
    else
      MKT_VERDICT="marketplace source: no readable known_marketplaces.json under ${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/plugins — not verified against origin"
    fi
    return 0
  fi
  canon_mkt="$(canonical_directory "$mkt" 2>/dev/null || printf '%s' "$mkt")"
  if [ "$canon_mkt" = "$root" ]; then
    MKT_VERDICT="marketplace source is this checkout"
    return 0
  fi
  if ! git -C "$canon_mkt" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    MKT_VERDICT="marketplace source $canon_mkt is not a git checkout — not verified against origin"
    return 0
  fi
  if [ -z "$self_script" ]; then
    MKT_VERDICT="marketplace source $canon_mkt not examined: the updater cannot locate itself to re-enter (run it by path) — not verified against origin"
    return 0
  fi
  # Re-enter this script on the marketplace checkout: --auto so a checkout that cannot be brought
  # current SKIPS with its reason rather than refusing the Claude refresh outright. Its report line
  # is the verdict, verbatim after the prefix and minus its own plugin suffix. The sub-run is THIS
  # file's copy, which may be older than the checkout it updates: it fast-forwards and reports, and
  # the next warm-up runs the newer copy.
  local -a sub_args=(--root "$canon_mkt" --channel auto --auto)
  [ "$dry_run" -eq 1 ] && sub_args+=(--dry-run)
  set +e
  sub_out="$(bash "$self_script" "${sub_args[@]}" 2>&1)"
  sub_rc=$?
  set -e
  printf '%s\n' "$sub_out" | grep '^would run: ' || true
  sub_line="$(printf '%s\n' "$sub_out" | awk '/^hatsu-plugin-update: /{ line = $0 } END { sub(/ · plugin [^ ]+$/, "", line); print line }')"
  case "$sub_line" in
    'hatsu-plugin-update: skipped · '*)
      MKT_VERDICT="marketplace source $canon_mkt NOT brought current: ${sub_line#hatsu-plugin-update: skipped · } — claude plugin update compares against that checkout as it stands"
      ;;
    'hatsu-plugin-update: '*)
      MKT_VERDICT="marketplace source $canon_mkt: ${sub_line#hatsu-plugin-update: }"
      ;;
    *)
      MKT_VERDICT="marketplace source $canon_mkt: could not be examined (sub-run exit $sub_rc: $(one_line "${sub_out:-no output}")) — not verified against origin"
      ;;
  esac
}

# reenter_verdict TARGET — bring TARGET current by re-entering this script on it with the
# --channel/--from/--dry-run this run was given, and --auto only when this run had it. This is the
# "as given" re-entry form used by the --claude in-place link and the --codex local marketplace
# root — distinct from marketplace_verdict's own sub-run, which always forces --channel auto --auto
# because the marketplace checkout there is a side concern the primary flow must not fail over.
# Sets REENTER_VERDICT; the sub-run's own `would run:` lines pass straight through to stdout.
REENTER_VERDICT=""
reenter_verdict() {
  local target="$1" sub_out sub_rc sub_line
  if [ -z "$self_script" ]; then
    REENTER_VERDICT="not examined: the updater cannot locate itself to re-enter (run it by path)"
    return 0
  fi
  local -a sub_args=(--root "$target" --channel "$channel")
  [ -n "$from_input" ] && sub_args+=(--from "$from_input")
  [ "$auto" -eq 1 ] && sub_args+=(--auto)
  [ "$dry_run" -eq 1 ] && sub_args+=(--dry-run)
  set +e
  sub_out="$(bash "$self_script" "${sub_args[@]}" 2>&1)"
  sub_rc=$?
  set -e
  printf '%s\n' "$sub_out" | grep '^would run: ' || true
  sub_line="$(printf '%s\n' "$sub_out" | awk '/^hatsu-plugin-update: /{ line = $0 } END { sub(/ · plugin [^ ]+$/, "", line); print line }')"
  case "$sub_line" in
    'hatsu-plugin-update: '*)
      REENTER_VERDICT="${sub_line#hatsu-plugin-update: }"
      ;;
    *)
      REENTER_VERDICT="could not be examined (sub-run exit $sub_rc: $(one_line "${sub_out:-no output}"))"
      ;;
  esac
}

# installed_plugins_has_hatsu REGISTRY — true when Claude Code's installed_plugins.json records a
# top-level "hatsu@hatsu" entry (JSON.stringify(x, null, 2) shape, read the same way
# marketplace_directory_source reads known_marketplaces.json): a cached hatsu@hatsu install takes
# precedence over the in-place skills/hatsu link and needs retargeting.
installed_plugins_has_hatsu() {
  local registry="$1"
  [ -r "$registry" ] || return 1
  awk '/^  "hatsu@hatsu": \{$/ { found = 1 } END { exit found ? 0 : 1 }' "$registry"
}

# codex_marketplace_root — the ABSOLUTE root the `hatsu` marketplace resolves to in `codex plugin
# marketplace list` (header "MARKETPLACE  ROOT", then rows like "hatsu   /abs/root"): the row whose
# first whitespace-separated field is exactly `hatsu`, root is the rest of the line after that run
# of spaces. Nothing when Codex has no such marketplace. A real `codex plugin marketplace list` can
# print thousands of rows; an awk that `exit`s the moment it finds `hatsu` closes its end of the
# pipe while `codex` may still be writing later rows, and under this script's `pipefail` that
# SIGPIPE (codex killed writing to a closed pipe) surfaces as the PIPELINE's exit status even
# though awk itself succeeded — a silent 141 a caller's `|| true` masks the symptom of but not the
# cause. So the match is held in a variable and printed only from END, reading every row.
codex_marketplace_root() {
  codex plugin marketplace list 2>/dev/null | awk '
    $1 == "hatsu" && !found {
      line = $0
      sub(/^hatsu[ \t]+/, "", line)
      found = 1
    }
    END { if (found) print line }
  '
}

# codex_plugin_version — the version field off the `hatsu@hatsu` row of `codex plugin list`
# (header "PLUGIN  STATUS  VERSION  SOURCE", e.g. "hatsu@hatsu  installed, enabled  0.59.1
# /abs/source"). The STATUS column itself carries an embedded space ("installed, enabled"), so a
# plain whitespace split misaligns VERSION into field 4; columns are separated by RUNS of two or
# more spaces instead, which the STATUS value's own single space never produces. `codex plugin
# list` can print thousands of rows too, so — same reason as codex_marketplace_root above — the
# match is held and printed only from END rather than `exit`ing mid-stream and SIGPIPE-ing `codex`.
codex_plugin_version() {
  codex plugin list 2>/dev/null | awk -F'  +' '
    $1 == "hatsu@hatsu" && !found {
      ver = $3
      found = 1
    }
    END { if (found) print ver }
  '
}

# claude_refresh_link TARGET AFTER_GIT — the in-place `hatsu@skills-dir` install: TARGET is what
# ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/hatsu resolves to. Bring it current (unless it IS --root,
# already brought current above), say whether a cached hatsu@hatsu install shadows it, and stop —
# `claude plugin marketplace update` / `claude plugin update` are never invoked here (#118's
# comparison-against-a-stale-cache problem does not exist when Claude loads the checkout directly).
claude_refresh_link() {
  local target="$1" after_git="${2:-}" note tail installed
  if [ "$target" = "$root" ]; then
    note="in-place link $target"
  else
    reenter_verdict "$target"
    if [ "$dry_run" -eq 1 ]; then
      report "${after_git:+$after_git · }in-place link $target: $REENTER_VERDICT · dry-run"
      exit 0
    fi
    note="in-place link $target: $REENTER_VERDICT"
  fi
  installed="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json"
  if installed_plugins_has_hatsu "$installed"; then
    tail="hatsu@hatsu (a cached marketplace install) shadows the in-place link; retarget: scripts/hatsu_surface_link.sh --surface claude-code"
  else
    tail="served in place from $target (hatsu@skills-dir)"
  fi
  report "${after_git:+$after_git · }$note · $tail · apply: type /reload-plugins in the running session, or open a new session"
  exit 0
}

claude_refresh() {
  local after_git="${1:-}" mkt_verdict mkt_path mkt_ver cache_note link link_canon
  link="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/hatsu"
  if [ -L "$link" ]; then
    link_canon="$(canonical_directory "$link" 2>/dev/null || true)"
    case "$link_canon" in
      */plugins/cache/*) link_canon="" ;;  # a link into a surface's own cache is not "served in place"
    esac
    if [ -n "$link_canon" ] && is_hatsu "$link_canon" && git -C "$link_canon" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      claude_refresh_link "$link_canon" "$after_git"
    fi
  fi
  if ! command -v claude >/dev/null 2>&1; then
    if [ -n "$after_git" ]; then
      skip_or_refuse "$after_git · Claude Code refresh skipped (claude not on PATH). Run: claude plugin update hatsu@hatsu -y"
    fi
    skip_or_refuse "Claude Code plugin cache (v$plugin_ver); claude is not on PATH. Run: claude plugin marketplace update && claude plugin update hatsu@hatsu -y"
  fi
  # The marketplace source first (#118): what `claude plugin update` will compare against.
  marketplace_verdict
  mkt_verdict="$MKT_VERDICT"
  would "claude plugin marketplace update"
  would "claude plugin update hatsu@hatsu -y"
  if [ "$dry_run" -eq 1 ]; then
    report "${after_git:+$after_git · }$mkt_verdict · dry-run · claude plugin update hatsu@hatsu"
    exit 0
  fi
  # Marketplace name may be absent on a host that installed from a path; updating
  # all marketplaces then the plugin is the documented Claude Code refresh.
  claude plugin marketplace update >/dev/null 2>&1 || true
  if claude plugin update hatsu@hatsu -y; then
    # A versioned cache path names ONE version forever, so re-reading $root cannot see a newer
    # slot; the marketplace source's own manifest says what the cache should now hold.
    cache_note=""
    mkt_path="$(marketplace_directory_source || true)"
    if [ -n "$mkt_path" ] && [ -f "$mkt_path/.claude-plugin/plugin.json" ]; then
      mkt_ver="$(plugin_version "$mkt_path" 2>/dev/null || true)"
      if [ -n "$mkt_ver" ] && [ "$mkt_ver" != "$plugin_ver" ]; then
        cache_note=" · marketplace source at v$mkt_ver, this cache slot is v$plugin_ver (a newer slot is installed beside it, or the update did not move)"
      fi
    fi
    plugin_ver="$(plugin_version "$root" 2>/dev/null || printf '%s' "$plugin_ver")"
    report "${after_git:+$after_git · }$mkt_verdict · claude plugin updated$cache_note · cached install: retarget in place with scripts/hatsu_surface_link.sh --surface claude-code · apply: type /reload-plugins in the running session, or open a new session"
    exit 0
  fi
  if [ -n "$after_git" ]; then
    skip_or_refuse "$after_git · $mkt_verdict · claude plugin update hatsu@hatsu failed; run it yourself, then apply: type /reload-plugins in the running session, or open a new session"
  fi
  skip_or_refuse "$mkt_verdict · claude plugin update hatsu@hatsu failed. Run it yourself, then apply: type /reload-plugins in the running session, or open a new session"
}

# codex_refresh AFTER_GIT — mirrors claude_refresh for Codex 0.154.0: resolve the `hatsu`
# marketplace root from `codex plugin marketplace list`, bring it current (a Codex-managed snapshot
# under $CODEX_HOME upgrades itself; a local checkout that is not --root is re-entered exactly as
# --claude's in-place link is), then `codex plugin add hatsu@hatsu` and read back the installed
# version. --dry-run touches the `codex` binary not at all beyond the initial PATH check — every
# step is a `would run:` line, mirroring --claude's own zero-invocation dry run.
codex_refresh() {
  local after_git="${1:-}" mkt_root canon_mkt codex_home is_managed verdict ver
  if ! command -v codex >/dev/null 2>&1; then
    skip_or_refuse "${after_git:+$after_git · }codex not on PATH"
  fi
  if [ "$dry_run" -eq 1 ]; then
    would "codex plugin marketplace list"
    would "codex plugin marketplace upgrade hatsu"
    would "codex plugin add hatsu@hatsu"
    report "${after_git:+$after_git · }dry-run · codex plugin add hatsu@hatsu"
    exit 0
  fi
  mkt_root="$(codex_marketplace_root || true)"
  if [ -z "$mkt_root" ]; then
    skip_or_refuse "${after_git:+$after_git · }no hatsu marketplace in Codex; install first-party: scripts/hatsu_surface_link.sh --surface codex"
  fi
  canon_mkt="$(canonical_directory "$mkt_root" 2>/dev/null || printf '%s' "$mkt_root")"
  codex_home="$(canonical_directory "${CODEX_HOME:-$HOME/.codex}" 2>/dev/null || true)"
  is_managed=0
  if [ -n "$codex_home" ]; then
    case "$canon_mkt" in
      "$codex_home"/*) is_managed=1 ;;
    esac
  fi
  if [ "$is_managed" -eq 1 ]; then
    codex plugin marketplace upgrade hatsu >/dev/null 2>&1 \
      || skip_or_refuse "${after_git:+$after_git · }codex plugin marketplace upgrade hatsu failed"
    verdict="codex-managed marketplace root $canon_mkt upgraded"
  elif [ "$canon_mkt" = "$root" ]; then
    verdict="marketplace root is this checkout"
  else
    reenter_verdict "$canon_mkt"
    verdict="marketplace root $canon_mkt: $REENTER_VERDICT"
  fi
  if codex plugin add hatsu@hatsu >/dev/null 2>&1; then
    ver="$(codex_plugin_version || true)"
    report "${after_git:+$after_git · }$verdict · codex plugin hatsu@hatsu at v${ver:-unknown} · apply: running Codex sessions refresh skills and hooks after an external plugin upgrade (codex-cli 0.154.0); if one does not, open a new session"
    exit 0
  fi
  skip_or_refuse "${after_git:+$after_git · }$verdict · codex plugin add hatsu@hatsu failed"
}

is_git_worktree() {
  local top
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || return 1
  top="$(canonical_directory "$top")" || return 1
  [ "$top" = "$root" ]
}

# A surface's OWN plugin cache — Claude's versioned slot, or Codex's copy of the whole plugin root
# (which carries a real .git, per HA-BAKURYUHA-88d5f6): never git-pulled here, no matter what it
# carries, so this is checked by PATH alone, before is_git_worktree ever runs `git` against it.
surface_cache=0
case "$root" in
  */plugins/cache/*) surface_cache=1 ;;
esac

if [ "$surface_cache" -eq 0 ] && [ -e "$root/.git" ]; then
  if ! is_git_worktree; then
    skip_or_refuse "git metadata unreadable"
  fi
elif [ "$surface_cache" -eq 1 ] || ! is_git_worktree; then
  if [ "$claude_update" -eq 1 ]; then
    claude_refresh
  fi
  if [ "$codex_update" -eq 1 ]; then
    codex_refresh
  fi
  if [ "$surface_cache" -eq 1 ]; then
    if [ "$auto" -eq 1 ]; then
      report "skipped · surface plugin cache v$plugin_ver (a surface's own copied install; never git-pulled here) · Claude: claude plugin update hatsu@hatsu -y · Codex: codex plugin add hatsu@hatsu"
      exit 0
    fi
    echo "hatsu-plugin-update: $root is a surface plugin cache (v$plugin_ver) — a surface's own copied plugin install (Claude Code's versioned cache, or Codex's copy of the whole plugin root, .git included). It is never git-pulled here. Refresh through the surface's own update path instead:" >&2
    echo "  Claude Code: claude plugin marketplace update && claude plugin update hatsu@hatsu -y" >&2
    echo "  Codex:       codex plugin marketplace upgrade hatsu (or a git fast-forward of its checkout) && codex plugin add hatsu@hatsu" >&2
    echo "Or clone zheref/hatsu and point the surface at that checkout — docs/SURFACES.md § Targeting a local checkout." >&2
    exit 4
  fi
  if [ "$auto" -eq 1 ]; then
    report "skipped · Claude versioned plugin cache v$plugin_ver · run: claude plugin update hatsu@hatsu -y (apply: type /reload-plugins in the running session, or open a new session)"
    exit 0
  fi
  echo "hatsu-plugin-update: $root is a Hatsu tree but not a git checkout (Claude versioned plugin cache v$plugin_ver). It cannot be git-pulled. Run:" >&2
  echo "  claude plugin marketplace update" >&2
  echo "  claude plugin update hatsu@hatsu -y" >&2
  echo "then type /reload-plugins in the running session, or open a new session. Or clone zheref/hatsu and point the surface at that checkout — docs/SURFACES.md § Targeting a local checkout." >&2
  exit 4
fi

trunk="${from_input:-$(trunk_from_workflow "$root")}"
[ -n "$trunk" ] || trunk="main"

branch="$(git -C "$root" branch --show-current 2>/dev/null || true)"
detached_at=""
if [ -z "$branch" ]; then
  detached_at="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || true)"
fi
exact_tag="$(git -C "$root" describe --tags --exact-match 2>/dev/null || true)"
# Tracked modifications only: an untracked file never blocks a fast-forward, and git itself
# refuses one that would overwrite it (see the header, #118).
porcelain="$(git -C "$root" status --porcelain=v1 --untracked-files=no)"
untracked_count="$(git -C "$root" status --porcelain=v1 -uall | awk '/^\?\? /{ n++ } END { if (n) print n }')"

if [ -n "$porcelain" ]; then
  skip_or_refuse "dirty working copy (tracked changes) · staying at ${branch:-detached $detached_at}"
fi

detected="$channel"
if [ "$channel" = "auto" ]; then
  if [ -n "$branch" ]; then
    if [ "$branch" = "$trunk" ]; then
      detected="trunk"
    else
      detected=""
    fi
  elif [ -n "$exact_tag" ]; then
    if is_stable_release_tag "$exact_tag"; then
      detected="release"
    else
      detected=""
    fi
  else
    detected=""
  fi
  if [ -z "$detected" ]; then
    skip_or_refuse "authoring checkout (${branch:-detached ${detached_at:-HEAD}}) · not a consumer channel"
  fi
fi

if [ "$detected" = "trunk" ] && [ "$branch" != "$trunk" ]; then
  skip_or_refuse "HEAD is ${branch:-detached ${detached_at:-HEAD}}, not trunk '$trunk'"
fi

if [ "$detected" = "release" ] && [ "$channel" != "auto" ] && [ -n "$branch" ] && [ "$branch" != "$trunk" ]; then
  skip_or_refuse "release channel refuses a feature branch ($branch); check out a tag or the trunk first"
fi

# `grep -q` exits the moment it finds a match, closing its end of the pipe while `git remote` may
# still be writing — under this script's `pipefail` that SIGPIPE would surface as the pipeline's
# exit status. `git remote` output is small in practice, but the fix costs nothing: match without
# `-q`, output suppressed by redirection instead, so grep reads every remote name to completion.
if ! git -C "$root" remote | grep -x origin >/dev/null; then
  skip_or_refuse "no origin remote"
fi

if [ "$detected" = "trunk" ]; then
  would "git fetch origin"
  if [ "$dry_run" -eq 0 ]; then
    if ! git -C "$root" fetch origin; then
      skip_or_refuse "git fetch origin failed"
    fi
  fi
  if ! git -C "$root" show-ref --verify --quiet "refs/remotes/origin/$trunk"; then
    skip_or_refuse "origin/$trunk does not exist${dry_run:+ · dry-run cannot plan a fast-forward without that ref}"
  fi
  if ! git -C "$root" merge-base --is-ancestor HEAD "origin/$trunk"; then
    skip_or_refuse "local trunk diverged from origin/$trunk · refusing a non-ff update"
  fi
  before="$(git -C "$root" rev-parse --short HEAD)"
  would "git merge --ff-only origin/$trunk"
  if [ "$dry_run" -eq 1 ]; then
    # Set the verdict and fall through to --claude/--codex below (never exit here): with neither
    # flag, the bottom-of-script `report "$git_result"; exit 0` reproduces this exact line byte for
    # byte, and with one, its own `would run:` lines print beside this git plan instead of never
    # being reached (HA-BAKURYUHA-88d5f6 follow-up).
    git_result="dry-run · would fast-forward $trunk from $before"
  else
    # git refuses a fast-forward that would overwrite an UNTRACKED file, but it silently overwrites
    # an IGNORED one (Copilot, HA-PR-#121 round 2): compare the incoming paths with the ignored set
    # first and skip on any intersection, naming the paths. That keeps "never discards work" true
    # for a file .gitignore hides as well as for one it does not.
    incoming="$(git -C "$root" diff --name-only HEAD "origin/$trunk" 2>/dev/null || true)"
    ignored_hits="$(git -C "$root" ls-files --others --ignored --exclude-standard 2>/dev/null | grep -Fxf <(printf '%s\n' "$incoming") 2>/dev/null || true)"
    if [ -n "$ignored_hits" ]; then
      skip_or_refuse "fast-forward would overwrite ignored file(s): $(printf '%s' "$ignored_hits" | tr '\n' ' ' | cut -c1-200)· staying at $trunk @$before"
    fi
    # git refuses a fast-forward that would overwrite an untracked file: that refusal is a SKIP with
    # its reason, never a bare death under `set -e` (Chrollo, zheref/hatsu#118 review).
    ff_err="$(git -C "$root" merge --ff-only "origin/$trunk" 2>&1 >/dev/null)" \
      || skip_or_refuse "fast-forward refused by git: $(one_line "${ff_err:-no reason printed}") · staying at $trunk @$before"
    after="$(git -C "$root" rev-parse --short HEAD)"
    plugin_ver="$(plugin_version "$root")"
    if [ "$before" = "$after" ]; then
      git_result="already current · trunk $trunk @$after${untracked_count:+ · $untracked_count untracked, not blocking}"
    else
      git_result="updated trunk $trunk $before..$after${untracked_count:+ · $untracked_count untracked, not blocking}"
    fi
  fi
elif [ "$detected" = "release" ]; then
  would "git fetch origin --tags"
  if [ "$dry_run" -eq 0 ]; then
    if ! git -C "$root" fetch origin --tags; then
      skip_or_refuse "git fetch origin --tags failed"
    fi
    tag="$(latest_release_tag "$root" || true)"
  else
    tag=""
    while IFS= read -r candidate; do
      [ -n "$candidate" ] || continue
      if is_stable_release_tag "$candidate"; then
        tag="$candidate"
        break
      fi
    done <<EOF
$(git -C "$root" ls-remote --tags --refs origin 'v[0-9]*' 2>/dev/null | awk '{ print $2 }' | sed 's#^refs/tags/##' | sort -V -r)
EOF
    if [ -z "$tag" ]; then
      tag="$(latest_release_tag "$root" || true)"
    fi
  fi
  if [ -z "$tag" ]; then
    skip_or_refuse "no vX.Y.Z release tags on this checkout"
  fi
  if [ "$exact_tag" = "$tag" ]; then
    # Set the verdict and fall through (never exit here) — see the trunk branch's own comment above.
    if [ "$dry_run" -eq 1 ]; then
      git_result="dry-run · already at release $tag"
    else
      git_result="already current · release $tag"
    fi
  else
    would "git checkout --detach $tag"
    if [ "$dry_run" -eq 1 ]; then
      git_result="dry-run · would check out release $tag (from ${exact_tag:-$branch})"
    else
      git -C "$root" checkout --detach "$tag" >/dev/null 2>&1 || skip_or_refuse "could not check out $tag"
      plugin_ver="$(plugin_version "$root")"
      git_result="updated release ${exact_tag:-$branch} → $tag"
    fi
  fi
else
  echo "hatsu-plugin-update: internal error: unknown channel '$detected'" >&2
  exit 2
fi

if [ "$claude_update" -eq 1 ]; then
  claude_refresh "$git_result"
fi
if [ "$codex_update" -eq 1 ]; then
  codex_refresh "$git_result"
fi

report "$git_result"
exit 0
