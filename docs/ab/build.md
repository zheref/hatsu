# A/B evidence — `build` (zheref/hatsu#2)

Port of `claude/skills/build/SKILL.md`: take one issue from wherever it sits to a delivery PR
standing ready at its human gate. The old skill's own deterministic steps were improvised prose
over raw `gh`/hand-reasoning throughout — "decide from labels, body and linked objects, never the
title" (§ 2), the mode-routing table read by eye (§ 3), the epic-wave release computed by a
`CON-23` CI coordinator or, absent one, by hand, and the two-PR concurrency cap enforced by
eyeballing "never drive more than two." There is no runnable old-side script for any of this (unlike
`pr-state`'s `scripts/pr_ready_gate.sh`) — it was agent judgment and raw `gh`, every invocation.

Run: 2026-09-01T (local session). `nen` `0.1.0`
(`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`). `gh` authenticated as `zheref`. All
commands below ran **read-only** against the live `zheref/bankai-core` repository (issue reads,
label reads, `gh issue view --json`) or against local scratch JSON/markdown files with **no**
GitHub write of any kind. `nen label apply` (the one mutating verb this port uses) was **never
exercised live** — contract-inspected only, per the shared brief's rule that a mutating verb is
A/B'd by flag mapping, never by a live call against `bankai-core`.

---

## 1. Command mapping table

| # | Old (prose / raw `gh`) | New (`nen`) |
|---|---|---|
| 1 | This skill's own `<CODE>#<N>` invocation, split by hand, "same resolution rules as `drive` § 1" | `nen parse build --grammar "<code>#<n>" --line "<invocation>"` — a working two-slot grammar (verified live, § 2.1) |
| 2 | "Codes from `schemas/repos.json` → `product_codes`, case-insensitive" — read by hand | `nen repo resolve <CODE> --repo <path>` (verified live, § 2.2) |
| 3 | "If `#<N>` is a PR, hand straight to `drive`" — no mechanism given at all | Attempted via `nen issue chain-position`/`terminus` — **does not detect it** (verified live, § 2.3, filed as a finding); kept as a plain `gh issue view --json pull_request` check, disclosed, not mechanized |
| 4 | § 2's whole "decide from labels, body and linked objects, never the title" — a five-way judgment call made by eye every time | `nen issue chain-position --target ... --issue N --chain-labels ...` — one call, five states, verified live against six real objects (§§ 2.4–2.7) |
| 5 | § 4's "the delivery PR is the terminus" — reasoned per-case (epic mode, shikai mode, chore) | `nen issue terminus --target ... --issue N --chain-labels ...` — verified live (§ 2.6) |
| 6 | § 4's epic-wave release — "with a coordinator ... the coordinator releases the next unblocked child" / "where there is no coordinator, releasing the next child is this run's job", computed by reading the checklist by eye | `nen epic next-wave --body-file ... --citation ... [--completed] [--inflight] --cap 2 --out ...` — verified live end-to-end including flip/redraw/cap/duplicate-refusal (§ 2.8), and against two real (if stale-shaped) epic bodies (§ 2.9) |
| 7 | § 4's "never drive more than two PRs concurrently" — eyeballed | `nen loop slots --efforts ... --local-cap 2 --json` — verified live, occupied/free/binding computed, freed only on `ready && prompted` for the local plane (§ 2.10) |
| 8 | § 8's gate-stop banner + efforts table — hand-formatted markdown | `nen stop --who Kurapika --gate <Gn> efforts.md` — verified live, byte-padded table + banner (§ 2.11) |
| 9 | § 5's release — `bankai:stage/building` applied by the CI-routing logic, then a whole section verifying the CI builder's own `probe`/`build` job ran | `nen label apply <ref> --label bankai:stage/building --repo-slug ... --reason ... --run` for the release half (contract-verified only, § 3 — never exercised live against `bankai-core`); **the wake-verification half has no replacement at all**, because Hatsu holds no CI plane to verify a wake against — this is the skill's own declared structural change (`SKILL.md` § 1 callout, § 5), not a `nen` mechanization |

**Count.** Before: **zero** deterministic steps in §§ 1–5, 8 of the old skill — invocation
splitting, code resolution, chain-position judgment, mode routing, epic-wave release, the
concurrency cap and the gate-stop banner were all agent prose or raw `gh`. After: **seven** of
those (rows 1, 2, 4, 5, 6, 7, 8 above) are now single `nen` verb calls, verified live against real
objects where GitHub-shaped, or against local scratch files where the computation is purely
mechanical (epic bodies, concurrency ledgers, gate-stop tables). What remains prose: the PR-vs-issue
disambiguation (row 3 — a verified `nen` gap, not a choice), mode/severity judgment at § 3, the G5
diagnosis at § 7, and — genuinely new, not present in the old skill at all — the entire "Kurapika
builds it himself" declared-change paragraph that used to be "verify the CI builder woke."

---

## 2. Live A/B transcript (read-only)

### 2.1 — `nen parse build`, a working two-slot grammar

```
$ nen parse build --grammar "<code>#<n>" --line "BC#918"
code: BC
n: 918

$ nen parse build --grammar "<code>#<n>" --line "BC#918" --json
{
  "skill": "build", "template": "<code>#<n>", "line": "BC#918", "ok": true,
  "slots": [{"name":"code","value":"BC","suffix":false},{"name":"n","value":"918","suffix":false}],
  "missing": [], "problems": [],
  "corrected": "build BC#918",
  "echo": ["code: BC", "n: 918"]
}

$ nen parse build --grammar "<code>#<n>" --line "BC918"
nen parse: <n> is required and the line does not supply it.

Corrected line:
  build BC918#<n>
```

Both slots resolve correctly and a malformed line is refused with a corrected line ready to paste.
Unlike `backlog-state`'s single-slot `<repo>[@<gate>]` template (that port's own A/B doc, § 3), this
two-slot template shows no bracket-swallowing defect — `build`'s own invocation grammar is genuinely
mechanized, not routed around.

