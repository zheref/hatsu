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
#   scripts/hanten_cycle_ledger.sh ensure --repo <path> --branch <name> [--pr <n>] [--base <trunk>]
#   scripts/hanten_cycle_ledger.sh decide --repo <path> --branch <name> [--pr <n>] --applicable <csv>
#   scripts/hanten_cycle_ledger.sh record --repo <path> --branch <name> [--pr <n>] --persona <id> --outcome ran|skipped-exhausted
#   scripts/hanten_cycle_ledger.sh show   --repo <path> --branch <name> [--pr <n>]
#   scripts/hanten_cycle_ledger.sh --self-test
#
# `ensure` (zheref/hatsu#169) opens the branch ledger for a branch breath § 3b
# did not cut -- the desktop app's worktree, a hand-made branch -- with the same
# `init`, and is safe to run on every entry (hanten § 1 passes --pr <n> once the
# effort has a PR):
#   0  {"ensure":"opened"}   no ledger and no trace of an earlier one: opened now
#   0  {"ensure":"present"}  already there (breath's, or an earlier ensure): untouched;
#                            with --pr <n>, that PR's own PR-keyed ledger (hanten
#                            § 2b's) also reads present ("keyed":"pr")
#   3  the branch is the trunk (--base, else nen/workflow.json branch.base, else
#      origin/HEAD, else main) or empty: no ledger is opened, hanten stops
#   4  no ledger here, but a ledger was opened under this key before: LOST.
#      Never a fresh init -- hanten § 1's recovery path owns it.
# THE TRACE OUTLIVES .nen/. A lock file beside the ledger dies with it (git
# clean -X, a removed worktree), so it cannot be the only trace. Every init
# (breath's, ensure's, recover-first's, the PR-keyed one) also writes
# <git-common-dir>/hatsu/hanten/<key>.opened, which git clean never touches
# and every worktree of the clone shares (git rev-parse --git-common-dir, read
# without --path-format so git older than 2.31 still answers; a relative answer
# is resolved against --repo; anything but one line is no trace, and `opened`
# says so). `ensure` reads, before opening: that marker or a
# <key>-pr<digits> one for ANOTHER PR (a branch whose slug merely extends this
# one's, x/ten-preflight beside x/ten, is another branch), another PR's ledger
# in this checkout, the same key's ledger or lock in any other `git worktree
# list` checkout, and a lock file here older than STALE_LOCK_SECONDS. Any one is
# a lost ledger. The lock's age is read once, before ensure waits on anything,
# and never dropped: a younger lock is an init or ensure in flight (it creates
# the lock before it saves), so ensure waits on it and reads again.
# What no local trace survives is a fresh clone: that reads `opened`. A
# pushed branch or an open PR is not a trace -- hanten first runs on an
# already-pushed branch (mukai). A marker never expires: a branch name reused
# after its branch was merged and deleted reads LOST, by design (fail closed),
# and is settled through recover-first (WORKFLOW.md § 4).
# decide/record/show on a MISSING ledger refuse before taking the lock, so a
# refused read never fakes a trace.
python3 - "$@" <<'PY'
from __future__ import annotations
import json
import os
import sys
import subprocess
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
    "leorio": 1,
}
PERSONAS = tuple(DEFAULT_MAXIMA)
# Personas ADDED after the ledger contract shipped. A ledger opened before such
# a persona existed has no row for him, and he could not have run in it, so an
# ABSENT row is hydrated at used 0 (marked hydratedAs). That leniency is for a
# ledger that PROVABLY predates him: init stamps personasAtOpen, and a
# hydration is recorded in lateHydrated beside the row it wrote, so an absent
# row in a ledger that names him in either refuses like any other (his row was
# lost, deleted or re-cased -- Feitan/Phinks/Chrollo, hanten on 265c2533). A
# row that is PRESENT but malformed still refuses, and every other persona's
# missing row still refuses: counts are never minted for someone who could
# have run.
LATE_PERSONAS = frozenset({"leorio"})
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
        "personasAtOpen": list(PERSONAS),
        "reviewers": empty_reviewers(),
    }


