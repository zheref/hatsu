#!/usr/bin/env bash
# report_markdown_check.sh — the guard for the Markdown report templates (zheref/hatsu#215).
#
# FROZEN (the maintainer's ruling of 2026-10-13, docs/ROSTER.md § Rulings of 2026-10-13): BC-11's
# embedded-Python freeze binds this script as it binds scripts/hanten_cycle_ledger.sh (ruling of
# 2026-10-03). Fixes only — no new check, verdict, flag or subcommand — until nen carries the template
# conformance verb the run's harvest requests (a `nen report check` over the Markdown and HTML templates,
# the example data documents and the declared blocks); when it lands, this script and its fixture retire
# and lane report-markdown-guard points at nen's own tests.
#
# WHAT IT PROTECTS. A surface whose native report is a Markdown artifact (Antigravity) publishes
# `nen report render`'s fill of templates/spiritual-message.md or templates/rikugan.md, from the SAME
# data document and the SAME reports.sections.<variant>.blocks as the HTML templates beside them, so
# the two renders cannot disagree on which blocks a variant shows. For every variant nen/workflow.json
# declares, this guard renders BOTH templates from templates/report-examples/<variant>.data.json
# and fails when:
#
#   0. a data document is not a UTF-8 JSON object, carries `graphMermaid` (a Markdown render takes it from
#      --graph only: templates/report-examples/<variant>.graph.json, else templates/graph.example.json),
#      or carries a newline in a value outside a `<pre>` slot (it would end its Markdown line);
#   1. a render is refused, or the Markdown still carries a `{{`;
#   2. the Markdown's block markers are not the declared blocks, in the declared order, or the HTML
#      render's blocks are not that same sequence;
#   3. the desk drops an ask, an ask has other than exactly one starred OPTION LINE, a verdict is not
#      quoted verbatim, a G5 blocker has no `g5-blocker` wrapper, or a gate of the register is
#      omitted rather than shown cleared;
#   4. an escaped value lands where GFM shows the escape literally — a code span, a fence or an indented
#      code block — or a raw slot other than `graphMermaid` inside the mermaid fence is in a template;
#   5. a GFM table row has a cell count other than its header's (a `|` in a value split it);
#   6. the Markdown template names a token the HTML template does not (graphMermaid excepted), or the
#      HTML names one the Markdown does not beyond its presentational tokens (*Class, generatedAt,
#      graphJson);
#   7. templates/report-examples/<variant>.md, the checked example the skills and docs/PROCESS.md
#      § The Markdown report point at, is not byte for byte a fresh render.
#
# WHO RUNS IT. The report-markdown-guard lane (`nen shu test --repo <hatsu> --lane report-markdown-guard`),
# through scripts/report_markdown_check_fixture.sh, which proves each refusal on throwaway trees and
# then runs this check on the repository itself. No installed copy executes it, so it is not in
# scripts/plugin_bump_check.sh's PLUGIN_SURFACE_GLOBS; the templates and examples it guards are
# (templates/*).
#
# BC-11. The check is embedded Python, owed to a nen verb (template conformance; docs/PROCESS.md
# § Residue and owned dependencies, the spiritual-message and rikugan entry). Until the G4 port-or-waive
# ruling, fixes only.
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
    -h|--help) sed -n '2,49p' "$0"; exit 0 ;;
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

def rel(p):
    return os.path.relpath(p, root)

def read_text(path):
    """A file's text, or None with a finding: a bad file is a finding, never a traceback."""
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except UnicodeDecodeError as e:
        find(f"{rel(path)}: not UTF-8 ({e.reason} at byte {e.start})")
    except OSError as e:
        find(f"{rel(path)}: unreadable ({e.strerror})")
    return None

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
# Tokens only the HTML names because they are presentation there: a CSS class, the machine time in
# a <time> attribute, the graph JSON the page lays out. Any other HTML-only token is a block the
# Markdown dropped.
HTML_ONLY = re.compile(r"^(.*Class|generatedAt|graphJson)$")
BLOCK_RE = re.compile(r"^<!-- hatsu:block ([A-Za-z]+) -->$", re.M)
ASK = "<!-- hatsu:ask -->"
OPTION = re.compile(r"^- \*\*[A-Z]\*\* · ")
STAR = "⭐"
ENTITY = re.compile(r"&(amp|lt|gt|quot|#39);")
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
LIST_ITEM = re.compile(r"^ {0,3}([-*+]|\d{1,9}[.)])( |$)")
PRE_SLOT = re.compile(r"<pre>\{\{([A-Za-z_.]+)\}\}</pre>")

