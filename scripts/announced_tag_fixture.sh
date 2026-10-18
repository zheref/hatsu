#!/usr/bin/env bash
# announced_tag_fixture.sh — proves scripts/announced_tag.sh's three exits (zheref/hatsu#289 item 5).
# Lane `announced-tag-guard`: `nen shu test --lane announced-tag-guard --repo <hatsu>`. Hermetic and offline.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; guard="$here/announced_tag.sh"
tmp="$(mktemp -d)" || exit 2; trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
pass=0; fail=0
expect() { want="$1"; name="$2"; shift 2; out="$("$@" 2>&1)"; rc=$?; if [ "$rc" = "$want" ]; then pass=$((pass+1)); echo "ok    $name"; else fail=$((fail+1)); echo "FAIL  $name: wanted $want, got $rc -- $out"; fi; }
repo="$tmp/repo"; git init -q "$repo"; mkdir -p "$repo/nen" "$repo/.nen/archive"
expect 3 "no workflow file is no tag declared" bash "$guard" --repo "$repo"
printf '{"branch":{"base":"main"}}\n' > "$repo/nen/workflow.json"
expect 3 "no tags block is no tag declared" bash "$guard" --repo "$repo"
printf '{"tags":"x"}\n' > "$repo/nen/workflow.json"
expect 1 "tags that is not an object is a declaration fault" bash "$guard" --repo "$repo"
printf '{"tags":{"identity":{"nameFrom":".nen/archive/tag-name"}}}\n' > "$repo/nen/workflow.json"
expect 1 "a nameFrom that is not a file is a declaration fault" bash "$guard" --repo "$repo"
printf 'v1.0.0+1\n' > "$repo/.nen/archive/tag-name"
expect 1 "one line is a declaration fault" bash "$guard" --repo "$repo"
printf 'v1.0.0+1\n0123456789abcdef0123456789abcdef01234567\n' > "$repo/.nen/archive/tag-name"
expect 0 "two lines print" bash "$guard" --repo "$repo"
[ "$(bash "$guard" --repo "$repo" | sed -n 1p)" = "v1.0.0+1" ] && { pass=$((pass+1)); echo "ok    line 1 is the identity"; } || { fail=$((fail+1)); echo "FAIL  line 1"; }
printf '{"tags":{"identity":{"nameFrom":"../x"}}}\n' > "$repo/nen/workflow.json"
expect 1 "a nameFrom with .. is a declaration fault" bash "$guard" --repo "$repo"
expect 2 "a missing --repo is wiring" bash "$guard"
expect 2 "a non-repository is wiring" bash "$guard" --repo "$tmp"
echo "announced-tag-guard: $pass passed, $fail failed"; [ "$fail" = 0 ]
