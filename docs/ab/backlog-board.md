# A/B evidence — `backlog-board` (zheref/hatsu#2)

Port of `claude/skills/backlog-board/SKILL.md`: the same sweep as `backlog-state`, painted as one
self-contained HTML gate board published as an Artifact. Old mechanics: `scripts/ichigo_board.sh`
(the JSON-in/HTML-out python3 generator) plus the prose that assembled its input by hand. New
mechanics: `nen board build | render | diff`, composed with `nen backlog fetch|order`, `nen gate
derive`, `nen color status`, `nen pr ready` (all `backlog-state`'s, adopted by reference) and `nen
ref format`.

Run: 2026-09-02 (UTC). `nen 0.1.0` (`<cache>\nen\v0.1.0\nen-windows-x64.exe`). `gh`
authenticated as `zheref`. Live target: `<reference-repo>` (real, open backlog, 88 open rows at
run time). Oracle checkout: `<reference-repo>` tag `v0.11.3`
(`2269fe723e355dc69bf535ab40f22556e4fe4081`, working tree clean, 16 commits behind `origin/main` —
irrelevant here since only `git show`-extracted, read-only files were used) —
`scripts/ichigo_board.sh` and `scripts/ichigo_pix.txt` extracted read-only via `git show
v0.11.3:<path>` into a scratch directory outside the `<reference-repo>` checkout, never written back to it.

*Paths sanitized: this machine's local absolute paths appear as `<checkout>` (the parent directory of the repository checkouts), `<cache>` (the nen binary cache) and `<scratch>` (a throwaway scratch directory). Private repository names, and the product codes that identified them, are redacted to placeholders (see [`docs/PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md)); nothing else below is altered -- the transcripts are otherwise verbatim.*

**§2.4 re-run for this review fix:** 2026-09-02T01:24 UTC, same extracted `ichigo_board.sh`, same
`v0.11.3` oracle checkout, against the exact `board.json` now embedded in §2.4 — done to make the
byte-count claim there independently checkable (adversarial-review MINOR-2).

---

## 1. Command mapping table

| # | Old (prose / shell) | New (`nen`) |
|---|---|---|
| 1 | The row computation itself: `backlog-state`'s §§2–11, read and applied by hand (fetch, gate tree, readiness by eye unless `pr_ready_gate.sh` was actually run, colour precedence, synthesized titles, expected action, session·lane, ordering) | `hatsu:backlog-state`, adopted by reference (§2 of this port) — that skill's own port replaces each of those steps with `nen backlog fetch\|order`, `nen gate derive`, `nen color status`, `nen pr ready`. This skill does not re-implement any of it |
| 2 | Assembling the rich board JSON (`efforts[]`, `gates[].asks[]`, `tally`, `legend`, `footer`) from those rows, entirely in prose, per invocation | `nen board build --repo-slug <owner/name> --rows-from <path> --json` assembles a thinner `Board` object (`{id,title,refs,gate,status,needs}` rows plus a `repo`/`generatedAt` header) from rows already carrying their gate and status — verified live, § 2 below |
| 3 | Deriving a row's gate from the diff by eye ("does it touch `CONSTITUTION.md`/`handbooks/`/`agents/`/`schemas/`? the process surface?") | `nen gate derive --policy-paths … --process-paths … --files …` — verified live against the real open PR `BC#925`, § 2.1 |
| 4 | Deriving a row's colour by matching `agents/_conventions.md`'s prose precedence table by hand | `nen color status --present <values> --category status --json`, reading the target repo's own `schemas/colors.yml` precedence — verified live, § 2.1 |
| 5 | Formatting `<CODE>-<IS\|PR>-#<N>` with its emoji/state mark by hand | `nen ref format --code … --kind … --number … --state … --url …` — verified live, § 2.4 |
| 6 | Rendering the assembled JSON to HTML via `scripts/ichigo_board.sh --out file.html board.json` — a cached python3 generator whose ~2.8k-token design shell never changes | **No nen counterpart exists.** `nen board render` emits a padded-**markdown** table only — verified live, § 3. The HTML page is now authored directly by Kurapika from `nen board build`'s JSON, via the Artifact tool, every render — see the finding in § 4 |
| 7 | Detecting "what changed" between two renders in `every state-change` mode, by comparing status colour/gate/expected-action fields across rows by hand | `nen board diff --before <path> --after <path>` — field-level, by row id, ignores unchanged rows entirely — verified live, both a real null-diff and a doctored two-row diff, § 3 |
| 8 | Parsing the `<repo>@<gate> [every <freq>]` invocation by hand, every time | Partially: `nen parse backlog-board --grammar "<repo>@<gate:…> [every <freq:…>]" --line "<invocation>"` validates the enumerated gate/frequency tokens and refuses with a corrected line — verified live, § 4. **Does not** cover the optional-`@`/bare-`all` shorthand or the no-repo-defaults-to-cwd-origin rule; those stay prose, inherited from `backlog-state` §1 |
| 9 | Detecting a host with no runnable `python3` (three-interpreter probe: `python3`/`py -3`/`python`, version-gated) and degrading to the markdown table | **Retired outright**, not ported. § 4's finding means the HTML authoring step no longer shells out to a local interpreter at all — there is nothing left on this path to probe or degrade around |

