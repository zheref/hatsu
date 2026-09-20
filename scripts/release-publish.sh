#!/usr/bin/env bash
# release-publish.sh — publish ONE GitHub Release for a tag that already exists.
#
# RENDERED BY hatsu:tenkai from `templates/release-publish.sh`. Hatsu's own copy
# is a rendering of this same file, so the engine a consumer receives is the
# engine Hatsu runs on itself.
#
# WHY THIS EXISTS. `nen shu release` runs whatever the target repository declares
# under `project.verbs.<lane>.release`. A repository that declares a SEAT there
# has told nen there is nothing to run — so `hatsu:mugetsu`, whose entire job is
# to execute that row at G3, has nothing to execute, and publication happens by
# hand, outside the machinery, or not at all. `zheref/hatsu` lived in exactly
# that state: its seat read "nothing in this repository publishes one" while a
# GitHub Release was being published by hand at v0.39.0. A declaration that
# disagrees with the practice is a bug in the declaration, so this script is the
# row's argv and the seat is retired.
#
# WHAT IT PUBLISHES, AND WHAT IT DOES NOT. It creates a GitHub Release for a tag
# that ALREADY RESOLVES on the remote. It does not cut tags — that is
# `hatsu:getsuga` § 4 and `nen tag cut` — it does not push, it does not build,
# and it attaches only artifacts it was handed. The tag is the input, never the
# output.
#
# KIND-AWARENESS, AND ITS LIMIT. The notes and the title come from the
# repository's own CHANGELOG.md, which every declared stack has; assets come
# only from `--asset`, which the lane's own `archive` (hatsu:susanoo) produces.
# So one engine serves a `claude-code-plugin` — distributed by git ref through a
# marketplace, where the tag IS the distribution and there is no artifact — and a
# stack that does build one, without this script knowing either stack's name.
# **It never invents an artifact and never guesses a build.**
#
# USAGE
#   release-publish.sh [--tag <vX.Y.Z>] [--repo <path>] [--slug <owner/name>]
#                      [--changelog <path>] [--previous-tag <vX.Y.Z>]
#                      [--asset <path>]... [--title <text>]
#                      [--dry-run] [--json]
#
# `--tag` IS OPTIONAL, and deliberately so: `nen shu release` runs the declared
# argv with no arguments, so a row whose script required one could never be run
# by the verb that exists to run it. Omitted, it is the newest `v*` by version
# sort, NAMED as `(DERIVED)` in every output.
#   release-publish.sh --self-test
#
# EXIT CODES
#   0  published (or, with --dry-run, the plan printed and nothing sent)
#   1  a precondition refused — named, never worked around
#   2  an invocation or environment defect
#
# THE REFUSALS ARE THE POINT. Publication is G3 and it is not idempotent in any
# way a caller can rely on: a GitHub Release notifies watchers the moment it
# exists. So every one of these refuses BEFORE anything is sent:
#   * no `gh`, or no usable token                -> 2
#   * the tag does not resolve LOCALLY           -> 1
#   * --tag omitted AND no `v*` tag exists       -> 1  (it publishes a tag; it
#     never creates one)
#   * the tag does not resolve ON THE REMOTE     -> 1  (a local-only tag would
#     publish a release pointing at a ref nobody else can fetch)
#   * a release ALREADY exists for that tag      -> 1  (one go publishes one
#     target once; re-publishing is never the fix)
#   * an --asset path that does not exist        -> 1
#   * no `python3`                               -> 2  (it composes the notes)
#   * no section for the tag in the changelog    -> 1  (the notes are the
#     changelog's; this script does not write them)
set -euo pipefail

TAG=""; REPO="."; SLUG=""; CHANGELOG=""; PREV=""; TITLE=""; DRY=0; JSON=0
ASSETS=()

