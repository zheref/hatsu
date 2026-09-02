---
name: file
description: File one well-formed, correctly-labelled, non-duplicate issue — reconciling it against the open backlog first. Use when the maintainer invokes hatsu:file <problem> <repo> or a bare hatsu:file (which files what the session has just been discussing), or asks to file, open, log or raise an issue. Kurapika searches for duplicates to amend, near-neighbours to fold into, and issues this supersedes, then presents ONE plan for ONE confirmation before anything is written.
---

# File — one issue, reconciled against the backlog before it is written

**Nature: Manipulator** — the filing itself is GitHub-side reconciliation and label
application, the same discipline as a drive or a wake. Name a second mode alongside it when
the underlying problem is squarely governance (**Conjurer**), machinery (**Transmuter**), or
product code (**Enhancer**) — say which leads, per the identity header's rule against blending
modes silently.

The default failure this skill exists to prevent is not a badly-written issue. It is a **backlog
that grows faster than it is worked**, because every new finding is filed as if the backlog were
empty. So filing is the *last* of five steps, and four of them are about what is already there:

> **Amend a duplicate · fold into a neighbour · supersede what this obsoletes · then file · then
> label so a loop can triage it without reading it.**

---

## 1. Invocation

```
hatsu:file <problem to file> <product|repo_code>
hatsu:file <problem to file>
hatsu:file
```

**Parsing.** The **last whitespace-delimited token** is taken as the repo **only if it
resolves**:

```bash
nen repo resolve <token>
```

against the current checkout's `schemas/repos.json` — a `product_code`, an owner/name slug, or
a repository's short name, matched exactly and case-insensitively, never as a prefix (verified
live: `nen repo resolve BC` exits `0` with the resolved slug; `nen repo resolve notarealtoken`
exits `1` and its own refusal text names every valid code and repository — that refusal text
**is** the candidate list, never re-derived by hand). **Exit `0`** → the token is the repo;
everything before it is the problem. **Exit `1`** → the token is **part of the problem text**,
not a typo'd repo — never silently repoint a filing at a repo the maintainer did not name.

**The repo, when omitted:** run `nen repo resolve` with **no token** — it resolves the current
working directory's `origin` remote against the same registry. If the cwd is not a registry
repo, it refuses (verified live) and the refusal text already lists the registry's codes and
repositories — **ask, quoting that list**, rather than reconstructing it. Filing into the wrong
repo is worse than a round-trip: it routes the work to the wrong lane, wakes the wrong agent,
and hides from the sweep that would have caught it.

**The problem, when omitted (bare `hatsu:file`):** the subject is **the problem this session has
just been discussing** — the defect just diagnosed, the gap just hit, the thing that just went
wrong. State the problem back in one line **before** doing anything else and let the plan carry
it; the maintainer's confirmation of the plan is the confirmation of that reading. If the session
has discussed several distinct problems, **do not merge them** — say so and ask which, or file
them as separate issues (one issue per distinct problem).

## 2. Before the plan — elicit what is missing

Ask for missing data **before** presenting the plan, never after. A plan the maintainer must
amend three times is a plan that was presented too early.

**Every issue owes:** the problem in one sentence · the evidence (a run link, a diff, a paste, a
repro) · why it matters and to whom · **observable** acceptance criteria · explicit scope
boundaries · the cross-references it touches (constitution/handbook clause IDs, rule IDs, files,
sibling issues, in the target repo's own object notation — § 5's `nen ref` note).

**A product defect additionally owes:** repro steps, expected vs actual, platform and build,
frequency. **A performance finding owes its method block** — an unqualified number is void
(`nen quality method-check` validates one, if the target repo scenario carries method-block
rules). **A machinery defect owes** the failing run link and what the guard should have done
instead. **A canon/governance gap owes** the rule that is missing or wrong, and what a reader did
instead because of it.

**Never invent an acceptance criterion to fill the shape.** An issue whose acceptance criteria
were guessed will be built to the guess. If a criterion is genuinely the maintainer's call, name
it as an open question inside the issue rather than resolving it silently.

## 3. Reconcile against the backlog — the four searches

Export a token first — `nen` never picks one up ambiently, unlike `gh`:

```bash
export GH_TOKEN=$(gh auth token)
```

Then run the whole reconciliation in one call:

```bash
nen issue search --target <owner/name> --subject "<text>" \
  [--files a,b] [--rule-ids X-1,X-2] [--lane-labels l1,l2]
```

