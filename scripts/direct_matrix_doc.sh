#!/usr/bin/env bash
# direct_matrix_doc.sh — render the model matrix hatsu:direct resolves from, as a page a person reads.
#
#   bash scripts/direct_matrix_doc.sh [--write | --check | --verify | --self-test] [repo-root]
#
#   (none)       print the rendered page to stdout
#   --write      write it to docs/DIRECT-MATRIX.md (atomically: a temp file, then a rename)
#   --check      exit 1 when docs/DIRECT-MATRIX.md is missing or differs from what the data renders
#   --verify     ask `nen direct resolve` about EVERY CLAIM THE PAGE PRINTS — each matrix cell, each
#                grid cell, each "Effort alone" level, each unreachable "—", each worked example — and
#                exit 1 on any disagreement. Needs nen at contracts' pin (NEN=<path> overrides `nen`).
#   --self-test  hermetic fixtures under a temp dir: --check fails on a stale, missing or mutated page,
#                malformed data refuses by name, the re-implemented rules hold at their edges, the
#                registry's own invariants hold over every cell (the fallback rule, every alias's line
#                and escalation, every companion job routed); then --check on the real tree. This is
#                the direct-matrix-guard lane's argv.
#
#   exit 0 ok · 1 stale page or a disagreement · 2 usage, unreadable data or a refused rule shape
#
# WHY A GENERATOR. hatsu:direct never decides in prose: `nen direct resolve` reads
# contracts/direct.registry.json, contracts/classify.taxonomy.json and the consumer's
# nen/workflow.json -> models, and answers. A hand-written table of the same answers would be a second
# copy that rots the first time a cell moves. This page is RENDERED from those three files, so the page
# and the verb cannot disagree unless the page is stale (--check) or the renderer reads the data
# differently than the verb does (--verify, which checks what the page PRINTS, not what this file meant).
#
# WHAT IS PRESENTATION, WHAT IS DATA, AND WHAT IS RESIDUE. Provider dots, domain display names, the
# worked-example inputs and the "How a recommendation is made" walkthrough are presentation, written
# here. Every alias, surface, tier, typed name, routing cell, weight, band, count and every rule sentence
# (domain rows, fallback, aggregation, the collapsed effort dial) is read from the data. RESIDUE: to
# render offline this file re-implements domain derivation, the fallback order (parsed from the
# taxonomy's fallback sentence after its colon, exactly as `nen direct --help` documents the verb doing),
# aggregation and effort banding. --verify holds every printed result of that re-implementation to the
# verb; a matrix/explain mode of `nen direct` would retire it.
#
# It follows scripts/config_values.sh's house shape: a thin bash wrapper over one embedded python3
# program.
set -euo pipefail

mode=""
root=""
for arg in "$@"; do
  case "$arg" in
    --write|--check|--verify|--self-test)
      if [ -n "$mode" ]; then echo "direct_matrix_doc: one mode at a time (got --$mode and $arg)" >&2; exit 2; fi
      mode="${arg#--}" ;;
    -h|--help) sed -n '2,35p' "$0"; exit 0 ;;
    -*) echo "direct_matrix_doc: unknown flag $arg" >&2; exit 2 ;;
    *)
      if [ -n "$root" ]; then echo "direct_matrix_doc: one repo-root at a time (got $root and $arg)" >&2; exit 2; fi
      root="$arg" ;;
  esac
done
[ -n "$mode" ] || mode=print
if [ -z "$root" ]; then
  root="$(cd "$(dirname "$0")/.." && pwd)"
else
  given="$root"
  root="$(cd "$given" 2>/dev/null && pwd)" || { echo "direct_matrix_doc: repo-root $given is not a directory" >&2; exit 2; }
fi
script="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

exec python3 - "$mode" "$root" "$script" <<'PY'
import json, os, re, shutil, subprocess, sys, tempfile

mode, root, SCRIPT = sys.argv[1], sys.argv[2], sys.argv[3]
REG_PATH = "contracts/direct.registry.json"
TAX_PATH = "contracts/classify.taxonomy.json"
WF_PATH = "nen/workflow.json"
CONTRACT_PATH = "nen/contract.json"
OUT_PATH = "docs/DIRECT-MATRIX.md"

def refuse(msg):
    print(f"direct_matrix_doc: {msg}", file=sys.stderr)
    sys.exit(2)

def load(p):
    try:
        with open(os.path.join(root, p), encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        refuse(f"{p}: {e}")

reg, tax, wf = load(REG_PATH), load(TAX_PATH), load(WF_PATH)
try:
    aliases, surfaces, routing = reg["aliases"], reg["surfaces"], reg["routing"]
    snap = reg["snapshot"]
    models = wf.get("models", {})
    jobs = tax["axes"]["job"]["keys"]
    langs = tax["axes"]["lang"]["keys"]
    domains = tax["domains"]["keys"]
    rules = sorted(tax["domains"]["rule"], key=lambda r: r["order"])
    precedence = reg["aggregation"]["precedence"]
    bands = reg["effort"]["rule"]["bands"]
    levels = reg["effort"]["levels"]
    surface_map = reg["effort"]["surfaceMap"]
    picks = reg["picks"]
    companions = reg["companions"]
    non_actionable = reg["surfaces"].get("$nonActionable", {})
    live_lookup = reg["liveLookup"]
except (KeyError, TypeError) as e:
    refuse(f"a key the renderer needs is missing: {e}")
job_by_key = {j["key"]: j for j in jobs}
lang_keys = [l["key"] for l in langs]
code_lang = {l["key"]: l.get("code", True) is not False for l in langs}
surface_keys = [s for s in surfaces if not s.startswith("$")]
companion_jobs = [j["key"] for j in jobs if j.get("companion") is True]
actionable = [a for a in precedence if not aliases[a].get("reviewer")]
escalations = [a for a in actionable if aliases[a]["tier"] == "frontier"]
for j in jobs:
    if j["key"] not in routing:
        refuse(f"job '{j['key']}' has no routing row in {REG_PATH}")

# ---- presentation only --------------------------------------------------------------------------
DOT = {"anthropic": "🟠", "openai": "🟢", "google": "🔵", "cursor": "⚫"}
PROVIDER_NAME = {"anthropic": "Anthropic", "openai": "OpenAI", "google": "Google", "cursor": "Cursor"}
DOMAIN_NAME = {"feature": "Feature development", "maintenance": "Maintenance & operations",
               "parity": "Cross-platform parity", "aigov": "AI governance", "library": "Reusable library"}
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
    {"title": "A TypeScript library change and its docs",
     "kind": "library", "role": None, "labels": [], "lang": ["typescript", "prose"],
     "job": ["implementation", "documentation"]},
    {"title": "Porting a screen from Swift to Kotlin",
     "kind": "product", "role": None, "labels": [], "lang": ["swift", "kotlin"],
     "job": ["parity", "ui"]},
    {"title": "A repository-wide mechanical rename in C#",
     "kind": "product", "role": None, "labels": [], "lang": ["csharp"], "job": ["mechanical-edit"]},
    {"title": "A React component and its unit tests",
     "kind": "product", "role": None, "labels": [], "lang": ["typescript"], "job": ["ui", "unit-tests"]},
    {"title": "A security threat model for a Swift feature",
     "kind": "product", "role": None, "labels": [], "lang": ["swift"], "job": ["security"]},
]
# the facts that put an issue in each domain, for the grid, the matrices and --verify
FORCE = {"aigov": ("process", None, []), "library": ("library", None, []),
         "maintenance": ("product", None, ["bug"]), "feature": ("product", None, []),
         "parity": ("product", None, [])}
