#!/bin/sh
# cleanup_path_admit.sh — hatsu:cleanup § 4's admission of a worktree PATH (zheref/hatsu#333).
#
#   scripts/cleanup_path_admit.sh --core <abs> --base <branch.base> --path <abs> [--pr-state merged|closed|open|none]
#   scripts/cleanup_path_admit.sh --self-test
#
# A worktree path is a filesystem path, never a Git ref, and is never put through
# `git check-ref-format --branch`: a native absolute path starts with `/`, which that check refuses,
# so the old rule made every clean merged worktree under the home a named row. A branch or a remote
# head keeps § 4's ref rule. A path is ADMITTED only when every condition below holds; the first one
# that fails refuses it.
#   1. --core is canonical (`cd -P` resolves to itself), matches the charset of 2, and is the main
#      worktree of its repository (the parent of `git rev-parse --git-common-dir`). Else exit 2.
#   2. The path is absolute and matches ^/[A-Za-z0-9._/-]+$ under LC_ALL=C — no space, quote, glob,
#      backslash, non-ASCII or control byte — with no empty, `.` or `..` component and no trailing
#      slash. Traversal is refused as spelled, never normalised into something admissible.
#   3. It lies strictly under <core>/.nen/worktrees/, the permitted cleanup home. Core itself and every
#      path outside the home are refused.
#   4. No symlink: <core>/.nen and <core>/.nen/worktrees are not links, the path is a directory and not
#      a link, it resolves (`cd -P`) to itself, and it is its own `git rev-parse --show-toplevel`.
#   5. It is listed, exactly, as `worktree <path>` in `git -C <core> worktree list --porcelain`, the
#      authoritative inventory. A directory git does not list is somebody's, never cleanup's.
#   6. Its entry is not checked out on the trunk (--base).
# A refused path is exit 1 and one NAMED row, `named<TAB>refused: <reason><TAB><path>`, the path with
# every byte outside the charset shown as `?`; no command is printed, and none may be run on it.
#
# An admitted path prints `<class><TAB><evidence><TAB><command>` at exit 0, the command being the one
# literal, single-quoted, after `--`, and never `--force`:
#   git -C '<core>' worktree remove -- '<path>'
# Without --pr-state the class is `admitted` and § 5 classifies. With it, § 5's worktree rows decide:
# locked → named (no command); open → named (no command); dirty, or status unreadable → proposed, each
# dirty path on its own `dirt<TAB><path>` line; clean but detached → proposed; clean on a branch and
# merged → deterministic; clean and closed or no PR → proposed. A `hanten-<persona>` or `prove-<n>`
# checkout keeps § 5's ledger rule. The command is printed, never run: the maintainer's pick (§ 6)
# runs it, and a failure is reported, never retried with a wider flag.
set -u
LC_ALL=C
export LC_ALL

usage() {
  echo "usage: cleanup_path_admit.sh --core <abs> --base <branch> --path <abs> [--pr-state merged|closed|open|none]" >&2
  echo "       cleanup_path_admit.sh --self-test" >&2
}

shown() { printf '%s' "$1" | tr -c 'A-Za-z0-9._/-' '?'; }

refuse() {
  printf 'named\trefused: %s\t%s\n' "$1" "$(shown "$path")"
  exit 1
}

safe_abs() {
  case $1 in
    '' | [!/]* | *[!A-Za-z0-9._/-]* | *//* | */./* | */../* | */. | */.. | */) return 1 ;;
  esac
  return 0
}