**Count.** Before: at minimum 6 improvised steps per invocation this skill's own text owned
directly (rows 2–5, 8, 9 above — the JSON assembly, the gate/colour-by-eye derivations this skill
would fall back to without `backlog-state`'s own port, the ref formatting, the invocation parse,
the python3 probe), on top of everything `backlog-state`'s own port already retires (row 1, counted
there, not here). After: **rows 2–5 and 8 are `nen` invocations** (`board build`, `gate derive`,
`color status`, `ref format`, `parse`); row 9 no longer exists as a step at all. **Row 6 — the
actual HTML render — is the one genuine gap**: no `nen` verb replaces it, and this is reported as a
finding (§4) rather than routed around by hand-authoring a cached template this port's file set
does not allow.

---

## 2. Live A/B transcript (read-only)

### 2.1 — the real backlog fetch, and one row's gate + colour derivation

```
$ export GH_TOKEN=$(gh auth token)
$ nen backlog fetch --repo-slug <reference-repo> --json
{
  "repo": "<reference-repo>", "truncated": false,
  "rows": [
    { "issueNumber": 939, "title": "[Machinery] Nothing guards against bash 4 constructs …",
      "labels": ["bankai:bug","bankai:severity/medium","bankai:agent/kisuke"],
      "prNumbers": [925], "createdAt": "2026-09-01T23:47:08Z" },
    { "issueNumber": 918, "title": "[Machinery] A cancelled build leaves bankai:stage/building set …",
      "labels": ["bankai:stage/in-review","bankai:bug","bankai:severity/high","bankai:agent/kisuke"],
      "prNumbers": [925], "createdAt": "2026-09-01T17:35:29Z" },
    { "issueNumber": 877, "title": "[Machinery] pr_ready_gate.sh cannot see an unreported REQUIRED context …",
      "labels": ["bankai:bug","bankai:severity/high","bankai:agent/kisuke"],
      "prNumbers": [925], "createdAt": "2026-08-29T17:16:02Z" },
    … 85 more rows, elided honestly — 88 rows total, zero lone-PR rows, exactly one open PR
    (`#925`) in the whole set at run time …
  ]
}
```

Three real issues (`#918`, `#939`, `#877`) all reference the **one** open PR — confirmed by
`gh pr view 925 --repo <reference-repo> --json files`, whose changed-file set is:

```
.github/workflows/dev-build.yml       .github/workflows/kisuke-build.yml
.github/workflows/naruto-build.yml    .github/workflows/roy-build.yml
.github/workflows/yamamoto-build.yml  changelog.d/918-cancelled-build-report.md
scripts/report_cancelled_build.sh     tests/cancelled_build_report_wiring.bats
tests/report_cancelled_build.bats
```

Gate, from the diff alone:

```
$ nen gate derive --repo <reference-repo checkout> \
  --policy-paths "CONSTITUTION.md,handbooks/,agents/,schemas/" \
  --process-paths ".github/workflows/,claude/,scripts/,tests/,docs/" \
  --files ".github/workflows/dev-build.yml,…,tests/report_cancelled_build.bats" --json
{
  "gate": "G4",
  "basis": "G4: the diff touches the process surface (.github/workflows/, scripts/, tests/); in a
            repository whose product is its process, that is a policy change.",
  "readinessNote": "This is the diff's half of the derivation only. A pull request that is not
            ready has NO GATE -- it is in progress and owned by its author -- so compose this with
            a readiness verdict before putting a row in anyone's queue."
}
```

