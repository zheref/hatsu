#!/bin/sh
# nen_global.sh — bind the contract-pinned `nen` on the host, idempotently.
#
# WHAT THIS IS
# The host half of the hard Nen dependency (D10). It makes the `nen` binary the
# contract pins available under the name `nen` on the machine's own PATH, for
# agents and for a human at a terminal alike, and keeps it current: the
# SessionStart hook (hooks/session-start.sh) runs it first on every session.
# This binds the name `nen` on the host — ten § 2 (a), made the default by the
# maintainer's ruling of 2026-09-30 — and runs nen's OWN checksum-verified
# bootstrap at the contract's pin; it never vendors, pipes or improvises the
# bootstrap. Steps:
#
#   0. Opt-outs and bounds: HATSU_NEN_GLOBAL in 0|false|no|off (any case), or a
#      file ${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/nen-global whose first word
#      is `off`, or an MSYS/MINGW/CYGWIN uname (symlinks are copies there) →
#      one `skipped (...)` line, exit 0.
#   1. Probe `<bin-dir>/nen`. A binary STRICTLY NEWER than the pin with the same
#      major whose own `shu tools` verdict says nen is satisfied is kept
#      (`kept-newer <v>`, never downgraded, no network). Otherwise the state is
#      `current` ONLY when the link points at the expected verified file in
#      nen's cache, that file hashes to the digest the contract records
#      (dependency.bootstrap.sha256, per platform) and it prints the pin. Both
#      end here with NO network.
#   2. Otherwise, under a lock (`<cache>/nen/.nen-global.lock`, a mkdir; a second
#      session waits ~10 s, then reports `skipped (another session is binding)`),
#      fetch nen's bootstrap TWO-STEP (curl to a file, then run the file —
#      contract: bootstrap.fetch_must_be_two_step, never a pipe) at the contract
#      url — accepted only when it equals
#      https://raw.githubusercontent.com/<dependency.source>/<pinned_ref>/<script_path_in_source>
#      — and run it with the NEN_SOURCE/NEN_REF/NEN_CACHE_DIR environment removed
#      and `--ref <pinned_ref> --source <dependency.source>`. The LAST stdout
#      line must be an absolute regular, executable, non-symlink file under
#      ${XDG_CACHE_HOME:-$HOME/.cache}/nen/, must hash to the recorded digest
#      and print the pin — ALL BEFORE any link is made. Then `<bin-dir>/nen` is
#      replaced atomically (`ln -s` to a temp name, `mv -f` over the link); the
#      binary is never copied or renamed. A platform with no recorded digest is
#      never linked unverified.
#   3. Make <bin-dir> reachable: append one marked block to the shell's own
#      profile files (zsh: ~/.zshrc, ~/.zprofile; bash: ~/.bashrc,
#      ~/.bash_profile; anything else: ~/.profile) unless a non-comment line
#      there already puts the directory on PATH. The directory is written
#      single-quoted (a leading $HOME stays `"$HOME"'/rest'`), so no shell
#      syntax in a path is ever evaluated. Existing content is never rewritten,
#      and a file this script once added the block to, which no longer has it,
#      is reported `removed-by-user` and never re-added (record:
#      ${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/nen-global.rc-added).
#
# Usage:
#   nen_global.sh --root <hatsu_root> [--bin-dir <dir>] [--rc auto|none|<file>]
#                 [--bootstrap-script <file> [--expect-sha256 <hex>]]
#                 [--dry-run] [--quiet]
#
#   --root              the Hatsu checkout or installed plugin root carrying
#                       nen/contract.json (required)
#   --bin-dir           where the `nen` link lives; default $HOME/.local/bin; a
#                       directory containing a single quote or a newline is
#                       refused (exit 2)
#   --rc                auto (default, by $SHELL), none, or exactly ONE file
#                       (one path, spaces allowed)
#   --bootstrap-script  use this local file instead of fetching the contract's
#                       url (the FIXTURE SEAM; the two-step run is unchanged)
#   --expect-sha256     FIXTURE SEAM, accepted ONLY together with
#                       --bootstrap-script and never from the environment: the
#                       digest the stub's binary must have, in place of the
#                       contract's per-platform one. With it the cache-path
#                       equality of step 1 is relaxed to "under the cache".
#   --dry-run           say what would happen; change nothing, touch no network
#   --quiet             print only the summary line and errors
#
# EXIT CODES
#   0  ok — current, kept-newer, linked, or skipped (opt-out, win32, lock)
#   2  usage error, nen/contract.json unreadable or its url/source not the
#      pinned raw.githubusercontent.com address, or a refused --bin-dir
#   3  refused: <bin-dir>/nen exists and is a real file, not a symlink; it is
#      someone's own and is never replaced
#   4  host write refused: the bin dir or the cache dir cannot be created, or
#      the link cannot be written (the old link is left intact)
#   5  bootstrap or verification failed (fetch, the bootstrap's own exit code,
#      a verified path that is not absolute / not under the cache / not a
#      regular executable, a digest or version that does not match, no recorded
#      digest for the platform, or a TERM from the hook's time limit)
#
# FAIL SEMANTICS. Nothing here is a gate: on any failure the existing link is
# left exactly as it was, one line names the rc and its meaning, and the caller
# (a fail-open hook) carries on. The contract's retry policy is honoured: the
# bootstrap's exit 4 is retried once; 5, 6, 3 and curl 22/56 never are, because
# retrying a checksum failure is how a fail-closed guard becomes fail-open.
# Every network step is --max-time bounded, runs in the background and is
# `wait`ed on, so a TERM from the hook's watchdog is honoured at once: the whole
# child tree is killed, the temp dir and the lock are removed, and the script
# exits 5. Failure lines never echo the bootstrap's stdout or a binary's raw
# --version; the last stderr line of the curl/bootstrap is quoted at <= 120
# printable characters. POSIX sh; no jq, yq or python.
set -u
umask 022

