#!/bin/sh
# nen_global_fixture_check.sh — hermetic, offline fixture for scripts/nen_global.sh
# and for step 0 of hooks/session-start.sh.
#
# Every case runs under a throwaway HOME with its own XDG_CACHE_HOME and
# XDG_CONFIG_HOME, from a throwaway cwd, with HATSU_NEN_GLOBAL set explicitly.
# The bootstrap is a stub handed in through --bootstrap-script: it writes a fake
# `nen` under the fake cache and prints that path as its last line; the digest
# the fixture hands in through the fixture seam --expect-sha256 is computed from
# the bytes the stub writes. The real contract is read from this checkout (or a
# sed-edited copy of it). Nothing here touches the network or the real HOME.
set -u

here="$(cd "$(dirname "$0")" && pwd -P)"
root="$(cd "$here/.." && pwd -P)"
script="$root/scripts/nen_global.sh"
hook="$root/hooks/session-start.sh"
pin="$(sed -n 's/^[[:space:]]*"pinned_ref"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' "$root/nen/contract.json" | head -n 1)"
[ -n "$pin" ] || { echo "nen-global-fixture: cannot read the pin" >&2; exit 1; }
pinref="v$pin"
newer="${pin%.*}.$(( ${pin##*.} + 9 ))"
real_sha="$(sed -n 's/^[[:space:]]*"darwin-arm64"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{64\}\)".*/\1/p' "$root/nen/contract.json" | head -n 1)"
[ -n "$real_sha" ] || { echo "nen-global-fixture: no darwin-arm64 digest in the contract" >&2; exit 1; }

work="$(mktemp -d "${TMPDIR:-/tmp}/nen-global-fixture.XXXXXX")"
cleanup() { chmod -R u+rwx "$work" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/cwd" "$work/tmp"
fails=0

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1 — $2"; fails=$((fails + 1)); }

sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'; else sha256sum | awk '{print $1}'; fi; }

# mkstub NAME VERSION EXIT [MODE] — a stub bootstrap; sets $stub and $stubsha.
#   MODE normal   writes <cache>/nen/stub/nen-NAME and prints it
#        outside  prints a file OUTSIDE the cache (right bytes)
#        relative prints a relative path
#        dir      prints the cache directory itself
#        once4    exits 4 on its first call, then behaves as normal
#        hang     spawns a child and sleeps (for the TERM case)
# Every call appends a line to $work/calls-NAME and records its env and argv.
mkstub() {
  _n="$1"; _v="$2"; _x="$3"; _m="${4:-normal}"
  stub="$work/stub-$_n.sh"
  stubsha="$(printf '#!/bin/sh\necho "%s"\n' "$_v" | sha)"
  cat >"$stub" <<EOS
#!/bin/sh
echo call >>"$work/calls-$_n"
echo "src=\${NEN_SOURCE-unset} ref=\${NEN_REF-unset} cache=\${NEN_CACHE_DIR-unset} args=\$*" >"$work/seen-$_n"
[ "\$1" = "--ref" ] || exit 2
if [ "$_x" != "0" ]; then echo "stub bootstrap failing" >&2; exit $_x; fi
case "$_m" in
  once4) [ "\$(wc -l <"$work/calls-$_n" | tr -d ' ')" -gt 1 ] || { echo "stub download failed" >&2; exit 4; } ;;
  hang) sleep 301 & echo \$! >"$work/childpid"; wait ;;
esac
d="\${XDG_CACHE_HOME:-\$HOME/.cache}/nen/stub"
mkdir -p "\$d"
printf '#!/bin/sh\necho "%s"\n' "$_v" >"\$d/nen-$_n"
chmod +x "\$d/nen-$_n"
echo "noise line"
case "$_m" in
  outside) mkdir -p "$work/outside"; cp "\$d/nen-$_n" "$work/outside/nen-$_n"; echo "$work/outside/nen-$_n" ;;
  relative) echo "stub/nen-$_n" ;;
  dir) echo "\$d" ;;
  *) echo "\$d/nen-$_n" ;;
esac
EOS
  chmod +x "$stub"
}

newhome() { h="$work/home-$1"; mkdir -p "$h"; printf '%s' "$h"; }

# run HOME SHELL args... — output in $out, rc in $rc. NG is HATSU_NEN_GLOBAL,
# RUNPATH an optional PATH, ROOT an optional contract root.
run() {
  _h="$1"; _s="$2"; shift 2
  out="$(cd "$work/cwd" && HOME="$_h" XDG_CACHE_HOME="$_h/.cache" XDG_CONFIG_HOME="$_h/.config" TMPDIR="$work/tmp" \
    PATH="${RUNPATH:-$PATH}" SHELL="$_s" HATSU_NEN_GLOBAL="${NG:-1}" sh "$script" --root "${ROOT:-$root}" "$@" 2>&1)"
  rc=$?
}
# runstub HOME SHELL args... — run with the current stub and its digest.
runstub() { _h="$1"; _s="$2"; shift 2; run "$_h" "$_s" --bootstrap-script "$stub" --expect-sha256 "$stubsha" "$@"; }

count_blocks() { grep -c '>>> hatsu nen-global >>>' "$1" 2>/dev/null || true; }
has() { printf '%s' "$out" | grep -q -- "$1"; }
oldnen() { mkdir -p "$work/old"; printf '#!/bin/sh\necho 0.14.0\n' >"$work/old/nen"; chmod +x "$work/old/nen"; }
oldnen

# 1. fresh install links and adds the zsh rc block
h="$(newhome fresh)"; mkstub ok "$pin" 0
runstub "$h" /bin/zsh
if [ "$rc" -eq 0 ] && [ -L "$h/.local/bin/nen" ] && [ "$("$h/.local/bin/nen" --version)" = "$pin" ] \
  && [ "$(count_blocks "$h/.zshrc")" = 1 ] && [ "$(count_blocks "$h/.zprofile")" = 1 ] \
  && has "rc: added $h/.zshrc, added $h/.zprofile" && [ -f "$h/.config/hatsu/nen-global.rc-added" ]; then
  pass "fresh install links and adds the zsh rc block"
