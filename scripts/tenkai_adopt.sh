#!/usr/bin/env bash
# tenkai_adopt.sh — the deterministic engine behind hatsu:tenkai (zheref/hatsu#81).
#
# Hatsu owns this file. Nen does not. The skill
# `claude/skills/tenkai/SKILL.md` is the policy; this script is the reader and
# the writer, so adoption state cannot be counted in prose and mis-remembered on
# the next re-run. It follows `scripts/hanten_cycle_ledger.sh`'s house shape: a
# thin bash wrapper over one embedded python3 program, with a `--self-test` that
# builds real fixtures and proves both directions.
#
# THE TWO HARD REQUIREMENTS, AND WHY THEY SHAPE EVERY ITEM BELOW.
#
#   IDEMPOTENCE. `apply` is safe to run any number of times. Every item detects
#   before it writes and reports `satisfied` when it finds nothing to do, so a
#   second run performs zero writes and says so. This is not a nicety: a
#   repository that adopted at v0.30.0 and never re-ran Tenkai is the NORMAL
#   case, and an adoption path that is only safe once is an adoption path nobody
#   re-runs.
#
#   DRIFT REPAIR. The interesting state is not "absent", it is "present and
#   quietly wrong" — a workflow rendered for another repository's slug, a hook
#   from an older template, a runner label that no longer matches what this
#   repository derives. Those look installed. Every item therefore reports
#   `drift` distinctly from `missing`, with the observed and expected values
#   both named, because "it is there" is not the same claim as "it works".
#
# OWNERSHIP IS EXPLICIT AND NEVER IMPROVISED AROUND. An item whose file belongs
# to nen is DIAGNOSED here and REPAIRED by nen's own verb — this script prints
# the exact command and marks the item `routed` rather than hand-writing a
# `nen/contract.json`. A Nen-owned operation is never improvised in prose, and it
# is not improvised in a script either.
#
# USAGE
#   scripts/tenkai_adopt.sh diagnose      --repo <path> [--slug <owner/name>] [--json]
#   scripts/tenkai_adopt.sh apply         --repo <path> [--slug <owner/name>] [--json]
#   scripts/tenkai_adopt.sh runner-policy --visibility <public|private> --self-hosted <n> [--json]
#   scripts/tenkai_adopt.sh --self-test
#
#   --hatsu-root <path>   where templates/ lives. Defaults to this script's own
#                         parent, so an installed plugin copy resolves its own
#                         templates rather than the target repository's.
#   --visibility / --self-hosted  override the probe. `diagnose` and `apply`
#                         probe `gh` when these are absent and fall back to
#                         UNKNOWN (never to a guess) when it cannot answer.
#
# EXIT CODES
#   0  every item is satisfied (or was repaired, on `apply`)
#   1  at least one item is missing, drifted, routed or staged — work remains
#   2  an invocation or environment defect: no such repo, unreadable template
#
# 1 IS NOT A CRASH. It is the honest answer to "is this repository a working
# Hatsu consumer yet", and a caller that treats it as an error has misread the
# contract. 2 is the one that means this script could not do its job.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TENKAI_DEFAULT_ROOT="$(dirname "$HERE")"

python3 - "$@" <<'PY'
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

CONTRACT = "hatsu.tenkai.adoption/v0.1"
HOSTED_RUNNER = "ubuntu-latest"
WORKFLOW_PATH = ".github/workflows/pr-readiness.yml"

# THE ADMITTED PRIVILEGED TRIGGERS — maintainer's ruling, 2026-09-19. The closed
# set lives in `scripts/workflow_runner_policy_check.rb`'s ALLOWED_TRIGGERS and
# is mirrored here so a CONSUMER's rendered workflow is held to it too.
#
# WHY ALL THREE ARE REQUIRED, NOT MERELY PERMITTED. With `pull_request_target`
# alone the verdict is computed at PUSH time -- while the checks are still
# pending -- and is never recomputed. Three of the five conjuncts change on
# events that trigger cannot see: CON-32(a) when a check completes, CON-32(b)/
# CON-16 when a review lands, CON-32(d) when a thread resolves. So the `ready`
# transition, which normally happens when the reviewer approves or the last
# check passes, would essentially never be published and the check would read
# not-ready almost always. A consumer provisioned with the single-trigger form
# inherits exactly that bug, which is why a MISSING trigger is drift and not a
# stylistic difference.
#
# WHY NOT A FOURTH. All three carry `github.event.pull_request`, so ONE job
# condition and one `github.event.pull_request.number` work unchanged across
# them under a single byte-compared same-repository guard. `check_suite` is
# deliberately refused: its payload has only `check_suite.pull_requests[]`, so it
# would need a second and weaker guard, and it fires for forks. A consumer that
# appears to need it is a ruling to escalate, never a template variation.
REQUIRED_TRIGGERS = ("pull_request_target", "pull_request_review", "pull_request_review_thread")
GUARD_PATH = "scripts/workflow_runner_policy_check.rb"

