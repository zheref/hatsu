#!/usr/bin/env bash
# Exercise the trusted guard preflight against a throwaway Hatsu checkout.
set -euo pipefail
script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
source_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-trusted-guard.XXXXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT

git clone -q --no-local --branch main "$source_root" "$fixture/checkout"
checkout="$fixture/checkout"
preflight="$source_root/scripts/trusted_guard_preflight.rb"
# The maintainer's core main can lag; use the fetched trusted base this effort
# actually targets, including when the fixture runs from a PR checkout.
git -C "$checkout" fetch -q "$source_root" refs/remotes/origin/main
git -C "$checkout" checkout -q -B main FETCH_HEAD
git -C "$checkout" update-ref refs/remotes/origin/main HEAD

ruby "$preflight" --root "$checkout" --base-ref origin/main > "$fixture/pass.log" 2>&1
grep -q 'every derived trusted guard passed' "$fixture/pass.log" \
  || { cat "$fixture/pass.log"; echo 'trusted-guard-preflight-fixture: known root did not pass' >&2; exit 1; }
for guard in branch_authorship_check.sh canon_contracts_check.sh plugin_bump_check.sh prose_size_check.sh surface_link_check.sh surface_mirror_check.sh workflow_runner_policy_check.rb; do
  grep -q "  $guard: exit 0" "$fixture/pass.log" \
    || { cat "$fixture/pass.log"; echo "trusted-guard-preflight-fixture: $guard was not run" >&2; exit 1; }
done

# A broken candidate contract must be rejected by the trusted canon guard.
printf '{invalid json\n' > "$checkout/contracts/direct.registry.json"
set +e
ruby "$preflight" --root "$checkout" --base-ref origin/main > "$fixture/canon-red.log" 2>&1
code=$?
set -e
[ "$code" -eq 1 ] && grep -q 'canon_contracts_check.sh: exit 1' "$fixture/canon-red.log" \
  && grep -q 'direct registry' "$fixture/canon-red.log" \
  || { cat "$fixture/canon-red.log"; echo 'trusted-guard-preflight-fixture: broken canon registry was not named' >&2; exit 1; }
git -C "$checkout" reset -q --hard HEAD

# The working tree generates Codex at a new hooks root. The trusted main
# guard still knows only the old root and must demand the two-step landing.
ruby -e 'p=ARGV.fetch(0); s=File.read(p); old=%q{${PLUGIN_ROOT:-${HATSU_PLUGIN_ROOT:-./.codex}}}; abort "root missing" unless s.include?(old); File.write(p,s.sub(old,%q{${PLUGIN_ROOT:-${HATSU_PLUGIN_ROOT:-./.codex-next}}}))' \
  "$checkout/scripts/surface_mirror_check.sh"
bash "$checkout/scripts/surface_mirror_regenerate.sh" "$checkout" > "$fixture/regenerate.log"
set +e
ruby "$preflight" --root "$checkout" --base-ref origin/main > "$fixture/red.log" 2>&1
code=$?
set -e
[ "$code" -eq 1 ] || { cat "$fixture/red.log"; echo "trusted-guard-preflight-fixture: new root exited $code, expected 1" >&2; exit 1; }
grep -q 'surface_mirror_check.sh: exit 1' "$fixture/red.log" \
  || { cat "$fixture/red.log"; echo 'trusted-guard-preflight-fixture: old mirror guard was not red' >&2; exit 1; }
grep -q 'two-step landing in docs/GATE-CONFIGURATION.md' "$fixture/red.log" \
  || { cat "$fixture/red.log"; echo 'trusted-guard-preflight-fixture: missing two-step guidance' >&2; exit 1; }

# The trusted plugin-bump workflow submits both sides of a rename. A staged
# rename out of the plugin surface must remain visible to the preflight.
git -C "$checkout" reset -q --hard HEAD
git -C "$checkout" clean -q -fd
git -C "$checkout" mv claude/skills/aka/SKILL.md moved-skill.md
set +e
ruby "$preflight" --root "$checkout" --base-ref origin/main > "$fixture/rename.log" 2>&1
code=$?
set -e
[ "$code" -eq 1 ] && grep -q 'plugin_bump_check.sh: exit 1' "$fixture/rename.log" \
  || { cat "$fixture/rename.log"; echo 'trusted-guard-preflight-fixture: staged rename escaped plugin bump' >&2; exit 1; }

# A staged-only edit must also reach the old guard before PR creation.
git -C "$checkout" reset -q --hard HEAD
git -C "$checkout" clean -q -fd
printf '\nStaged fixture edit.\n' >> "$checkout/claude/skills/aka/SKILL.md"
git -C "$checkout" add claude/skills/aka/SKILL.md
set +e
ruby "$preflight" --root "$checkout" --base-ref origin/main > "$fixture/staged.log" 2>&1
code=$?
set -e
[ "$code" -eq 1 ] && grep -q 'plugin_bump_check.sh: exit 1' "$fixture/staged.log" \
  || { cat "$fixture/staged.log"; echo 'trusted-guard-preflight-fixture: staged edit escaped plugin bump' >&2; exit 1; }

# A non-main PR base supplies its own trusted guard revision.
git -C "$checkout" reset -q --hard HEAD
git -C "$checkout" clean -q -fd
git -C "$checkout" config user.name 'Hatsu fixture'
git -C "$checkout" config user.email 'fixture@example.invalid'
ruby -e 'p=ARGV.fetch(0); s=File.read(p); old="#!/bin/sh\n"; abort "guard shebang missing" unless s.start_with?(old); File.write(p,s.sub(old, "#{old}exit 1 # fixture base guard\n"))' \
  "$checkout/scripts/prose_size_check.sh"
git -C "$checkout" add scripts/prose_size_check.sh
git -C "$checkout" commit -qm 'fixture: alternate trusted guard'
git -C "$checkout" update-ref refs/remotes/origin/preflight-test HEAD
set +e
ruby "$preflight" --root "$checkout" --base-ref origin/preflight-test > "$fixture/alternate.log" 2>&1
code=$?
set -e
[ "$code" -eq 1 ] && grep -q 'prose_size_check.sh: exit 1' "$fixture/alternate.log" \
  || { cat "$fixture/alternate.log"; echo 'trusted-guard-preflight-fixture: alternate base guard was not run' >&2; exit 1; }

# Discover unknown scripts from the base workflow and refuse missing wiring.
cat >> "$checkout/.github/workflows/plugin-bump-check.yml" <<'YAML'
  fixture-unknown-guard:
    runs-on: ubuntu-latest
    steps:
      - run: bash .trusted/scripts/unrecognized_guard.sh
YAML
printf '#!/bin/sh\nexit 0\n' > "$checkout/scripts/unrecognized_guard.sh"
git -C "$checkout" add .github/workflows/plugin-bump-check.yml scripts/unrecognized_guard.sh
git -C "$checkout" commit -qm 'fixture: add unknown trusted guard'
git -C "$checkout" update-ref refs/remotes/origin/preflight-unknown HEAD
set +e
ruby "$preflight" --root "$checkout" --base-ref origin/preflight-unknown > "$fixture/unknown.log" 2>&1
code=$?
set -e
[ "$code" -eq 2 ] && grep -q 'no local invocation for trusted guard(s): unrecognized_guard.sh' "$fixture/unknown.log" \
  || { cat "$fixture/unknown.log"; echo 'trusted-guard-preflight-fixture: unknown trusted guard was not a wiring error' >&2; exit 1; }

echo 'trusted-guard-preflight-fixture: ok (canon pass/red, unknown guard refusal, old guard regression cases)'
