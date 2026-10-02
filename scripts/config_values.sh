#!/usr/bin/env bash
# config_values.sh — every value a consumer may set, written out and asked for.
#
# Hatsu owns this file and contracts/config-catalogue.json, the catalogue it reads. The maintainer's
# ruling of 2026-10-01 (docs/ROSTER.md § Rulings of 2026-10-01): a consumer's configuration files must
# show every optionally settable value at its default, with the allowed values beside each value whose
# domain is a fixed set, and a skill that needs a value nobody has set must guide the maintainer
# through setting it up instead of stopping. Tenkai (§ 6d) and every phase's warm-up (ten § 6, step
# 5b) call this engine, so the list of what is settable lives in one data file and is never counted in
# prose.
#
# It follows scripts/tenkai_adopt.sh's house shape: a thin bash wrapper over one embedded python3
# program, with a `--self-test` that builds real fixtures and proves both directions.
#
# WHAT IT WRITES, AND WHY THAT IS SAFE.
#
#   `fill` writes only two things into a declaration that ALREADY EXISTS: an absent key at the
#   catalogue's default, and a `$<key>` sibling annotation listing a fixed-set value's options.
#   Writing a key at the default its readers already apply changes no behaviour by construction, and
#   nen treats every `$`-prefixed key as metadata (zheref/nen src/schema/source.ts). It never creates a
#   declaration file (`nen scaffold init` owns that), never rewrites a value somebody set, never writes
#   a value without a default, and inserts text surgically, so the file's own formatting survives.
#
#   `set` writes ONE value the maintainer chose, by catalogue id, after the question was asked
#   (docs/WORKFLOW.md § 4 step 3). A fixed-set value outside its options is refused, and a
#   `secret-env` value must be an environment-variable NAME, never the secret.
#
# USAGE
#   scripts/config_values.sh diagnose --repo <path> [--domain <d>] [--json]
#   scripts/config_values.sh fill     --repo <path> [--json]
#   scripts/config_values.sh need     --repo <path> --skill <name> [--json]
#   scripts/config_values.sh set      --repo <path> --id <catalogue id> --value <JSON literal>
#   scripts/config_values.sh check-catalogue
#   scripts/config_values.sh --self-test
#
#   --hatsu-root <path>  where contracts/config-catalogue.json lives. Defaults to this script's own
#                        parent, so an installed plugin copy reads its own catalogue rather than one
#                        the target repository happens to carry.
#
# EXIT CODES
#   0  nothing outstanding (diagnose, fill), nothing this skill needs is missing (need), written (set)
#   1  work remains: a default unwritten, an annotation owed, a value invalid, or a value with no
#      default that a skill needs — NOT a crash, the honest answer to "is it configured"
#   2  an invocation or environment defect: no such repo, an unreadable catalogue, a refused value
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CONFIG_VALUES_DEFAULT_ROOT="$(dirname "$HERE")"

python3 - "$@" <<'PY'
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

CATALOGUE = Path("contracts") / "config-catalogue.json"
WRITABLE_FILES = ("nen/workflow.json", "nen/gates.json", "nen/contract.json")
KINDS = ("enum", "open", "external", "secret-env")
ASK_WHEN = ("adoption", "on-use")

SET, UNANNOTATED, INVALID, UNWRITTEN, REQUIRED, ON_USE, OPTIONAL, NA, FILE_MISSING, BLOCKED = (
    "set", "unannotated", "invalid", "default-unwritten", "required-missing", "asked-on-use", "optional",
    "not-applicable", "file-missing", "blocked")
OUTSTANDING = {UNANNOTATED, INVALID, UNWRITTEN, REQUIRED, FILE_MISSING, BLOCKED}
FILLABLE = {UNANNOTATED, UNWRITTEN}
GLYPH = {SET: "ok  ", UNANNOTATED: "NOTE", INVALID: "BAD ", UNWRITTEN: "DFLT",
         REQUIRED: "ASK ", ON_USE: "LATR", OPTIONAL: "OPT ", NA: "n/a ", FILE_MISSING: "MISS", BLOCKED: "BLOK"}
ENV_NAME = re.compile(r"^[A-Z][A-Z0-9_]{0,127}$")


