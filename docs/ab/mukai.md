# A/B evidence — `mukai` (new skill, wave 3)

`claude/skills/mukai/SKILL.md`: the composite that turns a pushed branch into an open pull request —
`murasaki`¹ → `hanten`² → checkpoint/catch-up/aka verification³ → `gyo` over aka results⁴ → final
unchanged catch-up and update push⁵ → evidence⁶ → `shibari`⁷ → landing report and `en`⁸. Human-called,
and the call is the authorization for the PR *and* for the
evidence mechanism's public step.

**Phase ruling, 2026-09-12.** Mukai owns coverage measurement/gating, never regression execution.
Every review, coverage-test, snapshot, execution-configuration, metadata, or catch-up tree change
invalidates evidence and returns through kokusen plus aka's narrow verification helper before the
already-published update is pushed. A final catch-up that changes the tree pushes nothing and loops
through regression and coverage.

**A new skill, and a composite one, so this record is shaped the way `docs/ab/ren.md` is.** Mukai
restates no protocol: every deterministic step inside the run belongs to a composed skill and is
evidenced in *that* skill's A/B file. What this document has to establish is only what is genuinely
mukai's own — **the invocation's shape, the parameter table's honesty, and the claim that the
composition has no verb** — and two of those three are boundaries rather than mechanisms.

Run: 2026-09-10 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
`nen parse` is pure and `nen schema check` is read-only; the throwaway fixture at
`<worktree>/.nen-fixture` was deleted before this branch was committed. **No verb was run against
any primary checkout in a way that could write to it, and no GitHub call of any kind was made.**

Nothing below is redacted; both repositories are public.

---

## 1. The skill

Mukai composes six skills in a fixed order and asserts exactly four things of its own about that
order, plus the run's boundaries.

| Mukai's own step | Owned by | Evidence lives in |
|---|---|---|
| The invocation (a bare verb) | **nothing — by the same reasoning `aka` § 1 gives** | **§ 2.1, here** |
| The parameter table's pin caveat | `nen schema check` | **§ 2.2, here** |
| Run the composition | **nothing — a boundary, not a gap** | `docs/ab/ren.md` § 2.2, cited not re-proven |
| 1 · catch up | `hatsu:murasaki` | that skill's A/B file |
| 2 · adversarial review | `hatsu:hanten` | that skill's A/B file |
| 3 · one full regression, with UI-specific handling where declared | `hatsu:tsukuyomi`, with `hatsu:kotoamatsukami` handling that same UI invocation | those skills' A/B files |
| 4 · the coverage bar | `hatsu:gyo` | that skill's A/B file |
| 5 · the evidence rows | `hatsu:rikugan` `as landing` | `docs/ab/rikugan.md` |
| 6 · compose and open | `hatsu:shibari` | `docs/ab/shibari.md` |

**Two rows are mukai's; the rest are references.** A composite whose A/B file re-proves its members'
verbs has duplicated the members, which is the failure mode this table exists to avoid — the same
discipline `docs/ab/ren.md` § 1 states.

---

## 2. Verbs exercised live

### 2.1 — There is no grammar here to parse, and that is a decision

`hatsu:mukai` takes no arguments. `nen parse <skill> --grammar <template> --line <text>` exists for a
grammar; a bare verb has none. The alternative — inventing an optional clause so that a parse could
be echoed — is refused by the engine itself when the clause is a lone bracketed slot, which this
wave re-confirmed while designing `en`'s grammar (`docs/ab/en.md` § 2.1):

```
$ nen parse en --grammar "[<ref>]" --line ""
nen parse: template '[<ref>]' is refused: its leading slot <ref> is bracketed but nothing introduces
it, so an omitted value cannot be told apart from a mistyped one. Anchor it behind a literal ('word
[<ref>]') or drop the brackets.
exit=2
```

**So a bare verb stays a bare verb.** `aka` § 1 reached the same conclusion for the same reason and
`tensho` § 1 records the engine boundary that forces it. Recorded here so that "mukai has no
`nen parse` line" reads as a decision with a transcript behind it rather than an omission.

### 2.2 — `nen schema check` still has no `nen/workflow.json` row, at this wave's own worktree

Read-only, against the worktree this wave was authored in:

```
$ nen schema check --repo .
repository: <worktree>
  FAIL  nen/labels.json    ... no such file ...
  FAIL  nen/repos.json     ... no such file ...
  FAIL  nen/colors.yml     ... no such file ...
  warn  nen/gates.json     ... no such file ...
  ok    nen/contract.json  dependency (nen >= 0.3, pinned v0.3.0), project (1 lane: plugin; 10 verbs; 1 toolchain entry)
nen: this repository's taxonomy could not be read. Nen has no built-in copy to fall back on -- a
binary that guessed the names would report a taxonomy this repository does not have.
exit=1
```

**Five rows, and none of them is `nen/workflow.json`** — the same result `docs/ab/rikugan.md` § 2.4
recorded in wave 1, re-run here because `SKILL.md` § 5's whole parameter table depends on it. The
workflow schema and loader are P1 and arrive with the `v0.4` line; until then **every step reads the
file as data and states the default it fell back to**, and mukai neither supplies a default nor
overrides one.

