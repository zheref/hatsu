#!/usr/bin/env python3
"""HA#351 interim catalogue resolver/checker; retire at a released NN#448 pin."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def load(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ValueError(f"{path}: unreadable JSON: {exc}") from exc


def catalogue(root=ROOT):
    for rel in ("contracts", "contracts/pr-sections.json", "contracts/classify.taxonomy.json"):
        candidate = root / rel
        if candidate.is_symlink() or not candidate.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"{rel}: declaration escapes checkout or is a symlink")
    cat = load(root / "contracts/pr-sections.json")
    taxonomy = load(root / "contracts/classify.taxonomy.json")
    if cat.get("contract") != "hatsu.pr-sections/v1":
        raise ValueError("expected hatsu.pr-sections/v1")
    if not isinstance(cat.get("sections"), list) or not isinstance(cat.get("footer"), list):
        raise ValueError("sections and footer must be arrays")
    rows = cat["sections"] + cat["footer"]
    if not all(isinstance(row, dict) for row in rows):
        raise ValueError("every section must be an object")
    ids = [row.get("id") for row in rows]
    if not rows or any(not isinstance(i, str) or not i for i in ids) or len(set(ids)) != len(ids):
        raise ValueError("section ids must be nonempty and unique")
    if type(cat.get("max")) is not int or not 1 <= cat["max"] <= 7:
        raise ValueError("catalogue max must be an integer from 1 through 7")
    if type(cat.get("proseBudget")) is not int or cat["proseBudget"] < 1:
        raise ValueError("proseBudget must be positive")
    for row in rows:
        if type(row.get("level")) is not int or row["level"] not in (1, 2) or not isinstance(row.get("glyph"), str) or not row["glyph"]:
            raise ValueError(f"{row['id']}: invalid level/glyph")
        title = row.get("title")
        if not (isinstance(title, str) and title or isinstance(title, dict) and title and all(isinstance(v, str) and v for v in title.values())):
            raise ValueError(f"{row['id']}: missing title")
        if isinstance(title, dict) and set(title) != {"product", "library", "process", "unknown"}:
            raise ValueError(f"{row['id']}: kind titles must cover every repository kind")
        if row["level"] != (1 if row["id"] == "changes" else 2):
            raise ValueError(f"{row['id']}: changes alone is H1; every other block is H2")
        if row.get("when") not in (None, "evidence", "economics", "policy-hit"):
            raise ValueError(f"{row['id']}: unknown run fact")
        if "reserved" in row and type(row["reserved"]) is not bool:
            raise ValueError(f"{row['id']}: reserved must be boolean")
        template = root / row.get("template", "")
        if template.resolve().is_relative_to(root.resolve()) is False or not template.is_file():
            raise ValueError(f"{row['id']}: missing or escaping template")
    families = cat.get("families", {})
    precedence = cat.get("precedence", [])
    if set(precedence) != set(families) or len(precedence) != len(families):
        raise ValueError("precedence must list every family exactly once")
    jobs = [job for entries in families.values() for job in entries]
    known = [row["key"] for row in taxonomy["axes"]["job"]["keys"]]
    if len(set(jobs)) != len(jobs) or set(jobs) != set(known):
        raise ValueError(f"every taxonomy job must belong to exactly one family; missing {sorted(set(known)-set(jobs))}; unknown {sorted(set(jobs)-set(known))}")
    cells = {f"{kind}.{family}" for kind in ("product", "library", "process", "unknown") for family in families}
    if not isinstance(cat.get("variants"), dict) or set(cat["variants"]) != cells:
        raise ValueError("variants must declare exactly every kind/family cell")
    required = {"changes", "why", "verify"}
    readers = {row["id"] for row in cat["sections"]}
    for kind in ("product", "library", "process", "unknown"):
        for family in families:
            cell = f"{kind}.{family}"
            items = cat.get("variants", {}).get(cell)
            validate_cell(cat, cell, items, cat["max"])
            if not (required | ({"improves"} if family != "release" else set())).issubset(items) or items[0] != "changes":
                raise ValueError(f"{cell}: changes first and all always-required readers are owed")
            if any(i not in readers for i in items):
                raise ValueError(f"{cell}: unknown reader id")
    if not cat["footer"] or cat["footer"][-1]["id"] != "attribution":
        raise ValueError("attribution must be the final footer")
    return cat


def validate_cell(cat, cell, items, maximum):
    known = {row["id"] for row in cat["sections"]}
    if not isinstance(items, list) or not items or any(not isinstance(i, str) or i not in known for i in items):
        raise ValueError(f"{cell}: unknown or missing reader id")
    if len(set(items)) != len(items):
        raise ValueError(f"{cell}: repeated section id")
    if len(items) > maximum:
        raise ValueError(f"{cell}: {len(items)} readers exceed max {maximum}")


def defaults(cat):
    return {"max": cat["max"], "variants": cat["variants"]}


def options(cat):
    return {row["id"]: row["$comment"] for row in cat["sections"] + cat["footer"]}


def fold(cat, jobs):
    if not jobs:
        return "build"
    counts = {family: 0 for family in cat["precedence"]}
    for job in set(jobs):
        matches = [family for family, entries in cat["families"].items() if job in entries]
        if len(matches) != 1:
            raise ValueError(f"job {job!r} has no unique declared family")
        counts[matches[0]] += 1
    return max(cat["precedence"], key=lambda family: counts[family])


def pattern(row, kind):
    title = row["title"] if isinstance(row["title"], str) else row["title"][kind]
    # Patterns, rather than the checker, declare glyph tolerance.
    return {"name": row["id"], "pattern": "^ {0,3}" + "#" * row["level"] + r"[ \t]+(?:[^A-Za-z0-9#\r\n]+[ \t]*)?" + re.escape(title) + r"[ \t]*$"}


def policy_hit(repo):
    """Hatsu's own default path sets, from their declared home; no network."""
    declaration = repo / "contracts/pr-composition.json"
    if not declaration.is_file():
        return False
    sets = load(declaration).get("gateDerive", {})
    # A target's origin selects its own declared row, never another repo's.
    origin = subprocess.run(["git", "-C", str(repo), "remote", "get-url", "origin"], capture_output=True, text=True)
    if origin.returncode:
        return False
    slug = re.sub(r"\.git$", "", re.sub(r"^.*github\.com[:/]", "", origin.stdout.strip()))
    row = sets.get(slug, {})
    prefixes = row.get("policyPaths", []) + row.get("processPaths", [])
    workflow = repo / "nen/workflow.json"
    if workflow.is_symlink() or (repo / "nen").is_symlink():
        raise ValueError("workflow declaration escapes target checkout")
    document = load(workflow) if workflow.is_file() else {}
    if not isinstance(document, dict) or not isinstance(document.get("branch", {}), dict):
        raise ValueError("workflow and branch must be objects")
    base = document.get("branch", {}).get("base", "main")
    if not isinstance(base, str) or not base or base.startswith("-"):
        raise ValueError("branch.base must name a branch")
    changed = subprocess.run(["git", "-C", str(repo), "diff", "--name-only", "origin/" + base], capture_output=True, text=True)
    untracked = subprocess.run(["git", "-C", str(repo), "ls-files", "--others", "--exclude-standard"], capture_output=True, text=True)
    if changed.returncode or untracked.returncode:
        raise ValueError("cannot derive policy-hit from the target diff; pass --policy-hit with Mukai's result")
    return any(path == prefix.rstrip("/") or path.startswith(prefix.rstrip("/") + "/") for path in (changed.stdout + untracked.stdout).splitlines() for prefix in prefixes)


