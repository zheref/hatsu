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
#   (docs/WORKFLOW.md § 4 step 3). A fixed-set value outside its options is refused; a `secret-env`
#   value must be an environment-variable NAME; and every string inside any value is screened before
#   the write — a `requiresEnv` entry that is not a NAME, a string shaped like a known credential, a
#   literal following a credential-named flag (`--api-key <literal>`), or a credential-named key
#   holding a literal is refused, and the confirmation line prints keys, never the value. The screen
#   is a shape check, not proof of absence: `nen stage triage` still runs on the written file.
#
#   CONFINEMENT. A declaration that is a symlink, under a `nen/` that is a symlink, or resolving
#   outside --repo is `blocked` — read and write alike — and the check is repeated immediately before
#   the replace, so a link swapped in between is refused rather than followed (SEC-1).
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
import contextlib
import json
import os
import threading
import time
import re
import shutil
import sys
import tempfile
from pathlib import Path

if os.name == "nt":   # the same split scripts/hanten_cycle_ledger.sh makes for its own lock
    import msvcrt
    _windows_thread_lock = threading.Lock()
else:
    import fcntl

CATALOGUE = Path("contracts") / "config-catalogue.json"
WRITABLE_FILES = ("nen/workflow.json", "nen/gates.json", "nen/contract.json")
KINDS = ("enum", "subset", "open", "external", "secret-env")
ANNOTATED = ("enum", "subset")
ANNOTATION_PREFIXES = ("one of: ", "any of: ")


def in_options(value, options):
    """Membership that keeps JSON types apart: 1 is not true, 0 is not false (QA-18)."""
    return any(type(value) is type(o) and value == o for o in options)


def valid_for(row, value):
    if row["kind"] == "enum":
        return in_options(value, row["options"])
    if row["kind"] == "subset":
        return isinstance(value, list) and all(in_options(v, row["options"]) for v in value)
    return True
ASK_WHEN = ("adoption", "on-use")

SET, UNANNOTATED, INVALID, UNWRITTEN, REQUIRED, ON_USE, OPTIONAL, NA, FILE_MISSING, BLOCKED = (
    "set", "unannotated", "invalid", "default-unwritten", "required-missing", "asked-on-use", "optional",
    "not-applicable", "file-missing", "blocked")
OUTSTANDING = {UNANNOTATED, INVALID, UNWRITTEN, REQUIRED, FILE_MISSING, BLOCKED}
FILLABLE = {UNANNOTATED, UNWRITTEN}
GLYPH = {SET: "ok  ", UNANNOTATED: "NOTE", INVALID: "BAD ", UNWRITTEN: "DFLT",
         REQUIRED: "ASK ", ON_USE: "LATR", OPTIONAL: "OPT ", NA: "n/a ", FILE_MISSING: "MISS", BLOCKED: "BLOK"}
ENV_NAME = re.compile(r"^[A-Z][A-Z0-9_]{0,127}$")
SECRET_SHAPES = re.compile(
    r"(sk|pk|rk)[-_](live|test)[-_]|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_|AKIA[0-9A-Z]{16}|xox[abposr]-"
    r"|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|eyJ[A-Za-z0-9_-]{10,}\\.eyJ")
CREDENTIAL_NAME = re.compile(r"(api[-_]?key|token|secret|passw(or)?d|credential|private[-_]?key)", re.I)


