#!/usr/bin/env bash
# publish_gate.sh — murasaki § 6's gated push, as one shipped command (zheref/hatsu#218, #188).
#
# The maintainer's ruling of 2026-10-13 (docs/ROSTER.md § Rulings of 2026-10-13): #188's required
# `&&` chain carried `$(mktemp -d)` and `$(git rev-parse …)`, shapes the worktree-isolation guard refuses
# in a Claude Code session, so the chain ships here as a script and the skill block is one plain call.
# Every gate below is one link of the chain the prose stated, in the same order, and the push runs only
# when each says yes — never `;`, `||`, a pipe or a lone `&` between them:
#
#   1. nen wc catch-up --json   must read `"noOp": true` (the base did not move again; exit 1/2/3 is
#                               ao's classification, and noOp:false returns the changed tree to the caller);
#   2. HEAD must equal --proved (the HEAD the caller's steps 3–5 proved; a merge moved it → re-prove);
#   3. @{upstream} must resolve  (the branch is published; a first publish is hatsu:aka's human call);
#   4. nen shu <check> --lane    the iteration check on the lane (nen/workflow.json → iteration.checks/lane);
#   5. branch_authorship_check   every outgoing commit carries the run's own Hatsu-Agent trailer
#                               (--base @{upstream}, --trunk origin/<base>, zheref/hatsu#170);
#   6. nen wc publish            never --set-upstream here.
#
# Usage:
#   scripts/publish_gate.sh --repo <path> --base <branch.base> --proved <sha> --check <lint|build|test>
#                           --lane <iteration.lane> --persona <responsible-persona> [--dry-run]
#
# --dry-run runs gates 1–5 and prints `would publish` instead of pushing. Exit 0 pushed (or would);
# 1 a gate said no — the line names which gate and quotes the verb's own exit; 2 wiring (a missing
# argument, no nen, no git repository). Each gate's command and exit are printed, so the report quotes
# them. scripts/publish_gate_check.sh holds the prose that cites this script to the chain's shape;
# scripts/publish_gate_fixture.sh proves each gate refuses the push.
set -u

repo=""; base=""; proved=""; check=""; lane=""; persona=""; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?}"; shift 2 ;;
    --base) base="${2:?}"; shift 2 ;;
    --proved) proved="${2:?}"; shift 2 ;;
    --check) check="${2:?}"; shift 2 ;;
    --lane) lane="${2:?}"; shift 2 ;;
    --persona) persona="${2:?}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "publish_gate: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
for v in repo base proved check lane persona; do
  eval "val=\${$v}"
  [ -n "$val" ] || { echo "publish_gate: --$v is required" >&2; exit 2; }
done
here="$(cd "$(dirname "$0")" && pwd)"
nen="${NEN:-nen}"
command -v "$nen" >/dev/null 2>&1 || { echo "publish_gate: '$nen' not found (set NEN=<path> or put nen on PATH)" >&2; exit 2; }
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "publish_gate: '$repo' is not a git repository" >&2; exit 2; }
case "$check" in lint|build|test) : ;; *) echo "publish_gate: --check must be lint, build or test" >&2; exit 2 ;; esac

d="$(mktemp -d)"
trap 'rm -rf "$d"' EXIT

gate() {  # $1 number, $2 label; the rest is the command. Prints the command and its exit; exit 1 ends the chain.
  n="$1"; label="$2"; shift 2
  printf 'gate %s  %s\n      $ %s\n' "$n" "$label" "$*"
  "$@" >"$d/out" 2>&1; code=$?
  printf '      exit %s\n' "$code"
  if [ "$code" != 0 ]; then
    sed 's/^/      /' "$d/out"
    echo "publish_gate: gate $n ($label) said no (exit $code); nothing pushed" >&2
    exit 1
  fi
}

# 1. the freshness re-probe
gate 1 "catch-up re-probe is a no-op" "$nen" wc catch-up --repo "$repo" --base "$base" --json
cp "$d/out" "$d/catch-up.json"
grep -Eq '"noOp": *true' "$d/catch-up.json" || { echo "publish_gate: gate 1 (catch-up re-probe): the base moved again (noOp is not true); the changed tree returns to the caller, nothing pushed" >&2; exit 1; }

# 2. HEAD is the proved HEAD
head="$(git -C "$repo" rev-parse HEAD)"
printf 'gate 2  HEAD is the proved HEAD\n      HEAD %s  proved %s\n' "$head" "$proved"
[ "$head" = "$proved" ] || { echo "publish_gate: gate 2 (proved HEAD): HEAD $head is not the proved $proved; re-prove, nothing pushed" >&2; exit 1; }

# 3. the branch is published
up="$(git -C "$repo" rev-parse --verify --quiet '@{upstream}')" || { echo "publish_gate: gate 3 (upstream): no @{upstream}; the branch is not published, and the first publish is hatsu:aka's human call; nothing pushed" >&2; exit 1; }
printf 'gate 3  @{upstream} resolves\n      %s\n' "$up"

# 4. the iteration check
gate 4 "iteration check ($check on lane $lane)" "$nen" shu "$check" --repo "$repo" --lane "$lane"

# 5. provenance
gate 5 "authorship of the outgoing range" bash "$here/branch_authorship_check.sh" --repo "$repo" --base "$up" --require-agent "$persona" --trunk "origin/$base"

# 6. the push
if [ "$dry" = 1 ]; then
  echo "publish_gate: every gate said yes; would publish (--dry-run)"
  exit 0
fi
gate 6 "publish" "$nen" wc publish --repo "$repo"
cat "$d/out"
echo "publish_gate: pushed on the strength of gates 1-5"
exit 0
