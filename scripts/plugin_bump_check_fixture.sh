#!/usr/bin/env bash
# Focused, declared verification for scripts/plugin_bump_check.sh.
# Requires Bash, mktemp and jq (invoked by the guard to read plugin versions).
# Invoked only through `nen shu test --lane plugin-bump-guard --repo <hatsu>`.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' 'plugin-bump-guard fixture: jq is required for this focused lane; install jq 1.6 or newer and rerun nen shu test --lane plugin-bump-guard --repo <hatsu>' >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$repo_root/scripts/plugin_bump_check.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-plugin-bump-guard.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

printf '%s\n' '{"version":"0.16.0"}' > "$fixture_root/base.json"
printf '%s\n' '{"version":"0.16.0"}' > "$fixture_root/head-unchanged.json"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/head-bumped.json"
printf '%s\n' '{"version":"0.15.9"}' > "$fixture_root/head-lower.json"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/head-higher-patch.json"
printf '%s\n' '{"version":"0.17.0"}' > "$fixture_root/head-higher-minor.json"
printf '%s\n' '{"version":"1.0.0"}' > "$fixture_root/head-higher-major.json"
printf '%s\n' '{"version":"not-a-semver"}' > "$fixture_root/head-malformed.json"
printf '%s\n' 'No opt-out is declared by this focused fixture.' > "$fixture_root/body.md"
printf '%s\n' 'docs/DISCOVERY.md' > "$fixture_root/changed-discovery.txt"
printf '%s\n' 'docs/LAUNCH-MIGRATION.md' > "$fixture_root/changed-launch-migration.txt"
printf '%s\n' 'docs/WORKFLOW.md' > "$fixture_root/changed-workflow.txt"
printf '%s\n' 'docs/AGENT-ATTRIBUTION.md' > "$fixture_root/changed-agent-attribution.txt"
printf '%s\n' 'docs/ab/plugin-bump-guard.md' > "$fixture_root/changed-unrelated.txt"
printf '%s\n' 'scripts/hatsu_plugin_update.sh' > "$fixture_root/changed-updater.txt"
printf '%s\n' 'docs/PROCESS.md' > "$fixture_root/changed-process.txt"
printf '%s\n' 'scripts/report_time.sh' > "$fixture_root/changed-report-time.txt"
printf '%s\n' 'scripts/pr_body_evidence_check.sh' > "$fixture_root/changed-evidence-check.txt"
printf '%s\n' 'scripts/pr_body_delivery_check.sh' 'scripts/pr_delivery.ts' > "$fixture_root/changed-delivery-check.txt"
printf '%s\n' 'scripts/send_freshness_check.sh' > "$fixture_root/changed-freshness.txt"
printf '%s\n' 'scripts/kagutsuchi_worktree.sh' > "$fixture_root/changed-kagutsuchi-worktree.txt"
printf '%s\n' 'scripts/cleanup_path_admit.sh' > "$fixture_root/changed-cleanup-path-admit.txt"
printf '%s\n' 'scripts/cleanup_path_admit.ts' > "$fixture_root/changed-cleanup-path-admit-ts.txt"
printf '%s\n' 'scripts/hatsu_surface_link.sh' > "$fixture_root/changed-surface-link.txt"
printf '%s\n' 'scripts/surface_link_check.sh' > "$fixture_root/changed-link-guard.txt"
printf '%s\n' 'scripts/prose_size_check.sh' > "$fixture_root/changed-prose-guard.txt"

run_case() {
  local name="$1" expected_status="$2" changed="$3" head="$4" expected_text="$5" body="${6:-$fixture_root/body.md}"
  local actual_status output

  if output="$(bash "$guard" "$changed" "$fixture_root/base.json" "$head" "$body" 2>&1)"; then
    actual_status=0
  else
    actual_status=$?
  fi

  if [ "$actual_status" -ne "$expected_status" ]; then
    printf '%s: expected exit %s, got %s\n%s\n' "$name" "$expected_status" "$actual_status" "$output" >&2
    exit 1
  fi
  # A here-string, never `printf | grep -q`: grep -q exits at the first match, printf takes SIGPIPE,
  # and under pipefail the pipeline reports failure on a match (Phinks F2, a flake in parallel runs).
  if ! grep -Fq -- "$expected_text" <<<"$output"; then
    printf '%s: missing expected output %s\n%s\n' "$name" "$expected_text" "$output" >&2
    exit 1
  fi
  printf '%s: exit %s\n' "$name" "$actual_status"
}

