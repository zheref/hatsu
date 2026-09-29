#!/usr/bin/env bash
# Prove scripts/surface_link_check.sh (zheref/hatsu#72): a tree whose relative .md links all resolve is
# exit 0; one dangling link is exit 1 naming the file, the link and the resolved path; links with a
# fragment resolve by their path; absolute, http(s), mailto and fragment-only links are never judged;
# a nested mirror one directory deeper is the #71 regression and is caught; a root that is not a
# Hatsu checkout or has no surfaces/ is a wiring refusal at exit 2; --summary prints the classes.
# Offline, hermetic, writes only under mktemp.

set -euo pipefail
export LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
guard="$script_dir/surface_link_check.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-surface-link.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "surface-link-fixture: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "$message: expected '$needle' in: $haystack" ;;
  esac
}

# run <expected exit> <args...>: stdout+stderr in $out
run() {
  local expected="$1"; shift
  set +e
  out="$(bash "$guard" "$@" 2>&1)"
  code=$?
  set -e
  [ "$code" -eq "$expected" ] || fail "'$*' exited $code, expected $expected: $out"
}

make_root() {
  local r="$1"
  mkdir -p "$r/.claude-plugin" "$r/claude/skills/ten" "$r/docs" "$r/surfaces/codex/ten" "$r/surfaces/codex/agents" "$r/surfaces/antigravity/skills/ten"
  printf '%s\n' '{' '  "name": "hatsu",' '  "version": "0.1.0"' '}' > "$r/.claude-plugin/plugin.json"
  printf '%s\n' '# ten' > "$r/claude/skills/ten/SKILL.md"
  printf '%s\n' '# surfaces' > "$r/docs/SURFACES.md"
  printf '%s\n' '# kurapika' > "$r/surfaces/codex/agents/kurapika.md"
}

# --- a clean tree: every relative link resolves, the rest are never judged ---
clean="$fixture_root/clean"
make_root "$clean"
cat > "$clean/surfaces/codex/ten/SKILL.md" <<'EOF'
See [the surfaces doc](../../../docs/SURFACES.md), [§ 4](../../../docs/SURFACES.md#4-the-check),
[the lead persona](../agents/kurapika.md), [an absolute path](/docs/SURFACES.md), a
[web link](https://example.invalid/x.md), [mail](mailto:nobody@example.invalid), [a fragment](#here) and
[a script](../../../scripts/dist_tag.sh).
EOF
mkdir -p "$clean/scripts"; printf '%s\n' '#!/bin/sh' > "$clean/scripts/dist_tag.sh"
printf '%s\n' '# nested' 'Reads [the hub](../../../../docs/SURFACES.md).' > "$clean/surfaces/antigravity/skills/ten/SKILL.md"
printf '%s\n' 'name = "kurapika"' 'developer_instructions = "Reads [the hub](../../../docs/SURFACES.md)."' > "$clean/surfaces/codex/agents/kurapika.toml"
run 0 "$clean"
assert_contains "$out" 'every relative link under surfaces/ resolves (6 checked)' 'a clean tree is exit 0 and counts only relative links, .toml bodies included'
run 2 . --summary "$clean"
assert_contains "$out" 'unexpected argument' 'an extra positional is refused, never silently dropped'

# --- one dangling link: exit 1, file · link · resolved path named ---
one="$fixture_root/one"
make_root "$one"
printf '%s\n' '# ten' 'Reads [a missing doc](../../../docs/MISSING.md).' > "$one/surfaces/codex/ten/SKILL.md"
printf '%s\n' '# nested' 'Reads [the hub](../../../../docs/SURFACES.md).' > "$one/surfaces/antigravity/skills/ten/SKILL.md"
run 1 "$one"
assert_contains "$out" $'surfaces/codex/ten/SKILL.md\t../../../docs/MISSING.md\tsurfaces/codex/ten/../../../docs/MISSING.md' 'the dangling row names file, link and resolved path'
assert_contains "$out" '1 of 2 relative link(s) under surfaces/ dangle' 'the verdict counts'

# --- the #71 regression: a nested mirror carrying the flat mirror's depth ---
nested="$fixture_root/nested"
make_root "$nested"
printf '%s\n' '# ten' 'Reads [the hub](../../../docs/SURFACES.md).' > "$nested/surfaces/codex/ten/SKILL.md"
printf '%s\n' '# nested' 'Reads [the hub](../../../docs/SURFACES.md).' > "$nested/surfaces/antigravity/skills/ten/SKILL.md"   # one level short
run 1 "$nested"
assert_contains "$out" $'surfaces/antigravity/skills/ten/SKILL.md\t../../../docs/SURFACES.md' 'the nested mirror at flat depth dangles'
case "$out" in *$'surfaces/codex/ten/SKILL.md\t'*) fail "the flat mirror's correct link was reported as dangling" ;; esac

# --- a non-.md relative target (a script, a template, a JSON file) is judged like any other ---
nonmd="$fixture_root/nonmd"
make_root "$nonmd"
printf '%s\n' '# ten' 'Runs [the tag block](../../../scripts/dist_tag.sh) and reads [the example](../../../templates/graph.example.json).' > "$nonmd/surfaces/codex/ten/SKILL.md"
printf '%s\n' '# nested' 'Reads [the hub](../../../../docs/SURFACES.md).' > "$nonmd/surfaces/antigravity/skills/ten/SKILL.md"
mkdir -p "$nonmd/scripts"; printf '%s\n' '#!/bin/sh' > "$nonmd/scripts/dist_tag.sh"
run 1 "$nonmd"
assert_contains "$out" $'surfaces/codex/ten/SKILL.md\t../../../templates/graph.example.json' 'a dangling non-.md target is reported'
case "$out" in *$'dist_tag.sh\t'*) fail "a resolving non-.md target was reported as dangling" ;; esac

