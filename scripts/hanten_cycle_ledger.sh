#!/usr/bin/env bash
# hanten_cycle_ledger.sh — per-effort Hanten reviewer budgets (zheref/hatsu#63).
#
# Hatsu owns this file. Nen does not. The skill
# `claude/skills/hanten/SKILL.md` § 2a is the policy; this script is the writer
# so used/max cannot be counted in prose and forgotten on the next remediation.
#
# Usage:
#   scripts/hanten_cycle_ledger.sh decide --repo <path> --branch <name> --applicable <csv>
#   scripts/hanten_cycle_ledger.sh record --repo <path> --branch <name> --persona <id> --outcome ran|skipped-exhausted
#   scripts/hanten_cycle_ledger.sh show   --repo <path> --branch <name>
#   scripts/hanten_cycle_ledger.sh --self-test
set -euo pipefail

python3 - "$@" <<'PY'
import json, os, sys, tempfile, time
from datetime import datetime, timezone
from pathlib import Path

CONTRACT = "hatsu.hanten.cycle/v0.1"
MAXIMA = {
    "feitan": 1,
    "chrollo": 1,
    "phinks": 1,
    "hisoka": 2,
    "uvogin": 3,
}
PERSONAS = tuple(MAXIMA)

def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

def slug(branch: str) -> str:
    return branch.replace("/", "-")

def ledger_path(repo: Path, branch: str) -> Path:
    return repo / ".nen" / "hanten" / f"{slug(branch)}.cycle.json"

def empty_reviewers():
    return {p: {"max": MAXIMA[p], "used": 0, "invocations": []} for p in PERSONAS}

def new_doc(branch: str) -> dict:
    now = utc_now()
    return {
        "contract": CONTRACT,
        "branch": branch,
        "slug": slug(branch),
        "openedAt": now,
        "updatedAt": now,
        "reviewers": empty_reviewers(),
    }

def load_or_create(repo: Path, branch: str) -> dict:
    path = ledger_path(repo, branch)
    if not path.is_file():
        return new_doc(branch)
    doc = json.loads(path.read_text())
    if doc.get("contract") != CONTRACT:
        raise SystemExit(f"hanten_cycle_ledger: {path} is not {CONTRACT}")
    if doc.get("branch") != branch:
        raise SystemExit(f"hanten_cycle_ledger: ledger branch {doc.get('branch')!r} is not {branch!r}")
    reviewers = doc.setdefault("reviewers", {})
    for p in PERSONAS:
        row = reviewers.get(p) or {"max": MAXIMA[p], "used": 0, "invocations": []}
        row["max"] = MAXIMA[p]
        row.setdefault("used", 0)
        row.setdefault("invocations", [])
        reviewers[p] = row
    return doc

def save(repo: Path, doc: dict) -> Path:
    path = ledger_path(repo, doc["branch"])
    path.parent.mkdir(parents=True, exist_ok=True)
    doc["updatedAt"] = utc_now()
    tmp = path.with_suffix(".cycle.json.tmp")
    tmp.write_text(json.dumps(doc, indent=2) + "\n")
    tmp.replace(path)
    return path

def parse_applicable(raw: str) -> list[str]:
    if not raw.strip():
        return []
    out = []
    seen = set()
    for part in raw.split(","):
        p = part.strip().lower()
        if not p:
            continue
        if p not in MAXIMA:
            raise SystemExit(
                f"hanten_cycle_ledger: persona {p!r} is not one of {', '.join(PERSONAS)}"
            )
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out

def decide(doc: dict, applicable: list[str]) -> dict:
    rows = []
    for p in PERSONAS:
        row = doc["reviewers"][p]
        used, mx = row["used"], row["max"]
        if p not in applicable:
            action = "not-applicable"
        elif used >= mx:
            action = "skip-exhausted"
        else:
            action = "raise"
        rows.append({
            "persona": p,
            "applicable": p in applicable,
            "used": used,
            "max": mx,
            "remaining": max(0, mx - used),
            "action": action,
        })
    return {
        "contract": CONTRACT,
        "branch": doc["branch"],
        "path": None,
        "reviewers": rows,
        "raise": [r["persona"] for r in rows if r["action"] == "raise"],
        "skippedExhausted": [r["persona"] for r in rows if r["action"] == "skip-exhausted"],
    }

