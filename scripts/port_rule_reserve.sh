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
#      has published through aka but whose PR has not opened yet — and every local ports-* head.
#      OWN IS DECIDED BY ANCESTRY, NEVER BY NAME: origin/<current> is this run's own push only when
#      it is an ancestor of HEAD; otherwise it is another run that took the same branch name, and
#      it is read as a sibling. A local head whose upstream remote is unset or `.` is read; one
#      whose merge ref is refs/pull/* (a PR checkout), or whose remote's URL is not origin's, is
#      skipped, counted and reported by reason only, never by name. A PR head fetched by hand with
#      NO tracking config is read like any local head;
#   4. every open SAME-REPOSITORY pull request whose FILE LIST names any pair file. The PR whose
#      headRefName is the current branch is this run's own (read as 2, not again) only when its
#      headRefOid is an ancestor of HEAD; otherwise it is read like any open PR. A FORK PR is never
#      read at all — no file list, no diff — and listed as `PR #<n> fork, not read`: a port run
#      pushes to origin, never to a fork, and the public repository's forks are anyone's.
# WHAT THIS DOES NOT COVER, said plainly: a concurrent run that has not pushed yet (kokusen never
# pushes; a branch reaches origin only through aka at the run's end) is invisible to reads 3 and 4,
# so two runs reserving in the same window can take one id. That collision is caught by `--check`:
# the same four reads, judged as a duplicate pass — every id this branch adds (on HEAD or in the
# working tree, absent from that same file at the tip) that any other place carries, in ANY pair
# file, that this branch itself carries in a second pair file, or in two rows of one pair file, is
# listed with `also at` and the exit is 3, so hatsu:ao's catch-up, hatsu:mukai before the PR and
# hatsu:en before the G4 prompt stop on it and the run renumbers only its own rows, never a merged
# one. A duplicate is told from the other exit-3 refusals by its `also at` line.
#
# NUMBERING SCOPE — ONE GLOBAL COUNTER. The maintainer's ruling of 2026-10-21 (docs/ROSTER.md §
# Rulings of 2026-10-21 — the port rule prefix (HA#355); the question "Which numbering?", answer
# "B PT-{n}, one global counter"): the prefix is PT and one counter runs across every pair file of
# the rulings directory. --prefix is therefore PT and nothing else (exit 2 otherwise). A HEADER
# LINE is one that begins (after any whitespace) with `<!--` and names `prefix:` or `numbering:`,
# keys compared case-insensitively; in a counted pair file — at the tip, HEAD, a sibling, the
# working tree, or in an open PR's added lines for that file — it must carry exactly one prefix and
# one numbering, as `prefix: PT · numbering: global` with `global` followed by whitespace, `)`, `·`
# or `-->`; anything else is a named refusal at exit 3 (a handbook-question: a second counter would
# fall through this one). A file carrying no header line is counted as it stands. The RULINGS
# DIRECTORY is the --pair-file's own directory (the skill strips one trailing `/` from rulingsDir,
# then the grammar applies); a PAIR FILE is every direct child of it named `*.md` (INDEX.md
# included: it carries no id rows and no prefix header). --pair-file still names the file the new
# row lands in, and the duplicate pass judges a row by its (id, file).
#
# A ROW. Every line of a counted pair file that carries a `|` is judged by its FIRST CELL (the text
# before the first `|`, after an optional leading `|`), trimmed and with emphasis (`**`, `__`, `*`,
# `_`, backticks) stripped: `PT-<n>` on a line indented at most three spaces is a ROW and is
# counted (`| PT-9 |`, `|PT-9|`, `PT-9 | …`, `   | PT-9 |`, `| **PT-9** |`, `` | `PT-9` | ``);
# indented further, or any other first cell carrying `PT-<digits>` (`PT-9a`, `~~PT-9~~`, `PT-9 x`),
# is a named refusal at exit 3, never silently skipped; a first cell `[A-Z]+-[0-9]+` with another
# prefix is a named refusal at exit 3 (a handbook-question). The header row and the separator row
# are not rows. KNOWN, SAFE OVER-COUNT: a row inside a fenced example block is counted too — it can
# only raise the next id, never lower it.
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
# escapes `"`, `\` and every control character; a working-tree pair file is read only when it is
# a regular file whose realpath sits inside the worktree.
#
# COST — NO SLOWER THAN ONE FILE PER PLACE (the maintainer's ruling on HA-PR-#392: no performance decrease
# against the per-file reader). One ls-tree per place lists its pair files; ONE `git cat-file --batch`
# serves every blob of every place and ONE awk judges every line of every file, so the process count is
# the number of places plus two, whatever the number of pair files, and the work is linear in rows.
# Duplicates are found once, after collection, by one awk over the seen lines. Lane port-rule-guard holds
# a 3000-row scaling case to a 30 s bound (docs/ab/bankai-rule.md § 2 carries the benchmark).
#
# RESIDUE, NAMED. The open-PR reads are `gh pr list`, `gh api --paginate repos/<t>/pulls/<n>/files`,
# `gh pr diff` and `gh api search/issues`: harness shell for a GitHub read, until zheref/nen#456
# lands a verb; this script is the one place it lives. The `gh` it runs is the first on PATH — the
# trust the session already places in PATH — which is how the fixture serves a stub.
#
# USAGE
#   scripts/port_rule_reserve.sh --worktree <the run's rulings worktree> --target <owner/name>
#                                --pair-file <rulingsDir>/<from>--<to>.md --prefix PT [--base <ref>]
#                                [--handbooks-tag <vX.Y.Z>] [--no-fetch] [--check] [--json]
#
# OUTPUT  `next: PT-<n>` ONLY on a complete read, and one line per id seen, `<id> <where> in <file>`
#         (where: tip <ref> · branch HEAD · working tree · branch <ref> · PR #n (<ref>)); seen[]
#         also carries one entry per fork PR (`PR #n fork, not read`), per own PR (`PR #n this run's
#         own branch, read as HEAD`) and one per skip reason (`skipped <k> local head(s): …`);
#         --json: {complete, next, number, seen[]}, next null when the read was incomplete.
# EXIT    0 reserved (or, with --check, no duplicate) · 1 a read failed — an open PR, a file list
#         (or a short one), a git listing, a blob, the branch list or a working-tree file (an unread
#         place is never a clean one) · 2 usage (a flag with no value, an unknown argument, a
#         --prefix other than PT, a --target that is not `[A-Za-z0-9-]+/` then one segment of
#         `[A-Za-z0-9_-][A-Za-z0-9._-]*`, a --pair-file not one or more such segments then
#         `/<name>.md` — no empty, `.` or `..` segment, no leading `./`, no trailing `/`), no scratch
#         directory (mktemp failed), a worktree that is not a git checkout, a clone whose origin
#         fetch refspec does not cover refs/heads/* (a --single-branch clone), a fetch that failed,
#         a tip ref that does not resolve, a --handbooks-tag not vX.Y.Z, a --pair-file missing at the tip
#         under a --handbooks-tag at or above v0.11.0 (every directed pair ships its file there), a working-tree pair file (or the rulings directory) that
#         is a symlink, not a regular file or outside the worktree, or no gh on PATH · 3 an id, a
#         row, a first cell, a pair-file name or a pair-file header outside the admitted shape is in
#         a counted place, the next id would pass the ceiling, or (--check) this branch adds an id
#         another counted place carries (`also at`) — each named; settle it, or renumber this
#         branch's rows.
set -uo pipefail

