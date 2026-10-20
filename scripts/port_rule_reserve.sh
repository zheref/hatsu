#!/usr/bin/env bash
# port_rule_reserve.sh — the next free port-ruling id, reserved against the tip AND every open PR.
#
# hatsu:bankai-rule § 3 (zheref/hatsu#355; the ruling of 2026-10-20, "reserve against open PRs"):
# a ruling's id is the next number free in the pair file at the authoring clone's
# origin/<base> tip and in every open pull request of the handbooks repository that adds rows to
# that file. Two concurrent port runs therefore never take one id, and a collision that still
# slips in (two PRs reserving between each other's reads) is renumbered only in the run's own
# branch at catch-up, never after a merge.
#
# RESIDUE, NAMED. The open-PR read is `gh pr list` + `gh pr diff`: harness shell for a GitHub read,
# until zheref/nen#456 lands a verb; this script is the one place it lives, so the move is one edit.
# The `gh` it runs is the first on PATH, which is how the fixture (port_rule_reserve_fixture.sh)
# serves a stub instead of the live service.
#
# USAGE
#   scripts/port_rule_reserve.sh --clone <path> --target <owner/name> --pair-file <relative path>
#                                --prefix <PT> [--base <ref>] [--json]
#
# OUTPUT  `next: <prefix>-<n>` and one line per id seen (tip or PR #n); --json: {next, number, seen[]}.
# EXIT    0 reserved · 1 a PR's diff could not be read (an unread PR is never a clean one) ·
#         2 usage, a clone that is not a git repository, or no gh on PATH.
set -uo pipefail

clone=""; target=""; pair=""; prefix=""; base="main"; json=0
while [ $# -gt 0 ]; do
  case "$1" in
    --clone) clone="$2"; shift 2 ;;
    --target) target="$2"; shift 2 ;;
    --pair-file) pair="$2"; shift 2 ;;
    --prefix) prefix="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --json) json=1; shift ;;
    *) echo "port_rule_reserve: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$clone" ] && [ -n "$target" ] && [ -n "$pair" ] && [ -n "$prefix" ] || { echo "usage: port_rule_reserve.sh --clone <path> --target <owner/name> --pair-file <path> --prefix <PT> [--base <ref>] [--json]" >&2; exit 2; }
git -C "$clone" rev-parse --git-dir >/dev/null 2>&1 || { echo "port_rule_reserve: '$clone' is not a git repository" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "port_rule_reserve: gh is not on PATH" >&2; exit 2; }
case "$prefix" in *[!A-Za-z0-9]*|"") echo "port_rule_reserve: --prefix is letters and digits only" >&2; exit 2 ;; esac

ids() { # stdin: lines; stdout: the numbers of `| <prefix>-<n> ` rows
  grep -aoE "^\+?\| ${prefix}-[0-9]+ " | sed -E 's/.*-([0-9]+) $/\1/' || true
}

seen=()
max=0
note() { seen+=("$1"); n="${1%% *}"; n="${n##*-}"; [ "$n" -gt "$max" ] 2>/dev/null && max="$n"; }

# 1. the tip
tipref="origin/$base"
git -C "$clone" rev-parse --verify -q "$tipref" >/dev/null || tipref="$base"
if git -C "$clone" cat-file -e "$tipref:$pair" 2>/dev/null; then
  while IFS= read -r n; do [ -n "$n" ] && note "$prefix-$n tip $tipref"; done < <(git -C "$clone" show "$tipref:$pair" | ids)
fi

# 2. every open PR that adds rows under the pair file
rc=0
prs="$(gh pr list --repo "$target" --state open --json number,headRefName --jq '.[] | "\(.number) \(.headRefName)"' 2>/dev/null)" || { echo "port_rule_reserve: gh pr list failed for $target" >&2; exit 1; }
while IFS= read -r line; do
  [ -n "$line" ] || continue
  num="${line%% *}"; ref="${line#* }"
  diff="$(gh pr diff "$num" --repo "$target" 2>/dev/null)" || { echo "port_rule_reserve: PR #$num's diff could not be read; its ids are unknown" >&2; rc=1; continue; }
  # only the hunks of the pair file
  section="$(printf '%s\n' "$diff" | awk -v f="$pair" 'BEGIN{p=0} /^diff --git /{p=0} ($0 ~ "^\\+\\+\\+ b/" f "$"){p=1; next} p{print}')"
  while IFS= read -r n; do [ -n "$n" ] && note "$prefix-$n PR #$num ($ref)"; done < <(printf '%s\n' "$section" | ids)
done <<< "$prs"

next=$((max + 1))
if [ "$json" = 1 ]; then
  printf '{"next":"%s-%s","number":%s,"seen":[' "$prefix" "$next" "$next"
  first=1; for s in "${seen[@]+"${seen[@]}"}"; do [ $first = 1 ] || printf ','; first=0; printf '"%s"' "$s"; done
  printf '],"unreadPRs":%s}\n' "$rc"
else
  printf 'next: %s-%s\n' "$prefix" "$next"
  for s in "${seen[@]+"${seen[@]}"}"; do printf '  seen: %s\n' "$s"; done
fi
exit "$rc"
