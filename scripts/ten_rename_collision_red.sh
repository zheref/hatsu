#!/usr/bin/env bash
# RED TEST (Phinks, pre-PR, hatsu v0.48.0 candidate): a consumer that already
# owns a skill directory named `ten` (tracked or untracked) and adopted Hatsu
# at the last pre-rename release. On upgrade, --install-all removes the
# working Hatsu entry (hatsu-warmup) as stale, keeps the consumer's own `ten`,
# and exits 0 -- so `$ten` / `/ten` (P1 of every phase) now runs the
# consumer's skill and the D10 warm-up is gone. --bootstrap refuses this exact
# blocker ("blocks required ten discovery", exit 1); --install-all does not.
#
# Expected (passes when fixed): after the upgrade either Hatsu's own entry is
# still discoverable, or --install-all exits non-zero naming the blocker.
set -u
LC_ALL=C
repo="$(CDPATH='' cd -- "$(dirname -- "$0")/.." >/dev/null 2>&1 && pwd -P)"
cand="${CANDIDATE:-$(git -C "$repo" rev-parse HEAD)}"
from="${FROM:-$(git -C "$repo" log --format=%H -1 --diff-filter=D "$cand" -- claude/skills/hatsu-warmup/SKILL.md)^}"
work="$(mktemp -d "${TMPDIR:-/tmp}/ten-rename-collision.XXXXXX")"
trap 'rm -rf "$work"' EXIT
root="$work/hatsu"
git clone -q --shared "$repo" "$root"

fail=0
for surface in codex cursor; do
  case "$surface" in cursor) sd=.cursor/skills ;; *) sd=.agents/skills ;; esac
  consumer="$work/consumer-$surface"
  git -C "$root" checkout -q "$from"
  mkdir -p "$consumer/nen" "$consumer/$sd/ten"
  git -C "$consumer" init -q
  printf '{}\n' > "$consumer/nen/workflow.json"
  printf -- '---\nname: ten\ndescription: the consumer team own ten skill\n---\nnot hatsu\n' > "$consumer/$sd/ten/SKILL.md"
  git -C "$consumer" add -A
  git -C "$consumer" -c user.email=t@t -c user.name=t commit -qm init
  bash "$root/scripts/surface_bootstrap.sh" --surface "$surface" --target "$consumer" --bootstrap >/dev/null 2>&1
  bash "$root/scripts/surface_bootstrap.sh" --surface "$surface" --target "$consumer" --install-all >/dev/null 2>&1 || {
    echo "setup: pre-rename install-all failed on $surface" >&2; exit 2; }
  [ -f "$consumer/$sd/hatsu-warmup/SKILL.md" ] || { echo "setup: pre-rename entry missing on $surface" >&2; exit 2; }

  git -C "$root" checkout -q "$cand"
  out="$(bash "$root/scripts/surface_bootstrap.sh" --surface "$surface" --target "$consumer" --install-all 2>&1)"; rc=$?
  entry=absent
  grep -qs 'GENERATED' "$consumer/$sd/ten/SKILL.md" && entry=ten
  [ -f "$consumer/$sd/hatsu-warmup/SKILL.md" ] && entry=hatsu-warmup
  if [ "$entry" = absent ] && [ "$rc" -eq 0 ]; then
    echo "FAIL ($surface): upgrade removed Hatsu's entry, kept the consumer's own ten, and exited 0: ${out##*$'\n'}"
    fail=1
  else
    echo "ok ($surface): entry=$entry rc=$rc"
  fi
done
exit "$fail"
