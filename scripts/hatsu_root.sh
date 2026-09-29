#!/bin/sh
# hatsu_root.sh — resolve the Hatsu plugin root and print it ALONE on stdout.
#
#   scripts/hatsu_root.sh [--quoted] [<a candidate path the harness handed this invocation>]
#
# Three candidates and no fourth, in order, the first that passes winning:
#   1. $HATSU_PLUGIN_ROOT   — the form that works on all surfaces, and the one to prefer
#   2. $1                   — the path this invocation was handed
#   3. $CLAUDE_PLUGIN_ROOT  — Claude Code's own, kept last so one resolution serves every surface
#
# THE TREE IS NAMED, NEVER TRUSTED BY ITSELF (zheref/hatsu#67). When the working tree this script
# runs in is a Hatsu checkout (the git toplevel of $PWD carries .claude-plugin/plugin.json naming
# hatsu) whose manifest version is NEWER than the resolved candidate's, the candidate STAYS — a
# directory's own claim about itself is never what picks the root that later steps run scripts
# from (a checkout naming itself `hatsu` at version 999.0.0 must not become the plugin root by
# being cd'd into; Feitan, SEC-14) — and stderr says so: which pin this session bound, that the
# skill bodies already inlined came from it, where to read the tree's protocol, and the quoted
# `export HATSU_PLUGIN_ROOT='…'` that binds the tree from the next session (the maintainer's word,
# candidate 1). With no candidate at all the answer stays NOT INSTALLED, the checkout named the same
# way. An older, equal or unorderable version (anything but three dot-separated digit fields of at
# most nine digits) is said and changes nothing. A git that is absent from PATH, or refuses the
# directory, is said as "tree check not run".
#
# A candidate may be a SKILL DIRECTORY inside the plugin rather than the root (zheref/hatsu#105):
# Claude Code prints `<root>/claude/skills/<name>` as a skill's base directory, and an installed
# skill directory holds only SKILL.md, so a skill cannot run this script from where it stands. Each
# candidate is therefore walked up at most four levels — skills/<name> → skills → claude → root, or
# surfaces/<surface>/skills/<name> on a mirrored copy — and EVERY level is checked for what it IS;
# the walk names its start and its end on stderr. Nothing is accepted by shape.
#
# $CLAUDE_PLUGIN_ROOT is NOT inert off Claude Code: exported from a shell profile it names another
# plugin, and a `[ -d "$root/surfaces/…" ]` guard checks SHAPE, not IDENTITY — a plugin checkout that
# happened to carry a surfaces/ directory would install the wrong plugin's skills into somebody's
# repository with no error anywhere. So a candidate is checked for what it IS.
#
# stdout: the resolved root, absolute, symlinks resolved, alone on one line.
# stderr: every passed-over candidate, on success too — a stale $CLAUDE_PLUGIN_ROOT in a shell
#         profile is a thing to fix, and this is where it becomes visible.
# exit 1: no candidate resolved, with the reason and every rejected path named.
#
# --quoted additionally prints, after a label line, the root as a single-quoted shell literal with
# every ' written '\'' — the line a caller pastes verbatim into `hatsu_root='<…>'`.

