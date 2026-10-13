#!/usr/bin/env bash
# gh_token_env.sh — run ONE command with GH_TOKEN in its environment, read from
# `gh auth token`, so no skill block needs `export GH_TOKEN=$(gh auth token)`
# (zheref/hatsu#218).
#
# WHY A SCRIPT
# nen reads its GitHub token from GH_TOKEN (`nen pr ready --token-env`'s
# default) and, unlike gh, never picks one up ambiently. The line skill blocks
# used to carry, `export GH_TOKEN=$(gh auth token)` before the nen call, is two
# of the shapes Claude Code's worktree-isolation guard refuses: an export "with
# a value every later program inherits", and a value computed at runtime.
# Written here once, the skill block is one plain command, the token reaches
# only the command named, and nothing here prints it.
#
# USAGE
#   gh_token_env.sh [--path <dir>] [--] <command> [<arg>...]
#
#   --path <dir>  prepend <dir> to PATH for the command: the session bind's
#                 bin directory (ten § 2), so no block needs a PATH prefix
#                 either. Absolute, an existing directory and free of `:` (one
#                 entry, never several smuggled in), else refused.
#   --            ends the options; everything after it is the command.
#
# The token is always the one `gh auth token` prints, the credential gh itself
# would use (it honours an ambient GH_TOKEN the same way), so the wrapped
# command and a raw gh call never act as two identities.
#
# EXIT CODES — env(1)'s convention, so the command's own codes pass through:
#   125  this wrapper failed: usage, a refused --path, no gh on PATH, or
#        `gh auth token` failed or printed nothing (`gh auth status` names the
#        fix); the command is NOT run
#   126  the command was found but could not be executed
#   127  the command was not found
#   any other code is the command's own (the wrapper execs it).
#
# Fixture: scripts/gh_token_env_fixture.sh (lane gh-token-guard).
set -euo pipefail

die() { printf 'gh-token-env: %s\n' "$1" >&2; exit 125; }

usage='usage: gh_token_env.sh [--path <dir>] [--] <command> [<arg>...]'
path_dir=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --path)
      [ "$#" -ge 2 ] || die "--path requires a directory ($usage)."
      path_dir="$2"
      shift 2
      ;;
    --) shift; break ;;
    -*) die "unknown option '$1' ($usage)." ;;
    *) break ;;
  esac
done

[ "$#" -ge 1 ] || die "no command given ($usage)."

if [ -n "$path_dir" ]; then
  case "$path_dir" in
    /*) : ;;
    *) die "--path '$path_dir' is not absolute." ;;
  esac
  case "$path_dir" in
    *:*) die "--path '$path_dir' contains ':'; it names one directory." ;;
  esac
  [ -d "$path_dir" ] || die "--path '$path_dir' is not a directory."
fi

command -v gh >/dev/null 2>&1 || die "no 'gh' on PATH; install the GitHub CLI, then 'gh auth login'."

# A caller tracing with `bash -x` or SHELLOPTS=xtrace would otherwise print the token in the
# assignment and export below; tracing stops here, silently, for the rest of this process.
{ set +x; } 2>/dev/null
token=""
token="$(gh auth token 2>/dev/null)" || die "'gh auth token' failed; 'gh auth status' names the fix."
[ -n "$token" ] || die "'gh auth token' printed nothing; 'gh auth status' names the fix."

if [ -n "$path_dir" ]; then
  PATH="$path_dir:$PATH"
  export PATH
fi
GH_TOKEN="$token"
export GH_TOKEN
unset token
# errexit off for the exec itself: under bash 3.2's `set -e` a failed exec exits 1 rather
# than env(1)'s 126 (checked by the fixture), and 126/127 are the codes callers read.
set +e
exec -- "$@"   # `--`: a command named `-c` or `-l` is the command, never exec's own flag