# --- a Codex persona .toml body is scanned like a markdown file ---
tomltree="$fixture_root/toml"
make_root "$tomltree"
printf '%s\n' '# ten' 'Reads [the hub](../../../docs/SURFACES.md).' > "$tomltree/surfaces/codex/ten/SKILL.md"
printf '%s\n' '# nested' > "$tomltree/surfaces/antigravity/skills/ten/SKILL.md"
printf '%s\n' 'name = "kurapika"' 'developer_instructions = "Reads [a skill](../skills/build/SKILL.md)."' > "$tomltree/surfaces/codex/agents/kurapika.toml"
run 1 "$tomltree"
assert_contains "$out" $'surfaces/codex/agents/kurapika.toml\t../skills/build/SKILL.md' 'a dangling link inside a persona .toml is reported'

# --- an unreadable mirror file is a wiring refusal, never a file with zero links ---
if [ "$(id -u)" -ne 0 ]; then
  unread="$fixture_root/unread"
  make_root "$unread"
  printf '%s\n' '# ten' 'Reads [the hub](../../../docs/SURFACES.md).' > "$unread/surfaces/codex/ten/SKILL.md"
  printf '%s\n' '# nested' > "$unread/surfaces/antigravity/skills/ten/SKILL.md"
  chmod 000 "$unread/surfaces/antigravity/skills/ten/SKILL.md"
  run 2 "$unread"
  assert_contains "$out" 'cannot read' 'an unreadable mirror file is exit 2'
  chmod 644 "$unread/surfaces/antigravity/skills/ten/SKILL.md"
fi

# --- an empty surfaces/ is a wiring refusal, not a clean tree ---
emptysurf="$fixture_root/emptysurf"
make_root "$emptysurf"
rm -rf "$emptysurf/surfaces"; mkdir -p "$emptysurf/surfaces"
run 2 "$emptysurf"
assert_contains "$out" 'holds no generated file to read' 'an empty surfaces/ is exit 2'

# --- the three CommonMark forms: angle-bracketed, titled, reference definition -- resolving and dangling ---
forms="$fixture_root/forms"
make_root "$forms"
cat > "$forms/surfaces/codex/ten/SKILL.md" <<'FORMS'
# ten
Angle [ok](<../../../docs/SURFACES.md>) and [bad](<../../../docs/GONE-A.md>).
Titled [ok](../../../docs/SURFACES.md "the hub") and [bad](../../../docs/GONE-B.md 'gone').
Reference use [hub][h] and [gone][g].

[h]: ../../../docs/SURFACES.md
[g]: <../../../docs/GONE-C.md>
FORMS
printf '%s\n' '# nested' > "$forms/surfaces/antigravity/skills/ten/SKILL.md"
run 1 "$forms"
assert_contains "$out" $'\t../../../docs/GONE-A.md\t' 'an angle-bracketed dangling target is reported (unwrapped)'
assert_contains "$out" $'\t../../../docs/GONE-B.md\t' 'a titled dangling target is reported (title dropped)'
assert_contains "$out" $'\t../../../docs/GONE-C.md\t' 'a reference-definition dangling target is reported (unwrapped)'
assert_contains "$out" '3 of 6 relative link(s) under surfaces/ dangle' 'the three resolving forms count and pass'

# --- --summary prints classes before the verdict ---
run 1 --summary "$nested"
assert_contains "$out" 'antigravity · skills (nested) · ../../../docs/' '--summary classifies by surface, kind and prefix'

# --- wiring refusals: not a Hatsu checkout; no surfaces/ ---
plain="$fixture_root/plain"
mkdir -p "$plain/surfaces"
run 2 "$plain"
assert_contains "$out" 'not a Hatsu checkout' 'a non-Hatsu root is a wiring refusal'
nosurf="$fixture_root/nosurf"
make_root "$nosurf"
rm -rf "$nosurf/surfaces"
run 2 "$nosurf"
assert_contains "$out" 'carries no surfaces/ directory' 'a root with no surfaces/ is a wiring refusal'
run 2 "$fixture_root/does-not-exist"

echo 'surface-link-fixture: ok'