# manifest_name FILE — the TOP-LEVEL "name" of a plugin manifest, or nothing. No jq and no grep:
# a stack machine over the ONE shape the tooling writes, JSON.stringify(x, null, 2). Anything else —
# minified, oddly indented, a trailing or missing comma, a mismatched closer, two top-level names,
# or a token JSON would refuse — is REFUSED rather than parsed. Refusal is the safe direction.
manifest_name() {
  awk '
    function scalar(v) { return v ~ /^("([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*"|-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?|true|false|null)$/ }
    function value_ok(v) { return v == "{" || v == "[" || v == "{}" || v == "[]" || scalar(v) }
    NR == 1 { if ($0 != "{") bad = 1; sp = 1; top[1] = "{"; ind[1] = 0; first = 1; comma = 0; next }
    {
      if (bad || done) { bad = 1; next }
      ni = match($0, /[^ ]/) - 1; if (ni < 0) { bad = 1; next }
      body = substr($0, ni + 1)
      if (body ~ /^[}\]],?$/) {
        c = substr(body, 1, 1); tr = (body ~ /,$/)
        if (sp == 0 || ni != ind[sp] || (top[sp] == "{" && c != "}") || (top[sp] == "[" && c != "]") || comma) { bad = 1; next }
        sp--; if (sp == 0) { if (tr) bad = 1; done = 1; next }
        comma = tr; first = 0; next
      }
      if (sp == 0 || ni != ind[sp] + 2 || (!first && !comma)) { bad = 1; next }
      tr = (body ~ /,$/); if (tr) body = substr(body, 1, length(body) - 1)
      if (top[sp] == "{") {
        if (body !~ /^"([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*": /) { bad = 1; next }
        v = body; sub(/^"([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*": /, "", v)
        if (sp == 1 && body ~ /^"name": "/) { s = v; sub(/^"/, "", s); sub(/"$/, "", s); n++; name = s }
      } else v = body
      if (!value_ok(v)) { bad = 1; next }
      if (v == "{" || v == "[") { if (tr) { bad = 1; next }; sp++; top[sp] = v; ind[sp] = ni; first = 1; comma = 0; next }
      comma = tr; first = 0
    }
    END { if (!bad && done && sp == 0 && n == 1) print name }
  ' "$1"
}

# manifest_version FILE — the TOP-LEVEL "version" of a plugin manifest, read by the same stack
# machine as the name (one shape, one parser); empty when the file is refused or carries none.
manifest_version() {
  awk '
    function scalar(v) { return v ~ /^("([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*"|-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?|true|false|null)$/ }
    function value_ok(v) { return v == "{" || v == "[" || v == "{}" || v == "[]" || scalar(v) }
    NR == 1 { if ($0 != "{") bad = 1; sp = 1; top[1] = "{"; ind[1] = 0; first = 1; comma = 0; next }
    {
      if (bad || done) { bad = 1; next }
      ni = match($0, /[^ ]/) - 1; if (ni < 0) { bad = 1; next }
      body = substr($0, ni + 1)
      if (body ~ /^[}\]],?$/) {
        c = substr(body, 1, 1); tr = (body ~ /,$/)
        if (sp == 0 || ni != ind[sp] || (top[sp] == "{" && c != "}") || (top[sp] == "[" && c != "]") || comma) { bad = 1; next }
        sp--; if (sp == 0) { if (tr) bad = 1; done = 1; next }
        comma = tr; first = 0; next
      }
      if (sp == 0 || ni != ind[sp] + 2 || (!first && !comma)) { bad = 1; next }
      tr = (body ~ /,$/); if (tr) body = substr(body, 1, length(body) - 1)
      if (top[sp] == "{") {
        if (body !~ /^"([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*": /) { bad = 1; next }
        v = body; sub(/^"([^"\\[:cntrl:]]|\\["\\\/bfnrt]|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])*": /, "", v)
        if (sp == 1 && body ~ /^"version": "/) { s = v; sub(/^"/, "", s); sub(/"$/, "", s); n++; ver = s }
      } else v = body
      if (!value_ok(v)) { bad = 1; next }
      if (v == "{" || v == "[") { if (tr) { bad = 1; next }; sp++; top[sp] = v; ind[sp] = ni; first = 1; comma = 0; next }
      comma = tr; first = 0
    }
    END { if (!bad && done && sp == 0 && n == 1) print ver }
  ' "$1"
}

# semver_newer A B — exit 0 when A is strictly newer than B, 1 when older or equal, 2 when either is
# not exactly three dot-separated digit fields of at most nine digits (a pre-release or build suffix,
# a one- or two-field version and an over-long field are not ordered here; refusal is the safe
# direction, and the caller says so).
semver_newer() {
  for v in "$1" "$2"; do
    case $v in *.*.*.*|*..*|.*|*.|"") return 2 ;; *.*.*) ;; *) return 2 ;; esac
    case $v in *[!0-9.]*) return 2 ;; esac
    f1=${v%%.*}; rest=${v#*.}; f2=${rest%%.*}; f3=${rest#*.}
    for f in "$f1" "$f2" "$f3"; do case $f in ""|??????????*) return 2 ;; esac; done
  done
  a1=${1%%.*}; r=${1#*.}; a2=${r%%.*}; a3=${r#*.}; b1=${2%%.*}; r=${2#*.}; b2=${r%%.*}; b3=${r#*.}
  [ "$a1" -gt "$b1" ] && return 0; [ "$a1" -lt "$b1" ] && return 1
  [ "$a2" -gt "$b2" ] && return 0; [ "$a2" -lt "$b2" ] && return 1
  [ "$a3" -gt "$b3" ]
}

