#!/usr/bin/env bash
# direct_matrix_doc.sh — render the model matrix hatsu:direct resolves from, as a page a person reads.
#
#   bash scripts/direct_matrix_doc.sh [--write | --check | --verify | --self-test] [repo-root]
#
#   (none)       print the rendered page to stdout
#   --write      write it to docs/DIRECT-MATRIX.md (atomically: a temp file, then a rename)
#   --check      exit 1 when docs/DIRECT-MATRIX.md is missing or differs from what the data renders
#   --verify     ask `nen direct resolve` about EVERY CLAIM THE PAGE PRINTS — each matrix cell, each
#                grid cell, each "Effort alone" level, each unreachable "—", each worked example — and
#                exit 1 on any disagreement. Needs nen at contracts' pin (NEN=<path> overrides `nen`).
#   --self-test  hermetic fixtures under a temp dir: --check fails on a stale, missing or mutated page,
#                malformed data refuses by name, the re-implemented rules hold at their edges, the
#                registry's own invariants hold over every cell (the fallback rule, every alias's line
#                and escalation, every companion job routed); then --check on the real tree. This is
#                the direct-matrix-guard lane's argv.
#
#   exit 0 ok · 1 stale page or a disagreement · 2 usage, unreadable data or a refused rule shape
#
# WHY A GENERATOR. hatsu:direct never decides in prose: `nen direct resolve` reads
# contracts/direct.registry.json, contracts/classify.taxonomy.json and the consumer's
# nen/workflow.json -> models, and answers. A hand-written table of the same answers would be a second
# copy that rots the first time a cell moves. This page is RENDERED from those three files, so the page
# and the verb cannot disagree unless the page is stale (--check) or the renderer reads the data
# differently than the verb does (--verify, which checks what the page PRINTS, not what this file meant).
#
# WHAT IS PRESENTATION, WHAT IS DATA, AND WHAT IS RESIDUE. Provider dots, domain display names, the
# worked-example inputs and the "How a recommendation is made" walkthrough are presentation, written
# here. Every alias, surface, tier, typed name, routing cell, weight, band, count and every rule sentence
# (domain rows, fallback, aggregation, the collapsed effort dial) is read from the data. RESIDUE: to
# render offline this file re-implements domain derivation, the fallback order (parsed from the
# taxonomy's fallback sentence after its colon, exactly as `nen direct --help` documents the verb doing),
# aggregation and effort banding. --verify holds every printed result of that re-implementation to the
# verb; a matrix/explain mode of `nen direct` would retire it.
#
# The wrapper preserves the original CLI; the typed sibling owns validation, rendering and fixtures.
# HA341 preparer: no new registry fields or model data are activated here.
set -euo pipefail

mode=""
root=""
for arg in "$@"; do
  case "$arg" in
    --write|--check|--verify|--self-test)
      if [ -n "$mode" ]; then echo "direct_matrix_doc: one mode at a time (got --$mode and $arg)" >&2; exit 2; fi
      mode="${arg#--}" ;;
    -h|--help) sed -n '2,35p' "$0"; exit 0 ;;
    -*) echo "direct_matrix_doc: unknown flag $arg" >&2; exit 2 ;;
    *)
      if [ -n "$root" ]; then echo "direct_matrix_doc: one repo-root at a time (got $root and $arg)" >&2; exit 2; fi
      root="$arg" ;;
  esac
done
[ -n "$mode" ] || mode=print
if [ -z "$root" ]; then
  root="$(cd "$(dirname "$0")/.." && pwd)"
else
  given="$root"
  root="$(cd "$given" 2>/dev/null && pwd)" || { echo "direct_matrix_doc: repo-root $given is not a directory" >&2; exit 2; }
fi
script="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# The trusted sibling judges the named root as data. Do not admit a PR's
# Node preload or module search path before the trusted renderer starts.
unset NODE_OPTIONS NODE_PATH
command -v node >/dev/null 2>&1 || { echo 'direct_matrix_doc: node not found' >&2; exit 2; }
v="$(node --version 2>/dev/null)" || v=''
IFS=. read -r maj min _rest <<NODE_VERSION_EOF
${v#v}
NODE_VERSION_EOF
case "$maj.$min" in *[!0-9.]*|.*|*.) maj=0 min=0 ;; esac
if [ "$maj" -ge 24 ] || { [ "$maj" -eq 23 ] && [ "$min" -ge 6 ]; } || { [ "$maj" -eq 22 ] && [ "$min" -ge 18 ]; }; then
  exec node "$(dirname "$script")/direct_matrix_doc.mts" "$mode" "$root"
fi
echo "direct_matrix_doc: node >= 22.18 required (found ${v:-no version}; on 23.x, >= 23.6)" >&2
exit 2
