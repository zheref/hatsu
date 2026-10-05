#!/usr/bin/env bash
# direct_matrix_doc.sh — render the model matrix hatsu:direct resolves from, as a page a person reads.
#
#   bash scripts/direct_matrix_doc.sh [--write | --check | --verify] [repo-root]
#
#   (none)     print the rendered page to stdout
#   --write    write it to docs/DIRECT-MATRIX.md
#   --check    exit 1 when docs/DIRECT-MATRIX.md differs from what the data renders (drift guard)
#   --verify   ask `nen direct resolve` for every rendered cell, every fallback and every worked
#              example and exit 1 on the first disagreement — proof the page says what direct does
#
# WHY A GENERATOR. hatsu:direct never decides in prose: `nen direct resolve` reads
# contracts/direct.registry.json, contracts/classify.taxonomy.json and the consumer's
# nen/workflow.json -> models, and answers. A hand-written table of the same answers would be a second
# copy that rots the first time a cell moves. This page is therefore RENDERED from those three files and
# from nothing else, so the page and the verb cannot disagree unless the page is stale (--check says so)
# or the verb reads the data differently than this renderer does (--verify says so, by cell).
#
# WHAT IS PRESENTATION HERE, AND WHAT IS NOT. The provider dots, the domain display names and the
# worked-example inputs are presentation and live in this file. Every alias, surface, tier, typed
# model name, routing cell, weight, band, rule and snapshot version is read from the data. The
# aggregation and effort arithmetic is re-implemented below only to render the worked examples; --verify
# holds it to the verb's own answer.
#
# It follows scripts/config_values.sh's house shape: a thin bash wrapper over one embedded python3
# program.
set -euo pipefail

mode=print
root=""
for arg in "$@"; do
  case "$arg" in
    --write) mode=write ;;
    --check) mode=check ;;
    --verify) mode=verify ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    -*) echo "direct_matrix_doc: unknown flag $arg" >&2; exit 2 ;;
    *) root="$arg" ;;
  esac
done
if [ -z "$root" ]; then
  root="$(cd "$(dirname "$0")/.." && pwd)"
fi

exec python3 - "$mode" "$root" <<'PY'
import json, os, re, subprocess, sys, tempfile

mode, root = sys.argv[1], sys.argv[2]
REG_PATH = "contracts/direct.registry.json"
TAX_PATH = "contracts/classify.taxonomy.json"
WF_PATH = "nen/workflow.json"
OUT_PATH = "docs/DIRECT-MATRIX.md"

def load(p):
    with open(os.path.join(root, p), encoding="utf-8") as f:
        return json.load(f)

reg, tax, wf = load(REG_PATH), load(TAX_PATH), load(WF_PATH)
aliases, surfaces, routing = reg["aliases"], reg["surfaces"], reg["routing"]
snap = reg["snapshot"]
models = wf.get("models", {})
jobs = tax["axes"]["job"]["keys"]
job_by_key = {j["key"]: j for j in jobs}
langs = tax["axes"]["lang"]["keys"]
lang_keys = [l["key"] for l in langs]
code_lang = {l["key"]: l.get("code", True) is not False for l in langs}
domains = tax["domains"]["keys"]
precedence = reg["aggregation"]["precedence"]
bands = reg["effort"]["rule"]["bands"]
surface_map = reg["effort"]["surfaceMap"]

# ---- presentation only --------------------------------------------------------------------------
DOT = {"anthropic": "🟠", "openai": "🟢", "google": "🔵", "cursor": "⚫"}
DOMAIN_NAME = {
    "feature": "Feature development",
    "maintenance": "Maintenance & operations",
    "parity": "Cross-platform parity",
    "aigov": "AI governance",
    "library": "Reusable library",
}
DOMAIN_SHORT = {"feature": "Feature", "maintenance": "Maintenance", "parity": "Parity",
                "aigov": "AI-gov", "library": "Library"}
LANG_NAME = {"swift": "Swift", "kotlin": "Kotlin", "typescript": "TypeScript", "csharp": "C#",
             "prose": "Prose"}
