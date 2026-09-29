#!/usr/bin/env bash
# hanten_cycle_ledger.sh — per-effort Hanten reviewer budgets (zheref/hatsu#63).
#
# Hatsu owns this file. Nen does not. The skill
# `claude/skills/hanten/SKILL.md` § 2b is the policy; this script is the writer
# so used/max cannot be counted in prose and forgotten on the next remediation.
#
# AN EFFORT IS A BRANCH PLUS ITS PULL REQUEST (maintainer's ruling of
# 2026-09-28, docs/ROSTER.md § Rulings of 2026-09-26/27/28, ruling 9): the
# ledger is keyed `<branch-slug>` until a PR exists and `<branch-slug>-pr<N>`
# once one does, so a new PR number on the same branch name is a new ledger
# and every reviewer starts fresh. `init` refuses only the SAME key twice.
# The maxima are the target repository's own `nen/workflow.json` ->
# `review.scopes.<scope>.budget`, matched by each scope's `persona`; a persona
# no scope declares falls back to the built-in default below, and the ledger
# records which source each maximum came from (`budgetSource`).
#
# Usage:
#   scripts/hanten_cycle_ledger.sh init   --repo <path> --branch <name> [--pr <n>]
#   scripts/hanten_cycle_ledger.sh decide --repo <path> --branch <name> [--pr <n>] --applicable <csv>
#   scripts/hanten_cycle_ledger.sh record --repo <path> --branch <name> [--pr <n>] --persona <id> --outcome ran|skipped-exhausted
#   scripts/hanten_cycle_ledger.sh show   --repo <path> --branch <name> [--pr <n>]
#   scripts/hanten_cycle_ledger.sh --self-test
set -euo pipefail

python3 - "$@" <<'PY'
import json
import os
import sys
import tempfile
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

if os.name == "nt":
    import msvcrt
    _windows_thread_lock = threading.Lock()
else:
    import fcntl

CONTRACT = "hatsu.hanten.cycle/v0.1"
DEFAULT_MAXIMA = {
    "nobunaga": 2,
    "feitan": 1,
    "chrollo": 1,
    "phinks": 1,
    "hisoka": 2,
    "uvogin": 3,
}
PERSONAS = tuple(DEFAULT_MAXIMA)
# Filled per invocation from the target's nen/workflow.json (see budgets()).
MAXIMA = dict(DEFAULT_MAXIMA)
BUDGET_SOURCE = {p: "default" for p in PERSONAS}


def budgets(repo: Path) -> None:
    """Read review.scopes.<scope>.budget by persona from the TARGET's nen/workflow.json.

    A missing file, an unreadable file or a scope without a numeric budget
    leaves that persona on the built-in default and says so in budgetSource.
    A persona claimed by MORE THAN ONE scope (phinks: release and surfaces,
    zheref/hatsu#73) keeps ONE budget -- the smallest declared, so no scope's
    ceiling is silently exceeded -- and budgetSource names every scope that
    declared it; the last declaration never wins in silence.
    """
    global MAXIMA, BUDGET_SOURCE
    MAXIMA = dict(DEFAULT_MAXIMA)
    BUDGET_SOURCE = {p: "default" for p in PERSONAS}
    path = repo / "nen" / "workflow.json"
    if not path.is_file():
        return
    try:
        scopes = json.loads(path.read_text()).get("review", {}).get("scopes", {})
    except (ValueError, AttributeError):
        return
    if not isinstance(scopes, dict):
        return
    seen: dict[str, list[str]] = {}
    for scope, row in scopes.items():
        if not isinstance(row, dict):
            continue
        persona = str(row.get("persona", "")).lower()
        budget = row.get("budget")
        if persona in DEFAULT_MAXIMA and isinstance(budget, int) and not isinstance(budget, bool) and budget >= 0:
            if persona in seen:
                MAXIMA[persona] = min(MAXIMA[persona], budget)
                seen[persona].append(scope)
            else:
                MAXIMA[persona] = budget
                seen[persona] = [scope]
            BUDGET_SOURCE[persona] = "nen/workflow.json review.scopes." + "+".join(seen[persona]) + ".budget" + (" (min of the scopes named)" if len(seen[persona]) > 1 else "")


