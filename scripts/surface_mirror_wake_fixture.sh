#!/usr/bin/env bash
# surface_mirror_wake_fixture.sh -- QA-17 wake-condition assertion for
# .github/workflows/surface-mirror-check.yml.
#
# TEST-ONLY. Nothing installed reads this file; it is not a plugin surface.
#
# WHY IT EXISTS. Hatsu 0.43.0 adds a `paths:` filter to the mirror-drift
# guard's `pull_request_target` trigger, and the same release stamps
# `.claude-plugin/plugin.json`'s `version` into EVERY generated mirror marker
# (`--stamp`, scripts/surface_mirror_check.sh line 173). A `paths:` filter is a
# wake condition, and a wake condition that omits an input the guard reads is a
# guard that does not wake for a change it would have failed. QA-17: assert it
# against the LIVE workflow definition, conjunct by conjunct, never by eye.
#
# The expected input set is DERIVED FROM THE GUARD SCRIPT'S OWN DECLARATIONS
# (its SOURCE_DIR / AGENTS_DIR / MODELS_FILE / PERMISSIONS_FILE / HOOKS_FILE /
# RULES_FILE / MANIFEST_FILE assignments) rather than transcribed here, so the
# assertion follows the guard instead of drifting from it.
#
#   bash scripts/surface_mirror_wake_fixture.sh [repo-root]
#
# Exit 0 every assertion held; exit 1 naming each that did not.
set -uo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
workflow="$root/.github/workflows/surface-mirror-check.yml"
guard="$root/scripts/surface_mirror_check.sh"
fails=0

fail() { printf 'FAIL  %s\n' "$*" >&2; fails=$((fails + 1)); }
pass() { printf 'ok    %s\n' "$*"; }

[ -f "$workflow" ] || { echo "no such workflow: $workflow" >&2; exit 2; }
[ -f "$guard" ]    || { echo "no such guard: $guard" >&2; exit 2; }

# --- the wake conditions, read live out of the workflow, one at a time -------
wake="$(
  ruby -ryaml -e '
    doc = YAML.safe_load(File.read(ARGV[0]), aliases: true)
    on  = doc["on"] || doc[true]
    pr  = (on || {})["pull_request_target"] || {}
    job = (doc["jobs"] || {}).fetch("surface-mirror-check", {})
    puts "EVENT=#{(on || {}).keys.sort.join(",")}"
    puts "TYPES=#{Array(pr["types"]).sort.join(",")}"
    puts "PATHS=#{Array(pr["paths"]).join("|")}"
    puts "IF=#{job["if"]}"
    puts "JOBID=surface-mirror-check" if doc.fetch("jobs", {}).key?("surface-mirror-check")
  ' "$workflow"
)" || { echo "could not parse $workflow" >&2; exit 2; }

event="$(printf '%s\n' "$wake" | sed -n 's/^EVENT=//p')"
types="$(printf '%s\n' "$wake" | sed -n 's/^TYPES=//p')"
paths="$(printf '%s\n' "$wake" | sed -n 's/^PATHS=//p')"
job_if="$(printf '%s\n' "$wake" | sed -n 's/^IF=//p')"

# 1 · the event
[ "$event" = "pull_request_target" ] \
  && pass "event is exactly pull_request_target" \
  || fail "event set is '$event', expected exactly 'pull_request_target'"

# 2 · each type, independently
#
# TWO-STEP LANDING (docs/GATE-CONFIGURATION.md, Hatsu 0.43.0 / zheref/hatsu#94):
# the LIVE workflow this fixture reads still carries the shape `main`'s
# trusted validator judges every PR against -- no `ready_for_review` -- until
# a follow-up PR flips it once THIS repo's own validator (which now accepts
# either shape) is what `main` trusts. So `ready_for_review` is asserted
# ABSENT here, not present; flip this fixture alongside the live workflow in
# that follow-up PR.
for t in opened synchronize reopened; do
  case ",$types," in
    *",$t,"*) pass "type '$t' present" ;;
    *)        fail "type '$t' absent from [$types]" ;;
  esac
done
case ",$types," in
  *",ready_for_review,"*) fail "type 'ready_for_review' present on the live workflow before its two-step landing follow-up (docs/GATE-CONFIGURATION.md)" ;;
  *)                      pass "type 'ready_for_review' absent (deferred to the follow-up PR)" ;;
esac

# 3 · each `if:` conjunct, independently. The draft-skip conjunct is likewise
# deferred to the follow-up PR -- see the two-step-landing note above.
for conj in \
  "github.repository == 'zheref/hatsu'" \
  "github.event.pull_request.head.repo.full_name == github.repository"