# shell_quote S — S as a single-quoted shell literal, every ' written '\''.
shell_quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# is_hatsu ROOT — two independent facts: the MANIFEST'S OWN top-level name is `hatsu` (compared
# WHOLE, so a plugin merely carrying the string anywhere is rejected), and a claude/skills/ directory
# exists as a directory, never read from the manifest's own `skills` member.
is_hatsu() {
  [ -n "${1:-}" ] && [ -f "$1/.claude-plugin/plugin.json" ] && [ -d "$1/claude/skills" ] || return 1
  [ "$(manifest_name "$1/.claude-plugin/plugin.json")" = "hatsu" ]
}

quoted=0
[ "${1:-}" = "--quoted" ] && { quoted=1; shift; }

# walk_up PATH — print the first of PATH and its four nearest ancestors that IS a Hatsu root, or
# nothing. `..` segments are resolved by the kernel, so a symlinked skill directory (Cursor's
# .cursor/skills/<name> → <root>/surfaces/cursor/<name>) walks up through its TARGET's parents.
walk_up() {
  probe=$1; depth=0
  while [ "$depth" -le 4 ]; do
    if is_hatsu "$probe"; then printf '%s\n' "$probe"; return 0; fi
    [ -d "$probe" ] || return 1
    probe="$probe/.."; depth=$((depth + 1))
  done
  return 1
}

hatsu_root=""; rejected=""; unusable=""; walked=""; won=""; slot=0
nl="$(printf '\nx')"; nl="${nl%x}"
# The winner is CANONICALISED — absolute, symlinks resolved — so a relative root can never reach a
# --gates argument nen resolves against --repo. Four guards, and $hatsu_root is assigned only once
# all four pass: a candidate carrying a newline is refused BEFORE the walk (walk_up hands its answer
# back through a command substitution, which strips trailing newlines, so the old `-ef` guard alone
# could no longer see one — Feitan, zheref/hatsu#105 review); cd runs with CDPATH cleared and its
# stdout dropped, so a relative candidate resolves where the file tests looked and a CDPATH hit can
# neither redirect it nor leak into the path (`cd -P`, so a symlinked skill directory walks up
# through its TARGET); `-ef` proves the captured path IS the candidate's directory; and the
# canonical path is checked for identity AGAIN, so what is printed is what passed is_hatsu.
for cand in "${HATSU_PLUGIN_ROOT:-}" "${1:-}" "${CLAUDE_PLUGIN_ROOT:-}"; do
  slot=$((slot + 1)); [ -n "$cand" ] || continue
  case $cand in *"$nl"*) unusable="$unusable $(printf '%s' "$cand" | tr '\n' '?')"; continue ;; esac
  case $cand in -*) cand=./$cand ;; esac   # an option-looking relative candidate is a path, not a flag
  if ! found=$(walk_up "$cand"); then rejected="$rejected $cand"; continue; fi
  [ "$found" = "$cand" ] || walked="$walked $cand"
  cand=$found
  if r=$(CDPATH= cd -P "$cand" >/dev/null 2>&1 && pwd -P) \
     && [ "$r/." -ef "$cand/." ] && [ "$(printf '%s' "$r" | wc -l)" -eq 0 ] && is_hatsu "$r"; then hatsu_root=$r; case $slot in 1) won='$HATSU_PLUGIN_ROOT' ;; 2) won='the handed path' ;; *) won='$CLAUDE_PLUGIN_ROOT' ;; esac; break; fi
  unusable="$unusable $cand"
done

# The tree is named (zheref/hatsu#67): the git toplevel of the working directory, when it is a Hatsu
# checkout, is compared with what the candidates gave — and NEVER replaces them. The toplevel is
# captured with a sentinel so a trailing newline survives the substitution, refused when it carries
# one, canonicalised, proved identical (-ef) and checked for identity, as every candidate is.
here=""; tree_note=""
if ! command -v git >/dev/null 2>&1; then
  tree_note='hatsu_root.sh: tree check not run — git is not on PATH (zheref/hatsu#67)'