def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def slug(branch: str, pr: str | None = None) -> str:
    base = branch.replace("/", "-")
    return f"{base}-pr{pr}" if pr else base


def ledger_path(repo: Path, branch: str, pr: str | None = None) -> Path:
    return repo / ".nen" / "hanten" / f"{slug(branch, pr)}.cycle.json"


def lock_path(repo: Path, branch: str, pr: str | None = None) -> Path:
    return repo / ".nen" / "hanten" / f"{slug(branch, pr)}.cycle.lock"


def parse_pr(raw: str | None) -> str | None:
    if raw is None or not str(raw).strip():
        return None
    value = str(raw).strip().lstrip("#")
    if not value.isdigit() or int(value) <= 0:
        refuse(f"hanten_cycle_ledger: --pr must be a positive PR number, got {raw!r}")
    return str(int(value))


def refuse(msg: str):
    print(msg, file=sys.stderr)
    raise SystemExit(2)


class LedgerLock:
    """Exclusive file lock across load, mutation, and save for one branch ledger."""

    def __init__(self, repo: Path, branch: str, pr: str | None = None):
        self.path = lock_path(repo, branch, pr)
        self.fd = None
        self.thread_lock_held = False

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.fd = os.open(self.path, os.O_CREAT | os.O_RDWR, 0o644)
        try:
            if os.name == "nt":
                # Windows byte-range locks need a byte to lock. The thread lock
                # also serializes callers inside this Python process.
                _windows_thread_lock.acquire()
                self.thread_lock_held = True
                if os.fstat(self.fd).st_size == 0:
                    os.write(self.fd, b"\0")
                os.lseek(self.fd, 0, os.SEEK_SET)
                deadline = time.monotonic() + 30
                while True:
                    try:
                        msvcrt.locking(self.fd, msvcrt.LK_NBLCK, 1)
                        break
                    except OSError:
                        if time.monotonic() >= deadline:
                            raise
                        time.sleep(0.05)
            else:
                fcntl.flock(self.fd, fcntl.LOCK_EX)
        except BaseException:
            os.close(self.fd)
            self.fd = None
            if self.thread_lock_held:
                _windows_thread_lock.release()
                self.thread_lock_held = False
            raise
        return self

    def __exit__(self, *exc):
        if self.fd is not None:
            try:
                if os.name == "nt":
                    os.lseek(self.fd, 0, os.SEEK_SET)
                    msvcrt.locking(self.fd, msvcrt.LK_UNLCK, 1)
                else:
                    fcntl.flock(self.fd, fcntl.LOCK_UN)
            finally:
                os.close(self.fd)
                self.fd = None
                if self.thread_lock_held:
                    _windows_thread_lock.release()
                    self.thread_lock_held = False


def empty_reviewers():
    return {p: {"max": MAXIMA[p], "used": 0, "budgetSource": BUDGET_SOURCE[p], "invocations": []} for p in PERSONAS}


def new_doc(branch: str, pr: str | None = None) -> dict:
    now = utc_now()
    return {
        "contract": CONTRACT,
        "branch": branch,
        "pr": int(pr) if pr else None,
        "slug": slug(branch, pr),
        "openedAt": now,
        "updatedAt": now,
        "reviewers": empty_reviewers(),
    }


