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
# bootstrap. Three steps:
#
#   1. Probe `<bin-dir>/nen --version`. When it already prints the pin (the
#      contract's dependency.pinned_ref without its `v`), the state is
#      `current` and NOTHING touches the network.
#   2. Otherwise fetch nen's bootstrap TWO-STEP (curl to a file, then run the
#      file — contract: bootstrap.fetch_must_be_two_step, never a pipe) at
#      dependency.bootstrap.url, run it with `--ref <pinned_ref>`, take the LAST
#      line of its stdout as the verified binary path, and symlink
#      `<bin-dir>/nen` to it (`ln -sfn`; the binary is never copied or renamed).
#      The link is read back and must print the pin.
#   3. Make <bin-dir> reachable: append one marked block to the shell's own
#      profile files (zsh: ~/.zshrc, ~/.zprofile; bash: ~/.bashrc,
#      ~/.bash_profile; anything else: ~/.profile) unless a line there already
#      puts the directory on PATH. Existing content is never rewritten.
#
# Usage:
#   nen_global.sh --root <hatsu_root> [--bin-dir <dir>] [--rc auto|none|<file>]
#                 [--bootstrap-script <file>] [--dry-run] [--quiet]
#
#   --root              the Hatsu checkout or installed plugin root carrying
#                       nen/contract.json (required)
#   --bin-dir           where the `nen` link lives; default $HOME/.local/bin
#   --rc                auto (default, by $SHELL), none, or exactly one file
#   --bootstrap-script  use this local file instead of fetching the contract's
#                       url (the fixture seam; the two-step run is unchanged)
#   --dry-run           say what would happen; change nothing, touch no network
#   --quiet             print only the summary line and errors
#   HATSU_NEN_GLOBAL=0  opt out: print one `skipped` line and exit 0
#
# EXIT CODES
#   0  ok — current, linked, or skipped by the opt-out
#   2  usage error, or nen/contract.json unreadable (pinned_ref / bootstrap.url)
#   3  refused: <bin-dir>/nen exists and is a real file, not a symlink; it is
#      someone's own and is never replaced
#   5  bootstrap or verification failed (fetch, the bootstrap's own exit code,
#      no executable path, or the linked binary does not print the pin)
#
# FAIL SEMANTICS. Nothing here is a gate: on any failure the existing link is
# left exactly as it was, one line names the rc and its meaning, and the caller
# (a fail-open hook) carries on. The contract's retry policy is honoured: the
# bootstrap's exit 4 is retried once; 5, 6, 3 and curl 22/56 never are, because
# retrying a checksum failure is how a fail-closed guard becomes fail-open.
# POSIX sh; no jq, yq or python.
set -u
umask 022

root=""
bindir=""
rcmode="auto"
bscript=""
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
    --dry-run) dry=1; shift ;;
    --quiet) quiet=1; shift ;;
    *) die 2 "unknown argument '$1'" ;;
  esac
done

if [ "${HATSU_NEN_GLOBAL:-}" = "0" ]; then
  echo "nen-global: skipped (HATSU_NEN_GLOBAL=0)"
  exit 0
fi

[ -n "$root" ] || die 2 "usage: nen_global.sh --root <hatsu_root> [--bin-dir <dir>] [--rc auto|none|<file>] [--bootstrap-script <file>] [--dry-run] [--quiet]"
[ -n "${HOME:-}" ] || die 2 "HOME is not set"
contract="$root/nen/contract.json"
[ -f "$contract" ] || die 2 "contract unreadable: $contract"
pinned_ref="$(sed -n 's/^[[:space:]]*"pinned_ref"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$contract" | head -n 1)"
url="$(sed -n 's/^[[:space:]]*"url"[[:space:]]*:[[:space:]]*"\(https:[^"]*\/bootstrap\/[^"]*\)".*/\1/p' "$contract" | head -n 1)"
[ -n "$pinned_ref" ] || die 2 "contract unreadable: no dependency.pinned_ref in $contract"
[ -n "$url" ] || die 2 "contract unreadable: no dependency.bootstrap.url in $contract"
pin="${pinned_ref#v}"
[ -z "$bscript" ] || [ -f "$bscript" ] || die 2 "--bootstrap-script '$bscript' is not a file"

[ -n "$bindir" ] || bindir="$HOME/.local/bin"
bindir="${bindir%/}"
link="$bindir/nen"

d=""
cleanup() { [ -z "$d" ] || rm -rf "$d"; }
trap cleanup EXIT
trap 'exit 5' HUP INT TERM

# version_of FILE — the version a binary reports: the last word of the first
# line of `--version` output, without a leading `v` (accepts `0.18.1`, `nen 0.18.1`).
version_of() {
  [ -x "$1" ] || return 0
  "$1" --version 2>/dev/null | head -n 1 | awk '{print $NF}' | sed 's/^v//'
}