run_case 'DISCOVERY unchanged version' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-unchanged.json" 'docs/DISCOVERY.md'
run_case 'LAUNCH-MIGRATION unchanged version' 1 "$fixture_root/changed-launch-migration.txt" "$fixture_root/head-unchanged.json" 'docs/LAUNCH-MIGRATION.md'
run_case 'WORKFLOW unchanged version' 1 "$fixture_root/changed-workflow.txt" "$fixture_root/head-unchanged.json" 'docs/WORKFLOW.md'
run_case 'AGENT-ATTRIBUTION unchanged version' 1 "$fixture_root/changed-agent-attribution.txt" "$fixture_root/head-unchanged.json" 'docs/AGENT-ATTRIBUTION.md'
run_case 'DISCOVERY bumped version' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/head-bumped.json" 'plugin.json version bumped'
run_case 'unrelated docs unchanged version' 0 "$fixture_root/changed-unrelated.txt" "$fixture_root/head-unchanged.json" 'no plugin-shipped surface changed'
run_case 'updater script unchanged version' 1 "$fixture_root/changed-updater.txt" "$fixture_root/head-unchanged.json" 'scripts/hatsu_plugin_update.sh'
run_case 'PROCESS unchanged version' 1 "$fixture_root/changed-process.txt" "$fixture_root/head-unchanged.json" 'docs/PROCESS.md'
run_case 'report clock script unchanged version' 1 "$fixture_root/changed-report-time.txt" "$fixture_root/head-unchanged.json" 'scripts/report_time.sh'
run_case 'evidence check script unchanged version' 1 "$fixture_root/changed-evidence-check.txt" "$fixture_root/head-unchanged.json" 'scripts/pr_body_evidence_check.sh'
run_case 'delivery guard and engine unchanged version' 1 "$fixture_root/changed-delivery-check.txt" "$fixture_root/head-unchanged.json" 'scripts/pr_body_delivery_check.sh'
run_case 'freshness gate script unchanged version' 1 "$fixture_root/changed-freshness.txt" "$fixture_root/head-unchanged.json" 'scripts/send_freshness_check.sh'
run_case 'kagutsuchi worktree script unchanged version' 1 "$fixture_root/changed-kagutsuchi-worktree.txt" "$fixture_root/head-unchanged.json" 'scripts/kagutsuchi_worktree.sh'
run_case 'cleanup path admission script unchanged version' 1 "$fixture_root/changed-cleanup-path-admit.txt" "$fixture_root/head-unchanged.json" 'scripts/cleanup_path_admit.sh'
run_case 'cleanup path admission implementation unchanged version' 1 "$fixture_root/changed-cleanup-path-admit-ts.txt" "$fixture_root/head-unchanged.json" 'scripts/cleanup_path_admit.ts'
run_case 'surface link script unchanged version' 1 "$fixture_root/changed-surface-link.txt" "$fixture_root/head-unchanged.json" 'scripts/hatsu_surface_link.sh'
run_case 'link guard script unchanged version' 1 "$fixture_root/changed-link-guard.txt" "$fixture_root/head-unchanged.json" 'scripts/surface_link_check.sh'
run_case 'prose guard script unchanged version' 1 "$fixture_root/changed-prose-guard.txt" "$fixture_root/head-unchanged.json" 'scripts/prose_size_check.sh'
run_case 'surface link script bumped version' 0 "$fixture_root/changed-surface-link.txt" "$fixture_root/head-bumped.json" 'plugin.json version bumped'
run_case 'updater script bumped version' 0 "$fixture_root/changed-updater.txt" "$fixture_root/head-bumped.json" 'plugin.json version bumped'

# --- semver-increase cases (2026-09-20): equal, lower, and malformed all fail;
# a strict increase at any of the three semver positions passes. ------------
run_case 'equal version fails' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-unchanged.json" 'not a strict increase'
run_case 'lower version fails' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-lower.json" 'not a strict increase'
run_case 'higher patch passes' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/head-higher-patch.json" 'plugin.json version bumped'
run_case 'higher minor passes' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/head-higher-minor.json" 'plugin.json version bumped'
run_case 'higher major passes' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/head-higher-major.json" 'plugin.json version bumped'
run_case 'malformed head version fails' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-malformed.json" 'not a strict increase'

