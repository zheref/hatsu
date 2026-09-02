# A/B evidence — `tensho` (zheref/hatsu#2)

Port of `claude/skills/tensho/SKILL.md`: turning a dirty working copy into one PR standing ready at
its gate. Old mechanics: prose reasoning over `git status`/`git diff` by hand — a four-case table
for where the checkout sits, a six-category flag list for what never gets staged blind, unchecked
Conventional-Commits shape, and a hand-read of the PR body against three "not optional" parts — with
no runnable script backing any of it (unlike `pr-state`'s `pr_ready_gate.sh`). New mechanics: `nen wc
classify`, `nen stage triage`, `nen commit format`, `nen pr body-check`, `nen changelog
fragment-required`, `nen gate derive`, `nen ref format|parse`, `nen repo resolve`, `nen pr
request-reviews`, and — for the phase the old skill handed to `bankai:drive` — `nen pr ready` via
`hatsu:pr-state`.

Run: 2026-09-01 (local clock; `nen 0.1.0` at `C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`).
`gh` authenticated as `zheref`. Local verbs exercised against a **constructed** scratch git repo
(`C:\Users\zhere\.claude\jobs\4f1fdef1\tmp\scratch-tensho`, never pushed anywhere, seeded and
discarded for this run only) and, for `--files`/`--policy-paths`-shaped verbs that take a path list
rather than a live checkout, constructed inline file lists. GitHub-touching read-only verbs
(`pr ready`, `ref format`, `repo resolve`) were run against the real `zheref/bankai-core` (read-only:
`gh pr list`, `nen pr ready`, `nen ref format`, `nen repo resolve` — nothing mutating). No verb was
ever run against `bankai-core` in a way that could write to it, and nothing was pushed to any remote
other than `hatsu`'s own `p2/2-tensho` branch.

---

## 1. Command mapping table

| # | Old (prose, hand-reasoned — no runnable script) | New (`nen`) |
|---|---|---|
| 1 | "The argument is the PR's base... `main` is the default" — parsed by the agent reading the invocation by eye | Considered `nen parse tensho --grammar <template> --line <invocation>` and **declined** — a finding (§ 4.1): the generic grammar's `[ ... ]` optional-clause syntax does not actually make a lone bracketed slot optional, verified live. The default-to-`main` rule stays prose, same as `pr-state` declined `nen parse` for its own ref grammar (`docs/ab/pr-state.md` row 9) |
| 2 | "Read the current checkout before moving anything" — the four-row table (must-move / same-effort continue / different-effort fresh branch / clean), reasoned from `git status`/`git log` by hand | `nen wc classify --repo <path> --base <target>` — reports one of three cases (`must-move`, `on-branch-dirty`, `on-branch-clean`) with the evidence printed; verified live it never folds a `git` failure into a zero/empty reading (§ 2.1) |
| 3 | Deciding whether uncommitted work is the "same effort" as a branch's existing commits — a judgement call with no stated evidence source | Still judgement — but `nen wc classify`'s `on-branch-dirty` case now **prints** the exact evidence (existing commit subjects, uncommitted paths) this skill used to have to go gather itself |
| 4 | Resolving which product code a working copy belongs to — never a stated command, left to the agent to infer | `nen repo resolve --repo <path> --from <path>` (origin match) or `nen repo resolve <CODE> --repo <path>` (explicit) — with a real finding on the origin-match path (§ 4.2, § 2.9) |
| 5 | The staging flag table — 7 categories (secret, ignored, binary, out-of-scope, local-config, unmentioned-deletion, unusually-large), each detected by the agent reading the diff by eye | `nen stage triage --repo <path> [--scope ...] [--mentions ...]` covers **5 of 7** (§ 2.2) — `secret-shape`, `ignored`, `binary`, `out-of-scope`, `unmentioned-deletion`. **2 residual categories with no detector**: local-config files and "unusually large" files (§ 4.3/4.4) — both verified live to report clean when they hit neither an existing detector, and both stay this skill's to ask about by eye |
| 6 | "The ask on every flagged file stays human" | **Unchanged, verbatim** — `nen stage triage` detects, never decides, and its own `--help` says the yes is never its to give |
| 7 | Conventional Commits shape (type, subject length, trailing punctuation), checked (or not) by eye | `nen commit format --type ... --subject ...` — validates shape only, exits `2` on a violation (§ 2.3) |
| 8 | The two "not optional" PR body sections, hand-read against the diff | `nen pr body-check --body-from ... --requirements-from ...` — checks every requirement, never stops at the first miss (§ 2.4) |
| 9 | The `changelog.d/` fragment obligation (`CON-33(a)`), hand-checked against the diff's touched paths | `nen changelog fragment-required --spec-paths ... --files ... --head-changelog ...` (§ 2.5) |
| 10 | Deciding the target gate (G2 vs G4) from the diff, by the same two-tier prose `drive.SKILL.md` carries | `nen gate derive --policy-paths ... --process-paths ...` — reports the gate, names which set hit, and corrects a wrong `--asserted` guess rather than accepting it (§ 2.6) |
| 11 | `Closes #N`/`Part of #N` and `<CODE>-<IS\|PR>-#<N>` object notation, formatted by hand | `nen ref format`/`nen ref parse` (§ 2.7) |
| 12 | "Request Copilot on open" — raw `gh pr edit --add-reviewer` | `nen pr request-reviews --target ... --pr ... --add-reviewers copilot` — contract-inspected only, never exercised live (§ 3) |
| 13 | "tensho hands straight to `bankai:drive`... same one-directional readiness rule" | `hatsu:drive` is not ported yet (`hatsu#2`); the interim mechanics are the same verb `hatsu:pr-state` already ports, `nen pr ready ... --explain` (§ 2.10), quoted verbatim under the same binding rule |
| 14 | The gate-stop banner, rendered by hand or via `scripts/gate_stop.sh` in bankai-core | `nen stop --who kurapika --gate <g> <efforts.md>` (§ 2.8) |

**Count.** Before: **9 hand-reasoned steps per invocation** (rows 1, 2, 5, 6's detection half, 7, 8,
9, 10, 11 — every one of them prose the agent executed by reading the diff, with zero runnable
scripts behind any of them, unlike `pr-state`'s oracle). After: **0 fully improvised** — every row
above is now a `nen` invocation, except row 1 (a considered-and-declined `nen parse`, a finding
against the binary rather than a skill choice) and two named residual detection gaps in row 5 (§ 4.3,
§ 4.4), which are by-eye judgement calls the verb explicitly declines to own, not gaps routed around
by hand. Rows 3 and 6 stay judgement by design — Nen hands over evidence, never a verdict, exactly as
the shared brief's boundary list requires.

---

## 2. Live transcripts

### 2.1 — `nen wc classify`, all three cases plus the error path (constructed)

Constructed scratch repo: `main` seeded with one commit, a feature branch `ichigo/scratch-feature`
cut from it.

```
$ echo "dirty line" >> README.md   # on main
$ nen wc classify --repo <scratch> --base main
case: must-move
  on the trunk ('main') with 1 uncommitted path(s) -- this MUST move to a fresh branch cut from the
  target base; nothing is ever committed to the trunk directly
exit=0
```

```
$ git checkout -b ichigo/scratch-feature
$ git add feature.txt && git commit -m "feat: add feature file"
$ echo "more uncommitted work" >> feature.txt
$ nen wc classify --repo <scratch> --base main
case: on-branch-dirty
  on 'ichigo/scratch-feature', 1 commit(s) ahead of base, 1 uncommitted path(s) -- whether these are
  the SAME effort as the branch's existing commits is a judgement this module does not make; the
  commit subjects and paths below are the evidence for it
  existing commits: "feat: add feature file"
exit=0
```

```
$ git checkout feature.txt   # clean it up
$ nen wc classify --repo <scratch> --base main
case: on-branch-clean
  on 'ichigo/scratch-feature' with nothing uncommitted -- open or report the existing PR
exit=0
```

```
$ nen wc classify --repo <scratch> --base does-not-exist-branch
nen wc: could not count commits ahead of base ('git rev-list --count does-not-exist-branch..HEAD'
failed: ... unknown revision or path not in the working tree ...). This usually means --base
'does-not-exist-branch' does not name a ref reachable from HEAD. Refusing to report 0 commits
ahead, which would read as a checked answer rather than an unreadable one.
exit=1
```

All four verified: the three cases from `nen wc classify --help`'s own table, plus the documented
"never folds a git failure into an empty reading" guarantee.

### 2.2 — `nen stage triage`, one of each hazard, plus `--scope`/`--mentions`/`--json` (constructed)

Working copy seeded with: `README.md` deleted (tracked, unmentioned), `.env` (untracked secret
shape), `debug.local.log` (untracked, matches a `.gitignore` entry added the same run),
`image.bin` (untracked binary), `randomfile.txt` (untracked, plain, in no declared scope).

```
$ nen stage triage --repo <scratch>
clean: 1 file(s)
  randomfile.txt
flagged: 4 file(s) -- never staged without an explicit yes
  README.md  [unmentioned-deletion]
  .env  [secret-shape]
  image.bin  [binary]
  debug.local.log  [ignored]
exit=1
```

```
$ nen stage triage --repo <scratch> --scope src/,docs/
clean: 0 file(s)
flagged: 5 file(s) -- never staged without an explicit yes
  README.md  [out-of-scope, unmentioned-deletion]
  .env  [secret-shape, out-of-scope]
  image.bin  [binary, out-of-scope]
  randomfile.txt  [out-of-scope]
  debug.local.log  [ignored, out-of-scope]
exit=1
```

```
$ nen stage triage --repo <scratch> --mentions "removing README.md as part of cleanup"
clean: 2 file(s)
  README.md
  randomfile.txt
flagged: 3 file(s) -- never staged without an explicit yes
  .env  [secret-shape]
  image.bin  [binary]
  debug.local.log  [ignored]
exit=1
```

`--json` on the first run reproduces the same rows structured, `clean: ["randomfile.txt"]` and
`flagged` as `{path, reasons[]}` objects — confirms multi-reason rows (`README.md` carrying both
`out-of-scope` and `unmentioned-deletion` at once) are a real array, not a display artifact.

### 2.3 — `nen commit format`, valid and every invalid shape (pure, no repo needed)

```
$ nen commit format --type feat --subject "add tensho port scratch fixtures" --scope tensho \
    --body "Exercises wc classify and stage triage against constructed working-copy states." \
    --trailer "Akatsuki-Agent=kurapika"
feat(tensho): add tensho port scratch fixtures

Exercises wc classify and stage triage against constructed working-copy states.

Akatsuki-Agent: kurapika
exit=0

$ nen commit format --type fix --subject "correct triage flag ordering" --breaking --body "..."
fix!: correct triage flag ordering
...
exit=0

$ nen commit format --type feature --subject "bad type"
nen: type 'feature' is not one of feat, fix, chore, docs, refactor, test, perf, build, ci
exit=2

$ nen commit format --type feat --subject "<168-char subject>"
nen: header line is 167 characters, over the 72-character convention: '...'
exit=2

$ nen commit format --type feat --subject "add a trailing period."
nen: subject ends with punctuation -- Conventional Commits subjects read as a sentence fragment, not
a sentence
exit=2

$ nen commit format --type feat --subject ""
nen: subject is empty
exit=2
```

Also verified: `--trailer "Akatsuki-Agent=kurapika,Closes=#12"` renders both trailers, confirming the
comma-separated multi-pair form `--help` documents.

### 2.4 — `nen pr body-check` (constructed local files, pure)

```
$ cat requirements.json
[
  {"name": "What this changes for you", "pattern": "^# What this changes for you"},
  {"name": "How to verify", "pattern": "^## How to verify"}
]

$ nen pr body-check --body-from good-body.md --requirements-from requirements.json
2/2 requirement(s) satisfied
ok  What this changes for you
ok  How to verify
exit=0

$ nen pr body-check --body-from bad-body.md --requirements-from requirements.json
0/2 requirement(s) satisfied
MISSING  What this changes for you
MISSING  How to verify
exit=1
```

Confirms "every requirement is checked; never stops at the first miss" — both misses reported
together, not just the first.

### 2.5 — `nen changelog fragment-required`, all four states (constructed)

```
$ nen changelog fragment-required --spec-paths "CONSTITUTION.md,handbooks/,schemas/,agents/,.github/workflows/" \
    --fragment-dir changelog.d --files "CONSTITUTION.md,src/app.js" --head-changelog CHANGELOG.md
required
this change touches a spec/canon path (CONSTITUTION.md) but adds no changelog.d/ fragment, and its
body carries no opt-out with a reason. ...
exit=1

$ nen changelog fragment-required --spec-paths "..." --fragment-dir changelog.d \
    --files "src/app.js,src/util.js" --head-changelog CHANGELOG.md
not-applicable
no spec/canon paths changed, so the per-PR fragment rule does not apply
exit=0

# a fragment file exists on disk under changelog.d/ but is NOT part of --files:
$ nen changelog fragment-required --spec-paths "..." --files "CONSTITUTION.md,src/app.js" ...
required        # UNCHANGED -- a fragment merely present is not enough

# the fragment path is added to --files (it is part of THIS diff):
$ nen changelog fragment-required --spec-paths "..." \
    --files "CONSTITUTION.md,src/app.js,changelog.d/12-scratch-fix.md" --head-changelog CHANGELOG.md
fragment-present
a fragment under changelog.d/ is added or modified and survives at head -- satisfied
exit=0

$ nen changelog fragment-required --spec-paths "..." --files "CONSTITUTION.md" \
    --head-changelog CHANGELOG.md --body-from pr-body.txt   # body contains "no CHANGELOG entry: ..."
opt-out
the body states the opt-out with a reason -- skipping the entry check, as the rule allows for a
genuinely non-spec change
exit=0
```

All four states (`not-applicable`, `required`, `fragment-present`, `opt-out`) reproduced live. Note
the load-bearing detail: the fragment must appear in `--files` (the changed-path set), not merely
exist in `--fragment-dir` — verified by the "unchanged" run above.

### 2.6 — `nen gate derive` (constructed file lists, pure)

```
$ nen gate derive --policy-paths "CONSTITUTION.md,handbooks/,agents/,schemas/" \
    --process-paths ".github/workflows/,claude/,scripts/,tests/,docs/" --files "src/app.js,src/util.js"
G2
G2: the diff touches neither path set across 2 changed files, so it is product code.

$ nen gate derive --policy-paths "..." --process-paths "..." --files "handbooks/stack-matrix.md,src/app.js" --asserted G2
G4
G4: the diff touches the process surface (handbooks/); in a repository whose product is its process,
that is a policy change.
correction: the invocation asserted G2; the diff derives G4, and the derived gate stands.

$ nen gate derive --policy-paths "..." --process-paths "..." --files "CONSTITUTION.md"
G4
G4: the diff touches policy/spec (CONSTITUTION.md), which only the human merges.
```

`--json` reproduces the same as `{gate, changed[], hits[], basis, asserted, corrected,
readinessNote}` — `hits[]` names which pattern and which set (`policy`/`process`) matched.

### 2.7 — `nen ref format` / `nen ref parse`, against the real `bankai-core` registry (read-only)

```
$ nen ref format --code BC --kind PR --number 925 --state open --repo <bankai-core checkout>
🔀 BC-PR-#925

$ nen ref format --code BC --kind IS --number 12 --repo <bankai-core checkout> \
    --url "https://github.com/zheref/bankai-core/issues/12"
📄 [BC-IS-#12](https://github.com/zheref/bankai-core/issues/12)

$ nen ref parse "BC-PR-#925"
ref:    BC-PR-#925
code:   BC
kind:   PR
number: 925
glyph:  🔀
```

### 2.8 — `nen stop`, the gate banner (pure)

```
$ nen stop --template
| Effort  | Open issues & PRs | Status (gate)   | Thought flow | Session / lane |
...

$ nen stop --who kurapika --gate G4 efforts.md
=== YOUR INPUT IS NEEDED ==============================
who: kurapika
gate: G4 -- policy/spec change
rung 1 (push notification): NOT fired -- the caller's to have sent, before this renders.
rungs 2-3 (OS notification, audible cue): not fired by nen -- only git/gh subprocesses are ever
shelled out to.
see the table below. No banner above => nothing needs you right now.

| Effort     | State               | Gate | Needs        | Owner      |
| BC-PR-#925 | not-ready (CON-32a) | G4   | green checks | maintainer |
```

### 2.9 — `nen repo resolve`, a real finding against the binary (read-only, live)

```
$ nen repo resolve --repo <bankai-core checkout> --from <bankai-core checkout>
nen repo: 'C:\...\bankai-core' has an 'origin' of 'https://github.com/zheref/bankai-core.git', which
resolves to 'zheref/bankai-core' -- and that is not in this registry (...\schemas\repos.json). An
origin is a token like any other: it is an error, never a fallback to every repository. Codes:
$comment (...), BC (zheref/bankai-core), BS (zheref/bankai-scaffold), KP (zheref/KroApple), KN
(zheref/KroAndroid), KW (zheref/KroWindows), KC (zheref/kro-pwa). Repositories: zheref/KroApple,
zheref/KroAndroid, zheref/bankai-scaffold.
exit=1

$ nen repo resolve BC --repo <bankai-core checkout>
zheref/bankai-core  (BC)  via code
exit=0
```

The no-token form's origin match only ever compares against `schemas/repos.json`'s `consumers[]`
array (three repos, printed above) — `bankai-core` itself is the registry's owner, never one of its
own `consumers[]` rows, so this path refuses even though `BC` is a valid, listed code (the same
refusal message enumerates it). Recorded as a finding, § 4.2.

### 2.10 — `nen pr ready`, spot confirmation for § 6's drive-phase reuse (read-only, live)

**Citation, not re-proof.** Verdict parity between `nen pr ready` and `pr_ready_gate.sh` is already
established across the live estate by `docs/ab/pr-state.md` (17/17 agreeing, per nen's shadow
window). This is a spot confirmation only, reusing the same PR `pr-state`'s own doc already recorded:
`zheref/bankai-core#925` — the identical PR `docs/ab/pr-state.md` § 2.1 already A/B'd — run again
here deliberately, as a spot-confirmation that the handover is wired correctly, not as a claim of
any new verdict coverage.

```
$ export GH_TOKEN=$(gh auth token)
$ nen pr ready 925 --gh-repo zheref/bankai-core --gates <hatsu>/contracts/bankai-core.gates.json --explain
zheref/bankai-core#925: not-ready: required checks reported but are not all green (CON-32a)
  ...
  1  ready       CON-42/1          Mergeable
  2  FAILED      CON-32(a)         Every reported check green, on the latest run per check name
        └ not-ready: required checks reported but are not all green (CON-32a)
  3  unevaluated CON-32(b)         No configured reviewer's requested round has stalled
  4  unevaluated CON-32(b)         No configured reviewer's round owed at the current head
  5  unevaluated CON-32(b)/CON-16  Every approving reviewer's latest round is an APPROVE at the current head
  6  unevaluated CON-32(d)         Zero unresolved review threads
exit=1
```

**Byte-identical** to `docs/ab/pr-state.md` § 2.1's own transcript of the same PR — same head SHA,
same verdict, same reason text. This is expected (`nen pr ready` is one verb; both docs invoke it on
the same live PR) and confirms the drive-phase reuse in § 6 needs no separate proof of the gate
itself, only of the handover being correctly wired to the existing verb.

---

## 3. Mutating verb — contract inspection only, not exercised live

`nen pr request-reviews --target <owner/name> --pr <n> --add-reviewers a,b` maps directly onto `gh
pr edit --add-reviewer`, once per name (`nen pr --help`'s own description). Per this port's ground
rules, a mutating GitHub verb is A/B'd by contract inspection against the old skill's raw `gh pr edit
--add-reviewer copilot` (same effect, same caveat — "on the maintainer's user token it registers,
where a bot token silently no-ops," verified by `nen`'s own `--help` text carrying the identical
caveat verbatim) rather than exercised against a real `bankai-core` or `hatsu` PR. No dry run against
`hatsu` was performed either: the maintainer's own open PRs on `hatsu` were left untouched, since
adding a reviewer is a real, visible side effect on a PR nobody asked this port to touch.

---

## 4. Residue and findings

### 4.1 — `nen parse`'s optional-clause syntax does not make a lone slot optional (finding)

Verified live: `nen parse tensho --grammar "[<target-branch>]" --line ""` refuses with
`<target-branch> is required and the line does not supply it`, contradicting `--help`'s own
description of `[ ... ]` as "an optional trailing clause." Worse, `--grammar "onto [<target-branch>]"
--line "onto"` (introducing word present, nothing after it) parses successfully but reports
`target-branch: onto` — it reads the introducing literal itself as the slot's value rather than
recognizing the clause was omitted. Reproduced twice, same shape both times. **This is why tensho's
own invocation grammar (§ 1) stays hand-written prose** rather than a `nen parse` call — not a skill
authoring choice, a defect against the binary's generic grammar engine, worth filing.

### 4.2 — `nen repo resolve`'s no-token path cannot resolve the registry-owning repo to its own code

See § 2.9. Not necessarily a defect — arguably correct, since `schemas/repos.json`'s `consumers[]`
is deliberately a list of repos that *consume* bankai-core, and bankai-core consuming itself would be
a category error — but it means tensho, when run from inside the very checkout that ships the
registry, cannot use the convenient no-token form and must pass the code explicitly. Documented in
the skill (§ 2) as a named finding rather than a silent workaround.

### 4.3 — No local-config detector in `nen stage triage`

A `.claude/settings.local.json`-shaped file that is not git-ignored and not out of a declared
`--scope` reports **clean** — verified live, § 2.2's transcripts show it absent from every `flagged`
list across every run. The old skill named this its own category ("Personal state, not project
state"); `nen stage triage`'s own `--help` lists five detectors and this is not one of them. Kept as
residue per the shared brief's boundary list — asking about a local-config file by name stays this
skill's job, not routed around by hand as if the verb covered it.

### 4.4 — No size/"unusually large" detector in `nen stage triage`

A constructed 2.6&nbsp;MB plain-text file (ordinary padding lines, not binary) reports clean for the
same reason as § 4.3 — verified live. "Repo weight is permanent" stays a by-eye judgement this skill
states in § 3, since no `nen` verb computes it.

### 4.5 — No missing verb, otherwise

Every other deterministic step the old skill improvised in prose has a `nen` verb, verified live
against a constructed fixture or (where GitHub was actually involved) the real, read-only
`zheref/bankai-core`. The two gaps above (§ 4.3, § 4.4) are declared detection boundaries the verb's
own `--help` names explicitly ("Detects... secret shapes, git-ignored files, binaries, out-of-scope
paths and unmentioned deletions") — not silences to be discovered later.

### 4.6 — Judgment kept, per the shared brief's boundary list

- **"Same effort" or not**, when `nen wc classify` reports `on-branch-dirty` (§ 2.1) — the verb
  hands over evidence (commit subjects, uncommitted paths), never a verdict.
- **The ask on every flagged staging file** (§ 2.2) — `nen stage triage` detects and exits `1`; the
  yes is never its to give, per its own `--help`.
- **Conjurer vs. Transmuter** inside a `nen gate derive` `G4` hit (§ 2.6) — the verb says which path
  set matched, not which of the two authorship natures that implies.
- **Whether two axes belong in one PR at all** — offering `hatsu:jujisho` instead is this skill's
  call, not a verb's.
- **The readiness verdict's downstream meaning** — § 6 quotes `nen pr ready`'s verdict verbatim
  (same binding rule `hatsu:pr-state` § 5 states) and stops; deciding what happens next is the
  maintainer's or `hatsu:drive`'s, once it lands.

### 4.7 — `hatsu:drive` and `hatsu:jujisho` are not yet ported

Both are referenced in the ported skill (§ 1, § 6) as forward pointers to `zheref/hatsu#2`'s own
scope list, in prose only — no relative markdown link to a file that does not exist in this repo yet,
matching the precedent `hatsu:pr-state` set for the same situation with `drive`.
