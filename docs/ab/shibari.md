# A/B evidence — `shibari` (new skill, wave 3)

`claude/skills/shibari/SKILL.md`: compose the pull-request body — why, how, what this changes for
the consumer, how to verify, a mermaid diagram where a flow changed, the `UZF-26` evidence table,
the completion checklist, `Closes #N` — open the PR on it from the last pushed commit, check it by
verb, request reviewers, and hand it to `hatsu:en`.

**A new skill, so this record proves the verbs it calls.** Four of the five are read-only or pure
and were run live; the fifth (`nen pr request-reviews`) is a GitHub write and is inspected by
contract only, per this wave's ground rules.

> **Dated note, 2026-09-10 — the key changed after this record was made; the record did not.** Every
> transcript below is verbatim and stays that way. The maintainer's ruling of 2026-09-10
> ([`docs/ROSTER.md`](../ROSTER.md) § *Rulings of 2026-09-10*, *Two provenance trailers*) split
> provenance in two: a **local** Hatsu session writes **`Hatsu-Agent: <persona>`**, and
> `Akatsuki-Agent:` is the **autonomous CI plane's** key, which nothing on this plane writes. So read
> every `Akatsuki-Agent=…` below as *what was written on the day*, not as what to write now. What the
> runs establish about the verbs is unaffected: both keys sit on
> `commits.allowedAttributionTrailers`, so the accept/refuse behaviour is identical either way.

Run: 2026-09-10 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
Every transcript below ran against a **throwaway fixture** at `<worktree>/.nen-fixture` — a `git
init`ed directory holding two drafted bodies, a requirements file, a `CHANGELOG.md` and a
`changelog.d/` — which was deleted before this branch was committed. `nen pr body-check`,
`nen changelog fragment-required` and `nen gate derive` are **pure**: they read the paths they are
given and reach no network. **No GitHub write of any kind was made, and no primary checkout was
touched.**

Nothing below is redacted; both repositories are public.

---

## 1. The skill

Shibari is `mukai`'s sixth and last step. It **proves nothing of its own** — every fact in the body
was established by a step above it — so what this record has to establish is the four mechanical
checks it applies to the body it wrote, and the two absences it works around by hand.

| Shibari's own step | Owned by | Evidence |
|---|---|---|
| The body's required sections | `nen pr body-check` | **§ 2.1** |
| The changelog fragment | `nen changelog fragment-required` | **§ 2.2** |
| The gate, as a forecast | `nen gate derive` | **§ 2.3** |
| Writing the body back | **residue** — `nen pr edit-body` absent | **§ 2.4** |
| Opening the PR | **residue** — no `nen` verb creates a PR | **§ 2.4** |
| Requesting reviewers | `nen pr request-reviews` — contract only | **§ 2.5** |
| The evidence rows | **residue** — `nen shu evidence` absent; re-used from `rikugan` | `docs/ab/rikugan.md` § 3 |

---

## 2. Verbs exercised live

### 2.1 — `nen pr body-check`: every requirement reported, and exit `1` on a miss

Requirements file, the target's own template convention (`reqs.json`):

```json
[
  {"name": "What this changes for you", "pattern": "^# What this changes for you"},
  {"name": "What changed", "pattern": "^## What changed"},
  {"name": "How to verify", "pattern": "^## How to verify"}
]
```

```
$ nen pr body-check --body-from body-good.md --requirements-from reqs.json
3/3 requirement(s) satisfied
ok  What this changes for you
ok  What changed
ok  How to verify
exit=0

$ nen pr body-check --body-from body-bad.md --requirements-from reqs.json
2/3 requirement(s) satisfied
ok  What this changes for you
ok  What changed
MISSING  How to verify
exit=1
```

**It reports every requirement rather than stopping at the first miss**, which is what makes one run
enough to fix a body — a first-miss check would need as many runs as the body has holes. **Exit `1`
is the finding**, and shibari treats it as one: the section is written and the check re-run before
the body is attached.

**What it does not do:** it never looks at changed paths (§ 2.2 is a separate, diff-shaped check),
and it asserts nothing about *content* — a `## How to verify` heading followed by nothing satisfies
it. The steps under the heading being runnable is the skill's job, not the verb's.

### 2.2 — `nen changelog fragment-required`: all four verdicts, and one refusal

```
$ nen changelog fragment-required \
    --spec-paths "CONSTITUTION.md,handbooks/,nen/,schemas/,agents/,.github/workflows/" \
    --fragment-dir changelog.d --files "README.md,docs/notes.md" --head-changelog CHANGELOG.md
not-applicable
no spec/canon paths changed, so the per-PR fragment rule does not apply
exit=0
```