else fail "fresh install" "rc=$rc out=$out"; fi

# 2. second run is idempotent: current, no bootstrap call, one block
calls_before="$(wc -l <"$work/calls-ok" | tr -d ' ')"
runstub "$h" /bin/zsh
if [ "$rc" -eq 0 ] && has '(current)' && has 'present' && [ "$(count_blocks "$h/.zshrc")" = 1 ] \
  && [ "$(wc -l <"$work/calls-ok" | tr -d ' ')" = "$calls_before" ]; then
  pass "second run is idempotent (current, no bootstrap call, rc present, one block)"
else fail "idempotent" "rc=$rc out=$out"; fi

# 3. stale link is relinked
h="$(newhome stale)"; mkdir -p "$h/.local/bin"
ln -s "$work/old/nen" "$h/.local/bin/nen"
runstub "$h" /bin/zsh --rc none
if [ "$rc" -eq 0 ] && [ "$("$h/.local/bin/nen" --version)" = "$pin" ] && has 'linked from' && has 'rc: skipped'; then
  pass "stale link is relinked"
else fail "stale relink" "rc=$rc out=$out"; fi

# 4. a real file at bin/nen is refused and untouched
h="$(newhome real)"; mkdir -p "$h/.local/bin"
printf '#!/bin/sh\necho 0.1.0\n' >"$h/.local/bin/nen"; chmod +x "$h/.local/bin/nen"
before="$(cksum <"$h/.local/bin/nen")"
runstub "$h" /bin/zsh
if [ "$rc" -eq 3 ] && [ ! -L "$h/.local/bin/nen" ] && [ "$(cksum <"$h/.local/bin/nen")" = "$before" ]; then
  pass "a real file at bin/nen is refused (exit 3) and untouched"
else fail "real file" "rc=$rc out=$out"; fi

# 5. bootstrap exit 5 -> exit 5, old link kept, the bootstrap's last stderr line quoted
h="$(newhome bad)"; mkdir -p "$h/.local/bin"
ln -s "$work/old/nen" "$h/.local/bin/nen"; mkstub bad "$pin" 5
runstub "$h" /bin/zsh
if [ "$rc" -eq 5 ] && [ "$(readlink "$h/.local/bin/nen")" = "$work/old/nen" ] && has 'exited 5' && has 'stub bootstrap failing'; then
  pass "bootstrap exit 5 -> exit 5, old link kept, last stderr line quoted"
else fail "bootstrap failure" "rc=$rc out=$out"; fi

# 6. opt-outs: env values (any case), the config file
h="$(newhome off)"
for v in 0 false no off OFF No FALSE; do
  NG="$v"; runstub "$h" /bin/zsh
  lv="$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')"
  if [ "$rc" -eq 0 ] && [ "$out" = "nen-global: skipped (HATSU_NEN_GLOBAL=$lv)" ] && [ ! -e "$h/.local" ] && [ ! -e "$h/.zshrc" ]; then
    pass "HATSU_NEN_GLOBAL=$v skips"
  else fail "opt-out $v" "rc=$rc out=$out"; fi
done
NG=1
mkdir -p "$h/.config/hatsu"; printf 'OFF  # not today\n' >"$h/.config/hatsu/nen-global"
runstub "$h" /bin/zsh
if [ "$rc" -eq 0 ] && [ "$out" = "nen-global: skipped (config off)" ] && [ ! -e "$h/.local" ]; then
  pass "the config file's first word off skips"
else fail "config opt-out" "rc=$rc out=$out"; fi
printf 'on\n' >"$h/.config/hatsu/nen-global"; mkstub ok "$pin" 0
runstub "$h" /bin/zsh --rc none
if [ "$rc" -eq 0 ] && has 'linked from'; then pass "a config file that does not say off does not skip"
else fail "config on" "rc=$rc out=$out"; fi

# 7. dry-run changes nothing
h="$(newhome dry)"
runstub "$h" /bin/zsh --dry-run
if [ "$rc" -eq 0 ] && [ -z "$(ls -A "$h")" ] && has 'dry-run'; then pass "--dry-run changes nothing"
else fail "dry-run" "rc=$rc out=$out ls=$(ls -A "$h")"; fi

# 8. bash picks .bashrc / .bash_profile
h="$(newhome bash)"; mkstub ok "$pin" 0
runstub "$h" /bin/bash
if [ "$rc" -eq 0 ] && [ "$(count_blocks "$h/.bashrc")" = 1 ] && [ "$(count_blocks "$h/.bash_profile")" = 1 ] && [ ! -e "$h/.zshrc" ]; then
  pass "bash SHELL picks .bashrc and .bash_profile"
else fail "bash rc" "rc=$rc out=$out"; fi

# 9. an existing PATH line is recognised; other shells use .profile
h="$(newhome pre)"; printf 'export PATH="$HOME/.local/bin:$PATH"\n' >"$h/.profile"
runstub "$h" /bin/dash
if [ "$rc" -eq 0 ] && [ "$(count_blocks "$h/.profile")" = 0 ] && has "present $h/.profile"; then
  pass "existing PATH line is left alone (.profile for other shells)"
else fail "present rc" "rc=$rc out=$out"; fi

# 10. unreadable contract -> exit 2
h="$(newhome nocontract)"; mkdir -p "$work/emptyroot"
ROOT="$work/emptyroot"; runstub "$h" /bin/zsh; ROOT=""
if [ "$rc" -eq 2 ]; then pass "unreadable contract -> exit 2"; else fail "contract" "rc=$rc out=$out"; fi