### 2.2 — `nen repo resolve`, explicit code, case-insensitive

```
$ nen repo resolve BC --repo <bankai-core checkout>
zheref/bankai-core  (BC)  via code

$ nen repo resolve bc --repo <bankai-core checkout>
zheref/bankai-core  (BC)  via code
```

Matches `schemas/repos.json`'s `product_codes.BC`. (The no-token origin-based form's own gap is
already filed against `backlog-state`'s port, `docs/ab/backlog-state.md` § 2.1 — not re-proven
here; this skill only ever uses the explicit-code form.)

### 2.3 — the PR-vs-issue gap, reproduced live

```
$ nen issue chain-position --target zheref/bankai-core --issue 925 --repo <bankai-core checkout> \
    --chain-labels "idea=bankai:stage/idea,researched=bankai:stage/researched,\
approved-team=bankai:stage/ready-for-bankai,approved-direct=bankai:stage/ready-for-shikai,\
building=bankai:stage/building,in-review=bankai:stage/in-review,epic=bankai:epic"
#925: routable
  carries no idea, epic or release label -- a routable child or standalone task

$ nen issue terminus --target zheref/bankai-core --issue 925 --chain-labels "<same map>"
terminus: own-pr
  no epic or chore label -- the terminus is this issue's own PR into 'main'
```

`zheref/bankai-core#925` is a real, open **pull request** (used as a worked example in
`docs/ab/pr-state.md`), not an issue. Neither verb noticed — both answered exactly as they would
for an ordinary routable issue, with no error and no distinguishing field in `--json` either.
**Filed** (`SKILL.md` § 10, finding 1).

### 2.4 — `chain-position`, an `in-review`/`building` issue

```
$ nen issue chain-position --target zheref/bankai-core --issue 918 --repo <bankai-core checkout> \
    --chain-labels "<same map as § 2.3>"
#918: building
  carries 'bankai:stage/in-review' -- the release already happened, so the next move is the PR-shaped one
```