# -------------------------------------------------------------------------------------------------

def esc(x):
    """A data string bound for a table cell: GFM splits cells on | even inside a code span."""
    return str(x).replace("|", "\\|")

def dname(d): return DOMAIN_NAME.get(d, d)
def dshort(d): return DOMAIN_SHORT.get(d, d)
def lname(l): return LANG_NAME.get(l, l)

def slug(heading):
    """GitHub's heading anchor: lowercase, drop what is not a word character, space or hyphen."""
    return re.sub(r"[^\w\- ]", "", heading.lower()).replace(" ", "-")

def typed(alias):
    a = aliases[alias]
    if a.get("surface") is None:
        return None
    return models.get(surfaces[a["surface"]]["modelsKey"], {}).get(a["tier"])

def label(alias, surface=False):
    a = aliases[alias]
    if a.get("reviewer"):
        return f"🔍 {snap['aliases'][alias]['primary']}"
    s = f"{DOT.get(a['provider'], '⚪')} `{typed(alias) or 'unspelled'}`"
    if surface:
        s += f" · {surfaces[a['surface']]['label']}"
    return s

def cell_text(c, surface=False):
    s = label(c["alias"], surface)
    if c.get("also"):
        s += f" → {label(c['also'], surface)}"
    return s

def effective(c):
    """The actionable alias a cell resolves to: a review bot's cell resolves to its `also`."""
    return c.get("also") if aliases[c["alias"]].get("reviewer") else c["alias"]

def same_alias(x, y):
    return x.get("alias") == y.get("alias") and x.get("also") == y.get("also")

def band(score):
    for lvl in levels:
        lo, hi = bands[lvl]
        if lo <= score <= hi:
            return lvl
    refuse(f"effort score {score} falls in no band of effort.rule.bands")

def cell_for(job, dom, lang):
    cells = routing[job][dom]["cells"]
    return cells.get(lang) or cells["*"]

# The fallback order, read from the taxonomy's sentence after its colon in order of appearance --
# `nen direct --help`: "in the order the taxonomy's fallback sentence names them after its colon".
_fb = tax["domains"].get("fallback", "")
if ":" not in _fb:
    refuse("domains.fallback has no colon to read the order after")
_fb_tail = _fb.split(":", 1)[1]
fb_order = sorted([d for d in domains if re.search(r"\b%s\b" % d, _fb_tail)],
                  key=lambda d: re.search(r"\b%s\b" % d, _fb_tail).start())

def route_domain(job, dom):
    for d in [dom] + fb_order:
        if d in routing[job]:
            return d
    refuse(f"job {job} routes in no domain of the fallback order")

PREDICATES = {"anyOf", "repoKind", "repoRole", "issueLabels", "jobs"}

def match(w, kind, role, labels, jl):
    keys = set(w) - {"$comment"}
    if len(keys) != 1 or not keys <= PREDICATES:
        refuse(f"domain rule predicate {sorted(keys)} is not one known shape")
    (k,) = keys
    if k == "anyOf":
        return any(match(x, kind, role, labels, jl) for x in w["anyOf"])
    if k == "repoKind":
        return kind in w["repoKind"]
    if k == "repoRole":
        return role in w["repoRole"]
    if k == "issueLabels":
        for pat in w["issueLabels"]["any"]:
            for l in labels:
                if l == pat:
                    return True
                # '*:name' matches '<ns>:name' with a non-empty namespace
                if pat.startswith("*:") and l.endswith(pat[1:]) and len(l) > len(pat) - 1:
                    return True
        return False
    j = w["jobs"]
    if "anyKey" in j:
        return any(x in jl for x in j["anyKey"])
    if j.get("nonEmpty"):
        only = j["everyListsOnly"]
        return bool(jl) and all(set(job_by_key[x]["phases"]) == {only} for x in jl)
    refuse(f"jobs predicate {sorted(j)} is not one known shape")

def derive_domain(kind, role, labels, jl):
    for row in rules:
        if row["when"] == "otherwise" or match(row["when"], kind, role, labels, jl):
            return row["domain"]
    refuse("no domain rule matched and the taxonomy names no 'otherwise' row")

_full = [x["key"] for x in jobs if len(routing[x["key"]]) == len(domains)]

def reach(k, d):
    """The job list that puts job k in domain d under FORCE[d], or None when no issue can."""
    kind, role, labels = FORCE[d]
    jl = [k] if d != "parity" or k == "parity" else ["parity", k]
    if derive_domain(kind, role, labels, jl) == d:
        return jl
    comp = next((x for x in _full if x != k), None)
    if comp is None:
        refuse("no job routes in every domain, so a companion job cannot be chosen")
    jl = jl + [comp]
    return jl if derive_domain(kind, role, labels, jl) == d else None

def unreach_inputs(k, d):
    kind, role, labels = FORCE[d]
    base = [k] if d != "parity" or k == "parity" else ["parity", k]
    return [base] + [base + [c] for c in _full if c != k][:1]

def resolve(ex):
    if not ex["job"]:
        return {"undirectable": True}
    dom = derive_domain(ex["kind"], ex["role"], ex["labels"], ex["job"])
    ls = []
    for l in ex["lang"] or ["prose"]:
        l = "*" if l == "prose" else l
        if l not in ls:
            ls.append(l)
    pairs = []
    for j in ex["job"]:
        d = route_domain(j, dom)
        for l in ls:
            pairs.append(cell_for(j, d, l))
    winner, runner = aggregate(pairs)
    w = max(job_by_key[j]["weight"] for j in ex["job"])
    adds = []
    if len(ex["job"]) >= 3: adds.append("three or more jobs")
    if sum(1 for l in ex["lang"] if code_lang.get(l, True)) >= 2: adds.append("two or more code languages")
    if dom == "aigov": adds.append("aigov domain")
    level = band(w + len(adds))
    return {"undirectable": False, "domain": dom, "winner": winner, "runner": runner,
            "weight": w, "adds": adds, "effort": level, "recommended": recommended(winner, w, level),
            "aggFallback": agg_fallback(pairs, winner, runner)}

