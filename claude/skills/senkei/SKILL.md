---
name: senkei
description: Inventory a consuming product repo's own backlog — open epics, live integration branches, and open PRs — classify each effort, and state a CON-32 readiness determination for every open PR. Use when the maintainer asks for the status of a product repo (any Hatsu consumer), wants its existing efforts driven forward, or invokes `hatsu:senkei <repo>`. Kurapika (Manipulator) opens with `hatsu:ten senkei`, enumerates the target's backlog, classifies each effort (delivering/building/stalled/queued/idle, plus state-machine-violation and undecidable) against the stage family the target declares, quotes `nen pr ready` for every open PR, hands a stuck one to `sharingan`, and reports through rikugan's `register`. Carries no CON-25 delegation and never merges — G2 stays the maintainer's.
---

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md`,
`docs/LAUNCH-MIGRATION.md`, `docs/STANDALONE-ENTRY.md`, `docs/PROCESS.md`, `docs/using/README.md` and `docs/using/mirrors.md` belong to the resolved **Hatsu plugin
root**, not the consuming repository. On an installed surface, use the absolute root printed by
`ten` to read those files (re-resolve through that skill if unavailable). Relative links
below identify source locations; a missing consumer `docs/` copy is not a missing policy and must not
trigger a duplicate filing. Never copy or invent a second policy in the target repository.



# Senkei — inventory a product repo's own backlog and state each PR's readiness

**Nature: Manipulator.** GitHub-side reading and reporting over **one consuming product repo's** own
backlog. Kurapika says so when he runs it.

This is the product-repo counterpart of [`backlog-loop`](../backlog-loop/SKILL.md), which drives Hatsu's
own backlog. `senkei` never touches Hatsu's backlog and never edits the target's product code. It
enumerates (§ 2), classifies (§ 3), states a `CON-32` determination for every open PR (§ 4) and reports
(§ 5). **It calls none of the five human-called phases** — `aka`, `mukai`, the merge, `kagutsuchi` and
`mugetsu` are the maintainer's ([`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 4) — and prompts for none: it
opens, pushes, merges, uploads and publishes nothing. It is reached only by its typed call; no composite
runs it and Illumi's loop does not (ROSTER OPEN-1). The evidence behind every mechanical claim below is
[`docs/ab/senkei.md`](../../../docs/ab/senkei.md) § *Re-run at nen 0.28 — 2026-11-03*.

## 1. Invocation

```
hatsu:senkei <repo>
```

