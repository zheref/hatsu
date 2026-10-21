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

tmp="$(mktemp -d)" || { echo "canon_contracts_check_fixture: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$tmp"' EXIT
passed=0; failed=0

fresh() {
  rm -rf "$tmp/r"; mkdir -p "$tmp/r/contracts" "$tmp/r/nen"
  cp "$root/contracts/direct.registry.json" "$root/contracts/classify.taxonomy.json" "$tmp/r/contracts/"
  cp "$root/nen/labels.json" "$tmp/r/nen/"
}
# break <file> <perl expression>: edits one data file and refuses to continue when the edit matched
# nothing, so a drifted pattern never reads as nen accepting broken data (the HA#243 pattern).
break_file() {
  before="$(cat "$1")"; perl -0pi -e "$2" "$1"
  if [ "$before" = "$(cat "$1")" ]; then failed=$((failed+1)); echo "FAIL  fixture edit matched nothing in $1: $2"; return 1; fi
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
break_file "$tmp/r/contracts/direct.registry.json" 's/("alias": "EXECUTION_FRONTIER",\s*"surface": ")codex/${1}cursor/' && \
expect "registry: a cell surface off its alias is refused" 1 "FAIL  direct registry"

# 2. a duplicated job key -> classify labels refuses
fresh
break_file "$tmp/r/contracts/classify.taxonomy.json" 's/"key": "parity"/"key": "backlog"/' && \
expect "taxonomy: a duplicated job key is refused" 1 "FAIL  classify labels"

# 3. a label missing from nen/labels.json -> parity refuses
fresh
break_file "$tmp/r/nen/labels.json" 's/\{[^{}]*"name": "job\/delivery-ops"[^{}]*\},?//s' && \
expect "labels: an absent taxonomy label is refused" 1 "FAIL  labels parity"

# 4. a drifted colour -> parity refuses
fresh
break_file "$tmp/r/nen/labels.json" 's/("color": ")[0-9a-fA-F]{6}("[^{}]*"name": "lang\/swift")/${1}000000${2}/s' && \
expect "labels: a drifted colour is refused" 1 "FAIL  labels parity"

# 4b. a foreign axis-prefixed label -> parity refuses (set equality, both ways)
fresh
break_file "$tmp/r/nen/labels.json" 's/"labels": \[/"labels": [\n    { "color": "ededed", "description": "foreign", "name": "job\/bogus" },/' && \
expect "labels: a foreign axis-prefixed label is refused" 1 "foreign"

# 5. a missing data file -> wiring, never a pass
fresh
rm "$tmp/r/nen/labels.json"
expect "wiring: a missing nen/labels.json is exit 2" 2 "missing"

# 4c. the verdict the pinned nen gives a job with no phase is PINNED here (a false green the header no longer
# claims otherwise): when nen learns the two phase-coverage invariants this case flips, and the header
# and this case are updated together (hanten on #223, Phinks P1)
fresh
break_file "$tmp/r/contracts/classify.taxonomy.json" 's/"phases": \{[^{}]*(\{[^{}]*\}[^{}]*)*\}/"phases": {}/g' && \
expect "pinned: a job with no phase passes (phase coverage is nen's to add)" 0 "hold every invariant nen states"
fresh
chmod 000 "$tmp/r/nen/labels.json"
expect "wiring: an unreadable nen/labels.json is exit 2" 2 "not readable"
chmod 644 "$tmp/r/nen/labels.json"

# 5b. a symlinked data file is refused, never followed
fresh
rm "$tmp/r/nen/labels.json"; printf 'SYNTHETIC_PLACEHOLDER_VALUE\n' > "$tmp/outside.json"; ln -s "$tmp/outside.json" "$tmp/r/nen/labels.json"
expect "wiring: a symlinked nen/labels.json is exit 2, never read" 2 "symbolic link"

# 5c. a nen that lacks a verb, or answers outside 0/1, is wiring -- never a pass
fresh
mkdir -p "$tmp/stub"
printf '#!/bin/sh\necho "nen: unknown command %s" >&2; exit 2\n' "'direct registry'" > "$tmp/stub/nen-absent"; chmod +x "$tmp/stub/nen-absent"
out="$(NEN="$tmp/stub/nen-absent" bash "$guard" --root "$tmp/r" 2>&1)"; code=$?
if [ "$code" = 2 ] && printf '%s' "$out" | grep -qF "lacks the verb"; then passed=$((passed+1)); echo "ok    wiring: a nen lacking the verb is exit 2 naming it"; else failed=$((failed+1)); echo "FAIL  wiring: nen lacking the verb: expected exit 2 carrying 'lacks the verb', got exit $code"; printf '%s\n' "$out" | sed 's/^/      /'; fi
printf '#!/bin/sh\necho "boom" >&2; exit 3\n' > "$tmp/stub/nen-broken"; chmod +x "$tmp/stub/nen-broken"
out="$(NEN="$tmp/stub/nen-broken" bash "$guard" --root "$tmp/r" 2>&1)"; code=$?
if [ "$code" = 2 ] && printf '%s' "$out" | grep -qF "wiring"; then passed=$((passed+1)); echo "ok    wiring: a nen exit outside 0/1 is exit 2"; else failed=$((failed+1)); echo "FAIL  wiring: nen exit 3: expected exit 2 carrying 'wiring', got exit $code"; printf '%s\n' "$out" | sed 's/^/      /'; fi
out="$(bash "$guard" --root "$tmp/nowhere" 2>&1)"; code=$?
if [ "$code" = 2 ]; then passed=$((passed+1)); echo "ok    wiring: a --root that is not a directory is exit 2"; else failed=$((failed+1)); echo "FAIL  wiring: --root nowhere: expected exit 2, got $code"; fi

# 6. the committed files pass
rm -rf "$tmp/r"; mkdir -p "$tmp/r/contracts" "$tmp/r/nen"
cp "$root/contracts/direct.registry.json" "$root/contracts/classify.taxonomy.json" "$tmp/r/contracts/"
cp "$root/nen/labels.json" "$tmp/r/nen/"
expect "committed data: every invariant holds" 0 "hold every invariant nen states"

echo "canon_contracts_check_fixture: $passed passed, $failed failed"
[ "$failed" = 0 ]
