#!/usr/bin/env bash
# announced_tag.sh — susanoo § 5a's announced-tag read, as one shipped command (zheref/hatsu#289 item 5).
#
# FROZEN to fixes only pending its port (BC-11, the ruling of 2026-10-17): the read branches three ways and
# carries the embedded Python the skill's block carried before this script existed — moved, never grown.
# The nen verb that retires it is zheref/nen#407's family (a `tags announce` read of nen/workflow.json).
#
#   scripts/announced_tag.sh --repo <path>
#
# Reads `nen/workflow.json` → tags.identity.nameFrom and prints the two lines of that file: line 1 the tag's
# IDENTITY (no prefix), line 2 the SHA the archive built. Exit 0 printed; 3 no tag declared (absent `tags` or
# `tags.identity`: a no-op report, the archive stands); 1 a declaration fault (malformed `tags`, a nameFrom
# that is not a regular file, fewer than two lines); 2 wiring.
set -u
repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] && [ -n "$2" ] || { echo "announced_tag: --repo needs a value" >&2; exit 2; }; repo="$2"; shift 2 ;;
    -h|--help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { print }' "$0"; exit 0 ;;
    *) echo "announced_tag: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$repo" ] || { echo "announced_tag: --repo is required" >&2; exit 2; }
top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || { echo "announced_tag: '$repo' is not a git repository" >&2; exit 2; }
wf="$top/nen/workflow.json"
[ -f "$wf" ] || { echo "announced_tag: no tag declared (no nen/workflow.json)"; exit 3; }
# The value is read as DATA; it is never templated into shell source.
nameFrom="$(python3 -I -c 'import json,sys
t=json.load(open(sys.argv[1])).get("tags")
if t is None: sys.exit(3)
if not isinstance(t, dict): sys.exit("tags is %s, not an object" % type(t).__name__)
i=t.get("identity")
if i is None: sys.exit(3)
if not isinstance(i, dict): sys.exit("tags.identity is %s, not an object" % type(i).__name__)
n=i.get("nameFrom")
if not isinstance(n, str) or not n: sys.exit("tags.identity.nameFrom is missing or is not a non-empty string")
print(n)' "$wf" 2>/tmp/announced_tag.$$)"; rc=$?
err="$(cat /tmp/announced_tag.$$ 2>/dev/null)"; rm -f /tmp/announced_tag.$$
case "$rc" in
  0) ;;
  3) echo "announced_tag: no tag declared (nen/workflow.json has no tags.identity)"; exit 3 ;;
  *) echo "announced_tag: declaration fault: ${err:-python exit $rc}" >&2; exit 1 ;;
esac
case "$nameFrom" in /*|*..*) echo "announced_tag: declaration fault: nameFrom must be a repo-relative path without '..' ($nameFrom)" >&2; exit 1 ;; esac
f="$top/$nameFrom"
[ -f "$f" ] || { echo "announced_tag: declaration fault: nameFrom is not a regular file ($nameFrom)" >&2; exit 1; }
identity="$(sed -n 1p "$f")"; sha="$(sed -n 2p "$f")"
[ -n "$identity" ] && [ -n "$sha" ] || { echo "announced_tag: declaration fault: $nameFrom must carry two lines (identity, sha)" >&2; exit 1; }
printf '%s\n%s\n' "$identity" "$sha"
exit 0
