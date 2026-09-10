# A/B evidence — `hanten` (new skill, wave 3)

`claude/skills/hanten/SKILL.md`: the adversarial pre-PR review — classify the change set by scope, raise
one reviewer per scope on the tier the model matrix names, collect findings in one fixed shape, and settle
every one by fixing it or pushing back with a cited reason. A scope with no reviewer is a **gap**; an
unsettled finding is a **G5**.

**A new skill, so there is no "old mechanics" column.** And it is the one skill in this wave whose central
mechanism is **not a nen verb and is not expected to become one** — raising a delegate is the surface's
tool, the same boundary `docs/ab/ren.md` records for the turn loop. So this record does something a
little different from its siblings: it establishes what nen *does* answer here (very little, and
deliberately), and then documents three facts about **this repository's own state** that decide whether
hanten can honestly run at all.

Run: 2026-09-10 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
`nen parse`, `nen gate derive` and `nen stop --template` are pure — no repository was written, no
subagent was raised, and no reviewer was run. The filesystem transcripts in § 2.2 are `ls` and `grep`
against this worktree.

Nothing below is redacted; both repositories are public.

---

## 1. The skill

| Step | Owned by | State at `v0.3.0` |
|---|---|---|
| The invocation | `nen parse hanten --grammar "for [<scope:…>]"` | **verb** (§ 2.1) |
| Classify the change set by scope | — | **no verb** → residue (§ 2.3) |
| Where the scope map is declared | `nen/workflow.json → review.scopes` | **no such key** → gap (§ 4.2) |
| Resolve the reviewer's model | `nen/workflow.json → models` | **read as data** (§ 2.4, § 4.1) |
| Check the reviewer exists | — | filesystem (§ 2.2) |
| Raise the reviewer | the harness's Agent tool | **boundary, never a verb** (§ 4.4) |
| The findings record | — | this skill's own document, `hatsu.hanten.findings/v0.1` |
| The G5 banner and table | `nen stop --template` / `nen stop --who --gate` | **verb** (§ 2.5) |

**Eight rows; two are verbs, one is a boundary, and the rest are the skill's own.** That ratio is the
honest shape of a review step, and § 4.4 argues it is the right one rather than a backlog.

---

## 2. Verbs and facts, exercised live

### 2.1 — `nen parse hanten`: the scope clause resolves, and refuses a near-miss

```
$ nen parse hanten --grammar "for [<scope:ui|security|architecture|performance|release|all>]" \
    --line "for security"
scope: security
exit=0
```

```
$ nen parse hanten --grammar "for [<scope:ui|security|architecture|performance|release|all>]" \
    --line "for styling"
nen parse: <scope> is one of ui | security | architecture | performance | release | all
(case-insensitively), and 'styling' is none of them. It is resolved, never guessed at: the closest
match is not the answer.

Corrected line:
  hanten for <scope: ui | security | architecture | performance | release | all>
exit=2
```

**The enumerated-slot form does real work here.** `styling` is one letter from nothing and three from
`ui`, and the engine's own sentence — *"the closest match is not the answer"* — is exactly the discipline
a scope needs: routing a security-bearing diff to a reviewer picked by string proximity is worse than
refusing the line.

### 2.2 — Two of the five reviewers had no definition, and the roster said so

