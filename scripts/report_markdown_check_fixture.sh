#!/usr/bin/env bash
# Focused, declared verification for scripts/report_markdown_check.sh (zheref/hatsu#215).
# Hermetic and offline: every case copies the report templates, their samples and nen/workflow.json
# into a throwaway Hatsu-shaped tree, breaks exactly one thing, runs the checked-in guard on it and
# asserts the exit code and one line of its output; the last case runs the guard on this repository.
# Requires bash, python3 and nen (the guard's own dependencies; the render is nen's).
# Invoked only through `nen shu test --lane report-markdown-guard --repo <hatsu>`.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$repo_root/scripts/report_markdown_check.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-report-markdown-fixture.XXXXXX")"
trap 'rm -rf "$work"' EXIT
n=0

make_tree() {
  local t="$work/$1"
  mkdir -p "$t/.claude-plugin" "$t/nen" "$t/templates/report-examples"
  cp "$repo_root/.claude-plugin/plugin.json" "$t/.claude-plugin/plugin.json"
  cp "$repo_root/nen/workflow.json" "$t/nen/workflow.json"
  cp "$repo_root"/templates/spiritual-message.md "$repo_root"/templates/spiritual-message.html \
     "$repo_root"/templates/rikugan.md "$repo_root"/templates/rikugan.html \
     "$repo_root"/templates/graph.example.json "$t/templates/"
  cp "$repo_root"/templates/report-examples/* "$t/templates/report-examples/"
  printf '%s\n' "$t"
}

# edit FILE OLD NEW -- one literal replacement, refused when OLD is absent (a no-op case proves nothing).
edit() {
  python3 -I - "$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1:4]
s = open(path, encoding="utf-8").read()
if old not in s:
    sys.exit(f"fixture: '{old}' not found in {path}")
open(path, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

# edit_json FILE PYTHON -- mutate a sample data document; `d` is the parsed document.
edit_json() {
  python3 -I - "$1" "$2" <<'PY'
import json, sys
path, code = sys.argv[1:3]
d = json.load(open(path, encoding="utf-8"))
exec(code)
json.dump(d, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY
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
run_case 'a faithful tree passes' 0 "$t" 'report-markdown ok: 5 variant(s) render in both formats'

# --- block order and presence ------------------------------------------------------------------
t="$(make_tree order)"
edit "$t/templates/spiritual-message.md" '<!-- hatsu:block launch -->' '<!-- hatsu:block TMP -->'
edit "$t/templates/spiritual-message.md" '<!-- hatsu:block decisions -->' '<!-- hatsu:block launch -->'
edit "$t/templates/spiritual-message.md" '<!-- hatsu:block TMP -->' '<!-- hatsu:block decisions -->'
run_case 'a block out of the declared order fails' 1 "$t" "'decisions', 'launch', 'prBody'] are not the declared reports.sections.landing.blocks"

t="$(make_tree dropped)"
edit "$t/templates/spiritual-message.md" '{{#if sections.spend}}<!-- hatsu:block spend -->' '{{#if sections.spend}}'
run_case 'a declared block the Markdown never renders fails' 1 "$t" 'are not the declared reports.sections.landing.blocks'

t="$(make_tree html-order)"
edit "$t/templates/rikugan.html" '<section id="spend">' '<section id="TMP">'
edit "$t/templates/rikugan.html" '<section id="legend">' '<section id="spend">'
edit "$t/templates/rikugan.html" '<section id="TMP">' '<section id="legend">'
run_case 'an HTML render whose blocks run out of order fails' 1 "$t" "the HTML render's blocks run"

t="$(make_tree no-md)"
rm "$t/templates/rikugan.md"
run_case 'a variant with no Markdown template fails' 1 "$t" 'templates/rikugan.md: missing for variant register'

# --- the desk ------------------------------------------------------------------------------------
t="$(make_tree stars)"
edit "$t/templates/spiritual-message.md" '{{#if star}} ⭐ {{star}}{{/if}}' ' ⭐ {{star}}'
run_case 'every option starred fails' 1 "$t" 'ask 1 carries 3 starred option(s); exactly one is the rule'

t="$(make_tree no-star)"
edit "$t/templates/rikugan.md" '{{#if star}} ⭐ {{star}}{{/if}}' ''
run_case 'an ask with no star fails' 1 "$t" 'ask 2 carries 0 starred option(s)'

t="$(make_tree ask-dropped)"
edit "$t/templates/rikugan.md" '<!-- hatsu:ask -->' ''
run_case 'a desk that drops its asks fails' 1 "$t" 'the desk renders 0 ask(s), the data carries 2'

t="$(make_tree verdict)"
edit "$t/templates/rikugan.md" '“{{verdict}}”' '{{verdict}}'
run_case 'a verdict not quoted verbatim fails' 1 "$t" "does not quote its readiness verdict verbatim"

t="$(make_tree sm-verdict)"
edit "$t/templates/spiritual-message.md" '“{{verdict}}”' '{{reason}}'
run_case 'a landing verdict not quoted fails' 1 "$t" 'the G4 readiness verdict is not quoted verbatim on the desk'

t="$(make_tree g5)"
edit "$t/templates/spiritual-message.md" 'id="g5-blocker"' 'id="blocker"'
run_case 'a G5 blocker with no wrapper fails' 1 "$t" 'the desk has no g5-blocker wrapper'

t="$(make_tree heading-star)"
edit "$t/templates/spiritual-message.md" '{{#if star}} ⭐ {{star}}{{/if}}' ''
edit "$t/templates/spiritual-message.md" '### {{ask.question}}' '### {{ask.question}} ⭐'
run_case 'a star outside the option lines does not count' 1 "$t" 'ask 1 carries 0 starred option(s)'

t="$(make_tree gate)"
edit "$t/templates/rikugan.md" '### {{gate}} · {{label}}' '### {{label}}'
run_case 'a gate omitted from the desk fails' 1 "$t" 'gate G2 is omitted from the desk'

# --- escaping, raw slots and tables --------------------------------------------------------------
t="$(make_tree span)"
edit "$t/templates/rikugan.md" '<pre>{{command}}</pre>' '`{{command}}`'
run_case 'a value in a code span is refused in the template' 1 "$t" 'a value inside a code span renders its escape literally'
run_case 'and its escape is caught in the render' 1 "$t" 'an escaped entity inside a code span shows literally in GFM'

t="$(make_tree fence)"
edit "$t/templates/spiritual-message.md" '<pre>{{launch}}</pre>' $'```\n{{launch}}\n```'
# the examples' launch is a reason line with nothing to escape; give the case a value that has some
edit_json "$t/templates/report-examples/turn.data.json" 'd["launch"] = "npm run dev -- --host \"0.0.0.0\" && open <url>"'
run_case 'an escaped value in a fence fails' 1 "$t" 'an escaped entity inside a code fence shows literally in GFM'

t="$(make_tree icode)"
edit "$t/templates/spiritual-message.md" $'{{ask.whyNow}}\n\n{{#each ask.options}}' $'{{ask.whyNow}}\n\n    {{ask.whyNow}}\n\n{{#each ask.options}}'
run_case 'an escaped value in an indented code block fails' 1 "$t" 'an escaped entity inside an indented code block shows literally in GFM'

t="$(make_tree raw)"
edit "$t/templates/rikugan.md" '{{why}}' '{{{why}}}'
run_case 'a raw slot outside the mermaid fence fails' 1 "$t" "a raw slot '{{{why}}}' outside the mermaid fence"

t="$(make_tree pipe)"
edit_json "$t/templates/report-examples/landing.data.json" 'd["touchedCoverage"][0]["band"] = "ideal | high"'
run_case 'a | that splits a table cell fails' 1 "$t" 'a table row has 4 cells, its header 3'

t="$(make_tree leak)"
edit_json "$t/templates/report-examples/turn.data.json" 'd["lastTurnRequest"] = "a {{leak}} in a value"'
run_case 'an unfilled {{ in the output fails' 1 "$t" "an unfilled '{{' remains"

t="$(make_tree data-graph)"
edit_json "$t/templates/report-examples/final.data.json" 'd["graphMermaid"] = "flowchart LR"'
run_case 'a data document carrying graphMermaid fails' 1 "$t" 'final.data.json: carries graphMermaid; a Markdown render takes the graph from --graph only'

t="$(make_tree forged)"
edit_json "$t/templates/report-examples/register.data.json" 'd["objects"][1]["title"] = "x](javascript:alert(1)) [y\n**MERGE** · G2"'
run_case 'a newline in a free-text value fails' 1 "$t" 'register.data.json: $.objects[1].title carries a newline outside a <pre> slot'

t="$(make_tree bad-bytes)"
printf '\377\376 not utf-8\n' > "$t/templates/report-examples/final.md"
run_case 'a non-UTF-8 example is a finding, not a traceback' 1 "$t" 'templates/report-examples/final.md: not UTF-8'

t="$(make_tree null-data)"
printf 'null\n' > "$t/templates/report-examples/turn-fast.data.json"
run_case 'a null data document is a finding, not a traceback' 1 "$t" 'turn-fast.data.json: not a data document (a JSON object), but NoneType'

# --- one data document ---------------------------------------------------------------------------
t="$(make_tree token)"
edit "$t/templates/spiritual-message.md" '# {{title}}' '# {{title}} {{contract}}'
run_case 'a token the HTML template does not name fails' 1 "$t" 'templates/spiritual-message.md names token(s) templates/spiritual-message.html does not: contract'

t="$(make_tree html-token)"
edit "$t/templates/spiritual-message.html" '<h1>{{title}}</h1>' '<h1>{{title}} {{contract}}</h1>'
run_case 'a token only the HTML names fails' 1 "$t" 'templates/spiritual-message.html names token(s) templates/spiritual-message.md does not: contract'

t="$(make_tree refused)"
edit "$t/templates/rikugan.md" '{{footerCount}}' '{{footerCountNever}}'
run_case 'a token the data has not got is a refused render' 1 "$t" 'does not render from templates/report-examples/register.data.json (exit 2)'

# --- the checked examples ------------------------------------------------------------------------
t="$(make_tree stale)"
printf 'drift\n' >> "$t/templates/report-examples/final.md"
run_case 'a stale checked example fails' 1 "$t" 'templates/report-examples/final.md: not a fresh render'
run_case '--write-examples rewrites it and passes' 0 "$t" 'examples fresh' --write-examples
run_case 'and it then stays fresh' 0 "$t" 'examples fresh'

t="$(make_tree no-example)"
rm "$t/templates/report-examples/turn-fast.md"
run_case 'a missing checked example fails' 1 "$t" 'the checked example for turn-fast is missing'

# --- wiring --------------------------------------------------------------------------------------
t="$(make_tree wiring)"
run_case 'an unknown argument is a wiring refusal' 2 "$t" "unknown argument '--bogus'" --bogus
run_case 'a missing nen is a wiring refusal' 2 "$t" 'nen is required' --nen "$work/no-such-nen"
mkdir -p "$work/not-hatsu"
run_case 'a non-Hatsu root is a wiring refusal' 2 "$work/not-hatsu" 'is not a Hatsu checkout'
edit_json "$t/nen/workflow.json" 'd["reports"].pop("sections")'
run_case 'a workflow with no reports.sections is a wiring refusal' 2 "$t" 'has no readable reports.sections'

# --- --help prints the whole header (a hardcoded line range once dropped EXIT CODES, hanten on #216) --
if bash "$guard" --help 2>&1 | grep -q '^# EXIT CODES'; then n=$((n + 1)); else printf -- '--help no longer prints the EXIT CODES block\n' >&2; exit 1; fi

# --- this repository -----------------------------------------------------------------------------
if out="$(bash "$guard" --root "$repo_root" 2>&1)"; then
  n=$((n + 1)); printf 'this repository passes: %s\n' "$out"
else
  printf 'this repository fails the guard:\n%s\n' "$out" >&2; exit 1
fi
printf 'report-markdown-guard: %s cases passed\n' "$n"