die()    { printf 'release-publish: %s\n' "$1" >&2; exit "${2:-2}"; }
refuse() { printf 'release-publish: %s\n' "$1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --tag)           TAG="${2:-}"; shift 2 ;;
    --repo)          REPO="${2:-}"; shift 2 ;;
    --slug)          SLUG="${2:-}"; shift 2 ;;
    --changelog)     CHANGELOG="${2:-}"; shift 2 ;;
    --previous-tag)  PREV="${2:-}"; shift 2 ;;
    --title)         TITLE="${2:-}"; shift 2 ;;
    --asset)         ASSETS+=("${2:-}"); shift 2 ;;
    --dry-run)       DRY=1; shift ;;
    --json)          JSON=1; shift ;;
    --self-test)     SELF_TEST=1; shift ;;
    *) die "unexpected argument '$1'" ;;
  esac
done

# --------------------------------------------------------------------------
# self-test — hermetic, offline, and it publishes nothing, ever
# --------------------------------------------------------------------------
if [ "${SELF_TEST:-0}" = "1" ]; then
  fails=0; ran=0
  ok() {
    ran=$((ran+1))
    if [ "$1" = "0" ]; then printf '  ok    %s\n' "$2"
    else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi
  }
  T="$(mktemp -d)"
  trap 'rm -rf "$T"' EXIT
  ( cd "$T" && git init -q && git remote add origin https://github.com/acme/widget.git )
  printf 'x\n' > "$T/f"
  ( cd "$T" && git add f && git -c user.email=a@b -c user.name=t commit -qm "chore: seed" && git tag v2.0.0 && git tag v1.0.0 )
  cat > "$T/CHANGELOG.md" <<'CL'
# Changelog

## v2.0.0 — the new one

- a thing that landed
- another thing

## v1.0.0 — the old one

- ancient history
CL

  echo "notes composition — the changelog's, never this script's"
  N="$(SELF_TEST=0 bash "$0" --tag v2.0.0 --repo "$T" --slug acme/widget \
        --changelog "$T/CHANGELOG.md" --previous-tag v1.0.0 --dry-run 2>/dev/null || true)"
  case "$N" in *"would publish"*) ok 0 "--dry-run prints a plan and sends nothing" ;; *) ok 1 "--dry-run prints a plan and sends nothing" ;; esac
  case "$N" in *"acme/widget"*) ok 0 "the plan names the repository" ;; *) ok 1 "the plan names the repository" ;; esac
  case "$N" in *"v2.0.0"*) ok 0 "the plan names the tag" ;; *) ok 1 "the plan names the tag" ;; esac
  case "$N" in *"gh release create"*) ok 0 "the plan shows the exact command" ;; *) ok 1 "the plan shows the exact command" ;; esac
  case "$N" in *"1 section"*) ok 0 "one section between v2.0.0 and v1.0.0" ;; *) ok 1 "one section between v2.0.0 and v1.0.0" ;; esac

  echo "a tag that closes a MULTI-version gap carries every section in it"
  M="$(SELF_TEST=0 bash "$0" --tag v2.0.0 --repo "$T" --slug acme/widget \
        --changelog "$T/CHANGELOG.md" --previous-tag v0.1.0 --dry-run 2>/dev/null || true)"
  case "$M" in *"2 section"*) ok 0 "both sections when the previous tag is older" ;; *) ok 1 "both sections when the previous tag is older" ;; esac

  echo "an OLDER target — the backfill case"
  B="$(SELF_TEST=0 bash "$0" --tag v1.0.0 --repo "$T" --slug acme/widget \
        --changelog "$T/CHANGELOG.md" --dry-run 2>/dev/null || true)"
  case "$B" in *"previous   : (none"*) ok 0 "an older target derives the tag BELOW it, not the newest" ;;
    *"previous   : v2.0.0"*) ok 1 "an older target derives the tag BELOW it, not the newest" ;;
    *) ok 0 "an older target derives the tag BELOW it, not the newest" ;; esac
  case "$B" in *"1 section"*) ok 0 "and carries only its own section, not every older one" ;; *) ok 1 "and carries only its own section, not every older one" ;; esac
  case "$B" in *"latest     : NO"*) ok 0 "--latest is WITHHELD for an older tag — the pointer never moves backwards" ;; *) ok 1 "--latest is WITHHELD for an older tag — the pointer never moves backwards" ;; esac
  case "$B" in *"--verify-tag --latest"*) ok 1 "and the printed command omits --latest" ;; *) ok 0 "and the printed command omits --latest" ;; esac
  case "$N" in *"latest     : yes"*) ok 0 "--latest IS passed for the newest tag" ;; *) ok 1 "--latest IS passed for the newest tag" ;; esac

  echo "refusals — each BEFORE anything is sent"
  set +e
  D="$(SELF_TEST=0 bash "$0" --repo "$T" --slug acme/widget --changelog "$T/CHANGELOG.md" --dry-run 2>/dev/null || true)"
  case "$D" in *"v2.0.0 (DERIVED"*) ok 0 "an omitted --tag derives the newest v* AND says so" ;; *) ok 1 "an omitted --tag derives the newest v* AND says so" ;; esac
  E="$(cd "$T" && mktemp -d)"; ( cd "$E" && git init -q )
  SELF_TEST=0 bash "$0" --repo "$E" --slug a/b --dry-run >/dev/null 2>&1
  ok "$([ $? -eq 1 ] && echo 0 || echo 1)" "no tags at all refuses (1) — it publishes a tag, never creates one"
  SELF_TEST=0 bash "$0" --tag v9.9.9 --repo "$T" --slug acme/widget --changelog "$T/CHANGELOG.md" --dry-run >/dev/null 2>&1
  ok "$([ $? -eq 1 ] && echo 0 || echo 1)" "a tag that does not resolve locally refuses (1)"
  SELF_TEST=0 bash "$0" --tag v2.0.0 --repo "$T" --slug acme/widget --changelog "$T/nope.md" --dry-run >/dev/null 2>&1
  ok "$([ $? -eq 1 ] && echo 0 || echo 1)" "an unreadable --changelog refuses (1)"
  SELF_TEST=0 bash "$0" --tag v1.0.0 --repo "$T" --slug acme/widget --changelog "$T/CHANGELOG.md" --asset "$T/absent.zip" --dry-run >/dev/null 2>&1
  ok "$([ $? -eq 1 ] && echo 0 || echo 1)" "an --asset that does not exist refuses (1)"
  printf '# Changelog\n\n## v1.0.0 — only this\n\n- x\n' > "$T/partial.md"
  SELF_TEST=0 bash "$0" --tag v2.0.0 --repo "$T" --slug acme/widget --changelog "$T/partial.md" --dry-run >/dev/null 2>&1
  ok "$([ $? -eq 1 ] && echo 0 || echo 1)" "no section for the tag refuses (1) — notes are never invented"
  set -e

  echo "the shipped copy and the template it was cut from cannot drift silently"
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  TEMPLATE_COPY="$SCRIPT_DIR/../templates/release-publish.sh"
  if [ -f "$TEMPLATE_COPY" ]; then
    if cmp -s "$TEMPLATE_COPY" "$0"; then
      ok 0 "templates/release-publish.sh matches scripts/release-publish.sh byte-for-byte"
    else
      ok 1 "templates/release-publish.sh matches scripts/release-publish.sh byte-for-byte"
    fi
  else
    ok 1 "templates/release-publish.sh exists to compare against"
  fi

  printf '\n'
  if [ "$fails" -gt 0 ]; then
    printf 'release-publish --self-test: %s FAILED of %s\n' "$fails" "$ran"
    exit 1
  fi
  printf 'release-publish --self-test: all green (%s assertions)\n' "$ran"
  exit 0
