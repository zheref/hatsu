# A/B evidence — `senkei` (zheref/hatsu#2)

Port of `claude/skills/senkei/SKILL.md`: inventory one consuming product repo's own backlog, classify
each effort, and drive every open PR to `CON-32`/G2-readiness. Scope per the issue: mechanics onto
`nen repo inventory`, `nen effort classify`, `nen run rerun-failed`; readiness composed from
`nen pr ready` (unchanged pointer, shared with `hatsu:pr-state`).

Run: 2026-09-02 (this session). `nen` `0.1.0` (`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`).
`gh` authenticated as `zheref` (`GH_TOKEN=$(gh auth token)` exported before every `nen` call that
reaches GitHub, per the shared brief — `nen` never picks a token up ambiently).

**Everything below ran read-only, against real repositories, with one narrow exception (§ 5) that
was itself a read-only-safe refusal probe.** No local checkout of KroApple or KroAndroid exists on
this machine (checked: `C:\Users\zhere\Code\WebStorm\Claude\` has no `Kro*` directory) — both
consumer repos are private but readable with this session's token, so every live call below is
**API-only** against the real `zheref/KroApple`, plus one call against the real `zheref/hatsu`
(§ 5) and reads of the frozen `zheref/bankai-core` registry (`git show`, per the ground rules).
Nothing was labelled, merged, pushed, commented on, or opened. `nen run rerun-failed` (§ 5) was
invoked exactly once, against a real run with zero failed jobs, which is why it refused rather than
rerunning anything — see that section for why this is a safe, read-only-equivalent probe rather
than an exercised mutation.

---

## 1. Command mapping table

| # | Old (prose) | New (`nen`) |
|---|---|---|
| 1 | `hatsu:senkei <repo>` parsed and validated by hand (no grammar tool used at all in the old skill) | `nen parse senkei --grammar "<repo>" --line "<input>"` — verified live, § 2.1 |
| 2 | "Every open epic and its child issues... every live `integration/*` branch, with ahead/behind vs. trunk... every open PR" — hand-assembled via unspecified `gh issue list` / `gh api repos/.../branches` / `gh pr list` calls, cross-referenced by eye | `nen repo inventory --target <owner/name> --epic-label <label> --integration-prefix <prefix> --trunk main` — one call, one JSON shape, verified live against the real `zheref/KroApple` (§ 3.1) |
| 3 | The five-class taxonomy (delivering/building/stalled/queued/idle) reasoned by eye per row, from labels + branch/PR presence | `nen effort classify --input <rows.json>` — mechanical, verified live across 14 constructed rows plus the real KroApple epics (§ 3.3–3.5); returns a **sixth** class (`undecidable`) the old prose never named |
| 4 | "Re-run the failed job (`gh run rerun <id> --failed`)" — a literal raw `gh` invocation in the old skill's own prose | `nen run rerun-failed --target <owner/name> --run-id <n>` — the verb's own `--help` names this "senkei's dead-reviewer recovery"; refusal shape verified live against a real `zheref/hatsu` run (§ 5.1), affirmative path not exercised (mutating, no dry-run mode) |
| 5 | Readiness "decided by `scripts/pr_ready_gate.sh --verdict <PR>`" | `nen pr ready` via [`hatsu:pr-state`](../../claude/skills/pr-state/SKILL.md)'s pointer — unchanged; spot-confirmed live against a real `zheref/KroApple` PR with no gates file of its own (§ 4.1–4.2), a shape `pr-state`'s own bankai-core-only A/B never had to test |
| 6 | Object references (`KP-IS-#178`, `KP-PR-#509`) typed by hand | `nen ref format --code KP --kind IS\|PR --number <n> [--state <s>] [--url <u>]` — verified live (§ 6.1), unchanged from `backlog-state`'s own confirmation of this verb |
| 7 | "Use the same unblock channel as `backlog-loop`: `bankai:wake/iterate`, fired ALONE" — no raw command given, delegated to the sibling skill's own prose | **Not mechanized in this port.** `nen wake fire` exists and matches this exact remove-then-reapply pattern, but is outside this port's declared Scope (the issue names only `nen repo inventory`, `nen effort classify`, `nen run rerun-failed` for `senkei`); kept as prose, forward-referencing `backlog-loop`/`drive` (neither landed yet) — § 7 residue |

**Count.** Before: **four** raw/improvised steps in the old skill's own text — the invocation split,
the backlog enumeration, the five-class reasoning, and the literal `gh run rerun <id> --failed`
prose (the fifth, readiness, was already a script in the old skill, unchanged in shape). After:
**four** single `nen` verb calls replace them (`parse`, `repo inventory`, `effort classify`, `run
rerun-failed`), plus the pre-existing `pr ready`/`ref format` pointers this skill shares with every
other port. What remains prose: the `stageLabels`/`modeLabelPresent` reshape's own judgment call
(§ 3), the Ready/not-Ready narrative and escalation reading (§ 4), the wake-unblock channel (§ 7,
out of this port's declared Scope), and the closing table's synthesis.

---

## 2. Invocation grammar

### 2.1 — `nen parse senkei`, live

```
$ nen parse senkei --grammar "<repo>" --line "KroApple"
repo: KroApple

$ nen parse senkei --grammar "<repo>" --line "zheref/KroApple"
repo: zheref/KroApple

$ nen parse senkei --grammar "<repo>" --line ""
nen parse: <repo> is required and the line does not supply it.

Corrected line:
  senkei <repo>
(exit 2)
```

**Works cleanly, unlike `backlog-state`'s own grammar.** `backlog-state`'s `<repo>[@<gate>]`
template hit a verified defect where the `[ ... ]` bracketed clause is swallowed into a preceding
single slot (`docs/ab/backlog-state.md` § 3). `senkei`'s own grammar has no bracketed clause at
all — a single mandatory slot — and the defect does not reproduce here. This is a genuine
mechanization, not a residue.

---

## 3. `nen repo inventory` and `nen effort classify` — live, against the real `zheref/KroApple`

### 3.1 — the live inventory call

No local KroApple checkout exists; `nen repo inventory` needs none — it reaches GitHub directly via
`--target`.

```
$ export GH_TOKEN=$(gh auth token)
$ nen repo inventory --target zheref/KroApple --epic-label "bankai:epic" \
                     --integration-prefix "integration/" --trunk main
epics: 7
  #178 Epic — Milestone celebrations + haptics (reward-claim & streak) -- 6 child(ren)
    ... (4 closed, 2 open)
  #27  [EPIC] Security, Privacy & Observability posture ... -- 6 child(ren)
    ... (6 open)
  #20  [Epic][CHR-019] JIRA Ticket Import (Read-Only) ... -- 6 child(ren)
    ... (6 open)
  #17  [CHR-016] Streak Tracker ... [epic] -- 7 child(ren)
    ... (7 closed)
  #15  [Epic] Earn History ... -- 6 child(ren)
    ... (6 open)
  #13  [Epic][CHR-012] Focus Mode ... -- 5 child(ren)
    ... (5 open)
  #5   [Epic] Smart Day Composer ... -- 6 child(ren)
    ... (6 open)
integration branches: 4
  integration/epic-17   +38/-236 vs trunk
  integration/epic-178  +16/-227 vs trunk
  integration/epic-193  +0/-152  vs trunk
  integration/epic-213  +0/-116  vs trunk
open PRs: 1
  #509 -> main  fix(do): stabilize Endeavor lane spacing
(exit 0)
```

7 epics, 34 children (mix of open/closed), 4 live integration branches, 1 open PR — one call,
matching `gh issue list --label bankai:epic --state open` (independently re-run, § 3.2) exactly in
epic count and numbers. `--json` returns the same content typed (`epics[].epic`,
`epics[].children[]`, `integrationBranches[]`, `openPrs[]`) — confirmed by piping to a file and
inspecting both ends.

### 3.2 — the `idle` finding, found on real data

```
$ gh issue view 193 --repo zheref/KroApple --json number,title,state,labels
{"number":193,"state":"CLOSED","title":"Epic — Overdue notifications: ...","labels":[...,"bankai:epic",...]}

$ gh issue view 213 --repo zheref/KroApple --json number,title,state,labels
{"number":213,"state":"CLOSED","title":"Epic — Debug Window: DB-target switcher ...","labels":[...,"bankai:epic",...]}
```

Both epics named by `integration/epic-193` and `integration/epic-213` are **closed**, yet both
branches are still alive per § 3.1's inventory (`0 ahead / -152` and `0 ahead / -116` vs trunk —
fully merged into trunk already, nothing left to land, and still not deleted). This is exactly
`SKILL.md` § 3's **idle** class, confirmed on the live target repo rather than constructed — a real
cleanup item this pass surfaces.

### 3.3–3.5 — `nen effort classify`, the `stageLabels`/`modeLabelPresent` finding

Constructed 14 rows total (`classify-rows.json`, `classify-probe2.json`–`classify-probe4.json`,
not committed — scratch files in the worktree, deleted before commit) spanning every class the
verb's `--help` documents, seeded from real KroApple objects where possible.

**3.3 — feeding the mode label into `stageLabels` misclassifies a real epic:**

```
$ cat classify-rows.json   # (excerpt) KP-IS-#17-epic, KP-IS-#178-epic:
{"kind":"epic","issueState":"open","stageLabels":["bankai:stage/ready-for-bankai"],
 "modeLabelPresent":true,"hasPr":false,"integrationBranchAlive":true, ...}

$ nen effort classify --input classify-rows.json
building
  carries the released stage label 'bankai:stage/ready-for-bankai'; a branch exists but no PR yet
building
  carries the released stage label 'bankai:stage/ready-for-bankai'; a branch exists but no PR yet
```

Both `KP-IS-#17` and `KP-IS-#178` are real, live epics: G1-approved (`bankai:stage/ready-for-bankai`)
with an alive integration branch and no delivery PR, and neither has actually released a child to
`bankai:stage/building` yet (`#178`'s two open children, `#190`/`#335`, both carry only
`bankai:stage/researched`). The old skill's own taxonomy calls this **queued**. Feeding the mode
label into `stageLabels` (as it literally appears in GitHub's label list) reports `building`
instead — wrong for both real objects.

**3.4 — excluding the mode label from `stageLabels` reports the correct class:**

```
$ cat classify-probe4.json   # epic17-correct, epic178-correct:
{"kind":"epic","issueState":"open","stageLabels":[],"modeLabelPresent":true,"hasPr":false,
 "integrationBranchAlive":true, ...}

$ nen effort classify --input classify-probe4.json
queued
  G1-approved (a mode label was picked) but not yet released with a stage label
queued
  G1-approved (a mode label was picked) but not yet released with a stage label
```

**Same two real epics, correct class, once the mode label is excluded from `stageLabels` and
carried only in `modeLabelPresent`.** Confirms the reshape rule `SKILL.md` § 3 states: mode labels
and stage-progression labels are two different pieces of caller data even though GitHub ships them
under the same `bankai:stage/*` prefix, and `queued` is reachable ONLY when `stageLabels` is empty
— an alive integration branch does not upgrade it to `building` on its own (contrast the previous
paragraph, same branch-alive flag, different `stageLabels` content, different class).

**3.5 — a pre-G1 label reports `stalled`, not `queued` — and a bare row reports a class the old
taxonomy never named:**

```
$ cat classify-probe2.json   # probe-queued-b, probe-nolabels:
{"stageLabels":["bankai:stage/researched"],"modeLabelPresent":false,"hasPr":false, ...}
{"stageLabels":[],"modeLabelPresent":false,"hasPr":false,"integrationBranchAlive":false, ...}

$ nen effort classify --input classify-probe2.json
stalled
  carries 'bankai:stage/researched' -- released, but no branch or PR was ever opened
...
undecidable
  no stage label, no mode label, no PR, no live integration branch -- nothing here places it in the taxonomy
```

`researched` (pre-G1, "awaiting G1 approval" per KroApple's own label description) reports
`stalled` when fed into `stageLabels` — the verb treats ANY non-empty `stageLabels` as "released,"
with no notion of a pre-G1 state at all. **`SKILL.md` § 3's rule follows directly: an issue still
at `idea`/`researched`/`triage` is outside this skill's five/six-class universe and must not be fed
to `nen effort classify` at all** — report it separately, never as `stalled`. And a fully bare row
(real shape: a freshly filed, untriaged issue) reports **`undecidable`** — a sixth class the old
skill's own table never named, confirmed not silently defaulted into `queued` or `idle`.

**Full behaviour matrix confirmed live** (`kind` did not change any outcome tested):

| stageLabels | modeLabelPresent | hasPr | branch alive | → class |
|---|---|---|---|---|
| `[]` | `false` | `false` | `false` | `undecidable` |
| `[]` | `true`  | `false` | `false` | `queued` |
| `[]` | `true`  | `false` | `true`  | `queued` (branch alive does NOT upgrade it) |
| `["researched"]` (or any non-`building` progression label) | any | `false` | `false` | `stalled` |
| `["building"]` | any | `false` | `false` | `stalled` |
| `["building"]` | any | `false` | `true`  | `building` |
| `["building"]` | any | `true` (open, not delivery) | any | `building` |
| any | any | `true` (`prIsDelivery:true`) | any | `delivering` |
| epic, `issueState:"closed"`, branch alive | any | any | `true` | `idle` |
| 2 stage-family labels at once | any | any | any | `state-machine-violation` |

---

## 4. `nen pr ready` against a real product-repo PR with no gates file

### 4.1 — the refusal, confirmed against the real `zheref/KroApple`

```
$ gh api repos/zheref/KroApple/contents/schemas/gates.json
{"message":"Not Found", ...} (404)
$ gh api repos/zheref/KroApple/contents/schemas/repos.json
{"message":"Not Found", ...} (404)
$ gh api repos/zheref/KroApple/contents/schemas
{"message":"Not Found", ...} (404)
```

KroApple ships **no `schemas/` directory at all** — confirmed, not assumed. So:

```
$ nen pr ready 509 --gh-repo zheref/KroApple --explain
nen: no reviewer identities. This gate never falls back to a built-in reviewer set: a binary that
guessed the reviewers would judge this repository against another one's and report success. Give
it one of: --gates <path>, a 'schemas/gates.json' in the target repository (looked for at
'<cwd>/schemas/gates.json'), or --reviewers a,b,c.
(exit 2)
```

Confirms `pr-state`'s own documented refusal shape (`docs/ab/pr-state.md` § 2, filed against
bankai-core) reproduces identically against a **different**, real repository with genuinely no
gates file anywhere — this is a general property of the verb, not a bankai-core-specific fixture
gap. `SKILL.md` § 4's rule follows: **never** point this refusal at `contracts/bankai-core.gates.json`
for a non-bankai-core repo — that file's reviewer identities are bankai-core's own and would judge
a different repo against the wrong vocabulary.

### 4.2 — a real verdict, with KroApple's own identities supplied

KroApple's own `bankai:stage/in-review` label reads *"Sasuke and Tenma reviewing"* — the same
review-pair bots bankai-core uses (both are Bankai-CI consumers reusing bankai-core's own
`sasuke-review.yml`/`tenma-review.yml`/`bisky-review.yml`, confirmed against bankai-core's own
`schemas/repos.json` `consumes` list for this repo, § 6.1). Supplying them explicitly:

```
$ nen pr ready 509 --gh-repo zheref/KroApple --reviewers sasuke,tenma,copilot \
               --approvers sasuke,tenma --explain
zheref/KroApple#509: not-ready: required checks reported but are not all green (CON-32a)

  head c8283f2b9bad618dea222f6f2b55503c56646605 · reviewers sasuke,tenma,copilot · approvers sasuke,tenma
  policy bounded · delivery PR no · identities from --reviewers (reduced: no review checks, no carve-outs)

  1  ready       CON-42/1          Mergeable
  2  FAILED      CON-32(a)         Every reported check green, on the latest run per check name
        └ not-ready: required checks reported but are not all green (CON-32a)
  3  unevaluated CON-32(b)         No configured reviewer's requested round has stalled
  4  unevaluated CON-32(b)         No configured reviewer's round owed at the current head
  5  unevaluated CON-32(b)/CON-16  Every approving reviewer's latest round is an APPROVE at the current head
  6  unevaluated CON-32(d)         Zero unresolved review threads
(exit 1)
```

Cross-checked against the PR's own live check rollup
(`gh pr view 509 --json statusCheckRollup`): several checks in the rollup carry no `conclusion`
(still queued/running) alongside a run of `SUCCESS`/`SKIPPED` entries — a genuinely non-green
rollup, matching the verdict exactly. `KP-PR-#509` is `not-ready` for a real, verifiable reason,
not a guess.

**Verdict parity for the core gate itself** (mergeable/checks/reviewer-round/thread conjuncts) was
already proven across bankai-core's live estate by nen's shadow window
(`docs/evidence/shadow-window-p1.md` in zheref/nen, cited per the shared brief rather than
re-proven); this section's own contribution is narrower and new — confirming the **no-gates-file**
refusal and the **explicit-`--reviewers`** path both behave correctly against a *different*
repository, which `pr-state`'s bankai-core-only A/B never had occasion to test.

---

## 5. `nen run rerun-failed` — refusal shape only, against real `zheref/hatsu`

Per the shared brief: this verb **mutates** (re-runs workflow jobs) and carries no dry-run mode
(unlike `nen label apply`/`nen wake fire`/`nen labels sync`, all of which default to a logged
no-op). `zheref/hatsu` has no `.github/workflows/` directory today, so — as instructed — this was
contract-inspected via `--help` first, then probed for the refusal shape only, against a target
where nothing could actually be mutated by the call:

```
$ gh api repos/zheref/hatsu/actions/runs --jq '.total_count'
7
$ gh api repos/zheref/hatsu/actions/runs --jq '.workflow_runs[] | {id, conclusion}'
{"id":33579774559,"conclusion":"success"}
... (all 7, all "success" -- zero failed jobs across the board)

$ nen run rerun-failed --target zheref/hatsu --run-id 33579774559
could not rerun zheref/hatsu's run 33579774559: run 33579774559 cannot be rerun; This workflow run
cannot be retried
(exit 1)
```

Every one of hatsu's 7 recorded runs (`Running Copilot Code Review`, GitHub's own built-in check)
concluded `success` — nothing failed, so `gh run rerun <id> --failed` (which this verb wraps
exactly, per its own `--help`) has nothing to rerun and refuses cleanly. **Nothing was mutated**:
the refusal happens before any job is touched. This confirms the verb's error-surface shape
(`could not rerun <target>'s run <id>: <gh's own reason>`) live, without exercising the affirmative
"actually reran a failed job" path against any repository — that path is not exercised in this
port, per the shared brief's mutation boundary (bankai-core is frozen and off-limits for mutation;
a real consumer repo's PR is not this session's to mutate either, and hatsu itself has no failing
job to safely rerun).

---

## 6. Supporting verbs, unchanged pointers

### 6.1 — `nen repo resolve` / `nen repo scanario`, against bankai-core's registry

KroApple ships no registry of its own (§ 4.1); the registry that names its product code lives in
bankai-core's own `schemas/repos.json`:

```
$ nen repo resolve KP --repo <bankai-core checkout>
zheref/KroApple  (KP)  via code

$ nen repo scenario --repo <bankai-core checkout> --target zheref/KroApple
swiftui-tca-uzf-v2
```

Matches bankai-core's frozen registry read directly (`git -C bankai-core show
v0.11.3:schemas/repos.json`): `KP` → `zheref/KroApple`, `consumes` listing
`sasuke-review.yml`/`tenma-review.yml`/`bisky-review.yml` among others — the basis for § 4.2's
reviewer-identity choice.

### 6.2 — `nen ref format`

```
$ nen ref format --repo <bankai-core checkout> --code KP --kind IS --number 178 --state open \
                 --url https://github.com/zheref/KroApple/issues/178
📄 [KP-IS-#178](https://github.com/zheref/KroApple/issues/178)

$ nen ref format --repo <bankai-core checkout> --code KP --kind PR --number 509 --state open \
                 --url https://github.com/zheref/KroApple/pull/509
🔀 [KP-PR-#509](https://github.com/zheref/KroApple/pull/509)
```

Unchanged from `backlog-state`'s own confirmation of this verb (`docs/ab/backlog-state.md` § 2.8) —
re-run here only to confirm it resolves a **different** product code (`KP`, not `BC`) correctly.

---

## 7. Residue

- **The unblock channel (`bankai:wake/iterate`, fired ALONE) is not mechanized in this port.**
  `nen wake fire --repo-slug <owner/name> --ref <object-ref> --label <name> [--comment <text>]
  [--run]` exists and matches this exact remove-then-reapply pattern (confirmed via `nen wake
  --help`), but zheref/hatsu#2's own Scope line for `senkei` names only `nen repo inventory`, `nen
  effort classify`, `nen run rerun-failed` — `nen wake fire` is not in it, and the two skills whose
  Scope lines DO name `nen wake fire | verify` (`backlog-loop`, `drive`) are not landed on `main`
  yet. `SKILL.md` § 4 keeps the old skill's own prose rule (fire alone, never with a comment in the
  same breath, verify the `build` job ran) unchanged, forward-referencing both siblings as "lands
  with a later port of hatsu#2" rather than introducing a verb outside this port's declared scope.
- **Judgment kept, per the shared brief's boundary list**: the Ready/not-Ready narrative around a
  verdict (§ 4), the escalation reading when a PR is stuck, and the closing status table's shape —
  `nen` computes and formats; deciding what a row means to the maintainer stays this skill's.
- **No PR-diff-fetch verb, same gap `backlog-state` already filed** (`docs/ab/backlog-state.md`
  § 4/5) — not relevant to this skill's own Scope (senkei never derives a gate from a diff), noted
  only because it would recur if a future port asked this skill to.
- **`nen pr fetch`'s live crash** (`docs/ab/backlog-state.md` § 2.5) was not re-tested here — this
  skill never calls it, for the same reason `backlog-state` stopped calling it.
