#!/usr/bin/env bash
# canon_contracts_check.sh — the canon data contracts hold their stated invariants (zheref/hatsu#223).
#
# The maintainer's ruling of 2026-10-13 (docs/ROSTER.md § Rulings of 2026-10-13): a canon data contract
# owes a guard lane, and the guard is nen's own validators, run as a focused lane. Three reads, each a
# nen verb or a nen verdict, no re-implementation here (BC-6: one owner per rule, nen's). BC-11 (ruling of
# 2026-10-17): this wrapper's three-way exit is a verdict, so the script is FROZEN to fixes only pending
# its port, nen's own canon check (zheref/nen#407 item 19); no second copy of a rule nen owns:
#
#   1. nen direct registry  --registry contracts/direct.registry.json
#        every routing cell's surface is its alias's, `also` is actionable, the bands partition the
#        scores, the precedence ranks every alias, the snapshot date is a date (exit 0 valid, 1 invalid)
#   2. nen classify labels  --taxonomy contracts/classify.taxonomy.json
#        the taxonomy's own invariants as nen states them: unique keys, every label's colour,
#        description and axis well-formed (exit 0 valid, 1 invalid). Two invariants the issue names --
#        every phase of the document covered, at least one phase per job -- are NOT checked by this
#        verb at this pin (hanten on #223, Nobunaga: a job with no phase passes); they are nen's to
#        add, requested through the run's harvest, never re-implemented here.
#   3. nen classify install --taxonomy <same> --repo <root> --dry-run --json
#        nen/labels.json PARITY with the taxonomy, both ways: every taxonomy label present, none
#        drifted (colour or description), none absent (nen's exit 1), AND no foreign axis-prefixed
#        label nen lists (this script reads `foreign` from the JSON and refuses one: parity is a
#        set equality, not a subset)
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
    --root) [ $# -ge 2 ] && [ -n "$2" ] || { echo "canon_contracts_check: --root needs a path" >&2; exit 2; }; root="$2"; shift 2 ;;
    --self-test) self_test=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "canon_contracts_check: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
if [ "$self_test" = 1 ]; then
  exec bash "$here/canon_contracts_check_fixture.sh"
fi

root="$(cd "$root" 2>/dev/null && pwd -P)" || { echo "canon_contracts_check: --root is not a directory" >&2; exit 2; }
nen="${NEN:-nen}"
command -v "$nen" >/dev/null 2>&1 || { echo "canon_contracts_check: '$nen' not found (set NEN=<path> or put nen on PATH)" >&2; exit 2; }
registry="$root/contracts/direct.registry.json"
taxonomy="$root/contracts/classify.taxonomy.json"
labels="$root/nen/labels.json"
for f in "$registry" "$taxonomy" "$labels"; do
  [ -f "$f" ] || { echo "canon_contracts_check: missing $f" >&2; exit 2; }
  # A symlink is refused (never followed): nen's parse error would echo the first token of whatever
  # file it points at, inside or outside the root (hanten on #223, Feitan; the precedent is
  # prose_size_check.sh and surface_link_check.sh).
  [ -L "$f" ] && { echo "canon_contracts_check: $f is a symbolic link; refused" >&2; exit 2; }
  [ -r "$f" ] || { echo "canon_contracts_check: $f is not readable" >&2; exit 2; }
done
for d in "$root/contracts" "$root/nen"; do
  [ -L "$d" ] && { echo "canon_contracts_check: $d is a symbolic link; refused" >&2; exit 2; }
done

fail=0
run_read() {
  # $1 label, rest: the command. Exit 0 ok; 1 refused (named); anything else wiring (exit 2 here).
  label="$1"; shift
  out="$("$@" 2>&1)"; code=$?
  # A verb the pin lacks: nen answers non-zero with `unknown command` on its first line. Read after
  # the exit, never on the text alone, so data that prints the phrase cannot force a wiring stop.
  if [ "$code" != 0 ] && printf '%s' "$out" | head -1 | grep -Eq "unknown command|unknown '[a-z]+' subcommand"; then
    echo "canon_contracts_check: $label: the pinned nen lacks the verb -- nothing checked" >&2; printf '%s\n' "$out" | head -1 >&2; exit 2
  fi
  case "$code" in
    0) echo "ok    $label" ;;
    1) echo "FAIL  $label"; echo "$out" | sed 's/^/      /'; fail=1 ;;
    *) echo "canon_contracts_check: $label: wiring (exit $code)" >&2; echo "$out" | sed 's/^/      /' >&2; exit 2 ;;
  esac
}

run_read "direct registry (contracts/direct.registry.json)" "$nen" direct registry --registry "$registry" --repo "$root"
run_read "classify labels (contracts/classify.taxonomy.json)" "$nen" classify labels --taxonomy "$taxonomy" --repo "$root"
run_read "labels parity (nen/labels.json against the taxonomy)" "$nen" classify install --taxonomy "$taxonomy" --repo "$root" --dry-run --json
if [ "$fail" = 0 ] && ! printf '%s' "$out" | grep -q '"foreign": \[\]'; then
  echo "FAIL  labels parity: nen/labels.json carries a foreign axis-prefixed label the taxonomy lacks"
  printf '%s\n' "$out" | grep -A3 '"foreign"' | sed 's/^/      /'
  fail=1
fi

if [ "$fail" = 1 ]; then
  echo "canon_contracts_check: a canon data contract breaks an invariant nen states; fix the data, never the guard" >&2
  exit 1
fi
echo "canon_contracts_check: the registry, the taxonomy and nen/labels.json hold every invariant nen states (the two phase-coverage invariants are nen's to add)"
exit 0
