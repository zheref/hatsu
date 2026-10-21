#!/usr/bin/env bash
# port_rule_reserve.sh — the next free port-ruling id, reserved against every place a row can be,
# and (--check) the duplicate-id pass a run makes at every catch-up and before its gate.
#
# hatsu:bankai-rule § 3 (zheref/hatsu#355; the ruling of 2026-10-20, "reserve against open PRs",
# read with the round-2 settlement that a rulings PR opens only at a port run's end): a ruling's
# id is the next number free in the RULINGS DIRECTORY at FOUR places, read together from the RUN'S
# OWN RULINGS WORKTREE (--worktree: the checkout the branch is authored in, never the clone root) —
#   1. the tip, origin/<base>, fetched (and pruned) first: a stale tip would collide with a merged,
#      immutable row, and a deleted sibling branch must stop counting;
#   2. this run's own branch: HEAD's copy of every pair file and the working-tree copies, so the
#      second ruling of a run (a batched port-drift call writes several) never repeats the first;
#   3. every rulings branch already pushed to origin — refs/remotes/origin/**/ports-* at one to four
#      path segments (the clone's `{model}/{persona}/ports-<pair>` template is three) — a run that
#      has published through aka but whose PR has not opened yet — and every local ports-* head;
#      the run's OWN branch (local, and origin/<current> once pushed) is read as 2, never as a
#      sibling, and a local head tracking refs/pull/* or a remote other than origin is skipped,
#      named (a PR checkout, not a rulings run);
#   4. every open SAME-REPOSITORY pull request whose FILE LIST names any pair file, except the run's
#      own (headRefName = the current branch), which 2 already reads. A FORK PR is never read at
#      all — no file list, no diff — and listed as `PR #<n> fork, not read`: a port run pushes to
#      origin, never to a fork, and the public repository's forks are anyone's.
# WHAT THIS DOES NOT COVER, said plainly: a concurrent run that has not pushed yet (kokusen never
# pushes; a branch reaches origin only through aka at the run's end) is invisible to reads 3 and 4,
# so two runs reserving in the same window can take one id. That collision is caught by `--check`:
# the same four reads, judged as a duplicate pass — every id this branch adds (on HEAD or in the
# working tree, absent from that same file at the tip) that any other place carries, in ANY pair
# file, or that this branch itself carries in a second pair file, is listed and the exit is 3, so
# hatsu:ao's catch-up, hatsu:mukai before the PR and hatsu:en before the G4 prompt stop on it and
# the run renumbers only its own rows, never a merged one.
#
# NUMBERING SCOPE — ONE GLOBAL COUNTER. The maintainer's ruling of 2026-10-21 (docs/ROSTER.md §
# Rulings of 2026-10-21 — the port rule prefix (HA#355); the question "Which numbering?", answer
# "B PT-{n}, one global counter"): the prefix is PT and one counter runs across every pair file of
# the rulings directory. --prefix is therefore PT and nothing else (exit 2 otherwise), and a counted
# pair file whose header DECLARES a prefix or a numbering other than `prefix: PT · numbering:
# global` is a named refusal at exit 3 (a handbook-question: a second counter would fall through
# this one). A file carrying no such header line is counted as it stands. The RULINGS DIRECTORY is
# the --pair-file's own directory (the skill passes <rulingsDir>/<from>--<to>.md, one trailing `/`
# stripped from rulingsDir first); a PAIR FILE is every direct child of it named `*.md` (INDEX.md
# included: it carries no id rows and no prefix header). --pair-file still names the file the new
# row lands in, and the duplicate pass judges a row by its (id, file).
#
# A ROW is a table line whose first cell holds `PT-<n>` with any whitespace padding (`| PT-9 |`,
# `|PT-9|`, `|  PT-9  |`), so a hand-tightened merged row is never reserved over.
#
# THE OPEN PRS ARE HOSTILE INPUT, AND SO IS EVERY READ. So: only a same-repository PR whose
# paginated file list names a pair file is read; a hunk header is matched only inside a file's
# header region (between `diff --git` and its first `@@`), compared as a literal, so a `+++ b/<pair>`
# CONTENT line in another file's hunk is never a header; no path is ever spliced into a regex; a
# pair file named outside `^[A-Za-z0-9_-][A-Za-z0-9._-]*\.md$` in a counted place is a NAMED
# refusal (exit 3, the path printed through %q); every counted id must read `^[1-9][0-9]{0,8}$` (no
# leading zero, under a billion) and is computed in base 10, one outside that shape in a counted
# place is a NAMED refusal (exit 3), and a reservation that would pass the ceiling is refused too;
# the open-PR list and each file list are read with explicit limits or pagination and compared to
# the repository's own counts, a short read being the unread code (exit 1); a PR naming a pair
# file whose diff carries no header for it is unread (exit 1); a git listing, a blob, a branch list
# or a working-tree file that cannot be read (a missing object, an unreadable mode) is named and
# makes the read incomplete (exit 1, nothing reserved) — never read as empty; the printed JSON
# escapes every branch name; a working-tree pair file is read only when it is a regular file whose
# realpath sits inside the worktree.
#
# RESIDUE, NAMED. The open-PR reads are `gh pr list`, `gh api --paginate repos/<t>/pulls/<n>/files`,
# `gh pr diff` and `gh api search/issues`: harness shell for a GitHub read, until zheref/nen#456
# lands a verb; this script is the one place it lives. The `gh` it runs is the first on PATH — the
# trust the session already places in PATH — which is how the fixture serves a stub.
#
# USAGE
#   scripts/port_rule_reserve.sh --worktree <the run's rulings worktree> --target <owner/name>
#                                --pair-file <rulingsDir>/<from>--<to>.md --prefix PT [--base <ref>]
#                                [--no-fetch] [--check] [--json]
#
# OUTPUT  `next: PT-<n>` ONLY on a complete read, and one line per id seen, `<id> <where> in <file>`
#         (where: tip <ref> · branch HEAD · working tree · branch <ref> · PR #n (<ref>)), plus one
#         line per fork PR (`PR #n fork, not read`), per own PR and per skipped local head;
#         --json: {complete, next, number, seen[]}, next null when the read was incomplete.
# EXIT    0 reserved (or, with --check, no duplicate) · 1 a read failed — an open PR, a file list
#         (or a short one), a git listing, a blob, the branch list or a working-tree file (an unread
#         place is never a clean one) · 2 usage (a flag with no value, an unknown argument, a
#         --prefix other than PT, a --target outside `^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$`, a
#         --pair-file not one or more `^[A-Za-z0-9_-][A-Za-z0-9._-]*$` segments then `/<name>.md` —
#         no empty, `.` or `..` segment, no leading `./`, no trailing `/`), a worktree that is not a
#         git checkout, a fetch that failed, a tip ref that does not resolve, a working-tree pair file
#         (or the rulings directory) that is a symlink, not a regular file or outside the worktree,
#         or no gh on PATH · 3 an id, a pair-file name or a pair-file header outside the admitted
#         shape is in a counted place, the next id would pass the ceiling, or (--check) this branch
#         adds an id another counted place carries — each named; settle it, or renumber this
#         branch's rows.
set -uo pipefail