clone=""; target=""; pair=""; prefix=""; base="main"; json=0; fetch=1; check=0; htag=""
usage() { echo "usage: port_rule_reserve.sh --worktree <path> --target <owner/name> --pair-file <rulingsDir>/<file>.md --prefix PT [--base <ref>] [--handbooks-tag <vX.Y.Z>] [--no-fetch] [--check] [--json]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --worktree|--target|--pair-file|--prefix|--base|--handbooks-tag) [ -n "${2-}" ] || { echo "port_rule_reserve: $1 takes a value" >&2; usage; } ;;
  esac
  case "$1" in
    --worktree) clone="$2"; shift 2 ;;
    --target) target="$2"; shift 2 ;;
    --pair-file) pair="$2"; shift 2 ;;
    --prefix) prefix="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --handbooks-tag) htag="$2"; shift 2 ;;
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
TARGETSHAPE="^[A-Za-z0-9-]+/${SEG}\$"
[[ "$pair" =~ $PAIRSHAPE ]] || { echo "port_rule_reserve: --pair-file is <rulingsDir>/<name>.md: one or more segments of $SEG then /<name>.md -- no empty, '.' or '..' segment, no leading './' or '/', no trailing '/'; got $(printf '%q' "$pair")" >&2; exit 2; }
dir="${pair%/*}"
[[ "$target" =~ $TARGETSHAPE ]] || { echo "port_rule_reserve: --target is owner/name (owner [A-Za-z0-9-]+, name $SEG); got $(printf '%q' "$target")" >&2; exit 2; }
# --handbooks-tag: the consumer's pinned handbooks tag. From v0.11.0 every directed pair of product stacks
# ships its pair file (CON-13 as amended, zheref/bankai-handbooks#21), so a pair file missing at the tip is
# refused at exit 2 rather than created.
pairs_ship=0
if [ -n "$htag" ]; then
  [[ "$htag" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || { echo "port_rule_reserve: --handbooks-tag is vX.Y.Z; got $(printf '%q' "$htag")" >&2; exit 2; }
  hmaj=$((10#${BASH_REMATCH[1]})); hmin=$((10#${BASH_REMATCH[2]}))
  if [ "$hmaj" -gt 0 ] || [ "$hmin" -ge 11 ]; then pairs_ship=1; fi
fi
CEILING=999999999
P='[Pp][Rr][Ee][Ff][Ii][Xx]'; N='[Nn][Uu][Mm][Bb][Ee][Rr][Ii][Nn][Gg]'
HDRSHAPE="${P}: PT · ${N}: global([[:space:]]|\\)|·|-->)"
work="$(mktemp -d "${TMPDIR:-/tmp}/port-rule-reserve.XXXXXX")" || { echo "port_rule_reserve: no scratch directory (mktemp failed)" >&2; exit 2; }
trap 'rm -rf "${work:?}"' EXIT

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
bad=()
TAB=$'\t'
SEENF="$work/seen"; : > "$SEENF"   # every seen line, in read order (also fork, own-PR and skip entries)
seenadd() { printf '%s\n' "$1" >> "$SEENF"; }
unread() { echo "port_rule_reserve: $1; its ids are unknown, nothing is reserved" >&2; rc=1; }
max=0

# THE READ PLAN. Every place's pair files are QUEUED, in the order the places are read (tip, HEAD, working
# tree, siblings), into one LIST ("idx<TAB>kind<TAB>group<TAB>path<TAB>src"): kind b a blob (its oid in
# OIDS, served by ONE `git cat-file --batch` for every place), f a file read from src, x a file named out of
# shape, u an unreadable one, m a message (an unread listing, said in its place). Groups carry each place's
# label and class. ONE awk (JUDGE) then judges every file of every place in that order, so the process count
# is one ls-tree per place plus two, whatever the number of pair files and rows. A PR section is its own
# one-entry plan. JUDGE: per file, the header pass first (a foreign header refuses the file and skips its
# rows), then every line carrying a `|` judged by its first cell. Counted ids and their seen lines go to
# IDS and SEEN; whatever bash must still word comes back on stdout as an indexed record, in read order:
# B<TAB>message · X|U<TAB>idx<TAB>group · N<TAB>idx · Q<TAB>F|P<TAB>idx<TAB>group<TAB>cell · M<TAB>max.
# POSIX/BWK awk, run under LC_ALL=C (bytes; `·` is matched as its two bytes).
IFS= read -r -d '' JUDGE_AWK <<'AWK' || true
function lead_of(s,   i, c, L) {
  L = length(s); i = 1
  while (i <= L) { c = substr(s, i, 1); if (c == " " || c == "\t" || c == "\r" || c == "\f" || c == VT) i++; else break }
  return substr(s, 1, i - 1)
}
function trim(s) { sub("^" SP "+", "", s); sub(SP "+$", "", s); return s }
function cnt(s, k,   t) { t = s; return gsub(k, "", t) }
function count(num, W, path) {
  if (substr(num, 1, 1) != "0" && length(num) <= 9) {
    print PFX "-" num " " W " in " path
    if (num + 0 > MAX) MAX = num + 0
  } else print "B\t" PFX "-" num " " W " in " path > REC
}
function judge(idx, g, path,   i, ld, body, low, cell, L2, c1, p, num, W, C, IDS, line, rest, sp) {
  W = GL[g]
  for (i = 1; i <= nl; i++) {
    if (!index(buf[i], "<!--")) continue
    ld = lead_of(buf[i]); body = substr(buf[i], length(ld) + 1)
    if (substr(body, 1, 4) != "<!--") continue
    low = tolower(body)
    if (!index(low, "prefix:") && !index(low, "numbering:")) continue
    if (cnt(low, "prefix:") != 1 || cnt(low, "numbering:") != 1 || body !~ HDR) {
      print "B\ta pair file whose header is not 'prefix: PT · numbering: global' (a handbook-question): " path " at " W > REC
      return
    }
  }
  for (i = 1; i <= nl; i++) {
    line = buf[i]
    if (!index(line, "|")) continue
    if (substr(line, 1, 5) == "| PT-") {   # the common row, `| PT-<digits> |`: judged exactly as below, without the general walk
      rest = substr(line, 6); sp = index(rest, " |")
      if (sp > 1) { num = substr(rest, 1, sp - 1); if (num !~ /[^0-9]/) { count(num, W, path); continue } }
    }
    ld = lead_of(line); body = substr(line, length(ld) + 1)
    cell = body; if (substr(cell, 1, 1) == "|") cell = substr(cell, 2)
    p = index(cell, "|"); if (p) cell = substr(cell, 1, p - 1)
    cell = trim(cell)
    while (1) {
      L2 = length(cell)
      if (L2 >= 5 && ((substr(cell, 1, 2) == "**" && substr(cell, L2 - 1) == "**") || (substr(cell, 1, 2) == "__" && substr(cell, L2 - 1) == "__"))) cell = substr(cell, 3, L2 - 4)
      else if (L2 >= 3 && ((c1 = substr(cell, 1, 1)) == "*" || c1 == "_" || c1 == "`") && substr(cell, L2, 1) == c1) cell = substr(cell, 2, L2 - 2)
      else break
      cell = trim(cell)
    }
    if (cell ~ /^PT-[0-9]+$/) {
      num = substr(cell, 4)
      if (index(ld, "\t") || substr(ld, 1, 4) == "    ") { print "B\ta PT row indented past three spaces (not a table row) in " path " at " W > REC; continue }
      count(num, W, path)
    } else if (cell ~ /^[A-Z]+-[0-9]+$/) print "Q\tF\t" idx "\t" g "\t" cell > REC
    else if (cell ~ /PT-[0-9]/) print "Q\tP\t" idx "\t" g "\t" cell > REC
  }
}
function readfile(e,   src, r, ln) {
  src = Src[e]; nl = 0
  r = (getline ln < src)
  if (r < 0) { print "U\t" e "\t" G[e] > REC; return }
  while (r > 0) { buf[++nl] = ln; r = (getline ln < src) }
  close(src)
  judge(e, G[e], Pth[e])
}
function adv() {
  cur++
  while (cur <= ne && K[cur] != "b") {
    if (K[cur] == "x") print "X\t" cur "\t" G[cur] > REC
    else if (K[cur] == "u") print "U\t" cur "\t" G[cur] > REC
    else if (K[cur] == "m") print "N\t" cur > REC
    else if (K[cur] == "f") readfile(cur)
    cur++
  }
}
function field(s, n,   i, t) { for (i = 1; i < n; i++) { t = index(s, "\t"); s = substr(s, t + 1) } ; t = index(s, "\t"); return t ? substr(s, 1, t - 1) : s }
BEGIN {
  VT = sprintf("%c", 11); SP = "[ \t\r\f" VT "]"
  HDR = "[Pp][Rr][Ee][Ff][Ii][Xx]: PT · [Nn][Uu][Mm][Bb][Ee][Rr][Ii][Nn][Gg]: global(" SP "|\\)|·|-->)"
  PFX = ENVIRON["PFX"]; REC = ENVIRON["REC"]; MAX = 0
  while ((getline ln < ENVIRON["JGROUPS"]) > 0) { g = field(ln, 1); GC[g] = field(ln, 2); t = index(ln, "\t"); r = substr(ln, t + 1); t = index(r, "\t"); GL[g] = substr(r, t + 1) }
  close(ENVIRON["JGROUPS"])
  ne = 0
  while ((getline ln < ENVIRON["LIST"]) > 0) {
    ne++; K[ne] = field(ln, 2); G[ne] = field(ln, 3); Pth[ne] = field(ln, 4)
    r = ln; for (i = 1; i <= 4; i++) { t = index(r, "\t"); r = substr(r, t + 1) } ; Src[ne] = r
  }
  close(ENVIRON["LIST"])
  cur = 0; adv(); state = 0
}
state == 0 {
  if ($0 ~ / missing$/) { print "U\t" cur "\t" G[cur] > REC; adv(); next }
  size = $3 + 0; got = 0; nl = 0
  if (size == 0) { judge(cur, G[cur], Pth[cur]); adv(); state = 2 } else state = 1
  next
}
state == 1 {
  buf[++nl] = $0; got += length($0) + 1
  if (got >= size) { judge(cur, G[cur], Pth[cur]); adv(); state = (got == size) ? 2 : 0 }
  next
}
state == 2 { state = 0; next }
END {
  while (cur <= ne) { if (K[cur] == "b") { print "U\t" cur "\t" G[cur] > REC; adv() } else adv() }
  print "M\t" MAX > REC
}
AWK
LIST="$work/list"; OIDS="$work/oids"; GRPF="$work/groups"
plan_reset() { : > "$LIST"; : > "$OIDS"; : > "$GRPF"; ng=0; ni=0; }
plan_group() { ng=$((ng + 1)); printf '%s\t%s\t%s\n' "$ng" "$1" "$2" >> "$GRPF"; glabel[ng]="$2"; }   # class, label
plan_entry() { ni=$((ni + 1)); gnames[ni]="$3"; printf '%s\t%s\t%s\t%s\t%s\n' "$ni" "$1" "$ng" "$2" "$4" >> "$LIST"; }   # kind, listed path, name, src
plan_ref() { # a git ref, its label: every pair file at that ref, queued (one ls-tree)
  local ref="$1" label="$2" ent meta path kind c rest obj cls
  case "$label" in tip*) cls=tip ;; "branch HEAD") cls=mine ;; *) cls=others ;; esac
  plan_group "$cls" "$label"
  if ! git -C "$clone" ls-tree -z "$ref" -- "$dir/" > "$work/ls" 2>/dev/null; then
    msgs[ni + 1]="$label: the tree could not be listed"; plan_entry m - "" ""; return 0
  fi
  while IFS= read -r -d '' ent; do
    meta="${ent%%"$TAB"*}"; path="${ent#*"$TAB"}"
    kind="${meta#* }"; rest="${kind#* }"; kind="${kind%% *}"; obj="${rest%% *}"
    [ "$kind" = blob ] || continue
    classify "$path"; c=$?
    [ "$c" = 1 ] && continue
    if [ "$c" = 2 ]; then plan_entry x - "$path" ""; continue; fi
    plan_entry b "$path" "$path" "$ref"; printf '%s\n' "$obj" >> "$OIDS"
  done < "$work/ls"
}
plan_run() { # judge the whole plan: one cat-file --batch for every queued blob, one awk; then word the records
  local stream="$work/stream" l i g rest cell nm
  if [ -s "$OIDS" ] && ! git -C "$clone" cat-file --batch < "$OIDS" > "$stream" 2>/dev/null; then
    # cat-file could not serve the batch (a partial clone whose promisor is away): read each blob alone, so a
    # missing one is unread by name and the others are still judged, exactly as one read per file
    local fb="$work/fb" k gg p s ln
    rm -rf "${fb:?}"; mkdir -p "$fb"
    while IFS= read -r ln; do
      i="${ln%%"$TAB"*}"; rest="${ln#*"$TAB"}"; k="${rest%%"$TAB"*}"; rest="${rest#*"$TAB"}"; gg="${rest%%"$TAB"*}"; rest="${rest#*"$TAB"}"; p="${rest%%"$TAB"*}"; s="${rest#*"$TAB"}"
      if [ "$k" = b ]; then
        if git -C "$clone" show "$s:$p" > "$fb/$i" 2>/dev/null; then printf '%s\tf\t%s\t%s\t%s\n' "$i" "$gg" "$p" "$fb/$i"; else printf '%s\tu\t%s\t%s\t\n' "$i" "$gg" "$p"; fi
      else printf '%s\n' "$ln"; fi
    done < "$LIST" > "$LIST.fb"
    mv "$LIST.fb" "$LIST"; : > "$stream"
  elif [ ! -s "$OIDS" ]; then : > "$stream"; fi
  # the judge's seen lines go straight to the seen file (buffered stdout); its few records to REC
  : > "$work/rec"
  PFX="$prefix" REC="$work/rec" JGROUPS="$GRPF" LIST="$LIST" LC_ALL=C awk "$JUDGE_AWK" < "$stream" >> "$SEENF"
  while IFS= read -r l; do
    case "$l" in
      B"$TAB"*) bad+=("${l#B"$TAB"}") ;;
      M"$TAB"*) i="${l#M"$TAB"}"; [ "$i" -gt "$max" ] && max="$i" ;;
      N"$TAB"*) i="${l#N"$TAB"}"; unread "${msgs[i]}" ;;
      X"$TAB"*|U"$TAB"*)
        rest="${l#?"$TAB"}"; i="${rest%%"$TAB"*}"; g="${rest#*"$TAB"}"; nm="${gnames[i]}"
        case "$l" in
          X*) if [ "${glabel[g]}" = "working tree" ]; then bad+=("a pair file named outside $NAMESHAPE: $(printable "$nm") in the working tree"); else bad+=("a pair file named outside $NAMESHAPE: $(printable "$nm") at ${glabel[g]}"); fi ;;
          *) unread "${glabel[g]}: $(printable "$nm") could not be read" ;;
        esac ;;
      Q"$TAB"?"$TAB"*)
        rest="${l#Q"$TAB"?"$TAB"}"; i="${rest%%"$TAB"*}"; rest="${rest#*"$TAB"}"; g="${rest%%"$TAB"*}"; cell="${rest#*"$TAB"}"; nm="${gnames[i]}"
        case "$l" in
          Q"$TAB"F*) bad+=("a first cell carrying another prefix, $(printable "$cell") (a handbook-question), in $(printable "$nm") at ${glabel[g]}") ;;
          *) bad+=("a PT id in first-cell position that is not a counted row, $(printable "$cell"), in $(printable "$nm") at ${glabel[g]}") ;;
        esac ;;
    esac
  done < "$work/rec"
}
exit2_after_flush() { plan_run; echo "$1" >&2; exit 2; }   # a refusal in the working tree: the places before it were read, as they always were
realdir() { ( cd "$1" 2>/dev/null && pwd -P ); }

