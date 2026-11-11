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
grep -q 'every runnable trusted guard passed' "$fixture/pass.log" \
  || { cat "$fixture/pass.log"; echo 'trusted-guard-preflight-fixture: known root did not pass' >&2; exit 1; }
for guard in branch_authorship_check.sh canon_contracts_check.sh direct_matrix_ci_check.mts plugin_bump_api_retry.mts plugin_bump_check.sh private_name_check_fixture.sh prose_size_check.sh surface_link_check.sh surface_mirror_check.sh workflow_runner_policy_check.rb; do
  grep -q "  $guard: exit 0" "$fixture/pass.log" \
    || { cat "$fixture/pass.log"; echo "trusted-guard-preflight-fixture: $guard was not run" >&2; exit 1; }
done

grep -q '    changed files: 1' "$fixture/pass.log" \
  || { cat "$fixture/pass.log"; echo 'trusted-guard-preflight-fixture: plugin-bump API helper did not report its verdict' >&2; exit 1; }
ruby "$preflight" --root "$checkout" --check-adapters

grep -q '  readiness_ci_verdict.mts: not run (' "$fixture/pass.log" \
  || { cat "$fixture/pass.log"; echo 'trusted-guard-preflight-fixture: the readiness verdict was not named as not run' >&2; exit 1; }

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

# Use the installed lint step verbatim in a separate fixture base. The
# unrelated guard adapters have already run above; this control exercises
# the exact archived invocation and its whole-tree verdict in isolation.
git -C "$checkout" reset -q --hard refs/remotes/origin/main
git -C "$checkout" clean -q -fd
cp "$source_root/claude/skills/cleanup/SKILL.md" "$checkout/claude/skills/cleanup/SKILL.md"
cp "$source_root/docs/ROSTER.md" "$checkout/docs/ROSTER.md"
# Retain the full repository data, but give the archived control only the
# actual canon lint step and disable discovery of other jobs.
fixture_workflow="$checkout/.github/workflows/prose-ambiguity-check.yml"
ruby -rpsych -e '
  source, target = ARGV
  data = Psych.safe_load(File.read(source, encoding: "UTF-8"))
  step = data.fetch("jobs").fetch("canon-lint").fetch("steps").find { |row| row["name"] == "Canon prose lint" }
  abort "installed canon lint step missing" unless step
  File.write(target, Psych.dump("on" => { "pull_request_target" => {} }, "jobs" => { "canon-lint" => { "steps" => [step] } }))
