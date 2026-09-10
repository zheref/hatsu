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
# against. It is read from the repository the write would land in, not from the
# session's own tree.
#
# HOW THE COMMAND IS READ — a parse, never a substring match
#   1. Every quoted span (`'…'` or `"…"`) is replaced by the single token `@`,
#      so quoted text can contribute neither an operator nor a space nor the
#      word `git` to the parse. `echo 'git commit'` reads as `echo @`.
#   2. The masked line is split into segments on `;` `|` `&` `(` `)` and the
#      backtick, so `&&`, `||`, a pipeline, a subshell and `$( … )` all separate.
#   3. A segment is a git call only when its FIRST token is `git`. Git's own
#      global options are walked past — `-C <dir>`, `-c <k=v>`, `--no-pager`,
#      `--git-dir=…`, `--work-tree=…`, `--namespace` and any other leading `-…`
#      — and the first token that is not an option is the SUBCOMMAND.
#   4. Only the subcommands `commit` and `push` are writes. `commit-tree` is a
#      different token and is not one of them.
#   5. The repository judged is that segment's own `-C <dir>` when it has one
#      and the working directory otherwise — where the working directory is the
#      payload `cwd` moved by any `cd` earlier in the same line, because a write
#      after a `cd` lands in the repository it moved to, not in `cwd`.
#
# WHERE IT FAILS CLOSED
# Two forms are refused whatever branch the working copy is on, because in both
# the branch this hook can see is not the branch the write would land on:
#   - a line that both changes branch (`switch`, `checkout`, `branch -f|-m|-M`)
#     and writes (`commit`, `push`) — `git switch main && git commit -m x`;
#   - a `-C` path that was quoted in a form this guard cannot recover.
#
# WHAT IT DOES NOT DO
# It does not judge WHICH branch you are on beyond that one comparison, does not
# look at what is staged, and does not care about `--no-verify` (a hook the
# harness runs is not a git hook, so `--no-verify` does not reach it). Anything
# else it cannot read — a payload it cannot parse, a directory that is not a git
# repository, a detached HEAD — is exit 0: outside the two forms above this hook
# refuses on a fact, never on a doubt, because a PreToolUse hook that blocks on
# uncertainty blocks the session.
#
# TEST CASES — payload on stdin, {"cwd": "<dir>", "tool_input": {"command": "…"}}
# All twenty-four run live against four constructed checkouts (one on `main`,
# one on a feature branch, one on `main` under a path with spaces, one whose
# workflow.json declares `develop`) in the commit that introduced this parse.
#   Standing on the base branch (`main`):
#     git commit -m x                          -> 2   blocked
#     git push                                 -> 2   blocked
#     git -C . commit -m x                     -> 2   blocked
#     git --no-pager commit -m x               -> 2   global option walked past
#     git -C . -c user.name=x commit -m y      -> 2   two globals walked past
#     git -c commit.gpgsign=false push origin HEAD -> 2
#     echo $(git commit -m x)                  -> 2   the subshell is a segment
#     git commit-tree -m x                     -> 0   not the `commit` token
#     echo 'git commit'                        -> 0   quoted, not a git call
#     gh pr create --title 'git commit'        -> 0   quoted, and not git
#     git log --format='git push'              -> 0   quoted, not a git write
#     git status                               -> 0
#   Standing on a feature branch:
#     git commit -m x                          -> 0
#     git push                                 -> 0
#     git commit -m x && git push              -> 0   no branch change in it
#     git -C <a checkout on main> commit -m x  -> 2   the -C repo is judged
#     git -C '<a checkout on main with spaces in its path>' commit -m x -> 2
#     cd <a checkout on main> && git commit    -> 2   the cd is followed
#     cd '<the same, quoted, with spaces>' && git push                  -> 2
#     git switch main && git commit -m x       -> 2   compound, fails closed
#     git checkout main; git push              -> 2   compound, fails closed
#     git branch -f main HEAD && git push      -> 2   compound, fails closed
#   In a checkout whose workflow.json declares `branch.base: develop`, standing
#   on `develop`:
#     git commit -m x                          -> 2   the declared base is read
#     git switch -c feat/x                     -> 0   not a write
#
# NO jq. Hatsu's installed path is one binary plus git and gh (README,
# 'On the installed plugin path'), so the JSON here is read with sed.

# `-f` for the whole run: a token like `*` reaches the parser as itself and is
# never expanded against the working directory.
set -uf

nl='
'

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

cwd=$(json_str "$payload" cwd)
[ -n "$cwd" ] || cwd=$PWD
[ -d "$cwd" ] || exit 0

# --- step 1: mask quoted spans ----------------------------------------------
# Single-quoted first: a `'` inside a double-quoted span has no partner and so
# matches nothing, while a `"` inside a single-quoted span would.
masked=$(printf '%s\n' "$command_line" | sed -e "s/'[^']*'/@/g" -e 's/"[^"]*"/@/g')

