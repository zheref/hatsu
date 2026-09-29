---
name: tenkai
description: Make a repository — new or existing, consumer or not — a working Hatsu consumer, deterministically and idempotently. It DIAGNOSES before it writes, reports what was satisfied, missing or drifted, repairs Hatsu-owned surfaces, and guides the owner through every remaining development-workflow decision. Use when the maintainer invokes hatsu:tenkai [<path>], asks to adopt, onboard or set up a repository, asks why a Hatsu skill does not work somewhere, or when hatsu:ten's verification reports an adoption item unsatisfied. The engine never writes a nen-owned declaration; the agent may configure a consumer's declaration after an owner decision and validation. It never invents a colour taxonomy, merges, pushes or opens a pull request.
---

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md`,
`docs/LAUNCH-MIGRATION.md`, `docs/STANDALONE-ENTRY.md`, `docs/PROCESS.md` and `docs/SURFACES.md` belong to the resolved **Hatsu plugin
root**, not the consuming repository. On an installed surface, use the absolute root printed by
`ten` to read those files (re-resolve through that skill if unavailable). Relative links
below identify source locations; a missing consumer `docs/` copy is not a missing policy and must not
trigger a duplicate filing. Never copy or invent a second policy in the target repository.
`docs/GATE-CONFIGURATION.md` resolves there too.


# Tenkai — the unfolding, by which a repository becomes a consumer

> **The gate on a declaration change is the REPOSITORY's role, not the file's kind.** Maintainer's
> ruling, 2026-09-18 ([`docs/ROSTER.md`](../../../docs/ROSTER.md) § *Rulings of 2026-09-18 — G4 is
> the repository's role, not the file's kind*): **`G4` (`CON-7`) in a canon repository** —
> the repositories `nen repo classify` reports as `role: canon` (`nen/repos.json` → `maintained_tools`),
> whose product *is* the process — and **`G2` (`CON-5`) in a consumer repository**, where a
> `nen/contract.json`, `nen/workflow.json` or `nen/gates.json` is that repository's own configuration
> and governs nothing else. **This skill exists to run against consumer checkouts**, so its ordinary
> case is `G2`. The merge is `en` § 5's either way — the ruling moves the gate, never the
> owner.

**Nature: Transmuter** carries every run. Adoption shapes machinery: it renders templates, installs a
hook, creates directories and guides declaration changes through the verb that owns them. It authors no product
code and no canon. The one place a run comes close — seeding `nen/colors.yml` — is explicitly a
**seed and not a canon file** (§ 4), and a repository that wants a real taxonomy authors one as
Conjurer work in its own right.

> **Before a skill can work here, the things every skill reads have to exist. Find out which of them
> do, say so item by item, fix the ones that are mine to fix, and name the owner of the ones that are
> not.**

---

## 0. Standalone entry — when no composite is holding the run

**Tenkai is normally typed by the maintainer, and that IS its wired position** — no composite owns
adoption, because adoption happens before the loop exists. The contract is
[`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md); this is Tenkai's half.
**Reached from ANY composite, skip this section entirely** — the caller established every fact in it,
and re-deriving them is how two answers to one question appear. The clause is stated in the generic
form every other phase carries, rather than argued from the fact that no composite calls this one.

**Run the preamble's `P1` (warm up), `P2` (orient), `P4` (elicit) and `P5` (declare).** `P1b` and
`P3` do **not** apply and are declined explicitly rather than half-performed — and the declining is
itself declared, so a reader can tell a step that was considered from one that was forgotten:

| Preamble step | What Tenkai does |
|---|---|
| **`P1` warm up** | Runs, unconditionally, as `hatsu:ten tenkai` (ten § 6 catches up the prerequisites). `ten` establishes `D10` and prints `$hatsu_root`, and **`$hatsu_root` is where `templates/` lives** — an adoption that resolved its templates from the TARGET repository would render a consumer's stale copy of a file back over itself |
| **`P1b` prove the base** | **Does not apply to diagnosis.** Tenkai reads the checkout as it stands, including existing edits. Before a scoped consumer configuration edit, run the relevant declared check on the current tree and record any pre-existing red so the edit is not credited with causing or fixing it |
| **`P2` orient** | Runs. The branch, dirty-or-clean, and the slug are all read out loud before anything is written, because `apply` writes to the working copy and the maintainer must see what state it was in |
| **`P3` the delta** | **Does not apply, and this is the one that matters.** Tenkai does not read a change set. Its subject is the checkout's CURRENT configuration, not what this effort changed, so there is no base to fetch and no `against <base>` clause. **A repository is diagnosed as it stands** |
| **`P4` elicit** | Ask for `--slug` only when no `origin` resolves one. The apply choice is already answered when the maintainer explicitly requested repair. Group independent owner decisions into native option pickers of at most three questions per call; ask only decisions the declaration and prior answers cannot settle. Reuse answers from this session |
| **`P5` declare** | Runs. One line before any item is read: `standalone entry · no composite is holding this run · <repo> · slug <slug> · runner <label> (<reason>) · not running: nothing — adoption is not a phase of the loop`. **`(fetched <sha>)` is never asserted**, because Tenkai runs no fetch — there is no delta to establish (`P3`) |

**`S4` — the artifact question — is answered by the engine, not by prose.** Tenkai's own state is
whatever is on disk: `scripts/tenkai_adopt.sh diagnose` re-derives every item on every run and holds
no ledger. **There is deliberately no adoption marker file.** A marker would answer *"has Tenkai
run"*, and the question that matters is *"is this repository CURRENT"* — which a marker written at
`v0.30.0` answers wrongly and confidently. Re-deriving is cheap; a stale marker is not.

