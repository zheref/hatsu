#!/usr/bin/env bash
# permissions_pack_fixture_check.sh — regression fixture for
# scripts/permissions_pack.sh's codex `writable_roots` population
# (zheref/hatsu#94, Copilot thread B).
#
# WHY. `nen surface mirror generate` emits `.codex/config.toml` with
# `sandbox_workspace_write.writable_roots = []` — a placeholder the generator
# itself cannot fill in, since it has no target repository to inspect.
# permissions_pack.sh's `--install` used to copy that placeholder verbatim,
# so every installed codex surface ran with an EMPTY writable-roots list —
# nothing was ever actually writable inside the sandbox, defeating the whole
# point of `sandbox_mode = "workspace-write"`. This fixture builds a scratch
# git repository with a linked worktree and a `nen/repos.json` carrying a
# consumer `path` field, installs the codex pack into it, and asserts the
# placed `.codex/config.toml` names every root the maintainer's ruling
# requires: the target's own toplevel, every linked worktree, the absolute
# git common dir, and any declared local `path` from nen/repos.json — then
# re-installs and asserts the result is byte-identical (idempotent), and
# separately asserts a TRACKED `.codex/config.toml` is left untouched.
#
# Invoked by hand or from `scripts/surface_bootstrap_fixture_check.sh`'s own
# lane; exits 0 only if every assertion below holds.

set -euo pipefail
LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
hatsu_root="$(CDPATH='' cd -- "$script_dir/.." >/dev/null 2>&1 && pwd -P)"
pack="$hatsu_root/scripts/permissions_pack.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-permissions-pack.XXXXXX")"
# Resolved through `pwd -P`: on macOS `$TMPDIR` lives under a `/var` that is
# itself a symlink to `/private/var`, and git's own `rev-parse` answers with
# the resolved (`/private/...`) form — comparing against the unresolved path
# below would fail on a real difference that is not one.
fixture_root="$(CDPATH='' cd -- "$fixture_root" && pwd -P)"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  echo "permissions-pack-fixture: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required for this fixture"

main="$fixture_root/main"
wt="$fixture_root/wt"
mkdir -p "$main/nen"
git -C "$main" init -q 2>/dev/null || { mkdir -p "$main"; git -C "$main" init -q; }
git -C "$main" config user.email fixture@hatsu.test
git -C "$main" config user.name "Hatsu Fixture"

cat > "$main/nen/contract.json" <<'EOF'
{"placeholder": true}
EOF
cat > "$main/nen/repos.json" <<EOF
{
  "consumers": [
    {"repo": "acme/widget", "role": "fixture", "path": "$fixture_root/acme-widget"}
  ],
  "maintained_tools": [
    {"repo": "zheref/hatsu", "role": "fixture"}
  ]
}
EOF
git -C "$main" add -A
git -C "$main" commit -q -m init
git -C "$main" branch -q feature
git -C "$main" worktree add -q "$wt" feature

toplevel="$(git -C "$main" rev-parse --show-toplevel)"
common_dir="$(git -C "$main" rev-parse --path-format=absolute --git-common-dir)"
declared_path="$fixture_root/acme-widget"

