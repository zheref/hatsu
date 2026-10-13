#!/usr/bin/env bash
# report_markdown_check.sh — the guard for the Markdown report templates (zheref/hatsu#215).
#
# WHAT IT PROTECTS. A surface whose native report is a Markdown artifact (Antigravity) publishes
# `nen report render`'s fill of templates/spiritual-message.md or templates/rikugan.md, from the SAME
# data document and the SAME reports.sections.<variant>.blocks as the HTML templates beside them, so
# the two renders cannot disagree on which blocks a variant shows. For every variant nen/workflow.json
# declares, this guard renders BOTH templates from templates/report-examples/<variant>.data.json
# (with --graph templates/graph.example.json where the document carries no graph) and fails when:
#
#   1. a render is refused, or the Markdown still carries a `{{`;
#   2. the Markdown's block markers are not the declared blocks, in the declared order, or the HTML
#      render's blocks are not that same sequence;
#   3. the desk drops an ask, an ask carries other than exactly one star, a readiness verdict is not
#      quoted verbatim, a G5 blocker has no `g5-blocker` wrapper, or a gate of the register is
#      omitted rather than shown cleared;
#   4. an escaped value lands where GFM shows the escape literally — inside a code span or a fence —
#      or a raw slot other than `graphMermaid` inside the mermaid fence appears in a template;
#   5. a GFM table row has a cell count other than its header's (a `|` in a value split it);
#   6. the Markdown template names a token the HTML template does not (one data shape; graphMermaid,
#      injected by --graph beside graphJson, is the one exception);
#   7. templates/report-examples/<variant>.md, the checked example the skills and docs/PROCESS.md
#      § The Markdown report point at, is not byte for byte a fresh render.
#
# WHO RUNS IT. The report-markdown-guard lane (`nen shu test --repo <hatsu> --lane report-markdown-guard`),
# through scripts/report_markdown_check_fixture.sh, which proves each refusal on throwaway trees and
# then runs this check on the repository itself. No installed copy executes it, so it is not in
# scripts/plugin_bump_check.sh's PLUGIN_SURFACE_GLOBS; the templates and examples it guards are
# (templates/*).
#
# USAGE
#   scripts/report_markdown_check.sh [--root <hatsu checkout>] [--nen <binary>] [--write-examples]
#     --root            default: this script's parent
#     --nen             default: $NEN_BIN, else `nen` on PATH
#     --write-examples  rewrite each templates/report-examples/<variant>.md from its fresh render
#                       (after a template change), then check as usual
#
# EXIT CODES
#   0  every variant renders, in order, with its desk rules, in both formats, matching its example
#   1  a finding: every finding is printed, never only the first
#   2  wiring: an unknown argument, a root that is not a Hatsu checkout, python3 or nen absent, or
#      a nen/workflow.json with no reports.sections
set -euo pipefail

root=""
nen="${NEN_BIN:-}"
write=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || { echo "report_markdown_check.sh: --root needs a path" >&2; exit 2; }; root="$2"; shift 2 ;;
    --nen) [ "$#" -ge 2 ] || { echo "report_markdown_check.sh: --nen needs a path" >&2; exit 2; }; nen="$2"; shift 2 ;;
    --write-examples) write=1; shift ;;
    -h|--help) sed -n '2,46p' "$0"; exit 0 ;;
    *) echo "report_markdown_check.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
if [ -z "$root" ]; then
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
[ -d "$root" ] || { echo "report_markdown_check.sh: root '$root' is not a directory" >&2; exit 2; }
root="$(cd "$root" && pwd)"
[ -f "$root/.claude-plugin/plugin.json" ] || { echo "report_markdown_check.sh: '$root' is not a Hatsu checkout (no .claude-plugin/plugin.json)" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "report_markdown_check.sh: python3 is required" >&2; exit 2; }
if [ -z "$nen" ]; then
  nen="$(command -v nen 2>/dev/null || true)"
