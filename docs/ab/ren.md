# A/B evidence — `ren` (new skill, wave 2)

`claude/skills/ren/SKILL.md`: the composite turn loop —
`breath`¹ (first turn) → `rasengan`² → `kokusen`³ → `amaterasu`⁴ → `rikugan`⁵ → `jutaisho`⁶ — one
pass per request, never pushing, ending only on `hatsu:aka` or `hatsu:tensho`.

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
| 5 · report | `hatsu:rikugan` | `docs/ab/rikugan.md` |
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
wave (`rikugan as`, `jutaisho at`, `ao from`), each of which had to be anchored behind a literal
because a lone bracketed slot is refused at the template (`docs/ab/rikugan.md` § 2.1). Ren needs no
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
   `docs/ab/rikugan.md` § 3), `nen stop` plus the `osascript`/`afplay` fallback (step 6, named in
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
A reviewer checking whether ren is safe should read, in this order: `docs/ab/rikugan.md` (step 5 —
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
