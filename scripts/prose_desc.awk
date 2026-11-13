# block(): a `|` or `>` value as YAML builds it -- literal lines joined by newlines, folded lines by
# spaces with each blank line a newline, then the chomping indicator: strip (-) no final line break,
# clip (default) one, keep (+) one plus every trailing blank line.
function block(   i, j, last, lead, gap, out) {
  if (style == "plain" || built) return
  built = 1; last = 0
  for (i = 1; i <= nl; i++) if (L[i] != "") last = i
  out = ""; lead = 1; gap = 0
  for (i = 1; i <= last; i++) {
    if (style == "literal") { out = (i == 1 ? L[i] : out "\n" L[i]); continue }
    if (L[i] == "") { gap++; continue }
    if (lead) { for (j = 0; j < gap; j++) out = out "\n"; out = out L[i]; lead = 0 }
    else if (gap) { for (j = 0; j < gap; j++) out = out "\n"; out = out L[i] }
    else out = out " " L[i]
    gap = 0
  }
  if (last && chomp != "strip") out = out "\n"
  if (last && chomp == "keep") for (i = last + 1; i <= nl; i++) out = out "\n"
  v = out
}
{ sub(/\r$/, "") }
NR == 1 {
  if (substr($0, 1, 3) == "\357\273\277" && substr($0, 4) == "---") { nc = "a BOM before ---"; exit }
  if ($0 != "---") exit
  next
}
/^---$/ { exit }
indesc && style != "plain" && (/^[ \t]/ || /^$/) { line = $0; sub(/^[ \t]+/, "", line); L[++nl] = line; next }
indesc && /^[ \t]/ {
  line = $0; sub(/^[ \t]+/, "", line)
  if (line != "") v = (v == "" ? line : v " " line)
  next
}
indesc && /^$/ { next }
{ if (indesc) block(); indesc = 0 }
/^["\047]?description["\047]?[ \t]*:/ && !/^description:/ { nc = "a quoted key or a space before the colon"; exit }
/^description:/ {
  if (seen) { dup = 1; exit }
  seen = 1; indesc = 1; v = $0; sub(/^description:[ \t]*/, "", v)
  if (v ~ /^[>|][-+0-9]*[ \t]*$/) {
    style = (substr(v, 1, 1) == ">" ? "folded" : "literal")
    chomp = (index(v, "-") ? "strip" : (index(v, "+") ? "keep" : "clip")); v = ""; nl = 0
  }
  else if (v ~ /^[*&]/) { nc = "an alias or anchor value"; exit }
  else style = "plain"
}
END { if (indesc) block(); if (nc != "") print "NONCANON " nc; else if (dup) print "DUP"; else if (seen) print "OK " v "|" }
