#!/bin/sh
# prose_size_check.sh — hold the diet, mechanically.
#
#   sh scripts/prose_size_check.sh [repo-root]
#
# The ceilings were achieved by hand at v0.42.0 and would be lost the same way: every edit to a file
# already within a few bytes of its limit is an invitation to add "just one more sentence". A limit
# nothing measures is a limit that has already been exceeded, so this measures it.
#
#   every claude/agents/*.md except kurapika.md   <=  6144 bytes
#   the seventeen dieted skills                   <= 12288 bytes
#
# kurapika.md is exempt deliberately: he is the lead persona and the whole local plane in one file,
# and no reviewer budget or subagent raise depends on his size. The skills NOT on the list below are
# not exempt from good sense -- they were simply never put on the diet, and adding one here is a
# decision to hold it at 12 KB from then on.
#
# exit 0  every file is within its ceiling
# exit 1  at least one is over, each named with its size and its ceiling
# exit 2  the repository root does not look like a Hatsu checkout

set -eu

AGENT_MAX=6144
SKILL_MAX=12288

# The seventeen: fifteen from CHANGELOG v0.42.0 "The diet" plus black-voice and great-hiker, which
# were authored under the ceiling rather than reduced to it.
DIETED_SKILLS="amaterasu backlog-board backlog-loop black-voice breath build futon great-hiker hanten
hatsu-warmup jujutsu jutaisho kagutsuchi kokusen spiritual-message sharingan shibari"

root="${1:-}"
if [ -z "$root" ]; then
  root="$(cd -P -- "$(dirname -- "$0")/.." && pwd -P)"
fi
[ -d "$root/claude/agents" ] && [ -d "$root/claude/skills" ] \
  || { echo "prose_size_check.sh: $root is not a Hatsu checkout (no claude/agents, claude/skills)" >&2; exit 2; }

size_of() { wc -c <"$1" | tr -d ' '; }

offenders=0
checked=0

for f in "$root"/claude/agents/*.md; do
  [ -f "$f" ] || continue
  case "${f##*/}" in
    kurapika.md) continue ;;
  esac
  checked=$((checked + 1))
  n="$(size_of "$f")"
  if [ "$n" -gt "$AGENT_MAX" ]; then
    echo "OVER  ${f#"$root"/}  $n > $AGENT_MAX"
    offenders=$((offenders + 1))
  fi
done

for s in $DIETED_SKILLS; do
  f="$root/claude/skills/$s/SKILL.md"
  if [ ! -f "$f" ]; then
    echo "MISSING  claude/skills/$s/SKILL.md -- named on the diet list and not on disk"
    offenders=$((offenders + 1))
    continue
  fi
  checked=$((checked + 1))
  n="$(size_of "$f")"
  if [ "$n" -gt "$SKILL_MAX" ]; then
    echo "OVER  ${f#"$root"/}  $n > $SKILL_MAX"
    offenders=$((offenders + 1))
  fi
done

if [ "$offenders" -eq 0 ]; then
  echo "prose ok: $checked files within their ceilings (agents $AGENT_MAX, dieted skills $SKILL_MAX)"
  exit 0
fi
echo "prose_size_check.sh: $offenders file(s) over the ceiling" >&2
exit 1