fi

# --------------------------------------------------------------------------
[ -d "$REPO" ] || die "--repo '$REPO' is not a directory"
command -v git >/dev/null 2>&1 || die "no 'git' on PATH"
# python3 composes the notes and the title. Unvalidated, a missing interpreter
# made the heredoc exit 127, which was then folded into the generic "no section"
# refusal and reported as exit 1 -- a repository defect dressed as a changelog
# one. An absent interpreter is an ENVIRONMENT defect and exits 2.
command -v python3 >/dev/null 2>&1 || die "no 'python3' on PATH — it composes the notes and the title from the changelog"

# --tag IS OPTIONAL, AND THAT IS WHAT MAKES THE DECLARED ROW RUNNABLE.
# `nen shu release` runs the lane's argv with no arguments of its own -- it has
# no --tag to pass -- so a row whose script REQUIRED one could never be executed
# by the verb that exists to execute it. Omitted, the tag is the newest `v*` by
# version sort, and it is NAMED in every output so nobody has to infer which tag
# was chosen. The refusals below still gate it: the tag must resolve locally and
# on the remote, and a tag that already has a release is refused outright.
if [ -z "$TAG" ]; then
  TAG="$( ( cd "$REPO" && git tag --list 'v*' --sort=-v:refname ) | head -1 || true )"
  [ -n "$TAG" ] || refuse "no --tag was given and this repository has no 'v*' tag to derive one from. Cut one first ('nen tag cut'); this script publishes a tag, it does not create one."
  DERIVED_TAG=1
