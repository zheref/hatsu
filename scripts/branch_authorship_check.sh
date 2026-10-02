#!/bin/sh
# branch_authorship_check.sh — does every commit this branch is about to send carry the run's own
# provenance? zheref/hatsu#170: a hanten reviewer's repro ran `git commit` in the branch's own
# checkout (author `t <a@b>`, eleven one-line files), the working copy read clean afterwards, and
# the post-review push sent it. Isolation was a convention in a prompt; nothing read the range.
#
#   scripts/branch_authorship_check.sh --repo <path> --base <ref>
#       [--require-agent <persona>]... [--trunk <ref>] [--allow-email <email>]... [--require-trailer <Key>]
#
# WHAT IT TESTS, per commit in <base>..HEAD (merges included). <base> is the OUTGOING range's base —
# the SHA `ls-remote` printed (or `@{upstream}`) on a published branch, `git merge-base
# origin/<base> HEAD` on a first publish — so commits already published are never re-judged.
#   1. PROVENANCE (--require-agent, the strong signal): the commit's `Hatsu-Agent:` trailer values
#      are present and every one is in the allowed set. The run writes `Hatsu-Agent:
#      <responsible-persona>`; a reviewer writes its own persona (_review-preamble § 9) or nothing,
#      and either is a finding. This survives a squash or a rebase, which a recorded-SHA list does
#      not. It cannot tell a commit that FORGES the run's own persona; hanten § 4's printed-HEAD
#      comparison is what catches a commit made during a review. With --trunk <ref>, a merge that
#      carries no trailer is exempt from this test only when every parent after the first is on
#      <ref> and its tree is exactly git's own clean merge (`git merge-tree --write-tree`) — the
#      commit `nen wc catch-up` writes for a clean base merge. A merge that adds anything is judged.
#      --trunk also drops every commit already on <ref> from the range: that history is the base's.
#      --trunk needs git >= 2.38 (`merge-tree --write-tree`); an older git is a wiring error, probed
#      once before anything is judged, never a silently judged merge.
#   2. IDENTITY (the weak signal): author AND committer email are in the allowed set — the
#      repository's `user.email` plus every --allow-email, case-insensitive. A subagent on the
#      maintainer's credentials shares that identity, so this catches only an explicit foreign one.
#   3. --require-trailer <Key>: the commit carries that trailer key with a non-empty value.
#
# exit 0  every commit in the range passes (an empty range is clean)
# exit 1  a finding: one line per failing commit on stdout — sha, author, committer, files changed
#         against the first parent, the reason, and the subject (untrusted commit text, non-printing
#         bytes shown as `?`) — and a summary on stderr. The caller stops; it never pushes past one.
# exit 2  a wiring error: no repository, an empty or unresolvable --base, an empty --allow-email,
#         a --require-trailer or --require-agent value that is not a plain token, no allowed
#         identity at all, --trunk on a git without `merge-tree --write-tree`, or an unknown
#         argument. Nothing was judged.
#
# Hatsu runs it from `$hatsu_root/scripts/` before aka's squash, before every post-review push
# (aka § 7, murasaki § 6) and at hanten § 4's return. It reads and never writes.
set -u

repo=''
base=''
allowed=''
trailer=''
agents=''
trunk=''

usage() {
  echo 'usage: branch_authorship_check.sh --repo <path> --base <ref> [--require-agent <persona>]... [--trunk <ref>] [--allow-email <email>]... [--require-trailer <Key>]' >&2
  exit 2
}
token_ok() { printf '%s' "$1" | grep -Eqx '[A-Za-z0-9][A-Za-z0-9-]*'; }
clean() { printf '%s' "$1" | LC_ALL=C sed 's/[^[:print:]]/?/g'; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || usage; repo="$2"; shift 2 ;;
    --base) [ $# -ge 2 ] || usage; base="$2"; shift 2 ;;
    --allow-email) [ $# -ge 2 ] || usage
      [ -n "$2" ] || { echo 'branch_authorship_check: --allow-email needs a non-empty address' >&2; exit 2; }
      allowed="${allowed}$(lower "$2")
"; shift 2 ;;
    --require-trailer) [ $# -ge 2 ] || usage
      token_ok "$2" || { echo "branch_authorship_check: --require-trailer must be a plain key ([A-Za-z0-9-]): $(clean "$2")" >&2; exit 2; }
      trailer="$2"; shift 2 ;;
    --require-agent) [ $# -ge 2 ] || usage
      token_ok "$2" || { echo "branch_authorship_check: --require-agent must be a plain persona name ([A-Za-z0-9-]): $(clean "$2")" >&2; exit 2; }
      agents="${agents}$(lower "$2")
"; shift 2 ;;
    --trunk) [ $# -ge 2 ] && [ -n "$2" ] || usage; trunk="$2"; shift 2 ;;
    *) echo "branch_authorship_check: unknown argument: $(clean "$1")" >&2; usage ;;
  esac
done

[ -n "$repo" ] && [ -n "$base" ] || usage
if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
  echo "branch_authorship_check: not a git repository: $(clean "$repo")" >&2
  exit 2