# States, most-satisfied first. `apply` turns missing/drift into repaired; it
# never turns routed, staged or blocked into anything, because those are owned
# elsewhere or deliberately deferred.
SATISFIED, REPAIRED, MISSING, DRIFT, ROUTED, STAGED, BLOCKED = (
    "satisfied", "repaired", "missing", "drift", "routed", "staged", "blocked")
OUTSTANDING = {MISSING, DRIFT, ROUTED, STAGED, BLOCKED}

# The five declaration files nen owns and validates. Tenkai reads them and
# routes their repair; it writes none of them.
NEN_DECLARATIONS = [
    ("nen/contract.json", "what nen EXECUTES — lanes, argv, preconditions, hosts, targets"),
    ("nen/workflow.json", "what the workflow DECIDES with — branch shape, checks, coverage, trailers"),
    ("nen/gates.json", "the readiness gate — reviewer identities, approval policy, carve-outs"),
    ("nen/labels.json", "the label vocabulary `hatsu:file` validates a filing against"),
    ("nen/repos.json", "the consumer and product-code registry"),
]


def usage(msg):
    print(f"tenkai_adopt: {msg}", file=sys.stderr)
    raise SystemExit(2)


# --------------------------------------------------------------------------
# Runner selection — the maintainer's ruling of 2026-09-19, encoded once.
# --------------------------------------------------------------------------
def derive_runner(visibility, self_hosted, portable=True):
    """Derive a runner label from the repository's own measured facts.

    THE RULING. A self-hosted PREFERENCE is right where hosted minutes are
    genuinely billed and the security calculus differs -- a PRIVATE consumer
    repository with a runner actually registered. It is wrong everywhere else,
    and #81 measured why on `zheref/hatsu` itself:

      * PUBLIC repositories get GitHub-hosted STANDARD runners free and
        unlimited, so there is no bill to avoid; and GitHub's own guidance is
        not to attach self-hosted runners to a public repository, because a
        fork PR can execute arbitrary code on the runner.
      * ZERO REGISTERED RUNNERS means a preference queues the job against a
        runner that never appears. A check that never completes is strictly
        worse than a bill that is currently zero -- and if it is ever made
        required, it blocks every merge, permanently.

    So the policy is DERIVED, never assumed, and it always terminates on a
    runner that exists. `fallback` is the label to fall back to and is never
    None: a job can never hang on an absent runner.
    """
    if visibility is None:
        return {
            "runs_on": HOSTED_RUNNER,
            "fallback": HOSTED_RUNNER,
            "reason": "repository visibility could not be read, so the hosted runner is used — "
                      "the derivation never guesses toward a runner that might not exist",
            "derived_from": {"visibility": None, "self_hosted": self_hosted, "portable": portable},
        }
    if visibility != "private":
        return {
            "runs_on": HOSTED_RUNNER,
            "fallback": HOSTED_RUNNER,
            "reason": f"repository is {visibility}: hosted standard runners are free and unlimited, "
                      "so there is no bill to avoid, and GitHub advises against self-hosted runners "
                      "on public repositories because a fork PR can execute code on them",
            "derived_from": {"visibility": visibility, "self_hosted": self_hosted, "portable": portable},
        }
    if not self_hosted:
        return {
            "runs_on": HOSTED_RUNNER,
            "fallback": HOSTED_RUNNER,
            "reason": "repository is private, but zero self-hosted runners are registered: a "
                      "preference would queue this job against a runner that never appears, and a "
                      "check that never completes is worse than a bill that is currently zero",
            "derived_from": {"visibility": visibility, "self_hosted": self_hosted, "portable": portable},
        }
    return {
        "runs_on": "self-hosted",
        "fallback": HOSTED_RUNNER,
        "reason": f"repository is private with {self_hosted} self-hosted runner(s) registered: "
                  "hosted minutes are genuinely billed here and the fork-exposure argument does not "
                  f"apply to a private repository. Falls back to {HOSTED_RUNNER} if the runner is gone",
        "derived_from": {"visibility": visibility, "self_hosted": self_hosted, "portable": portable},
    }


# --------------------------------------------------------------------------
# Context
# --------------------------------------------------------------------------
def probe_gh(slug, field):
    if not shutil.which("gh"):
        return None
    try:
        out = subprocess.run(
            ["gh", "api", f"repos/{slug}" if field == "visibility" else f"repos/{slug}/actions/runners",
             "--jq", ".visibility" if field == "visibility" else ".total_count"],
            capture_output=True, text=True, timeout=30)
    except Exception:
        return None
    if out.returncode != 0:
        return None
    val = out.stdout.strip()
    return int(val) if field == "runners" and val.isdigit() else (val or None)


