#!/usr/bin/env bash
# pr_development_link_check.sh — refuse a pull request whose closing issues are not linked both ways in
# GitHub's Development field (zheref/hatsu#203; claude/skills/shibari/SKILL.md § 3, ruling 2026-09-12).
#
#   scripts/pr_development_link_check.sh --pr <owner/name#N> [--fixture <dir>]
#   scripts/pr_development_link_check.sh --body <file> --target <owner/name>
#   scripts/pr_development_link_check.sh --self-test
#
# THE EXPECTED SET IS DERIVED FROM THE BODY, never restated. The body's one `## Associated issues`
# section holds a pipe table whose header names an *Issue* and a *Merging this* column
# (templates/pr-body.md). Each row's VERDICT is the cell's leading bold span, or its text up to the
# first ` — `, ` - `, ` (`, `; `, `: `, `, ` or `. `, lowercased, ASCII only, and it must be one of a
# CLOSED VOCABULARY, matched as whole words:
#   closing      completes it · completes · closes it · closes
#   non-closing  delivers part · delivers part of it · part of · part of it · cited · cited only ·
#                prerequisite · relates to it · delivers none of it
# The issue cell holds a canonical issue URL, `owner/name#N` or a bare `#N` (this repository); a bare
# `#N` beside a URL is link text. The closing rows are the expected closing set.
#
# FAIL CLOSED. Anything the parser does not model is refused by name (exit 1), never guessed past:
# a NUL byte, invalid UTF-8, a lone CR; a fence-like line that is not a lone fence, a fence closed by
# anything but its own character and length, a fence or HTML comment never closed; an HTML comment not
# at line start (code spans are stripped first) or with text after its `-->`; an unbalanced code span;
# no `## Associated issues` section (a PR with no associated issue says so in that section), a second
# one, or a lookalike heading (ATX with closing hashes and setext headings are read); a pipe row
# without a leading pipe, a pipe row with no delimiter row, a line directly under the table (GitHub
# continues the table into it), a second table with both columns, an Issue column with no Merging
# column; a verdict outside the vocabulary or not ASCII (it is refused, not normalised); an alias
# reference such as `HA#3` with no URL, a pull request URL, a `.`/`..` segment; more than 50 distinct
# references (the API budget). An escaped `\|` stays inside its cell.
#
# KEYWORDS. GitHub links `close[sd]?|fix(e[sd])?|resolve[sd]?`, an optional colon, then a reference,
# ANYWHERE outside code — so any such keyword whose reference is not a closing row is refused, in both
# modes. Each closing row also needs its OWN keyword line: the keyword and reference alone on a line,
# one trailing `.` allowed, `owner/name#N` or a URL for another repository.
#
# LIVE (--pr). On the default branch: the PR's closingIssuesReferences must equal the expected set,
# and each expected issue must list the PR in closedByPullRequestsReferences; a non-closing issue in
# either set is refused. On any other base the run prints `retarget-pending` and exits 1, never a
# pass: keywords and links do not act there (ROSTER, Rulings of 2026-09-29, ruling 2), and the closing
# set is verified on the PR that reaches the default branch. Remedies name GitHub's Development sidebar
# (at most 10 linked issues per PR) or the platform's GraphQL linking; there is no Nen verb, and no
# link is ever claimed.
#
# --body/--target checks the body alone, offline, before the PR exists.
# --fixture <dir> reads the GitHub half from files instead of gh (the pass line says GitHub was not read):
#   <dir>/repo.json                       gh repo view <o/n> --json defaultBranchRef
#   <dir>/pr.json                         gh pr view <N> --repo <o/n> --json number,baseRefName,body,closingIssuesReferences
#   <dir>/issues/<owner>/<name>/<N>.json  gh issue view <N> --repo <o/n> --json number,closedByPullRequestsReferences
#   (owner and name lowercased)
# PR_DEV_LINK_AWK names the awk to run (default `awk`); the self-test uses it to prove the parser's
# failure modes are exit 2.
#
# exit 0  every closing row is keyworded, no other keyword acts, and both directions match exactly
# exit 1  at least one refusal; every one is listed on stderr, control characters replaced by `?`
# exit 2  GitHub (or the fixture) could not be read, malformed JSON, the parser failed or is absent,
#         jq or iconv missing, or a usage error
#
# Bash 3.2 portable: no associative arrays; sets are newline-delimited temp files; awk runs under LC_ALL=C.

AWK="${PR_DEV_LINK_AWK:-awk}"
REF_CAP=50

usage() {
  echo "usage: pr_development_link_check.sh --pr <owner/name#N> [--fixture <dir>]" >&2
  echo "       pr_development_link_check.sh --body <file> --target <owner/name>" >&2
  echo "       pr_development_link_check.sh --self-test" >&2
}

die2() { echo "pr_development_link_check.sh: $*" >&2; exit 2; }
printable() { LC_ALL=C tr -c '[:print:]\n' '?'; }

