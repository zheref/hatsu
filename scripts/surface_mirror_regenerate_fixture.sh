#!/usr/bin/env bash
# Prove scripts/surface_mirror_regenerate.sh (zheref/hatsu#218): one generate per surface, in order,
# each carrying EXACTLY the inputs scripts/surface_mirror_check.sh hands `nen surface mirror check`
# for that surface (same flags, same values, same hooks root, the manifest's stamp), so regeneration
# and the drift check cannot disagree; a dry run spawns nothing; a refusal stops at the surface that
# refused with nen's code and generates nothing after it; wiring failures are 2 and a missing nen 3.
# Offline and hermetic: a stub `nen` under mktemp logs every call, one argument per line.

set -euo pipefail
LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
regen="$script_dir/surface_mirror_regenerate.sh"
check="$script_dir/surface_mirror_check.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/surface-mirror-regenerate.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() { echo "surface-mirror-regenerate-fixture: $*" >&2; exit 1; }
pass=0
ok() { pass=$((pass + 1)); echo "ok - $1"; }

tree="$fixture_root/tree"
mkdir -p "$tree/claude/skills/ten" "$tree/.claude-plugin"
printf '{\n  "name": "hatsu",\n  "version": "9.8.7"\n}\n' > "$tree/.claude-plugin/plugin.json"

# The stub: logs "<verb> <surface>" then each argument on its own line, then "--end--", to
# $STUB_LOG; answers generate with STUB_GEN_<SURFACE> (default 0) and check with 0.
stub="$fixture_root/nen"
cat > "$stub" <<'STUB'
#!/usr/bin/env bash
set -u
case "${1:-}" in --version) echo "0.21.0"; exit 0 ;; esac
if [ "${1:-} ${2:-} ${3:-} ${4:-}" = "surface mirror generate --help" ]; then
  echo "nen surface -- mirror a skills directory (stub)"; exit 0
fi
verb="${3:-}" surface=""
prev=""
for a in "$@"; do [ "$prev" = "--surface" ] && surface="$a"; prev="$a"; done
{ printf '%s %s\n' "$verb" "$surface"; shift 3; for a in "$@"; do printf '%s\n' "$a"; done; echo "--end--"; } >> "$STUB_LOG"
if [ "$verb" = generate ]; then
  var="STUB_GEN_$(printf '%s' "$surface" | tr '[:lower:]' '[:upper:]')"
  exit "${!var:-0}"
fi
exit 0
STUB
chmod +x "$stub"

# calls VERB LOG — print, per call of VERB, "<surface>|<sorted flag=value pairs>"
calls() {
  awk -v verb="$1" '
    /^--end--$/ { if (on) print surface "|" acc; on = 0; acc = ""; next }
    on == 0 && $1 == verb { on = 1; surface = $2; acc = ""; next }
    on == 1 { acc = acc (acc == "" ? "" : "\x1f") $0 }
  ' "$2"
}
# pairs_sorted LINE — the argv after the surface, re-joined as sorted flag=value pairs
pairs_sorted() {
  printf '%s' "${1#*|}" | tr '\037' '\n' | paste -d= - - | sort
}

# 1. Parity with the check, surface by surface.
gen_log="$fixture_root/gen.log"; chk_log="$fixture_root/chk.log"
code=0; out="$(STUB_LOG="$gen_log" NEN_BIN="$stub" "$regen" "$tree" 2>&1)" || code=$?
[ "$code" = 0 ] || fail "a clean regenerate exited $code: $out"
code=0; out_chk="$(STUB_LOG="$chk_log" NEN_BIN="$stub" "$check" "$tree" 2>&1)" || code=$?
[ "$code" = 0 ] || fail "the check against the stub exited $code: $out_chk"

order="$(calls generate "$gen_log" | cut -d'|' -f1 | tr '\n' ' ')"
[ "$order" = "codex cursor antigravity " ] || fail "generate order was '$order'"
ok "one generate per surface: codex, cursor, antigravity, in that order"

