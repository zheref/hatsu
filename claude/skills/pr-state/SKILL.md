---
name: pr-state
description: Report one PR's CON-32 readiness as the deterministic gate's verdict, quoted, with the conjunct-by-conjunct reason it passed or failed. Use when the maintainer invokes hatsu:pr-state <CODE>#<N>, or asks whether a PR is ready, G2-ready, G4-ready or mergeable. Strictly read-only — it never labels, merges, pushes, comments or opens anything. A readiness claim made any other way is not a readiness claim.
---

# PR state — the gate's verdict, quoted, or no claim at all

**Nature: Manipulator.** GitHub-side ops. Kurapika says so when he runs it.

This skill answers exactly one question, the same way every time:

> **Is this PR `CON-32`-Ready, and if not, which conjunct failed?**

It exists because the rule already existed and was skipped anyway. `scripts/pr_ready_gate.sh`
was `CON-32`'s sole authority in bankai-core since [BC-PR-#577](https://github.com/zheref/bankai-core/pull/577) — and
[BC-IS-#681](https://github.com/zheref/bankai-core/issues/681) was filed after a readiness claim was
made without running it. The verdicts, when it was finally run across the open set:

| PR | claimed | actual verdict |
| --- | --- | --- |
| [#575](https://github.com/zheref/bankai-core/pull/575) | "merge it" | `not-ready` — `CON-32(a)` |
| [#679](https://github.com/zheref/bankai-core/pull/679) | "once green" | `not-ready` — 1 unresolved thread |
| [#603](https://github.com/zheref/bankai-core/pull/603) | ready | **`ready`** |
| [#622](https://github.com/zheref/bankai-core/pull/622), [#678](https://github.com/zheref/bankai-core/pull/678) | "driving to ready" | `not-ready` — `CONFLICTING` |

**Three of four wrong.** Not for want of a tool — the tool evaluated 19 of 21 PRs fine on that same
host. It was skipped. **A deterministic authority an agent may skip is a suggestion**, so this skill
exists to make running it the cheap path, and the rule in § 5 exists to make not running it
indefensible. `nen pr ready` is the Nen-native port of that same authority — byte-for-byte transcribed
from `cli/src/ports/pr_ready_gate.ts`, and proven against the live shadow window (`docs/ab/pr-state.md`
§ 2) rather than merely asserted — so the rule below binds identically to it.

> **Read-only, without exception.** This skill renders a verdict. It never applies a label, merges,
> pushes, opens, closes or comments — not even when the verdict is `ready` and the merge is obvious.
> Acting on a PR is `drive`'s job once it lands under [zheref/hatsu#2](https://github.com/zheref/hatsu/issues/2)
> — this skill's own scope stops at reporting `ready`.
> `nen pr ready` itself has no notification mode to reach for by mistake — unlike the oracle it ports,
> which posts a "ready for decision" comment outside `--verdict`, this verb only ever prints a report.

---

## 1. Invocation

```
hatsu:pr-state <repo_code>#<PR_NUMBER>        e.g.  hatsu:pr-state BC#603
```

| Part | Accepts | Rule |
|---|---|---|
| `<repo_code>` | a product code from the target repository's `schemas/repos.json` → `product_codes` | **case-insensitive**; an unknown code is an **error** that names the valid ones, never a guess |
| `<PR_NUMBER>` | a positive integer | a number that names an **issue**, not a PR, is **not** caught as one before the call — verified against the real binary, it comes back `unevaluated: GitHub could not be read (… Could not resolve to a PullRequest with the number of <N>.)`, carrying `nen`'s generic token-grants remedy even though the token is fine — see the callout below and § 4 |

The codes are read from the registry **at run time, never from memory** — they change. `nen pr ready`
does this itself: pass the ref straight through and let the verb resolve it against
`--repo <path>`'s `schemas/repos.json`. Do not pre-resolve the code by hand or guess one from the
working directory.

> **Always write the `#`.** `nen pr ready --help` documents `<CODE>#<N>` "or a bare `<N>` with
> `--gh-repo`" and states the `#` is optional on its own refusal text — but **verified against the
> real binary, it is not, for any PR number with two or more digits**: `nen pr ready BC925 --repo
> <path>` refuses with `'BC92' is not a product code`, because the no-`#` parser splits off only the
> LAST digit as the number and misreads everything before it — including trailing digits — as the
> code. `BC9` (a genuinely single-digit ref) resolves fine; `BC92`, `BC925`, `BC9925` all fail the same
> way. **This is a finding against the binary, not a skill rule to route around by hand** — never
> improvise a different split. Always write `<CODE>#<N>` with the `#` present; it is unaffected.

> **A wrong number is caught by GitHub, not by `nen`, and the remedy it prints can mislead.**
> `nen pr ready` never checks whether `<PR_NUMBER>` names a pull request before asking GitHub —
> verified against the real binary, `BC#918` (`918` is an issue on `zheref/bankai-core`, not a PR) does
> **not** come back as "that's an issue." It comes back
> `unevaluated: GitHub could not be read (… Could not resolve to a PullRequest with the number of
> 918.)`, followed by `nen`'s generic token-grants remedy (`pull-requests:read AND checks:read AND
> actions:read`, not expired, network reached `github.com`) — a remedy that is **misleading here**: the
> token is fine, the number just names the wrong kind of object. **This is a second finding against the
> binary**, recorded in `docs/ab/pr-state.md` § 4 alongside the `#`-parser bug above — not a skill rule
> to route around by hand. Relay the reason and remedy exactly as printed anyway (§ 4, § 6); never
> silently upgrade `unevaluated` to "that number is an issue" on the reader's behalf, since `nen` itself
> never says that.

## 2. Run the gate — this is the whole computation

Export a token first — `nen` never picks one up ambiently, unlike `gh`:

```bash
export GH_TOKEN=$(gh auth token)
```

Then:

```bash
nen pr ready <CODE>#<N> --repo <path to a checkout carrying schemas/repos.json> \
  --gates "$CLAUDE_PLUGIN_ROOT/contracts/bankai-core.gates.json" --explain
```

or, with a bare number against a repo slug directly:

```bash
nen pr ready <N> --gh-repo <owner/repo> --gates "$CLAUDE_PLUGIN_ROOT/contracts/bankai-core.gates.json" --explain
```

**Always the `$CLAUDE_PLUGIN_ROOT`-anchored form, never a bare `contracts/bankai-core.gates.json`.**
The bare relative path only resolves from this checkout's own root as the process's cwd — verified
live: run from anywhere else, `nen` refuses `ENOENT: no such file or directory, open
'contracts/bankai-core.gates.json'`. `$CLAUDE_PLUGIN_ROOT` is the house convention for exactly this
(`claude/skills/hatsu-warmup/SKILL.md` § 0) and is cwd-independent.

- **`--repo <path>`** is the TARGET repository's working-tree root — a path, never an `owner/name`
  slug — used to resolve `<CODE>` against its `schemas/repos.json`. **`--gh-repo <owner/name>`** is the
  slug the API read runs against, needed whenever the ref is a bare number — `--repo <path>` is itself a
  path argument, not the cwd, so it already works from anywhere without `--gh-repo` alongside it.
- **`--gates "$CLAUDE_PLUGIN_ROOT/contracts/bankai-core.gates.json"`** — bankai-core is FROZEN and ships
  no `schemas/gates.json` of its own; without `--gates` (or a `--reviewers` override) `nen pr ready`
  refuses outright with `no reviewer identities` rather than guessing a reviewer set (verified live, § 2
  of `docs/ab/pr-state.md`). This repository's `contracts/bankai-core.gates.json` carries the same
  reviewer identities the oracle script hard-codes — see that file's own header. **A repo that ships its
  own `schemas/gates.json` needs no `--gates` flag at all**; this one is bankai-core-specific plumbing,
  not a general rule.
- **`--explain`** renders the conjunct-by-conjunct table in evaluation order, short-circuit rows
  included, plus the fixed "what the gate does NOT decide" caveats — all computed and printed by the
  verb itself; see § 3. Add `--json` instead when a caller needs the same content structured
  (`conjuncts[]`, `caveats[]`, `meta`).
- **Exit `0`** → the verdict is `ready`.
- **Exit `1`** → the verdict is either `not-ready: <first failing reason>` **or** `unevaluated: <what
  went wrong>` — read the printed verdict string itself to tell them apart; both share the exit code.
- **Exit `2`** → the invocation itself was refused before evaluation ever started (an unknown code, an
  unparseable ref, no reviewer identities, no `GH_TOKEN`-bearing token reachable in a way that stops the
  call outright). Never render this as any of the three verdicts — report the refusal text verbatim and
  fix the invocation.

**Never pass `--round-policy strict`.** `bounded` is the default and the settled `CON-32(b)` reading
(mirrors `pr_ready_gate.sh`'s own `--copilot-policy bounded` default, [BC-IS-#572](https://github.com/zheref/bankai-core/issues/572)); inheriting it is what keeps every
asker consistent when the policy is next revisited.

**Pass `--exclude-run $GITHUB_RUN_ID` only from inside a job asking about its own PR**
([BC-IS-#708](https://github.com/zheref/bankai-core/issues/708)) — it drops that run's own rollup
entries so an in-flight job cannot self-block the verdict. A human or a local session asking about
someone else's PR passes nothing.

## 3. The report — verdict verbatim, then the breakdown

**Lead with the verdict, quoted exactly as `nen` printed it.** Not paraphrased, not summarised,
not softened. `nen` prints the whole line as `<repo>#<N>: <gateLine>` — that entire line is the first
line of the answer. `gateLine` (the plain-text tail, or the `--json` field of the same name) is only
the part after the `: ` — e.g. `not-ready: 3 unresolved review thread(s) (CON-32d)` — never the
`<repo>#<N>` prefix in front of it.

Then the conjunct-by-conjunct table — **rendered by `--explain`, not reconstructed by hand.** The gate
is a conjunction evaluated **in this order**, and it **short-circuits on the first failure**, so
everything after the failing row is genuinely *unknown* and `nen` itself prints it as `unevaluated`
rather than as passing. The "what a failure reads as" column below is illustrative, verified live and
against `nen`'s own source (pinned `v0.1.0`) — **relay `--explain`'s own printed text, never retype it
from memory**, since more than one of these rows has more than one real shape:

| # | Conjunct | Clause | What a failure reads as (illustrative — quote `--explain`, don't retype) |
|---|---|---|---|
| 1 | Mergeable | `CON-42/1` | `mergeable=CONFLICTING`, or `mergeable=UNKNOWN (expected MERGEABLE — CON-42/1's added predicate)` when GitHub is still computing or the PR is closed — re-run if open |
| 2 | Every reported check green, on the **latest** run per check name | `CON-32(a)` | `required checks reported but are not all green (CON-32a)`; a wholly empty rollup instead reads `NO checks reported at head (CON-32a) — an EMPTY rollup, not a red one. …`; a cancelled latest run instead reads `required checks are not all green (CON-32a) — latest run CANCELLED, no verdict (needs a re-run, not a fix): <names>` |
| 3 | No configured reviewer's requested round has stalled | `CON-32(b)` | `<reviewer> round stalled — requested N min ago and never posted (CON-32b; re-request it, a user token is required)` — `<reviewer>` is whichever configured name actually stalled, never hardcoded to one identity |
| 4 | No configured reviewer's round **owed** at the current head | `CON-32(b)` | `a configured reviewer's round is still owed at the current head (CON-32b): <reviewer> (…)` |
| 5 | Every approving reviewer's **latest** round is an APPROVE at the **current head** | `CON-32(b)`/`CON-16` | `not every approving reviewer's latest round is an APPROVE (CON-32b): <unapproved>` — the printed text does not repeat "at the current head"; that reading lives in the conjunct's own definition (`CON-16`), not in the failure string |
| 6 | Zero unresolved review threads | `CON-32(d)` | `N unresolved review thread(s) (CON-32d)` |

**Name what the gate does NOT decide.** `--explain`/`--json` prints this block automatically, every
time — it is no longer boilerplate the skill has to remember to append by hand, only content this
skill must never omit or soften when relaying it:

- **`CON-32(c)` "addressed"** is *approximated* by rows 5 and 6 — the gate cannot read whether a
  thread's substance was actually answered. Replying remains the author's obligation.
- **A build check existing SPECIFICALLY** is not asserted — but *some* check must report. Row 2's
  check-green conjunct is `length > 0 and all(… SUCCESS/NEUTRAL/SKIPPED)`, so an **empty** rollup
  **fails**. **Absence is a finding here, not a pass** ([BC-IS-#680](https://github.com/zheref/bankai-core/issues/680)).
  What the gate cannot tell you is *which* checks reported — a repo where `CON-19` requires a build
  check gets `ready` from any other green check alone, so confirm by eye that the build one is among
  them.
- **`CON-32(e)` channel-less findings** — a reviewer finding with no thread object (a suppressed-comments
  block rendered in the review **body**) has nothing for row 6 to count. Read the review body, not just
  its threads.

## 4. `unevaluated` is a finding, never a pass

Where the gate cannot decide — no `GH_TOKEN`-bearing token reachable, a network failure, a check
rollup that could not be read — `nen` itself prints:

```
<repo>#<N>: unevaluated: <what went wrong>
```

followed by its own remedy line. **Relay that remedy line verbatim, never paraphrased** — it already
names the fix, and a paraphrase risks losing the exact grant or cause it points at.

**Never `ready`, and never silently omitted.** This is
[BC-IS-#680](https://github.com/zheref/bankai-core/issues/680)'s principle in its smallest form:
*absence is never a pass.* An unevaluated PR is a row that needs attention, not one that cleared.

**What would fix it — quote `nen`'s own remedy line, verified live (and against `nen`'s pinned `v0.1.0`
source) for each shape below:**

- `unevaluated: no usable token, so GitHub could not be read` — the `GH_TOKEN` export in § 2 was
  skipped or the token it names has expired; export a fresh one and re-run. This is verified live: an
  invocation with no `GH_TOKEN` set prints this exact string and a second line naming the cause —
  `GH_TOKEN is not set -- this client never picks a token up ambiently the way gh does`. Never read this
  as "the PR is not ready" — it is a caller-side setup gap.
- `unevaluated: the check rollup could not be read for <owner>/<repo>#<N>` — the remedy is a **missing
  token grant**: `checks:read` alone is not enough, the rollup's own `checkSuite.workflowRun` sub-field
  needs `actions:read` too (verified against `src/github/pr_state.ts` at the pinned `v0.1.0` tag). `nen`
  deliberately **refuses to conflate this with an EMPTY rollup** — a genuinely empty, *readable* rollup
  is `CON-32(a)`'s own `not-ready` instead (see § 3's build-check caveat). Unreadable and empty are two
  different findings with two different remedies; never collapse one into the other.
- `unevaluated: GitHub could not be read (<the API's own error text>)` — the generic shape, also
  printed when the ref names an **issue**, not a PR (§ 1's second callout: the API's own text reads
  `Could not resolve to a PullRequest with the number of <N>`). `nen`'s remedy line here is a
  token-grants checklist (`pull-requests:read AND checks:read AND actions:read`, not expired, network
  reached `github.com`) — relay it verbatim regardless, even though for the issue-number case
  specifically the real cause is the wrong object type, not the token. **This is the second documented
  defect against `nen`** (§ 1, § 6) — recorded in `docs/ab/pr-state.md` § 4 alongside the `#`-parser
  bug, not routed around by hand.
- A bare `nen: no reviewer identities …` refusal (exit `2`, not a verdict at all) means the invocation
  itself is missing `--gates`/`--reviewers` and a `schemas/gates.json` — fix the command, per § 2.

> **Historical note, kept because it is the reason this rule is written down.**
> [BC-IS-#639](https://github.com/zheref/bankai-core/issues/639) found the shell gate hitting `E2BIG` on
> 2 of 21 PRs whose check rollup exceeded the Windows argv cap. That specific cause is **fixed** in the
> shell oracle — the large blobs reach `jq` through files, never argv — and `nen pr ready` never shells
> the payload through argv at all, reading it over the GraphQL API instead. Do **not** report it as a
> live limitation on either side. The rule it motivated stands on its own for every other way
> evaluation can fail.

## 5. The binding rule — the half that actually changes anything

> **A readiness claim is `nen pr ready`'s verdict, quoted, or it is not made.**

No agent — CI or local — and no session may describe a PR as *ready*, *G2-ready*, *G4-ready* or
*mergeable* on any other basis. Not a checks-page reading. Not *"I just fixed it"*. Not the absence
of a red mark. Not *"the reviewers approved"*. Not the checks being **not yet reported**, which is
the specific error [BC-IS-#681](https://github.com/zheref/bankai-core/issues/681) records: pending
was read as green.

A skill nobody is obliged to use changes nothing, so the obligation is the rule and the skill is
merely the convenient way to satisfy it. **Where the gate cannot evaluate, the claim is
`unevaluated`** — the one thing that is never available is calling it ready anyway.

## 6. What this skill must never do

- **Act on the verdict.** No label, no merge, no push, no comment, no re-request, no re-run — even
  when the verdict is `ready` and the next step is obvious. Say what the action is; do not take it.
- **Paraphrase the verdict.** Quote it. A summarised verdict is a re-derived one.
- **Report `ready` for a PR it could not evaluate.** See § 4.
- **Guess a repo code**, or infer one from the working directory when none was given.
- **Improvise a no-`#` split by hand.** § 1's finding means `BC925` cannot be trusted through this
  verb at all — always write `<CODE>#<N>`.
- **Take an `unevaluated: GitHub could not be read (…)` token-grants remedy at face value for an
  issue-number ref.** § 1's second finding means that remedy is printed identically whether the token
  is actually missing a grant or the number simply names an issue, not a PR — check which before acting
  on the remedy.
- **Pass `--round-policy strict`**, or re-derive any conjunct by hand when `nen pr ready` is available.
- **Claim the conjuncts after the failing one passed.** The gate short-circuits; they are unknown.
