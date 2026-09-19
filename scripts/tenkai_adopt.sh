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
import hashlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

CONTRACT = "hatsu.tenkai.adoption/v0.1"
_FIXTURES: list = []
HOSTED_RUNNER = "ubuntu-latest"
WORKFLOW_PATH = ".github/workflows/pr-readiness.yml"

# THE ADMITTED PRIVILEGED TRIGGERS — maintainer's ruling, 2026-09-19, as
# corrected the same day. The closed set lives in
# `scripts/workflow_runner_policy_check.rb`'s ALLOWED_TRIGGERS and is mirrored
# here so a CONSUMER's rendered workflow is held to it too.
#
# WHY BOTH ARE REQUIRED, NOT MERELY PERMITTED. With `pull_request_target` alone
# the verdict is computed at PUSH time -- while the checks are still pending --
# and is never recomputed. The conjuncts change on events that trigger cannot
# see: CON-32(b)/CON-16 when a review lands. So the `ready` transition, which
# normally happens when the reviewer approves, would essentially never be
# published and the check would read not-ready almost always. A consumer
# provisioned with the single-trigger form inherits exactly that bug, which is
# why a MISSING trigger is drift and not a stylistic difference.
#
# WHY NOT A THIRD. `pull_request_review_thread` WAS ADMITTED BRIEFLY AND REMOVED,
# and this is the correction that matters most here: it is a WEBHOOK event and
# NOT a supported Actions trigger, so a workflow naming it CANNOT REGISTER AT
# ALL. An earlier version of this file required it, which meant `apply` would
# have reported a correct workflow as drift and then "repaired" it into one that
# does not run -- the tool actively breaking the consumer it was adopting.
# `check_suite` is refused for a different reason: its payload carries no
# `github.event.pull_request` (only `check_suite.pull_requests[]`), so it would
# need a second and weaker guard, and it fires for forks. Either way a consumer
# that appears to need one is a ruling to escalate, never a template variation.
#
# CON-32(d) -- unresolved threads -- therefore has NO TRIGGER AVAILABLE. That is
# a named limitation, not an oversight, and § 5c of the skill states it.
REQUIRED_TRIGGERS = ("pull_request_target", "pull_request_review")
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


def _atomic_write(path: Path, text: str):
    """Write through a temp file in the same directory, then os.replace.

    A direct `write_text` that dies mid-call leaves a TRUNCATED workflow or hook
    behind rather than the previous one -- and these are files a repository's CI
    depends on. `scripts/hanten_cycle_ledger.sh` already writes this way.
    """
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".tenkai-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(text)
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


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
            "labels_required": False,
            "fallback": HOSTED_RUNNER,
            "reason": "repository visibility could not be read, so the hosted runner is used — "
                      "the derivation never guesses toward a runner that might not exist",
            "derived_from": {"visibility": None, "self_hosted": self_hosted, "portable": portable},
        }
    if visibility != "private":
        return {
            "runs_on": HOSTED_RUNNER,
            "labels_required": False,
            "fallback": HOSTED_RUNNER,
            "reason": f"repository is {visibility}: hosted standard runners are free and unlimited, "
                      "so there is no bill to avoid, and GitHub advises against self-hosted runners "
                      "on public repositories because a fork PR can execute code on them",
            "derived_from": {"visibility": visibility, "self_hosted": self_hosted, "portable": portable},
        }
    if not self_hosted:
        return {
            "runs_on": HOSTED_RUNNER,
            "labels_required": False,
            "fallback": HOSTED_RUNNER,
            "reason": "repository is private, but zero self-hosted runners are registered: a "
                      "preference would queue this job against a runner that never appears, and a "
                      "check that never completes is worse than a bill that is currently zero",
            "derived_from": {"visibility": visibility, "self_hosted": self_hosted, "portable": portable},
        }
    # A BARE `self-hosted` IS THE BROADEST SELECTOR THERE IS -- any runner
    # registered to the repository OR its organisation, including runners shared
    # with other repositories, and non-ephemeral by default while this job checks
    # PR-controlled content into its workspace. This repository's own guard admits
    # only LABELLED SETS for that reason, and would reject the bare scalar
    # outright. The label set is the consumer's own data, which Tenkai does not
    # invent -- so the derivation names the requirement instead of guessing one.
    return {
        "runs_on": "self-hosted",
        "labels_required": True,
        "fallback": HOSTED_RUNNER,
        "reason": f"repository is private with {self_hosted} self-hosted runner(s) registered: "
                  "hosted minutes are genuinely billed here and the fork-exposure argument does not "
                  f"apply to a private repository. Falls back to {HOSTED_RUNNER} if the runner is gone",
        "derived_from": {"visibility": visibility, "self_hosted": self_hosted, "portable": portable},
    }


