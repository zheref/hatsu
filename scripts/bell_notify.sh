#!/usr/bin/env bash
# bell_notify.sh — jutaisho § 5's in-session bell where no stop hook is placed (zheref/hatsu#289 item 9).
#
# The maintainer's ruling of 2026-10-17 (docs/ROSTER.md § Rulings of 2026-10-17): the `osascript *` allow row
# pre-approved more than a notification (plain `do shell script`, an administrator-privileges prompt), so the
# row is gone and the bell rings through this script with a FIXED argv. Values are passed as ARGUMENTS after
# `--`, never spliced into script text and never read as options; they are sanitised as hooks/stop-bell.sh
# sanitises: `"`, `\` and newlines stripped, 240 characters at most, the title always prefixed `Hatsu — `,
# the sound reduced to [A-Za-z0-9_-] with Glass as the fallback (and Glass where the named sound is absent).
#
#   scripts/bell_notify.sh --title <text> --message <text> [--subtitle <text>] [--sound <name>] [--no-sound]
#
# Exit 0 after every rung attempted (a rung that cannot fire is REPORTED, never retried); 2 wiring. Read the
# lines it prints, never its exit code, for what fired: `osascript` exits 0 with nothing delivered where the
# session has no Notification Center seat (docs/surfaces/README.md § Shared rules).
set -u
title=""; message=""; subtitle=""; sound="Glass"; nosound=0
need() { [ $# -ge 2 ] && [ -n "$2" ] || { echo "bell_notify: $1 needs a value" >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --title) need "$1" "${2-}"; title="$2"; shift 2 ;;
    --message) need "$1" "${2-}"; message="$2"; shift 2 ;;
    --subtitle) need "$1" "${2-}"; subtitle="$2"; shift 2 ;;
    --sound) need "$1" "${2-}"; sound="$2"; shift 2 ;;
    --no-sound) nosound=1; shift ;;
    -h|--help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { print }' "$0"; exit 0 ;;
    *) echo "bell_notify: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$title" ] && [ -n "$message" ] || { echo "bell_notify: --title and --message are required" >&2; exit 2; }
clean() { printf '%s' "$1" | tr -d '"\\' | tr '\n\r' '  ' | cut -c1-240; }
title="Hatsu — $(clean "$title")"; message="$(clean "$message")"; subtitle="$(clean "$subtitle")"
case "$sound" in *[!A-Za-z0-9_-]*|"") sound="Glass" ;; esac
case "$(uname -s)" in
  Darwin)
    if command -v osascript >/dev/null 2>&1; then
      # `on run argv` makes the values ARGUMENTS; `--` keeps a value that starts with `-` from being an option.
      err="$(osascript -e "on run argv" -e "display notification (item 2 of argv) with title (item 1 of argv) subtitle (item 3 of argv)" -e "end run" -- "$title" "$message" "$subtitle" 2>&1 >/dev/null)" || :
      [ -z "$err" ] && echo "rung 2 (OS notification): sent" || echo "rung 2 (OS notification): not applicable, no seat ($err)"
    else echo "rung 2 (OS notification): not applicable, no osascript"; fi
    if [ "$nosound" = 0 ]; then
      f="/System/Library/Sounds/$sound.aiff"; [ -f "$f" ] || { sound="Glass"; f="/System/Library/Sounds/Glass.aiff"; }
      if [ -f "$f" ] && command -v afplay >/dev/null 2>&1; then
        err="$(afplay -- "$f" 2>&1 >/dev/null)" || err="${err:-afplay exited non-zero}"
        [ -z "$err" ] && echo "rung 3 (sound): played $sound" || echo "rung 3 (sound): not applicable, no seat ($err)"
      else echo "rung 3 (sound): not applicable, no $sound"; fi
    fi ;;
  Linux)
    if command -v notify-send >/dev/null 2>&1; then notify-send -- "$title" "$message" >/dev/null 2>&1 && echo "rung 2 (OS notification): sent" || echo "rung 2 (OS notification): not applicable"; else echo "rung 2 (OS notification): not applicable, no notify-send"; fi
    echo "rung 3 (sound): not applicable on Linux" ;;
  *) echo "rung 2 (OS notification): not applicable on $(uname -s)" ;;
esac
exit 0
