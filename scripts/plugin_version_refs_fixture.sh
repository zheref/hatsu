#!/usr/bin/env bash
# Prove the version-reference list and conservative write on a scratch Git tree.
set -euo pipefail
here="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-version-refs.XXXXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
fail() { echo "plugin-version-refs-fixture: $*" >&2; exit 1; }

git -C "$tmp" init -q
git -C "$tmp" config user.name 'Hatsu fixture'
git -C "$tmp" config user.email 'fixture@example.invalid'
mkdir -p "$tmp/.claude-plugin" "$tmp/.codex-plugin" "$tmp/docs" "$tmp/surfaces/codex"
printf '{\n  "version": "1.2.3"\n}\n' > "$tmp/.claude-plugin/plugin.json"
printf '{\n  "version": "1.2.3"\n}\n' > "$tmp/.codex-plugin/plugin.json"
printf '## v1.2.3 — draft\n\n## v1.2.3-old is ambiguous\n' > "$tmp/CHANGELOG.md"
printf 'New in v1.2.3: an authoring helper.\nFrom v1.2.3: historical context.\nNew in v1.2.3-rc.1 is a prerelease.\nNew in v1.2.3-old is another label.\nNew in v1.2.3.4 is another version.\n' > "$tmp/README.md"
printf 'from v1.2.3 in another source\n' > "$tmp/docs/notes.md"
printf '<!-- GENERATED stamp 1.2.3 -->\n' > "$tmp/surfaces/codex/AGENTS.md"
git -C "$tmp" add -- .claude-plugin .codex-plugin CHANGELOG.md README.md docs surfaces
git -C "$tmp" commit -qm 'fixture: version references'

bash "$here/plugin_version_refs.sh" --root "$tmp" --from 1.2.3 --to 1.2.4 > "$tmp/list.log"
git -C "$tmp" diff --quiet || fail 'list-only changed the scratch tree'
for expected in '.claude-plugin/plugin.json:2: rewrite' '.codex-plugin/plugin.json:2: rewrite' \
  'CHANGELOG.md:1: rewrite' 'README.md:1: rewrite' 'README.md:2: review' \
  'README.md:3: review' 'README.md:4: review' 'README.md:5: review' \
  'docs/notes.md:1: review' 'surfaces/codex/AGENTS.md:1: generated'; do
  grep -Fq "$expected" "$tmp/list.log" || fail "list-only missed $expected"
done
grep -Fq 'use --body-file <local-draft>' "$tmp/list.log" || fail 'PR-body reminder missing'

bash "$here/plugin_version_refs.sh" --root "$tmp" --from 1.2.3 --to 1.2.4 --write > "$tmp/write.log"
grep -Fq '"version": "1.2.4"' "$tmp/.claude-plugin/plugin.json" || fail 'Claude manifest not rewritten'
grep -Fq '"version": "1.2.4"' "$tmp/.codex-plugin/plugin.json" || fail 'Codex manifest not rewritten'
grep -Fq '## v1.2.4 — draft' "$tmp/CHANGELOG.md" || fail 'CHANGELOG heading not rewritten'
grep -Fq 'New in v1.2.4' "$tmp/README.md" || fail 'new-in line not rewritten'
grep -Fq 'From v1.2.3' "$tmp/README.md" || fail 'ambiguous README line was rewritten'
grep -Fq 'New in v1.2.3-rc.1' "$tmp/README.md" || fail 'prerelease reference was rewritten'
grep -Fq 'New in v1.2.3-old' "$tmp/README.md" || fail 'hyphenated reference was rewritten'
grep -Fq 'New in v1.2.3.4' "$tmp/README.md" || fail 'longer version was rewritten'
grep -Fq 'v1.2.3-old' "$tmp/CHANGELOG.md" || fail 'ambiguous heading was rewritten'
grep -Fq 'from v1.2.3' "$tmp/docs/notes.md" || fail 'ambiguous source was rewritten'
grep -Fq 'stamp 1.2.3' "$tmp/surfaces/codex/AGENTS.md" || fail 'generated mirror was rewritten'
grep -Fq 'rewrote 4' "$tmp/write.log" || fail 'write count did not name four unambiguous lines'
grep -Fq 'run bash scripts/surface_mirror_regenerate.sh' "$tmp/write.log" || fail 'mirror reminder missing'

