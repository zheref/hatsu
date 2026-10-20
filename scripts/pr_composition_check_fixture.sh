#!/usr/bin/env bash
# Focused, declared verification for scripts/pr_composition_check.sh (zheref/hatsu#171).
# Every guard case builds a throwaway Hatsu-shaped tree under a temp dir, runs the checked-in guard on
# it, and asserts the exit code and one line of its output; the zheref/nen cases read this
# repository's own declaration and need the host's nen; the last case runs the guard on this
# repository itself. Requires bash and python3 (the guard's own dependency), and jq and nen
# (NEN=<path> or on PATH, at nen/contract.json's dependency.minimum or later) for the zheref/nen row
# cases, which ask nen gate derive itself; a missing one is a wiring refusal at exit 2.
# Invoked only through `nen shu test --lane pr-composition-guard --repo <hatsu>`.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$repo_root/scripts/pr_composition_check.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-pr-composition.XXXXXX")"
trap 'rm -rf "$work"' EXIT
n=0

# write_decl TREE POLICY PROCESS OPTOUT OPTIONAL READERS -- each list argument is a JSON array body.
write_decl() {
  cat > "$1/contracts/pr-composition.json" <<JSON
{
  "contract": "hatsu.pr-composition/v1",
  "readers": [$6],
  "bodyRequirements": {"file": "contracts/pr-body.requirements.json", "template": "templates/pr-body.md", "optionalHeadings": [$5]},
  "gateDerive": {"\$comment": "x", "owner/repo": {"policyPaths": [$2], "processPaths": [$3]}},
  "changelogFragment": {"specPaths": ["nen/", "schemas/"], "fragmentDir": "changelog.d", "headChangelog": "CHANGELOG.md",
    "directSection": {"when": "the diff changes CHANGELOG.md", "optOut": "$4"}}
}
JSON
}

# make_tree NAME -- a consistent tree; cases then break exactly one thing.
make_tree() {
  local t="$work/$1"
  mkdir -p "$t/.claude-plugin" "$t/contracts" "$t/templates" "$t/docs" "$t/claude/skills/shibari"
  printf '%s\n' '{"version":"0.0.1"}' > "$t/.claude-plugin/plugin.json"
  write_decl "$t" '"nen/", "schemas/"' '"docs/", "contracts/"' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
  cat > "$t/contracts/pr-body.requirements.json" <<'JSON'
[
  {"name": "Why", "pattern": "^## Why\\s*$"},
  {"name": "How to verify", "pattern": "^## How to verify\\s*$"},
  {"name": "Agent attribution", "pattern": "^## Agent attribution\\s*$(?![\\s\\S]*^#{1,2}[ \\t])"}
]
JSON
  printf '%s\n' '<!--' '## Inside a comment, not a heading' '-->' '## Why' '' '## How to verify' '' '## The flow' '' \
    '```' '## Inside a fence, not a heading' '```' '' '## Agent attribution' > "$t/templates/pr-body.md"
  printf '%s\n' '# Workflow' '' '## Gate derivation' '' \
    'The sets are declared in [`contracts/pr-composition.json`](../contracts/pr-composition.json); it keeps `nen/` and `schemas/`.' '' \
    'Rulings: [`ROSTER.md`](ROSTER.md); a `nen/decisions.json` row; the `owner/repo` slug is no path.' '' \
    '```bash' 'nen gate derive --policy-paths <policyPaths> --process-paths <processPaths> --files <changed>' '```' '' \
    'Only `--policy-paths ""` with an empty process set too is refused.' '' '## Next section' '' 'Names `handbooks/` outside the section.' > "$t/docs/WORKFLOW.md"
  printf '%s\n' 'Reads contracts/pr-composition.json: `--spec-paths <specPaths>`.' > "$t/claude/skills/shibari/SKILL.md"
  printf '%s\n' "$t"
}

run_case() {
  local name="$1" expected="$2" tree="$3" text="$4" out status
  shift 4
  if out="$(bash "$guard" --root "$tree" "$@" 2>&1)"; then status=0; else status=$?; fi
  if [ "$status" -ne "$expected" ]; then
    printf '%s: expected exit %s, got %s\n%s\n' "$name" "$expected" "$status" "$out" >&2; exit 1
  fi
  if ! grep -Fq -- "$text" <<<"$out"; then
    printf '%s: missing expected output %s\n%s\n' "$name" "$text" "$out" >&2; exit 1
  fi
  n=$((n + 1))
  printf '%s: exit %s\n' "$name" "$status"
}