This **is** the four duplicate searches, run in order and reported with what each pass was
for — never reconstructed by hand: **subject/open**, **subject/recently-closed** (the verb picks
its own lookback window), **files+rule-ids**, **lane**. A pass with no terms to search on is
reported `skipped`, never silently omitted (verified live: an invocation with no `--files`,
`--rule-ids` or `--lane-labels` prints `skipped -- this pass had no terms to search with` for
both of those passes rather than staying quiet about them). **Exits `1`** when any pass could
not run at all — "found nothing" and "could not look" must never read the same; a non-zero exit
here is itself a finding to report, not a clean empty search.

**(a) Duplicates — amend, do not file.** Same problem, same scope, same lane. Comment on the
existing issue with the new evidence (`gh issue comment <n> --repo <owner/name> --body-file
<path>` — **residue**: no `nen` verb owns posting a plain issue comment; see the port's A/B
doc), and **raise its severity** where the new evidence justifies it, via:

```bash
nen label apply <CODE>-IS-#<n> --label <severity-label> --repo-slug <owner/name> \
  --reason "<what changed the assessment>" --run
```

only once the plan is confirmed (§ 4) — say what changed the assessment (broader blast radius, a
second occurrence, a consumer now affected). One open issue per distinct problem.

**(b) Fold — near, not same.** A different problem whose **scope and authority level** are close
enough that one PR would sanely deliver both: same lane, same files or same clause, same
severity band. Folding adds the new requirement to that issue as a checklist item plus a comment
explaining the addition (same residue as (a) — a plain `gh issue comment`). **Do not fold across
lanes** — a governance change and the machinery that implements it are a dependency chain, not
one issue; if they must ship together, say so and name it as a chore instead.

**(c) Supersede — this obsoletes those.** Where the new requirement makes an existing issue's
approach or scope moot, propose closing the former **with a comment naming this issue and why**.
Guard every candidate first:

```bash
nen issue open-pr-check --target <owner/name> --issues <n1,n2,...>
```

**Exits `1`** when any candidate carries an open PR (verified live against `zheref/bankai-core`:
scanned every open PR, matched by both `closingIssuesReferences` and body mentions, and flagged
every issue either one touches — cross-checked by hand against `gh pr view <n> --json
closingIssuesReferences,body`, byte-identical). **Exit `0`** clears every candidate.

