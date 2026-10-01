#!/bin/sh
# nen_global_fixture_check.sh — hermetic, offline fixture for scripts/nen_global.sh.
#
# Every case runs under a throwaway HOME. The bootstrap is a stub handed in
# through --bootstrap-script: it writes a fake `nen` that prints the contract's
# pin and prints that path as its last line. The real contract is read from this
# checkout. Nothing here touches the network or the real HOME.
set -u

here="$(cd "$(dirname "$0")" && pwd -P)"
root="$(cd "$here/.." && pwd -P)"
script="$root/scripts/nen_global.sh"
pin="$(sed -n 's/^[[:space:]]*"pinned_ref"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' "$root/nen/contract.json" | head -n 1)"
[ -n "$pin" ] || { echo "nen-global-fixture: cannot read the pin" >&2; exit 1; }

work="$(mktemp -d "${TMPDIR:-/tmp}/nen-global-fixture.XXXXXX")"
trap 'rm -rf "$work"' EXIT
fails=0

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1 — $2"; fails=$((fails + 1)); }

# A stub bootstrap: $1 is the dir to place the fake binary in, $2 the version it
# prints, $3 the exit code (0 = success).
mkstub() {
  stub="$work/stub-$1.sh"
  cat >"$stub" <<EOS
#!/bin/sh
[ "\$1" = "--ref" ] || exit 2
if [ "$3" != "0" ]; then echo "stub bootstrap failing" >&2; exit $3; fi
mkdir -p "$work/cache"
printf '#!/bin/sh\necho "$2"\n' >"$work/cache/nen-$1"
chmod +x "$work/cache/nen-$1"
echo "noise line"
echo "$work/cache/nen-$1"
EOS
  chmod +x "$stub"
}

newhome() { h="$work/home-$1"; mkdir -p "$h"; printf '%s' "$h"; }

run() { # run <home> <shell> args... ; output in $out, rc in $rc
  _h="$1"; _s="$2"; shift 2
  out="$(HOME="$_h" SHELL="$_s" HATSU_NEN_GLOBAL="${NG:-1}" sh "$script" --root "$root" "$@" 2>&1)"
  rc=$?
}

count_blocks() { grep -c '>>> hatsu nen-global >>>' "$1" 2>/dev/null || true; }

# 1. fresh install links and adds the zsh rc block
h="$(newhome fresh)"; mkstub ok "$pin" 0
run "$h" /bin/zsh --bootstrap-script "$stub"
if [ "$rc" -eq 0 ] && [ -L "$h/.local/bin/nen" ] && [ "$("$h/.local/bin/nen" --version)" = "$pin" ] \
  && [ "$(count_blocks "$h/.zshrc")" = 1 ] && [ "$(count_blocks "$h/.zprofile")" = 1 ] \
  && printf '%s' "$out" | grep -q "rc: added $h/.zshrc, added $h/.zprofile"; then
  pass "fresh install links and adds the zsh rc block"
else fail "fresh install" "rc=$rc out=$out"; fi

# 2. second run is idempotent
run "$h" /bin/zsh --bootstrap-script "$stub"
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '(current)' && printf '%s' "$out" | grep -q 'present' \
  && [ "$(count_blocks "$h/.zshrc")" = 1 ]; then
  pass "second run is idempotent (current, rc present, one block)"
else fail "idempotent" "rc=$rc out=$out"; fi

# 3. stale link is relinked
h="$(newhome stale)"; mkdir -p "$h/.local/bin" "$work/old"
printf '#!/bin/sh\necho 0.14.0\n' >"$work/old/nen"; chmod +x "$work/old/nen"
ln -s "$work/old/nen" "$h/.local/bin/nen"
run "$h" /bin/zsh --rc none --bootstrap-script "$stub"
if [ "$rc" -eq 0 ] && [ "$("$h/.local/bin/nen" --version)" = "$pin" ] && printf '%s' "$out" | grep -q 'linked from' \
  && printf '%s' "$out" | grep -q 'rc: skipped'; then
  pass "stale link is relinked"
