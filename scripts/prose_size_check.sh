#!/bin/sh
# prose_size_check.sh — hold the diet, mechanically; say how much room is left.
#
#   sh scripts/prose_size_check.sh [--headroom] [repo-root]
#
# The ceilings were achieved by hand at v0.42.0 and would be lost the same way: every edit to a file
# already within a few bytes of its limit is an invitation to add "just one more sentence". A limit
# nothing measures is a limit that has already been exceeded, so this measures it.
#
#   every claude/agents/*.md except kurapika.md   <=  6144 bytes
#   the seventeen dieted skills                   <= 12288 bytes
#   every claude/rules/*.md                       <= 12000 characters (Antigravity's own documented
#                                                     rules-file limit, docs/surfaces/antigravity.md --
#                                                     the smallest limit any surface documents for a
#                                                     rules/instructions file, so it is the one this
#                                                     source file is measured against)
#
# --headroom (zheref/hatsu#119): print every measured file with its size, its ceiling and the bytes
# (or characters) left, smallest headroom first, so a reviewer or an author states the remaining
# margin as a number instead of rediscovering "0 bytes left" by trading clauses round after round.
# The ceilings are unchanged by this flag; it reports, and the exit code is the same as without it.
#
# kurapika.md is exempt deliberately: he is the lead persona and the whole local plane in one file,
# and no reviewer budget or subagent raise depends on his size. The skills NOT on the list below are
# not exempt from good sense -- they were simply never put on the diet, and adding one here is a
# decision to hold it at 12 KB from then on.
#
# exit 0  every file is within its ceiling
# exit 1  at least one is over, each named with its size and its ceiling
# exit 2  the repository root does not look like a Hatsu checkout, or an unknown flag

set -eu

AGENT_MAX=6144
SKILL_MAX=12288
RULES_MAX=12000

# The seventeen: fifteen from CHANGELOG v0.42.0 "The diet" plus black-voice and great-hiker, which
# were authored under the ceiling rather than reduced to it.
DIETED_SKILLS="amaterasu backlog-board backlog-loop black-voice breath build futon great-hiker hanten
ten jujutsu jutaisho kagutsuchi kokusen spiritual-message sharingan shibari"

headroom=0
root=""
for arg in "$@"; do
  case "$arg" in
    --headroom) headroom=1 ;;
    --*) echo "prose_size_check.sh: unknown flag $arg (known: --headroom)" >&2; exit 2 ;;
    *) root="$arg" ;;
  esac
done
if [ -z "$root" ]; then
  root="$(cd -P -- "$(dirname -- "$0")/.." && pwd -P)"
fi
[ -d "$root/claude/agents" ] && [ -d "$root/claude/skills" ] \
  || { echo "prose_size_check.sh: $root is not a Hatsu checkout (no claude/agents, claude/skills)" >&2; exit 2; }

size_of() { wc -c <"$1" | tr -d ' '; }
# characters = UTF-8 code points, whatever the locale: drop the continuation bytes (0x80-0xBF) and count what is left.
chars_of() { LC_ALL=C tr -d '\200-\277' <"$1" | wc -c | tr -d ' '; }

offenders=0
checked=0
rows=""

# measure <relative path> <measured> <ceiling> <unit>: one row of the report, and the verdict.
measure() {
  checked=$((checked + 1))
  left=$(($3 - $2))
  rows="$rows$(printf '%6d %-52s %6d/%-6d %s' "$left" "$1" "$2" "$3" "$4")
"
  if [ "$2" -gt "$3" ]; then
    echo "OVER  $1  $2 > $3 $4"
    offenders=$((offenders + 1))
  fi
}

for f in "$root"/claude/agents/*.md; do
  [ -f "$f" ] || continue
  case "${f##*/}" in
    kurapika.md) continue ;;
  esac
  measure "${f#"$root"/}" "$(size_of "$f")" "$AGENT_MAX" bytes
done

for s in $DIETED_SKILLS; do
  f="$root/claude/skills/$s/SKILL.md"
  if [ ! -f "$f" ]; then
    echo "MISSING  claude/skills/$s/SKILL.md -- named on the diet list and not on disk"
    offenders=$((offenders + 1))
    continue
  fi
  measure "${f#"$root"/}" "$(size_of "$f")" "$SKILL_MAX" bytes
done

if [ -d "$root/claude/rules" ]; then
  for f in "$root"/claude/rules/*.md; do
    [ -f "$f" ] || continue
    measure "${f#"$root"/}" "$(chars_of "$f")" "$RULES_MAX" chars
  done
fi

if [ "$headroom" -eq 1 ]; then
  echo "headroom  file                                                  size/ceiling"
  printf '%s' "$rows" | sort -n
fi

if [ "$offenders" -eq 0 ]; then
  echo "prose ok: $checked files within their ceilings (agents $AGENT_MAX, dieted skills $SKILL_MAX, rules $RULES_MAX chars)"
  exit 0
fi
echo "prose_size_check.sh: $offenders file(s) over the ceiling" >&2
exit 1