# An explicit local body draft is independent of tracked-file rewrite forms.
# A stub would expose any accidental remote PR command.
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nprintf remote-called > "%s"\nexit 99\n' "$tmp/remote-called" > "$tmp/bin/gh"
chmod +x "$tmp/bin/gh"
body="$tmp/body draft.md"
printf 'Plugin 1.2.3 and `v1.2.3`\r\nRelease: v1.2.3\nAmbiguous 1.2.3-rc.1\nMixed 1.2.3 and 1.2.3.4\nPrefix 11.2.3 and build1.2.3\nUnchanged 8.9.0\nNo final newline: 1.2.3' > "$body"
cp "$body" "$tmp/body.before"
PATH="$tmp/bin:$PATH" bash "$here/plugin_version_refs.sh" --root "$tmp" --from 1.2.3 --to 1.2.4 \
  --body-file 'body draft.md' > "$tmp/body-list.log"
cmp -s "$body" "$tmp/body.before" || fail 'body list-only changed the draft'
for expected in ':1: rewrite:' ':2: rewrite:' ':3: review:' ':4: review:' ':5: review:' ':7: rewrite:'; do
  grep -Fq "body draft.md$expected" "$tmp/body-list.log" || fail "body list-only missed $expected"
done
PATH="$tmp/bin:$PATH" bash "$here/plugin_version_refs.sh" --root "$tmp" --from 1.2.3 --to 1.2.4 \
  --body-file "$body" --write > "$tmp/body-write.log"
printf 'Plugin 1.2.4 and `v1.2.4`\r\nRelease: v1.2.4\nAmbiguous 1.2.3-rc.1\nMixed 1.2.3 and 1.2.3.4\nPrefix 11.2.3 and build1.2.3\nUnchanged 8.9.0\nNo final newline: 1.2.4' > "$tmp/body.expected"
cmp -s "$body" "$tmp/body.expected" || fail 'body write changed ambiguous lines or lost exact versions/line endings'
grep -Fq 'rewrote 4 occurrence(s)' "$tmp/body-write.log" || fail 'draft occurrence count wrong'
[ ! -e "$tmp/remote-called" ] || fail 'body helper invoked remote PR command'

# A generated file or symlink cannot be smuggled through the draft flag.
ln -s "$body" "$tmp/body-link.md"
for refused in "$tmp/body-link.md" "$tmp/surfaces/codex/AGENTS.md" "$tmp/missing.md"; do
  set +e
  bash "$here/plugin_version_refs.sh" --root "$tmp" --from 1.2.3 --to 1.2.4 \
    --body-file "$refused" --write > "$tmp/body-refused.log" 2>&1
  code=$?
  set -e
  [ "$code" -eq 2 ] || fail "invalid body $refused exited $code, expected 2"
done
cmp -s "$body" "$tmp/body.expected" || fail 'refused draft touched symlink target'
grep -Fq 'stamp 1.2.3' "$tmp/surfaces/codex/AGENTS.md" || fail 'draft flag rewrote a generated mirror'

# A sibling whose name merely begins with surfaces is an ordinary local draft.
mkdir -p "$tmp/surfaces-draft"
printf 'Plugin 1.2.3\n' > "$tmp/surfaces-draft/body.md"
bash "$here/plugin_version_refs.sh" --root "$tmp" --from 1.2.3 --to 1.2.4 \
  --body-file "$tmp/surfaces-draft/body.md" --write > "$tmp/body-boundary.log"
grep -Fxq 'Plugin 1.2.4' "$tmp/surfaces-draft/body.md" || fail 'surfaces-prefixed sibling draft was refused'

# A local replacement of a tracked directory must not make --write touch a
# file outside the checkout.
outside="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-version-refs-outside.XXXXXXXX")"
trap 'rm -rf -- "$tmp" "$outside"' EXIT
# A lexical mirror path stays excluded when its ancestor resolves outside.
mkdir -p "$outside/mirror"
printf 'Plugin 1.2.4\n' > "$outside/mirror/AGENTS.md"
cp "$outside/mirror/AGENTS.md" "$tmp/mirror.before"
cp "$tmp/.claude-plugin/plugin.json" "$tmp/manifest.before"
mv "$tmp/surfaces/codex" "$tmp/surfaces/codex.saved"
ln -s "$outside/mirror" "$tmp/surfaces/codex"
set +e
bash "$here/plugin_version_refs.sh" --root "$tmp" --from 1.2.4 --to 1.2.5 \
  --body-file "$tmp/surfaces/codex/AGENTS.md" --write > "$tmp/mirror-escape.log" 2>&1
code=$?
set -e
[ "$code" -eq 2 ] || fail "mirror ancestor symlink exited $code, expected 2"
cmp -s "$outside/mirror/AGENTS.md" "$tmp/mirror.before" || fail 'mirror ancestor target was rewritten'
cmp -s "$tmp/.claude-plugin/plugin.json" "$tmp/manifest.before" || fail 'mirror refusal changed a tracked manifest'
rm "$tmp/surfaces/codex"
mv "$tmp/surfaces/codex.saved" "$tmp/surfaces/codex"

