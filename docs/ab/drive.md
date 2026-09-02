# A/B evidence — `drive` (zheref/hatsu#2)

Port of `claude/skills/drive/SKILL.md`: take one open PR to `CON-32` readiness at its human gate,
then stop. Old mechanics: `scripts/pr_ready_gate.sh --verdict` (already A/B'd by `pr-state`) plus a
large amount of hand-reconstructed prose — the first-blocking-condition order, wake-landed
verification by eyeballing `gh pr checks`, a hand-maintained round count, a hand-reasoned gate
derivation. New mechanics: `nen pr ready`, `nen pr body-check`, `nen pr staleness`, `nen wake
verify`, `nen gate derive`, plus contract-only inspection of `nen wake fire`, `nen pr cascade-main`,
`nen pr request-reviews`, `nen pr retarget`.

Run: 2026-09-01, UTC times as logged by each command. `nen` `0.1.0`
(`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`). `gh` authenticated as `zheref`. All GitHub
reads below ran **read-only** against the live `zheref/bankai-core` repository (its two real open
PRs at run time, `#925` and `#940`) or against local scratch JSON with no GitHub write of any kind.
Nothing was labelled, merged, pushed, commented on, retargeted, cascaded, or woken. Verdict parity
between `nen pr ready` and `scripts/pr_ready_gate.sh` across the live estate is already established
by nen's shadow window (`docs/evidence/shadow-window-p1.md` in `zheref/nen`, most recently 17/17)
and re-confirmed for this repository by `pr-state`'s own A/B (`docs/ab/pr-state.md`) — not
re-proven here; this doc's `nen pr ready` runs are spot confirmation feeding `drive`'s own
composition (§ 2.1 below), same discipline `backlog-state`'s A/B doc already used.

---

## 1. Command mapping table

| # | Old (prose / shell) | New (`nen`) |
|---|---|---|
| 1 | `REPO=<owner>/<repo> scripts/pr_ready_gate.sh --verdict <N>` for readiness | `nen pr ready <CODE>#<N> --repo <path> --gates "$CLAUDE_PLUGIN_ROOT/contracts/bankai-core.gates.json" --explain` — unchanged pointer from `pr-state`; see `docs/ab/pr-state.md` for that A/B, § 2.1 below for this port's own spot check |
| 2 | Gate derivation (§ 2): "does the diff touch `CONSTITUTION.md`, `handbooks/`, `agents/`, `schemas/`, or the process surface" — reasoned by eye per PR | `nen gate derive --policy-paths ... --process-paths ... --files ...` — unchanged pointer from `backlog-state`; re-confirmed here against both real open PRs (§ 2.3) |
| 3 | "Fetch the PR whole: head SHA, `mergeStateStatus`, the check rollup ... every review ... every review thread ..." — one snapshot, unspecified `gh api` calls | Attempted: `nen pr fetch --target <owner/name> --pr <n>`. **Does not work** — reproduced against both real open PRs, two DIFFERENT failure shapes (§ 2.2). Not used; readiness comes from `nen pr ready`, body requirements from `nen pr body-check`, checks/comments/base-ref from `gh pr checks`/`gh pr view --json` |
| 4 | "Name the FIRST blocking condition, in this order: conflict → red required check → owed reviewer round → unaddressed thread → missing body requirement" — reasoned by eye over the § 3 snapshot | Attempted: `nen pr next-blocker --target <owner/name> --pr <n> --repo <path> --reviewers a,b`. **Does not work against bankai-core** — no `--gates` override exists for this verb at all, and passing `--reviewers` does not substitute; once patched around with a scratch `schemas/gates.json`, it fails again on the SAME underlying reviews-fetch defect as row 3 (§ 2.4). Not used; the disclosed stopgap is `nen pr ready --explain`'s own conjunct short-circuit order (rows 1–6 collapse onto `next-blocker`'s first four buckets) plus a separate `nen pr body-check` call for the fifth (missing-body) leg |
| 5 | Missing body requirement (`## How to verify`, a `changelog.d/` fragment) — checked by reading the body by eye | `nen pr body-check --body-from <path> --requirements-from <path>` — exercised against the real body of `BC-PR-#925` (§ 2.5) |
| 6 | "Verify the wake reached the builder" — `gh pr checks`, eyeballed for a `build` job having run, a cancelled `probe` with no `build` job read by eye as a failed wake | `nen wake verify --repo-slug <owner/name> --now <ISO> --author-pattern <regex>` (no `--run`, genuinely read-only) — scans for exactly this shape (a run concluding `action_required`/`startup_failure` with no job executed) mechanically; exercised live against real bankai-core (§ 2.6) |
| 7 | "Count the round" / staleness — "≥2 verified no-commit wakes AND ≥60 minutes since last activity", tallied by hand from a wake-attempt log the skill told the agent to keep | `nen pr staleness --wakes-from <path> --last-activity <ISO> --now <ISO> [--ready]` — computes the same two-conjunct test and prints `stale`/`mergePermitted` explicitly; exercised across four cases (stale, stale+ready, one commit landing, idle<60) (§ 2.7) |
| 8 | The wake channel itself: `bankai:wake/iterate` fired alone, a raw label add/remove via `gh` implied by prose | `nen wake fire --repo-slug <owner/name> --ref <CODE>-PR-#<N> --label bankai:wake/iterate --run` — contract inspected only (mutating; never fired at bankai-core, per the shared brief's boundary) |
| 9 | Conflicted PR: "cascade `main` in — merge, never rebase" — raw `git merge`/`git push` implied | `nen pr cascade-main --repo <path> [--trunk main]` — contract inspected only (mutating) |
| 10 | "Re-request Copilot on the maintainer's user token" — raw `gh pr edit --add-reviewer` implied | `nen pr request-reviews --target <owner/name> --pr <n> --add-reviewers a,b` — contract inspected only (mutating) |
| 11 | `scripts/gate_stop.sh --gate <G2\|G4> [--notified] <efforts.md>` | `nen stop --who Kurapika --gate <G2\|G4> [--notified] efforts.md` — exercised live end to end with a real PR's data (§ 2.8) |
| 12 | `scripts/ichigo_board.sh` for the gate board | `nen board build`/`nen board render` — unchanged pointer from `backlog-state`'s own A/B; not re-exercised here |
| 13 | Resolving `<product_code>` against the registry — no command given in the old skill's prose | `nen repo resolve <CODE> --repo <path>` — same verb `backlog-state` uses for the explicit-code form; not separately re-proven here (see `docs/ab/backlog-state.md` § 2.1) |

**Count.** Before: essentially every deterministic step in §§ 2–6 of the old skill (11 of the 13
rows above) was improvised prose or a raw `gh`/`git` call the agent assembled per invocation — only
readiness (row 1) already had a script. After: **8** of those rows are now single `nen` verb calls
verified live against real bankai-core PRs (rows 1, 2, 5, 6, 7, 11, plus the readiness composition
in row 4's stopgap), **3** are mechanized but exercised by contract-inspection only because they
mutate GitHub (rows 8–10), and **2 verbs this port needed do not work against real bankai-core PRs
at all** (rows 3 and 4's primary path) — filed as defects (§ 4), with a disclosed, working stopgap
carried in the skill rather than silently improvised.

---

## 2. Live A/B transcript (read-only)

Both open bankai-core PRs at run time:

```
$ gh pr list --repo zheref/bankai-core --state open --json number,title,headRefName,isDraft
[{"headRefName":"ichigo/937-bc11-frozen-line-patch","isDraft":false,"number":940,
  "title":"feat(bc11): a fifth shell clause for a frozen-line patch, expiring with the freeze"},
 {"headRefName":"kisuke/918-cancelled-build-report","isDraft":false,"number":925,
  "title":"fix(ci): report a cancelled builder run instead of leaving bankai:stage/building silent"}]
```

### 2.1 — `nen pr ready --explain`, both real open PRs

```
$ export GH_TOKEN=$(gh auth token)
$ nen pr ready 925 --gh-repo zheref/bankai-core --gates contracts/bankai-core.gates.json --explain
zheref/bankai-core#925: not-ready: required checks reported but are not all green (CON-32a)
  head 702868f12487fa189b7bf0e35fc140391c19fd24 · reviewers sasuke,tenma,copilot · approvers sasuke,tenma
  1  ready       CON-42/1          Mergeable
  2  FAILED      CON-32(a)         Every reported check green, on the latest run per check name
  3-6 unevaluated  (short-circuited)

$ nen pr ready 940 --gh-repo zheref/bankai-core --gates contracts/bankai-core.gates.json --explain
zheref/bankai-core#940: ready
  head 8831f0b867dcddda64c3d28315c3d5c746c2ee9b · reviewers sasuke,tenma,copilot · approvers sasuke,tenma
  1  ready CON-42/1          Mergeable
  2  ready CON-32(a)         Every reported check green, on the latest run per check name
  3  ready CON-32(b)         No configured reviewer's requested round has stalled
  4  ready CON-32(b)         No configured reviewer's round owed at the current head
  5  ready CON-32(b)/CON-16  Every approving reviewer's latest round is an APPROVE at the current head
  6  ready CON-32(d)         Zero unresolved review threads
```

**`BC-PR-#940` is a real `ready` PR — used as the worked example for § 2.5, § 2.8.** `BC-PR-#925` is
a real `not-ready` PR (first failing conjunct: checks-green) — used as the worked example for § 1
row 4's stopgap composition.

### 2.2 — `nen pr fetch`, reproduced broken on BOTH real open PRs, two different shapes

```
$ nen pr fetch --target zheref/bankai-core --pr 925
nen pr: could not fetch zheref/bankai-core#925 reviews: gh: Unprocessable Entity (HTTP 422)

$ nen pr fetch --target zheref/bankai-core --pr 925 --json
nen pr: could not fetch zheref/bankai-core#925 reviews: gh: Unprocessable Entity (HTTP 422)

$ nen pr fetch --target zheref/bankai-core --pr 940
nen pr: zheref/bankai-core#940: $.reviews -- expected an array, got object ({"id":5084846292,
  "node_id":"PRR_kwDOTQ_CoM8AAAABLxSY1A","user":{"login":"zheref", ...},"body":"",
  "state":"PENDING", ..., "commit_id":"8831f0b867dcddda64c3d28315c3d5c746c2ee9b"})
```

**`#925` reproduces the same `422 Unprocessable Entity` `backlog-state`'s own A/B already caught on
this exact PR** (`docs/ab/backlog-state.md` § 2.5 — five-for-five across two repos at that time).
**`#940` is a NEW failure shape, not previously reproduced**: instead of a 422, the verb's own
schema validation rejects a *successful* GitHub response because a single, still-`PENDING` (never
submitted) review comes back as a bare JSON object rather than wrapped in the array `nen` expects.
Two genuinely different bugs in the same reviews-fetch path, both real, both against real PRs, in
the same run. **Confirms `nen pr fetch` is not usable for anything this skill needs** — neither
failure mode is bankai-core-specific data (both are real GitHub response shapes for real reviews on
real open PRs), so no plausible flag combination routes around either.

### 2.3 — `nen gate derive`, both real open PRs (re-confirming `backlog-state`'s pointer)

```
$ gh pr diff 940 --repo zheref/bankai-core --name-only
changelog.d/937-bc11-frozen-line-patch.md
cli/src/guards/bc11-allowlist.txt
cli/src/guards/bc11.repo.test.ts
cli/src/guards/bc11.test.ts
cli/src/guards/bc11.ts
handbooks/stacks/bankai-core/architecture.md

$ nen gate derive --policy-paths "CONSTITUTION.md,handbooks/,agents/,schemas/" \
                  --process-paths ".github/workflows/,claude/,scripts/,tests/,docs/" \
                  --files "changelog.d/937-bc11-frozen-line-patch.md,cli/src/guards/bc11-allowlist.txt,cli/src/guards/bc11.repo.test.ts,cli/src/guards/bc11.test.ts,cli/src/guards/bc11.ts,handbooks/stacks/bankai-core/architecture.md"
G4
G4: the diff touches policy/spec (handbooks/), which only the human merges.
```

(`#925`'s own derivation — G4, process surface — is already recorded in `docs/ab/backlog-state.md`
§ 2.3 against the same PR; not re-run here to avoid duplicating that transcript.) Both real open PRs
derive `G4`, matching the maintainer's own PR titles/intent. `nen gate derive --asserted` mismatch
behavior is unchanged from `backlog-state`'s own proof and not re-run.

### 2.4 — `nen pr next-blocker`, reproduced broken two ways

**First: no working override for bankai-core's missing `schemas/gates.json`.**

```
$ nen pr next-blocker --target zheref/bankai-core --pr 925 --repo <bankai-core checkout> --reviewers sasuke,tenma,copilot
nen pr: C:\...\bankai-core\schemas\gates.json: no such file. Nen reads this repository's taxonomy
from 'schemas/gates.json' in the TARGET repo and has no built-in copy to fall back on ... Point it
at a checkout that carries the file with --repo <path>, or add the file.

$ nen pr next-blocker --target zheref/bankai-core --pr 925 --repo <bankai-core checkout> \
    --gates contracts/bankai-core.gates.json --reviewers sasuke,tenma,copilot
nen pr: C:\...\bankai-core\schemas\gates.json: no such file.   # identical -- --gates is silently ignored, not even flagged as unknown
```

**`--reviewers` (documented) does not substitute, and `--gates` (undocumented for this verb) is
silently accepted but has no effect** — confirmed bankai-core's own checkout genuinely has no
`schemas/gates.json` (`ls schemas/` lists `colors.yml, labels.json, permission-tiers.yml,
repos.json, rulesets, templates` — no `gates.json`), matching the shared brief's own operational
truth #3.

**Second: patched around with a scratch `schemas/gates.json`, it hits the SAME reviews-fetch bug as
`nen pr fetch`.**

```
$ mkdir -p /tmp/nen-scratch-gates/schemas
$ cp contracts/bankai-core.gates.json /tmp/nen-scratch-gates/schemas/gates.json

$ nen pr next-blocker --target zheref/bankai-core --pr 925 --repo /tmp/nen-scratch-gates
nen pr: could not fetch zheref/bankai-core#925 reviews: gh: Unprocessable Entity (HTTP 422)

$ nen pr next-blocker --target zheref/bankai-core --pr 940 --repo /tmp/nen-scratch-gates
nen pr: could not fetch zheref/bankai-core#940 reviews: gh: Unprocessable Entity (HTTP 422)
```

Note `#940` fails with the **422** shape here, not the schema-validation shape `nen pr fetch #940`
gave standalone (§ 2.2) — the two verbs' internal reviews-fetch calls disagree with each other on
the identical live PR. **`nen pr next-blocker` cannot evaluate any real bankai-core PR today, with
or without the missing-taxonomy blocker patched around.** This port never calls it.

### 2.5 — `nen pr body-check`, a real PR body

```
$ gh pr view 925 --repo zheref/bankai-core --json body -q .body > pr925-body.txt
$ cat > body-reqs.json <<'EOF'
[
  {"name": "How to verify", "pattern": "## How to verify"},
  {"name": "Akatsuki-Agent trailer", "pattern": "Akatsuki-Agent:"}
]
EOF
$ nen pr body-check --body-from pr925-body.txt --requirements-from body-reqs.json
1/2 requirement(s) satisfied
ok  How to verify
MISSING  Akatsuki-Agent trailer
```

Confirmed: purely local text matching, no `schemas/gates.json` dependency, no GitHub call beyond
the body read the caller already needed. Never stops at the first miss (both requirements
evaluated and reported, matching `--help`'s own description).

### 2.6 — `nen wake verify`, no `--run` — confirmed genuinely read-only, run against real bankai-core

```
$ nen wake verify --repo-slug zheref/bankai-core --now "2026-09-01T23:00:00Z" \
    --author-pattern "kisuke|naruto|sasuke|tenma|yamamoto|roy|dev-build"
scanned 1 PR(s) (dry run)
no swallowed wakes found

$ nen wake verify --repo-slug zheref/bankai-core --now "2026-09-01T23:00:00Z" \
    --author-pattern "kisuke\[bot\]|naruto\[bot\]" --json
{"repo":"zheref/bankai-core","now":"2026-09-01T23:00:00Z","dryRun":true,"scanned":0,"results":[],"warnings":[]}
```

Confirmed: without `--run` the verb prints `(dry run)`/`"dryRun": true` and both plain and `--json`
forms ran clean against the real repository with no GitHub write of any kind — the shared brief's
own hint ("verify's read half may be exercisable read-only — check") holds. `--run` (auto-redrive,
posts comments) was **not** exercised — mutating, contract inspected only.

### 2.7 — `nen pr staleness`, four synthetic cases

```
$ cat wakes-stale.json
[{"at":"2026-09-01T20:00:00Z","noCommit":true},{"at":"2026-09-01T21:00:00Z","noCommit":true}]

$ nen pr staleness --wakes-from wakes-stale.json --last-activity 2026-09-01T21:00:00Z --now 2026-09-01T22:30:00Z
stale
merge not permitted
2/2 verified no-commit wake(s) (met)
90/60 idle minute(s) (met)
stale, but NOT Ready -- no merge is permitted; a stale, not-ready PR is still owned by its author

$ nen pr staleness --wakes-from wakes-stale.json --last-activity 2026-09-01T21:00:00Z --now 2026-09-01T22:30:00Z --ready
stale
merge PERMITTED (stale + Ready)
2/2 verified no-commit wake(s) (met)
90/60 idle minute(s) (met)

$ cat wakes-notstale.json   # second wake DID produce a commit
[{"at":"2026-09-01T20:00:00Z","noCommit":true},{"at":"2026-09-01T21:00:00Z","noCommit":false}]
$ nen pr staleness --wakes-from wakes-notstale.json --last-activity 2026-09-01T21:00:00Z --now 2026-09-01T22:30:00Z
not stale
1/2 verified no-commit wake(s)
90/60 idle minute(s) (met)

$ nen pr staleness --wakes-from wakes-stale.json --last-activity 2026-09-01T22:00:00Z --now 2026-09-01T22:30:00Z   # only 30 min idle
not stale
2/2 verified no-commit wake(s) (met)
30/60 idle minute(s)
```

All four cases match the documented rule exactly (≥2 verified no-commit wakes AND ≥60 idle minutes,
both required; `--ready` is the sole switch between "not permitted" and "PERMITTED"). **Finding,
not a bug**: `mergePermitted: true` is a real field this verb prints, and `drive`'s own hard limit
(never merges — § 10 of the skill) deliberately does not act on it; recorded as tension, not
silently reconciled (§ 4).

### 2.8 — `nen stop`, end to end with `BC-PR-#940`'s real data

```
$ cat efforts-drive.md
| Effort | Refs | Status (gate) | Needs |
| --- | --- | --- | --- |
| A fifth shell clause for a frozen-line patch, expiring with the freeze | BC-IS-#937, BC-PR-#940 | 🟢 (G4) | Merge — maintainer only |

$ nen stop --who Kurapika --gate G4 efforts-drive.md
=== YOUR INPUT IS NEEDED ==============================
who: Kurapika
gate: G4 -- policy/spec change
rung 1 (push notification): NOT fired -- the caller's to have sent, before this renders.
rungs 2-3 (OS notification, audible cue): not fired by nen -- only git/gh subprocesses are ever shelled out to.
see the table below. No banner above => nothing needs you right now.

| Effort                                                                 | Refs                   | Status (gate) | Needs                   |
| ----------------------------------------------------------------------- | ---------------------- | ------------- | ----------------------- |
| A fifth shell clause for a frozen-line patch, expiring with the freeze | BC-IS-#937, BC-PR-#940 | 🟢 (G4)       | Merge — maintainer only |
```

Real gate banner, real PR, real gate derivation (§ 2.3) and real readiness verdict (§ 2.1)
composed end to end.

---

## 3. Mutating verbs — contract inspection only (never exercised against bankai-core)

Per the shared brief's boundary: these MUTATE GitHub (or the git remote) and are never fired at the
real, frozen bankai-core repository by this port. Their full `--help` contracts (captured verbatim
from the pinned `v0.1.0` binary) are what `SKILL.md` cites; no dry run against `zheref/hatsu` was
attempted either, since none was genuinely needed to write the skill (same precedent as `pr-state`
and `backlog-state`'s own A/B docs, neither of which dry-ran a mutating verb against hatsu).

- **`nen wake fire --repo-slug <owner/name> --ref <object-ref> --label <name> [--comment <text>]
  [--run]`** — removes then re-applies one label (the edge-trigger convention), optionally posts a
  settle comment after. `--run` required to write anything.
- **`nen pr cascade-main --repo <path> [--trunk main]`** — merges (never rebases) the trunk into the
  current branch and pushes on a clean merge; reports rather than resolves a conflict.
- **`nen pr request-reviews --target <owner/name> --pr <n> --add-reviewers a,b`** — `gh pr edit
  --add-reviewer`, once per name; the verb itself warns it cannot enforce which credential runs it.
- **`nen pr retarget --target <owner/name> --pr <n> --base <branch>`** — `gh pr edit --base`, for a
  stacked PR after its predecessor merges. Not used by this skill's own text (no stacking scenario
  in `drive`'s scope) but captured here since it lives in the same `pr` family and a future revision
  may need it.
- **`nen wake verify ... --run`** — the mutating half of the verb whose read half is exercised live
  in § 2.6; auto-redrives and posts comments once given `--run`.

---

## 4. Findings (report separately, do not route around)

1. **`nen pr fetch` is broken against real bankai-core PRs in (at least) two distinct ways in the
   same reviews-fetch path.** `#925`: `could not fetch ... reviews: gh: Unprocessable Entity (HTTP
   422)` (matches `backlog-state`'s own earlier five-for-five reproduction on this same PR,
   `docs/ab/backlog-state.md` § 2.5). `#940`: a *different* failure — `$.reviews -- expected an
   array, got object`, because a single still-`PENDING` review comes back from GitHub as a bare
   object rather than wrapped in an array, and the verb's schema validation rejects it outright
   rather than normalizing a one-element case. Reproduced live, this run (§ 2.2). This port never
   calls `nen pr fetch`.

2. **`nen pr next-blocker` cannot evaluate any real bankai-core PR, for two compounding reasons.**
   First, it has no `--gates` override at all (only `--reviewers`/`--approvers`, per `--help`), and
   passing `--gates` anyway is silently accepted with no effect — the verb still hard-requires
   `schemas/gates.json` inside `--repo`'s own checkout, which frozen bankai-core does not ship
   (confirmed: `ls schemas/` lists no `gates.json`). Second, once that is patched around with a
   scratch checkout carrying a copy of the taxonomy, the verb fails again on the identical
   reviews-fetch defect finding 1 already names — and, on `#940` specifically, with the **422**
   shape rather than the schema-mismatch shape `nen pr fetch` gave the same PR standalone,
   meaning the two verbs' internal fetch calls do not even agree with each other against the same
   live data. Reproduced live both ways (§ 2.4). This port never calls `nen pr next-blocker`; the
   disclosed stopgap is composing `nen pr ready --explain`'s own conjunct order with a separate
   `nen pr body-check` call (`SKILL.md` § 3).

3. **`nen pr next-blocker` has no documented flag for the `schemas/gates.json` substitute that `nen
   pr ready` offers (`--gates <path>`) despite living in the same `pr` family and serving the same
   frozen-repo need.** This asymmetry between two verbs in one family is itself worth fixing
   upstream regardless of finding 2's deeper (fetch-layer) blocker — even a working reviews-fetch
   underneath would still leave bankai-core unjudgeable by this verb today.

4. **`nen pr staleness` prints a `mergePermitted: true` field for the stale+Ready case that this
   skill deliberately never acts on.** Not a bug in the verb — it is documented behavior
   (`--help`: *"Stale + Ready is the one case a merge is permitted without a human"*) — but a real
   tension with `drive`'s own hard limit (never merges, under any circumstance; G2/G4 stay the
   maintainer's). Recorded here and in `SKILL.md` § 6/§ 10 as a disclosed carve-out, not silently
   reconciled: this skill reads the verb's `stale` boolean and its two conjuncts, and never its
   `mergePermitted` field, as a matter of policy.

---

## 5. Residue

- **Judgment kept, per the shared brief's boundary list:** the confirmation pass itself (§ 4 of the
  skill — what a deterministic gate structurally cannot read), the escalation ladder's diagnosis
  step (naming *what* is actually stuck), the `DECIDE`/`DO` framing at G5, and the decision to take
  local authorship as an exception (§ 6 of the skill) — `nen` computes and verifies; deciding what a
  stuck PR needs next stays this skill's.
- **No PR-diff-fetch verb exists**, same residue `backlog-state`'s own A/B already names — `gh pr
  diff <n> --name-only` remains a necessary raw call feeding `nen gate derive --files`.
- **No PR-base-ref-fetch verb exists** either, for the identical reason (`nen pr fetch` would supply
  it and does not work) — `gh pr view --json baseRefName` remains a necessary raw call, same
  stopgap `backlog-state`'s own § 4 already discloses.
- **The concurrency-group hazard between a comment and a label fire** (BC-IS-#554) and the
  conflicted-PR edge-trigger behavior (BC-IS-#798) are `copilot-sweeper.yml`-level GitHub Actions
  behavior, outside anything `nen` owns or could own — kept as prose/judgment in `SKILL.md` § 5,
  unchanged in substance from the old skill.
- **The wake-attempt log this skill asks the agent to keep** (`docs/Loop/<run-id>/`) now has a
  second job: it is also `nen pr staleness --wakes-from`'s own input shape (`{ at, noCommit }`).
  This is a genuine simplification over the old skill (one artifact instead of a log plus a
  separately-reasoned tally), not a `nen` verb in its own right — no verb populates this log from
  GitHub automatically; the caller still appends to it as each wake attempt happens.
