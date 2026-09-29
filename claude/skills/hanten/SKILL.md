---
name: hanten
description: Have the change read adversarially before it is anybody else's problem — classify with `nen review scopes`, raise one reviewer per raised scope with budget left, collect findings in one shape, settle each by fixing or pushing back with a cited reason. Use when the maintainer invokes hatsu:hanten [for <scope>], asks for a review of this branch, or at hatsu:mukai's review step.
---

# Hanten — the change, read by someone looking for what is wrong

> **Have somebody whose job is finding what is wrong read it, and settle everything they found —
> fixed, or refused with a reason I can check.**

**No fixed mode**: hanten holds the nature the change was authored in;
[`mukai`](../mukai/SKILL.md)'s second step, after [`murasaki`](../murasaki/SKILL.md), and invocable
alone. **Pre-PR a finding costs an edit, not a review round — and it is a review, not a gate.**

## 1. Invocation

```
hatsu:hanten [for <scope>] [against <base>]
```

```bash
nen parse hanten \
  --grammar "for [<scope:code|ui|security|architecture|performance|release|surfaces|all>] against [<base>]" \
  --line "<the invocation, minus the hatsu:hanten prefix>"
```

**`against <base>` names the base**; with none, base and change set are P3's (`origin/<branch.base>`
fetched, the delta plus `git status --porcelain`; [`STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md)
§ 3). **`all` is every scope the diff raises**, `for <scope>` narrows, never widens; an unknown scope
(exit `2`) asks with the eight as options; a missing argument or configuration item is set up inline
(`missing-argument`, `missing-configuration`; [`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 4).

**The cycle ledger is fail-closed**: `.nen/hanten/<branch-slug>.cycle.json` is
[`breath`](../breath/SKILL.md) § 3b's to open, and `decide`/`record`/`show` refuse a missing file —
absent on a feature branch → breath, re-read; still absent is a **lost ledger**, nobody raised; the
trunk, headless, or the script refusing → stop; **never fabricate one**. **Once a PR exists** the ledger
is `<branch-slug>-pr<N>.cycle.json`, opened by hanten once (`… init --repo <path> --branch <branch>
--pr <N>` before the first `decide`; present → never re-`init`); the branch-only one is not read again.

## 2. Classify — by path, then by content

```bash
nen review scopes --base origin/<branch.base> --repo <path> --json
```

**The raised scopes, personas, tiers, budgets and paths are that document's** — the target's
`review.scopes`, over `<base>...HEAD`. Exit `1` is no `review` block — set one up
(`missing-configuration`), never a review skipped; exit `2` a malformed block or unresolvable base.
**`unclaimed` paths are named.** Nobunaga's tier swap is [`WORKFLOW.md`](../../../docs/WORKFLOW.md)
§ 2 → `review`: say which ran.