# --- full SemVer 2.0.0 grammar cases (2026-09-20) ---------------------------
# semver_parts now validates the full grammar rather than a narrower
# approximation: MAJOR.MINOR.PATCH each `0|[1-9][0-9]*`, an optional
# `-<prerelease>` of non-empty dot-separated `[0-9A-Za-z-]+` identifiers
# (numeric ones with no leading zero unless exactly `0`), and an optional
# `+<build>` of the same identifier shape. Anything outside that grammar is
# malformed and refused, same as any other unparseable version. Pre-release
# stays out of scope for ordering — a well-formed prerelease/build head still
# needs a numeric MAJOR.MINOR.PATCH increase over base to pass.
printf '%s\n' '{"version":"0.43.1-"}' > "$fixture_root/head-semver-empty-prerelease.json"
printf '%s\n' '{"version":"01.2.3"}' > "$fixture_root/head-semver-leading-zero-major.json"
printf '%s\n' '{"version":"1.02.3"}' > "$fixture_root/head-semver-leading-zero-minor.json"
printf '%s\n' '{"version":"1.2.3-01"}' > "$fixture_root/head-semver-leading-zero-prerelease.json"
printf '%s\n' '{"version":"1.2.3-"}' > "$fixture_root/head-semver-trailing-dash.json"
printf '%s\n' '{"version":"1.2.3+"}' > "$fixture_root/head-semver-trailing-plus.json"
printf '%s\n' '{"version":"0.16.1-rc.1"}' > "$fixture_root/head-semver-prerelease-increase.json"
printf '%s\n' '{"version":"0.16.1+build.5"}' > "$fixture_root/head-semver-build-increase.json"

run_case 'SemVer: empty pre-release (0.43.1-) is malformed' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-semver-empty-prerelease.json" 'not a strict increase'
run_case 'SemVer: leading zero in major (01.2.3) is malformed' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-semver-leading-zero-major.json" 'not a strict increase'
run_case 'SemVer: leading zero in minor (1.02.3) is malformed' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-semver-leading-zero-minor.json" 'not a strict increase'
run_case 'SemVer: leading zero in pre-release (1.2.3-01) is malformed' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-semver-leading-zero-prerelease.json" 'not a strict increase'
run_case 'SemVer: trailing dash (1.2.3-) is malformed' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-semver-trailing-dash.json" 'not a strict increase'
run_case 'SemVer: trailing plus (1.2.3+) is malformed' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/head-semver-trailing-plus.json" 'not a strict increase'
run_case 'SemVer: valid pre-release (1.2.3-rc.1) with a real increase passes' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/head-semver-prerelease-increase.json" 'plugin.json version bumped'
run_case 'SemVer: valid build metadata (1.2.3+build.5) with a real increase passes' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/head-semver-build-increase.json" 'plugin.json version bumped'