def _hydrate(doc: dict, path: Path, branch: str, pr: str | None = None) -> dict:
    if doc.get("contract") != CONTRACT:
        refuse(f"hanten_cycle_ledger: {path} is not {CONTRACT}")
    if doc.get("branch") != branch:
        refuse(f"hanten_cycle_ledger: ledger branch {doc.get('branch')!r} is not {branch!r}")
    want_pr = int(pr) if pr else None
    if doc.get("pr") != want_pr:
        refuse(f"hanten_cycle_ledger: ledger pr {doc.get('pr')!r} is not {want_pr!r}")
    reviewers = doc.get("reviewers")
    if not isinstance(reviewers, dict):
        refuse(f"hanten_cycle_ledger: {path} has no reviewer count map; restore the original ledger")
    for p in PERSONAS:
        row = reviewers.get(p)
        if (not isinstance(row, dict) or type(row.get("used")) is not int
                or row["used"] < 0 or not isinstance(row.get("invocations"), list)):
            refuse(f"hanten_cycle_ledger: {path} has no valid {p} review history; restore it without resetting used counts")
        outcomes = [entry.get("outcome") if isinstance(entry, dict) else None for entry in row["invocations"]]
        if any(outcome not in ("ran", "skipped-exhausted") for outcome in outcomes) or outcomes.count("ran") != row["used"]:
            refuse(f"hanten_cycle_ledger: {path} has inconsistent {p} used count and invocation history; restore the original ledger")
        row["max"] = MAXIMA[p]
        row["budgetSource"] = BUDGET_SOURCE[p]
    return doc


def load(repo: Path, branch: str, pr: str | None = None) -> dict:
    path = ledger_path(repo, branch, pr)
    if not path.is_file():
        refuse(
            f"hanten_cycle_ledger: no ledger at {path} — "
            "init if this effort (this branch and this PR) is new; if reviews already ran "
            "under this key, the ledger is lost and must not get a fresh budget"
        )
    doc = json.loads(path.read_text())
    return _hydrate(doc, path, branch, pr)


def save(repo: Path, doc: dict) -> Path:
    path = ledger_path(repo, doc["branch"], str(doc["pr"]) if doc.get("pr") else None)
    path.parent.mkdir(parents=True, exist_ok=True)
    doc["updatedAt"] = utc_now()
    fd, tmp_name = tempfile.mkstemp(
        prefix=f"{path.name}.",
        suffix=".tmp",
        dir=path.parent,
    )
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(json.dumps(doc, indent=2) + "\n")
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise
    return path


def init(repo: Path, branch: str, pr: str | None = None, *, first_cycle_recovery: bool = False) -> dict:
    path = ledger_path(repo, branch, pr)
    if path.is_file():
        refuse(f"hanten_cycle_ledger: ledger already exists at {path}")
    doc = new_doc(branch, pr)
    if first_cycle_recovery:
        doc["openedAs"] = "confirmed-first-cycle-recovery"
    save(repo, doc)
    return doc


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
            refuse(
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
        "pr": doc.get("pr"),
        "path": None,
        "reviewers": rows,
        "raise": [r["persona"] for r in rows if r["action"] == "raise"],
        "skippedExhausted": [r["persona"] for r in rows if r["action"] == "skip-exhausted"],
    }


def record(doc: dict, persona: str, outcome: str) -> dict:
    persona = persona.lower()
    if persona not in MAXIMA:
        refuse(f"hanten_cycle_ledger: persona {persona!r} is not a cycle reviewer")
    if outcome not in ("ran", "skipped-exhausted"):
        refuse("hanten_cycle_ledger: --outcome is ran or skipped-exhausted")
    row = doc["reviewers"][persona]
    if outcome == "ran" and row["used"] >= row["max"]:
        refuse(
            f"hanten_cycle_ledger: {persona} is exhausted ({row['used']}/{row['max']}); "
            "record skipped-exhausted, do not raise"
        )
    if outcome == "skipped-exhausted" and row["used"] < row["max"]:
        refuse(
            f"hanten_cycle_ledger: {persona} still has budget "
            f"({row['used']}/{row['max']}); skipped-exhausted is only for used >= max"
        )
    if outcome == "ran":
        row["used"] += 1
    row["invocations"].append({"at": utc_now(), "outcome": outcome})
    return doc