clone=""; target=""; pair=""; prefix=""; base="main"; json=0; fetch=1; check=0
usage() { echo "usage: port_rule_reserve.sh --worktree <path> --target <owner/name> --pair-file <rulingsDir>/<file>.md --prefix PT [--base <ref>] [--no-fetch] [--check] [--json]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --worktree|--target|--pair-file|--prefix|--base) [ -n "${2-}" ] || { echo "port_rule_reserve: $1 takes a value" >&2; usage; } ;;
  esac
  case "$1" in
    --worktree) clone="$2"; shift 2 ;;
    --target) target="$2"; shift 2 ;;
    --pair-file) pair="$2"; shift 2 ;;
    --prefix) prefix="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --no-fetch) fetch=0; shift ;;
    --check) check=1; shift ;;
    --json) json=1; shift ;;
    *) echo "port_rule_reserve: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$clone" ] && [ -n "$target" ] && [ -n "$pair" ] && [ -n "$prefix" ] || usage
git -C "$clone" rev-parse --git-dir >/dev/null 2>&1 || { echo "port_rule_reserve: '$clone' is not a git checkout" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "port_rule_reserve: gh is not on PATH" >&2; exit 2; }
[ "$prefix" = PT ] || { echo "port_rule_reserve: --prefix is PT, the ruled prefix (docs/ROSTER.md § Rulings of 2026-10-21 — the port rule prefix (HA#355)); got $(printf '%q' "$prefix")" >&2; exit 2; }
SEG='[A-Za-z0-9_-][A-Za-z0-9._-]*'
PAIRSHAPE="^(${SEG}/)+${SEG}\\.md\$"
NAMESHAPE="^${SEG}\\.md\$"
[[ "$pair" =~ $PAIRSHAPE ]] || { echo "port_rule_reserve: --pair-file is <rulingsDir>/<name>.md: one or more segments of $SEG then /<name>.md -- no empty, '.' or '..' segment, no leading './' or '/', no trailing '/'; got $(printf '%q' "$pair")" >&2; exit 2; }
dir="${pair%/*}"
[[ "$target" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$ ]] || { echo "port_rule_reserve: --target is owner/name (^[A-Za-z0-9-]+/[A-Za-z0-9._-]+\$); got $(printf '%q' "$target")" >&2; exit 2; }
CEILING=999999999
HDRSHAPE='prefix: PT · numbering: global([^A-Za-z0-9_-]|$)'
work="$(mktemp -d "${TMPDIR:-/tmp}/port-rule-reserve.XXXXXX")" || { echo "port_rule_reserve: no scratch directory" >&2; exit 2; }
trap 'rm -rf "${work:?}"' EXIT

