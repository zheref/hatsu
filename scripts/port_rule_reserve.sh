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
#   4. every open SAME-REPOSITORY pull request whose FILE LIST names any pair file. A fork PR is
#      listed as `fork, not counted` and never moves the reservation: a port run pushes to origin,
#      never to a fork, and the public repository's forks are anyone's.
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
# Rulings of 2026-10-21 — the port rule prefix (HA#355), HR-34; the question "Which numbering?",
# answer "B PT-{n}, one global counter"): the prefix is PT and one counter runs across every pair
# file of the rulings directory, so an id is unique without its pair. The RULINGS DIRECTORY is the
# --pair-file's own directory (the skill passes <rulingsDir>/<from>--<to>.md); a PAIR FILE is every
# direct child of it named `*.md` (INDEX.md included: it carries no id rows, and reading it can only
# raise the count, never lower it). --pair-file still names the file the new row lands in, and the
# duplicate pass judges a row by its (id, file); --prefix stays, validated, read by the caller from
# the pair file's `prefix:` header.
#
# THE OPEN PRS ARE HOSTILE INPUT. So: only a same-repository PR whose paginated file list names a
# pair file is read; a hunk header is matched only inside a file's header region (between
# `diff --git` and its first `@@`), compared as a literal, so a `+++ b/<pair>` CONTENT line in
# another file's hunk is never a header; no path is ever spliced into a regex; a pair file named
# outside `^[A-Za-z0-9._-]+\.md$` in a counted place is a NAMED refusal (exit 3); every counted id
# must read `^[1-9][0-9]{0,8}$` (no leading zero, under a billion) and is computed in base 10, one
# outside that shape in a counted place is a NAMED refusal (exit 3), and a reservation that would
# pass the ceiling is refused too; the open-PR list and each file list are read with explicit
# limits or pagination and compared to the repository's own counts, a short read being the unread
# code (exit 1); a PR naming a pair file whose diff carries no header for it is unread (exit 1);
# the printed JSON escapes every branch name; a working-tree pair file is read only when it is a
# regular file whose realpath sits inside the worktree.
#
# RESIDUE, NAMED. The open-PR reads are `gh pr list`, `gh api --paginate repos/<t>/pulls/<n>/files`,
# `gh pr diff` and `gh api search/issues`: harness shell for a GitHub read, until zheref/nen#456
# lands a verb; this script is the one place it lives. The `gh` it runs is the first on PATH — the
# trust the session already places in PATH — which is how the fixture serves a stub.
#
# USAGE
#   scripts/port_rule_reserve.sh --worktree <the run's rulings worktree> --target <owner/name>
#                                --pair-file <rulingsDir>/<from>--<to>.md --prefix <PT> [--base <ref>]
#                                [--no-fetch] [--check] [--json]
#
# OUTPUT  `next: <prefix>-<n>` ONLY on a complete read, and one line per id seen, `<id> <where> in
#         <file>` (where: tip <ref> · branch HEAD · working tree · branch <ref> · PR #n (<ref>) ·
#         PR #n (<ref>) fork, not counted); --json: {complete, next, number, seen[]}, next null when
#         the read was incomplete.
# EXIT    0 reserved (or, with --check, no duplicate) · 1 an open PR or a file list could not be
#         read, or a list was short (an unread PR is never a clean one) · 2 usage (a flag with no
#         value, an unknown argument), a worktree that is not a git checkout, a fetch that failed,
#         a tip ref that does not resolve, a pair path outside `^[A-Za-z0-9._/-]+$`, carrying `..`,
#         with no directory or not ending `.md`, a working-tree pair file (or the rulings directory)
#         that is a symlink, not a regular file or outside the worktree, or no gh on PATH · 3 an id
#         or a pair-file name outside the admitted shape is in a counted place, the next id would
#         pass the ceiling, or (--check) this branch adds an id another counted place carries — each
#         named; settle it, or renumber this branch's rows.
set -uo pipefail