> **Superseded 2026-09-10 — the transcript below is kept as run, and the fact it records has since
> changed.** `claude/agents/feitan.md` and `claude/agents/chrollo.md` **now exist**: both definitions
> landed at `v0.5.0` on the ruling of 2026-09-09, and `docs/ROSTER.md` has moved both rows up into
> § *The independents*. **All five of `hanten` § 2's reviewer personas are defined today, and no scope
> in that table is a gap.** The transcript stands as evidence of the state this A/B was run against;
> it is not evidence about the plugin as it ships now.
>
> Three consequences, recorded here so the rest of this file is read correctly:
>
> - **`hanten` § 3 has been rewritten** to state the gap *mechanism* — a scope whose persona has no
>   definition in `claude/agents/` is reported as a gap and never improvised past — without asserting
>   which personas are missing, because that is a fact about a version.
> - **§ 4.3 below has lapsed**, exactly as its own last line said it would.
> - **§ 4.1's aside naming Feitan and Chrollo as "the personas with no definition to pin a model in"
>   is superseded**: both pin `model: opus` in their own frontmatter. **The question § 4.1 asks is
>   untouched and still open** — it was never about those two, and the reconciliation it records
>   (a persona's own pin wins; the role-derived alias is for a persona that pins none) is unchanged.

```
$ ls claude/agents/
gon.md
hisoka.md
kurapika.md
phinks.md
uvogin.md

$ ls claude/agents/feitan.md claude/agents/chrollo.md
ls: claude/agents/chrollo.md: No such file or directory
ls: claude/agents/feitan.md: No such file or directory
exit=1
```

`docs/ROSTER.md` § 4 activates both — Feitan for *"security, and security only"*, Chrollo for
*"architecture and handbook conformance"*, each named as **the reviewer `hanten` routes to** — and states
the constraint verbatim: *"**Their definitions land at `v0.5.0`.** Until a definition exists in
`claude/agents/`, **neither may be acted as** — an activation is a decision about standing, not a licence
to improvise the agent."*

**So at the moment this A/B was run, two of the skill's five scopes had no reviewer**, which is why
§ 3 of the skill exists rather than being a hypothetical branch. See § 4.3 — and the note at the head
of this section, which records that both definitions have since landed.

The model pins on the three that do exist, read off their own frontmatter:

```
$ for a in hisoka uvogin phinks gon kurapika; do printf '%-9s ' "$a"; \
    grep -m1 '^model:' claude/agents/$a.md || echo "(no model: key)"; done
hisoka    model: sonnet
uvogin    model: sonnet
phinks    model: opus
gon       model: opus
kurapika  (no model: key)
```

Which matches `docs/ROSTER.md` § 3 exactly, and collides with the role map — § 4.1.

### 2.3 — `nen gate derive` answers a different question, and answers it well

The nearest verb to "classify this change set":

```
$ nen gate derive --policy-paths "nen/,schemas/,claude/agents/" \
    --process-paths ".github/workflows/,claude/skills/,scripts/,docs/" \
    --files "claude/skills/hanten/SKILL.md,docs/ab/hanten.md"
G4
G4: the diff touches the process surface (claude/skills/, docs/); in a repository whose product is its
process, that is a policy change.
This is the diff's half of the derivation only. A pull request that is not ready has NO GATE -- it is
in progress and owned by its author -- so compose this with a readiness verdict before putting a row
in anyone's queue.
exit=0
```

**Correct, useful, and not the question.** `gate derive` maps paths to a **human gate** — who has to
approve this — which is orthogonal to *what kind of scrutiny does this need*. The same two files are `G4`
and raise no security scope, no performance scope and no UI scope; a one-line change to an auth token's
storage would be `G2` and raise the security scope loudly. Composing the two would be a category error.

So hanten's § 2 classification is `git diff --name-only <base>...HEAD` read against the skill's own
default path map, in the open, reported as by-hand. See § 4.2 for where that map should eventually live.

### 2.4 — The model matrix, read as data

`nen/workflow.json → models`, at this pin, read by the skill itself (no loader, no `jq` — the
`no_improvised_fallback`/`no_jq` posture `nen/contract.json` states):

```json
"claude": { "frontier": "fable", "deep": "opus", "fast": "sonnet", "economy": "haiku" },
"roles":  { "reviewer": "deep", "worker": "fast", "measurer": "fast", "orchestrator": "frontier" }
```

`models.roles.reviewer` → `deep` → `models.claude.deep` → **`opus`**. Against § 2.2's frontmatter, which
gives Hisoka and Uvogin **`sonnet`** — the `fast` tier. Both readings are recorded as true in the same
document (`docs/ROSTER.md` § 3). § 4.1 is what to do about it.

`nen schema check` does not validate `nen/workflow.json` at this pin (`docs/ab/rikugan.md` § 2.4), so
these values are read as data and the defaults are stated whenever they apply.

### 2.5 — `nen stop --template`, and what it does not do

```
$ nen stop --template
| Effort  | Open issues & PRs | Status (gate)   | Thought flow | Session / lane |
| ------- | ----------------- | --------------- | ------------ | -------------- |
| <title> | <link>            | <status (gate)> | <one line>   | <session>      |
exit=0
```

`nen stop --help`, verified at this pin: *"Rungs 2-3 of the escalation ladder (an OS notification, an
audible cue) are **NOT** fired by this command … this command renders rung 4 (the banner and table) and
states rung 1's status, which is the caller's to have fired."* The full transcript is
`docs/ab/gyo.md` § 2.4; it is the same verb serving the same purpose in both skills, and the unsettled
finding of hanten § 7 renders through it identically.

