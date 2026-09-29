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

hatsu_root=""; rejected=""; unusable=""; walked=""
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
  [ -n "$cand" ] || continue
  case $cand in *"$nl"*) unusable="$unusable $(printf '%s' "$cand" | tr '\n' '?')"; continue ;; esac
  case $cand in -*) cand=./$cand ;; esac   # an option-looking relative candidate is a path, not a flag
  if ! found=$(walk_up "$cand"); then rejected="$rejected $cand"; continue; fi
  [ "$found" = "$cand" ] || walked="$walked $cand"
  cand=$found
  if r=$(CDPATH= cd -P "$cand" >/dev/null 2>&1 && pwd -P) \
     && [ "$r/." -ef "$cand/." ] && [ "$(printf '%s' "$r" | wc -l)" -eq 0 ] && is_hatsu "$r"; then hatsu_root=$r; break; fi
  unusable="$unusable $cand"
done

[ -z "$rejected$unusable" ] || printf 'hatsu_root.sh: passed over —%s%s\n' \
  "${rejected:+ rejected (not a Hatsu checkout, nor inside one within four levels):$rejected.}" \
  "${unusable:+ unusable (path cannot be handed on as one line):$unusable.}" >&2
[ -z "$walked" ] || printf 'hatsu_root.sh: resolved by walking up from%s%s\n' "$walked" "${hatsu_root:+ → $hatsu_root}" >&2

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
