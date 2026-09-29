#!/usr/bin/env bash
# Fixture (Phinks, pre-PR, hatsu v0.48.0; green since ruling 9 R1): getsuga's
# no-token cut point in a consumer whose nen/workflow.json declares a
# branch.base other than main. claude/skills/getsuga/SKILL.md § 1 spells the
# call as `nen release resolve-target --repo <path> --token <branch.base>
# --trunk <branch.base>`: nen's --trunk defaults to `main`, so without it the
# documented default was refused as "NOT an ancestor of the trunk" and the cut
# point was required after all.
#
# Expected: the documented no-token call, with --trunk <branch.base>, exits 0.
set -u
LC_ALL=C
command -v nen >/dev/null 2>&1 || { echo "nen not on PATH" >&2; exit 2; }
work="$(mktemp -d "${TMPDIR:-/tmp}/getsuga-default.XXXXXX")"
trap 'rm -rf "$work"' EXIT
git init -q --bare "$work/origin.git"
git clone -q "$work/origin.git" "$work/consumer" 2>/dev/null
c="$work/consumer"
git -C "$c" checkout -q -b main
mkdir -p "$c/nen"
printf '{"branch":{"base":"develop"}}\n' > "$c/nen/workflow.json"
git -C "$c" add -A
git -C "$c" -c user.email=t@t -c user.name=t commit -qm init
git -C "$c" push -q origin main
git -C "$c" checkout -q -b develop
printf 'x\n' > "$c/f"
git -C "$c" add f
git -C "$c" -c user.email=t@t -c user.name=t commit -qm work
git -C "$c" push -q origin develop

base="$(sed -n 's/.*"base"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$c/nen/workflow.json")"
out="$(nen release resolve-target --repo "$c" --token "$base" --trunk "$base" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: documented default (branch.base=$base, --trunk $base) exit $rc: $out"
  exit 1
fi
echo "ok: default cut point resolves ($out)"
