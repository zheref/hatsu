#!/bin/sh
# stop-bell.sh — jutaisho's rungs 2 and 3, rung by the harness rather than by a skill.
#
# WHAT THIS IS
# A Claude Code `Stop` hook (see hooks/hooks.json). It fires when the model
# finishes a turn, reads the marker the `jutaisho` skill drops at
# `.nen/last-stop.json`, and — only if that marker is there and fresh — raises an
# OS notification and plays a sound, then removes the marker.
#
# It is NOT a nen-owned step and never will be. The whole point of a bell is that
# it rings when the model has stopped talking, which is exactly when no skill is
# running to ring it. `jutaisho` writes the marker and, where no hook is
# installed, rings the bell itself and says that it did.
#
# THE MARKER — hatsu.stop-marker/v0.1, written by jutaisho, read here
#   { "contract": "hatsu.stop-marker/v0.1",
#     "at": "<ISO-8601>", "gate": "G5", "title": "<one line>",
#     "repo": "<name>", "report": "<url or path>" }
# Only `gate` and `title` are read here. Freshness is taken from the FILE's
# mtime, not from `at`: comparing a timestamp in a string needs a date parser,
# and the mtime is the same fact without one.
#
# RUNGS
# `notifications.rungs` in the repository's nen/workflow.json decides which of
# the two this rings. A rung absent from the list is not rung. No workflow.json
# means both, which is the useful default for a repository that has not opted in
# to the ladder.
#
# WHY IT NO-OPS SO EAGERLY
# A Stop hook runs after EVERY turn. A bell that rings on a turn that was not a
# gate stop is a bell nobody hears any more, so absence of the marker and
# staleness of the marker are each a silent exit 0. This hook never blocks a
# stop and never writes to stdout: exit 2 on a Stop hook would prevent the model
# from stopping, which is the opposite of what a bell is for.
#
# EVERY RUNG FAILS OPEN ON ITS OWN, AND THE MARKER IS ALWAYS CONSUMED
# A missing tool disables ONE rung, never the hook: a host without `osascript`
# (or a host that is not macOS) skips rung 2 and still plays rung 3 if `afplay`
# is there, and a host with neither still consumes the marker. Nothing exits
# before marker cleanup — a fresh marker that rang nothing is still a marker
# that has been dealt with, and leaving it would ring the same stop on the next
# turn as soon as the machine could ring at all. A stale marker is removed on
# every path.
#
# NO jq. Hatsu's installed path is one binary plus git and gh (README,
# 'On the installed plugin path'), so the JSON here is read with sed.
#
# TEST CASES — payload on stdin, {"cwd": "<dir>"}; run live in the commit that
# made the rungs independent.
#   no marker at all                             -> 0, nothing rung
#   fresh marker, rungs ["push","sound"]         -> 0, rung 2 skipped (not
#                                                   listed), sound rung, marker
#                                                   consumed
#   marker older than ten minutes                -> 0, removed without ringing
#   fresh marker, PATH carrying neither osascript
#     nor afplay                                 -> 0, both rungs skipped,
#                                                   MARKER STILL CONSUMED
#   fresh marker, rungs ["os"] only              -> 0, notification only, marker
#                                                   consumed
#   fresh marker, no workflow.json               -> 0, both rungs (the default),
#                                                   marker consumed

set -u

# The harness delivers the Stop payload on stdin; drain it whether or not we use
# it, so the writer never sees a closed pipe.
payload=$(cat 2>/dev/null || :)

# --- first string value of a JSON key, scalar strings only -------------------
# Stops at the first `"`, so a value carrying an escaped quote is read up to it.
# That is fine for the two fields used here, both of which are one short line.
json_str() {
  # $1 = text, $2 = key
  printf '%s\n' "$1" \
    | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1
}

# osascript takes a double-quoted AppleScript literal, so strip the two
# characters that could close or escape it. Extraction already excludes `"`.
sanitize() { printf '%s' "$1" | tr -d '"\\' | tr -d '\n'; }

cwd=$(json_str "$payload" cwd)
[ -n "$cwd" ] || cwd=$PWD
[ -d "$cwd" ] || exit 0

marker="$cwd/.nen/last-stop.json"
[ -f "$marker" ] || exit 0

# --- fresh? ------------------------------------------------------------------
# A marker older than ten minutes belongs to a stop the maintainer has already
# seen; ringing for it would be noise. Remove it and say nothing.
if [ -z "$(find "$marker" -mmin -10 2>/dev/null)" ]; then
  rm -f "$marker"
  exit 0
fi

gate=$(sanitize "$(json_str "$(cat "$marker" 2>/dev/null || :)" gate)")
title=$(sanitize "$(json_str "$(cat "$marker" 2>/dev/null || :)" title)")
[ -n "$gate" ] || gate="stop"
[ -n "$title" ] || title="A decision is waiting."

# --- policy: which rungs, which sound ---------------------------------------
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")
workflow="$root/nen/workflow.json"

rungs=""
sound="Glass"
if [ -f "$workflow" ]; then
  rungs=$(sed -n 's/.*"rungs"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' "$workflow" | head -n 1)
  from_file=$(sed -n 's/.*"sound"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$workflow" | head -n 1)
  [ -n "$from_file" ] && sound=$from_file
fi

# A sound name reaches the filesystem, so it is reduced to the characters a
# system sound name can actually have before it is used as a path.
sound=$(printf '%s' "$sound" | tr -cd 'A-Za-z0-9_-')
[ -n "$sound" ] || sound="Glass"
sound_file="/System/Library/Sounds/$sound.aiff"
[ -f "$sound_file" ] || sound_file="/System/Library/Sounds/Glass.aiff"

rings() {
  # $1 = rung name. No rungs declared (no workflow.json) rings everything.
  [ -z "$rungs" ] && return 0
  case "$rungs" in
    *"\"$1\""*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- rung 2: the OS notification --------------------------------------------
# `osascript` is macOS-only, so both conditions are this rung's own and neither
# is the hook's: a host without it skips rung 2 and goes on to rung 3.
if rings os \
  && [ "$(uname -s 2>/dev/null || echo unknown)" = "Darwin" ] \
  && command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$title\" with title \"Hatsu — $gate\" subtitle \"$(sanitize "$(basename "$root")")\"" >/dev/null 2>&1 || :
fi

# --- rung 3: the sound -------------------------------------------------------
if rings sound && command -v afplay >/dev/null 2>&1 && [ -f "$sound_file" ]; then
  afplay "$sound_file" >/dev/null 2>&1 || :
fi

# The marker is consumed whatever rang — including when nothing could. Leaving
# it would ring this same stop on a later turn, on a machine that by then can.
rm -f "$marker"
exit 0