# parse_body <default owner/name> < body: one tab-separated record per line —
#   FAIL <message> · ROW completes|other <o/n#N> · KW <o/n#N> (own line) · IKW <o/n#N> (anywhere) ·
#   SECTION absent|table|none · and last, END <lines>
parse_body() {
  LC_ALL=C "$AWK" -v def="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function clean(s) { gsub(PH, "|", s); gsub(CNTRL, "?", s); return s }
    function fail(i, msg) { print "FAIL\t" clean((i ? "line " i ": " : "") msg) }
    function norm(s) { s = tolower(s); gsub(/[*_`]/, "", s); gsub(/[ \t]+/, " ", s); return trim(s) }
    function dots(r,    t) { split(r, t, /[\/#]/); return (t[1] == "." || t[1] == ".." || t[2] == "." || t[2] == "..") }
    function strip_spans(s,    out, n, rest, found) {
      out = ""; UNBAL = 0
      while ((p = index(s, "`")) > 0) {
        out = out substr(s, 1, p - 1); s = substr(s, p)
        match(s, /^`+/); n = RLENGTH; rest = substr(s, n + 1); found = 0
        while (match(rest, /`+/)) {
          if (RLENGTH == n) { rest = substr(rest, RSTART + RLENGTH); found = 1; break }
          rest = substr(rest, RSTART + RLENGTH)
        }
        if (!found) { UNBAL = 1; return out s }
        out = out " "; s = rest
      }
      return out s
    }
    function cellrefs(s, out,    n, u, t, found, b) {
      n = 0; found = 0; s = tolower(s); BADKIND = ""; HASPULL = 0
      while (match(s, /https?:\/\/github\.com\/[a-z0-9_.-]+\/[a-z0-9_.-]+\/(issues|pull)\/[0-9]+/)) {
        u = substr(s, RSTART, RLENGTH); s = substr(s, 1, RSTART - 1) " " substr(s, RSTART + RLENGTH)
        sub(/^https?:\/\/github\.com\//, "", u); split(u, t, "/")
        if (t[3] == "pull") { HASPULL = 1; found = 1; continue }
        out[++n] = t[1] "/" t[2] "#" t[4]; found = 1
      }
      while (match(s, /[a-z0-9_.-]+\/[a-z0-9_.-]+#[0-9]+/)) {
        out[++n] = substr(s, RSTART, RLENGTH); s = substr(s, 1, RSTART - 1) " " substr(s, RSTART + RLENGTH); found = 1
      }
      if (!found) while (match(s, /#[0-9]+/)) {
        b = (RSTART > 1) ? substr(s, RSTART - 1, 1) : " "
        if (b ~ /[a-z0-9_-]/) BADKIND = "alias"
        else out[++n] = def substr(s, RSTART, RLENGTH)
        s = substr(s, RSTART + RLENGTH)
      }
      for (k = 1; k <= n; k++) if (dots(out[k])) BADKIND = "dots"
      return n
    }
    function kwref(m,    t) {
      if (m ~ /^https?:\/\//) { sub(/^https?:\/\/github\.com\//, "", m); split(m, t, "/"); m = t[1] "/" t[2] "#" t[4] }
      else if (m ~ /^#/) m = def m
      return dots(m) ? "" : m
    }
    function verdict(c,    m, e, v, p, best, k, d) {
      m = tolower(trim(c)); d = substr(m, 1, 2)
      if (d == "**" || d == "__") { e = index(substr(m, 3), d); v = e ? substr(m, 3, e - 1) : substr(m, 3) }
      else {
        best = length(m) + 1
        for (k = 1; k <= NSEP; k++) { p = index(m, SEP[k]); if (p && p < best) best = p }
        v = substr(m, 1, best - 1)
      }
      v = norm(v); sub(/[.:;,]+$/, "", v); return trim(v)
    }
    function isdelim(r) {
      return index(r, "|") && r ~ /^ *\|?[ \t]*:?-+:?[ \t]*(\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$/
    }
    function cells(r, arr,    s, n, k) {
      s = trim(r); sub(/^\|/, "", s); sub(/\|$/, "", s)
      n = split(s, arr, "|")
      for (k = 1; k <= n; k++) { arr[k] = trim(arr[k]); gsub(PH, "|", arr[k]) }
      return n
    }
    BEGIN {
      CNTRL = "[\001-\037\177]"; PH = "\034"
      KW = "(close[sd]?|fix(e[sd])?|resolve[sd]?)"
      REF = "(https?://github\\.com/[a-z0-9_.-]+/[a-z0-9_.-]+/issues/[0-9]+|[a-z0-9_.-]+/[a-z0-9_.-]+#[0-9]+|#[0-9]+)"
      KWRE = KW ":?[ \t]+" REF; KWLINE = "^" KW ":?[ \t]+" REF "\\.?$"
      NSEP = split(" \342\200\224 | \342\200\223 | - | (|; |: |, |. ", SEP, "|")
      split("completes it|completes|closes it|closes", a, "|"); for (k in a) CLOSING[a[k]] = 1
      split("delivers part|delivers part of it|part of|part of it|cited|cited only|prerequisite|relates to it|delivers none of it", a, "|")
      for (k in a) OTHER[a[k]] = 1
    }
    { L[NR] = $0 }
    END {
      n = NR; fence = 0; com = 0
      for (i = 1; i <= n; i++) {
        line = L[i]; sub(/\r$/, "", line)
        if (index(line, "\r")) { fail(i, "a lone carriage return, which the parser does not model"); gsub(/\r/, " ", line) }
        gsub(/\\\|/, PH, line)
        kind[i] = "text"; raw[i] = line; txt[i] = ""
        match(line, /^[ \t]*/); ind = substr(line, 1, RLENGTH); gsub(/\t/, "    ", ind); indent[i] = length(ind)
        isfence = (indent[i] < 4 && line ~ /^ *(```+|~~~+)/)
        if (isfence) { s2 = line; sub(/^ */, "", s2); match(s2, /^(`+|~+)/); run = substr(s2, 1, RLENGTH); rest = substr(s2, RLENGTH + 1) }
        if (fence) {
          kind[i] = "code"
          if (isfence) {
            if (substr(run, 1, 1) == fch && length(run) == flen && rest ~ /^[ \t]*$/) fence = 0
            else fail(i, "a fence-like line inside the code block opened at line " fopen " that does not close it exactly")
          }
          continue
        }
        if (com) {
          kind[i] = "comment"; e = index(line, "-->")
          if (e) { com = 0; if (substr(line, e + 3) !~ /^[ \t]*$/) fail(i, "text after the --> that closes an HTML comment") }
          continue
        }
        if (isfence) {
          kind[i] = "code"; fch = substr(run, 1, 1); flen = length(run)
          if (fch == "`" && index(rest, "`")) fail(i, "a line starting with a backtick run that is not a fence")
          else { fence = 1; fopen = i }
          continue
        }
        if (indent[i] < 4 && line ~ /^ *<!--/) {
          kind[i] = "comment"; after = substr(line, index(line, "<!--") + 4); e = index(after, "-->")
          if (!e) com = 1
          else if (substr(after, e + 3) !~ /^[ \t]*$/) fail(i, "text after the --> that closes an HTML comment")
          continue
        }
        t = strip_spans(line)
        if (UNBAL) fail(i, "an unbalanced code span (a backtick run with no closing run on its line)")
        if (index(t, "<!--")) { fail(i, "an HTML comment that does not start its line"); kind[i] = "comment"; continue }
        txt[i] = t
      }
      if (fence) fail(0, "the code fence opened at line " fopen " never closes; it would hide the rest of the body")
      if (com) fail(0, "an HTML comment never closes; it would hide the rest of the body")

      for (i = 1; i <= n; i++) {
        if (kind[i] != "text" || indent[i] >= 4 || txt[i] !~ /^ *#+([ \t]|$)/) continue
        h = txt[i]; sub(/^ */, "", h); match(h, /^#+/); lvl = RLENGTH
        if (lvl > 6) continue
        h = substr(h, lvl + 1); sub(/[ \t]+#+[ \t]*$/, "", h); sub(/^[ \t]*#+[ \t]*$/, "", h)
        head[i] = lvl; htxt[i] = trim(h)
      }
      for (i = 2; i <= n; i++) {
        if (kind[i] != "text" || kind[i - 1] != "text" || head[i - 1] || under[i - 1] || indent[i] >= 4 || indent[i - 1] >= 4) continue
        if (txt[i] !~ /^ *(=+|-+)[ \t]*$/ || txt[i - 1] ~ /^[ \t]*$/ || txt[i - 1] ~ /^ *(\||>|[-*+][ \t]|[0-9]+[.)][ \t])/) continue
        head[i - 1] = (txt[i] ~ /=/) ? 1 : 2; htxt[i - 1] = trim(txt[i - 1]); under[i] = 1
      }

      ss = 0; se = n; ins = 0
      for (i = 1; i <= n; i++) {
        if (head[i]) {
          h = norm(htxt[i])
          if (h == "associated issues" && head[i] == 2) {
            if (ss) fail(i, "a second Associated issues section")
            else { ss = i + (under[i + 1] ? 2 : 1); ins = 1; continue }
          } else if (h ~ /associated/ && h ~ /issue/) fail(i, "a heading that looks like the Associated issues section but is not exactly `## Associated issues`: " htxt[i])
          if (ins) { se = i - 1; ins = 0 }
        } else if (kind[i] == "text" && !under[i]) {
          p = norm(txt[i]); sub(/:$/, "", p)
          if (p == "associated issues") fail(i, "a line that looks like the Associated issues heading but is not one")
        }
      }

      tstate = 0; matched = 0; stext = ""
      if (ss) for (j = ss; j <= se; j++) {
        if (kind[j] != "text") { tstate = 0; continue }
        t = txt[j]; r = raw[j]
        if (t ~ /^[ \t]*$/) { tstate = 0; continue }
        if (indent[j] >= 4) {
          if (index(t, "|") || tstate == 1) fail(j, "an indented line in or as a table, which the parser does not model")
          stext = stext " " tolower(t); continue
        }
        if (t !~ /^ *\|/) {
          if (index(t, "|")) { fail(j, "a pipe-table row without a leading pipe"); continue }
          if (tstate == 1) fail(j, "a line directly under the Associated issues table, which GitHub reads as another row; leave a blank line")
          tstate = 0; stext = stext " " tolower(t); continue
        }
        if (tstate == 0) {
          if (!(j < se && kind[j + 1] == "text" && isdelim(raw[j + 1]))) { fail(j, "a pipe row with no delimiter row under it"); continue }
          nc = cells(r, hc); icol = 0; mcol = 0
          for (k = 1; k <= nc; k++) { hh = tolower(hc[k]); if (!icol && hh ~ /issue/) icol = k; if (!mcol && hh ~ /merging/) mcol = k }
          if (icol && mcol) {
            if (matched) { fail(j, "a second table with Issue and Merging this columns"); tstate = 2 } else { matched = 1; tstate = 1 }
          } else {
            if (icol || mcol) fail(j, "a table with only one of the Issue and Merging this columns")
            tstate = 2
          }
          j++; continue
        }
        if (tstate == 2) continue
        nc = cells(r, dc)
        if (icol > nc || mcol > nc) { fail(j, "a row with no Issue or no Merging this cell"); continue }
        v = verdict(dc[mcol])
        if (v !~ /^[ -~]*$/) { fail(j, "a Merging this verdict that is not ASCII; it is refused, not normalised"); continue }
        if (v in CLOSING) cls = "completes"
        else if (v in OTHER) cls = "other"
        else { fail(j, "a Merging this verdict outside the closed vocabulary: `" v "` (closing: completes it, closes it; non-closing: delivers part, part of, cited, prerequisite, relates to it, delivers none of it)"); continue }
        k = cellrefs(dc[icol], o)
        if (BADKIND == "alias") fail(j, "an alias reference with no canonical URL (" dc[icol] "); use the canonical URL")
        else if (HASPULL && cls == "completes") fail(j, "a pull request URL on a closing row; a closing row names an issue")
        else if (HASPULL && k == 0) continue
        else if (BADKIND == "dots") fail(j, "a reference with a . or .. segment")
        else if (k == 0) fail(j, "an Associated issues row names no issue reference: " dc[icol])
        else for (q = 1; q <= k; q++) print "ROW\t" cls "\t" o[q]
      }
      if (!ss) print "SECTION\tabsent"
      else if (matched) print "SECTION\ttable"
      else if (stext ~ /(^|[^a-z])no associated issues?([^a-z]|$)/ || stext ~ /(^|[^a-z])none([^a-z]|$)/) print "SECTION\tnone"
      else fail(ss - 1, "the Associated issues section has neither the table nor a statement that the PR has no associated issue")

      for (i = 1; i <= n; i++) {
        if (kind[i] != "text") continue
        lt = tolower(txt[i]); gsub(PH, "|", lt); s = lt; any = 0
        while (match(s, KWRE)) {
          pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : " "
          m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
          if (pre ~ /[a-z0-9_]/) continue
          sub(/^[a-z]+:?[ \t]+/, "", m); r = kwref(m)
          if (r == "") { fail(i, "a closing keyword whose reference has a . or .. segment"); continue }
          any = 1; print "IKW\t" r
        }
        if (any && indent[i] >= 4) fail(i, "an indented closing keyword line, which the parser does not model")
        tl = trim(lt)
        if (indent[i] < 4 && tl ~ KWLINE) { m = tl; sub(/^[a-z]+:?[ \t]+/, "", m); sub(/\.$/, "", m); r = kwref(m); if (r != "") print "KW\t" r }
      }
      print "END\t" n
    }
  '
}

in_set() { grep -Fqx -- "$1" "$2" 2>/dev/null; }   # in_set <item> <file>
add_set() { in_set "$1" "$2" || printf '%s\n' "$1" >> "$2"; }

# fetch <kind> <owner/name> [<N>]: prints gh JSON (or the fixture's), validated; exit 2 on failure.
fetch() {
  local kind="$1" repo="$2" num="$3" out file
  if [ -n "$fixture" ]; then
    case "$kind" in
      repo) file="$fixture/repo.json" ;;
      pr) file="$fixture/pr.json" ;;
      issue) file="$fixture/issues/$repo/$num.json" ;;
    esac
    [ -f "$file" ] && [ -r "$file" ] || die2 "cannot read $kind $repo${num:+#$num}: fixture file '$file' is missing"
    out="$(cat "$file")"
  else
    case "$kind" in
      repo) out="$(gh repo view "$repo" --json defaultBranchRef 2>/dev/null </dev/null)" ;;
      pr) out="$(gh pr view "$num" --repo "$repo" --json number,baseRefName,body,closingIssuesReferences 2>/dev/null </dev/null)" ;;
      issue) out="$(gh issue view "$num" --repo "$repo" --json number,closedByPullRequestsReferences 2>/dev/null </dev/null)" ;;
    esac || die2 "GitHub could not be read: $kind $repo${num:+#$num}"
  fi
  printf '%s\n' "$out" | jq -e 'type == "object"' >/dev/null 2>&1 || die2 "malformed JSON for $kind $repo${num:+#$num}"
  printf '%s\n' "$out"
}

# check_body <body file> <owner/name> <work dir>: writes the expected/other/kw/ikw sets; prints refusals.
# Returns 0/1; sets too_many=1 when the reference cap is crossed (no issue is then read).
check_body() {
  local body="$1" repo="$2" w="$3" bad=0 kind a b r count
  too_many=0
  : > "$w/expected"; : > "$w/other"; : > "$w/kw"; : > "$w/ikw"
  if ! LC_ALL=C tr -d '\000' < "$body" | cmp -s - "$body"; then echo "body: a NUL byte, which the parser does not model" >&2; return 1; fi
  if ! iconv -f UTF-8 -t UTF-8 < "$body" > /dev/null 2>&1; then echo "body: not valid UTF-8, which the parser does not model" >&2; return 1; fi
  parse_body "$repo" < "$body" > "$w/parsed" || die2 "the body parser failed ($AWK exited non-zero); nothing is passed"
  [ "$(tail -n 1 "$w/parsed" | cut -f1)" = END ] || die2 "the body parser wrote no END record; its output is not trusted"
  while IFS="$(printf '\t')" read -r kind a b; do
    case "$kind" in
      ROW) if [ "$a" = completes ]; then add_set "$b" "$w/expected"; else add_set "$b" "$w/other"; fi ;;
      KW) add_set "$a" "$w/kw" ;;
      IKW) add_set "$a" "$w/ikw" ;;
      FAIL) echo "body: $a" >&2; bad=1 ;;
      SECTION) [ "$a" = absent ] && { echo "body: no \`## Associated issues\` section; a PR with no associated issue says so under that heading" >&2; bad=1; } ;;
    esac
  done < "$w/parsed"
  count="$(cat "$w/expected" "$w/other" "$w/ikw" | sort -u | grep -c .)"
  if [ "$count" -gt "$REF_CAP" ]; then
    echo "body: $count distinct issue references, over the cap of $REF_CAP; split the PR (no issue is read)" >&2; too_many=1; return 1
  fi
  while read -r r; do
    in_set "$r" "$w/other" && { echo "body: $r is a closing row and a non-closing row at once" >&2; bad=1; }
    in_set "$r" "$w/kw" || { echo "body: closing row $r has no keyword line of its own (\`Closes $r\`, alone on its line)" >&2; bad=1; }
  done < "$w/expected"
  while read -r r; do
    in_set "$r" "$w/expected" && continue
    if in_set "$r" "$w/other"; then echo "body: a closing keyword for $r, which the table marks non-closing; GitHub acts on a keyword anywhere outside code and would close it" >&2
    else echo "body: a closing keyword for $r, which the Associated issues table does not list as closing; GitHub would act on it" >&2; fi
    bad=1
  done < "$w/ikw"
  return $bad
}