def aggregate(pairs):
    """aggregation.$comment, as the verb applies it: the winner by winner positions, the runner-up by the
    next-highest winner count, else the winner's pairs' most frequent runner-up; None when none is distinct."""
    tally = {}
    for c in pairs:
        a = effective(c["winner"])
        if a:
            tally[a] = tally.get(a, 0) + 1
    rank = sorted(tally, key=lambda a: (-tally[a], precedence.index(a)))
    winner = rank[0]
    if len(rank) > 1:
        return winner, rank[1]
    rt = {}
    for c in pairs:
        a = effective(c["runnerUp"])
        if a and a != winner:
            rt[a] = rt.get(a, 0) + 1
    return winner, (sorted(rt, key=lambda a: (-rt[a], precedence.index(a)))[0] if rt else None)

def same_pool(a, b):
    return aliases[a]["provider"] == aliases[b]["provider"] and aliases[a]["surface"] == aliases[b]["surface"]

def agg_fallback(pairs, winner, runner):
    """picks.fallback at the aggregate: the verb's runner-up when it sits in another pool than the primary,
    else the highest-precedence other-pool alias among the pairs' winners and runner-ups (None when none)."""
    if runner and not same_pool(winner, runner):
        return runner
    pool = {effective(c[k]) for c in pairs for k in ("winner", "runnerUp")}
    others = [a for a in pool if a and not same_pool(winner, a)]
    return min(others, key=precedence.index) if others else None

def recommended(primary, max_weight, level):
    """picks.recommended: the primary's escalation on a weight-4 job or a max effort, else the primary."""
    esc = aliases[primary].get("escalation")
    return esc if esc and (max_weight == 4 or level == "max") else primary

def fallback_ok(c):
    """picks.fallbackRule: the actionable fallback sits on another provider or another surface."""
    return not same_pool(effective(c["winner"]), effective(c["runnerUp"]))

def price(alias):
    lp = snap["aliases"][alias].get("listPrice")
    return f"${lp['input']:g} / ${lp['output']:g}" if lp else "—"

def restart(alias, level):
    a = aliases[alias]
    dial = surface_map[a["surface"]][level]
    return surfaces[a["surface"]]["restart"].replace("<alias>", typed(alias) or "<alias>").replace("<level>", dial)