def _on_block(live: str) -> str:
    """The workflow's `on:` mapping, and nothing else.

    `"on":` and `'on':` are accepted deliberately: bare `on` is the YAML 1.1
    boolean `true`, so many repositories quote it ON PURPOSE. An earlier draft
    matched the bare form only and reported a correct workflow as missing every
    trigger -- with the consequence sentence asserted confidently about a file
    that did not have the defect. The child indent is derived from the first
    child line rather than assumed to be two spaces, for the same reason.
    """
    lines = live.splitlines()
    try:
        start = next(i for i, l in enumerate(lines)
                     if l.rstrip() in ('on:', '"on":', "'on':"))
    except StopIteration:
        return ""
    out = []
    for l in lines[start + 1:]:
        if l.strip() and not l.startswith(" "):
            break
        out.append(l)
    return "\n".join(out)


def _on_keys(live: str):
    """Top-level event keys of the `on:` block, at whatever indent it uses."""
    block = _on_block(live)
    child = None
    for l in block.splitlines():
        if l.strip() and not l.lstrip().startswith("#"):
            child = len(l) - len(l.lstrip())
            break
    if child is None:
        return None            # an `on:` we could not parse -- NOT "declares nothing"
    return set(re.findall(rf"^ {{{child}}}([A-Za-z_][A-Za-z0-9_-]*):", block, re.M))


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


# GitHub's own owner/repo grammar. THE SLUG IS SUBSTITUTED INTO A SINGLE-QUOTED
# GITHUB EXPRESSION, so a value carrying a quote does not merely render wrongly --
# it RESTRUCTURES the predicate. Measured: an `origin` of
# `https://github.com/acme/widget' || true || '.git` rendered
#   if: ${{ github.repository == 'acme/widget' || true || '' && <fork limb> }}
# which is valid YAML and reduces to `A || true || ('' && B)` -- CONSTANT TRUE,
# because `&&` binds tighter than `||`. Both limbs die at once, and a
# `pull_request_target` job holding `checks: write` and a token would then run on
# FORK pull requests. The template's "a wrong slug fails CLOSED" is true of a
# wrong slug and false of a hostile one, so the slug is validated before anything
# consumes it -- the workflow render AND the `gh api repos/<slug>` path.
SLUG_RE = re.compile(r"^[A-Za-z0-9._-]{1,39}/[A-Za-z0-9._-]{1,100}$")


def slug_ok(slug):
    return bool(slug) and bool(SLUG_RE.match(slug))


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
    def __init__(self, repo, hatsu_root, slug, visibility, self_hosted, probe, runner_labels=None):
        self.repo = repo
        self.hatsu_root = hatsu_root
        self.slug = slug or git_slug(repo)
        # ONE gate for both the derived and the --slug path.
        if self.slug is not None and not slug_ok(self.slug):
            usage(f"refusing slug {self.slug!r}: not <owner>/<name> in GitHub's grammar "
                  f"([A-Za-z0-9._-]). A slug is substituted into a single-quoted GitHub "
                  f"expression and into a `gh api repos/<slug>` path, so a value outside that "
                  f"grammar can restructure the job's guard predicate rather than merely break it")
        self.git_dir = git_dir(repo)
        self.notes = []
        if visibility is None and probe and self.slug:
            visibility = probe_gh(self.slug, "visibility")
        if self_hosted is None and probe and self.slug:
            self_hosted = probe_gh(self.slug, "runners")
        self.visibility = visibility
        self.self_hosted = self_hosted or 0
        self.runner = derive_runner(visibility, self.self_hosted)
        self.runner_labels = runner_labels
        if self.runner.get("labels_required") and runner_labels:
            self.runner["runs_on"] = runner_labels
            self.runner["labels_required"] = False

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
        """True / False / None -- and None is the point.

        `git check-ignore` cannot answer in a directory that is not a repository
        yet. Reading that as "not ignored" made `repair` APPEND unconditionally,
        so three `apply` runs against a non-git directory produced three copies of
        `Reports/` and `.nen/` in .gitignore -- idempotence failing in the exact
        "new repository" case the skill's own description claims.
        """
        if ctx.git_dir is None:
            return None
        probe = f"{self.rel}/probe"
        try:
            out = subprocess.run(["git", "-C", str(ctx.repo), "check-ignore", "-q", probe],
                                 capture_output=True, text=True, timeout=15)
            return out.returncode == 0
        except Exception:
            return None

    def detect(self, ctx):
        exists = (ctx.repo / self.rel).is_dir()
        ignored = self._ignored(ctx)
        if ignored is None:
            return self.row(BLOCKED,
                            f"not a git repository — there is nothing to ignore {self.rel}/ into yet",
                            "run `git init` (or `nen scaffold init`) first, then re-run apply")
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
        if cur["state"] == BLOCKED:
            return cur
        did = []
        d = ctx.repo / self.rel
        if not d.is_dir():
            d.mkdir(parents=True, exist_ok=True)
            (d / ".gitkeep").write_text("")
            did.append("created")
        if self._ignored(ctx) is False:
            gi = ctx.repo / ".gitignore"
            prev = gi.read_text() if gi.is_file() else ""
            if prev and not prev.endswith("\n"):
                prev += "\n"
            gi.write_text(prev + f"{self.rel}/\n")
            did.append("added to .gitignore")
        return self.row(REPAIRED, f"{self.rel}/ " + " and ".join(did))


