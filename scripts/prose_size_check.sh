#!/bin/sh
# prose_size_check.sh — hold the diet, mechanically; say how much room is left.
#
#   sh scripts/prose_size_check.sh [--headroom] [--] [repo-root]
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
#                                                     source file is measured against; counted as
#                                                     UTF-8 code points, the same under every locale
#                                                     -- was `wc -m`, which counted bytes under C)
#
# --headroom (zheref/hatsu#119): print every measured file with its size, its ceiling and the bytes
# (or characters) left, smallest headroom first, so a reviewer or an author states the remaining
# margin as a number instead of rediscovering "0 bytes left" by trading clauses round after round.
# The ceilings are unchanged by this flag; it reports, and the exit code is the same as without it.
#
# Every measured file must be a regular file whose real path stays under the root: a symlink that
# leaves the root, a dangling symlink where a file is expected, a file that cannot be read, a directory
# that cannot be listed and a rules file that is not valid UTF-8 are each an OFFENDER by name (the run
# never reads green over a file it did not measure, and never measures a path the tree pointed outside
# itself -- SEC-7; QA-16/QA-18, zheref/hatsu#119's review).
#
# kurapika.md is exempt deliberately: he is the lead persona and the whole local plane in one file,
# and no reviewer budget or subagent raise depends on his size. The skills NOT on the list below are
# not exempt from good sense -- they were simply never put on the diet, and adding one here is a
# decision to hold it at 12 KB from then on.
#
# exit 0  every file is within its ceiling
# exit 1  at least one is over, unreadable, unlistable, unmeasurable, dangling or outside the root, each named
# exit 2  the repository root does not look like a Hatsu checkout, an unknown flag, an empty root
#         argument, or more than one root argument

set -eu

AGENT_MAX=6144
SKILL_MAX=12288
RULES_MAX=12000

# The seventeen: fifteen from CHANGELOG v0.42.0 "The diet" plus black-voice and great-hiker, which
# were authored under the ceiling rather than reduced to it.
DIETED_SKILLS="amaterasu backlog-board backlog-loop black-voice breath build futon great-hiker hanten
ten jujutsu jutaisho kagutsuchi kokusen spiritual-message sharingan shibari"

usage_error() { echo "prose_size_check.sh: $1" >&2; exit 2; }

headroom=0
root=""
root_seen=0
options_done=0
for arg in "$@"; do
  if [ "$options_done" -eq 0 ]; then
    case "$arg" in
      --headroom) headroom=1; continue ;;
      --) options_done=1; continue ;;
      -*) usage_error "unknown flag $arg (known: --headroom, -- ends the flags)" ;;
    esac
  fi
  [ -n "$arg" ] || usage_error "empty repo-root argument -- name the checkout, or pass nothing for this script's own"
  [ "$root_seen" -eq 0 ] || usage_error "more than one repo-root argument ('$root' then '$arg'); one checkout per run"
  root="$arg"; root_seen=1
done
if [ -z "$root" ]; then
  root="$(cd -P -- "$(dirname -- "$0")/.." && pwd -P)"
fi
[ -d "$root/claude/agents" ] && [ -d "$root/claude/skills" ] \
  || usage_error "$root is not a Hatsu checkout (no claude/agents, claude/skills)"
root="$(cd -P -- "$root" && pwd -P)"

size_of() { wc -c <"$1" | tr -d ' '; }
# characters = UTF-8 code points, whatever the locale: drop the continuation bytes (0x80-0xBF) and count what is left.
chars_of() { LC_ALL=C tr -d '\200-\277' <"$1" | wc -c | tr -d ' '; }

offenders=0
checked=0
rows=""

offend() { echo "$1"; offenders=$((offenders + 1)); }

# listable <dir>: 0 when the directory can be listed; otherwise UNLISTABLE is named and counted, because a
# glob over a directory that exists but cannot be read expands to nothing and would read as green.
listable() {
  ls -- "$1" >/dev/null 2>&1 && return 0
  offend "UNLISTABLE  ${1#"$root"/} -- the directory exists but could not be listed"; return 1
}