*(The four `FAIL`/`warn` rows are Hatsu's own standing state — it ships a `dependency`-only contract
and no taxonomy layer — and are not a finding of this run. The `project` clause on the `ok` row is
new since wave 1's transcript only because Hatsu's contract gained its `project` block then.)*

### 2.3 — The composition has no verb, and this file does not re-prove it

`docs/ab/ren.md` § 2.2 establishes it live for `ren`, and the argument transfers **more** strongly to
mukai, not less: `nen watch until` spawns one program with no shell and refuses a mutating one
(re-confirmed in this wave, `docs/ab/en.md` § 2.3), and `nen loop slots` counts concurrency across
efforts rather than sequencing phases within one. A mukai run is six skills, many programs, most of
them mutating, and **four of them able to stop and ask the maintainer something** — which is the
part no loop primitive could own even if the other objections were answered.

**Cited, not re-run.** Re-running `ren`'s transcripts under a different heading would produce a
second record of the same fact, and two records of one fact is how they come to disagree.

---

## 3. Residue

**One entry, and it is a boundary:**

1. **The composition itself has no verb and is not expected to get one** (§ 2.3). **Mukai adds no
   residue of its own** — every deterministic step inside the run is a verb or a named residue *in
   the skill that owns it*: `nen pr cascade-main` and its missing `--no-push` (step 1, named in
   `docs/ab/ao.md`), the Agent tool (step 2), `nen shu test` and the missing `nen shu test-report`
   (step 3), `nen shu coverage` and the missing `--touched` (step 4), the missing `nen shu evidence`
   (step 5, named in `docs/ab/rikugan.md` § 3), `gh pr create` and the missing `nen pr edit-body`
   (step 6, named in `docs/ab/shibari.md` § 3).

**The test this file holds itself to:** if a bare shell command ever appears in
`claude/skills/mukai/SKILL.md`, it belongs in a composed skill as that skill's named residue
instead, and its presence in mukai is the bug. At the time of this run there is none.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — The authorization question is the one thing in this skill with no mechanical backing, and cannot have one

`SKILL.md` § 1 makes two claims that no verb can enforce: that the maintainer's `mukai` call
authorizes the pull request, and that it also authorizes the evidence mechanism's public step (the
`public-mirror` case, on KroApple `ci_scripts/pr_screenshots.sh -y`). **Neither is checkable by a
binary**, because both are facts about what a human meant by typing a word. The mitigation is
structural rather than mechanical: the call is a bare verb with no arguments, so there is no way to
type it and mean *less* than it means; and step 6 reports what it actually published, so an
over-broad reading shows up in the handover line rather than silently.

**Recorded rather than filed**, because the alternative — a per-scene confirmation — converts one
authorization into a queue of them, which is the failure mode `aka` § 1 and this skill § 1 both
exist to prevent.

### 4.2 — Four of the run's six steps can stop, and no verb sequences a run that stops

This is the sharpest form of `docs/ab/ren.md` § 4.2's finding (*"nen has no vocabulary for 'a turn',
and probably should not"*). Steps 1, 2, 3 and 4 each carry a G5, each rendered by `jutaisho` § 4 with
a question through the surface's own picker. **A verb that orchestrated mukai would have to own the
asking**, which is precisely what the local plane keeps in the conversation. Recorded so the absence
stays a decision on file rather than an oversight someone later "fixes".

### 4.3 — Not a finding: mukai's own rules are all prose, and there is nothing mechanical to refuse

Mukai's four assertions are about **ordering** (1 before 2, 2 before 3, 3 before 4, 5 before 6) and
its sharpest refusals are about **suggestions** — it never proposes itself, never claims readiness,
never opens a PR from a run that stopped. **No verb can refuse a sentence**, which `docs/ab/ren.md`
§ 4.4 already records for `ren`'s own never-propose-`aka` rule. The redundancy across
`aka` § 1, `mukai` § 1 and `WORKFLOW.md` § 4 is deliberate for the same reason it is there: a rule
that lives in only one file survives exactly as long as nobody reads that one.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| `nen/workflow.json` unvalidated at step 1 | `nen schema check --repo .` | `1` overall, six rows, the workflow row `ok` |

```
  ok    nen/contract.json  dependency (nen >= 0.6, pinned v0.6.0), project (1 lane: plugin; 10 verbs; 1 toolchain entry)
  ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}' off 'main', checks: lint
```

§ 2.2 recorded five rows, none of them the workflow file. **Every step of this composite reads that file**
— the branch template, the iteration checks, the ladder, the reports directory, the trailers — and a
malformed key is now a FAIL by pointer rather than a thing each step has to notice for itself.

The verbs the composed skills gained at this pin are recorded in their own A/B files:
`docs/ab/murasaki.md` (`pr cascade-main --no-push`), `docs/ab/gyo.md` (`shu coverage --touched`),
`docs/ab/kotoamatsukami.md` (`shu evidence`), `docs/ab/shibari.md` (`pr edit-body`) and
`docs/ab/rikugan.md` (`report data`, `report render`).

**Step 7's mirror check is a real check now** rather than a skip: `bash scripts/surface_mirror_check.sh`
exits `0` at this pin, `codex ok: 40`, `cursor ok: 47`.
