#!/usr/bin/env bash
# RED TEST (Phinks, pre-PR, hatsu v0.49.0 candidate): a Cursor consumer that
# ran the documented first step (`surface_bootstrap.sh --bootstrap`) at the
# last pre-rename release and had not yet run the warm-up is left with NO
# discoverable Hatsu skill once the same Hatsu checkout moves to the
# candidate: its only placement, .cursor/skills/hatsu-warmup, is a symlink into
# surfaces/cursor/hatsu-warmup (gone), and --install-all -- the refresh path --
# refuses because the adoption gate's `find -L` cannot see a marker through a
# dangling link.
#
# Expected (passes when fixed): after the upgrade, --install-all leaves
# .cursor/skills/ten/SKILL.md discoverable and no dangling hatsu-warmup link.
set -u
LC_ALL=C
repo="$(CDPATH='' cd -- "$(dirname -- "$0")/.." >/dev/null 2>&1 && pwd -P)"
cand="${CANDIDATE:-$(git -C "$repo" rev-parse HEAD)}"
# The last tree that still shipped hatsu-warmup: the parent of the commit that deleted it.
from="${FROM:-$(git -C "$repo" log --format=%H -1 --diff-filter=D "$cand" -- claude/skills/hatsu-warmup/SKILL.md)^}"
work="$(mktemp -d "${TMPDIR:-/tmp}/ten-rename-cursor.XXXXXX")"
trap 'rm -rf "$work"' EXIT
root="$work/hatsu"; consumer="$work/consumer"

git clone -q --shared "$repo" "$root"
git -C "$root" checkout -q "$from"
mkdir -p "$consumer/nen"
git -C "$consumer" init -q
printf '{}\n' > "$consumer/nen/workflow.json"
git -C "$consumer" add -A
git -C "$consumer" -c user.email=t@t -c user.name=t commit -qm init

bash "$root/scripts/surface_bootstrap.sh" --surface cursor --target "$consumer" --bootstrap >/dev/null 2>&1 || {
  echo "setup: pre-rename --bootstrap failed" >&2; exit 2; }
[ -e "$consumer/.cursor/skills/hatsu-warmup/SKILL.md" ] || { echo "setup: pre-rename seed missing" >&2; exit 2; }

git -C "$root" checkout -q "$cand"
out="$(bash "$root/scripts/surface_bootstrap.sh" --surface cursor --target "$consumer" --install-all 2>&1)"; rc=$?

fail=0
if [ ! -f "$consumer/.cursor/skills/ten/SKILL.md" ]; then
  echo "FAIL: after upgrade, .cursor/skills/ten/SKILL.md is not discoverable (install-all rc=$rc: ${out##*$'\n'})"
  fail=1
fi
if [ -L "$consumer/.cursor/skills/hatsu-warmup" ] && [ ! -e "$consumer/.cursor/skills/hatsu-warmup" ]; then
  echo "FAIL: .cursor/skills/hatsu-warmup is a dangling symlink after upgrade"
  fail=1
fi
[ "$fail" -eq 0 ] && echo "ok: cursor bootstrap-only consumer keeps a discoverable Hatsu entry across the rename"
exit "$fail"