# 1. the tip, fetched and pruned (a clone whose fetch refspec does not cover every head cannot see sibling branches)
originurl=""
if originurl="$(git -C "$clone" remote get-url origin 2>/dev/null)"; then
  git -C "$clone" config --get-all remote.origin.fetch 2>/dev/null | grep -q 'refs/heads/\*' || { echo "port_rule_reserve: origin's fetch refspec does not cover refs/heads/* (a --single-branch clone?) -- sibling branches would be unread, nothing is reserved" >&2; exit 2; }
  if [ "$fetch" = 1 ]; then
    git -C "$clone" fetch -q --prune origin >/dev/null 2>&1 || { echo "port_rule_reserve: fetching origin failed -- the tip is unread, nothing is reserved" >&2; exit 2; }
  fi
  tipref="origin/$base"
  git -C "$clone" rev-parse --verify -q "$tipref" >/dev/null || { echo "port_rule_reserve: origin/$base does not resolve in $clone -- the tip is unread, nothing is reserved" >&2; exit 2; }
else
  originurl=""
  tipref="$base"
  git -C "$clone" rev-parse --verify -q "$tipref" >/dev/null || { echo "port_rule_reserve: $clone has no origin and $base does not resolve -- the tip is unread, nothing is reserved" >&2; exit 2; }
  echo "port_rule_reserve: $clone has no origin; the local $base is the tip" >&2
