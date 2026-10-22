---
name: kazaana
description: Draw a repository's whole surface-matched backlog in and deliver it — hatsu:futon <repo>@model/<this surface's line> then getsuga, under the hood. Use when the maintainer invokes hatsu:kazaana <repo> [on <line>], or asks to work everything this surface's model can build. Unlabelled issues are directed first and refetched; each issue is authored and published by a delegate in its own worktree on direct's primary pick, up to 7 at once, stacked only on overlap, while this session runs mukai and en per effort to its merge prompt; the final register carries the merge order. Once every PR is merged or closed, getsuga cuts the tag with its proposal merged autonomously (never the maintainer's to merge), then one unstarred picker asks whether mugetsu should publish it. Never merges a delivery PR, never a frontier-tier delegate.
---

**Shared policy:** [`PROCESS.md`](../../../docs/PROCESS.md) § *Standalone entry*.

# Kazaana — the wind tunnel: one surface's whole backlog, drawn in and delivered

**Nature: Manipulator** while the queue, the delegates and the PRs are driven; the mode
[`build`](../build/SKILL.md) § 2 confirms per issue inside each delegate; **Emitter** at the cut.

> **Name a repository; I give it back with every issue this surface's model can build merged or
> standing at your merge prompt, a merge plan, then the tag — and one question about publishing.**

Kazaana is **one [`futon`](../futon/SKILL.md) run** — `hatsu:futon <repo>@model/<line> then getsuga` —
plus the **six differences** this file owns (the maintainer's ruling of 2026-10-13,
[`ROSTER.md`](../../../docs/ROSTER.md) § *Rulings of 2026-10-13*): the selector read from the surface
(§ 1), the unlabelled directed first (§ 2), parallel delegates on `direct`'s primary pick (§ 3), a PR the
maintainer closed holding nothing (§ 5), a release proposal never the maintainer's to merge (§ 5), the
publish offer after the tag (§ 6). The rest is futon's, cited, never restated. **The phases this
composite calls skip their own `## 0.`** ([`STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) § 4).

## 1. Invocation — the selector is read, the go is typed

**P1 — `hatsu:ten kazaana` opens this run** ([`ten`](../ten/SKILL.md) § 6).

```
hatsu:kazaana <repo> [on <line>]
nen parse kazaana --grammar "<repo> [on <line:claude|gpt|gemini|grok|composer>]" --line "<the arguments>"
```

Verified at nen `0.21.0`: `<product-repo-A>` → `repo: <product-repo-A> · line: (clause absent)`; `on
llama` and an empty line are exit `2` — the trigger to ask (row `missing-argument`: the checkout's own
repository is the derived candidate).

**The line is the surface's main model, read, never remembered**: the session's surface as the harness
reports it ([`direct`](../direct/SKILL.md) § 2), then `aliases.<a>.line` **read from the registry file**
`$hatsu_root/contracts/direct.registry.json` for the alias whose `surface` is that surface and whose
`tier` is `deep` (`claude`, `gpt`, `grok`, `gemini`); `nen direct registry --json` validates the file
but prints no `line` (§ Residue). A typed `on <line>` overrides it. Cursor's second line is inventoried, its
own run named, never selected here (futon § 11).

Then the futon line, parsed as futon § 1 does and **echoed before anything is fetched**:

```bash
nen parse futon --repo <target checkout> "<repo>@model/<line> then getsuga" [--self <owner/name>]
```

**The typed `hatsu:kazaana` is the advance go for the `then getsuga` step of the futon line it
composes, and for nothing else** ([`mugetsu`](../mugetsu/SKILL.md) § 3 *Record*; ruling 2026-10-13, 1):
quoted at the echo, bound to the tag this run cuts, lapsing at a G5 or a halt; the step's `gate` line is
relayed as parsed. **Say the run has started** (a bounded `CON-25` delegation, futon § 7).

## 2. The inventory — labelled, unlabelled, directed, refetched

`nen backlog fetch --repo-slug <owner/name> --json` — never cached, never `--limit`. Every open issue
lands in exactly one set:

- **one `model/*`, this surface's line** — **the queue**.
- **one `model/*`, another line** — out of scope, listed with its line; never built here.
- **more than one `model/*`** (direct § 7 names an older label, never removes it) — **conflicting**: out
  of scope, listed; the maintainer settles the labels.
- **no `model/*`** — `hatsu:direct <CODE>#<N>[,…]` over **exactly these** (a missing `lang/`/`job/`
  axis is classify § 3 proposed there). **One table, one confirmation** for the batch (direct § 8's
  shape), **nothing written before the answer**; then direct § 7 publishes per `direct.publish` read at
  the default branch's tip. `none` there, a declined confirmation or direct § 8's **D**: no label lands,
  the set stays **unrouted**, listed, the opt-in's path named.

**Then refetch** — the same verb again — and re-partition: a `model/<line>` applied under this run joins
the queue. Triage, briefing and ordering are futon § 2's; an epic awaiting its mode label is **G1**
(`mode-label`). **State the queue before advancing anything**: count, issues, exclusions, § 3's plan.

## 3. The engine — futon's, with parallel delegates on direct's primary

Futon §§ 3–6 hold: delegated stage label and `nen loop slots --efforts <abs path>
--ci-cap 2 --local-cap 7 --json`. This file adds:

**One delegate authors and publishes each issue in its worktree**, raised as a **builder
effort** — [`WORKFLOW.md`](../../../docs/WORKFLOW.md) § *Where worktrees live* and its surface adapter
([`claude/rules/hatsu.md`](../../rules/hatsu.md) § 6: Antigravity `Workspace: "branch"`) — titled `kazaana · kurapika · <alias>`, bound to
`<core>/.nen/worktrees/<surface>/<name>`, handed the path, issue, stack base and aka § 0's push scope (HR-20); never raw `gh pr create`. **Its model is `direct`'s primary pick** — `.nen/direct/<effort>.json`,
else `nen direct resolve … --record` again — spelled through `models.<surface>.<tier>` and passed as the
raise's model; pass the dial where exposed (Claude Code Agent-tool has none). The delegate records `--dial` on phase/usage calls
and title/id at its first phase when exposed; shibari reads its ledgers. The primary
is never frontier. **The delegate runs
`ren` then `aka`** — on a canon repository (`nen repo classify` → `role: canon`)
[`great-hiker`](../great-hiker/SKILL.md) §§ 3–5 in `ren`'s place, mirrors, bump and checks, **in the
delegate, at its tier**: great-hiker § 2 raises no second subsession here (ruling 2026-10-13, 1). **This
session runs `mukai` and `en` per effort, one at a time**: a subagent raises no subagent (hanten's
reviewers, Illumi), and hanten § 4's reviewer checkouts are per persona. `en` is started per PR, never
offered; **a delegate never asks the wrap-up**.

**Stacks only on overlap** — WORKFLOW § *Stacked pull requests*, rules 1–6, never restated
(the maintainer's word: *"Use stacked PRs ONLY when necessary, otherwise target `main` directly"*).
Kazaana's own clause: **disjoint efforts are never stacked** — each cut from `origin/<branch.base>` and
opened against it; efforts sharing a path form one stack (rule 1), cut in order from the
previous effort's published branch (rule 2), so a stacked delegate starts once that `aka` has run. The
plan — what stacks, in what order, what stands alone — is stated at § 2's queue and is § 4's merge plan;
a slot frees per rule 4.

## 4. The register, and the merge plan

Futon § 9 whole: the Rikugan register every cycle, no banner on a progress turn, every PR at en § 5's
merge prompt a **G2/G4** gate event ([`jutaisho`](../jutaisho/SKILL.md) § 4). **The desk carries the
merge plan** (ruling 2026-10-12): independent PRs first, one line each, then each stack **bottom-up** by
WORKFLOW rule 5 — one `MERGE` ask only for a PR whose base reads `branch.base`; a stacked PR is
presented nowhere as mergeable. **The final report names the same order.**

## 5. The `then getsuga` step — held, then cut; the proposal is never theirs to merge

**Kazaana's own gate** (ruling 2026-10-13, 2; futon § 8 reads *merged* alone): nothing after `then`
runs until every PR this run authored is **merged into `branch.base`, or closed by the maintainer** — a
PR closed unmerged is reported as not delivered, its issue left open, and holds nothing; **a child of a
closed stacked PR is stranded** (WORKFLOW rule 5, en § 6), reported, and holds the gate until the
maintainer closes or retargets it. Until then the run is **held at its gate**, every merge prompt
standing (futon § 8). Then [`getsuga`](../getsuga/SKILL.md) runs under its own authority at the
configuration default cut point, and **its § 3a's kazaana paragraph is the one statement of the rule**
the maintainer gave — *"NEVER prompted to the maintainer to merge himself"*: transient conditions held
through en's observation hold, every declaration-gate fall-back a **G5 halt** handing the exact command,
never a `MERGE` ask, the `aiReviewers` case owed to nen (§ Residue). The fan-out is getsuga § 7's.

## 6. After the tag — the publish offer

**After futon's run has ended** (§ 5's gate passed, the tag cut), on kazaana's own authority under
ruling 2026-10-13, 3 — futon § 11 governs a `then` step, not this question. Once the tag resolves on
origin (`git ls-remote --tags`), ask **once** through the surface's own picker (row
`publish-offer`), **only where** the target's kind (`nen repo classify`) is listed under
`futon.advanceGo.mugetsu` as `nen parse futon` reads it — the target's declared key, or nen's default
where absent (futon § 8) — else no offer, said. **Zero declared destinations: no offer, said.** One:
*Publish `<tag>` through `hatsu:mugetsu` to `<destination>`?* — **A** publish: the answer is the go ·
**B** not now. **Several: one unstarred option per destination, plus not now** — the answer names the
destination. **No option is ever starred**: G3 is never recommended. On a publish answer, run
[`mugetsu`](../mugetsu/SKILL.md) with it as the go — form (4) of mugetsu § 0, quoted verbatim with the
question in the report and on the release PR. On **not now** end with the tag and the line to type
later. A refused tag capability halts before any offer.

## 7. Ending the run

Futon § 10: the run ends when every queued issue is merged, closed by the maintainer, briefed or
blocked **and** the `then` step has run, halted, or is **held at its gate**. The final report is
[`rikugan`](../rikugan/SKILL.md) over this run's scope — issues, every PR, the proposal, the tag, the
fan-out, the publish outcome — `final` only if every PR merged and the tag cut, else `register` with
§ 4's plan. Then **kazaana, once, asks the wrap-up picker** ([`cleanup`](../cleanup/SKILL.md) § 2, row
`wrap-up`). **Kazaana never resumes itself**; re-invoke it.

## Residue

`nen direct registry --json` prints no `line`, so the surface → line read is the registry file (**owed to
nen**, to file). Raising a delegate has no verb; § 3 names the effort-dial residue; the overlap read
has none. **Owed to nen**: `nen pr merge --release-unit` reading `aiReviewers` (getsuga § 3a) — to file.

## Authority

- **Permitted:** futon § 7's delegation; classify's and direct's writes after § 2's one confirmation;
  delegates at direct's primary tier; branch pushes (aka § 0, HR-20); `mukai` and `en` per effort; the typed invocation as getsuga's
  advance go; the publish offer, and `mugetsu` on a publish answer only.
- **Not permitted:** merging a delivery PR, a G1 label, a review vote, raw `gh pr create`, a
  frontier-tier delegate, widening the selector.

## Hard limits

- **Never merges into `main`** save getsuga § 3a's own proposal through `nen pr merge --release-unit`;
  **never presents that proposal as the maintainer's to merge** (§ 5).
- **Never exceeds 7 local efforts**, never lets two delegates share a file, never stacks disjoint efforts.
- **Never publishes a release without the answer**, never stars one, never offers where the policy does
  not list the kind or no destination is declared.
- **Never raises a delegate on the frontier tier**, nor on a tier direct did not name.
