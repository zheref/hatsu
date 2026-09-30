#!/usr/bin/env bash
# Prove scripts/surface_mirror_check.sh's verdicts per surface, the NEXT-root re-check included
# (docs/GATE-CONFIGURATION.md, 2026-09-30): a clean tree passes with no re-check; Codex drifting at
# its current root and matching at its next passes and says so; drifting at both fails and says the
# next root drifted too; a refusal at the current root keeps its code and is never re-checked; a
# refusal at the next root keeps ITS code and is named; a surface with no next root (Cursor) is never
# re-checked. Offline and hermetic: a stub `nen` stands in for the generator, answering each check by
# the surface and the --hooks-root it was handed, and logging every call under mktemp.

set -euo pipefail
LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
guard="$script_dir/surface_mirror_check.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/surface-mirror-check.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "surface-mirror-check-fixture: $*" >&2
  exit 1
}

# A Hatsu-shaped root: the guard only needs claude/skills/ to exist and the manifest for its stamp.
tree="$fixture_root/tree"
mkdir -p "$tree/claude/skills/ten" "$tree/.claude-plugin"
printf '{\n  "name": "hatsu",\n  "version": "9.9.9"\n}\n' > "$tree/.claude-plugin/plugin.json"

# The stub. STUB_<SURFACE>_CURRENT and STUB_CODEX_NEXT are the exit codes it answers with; a root
# that opens with ${PLUGIN_ROOT:- is Codex's next root. Every check is appended to $STUB_LOG.
stub="$fixture_root/nen"
cat > "$stub" <<'STUB'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  --version) echo "0.16.0"; exit 0 ;;
esac
if [ "${1:-}" = surface ] && [ "${2:-}" = mirror ] && [ "${3:-}" = generate ]; then
  echo "nen surface mirror generate --surface <s> ..."; exit 0
fi
surface="" root=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --surface) surface="$2"; shift 2 ;;
    --hooks-root) root="$2"; shift 2 ;;
    *) shift ;;
  esac
done
case "$root" in '${PLUGIN_ROOT:-'*) which=next ;; *) which=current ;; esac
printf '%s %s\n' "$surface" "$which" >> "$STUB_LOG"
var="STUB_$(printf '%s' "$surface" | tr '[:lower:]' '[:upper:]')_$(printf '%s' "$which" | tr '[:lower:]' '[:upper:]')"
code="${!var:-0}"
case "$code" in
  0) echo "surface: $surface"; echo "hand-edited: (none)" ;;
  1) echo "surface: $surface"; echo "hand-edited: hooks.json" ;;
  *) echo "nen: surface mirror check refused (stub, $which root)" >&2 ;;
esac
exit "$code"
STUB
chmod +x "$stub"

# run NAME EXPECTED_EXIT [VAR=value ...] — runs the guard against the tree with the stub, leaves the
# output in $out and the call log in $calls.
run() {
  local name="$1" expected="$2" code=0
  shift 2
  export STUB_LOG="$fixture_root/$name.log"
  : > "$STUB_LOG"
  out="$(env "$@" NEN_BIN="$stub" bash "$guard" "$tree" 2>&1)" || code=$?
  calls="$(cat "$STUB_LOG")"
  [ "$code" -eq "$expected" ] || fail "$name: exit $code, expected $expected. Output: $out"
}

expect_in() {
  case "$2" in *"$3"*) ;; *) fail "$1: expected '$3' in: $2" ;; esac
}

expect_not_in() {
  case "$2" in *"$3"*) fail "$1: did not expect '$3' in: $2" ;; *) ;; esac
}

# (a) every surface clean: exit 0, one check each, no next-root line.
run clean 0
[ "$(printf '%s\n' "$calls" | wc -l | tr -d ' ')" = 3 ] || fail "clean: expected 3 checks, got: $calls"
expect_not_in clean "$out" 'next hooks root'
expect_in clean "$out" 'all mirrors match a fresh generation.'
expect_not_in clean "$out" 'NEXT hooks root'

# (b) Codex drifts at its current root and matches at its next: exit 0, said, checked twice.
run next-accepted 0 STUB_CODEX_CURRENT=1 STUB_CODEX_NEXT=0
expect_in next-accepted "$out" 'codex matches a fresh generation at its NEXT hooks root'
expect_in next-accepted "$calls" 'codex next'
expect_not_in next-accepted "$out" 'hand-edited: hooks.json'
expect_in next-accepted "$out" 'all mirrors match a fresh generation (at the next hooks root: codex).'

# (c) Codex drifts at both roots: exit 1, the current root's report kept, the second drift said.
run both-drift 1 STUB_CODEX_CURRENT=1 STUB_CODEX_NEXT=1
expect_in both-drift "$out" 'hand-edited: hooks.json'
expect_in both-drift "$out" 'drifts there too'
expect_not_in both-drift "$out" 'at its NEXT hooks root'

# (d) a refusal at the current root: its own exit, never re-checked.
run current-refused 2 STUB_CODEX_CURRENT=2
expect_not_in current-refused "$calls" 'codex next'
expect_in current-refused "$out" 'refused at exit 2'

# (e) drift at the current root, a refusal at the next: the refusal's exit, named.
run next-refused 2 STUB_CODEX_CURRENT=1 STUB_CODEX_NEXT=2
expect_in next-refused "$out" 'the re-check of codex at the next hooks root'
expect_not_in next-refused "$out" 'at its NEXT hooks root'
expect_in next-refused "$out" 'refused at exit 2'

# (f) Cursor has no next root: its drift is never re-checked.
run cursor-drift 1 STUB_CURSOR_CURRENT=1
expect_not_in cursor-drift "$calls" 'cursor next'
expect_not_in cursor-drift "$out" 'next hooks root'

echo 'surface-mirror-check-fixture: ok (clean, next root accepted, drift at both, current refused, next refused, cursor never re-checked)'
