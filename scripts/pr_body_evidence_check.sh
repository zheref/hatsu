#!/bin/sh
# pr_body_evidence_check.sh — refuse a pull request body whose screenshots are not in a table.
#
#   scripts/pr_body_evidence_check.sh --body <file>
#   scripts/pr_body_evidence_check.sh --self-test
#
# docs/WORKFLOW.md § The UZF-26 evidence shape: every screenshot a PR body carries sits in a CELL of an
# evidence table — states as named columns, variants as labelled rows — and every image names what it
# shows. A body that spreads images one per line reads as a pile, not as evidence. This checks the
# body FILE before it is written to the pull request (on the first write and on every update after a
# review), so a loose image never reaches the reviewer.
#
# What counts as an image: a markdown image `![alt](src)` or an HTML `<img …>`. Inside a fenced code
# block nothing counts. An image is IN a table when its line is a markdown table row (it starts with
# `|`) or when it sits between `<table>` and `</table>`.
#
# Refused, each by line number:
#   loose     an image outside any table
#   unlabeled an image with no alt text (`![](…)`, or `<img>` with no or an empty alt)
#
# exit 0  every image is in a table and labelled (a body with no images passes)
# exit 1  at least one image refused; every one is listed on stderr
# exit 2  a usage error: no --body, an unreadable file, an unknown argument

usage() {
  echo "usage: pr_body_evidence_check.sh --body <file>" >&2
  echo "       pr_body_evidence_check.sh --self-test" >&2
}

check() {  # check <file>
  awk '
    BEGIN { bad = 0; fence = 0; html = 0 }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      low = tolower(line)
      if (low ~ /<table[ >]/ || low ~ /<table$/) html++
      has_md = (line ~ /!\[[^]]*\]\(/)
      has_img = (low ~ /<img[ >\/]/)
      if (has_md || has_img) {
        in_table = (html > 0) || (line ~ /^[ \t]*\|/)
        if (!in_table) { printf "line %d: loose: an image outside any table: %s\n", NR, line > "/dev/stderr"; bad++ }
        if (line ~ /!\[[ \t]*\]\(/) { printf "line %d: unlabeled: a markdown image with no alt text\n", NR > "/dev/stderr"; bad++ }
        n = split(low, parts, /<img/)
        for (i = 2; i <= n; i++) {
          tag = parts[i]; sub(/>.*/, "", tag)
          if (tag !~ /alt[ \t]*=[ \t]*"[^"]*[^" \t][^"]*"/ && tag !~ /alt[ \t]*=[ \t]*\047[^\047]*[^\047 \t][^\047]*\047/) {
            printf "line %d: unlabeled: an <img> with no alt text\n", NR > "/dev/stderr"; bad++
          }
        }
      }
      if (low ~ /<\/table>/ && html > 0) html--
    }
    END { exit (bad > 0) ? 1 : 0 }
  ' "$1"
}

self_test() {
  st_self="$0"; st_fails=0
  st_dir="$(mktemp -d)"; trap 'rm -rf "$st_dir"' EXIT
  st_case() {  # st_case <label> <want exit> <body text>
    printf '%s\n' "$3" > "$st_dir/body.md"
    sh "$st_self" --body "$st_dir/body.md" >/dev/null 2>&1; st_rc=$?
    if [ "$st_rc" -eq "$2" ]; then echo "ok    $1"; else echo "FAIL  $1: want $2, got $st_rc"; st_fails=$((st_fails + 1)); fi
  }
  st_case "no images passes" 0 "## Evidence
Logic-only change; UZF-26 exempt."
  st_case "a markdown table of labelled images passes" 0 "### Settings — HA#12
| | Typical | Empty |
|---|---|---|
| **iPhone · light** | ![Typical, light](a.png) | ![Empty, light](b.png) |"
  st_case "an HTML table of labelled <img> passes" 0 '<table><tr><th></th><th>Typical</th></tr>
<tr><td><b>iPhone · dark</b></td><td><img src="a.png" width="180" alt="Typical, dark"></td></tr>
</table>'
  st_case "a loose markdown image is refused" 1 "## Evidence
![Typical](a.png)"
  st_case "a loose <img> is refused" 1 '<img src="a.png" alt="Typical">'
  st_case "images stacked one per line are refused" 1 "![Typical](a.png)
![Empty](b.png)"
  st_case "an unlabeled markdown image in a table is refused" 1 "| | Typical |
|---|---|
| **iPhone** | ![](a.png) |"
  st_case "an <img> with an empty alt in a table is refused" 1 '| **iPad** | <img src="a.png" alt=""> |'
  st_case "an <img> with no alt in a table is refused" 1 '| **iPad** | <img src="a.png" width="180"> |'
  st_case "an image inside a code fence is ignored" 0 '```
![](a.png)
```'
  st_case "a second, unlabeled <img> on a labelled line is refused" 1 '| **x** | <img src="a.png" alt="A"> <img src="b.png"> |'
  sh "$st_self" --body "$st_dir/missing.md" >/dev/null 2>&1
  if [ $? -eq 2 ]; then echo "ok    an unreadable body is a usage error (2)"; else echo "FAIL  an unreadable body"; st_fails=$((st_fails + 1)); fi
  sh "$st_self" --nope >/dev/null 2>&1
  if [ $? -eq 2 ]; then echo "ok    an unknown argument is a usage error (2)"; else echo "FAIL  an unknown argument"; st_fails=$((st_fails + 1)); fi
  if [ "$st_fails" -eq 0 ]; then echo "pr_body_evidence_check.sh --self-test: all passed"; return 0; fi
  echo "pr_body_evidence_check.sh --self-test: $st_fails failed"; return 1
}

body=""
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) self_test; exit $? ;;
    --body) [ $# -ge 2 ] || { usage; exit 2; }; body="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "pr_body_evidence_check.sh: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done
[ -n "$body" ] || { usage; exit 2; }
[ -r "$body" ] || { echo "pr_body_evidence_check.sh: cannot read '$body'" >&2; exit 2; }
if check "$body"; then echo "pr body evidence: every image is in a table and labelled"; exit 0; fi
echo "pr body evidence: refused; put every screenshot in the evidence table (docs/WORKFLOW.md § The UZF-26 evidence shape)" >&2
exit 1
