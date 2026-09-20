<!--
  templates/pr-body.md — the nine-part PR body hatsu:shibari fills.
  Moved out of claude/skills/shibari/SKILL.md § 3 (2026-09-20 diet, zheref/hatsu#89).

  THE TARGET REPOSITORY'S OWN TEMPLATE GOVERNS THE SECTION *NAMES* where it has one; this file
  governs what each part must CONTAIN. A part with no fact behind it SAYS SO — "No user-visible
  surface changed, so there is no evidence table (logic-only change, UZF-26 exempt)." is a complete
  answer, a blank heading is not, and nothing here is written from what the change was supposed to do.

  THE THREE MECHANICAL CHECKS, all run before the body is written back (shibari § 5):

    (a) nen pr body-check --body-from <this file, filled> --requirements-from <path>
        --requirements-from is a JSON array of {name, pattern} from the target's own template
        convention, INCLUDING `## Agent attribution` as the final heading. Every requirement is
        reported, never stopped at the first miss, and exit 1 is a finding to fix: write the missing
        section and re-run.

    (b) nen changelog fragment-required --spec-paths "CONSTITUTION.md,handbooks/,nen/,schemas/,agents/,.github/workflows/" \
          --fragment-dir changelog.d --files <the changed paths> --head-changelog <path to CHANGELOG.md> \
          [--body-from <this file, filled>]
        A separate, DIFF-shaped check, because body-check never looks at changed paths. Four
        verdicts: not-applicable, required (exit 1), fragment-present, and opt-out where --body-from
        carries a `no CHANGELOG entry: <reason>` line. KEEP BOTH `nen/` AND `schemas/` — a prefix is
        taken literally and dropping it would under-derive. --head-changelog must exist or the verb
        refuses at exit 2, reported as the fact it is and never as a clean verdict, and
        fragment-present needs the fragment on disk at head as well as in --files.

    (c) The gate is derived, never asserted — docs/WORKFLOW.md § Gate derivation. THE BODY NAMES THE
        GATE AS A FORECAST, NEVER AS A STATUS, because a PR shibari just opened is by definition not
        ready, and shibari never labels one.
-->

## Why

<!-- The problem in the reader's terms, and the authoring nature (Enhancer / Conjurer / Transmuter).
     From the issue, or from the request that started the effort. -->

## How

<!-- The approach, and the alternative that was rejected, with the reason. From the run's own decisions. -->

## What this changes for you

<!-- EFFECT FIRST, AND THE COST STATED, for a NAMED consumer — "for anyone calling `x`…", "for a
     maintainer running `hatsu:mukai`…", "for a user opening the settings screen…". "You" without a
     referent addresses nobody. Read the diff as its consumer would meet it. -->

## How to verify

<!-- Steps someone can actually run, per scenario, quoting the verbs the repository declares as they
     were run. WITH NO BACKING ISSUE, THIS IS THE ACCEPTANCE CRITERIA. -->

## The flow

<!-- A mermaid diagram, ONLY when a flow, a state machine or a sequence actually changed. Draw the NEW
     flow and say in one line what moved; a before-and-after pair only when the move is the point.
     Omit the section entirely where nothing of the kind changed. -->

## Evidence

<!-- The UZF-26 table — docs/WORKFLOW.md § The UZF-26 evidence shape. The rows come from mukai step 7's
     evidence pass and are RE-USED, never re-derived. -->

## Completion checklist

<!-- One box per condition this PR claims to have met, EACH WITH THE EVIDENCE THAT SETTLES IT ON THE
     SAME LINE. An unticked box is a statement and it stays unticked; a condition that is genuinely
     not applicable says `n/a` with the reason rather than being ticked. -->

- [x] Required tests — kotoamatsukami: `<N> passed / 0 failed` / `not applicable — no impacted suites` / seat quoted; never tick "green" when nothing ran
- [x] Touched-file coverage — byakugan against `coverage.minimum` (not a hardcoded 80): lowest touched file `<n>%` / `not measurable here` with the reason
- [x] Adversarial review settled — <reviewer> · <persona>, <n> findings, all disposed (hanten)
- [x] `## What this changes for you` and `## How to verify` present — `nen pr body-check`, 3/3
- [x] Final `## Agent attribution` present — `nen pr body-check`, 4/4
- [x] changelog fragment — `nen changelog fragment-required`: <verdict>
- [ ] <a condition that is NOT met, with what is missing>

## Associated issues

<!-- Every issue this PR addresses, in the body AND in GitHub's Development association — shibari's
     linkage contract. One row per issue: the canonical URL, the scope this PR implements, and whether
     merging COMPLETES it or delivers part of it. Prerequisites and incidental references are listed
     separately; a PR with no associated issue says so rather than inventing one. -->

| Issue | Scope this PR implements | Merging this |
|---|---|---|
| <canonical URL> | <the part of it this PR delivers> | **completes it** / **delivers part** |

## Agent attribution

<!-- The participant ledger, following <plugin root>/docs/AGENT-ATTRIBUTION.md: every and ONLY the
     agents that actually participated, with canonical Hatsu persona, contribution and reviewable
     evidence. NO model, runtime, surface or session metadata, and never a contributor inferred from
     the branch, a default coordinator persona, a reviewer request or a model label. Commit messages
     carry only the canonical Hatsu-Agent / Akatsuki-Agent trailer. THIS IS THE FINAL HEADING. -->
