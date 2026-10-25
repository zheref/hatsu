# A/B evidence — `hiraishin` (zheref/hatsu#357)

`claude/skills/hiraishin/SKILL.md`: one PR merged into its repository's base, ported to one sibling of the
same product family — spec first where the family declares a spec repository (kamui's spec step, a **G2**
wait), then a port brief mapping every concept to its target equivalent, each unmapped row ruled once
through `bankai-rule`'s `port-drift`, then the port issue filed on the target and `hatsu:build` run on it.
**This file is the dated dry run** the SDD assessment's wave 3 (*porting closes the loop*, zheref/hatsu#354)
owes: `--dry-run` over the offline fixtures, every command and its output as they ran. **A stale dry run is a
finding** — the date is part of the record.

## 1. Dry run — `hatsu:hiraishin FI-PR-#42 to FA --dry-run` over the fixtures

**Run: 2026-10-22 (UTC), nen `0.24.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64), from the
working tree of `fable/kurapika/port-term-guard` over base `4baf46d65` — the head this PR lands; every
command below reads only files that exist at the base too, so it reruns from `main`.** Inputs: `scripts/fixtures/port-family/with-family` (the source's registry:
`FI`, scenario `swiftui-tca-uzf-v2`; `FA` and `FW` as codes and family members) and
`scripts/fixtures/spec-family/specs/001-fixture-capability/spec.md` (the spec folder standing in for the
source feature's spec). **No GitHub call of any kind was made** — `fixture-owner/*` never reaches `gh` or a
networked verb ([`PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md), the fixture row); each read a live run
makes from GitHub is named as *not read*. `--dry-run` writes nothing outside the session's scratch
directory (hiraishin § 9): no record, no issue, no spec PR, no label.

### § 1 — the invocation; a dangling `to` is the skill's refusal, not nen's

```
$ nen parse hiraishin --grammar "<source> [to <target>] [--dry-run]" --line 'FI-PR-#42 to FA --dry-run'
source: FI-PR-#42
target: FA
[--dry-run]: present
exit=0

$ nen parse hiraishin --grammar "<source> [to <target>] [--dry-run]" --line 'FI-PR-#42 to --dry-run'
source: FI-PR-#42
target: (clause absent)
[--dry-run]: present
exit=0

$ nen parse hiraishin --grammar "resume <run_id>" --line 'resume'
nen parse: <run_id> is required and the line does not supply it.

Corrected line:
  hiraishin resume <run_id>
exit=2

$ nen ref parse 'FI-PR-#42' --repo scripts/fixtures/port-family/with-family
ref:    FI-PR-#42
code:   FI
kind:   PR
number: 42
glyph:  🔀
exit=0

$ nen repo resolve FA --repo scripts/fixtures/port-family/with-family
fixture-owner/fixture-android  (FA)  via code
exit=0
```

The second transcript is *conventions*' dangling-`to` row (ports.md § *Shared conventions*, zheref/nen#366,
**still open at `0.24.0`**): nen drops the trailing `to` at exit `0` with the target absent, so the skill
refuses when the target slot is empty while the raw line's last token before `--dry-run` is `to`, and asks
(`missing-argument`). The `resume` template is chosen only by the literal first token; `resume` alone exits
`2`, as hiraishin § 1 records. Target `FA` ≠ source `FI`, so the directed pair stands.

**Governance** (`nen canon resolve`, no scenario → `handbook-question (CON-37)`): the source's scenario is
declared on its own `consumers[]` row; the target's is read from the target's own checkout on a live run, and
the fixture has none for it:

```
$ nen repo scenario --repo scripts/fixtures/port-family/with-family --target fixture-owner/fixture-ios
swiftui-tca-uzf-v2
exit=0

$ nen repo scenario --repo scripts/fixtures/port-family/with-family --target fixture-owner/fixture-android
nen: 'fixture-owner/fixture-android' is recorded in <checkout>/scripts/fixtures/port-family/with-family/nen/repos.json (as product code 'FA' ('fixture-owner/fixture-android')), but on no row that can carry a 'scenario' field -- only consumers[], maintained_tools[] and pending_onboarding[] rows do, and a product_codes value is a name rather than a row. To give it one, add a row for it under maintained_tools[] if it is one of this registry's own tool repositories, pending_onboarding[] if it has not adopted the machinery yet, or consumers[] if it consumes it, with a 'scenario'.
exit=1
```

The dry run reads the target's scenario as *not read (no target checkout)*; the pair it would cite is
`swiftui-tca-uzf-v2--compose-uzf-v2` once the target's checkout declares `compose-uzf-v2`.

### § 2 — the precondition: merged into the source's base

`gh pr view 42 --repo fixture-owner/fixture-ios --json state,mergedAt,baseRefName,…` and `gh api
repos/fixture-owner/fixture-ios/pulls/42/files --paginate` — **not read** (a fixture slug). A live run proceeds
only on `mergedAt` set and `baseRefName` equal to the source's `branch.base` (absent, `main`), refuses naming
the state otherwise, and refuses a file list shorter than `changedFiles`. The three searches of § 2 — *already
ported*, *a port of a port*, *unported prerequisites* — are `nen issue search --target fixture-owner/fixture-android
--subject '(from FI-PR-#42)'` through `gh_token_env.sh`: **not run** for the same reason; a live run reads an
exit `1` as a refusal with the verb's line quoted, never as *no port*. Visibility: a private source to a public
target is refused (SEC-8) — not read here.

### § 3 — the run record's id

```
$ printf '%s' 'hiraishin-fi-pr-42-20261022' | grep -Ex '^(kamui|hiraishin)-[a-z]{2,3}-(is|pr)-[0-9]+-[0-9]{8}(-[0-9]+)?$'
hiraishin-fi-pr-42-20261022
exit=0
```

The record a live run writes at `${XDG_STATE_HOME:-$HOME/.local/state}/hatsu/ports/hiraishin-fi-pr-42-20261022.json`
(`caller: hiraishin`, one `targets[]` entry for `FA`); a second target the same day takes `-2`. **The dry run
writes none.** `grep -Ex` is shown for the shape only — the skill's validator is `re.fullmatch` or an
equivalent that refuses whitespace inside the token (*conventions*: `run_id` validation).

### § 4 — spec first: the family declares a spec repository

`families[]` lists both `FI` and `FA` (members ios and android) with `spec.repo: fixture-owner/fixture-spec`,
role `spec`, gate `G2`, so kamui § 2 runs by name — the same reads as [`kamui.md`](kamui.md) § 2, not repeated
here — then kamui § 3 on the shipped PR, whose search over the spec fixture finds nothing:

```
$ grep -rlwF -e 'FI-PR-#42' scripts/fixtures/spec-family/specs/ || echo 'no hit'
no hit
exit=0
```

A live run amends an existing folder or attaches to an open spec PR for the feature; none → a new folder
`specs/002-<slug>`, a spec PR at **G2**, kamui § 4's wait (`nen watch until --command "gh pr view <n> --repo
fixture-owner/fixture-spec --json state --jq .state" …` — **not run**). `MERGED` → § 5, `next: start`.

### § 5 — the port brief, one row per concept

The source PR's files are not readable offline, so the brief is drawn over the fixture spec's statements,
each a concept the port carries; *Handling* cites its entry in ports.md § *Mirror versus map*, never a
judgement:

```
$ grep -n 'AC-\|FR-\|SC-\|US-' scripts/fixtures/spec-family/specs/001-fixture-capability/spec.md
4:form once, an acceptance scenario's folder-global `AC-###` (SP-10), MUST only on a `declared` line (FR-002's `[ruled: CL-001]`), the Clarifications session shape, the prose-made line and a longer fence around a backtick run. Every path, sha and value is a placeholder;
25:### US-1 — A user opens the fixture list (Priority: [NEEDS RULING])
29:1. **AC-001**: **Given** an empty fixture list, **When** the user opens it, **Then** the empty state is shown. [src: FI:Tests/FixtureListTests.swift:12-20 @ 0000000000000000000000000000000000000001 · declared] [src: FA:app/src/test/FixtureListTest.kt:30-41 @ 0000000000000000000000000000000000000002 · declared]
39:- **FR-001**: The system shows the empty state when the list holds no item. [src: FI:Sources/FixtureList/FixtureListState.swift:40-52 @ 0000000000000000000000000000000000000001 · observed]
40:- **FR-002**: The system MUST keep the list's sort order across a restart. [ruled: CL-001]
41:- **FR-003**: The system refreshes the list on return to the screen. [UNVERIFIED]
42:- **FR-004**: The system removes an item the user deletes. [src: FW:src/fixture-list/selectors.ts:8-19 @ 0000000000000000000000000000000000000003 · observed] [STALE @ 0000000000000000000000000000000000000000]
50:- **SC-001**: The empty state appears within a typed threshold of opening the list. [NEEDS RULING]
60:- **CL-001** — Question as asked: *Is the sort order kept across a restart?* · Options shown: A kept · B reset to default · Answer, verbatim: `A kept` · Rules: FR-002.
exit=0
```

| Concept (its source) | Target equivalent | Ruling | Handling |
|---|---|---|---|
| the empty-state rule — FR-001, AC-001 (`FixtureListState.swift:40-52`) | the target's state container renders the same empty state | `unmapped` | `mirror: business rule`, `mirror: acceptance outcome` |
| sort order kept across a restart — FR-002 (ruled CL-001) | the target's persisted preference | `unmapped` | `mirror: data lifecycle (retain)` |
| refresh on return to the screen — FR-003 `[UNVERIFIED]` | — | `unmapped` | `mirror: business rule`; the marker is surfaced, never resolved by the port |
| the swipe-to-delete gesture behind FR-004 | the target's idiom | `unmapped` | `map: gesture` (UX-13's adapt list owns the UI half) |
| a list longer than one page (the edge case still carrying its clarification marker) | — | `unmapped` | `unclassifiable` — no entry names it; asked in § 6 |
| SC-001's threshold, its ruling marker still open | — | — | `mirror: acceptance outcome` once the spec rules the number; the port does not |

Below the table, the UZF-26 evidence the target PR owes. The brief is written to the session's scratch
directory and shown; nothing else is written.

### § 6 — drift, listed unasked

One batch per run through `bankai-rule` § 5 (`port-drift`, `ask-once-per-run`, three questions a call). The
dry run **lists** the questions and asks none: *a list longer than one page, on `compose-uzf-v2`* — **A** `map
to <equivalent>` (no existing pair row quotes one, so not starred) · **B** `mirror` · **C** `drop with note` ⭐ ·
**D** `target-only addition`. The `map: gesture` row cites the handbook rule on both sides on a live run (the
pair file through `--always-load` until zheref/nen#457). Each answer would bind at once and become one pair
row, with the spec's `## Platform decisions` and `port-ledger.md` written on hiraishin's amendment PR in the
same run (ports.md § *Product-level divergence*; HR-6).

### § 7 — the port issue's plan

Title, from *conventions*: `port: <source title> (from FI-PR-#42)` — the source title is not read, every `'`
would be typed `'\''`, a newline refused (zheref/nen#444). Labels: file § 5's, plus `job/parity`,
`job/implementation`, the target's `lang/kotlin`, kind `enhancement`; `direct`'s `model/<line>` under the
target's `direct.publish`. Body: *conventions*' port issue body — the fenced `source-data` block, the
`- AC-{n}: … (F002-AC-###)` rows, the android `tasks.md` rows, the folder at the merged ref, the brief, the
SEC-15 line, the source PR as a cross-reference and never a Development link. `nen issue file --dry-run
--target fixture-owner/fixture-android …` is **not run** (a fixture slug); its live form:

```
"$hatsu_root/scripts/gh_token_env.sh" nen issue file --target <owner/name> --repo <target checkout> --title '<escaped title>' --body-file <absolute brief.md> --label job/parity,job/implementation,lang/kotlin,… --assignee <user> --private-names-ignore-file <file § 4's ignore file> --json
gh issue view <n> --repo <owner/name> --json title,body,labels
```

### § 9 — the end: nothing written

No record, no issue, no spec PR, no label; missing setup (the checkouts file, [`kamui.md`](kamui.md) § 2.1)
reported, never set up. The build go is a separate typed call and never part of a dry run.

## 2. Findings against the binary and the fixtures

*File nothing from this document; this is the list.*

1. **The dangling `to` is still dropped at exit `0`** (`target: (clause absent)`) at nen `0.24.0` — verified
   live above. The refusal is the skill's own prose rule, as *conventions* say, until zheref/nen#366 lands.
2. **A target's scenario is not in the source's registry.** `nen repo scenario` refuses a code the source knows
   only under `product_codes` (exit `1`); hiraishin reads the target's own checkout (§ 1), and a dry run over one
   registry says *not read*. The same finding as [`kamui.md`](kamui.md) § 2, item 1, seen from the other skill.
3. **A brief over a fixture spec names no source files.** The concept cut is judgement over the merged PR's
   file list (hiraishin § *Residue*); with the list unread, the fixture spec's statements stand in and the table
   says so. A live brief carries the files.
4. **The spec's unverified, stale and needs-ruling markers travel into the brief as markers.** The port never
   resolves one: FR-003 is mirrored as stated and SC-001's number waits on the spec. Nothing in the skill
   says this in so many words; it follows from the spec being the product canon (HR-6) and the port issue
   carrying the scenarios verbatim.

## 3. Residue

The concept cut, the mapping and the prerequisite read are judgement; the file list is `gh api`
(hiraishin § *Residue*). Owed to nen, unchanged at `0.24.0`: a file-fed title (zheref/nen#444), the dangling
clause refused (zheref/nen#366), `families[]` and the `spec` role (zheref/nen#453), `watch until --until
merged` (zheref/nen#454), pair resolution beside the stack handbook (zheref/nen#457).

## 4. Readiness — the convergence table over a two-commit member (zheref/hatsu#447)

**Run: 2026-10-23 (UTC), nen built from source at `b313c909` (zheref/nen#517's stack top, version `0.27.0`,
unreleased; the contract pins `0.26.0`, which has none of these verbs), host `darwin` (arm64).** The table is
[`spec-repo.md`](../config/spec-repo.md) § *The convergence table at readiness*: hiraishin § 8, kamui § 8 and
en § 4 quote it beside `nen pr ready` for a parity PR. Inputs, built in the session's scratch directory
(`<scratch>`) and never pushed: a member `fixture-owner/fixture-web` (code `FW`, scenario `react-uzf-v1`, a
`tsconfig.json` over `src/`) with two commits — `12ab2772` *one* (`src/List.ts` sorts; `src/List.test.ts`
asserts it) and `effa98c6` *two* (the sort removed) — and a spec repository carrying
`scripts/fixtures/spec-family/spec-repo/nen/repos.json` and two folders: `specs/002-fixture-list` (an
`AC-001` scenario line, `FR-001` citing `FW:src/List.ts:1-3 @ 12ab2772`, `SC-001` citing the test line, and a
`parity.md` table `| FR | FI | FA | FW |` with `FW` `present` and its citation) and `specs/003-fixture-sort`
(one FR citing `FI` only). The checkouts file maps `fixture-owner/fixture-web` to the member. **No GitHub call
was made**; no `--write` ran, so nothing was appended.

```
$ nen --version
0.27.0
exit=0

$ nen spec inventory --repo <scratch>/member --scenario react-uzf-v1 --at 12ab2772937ef9dd0ac4e0e5f568f6002ca6efe8 --out <scratch>/inv-A.json
read: react-uzf-v1 fixture-owner/fixture-web @ 12ab2772937e -- 1 row(s) from 2 owned file(s) (tsconfig: tsconfig.json)
  totals: screen 0 · state 0 · event unknown · shifter 0 · selector 0 · producer 0 · service 0 · model 0 · flag unknown · strings unknown · analytics unknown · navigation unknown · test 1 (per case) · snapshot 0
  1 classified · 0 joined to another row · 1 unclassified · 0 excluded by --exclude
  wrote <scratch>/inv-A.json
exit=0

$ nen spec converge --repo <scratch>/spec --folder specs/002-fixture-list --inventory <scratch>/inv-A.json --code FW --checkouts <scratch>/checkouts
converged: specs/002-fixture-list against FW fixture-owner/fixture-web @ 12ab2772937e -- 0 missing · 0 partial · 0 contradicts · 0 unrequested · action none
  unrequested: not computed -- capture/FW/inventory.json does not exist, so there is no earlier capture to tell new rows from old ones
exit=0

$ nen spec inventory --repo <scratch>/member --scenario react-uzf-v1 --at effa98c65a0bef1ea6b3f1c5678c6d7e0e876499 --out <scratch>/inv-B.json
read: react-uzf-v1 fixture-owner/fixture-web @ effa98c65a0b -- 1 row(s) from 2 owned file(s) (tsconfig: tsconfig.json)
  totals: screen 0 · state 0 · event unknown · shifter 0 · selector 0 · producer 0 · service 0 · model 0 · flag unknown · strings unknown · analytics unknown · navigation unknown · test 1 (per case) · snapshot 0
  1 classified · 0 joined to another row · 1 unclassified · 0 excluded by --exclude
  wrote <scratch>/inv-B.json
exit=0

$ nen spec converge --repo <scratch>/spec --folder specs/002-fixture-list --inventory <scratch>/inv-B.json --code FW --checkouts <scratch>/checkouts
gaps: specs/002-fixture-list against FW fixture-owner/fixture-web @ effa98c65a0b -- 0 missing · 0 partial · 1 contradicts · 0 unrequested · action none
  contradicts FR-001 (spec.md:11) -- 1 changed at effa98c65a0b; the cited bytes read differently and are found nowhere else in the file -- a candidate for the spec-conflict ruling, never decided here
  unrequested: not computed -- capture/FW/inventory.json does not exist, so there is no earlier capture to tell new rows from old ones
  owed specs/002-fixture-list/spec.md:11 [STALE @ 12ab2772937ef9dd0ac4e0e5f568f6002ca6efe8]
  owed specs/002-fixture-list/tasks.md ## Phase 1: Convergence 2026-10-23
exit=1

$ nen spec converge --repo <scratch>/spec --folder specs/003-fixture-sort --inventory <scratch>/inv-B.json --code FW --checkouts <scratch>/checkouts
converged: specs/003-fixture-sort against FW fixture-owner/fixture-web @ effa98c65a0b -- 0 missing · 0 partial · 0 contradicts · 0 unrequested · action none
  unrequested: not computed -- capture/FW/inventory.json does not exist, so there is no earlier capture to tell new rows from old ones
exit=0

$ nen spec converge --repo <scratch>/spec --folder specs/009-fixture-none --inventory <scratch>/inv-B.json --code FW --checkouts <scratch>/checkouts
could-not-read: specs/009-fixture-none -- specs/009-fixture-none/spec.md does not exist; a folder with no spec.md has nothing to converge, which is not the same as converged
exit=1

$ nen spec parity --repo <scratch>/spec --folder specs/002-fixture-list
gaps: 1/3 requirement x member row(s) handled across 1 folder(s), members FA, FI, FW
  1 present · 0 mirror · 0 map · 0 drop-with-note · 0 target-only · 0 differs · 1 absent · 1 open · 0 malformed
  F002-FR-001 FA absent -- not a handling
  F002-FR-001 FI open -- no state recorded yet
  F002-FR-001 FW present
exit=1
```

**The table those outputs give** (converge's `--json` `citations` and `gaps`, then the parity row, quoted):

| Requirement | At `12ab2772` | At `effa98c6` | Evidence |
|---|---|---|---|
| FR-001 | `current` | `contradicts` | `src/List.ts:1-3 @ 12ab2772`, the bytes changed and found nowhere else |
| SC-001 | `current` | `current` | `src/List.test.ts:2-2 @ 12ab2772` |
| parity `F002-FR-001 FW` | `present` | `present` | its own `FW` citation |

- **AC-1, AC-2**: at `12ab2772` the table reads converged (two citations, both current; the `FW` parity row
  settles); at `effa98c6` the `contradicts` row makes the PR **not ready**, quoted, whatever `nen pr ready`
  says — and it is `spec-conflict`'s candidate, never decided here.
- **AC-3**: `specs/009-fixture-none` reads `could-not-read` (exit `1`), never converged; and
  `specs/003-fixture-sort`, which never cites `FW`, reads **`converged` over zero citations** (exit `0`,
  `citations: []`) — the verb's fact about no bytes, which the table reads as *could not read: no target
  citation*, not converged.
- **Not keyed by scenario**: the `AC-001` line carries a citation, yet converge's rows are `FR-001` and
  `SC-001` only; it reads FR, SC and story lines. zheref/hatsu#447's AC-1 asks one row per acceptance
  scenario; the verb gives one per requirement, so the table is keyed by requirement until it does.
- **AC-4** is not exercised here: the port ledger is read before the brief (ports.md), unchanged.