fi
[ -n "$nen" ] && [ -x "$nen" ] || { echo "report_markdown_check.sh: nen is required (PATH, \$NEN_BIN or --nen); the render is nen's, never improvised" >&2; exit 2; }

work="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-report-markdown.XXXXXX")"
trap 'rm -rf "$work"' EXIT

python3 -I - "$root" "$nen" "$work" "$write" <<'PY'
import html
import json
import os
import re
import shutil
import subprocess
import sys

root, nen, work, write = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
findings = []
def find(msg):
    findings.append(msg)

try:
    workflow = json.load(open(os.path.join(root, "nen/workflow.json"), encoding="utf-8"))
    sections = workflow["reports"]["sections"]
except (OSError, ValueError, KeyError, TypeError) as e:
    sys.stderr.write(f"report_markdown_check.sh: nen/workflow.json has no readable reports.sections ({e})\n")
    sys.exit(2)
variants = [v for v in sections if not v.startswith("$")]
if not variants:
    sys.stderr.write("report_markdown_check.sh: reports.sections declares no variant\n")
    sys.exit(2)

os.makedirs(os.path.join(work, "nen"))
shutil.copy(os.path.join(root, "nen/workflow.json"), os.path.join(work, "nen/workflow.json"))

# Where each block sits in the HTML templates. A block the guard does not know is a finding, so a
# new block cannot ship in one format only.
HTML_ANCHOR = {
    "masthead": '<header class="mast">', "tally": '<section class="tally"', "desk": '<section id="desk">',
    "lastTurn": '<section id="last-turn">', "landed": '<section id="landed">', "delta": '<section id="delta">',
    "evidence": '<section id="evidence">', "spend": '<section id="spend">', "launch": '<section id="launch">',
    "decisions": '<section id="decisions">', "prBody": '<section id="pr-body">',
    "register": '<section id="register">', "legend": '<section id="legend">',
}
BLOCK_RE = re.compile(r"^<!-- hatsu:block ([A-Za-z]+) -->$", re.M)
ASK = "<!-- hatsu:ask -->"
STAR = "⭐"
ENTITY = re.compile(r"&(amp|lt|gt|quot|#39);")
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")

def esc(v):
    return html.escape("" if v is None else str(v), quote=True).replace("&#x27;", "&#39;")

def render(variant, template, data, out, graph):
    argv = [nen, "report", "render", "--variant", variant, "--template", template, "--data", data,
            "--out", out, "--repo", work]
    if graph:
        argv += ["--graph", graph]
    p = subprocess.run(argv, capture_output=True, text=True)
    return p.returncode, p.stderr.strip()

def tokens(template, data, graph, variant):
    argv = [nen, "report", "render", "--variant", variant, "--template", template, "--data", data,
            "--out", os.path.join(work, "dry"), "--repo", work, "--dry-run", "--json"]
    if graph:
        argv += ["--graph", graph]
    p = subprocess.run(argv, capture_output=True, text=True)
    if p.returncode != 0:
        return None
    return set(json.loads(p.stdout).get("tokens", []))

def regions(text):
    """Yield (line_no, line, kind) with kind in text | fence | pre: GFM's literal regions."""
    fence = None
    pre = False
    for n, line in enumerate(text.split("\n"), 1):
        if pre:
            yield n, line, "pre"
            if "</pre>" in line:
                pre = False
            continue
        if fence:
            m = FENCE.match(line)
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and not line.strip(" `~"):
                fence = None
                yield n, line, "fence-edge"
                continue
            yield n, line, "fence"
            continue
        m = FENCE.match(line)
        if m:
            fence = m.group(1)
            yield n, line, "fence-edge"
            continue
        if line.lstrip().startswith("<pre>") and "</pre>" not in line:
            pre = True
        yield n, line, "pre" if line.lstrip().startswith("<pre>") else "text"

def cells(row):
    row = row.strip()
    if row.startswith("|"):
        row = row[1:]
    if row.endswith("|") and not row.endswith("\\|"):
        row = row[:-1]
    return len(re.split(r"(?<!\\)\|", row))