---

## 3. Residue

1. **Raising a subagent** — a **boundary**, not a gap (§ 4.4). § 4 of the skill is the harness's Agent
   tool; § 9 is what an adapter on another surface must provide.
2. **Classifying a change set by scope** — no verb; `nen gate derive` answers the gate question instead
   (§ 2.3). Run as `git diff --name-only <base>...HEAD` against the skill's default map, reported as
   by-hand.
3. **`nen/workflow.json → review.scopes`** — no such key at `nen.workflow/v0.1` (§ 4.2). The map is the
   skill's default until one exists.
4. **`nen/workflow.json` read as data** — no schema row at `v0.3.0`. `models` and `reports.dir` are read
   directly, with `Reports` stated as the default when it applied.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — The role→tier map and the persona frontmatter give different models for the same reviewer

§ 2.2 and § 2.4 together. `docs/ROSTER.md` § 3 states both of these as rules, one paragraph apart:

- *"Model choice is by **tier**, from `nen/workflow.json → models`"* — and `roles.reviewer` is `deep`,
  which on Claude is **`opus`**.
- *"The pins are frontmatter in the definitions: … **Hisoka** `model: sonnet` / `effort: high`;
  **Uvogin** `model: sonnet` / `effort: medium`"* — the **`fast`** tier.

For Phinks the two agree (`opus`, `deep`). **For Hisoka and Uvogin they do not**, and the disagreement is
not academic: the harness's Agent-tool `model` parameter **takes precedence over the definition's
frontmatter**, so a caller that dutifully resolves `roles.reviewer → deep → opus` and passes it would
**silently overrule** the pin the maintainer recorded in Hisoka's own file — while believing it was
reading policy from the file.

**The skill's reconciliation, disclosed in its § 4:** the persona's own pin wins where it exists, and
hanten then passes **no** `model` at all; the role-derived alias is used only for a persona whose
definition pins none — which today is exactly Feitan and Chrollo, who have no definition to pin one in.
Either way the alias that actually ran goes in the title, and neither path can reach the frontier tier.