# --- step 2: split into segments --------------------------------------------
segments=$(printf '%s\n' "$masked" | tr ';|()&`' '\n\n\n\n\n\n')

# --- step 3: the git argv walk ----------------------------------------------
# Sets `sub` (the subcommand, empty when the segment is not a git call) and
# `cdir` (the segment's own -C value, empty when it has none).
sub=""
cdir=""
parse_git_segment() {
  sub=""
  cdir=""
  # shellcheck disable=SC2086  # deliberate word split; globbing is off (set -f)
  set -- $1
  [ "${1:-}" = "git" ] || return 0
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        cdir=${2:-}
        shift 2 2>/dev/null || return 0
        ;;
      -c|--git-dir|--work-tree|--namespace)
        shift 2 2>/dev/null || return 0
        ;;
      --)
        shift
        ;;
      -*)
        shift
        ;;
      *)
        sub=$1
        return 0
        ;;
    esac
  done
}

recover_quoted() {
  # The value written after $2, for the case where masking replaced a quoted
  # path with `@`. $1 = the raw command line, $2 = the flag or word it follows.
  found=$(printf '%s\n' "$1" | sed -n "s/.*$2[[:space:]][[:space:]]*'\([^']*\)'.*/\1/p" | head -n 1)
  [ -n "$found" ] || found=$(printf '%s\n' "$1" | sed -n "s/.*$2[[:space:]][[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1)
  printf '%s' "$found"
}

resolve() {
  # $1 = a path as written, $2 = the directory it is relative to.
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$2" "$1" ;;
  esac
}

writes=0
changes_branch=0
write_dirs=""
act="git commit"
# A `cd` earlier in the same line moves the repository a later segment writes
# in. The guard follows it, because judging the payload `cwd` after a `cd` is
# judging the wrong repository — the same mistake as ignoring `-C`.
here=$cwd

while IFS= read -r seg; do
  [ -n "$seg" ] || continue
  # shellcheck disable=SC2086  # deliberate word split; globbing is off (set -f)
  set -- $seg
  if [ "${1:-}" = "cd" ] && [ -n "${2:-}" ]; then
    moved=$2
    [ "$moved" = "@" ] && moved=$(recover_quoted "$command_line" cd)
    case "$moved" in
      -|@|-*) : ;;                       # `cd -`, or a path this guard cannot read
      *) here=$(resolve "$moved" "$here") ;;
    esac
    continue
  fi
  parse_git_segment "$seg"
  case "$sub" in
    commit|push)
      writes=$((writes + 1))
      act="git $sub"
      if [ "$cdir" = "@" ]; then
        cdir=$(recover_quoted "$command_line" -C)
        if [ -z "$cdir" ]; then
          printf 'hatsu: refusing %s — its `-C` path is quoted in a form this guard cannot read, so the branch the write would land on cannot be established; run the command from inside that repository instead.\n' \
            "git $sub" >&2
          exit 2
        fi
      fi
      target=$(resolve "${cdir:-.}" "$here")
      if [ -z "$write_dirs" ]; then
        write_dirs=$target
      else
        write_dirs="$write_dirs$nl$target"
      fi
      ;;
    switch|checkout)
      changes_branch=1
      ;;
    branch)
      case " $seg " in
        *" -f "* | *" -m "* | *" -M "* | *" --force "* | *" --move "*) changes_branch=1 ;;
      esac
      ;;
    *) ;;
  esac
done <<EOF
$segments
EOF

[ "$writes" -gt 0 ] || exit 0

# --- fail closed: branch change and write on the same line -------------------
if [ "$changes_branch" -eq 1 ]; then
  printf 'hatsu: refusing a compound command that changes branch and writes; run them separately. The branch this guard can see is the one you are on now, not the one %s would land on, so the base-branch check would be answered by the wrong repository state.\n' \
    "$act" >&2
  exit 2
fi

# --- the branch comparison, once per write ----------------------------------
while IFS= read -r target; do
  [ -n "$target" ] || continue
  [ -d "$target" ] || continue

  branch=$(git -C "$target" branch --show-current 2>/dev/null || :)
  # Empty means a detached HEAD or not a repository at all — neither is this
  # guard's business.
  [ -n "$branch" ] || continue

  root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || :)
  base="main"
  if [ -n "$root" ] && [ -f "$root/nen/workflow.json" ]; then
    declared=$(sed -n 's/.*"base"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$root/nen/workflow.json" | head -n 1)
    [ -n "$declared" ] && base=$declared
  fi

  [ "$branch" = "$base" ] || continue

  printf 'hatsu: refusing %s on %s — %s is the workflow base (nen/workflow.json branch.base) and is only ever reached through a merged PR; cut {model}/{persona}/{descriptor} with the breath skill (nen shu warmup --repo <path> --branch <name>) and commit there.\n' \
    "$act" "$base" "$base" >&2
  exit 2
done <<EOF
$write_dirs
EOF

exit 0
