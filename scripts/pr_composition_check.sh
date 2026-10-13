#!/usr/bin/env bash
# pr_composition_check.sh — the drift guard for contracts/pr-composition.json (zheref/hatsu#171).
#
# WHAT IT PROTECTS. Three nen verbs run on every Hatsu pull request and take inputs nen ships none of:
# `nen pr body-check --requirements-from`, `nen gate derive --policy-paths/--process-paths` and
# `nen changelog fragment-required --spec-paths/--fragment-dir/--head-changelog`. They are declared
# once, in contracts/pr-composition.json (and the array body-check reads, contracts/pr-body.requirements.json),
# and every other surface cites that file. This guard fails when the declaration and the prose drift:
#
#   1. The declaration's shape: every key the readers use is present and typed; no gate row has both
#      sets empty (nen refuses that invocation); no entry carries whitespace or a comma (a value is
#      passed comma-joined); directSection.optOut is a line nen's fragment-required honours.
#   2. The requirements array against templates/pr-body.md: its names are the template's level-2
#      headings outside HTML comments and fences, in order, less `optionalHeadings`; each pattern
#      matches a body carrying its heading and misses one without it (a pattern that matches anyway
#      checks nothing). The template never carries the fragment opt-out phrase: nen 0.21.0 honours
#      it anywhere in a body, an HTML comment or a code fence included.
#   3. docs/WORKFLOW.md § Gate derivation (cut with fenced lines masked, so a `## ` inside a fence
#      ends nothing) cites the declaration; every directory prefix it names in backticks, of any
#      depth (`nen/`, `.github/workflows/`), is a declared member, and every file path it names
#      (a relative link's text read as its target) is covered by a declared set.
#   4. No second copy: a --policy-paths, --process-paths or --spec-paths flag followed by a literal
#      path list, anywhere in the canon prose — claude/, templates/, hooks/, contracts/, .github/,
#      docs/ and the root README.md and CONTRIBUTING.md. Records are exempt: docs/ab/, docs/history/,
#      docs/Loop/ and docs/ROSTER.md hold dated transcripts and rulings, CHANGELOG.md is history, and
#      surfaces/ is generated from claude/ (surface-mirror-guard owns its drift).
#   5. Every file in the declaration's `readers` exists and cites contracts/pr-composition.json.
#   Every path the declaration names (readers, the requirements file, the template) is confined to the
#   root -- never absolute, never `..`, never a link out -- and a scanned file that is not UTF-8 is a
#   finding, never a silent skip.
#
# WHO RUNS IT. The pr-composition-guard lane (`nen shu test --repo <hatsu> --lane pr-composition-guard`),
# through scripts/pr_composition_check_fixture.sh, which proves every refusal on throwaway trees and then
# runs this check on the repository itself. No installed copy executes it, so it is not in
# scripts/plugin_bump_check.sh's PLUGIN_SURFACE_GLOBS; the two files it guards are (contracts/*).
#
# USAGE
#   scripts/pr_composition_check.sh [--root <hatsu checkout>]   # default: this script's parent
#
# EXIT CODES
#   0  the declaration, the requirements, the template and the prose agree
#   1  drift: every finding is printed, never only the first
#   2  wiring: an unknown argument, a root that is not a Hatsu checkout, python3 absent, or a
#      declaration or requirements file that is missing or is not JSON
set -euo pipefail

root=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || { echo "pr_composition_check.sh: --root needs a path" >&2; exit 2; }; root="$2"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "pr_composition_check.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
if [ -z "$root" ]; then
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
[ -d "$root" ] || { echo "pr_composition_check.sh: root '$root' is not a directory" >&2; exit 2; }
[ -f "$root/.claude-plugin/plugin.json" ] || { echo "pr_composition_check.sh: '$root' is not a Hatsu checkout (no .claude-plugin/plugin.json)" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "pr_composition_check.sh: python3 is required" >&2; exit 2; }

exec python3 -I - "$root" <<'PY'
import json
import os
import re
import sys

root = sys.argv[1]
DECL = "contracts/pr-composition.json"
findings = []


def wiring(message):
    print(f"pr_composition_check.sh: {message}", file=sys.stderr)
    sys.exit(2)


def load(rel):
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        wiring(f"{rel} is missing")
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        wiring(f"{rel} is not readable JSON ({error})")


