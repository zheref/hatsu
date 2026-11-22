#!/usr/bin/env bash
# Prove scripts/surface_mirror_regenerate.sh (zheref/hatsu#218): one generate per surface, in order,
# each carrying EXACTLY the inputs scripts/surface_mirror_check.sh hands `nen surface mirror check`
# for that surface (same flags, same values, same hooks root, the same manifest), so regeneration
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
  # zheref/hatsu#530: --stamp is gone from BOTH sides. A generate that carried it would write the
  # plugin version into all 252 mirror files and make every bump rewrite them.
  case "$(pairs_sorted "$g")" in *"--stamp"*) fail "$s was generated with --stamp; zheref/hatsu#530 removed it" ;; esac
  case "$(pairs_sorted "$c")" in *"--stamp"*) fail "$s was checked with --stamp; zheref/hatsu#530 removed it" ;; esac
  case "$(pairs_sorted "$g")" in *"--manifest=.claude-plugin/plugin.json"*) ;; *) fail "$s was generated without the manifest input" ;; esac
done
ok "each generate carries exactly the check's inputs for its surface; neither side carries --stamp, both carry --manifest"

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
[ "$code" = 2 ] || fail "a manifest with no version exited $code, not 2"
case "$out" in *"never generated unversioned"*) ;; *) fail "the unversioned refusal is not named: $out" ;; esac
old="$fixture_root/old-nen"; printf '#!/usr/bin/env bash\necho "usage: nen <command>"\n' > "$old"; chmod +x "$old"
code=0; out="$(NEN_BIN="$old" "$regen" "$tree" 2>&1)" || code=$?
[ "$code" = 2 ] || fail "a nen with no surface verb exited $code, not 2"
code=0; out="$(NEN_BIN="$stub" "$regen" --bogus "$tree" 2>&1)" || code=$?
[ "$code" = 2 ] || fail "an unknown option exited $code, not 2"
ok "no nen is 3; a wrong root, a manifest with no version, no surface verb and an unknown option are 2"

# 5. A bare `nen` is looked up on PATH only: a root carrying its own nen/ directory (Hatsu does) with
# no nen on PATH is 3, never "no surface verb" (the old `[ -x nen ]` read the directory as the binary).
mkdir -p "$tree/nen"
code=0; out="$(env -u NEN_BIN PATH=/usr/bin:/bin "$regen" "$tree" 2>&1)" || code=$?
[ "$code" = 3 ] || fail "no nen on PATH with a nen/ directory in the root exited $code, not 3: $out"
# An unreadable manifest is this script's own refusal line, not awk's.
unread="$fixture_root/unread"; mkdir -p "$unread/claude/skills" "$unread/.claude-plugin"
printf '{"version": "1.0.0"}\n' > "$unread/.claude-plugin/plugin.json"; chmod 000 "$unread/.claude-plugin/plugin.json"
code=0; out="$(NEN_BIN="$stub" "$regen" "$unread" 2>&1)" || code=$?
chmod 644 "$unread/.claude-plugin/plugin.json"
if [ "$(id -u)" != 0 ]; then
  [ "$code" = 2 ] || fail "an unreadable manifest exited $code, not 2"
  case "$out" in "surface-mirror-regenerate: "*"missing or unreadable"*) ;; *) fail "the unreadable-manifest refusal is not the script's own: $out" ;; esac
fi
# One table: the regenerator carries no hooks-root table of its own, it sources the check's.
! grep -q "printf %s '" "$regen" || fail "the regenerator carries its own hooks-root table"
grep -q 'surface_mirror_check.sh"$' "$regen" || fail "the regenerator does not source the check"
ok "a nen/ directory in the root is never read as nen (3); an unreadable manifest is refused by name; one table, sourced"

# 6. Run the real pinned generator on a scratch checkout, and prove zheref/hatsu#530 against it:
# a MANIFEST-ONLY version change must rewrite exactly ONE mirror file — surfaces/antigravity/
# plugin.json, the single generated file that IS a plugin manifest declaring a version — and
# nothing else. Through 0.154.1 the same bump rewrote all 252 of them, one marker line apiece,
# which is the churn this issue removed. The assertion is a count, so a regression that restamps
# the tree again fails here by number rather than by eye.
real_nen="$(command -v nen || true)"
[ -n "$real_nen" ] || fail "the real manifest-version case needs pinned nen on PATH"
version_tree="$fixture_root/version-tree"; mkdir -p "$version_tree"
git -C "$script_dir/.." archive --format=tar HEAD | tar -xf - -C "$version_tree"
NEN_BIN="$real_nen" "$regen" "$version_tree" > "$fixture_root/real-generate.log" \
  || { cat "$fixture_root/real-generate.log"; fail "real scratch regeneration refused"; }