def resolve(cat, repo, kind, jobs, facts):
    family = fold(cat, jobs)
    if kind not in ("product", "library", "process", "unknown"):
        raise ValueError(f"unknown repository kind {kind!r}")
    config = {}
    workflow = repo / "nen/workflow.json"
    if workflow.exists():
        if workflow.is_symlink() or (repo / "nen").is_symlink() or not workflow.resolve().is_relative_to(repo.resolve()):
            raise ValueError("workflow declaration escapes target checkout")
        document = load(workflow)
        if not isinstance(document, dict) or not isinstance(document.get("pr", {}), dict):
            raise ValueError("workflow and pr must be objects")
        config = document.get("pr", {}).get("sections", {})
    if not isinstance(config, dict):
        raise ValueError("pr.sections must be an object")
    maximum = config.get("max", cat["max"])
    if type(maximum) is not int or not 1 <= maximum <= cat["max"]:
        raise ValueError(f"pr.sections.max must be from 1 through {cat['max']}")
    overrides = config.get("variants", {})
    if not isinstance(overrides, dict):
        raise ValueError("pr.sections.variants must be a cell map")
    for cell, items in overrides.items():
        if cell not in cat["variants"]:
            raise ValueError(f"unknown override cell {cell!r}")
        validate_cell(cat, cell, items, maximum)
        if items[0] != "changes" or not ({"why", "verify"} | ({"improves"} if not cell.endswith(".release") else set())).issubset(items):
            raise ValueError(f"{cell}: overrides retain changes first and mandatory readers")
    cell = f"{kind}.{family}"
    selected = overrides.get(cell, cat["variants"][cell])
    by_id = {row["id"]: row for row in cat["sections"]}
    readers = [by_id[i] for i in selected if not by_id[i].get("when") or by_id[i]["when"] in facts]
    if "economics" in facts and not any(row["id"] == "economics" for row in readers):
        readers.append(by_id["economics"])
    if len(readers) > maximum:
        raise ValueError(f"{cell}: {len(readers)} admitted readers exceed max {maximum}")
    footer = [row for row in cat["footer"] if not row.get("reserved", False)]
    return {"cell": cell, "max": maximum, "ids": [r["id"] for r in readers], "footer": [r["id"] for r in footer], "requirements": [pattern(row, kind) for row in readers + footer]}


