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
#   scripts/hanten_cycle_ledger.sh ensure --repo <path> --branch <name> [--base <trunk>] [--no-pr-check]
#   scripts/hanten_cycle_ledger.sh decide --repo <path> --branch <name> [--pr <n>] --applicable <csv>
#   scripts/hanten_cycle_ledger.sh record --repo <path> --branch <name> [--pr <n>] --persona <id> --outcome ran|skipped-exhausted
#   scripts/hanten_cycle_ledger.sh show   --repo <path> --branch <name> [--pr <n>]
#   scripts/hanten_cycle_ledger.sh --self-test
#
# `ensure` (zheref/hatsu#169) opens the branch-only ledger, through the same
# init, for a branch breath did not cut (the desktop app's worktree). One JSON
# document on stdout, `action` + `reason`/`row` (ENSURE_ROWS is hanten § 1's
# table): exit 0 `opened` (stamped openedAs "ensure" with what was searched)
# or `present` (this branch's ledger LOADS; untouched); exit 3 `lost-ledger`
# (review evidence and no ledger here); exit 2 `trunk`, `detached-head` or
# `refused`. Before any lock or write it refuses --pr, --confirmed-first-cycle,
# an empty/HEAD/invalid branch, the trunk (main, --base and every declared
# branch.base, origin/ stripped, from the working tree and origin/<base>), a
# --repo that is not a git toplevel or not on --branch, a malformed
# workflow.json (only a missing one falls back), and a tracked or symlinked
# .nen/hanten. Evidence: in every `git worktree list` checkout, the branch's
# ledger or lock, its PR-keyed ledgers, hanten's findings record (Reports and
# the declared reports.dir), all under the branch's name and any name the
# reflog says it was renamed from; a lock left here with no ledger; and a PR
# whose head is the branch (gh, unless --no-pr-check, the maintainer's word).
# A remote ref alone is never evidence. What it guarantees is no fresh budget
# where that evidence survives; history with no trace anywhere is beyond it.
python3 - "$@" <<'PY'
from __future__ import annotations
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import unicodedata
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


def init(repo: Path, branch: str, pr: str | None = None, *, first_cycle_recovery: bool = False,
         opened_as: str | None = None, searched: dict | None = None) -> dict:
    path = ledger_path(repo, branch, pr)
    if path.is_file():
        refuse(f"hanten_cycle_ledger: ledger already exists at {path}")
    doc = new_doc(branch, pr)
    if first_cycle_recovery:
        doc["openedAs"] = "confirmed-first-cycle-recovery"
    elif opened_as:
        doc["openedAs"] = opened_as
        doc["evidenceSearched"] = searched or {}
    save(repo, doc)
    return doc


# ---- ensure (zheref/hatsu#169) ----------------------------------------------
# Every refusal is a JSON document on stdout ({"action": "refused", "reason":
# <row>, ...}) plus one line on stderr. The rows ARE hanten § 1's table:
ENSURE_ROWS = {
    "opened": "exit 0 -- no ledger and no review evidence: opened by init, openedAs ensure; report it",
    "present": "exit 0 -- this branch's ledger loads; untouched, never re-init, never reset",
    "lost-ledger": "exit 3 -- review evidence with no ledger here: recover it (hanten § 1, WORKFLOW.md § 4); never a fresh budget",
    "trunk": "exit 2 -- the trunk gets no ledger: stop",
    "detached-head": "exit 2 -- a detached HEAD gets no ledger: stop",
    "refused": "exit 2 -- any other refusal (usage, checkout, declaration, ledger state): stop, stderr quoted",
}
LOST_EXIT = 3


def ensure_refuse(reason: str, msg: str, code: int = 2, **extra):
    doc = {"action": "refused", "reason": reason, "row": ENSURE_ROWS[reason], "message": msg}
    doc.update(extra)
    json.dump(doc, sys.stdout, indent=2)
    sys.stdout.write("\n")
    print(f"hanten_cycle_ledger: ensure: {msg}", file=sys.stderr)
    raise SystemExit(code)