else fail "stale relink" "rc=$rc out=$out"; fi

# 4. a real file at bin/nen is refused and untouched
h="$(newhome real)"; mkdir -p "$h/.local/bin"
printf '#!/bin/sh\necho 0.1.0\n' >"$h/.local/bin/nen"; chmod +x "$h/.local/bin/nen"
before="$(cksum <"$h/.local/bin/nen")"
run "$h" /bin/zsh --bootstrap-script "$stub"
if [ "$rc" -eq 3 ] && [ ! -L "$h/.local/bin/nen" ] && [ "$(cksum <"$h/.local/bin/nen")" = "$before" ]; then
  pass "a real file at bin/nen is refused (exit 3) and untouched"
else fail "real file" "rc=$rc out=$out"; fi

# 5. bootstrap exit 5 -> exit 5, old link kept
h="$(newhome bad)"; mkdir -p "$h/.local/bin"
ln -s "$work/old/nen" "$h/.local/bin/nen"; mkstub bad "$pin" 5
run "$h" /bin/zsh --bootstrap-script "$stub"
if [ "$rc" -eq 5 ] && [ "$(readlink "$h/.local/bin/nen")" = "$work/old/nen" ] && printf '%s' "$out" | grep -q 'exited 5'; then
  pass "bootstrap exit 5 -> exit 5, old link kept"
else fail "bootstrap failure" "rc=$rc out=$out"; fi

# 6. opt-out
h="$(newhome off)"
NG=0; run "$h" /bin/zsh --bootstrap-script "$stub"; NG=1
if [ "$rc" -eq 0 ] && [ "$out" = "nen-global: skipped (HATSU_NEN_GLOBAL=0)" ] && [ ! -e "$h/.local" ] && [ ! -e "$h/.zshrc" ]; then
  pass "HATSU_NEN_GLOBAL=0 skips"
else fail "opt-out" "rc=$rc out=$out"; fi

# 7. dry-run changes nothing
h="$(newhome dry)"; mkstub ok "$pin" 0
run "$h" /bin/zsh --dry-run --bootstrap-script "$stub"
if [ "$rc" -eq 0 ] && [ -z "$(ls -A "$h")" ] && printf '%s' "$out" | grep -q 'dry-run'; then
  pass "--dry-run changes nothing"
else fail "dry-run" "rc=$rc out=$out ls=$(ls -A "$h")"; fi

# 8. bash picks .bashrc / .bash_profile
h="$(newhome bash)"
run "$h" /bin/bash --bootstrap-script "$stub"
if [ "$rc" -eq 0 ] && [ "$(count_blocks "$h/.bashrc")" = 1 ] && [ "$(count_blocks "$h/.bash_profile")" = 1 ] && [ ! -e "$h/.zshrc" ]; then
  pass "bash SHELL picks .bashrc and .bash_profile"
else fail "bash rc" "rc=$rc out=$out"; fi

# 9. an existing PATH line is recognised; other shells use .profile
h="$(newhome pre)"; printf 'export PATH="$HOME/.local/bin:$PATH"\n' >"$h/.profile"
run "$h" /bin/dash --bootstrap-script "$stub"
if [ "$rc" -eq 0 ] && [ "$(count_blocks "$h/.profile")" = 0 ] && printf '%s' "$out" | grep -q "present $h/.profile"; then
  pass "existing PATH line is left alone (.profile for other shells)"
else fail "present rc" "rc=$rc out=$out"; fi

# 10. unreadable contract -> exit 2
h="$(newhome nocontract)"; mkdir -p "$work/emptyroot"
out="$(HOME="$h" SHELL=/bin/zsh sh "$script" --root "$work/emptyroot" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then pass "unreadable contract -> exit 2"; else fail "contract" "rc=$rc out=$out"; fi

if [ "$fails" -ne 0 ]; then echo "nen-global-fixture: $fails case(s) failed" >&2; exit 1; fi
echo "nen-global-fixture: all cases passed"
