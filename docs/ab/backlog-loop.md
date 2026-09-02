# A/B evidence — `backlog-loop` (zheref/hatsu#2)

Port of `claude/skills/backlog-loop/SKILL.md`: drive `bankai-core`'s backlog to zero open
actionable issues, in severity order, as G4-ready PRs. The old skill's own deterministic steps were
either raw `gh`/hand-reasoning (fetch, severity-order sort, the concurrency cap, the gate-stop
table) or CI-plane machinery this port structurally cannot reuse at all (the wake-verification half
of § 4, the `probe`/`build` job distinction) because Hatsu holds no CI plane. New mechanics: `nen
backlog fetch|order`, `nen loop slots`, `nen pr staleness`, `nen tag cut`, `nen fanout
compute|record`, `nen changelog collate|completeness|fragment-required`,
`nen board build|render`, `nen stop`, `nen parse`, `nen repo resolve` — plus a deliberate
delegation of every issue→PR and PR→Ready step to the already-landed `build`/`drive` ports, per
`SKILL.md` § 0's declared structural adaptation.

Run: 2026-09-02, UTC times as logged by each command. `nen` `0.1.0`
(`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`). `gh` authenticated as `zheref`. All
commands below ran **read-only** against the live `zheref/bankai-core` repository (backlog fetch,
`changelog completeness`, `fanout compute`), against a **scratch copy** of `bankai-core`'s own
`CHANGELOG.md` (never the real checkout — `changelog collate` without
`--write`), or against local scratch JSON/markdown with **no GitHub write of any kind**. `nen label
apply`, `nen tag cut`, `nen wake fire`, and `nen changelog collate --write` (the four mutating
verbs this port's text cites) were **never exercised live** against `zheref/bankai-core` — contract
inspected only, per the shared brief's rule and the identical precedent `pr-state`'s and
`backlog-state`'s own A/B docs already set (`docs/ab/pr-state.md`, `docs/ab/backlog-state.md`). `nen
fanout record` is exercised live because it writes **only** a local scratch ledger file, never
GitHub — confirmed in § 2.11.

---

## 1. Command mapping table

| # | Old (prose / raw `gh`) | New (`nen`) |
|---|---|---|
| 1 | § 1 "Fetch every open `bankai-core` issue with its labels, comments, linked PRs and current check/review state. Never work from a cached list" | `nen backlog fetch --repo-slug <owner/name> --json` — paginated, never cached, `truncated` reported explicitly (verified live, § 2.3) |
| 2 | § 2 "Propose a severity ... Apply it" — a raw `gh issue edit --add-label` implied | `nen label apply <ref> --label bankai:severity/<level> --repo-slug <owner/name> --reason ... --run` — contract-verified only (§ 3), same verb `build`'s own port already contract-maps for `bankai:stage/building` |
| 3 | § 2's whole priority order — "severity first ... within a severity: blocks, affects consumers, age" — hand-sorted | `nen backlog order --rows-from <path> --severity-order critical,high,medium,low [--blocks <id,...>] [--affects-consumers <id,...>]` — verified live against the real 88-row backlog (§ 2.4) |
| 4 | § 4 "Work at most TWO issues ... Never three" — eyeballed | `nen loop slots --efforts efforts.json --local-cap 2 --json` — verified live, occupied/free/binding computed (§ 2.5) |
| 5 | § 4's whole CI-routing + wake-verification half — "apply the lane label ... verify the wake actually reached the builder ... a `probe` that is `cancelled` with no `build` job" | **No replacement** — this is the declared structural change (`SKILL.md` § 0, § 6): the issue→PR step is `build`'s engine, the PR→Ready step (including any wake) is `drive`'s engine. This skill never routes to a CI agent and never fires or verifies a wake itself |
| 6 | § 4's stale-chore-sub-PR merge bar — "≥2 wake attempts producing no commit, ≥60 min since last activity" — hand-counted | `nen pr staleness --wakes-from <path> --last-activity <ISO> --now <ISO> [--ready]` — verified live, both cases (§ 2.6), byte-identical to `drive`'s own proof |
| 7 | § 6's tag-cut trigger table — "All critical merged → tag-cut + fan-out" etc., executed by hand | `nen tag cut --repo <path> --name <vX.Y.Z> --at <sha> [--push]` — contract inspected only (§ 3) |
| 8 | § 6 "Collate `changelog.d/` fragments ... via `scripts/changelog_collate_fragments.sh`" | `nen changelog collate --version ... --theme ... --changelog ... --fragment-dir ... [--write]` — verified live on a scratch copy without `--write` (§ 2.9); `--write` itself contract inspected only (§ 3) |
| 9 | § 6 "Compute affected consumers factually (`changed-workflows ∩ consumes`), open a repin PR to each, record every unaffected consumer as an explicit N/A" — hand-computed | `nen fanout compute --range <vPrev>..<vNew>` — verified live against the real `v0.11.2..v0.11.3` range (§ 2.10); `nen fanout record --ledger <path>` for the audit trail — verified live, local-only write (§ 2.11) |
| 10 | § 7's `docs/Loop/<run-id>/` write and § 8's hand-formatted status table + `scripts/ichigo_board.sh` | `nen board build`/`nen board render` — verified live, including a `refs`-shape finding (§ 2.12); `nen stop --who Kurapika --gate <Gn> board.md` for the gate banner — verified live (§ 2.13) |
| 11 | This skill's own resolution of "which repo" — no command given in the old skill's prose at all (it hard-coded `bankai-core` throughout) | `nen parse backlog-loop --grammar "<repo>" --line "<invocation>"` (§ 2.1) then `nen repo resolve <CODE> --repo <path>` (§ 2.2) — generalized across repos, same as every other ported skill in this wave |
| 12 | CON-33(a)'s "does this change owe a fragment" check — read by eye | `nen changelog fragment-required --spec-paths ... --fragment-dir ... --files-from ... --head-changelog ...` — verified live against the real `zheref/bankai-core#940` (§ 2.8) |
| 13 | CON-33(c)'s "every merged PR has an entry" completeness check — read by eye | `nen changelog completeness --range ... --changelog ... --owner-repo ...` — verified live against the real `v0.11.2..v0.11.3` range (§ 2.7) |

**Count.** Before: **zero** deterministic steps in §§ 1–2, 4, 6–8 of the old skill — fetch,
severity triage, priority ordering, the concurrency cap, the tag-cut trigger table, changelog
collation/completeness, fan-out computation, and the status board were all agent prose, raw `gh`,
or a shell script invoked by hand. After: **eleven** of those (rows 1, 3, 4, 6, 7 (contract), 8, 9,
10, 11, 12, 13) are now single `nen` verb calls, seven of them verified live against the real
`zheref/bankai-core` repository or a faithful scratch copy of it, four contract-inspected only
because they mutate GitHub or an immutable git object (label apply, tag cut, `changelog collate
--write`, and — inherited — wake fire). What remains prose: severity/mode reasoning (§ 4 of the
skill), critical-preemption/low-deferral/seize-the-wait (§ 5), the live-chore detection ahead of a
cut (§ 8), and — genuinely new, not present in the old skill at all — the entire "this is `build`
and `drive`'s job, not restated here" declared-change paragraph that used to be the CI
routing/wake-verification machinery (row 5).

---

## 2. Live A/B transcript (read-only, or against a scratch copy where noted)

### 2.1 — `nen parse backlog-loop`, a working single-slot grammar

```
$ nen parse backlog-loop --grammar "<repo>" --line "BC" --json
{
  "skill": "backlog-loop", "template": "<repo>", "line": "BC", "ok": true,
  "slots": [{"name":"repo","value":"BC","suffix":false}],
  "missing": [], "problems": [],
  "corrected": "backlog-loop BC",
  "echo": ["repo: BC"]
}

$ nen parse backlog-loop --grammar "<repo>" --line ""
nen parse: <repo> is required and the line does not supply it.

Corrected line:
  backlog-loop <repo>
```

A single slot with no bracketed clause — unlike `backlog-state`'s own `<repo>[@<gate>]` template
(that port's own A/B doc § 3, a live bracket-swallowing defect), there is no optional clause here
for the same gap to bite. Genuinely mechanized, not routed around.

### 2.2 — `nen repo resolve`, case-insensitive

```
$ nen repo resolve BC --repo <bankai-core checkout>
zheref/bankai-core  (BC)  via code

$ nen repo resolve bc --repo <bankai-core checkout>
zheref/bankai-core  (BC)  via code
```

Same verb, same behavior every sibling port already confirmed (`docs/ab/build.md` § 2.2); not
re-derived differently here.

### 2.3 — `nen backlog fetch`, the real `zheref/bankai-core` backlog

```
$ export GH_TOKEN=$(gh auth token)
$ nen backlog fetch --repo-slug zheref/bankai-core --json > bloop-fetch.json
$ python3 -c "import json; d=json.load(open('bloop-fetch.json')); print('truncated:', d['truncated']); print('rows:', len(d['rows']))"
truncated: False
rows: 88
```

Severity distribution off the fetched rows' own `labels[]` (`bankai:severity/*`), computed by this
port, not by the verb: `medium: 60, low: 14, high: 7, untriaged (no severity label): 7`. **No
`critical` currently open** — the loop's own critical-preemption rule (`SKILL.md` § 5) has nothing
to preempt against today; this is a fact about the live backlog at run time, not a limitation of
the verb.

### 2.4 — `nen backlog order`, the real backlog, severity + `--blocks` tie-break

Rows reshaped to `{id, severity, createdAt, number}` (`id` = `BC-IS-#<issueNumber>`, `severity`
read off the `bankai:severity/*` label or `"untriaged"` when absent):

```
$ nen backlog order --rows-from bloop-rows.json --severity-order critical,high,medium,low --json
```

The 7 real `high` rows sort strictly ahead of every `medium`/`low`/`untriaged` row, oldest-first
within the band:

```
BC-IS-#877  2026-08-29T17:16:02Z  severityRank:1
BC-IS-#878  2026-08-29T17:43:13Z  severityRank:1
BC-IS-#879  2026-08-29T20:06:05Z  severityRank:1
BC-IS-#918  2026-09-01T17:35:29Z  severityRank:1
BC-IS-#928  2026-09-01T18:26:51Z  severityRank:1
BC-IS-#929  2026-09-01T18:26:57Z  severityRank:1
BC-IS-#937  2026-09-01T22:55:36Z  severityRank:1
BC-IS-#494  2026-08-21T16:31:24Z  severityRank:2   <- first medium row
...
```

The 7 `untriaged` rows all report `severityRank: null` and sort after every recognised severity —
confirmed against real objects, not synthetic ones, matching `backlog-state`'s own already-proven
"unrecognised severity ranks last" finding for this verb.

**`--blocks` — bare numbers silently no-op; the row's `id` string works:**

```
$ nen backlog order --rows-from bloop-rows.json --severity-order critical,high,medium,low --blocks 928,929 --json
# high band unchanged: all 7 rows still oldest-first, blocksOther:false for every one

$ nen backlog order --rows-from bloop-rows.json --severity-order critical,high,medium,low --blocks "BC-IS-#928,BC-IS-#929" --json
BC-IS-#928  2026-09-01T18:26:51Z  blocksOther:true   <- promoted to the front
BC-IS-#929  2026-09-01T18:26:57Z  blocksOther:true   <- promoted to the front
BC-IS-#877  2026-08-29T17:16:02Z  blocksOther:false
BC-IS-#878  2026-08-29T17:43:13Z  blocksOther:false
BC-IS-#879  2026-08-29T20:06:05Z  blocksOther:false
BC-IS-#918  2026-09-01T17:35:29Z  blocksOther:false
BC-IS-#937  2026-09-01T22:55:36Z  blocksOther:false
```

**Confirmed: the flag reads the row's own `id` field, not the bare `number`.** `--help`'s own
`<n,n>` notation reads as "numbers," and passing bare numbers is silently accepted with no error and
no effect — a caller who follows the literal help text produces silently wrong ordering, not a
refusal. Filed (`SKILL.md` § 12, finding 1).

### 2.5 — `nen loop slots`, local-plane concurrency

```
$ cat bloop-efforts1.json
[
  {"id":"BC-IS-#877","plane":"local","prOpen":false,"ready":false,"prompted":false},
  {"id":"BC-IS-#878","plane":"local","prOpen":true,"ready":false,"prompted":false}
]

$ nen loop slots --efforts bloop-efforts1.json --local-cap 2 --json
{"ci":{"plane":"ci","cap":2,"occupied":0,"free":2,"holding":[],"binding":false},
 "local":{"plane":"local","cap":2,"occupied":2,"free":0,
   "holding":[{"id":"BC-IS-#877","why":"authored locally, no PR yet"},
              {"id":"BC-IS-#878","why":"PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it"}],
   "binding":true},"done":[]}
(exit 1)

$ nen loop slots --efforts bloop-efforts1.json --json      # no --local-cap at all
{"local":{"plane":"local","cap":7, ...}, "ci":{"plane":"ci","cap":2, ...}}
(exit 0)
```

Reconfirms `build`'s own already-filed finding on this identical verb (`docs/ab/build.md` § 2.10):
the default local-plane cap is `7`, not `2`. This port always passes `--local-cap 2` explicitly
(`SKILL.md` § 12, finding 3, cross-referenced rather than re-filed as new).

### 2.6 — `nen pr staleness`, reconfirming `drive`'s own proof

```
$ cat bloop-wakes.json
[{"at":"2026-09-01T20:00:00Z","noCommit":true},{"at":"2026-09-01T21:00:00Z","noCommit":true}]

$ nen pr staleness --wakes-from bloop-wakes.json --last-activity 2026-09-01T21:00:00Z --now 2026-09-01T22:30:00Z
stale
merge not permitted
2/2 verified no-commit wake(s) (met)
90/60 idle minute(s) (met)
stale, but NOT Ready -- no merge is permitted; a stale, not-ready PR is still owned by its author

$ nen pr staleness --wakes-from bloop-wakes.json --last-activity 2026-09-01T21:00:00Z --now 2026-09-01T22:30:00Z --ready
stale
merge PERMITTED (stale + Ready)
2/2 verified no-commit wake(s) (met)
90/60 idle minute(s) (met)
```

Byte-identical to `drive`'s own proof (`docs/ab/drive.md` § 2.7) — this port re-ran it independently
rather than only citing it, since `backlog-loop` calls the same verb for the same reason (the
wake-attempt log it asks `docs/Loop/<run-id>/` to carry doubles as this verb's own input, same
simplification `drive`'s own A/B § 5 already names).

### 2.7 — `nen changelog completeness`, the real historical release range

```
$ nen changelog completeness --range v0.11.2..v0.11.3 --changelog CHANGELOG.md --owner-repo zheref/bankai-core
every PR merged in v0.11.2..v0.11.3 has a CHANGELOG entry or fragment.
(exit 0)
```

Run from inside the real `bankai-core` checkout, read-only — no write, no `--fragment-dir` needed
since the range is fully collated already.

### 2.8 — `nen changelog fragment-required`, the real `BC-PR-#940`

```
$ gh pr diff 940 --repo zheref/bankai-core --name-only > pr940-files.txt
changelog.d/937-bc11-frozen-line-patch.md
cli/src/guards/bc11-allowlist.txt
cli/src/guards/bc11.repo.test.ts
cli/src/guards/bc11.test.ts
cli/src/guards/bc11.ts
handbooks/stacks/bankai-core/architecture.md

$ nen changelog fragment-required --spec-paths "CONSTITUTION.md,handbooks/,agents/,schemas/,.github/workflows/,cli/" \
    --fragment-dir changelog.d --files-from pr940-files.txt --head-changelog CHANGELOG.md
release-move
release move recognized (changelog.d/ fragment(s) collated and deleted, Unreleased already empty, new dated section landed) -- satisfied natively, so a release PR needs no opt-out to empty Unreleased
(exit 0)
```

Real diff, real repo, genuinely read-only.

### 2.9 — `nen changelog collate`, without `--write`, on a scratch copy

**Never run against the real `bankai-core` checkout** — a scratch copy of its real `CHANGELOG.md`
plus a synthetic fragment, in a throwaway directory:

```
$ mkdir -p scratch/changelog.d && cp <bankai-core>/CHANGELOG.md scratch/CHANGELOG.md
$ cat > scratch/changelog.d/999-test-fragment.md <<'EOF'
### Test fragment (scratch, never real)
- what: nothing, this is a dry-run proof
EOF
$ cd scratch
$ md5sum CHANGELOG.md
465e674bbefb10f34be12b3632288870  CHANGELOG.md

$ nen changelog collate --version v0.11.4-test --theme "scratch dry run" --changelog CHANGELOG.md --fragment-dir changelog.d
(no --write) would collate 1 fragment(s) into CHANGELOG.md ### v0.11.4-test — scratch dry run
  999-test-fragment.md
(exit 0)

$ md5sum CHANGELOG.md
465e674bbefb10f34be12b3632288870  CHANGELOG.md   <- unchanged
$ ls changelog.d
999-test-fragment.md   <- still present, never deleted
```

**Confirmed genuinely read-only without `--write`**: the file hash is identical before and after,
and the fragment file was not consumed. `--write` itself (which would delete the fragment and
rewrite `CHANGELOG.md`) is never exercised against the real, frozen `bankai-core` — contract
inspected only (§ 3).

### 2.10 — `nen fanout compute`, the real historical release range

```
$ nen fanout compute --range v0.11.2..v0.11.3 --json
{
  "range": "v0.11.2..v0.11.3",
  "changedWorkflows": [21 real workflow basenames, e.g. "bankai.yml", "roy-build.yml", ...],
  "rows": [
    {"repo":"zheref/KroApple","code":"KP","status":"affected",
     "matchedWorkflows":["cascade-ancestry-guard.yml","db-migrate.yml","handbook-question-dedupe.yml","roy-build.yml","sync-canon.yml"],
     "basis":"consumes cascade-ancestry-guard.yml, db-migrate.yml, handbook-question-dedupe.yml, roy-build.yml, sync-canon.yml, which changed in this range"},
    {"repo":"zheref/KroAndroid","code":"KN","status":"affected",
     "matchedWorkflows":["roy-build.yml","sync-canon.yml","cascade-ancestry-guard.yml","handbook-question-dedupe.yml"],
     "basis":"..."},
    {"repo":"zheref/bankai-scaffold","code":"BS","status":"affected",
     "matchedWorkflows":["kisuke-build.yml"], "basis":"..."}
  ]
}
(exit 0)
```

Real range, real consumers, every row `affected` with a stated basis — no silent `n/a`, genuinely
read-only.

### 2.11 — `nen fanout record`, local-only write, no GitHub call

```
$ nen fanout record --range v0.11.2..v0.11.3 --ledger bloop-fanout-ledger.jsonl
recorded 3 row(s) to .../bloop-fanout-ledger.jsonl
(exit 0)

$ cat bloop-fanout-ledger.jsonl
{"range":"v0.11.2..v0.11.3","at":"2026-09-02T02:27:16.553Z","repo":"zheref/KroApple", ...}
{"range":"v0.11.2..v0.11.3","at":"2026-09-02T02:27:16.553Z","repo":"zheref/KroAndroid", ...}
{"range":"v0.11.2..v0.11.3","at":"2026-09-02T02:27:16.553Z","repo":"zheref/bankai-scaffold", ...}
```

Three JSON lines appended to a scratch path outside any tracked checkout. Same underlying
computation as § 2.10, plus a local audit trail — no GitHub API call beyond what `compute` itself
already made (a read), confirmed by watching the command open no additional network state and by
the ledger path being the only file that changed. Safe to run live, unlike every other write in
this doc.

### 2.12 — `nen board build`/`render`, a `refs`-shape finding

**First attempt — `refs` as a plain string, per a naive reading of `backlog-state`'s own doc:**

```
$ cat bloop-boardrows.json
[{"id":"BC-IS-#877", "refs":"BC-IS-#877", ...}]

$ nen board build --repo-slug zheref/bankai-core --rows-from bloop-boardrows.json --json
nen board: row.refs.join is not a function. (In 'row.refs.join(", ")', 'row.refs.join' is undefined)
(exit 1)
```

**Corrected — `refs` as an array, one element per `nen ref format` output:**

```
$ nen ref format --code BC --kind IS --number 877 --state open \
    --url "https://github.com/zheref/bankai-core/issues/877" --no-glyphs --repo <bankai-core checkout>
[BC-IS-#877](https://github.com/zheref/bankai-core/issues/877)

$ cat bloop-boardrows3.json
[
  {"id":"BC-IS-#877","title":"[oldest open high-severity issue]",
   "refs":["[BC-IS-#877](https://github.com/zheref/bankai-core/issues/877)"],
   "gate":"","status":"in_progress","needs":"Triage next move"},
  {"id":"BC-IS-#937","title":"Record the BC-11 frozen-line ruling",
   "refs":["BC-IS-#937","BC-PR-#940"],
   "gate":"G4","status":"ready_g2_g4","needs":"Merge -- maintainer only"}
]

$ nen board build --repo-slug zheref/bankai-core --rows-from bloop-boardrows3.json --json > board.json
(exit 0)
$ nen board render --board-from board.json
zheref/bankai-core -- generated 2026-09-02T02:26:45.410Z

| Effort                              | Refs                                                            | Status (gate)     | Needs                     |
| ------------------------------------ | ---------------------------------------------------------------- | ------------------- | --------------------------- |
| [oldest open high-severity issue]   | [BC-IS-#877](https://github.com/zheref/bankai-core/issues/877) | in_progress ()     | Triage next move          |
| Record the BC-11 frozen-line ruling | BC-IS-#937, BC-PR-#940                                          | ready_g2_g4 (G4)  | Merge -- maintainer only  |
```

**Confirmed: `refs` must be an array of pre-formatted strings, never a plain string.** A caller who
joins the refs into one string before calling `board build` gets an unhandled crash, not a friendly
validation error. Filed (`SKILL.md` § 12, finding 2). (The bare `status` string is rendered
verbatim, unresolved through `colors.yml`, reconfirming `backlog-state`'s own finding that `board
render` never itself resolves a colour glyph — the caller passes the resolved glyph in.)

### 2.13 — `nen stop`, the gate banner for a backlog-loop-shaped row

```
$ cat bloop-efforts.md
| Effort | Refs | Status (gate) | Needs |
| --- | --- | --- | --- |
| Untriaged issue needs a severity proposal | BC-IS-#938 | 🟡 | Confirm proposed severity |

$ nen stop --who Kurapika --gate G5 bloop-efforts.md
=== YOUR INPUT IS NEEDED ==============================
who: Kurapika
gate: G5 -- decision / human-only action
rung 1 (push notification): NOT fired -- the caller's to have sent, before this renders.
rungs 2-3 (OS notification, audible cue): not fired by nen -- only git/gh subprocesses are ever shelled out to.
see the table below. No banner above => nothing needs you right now.

| Effort                                    | Refs       | Status (gate) | Needs                     |
| ------------------------------------------ | ------------ | --------------- | --------------------------- |
| Untriaged issue needs a severity proposal | BC-IS-#938 | 🟡            | Confirm proposed severity |
```

Renders the banner, both notification-rung status lines, and the padded table from a plain
pipe-table input — exactly as `--help` documents, reconfirming `build`/`drive`'s own identical
proof of this verb.

---

## 3. Mutating verbs — contract inspection only (never exercised against `bankai-core`)

Per the shared brief's boundary: these MUTATE GitHub or an immutable git object, and are never
fired at the real, frozen `zheref/bankai-core` by this port. Their full `--help` contracts (from
the pinned `v0.1.0` binary) are what `SKILL.md` cites; no dry run against `zheref/hatsu` was
attempted either, for the same reason `pr-state`/`backlog-state`'s own A/B docs already gave (none
was genuinely needed to write the skill).

- **`nen label apply <object-ref> --label <name> --repo-slug <owner/name> [--reason <text>]
  [--ledger <path>] [--run]`** — used here for `bankai:severity/*` triage (§ 4 of the skill). Same
  verb `build`'s own port contract-maps for `bankai:stage/building`; the flag-by-flag mapping is
  unchanged (object → `<object-ref>`, label → `--label`, logged decision → the ledger, `--run`
  gating GitHub writes vs. a `dry-run` ledger record).
- **`nen tag cut --repo <path> --name <vX.Y.Z> --at <sha> [--message <text>] [--trunk main]
  [--push]`** — creates a real, annotated git tag object even without `--push` (locally only in
  that case). `--at` has no default and is never `HEAD`; the verb refuses a name that already
  exists locally or on origin, or an `--at` not an ancestor of `origin/--trunk`.
- **`nen changelog collate ... --write`** — the writing half of § 2.9's verified-read-only dry
  path; deletes collated fragments and rewrites `CHANGELOG.md` in place.
- **`nen wake fire`/`nen wake verify --run`** — inherited from `drive`'s own § 5–6
  (`docs/ab/drive.md` § 3); this skill never calls either itself (`SKILL.md` § 6's residual-wake
  paragraph), so they are named here for completeness of the authority table, not re-mapped.

No behavioural gap found in any of these contracts themselves.

---

## 4. Findings (report separately, do not route around)

1. **`nen backlog order`'s `--blocks`/`--affects-consumers` silently no-op on a bare issue number**
   rather than refusing, even though `--help`'s own `<n,n>` example notation reads as "numbers."
   Reproduced live (§ 2.4): passing `928,929` produces no error and no change in ordering; passing
   the row's own `id` string (`BC-IS-#928,BC-IS-#929`) works exactly as documented. A caller who
   follows the literal help text gets silently wrong output, not a loud refusal.
2. **`nen board build` crashes uncaught (`row.refs.join is not a function`) when `refs` is a plain
   string instead of an array.** Reproduced live (§ 2.12). The documented `BoardRow` shape does not
   itself say `refs` must be pre-built as an array of `nen ref format` outputs — a caller has to
   infer the array requirement from the crash, or from having already read `backlog-state`'s own
   worked example closely enough to notice its `refs` cells were always arrays under the hood.
3. **(Reconfirmed, not newly filed)** `nen loop slots`'s local-plane default cap is `7`, first
   filed against `build` (`docs/ab/build.md` § 2.10); reproduced identically here (§ 2.5) because
   this skill calls the verb independently, for the same reason.
4. **(Cited, not re-exercised)** `nen pr fetch`/`nen pr next-blocker` are broken against every real
   `zheref/bankai-core` PR tried — filed against `drive` (`docs/ab/drive.md` § 4), whose engine this
   skill delegates all PR-shaped work to. `backlog-loop` never calls either verb itself.

---

## 5. Residue

- **Judgment kept, per the shared brief's boundary list**: severity/mode reasoning (`SKILL.md`
  § 4), critical-preemption / low-deferral / seize-the-wait (§ 5), the G5 diagnosis on a stuck
  `build`/`drive` escalation (delegated, reported on the board), and the closing narration of what
  shape the backlog collapses into.
- **The live-chore detection ahead of a tag-cut** (`SKILL.md` § 8) — "the chore's issue is open AND
  its `integration/<chore>` branch exists" — has no `nen` verb; a plain `gh issue view`/`git
  branch -r` composite check, same residue `build`'s own port already names for the identical
  structural gap (no live chore exists today to test it against — `bankai-core`'s own taxonomy
  carries no `chore` label at all, `docs/ab/build.md` § 2.7/§ 2.9).
- **Opening a fan-out consumer's repin PR** is a plain `gh pr create` per row; `nen fanout record`
  only logs the decision, never opens anything (§ 2.11).
- **Keeping exactly one `bankai:stage/*` label on an object at a time** (`CON-9`) is `build`'s own
  residue, unchanged — `nen label apply` applies and logs exactly the one label it is given.
- **The entire CI-wake-verification half of the old skill's § 4** has no replacement here, by
  design — it verified a plane (CI builders) Hatsu does not have. `drive` carries the narrower,
  genuinely-still-meaningful residual case (an externally-authored PR); this port never re-derives
  or duplicates that authority (`SKILL.md` § 6).
- Verdict parity between `nen pr ready` and `scripts/pr_ready_gate.sh` was already proven across
  the live estate by `nen`'s shadow window (`docs/evidence/shadow-window-p1.md` in `zheref/nen`)
  and re-confirmed for this repository by `pr-state`'s own A/B (`docs/ab/pr-state.md`) — this skill
  never calls `nen pr ready` itself (that is `build`/`drive`'s job), so it is cited, not re-proven a
  third time.