def git(repo: Path | None, *args, timeout: int = 30):
    cmd = ["git"] + (["-C", str(repo)] if repo is not None else []) + list(args)
    try:
        return subprocess.run(cmd, capture_output=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        ensure_refuse("refused", f"git could not run ({' '.join(cmd[:4])}...): {exc}")


def nfc(text: str) -> str:
    return unicodedata.normalize("NFC", text)


def strip_origin(name: str) -> str:
    name = name.strip()
    return name[len("origin/"):] if name.startswith("origin/") else name


def parse_workflow(raw: bytes, source: str) -> tuple[str | None, str | None]:
    """(branch.base, reports.dir) from one nen/workflow.json; malformed refuses, absent keys are None."""
    try:
        doc = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as exc:
        ensure_refuse("refused", f"{source} is present but malformed ({exc}); only a missing file falls back")
    if not isinstance(doc, dict):
        ensure_refuse("refused", f"{source} is not a JSON object")
    base = reports = None
    branch = doc.get("branch")
    if branch is not None:
        if not isinstance(branch, dict):
            ensure_refuse("refused", f"{source} branch is not an object")
        if "base" in branch:
            base = branch["base"]
            if not isinstance(base, str) or not base.strip():
                ensure_refuse("refused", f"{source} branch.base is not a non-empty string")
            base = strip_origin(base)
    rep = doc.get("reports")
    if rep is not None:
        if not isinstance(rep, dict):
            ensure_refuse("refused", f"{source} reports is not an object")
        if "dir" in rep:
            reports = rep["dir"]
            if not isinstance(reports, str) or not reports.strip():
                ensure_refuse("refused", f"{source} reports.dir is not a non-empty string")
            p = Path(reports.strip())
            if p.is_absolute() or ".." in p.parts:
                ensure_refuse("refused", f"{source} reports.dir {reports!r} is absolute or climbs out of the checkout")
            reports = reports.strip()
    return base, reports


def scan(directory: Path, names: set[str]) -> list[Path]:
    """Entries of directory whose NFC name is in names (NFC); never follows a missing dir."""
    try:
        entries = list(directory.iterdir())
    except OSError:
        return []
    return sorted(p for p in entries if nfc(p.name) in names)


def evidence_in(checkout: Path, branches: list[str], report_dirs: list[str], skip_own: Path | None) -> list[str]:
    """Review evidence for any of branches in one checkout (fail closed on unreadable files)."""
    found = []
    hanten = checkout / ".nen" / "hanten"
    for name in branches:
        s = nfc(slug(name))
        if skip_own is None or checkout.resolve() != skip_own or name != branches[0]:
            # Another checkout's ledger or lock, or one under a pre-rename name, is this effort's history.
            found += [str(p) for p in scan(hanten, {f"{s}.cycle.json", f"{s}.cycle.lock"})]
        try:
            entries = list(hanten.iterdir())
        except OSError:
            entries = []
        for p in sorted(entries):
            n = nfc(p.name)
            if not (n.startswith(f"{s}-pr") and n.endswith(".cycle.json")):
                continue
            num = n[len(s) + 3:-len(".cycle.json")]
            if not num.isdigit():
                continue
            # Counted unless it READS as another branch's ledger (branch x vs a
            # branch named x-pr3); unreadable or a pr mismatch is counted.
            try:
                d = json.loads(p.read_text())
                other = isinstance(d, dict) and isinstance(d.get("branch"), str) and nfc(d["branch"]) != nfc(name)
            except (OSError, ValueError):
                other = False
            if not other:
                found.append(str(p))
        for rd in report_dirs:
            found += [str(p) for p in scan(checkout / rd / "hanten", {f"{s}.json"})]
    return found


def pr_evidence(repo: Path, branch: str) -> tuple[list[str], str]:
    """PRs whose head is this branch (a remote ref alone is never evidence)."""
    try:
        r = subprocess.run(["gh", "pr", "list", "--head", branch, "--state", "all",
                            "--json", "number,headRefName", "--limit", "100"],
                           cwd=str(repo), capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        ensure_refuse("refused", f"the PR check could not run (gh: {exc}); pass --no-pr-check only on the maintainer's word")
    if r.returncode != 0:
        ensure_refuse("refused", f"the PR check failed (gh exit {r.returncode}: {r.stderr.strip()[:200]}); "
                      "pass --no-pr-check only on the maintainer's word")
    try:
        rows = json.loads(r.stdout or "[]")
        prs = [f"PR #{row['number']}" for row in rows if nfc(str(row.get("headRefName"))) == nfc(branch)]
    except (ValueError, TypeError, KeyError) as exc:
        ensure_refuse("refused", f"the PR check returned unreadable output: {exc}")
    return prs, "gh pr list --head (state all)"


def ensure_main(opts) -> None:
    if opts.get("pr"):
        ensure_refuse("refused", "ensure opens the branch-only ledger; the PR-keyed one is hanten § 2b's init --pr")
    if opts.get("confirmed-first-cycle"):
        ensure_refuse("refused", "--confirmed-first-cycle is only valid with recover-first")
    if not opts.get("repo"):
        ensure_refuse("refused", "missing --repo")
    branch = opts.get("branch") or ""
    if branch.strip() in ("", "HEAD"):
        ensure_refuse("detached-head", f"{branch!r}: a detached HEAD gets no ledger (missing --branch reads the same)")
    if git(None, "check-ref-format", "--branch", branch).returncode != 0:
        ensure_refuse("refused", f"{branch!r} is not a valid branch name (git check-ref-format --branch)")
    repo = Path(opts["repo"]).resolve()
    if not repo.is_dir():
        ensure_refuse("refused", f"--repo {repo} is not a directory")
    # The trunk set only ever GROWS: main, --base, and every declared branch.base.
    trunks = {"main"}
    if opts.get("base"):
        trunks.add(strip_origin(opts["base"]))
    report_dirs = ["Reports"]
    sources = []
    wt_file = repo / "nen" / "workflow.json"
    wt_base = None
    if wt_file.exists():
        try:
            raw = wt_file.read_bytes()
        except OSError as exc:
            ensure_refuse("refused", f"{wt_file} is present but unreadable: {exc}")
        wt_base, rd = parse_workflow(raw, str(wt_file))
        sources.append(str(wt_file))
        if wt_base:
            trunks.add(wt_base)
        if rd:
            report_dirs.append(rd)
    if nfc(branch) in {nfc(t) for t in trunks}:
        ensure_refuse("trunk", f"{branch!r} is the trunk ({', '.join(sorted(trunks))}); the trunk gets no ledger")
    top = git(repo, "rev-parse", "--show-toplevel")
    if top.returncode != 0:
        ensure_refuse("refused", f"--repo {repo} is not a git checkout; ensure searches every worktree and refuses without git")
    if Path(top.stdout.decode().strip()).resolve() != repo:
        ensure_refuse("refused", f"--repo {repo} is not the checkout toplevel ({top.stdout.decode().strip()})")
    for ref in ["origin/main"] + ([f"origin/{wt_base}"] if wt_base and wt_base != "main" else []):
        shown = git(repo, "show", f"{ref}:nen/workflow.json")
        if shown.returncode == 0:
            b, rd = parse_workflow(shown.stdout, f"{ref}:nen/workflow.json")
            sources.append(f"{ref}:nen/workflow.json")
            if b:
                trunks.add(b)
            if rd and rd not in report_dirs:
                report_dirs.append(rd)
    if nfc(branch) in {nfc(t) for t in trunks}:
        ensure_refuse("trunk", f"{branch!r} is the trunk ({', '.join(sorted(trunks))}); the trunk gets no ledger")
    current = git(repo, "branch", "--show-current").stdout.decode().strip()
    if not current:
        ensure_refuse("detached-head", f"{repo} has a detached HEAD; it gets no ledger")
    if nfc(current) != nfc(branch):
        ensure_refuse("refused", f"--branch {branch!r} is not the branch checked out in {repo} ({current!r})")
    hanten_dir = repo / ".nen" / "hanten"
    if git(repo, "ls-files", "--", ".nen/hanten").stdout.strip():
        ensure_refuse("refused", ".nen/hanten is tracked by git; a ledger must be local, untracked state")
    for p in (repo / ".nen", hanten_dir):
        if (p.exists() or p.is_symlink()) and (p.is_symlink() or repo not in p.resolve().parents):
            ensure_refuse("refused", f"{p} is a symlink or resolves outside {repo}")
    # Every checkout of this repository, plus old names from a rename.
    wl = git(repo, "worktree", "list", "--porcelain")
    if wl.returncode != 0:
        ensure_refuse("refused", "git worktree list failed; evidence across worktrees cannot be searched")
    checkouts = [repo] + [Path(line[len("worktree "):]).resolve() for line in wl.stdout.decode().splitlines()
                          if line.startswith("worktree ")]
    names = [branch]
    reflog = git(repo, "reflog", "show", "--format=%gs", f"refs/heads/{branch}", "--")
    for line in reflog.stdout.decode(errors="replace").splitlines():
        if line.startswith("Branch: renamed refs/heads/") and " to refs/heads/" in line:
            old = line[len("Branch: renamed refs/heads/"):].split(" to refs/heads/")[0]
            if old and old not in names:
                names.append(old)
    lock_existed = lock_path(repo, branch).exists()
    # The PR check runs before the lock, so a failed check writes nothing; a
    # present ledger needs no check at all.
    prs, how = [], "not needed (ledger present)"
    if not ledger_path(repo, branch).is_file():
        if opts.get("no-pr-check"):
            how = "skipped (--no-pr-check, the maintainer's word)"
        else:
            prs, how = pr_evidence(repo, branch)
    with LedgerLock(repo, branch):
        path = ledger_path(repo, branch)
        if path.is_file():
            try:
                load(repo, branch)
            except (ValueError, OSError) as exc:
                ensure_refuse("refused", f"{path} exists but does not load ({exc}); restore it, never re-init")
            except SystemExit:
                ensure_refuse("refused", f"{path} exists but is not this branch's valid ledger; restore it, never re-init")
            json.dump({"action": "present", "row": ENSURE_ROWS["present"], "path": str(path), "branch": branch,
                       "contract": CONTRACT}, sys.stdout, indent=2)
            sys.stdout.write("\n")
            return
        evidence = []
        if lock_existed:
            evidence.append(str(lock_path(repo, branch)) + " (a ledger command ran here; its ledger is gone)")
        for checkout in dict.fromkeys(checkouts):
            evidence += evidence_in(checkout, names, report_dirs, repo if checkout == repo else None)
        searched = {"checkouts": [str(c) for c in dict.fromkeys(checkouts)], "names": names,
                    "reportDirs": report_dirs, "workflow": sources}
        evidence += prs
        searched["prCheck"] = how
        if evidence:
            ensure_refuse("lost-ledger", "review evidence with no ledger here: a lost ledger, recovered per hanten § 1, "
                          "never a fresh budget", LOST_EXIT, evidence=sorted(set(evidence)), searched=searched)
        doc = init(repo, branch, opened_as="ensure", searched=searched)
        json.dump({"action": "opened", "row": ENSURE_ROWS["opened"], "path": str(path), "branch": branch,
                   "contract": CONTRACT, "openedAs": doc["openedAs"], "searched": searched}, sys.stdout, indent=2)
        sys.stdout.write("\n")


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
            "[--repo PATH --branch NAME --base TRUNK --applicable CSV --persona ID --outcome ran|skipped-exhausted]"
        )
    cmd = argv[0]
    opts = {}
    i = 1
    while i < len(argv):
        if argv[i] in ("--repo", "--branch", "--pr", "--base", "--applicable", "--persona", "--outcome") and i + 1 < len(argv):
            opts[argv[i][2:]] = argv[i + 1]
            i += 2
            continue
        if argv[i] == "--no-pr-check":
            opts["no-pr-check"] = True
            i += 1
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
    print(f"self-test: {passed} passed, {len(failures)} failed")
    return 0


def main(argv):
    if argv and argv[0] == "--self-test":
        raise SystemExit(self_test())
    cmd, opts = parse_args(argv)
    if cmd == "--self-test":
        raise SystemExit(self_test())
    if cmd == "ensure":
        if opts.get("repo") and Path(opts["repo"]).resolve().is_dir():
            budgets(Path(opts["repo"]).resolve())
        ensure_main(opts)
        return
    if opts.get("no-pr-check"):
        refuse("hanten_cycle_ledger: --no-pr-check is only valid with ensure")
    require(opts, "repo", "branch")
    repo = Path(opts["repo"]).resolve()
    if not repo.is_dir():
        refuse(f"hanten_cycle_ledger: --repo {repo} is not a directory")
    branch = opts["branch"]
    pr = parse_pr(opts.get("pr"))
    budgets(repo)
    if opts.get("base") and cmd != "ensure":
        refuse("hanten_cycle_ledger: --base is only valid with ensure")
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