class NenCommitMsgHook(Item):
    """DIAGNOSED here, REPAIRED by nen -- and the correction matters.

    An earlier revision of this file RENDERED a Hatsu-authored `commit-msg` hook
    from `templates/commit-msg`. That was wrong by this repository's own canon:
    `docs/ROSTER.md` § 2 assigns layer (b) of the three-layer attribution
    enforcement to "a target repository's `commit-msg` hook, generated by
    `nen scaffold init` from `allowedAttributionTrailers`", and
    `nen scaffold init` installs exactly that, at exactly this path, from exactly
    that policy file.

    The duplication was DESTRUCTIVE IN BOTH ORDERINGS, measured on fixtures:
    Tenkai first, and `nen scaffold init` refuses ("a different commit-msg hook
    already exists ... refusing to overwrite it"); nen first, and Tenkai reported
    the generated hook as foreign drift and advised DELETING it -- so the item
    could never reach satisfied and `apply` could never exit 0.

    So this item now does what every other nen-owned item does: it asserts
    presence and routes. Tenkai writes no hook, which also removes three
    ways the old one could go wrong -- a write outside `--repo` through the git
    common dir, a followed symlink, and `core.hooksPath` being ignored so the
    hook was reported "installed and current" where git would never run it.
    """

    def __init__(self):
        super().__init__("hooks/commit-msg", "the commit trailer gate, generated from nen/workflow.json", "nen")

    @staticmethod
    def _dest(ctx):
        """Where git will ACTUALLY look, `core.hooksPath` included."""
        gd = ctx.git_dir
        if gd is None:
            return None
        try:
            out = subprocess.run(["git", "-C", str(ctx.repo), "config", "--get", "core.hooksPath"],
                                 capture_output=True, text=True, timeout=15)
            if out.returncode == 0 and out.stdout.strip():
                hp = Path(out.stdout.strip())
                return (hp if hp.is_absolute() else ctx.repo / hp) / "commit-msg"
        except Exception:
            pass
        return gd / "hooks" / "commit-msg"

    def detect(self, ctx):
        dest = self._dest(ctx)
        if dest is None:
            return self.row(BLOCKED, "not a git repository — there is no hooks directory to look in")
        if dest.is_file():
            return self.row(SATISFIED, f"present at {dest}")
        return self.row(ROUTED,
                        f"no commit-msg hook at {dest} — the repository's trailer policy is enforced "
                        f"by the agent-side refusal and by `nen commit format` / `nen wc squash`, but "
                        f"not by git. nen owns this hook and Tenkai does not write one",
                        f"nen scaffold init --repo {ctx.repo} --agent-trailer Hatsu-Agent")

    def repair(self, ctx):
        return self.detect(ctx)   # never written here; routing IS the repair


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

    # THE THREE CONSTANTS THAT CONSTITUTE REGISTRATION, and only those.
    # A whole-file substring is COMMENT-STRENGTH, not grep-strength: this
    # repository's own guard names `pr-readiness.yml` in a COMMENT on line 13,
    # and a guard whose only mention is `# TODO: someday register pr-readiness.yml`
    # scored as registered -- so `apply` would write the workflow into a
    # repository whose guard cannot know it, which is the exact pull request that
    # fails every required check for one cause. `PORTABLE_HOSTED_WORKFLOWS` is
    # excluded on purpose: the routed action tells the maintainer NOT to add the
    # file there, so mentioning it must not satisfy the gate either.
    REGISTRATION_CONSTANTS = ("EXPECTED_JOBS", "EXPECTED_TYPES", "EXPECTED_STEPS")

    @staticmethod
    def state_of(ctx):
        g = ctx.repo / GUARD_PATH
        if not g.is_file():
            return "absent"          # no guard: no ordering constraint at all
        src = "\n".join(l for l in g.read_text().splitlines()
                        if not l.lstrip().startswith("#"))
        named = [c for c in GuardRegistration.REGISTRATION_CONSTANTS
                 if re.search(rf"{c}\s*=.*?pr-readiness\.yml", src, re.S)]
        return "registered" if len(named) == len(GuardRegistration.REGISTRATION_CONSTANTS) else "unregistered"

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

    MARKER = "RENDERED BY hatsu:tenkai"

    def render(self, ctx):
        t = ctx.template("pr-readiness.yml")
        return (t.replace("@@REPO_SLUG@@", ctx.slug)
                 .replace("@@RUNS_ON@@", ctx.runner["runs_on"])
                 .replace("@@RUNNER_REASON@@", ctx.runner["reason"]))

    def detect(self, ctx):
        # BEFORE the file check, so `repair`'s BLOCKED early-return stops the write
        # on a fresh repository too -- not only where a file already exists.
        if ctx.runner.get("labels_required"):
            return self.row(BLOCKED,
                            "this repository derives a self-hosted runner, but a BARE `self-hosted` "
                            "selects any runner registered to the repository or its organisation — "
                            "the policy guard admits only labelled sets, and the labels are this "
                            "repository's own data, which Tenkai does not invent",
                            "pass --runner-labels '[self-hosted, <OS>, <arch>]'")
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
        drifts, notes = [], []
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
        # AN UNREADABLE FACT IS NOT A CHANGED FACT. The ruling "unreadable ->
        # hosted" governs RENDERING A NEW FILE. Reused as the drift EXPECTATION it
        # means an offline `apply` reports a correct `self-hosted` as drift and then
        # silently reverts it -- resolving "could not read" toward a write. When the
        # probe could not answer, this limb is reported unchecked and left alone.
        m = re.search(r"runs-on:\s*(\[[^\]]*\]|\S+)", live)
        if ctx.visibility is None:
            notes.append("runner limb unread: `gh` could not answer for this repository, so "
                         "`runs-on` was not compared and will not be rewritten")
        elif m and m.group(1) != ctx.runner["runs_on"]:
            drifts.append(f"runs-on is '{m.group(1)}', but this repository derives "
                          f"'{ctx.runner['runs_on']}' ({ctx.runner['reason']})")
        # THE INVARIANTS THE TEMPLATE SAYS IT INHERITS. Checking the slug, the
        # runner and the triggers left every security property of a PRIVILEGED,
        # CREDENTIALED workflow unchecked: a rendered file was mutated with the
        # trust boundary inverted, `persist-credentials` dropped, write scopes
        # added, a PR-controlled `${{ }}` put inside a `run:` body, and `--gates`
        # downgraded -- and `diagnose` still said `ok`. In a consumer with no
        # policy guard of its own, THIS IS THE ONLY SAFETY NET the workflow has.
        #
        # `--gates` is matched as the WHOLE ARGUMENT, not as a flag name: the
        # repository's own Ruby guard documents why a substring is not enough --
        # `--gates nen/gates.json` satisfies a substring test and resolves against
        # the PR HEAD checkout, handing the pull request the gate that judges it.
        if '--gates "$PWD/.trusted/nen/gates.json"' not in live:
            drifts.append("the verdict step does not pass --gates with the TRUSTED absolute path, so "
                          "nen falls back to the PR head checkout's own gates file — the PR would "
                          "supply the gate that judges it")
        # SCOPE THE TRUSTED-REF CHECK TO ITS OWN STEP BLOCK. A fixed character
        # window reached back into the PRECEDING PR-head checkout step and
        # reported every correct file as inverted -- a false positive that, under
        # `apply`, would have rewritten a good workflow. Steps are split on their
        # own `- name:` boundary instead.
        steps = re.split(r"\n(?=\s*- name:)", live)
        trusted = [b for b in steps if re.search(r"path:\s*\.trusted", b)]
        if not trusted:
            drifts.append("there is no `.trusted` checkout — the guard and the pin would come from "
                          "the pull request's own tree")
        else:
            for blk in trusted:
                if re.search(r"ref:.*pull_request\.head", blk):
                    drifts.append("the .trusted checkout takes the PR HEAD ref — the trust boundary "
                                  "is inverted and the guard judging the PR would be the PR's own copy")
                    break
        # PER CHECKOUT STEP, not a global count. Counting occurrences meant
        # deleting one from a file that happened to carry three still read as
        # "enough", so the step that actually lost its credential guard was
        # invisible. Every `actions/checkout` is asked individually.
        for blk in steps:
            if "actions/checkout" in blk and "persist-credentials: false" not in blk:
                name = re.search(r"- name:\s*(.+)", blk)
                drifts.append(f"a checkout step is missing `persist-credentials: false` "
                              f"({name.group(1).strip() if name else 'unnamed'}), leaving a "
                              f"credential in the workspace of a pull_request_target job")
        m_perm = re.search(r"^permissions:\n((?:  .*\n)+)", live, re.M)
        if m_perm:
            bad = [l.strip() for l in m_perm.group(1).splitlines()
                   if "write" in l and not l.strip().startswith("checks:")]
            if bad:
                drifts.append(f"the permissions block grants write beyond `checks`: {', '.join(bad)} — "
                              f"a pull_request_target job holds a base-repository credential")
        for blk in re.findall(r"run:\s*\|\n((?:[ \t]+.*\n)+)", live):
            if "${{" in blk:
                drifts.append("a `run:` body interpolates `${{ }}` — PR-controlled text would reach "
                              "the runner's shell; pass it through `env:` instead")
                break
        if "@@" in text:
            drifts.append("still carries unsubstituted @@TOKEN@@ placeholders")
        # THE TRIGGER SET, IN BOTH DIRECTIONS. A missing trigger is the
        # single-trigger bug; an extra one is outside the admitted closed set.
        # PARSE THE `on:` BLOCK, NEVER MATCH AGAINST A LIST OF KNOWN EVENTS. An
        # earlier draft intersected the found keys with a hand-kept allowlist of
        # event names, which meant any event NOT on that list was silently
        # dropped instead of flagged -- so the one case that matters most, an
        # unrecognised trigger, was the one case it could not see. The self-test
        # caught it on `pull_request_review_thread`. Taking every key inside the
        # block has no list to fall out of date.
        declared = _on_keys(live)
        if declared is None:
            drifts.append("the `on:` block could not be parsed, so the trigger set was NOT checked")
            declared = set(REQUIRED_TRIGGERS)
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
            return self.row(DRIFT, "; ".join(drifts + notes), "re-render from templates/pr-readiness.yml")
        detail = f"installed, gated to {ctx.slug}, runs-on {ctx.runner['runs_on']}"
        return self.row(SATISFIED, "; ".join([detail] + notes))

    def repair(self, ctx):
        cur = self.detect(ctx)
        if cur["state"] in (SATISFIED, STAGED, BLOCKED):
            return cur
        # NO PLACEHOLDER PREDICATE, EVER. An earlier revision rendered
        # `github.repository == 'UNKNOWN'` when no slug resolved. That predicate is
        # false on every event forever, so the job is skipped silently -- which is
        # the precise failure mode § 5 of the skill exists to prevent, reintroduced
        # by the tool meant to prevent it. The `@@` guard did not catch it, because
        # the token WAS substituted; it was substituted with a guaranteed-false value.
        if not ctx.slug:
            return self.row(BLOCKED,
                            "no slug resolves for this repository, and a workflow rendered with a "
                            "placeholder predicate is SKIPPED on every event, forever",
                            "pass --slug <owner/name>")
        p = ctx.repo / WORKFLOW_PATH
        # SOMEBODY ELSE'S WORKFLOW IS SOMEBODY ELSE'S -- the same rule the hook item
        # carried and this one did not. A hand-written pr-readiness.yml was silently
        # replaced by 367 rendered lines, unrecoverable when untracked.
        if p.is_file() and self.MARKER not in p.read_text():
            return self.row(DRIFT,
                            "a pr-readiness.yml is installed that Tenkai did not render — "
                            "it will not be overwritten",
                            "review by hand, then delete it and re-run apply")
        p.parent.mkdir(parents=True, exist_ok=True)
        _atomic_write(p, self.render(ctx))
        return self.row(REPAIRED, f"rendered for {ctx.slug}, runs-on {ctx.runner['runs_on']}")