check_pr() {  # check_pr <owner/name#N> <work dir>
  local self="$1" w="$2" repo num pr base def bad=0 missing=0 r o n set
  repo="${self%#*}"; num="${self##*#}"
  def="$(fetch repo "$repo")" || exit 2
  pr="$(fetch pr "$repo" "$num")" || exit 2
  base="$(printf '%s\n' "$pr" | jq -r '.baseRefName // empty' | printable)"
  def="$(printf '%s\n' "$def" | jq -r '.defaultBranchRef.name // empty' | printable)"
  [ -n "$base" ] && [ -n "$def" ] || die2 "baseRefName or defaultBranchRef missing for $self"
  printf '%s\n' "$pr" | jq -r '.body // ""' > "$w/body"
  printf '%s\n' "$pr" | jq -r '.closingIssuesReferences // [] | .[] | "\(.repository.owner.login)/\(.repository.name)#\(.number)" | ascii_downcase' > "$w/closing.raw" \
    || die2 "closingIssuesReferences unreadable for $self"
  printable < "$w/closing.raw" > "$w/closing"
  check_body "$w/body" "$repo" "$w" || bad=1
  [ "$too_many" -eq 1 ] && return 1
  while read -r r; do
    in_set "$r" "$w/closing" || { echo "pr side: missing: $r is a closing row but absent from $self closingIssuesReferences" >&2; bad=1; missing=1; }
  done < "$w/expected"
  while read -r r; do
    in_set "$r" "$w/expected" && continue
    if in_set "$r" "$w/other"; then echo "pr side: extra: $r is in $self closingIssuesReferences but the body marks it non-closing (merging would close it)" >&2
    else echo "pr side: extra: $r is in $self closingIssuesReferences but the Associated issues table does not list it as closing" >&2; fi
    bad=1
  done < "$w/closing"
  if [ "$base" != "$def" ]; then
    echo "retarget-pending (base '$base' is not the default branch '$def'): closing keywords and links do not act here; the closing set is verified on the PR that reaches the default branch. Never a pass." >&2
    echo "remedy: run this guard on the PR that reaches '$def'; a link needed sooner goes through GitHub's Development sidebar (at most 10 linked issues per PR) or the platform's GraphQL linking. There is no Nen verb, and no link is claimed." >&2
    return 1
  fi
  for set in expected other; do
    while read -r r; do
      o="${r%#*}"; n="${r##*#}"
      fetch issue "$o" "$n" > "$w/issue.json" || exit 2
      jq -r '.closedByPullRequestsReferences // [] | .[] | "\(.repository.owner.login)/\(.repository.name)#\(.number)" | ascii_downcase' < "$w/issue.json" > "$w/closedby" \
        || die2 "closedByPullRequestsReferences unreadable for $r"
      if [ "$set" = expected ]; then
        in_set "$self" "$w/closedby" || { echo "issue side: missing: $r does not list $self in closedByPullRequestsReferences" >&2; bad=1; missing=1; }
      else
        in_set "$self" "$w/closedby" && { echo "issue side: extra: $r lists $self in closedByPullRequestsReferences but the body marks it non-closing" >&2; bad=1; }
      fi
    done < "$w/$set"
  done
  if [ "$missing" -eq 1 ]; then
    echo "remedy: give each missing closing row its own \`Closes <ref>\` line and re-run, or link it through GitHub's Development sidebar (at most 10 linked issues per PR) or the platform's GraphQL linking. There is no Nen verb, and no link is claimed." >&2
  fi
  return $bad
}

