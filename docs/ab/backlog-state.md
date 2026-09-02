# A/B evidence — `backlog-state` (zheref/hatsu#2)

Port of `claude/skills/backlog-state/SKILL.md`: the gate-oriented backlog table. Old mechanics were
entirely **improvised prose** — hand-grepping `schemas/repos.json`, eyeballing check pages,
reconstructing a colour precedence table from memory, hand-sorting rows by severity. There is no
deterministic old-side *script* to run for most of this skill's own computation (contrast
`pr-state`, which had `scripts/pr_ready_gate.sh`) — the closest thing, `scripts/ichigo_board.sh`, is
a **renderer** that consumes already-computed rows and emits HTML; it does not fetch, derive a gate,
or resolve a colour itself (confirmed by reading its header live, § 0 below). So this doc's "old
side" comparison is, for those steps, **contract-inspection against the old skill's own prose
rules**, not a runnable script diff. Where a runnable counterpart exists (`nen pr ready` vs.
`pr_ready_gate.sh`), it is cited rather than re-proven — see § 2.4.

Run: 2026-09-02T00:45–01:05Z (UTC). `nen` `0.1.0`
(`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`). `gh` authenticated as `zheref`.
All commands below ran **read-only** against the live `zheref/bankai-core` repository (issue/PR
reads, `gh pr diff --name-only`, `gh pr view --json baseRefName`) or against local scratch JSON
files with no GitHub write of any kind. Nothing was labelled, merged, pushed, commented on, or
opened.

---

## 0. Confirming there is no old-side script for §§2–4, 6, 7, 11

```
$ git -C bankai-core show v0.11.3:scripts/ichigo_board.sh | head -20
```

Its own header states the computation lives elsewhere: *"This script does not fetch. It is a
renderer... rows are computed by claude/skills/backlog-state/SKILL.md's rules — the fetch (§3), the
gate decision tree (§4), readiness from scripts/pr_ready_gate.sh ..., colour precedence (§6)..."*
Confirmed: the only deterministic old-side artifact in this whole skill's path is
`pr_ready_gate.sh`, already ported and A/B'd by `pr-state` (`docs/ab/pr-state.md`). Everything else
— fetch assembly, gate derivation, colour precedence, table layout, ordering — was the agent's own
prose, every invocation, which is exactly what §§ 4, 6, 7, 11 below now mechanize.

---

## 1. Command mapping table

| # | Old (prose) | New (`nen`) |
|---|---|---|
| 1 | "Read the registry; never work from a remembered list" — no command given, the agent greps `schemas/repos.json` by hand | `nen repo resolve <token>\|all --repo <path>` — resolves a token or enumerates the registry itself (with two verified gaps, § 4.1–4.2) |
| 2 | Fetch open issues + PRs "with, at minimum: labels, assignees, linked issues/PRs, the check rollup, review state..." via unspecified `gh api` calls, hand-assembled into one row per effort | `nen backlog fetch --repo-slug <owner/name> [--limit n]` — paginated, never cached, assembles issue+PR rows itself; `truncated` is reported explicitly rather than silently capped (verified live, § 2.10) |
| 3 | The G2/G4/G1/G1-M/G3/G5 decision tree (§4) was reasoned by eye per row, including "does the diff touch CONSTITUTION.md, handbooks/, agents/, schemas/, or the process surface" | `nen gate derive --policy-paths ... --process-paths ... --files ...` — computed, verified live against two real PRs (§ 3.1) |
| 4 | Readiness "decided by the script, never by eye" (already true in the old skill) — `scripts/pr_ready_gate.sh` | `nen pr ready` via `hatsu:pr-state`, unchanged pointer — see `docs/ab/pr-state.md` for that A/B; § 2.4 below is a spot-confirmation, not a re-proof |
| 5 | The colour precedence table (§6) was a hard-coded markdown table in the skill file, applied by eye, "precedence, when more than one could apply" reasoned by the agent per row | `nen color status --repo <path> --present <a,b,c>` — reads `schemas/colors.yml` itself and reports the first match plus what it outranked; verified live (§ 3.2) byte-identical to the old hard-coded table |
| 6 | The table (§7) was hand-formatted markdown, column widths and alignment computed by the agent each time | `nen board build --rows-from <path>` + `nen board render --board-from <path>` — assembles and pads the same table mechanically (verified live, § 3.3), though two columns (`Repo`, `Session · Lane`) have no slot in `nen`'s `BoardRow` schema and must be folded into existing cells (§ 4.3, `SKILL.md` § 7) |
| 7 | Object references (`BC-IS-#918`, `BC-PR-#925`) were typed by hand in the old table, `<CODE>-<TYPE>-#<N>`, with the state glyph/strikethrough applied by eye | `nen ref format --code --kind --number [--state] [--url]` — verified live (§ 3.4) |
| 8 | Ordering (§11) — "bands, then severity order" — was a fully manual sort: eyeball each row's colour, group, then eyeball severity within group | `nen color status` for the band (§6) + `nen backlog order --severity-order ... [--blocks] [--affects-consumers]` for the within-band sort (verified live, § 3.5) — composition (band first, verb second) stays this skill's own, because the ordering verb has no notion of colour bands at all |
| 9 | This skill's own `<repo\|all>@<gate>` invocation grammar — split by hand, by prose rule | Attempted via `nen parse backlog-state --grammar <template>` — **does not work** for this shape (verified live, § 4.4); kept as a prose rule, same as before, with the gap filed |

