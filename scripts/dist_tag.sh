#!/bin/sh
# dist_tag.sh — cut the ONE opt-in distribution tag for a target that has just been sent to.
# Moved verbatim out of claude/skills/kagutsuchi/SKILL.md § 4a (2026-09-20 diet, zheref/hatsu#89).
#
#   scripts/dist_tag.sh --repo <path> --target-file <file> [--dry-run]
#   scripts/dist_tag.sh --self-test
#
# --target-file is a file holding the target name, VERBATIM AND ALONE. THE TARGET IS THE MAINTAINER'S
# WORD AND IT IS DATA: it never enters shell source at all. A double-quoted assignment still runs
# command substitution, and a quoted heredoc's delimiter is in-band. The caller writes that file with
# the SURFACE'S OWN file-writing primitive — never echo, printf, cat or a heredoc.
#
# --dry-run performs every check and prints its verdict, and cuts nothing.
# --self-test runs the hermetic offline fixtures in a throwaway repository and cuts nothing, ever.
#
# exit 0  the tag was cut (or, with --dry-run, every check passed)
# exit 2  refused, with the reason on stderr — nothing was cut
# exit 3  no `tags.deploy` entry for this target: not declared, nothing cut, not an error
# exit 1  `nen tag cut` itself failed; its own reason stands and is never routed around

usage() {
  echo "usage: dist_tag.sh --repo <path> --target-file <file> [--dry-run]" >&2
  echo "       dist_tag.sh --self-test" >&2
  echo "  --target-file holds the target name verbatim and alone, written by the surface's own" >&2
  echo "  file-writing tool. The target never enters shell source." >&2
}

# ---------------------------------------------------------------------------
# --self-test — hermetic, offline, and it cuts nothing.
#
# Every assertion runs through --dry-run or through a refusal that fires before `nen tag cut` is
# reached, so no tag is ever created and `nen` is never invoked. Each case gets its own throwaway
# repository, copied from one good baseline, so a case cannot leave state behind for the next one.
# ---------------------------------------------------------------------------
st_fails=0
st_out=""

st_run() {  # st_run <expected exit> <label> [args...]
  st_want="$1"; st_label="$2"; shift 2
  st_out="$(sh "$st_self" "$@" 2>&1)"; st_rc=$?
  if [ "$st_rc" -eq "$st_want" ]; then
    echo "  ok    $st_label (exit $st_rc)"
  else
    echo "  FAIL  $st_label: expected exit $st_want, got $st_rc" >&2
    echo "$st_out" | sed 's/^/          /' >&2
    st_fails=$((st_fails + 1))
  fi
}

st_says() {  # st_says <substring> <label> -- the LAST st_run's output must contain it
  case "$st_out" in
    *"$1"*) echo "  ok    $2" ;;
    *) echo "  FAIL  $2: output does not carry '$1'" >&2
       echo "$st_out" | sed 's/^/          /' >&2
       st_fails=$((st_fails + 1)) ;;
  esac
}

st_silent() {  # st_silent <substring> <label> -- the LAST st_run's output must NOT contain it
  case "$st_out" in
    *"$1"*) echo "  FAIL  $2: output carries '$1' and must not" >&2
            echo "$st_out" | sed 's/^/          /' >&2
            st_fails=$((st_fails + 1)) ;;
    *) echo "  ok    $2" ;;
  esac
}

st_build() {  # st_build <dir> -- one good baseline repository, clean tree
  git init -q "$1" >/dev/null 2>&1 || return 1
  git -C "$1" symbolic-ref HEAD refs/heads/main
  mkdir -p "$1/nen" "$1/dist"
  cat >"$1/nen/workflow.json" <<'JSON'
{ "branch": { "base": "main" },
  "tags": { "identity": { "nameFrom": "dist/identity.txt" },
            "deploy": { "internal": { "push": true }, "quiet": { "push": false } } } }
JSON
  printf 'v1.2.3\nplaceholder\n' >"$1/dist/identity.txt"
  git -C "$1" add -A
  git -c commit.gpgsign=false -c core.hooksPath=/dev/null -C "$1" commit -q -m base
  st_sha="$(git -C "$1" rev-parse HEAD)"
  printf 'v1.2.3\n%s\n' "$st_sha" >"$1/dist/identity.txt"
  git -C "$1" add -A
  git -c commit.gpgsign=false -c core.hooksPath=/dev/null -C "$1" commit -q -m identity
}