`#918` carries `bankai:stage/in-review` (Sasuke/Tenma reviewing, in the retired canon) and no other
stage label. `chain-position` folds it into `building` — confirmed correct: it already has an open
PR (`#925` above references it), so the old skill's own "already building, with or without a PR —
skip to the drive engine" row is exactly right.

### 2.5 — `chain-position`, routable children (no stage label at all)

```
$ nen issue chain-position --target zheref/bankai-core --issue 673 --repo <bankai-core checkout> --chain-labels "<same map>"
#673: routable
  carries no idea, epic or release label -- a routable child or standalone task

$ nen issue chain-position --target zheref/bankai-core --issue 710 --repo <bankai-core checkout> --chain-labels "<same map>"
#710: routable
  carries no idea, epic or release label -- a routable child or standalone task

$ nen issue chain-position --target zheref/bankai-core --issue 494 --repo <bankai-core checkout> --chain-labels "<same map>"
#494: routable
  carries no idea, epic or release label -- a routable child or standalone task
```

All three carry only severity/agent-scope labels (`bankai:agent/yamamoto`, `bankai:agent/kisuke`) —
correctly read as routable children awaiting a mode confirmation (§ 3 of the ported skill), not yet
released.

### 2.6 — `terminus`, `own-pr` and `run-already-ended`

```
$ nen issue terminus --target zheref/bankai-core --issue 918 --chain-labels "<same map>" --integration-prefix "integration/" --trunk main
terminus: own-pr
  no epic or chore label -- the terminus is this issue's own PR into 'main'

$ nen issue terminus --target zheref/bankai-core --issue 733 --chain-labels "<same map>"
terminus: run-already-ended
  #733 is 'closed' -- whatever closed it is the answer, not a PR still to come
```

`#733` is bankai-core's own closed shell→TypeScript migration epic — real, closed, and correctly
read as ended rather than as a live terminus.

### 2.7 — `chain-position`, a closed issue and the undecidable/refusal cases

```
$ nen issue chain-position --target zheref/bankai-core --issue 733 --repo <bankai-core checkout> --chain-labels "<same map>"
#733: closed
  state is 'closed' -- a closed issue ends the run; re-opening is a human's call

$ nen issue chain-position --target zheref/bankai-core --issue 918 --repo <bankai-core checkout>
#918: undecidable
  role(s) building, in-review, idea, epic were never mapped, so 'routable' cannot be told apart
  from 'building'/'in-review'/'idea'/'epic' for this issue -- a run that reads a building issue as
  routable releases it twice. Supply --chain-labels for each; guessing which label means 'building'
  is exactly what this check exists to refuse.
(exit 1)

$ nen issue chain-position --target zheref/bankai-core --issue 918 --repo <bankai-core checkout> --chain-labels "bogus=foo"
nen: --chain-labels: 'bogus=foo' names an unknown role 'bogus' -- expected one of idea, researched,
approved-team, approved-direct, building, in-review, epic, chore.
(exit 2)
```

**No live `bankai-core` issue currently carries** `bankai:stage/idea`, `bankai:stage/researched`,
`bankai:stage/ready-for-bankai` or `bankai:stage/ready-for-shikai` — checked both open and all
states:

```
$ gh issue list --repo zheref/bankai-core --state all --label "bankai:stage/idea" --limit 5 --json number,title,state
[]
$ gh issue list --repo zheref/bankai-core --state all --label "bankai:stage/researched" --limit 5 --json number,title,state
[]
$ gh issue list --repo zheref/bankai-core --state all --label "bankai:stage/ready-for-bankai" --limit 5 --json number,title,state
[]
$ gh issue list --repo zheref/bankai-core --state all --label "bankai:stage/ready-for-shikai" --limit 5 --json number,title,state
[]
$ gh issue list --repo zheref/bankai-core --state all --label "bankai:epic" --limit 20 --json number,title,state
[{"number":733,"state":"CLOSED", ...},{"number":568,"state":"CLOSED", ...},{"number":545,"state":"CLOSED", ...}]
```

Those four chain-role rows in `SKILL.md` § 2 are contract-verified against `nen issue
chain-position --help` and the label taxonomy only — not live-confirmed on a real object. Said so
plainly rather than presenting all five rows as equally proven.