**Two scopes the paths cannot raise, hanten raises by content** (#73): a diff adding, editing or
removing a `## 0.` section, **any table that routes control flow**, or the fall-through statement
beneath one, raises a **totality pass** on `architecture` — every reachable input state matches
exactly one row, the fall-through named — **Chrollo's**; absent or unraisable, a § 3 gap; spent,
§ 2b's `skipped-exhausted`. The `surfaces` scope (`surfaces/**`, Phinks) runs its two deterministic
rows first, handed to him as § 2a's are: `"$hatsu_root/scripts/surface_link_check.sh" <path>` and
`"$hatsu_root/scripts/surface_mirror_check.sh" <path>`, `<path>` the checkout under review. **A
content-raised persona joins § 2b's `--applicable`; print the classification, content rows included,
before raising anyone.**

### 2a · The security scope's deterministic rows, before Feitan reads

Feitan is handed their output (his file has the same rows); **a row that cannot run is not scanned,
never clean**; every version, URL, asset and command is `$hatsu_root/contracts/scans.json`'s, read at use.

- **Checksum-verified gitleaks** — `secretScan.version`, its asset **SHA256-verified against
  `checksumsUrl`** first, **failing loud on a non-zero exit**, never skipped silently.
- **The stack's `dependencyAudit` row**, command and endpoint; **a stack with no row is not scanned**, and named.
- **`nen stage triage`** over the change set, each secret shape with its path.
- **The builder-touching-workflow gate** — a **consumer** (`role` not `canon`) diff touching
  `.github/workflows/**` **raises this scope and requires Feitan's read**. Never waived.

## 2b · Budgets — one effort, one ledger

**A Hanten invocation is not a new review budget**: remediation, a resumed session, a later `ren` turn
and `mukai` re-entering continue the **same cycle**. **An effort is a branch PLUS its pull request**
(ROSTER ruling 9 R2) — keyed `<branch-slug>`, then `<branch-slug>-pr<N>`, so a new PR number is a new
ledger with every scope's full budget. **Each scope's maximum is its own `budget`, per effort, never per session or repository** (ruling
2026-09-28), the ledger's count, never prose's; **one persona, one budget** (the smallest declared): two
scopes he owns raised together are one raise carrying both.

```bash
"$hatsu_root/scripts/hanten_cycle_ledger.sh" decide --repo <path> --branch <branch> [--pr <N>] \
  --applicable <csv of personas the classification raised>
```

**Raise only `raise[]`'s personas.** A returned reviewer — raised or adapted — is `record --outcome
ran`; a budget skip `--outcome skipped-exhausted`; either misused is exit `2`. **A spent reviewer meeting a new head gets one bounded delta pass**: the diff since the head it last
read, both heads named, the row saying `delta`, `used` never past the cap.

## 3. A scope whose persona has no definition is a **gap**

Three checks per persona: `ls "$hatsu_root/claude/agents/<persona>.md"`; `ls
"$hatsu_root/claude/agents/_review-preamble.md"` (**missing is a gap too**); and **the surface's own
agent registry** for whether it raises `hatsu:<persona>` — `ls` cannot answer that. Raisable → raise;
present, not raisable → **§ 7's adapter, disclosed as weaker** (`"adapted": "…"`); **absent → a gap**:
the persona named, the raising paths, and that **this scope was not reviewed** — never a pass, never
improvised past.

## 4. Raising a reviewer, and its cost

On Claude Code the reviewer is a subagent (the harness's Agent tool), one per scope, in parallel:
`subagent_type` `hatsu:<persona>`, `description` **`hanten · <persona> · <model alias>`**, `model`
`models.<surface>.<tier>` for the scope's `tier` (never frontier, **not passed** where the persona pins
one), `isolation` **omitted**, the `prompt` carrying the checkout path, scope, base, raising paths, § 5's
shape, the **absolute** paths of `$hatsu_root/claude/agents/_review-preamble.md` and of the pinned
`nen`, and *"do not request a worktree"*. **A subagent inherits no `PATH`** (#107): pass the `nen`
[`ten`](../ten/SKILL.md) § 2 bound as `nen: <path>` with its pin (never a bare `command -v nen`); it
prefixes every block (preamble § 2); unresolvable, the prompt names every Nen-owned check **unread**
once, and one failing at the reviewer's end is the reviewer's to declare.

```bash
git -C <target repo> worktree add --detach <target repo>/.claude/worktrees/hanten-<persona> HEAD
```

**The isolated checkout makes *never edits non-test source* a property of where the reviewer stands**,
removed when the review returns; **never `isolation: "worktree"`** — that isolates the *plugin's*
repository, not the target.
**Say what was raised before the reviews return**: scopes, personas, aliases, gaps, each `used`/`max`. **As each returns, one entry — never a transcription after the round** (#100): `nen usage record
--effort <branch> --surface <s> --model <alias> --input/--output <n> --source "hanten § 4: <persona>,
<readout>"` — `--effort` the branch (only the cycle ledger is PR-keyed), `<readout>` the surface's own
figure for that reviewer at its return (on Claude Code the Agent tool's completion totals),
`--not-reported` where the surface gives none; the mechanism is
[`WORKFLOW.md`](../../../docs/WORKFLOW.md) § *The effort's ledgers*.

## 5. One fixed finding shape

**Every reviewer returns findings in one shape and hanten records nothing else**
(`claude/agents/_review-preamble.md` § 4 has the example):

| Field | What it must carry |
|---|---|
| `rule` | **a rule id** (`UX-3`, `SEC-…`, `QA-11`, a WCAG SC, a HIG reference), never a bare preference |
| `severity` | `critical` \| `high` \| `medium` \| `low` \| `nit` ([Hisoka's ladder](../../agents/hisoka.md)) |
| `path`, `line` | where, exactly; no location is a note |
| `evidence` | **what was observed or measured**, method included for a number; never a restatement of the rule |
| `proposedFix` | what would settle it; a reviewer proposes, never applies |

**A "finding" missing `rule` or `evidence` is a note**, reported as one. The record is one ignored
`hatsu.hanten.findings/v0.1` document at `<reports.dir>/hanten/<branch-slug>.json`: `scopes[]` (persona,
tier, model, `used`/`max`, `invocation` = `ran` | `delta` | `skipped-exhausted`, plus `adapted`, `gap` or
the security `scans`) and `findings[]` (the six fields plus hanten's `id`, `scope`, `persona`,
`disposition`). **Hanten is the single discovery writer**; Kurapika alone applies
[`docs/DISCOVERY.md`](../../../docs/DISCOVERY.md).

## 6. Settle every finding — fixed, or pushed back with a reason

| `state` | When | `detail` carries |
|---|---|---|
| **`fixed`** | the change was made | what changed, and where |
| **`pushed-back`** | the finding does not hold | **a cited reason** — the rule misread, a constraint they could not see, a contradicting measurement; never "disagree" or "out of scope" alone |
| **`deferred`** | it outlives this branch | the tracked item, or its durable `pending` record. An untracked deferral is `unsettled` |

**A push-back is an argument, not a veto**. Every disposition is
recorded and reaches the PR body through [`shibari`](../shibari/SKILL.md); a `fixed` one is proved
by the declared `iteration.checks`, and one editing a dieted file quotes that file's
`"$hatsu_root/scripts/prose_size_check.sh" --headroom <path>` line (#119). **A finding is work, not a gate.**

**An unsettled finding is a G5** (`nen/decisions.json` row `unsettled-finding`, `CON-47`), only once
investigation proves no disposition can be chosen without a maintainer decision: record it, what was
tried and the alternatives, then stop in [`jutaisho`](../jutaisho/SKILL.md) § 4's shape, all four
parts. **Never one re-grading a severity.**

**One Copilot round is requested after hanten settles**; [`sharingan`](../sharingan/SKILL.md) § 6
carries the policy. Hanten hands over.

## 7. On a surface that is not Claude Code

§ 4's mechanism is Claude Code's; the contract is not: **[PROCESS.md](../../../docs/PROCESS.md)
§ Surfaces and pickers** binds — the worker at the scope's tier, the copy the repository under review,
the document § 5's shape, the pinned `nen` by absolute path (§ 4) or none where the worker carries it
(preamble § 2).

## Authority

`claude/agents/_review-preamble.md` § 7 is every reviewer's refusal list. **Hanten may** read the working
copy, raise reviewers, write the findings record, the cycle and usage ledgers, edit the working copy to
settle a finding, and render the stop. **It may not** push, commit, PR, label, merge, tag, deploy or
vote ([PROCESS.md](../../../docs/PROCESS.md) § Authority every phase shares).

## Hard limits

- Never reports a scope reviewed without its persona and the preamble, improvises a persona, or
  answers § 3's registry question with `ls`.
- Never raises a subagent on the frontier tier, untitled, over a persona's model pin, into the working
  copy under review, or with `isolation: "worktree"`; never an exhausted reviewer.
- Never skips a scan or guard row silently, calls a not-run row clean, or waives the workflow gate.
- Never records a finding missing `rule` or `evidence`, lets a reviewer file an issue, leaves one
  undisposed, re-grades a severity away, or accepts an uncited push-back.
- Never presents an in-session pass as a raised reviewer, by-hand work as a verb's output, or a spend
  as recorded when no `nen usage record` wrote it.
