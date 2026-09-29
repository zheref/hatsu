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
# refusal is reported as a skip with its reason), so only tracked modifications
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

set -euo pipefail
LC_ALL=C

usage() {
  cat <<'EOF'
usage: scripts/hatsu_plugin_update.sh [--root <path>] [--channel auto|trunk|release]
                                      [--from <branch>] [--auto] [--dry-run] [--claude]

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
--claude    After a git update — or instead of one, when --root is a versioned
            plugin cache — bring the `hatsu` marketplace's Directory source
            current when it is a git checkout (or say why it could not be), then
            run `claude plugin marketplace update` and
            `claude plugin update hatsu@hatsu -y`. Restart Claude Code to apply.
EOF
}

root_input=""
channel="auto"
from_input=""
auto=0
dry_run=0
claude_update=0

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

claude_refresh() {
  local after_git="${1:-}" mkt_verdict mkt_path mkt_ver cache_note
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
    report "${after_git:+$after_git · }$mkt_verdict · claude plugin updated$cache_note · restart Claude Code to apply"
    exit 0
  fi
  if [ -n "$after_git" ]; then
    skip_or_refuse "$after_git · $mkt_verdict · claude plugin update hatsu@hatsu failed; run it yourself, then restart Claude Code"
  fi
  skip_or_refuse "$mkt_verdict · claude plugin update hatsu@hatsu failed. Run it yourself, then restart Claude Code"
}

is_git_worktree() {
  local top
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || return 1
  top="$(canonical_directory "$top")" || return 1
  [ "$top" = "$root" ]
}

if [ -e "$root/.git" ]; then
  if ! is_git_worktree; then
    skip_or_refuse "git metadata unreadable"
  fi
elif ! is_git_worktree; then
  if [ "$claude_update" -eq 1 ]; then
    claude_refresh
  fi
  if [ "$auto" -eq 1 ]; then
    report "skipped · Claude versioned plugin cache v$plugin_ver · run: claude plugin update hatsu@hatsu -y (restart required)"
    exit 0
  fi
  echo "hatsu-plugin-update: $root is a Hatsu tree but not a git checkout (Claude versioned plugin cache v$plugin_ver). It cannot be git-pulled. Run:" >&2
  echo "  claude plugin marketplace update" >&2
  echo "  claude plugin update hatsu@hatsu -y" >&2
  echo "then restart Claude Code. Or clone zheref/hatsu and point the surface at that checkout — docs/SURFACES.md § Targeting a local checkout." >&2
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

if ! git -C "$root" remote | grep -qx origin; then
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
    report "dry-run · would fast-forward $trunk from $before"
    exit 0
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
    if [ "$dry_run" -eq 1 ]; then
      report "dry-run · already at release $tag"
      exit 0
    fi
    git_result="already current · release $tag"
  else
    would "git checkout --detach $tag"
    if [ "$dry_run" -eq 1 ]; then
      report "dry-run · would check out release $tag (from ${exact_tag:-$branch})"
      exit 0
    fi
    git -C "$root" checkout --detach "$tag" >/dev/null 2>&1 || skip_or_refuse "could not check out $tag"
    plugin_ver="$(plugin_version "$root")"
    git_result="updated release ${exact_tag:-$branch} → $tag"
  fi
else
  echo "hatsu-plugin-update: internal error: unknown channel '$detected'" >&2
  exit 2
fi

if [ "$claude_update" -eq 1 ]; then
  claude_refresh "$git_result"
fi

report "$git_result"
exit 0