fi

# THE TAG IS THE INPUT. It must resolve locally AND on the remote: a local-only
# tag would publish a release pointing at a ref nobody else can fetch.
if ! ( cd "$REPO" && git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1 ); then
  refuse "tag '$TAG' does not resolve in $REPO. This script publishes a tag that already exists; cutting one is 'nen tag cut' (hatsu:getsuga § 4)."
fi

if [ -z "$SLUG" ]; then
  SLUG="$( ( cd "$REPO" && git remote get-url origin 2>/dev/null ) \
    | sed -E 's#(\.git)?$##; s#^.*[:/]([^/:]+/[^/]+)$#\1#' )"
fi
[ -n "$SLUG" ] || die "could not derive <owner/name> from origin; pass --slug"

[ -n "$CHANGELOG" ] || CHANGELOG="$REPO/CHANGELOG.md"
[ -r "$CHANGELOG" ] || refuse "changelog '$CHANGELOG' is not readable. Release notes are composed from it; this script does not invent them."

if [ -z "$PREV" ]; then
  # THE TAG IMMEDIATELY BELOW THE TARGET, not merely the newest other tag.
  # Taking the newest was wrong for any backfill or older target: publishing
  # v1.0.0 while v2.0.0 exists derived PREV=v2.0.0, the notes walk never reached
  # that newer tag after the target, and the release silently carried every older
  # section instead of the one interval it names. Descending version order, then
  # the first entry strictly BELOW the target.
  PREV="$( ( cd "$REPO" && git tag --list 'v*' --sort=-v:refname ) \
    | awk -v t="$TAG" 'BEGIN{seen=0} $0==t{seen=1;next} seen==1{print;exit}' )"
fi

# --latest IS CONDITIONAL, because it moves a pointer. Passing it for a backfill
# or an older tag would move GitHub's "Latest release" BACKWARDS -- a published,
# outward-facing regression that no later run undoes. It is passed only when the
# target IS the newest `v*` this repository has.
NEWEST="$( ( cd "$REPO" && git tag --list 'v*' --sort=-v:refname ) | head -1 || true )"
if [ "$TAG" = "$NEWEST" ]; then
  LATEST_FLAG=" --latest"; LATEST_WHY="yes — '$TAG' is the newest v* tag"
else
  LATEST_FLAG=""; LATEST_WHY="NO — '$TAG' is older than '$NEWEST'; --latest would move the pointer backwards"
fi

for a in ${ASSETS+"${ASSETS[@]}"}; do
  [ -f "$a" ] || refuse "--asset '$a' does not exist. An artifact is produced by the lane's own 'archive' (hatsu:susanoo), never by this script."
done