---

## 1. Invocation

```
hatsu:tenkai                 # the checkout the session is standing in
hatsu:tenkai <path>          # another checkout on this machine
hatsu:tenkai diagnose        # diagnose only, write nothing, whatever else is true
```

**`diagnose` is the default posture and `apply` is never implicit.** A bare invocation runs the
diagnosis and prints the per-item report. If Hatsu owns missing or drifted items that `apply` can
repair, ask through the surface's own option picker before writing, with the count of repairable
items in the question. An explicit request to set up or repair those items supplies the apply
decision for that run:

> `<repo>` has `<n>` outstanding item(s): `<ids>`. I will render `<k>` file(s) and install `<h>` hook(s).
> ⭐ **Apply** · **Diagnose only** · **Stop**

If only nen-owned routed seats remain, skip the apply picker: `apply` cannot configure a product's
commands. For an explicit `diagnose`, report § 6c's remaining choices and checks without asking or
writing. Otherwise continue through § 6c's guided readiness pass after a setup request or owner
answer. A product's Store and direct-download
release decisions are asked together when they are unknown, then recorded as separate lane seats;
Tenkai never substitutes a generic process publisher for either destination.

A missing argument or configuration item is asked for and set up inline (`missing-argument`,
`missing-configuration`; [`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 4 *Ask, set up, continue*) —
tenkai **is** the owner that sets up a Hatsu-owned piece (`scripts/tenkai_adopt.sh apply`).
It routes an initial Nen declaration to `nen scaffold init`; an existing consumer's
missing lane configuration follows § 6c.

**`diagnose` is a strictly read-only run with every setup question suppressed**: § 6c may inspect
declarations and run read-only Nen probes, but it neither executes artifact-producing checks nor
edits consumer files. This is what [`hatsu:ten`](../ten/SKILL.md) § 0a calls.
**One name, not two** — an earlier draft called it `check` here and `diagnose` there.

---

## 2. The engine, and why it is a script

```bash
hatsu_root='<the absolute path ten § 0 printed>'    # explicit input, never assumed
"$hatsu_root/scripts/tenkai_adopt.sh" diagnose --repo <path> [--slug <owner/name>] [--json]
"$hatsu_root/scripts/tenkai_adopt.sh" apply    --repo <path> [--slug <owner/name>] [--json]
"$hatsu_root/scripts/tenkai_adopt.sh" runner-policy --visibility <public|private> --self-hosted <n>
"$hatsu_root/scripts/tenkai_adopt.sh" --self-test
```

**The engine is addressed through `$hatsu_root`, for the reason § 0's `P1` row already gives about
`templates/`.** On an installed surface the working directory is the **consumer** repository, so a
bare `scripts/tenkai_adopt.sh` resolves to nothing — or, worse, to a same-named script the target
repository happens to carry. `--hatsu-root` defaults to the script's own parent, which is right once
the script is the right script.

**After `apply`, place the permission pack** (zheref/hatsu#85 — the maintainer's ruling of 2026-09-19 that a
session is never asked about an action scoped to its own repository):

```bash
"$hatsu_root/scripts/permissions_pack.sh" --surface <claude-code|codex|cursor|antigravity> --install --target <path>
```

It renders `contracts/permissions.json` into the surface's own files (`.claude/settings.local.json` merged;
`.codex/config.toml` + `.codex/hooks.json`; `.cursor/cli.json` + `.cursor/hooks.json`; nothing on Antigravity,
which has no allowlist file — its pack is the generated hooks, and a persona-wide `auto` policy is
deliberately not emitted because it would approve arbitrary commands), excludes every written path through
`info/exclude`, leaves a file it did not write alone and names it, and skips a target that carries no
`nen/contract.json` or `nen/workflow.json`. Report its one line beside the engine's rows. **The engine's
`diagnose` does not yet know this item** — it is placed by this step and by the warm-up, and the
diagnose row for it is filed as a follow-up on the engine.

**The surface packs are items too, placed by one generator.** Off Claude Code a consumer carries, per
surface, the hooks, the allowlists, the rules files and the `.codex/agents` fragments — everything
`nen surface mirror generate --surface <codex|cursor|antigravity> --out <consumer>/<surface dir>`
emits from this plugin's `nen/workflow.json` models, `contracts/permissions.json` and `hooks/hooks.json`,
stamped with the plugin version (zheref/hatsu#93). The surface dir is `.agents` for Codex skills and
`.codex` for its config, `.cursor` for Cursor, the workspace's Antigravity dir for Antigravity. They
are placed by this step at adoption and refreshed by the warm-up's `surface_bootstrap.sh
--install-all` on every session (ten § 5), the in-tree mirrors having passed `scripts/surface_mirror_check.sh` first; a pack Tenkai did not generate is left alone and named,
never overwritten, and the same `diagnose` follow-up covers its row.

**State is written by a script with fixtures, never counted in prose.** This is the same rule
[`scripts/hanten_cycle_ledger.sh`](../../../scripts/hanten_cycle_ledger.sh) carries and for the same
reason: a skill that counted adoption items in its own reply would get the count right on the turn it
was written and wrong on every turn after. **Relay the engine's rows; never re-derive one by eye, and
never report an item this skill checked by hand as though the engine had.**

**Exit codes, and the one that is routinely misread:**

| Exit | Means |
|---|---|
| `0` | every item the engine checks is structurally satisfied; § 6c still verifies execution and CI wiring before calling the development workflow ready |
| `1` | **work remains.** Not a crash. This is the honest answer to *"is it a consumer yet"*, and a caller that treats it as an error has misread the contract |
| `2` | an invocation or environment defect — no such repo, an unreadable template |

**Read the exit code without a pipe.** `$?` after `cmd | tail` is `tail`'s status.

**The slug.** Derived from `origin` and named out loud. **`--slug` is an entry question**, asked
only when no remote resolves one — because the slug is what the readiness workflow's gate predicate
is rendered with, and a wrong one produces the silent skip § 5 exists to prevent.

---

## 3. What is diagnosed, and who owns each item

**Ownership is the load-bearing column.** An item Hatsu owns, the engine repairs. An item nen
scaffolds is routed to its verb. An existing consumer-specific declaration gap is routed to the
owner decision and § 6c's scoped edit when no Nen edit verb exists. The engine never improvises
either operation.

| Item | Owner | Repair |
|---|---|---|
| `nen/contract.json`, `nen/workflow.json`, `nen/gates.json`, `nen/labels.json`, `nen/repos.json` | **nen** | Initial files are routed to `nen scaffold init`. Tenkai asserts only *present and parseable*; `nen schema check` is the authority on validity. Existing consumer-specific fields follow § 6c |
| `nen/colors.yml` | **Hatsu** | Rendered from `templates/colors.yml` — see § 4, and the reason nen cannot do it |
| `Reports/`, `.nen/` | **Hatsu** | Created **and** git-ignored. Both halves: an unignored `Reports/` puts a rendered HTML report into somebody's next commit |
| the `commit-msg` trailer hook | **nen** | **Routed** to `nen scaffold init` — § 6. Tenkai writes no hook |
| the policy-guard registration | **Hatsu** | **Routed**, and it gates the item below — § 5a |
| `.github/workflows/pr-readiness.yml` | **Hatsu** | Rendered with this repository's slug and derived runner — § 5. **A file Tenkai did not render is never overwritten** |
| other privileged workflows | **Hatsu** | **Observation only.** Named, never written — § 5d |
| `scripts/release-publish.sh` | **Hatsu** | Rendered — **only in a process/system repository** — § 6a; product publishers are chosen by their owners |
| the default lane's `release` row | **nen** | In a process repository, a seat gets an exact row offered — § 6a |
| `lane/<lane>/<verb>` in a product | **nen** | Every declared command is checked; unsupported seats and missing iteration checks are routed — § 6b |
| `workflow/<join>` in a product | **consumer configuration** | Checks toolchain, test selection and results, coverage, and visual evidence links across the declarations — § 6c |
| `gates/check-exclusions` | **Hatsu** | **Observation only.** Reads `nen/gates.json` → `check_exclusions[]` (zheref/hatsu#104): none, or every row live, is `satisfied`; a row lapsed, malformed, or carrying a name the flag cannot be handed is `drift`, named — the maintainer removes or re-rules it; the engine never rewrites a gate |
| `gates/reviewer-fallback` | **Hatsu** | **Observation only.** Reads `nen/gates.json` → `reviewer_fallback` (ruling 2026-09-29): a chain of identities, `terminal: hanten`, a live exhaustion is `satisfied`; a chain step `reviewers[]` does not carry is `routed` (declare it once the app is installed); a lapsed or malformed row, a terminal that is not `hanten`, or the terminal inside the chain is `drift`, named |
| `workflow/review-scopes` | **consumer configuration** | Guide the owner through `review.scopes` when absent; validate with `nen schema check` before Hanten resumes |
| `effort/review-ledger` | **Hanten** | On an active effort branch, diagnose the branch ledger or its PR-keyed ledger when one exists; multiple PR candidates route exact-key selection to Hanten. Hanten checks history and uses `recover-first --confirmed-first-cycle` only after the maintainer confirms no review ran under this key; otherwise restore used counts. Tenkai `apply` does not mint a review budget |

**Seven states, and `drift` is the one the whole skill is for:**

| State | Means |
|---|---|
| `satisfied` | already correct. Nothing was written |
| `repaired` | `apply` fixed it this run |
| `missing` | absent, and Hatsu's to write |
| **`drift`** | **present and quietly wrong.** The interesting case: it looks installed |
| `routed` | outstanding, and owned elsewhere. The exact command is named |
| `staged` | deliberately deferred to a later pull request — § 5a |
| `blocked` | cannot proceed, and the reason is named rather than worked around |

**`missing` and `drift` are reported distinctly, always.** *"It is there"* is not the same claim as
*"it works"*, and conflating them is how a repository sits for three versions with a workflow that
has never once run.

---

## 4. `nen/colors.yml` — a seed, and the one file nen cannot scaffold

**nen ships no built-in colour table and no fallback, deliberately**: a binary that guessed the names
would report a taxonomy the repository does not have. So `nen scaffold init` does not write one
either. A repository without the file still has a `nen color status` that cannot run at all — which
is exactly what `zheref/hatsu` itself lived with until
[`#79`](https://github.com/zheref/hatsu/issues/79).

**It no longer reds the aggregate, and that changed under this file.** Through nen `0.10.x` an
absent `nen/colors.yml` failed `nen schema check` outright; **since nen `0.11.0` it is an `ok` row
reading `absent (optional)`** — the verbs that resolve a colour refuse by name when asked, and the
aggregate no longer fails a repository that never adopted the file. So the file is a seed worth
placing, not a precondition for a readable taxonomy, and § 4a's table reports that row as `ok`
rather than as a failure.

**The vocabulary `templates/colors.yml` carries is not invented and is not nen's**: it is transcribed
from the skills that already resolve it — [`backlog-state`](../backlog-state/SKILL.md) § 6's five
`status` values, their glyphs and their precedence line, and the four `severity` band names
[`futon`](../futon/SKILL.md) and [`backlog-synthesis`](../backlog-synthesis/SKILL.md) already take on
the command line.

**It is a seed, and Tenkai treats it as one.** Once the file parses and declares a `categories`
block, the item is `satisfied` — **the engine never compares it byte-for-byte against the template**,
so a repository that tuned its own families keeps them across every later re-run. **Never widen a
taxonomy on a consumer's behalf**: a colour family they did not ask for is canon authored inside an
adoption run.

---

## 4a. A repository with no lane — where § 3's routing has nowhere to route

**§ 3 routes all five `nen/` files to `nen scaffold init`. That routing has no destination in a
repository with no code lane** — a canon, handbook or documentation repository whose product is
prose. `nen scaffold init` refuses outright:

```
nen scaffold: --accept-detected has nothing to accept: no lane was detected under <path>.
Nen proposes a lane only from a marker it can see, so state the stack with --stack <id> instead.
```

and `--stack <id>` is no answer either, because there is no stack to state. **Nen never guesses a
stack**, which is correct and is exactly why the repair cannot be routed. In such a repository the
taxonomy is hand-authored — modelled on a sibling that already carries it, never invented — and the
item is `routed` to the maintainer rather than to a verb.

**What the bare repository's `nen schema check` actually says**, so the minimum set is not guessed:

| Row | Verdict on a repository carrying no `nen/` |
|---|---|
| `nen/labels.json` | **FAIL** — the aggregate refuses; nen has no built-in copy to fall back on |
| `nen/repos.json` | **FAIL** — same |
| `nen/gates.json` | `warn` — but `nen pr ready` cannot judge the repository without it |
| `nen/contract.json`, `nen/workflow.json`, `nen/decisions.json`, `nen/colors.yml` | `ok` — absent, optional, or defaults apply |

So the floor is `labels.json` + `repos.json` to make the taxonomy readable at all, and `gates.json`
before any readiness verdict means anything.

### Three shapes that are `drift` rather than `missing`

Each of these parses, validates, and is quietly wrong — the state § 3 says the whole skill is for.

- **`latest` is a TOP-LEVEL key of `nen/repos.json`.** Placed inside a `maintained_tools` entry it
  still validates, and `nen schema check` reports `latest (unrecorded)` — a row that reads like a
  repository which has not released yet rather than one whose version is in the wrong place. Read
  the row, not the file.
- **`nen changelog collate` needs an `### Unreleased` anchor.** A `CHANGELOG.md` seeded without one
  is refused with *"the changelog has no '### Unreleased' header to anchor the collation on"* — so a
  freshly adopted repository's first release stops at its first collation unless the seed carries it.
- **A declared label is not a provisioned one.** `nen release preflight` trusts the caller's issue
  list and never checks that the label exists. A `bankai:severity/critical` declared in
  `nen/labels.json` but never created on the repository returns zero matches, and the criticals
  precondition reports **none open because nothing could match**. Adoption must create the labels on
  the repository, not only declare them — the declaration is the record, the provisioning is the gate.

### A repository with no build still needs a check that reports

`CON-32(a)` fails on an **empty** rollup, not only a red one, and it is the second conjunct — so
every later row is `unevaluated` and the pull request can never reach readiness:

```
2  FAILED  CON-32(a)  Every reported check green, on the latest run per check name
     └ NO checks reported at head — an EMPTY rollup, not a red one
3-6  unevaluated
```

§ 5's `pr-readiness.yml` *publishes* `nen pr ready`'s verdict; it is not a substantive gate and does
not stand in for one. **A repository whose product is prose has no build to report, so a check has
to be authored for it** — what such a repository can silently get wrong is not compilation but its
own content: a link that does not resolve, a taxonomy that does not parse, or, in a public
repository built from private sources, a name that should never have been published. Adoption is not
complete while the readiness gate has nothing to read.

---

## 5. The readiness workflow — parameterised, because the alternative fails silently

The workflow this renders was hard-gated `if: github.repository == 'zheref/hatsu'`. **Copied to any
other repository that predicate is false on every event, so the job is skipped — green tick, no job,
no signal, forever.** It looks installed and does nothing, and there is no error to read. That is the
worst failure mode available, and it is why the slug is **substituted at adoption** rather than
copied.

**The gate predicate keeps its shape.** It is still the two-limb same-repository test — this
repository **and** a head that is not a fork — and the fork limb is what keeps a
`pull_request_target` credential away from code the pull request controls. Substituting the slug does
not weaken it: a wrong slug fails **closed** (the job is skipped).

**What turns that closed failure into a visible one is the diagnosis.** Every later run re-reads the
rendered predicate and reports a slug that is not this repository's as `drift`, naming the
consequence and not merely the mismatch. **A repository that was renamed or transferred is caught by
a diagnosis instead of by a signal that quietly stopped arriving** — which nobody notices, because
nothing goes red.

**Three further drifts are checked on the live YAML, never on the comments** (the template carries a
provenance banner that quotes the defect it prevents, including the literal slug):

- a `runs-on` that no longer matches what this repository derives (§ 5b);
- a **dropped `--gates`** — nen falls back to `<cwd>/nen/gates.json`, and the cwd in that job is the
  **PR head checkout**, so losing the flag hands the pull request the gate that judges it. It reads
  as a harmless simplification and is not one;
- any surviving `@@TOKEN@@`, which means the file was copied rather than rendered;
- a **trigger set that is not exactly the admitted two** — § 5c; it matters in both directions,
  because an extra one may be an event no workflow can even register with.
- a consumer workflow that assumes Hatsu's Ruby policy guard exists, or assumes the consumer
  contract has a `dependency.pinned_ref`. The rendered product workflow treats the guard as
  optional and uses Hatsu's trusted, pinned Nen ref when the consumer declares no dependency pin.
  A process repository still requires its own guard and pin.

### 5c · The two admitted triggers — required, and the set is closed

**Maintainer's ruling, 2026-09-19, as corrected the same day.** The rendered workflow declares
**two** events, and Tenkai reports a set that is not exactly those two as `drift` **in both
directions**.

| Event | Types | The conjunct it exists for |
|---|---|---|
| `pull_request_target` | `opened, synchronize, reopened, review_requested, review_request_removed` | the head moving, **and** `CON-32(b)` in its own right — `nen pr ready` distinguishes a round *in flight* from one that is *owed*, so adding or removing a reviewer changes the answer. **No `edited`**: the verdict never reads the body or the title |
| `pull_request_review` | `submitted, edited, dismissed` | `CON-32(b)` / `CON-16` — a reviewer round landing, changing or being dismissed |

**A missing trigger is a bug, not a simplification.** With `pull_request_target` alone the verdict is
computed at **push time — while the checks are still pending — and is never recomputed.** The
`ready` transition, which is exactly the moment worth publishing, would essentially never be
published and the check would read not-ready almost always. **A consumer provisioned with the
single-trigger form inherits precisely that**, which is why the engine treats an absent trigger as
drift and names the consequence rather than the absence.

**`pull_request_review_thread` was admitted briefly and REMOVED, and the correction is worth stating
plainly because this skill shipped the error.** It exists as a **webhook** event but is **not a
supported Actions trigger**, so **a workflow naming it cannot register at all** — GitHub's event
reference lists `pull_request_review` and `pull_request_review_comment` and not that one. An earlier
version of `scripts/tenkai_adopt.sh` *required* it, which meant `apply` would have reported a correct
workflow as drift and then rendered one that does not run: **the adoption tool actively breaking the
repository it was adopting.** It is now refused as firmly as any other non-admitted event, with a
fixture whose whole job is to stop it being re-adopted.

**The set is CLOSED, and widening it is a ruling rather than a template variation.**
`scripts/workflow_runner_policy_check.rb`'s `ALLOWED_TRIGGERS` holds it in one place. Both admitted
events carry `github.event.pull_request`, which is *why* these two: one job condition and one
`github.event.pull_request.number` work unchanged across them under a **single** byte-compared
same-repository guard — so the guard stays one expression even though Tenkai parameterises its slug.
**`check_suite` is refused for a different reason**: its payload carries only
`check_suite.pull_requests[]`, so it would need a second and weaker guard, and it fires for forks. A
consumer that appears to need either is a **`G5` to escalate**, never a variation Tenkai renders.

> **`CON-32(d)` has NO trigger available at all, and that is a named limitation rather than an
> oversight.** Thread resolution has no supported Actions trigger, so a pull request whose last
> changing input is a thread being resolved keeps a stale verdict. **A check *completing* fires
> nothing either.** In the normal flow — push, then checks, then a reviewer round — the review event
> is the last input and re-evaluates once the checks are green, so the common path is covered. A pull
> request whose last changing input is a check re-run with no review after it stays stale until
> something else happens.

**The engine parses the `on:` block itself rather than matching a list of known event names.** An
earlier draft intersected the keys it found against a hand-kept allowlist, so an **unrecognised**
trigger was silently dropped instead of flagged — the one case worth refusing was the one case it
could not see. There is no list to fall out of date now.

### 5d · What a consumer does **not** inherit, said out loud

**Tenkai installs a privileged, credentialed `pull_request_target` job and installs no policy
guard.** `GuardRegistration` scoring a missing guard as *"no ordering constraint at all"* is true
about the **ordering** and says nothing about **enforcement**: the byte-compared same-repository
guard, the write-permission refusal and the trusted-data rules all live in
`scripts/workflow_runner_policy_check.rb`, which Tenkai does not install.

The rendered job checks for that file on its **trusted** checkout. A process repository fails
if it is absent; a consumer emits a notice and continues under the rendered job's own guards.
The Nen ref comes from the trusted contract when present, otherwise from the pinned Hatsu
source used to render the consumer workflow. Neither value comes from the pull request head.

Two things follow, and neither is left implicit:

- **§ 5's drift checks and the rendered job's own guards are the safety net** in a consumer with no guard of its own. That is why
  they assert the inherited hardening — the trusted checkout's ref, `persist-credentials` on **every**
  checkout step, no write scope beyond `checks`, no `${{ }}` inside a `run:` body, and `--gates`
  matched as a **whole argument** rather than a flag name.
- **Every other privileged workflow in the repository is named** — `pull_request_target`,
  `workflow_run`, `issue_comment`, `workflow_call` — as an **observation row that writes nothing**.
  Installing the guard into a consumer is a separate, maintainer-owned change; this item exists so
  the gap cannot be silent.

### 5a · The two-PR ordering — handled, never hit

**A new workflow cannot be registered and added in one pull request**, and that is structural.
[`#80`](https://github.com/zheref/hatsu/pull/80) documents the mechanism: the policy guard that
judges a pull request is the **trusted** copy from the base branch, run against the PR's tree, and
the PR's own copy never executes. So a PR that both registers a workflow in the guard's tables and
adds the workflow file is judged by a guard that cannot know it, and fails.

**Any consumer that adopts this guard inherits that ordering.** Tenkai does not edit an arbitrary
Ruby guard; it **detects which half has landed** and sequences the plan:

| Guard state | What Tenkai does |
|---|---|
| **no guard in the repository** | No ordering constraint. The workflow may land in one pull request |
| **guard present, does not name the workflow** | The registration is `routed` and the workflow is **`staged`** — **`apply` does not write it.** Writing it now would fail every required check for one cause |
| **guard present, names the workflow** | The workflow lands on the next `apply` |

**The routed action carries the one thing that looks like an oversight and is not:**
`PORTABLE_HOSTED_WORKFLOWS` must **not** name a file that does not exist yet, because that constant
doubles as the required-**presence** list — naming it early fails every pull request from the other
direction. The file is added to that list in the same commit as the file itself.

### 5b · Runner selection — derived per repository, never assumed

**Maintainer's ruling, 2026-09-19.** `scripts/tenkai_adopt.sh runner-policy` is the single encoding
and the skill restates no part of it beyond the table below. The preference for self-hosted runners
is right where hosted minutes are genuinely billed and the security calculus differs — a **private**
consumer repository with a runner **actually registered** — and wrong everywhere else:

| Visibility | Registered self-hosted | Derives | Because |
|---|---|---|---|
| public | any | `ubuntu-latest` | hosted **standard** runners are free and unlimited on public repositories, so there is no bill to avoid; and GitHub advises against self-hosted runners there, because a fork PR can execute code on them |
| private | **0** | `ubuntu-latest` | a preference would queue the job against a runner that never appears. **A check that never completes is strictly worse than a bill that is currently zero** — and if it is ever made required, it blocks every merge, permanently |
| private | ≥1 | `self-hosted` | minutes are genuinely billed, and the fork-exposure argument does not apply |
| **unreadable** | — | `ubuntu-latest` | **the derivation never guesses toward a runner that might not exist** |

**Every derivation names a fallback, and the fallback is never absent.** A job can never hang on a
runner that is not there.

> **Measured on `zheref/hatsu` itself**: `visibility=public`, `actions/runners` → `total_count: 0`.
> Both limbs derive hosted, so **this ruling changes nothing here today** — it is for the private
> consumers where the preference was always right.

---

## 6. The `commit-msg` hook is **nen's**, and Tenkai routes it

Every Hatsu skill that commits gates the message on `nen commit format --repo .`'s exit code. A
commit typed by hand, made from an IDE, or written by a session that never named a phase passes
through none of them — which is a real gap, and **it is already assigned.**
[`docs/ROSTER.md`](../../../docs/ROSTER.md) § 2 names layer (b) of the three-layer attribution
enforcement as *"a target repository's `commit-msg` hook, **generated by `nen scaffold init`** from
`allowedAttributionTrailers`"*, and `nen scaffold init` installs exactly that, at exactly that path,
from exactly that policy file.

**So this item is diagnosed here and repaired by nen**, like every other nen-owned item:

```bash
nen scaffold init --repo <path> --agent-trailer Hatsu-Agent
```

**An earlier revision of this skill rendered a Hatsu-authored hook instead, and it was wrong twice
over.** It claimed a mechanism this repository's own canon had already assigned — while the skill's
central rule is *never write a nen-owned file; route it* — and the two writers **collided
destructively in both orderings**, measured on fixtures:

| Order | What happened |
|---|---|
| Tenkai first | `nen scaffold init` — **the very command Tenkai routes the five declarations to** — refuses: *"a different commit-msg hook already exists … refusing to overwrite it"* |
| nen first | Tenkai reported nen's generated hook as foreign drift and advised **deleting** it, so the item could never reach `satisfied` and `apply` could never exit `0` |

**Removing the template removed three defects with it**, rather than patching them: a write that
escaped `--repo` through the git common dir, a followed symlink that created an arbitrary executable,
and `core.hooksPath` being ignored so the hook was reported *"installed and current"* in a directory
git would never read. **Detection still honours `core.hooksPath`**, because asserting presence in the
wrong directory is the same silent-skip failure in a smaller costume.

> **Whether a verb-delegating hook should ever supersede nen's data-baked one is a `G4` question**,
> and it is the maintainer's. It is not a template this skill ships on its own authority.

## 6a. The repository's ROLE, and the release row that depends on it

**Maintainer's ruling, 2026-09-19.** A repository whose **product is the process** must declare a
**real `release` row**, not a seat.

**The role is derived, never asked and never invented.** The 2026-09-18 ruling already splits
repositories by role rather than by file kind, and [`nen/repos.json`](../../../nen/repos.json)
already records that split in machine-readable form:

| Where the registry names it | Role | What Tenkai asserts |
|---|---|---|
| `maintained_tools` | **process / system** | a real `release` row is owed, and a publisher must exist |
| `consumers` | **product** | inspect every declared lane command, including each lane's `release`; route seats and missing iteration checks without choosing a destination or publisher |
| **neither** | unknown | **`blocked`** — *"Tenkai does not classify a repository for itself"* |

**Reading the registry rather than parsing canon prose is the whole point.** The canon list lives in
[`docs/ROSTER.md`](../../../docs/ROSTER.md) as a ruling in the maintainer's own words; a script that
scraped it would be counting canon in prose, which is the thing § 2 exists to stop. The registry is
already the machine-readable form of the same fact, and it costs the preamble no third question.

**Why the row matters, and it is not bookkeeping.** `hatsu:mugetsu`'s entire job is to execute the
lane's declared `release` row at **`G3`**. A **seat** there tells nen there is nothing to run — so
mugetsu has nothing to execute, and publication happens **by hand, outside the machinery, or not at
all.** `zheref/hatsu` lived in exactly that state: its seat read *"nothing in this repository
publishes one"* while a GitHub Release was being published by hand at `v0.39.0`. **A declaration
that disagrees with the practice is a bug in the declaration**, and the seat is now retired.

**Two halves, and the ownership line runs between them:**

- **`scripts/release-publish.sh` is Hatsu's to render in a process repository**, from
  `templates/release-publish.sh` — the same engine Hatsu runs on itself. A product needs its own
  publisher for its chosen destination. **A publisher Tenkai did not render is never overwritten.**
- **The `release` row is nen's**, so Tenkai **routes** it and **offers** the exact row to paste,
  composed from **this repository's own default lane and declared stack** for a process repository.
  For a product, each lane's release seat is routed with destination, package identity, signing and
  publisher decisions named. A Store lane and a direct-download lane can carry separate G3 decisions;
  Tenkai does not merge them into one command or invent an executable. Once the owner has
  chosen the behaviour, the agent can update this consumer's declaration under § 6c;
  `tenkai_adopt.sh` itself never writes it.

**What the publisher is kind-aware about, and what it refuses to guess.** Notes and title come from
the repository's own `CHANGELOG.md`, which every declared stack has; assets come **only** from
`--asset`, which the lane's own `archive` ([`hatsu:susanoo`](../susanoo/SKILL.md)) produces. So one
engine serves a `claude-code-plugin` — distributed by git ref, where **the tag *is* the
distribution** and there is no artifact — and a stack that does build one, without knowing either
stack's name. **It never invents an artifact and never guesses a build.**

> **`--tag` is optional, and that is what makes the row runnable at all.** `nen shu release` runs the
> declared argv with **no arguments of its own**, so a row whose script *required* a tag could never
> be executed by the verb that exists to execute it. Omitted, the tag is the newest `v*` by version
> sort, and every output names it `(DERIVED)` so nobody has to infer which tag was chosen.

**Every refusal fires before anything is sent**, because publication is not idempotent in any way a
caller can rely on — a release notifies watchers the moment it exists: an absent tag, a tag missing
from the **remote** (a release must not point at a ref nobody can fetch), a tag that **already has a
release** (*one go publishes one target once*), an `--asset` that does not exist, and a changelog
with no section for the tag.

**This row is what mugetsu RUNS. It is never permission to run it.** `G3` (`CON-6`) still holds the
go, per target, in the maintainer's own words.

## 6b. Product lane readiness — adoption is not a green build

For each lane declared in a product's `nen/contract.json`, Tenkai reports each declared verb as
`lane/<lane>/<verb>`. A real command is `satisfied`; an `unsupported` seat is `routed` with its own
reason quoted and its declaration path named. The iteration lane also gets a routed row for any verb
named by `nen/workflow.json → iteration.checks` but absent from the contract. Focused lanes owe only
the commands they declare. `release` is reported per product lane, so each destination stays visible
at its own gate. If no lane declares a release command or explicit seat, Tenkai routes the missing
row on the default lane without guessing a destination. An absent or malformed declaration is handled
by § 3's declaration item, never guessed past.

**Tenkai diagnoses and guides; it does not fabricate a command or run a release.** Product owners
choose what `lint`, coverage, archive, launch, deploy and release actually do. An intentional seat
remains visible as a limitation, rather than being called configured. A declared command is only
structurally satisfied: it has not been proven to run. After the owner sets a real row, Tenkai
re-runs diagnosis; `nen schema check` validates its syntax and the relevant `nen shu <verb>
--dry-run` and execution prove its behaviour.

## 6c. Guided readiness — complete the workflow joins

The engine reports `workflow/toolchain`, `workflow/test-selection/<verb>`,
`workflow/test-results`, `workflow/coverage`, and `workflow/evidence` where their conditions
apply. These are **cross-file joins**, not a stack command catalogue. A lane may have a valid
`ui-test` command while the workflow selects only `test`; a test may pass but produce no result
artifact for `nen shu test-report`; a coverage ladder may exist without a capture row. Each is a
routed gap until its declarations agree. The engine checks declared structure, not CI execution,
test quality, or whether the app launches. Keep those as separately named verification results.

Work the outstanding rows in dependency order, carrying prior owner answers forward:

0. **Policy inbox:** run `nen warmup --repo <path> --current <the installed Hatsu
   plugin's actual version>` and supply `--questions-from` when a question list exists.
   Relay `unpinned`, `stale`, and `NOT CHECKED` exactly as Nen reports them; the engine's
   parseable `nen/repos.json` row does not certify a pin. Set a consumer pin only to a
   released, resolvable Hatsu tag. An unpublished plugin version is a pending fan-out,
   not a ref to write into the consumer registry.
1. **Iteration:** inspect `nen/workflow.json`'s checks and selected suites, the product lanes,
   and — where the consumer carries `.claude/canon-values.yml` — `nen/workflow.json` →
   `iteration.canonMirror.command`, the argv the local verification gate runs to regenerate
   `.claude/rules/` on every commit that touches the bindings ([`WORKFLOW.md`](../../../docs/WORKFLOW.md)
   § *The local verification gate*, step 2; zheref/hatsu#111); a consumer with the bindings and no such
   key is a routed gap — *the key is absent* — never a weekly cron waited on; inspect
   `project.toolchain` and the actual CI workflow too. For every executable check, identify its exact
   `nen shu` route, host, result artifact, and whether CI runs it. A `lint` seat needs a real lint
   command or an owner-approved documented reason it cannot exist. A suite omitted from selection
   is a choice to ask, not a pass. Check `dev` and `run` against their declared launch semantics.
2. **Evidence:** match tests that produce reports to `test-report`, coverage capture to the
   workflow's coverage ladder, and rendered changes to `project.evidence` and snapshot tooling.
   Prove the command exists with `nen shu <verb> --dry-run`; on a setup run, execute a safe local
   check when the host supports it. In particular, an artifact path on a test row is only a
   structural join: run
   `nen shu test-report` after the test and check that Nen can parse its actual format and
   count. Mark an unsupported host or a missing runner as unread, with its remedy.
3. **Distribution:** keep each product destination separate. For every `archive`, `release` and
   `deploy` seat, record the intended format, channel, signing source, identity, and destination.
   Ask only for missing owner choices. External accounts, certificates and production targets are
   named prerequisites, never invented values. Stop before any upload or publication at G3.

Use the surface's native Crazy Slots picker for genuine choices, at most three related questions
per call. Offer a recommendation with the consequence of each option. The question is about the
workflow behaviour the maintainer wants, not a request to fill JSON. Do not re-ask a decision
already made in the session. An unanswered required choice remains `routed` with the precise
question, owner, and next safe step; continue independent rows.

**Who writes, on `apply` or an explicit setup request only:** `tenkai_adopt.sh apply` writes only
Hatsu-owned surfaces. Run `nen scaffold init`
for missing Nen scaffolded files, after its dry run. For an existing consumer declaration,
use a Nen edit verb if one exists; if no verb edits that field, Tenkai may author the consumer's
`nen/contract.json` or `nen/workflow.json` in this working branch once the owner has chosen the
behaviour. This is consumer setup at G2, never a new Nen operation. First read the declaration,
write only the selected fields, then run `nen schema check`, `nen stage triage`, the relevant
`nen shu <verb> --dry-run`, and local checks supported here. Report the exact seat for any check
that cannot run. Re-diagnose after every batch, preserve already satisfied rows, and finish with
an item-by-item status and the remaining owner questions. No phase here commits, pushes, opens a
PR, tags, uploads, or publishes.

## 7. Report — per item, and never a summary that hides a row

**Relay the engine's rows.** Every item, including the satisfied ones: *"what was already satisfied"*
is half of what [`#81`](https://github.com/zheref/hatsu/issues/81) asks for, and a report that printed
only the problems would leave a maintainer unable to tell a checked item from an unchecked one.

State, out loud, in this order:

1. the repository, the slug, and the derived runner **with its reason**;
2. every item, with its state and its detail;
3. for each outstanding item, the named action and its **owner**;
4. the outstanding count, and — where anything is `staged` — **the order the pull requests must land
   in**;
5. the policy inbox and execution verdict: whether `nen warmup` found unpinned or stale
   consumers and whether its handbook questions were checked; which declared build, lint,
   selected tests, result parser, coverage, launch and CI checks actually ran, and which
   were unread or blocked on this host;
6. the successor: **nothing**. Adoption is not a phase of the loop. A repository whose required
   checks Tenkai has proved is ready for [`hatsu:ren`](../ren/SKILL.md); otherwise name each
   outstanding prerequisite without calling the workflow ready.

**An outstanding count above zero is a finding, not a failure**, and it is stated as one.

---

## Residue

- **Registering a workflow in an arbitrary consumer's policy guard.** Tenkai detects the registration
  and routes it; it does not edit Ruby it did not ship. Generalising
  `scripts/workflow_runner_policy_check.rb`'s own frozen `HOSTED_RUNNER` mandate to consume
  `runner-policy`'s derivation is a **separate change to that file**, and it is named here rather
  than smuggled into an adoption run.
- **`nen pr ready --json`.** The rendered workflow still derives its check title by `head -1` and a
  prose-prefix strip. It works, and it parses human-readable text: the day nen rewords that line,
  every consumer's signal breaks silently. Filed against `zheref/nen`, not improvised here.
- **A consumer's initial `nen/contract.json` still comes from `nen scaffold init`**, which knows the
  stack and nothing of this process — correctly. Tenkai adds the process half, then guides
  subsequent consumer-specific lane choices under § 6c.

## Authority

- **Permitted:** read any checkout on this machine; render `templates/**` into a target repository;
  create and ignore `Reports/` and `.nen/`; route the `commit-msg` hook to Nen; derive and report the
  runner policy; guide and validate consumer configuration after an owner choice under § 6c;
  name the owner and the exact command for every routed item.
- **Not permitted:** push, commit, open a pull request, label, merge, deploy, tag; write any
  canon repository's `nen/*.json` during consumer adoption; run `nen scaffold init` on the
  maintainer's behalf without the § 1 confirmation;
  overwrite a hook it did not render; widen a colour taxonomy; edit a policy guard.
- **Carries no delegation**, and confers none. Being the first skill run in a repository lends it no
  authority over what runs next.

## Hard limits

- **Never writes before it diagnoses.** Every item detects first, on every run, including `apply`.
- **Never reports an item it did not actually check**, and never re-derives one by eye that the
  engine reports.
- **The engine never writes a `nen`-owned declaration.** The agent uses an available Nen verb
  or makes a scoped consumer configuration edit after the owner decision and § 6c validation.
- **Never invents a colour family**, and never compares a tuned `colors.yml` byte-for-byte against
  the seed.
- **Never writes a workflow into a repository whose guard has not registered it.** The ordering is
  handled as a sequenced plan; it is never hit and then explained.
- **Never encodes a runner preference that could queue on an absent runner.** Every derivation
  terminates on a runner that exists.
- **Never overwrites a hand-written hook**, and never treats a foreign hook as drift to be corrected.
- **Never claims a repository is current on the strength of a marker file.** There is none, and the
  reason is that a marker written three versions ago answers the wrong question confidently.
- **Never treats exit `1` as a crash**, and never reports an outstanding count as a pass.