fi
if [ "$pairs_ship" = 1 ] && [ "$(git -C "$clone" cat-file -t "$tipref:$pair" 2>/dev/null)" != blob ]; then
  pname="${pair##*/}"; pname="${pname%.md}"
  echo "port_rule_reserve: pair $(printable "$pname") has no pair file $(printable "$pair") at the tip $tipref; at handbooks $htag (>= v0.11.0) every directed pair of product stacks ships its file (CON-13, zheref/bankai-handbooks#21), so bankai-rule appends rows and never creates one -- refusing, nothing is reserved" >&2
  exit 2
fi
plan_reset
plan_ref "$tipref" "tip $tipref"

# 2. this run's own branch: HEAD and the working tree (regular files inside the worktree, never a symlink)
plan_ref HEAD "branch HEAD"
if [ -L "$clone/$dir" ]; then exit2_after_flush "port_rule_reserve: $clone/$dir is a symlink -- refusing to read it"; fi
if [ -d "$clone/$dir" ]; then
  ddir="$(realdir "$clone/$dir")"; wdir="$(realdir "$clone")"
  case "$ddir/" in "$wdir"/*) ;; *) exit2_after_flush "port_rule_reserve: $clone/$dir resolves outside the worktree -- refusing to read it" ;; esac
  shopt -s nullglob dotglob
  plan_group mine "working tree"
  for f in "$clone/$dir"/*; do
    rel="$dir/${f##*/}"
    classify "$rel"; c=$?
    [ "$c" = 1 ] && continue
    if [ -L "$f" ] || [ ! -f "$f" ]; then
      exit2_after_flush "port_rule_reserve: $(printable "$f") is a symlink or not a regular file -- refusing to read it"
    fi
    if [ "$c" = 2 ]; then plan_entry x - "$rel" ""; else plan_entry f "$rel" "$rel" "$f"; fi
  done
  shopt -u nullglob dotglob