# ---- render --------------------------------------------------------------------------------------
def render():
    """The page, and every claim it prints -- recorded from the same values that were formatted."""
    o, claims = [], []
    w = o.append
    n_routes = sum(len(v) for v in routing.values())
    n_cells = sum(len(r["cells"]) for v in routing.values() for r in v.values())
    H = {
        "how": "How a recommendation is made",
        "models": f"The models — {len(precedence)} aliases",
        "picks": "Primary, fallback, recommended — the three picks",
        "grid": "The grid — every job in every domain",
        "domain": "Which domain am I in?",
        "matrix": "Job × language — one matrix per domain",
        "effort": "How hard — the effort rule",
        "agg": "Several jobs or languages on one issue",
        "examples": "Worked examples",
        "surfaces": "Surfaces, restart lines and interactive equivalents",
        "versions": "Where the version comes from",
        "sync": "Keeping this page true",
    }
    w("# Direct — the model matrix")
    w("")
    w("<!-- GENERATED by scripts/direct_matrix_doc.sh from contracts/direct.registry.json, "
      "contracts/classify.taxonomy.json and nen/workflow.json -> models. Do not edit by hand: "
      "change the data, then run `bash scripts/direct_matrix_doc.sh --write`. -->")
    w("")
    w(f"> **Which model will `hatsu:direct` pick for my work — without running it?** Find the issue's job "
      f"in [the grid](#{slug(H['grid'])}), read across to its domain, and that is the model, the surface it "
      f"runs on and what you type. The tables and rule text on this page are rendered from the same data "
      f"`nen direct resolve` reads, and `--verify` asks the verb about every cell, level and example printed here.")
    w("")
    w(f"Snapshot **{snap['asOf']}** · {len(jobs)} jobs · {len(domains)} domains · {n_routes} job × "
      f"domain routes · {n_cells} cells · source digest `{reg['source']['documentSha256'][:12]}…` · "
      f"skills: [`classify`](../claude/skills/classify/SKILL.md), [`direct`](../claude/skills/direct/SKILL.md)")
    w("")
    w("## Contents")
    w("")
    for h in H.values():
        w(f"- [{h}](#{slug(h)})")
    w("")

    # how -- the one hand-written walkthrough
    w(f"## {H['how']}")
    w("")
    w("```")
    w("issue labels ──► lang/<key> + job/<key>        (hatsu:classify writes them)")
    w("repo kind/role + issue labels + jobs ──► domain (first matching rule wins)")
    w("(job, domain, language) ──► routing cell       (winner + runner-up, each an ALIAS)")
    w("alias ──► provider · model family · surface · tier ──► the name you type")
    w("job weights + counts + domain ──► effort       (" + " | ".join(levels) + ")")
    w("```")
    w("")
    w("1. **Two labels decide it.** `lang/` is what the work is written in (`" + "`, `".join(lang_keys) +
      f"`); `job/` is the kind of work ({len(jobs)} keys, below). `hatsu:classify` applies them; `direct` only reads them.")
    w(f"2. **The domain is derived, never labelled** — from the repository's kind and role, the issue's "
      f"labels and its jobs ([rules](#{slug(H['domain'])})).")
    w("3. **One cell per (job, language), three picks.** Every cell names a *winner* — the **primary**, the "
      "cost-aligned best — and a *runner-up* — the **fallback**, on another provider or surface; the "
      f"**recommended** (cost-agnostic) pick follows by rule ([the three picks](#{slug(H['picks'])})). A language "
      "column only exists in the data where that language is routed differently; otherwise the shared `*` "
      "cell applies (and `prose` always reads `*`).")
    w("4. **An alias is stable; a version is not.** The alias names a provider, a model line, a model family, "
      "the Hatsu surface it runs on and its tier. The name you type comes from `nen/workflow.json` → "
      "`models.<modelsKey>.<tier>` (`claude`, `codex`, `cursor`, `antigravity`); the newest version and the "
      "effort dial are read live when `direct` runs, with the dated snapshot below as the fallback.")
    w("5. **No `job/` label, no recommendation** — `emptyAxis.job`: *" + reg["emptyAxis"]["job"] + "*")
    w("")
    w("*This walkthrough is a hand-written summary; every section below it is rendered from the data.*")
    w("")

    # models
    w(f"## {H['models']}")
    w("")
    w(f"Model versions are the snapshot of **{snap['asOf']}**; `direct` reports the newest live version of the "
      "same family when it can read one. *You type* is Hatsu's own `models` spelling — a consumer repository "
      "may spell a tier differently in its own `nen/workflow.json`.")
    w("")
    w("| | Alias | Provider · line | Family | Surface | You type | Escalation | List price in / out | Model (snapshot) | If unavailable | What it is for |")
    w("|---|---|---|---|---|---|---|---|---|---|---|")
    for name in precedence:
        a = aliases[name]
        s = snap["aliases"][name]
        dot = "🔍" if a.get("reviewer") else DOT.get(a["provider"], "⚪")
        surf = surfaces[a["surface"]]["label"] if a.get("surface") else "PR review bot"
        t = typed(name)
        tt = f"`{t}` (tier `{a['tier']}`)" if t else "—"
        mid = f" `{s['modelId']}`" if s.get("modelId") else ""
        line = f"{a['provider']} · `{a['line']}`" if a.get("line") else a["provider"]
        up = f"`{a['escalation']}`" if a.get("escalation") else ("*(a frontier alias)*" if a.get("tier") == "frontier" else "—")
        w(f"| {dot} | `{name}` | {line} | `{a['family']}` | {surf} | {tt} | {up} | {price(name)} | **{esc(s['primary'])}**{mid} | "
          f"{esc(s['fallback'])} | {esc(a['selection'])} |")
    w("")
    providers = []
    for name in precedence:
        p = aliases[name]["provider"]
        if not aliases[name].get("reviewer") and p not in providers:
            providers.append(p)
    w("Legend: " + " · ".join(f"{DOT.get(p, '⚪')} {PROVIDER_NAME.get(p, p)}" for p in providers) +
      " · 🔍 a PR review bot — never a session recommendation; where one wins a cell, the actionable alias "
      "after its arrow is what you run. Row order is the tie-break `precedence`. List prices are the snapshot "
      f"of **{snap['asOf']}** in USD per million tokens, each row's source in the registry — evidence for the "
      "cost-aligned ordering, never today's price. The frontier aliases (" + ", ".join(f"`{a}`" for a in escalations) +
      ") are reached only as the *recommended* pick, for **your own** session, never for a subagent.")
    w("")
    served = [(n, snap["aliases"][n]["served"]) for n in actionable if snap["aliases"][n].get("served")]
    if served:
        w(f"What each surface's own lookup served on {snap['asOf']} (the alias you type resolves to this id, which may lag the provider's newest):")
        w("")
        w("| Alias | Surface | Served id |")
        w("|---|---|---|")
        for n, sv in served:
            for sk, txt in sv.items():
                w(f"| `{n}` | {surfaces[sk]['label']} | {esc(txt)} |")
        w("")

    # picks
    w(f"## {H['picks']}")
    w("")
    w(f"> {picks['$comment']}")
    w("")
    w("| Pick | What it is | Where it comes from |")
    w("|---|---|---|")
    w(f"| **primary** | {esc(picks['primary'])} | the cell's `winner`, `nen direct resolve`'s winner |")
    w(f"| **fallback** | {esc(picks['fallback'])} | the cell's `runnerUp`, the verb's runner-up |")
    w(f"| **recommended** | {esc(picks['recommended']['describe'])} | {esc(picks['recommended']['rule'])} |")
    w("")
    w(f"`picks.fallbackRule`: *{esc(picks['fallbackRule'])}*")
    w("")
    w("What each primary escalates to when the rule fires:")
    w("")
    w("| Primary | Recommended on a weight-4 job or a `max` effort |")
    w("|---|---|")
    for a in actionable:
        up = aliases[a].get("escalation")
        w(f"| {label(a, surface=True)} | " + (label(up, surface=True) if up else "itself — nothing above it") + " |")
    w("")
    w(f"`picks.tiers`: *{esc(picks['tiers'])}*")
    w("")
    w("**Companion jobs** (`companion: true` in the taxonomy): " + ", ".join(f"`{j}`" for j in companion_jobs) +
      f". {esc(companions['$comment'])}")
    w("")
    w("| Companion job | Runs on the primary's surface at |")
    w("|---|---|")
    for j, role in companions["role"].items():
        tier = models.get("roles", {}).get(role)
        w(f"| `{j}` | `models.roles.{role}`" + (f" → tier `{tier}`" if tier else "") + " |")
    w("")

    # grid
    w(f"## {H['grid']}")
    w("")
    w("The **winner** of each job's own cell — for every language, unless a language is named beneath it "
      "with its own winner. *↪ italics* means the job has no phase in that domain and borrows the route of "
      f"the domain named. *—* means no issue can put that job in that domain: the [domain rules](#{slug(H['domain'])}) "
      "decide before the job does. *Effort alone* is that job's level when it is the issue's only job "
      "(and in AI governance, where the domain adds one). Runner-ups are in "
      f"[the job × language matrices](#{slug(H['matrix'])}).")
    w("")
    key = [f"{label(n)} **{snap['aliases'][n]['primary']}** on {surfaces[aliases[n]['surface']]['label']}"
           for n in precedence if not aliases[n].get("reviewer")]
    w("**Key** — " + " · ".join(key))
    w("")
    w("| Job | " + " | ".join(dshort(d) for d in domains) + " | Weight | Effort alone |")
    w("|" + "---|" * (len(domains) + 3))
    aigov_add = any(p.get("key") == "aigov" for p in reg["effort"]["rule"]["plusOne"])
    for j in jobs:
        k = j["key"]
        row = [f"**`{k}`**<br><sub>{esc(j['title'])}</sub>"]
        for d in domains:
            if reach(k, d) is None:
                row.append("—")
                claims.append({"t": "unreachable", "job": k, "d": d})
                continue
            rd = route_domain(k, d)
            r = routing[k][rd]
            star_w = r["cells"]["*"]["winner"]
            txt = cell_text(star_w)
            if rd != d:
                txt = f"*↪ {dshort(rd).lower()}: {txt}*"
            for l in lang_keys:
                shown = star_w
                lc = r["cells"].get(l) if l != "prose" else None
                if lc and not same_alias(lc["winner"], star_w):
                    shown = lc["winner"]
                    txt += f"<br><sub>{lname(l)}: {cell_text(shown)}</sub>"
                claims.append({"t": "grid", "job": k, "d": d, "lang": l, "routed": rd,
                               "winner": effective(shown)})
            row.append(txt)
        wt = j["weight"]
        e1 = band(wt)
        e2 = band(wt + 1) if aigov_add else e1
        claims.append({"t": "effort", "job": k, "aigov": False, "level": e1})
        claims.append({"t": "effort", "job": k, "aigov": True, "level": e2})
        row += [str(wt), e1 if e1 == e2 else f"{e1} · {e2} in AI-gov"]
        w("| " + " | ".join(row) + " |")
    w("")

    # domains
    w(f"## {H['domain']}")
    w("")
    w("Rules are checked in `order`; **the first match wins** (`domains.rule`).")
    w("")
    w("| # | Domain | When |")
    w("|---|---|---|")
    for r in rules:
        w(f"| {r['order']} | **{dname(r['domain'])}** (`{r['domain']}`) | {esc(r['$comment'])} |")
    w("")
    w(f"`domains.fallback`: *{tax['domains']['fallback']}*")
    w("")

    # per-domain job x language matrices
    w(f"## {H['matrix']}")
    w("")
    w(f"The registry's routing is keyed **(job, domain, language)** — {len(domains)} tables, one per domain, "
      "each varying by language. Pick your domain, find your job's row, read your language's column. "
      "Each cell is that pair's **winner**, then its runner-up, then the interactive tool the source prefers "
      "where it names one. A **bold** winner is routed for that language specifically, unlike the shared "
      "cell. A row in *↪ italics* has no phase in this domain and borrows the route of the domain named — "
      "you meet it when the issue's other jobs put it in this domain. `prose` always reads the shared cell.")
    w("")
    for d in domains:
        w(f"### {dname(d)} (`{d}` · `{tax['domains']['tablePrefix'][d]}`)")
        w("")
        w("| Job | Phase | " + " | ".join(lname(l) for l in lang_keys) + " |")
        w("|---|---|" + "---|" * len(lang_keys))
        for j in jobs:
            k = j["key"]
            if reach(k, d) is None:
                continue  # no issue can put this job in this domain; the grid prints "—"
            rd = route_domain(k, d)
            r = routing[k][rd]
            star = r["cells"]["*"]
            ph = f"`{r['phase']}` {esc(r['phaseName'])}"
            if r.get("alsoPhases"):
                ph += "<br><sub>also " + ", ".join(f"`{p}`" for p in r["alsoPhases"]) + "</sub>"
            jc = f"`{k}`"
            if rd != d:
                jc = f"*`{k}`<br>↪ {dshort(rd).lower()}*"
                ph = f"*{ph}*"
            cols = []
            for l in lang_keys:
                c = (r["cells"].get(l) if l != "prose" else None) or star
                wn, ru = c["winner"], c["runnerUp"]
                win = cell_text(wn)
                if not same_alias(wn, star["winner"]):
                    win = f"**{win}**"
                s_ = win + f"<br><sub>runner-up {cell_text(ru)}</sub>"
                extra = []
                for x in (wn, ru):
                    for f in ("interactive", "note"):
                        if x.get(f) and x[f] not in extra:
                            extra.append(x[f])
                if extra:
                    s_ += "<br><sub><i>" + " · ".join(esc(x) for x in extra) + "</i></sub>"
                cols.append(s_)
                claims.append({"t": "cell", "job": k, "d": d, "lang": l, "routed": rd, "phase": r["phase"],
                               "winner": effective(wn), "runnerUp": effective(ru), "extra": extra})
            w(f"| {jc} | {ph} | " + " | ".join(cols) + " |")
        w("")

    # effort
    w(f"## {H['effort']}")
    w("")
    rule = reg["effort"]["rule"]
    w(f"**score = the {rule['base']}**, plus one for each of:")
    w("")
    for p in rule["plusOne"]:
        w(f"- {p['when']}")
    w("")
    w("| Score | Effort |")
    w("|---|---|")
    for lvl in levels:
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
    for lvl in levels:
        w(f"| {lvl} | " + " | ".join(f"`{surface_map[s][lvl]}`" for s in sk) + " |")
    w("")
    if surface_map.get("$collapsed"):
        w(f"`effort.surfaceMap.$collapsed`: *{surface_map['$collapsed']}*")
        w("")

    # aggregation -- the registry's own rule text, quoted
    w(f"## {H['agg']}")
    w("")
    w("Every (job, language) pair gets its own cell; one recommendation comes out. The rule, as "
      "`aggregation.$comment` states it:")
    w("")
    w(f"> {reg['aggregation']['$comment']}")
    w("")
    w("`precedence`, earliest first: " + " › ".join(f"`{a}`" for a in precedence) + ".")
    w("")
    w("Where no other alias is left the verb returns no runner-up, and `direct` reports it as "
      "*fallback: none distinct* ([`direct`](../claude/skills/direct/SKILL.md) § 5). Where the verb's runner-up "
      "shares the primary's provider and surface, the aggregate fallback is the highest-precedence alias in another "
      "pool among the pairs' winners and runner-ups, named beside it (`picks.fallback`; zheref/nen#389).")
    w("")

    # examples
    w(f"## {H['examples']}")
    w("")
    w("Domain, primary, the verb's runner-up, effort and restart line are checked against `nen direct resolve` by "
      "`--verify`; the recommended column and the aggregate fallback are this page's reading of `picks.recommended` "
      "and `picks.fallback`, which the verb does not compute yet (zheref/nen#389).")
    w("")
    w("| Work | Labels | Domain | Primary | Fallback | Recommended | Effort | Restart line |")
    w("|---|---|---|---|---|---|---|---|")
    for ex in EXAMPLES:
        r = resolve(ex)
        lbl = " ".join(f"`lang/{l}`" for l in ex["lang"]) + " " + " ".join(f"`job/{j}`" for j in ex["job"])
        if ex["labels"]:
            lbl += " " + " ".join(f"`{l}`" for l in ex["labels"])
        why = f"weight {r['weight']}" + "".join(f" + {a}" for a in r["adds"])
        line = restart(r["winner"], r["effort"])
        ru = label(r["runner"], surface=True) if r["runner"] else "none distinct"
        if r["aggFallback"] and r["aggFallback"] != r["runner"]:
            ru += f"<br><sub>verb's runner-up, same pool · aggregate fallback {label(r['aggFallback'], surface=True)}</sub>"
        rec = "the primary" if r["recommended"] == r["winner"] else label(r["recommended"], surface=True)
        w(f"| {ex['title']}<br><sub>repo kind `{ex['kind']}`</sub> | {lbl} | {dshort(r['domain'])} | "
          f"{label(r['winner'], surface=True)} | {ru} | {rec} | **{r['effort']}**<br><sub>{why}</sub> | `{line}` |")
        claims.append({"t": "example", "ex": ex, "domain": r["domain"], "winner": r["winner"],
                       "runnerUp": r["runner"], "effort": r["effort"], "restart": line})
    w("")

    # surfaces
    w(f"## {H['surfaces']}")
    w("")
    w(f"The actionable recommendation is always one of Hatsu's {len(surface_keys)} surfaces. `direct` fills "
      "`<alias>` from `models` and `<level>` from the effort map — never a version.")
    w("")
    w("| Surface | Restart line | Effort control | Model lookup | Interactive twin |")
    w("|---|---|---|---|---|")
    for s in surface_keys:
        v = surfaces[s]
        w(f"| **{esc(v['label'])}** | `{esc(v['restart'])}` | {esc(v['effortControl'])} | {esc(v['lookup'])} | {esc(v['interactive'])} |")
    w("")
    na = [(k, v) for k, v in non_actionable.items() if not k.startswith("$")]
    if na:
        w("Surfaces `direct` knows of and never recommends as actionable (`surfaces.$nonActionable`): " +
          esc(non_actionable.get("$comment", "")))
        w("")
        w("| Surface | Provider | What it is | Lookup |")
        w("|---|---|---|---|")
        for k, v in na:
            w(f"| **{esc(v['label'])}** (`{k}`) | {esc(v.get('provider', '—'))} | {esc(v['what'])} | {esc(v['lookup'])} |")
        w("")
    w("Native IDE equivalents by language (offered beside the winner as the *interactive* row):")
    w("")
    w("| Language | Native interactive option |")
    w("|---|---|")
    for l, v in reg["nativeInteractive"].items():
        if not l.startswith("$"):
            w(f"| {lname(l)} | {esc(v)} |")
    w("")

    # versions
    w(f"## {H['versions']}")
    w("")
    w("At run time `direct` reads the newest version of each pick's family and the effort dial its surface "
      "offers — the surface's own lookup first, then the provider's model page, quoted with its URL and date. "
      f"Only when neither can be read does it quote the snapshot above, **with its date ({snap['asOf']})**, "
      "and the effort map's dial.")
    w("")
    w("| Provider | Surface lookup | Effort dial, read live | Model pages |")
    w("|---|---|---|---|")
    for p, v in live_lookup.items():
        if not p.startswith("$"):
            w(f"| {p} | {esc(v['cli'] or '—')} | {esc(v.get('effort') or 'no dial')} | " + "<br>".join(esc(x) for x in v["docs"]) + " |")
    w("")

    # sync
    w(f"## {H['sync']}")
    w("")
    w("```bash")
    w("bash scripts/direct_matrix_doc.sh --write      # re-render after any registry, taxonomy or models edit")
    w("bash scripts/direct_matrix_doc.sh --check      # exit 1 when this page is stale (lane direct-matrix-guard)")
    w("bash scripts/direct_matrix_doc.sh --verify     # every printed cell, level and example against nen direct resolve")
    w("bash scripts/direct_matrix_doc.sh --self-test  # the guard's own fixtures, then --check")
    w("```")
    w("")
    w("Agreement with the verb is proved when `--verify` runs; staleness is caught when the lane runs. Neither "
      "runs on its own in CI yet (zheref/hatsu#234). A routing change is a registry edit through a PR, never an edit here; "
      "changing what an alias **means** is a maintainer ruling ([`ROSTER.md`](ROSTER.md) § *Rulings of "
      "2026-10-04 — classify and direct*).")
    return "\n".join(o) + "\n", claims

