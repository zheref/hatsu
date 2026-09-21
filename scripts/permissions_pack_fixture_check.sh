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

echo "permissions-pack-fixture: all assertions passed"