def record(doc: dict, persona: str, outcome: str) -> dict:
    persona = persona.lower()
    if persona not in MAXIMA:
        raise SystemExit(f"hanten_cycle_ledger: persona {persona!r} is not a cycle reviewer")
    if outcome not in ("ran", "skipped-exhausted"):
        raise SystemExit("hanten_cycle_ledger: --outcome is ran or skipped-exhausted")
    row = doc["reviewers"][persona]
    if outcome == "ran" and row["used"] >= row["max"]:
        raise SystemExit(
            f"hanten_cycle_ledger: {persona} is exhausted ({row['used']}/{row['max']}); "
            "record skipped-exhausted, do not raise"
        )
    if outcome == "ran":
        row["used"] += 1
    row["invocations"].append({"at": utc_now(), "outcome": outcome})
    return doc

def parse_args(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__ if False else "", end="")
        raise SystemExit(
            "hanten_cycle_ledger.sh decide|record|show|--self-test "
            "[--repo PATH --branch NAME --applicable CSV --persona ID --outcome ran|skipped-exhausted]"
        )
    cmd = argv[0]
    opts = {}
    i = 1
    while i < len(argv):
        if argv[i] in ("--repo", "--branch", "--applicable", "--persona", "--outcome") and i + 1 < len(argv):
            opts[argv[i][2:]] = argv[i + 1]
            i += 2
            continue
        raise SystemExit(f"hanten_cycle_ledger: unexpected argument {argv[i]!r}")
    return cmd, opts

def require(opts, *keys):
    missing = [k for k in keys if not opts.get(k)]
    if missing:
        raise SystemExit("hanten_cycle_ledger: missing " + ", ".join("--" + k for k in missing))