# --- guarded-surface rows added at 0.51.0 (zheref/hatsu#74, and the two runtime
# scripts Phinks proved unguarded on the #105/#106 delivery) ------------------
printf '%s\n' 'docs/SURFACES.md' > "$fixture_root/changed-surfaces-doc.txt"
printf '%s\n' 'docs/using/mirrors.md' > "$fixture_root/changed-using-mirrors.txt"
printf '%s\n' 'docs/using/README.md' > "$fixture_root/changed-using-hub.txt"
printf '%s\n' 'docs/PUBLIC-REDACTION.md' > "$fixture_root/changed-redaction-doc.txt"
printf '%s\n' 'scripts/hatsu_root.sh' > "$fixture_root/changed-root-resolver.txt"
printf '%s\n' 'scripts/surface_mirror_check.sh' > "$fixture_root/changed-mirror-check.txt"
printf '%s\n' 'scripts/permissions_pack.sh' > "$fixture_root/changed-permissions-pack.txt"
printf '%s\n' 'scripts/dist_tag.sh' > "$fixture_root/changed-dist-tag.txt"
printf '%s\n' 'scripts/plugin_bump_check_fixture.sh' > "$fixture_root/changed-this-fixture.txt"
run_case 'SURFACES.md unchanged version' 1 "$fixture_root/changed-surfaces-doc.txt" "$fixture_root/head-unchanged.json" 'docs/SURFACES.md'
run_case 'PUBLIC-REDACTION.md unchanged version' 1 "$fixture_root/changed-redaction-doc.txt" "$fixture_root/head-unchanged.json" 'docs/PUBLIC-REDACTION.md'
run_case 'root resolver unchanged version' 1 "$fixture_root/changed-root-resolver.txt" "$fixture_root/head-unchanged.json" 'scripts/hatsu_root.sh'
run_case 'mirror check script unchanged version' 1 "$fixture_root/changed-mirror-check.txt" "$fixture_root/head-unchanged.json" 'scripts/surface_mirror_check.sh'
run_case 'permissions pack unchanged version' 1 "$fixture_root/changed-permissions-pack.txt" "$fixture_root/head-unchanged.json" 'scripts/permissions_pack.sh'
run_case 'dist tag script unchanged version' 1 "$fixture_root/changed-dist-tag.txt" "$fixture_root/head-unchanged.json" 'scripts/dist_tag.sh'
run_case 'SURFACES.md bumped version' 0 "$fixture_root/changed-surfaces-doc.txt" "$fixture_root/head-bumped.json" 'plugin.json version bumped'
run_case 'docs/using/mirrors.md unchanged version' 1 "$fixture_root/changed-using-mirrors.txt" "$fixture_root/head-unchanged.json" 'docs/using/mirrors.md'
run_case 'docs/using/mirrors.md bumped version' 0 "$fixture_root/changed-using-mirrors.txt" "$fixture_root/head-bumped.json" 'plugin.json version bumped'
run_case 'docs/using/README.md unchanged version' 1 "$fixture_root/changed-using-hub.txt" "$fixture_root/head-unchanged.json" 'docs/using/README.md'
run_case 'a fixture script alone does not apply' 0 "$fixture_root/changed-this-fixture.txt" "$fixture_root/head-unchanged.json" 'no plugin-shipped surface changed'

# --- the stamp lag (zheref/hatsu#99): a real bump beside mirrors still stamped
# with the base version fails BY NAME; mirrors at the new stamp pass; a head
# root with no surfaces/ has nothing to lag. The head manifest must sit in a
# tree (<root>/.claude-plugin/plugin.json) for the guard to find surfaces/. --
make_tree() {
  local tree="$1" version="$2" stamp="$3"
  mkdir -p "$tree/.claude-plugin" "$tree/surfaces/codex/ten" "$tree/surfaces/cursor/ten" "$tree/surfaces/antigravity/skills/ten"
  printf '%s\n' "{\"version\":\"$version\"}" > "$tree/.claude-plugin/plugin.json"
  local s
  for s in codex cursor antigravity; do
    local dir="$tree/surfaces/$s/ten"; [ "$s" = antigravity ] && dir="$tree/surfaces/$s/skills/ten"
    printf '%s\n' '---' 'name: ten' '---' "<!-- GENERATED by nen surface mirror (surface: $s, stamp: $stamp) -- do not edit; edit the source and regenerate -->" '# ten' > "$dir/SKILL.md"
  done
}
make_tree "$fixture_root/tree-lagging" '0.16.1' '0.16.0'
make_tree "$fixture_root/tree-restamped" '0.16.1' '0.16.1'
mkdir -p "$fixture_root/tree-nomirrors/.claude-plugin"; printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/tree-nomirrors/.claude-plugin/plugin.json"
run_case 'bump with lagging mirror stamps fails by name' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-lagging/.claude-plugin/plugin.json" 'surfaces/antigravity: stamp(s) 0.16.0 (needs 0.16.1 on every generated file)'
run_case 'bump with lagging mirror stamps names the one owner of the regeneration' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-lagging/.claude-plugin/plugin.json" 'scripts/surface_mirror_regenerate.sh is the one owner of the command'
# a detached head manifest (every pre-existing 'bumped' case above) names no head tree: the stamp
# check is skipped and says so, never scanning whatever surfaces/ sits beside the file's parent
run_case 'a detached head manifest skips the stamp check and says so' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/head-bumped.json" 'stamp check skipped (the head manifest is not at <root>/.claude-plugin/plugin.json'
# a PARTIAL lag: one current .md beside a lagging one, and a lagging non-.md generated file
make_tree "$fixture_root/tree-partial" '0.16.1' '0.16.1'
mkdir -p "$fixture_root/tree-partial/surfaces/cursor/aka"
printf '%s\n' '---' 'name: aka' '---' '<!-- GENERATED by nen surface mirror (surface: cursor, stamp: 0.16.0) -- do not edit -->' > "$fixture_root/tree-partial/surfaces/cursor/aka/SKILL.md"
printf '%s\n' '{"description": "GENERATED by nen surface mirror (surface: codex, stamp: 0.16.0) -- do not edit"}' > "$fixture_root/tree-partial/surfaces/codex/hooks.json"
run_case 'a surface whose first file is current but another lags is lagging' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-partial/.claude-plugin/plugin.json" 'surfaces/cursor: stamp(s) 0.16.0,0.16.1 (needs 0.16.1 on every generated file)'
run_case 'a lagging non-.md generated file (hooks.json) is read too' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-partial/.claude-plugin/plugin.json" 'surfaces/codex: stamp(s) 0.16.0,0.16.1'
run_case 'bump with restamped mirrors passes' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-restamped/.claude-plugin/plugin.json" 'surfaces/ stamps read 0.16.1: antigravity, codex, cursor'
run_case 'bump with no mirrors present passes' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-nomirrors/.claude-plugin/plugin.json" 'no surfaces/ mirrors under the head tree to scan'

