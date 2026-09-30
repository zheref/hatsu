#!/bin/sh
# send_freshness_check.sh — the freshness gate a non-production send passes BEFORE `--run`.
# kagutsuchi § 3a (zheref/hatsu#146): the archive that is about to be sent must be the one the
# checkout describes, and that checkout must be the trunk's tip.
#
#   scripts/send_freshness_check.sh --repo <path> [--base <branch>]
#   scripts/send_freshness_check.sh --self-test
#
# THE QUESTION IT ANSWERS: is the .ipa (or whatever the archive row produced) in this checkout a
# build of the commit this checkout is standing on, and is that commit the tip of the trunk right
# now? Canon already protected the TAG (scripts/dist_tag.sh refuses a dirty tree and tags the
# recorded SHA), but the tag is cut AFTER a green send: a 95-commit-stale archive went out first
# and only the tag refused. This gate runs first.
#
# WHAT IT READS, as data and never templated into shell source:
#   nen/workflow.json -> tags.identity.nameFrom   the file the repository's own `archive` row wrote:
#                                                 line 1 the identity, LINE 2 THE COMMIT IT WAS BUILT
#                                                 FROM (susanoo § 5a, kagutsuchi § 4a)
#   nen/workflow.json -> branch.base              the trunk, unless --base overrides it
#
# THE CHECKS, in order — every one a refusal at exit 2 with the reason on stderr:
#   1. the working tree is clean          (a dirty tree is refused BEFORE the send, not only at the tag)
#   2. nameFrom is a regular file inside the repository, not a symlink, and its line 2 is a raw
#      40-character commit this repository has
#   3. the built SHA is the checkout's HEAD
#   4. `git fetch origin <base>` succeeds and the built SHA is origin/<base>'s tip
#
# exit 0  fresh: the four lines below are printed and the send may proceed
# exit 2  refused, reason on stderr — the plan is still the caller's to print; nothing was sent
# exit 3  no tags.identity declared: the built SHA cannot be read, so freshness is NOT asserted.
#         Reported as that fact, never as fresh. The dirty-tree check (1) still ran and passed.
#
# Every verdict prints, on stdout:
#   built:          <sha>   (line 2 of nameFrom)      -- or "unrecorded (no tags.identity declared)"
#   head:           <sha>
#   origin/<base>:  <sha>                            -- after the fetch
#   tree:           clean
#   freshness:      fresh | unverified

usage() {
  echo "usage: send_freshness_check.sh --repo <path> [--base <branch>]" >&2
  echo "       send_freshness_check.sh --self-test" >&2
}

# ---------------------------------------------------------------------------
# --self-test — hermetic, offline. A bare repository stands in for `origin` so that the fetch in
# check 4 is real and still touches no network. Nothing is sent, nothing is tagged.
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

st_says() {  # st_says <substring> <label>
  case "$st_out" in
    *"$1"*) echo "  ok    $2" ;;
    *) echo "  FAIL  $2: output does not carry '$1'" >&2
       echo "$st_out" | sed 's/^/          /' >&2
       st_fails=$((st_fails + 1)) ;;
  esac
}

st_git() { git -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }

st_build() {  # st_build <dir> -- origin (bare) + a clone whose archive row "ran" at its tip
  git init -q --bare "$1/origin.git" >/dev/null 2>&1 || return 1
  git -C "$1/origin.git" symbolic-ref HEAD refs/heads/main
  git init -q "$1/core" >/dev/null 2>&1 || return 1
  git -C "$1/core" symbolic-ref HEAD refs/heads/main
  mkdir -p "$1/core/nen" "$1/core/dist"
  cat >"$1/core/nen/workflow.json" <<'JSON'
{ "branch": { "base": "main" },
  "tags": { "identity": { "nameFrom": "dist/identity.txt" } } }
JSON
  printf 'dist/identity.txt\n' >"$1/core/.gitignore"
  printf 'hello\n' >"$1/core/README"
  st_git -C "$1/core" add -A
  st_git -C "$1/core" commit -q -m base
  git -C "$1/core" remote add origin "$1/origin.git"
  git -C "$1/core" push -q origin main
  st_sha="$(git -C "$1/core" rev-parse HEAD)"
  printf 'v1.2.3\n%s\n' "$st_sha" >"$1/core/dist/identity.txt"   # the archive "ran" at the tip
}

st_copy() {  # st_copy <name> -- a fresh copy of the baseline core; echoes its path
  cp -R "$st_tmp/core" "$st_tmp/$1"
  echo "$st_tmp/$1"
}