rows() { # stdin: lines; stdout: the raw number text of rows whose first cell is `<prefix>-<n>`, any padding (a leading + admitted)
  grep -aoE "^\+?\|[[:space:]]*${prefix}-[0-9]+[[:space:]]*\|" | sed -E "s/.*${prefix}-([0-9]+)[[:space:]]*\|\$/\1/" || true
}
classify() { # a repository path: 0 a pair file (a direct *.md child of the rulings directory, in shape),
             # 1 not a pair file, 2 a direct *.md child named outside the shape
  local p="$1" rest
  case "$p" in "$dir"/*) rest="${p#"$dir"/}" ;; *) return 1 ;; esac
  case "$rest" in ""|*/*) return 1 ;; esac
  case "$rest" in *.md) ;; *) return 1 ;; esac
  [[ "$rest" =~ $NAMESHAPE ]] && return 0
  return 2
}
printable() { printf '%q' "$1"; }

rc=0
seen=()
bad=()
mine=()    # "n<TAB>file<TAB>where": ids this branch carries (HEAD or working tree)
tipids=()  # "n<TAB>file": ids at the tip
others=()  # "n<TAB>file<TAB>where": ids at sibling branches and same-repository PRs
max=0
TAB=$'\t'
unread() { echo "port_rule_reserve: $1; its ids are unknown, nothing is reserved" >&2; rc=1; }
note() { # number-text, where, file
  local n="$1" where="$2" file="$3"
  if [[ "$n" =~ ^[1-9][0-9]{0,8}$ ]]; then
    seen+=("$prefix-$n $where in $file")
    [ "$((10#$n))" -gt "$max" ] && max=$((10#$n))
    case "$where" in
      tip*) tipids+=("$n$TAB$file") ;;
      "branch HEAD"|"working tree") mine+=("$n$TAB$file$TAB$where") ;;
      *) others+=("$n$TAB$file$TAB$where") ;;
    esac
  else
    bad+=("$prefix-$n $where in $file")
  fi
}
take() { # content, where, file: a pair file's header, then its rows
  local content="$1" where="$2" file="$3" line n
  while IFS= read -r line; do
    case "$line" in "<!--"*prefix:*|"<!--"*numbering:*) ;; *) continue ;; esac
    if ! [[ "$line" =~ $HDRSHAPE ]] || [[ "${line#*prefix:}" == *prefix:* ]]; then
      bad+=("a pair file whose header is not 'prefix: PT · numbering: global' (a handbook-question): $(printable "$file") at $where")
      return 0
    fi
  done <<< "$content"
  while IFS= read -r n; do [ -n "$n" ] && note "$n" "$where" "$file"; done < <(printf '%s\n' "$content" | rows)
}
note_ref() { # a git ref, its label: every pair file at that ref
  local ref="$1" label="$2" ent meta path kind c content lst="$work/ls"
  if ! git -C "$clone" ls-tree -z "$ref" -- "$dir/" > "$lst" 2>/dev/null; then unread "$label: the tree could not be listed"; return 0; fi
  while IFS= read -r -d '' ent; do
    meta="${ent%%"$TAB"*}"; path="${ent#*"$TAB"}"
    kind="${meta#* }"; kind="${kind%% *}"
    [ "$kind" = blob ] || continue
    classify "$path"; c=$?
    [ "$c" = 1 ] && continue
    if [ "$c" = 2 ]; then bad+=("a pair file named outside $NAMESHAPE: $(printable "$path") at $label"); continue; fi
    content="$(git -C "$clone" show "$ref:$path" 2>/dev/null)" || { unread "$label: $(printable "$path") could not be read"; continue; }
    take "$content" "$label" "$path"
  done < "$lst"
}
attip() { # n, file: is this (id, file) a row the tip carries?
  local t
  for t in "${tipids[@]+"${tipids[@]}"}"; do [ "$t" = "$1$TAB$2" ] && return 0; done
  return 1
}
jsonstr() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
realdir() { ( cd "$1" 2>/dev/null && pwd -P ); }