**This is a reading, not a ruling, and the ruling is the maintainer's.** Two shapes would settle it in the
file rather than in prose: either `roles` becomes an explicit *default for a persona with no pin* (one
sentence in `nen/workflow.json`'s `$comment` and in `ROSTER.md` § 3), or the pins move out of the
frontmatter and `models` grows a `personas` block so there is one place to read. **Worth deciding before
a fourth reviewer is added**, because every new persona doubles the number of places the answer lives.

Ranked: this is the highest-value item in this record — it is cheap to fix, it is a policy question rather
than an implementation one, and getting it wrong silently overrides a recorded decision.

### 4.2 — `nen/workflow.json` has no `review` block, so the path→scope map has nowhere to live

Hanten's § 2 table maps directories to review scopes — which paths are *security-bearing*, which are
*performance-sensitive*, which are *release-adjacent*. **That is a per-repository fact** (an iOS app's
keychain wrapper, a PWA's service worker, an Android app's `ProGuard` rules are in wildly different
places), and `nen.workflow/v0.1` has nowhere to put it: the schema's keys are `branch`, `iteration`,
`tests`, `coverage`, `launch`, `reports`, `notifications`, `commits`, `monitor`, `models`.

So the map is the **skill's default**, stated out loud every run and corrected by hand where a
repository's layout defeats it. That works, and it is worse than a declaration in exactly the way
`docs/WORKFLOW.md` § 1 predicts: *"a wrong `workflow.json` produces a correct command run at the wrong
moment, which is silent"* — and a scope map that is silently wrong routes a security-bearing diff to
nobody.

**The shape that would fix it**, proposed rather than invented here:

```json
"review": { "scopes": { "security": ["Sources/Auth/", "**/Keychain*"],
                        "performance": ["Sources/Feed/"], "release": ["fastlane/", "CHANGELOG.md"] } }
```

with the built-in map as the default when the key is absent — the same *declare-or-default* posture every
other key in that file has. Note that a glob written there inherits `docs/ab/kotoamatsukami.md` § 4.1's
question: **which dialect**. Answer it once, for both keys.

This is a `0.4.0`-or-later schema item, not a `0.3.0` residue, and it is smaller than it looks because
nothing executes it — hanten reads it, exactly as it reads `models`.

### 4.3 — Two of five scopes had no reviewer when this A/B ran, and that was the load-bearing case — **LAPSED**

§ 2.2. `ls claude/agents/` returns five files and neither `feitan.md` nor `chrollo.md` is among them,
while `docs/ROSTER.md` § 4 routes **security** and **architecture** to exactly those two and forbids
acting as either until a definition exists.

**This is not a defect in anything** — the roster planned it this way, and the two definitions land with
this wave or the next. It is recorded because it changes what hanten's § 3 *is*: not a defensive branch
for an unlikely future, but **the path a large fraction of real runs will take on the day this ships**.
Any change touching auth, secrets, network or storage gets a `security` gap today.

Two consequences worth stating:

- **The gap must read as loudly as a finding.** A scope reported as "not reviewed" in a footnote is a
  scope nobody notices was skipped. It goes in the record with `reviewed: false` and a reason, in the PR
  body, and in the turn report.
- **The temptation is to improvise.** Reading a security diff "as Feitan would" is available, feels
  helpful, and is precisely what the roster's ruling forbids — and it produces findings with no citable
  rule behind them, which `hisoka.md` and `phinks.md` both already refuse for their own scopes. The
  honest output names the paths that raised the scope and says it was not reviewed.

**Re-check this record's § 2.2 when the pin on the roster moves.** The day both files exist, hanten's
gap path becomes the rare branch it was designed to be, and this finding lapses.

> **LAPSED 2026-09-10, on its own terms.** Both files exist —
> [`claude/agents/feitan.md`](../../claude/agents/feitan.md) and
> [`claude/agents/chrollo.md`](../../claude/agents/chrollo.md), landed at `v0.5.0` — so every scope in
> `hanten` § 2 routes to a defined persona and the gap path is the rare branch it was designed to be.
> The two consequences above are **not** lapsed and were folded into the skill: the gap still reads as
> loudly as a finding, and improvising a review for a persona with no definition is still forbidden.
> What lapsed is only the claim that a large fraction of real runs would take that path.

### 4.4 — Not a finding: raising a delegate is a boundary, and nen is right not to own it

Every other skill in this wave has a residue list of verbs it wishes existed. Hanten's central mechanism
has none, and should not.

`docs/ab/ren.md` § 2.2 established the principle live: nen's two loop primitives refuse to drive a
conversation — `nen watch until` spawns **one** program with no shell and classifies it read-only first,
and `nen parse izanami` refuses a whole run when any command classifies as mutating. Re-confirmed here at
this pin for the verbs this wave's skills call:

```
$ nen parse izanami "nen shu ui-test until it is green"
  [mutating] nen shu ui-test
nen: at least one command does not classify as read-only -- the WHOLE run is refused.
exit=1

$ nen parse izanami "nen shu coverage until every touched file clears 80"
  [mutating] nen shu coverage
exit=1
```

**nen deliberately owns operations rather than conversations**, and a reviewer is a conversation: it
reads, judges against rules, and returns prose-shaped structure. A verb that raised one would be nen
taking a position on what a model is, which is the one thing a declaration-driven binary is built not to
do.

What the skill owes in exchange is § 9 — a written contract for what an adapter must provide (isolation,
a tier, the finding shape, the title) — so that the boundary is a *specified* boundary rather than "it
depends on the surface". Recorded as the counter-example to §§ 4.1–4.3: not every gap is a backlog item,
and calling this one would produce a worse system.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| `nen/workflow.json` unvalidated — `models` and `reports.dir` read blind | `nen schema check --repo .` | `1` overall, that row `ok` |

```
  ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}' off 'main', checks: lint
```

**`models` is an OPEN map and nen validates nothing inside it** — the near-miss rule that guards every
other block is deliberately not applied there — so the matrix stays this skill's own read. That is a read,
not a residue: what the row buys is that a malformed `reports` or `coverage` block is caught by a verb
before a reviewer is raised against it.