class PrivilegedWorkflows(Item):
    """Read-only. Names every OTHER privileged workflow, and the enforcement gap.

    Tenkai installs a `pull_request_target` job — privileged, credentialed — and
    installs NO policy guard. In a consumer with no
    `scripts/workflow_runner_policy_check.rb`, `GuardRegistration` scores `absent`
    as "no ordering constraint", which is true about the ORDERING and says nothing
    about enforcement: the byte-compared same-repo guard, the write-permission
    refusal and the trusted-data rules all live in that script. So the net effect
    of an adoption run on a fresh repository was one new privileged workflow and
    zero new enforcement around it.

    This item does not close that gap — installing the guard is a separate,
    maintainer-owned change. It refuses to let the gap be SILENT: the other
    privileged workflows are named, and § 5 of the skill states what is not
    inherited.
    """

    PRIVILEGED = ("pull_request_target", "workflow_run", "issue_comment", "workflow_call")

    def __init__(self):
        super().__init__("workflows/privileged", "other privileged workflows, and what enforces them", "hatsu")

    def detect(self, ctx):
        d = ctx.repo / ".github" / "workflows"
        if not d.is_dir():
            return self.row(SATISFIED, "no .github/workflows/ directory")
        others = []
        for f in sorted(d.glob("*.y*ml")):
            if f.name == Path(WORKFLOW_PATH).name:
                continue
            live = "\n".join(l for l in f.read_text().splitlines() if not l.lstrip().startswith("#"))
            keys = _on_keys(live) or set()
            hit = sorted(k for k in keys if k in self.PRIVILEGED)
            if hit:
                others.append(f"{f.name} ({', '.join(hit)})")
        guard = "present" if (ctx.repo / GUARD_PATH).is_file() else "ABSENT"
        detail = (f"policy guard {guard}; "
                  + (f"other privileged workflows: {'; '.join(others)}" if others
                     else "no other privileged workflow"))
        if guard == "ABSENT":
            detail += ". Tenkai installs a privileged pull_request_target job and NO guard — "
            detail += "this repository inherits no ongoing enforcement around it"
        return self.row(SATISFIED, detail)

    def repair(self, ctx):
        return self.detect(ctx)   # observation only; it writes nothing, ever