```
$ nen changelog fragment-required \
    --spec-paths "CONSTITUTION.md,handbooks/,nen/,schemas/,agents/,.github/workflows/" \
    --fragment-dir changelog.d --files "nen/contract.json,claude/skills/shibari/SKILL.md" \
    --head-changelog CHANGELOG.md
required
this change touches a spec/canon path (nen/) but adds no changelog.d/ fragment, and its body carries
no opt-out with a reason. Add changelog.d/<number>-<slug>.md -- never a direct edit to the
changelog's Unreleased block, which the fragment convention retired as the per-PR mechanism -- or
state the opt-out reason if this change is genuinely non-spec.
exit=1
```

```
$ printf -- '- shibari composes the PR body.\n' > changelog.d/1234-shibari.md
$ nen changelog fragment-required --spec-paths "nen/" --fragment-dir changelog.d \
    --files "nen/contract.json,changelog.d/1234-shibari.md" --head-changelog CHANGELOG.md
fragment-present
a fragment under changelog.d/ is added or modified and survives at head -- satisfied
exit=0
```

```
$ printf 'no CHANGELOG entry: docs-only change\n' > optout.md
$ nen changelog fragment-required --spec-paths "nen/" --fragment-dir changelog.d \
    --files "nen/contract.json" --head-changelog CHANGELOG.md --body-from optout.md
opt-out
the body states the opt-out with a reason -- skipping the entry check, as the rule allows for a
genuinely non-spec change
exit=0
```

**And the refusal**, hit first by accident and kept because it is the more interesting transcript —
the fixture had no `CHANGELOG.md` on the first pass:

```
$ nen changelog fragment-required \
    --spec-paths "CONSTITUTION.md,handbooks/,nen/,schemas/,agents/,.github/workflows/" \
    --fragment-dir changelog.d --files "README.md,docs/notes.md" --head-changelog CHANGELOG.md
nen changelog: could not read '<fixture>/CHANGELOG.md' (ENOENT). A verb that fell back to an empty
input here would report a clean verdict for a check it never ran.
Run 'nen changelog --help'.
exit=2
```

*(That is the `not-applicable` invocation above, run before the fixture had a `CHANGELOG.md`: the
same flags, the same diff, and a refusal instead of a verdict. All four verdict transcripts above
are from the re-run after the file was created.)*

**Exit `2`, not a `not-applicable`.** The verb refuses to answer a question it could not evaluate,
and says why in the refusal itself. That is the behaviour a caller wants and the opposite of what a
"be lenient about missing inputs" instinct would produce — recorded here because a reader hitting it
will read it as the verb being broken (§ 4.1).

### 2.3 — `nen gate derive`: the derived gate stands, and it says what it does not know

```
$ nen gate derive --policy-paths "CONSTITUTION.md,handbooks/,agents/,nen/,schemas/" \
    --process-paths ".github/workflows/,claude/,scripts/,tests/,docs/" \
    --files "claude/skills/shibari/SKILL.md,docs/ab/shibari.md"
G4
G4: the diff touches the process surface (claude/, docs/); in a repository whose product is its
process, that is a policy change.
This is the diff's half of the derivation only. A pull request that is not ready has NO GATE -- it
is in progress and owned by its author -- so compose this with a readiness verdict before putting a
row in anyone's queue.
exit=0
```

```
$ nen gate derive --policy-paths "..." --process-paths "..." --files "README.md"
G2
G2: the diff touches neither path set across 1 changed file, so it is product code.
exit=0
```

```
$ nen gate derive --policy-paths "..." --process-paths "..." --files "nen/workflow.json" --asserted G2
G4
G4: the diff touches policy/spec (nen/), which only the human merges.
correction: the invocation asserted G2; the diff derives G4, and the derived gate stands.
exit=0
```

`--json`, on this wave's own shape:

```
$ nen gate derive --policy-paths "..." --process-paths "..." --files "claude/skills/en/SKILL.md" --json
{
  "gate": "G4",
  "changed": ["claude/skills/en/SKILL.md"],
  "hits": [{ "path": "claude/skills/en/SKILL.md", "pattern": "claude/", "set": "process" }],
  "basis": "G4: the diff touches the process surface (claude/); in a repository whose product is its process, that is a policy change.",
  "asserted": null,
  "corrected": false,
  "readinessNote": "This is the diff's half of the derivation only. …"
}
exit=0
```