elif [ -e "$clone/$dir" ]; then
  exit2_after_flush "port_rule_reserve: $clone/$dir is not a directory -- refusing to read it"
fi

# 3. every rulings branch already pushed to origin, and every local ports-* head of this clone that is not
#    this run's own (another run authoring in the same clone; ports-* at one to four path segments)
current="$(git -C "$clone" symbolic-ref -q --short HEAD 2>/dev/null || true)"
if ! refs="$(git -C "$clone" for-each-ref --format='%(refname)%09%(refname:short)' 'refs/remotes/origin/ports-*' 'refs/remotes/origin/*/ports-*' 'refs/remotes/origin/*/*/ports-*' 'refs/remotes/origin/*/*/*/ports-*' 'refs/heads/ports-*' 'refs/heads/*/ports-*' 'refs/heads/*/*/ports-*' 'refs/heads/*/*/*/ports-*' 2>/dev/null)"; then
  msgs[ni + 1]="the rulings branches of $clone could not be listed"; plan_group others "-"; plan_entry m - "" ""; refs=""
fi
# every local branch's upstream, read ONCE (never two git config calls per head)
bcfg="$(git -C "$clone" config --get-regexp '^branch\..*\.(merge|remote)$' 2>/dev/null || true)"
bconf() { # branch, key: its configured value in REPLY, or empty (no subshell)
  local want="branch.$1.$2 " line
  REPLY=""
  while IFS= read -r line; do case "$line" in "$want"*) REPLY="${line#"$want"}"; return 0 ;; esac; done <<< "$bcfg"
  return 0
}
skip_pull=0; skip_remote=0
while IFS="$TAB" read -r full short; do
  [ -n "$full" ] || continue
  [ "$short" = "$tipref" ] && continue
  if [ -n "$current" ]; then
    [ "$full" = "refs/heads/$current" ] && continue
    if [ "$full" = "refs/remotes/origin/$current" ] && git -C "$clone" merge-base --is-ancestor "$full" HEAD 2>/dev/null; then
      continue  # this run's own push (an ancestor of HEAD): read as HEAD; a same-named branch that is not is a sibling
    fi
  fi
  case "$full" in
    refs/heads/*)
      bname="${full#refs/heads/}"
      bconf "$bname" merge; umerge="$REPLY"; bconf "$bname" remote; uremote="$REPLY"
      case "$umerge" in refs/pull/*) skip_pull=$((skip_pull + 1)); continue ;; esac
      if [ -n "$uremote" ] && [ "$uremote" != . ]; then
        uurl="$(git -C "$clone" remote get-url "$uremote" 2>/dev/null)" || uurl="$uremote"
        if [ -z "$originurl" ] || [ "$uurl" != "$originurl" ]; then skip_remote=$((skip_remote + 1)); continue; fi
      fi
      ;;
  esac
  plan_ref "$full" "branch $short"
done <<< "$refs"
plan_run   # the tip, HEAD, the working tree and every sibling, judged in that order
if [ "$skip_pull" -gt 0 ]; then
  seenadd "skipped $skip_pull local head(s): a PR checkout (merge ref refs/pull/*)"
  echo "port_rule_reserve: skipped $skip_pull local ports-* head(s) tracking refs/pull/* (a PR checkout, not a rulings run)" >&2
fi
if [ "$skip_remote" -gt 0 ]; then
  seenadd "skipped $skip_remote local head(s): tracking a remote whose URL is not origin's"
  echo "port_rule_reserve: skipped $skip_remote local ports-* head(s) tracking a remote whose URL is not origin's" >&2
fi

# 4. every open same-repository PR whose file list names a pair file; a fork PR is never read, only listed
total="$(gh api "search/issues?q=repo:${target}+is:pr+is:open" --jq '.total_count' 2>/dev/null)" || { echo "port_rule_reserve: the open-PR total of $target could not be read" >&2; exit 1; }
prs="$(gh pr list --repo "$target" --state open --limit 1000 --json number,headRefName,isCrossRepository,changedFiles,headRefOid --jq '.[] | "\(.number)\t\(.isCrossRepository)\t\(.changedFiles)\t\(.headRefName)\t\(.headRefOid)"' 2>/dev/null)" || { echo "port_rule_reserve: gh pr list failed for $target" >&2; exit 1; }
count=0; [ -n "$prs" ] && count="$(printf '%s\n' "$prs" | grep -c .)"
if [ "$count" != "$total" ]; then
  echo "port_rule_reserve: the open-PR list of $target is short ($count read of $total open) -- an unread PR is never a clean one" >&2
  exit 1
fi
while IFS="$TAB" read -r num fork changed ref oid; do
  [ -n "$num" ] || continue
  [[ "$num" =~ ^[0-9]+$ ]] || { unread "an open PR listed with a non-numeric number"; continue; }
  if [ "$fork" = true ]; then seenadd "PR #$num fork, not read"; continue; fi
  if [ -n "$current" ] && [ "$ref" = "$current" ] && [[ "${oid-}" =~ ^[0-9a-f]{40}$ ]] \
     && git -C "$clone" merge-base --is-ancestor "$oid" HEAD 2>/dev/null; then
    seenadd "PR #$num this run's own branch, read as HEAD"; continue
  fi
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
    # only that pair file's added lines, the leading + stripped: the header is matched literally and only inside a file's header region
    section="$(printf '%s\n' "$diff" | awk -v f="+++ b/$fl" 'BEGIN{p=0;h=0} /^diff --git /{p=0;h=1;next} /^@@/{h=0} (h && index($0, f) == 1 && length($0) == length(f)){p=1;next} p && /^\+/{print substr($0, 2)}')"
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
    printf '%s\n' "$section" > "$work/section"
    plan_reset; plan_group others "$where"; plan_entry f "$fl" "$fl" "$work/section"; plan_run
  done
done <<< "$prs"

if [ "${#bad[@]}" -gt 0 ]; then
  echo "port_rule_reserve: refusing to reserve -- a counted place carries an id outside ^[1-9][0-9]{0,8}$, a row or first cell out of shape, a pair file named out of shape, or a foreign pair-file header (settle it first):" >&2
  for b in "${bad[@]}"; do echo "  $b" >&2; done
  exit 3
fi

if [ "$check" = 1 ]; then
  # one counter across every pair file: an id this branch adds collides with the same id ANYWHERE else --
  # the tip in another file, a sibling or a PR in any file, this branch's own row in a second file, or a
  # second row of the same file in one of this branch's places. Judged ONCE, after collection, by one awk
  # over the three id lists (linear in rows), the messages then sorted unique.
  # the counted ids are re-read from the seen file: each is one line `PT-<n> <where> in <file>`, the file a
  # shape-checked path (no space), so the where is what lies between; the class follows the where
  dupsout="$(LC_ALL=C awk -v pfx="$prefix" -v tipref="$tipref" '
      substr($0, 1, 3) != "PT-" { next }
      { sp = index($0, " "); n = substr($0, 4, sp - 4); if (n == "" || n ~ /[^0-9]/) next
        f = $NF; rest = substr($0, sp + 1); w = substr(rest, 1, length(rest) - length(f) - 4)
        if (substr(w, 1, 4) == "tip ") { k = n SUBSEP f; tc[k]++; tf[n] = tf[n] f "\n"; next }
        if (w == "branch HEAD" || w == "working tree") { k = n "\t" f "\t" w; mc[k]++; d = n SUBSEP f; if (!(d in md)) { md[d] = 1; mn[++nm] = n; mf[nm] = f }
                  mlist[n] = mlist[n] f "\t" w "\n"; next }
        on[++no] = n; of[no] = f; ow[no] = w }
      END {
        for (k in mc) if (mc[k] >= 2) { split(k, a, "\t"); if (tc[a[1] SUBSEP a[2]] >= 2) continue
          print pfx "-" a[1] " (" a[2] ") also at a second row of the same file (" a[3] ")" }
        for (i = 1; i <= no; i++) if (!((on[i] SUBSEP of[i]) in tc)) ob[on[i]] = ob[on[i]] of[i] "\t" ow[i] "\n"
        for (j = 1; j <= nm; j++) { n = mn[j]; f = mf[j]; if ((n SUBSEP f) in tc) continue
          c = split(tf[n], L, "\n"); for (x = 1; x <= c; x++) if (L[x] != "") print pfx "-" n " (" f ") also at tip " tipref " (" L[x] ")"
          c = split(ob[n], L, "\n"); for (x = 1; x <= c; x++) if (L[x] != "") { split(L[x], b, "\t"); print pfx "-" n " (" f ") also at " b[2] " (" b[1] ")" }
          c = split(mlist[n], L, "\n"); for (x = 1; x <= c; x++) if (L[x] != "") { split(L[x], b, "\t"); if (b[1] != f) print pfx "-" n " (" f ") also at " b[2] " (" b[1] ")" } }
      }' "$SEENF")"
  if [ -n "$dupsout" ]; then
    echo "port_rule_reserve --check: this branch adds an id another place carries (one counter across every pair file) -- renumber this branch's rows (never a merged one):" >&2
    printf '%s\n' "$dupsout" | sort -u | sed 's/^/  /' >&2
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
  # every seen line as a JSON string: quote, backslash and every U+0000-U+001F escaped, in one awk pass
  LC_ALL=C awk 'BEGIN { for (i = 1; i < 32; i++) cc[sprintf("%c", i)] = i; re = "[\"\\\\"; for (i = 1; i < 32; i++) re = re sprintf("%c", i); re = re "]"; first = 1 }
    { s = $0
      if (s ~ re) { o = ""; L = length(s)
        for (i = 1; i <= L; i++) { c = substr(s, i, 1)
          if (c == "\"") o = o "\\\""; else if (c == "\\") o = o "\\\\"
          else if (c in cc) { k = cc[c]; if (k == 9) o = o "\\t"; else if (k == 10) o = o "\\n"; else if (k == 13) o = o "\\r"; else o = o sprintf("\\u%04x", k) }
          else o = o c }
        s = o }
      printf "%s\"%s\"", (first ? "" : ","), s; first = 0 }' "$SEENF"
  printf ']}\n'
else
  if [ "$complete" = true ]; then printf 'next: %s-%s\n' "$prefix" "$next"; else printf 'next: (none reserved -- the read was incomplete)\n'; fi
  LC_ALL=C awk '{ print "  seen: " $0 }' "$SEENF"
fi
exit "$rc"