def git_slug(repo):
    try:
        out = subprocess.run(["git", "-C", str(repo), "remote", "get-url", "origin"],
                             capture_output=True, text=True, timeout=15)
    except Exception:
        return None
    if out.returncode != 0:
        return None
    url = out.stdout.strip()
    m = re.search(r"[:/]([^/:]+/[^/]+?)(?:\.git)?$", url)
    return m.group(1) if m else None


def git_dir(repo):
    try:
        out = subprocess.run(["git", "-C", str(repo), "rev-parse", "--git-common-dir"],
                             capture_output=True, text=True, timeout=15)
    except Exception:
        return None
    if out.returncode != 0:
        return None
    p = Path(out.stdout.strip())
    return p if p.is_absolute() else (repo / p)


class Ctx:
    def __init__(self, repo, hatsu_root, slug, visibility, self_hosted, probe):
        self.repo = repo
        self.hatsu_root = hatsu_root
        self.slug = slug or git_slug(repo)
        self.git_dir = git_dir(repo)
        self.notes = []
        if visibility is None and probe and self.slug:
            visibility = probe_gh(self.slug, "visibility")
        if self_hosted is None and probe and self.slug:
            self_hosted = probe_gh(self.slug, "runners")
        self.visibility = visibility
        self.self_hosted = self_hosted or 0
        self.runner = derive_runner(visibility, self.self_hosted)

    def template(self, name):
        p = self.hatsu_root / "templates" / name
        if not p.is_file():
            usage(f"no template at {p} — --hatsu-root must point at a Hatsu checkout or plugin root")
        return p.read_text()


# --------------------------------------------------------------------------
# Items
# --------------------------------------------------------------------------
class Item:
    def __init__(self, ident, title, owner):
        self.id, self.title, self.owner = ident, title, owner

    def row(self, state, detail, action=None):
        return {"id": self.id, "title": self.title, "owner": self.owner,
                "state": state, "detail": detail, "action": action}


class NenDeclaration(Item):
    """Present-and-parseable is all Tenkai asserts. nen schema check is the
    authority on validity and this script never second-guesses it."""

    def __init__(self, path, what):
        super().__init__(path, what, "nen")
        self.path = path

    def detect(self, ctx):
        p = ctx.repo / self.path
        if not p.is_file():
            return self.row(ROUTED, f"absent — nen owns this file and Tenkai does not hand-write one",
                            f"nen scaffold init --repo {ctx.repo}")
        if self.path.endswith(".json"):
            try:
                json.loads(p.read_text())
            except Exception as exc:
                return self.row(BLOCKED, f"present but not parseable JSON: {exc}",
                                "repair by hand; a malformed declaration is not Tenkai's to rewrite")
        return self.row(SATISFIED, "present and parseable")

    def repair(self, ctx):
        return self.detect(ctx)   # never written here; routing is the repair


class ColorsFile(Item):
    """nen ships NO built-in colour table and no fallback, so nothing scaffolds
    this file. Hatsu does, because the vocabulary the shipped skills resolve is
    Hatsu's own."""

    def __init__(self):
        super().__init__("nen/colors.yml", "the colour vocabulary backlog-state and backlog-board resolve", "hatsu")

    def detect(self, ctx):
        p = ctx.repo / "nen" / "colors.yml"
        if not p.is_file():
            return self.row(MISSING, "absent — `nen schema check` will exit 1 and `nen color status` "
                                     "cannot run against this repository at all",
                            "render templates/colors.yml")
        text = p.read_text()
        if "categories:" not in text:
            return self.row(DRIFT, "present but declares no `categories:` block", "re-render from templates/colors.yml")
        return self.row(SATISFIED, "present and declares a categories block")

    def repair(self, ctx):
        cur = self.detect(ctx)
        if cur["state"] == SATISFIED:
            return cur
        p = ctx.repo / "nen" / "colors.yml"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(ctx.template("colors.yml"))
        return self.row(REPAIRED, "rendered from templates/colors.yml — tune the values, they are a seed")