self_test() {
  local st_self st_dir st_fails=0 args table m_body big k
  st_self="$(cd -P -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")"
  st_dir="$(mktemp -d)"; trap 'rm -rf "$st_dir"' EXIT
  refs_json() {  # refs_json <o/n#N ...>: a JSON array of gh reference objects
    local out="" r
    for r in "$@"; do
      out="$out${out:+,}{\"number\":${r##*#},\"repository\":{\"name\":\"$(printf '%s' "${r%#*}" | cut -d/ -f2)\",\"owner\":{\"login\":\"${r%%/*}\"}}}"
    done
    printf '[%s]' "$out"
  }
  mk() {  # mk <case> <base> <body> <closing refs, space-separated o/n#N>
    local d="$st_dir/$1"
    mkdir -p "$d"
    printf '{"defaultBranchRef":{"name":"main"}}\n' > "$d/repo.json"
    # shellcheck disable=SC2086
    jq -n --arg base "$2" --arg body "$3" --argjson c "$(refs_json $4)" \
      '{number:7,baseRefName:$base,body:$body,closingIssuesReferences:$c}' > "$d/pr.json"
  }
  issue() {  # issue <case> <o/n#N> <closed-by refs>
    local d="$st_dir/$1/issues/${2%#*}"
    mkdir -p "$d"
    # shellcheck disable=SC2086
    printf '{"number":%s,"closedByPullRequestsReferences":%s}\n' "${2##*#}" "$(refs_json $3)" > "$d/${2##*#}.json"
  }
  verdict() {  # verdict <label> <want> <got> [stderr file] [substring]
    if [ "$3" -eq "$2" ] && { [ -z "$5" ] || grep -Fq -- "$5" "$4"; }; then echo "ok    $1"
    else echo "FAIL  $1: want $2${5:+ with '$5'}, got $3${4:+: $(head -3 "$4" 2>/dev/null)}"; st_fails=$((st_fails + 1)); fi
  }
  run() {  # run <label> <want exit> <case> [stderr substring]
    local rc
    bash "$st_self" --pr octo/demo#7 --fixture "$st_dir/$3" > "$st_dir/$3.out" 2> "$st_dir/$3.err"; rc=$?
    verdict "$1" "$2" "$rc" "$st_dir/$3.err" "$4"
  }
  body() {  # body <label> <want exit> <body text> [stderr substring]
    local rc
    printf '%s\n' "$3" > "$st_dir/b.md"
    bash "$st_self" --body "$st_dir/b.md" --target octo/demo > /dev/null 2> "$st_dir/b.err"; rc=$?
    verdict "$1" "$2" "$rc" "$st_dir/b.err" "$4"
  }
  table='## Associated issues

| Issue | Scope this PR implements | Merging this |
|---|---|---|'
  m_body="$table
| https://github.com/octo/demo/issues/3 | all of it | **completes it** |
| https://github.com/octo/demo/issues/4 | the first half | **delivers part** |

Closes #3

## Agent attribution"

  # --- live shape, through --fixture ------------------------------------------------------------
  mk matched main "$m_body" "octo/demo#3"; issue matched octo/demo#3 "octo/demo#7"; issue matched octo/demo#4 ""
  run "matched: closing row keyworded and linked both ways, partial unlinked" 0 matched
  if grep -Fq "GitHub not read" "$st_dir/matched.out"; then echo "ok    a fixture pass says GitHub was not read"; else echo "FAIL  fixture pass line"; st_fails=$((st_fails + 1)); fi

  mk nokw main "$table
| https://github.com/octo/demo/issues/3 | all of it | **completes it** |" "octo/demo#3"; issue nokw octo/demo#3 "octo/demo#7"
  run "a closing row with no keyword line is refused" 1 nokw "has no keyword line of its own"

  mk nondefault feature/x "$m_body" ""
  run "a non-default base names the unlinked issue" 1 nondefault "pr side: missing: octo/demo#3"
  run "a non-default base prints retarget-pending" 1 nondefault "retarget-pending (base 'feature/x'"
  run "a non-default base names the sidebar's 10-link limit" 1 nondefault "at most 10 linked issues"
  mk nondeflinked feature/x "$m_body" "octo/demo#3"
  run "a non-default base linked by hand is still never a pass" 1 nondeflinked "retarget-pending"

  mk partkw main "$table
| https://github.com/octo/demo/issues/3 | all of it | **completes it** |
| https://github.com/octo/demo/issues/4 | the first half | Part of it |

Closes #3
Closes #4" "octo/demo#3 octo/demo#4"; issue partkw octo/demo#3 "octo/demo#7"; issue partkw octo/demo#4 "octo/demo#7"
  run "a Part of issue keyworded is refused in the body" 1 partkw "a closing keyword for octo/demo#4"
  run "a Part of issue linked is an extra on the PR side" 1 partkw "pr side: extra: octo/demo#4"
  run "a Part of issue listing the PR is an extra on the issue side" 1 partkw "issue side: extra: octo/demo#4"

  mk partlinked main "$m_body" "octo/demo#3 octo/demo#4"; issue partlinked octo/demo#3 "octo/demo#7"; issue partlinked octo/demo#4 "octo/demo#7"
  run "a partial issue linked by hand with no keyword is still refused" 1 partlinked "pr side: extra: octo/demo#4"

  mk cited main "$m_body
Closes #9" "octo/demo#3 octo/demo#9"; issue cited octo/demo#3 "octo/demo#7"; issue cited octo/demo#4 ""
  run "a keyword and a link for an issue the table never lists are refused" 1 cited "pr side: extra: octo/demo#9"

  mk xrepo main "$table
| [OT-IS-#5](https://github.com/octo/other/issues/5) | the consumer half | **completes it** |

Fixes octo/other#5" "octo/other#5"; issue xrepo octo/other#5 "octo/demo#7"
  run "a cross-repository closing row keyworded and linked passes" 0 xrepo

  mk xrepobare main "$table
| https://github.com/octo/other/issues/5 | the consumer half | **completes it** |

Fixes #5" "octo/demo#5"; issue xrepobare octo/other#5 ""
  run "a cross-repository issue keyworded as a bare #N is refused" 1 xrepobare "closing row octo/other#5 has no keyword line"

  mk reverse main "$m_body" "octo/demo#3"; issue reverse octo/demo#3 ""; issue reverse octo/demo#4 ""
  run "the reverse side missing is refused" 1 reverse "issue side: missing: octo/demo#3 does not list octo/demo#7"
  run "a missing link names the remedy" 1 reverse "Development sidebar"

  mk none main "## Associated issues

No associated issue." ""
  run "a section saying there is no associated issue, with no link, passes" 0 none
  mk nonelinked main "## Associated issues

None." "octo/demo#3"
  run "no associated issue but a link is refused" 1 nonelinked "pr side: extra: octo/demo#3"

  mk noissue main "$m_body" "octo/demo#3"
  run "a missing issue fixture is exit 2" 2 noissue "missing"
  mkdir -p "$st_dir/nopr"
  run "a missing pr fixture is exit 2" 2 nopr "missing"
  mk badjson main "$m_body" ""; echo "not json" > "$st_dir/badjson/pr.json"
  run "malformed JSON is exit 2" 2 badjson "malformed JSON"

  big="$table"; k=1
  while [ "$k" -le 51 ]; do big="$big
| https://github.com/octo/demo/issues/$k | x | cited |"; k=$((k + 1)); done
  mk big main "$big" ""
  run "more than 50 references is refused, naming the count, before any issue is read" 1 big "51 distinct issue references"

  # --- the body parser, fail closed (--body mode) -----------------------------------------------
  body "the body alone passes before the PR exists" 0 "$m_body"
  body "Closes #3. with one trailing dot is a keyword line" 0 "$table
| #3 | all | **completes it** |

Closes #3."
  body "a keyword inside a code fence or HTML comment does not count" 1 "$table
| #3 | all | **closes it** |

\`\`\`
Closes #3
\`\`\`
<!-- Closes #3 -->" "has no keyword line of its own"
  body "a keyword inside a sentence is not a keyword line of its own" 1 "$table
| #3 | all | **completes it** |

This PR closes #3 and more." "has no keyword line of its own"
  body "an inline keyword for a partial issue is refused (GitHub would link it)" 1 "$m_body
This also fixes #4 along the way." "a closing keyword for octo/demo#4"
  body "an inline keyword for an unlisted issue is refused" 1 "$m_body
Resolves: octo/elsewhere#12" "a closing keyword for octo/elsewhere#12"
  body "an inline-code <!-- does not hide the table (RED-2)" 1 "$table
| #3 | the \`<!--\` case | **completes it** |
| #4 | rest | delivers part |
Closes #3
<!-- -->" "a line directly under the Associated issues table"
  body "an inline-code <!-- leaves the closing row read (RED-2)" 1 "Notes: \`<!--\` is literal.

$table
| #3 | x | **completes it** |" "closing row octo/demo#3 has no keyword line"
  body "an HTML comment not at line start is refused" 1 "$m_body
text <!-- Closes #4 -->" "does not start its line"
  body "text after --> is refused" 1 "$m_body
<!-- note --> Closes #4" "text after the -->"
  body "an unclosed comment is refused" 1 "$m_body
<!-- open" "never closes"
  body "an unclosed fence is refused" 1 "$m_body
\`\`\`
Closes #4" "never closes"
  body "a fence closed by another character is refused" 1 "$m_body
\`\`\`
~~~
\`\`\`" "does not close it exactly"
  body "a fence closed by a longer run is refused" 1 "$m_body
\`\`\`
x
\`\`\`\`
\`\`\`" "does not close it exactly"
  body "a backtick run with a backtick after it is not a fence" 1 "$m_body
\`\`\`x\`\`\` y" "not a fence"
  body "an unbalanced code span is refused" 1 "$m_body
a \`stray backtick" "unbalanced code span"
  body "a lone CR is refused" 1 "$(printf '%s\nx\ry' "$m_body")" "lone carriage return"
  printf '%s\r\n' "## Associated issues" "" "| Issue | Scope | Merging this |" "|---|---|---|" "| #3 | x | **completes it** |" "" "Closes #3" > "$st_dir/crlf.md"
  bash "$st_self" --body "$st_dir/crlf.md" --target octo/demo > /dev/null 2>&1
  verdict "CRLF line ends are read" 0 $?
  printf '%s\n' "$m_body" > "$st_dir/nul.md"; printf 'x\000y\n' >> "$st_dir/nul.md"
  bash "$st_self" --body "$st_dir/nul.md" --target octo/demo > /dev/null 2> "$st_dir/nul.err"
  verdict "a NUL byte is refused" 1 $? "$st_dir/nul.err" "NUL byte"
  printf '%s\n' "$m_body" > "$st_dir/latin.md"; printf 'caf\351\n' >> "$st_dir/latin.md"
  bash "$st_self" --body "$st_dir/latin.md" --target octo/demo > /dev/null 2> "$st_dir/latin.err"
  verdict "invalid UTF-8 is refused" 1 $? "$st_dir/latin.err" "not valid UTF-8"
  body "no Associated issues section is refused" 1 "## Why

Text." "no \`## Associated issues\` section"
  body "a section with neither table nor statement is refused" 1 "## Associated issues

Some prose." "neither the table nor a statement"
  body "a setext Associated issues heading is read" 0 "Associated issues
-----------------

| Issue | Scope | Merging this |
|---|---|---|
| #3 | x | **closes it** |

Closes #3"
  body "a closing-hash heading is read" 0 "## Associated issues ##

| Issue | Scope | Merging this |
|---|---|---|
| #3 | x | **closes it** |

Closes #3"
  body "a lookalike heading is refused" 1 "## Associated Issues:

| Issue | Scope | Merging this |
|---|---|---|
| #3 | x | **closes it** |" "looks like the Associated issues section"
  body "a level-3 Associated issues heading is a lookalike" 1 "### Associated issues

None." "looks like the Associated issues section"
  body "a bold pseudo-heading is refused" 1 "$m_body

**Associated issues**" "looks like the Associated issues heading"
  body "a second Associated issues section is refused" 1 "$m_body

## Associated issues

None." "a second Associated issues section"
  body "a row without a leading pipe is refused" 1 "$table
| #3 | x | **completes it** |
#4 | y | **completes it** |

Closes #3" "without a leading pipe"
  body "an escaped pipe stays inside its cell" 0 "$table
| #3 | a \\| b | **completes it** |

Closes #3"
  body "a line directly under the table is refused" 1 "$table
| #3 | x | **completes it** |
Closes #3" "directly under the Associated issues table"
  body "a second table with other columns is ignored (HA-PR-#210 shape)" 0 "$table
| #3 | x | **closes it** |

#3 criteria:

| # | Criterion | Status |
|---|---|---|
| 1 | first | met, part of the work |

Closes #3"
  body "a second table with both columns is refused" 1 "$table
| #3 | x | **closes it** |

| Issue | Scope | Merging this |
|---|---|---|
| #5 | y | **closes it** |

Closes #3" "a second table with Issue and Merging this columns"
  body "a table with an Issue column and no Merging column is refused" 1 "## Associated issues

| Issue | Scope |
|---|---|
| #3 | all |" "only one of the Issue and Merging this columns"
  body "a verdict outside the vocabulary is refused" 1 "$table
| #3 | x | **partly done** |" "outside the closed vocabulary: \`partly done\`"
  body "words, not substrings: completes it with part in its remark is closing" 1 "$table
| #3 | x | **completes it** — the departure board |" "closing row octo/demo#3 has no keyword line"
  body "a non-ASCII verdict is refused, not normalised" 1 "$table
| #3 | x | **ｃｏｍｐｌｅｔｅｓ it** |" "not ASCII"
  body "an alias reference with no URL is refused" 1 "$table
| HA#3 | x | **closes it** |" "use the canonical URL"
  body "a dashed alias reference with no URL is refused" 1 "$table
| NN-#315 | x | **closes it** |" "use the canonical URL"
  body "a pull request URL on a closing row is refused" 1 "$table
| https://github.com/octo/demo/pull/3 | x | **closes it** |" "a pull request URL on a closing row"
  body "a pull request on a prerequisite row is listed, not verified" 0 "$table
| #3 | x | **closes it** |
| [HA-PR-#2](https://github.com/octo/demo/pull/2) | step one | prerequisite |

Closes #3"
  body "a .. segment in a reference is refused" 1 "$table
| ../demo#3 | x | **closes it** |" "segment"
  body "a row with no issue reference is refused" 1 "$table
| the login bug | all of it | **completes it** |" "names no issue reference"
  body "control characters in an echoed cell are replaced" 1 "$(printf '%s\n| the bug\001::error:: | x | **closes it** |' "$table")" "the bug?::error::"

  # --- the parser itself, and the shell around it ----------------------------------------------
  printf '%s\n' "$m_body" > "$st_dir/body.md"
  PR_DEV_LINK_AWK=/nonexistent/awk bash "$st_self" --body "$st_dir/body.md" --target octo/demo > /dev/null 2>&1
  verdict "awk absent is exit 2" 2 $?
  PR_DEV_LINK_AWK=false bash "$st_self" --body "$st_dir/body.md" --target octo/demo > /dev/null 2>&1
  verdict "a parser that exits non-zero is exit 2" 2 $?
  PR_DEV_LINK_AWK=true bash "$st_self" --body "$st_dir/body.md" --target octo/demo > /dev/null 2>&1
  verdict "a parser with no END record is exit 2" 2 $?

  mkdir -p "$st_dir/bin"
  cat > "$st_dir/bin/gh" <<'STUB'
#!/usr/bin/env bash
[ -n "$STUB_FAIL" ] && exit 1
case "$1 $2" in
  "repo view") cat "$STUB_DIR/repo.json" ;;
  "pr view") cat "$STUB_DIR/pr.json" ;;
  "issue view") cat "$STUB_DIR/issues/$5/$3.json" ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$st_dir/bin/gh"
  PATH="$st_dir/bin:$PATH" STUB_DIR="$st_dir/matched" bash "$st_self" --pr octo/demo#7 > /dev/null 2>&1
  verdict "live mode reads gh and passes the matched case" 0 $?
  PATH="$st_dir/bin:$PATH" STUB_DIR="$st_dir/reverse" bash "$st_self" --pr octo/demo#7 > /dev/null 2>&1
  verdict "live mode refuses the reverse side missing" 1 $?
  PATH="$st_dir/bin:$PATH" STUB_DIR="$st_dir/matched" STUB_FAIL=1 bash "$st_self" --pr octo/demo#7 > /dev/null 2>&1
  verdict "GitHub unreadable is exit 2" 2 $?

  for args in "--pr octo/demo" "--pr octo#7" "--pr -x/demo#7" "--pr octo/..#7" "--nope" "" \
      "--body $st_dir/missing.md --target octo/demo" "--body $st_dir/body.md" "--body $st_dir/body.md --target -x/y" \
      "--pr octo/demo#7 --fixture $st_dir/nodir"; do
    # shellcheck disable=SC2086
    bash "$st_self" $args > /dev/null 2>&1
    verdict "usage error (2): '${args//$st_dir/<tmp>}'" 2 $?
  done
  bash "$st_self" --pr "$(printf 'octo/demo#7\nx')" > /dev/null 2>&1
  verdict "a --pr value with a newline is a usage error (2)" 2 $?

  if [ "$st_fails" -eq 0 ]; then echo "pr_development_link_check.sh --self-test: all passed"; return 0; fi
  echo "pr_development_link_check.sh --self-test: $st_fails failed"; return 1
}

valid_repo() {  # valid_repo <owner/name>: the whole value, no leading '-', no '.'/'..' name
  local re='^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.][A-Za-z0-9_.-]*$'
  [[ $1 =~ $re ]] || return 1
  case "${1#*/}" in .|..) return 1 ;; esac
}

pr="" fixture="" body="" target=""
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) command -v jq >/dev/null 2>&1 || die2 "jq is required"; self_test; exit $? ;;
    --pr|--fixture|--body|--target)
      [ $# -ge 2 ] || { usage; exit 2; }
      case "$1" in --pr) pr="$2" ;; --fixture) fixture="$2" ;; --body) body="$2" ;; --target) target="$2" ;; esac
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "pr_development_link_check.sh: unknown argument '$1'" | printable >&2; usage; exit 2 ;;
  esac
done
command -v jq >/dev/null 2>&1 || die2 "jq is required"
command -v iconv >/dev/null 2>&1 || die2 "iconv is required"
command -v "$AWK" >/dev/null 2>&1 || die2 "awk is required ('$AWK' not found)"
work="$(mktemp -d)" || die2 "mktemp failed"; trap 'rm -rf "$work"' EXIT

if [ -n "$body" ]; then
  [ -z "$pr" ] && [ -z "$fixture" ] || { usage; exit 2; }
  valid_repo "$target" || { echo "pr_development_link_check.sh: --target must be <owner/name>" >&2; usage; exit 2; }
  [ -f "$body" ] && [ -r "$body" ] || die2 "the --body path is not a readable regular file"
  if check_body "$body" "$target" "$work"; then echo "pr development links: the body keywords every closing row and no other (body only, GitHub not read)"; exit 0; fi
  echo "pr development links: body refused (claude/skills/shibari/SKILL.md § 3, Associated issues)" >&2; exit 1
fi

[[ $pr == *'#'* ]] && valid_repo "${pr%#*}" && [[ ${pr##*#} =~ ^[0-9]+$ ]] && [[ ${pr%#*} != *'#'* ]] \
  || { echo "pr_development_link_check.sh: --pr must be <owner/name#N>" >&2; usage; exit 2; }
[ -z "$fixture" ] || [ -d "$fixture" ] || die2 "the --fixture path is not a directory"
self="$(printf '%s' "$pr" | tr '[:upper:]' '[:lower:]')"
note=""; [ -n "$fixture" ] && note=" (fixture: $fixture, GitHub not read)"
if check_pr "$self" "$work"; then
  echo "pr development links: $self — every closing row is keyworded and linked both ways, nothing extra$note"; exit 0
fi
echo "pr development links: $self refused (claude/skills/shibari/SKILL.md § 3, Associated issues)$note" >&2
exit 1