# 11. a HOME with a space: the block lands only in $HOME/.zshrc and .zprofile, nothing beside HOME or in cwd,
#     and sourcing the block puts the dir on PATH without evaluating anything else
h="$work/home with space"; mkdir -p "$h"; mkstub ok "$pin" 0
ls -A "$work" >"$work/ls-before"
runstub "$h" /bin/zsh
pathfirst="$(env -i HOME="$h" PATH=/usr/bin:/bin sh -c '. "$HOME/.zshrc"; printf %s "$PATH"' | cut -d: -f1)"
ls -A "$work" >"$work/ls-after"
newtop="$(diff "$work/ls-before" "$work/ls-after" | grep '^>' | sed 's/^> //' | tr '\n' ',')"
if [ "$rc" -eq 0 ] && [ "$(count_blocks "$h/.zshrc")" = 1 ] && [ "$(count_blocks "$h/.zprofile")" = 1 ] \
  && [ -z "$(ls -A "$work/cwd")" ] && [ "$pathfirst" = "$h/.local/bin" ] \
  && ! printf '%s' "$newtop" | tr ',' '\n' | grep -v '^\(calls-\|seen-\|ls-\|$\)' | grep -q .; then
  pass "a HOME with a space: block only in .zshrc/.zprofile, nothing beside HOME or in cwd, PATH gets the dir"
else fail "spaced HOME" "rc=$rc out=$out first=$pathfirst new=$newtop cwd=$(ls -A "$work/cwd")"; fi

# 12. --rc with a space is ONE path; a hostile bin dir is never evaluated; a quote in it is refused
h="$(newhome rcspace)"; mkstub ok "$pin" 0
runstub "$h" /bin/zsh --rc "$h/my rc file"
if [ "$rc" -eq 0 ] && [ "$(count_blocks "$h/my rc file")" = 1 ] && [ ! -e "$h/my" ] && [ ! -e "$h/rc" ] && [ ! -e "$h/.zshrc" ] && has "added $h/my rc file"; then
  pass "--rc with a space is taken as one path"
else fail "--rc spaced" "rc=$rc out=$out ls=$(ls -A "$h")"; fi
h="$(newhome hostile)"
runstub "$h" /bin/zsh --bin-dir "$h/"'x$(touch pwned)`touch pwned2`'
env -i HOME="$h" PATH=/usr/bin:/bin sh -c 'cd "$HOME" && . "$HOME/.zshrc"' 2>/dev/null
if [ "$rc" -eq 0 ] && [ ! -e "$h/pwned" ] && [ ! -e "$h/pwned2" ] && [ "$(count_blocks "$h/.zshrc")" = 1 ]; then
  pass "shell syntax in --bin-dir is written single-quoted and never evaluated"
else fail "hostile bin-dir" "rc=$rc out=$out ls=$(ls -A "$h")"; fi
runstub "$h" /bin/zsh --bin-dir "$h/it's"
if [ "$rc" -eq 2 ]; then pass "a --bin-dir containing a single quote is refused (exit 2)"; else fail "quote bin-dir" "rc=$rc out=$out"; fi

# 13. post-verification mismatch: the stub's binary prints the wrong version -> exit 5, old link byte-identical
h="$(newhome wrongver)"; mkdir -p "$h/.local/bin"; ln -s "$work/old/nen" "$h/.local/bin/nen"
mkstub wrongver 9.9.9 0
runstub "$h" /bin/zsh
if [ "$rc" -eq 5 ] && [ "$(readlink "$h/.local/bin/nen")" = "$work/old/nen" ] && [ ! -e "$h/.local/bin/nen.tmp.$$" ] && has 'does not print the pin'; then
  pass "wrong version -> exit 5, old link intact"
else fail "wrong version" "rc=$rc out=$out"; fi

# 14. digest mismatch -> exit 5, old link intact
h="$(newhome badsha)"; mkdir -p "$h/.local/bin"; ln -s "$work/old/nen" "$h/.local/bin/nen"
mkstub ok "$pin" 0
run "$h" /bin/zsh --bootstrap-script "$stub" --expect-sha256 "$(printf x | sha)"
if [ "$rc" -eq 5 ] && [ "$(readlink "$h/.local/bin/nen")" = "$work/old/nen" ] && has 'sha256 does not match'; then
  pass "digest mismatch -> exit 5, old link intact"
else fail "digest mismatch" "rc=$rc out=$out"; fi

# 15. out-of-cache, relative and directory verified paths -> exit 5, old link intact
for m in outside relative dir; do
  h="$(newhome path-$m)"; mkdir -p "$h/.local/bin"; ln -s "$work/old/nen" "$h/.local/bin/nen"
  mkstub "p$m" "$pin" 0 "$m"
  runstub "$h" /bin/zsh
  if [ "$rc" -eq 5 ] && [ "$(readlink "$h/.local/bin/nen")" = "$work/old/nen" ]; then
    pass "verified path '$m' -> exit 5, old link intact"
  else fail "verified path $m" "rc=$rc out=$out"; fi
done

# 16. bootstrap exits 4 once, then succeeds -> retried once, exit 0
h="$(newhome retry)"; mkstub retry "$pin" 0 once4
runstub "$h" /bin/zsh --rc none
if [ "$rc" -eq 0 ] && [ "$(wc -l <"$work/calls-retry" | tr -d ' ')" = 2 ] && has 'linked from'; then
  pass "bootstrap exit 4 is retried once, then links"
else fail "retry" "rc=$rc out=$out calls=$(cat "$work/calls-retry" 2>/dev/null | wc -l)"; fi