def _knew(doc: dict, persona: str) -> bool:
    """True when this ledger already knew the persona: opened with him, or hydrated him once."""
    for key in ("personasAtOpen", "lateHydrated"):
        seen = doc.get(key)
        if seen is not None and (not isinstance(seen, list) or persona in seen):
            return True  # a malformed stamp is read as knowing him: fail closed
    return False


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
        if p not in reviewers and p in LATE_PERSONAS and not _knew(doc, p):
            row = reviewers[p] = {"used": 0, "invocations": [], "hydratedAs": "persona-added-after-ledger-opened"}
            doc["lateHydrated"] = sorted(set(doc.get("lateHydrated") or []) | {p})
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


def _git(repo: Path, *args: str) -> str | None:
    """One git read in repo, or None when git is absent, refuses, or the path is no repository."""
    try:
        r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout if r.returncode == 0 else None


def trace_dir(repo: Path) -> Path | None:
    """<git-common-dir>/hatsu/hanten: outlives .nen/ (git clean -X, a removed worktree), never tracked."""
    out = _git(repo, "rev-parse", "--git-common-dir")  # no --path-format: that needs git >= 2.31
    lines = (out or "").strip().splitlines()
    if len(lines) != 1 or not lines[0].strip():
        return None  # no repository, or a git that answered something else: no durable trace (said by ensure)
    d = Path(lines[0].strip())
    if not d.is_absolute():
        d = repo / d
    return d.resolve() / "hatsu" / "hanten"


def note_opened(repo: Path, key: str) -> None:
    """Record, outside .nen/, that a ledger was opened under key. Best effort: no repository, no trace."""
    d = trace_dir(repo)
    if d is None:
        return
    try:
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{key}.opened").write_text(f"{utc_now()} {repo}\n")
    except OSError:
        pass


def init(repo: Path, branch: str, pr: str | None = None, *, first_cycle_recovery: bool = False) -> dict:
    path = ledger_path(repo, branch, pr)
    if path.is_file():
        refuse(f"hanten_cycle_ledger: ledger already exists at {path}")
    doc = new_doc(branch, pr)
    if first_cycle_recovery:
        doc["openedAs"] = "confirmed-first-cycle-recovery"
    save(repo, doc)
    note_opened(repo, slug(branch, pr))
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
            "hanten_cycle_ledger.sh init|ensure|recover-first|decide|record|show|--self-test "
            "[--repo PATH --branch NAME --applicable CSV --persona ID --outcome ran|skipped-exhausted]"
        )
    cmd = argv[0]
    opts = {}
    i = 1
    while i < len(argv):
        if argv[i] in ("--repo", "--branch", "--pr", "--applicable", "--persona", "--outcome", "--base") and i + 1 < len(argv):
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