fi
if ! base_sha="$(git -C "$repo" rev-parse --verify --quiet "${base}^{commit}")"; then
  echo "branch_authorship_check: --base does not resolve to a commit: $(clean "$base")" >&2
  exit 2
fi
own="$(git -C "$repo" config user.email 2>/dev/null | tr '[:upper:]' '[:lower:]')"
[ -n "$own" ] && allowed="${allowed}${own}
"
if [ -z "$allowed" ]; then
  echo 'branch_authorship_check: no allowed identity: set user.email in the repository or pass --allow-email' >&2
  exit 2
fi

in_set() { # <set> <value>
  [ -n "$2" ] && printf '%s' "$1" | grep -Fqx -- "$(lower "$2")"
}

trunk_sha=''
if [ -n "$trunk" ] && ! trunk_sha="$(git -C "$repo" rev-parse --verify --quiet "${trunk}^{commit}")"; then
  echo "branch_authorship_check: --trunk does not resolve to a commit: $(clean "$trunk")" >&2
  exit 2
fi
if [ -n "$trunk_sha" ] && ! git -C "$repo" merge-tree --write-tree "$trunk_sha" "$trunk_sha" >/dev/null 2>&1; then
  echo "branch_authorship_check: --trunk needs git >= 2.38 (merge-tree --write-tree); this is $(clean "$(git --version)")" >&2
  exit 2
fi
clean_trunk_merge() { # <sha>: a merge of the trunk whose tree is git's own clean merge
  [ -n "$trunk_sha" ] || return 1
  parents="$(git -C "$repo" log -1 --format=%P "$1")"; set -- $parents
  [ $# -ge 2 ] || return 1
  first="$1"; shift
  for p in "$@"; do git -C "$repo" merge-base --is-ancestor "$p" "$trunk_sha" || return 1; done
  [ $# -eq 1 ] || return 1
  want="$(git -C "$repo" merge-tree --write-tree "$first" "$1" 2>/dev/null)" || return 1
  [ "$want" = "$(git -C "$repo" rev-parse "${sha}^{tree}")" ]
}

# A commit already on the trunk is the base's history, not the run's: a catch-up merge brings it in.
if ! shas="$(git -C "$repo" rev-list HEAD "^${base_sha}" ${trunk_sha:+"^${trunk_sha}"})"; then
  echo "branch_authorship_check: could not list $(clean "$base")..HEAD${trunk:+ less $(clean "$trunk")}" >&2
  exit 2
fi

found=0
total=0
for sha in $shas; do
  total=$((total + 1))
  ae="$(git -C "$repo" log -1 --format='%ae' "$sha")"
  ce="$(git -C "$repo" log -1 --format='%ce' "$sha")"
  reason=''
  in_set "$allowed" "$ae" || reason="author"
  in_set "$allowed" "$ce" || reason="${reason:+$reason+}committer"
  if [ -n "$agents" ]; then
    vals="$(git -C "$repo" log -1 --format='%(trailers:key=Hatsu-Agent,valueonly,separator=%x0a)' "$sha" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep . || true)"
    if [ -z "$vals" ]; then
      clean_trunk_merge "$sha" || reason="${reason:+$reason+}no Hatsu-Agent trailer"
    else
      bad="$(printf '%s\n' "$vals" | while IFS= read -r v; do in_set "$agents" "$v" || printf '%s ' "$v"; done)"
      [ -z "$bad" ] || reason="${reason:+$reason+}Hatsu-Agent: $(clean "$bad")"
    fi
  fi
  if [ -n "$trailer" ]; then
    has="$(git -C "$repo" log -1 --format="%(trailers:key=${trailer},valueonly)" "$sha" | tr -d '[:space:]')"
    [ -n "$has" ] || reason="${reason:+$reason+}no ${trailer} trailer"
  fi
  if [ -n "$reason" ]; then
    found=$((found + 1))
    if git -C "$repo" rev-parse --verify --quiet "${sha}^1" >/dev/null; then
      files="$(git -C "$repo" diff --name-only "${sha}^1" "$sha" | grep -c . || true)"
    else
      files="$(git -C "$repo" diff-tree --root --no-commit-id --name-only -r "$sha" | grep -c . || true)"
    fi
    printf '%s  author=%s  committer=%s  files=%s  (%s)  subject (untrusted): %s\n' \
      "$(git -C "$repo" rev-parse --short "$sha")" \
      "$(clean "$(git -C "$repo" log -1 --format='%an <%ae>' "$sha")")" "$(clean "$ce")" "$files" "$reason" \
      "$(clean "$(git -C "$repo" log -1 --format='%s' "$sha")")"
  fi
done

if [ "$found" -gt 0 ]; then
  echo "branch_authorship_check: ${found} of ${total} commit(s) in the outgoing range fail provenance; stop before any push and report them" >&2
  exit 1
fi
echo "branch_authorship_check: ${total} commit(s) in the outgoing range, all with the run's provenance"
exit 0