# #166: a declared spec change owes a changed fragment that survives at head.
# A pre-existing fragment, an unrelated fragment path, and a body claim alone
# cannot satisfy it. The integration PR's direct CHANGELOG section is explicit.
mkdir -p "$fixture_root/tree-fragment/.claude-plugin" "$fixture_root/tree-fragment/changelog.d"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/tree-fragment/.claude-plugin/plugin.json"
printf '%s\n' '- Existing entry' > "$fixture_root/tree-fragment/changelog.d/existing.md"
printf '%s\n' 'nen/contract.json' > "$fixture_root/changed-spec.txt"
run_case 'spec change without fragment fails' 1 "$fixture_root/changed-spec.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'no changed changelog.d/<name>.md fragment at head'
printf '%s\n' 'nen/contract.json' 'changelog.d/missing.md' > "$fixture_root/changed-missing-fragment.txt"
run_case 'a changed but absent fragment fails' 1 "$fixture_root/changed-missing-fragment.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'no changed changelog.d/<name>.md fragment at head'
printf '%s\n' 'nen/contract.json' 'changelog.d/existing.md' > "$fixture_root/changed-present-fragment.txt"
run_case 'a changed fragment present at head passes' 0 "$fixture_root/changed-present-fragment.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'changelog fragment: changed changelog.d/ fragment present at PR head'
printf '%s\n' 'nen/contract.json' 'CHANGELOG.md' > "$fixture_root/changed-direct-section.txt"
printf '%s\n' 'no CHANGELOG entry: this pull request writes its own CHANGELOG.md section (contracts/pr-composition.json, changelogFragment.directSection)' > "$fixture_root/body-direct-section.md"
printf '%s\n' '### v0.16.1' '- **Guard** tested direct section' > "$fixture_root/tree-fragment/CHANGELOG.md"
run_case 'declared direct CHANGELOG section passes' 0 "$fixture_root/changed-direct-section.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'changelog fragment: direct CHANGELOG.md section declared by this PR' "$fixture_root/body-direct-section.md"
run_case 'a direct section body line without a CHANGELOG diff fails' 1 "$fixture_root/changed-spec.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'no changed changelog.d/<name>.md fragment at head' "$fixture_root/body-direct-section.md"
printf '%s\n' '<!--' 'no CHANGELOG entry: this pull request writes its own CHANGELOG.md section (contracts/pr-composition.json, changelogFragment.directSection)' '-->' > "$fixture_root/body-commented-direct.md"
run_case 'a direct section hidden in an HTML comment fails' 1 "$fixture_root/changed-direct-section.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'no changed changelog.d/<name>.md fragment at head' "$fixture_root/body-commented-direct.md"
printf '%s\n' '```text' 'no CHANGELOG entry: this pull request writes its own CHANGELOG.md section (contracts/pr-composition.json, changelogFragment.directSection)' '```' > "$fixture_root/body-fenced-direct.md"
run_case 'a direct section hidden in a code fence fails' 1 "$fixture_root/changed-direct-section.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'no changed changelog.d/<name>.md fragment at head' "$fixture_root/body-fenced-direct.md"
printf '%s\n' '```text' '```text' 'no CHANGELOG entry: this pull request writes its own CHANGELOG.md section (contracts/pr-composition.json, changelogFragment.directSection)' '```' > "$fixture_root/body-fence-with-language.md"
run_case 'a fence marker with trailing language does not close an open fence' 1 "$fixture_root/changed-direct-section.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'no changed changelog.d/<name>.md fragment at head' "$fixture_root/body-fence-with-language.md"
printf '%s\n' '```text' '<!-- -->```' 'no CHANGELOG entry: this pull request writes its own CHANGELOG.md section (contracts/pr-composition.json, changelogFragment.directSection)' '```' > "$fixture_root/body-fence-comment-literal.md"
run_case 'HTML-looking code cannot close a fence' 1 "$fixture_root/changed-direct-section.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'no changed changelog.d/<name>.md fragment at head' "$fixture_root/body-fence-comment-literal.md"
printf '%s\n' '    no CHANGELOG entry: this pull request writes its own CHANGELOG.md section (contracts/pr-composition.json, changelogFragment.directSection)' > "$fixture_root/body-indented-direct.md"
run_case 'an indented code declaration does not count' 1 "$fixture_root/changed-direct-section.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'no changed changelog.d/<name>.md fragment at head' "$fixture_root/body-indented-direct.md"
ln -s existing.md "$fixture_root/tree-fragment/changelog.d/linked.md"
printf '%s\n' 'nen/contract.json' 'changelog.d/linked.md' > "$fixture_root/changed-linked-fragment.txt"
run_case 'a changed symlink cannot count as a fragment' 1 "$fixture_root/changed-linked-fragment.txt" "$fixture_root/tree-fragment/.claude-plugin/plugin.json" 'no changed changelog.d/<name>.md fragment at head'
mkdir -p "$fixture_root/tree-symlink-parent/.claude-plugin" "$fixture_root/external-fragments"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/tree-symlink-parent/.claude-plugin/plugin.json"
printf '%s\n' '- Outside entry' > "$fixture_root/external-fragments/outside.md"
ln -s "$fixture_root/external-fragments" "$fixture_root/tree-symlink-parent/changelog.d"
printf '%s\n' 'nen/contract.json' 'changelog.d/outside.md' > "$fixture_root/changed-outside-fragment.txt"
run_case 'a fragment through a symlinked directory outside the PR head fails' 1 "$fixture_root/changed-outside-fragment.txt" "$fixture_root/tree-symlink-parent/.claude-plugin/plugin.json" 'no changed changelog.d/<name>.md fragment at head'
make_tree "$fixture_root/tree-unread" '0.16.1' '0.16.1'; printf '%s\n' '# ten' 'no marker here' > "$fixture_root/tree-unread/surfaces/cursor/ten/SKILL.md"
run_case 'a surface with no readable marker is reported unread, never read' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-unread/.claude-plugin/plugin.json" 'stamp unread (no GENERATED marker matched): cursor'
run_case 'a surface with no readable marker is not counted among the read ones' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-unread/.claude-plugin/plugin.json" 'surfaces/ stamps read 0.16.1: antigravity, codex;'