def trunk_of(repo: Path, explicit: str | None) -> str:
    """The trunk ensure must never open a ledger on: --base, else workflow.json branch.base, else origin/HEAD, else main."""
    if explicit and explicit.strip():
        return explicit.strip()
    try:
        base = json.loads((repo / "nen" / "workflow.json").read_text()).get("branch", {}).get("base")
        if isinstance(base, str) and base.strip():
            return base.strip()
    except (OSError, ValueError, AttributeError):
        pass
    head = _git(repo, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    if head and head.strip().startswith("origin/") and head.strip() != "origin/":
        return head.strip()[len("origin/"):]
    return "main"


STALE_LOCK_SECONDS = 30


def stale_lock(repo: Path, branch: str) -> bool:
    """A lock file older than STALE_LOCK_SECONDS is a trace; a younger one is an init or ensure in flight.

    Read once, before ensure waits on anything, and never dropped by a later probe (Nobunaga, hanten
    on 449dda6b: a non-blocking flock probe made two concurrent ensures read each other as in flight
    and drop the trace). LedgerLock creates the file before it saves, so an in-flight init is always
    young; os.open on an existing lock file leaves its mtime alone, so a stale one stays old."""
    try:
        return time.time() - lock_path(repo, branch).stat().st_mtime > STALE_LOCK_SECONDS
    except OSError:
        return False


def _pr_keyed(name: str, key: str, suffix: str) -> str | None:
    """The PR number when name is exactly <key>-pr<digits><suffix>, else None (never a longer branch's key)."""
    head = f"{key}-pr"
    if not (name.startswith(head) and name.endswith(suffix)):
        return None
    n = name[len(head):len(name) - len(suffix)]
    return n if n.isdigit() else None


def traces(repo: Path, branch: str) -> list[str]:
    """Evidence that a ledger was opened under this branch before, from places .nen/ does not hold.

    A PR-keyed name counts only as exactly <key>-pr<digits> (a branch whose slug merely extends this
    one's with -pr..., e.g. -preflight, is another branch). The current PR's own PR-keyed ledger never
    reaches here: ensure returns it as present first (hanten § 2b reads it)."""
    key = slug(branch)
    found = []
    d = trace_dir(repo)
    if d is not None and d.is_dir():
        for m in sorted(d.glob(f"{key}.opened")):
            found.append(f"opened before under this repository's git dir ({m.name})")
        for m in sorted(d.glob(f"{key}-pr[0-9]*.opened")):
            if _pr_keyed(m.name, key, ".opened"):
                found.append(f"opened before under this repository's git dir ({m.name})")
    for p in sorted((repo / ".nen" / "hanten").glob(f"{key}-pr[0-9]*.cycle.json")):
        if _pr_keyed(p.name, key, ".cycle.json"):
            found.append(f"a PR-keyed ledger for another PR exists here ({p.name})")
    me = repo.resolve()
    for line in (_git(repo, "worktree", "list", "--porcelain") or "").splitlines():
        if not line.startswith("worktree "):
            continue
        wt = Path(line[len("worktree "):])
        try:
            if wt.resolve() == me:
                continue
        except OSError:
            continue
        h = wt / ".nen" / "hanten"
        others = [q for q in sorted(h.glob(f"{key}-pr[0-9]*.cycle.json")) if _pr_keyed(q.name, key, ".cycle.json")]
        for p in [h / f"{key}.cycle.json", h / f"{key}.cycle.lock", *others]:
            if p.exists():
                found.append(f"another checkout of this repository holds {p}")
    return found


def ensure(repo: Path, branch: str, base: str | None = None, pr: str | None = None) -> tuple[int, dict]:
    """Open the branch ledger for a branch breath did not cut; never reset, never re-open a lost one.

    With --pr N, a PR-keyed ledger for that PR is the effort's live ledger (hanten § 2b): present."""
    trunk = trunk_of(repo, base)
    path = ledger_path(repo, branch)
    if not branch.strip() or branch.strip() in (trunk, "HEAD") or branch.strip().startswith("refs/"):
        return 3, {"ensure": "refused", "reason": f"{branch!r} is the trunk ({trunk}) or not a branch: no ledger is opened", "path": str(path)}
    if pr and ledger_path(repo, branch, pr).is_file():
        return 0, {"ensure": "present", "keyed": "pr", "path": str(ledger_path(repo, branch, pr))}
    if path.is_file():
        return 0, {"ensure": "present", "path": str(path)}
    # Read the lock's age BEFORE waiting on it, and never drop that reading: a stale lock is a trace,
    # a young one is an init or ensure in flight (it creates the lock before it saves), so wait and re-read.
    stale = stale_lock(repo, branch)
    with LedgerLock(repo, branch):
        if pr and ledger_path(repo, branch, pr).is_file():
            return 0, {"ensure": "present", "keyed": "pr", "path": str(ledger_path(repo, branch, pr))}
        if path.is_file():  # the in-flight init, or a concurrent ensure, won
            return 0, {"ensure": "present", "path": str(path)}
        found = traces(repo, branch)
        if stale:
            found.append("its lock file remains in this checkout (older than an init in flight)")
        if found:
            return 4, {"ensure": "lost", "reason": "no ledger here, but a ledger was opened under this key before: recover it (hanten § 1), never a fresh init", "traces": found, "path": str(path)}
        init(repo, branch)
    out = {"ensure": "opened", "reason": "no trace of an earlier ledger was found", "path": str(path)}
    if trace_dir(repo) is None:
        out["note"] = "no git common dir was readable here, so no durable trace exists for a later ensure"
    return 0, out


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

        # Entry 2: Feitan/Chrollo/Phinks/Leorio exhausted; Nobunaga, Hisoka and Uvogin still raise.
        d2 = decide(doc2, all_reviewers)
        check("entry-2-chrollo-exhausted", d2["skippedExhausted"] == ["feitan", "chrollo", "phinks", "leorio"], str(d2["skippedExhausted"]))
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
            and doc4["reviewers"]["uvogin"]["used"] == 3
            and doc4["reviewers"]["leorio"]["used"] == 1,
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

        # Late persona (leorio): an old ledger with no leorio row loads, hydrated at used 0.
        old_branch = "grok/kurapika/old-ledger"
        with LedgerLock(repo, old_branch):
            old = init(repo, old_branch)
        del old["reviewers"]["leorio"]
        del old["personasAtOpen"]  # the pre-0.67.0 shape: no stamp, no leorio row
        save(repo, old)
        with LedgerLock(repo, old_branch):
            hydrated = load(repo, old_branch)
        lrow = hydrated["reviewers"]["leorio"]
        check("old-ledger-without-leorio-loads-hydrated",
              lrow["used"] == 0 and lrow["invocations"] == [] and lrow["max"] == MAXIMA["leorio"]
              and lrow.get("hydratedAs") == "persona-added-after-ledger-opened", json.dumps(lrow))
        check("hydrated-leorio-raises", decide(hydrated, ["leorio"])["raise"] == ["leorio"])
        check("hydration-is-on-record", hydrated.get("lateHydrated") == ["leorio"], str(hydrated.get("lateHydrated")))
        # A ledger that already knew him (stamped at init, or hydrated once) refuses a lost row.
        for label, doc_edit in (("stamped", {"personasAtOpen": list(PERSONAS)}), ("hydrated-once", {"lateHydrated": ["leorio"]})):
            knew = json.loads(json.dumps(old)); knew.update(doc_edit)
            save(repo, knew)
            try:
                load(repo, old_branch)
                check(f"lost-leorio-row-refused-when-{label}", False, "load succeeded")
            except SystemExit as e:
                check(f"lost-leorio-row-refused-when-{label}", e.code == 2, str(e))
        save(repo, old)
        # Present-but-malformed leorio row refuses.
        old["reviewers"]["leorio"] = {"used": "one", "invocations": []}
        save(repo, old)
        try:
            load(repo, old_branch)
            check("malformed-leorio-row-refused", False, "load succeeded")
        except SystemExit as e:
            check("malformed-leorio-row-refused", e.code == 2, str(e))
        old["reviewers"]["leorio"] = {"used": 1, "invocations": []}
        save(repo, old)
        try:
            load(repo, old_branch)
            check("inconsistent-leorio-row-refused", False, "load succeeded")
        except SystemExit as e:
            check("inconsistent-leorio-row-refused", e.code == 2, str(e))
        # A missing row for a NON-late persona still refuses.
        old["reviewers"] = empty_reviewers()
        del old["reviewers"]["feitan"]
        save(repo, old)
        try:
            load(repo, old_branch)
            check("missing-feitan-row-still-refused", False, "load succeeded")
        except SystemExit as e:
            check("missing-feitan-row-still-refused", e.code == 2, str(e))

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
    # ensure (zheref/hatsu#169): app-created branch opened, breath's untouched, trunk refused, lost reported
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        app = "opus/kurapika/app-cut"
        code, out = ensure(repo, app)
        check("ensure-opens-an-app-created-branch", code == 0 and out["ensure"] == "opened" and ledger_path(repo, app).is_file(), str(out))
        before = ledger_path(repo, app).read_bytes()
        code, out = ensure(repo, app)
        check("ensure-is-idempotent", code == 0 and out["ensure"] == "present" and ledger_path(repo, app).read_bytes() == before, str(out))
        cut = "opus/kurapika/breath-cut"
        with LedgerLock(repo, cut):
            init(repo, cut)
        doc = load(repo, cut)
        doc["reviewers"]["nobunaga"]["used"] = 1
        doc["reviewers"]["nobunaga"]["invocations"] = [{"at": "x", "outcome": "ran"}]
        save(repo, doc)
        before = ledger_path(repo, cut).read_bytes()
        code, out = ensure(repo, cut)
        check("ensure-leaves-a-breath-ledger-untouched", code == 0 and out["ensure"] == "present" and ledger_path(repo, cut).read_bytes() == before, str(out))
        for trunk_case in ("main", "HEAD", ""):
            code, out = ensure(repo, trunk_case)
            check(f"ensure-refuses-trunk-{trunk_case or 'empty'}", code == 3 and not ledger_path(repo, trunk_case or "x").is_file() and not any(repo.glob(".nen/hanten/main.*")), str(out))
        code, out = ensure(repo, "develop", "develop")
        check("ensure-refuses-the-declared-base", code == 3, str(out))
        (repo / "nen").mkdir()
        (repo / "nen" / "workflow.json").write_text(json.dumps({"branch": {"base": "trunk"}}))
        code, out = ensure(repo, "trunk")
        check("ensure-reads-branch-base-from-workflow", code == 3, str(out))
        ledger_path(repo, cut).unlink()
        old = time.time() - STALE_LOCK_SECONDS - 60
        os.utime(lock_path(repo, cut), (old, old))  # a lock left long ago, not an init in flight
        code, out = ensure(repo, cut)
        check("ensure-reports-a-lost-ledger-never-reinits", code == 4 and out["ensure"] == "lost" and not ledger_path(repo, cut).is_file(), str(out))
        fresh = "opus/kurapika/never-reviewed"
        try:
            main(["decide", "--repo", str(repo), "--branch", fresh, "--applicable", "nobunaga"])
            check("refused-read-leaves-no-lock", False, "decide succeeded")
        except SystemExit as e:
            check("refused-read-leaves-no-lock", e.code == 2 and not lock_path(repo, fresh).exists(), str(e))
        code, out = ensure(repo, fresh)
        check("ensure-opens-after-a-refused-read", code == 0 and out["ensure"] == "opened", str(out))
        # --pr N: that PR's own PR-keyed ledger is the live one (hanten § 2b), present; another PR's is a trace
        prb = "opus/kurapika/pr-keyed"
        with LedgerLock(repo, prb, "9"):
            init(repo, prb, "9")
        code, out = ensure(repo, prb, None, "9")
        check("ensure-pr-keyed-ledger-of-this-pr-is-present", code == 0 and out["ensure"] == "present" and out.get("keyed") == "pr" and not ledger_path(repo, prb).is_file(), str(out))
        # a sibling branch's ledger here (no git, so no marker) is never a PR key: x/ten beside x/ten-preflight
        with LedgerLock(repo, "x/ten-preflight"):
            init(repo, "x/ten-preflight")
        with LedgerLock(repo, "x/ten-pr2-notes"):
            init(repo, "x/ten-pr2-notes")
        code, out = ensure(repo, "x/ten")
        check("ensure-a-sibling-branch-ledger-is-no-trace", code == 0 and out["ensure"] == "opened", str(out))
        check("ensure-pr-keyed-present-makes-no-branch-lock", not lock_path(repo, prb).exists(), "a branch lock with no branch ledger would read stale later")
        code, out = ensure(repo, prb, None, "10")
        check("ensure-pr-keyed-ledger-of-another-pr-is-a-trace", code == 4 and any("another PR" in x for x in out.get("traces", [])), str(out))
        try:
            main(["ensure", "--repo", str(repo), "--branch", prb, "--pr", "9"])
            check("ensure-cli-takes-pr", False, "no exit")
        except SystemExit as e:
            check("ensure-cli-takes-pr", e.code == 0, str(e))
        try:
            main(["show", "--repo", str(repo), "--branch", fresh, "--base", "main"])
            check("base-only-with-ensure", False, "succeeded")
        except SystemExit as e:
            check("base-only-with-ensure", e.code == 2, str(e))

    # ensure's traces outlive .nen/ (Chrollo/Nobunaga/Phinks, hanten on 029322fb): git-backed cases
    def sh(*args, cwd=None):
        return subprocess.run(list(args), cwd=cwd, capture_output=True, text=True, timeout=30)
    def mkrepo(path: Path, branch: str = "app/feature") -> Path:
        sh("git", "init", "-q", "-b", "main", str(path))
        (path / ".gitignore").write_text(".nen/\n")
        sh("git", "-C", str(path), "add", ".gitignore")
        sh("git", "-C", str(path), "-c", "user.name=t", "-c", "user.email=t@example.invalid", "commit", "-q", "-m", "init")
        sh("git", "-C", str(path), "checkout", "-q", "-b", branch)
        return path
    def spend(repo: Path, branch: str = "app/feature"):
        ensure(repo, branch)
        with LedgerLock(repo, branch):
            doc = load(repo, branch)
            record(doc, "phinks", "ran")
            save(repo, doc)
    if sh("git", "--version").returncode == 0:
        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            a = mkrepo(t / "a"); spend(a)
            sh("git", "-C", str(a), "clean", "-fdxq")
            code, out = ensure(a, "app/feature")
            check("ensure-lost-after-git-clean", code == 4 and out["ensure"] == "lost" and not ledger_path(a, "app/feature").is_file(), str(out))
            core = mkrepo(t / "core"); sh("git", "-C", str(core), "checkout", "-q", "main")
            wt = core / ".nen" / "worktrees" / "x" / "feature"
            sh("git", "-C", str(core), "worktree", "add", "-q", str(wt), "app/feature")
            spend(wt)
            code, out = ensure(core / ".nen" / "worktrees" / "x" / "feature", "app/feature")
            check("ensure-present-in-the-worktree-that-holds-it", code == 0 and out["ensure"] == "present", str(out))
            sh("git", "-C", str(core), "checkout", "-q", "-b", "app/other")
            code, out = ensure(core, "app/feature")
            check("ensure-lost-when-another-worktree-holds-it", code == 4 and any("another checkout" in x for x in out.get("traces", [])), str(out))
            sh("git", "-C", str(core), "worktree", "remove", "--force", str(wt))
            sh("git", "-C", str(core), "checkout", "-q", "app/feature")
            code, out = ensure(core, "app/feature")
            check("ensure-lost-after-the-worktree-is-removed", code == 4 and any(".opened" in x for x in out.get("traces", [])), str(out))
            # another worktree holding a sibling branch's ledger (x/ten-pr2-notes beside x/ten) is no trace
            sib = mkrepo(t / "sib", "x/ten"); sh("git", "-C", str(sib), "branch", "x/ten-pr2-notes")
            swt = t / "sib-wt"
            sh("git", "-C", str(sib), "worktree", "add", "-q", str(swt), "x/ten-pr2-notes")
            save(swt, new_doc("x/ten-pr2-notes"))
            code, out = ensure(sib, "x/ten")
            check("ensure-a-sibling-ledger-in-another-worktree-is-no-trace", code == 0 and out["ensure"] == "opened", str(out))
            b = mkrepo(t / "b", "app/pr-only")
            with LedgerLock(b, "app/pr-only", "9"):
                init(b, "app/pr-only", "9")
            for m in (trace_dir(b) or t).glob("*.opened"):
                m.unlink()
            code, out = ensure(b, "app/pr-only", None, "9")
            check("ensure-present-for-the-current-prs-ledger", code == 0 and out["ensure"] == "present" and out.get("keyed") == "pr", str(out))
            code, out = ensure(b, "app/pr-only")
            check("ensure-lost-when-another-prs-ledger-exists", code == 4 and any("another PR" in x for x in out.get("traces", [])), str(out))
            # a branch whose slug extends this one's with -pr... is another branch, never a PR key (Nobunaga M1)
            e2 = mkrepo(t / "e2", "x/ten-preflight")
            code, out = ensure(e2, "x/ten-preflight")
            check("ensure-opens-the-longer-branch", code == 0 and out["ensure"] == "opened", str(out))
            sh("git", "-C", str(e2), "checkout", "-q", "-b", "x/ten-pr2-notes")
            code, out = ensure(e2, "x/ten-pr2-notes")
            check("ensure-opens-a-pr-digit-prefixed-branch", code == 0 and out["ensure"] == "opened", str(out))
            sh("git", "-C", str(e2), "checkout", "-q", "-b", "x/ten")
            code, out = ensure(e2, "x/ten")
            check("ensure-opens-a-branch-whose-name-prefixes-another", code == 0 and out["ensure"] == "opened", str(out))
            c = mkrepo(t / "c", "app/new")
            code, out = ensure(c, "app/new")
            check("ensure-opened-says-no-trace", code == 0 and out["ensure"] == "opened" and "no trace" in out.get("reason", ""), str(out))
            d = mkrepo(t / "d", "develop")
            sh("git", "-C", str(d), "update-ref", "refs/remotes/origin/develop", "HEAD")
            sh("git", "-C", str(d), "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/develop")
            code, out = ensure(d, "develop")
            check("ensure-refuses-the-trunk-from-origin-head", code == 3 and "develop" in out.get("reason", ""), str(out))
    # a held lock is an init in flight: wait for it, never call it lost (Phinks M2)
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        for writes, want in ((False, "opened"), (True, "present")):
            br = f"app/inflight-{want}"
            lock_path(repo, br).parent.mkdir(parents=True, exist_ok=True)
            held = threading.Event()
            def holder():
                fd = os.open(lock_path(repo, br), os.O_CREAT | os.O_RDWR, 0o644)
                fcntl.flock(fd, fcntl.LOCK_EX)
                held.set()
                time.sleep(0.6)
                if writes:
                    save(repo, new_doc(br))
                fcntl.flock(fd, fcntl.LOCK_UN)
                os.close(fd)
            th = threading.Thread(target=holder)
            if os.name != "nt":
                th.start(); held.wait(5)
                code, out = ensure(repo, br)
                th.join()
                check(f"ensure-waits-on-an-in-flight-lock-{want}", code == 0 and out["ensure"] == want, str(out))

    # races (Nobunaga M3 on 449dda6b, Phinks M2 on 029322fb), 30 trials each, two concurrent ensures
    if os.name != "nt":
        bad_stale = bad_fresh = 0
        for trial in range(30):
            with tempfile.TemporaryDirectory() as tmp:
                repo = Path(tmp)
                br = f"app/race-{trial}"
                lp = lock_path(repo, br)
                lp.parent.mkdir(parents=True, exist_ok=True)
                lp.write_text("")
                old = time.time() - STALE_LOCK_SECONDS - 60
                os.utime(lp, (old, old))  # a stale lock is the only trace (no git, no marker)
                res = []
                ths = [threading.Thread(target=lambda: res.append(ensure(repo, br)[0])) for _ in range(2)]
                for th in ths: th.start()
                for th in ths: th.join()
                if res != [4, 4] or ledger_path(repo, br).is_file():
                    bad_stale += 1
                br2 = f"app/fresh-{trial}"
                res = []
                ths = [threading.Thread(target=lambda: res.append(ensure(repo, br2))) for _ in range(2)]
                for th in ths: th.start()
                for th in ths: th.join()
                states = sorted(o["ensure"] for _, o in res)
                if any(c != 0 for c, _ in res) or states != ["opened", "present"]:
                    bad_fresh += 1
        check("race-a-stale-lock-reads-lost-in-every-trial", bad_stale == 0, f"{bad_stale}/30 trials opened a fresh budget")
        check("race-a-fresh-branch-never-reads-lost", bad_fresh == 0, f"{bad_fresh}/30 trials read lost or opened twice")

    print(f"self-test: {passed} passed, {len(failures)} failed")
    return 1 if failures else 0  # a failed case must fail the ledger-guard lane, which reads this exit


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
    if opts.get("base") and cmd != "ensure":
        refuse("hanten_cycle_ledger: --base is only valid with ensure")
    if cmd == "ensure":
        code, out = ensure(repo, branch, opts.get("base"), pr)
        json.dump(out, sys.stdout, indent=2)
        sys.stdout.write("\n")
        raise SystemExit(code)
    if cmd in ("decide", "record", "show") and not ledger_path(repo, branch, pr).is_file():
        load(repo, branch, pr)  # refuses with the missing-ledger message, before any lock file is made
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