# 17. a newer linked nen whose own verdict is ok is kept; one the verdict rejects is not
mknewer() { # mknewer DIR SATISFIED — a stub nen printing $newer and a shu tools verdict
  mkdir -p "$1"
  cat >"$1/nen" <<EOS
#!/bin/sh
case "\$1" in
  --version) echo "$newer" ;;
  shu) printf '{\n  "tools": [\n    {\n      "name": "nen",\n      "satisfied": $2\n    }\n  ]\n}\n' ;;
esac
EOS
  chmod +x "$1/nen"
}
h="$(newhome newer)"; mkdir -p "$h/.local/bin"; mknewer "$work/newer-ok" true; ln -s "$work/newer-ok/nen" "$h/.local/bin/nen"
mkstub unused "$pin" 9
runstub "$h" /bin/zsh --rc none
if [ "$rc" -eq 0 ] && has "kept-newer $newer" && [ ! -e "$work/calls-unused" ] && [ "$(readlink "$h/.local/bin/nen")" = "$work/newer-ok/nen" ]; then
  pass "a newer same-major nen that satisfies the contract is kept, no bootstrap"
else fail "kept-newer" "rc=$rc out=$out"; fi
h="$(newhome newerbad)"; mkdir -p "$h/.local/bin"; mknewer "$work/newer-no" false; ln -s "$work/newer-no/nen" "$h/.local/bin/nen"
mkstub ok "$pin" 0
runstub "$h" /bin/zsh --rc none
if [ "$rc" -eq 0 ] && has 'linked from' && ! has 'kept-newer'; then pass "a newer nen the verdict rejects is replaced by the pin"
else fail "newer rejected" "rc=$rc out=$out"; fi

# 18. NEN_SOURCE / NEN_REF / NEN_CACHE_DIR in the caller's env never reach the bootstrap; it gets --source from the contract
h="$(newhome env)"; mkstub envchk "$pin" 0
export NEN_SOURCE=evil/nen NEN_REF=v0.0.1 NEN_CACHE_DIR=/nonexistent/evil
runstub "$h" /bin/zsh --rc none
unset NEN_SOURCE NEN_REF NEN_CACHE_DIR
seen="$(cat "$work/seen-envchk" 2>/dev/null)"
case "$seen" in
  "src=unset ref=unset cache=unset args=--ref $pinref --source zheref/nen") envok=1 ;; *) envok=0 ;;
esac
if [ "$rc" -eq 0 ] && [ "$envok" -eq 1 ]; then pass "the bootstrap never sees NEN_SOURCE/NEN_REF/NEN_CACHE_DIR and is handed --ref and --source"
else fail "env" "rc=$rc seen=$seen out=$out"; fi

# 19. a contract url that is not the pinned raw.githubusercontent.com address -> exit 2
mkdir -p "$work/root-badurl/nen"
sed 's#raw.githubusercontent.com/zheref/nen/#raw.githubusercontent.com/evil/nen/#g' "$root/nen/contract.json" >"$work/root-badurl/nen/contract.json"
h="$(newhome badurl)"; ROOT="$work/root-badurl"; runstub "$h" /bin/zsh; ROOT=""
if [ "$rc" -eq 2 ] && has 'bootstrap.url' && [ ! -e "$h/.local" ]; then pass "a url off the pinned address -> exit 2"
else fail "url pin" "rc=$rc out=$out"; fi

# 20. a commented PATH line, and a longer directory name, do not count as present
h="$(newhome comment)"
printf '# export PATH="$HOME/.local/bin:$PATH"\nexport PATH="$HOME/.local/bin-old:$PATH"\n' >"$h/.profile"
runstub "$h" /bin/dash
if [ "$rc" -eq 0 ] && [ "$(count_blocks "$h/.profile")" = 1 ] && has "added $h/.profile"; then
  pass "a commented or longer-named PATH line does not suppress the block"
else fail "comment rc_has" "rc=$rc out=$out"; fi

# 21. a block the user removed is never re-added
h="$(newhome removed)"
runstub "$h" /bin/zsh
printf '# my own zshrc\n' >"$h/.zshrc"
runstub "$h" /bin/zsh
if [ "$rc" -eq 0 ] && has "removed-by-user $h/.zshrc" && [ "$(count_blocks "$h/.zshrc")" = 0 ] && has "present $h/.zprofile"; then
  pass "a removed block is reported removed-by-user and not re-added"
else fail "removed block" "rc=$rc out=$out"; fi

# 21a. no previous link and the post-link probe fails -> exit 5 and NO link left behind
#      (the binary answers the pin when run by its cache path, and 9.9.9 through the new link)
h="$(newhome nolinkflip)"
flipbin="$(printf '#!/bin/sh\ncase "$0" in */.local/bin/*) echo 9.9.9 ;; *) echo "%s" ;; esac\n' "$pin")"
stub="$work/stub-flip.sh"; stubsha="$(printf '%s\n' "$flipbin" | sha)"
cat >"$stub" <<EOS
#!/bin/sh
d="\${XDG_CACHE_HOME:-\$HOME/.cache}/nen/stub"; mkdir -p "\$d"
cat >"\$d/nen-flip" <<'EOB'
$flipbin
EOB
chmod +x "\$d/nen-flip"; echo "\$d/nen-flip"
EOS
chmod +x "$stub"
runstub "$h" /bin/zsh
if [ "$rc" -eq 5 ] && [ ! -e "$h/.local/bin/nen" ] && [ ! -L "$h/.local/bin/nen" ] && has 'new one removed'; then
  pass "no previous link and a failing post-link probe -> exit 5, no link left behind"
else fail "post-link no old" "rc=$rc out=$out ls=$(ls -A "$h/.local/bin" 2>/dev/null)"; fi