# --- rc targets ----------------------------------------------------------------
case "$rcmode" in
  none) rcfiles="" ;;
  auto)
    case "$(basename "${SHELL:-}")" in
      zsh) rcfiles="$HOME/.zshrc $HOME/.zprofile" ;;
      bash) rcfiles="$HOME/.bashrc $HOME/.bash_profile" ;;
      *) rcfiles="$HOME/.profile" ;;
    esac
    ;;
  *) rcfiles="$rcmode" ;;
esac

# The bin dir as a profile line spells it: via $HOME when it sits under $HOME.
case "$bindir" in
  "$HOME"/*)
    bin_expr="\$HOME/${bindir#"$HOME"/}"
    bin_tilde="~/${bindir#"$HOME"/}"
    bin_brace="\${HOME}/${bindir#"$HOME"/}"
    ;;
  *) bin_expr="$bindir"; bin_tilde="$bindir"; bin_brace="$bindir" ;;
esac

# rc_has FILE — a line that puts the bin dir on PATH already exists.
rc_has() {
  [ -f "$1" ] || return 1
  for needle in "$bindir" "$bin_expr" "$bin_tilde" "$bin_brace"; do
    if grep -F -- "$needle" "$1" 2>/dev/null | grep -q 'PATH'; then return 0; fi
  done
  return 1
}

# rc_apply — add the marked block where missing; sets rc_summary.
rc_apply() {
  rc_summary=""
  [ -n "$rcfiles" ] || { rc_summary="skipped"; return 0; }
  for f in $rcfiles; do
    state=""
    if rc_has "$f"; then
      state="present"
    elif [ "$dry" -eq 1 ]; then
      state="would-add"
    else
      {
        [ ! -s "$f" ] || [ -z "$(tail -c 1 "$f" 2>/dev/null)" ] || printf '\n'
        printf '%s\n' "# >>> hatsu nen-global >>>"
        printf '%s\n' "case \":\$PATH:\" in *\":$bin_expr:\"*) ;; *) export PATH=\"$bin_expr:\$PATH\" ;; esac"
        printf '%s\n' "# <<< hatsu nen-global <<<"
      } >>"$f" 2>/dev/null && state="added" || { echo "nen-global: could not write $f" >&2; state="failed"; }
    fi
    rc_summary="${rc_summary:+$rc_summary, }$state $f"
  done
}

# --- step 1: probe -------------------------------------------------------------
have="$(version_of "$link")"
if [ "$have" = "$pin" ]; then
  how="current"
else
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    die 3 "$link is a real file, not a symlink — refusing to replace it"
  fi
  if [ "$dry" -eq 1 ]; then
    rc_apply
    echo "nen-global: dry-run: nen ${have:-absent} at $link would be bootstrapped at $pinned_ref and linked · rc: $rc_summary"
    exit 0
  fi
  # --- step 2: two-step bootstrap, never piped -------------------------------
  d="$(mktemp -d "${TMPDIR:-/tmp}/nen-global.XXXXXX")" || die 5 "mktemp failed"
  chmod 700 "$d"
  script="$d/nen-bootstrap.sh"
  if [ -n "$bscript" ]; then
    script="$bscript"
  else
    say "fetching $url"
    curl -fsSL --max-time 30 "$url" -o "$script" 2>"$d/curl.err"
    crc=$?
    if [ "$crc" -ne 0 ]; then
      case "$crc" in
        22|56) meaning="the script is absent at the pinned ref (tag or release not published); never retried" ;;
        *) meaning="the bootstrap script could not be fetched" ;;
      esac
      die 5 "bootstrap fetch failed (curl rc $crc: $meaning); existing link left as it was"
    fi
  fi
  attempt=1
  while :; do
    out="$(bash "$script" --ref "$pinned_ref" 2>"$d/bootstrap.err")"
    brc=$?
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
    die 5 "bootstrap exited $brc ($meaning); existing link left as it was"
  fi
  verified="$(printf '%s\n' "$out" | tail -n 1)"
  if [ -z "$verified" ] || [ ! -x "$verified" ]; then
    die 5 "bootstrap printed no executable path (got '$verified'); existing link left as it was"
  fi
  mkdir -p "$bindir" || die 5 "cannot create $bindir"
  ln -sfn "$verified" "$link" || die 5 "cannot link $link"
  got="$(version_of "$link")"
  [ "$got" = "$pin" ] || die 5 "$link reports '${got:-nothing}', expected $pin after linking $verified"
  how="linked from $verified"
fi

# --- step 3: PATH --------------------------------------------------------------
rc_apply
echo "nen-global: nen $pin at $link ($how) · rc: $rc_summary"
exit 0