Readiness (real, same as `docs/ab/pr-state.md` §2.1's own run, same PR): `nen pr ready 925 …`
returns `not-ready: required checks reported but are not all green (CON-32a)`. Composed per
`backlog-state`'s tree: **not-ready → no gate, in progress** — so the row's final `gate` is `null`,
not the `G4` `gate derive` alone would suggest. `gate derive`'s own text says exactly this; nothing
here was inferred beyond what it printed.

Colour, for that same composed state:

```
$ nen color status --repo <reference-repo checkout> --present "in_progress" --category status --json
{
  "category": "status", "present": ["in_progress"],
  "resolved": { "name": "in_progress", "emoji": "🟠", "hex": "#ef6c00", "label": "In progress",
    "means": "Work is moving … NOT a gate …", "extra": { "gate": null } }
}
```

> **Snapshot caveat.** Everything in this section is a single point-in-time read, not a standing
> truth. Within minutes of the board sample's own `generatedAt` (`2026-09-02T00:57:42.267Z`, §2.2
> below), issue `#937` gained an open PR — `<reference-repo>#940`, titled *"feat(bc11): a fifth
> shell clause for a frozen-line patch, expiring with the freeze"*, body opening `Closes #937`,
> opened `2026-09-02T01:03:46Z` (confirmed live via `gh pr view 940 --repo <reference-repo>
> --json createdAt,body`) — about six minutes after this sweep ran. Re-fetching now would collapse
> `#937`'s row into a PR-anchored effort the way `#918`'s row already is here, and its gate/status
> would move with it (routed-not-building → building, at minimum). Nothing below was re-run to
> chase that drift; §§2.2–2.6 stand as the live snapshot they always were, not a board that stays
> current on its own — a fresh `hatsu:backlog-board` invocation re-sweeps every time, per the skill
> file's own rule against publishing rows held in session memory.

### 2.2 — `nen board build`, the real 3-row sample