clone=""; target=""; pair=""; prefix=""; base="main"; json=0; fetch=1; check=0
usage() { echo "usage: port_rule_reserve.sh --worktree <path> --target <owner/name> --pair-file <rulingsDir>/<file>.md --prefix <PT> [--base <ref>] [--no-fetch] [--check] [--json]" >&2; exit 2; }
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
case "$prefix" in *[!A-Za-z0-9]*|"") echo "port_rule_reserve: --prefix is letters and digits only" >&2; exit 2 ;; esac
case "$pair" in
  /*|*..*|*[!A-Za-z0-9._/-]*|"") echo "port_rule_reserve: --pair-file is a relative path of [A-Za-z0-9._/-] with no '..', got '$pair'" >&2; exit 2 ;;
esac
case "$pair" in
  */*.md) ;;
  *) echo "port_rule_reserve: --pair-file is <rulingsDir>/<file>.md -- the counter is its directory's, so it needs one, got '$pair'" >&2; exit 2 ;;
esac
dir="${pair%/*}"
case "$target" in */*) ;; *) echo "port_rule_reserve: --target is owner/name" >&2; exit 2 ;; esac
CEILING=999999999
NAMESHAPE='^[A-Za-z0-9._-]+\.md$'

rows() { # stdin: lines; stdout: the raw number text of `| <prefix>-<n> ` rows (a leading + admitted)
  grep -aoE "^\+?\| ${prefix}-[0-9]+ " | sed -E 's/.*-([0-9]+) $/\1/' || true
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

seen=()
bad=()
mine=()    # "n<TAB>file<TAB>where": ids this branch carries (HEAD or working tree)
tipids=()  # "n<TAB>file": ids at the tip
others=()  # "n<TAB>file<TAB>where": ids at sibling branches and same-repository PRs
max=0
TAB=$'\t'
note() { # number-text, where, file, counted (1|0)
  local n="$1" where="$2" file="$3" counted="${4:-1}"
  if [ "$counted" = 0 ]; then seen+=("$prefix-$n $where in $file"); return; fi
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
note_ref() { # a git ref, its label: every row of every pair file at that ref
  local ref="$1" label="$2" ent meta path kind n c
  while IFS= read -r -d '' ent; do
    meta="${ent%%"$TAB"*}"; path="${ent#*"$TAB"}"
    kind="${meta#* }"; kind="${kind%% *}"
    [ "$kind" = blob ] || continue
    classify "$path"; c=$?
    [ "$c" = 1 ] && continue
    if [ "$c" = 2 ]; then bad+=("a pair file named outside $NAMESHAPE: $label"); continue; fi
    while IFS= read -r n; do [ -n "$n" ] && note "$n" "$label" "$path"; done < <(git -C "$clone" show "$ref:$path" | rows)
  done < <(git -C "$clone" ls-tree -z "$ref" -- "$dir/" 2>/dev/null)
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
      echo "port_rule_reserve: $f is a symlink or not a regular file -- refusing to read it" >&2; exit 2
    fi
    if [ "$c" = 2 ]; then bad+=("a pair file named outside $NAMESHAPE: working tree"); continue; fi
    while IFS= read -r n; do [ -n "$n" ] && note "$n" "working tree" "$rel"; done < <(rows < "$f")
  done
  shopt -u nullglob dotglob
elif [ -e "$clone/$dir" ]; then
  echo "port_rule_reserve: $clone/$dir is not a directory -- refusing to read it" >&2; exit 2
fi

# 3. every rulings branch already pushed to origin, and every local ports-* head of this clone that is not
#    this run's own (another run authoring in the same clone; ports-* at one to four path segments)
current="$(git -C "$clone" symbolic-ref -q --short HEAD 2>/dev/null || true)"
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  [ "$ref" = "$tipref" ] && continue
  [ -n "$current" ] && [ "$ref" = "$current" ] && continue
  note_ref "$ref" "branch $ref"
done < <(git -C "$clone" for-each-ref --format='%(refname:short)' 'refs/remotes/origin/ports-*' 'refs/remotes/origin/*/ports-*' 'refs/remotes/origin/*/*/ports-*' 'refs/remotes/origin/*/*/*/ports-*' 'refs/heads/ports-*' 'refs/heads/*/ports-*' 'refs/heads/*/*/ports-*' 'refs/heads/*/*/*/ports-*' 2>/dev/null)