**P1 — the run opens with `hatsu:ten senkei`, never skipped** ([`ten`](../ten/SKILL.md) § 6 catches up
the prerequisites under this run's name). **The phases this composite calls skip their own `## 0.`**
and inherit P1–P4 from this run ([`STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) § 4); each
says which composite is holding it.

`<repo>` is a product code, a short name or an `owner/repo`, taken from the invocation, **never
guessed**:

```bash
nen parse senkei --grammar "<repo>" --line "<the arguments after the skill's name>"
nen repo resolve <token> --repo <a checkout carrying the registry that records the target>
nen repo scenario --repo <that checkout> --target <owner/name>
```

`--line` takes the arguments only, not the skill's name. An empty slot (`nen parse` exit `2`) or an
unknown token (`nen repo resolve` exit `1`, whose refusal lists every code) is asked, quoting that list
(`missing-argument`, `missing-configuration`; WORKFLOW § 4 *Ask, set up, continue*). **The registry is
read in [`bankai-handbooks`](../bankai-handbooks/SKILL.md) § 1's order** — the canon registry, then the
product repo's own `nen/repos.json` where it records itself with a `scenario` — never the product repo's
checkout as a stand-in for a registry it does not carry. **An unregistered product repo is reported,
never written**: senkei names the missing `consumers` entry and the repository that owns the registry,
and stops that repo's run. Resolve once and carry the `owner/repo` slug forward.

**A product repo's own declarations are read, never written.** With its checkout in hand, report what
`nen shu detect --repo <checkout>` proposes and withholds and what `nen schema check --repo <checkout>`
reads; a missing `nen/contract.json`, `nen/labels.json` or `nen/gates.json` is a finding for **that
repo's maintainer**, landed as a PR at that repo's own gate, never a write this skill runs.

## 2. Enumerate — `nen repo inventory`

```bash
"$hatsu_root/scripts/gh_token_env.sh" nen repo inventory --target <owner/name> --epic-label <label> --integration-prefix <prefix> --trunk <branch.base>
```

Every open issue carrying `--epic-label` with its children, every branch under `--integration-prefix`
with its ahead/behind against `--trunk`, and every open PR. **Always fetched live**; never a cached list.

- **`--epic-label`** and **`--integration-prefix`** are the target's own conventions, read from its
  label declaration and branch names, never hard-coded or copied from another repository. A target that
  declares no epic label reads `epics: 0`, which is the label's absence, not an empty backlog: say so.
- **`--trunk`** is the target's `branch.base`, `main` where none is declared.

An integration branch alive with no open epic to own it is the `idle` shape (§ 3), reported for cleanup.

## 3. Classify — `nen effort classify`

| Class | Meaning |
| --- | --- |
| **delivering** | A delivery PR is open at **G2** — the final integration-to-trunk PR, or a child PR delivered alone. |
| **building** | A child released into building (a non-mode stage label); no PR yet, or a PR in review. |
| **stalled** | Released with no branch or PR ever opened, or a reviewer job that never posted its verdict. |
| **queued** | G1-approved (a mode label picked) but not yet released with a stage label. |
| **idle** | An integration branch still alive whose epic is closed: flag it for cleanup. |

**The verb prints seven values; two are answers *about* the taxonomy, not classes, and the report
handles both by name**: `state-machine-violation` (two stage labels on one object — flagged, never
resolved by guessing which is authoritative) and `undecidable` (nothing places the object anywhere —
reported as such, never folded into `queued`).

```bash
nen stage check --exclusive --target <owner/name> --issues <n,...> --repo <the target's checkout>
nen effort classify --input <absolute path.json> --repo <the target's checkout>
```

**The stage family is the target's own declaration**: every `<namespace>:stage/<leaf>` label its
`nen/labels.json` declares (`nen stage --help`). `stage check` exit `1` names every object carrying two
of them; exit `2` means the target declares no stage family — then the classes that rest on a stage
label are not claimed, every `stageLabels` is empty and `modeLabelPresent` false, and the report says the
repository declares no delivery stages ([`WORKFLOW.md`](../../../docs/WORKFLOW.md) § *A target
repository with no delivery-stage taxonomy*).

**Reshape the inventory before the classifier, or it misclassifies silently.** The input is one
`{kind, issueState, stageLabels[], modeLabelPresent, hasPr, prOpen, prIsDelivery,
integrationBranchAlive, reviewerVerdictMissing}` per effort. The verb reads only the label text it is
given:

- **The G1 mode labels** (the leaves the maintainer picks at G1, `CON-4`) become `modeLabelPresent:
  true` and are **never** passed in `stageLabels` — passed there, a G1-approved epic reads `building`
  instead of `queued`.
- **Pre-G1 leaves** (an idea, a triage or a research stage) are left out of the pass entirely and
  reported as "not yet G1-approved" — passed in, they read `stalled`.
- Which leaves are mode and which are pre-G1 is read from the target's declaration; where it does not
  say, ask once per run (`missing-configuration`), never infer from a name.
- **`reviewerVerdictMissing`** is caller-supplied: set it only on a dead reviewer job confirmed in § 4.

Pass an absolute `--input` and a deliberate `--repo`: a relative input resolves against `--repo`'s root,
never the calling directory.

## 4. State every open PR's readiness — `nen pr ready`

For each open PR, a **Ready / not-Ready** determination with its reason — never "checks are green".

```bash
"$hatsu_root/scripts/gh_token_env.sh" nen pr ready <N> --gh-repo <owner/name> --repo <the target's checkout> --explain
```

The verdict is quoted **verbatim**; it is never re-derived from the check rollup by eye, and the
adversarial confirmation pass may only veto a `ready`, never promote a `not-ready`
([`pr-state`](../pr-state/SKILL.md)).

**Reviewer identities are the target's own.** Its `nen/gates.json` needs no flag. Without one, `nen pr
ready` refuses at exit `2` and never guesses a reviewer set. Then pass `--reviewers` and `--approvers`
read from **that repo's own** review configuration, and say every time that a flat list cannot express a
conditional member, the `aiReviewers` reading or a kind-bot waiver, which only a `nen/gates.json`
models. **Never reuse Hatsu's `contracts/reference.gates.json` or another repository's identities.**
With neither, the identities are the maintainer's word (`missing-maintainer-choice`): ask, offer a
`nen/gates.json` as that repo's own declaration PR, and with no answer the refusal **is** the report.

Name these failure modes in the determination when they apply:

- **A reviewer job that died mid-run**, leaving a stale verdict on a required check:

  ```bash
  "$hatsu_root/scripts/gh_token_env.sh" nen run rerun-failed --target <owner/name> --run-id <n>
  ```

  It mutates GitHub with no dry run; only its refusal on a run with no failed job is on record. Run it
  only on a repository whose consequences you control. **Never re-label to force a re-vote.**
- **An author that stopped mid-run** and pushed nothing: `stalled` in § 3, not `building`.
- **Two stage labels on one child**: `state-machine-violation` (§ 3).

**A PR stuck for any other reason goes to [`hatsu:sharingan`](../sharingan/SKILL.md)**, once per stuck PR.
Senkei fires no label and no wake. Hatsu holds no CI plane ([`WORKFLOW.md`](../../../docs/WORKFLOW.md)
§ *Building an issue with no CI plane*). **Reviewer rounds are sharingan § 6's, stated there once**: an owed round
within both bounds is requested without asking (row `cap-reached`), and senkei restates none of the
bounds.

## 5. Report — rikugan's `register`

Hand the scope to [`hatsu:rikugan`](../rikugan/SKILL.md) as `register` (its § 2 row 1, `from: senkei`):
every epic, child, integration branch and PR § 2 listed. The desk carries § 3's class for each object,
the objects § 3 left out as not yet G1-approved, and § 4's verdict quoted for each PR. Cite objects in
the target's own notation (`nen ref format --code <CODE> --kind <IS|PR> --number <N>`).

**The bell is [`jutaisho`](../jutaisho/SKILL.md)'s**: a gate stop in its § 4 shape only when a row needs
the maintainer — an identity set to give, a declaration PR to land, a merge at G2. A status-only pass
rings rung 1 only, and a pass that changed nothing rings nothing.

## Explicitly out of scope

- **No new authority.** The run-scoped label delegation belongs to
  [`backlog-loop`](../backlog-loop/SKILL.md) by name; senkei applies no stage label without the
  maintainer's per-action confirmation, and no routing label at all.
- **No merging, anywhere.** G2 is the target repo's maintainer's.
- **No writes to product code.** It inventories and reports; it never edits the target's source.

## Hard limits

- Never merge, on any repository, for any reason.
- Never apply a label without the maintainer's per-action confirmation.
- Never cast a `request_changes` review or fire a label to move a stuck PR — hand it to `sharingan` (§ 4).
- Never guess the target repository (§ 1) or a reviewer set (§ 4).
- Never feed a mode or pre-G1 label into `stageLabels` (§ 3).
- Never restate the reviewer-round bounds; `sharingan` § 6 holds them. `nen/workflow.json` →
  `monitor.maxCycles` is en's acting-cycle cap, a different number.
- Never run `nen run rerun-failed` against a repository whose consequences you do not control (§ 4).