EXAMPLES = [
    {"title": "A canon or skill change in Hatsu itself",
     "kind": "process", "role": "canon", "labels": [], "lang": ["prose"], "job": ["prose-authoring"]},
    {"title": "A SwiftUI feature with its tests",
     "kind": "product", "role": None, "labels": [], "lang": ["swift"],
     "job": ["ui", "implementation", "unit-tests"]},
    {"title": "A TypeScript bug fix",
     "kind": "product", "role": None, "labels": ["bug"], "lang": ["typescript"],
     "job": ["bug-fix", "unit-tests"]},
    {"title": "Designing a Kotlin library's public API",
     "kind": "library", "role": None, "labels": [], "lang": ["kotlin"], "job": ["api-design"]},
    {"title": "Porting a screen from Swift to Kotlin",
     "kind": "product", "role": None, "labels": [], "lang": ["swift", "kotlin"],
     "job": ["parity", "ui"]},
    {"title": "A repository-wide mechanical rename in C#",
     "kind": "product", "role": None, "labels": [], "lang": ["csharp"], "job": ["mechanical-edit"]},
]
# -------------------------------------------------------------------------------------------------

def typed(alias):
    a = aliases[alias]
    if a.get("surface") is None:
        return None
    key = surfaces[a["surface"]]["modelsKey"]
    return models.get(key, {}).get(a["tier"])

def label(alias, surface=False):
    a = aliases[alias]
    dot = DOT.get(a["provider"], "⚪")
    if a.get("reviewer"):
        return f"🔍 {snap['aliases'][alias]['primary']}"
    t = typed(alias) or "unspelled"
    s = f"{dot} `{t}`"
    if surface:
        s += f" · {surfaces[a['surface']]['label']}"
    return s

def cell_text(c, surface=False):
    s = label(c["alias"], surface)
    if c.get("also"):
        s += f" → {label(c['also'], surface)}"
    return s

def same_alias(x, y):
    return x.get("alias") == y.get("alias") and x.get("also") == y.get("also")

def winner_diffs(r):
    star = r["cells"]["*"]["winner"]
    return [(l, r["cells"][l]["winner"]) for l in lang_keys
            if l in r["cells"] and not same_alias(r["cells"][l]["winner"], star)]

def band(score):
    for lvl in reg["effort"]["levels"]:
        lo, hi = bands[lvl]
        if lo <= score <= hi:
            return lvl
    return "max"

def cell_for(job, dom, lang):
    cells = routing[job][dom]["cells"]
    return cells.get(lang) or cells["*"]

# fallback order from the taxonomy's own sentence, after its colon, in order of appearance
fb_tail = tax["domains"]["fallback"].split(":", 1)[1]
fb_order = sorted([d for d in domains if re.search(r"\b%s\b" % d, fb_tail)],
                  key=lambda d: re.search(r"\b%s\b" % d, fb_tail).start())

def route_domain(job, dom):
    if dom in routing[job]:
        return dom
    for d in [dom] + fb_order:
        if d in routing[job]:
            return d
    raise SystemExit(f"job {job} routes nowhere")

def derive_domain(kind, role, labels, jl):
    for row in tax["domains"]["rule"]:
        w = row["when"]
        if w == "otherwise" or match(w, kind, role, labels, jl):
            return row["domain"]

def match(w, kind, role, labels, jl):
    if "anyOf" in w:
        return any(match(x, kind, role, labels, jl) for x in w["anyOf"])
    if "repoKind" in w:
        return kind in w["repoKind"]
    if "repoRole" in w:
        return role in w["repoRole"]
    if "issueLabels" in w:
        for pat in w["issueLabels"]["any"]:
            for l in labels:
                if l == pat or (pat.startswith("*:") and l.endswith(pat[1:])):
                    return True
        return False
    if "jobs" in w:
        j = w["jobs"]
        if "anyKey" in j:
            return any(x in jl for x in j["anyKey"])
        if j.get("nonEmpty"):
            only = j["everyListsOnly"]
            return bool(jl) and all(set(job_by_key[x]["phases"]) == {only} for x in jl)
    raise SystemExit(f"unknown predicate {w}")

def actionable(a):
    return a if not aliases[a].get("reviewer") else None

FORCE = {"aigov": ("process", None, []), "library": ("library", None, []),
         "maintenance": ("product", None, ["bug"]), "feature": ("product", None, []),
         "parity": ("product", None, [])}

def reach(k, d):
    """The job list that puts job k in domain d under FORCE[d], or None when no issue can."""
    kind, role, labels = FORCE[d]
    jl = [k] if d != "parity" or k == "parity" else ["parity", k]
    if derive_domain(kind, role, labels, jl) == d:
        return jl
    comp = next(x["key"] for x in jobs if x["key"] != k and len(routing[x["key"]]) == len(domains))
    jl = jl + [comp]
    return jl if derive_domain(kind, role, labels, jl) == d else None