def secret_problems(value, where="value"):
    """Every string leaf that looks like a credential rather than a reference to one."""
    out = []
    if isinstance(value, dict):
        for k, v in value.items():
            if k == "requiresEnv":
                names = v if isinstance(v, list) else [v]
                out += [f"{where}.requiresEnv: {n!r} is not an environment-variable NAME"
                        for n in names if not (isinstance(n, str) and ENV_NAME.match(n))]
                continue
            if CREDENTIAL_NAME.search(k) and isinstance(v, str) and not ENV_NAME.match(v):
                out.append(f"{where}.{k}: a credential-named key holds a literal, not an environment-variable NAME")
            out += secret_problems(v, f"{where}.{k}")
    elif isinstance(value, list):
        for i, v in enumerate(value):
            prev = value[i - 1] if i > 0 else None
            if (isinstance(v, str) and isinstance(prev, str) and prev.startswith("-")
                    and CREDENTIAL_NAME.search(prev) and "=" not in prev and not v.startswith("$")):
                out.append(f"{where}[{i}]: a literal follows the credential-named flag {prev!r}")
            elif (isinstance(v, str) and v.startswith("-") and "=" in v
                    and CREDENTIAL_NAME.search(v.split("=", 1)[0]) and not v.split("=", 1)[1].startswith("$")):
                out.append(f"{where}[{i}]: a credential-named flag carries a literal")
            out += secret_problems(v, f"{where}[{i}]")
    elif isinstance(value, str) and SECRET_SHAPES.search(value):
        out.append(f"{where}: shaped like a credential")
    return out


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
            if member(node, key) is not None:
                raise ValueError(f"duplicate key {key!r}: JSON keeps the last, so an in-place edit would "
                                 f"land in the copy every reader ignores")
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
    json.loads(text)   # json is the authority on validity, and rejects a truncated file before the walk
    root = _value(text, 0)
    if root.kind != "object" or _skip(text, root.end) != len(text):
        raise ValueError("a declaration must be one JSON object")
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


def newline_of(text):
    return "\r\n" if "\r\n" in text else "\n"


def render(value, indent, nl="\n"):
    out = json.dumps(value, indent=2, ensure_ascii=False)
    return out.replace("\n", nl + indent)


def insert_member(text, obj, key, value, after_key=None):
    """Insert `"key": value` into obj — after `after_key`'s member when named, else last."""
    ind = member_indent(text, obj)
    nl = newline_of(text)
    piece = f'"{key}": {render(value, ind, nl)}'
    if not obj.members:
        close_ind = line_indent(text, obj.start)
        return text[:obj.start] + "{" + nl + ind + piece + nl + close_ind + "}" + text[obj.end:]
    anchor = obj.members[-1][2]
    if after_key is not None:
        found = member(obj, after_key)
        if found:
            anchor = found[1]
    return text[:anchor.end] + "," + nl + ind + piece + text[anchor.end:]


def replace_value(text, node, value):
    ind = line_indent(text, node.start)
    return text[:node.start] + render(value, ind, newline_of(text)) + text[node.end:]


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
        if r.get("kind") in ANNOTATED:
            if not isinstance(opts, list) or len(opts) < 2:
                problems.append(f"{where}: an {r.get('kind')} row needs at least two options")
            elif "default" in r and r["default"] is not None and not valid_for(r, r["default"]):
                problems.append(f"{where}: default {r['default']!r} is not among its options")
        elif opts is not None:
            problems.append(f"{where}: only an enum or subset row carries options")
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
        if r.get("choice") not in (None, "maintainer"):
            problems.append(f"{where}: choice {r.get('choice')!r} is not 'maintainer'")
        if r.get("nullIsAnswer") and r.get("requiredBy"):
            problems.append(f"{where}: a null that is an answer cannot also be required")
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
    problems += source_drift(root, rows)
    return problems


def source_drift(root, rows):
    """A default restated in docs/WORKFLOW.md's key tables must agree with the catalogue's — the two
    are one fact in two places, so a mismatch is a catalogue problem, never a silent fill."""
    out = []
    try:
        lines = (root / "docs" / "WORKFLOW.md").read_text().splitlines()
    except OSError:
        return out
    for r in rows:
        if "default" not in r or "docs/WORKFLOW.md" not in str(r.get("source", "")):
            continue
        leaf = r["path"].split(".")[-1]
        if r.get("sourceTable") is False:
            # documented in WORKFLOW's prose, declared so: the key and its default must still meet on a line
            hits = [ln for ln in lines if f"`{leaf}`" in ln or f'"{leaf}"' in ln]
        else:
            hits = [ln for ln in lines if ln.startswith("|") and f"`{leaf}`" in ln.split("|")[1]]
        if not hits:
            out.append(f"row {r['id']!r}: cites docs/WORKFLOW.md but no "
                       f"{'line' if r.get('sourceTable') is False else 'key-table row'} there names `{leaf}` "
                       f"— the drift guard would read nothing; restore the row, or re-cite the source")
            continue
        d = r["default"]
        shown_d = json.dumps(d) if not isinstance(d, str) else d
        forms = {shown_d, str(d).lower(), json.dumps(d), str(d)}
        if isinstance(d, list):
            forms |= {", ".join(json.dumps(x) for x in d), json.dumps(d, separators=(",", ":"))}
        if not any(any(f in h for f in forms) for h in hits):
            out.append(f"row {r['id']!r}: default {json.dumps(d)} does not appear in docs/WORKFLOW.md's "
                       f"`{leaf}` row — one of the two has drifted")
    return out