class Defect(Exception):
    """Exit 2: the engine could not do its job."""


# --------------------------------------------------------------------------
# A JSON scanner that records spans, so a write is an insertion, never a re-dump.
# --------------------------------------------------------------------------
class Node:
    def __init__(self, kind, start):
        self.kind, self.start, self.end = kind, start, None
        self.members = []   # objects: (key, key_start, value Node)
        self.items = []     # arrays


WS = " \t\r\n"


def _skip(s, i):
    while i < len(s) and s[i] in WS:
        i += 1
    return i


def _string_end(s, i):
    i += 1
    while i < len(s):
        c = s[i]
        if c == "\\":
            i += 2
            continue
        if c == '"':
            return i + 1
        i += 1
    raise ValueError("unterminated string")


def _value(s, i):
    i = _skip(s, i)
    if i >= len(s):
        raise ValueError("unexpected end of input")
    c = s[i]
    if c == "{":
        node = Node("object", i)
        i = _skip(s, i + 1)
        if s[i] == "}":
            node.end = i + 1
            return node
        while True:
            i = _skip(s, i)
            if s[i] != '"':
                raise ValueError(f"expected a key at offset {i}")
            k_end = _string_end(s, i)
            key = json.loads(s[i:k_end])
            j = _skip(s, k_end)
            if s[j] != ":":
                raise ValueError(f"expected ':' at offset {j}")
            val = _value(s, j + 1)
            node.members.append((key, i, val))
            i = _skip(s, val.end)
            if s[i] == ",":
                i += 1
                continue
            if s[i] == "}":
                node.end = i + 1
                return node
            raise ValueError(f"expected ',' or '}}' at offset {i}")
    if c == "[":
        node = Node("array", i)
        i = _skip(s, i + 1)
        if s[i] == "]":
            node.end = i + 1
            return node
        while True:
            val = _value(s, i)
            node.items.append(val)
            i = _skip(s, val.end)
            if s[i] == ",":
                i += 1
                continue
            if s[i] == "]":
                node.end = i + 1
                return node
            raise ValueError(f"expected ',' or ']' at offset {i}")
    node = Node("scalar", i)
    if c == '"':
        node.end = _string_end(s, i)
    else:
        m = re.compile(r"-?\d+(\.\d+)?([eE][+-]?\d+)?|true|false|null").match(s, i)
        if not m:
            raise ValueError(f"unexpected character {c!r} at offset {i}")
        node.end = m.end()
    return node


def scan(text):
    root = _value(text, 0)
    if root.kind != "object" or _skip(text, root.end) != len(text):
        raise ValueError("a declaration must be one JSON object")
    json.loads(text)   # the scanner finds spans; json is the authority on validity
    return root


def member(node, key):
    for k, ks, v in node.members:
        if k == key:
            return ks, v
    return None


def line_indent(text, pos):
    start = text.rfind("\n", 0, pos) + 1
    j = start
    while j < len(text) and text[j] in " \t":
        j += 1
    return text[start:j]


def member_indent(text, obj):
    if obj.members:
        return line_indent(text, obj.members[0][1])
    return line_indent(text, obj.start) + "  "


def render(value, indent):
    out = json.dumps(value, indent=2, ensure_ascii=False)
    return out.replace("\n", "\n" + indent)


def insert_member(text, obj, key, value, after_key=None):
    """Insert `"key": value` into obj — after `after_key`'s member when named, else last."""
    ind = member_indent(text, obj)
    piece = f'"{key}": {render(value, ind)}'
    if not obj.members:
        close_ind = line_indent(text, obj.start)
        return text[:obj.start] + "{\n" + ind + piece + "\n" + close_ind + "}" + text[obj.end:]
    anchor = obj.members[-1][2]
    if after_key is not None:
        found = member(obj, after_key)
        if found:
            anchor = found[1]
    return text[:anchor.end] + ",\n" + ind + piece + text[anchor.end:]


def replace_value(text, node, value):
    ind = line_indent(text, node.start)
    return text[:node.start] + render(value, ind) + text[node.end:]


