#!/usr/bin/env bash
# port_rule_reserve.sh — the next free port-ruling id, reserved against every place a row can be.
#
# hatsu:bankai-rule § 3 (zheref/hatsu#355; the ruling of 2026-10-20, "reserve against open PRs",
# read with the round-2 settlement that a rulings PR opens only at a port run's end): a ruling's
# id is the next number free in the pair file at FOUR places, read together —
#   1. the tip, origin/<base>, fetched first (a stale tip would collide with a merged, immutable row);
#   2. this run's own branch: HEAD's copy of the pair file and the working-tree copy, so the second
#      ruling of a run (a batched port-drift call writes several) never repeats the first;
#   3. every other pushed rulings branch on origin (refs/remotes/origin/*/*/ports-*, the clone's
#      own branch template), because an in-flight run has no PR yet and would otherwise be unseen;
#   4. every open pull request whose FILE LIST names the pair file.
# Two concurrent port runs therefore never take one id, and a collision that still slips in (two
# runs reserving between each other's pushes) is renumbered only in the run's own branch at
# catch-up, never after a merge.
#
# THE OPEN PRS AND THE SIBLING BRANCHES ARE HOSTILE INPUT. The handbooks repository is public, so
# any account's fork PR is in `gh pr list` and its diff text is attacker-controlled. So: only a PR
# whose file list names the pair file is read (a `+++ b/<pair>` line inside another file's hunk is
# never a header); the pair path is compared as a literal, never spliced into a regex; every id
# must read `^[1-9][0-9]{0,8}$` (no leading zero, under a billion), is computed in base 10, and one
# outside that shape is a NAMED refusal (exit 3) listing where it sits, never a silent drop and never
# the unread code; the open-PR list is read with an explicit limit and its count compared to the
# repository's own open-PR total, a short read being the unread code (exit 1); the printed JSON
# escapes every branch name. A fork PR is marked `fork` in `seen`.
#
# RESIDUE, NAMED. The open-PR read is `gh pr list`, `gh pr view --json files`, `gh pr diff` and
# `gh api search/issues`: harness shell for a GitHub read, until zheref/nen#456 lands a verb; this
# script is the one place it lives, so the move is one edit. The `gh` it runs is the first on PATH
# — the trust the session already places in PATH — which is how the fixture
# (port_rule_reserve_fixture.sh) serves a stub instead of the live service.
#
# USAGE
#   scripts/port_rule_reserve.sh --clone <path> --target <owner/name> --pair-file <relative path>
#                                --prefix <PT> [--base <ref>] [--no-fetch] [--json]
#
# OUTPUT  `next: <prefix>-<n>` ONLY on a complete read, and one line per id seen (tip · branch HEAD ·
#         working tree · branch origin/<x> · PR #n (<ref>) [fork]); --json: {complete, next, number, seen[]}
#         with next null when the read was incomplete -- an exit-1 run reserves nothing.
# EXIT    0 reserved · 1 an open PR could not be read, or the open-PR list was short (an unread
#         PR is never a clean one) · 2 usage (a flag with no value, an unknown argument), a clone
#         that is not a git repository, a fetch that failed, a tip ref that does not resolve, a
#         pair path outside `^[A-Za-z0-9._/-]+$` or carrying `..`, or no gh on PATH · 3 an id
#         outside the admitted shape is in the way (named; settle that PR or branch first).
set -uo pipefail

clone=""; target=""; pair=""; prefix=""; base="main"; json=0; fetch=1
usage() { echo "usage: port_rule_reserve.sh --clone <path> --target <owner/name> --pair-file <path> --prefix <PT> [--base <ref>] [--no-fetch] [--json]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --clone|--target|--pair-file|--prefix|--base) [ -n "${2-}" ] || { echo "port_rule_reserve: $1 takes a value" >&2; usage; } ;;
  esac
  case "$1" in
    --clone) clone="$2"; shift 2 ;;
    --target) target="$2"; shift 2 ;;
    --pair-file) pair="$2"; shift 2 ;;
    --prefix) prefix="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --no-fetch) fetch=0; shift ;;
    --json) json=1; shift ;;
    *) echo "port_rule_reserve: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$clone" ] && [ -n "$target" ] && [ -n "$pair" ] && [ -n "$prefix" ] || usage
git -C "$clone" rev-parse --git-dir >/dev/null 2>&1 || { echo "port_rule_reserve: '$clone' is not a git repository" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "port_rule_reserve: gh is not on PATH" >&2; exit 2; }
case "$prefix" in *[!A-Za-z0-9]*|"") echo "port_rule_reserve: --prefix is letters and digits only" >&2; exit 2 ;; esac
case "$pair" in
  /*|*..*|*[!A-Za-z0-9._/-]*|"") echo "port_rule_reserve: --pair-file is a relative path of [A-Za-z0-9._/-] with no '..', got '$pair'" >&2; exit 2 ;;
esac
case "$target" in */*) ;; *) echo "port_rule_reserve: --target is owner/name" >&2; exit 2 ;; esac