st_copy() {  # st_copy <name> -- a fresh copy of the baseline; echoes its path
  cp -R "$st_tmp/base" "$st_tmp/$1"
  echo "$st_tmp/$1"
}

self_test_main() {
  st_self="$(cd -P -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")"
  st_tmp="$(mktemp -d "${TMPDIR:-/tmp}/dist-tag-selftest.XXXXXX")" || return 2
  trap 'chmod -R u+rwX "$st_tmp" 2>/dev/null; rm -rf "$st_tmp"' EXIT INT TERM HUP
  GIT_AUTHOR_NAME=selftest GIT_AUTHOR_EMAIL=selftest@example.invalid
  GIT_COMMITTER_NAME=selftest GIT_COMMITTER_EMAIL=selftest@example.invalid
  export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
  st_build "$st_tmp/base" || { echo "dist_tag.sh --self-test: could not build the fixture repository" >&2; return 2; }

  printf 'internal\n' >"$st_tmp/t-internal"
  printf 'quiet\n'    >"$st_tmp/t-quiet"
  printf 'nope\n'     >"$st_tmp/t-undeclared"
  printf 'a\nb\n'     >"$st_tmp/t-two-lines"
  printf 'inter\tnal\n' >"$st_tmp/t-control"
  printf 'internal\n' >"$st_tmp/t-unreadable"

  echo "dist_tag.sh --self-test"

  # --- the argument parser: every two-argument flag given no argument (N1) ---------------------
  st_run 2 "--repo with no value is refused, never an empty repo path" --repo
  st_run 2 "--target-file with no value is refused" --repo "$st_tmp/base" --target-file
  st_run 2 "neither flag given is refused" --dry-run
  st_run 2 "an unknown argument is refused" --repo "$st_tmp/base" --nope

  # --- the target file is proven before it is read (P4) ----------------------------------------
  st_run 2 "a missing --target-file is refused as a file, not as an empty target" \
    --repo "$st_tmp/base" --target-file "$st_tmp/does-not-exist" --dry-run
  st_says "not a readable regular file" "and the refusal names the file, not the target"
  st_run 2 "a directory as --target-file is refused" \
    --repo "$st_tmp/base" --target-file "$st_tmp" --dry-run
  if [ "$(id -u)" != "0" ]; then
    chmod 000 "$st_tmp/t-unreadable"
    st_run 2 "an unreadable --target-file is refused" \
      --repo "$st_tmp/base" --target-file "$st_tmp/t-unreadable" --dry-run
    chmod 644 "$st_tmp/t-unreadable"
  else
    echo "  skip  unreadable --target-file: running as root, the mode would not hold"
  fi
  st_run 2 "a two-line --target-file is refused rather than joined" \
    --repo "$st_tmp/base" --target-file "$st_tmp/t-two-lines" --dry-run
  st_run 2 "a --target-file that is not one printable line is refused" \
    --repo "$st_tmp/base" --target-file "$st_tmp/t-control" --dry-run
  st_says "not one printable line" "and says which rule refused it"

  # --- the opt-in, and what `push` decides ------------------------------------------------------
  st_run 3 "a target with no tags.deploy entry is exit 3, nothing cut" \
    --repo "$st_tmp/base" --target-file "$st_tmp/t-undeclared" --dry-run
  st_run 0 "a declared target with push: true passes every check" \
    --repo "$st_tmp/base" --target-file "$st_tmp/t-internal" --dry-run
  st_says "--push" "and carries --push"
  st_run 0 "a declared target with push: false passes every check" \
    --repo "$st_tmp/base" --target-file "$st_tmp/t-quiet" --dry-run
  st_silent "--push" "and drops --push"

  # --- nameFrom: a symlink, and a path that leaves the repository ------------------------------
  d="$(st_copy sym)"
  rm -f "$d/dist/identity.txt"; ln -s /etc/hosts "$d/dist/identity.txt"
  st_run 2 "a symlinked nameFrom is refused" --repo "$d" --target-file "$st_tmp/t-internal" --dry-run
  st_says "symlink" "and says so"

  d="$(st_copy outside)"
  printf 'v9\n%s\n' "$st_sha" >"$st_tmp/outside-identity.txt"
  sed 's|"dist/identity.txt"|"../outside-identity.txt"|' "$d/nen/workflow.json" >"$d/nen/workflow.json.new"
  mv "$d/nen/workflow.json.new" "$d/nen/workflow.json"
  st_run 2 "a nameFrom resolving outside the repository is refused" \
    --repo "$d" --target-file "$st_tmp/t-internal" --dry-run

  # --- the recorded build SHA -------------------------------------------------------------------
  d="$(st_copy nothex)"
  printf 'v1.2.3\nHEAD\n' >"$d/dist/identity.txt"
  st_run 2 "a build SHA that is not raw lowercase hex is refused, never resolved" \
    --repo "$d" --target-file "$st_tmp/t-internal" --dry-run
  st_says "raw lowercase hex" "and says so"

  d="$(st_copy shortsha)"
  printf 'v1.2.3\n%s\n' "$(printf '%s' "$st_sha" | cut -c1-39)" >"$d/dist/identity.txt"
  st_run 2 "an abbreviated build SHA is refused" \
    --repo "$d" --target-file "$st_tmp/t-internal" --dry-run

  d="$(st_copy nosha)"
  printf 'v1.2.3\n' >"$d/dist/identity.txt"
  st_run 2 "a nameFrom carrying no build SHA is refused rather than tagging HEAD" \
    --repo "$d" --target-file "$st_tmp/t-internal" --dry-run

  d="$(st_copy noidentity)"
  printf '\n%s\n' "$st_sha" >"$d/dist/identity.txt"
  st_run 2 "an empty first line is refused" --repo "$d" --target-file "$st_tmp/t-internal" --dry-run

  # --- a nameFrom whose own name is `-` still reads as a FILE (F1) ------------------------------
  d="$(st_copy dashname)"
  printf 'v1.2.3\n%s\n' "$st_sha" >"$d/-"
  sed 's|"dist/identity.txt"|"-"|' "$d/nen/workflow.json" >"$d/nen/workflow.json.new"
  mv "$d/nen/workflow.json.new" "$d/nen/workflow.json"
  git -C "$d" add -A
  git -c commit.gpgsign=false -c core.hooksPath=/dev/null -C "$d" commit -q -m dashname
  st_run 0 "a nameFrom named '-' is read as a file, never as standard input" \
    --repo "$d" --target-file "$st_tmp/t-internal" --dry-run
  st_says "identity (line 1): v1.2.3" "and its first line is the identity"

  # --- a dirty tree, and an illegal composed ref ------------------------------------------------
  d="$(st_copy dirty)"
  : >"$d/stray-file"
  st_run 2 "a dirty working tree is refused" --repo "$d" --target-file "$st_tmp/t-internal" --dry-run
  st_says "dirty" "and says so"

  d="$(st_copy badref)"
  printf 'v1.2.3 beta\n%s\n' "$st_sha" >"$d/dist/identity.txt"
  git -C "$d" add -A
  git -c commit.gpgsign=false -c core.hooksPath=/dev/null -C "$d" commit -q -m badref
  st_run 2 "an illegal composed tag name is refused" \
    --repo "$d" --target-file "$st_tmp/t-internal" --dry-run
  st_says "not a legal git ref" "and says so"

  # --- the declaration itself --------------------------------------------------------------------
  d="$(st_copy noworkflow)"
  rm -f "$d/nen/workflow.json"
  st_run 2 "a repository with no nen/workflow.json is refused" \
    --repo "$d" --target-file "$st_tmp/t-internal" --dry-run
  st_run 2 "a path that is not a git repository is refused" \
    --repo "$st_tmp" --target-file "$st_tmp/t-internal" --dry-run

  if [ "$st_fails" -eq 0 ]; then
    echo "dist_tag.sh --self-test: all assertions held; nothing was cut."
    return 0
  fi
  echo "dist_tag.sh --self-test: $st_fails assertion(s) failed" >&2
  return 1
}