def items():
    out = [NenDeclaration(path, what) for path, what in NEN_DECLARATIONS]
    out.append(ColorsFile())
    out.append(IgnoredDir("dirs/reports", "Reports", "where rikugan writes the retained final report"))
    out.append(IgnoredDir("dirs/nen-state", ".nen", "where the hanten cycle ledger and the stop marker live"))
    out.append(NenCommitMsgHook())
    out.append(GuardRegistration())
    out.append(ReadinessWorkflow())
    out.append(PrivilegedWorkflows())
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
def self_test() -> int:
    root = Path(os.environ["TENKAI_DEFAULT_ROOT"])
    failures = []
    checks_run = 0

    def check(name, cond, detail=""):
        nonlocal checks_run
        checks_run += 1
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
        _FIXTURES.append(d)
        subprocess.run(["git", "-C", str(d), "init", "-q"], check=True)
        subprocess.run(["git", "-C", str(d), "remote", "add", "origin",
                        f"https://github.com/{slug}.git"], check=True)
        if with_guard:
            g = d / GUARD_PATH
            g.parent.mkdir(parents=True, exist_ok=True)
            body = "# guard — a COMMENT naming pr-readiness.yml must NOT count\n"
            for const in ("EXPECTED_JOBS", "EXPECTED_TYPES", "EXPECTED_STEPS"):
                body += f"{const} = {{" + ("'pr-readiness.yml' => 1" if registered else "") + "}.freeze\n"
            g.write_text(body)
        return d

    def ctx_for(d, slug="acme/widget", vis="private", sh=2, labels="[self-hosted, Linux, X64]"):
        return Ctx(d, root, slug, vis, sh, probe=False, runner_labels=labels)

    print("\ngreenfield — diagnose then apply then apply again")
    d = fixture()
    first = run("diagnose", ctx_for(d))
    check("a bare repository is not a consumer", first["outstanding"] > 0)
    by = {r["id"]: r for r in first["items"]}
    check("the commit-msg hook routes to nen, never written",
          by["hooks/commit-msg"]["state"] == ROUTED)
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
    check("workflow repaired", by[WORKFLOW_PATH]["state"] == REPAIRED)
    check("the rendered workflow carries the real slug",
          "github.repository == 'acme/widget'" in (d / WORKFLOW_PATH).read_text())
    check("no @@TOKEN@@ survives rendering", "@@" not in (d / WORKFLOW_PATH).read_text())
    check("private+registered renders the LABELLED set, never a bare self-hosted",
          re.search(r"runs-on:\s*\[self-hosted, Linux, X64\]", (d / WORKFLOW_PATH).read_text()) is not None
          and re.search(r"runs-on:\s*self-hosted\s*$", (d / WORKFLOW_PATH).read_text(), re.M) is None)

    print("\nRUNNER LABELS — a bare `self-hosted` is never rendered")
    dnl = fixture()
    row = run("apply", ctx_for(dnl, labels=None))
    wf = [r for r in row["items"] if r["id"] == WORKFLOW_PATH][0]
    check("private + registered runners with NO labels is BLOCKED", wf["state"] == BLOCKED)
    check("and the refusal names the flag that answers it",
          "--runner-labels" in (wf["action"] or ""))
    check("nothing was written", not (dnl / WORKFLOW_PATH).is_file())
    # Indexed BY ID, never by position: a fixture that says `items[-1]` breaks the
    # moment an item is added, and reports it as a failure of the thing it names.
    pub = {r["id"]: r for r in
           run("apply", ctx_for(fixture(), vis="public", sh=0, labels=None))["items"]}
    check("public still derives hosted and renders fine",
          pub[WORKFLOW_PATH]["state"] == REPAIRED)

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

    w.write_text(w.read_text().replace("runs-on: [self-hosted, Linux, X64]", "runs-on: ubuntu-latest"))
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
    t = re.sub(r"^  pull_request_review:\n(?:    .*\n)*", "", w.read_text(), flags=re.M)
    w.write_text(t)
    row = ReadinessWorkflow().detect(ctx_for(d))
    check("a single-trigger workflow is DRIFT", row["state"] == DRIFT)
    check("and the never-recomputed consequence is named, not just the absence",
          "NEVER recomputed" in row["detail"])
    ReadinessWorkflow().repair(ctx_for(d))
    check("both admitted triggers are restored",
          ReadinessWorkflow().detect(ctx_for(d))["state"] == SATISFIED)

    # THE REGRESSION THAT WOULD HAVE BROKEN EVERY CONSUMER. An earlier version of
    # this engine REQUIRED pull_request_review_thread. It is a webhook event and
    # not an Actions trigger, so a workflow naming it cannot register -- `apply`
    # would have reported a correct workflow as drift and then rendered one that
    # does not run. It must now be refused as firmly as any other non-admitted
    # event, so this fixture is the guard against re-adopting it.
    t = w.read_text().replace(
        "  pull_request_review:\n",
        "  pull_request_review_thread:\n    types: [resolved, unresolved]\n  pull_request_review:\n", 1)
    w.write_text(t)
    row = ReadinessWorkflow().detect(ctx_for(d))
    check("pull_request_review_thread is DRIFT — it cannot register at all",
          row["state"] == DRIFT and "pull_request_review_thread" in row["detail"])
    ReadinessWorkflow().repair(ctx_for(d))
    check("it is removed again by repair",
          ReadinessWorkflow().detect(ctx_for(d))["state"] == SATISFIED)

    # ANOTHER NON-ADMITTED TRIGGER, refused for its own separate reason.
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

    # THE SHIPPED TEMPLATE ITSELF, checked on its LIVE yaml rather than its prose
    # -- the banner legitimately discusses the event it refuses.
    tmpl = (root / "templates" / "pr-readiness.yml").read_text()
    tmpl_live = "\n".join(l for l in tmpl.splitlines() if not l.lstrip().startswith("#"))
    check("the shipped template declares exactly the admitted two",
          re.findall(r"^  (pull_request[a-z_]*):", tmpl_live, re.M) == list(REQUIRED_TRIGGERS))
    check("the shipped template does NOT name the unregistrable event in live yaml",
          "pull_request_review_thread:" not in tmpl_live)
    check("the shipped template carries the widened CON-32(b) types",
          "review_requested" in tmpl_live and "review_request_removed" in tmpl_live)
    check("the engine mirrors the guard's own ALLOWED_TRIGGERS",
          set(REQUIRED_TRIGGERS) == {"pull_request_target", "pull_request_review"})

    print("\nOWNERSHIP — nen's items are routed, never written")
    hook_row = NenCommitMsgHook().detect(ctx_for(d))
    check("the commit-msg hook is a nen item, not a Hatsu one",
          NenCommitMsgHook().owner == "nen")
    check("an absent hook is ROUTED to nen scaffold init",
          hook_row["state"] == ROUTED and "nen scaffold init" in (hook_row["action"] or ""))
    hooks_dir = ctx_for(d).git_dir / "hooks"
    before_hook = sorted(x.name for x in hooks_dir.iterdir()) if hooks_dir.is_dir() else []
    NenCommitMsgHook().repair(ctx_for(d))
    after_hook = sorted(x.name for x in hooks_dir.iterdir()) if hooks_dir.is_dir() else []
    check("repair writes NO hook — routing is the repair", before_hook == after_hook)
    # BEHAVIOURAL, not source-text: git looks in core.hooksPath when it is set,
    # and an item that reported "installed and current" against the default path
    # while git looked elsewhere is the silent-skip failure this tool exists to end.
    dhp = fixture()
    subprocess.run(["git", "-C", str(dhp), "config", "core.hooksPath", "myhooks"], check=True)
    (dhp / "myhooks").mkdir()
    dest = NenCommitMsgHook._dest(ctx_for(dhp))
    check("core.hooksPath decides where git actually looks",
          dest == dhp / "myhooks" / "commit-msg", f"got {dest}")
    (dhp / "myhooks" / "commit-msg").write_text("#!/bin/sh\nexit 0\n")
    check("a hook in core.hooksPath is seen as present",
          NenCommitMsgHook().detect(ctx_for(dhp))["state"] == SATISFIED)

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

    def snapshot(root: Path):
        """{path: sha256} over everything, INCLUDING .git/hooks.

        The old proof compared NAMES and filtered out `.git/`, which is the one
        directory the hook item could write into -- so a regression that installed
        a hook during `detect` would have passed it green. Content hashes also
        catch an in-place rewrite of an existing path, which a name list cannot.
        """
        out = {}
        for f in root.rglob("*"):
            rel = str(f.relative_to(root))
            if rel.startswith(".git/objects") or rel.startswith(".git/index"):
                continue
            if f.is_file():
                out[rel] = hashlib.sha256(f.read_bytes()).hexdigest()
        return out

    d4 = fixture()
    before = snapshot(d4)
    run("diagnose", ctx_for(d4))
    after = snapshot(d4)
    check("diagnose wrote nothing — by CONTENT, over the whole tree including .git/hooks",
          before == after, f"changed: {sorted(set(before) ^ set(after))}")

    print("\nCLAIMS THAT HAD NO FIXTURE — the combination that rots quietly")
    # A TUNED colors.yml MUST SURVIVE. § 4 and Hard limits both promise the engine
    # never compares it byte-for-byte against the seed; nothing tested it.
    dt = fixture()
    (dt / "nen").mkdir(parents=True, exist_ok=True)
    tuned = ("version: 1\ncategories:\n  my_own_family:\n    precedence: [a]\n"
             "    values:\n      a:\n        label: Mine\n")
    (dt / "nen" / "colors.yml").write_text(tuned)
    check("a tuned colors.yml is satisfied, not compared to the seed",
          ColorsFile().detect(ctx_for(dt))["state"] == SATISFIED)
    ColorsFile().repair(ctx_for(dt))
    check("and apply leaves its bytes untouched",
          (dt / "nen" / "colors.yml").read_text() == tuned)

    # THE GUARD-COMMENT CASE. This repository's own guard names the file in a
    # comment, so a whole-file substring was comment-strength, not grep-strength.
    dc = fixture()
    (dc / GUARD_PATH).parent.mkdir(parents=True, exist_ok=True)
    (dc / GUARD_PATH).write_text("# TODO: someday register pr-readiness.yml here\n"
                                 "EXPECTED_JOBS = {}.freeze\n")
    check("a guard naming the file only in a COMMENT is unregistered",
          GuardRegistration.state_of(ctx_for(dc)) == "unregistered")
    res = run("apply", ctx_for(dc))
    check("so the workflow is staged, not written", not (dc / WORKFLOW_PATH).is_file())
    # PORTABLE_HOSTED_WORKFLOWS must not satisfy it either -- the routed action
    # explicitly tells the maintainer NOT to add the file there yet.
    (dc / GUARD_PATH).write_text("PORTABLE_HOSTED_WORKFLOWS = %w[pr-readiness.yml].freeze\n")
    check("naming it ONLY in PORTABLE_HOSTED_WORKFLOWS is still unregistered",
          GuardRegistration.state_of(ctx_for(dc)) == "unregistered")

    # THE "NEW REPOSITORY" HALF OF THE SKILL'S OWN DESCRIPTION.
    dn = Path(tempfile.mkdtemp(prefix="tenkai-fixture-")); _FIXTURES.append(dn)
    for _ in range(3):
        run("apply", Ctx(dn, root, "acme/widget", "public", 0, probe=False))
    gi = dn / ".gitignore"
    check("three applies to a NON-GIT directory do not grow .gitignore",
          not gi.is_file() or gi.read_text().count("Reports/") <= 1,
          gi.read_text() if gi.is_file() else "(absent)")

    ds = fixture()
    subprocess.run(["git", "-C", str(ds), "remote", "remove", "origin"], check=True)
    row = ReadinessWorkflow().repair(Ctx(ds, root, None, "public", 0, probe=False))
    check("no slug resolvable -> BLOCKED, never a placeholder predicate",
          row["state"] == BLOCKED)
    check("and nothing is written", not (ds / WORKFLOW_PATH).is_file())

    # A HOSTILE SLUG must be refused before it reaches a predicate or a URL.
    dh = Path(tempfile.mkdtemp(prefix="tenkai-fixture-")); _FIXTURES.append(dh)
    subprocess.run(["git", "-C", str(dh), "init", "-q"], check=True)
    subprocess.run(["git", "-C", str(dh), "remote", "add", "origin",
                    "https://github.com/acme/widget' || true || '.git"], check=True)
    try:
        Ctx(dh, root, None, "public", 0, probe=False)
        check("a quote-bearing slug is refused before it is rendered", False, "it was accepted")
    except SystemExit as exc:
        check("a quote-bearing slug is refused before it is rendered", exc.code == 2)
    check("slug grammar accepts the ordinary case", slug_ok("zheref/hatsu"))
    check("slug grammar rejects a traversal", not slug_ok("x/../../user"))

    # SOMEBODY ELSE'S WORKFLOW IS SOMEBODY ELSE'S.
    dw = fixture()
    (dw / WORKFLOW_PATH).parent.mkdir(parents=True, exist_ok=True)
    (dw / WORKFLOW_PATH).write_text("name: mine\non: push\njobs: {}\n")
    row = ReadinessWorkflow().repair(ctx_for(dw))
    check("a hand-written pr-readiness.yml is NOT overwritten", row["state"] == DRIFT)
    check("and its bytes survive", "name: mine" in (dw / WORKFLOW_PATH).read_text())

    # AN UNREAD PROBE IS NOT A CHANGED FACT.
    du = fixture()
    run("apply", ctx_for(du))
    row = ReadinessWorkflow().detect(Ctx(du, root, "acme/widget", None, 0, probe=False))
    check("an unreadable visibility does not report runs-on drift", row["state"] == SATISFIED)
    check("and says the limb went unchecked", "runner limb unread" in row["detail"])

    # THE TEMPLATE AND THIS REPOSITORY'S OWN colors.yml ARE ONE VOCABULARY.
    def body(pth):
        return [l for l in pth.read_text().splitlines() if not l.lstrip().startswith("#")]
    check("templates/colors.yml and nen/colors.yml carry the same vocabulary",
          body(root / "templates" / "colors.yml") == body(root / "nen" / "colors.yml"))

    print("\nblocked states are reported, never repaired around")
    d5 = fixture()
    (d5 / "nen").mkdir()
    (d5 / "nen" / "contract.json").write_text("{not json")
    row = NenDeclaration("nen/contract.json", "x").detect(ctx_for(d5))
    check("malformed JSON is BLOCKED, not silently rewritten", row["state"] == BLOCKED)

    print()
    if failures:
        print(f"tenkai_adopt --self-test: {len(failures)} FAILED: {', '.join(failures)}")
        return 1
    print(f"tenkai_adopt --self-test: all green ({checks_run} assertions)")
    return 0


# --------------------------------------------------------------------------
def _self_test_guarded() -> int:
    """Every fixture is removed on EVERY path, including a failing assertion.

    The old loop removed five named directories after the last check, so any
    exception -- or a `return` from a failure -- leaked them into /tmp.
    """
    made: list = []
    try:
        return self_test()
    finally:
        for d in _FIXTURES:
            shutil.rmtree(d, ignore_errors=True)
        _FIXTURES.clear()


def main(argv):
    if not argv:
        usage("a subcommand is required: diagnose | apply | runner-policy | --self-test")
    cmd, rest = argv[0], argv[1:]
    if cmd == "--self-test":
        raise SystemExit(_self_test_guarded())

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

    ctx = Ctx(repo, hatsu_root, opts.get("slug"), vis, sh, probe=True,
              runner_labels=opts.get("runner-labels"))
    res = run(cmd, ctx)
    report(res, as_json)
    raise SystemExit(1 if res["outstanding"] else 0)


main(sys.argv[1:])
PY