### 2.8 — `nen epic next-wave`, synthetic checklist, full lifecycle

Real epic bodies (§ 2.9) turned out not to use the checklist shape this verb expects, so the shape
itself — and the flip/redraw/cap/duplicate behaviour — was confirmed with a small synthetic
checklist, read-only in the sense that nothing was written anywhere but a local scratch file:

```
$ cat synth1.md
## Children

- [ ] #101 Phase 0a
- [x] #102 Phase 0b
- [ ] #103 Phase 1 (blocked by #101, #102)

$ nen epic next-wave --body-file synth1.md --citation CON-9 --json
{"total":3,"done":1,"release":[{"child":101,"owner":null}]}

$ cat synth2.md         # same content, "- [x] Phase 0a — #101" (trailing #N instead of leading)
$ nen epic next-wave --body-file synth2.md --citation CON-9 --json
{"total":0,"done":0,"release":[]}
```

**Confirmed: only `- [ ] #<N> …` / `- [x] #<N> …` — checkbox immediately followed by the child
reference — is recognised.** A trailing `#<N>` elsewhere on the same line is invisible to the
parser; `total` reads `0` with no error. Filed (`SKILL.md` § 10, finding 3).

```
$ nen epic next-wave --body-file synth1.md --citation CON-9 --completed 101 --out synth1_out.md --json
{"total":3,"done":2,"release":[{"child":103,"owner":null}]}

$ cat synth1_out.md
## Progress

`▓▓▓▓▓▓▓▓░░░░` **2/3** · 67%
<sub>Auto-maintained by the CON-9 coordinator — do not hand-edit.</sub>

## Children

- [x] #101 Phase 0a
- [x] #102 Phase 0b
- [ ] #103 Phase 1 (blocked by #101, #102)
```

`--completed` flips the child and redraws a progress footer citing the given clause id, exactly as
documented.

```
$ cat synth3.md
## Children

- [ ] #201
- [ ] #202
- [ ] #203

$ nen epic next-wave --body-file synth3.md --citation CON-9 --inflight 201,202 --cap 2 --json
{"total":3,"done":0,"release":[]}
```

Cap enforced: two already-released children occupy both slots, so `#203` — with no declared
blocker at all — still does not release.

```
$ cat synth4.md
## Children

- [ ] #301
- [ ] #301

$ nen epic next-wave --body-file synth4.md --citation CON-9 --json
nen: duplicate child checklist id(s): #301 -- each child must appear in the checklist exactly once.
A duplicated id is an authoring error this coordinator refuses to guess past, because which line is
authoritative changes both the done-count and which blockers read as satisfied.
(exit 1, --out never written)
```

Duplicate-id refusal confirmed exactly as documented.

### 2.9 — `nen epic next-wave` against `bankai-core`'s own real epic bodies

```
$ gh issue view 733 --repo zheref/bankai-core --json body -q .body > epic733body.md   # closed, real
$ grep -n '^- \[' epic733body.md
(no matches -- this epic's "Phases" section is a markdown table, not a checklist)

$ gh issue view 568 --repo zheref/bankai-core --json body -q .body > epic568body.md   # closed, real
$ grep -n '^- \[' epic568body.md
63:- [x] **Child 1 — machinery: DONE.** [BC-IS-#570](https://...) → [BC-PR-#577](https://...), ...
64:- [ ] Child 2 — definitions: bind all 6 askers ... — [BC-IS-#571](https://...). ...
65:- [x] **Child 3 — canon: DONE.** ... — [BC-IS-#572](https://...). ...
66:- [ ] Release tag + CON-22 fan-out (consumers re-pin copilot-sweeper.yml)

$ nen epic next-wave --body-file epic568body.md --citation CON-9 --json
{"total":0,"done":0,"release":[]}
```