# --------------------------------------------------------------------------
# The catalogue
# --------------------------------------------------------------------------
def load_catalogue(root):
    path = root / CATALOGUE
    try:
        cat = json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        raise Defect(f"cannot read the catalogue at {path}: {exc}")
    rows = cat.get("values")
    if not isinstance(rows, list):
        raise Defect(f"{path}: `values` must be a list")
    return cat, [r for r in rows if isinstance(r, dict)]


def catalogue_problems(root, cat, rows):
    problems = []
    seen = set()
    domains = cat.get("domains", {})
    skills_dir = root / "claude" / "skills"
    for r in rows:
        rid = r.get("id")
        where = f"row {rid!r}"
        if not isinstance(rid, str) or not rid:
            problems.append(f"a row has no id: {r}")
            continue
        if rid in seen:
            problems.append(f"{where}: duplicate id")
        seen.add(rid)
        if r.get("file") not in WRITABLE_FILES:
            problems.append(f"{where}: file {r.get('file')!r} is not one of {WRITABLE_FILES}")
        path = r.get("path")
        if not isinstance(path, str) or not path or any(p.startswith("$") or not p for p in path.split(".")):
            problems.append(f"{where}: path {path!r} must be dotted keys, none `$`-prefixed")
        if r.get("kind") not in KINDS:
            problems.append(f"{where}: kind {r.get('kind')!r} is not one of {KINDS}")
        if r.get("domain") not in domains:
            problems.append(f"{where}: domain {r.get('domain')!r} is not declared under `domains`")
        opts = r.get("options")
        if r.get("kind") == "enum":
            if not isinstance(opts, list) or len(opts) < 2:
                problems.append(f"{where}: an enum row needs at least two options")
            elif "default" in r and r["default"] not in opts:
                problems.append(f"{where}: default {r['default']!r} is not among its options")
        elif opts is not None:
            problems.append(f"{where}: only an enum row carries options")
        if r.get("kind") == "secret-env" and r.get("default") not in (None,) and "default" in r:
            if not ENV_NAME.match(str(r["default"])):
                problems.append(f"{where}: a secret-env default must be an environment-variable NAME")
        for field in ("readers", "requiredBy"):
            for s in r.get(field, []):
                if not (skills_dir / s / "SKILL.md").is_file():
                    problems.append(f"{where}: {field} names {s!r}, which is not a skill in claude/skills/")
        if not r.get("readers"):
            problems.append(f"{where}: no readers — a value nobody reads is not configuration")
        if not isinstance(r.get("describe"), str) or not r["describe"]:
            problems.append(f"{where}: no describe")
        if r.get("ask") == "on-use" and not r.get("requiredBy"):
            problems.append(f"{where}: ask on-use names the skills that ask, so it needs requiredBy")
        if r.get("ask", "adoption") not in ASK_WHEN:
            problems.append(f"{where}: ask {r.get('ask')!r} is not one of {ASK_WHEN}")
        if (r.get("requiredBy") or "default" not in r) and not r.get("question"):
            problems.append(f"{where}: a value a skill requires needs the question to ask")
        for field in ("when", "candidatesFrom"):
            ref = r.get(field)
            if ref is not None and not (isinstance(ref, str) and "#" in ref and ref.split("#")[0] in WRITABLE_FILES):
                problems.append(f"{where}: {field} {ref!r} must be <file>#<dotted.path>")
    return problems


def annotation(options):
    def show(v):
        if v is None:
            return "null"
        if isinstance(v, bool):
            return "true" if v else "false"
        return str(v)
    return "one of: " + " | ".join(show(o) for o in options)


# --------------------------------------------------------------------------
# Reading a repository against the catalogue
# --------------------------------------------------------------------------
class Repo:
    def __init__(self, path):
        self.path = path
        self.texts, self.errors = {}, {}

    def text(self, rel):
        if rel not in self.texts and rel not in self.errors:
            p = self.path / rel
            if not p.is_file():
                self.texts[rel] = None
            else:
                try:
                    t = p.read_text()
                    scan(t)
                    self.texts[rel] = t
                except (OSError, ValueError) as exc:
                    self.errors[rel] = str(exc)
        return self.texts.get(rel)

    def lookup(self, rel, dotted):
        """(present, value, node, parent_chain) for a dotted path in a file."""
        t = self.text(rel)
        if t is None:
            return False, None
        cur = json.loads(t)
        for k in dotted.split("."):
            if not isinstance(cur, dict) or k not in cur:
                return False, None
            cur = cur[k]
        return True, cur

    def ref(self, ref):
        rel, dotted = ref.split("#", 1)
        return self.lookup(rel, dotted)