elif top=$(CDPATH= git rev-parse --show-toplevel 2>/dev/null && printf x); then
  top=${top%x}; top=${top%"$nl"}
  case $top in *"$nl"*) tree_note='hatsu_root.sh: tree check not run — the working tree'"'"'s toplevel carries a newline (zheref/hatsu#67)' ;;
  *) if [ -n "$top" ] && r=$(CDPATH= cd -P "$top" >/dev/null 2>&1 && pwd -P) && [ "$r/." -ef "$top/." ] \
        && [ "$(printf '%s' "$r" | wc -l)" -eq 0 ] && is_hatsu "$r"; then here=$r; fi ;;
  esac
fi
if [ -n "$here" ]; then
  export_line="export HATSU_PLUGIN_ROOT=$(shell_quote "$here")"
  if [ -z "$hatsu_root" ]; then
    tree_note="hatsu_root.sh: no candidate resolved; the checkout in front of you ($here) is a Hatsu checkout but a tree never binds itself — $export_line to bind it, then run the warm-up again (zheref/hatsu#67)"
  elif [ "$here/." -ef "$hatsu_root/." ]; then
    :
  else
    vh=$(manifest_version "$here/.claude-plugin/plugin.json"); vr=$(manifest_version "$hatsu_root/.claude-plugin/plugin.json")
    semver_newer "$vh" "$vr"; cmp=$?
    if [ "$cmp" -eq 2 ]; then
      tree_note="hatsu_root.sh: the checkout in front of you ($here, version ${vh:-unreadable}) and the root $won resolved ($hatsu_root, version ${vr:-unreadable}) cannot be ordered — the resolved root stays; $export_line binds the tree (zheref/hatsu#67)"
    elif [ "$cmp" -eq 0 ]; then
      tree_note="hatsu_root.sh: the checkout in front of you ($here, version $vh) is newer than the root $won resolved ($hatsu_root, version $vr) — the bound pin stays: this session's skill bodies came from it; read $here/claude/skills/<name>/SKILL.md for the tree's protocol, and $export_line binds the tree from the next session (not on Claude Code, whose bodies are the installed pin's) (zheref/hatsu#67)"
    else
      tree_note="hatsu_root.sh: the checkout in front of you ($here, version $vh) is not newer than the root $won resolved ($hatsu_root, version $vr); the resolved root stays (zheref/hatsu#67)"
    fi
  fi
fi

[ -z "$rejected$unusable" ] || printf 'hatsu_root.sh: passed over —%s%s\n' \
  "${rejected:+ rejected (not a Hatsu checkout, nor inside one within four levels):$rejected.}" \
  "${unusable:+ unusable (path cannot be handed on as one line):$unusable.}" >&2
[ -z "$walked" ] || printf 'hatsu_root.sh: resolved by walking up from%s%s\n' "$walked" "${hatsu_root:+ → $hatsu_root}" >&2

[ -z "$tree_note" ] || printf '%s\n' "$tree_note" >&2

if [ -z "$hatsu_root" ]; then
  printf '%s %s%s%s\n' \
    "hatsu_root.sh: NOT INSTALLED. No Hatsu source root." \
    "${rejected:+Rejected (no .claude-plugin/plugin.json naming hatsu at its top level, there or within four levels above):$rejected. }" \
    "${unusable:+Unusable (a Hatsu checkout whose path cannot be handed on as one line):$unusable. }" \
    "\$HATSU_PLUGIN_ROOT is unset or is not a Hatsu checkout, no usable path was handed to this invocation, and this surface has no plugin registry to ask." >&2
  exit 1
fi

printf '%s\n' "$hatsu_root"
[ "$quoted" -eq 1 ] && {
  echo "hatsu_root resolved. The NEXT LINE is the quoted value every later block pastes verbatim, quotes included:"
  printf "'%s'\n" "$(printf '%s' "$hatsu_root" | sed "s/'/'\\\\''/g")"
}
exit 0