self_test_main() {
  st_self="$(cd -P -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")"
  st_tmp="$(mktemp -d "${TMPDIR:-/tmp}/send-freshness-selftest.XXXXXX")" || return 2
  trap 'chmod -R u+rwX "$st_tmp" 2>/dev/null; rm -rf "$st_tmp"' EXIT INT TERM HUP
  GIT_AUTHOR_NAME=selftest GIT_AUTHOR_EMAIL=selftest@example.invalid
  GIT_COMMITTER_NAME=selftest GIT_COMMITTER_EMAIL=selftest@example.invalid
  export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
  st_build "$st_tmp" || { echo "send_freshness_check.sh --self-test: could not build the fixture" >&2; return 2; }

  echo "send_freshness_check.sh --self-test"

  # --- the argument parser ----------------------------------------------------------------------
  st_run 2 "--repo with no value is refused" --repo
  st_run 2 "--base with no value is refused" --repo "$st_tmp/core" --base
  st_run 2 "no --repo is refused" --base main
  st_run 2 "an unknown argument is refused" --repo "$st_tmp/core" --nope
  st_run 2 "a path that is not a git repository is refused" --repo "$st_tmp"

  # --- the good case: built == HEAD == origin/main, clean tree ----------------------------------
  st_run 0 "an archive built at HEAD, at the fetched tip, on a clean tree, is fresh" --repo "$st_tmp/core"
  st_says "freshness:      fresh" "and says fresh"
  st_says "built:          $st_sha" "and names the built SHA"
  st_says "origin/main:    $st_sha" "and names the trunk's tip"

  # --- 1. a dirty tree is refused before anything else ------------------------------------------
  d="$(st_copy dirty)"; : >"$d/stray"
  st_run 2 "a dirty working tree is refused before the send" --repo "$d"
  st_says "dirty" "and says so"

  # --- 2. the record -----------------------------------------------------------------------------
  d="$(st_copy noidentity)"
  printf '{ "branch": { "base": "main" } }\n' >"$d/nen/workflow.json"
  st_git -C "$d" commit -q -am noidentity
  git -C "$d" push -q origin HEAD:main 2>/dev/null; git -C "$d" fetch -q origin main
  st_run 3 "no tags.identity is exit 3: freshness not asserted, never fresh" --repo "$d"
  st_says "freshness:      unverified" "and says unverified"
  git -C "$st_tmp/origin.git" update-ref refs/heads/main "$st_sha"   # put origin back for the rest

  d="$(st_copy nosha)"; printf 'v1.2.3\n' >"$d/dist/identity.txt"
  st_run 2 "a nameFrom carrying no build SHA is refused" --repo "$d"

  d="$(st_copy nothex)"; printf 'v1.2.3\nHEAD\n' >"$d/dist/identity.txt"
  st_run 2 "a build SHA that is not raw lowercase hex is refused, never resolved" --repo "$d"

  d="$(st_copy sym)"; rm -f "$d/dist/identity.txt"; ln -s /etc/hosts "$d/dist/identity.txt"
  st_run 2 "a symlinked nameFrom is refused" --repo "$d"

  d="$(st_copy missing)"; rm -f "$d/dist/identity.txt"
  st_run 2 "an absent nameFrom is refused: no archive has run here" --repo "$d"
  st_says "no archive" "and says no archive has run"

  d="$(st_copy outside)"; printf 'v1\n%s\n' "$st_sha" >"$st_tmp/outside-identity.txt"
  printf '{ "branch": { "base": "main" }, "tags": { "identity": { "nameFrom": "../outside-identity.txt" } } }\n' >"$d/nen/workflow.json"
  st_git -C "$d" commit -q -am outside
  st_run 2 "a nameFrom resolving outside the repository is refused" --repo "$d"
  st_says "outside the repository" "and says so"

  d="$(st_copy shortsha)"; printf 'v1.2.3\n%s\n' "$(printf '%s' "$st_sha" | cut -c1-39)" >"$d/dist/identity.txt"
  st_run 2 "an abbreviated 39-character build SHA is refused" --repo "$d"

  d="$(st_copy unknownsha)"; printf 'v1.2.3\n0123456789abcdef0123456789abcdef01234567\n' >"$d/dist/identity.txt"
  st_run 2 "a 40-hex build SHA that is no commit here is refused" --repo "$d"
  st_says "not a commit" "and says so"

  d="$(st_copy badtags)"; printf '{ "branch": { "base": "main" }, "tags": [] }\n' >"$d/nen/workflow.json"
  st_git -C "$d" commit -q -am badtags
  st_run 2 "a malformed tags block is refused, never read as absent" --repo "$d"
  st_says "present but unreadable is not absent" "and says so"

  # --- 3. built SHA is not HEAD ------------------------------------------------------------------
  d="$(st_copy behind)"
  printf 'more\n' >>"$d/README"; st_git -C "$d" commit -q -am second
  st_run 2 "an archive built at a commit that is not HEAD is refused, both SHAs named" --repo "$d"
  st_says "is not the checkout's HEAD" "and says which"
  st_says "$st_sha" "and names the built SHA"

  # --- 4. built SHA is HEAD but the trunk moved on ------------------------------------------------
  d="$(st_copy stale)"
  git clone -q "$st_tmp/origin.git" "$st_tmp/other" 2>/dev/null
  printf 'newer\n' >>"$st_tmp/other/README"; st_git -C "$st_tmp/other" commit -q -am newer
  git -C "$st_tmp/other" push -q origin main
  st_run 2 "an archive at HEAD behind origin/<base>'s tip is refused, both SHAs named" --repo "$d"
  st_says "is not the tip of origin/main" "and says which"
  st_says "0 ahead, 1 behind" "and counts ahead and behind"
  git -C "$st_tmp/origin.git" update-ref refs/heads/main "$st_sha"

  # --- --base overrides branch.base, and a base that does not exist on origin refuses ------------
  st_run 2 "a --base that origin does not carry is refused, never assumed" --repo "$st_tmp/core" --base nope
  st_says "fetch" "and names the fetch"

  if [ "$st_fails" -eq 0 ]; then
    echo "send_freshness_check.sh --self-test: all assertions held; nothing was sent."
    return 0
  fi
  echo "send_freshness_check.sh --self-test: $st_fails assertion(s) failed" >&2
  return 1
}

