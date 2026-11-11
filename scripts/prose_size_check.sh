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
#   the thirty-one dieted skills                      <= 12288 bytes
#   every claude/rules/*.md, and the generated      <= 12000 characters (Antigravity's own documented
#   surfaces/antigravity/rules/*.md mirror
#                                                     rules-file limit, docs/surfaces/antigravity.md --
#                                                     the smallest limit any surface documents for a
#                                                     rules/instructions file, so it is the one this
#                                                     source file is measured against; counted as
#                                                     UTF-8 code points, the same under every locale
#                                                     -- was `wc -m`, which counted bytes under C)
#   every skill's frontmatter `description`   <=  1024 characters (zheref/hatsu#186: the Agent Skills
#                                                     spec's cap; Codex 0.154.0 truncates past it, dropping
#                                                     the tail, and Copilot CLI drops the skill --
#                                                     docs/surfaces/codex.md). Measured in claude/skills/*/
#                                                     SKILL.md AND every generated mirror's SKILL.md under
#                                                     surfaces/, since a mirror's own length is the one its
#                                                     surface reads. Measured whole in the forms the
#                                                     generator writes -- a `description:` key at column 0
#                                                     holding a plain, quoted, folded or literal scalar,
#                                                     indented continuations, CRLF -- and in no other: a
#                                                     quoted key, a space before the colon, an alias or
#                                                     anchor value, a BOM before `---`, a duplicate key or
#                                                     a value that is not valid UTF-8 (checked exactly, by
#                                                     perl's Encode) is UNMEASURABLE by name, never skipped. A
#                                                     SKILL.md with no frontmatter description is not
#                                                     measured. This is branching shell owed to a nen verb.
#
# --headroom (zheref/hatsu#119): print every measured file with its size, its ceiling and the bytes
# (or characters) left, smallest headroom first, so a reviewer or an author states the remaining
# margin as a number instead of rediscovering "0 bytes left" by trading clauses round after round.
# The ceilings are unchanged by this flag; it reports, and the exit code is the same as without it.
# A measured dieted skill with under 512 bytes left also prints WARN without changing the verdict.
#
# Every measured file must be a regular file whose real path stays under the root: a symlink, or a
# chain of them, that leaves the root, a dangling symlink where a file is expected, a file that cannot be read, a directory
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
# exit 1  at least one is over (a description included), unreadable, unlistable, unmeasurable, dangling or outside the root, each named
# exit 2  the repository root does not look like a Hatsu checkout, an unknown flag, an empty root
#         argument, more than one root argument, no perl to check UTF-8 with, or no readable description parser

set -eu

AGENT_MAX=6144
SKILL_MAX=12288
RULES_MAX=12000
DESC_MAX=1024

# The thirty-two: fifteen from CHANGELOG v0.42.0 "The diet" plus black-voice, great-hiker, limbo,
# bakuryuha, rikugan (new at v0.73.0), classify (v0.88.0), direct (v0.89.0), kazaana and cleanup (v0.108.0), emperor-time (v0.116.0), bankai-rule (v0.125.0), kamui and hiraishin (v0.126.0), dowsing-chain (v0.133.0), kuchiyose (v0.140.0), kage-bunshin (v0.156.0), senkaimon (v0.165.0), which were authored
# under the ceiling rather than reduced to it. scripts/prose_size_check_fixture.sh reads THIS list, so it is the only one.
DIETED_SKILLS="amaterasu backlog-board backlog-loop bakuryuha black-voice breath build classify direct futon great-hiker
hanten limbo ten jujutsu jutaisho kagutsuchi kokusen rikugan spiritual-message sharingan shibari kazaana cleanup emperor-time bankai-rule kamui hiraishin dowsing-chain kuchiyose kage-bunshin senkaimon"

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
script_dir="$(CDPATH= cd -P -- "$(dirname -- "$0")" && pwd -P)"
if [ -z "$root" ]; then
  root="$(dirname -- "$script_dir")"