# EVERY TWO-ARGUMENT FLAG IS GUARDED BEFORE IT SHIFTS TWICE. `--repo` as the last word on the line
# used to assign the empty string and `shift 2` past the end; under `set -u` that is an error with a
# shell's wording, and without it a silent empty --repo reads the CURRENT directory's repository.
repo=""; target_file=""; dry=0; self_test=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || { usage; exit 2; }; repo="$2"; shift 2 ;;
    --target-file) [ $# -ge 2 ] || { usage; exit 2; }; target_file="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    --self-test) self_test=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "dist_tag.sh: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done

if [ "$self_test" -eq 1 ]; then
  [ -z "$repo" ] && [ -z "$target_file" ] || { echo "dist_tag.sh: --self-test takes no other argument" >&2; exit 2; }
  self_test_main
  exit $?
fi

[ -n "$repo" ] && [ -n "$target_file" ] || { usage; exit 2; }

say() { [ "$dry" -eq 1 ] && echo "  ok   $1"; }

root="$(git -C "$repo" rev-parse --show-toplevel)" || { echo "dist_tag.sh: not a git repository: $repo" >&2; exit 2; }
wf="$root/nen/workflow.json"
[ -f "$wf" ] || { echo "dist_tag.sh: no $wf -- refused" >&2; exit 2; }

# THE TARGET FILE IS PROVEN BEFORE IT IS READ. A redirection from a missing or unreadable path
# produces an EMPTY target under `$(...)`, and an empty target would refuse below with "no target
# named" -- a true sentence about the wrong thing, sending the caller to look at the maintainer's
# word instead of at the file that was never there.
[ -f "$target_file" ] && [ -r "$target_file" ] \
  || { echo "dist_tag.sh: --target-file is not a readable regular file: $target_file -- refused" >&2; exit 2; }

# ONE PRINTABLE LINE, AND NOTHING ELSE. The file carries the maintainer's word verbatim and alone:
# a second line, a control character or a byte outside printable ASCII means the surface wrote
# something other than a target name, and joining the lines would invent a name nobody typed.
if [ "$(awk 'END { print NR }' <"$target_file")" -gt 1 ]; then
  echo "dist_tag.sh: --target-file carries more than one line -- refused" >&2; exit 2
fi
target="$(tr -d '\r\n' <"$target_file")"
[ -n "$target" ] || { echo "dist_tag.sh: no target named -- refused" >&2; exit 2; }
case "$target" in
  *[![:print:]]*) echo "dist_tag.sh: --target-file is not one printable line -- refused" >&2; exit 2 ;;