# 21b. the removal record cannot be written -> no block is added, so none can be re-added later
h="$(newhome norecord)"; mkdir -p "$h/.config"; printf 'not a dir\n' >"$h/.config/hatsu"
mkstub ok "$pin" 0
runstub "$h" /bin/zsh
if [ "$rc" -eq 0 ] && [ ! -e "$h/.zshrc" ] && [ ! -e "$h/.zprofile" ] \
  && has "failed $h/.zshrc (record unwritable)"; then
  pass "an unwritable removal record -> no block added, reported"
else fail "record unwritable" "rc=$rc out=$out"; fi

# 21c. every platform the pinned release publishes has a digest in the REAL contract (linux included), and each
#      digest is the one the CURRENT pin's own record in pinned_ref_semantics (before its first `Before it,`) carries,
#      so a repin that moves pinned_ref without moving the digests goes red. Platform = asset name minus `nen-` and `.exe`.
missing=""; mismatch=""
cur_rec="$(sed -n 's/^[[:space:]]*"pinned_ref_semantics"[[:space:]]*:[[:space:]]*"\(.*\)/\1/p' "$root/nen/contract.json" | head -n 1 | sed 's/Before it,.*//')"
plats="$(awk '/"published_binaries"/ { inb = 1; next } inb && /\]/ { exit } inb { gsub(/[ ",]/, ""); sub(/^nen-/, ""); sub(/\.exe$/, ""); if ($0 != "") print }' "$root/nen/contract.json")"
[ -n "$plats" ] || missing=" (no published_binaries read)"
for p in $plats; do
  d="$(sed -n "s/^[[:space:]]*\"$p\"[[:space:]]*:[[:space:]]*\"\\([0-9a-f]\\{64\\}\\)\".*/\\1/p" "$root/nen/contract.json" | head -n 1)"
  if [ -z "$d" ]; then missing="$missing $p"
  elif ! printf '%s' "$cur_rec" | grep -qF "$d"; then mismatch="$mismatch $p"; fi
done
if [ -z "$missing" ] && [ -z "$mismatch" ]; then pass "every published platform ($(echo $plats)) has a contract digest, and it is the current pin's own record"
else fail "contract digests" "missing:$missing; not in the current pin's record:$mismatch"; fi

# 21d. a failed rc write rolls its record entry back: another file's tombstone survives, and once the
#      directory exists the file is ADDED (never read as removed-by-user)
h="$(newhome rcroll)"; mkdir -p "$h/.config/hatsu"; printf '/other\n' >"$h/.config/hatsu/nen-global.rc-added"
mkstub ok "$pin" 0
runstub "$h" /bin/zsh --rc "$h/nodir/rc"
rec="$(cat "$h/.config/hatsu/nen-global.rc-added")"
if [ "$rc" -eq 0 ] && has "failed $h/nodir/rc" && [ "$rec" = "/other" ] && ! printf '%s' "$out" | grep -q 'line [0-9]\|Permission\|No such'; then
  pass "a failed rc write: reported, no raw shell error, record rolled back to exactly the other tombstone"
else fail "record rollback" "rc=$rc out=$out record=$rec"; fi
mkdir -p "$h/nodir"
runstub "$h" /bin/zsh --rc "$h/nodir/rc"
if [ "$rc" -eq 0 ] && has "added $h/nodir/rc" && ! has 'removed-by-user'; then pass "after the rollback the file is added, not removed-by-user"
else fail "after rollback" "rc=$rc out=$out"; fi

# 21e. the record is appendable but unreadable: the rollback leaves it untouched (no truncation) and says so
h="$(newhome rcunread)"; mkdir -p "$h/.config/hatsu"; printf '/other\n' >"$h/.config/hatsu/nen-global.rc-added"
chmod 200 "$h/.config/hatsu/nen-global.rc-added"
mkstub ok "$pin" 0
runstub "$h" /bin/zsh --rc "$h/nodir/rc"
chmod 600 "$h/.config/hatsu/nen-global.rc-added"
if [ "$rc" -eq 0 ] && has 'record not rolled back' && grep -Fxq '/other' "$h/.config/hatsu/nen-global.rc-added" \
  && ! ls "$h/.config/hatsu" | grep -q 'tmp'; then
  pass "an unreadable record is not truncated by the rollback, and the summary says record not rolled back"
else fail "unreadable record" "rc=$rc out=$out record=$(cat "$h/.config/hatsu/nen-global.rc-added")"; fi

# 21f. fetch failure with a working in-range older nen already linked: exit 5, the link is untouched
h="$(newhome oldkept)"; mkdir -p "$h/.local/bin" "$work/inrange"
printf '#!/bin/sh\necho "%s.0"\n' "${pin%.*}" >"$work/inrange/nen"; chmod +x "$work/inrange/nen"
ln -s "$work/inrange/nen" "$h/.local/bin/nen"; mkstub fetchfail "$pin" 4
runstub "$h" /bin/zsh
if [ "$rc" -eq 5 ] && [ "$(readlink "$h/.local/bin/nen")" = "$work/inrange/nen" ] && [ "$("$h/.local/bin/nen" --version)" = "${pin%.*}.0" ]; then
  pass "a failed bootstrap leaves a working in-range nen link untouched (exit 5)"
else fail "old link on failure" "rc=$rc out=$out link=$(readlink "$h/.local/bin/nen")"; fi

# 22. lock: a live holder -> skipped after the wait; a dead holder's lock is broken
h="$(newhome locked)"; mkdir -p "$h/.cache/nen/.nen-global.lock"; echo $$ >"$h/.cache/nen/.nen-global.lock/pid"
mkstub ok "$pin" 0
start="$(date +%s)"; runstub "$h" /bin/zsh; end="$(date +%s)"
if [ "$rc" -eq 0 ] && [ "$out" = "nen-global: skipped (another session is binding)" ] && [ ! -e "$h/.local" ] && [ $((end - start)) -ge 9 ]; then
  pass "a held lock -> skipped (another session is binding) after the wait ($((end - start))s)"