t="$(make_tree ok)"
run_case 'a consistent tree passes' 0 "$t" 'pr-composition ok: 1 gate row(s), 2 reader(s)'

# --- the WORKFLOW section and the declared sets disagree ------------------------------------------
t="$(make_tree workflow-copy)"
printf '%s\n' '## Gate derivation' '' 'cites contracts/pr-composition.json' 'nen gate derive --policy-paths "nen/,schemas/" --process-paths "docs/"' > "$t/docs/WORKFLOW.md"
run_case 'a literal set copied into WORKFLOW.md fails' 1 "$t" 'docs/WORKFLOW.md:4: --policy-paths carries a literal path list (nen/,schemas/)'
run_case 'both copied flags are named' 1 "$t" 'docs/WORKFLOW.md:4: --process-paths carries a literal path list (docs/)'

t="$(make_tree workflow-extra)"
sed -i.bak 's/keeps `nen\/` and `schemas\/`/keeps `nen\/`, `schemas\/` and `handbooks\/`/' "$t/docs/WORKFLOW.md"
run_case 'a prefix the section names but no set declares fails' 1 "$t" 'names `handbooks/`, which no declared gate set carries'

t="$(make_tree decl-dropped)"
write_decl "$t" '"nen/"' '"docs/", "contracts/"' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
run_case 'a set member dropped from the declaration but still named in the section fails' 1 "$t" 'names `schemas/`, which no declared gate set carries'

t="$(make_tree workflow-uncited)"
sed -i.bak 's/contracts\/pr-composition.json/the declaration/g' "$t/docs/WORKFLOW.md"
run_case 'a Gate derivation section that does not cite the declaration fails' 1 "$t" 'docs/WORKFLOW.md § Gate derivation: does not cite contracts/pr-composition.json'
run_case 'and the reader row says the same' 1 "$t" 'docs/WORKFLOW.md: listed in readers but does not cite'

t="$(make_tree workflow-missing-section)"
printf '%s\n' '# Workflow' 'contracts/pr-composition.json' > "$t/docs/WORKFLOW.md"
run_case 'a WORKFLOW.md with no Gate derivation section fails' 1 "$t" 'docs/WORKFLOW.md: no `## Gate derivation` section'

# --- no second copy anywhere in the canon prose; records are exempt -------------------------------
t="$(make_tree skill-copy)"
printf '%s\n' 'contracts/pr-composition.json' 'nen changelog fragment-required --spec-paths=nen/,schemas/ --files x' > "$t/claude/skills/shibari/SKILL.md"
run_case 'a --flag=literal copy in a skill fails' 1 "$t" 'claude/skills/shibari/SKILL.md:2: --spec-paths carries a literal path list (nen/,schemas/)'

t="$(make_tree wrapped-copy)"
printf '%s\n' 'contracts/pr-composition.json' '`nen changelog fragment-required --spec-paths' '"CONSTITUTION.md,nen/" --files x`' > "$t/claude/skills/shibari/SKILL.md"
run_case 'a copy wrapped across lines fails' 1 "$t" 'claude/skills/shibari/SKILL.md:2: --spec-paths carries a literal path list (CONSTITUTION.md,nen/)'

t="$(make_tree records)"
for f in docs/ab/shibari.md docs/history/old.md docs/Loop/run/decisions.md docs/ROSTER.md surfaces/codex/shibari/SKILL.md CHANGELOG.md; do
  mkdir -p "$t/$(dirname "$f")"; printf '%s\n' '$ nen gate derive --policy-paths "nen/,schemas/" --process-paths "docs/"' > "$t/$f"
done
run_case 'transcripts, rulings, history and generated mirrors are exempt' 0 "$t" 'no literal path-set copy'

t="$(make_tree placeholders)"
printf '%s\n' 'contracts/pr-composition.json' '--spec-paths <specPaths> --policy-paths "" --process-paths "..." --spec-paths (comma-joined)' '`--policy-paths`/`--spec-paths` prefix' > "$t/claude/skills/shibari/SKILL.md"
run_case 'placeholders, an empty set and prose naming the flags pass' 0 "$t" 'pr-composition ok'