def check_markdown(variant, md, data, where):
    if "{{" in md:
        n = md[: md.index("{{")].count("\n") + 1
        find(f"{where}:{n}: an unfilled '{{{{' remains")
    declared = sections[variant].get("blocks") or list(HTML_ANCHOR)
    found = BLOCK_RE.findall(md)
    if found != declared:
        find(f"{where}: blocks {found} are not the declared reports.sections.{variant}.blocks {declared}")
    # --- the desk ------------------------------------------------------------------------------
    if "desk" in found:
        start = md.index("<!-- hatsu:block desk -->")
        nxt = BLOCK_RE.search(md, start + 10)
        end = nxt.start() if nxt else md.find("\n---\n", start)
        desk = md[start:end if end > 0 else len(md)]
        chunks = desk.split(ASK)[1:]
        if "gates" in data:
            asks = [a for g in data.get("gates") or [] for a in g.get("asks") or []]
            for g in data.get("gates") or []:
                head = f"### {esc(g.get('gate'))} · {esc(g.get('label'))}"
                if head not in desk:
                    find(f"{where}: gate {g.get('gate')} is omitted from the desk; a gate with nothing owed is shown cleared")
            for a, c in zip(asks, chunks):
                v = a.get("verdict")
                if v and f"“{esc(v)}”" not in c:
                    find(f"{where}: ask '{a.get('title')}' does not quote its readiness verdict verbatim")
        else:
            asks = [data["ask"]] if data.get("ask") else []
            for r in data.get("readiness") or []:
                if f"“{esc(r.get('verdict'))}”" not in desk:
                    find(f"{where}: the {r.get('gate')} readiness verdict is not quoted verbatim on the desk")
            if data.get("ask") and data["ask"].get("blocker") and 'id="g5-blocker"' not in desk:
                find(f"{where}: the ask carries a G5 blocker and the desk has no g5-blocker wrapper")
            if not data.get("ask") and data.get("deskCleared") and esc(data["deskCleared"]) not in desk:
                find(f"{where}: a cleared desk does not say so")
        if len(chunks) != len(asks):
            find(f"{where}: the desk renders {len(chunks)} ask(s), the data carries {len(asks)}")
        for i, c in enumerate(chunks, 1):
            if "gates" in data:   # a register ask ends at the next gate heading
                c = re.split(r"^### ", c, flags=re.M)[0]
            stars = c.count(STAR)
            if stars != 1:
                find(f"{where}: ask {i} carries {stars} starred option(s); exactly one is the rule")
    # --- GFM's literal regions and tables --------------------------------------------------------
    header = None
    for n, line, kind in regions(md):
        if kind == "fence" and ENTITY.search(line):
            find(f"{where}:{n}: an escaped entity inside a code fence shows literally in GFM: {line.strip()[:80]}")
        if kind != "text":
            header = None
            continue
        for span in re.finditer(r"(`+)(.+?)\1", line):
            if ENTITY.search(span.group(2)):
                find(f"{where}:{n}: an escaped entity inside a code span shows literally in GFM: {span.group(0)[:80]}")
        if line.startswith("|"):
            if header is None:
                header = cells(line)
            elif cells(line) != header:
                find(f"{where}:{n}: a table row has {cells(line)} cells, its header {header} (a '|' in a value splits a cell)")
        else:
            header = None

def check_html_order(variant, page, where):
    declared = sections[variant].get("blocks") or list(HTML_ANCHOR)
    seen = []
    for b in declared:
        anchor = HTML_ANCHOR.get(b)
        if anchor is None:
            find(f"{where}: block '{b}' has no known HTML anchor; teach this guard where it sits")
            continue
        i = page.find(anchor)
        if i < 0:
            find(f"{where}: declared block '{b}' is missing from the HTML render")
        else:
            seen.append((i, b))
    order = [b for _, b in sorted(seen)]
    if order != [b for b in declared if b in dict((x, 1) for _, x in seen)]:
        find(f"{where}: the HTML render's blocks run {order}, not the declared order")

