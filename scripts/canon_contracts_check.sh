#!/usr/bin/env bash
# canon_contracts_check.sh — the canon data contracts hold their stated invariants (zheref/hatsu#223).
#
# The maintainer's ruling of 2026-10-13 (docs/ROSTER.md § Rulings of 2026-10-13): a canon data contract
# owes a guard lane, and the guard is nen's own validators, run as a focused lane. Three reads, each a
# nen verb or a nen verdict, no re-implementation here (BC-9, BC-11: no branching Python, no second
# copy of a rule nen owns):
#
#   1. nen direct registry  --registry contracts/direct.registry.json
#        every routing cell's surface is its alias's, `also` is actionable, the bands partition the
#        scores, the precedence ranks every alias, the snapshot date is a date (exit 0 valid, 1 invalid)
#   2. nen classify labels  --taxonomy contracts/classify.taxonomy.json
#        unique keys, every phase covered, at least one phase per job (exit 0 valid, 1 invalid)
#   3. nen classify install --taxonomy <same> --repo <root> --dry-run
#        nen/labels.json PARITY with the taxonomy: every taxonomy label present, none drifted
#        (colour or description), none absent; foreign axis-prefixed labels are listed, never
#        touched (exit 0 parity, 1 drift or absent, 2 wiring)
#
# Usage:
#   scripts/canon_contracts_check.sh [--root <hatsu checkout>] [--self-test]
#
# `nen` is the pinned binary: NEN=<path> overrides `nen` on PATH, the form CI uses (the trusted
# checkout's bootstrapped binary, never the pull request's). Exit 0 every invariant holds; 1 one or
# more refused, each named by the verb's own line; 2 wiring (no nen, no root, a verb absent at this
# pin — `unknown command` is exit 2 here, never a pass: a verb the pin lacks has checked nothing).
# --self-test runs the fixture, scripts/canon_contracts_check_fixture.sh, which proves each read
# refuses on a broken copy and passes on the committed files.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
self_test=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) shift; root="${1:?--root needs a path}"; shift ;;
    --self-test) self_test=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "canon_contracts_check: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
if [ "$self_test" = 1 ]; then
  exec bash "$here/canon_contracts_check_fixture.sh"
fi

nen="${NEN:-nen}"
command -v "$nen" >/dev/null 2>&1 || { echo "canon_contracts_check: '$nen' not found (set NEN=<path> or put nen on PATH)" >&2; exit 2; }
registry="$root/contracts/direct.registry.json"
taxonomy="$root/contracts/classify.taxonomy.json"
labels="$root/nen/labels.json"
for f in "$registry" "$taxonomy" "$labels"; do
  [ -f "$f" ] || { echo "canon_contracts_check: missing $f" >&2; exit 2; }
done

fail=0
run_read() {
  # $1 label, rest: the command. Exit 0 ok; 1 refused (named); anything else wiring (exit 2 here).
  label="$1"; shift
  out="$("$@" 2>&1)"; code=$?
  case "$out" in
    *"unknown command"*) echo "canon_contracts_check: $label: the pinned nen lacks the verb -- nothing checked" >&2; echo "$out" | head -1 >&2; exit 2 ;;
  esac
  case "$code" in
    0) echo "ok    $label" ;;
    1) echo "FAIL  $label"; echo "$out" | sed 's/^/      /'; fail=1 ;;
    *) echo "canon_contracts_check: $label: wiring (exit $code)" >&2; echo "$out" | sed 's/^/      /' >&2; exit 2 ;;
  esac
}

run_read "direct registry (contracts/direct.registry.json)" "$nen" direct registry --registry "$registry" --repo "$root"
run_read "classify labels (contracts/classify.taxonomy.json)" "$nen" classify labels --taxonomy "$taxonomy" --repo "$root"
run_read "labels parity (nen/labels.json against the taxonomy)" "$nen" classify install --taxonomy "$taxonomy" --repo "$root" --dry-run

if [ "$fail" = 1 ]; then
  echo "canon_contracts_check: a canon data contract breaks an invariant nen states; fix the data, never the guard" >&2
  exit 1
fi
echo "canon_contracts_check: the registry, the taxonomy and nen/labels.json hold every stated invariant"
exit 0