# --- the requirements array against the template --------------------------------------------------
t="$(make_tree template-grew)"
printf '%s\n' '## Evidence' '' >> "$t/templates/pr-body.md"
run_case 'a template heading the requirements lack fails' 1 "$t" "are not templates/pr-body.md's required headings"

t="$(make_tree pattern-misses)"
sed -i.bak 's/\^## Why/^## Whyy/' "$t/contracts/pr-body.requirements.json"
run_case 'a pattern that misses its own heading fails' 1 "$t" "'Why' does not match a body that carries \`## Why\`"

t="$(make_tree pattern-vacuous)"
sed -i.bak 's/"\^## Why\\\\s\*\$"/"^## "/' "$t/contracts/pr-body.requirements.json"
run_case 'a pattern that matches without its heading fails' 1 "$t" "'Why' matches a body without \`## Why\`, so it checks nothing"

t="$(make_tree pattern-broken)"
sed -i.bak 's/\^## Why\\\\s\*\$/^## Why(/' "$t/contracts/pr-body.requirements.json"
run_case 'an unparseable pattern fails by name' 1 "$t" "'Why' has an unparseable pattern"

t="$(make_tree optional-stale)"
write_decl "$t" '"nen/", "schemas/"' '"docs/", "contracts/"' 'no CHANGELOG entry: writes its own section' '"The flow", "Economics"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
run_case 'an optional heading the template no longer has fails' 1 "$t" "optional heading 'Economics' is not a heading of templates/pr-body.md"

# --- the declaration's own shape ------------------------------------------------------------------
t="$(make_tree both-empty)"
write_decl "$t" '' '' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
run_case 'a gate row with both sets empty fails' 1 "$t" 'gateDerive.owner/repo has both sets empty'

t="$(make_tree comma-entry)"
write_decl "$t" '"nen/,schemas/"' '"docs/", "contracts/"' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
run_case 'an entry carrying a comma fails' 1 "$t" "entry 'nen/,schemas/' is empty or carries whitespace or a comma"

t="$(make_tree bad-optout)"
write_decl "$t" '"nen/", "schemas/"' '"docs/", "contracts/"' 'no CHANGELOG entry:' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
run_case 'an opt-out with no reason fails' 1 "$t" 'directSection.optOut is not one `no CHANGELOG entry: <reason>` line'

t="$(make_tree reader-missing)"
write_decl "$t" '"nen/", "schemas/"' '"docs/", "contracts/"' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/tensho/SKILL.md"'
run_case 'a reader that does not exist fails' 1 "$t" 'claude/skills/tensho/SKILL.md: listed in readers but missing'

# --- hanten round 1 (zheref/hatsu#171): Phinks QA-16, Feitan, Chrollo --------------------------------
t="$(make_tree multi-segment)"
sed -i.bak 's/keeps `nen\/` and `schemas\/`/keeps `nen\/`, `schemas\/` and `.github\/actions\/`/' "$t/docs/WORKFLOW.md"
run_case 'a multi-segment prefix no set declares fails' 1 "$t" 'names `.github/actions/`, which no declared gate set carries'

t="$(make_tree file-uncovered)"
sed -i.bak 's/a `nen\/decisions.json` row/a `README.md` row/' "$t/docs/WORKFLOW.md"
run_case 'a file name no declared set covers fails' 1 "$t" 'names `README.md`, which no declared gate set covers'

t="$(make_tree fenced-heading)"
printf '%s\n' '# Workflow' '' '## Gate derivation' '' 'cites contracts/pr-composition.json' '' '```' '## not a heading, inside a fence' '```' '' 'Still the section: names `handbooks/`.' '' '## Next' > "$t/docs/WORKFLOW.md"
run_case 'a ## line inside a fence does not end the section' 1 "$t" 'names `handbooks/`, which no declared gate set carries'

t="$(make_tree leading-slash)"
printf '%s\n' 'contracts/pr-composition.json' 'nen gate derive --policy-paths "/nen/,/schemas/" --files x' > "$t/claude/skills/shibari/SKILL.md"
run_case 'a literal copy with a leading slash fails' 1 "$t" 'claude/skills/shibari/SKILL.md:2: --policy-paths carries a literal path list (/nen/,/schemas/)'