def visible_lines(body):
    """Preserve physical lines. Comments and valid fenced code are blanked."""
    lines = body.replace("\r\n", "\n").replace("\r", "\n").lstrip("\ufeff").split("\n")
    visible, fence, comment = [], None, False
    for raw in lines:
        if fence:
            if re.fullmatch(r" {0,3}" + re.escape(fence[0]) + "{" + str(len(fence)) + r",}[ \t]*", raw):
                fence = None
            visible.append("")
            continue
        started = comment
        out, pos = "", 0
        while pos < len(raw):
            if comment:
                end = raw.find("-->", pos)
                if end < 0:
                    pos = len(raw)
                    continue
                comment, pos = False, end + 3
            else:
                start = raw.find("<!--", pos)
                if start < 0:
                    out += raw[pos:]
                    break
                out += raw[pos:start]
                comment, pos = True, start + 4
        if started or re.match(r" {0,3}<!--", raw):
            visible.append("")
            continue
        match = re.match(r" {0,3}(`{3,}|~{3,})(.*)$", out)
        if match and (match[1][0] != "`" or "`" not in match[2]):
            fence = match[1]
            visible.append("")
        else:
            visible.append(out)
    return visible


def check(cat, body, requirements, maximum):
    if type(maximum) is not int or not 1 <= maximum <= cat["max"]:
        raise ValueError("--max must be positive and within the catalogue cap")
    if not isinstance(requirements, list) or not requirements:
        raise ValueError("requirements must be a nonempty array")
    compiled = []
    for row in requirements:
        if not isinstance(row, dict) or not isinstance(row.get("name"), str) or not isinstance(row.get("pattern"), str):
            raise ValueError("requirements must contain name/pattern objects")
        compiled.append(re.compile(row["pattern"], re.I | re.M))
    lines = visible_lines(body)
    headings = [(i + 1, line) for i, line in enumerate(lines) if re.match(r" {0,3}#{1,2}(?:[ \t]+|$)", line)]
    # Setext headings also render as H1/H2; refuse them rather than admitting hidden sections.
    setext = [(i + 1, line) for i, line in enumerate(lines) if i > 0 and lines[i-1].strip()
              and re.fullmatch(r" {0,3}(?:=+|-+)[ \t]*", line)]
    findings, seen, previous, readers = [], set(), -1, 0
    for number, text in setext:
        findings.append(f"line {number}: undeclared setext heading: {lines[number-2]}")
    first = next((line for line in lines if line.strip()), "")
    if requirements[0]["name"] != "changes" or not compiled[0].search(first):
        findings.append("body must open with the changes H1 heading")
    footers = {row["id"] for row in cat["footer"]}
    for number, text in headings:
        matches = [i for i, regex in enumerate(compiled) if regex.search(text)]
        if len(matches) != 1:
            findings.append(f"line {number}: {'undeclared' if not matches else 'ambiguous'} heading {text}")
            continue
        at = matches[0]
        if at <= previous:
            findings.append(f"line {number}: out-of-order or repeated heading {text}")
        previous = max(at, previous)
        seen.add(at)
        if requirements[at]["name"] not in footers:
            readers += 1
            if readers == maximum + 1:
                findings.append(f"line {number}: reader count exceeds max {maximum}: {text}")
    for at, row in enumerate(requirements):
        if at not in seen:
            findings.append(f"missing heading {row['name']}")
    # Tables continue until blank/new block, including pipe-free omitted cells.
    table = set()
    def cells(line):
        return re.sub(r"^\||\|$", "", line.strip().replace(r"\|", "escaped-pipe")).split("|")
    for i in range(1, len(lines)):
        if ("|" in lines[i] or "|" in lines[i-1]) and len(cells(lines[i])) == len(cells(lines[i-1])) and all(re.fullmatch(r"\s*:?-+:?\s*", cell) for cell in cells(lines[i])):
            table.update((i - 1, i))
            for j in range(i + 1, len(lines)):
                if not lines[j].strip() or re.match(r" {0,3}(?:#|>|[-+*]\s|\d+[.)]\s|<)", lines[j]):
                    break
                table.add(j)
    warnings, title, words = [], "preamble", 0
    budget = cat["proseBudget"]
    for i, line in enumerate(lines + ["## end"]):
        heading = re.match(r" {0,3}#{1,2}(?:[ \t]+|$)(.*)", line)
        if heading:
            if words > budget:
                warnings.append(f"WARN {title}: {words} prose words (budget {budget})")
            title, words = heading[1], 0
        elif i not in table and not re.match(r" {4}|\t| {0,3}#{3,6}(?:\s|$)", line):
            words += len(re.findall(r"\w+(?:['’]\w+)*", re.sub(r"<[^>]*>", " ", line), re.UNICODE))
    return findings, warnings


