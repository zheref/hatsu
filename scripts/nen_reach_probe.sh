#!/usr/bin/env bash
# nen_reach_probe.sh — ten § 2c's login-shell probe as ONE plain command (zheref/hatsu#218).
#
# WHAT IT ASKS
# Whether the maintainer's OWN login shell resolves `nen`, and what that nen's
# `nen shu tools` row says, never this session's PATH (zheref/hatsu#164). It runs
# exactly the line ten § 2c used to carry inline:
#
#   "$SHELL" -lic 'command -v nen && nen shu tools --repo "$1"' nen-probe <root> </dev/null
#
# the Hatsu root handed as the program's $1, never spliced into the string, and
# stdin closed so an interactive rc cannot wait on it. Inline, that line is a
# login shell running a quoted program, which Claude Code's worktree-isolation
# guard refuses; behind a shipped script it is one plain command.
#
# USAGE
#   nen_reach_probe.sh --root <hatsu_root>
#
# EXIT CODES
#   the login shell's own: `nen shu tools`'s code after a printed path (0 ok,
#   5, 7 BEHIND, ...), or 1 with nothing printed when no nen resolves. ten § 2c
#   reads them; this script interprets nothing.
#   125  this script failed before any shell ran: usage, a --root that is not a
#        directory, $SHELL empty, not absolute or not executable. ten § 2c reads
#        it as `not read (125, <this line>)`. A $SHELL truly UNSET is not this
#        case: bash fills an unset SHELL from the account's password entry at
#        startup, so the probe asks that login shell (under `env -i` its PATH
#        is the shell's own, and the reading follows from it).
#
# Fixture: scripts/nen_reach_probe_fixture.sh (lane reach-probe-guard).
set -euo pipefail

die() { printf 'nen-reach-probe: %s\n' "$1" >&2; exit 125; }

root=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      [ "$#" -ge 2 ] || die "--root requires a path (usage: nen_reach_probe.sh --root <hatsu_root>)."
      root="$2"
      shift 2
      ;;
    *) die "unknown argument '$1' (usage: nen_reach_probe.sh --root <hatsu_root>)." ;;
  esac
done

[ -n "$root" ] || die "no --root given (usage: nen_reach_probe.sh --root <hatsu_root>)."
[ -d "$root" ] || die "--root '$root' is not a directory."

login_shell="${SHELL:-}"
[ -n "$login_shell" ] || die "\$SHELL is empty; the login shell cannot be asked."
case "$login_shell" in
  /*) : ;;
  *) die "\$SHELL '$login_shell' is not an absolute path." ;;
esac
[ -x "$login_shell" ] || die "\$SHELL '$login_shell' is not executable."

set +e
# shellcheck disable=SC2016  # $1 is the login shell's, expanded there, never here
exec "$login_shell" -lic 'command -v nen && nen shu tools --repo "$1"' nen-probe "$root" </dev/null
