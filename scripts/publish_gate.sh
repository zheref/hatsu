#!/usr/bin/env bash
# publish_gate.sh — murasaki § 6's gated push, as one shipped command (zheref/hatsu#218, #188).
#
# The maintainer's ruling of 2026-10-13 (docs/ROSTER.md § Rulings of 2026-10-13): #188's required
# `&&` chain carried `$(mktemp -d)` and `$(git rev-parse …)`, shapes the worktree-isolation guard refuses
# in a Claude Code session, so the chain ships here as a script and the skill block is one plain call.
# BC-11 (ruling of 2026-10-17): the chain decides a push with a three-way exit, a verdict, so this script
# is FROZEN to fixes only pending its port, nen's gated publish (zheref/nen#407 item 18).
# Every gate below is one link of the chain the prose stated, in the same order, and the push runs only
# when each says yes — never `;`, `||`, a pipe or a lone `&` between them:
#
#   1. nen wc catch-up --json   must read `"noOp": true` (the base did not move again; exit 1/2/3 is
#                               ao's classification, and noOp:false returns the changed tree to the caller);
#   2. HEAD must equal --proved (the HEAD the caller's steps 3–5 proved; a merge moved it → re-prove);
#   3. @{upstream} must be      <remote>/<this branch> (the branch is published under its own name; a
#                               first publish, or a branch tracking the trunk, is hatsu:aka's human call);
#   4. nen shu <check> --lane   EVERY declared iteration check, in the order given (--check repeats);
#   5. branch_authorship_check   every outgoing commit carries the run's own Hatsu-Agent trailer
#                               (--base @{upstream}, --trunk origin/<base>, zheref/hatsu#170);
#   6. HEAD still equals --proved, then nen wc publish — never --set-upstream here.
#
# Usage:
#   scripts/publish_gate.sh --repo <path> --base <branch.base> --proved <sha> --check <verb>...
#                           --lane <iteration.lane> --persona <responsible-persona> [--dry-run]
#
# --check names one of nen/workflow.json → iteration.checks (lint, build, test, or whatever the file
# lists); repeat it once per entry, in order. --proved is the full 40-hex SHA. --dry-run runs gate 1
# as `nen wc catch-up --dry-run`, gates 2–5 for real, and gate 6 as `nen wc publish --dry-run`, so a
# dry run pushes nothing and merges nothing. Exit 0 pushed (or would have); 1 a gate said no — the
# line names which gate and quotes the verb's own exit; 2 wiring (a missing or empty argument, a
# malformed --proved or --check, no nen, no git repository). SIGINT and SIGTERM end the chain before
# the push and remove the scratch directory. Each gate's command and exit are printed, quoted, so the
# report can carry them. scripts/publish_gate_check.sh holds the prose that cites this script to the
# chain's shape; scripts/publish_gate_fixture.sh proves each gate refuses the push.
set -u

repo=""; base=""; proved=""; lane=""; persona=""; dry=0; checks=()
need() { # $1 flag, $2 value (may be unset): a missing or empty value is wiring, named
  [ $# -ge 2 ] && [ -n "$2" ] || { echo "publish_gate: $1 needs a value" >&2; exit 2; }
}
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) need "$1" "${2-}"; repo="$2"; shift 2 ;;
    --base) need "$1" "${2-}"; base="$2"; shift 2 ;;
    --proved) need "$1" "${2-}"; proved="$2"; shift 2 ;;
    --check) need "$1" "${2-}"; checks+=("$2"); shift 2 ;;
    --lane) need "$1" "${2-}"; lane="$2"; shift 2 ;;
    --persona) need "$1" "${2-}"; persona="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { print }' "$0"; exit 0 ;;
    *) echo "publish_gate: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$repo" ] || { echo "publish_gate: --repo is required" >&2; exit 2; }
[ -n "$base" ] || { echo "publish_gate: --base is required" >&2; exit 2; }
[ -n "$proved" ] || { echo "publish_gate: --proved is required" >&2; exit 2; }
[ -n "$lane" ] || { echo "publish_gate: --lane is required" >&2; exit 2; }
[ -n "$persona" ] || { echo "publish_gate: --persona is required" >&2; exit 2; }
[ "${#checks[@]}" -gt 0 ] || { echo "publish_gate: at least one --check is required (nen/workflow.json -> iteration.checks)" >&2; exit 2; }
case "$proved" in
  *[!0-9a-f]*|"") echo "publish_gate: --proved must be a full 40-hex commit SHA" >&2; exit 2 ;;
esac
[ "${#proved}" -eq 40 ] || { echo "publish_gate: --proved must be a full 40-hex commit SHA" >&2; exit 2; }
for c in "${checks[@]}"; do
  case "$c" in
    [a-z]*) case "$c" in *[!a-z0-9-]*) echo "publish_gate: --check '$c' is not a verb name" >&2; exit 2 ;; esac ;;
    *) echo "publish_gate: --check '$c' is not a verb name" >&2; exit 2 ;;
  esac