# ---- verify --------------------------------------------------------------------------------------
NEN = os.environ.get("NEN", "nen")
_cache = {}

def nen(kind, role, labels, lang, job):
    key = (kind, role, tuple(labels), tuple(lang), tuple(job))
    if key in _cache:
        return _cache[key]
    cmd = [NEN, "direct", "resolve", "--registry", REG_PATH, "--taxonomy", TAX_PATH, "--repo", root,
           "--kind", kind, "--job", ",".join(job), "--json"]
    if role: cmd += ["--role", role]
    if labels: cmd += ["--labels", ",".join(labels)]
    if lang: cmd += ["--lang", ",".join(lang)]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, cwd=root)
    except FileNotFoundError:
        refuse(f"--verify: '{NEN}' not found (set NEN=<path> or put nen on PATH)")
    if p.returncode != 0:
        refuse(f"--verify: nen direct resolve failed ({' '.join(cmd)}): {p.stderr.strip()}")
    _cache[key] = json.loads(p.stdout)
    return _cache[key]

def check_pin():
    pin = load(CONTRACT_PATH)["dependency"]["pinned_ref"].lstrip("v")
    try:
        got = subprocess.run([NEN, "--version"], capture_output=True, text=True).stdout.strip()
    except FileNotFoundError:
        refuse(f"--verify: '{NEN}' not found (set NEN=<path> or put nen on PATH)")
    if got != pin:
        refuse(f"--verify: {NEN} --version reads '{got}', the contract pins '{pin}'")
    return got

