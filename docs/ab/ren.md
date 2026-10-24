# A/B evidence — `ren` (new skill, wave 2)

`claude/skills/ren/SKILL.md`: the composite turn loop —
`breath`¹ (first turn) → `rasengan`² → `kokusen`³ → `amaterasu`⁴ → `spiritual-message`⁵ → `jutaisho`⁶ — one
pass per request, never pushing, ending only on `hatsu:aka` or `hatsu:tensho`.

> **Dated 2026-09-10 — the turn's order changed after this record was written.** The header line
> above reads step 2 as `rasengan`-the-build, and the record's own § 2 table calls it *build*. The
> maintainer's ruling of 2026-09-10 ([`../ROSTER.md`](../ROSTER.md) HR-55, HR-58) folds
> that step into `rasengan`, which is the **authoring** phase, and seats the compile-before-commit in
> `kokusen`. The order is now six whole steps: `breath`¹ (and it proves the base tip) → `rasengan`²
> (author the change) → `kokusen`³ (verify the tree, then commit) → `amaterasu`⁴ → `spiritual-message`⁵ →
> `jutaisho`⁶. The transcripts below are untouched and still stand — they are evidence about
> `nen parse`, `nen watch until` and `nen loop slots`, none of which this ruling touches.

**A new skill, and a composite one, so this record is shaped differently from the atomic four.**
Ren restates no protocol: every deterministic step inside a turn belongs to a composed skill and is
evidenced in *that* skill's A/B file. What this document has to establish is only what is genuinely
ren's own: **the invocation grammar, and the claim that no `nen` verb can drive the loop.** Both are
verified live below.

Run: 2026-09-09 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
`nen parse` is pure; `nen watch until` was invoked in a form that is refused **before** the first
observation, so nothing was spawned. The constructed throwaway fixture at `<worktree>/.nen-fixture`
supplied the declaration behind `nen shu build`'s classification and was deleted before the branch
was committed. **No verb was run against any primary checkout in a way that could write to it.**

Nothing below is redacted; both repositories are public.

---

## 1. The skill

Ren composes six skills in a fixed order and asserts exactly three things of its own about that
order — build before commit, launch before report, report before bell — plus the loop's boundaries.

| Ren's own step | Owned by | Evidence lives in |
|---|---|---|
| Parse `<request>` | `nen parse ren --grammar "<request>"` | **§ 2.1, here** |
| Drive the loop | **nothing — a boundary, not a gap** | **§ 2.2, here** |
| 1 · warm up (first turn only) | `hatsu:breath` | that skill's A/B file |
| 2 · build | `hatsu:rasengan` | that skill's A/B file |
| 3 · commit | `hatsu:kokusen` | that skill's A/B file |
| 4 · launch | `hatsu:amaterasu` | that skill's A/B file |
| 5 · report | `hatsu:spiritual-message` | `docs/ab/spiritual-message.md` |
| 6 · bell | `hatsu:jutaisho` | `docs/ab/jutaisho.md` |

**Two steps are ren's; six are references.** A composite whose A/B file re-proves its members'
verbs has duplicated the members, which is the failure mode this table exists to avoid — the same
discipline `docs/ab/futon.md` applies to `backlog-loop`'s engine.

---

## 2. Verbs exercised live

### 2.1 — `nen parse ren`: a free-text request slot, and the empty line refused

```
$ nen parse ren --grammar "<request>" --line "add the resume path to the session list"
request: add the resume path to the session list
exit=0

$ nen parse ren --grammar "<request>" --line ""
nen parse: <request> is required and the line does not supply it.

Corrected line:
  ren <request>
exit=2
```

**The slot is required, not bracketed, and that is the design.** A turn with no request is refused
outright rather than inferred from whatever the session was last doing — which is the one way a
turn loop can quietly start doing work nobody asked for. Contrast the three optional clauses in this
wave (`spiritual-message as`, `jutaisho at`, `ao from`), each of which had to be anchored behind a literal
because a lone bracketed slot is refused at the template (`docs/ab/spiritual-message.md` § 2.1). Ren needs no
anchor: its slot is mandatory.

### 2.2 — Neither loop primitive nen ships can drive a turn

**`nen watch until` refuses a mutating command before the first observation:**