def write_json(path, value):
    path = Path(path)
    if path.is_symlink():
        raise ValueError(f"output {path} is a symlink")
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=".pr-sections-")
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    p = sub.add_parser("resolve")
    p.add_argument("--repo", type=Path, required=True)
    p.add_argument("--kind", required=True)
    p.add_argument("--jobs", default="")
    for fact in ("evidence", "economics", "policy-hit"):
        p.add_argument("--" + fact, action="store_true")
    p.add_argument("--out", required=True)
    p = sub.add_parser("check")
    p.add_argument("--body", type=Path, required=True)
    p.add_argument("--requirements", type=Path, required=True)
    p.add_argument("--max", type=int, required=True)
    sub.add_parser("validate")
    args = parser.parse_args()
    try:
        cat = catalogue()
        if args.action == "validate":
            print(f"pr sections: {len(cat['variants'])} cells, every job owned once; catalogue valid")
            return 0
        if args.action == "resolve":
            jobs = [] if args.jobs == "" else args.jobs.split(",")
            facts = {fact for fact in ("evidence", "economics", "policy-hit") if getattr(args, fact.replace("-", "_"))}
            if args.kind == "process" and "policy-hit" not in facts and policy_hit(args.repo):
                facts.add("policy-hit")
            report = resolve(cat, args.repo, args.kind, jobs, facts)
            write_json(args.out, report["requirements"])
            print(" · ".join(report["ids"]))
        else:
            findings, warnings = check(cat, args.body.read_text(), load(args.requirements), args.max)
            for message in findings + warnings:
                print(message)
            if findings:
                return 1
            print("pr sections: exact order and reader cap satisfied")
        return 0
    except (ValueError, OSError, KeyError, TypeError, re.error) as exc:
        print(f"pr sections: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