fi
[ -d "$root/claude/agents" ] && [ -d "$root/claude/skills" ] \
  || usage_error "$root is not a Hatsu checkout (no claude/agents, claude/skills)"
root="$(cd -P -- "$root" && pwd -P)"

command -v perl >/dev/null 2>&1 || usage_error "no perl on PATH -- UTF-8 validity is checked exactly, never guessed"

description_parser="$script_dir/prose_desc.awk"
[ -f "$description_parser" ] && [ -r "$description_parser" ] \
  || usage_error "cannot read description parser $description_parser"

size_of() { wc -c <"$1" | tr -d ' '; }
# valid_utf8: 0 when stdin is entirely valid UTF-8 -- Encode's strict decoder refuses any stray, truncated,
# overlong or surrogate sequence. Not iconv: macOS's refuses a valid character straddling its 1024-byte buffer.
valid_utf8() {
  perl -e 'use Encode (); local $/; my $s = <STDIN>; exit(eval { Encode::decode("UTF-8", $s, Encode::FB_CROAK); 1 } ? 0 : 1)' 2>/dev/null
}
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
    # Every hop, never one readlink: a symlink to an in-root symlink that leaves the root is outside too
    # (Feitan, hanten on #135). perl is already required; Cwd::realpath resolves the whole chain.
    real="$(perl -MCwd=realpath -e 'my $r = realpath($ARGV[0]); print $r if defined $r' -- "$f" 2>/dev/null)" || real=""
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

diet_offended="|"
for s in $DIETED_SKILLS; do
  f="$root/claude/skills/$s/SKILL.md"
  if [ ! -e "$f" ] && [ ! -L "$f" ]; then
    offend "MISSING  claude/skills/$s/SKILL.md -- named on the diet list and not on disk"
    continue
  fi
  admit "$f" || { diet_offended="$diet_offended${f#"$root"/}|"; continue; }
  measure "${f#"$root"/}" "$(size_of "$f" 2>/dev/null || true)" "$SKILL_MAX" bytes
done

if [ -d "$root/claude/rules" ] && listable "$root/claude/rules"; then
  for f in "$root"/claude/rules/*.md; do
    admit "$f" || continue
    bytes="$(size_of "$f" 2>/dev/null || true)"
    chars="$(chars_of "$f" 2>/dev/null || true)"
    # a file that is not valid UTF-8 has no true code-point count: refused, never undercounted
    if ! valid_utf8 <"$f"; then
      offend "UNMEASURABLE  ${f#"$root"/} -- not valid UTF-8 ($bytes bytes), not measured"; continue
    fi
    measure "${f#"$root"/}" "$chars" "$RULES_MAX" chars
  done
fi

# the generated Antigravity mirror adds frontmatter and a stamp to the source, so the limit is measured on
# it too where it exists (a consumer checkout may carry no surfaces/): a source under 12000 is not proof
if [ -d "$root/surfaces/antigravity/rules" ] && listable "$root/surfaces/antigravity/rules"; then
  for f in "$root"/surfaces/antigravity/rules/*.md; do
    admit "$f" || continue
    bytes="$(size_of "$f" 2>/dev/null || true)"
    chars="$(chars_of "$f" 2>/dev/null || true)"
    if ! valid_utf8 <"$f"; then
      offend "UNMEASURABLE  ${f#"$root"/} -- not valid UTF-8 ($bytes bytes), not measured"; continue
    fi
    measure "${f#"$root"/}" "$chars" "$RULES_MAX" chars
  done
fi

# description_of <file>: the frontmatter `description` in the forms the generator writes, on stdout after a status word:
# "OK <value>|" (the value measured whole, a "|" sentinel after it -- a folded `>` block joined by spaces, a
# literal `|` block by newlines, either with its chomping indicator applied as YAML does, a plain or quoted scalar continued on indented lines joined by spaces, a trailing CR dropped
# the way Codex's frontmatter reader trims it), "DUP" for a second `description:` key (readers disagree on
# which wins, so it is never measured), "NONCANON <why>" for a form this reader does not follow (a BOM
# before `---`, a quoted key or a space before the colon at column 0, an alias or anchor value -- each one
# YAML and Codex read in full), or nothing when the file opens no frontmatter or carries no description. Read as bytes (LC_ALL=C) so an invalid byte never stops awk; UTF-8 validity is checked after.
description_of() {
  LC_ALL=C awk -f "$description_parser" "$1" 2>/dev/null
}

# Every directory the globs below walk must be listable, or a skill inside it is silently unmeasured.
for d0 in "$root/claude/skills" "$root/surfaces" "$root"/surfaces/*/ "$root"/surfaces/*/skills/ "$root"/claude/skills/*/ "$root"/surfaces/*/*/ "$root"/surfaces/*/skills/*/; do
  d0="${d0%/}"; [ -d "$d0" ] || continue
  if [ ! -r "$d0" ] || [ ! -x "$d0" ]; then offend "UNLISTABLE  ${d0#"$root"/} -- the directory exists but could not be listed"; fi