```
$ nen watch until --command "nen shu build" --max-iterations 1
nen: 'nen shu build' classifies as mutating (nen shu build -- spawns the lane's declared build
unless --dry-run is given). izanami watches only; a command that writes needs 'nen parse izanagi
<task> until <condition> up to <N>' instead.
exit=2
```

```
$ nen parse izanami "nen shu build until it is green"
until: it is green
  [mutating] nen shu build
nen: at least one command does not classify as read-only -- the WHOLE run is refused. Use 'nen parse
izanagi <task> until <condition> up to <N>' for a loop that must act.
exit=1
```

**And the classifier's verdict on the rest of a turn's programs**, run in the same session:

| Command | Classification | exit |
|---|---|---|
| `git fetch origin main` | `[read-only]` | `0` |
| `nen wc classify --repo . --base main` | `[read-only]` | `0` |
| `nen shu test --dry-run` | `[read-only]` | `0` |
| `nen stop --who Kurapika --gate G5 efforts.md` | `[read-only]` | `0` |
| `nen shu build` | `[mutating]` | `1` |
| `nen shu dev --target sim` | `[mutating]` | `1` |
| `git merge --no-edit origin/main` | `[mutating]` | `1` |
| `git rebase origin/main` | `[mutating]` | `1` |
| `git push -u origin HEAD` | `[mutating]` | `1` |
| `osascript -e display` | `[unknown]` | `1` |
| `afplay /System/Library/Sounds/Glass.aiff` | `[unknown]` | `1` |

*(The `osascript`/`afplay` rows are `docs/ab/jutaisho.md` § 2.3's; reproduced here because they are
part of the same "can a watch drive a turn?" question.)*

**`nen watch until` spawns ONE program, DIRECTLY, with no shell** — its own `--help`: *"The
observation is spawned DIRECTLY -- no shell -- so `<bin>` must be a real executable on PATH … a
pipeline is not a command it can classify — one observation, one program."* A turn is six skills and
many programs, most of them mutating and two of them unclassifiable, so it has no single
`--command`, and would be refused if it had one.

**The other loop primitive is a different question entirely:**

```
$ nen loop --help
nen loop slots -- how many concurrency slots each plane has free.

usage:
  nen loop slots --efforts <path.json> --local-cap <n> [--ci-cap <n>]
...
A CI slot frees when the PR OPENS -- something else drives it from there. A
LOCAL slot frees only when the PR is READY and the human has been PROMPTED,
because nothing else is behind a locally-authored PR.
exit=0
```

`nen loop slots` counts **how many efforts may be in flight**, not how one effort takes its next
turn. Its unit is an effort with a PR; ren's unit is a request with no PR at all.

**Conclusion, stated in the skill as a boundary rather than filed as a finding:** the loop lives in
the session, under `hatsu:izanami`'s borrowed discipline — one line per turn, no line when nothing
happened, no background timer, no deferral primitive, and a visible way to end it.

---

## 3. Residue

**One entry, and it is a boundary:**

1. **The composition itself has no verb and is not expected to get one** (§ 2.2). nen owns
   operations; a turn loop is a conversation's shape. **Ren adds no residue of its own** — every
   deterministic step inside a turn is a verb or a named residue *in the skill that owns it*:
   `nen shu build` / `nen shu tools` (step 2), `nen stage triage` / `nen commit format` (step 3),
   `nen shu dev` (step 4), the absent `nen report data` / `nen report render` (step 5, named in
   `docs/ab/spiritual-message.md` § 3), `nen stop` plus the `osascript`/`afplay` fallback (step 6, named in
   `docs/ab/jutaisho.md` § 3).

**The test this file holds itself to:** if a bare shell command ever appears in
`claude/skills/ren/SKILL.md`, it belongs in a composed skill as that skill's named residue instead,
and its presence in ren is the bug. At the time of this run there is none.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — `nen watch until`'s one-program rule is correct and worth not eroding

§ 2.2. Every instinct that says "it would be convenient if a watch could run a pipeline" is the same
instinct that would make the classifier meaningless — a shell line can hide any write behind a
metacharacter, which is exactly why `claude/skills/izanami/SKILL.md` § 2 records a pipeline as
`[unknown]`. **This is recorded as a property to preserve, not a limitation to file**, because the
pressure to relax it will come from composites like ren, and ren is on record here as not wanting
it.