# 1. the tip, fetched and pruned (a clone whose fetch refspec does not cover every head cannot see sibling branches)
if git -C "$clone" remote get-url origin >/dev/null 2>&1; then
  git -C "$clone" config --get-all remote.origin.fetch 2>/dev/null | grep -q 'refs/heads/\*' || { echo "port_rule_reserve: origin's fetch refspec does not cover refs/heads/* (a --single-branch clone?) -- sibling branches would be unread, nothing is reserved" >&2; exit 2; }
  if [ "$fetch" = 1 ]; then
    git -C "$clone" fetch -q --prune origin >/dev/null 2>&1 || { echo "port_rule_reserve: fetching origin failed -- the tip is unread, nothing is reserved" >&2; exit 2; }
  fi
  tipref="origin/$base"
  git -C "$clone" rev-parse --verify -q "$tipref" >/dev/null || { echo "port_rule_reserve: origin/$base does not resolve in $clone -- the tip is unread, nothing is reserved" >&2; exit 2; }
else
  tipref="$base"
  git -C "$clone" rev-parse --verify -q "$tipref" >/dev/null || { echo "port_rule_reserve: $clone has no origin and $base does not resolve -- the tip is unread, nothing is reserved" >&2; exit 2; }
  echo "port_rule_reserve: $clone has no origin; the local $base is the tip" >&2
fi
note_ref "$tipref" "tip $tipref"

# 2. this run's own branch: HEAD and the working tree (regular files inside the worktree, never a symlink)
note_ref HEAD "branch HEAD"
if [ -L "$clone/$dir" ]; then echo "port_rule_reserve: $clone/$dir is a symlink -- refusing to read it" >&2; exit 2; fi
if [ -d "$clone/$dir" ]; then
  ddir="$(realdir "$clone/$dir")"; wdir="$(realdir "$clone")"
  case "$ddir/" in "$wdir"/*) ;; *) echo "port_rule_reserve: $clone/$dir resolves outside the worktree -- refusing to read it" >&2; exit 2 ;; esac
  shopt -s nullglob dotglob
  for f in "$clone/$dir"/*; do
    rel="$dir/${f##*/}"
    classify "$rel"; c=$?
    [ "$c" = 1 ] && continue
    if [ -L "$f" ] || [ ! -f "$f" ]; then
      echo "port_rule_reserve: $(printable "$f") is a symlink or not a regular file -- refusing to read it" >&2; exit 2
    fi
    if [ "$c" = 2 ]; then bad+=("a pair file named outside $NAMESHAPE: $(printable "$rel") in the working tree"); continue; fi
    content="$(cat -- "$f" 2>/dev/null)" || { unread "working tree: $(printable "$rel") could not be read"; continue; }
    take "$content" "working tree" "$rel"
  done
  shopt -u nullglob dotglob
elif [ -e "$clone/$dir" ]; then
  echo "port_rule_reserve: $clone/$dir is not a directory -- refusing to read it" >&2; exit 2
fi

# 3. every rulings branch already pushed to origin, and every local ports-* head of this clone that is not
#    this run's own (another run authoring in the same clone; ports-* at one to four path segments)
current="$(git -C "$clone" symbolic-ref -q --short HEAD 2>/dev/null || true)"
if ! refs="$(git -C "$clone" for-each-ref --format='%(refname)%09%(refname:short)' 'refs/remotes/origin/ports-*' 'refs/remotes/origin/*/ports-*' 'refs/remotes/origin/*/*/ports-*' 'refs/remotes/origin/*/*/*/ports-*' 'refs/heads/ports-*' 'refs/heads/*/ports-*' 'refs/heads/*/*/ports-*' 'refs/heads/*/*/*/ports-*' 2>/dev/null)"; then
  unread "the rulings branches of $clone could not be listed"; refs=""