class IgnoredDir(Item):
    """A directory the process writes into, which must exist AND be ignored.
    Both halves: an unignored Reports/ puts a rendered HTML report into somebody's
    next commit."""

    def __init__(self, ident, rel, why):
        super().__init__(ident, why, "hatsu")
        self.rel = rel

    def _ignored(self, ctx):
        probe = f"{self.rel}/probe"
        try:
            out = subprocess.run(["git", "-C", str(ctx.repo), "check-ignore", "-q", probe],
                                 capture_output=True, text=True, timeout=15)
            return out.returncode == 0
        except Exception:
            return False

    def detect(self, ctx):
        exists = (ctx.repo / self.rel).is_dir()
        ignored = self._ignored(ctx)
        if exists and ignored:
            return self.row(SATISFIED, f"{self.rel}/ exists and is ignored")
        missing = []
        if not exists:
            missing.append("does not exist")
        if not ignored:
            missing.append("is not git-ignored")
        state = MISSING if not exists else DRIFT
        return self.row(state, f"{self.rel}/ " + " and ".join(missing),
                        f"mkdir {self.rel}/ and add it to .gitignore")

    def repair(self, ctx):
        cur = self.detect(ctx)
        if cur["state"] == SATISFIED:
            return cur
        did = []
        d = ctx.repo / self.rel
        if not d.is_dir():
            d.mkdir(parents=True, exist_ok=True)
            (d / ".gitkeep").write_text("")
            did.append("created")
        if not self._ignored(ctx):
            gi = ctx.repo / ".gitignore"
            prev = gi.read_text() if gi.is_file() else ""
            if prev and not prev.endswith("\n"):
                prev += "\n"
            gi.write_text(prev + f"{self.rel}/\n")
            did.append("added to .gitignore")
        return self.row(REPAIRED, f"{self.rel}/ " + " and ".join(did))


class CommitMsgHook(Item):
    """The trailer gate. Every skill that commits gates on `nen commit format`;
    a commit typed by hand passes through none of them."""

    def __init__(self):
        super().__init__("hooks/commit-msg", "the commit trailer gate, run by git rather than by a skill", "hatsu")

    def _paths(self, ctx):
        gd = ctx.git_dir
        return None if gd is None else gd / "hooks" / "commit-msg"

    def detect(self, ctx):
        dest = self._paths(ctx)
        if dest is None:
            return self.row(BLOCKED, "not a git repository — there is no hooks directory to install into")
        want = ctx.template("commit-msg")
        if not dest.is_file():
            return self.row(MISSING, "no commit-msg hook — the trailer policy is enforced by discipline only",
                            "install templates/commit-msg")
        have = dest.read_text()
        if have != want:
            # A hand-written hook is NOT overwritten silently. Reporting drift and
            # naming the difference is the whole contract; `apply` re-renders only
            # a hook that carries this template's own marker line.
            mine = "RENDERED BY hatsu:tenkai from templates/commit-msg" in have
            return self.row(DRIFT,
                            "a commit-msg hook is installed but differs from the current template"
                            + ("" if mine else " AND was not rendered by Tenkai — it will not be overwritten"),
                            "re-render" if mine else "review by hand, then delete it and re-run apply")
        return self.row(SATISFIED, "installed and current")

    def repair(self, ctx):
        cur = self.detect(ctx)
        if cur["state"] == SATISFIED:
            return cur
        if cur["state"] == BLOCKED:
            return cur
        dest = self._paths(ctx)
        if cur["state"] == DRIFT and "will not be overwritten" in cur["detail"]:
            return cur
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(ctx.template("commit-msg"))
        dest.chmod(0o755)
        return self.row(REPAIRED, f"installed at {dest}")


class GuardRegistration(Item):
    """Half one of the two-PR ordering, detected rather than walked into.

    THE MECHANISM (zheref/hatsu#80). The policy guard that judges a PR is the
    TRUSTED copy from `main`, run against the PR's tree; the PR's own copy never
    executes. So a PR that both registers a workflow in the guard's tables AND
    adds the workflow file is judged by a guard that cannot know the file, and
    fails. Registration must land FIRST, in its own PR.

    Tenkai does not edit an arbitrary Ruby guard -- it DETECTS which half has
    landed and gates the workflow item on it, so a consumer inherits the ordering
    as a sequenced plan instead of as a red check they have to diagnose.
    """

    def __init__(self):
        super().__init__("guard/registration", "pr-readiness.yml registered in the workflow policy guard", "hatsu")

    @staticmethod
    def state_of(ctx):
        g = ctx.repo / GUARD_PATH
        if not g.is_file():
            return "absent"          # no guard: no ordering constraint at all
        return "registered" if "pr-readiness.yml" in g.read_text() else "unregistered"

    def detect(self, ctx):
        st = self.state_of(ctx)
        if st == "absent":
            return self.row(SATISFIED, f"no {GUARD_PATH} in this repository — no two-PR ordering applies")
        if st == "registered":
            return self.row(SATISFIED, "the guard already names pr-readiness.yml — the workflow may land next")
        return self.row(ROUTED,
                        "the guard does not name pr-readiness.yml. This must land in its OWN pull request, "
                        "BEFORE the workflow file: the guard judging a PR is the trusted copy from the base "
                        "branch, so a PR adding both is judged by a guard that cannot know the file",
                        "register pr-readiness.yml in the guard's EXPECTED_JOBS / EXPECTED_TYPES / EXPECTED_STEPS, "
                        "and do NOT add it to PORTABLE_HOSTED_WORKFLOWS — that constant doubles as the "
                        "required-PRESENCE list, so naming a file that does not exist yet fails every PR "
                        "from the other direction")

    def repair(self, ctx):
        return self.detect(ctx)