# --- the PR head is data (Feitan): a marker carrying CR and a workflow-command string is printed as
# <malformed>, never raw; a symlinked surface directory is never followed ----------------------
make_tree "$fixture_root/tree-hostile" '0.16.1' '0.16.0'
printf '%s\n' '---' 'name: ten' '---' '<!-- GENERATED by nen surface mirror (surface: codex, stamp: 0.0.1'$'\r''::notice title=x::forged) -- do not edit -->' > "$fixture_root/tree-hostile/surfaces/codex/ten/SKILL.md"
hostile_out="$(bash "$guard" "$fixture_root/changed-discovery.txt" "$fixture_root/base.json" "$fixture_root/tree-hostile/.claude-plugin/plugin.json" "$fixture_root/body.md" 2>&1 || true)"
grep -Fq -- 'surfaces/codex: stamp(s) <malformed> (needs 0.16.1' <<<"$hostile_out" || { printf 'hostile stamp: expected <malformed>, got:\n%s\n' "$hostile_out" >&2; exit 1; }
if printf '%s' "$hostile_out" | LC_ALL=C grep -q $'\r'; then echo 'hostile stamp: a CR reached the output' >&2; exit 1; fi
printf '%s\n' 'hostile stamp printed as <malformed>, no CR: exit 1'
# a PR-controlled surface directory whose name carries a control character or a space is never
# printed (the name check is an anchored character class, not a glob)
mkdir -p "$fixture_root/tree-hostile/surfaces/ab"$'\r'"/ten" "$fixture_root/tree-hostile/surfaces/a b/ten"
printf '%s\n' '<!-- GENERATED by nen surface mirror (surface: codex, stamp: 0.0.2) -- x -->' > "$fixture_root/tree-hostile/surfaces/ab"$'\r'"/ten/SKILL.md"
printf '%s\n' '<!-- GENERATED by nen surface mirror (surface: codex, stamp: 0.0.3) -- x -->' > "$fixture_root/tree-hostile/surfaces/a b/ten/SKILL.md"
hostile_out="$(bash "$guard" "$fixture_root/changed-discovery.txt" "$fixture_root/base.json" "$fixture_root/tree-hostile/.claude-plugin/plugin.json" "$fixture_root/body.md" 2>&1 || true)"
if grep -q -- '0\.0\.2\|0\.0\.3\|a b' <<<"$hostile_out"; then echo 'hostile surface name: a control-character or space-bearing directory name was printed' >&2; exit 1; fi
printf '%s\n' 'hostile surface names (CR, space) are never printed: ok'
outside="$fixture_root/outside-the-tree/ten"; mkdir -p "$outside"; printf '%s\n' '<!-- GENERATED by nen surface mirror (surface: cursor, stamp: 0.0.9) -- x -->' > "$outside/SKILL.md"
make_tree "$fixture_root/tree-symlink" '0.16.1' '0.16.1'; rm -rf "$fixture_root/tree-symlink/surfaces/cursor"; ln -s "$fixture_root/outside-the-tree" "$fixture_root/tree-symlink/surfaces/cursor"
run_case 'a symlinked surface directory is not followed' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-symlink/.claude-plugin/plugin.json" 'surfaces/ stamps read 0.16.1: antigravity, codex'