def resolve(ex):
    dom = derive_domain(ex["kind"], ex["role"], ex["labels"], ex["job"])
    ls = [l for l in ex["lang"] if l != "prose"] or ["*"]
    pairs = []
    for j in ex["job"]:
        d = route_domain(j, dom)
        for l in ls:
            pairs.append((j, l, d, cell_for(j, d, l)))
    tally = {}
    for _, _, _, c in pairs:
        a = c["winner"]["alias"] if not aliases[c["winner"]["alias"]].get("reviewer") else c["winner"].get("also")
        if a:
            tally[a] = tally.get(a, 0) + 1
    rank = sorted(tally, key=lambda a: (-tally[a], precedence.index(a)))
    winner = rank[0]
    if len(rank) > 1:
        runner = rank[1]
    else:
        rt = {}
        for _, _, _, c in pairs:
            r = c["runnerUp"]
            a = r["alias"] if not aliases[r["alias"]].get("reviewer") else r.get("also")
            if a and a != winner:
                rt[a] = rt.get(a, 0) + 1
        runner = sorted(rt, key=lambda a: (-rt[a], precedence.index(a)))[0] if rt else None
    w = max(job_by_key[j]["weight"] for j in ex["job"])
    adds = []
    if len(ex["job"]) >= 3: adds.append("three or more jobs")
    if sum(1 for l in ex["lang"] if code_lang.get(l, True)) >= 2: adds.append("two or more code languages")
    if dom == "aigov": adds.append("aigov domain")
    return {"domain": dom, "pairs": pairs, "winner": winner, "runner": runner,
            "weight": w, "adds": adds, "effort": band(w + len(adds))}

def restart(alias, level):
    a = aliases[alias]
    line = surfaces[a["surface"]]["restart"]
    dial = surface_map[a["surface"]][level]
    return line.replace("<alias>", typed(alias) or "<alias>").replace("<level>", dial), dial

