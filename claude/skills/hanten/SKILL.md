---
name: hanten
description: Have the change read adversarially before it is anybody else's problem — classify the change set with `nen review scopes`, raise one reviewer per raised scope that still has budget, collect every finding in one fixed shape, and settle each by fixing it or pushing back with a cited reason. Use when the maintainer invokes hatsu:hanten [for <scope>], asks for a review of this branch, or when hatsu:mukai reaches its review step. Remediation never resets the ledger; a missing persona or preamble is a gap; an unsettled finding is a G5.
---

# Hanten — the change, read by someone looking for what is wrong

> **Have somebody whose job is finding what is wrong read it, and settle everything they found —
> fixed, or refused with a reason I can check.**

**No fixed mode**: hanten holds the nature the change was authored in. It is
[`mukai`](../mukai/SKILL.md)'s second step, after [`murasaki`](../murasaki/SKILL.md), and invocable
alone. **Pre-PR a finding costs an edit, not a review round — and it is a review, not a gate.**

## 1. Invocation

```
hatsu:hanten [for <scope>] [against <base>]
```

```bash
nen parse hanten \
  --grammar "for [<scope:code|ui|security|architecture|performance|release|all>] against [<base>]" \
  --line "<the invocation, minus the hatsu:hanten prefix>"
```