root=""
bindir=""
rcmode="auto"
bscript=""
expect_override=""
dry=0
quiet=0

die() { echo "nen-global: $2" >&2; exit "$1"; }
say() { [ "$quiet" -eq 1 ] || printf '%s\n' "nen-global: $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || die 2 "--root needs a value"; root="$2"; shift 2 ;;
    --bin-dir) [ $# -ge 2 ] || die 2 "--bin-dir needs a value"; bindir="$2"; shift 2 ;;
    --rc) [ $# -ge 2 ] || die 2 "--rc needs a value"; rcmode="$2"; shift 2 ;;
    --bootstrap-script) [ $# -ge 2 ] || die 2 "--bootstrap-script needs a value"; bscript="$2"; shift 2 ;;
    --expect-sha256) [ $# -ge 2 ] || die 2 "--expect-sha256 needs a value"; expect_override="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    --quiet) quiet=1; shift ;;
    *) die 2 "unknown argument '$1'" ;;
  esac
done

# --- step 0: opt-outs -------------------------------------------------------------
ng_env="$(printf '%s' "${HATSU_NEN_GLOBAL:-}" | tr '[:upper:]' '[:lower:]')"
case "$ng_env" in
  0|false|no|off) echo "nen-global: skipped (HATSU_NEN_GLOBAL=$ng_env)"; exit 0 ;;
esac

[ -n "$root" ] || die 2 "usage: nen_global.sh --root <hatsu_root> [--bin-dir <dir>] [--rc auto|none|<file>] [--bootstrap-script <file> [--expect-sha256 <hex>]] [--dry-run] [--quiet]"
[ -n "${HOME:-}" ] || die 2 "HOME is not set"
if [ -n "$expect_override" ]; then
  [ -n "$bscript" ] || die 2 "--expect-sha256 is the fixture seam and is accepted only with --bootstrap-script"
  case "$expect_override" in *[!0-9a-f]*) die 2 "--expect-sha256 takes 64 lowercase hex digits" ;; esac
  [ "${#expect_override}" -eq 64 ] || die 2 "--expect-sha256 takes 64 lowercase hex digits"
fi

cfgdir="${XDG_CONFIG_HOME:-$HOME/.config}/hatsu"
if [ -f "$cfgdir/nen-global" ]; then
  cfg_word="$(awk 'NF { print tolower($1); exit }' "$cfgdir/nen-global" 2>/dev/null)"
  if [ "$cfg_word" = "off" ]; then echo "nen-global: skipped (config off)"; exit 0; fi
fi

uname_s="$(uname -s 2>/dev/null || echo unknown)"
uname_m="$(uname -m 2>/dev/null || echo unknown)"
case "$uname_s" in
  MINGW*|MSYS*|CYGWIN*) echo "nen-global: skipped (win32: symlinks are copies under MSYS)"; exit 0 ;;
esac

