#!/usr/bin/env bash
# Prove scripts/surface_mirror_check.sh's verdicts per surface: a clean tree passes with one check per
# surface; a drift fails at exit 1 and is never re-checked at another root; a refusal keeps its own
# exit code and is named; each surface is handed its own --hooks-root. The next-root re-check that
# zheref/hatsu#153 added for the Codex root's two-step landing is gone since zheref/hatsu#151 made
# that root current (docs/GATE-CONFIGURATION.md, 2026-09-30). Offline and hermetic: a stub `nen`
# stands in for the generator, answering each check by surface, and logging every call under mktemp.

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

# The stub. STUB_<SURFACE> is the exit code it answers a surface's check with. Every check is
# appended to $STUB_LOG as "<surface> <hooks root>".
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
printf '%s %s\n' "$surface" "$root" >> "$STUB_LOG"
var="STUB_$(printf '%s' "$surface" | tr '[:lower:]' '[:upper:]')"
code="${!var:-0}"
case "$code" in
  0) echo "surface: $surface"; echo "hand-edited: (none)" ;;
  1) echo "surface: $surface"; echo "hand-edited: hooks.json" ;;
  *) echo "nen: surface mirror check refused (stub)" >&2 ;;
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

# (a) every surface clean: exit 0, one check each, each with its own root.
run clean 0
[ "$(printf '%s\n' "$calls" | wc -l | tr -d ' ')" = 3 ] || fail "clean: expected 3 checks, got: $calls"
expect_in clean "$calls" 'codex ${PLUGIN_ROOT:-${HATSU_PLUGIN_ROOT:-./.codex}}'
expect_in clean "$calls" 'cursor ${HATSU_PLUGIN_ROOT:-./.cursor}'
expect_in clean "$out" 'all mirrors match a fresh generation.'

# (b) Codex drifts: exit 1, the drift printed, checked once, never at another root.
run codex-drift 1 STUB_CODEX=1
expect_in codex-drift "$out" 'hand-edited: hooks.json'
[ "$(printf '%s\n' "$calls" | grep -c '^codex ')" = 1 ] || fail "codex-drift: codex was checked more than once: $calls"

# (c) a refusal: its own exit code, named, never read as drift.
run codex-refused 2 STUB_CODEX=2
expect_in codex-refused "$out" 'refused at exit 2'
expect_not_in codex-refused "$out" 'the committed mirror is not what the source generates'

# (d) Cursor drifts: exit 1, checked once.
run cursor-drift 1 STUB_CURSOR=1
[ "$(printf '%s\n' "$calls" | grep -c '^cursor ')" = 1 ] || fail "cursor-drift: cursor was checked more than once: $calls"

# (e) one root per surface, written the same everywhere it is written: hooks_root_for in the check,
# the regenerate workflow's case arms, docs/SURFACES.md § 3's loop (Codex and Antigravity; Cursor
# goes through its generic arm) and the search side of surface_bootstrap.sh's placed-hooks sed. The
# workflow's copy drifted once (zheref/hatsu#151); this is the check that it cannot again.
repo="$(CDPATH='' cd -- "$script_dir/.." >/dev/null 2>&1 && pwd -P)"
for s in codex cursor antigravity; do
  in_check="$(grep -o "$s) printf %s '[^']*'" "$guard" | sed "s/^$s) printf %s //")"
  in_workflow="$(grep -o "$s) root='[^']*'" "$repo/.github/workflows/surface-mirror-regenerate.yml" | sed "s/^$s) root=//")"
  [ -n "$in_check" ] || fail "roots: no $s root in hooks_root_for"
  [ "$in_check" = "$in_workflow" ] || fail "roots: $s is $in_check in the check but $in_workflow in surface-mirror-regenerate.yml"
  case "$s" in
    cursor) ;;
    *)
      in_docs="$(grep -o "$s) root='[^']*'" "$repo/docs/SURFACES.md" | sed "s/^$s) root=//")"
      [ "$in_check" = "$in_docs" ] || fail "roots: $s is $in_check in the check but $in_docs in docs/SURFACES.md § 3"
      ;;
  esac