def applies(repo, row):
    ref = row.get("when")
    if not ref:
        return True
    present, value = repo.ref(ref)
    return present and value not in (None, "", [], {}) and not (
        isinstance(value, dict) and all(k.startswith("$") for k in value))


def candidates(repo, row):
    ref = row.get("candidatesFrom")
    if not ref:
        return row.get("options")
    present, value = repo.ref(ref)
    if isinstance(value, dict):
        return [k for k in value if not k.startswith("$")]
    if isinstance(value, list):
        return [v for v in value if isinstance(v, str)]
    return []


def annotation_state(repo, row):
    """True when the `$<key>` sibling carries the catalogue's current option list."""
    parent, _, leaf = row["path"].rpartition(".")
    present, holder = repo.lookup(row["file"], parent) if parent else (True, json.loads(repo.text(row["file"])))
    return isinstance(holder, dict) and holder.get("$" + leaf) == annotation(row["options"])


def shown(value):
    if isinstance(value, dict):
        keys = [k for k in value if not k.startswith("$")]
        return "{} (declared empty)" if not keys else f"{{{len(keys)} entries: {', '.join(keys)}}}"
    out = json.dumps(value, ensure_ascii=False)
    return out if len(out) <= 120 else out[:117] + "..."


def classify(repo, row, for_skill=None):
    rel = row["file"]
    t = repo.text(rel)
    if rel in repo.errors:
        return BLOCKED, f"{rel} does not parse: {repo.errors[rel]}"
    if t is None:
        return FILE_MISSING, f"{rel} is absent — nen scaffold init --repo <path> creates it"
    if not applies(repo, row):
        return NA, f"does not apply: {row['when']} is absent or empty"
    present, value = repo.lookup(rel, row["path"])
    has_default = "default" in row
    needed = bool(row.get("requiredBy"))
    if present and value is not None:
        if row["kind"] == "enum" and value not in row["options"]:
            return INVALID, f"{value!r} is not one of the options ({annotation(row['options'])})"
        if row["kind"] == "secret-env" and not (isinstance(value, str) and ENV_NAME.match(value)):
            return INVALID, "must name an environment variable, never carry the secret itself"
        if row["kind"] == "enum" and not annotation_state(repo, row):
            return UNANNOTATED, f"set to {json.dumps(value)}; its `$` option annotation is absent or stale"
        return SET, shown(value)
    if not present and has_default and not (needed and row["default"] is None):
        return UNWRITTEN, f"absent — its readers apply the default {json.dumps(row['default'])}; fill writes it"
    if needed and row.get("ask") == "on-use" and for_skill not in row["requiredBy"]:
        return ON_USE, (f"unset — only {', '.join(row['requiredBy'])} need it; Tenkai offers it, "
                        f"and the first of them to run asks for it then")
    if needed:
        return REQUIRED, (f"{'null' if present else 'absent'} with no usable default — "
                          f"{', '.join(row['requiredBy'])} cannot run until it is set")
    if present and row["kind"] == "enum" and not annotation_state(repo, row):
        return UNANNOTATED, "null; its `$` option annotation is absent or stale"
    if present:
        return SET, "null (a deliberate absence its readers handle)"
    return OPTIONAL, (f"absent — optional, {', '.join(row['readers'])} work without it; "
                      f"Tenkai offers it, no skill stops for it")


def diagnose(repo, rows, domain=None, for_skill=None):
    out = []
    for r in rows:
        if domain and r.get("domain") != domain:
            continue
        state, detail = classify(repo, r, for_skill)
        row = {"id": r["id"], "file": r["file"], "path": r["path"], "domain": r["domain"],
               "kind": r["kind"], "state": state, "detail": detail,
               "readers": r.get("readers", []), "requiredBy": r.get("requiredBy", [])}
        if state in (REQUIRED, INVALID, ON_USE, OPTIONAL) and r.get("question"):
            row["question"] = r.get("question") or f"What should {r['path']} be?"
            row["options"] = candidates(repo, r)
            row["setup"] = r.get("setup", [])
            row["write"] = f"config_values.sh set --repo <path> --id {r['id']} --value <JSON>"
            if r.get("satisfiedByArgument"):
                row["satisfiedByArgument"] = r["satisfiedByArgument"]
        out.append(row)
    return out