else fail "lock held" "rc=$rc out=$out"; fi
sh -c 'exit 0' & deadpid=$!; wait "$deadpid"
echo "$deadpid" >"$h/.cache/nen/.nen-global.lock/pid"
runstub "$h" /bin/zsh --rc none
if [ "$rc" -eq 0 ] && has 'linked from' && [ ! -e "$h/.cache/nen/.nen-global.lock" ]; then pass "a dead holder's lock is broken, and the lock is released on exit"
else fail "stale lock" "rc=$rc out=$out"; fi

# 23. unwritable bin dir -> exit 4 with the old link intact
h="$(newhome ro)"; mkdir -p "$h/ro"; chmod 555 "$h/ro"
runstub "$h" /bin/zsh --bin-dir "$h/ro/bin" --rc none
if [ "$rc" -eq 4 ] && has 'host write refused'; then pass "an uncreatable bin dir -> exit 4"; else fail "mkdir refused" "rc=$rc out=$out"; fi
h="$(newhome ro2)"; mkdir -p "$h/.local/bin"; ln -s "$work/old/nen" "$h/.local/bin/nen"; chmod 555 "$h/.local/bin"
runstub "$h" /bin/zsh --rc none
if [ "$rc" -eq 4 ] && has 'host write refused' && [ "$(readlink "$h/.local/bin/nen")" = "$work/old/nen" ]; then
  pass "an unwritable bin dir -> exit 4, old link intact"
else fail "link refused" "rc=$rc out=$out"; fi
chmod 755 "$h/.local/bin" "$work/home-ro/ro"

# 24. uname stubs: a platform with no recorded digest -> exit 5; win32 -> skipped; darwin-arm64 production path, no override
for u in darwin odd mingw; do
  mkdir -p "$work/uname-$u"
  case "$u" in
    darwin) s=Darwin; m=arm64 ;;
    odd) s=Plan9; m=mips ;;
    mingw) s=MINGW64_NT-10.0; m=x86_64 ;;
  esac
  printf '#!/bin/sh\ncase "$1" in -s) echo %s ;; -m) echo %s ;; *) echo %s ;; esac\n' "$s" "$m" "$s" >"$work/uname-$u/uname"
  chmod +x "$work/uname-$u/uname"
done
h="$(newhome nodigest)"; mkstub ok "$pin" 0
RUNPATH="$work/uname-odd:$PATH"; run "$h" /bin/zsh --bootstrap-script "$stub"; RUNPATH=""
if [ "$rc" -eq 5 ] && has 'no recorded digest for plan9-mips' && [ ! -e "$h/.local" ]; then pass "a platform with no recorded digest -> exit 5, nothing linked"
else fail "no digest" "rc=$rc out=$out"; fi
RUNPATH="$work/uname-mingw:$PATH"; runstub "$h" /bin/zsh; RUNPATH=""
if [ "$rc" -eq 0 ] && [ "$out" = "nen-global: skipped (win32: symlinks are copies under MSYS)" ] && [ ! -e "$h/.local" ]; then pass "MSYS/MINGW is skipped"
else fail "win32" "rc=$rc out=$out"; fi
# the production path: contract digest for darwin-arm64 (a sed copy carrying the stub's digest), nen's own cache layout, no override
mkstub prod "$pin" 0
mkdir -p "$work/root-prod/nen"
sed "s/$real_sha/$stubsha/g" "$root/nen/contract.json" >"$work/root-prod/nen/contract.json"
cat >"$work/stub-prodpath.sh" <<EOS
#!/bin/sh
echo call >>"$work/calls-prodpath"
d="\${XDG_CACHE_HOME:-\$HOME/.cache}/nen/zheref_nen/$pinref"
mkdir -p "\$d"
printf '#!/bin/sh\necho "%s"\n' "$pin" >"\$d/nen-darwin-arm64"
chmod +x "\$d/nen-darwin-arm64"
echo "\$d/nen-darwin-arm64"
EOS
chmod +x "$work/stub-prodpath.sh"
h="$(newhome prod)"; ROOT="$work/root-prod"; RUNPATH="$work/uname-darwin:$PATH"
run "$h" /bin/zsh --bootstrap-script "$work/stub-prodpath.sh" --rc none; r1="$out"; rc1=$rc
run "$h" /bin/zsh --bootstrap-script "$work/stub-prodpath.sh" --rc none
ROOT=""; RUNPATH=""
if [ "$rc1" -eq 0 ] && [ "$rc" -eq 0 ] && has '(current)' && [ "$(wc -l <"$work/calls-prodpath" | tr -d ' ')" = 1 ] \
  && [ "$(readlink "$h/.local/bin/nen")" = "$h/.cache/nen/zheref_nen/$pinref/nen-darwin-arm64" ]; then
  pass "the production path: contract digest, nen's cache layout, then current with no second bootstrap"
else fail "production path" "rc1=$rc1 r1=$r1 rc=$rc out=$out"; fi

# 25. the fixture seam is refused without --bootstrap-script
h="$(newhome seam)"
run "$h" /bin/zsh --expect-sha256 "$real_sha"
if [ "$rc" -eq 2 ] && has 'fixture seam'; then pass "--expect-sha256 without --bootstrap-script -> exit 2"; else fail "seam" "rc=$rc out=$out"; fi

# 26. TERM: the whole child tree dies, the temp dir is removed, exit 5, quickly
h="$(newhome term)"; mkstub hang "$pin" 0 hang; rm -f "$work/childpid"; rm -rf "$work/tmp"; mkdir -p "$work/tmp"
(cd "$work/cwd" && HOME="$h" XDG_CACHE_HOME="$h/.cache" XDG_CONFIG_HOME="$h/.config" TMPDIR="$work/tmp" SHELL=/bin/zsh HATSU_NEN_GLOBAL=1 \
  sh "$script" --root "$root" --bootstrap-script "$stub" --expect-sha256 "$stubsha" >"$work/term.out" 2>&1) &