**Three properties this port relies on**, all visible above: the correction is the verb's and the
**derived gate stands** rather than the asserted one; the `readinessNote` is printed on **every**
run, unprompted, and it is the reason shibari's body states the gate as a **forecast**; and the exit
code is `0` in every case — `nen gate derive` reports, it never gates.

### 2.4 — Two absences, both refused cleanly

**`nen pr edit-body` does not exist**, in both shapes the mistake takes:

```
$ nen pr edit-body
nen pr: unknown 'pr' subcommand 'edit-body'. Known: ready, staleness, body-check, fetch,
next-blocker, cascade-main, retarget, request-reviews.
Run 'nen pr --help'.
exit=2

$ nen pr edit-body --pr 1 --body-file body-good.md
nen pr: unknown option '--body-file'. Known options here: --add-reviewers <value>, --approvers
<value>, --base <value>, --body-from <value>, … --wakes-from <value>.
Run 'nen pr --help'.
exit=2
```

**The eight known subcommands in that first message are also the proof of the second absence: no
`nen` verb opens a pull request.** `create` is not among them, so `gh pr create` is residue, named
in `SKILL.md` § 4.

*(The second refusal is worth reading closely: `--body-file` is unknown to the **whole `pr`
family**, while `--body-from` — `body-check`'s input flag — is known. A reader who mistypes one for
the other gets a list, not a guess.)*

### 2.5 — `nen pr request-reviews`: contract inspected, not exercised

Mutating GitHub call; read-only inspection only, per this wave's ground rules.

```
$ nen pr --help
…
  nen pr request-reviews --target <owner/name> --pr <n> --add-reviewers a,b
…
request-reviews:
  gh pr edit --add-reviewer, once per name. Request on the MAINTAINER's
  user token -- a bot token silently no-ops on this call (S6); this verb
  cannot enforce which credential ran it, only warn.
exit=0
```

**"Silently no-ops" is the whole reason `SKILL.md` § 9 makes the handover line say whether the
request landed.** A verb that cannot enforce which credential ran it can only warn, and a warning
nobody carries forward is a reviewer nobody requested.

---

## 3. Residue