# --- the contract -----------------------------------------------------------------
contract="$root/nen/contract.json"
[ -f "$contract" ] || die 2 "contract unreadable: $contract"
jstr() { sed -n 's/^[[:space:]]*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$contract" | head -n 1; }
pinned_ref="$(jstr pinned_ref)"
url="$(sed -n 's/^[[:space:]]*"url"[[:space:]]*:[[:space:]]*"\(https:[^"]*\/bootstrap\/[^"]*\)".*/\1/p' "$contract" | head -n 1)"
source="$(jstr source)"
script_path="$(jstr script_path_in_source)"
[ -n "$pinned_ref" ] || die 2 "contract unreadable: no dependency.pinned_ref in $contract"
[ -n "$url" ] || die 2 "contract unreadable: no dependency.bootstrap.url in $contract"
[ -n "$source" ] || die 2 "contract unreadable: no dependency.source in $contract"
[ -n "$script_path" ] || die 2 "contract unreadable: no dependency.bootstrap.script_path_in_source in $contract"
case "$source" in */*/*|*[!A-Za-z0-9._/-]*|/*|*/) die 2 "contract: dependency.source is not owner/name" ;; esac
case "$pinned_ref" in *[!A-Za-z0-9._-]*) die 2 "contract: dependency.pinned_ref has unexpected characters" ;; esac
[ "$url" = "https://raw.githubusercontent.com/$source/$pinned_ref/$script_path" ] \
  || die 2 "contract: bootstrap.url is not https://raw.githubusercontent.com/<source>/<pinned_ref>/<script_path_in_source>"
pin="${pinned_ref#v}"
[ -z "$bscript" ] || [ -f "$bscript" ] || die 2 "--bootstrap-script '$bscript' is not a file"

os="$(printf '%s' "$uname_s" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '_')"
case "$uname_m" in
  arm64|aarch64) arch=arm64 ;;
  x86_64|amd64) arch=x64 ;;
  *) arch="$(printf '%s' "$uname_m" | tr -c 'A-Za-z0-9\n' '_')" ;;
esac
platform="$os-$arch"
contract_sha="$(awk -v k="$platform" '
  /"sha256"[[:space:]]*:[[:space:]]*\{/ { inb = 1; next }
  inb && /^[[:space:]]*\}/ { exit }
  inb { n = split($0, a, "\""); if (n >= 4 && a[2] == k) { print a[4]; exit } }' "$contract")"

[ -n "$bindir" ] || bindir="$HOME/.local/bin"
bindir="${bindir%/}"
case "$bindir" in
  *"'"*) die 2 "--bin-dir may not contain a single quote" ;;
  *"
"*) die 2 "--bin-dir may not contain a newline" ;;
esac
link="$bindir/nen"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/nen"
lock="$cache/.nen-global.lock"

d=""
kids=""
have_lock=0
cleanup() {
  [ -z "$d" ] || rm -rf "$d"
  [ "$have_lock" -eq 0 ] || rm -rf "$lock"
}
trap cleanup EXIT

# descendants PID — every descendant pid, one per line (POSIX ps + awk).
descendants() {
  ps -A -o pid= -o ppid= 2>/dev/null | awk -v root="$1" '
    { p[NR] = $1; q[NR] = $2 }
    END {
      m[root] = 1; changed = 1
      while (changed) { changed = 0
        for (i = 1; i <= NR; i++) if (!(p[i] in m) && (q[i] in m)) { m[p[i]] = 1; changed = 1 } }
      for (i = 1; i <= NR; i++) if (p[i] != root && (p[i] in m)) print p[i]
    }'
}
kill_tree() {
  _all="$(descendants "$1")"
  for _p in $_all; do kill -TERM "$_p" 2>/dev/null; done
  kill -TERM "$1" 2>/dev/null
  return 0
}
on_term() {
  for _k in $kids; do kill_tree "$_k"; done
  echo "nen-global: terminated by the time limit; the existing link was left as it was" >&2
  exit 5
}
trap on_term HUP INT TERM

# bg_run OUT ERR CMD... — run CMD in the background with stdout/stderr to files and
# wait for it; sets bg_rc. A trapped TERM interrupts the wait at once.
bg_run() {
  _o="$1"; _e="$2"; shift 2
  "$@" >"$_o" 2>"$_e" </dev/null &
  kids="$!"
  wait "$kids"
  bg_rc=$?
  kids=""
}

# lastline FILE — the last line of FILE, printable ASCII only, <= 120 chars.
lastline() { tail -n 1 "$1" 2>/dev/null | tr -cd '[:print:]' | cut -c1-120; }