t="$(make_tree undecodable)"
printf 'nen gate derive --policy-paths "nen/" \377\n' > "$t/claude/skills/shibari/notes.md"
run_case 'a scanned file that is not UTF-8 is a finding, never a skip' 1 "$t" 'claude/skills/shibari/notes.md: not UTF-8, so it could not be scanned for a copy'

t="$(make_tree template-optout)"
printf '%s\n' '<!-- (b) carries a `no CHANGELOG entry: <reason>` line -->' >> "$t/templates/pr-body.md"
run_case 'the opt-out phrase in the template, even in a comment, fails' 1 "$t" 'templates/pr-body.md:15: carries the fragment opt-out phrase'

t="$(make_tree reader-escape)"
mkdir -p "$work/outside"; printf '%s\n' 'contracts/pr-composition.json' > "$work/outside/x.md"
write_decl "$t" '"nen/", "schemas/"' '"docs/", "contracts/"' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "../outside/x.md"'
run_case 'a reader outside the root is refused' 1 "$t" "reader '../outside/x.md' escapes the root"

t="$(make_tree template-absolute)"
sed -i.bak 's#"template": "templates/pr-body.md"#"template": "/etc/hosts"#' "$t/contracts/pr-composition.json"
run_case 'an absolute template path is refused' 1 "$t" "bodyRequirements.template '/etc/hosts' escapes the root"

t="$(make_tree reader-link-out)"
ln -s "$work/outside/x.md" "$t/docs/linked.md"
write_decl "$t" '"nen/", "schemas/"' '"docs/", "contracts/"' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "docs/linked.md"'
run_case 'a reader that is a link out of the root is refused' 1 "$t" "reader 'docs/linked.md' escapes the root"

# --- wiring refusals at exit 2 ----------------------------------------------------------------------
t="$(make_tree no-decl)"; rm "$t/contracts/pr-composition.json"
run_case 'a missing declaration is a wiring refusal' 2 "$t" 'contracts/pr-composition.json is missing'
t="$(make_tree bad-json)"; printf '%s\n' '{ not json' > "$t/contracts/pr-composition.json"
run_case 'a declaration that is not JSON is a wiring refusal' 2 "$t" 'is not readable JSON'
t="$(make_tree not-hatsu)"; rm "$t/.claude-plugin/plugin.json"
run_case 'a root that is not a Hatsu checkout is a wiring refusal' 2 "$t" 'is not a Hatsu checkout'
t="$(make_tree unknown-arg)"
run_case 'an unknown argument is a wiring refusal' 2 "$t" "unknown argument '--nope'" --nope

# --- no guessed fallback row (zheref/hatsu#334) -----------------------------------------------------
t="$(make_tree wildcard-row)"
sed -i.bak 's#"owner/repo"#"*/*"#' "$t/contracts/pr-composition.json"
run_case 'a wildcard row standing for every canon repository is refused' 1 "$t" "gateDerive row '*/*' is not an owner/name key"

# --- a gate row key the verb never reads is refused (QA-16, zheref/hatsu#334) -----------------------
t="$(make_tree misspelled-key)"
sed -i.bak 's#"owner/repo": {"policyPaths"#"owner/repo": {"policyPath": ["src/"], "policyPaths"#' "$t/contracts/pr-composition.json"
run_case 'a gate row key the verb never reads (policyPath) fails by name' 1 "$t" 'policyPath'

# --- zheref/nen's row derives the recorded gates (zheref/hatsu#334) ---------------------------------
# The expected gate of each representative change is recorded here, its basis in the row's own
# $comment and the maintainer's ruling of 2026-10-20 (docs/ROSTER.md); nen gate derive decides each
# one from the declared sets, read off this repository's declaration, so the fixture re-implements no
# matcher. A missing jq or nen, or a nen below the declared minimum, is a wiring refusal (exit 2); a
# missing row is a red case (exit 1).
command -v jq >/dev/null 2>&1 || { echo "zheref/nen row cases: jq not found (install jq 1.6 or newer)" >&2; exit 2; }
nen_bin="${NEN:-nen}"
command -v "$nen_bin" >/dev/null 2>&1 || { echo "zheref/nen row cases: '$nen_bin' not found (set NEN=<path> or put nen on PATH)" >&2; exit 2; }
nen_min="$(jq -r '.dependency.minimum // empty' "$repo_root/nen/contract.json")"
nen_have="$("$nen_bin" --version 2>/dev/null | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n 1)"
if [ -z "$nen_min" ] || [ -z "$nen_have" ] || [ "$(printf '%s\n%s\n' "$nen_min" "$nen_have" | sort -t. -k1,1n -k2,2n | head -n 1)" != "$nen_min" ]; then
  echo "zheref/nen row cases: nen '${nen_have:-unknown}' is below nen/contract.json dependency.minimum '${nen_min:-unset}'" >&2; exit 2