# --- the Codex overlay (.codex-plugin/plugin.json), 2026-09-29: Codex keys its
# own plugin-cache slot on that manifest's name and version, exactly as Claude
# Code keys its cache on .claude-plugin/plugin.json's version -- equal passes;
# lagging fails naming both; an absent overlay is not an error. No surfaces/ in
# any of these trees, so only the overlay check is exercised. -----------------
mkdir -p "$fixture_root/tree-codex-equal/.claude-plugin" "$fixture_root/tree-codex-equal/.codex-plugin"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/tree-codex-equal/.claude-plugin/plugin.json"
printf '%s\n' '{"name":"hatsu","version":"0.16.1"}' > "$fixture_root/tree-codex-equal/.codex-plugin/plugin.json"
mkdir -p "$fixture_root/tree-codex-lagging/.claude-plugin" "$fixture_root/tree-codex-lagging/.codex-plugin"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/tree-codex-lagging/.claude-plugin/plugin.json"
printf '%s\n' '{"name":"hatsu","version":"0.16.0"}' > "$fixture_root/tree-codex-lagging/.codex-plugin/plugin.json"
mkdir -p "$fixture_root/tree-codex-absent/.claude-plugin"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/tree-codex-absent/.claude-plugin/plugin.json"

run_case 'Codex overlay matching version passes' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-codex-equal/.claude-plugin/plugin.json" 'plugin.json version bumped'
run_case 'Codex overlay lagging version fails naming both' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-codex-lagging/.claude-plugin/plugin.json" '.codex-plugin/plugin.json version is 0.16.0, .claude-plugin/plugin.json version is 0.16.1'
run_case 'no Codex overlay at all is not an error' 0 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-codex-absent/.claude-plugin/plugin.json" 'plugin.json version bumped'

