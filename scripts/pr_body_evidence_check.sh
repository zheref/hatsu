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
# What counts as an image: a markdown image `![alt](src)`, a reference-style image `![alt][ref]`, or an
# HTML `<img …>` (its attributes may continue on the following lines). Inside a fenced code block
# nothing counts, and an inline code span (`…`) is stripped before anything is matched, so `<table>`
# written as code opens nothing. An image is IN a table when:
#   - its line belongs to a markdown table: a run of lines starting with `|` whose second line is a
#     `|---|` separator row (a lone `| ![x](a.png)` line is not a table), or
#   - it sits between a `<table>` and the `</table>` that closes it (a `<table>` never closed holds
#     nothing, so its images are loose).
#
# Refused, each by line number:
#   loose     an image outside any table
#   unlabeled an image with no alt text (`![](…)`, `![][ref]`, or `<img>` with no or an empty alt)
#
# exit 0  every image is in a table and labelled (a body with no images passes)
# exit 1  at least one image refused; every one is listed on stderr
# exit 2  a usage error: no --body, a path that is not a readable regular file, an unknown argument
#
# The body is handed to awk on stdin, never as an operand: awk reads an operand containing `=` as a
# variable assignment, and a file named `x=y.md` would be checked as an empty body and passed.

usage() {
  echo "usage: pr_body_evidence_check.sh --body <file>" >&2
  echo "       pr_body_evidence_check.sh --self-test" >&2
}