# ---- render --------------------------------------------------------------------------------------
def render():
    o = []
    w = o.append
    n_routes = sum(len(v) for v in routing.values())
    n_cells = sum(len(r["cells"]) for v in routing.values() for r in v.values())
    w("# Direct — the model matrix")
    w("")
    w("<!-- GENERATED by scripts/direct_matrix_doc.sh from contracts/direct.registry.json, "
      "contracts/classify.taxonomy.json and nen/workflow.json -> models. Do not edit by hand: "
      "change the data, then run `bash scripts/direct_matrix_doc.sh --write`. -->")
    w("")
    w("> **Which model will `hatsu:direct` pick for my work — without running it?** Find the issue's job "
      "in [the grid](#the-grid--every-job-in-every-domain), read across to its domain, and that is the "
      "model, the surface it runs on and what you type. Everything on this page is rendered from the same "
      "data `nen direct resolve` reads, and `--verify` checks every cell against the verb itself.")
    w("")
    w(f"Snapshot **{snap['asOf']}** · {len(jobs)} jobs · {len(domains)} domains · {n_routes} job × "
      f"domain routes · {n_cells} cells · source digest `{reg['source']['documentSha256'][:12]}…` · "
      f"skills: [`classify`](../claude/skills/classify/SKILL.md), [`direct`](../claude/skills/direct/SKILL.md)")
    w("")
    w("## Contents")
    w("")
    for t, a in [("How a recommendation is made", "how-a-recommendation-is-made"),
                 ("The models — ten aliases", "the-models--ten-aliases"),
                 ("The grid — every job in every domain", "the-grid--every-job-in-every-domain"),
                 ("Which domain am I in?", "which-domain-am-i-in"),
                 ("Job × language — one matrix per domain", "job--language--one-matrix-per-domain"),
                 ("How hard — the effort rule", "how-hard--the-effort-rule"),
                 ("Several jobs or languages on one issue", "several-jobs-or-languages-on-one-issue"),
                 ("Worked examples", "worked-examples"),
                 ("Surfaces, restart lines and interactive equivalents", "surfaces-restart-lines-and-interactive-equivalents"),
                 ("Where the version comes from", "where-the-version-comes-from"),
                 ("Keeping this page true", "keeping-this-page-true")]:
        w(f"- [{t}](#{a})")
    w("")

    # how
    w("## How a recommendation is made")
    w("")
    w("```")
    w("issue labels ──► lang/<key> + job/<key>        (hatsu:classify writes them)")
    w("repo kind/role + issue labels + jobs ──► domain (first matching rule wins)")
    w("(job, domain, language) ──► routing cell       (winner + runner-up, each an ALIAS)")
    w("alias ──► provider · model family · surface · tier ──► the name you type")
    w("job weights + counts + domain ──► effort       (low | medium | high | max)")
    w("```")
    w("")
    w("1. **Two labels decide it.** `lang/` is what the work is written in (`" + "`, `".join(lang_keys) +
      "`); `job/` is the kind of work (39 keys, below). `hatsu:classify` applies them; `direct` only reads them.")
    w("2. **The domain is derived, never labelled** — from the repository's kind and role, the issue's "
      "`bug` label and its jobs ([rules](#which-domain-am-i-in)).")
    w("3. **One cell per (job, language).** Every cell names a *winner* and a *runner-up* alias. A language "
      "column only exists where that language is routed differently; otherwise the shared `*` cell applies "
      "(and `prose` always reads `*`).")
    w("4. **An alias is stable; a version is not.** The alias names a provider, a model family and the Hatsu "
      "surface it runs on. The name you type comes from `nen/workflow.json` → `models.<surface>.<tier>`; the "
      "newest version is read live when `direct` runs, with the dated snapshot below as the fallback.")
    w("5. **No `job/` label, no recommendation** — " + reg["emptyAxis"]["job"].split(":")[0] +
      ": `direct` says so in one line and `build` continues on the current session.")
    w("")

    # models
    w("## The models — ten aliases")
    w("")
    w(f"Model versions are the snapshot of **{snap['asOf']}**; `direct` reports the newest live version of the "
      "same family when it can read one. *You type* is Hatsu's own `models` spelling — a consumer repository "
      "may spell a tier differently in its own `nen/workflow.json`.")
    w("")
    w("| | Alias | Provider | Family | Surface | You type | Model (snapshot) | If unavailable | What it is for |")
    w("|---|---|---|---|---|---|---|---|---|")
    for name in precedence:
        a = aliases[name]
        s = snap["aliases"][name]
        dot = "🔍" if a.get("reviewer") else DOT.get(a["provider"], "⚪")
        surf = surfaces[a["surface"]]["label"] if a.get("surface") else "PR review bot"
        t = typed(name)
        tt = f"`{t}` (tier `{a['tier']}`)" if t else "—"
        mid = f" `{s['modelId']}`" if s.get("modelId") else ""
        w(f"| {dot} | `{name}` | {a['provider']} | `{a['family']}` | {surf} | {tt} | **{s['primary']}**{mid} | "
          f"{s['fallback']} | {a['selection']} |")
    w("")
    w("Legend: 🟠 Anthropic · 🟢 OpenAI · 🔵 Google · ⚫ Cursor · 🔍 a PR review bot — never a session "
      "recommendation; where one wins a cell, the actionable alias after its arrow is what you run. "
      f"Row order is the tie-break `precedence`. `SEMANTIC_MAX` may be recommended for **your own** session, "
      "never for a subagent.")
    w("")

    # grid
    w("## The grid — every job in every domain")
    w("")
    w("The **winner** of each job's own cell — for every language, unless a language is named beneath it "
      "with its own winner. *↪ italics* means the job has no phase in that domain and borrows the route of "
      "the domain named. *—* means no issue can put that job in that domain (`job/parity` in a product "
      "repository always derives the parity domain). *Effort alone* is that job's level by itself "
      "(one more step in AI governance). Runner-ups are in "
      "[the job × language matrices](#job--language--one-matrix-per-domain).")
    w("")
    key = []
    for name in precedence:
        a = aliases[name]
        if a.get("reviewer"):
            continue
        key.append(f"{label(name)} **{snap['aliases'][name]['primary']}** on {surfaces[a['surface']]['label']}")
    w("**Key** — " + " · ".join(key))
    w("")
    hdr = "| Job | " + " | ".join(DOMAIN_SHORT.get(d, d) for d in domains) + " | Weight | Effort alone |"
    w(hdr)
    w("|" + "---|" * (len(domains) + 3))
    for j in jobs:
        k = j["key"]
        row = [f"**`{k}`**<br><sub>{j['title']}</sub>"]
        for d in domains:
            if reach(k, d) is None:
                row.append("—")
                continue
            rd = route_domain(k, d)
            r = routing[k][rd]
            c = r["cells"]["*"]["winner"]
            txt = cell_text(c)
            if rd != d:
                txt = f"*↪ {DOMAIN_SHORT.get(rd, rd).lower()}: {txt}*"
            for l, x in winner_diffs(r):
                txt += f"<br><sub>{LANG_NAME.get(l, l)}: {cell_text(x)}</sub>"
            row.append(txt)
        wt = j["weight"]
        e1, e2 = band(wt), band(wt + 1)
        eff = e1 if e1 == e2 else f"{e1} · {e2} in AI-gov"
        row += [str(wt), eff]
        w("| " + " | ".join(row) + " |")
    w("")

    # domains
    w("## Which domain am I in?")
    w("")
    w("Rules are checked in order; **the first match wins**.")
    w("")
    w("| # | Domain | When |")
    w("|---|---|---|")
    for r in tax["domains"]["rule"]:
        w(f"| {r['order']} | **{DOMAIN_NAME.get(r['domain'], r['domain'])}** (`{r['domain']}`) | {r['$comment']} |")
    w("")
    w("*Hatsu and nen themselves are process / canon repositories, so work on them is always **AI governance**.* "
      "When a job has no phase in the derived domain, it routes on the first domain it does list, in this "
      "order: the derived domain, then " + ", ".join(fb_order) + " — and `direct` names the substitution.")
    w("")

    # per-domain job x language matrices
    w("## Job × language — one matrix per domain")
    w("")
    w("The registry's routing is keyed **(job, domain, language)**: the source document's five tables, one per "
      "domain, each varying by language. Pick your domain, find your job's row, read your language's column. "
      "Each cell is that pair's **winner**, then its runner-up, then the interactive tool the source prefers "
      "where it names one. A **bold** winner is routed for that language specifically, unlike the shared "
      "cell. A row in *↪ italics* has no phase in this domain and borrows the route of the domain named — "
      "you meet it when the issue's other jobs put it in this domain. `prose` always reads the shared cell.")
    w("")
    for d in domains:
        w(f"### {DOMAIN_NAME.get(d, d)} (`{d}` · `{tax['domains']['tablePrefix'][d]}`)")
        w("")
        w("| Job | Phase | " + " | ".join(LANG_NAME.get(l, l) for l in lang_keys) + " |")
        w("|---|---|" + "---|" * len(lang_keys))
        for j in jobs:
            k = j["key"]
            if reach(k, d) is None:
                continue  # no issue can put this job in this domain
            rd = route_domain(k, d)
            r = routing[k][rd]
            star = r["cells"]["*"]
            ph = f"`{r['phase']}` {r['phaseName']}"
            if r.get("alsoPhases"):
                ph += "<br><sub>also " + ", ".join(f"`{p}`" for p in r["alsoPhases"]) + "</sub>"
            jc = f"`{k}`"
            if rd != d:
                jc = f"*`{k}`<br>↪ {DOMAIN_SHORT.get(rd, rd).lower()}*"
                ph = f"*{ph}*"
            cols = []
            for l in lang_keys:
                c = r["cells"].get(l) if l != "prose" else None
                c = c or star
                win = cell_text(c["winner"])
                if not same_alias(c["winner"], star["winner"]):
                    win = f"**{win}**"
                s_ = win + f"<br><sub>runner-up {cell_text(c['runnerUp'])}</sub>"
                extra = []
                for x in (c["winner"], c["runnerUp"]):
                    for f in ("interactive", "note"):
                        if x.get(f) and x[f] not in extra:
                            extra.append(x[f])
                if extra:
                    s_ += "<br><sub><i>" + " · ".join(extra) + "</i></sub>"
                cols.append(s_)
            w(f"| {jc} | {ph} | " + " | ".join(cols) + " |")
        w("")

    # effort
    w("## How hard — the effort rule")
    w("")
    rule = reg["effort"]["rule"]
    w("**score = the highest job weight**, plus one for each of:")
    w("")
    for p in rule["plusOne"]:
        w(f"- {p['when']}")
    w("")
    w("| Score | Effort |")
    w("|---|---|")
    for lvl in reg["effort"]["levels"]:
        lo, hi = bands[lvl]
        rng = f"≤ {hi}" if lo == 0 else (f"≥ {lo}" if hi >= 99 else (str(lo) if lo == hi else f"{lo}–{hi}"))
        w(f"| {rng} | **{lvl}** |")
    w("")
    w("Job weights:")
    w("")
    w("| Weight | Jobs |")
    w("|---|---|")
    for wt in sorted({j["weight"] for j in jobs}, reverse=True):
        w(f"| {wt} | " + ", ".join(f"`{j['key']}`" for j in jobs if j["weight"] == wt) + " |")
    w("")
    w("How each surface spells the level (`effort.surfaceMap`):")
    w("")
    sk = [s for s in surface_map if not s.startswith("$")]
    w("| Level | " + " | ".join(surfaces[s]["label"] for s in sk) + " |")
    w("|---|" + "---|" * len(sk))
    for lvl in reg["effort"]["levels"]:
        w(f"| {lvl} | " + " | ".join(f"`{surface_map[s][lvl]}`" for s in sk) + " |")
    w("")
    w("Cursor and Antigravity have no top setting, so `max` reads `high` there — and a session already at "
      "`high` on them counts as matching.")
    w("")

    # aggregation
    w("## Several jobs or languages on one issue")
    w("")
    w("Every (job, language) pair gets its own cell; one recommendation comes out:")
    w("")
    w("1. **Winner** — the alias that wins the most pairs; a tie goes to the earlier alias in this order: " +
      " › ".join(f"`{a}`" for a in precedence) + ".")
    w("2. A review bot never wins: a pair it wins counts for the actionable alias after its arrow.")
    w("3. **Runner-up** — the alias with the next-most wins; if the winner won every pair, the most frequent "
      "runner-up across those pairs (same tie-break). If nothing else is left, *runner-up: none distinct*.")
    w("4. `prose` and an empty `lang/` read the shared `*` cell; `prose` never counts as a code language for effort.")
    w("")

    # examples
    w("## Worked examples")
    w("")
    w("Each is checked against `nen direct resolve` by `--verify`.")
    w("")
    w("| Work | Labels | Domain | Winner | Runner-up | Effort | Restart line |")
    w("|---|---|---|---|---|---|---|")
    for ex in EXAMPLES:
        r = resolve(ex)
        lbl = " ".join(f"`lang/{l}`" for l in ex["lang"]) + " " + " ".join(f"`job/{j}`" for j in ex["job"])
        if ex["labels"]:
            lbl += " " + " ".join(f"`{l}`" for l in ex["labels"])
        ctx = f"<br><sub>repo kind `{ex['kind']}`</sub>"
        why = f"weight {r['weight']}" + "".join(f" + {a}" for a in r["adds"])
        line, _ = restart(r["winner"], r["effort"])
        ru = label(r["runner"], surface=True) if r["runner"] else "none distinct"
        w(f"| {ex['title']}{ctx} | {lbl} | {DOMAIN_SHORT.get(r['domain'], r['domain'])} | "
          f"{label(r['winner'], surface=True)} | {ru} | **{r['effort']}**<br><sub>{why}</sub> | `{line}` |")
    w("")

    # surfaces
    w("## Surfaces, restart lines and interactive equivalents")
    w("")
    w("The actionable recommendation is always one of Hatsu's four surfaces. `direct` fills `<alias>` from "
      "`models` and `<level>` from the effort map — never a version.")
    w("")
    w("| Surface | Restart line | Effort control | Model lookup | Interactive twin |")
    w("|---|---|---|---|---|")
    for s, v in surfaces.items():
        if s.startswith("$"):
            continue
        w(f"| **{v['label']}** | `{v['restart']}` | {v['effortControl']} | {v['lookup']} | {v['interactive']} |")
    w("")
    w("Native IDE equivalents by language (offered beside the winner as the *interactive* row):")
    w("")
    w("| Language | Native interactive option |")
    w("|---|---|")
    for l, v in reg["nativeInteractive"].items():
        w(f"| {LANG_NAME.get(l, l)} | {v} |")
    w("")

    # versions
    w("## Where the version comes from")
    w("")
    w("At run time `direct` reads the newest version of the recommended family — the surface's own lookup "
      "first, then the provider's model page, quoted with its URL and date. Only when neither can be read does "
      f"it quote the snapshot above, **with its date ({snap['asOf']})**.")
    w("")
    w("| Provider | Surface lookup | Model pages |")
    w("|---|---|---|")
    for p, v in reg["liveLookup"].items():
        if p.startswith("$"):
            continue
        w(f"| {p} | {v['cli'] or '—'} | " + "<br>".join(v["docs"]) + " |")
    w("")

    # sync
    w("## Keeping this page true")
    w("")
    w("```bash")
    w("bash scripts/direct_matrix_doc.sh --write    # re-render after any registry, taxonomy or models edit")
    w("bash scripts/direct_matrix_doc.sh --check    # exit 1 when this page is stale")
    w("bash scripts/direct_matrix_doc.sh --verify   # every cell, fallback and example against nen direct resolve")
    w("```")
    w("")
    w("A routing change is a registry edit through a PR, never an edit here; changing what an alias **means** "
      "is a maintainer ruling ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-04 — classify and direct*).")
    return "\n".join(o) + "\n"

