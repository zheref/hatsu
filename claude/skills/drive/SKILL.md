---
name: drive
description: Drive one open PR to CON-32 readiness at its human gate, then stop there. Use when the maintainer invokes hatsu:drive <CODE>#<PR> to <G2|G4>, or asks to get a PR ready, unstick a PR, or take it to the merge gate. Kurapika (Manipulator) diagnoses the first blocking condition, addresses threads or wakes the CI author with `nen wake fire` fired alone, decides readiness with `nen pr ready` plus an adversarial confirmation pass, and stops at a gate board. Never merges, never self-reviews, never casts a review vote.
---

# Drive — one PR, to the doorstep of its gate

**Nature: Manipulator.** GitHub-side ops — drives, wakes, labels, retargets, cascades, thread
stewardship. Kurapika says so when he runs it. Unlike the old skill's per-diff nature switch
(bankai-core's Ichigo had no dedicated ops mode, so it borrowed Shinigami/Quincy to signal the
PR's own domain), Kurapika drives a product-shaped PR and a governance-shaped PR through the exact
same mode, because the *action* here is always GitHub ops, never the code — Manipulator does not
switch with the diff.

This skill does one thing:

> **Take this PR to genuine `CON-32` readiness at its human gate, and stop there.**

It is the *verb* half of [`backlog-state`](../backlog-state/SKILL.md)'s noun. `backlog-state`
renders where everything sits; `drive` moves **one named PR** from wherever it sits to the point
where the only remaining actor is the maintainer. It never crosses the gate — G2 and G4 are theirs
(`CON-5`/`CON-7`), and Kurapika never merges `main`.

The old (bankai-core) version of this skill improvised almost every deterministic step by hand: a
raw `scripts/pr_ready_gate.sh --verdict` call for readiness (already ported — see
[`pr-state`](../pr-state/SKILL.md)), then prose reconstructing the first blocking condition, prose
verifying a wake landed, and a hand-maintained round count. This port replaces every one of those
with a `nen` verb — `nen pr ready`, `nen pr staleness`, `nen wake verify`, `nen pr body-check`, `nen
gate derive`, `nen pr cascade-main`, `nen wake fire`, `nen stop` — per zheref/hatsu#2. **One verb
this port needed does not work against real bankai-core PRs at all** (`nen pr next-blocker`,
sharing `nen pr fetch`'s reviews-endpoint crash) — see § 3 for the disclosed stopgap, and
`docs/ab/drive.md` for the reproduction.

---

## 1. Invocation

```
hatsu:drive <product_code>#<pr_number> to <G2 | G4>
```

| Part | Accepts | Notes |
|---|---|---|
| `product_code` | a code from the target repository's `schemas/repos.json` → `product_codes` | A short name (`bankai-core`) or `owner/repo` is also accepted |
| `pr_number` | an **open PR** on that repo | An issue number is an error — see below |
| gate | `G2` or `G4` | `to <gate>` may be omitted; the gate is then derived (§ 2) |

Parsing rules, all of them the same rule: **resolve or fail, never guess.**

- **Case-insensitive.** `bc#<n> to g4` is `BC#<N> to G4`.
- **Resolve the code once, up front**, and keep the owner/name slug it returns for every later
  call:
  ```bash
  nen repo resolve <CODE> --repo <path to the target repo's own checkout>
  ```
  prints `<owner>/<repo>  (<CODE>)  via code` — an unknown code is refused by name, listing the
  registry's real codes (never a guess, never a prefix match). Feed that `owner/name` into every
  flag below that wants `--gh-repo`/`--target`/`--repo-slug` — never re-derive it a second way.
- **This skill drives PRs, never issues.** If `#<N>` resolves to an issue, say so and point at
  `hatsu:build` (lands with a later port of hatsu#2), which is the issue-shaped verb. Do not
  silently switch — releasing work into an agent's autonomous build is a different authority than
  driving a PR that is already running.
- **A closed or merged PR ends the run immediately** with what happened to it. There is nothing to
  drive, and re-opening is the maintainer's call.

## 2. The target gate is **verified**, never accepted

`to G4` is the maintainer's *assertion*. Check it against the diff — mechanically, the same verb
[`backlog-state`](../backlog-state/SKILL.md) uses:

```bash
nen gate derive --policy-paths "CONSTITUTION.md,handbooks/,agents/,schemas/" \
                --process-paths ".github/workflows/,claude/,scripts/,tests/,docs/" \
                --files <comma-separated changed paths>
```

`--files`/`--files-from` are caller data — `nen gate derive` fetches nothing itself, so the changed
path set still comes from `gh pr diff <n> --repo <owner/name> --name-only` (residue: no `nen` verb
fetches a remote diff, per `backlog-state`'s own A/B).

If the derived gate differs from the one typed, **say so in one line, drive to the derived gate,
and carry the correction into the stop** — `nen gate derive --asserted <G2|G4>` reports the
mismatch itself (*"the invocation asserted G4; the diff derives G2, and the derived gate stands"*).
When `to <gate>` is omitted entirely, derive it silently.

> **`nen gate derive` reads the diff's half only — it does not know the PR's base branch.**
> `backlog-state`'s own A/B doc records this as a live, open finding (`BC-IS-#929`): a sub-PR based
> on an `integration/*` branch is not a maintainer gate row at all (Roy's cascade lane, `CON-5`),
> and the diff alone cannot tell you that. `nen pr fetch` would supply `baseRefName` and does not
> work (§ 3) — read it directly: `gh pr view <n> --repo <owner/name> --json baseRefName -q
> .baseRefName`. A base that could not be determined is reported `unresolved`, never assumed `main`.

## 3. The loop

Re-run from the top on **every** state change; never act on a picture older than the last fetch.

1. **Fetch the PR's state**, per-verb rather than one snapshot:
   - Readiness and the conjunct table: `nen pr ready <CODE>#<N> --repo <path> --gates
     "$CLAUDE_PLUGIN_ROOT/contracts/bankai-core.gates.json" --explain` (§ 4).
   - Body requirements: `nen pr body-check --body-from <path> --requirements-from <path>`.
   - Checks/comments/base ref not carried by the above: `gh pr checks`, `gh pr view --json
     body,comments,baseRefName`.

   > **`nen pr fetch` — the verb documented to return this whole snapshot in one call — is broken
   > against every real bankai-core PR tried.** Reproduced live against both open PRs at port time:
   > `zheref/bankai-core#925` crashes `could not fetch ... reviews: gh: Unprocessable Entity (HTTP
   > 422)`; `#940` crashes with a *different* shape, `$.reviews -- expected an array, got object`
   > (a lone `PENDING` review returned unwrapped). Two distinct failure modes, same verb, same
   > session — see `docs/ab/drive.md` § 2 for both transcripts. **This skill never calls `nen pr
   > fetch`.** Readiness comes from `nen pr ready` (a separately-verified, working code path); the
   > rest comes from the calls listed above.

2. **Decide readiness** — § 4. Ready ⇒ go to § 8 and stop.
3. **Name the FIRST blocking condition**, in this order, and act only on that one:
   conflict → red required check → owed reviewer round → unresolved thread → missing body
   requirement (`## How to verify`, `CON-17`; a `changelog.d/` fragment where `CON-33(a)` requires
   one). Fixing the fourth thing while the branch is conflicted wastes a cycle, because the
   conflict re-invalidates the checks anyway.

   > **`nen pr next-blocker` — the verb built to name this order for you — does not work against
   > real bankai-core PRs either, and for the identical underlying reason.** `next-blocker` has no
   > `--gates` override at all (only `--reviewers`/`--approvers`, and passing them does not help):
   > against frozen bankai-core, which ships no `schemas/gates.json`, it refuses outright —
   > `schemas/gates.json: no such file ... has no built-in copy to fall back on`, reproduced live
   > against both open PRs. Supplying that file into a scratch checkout satisfies the refusal, but
   > the verb then hits `nen pr fetch`'s own crash underneath — `could not fetch ...#925 reviews: gh:
   > Unprocessable Entity (HTTP 422)`, and, on retry, the identical 422 for `#940` too (not the
   > schema-shape error `pr fetch` gave that PR standalone — the two verbs' internal calls disagree
   > with each other on the same live data). **This port never calls `nen pr next-blocker`.** The
   > disclosed stopgap: `nen pr ready --explain`'s conjunct table already evaluates conflict → checks
   > → reviewer-round legs in this same short-circuit order (§ 4's six rows collapse onto
   > `next-blocker`'s first four buckets); run `nen pr body-check` separately for the fifth
   > (missing-body-requirement) leg, since `nen pr ready` never asserts body content at all. See
   > `docs/ab/drive.md` § 2 for the full reproduction, filed as a defect against both verbs, not
   > routed around silently.

4. **Act through the right channel** — § 5.
5. **Poll in-shell** (`gh pr checks`, `gh pr view --comments`). Never a background primitive, never
   a scheduled wake-up: Kurapika has no App and no sweeper.
6. **Count the round**, mechanically — § 6. Five rounds on one PR is the cap
   (bankai-core's own `agents/_conventions.md`: *"max 5 build↔review rounds per PR, then escalate
   to the human"*); the sixth is an escalation, not a retry.

## 4. Readiness — the verb decides; the confirmation pass may only **veto**

A PR is ready **iff `nen pr ready` says `ready` AND `nen pr body-check` says every requirement is
satisfied.** Both are deterministic; neither is re-derived by eye. This is exactly
[`pr-state`](../pr-state/SKILL.md)'s own discipline — `drive` reuses it rather than reinventing it:

```bash
export GH_TOKEN=$(gh auth token)
nen pr ready <CODE>#<N> --repo <path> \
  --gates "$CLAUDE_PLUGIN_ROOT/contracts/bankai-core.gates.json" --explain
```

`--gates` anchored on `$CLAUDE_PLUGIN_ROOT`, never a bare relative path (`pr-state`'s own A/B proves
the `ENOENT` you get from any other cwd). A repo that ships its own `schemas/gates.json` needs no
`--gates` flag at all.

**Never re-derive readiness by eye.** Two approvals that predate the last push look exactly like
two that follow it on the page, and only one of those is Ready. `nen pr ready`'s verdict is the
current-head (`CON-16`) rule already applied.

**Then run the confirmation pass — and it is one-directional.** `nen pr ready --explain`'s own
printed caveats name exactly what the gate cannot decide (`CON-32(c)` "addressed" is approximated;
`CON-32(e)` channel-less findings in a review body have nothing for the unresolved-threads row to
count). So after a `ready` verdict, read the PR adversarially and ask what a deterministic gate
structurally cannot:

- Is every **summary-level** finding addressed — a reviewer's prose objection that never became an
  inline thread, so resolving threads never touched it?
- Does any thread carry a **reply promising a fix** whose commit was never pushed?
- Was a thread **resolved without a reply**? An inline comment is addressed by two acts — the
  on-thread disposition *and* the resolution.
- Does `nen pr body-check` pass (`## How to verify`, `CON-17`; the `changelog.d/` fragment where
  `CON-33(a)` requires one)?
- Does the diff still match the gate derived in § 2, and does it deliver what the issue it claims
  to close actually asked for?

**The asymmetry is the whole point:**

| `nen pr ready` + `body-check` say | Confirmation pass says | Verdict |
|---|---|---|
| both pass | agrees | **Ready** — stop at the gate |
| both pass | objects | **Not ready.** The objection *is* the next round's work |
| either fails | anything | **Not ready.** The pass never promotes; it only vetoes |

An inference that can override a deterministic gate *upward* is not a safety net — it is a second
gate with worse evidence.

## 5. Unblocking — the channel is decided by who authored the PR

> **Disclosure: the CI-agent branch below is structurally inapplicable to hatsu's own PRs.** A PR
> in `hatsu` itself is authored locally, on the maintainer's/Kurapika's own credentials — there is
> no CI builder in this repository to carry a `<!-- bankai agent=… run=… -->` stamp, so no hatsu PR
> can ever match the first branch's trigger. `nen wake fire`/`nen wake verify` are exercised in this
> port's own A/B (`docs/ab/drive.md` § 2.6, § 3) only against **bankai-core's** CI-authored objects
> (`zheref/bankai-core#925`, `#940`, both stamped by a CI builder), never against `hatsu` itself.
> Driving a `hatsu` PR always takes the second branch below (Kurapika authored it) or the third
> (conflicted).

**A CI agent authored it** (a `<!-- bankai agent=… run=… -->` stamp on the body or a commit): the
fix is that agent's to make. The channel is **`nen wake fire`, fired ALONE**:

```bash
nen wake fire --repo-slug <owner/name> --ref <CODE>-PR-#<N> --label bankai:wake/iterate --run
```

(`bankai:wake/iterate` is the real label name, read off bankai-core's own `schemas/labels.json`:
*"CON-26/CON-38 non-vote wake: re-fires a builder's own ITERATE on its open PR; edge-triggered."*)
`--run` is required — without it `nen wake fire` writes nothing (CON-38's dry-run-first
convention), which this port never exercises against bankai-core itself (mutating; contract
inspected only, per the shared brief's boundary — see `docs/ab/drive.md` § 3).

> ⚠️ **Never apply the label in the same breath as a comment.** Both dispatch runs into the same
> concurrency group seconds apart and the second **cancels the first's `probe`**, so `build` never
> starts and the wake dies silently (BC-IS-#554). If context must be added first: post the comment,
> **wait for its run to settle**, then fire the label. If the findings are already on the PR — and
> after any automated review round they are — fire the label alone and add nothing.

**Verify the wake reached the builder — mechanically, not by eyeballing `gh pr checks`:**

```bash
nen wake verify --repo-slug <owner/name> --now <ISO-8601> --author-pattern <ci-agent-login-regex>
```

Without `--run` this is **genuinely read-only** — verified live against the real bankai-core repo
(`docs/ab/drive.md` § 2): it scans open PRs whose author matches the pattern for a run that
concluded `action_required`/`startup_failure` with **no job executed**, which is exactly "a `probe`
that is `cancelled` with no `build` job" — a **failed** wake, not an attempt, and must be re-fired
rather than counted. `--run` additionally auto-redrives what can safely be redriven and posts a flag
comment otherwise — mutating; never fired at bankai-core by this port (contract inspected only).

**Kurapika authored it** (local, on the maintainer's creds): address it yourself. Reply on each
thread with the disposition — the fix SHA, or a cited pushback — **and** resolve it. Push the fix.
Re-request review where a round is owed, on the maintainer's own user token (a bot token silently
no-ops here):

```bash
nen pr request-reviews --target <owner/name> --pr <n> --add-reviewers <a,b>
```

Mutating; contract inspected only (§ 3, `docs/ab/drive.md`).

**It is conflicted:**

```bash
nen pr cascade-main --repo <path> [--trunk main]
```

Merges (never rebases) the trunk in and pushes on a clean merge; reports a conflict rather than
resolving it. Mutating; contract inspected only. A conflicted PR gets *no checks at all*, which
reads as "clean" rather than "broken". **`nen wake fire` is a known no-op here — do not re-fire it
and wait.** A `CONFLICTING` PR dispatches no `pull_request`-family event, including the `labeled`
event the wake label needs (BC-IS-#798); it is also edge-triggered, so a label already present from
an earlier failed attempt must be removed, then re-applied, before it can even be tried again — and
on a still-conflicted PR, that still will not help. Cascade `main` in instead.
`copilot-sweeper.yml`'s `conflict_guard` job (bankai-core, unchanged infrastructure, outside `nen`'s
scope) auto-detects a `dirty` PR and redrives a `kisuke-bankai[bot]`-authored PR only; for every
other author it still only leaves a flag comment, and cascading `main` in yourself is faster than
waiting on it.

**Never** cast a `request_changes` review to move a PR. Kurapika runs on the maintainer's
credentials, so GitHub records the vote as **theirs** — manufacturing a governance vote on a PR
they have not read (`CON-26`). This holds even when the finding is real and even when it is the
only path you can see. If `nen wake fire` cannot wake that builder, **that is a machinery defect to
file** (§ 6), never a reason to reach for a vote.

## 6. When it will not move — the escalation ladder

Fixed, in order, with nothing skipped. **Check `mergeable_state` first** (row 1 of `nen pr ready
--explain`'s conjunct table) — a `dirty` PR makes step 1 unsatisfiable by construction (§ 5), so
diagnose that before spending a wake attempt on it:

1. **Re-fire `nen wake fire`, alone.** Verify with `nen wake verify` (§ 5) that a `build` job ran.
   If the PR is `dirty`, skip straight to § 5's cascade instead.
2. **A second verified wake**, if the first produced no commit.
3. **Staleness is now a computed verdict, not a hand-count.** Log every wake attempt as it happens
   — `{ "at": "<ISO>", "noCommit": <bool> }` — into the same `docs/Loop/<run-id>/` transcript § 9
   already asks for, then feed it straight to the gate:
   ```bash
   nen pr staleness --wakes-from <path-to-that-log> --last-activity <ISO> --now <ISO> --ready
   ```
   Verified live (`docs/ab/drive.md` § 2): with `--ready` given, a stale PR reports `merge
   PERMITTED (stale + Ready)`; without it, `stale, but NOT Ready -- no merge is permitted; a stale,
   not-ready PR is still owned by its author`. **`nen pr staleness`'s own `mergePermitted: true` is
   NOT authority for this skill to merge anything.** `drive` carries no merge delegation under any
   circumstance (§ 7, § 10) — the maintainer's own gate stands regardless of what the verb reports
   as permitted elsewhere in the system. Use the verb only for the `stale` boolean and its two
   printed conjuncts (verified-no-commit-wake count, idle minutes); never act on `mergePermitted`.
4. **After 2 verified no-commit wakes and ≥60 minutes since the author's last activity** (i.e.
   `nen pr staleness` reports `stale: true`): **diagnose.** Name what is actually stuck — a
   swallowed wake (`nen wake verify` found a run concluding `action_required` with 0 jobs), a
   `dirty` PR (zero `build` runs at all — the label was never consumable), a reply-only builder
   mode, a red check the builder cannot fix, a required check that never reports.
5. **File the defect** with [`hatsu:file`](../file/SKILL.md) — routed by scope, with the run links
   and both wake attempts as evidence.
6. **Stop at G5** with the board: what is stuck, what was tried, the filed issue, and the options
   with a recommendation.

**Local authorship is the exception, not step 4.5.** Take authorship only where the work is
something CI structurally cannot do, and state in the PR body why authorship moved locally.

⚠️ **A wake that was cancelled never attempted anything.** Do not count it toward the two in
`nen pr staleness`'s `--wakes-from` log, and do not build a staleness finding on it.

## 7. Authority — `drive` carries **no** routing or release delegation

A human-invoked skill's delegation is bounded by what that skill needs, and `drive` needs almost
nothing: it acts on a PR that already exists, authored by an agent that has already been routed and
released.

- **Permitted:** `nen wake fire` — a non-vote wake, never a routing decision.
- **Not permitted, ever:** any G1 mode label, any merge, any review vote, any routing/release
  label. If driving this PR turns out to need one, that is `hatsu:build`'s job (lands with a later
  port of hatsu#2) — say so and stop rather than reaching for it here.
- **Log every label application** (object, label, time) in the stop, exactly as a named run does.

## 8. The stop

**Reaching the gate is a gate event.**

```bash
nen stop --who Kurapika --gate <G2|G4> [--notified] efforts.md
```

Paste the banner verbatim — verified live end to end (`docs/ab/drive.md` § 2), a real `ready`
bankai-core PR (`BC-PR-#940`) renders:

```
| Effort                                                                 | Refs                   | Status (gate) | Needs                   |
| ----------------------------------------------------------------------- | ---------------------- | ------------- | ----------------------- |
| A fifth shell clause for a frozen-line patch, expiring with the freeze | BC-IS-#937, BC-PR-#940 | 🟢 (G4)       | Merge — maintainer only |
```

Then publish the gate board as an Artifact and link it — the same `nen board build`/`nen board
render` machinery [`backlog-state`](../backlog-state/SKILL.md) uses, fed this one row. The ask is a
**`MERGE`** kind — the verdict says everything, so it takes no options:

```
MERGE — BC-PR-#940 is CON-32-Ready at G4
why:   nen pr ready: ready · nen pr body-check: 2/2 satisfied · the confirmation pass found
       nothing the gate missed.
```

The chat around it is **about five lines**: banner, the gate and the one ask, the board link.
Anything longer is the prose the board exists to end.

**A stop that is not the gate** — an escalation (§ 6), or a decision the PR surfaces — is `G5` with
a `DECIDE` or `DO` ask carrying the question, lettered options, the ⭐ recommendation and what tips
it.

**No banner on a progress turn.** A board appearing *is* a gate event; a board not appearing means
what silence has always meant.

## 9. Resuming

The run is **resumable by re-invocation**, not by remembered state. `hatsu:drive <CODE>#<PR> to
<G2|G4>` run again re-fetches everything and re-decides from live evidence. Write what you learned
— diagnoses, wake attempts with their run links, label applications — to `docs/Loop/<run-id>/` so a
fresh session does not re-derive it, but **never trust that file over a fetch**: it is a
transcript, not a cache. The wake-attempt log doubles as § 6's `nen pr staleness --wakes-from`
input — keep it in the same shape (`{ at, noCommit }`) so it feeds the verb directly.

Say when the run **starts** and when it **ends**.

## 10. Hard limits

- **Never merges** — not `main`, not a chore branch, and never on the strength of `nen pr
  staleness`'s own `mergePermitted` field (§ 6). This skill's terminus is *ready*, full stop.
- **Never self-reviews, never impersonates an automated reviewer, never casts `request_changes`.**
- **Never force-pushes, never `--no-verify`, never pushes `main`.**
- **Never applies a routing, release or G1 mode label** (§ 7).
- **Never reports readiness it did not get from `nen pr ready` + `nen pr body-check`**, and never
  promotes a `not-ready` verdict on inference.
- **Never counts an unverified wake** toward the escalation ladder, and never fabricates a
  `nen pr staleness --wakes-from` entry to manufacture a stale verdict.
- **Never exceeds the 5-round cap** on one PR — the sixth round is an escalation.
- **Never calls `nen pr fetch` or `nen pr next-blocker`** — both are reproduced broken against real
  bankai-core PRs (§ 3) and are filed as defects, not routed around by hand.