do
  case "$job_if" in
    *"$conj"*) pass "if-conjunct present: $conj" ;;
    *)         fail "if-conjunct MISSING: $conj  (if: $job_if)" ;;
  esac
done
case "$job_if" in
  *"github.event.pull_request.draft == false"*)
    fail "draft-skip conjunct present on the live workflow before its two-step landing follow-up (docs/GATE-CONFIGURATION.md)" ;;
  *)
    pass "draft-skip conjunct absent (deferred to the follow-up PR)" ;;
esac

declared_inputs="$(
  grep -E '^(SOURCE_DIR|AGENTS_DIR|MODELS_FILE|PERMISSIONS_FILE|HOOKS_FILE|RULES_FILE|MANIFEST_FILE)="' "$guard" \
    | sed -e 's/^[A-Z_]*="//' -e 's/".*$//' \
    | sort -u
)"
[ -n "$declared_inputs" ] || { echo "could not read the guard's declared inputs" >&2; exit 2; }

# A `paths:` glob matches an input when the input is at or under it. GitHub's
# `**` spans directories; a bare directory prefix behaves the same way here.
# An EMPTY glob list (no `paths:` filter at all) covers every input: the job
# wakes on every pull request.
path_covered() {
  local input="$1" glob
  [ -n "$paths" ] || return 0
  local IFS='|'
  for glob in $paths; do
    [ -n "$glob" ] || continue
    case "$glob" in
      */\*\*) [ "${input#"${glob%\*\*}"}" != "$input" ] && return 0 ;;
      *\*)    [ "${input#"${glob%\*}"}"  != "$input" ] && return 0 ;;
      *)      [ "$input" = "$glob" ] && return 0
              [ "${input#"$glob"/}" != "$input" ] && return 0 ;;
    esac
  done
  return 1
}

# 4 · the paths filter must cover every input the guard declares it reads --
#     UNLESS there is no filter at all, in which case the job wakes on EVERY
#     pull request and trivially covers all of them (Hatsu 0.44.0: a required
#     context cannot carry a `paths:` filter without deadlocking a PR that
#     misses every listed path, so surface-mirror-check now carries none).
if [ -z "$paths" ]; then
  pass "no paths filter on surface-mirror-check -- wakes on every PR, which trivially covers every guard input"
else
  while IFS= read -r input; do
    [ -n "$input" ] || continue
    if path_covered "$input"; then
      pass "paths filter covers guard input '$input'"
    else
      fail "paths filter does NOT cover guard input '$input' -- a PR changing only this file does not wake surface-mirror-check, and the guard's own output would have reported drift"
    fi
  done <<EOF
$declared_inputs
EOF
fi

# 5 · the generated tree itself, so a hand-edited mirror still wakes the guard
#     (trivially true when there is no filter at all -- see path_covered).
path_covered "surfaces/codex/aka/SKILL.md" \
  && pass "paths filter covers the generated tree (surfaces/**)" \
  || fail "paths filter does not cover surfaces/**"

# 6 · the AUTO-REGENERATOR's own wake condition. surface-mirror-regenerate.yml
#     is what repairs the drift the check reports, and it carries the same
#     `paths:` list on `push: branches: [main]`. A file that wakes neither is a
#     file whose drift is never reported AND never repaired.
#
#     TWO-STEP LANDING: this workflow is not yet live -- it ships at
#     `templates/surface-mirror-regenerate.yml` until the follow-up PR
#     installs it under `.github/workflows/` (docs/GATE-CONFIGURATION.md).
#     Assert against whichever copy exists so this fixture keeps proving the
#     paths shape today and needs no further edit when the file moves.
regen="$root/.github/workflows/surface-mirror-regenerate.yml"
[ -f "$regen" ] || regen="$root/templates/surface-mirror-regenerate.yml"
if [ -f "$regen" ]; then
  paths="$(
    ruby -ryaml -e '
      doc = YAML.safe_load(File.read(ARGV[0]), aliases: true)
      on  = doc["on"] || doc[true]
      pu  = (on || {})["push"] || {}
      print Array(pu["paths"]).join("|")
    ' "$regen"
  )"
  while IFS= read -r input; do
    [ -n "$input" ] || continue
    if path_covered "$input"; then
      pass "regenerate paths cover guard input '$input'"
    else
      fail "regenerate paths do NOT cover guard input '$input' -- a push to main changing only this file neither reports nor repairs the drift it causes"
    fi
  done <<EOF2
$declared_inputs
EOF2
else
  fail "no surface-mirror-regenerate.yml to assert (checked .github/workflows/ and templates/)"
fi

if [ "$fails" -ne 0 ]; then
  printf '\nsurface-mirror-wake: %s assertion(s) failed\n' "$fails" >&2
  exit 1
fi
printf '\nsurface-mirror-wake: every wake conjunct asserted\n'