UNDECODABLE = object()
REAL_ROOT = os.path.realpath(root)


def read_text(rel):
    path = os.path.join(root, rel)
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except UnicodeDecodeError:
        return UNDECODABLE
    except OSError:
        return None


def confined(rel, where):
    """A declared path must stay inside the root: never absolute, never `..`, never a link out."""
    parts = rel.replace("\\", "/").split("/")
    real = os.path.realpath(os.path.join(root, rel))
    if os.path.isabs(rel) or ".." in parts or not (real == REAL_ROOT or real.startswith(REAL_ROOT + os.sep)):
        findings.append(f"{DECL}: {where} {rel!r} escapes the root (absolute, `..` or a link out); refused")
        return False
    return True


def covered(path, pattern):
    """nen's own matcher (src/changelog/fragment.ts, src/gate/derive.ts): `/`-suffix is a prefix, `*` crosses `/`."""
    if pattern.endswith("/"):
        return path.startswith(pattern)
    if "*" in pattern:
        return re.fullmatch(".*".join(re.escape(part) for part in pattern.split("*")), path) is not None
    return path == pattern


def path_list(value, where):
    if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
        findings.append(f"{DECL}: {where} is not an array of strings")
        return []
    for v in value:
        if v == "" or re.search(r"[\s,]", v):
            findings.append(f"{DECL}: {where} entry {v!r} is empty or carries whitespace or a comma (values are passed comma-joined)")
    return value


decl = load(DECL)
if not isinstance(decl, dict) or decl.get("contract") != "hatsu.pr-composition/v1":
    wiring(f"{DECL} is not a hatsu.pr-composition/v1 declaration")

# --- 1. the declaration's shape ------------------------------------------------------------------
body = decl.get("bodyRequirements") if isinstance(decl.get("bodyRequirements"), dict) else {}
for key in ("file", "template"):
    if not isinstance(body.get(key), str) or not body.get(key):
        findings.append(f"{DECL}: bodyRequirements.{key} is missing")
optional = body.get("optionalHeadings", [])
if not isinstance(optional, list) or not all(isinstance(v, str) for v in optional):
    findings.append(f"{DECL}: bodyRequirements.optionalHeadings is not an array of strings")
    optional = []

gate = decl.get("gateDerive") if isinstance(decl.get("gateDerive"), dict) else {}
rows = {k: v for k, v in gate.items() if not k.startswith("$")}
if not rows:
    findings.append(f"{DECL}: gateDerive declares no repository")
declared_prefixes = set()
for repo, row in rows.items():
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo) or not isinstance(row, dict):
        findings.append(f"{DECL}: gateDerive row {repo!r} is not an owner/name key holding an object")
        continue
    policy = path_list(row.get("policyPaths"), f"gateDerive.{repo}.policyPaths")
    process = path_list(row.get("processPaths"), f"gateDerive.{repo}.processPaths")
    if not policy and not process:
        findings.append(f"{DECL}: gateDerive.{repo} has both sets empty, which nen gate derive refuses")
    declared_prefixes.update(policy + process)

frag = decl.get("changelogFragment") if isinstance(decl.get("changelogFragment"), dict) else {}
if not path_list(frag.get("specPaths"), "changelogFragment.specPaths"):
    findings.append(f"{DECL}: changelogFragment.specPaths is empty")
for key in ("fragmentDir", "headChangelog"):
    if not isinstance(frag.get(key), str) or not frag.get(key):
        findings.append(f"{DECL}: changelogFragment.{key} is missing")
direct = frag.get("directSection") if isinstance(frag.get("directSection"), dict) else {}
opt_out = direct.get("optOut")
# nen's own test (src/changelog/fragment.ts): /no CHANGELOG entry:[ \t]*[^ \t\r\n]/i
if not isinstance(opt_out, str) or not re.match(r"no CHANGELOG entry:[ \t]*[^ \t\r\n]", opt_out, re.I) or "\n" in opt_out:
    findings.append(f"{DECL}: changelogFragment.directSection.optOut is not one `no CHANGELOG entry: <reason>` line")
if not isinstance(direct.get("when"), str) or not direct.get("when"):
    findings.append(f"{DECL}: changelogFragment.directSection.when is missing")