tpid=$!
i=0; while [ ! -s "$work/childpid" ] && [ "$i" -lt 50 ]; do sleep 0.2; i=$((i + 1)); done
child="$(cat "$work/childpid" 2>/dev/null)"
# the subshell's pid is $tpid; the script is its child — TERM the script, found as a descendant
spid="$(ps -A -o pid= -o ppid= | awk -v p="$tpid" '$2 == p { print $1 }' | head -n 1)"
t0="$(date +%s)"; kill -TERM "${spid:-$tpid}" 2>/dev/null; wait "$tpid" 2>/dev/null; trc=$?; t1="$(date +%s)"
sleep 0.5
leaked="$(ls -A "$work/tmp" | tr '\n' ' ')"
if [ -n "$child" ] && ! kill -0 "$child" 2>/dev/null && [ "$trc" -eq 5 ] && [ -z "$leaked" ] && [ $((t1 - t0)) -le 4 ] \
  && grep -q 'terminated by the time limit' "$work/term.out" && [ ! -e "$h/.cache/nen/.nen-global.lock" ]; then
  pass "TERM kills the bootstrap's child tree, removes the temp dir and the lock, exits 5 in $((t1 - t0))s"
else fail "TERM" "trc=$trc child=$child alive=$(kill -0 "$child" 2>/dev/null && echo yes) leaked=$leaked out=$(cat "$work/term.out")"; kill "$child" 2>/dev/null; fi

# --- the hook's step 0 -----------------------------------------------------------------
# A plugin root copy: the hook, the script, a contract whose darwin-arm64 digest is the stub's, a manifest,
# a stub surface_bootstrap.sh. The state is seeded `current`, so no bootstrap and no network run.
mkstub hookbin "$pin" 0
mkplugin() { # mkplugin DIR
  mkdir -p "$1/hooks" "$1/scripts" "$1/nen" "$1/.claude-plugin"
  cp "$hook" "$1/hooks/session-start.sh"; cp "$script" "$1/scripts/nen_global.sh"
  sed "s/$real_sha/$stubsha/g" "$root/nen/contract.json" >"$1/nen/contract.json"
  printf '{\n  "name": "hatsu"\n}\n' >"$1/.claude-plugin/plugin.json"
  printf '#!/bin/sh\necho "stub surface bootstrap ran"\n' >"$1/scripts/surface_bootstrap.sh"
  chmod +x "$1/hooks/session-start.sh" "$1/scripts/nen_global.sh" "$1/scripts/surface_bootstrap.sh"
}
seedcurrent() { # seedcurrent HOME
  _d="$1/.cache/nen/zheref_nen/$pinref"; mkdir -p "$_d" "$1/.local/bin"
  printf '#!/bin/sh\necho "%s"\n' "$pin" >"$_d/nen-darwin-arm64"; chmod +x "$_d/nen-darwin-arm64"
  ln -s "$_d/nen-darwin-arm64" "$1/.local/bin/nen"
}
hookrun() { # hookrun HOME CWD HOOKFILE [ENV=VAL...] — stdout in $hout, stderr in $herr, rc in $hrc
  _hh="$1"; _hc="$2"; _hf="$3"; shift 3
  hout="$( cd "$_hc" && env -u HATSU_PLUGIN_ROOT -u PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT HOME="$_hh" XDG_CACHE_HOME="$_hh/.cache" XDG_CONFIG_HOME="$_hh/.config" TMPDIR="$work/tmp" \
    PATH="$work/uname-darwin:$PATH" SHELL=/bin/zsh HATSU_NEN_GLOBAL=1 "$@" sh "$_hf" 2>"$work/hook.err")"
  hrc=$?
  herr="$(cat "$work/hook.err")"
}
mkplugin "$work/plugin"

# 27. source copy: one line of JSON that parses and carries `nen-global reported:`, even with quote and backslash in the summary
h="$work/ho\"me\\x"; mkdir -p "$h"; seedcurrent "$h"
hookrun "$h" "$work/cwd" "$work/plugin/hooks/session-start.sh"
lines="$(printf '%s\n' "$hout" | wc -l | tr -d ' ')"
parsed="$(printf '%s' "$hout" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["hookSpecificOutput"]["additionalContext"])' 2>&1)"
if [ "$hrc" -eq 0 ] && [ "$lines" = 1 ] && printf '%s' "$parsed" | grep -qF 'nen-global reported: nen-global: nen' \
  && printf '%s' "$parsed" | grep -qF "$h/.local/bin/nen" && printf '%s' "$parsed" | grep -q '(current)'; then
  pass "source copy: one-line JSON that parses, carrying 'nen-global reported:' with a quote and backslash in the path"
else fail "hook source JSON" "hrc=$hrc lines=$lines parsed=$parsed raw=$hout"; fi

# 28. HATSU_NEN_GLOBAL=0 -> skipped in the context
h="$(newhome hookoff)"
hookrun "$h" "$work/cwd" "$work/plugin/hooks/session-start.sh" HATSU_NEN_GLOBAL=0
parsed="$(printf '%s' "$hout" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])' 2>&1)"
if [ "$hrc" -eq 0 ] && printf '%s' "$parsed" | grep -qF 'nen-global reported: nen-global: skipped (HATSU_NEN_GLOBAL=0)' && [ ! -e "$h/.local" ]; then
  pass "hook: HATSU_NEN_GLOBAL=0 -> skipped, nothing written"
else fail "hook opt-out" "parsed=$parsed"; fi