NEN_BIN="$real_nen" "$check" "$version_tree" > "$fixture_root/real-check.log" \
  || { cat "$fixture_root/real-check.log"; fail "real scratch check refused"; }
cp -R "$version_tree/surfaces" "$fixture_root/before-bump"
old_version="$(awk -F'"' '/"version"[[:space:]]*:/ { print $4; exit }' "$version_tree/.claude-plugin/plugin.json")"
[ -n "$old_version" ] || fail "scratch manifest has no version"
new_version=9.8.8
awk -v new="$new_version" '
  !done && /"version"[[:space:]]*:/ {
    sub(/"version"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"version\": \"" new "\"")
    done=1
  }
  { print }
  END { if (!done) exit 2 }
' "$version_tree/.claude-plugin/plugin.json" > "$fixture_root/bumped-manifest.json" \
  || fail "could not bump the scratch manifest"
mv "$fixture_root/bumped-manifest.json" "$version_tree/.claude-plugin/plugin.json"
NEN_BIN="$real_nen" "$regen" "$version_tree" > "$fixture_root/bumped-generate.log" \
  || { cat "$fixture_root/bumped-generate.log"; fail "manifest-only regeneration refused"; }
NEN_BIN="$real_nen" "$check" "$version_tree" > "$fixture_root/bumped-check.log" \
  || { cat "$fixture_root/bumped-check.log"; fail "manifest-only scratch check refused"; }
code=0; diff -rq "$fixture_root/before-bump" "$version_tree/surfaces" > "$fixture_root/bump.diff" || code=$?
[ "$code" -eq 1 ] || fail "the manifest-only diff exited $code, expected exactly one changed mirror"
! grep -q '^Only in ' "$fixture_root/bump.diff" || fail "a manifest-only regeneration added or removed mirror paths:
$(cat "$fixture_root/bump.diff")"
changed_files="$(grep -c '^Files ' "$fixture_root/bump.diff" || true)"
[ "$changed_files" -eq 1 ] || fail "a manifest-only regeneration rewrote $changed_files mirror files, expected exactly 1:
$(cat "$fixture_root/bump.diff")"
grep -q 'antigravity/plugin\.json' "$fixture_root/bump.diff" \
  || fail "the one rewritten mirror is not antigravity/plugin.json:
$(cat "$fixture_root/bump.diff")"
code=0; diff -u "$fixture_root/before-bump/antigravity/plugin.json" "$version_tree/surfaces/antigravity/plugin.json" \
  > "$fixture_root/bump-manifest.diff" || code=$?
[ "$code" -eq 1 ] || fail "the one rewritten mirror diffed at $code, expected a change"
changed_lines="$(awk '/^(---|\+\+\+)/ { next } /^[+-]/ { print }' "$fixture_root/bump-manifest.diff")"
[ -n "$changed_lines" ] || fail "antigravity/plugin.json changed no lines"
if printf '%s\n' "$changed_lines" | grep -qv '"version"'; then
  fail "antigravity/plugin.json changed text besides its version:
$changed_lines"
fi
case "$changed_lines" in *"$new_version"*) ;; *) fail "the rewritten manifest does not carry $new_version: $changed_lines" ;; esac
# No MARKER carries a version. The word "stamp" may still appear in a mirrored BODY -- the hook
# script's own comments describe both marker grammars -- so this matches the marker, not the word.
! grep -rqE 'GENERATED by nen surface mirror \(surface: [a-z-]+, stamp:' "$version_tree/surfaces" \
  || fail "a generated file's marker still carries a stamp:
$(grep -rlE 'GENERATED by nen surface mirror \(surface: [a-z-]+, stamp:' "$version_tree/surfaces" | head -5)"
ok "real scratch bump rewrites exactly 1 mirror file (antigravity/plugin.json, version only); no marker carries a version"

echo "surface-mirror-regenerate-fixture: all $pass checks passed"