# NOTES: every section from this tag down to (but excluding) the previous one.
# A tag that closes a multi-version gap carries every section in that gap —
# silently shipping only the newest would misreport what the tag contains.
NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
set +e
python3 - "$CHANGELOG" "$TAG" "${PREV:-}" > "$NOTES_FILE" <<'PY'
import re, sys
text, tag = open(sys.argv[1]).read(), sys.argv[2]
prev = sys.argv[3] if len(sys.argv) > 3 else ""
secs = re.split(r"(?m)^## ", text)[1:]
out, seen = [], False
for s in secs:
    ver = s.split("\n")[0].split(" ")[0].strip()
    if prev and ver == prev and seen:
        break
    if ver == tag:
        seen = True
    if seen:
        out.append("## " + s.rstrip() + "\n")
if not out:
    raise SystemExit(3)
sys.stdout.write("\n".join(out))
PY
notes_rc=$?
set -e
[ "$notes_rc" -eq 0 ] || refuse "no '## $TAG' section in '$CHANGELOG'. The notes are the changelog's; this script does not write them."

if [ -z "$TITLE" ]; then
  TITLE="$(python3 - "$CHANGELOG" "$TAG" <<'PY'
import re, sys
t = open(sys.argv[1]).read(); tag = sys.argv[2]
m = re.search(rf"(?m)^## {re.escape(tag)}\b(.*)$", t)
print(f"{tag}{m.group(1)}" if m else tag)
PY
)"
fi

if [ "$DRY" = "1" ]; then
  printf 'would publish:\n'
  printf '  repository : %s\n' "$SLUG"
  printf '  tag        : %s%s\n' "$TAG" "$([ "${DERIVED_TAG:-0}" = 1 ] && printf ' (DERIVED — newest v* tag; no --tag was given)')"
  printf '  previous   : %s\n' "${PREV:-(none - first release)}"
  printf '  title      : %s\n' "$TITLE"
  printf '  notes      : %s bytes, %s section(s) from %s\n' \
    "$(wc -c < "$NOTES_FILE" | tr -d ' ')" "$(grep -c '^## ' "$NOTES_FILE" || true)" "$CHANGELOG"
  printf '  assets     : %s\n' "${#ASSETS[@]}"
  printf '  command    : gh release create %s --repo %s --verify-tag%s\n' "$TAG" "$SLUG" "$LATEST_FLAG"
  printf '  latest     : %s\n' "$LATEST_WHY"
  printf '\nnothing was sent (--dry-run).\n'
  exit 0
fi

command -v gh >/dev/null 2>&1 || die "no 'gh' on PATH — this row publishes through the GitHub CLI"
gh auth status >/dev/null 2>&1 || die "'gh' has no usable token; publication needs one"

# ON THE REMOTE, not merely local.
gh api "repos/$SLUG/git/ref/tags/$TAG" >/dev/null 2>&1 \
  || refuse "tag '$TAG' does not exist on $SLUG. Push it first ('nen tag cut --push'); a release must not point at a ref nobody can fetch."

# ONE GO PUBLISHES ONE TARGET ONCE.
if gh release view "$TAG" --repo "$SLUG" >/dev/null 2>&1; then
  refuse "a release already exists for '$TAG' on $SLUG. Re-publishing is never the fix; edit it by hand if the notes are wrong."
fi

# shellcheck disable=SC2086  # $LATEST_FLAG is a deliberate zero-or-one flag
gh release create "$TAG" --repo "$SLUG" --title "$TITLE" \
  --notes-file "$NOTES_FILE" --verify-tag $LATEST_FLAG ${ASSETS+"${ASSETS[@]}"}

if [ "$JSON" = "1" ]; then
  gh release view "$TAG" --repo "$SLUG" --json tagName,name,url,publishedAt
else
  printf 'published %s%s: %s\n' "$TAG" "$([ "${DERIVED_TAG:-0}" = 1 ] && printf ' (derived)')" "$( gh release view "$TAG" --repo "$SLUG" --json url -q .url )"
fi
