#!/usr/bin/env bash
# plugin_bump_check_hostile_fixture.sh -- QA-16 hostile-input corpus for the
# 0.43.0 plugin-bump guard, and the QA-18 negative tests it ships without.
#
# TEST-ONLY. Nothing installed reads this file; it is not a plugin surface.
#
# scripts/plugin_bump_check_fixture.sh (the declared `plugin-bump-guard` lane)
# covers the HAPPY corpus of the new strict-increase comparison: equal, lower,
# malformed, and one increase at each semver position. It drives none of the
# corpus QA-16 names -- empty, missing, malformed JSON, non-UTF-8, a path with
# spaces, an unterminated last line -- and it asserts nothing about the one
# input the guard is handed that it cannot re-derive: the BASE manifest.
#
# Every case below is written so PASSING means FAILING CLOSED.
#
#   bash scripts/plugin_bump_check_hostile_fixture.sh
#
# Exit 0 if every case failed closed; exit 1 naming each that did not.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$HERE/plugin_bump_check.sh"
[ -f "$GUARD" ] || { echo "no guard at $GUARD" >&2; exit 2; }

root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-bump-hostile.XXXXXX")"
trap 'rm -rf "$root"' EXIT
fails=0

fail() { printf 'FAIL  %s\n' "$*" >&2; fails=$((fails + 1)); }
pass() { printf 'ok    %s\n' "$*"; }

# The manifests. HEAD never increases anywhere in this file, so a guard that
# fails closed must exit 1 on EVERY case.
printf '%s\n' '{"version":"0.43.0"}' > "$root/base-good.json"
printf '%s\n' '{"version":"0.43.0"}' > "$root/head-same.json"
printf '%s\n' '{}'                   > "$root/base-no-version.json"
printf '%s'   '{"version": "0.43.0"' > "$root/base-truncated.json"   # malformed JSON
: >                                    "$root/base-empty.json"        # zero bytes
printf '\xff\xfe\x00binary'          > "$root/base-non-utf8.json"     # non-UTF-8
printf '%s\n' 'no opt-out is declared here' > "$root/body.md"

# Changed-file lists.
printf 'claude/skills/aka/SKILL.md\n'  > "$root/cf.txt"
printf 'claude/skills/aka/SKILL.md'    > "$root/cf-no-final-newline.txt"
mkdir -p "$root/dir with spaces"
printf 'claude/skills/aka/SKILL.md\n'  > "$root/dir with spaces/cf.txt"

# --- expect_closed NAME CHANGED BASE HEAD BODY -------------------------------
# The guard must exit 1 (refuse). Exit 0 is a FAIL-OPEN: a plugin surface
# changed, the version did not increase, and the guard let it through.
expect_closed() {
  local name="$1" changed="$2" base="$3" head="$4" body="$5" out rc
  out="$(bash "$GUARD" "$changed" "$base" "$head" "$body" 2>&1)"; rc=$?
  case "$rc" in
    1) pass "$name -- refused (exit 1)" ;;
    2) pass "$name -- refused as an input defect (exit 2)" ;;
    0) fail "$name -- FAIL-OPEN: exit 0 on an unbumped plugin surface. Guard said: ${out%%$'\n'*}" ;;
    *) fail "$name -- unexpected exit $rc: ${out%%$'\n'*}" ;;
  esac
}

# 1 · The BASE manifest corpus. `.github/workflows/plugin-bump-check.yml` writes
#     `{}` into this file whenever `gh api .../contents/...` fails for ANY
#     reason -- `... 2>/dev/null || echo '{}' > base_plugin.json`. Every shape
#     below therefore reaches the guard in production, and none of them is
#     evidence that the head version increased.
expect_closed 'base manifest has no version (the workflows API fallback)' \
  "$root/cf.txt" "$root/base-no-version.json" "$root/head-same.json" "$root/body.md"
expect_closed 'base manifest is malformed JSON' \
  "$root/cf.txt" "$root/base-truncated.json" "$root/head-same.json" "$root/body.md"
expect_closed 'base manifest is empty' \
  "$root/cf.txt" "$root/base-empty.json" "$root/head-same.json" "$root/body.md"
expect_closed 'base manifest is non-UTF-8' \
  "$root/cf.txt" "$root/base-non-utf8.json" "$root/head-same.json" "$root/body.md"
expect_closed 'base manifest is missing entirely' \
  "$root/cf.txt" "$root/base-absent.json" "$root/head-same.json" "$root/body.md"

# 2 · The changed-files corpus.
expect_closed 'changed-files last line is unterminated' \
  "$root/cf-no-final-newline.txt" "$root/base-good.json" "$root/head-same.json" "$root/body.md"
expect_closed 'changed-files path contains spaces' \
  "$root/dir with spaces/cf.txt" "$root/base-good.json" "$root/head-same.json" "$root/body.md"
# The CLI tests the changed-files list with `-f` (exists) and never for
# READABILITY, and any_path_is_plugin_surface's `while read ... < "$file"`
# answers "no surface changed" when the redirect fails.
printf 'claude/skills/aka/SKILL.md\n' > "$root/cf-unreadable.txt"
chmod 000 "$root/cf-unreadable.txt"
expect_closed 'changed-files list is unreadable (mode 000)' \
  "$root/cf-unreadable.txt" "$root/base-good.json" "$root/head-same.json" "$root/body.md"
chmod 644 "$root/cf-unreadable.txt"

# 3 · The control. A good base and an unbumped head must still refuse, so a
#     pass above is never a pass for the wrong reason.
expect_closed 'control: well-formed base, unbumped head' \
  "$root/cf.txt" "$root/base-good.json" "$root/head-same.json" "$root/body.md"

# 4 · An INVISIBLE opt-out declaration must not satisfy the guard: markdown
#     that GitHub's own renderer never shows is not a maintainer stating
#     anything, and the fenced-code case is this file's OWN refusal message
#     quoting the phrase as an example rather than declaring it (QA-24).
printf '%s\n' '<!-- no plugin bump: hidden in an HTML comment -->' > "$root/body-html-comment.md"
printf '%s\n' 'A comment can span lines too:' > "$root/body-html-comment-multiline.md"
printf '%s\n' '<!--' >> "$root/body-html-comment-multiline.md"
printf '%s\n' 'no plugin bump: multiple lines' >> "$root/body-html-comment-multiline.md"
printf '%s\n' '-->' >> "$root/body-html-comment-multiline.md"
{
  printf '%s\n' 'See the guard'"'"'s own refusal message:'
  printf '%s\n' '```'
  printf '%s\n' 'no plugin bump: <reason>'
  printf '%s\n' '```'
} > "$root/body-fenced-code.md"

expect_closed 'opt-out hidden inside an HTML comment' \
  "$root/cf.txt" "$root/base-good.json" "$root/head-same.json" "$root/body-html-comment.md"
expect_closed 'opt-out hidden inside a multi-line HTML comment' \
  "$root/cf.txt" "$root/base-good.json" "$root/head-same.json" "$root/body-html-comment-multiline.md"
expect_closed 'opt-out only quoted inside a fenced code block' \
  "$root/cf.txt" "$root/base-good.json" "$root/head-same.json" "$root/body-fenced-code.md"

if [ "$fails" -ne 0 ]; then
  printf '\nplugin-bump-hostile: %s case(s) failed open\n' "$fails" >&2
  exit 1
fi
printf '\nplugin-bump-hostile: every hostile input failed closed\n'