# --------------------------------------------------------------------------
# Writing
# --------------------------------------------------------------------------
def write_atomic(path, text):
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".config_values.")
    with os.fdopen(fd, "w") as fh:
        fh.write(text)
    shutil.copymode(str(path), tmp)
    os.replace(tmp, str(path))


def ensure_and_write(text, path_keys, value, annotate=None, overwrite=False):
    """Return new text with path_keys set to value (creating absent parents), plus annotation."""
    root = scan(text)
    node = root
    for i, k in enumerate(path_keys[:-1]):
        found = member(node, k)
        if found is None:
            nested = {}
            cur = nested
            for kk in path_keys[i + 1:-1]:
                cur[kk] = {}
                cur = cur[kk]
            cur[path_keys[-1]] = value
            if annotate is not None:
                cur["$" + path_keys[-1]] = annotate
            return insert_member(text, node, k, nested)
        node = found[1]
        if node.kind != "object":
            raise Defect(f"{'.'.join(path_keys[:i + 1])} is not an object; refusing to write through it")
    leaf = path_keys[-1]
    found = member(node, leaf)
    if found is None:
        text = insert_member(text, node, leaf, value)
    elif overwrite:
        text = replace_value(text, found[1], value)
    if annotate is not None:
        node = scan(text)
        for k in path_keys[:-1]:
            node = member(node, k)[1]
        ann = member(node, "$" + leaf)
        if ann is None:
            text = insert_member(text, node, "$" + leaf, annotate, after_key=leaf)
        elif json.loads(text[ann[1].start:ann[1].end]) != annotate:
            text = replace_value(text, ann[1], annotate)
    return text


def fill(repo, rows):
    written = []
    for r in rows:
        state, _ = classify(repo, r)
        rel = r["file"]
        present, value = repo.lookup(rel, r["path"]) if state not in (BLOCKED, FILE_MISSING) else (True, None)
        placeholder = not present and "default" in r and state in (REQUIRED, ON_USE)
        if state not in FILLABLE and not placeholder:
            continue
        ann = annotation(r["options"]) if r["kind"] == "enum" else None
        new = ensure_and_write(repo.text(rel), r["path"].split("."),
                               value if present else r["default"], annotate=ann)
        if new != repo.texts[rel]:
            json.loads(new)
            write_atomic(repo.path / rel, new)
            repo.texts[rel] = new
            written.append({"id": r["id"], "file": rel, "path": r["path"],
                            "wrote": "annotation" if present else f"default {json.dumps(r['default'])}"})
    return written


def set_value(repo, rows, rid, literal):
    row = next((r for r in rows if r["id"] == rid), None)
    if row is None:
        raise Defect(f"no catalogue row {rid!r}")
    try:
        value = json.loads(literal)
    except ValueError:
        raise Defect(f"--value must be a JSON literal (a string is quoted): {literal!r}")
    if row["kind"] == "enum" and value not in row["options"]:
        raise Defect(f"refusing {value!r}: {row['path']} is {annotation(row['options'])}")
    if row["kind"] == "secret-env" and not (isinstance(value, str) and ENV_NAME.match(value)):
        raise Defect(f"refusing: {row['path']} takes an environment-variable NAME, never the secret")
    rel = row["file"]
    if repo.text(rel) is None:
        raise Defect(f"{rel} is absent or unparseable — nen scaffold init owns creating it")
    ann = annotation(row["options"]) if row["kind"] == "enum" else None
    new = ensure_and_write(repo.text(rel), row["path"].split("."), value, annotate=ann, overwrite=True)
    json.loads(new)
    write_atomic(repo.path / rel, new)
    return {"id": rid, "file": rel, "path": row["path"], "value": value}


# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
def report(cat, rows_out, as_json, title):
    if as_json:
        print(json.dumps({"mode": title, "values": rows_out,
                          "outstanding": sum(1 for r in rows_out if r["state"] in OUTSTANDING)}, indent=2))
        return
    domains = cat.get("domains", {})
    for d in domains:
        group = [r for r in rows_out if r["domain"] == d]
        if not group:
            continue
        print(f"{d} — {domains[d]}")
        for r in group:
            print(f"  {GLYPH[r['state']]}  {r['file']} → {r['path']}")
            print(f"        {r['detail']}")
            if "question" in r:
                print(f"        ? {r['question']}")
                if r.get("options"):
                    print(f"          options: {' | '.join(map(str, r['options']))}")
                for step in r.get("setup", []):
                    print(f"          setup: {step}")
                if r.get("satisfiedByArgument"):
                    print(f"          (a typed {r['satisfiedByArgument']} satisfies it for that run)")
                print(f"          → {r['write']}")
    n = sum(1 for r in rows_out if r["state"] in OUTSTANDING)
    print()
    print("every settable value is written out and every needed one is set." if n == 0 else
          f"{n} value(s) outstanding — `fill` writes the defaults and annotations; "
          f"the ASK rows are the maintainer's answers (docs/WORKFLOW.md § 4).")


