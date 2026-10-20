#!/usr/bin/env bash
# HA#321: compare the first Delivery block to exact-current-branch Nen ledgers.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
body=''
repo=''
base=''

usage() {
  printf '%s\n' 'usage: pr_body_delivery_check.sh --body <abs> --repo <path> [--base <ref>]' >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --body) [ "$#" -ge 2 ] || usage; body="$2"; shift 2 ;;
    --repo) [ "$#" -ge 2 ] || usage; repo="$2"; shift 2 ;;
    --base) [ "$#" -ge 2 ] || usage; base="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

[ -n "$body" ] && [ -n "$repo" ] || usage
case "$body" in /*) ;; *) printf '%s\n' 'pr-delivery guard: --body must be absolute' >&2; exit 2 ;; esac

repo="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || {
  printf '%s\n' 'pr-delivery guard: --repo is not a git working tree' >&2
  exit 2
}
[ ! -L "$repo/.nen" ] || { printf '%s\n' 'pr-delivery guard: .nen symlink refused' >&2; exit 2; }
reports="$repo/.nen/reports"
[ ! -L "$reports" ] || { printf '%s\n' 'pr-delivery guard: .nen/reports symlink refused' >&2; exit 2; }
mkdir -p "$reports"
chmod 700 "$reports"
work="$(mktemp -d "$reports/pr-delivery.XXXXXX")"
chmod 700 "$work"
cleanup() { rm -rf -- "$work"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

if [ -z "$base" ]; then
  base="$(node -e 'const fs=require("node:fs");const p=process.argv[1];const x=JSON.parse(fs.readFileSync(p,"utf8"));process.stdout.write(x.branch?.base?`origin/${x.branch.base}`:"origin/main")' "$repo/nen/workflow.json")" || {
    printf '%s\n' 'pr-delivery guard: cannot read branch.base' >&2
    exit 2
  }
fi

data="$work/report-data.json"
normalized="$work/delivery-data.json"
expected="$work/delivery.md"
set +e
nen report data --repo "$repo" --base "$base" --json > "$data"
status=$?
set -e
if [ "$status" -ne 0 ]; then
  printf 'pr-delivery guard: nen report data failed (exit %s)\n' "$status" >&2
  exit "$status"
fi
chmod 600 "$data"
node "$here/pr_delivery.ts" normalize --data "$data" --out "$normalized" --repo "$repo"
nen report render --template "$repo/templates/pr-delivery.md" --data "$normalized" --out "$expected" --repo "$repo"
chmod 600 "$normalized" "$expected"
node "$here/pr_delivery.ts" check --body "$body" --expected "$expected" --repo "$repo"