class ReadinessWorkflow(Item):
    """Half two. Rendered with this repository's own slug and derived runner."""

    def __init__(self):
        super().__init__(WORKFLOW_PATH, "the readiness check run, rendered for this repository", "hatsu")

    def render(self, ctx):
        t = ctx.template("pr-readiness.yml")
        return (t.replace("@@REPO_SLUG@@", ctx.slug or "UNKNOWN")
                 .replace("@@RUNS_ON@@", ctx.runner["runs_on"])
                 .replace("@@RUNNER_REASON@@", ctx.runner["reason"]))

    def detect(self, ctx):
        p = ctx.repo / WORKFLOW_PATH
        gate = GuardRegistration.state_of(ctx)
        if not p.is_file():
            if gate == "unregistered":
                return self.row(STAGED,
                                "not installed, and the policy guard has not registered it yet. Writing it now "
                                "would fail both required checks for one cause",
                                "land the guard registration first, then re-run apply")
            return self.row(MISSING, "not installed — this repository publishes no readiness verdict",
                            "render templates/pr-readiness.yml")
        text = p.read_text()
        if not ctx.slug:
            return self.row(BLOCKED, "installed, but this repository's slug could not be read, so the "
                                     "gate predicate cannot be checked",
                            "pass --slug <owner/name>")
        drifts = []
        # ANALYSE THE LIVE YAML, NEVER THE COMMENTS. This template carries a long
        # provenance banner that QUOTES the defect it exists to prevent --
        # including the literal `github.repository == \'zheref/hatsu\'` and the word
        # `--gates`. An earlier draft matched those and reported every correctly
        # rendered workflow as drift, which the self-test caught. Every line whose
        # first non-space character is `#` is a comment, in YAML and in the shell
        # inside a `run:` block alike, and none of them is what runs.
        live = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))
        # THE SILENT-SKIP FAILURE. A workflow gated to another repository's slug
        # is skipped on every event: green tick, no job, no signal, forever.
        m = re.search(r"github\.repository == '([^']+)'", live)
        if m and m.group(1) != ctx.slug:
            drifts.append(f"gated to '{m.group(1)}', not '{ctx.slug}' — this job is SKIPPED on every "
                          f"event and publishes nothing, with no error anywhere")
        elif not m:
            drifts.append("carries no `github.repository ==` gate predicate")
        m = re.search(r"runs-on:\s*(\S+)", live)
        if m and m.group(1) != ctx.runner["runs_on"]:
            drifts.append(f"runs-on is '{m.group(1)}', but this repository derives "
                          f"'{ctx.runner['runs_on']}' ({ctx.runner['reason']})")
        if "--gates" not in live:
            drifts.append("the verdict step does not pass --gates, so nen falls back to the PR head "
                          "checkout's own gates file — the PR would supply the gate that judges it")
        if "@@" in text:
            drifts.append("still carries unsubstituted @@TOKEN@@ placeholders")
        # THE TRIGGER SET, IN BOTH DIRECTIONS. A missing trigger is the
        # single-trigger bug; an extra one is outside the admitted closed set.
        declared = set(re.findall(r"^  ([a-z_]+):", live, re.M)) & (
            set(REQUIRED_TRIGGERS) | {"push", "check_suite", "check_run", "pull_request",
                                      "pull_request_review_comment", "issue_comment", "schedule",
                                      "workflow_dispatch", "workflow_run", "status"})
        absent = [t for t in REQUIRED_TRIGGERS if t not in declared]
        if absent:
            drifts.append(f"does not declare {', '.join(absent)} — with pull_request_target alone the "
                          f"verdict is computed at push time while checks are still pending and is "
                          f"NEVER recomputed, so the `ready` transition is essentially never published")
        extra = sorted(t for t in declared if t not in REQUIRED_TRIGGERS)
        if extra:
            drifts.append(f"declares {', '.join(extra)}, which is outside the admitted privileged "
                          f"trigger set — widening it is a maintainer ruling, not a template variation")
        if drifts:
            return self.row(DRIFT, "; ".join(drifts), "re-render from templates/pr-readiness.yml")
        return self.row(SATISFIED, f"installed, gated to {ctx.slug}, runs-on {ctx.runner['runs_on']}")

    def repair(self, ctx):
        cur = self.detect(ctx)
        if cur["state"] in (SATISFIED, STAGED, BLOCKED):
            return cur
        p = ctx.repo / WORKFLOW_PATH
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(self.render(ctx))
        return self.row(REPAIRED, f"rendered for {ctx.slug}, runs-on {ctx.runner['runs_on']}")


def items():
    out = [NenDeclaration(path, what) for path, what in NEN_DECLARATIONS]
    out.append(ColorsFile())
    out.append(IgnoredDir("dirs/reports", "Reports", "where rikugan writes the retained final report"))
    out.append(IgnoredDir("dirs/nen-state", ".nen", "where the hanten cycle ledger and the stop marker live"))
    out.append(CommitMsgHook())
    out.append(GuardRegistration())
    out.append(ReadinessWorkflow())
    return out