# --- 2. the requirements array against the template ----------------------------------------------
def template_headings(text):
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    headings, fence = [], None
    for line in text.splitlines():
        marker = re.match(r"\s*(`{3,}|~{3,})", line)
        if marker:
            run = marker.group(1)
            if fence is None:
                fence = run
            elif run[0] == fence[0] and len(run) >= len(fence):
                fence = None
            continue
        if fence is None:
            match = re.match(r"## (.+?)\s*$", line)
            if match:
                headings.append(match.group(1))
    return headings


if (isinstance(body.get("file"), str) and isinstance(body.get("template"), str)
        and confined(body["file"], "bodyRequirements.file") and confined(body["template"], "bodyRequirements.template")):
    requirements = load(body["file"])
    template = read_text(body["template"])
    if template is None or template is UNDECODABLE:
        findings.append(f"{body['template']}: missing, unreadable or not UTF-8 (bodyRequirements.template)")
        template = None
    else:
        # nen 0.21.0 honours the fragment opt-out phrase anywhere in a body -- inside an HTML comment or
        # a code fence too -- so the template a body is filled from must never carry it (zheref/hatsu#171).
        for found in re.finditer(r"no CHANGELOG entry:", template, re.I):
            line = template.count("\n", 0, found.start()) + 1
            findings.append(f"{body['template']}:{line}: carries the fragment opt-out phrase, which nen honours anywhere in a body, a kept comment or fence included")
    if template is None:
        pass  # named above
    elif not isinstance(requirements, list) or not requirements:
        findings.append(f"{body['file']}: not a non-empty JSON array of {{name, pattern}}")
    else:
        headings = template_headings(template)
        for name in optional:
            if name not in headings:
                findings.append(f"{DECL}: optional heading {name!r} is not a heading of {body['template']}")
        expected = [h for h in headings if h not in optional]
        names, compiled = [], []
        for index, entry in enumerate(requirements):
            if not isinstance(entry, dict) or not isinstance(entry.get("name"), str) or not isinstance(entry.get("pattern"), str):
                findings.append(f"{body['file']}: entry {index} is not {{name, pattern}}")
                continue
            try:
                compiled.append((entry["name"], re.compile(entry["pattern"], re.I | re.M)))
            except re.error as error:
                findings.append(f"{body['file']}: {entry['name']!r} has an unparseable pattern ({error})")
            names.append(entry["name"])
        if names != expected:
            findings.append(f"{body['file']}: names {names} are not {body['template']}'s required headings {expected}, in order")
        full = "".join(f"## {h}\n\nfilled.\n\n" for h in expected)
        for name, regex in compiled:
            if not regex.search(full):
                findings.append(f"{body['file']}: {name!r} does not match a body that carries `## {name}`")
            without = "".join(f"## {h}\n\nfilled.\n\n" for h in expected if h != name)
            if regex.search(without):
                findings.append(f"{body['file']}: {name!r} matches a body without `## {name}`, so it checks nothing")

# --- 3 and 4. the WORKFLOW section, and no second copy anywhere -----------------------------------
FLAG = re.compile(r"--(policy-paths|process-paths|spec-paths)(?:=|\s+)[\"']?([^\s\"'`]*)")


def literal(value):
    return bool(re.match(r"(?!\.\.)[A-Za-z0-9_.*/]", value) and re.search(r"[A-Za-z0-9]", value)
                and re.search(r"[/,]|\.[A-Za-z]", value))


def unfenced_lines(text):
    """Each line, with a fenced block's lines reported as None so a `## ` inside a fence ends nothing."""
    out, fence = [], None
    for line in text.split("\n"):
        marker = re.match(r"\s*(`{3,}|~{3,})", line)
        if fence is not None:
            if marker and marker.group(1)[0] == fence[0] and len(marker.group(1)) >= len(fence):
                fence = None
            out.append(None)
            continue
        if marker:
            fence = marker.group(1)
            out.append(None)
            continue
        out.append(line)
    return out


workflow = read_text("docs/WORKFLOW.md")
section = None
if workflow is UNDECODABLE:
    findings.append("docs/WORKFLOW.md: not UTF-8, so it could not be read")