done

# One finding per path: a SKILL.md the diet loop already offended against is not offended against again.
described=0
for f in "$root"/claude/skills/*/SKILL.md "$root"/surfaces/*/*/SKILL.md "$root"/surfaces/*/skills/*/SKILL.md; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  rel="${f#"$root"/}"
  case "$diet_offended" in *"|$rel|"*) continue ;; esac
  admit "$f" || continue
  if ! out="$(description_of "$f")"; then
    offend "UNMEASURABLE  $rel -- the description could not be measured"; continue
  fi
  case "$out" in
    '') continue ;;
    DUP) offend "UNMEASURABLE  $rel -- two description keys in the frontmatter, not measured"; continue ;;
    NONCANON\ *) offend "UNMEASURABLE  $rel -- the description is written as ${out#NONCANON }, a form this check does not read; not measured"; continue ;;
  esac
  d="${out#OK }"; d="${d%|}"   # the "|" sentinel keeps a block value'"'"'s final line breaks from $(...)
  case "$d" in
    \"*\") d="${d#\"}"; d="${d%\"}" ;;
    \'*\') d="${d#\'}"; d="${d%\'}" ;;
  esac
  if ! printf '%s' "$d" | valid_utf8; then
    offend "UNMEASURABLE  $rel -- the description is not valid UTF-8, not measured"; continue
  fi
  n="$(printf '%s' "$d" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' ')"
  case "$n" in ''|*[!0-9]*) offend "UNMEASURABLE  $rel -- the description could not be measured"; continue ;; esac
  described=$((described + 1))
  if [ "$n" -gt "$DESC_MAX" ]; then
    offend "OVER-DESCRIPTION  $rel  $n > $DESC_MAX chars -- the Agent Skills cap; Codex truncates past it, dropping the tail (zheref/hatsu#186)"
  fi
done

if [ "$headroom" -eq 1 ]; then
  printf '%6s %-52s %6s/%-6s %s\n' left file size ceiling unit
  printf '%s' "$rows" | sort -n
  # TypeScript owns the 512-byte warning predicate (BC-11); this shell only
  # hands it the diet's existing list and the measured root.
  node "$(dirname -- "$0")/prose_headroom_warn.ts" "$root" "$SKILL_MAX" $DIETED_SKILLS
fi

if [ "$offenders" -eq 0 ]; then
  echo "prose ok: $checked files within their ceilings (agents $AGENT_MAX, dieted skills $SKILL_MAX, rules $RULES_MAX chars); $described skill descriptions within the $DESC_MAX-character cap"
  exit 0
fi
echo "prose_size_check.sh: $offenders offence(s): a file over its ceiling or a description over the cap, or a path unreadable, unlistable, unmeasurable, dangling or outside the root" >&2
exit 1
