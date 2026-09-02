---
name: backlog-loop
description: Drive a target repository's backlog to zero open actionable issues, in severity order, as gate-ready PRs. Use when the maintainer asks to work the backlog, clear open issues, run the loop, or keep a repo current. Kurapika triages, sequences `build` and `drive` across at most two efforts, cuts tags and runs the fan-out at severity-batch boundaries, and reports one status board per cycle. Never merges main; G2/G4/G3 stay the maintainer's.
---

# Backlog loop — drive a backlog to zero, in severity order

**Nature: spans modes, named at each step.** Concurrency arbitration, severity triage, and
batch-boundary tag-cuts + fan-out are **Manipulator**/**Emitter** work Kurapika names directly.
The mode for any one issue's own authorship is whatever [`build`](../build/SKILL.md) § 3 confirms
for it — **Enhancer**, **Conjurer** or **Transmuter** — and this skill never re-derives that call;
it only decides *which* issue gets the next free slot and *when* a batch boundary fires.

The goal is **zero open *actionable* issues on the target repository**, each delivered as a
**gate-ready PR** the maintainer merges — while the repository stays stable for its consumers.
Not every issue is actionable by the loop: `bankai:handbook-question` items and design calls need
the maintainer's decision. Those get **briefed**, never guessed (§ 4).

> **This is a named run.** While it is active, `CON-25`'s third carve-out applies: the severity
> label may be applied, and `bankai:stage/building` released on an issue this run advances, without
> per-issue confirmation, provided every application is logged in the status board and the
> delegation **expires when the run ends**. Say explicitly, at the start, that a named run is
> beginning — and say when it ends.

---

## 0. Declared process change — read this before § 6

The old (bankai-core) version of this skill spent most of its bulk (§§ 4–5) on a CI plane: routing
an issue to `bankai:agent/naruto`/`yamamoto`/`kisuke`, then verifying the resulting wake actually
reached that builder — the `probe`/`build` job distinction, the comment-then-label
concurrency-group hazard (`BC-IS-#554`), the swallowed-wake and reply-only-mode failure shapes.

**Hatsu holds no CI plane at all** — no App, no workflow, no bot identity
(`claude/agents/kurapika.md` header) — the identical structural fact [`build`](../build/SKILL.md)'s
own § 1 callout already declares for the issue-shaped half of this same gap. This port's own
"advance an issue" step is therefore almost entirely a **pointer** to two already-landed skills,
not a restatement:

- **Turning a routable issue into a PR** is [`build`](../build/SKILL.md)'s whole job. Kurapika
  builds it himself, in the mode its § 3 confirms, under the same `CON-25` fourth-carve-out release
  authority its § 6 already carries.
- **Driving that PR to `CON-32` readiness** is [`drive`](../drive/SKILL.md)'s whole job —
  diagnosing the first blocking condition, addressing threads, or firing the wake channel.

**This skill's own job over both is the concurrency arbitration and the ordering** — which two
efforts are in flight, and which issue gets the next free slot — plus the batch-boundary layer (§
6) neither `build` nor `drive` owns. Nothing about turning an issue into a PR, or a PR into a Ready
one, is re-described here.

`nen backlog fetch|order`, `nen loop slots`, `nen pr staleness`, `nen wake fire|verify`, `nen tag
cut`, `nen fanout compute|record`, `nen changelog collate|completeness|fragment-required`, `nen
board build|render`, `nen stop` are this skill's own verbs, verified live in
`docs/ab/backlog-loop.md`. `build`/`drive`'s own verbs (`nen issue chain-position`, `nen pr ready`,
`nen gate derive`, …) are never re-invoked here — they are those skills' authority, not this one's.

## 1. Invocation

```
hatsu:backlog-loop <repo_code>
```

Split mechanically, not by hand:

```bash
nen parse backlog-loop --grammar "<repo>" --line "<the raw invocation>"
```

Verified live: a single-slot grammar with no bracketed clause — unlike
[`backlog-state`](../backlog-state/SKILL.md)'s own `<repo>[@<gate>]` template, there is nothing here
for `nen parse`'s documented bracket-swallowing gap (that port's own A/B doc § 3) to bite. `nen
parse backlog-loop --grammar "<repo>" --line "BC" --json` returns `slots: [{name:"repo",
value:"BC"}]`, `ok:true`; an empty line is refused with a corrected line ready to paste
(`docs/ab/backlog-loop.md` § 2.1).

Resolve the code against the registry, never from memory:

```bash
nen repo resolve <CODE> --repo <target repo checkout>
```

case-insensitive, an unresolved code is an error listing the registry's real codes (verified live,
`docs/ab/backlog-loop.md` § 2.2 — same verb every sibling port uses for this).

**Say the run has started.** A named skill run holds a bounded `CON-25` delegation (§ 3), and a
delegation nobody announced is a delegation nobody can end.

## 2. The cycle

Re-run on every fetch trigger: at start, whenever an issue reaches its gate (a PR merges or goes
Ready), and whenever the monitor (§ 7) sees a PR state change.

1. **Fetch** every open issue, fresh:
   ```bash
   export GH_TOKEN=$(gh auth token)
   nen backlog fetch --repo-slug <owner/name> --json
   ```
   **Never cached, never capped** — omit `--limit` entirely. Verified live against the real
   `zheref/bankai-core` backlog: `88` rows, `truncated: false`, paginated past GitHub's 100-row
   clamp without needing to be (`docs/ab/backlog-loop.md` § 2.3). A `truncated: true` fetch is never
   rendered as complete.
2. **Triage** anything with no `bankai:severity/*` label (§ 4).
3. **Order** the queue — § 5 covers exactly what `nen backlog order` computes and what stays this
   skill's own judgment on top of it.
4. **Advance** up to **two** efforts (§ 6 — almost entirely a pointer to `build`/`drive`).
5. **Check batch boundaries** — a severity batch fully merged fires a tag-cut + fan-out (§ 8).
6. **Report** the status board (§ 9).

## 3. Authority — what this run may and may not do

`CON-25`'s **third carve-out** — the run-scoped standing delegation the constitution names
explicitly for this skill ("while a named `backlog-loop` run is active
(`claude/skills/backlog-loop/`)"), not the fourth carve-out's per-skill table
[`build`](../build/SKILL.md) § 6 carries:

| | `backlog-loop` may |
|---|---|
| **Triage** | Propose and apply `bankai:severity/*` on an untriaged issue, logged |
| **Release** | Hand an issue to `build`, which applies `bankai:stage/building` under its own carried delegation |

| | `backlog-loop` may **not** |
|---|---|
| **Apply a G1 mode label** | Never, inside a run or outside it |
| **Merge** | Not `main`, not a chore/integration branch, not its own PR anywhere |
| **Vote** | No review, ever — and never `request_changes` |
| **Cut a tag or publish a release** | § 8 stops at the maintainer's `G3` for the official release; the tag itself is prepared, never merged past a refusal |
| **Fire or verify a wake itself** | That authority lives entirely in `drive` (§ 6) |

> **`CON-46(c-i)`'s stale-chore-merge carve-out is retired here, not restated.** The old
> (bankai-core) skill inherited the one merge a local persona may perform — a stale CI author's
> Ready sub-PR onto an `integration/<chore>` branch, once that author demonstrably stops responding.
> It does not apply to this port: Hatsu holds no CI plane at all (§ 0), so there is no CI-authored
> chore sub-PR that can ever go stale in the sense `CON-46(c-i)` requires. [`drive`](../drive/SKILL.md)
> states the identical rule for the same reason — never merges `main`, and not a chore branch either.

**The delegation expires when the run ends. Say when it ends.**

## 4. Triage & briefing

**Untriaged (no `bankai:severity/*`).** Propose a severity with one line of reasoning, then apply
it — logged under the carve-out above:

```bash
nen label apply <CODE>-IS-#<N> --label bankai:severity/<level> --repo-slug <owner/name> \
  --reason "<why, for the ledger>" --run
```

Never exercised live against the real, frozen `zheref/bankai-core` (the shared brief's read-only
rule) — contract-verified only, `docs/ab/backlog-loop.md` § 3. `bankai-core`'s own taxonomy carries
four severities (`critical`, `high`, `medium`, `low` — verified live off `schemas/labels.json`); a
different target repository's own taxonomy is read the same way, never hard-coded.

**`bankai:handbook-question` and design calls.** These need a **decision**, not a fix. Analyse
each, then **brief** the maintainer through `nen stop --gate G5` (§ 9) with a `DECIDE` ask: what is
being asked, the options, the recommendation and why. **Never guess a policy call and never close
one unanswered** — an unanswered question is a briefed row on the board, not a resolved one.

**Routing an issue to a mode is `build`'s own § 3 question, not this skill's.** This skill only
decides *when* an issue's turn comes up (§ 5); *what mode Kurapika builds it in* is answered once,
by `build`, the moment the issue is handed to it.

## 5. Priority order — what `nen backlog order` computes, and what stays judgment on top of it

Reshape `nen backlog fetch --json`'s rows to `{id, severity, createdAt, number}` (severity read off
the `bankai:severity/*` label; an untriaged row's `severity` is any string not in
`--severity-order`'s list, so it sorts last rather than erroring — verified live,
`docs/ab/backlog-loop.md` § 2.4), then:

```bash
nen backlog order --rows-from <path> --severity-order critical,high,medium,low \
  [--blocks <id,id>] [--affects-consumers <id,id>]
```

Implements backlog-loop's own severity-first order exactly: severity primary, then **blocks
another issue**, then **affects consumer behaviour/DX**, then **age** (oldest first), then issue
number. Verified live against the real backlog: the seven real open `high` rows sort strictly
oldest-first ahead of every `medium`/`low`/untriaged row (`docs/ab/backlog-loop.md` § 2.4).

> **`--blocks`/`--affects-consumers` take the row's own `id` string (`BC-IS-#928`), not the bare
> issue number `--help`'s own `<n,n>` notation reads as** — verified live: passing the bare numbers
> `928,929` is silently accepted, produces no error, and simply never marks either row
> `blocksOther: true`; passing the `id` strings `BC-IS-#928,BC-IS-#929` correctly promotes both to
> the front of their severity band, tied on age between themselves (`docs/ab/backlog-loop.md`
> § 2.4). Not a defect — the verb reads exactly what `--rows-from`'s own `id` field carries — but a
> caller who follows the `--help` text's `<n,n>` literally gets a silent no-op, not a refusal. **This
> skill always builds `--blocks`/`--affects-consumers` from the same `id` strings the row set
> itself carries.**

**What `nen backlog order` does NOT compute — stays this skill's own judgment, layered on top of
the static ranking it returns:**

- **`critical` pre-empts everything, including an issue already in flight.** The severity-order list
  already ranks a `critical` row first in the static sort; what the verb cannot see is a **live**
  slot already occupied by a lower-severity effort when a new `critical` issue arrives mid-run. That
  pause-and-substitute decision — which effort is paused, and why — is this skill's own call,
  recorded in the board's `needs` cell. **No tag-cut, fan-out or release preparation happens while
  any `critical` is open**, at any batch boundary (§ 8).
- **`low` never starts while anything above it is still *actionable*** (not yet Ready and handed to
  the maintainer) — same shared "the queue never idles on the maintainer" rule the old skill named
  (`BC-IS-#545`). Once everything above `low` is merged or Ready-and-waiting, `low` proceeds; the
  merge-order discipline still holds at the other end (a `low` PR is delivered Ready, but the
  maintainer merges the higher-severity PRs above it first).
- **Seize the wait.** Whenever the only open work is PRs already Ready-and-waiting, immediately
  re-fetch (§ 2 step 1): new issues, issues whose blockers just merged, and briefed items the
  maintainer answered. The run ends only on a genuinely empty actionable queue (§ 11), never on
  "waiting for a gate."

This is exactly the composition [`backlog-state`](../backlog-state/SKILL.md)'s own § 11 already
established for the identical verb ("`nen backlog order` does not know about status bands ...
bucket rows first, then run `nen backlog order` inside each band") — here the "bands" are the
critical-preemption/low-deferral rule rather than gate colour, but the shape of the composition is
the same one that port already proved.

## 6. Advancing an effort — almost entirely a pointer

**Work at most TWO efforts at a time. Never three.** Mechanized, not eyeballed:

```bash
nen loop slots --efforts efforts.json --local-cap 2 --json
```

Every effort here is `"plane":"local"` — Hatsu holds no `ci` plane, so a slot never frees on "the PR
opened"; it frees only once a PR is both `"ready":true` **and** `"prompted":true` — the maintainer
has actually been shown the ask (§ 9). Verified live, this port's own run: two efforts with neither
ready nor prompted report `local: 2/2 occupied, 0 free` at exit `1`; flip one to
`ready:true, prompted:true` and it frees, `1/2 occupied` at exit `0`
(`docs/ab/backlog-loop.md` § 2.5).

> **Always pass `--local-cap 2` explicitly.** Verified live, reconfirming
> [`build`](../build/SKILL.md)'s own already-filed finding on the identical verb (that port's
> `docs/ab/build.md` § 2.10, its `SKILL.md` § 10 finding 4): the default local cap is **`7`**, not
> `2`. Omitting the flag would silently triple this skill's own hard concurrency limit.

**When a slot is free**, take the next row `nen backlog order` returned (respecting § 5's
critical-preemption/low-deferral layer) and hand it to [`build`](../build/SKILL.md)
(`hatsu:build <CODE>#<N>`) — everything from "is this an idea, an epic, or a routable child" through
"here is a `CON-32`-Ready PR or a G5 stop" is that skill's own engine, not restated here. Once a PR
exists, [`drive`](../drive/SKILL.md) (`hatsu:drive <CODE>#<N> to <G2|G4>`) takes it the rest of the
way — diagnosing the first blocking condition, addressing threads, computing staleness, deciding
readiness.

**`nen pr staleness`** — the escalation-ladder gate `drive` § 6 already owns — is reconfirmed here
because a backlog-wide loop is exactly the caller that keeps the wake-attempt log `drive`'s own
§ 9 asks for, across many efforts at once rather than one. Verified live, both cases:
`--wakes-from` with 2 no-commit wakes and 90 idle minutes reports `stale` / `merge not permitted`
without `--ready`, and `merge PERMITTED (stale + Ready)` with it — byte-identical to `drive`'s own
proof (`docs/ab/drive.md` § 2.7; re-run here, `docs/ab/backlog-loop.md` § 2.6). This skill reads the
same two conjuncts `drive` reads and never the `mergePermitted` field, for the identical reason:
**this run carries no merge delegation, under any circumstance.**

### The residual wake case — declared, not dropped

The old skill fired `bankai:wake/iterate` as the **default** unblock channel for every routed
issue, because every routed issue's PR was, by construction, CI-authored. Since `build` (this
port's issue-shaped engine) never routes to a CI agent — Hatsu holds none — the PRs this loop
drives are, by default, **Kurapika-authored**, and [`drive`](../drive/SKILL.md) § 5 already
addresses those directly (reply on thread, push the fix, re-request review).

**The wake channel is not dead — it is narrower, and it lives in `drive`, not here.**
`backlog-loop` is written to drive whichever repository's backlog it is pointed at (§ 1), not only
`bankai-core`'s, and a PR authored by a genuinely external automated participant — a
`<!-- bankai agent=… run=… -->` stamp, or an assigned GitHub-hosted coding-agent PR — is exactly the
shape [`drive`](../drive/SKILL.md) § 5 already names and fires `nen wake fire`/`nen wake verify`
for. **This skill itself never calls either verb.** Its own job is only to recognise, from the PR
shape `drive` reports back, that the effort in its queue is CI-authored rather than
Kurapika-authored, and to keep counting it against the same two-slot cap while `drive` runs the
wake ladder — not to re-fire a wake of its own alongside it. This is the declared, narrower shape
the old skill's wake machinery takes here: relocated to where the authorship distinction is
actually made, not silently dropped.

**Never two efforts touching the same file.** No verb governs this; sequence them and say so — this
skill's own judgment, unchanged from the old skill.

## 7. The monitor

Between cycles, keep watching: PR check transitions, new reviews, new comments, merges, and new or
relabelled issues. A merge or a state change is a fetch trigger — go back to § 2. There is no
scheduled sweep behind this run — no App, no sweeper (same structural fact `build`/`drive` both
state) — polling happens in-shell, in-session, exactly as `drive` § 3 already does per PR.

## 8. Tag-cut, fan-out and release

| Trigger | Action |
| --- | --- |
| All `critical` **merged** | Tag-cut + fan-out. Nothing releases while a `critical` is open. |
| All `high` **merged**, changes unreleased | Tag-cut + fan-out; do **not** pause `medium` work. |
| All `medium` **merged**, no `critical`/`high` open | Tag-cut + fan-out + prepare the official release with developer-facing notes — then **stop at G3**. |
| `low` merged | Tag-cut, **hold** the fan-out. |

> **Before ANY cut, check for a live chore.** No tag, no release and no fan-out is cut while an
> `integration/<chore>` branch still carries unmerged scope. Detect it **mechanically**: the
> chore's issue is open AND its `integration/<chore>` branch exists (a plain `gh issue view`/`git
> branch -r` check — no `nen` verb owns this composite fact; residue, § 12). **Not live-exercisable
> today**: `bankai-core`'s own taxonomy carries no `chore` label and no open `bankai:epic` issue at
> all (`build`'s own A/B, `docs/ab/build.md` § 2.7/§ 2.9) — this branch is contract-verified against
> the check's own shape, not confirmed against a real live chore.

**Changelog completeness, mechanized:**

```bash
nen changelog completeness --range <vPrev>..<vNew> --changelog CHANGELOG.md --owner-repo <owner/name> [--fragment-dir changelog.d]
```

Verified live against the real, historical `zheref/bankai-core` range `v0.11.2..v0.11.3`:
`every PR merged in v0.11.2..v0.11.3 has a CHANGELOG entry or fragment.` (`docs/ab/backlog-loop.md`
§ 2.7) — genuinely read-only, no GitHub write, no local write.

**Whether a specific PR's diff owes a fragment at all:**

```bash
nen changelog fragment-required --spec-paths "<policy paths>" --fragment-dir changelog.d \
  --files-from <path> --head-changelog CHANGELOG.md
```

Verified live against the real `zheref/bankai-core#940`'s changed-file set: reports `release-move`
— *"changelog.d/ fragment(s) collated and deleted, Unreleased already empty, new dated section
landed -- satisfied natively"* (`docs/ab/backlog-loop.md` § 2.8).

**Collating fragments into a new dated section, before the release PR:**

```bash
nen changelog collate --version <vX.Y.Z> --theme "<text>" --changelog CHANGELOG.md --fragment-dir changelog.d [--write]
```

**Without `--write`, this is genuinely read-only** — reports the rendered result untouched.
Verified live on a scratch copy of `bankai-core`'s real `CHANGELOG.md` (never the real checkout):
the file's own hash is identical before and after the dry-run call, and the synthetic fragment file
is still present afterward (`docs/ab/backlog-loop.md` § 2.9). **`--write` is never exercised against
the real, frozen `zheref/bankai-core`** — it would delete fragments and rewrite the file, exactly
the write the shared brief forbids — contract-inspected only.

**Computing the fan-out set, genuinely read-only:**

```bash
nen fanout compute --range <vPrev>..<vNew> [--workflows-dir .github/workflows]
```

Verified live against the real range `v0.11.2..v0.11.3`: three real consumers (`KroApple`,
`KroAndroid`, `bankai-scaffold`) each reported `affected` with the matched workflow basenames and a
stated basis (`docs/ab/backlog-loop.md` § 2.10) — no consumer came back a silent, unstated `n/a`.

**Recording it for audit is a LOCAL write, never a GitHub one** — safe to exercise live:

```bash
nen fanout record --range <vPrev>..<vNew> [--workflows-dir <dir>] --ledger <scratch path>
```

Verified live, pointed at a scratch ledger path outside any tracked checkout: appended three JSON
lines, one per consumer, and made **no GitHub call of any kind** (`docs/ab/backlog-loop.md` § 2.11).
This verb never opens a repin PR itself — it only records the decision a caller then acts on; opening
each consumer's repin PR is a plain `gh pr create` per row, no `nen` verb owns that act (residue,
§ 12).

**The cut itself:**

```bash
nen tag cut --repo <path> --name <vX.Y.Z> --at <sha> [--message <text>] [--trunk main] [--push]
```

Mutating — creates a real git tag object even without `--push` (locally). **Never exercised against
the real `zheref/bankai-core`, in any form**, per the shared brief's boundary: contract-inspected
only (`docs/ab/backlog-loop.md` § 3), same precedent [`pr-state`](../pr-state/SKILL.md) and
[`backlog-state`](../backlog-state/SKILL.md)'s own A/B docs already set (neither dry-ran a mutating
verb against `zheref/hatsu` either, since none was genuinely needed to write the skill). Honour an
active `RELEASE_HOLD`. Land the changelog collation as its own release PR the maintainer merges,
**then** cut — `--at` is required and never defaulted to `HEAD`, and the verb itself refuses a
name that already exists or an `--at` that is not an ancestor of `origin/--trunk`. **If the tag
capability is refused, HALT and hand the maintainer the exact command.**

**The official release is `G3` — the maintainer's alone.** Prepare it; never publish it.

**Fan-out, closing the loop.** Every affected consumer from `nen fanout compute`'s own row gets a
repin PR opened against it (plain `gh pr create`, residue), every unaffected consumer is the
verb's own explicit `n/a` row with its stated basis, and every `bankai:handbook-question` fan-out
issue this cut covers is closed with the reference.

## 9. The status board

Report every cycle, and whenever the maintainer asks — assembled and rendered, never
hand-formatted:

```bash
nen board build --repo-slug <owner/name> --rows-from <path>   # rows: {id,title,refs,gate,status,needs}
nen board render --board-from <path>
```

Same machinery [`backlog-state`](../backlog-state/SKILL.md) and [`drive`](../drive/SKILL.md) both
already use — this port adds no new columns and reuses `nen gate derive`/`nen color status` the
same way those ports document. Verified live end to end, including a finding worth stating plainly:

> **`refs` must be an array of pre-formatted `nen ref format` strings, not a joined string.**
> Verified live: passing `refs` as a plain string crashes `board build` outright —
> `row.refs.join is not a function` — because the render layer calls `.join(", ")` on it. Passing
> an **array** (`["BC-IS-#937","BC-PR-#940"]`, or a single-element array from `nen ref format`)
> builds and renders correctly (`docs/ab/backlog-loop.md` § 2.12). Never hand-join a `refs` cell
> into one string before calling `board build`.

`nen stop --who Kurapika --gate <Gn> [--notified] board.md` renders the gate banner. Verified live,
a real `G5` example (an untriaged issue awaiting a severity confirmation) rendered the full banner
and padded table unchanged (`docs/ab/backlog-loop.md` § 2.13). **Every place this run reaches a
gate is a gate event** — the banner is the "I need you" signal, never printed for a plain progress
report.

Also state, every cycle: **briefed items awaiting a decision**, **blocked items and what blocks
them**, and **every label applied under the run-scoped delegation** (issue, label, time).

**When the maintainer is needed, do not stop.** Notify, record it on the board, and continue on
other efforts. Only a genuinely empty actionable queue ends a cycle (§ 11).

## 10. Conflict discipline & documentation

- **One worktree per effort**, per `build`/`drive`'s own conventions.
- **Cascade `main` whenever it moves** — `nen pr cascade-main --repo <path> [--trunk main]`, the
  same verb `drive` § 5 already owns; this skill never calls it directly, it delegates to `drive`.
- **Never two efforts touching the same file** (§ 6).
- **Write run state to `docs/Loop/<run-id>/`** — the board, decisions, and every logged label
  application — so a fresh session resumes without re-deriving it, and **never trusts it over a
  fresh fetch** (§ 2).

## 11. Ending the run

The run ends when the actionable queue is empty — every issue either delivered as a merged PR, or
briefed and awaiting a maintainer decision. **Say the run has ended**, so the `CON-25` delegation
(§ 3) lapses, and give a final board plus what remains on the maintainer's plate.

## 12. Findings against the binary (report, never route around)

1. **`nen backlog order`'s `--blocks`/`--affects-consumers` silently no-op on the bare issue number
   `--help`'s own `<n,n>` notation suggests, rather than refusing.** Verified live (§ 5): the flag
   reads the row's own `id` field (`BC-IS-#928`), and a caller who passes `928` instead gets no
   error, no `blocksOther: true`, and no different ordering — a silent miss, not a loud one.
2. **`nen board build` crashes on a `refs` value that is not an array**, with no type-checked
   refusal — `row.refs.join is not a function` (§ 9). The documented `BoardRow` shape
   (`{id,title,refs,gate,status,needs}`) does not itself say `refs` must be a pre-built array of
   `nen ref format` outputs.
3. **(Reconfirmed, not newly filed)** `nen loop slots`'s local-plane default cap is `7`, not `2` —
   first filed against [`build`](../build/SKILL.md) (`docs/ab/build.md` § 2.10); reproduced
   identically here (§ 6) because this skill calls the same verb independently.
4. **(Not re-exercised, cited)** `nen pr fetch`/`nen pr next-blocker` are broken against every real
   `bankai-core` PR tried — filed against [`drive`](../drive/SKILL.md) (`docs/ab/drive.md` § 4),
   whose engine this skill delegates all PR-shaped work to. `backlog-loop` never calls either verb
   itself, so the finding is cited rather than re-reproduced.

## 13. Residue — what stays this skill's own judgment, or has no verb yet

- **Judgment kept, per the shared brief's boundary list**: critical-preemption/low-deferral/
  seize-the-wait (§ 5), the severity-proposal reasoning (§ 4), the G5 diagnosis on a stuck
  `build`/`drive` escalation (delegated but reported here), and the closing "what shape collapses"
  narration on the board.
- **The live-chore detection** (§ 8) — "the chore's issue is open AND its `integration/<chore>`
  branch exists" — is a plain `gh`/`git` composite check; no `nen` verb owns this fact.
- **Opening each fan-out consumer's repin PR** (§ 8) is a plain `gh pr create` per row; `nen fanout
  record` only logs the decision, it never opens anything itself.
- **Keeping exactly one `bankai:stage/*` label on an object at a time** (`CON-9`) is `build`'s own
  residue, inherited unchanged — `nen label apply` applies and logs exactly the one label it is
  given.
- **`nen wake fire`/`nen wake verify`'s full escalation ladder** lives entirely in
  [`drive`](../drive/SKILL.md) § 5–6, cited rather than restated (§ 6's "residual wake case").
- Verdict parity between `nen pr ready` and `scripts/pr_ready_gate.sh` was already proven across
  the live estate by `nen`'s shadow window (`docs/evidence/shadow-window-p1.md` in `zheref/nen`),
  and re-confirmed for this repository by [`pr-state`](../pr-state/SKILL.md)'s own A/B
  (`docs/ab/pr-state.md`) — this skill never calls `nen pr ready` itself (that is `build`/`drive`'s
  job) and does not re-prove it a third time.

## 14. Hard limits

- **Never merges `main`.** `G2`, `G3`, `G4` are the maintainer's.
- **Never merges its own PR**, anywhere.
- **Never self-reviews, never impersonates a reviewer, never casts a `request_changes` review** —
  binding even when the finding is real and even when it looks like the only way to move a PR.
  `drive`'s wake channel exists precisely so no vote is ever needed.
- **Never applies a G1 mode label** — human-only, inside a run or outside it.
- **Never fires or verifies a wake itself** — that authority and its escalation ladder live
  entirely in `drive` (§ 6).
- **Never cuts a tag or publishes a release against the real target repository during this port's
  own verification** — `nen tag cut` and `--write` on `nen changelog collate` are contract-inspected
  only against `zheref/bankai-core` (§ 8); in a live run against a repository this skill is actually
  authorized to write to, the cut still never auto-pushes without `--push`, and the release itself
  stays `G3` — the maintainer's alone.
- **Never exceeds two concurrently-driven efforts** (`nen loop slots --local-cap 2`, § 6), and never
  lets two touch one file.
- **The run-scoped delegation expires when the run ends** (§ 3). Say when it ends.
