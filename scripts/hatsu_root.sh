#!/bin/sh
# hatsu_root.sh — resolve the Hatsu plugin root and print it ALONE on stdout.
#
#   scripts/hatsu_root.sh [<a candidate path the harness handed this invocation>]
#
# Three candidates and no fourth, in order, the first that passes winning:
#   1. $HATSU_PLUGIN_ROOT   — the form that works on all surfaces, and the one to prefer
#   2. $1                   — the path this invocation was handed
#   3. $CLAUDE_PLUGIN_ROOT  — Claude Code's own, kept last so one resolution serves every surface
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

hatsu_root=""; rejected=""; unusable=""
# The winner is CANONICALISED — absolute, symlinks resolved — so a relative root can never reach a
# --gates argument nen resolves against --repo. Three guards, and $hatsu_root is assigned only once
# all three pass: cd runs with CDPATH cleared and its stdout dropped, so a relative candidate
# resolves where the file tests looked and a CDPATH hit can neither redirect it nor leak into the
# path; `-ef` proves the captured path IS the candidate's directory, so a trailing newline command
# substitution stripped is caught rather than pointed elsewhere; and a root containing a newline is
# refused outright, because the handoff is ONE line.
for cand in "${HATSU_PLUGIN_ROOT:-}" "${1:-}" "${CLAUDE_PLUGIN_ROOT:-}"; do
  [ -n "$cand" ] || continue
  case $cand in -*) cand=./$cand ;; esac   # an option-looking relative candidate is a path, not a flag
  if ! is_hatsu "$cand"; then rejected="$rejected $cand"; continue; fi
  if r=$(CDPATH= cd "$cand" >/dev/null 2>&1 && pwd -P) \
     && [ "$r/." -ef "$cand/." ] && [ "$(printf '%s' "$r" | wc -l)" -eq 0 ]; then hatsu_root=$r; break; fi
  unusable="$unusable $cand"
done

[ -z "$rejected$unusable" ] || printf 'hatsu_root.sh: passed over —%s%s\n' \
  "${rejected:+ rejected (not a Hatsu checkout):$rejected.}" \
  "${unusable:+ unusable (path cannot be handed on as one line):$unusable.}" >&2

if [ -z "$hatsu_root" ]; then
  printf '%s %s%s%s\n' \
    "hatsu_root.sh: NOT INSTALLED. No Hatsu source root." \
    "${rejected:+Rejected (no .claude-plugin/plugin.json naming hatsu at its top level):$rejected. }" \
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
