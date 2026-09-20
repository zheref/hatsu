#!/bin/sh
# session-start.sh — the SessionStart hook, on every surface, fail-open.
#
# WHAT THIS IS
# A Claude Code `SessionStart` hook (see hooks/hooks.json) — and, mirrored by
# `nen surface mirror generate --hooks`, a Codex `SessionStart`, a Cursor
# `sessionStart` and an Antigravity `PreInvocation` hook. It does two things and
# nothing else:
#
#   1. On Claude Code (the plugin is the source, so there is nothing to place)
#      it prints one line of additional context reminding the session that
#      Nen-owned work starts with hatsu:hatsu-warmup.
#   2. On any other surface, when the plugin root is known and the target
#      checkout already carries that surface's directory, it refreshes the
#      installed mirrors through scripts/surface_bootstrap.sh --install-all,
#      which itself copies only what drifted. A checkout with no surface
#      directory is left alone: adoption is hatsu:tenkai's, never a hook's.
#
# It is NOT a nen-owned step: the warm-up's `nen surface mirror check
# --installed` is the check of record; this hook only keeps a consumer's copy
# from going stale between warm-ups. POSIX sh, no jq, no python, fails open —
# a hook that cannot help must never block a session (zheref/hatsu#93).
set -u
umask 022

if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Hatsu: Nen-owned work starts with hatsu:hatsu-warmup (nen shu tools verdict, mirrors checked with nen surface mirror check --installed)."}}'
  exit 0
fi

root="${HATSU_PLUGIN_ROOT:-}"
[ -n "$root" ] || exit 0
[ -x "$root/scripts/surface_bootstrap.sh" ] || exit 0

surface=""
if [ -d ./.codex ]; then surface=codex
elif [ -d ./.cursor ]; then surface=cursor
elif [ -d ./.agents ]; then surface=antigravity
fi
[ -n "$surface" ] || exit 0

"$root/scripts/surface_bootstrap.sh" --surface "$surface" --target . --install-all >/dev/null 2>&1 || true
exit 0