# ---- verify --------------------------------------------------------------------------------------
def nen(kind, role, labels, lang, job):
    cmd = ["nen", "direct", "resolve", "--registry", REG_PATH, "--taxonomy", TAX_PATH, "--repo", root,
           "--kind", kind, "--job", ",".join(job), "--json"]
    if role: cmd += ["--role", role]
    if labels: cmd += ["--labels", ",".join(labels)]
    if lang: cmd += ["--lang", ",".join(lang)]
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=root)
    if p.returncode != 0:
        raise SystemExit(f"nen direct resolve failed ({' '.join(cmd)}): {p.stderr.strip()}")
    return json.loads(p.stdout)

def verify():
    checked = 0
    bad = []
    for j in jobs:
        k = j["key"]
        for d in domains:
            kind, role, labels = FORCE[d]
            jl = reach(k, d)
            if jl is None:
                continue  # no issue reaches this pair; the page renders it as unreachable
            rd = route_domain(k, d)
            for l in lang_keys:
                out = nen(kind, role, labels, [l], jl)
                if out["domain"]["domain"] != d:
                    bad.append(f"{k}/{d}/{l}: nen derived domain {out['domain']['domain']}")
                    continue
                pair = next(p for p in out["pairs"] if p["job"] == k)
                want = cell_for(k, rd, "*" if l == "prose" else l)
                for role_ in ("winner", "runnerUp"):
                    # a review bot's cell is rendered "bot → also"; the verb reports the actionable also
                    acc = {want[role_]["alias"], want[role_].get("also")} - {None}
                    if pair[role_]["alias"] not in acc:
                        bad.append(f"{k}/{d}/{l} {role_}: page {want[role_]['alias']} · nen {pair[role_]['alias']}")
                if pair["domain"] != rd:
                    bad.append(f"{k}/{d}/{l}: page routes on {rd} · nen on {pair['domain']}")
                checked += 1
    for ex in EXAMPLES:
        r = resolve(ex)
        out = nen(ex["kind"], ex["role"], ex["labels"], ex["lang"], ex["job"])
        got = (out["domain"]["domain"], out["winner"]["alias"],
               (out.get("runnerUp") or {}).get("alias"), out["effort"]["level"])
        want = (r["domain"], r["winner"], r["runner"], r["effort"])
        if got != want:
            bad.append(f"example '{ex['title']}': page {want} · nen {got}")
        line, _ = restart(r["winner"], r["effort"])
        if out["winner"]["restart"] != line:
            bad.append(f"example '{ex['title']}' restart: page {line!r} · nen {out['winner']['restart']!r}")
        checked += 1
    if bad:
        print("direct_matrix_doc --verify: %d disagreement(s) of %d checks" % (len(bad), checked), file=sys.stderr)
        for b in bad:
            print("  " + b, file=sys.stderr)
        sys.exit(1)
    print(f"direct_matrix_doc --verify: {checked} checks agree with nen direct resolve")

if mode == "verify":
    verify()
    sys.exit(0)
page = render()
target = os.path.join(root, OUT_PATH)
if mode == "print":
    sys.stdout.write(page)
elif mode == "write":
    with open(target, "w", encoding="utf-8") as f:
        f.write(page)
    print(f"wrote {OUT_PATH}")
elif mode == "check":
    cur = open(target, encoding="utf-8").read() if os.path.exists(target) else ""
    if cur != page:
        print(f"{OUT_PATH} is stale: run bash scripts/direct_matrix_doc.sh --write", file=sys.stderr)
        sys.exit(1)
    print(f"{OUT_PATH} is current")
PY