# admit <path>: 0 when the entry is a regular file whose real path stays under $root and is readable;
# otherwise the offence is named and 1 is returned. An absent entry (no symlink) is the caller's case.
admit() {
  f="$1"; rel="${f#"$root"/}"
  if [ -L "$f" ] && [ ! -e "$f" ]; then offend "DANGLING  $rel -- a symlink to nothing where a file is expected"; return 1; fi
  [ -f "$f" ] || return 1
  if [ -L "$f" ]; then
    link="$(readlink "$f")"
    case "$link" in /*) linkdir="$(dirname -- "$link")" ;; *) linkdir="$(dirname -- "$f")/$(dirname -- "$link")" ;; esac
    real="$(cd -P -- "$linkdir" 2>/dev/null && pwd -P)/$(basename -- "$link")" || real=""
  else
    real="$(cd -P -- "$(dirname -- "$f")" && pwd -P)/$(basename -- "$f")"
  fi
  case "$real" in
    "$root"/*) ;;
    *) offend "OUTSIDE  $rel -- resolves to a path outside the root, not measured"; return 1 ;;
  esac
  [ -r "$f" ] || { offend "UNREADABLE  $rel -- could not be measured"; return 1; }
  return 0
}

# measure <relative path> <measured> <ceiling> <unit>: one row of the report, and the verdict.
measure() {
  case "$2" in
    ''|*[!0-9]*) offend "UNREADABLE  $1 -- could not be measured"; return ;;
  esac
  checked=$((checked + 1))
  left=$(($3 - $2))
  rows="$rows$(printf '%6d %-52s %6d/%-6d %s' "$left" "$1" "$2" "$3" "$4")
"
  if [ "$2" -gt "$3" ]; then
    offend "OVER  $1  $2 > $3 $4"
  fi
}

if listable "$root/claude/agents"; then
  for f in "$root"/claude/agents/*.md; do
    case "${f##*/}" in
      kurapika.md) continue ;;
    esac
    admit "$f" || continue
    measure "${f#"$root"/}" "$(size_of "$f" 2>/dev/null || true)" "$AGENT_MAX" bytes
  done
fi

for s in $DIETED_SKILLS; do
  f="$root/claude/skills/$s/SKILL.md"
  if [ ! -e "$f" ] && [ ! -L "$f" ]; then
    offend "MISSING  claude/skills/$s/SKILL.md -- named on the diet list and not on disk"
    continue
  fi
  admit "$f" || continue
  measure "${f#"$root"/}" "$(size_of "$f" 2>/dev/null || true)" "$SKILL_MAX" bytes
done

if [ -d "$root/claude/rules" ] && listable "$root/claude/rules"; then
  for f in "$root"/claude/rules/*.md; do
    admit "$f" || continue
    bytes="$(size_of "$f" 2>/dev/null || true)"
    chars="$(chars_of "$f" 2>/dev/null || true)"
    # a code-point count that cannot be right for its byte count (no lead bytes at all, or fewer than a
    # quarter as many characters as bytes) is not valid UTF-8 and is refused, never undercounted
    case "$bytes$chars" in *[!0-9]*|'') ;; *)
      if [ "$bytes" -gt 0 ] && { [ "$chars" -eq 0 ] || [ $((chars * 4)) -lt "$bytes" ]; }; then
        offend "UNMEASURABLE  ${f#"$root"/} -- not valid UTF-8 ($bytes bytes, $chars code points), not measured"; continue
      fi ;;
    esac
    measure "${f#"$root"/}" "$chars" "$RULES_MAX" chars
  done
fi

if [ "$headroom" -eq 1 ]; then
  printf '%6s %-52s %6s/%-6s %s\n' left file size ceiling unit
  printf '%s' "$rows" | sort -n
fi

if [ "$offenders" -eq 0 ]; then
  echo "prose ok: $checked files within their ceilings (agents $AGENT_MAX, dieted skills $SKILL_MAX, rules $RULES_MAX chars)"
  exit 0
fi
echo "prose_size_check.sh: $offenders file(s) over the ceiling, unreadable, dangling or outside the root" >&2
exit 1