def verify():
    version = check_pin()
    _, claims = render()
    bad = []
    def pair_of(k, d, l):
        kind, role, labels = FORCE[d]
        out = nen(kind, role, labels, [l], reach(k, d))
        return out, next((p for p in out["pairs"] if p["job"] == k), None)
    for c in claims:
        t = c["t"]
        if t in ("cell", "grid"):
            out, pair = pair_of(c["job"], c["d"], c["lang"])
            where = f"{t} {c['job']}/{c['d']}/{c['lang']}"
            if out["domain"]["domain"] != c["d"] or pair is None:
                bad.append(f"{where}: nen derived {out['domain']['domain']}")
                continue
            if pair["domain"] != c["routed"]:
                bad.append(f"{where}: page routes on {c['routed']} · nen on {pair['domain']}")
            if pair["winner"]["alias"] != c["winner"]:
                bad.append(f"{where} winner: page {c['winner']} · nen {pair['winner']['alias']}")
            if t == "cell":
                if pair["runnerUp"]["alias"] != c["runnerUp"]:
                    bad.append(f"{where} runner-up: page {c['runnerUp']} · nen {pair['runnerUp']['alias']}")
                if pair["phase"] != c["phase"]:
                    bad.append(f"{where} phase: page {c['phase']} · nen {pair['phase']}")
                theirs = []
                for x in (pair["winner"], pair["runnerUp"]):
                    for f in ("interactive", "note"):
                        if x.get(f) and x[f] not in theirs:
                            theirs.append(x[f])
                if theirs != c["extra"]:
                    bad.append(f"{where} interactive/note: page {c['extra']} · nen {theirs}")
        elif t == "unreachable":
            kind, role, labels = FORCE[c["d"]]
            for jl in unreach_inputs(c["job"], c["d"]):
                got = nen(kind, role, labels, ["prose"], jl)["domain"]["domain"]
                if got == c["d"]:
                    bad.append(f"unreachable {c['job']}/{c['d']}: nen derives {got} for jobs {jl}")
        elif t == "effort":
            kind, role, labels = FORCE["aigov"] if c["aigov"] else FORCE["maintenance"]
            got = nen(kind, role, labels, ["prose"], [c["job"]])["effort"]["level"]
            if got != c["level"]:
                bad.append(f"effort alone {c['job']} (aigov={c['aigov']}): page {c['level']} · nen {got}")
        elif t == "example":
            ex = c["ex"]
            out = nen(ex["kind"], ex["role"], ex["labels"], ex["lang"], ex["job"])
            got = (out["domain"]["domain"], out["winner"]["alias"],
                   (out.get("runnerUp") or {}).get("alias"), out["effort"]["level"], out["winner"]["restart"])
            want = (c["domain"], c["winner"], c["runnerUp"], c["effort"], c["restart"])
            if got != want:
                bad.append(f"example '{ex['title']}': page {want} · nen {got}")
    if bad:
        print(f"direct_matrix_doc --verify: {len(bad)} disagreement(s) of {len(claims)} printed claims "
              f"(nen {version})", file=sys.stderr)
        for b in bad:
            print("  " + b, file=sys.stderr)
        sys.exit(1)
    kinds = {}
    for c in claims:
        kinds[c["t"]] = kinds.get(c["t"], 0) + 1
    print(f"direct_matrix_doc --verify: {len(claims)} printed claims agree with nen direct resolve {version} "
          f"({', '.join(f'{v} {k}' for k, v in kinds.items())}; {len(_cache)} resolves)")