done
here="$(cd "$(dirname "$0")" && pwd)"
nen="${NEN:-nen}"
command -v "$nen" >/dev/null 2>&1 || { echo "publish_gate: '$nen' not found (set NEN=<path> or put nen on PATH)" >&2; exit 2; }
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "publish_gate: '$repo' is not a git repository" >&2; exit 2; }

d="$(mktemp -d)" || { echo "publish_gate: mktemp failed" >&2; exit 2; }
child=""
trap 'rm -rf "$d"' EXIT
trap '[ -n "$child" ] && kill "$child" 2>/dev/null; echo "publish_gate: interrupted; nothing pushed" >&2; exit 130' INT
trap '[ -n "$child" ] && kill "$child" 2>/dev/null; echo "publish_gate: terminated; nothing pushed" >&2; exit 143' TERM

show() { printf '      $'; printf ' %q' "$@"; printf '\n'; }
gate() {  # $1 number, $2 label; the rest is the command. Prints the command and its exit; exit 1 ends the chain.
  n="$1"; label="$2"; shift 2
  printf 'gate %s  %s\n' "$n" "$label"; show "$@"
  # The verb runs as a child the script WAITS on, so an interrupt reaches the traps above at once
  # (bash defers a trapped signal past a foreground child, which once let a push through).
  "$@" >"$d/out" 2>"$d/err" & child=$!
  wait "$child"; code=$?; child=""
  printf '      exit %s\n' "$code"
  if [ "$code" != 0 ]; then
    sed 's/^/      /' "$d/out" "$d/err"
    echo "publish_gate: gate $n ($label) said no (exit $code); nothing pushed" >&2
    exit 1
  fi
}

# 1. the freshness re-probe (a dry run probes without merging)
if [ "$dry" = 1 ]; then
  gate 1 "catch-up re-probe is a no-op" "$nen" wc catch-up --repo "$repo" --base "$base" --dry-run --json
else
  gate 1 "catch-up re-probe is a no-op" "$nen" wc catch-up --repo "$repo" --base "$base" --json
fi
grep -Eq '^[[:space:]]*"noOp": *true' "$d/out" || { echo "publish_gate: gate 1 (catch-up re-probe): the base moved again (noOp is not true); the changed tree returns to the caller, nothing pushed" >&2; exit 1; }

# 2. HEAD is the proved HEAD
head="$(git -C "$repo" rev-parse HEAD)"
printf 'gate 2  HEAD is the proved HEAD\n      HEAD %s  proved %s\n' "$head" "$proved"
[ "$head" = "$proved" ] || { echo "publish_gate: gate 2 (proved HEAD): HEAD $head is not the proved $proved; re-prove, nothing pushed" >&2; exit 1; }

# 3. the branch is published under its own name
branch="$(git -C "$repo" branch --show-current)"
[ -n "$branch" ] || { echo "publish_gate: gate 3 (upstream): detached HEAD, nothing pushed" >&2; exit 1; }
up="$(git -C "$repo" rev-parse --verify --quiet '@{upstream}')" || { echo "publish_gate: gate 3 (upstream): no @{upstream}; the branch is not published, and the first publish is hatsu:aka's human call; nothing pushed" >&2; exit 1; }
upname="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')"
case "$upname" in
  */"$branch") printf 'gate 3  @{upstream} is %s\n      %s\n' "$upname" "$up" ;;
  *) echo "publish_gate: gate 3 (upstream): @{upstream} is '$upname', not '<remote>/$branch'; a branch tracking another name (the trunk) is never pushed here; nothing pushed" >&2; exit 1 ;;
esac

# 4. every declared iteration check, in order
for c in "${checks[@]}"; do
  gate 4 "iteration check ($c on lane $lane)" "$nen" shu "$c" --repo "$repo" --lane "$lane"
done

# 5. provenance over the outgoing range
gate 5 "authorship of the outgoing range" bash "$here/branch_authorship_check.sh" --repo "$repo" --base "$up" --require-agent "$persona" --trunk "origin/$base"

# 6. the push, on a HEAD that still is the proved one
head2="$(git -C "$repo" rev-parse HEAD)"
[ "$head2" = "$proved" ] || { echo "publish_gate: gate 6 (publish): HEAD moved to $head2 during the gates (proved $proved); nothing pushed" >&2; exit 1; }
if [ "$dry" = 1 ]; then
  gate 6 "publish (dry run)" "$nen" wc publish --repo "$repo" --dry-run
  cat "$d/out"
  echo "publish_gate: every gate said yes; would publish (--dry-run)"
  exit 0
fi
gate 6 "publish" "$nen" wc publish --repo "$repo"
cat "$d/out"
echo "publish_gate: pushed on the strength of gates 1-5"
exit 0