# --------------------------------------------------------------------------
# Run
# --------------------------------------------------------------------------
GLYPH = {SATISFIED: "ok  ", REPAIRED: "NEW ", MISSING: "MISS", DRIFT: "DRIF",
         ROUTED: "ROUT", STAGED: "STAG", BLOCKED: "BLOK"}


def run(mode, ctx):
    rows = [(it.repair(ctx) if mode == "apply" else it.detect(ctx)) for it in items()]
    return {"contract": CONTRACT, "mode": mode, "repo": str(ctx.repo), "slug": ctx.slug,
            "runner": ctx.runner, "items": rows,
            "outstanding": sum(1 for r in rows if r["state"] in OUTSTANDING)}


def report(res, as_json):
    if as_json:
        print(json.dumps(res, indent=2))
        return
    print(f"repository: {res['repo']}")
    print(f"slug:       {res['slug'] or '(unreadable)'}")
    r = res["runner"]
    print(f"runner:     {r['runs_on']} (fallback {r['fallback']}) — {r['reason']}")
    print()
    for row in res["items"]:
        print(f"  {GLYPH[row['state']]}  {row['id']}")
        print(f"        {row['detail']}")
        if row["action"] and row["state"] in OUTSTANDING:
            print(f"        → {row['action']}")
    print()
    n = res["outstanding"]
    if n == 0:
        print("every item is satisfied — this repository is a working Hatsu consumer.")
    else:
        print(f"{n} item(s) outstanding. Re-run `apply` after settling the routed and staged ones.")


