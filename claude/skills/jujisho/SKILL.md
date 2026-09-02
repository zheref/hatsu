---
name: jujisho
description: Split a mixed working copy into up to two stacked branches and PRs, by axis, leaving nothing behind. Use when the maintainer invokes hatsu:jujisho, or asks to split these changes, separate these concerns, or break this into separate PRs. Kurapika names every axis it finds, stacks the second PR on the first, states the merge order in both bodies, and asks which two when there are more. Never merges, never drops a hunk.
---

# Jujisho — one working copy, two stacked PRs, nothing left behind

**Nature: Enhancer** for product code, **Conjurer** for spec/governance, **Transmuter** for
machinery — and **Manipulator** for the GitHub-side mechanics (branch, PR, retarget) once the axes
are named. A mixed working copy routinely needs more than one; say which mode leads when it does.

> **Separate what I have by what it is actually about, and leave no dot unconnected.**

[`hatsu:tensho`](../tensho/SKILL.md) treats the working copy as one effort. jujisho is for when it
is not.

---

## 1. Invocation

```
hatsu:jujisho
```

No arguments. The working copy is the input — there is nothing here for `nen parse` to check
(that verb validates a skill's own flag grammar; jujisho takes none).

**The base is `main` for two independent efforts, and `integration/<chore>` when the two legs are
one logical effort** — the `CON-36` case in § 4. Decide that *before* cutting branches, because it
changes what A is based on and what "done" means: for a chore, both legs land on the chore branch
and the maintainer's gate is the `integration/<chore> → main` delivery PR, not either leg.

Run `nen wc classify --repo <path> --base <target base>` first, exactly as
[`hatsu:tensho`](../tensho/SKILL.md) does: it reports whether the checkout is `must-move` (on the
trunk, dirty — cut every axis branch from the target base, never reflexively from `main`),
`on-branch-dirty` (uncommitted work sits on an existing branch — read the evidence it hands back
before assuming any of it is one of the axes), or `on-branch-clean`. It is a report, not a guard;
the judgment of which axis the existing branch's commits belong to stays yours.

## 2. Find the axes — then say what you found before touching anything

An **axis** is what a change is *about*: a subsystem, a concern, a layer, a bug versus the
refactor it sits on, spec versus the machinery implementing it. Derive axes from the **diff**, not
from file paths — two files in one directory are routinely two concerns, and one concern routinely
spans four directories.

**Report every axis before splitting**: its name, the hunks it owns, and one line on what makes it
one thing. This is the step the maintainer checks; the mechanics after it are just git.

**A change that cannot be cleanly separated is not split.** If axis B's code does not compile
without axis A's, they are one effort delivered in sequence — which is what stacking is for (§ 4),
not a reason to force a cut through the middle of a function.

### Prove it, before opening anything — `nen split verify`

**Nothing is left behind — this is the rule the skill exists for.** Every hunk, every new file,
every deletion, every untracked file lands on exactly one axis. **A leftover hunk is a silent bug**,
because it is invisible in both PRs and will surface later as an unexplained local change. If a
hunk genuinely belongs to both axes, it goes on the **lower** one in the stack, and both bodies say
so.

This used to be a claim the skill asked the reader to trust by eye. It no longer is:

```bash
git diff <base> > original.diff                       # BEFORE cutting any branch
# … cut each axis branch, commit only that axis's hunks …
git diff <base>...<axis-A-branch> > axis-a.diff
git diff <base>...<axis-B-branch> > axis-b.diff
nen split verify --original original.diff --branches axis-a.diff,axis-b.diff
```

`nen split verify` proves every hunk in `--original` lands in exactly one of `--branches`, same
body, and reports `MISSING` / `DUPLICATED` / `ALTERED` / extra otherwise. Exit `0` means proven;
exit `1` means the split is incomplete and nothing is opened until it reads `OK`.

> **Known defect — verified live, `docs/ab/jujisho.md` § 2.1–2.2.** When `--original` spans **more
> than one file** (more than one `diff --git` block), `nen split verify` misparses every file
> **except the last one named in the original diff**: it reports a false `ALTERED` on an otherwise
> byte-identical hunk, with the diagnostic reading exactly
> `line N: original "(absent)" vs branch ""` at the position one past that hunk's true last line.
> **The same false `ALTERED` also fires within a single file, at a hunk boundary rather than a
> file boundary**, whenever that one file's branch-side diff is genuinely short a hunk: the
> surviving hunk is falsely reported `ALTERED` alongside the correctly-reported `MISSING` line for
> the hunk that really is absent. **Reproduced independently five ways** (two-file order A, the
> same two files reversed, a three-file original, a single-file two-hunk case with a hunk
> genuinely dropped, and the same single-file two-hunk case with nothing dropped, which verifies
> clean) — it is not a fluke of one construction.
>
> **The mandated workaround, until this is fixed upstream:** run `nen split verify` **once per
> touched file**, slicing `--original` into one per-file diff for each file the working copy
> touches and slicing `--branches` into the matching per-file diff from whichever axis branch(es)
> carry that file — comma-separate more than one only where a hunk is deliberately shared per the
> lower-axis rule above. **A per-file slice is not immune to the false `ALTERED`** — the
> hunk-boundary case above can still produce one — **but the workaround stays safe**, because a
> real gap (a hunk truly missing on the branch side) always also produces its own `MISSING` line:
> the split is never reported as a clean `OK` when a hunk has genuinely been left behind. Confirm
> every per-file run reads `OK` with no `MISSING` line. **Then separately confirm the file set
> itself**: the set of files named across every `--branches` diff must equal the set of files
> named in `--original`, with none extra and none missing — a plain comparison of each diff's
> `diff --git` lines, not a verb call. Together these reconstruct exactly the guarantee one
> correct combined run would give, without ever letting a genuine gap through undetected. **File
> this as a finding against `nen` (`docs/ab/jujisho.md` § 4); never quietly trust a bare
> `OK`/`ALTERED` verdict from a multi-file `--original` run as-is, and never silently widen the
> workaround into skipping the proof.**

## 3. Three or more axes — report, then ask

The cap is two. When the working copy genuinely has three or more axes, **do not silently merge two
unrelated ones to satisfy the cap** — that is the unconnected-dots failure in a different costume.

Name every axis with what it carries, then ask through the harness's question interface, with a
recommendation: **combine two named axes** (say which and why they are closest), **defer one** to a
follow-up run, or **lift the cap** for this run. The maintainer's answer decides.

## 4. Stacking — always, and what it costs

**PR B targets PR A's branch**, never `main`. So B's diff shows only B's change, and a reviewer sees
one concern at a time — which is the whole point of splitting.

Order the stack by **dependency, then by unblocking power**: A is the one B needs, or if neither
needs the other, A is the one whose merge frees the most.

**State the cost in both bodies, plainly:**

- **B cannot merge until A does, and retargeting it is a step you take.** GitHub only auto-retargets
  a PR when its base branch is **deleted**, which depends on the repo's delete-on-merge setting and
  on the maintainer not keeping the branch. **Do not rely on it:** after A merges, run
  `nen pr retarget --target <owner/name> --pr <B> --base main` (resolve `<owner/name>` with
  `nen repo resolve --from <checkout>` rather than reading `git remote -v` by hand) and confirm the
  base changed — `nen` exposes no read-back for a PR's current base, so `gh pr view <B> --json
  baseRefName` remains the confirmation step (`docs/ab/jujisho.md` § 3 residue). A stacked PR
  silently left pointing at a merged branch shows an empty or nonsensical diff, and reads as
  "already done".
- **If A moves, B's base moves under it.** When A takes review commits, or `main` cascades into A,
  **cascade A into B in the same pass, by merge, never by rebase** — a rebase of A orphans B's
  history and is the failure `CON-21` exists to prevent. With B checked out:
  `nen pr cascade-main --repo <path> --trunk <A's-branch-name>` — the verb's `--trunk` override
  makes it merge (never rebase) *whatever branch you name* into the current one and push on a clean
  merge, reporting a conflict rather than resolving it. It is written for merging `main` in; naming
  A instead is exactly this skill's use of it.
- **B's checks are only meaningful against A's current head.** A red check on B that is really A's
  problem is reported as such, not iterated on.

> **When the two legs are one logical effort, this is a `CON-36` chore — say so.** Two PRs
> delivering one unit of framework work belong on an `integration/<chore>` branch, where the
> delivery PR is `integration/<chore> → main` and is the maintainer's gate. Stacking two
> `main`-bound PRs and stacking two legs of a chore look identical in git and are governed
> differently. Name which one this is, in both bodies.

## 5. Staging discipline

Every rule from [`hatsu:tensho`](../tensho/SKILL.md) § 3 applies unchanged, per branch: run
`nen stage triage --repo <path> [--scope <axis's own paths>] [--mentions "<commit/PR draft text>"]`
before staging each axis. It **detects, never decides** — secret shapes, git-ignored files,
binaries, out-of-scope paths, unmentioned deletions — and exits `1` on anything flagged. **A
flagged file is never committed without an explicit yes**; that yes is the skill's to give, never
the verb's.

**One flag category from the old checklist has no detector in `nen stage triage` at all — residue,
not routed around by hand, still asked about by eye,** same finding as
[`hatsu:tensho`](../tensho/SKILL.md) § 3: a local-config file (`.claude/settings.local.json`,
editor state, OS cruft) that is neither git-ignored nor out of the declared `--scope` reports
**clean** — the verb names five detectors and local-config is not one of them. Ask about any
local-config path by name regardless of what the verb reports, per axis.

Format each commit with `nen commit format --type <t> --subject "<...>" [--scope <s>] [--body "..."] [--trailer Akatsuki-Agent=kurapika]` —
it validates shape (declared type, non-empty subject under 72 characters, no trailing punctuation),
never content; what changed and why stays yours to write.

Branches are `kurapika/<slug>` per axis (the local plane's own convention — not `CON-27`, which
governs worktree isolation), slugs from the axes, not `part-1`/`part-2` — the names are what a
reader sees in the PR list.

## 6. The PRs

Both carry what `schemas/templates/pr.md` requires — `# What this changes for you` (`CON-17(a)`),
`## How to verify` (`CON-17`). Check whether a `changelog.d/` fragment is owed with
`nen changelog fragment-required --files <this axis's changed paths> --spec-paths
CONSTITUTION.md,handbooks,schemas,agents,.github/workflows --fragment-dir changelog.d
--head-changelog CHANGELOG.md` (`CON-33(a)`) rather than eyeballing the path list by hand — it
answers per axis, since the two PRs' changed-path sets differ.

Additionally, **each body carries the split itself**:

- **The axis** this PR is, in one line.
- **The sibling**, formatted with `nen ref format --code <CODE> --kind PR --number <A|B> [--state
  <s>]` rather than hand-typed object notation, linked, with the relationship: *"stacked on
  `<CODE>-PR-#<A>`; merge that first."* / *"`<CODE>-PR-#<B>` is stacked on this; **retarget it** to
  the final base once this merges."*
- **What was split off and why**, so a reviewer knows what they are *not* looking at and does not
  file the absence as a gap.
- **The merge order**, stated as an instruction, not an implication.

## 7. After

Report both PRs with the stack drawn, then hand them to
[`hatsu:drive`](../drive/SKILL.md) — **A first**. Driving B to readiness while A is unmerged produces a PR that is ready
against a base that will change; take A to its gate, and start B once A's merge retargets it.

## 8. Authority

- **Permitted:** branch, commit, push non-`main` branches, open PRs, request reviewers (`nen pr
  request-reviews`), cascade A into B, retarget B once A merges, and everything `drive` is
  permitted.
- **Not permitted:** `bankai:agent/*`, `bankai:stage/*`, G1 mode labels, any merge (including
  merging A to unblock B), any review vote (never `request_changes` — Manipulator's standing rule).

## 9. Hard limits

- **Never leaves a hunk behind.** The union of the splits equals the original diff, proven by
  `nen split verify` — per file, per § 2's mandated workaround while the multi-file defect stands.
- **Never merges two unrelated axes** to fit the cap — it reports and asks.
- **Never rebases a pushed branch**; A reaches B by merge (`nen pr cascade-main --trunk <A>`,
  `CON-21`).
- **Never opens B against `main`** while A is unmerged.
- **Never commits a flagged file without an explicit yes.**
- **Never merges A to unblock B** — G2/G4 are the maintainer's.