mv "$tmp/docs" "$tmp/docs.saved"
ln -s "$outside" "$tmp/docs"
printf 'new in v1.2.3 outside\n' > "$outside/notes.md"
set +e
bash "$here/plugin_version_refs.sh" --root "$tmp" --from 1.2.3 --to 1.2.4 --write > "$tmp/escape.log" 2>&1
code=$?
set -e
[ "$code" -eq 2 ] || fail "symlink escape refusal exited $code, expected 2"
grep -Fq 'new in v1.2.3 outside' "$outside/notes.md" || fail 'outside file was rewritten'
rm "$tmp/docs"
mv "$tmp/docs.saved" "$tmp/docs"

set +e
bash "$here/plugin_version_refs.sh" --root "$tmp" --from 1.2.3 --to 1.2.3 > "$tmp/bad.log" 2>&1
code=$?
set -e
[ "$code" -eq 2 ] || fail "same-version refusal exited $code, expected 2"

# --check-nen-pin: the page's echoed pin line against the contract's two values.
pin="$tmp/pin"
mkdir -p "$pin/nen" "$pin/docs"
printf '{"dependency": {"minimum": "0.9", "pinned_ref": "v0.9.0"}}\n' > "$pin/nen/contract.json"
echo_line() {
  printf '# Range\n\n*Current pin, echoed for convenience:* **`nen >= %s`**, with the bootstrap installing **`%s`**.\n' \
    "$1" "$2" > "$pin/docs/NEN-CONTRACT.md"
}
pin_case() { # <expected exit> <label>
  set +e
  bash "$here/plugin_version_refs.sh" --check-nen-pin --root "$pin" > "$tmp/pin.log" 2>&1
  code=$?
  set -e
  [ "$code" -eq "$1" ] || fail "nen pin $2 exited $code, expected $1: $(cat "$tmp/pin.log")"
}
echo_line 0.9 v0.9.0; pin_case 0 'agreement'
grep -Fq 'nen pin echo agrees (nen >= 0.9, v0.9.0)' "$tmp/pin.log" || fail 'agreement line missing'
echo_line 0.8 v0.9.0; pin_case 1 'stale minimum'
grep -Fq 'echoes nen >= 0.8 installing v0.9.0; nen/contract.json says minimum 0.9, pinned_ref v0.9.0' \
  "$tmp/pin.log" || fail 'drift line missing'
echo_line 0.9 v0.8.0; pin_case 1 'stale pinned_ref'
printf 'no pin line here\n' > "$pin/docs/NEN-CONTRACT.md"; pin_case 2 'missing pin line'
echo_line 0.9 v0.9.0; printf '{"dependency": {}}\n' > "$pin/nen/contract.json"; pin_case 2 'contract without values'
printf '{"dependency": \n' > "$pin/nen/contract.json"; pin_case 2 'malformed contract JSON'
printf '{"dependency": {"minimum": "0.9", "pinned_ref": "v0.9.0"}}\n' > "$pin/nen/contract.json"
rm -f "$pin/docs/NEN-CONTRACT.md"; pin_case 2 'missing page'
echo_line 0.9 v0.9.0; tail -n 1 "$pin/docs/NEN-CONTRACT.md" >> "$pin/docs/NEN-CONTRACT.md"; pin_case 2 'duplicated pin line'
printf '*Current pin, echoed for convenience:* nen at least 0.9.\n' > "$pin/docs/NEN-CONTRACT.md"; pin_case 2 'unparseable pin line'
outside="$tmp/outside"; mkdir -p "$outside"; echo_line 0.9 v0.9.0; mv "$pin/docs/NEN-CONTRACT.md" "$outside/page.md"
ln -s "$outside/page.md" "$pin/docs/NEN-CONTRACT.md"; pin_case 2 'page resolving outside the root'
rm -f "$pin/docs/NEN-CONTRACT.md"
spaced="$tmp/a root"; mv "$pin" "$spaced"; pin="$spaced"; echo_line 0.9 v0.9.0; pin_case 0 'root with a space'

# The committed tree itself: the live echo must agree, so a repin that leaves it stale fails this lane.
set +e
bash "$here/plugin_version_refs.sh" --check-nen-pin --root "$here/.." > "$tmp/live.log" 2>&1
code=$?
set -e
[ "$code" -eq 0 ] || fail "the committed tree's nen pin echo exited $code: $(cat "$tmp/live.log")"

echo 'plugin-version-refs-fixture: list-only, conservative write, local draft, mirrors, ambiguity, the nen pin echo and the live echo passed'