### 4.2 — nen has no vocabulary for "a turn", and probably should not

Two loop primitives exist and neither fits (§ 2.2): one polls a single read-only program until a
predicate holds, the other counts concurrency slots across efforts. There is no verb for "run these
six phases in order, stop where one refuses, report either way". **That gap is deliberate on nen's
part and should stay**: the phases are skills, not programs; three of the six ask the maintainer
something; and a verb that orchestrated them would need to own the asking, which is precisely what
the local plane keeps in the conversation. Recorded so the absence is a decision on file rather than
an oversight someone later "fixes".

### 4.3 — The composed skills' A/B evidence is where a reviewer of ren should actually look

A composite is only as sound as its members, and this file deliberately proves almost nothing.
A reviewer checking whether ren is safe should read, in this order: `docs/ab/spiritual-message.md` (step 5 —
five residue entries, the largest verb gap in the loop), `docs/ab/jutaisho.md` (step 6 — the
rung boundary), then the wave's `breath`, `rasengan`, `kokusen` and `amaterasu` records for steps
1–4. **Ren's own risk surface is the ordering and the two refusals** (never pushes, never proposes
`hatsu:aka`), and both are prose rules with no verb behind them — by nature, since there is nothing
mechanical to refuse when the thing being refused is a *suggestion*.

### 4.4 — Not a finding: `hatsu:aka` cannot be enforced as unprompted, only written as unprompted

Ren's sharpest rule — it never proposes `hatsu:aka` — has no mechanical enforcement anywhere and
cannot have one: no verb can refuse a sentence. It is stated in three files on purpose
(`ren` § 4, `aka` § 1, `jutaisho` § *Hard limits*), because a rule that lives in only one of them
survives exactly as long as nobody reads that one. Noted here so the redundancy reads as deliberate
rather than as the restatement ren otherwise forbids itself.


## Issue #48/#49 integration scenarios — 2026-09-12

The following are constructed protocol acceptance scenarios, not transcripts of a physical-device
run or a full regression. The current source contract is in docs/WORKFLOW.md, docs/DISCOVERY.md
and docs/LAUNCH-MIGRATION.md; historical command transcripts above retain their original dates.

| Scenario | Expected outcome |
|---|---|
| Ordinary turn with authored executable changes | Focused tests and inexpensive checks pass at kokusen; no regression or coverage run is scheduled by the turn/report |
| Hatsu's prose-only change | Declared plugin lint; tests not applicable; no launch target declared |
| Missing scoped test path | Capture an owned pending/linked dependency; no raw runner or substitute full suite |
| Physical target chooses simulator artifact | Report a consumer declaration defect and incomplete launch |
| Compatible build, successful install and launch | Report each actual outcome from Nen's core-checkout invocation |
| Absent versus present-but-unusable device | Only absence may take a declared fallback; unusable remains a readiness refusal |
| Nested repeated device names | Route to Nen #204; retain the consumer normalizer until a compatible release and verification |
| Turn/final report sees stale test or coverage artifact | Mark stale; do not execute tests/coverage merely to render the page |
| Repeated discovery already captured | Unchanged result and no GitHub write; retain canonical link |
| Filing unavailable | Durable sanitized pending record; original work continues where possible |

## Dated verification, 2026-10-23 — crash-and-resume (ren, every step) (zheref/hatsu#444)

Run: 2026-10-23, host `darwin` (arm64), twice with identical verdicts: nen `0.26.0` at `/Users/zheref/.local/bin/nen`
(the contract pin) and nen source `0.27.0` at zheref/nen `847f7dc4b8087591b3d68bb486d48855b7cb72b5` (`bun run src/index.ts`, the stack top of zheref/nen#518,
unreleased). Command, reproducible: `node scripts/resume_proof.mts --nen <nen>` (lane `resume-proof`). Each case
runs in a throwaway `git init` repository; nothing touched a primary checkout or GitHub.