esac
say "target read from file, never from shell source: $target"

# THE OPT-IN FOR THIS TARGET, FIRST. Three outcomes, never two: exit 3 is "not declared" and is
# reported without cutting; any other nonzero is a refusal, because present-but-malformed is never
# reported as absent. isinstance(d, dict) is load-bearing -- `in` against a string is a substring
# test -- and key presence is tested before the value, absent and null being different answers.
python3 -c 'import json,sys
d=json.load(open(sys.argv[1])).get("tags",{}).get("deploy",{})
if not isinstance(d, dict): sys.exit("tags.deploy is %s, not an object" % type(d).__name__)
if sys.argv[2] not in d: sys.exit(3)
e=d[sys.argv[2]]
if not isinstance(e, dict): sys.exit("tags.deploy.%s is %s, not an object" % (sys.argv[2], type(e).__name__ if e is not None else "null"))
p=e.get("push", False)
if not isinstance(p, bool): sys.exit("tags.deploy.%s.push is %r, not a boolean" % (sys.argv[2], p))
sys.exit(0 if p else 4)' "$wf" "$target"
# FOUR OUTCOMES, because `push` is a VALUE and not merely a key: the declaration controls the flag.
case $? in
  0) push_flag="--push"; say "tags.deploy.$target declared, push: true" ;;
  4) push_flag="";       say "tags.deploy.$target declared, push: false" ;;
  3) echo "no tags.deploy entry for '$target' -- not declared for this target, nothing cut"; exit 3 ;;
  *) echo "dist_tag.sh: $wf could not be read for tags.deploy -- present but unreadable is not absent; refused" >&2; exit 2 ;;
esac

# THE SAME THREE-WAY READ FOR THE NAME: a silent empty nameFrom would make every refusal below
# report a misleading reason for a file that was never named.
nameFrom="$(python3 -c 'import json,sys
d=json.load(open(sys.argv[1])).get("tags",{}).get("identity",{})
if not isinstance(d, dict) or not isinstance(d.get("nameFrom"), str) or not d["nameFrom"]:
    sys.exit("tags.identity.nameFrom is missing or is not a non-empty string")
print(d["nameFrom"])' "$wf")" || { echo "dist_tag.sh: tags.identity.nameFrom unreadable -- refused" >&2; exit 2; }
say "tags.identity.nameFrom: $nameFrom"