def parse_args(argv):
    if not argv or argv[0] in ("-h", "--help"):
        refuse(
            "hanten_cycle_ledger.sh init|recover-first|decide|record|show|--self-test "
            "[--repo PATH --branch NAME --applicable CSV --persona ID --outcome ran|skipped-exhausted]"
        )
    cmd = argv[0]
    opts = {}
    i = 1
    while i < len(argv):
        if argv[i] in ("--repo", "--branch", "--pr", "--applicable", "--persona", "--outcome") and i + 1 < len(argv):
            opts[argv[i][2:]] = argv[i + 1]
            i += 2
            continue
        if argv[i] == "--confirmed-first-cycle":
            opts["confirmed-first-cycle"] = True
            i += 1
            continue
        refuse(f"hanten_cycle_ledger: unexpected argument {argv[i]!r}")
    return cmd, opts


def require(opts, *keys):
    missing = [k for k in keys if not opts.get(k)]
    if missing:
        refuse("hanten_cycle_ledger: missing " + ", ".join("--" + k for k in missing))


def self_test() -> int:
    failures = []
    passed = 0

    def check(name, cond, detail=""):
        nonlocal passed
        if cond:
            print(f"ok    {name}")
            passed += 1
        else:
            print(f"FAIL  {name}{': ' + detail if detail else ''}")
            failures.append(name)

    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        budgets(repo)
        check("no-workflow-json-uses-defaults", MAXIMA == DEFAULT_MAXIMA and all(v == "default" for v in BUDGET_SOURCE.values()))
        branch = "grok/kurapika/demo-cycle"
        all_reviewers = list(PERSONAS)

        try:
            load(repo, branch)
            check("refuse-missing-as-new-cycle", False, "load succeeded")
        except SystemExit as e:
            check("refuse-missing-as-new-cycle", e.code == 2, str(e))

        with LedgerLock(repo, branch):
            init(repo, branch)

        recovery_branch = "grok/kurapika/first-review"
        parsed, recovery_opts = parse_args(["recover-first", "--repo", str(repo), "--branch", recovery_branch,
                                           "--confirmed-first-cycle"])
        check("recovery-command-requires-explicit-flag", parsed == "recover-first" and recovery_opts.get("confirmed-first-cycle") is True)
        try:
            main(["recover-first", "--repo", str(repo), "--branch", recovery_branch])
            check("recover-first-without-confirmation-refused", False, "command succeeded")
        except SystemExit as e:
            check("recover-first-without-confirmation-refused", e.code == 2 and not ledger_path(repo, recovery_branch).exists())
        with LedgerLock(repo, recovery_branch):
            recovered = init(repo, recovery_branch, first_cycle_recovery=True)
        check("first-cycle-recovery-is-audited", recovered.get("openedAs") == "confirmed-first-cycle-recovery"
              and load(repo, recovery_branch).get("openedAs") == "confirmed-first-cycle-recovery")
        try:
            with LedgerLock(repo, recovery_branch):
                init(repo, recovery_branch, first_cycle_recovery=True)
            check("recovery-never-replaces-an-existing-ledger", False, "recovery succeeded")
        except SystemExit as e:
            check("recovery-never-replaces-an-existing-ledger", e.code == 2, str(e))
        recovered["reviewers"] = {}
        save(repo, recovered)
        try:
            load(repo, recovery_branch)
            check("incomplete-count-map-refused", False, "load succeeded")
        except SystemExit as e:
            check("incomplete-count-map-refused", e.code == 2, str(e))
        recovered["reviewers"] = empty_reviewers()
        recovered["reviewers"]["nobunaga"]["invocations"] = [{"outcome": "ran"}]
        save(repo, recovered)
        try:
            load(repo, recovery_branch)
            check("inconsistent-used-count-refused", False, "load succeeded")
        except SystemExit as e:
            check("inconsistent-used-count-refused", e.code == 2, str(e))

        try:
            with LedgerLock(repo, branch):
                init(repo, branch)
            check("refuse-second-init", False, "init succeeded")
        except SystemExit as e:
            check("refuse-second-init", e.code == 2, str(e))

        with LedgerLock(repo, branch):
            doc = load(repo, branch)

        # Entry 1: every reviewer applicable and within budget.
        d1 = decide(doc, all_reviewers)
        check("entry-1-raise-all-reviewers", d1["raise"] == all_reviewers, str(d1["raise"]))
        for p in all_reviewers:
            record(doc, p, "ran")
        with LedgerLock(repo, branch):
            save(repo, doc)

        # Remediation does not reset.
        with LedgerLock(repo, branch):
            doc2 = load(repo, branch)
        check("remediation-keeps-used", all(doc2["reviewers"][p]["used"] == 1 for p in all_reviewers))

        try:
            record(doc2, "hisoka", "skipped-exhausted")
            check("refuse-skipped-exhausted-under-budget", False, "record succeeded")
        except SystemExit as e:
            check("refuse-skipped-exhausted-under-budget", e.code == 2, str(e))

        # Entry 2: Chrollo/Feitan/Phinks exhausted; Nobunaga, Hisoka and Uvogin still raise.
        d2 = decide(doc2, all_reviewers)
        check("entry-2-chrollo-exhausted", d2["skippedExhausted"] == ["feitan", "chrollo", "phinks"], str(d2["skippedExhausted"]))
        check("entry-2-nobunaga-hisoka-uvogin-raise", d2["raise"] == ["nobunaga", "hisoka", "uvogin"], str(d2["raise"]))
        record(doc2, "feitan", "skipped-exhausted")
        record(doc2, "nobunaga", "ran")
        record(doc2, "hisoka", "ran")
        record(doc2, "uvogin", "ran")
        with LedgerLock(repo, branch):
            save(repo, doc2)

        leftovers = list((repo / ".nen" / "hanten").glob("*.tmp"))
        check("unique-tmp-cleaned", leftovers == [], str(leftovers))

        # Entry 3: Hisoka now exhausted (2/2); Uvogin still has one (2/3).
        with LedgerLock(repo, branch):
            doc3 = load(repo, branch)
        d3 = decide(doc3, all_reviewers)
        check("entry-3-hisoka-exhausted", "hisoka" in d3["skippedExhausted"] and "hisoka" not in d3["raise"])
        check("entry-3-uvogin-raise", d3["raise"] == ["uvogin"], str(d3["raise"]))
        check("entry-3-chrollo-still-one", doc3["reviewers"]["chrollo"]["used"] == 1 and doc3["reviewers"]["chrollo"]["max"] == 1)
        record(doc3, "uvogin", "ran")
        with LedgerLock(repo, branch):
            save(repo, doc3)

        # Entry 4: Uvogin hits 3/3; nobody raises.
        with LedgerLock(repo, branch):
            doc4 = load(repo, branch)
        d4 = decide(doc4, all_reviewers)
        check("entry-4-no-raises", d4["raise"] == [], str(d4["raise"]))
        check("entry-4-uvogin-exhausted", "uvogin" in d4["skippedExhausted"])
        check(
            "maxima",
            doc4["reviewers"]["nobunaga"]["used"] == 2
            and doc4["reviewers"]["feitan"]["used"] == 1
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
            check("refuse-second-chrollo-raise", e.code == 2, str(e))

        # Inapplicable reviewer is not mandatory; later applicability still has budget.
        other = "opus/kurapika/other-effort"
        with LedgerLock(repo, other):
            init(repo, other)
            doc_b = load(repo, other)
        d_ui = decide(doc_b, ["hisoka"])
        check("inapplicable-chrollo-not-raised", "chrollo" not in d_ui["raise"] and d_ui["reviewers"][1]["action"] == "not-applicable")
        record(doc_b, "hisoka", "ran")
        with LedgerLock(repo, other):
            save(repo, doc_b)
            doc_b = load(repo, other)
        d_arch = decide(doc_b, ["chrollo"])
        check("later-applicable-chrollo-still-raises", d_arch["raise"] == ["chrollo"], str(d_arch["raise"]))

        # A new effort (new branch) is a new cycle — via init, not a missing-file fallback.
        fresh_branch = "grok/kurapika/fresh-effort"
        with LedgerLock(repo, fresh_branch):
            init(repo, fresh_branch)
            fresh = load(repo, fresh_branch)
        d_fresh = decide(fresh, ["chrollo"])
        check("new-branch-resets-budget", d_fresh["raise"] == ["chrollo"] and fresh["reviewers"]["chrollo"]["used"] == 0)

        # Same branch across a "session resume" is the same file.
        with LedgerLock(repo, branch):
            resumed = load(repo, branch)
        check("resume-same-file", resumed["reviewers"]["chrollo"]["used"] == 1)

        # An effort is a branch PLUS its PR (ruling 2026-09-28): a PR number on
        # the same branch name is a new key -- init is not refused, every
        # reviewer starts fresh, and the branch-only ledger is untouched.
        with LedgerLock(repo, branch, "7"):
            init(repo, branch, "7")
            pr7 = load(repo, branch, "7")
        # hanten's one-time init of the PR-keyed ledger while the branch-only one already exists.
        check("init-pr-beside-existing-branch-ledger", ledger_path(repo, branch).is_file() and ledger_path(repo, branch, "7").is_file())
        check("same-branch-new-pr-is-fresh", pr7["reviewers"]["chrollo"]["used"] == 0 and pr7["pr"] == 7 and pr7["slug"].endswith("-pr7"))
        check("same-branch-new-pr-new-file", ledger_path(repo, branch, "7") != ledger_path(repo, branch))
        record(pr7, "chrollo", "ran")
        with LedgerLock(repo, branch, "7"):
            save(repo, pr7)
        with LedgerLock(repo, branch, "8"):
            init(repo, branch, "8")
            pr8 = load(repo, branch, "8")
        check("second-pr-same-branch-resets", decide(pr8, ["chrollo"])["raise"] == ["chrollo"])
        try:
            with LedgerLock(repo, branch, "8"):
                init(repo, branch, "8")
            check("refuse-second-init-same-pr", False, "init succeeded")
        except SystemExit as e:
            check("refuse-second-init-same-pr", e.code == 2, str(e))
        try:
            with LedgerLock(repo, branch, "7"):
                _hydrate(json.loads(ledger_path(repo, branch, "7").read_text()), ledger_path(repo, branch, "7"), branch, "8")
            check("refuse-pr-mismatch", False, "hydrate succeeded")
        except SystemExit as e:
            check("refuse-pr-mismatch", e.code == 2, str(e))
        try:
            parse_pr("seven")
            check("refuse-non-numeric-pr", False, "parse succeeded")
        except SystemExit as e:
            check("refuse-non-numeric-pr", e.code == 2, str(e))
        check("pr-hash-prefix-normalised", parse_pr("#12") == "12")

        # Maxima come from the target's own nen/workflow.json review.scopes.
        wf = repo / "nen" / "workflow.json"
        wf.parent.mkdir(parents=True, exist_ok=True)
        wf.write_text(json.dumps({"review": {"scopes": {
            "code": {"persona": "nobunaga", "budget": 5},
            "security": {"persona": "feitan", "budget": 0},
            "odd": {"persona": "nobody", "budget": 9},
            "broken": {"persona": "hisoka", "budget": "two"},
        }}}))
        budgets(repo)
        check("budget-from-workflow", MAXIMA["nobunaga"] == 5 and MAXIMA["feitan"] == 0 and MAXIMA["hisoka"] == DEFAULT_MAXIMA["hisoka"], json.dumps(MAXIMA))
        check("budget-source-recorded", BUDGET_SOURCE["nobunaga"] == "nen/workflow.json review.scopes.code.budget" and BUDGET_SOURCE["hisoka"] == "default")
        wf_branch = "grok/kurapika/workflow-budget"
        with LedgerLock(repo, wf_branch, "3"):
            init(repo, wf_branch, "3")
            wf_doc = load(repo, wf_branch, "3")
        d_wf = decide(wf_doc, ["nobunaga", "feitan"])
        check("workflow-budget-drives-decide", d_wf["raise"] == ["nobunaga"] and d_wf["skippedExhausted"] == ["feitan"] and wf_doc["reviewers"]["nobunaga"]["max"] == 5, str(d_wf["raise"]))
        wf.unlink()
        budgets(repo)

        # Concurrent RMW: exclusive lock so both records land.
        conc_branch = "grok/kurapika/concurrent"
        with LedgerLock(repo, conc_branch):
            init(repo, conc_branch)
        errors = []

        def _record_persona(persona):
            try:
                with LedgerLock(repo, conc_branch):
                    d = load(repo, conc_branch)
                    time.sleep(0.05)
                    record(d, persona, "ran")
                    save(repo, d)
            except Exception as exc:
                errors.append(exc)

        t1 = threading.Thread(target=_record_persona, args=("feitan",))
        t2 = threading.Thread(target=_record_persona, args=("chrollo",))
        t1.start()
        t2.start()
        t1.join()
        t2.join()
        with LedgerLock(repo, conc_branch):
            conc = load(repo, conc_branch)
        check(
            "concurrent-rmw-both-records-land",
            not errors
            and conc["reviewers"]["feitan"]["used"] == 1
            and conc["reviewers"]["chrollo"]["used"] == 1,
            f"errors={errors!r} feitan={conc['reviewers']['feitan']['used']} chrollo={conc['reviewers']['chrollo']['used']}",
        )

    if failures:
        print(f"{len(failures)} failed", file=sys.stderr)
        return 1
    print(f"self-test: {passed} passed, {len(failures)} failed")
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
        refuse(f"hanten_cycle_ledger: --repo {repo} is not a directory")
    branch = opts["branch"]
    pr = parse_pr(opts.get("pr"))
    budgets(repo)
    with LedgerLock(repo, branch, pr):
        if cmd in ("init", "recover-first"):
            if cmd == "recover-first" and not opts.get("confirmed-first-cycle"):
                refuse("hanten_cycle_ledger: recover-first requires --confirmed-first-cycle after the maintainer confirms no review ran under this effort key")
            if cmd == "init" and opts.get("confirmed-first-cycle"):
                refuse("hanten_cycle_ledger: --confirmed-first-cycle is only valid with recover-first")
            doc = init(repo, branch, pr, first_cycle_recovery=cmd == "recover-first")
            path = ledger_path(repo, branch, pr)
            json.dump({"path": str(path), "branch": doc["branch"], "pr": doc["pr"], "contract": CONTRACT,
                       "openedAs": doc.get("openedAs", "normal-init"),
                       "budgets": {p: {"max": MAXIMA[p], "source": BUDGET_SOURCE[p]} for p in PERSONAS}}, sys.stdout, indent=2)
            sys.stdout.write("\n")
            return
        doc = load(repo, branch, pr)
        if cmd == "show":
            out = dict(doc)
            out["path"] = str(ledger_path(repo, branch, pr))
            json.dump(out, sys.stdout, indent=2)
            sys.stdout.write("\n")
            return
        if cmd == "decide":
            applicable = parse_applicable(opts.get("applicable", ""))
            result = decide(doc, applicable)
            result["path"] = str(ledger_path(repo, branch, pr))
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
        refuse(f"hanten_cycle_ledger: unknown command {cmd!r}")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except BrokenPipeError:
        pass
PY