for s in codex cursor antigravity; do
  g="$(calls generate "$gen_log" | grep "^$s|")" || fail "no generate for $s"
  c="$(calls check "$chk_log" | grep "^$s|")" || fail "no check for $s"
  [ "$(pairs_sorted "$g")" = "$(pairs_sorted "$c")" ] || fail "generate and check differ for $s:
generate: $(pairs_sorted "$g" | tr '\n' ' ')
check:    $(pairs_sorted "$c" | tr '\n' ' ')"
  case "$(pairs_sorted "$g")" in *"--stamp=9.8.7"*) ;; *) fail "$s was not stamped with the manifest's version" ;; esac
done
ok "each generate carries exactly the check's inputs for its surface, stamped 9.8.7"

case "$out" in *"Next: bash scripts/surface_mirror_check.sh"*) ;; *) fail "the next step is not named: $out" ;; esac
ok "a clean run names the drift check as the next step"

# 2. A dry run spawns nothing and prints three lines.
dry_log="$fixture_root/dry.log"
code=0; out="$(STUB_LOG="$dry_log" NEN_BIN="$fixture_root/absent-nen" "$regen" --dry-run "$tree" 2>&1)" || code=$?
[ "$code" = 0 ] || fail "a dry run exited $code: $out"
[ ! -e "$dry_log" ] || fail "a dry run spawned nen"
[ "$(printf '%s\n' "$out" | grep -c '^would run: nen surface mirror generate')" = 3 ] || fail "a dry run did not print three lines: $out"
ok "--dry-run prints three generate lines and spawns nothing, even with no nen"

# 3. A refusal stops at its surface with nen's code.
ref_log="$fixture_root/ref.log"
code=0; out="$(STUB_LOG="$ref_log" STUB_GEN_CURSOR=4 NEN_BIN="$stub" "$regen" "$tree" 2>&1)" || code=$?
[ "$code" = 4 ] || fail "a cursor refusal exited $code, not nen's 4"
[ "$(calls generate "$ref_log" | cut -d'|' -f1 | tr '\n' ' ')" = "codex cursor " ] || fail "a surface after the refusal was generated"
case "$out" in *"regenerated before it: codex"*) ;; *) fail "the refusal does not name what was regenerated: $out" ;; esac
ok "a refusal exits with nen's code, names what ran, and generates nothing after it"

# 4. Wiring.
code=0; out="$(NEN_BIN="$fixture_root/absent-nen" PATH=/usr/bin:/bin "$regen" "$tree" 2>&1)" || code=$?
[ "$code" = 3 ] || fail "a missing nen exited $code, not 3"
mkdir -p "$fixture_root/notroot"
code=0; out="$(NEN_BIN="$stub" "$regen" "$fixture_root/notroot" 2>&1)" || code=$?
[ "$code" = 2 ] || fail "a non-Hatsu root exited $code, not 2"
nover="$fixture_root/nover"; mkdir -p "$nover/claude/skills" "$nover/.claude-plugin"; printf '{"name": "hatsu"}\n' > "$nover/.claude-plugin/plugin.json"
code=0; out="$(NEN_BIN="$stub" "$regen" "$nover" 2>&1)" || code=$?
[ "$code" = 2 ] || fail "an unstamped manifest exited $code, not 2"
case "$out" in *"never generated unstamped"*) ;; *) fail "the unstamped refusal is not named: $out" ;; esac
old="$fixture_root/old-nen"; printf '#!/usr/bin/env bash\necho "usage: nen <command>"\n' > "$old"; chmod +x "$old"
code=0; out="$(NEN_BIN="$old" "$regen" "$tree" 2>&1)" || code=$?
[ "$code" = 2 ] || fail "a nen with no surface verb exited $code, not 2"
code=0; out="$(NEN_BIN="$stub" "$regen" --bogus "$tree" 2>&1)" || code=$?
[ "$code" = 2 ] || fail "an unknown option exited $code, not 2"
ok "no nen is 3; a wrong root, an unstamped manifest, no surface verb and an unknown option are 2"

echo "surface-mirror-regenerate-fixture: all $pass checks passed"