bash "$pack" --surface claude-code --install --target "$main" --hatsu-root "$hatsu_root" >/dev/null
claude_settings="$main/.claude/settings.local.json"
rendered_claude="$fixture_root/rendered-claude.json"
bash "$pack" --surface claude-code --render --hatsu-root "$hatsu_root" > "$rendered_claude"
node "$hatsu_root/scripts/permissions_pack_release_fixture.ts" "$claude_settings" "$rendered_claude" "$hatsu_root"
echo "ok    Claude Code pack renders only the declared plugin lane's release plan and publication forms"
node - "$hatsu_root/surfaces/cursor/cli.json" <<'JS'
const fs = require('node:fs');
// A GRANT is what must never appear: deny rows naming gh api (HA#331's ceremony denies) are refusals, not grants.
const { permissions } = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const allow = (permissions && permissions.allow) || [];
if (!Array.isArray(allow) || allow.length === 0) throw new Error('Cursor cli.json carries no permissions.allow list to check');
if (allow.some((entry) => entry.startsWith('Shell(node:') || entry.startsWith('Shell(gh:api'))) {
  throw new Error('Cursor inherited an unbounded API reader or raw gh api grant');
}
if (!((permissions.deny) || []).includes('Shell(gh:secret set *)')) throw new Error('Cursor lost the gh secret set deny row (HA#331)');
JS
node "$hatsu_root/scripts/gh_api_read_fixture.mts"
node - "$claude_settings" <<'JS'
const fs = require('node:fs');
const path = process.argv[2];
const doc = JSON.parse(fs.readFileSync(path, 'utf8'));
doc.permissions.allow.push('Bash(gh api *)', 'Bash(node */scripts/gh_api_read.mts *)',
  "Bash(node '/tmp/retired-plugin/scripts/gh_api_read.mts' *)", 'Bash(echo user-owned)');
fs.writeFileSync(path, JSON.stringify(doc));
JS
bash "$pack" --surface claude-code --install --target "$main" --hatsu-root "$hatsu_root" >/dev/null
node - "$claude_settings" <<'JS'
const fs = require('node:fs');
const allow = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')).permissions.allow;
if (!allow.includes('Bash(gh api *)') || !allow.includes('Bash(node */scripts/gh_api_read.mts *)') ||
    !allow.includes("Bash(node '/tmp/retired-plugin/scripts/gh_api_read.mts' *)") ||
    !allow.includes('Bash(echo user-owned)')) {
  throw new Error('Claude upgrade did not preserve entries with unknown ownership');
}
JS
echo "ok    Claude Code upgrade keeps ambiguous legacy rows, foreign paths and user entries"

bash "$pack" --surface codex --install --target "$main" --hatsu-root "$hatsu_root" >/dev/null

placed="$main/.codex/config.toml"
[ -f "$placed" ] || fail "no .codex/config.toml placed at $placed"

line="$(grep '^writable_roots' "$placed" || true)"
[ -n "$line" ] || fail "no writable_roots line in placed config.toml"

for expect in "$toplevel" "$wt" "$common_dir" "$declared_path"; do
  case "$line" in
    *"$expect"*) : ;;
    *) fail "writable_roots is missing expected root: $expect -- line was: $line" ;;
  esac
done
case "$line" in
  *"writable_roots = []"*) fail "writable_roots is still the unfilled placeholder" ;;
esac
echo "ok    writable_roots names the toplevel, the linked worktree, the git common dir, and the declared consumer path"

# The placed .codex/hooks.json (CWE-426, Feitan on #151): the mirror resolves
# ${PLUGIN_ROOT:-${HATSU_PLUGIN_ROOT:-./.codex}} for the Codex PLUGIN's hooks; a placed copy is a
# project-local hook that Codex never hands a PLUGIN_ROOT, so the pack places it with that rung
# dropped, the same rewrite scripts/surface_bootstrap.sh applies, and keeps nen's marker.
hooks="$main/.codex/hooks.json"
[ -f "$hooks" ] || fail "no .codex/hooks.json placed"
! grep -qF '${PLUGIN_ROOT' "$hooks" || fail "the placed .codex/hooks.json still reads PLUGIN_ROOT"
grep -q 'GENERATED by nen surface mirror (surface: codex' "$hooks" || fail "the placed .codex/hooks.json lost its generated marker"
sed 's#${PLUGIN_ROOT:-${HATSU_PLUGIN_ROOT:-./.codex}}#${HATSU_PLUGIN_ROOT:-./.codex}#g' "$hatsu_root/surfaces/codex/hooks.json" |
  cmp -s - "$hooks" || fail "the placed .codex/hooks.json is not the mirror with PLUGIN_ROOT dropped"