def self_test() -> int:
    failures = []
    def check(name, cond, detail=""):
        if cond:
            print(f"ok    {name}")
        else:
            print(f"FAIL  {name}{': ' + detail if detail else ''}")
            failures.append(name)

    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        branch = "grok/kurapika/demo-cycle"
        all_five = list(PERSONAS)
        doc = load_or_create(repo, branch)
        save(repo, doc)

        # Entry 1: every reviewer applicable and within budget.
        d1 = decide(doc, all_five)
        check("entry-1-raise-all-five", d1["raise"] == all_five, str(d1["raise"]))
        for p in all_five:
            record(doc, p, "ran")
        save(repo, doc)

        # Remediation does not reset.
        doc2 = load_or_create(repo, branch)
        check("remediation-keeps-used", all(doc2["reviewers"][p]["used"] == 1 for p in all_five))

        # Entry 2: Chrollo/Feitan/Phinks exhausted; Hisoka and Uvogin still raise.
        d2 = decide(doc2, all_five)
        check("entry-2-chrollo-exhausted", d2["skippedExhausted"] == ["feitan", "chrollo", "phinks"], str(d2["skippedExhausted"]))
        check("entry-2-hisoka-uvogin-raise", d2["raise"] == ["hisoka", "uvogin"], str(d2["raise"]))
        record(doc2, "hisoka", "ran")
        record(doc2, "uvogin", "ran")
        save(repo, doc2)

        # Entry 3: Hisoka now exhausted (2/2); Uvogin still has one (2/3).
        doc3 = load_or_create(repo, branch)
        d3 = decide(doc3, all_five)
        check("entry-3-hisoka-exhausted", "hisoka" in d3["skippedExhausted"] and "hisoka" not in d3["raise"])
        check("entry-3-uvogin-raise", d3["raise"] == ["uvogin"], str(d3["raise"]))
        check("entry-3-chrollo-still-one", doc3["reviewers"]["chrollo"]["used"] == 1 and doc3["reviewers"]["chrollo"]["max"] == 1)
        record(doc3, "uvogin", "ran")
        save(repo, doc3)

        # Entry 4: Uvogin hits 3/3; nobody raises.
        doc4 = load_or_create(repo, branch)
        d4 = decide(doc4, all_five)
        check("entry-4-no-raises", d4["raise"] == [], str(d4["raise"]))
        check("entry-4-uvogin-exhausted", "uvogin" in d4["skippedExhausted"])
        check(
            "maxima",
            doc4["reviewers"]["feitan"]["used"] == 1
            and doc4["reviewers"]["chrollo"]["used"] == 1
            and doc4["reviewers"]["phinks"]["used"] == 1
            and doc4["reviewers"]["hisoka"]["used"] == 2
            and doc4["reviewers"]["uvogin"]["used"] == 3,
            json.dumps({p: doc4["reviewers"][p]["used"] for p in PERSONAS}),
        )

        # Recording a raise past the cap is refused.
        try:
            record(doc4, "chrollo", "ran")
            check("refuse-second-chrollo-raise", False, "record ran succeeded")
        except SystemExit as e:
            check("refuse-second-chrollo-raise", "exhausted" in str(e))

        # Inapplicable reviewer is not mandatory; later applicability still has budget.
        other = "opus/kurapika/other-effort"
        doc_b = load_or_create(repo, other)
        d_ui = decide(doc_b, ["hisoka"])
        check("inapplicable-chrollo-not-raised", "chrollo" not in d_ui["raise"] and d_ui["reviewers"][1]["action"] == "not-applicable")
        record(doc_b, "hisoka", "ran")
        save(repo, doc_b)
        doc_b = load_or_create(repo, other)
        d_arch = decide(doc_b, ["chrollo"])
        check("later-applicable-chrollo-still-raises", d_arch["raise"] == ["chrollo"], str(d_arch["raise"]))

        # A new effort (new branch) is a new cycle.
        fresh = load_or_create(repo, "grok/kurapika/fresh-effort")
        d_fresh = decide(fresh, ["chrollo"])
        check("new-branch-resets-budget", d_fresh["raise"] == ["chrollo"] and fresh["reviewers"]["chrollo"]["used"] == 0)

        # Same branch across a "session resume" is the same file.
        resumed = load_or_create(repo, branch)
        check("resume-same-file", resumed["reviewers"]["chrollo"]["used"] == 1)

    if failures:
        print(f"{len(failures)} failed", file=sys.stderr)
        return 1
    print(f"self-test: {15 - len(failures)} passed, {len(failures)} failed")
    return 0

def main(argv):
    if argv and argv[0] == "--self-test":
        raise SystemExit(self_test())
    cmd, opts = parse_args(argv)
    if cmd == "--self-test":
        raise SystemExit(self_test())
    require(opts, "repo", "branch")
    repo = Path(opts["repo"]).resolve()
    if not repo.is_dir():
        raise SystemExit(f"hanten_cycle_ledger: --repo {repo} is not a directory")
    branch = opts["branch"]
    doc = load_or_create(repo, branch)
    if cmd == "show":
        path = save(repo, doc) if not ledger_path(repo, branch).is_file() else ledger_path(repo, branch)
        out = dict(doc)
        out["path"] = str(path)
        json.dump(out, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    if cmd == "decide":
        applicable = parse_applicable(opts.get("applicable", ""))
        path = save(repo, doc)
        result = decide(doc, applicable)
        result["path"] = str(path)
        json.dump(result, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    if cmd == "record":
        require(opts, "persona", "outcome")
        record(doc, opts["persona"], opts["outcome"])
        path = save(repo, doc)
        json.dump({
            "path": str(path),
            "persona": opts["persona"].lower(),
            "outcome": opts["outcome"],
            "used": doc["reviewers"][opts["persona"].lower()]["used"],
            "max": doc["reviewers"][opts["persona"].lower()]["max"],
        }, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    raise SystemExit(f"hanten_cycle_ledger: unknown command {cmd!r}")

if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except BrokenPipeError:
        pass
PY