def esc(v):
    return html.escape("" if v is None else str(v), quote=True).replace("&#x27;", "&#39;")

def nen_render(variant, template, data, out, graph, *extra):
    argv = [nen, "report", "render", "--variant", variant, "--template", template, "--data", data,
            "--out", out, "--repo", work, "--graph", graph, *extra]
    return subprocess.run(argv, capture_output=True, text=True)

def tokens(template, data, graph, variant):
    p = nen_render(variant, template, data, os.path.join(work, "dry"), graph, "--dry-run", "--json")
    if p.returncode != 0:
        return None
    return set(json.loads(p.stdout).get("tokens", []))

def regions(text):
    """Yield (line_no, line, kind): text, or one of GFM's literal regions -- a fence (and its edge),
    an indented code block, a <pre> block."""
    fence = None
    pre = False
    icode = False
    in_list = False
    prev_blank = True
    for n, line in enumerate(text.split("\n"), 1):
        blank = not line.strip()
        if pre:
            yield n, line, "pre"
            if "</pre>" in line:
                pre = False
            prev_blank = blank
            continue
        if fence:
            m = FENCE.match(line)
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and not line.strip(" `~"):
                fence = None
                yield n, line, "fence-edge"
            else:
                yield n, line, "fence"
            prev_blank = blank
            continue
        indented = line.startswith("    ") or line.startswith("\t")
        if icode and (blank or indented):
            yield n, line, "icode"
            prev_blank = blank
            continue
        icode = False
        if indented and not blank and prev_blank and not in_list:
            icode = True
            yield n, line, "icode"
            prev_blank = False
            continue
        if not blank:
            if LIST_ITEM.match(line):
                in_list = True
            elif not line.startswith(" "):
                in_list = False
        m = FENCE.match(line)
        if m:
            fence = m.group(1)
            yield n, line, "fence-edge"
        elif line.lstrip().startswith("<pre>"):
            pre = "</pre>" not in line
            yield n, line, "pre"
        else:
            yield n, line, "text"
        prev_blank = blank

def cells(row):
    row = row.strip()
    if row.startswith("|"):
        row = row[1:]
    if row.endswith("|") and not row.endswith("\\|"):
        row = row[:-1]
    return len(re.split(r"(?<!\\)\|", row))

def newlines(value, pre_keys, path="$"):
    """Every string with a newline outside a <pre> slot: in the Markdown it ends the line it sits on,
    so a value could open a forged ask or an unclosed fence."""
    if isinstance(value, dict):
        for k, v in value.items():
            yield from newlines(v, pre_keys, f"{path}.{k}") if not (isinstance(v, str) and k in pre_keys) else ()
    elif isinstance(value, list):
        for i, v in enumerate(value):
            yield from newlines(v, pre_keys, f"{path}[{i}]")
    elif isinstance(value, str) and ("\n" in value or "\r" in value):
        yield path

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
            stars = sum(1 for l in c.split("\n") if OPTION.match(l) and STAR in l)
            if stars != 1:
                find(f"{where}: ask {i} carries {stars} starred option(s); exactly one is the rule")
    # --- GFM's literal regions and tables --------------------------------------------------------
    header = None
    for n, line, kind in regions(md):
        if kind in ("fence", "icode") and ENTITY.search(line):
            what = "a code fence" if kind == "fence" else "an indented code block"
            find(f"{where}:{n}: an escaped entity inside {what} shows literally in GFM: {line.strip()[:80]}")
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

def check_template_static(path, text):
    lines = text.split("\n")
    for n, line in enumerate(lines, 1):
        for m in re.finditer(r"\{\{\{\s*([^}]*?)\s*\}\}\}", line):
            ok = (m.group(1) == "graphMermaid" and line.strip() == m.group(0)
                  and n >= 2 and lines[n - 2].strip() == "```mermaid" and n < len(lines) and lines[n].strip() == "```")
            if not ok:
                find(f"{rel(path)}:{n}: a raw slot '{m.group(0)}' outside the mermaid fence; every other value is escaped")
        for m in re.finditer(r"(`+)([^`]*\{\{[^`]*)\1", line):
            find(f"{rel(path)}:{n}: a value inside a code span renders its escape literally: {m.group(0)[:80]}")

