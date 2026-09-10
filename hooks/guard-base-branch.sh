#!/bin/sh
# guard-base-branch.sh — refuse a commit or a push while standing on the trunk.
#
# WHAT THIS IS
# A Claude Code `PreToolUse` hook matched on `Bash` (see hooks/hooks.json). It
# reads the command the model is about to run and, if that command commits or
# pushes while the working copy sits on the workflow BASE branch, exits 2 with a
# one-line reason. Exit 2 on PreToolUse blocks the tool call and hands the
# reason back to the model.
#
# It is NOT a nen-owned step. `breath` cuts the branch through
# `nen shu warmup --repo --branch`, and `kokusen` commits through
# `nen commit format`; both already refuse to work on the trunk. This hook is the
# reflex underneath them — the case where a skill was never invoked and a bare
# `git commit` was typed straight into Bash. A rule that only holds when the
# right skill was called is not a rule.
#
# THE BASE
# `branch.base` in the repository's nen/workflow.json, defaulting to `main`.
# The same value breath fast-forwards, ao pulls from, and shibari opens the PR
# against.
#
# WHAT IT DOES NOT DO
# It does not judge WHICH branch you are on beyond that one comparison, does not
# look at what is staged, and does not care about `--no-verify` (a hook the
# harness runs is not a git hook, so `--no-verify` does not reach it). Anything
# it cannot read — a payload it cannot parse, a directory that is not a git
# repository, a detached HEAD — is exit 0: this hook refuses on a fact, never on
# a doubt, because a PreToolUse hook that blocks on uncertainty blocks the
# session.
#
# NO jq. Hatsu's installed path is one binary plus git and gh (README,
# 'On the installed plugin path'), so the JSON here is read with sed.

set -u

payload=$(cat 2>/dev/null || :)

json_str() {
  # $1 = text, $2 = key. First string value for that key.
  # `[^"]*` stops at an escaped quote inside the value, so a command carrying one
  # is read up to it — which is after the git verb in every form this guard is
  # about (`git commit -m "…"` reads as `git commit -m \`, and still matches).
  printf '%s\n' "$1" \
    | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1
}

command_line=$(json_str "$payload" command)
[ -n "$command_line" ] || exit 0

# `git -C <path> commit` is the same act as `git commit`; normalise the flag away
# so the match below does not have to know about it.
command_line=$(printf '%s' "$command_line" | sed 's/git -C [^ ]* /git /g')

case "$command_line" in
  *"git commit"*) act="git commit" ;;
  *"git push"*)   act="git push" ;;
  *)              exit 0 ;;
esac

cwd=$(json_str "$payload" cwd)
[ -n "$cwd" ] || cwd=$PWD
[ -d "$cwd" ] || exit 0

branch=$(git -C "$cwd" branch --show-current 2>/dev/null || :)
# Empty means a detached HEAD or not a repository at all — neither is this
# guard's business.
[ -n "$branch" ] || exit 0

root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || :)
base="main"
if [ -n "$root" ] && [ -f "$root/nen/workflow.json" ]; then
  declared=$(sed -n 's/.*"base"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$root/nen/workflow.json" | head -n 1)
  [ -n "$declared" ] && base=$declared
fi

[ "$branch" = "$base" ] || exit 0

printf 'hatsu: refusing %s on %s — %s is the workflow base (nen/workflow.json branch.base) and is only ever reached through a merged PR; cut {model}/{persona}/{descriptor} with the breath skill (nen shu warmup --repo <path> --branch <name>) and commit there.\n' \
  "$act" "$base" "$base" >&2
exit 2