done
# The Codex placed-copy sed is the one whose replacement is the workspace root ./.codex.
in_sed="$(grep -o "sed 's#[^#]*#\${HATSU_PLUGIN_ROOT:-./.codex}#g'" "$repo/scripts/surface_bootstrap.sh" | sed "s/^sed 's#//; s/#.*//")"
[ "'$in_sed'" = "$(grep -o "codex) printf %s '[^']*'" "$guard" | sed "s/^codex) printf %s //")" ] ||
  fail "roots: surface_bootstrap.sh rewrites $in_sed, which is not the check's Codex root"

# (f) --installed on a real plugin cache (the source's own layout) is compared byte for byte by
# plugin_cache_check.sh and never handed to nen's claude-code row, which read every file `missing`
# against it (zheref/hatsu#122); any other path still goes to nen.
printf 'ten\n' > "$tree/claude/skills/ten/SKILL.md"
cache="$fixture_root/cache"; cp -R "$tree" "$cache"
run_installed() {
  local name="$1" expected="$2" path="$3" code=0
  export STUB_LOG="$fixture_root/$name.log"; : > "$STUB_LOG"
  out="$(NEN_BIN="$stub" bash "$guard" --installed "$path" "$tree" 2>&1)" || code=$?
  calls="$(cat "$STUB_LOG")"
  [ "$code" -eq "$expected" ] || fail "$name: exit $code, expected $expected. Output: $out"
}
run_installed cache-identical 0 "$cache"
expect_in cache-identical "$out" 'identical'
[ -z "$calls" ] || fail "cache-identical: nen was asked about a plugin cache: $calls"
printf 'ten, stale\n' > "$cache/claude/skills/ten/SKILL.md"
run_installed cache-stale 1 "$cache"
expect_in cache-stale "$out" 'differs:        claude/skills/ten/SKILL.md'
[ -z "$calls" ] || fail "cache-stale: nen was asked about a plugin cache: $calls"
# a comparator that cannot run is wiring (exit 2), never drift: bash 3.2 under set -e hands back 1
# for a command it cannot execute (Phinks, hanten on 029322fb)
cp -R "$tree" "$fixture_root/cache2"
mkdir -p "$fixture_root/scripts_copy"
cp "$guard" "$repo/scripts/plugin_cache_check.sh" "$fixture_root/scripts_copy/"
chmod -x "$fixture_root/scripts_copy/plugin_cache_check.sh"
code=0; out="$(NEN_BIN="$stub" /bin/bash "$fixture_root/scripts_copy/surface_mirror_check.sh" --installed "$fixture_root/cache2" "$tree" 2>&1)" || code=$?
[ "$code" -eq 2 ] || fail "unrunnable-comparator: exit $code, expected 2 (wiring). Output: $out"
rm "$fixture_root/scripts_copy/plugin_cache_check.sh"
code=0; out="$(NEN_BIN="$stub" /bin/bash "$fixture_root/scripts_copy/surface_mirror_check.sh" --installed "$fixture_root/cache2" "$tree" 2>&1)" || code=$?
[ "$code" -eq 2 ] || fail "missing-comparator: exit $code, expected 2 (wiring). Output: $out"
# a relative --installed path names the caller's directory, not the root it cds into
export STUB_LOG="$fixture_root/relative.log"; : > "$STUB_LOG"
code=0; out="$(cd "$fixture_root" && NEN_BIN="$stub" bash "$guard" --installed cache2 "$tree" 2>&1)" || code=$?
[ "$code" -eq 0 ] || fail "relative-installed: exit $code, expected 0. Output: $out"
expect_in relative-installed "$out" 'installed plugin cache'
[ -z "$(cat "$STUB_LOG")" ] || fail "relative-installed: the relative path was not resolved and went to nen: $(cat "$STUB_LOG")"
target_layout="$fixture_root/target/.claude"; mkdir -p "$target_layout/skills"
run_installed target-layout 0 "$target_layout"
expect_in target-layout "$calls" 'claude-code'

echo 'surface-mirror-check-fixture: ok (clean, codex drift checked once, refusal kept, cursor drift checked once, one root per surface everywhere it is written, a plugin cache compared byte for byte, an unrunnable comparator read as wiring, a relative --installed path resolved)'
