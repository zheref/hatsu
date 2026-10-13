#!/usr/bin/env bash
# Focused, declared verification for scripts/pr_composition_check.sh (zheref/hatsu#171).
# Hermetic and offline: every case builds a throwaway Hatsu-shaped tree under a temp dir, runs the
# checked-in guard on it, and asserts the exit code and one line of its output; the last case runs the
# guard on this repository itself. Requires bash and python3 (the guard's own dependency).
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
  write_decl "$t" '"nen/", "schemas/"' '"docs/"' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
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
write_decl "$t" '"nen/"' '"docs/"' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
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
write_decl "$t" '"nen/", "schemas/"' '"docs/"' 'no CHANGELOG entry: writes its own section' '"The flow", "Economics"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
run_case 'an optional heading the template no longer has fails' 1 "$t" "optional heading 'Economics' is not a heading of templates/pr-body.md"

# --- the declaration's own shape ------------------------------------------------------------------
t="$(make_tree both-empty)"
write_decl "$t" '' '' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
run_case 'a gate row with both sets empty fails' 1 "$t" 'gateDerive.owner/repo has both sets empty'

t="$(make_tree comma-entry)"
write_decl "$t" '"nen/,schemas/"' '"docs/"' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
run_case 'an entry carrying a comma fails' 1 "$t" "entry 'nen/,schemas/' is empty or carries whitespace or a comma"

t="$(make_tree bad-optout)"
write_decl "$t" '"nen/", "schemas/"' '"docs/"' 'no CHANGELOG entry:' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/shibari/SKILL.md"'
run_case 'an opt-out with no reason fails' 1 "$t" 'directSection.optOut is not one `no CHANGELOG entry: <reason>` line'

t="$(make_tree reader-missing)"
write_decl "$t" '"nen/", "schemas/"' '"docs/"' 'no CHANGELOG entry: writes its own section' '"The flow"' '"docs/WORKFLOW.md", "claude/skills/tensho/SKILL.md"'
run_case 'a reader that does not exist fails' 1 "$t" 'claude/skills/tensho/SKILL.md: listed in readers but missing'

# --- wiring refusals at exit 2 ----------------------------------------------------------------------
t="$(make_tree no-decl)"; rm "$t/contracts/pr-composition.json"
run_case 'a missing declaration is a wiring refusal' 2 "$t" 'contracts/pr-composition.json is missing'
t="$(make_tree bad-json)"; printf '%s\n' '{ not json' > "$t/contracts/pr-composition.json"
run_case 'a declaration that is not JSON is a wiring refusal' 2 "$t" 'is not readable JSON'
t="$(make_tree not-hatsu)"; rm "$t/.claude-plugin/plugin.json"
run_case 'a root that is not a Hatsu checkout is a wiring refusal' 2 "$t" 'is not a Hatsu checkout'
t="$(make_tree unknown-arg)"
run_case 'an unknown argument is a wiring refusal' 2 "$t" "unknown argument '--nope'" --nope

# --- and the repository itself ----------------------------------------------------------------------
run_case 'this repository: declaration, requirements, template and prose agree' 0 "$repo_root" 'pr-composition ok'

printf 'pr-composition-guard: %s cases passed\n' "$n"