# --------------------------------------------------------------------------
# Self-test — real fixtures, both directions, no network.
# --------------------------------------------------------------------------
def self_test():
    root = Path(os.environ["TENKAI_DEFAULT_ROOT"])
    failures = []

    def check(name, cond, detail=""):
        print(f"  {'ok  ' if cond else 'FAIL'}  {name}" + (f" — {detail}" if detail and not cond else ""))
        if not cond:
            failures.append(name)

    print("runner derivation — the ruling, in both directions")
    check("public + 0 runners -> hosted", derive_runner("public", 0)["runs_on"] == HOSTED_RUNNER)
    check("public + 5 runners -> hosted (fork exposure, and no bill)",
          derive_runner("public", 5)["runs_on"] == HOSTED_RUNNER)
    check("private + 0 runners -> hosted (never queue on an absent runner)",
          derive_runner("private", 0)["runs_on"] == HOSTED_RUNNER)
    check("private + 1 runner  -> self-hosted", derive_runner("private", 1)["runs_on"] == "self-hosted")
    check("unknown visibility  -> hosted, never a guess", derive_runner(None, 3)["runs_on"] == HOSTED_RUNNER)
    check("every derivation names a real fallback",
          all(derive_runner(v, n)["fallback"] == HOSTED_RUNNER
              for v in (None, "public", "private") for n in (0, 1, 9)))
    check("zheref/hatsu's own measured facts derive hosted",
          derive_runner("public", 0)["runs_on"] == HOSTED_RUNNER)

    def fixture(slug="acme/widget", with_guard=None, registered=False):
        d = Path(tempfile.mkdtemp(prefix="tenkai-fixture-"))
        subprocess.run(["git", "-C", str(d), "init", "-q"], check=True)
        subprocess.run(["git", "-C", str(d), "remote", "add", "origin",
                        f"https://github.com/{slug}.git"], check=True)
        if with_guard:
            g = d / GUARD_PATH
            g.parent.mkdir(parents=True, exist_ok=True)
            g.write_text("# guard\nEXPECTED_JOBS = {" +
                         ("'pr-readiness.yml' => 'readiness'" if registered else "") + "}\n")
        return d

    def ctx_for(d, slug="acme/widget", vis="private", sh=2):
        return Ctx(d, root, slug, vis, sh, probe=False)

    print("\ngreenfield — diagnose then apply then apply again")
    d = fixture()
    first = run("diagnose", ctx_for(d))
    check("a bare repository is not a consumer", first["outstanding"] > 0)
    by = {r["id"]: r for r in first["items"]}
    check("all five nen declarations route to nen, never hand-written",
          all(by[p]["state"] == ROUTED and "nen scaffold init" in (by[p]["action"] or "")
              for p, _ in NEN_DECLARATIONS))
    check("colors.yml is Hatsu's to write, not routed", by["nen/colors.yml"]["state"] == MISSING)
    check("no guard -> no two-PR ordering", by["guard/registration"]["state"] == SATISFIED)
    check("workflow is merely missing, not staged", by[WORKFLOW_PATH]["state"] == MISSING)

    applied = run("apply", ctx_for(d))
    by = {r["id"]: r for r in applied["items"]}
    check("colors.yml repaired", by["nen/colors.yml"]["state"] == REPAIRED)
    check("Reports/ repaired", by["dirs/reports"]["state"] == REPAIRED)
    check(".nen/ repaired", by["dirs/nen-state"]["state"] == REPAIRED)
    check("commit-msg hook repaired", by["hooks/commit-msg"]["state"] == REPAIRED)
    check("workflow repaired", by[WORKFLOW_PATH]["state"] == REPAIRED)
    check("the rendered workflow carries the real slug",
          "github.repository == 'acme/widget'" in (d / WORKFLOW_PATH).read_text())
    check("no @@TOKEN@@ survives rendering", "@@" not in (d / WORKFLOW_PATH).read_text())
    check("private+2 runners renders self-hosted",
          re.search(r"runs-on:\s*self-hosted", (d / WORKFLOW_PATH).read_text()) is not None)

    print("\nIDEMPOTENCE — the second apply must write nothing")
    again = run("apply", ctx_for(d))
    hatsu_rows = [r for r in again["items"] if r["owner"] == "hatsu"]
    check("every Hatsu-owned item reports satisfied on the second run",
          all(r["state"] == SATISFIED for r in hatsu_rows),
          str([(r["id"], r["state"]) for r in hatsu_rows if r["state"] != SATISFIED]))
    check("nothing is reported repaired on the second run",
          not any(r["state"] == REPAIRED for r in again["items"]))
    third = run("apply", ctx_for(d))
    check("a third run is identical to the second",
          [r["state"] for r in third["items"]] == [r["state"] for r in again["items"]])

    print("\nDRIFT REPAIR — present and quietly wrong is the interesting case")
    w = d / WORKFLOW_PATH
    w.write_text(w.read_text().replace("github.repository == 'acme/widget'",
                                       "github.repository == 'zheref/hatsu'"))
    row = ReadinessWorkflow().detect(ctx_for(d))
    check("a foreign slug is DRIFT, not satisfied", row["state"] == DRIFT)
    check("the silent-skip consequence is named, not just the mismatch", "SKIPPED" in row["detail"])
    ReadinessWorkflow().repair(ctx_for(d))
    check("the slug is repaired", ReadinessWorkflow().detect(ctx_for(d))["state"] == SATISFIED)

    w.write_text(w.read_text().replace("runs-on: self-hosted", "runs-on: ubuntu-latest"))
    check("a runner that no longer matches the derivation is DRIFT",
          ReadinessWorkflow().detect(ctx_for(d))["state"] == DRIFT)
    ReadinessWorkflow().repair(ctx_for(d))
    check("the runner is repaired to the derived value",
          ReadinessWorkflow().detect(ctx_for(d))["state"] == SATISFIED)

    w.write_text(w.read_text().replace('--gates "$PWD/.trusted/nen/gates.json"', ""))
    row = ReadinessWorkflow().detect(ctx_for(d))
    check("a dropped --gates is DRIFT", row["state"] == DRIFT and "--gates" in row["detail"])
    ReadinessWorkflow().repair(ctx_for(d))
    check("--gates is restored", ReadinessWorkflow().detect(ctx_for(d))["state"] == SATISFIED)

    # THE SINGLE-TRIGGER BUG, which a consumer would otherwise inherit silently.
    t = w.read_text()
    for ev in ("pull_request_review", "pull_request_review_thread"):
        t = re.sub(rf"^  {ev}:\n(?:    .*\n)*", "", t, flags=re.M)
    w.write_text(t)
    row = ReadinessWorkflow().detect(ctx_for(d))
    check("a single-trigger workflow is DRIFT", row["state"] == DRIFT)
    check("and the never-recomputed consequence is named, not just the absence",
          "NEVER recomputed" in row["detail"])
    ReadinessWorkflow().repair(ctx_for(d))
    check("all three triggers are restored",
          ReadinessWorkflow().detect(ctx_for(d))["state"] == SATISFIED)

    # A FOURTH TRIGGER, outside the admitted closed set.
    t = w.read_text().replace("  pull_request_review:\n",
                              "  check_suite:\n    types: [completed]\n  pull_request_review:\n", 1)
    w.write_text(t)
    row = ReadinessWorkflow().detect(ctx_for(d))
    check("check_suite is DRIFT — the set is closed", row["state"] == DRIFT
          and "check_suite" in row["detail"])
    check("and it is named as a ruling, not a style choice",
          "maintainer ruling" in row["detail"])
    ReadinessWorkflow().repair(ctx_for(d))
    check("the admitted set is restored", ReadinessWorkflow().detect(ctx_for(d))["state"] == SATISFIED)

    check("the shipped template itself declares exactly the admitted three",
          all(f"\n  {ev}:" in (root / "templates" / "pr-readiness.yml").read_text()
              for ev in REQUIRED_TRIGGERS))

    hook = ctx_for(d).git_dir / "hooks" / "commit-msg"
    hook.write_text("#!/bin/sh\n# somebody's own hook\nexit 0\n")
    row = CommitMsgHook().detect(ctx_for(d))
    check("a foreign hook is DRIFT", row["state"] == DRIFT)
    check("a foreign hook is NOT overwritten", "will not be overwritten" in row["detail"])
    CommitMsgHook().repair(ctx_for(d))
    check("apply left the foreign hook alone",
          "somebody's own hook" in hook.read_text())
    hook.unlink()
    CommitMsgHook().repair(ctx_for(d))
    check("a Tenkai-rendered hook IS re-rendered",
          CommitMsgHook().detect(ctx_for(d))["state"] == SATISFIED)

    print("\nTWO-PR ORDERING — handled, never hit")
    d2 = fixture(with_guard=True, registered=False)
    res = run("apply", ctx_for(d2))
    by = {r["id"]: r for r in res["items"]}
    check("an unregistered guard stages the workflow", by[WORKFLOW_PATH]["state"] == STAGED)
    check("apply did NOT write the workflow", not (d2 / WORKFLOW_PATH).is_file())
    check("the registration is routed with the ordering stated",
          by["guard/registration"]["state"] == ROUTED)
    check("PORTABLE_HOSTED_WORKFLOWS' double duty is named in the action",
          "required-PRESENCE list" in (by["guard/registration"]["action"] or ""))
    check("the run is outstanding, so nobody reads it as done", res["outstanding"] > 0)

    d3 = fixture(with_guard=True, registered=True)
    res = run("apply", ctx_for(d3))
    by = {r["id"]: r for r in res["items"]}
    check("once registered, the workflow lands", by[WORKFLOW_PATH]["state"] == REPAIRED)
    check("and the file is really there", (d3 / WORKFLOW_PATH).is_file())

    print("\ndiagnose is READ-ONLY")
    d4 = fixture()
    before = sorted(str(p.relative_to(d4)) for p in d4.rglob("*") if ".git/" not in str(p.relative_to(d4)))
    run("diagnose", ctx_for(d4))
    after = sorted(str(p.relative_to(d4)) for p in d4.rglob("*") if ".git/" not in str(p.relative_to(d4)))
    check("diagnose wrote nothing", before == after)

    print("\nblocked states are reported, never repaired around")
    d5 = fixture()
    (d5 / "nen").mkdir()
    (d5 / "nen" / "contract.json").write_text("{not json")
    row = NenDeclaration("nen/contract.json", "x").detect(ctx_for(d5))
    check("malformed JSON is BLOCKED, not silently rewritten", row["state"] == BLOCKED)

    for tmp in (d, d2, d3, d4, d5):
        shutil.rmtree(tmp, ignore_errors=True)

    print()
    if failures:
        print(f"tenkai_adopt --self-test: {len(failures)} FAILED: {', '.join(failures)}")
        raise SystemExit(1)
    print("tenkai_adopt --self-test: all green")
    raise SystemExit(0)