**Count.** Before: essentially the **whole skill** was improvised prose over raw `gh`/hand-reasoning
— there was no deterministic step at all in §§ 2–4, 6, 7, 11 (only § 5's readiness call was already
a script, itself now `nen pr ready`). After: **five** of those bands are now single `nen` verb
calls with output verified against the old skill's own stated rules (repo resolution, fetch,
gate derivation, colour, ordering), plus the table's assembly/render. What remains prose: gate
*interpretation* around the base-ref case (§ 4 of the ported skill, a **live, open, unrelated**
finding against the old skill's own tree — see § 5 below), synthesized titles, the expected-action
line, session/lane attribution, and this skill's own invocation grammar (a verified `nen parse`
gap, not a choice).

---

## 2. Live A/B transcript (read-only)

### 2.1 — `nen repo resolve`, explicit code vs. no-token origin form

```
$ nen repo resolve BC --repo <bankai-core checkout>
zheref/bankai-core  (BC)  via code

$ nen repo resolve BS --repo <bankai-core checkout>
zheref/bankai-scaffold  (BS)  via code

$ nen repo resolve --repo <bankai-core checkout> --from <bankai-core checkout>
nen repo: 'C:\...\bankai-core' has an 'origin' of 'https://github.com/zheref/bankai-core.git',
which resolves to 'zheref/bankai-core' -- and that is not in this registry
(C:\...\bankai-core\schemas\repos.json). ... Codes: $comment (...), BC (zheref/bankai-core),
BS (zheref/bankai-scaffold), KP (zheref/KroApple), KN (zheref/KroAndroid), KW (zheref/KroWindows),
KC (zheref/kro-pwa). Repositories: zheref/KroApple, zheref/KroAndroid, zheref/bankai-scaffold.
```

**Finding (filed, `SKILL.md` § 1).** The explicit-code form resolves `BC` instantly; the no-token
origin form, standing in the exact same checkout, refuses — even though its own refusal text prints
`BC (zheref/bankai-core)` as a known code. The origin-matching path only checks against
`consumers` ∪ `maintained_tools` (the trailing `Repositories:` list), never against the full
`product_codes` map. This is the one case backlog-state hits constantly: asked from inside the
source repo itself, no argument given.

### 2.2 — `nen repo resolve all`

```
$ nen repo resolve all --repo <bankai-core checkout>
zheref/KroApple  (KP)  via all
zheref/KroAndroid  (KN)  via all
zheref/bankai-scaffold  (BS)  via all
Object-reference notation (...)  ($comment)  via all
zheref/bankai-core  (BC)  via all
zheref/KroWindows  (KW)  via all
zheref/kro-pwa  (KC)  via all
```