fi
row='.gateDerive["zheref/nen"]'
jq -e "$row | type == \"object\"" "$repo_root/contracts/pr-composition.json" >/dev/null || { echo "contracts/pr-composition.json declares no gateDerive.zheref/nen row" >&2; exit 1; }
nen_policy="$(jq -r "$row.policyPaths | join(\",\")" "$repo_root/contracts/pr-composition.json")"
nen_process="$(jq -r "$row.processPaths | join(\",\")" "$repo_root/contracts/pr-composition.json")"

derive_case() {
  local name="$1" expected="$2" text="$3" files="$4" out status
  if out="$("$nen_bin" gate derive --repo "$repo_root" --policy-paths "$nen_policy" --process-paths "$nen_process" --files "$files" 2>&1)"; then status=0; else status=$?; fi
  if [ "$status" -ne 0 ] || [ "$(sed -n 1p <<<"$out")" != "$expected" ] || ! grep -Fq -- "$text" <<<"$out"; then
    printf '%s: expected %s (%s), got exit %s\n%s\n' "$name" "$expected" "$text" "$status" "$out" >&2; exit 1
  fi
  n=$((n + 1))
  printf '%s: %s\n' "$name" "$expected"
}

derive_case 'zheref/nen source derives G4' G4 'process surface (src/)' 'src/gate/derive.ts'
derive_case 'zheref/nen schema source derives G4' G4 'process surface (src/)' 'src/schema/contract.ts'
derive_case 'zheref/nen own contract derives G4 as policy' G4 'policy/spec (nen/)' 'nen/contract.json'
derive_case 'zheref/nen gates policy derives G4' G4 'policy/spec (nen/)' 'nen/gates.json'
derive_case 'zheref/nen verb spec derives G4' G4 'process surface (docs/)' 'docs/USAGE.md'
derive_case 'zheref/nen README derives G4' G4 'process surface (README.md)' 'README.md'
derive_case 'zheref/nen release workflow derives G4' G4 'process surface (.github/)' '.github/workflows/release-assets.yml'
derive_case 'zheref/nen bootstrap derives G4' G4 'process surface (bootstrap/)' 'bootstrap/nen.sh'
derive_case 'zheref/nen dependency manifest derives G4' G4 'process surface (package.json)' 'package.json'
derive_case 'zheref/nen LICENSE and .gitignore alone derive G2' G2 'touches neither path set' 'LICENSE,.gitignore'
derive_case 'zheref/nen .gitattributes alone derives G4' G4 'process surface (.gitattributes)' '.gitattributes'
derive_case 'zheref/nen changelog fragment alone derives G4' G4 'process surface (changelog.d/)' 'changelog.d/409-registry-line-explicit-prune.md'
derive_case 'zheref/nen dependabot config derives G4' G4 'process surface (.github/)' '.github/dependabot.yml'
derive_case 'zheref/nen bunfig.toml derives G4' G4 'process surface (bunfig.toml)' 'bunfig.toml'
derive_case 'zheref/nen bootstrap renamed out of its set derives G4 on its old side' G4 'process surface (bootstrap/)' 'nen.sh,bootstrap/nen.sh'
derive_case 'zheref/nen housekeeping beside source derives G4' G4 'process surface (src/)' '.gitignore,src/gate/derive.ts'

# --- and the repository itself ----------------------------------------------------------------------
run_case 'this repository: declaration, requirements, template and prose agree' 0 "$repo_root" 'pr-composition ok'

printf 'pr-composition-guard: %s cases passed\n' "$n"