def annotation(options, kind="enum"):
    def show(v):
        if v is None:
            return "null"
        if isinstance(v, bool):
            return "true" if v else "false"
        return str(v)
    return ("any of: " if kind == "subset" else "one of: ") + " | ".join(show(o) for o in options)


def ann_for(row):
    return annotation(row["options"], row["kind"]) if row["kind"] in ANNOTATED else None


# --------------------------------------------------------------------------
# Reading a repository against the catalogue
# --------------------------------------------------------------------------
class Repo:
    def __init__(self, path):
        self.path = path
        self.texts, self.errors = {}, {}

    def confined(self, rel):
        """None when rel is a regular path inside the repo, else why it is refused (SEC-1)."""
        cur = self.path
        for part in Path(rel).parts:
            cur = cur / part
            if cur.is_symlink():
                return f"{cur.relative_to(self.path)} is a symlink; refusing to read or write through it"
        try:
            (self.path / rel).resolve().relative_to(self.path.resolve())
        except ValueError:
            return f"{rel} resolves outside the repository"
        return None

    def text(self, rel):
        if rel not in self.texts and rel not in self.errors:
            p = self.path / rel
            refusal = self.confined(rel)
            if refusal:
                self.errors[rel] = refusal
            elif not p.is_file():
                self.texts[rel] = None
            else:
                try:
                    with open(p, newline="") as fh:   # CRLF survives the round trip
                        t = fh.read()
                    scan(t)
                    self.texts[rel] = t
                except (OSError, ValueError, IndexError, RecursionError, UnicodeDecodeError) as exc:
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
    """True when the `$<key>` sibling carries the current option list, or carries a note of the
    maintainer's own (one not written by this engine), which is never overwritten."""
    parent, _, leaf = row["path"].rpartition(".")
    present, holder = repo.lookup(row["file"], parent) if parent else (True, json.loads(repo.text(row["file"])))
    if not isinstance(holder, dict):
        return False
    note = holder.get("$" + leaf)
    if isinstance(note, str) and not note.startswith(ANNOTATION_PREFIXES):
        return True
    return note == ann_for(row)


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
        if rel == "nen/gates.json":
            return FILE_MISSING, (f"{rel} is absent — nen scaffold init does not write it; "
                                  f"tenkai § 4a and docs/GATE-CONFIGURATION.md author it")
        return FILE_MISSING, f"{rel} is absent — nen scaffold init --repo <path> creates it"
    if not applies(repo, row):
        return NA, f"does not apply: {row['when']} is absent or empty"
    cur, keys = json.loads(t), row["path"].split(".")
    for i, k in enumerate(keys[:-1]):
        if not isinstance(cur, dict) or k not in cur:
            break
        cur = cur[k]
        if not isinstance(cur, dict):
            return INVALID, (f"{'.'.join(keys[:i + 1])} is not an object, so {row['path']} cannot be "
                             f"written beneath it; fill skips it")
    present, value = repo.lookup(rel, row["path"])
    has_default = "default" in row
    needed = bool(row.get("requiredBy"))
    if present and value is None and row.get("nullIsAnswer"):
        if row.get("question"):
            return OPTIONAL, ("null — a deliberate answer: its readers ask on each call; "
                              "Tenkai offers a standing value, nothing stops for it")
        return SET, "null — a deliberate answer: its readers ask on each call"
    if present and value is None and row["kind"] in ANNOTATED and not in_options(None, row["options"]):
        return INVALID, f"null is not among the options ({ann_for(row)})"
    if present and value is not None:
        if not valid_for(row, value):
            return INVALID, f"{json.dumps(value)} is not within the options ({ann_for(row)})"
        cands = candidates(repo, row) if row.get("candidatesFrom") else None
        if cands and not in_options(value, cands):
            return INVALID, f"{json.dumps(value)} names no key of {row['candidatesFrom']} ({' | '.join(cands)})"
        if row["kind"] == "secret-env" and not (isinstance(value, str) and ENV_NAME.match(value)):
            return INVALID, "must name an environment variable, never carry the secret itself"
        if row["kind"] in ANNOTATED and not annotation_state(repo, row):
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
    if present and row["kind"] in ANNOTATED and not annotation_state(repo, row):
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
            if r.get("choice") == "maintainer":
                row["typed"] = True
            if r.get("landsByPR"):
                row["landsByPR"] = True
        out.append(row)
    return out