Rows built by hand from § 2.1's real data (the collapsed `918`/`939`/`877`/`925` effort) plus two
more real, label-driven rows (`#937`, `#936` — no open PR, routed via a `bankai:agent/*` label
without `bankai:stage/building`, so `backlog-state`'s tree reads `G1-M`/`ready_g1` for both):

```
$ nen board build --repo-slug <reference-repo> --rows-from boardrows.json --json
{
  "repo": "<reference-repo>", "generatedAt": "2026-09-02T00:57:42.267Z",
  "rows": [
    { "id": "918", "title": "Cancelled build leaves bankai:stage/building silently stuck",
      "refs": ["RR-IS-#918","RR-IS-#939","RR-IS-#877","RR-PR-#925"],
      "gate": null, "status": "in_progress",
      "needs": "PR #925 is not-ready — required checks reported but are not all green (CON-32a). Author iterating; not yet the human's." },
    { "id": "937", "title": "Record the ruling that BC-11 doesn't bind the frozen v0.11.z line",
      "refs": ["RR-IS-#937"], "gate": "G1-M", "status": "ready_g1",
      "needs": "Routed to Yamamoto (bankai:agent/yamamoto), not yet building — ready to be released into build." },
    { "id": "936", "title": "Should a CON-42/1 readiness claim carry its provenance line?",
      "refs": ["RR-IS-#936"], "gate": "G1-M", "status": "ready_g1",
      "needs": "Handbook question routed to Naruto — ready to be released into build." }
  ]
}
```

`board build` echoed every field back unchanged — confirming it assembles, and does not itself
compute, gate or status.

### 2.3 — `nen board render`, the same sample: markdown, not HTML

```
$ nen board render --board-from boardA.json
<reference-repo> -- generated 2026-09-02T00:57:50.925Z

| Effort                                                            | Refs                                            | Status (gate)   | Needs …
| Cancelled build leaves bankai:stage/building silently stuck       | RR-IS-#918, RR-IS-#939, RR-IS-#877, RR-PR-#925  | in_progress     | PR #925 is not-ready …
| Record the ruling that BC-11 doesn't bind the frozen v0.11.z line | RR-IS-#937                                      | ready_g1 (G1-M) | Routed to Yamamoto …
| Should a CON-42/1 readiness claim carry its provenance line?      | RR-IS-#936                                      | ready_g1 (G1-M) | Handbook question …
```

Plain pipe table, raw status strings (`in_progress`, `ready_g1 (G1-M)` — no 🟠/🟡 glyph), refs as
bare comma-joined strings with **no links and no state marks**.

### 2.4 — the SAME 3 rows through the retired `ichigo_board.sh`, at its own (richer) schema

`scripts/ichigo_board.sh` is a pure renderer — it never fetches — so it can be run read-only on a
hand-built input at its own schema, extracted via `git show v0.11.3:scripts/ichigo_board.sh` into a
scratch directory (never written back to the `<reference-repo>` checkout).

**The exact input, so this run is independently repeatable** — this is the constructed `board.json`
this doc's §2.4 run actually used, hand-built from §2.1–2.2's real row data at the OLD schema
(`--schema`'s contract), not asserted from a file that was later discarded:

```json
{
  "title": "Gate Register",
  "dek": "<reference-repo> -- G1-M",
  "eyebrow": "Bankai . local plane",
  "live": "2 need you",
  "generated": "2026-09-02T00:57:42.267Z",
  "tally": [
    {"n": 2, "label": "Need you", "tone": "hot"},
    {"n": 1, "label": "In flight", "tone": "cool"}
  ],
  "gates": [
    {"gate": "G1-M", "name": "Routed, ready to build", "status": "open",
     "asks": [
        {"rank": 1, "first": true, "recommended": false,
         "ask": "DO -- release RR-IS-#937 into build",
         "why": "Routed to Yamamoto (bankai:agent/yamamoto), not yet building -- ready to be released into build.",
         "objects": [ {"ref": "RR-IS-#937", "url": "https://github.com/<reference-repo>/issues/937"} ]},
        {"rank": 2,
         "ask": "DO -- release RR-IS-#936 into build",
         "why": "Handbook question routed to Naruto -- ready to be released into build.",
         "objects": [ {"ref": "RR-IS-#936", "url": "https://github.com/<reference-repo>/issues/936"} ]}
     ]},
    {"gate": "G2 . G3 . G4", "name": "Merges and release", "status": "clear",
     "note": "No PR is CON-32-Ready right now."}
  ],
  "efforts": [
    {"title": "Cancelled build leaves bankai:stage/building silently stuck",
     "state": "awaiting", "pill": "In progress", "lane": "unresolved", "open": true,
     "objects": [
        {"ref": "RR-IS-#918", "url": "https://github.com/<reference-repo>/issues/918"},
        {"ref": "RR-IS-#939", "url": "https://github.com/<reference-repo>/issues/939"},
        {"ref": "RR-IS-#877", "url": "https://github.com/<reference-repo>/issues/877"},
        {"ref": "RR-PR-#925", "url": "https://github.com/<reference-repo>/pull/925"}
     ],
     "summary": "PR #925 is not-ready -- required checks reported but are not all green (CON-32a). Author iterating; not yet the human's.",
     "fields": [ {"k": "Readiness objection", "text": "required checks reported but are not all green (CON-32a)"} ]},
    {"title": "Record the ruling that BC-11 doesn't bind the frozen v0.11.z line",
     "state": "awaiting", "pill": "Ready . G1-M", "lane": "unresolved", "open": true,
     "objects": [ {"ref": "RR-IS-#937", "url": "https://github.com/<reference-repo>/issues/937"} ],
     "summary": "Routed to Yamamoto (bankai:agent/yamamoto), not yet building -- ready to be released into build."},
    {"title": "Should a CON-42/1 readiness claim carry its provenance line?",
     "state": "awaiting", "pill": "Ready . G1-M", "lane": "unresolved", "open": true,
     "objects": [ {"ref": "RR-IS-#936", "url": "https://github.com/<reference-repo>/issues/936"} ],
     "summary": "Handbook question routed to Naruto -- ready to be released into build."}
  ],
  "legend": [ {"heading": "Gates", "items": [ {"term": "G1-M", "def": "Routed, ready to build"} ]} ],
  "footer": [ "3 of 88 open rows shown (sample)." ]
}
```

Run against exactly that file, re-verified for this fix:

```
$ python3 -c "import json; json.load(open('board.json'))"   # valid JSON, confirmed first
$ bash ichigo_board.sh --out board.html board.json
$ echo $?
0
$ wc -c board.html
28092 board.html
```

Exit `0`, zero `--schema`-contract warnings on stderr (the only stderr line is a BOM artifact from
the `git show` extraction re-executing the shebang line under `bash script.sh` invocation, not a
schema warning — it does not affect the output). The output is a self-contained HTML page carrying:
the design shell, a `G1-M` desk with two ranked `DO` asks (`#937`, `#936`) and their `why`, a
"Merges and release" gate rendered **cleared, with a note** (no PR is `CON-32`-Ready right now), the
`#918` effort row with its `not-ready` evidence, a tally strip, and a footer disclosing the sample
is 3 of 88 open rows. Confirmed present in the actual `board.html`: `<title>Gate Register</title>`,
`G1-M` (6 occurrences), `RR-IS-#937` (3 occurrences, ask + effort + object), a well-formed
`<head>`/`<style>` shell.

**Same content, same gate/status verdicts on both sides** (`G1-M`/`ready_g1` for `#937`/`#936`, no
gate/`in_progress` for the `#918` effort — nothing in the port disagrees with what the old renderer
would have shown for identical input). **The surfaces are not the same**: 28,092 bytes of
self-contained HTML with a design shell and a DECIDE/DO/MERGE desk, vs. ~700 bytes of plain
markdown with no shell, no grouping, and no grammar. This gap is § 4's finding in the skill file —
recorded here as the quantified, re-runnable evidence for it, not asserted without a run behind it.
(An earlier draft of this doc reported 28,760 bytes for this same claim without the input attached,
making the number impossible to independently check; this section supersedes that number with the
input that actually produced it.)

### 2.5 — `nen board diff`, two real ways

A genuine null-diff (same snapshot, twice):

```
$ nen board diff --before boardA.json --after boardA.json --json
{ "rows": [], "changed": false }
```

A doctored two-snapshot diff (declared, not a real 5-minute gap — the doctoring simulates `#925`
turning `CON-32`-Ready and `#936` moving from routed-not-building to building):

```
$ nen board diff --before boardA.json --after boardB.json
changed  918: gate '' -> 'G4', status 'in_progress' -> 'ready_g2_g4', needs '…not-ready…' -> '…now CON-32-Ready and mergeable — MERGE, yours.'
changed  936: gate 'G1-M' -> '', status 'ready_g1' -> 'in_progress', needs '…routed to Naruto…' -> '…Naruto has started building…'
```

Row `937` (unchanged) is correctly absent from both the JSON and plain-text diff output.

### 2.6 — `nen parse backlog-board`, a custom grammar template

```
$ nen parse backlog-board --grammar "<repo>@<gate:G1|G1-M|G2|G3|G4|G5|all> [every <freq:turn|state-change|once>]" --line "BC@G4"
repo: BC
gate: G4

$ nen parse backlog-board --grammar "…same…" --line "BC@G4 every state-change"
repo: BC
gate: G4
freq: state-change

$ nen parse backlog-board --grammar "…same…" --line "BC@G9"
nen parse: <gate> is one of G1 | G1-M | G2 | G3 | G4 | G5 | all (case-insensitively), and 'G9' is
none of them. …
Corrected line:
  backlog-board BC@<gate: G1 | G1-M | G2 | G3 | G4 | G5 | all>

$ nen parse backlog-board --grammar "…same…" --line "all"
nen parse: <gate> is required and the line does not supply it.
Corrected line:
  backlog-board all@<gate: G1 | G1-M | G2 | G3 | G4 | G5 | all>
```

The last case is the finding recorded in the skill file § 1: a bare `all` (short for `all@all` per
`backlog-state` §1) is refused rather than accepted, because the grammar mini-language has no
concept of an optional separator with a defaulted counterpart slot.

---

## 3. Residue

- **The HTML renderer itself has no `nen` verb** (§4 of the skill file, quantified in §2.3–2.4
  above). This is the one place this port could not retire an improvised step outright — it moved
  the improvisation from "assemble JSON by hand for a cached generator" to "author the page by hand
  from `nen`'s JSON," which is a smaller prose surface (no board-JSON schema to hold in memory) but
  is still prose, not a verb call.
- **Judgment kept, per the shared brief's boundary list:** severity/rank ordering on the desk,
  synthesized titles, the DECIDE/DO/MERGE `why` prose and options tables, and the collapsing of
  `backlog-state`'s effort rows onto `board build`'s thinner shape — `nen` computes the gate,
  colour and diff; deciding how to brief a `DECIDE` or rank a `DO` stays this skill's.
- **No missing verb beyond §4's HTML gap.** `board build`, `render` and `diff` between them cover
  every deterministic step this skill's old JSON-assembly-and-generator pipeline owned, except the
  render-to-HTML step itself.
- **`nen backlog fetch`'s one-row-per-issue granularity** (§3 of the skill file) is not itself a
  defect — its own `--help` text scopes it exactly that way — but it means `backlog-state`'s
  "an issue and the PRs that serve it are ONE row" collapsing rule still has real work to do on top
  of a fetch, for the (apparently common, live-verified) case of one PR closing several issues.
- **`$comment` appears among `nen repo resolve all`'s registry entries**, same defect already
  reported in `docs/ab/pr-state.md` §4 finding 3 — not re-filed here, only re-observed live
  (`nen repo resolve all --repo <reference-repo checkout> --json` lists a `code: "$comment"` entry
  whose `repo` field is the schema's own documentation string).
- **Verdict parity between `nen pr ready` and `pr_ready_gate.sh`** is `docs/ab/pr-state.md`'s to
  establish, cited rather than re-proven here; this doc's own PR-925 readiness read (§2.1) matches
  that doc's own run of the same PR.
- **Commit-message style on this branch does not match house precedent.** This port's own commit
  reads `port(backlog-board): …`; the house form established on prior ports is
  `feat(skills): port <name> … (hatsu#<N>)`. Recorded here rather than silently left unremarked —
  it is not rewritten because the commit is already pushed and rewriting it would need a
  force-push, which this fix deliberately does not do. The fix commit that resolves this review's
  findings uses the house form.

---

## 4. Findings (report separately, do not route around)

1. **`nen board render` has no HTML output mode.** Verified live: `nen board --help` lists exactly
   `build`/`render`/`diff`, no fourth verb and no `--format` flag anywhere in the family; `render`'s
   own help text states it emits "the padded-markdown table this port's source repository
   established" and nothing else. The retired `ichigo_board.sh`, run against the exact input
   embedded in §2.4, produced a 28,092-byte self-contained HTML page (design shell, per-gate desk,
   DECIDE/DO/MERGE grammar, tally, legend, footer, identity sprite) from the same 3-row input that
   `nen board render` turns into a ~700-byte plain table with no links, no colour glyphs and no
   grouping. The HTML-authoring mechanism this port exists to deliver has no home in `nen` and is
   not something a file-set restricted to `SKILL.md` + `docs/ab/backlog-board.md` can replace with
   a shipped generator — it is authored by Kurapika directly at render time instead (skill §4),
   which is disclosed as a real cost and behavior change, not hidden behind "the same board,
   painted."
2. **`nen parse`'s grammar mini-language cannot express an optional separator with a defaulted
   slot.** Verified live (§2.6): a bare `all` line, meant to parse as `all@all` per `backlog-state`
   §1's own stated shorthand, is refused as "gate is required" instead. The same gap would refuse
   the no-repo-token-defaults-to-cwd-origin rule if it were expressed in the template at all — there
   is no slot syntax for "absent, and if so resolve a default from context." Both rules stay prose,
   named explicitly in the skill file rather than silently dropped.
3. **`nen board build`'s `refs` carries no `url` or `state` per reference**, unlike the retired
   script's `objects[]` (`{ref, url, state}`). Verified live (§2.2–2.3): `board build` echoes `refs`
   as bare strings and `board render` prints them unlinked, with no ✓/✗/✎ state mark. Not a defect
   against the thinner `BoardRow` contract `board build --help` documents — it was never scoped to
   carry a URL — but it means the skill must re-attach both from `backlog-state`'s own rows (which
   already carry them) when authoring the HTML, rather than reading them back off `board build`'s
   output.