# sha_of FILE — lowercase sha256 of FILE, or nothing. A path carrying a backslash
# or newline makes the tool print the digest with a leading backslash; it is stripped.
sha_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" 2>/dev/null | awk '{ h = tolower($1); sub(/^\\/, "", h); print h }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | awk '{ h = tolower($1); sub(/^\\/, "", h); print h }'
  fi
}

# version_of FILE — the version a binary reports: the last word of the first
# line of `--version` output, without a leading `v` (accepts `0.18.1`, `nen 0.18.1`).
version_of() {
  [ -x "$1" ] || return 0
  "$1" --version 2>/dev/null </dev/null | head -n 1 | awk '{print $NF}' | sed 's/^v//'
}

is_semver() { case "$1" in ''|*[!0-9.]*|.*|*.|*..*) return 1 ;; esac; [ "$(printf '%s' "$1" | tr -cd '.' | wc -c | tr -d ' ')" = 2 ]; }
semver_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 1 }'
}

# --- rc targets ---------------------------------------------------------------------
# The bin dir as a profile line spells it. NEVER inside double quotes: a leading
# $HOME stays a quoted "$HOME", the rest of the path is single-quoted, so no
# shell syntax in the path is evaluated (a quote or newline was refused above).
case "$bindir" in
  "$HOME"/*)
    bin_q="\"\$HOME\"'/${bindir#"$HOME"/}'"
    bin_expr="\$HOME/${bindir#"$HOME"/}"
    # shellcheck disable=SC2088  # a literal `~/` as a profile line may spell it, never expanded here
    bin_tilde="~/${bindir#"$HOME"/}"
    bin_brace="\${HOME}/${bindir#"$HOME"/}"
    ;;
  *) bin_q="'$bindir'"; bin_expr="$bindir"; bin_tilde="$bindir"; bin_brace="$bindir" ;;
esac

# rc_has FILE — our marker block is there, or a NON-COMMENT line mentioning PATH
# carries the dir followed by `:`, `"`, `'` or the end of the line.
rc_has() {
  [ -f "$1" ] || return 1
  grep -q '>>> hatsu nen-global >>>' "$1" 2>/dev/null && return 0
  for needle in "$bindir" "$bin_expr" "$bin_tilde" "$bin_brace"; do
    awk -v n="$needle" -v q="'" '
      /^[ \t]*#/ { next }
      /PATH/ { s = $0
        while ((i = index(s, n)) > 0) {
          c = substr(s, i + length(n), 1)
          if (c == "" || c == ":" || c == "\"" || c == q) { found = 1; exit }
          s = substr(s, i + 1) } }
      END { exit !found }' "$1" 2>/dev/null && return 0
  done
  return 1
}

rc_record="$cfgdir/nen-global.rc-added"
rc_summary=""
rc_note() { rc_summary="${rc_summary:+$rc_summary, }$1"; }

# rc_one FILE — add the marked block to ONE file where missing; appends to rc_summary.
rc_one() {
  _f="$1"
  if rc_has "$_f"; then rc_note "present $_f"; return 0; fi
  if [ -f "$rc_record" ] && grep -Fxq -- "$_f" "$rc_record" 2>/dev/null; then
    rc_note "removed-by-user $_f"; return 0
  fi
  if [ "$dry" -eq 1 ]; then rc_note "would-add $_f"; return 0; fi
  if {
    [ ! -s "$_f" ] || [ -z "$(tail -c 1 "$_f" 2>/dev/null)" ] || printf '\n'
    printf '%s\n' "# >>> hatsu nen-global >>>"
    printf '%s\n' "case \":\$PATH:\" in *\":\"${bin_q}\":\"*) ;; *) export PATH=${bin_q}\":\$PATH\" ;; esac"
    printf '%s\n' "# <<< hatsu nen-global <<<"
  } >>"$_f" 2>/dev/null; then
    mkdir -p "$cfgdir" 2>/dev/null && printf '%s\n' "$_f" >>"$rc_record" 2>/dev/null
    rc_note "added $_f"
  else
    echo "nen-global: could not write $_f" >&2
    rc_note "failed $_f"
  fi
}

rc_apply() {
  rc_summary=""
  case "$rcmode" in
    none) rc_summary="skipped" ;;
    auto)
      case "$(basename "${SHELL:-}")" in
        zsh) rc_one "$HOME/.zshrc"; rc_one "$HOME/.zprofile" ;;
        bash) rc_one "$HOME/.bashrc"; rc_one "$HOME/.bash_profile" ;;
        *) rc_one "$HOME/.profile" ;;
      esac
      ;;
    *) rc_one "$rcmode" ;;
  esac
}

# --- step 1: assess (cheap, no network) ------------------------------------------------
# Sets state=current|kept-newer|need, keptv, expect.
state=need; keptv=""; expect=""
if [ -n "$expect_override" ]; then
  expect="$expect_override"; expected_file=""
else
  expect="$contract_sha"; expected_file=""
  case "$expect" in *[!0-9a-f]*) expect="" ;; esac
  [ "${#expect}" -eq 64 ] || expect=""
  # nen's own cache layout: <cache>/<slug(source)>/<slug(ref)>/nen-<platform>
  expected_file="$cache/$(printf '%s' "$source" | tr -c 'A-Za-z0-9._-' '_')/$(printf '%s' "$pinned_ref" | tr -c 'A-Za-z0-9._-' '_')/nen-$platform"
fi

assess() {
  state=need; keptv=""
  have="$(version_of "$link")"
  # Never downgrade: strictly newer, same major, and its own verdict says nen is ok.
  if is_semver "$have" && [ "${have%%.*}" = "${pin%%.*}" ] && semver_gt "$have" "$pin"; then
    verdict="$(PATH="$bindir:$PATH" "$link" shu tools --repo "$root" --json 2>/dev/null </dev/null \
      | awk '/"name"[[:space:]]*:[[:space:]]*"nen"/ { f = 1 } f && /"satisfied"/ { print ($0 ~ /true/) ? "ok" : "no"; exit }')"
    if [ "$verdict" = "ok" ]; then state=kept-newer; keptv="$have"; return 0; fi
  fi
  [ -n "$expect" ] || die 5 "no recorded digest for $platform; nothing is linked unverified"
  # Current: the link points at the expected verified file, its digest matches, it prints the pin.
  if [ -L "$link" ]; then
    _t="$(readlink "$link" 2>/dev/null)"
    case "$_t" in /*) ;; *) _t="$bindir/$_t" ;; esac
    if [ -n "$expected_file" ]; then _tok=0; [ "$_t" = "$expected_file" ] && _tok=1
    else _tok=0; case "$_t" in "$cache"/*) _tok=1 ;; esac; fi
    if [ "$_tok" -eq 1 ] && [ -f "$_t" ] && [ "$(sha_of "$_t")" = "$expect" ] && [ "$(version_of "$_t")" = "$pin" ]; then
      state=current
    fi
  fi
  return 0
}

assess
if [ "$state" = need ]; then
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    die 3 "$link is a real file, not a symlink — refusing to replace it"
  fi
  if [ "$dry" -eq 1 ]; then
    rc_apply
    echo "nen-global: dry-run: nen ${have:-absent} at $link would be bootstrapped at $pinned_ref and linked · rc: $rc_summary"
    exit 0
  fi
  # --- lock: one session binds at a time; re-assess once it is ours ------------------
  mkdir -p "$cache" 2>/dev/null || die 4 "host write refused: cannot create $cache"
  waited=0
  while ! mkdir "$lock" 2>/dev/null; do
    # A holder that died without cleaning up (SIGKILL) must not wedge every
    # session: a dead recorded pid, or a lock older than 3 minutes, is broken.
    _hp="$(cat "$lock/pid" 2>/dev/null || true)"
    if { [ -n "$_hp" ] && ! kill -0 "$_hp" 2>/dev/null; } || [ -n "$(find "$lock" -maxdepth 0 -mmin +3 2>/dev/null)" ]; then
      rm -rf "$lock"; continue
    fi
    if [ "$waited" -ge 10 ]; then
      echo "nen-global: skipped (another session is binding)"
      exit 0
    fi
    sleep 1; waited=$((waited + 1))
  done
  have_lock=1
  printf '%s\n' "$$" >"$lock/pid" 2>/dev/null || true
  assess
fi

if [ "$state" = need ]; then
  # --- step 2: two-step bootstrap, never piped ---------------------------------------
  d="$(mktemp -d "${TMPDIR:-/tmp}/nen-global.XXXXXX")" || die 5 "mktemp failed"
  chmod 700 "$d"
  script="$d/nen-bootstrap.sh"
  if [ -n "$bscript" ]; then
    script="$bscript"
  else
    say "fetching $url"
    bg_run "$d/curl.out" "$d/curl.err" curl -fsSL --max-time 30 "$url" -o "$script"
    crc=$bg_rc
    if [ "$crc" -ne 0 ]; then
      case "$crc" in
        22|56) meaning="the script is absent at the pinned ref (tag or release not published); never retried" ;;
        28) meaning="the fetch timed out" ;;
        *) meaning="the bootstrap script could not be fetched" ;;
      esac
      die 5 "bootstrap fetch failed (curl rc $crc: $meaning; $(lastline "$d/curl.err")); existing link left as it was"
    fi
  fi
  attempt=1
  while :; do
    bg_run "$d/bootstrap.out" "$d/bootstrap.err" \
      env -u NEN_SOURCE -u NEN_REF -u NEN_CACHE_DIR bash "$script" --ref "$pinned_ref" --source "$source"
    brc=$bg_rc
    if [ "$brc" -eq 4 ] && [ "$attempt" -eq 1 ]; then
      attempt=2
      say "bootstrap exit 4 (download); retrying once"
      continue
    fi
    break
  done
  if [ "$brc" -ne 0 ]; then
    case "$brc" in
      2) meaning="usage" ;;
      3) meaning="unsupported host" ;;
      4) meaning="download failed after one retry" ;;
      5) meaning="CHECKSUM — bytes did not verify; never retried" ;;
      6) meaning="manifest unfetchable or malformed; never retried" ;;
      *) meaning="unexpected" ;;
    esac
    die 5 "bootstrap exited $brc ($meaning; $(lastline "$d/bootstrap.err")); existing link left as it was"
  fi
  # --- verify BEFORE linking ------------------------------------------------------------
  verified="$(tail -n 1 "$d/bootstrap.out")"
  bad=""
  case "$verified" in
    "") bad="printed no path" ;;
    /*) ;;
    *) bad="printed a path that is not absolute" ;;
  esac
  if [ -z "$bad" ]; then
    case "$verified" in
      */../*|*/..) bad="printed a path with a .. component" ;;
      "$cache"/*) ;;
      *) bad="printed a path outside $cache" ;;
    esac
  fi
  if [ -z "$bad" ]; then
    if [ -L "$verified" ]; then bad="printed a symlink"
    elif [ ! -f "$verified" ]; then bad="printed a path that is not a regular file"
    elif [ ! -x "$verified" ]; then bad="printed a path that is not executable"
    fi
  fi
  [ -z "$bad" ] || die 5 "bootstrap $bad; existing link left as it was"
  got_sha="$(sha_of "$verified")"
  [ -n "$got_sha" ] || die 5 "no sha256 tool (shasum or sha256sum) to verify the binary; existing link left as it was"
  [ "$got_sha" = "$expect" ] || die 5 "the bootstrapped binary's sha256 does not match the contract's digest for $platform; existing link left as it was"
  got="$(version_of "$verified")"
  [ "$got" = "$pin" ] || die 5 "the bootstrapped binary does not print the pin $pin; existing link left as it was"
  # --- link atomically --------------------------------------------------------------------
  mkdir -p "$bindir" 2>/dev/null || die 4 "host write refused: cannot create $bindir"
  [ ! -d "$link" ] || die 4 "host write refused: $link is a directory"
  oldtarget=""; [ ! -L "$link" ] || oldtarget="$(readlink "$link" 2>/dev/null)"
  tmplink="$link.tmp.$$"
  rm -f "$tmplink" 2>/dev/null
  ln -s -- "$verified" "$tmplink" 2>/dev/null || die 4 "host write refused: cannot write $bindir"
  if ! mv -f -- "$tmplink" "$link" 2>/dev/null; then
    rm -f "$tmplink" 2>/dev/null
    die 4 "host write refused: cannot replace $link"
  fi
  got="$(version_of "$link")"
  if [ "$got" != "$pin" ]; then
    if [ -n "$oldtarget" ] && ln -s -- "$oldtarget" "$tmplink" 2>/dev/null; then mv -f -- "$tmplink" "$link" 2>/dev/null; fi
    die 5 "$link does not print the pin $pin after linking; the previous link was restored where there was one"
  fi
  how="linked from $verified"
elif [ "$state" = kept-newer ]; then
  how="kept-newer $keptv, pin $pin"
else
  how="current"
fi

# --- step 3: PATH --------------------------------------------------------------
rc_apply
if [ "$state" = kept-newer ]; then
  echo "nen-global: nen $keptv at $link ($how) · rc: $rc_summary"
else
  echo "nen-global: nen $pin at $link ($how) · rc: $rc_summary"
fi
exit 0
