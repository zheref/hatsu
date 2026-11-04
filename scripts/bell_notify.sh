#!/usr/bin/env bash
# bell_notify.sh — jutaisho § 5's in-session bell where no stop hook is placed (zheref/hatsu#289 item 9).
#
# The maintainer's ruling of 2026-10-17 (docs/ROSTER.md § Rulings of 2026-10-17): the `osascript *` allow row
# pre-approved more than a notification (plain `do shell script`, an administrator-privileges prompt), so the
# row is gone and the bell rings through this script with a FIXED argv. Values are passed as ARGUMENTS after
# `--`, never spliced into script text and never read as options; they are sanitised as hooks/stop-bell.sh
# sanitises: `"`, `\` and newlines stripped, 240 characters at most, the title always prefixed `Hatsu — `,
# the sound reduced to [A-Za-z0-9_-] with Glass as the fallback (and Glass where the named sound is absent).
# The sound is an absolute /System/Library/Sounds path, so `afplay` takes it bare: it has no `--` (#516).
#
#   scripts/bell_notify.sh --title <text> --message <text> [--subtitle <text>] [--sound <name>] [--no-sound]
#                          [--deadline <seconds>]
#
# Every rung runs as this script's own background child with a finite deadline, `--deadline` whole seconds
# (1 to 60, default 5): past it the child gets TERM, then KILL after one more second, by its PID only — never
# by name or pattern — and is reaped before the next rung. One call returns within 2 x (deadline + 1) seconds
# plus process start-up (#516). A timed-out notification still lets the sound rung run once after it.
#
# Exit 0 after every rung attempted (a rung that cannot fire is REPORTED, never retried); 2 wiring. Read the
# lines it prints, never its exit code, for what fired. Each rung prints one of: `sent` / `played <sound>`
# (the tool exited 0 with empty stderr — delivery itself is never confirmed: `osascript` exits 0 with nothing
# delivered where the session has no Notification Center seat, docs/surfaces/README.md § Shared rules);
# `not applicable, <what is missing>` (the capability is absent, nothing ran); `failed (exit <n>: <stderr>)`
# (it ran and reported an error); `timed out after <n>s, its own child stopped` (it never returned).
set -u
title=""; message=""; subtitle=""; sound="Glass"; nosound=0; deadline=5
need() { [ $# -ge 2 ] && [ -n "$2" ] || { echo "bell_notify: $1 needs a value" >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --title) need "$1" "${2-}"; title="$2"; shift 2 ;;
    --message) need "$1" "${2-}"; message="$2"; shift 2 ;;
    --subtitle) need "$1" "${2-}"; subtitle="$2"; shift 2 ;;
    --sound) need "$1" "${2-}"; sound="$2"; shift 2 ;;
    --no-sound) nosound=1; shift ;;
    --deadline) need "$1" "${2-}"; deadline="$2"; shift 2 ;;
    -h|--help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { print }' "$0"; exit 0 ;;
    *) echo "bell_notify: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$title" ] && [ -n "$message" ] || { echo "bell_notify: --title and --message are required" >&2; exit 2; }
case "$deadline" in *[!0-9]*) deadline=0 ;; *) deadline=$((10#$deadline)) ;; esac
[ "$deadline" -ge 1 ] && [ "$deadline" -le 60 ] || { echo "bell_notify: --deadline takes whole seconds, 1 to 60" >&2; exit 2; }
clean() { printf '%s' "$1" | tr -d '"\\' | tr '\n\r' '  ' | cut -c1-240; }
title="Hatsu — $(clean "$title")"; message="$(clean "$message")"; subtitle="$(clean "$subtitle")"
case "$sound" in *[!A-Za-z0-9_-]*|"") sound="Glass" ;; esac

# The owned child: started here, waited on here, stopped here by its PID. Bash reaps a finished background
# child itself, so `kill -0` fails once it is gone and a stop never reaches a recycled PID.
work="$(mktemp -d)" || { echo "bell_notify: mktemp failed" >&2; exit 2; }
child=""; rb_rc=0; rb_err=""; rb_timeout=0
alive() { [ -n "$child" ] && kill -0 "$child" 2>/dev/null; }
stop_child() {
  kill -TERM "$child" 2>/dev/null; g=0
  while alive && [ "$g" -lt 10 ]; do sleep 0.1; g=$((g + 1)); done
  alive && kill -KILL "$child" 2>/dev/null
  wait "$child" 2>/dev/null; child=""
}
trap 'alive && stop_child; rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
# run_bounded <argv...>: stdin /dev/null, stdout discarded, stderr to a file (never a pipe a stray grandchild
# could hold open); sets rb_timeout, rb_rc and rb_err (stderr, one line, 240 characters at most).
run_bounded() {
  # The child turns tracing off before it execs, so a caller's xtrace (bashcov's) never reads as the tool's stderr.
  ( set +x; exec "$@" </dev/null >/dev/null 2>"$work/err" ) &
  child=$!; rb_timeout=0; t=0
  while alive; do
    if [ "$t" -ge $((deadline * 10)) ]; then stop_child; rb_timeout=1; rb_rc=0; rb_err=""; return; fi
    sleep 0.1; t=$((t + 1))
  done
  wait "$child"; rb_rc=$?; child=""
  rb_err="$(tr '\n\r' '  ' < "$work/err" | sed 's/[[:space:]]*$//' | cut -c1-240)"
}
# report <rung label> <success word>: the line for the run that just finished.
report() {
  if [ "$rb_timeout" = 1 ]; then echo "$1: timed out after ${deadline}s, its own child stopped"
  elif [ "$rb_rc" = 0 ] && [ -z "$rb_err" ]; then echo "$1: $2"
  else echo "$1: failed (exit $rb_rc: ${rb_err:-no stderr})"; fi
}

case "$(uname -s)" in
  Darwin)
    if command -v osascript >/dev/null 2>&1; then
      # `on run argv` makes the values ARGUMENTS; `--` keeps a value that starts with `-` from being an option.
      run_bounded osascript -e "on run argv" -e "display notification (item 2 of argv) with title (item 1 of argv) subtitle (item 3 of argv)" -e "end run" -- "$title" "$message" "$subtitle"
      report "rung 2 (OS notification)" "sent"
    else echo "rung 2 (OS notification): not applicable, no osascript"; fi
    if [ "$nosound" = 0 ]; then
      f="/System/Library/Sounds/$sound.aiff"; [ -f "$f" ] || { sound="Glass"; f="/System/Library/Sounds/Glass.aiff"; }
      if [ ! -f "$f" ]; then echo "rung 3 (sound): not applicable, no $sound"
      elif ! command -v afplay >/dev/null 2>&1; then echo "rung 3 (sound): not applicable, no afplay"
      else run_bounded afplay "$f"; report "rung 3 (sound)" "played $sound"; fi
    fi ;;
  Linux)
    if command -v notify-send >/dev/null 2>&1; then
      run_bounded notify-send -- "$title" "$message"; report "rung 2 (OS notification)" "sent"
    else echo "rung 2 (OS notification): not applicable, no notify-send"; fi
    echo "rung 3 (sound): not applicable on Linux" ;;
  *) echo "rung 2 (OS notification): not applicable on $(uname -s)" ;;
esac
exit 0