def check_template_static(path):
    text = open(path, encoding="utf-8").read()
    lines = text.split("\n")
    for n, line in enumerate(lines, 1):
        for m in re.finditer(r"\{\{\{\s*([^}]*?)\s*\}\}\}", line):
            ok = (m.group(1) == "graphMermaid" and line.strip() == m.group(0)
                  and n >= 2 and lines[n - 2].strip() == "```mermaid" and n < len(lines) and lines[n].strip() == "```")
            if not ok:
                find(f"{os.path.relpath(path, root)}:{n}: a raw slot '{m.group(0)}' outside the mermaid fence; every other value is escaped")
        for m in re.finditer(r"(`+)([^`]*\{\{[^`]*)\1", line):
            find(f"{os.path.relpath(path, root)}:{n}: a value inside a code span renders its escape literally: {m.group(0)[:80]}")

graph_default = os.path.join(root, "templates/graph.example.json")
checked_templates = set()
for v in variants:
    t = sections[v].get("template")
    if not t:
        find(f"nen/workflow.json: reports.sections.{v} names no template")
        continue
    md_t = os.path.join(root, "templates", f"{t}.md")
    html_t = os.path.join(root, "templates", f"{t}.html")
    data_p = os.path.join(root, "templates/report-examples", f"{v}.data.json")
    example = os.path.join(root, "templates/report-examples", f"{v}.md")
    missing = [p for p in (md_t, html_t, data_p) if not os.path.isfile(p)]
    if missing:
        for p in missing:
            find(f"{os.path.relpath(p, root)}: missing for variant {v}")
        continue
    if md_t not in checked_templates:
        check_template_static(md_t)
        checked_templates.add(md_t)
    try:
        data = json.load(open(data_p, encoding="utf-8"))
    except ValueError as e:
        find(f"{os.path.relpath(data_p, root)}: not JSON ({e})")
        continue
    graph = None if "graphMermaid" in data else graph_default
    out_md = os.path.join(work, f"{v}.md")
    out_html = os.path.join(work, f"{v}.html")
    rc, err = render(v, md_t, data_p, out_md, graph)
    if rc != 0:
        find(f"templates/{t}.md: variant {v} does not render from {os.path.relpath(data_p, root)} (exit {rc}): {err.splitlines()[0] if err else ''}")
        continue
    rc, err = render(v, html_t, data_p, out_html, graph)
    if rc != 0:
        find(f"templates/{t}.html: variant {v} does not render from the same document (exit {rc}): {err.splitlines()[0] if err else ''}")
    else:
        check_html_order(v, open(out_html, encoding="utf-8").read(), f"templates/{t}.html [{v}]")
    md = open(out_md, encoding="utf-8").read()
    check_markdown(v, md, data, f"templates/{t}.md [{v}]")
    tm, th = tokens(md_t, data_p, graph, v), tokens(html_t, data_p, graph, v)
    if tm is None or th is None:
        find(f"templates/{t}: the dry run could not list the tokens for variant {v}")
    else:
        extra = sorted(tm - th - {"graphMermaid"})
        if extra:
            find(f"templates/{t}.md names token(s) templates/{t}.html does not: {', '.join(extra)}; one data document feeds both")
    if write:
        shutil.copy(out_md, example)
    if not os.path.isfile(example):
        find(f"{os.path.relpath(example, root)}: the checked example for {v} is missing (run with --write-examples)")
    elif open(example, encoding="utf-8").read() != md:
        find(f"{os.path.relpath(example, root)}: not a fresh render of templates/{t}.md (run with --write-examples)")

for f in findings:
    print(f)
if findings:
    print(f"report-markdown: {len(findings)} finding(s)")
    sys.exit(1)
print(f"report-markdown ok: {len(variants)} variant(s) render in both formats, blocks in order, one star per ask, examples fresh")
PY