# 29. a long summary is capped at 200 characters
h="$work/home-$(awk 'BEGIN { for (i = 0; i < 300; i++) printf "n" }')"; mkdir -p "$h" 2>/dev/null && seedcurrent "$h"
hookrun "$h" "$work/cwd" "$work/plugin/hooks/session-start.sh"
parsed="$(printf '%s' "$hout" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])' 2>&1)"
rep="${parsed#*nen-global reported: }"
if [ "$hrc" -eq 0 ] && [ "${#rep}" -le 200 ] && [ "${#rep}" -gt 100 ]; then pass "the reported line is capped at 200 characters (${#rep})"
else fail "cap" "len=${#rep} parsed=$parsed"; fi

# 30. mirrored copy, target not adopted -> the line goes to stderr, no log
mkdir -p "$work/plugin-m/hooks"
mkmirror() { # mkmirror SURFACE DEST
  { sed -n '1p' "$hook"; printf '# GENERATED by nen surface mirror (surface: %s, stamp: fixture) -- fixture copy\n' "$1"; sed -n '3,$p' "$hook"; } >"$2"
  chmod +x "$2"
}
mkmirror codex "$work/mirror-codex.sh"
tgt="$work/target-plain"; mkdir -p "$tgt/.agents" "$tgt/nen"; echo '{}' >"$tgt/nen/workflow.json"
h="$(newhome hookm)"; seedcurrent "$h"
hookrun "$h" "$tgt" "$work/mirror-codex.sh" HATSU_PLUGIN_ROOT="$work/plugin"
if [ "$hrc" -eq 0 ] && printf '%s' "$herr" | grep -q 'nen-global: nen' && [ ! -e "$tgt/.nen/session-start.log" ] && [ -z "$hout" ]; then
  pass "mirrored copy, target not adopted: the line goes to stderr, no log"
else fail "mirror stderr" "hrc=$hrc herr=$herr hout=$hout"; fi

# 31. mirrored copy, adopted -> .nen/session-start.log carries the line and the refresh
mkdir -p "$tgt/.agents/skills/ten"
printf '# GENERATED by nen surface mirror (surface: codex, stamp: fixture)\n' >"$tgt/.agents/skills/ten/SKILL.md"
hookrun "$h" "$tgt" "$work/mirror-codex.sh" HATSU_PLUGIN_ROOT="$work/plugin"
if [ "$hrc" -eq 0 ] && grep -q 'nen-global: nen' "$tgt/.nen/session-start.log" 2>/dev/null && grep -q 'stub surface bootstrap ran' "$tgt/.nen/session-start.log" && [ -z "$herr" ]; then
  pass "mirrored copy, adopted: .nen/session-start.log carries the nen-global line and the refresh"
else fail "mirror log" "hrc=$hrc herr=$herr log=$(cat "$tgt/.nen/session-start.log" 2>/dev/null)"; fi

# 32. Codex's PLUGIN_ROOT is accepted on a codex copy only
rm -rf "$tgt/.nen"
hookrun "$h" "$tgt" "$work/mirror-codex.sh" PLUGIN_ROOT="$work/plugin"
codexok=0; grep -q 'stub surface bootstrap ran' "$tgt/.nen/session-start.log" 2>/dev/null && codexok=1
mkmirror cursor "$work/mirror-cursor.sh"
tgt2="$work/target-cursor"; mkdir -p "$tgt2/.cursor/skills/ten" "$tgt2/nen"; echo '{}' >"$tgt2/nen/workflow.json"
printf '# GENERATED by nen surface mirror (surface: cursor, stamp: fixture)\n' >"$tgt2/.cursor/skills/ten/SKILL.md"
hookrun "$h" "$tgt2" "$work/mirror-cursor.sh" PLUGIN_ROOT="$work/plugin"
if [ "$codexok" -eq 1 ] && [ ! -e "$tgt2/.nen" ] && [ -z "$herr" ]; then pass "PLUGIN_ROOT is read on a codex-marked copy, ignored on a cursor-marked one"
else fail "PLUGIN_ROOT" "codexok=$codexok herr=$herr ls=$(ls -A "$tgt2")"; fi

# 33. the hook's own TERM: no descendant and no temp file outlives it
rm -rf "$work/tmp"; mkdir -p "$work/tmp"
mkstub hookhang "$pin" 0 hang
mkplugin "$work/plugin-hang"
cat >"$work/plugin-hang/scripts/nen_global.sh" <<EOS
#!/bin/sh
sleep 303 &
echo \$! >"$work/hookchild"
wait
EOS
chmod +x "$work/plugin-hang/scripts/nen_global.sh"
h="$(newhome hookterm)"; rm -f "$work/hookchild"
(cd "$work/cwd" && HOME="$h" TMPDIR="$work/tmp" sh "$work/plugin-hang/hooks/session-start.sh" >"$work/hookterm.out" 2>&1) &
hp=$!
i=0; while [ ! -s "$work/hookchild" ] && [ "$i" -lt 50 ]; do sleep 0.2; i=$((i + 1)); done
hchild="$(cat "$work/hookchild" 2>/dev/null)"
hspid="$(ps -A -o pid= -o ppid= | awk -v p="$hp" '$2 == p { print $1 }' | head -n 1)"
kill -TERM "${hspid:-$hp}" 2>/dev/null; wait "$hp" 2>/dev/null
sleep 0.5
if [ -n "$hchild" ] && ! kill -0 "$hchild" 2>/dev/null && [ -z "$(ls -A "$work/tmp")" ]; then pass "the hook's own TERM leaves no descendant and no temp file"
else fail "hook TERM" "child=$hchild tmp=$(ls -A "$work/tmp")"; kill "$hchild" 2>/dev/null; fi

[ -z "$(ls -A "$work/cwd")" ] || fail "cwd" "a case wrote into the cwd: $(ls -A "$work/cwd")"
if [ "$fails" -ne 0 ]; then echo "nen-global-fixture: $fails case(s) failed" >&2; exit 1; fi
echo "nen-global-fixture: all cases passed"