# --------------------------------------------------------------------------
# Self-test
# --------------------------------------------------------------------------
def self_test(root):
    failures = []

    def check(name, cond):
        if not cond:
            failures.append(name)

    cat = {
        "domains": {"development": "d", "deployment": "x"},
        "values": [
            {"id": "a.flag", "file": "nen/workflow.json", "path": "mukai.autoEn", "domain": "development",
             "kind": "enum", "default": False, "options": [True, False], "readers": ["mukai"],
             "describe": "x"},
            {"id": "a.mode", "file": "nen/workflow.json", "path": "reports.retain", "domain": "development",
             "kind": "enum", "default": "final-only", "options": ["final-only", "all"], "readers": ["spiritual-message"],
             "describe": "x"},
            {"id": "a.dir", "file": "nen/workflow.json", "path": "reports.dir", "domain": "development",
             "kind": "open", "default": "Reports", "readers": ["spiritual-message"], "describe": "x"},
            {"id": "a.target", "file": "nen/workflow.json", "path": "deploy.defaultTarget", "domain": "deployment",
             "kind": "open", "default": None, "readers": ["kagutsuchi"], "requiredBy": ["kagutsuchi"],
             "when": "nen/contract.json#project.targets", "candidatesFrom": "nen/contract.json#project.targets",
             "question": "Which target?", "describe": "x"},
            {"id": "a.key", "file": "nen/workflow.json", "path": "deploy.keyEnv", "domain": "deployment",
             "kind": "secret-env", "readers": ["kagutsuchi"], "requiredBy": ["kagutsuchi"],
             "question": "Which env var?", "setup": ["create a key"], "describe": "x"},
            {"id": "a.runners", "file": "nen/gates.json", "path": "runners.naming", "domain": "deployment",
             "kind": "open", "readers": ["jusshin"], "requiredBy": ["jusshin"], "ask": "on-use",
             "question": "Runner naming?", "describe": "x"},
            {"id": "a.kind", "file": "nen/contract.json", "path": "project.kind", "domain": "deployment",
             "kind": "enum", "options": ["product", "library"], "readers": ["mugetsu"],
             "question": "Kind?", "describe": "x"},
        ],
    }
    check("fixture catalogue is valid", catalogue_problems(root, cat, cat["values"]) == [])
    bad = json.loads(json.dumps(cat))
    bad["values"][1]["default"] = "nope"
    bad["values"][2]["readers"] = ["no-such-skill"]
    probs = catalogue_problems(root, bad, bad["values"])
    check("catalogue: default outside options refused", any("not among its options" in p for p in probs))
    check("catalogue: unknown reader refused", any("no-such-skill" in p for p in probs))

    workflow = ('{\n  "$schema": "nen.workflow/v0.1",\n  "reports": {\n    "dir": "Out",\n'
                '    "keep": ["a", "b"]\n  },\n  "deploy": {}\n}\n')
    contract = '{\n  "project": {\n    "targets": {\n      "$comment": "x",\n      "beta": {"why": "non-production"}\n    }\n  }\n}\n'
    with tempfile.TemporaryDirectory() as d:
        repo_path = Path(d)
        (repo_path / "nen").mkdir()
        (repo_path / "nen/workflow.json").write_text(workflow)
        (repo_path / "nen/contract.json").write_text(contract)
        (repo_path / "nen/gates.json").write_text("{}\n")
        rows = cat["values"]
        states = {r["id"]: r["state"] for r in diagnose(Repo(repo_path), rows)}
        check("absent defaulted enum is default-unwritten", states["a.flag"] == UNWRITTEN)
        check("set open value is set", states["a.dir"] == SET)
        check("null-default value a skill needs is required-missing", states["a.target"] == REQUIRED)
        check("no-default secret-env is required-missing", states["a.key"] == REQUIRED)
        check("an on-use value is not outstanding at adoption", states["a.runners"] == ON_USE)
        check("an absent value with no default nobody requires is optional", states["a.kind"] == OPTIONAL)
        on_use = [r for r in diagnose(Repo(repo_path), rows, for_skill="jusshin") if r["id"] == "a.runners"]
        check("an on-use value is required-missing for the skill that needs it",
              on_use and on_use[0]["state"] == REQUIRED)

        need = [r for r in diagnose(Repo(repo_path), rows)
                if "kagutsuchi" in r["requiredBy"] and r["state"] in OUTSTANDING]
        check("need offers candidates from the contract, skipping $comment",
              any(r.get("options") == ["beta"] for r in need))

        wrote = fill(Repo(repo_path), rows)
        after = (repo_path / "nen/workflow.json").read_text()
        check("fill wrote the absent defaults", {w["id"] for w in wrote} >= {"a.flag", "a.mode", "a.target"})
        check("fill keeps hand formatting (inline array survives)", '"keep": ["a", "b"]' in after)
        check("fill annotates an enum beside its key", '"$autoEn": "one of: true | false"' in after)
        check("fill never touches a set open value", '"dir": "Out"' in after)
        check("fill writes nothing without a default", "keyEnv" not in after)
        check("fill output is valid JSON", isinstance(json.loads(after), dict))
        check("fill is idempotent", fill(Repo(repo_path), rows) == [])
        states = {r["id"]: r["state"] for r in diagnose(Repo(repo_path), rows)}
        check("after fill only the asked values remain",
              {k for k, v in states.items() if v in OUTSTANDING} == {"a.target", "a.key"})

        try:
            set_value(Repo(repo_path), rows, "a.mode", '"sometimes"')
            check("set refuses an enum value outside its options", False)
        except Defect:
            pass
        try:
            set_value(Repo(repo_path), rows, "a.key", '"sk-live-abc123"')
            check("set refuses a secret-shaped value for a secret-env row", False)
        except Defect:
            pass
        set_value(Repo(repo_path), rows, "a.target", '"beta"')
        set_value(Repo(repo_path), rows, "a.key", '"BETA_UPLOAD_KEY"')
        set_value(Repo(repo_path), rows, "a.mode", '"all"')
        final = json.loads((repo_path / "nen/workflow.json").read_text())
        check("set writes the chosen values", final["deploy"]["defaultTarget"] == "beta"
              and final["deploy"]["keyEnv"] == "BETA_UPLOAD_KEY" and final["reports"]["retain"] == "all")
        check("set keeps the annotation", final["reports"]["$retain"] == "one of: final-only | all")
        check("nothing outstanding once answered",
              not [r for r in diagnose(Repo(repo_path), rows) if r["state"] in OUTSTANDING])

        (repo_path / "nen/workflow.json").write_text('{"mukai": {"autoEn": "maybe"}}\n')
        states = {r["id"]: r["state"] for r in diagnose(Repo(repo_path), rows)}
        check("an enum value outside its options is invalid, never rewritten", states["a.flag"] == INVALID)
        fill(Repo(repo_path), rows)
        check("fill leaves an invalid value alone",
              json.loads((repo_path / "nen/workflow.json").read_text())["mukai"]["autoEn"] == "maybe")

        (repo_path / "nen/workflow.json").write_text('{"mukai": ')
        check("an unparseable declaration is blocked",
              diagnose(Repo(repo_path), rows)[0]["state"] == BLOCKED)
        (repo_path / "nen/workflow.json").unlink()
        check("an absent declaration routes to nen scaffold init",
              diagnose(Repo(repo_path), rows)[0]["state"] == FILE_MISSING)
        check("fill never creates a declaration", fill(Repo(repo_path), rows) == []
              and not (repo_path / "nen/workflow.json").exists())

    real_cat, real_rows = load_catalogue(root)
    probs = catalogue_problems(root, real_cat, real_rows)
    for p in probs:
        failures.append(f"shipped catalogue: {p}")

    for f in failures:
        print(f"FAIL  {f}")
    print(f"config_values self-test: {'PASS' if not failures else 'FAIL'} ({len(failures)} failure(s))")
    return 0 if not failures else 1


