#!/bin/sh
# publish_gate_check.sh — every documented publish runs only on the verdicts chained before it.
# zheref/hatsu#188: on zheref/hatsu#181 a chained step ran `nen wc catch-up`, which exited 1
# mid-merge, and the chain went on to `nen wc publish` without reading that exit. The rule lived
# in prose ("only an unchanged, fully proved tree is pushed"); nothing held a code block to it.
#
#   scripts/publish_gate_check.sh [<markdown file>...]
#
# Default files: claude/skills/murasaki/SKILL.md, claude/skills/mukai/SKILL.md and
# claude/skills/aka/SKILL.md, relative to the repository root this script lives in.
#
# THE RULE, per fenced code block (``` or ~~~, any fence length, nested fences honoured; an
# unterminated fence is itself a finding). After `\`-newline continuations are joined, `# ...`
# comments stripped outside quotes only (a `#` inside "..." or '...' never hides what follows it)
# and every run of spaces and tabs collapsed to one space (`nen wc  publish` is still a publish),
# EVERY `nen wc publish` in a block is held to:
#   - a block that names `nen wc catch-up` must reach each publish from the nearest catch-up before
#     it, and a block that names `branch_authorship_check.sh` from the nearest such check before it,
#     through `&&` alone: no `;`, no `||`, no bare newline, no `|` (a pipe's status is its last
#     stage's, #161; a pipe glued to the publish, `x |nen wc publish`, counts), no lone `&` (a
#     backgrounded step's exit is never read); fd redirections (`2>&1`, `&>`) are not separators;
#   - a publish with no catch-up before it, in a block that names one, is a finding; so is a
#     publish with no branch_authorship_check.sh before it, in a block that names one (a publish
#     placed ahead of the check is ungated, whatever follows it);
#   - THE OWNERS' FILE-LEVEL POLICY: blocks are read one at a time, so a file could otherwise pair
#     one fully gated block with a separate, bare `nen wc publish` block. In the skills that own a
#     push, every publish carries its own gates in its own chain, whatever the other blocks hold:
#     murasaki/SKILL.md and mukai/SKILL.md (the post-review push) need both a catch-up and the
#     authorship check before each publish; aka/SKILL.md (the first publish and the pre-review
#     push, whose range step 0 already proved) needs the authorship check. Any other file is held
#     only to the gates its own block names (prose and tables are never read: only fenced code);
#   - a negated command (`! ...`) is a finding wherever it stands on that chain: the catch-up, the
#     authorship check, or any step between either and the publish (`&& ! grep ... noOp`) — a
#     negated step passes on the very failure it exists to catch.
# And murasaki/SKILL.md, the skill that owns the post-review push, must carry at least one gated
# block whose catch-up-to-publish chain also reads `noOp`, un-negated, and runs
# branch_authorship_check.sh.
#
# exit 0  every block is gated, and the owner shows the full gated form
# exit 1  a finding: file, block start line and the reason, one per line on stdout
# exit 2  an argument that is not a readable regular file
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
if [ $# -eq 0 ]; then
  set -- "$here/claude/skills/murasaki/SKILL.md" "$here/claude/skills/mukai/SKILL.md" "$here/claude/skills/aka/SKILL.md"
fi

status=0
for f in "$@"; do
  if [ ! -f "$f" ] || [ ! -r "$f" ]; then
    echo "publish_gate_check: not a readable regular file: $f" >&2
    exit 2
  fi
  case "$f" in
    */murasaki/SKILL.md|*/mukai/SKILL.md) needcu=1; needau=1 ;;
    */aka/SKILL.md) needcu=0; needau=1 ;;
    *) needcu=0; needau=0 ;;
  esac
  out="$(awk -v file="$f" -v sq="'" -v needcu="$needcu" -v needau="$needau" '
    function fence(s,   c, n, i) {        # "<char><len>" if s opens or closes a fence, else ""
      sub(/^[ \t]*/, "", s); c = substr(s, 1, 1)
      if (c != "`" && c != "~") return ""
      n = 0; for (i = 1; i <= length(s) && substr(s, i, 1) == c; i++) n++
      return (n >= 3) ? c n "|" substr(s, n + 1) : ""
    }
    function lastpos(t, pat, before,   p, q, r) {
      r = 0; p = 0
      while ((q = index(substr(t, p + 1), pat)) > 0) { p += q; if (p < before) r = p; else break }
      return r
    }
    function badseg(seg, what) {
      gsub(/[0-9]*>&[0-9-]*/, "", seg); gsub(/&>/, "", seg)
      if (seg ~ /;/)            return what ": a ; separates the steps"
      if (seg ~ /\|\|/)         return what ": a || lets the publish run on a failure"
      if (seg ~ /\n/)           return what ": a bare newline separates the steps"
      if (seg ~ /[^|]\|([^|]|$)/) return what ": a | hides an exit status"
      if (seg ~ /(^|[^&])&([^&]|$)/) return what ": a lone & backgrounds a step whose exit is never read"
      if (seg ~ /&&[ \t]*!/)     return what ": a negated step (! ...) passes on a failure"
      return ""
    }
    function negated(t, a,   ls) {     # does the command holding position a start with `!`?
      ls = substr(t, 1, a - 1); sub(/.*\n/, "", ls); sub(/.*&&/, "", ls)
      return ls ~ /^[ \t]*!/
    }
    function strip(s,   i, c, q, out, prev) {   # drop a # comment that stands outside quotes
      q = ""; out = ""; prev = " "
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (q == "" && c == "#" && prev ~ /[ \t]/) break
        if (q != sq && c == "\\" && i < length(s)) { out = out c substr(s, i + 1, 1); i++; prev = "x"; continue }
        if (q == "" && (c == "\"" || c == sq)) q = c
        else if (q != "" && c == q) q = ""
        out = out c; prev = c
      }
      return out
    }
    function report(msg) { printf "%s:%d: %s\n", file, start, msg; bad++ }
    function check(   t, p, q, cu, au, seg, msg, full) {
      t = blk
      gsub(/\\\n[ \t]*/, " ", t)
      gsub(/[ \t]+/, " ", t)
      p = 0; full = 0
      while ((q = index(substr(t, p + 1), "nen wc publish")) > 0) {
        p += q
        cu = lastpos(t, "nen wc catch-up", p); au = lastpos(t, "branch_authorship_check.sh", p)
        if ((needcu || index(t, "nen wc catch-up") > 0) && cu == 0) { report("a nen wc publish has no nen wc catch-up before it"); continue }
        if ((needau || index(t, "branch_authorship_check.sh") > 0) && au == 0) { report("a nen wc publish has no branch_authorship_check.sh before it"); continue }
        if (cu > 0) {
          if (negated(t, cu)) { report("a negated catch-up publishes on a failure"); continue }
          msg = badseg(substr(t, cu, p - cu), "catch-up to publish"); if (msg != "") { report(msg); continue }
        }
        if (au > 0 && negated(t, au)) { report("a negated authorship check publishes on a failure"); continue }
        if (au > 0) { msg = badseg(substr(t, au, p - au), "authorship check to publish"); if (msg != "") { report(msg); continue } }
        if (cu > 0 && au > cu && index(substr(t, cu, p - cu), "noOp") > 0) full++
      }
      gated_full += full
    }
    {
      fl = fence($0)
      if (!inb) {
        if (fl != "") { inb = 1; fc = substr(fl, 1, 1); fn = substr(fl, 2) + 0; start = NR; blk = "" }
        next
      }
      if (fl != "" && substr(fl, 1, 1) == fc) {
        split(substr(fl, 2), parts, "|")
        if (parts[1] + 0 >= fn && parts[2] ~ /^[ \t]*$/) { check(); inb = 0; blk = ""; next }
      }
      line = strip($0)
      blk = blk line "\n"
    }
    END {
      if (inb) report("an unterminated code fence")
      printf "FULL %d\n", gated_full + 0
      exit (bad > 0)
    }
  ' "$f")" || status=1
  printf '%s\n' "$out" | grep -v '^FULL ' || true
  case "$f" in
    */murasaki/SKILL.md)
      n="$(printf '%s\n' "$out" | sed -n 's/^FULL //p')"
      if [ "${n:-0}" -lt 1 ]; then
        echo "$f: murasaki shows no gated catch-up && noOp && ... && branch_authorship_check.sh && publish block (zheref/hatsu#188, #170)"
        status=1
      fi ;;
  esac
done

if [ "$status" -eq 0 ]; then
  echo "publish_gate_check: every publish block is gated"
fi
exit "$status"