`#568`'s checklist is real and human-legible, but every child reference is a markdown link
(`[BC-IS-#570](url)`) after bold prose, never a bare `- [ ] #<N>` — `nen` reads zero children.
`#733` has no checklist at all, only a phases table. **Neither of `bankai-core`'s own two real,
closed epics is shaped the way this verb expects** — the checklist convention `nen epic next-wave`
mechanizes is a new authoring requirement this port introduces going forward (`SKILL.md` § 4), not
one bankai-core's own historical epics already followed.

### 2.10 — `nen loop slots`, local-plane concurrency

```
$ cat efforts1.json
[
  {"id":"BC-IS-#673","plane":"local","prOpen":false,"ready":false,"prompted":false},
  {"id":"BC-IS-#710","plane":"local","prOpen":true,"ready":false,"prompted":false}
]

$ nen loop slots --efforts efforts1.json --local-cap 2 --json
{
  "ci": {"plane":"ci","cap":2,"occupied":0,"free":2,"holding":[],"binding":false},
  "local": {"plane":"local","cap":2,"occupied":2,"free":0,
    "holding":[
      {"id":"BC-IS-#673","why":"authored locally, no PR yet"},
      {"id":"BC-IS-#710","why":"PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it"}
    ],"binding":true},
  "done": []
}
(exit 1)

$ cat efforts2.json      # BC-IS-#673 flipped to ready:true, prompted:true
$ nen loop slots --efforts efforts2.json --local-cap 2 --json
{
  "ci": {"plane":"ci","cap":2,"occupied":0,"free":2,"holding":[],"binding":false},
  "local": {"plane":"local","cap":2,"occupied":1,"free":1,
    "holding":[{"id":"BC-IS-#710","why":"PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it"}],
    "binding":false},
  "done": ["BC-IS-#673"]
}
(exit 0)

$ nen loop slots --efforts efforts1.json --json          # no cap flags at all -- defaults
{"local": {"plane":"local","cap":7, ...}, "ci": {"plane":"ci","cap":2, ...}}
```

Confirms both the semantics (a local slot frees only on `ready && prompted`, never on "the PR
opened" — there is no `ci` plane here to apply that rule to) and the default-cap finding: **omitting
`--local-cap` defaults to `7`**, not this skill's own hard limit of `2`. Filed (`SKILL.md` § 10,
finding 4) — this port always passes `--local-cap 2` explicitly.

### 2.11 — `nen stop`, the gate-stop banner

```
$ cat efforts.md
| Effort | Refs | Status (gate) | Needs |
| --- | --- | --- | --- |
| Fix cancelled-build guard | BC-IS-#918 | 🟢 (G4) | Merge |

$ nen stop --who Kurapika --gate G4 efforts.md
=== YOUR INPUT IS NEEDED ==============================
who: Kurapika
gate: G4 -- policy/spec change
rung 1 (push notification): NOT fired -- the caller's to have sent, before this renders.
rungs 2-3 (OS notification, audible cue): not fired by nen -- only git/gh subprocesses are ever shelled out to.
see the table below. No banner above => nothing needs you right now.

| Effort                    | Refs       | Status (gate) | Needs |
| ------------------------- | ---------- | ------------- | ----- |
| Fix cancelled-build guard | BC-IS-#918 | 🟢 (G4)       | Merge |
```

Renders the banner, both notification-rung status lines, and the padded table from a plain
pipe-table input, exactly as `nen stop --help` documents.

---

## 3. Mutating verb — contract inspection only

`nen label apply <ref> --label bankai:stage/building --repo-slug <owner/name> --reason <text>
[--ledger <path>] [--run]` — the release half of § 5. Per the shared brief this is **never**
exercised live against `zheref/bankai-core`, even with `--run` omitted (a dry run is only ever run
against `zheref/hatsu` itself, and Hatsu carries no `schemas/labels.json` of its own to validate
against, so no dry run was attempted there either). Flag-by-flag mapping against the old skill's own
prose (`bankai:stage/building` applied, "every application is logged: object, label, time"):

