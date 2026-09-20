#!/bin/sh
# dist_tag.sh — cut the ONE opt-in distribution tag for a target that has just been sent to.
# Moved verbatim out of claude/skills/kagutsuchi/SKILL.md § 4a (2026-09-20 diet, zheref/hatsu#89).
#
#   scripts/dist_tag.sh --repo <path> --target-file <file> [--dry-run]
#
# --target-file is a file holding the target name, VERBATIM AND ALONE. THE TARGET IS THE MAINTAINER'S
# WORD AND IT IS DATA: it never enters shell source at all. A double-quoted assignment still runs
# command substitution, and a quoted heredoc's delimiter is in-band. The caller writes that file with
# the SURFACE'S OWN file-writing primitive — never echo, printf, cat or a heredoc.
#
# --dry-run performs every check and prints its verdict, and cuts nothing.
#
# exit 0  the tag was cut (or, with --dry-run, every check passed)
# exit 2  refused, with the reason on stderr — nothing was cut
# exit 3  no `tags.deploy` entry for this target: not declared, nothing cut, not an error
# exit 1  `nen tag cut` itself failed; its own reason stands and is never routed around

usage() {
  echo "usage: dist_tag.sh --repo <path> --target-file <file> [--dry-run]" >&2
  echo "  --target-file holds the target name verbatim and alone, written by the surface's own" >&2
  echo "  file-writing tool. The target never enters shell source." >&2
}

repo=""; target_file=""; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 ;;
    --target-file) target_file="${2:-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "dist_tag.sh: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done
[ -n "$repo" ] && [ -n "$target_file" ] || { usage; exit 2; }

say() { [ "$dry" -eq 1 ] && echo "  ok   $1"; }

root="$(git -C "$repo" rev-parse --show-toplevel)" || { echo "dist_tag.sh: not a git repository: $repo" >&2; exit 2; }
wf="$root/nen/workflow.json"
[ -f "$wf" ] || { echo "dist_tag.sh: no $wf -- refused" >&2; exit 2; }

target="$(tr -d '\r\n' <"$target_file")"
[ -n "$target" ] || { echo "dist_tag.sh: no target named -- refused" >&2; exit 2; }
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

identity="$(sed -n '1p' -- "$file" | tr -d '\r')"
built_at="$(sed -n '2p' -- "$file" | tr -d '\r')"
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
  echo "would run: nen tag cut --repo $repo --name $name --at $built_at --trunk $trunk ${push_flag}"
  echo "nothing was cut: --dry-run performs every check and stops."
  exit 0
fi

# nen refuses --at unless that commit is an ancestor of origin/<trunk>; its reason stands as given.
nen tag cut --repo "$repo" --name "$name" --at "$built_at" --trunk "$trunk" ${push_flag} || exit 1