elif workflow is not None:
    lines, masked = workflow.split("\n"), unfenced_lines(workflow)
    start = next((i for i, l in enumerate(masked) if l is not None and re.fullmatch(r"## Gate derivation\s*", l)), None)
    if start is not None:
        end = next((i for i in range(start + 1, len(masked)) if masked[i] is not None and masked[i].startswith("## ")), len(lines))
        section = "\n".join(lines[start + 1:end])
if section is None:
    findings.append("docs/WORKFLOW.md: no `## Gate derivation` section")
else:
    if DECL not in section:
        findings.append(f"docs/WORKFLOW.md § Gate derivation: does not cite {DECL}")
    PATHLIKE = r"[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*/?"
    named = set()
    # A relative link's text names the path its target resolves to, read from docs/.
    for text, target in re.findall(r"\[`([^`\n]+)`\]\(([^)#\s]+)[^)]*\)", section):
        if re.fullmatch(PATHLIKE, text) and "://" not in target:
            named.add(os.path.normpath(os.path.join("docs", target)).replace(os.sep, "/"))
    unlinked = re.sub(r"\[`[^`\n]+`\]\([^)]*\)", "", section)
    for token in re.findall(r"`([^`\n]+)`", unlinked):
        # a directory (`/`-suffixed) or a file with an extension; an owner/name slug is neither
        if re.fullmatch(PATHLIKE, token) and (token.endswith("/") or re.search(r"\.[A-Za-z][A-Za-z0-9]*$", token)):
            named.add(token)
    for token in sorted(named):
        if token.endswith("/"):
            if token not in declared_prefixes:
                findings.append(f"docs/WORKFLOW.md § Gate derivation: names `{token}`, which no declared gate set carries")
        elif not any(covered(token, pattern) for pattern in declared_prefixes):
            findings.append(f"docs/WORKFLOW.md § Gate derivation: names `{token}`, which no declared gate set covers")

EXEMPT_DIRS = ("docs/ab/", "docs/history/", "docs/Loop/", "surfaces/", ".git/", ".nen/", "node_modules/")
EXEMPT_FILES = {"docs/ROSTER.md", "CHANGELOG.md", DECL}
SCANNED_TOP = ("claude/", "templates/", "hooks/", "contracts/", ".github/", "docs/")
SCANNED_ROOT = {"README.md", "CONTRIBUTING.md"}
for dirpath, dirnames, filenames in os.walk(root):
    rel_dir = os.path.relpath(dirpath, root).replace(os.sep, "/")
    rel_dir = "" if rel_dir == "." else rel_dir + "/"
    dirnames[:] = [d for d in dirnames if not (rel_dir + d + "/").startswith(EXEMPT_DIRS) and not os.path.islink(os.path.join(dirpath, d))]
    for name in sorted(filenames):
        rel = rel_dir + name
        if rel in EXEMPT_FILES or not name.endswith((".md", ".mdc", ".json", ".yml", ".yaml", ".toml", ".sh")):
            continue
        if not (rel in SCANNED_ROOT or rel.startswith(SCANNED_TOP)):
            continue
        text = read_text(rel)
        if text is UNDECODABLE:
            findings.append(f"{rel}: not UTF-8, so it could not be scanned for a copy")
            continue
        if text is None:
            continue
        for found in FLAG.finditer(text):
            if literal(found.group(2)):
                line = text.count("\n", 0, found.start()) + 1
                findings.append(f"{rel}:{line}: --{found.group(1)} carries a literal path list ({found.group(2)}); cite {DECL} instead")

# --- 5. every reader cites the declaration ------------------------------------------------------
readers = decl.get("readers")
if not isinstance(readers, list) or not readers or not all(isinstance(r, str) for r in readers):
    findings.append(f"{DECL}: readers is not a non-empty array of paths")
else:
    for rel in readers:
        if not confined(rel, "reader"):
            continue
        text = read_text(rel)
        if text is UNDECODABLE:
            findings.append(f"{rel}: listed in readers but not UTF-8")
        elif text is None:
            findings.append(f"{rel}: listed in readers but missing")
        elif "pr-composition.json" not in text:
            findings.append(f"{rel}: listed in readers but does not cite {DECL}")

if findings:
    for finding in findings:
        print(f"drift: {finding}")
    print(f"pr-composition: {len(findings)} finding(s)")
    sys.exit(1)
print(f"pr-composition ok: {len(rows)} gate row(s), {len(readers)} reader(s) citing {DECL}, no literal path-set copy")
PY