pack_sed="$(grep -o "sed 's#\${PLUGIN_ROOT[^']*'" "$pack" || true)"
boot_sed="$(grep -o "sed 's#\${PLUGIN_ROOT[^']*'" "$hatsu_root/scripts/surface_bootstrap.sh" || true)"
[ -n "$pack_sed" ] && [ "$pack_sed" = "$boot_sed" ] || fail "placed-hooks rewrite: expected the same nonempty sed in permissions_pack and surface_bootstrap; pack='${pack_sed:-<none>}', bootstrap='${boot_sed:-<none>}'"
rendered="$(bash "$pack" --surface codex --render --hatsu-root "$hatsu_root")"
case "$rendered" in *'${PLUGIN_ROOT'*) fail "--render shows a hooks root the pack would not place" ;; esac
echo "ok    the placed .codex/hooks.json drops PLUGIN_ROOT, keeps its marker, and matches surface_bootstrap.sh's rewrite"

# --plugin: the Codex plugin serves the hooks, so the pack leaves .codex/hooks.json out and says so;
# it is refused off codex.
rm -f "$hooks"
plugin_out="$(bash "$pack" --surface codex --install --target "$main" --hatsu-root "$hatsu_root" --plugin)"
[ ! -e "$hooks" ] || fail "--plugin placed .codex/hooks.json"
case "$plugin_out" in
  *'not placed: .codex/hooks.json (the Codex plugin serves the hooks)'*) ;;
  *) fail "--plugin did not say why .codex/hooks.json was not placed: $plugin_out" ;;
esac
off_codex=0
bash "$pack" --surface cursor --install --target "$main" --hatsu-root "$hatsu_root" --plugin >/dev/null 2>&1 || off_codex=$?
[ "$off_codex" = 2 ] || fail "--plugin with --surface cursor exited $off_codex, expected 2"
bash "$pack" --surface codex --install --target "$main" --hatsu-root "$hatsu_root" >/dev/null
[ -f "$hooks" ] || fail "a later install without --plugin did not place .codex/hooks.json again"
echo "ok    --plugin leaves .codex/hooks.json to the Codex plugin, and is refused off codex"

before="$(cat "$placed")"
bash "$pack" --surface codex --install --target "$main" --hatsu-root "$hatsu_root" >/dev/null
after="$(cat "$placed")"
[ "$before" = "$after" ] || fail "re-install is not idempotent -- config.toml changed on a second run"
echo "ok    re-install is idempotent"

git -C "$main" add -f .codex/config.toml
git -C "$main" commit -q -m "track codex config"
printf '\n# hand-edited, tracked\n' >> "$placed"
git -C "$main" add -f .codex/config.toml
git -C "$main" commit -q -m "hand edit"
tracked_before="$(cat "$placed")"
bash "$pack" --surface codex --install --target "$main" --hatsu-root "$hatsu_root" >/dev/null || true
tracked_after="$(cat "$placed")"
[ "$tracked_before" = "$tracked_after" ] || fail "a TRACKED .codex/config.toml was overwritten"
echo "ok    a tracked .codex/config.toml is left alone"

# The user modes are render/read only, even if they are aimed at a valid
# checkout. Use only a scratch configuration directory for their fixtures.
export HOME="$fixture_root/home"
export CLAUDE_CONFIG_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_CONFIG_DIR" "$fixture_root/cli"
printf '#!/bin/sh\necho 2.1.295\n' > "$fixture_root/cli/claude"
chmod 700 "$fixture_root/cli/claude"
export PATH="$fixture_root/cli:$PATH"
user_settings="$CLAUDE_CONFIG_DIR/settings.json"
result="$fixture_root/pack-output"
run_pack() {
  local expected="$1" status=0
  shift
  bash "$pack" "$@" --hatsu-root "$hatsu_root" >"$result" 2>&1 || status=$?
  [ "$status" = "$expected" ] || fail "pack exited $status, expected $expected: $(cat "$result")"
}