rows() { # stdin: lines; stdout: the raw number text of `| <prefix>-<n> ` rows (a leading + admitted)
  grep -aoE "^\+?\| ${prefix}-[0-9]+ " | sed -E 's/.*-([0-9]+) $/\1/' || true
}

seen=()
bad=()
max=0
note() { # number-text, where
  local n="$1" where="$2"
  if [[ "$n" =~ ^[1-9][0-9]{0,8}$ ]]; then
    seen+=("$prefix-$n $where")
    [ "$((10#$n))" -gt "$max" ] && max=$((10#$n))
  else
    bad+=("$prefix-$n $where")
  fi
}
note_ref() { # a git ref, its label: every row of the pair file at that ref
  local ref="$1" label="$2" n
  git -C "$clone" cat-file -e "$ref:$pair" 2>/dev/null || return 0
  while IFS= read -r n; do [ -n "$n" ] && note "$n" "$label"; done < <(git -C "$clone" show "$ref:$pair" | rows)
}
jsonstr() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# 1. the tip, fetched
if git -C "$clone" remote get-url origin >/dev/null 2>&1; then
  if [ "$fetch" = 1 ]; then
    git -C "$clone" fetch -q origin >/dev/null 2>&1 || { echo "port_rule_reserve: fetching origin failed -- the tip is unread, nothing is reserved" >&2; exit 2; }
  fi
  tipref="origin/$base"
  git -C "$clone" rev-parse --verify -q "$tipref" >/dev/null || { echo "port_rule_reserve: origin/$base does not resolve in $clone -- the tip is unread, nothing is reserved" >&2; exit 2; }
else
  tipref="$base"
  git -C "$clone" rev-parse --verify -q "$tipref" >/dev/null || { echo "port_rule_reserve: $clone has no origin and $base does not resolve -- the tip is unread, nothing is reserved" >&2; exit 2; }
  echo "port_rule_reserve: $clone has no origin; the local $base is the tip" >&2
fi
note_ref "$tipref" "tip $tipref"

# 2. this run's own branch: HEAD and the working tree
note_ref HEAD "branch HEAD"
if [ -f "$clone/$pair" ]; then
  while IFS= read -r n; do [ -n "$n" ] && note "$n" "working tree"; done < <(rows < "$clone/$pair")
fi

# 3. every other pushed rulings branch on origin (the branch template's ports-* descriptor)
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  [ "$ref" = "$tipref" ] && continue
  note_ref "$ref" "branch $ref"
done < <(git -C "$clone" for-each-ref --format='%(refname:short)' 'refs/remotes/origin/*/*/ports-*' 'refs/remotes/origin/*/ports-*' 2>/dev/null)

# 4. every open PR whose file list names the pair file
rc=0
total="$(gh api "search/issues?q=repo:${target}+is:pr+is:open" --jq '.total_count' 2>/dev/null)" || { echo "port_rule_reserve: the open-PR total of $target could not be read" >&2; exit 1; }
prs="$(gh pr list --repo "$target" --state open --limit 1000 --json number,headRefName,isCrossRepository --jq '.[] | "\(.number)\t\(.isCrossRepository)\t\(.headRefName)"' 2>/dev/null)" || { echo "port_rule_reserve: gh pr list failed for $target" >&2; exit 1; }
count=0; [ -n "$prs" ] && count="$(printf '%s\n' "$prs" | grep -c .)"
if [ "$count" != "$total" ]; then
  echo "port_rule_reserve: the open-PR list of $target is short ($count read of $total open) -- an unread PR is never a clean one" >&2
  exit 1
fi
while IFS=$'\t' read -r num fork ref; do
  [ -n "$num" ] || continue
  files="$(gh pr view "$num" --repo "$target" --json files --jq '.files[].path' 2>/dev/null)" || { echo "port_rule_reserve: PR #$num's file list could not be read; its ids are unknown" >&2; rc=1; continue; }
  printf '%s\n' "$files" | grep -qxF -- "$pair" || continue
  diff="$(gh pr diff "$num" --repo "$target" 2>/dev/null)" || { echo "port_rule_reserve: PR #$num's diff could not be read; its ids are unknown" >&2; rc=1; continue; }
  # only the hunks of the pair file: the header compared as a literal, a hunk's own `+++ b/` content line never a header
  section="$(printf '%s\n' "$diff" | awk -v f="+++ b/$pair" 'BEGIN{p=0} /^diff --git /{p=0; next} (!p && index($0, f) == 1 && length($0) == length(f)){p=1; next} p && /^\+/{print}')"
  where="PR #$num ($ref)"; [ "$fork" = true ] && where="$where fork"
  while IFS= read -r n; do [ -n "$n" ] && note "$n" "$where"; done < <(printf '%s\n' "$section" | rows)
done <<< "$prs"

if [ "${#bad[@]}" -gt 0 ]; then
  echo "port_rule_reserve: refusing to reserve -- an id outside ^[1-9][0-9]{0,8}$ is in the way (settle it first):" >&2
  for b in "${bad[@]}"; do echo "  $b" >&2; done
  exit 3
fi

next=$((max + 1))
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