file="$root/$nameFrom"
[ -L "$file" ] && { echo "dist_tag.sh: nameFrom is a symlink -- refused" >&2; exit 2; }
[ -f "$file" ] || { echo "dist_tag.sh: nameFrom is not a regular file -- refused" >&2; exit 2; }
case "$(cd -P -- "$(dirname -- "$file")" && pwd -P)/" in
  "$root"/*) : ;;
  *) echo "dist_tag.sh: nameFrom resolves outside the repository -- refused" >&2; exit 2 ;;
esac
say "nameFrom is a regular file inside the repository, not a symlink"

# REDIRECTION, NOT AN OPERAND. `--` stops sed reading the path as a flag, but it does NOT stop sed
# reading a lone `-` as standard input: a repository-controlled nameFrom is caller data all the way
# down, so the file is opened by the shell and sed is handed no path at all.
identity="$(sed -n '1p' <"$file" | tr -d '\r')"
built_at="$(sed -n '2p' <"$file" | tr -d '\r')"
[ -n "$identity" ] || { echo "dist_tag.sh: nameFrom's first line is empty -- refused" >&2; exit 2; }
say "identity (line 1): $identity"

# THE SHA THE ARCHIVE WAS BUILT FROM, NEVER HEAD, and it must be a RAW sha: `cat-file -e` resolves
# HEAD, origin/main and HEAD~1 too, which would defeat the rule it is checking.
[ -n "$built_at" ] || { echo "dist_tag.sh: nameFrom carries no build SHA -- refused rather than tagging HEAD" >&2; exit 2; }
case "$built_at" in
  *[!0-9a-f]* | "") echo "dist_tag.sh: the recorded build SHA is not raw lowercase hex -- refused" >&2; exit 2 ;;
esac
[ "${#built_at}" -eq 40 ] || { echo "dist_tag.sh: the recorded build SHA is not a full 40-character name -- refused" >&2; exit 2; }
git -C "$repo" cat-file -e "${built_at}^{commit}" 2>/dev/null \
  || { echo "dist_tag.sh: the recorded build SHA is not a commit in this repository -- refused" >&2; exit 2; }
say "build SHA (line 2) is a raw 40-character commit in this repository: $built_at"

# A CLEAN TREE IS WHAT KEEPS THE TAG FROM ATTESTING BYTES THAT WERE NEVER ARCHIVED.
[ -z "$(git -C "$repo" status --porcelain)" ] \
  || { echo "dist_tag.sh: the working tree is dirty -- refused rather than tagging bytes the commit does not describe" >&2; exit 2; }
say "working tree is clean"

# THE SPECIES PREFIX IS BUILT FROM VARIABLES, NEVER TEMPLATED, so it cannot disagree with the target.
name="dist/$target/$identity"
git -C "$repo" check-ref-format "refs/tags/$name" \
  || { echo "dist_tag.sh: the composed tag name is not a legal git ref -- refused" >&2; exit 2; }
say "composed tag name is a legal git ref: $name"

# branch.base IS REPOSITORY-CONTROLLED TOO: read as data, never substituted into command text.
trunk="$(python3 -c 'import json,sys
b=json.load(open(sys.argv[1])).get("branch",{})
if not isinstance(b, dict): sys.exit("branch is not an object")
t=b.get("base","main")
if not isinstance(t, str) or not t: sys.exit("branch.base is not a non-empty string")
print(t)' "$wf")" || { echo "dist_tag.sh: branch.base unreadable -- refused" >&2; exit 2; }
git -C "$repo" check-ref-format --allow-onelevel "$trunk" \
  || { echo "dist_tag.sh: branch.base is not a legal git ref name -- refused" >&2; exit 2; }
say "trunk read from branch.base as data: $trunk"

if [ "$dry" -eq 1 ]; then
  echo "would run: nen tag cut --repo \"$repo\" --name \"$name\" --at $built_at --trunk \"$trunk\" ${push_flag}"
  echo "nothing was cut: --dry-run performs every check and stops."
  exit 0
fi

# nen refuses --at unless that commit is an ancestor of origin/<trunk>; its reason stands as given.
nen tag cut --repo "$repo" --name "$name" --at "$built_at" --trunk "$trunk" ${push_flag} || exit 1