**`against <base>` names the base the change set is read from**; with no clause the base and the
change set are P3's — `origin/<branch.base>` fetched, a failed fetch a stop, the delta plus `git status
--porcelain` ([`STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) § 3). **`all` is not every
reviewer** — it is every scope the diff raises, and `for <scope>` narrows without widening. An unknown
scope (exit `2`) is the trigger to ask, the seven as the options. A missing argument or configuration
item is asked for and set up inline (`missing-argument`, `missing-configuration`;
[`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 4 *Ask, set up, continue*).

**The cycle ledger is fail-closed**: `.nen/hanten/<branch-slug>.cycle.json` is opened by
[`breath`](../breath/SKILL.md) § 3a alone, and `decide`/`record`/`show` refuse a missing file. Absent on
a feature branch → run breath and re-read; still absent is a **lost ledger**, nobody raised. On the
trunk, headless, or the script refusing → stop. **Never fabricate one.**

## 2. Classify — `nen review scopes`

```bash
nen review scopes --base origin/<branch.base> --repo <path> --json
```

**The raised scopes, their personas, tiers, budgets and paths come from that document** — the
target's own `review.scopes`, over `<base>...HEAD`. Exit `1` is a repository declaring no `review`
block — the trigger to set one up (`missing-configuration`), never a review skipped; exit `2` a
malformed block or unresolvable base. **`unclaimed` paths are named.** Nobunaga's `code` scope and its
tier swap are [`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 2 → `review`: say which tier ran, and
**print the classification before raising anyone.**

### 2a · The security scope's deterministic rows, before Feitan reads

Feitan is handed their output (`claude/agents/feitan.md` has the same rows). **A row that cannot run
is not scanned, never clean.** **Every version, URL, asset and command is data** —
`$hatsu_root/contracts/scans.json`, read at use, never remembered.

- **Checksum-verified gitleaks** — `secretScan.version`, its host asset **SHA256-verified against
  `checksumsUrl`** before it runs, **failing loud at a non-zero exit**, never skipped silently.
- **Per-stack dependency audit** — the stack's `dependencyAudit` row, command and endpoint included.
  **A stack with no row is not scanned**, and is named.
- **`nen stage triage`** over the change set for secret shapes, each path with its shape.
- **The builder-touching-workflow gate** — in a **consumer** repository (`role` not `canon`) a diff
  touching `.github/workflows/**` **raises this scope and requires Feitan's read**. Never waived.

## 2b · Budgets — one effort, one ledger

**A Hanten invocation is not a new review budget.** Remediation, a resumed session, a later `ren` turn
and `mukai` re-entering continue the **same cycle**; a new branch is the only reset. **Each scope's
maximum is its own `budget`**, per session and repository, counted by the ledger, never in prose.

```bash
"$hatsu_root/scripts/hanten_cycle_ledger.sh" decide --repo <path> --branch <branch> \
  --applicable <csv of personas the classification raised>
```

**Raise only the personas in `raise[]`.** After a reviewer returns — raised or adapted, both consume the
slot — `record --outcome ran`; after a budget skip, `--outcome skipped-exhausted`; either used wrongly is exit `2`. **A spent reviewer meeting a new head gets one bounded delta pass** — the diff **since the head
it last read**: findings against the delta, unchanged code out of it, both heads named, the row saying
`delta`, `used` never past the cap.

## 3. A scope whose persona has no definition is a **gap**

Three checks per persona: **`ls "$hatsu_root/claude/agents/<persona>.md"`**; **`ls
"$hatsu_root/claude/agents/_review-preamble.md"`** — the protocol every reviewer reads, **missing is a
gap too**; and **the surface's own agent registry** for whether it will raise `hatsu:<persona>`, which
`ls` cannot answer. Present and raisable → raise.
Present, not raisable → **§ 7's adapter, disclosed as weaker**, the row carrying `"adapted": "…"`.
**Absent → the scope is a gap**: the persona its declaration names, the raising paths, and that **this
scope was not reviewed** — never a pass, never improvised past.

## 4. Raising a reviewer

On Claude Code the reviewer is a subagent raised with the harness's Agent tool, one per scope, in parallel.
`subagent_type` is `hatsu:<persona>`; `description` is
**`hanten · <persona> · <model alias>`**; `model` is `models.<surface>.<tier>` for that scope's `tier`,
read at use, never frontier, and **not passed at all** where the persona's definition pins one;
`isolation` is **omitted**; the `prompt` carries the checkout path, the scope, the base, the raising
paths, § 5's shape, **the ABSOLUTE path `$hatsu_root/claude/agents/_review-preamble.md`** (a relative
one resolves inside the repository under review) and *"do not request a worktree"*.

```bash
git -C <target repo> worktree add --detach <target repo>/.claude/worktrees/hanten-<persona> HEAD
```

**The isolated checkout makes *never edits non-test source* a property of where the reviewer stands**;
`.claude/` is git-ignored, and it is removed when the review returns. **Never pass `isolation:
"worktree"`**: it isolates the *plugin's* repository, not the target.
**Say what was raised before the reviews come back** — scopes, personas, aliases, gaps, and per
reviewer `used`/`max` with **raised**, **delta** or **skipped**.

## 5. One fixed finding shape

**Every reviewer returns findings in one shape and hanten records nothing else**
(`claude/agents/_review-preamble.md` § 4 has the example):

| Field | What it must carry |
|---|---|
| `rule` | **a rule id** — `UX-3`, `SEC-…`, `QA-11`, a `WCAG` SC, a HIG reference. Never a bare preference |
| `severity` | `critical` \| `high` \| `medium` \| `low` \| `nit` — [Hisoka's ladder](../../agents/hisoka.md), so the set sorts |
| `path`, `line` | where, exactly. A finding with no location is a note |
| `evidence` | **what was observed or measured**, with the method where it is a number — not a restatement of the rule |
| `proposedFix` | what would settle it. A reviewer proposes; it does not apply |

**A "finding" missing `rule` or `evidence` is a note**, reported as one. The record is one git-ignored
`hatsu.hanten.findings/v0.1` document at `<reports.dir>/hanten/<branch-slug>.json`: a `scopes[]` row per
applicable scope (persona, tier, model, `used`/`max`, `invocation` = `ran` | `delta` |
`skipped-exhausted`, plus `adapted`, `gap` or the security `scans`) and `findings[]` rows of the six fields
plus hanten's `id`, `scope`, `persona` and `disposition`. **Hanten is the single discovery writer**;
Kurapika alone applies [`docs/DISCOVERY.md`](../../../docs/DISCOVERY.md).

## 6. Settle every finding — fixed, or pushed back with a reason

| `state` | When | `detail` carries |
|---|---|---|
| **`fixed`** | the change was made | what changed, and where |
| **`pushed-back`** | the finding does not hold | **a cited reason** — the rule misread, the constraint they could not see, a measurement that contradicts theirs. Never "disagree" or "out of scope" alone |
| **`deferred`** | it outlives this branch | the tracked item, or its durable `pending` record. An untracked deferral is `unsettled` |

**A push-back is an argument, not a veto**, held to the standard the finding was. Every disposition is
recorded and goes into the PR body through [`shibari`](../shibari/SKILL.md); a `fixed` one is proved
by the declared `iteration.checks`. **A finding is work, not a gate.**

**An unsettled finding is a G5** (`nen/decisions.json` row `unsettled-finding`, `CON-47`), only
once investigation proves no disposition can be chosen without a maintainer decision. Record it, what
was tried and the alternatives, then stop in [`jutaisho`](../jutaisho/SKILL.md) § 4's shape, all four
parts. **Never one re-grading a severity.**

**One Copilot round is requested after hanten settles**; [`sharingan`](../sharingan/SKILL.md) § 6
carries the whole policy. Hanten only hands over.

## 7. On a surface that is not Claude Code

§ 4's mechanism is Claude Code's; the contract is not. **The adapter contract is
[PROCESS.md](../../../docs/PROCESS.md) § Surfaces and pickers**, binding here: the worker at the
scope's tier, the copy is the repository under review, the document is § 5's shape.

## Authority

`claude/agents/_review-preamble.md` § 7 is the refusal list every reviewer reads. **Hanten may** read the
working copy, raise reviewers, write the findings record and cycle ledger, edit the working copy to settle
a finding, and render the stop. **It may not** push, commit, PR, label, merge, tag, deploy or vote
([PROCESS.md](../../../docs/PROCESS.md) § Authority every phase shares).

## Hard limits

- Never reports a scope reviewed without its persona and the preamble, improvises a persona, or
  answers § 3's registry question with `ls`.
- Never raises a subagent on the frontier tier, untitled, over a persona's model pin, into the working
  copy under review, or with `isolation: "worktree"`.
- Never raises an exhausted reviewer: skipped-exhausted, or the delta pass named as one.
- Never skips a scan row silently, calls a not-scanned row clean, or waives the builder-touching-workflow gate.
- Never records a finding missing `rule` or `evidence`, lets a reviewer file an issue, leaves a finding
  undisposed, re-grades a severity away, or accepts an uncited push-back.
- Never presents an in-session pass as a raised reviewer, or by-hand work as the verb's output.