| Old prose | `nen label apply` flag |
|---|---|
| the object released | `<object-ref>` (`<CODE>-<IS|PR>-#<N>`) |
| the label applied | `--label bankai:stage/building` |
| logged, object * label * time | the ledger record (`--ledger`, defaults under the target repo's root) |
| — (no old-side equivalent) | `--reason <text>` — recorded in the ledger, never sent to GitHub |
| CON-38's dry-run-first convention | `--run` — omitted, the ledger still records the decision as `outcome:"dry-run"` |

No behavioural gap found in the contract itself; `nen wake fire`/`nen wake verify` (the old skill's
third authority row) are deliberately **not** mapped at all — `SKILL.md` § 6 explains why (Hatsu
holds no CI builder to wake), and pointing a "spot check" of `wake fire` at `bankai-core` would
itself be the exact write this port must never make.

---

## 4. Findings (report separately, do not route around)

1. **`nen issue chain-position` / `nen issue terminus` never verify the object number they were
   given actually names an issue, not a pull request.** Reproduced live against a real PR
   (`zheref/bankai-core#925`, § 2.3) — both answer as if it were an ordinary issue. This port's own
   `SKILL.md` § 1 keeps a manual `gh issue view --json pull_request` check ahead of both verbs as a
   direct result.
2. **`--chain-labels` has no partial-credit mode.** Any role actually in play that is missing from
   the map makes the whole call `undecidable` (exit `1`); an unknown role name is refused outright
   (exit `2`). Both reproduced live (§ 2.7). Not a defect — the refusal text says exactly why — but
   worth stating plainly since it means the full eight-role map (minus roles a repo's taxonomy
   genuinely lacks, like `chore` here) must be supplied every single call.
3. **`nen epic next-wave`'s checklist parser only recognises `- [ ] #<N> …` / `- [x] #<N> …`** —
   checkbox immediately followed by the reference. Reproduced live three ways (§§ 2.8–2.9), and
   confirmed against both of `bankai-core`'s own real, closed epics, neither of which is shaped this
   way (§ 2.9) — a genuine authoring-convention gap between this verb and this repository's own
   historical practice, not a bug in the verb.
4. **`nen loop slots`'s local-plane default cap is `7`.** Reproduced live (§ 2.10). This skill's own
   hard limit of two concurrently-driven efforts requires `--local-cap 2` on every call; the default
   would silently permit more than three times that.

---

## 5. Residue

- **Judgment kept, per the shared brief's boundary list**: mode/severity reasoning and the
  `DECIDE` brief (`SKILL.md` § 3), the G5 diagnosis and what-to-say-when-stuck (§ 7), synthesized
  status lines (§ 8). `nen` computes and formats; deciding what a stall or a mode call *means* to
  the maintainer stays this skill's.
- **The entire CI-wake-verification half of the old skill's § 5 has no replacement, by design** —
  it verified a plane (CI builders) Hatsu does not have. This is the single largest structural
  change in this port, and it is a **declared** one (`SKILL.md` § 1 callout, following the precedent
  `bankai-handbooks` set for the identical `CON-37` gap in its own § 4), not a `nen` mechanization at
  all.
- **Posting an epic's redrawn body back to GitHub** — `nen epic next-wave --out` only rewrites a
  local file; `gh issue edit --body-file` remains a necessary raw call afterward (`SKILL.md` § 4,
  § 11). No verb owns writing an issue body back to the API.
- **Keeping exactly one `bankai:stage/*` label on an object at a time** (`CON-9`) is not itself
  enforced by `nen label apply`, which applies and logs exactly the one label it is given.
- **The PR-vs-issue check** (finding 1 above) stays a plain `gh` read until `nen` grows one.
- **`nen wake fire`/`nen wake verify`** are `drive`'s verbs, not this skill's, and are not exercised
  or mapped here at all — see § 3 and `SKILL.md` § 6.
- Verdict parity between `nen pr ready` and `pr_ready_gate.sh` was already proven across the live
  estate by `nen`'s shadow window (`docs/evidence/shadow-window-p1.md` in `zheref/nen`); this port's
  own use of readiness (`SKILL.md` § 4, step 4) is a pointer to that landed result
  (`docs/ab/pr-state.md`), not re-proven here.