run_pack 0 --help
grep -q -- '--render-user' "$result" || fail "help omitted the render-only user mode"
run_pack 2 --bogus
grep -q 'unknown argument' "$result" || fail "an unknown flag lacked its reason"
run_pack 2 --surface cursor --check-user --target "$main"
grep -q -- '--check-user requires --surface claude-code' "$result" || fail "non-Claude user check lacked its refusal"
run_pack 2 --surface claude-code --render-user --install --target "$main"
grep -q 'choose exactly one' "$result" || fail "render and install were not mutually exclusive"

run_pack 0 --surface claude-code --check-user --target "$main"
grep -q 'routine user rows missing' "$result" || fail "the missing settings check did not name the gap"
[ ! -e "$user_settings" ] || fail "user check wrote settings"
bash "$pack" --surface claude-code --render-user --target "$main" --hatsu-root "$hatsu_root" \
  >"$result" 2>"$fixture_root/proposal-notes" || fail "the user proposal could not be rendered"
jq -e '.permissions.allow | index("Bash(./scripts/gh_token_env.sh -- nen pr threads settle *)") != null' "$result" >/dev/null ||
  fail "the proposal omitted the narrow relative wrapper rule"
jq -e '.hooks.PreToolUse[0].hooks[0].onFailure == "block"' "$result" >/dev/null ||
  fail "the proposal omitted the paired blocking hook"
[ ! -e "$user_settings" ] || fail "user render wrote settings"
cp "$result" "$user_settings"
run_pack 0 --surface claude-code --check-user --target "$main"
grep -q 'routine user rows present' "$result" || fail "the check did not recognize the user-approved rows"
printf '%s\n' '{"permissions":{"deny":["Bash(nen pr open *)"]},"autoMode":{"classifyAllShell":true}}' > "$user_settings"
cp "$user_settings" "$fixture_root/user-before.json"
run_pack 0 --surface claude-code --check-user --target "$main"
grep -q 'routine user rows missing.*classifyAllShell.*deny in' "$result" || fail "the check missed removed rows or a visible override"
cmp -s "$user_settings" "$fixture_root/user-before.json" || fail "user diagnosis edited settings"
echo "ok    user modes show the proposal, recheck removal, report an override, and keep settings read-only"

run_pack 0 --surface cursor --render
grep -q '# --- .cursor/hooks.json ---' "$result" || fail "Cursor render omitted its hook header"
run_pack 0 --surface antigravity --render
grep -q 'Nothing to write here' "$result" || fail "Antigravity render claimed to place an allowlist"
run_pack 0 --surface cursor --install --target "$wt"
[ -f "$wt/.cursor/cli.json" ] && [ -f "$wt/.cursor/hooks.json" ] || fail "Cursor scratch placement lost its pack files"

nonconsumer="$fixture_root/nonconsumer"
git init -q "$nonconsumer"
run_pack 0 --surface claude-code --install --target "$nonconsumer"
grep -q 'not a Hatsu consumer' "$result" || fail "unadopted repository was not named"
[ ! -e "$nonconsumer/.claude" ] || fail "the installer wrote to an unadopted repository"

mkdir -p "$wt/.claude"
ln -s "$user_settings" "$wt/.claude/settings.local.json"
run_pack 0 --surface claude-code --install --target "$wt"
grep -q 'settings.local.json is a symlink' "$result" || fail "the symlink refusal was not named"
cmp -s "$user_settings" "$fixture_root/user-before.json" || fail "the installer followed a settings symlink"
rm "$wt/.claude/settings.local.json"
printf '%s\n' '{not JSON' > "$wt/.claude/settings.local.json"
run_pack 0 --surface claude-code --install --target "$wt"
grep -q 'could not be read or parsed' "$result" || fail "the malformed file refusal was not named"
[ "$(cat "$wt/.claude/settings.local.json")" = '{not JSON' ] || fail "the installer overwrote malformed settings"
echo "ok    checkout placement reports symlink and malformed settings refusals"

echo "permissions-pack-fixture: all assertions passed"
