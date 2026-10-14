#!/usr/bin/env bash
# canon_contracts_check_fixture.sh — proves scripts/canon_contracts_check.sh (zheref/hatsu#223).
#
# Lane `canon-contracts-guard`: `nen shu test --lane canon-contracts-guard --repo <hatsu>`. Needs the
# pinned nen (NEN=<path> overrides `nen`); without one the fixture is a wiring stop (exit 2), never a
# pass. Each case copies the three data files into a temp root, breaks one invariant with a plain
# text edit, and expects the guard's exit code and the line that names the broken read. The last case
# runs the guard on the committed files, which must pass. Every case names its own failure.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
guard="$here/canon_contracts_check.sh"
nen="${NEN:-nen}"
command -v "$nen" >/dev/null 2>&1 || { echo "canon_contracts_check_fixture: '$nen' not found (set NEN=<path>)" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
passed=0; failed=0

fresh() {
  rm -rf "$tmp/r"; mkdir -p "$tmp/r/contracts" "$tmp/r/nen"
  cp "$root/contracts/direct.registry.json" "$root/contracts/classify.taxonomy.json" "$tmp/r/contracts/"
  cp "$root/nen/labels.json" "$tmp/r/nen/"
}
expect() {
  # $1 case name, $2 expected exit, $3 a substring the output must carry
  name="$1"; want="$2"; needle="$3"
  out="$(NEN="$nen" bash "$guard" --root "$tmp/r" 2>&1)"; code=$?
  if [ "$code" = "$want" ] && printf '%s' "$out" | grep -qF -- "$needle"; then
    passed=$((passed+1)); echo "ok    $name"
  else
    failed=$((failed+1)); echo "FAIL  $name: expected exit $want carrying '$needle', got exit $code"; printf '%s\n' "$out" | sed 's/^/      /'
  fi
}

# 1. a routing cell whose surface is not its alias's -> direct registry refuses
fresh
perl -0pi -e 's/("alias": "EXECUTION_FRONTIER",\s*"surface": ")codex/${1}cursor/' "$tmp/r/contracts/direct.registry.json"
expect "registry: a cell surface off its alias is refused" 1 "FAIL  direct registry"

# 2. a duplicated job key -> classify labels refuses
fresh
perl -0pi -e 's/"key": "parity"/"key": "backlog"/' "$tmp/r/contracts/classify.taxonomy.json"
expect "taxonomy: a duplicated job key is refused" 1 "FAIL  classify labels"

# 3. a label missing from nen/labels.json -> parity refuses
fresh
perl -0pi -e 's/\{[^{}]*"name": "job\/delivery-ops"[^{}]*\},?//s' "$tmp/r/nen/labels.json"
expect "labels: an absent taxonomy label is refused" 1 "FAIL  labels parity"

# 4. a drifted colour -> parity refuses
fresh
perl -0pi -e 's/("color": ")[0-9a-fA-F]{6}("[^{}]*"name": "lang\/swift")/${1}000000${2}/s' "$tmp/r/nen/labels.json"
expect "labels: a drifted colour is refused" 1 "FAIL  labels parity"

# 5. a missing data file -> wiring, never a pass
fresh
rm "$tmp/r/nen/labels.json"
expect "wiring: a missing nen/labels.json is exit 2" 2 "missing"

# 6. the committed files pass
rm -rf "$tmp/r"; mkdir -p "$tmp/r/contracts" "$tmp/r/nen"
cp "$root/contracts/direct.registry.json" "$root/contracts/classify.taxonomy.json" "$tmp/r/contracts/"
cp "$root/nen/labels.json" "$tmp/r/nen/"
expect "committed data: every invariant holds" 0 "hold every stated invariant"

echo "canon_contracts_check_fixture: $passed passed, $failed failed"
[ "$failed" = 0 ]
