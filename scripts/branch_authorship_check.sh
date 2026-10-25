#!/bin/sh
# branch_authorship_check.sh — does every commit this branch is about to send carry the run's own
# provenance? zheref/hatsu#170: a hanten reviewer's repro ran `git commit` in the branch's own
# checkout (author `t <a@b>`, eleven one-line files), the working copy read clean afterwards, and
# the post-review push sent it. Isolation was a convention in a prompt; nothing read the range.
#
#   scripts/branch_authorship_check.sh --repo <path> --base <ref>
#       [--require-agent <persona>]... [--trunk <ref>] [--allow-email <email>]... [--require-trailer <Key>]
#       [--forbid-trailers-from <workflow.json>] [--forbidden-only]
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
#      once before anything is judged by reading `git merge-tree -h`, which writes nothing, never a
#      silently judged merge (zheref/hatsu#314). The proof runs only for a trailer-less merge whose
#      exemption must be proved, and it writes its merged tree into a THROWAWAY object directory
#      (GIT_OBJECT_DIRECTORY at "${TMPDIR:-/tmp}/hatsu-proof.XXXXXX", the repository's own objects
#      read as its alternate, removed on exit), so it adds no object to the repository's store and
#      needs no grant there: git may refresh the mtime of an object the store already holds, and
#      where that is refused the tree is written to the throwaway directory instead. The proof runs
#      with GIT_NO_LAZY_FETCH=1, so a partial clone missing a blob it needs fails rather than
#      fetching from the promisor remote on the caller's credentials — on git >= 2.44; an older
#      git ignores the variable and may still fetch. Where git still cannot prove it (exit other
#      than 0 clean or 1 conflicted — unrelated histories, a shallow clone, a partial clone that
#      would need a fetch, a signal — or exit 0 with no tree id), that is a probe failure at exit 2
#      naming the commit, git's exit and its sanitised text — never a version diagnosis, never a
#      finding, never a pass.
#   Every git read judges the objects as stored, which are the ones a push sends:
#   GIT_NO_REPLACE_OBJECTS=1 ignores refs/replace (a replaced evil merge would otherwise be read as
#   the clean one it is replaced by) and GIT_GRAFT_FILE names a path that cannot exist, so
#   info/grafts cannot rewrite a commit's parents to skip or launder one. A shallow clone's
#   boundary is not a graft and stays; the proof fails on it as above.
#   2. IDENTITY (the weak signal): author AND committer email are in the allowed set — the
#      repository's `user.email` plus every --allow-email, case-insensitive. A subagent on the
#      maintainer's credentials shares that identity, so this catches only an explicit foreign one.
#   3. --require-trailer <Key>: the commit carries that trailer key with a non-empty value.
#   4. --forbid-trailers-from: no commit carries a key named by commits.forbiddenTrailers.
#      --forbidden-only selects this check without the local identity/provenance checks for CI.
#
# exit 0  every commit in the range passes (an empty range is clean)
# exit 1  a finding: one line per failing commit on stdout — sha, author, committer, files changed
#         against the first parent, the reason, and the subject (untrusted commit text, non-printing
#         bytes shown as `?`) — and a summary on stderr. The caller stops; it never pushes past one.
# exit 2  a wiring error: no repository, an empty or unresolvable --base, an empty --allow-email,
#         a --require-trailer or --require-agent value that is not a plain token, no allowed
#         identity at all, --trunk on a git without `merge-tree --write-tree`, a merge-tree proof
#         git could not complete (a partial clone that would need a fetch among them), no
#         throwaway object directory under "${TMPDIR:-/tmp}", or an unknown argument. Nothing
#         was judged: no finding line is printed.
#
# Hatsu runs it from `$hatsu_root/scripts/` before aka's squash, before every post-review push
# (aka § 7, murasaki § 6) and at hanten § 4's return. It never writes the repository: no ref, no
# index, no working file, and it adds no object to its store (git may refresh the mtime of an object
# the store already holds; where that is refused the tree is written to the throwaway directory).
# Its only write is the merge proof's tree, into a throwaway object directory under
# "${TMPDIR:-/tmp}" that is removed on exit.
set -u
# Judge the objects as stored, which are the ones a push sends: no replace refs, no grafts
# (zheref/hatsu#314 round 2). A path under /dev/null can never exist, so no graft file is read.
GIT_NO_REPLACE_OBJECTS=1
GIT_GRAFT_FILE=/dev/null/no-grafts
export GIT_NO_REPLACE_OBJECTS GIT_GRAFT_FILE
proof_dir=''
proof_root=''
trap '[ -z "$proof_dir" ] || rm -rf "$proof_dir"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

repo=''
base=''
allowed=''
trailer=''
agents=''
trunk=''
forbidden_config=''
forbidden_only=0