# ---- self-test -----------------------------------------------------------------------------------
def self_test():
    fails = []
    def ok(cond, what):
        print(("  ok    " if cond else "  FAIL  ") + what)
        if not cond:
            fails.append(what)
    def run(*args, r):
        p = subprocess.run(["bash", SCRIPT, *args, r], capture_output=True, text=True)
        return p.returncode, p.stdout + p.stderr
    tmp = tempfile.mkdtemp(prefix="direct-matrix-selftest.")
    try:
        for p in (REG_PATH, TAX_PATH, WF_PATH):
            os.makedirs(os.path.join(tmp, os.path.dirname(p)), exist_ok=True)
            shutil.copy(os.path.join(root, p), os.path.join(tmp, p))
        os.makedirs(os.path.join(tmp, "docs"), exist_ok=True)
        page = os.path.join(tmp, OUT_PATH)
        def edit(path, fn):
            full = os.path.join(tmp, path)
            with open(full, encoding="utf-8") as f:
                d = json.load(f)
            fn(d)
            with open(full, "w", encoding="utf-8") as f:
                json.dump(d, f)
        print("fixtures under a temp dir:")
        rc, _ = run("--check", r=tmp); ok(rc == 1, "--check exits 1 when the page is missing")
        rc, _ = run("--write", r=tmp); ok(rc == 0 and os.path.exists(page), "--write writes the page")
        rc, _ = run("--check", r=tmp); ok(rc == 0, "--check exits 0 on a fresh page")
        with open(page, "a", encoding="utf-8") as f:
            f.write("x\n")
        rc, _ = run("--check", r=tmp); ok(rc == 1, "--check exits 1 on a hand-edited page")
        run("--write", r=tmp)
        def move_cell(d):
            c = d["routing"]["bug-fix"]["maintenance"]["cells"]["*"]["winner"]
            c["alias"] = "EXECUTION_VALUE" if c["alias"] != "EXECUTION_VALUE" else "BALANCED_AUTHOR"
            c["surface"] = d["aliases"][c["alias"]]["surface"]
        edit(REG_PATH, move_cell)
        rc, _ = run("--check", r=tmp); ok(rc == 1, "--check exits 1 after one routing cell moves")
        shutil.copy(os.path.join(root, REG_PATH), os.path.join(tmp, REG_PATH))
        def add_job(d):
            j = dict(d["axes"]["job"]["keys"][0]); j["key"] = "zz-new-job"
            d["axes"]["job"]["keys"].append(j)
        edit(TAX_PATH, add_job)
        rc, out = run("--check", r=tmp); ok(rc == 2 and "zz-new-job" in out,
                                            "a job with no routing row refuses by name, exit 2")
        shutil.copy(os.path.join(root, TAX_PATH), os.path.join(tmp, TAX_PATH))
        def drop_otherwise(d):
            d["domains"]["rule"] = [r for r in d["domains"]["rule"] if r["when"] != "otherwise"]
        edit(TAX_PATH, drop_otherwise)
        rc, out = run("--check", r=tmp); ok(rc == 2 and "otherwise" in out,
                                            "no 'otherwise' domain row refuses by name, exit 2")
        shutil.copy(os.path.join(root, TAX_PATH), os.path.join(tmp, TAX_PATH))
        def gap_band(d):
            d["effort"]["rule"]["bands"]["medium"] = [9, 9]
        edit(REG_PATH, gap_band)
        rc, out = run("--check", r=tmp); ok(rc == 2 and "no band" in out, "an unbanded effort score refuses, exit 2")
        os.remove(os.path.join(tmp, REG_PATH))
        rc, out = run("--check", r=tmp); ok(rc == 2 and REG_PATH in out, "a missing registry refuses by name, exit 2")
        p = subprocess.run(["bash", SCRIPT, "--check", "--write", tmp], capture_output=True, text=True)
        ok(p.returncode == 2, "two modes at once are refused, exit 2")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("the re-implemented rules, at their edges (real data, in process):")
    pj = next(j["key"] for j in jobs if j["key"] != "parity")
    maint_only = next((j["key"] for j in jobs if set(j["phases"]) == {"maintenance"}), None)
    ok(derive_domain("process", None, [], [pj]) == "aigov", "kind process derives aigov")
    ok(derive_domain("product", "canon", [], [pj]) == "aigov", "role canon derives aigov")
    ok(derive_domain("library", None, ["bug"], ["parity"]) == "library", "kind library outranks bug and parity")
    ok(derive_domain("product", None, ["bug"], ["parity"]) == "parity", "job/parity outranks bug")
    ok(derive_domain("product", None, ["team:bug"], [pj]) == "maintenance", "'<ns>:bug' matches '*:bug'")
    ok(derive_domain("product", None, [":bug"], [pj]) != "maintenance", "':bug' (empty namespace) does not")
    ok(derive_domain("product", None, ["Bug"], ["architecture"]) == "feature", "'Bug' is not 'bug'")
    if maint_only:
        ok(derive_domain("product", None, [], [maint_only]) == "maintenance", "a maintenance-only job derives maintenance")
    ok(derive_domain("product", None, [], ["architecture"]) == "feature", "otherwise derives feature")
    ok([band(s) for s in range(0, 7)] == ["low", "low", "low", "medium", "high", "max", "max"], "effort bands at every edge")
    ok(resolve({"kind": "product", "role": None, "labels": [], "lang": [], "job": []})["undirectable"],
       "an empty job axis is undirectable")
    lib = {"kind": "library", "role": None, "labels": [], "lang": ["typescript", "prose"],
           "job": ["delivery-ops", "implementation"]}
    ok(resolve(lib)["runner"] == "SEMANTIC_FRONTIER", "prose beside a code language keeps its own pair")
    sec = {"kind": "library", "role": None, "labels": [], "lang": ["prose"], "job": ["security"]}
    ok(resolve(sec)["runner"] not in (None, resolve(sec)["winner"]),
       "a review bot's also never shares the winner's pool, so the fallback stays distinct (picks.fallbackRule)")
    same = [{"winner": {"alias": "SEMANTIC_FRONTIER"}, "runnerUp": {"alias": "SEMANTIC_FRONTIER"}}]
    ok(aggregate(same) == ("SEMANTIC_FRONTIER", None), "a runner-up equal to the winner leaves none distinct (fixture)")
    ok(agg_fallback(same, "SEMANTIC_FRONTIER", None) is None, "no other-pool alias among the pairs leaves no aggregate fallback (fixture)")
    mixed = [{"winner": {"alias": "BALANCED_AUTHOR"}, "runnerUp": {"alias": "EDITOR_FRONTIER"}},
             {"winner": {"alias": "SEMANTIC_FRONTIER"}, "runnerUp": {"alias": "EXECUTION_FRONTIER"}}]
    ok(aggregate(mixed) == ("SEMANTIC_FRONTIER", "BALANCED_AUTHOR") and agg_fallback(mixed, "SEMANTIC_FRONTIER", "BALANCED_AUTHOR") == "EXECUTION_FRONTIER",
       "a same-pool aggregate runner-up yields the highest-precedence other-pool alias as the fallback (fixture)")
    ok(all(not same_pool(r_["winner"], r_["aggFallback"]) for r_ in (resolve(e) for e in EXAMPLES) if r_["aggFallback"]),
       "every worked example's aggregate fallback sits in another pool than its primary")
    ok(effective({"alias": "PR_QUALITY_REVIEW", "also": "EXECUTION_FRONTIER"}) == "EXECUTION_FRONTIER",
       "a review bot's cell counts for its also")

    print("the registry's own invariants (picks, companions), over every cell:")
    broken = [f"{j}/{d}/{l}" for j, doms in routing.items() for d, r_ in doms.items() if not d.startswith("$")
              for l, c in r_["cells"].items() if not fallback_ok(c)]
    ok(not broken, f"picks.fallbackRule: every fallback is on another provider or surface{'' if not broken else ' (broken: ' + ', '.join(broken[:5]) + ')'}")
    ok(all(aliases[a].get("line") for a in actionable), "every actionable alias names its model line")
    ok(all(aliases[a].get("escalation") in (None,) or aliases[a]["escalation"] in actionable for a in actionable),
       "every escalation names an actionable alias or is null")
    TIERS = ["fast", "deep", "frontier"]
    ok(all(TIERS.index(aliases[aliases[a]["escalation"]]["tier"]) == TIERS.index(aliases[a]["tier"]) + 1
           and aliases[aliases[a]["escalation"]]["surface"] == aliases[a]["surface"]
           for a in actionable if aliases[a].get("escalation")),
       "every escalation climbs exactly one tier on the same surface")
    ok(all(aliases[a]["tier"] == "frontier" or any(aliases[b]["tier"] == TIERS[TIERS.index(aliases[a]["tier"]) + 1]
                                                   and aliases[b]["surface"] == aliases[a]["surface"] for b in actionable) is False
           for a in actionable if aliases[a].get("escalation") is None),
       "an alias with no escalation has no actionable alias one tier above it on its surface")
    ok(not any(c["winner"]["alias"] in escalations for doms in routing.values() for d, r_ in doms.items()
               if not d.startswith("$") for c in r_["cells"].values()),
       "no cell names a frontier alias as its primary (frontier is reached only as recommended)")
    ok(set(companions["role"]) == set(companion_jobs), "companions.role names exactly the taxonomy's companion jobs")
    ok(all(j in routing for j in companion_jobs), "every companion job still has its own routing row")
    ok(recommended("SEMANTIC_FRONTIER", 4, "high") == "SEMANTIC_MAX" and recommended("SEMANTIC_FRONTIER", 3, "high") == "SEMANTIC_FRONTIER"
       and recommended("BALANCED_AUTHOR", 2, "max") == "SEMANTIC_FRONTIER" and recommended("EDITOR_FRONTIER", 4, "max") == "EDITOR_FRONTIER",
       "picks.recommended at its edges: weight 4 or max climbs, else the primary; nothing above stays")
    ok(all(snap["aliases"][a].get("listPrice", {}).get("source") for a in actionable), "every actionable alias's list price cites its source")

    print("the committed page:")
    page_now, _ = render()
    def cells(line):
        return len(re.split(r"(?<!\\)\|", line.strip())) - 2
    ragged, hdr = [], None
    for n, line in enumerate(page_now.split("\n"), 1):
        if not line.startswith("|"):
            hdr = None
            continue
        if hdr is None:
            hdr = cells(line)
        elif cells(line) != hdr:
            ragged.append(n)
    ok(not ragged, f"every table row has its header's cell count{'' if not ragged else f' (ragged at lines {ragged[:5]})'}")
    cur = open(os.path.join(root, OUT_PATH), encoding="utf-8").read() if os.path.exists(os.path.join(root, OUT_PATH)) else None
    ok(cur == page_now, f"{OUT_PATH} is current")
    if fails:
        print(f"direct_matrix_doc --self-test: {len(fails)} failed", file=sys.stderr)
        sys.exit(1)
    print("direct_matrix_doc --self-test: all passed")

# ---- main ----------------------------------------------------------------------------------------
if mode == "verify":
    verify()
elif mode == "self-test":
    self_test()
else:
    page, _ = render()
    target = os.path.join(root, OUT_PATH)
    if mode == "print":
        sys.stdout.buffer.write(page.encode("utf-8"))
    elif mode == "write":
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(target), prefix=".direct-matrix.")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(page)
        os.replace(tmp, target)
        print(f"wrote {OUT_PATH}")
    elif mode == "check":
        if not os.path.exists(target):
            print(f"{OUT_PATH} is missing: run bash scripts/direct_matrix_doc.sh --write {root}", file=sys.stderr)
            sys.exit(1)
        if open(target, encoding="utf-8").read() != page:
            print(f"{OUT_PATH} is stale: run bash scripts/direct_matrix_doc.sh --write {root}", file=sys.stderr)
            sys.exit(1)
        print(f"{OUT_PATH} is current")
PY