# --- a present-but-not-a-regular-file overlay is a FAILURE, never "absent"
# (Nobunaga; Phinks's note on the same finding): a directory sitting where
# the manifest should be, and a dangling/broken symlink, both fail naming the
# problem rather than being read as "no overlay" and passing silently. A
# misnamed overlay (name != hatsu) is the same existing codex_overlay_check
# branch as the lagging-version case above, exercised here for the first
# time. --------------------------------------------------------------------
mkdir -p "$fixture_root/tree-codex-not-file/.claude-plugin" "$fixture_root/tree-codex-not-file/.codex-plugin/plugin.json"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/tree-codex-not-file/.claude-plugin/plugin.json"
mkdir -p "$fixture_root/tree-codex-dangling/.claude-plugin" "$fixture_root/tree-codex-dangling/.codex-plugin"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/tree-codex-dangling/.claude-plugin/plugin.json"
ln -s "$fixture_root/tree-codex-dangling/.codex-plugin/nonexistent-target.json" "$fixture_root/tree-codex-dangling/.codex-plugin/plugin.json"
mkdir -p "$fixture_root/tree-codex-misnamed/.claude-plugin" "$fixture_root/tree-codex-misnamed/.codex-plugin"
printf '%s\n' '{"version":"0.16.1"}' > "$fixture_root/tree-codex-misnamed/.claude-plugin/plugin.json"
printf '%s\n' '{"name":"not-hatsu","version":"0.16.1"}' > "$fixture_root/tree-codex-misnamed/.codex-plugin/plugin.json"

run_case 'Codex overlay that is a directory fails, not absent' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-codex-not-file/.claude-plugin/plugin.json" 'exists but is not a regular file'
run_case 'Codex overlay that is a dangling symlink fails, not absent' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-codex-dangling/.claude-plugin/plugin.json" 'exists but is not a regular file'
run_case 'Codex overlay with the wrong name fails naming it' 1 "$fixture_root/changed-discovery.txt" "$fixture_root/tree-codex-misnamed/.claude-plugin/plugin.json" 'name is not-hatsu, must be hatsu'

# --- the opt-out is never honoured over a shipped path (zheref/hatsu#171) --------
# A `no plugin bump:` line used to skip the version check for ANY diff; HA-PR-#233
# carried one over the shipped docs/WORKFLOW.md and nen/contract.json and passed.
# Now it is accepted only where no shipped path changed (where the guard does not
# apply anyway) and refused by name, listing the shipped paths, everywhere else.
printf '%s\n' '## Completion checklist' '' '- no plugin bump: wording only' > "$fixture_root/body-optout.md"
printf '%s\n' 'docs/ab/plugin-bump-guard.md' 'nen/contract.json' > "$fixture_root/changed-mixed.txt"
run_case 'opt-out over a shipped doc is refused' 1 "$fixture_root/changed-workflow.txt" "$fixture_root/head-unchanged.json" 'plugin-bump opt-out refused' "$fixture_root/body-optout.md"
run_case 'the refused opt-out names the shipped path' 1 "$fixture_root/changed-workflow.txt" "$fixture_root/head-unchanged.json" '  - docs/WORKFLOW.md' "$fixture_root/body-optout.md"
run_case 'opt-out over unshipped files only is accepted' 0 "$fixture_root/changed-unrelated.txt" "$fixture_root/head-unchanged.json" 'the `no plugin bump:` line is accepted' "$fixture_root/body-optout.md"
run_case 'opt-out over a mixed diff is refused, naming the shipped path' 1 "$fixture_root/changed-mixed.txt" "$fixture_root/head-unchanged.json" '  - nen/contract.json' "$fixture_root/body-optout.md"
mixed_out="$(bash "$guard" "$fixture_root/changed-mixed.txt" "$fixture_root/base.json" "$fixture_root/head-unchanged.json" "$fixture_root/body-optout.md" 2>&1 || true)"
if grep -Fq -- '  - docs/ab/plugin-bump-guard.md' <<<"$mixed_out"; then echo 'mixed opt-out: an unshipped path was listed as shipped' >&2; exit 1; fi
printf '%s\n' 'the refused opt-out lists only the shipped paths: ok'
run_case 'opt-out beside a real bump passes on the bump' 0 "$fixture_root/changed-workflow.txt" "$fixture_root/head-bumped.json" 'plugin.json version bumped' "$fixture_root/body-optout.md"
run_case 'beside a bump the opt-out line is named as ignored' 0 "$fixture_root/changed-workflow.txt" "$fixture_root/head-bumped.json" 'the `no plugin bump:` line was ignored (inert beside a bump' "$fixture_root/body-optout.md"
run_case 'the refusal no longer offers an opt-out for a shipped path' 1 "$fixture_root/changed-workflow.txt" "$fixture_root/head-unchanged.json" 'There is no opt-out for a shipped path'
