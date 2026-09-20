#!/bin/sh
# stop-bell.sh — jutaisho's rungs 2 and 3, rung by the harness rather than by a skill.
#
# WHAT THIS IS
# A Claude Code `Stop` hook (see hooks/hooks.json) — and, mirrored, a Codex
# `Stop`, a Cursor `stop` and an Antigravity `Stop` hook. It fires when the
# model finishes a turn, reads the marker at `.nen/last-stop.json`, and — only
# if that marker is there and fresh — raises an OS notification carrying the
# ask and the report link, plays a sound, then removes the marker.
#
# It is NOT a nen-owned step and never will be. The whole point of a bell is
# that it rings when the model has stopped talking, which is exactly when no
# skill is running to ring it. `nen stop --mark` writes the marker; `nen stop
# clear` consumes it where no hook is installed.
#
# THE MARKER — nen.stop.mark/v0.1 or v0.2, written by `nen stop --mark`
#   { "contract": "nen.stop.mark/v0.2", "who": "kurapika", "gate": "G5",
#     "notified": true, "at": "<ISO-8601>",
#     "title": "<one line>", "body": "<the ask>", "reportUrl": "<url>",
#     "options": [ ... ], "proposedIssue": { ... } }
# v0.1 carries the first five keys only. This hook reads `gate`, `title`,
# `body` and `reportUrl`; a v0.1 marker rings with a generic title. The older
# `hatsu.stop-marker/v0.1` shape (v0.38.0 and before) carried the same three
# strings under the same names and still rings. Freshness is the FILE's mtime,
# not `at`: comparing a timestamp in a string needs a date parser, and the
# mtime is the same fact without one.
#
# RUNGS
# `notifications.rungs` in the repository's nen/workflow.json decides which of
# the two this rings. A rung absent from the list is not rung. NO DECLARATION —
# no workflow.json, or no `rungs` key in it — means both. An EMPTY DECLARED
# list rings nothing. `HATSU_ATTENTION=off` in the environment rings nothing
# on any host and still consumes the marker (bankai-core's own switch, kept
# under Hatsu's name).
#
# PLATFORMS — macOS is verified live; Linux and Windows are PORTED from
# bankai-core's scripts/attention_signal.sh (2026-09-19) and are UNTESTED on a
# host until one runs them. Each rung fails open on its own:
#   macOS    rung 2 osascript (values passed as argv, never spliced into the
#            script text), rung 3 afplay <sound>.aiff
#   Linux    rung 2 notify-send, rung 3 paplay the freedesktop 'complete' sound
#   Windows  rung 2 powershell BurntToast then a NotifyIcon balloon (values
#            reach the script as environment variables), rung 3 [console]::beep
# A host with none of a rung's tools skips that rung and still consumes the
# marker. A terminal BEL is the floor when no sound tool exists.
#
# WHY IT NO-OPS SO EAGERLY
# A Stop hook runs after EVERY turn. Absence of the marker and staleness of the
# marker are each a silent exit 0. This hook never blocks a stop and never
# writes to stdout.
#
# NO jq. Hatsu's installed path is one binary plus git and gh (README, 'On the
# installed plugin path'), so the JSON here is read with sed. Values are
# sanitised to the characters a notification can carry.

payload=$(cat 2>/dev/null || :)

# json_str PAYLOAD KEY — the first string value of KEY, or nothing. Used on
# the harness payload, whose keys are top-level.
json_str() {
  printf '%s\n' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}
