#!/usr/bin/env bash
# Materialise exactly one committed Hatsu tree for Codex's copying marketplace.
# A commit-named directory is immutable: a changed existing snapshot is refused.
set -euo pipefail

source_root=""
snapshot_base="${CODEX_HOME:-$HOME/.codex}/hatsu-marketplace-snapshots"
dry_run=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || exit 2; source_root="$2"; shift 2 ;;
    --base) [ "$#" -ge 2 ] || exit 2; snapshot_base="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) echo "codex-marketplace-snapshot: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$source_root" ] || { echo 'codex-marketplace-snapshot: --root is required' >&2; exit 2; }
source_root="$(CDPATH='' cd -- "$source_root" && pwd -P)" || exit 2
[ -f "$source_root/.claude-plugin/plugin.json" ] && [ -d "$source_root/claude/skills" ] \
  || { echo 'codex-marketplace-snapshot: source is not a Hatsu plugin tree' >&2; exit 2; }
[ "$(git -C "$source_root" rev-parse --show-toplevel)" = "$source_root" ] \
  || { echo 'codex-marketplace-snapshot: source must be a git checkout root' >&2; exit 2; }
head="$(git -C "$source_root" rev-parse --verify HEAD^{commit})" || exit 2
case "$snapshot_base" in
  /*) ;;
  *) echo 'codex-marketplace-snapshot: --base must be absolute' >&2; exit 2 ;;
esac
snapshot="$snapshot_base/$head"
source_record="$snapshot_base/$head.source"
if [ "$dry_run" -eq 1 ]; then
  printf '%s\n' "$snapshot"
  exit 0
fi

mkdir -p -- "$snapshot_base"
[ ! -L "$snapshot_base" ] || { echo 'codex-marketplace-snapshot: snapshot base is a symlink' >&2; exit 3; }
[ ! -L "$source_record" ] || { echo 'codex-marketplace-snapshot: source record is a symlink' >&2; exit 3; }
stage="$(mktemp -d "$snapshot_base/.stage.XXXXXXXX")" || exit 1
trap 'rm -rf -- "$stage"' EXIT
git -C "$source_root" archive --format=tar "$head" | tar -xf - -C "$stage"
[ -f "$stage/.claude-plugin/plugin.json" ] \
  || { echo 'codex-marketplace-snapshot: committed tree lacks its plugin manifest' >&2; exit 2; }
snapshot_matches_stage() {
  local path relative counterpart
  while IFS= read -r -d '' path; do
    relative="${path#"$stage"/}"
    counterpart="$snapshot/$relative"
    if [ -L "$path" ]; then
      [ -L "$counterpart" ] && [ "$(readlink "$path")" = "$(readlink "$counterpart")" ] || return 1
    elif [ -d "$path" ]; then
      [ -d "$counterpart" ] && [ ! -L "$counterpart" ] || return 1
    elif [ -f "$path" ]; then
      [ -f "$counterpart" ] && [ ! -L "$counterpart" ] && cmp -s "$path" "$counterpart" || return 1
      if [ -x "$path" ]; then [ -x "$counterpart" ] || return 1
      else [ ! -x "$counterpart" ] || return 1; fi
    else
      return 1
    fi
  done < <(find "$stage" -mindepth 1 -print0)
  while IFS= read -r -d '' path; do
    relative="${path#"$snapshot"/}"
    counterpart="$stage/$relative"
    [ -e "$counterpart" ] || [ -L "$counterpart" ] || return 1
  done < <(find "$snapshot" -mindepth 1 -print0)
}
write_source_record() {
  local temp
  temp="$(mktemp "$snapshot_base/.source.XXXXXXXX")" || return 1
  printf '%s\n' "$source_root" > "$temp"
  if [ -L "$source_record" ] || [ -d "$source_record" ]; then
    rm -f -- "$temp"
    echo 'codex-marketplace-snapshot: source record is not a plain file' >&2
    return 3
  fi
  mv -f -- "$temp" "$source_record"
}
if [ -e "$snapshot" ] || [ -L "$snapshot" ]; then
  [ -d "$snapshot" ] && [ ! -L "$snapshot" ] \
    || { echo 'codex-marketplace-snapshot: commit path is not a plain directory' >&2; exit 3; }
  if ! snapshot_matches_stage; then
    echo 'codex-marketplace-snapshot: existing commit snapshot differs from the committed tree' >&2
    exit 3
  fi
  # The same commit may be served from another checkout. Its bytes are already
  # verified above; rebind the sidecar so a cache-started update finds it.
  write_source_record
else
  mv -- "$stage" "$snapshot"
  stage=''
  write_source_record
fi
printf '%s\n' "$snapshot"