# EVERY TWO-ARGUMENT FLAG IS GUARDED BEFORE IT SHIFTS TWICE (the dist_tag.sh lesson).
repo=""; base=""; self_test=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || { usage; exit 2; }; repo="$2"; shift 2 ;;
    --base) [ $# -ge 2 ] || { usage; exit 2; }; base="$2"; shift 2 ;;
    --self-test) self_test=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "send_freshness_check.sh: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done

if [ "$self_test" -eq 1 ]; then
  [ -z "$repo" ] && [ -z "$base" ] || { echo "send_freshness_check.sh: --self-test takes no other argument" >&2; exit 2; }
  self_test_main
  exit $?
fi

[ -n "$repo" ] || { usage; exit 2; }

root="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || { echo "send_freshness_check.sh: not a git repository: $repo" >&2; exit 2; }
wf="$root/nen/workflow.json"
[ -f "$wf" ] || { echo "send_freshness_check.sh: no $wf -- refused" >&2; exit 2; }

# THE TRUNK, read as data unless the caller named it.
if [ -z "$base" ]; then
  base="$(python3 -c 'import json,sys
b=json.load(open(sys.argv[1])).get("branch",{})
if not isinstance(b, dict): sys.exit("branch is not an object")
t=b.get("base","main")
if not isinstance(t, str) or not t: sys.exit("branch.base is not a non-empty string")
print(t)' "$wf")" || { echo "send_freshness_check.sh: branch.base unreadable -- refused" >&2; exit 2; }
fi
git -C "$root" check-ref-format --allow-onelevel "$base" \
  || { echo "send_freshness_check.sh: base is not a legal git ref name -- refused" >&2; exit 2; }

# 1. A CLEAN TREE, FIRST. An archive sent from a dirty tree is a binary no commit describes, and the
#    only refusal that used to catch it fired after the upload.
# CAPTURED, THEN TESTED: a `git status` that FAILS must never read as a clean tree (Nobunaga, 2026-09-30).
st="$(git -C "$root" status --porcelain)" || { echo "send_freshness_check.sh: git status failed in $root -- refused" >&2; exit 2; }
if [ -n "$st" ]; then
  echo "send_freshness_check.sh: the working tree is dirty -- refused before the send, not at the tag:" >&2
  printf '%s\n' "$st" | sed 's/^/    /' >&2
  exit 2
fi
head="$(git -C "$root" rev-parse HEAD)" || { echo "send_freshness_check.sh: no HEAD -- refused" >&2; exit 2; }