> ⚠️ **An issue with an OPEN PR is never quietly closed.** `open-pr-check`'s exit code is the
> guard, but the decision is still the plan's: flag it prominently with a recommendation —
> usually *exclude it from the supersede set and let its PR land first* — and let the
> maintainer's approval cover whatever the plan states. Closing the issue itself is `gh issue
> close <n> --repo <owner/name> --comment "<text>"` — **residue**: the same gap as (a)/(b), no
> `nen` verb closes a single issue with free-text comment outside the multi-child
> `consolidate-close` choreography in (d).

**(d) Umbrella check.** If three or more open issues would be folded or superseded, this is not a
filing — it is a **consolidation**, and `nen issue attach-sub` / `nen issue consolidate-close`
exist for exactly that shape (attach as sub-issues, compute the label union and severity maximum,
guard every child with the same open-PR check, then close — never the first failure, the whole
table). Say so and stop short of folding/superseding piecemeal here; hand the consolidation to
whatever skill owns it in this checkout (`hatsu:backlog-synthesis`, once ported) rather than
improvising the choreography inside `file`.

## 4. The plan, and the one confirmation

Present **one plan** covering everything that will be written, and take **one** confirmation for
all of it. The plan states, in this order:

1. **What is being filed** — the drafted title and body, in full. Not a summary of a body you
   will write afterwards; the actual text.
2. **The labels** that will be applied, each with its one-line basis (§ 5).
3. **Duplicates found** — which issue is being amended, with what comment, and any severity bump.
4. **Fold candidates** — which issue absorbs which requirement, or *none, and why not*.
5. **Supersede candidates** — which issues close, with the comment text, and any excluded for an
   open PR (`open-pr-check`'s own verdict, quoted).
6. **What was searched** — `nen issue search`'s own report, § 3, pasted in full. A reconciliation
   nobody can audit is a claim, not a check.

**The stop is a `G5` gate event.** Render it with the shared verb rather than reconstructing the
banner by hand:

```bash
nen stop --who Kurapika --gate G5 efforts.md
```

(or `-` to pipe a one-row efforts table through stdin) and put the **`DECIDE`** ask to the
maintainer with the options lettered — typically *file as planned* / *file, but skip the closes*
/ *amend the duplicate only* / *do not file* — the ⭐ recommendation, and what would tip it.

**Nothing is written before that answer.** Not the issue, not a comment, not a label, not a
close. A skill that files first and reconciles afterwards has already created the duplicate.

## 5. Labels — so the loop can triage without reading it

Applied **in the create call**, never as a follow-up edit:

```bash
nen issue file --target <owner/name> --repo <path to a checkout carrying schemas/*.json> \
  --title "<title>" --body-file <path> --label <a,b,...> --assignee <user> \
  --forbid-family <the target repo's stage-label family>
```

`nen issue file` checks every label against the target repository's `schemas/labels.json`
**before** attempting anything (verified live: an unknown label refuses with `is not in this
repository's taxonomy … GitHub would CREATE it rather than refuse, so a typo becomes a permanent
undocumented label` — GitHub itself never catches this, only the taxonomy check does) and enforces
`--forbid-family` as a hard, machine-checked guard (verified live: a label in a forbidden family
refuses with `is in the '<family>' family, which this invocation declared off-limits with
--forbid-family` — **before** any GitHub call is made). **Pass the target repo's stage-label
family to `--forbid-family` on every call this skill makes** — a stage label is the release
trigger and is the human's, never this skill's, and the flag turns that rule from a discipline
this skill's prose has to remember into one `nen issue file` refuses to violate.

| Class | What to apply | Basis |
|---|---|---|
| **Lane / agent** | Whichever labels route this problem to its owning discipline in the target repo's own taxonomy — several when it spans lanes | Read from `schemas/labels.json` at run time, never from memory; a label this port hasn't seen before is still a real one if the taxonomy carries it |
| **Severity** | Exactly one severity label from the target repo's own severity vocabulary | Propose with one line of reasoning; the plan carries it |
| **Kind** | Bug / handbook-question / epic / QA / observation-fix, as the target repo's taxonomy names them | What the issue *is* |
| **Stage** | **None** | Zero stage labels before release; the stage-that-is-the-release-trigger is the human's, and `--forbid-family` (above) makes that a call refusal, not a rule to remember |

**Assign the human maintainer** — a specific user, never an org login — so the issue reaches
them by notification rather than at the next local session.

**Severity is proposed, not decreed.** The plan says why, so it can be overruled in the same
answer that approves the filing.

**Cite every cross-reference in the target repo's own object notation** (`<CODE>-<IS|PR>-#<N>`),
formatted with `nen ref format --code <CODE> --kind IS --number <n> [--state <s>]` rather than
hand-typed — codes come from that repo's registry at run time (§ 1's `nen repo resolve`), never
from a fixed list carried in this file.

## 6. After filing — offer the build

Report the issue in object notation with its number linked, then offer the next verb in one
line:

```
hatsu:build <CODE>#<N>
```

**Offer it; never start it.** Releasing work into an agent's autonomous build is a separate
go-signal, given by a separate invocation. An offer that starts itself is not an offer.

## 7. Authority

`file` carries **routing delegation only, and only for what the approved plan named**:

- **Permitted:** the lane/agent labels on the issue it files and on the neighbours the plan
  names; the severity and kind labels; the comments and closes the plan states; `nen label
  apply --run` for a severity bump the plan named, logged in its ledger.
- **Not permitted:** any stage label (`--forbid-family` makes this a refusal, not just a rule), any
  G1 mode label, any merge, any review vote, any close the plan did not name.
- **Log every application** — object, label, time — in the report. `nen label apply` writes its
  own ledger entry (`outcome: "applied"` or `"failed"`, written after the call resolves) whether
  or not this report also restates it — restate it anyway, so the report is self-contained.

## 8. Hard limits

- **Never files without the confirmation**, and never files anything the plan did not show.
- **Never closes an issue that has an open PR** unless `open-pr-check` was run, the plan named it
  and the maintainer approved it with that fact stated.
- **Never files a duplicate.** If `nen issue search` could not run a pass (exit `1`), say so and
  file with a cross-reference rather than claiming a clean search.
- **Never applies a stage label** (`--forbid-family` enforces this mechanically on every `nen
  issue file` call — see § 5), and never releases work into build.
- **Never merges several distinct problems into one issue** to save a round-trip.
- **Never fabricates evidence, a repro, a number, or an acceptance criterion.**
- **Never files into a repo it resolved by guess** — `nen repo resolve`'s exit code is the only
  basis for treating a token as a repo (§ 1); never fall back to inferring one when it refuses.
- **Never hand-roll `attach-sub`/`consolidate-close`'s choreography** for a 1-or-2-candidate
  supersede that doesn't need it, and never invoke the umbrella verbs on fewer than three
  candidates just because they exist.