check() {  # check <file>
  awk '
    function strip_code(t) {
      gsub(/``([^`]|`[^`])*``/, "", t)
      gsub(/`[^`]*`/, "", t)
      return t
    }
    function is_sep(t) {
      return t ~ /^[ \t]*\|?[ \t]*:?-+:?[ \t]*(\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$/ && t ~ /-/ && t ~ /\|/
    }
    BEGIN { fence = 0 }
    {
      raw[NR] = $0
      if ($0 ~ /^[ \t]*(```|~~~)/) { fence = !fence; txt[NR] = ""; next }
      txt[NR] = fence ? "" : strip_code($0)
    }
    END {
      n = NR; bad = 0
      # HTML tables: an open <table> marks lines only once its </table> is found.
      depth = 0
      for (i = 1; i <= n; i++) {
        rest = tolower(txt[i])
        while (1) {
          o = match(rest, /<table([ \t>]|$)/); os = RSTART
          c = match(rest, /<\/table>/); cs = RSTART
          if (os == 0 && cs == 0) break
          if (os > 0 && (cs == 0 || os < cs)) {
            stack[++depth] = i; rest = substr(rest, os + 6)
          } else {
            if (depth > 0) { from = stack[depth--]; for (k = from; k <= i; k++) inhtml[k] = 1 }
            rest = substr(rest, cs + 8)
          }
        }
      }
      # Markdown tables: a run of `|` lines whose second line is a separator row.
      i = 1
      while (i <= n) {
        if (txt[i] ~ /^[ \t]*\|/) {
          j = i
          while (j + 1 <= n && txt[j + 1] ~ /^[ \t]*\|/) j++
          if (j > i && is_sep(txt[i + 1])) for (k = i; k <= j; k++) inmd[k] = 1
          i = j + 1
        } else i++
      }
      for (i = 1; i <= n; i++) {
        line = txt[i]; low = tolower(line)
        has_md = (line ~ /!\[[^]]*\][(\[]/)
        has_img = (low ~ /<img([ \t>\/]|$)/)
        if (!has_md && !has_img) continue
        if (!inhtml[i] && !inmd[i]) { printf "line %d: loose: an image outside any table: %s\n", i, raw[i] > "/dev/stderr"; bad++ }
        if (line ~ /!\[[ \t]*\][(\[]/) { printf "line %d: unlabeled: a markdown image with no alt text\n", i > "/dev/stderr"; bad++ }
        m = split(low, parts, /<img/)
        for (p = 2; p <= m; p++) {
          tag = parts[p]
          if (tag !~ /^([ \t>\/]|$)/) continue
          for (k = i + 1; tag !~ />/ && p == m && k <= n; k++) tag = tag " " tolower(txt[k])
          sub(/>.*/, "", tag)
          if (tag !~ /alt[ \t]*=[ \t]*"[^"]*[^" \t][^"]*"/ && tag !~ /alt[ \t]*=[ \t]*\047[^\047]*[^\047 \t][^\047]*\047/) {
            printf "line %d: unlabeled: an <img> with no alt text\n", i > "/dev/stderr"; bad++
          }
        }
      }
      exit (bad > 0) ? 1 : 0
    }
  ' < "$1"
}

self_test() {
  st_self="$(cd -P -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")"; st_fails=0
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
  st_case "an <img> with an empty alt in a table is refused" 1 '| | Typical |
|---|---|
| **iPad** | <img src="a.png" alt=""> |'
  st_case "an <img> with no alt in a table is refused" 1 '| | Typical |
|---|---|
| **iPad** | <img src="a.png" width="180"> |'
  st_case "a reference-style image outside a table is refused" 1 "![Typical][shot]

[shot]: a.png"
  st_case "a labelled reference-style image in a table passes" 0 "| | Typical |
|---|---|
| **iPhone** | ![Typical][shot] |

[shot]: a.png"
  st_case "an unlabeled reference-style image in a table is refused" 1 "| | Typical |
|---|---|
| **iPhone** | ![][shot] |

[shot]: a.png"
  st_case "an inline-code <table> opens nothing" 1 'Wrap the shots in `<table>` like so:
<img src="a.png" alt="Typical">'
  st_case "a <table> never closed holds nothing" 1 '<table><tr><td><img src="a.png" alt="Typical"></td></tr>'
  st_case "an <img> whose attributes continue on the next line is detected" 1 '<img
  src="a.png" alt="Typical">'
  st_case "a multi-line <img> in a closed table with alt passes" 0 '<table><tr><td><img
  src="a.png" alt="Typical"></td></tr></table>'
  st_case "a multi-line <img> with no alt is refused" 1 '<table><tr><td><img
  src="a.png" width="180"></td></tr></table>'
  st_case "a lone | row with no separator is loose" 1 '| ![Typical](a.png)'
  st_case "a | run whose second line is not a separator is loose" 1 '| Typical | Empty |
| ![Typical](a.png) | ![Empty](b.png) |'
  st_case "an image inside a code fence is ignored" 0 '```
![](a.png)
```'
  st_case "a second, unlabeled <img> on a labelled line is refused" 1 '| **x** | <img src="a.png" alt="A"> <img src="b.png"> |'
  sh "$st_self" --body "$st_dir/missing.md" >/dev/null 2>&1
  if [ $? -eq 2 ]; then echo "ok    an unreadable body is a usage error (2)"; else echo "FAIL  an unreadable body"; st_fails=$((st_fails + 1)); fi
  mkdir -p "$st_dir/x=y"; printf '%s\n' '![Typical](a.png)' > "$st_dir/x=y/body.md"
  sh "$st_self" --body "$st_dir/x=y/body.md" >/dev/null 2>&1
  if [ $? -eq 1 ]; then echo "ok    a path containing = is read as a file, not an awk assignment"; else echo "FAIL  a path containing ="; st_fails=$((st_fails + 1)); fi
  printf '%s\n' '![Typical](a.png)' > "$st_dir/k=v.md"
  (cd "$st_dir" && sh "$st_self" --body "k=v.md" >/dev/null 2>&1)
  if [ $? -eq 1 ]; then echo "ok    a relative name containing = is read as a file"; else echo "FAIL  a relative name containing ="; st_fails=$((st_fails + 1)); fi
  sh "$st_self" --body "$st_dir" >/dev/null 2>&1
  if [ $? -eq 2 ]; then echo "ok    a directory is a usage error (2)"; else echo "FAIL  a directory as --body"; st_fails=$((st_fails + 1)); fi
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
[ -f "$body" ] && [ -r "$body" ] || { echo "pr_body_evidence_check.sh: '$body' is not a readable regular file" >&2; exit 2; }
if check "$body"; then echo "pr body evidence: every image is in a table and labelled"; exit 0; fi
echo "pr body evidence: refused; put every screenshot in the evidence table (docs/WORKFLOW.md § The UZF-26 evidence shape)" >&2
exit 1