# 2. THE RECORD. Three outcomes: declared (read it), not declared (exit 3, said), malformed (refused).
nameFrom="$(python3 -c 'import json,sys
t=json.load(open(sys.argv[1])).get("tags")
if t is None: sys.exit(3)
if not isinstance(t, dict): sys.exit("tags is not an object")
i=t.get("identity")
if i is None: sys.exit(3)
if not isinstance(i, dict): sys.exit("tags.identity is not an object")
n=i.get("nameFrom")
if not isinstance(n, str) or not n: sys.exit("tags.identity.nameFrom is missing or is not a non-empty string")
print(n)' "$wf")"; rc=$?
case $rc in
  0) : ;;
  3)
    # The fetch still runs so the trunk line is real, and the tree line already held.
    git -C "$root" fetch -q origin "refs/heads/$base:refs/remotes/origin/$base" 2>/dev/null \
      || { echo "send_freshness_check.sh: git fetch origin $base failed -- refused, the trunk's tip is unknown" >&2; exit 2; }
    tip="$(git -C "$root" rev-parse --verify -q "refs/remotes/origin/$base")" \
      || { echo "send_freshness_check.sh: origin/$base does not resolve after the fetch -- refused" >&2; exit 2; }
    printf 'built:          unrecorded (no tags.identity declared)\n'
    printf 'head:           %s\n' "$head"
    printf 'origin/%s:    %s\n' "$base" "$tip"
    printf 'tree:           clean\n'
    printf 'freshness:      unverified -- this repository records no build SHA (nen/workflow.json -> tags.identity), so nothing here can say which commit the archive was built from\n'
    exit 3 ;;
  *) echo "send_freshness_check.sh: $wf could not be read for tags.identity -- present but unreadable is not absent; refused" >&2; exit 2 ;;
esac

file="$root/$nameFrom"
[ -L "$file" ] && { echo "send_freshness_check.sh: nameFrom is a symlink -- refused" >&2; exit 2; }
[ -f "$file" ] || { echo "send_freshness_check.sh: nameFrom '$nameFrom' is not a regular file -- no archive has run in this checkout; refused" >&2; exit 2; }
case "$(cd -P -- "$(dirname -- "$file")" && pwd -P)/" in
  "$root"/*) : ;;
  *) echo "send_freshness_check.sh: nameFrom resolves outside the repository -- refused" >&2; exit 2 ;;
esac
built="$(sed -n '2p' <"$file" | tr -d '\r')"
[ -n "$built" ] || { echo "send_freshness_check.sh: nameFrom carries no build SHA on line 2 -- refused rather than assuming HEAD" >&2; exit 2; }
case "$built" in
  *[!0-9a-f]* | "") echo "send_freshness_check.sh: the recorded build SHA is not raw lowercase hex -- refused" >&2; exit 2 ;;
esac
[ "${#built}" -eq 40 ] || { echo "send_freshness_check.sh: the recorded build SHA is not a full 40-character name -- refused" >&2; exit 2; }
git -C "$root" cat-file -e "${built}^{commit}" 2>/dev/null \
  || { echo "send_freshness_check.sh: the recorded build SHA is not a commit in this repository -- refused" >&2; exit 2; }

# 3. BUILT == HEAD. The archive and the send are separate invocations with a human decision between
#    them, so HEAD can move (susanoo § 5a); a send from a checkout that moved sends the wrong binary.
if [ "$built" != "$head" ]; then
  echo "send_freshness_check.sh: the archive was built from $built, which is not the checkout's HEAD $head -- refused; re-run the archive on this tree, or check out the built commit" >&2
  exit 2
fi

# 4. BUILT == origin/<base>'s TIP, after a fetch. A non-production upload is a release act: a build
#    that reaches testers matches a known commit at the trunk's tip, and a fetch that fails leaves
#    the tip unknown, which is a refusal and never a pass.
git -C "$root" fetch -q origin "refs/heads/$base:refs/remotes/origin/$base" 2>/dev/null \
  || { echo "send_freshness_check.sh: git fetch origin $base failed -- refused, the trunk's tip is unknown" >&2; exit 2; }
tip="$(git -C "$root" rev-parse "refs/remotes/origin/$base")" \
  || { echo "send_freshness_check.sh: origin/$base does not resolve after the fetch -- refused" >&2; exit 2; }
if [ "$built" != "$tip" ]; then
  lr="$(git -C "$root" rev-list --left-right --count "$built...$tip" 2>/dev/null || echo '? ?')"
  ahead="${lr%%[[:space:]]*}"; behind="${lr##*[[:space:]]}"
  echo "send_freshness_check.sh: the archive was built from $built, which is not the tip of origin/$base ($tip; the build is $ahead ahead, $behind behind) -- refused; catch the checkout up, re-run the archive, then send" >&2
  exit 2
fi

printf 'built:          %s\n' "$built"
printf 'head:           %s\n' "$head"
printf 'origin/%s:    %s\n' "$base" "$tip"
printf 'tree:           clean\n'
printf 'freshness:      fresh -- the archive was built from the checkout'"'"'s HEAD, which is the tip of origin/%s\n' "$base"
exit 0