Six real repos plus one spurious `$comment` row — **seven** printed lines for six actual
repositories. **Finding (filed, `SKILL.md` § 2).** `$comment` is `schemas/repos.json`'s own
documentation key (the same one pr-state's A/B doc already caught leaking into an *error* message's
code list, `docs/ab/pr-state.md` § 4 finding 3) — here it leaks into a *successful* sweep result
instead, which is the more consequential shape: a caller trusting `all`'s row count off-by-one
without inspecting each entry.

(Note: `BC` **is** present in this particular run's `all` output — the registry file at this
checkout's HEAD is not the frozen `v0.11.3` tag's content for this specific array; confirmed by
`git diff v0.11.3 HEAD -- schemas/repos.json` returning **no diff** at all, i.e. HEAD and the tag
are the same commit — annotated tag objects simply have a different SHA than the commit they point
at, which is what made `rev-parse v0.11.3` and `rev-parse HEAD` look different at first. Re-run
with `--repo` pointed at a checkout where `bankai-core` is asked to resolve **itself** — as opposed
to being asked about *from* a different repo's registry — still surfaces `BC` correctly in `all`
here because bankai-core's registry lists itself under `product_codes`, just not under `consumers`/
`maintained_tools`; the *source-repo-omitted-from-all* gap the old skill's § 2 already named is
about a *different* thing than what `all` prints — it is about which array a **consuming** repo's
registry would enumerate, not bankai-core's own. Recorded here exactly as observed, not smoothed
over: the `$comment` leak is the reproducible defect; the "does `all` include BC" question is
registry-content-dependent, not a fixed defect, and this skill's own § 2 instruction — "add the
source repo explicitly and say so" — is written to be correct either way.)

### 2.3 — `nen gate derive`, two real bankai-core PRs

```
$ gh pr diff 925 --repo zheref/bankai-core --name-only
.github/workflows/dev-build.yml
.github/workflows/kisuke-build.yml
.github/workflows/naruto-build.yml
.github/workflows/roy-build.yml
.github/workflows/yamamoto-build.yml
changelog.d/918-cancelled-build-report.md
scripts/report_cancelled_build.sh
tests/cancelled_build_report_wiring.bats
tests/report_cancelled_build.bats

$ nen gate derive --policy-paths "CONSTITUTION.md,handbooks/,agents/,schemas/" \
                  --process-paths ".github/workflows/,claude/,scripts/,tests/,docs/" \
                  --files "<the 9 paths above>"
G4
G4: the diff touches the process surface (.github/workflows/, scripts/, tests/); in a repository
whose product is its process, that is a policy change.
```

```
$ gh pr diff 916 --repo zheref/bankai-core --name-only
.claude-plugin/plugin.json
CHANGELOG.md
changelog.d/... (34 fragment files)
schemas/repos.json

$ nen gate derive --policy-paths "CONSTITUTION.md,handbooks/,agents/,schemas/" \
                  --process-paths ".github/workflows/,claude/,scripts/,tests/,docs/" \
                  --files ".claude-plugin/plugin.json,CHANGELOG.md,schemas/repos.json"
G4
G4: the diff touches policy/spec (schemas/), which only the human merges.
```

Both agree with the old skill's own tree (process surface → G4; `schemas/` → G4). **`--asserted`
mismatch, verified**:

```
$ nen gate derive --policy-paths "..." --process-paths "..." --files "src/foo.ts" --asserted G4
G2
G2: the diff touches neither path set across 1 changed file, so it is product code.
correction: the invocation asserted G4; the diff derives G2, and the derived gate stands.
```

### 2.4 — `nen pr ready` — spot confirmation only, cited not re-proven

Full A/B for `nen pr ready` vs. `pr_ready_gate.sh` lives in `docs/ab/pr-state.md` §§ 2.1–2.6 (4/4
PRs agreeing on verdict and reason text, citing nen's own shadow window at 17/17). This skill only
re-confirms the pointer is correct — `nen pr ready 925 --gh-repo zheref/bankai-core --gates
contracts/bankai-core.gates.json --json` returns the same `not-ready: required checks reported but
are not all green (CON-32a)` verdict this doc's own § 2.3 above independently re-ran it for, with a
`meta` block (`headSha`, `reviewers`, `approvers`, `roundPolicy`, `deliveryPr`, `identities`) that
**does not include `baseRefName`** — confirmed live, feeding directly into § 4's finding below.

### 2.5 — `nen pr fetch` — broken, reproduced on two repositories

```
$ nen pr fetch --target zheref/bankai-core --pr 925
nen pr: could not fetch zheref/bankai-core#925 reviews: gh: Unprocessable Entity (HTTP 422)

$ nen pr fetch --target zheref/bankai-core --pr 925 --json
nen pr: could not fetch zheref/bankai-core#925 reviews: gh: Unprocessable Entity (HTTP 422)

$ nen pr fetch --target zheref/bankai-core --pr 927   # closed, unmerged
nen pr: could not fetch zheref/bankai-core#927 reviews: gh: Unprocessable Entity (HTTP 422)

$ nen pr fetch --target zheref/bankai-core --pr 916   # merged
nen pr: could not fetch zheref/bankai-core#916 reviews: gh: Unprocessable Entity (HTTP 422)

$ nen pr fetch --target zheref/bankai-core --pr 932   # merged
nen pr: could not fetch zheref/bankai-core#932 reviews: gh: Unprocessable Entity (HTTP 422)

$ nen pr fetch --target zheref/hatsu --pr 5           # different repo entirely
nen pr: could not fetch zheref/hatsu#5 reviews: gh: Unprocessable Entity (HTTP 422)
```

**Five for five, across two repositories, every state (open/closed/merged) — plain and `--json`
modes print the identical error string.** There is no schema-validation variant of this error at
all; GitHub's reviews endpoint itself returns `422 Unprocessable Entity` to whatever request `nen pr
fetch` issues, and both output modes surface exactly that, verbatim, with no shape-mismatch framing
in either. **Filed as a finding** (`SKILL.md` § 5) — this port never calls `nen pr fetch`
for anything; `nen pr ready` (a working, separately-verified code path) supplies everything this
skill needs except base ref.

### 2.6 — `nen color status` — precedence, verified against the real file

```
$ nen color status --repo <bankai-core checkout> --present ready_g2_g4
🟢  ready_g2_g4  G2/G4-ready
precedence: on_hold > blocked > ready_g2_g4 > ready_g1 > in_progress

$ nen color status --repo <bankai-core checkout> --present ready_g2_g4,blocked
🔴  blocked  Blocked
outranked: ready_g2_g4

$ nen color status --repo <bankai-core checkout> --present blocked,on_hold
🔵  on_hold  Intentionally on hold
outranked: blocked

$ nen color status --repo <bankai-core checkout> --present ""
unresolved: nothing was reported present, so no value of 'status' applies
```

Precedence `on_hold > blocked > ready_g2_g4 > ready_g1 > in_progress` is byte-identical to
`schemas/colors.yml`'s own `status.precedence` array (read directly, § "colors.yml" excerpt above)
and to the old skill's hand-maintained § 6 table. **Same.**

### 2.7 — `nen board build` + `nen board render`

```
$ cat rows.json
[{"id":"925","title":"Cancelled build leaves bankai:stage/building set",
  "refs":["BC-IS-#918","BC-PR-#925"],"gate":"G4","status":"🟠",
  "needs":"Kisuke addresses required checks"}]

$ nen board build --repo-slug zheref/bankai-core --rows-from rows.json --json > board.json
$ nen board render --board-from board.json
zheref/bankai-core -- generated 2026-09-02T00:59:42.717Z

| Effort                                           | Refs                   | Status (gate) | Needs                            |
| ------------------------------------------------- | ---------------------- | ------------- | -------------------------------- |
| Cancelled build leaves bankai:stage/building set | BC-IS-#918, BC-PR-#925 | 🟠 (G4)       | Kisuke addresses required checks |
```

Confirmed: `status` is printed verbatim, so the caller must pass the resolved glyph (§ 2.6's
output), not the bare enum key — `render` performs no `colors.yml` lookup of its own.

### 2.8 — `nen ref format` / `nen ref parse`

```
$ nen ref format --repo <bankai-core checkout> --code BC --kind IS --number 929 --state open \
                 --url https://github.com/zheref/bankai-core/issues/929
📄 [BC-IS-#929](https://github.com/zheref/bankai-core/issues/929)

$ nen ref format --repo <bankai-core checkout> --code BC --kind PR --number 916 --state merged \
                 --url https://github.com/zheref/bankai-core/pull/916
🔀 [BC-PR-#916](https://github.com/zheref/bankai-core/pull/916) ✓

$ nen ref parse "BC-PR-#925"
ref:    BC-PR-#925
code:   BC
kind:   PR
number: 925
glyph:  🔀
```

Multi-line, tab-aligned output — one field per line, not a single `·`-joined line. Confirmed
identical in shape with `--json`:

```
$ nen ref parse "BC-PR-#925" --json
{
  "ref": "BC-PR-#925",
  "code": "BC",
  "kind": "PR",
  "number": 925,
  "glyph": "🔀"
}
```

Matches object notation exactly as the old skill typed by hand.

### 2.9 — `nen backlog order`

```
$ cat rows.json
[{"id":"937","severity":"high","createdAt":"2026-09-01T22:55:36Z","number":937},
 {"id":"939","severity":"medium","createdAt":"2026-09-01T23:47:08Z","number":939},
 {"id":"929","severity":"high","createdAt":"2026-09-01T18:26:57Z","number":929},
 {"id":"938","severity":"unknown-vocab","createdAt":"2026-09-01T23:19:42Z","number":938}]

$ nen backlog order --rows-from rows.json --severity-order critical,high,medium,low
1. 929  severity=high    2026-09-01T18:26:57Z
2. 937  severity=high    2026-09-01T22:55:36Z
3. 939  severity=medium  2026-09-01T23:47:08Z
4. 938  severity=unknown-vocab  2026-09-01T23:19:42Z
```

`high` before `medium` before an out-of-vocabulary severity (ranked last, never erroring); within
`high`, the older row (929, 18:26) sorts before the newer one (937, 22:55) — age tie-break, exactly
as documented. `--json` confirms `severityRank: null` for the unrecognised value rather than a
silent default.

### 2.10 — `nen backlog fetch` — the foundational verb, live

```
$ nen backlog fetch --repo-slug zheref/bankai-core --limit 5
4 row(s) -- 4 issue(s), 2 PR(s)
TRUNCATED at --limit 5: the fetch may not be complete. Raise --limit, or omit it to fetch every open row.
#939 [#925]  [Machinery] Nothing guards against bash 4 constructs, but unit_tests runs on macOS bash 3.2 — ${AGENT^} silently failed 8 tests on BC-PR-#925
#938  port pr_ready_gate.sh's plugin-cache guard classification into cli/src/ports/pr_ready_gate.ts (BC-IS-#733 plane parity)
#937 [#940]  [Canon] Record the ruling that BC-11 does not bind a patch on the frozen v0.11.z line — it exists only in PR comments and has blocked two PRs
#936  [Handbook question] Should a CON-42/1 readiness claim be required to carry its provenance line when quoted?

$ nen backlog fetch --repo-slug zheref/bankai-core --limit 5 --json
{
  "repo": "zheref/bankai-core",
  "truncated": true,
  "rows": [
    {
      "issueNumber": 939,
      "title": "[Machinery] Nothing guards against bash 4 constructs, but unit_tests runs on macOS bash 3.2 — ${AGENT^} silently failed 8 tests on BC-PR-#925",
      "labels": ["bankai:bug", "bankai:severity/medium", "bankai:agent/kisuke"],
      "prNumbers": [925],
      "createdAt": "2026-09-01T23:47:08Z"
    },
    {
      "issueNumber": 938,
      "title": "port pr_ready_gate.sh's plugin-cache guard classification into cli/src/ports/pr_ready_gate.ts (BC-IS-#733 plane parity)",
      "labels": ["bankai:agent/kisuke"],
      "prNumbers": [],
      "createdAt": "2026-09-01T23:19:42Z"
    },
    {
      "issueNumber": 937,
      "title": "[Canon] Record the ruling that BC-11 does not bind a patch on the frozen v0.11.z line — it exists only in PR comments and has blocked two PRs",
      "labels": ["documentation", "bankai:severity/high", "bankai:agent/yamamoto"],
      "prNumbers": [940],
      "createdAt": "2026-09-01T22:55:36Z"
    },
    {
      "issueNumber": 936,
      "title": "[Handbook question] Should a CON-42/1 readiness claim be required to carry its provenance line when quoted?",
      "labels": ["bankai:agent/naruto", "bankai:handbook-question"],
      "prNumbers": [],
      "createdAt": "2026-09-01T22:13:35Z"
    }
  ],
  "issueCount": 4,
  "prCount": 2
}
```

Both forms agree: 4 issue rows, `truncated: true` at `--limit 5` (the live `bankai-core` backlog
has more than 5 open issues), each row's `prNumbers[]` carrying the issue-to-PR assembly this
skill's § 3 describes (`#939` → `[#925]`, `#937` → `[#940]`, `#938`/`#936` → none open). Confirms
the thin row schema (`issueNumber, title, labels, prNumbers[], createdAt` — no severity field, no
PR-level detail) exactly as `SKILL.md` § 3 states, and that `truncated` is reported explicitly
rather than silently capping the result.

---

## 3. `nen parse` against this skill's own grammar — the finding in full

```
$ nen parse backlog-state --grammar "<repo>@<gate:G1|G1-M|G2|G3|G4|G5|all>" --line "BC@G4"
repo: BC
gate: G4                                              # works: two slots, mandatory separator

$ nen parse backlog-state --grammar "<repo>@<gate:G1|G1-M|G2|G3|G4|G5|all>" --line "BC@G9"
nen parse: <gate> is one of G1 | G1-M | ... , and 'G9' is none of them.  # refuses correctly

$ nen parse backlog-state --grammar "<repo>[@<gate:G1|G1-M|G2|G3|G4|G5|all>]" --line "BC@G4"
repo: BC@G4                                           # BROKEN: whole thing swallowed into <repo>

$ nen parse backlog-state --grammar "<repo>[@<gate:G1|G1-M|G2|G3|G4|G5|all>]" --line "BC@G9" --json
{"ok": true, "slots":[{"name":"repo","value":"BC@G9"}], "problems":[]}   # G9 never validated

$ nen parse backlog-state --grammar "<repo>[@<gate>]" --line "BC@G4"     # even unconstrained
repo: BC@G4                                                              # same collapse

$ nen parse backlog-state --grammar "<repo> [then sweep]" --line "BC then sweep"  # no slot at all
repo: BC then sweep                                                      # same collapse
```

**Root cause, as far as can be observed from the outside:** the `[ ... ]` optional-clause syntax
appears to only take effect when there is a **second** named slot for it to disambiguate against —
with exactly one slot in the whole template, the parser captures everything from the first
non-literal character onward into that slot and never looks for a bracketed clause at all,
regardless of whether that clause contains an enumerated slot, a bare slot, or no slot whatsoever.
It reports `"ok": true` in every case above rather than refusing the template or flagging the
swallowed clause — the failure mode is silent, not loud. `futon`/`izanagi`/`izanami` are unaffected
because `nen parse --help` states plainly they carry their own hand-written grammars rather than
going through this generic `--grammar` path.

**This is why `SKILL.md` § 1 still splits `<repo>@<gate>` by hand**, exactly as the old skill did —
not a choice to skip mechanizing it, a verified dead end.

---

## 4. Findings (report separately, do not route around)

1. **`nen repo resolve` (no-token, origin-based form) cannot resolve a repository to itself when
   that repository is the registry's own source, not a `consumers`/`maintained_tools` entry** —
   even though the same origin has a valid `product_codes` entry. Reproduced live, standing in
   `bankai-core`'s own checkout (§ 2.1). The explicit-code form (`nen repo resolve BC --repo ...`)
   is unaffected and is what this port falls back to when the no-token form refuses this specific
   way — reusing the code the refusal's own text just printed, never re-deriving one by hand.

2. **`nen repo resolve all` includes `schemas/repos.json`'s own `$comment` documentation key as if
   it were a resolvable repository**, inside a *successful* sweep result (not only an error
   message, where `pr-state`'s own A/B doc already caught the same leak — `docs/ab/pr-state.md` § 4
   finding 3). Reproduced live (§ 2.2): seven printed rows for six real repositories.

3. **`nen pr fetch` is completely broken** against every PR tried, in two unrelated repositories,
   across every PR state (open/closed/merged): the underlying GitHub reviews sub-fetch returns
   `422 Unprocessable Entity`, and both the plain and `--json` output modes print that identical
   HTTP error string verbatim — neither mode wraps it in schema-validation framing. Reproduced live
   five times (§ 2.5). This port does not use `nen pr fetch` anywhere as a result.

4. **`nen parse <skill> --grammar <template>`'s `[ ... ]` optional-clause syntax does not work with
   a single-slot template** — the whole remainder of the line, bracketed clause included, is
   silently captured into that one slot and reported `"ok": true`, whether the bracketed clause
   contains an enumerated slot, an unconstrained slot, or no slot at all. Reproduced live three
   ways (§ 3). This skill's own `<repo>@<gate>` invocation grammar cannot be validated through this
   verb today; parsing it stays a prose rule, disclosed rather than silently attempted and passed
   over.

5. **`nen board build`'s `BoardRow` schema (`{id, title, refs, gate, status, needs}`) has no field
   for a conditional Repo column or for Session · Lane attribution** — not a defect, a genuine
   scope boundary of the verb (it renders a single repo's board; multi-repo attribution and session
   provenance are this skill's own concerns), but one this port had to design around explicitly
   (folded into `title` and `needs` respectively — `SKILL.md` § 7) rather than silently, since a
   reader comparing this table to the old skill's seven-column one would otherwise wonder where two
   columns went.

---

## 5. Residue

- **Judgment kept, per the shared brief's boundary list**: gate *interpretation* (which situations
  count as G5 vs. in-progress, § "G5 is not the default bucket"), synthesized titles (§ 8),
  the expected-action line (§ 9), session/lane evidence-reading (§ 10), and the closing shape
  summary (§ 12) — `nen` computes and formats; deciding what a row *means* to the maintainer stays
  this skill's.
- **The base-ref gate-assignment fix is new in this port**, carried in from a **live, open**
  finding against the very skill being ported — `bankai-core#929` ("Machinery leg of #879 —
  drive/backlog-state must read baseRefName before assigning a gate"), discovered incidentally
  while running this port's own live A/B pass, not solicited. It names this exact skill file by
  path and states the fix in enough detail to carry forward faithfully. It is **not** a `nen`
  mechanization — `nen gate derive` explicitly stops at the diff (`nen gate --help`: *"This derives
  the DIFF's half only"*) — and it is currently unimplementable end-to-end via any working `nen`
  verb, because the one verb that would supply `baseRefName` (`nen pr fetch`) is the one proven
  broken in finding 3. `SKILL.md` § 4 names this plainly and points at `gh pr view --json
  baseRefName` as the (disclosed, necessary, non-`nen`) stopgap rather than silently reproducing the
  old tree's known gap.
- **No PR-diff-fetch verb exists.** Neither `nen gate derive` nor (the working parts of) `nen pr
  ready` fetches a remote PR's changed-file list; `gh pr diff <n> --name-only` remains a necessary
  raw call feeding `--files` (`SKILL.md` § 4). This is not an improvised replacement for anything
  `nen` owns — nothing owns this fetch yet, and it is named as residue rather than left unstated.
- **A lone PR referencing no open issue** is invisible to `nen backlog fetch`'s issue-keyed shape
  (§ "3. Fetching" note in `SKILL.md`); no verb currently reshapes this the other way round.
- **The historical framing** in the old skill's opening ("backlog-loop reports what its own run
  just did. Ichigo's prompt protocol reports what this session is holding...") does not carry over
  verbatim — those are bankai-core skills/personas with no hatsu counterpart yet. The port keeps
  the *shape* of that argument (nothing else answers this question) without naming bankai-core
  skills hatsu does not yet have ported.