# 4. every open same-repository PR whose file list names a pair file; a fork PR is listed, never counted
rc=0
total="$(gh api "search/issues?q=repo:${target}+is:pr+is:open" --jq '.total_count' 2>/dev/null)" || { echo "port_rule_reserve: the open-PR total of $target could not be read" >&2; exit 1; }
prs="$(gh pr list --repo "$target" --state open --limit 1000 --json number,headRefName,isCrossRepository,changedFiles --jq '.[] | "\(.number)\t\(.isCrossRepository)\t\(.changedFiles)\t\(.headRefName)"' 2>/dev/null)" || { echo "port_rule_reserve: gh pr list failed for $target" >&2; exit 1; }
count=0; [ -n "$prs" ] && count="$(printf '%s\n' "$prs" | grep -c .)"
if [ "$count" != "$total" ]; then
  echo "port_rule_reserve: the open-PR list of $target is short ($count read of $total open) -- an unread PR is never a clean one" >&2
  exit 1
fi
while IFS=$'\t' read -r num fork changed ref; do
  [ -n "$num" ] || continue
  files="$(gh api --paginate "repos/${target}/pulls/${num}/files" --jq '.[].filename' 2>/dev/null)" || { echo "port_rule_reserve: PR #$num's file list could not be read; its ids are unknown" >&2; rc=1; continue; }
  nfiles=0; [ -n "$files" ] && nfiles="$(printf '%s\n' "$files" | grep -c .)"
  if [ "$nfiles" != "$changed" ]; then echo "port_rule_reserve: PR #$num's file list is short ($nfiles read of $changed changed); its ids are unknown" >&2; rc=1; continue; fi
  where="PR #$num ($ref)"
  matched=()
  while IFS= read -r fl; do
    classify "$fl"; c=$?
    case "$c" in
      0) matched+=("$fl") ;;
      2) [ "$fork" = true ] || bad+=("a pair file named outside $NAMESHAPE: $where") ;;
    esac
  done <<< "$files"
  [ "${#matched[@]}" -gt 0 ] || continue
  diff="$(gh pr diff "$num" --repo "$target" 2>/dev/null)" || { echo "port_rule_reserve: PR #$num's diff could not be read; its ids are unknown" >&2; rc=1; continue; }
  unread=0; sections=()
  for fl in "${matched[@]}"; do
    # only that pair file's hunks: the header is matched literally and only inside a file's header region
    section="$(printf '%s\n' "$diff" | awk -v f="+++ b/$fl" 'BEGIN{p=0;h=0} /^diff --git /{p=0;h=1;next} /^@@/{h=0} (h && index($0, f) == 1 && length($0) == length(f)){p=1;next} p && /^\+/{print}')"
    if ! printf '%s\n' "$diff" | awk -v f="+++ b/$fl" 'BEGIN{h=0;ok=0} /^diff --git /{h=1;next} /^@@/{h=0} (h && index($0, f) == 1 && length($0) == length(f)){ok=1} END{exit ok?0:1}'; then
      if printf '%s\n' "$diff" | awk -v a="--- a/$fl" 'BEGIN{h=0;d=0;seen=0} /^diff --git /{h=1;seen=0;next} /^@@/{h=0} (h && index($0, a) == 1 && length($0) == length(a)){seen=1} (h && seen && $0 == "+++ /dev/null"){d=1} END{exit d?0:1}'; then
        continue # a deletion of the pair file: nothing to read
      fi
      echo "port_rule_reserve: PR #$num names the pair file $fl but its diff carries no hunk header for it (a rename or a mode change?); its ids are unknown" >&2
      unread=1; break
    fi
    sections+=("$fl$TAB$section")
  done
  if [ "$unread" = 1 ]; then rc=1; continue; fi
  for s in "${sections[@]+"${sections[@]}"}"; do
    fl="${s%%"$TAB"*}"; section="${s#*"$TAB"}"
    if [ "$fork" = true ]; then
      while IFS= read -r n; do [ -n "$n" ] && note "$n" "$where fork, not counted" "$fl" 0; done < <(printf '%s\n' "$section" | rows)
    else
      while IFS= read -r n; do [ -n "$n" ] && note "$n" "$where" "$fl"; done < <(printf '%s\n' "$section" | rows)
    fi
  done
done <<< "$prs"

if [ "${#bad[@]}" -gt 0 ]; then
  echo "port_rule_reserve: refusing to reserve -- an id outside ^[1-9][0-9]{0,8}$, or a pair file named out of shape, is in a counted place (settle it first):" >&2
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
  if [ "$rc" = 0 ]; then echo "port_rule_reserve --check: no duplicate -- every id this branch adds is its own"; else echo "port_rule_reserve --check: incomplete read (an open PR was unread); not judged" >&2; fi
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