' "$source_root/.github/workflows/prose-ambiguity-check.yml" "$fixture_workflow"
for workflow in "$checkout"/.github/workflows/*.yml; do
  # Keep cited paths in the fixture tree while excluding their jobs from discovery.
  [ "$workflow" = "$fixture_workflow" ] || printf 'name: fixture-only\n' > "$workflow"
done
git -C "$checkout" add -A
git -C "$checkout" commit -qm 'fixture: a base workflow running the canon lint'
git -C "$checkout" update-ref refs/remotes/origin/preflight-canon HEAD
ruby "$preflight" --root "$checkout" --base-ref origin/preflight-canon --list > "$fixture/canon-list.log" 2>&1 \
  && grep -Fq '  nen-canon-lint (prose-ambiguity-check.yml)' "$fixture/canon-list.log" \
  || { cat "$fixture/canon-list.log"; echo 'trusted-guard-preflight-fixture: the Nen canon lint was not derived' >&2; exit 1; }
ruby "$preflight" --root "$checkout" --base-ref origin/preflight-canon > "$fixture/canon-lint.log" 2>&1 \
  || { cat "$fixture/canon-lint.log"; exit 1; }
grep -q '  nen-canon-lint: exit 0' "$fixture/canon-lint.log" \
  && grep -q '    canon lint: [0-9]* files · 0 new · 0 stale · 0 grown' "$fixture/canon-lint.log" \
  && ! grep -q 'no local invocation' "$fixture/canon-lint.log" \
  || { cat "$fixture/canon-lint.log"; echo 'trusted-guard-preflight-fixture: the canon lint adapter did not run green with its verdict line' >&2; exit 1; }
[ -z "$(find "$checkout/.nen" -maxdepth 1 -name 'trusted-guard-preflight-*' 2>/dev/null)" ] \
  || { echo 'trusted-guard-preflight-fixture: the canon lint contracts copy was left under .nen/' >&2; exit 1; }

# The red path: a finding in the working tree outside the baseline makes the derived lint exit 1,
# the preflight red naming it, and the contracts copy is still removed (the ensure covers the exit).
printf '\nThis fixture step is done by hand.\n' >> "$checkout/docs/GATE-CONFIGURATION.md"
set +e
ruby "$preflight" --root "$checkout" --base-ref origin/preflight-canon > "$fixture/canon-red-lint.log" 2>&1
code=$?
set -e
[ "$code" -eq 1 ] && grep -q '  nen-canon-lint: exit 1' "$fixture/canon-red-lint.log" \
  && grep -q 'docs/GATE-CONFIGURATION.md:[0-9]* · PL-01 · .*fixture step is done by hand' "$fixture/canon-red-lint.log" \
  && grep -q 'canon lint: [0-9]* files · 1 new · 0 stale · 0 grown' "$fixture/canon-red-lint.log" \
  && grep -q 'nen-canon-lint: fix the prose or remove the stale baseline row' "$fixture/canon-red-lint.log" \
  || { cat "$fixture/canon-red-lint.log"; echo "trusted-guard-preflight-fixture: a planted finding did not redden the canon lint with the finding and its remedy named (exit $code)" >&2; exit 1; }
[ -z "$(find "$checkout/.nen" -maxdepth 1 -name 'trusted-guard-preflight-*' 2>/dev/null)" ] \
  || { echo 'trusted-guard-preflight-fixture: the contracts copy was left under .nen/ after a red lint' >&2; exit 1; }
git -C "$checkout" checkout -q -- docs/GATE-CONFIGURATION.md

# A trusted base that derives the lint but lacks one of its contracts is a wiring refusal (exit 2),
# named, and leaves no contract copy behind.
git -C "$checkout" rm -q contracts/prose.lint.json
git -C "$checkout" commit -qm 'fixture: a base deriving the canon lint without its rules'
git -C "$checkout" update-ref refs/remotes/origin/preflight-canon-norules HEAD
set +e
ruby "$preflight" --root "$checkout" --base-ref origin/preflight-canon-norules > "$fixture/canon-norules.log" 2>&1
code=$?
set -e
[ "$code" -eq 2 ] && grep -q 'trusted revision has no contracts/prose.lint.json for the canon lint' "$fixture/canon-norules.log" \
  || { cat "$fixture/canon-norules.log"; echo "trusted-guard-preflight-fixture: a base without the lint rules was not a wiring refusal (exit $code)" >&2; exit 1; }
[ -z "$(find "$checkout/.nen" -maxdepth 1 -name 'trusted-guard-preflight-*' 2>/dev/null)" ] \
  || { echo 'trusted-guard-preflight-fixture: the contracts copy was left under .nen/ after a wiring refusal' >&2; exit 1; }
git -C "$checkout" reset -q --hard refs/remotes/origin/preflight-canon

# A repin is valid candidate wiring even when hosted CI supplies the current base binary.
base_nen="$(command -v nen)"
ruby -rjson -e '
  path = ARGV.fetch(0)
  data = JSON.parse(File.read(path))
  data.dig("dependency", "bootstrap", "sha256").transform_values! { "a" * 64 }
  File.write(path, JSON.pretty_generate(data) + "\n")
' "$checkout/nen/contract.json"
NEN="$base_nen" ruby "$preflight" --root "$checkout" --check-adapters > "$fixture/candidate-repin.log" 2>&1 \
  || { cat "$fixture/candidate-repin.log"; exit 1; }
git -C "$checkout" checkout -q -- nen/contract.json

# An ordinary newer bind can coexist with the exact base executable.
newer_nen="$fixture/newer-nen"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo 0.30.99; exit 0; }\nexit 42\n' > "$newer_nen"
chmod +x "$newer_nen"
NEN="$newer_nen" HATSU_TRUSTED_BASE_NEN="$base_nen" \
  ruby "$preflight" --root "$checkout" --base-ref origin/preflight-canon > "$fixture/base-executable.log" 2>&1 \
  && grep -q 'nen-canon-lint: exit 0' "$fixture/base-executable.log" \
  || { cat "$fixture/base-executable.log"; exit 1; }

# Reject a different local binary before executing it. The same file is used
# for the silent-verdict case after its digest is pinned in the fixture base.
silent_nen="$fixture/silent-nen"
printf '#!/bin/sh\nexit 0\n' > "$silent_nen"
chmod +x "$silent_nen"
set +e
NEN="$base_nen" HATSU_TRUSTED_BASE_NEN="$silent_nen" ruby "$preflight" --root "$checkout" --base-ref origin/preflight-canon > "$fixture/canon-wrong-bin.log" 2>&1
code=$?
set -e
[ "$code" -eq 2 ] && grep -q 'selected Nen does not match the trusted' "$fixture/canon-wrong-bin.log" \
  || { cat "$fixture/canon-wrong-bin.log"; echo 'trusted-guard-preflight-fixture: an unverified binary was not refused' >&2; exit 1; }
ruby -rjson -rdigest -e '
  path, binary = ARGV
  data = JSON.parse(File.read(path))
  data.dig("dependency", "bootstrap", "sha256").transform_values! { Digest::SHA256.file(binary).hexdigest }
  File.write(path, JSON.pretty_generate(data) + "\n")
' "$checkout/nen/contract.json" "$silent_nen"
git -C "$checkout" commit -qam 'fixture: pin a silent Nen'
git -C "$checkout" update-ref refs/remotes/origin/preflight-canon-silent HEAD
set +e
HATSU_TRUSTED_BASE_NEN="$silent_nen" ruby "$preflight" --root "$checkout" --base-ref origin/preflight-canon-silent > "$fixture/canon-silent.log" 2>&1
code=$?
set -e
[ "$code" -eq 1 ] && grep -q 'nen-canon-lint: not run (exited 0 without its verdict line' "$fixture/canon-silent.log" \
  || { cat "$fixture/canon-silent.log"; echo "trusted-guard-preflight-fixture: a silent exit 0 from the lint was not refused (exit $code)" >&2; exit 1; }
git -C "$checkout" reset -q --hard refs/remotes/origin/preflight-canon

# Discover unknown scripts from the base workflow and refuse missing wiring.
git -C "$checkout" reset -q --hard refs/remotes/origin/main
cat >> "$checkout/.github/workflows/plugin-bump-check.yml" <<'YAML'
  fixture-unknown-guard:
    runs-on: ubuntu-latest
    steps:
      - run: bash .trusted/scripts/unrecognized_guard.sh
YAML
printf '#!/bin/sh\nexit 0\n' > "$checkout/scripts/unrecognized_guard.sh"
set +e
ruby "$preflight" --root "$checkout" --check-adapters > "$fixture/candidate.log" 2>&1
code=$?
set -e
[ "$code" -eq 2 ] && grep -q 'unrecognized_guard.sh: no local invocation' "$fixture/candidate.log" \
  || { cat "$fixture/candidate.log"; echo 'trusted-guard-preflight-fixture: candidate adapter check did not name the gap' >&2; exit 1; }

git -C "$checkout" add .github/workflows/plugin-bump-check.yml scripts/unrecognized_guard.sh
git -C "$checkout" commit -qm 'fixture: add unknown trusted guard'
git -C "$checkout" update-ref refs/remotes/origin/preflight-unknown HEAD
set +e
ruby "$preflight" --root "$checkout" --base-ref origin/preflight-unknown > "$fixture/unknown.log" 2>&1
code=$?
set -e
[ "$code" -eq 2 ] && grep -q '^  unrecognized_guard.sh: not run (no local invocation)$' "$fixture/unknown.log" \
  || { cat "$fixture/unknown.log"; echo 'trusted-guard-preflight-fixture: unknown trusted guard was not named as not run' >&2; exit 1; }
ruby "$preflight" --root "$checkout" --base-ref origin/preflight-unknown --list \
  | awk '/^  / { print $1 }' > "$fixture/derived.txt"
awk '/^  [^ ]+: (exit |not run )/ { sub(/:$/, "", $1); print $1 }' "$fixture/unknown.log" > "$fixture/reported.txt"
diff -u "$fixture/derived.txt" "$fixture/reported.txt" \
  || { cat "$fixture/unknown.log"; echo 'trusted-guard-preflight-fixture: each derived guard needs exactly one result' >&2; exit 1; }
grep -q '^  workflow_runner_policy_check.rb: exit [01]$' "$fixture/unknown.log" \
  && grep -q '^  plugin_bump_api_retry.mts: exit 0$' "$fixture/unknown.log" \
  && ! grep -q 'every runnable trusted guard passed' "$fixture/unknown.log" \
  || { cat "$fixture/unknown.log"; echo 'trusted-guard-preflight-fixture: missing adapter stopped other guards or read green' >&2; exit 1; }

echo 'trusted-guard-preflight-fixture: ok (canon pass/red, the pinned Nen canon lint derived and run with clean, finding, candidate repin, separate base binary, missing rules, wrong binary and silent paths proven, unknown guard refusal, old guard regression cases)'