# --------------------------------------------------------------------------
def main(argv):
    if not argv:
        usage("a subcommand is required: diagnose | apply | runner-policy | --self-test")
    cmd, rest = argv[0], argv[1:]
    if cmd == "--self-test":
        self_test()

    opts = {}
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == "--json":
            opts["json"] = True
            i += 1
            continue
        if not a.startswith("--") or i + 1 >= len(rest):
            usage(f"unexpected argument {a!r}")
        opts[a[2:]] = rest[i + 1]
        i += 2

    as_json = bool(opts.pop("json", False))
    vis = opts.get("visibility")
    sh = opts.get("self-hosted")
    sh = int(sh) if sh is not None else None

    if cmd == "runner-policy":
        if vis is None or sh is None:
            usage("runner-policy needs --visibility <public|private> and --self-hosted <n>")
        r = derive_runner(vis, sh)
        if as_json:
            print(json.dumps(r, indent=2))
        else:
            print(f"runs-on:  {r['runs_on']}")
            print(f"fallback: {r['fallback']}")
            print(f"because:  {r['reason']}")
        raise SystemExit(0)

    if cmd not in ("diagnose", "apply"):
        usage(f"unknown subcommand {cmd!r}")
    if "repo" not in opts:
        usage(f"{cmd} needs --repo <path>")
    repo = Path(opts["repo"]).resolve()
    if not repo.is_dir():
        usage(f"no such directory: {repo}")
    hatsu_root = Path(opts.get("hatsu-root", os.environ["TENKAI_DEFAULT_ROOT"])).resolve()

    ctx = Ctx(repo, hatsu_root, opts.get("slug"), vis, sh, probe=True)
    res = run(cmd, ctx)
    report(res, as_json)
    raise SystemExit(1 if res["outstanding"] else 0)


main(sys.argv[1:])
PY