# --------------------------------------------------------------------------
def main(argv):
    root = Path(os.environ["CONFIG_VALUES_DEFAULT_ROOT"])
    if not argv:
        raise Defect("usage: config_values.sh diagnose|fill|need|set|check-catalogue|--self-test ...")
    mode, rest = argv[0], argv[1:]
    opts = {}
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == "--json":
            opts["json"] = True
            i += 1
            continue
        if a in ("--repo", "--skill", "--id", "--value", "--domain", "--hatsu-root") and i + 1 < len(rest):
            opts[a[2:]] = rest[i + 1]
            i += 2
            continue
        raise Defect(f"unknown or incomplete argument {a!r}")
    if "hatsu-root" in opts:
        root = Path(opts["hatsu-root"]).resolve()
    if mode == "--self-test":
        return self_test(root)
    cat, rows = load_catalogue(root)
    if mode == "check-catalogue":
        probs = catalogue_problems(root, cat, rows)
        for p in probs:
            print(f"FAIL  {p}")
        print(f"{len(rows)} catalogue row(s); {len(probs)} problem(s)")
        return 0 if not probs else 1
    if "repo" not in opts:
        raise Defect(f"{mode} needs --repo <path>")
    repo_path = Path(opts["repo"]).resolve()
    if not repo_path.is_dir():
        raise Defect(f"no such repository: {repo_path}")
    repo = Repo(repo_path)
    if mode == "diagnose":
        out = diagnose(repo, rows, opts.get("domain"))
        report(cat, out, opts.get("json"), "diagnose")
        return 1 if any(r["state"] in OUTSTANDING for r in out) else 0
    if mode == "fill":
        wrote = fill(repo, rows)
        out = diagnose(Repo(repo_path), rows)
        if opts.get("json"):
            print(json.dumps({"mode": "fill", "wrote": wrote, "values": out}, indent=2))
        else:
            for w in wrote:
                print(f"  wrote {w['file']} → {w['path']}: {w['wrote']}")
            print(f"{len(wrote)} write(s).")
            report(cat, [r for r in out if r["state"] in OUTSTANDING], False, "fill")
        return 1 if any(r["state"] in OUTSTANDING for r in out) else 0
    if mode == "need":
        if "skill" not in opts:
            raise Defect("need takes --skill <name>")
        out = [r for r in diagnose(repo, rows, for_skill=opts["skill"])
               if opts["skill"] in r["requiredBy"] and r["state"] in (REQUIRED, INVALID, FILE_MISSING, BLOCKED)]
        if opts.get("json"):
            print(json.dumps({"mode": "need", "skill": opts["skill"], "values": out}, indent=2))
        elif not out:
            print(f"{opts['skill']}: every value it needs is set.")
        else:
            report(cat, out, False, "need")
        return 1 if out else 0
    if mode == "set":
        if "id" not in opts or "value" not in opts:
            raise Defect("set takes --id <catalogue id> --value <JSON literal>")
        res = set_value(repo, rows, opts["id"], opts["value"])
        print(f"set {res['file']} → {res['path']} = {json.dumps(res['value'])}; "
              f"now run nen schema check --repo {repo_path}")
        return 0
    raise Defect(f"unknown mode {mode!r}")


try:
    sys.exit(main(sys.argv[1:]))
except Defect as exc:
    print(f"config_values.sh: {exc}", file=sys.stderr)
    sys.exit(2)
PY