# --------------------------------------------------------------------------
# Writing
# --------------------------------------------------------------------------
def write_atomic(repo, rel, text):
    try:
        _write_atomic(repo, rel, text)
    except OSError as exc:
        raise Defect(f"cannot write {rel}: {exc.strerror or exc}")


def _write_atomic(repo, rel, text):
    path = repo.path / rel
    refusal = repo.confined(rel)
    if refusal:
        raise Defect(f"refusing to write: {refusal}")
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".config_values.")
    with os.fdopen(fd, "w", newline="") as fh:
        fh.write(text)
    shutil.copymode(str(path), tmp)
    refusal = repo.confined(rel)   # re-checked at the last moment: a link swapped in is refused, never followed
    if refusal:
        os.unlink(tmp)
        raise Defect(f"refusing to write: {refusal}")
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
        else:
            old = json.loads(text[ann[1].start:ann[1].end])
            if old != annotate and isinstance(old, str) and old.startswith(ANNOTATION_PREFIXES):
                text = replace_value(text, ann[1], annotate)   # only this engine's own note is rewritten
    return text


@contextlib.contextmanager
def declaration_lock(repo):
    """Serialise fill and set across processes: a second session's `set` waits for a running `fill`,
    and each re-reads the declaration under the lock, so neither writes from a stale copy (QA-16)."""
    d = repo.path / "nen"
    if not d.is_dir() or d.is_symlink():
        yield
        return
    if os.name == "nt":
        # a directory cannot be byte-range locked on Windows: lock a file under .nen/, which
        # tenkai git-ignores, with msvcrt as hanten_cycle_ledger.sh does
        (repo.path / ".nen").mkdir(exist_ok=True)
        fd = os.open(str(repo.path / ".nen" / "config_values.lock"), os.O_RDWR | os.O_CREAT, 0o600)
        _windows_thread_lock.acquire()
        try:
            if os.fstat(fd).st_size == 0:
                os.write(fd, b"\0")
            os.lseek(fd, 0, os.SEEK_SET)
            deadline = time.monotonic() + 30
            while True:
                try:
                    msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
                    break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise Defect("another config_values.sh write held the lock for 30 s; nothing written")
                    time.sleep(0.05)
            repo.texts.clear()
            repo.errors.clear()
            yield
        finally:
            try:
                os.lseek(fd, 0, os.SEEK_SET)
                msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
            except OSError:
                pass
            os.close(fd)
            _windows_thread_lock.release()
        return
    fd = os.open(str(d), os.O_RDONLY)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        repo.texts.clear()
        repo.errors.clear()
        yield
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def fill(repo, rows):
    with declaration_lock(repo):
        return _fill(repo, rows)