fi
while IFS="$TAB" read -r full short; do
  [ -n "$full" ] || continue
  [ "$short" = "$tipref" ] && continue
  if [ -n "$current" ]; then
    [ "$full" = "refs/heads/$current" ] && continue
    [ "$full" = "refs/remotes/origin/$current" ] && continue  # this run's own push: read as HEAD, never a sibling
  fi
  case "$full" in
    refs/heads/*)
      bname="${full#refs/heads/}"
      umerge="$(git -C "$clone" config --get "branch.$bname.merge" 2>/dev/null || true)"
      uremote="$(git -C "$clone" config --get "branch.$bname.remote" 2>/dev/null || true)"
      case "$umerge" in
        refs/pull/*) seen+=("skipped: branch $short (tracks $umerge -- a PR checkout, not a rulings run)"); echo "port_rule_reserve: skipped local head $short: it tracks $umerge (a PR checkout, not a rulings run)" >&2; continue ;;
      esac
      if [ -n "$uremote" ] && [ "$uremote" != origin ]; then
        seen+=("skipped: branch $short (tracks remote $uremote, not origin)"); echo "port_rule_reserve: skipped local head $short: it tracks remote $uremote, not origin" >&2; continue
      fi
      ;;
  esac
  note_ref "$full" "branch $short"
done <<< "$refs"

# 4. every open same-repository PR whose file list names a pair file; a fork PR is never read, only listed
total="$(gh api "search/issues?q=repo:${target}+is:pr+is:open" --jq '.total_count' 2>/dev/null)" || { echo "port_rule_reserve: the open-PR total of $target could not be read" >&2; exit 1; }
prs="$(gh pr list --repo "$target" --state open --limit 1000 --json number,headRefName,isCrossRepository,changedFiles --jq '.[] | "\(.number)\t\(.isCrossRepository)\t\(.changedFiles)\t\(.headRefName)"' 2>/dev/null)" || { echo "port_rule_reserve: gh pr list failed for $target" >&2; exit 1; }
count=0; [ -n "$prs" ] && count="$(printf '%s\n' "$prs" | grep -c .)"
if [ "$count" != "$total" ]; then
  echo "port_rule_reserve: the open-PR list of $target is short ($count read of $total open) -- an unread PR is never a clean one" >&2
  exit 1
fi
while IFS="$TAB" read -r num fork changed ref; do
  [ -n "$num" ] || continue
  [[ "$num" =~ ^[0-9]+$ ]] || { unread "an open PR listed with a non-numeric number"; continue; }
  if [ "$fork" = true ]; then seen+=("PR #$num fork, not read"); continue; fi
  if [ -n "$current" ] && [ "$ref" = "$current" ]; then seen+=("PR #$num this run's own branch, read as HEAD"); continue; fi
  files="$(gh api --paginate "repos/${target}/pulls/${num}/files" --jq '.[].filename' 2>/dev/null)" || { unread "PR #$num's file list could not be read"; continue; }
  nfiles=0; [ -n "$files" ] && nfiles="$(printf '%s\n' "$files" | grep -c .)"
  if [ "$nfiles" != "$changed" ]; then unread "PR #$num's file list is short ($nfiles read of $changed changed)"; continue; fi
  where="PR #$num ($ref)"
  matched=()
  while IFS= read -r fl; do
    classify "$fl"; c=$?
    case "$c" in
      0) matched+=("$fl") ;;
      2) bad+=("a pair file named outside $NAMESHAPE: $(printable "$fl") at $where") ;;
    esac
  done <<< "$files"
  [ "${#matched[@]}" -gt 0 ] || continue
  diff="$(gh pr diff "$num" --repo "$target" 2>/dev/null)" || { unread "PR #$num's diff could not be read"; continue; }
  failed=0; sections=()
  for fl in "${matched[@]}"; do
    # only that pair file's hunks: the header is matched literally and only inside a file's header region
    section="$(printf '%s\n' "$diff" | awk -v f="+++ b/$fl" 'BEGIN{p=0;h=0} /^diff --git /{p=0;h=1;next} /^@@/{h=0} (h && index($0, f) == 1 && length($0) == length(f)){p=1;next} p && /^\+/{print}')"
    if ! printf '%s\n' "$diff" | awk -v f="+++ b/$fl" 'BEGIN{h=0;ok=0} /^diff --git /{h=1;next} /^@@/{h=0} (h && index($0, f) == 1 && length($0) == length(f)){ok=1} END{exit ok?0:1}'; then
      if printf '%s\n' "$diff" | awk -v a="--- a/$fl" 'BEGIN{h=0;d=0;seen=0} /^diff --git /{h=1;seen=0;next} /^@@/{h=0} (h && index($0, a) == 1 && length($0) == length(a)){seen=1} (h && seen && $0 == "+++ /dev/null"){d=1} END{exit d?0:1}'; then
        continue # a deletion of the pair file: nothing to read
      fi
      unread "PR #$num names the pair file $fl but its diff carries no hunk header for it (a rename or a mode change?)"
      failed=1; break
    fi
    sections+=("$fl$TAB$section")
  done
  [ "$failed" = 1 ] && continue
  for s in "${sections[@]+"${sections[@]}"}"; do
    fl="${s%%"$TAB"*}"; section="${s#*"$TAB"}"
    while IFS= read -r n; do [ -n "$n" ] && note "$n" "$where" "$fl"; done < <(printf '%s\n' "$section" | rows)
  done
done <<< "$prs"

if [ "${#bad[@]}" -gt 0 ]; then
  echo "port_rule_reserve: refusing to reserve -- a counted place carries an id outside ^[1-9][0-9]{0,8}$, a pair file named out of shape, or a foreign pair-file header (settle it first):" >&2
  for b in "${bad[@]}"; do echo "  $b" >&2; done
  exit 3
fi

if [ "$check" = 1 ]; then
  # one counter across every pair file: an id this branch adds collides with the same id ANYWHERE else --
  # the tip in another file, a sibling or a PR in any file, or this branch's own row in a second file
  dups=(); judged=""
  for e in "${mine[@]+"${mine[@]}"}"; do
    m="${e%%"$TAB"*}"; rest="${e#*"$TAB"}"; mf="${rest%%"$TAB"*}"
    case "$judged" in *"|$m$TAB$mf|"*) continue ;; esac
    judged="$judged|$m$TAB$mf|"
    attip "$m" "$mf" && continue
    for t in "${tipids[@]+"${tipids[@]}"}"; do
      [ "${t%%"$TAB"*}" = "$m" ] && dups+=("$prefix-$m ($mf) also at tip $tipref (${t#*"$TAB"})")
    done
    for o in "${others[@]+"${others[@]}"}"; do
      on="${o%%"$TAB"*}"; orest="${o#*"$TAB"}"; of="${orest%%"$TAB"*}"; ow="${orest#*"$TAB"}"
      [ "$on" = "$m" ] || continue
      attip "$on" "$of" && continue  # the tip's own row, carried on that branch: listed against the tip above
      dups+=("$prefix-$m ($mf) also at $ow ($of)")
    done
    for o in "${mine[@]+"${mine[@]}"}"; do
      on="${o%%"$TAB"*}"; orest="${o#*"$TAB"}"; of="${orest%%"$TAB"*}"; ow="${orest#*"$TAB"}"
      [ "$on" = "$m" ] && [ "$of" != "$mf" ] && dups+=("$prefix-$m ($mf) also at $ow ($of)")
    done
  done
  if [ "${#dups[@]}" -gt 0 ]; then
    echo "port_rule_reserve --check: this branch adds an id another place carries (one counter across every pair file) -- renumber this branch's rows (never a merged one):" >&2
    printf '%s\n' "${dups[@]}" | sort -u | sed 's/^/  /' >&2
    exit 3
  fi
  if [ "$rc" = 0 ]; then echo "port_rule_reserve --check: no duplicate -- every id this branch adds is its own"; else echo "port_rule_reserve --check: incomplete read (a place was unread); not judged" >&2; fi
  exit "$rc"
fi

next=$((max + 1))
if [ "$next" -gt "$CEILING" ]; then
  echo "port_rule_reserve: refusing to reserve -- the next id $prefix-$next passes the ceiling $prefix-$CEILING" >&2
  exit 3
fi
complete=true; [ "$rc" = 0 ] || complete=false
if [ "$json" = 1 ]; then
  if [ "$complete" = true ]; then printf '{"complete":true,"next":"%s-%s","number":%s,"seen":[' "$prefix" "$next" "$next"; else printf '{"complete":false,"next":null,"number":null,"seen":['; fi
  first=1; for s in "${seen[@]+"${seen[@]}"}"; do [ $first = 1 ] || printf ','; first=0; printf '"%s"' "$(jsonstr "$s")"; done
  printf ']}\n'
else
  if [ "$complete" = true ]; then printf 'next: %s-%s\n' "$prefix" "$next"; else printf 'next: (none reserved -- the read was incomplete)\n'; fi
  for s in "${seen[@]+"${seen[@]}"}"; do printf '  seen: %s\n' "$s"; done
fi
exit "$rc"