# marker_str DOCUMENT KEY — a TOP-LEVEL string of the marker: nen writes the
# marker pretty-printed with two-space indentation, so a top-level key is the
# one on a line that starts with exactly two spaces. Anchoring there is what
# keeps `proposedIssue.title` (deeper) from being read as the stop's title
# (review finding on zheref/hatsu#85).
marker_str() {
  printf '%s\n' "$1" | sed -n "s/^  \"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}
# Decode the JSON escapes a notification can show as a space, then strip the
# characters a title cannot carry, then bound the length.
sanitize() { printf '%s' "$1" | sed 's/\\[nt]/ /g' | tr -d '"\\' | tr -d '\n' | cut -c1-240; }

cwd=$(json_str "$payload" cwd)
[ -n "$cwd" ] || cwd=$(json_str "$payload" Cwd)
if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
  ws=$(printf '%s\n' "$payload" | sed -n 's/.*"workspacePaths"[[:space:]]*:[[:space:]]*\[[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  [ -n "$ws" ] && cwd=$ws
fi
[ -n "$cwd" ] || cwd=$PWD
[ -d "$cwd" ] || exit 0

marker="$cwd/.nen/last-stop.json"
[ -f "$marker" ] || exit 0

# --- fresh? ------------------------------------------------------------------
if [ -z "$(find "$marker" -mmin -10 2>/dev/null)" ]; then
  rm -f "$marker"
  exit 0
fi

document=$(cat "$marker" 2>/dev/null || :)
gate=$(sanitize "$(marker_str "$document" gate)")
title=$(sanitize "$(marker_str "$document" title)")
body=$(sanitize "$(marker_str "$document" body)")
report=$(sanitize "$(marker_str "$document" reportUrl)")
[ -n "$gate" ] || gate="stop"
[ -n "$title" ] || title="A decision is waiting."
message="$body"
[ -n "$report" ] && message="${message:+$message — }report: $report"
[ -n "$message" ] || message="Open the session."

# --- the off switch -----------------------------------------------------------
if [ "${HATSU_ATTENTION:-on}" = "off" ]; then
  rm -f "$marker"
  exit 0
fi

# --- policy: which rungs, which sound ---------------------------------------
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")
workflow="$root/nen/workflow.json"

rungs=""
rungs_declared=0
sound="Glass"
if [ -f "$workflow" ]; then
  if grep -q '"rungs"[[:space:]]*:[[:space:]]*\[' "$workflow" 2>/dev/null; then
    rungs_declared=1
    rungs=$(sed -n 's/.*"rungs"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' "$workflow" | head -n 1)
  fi
  from_file=$(sed -n 's/.*"sound"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$workflow" | head -n 1)
  [ -n "$from_file" ] && sound=$from_file
fi
sound=$(printf '%s' "$sound" | tr -cd 'A-Za-z0-9_-')
[ -n "$sound" ] || sound="Glass"

rings() {
  [ "$rungs_declared" -eq 1 ] || return 0
  case "$rungs" in
    *"\"$1\""*) return 0 ;;
    *) return 1 ;;
  esac
}

subtitle=$(sanitize "$(basename "$root")")
os=$(uname -s 2>/dev/null || echo unknown)
case "$os" in
  MINGW*|MSYS*|CYGWIN*) os=Windows ;;
esac

# --- rung 2: the OS notification --------------------------------------------
if rings os; then
  case "$os" in
    Darwin)
      if command -v osascript >/dev/null 2>&1; then
        # `on run argv` makes the values ARGUMENTS, never script text.
        osascript \
          -e "on run argv" \
          -e "display notification (item 2 of argv) with title (item 1 of argv) subtitle (item 3 of argv)" \
          -e "end run" "Hatsu — $gate: $title" "$message" "$subtitle" >/dev/null 2>&1 || :
      fi
      ;;
    Linux)
      if command -v notify-send >/dev/null 2>&1; then
        notify-send -- "Hatsu — $gate: $title" "$message" >/dev/null 2>&1 || :
      fi
      ;;
    Windows)
      if command -v powershell.exe >/dev/null 2>&1; then
        HATSU_ATTENTION_TITLE="Hatsu — $gate: $title" HATSU_ATTENTION_MESSAGE="$message" \
        powershell.exe -NoProfile -NonInteractive -Command \
          'if (Get-Module -ListAvailable -Name BurntToast) { Import-Module BurntToast -ErrorAction Stop; New-BurntToastNotification -Text $env:HATSU_ATTENTION_TITLE, $env:HATSU_ATTENTION_MESSAGE; exit 0 } else { Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $n = New-Object System.Windows.Forms.NotifyIcon; $n.Icon = [System.Drawing.SystemIcons]::Information; $n.Visible = $true; $n.ShowBalloonTip(10000, $env:HATSU_ATTENTION_TITLE, $env:HATSU_ATTENTION_MESSAGE, [System.Windows.Forms.ToolTipIcon]::Info); Start-Sleep -Milliseconds 1500; $n.Dispose() }' \
          >/dev/null 2>&1 || :
      fi
      ;;
  esac
fi

# --- rung 3: the sound -------------------------------------------------------
if rings sound; then
  rang=0
  case "$os" in
    Darwin)
      sound_file="/System/Library/Sounds/$sound.aiff"
      [ -f "$sound_file" ] || sound_file="/System/Library/Sounds/Glass.aiff"
      if command -v afplay >/dev/null 2>&1 && [ -f "$sound_file" ]; then
        afplay "$sound_file" >/dev/null 2>&1 && rang=1
      fi
      ;;
    Linux)
      if command -v paplay >/dev/null 2>&1 && [ -f /usr/share/sounds/freedesktop/stereo/complete.oga ]; then
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1 && rang=1
      fi
      ;;
    Windows)
      if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -NonInteractive -Command '[console]::beep(880,250); [console]::beep(660,250)' >/dev/null 2>&1 && rang=1
      fi
      ;;
  esac
  [ "$rang" -eq 1 ] || printf '\a' >&2
fi

# The marker is consumed whatever rang — including when nothing could.
rm -f "$marker"
exit 0