1. **`gh pr create`** — no `nen` verb opens a pull request (§ 2.4's subcommand list). Named in
   `SKILL.md` § 4 and run by hand.
2. **`gh pr edit --body-file`** — `nen pr edit-body` absent at `v0.3.0` (§ 2.4), P2 in the brief.
   Always `--body-file`, never an inline `--body` string: a body carrying backticks, `$` and mermaid
   fences is one quoting mistake from a mangled PR.
3. **`nen shu evidence --base <ref>`** — absent (`docs/ab/rikugan.md` § 2.2 records the same). The
   evidence rows are `git diff --name-only <base>...HEAD` filtered by `project.evidence.globs`,
   **re-used from `rikugan`'s landing assembly rather than derived a second time**, so a report and
   a PR body cannot disagree about which scenes changed.
4. **The evidence mirror's publish step is the target repository's own script** — on KroApple,
   `ci_scripts/pr_screenshots.sh -y`. Nen shells out to `git` and `gh` and nothing else by design;
   a hosting mechanism is a stack's machinery, not a repository operation.
5. **`gh pr view --json baseRefName`** — `nen gate derive` reads the diff's half only and does not
   know the base (§ 2.3's own printed note), and this stack of skills does not call `nen pr fetch`
   (the recorded reviews-endpoint crash, `claude/skills/sharingan/SKILL.md` § 3).
6. **The last-pushed-commit precondition** — `git fetch origin <branch>` plus a two-ref
   `git rev-parse` comparison. `nen wc classify` reports distance from the **base**, never from the
   remote branch.
7. **`nen/workflow.json` is unvalidated at `v0.3.0`** — no row in `nen schema check`. `SKILL.md`
   § 2's keys are read as data with the defaults stated.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — `nen changelog fragment-required` refuses a missing `--head-changelog`, and it is right to

§ 2.2's last transcript: exit `2`, *"A verb that fell back to an empty input here would report a
clean verdict for a check it never ran."* **Recorded as a property to preserve, not a defect.** The
tempting "fix" — treat a missing changelog as an empty one — would make the verb answer `required`
or `not-applicable` for a repository it never actually read, and the answer would look identical to
a real one. The cost is that a repository with no `CHANGELOG.md` at all gets a refusal rather than a
verdict, which the calling skill must report as the fact it is instead of swallowing.

### 4.2 — `fragment-present` needs the fragment on disk at head, not merely in `--files`

Discovered live and not documented in `--help`: passing `--files "nen/contract.json,changelog.d/1234.md"`
for a fragment that **does not exist in the working tree** still reports `required`, and only once
the file was actually written did the verdict flip to `fragment-present` — whose own line says
*"added or modified **and survives at head**"*. The behaviour is correct (a fragment deleted later
in the same branch should not satisfy the rule) and the message does state it, but the flag name
`--files` reads as "the changed set" and invites the mistake.
`claude/skills/tensho/SKILL.md` § 5's summary — *"`fragment-present` once the fragment path is
included in `--files`"* — is **incomplete in exactly this way**; it is not wrong about the common
case and is left as it stands, with this note as the correction. **Not filed** as a nen defect: the
verb's own output already says `survives at head`.

### 4.3 — Copilot's reviewer mechanics are the one thing in this skill that is unverified

`SKILL.md` § 9 carries two claims that this port could **not** confirm live, because both need a
GitHub read against a repository whose review settings were out of scope: (i) that Copilot code
review may be configured to run **automatically**, making an explicit request redundant or a
duplicate; and (ii) that where it is requested, Copilot is addressed by its **bot id**, not by the
login `copilot`. They are written in the skill as **caveats to confirm**, marked as such, rather
than as mechanics — and this entry exists so that the first person to run `shibari` against a real
repository knows exactly which two sentences to check and correct. **A skill that states an
unverified mechanic as verified is worse than one that names the gap**, and the failure here is
quiet: an un-requested reviewer that the handover reports as requested makes `en`'s whole
reviewer-round leg wrong for as long as nobody looks.

### 4.4 — `nen gate derive` printing its own limit on every run is the pattern to copy

§ 2.3: the `readinessNote` is not behind `--explain` and not behind `--json` — it prints on every
invocation, and it says the one thing that would otherwise be inferred wrongly (*a PR that is not
ready has no gate*). **This is why `shibari` states the gate as a forecast**, and it is the reason
the skill can say that without a rule of its own to enforce: the verb says it out loud every time.
Recorded as a design property worth preserving in the verbs that are still to be written — a verb
that prints what it does **not** decide is a verb that cannot be over-read.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| `gh pr edit --body-file` for the write-back | `nen pr edit-body --target zheref/hatsu --pr 30 --body-file <f> --dry-run` | `0` |
| the same verb refusing the other family's object | `nen issue edit-body --target zheref/hatsu --issue 30 --body-file <f> --dry-run` | `2` |
| `nen shu evidence` absent | see `docs/ab/kotoamatsukami.md` § *Retired at nen 0.5* | `0` |
| `nen/workflow.json` unvalidated | `nen schema check --repo .` | that row `ok` |

```
$ GH_TOKEN=$(gh auth token) nen pr edit-body --target zheref/hatsu --pr 30 \
    --body-file <f> --dry-run
would run: gh pr edit 30 --repo zheref/hatsu --body-file <f>
target: zheref/hatsu
number: 30
bytes: 48
first line: chore(x): probe
last line: Akatsuki-Agent: kurapika
exit=0

$ GH_TOKEN=$(gh auth token) nen issue edit-body --target zheref/hatsu --issue 30 \
    --body-file <f> --dry-run
nen issue: #30 names a pull request in zheref/hatsu, not an issue -- 'nen issue edit-body' replaces an
ISSUE's body only, and it is certified before any write, so nothing was changed. Ask 'nen pr edit-body'
for the pull request's body instead.
exit=2
```

**`--dry-run` still performs the certifying read** — this pair is not network-free — and the refusal
above is that read doing its job: the number is checked *before* any write, so a mistake costs a refusal
rather than an overwritten body. Through `v0.4.0` both spellings answered *"unknown 'pr' subcommand
'edit-body'"* / *"unknown option '--body-file'"* at exit `2` (§ 2.4).

**Still residue:** `gh pr create`. `nen pr` carries nine subcommands at this pin and `create` is not one.

## Retired at nen 0.6 — 2026-09-10

Run against the released `zheref/nen` `v0.6.0` binary (`nen-darwin-arm64`, sha256
`2674dc58…151737e1`, fetched and checksum-verified by `bootstrap/nen.sh --ref v0.6.0`, on `PATH` as
`nen`; `nen --version` → `0.6.0`), with `GH_TOKEN=$(gh auth token)` — the maintainer's own user
token — against the real `zheref/hatsu#36`.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| § 4.3's two Copilot caveats, stated as unverified | `nen pr request-reviews … --add-bots BOT_kgDOCnlnWA --dry-run` | **`0`**, routed |
| a login that resolves to neither a bot nor a collaborator | `… --add-reviewers copilot --dry-run` | **`2`**, naming it |
| the empty-input refusal naming the wrong flag | `nen pr request-reviews --target … --pr 36` | **`1`**, naming its own two |

### `--add-bots` is the mechanic, and the route is printed before anything is requested

```text
$ nen pr request-reviews --target zheref/hatsu --pr 36 --add-reviewers zheref \
    --add-bots BOT_kgDOCnlnWA --dry-run
would request review on zheref/hatsu#36:
  zheref -> user [add-reviewers]
  BOT_kgDOCnlnWA -> bot [add-bots]                                                                # exit 0
```

**Two routes, chosen per name, and the verb chooses them.** A bot goes through GitHub's
`requestReviews` GraphQL mutation's `botIds`; a collaborator goes through `gh pr edit
--add-reviewer`, unchanged. The split exists because `gh pr edit --add-reviewer` resolves through
`requestReviewsByLogin`, which **never resolves a Bot reviewer at all** — which is why the old
`--add-reviewers copilot` was a dead end rather than a spelling problem, and why § 9 could only state
it as a caveat. An `--add-reviewers` entry containing a `/` is an `org/team` slug and goes straight
to `gh pr edit --add-reviewer` with no lookup.

### The refusal that replaces the silent no-op

```text
$ nen pr request-reviews --target zheref/hatsu --pr 36 --add-reviewers copilot --dry-run
nen pr: 'copilot' does not resolve to a Bot already known to zheref/hatsu#36 (its own reviewRequests or
timelineItems) or a collaborator of zheref/hatsu. A login this pull request has never requested a review
from, or received one from, cannot be told apart from a genuine typo -- if it is a bot's login, name it by
its node id with --add-bots instead.                                                              # exit 2
```

**This is a behaviour change, not only an addition**, and `nen/contract.json`'s
`zero_major_caveat.why` names it as one of the three at this minor: `v0.5.0` passed that login
through. A caller who typed `copilot` and read exit `0` learned nothing; a caller who reads exit `2`
is pointed at the flag that works.

```text
$ nen pr request-reviews --target zheref/hatsu --pr 36
no reviewers named -- --add-reviewers takes a comma-separated list of logins, or --add-bots a
comma-separated list of node ids                                                                  # exit 1
```

The wording names **this verb's own** flags. A prior version named `--reviewers`, which belongs to
`pr ready` / `pr next-blocker` and was never this verb's spelling (`zheref/nen#95`).

### The caveat that survives, and why the verb is built around it

**`BOT_kgDOCnlnWA` is Copilot's reviewer node id — data, not a rule.** Read the id off the target's
own reviewer set where a repository has a different one.

**The identical mutation call has been observed answering `NOT_FOUND` for a botId under one token and
succeeding under another** — a permission-scoped difference in what a token can resolve, recorded in
nen's own `src/pr/bots.ts` header, and not a flake. So the verb reports success from the **mutation's
own response** — which bots now read as pending review — never assumed from the ids it sent. § 9's
instruction follows from that and is the operative one: **read the verb's answer, and where it does
not name the bot, say the request did not land and why.** An un-requested reviewer that the handover
reports as requested is the one error that makes `en`'s whole reviewer-round leg wrong.

**The first of § 4.3's two caveats is unchanged and is still checked first.** `zheref/hatsu` has
GitHub's Copilot code review configured to review **automatically**, so on this repository requesting
it by hand is a no-op at best and a duplicate review at worst — the mechanic above is for a target
that does not have it configured.

### Nothing retired: `gh pr create`

`nen pr` at `v0.6.0` carries `ready`, `staleness`, `body-check`, `fetch`, `next-blocker`,
`cascade-main`, `retarget`, `request-reviews` and `edit-body`. `create` is not among them
(`nen pr --help`, read live at this pin). § 4's `gh pr create` is **genuinely still residue**.


## Complete associated-issue set — 2026-09-12

Hatsu #50 referenced #48 as `Part of` and #49 as `Closes`; a live GraphQL read showed only #49
in closingIssuesReferences. A body mention did not satisfy Development linkage. The updated
contract requires every addressed issue in both places, and a scope/completion row per issue.
Scenarios include multiple completed issues (one closing clause each), scope added after creation
(reconcile both sets), dependency-only reference (do not claim implementation), and partial work
(auto-close conflict surfaced before merge, never a false completion claim). UI/permission/limit
failures are explicit blockers. Evidence is a live association read, not a string search in a body.