usage() {
  echo 'usage: branch_authorship_check.sh --repo <path> --base <ref> [--require-agent <persona>]... [--trunk <ref>] [--allow-email <email>]... [--require-trailer <Key>] [--forbid-trailers-from <workflow.json>] [--forbidden-only]' >&2
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
    --forbid-trailers-from) [ $# -ge 2 ] && [ -n "$2" ] || usage; forbidden_config="$2"; shift 2 ;;
    --forbidden-only) forbidden_only=1; shift ;;
    *) echo "branch_authorship_check: unknown argument: $(clean "$1")" >&2; usage ;;
  esac
done

[ -n "$repo" ] && [ -n "$base" ] || usage
[ "$forbidden_only" -eq 0 ] || { [ -n "$forbidden_config" ] && [ -z "$agents" ] && [ -z "$trailer" ] && [ -z "$allowed" ] || usage; }
if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
  echo "branch_authorship_check: not a git repository: $(clean "$repo")" >&2
  exit 2
fi
if ! base_sha="$(git -C "$repo" rev-parse --verify --quiet "${base}^{commit}")"; then
  echo "branch_authorship_check: --base does not resolve to a commit: $(clean "$base")" >&2
  exit 2
fi
if [ "$forbidden_only" -eq 0 ]; then
  own="$(git -C "$repo" config user.email 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  [ -n "$own" ] && allowed="${allowed}${own}
"
  if [ -z "$allowed" ]; then
    echo 'branch_authorship_check: no allowed identity: set user.email in the repository or pass --allow-email' >&2
    exit 2
  fi
fi
forbidden=''
# Read as UTF-8 whatever the locale: under LC_ALL=C Ruby tags the file US-ASCII and JSON.parse raises on
# the first non-ASCII byte, which made every combined-mode run exit 2 (zheref/hatsu#470).
if [ -n "$forbidden_config" ]; then
  [ -f "$forbidden_config" ] || { echo 'branch_authorship_check: forbidden trailer config is missing' >&2; exit 2; }
  forbidden="$(ruby -rjson -e 'v=JSON.parse(File.read(ARGV.fetch(0), encoding: "UTF-8")).dig("commits", "forbiddenTrailers"); abort "forbiddenTrailers must be a non-empty key array" unless v.is_a?(Array) && !v.empty? && v.all? { |k| k.is_a?(String) && k.match?(/\A[A-Za-z0-9][A-Za-z0-9-]*\z/) }; puts v.map(&:downcase).uniq' "$forbidden_config")" || exit 2
fi

in_set() { # <set> <value>
  [ -n "$2" ] && printf '%s' "$1" | grep -Fqx -- "$(lower "$2")"
}

trunk_sha=''
if [ -n "$trunk" ] && ! trunk_sha="$(git -C "$repo" rev-parse --verify --quiet "${trunk}^{commit}")"; then
  echo "branch_authorship_check: --trunk does not resolve to a commit: $(clean "$trunk")" >&2
  exit 2
fi
# A capability read, not a write: `-h` lists --write-tree on every git that has it (zheref/hatsu#314).
if [ -n "$trunk_sha" ] && ! git -C "$repo" merge-tree -h 2>&1 | grep -Fq -- '--write-tree'; then
  echo "branch_authorship_check: --trunk needs git >= 2.38 (merge-tree --write-tree); this is $(clean "$(git --version)")" >&2
  exit 2