def _fill(repo, rows):
    written = []
    for r in rows:
        state, _ = classify(repo, r)
        rel = r["file"]
        present, value = repo.lookup(rel, r["path"]) if state not in (BLOCKED, FILE_MISSING) else (True, None)
        placeholder = not present and "default" in r and state in (REQUIRED, ON_USE)
        if state not in FILLABLE and not placeholder:
            continue
        ann = ann_for(r)
        try:
            new = ensure_and_write(repo.text(rel), r["path"].split("."),
                                   value if present else r["default"], annotate=ann)
        except Defect as exc:
            written.append({"id": r["id"], "file": rel, "path": r["path"], "wrote": f"nothing — {exc}"})
            continue
        if new != repo.texts[rel]:
            json.loads(new)
            write_atomic(repo, rel, new)
            repo.texts[rel] = new
            written.append({"id": r["id"], "file": rel, "path": r["path"],
                            "wrote": "annotation" if present else f"default {json.dumps(r['default'])}"})
    return written


def set_value(repo, rows, rid, literal):
    with declaration_lock(repo):
        return _set_value(repo, rows, rid, literal)


def _set_value(repo, rows, rid, literal):
    row = next((r for r in rows if r["id"] == rid), None)
    if row is None:
        raise Defect(f"no catalogue row {rid!r}")
    try:
        value = json.loads(literal)
    except ValueError:
        raise Defect(f"--value must be a JSON literal (a string is quoted): {literal!r}")
    if row["kind"] in ANNOTATED and not valid_for(row, value):
        raise Defect(f"refusing {json.dumps(value)}: {row['path']} is {ann_for(row)}")
    if row.get("candidatesFrom") and value is not None:
        cands = candidates(repo, row)
        if not in_options(value, cands or []):
            raise Defect(f"refusing {json.dumps(value)}: it names no key of {row['candidatesFrom']} "
                         f"({' | '.join(cands or []) or 'none declared'})")
    if row["kind"] == "secret-env" and not (isinstance(value, str) and ENV_NAME.match(value)):
        raise Defect(f"refusing: {row['path']} takes an environment-variable NAME, never the secret")
    if row.get("nonProductionTarget") and value is not None:
        _, targets = repo.lookup("nen/contract.json", "project.targets")
        why = (targets or {}).get(value, {}).get("why", "") if isinstance(targets, dict) and isinstance(value, str) else ""
        if "non-production" not in str(why).lower():
            raise Defect(f"refusing {value!r}: it must name a project.targets key whose `why` reads "
                         f"non-production (kagutsuchi § 2 reads it failing closed); production is mugetsu's at G3")
    problems = secret_problems(value, row["path"])
    if problems:
        raise Defect("refusing to write a credential into a tracked file — export it and write only its "
                     "environment-variable NAME: " + "; ".join(problems))
    rel = row["file"]
    if repo.text(rel) is None:
        why = repo.errors.get(rel, "absent — nen scaffold init owns creating it")
        raise Defect(f"{rel}: {why}")
    ann = ann_for(row)
    new = ensure_and_write(repo.text(rel), row["path"].split("."), value, annotate=ann, overwrite=True)
    json.loads(new)
    write_atomic(repo, rel, new)
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
                    label = ("candidates, for reference — typed, never picked, none starred"
                             if r.get("typed") else "options")
                    print(f"          {label}: {' | '.join(map(str, r['options']))}")
                for step in r.get("setup", []):
                    print(f"          setup: {step}")
                if r.get("landsByPR"):
                    print("          lands through its declaration PR before it runs; the phase does not resume on it")
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
        "domains": {"development": "d", "deployment": "x", "review": "r", "reporting": "p", "notifications": "n"},
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
            set_value(Repo(repo_path), rows, "a.key", '"the literal credential, not a name"')
            check("set refuses anything but an environment-variable NAME on a secret-env row", False)
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

        for bad in ('{"beta": {"args": ["--api-key", "PLAIN-LITERAL"], "why": "x"}}',
                    '{"beta": {"args": ["--token=PLAIN"], "why": "x"}}',
                    '{"beta": {"requiresEnv": ["not a name"], "why": "x"}}',
                    '{"beta": {"apiKey": "plain-literal-value"}}',
                    '{"beta": {"args": ["' + "gh" + 'p_abcdefghijklmnopqrstuvwxyz0123"]}}'):
            before = (repo_path / "nen/workflow.json").read_text()
            try:
                set_value(Repo(repo_path), rows, "a.dir", bad)
                check(f"set refuses a credential inside an object value: {bad}", False)
            except Defect:
                check("a refused value writes nothing", (repo_path / "nen/workflow.json").read_text() == before)
        set_value(Repo(repo_path), rows, "a.dir",
                  '{"beta": {"args": ["--api-key", "$BETA_KEY"], "requiresEnv": ["BETA_KEY"]}}')

        outside = Path(d) / "outside"
        outside.mkdir()
        (outside / "workflow.json").write_text('{"private": "x"}\n')
        linked = Path(d) / "linked"
        (linked / "nen").mkdir(parents=True)
        os.symlink(outside / "workflow.json", linked / "nen/workflow.json")
        check("a symlinked declaration is blocked", diagnose(Repo(linked), rows)[0]["state"] == BLOCKED)
        fill(Repo(linked), rows)
        check("fill never writes through a symlinked declaration",
              (outside / "workflow.json").read_text() == '{"private": "x"}\n'
              and (linked / "nen/workflow.json").is_symlink())
        try:
            set_value(Repo(linked), rows, "a.mode", '"all"')
            check("set refuses a symlinked declaration", False)
        except Defect:
            pass
        linkdir = Path(d) / "linkdir"
        linkdir.mkdir()
        os.symlink(outside, linkdir / "nen")
        fill(Repo(linkdir), rows)
        check("fill never writes through a symlinked nen/",
              (outside / "workflow.json").read_text() == '{"private": "x"}\n')

        (repo_path / "nen/workflow.json").write_text('{"mukai": ')
        check("an unparseable declaration is blocked",
              diagnose(Repo(repo_path), rows)[0]["state"] == BLOCKED)
        (repo_path / "nen/workflow.json").unlink()
        check("an absent declaration routes to nen scaffold init",
              diagnose(Repo(repo_path), rows)[0]["state"] == FILE_MISSING)
        check("fill never creates a declaration", fill(Repo(repo_path), rows) == []
              and not (repo_path / "nen/workflow.json").exists())

    # the remaining branches: not-applicable, null handling, stale annotation, need through main()
    extra = [
        {"id": "b.enum", "file": "nen/workflow.json", "path": "x.mode", "domain": "development",
         "kind": "enum", "default": "a", "options": ["a", "b"], "readers": ["mukai"], "describe": "x"},
        {"id": "b.target", "file": "nen/workflow.json", "path": "deploy.defaultTarget", "domain": "deployment",
         "kind": "open", "default": None, "nullIsAnswer": True, "choice": "maintainer",
         "nonProductionTarget": True, "readers": ["kagutsuchi"], "question": "Which?",
         "when": "nen/contract.json#project.targets", "candidatesFrom": "nen/contract.json#project.targets",
         "describe": "x"},
        {"id": "b.env", "file": "nen/workflow.json", "path": "x.keyEnv", "domain": "deployment",
         "kind": "secret-env", "readers": ["kagutsuchi"], "requiredBy": ["kagutsuchi"], "question": "?",
         "describe": "x"},
    ]
    check("extra fixture rows are valid", catalogue_problems(root, cat, extra) == [])
    with tempfile.TemporaryDirectory() as d:
        rp = Path(d)
        (rp / "nen").mkdir()
        (rp / "nen/workflow.json").write_text(
            '{\n  "x": {"mode": null, "keyEnv": "sk-live-not-a-name"},\n  "deploy": {"defaultTarget": null}\n}\n')
        st = {r["id"]: r for r in diagnose(Repo(rp), extra)}
        check("a when-row whose source is absent is not-applicable", st["b.target"]["state"] == NA)
        check("a present null on an enum outside its options is invalid", st["b.enum"]["state"] == INVALID)
        check("a secret-env value that is not a NAME is invalid in diagnose", st["b.env"]["state"] == INVALID)
        (rp / "nen/contract.json").write_text(
            '{"project": {"targets": {"beta": {"why": "non-production beta"}, "store": {"why": "the App Store"}}}}\n')
        st = {r["id"]: r for r in diagnose(Repo(rp), extra)}
        check("a deliberate null is an answer: optional, offered, never outstanding",
              st["b.target"]["state"] == OPTIONAL and st["b.target"].get("typed"))
        try:
            set_value(Repo(rp), extra, "b.target", '"store"')
            check("set refuses a production default target", False)
        except Defect:
            pass
        set_value(Repo(rp), extra, "b.target", '"beta"')
        check("set accepts a non-production default target",
              json.loads((rp / "nen/workflow.json").read_text())["deploy"]["defaultTarget"] == "beta")
        (rp / "nen/workflow.json").write_text('{\n  "x": {"mode": "b", "$mode": "one of: stale"}\n}\n')
        fill(Repo(rp), extra[:1])
        check("a stale annotation is rewritten in place",
              json.loads((rp / "nen/workflow.json").read_text())["x"]["$mode"] == "one of: a | b")
        import io
        import contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc_known = main(["need", "--repo", str(rp), "--skill", "gyo", "--hatsu-root", str(root)])
            rc_cat = main(["check-catalogue", "--hatsu-root", str(root)])
        check("need through main exits 0 when nothing the skill needs is missing", rc_known == 0)
        check("check-catalogue exits 0 on the shipped catalogue", rc_cat == 0)
        try:
            with contextlib.redirect_stdout(buf):
                main(["need", "--repo", str(rp), "--skill", "no-such-skill", "--hatsu-root", str(root)])
            check("need refuses an unknown skill", False)
        except Defect:
            pass

    # Nobunaga's corpus: CRLF, truncation, non-object parent, typed options, foreign notes, subsets
    more = [
        {"id": "c.flag", "file": "nen/workflow.json", "path": "mukai.autoEn", "domain": "review",
         "kind": "enum", "default": False, "options": [True, False], "readers": ["mukai"], "describe": "x"},
        {"id": "c.dir", "file": "nen/workflow.json", "path": "reports.dir", "domain": "reporting",
         "kind": "open", "default": "Reports", "readers": ["spiritual-message"], "describe": "x"},
        {"id": "c.rungs", "file": "nen/workflow.json", "path": "notifications.rungs", "domain": "notifications",
         "kind": "subset", "default": ["push", "os"], "options": ["push", "os", "sound"],
         "readers": ["jutaisho"], "describe": "x"},
    ]
    check("subset fixture rows are valid", catalogue_problems(root, cat, more) == [])
    with tempfile.TemporaryDirectory() as d:
        rp = Path(d)
        (rp / "nen").mkdir()
        wf = rp / "nen/workflow.json"
        wf.write_bytes(b'{\r\n  "mukai": {\r\n    "autoEn": false\r\n  }\r\n}\r\n')
        fill(Repo(rp), more)
        raw = wf.read_bytes()
        check("CRLF line endings survive fill", b"\r\n" in raw and b"\n" not in raw.replace(b"\r\n", b""))
        check("a subset is annotated with any-of", json.loads(raw)["notifications"]["$rungs"] == "any of: push | os | sound")
        for broken in ('{"mukai": {"autoEn": false}', "{"):
            wf.write_text(broken)
            check(f"a truncated declaration is blocked, never a crash: {broken!r}",
                  diagnose(Repo(rp), more)[0]["state"] == BLOCKED)
        wf.write_text('{"reports": "Reports", "mukai": {}}\n')
        st = {r["id"]: r["state"] for r in diagnose(Repo(rp), more)}
        check("a non-object parent is invalid in diagnose", st["c.dir"] == INVALID)
        wrote = {w["id"]: w["wrote"] for w in fill(Repo(rp), more)}
        check("fill skips a non-object parent and still writes the rows after it",
              "c.dir" not in wrote and json.loads(wf.read_text())["mukai"]["autoEn"] is False)
        wf.write_text('{"mukai": {"autoEn": 1}}\n')
        check("1 is not true: a typed enum check", diagnose(Repo(rp), more)[0]["state"] == INVALID)
        try:
            set_value(Repo(rp), more, "c.flag", "1")
            check("set refuses 1 for a boolean option set", False)
        except Defect:
            pass
        wf.write_text('{"mukai": {"autoEn": false, "$autoEn": "keep false until the beta"}}\n')
        fill(Repo(rp), more)
        check("a maintainer's own note is never overwritten",
              json.loads(wf.read_text())["mukai"]["$autoEn"] == "keep false until the beta")
        wf.write_text('{"notifications": {"rungs": ["push", "pager"]}}\n')
        check("a subset item outside the options is invalid",
              {r["id"]: r["state"] for r in diagnose(Repo(rp), more)}["c.rungs"] == INVALID)
        (rp / "nen/contract.json").write_text('{"project": {"targets": {"beta": {"why": "non-production"}}}}\n')
        wf.write_text('{"deploy": {"defaultTarget": "gamma"}}\n')
        tgt = [dict(extra[1])]
        check("a default naming an undeclared target is invalid", diagnose(Repo(rp), tgt)[0]["state"] == INVALID)
        try:
            set_value(Repo(rp), tgt, "b.target", '"gamma"')
            check("set refuses an undeclared target", False)
        except Defect:
            pass

    # Phinks's corpus: duplicates, deep nesting, read-only, gates routing, a derived default never written
    with tempfile.TemporaryDirectory() as d:
        rp = Path(d)
        (rp / "nen").mkdir()
        wf = rp / "nen/workflow.json"
        wf.write_text('{"mukai": {"autoEn": true}, "mukai": {}}\n')
        check("duplicate keys are blocked", diagnose(Repo(rp), more)[0]["state"] == BLOCKED)
        wf.write_text("[" * 50000 + "]" * 50000)
        check("deep nesting is blocked, never a traceback", diagnose(Repo(rp), more)[0]["state"] == BLOCKED)
        gates_row = [{"id": "g", "file": "nen/gates.json", "path": "approval_policy", "domain": "review",
                      "kind": "open", "readers": ["sharingan"], "question": "?", "describe": "x"}]
        check("an absent gates.json is not routed to nen scaffold init",
              "does not write it" in diagnose(Repo(rp), gates_row)[0]["detail"])
        wf.write_text('{"mukai": {}}\n')
        os.chmod(rp / "nen", 0o555)
        try:
            fill(Repo(rp), more)
            check("a read-only nen/ is refused cleanly", False)
        except Defect:
            pass
        finally:
            os.chmod(rp / "nen", 0o755)
    shipped = {r["id"]: r for r in load_catalogue(root)[1]}
    check("profile.default is derived from profile.allowed, so fill never writes it",
          "default" not in shipped.get("workflow.profile.default", {"default": 1}))

    ghost = [{"id": "z.ghost", "file": "nen/workflow.json", "path": "nosuch.ghostKey", "domain": "development",
              "kind": "open", "default": 1, "readers": ["mukai"], "describe": "x", "source": "docs/WORKFLOW.md § 2"}]
    check("a docs-sourced default with no WORKFLOW row is a catalogue problem",
          any("ghostKey" in p for p in source_drift(root, ghost)))

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
    if opts.get("domain") and opts["domain"] not in cat.get("domains", {}):
        raise Defect(f"no domain {opts['domain']!r}; the catalogue declares {', '.join(cat.get('domains', {}))}")
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
        if not (root / "claude" / "skills" / opts["skill"] / "SKILL.md").is_file():
            raise Defect(f"no skill {opts['skill']!r} under {root / 'claude' / 'skills'} — a typo would read clean")
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
        print(f"set {res['file']} → {res['path']} = {shown(res['value'])}; "
              f"now run nen schema check --repo {repo_path}")
        return 0
    raise Defect(f"unknown mode {mode!r}")


try:
    sys.exit(main(sys.argv[1:]))
except Defect as exc:
    print(f"config_values.sh: {exc}", file=sys.stderr)
    sys.exit(2)
except Exception as exc:  # noqa: BLE001 -- exit 1 means "work remains"; a crash must never read as that
    print(f"config_values.sh: internal error, nothing further written: {type(exc).__name__}: {exc}", file=sys.stderr)
    sys.exit(2)
PY