**Method.** The composite's phases are recorded once uninterrupted, then once per interruption point:
killed after a phase's `nen phase end` and killed after its `nen phase begin`. The same line is invoked again
under the resume rule (ren § 2a; WORKFLOW § *The effort's ledgers*): the ledger is read once, a phase ended at
exit `0` is skipped and named, an open phase continues with `nen phase begin --resume`, the rest begin. The end
state is compared with the uninterrupted run with only the instants elided (phase order, names, exits, steps),
and the ledger must hold one entry per phase with exactly one `resumedAt` on the interrupted one. A finished
ledger re-invoked must be **byte-identical** on disk. A phase that **ended non-zero** (a refused step) is
re-invoked too: the resume must refuse it by name and leave the ledger bytes unchanged, never begin it a
second time (HA-PR-#463 review). Re-run after that case was added: 34/34 on both binaries.

```text
converged ren                  finished, re-invoked                 ledger bytes unchanged; 6 skipped
converged ren                  killed after-end breath              1 skipped, rasengan begun
converged ren                  killed mid-phase breath              0 skipped, breath resumed
converged ren                  killed after-end rasengan            2 skipped, kokusen begun
converged ren                  killed mid-phase rasengan            1 skipped, rasengan resumed
converged ren                  killed after-end kokusen             3 skipped, amaterasu begun
converged ren                  killed mid-phase kokusen             2 skipped, kokusen resumed
converged ren                  killed after-end amaterasu           4 skipped, spiritual-message begun
converged ren                  killed mid-phase amaterasu           3 skipped, amaterasu resumed
converged ren                  killed after-end spiritual-message   5 skipped, jutaisho begun
converged ren                  killed mid-phase spiritual-message   4 skipped, spiritual-message resumed
converged ren                  killed after-end jutaisho            6 skipped, nothing left to run
converged ren                  killed mid-phase jutaisho            5 skipped, jutaisho resumed
converged ren                  killed after failed breath           0 skipped, breath refused by name, ledger bytes unchanged
converged ren                  killed after failed rasengan         1 skipped, rasengan refused by name, ledger bytes unchanged
converged ren                  killed after failed kokusen          2 skipped, kokusen refused by name, ledger bytes unchanged
converged ren                  killed after failed amaterasu        3 skipped, amaterasu refused by name, ledger bytes unchanged
converged ren                  killed after failed spiritual-message 4 skipped, spiritual-message refused by name, ledger bytes unchanged
converged ren                  killed after failed jutaisho         5 skipped, jutaisho refused by name, ledger bytes unchanged
converged any                  resume a phase while another is open refused at exit 2, naming the open phase
```

**The durable half, live on HA-PR-#463** (nen source `847f7dc4b8087591b3d68bb486d48855b7cb72b5`; zheref/hatsu#445). `nen pr ledger post` posted the
slice (`posted: https://github.com/zheref/hatsu/pull/463#issuecomment-6376486942 … head 3836e79b3f71, 2 phase entries,
2 proof file(s)`); the same post again answered `unchanged`; `nen pr ledger read` answered `ok … foreign: 0`. In a
**fresh clone** (`git clone --depth 1 --branch opus/kurapika/sdd100-h-k-resume-durable-idle`), `read --restore` wrote the
slice's two phases (`restored: <clone>/.git/.nen/phases/…json`); `nen phase show` listed `author` ended at exit 0
(skipped by the rule; in WORKFLOW's one skip-line form that reads `skipped author: exit 0 at 2026-10-23T23:02:36.216Z (slice … @ 3836e79b3f71)`) and `shibari` open, and `nen phase begin --resume --phase shibari` continued it (`resumed shibari
… (open since 2026-10-23T23:02:36.263Z)`): no finished phase re-ran.

**Finding.** A second `read --restore` in that clone, after the resume had appended its `resumedAt`, is refused
at exit `1` (*"the local phase ledger … disagrees with the slice … nothing was overwritten"*), while `read` without
`--restore` answers `ok` at exit `0`. A local ledger that has only moved on since the post is read as a
disagreement, so ren § 2a passes `--restore` only where no local ledger exists. Owed to nen: `--restore` reading a
local ledger that extends the slice as ahead, not disagreeing.

**Not proved here.** A live session killed mid-composite and re-invoked: the proof drives the ledger verbs
the composite's resume rule reads, not a running model following the rule. The live publish half is in
`docs/ab/mukai.md` and `docs/ab/ren.md` (2026-10-23, HA-PR-#463).