admit_main() {
  core='' base='' path='' prs='' have_path=0
  while [ "$#" -gt 0 ]; do
    case $1 in
      --core | --base | --path | --pr-state)
        [ "$#" -ge 2 ] || { echo "cleanup_path_admit.sh: $1 needs a value" >&2; usage; exit 2; }
        case $1 in
          --core) core=$2 ;;
          --base) base=$2 ;;
          --path) path=$2; have_path=1 ;;
          --pr-state) prs=$2 ;;
        esac
        shift 2 ;;
      *) echo "cleanup_path_admit.sh: unknown argument '$1'" >&2; usage; exit 2 ;;
    esac
  done
  [ -n "$core" ] && [ -n "$base" ] && [ "$have_path" -eq 1 ] || { usage; exit 2; }
  case $prs in '' | merged | closed | open | none) ;; *)
    echo "cleanup_path_admit.sh: --pr-state must be merged, closed, open or none" >&2; exit 2 ;;
  esac
  git check-ref-format --branch "$base" >/dev/null 2>&1 \
    || { echo "cleanup_path_admit.sh: --base is not a legal branch name" >&2; exit 2; }

  # 1 — core
  safe_abs "$core" || { echo "cleanup_path_admit.sh: --core is not a plain absolute path" >&2; exit 2; }
  [ "$(cd -P -- "$core" 2>/dev/null && pwd -P)" = "$core" ] \
    || { echo "cleanup_path_admit.sh: --core does not resolve to itself" >&2; exit 2; }
  common="$(git -C "$core" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || { echo "cleanup_path_admit.sh: --core is not a git checkout" >&2; exit 2; }
  [ "$(cd -P -- "$(dirname -- "$common")" 2>/dev/null && pwd -P)" = "$core" ] \
    || { echo "cleanup_path_admit.sh: --core is not its repository's main worktree" >&2; exit 2; }

  # 2 — the spelling
  case $path in /*) ;; *) refuse "not an absolute path" ;; esac
  case $path in *[!A-Za-z0-9._/-]*) refuse "a byte outside [A-Za-z0-9._/-] (space, quote, control or non-ASCII)" ;; esac
  safe_abs "$path" || refuse "an empty, '.' or '..' component, or a trailing slash"

  # 3 — the home
  home="$core/.nen/worktrees"
  case $path in "$home"/?*) ;; *) refuse "outside the cleanup home $home" ;; esac

  # 4 — no symlink anywhere on the way
  [ -L "$core/.nen" ] && refuse "$core/.nen is a symlink"
  [ -L "$home" ] && refuse "the cleanup home is a symlink"
  [ -L "$path" ] && refuse "the path is a symlink"
  [ -d "$path" ] || refuse "not a directory on disk (a prunable entry is git worktree prune's)"
  [ "$(cd -P -- "$path" 2>/dev/null && pwd -P)" = "$path" ] || refuse "does not resolve to itself (a symlinked component)"
  [ "$(git -C "$path" rev-parse --show-toplevel 2>/dev/null)" = "$path" ] || refuse "not a worktree root"

  # 5 — the inventory
  porcelain="$(git -C "$core" worktree list --porcelain 2>/dev/null)" || refuse "the worktree inventory is unreadable"
  stanza="$(printf '%s\n' "$porcelain" | awk -v p="$path" '
    /^worktree / { cur = substr($0, 10); if (cur == p) print "listed"; next }
    /^$/ { cur = ""; next }
    cur == p { print }')"
  printf '%s\n' "$stanza" | grep -qx 'listed' || refuse "not listed by git worktree list"

  # 6 — the trunk
  printf '%s\n' "$stanza" | grep -qxF "branch refs/heads/$base" && refuse "checked out on the trunk $base"

  cmd="git -C '$core' worktree remove -- '$path'"
  [ -z "$prs" ] && { printf 'admitted\t-\t%s\n' "$cmd"; exit 0; }

  if printf '%s\n' "$stanza" | grep -q '^locked'; then
    printf 'named\tlocked\t-\n'; exit 0
  fi
  [ "$prs" = open ] && { printf 'named\tPR open\t-\n'; exit 0; }
  if ! dirt="$(git -C "$path" status --porcelain 2>/dev/null)"; then
    printf 'proposed\tstatus unreadable, PR %s\t%s\n' "$prs" "$cmd"; exit 0
  fi
  if [ -n "$dirt" ]; then
    n="$(printf '%s\n' "$dirt" | wc -l | tr -d ' ')"
    printf 'proposed\tdirty: %s path(s), PR %s\t%s\n' "$n" "$prs" "$cmd"
    printf '%s\n' "$dirt" | while IFS= read -r line; do
      printf 'dirt\t%s %s\n' "$(printf '%.2s' "$line" | tr -c 'A-Z?! ' '?')" "$(shown "${line#???}")"
    done
    exit 0
  fi
  printf '%s\n' "$stanza" | grep -q '^branch refs/heads/' \
    || { printf 'proposed\tclean, detached, PR %s\t%s\n' "$prs" "$cmd"; exit 0; }
  [ "$prs" = merged ] && { printf 'deterministic\ton-branch-clean, PR merged\t%s\n' "$cmd"; exit 0; }
  printf 'proposed\ton-branch-clean, PR %s\t%s\n' "$prs" "$cmd"
  exit 0
}

# --- self-test ------------------------------------------------------------------------------------
st_fails=0
st_case() { # <want-exit> <want-first-field> <label> <args...>
  want=$1 field=$2 label=$3; shift 3
  st_out="$(sh "$st_self" "$@" 2>/dev/null)"; got=$?
  first="$(printf '%s\n' "$st_out" | head -n 1 | cut -f 1)"
  if [ "$got" -eq "$want" ] && { [ "$field" = - ] || [ "$first" = "$field" ]; }; then
    echo "  ok    $label"
  else
    echo "  FAIL  $label (exit $got, want $want; class '$first', want '$field')" >&2
    st_fails=$((st_fails + 1))
  fi
}
st_has() { # <fixed-text> <label>
  if printf '%s\n' "$st_out" | grep -qF -- "$1"; then echo "  ok    $2"
  else echo "  FAIL  $2 (no '$1' in: $st_out)" >&2; st_fails=$((st_fails + 1)); fi
}
st_true() { # <label> <command...>
  label=$1; shift
  if "$@" >/dev/null 2>&1; then echo "  ok    $label"
  else echo "  FAIL  $label" >&2; st_fails=$((st_fails + 1)); fi
}

self_test_main() {
  st_self="$(cd -P -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")"
  st_tmp="$(mktemp -d "${TMPDIR:-/tmp}/cleanup-path-admit.XXXXXX")" || return 2
  trap 'rm -rf "$st_tmp"' EXIT INT TERM HUP
  st_tmp="$(cd -P -- "$st_tmp" && pwd -P)" || return 2
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  GIT_AUTHOR_NAME=selftest GIT_AUTHOR_EMAIL=selftest@example.invalid
  GIT_COMMITTER_NAME=selftest GIT_COMMITTER_EMAIL=selftest@example.invalid
  export GIT_CONFIG_NOSYSTEM GIT_CONFIG_GLOBAL GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
  core="$st_tmp/core"; home="$core/.nen/worktrees/claude-code"
  {
    git init -q -b main "$core" && git -C "$core" commit -q --allow-empty -m base \
      && git -C "$core" switch -q -c scratch && mkdir -p "$home" \
      && git -C "$core" worktree add -q -b feat-merged "$home/merged" main \
      && git -C "$core" worktree add -q -b feat-closed "$home/closed" main \
      && git -C "$core" worktree add -q -b feat-dirty "$home/dirty" main \
      && git -C "$core" worktree add -q -b feat-locked "$home/locked" main \
      && git -C "$core" worktree lock "$home/locked" \
      && git -C "$core" worktree add -q -b feat-open "$home/open" main \
      && git -C "$core" worktree add -q --detach "$home/detached" main \
      && git -C "$core" worktree add -q "$home/trunk" main \
      && git -C "$core" worktree add -q -b feat-outside "$st_tmp/outside" main \
      && printf 'x\n' >"$home/dirty/uncommitted.txt" \
      && mkdir "$home/stray" && ln -s "$home/merged" "$home/link" \
      && git init -q -b main "$st_tmp/core2" && git -C "$st_tmp/core2" commit -q --allow-empty -m base \
      && mkdir -p "$st_tmp/elsewhere/worktrees/claude-code" && ln -s "$st_tmp/elsewhere" "$st_tmp/core2/.nen" \
      && git -C "$st_tmp/core2" worktree add -q -b feat-x "$st_tmp/core2/.nen/worktrees/claude-code/x" main
  } >/dev/null 2>&1 || { echo "cleanup_path_admit.sh --self-test: could not build the fixture" >&2; return 2; }
  a="--core $core --base main"
  echo "cleanup_path_admit.sh --self-test"

  # The contradiction #333 names: the old § 4 ref rule refuses every native absolute path.
  st_true "git check-ref-format --branch refuses the absolute path (why the ref rule cannot admit it)" \
    sh -c '! git check-ref-format --branch "$1"' _ "$home/merged"

  # --- admission ---------------------------------------------------------------------------------
  # shellcheck disable=SC2086
  st_case 0 admitted "a listed worktree under the home is admitted" $a --path "$home/merged"
  st_has "git -C '$core' worktree remove -- '$home/merged'" "with the one literal, quoted command after --"
  # shellcheck disable=SC2086
  { st_case 1 named "core itself is refused" $a --path "$core"
    st_case 1 named "the trunk's worktree is refused" $a --path "$home/trunk"
    st_has "on the trunk" "and says it is the trunk"
    st_case 1 named "a listed worktree outside the home is refused" $a --path "$st_tmp/outside"
    st_case 1 named "a directory git does not list is refused" $a --path "$home/stray"
    st_case 1 named "a symlink to an admitted worktree is refused" $a --path "$home/link"
    st_case 1 named "'..' traversal is refused as spelled, never normalised" $a --path "$home/../claude-code/merged"
    st_case 1 named "a '.' component is refused" $a --path "$home/./merged"
    st_case 1 named "a trailing slash is refused" $a --path "$home/merged/"
    st_case 1 named "a relative path is refused" $a --path "claude-code/merged"
    st_case 1 named "an empty path is refused" $a --path ""
    st_case 1 named "a space is refused" $a --path "$home/mer ged"
    st_case 1 named "a single quote is refused" $a --path "$home/mer'ged"
    st_case 1 named "a newline is refused" $a --path "$home/mer
ged"
    st_has "$home/mer?ged" "and the refused name is shown escaped"
    st_case 1 named "a symlinked .nen in core is refused" --core "$st_tmp/core2" --base main \
      --path "$st_tmp/core2/.nen/worktrees/claude-code/x"
  }

  # --- the § 5 class, once admitted -----------------------------------------------------------------
  # shellcheck disable=SC2086
  { st_case 0 deterministic "clean, on a branch, PR merged → deterministic" $a --path "$home/merged" --pr-state merged
    st_case 0 proposed "clean, PR closed unmerged → proposed" $a --path "$home/closed" --pr-state closed
    st_case 0 proposed "clean, no PR → proposed" $a --path "$home/closed" --pr-state none
    st_case 0 proposed "dirty, PR merged → proposed, never deterministic" $a --path "$home/dirty" --pr-state merged
    st_has "dirt	?? uncommitted.txt" "with every dirty path listed"
    st_case 0 named "locked → named" $a --path "$home/locked" --pr-state merged
    st_case 0 named "PR open → named" $a --path "$home/open" --pr-state open
    st_has "PR open	-" "and a named row carries no command"
    st_case 0 proposed "clean but detached, PR merged → proposed" $a --path "$home/detached" --pr-state merged
  }

  # --- wiring ---------------------------------------------------------------------------------------
  st_case 2 - "no --base is refused" --core "$core" --path "$home/merged"
  st_case 2 - "an unknown --pr-state is refused" --core "$core" --base main --path "$home/merged" --pr-state gone
  st_case 2 - "a linked worktree as --core is refused" --core "$home/merged" --base main --path "$home/closed"
  st_case 2 - "a non-canonical --core is refused" --core "$core/.nen/.." --base main --path "$home/merged"
  st_case 2 - "an unknown argument is refused" --core "$core" --base main --path "$home/merged" --force

  # The printed command is literal and runs as printed; the script itself removed nothing.
  st_true "the script removed nothing" test -d "$home/merged"
  st_true "the printed command removes the clean merged worktree" \
    git -C "$core" worktree remove -- "$home/merged"
  st_true "and leaves the .nen/ home in place" test -d "$home"

  if [ "$st_fails" -eq 0 ]; then
    echo "cleanup_path_admit.sh --self-test: all assertions held; nothing left this machine."
    return 0
  fi
  echo "cleanup_path_admit.sh --self-test: $st_fails assertion(s) failed" >&2
  return 1
}

if [ "${1:-}" = --self-test ]; then
  [ "$#" -eq 1 ] || { echo "cleanup_path_admit.sh: --self-test takes no other argument" >&2; exit 2; }
  self_test_main
  exit $?
fi
admit_main "$@"