graph_default = os.path.join(root, "templates/graph.example.json")
for v in variants:
    t = sections[v].get("template")
    if not t:
        find(f"nen/workflow.json: reports.sections.{v} names no template")
        continue
    md_t = os.path.join(root, "templates", f"{t}.md")
    html_t = os.path.join(root, "templates", f"{t}.html")
    data_p = os.path.join(root, "templates/report-examples", f"{v}.data.json")
    example = os.path.join(root, "templates/report-examples", f"{v}.md")
    own_graph = os.path.join(root, "templates/report-examples", f"{v}.graph.json")
    graph = own_graph if os.path.isfile(own_graph) else graph_default
    missing = [p for p in (md_t, html_t, data_p) if not os.path.isfile(p)]
    if missing:
        for p in missing:
            find(f"{rel(p)}: missing for variant {v}")
        continue
    md_text = read_text(md_t)
    data_text = read_text(data_p)
    if md_text is None or data_text is None:
        continue
    check_template_static(md_t, md_text)
    try:
        data = json.loads(data_text)
    except ValueError as e:
        find(f"{rel(data_p)}: not JSON ({e})")
        continue
    if not isinstance(data, dict):
        find(f"{rel(data_p)}: not a data document (a JSON object), but {type(data).__name__}")
        continue
    if "graphMermaid" in data:
        find(f"{rel(data_p)}: carries graphMermaid; a Markdown render takes the graph from --graph only, "
             "where nen serialises it from a validated document")
        continue
    pre_keys = {k.split(".")[-1] for k in PRE_SLOT.findall(md_text)}
    for path in newlines(data, pre_keys):
        find(f"{rel(data_p)}: {path} carries a newline outside a <pre> slot; in Markdown it ends the line it sits on")
    out_md = os.path.join(work, f"{v}.md")
    out_html = os.path.join(work, f"{v}.html")
    p = nen_render(v, md_t, data_p, out_md, graph)
    if p.returncode != 0:
        err = p.stderr.strip()
        find(f"templates/{t}.md: variant {v} does not render from {rel(data_p)} (exit {p.returncode}): {err.splitlines()[0] if err else ''}")
        continue
    p = nen_render(v, html_t, data_p, out_html, graph)
    if p.returncode != 0:
        err = p.stderr.strip()
        find(f"templates/{t}.html: variant {v} does not render from the same document (exit {p.returncode}): {err.splitlines()[0] if err else ''}")
    else:
        page = read_text(out_html)
        if page is not None:
            check_html_order(v, page, f"templates/{t}.html [{v}]")
    md = read_text(out_md)
    if md is None:
        continue
    check_markdown(v, md, data, f"templates/{t}.md [{v}]")
    tm, th = tokens(md_t, data_p, graph, v), tokens(html_t, data_p, graph, v)
    if tm is None or th is None:
        find(f"templates/{t}: the dry run could not list the tokens for variant {v}")
    else:
        extra = sorted(tm - th - {"graphMermaid"})
        if extra:
            find(f"templates/{t}.md names token(s) templates/{t}.html does not: {', '.join(extra)}; one data document feeds both")
        dropped = sorted(x for x in th - tm if not HTML_ONLY.match(x))
        if dropped:
            find(f"templates/{t}.html names token(s) templates/{t}.md does not: {', '.join(dropped)}; the Markdown dropped what the page shows")
    if write:
        shutil.copy(out_md, example)
    if not os.path.isfile(example):
        find(f"{rel(example)}: the checked example for {v} is missing (run with --write-examples)")
    else:
        ex = read_text(example)
        if ex is not None and ex != md:
            find(f"{rel(example)}: not a fresh render of templates/{t}.md (run with --write-examples)")

for f in findings:
    print(f)
if findings:
    print(f"report-markdown: {len(findings)} finding(s)")
    sys.exit(1)
print(f"report-markdown ok: {len(variants)} variant(s) render in both formats, blocks in order, one star per ask, examples fresh")
PY