fi
proof_fail() { # <commit> <detail> <stderr file>: a proof git could not complete — exit 2, nothing judged
  said="$(head -n 3 "$3" 2>/dev/null | tr '\n' ' ')"
  quoted="$(clean "$said" | cut -c1-300)"
  echo "branch_authorship_check: the clean trunk-merge proof for $(git -C "$repo" rev-parse --short "$1") did not complete: $2; nothing was judged" >&2
  [ -z "$quoted" ] || echo "branch_authorship_check: git said (untrusted): $quoted" >&2
  # Advice only when its trigger is in the quoted text the reader can see (SEC-15).
  if printf '%s' "$quoted" | grep -Eiq 'permission denied|operation not permitted|insufficient permission'; then
    echo "branch_authorship_check: git's own text reports a permission refusal; the proof writes only into a throwaway directory under $(clean "${proof_root:-/}") and reads the repository, so that is where access is refused. Do not replace git: grant it through the harness's normal approval path" >&2
  fi
  exit 2
}
# Call it in the main shell, never inside $(...) or a pipeline: its `exit 2` must end the script.
clean_trunk_merge() { # <commit>: a merge of the trunk whose tree is git's own clean merge
  [ -n "$trunk_sha" ] || return 1
  ctm_commit="$1"
  ctm_parents="$(git -C "$repo" log -1 --format=%P "$ctm_commit")"; set -- $ctm_parents
  [ $# -ge 2 ] || return 1
  ctm_first="$1"; shift
  for ctm_p in "$@"; do git -C "$repo" merge-base --is-ancestor "$ctm_p" "$trunk_sha" || return 1; done
  [ $# -eq 1 ] || return 1
  # The proof's tree goes into a throwaway object directory that reads the repository's objects as
  # its alternate, so the repository's store is never written (zheref/hatsu#314).
  if [ -z "$proof_dir" ]; then
    # A template, so macOS honours TMPDIR (bare `mktemp -d` uses the per-user confstr directory);
    # absolute, because GIT_OBJECT_DIRECTORY is read relative to the repository, not to here.
    proof_root="${TMPDIR:-/tmp}"; proof_root="${proof_root%/}"
    case "$proof_root" in /*|'') ;; *) proof_root="$(pwd -P)/$proof_root" ;; esac
    proof_dir="$(mktemp -d "${proof_root}/hatsu-proof.XXXXXX" 2>/dev/null)"
    [ -n "$proof_dir" ] && [ -d "$proof_dir" ] && mkdir -p "$proof_dir/objects/info" \
      && git -C "$repo" rev-parse --path-format=absolute --git-path objects > "$proof_dir/objects/info/alternates" \
      || { echo "branch_authorship_check: could not set up a throwaway object directory for the merge proof under $(clean "${proof_root:-/}"); nothing was judged" >&2; exit 2; }
  fi
  # stdout and stderr apart: the tree id is read from stdout's first line only; stderr is quoted.
  # No lazy fetch (git >= 2.44): a partial clone missing a blob fails closed, offline (SEC-9).
  GIT_NO_LAZY_FETCH=1 GIT_OBJECT_DIRECTORY="$proof_dir/objects" git -C "$repo" merge-tree --write-tree "$ctm_first" "$1" \
    > "$proof_dir/out" 2> "$proof_dir/err"; rc=$?
  # 1 is a conflict: not clean, so the merge is judged. Anything else but 0 is no verdict.
  [ "$rc" -eq 1 ] && return 1
  [ "$rc" -eq 0 ] || proof_fail "$ctm_commit" "git merge-tree --write-tree exited $rc, which is neither clean (0) nor conflicted (1)" "$proof_dir/err"
  want="$(head -n 1 "$proof_dir/out")"
  printf '%s\n' "$want" | grep -Eqx '[0-9a-f]{40}|[0-9a-f]{64}' \
    || proof_fail "$ctm_commit" "git merge-tree --write-tree exited 0 but produced no proof (no tree id on its first line of output)" "$proof_dir/err"
  [ "$want" = "$(git -C "$repo" rev-parse "${ctm_commit}^{tree}")" ]
}

# A commit already on the trunk is the base's history, not the run's: a catch-up merge brings it in.
if ! shas="$(git -C "$repo" rev-list HEAD "^${base_sha}" ${trunk_sha:+"^${trunk_sha}"})"; then
  echo "branch_authorship_check: could not list $(clean "$base")..HEAD${trunk:+ less $(clean "$trunk")}" >&2
  exit 2
fi

found=0
total=0
findings=''
for sha in $shas; do
  total=$((total + 1))
  ae="$(git -C "$repo" log -1 --format='%ae' "$sha")"
  ce="$(git -C "$repo" log -1 --format='%ce' "$sha")"
  reason=''
  if [ "$forbidden_only" -eq 0 ]; then
    in_set "$allowed" "$ae" || reason="author"
    in_set "$allowed" "$ce" || reason="${reason:+$reason+}committer"
  fi
  if [ -n "$forbidden" ]; then
    # The canon forbids these keys anywhere in the message, including a body
    # line before later prose that git interpret-trailers does not parse.
    keys="$(git -C "$repo" log -1 --format=%B "$sha" | sed -n 's/^[[:space:]]*\([A-Za-z0-9][A-Za-z0-9-]*\)[[:space:]]*:.*/\1/p' | tr '[:upper:]' '[:lower:]')"
    for key in $keys; do
      in_set "$forbidden" "$key" || continue
      reason="${reason:+$reason+}forbidden trailer $key"
    done
  fi
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
    # Held until the range is through: a probe failure later in it exits 2 with no finding printed.
    findings="${findings}$(printf '%s  author=%s  committer=%s  files=%s  (%s)  subject (untrusted): %s' \
      "$(git -C "$repo" rev-parse --short "$sha")" \
      "$(clean "$(git -C "$repo" log -1 --format='%an <%ae>' "$sha")")" "$(clean "$ce")" "$files" "$reason" \
      "$(clean "$(git -C "$repo" log -1 --format='%s' "$sha")")")
"
  fi
done

if [ "$found" -gt 0 ]; then
  printf '%s' "$findings"
  echo "branch_authorship_check: ${found} of ${total} commit(s) in the outgoing range fail provenance or trailer policy; stop before any push and report them" >&2
  exit 1
fi
echo "branch_authorship_check: ${total} commit(s) in the outgoing range, all with the run's provenance"
exit 0
