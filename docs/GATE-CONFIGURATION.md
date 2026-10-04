# Gate configuration — how a consumer repository tunes its own readiness gate

**This file is the authority on `nen/gates.json` from a CONSUMER's point of view.**
[`WORKFLOW.md`](WORKFLOW.md) is the authority on the loop and on the two-file configuration split;
this one covers the question neither it nor the skills answered: *I am adopting Hatsu in my own
repository — what do I put in `nen/gates.json`, and what happens if I get it wrong.*

> **Redaction notice.** Where this file names a repository that is not public, the name is a stable
> placeholder — see [`PUBLIC-REDACTION.md`](PUBLIC-REDACTION.md).

---

## 1. The gap this closes

The mechanism was already good. `nen/gates.json` is JSON, it is validated by `nen schema check`, it
fails **by pointer** on a malformed key, and the readiness workflow passes only `--gates` — so a
consumer tunes that one file and the workflow follows **with no workflow edit at all**.

What was missing was the page. `approval_policy` appeared in [`WORKFLOW.md`](WORKFLOW.md) only as a
record of the 2026-09-12 ruling *for Hatsu and Nen*; `dependabot_carve_out` appeared only inside an
`ab/` transcript and a `$comment`. There was no single place telling a consumer maintainer how to
tune their own gate, which meant the usual outcome: the file was copied from `zheref/hatsu`, and
`zheref/hatsu`'s ruling about its own reviewers silently became somebody else's policy.

**Copying this repository's `nen/gates.json` is the mistake this page exists to prevent.** The
reviewer identities in it are Hatsu's. Yours are yours.

---

## 2. What the gate actually decides

`nen pr ready` evaluates five conjuncts, and `nen/gates.json` supplies the reviewer half of them:

| Conjunct | Rule | Read from this file? |
|---|---|---|
| `CON-42/1` | the pull request is mergeable | no — GitHub's own state |
| `CON-32(a)` | every reported check is green | no |
| `CON-32(b)` | a review round is owed at the current head | **yes** — `reviewers` |
| `CON-32(b)` / `CON-16` | approvals | **yes** — `approval_policy`, `default_approvers` |
| `CON-32(d)` | no unresolved threads | no |

**A gate is not a merge.** `nen pr ready` says whether the gate's conditions hold; the human merge
decision stays outside it, at `G2` in your repository (`CON-5`) — or `G4` (`CON-7`) if your
repository's *product is the process*. See [`ROSTER.md`](ROSTER.md) § *Rulings of 2026-09-18*.

---

## 3. The keys, and what each one costs you if it is wrong

### `reviewers` — who counts as a review round

A list of named identities with a `login_pattern`. The pattern is matched against the reviewer's
login, so a bot and a human are declared the same way.

```json
"reviewers": [
  { "name": "copilot",
    "login_pattern": { "pattern": "^(copilot|copilot-pull-request-reviewer(\\[bot\\])?)$",
                       "ignoreCase": true } }
]
```

**Declare the identities that actually review in YOUR repository.** A pattern naming a reviewer who
never reviews means a round is owed at every head and the gate never closes. A pattern that is too
broad means any drive-by comment satisfies a round.

### `approval_policy` — `"required"` or `"review-round-only"`

This is the key that decides whether an empty `default_approvers` is legal, and it is load-bearing in
**both** directions:

| Value | Means |
|---|---|
| `"required"` | `default_approvers` must be non-empty, and an `APPROVED` review from one of them is a conjunct |
| `"review-round-only"` | a completed review **round** satisfies the gate; no separate `APPROVED` review is required |

**An empty `default_approvers` without this key is refused**, in nen's own words: *an empty approval
set makes the approve limb of the readiness gate vacuously true*. That refusal is the feature. Say
which of the two you mean; do not arrive at an empty set by omission.

> **Solo maintainer, no second human?** `"review-round-only"` with an automated reviewer declared is
> the honest shape — the round is real, and the run ends each PR at your merge prompt (`en` § 5). Setting `"required"` and listing
> yourself makes the approve limb vacuous by a different route.

### `default_approvers` — whose approval counts

A list of logins. **Non-empty when `approval_policy` is `"required"`; deliberately empty, and legal,
under `"review-round-only"`.**

### `base_reviewers` — who is requested by default

The identities a new pull request asks for. Names here should exist in `reviewers`.

### `delivery` — which pull requests are yours

Identifies the repository's own delivery branches so the gate can tell them from everything else:

```json
"delivery": {
  "author_pattern": { "pattern": "^your-login$", "ignoreCase": true },
  "head_ref_prefixes": ["claude/", "codex/"],
  "labels": []
}
```

**`head_ref_prefixes` is the one people get wrong on adoption.** Copying `["codex/"]` into a
repository whose branches are all `claude/…` classifies every delivery PR as *not yours*.

### `dependabot_carve_out` — optional, and refused when it is toothless

```json
"dependabot_carve_out": {
  "author_pattern": { "pattern": "^dependabot(\\[bot\\])?$", "ignoreCase": true },
  "satisfied_by_context": ["build", "test"]
}
```

A dependency-bump PR gets its review rounds cleared **only** when the named check contexts have
reported. **`satisfied_by_context` may not be empty** — nen refuses it in terms worth quoting,
because the refusal explains the whole design: *a carve-out satisfied by no context is satisfied by
nothing, so it would clear the review rounds for every pull request that author opens on no evidence
at all.*

Omit the block entirely if you do not want the carve-out. An absent block is a decision; an empty one
is a hole.

### `round_policy` — how many reviewer rounds, and when the asking stops

```json
"round_policy": { "stallMinutes": 30, "minRounds": 1, "maxRounds": 3 }
```

`stallMinutes` is nen's: a review request older than it reads `not-ready: reviewer round stalled`.
`minRounds` (**N**) and `maxRounds` (**M**) are **Hatsu's own keys** (zheref/hatsu#102; nen preserves them as
raw data — counting them in `nen pr ready --explain` is zheref/nen#240). **Neither key is ever unbounded:** a
repository that omits one, or declares one sharingan cannot read, takes Hatsu's canon default in
[`contracts/round_policy.default.json`](../contracts/round_policy.default.json), by sharingan § 6's
per-key rule ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-09-30 — reviewer-round caps by default*).
**The rule that reads them is
[`sharingan`](../claude/skills/sharingan/SKILL.md) § 6's, stated there once**; what a consumer needs to
know under nen's `bounded` policy (zheref/nen#214) is one sentence of it: **a push re-owes the reviewer's
round at the new head, but an owed round is not a request** — the skill does not ask again because its
own push or request re-opened the row, and once N rounds stand resolved it does not ask at all;
`review_on_push` on the reviewer's side is what answers a push. A `$comment` in your `nen/gates.json`
that still says *every push re-opens that condition until the reviewer reviews again* describes the
pre-#214 gate and should go.

### `check_exclusions` — a ruling that a check is not watched, with an expiry

```json
"check_exclusions": [
  { "name": "windows-build", "reason": "no self-hosted Windows runner is registered",
    "ruled": "2026-09-22", "until": "condition: the runner is enabled" }
]
```

**Hatsu's own key** (zheref/hatsu#104): the declared home of a maintainer's check-exclusion ruling,
which otherwise lives only in chat and makes every verdict permanently red on `CON-32(a)` — and a red
verdict is how readiness falls back to reading CI by eye. `name` is the check exactly as the rollup
reports it; `ruled` is a `YYYY-MM-DD` date, not in the future; `until` is a `YYYY-MM-DD` date **or**
`condition: <what lifts it>`. The skills pass every live row as `nen pr ready --exclude-check <a,b>`,
each name its own argv element ([`pr-state`](../claude/skills/pr-state/SKILL.md) § 2 owns the rule), and
quote the verdict with the exclusion named. **What this key refuses** — `scripts/tenkai_adopt.sh
diagnose` names each as `drift`, and a refused row is **never put on the call**: a name carrying a
comma (the flag's separator, zheref/nen#243 — a matrix check named `check (Windows, windows-latest)`
cannot be excluded until nen carries a repeatable flag), a quote, a shell metacharacter or a control
byte; a near-miss date in `until` (`2026-9-1`, `09/01/2026`, a date with a trailing note — never read
as a condition); a condition row older than 90 days from `ruled` (re-rule it with today's date once the
condition is confirmed); a row past its `until` date. The day is your `reports.timeZone`, else the host's,
and the row says which. nen preserves the key; validating it is zheref/nen#249. An empty array is a
decision: nothing is excluded.

### `reviewer_fallback` — when a reviewer's credits run out

```json
"reviewer_fallback": {
  "chain": ["copilot", "bugbot"], "terminal": "hanten",
  "exhausted": [ { "reviewer": "copilot", "reason": "credits exhausted", "ruled": "2026-09-29", "until": "condition: the credits are restored" } ]
}
```

**Hatsu's own key** (ruling 2026-09-29). **The shape**: `chain` is reviewer identities in fallback order —
each requestable only where `reviewers[]` carries it (a step it does not carry is passed over; Cursor Bugbot is `bugbot` in every key here, login `cursor[bot]`,
`BOT_kgDODFXTxQ`, and declaring it in `reviewers[]` makes its round required on every PR until nen
reads the chain — the maintainer's call); `terminal` is the one non-reviewer, the
local hanten rounds, never requested; `exhausted[]` rows are `check_exclusions` rows one key over
(`reviewer`, `reason`, `ruled` `YYYY-MM-DD`, `until` a date or `condition: <what lifts it>`) and are
**live only while not lapsed** — a row past its `until` date, a condition row unconfirmed past 90 days
from `ruled`, or a malformed row is not honoured, and `scripts/tenkai_adopt.sh diagnose` names it
(`gates/reviewer-fallback`, observation only). **The behaviour** — what a silent request means, the
counting, the terminus, the quoted verdict and its one annotation line, the merge staying yours — is
[`docs/PROCESS.md`](PROCESS.md) § *Reviewer rounds and review threads*, *The fallback chain*, stated once.
nen reads neither key (zheref/nen#275).

### `round_quorum` — at least one bot reviewer's round

```json
"round_quorum": { "any_of": ["copilot", "bugbot"], "minimum": 1 }
```

**nen's key** (from nen `0.17`; the maintainer's ruling of 2026-09-29, restated 2026-10-04). **The shape**:
`any_of` is reviewer names, every one a `reviewers[]` entry; `minimum` an integer from `1` to the group's
size. The loader refuses an undeclared name, a duplicate, a `minimum` below `1` or above the group and a
non-integer, by pointer, so `nen schema check` fails the file. Each member is counted **whether or not it is
a base reviewer or `bounded_policy_exempt`**, so a group of one is a floor for that member even where
nothing is owed; otherwise the verdict is unchanged and row 4 gains the quorum clause. **Cost if wrong**:
every member's `login_pattern` and `round_check_pattern` must be **anchored and bot-only** (`^…$` over the
bot's exact logins and check name, as nen's own file spells them) — one member's round now covers the
others, so a broad member pattern lets any login or check containing the word satisfy the whole group; and
the `reviewers[]` entry `any_of` requires is owed on every PR once its check enrols it, which only the
*fulfils* half of zheref/nen#361 excuses — Hatsu's own file names Copilot alone until Cursor Bugbot
(`bugbot` here, the fallback chain's name for it) is enrolled on the repository and the pin reads that
release. The behaviour — what counts as a round, which unavailable member a met quorum fulfils, the one in
flight it never does, the route under the pin — is [`docs/PROCESS.md`](PROCESS.md) § *Reviewer rounds and
review threads*, *One bot reviewer suffices*, stated once.

### Hatsu's own keys in `nen/gates.json` — the convention

Three keys here are Hatsu's, not nen's: `round_policy.minRounds`/`.maxRounds` (`stallMinutes` in the
same object is nen's — the `$comment` says which is which), `check_exclusions[]` and `reviewer_fallback`;
`round_quorum`, beside them, is nen's.
Each is a gate **declaration**, so it lives in the gate's file; each is **preserved, not read**, by `nen
schema check` (a string `minRounds` reads `ok` — nothing validates these at 0.15.1); an object-valued key
carries its `$comment` inside, an array-valued key a `$`-prefixed sibling; each names its ruling, the one
skill that states its rule, one owned nen issue for the eventual machine read (zheref/nen#240, #249,
#275), and one `tenkai diagnose` row where a row can lapse.
---

## 4. Validate it, and read the pointer

```bash
nen schema check --repo .
```

Every refusal names the **pointer** — `at default_approvers`, `at approval_policy`,
`at dependabot_carve_out.satisfied_by_context` — so a malformed gate tells you which key, not merely
that the file is bad. **Read the pointer before changing anything**, and read the exit code without a
pipe: `$?` after `cmd | tail` is `tail`'s status.

Then check it against a real pull request:

```bash
nen pr ready <n> --gh-repo <owner/name> --explain
```

`--explain` prints the conjunct-by-conjunct table, which is how you tell *"the gate is configured
wrong"* from *"the pull request genuinely is not ready"*. Exit `1` is **not-ready**, which is the
common case and not an error.

---

## 5. The gate the workflow uses is the TRUSTED one

If you adopt [the readiness workflow](../templates/pr-readiness.yml), its verdict step passes
`--gates "$PWD/.trusted/nen/gates.json"` — **the copy from the base branch, never the pull request's
own.**

This is not belt-and-braces. With the flag dropped, nen falls back to `<cwd>/nen/gates.json`, and the
cwd in that job is the **pull request's head checkout** — so losing the flag hands the pull request
the gate that judges it. It reads as a harmless simplification and it is the opposite of one.
`scripts/tenkai_adopt.sh diagnose` reports a dropped `--gates` as drift for this reason.

**The practical consequence for you:** a change to `nen/gates.json` takes effect for *other* pull
requests once it is **merged**, not while it sits in the pull request proposing it. That is correct,
and it is worth knowing before you conclude your edit did nothing.

---

## 6. Adoption

[`hatsu:tenkai`](../claude/skills/tenkai/SKILL.md) diagnoses `nen/gates.json` as *present and
parseable* and **routes its creation to `nen scaffold init`** — it does not write one for you, and it
does not copy Hatsu's. The content is yours: this page is what you tune it with.

```bash
scripts/tenkai_adopt.sh diagnose --repo <path>
```

---

**2026-09-20.** Changing a guard's trigger shape is a two-step landing: first the validator that
accepts both shapes, then the workflow; the trusted copy judges the PR. `scripts/
workflow_runner_policy_check.rb` (§5 above) is checked out from `main` and run against every pull
request's own `.github/workflows/`, so a PR that changes BOTH a live guard's shape and this
validator's acceptance of that shape in the same commit is judged by the OLD validator on `main` —
which still expects the old shape — and is refused no matter how the new shape and the new validator
agree with each other. Land the validator first, accepting the old shape and the new one; only once
`main` trusts that validator can a follow-up PR flip the live workflow.

**Step two landed (zheref/hatsu#93 follow-up, Hatsu 0.44.0).** `plugin-bump-check.yml`,
`surface-mirror-check.yml` and `pr-readiness.yml` now carry the hardened shape: `ready_for_review`
in their `pull_request_target` `types:`, and the job `if:` guard carrying the draft-skip conjunct as
one `${{ }}` expression. `surface-mirror-regenerate.yml` is installed live at
`.github/workflows/surface-mirror-regenerate.yml`. This is no longer a follow-up to schedule; it is
done.

**2026-09-30. A generated mirror's hooks root is the same two-step landing.** `surface-mirror-check`
runs `scripts/surface_mirror_check.sh` from `main` and judges the pull request's `surfaces/` with the
roots *that* copy knows, so a PR that regenerates a mirror at a new `--hooks-root` reads
`hand-edited` until `main` knows the root — no commit on the PR can fix it. Step one teaches the
check the next root beside the current one (`hooks_root_next_for`, Hatsu 0.65.0: Codex's
`${PLUGIN_ROOT:-${HATSU_PLUGIN_ROOT:-./.codex}}`, accepted and said so); step two
([zheref/hatsu#151](https://github.com/zheref/hatsu/pull/151)) regenerates at that root, makes it the
current one everywhere the root is written — `hooks_root_for` in the script, the regenerate loop in
`surface-mirror-regenerate.yml`, the one in [`docs/SURFACES.md`](SURFACES.md) § 3 and the root paragraph in
`docs/surfaces/README.md` — deletes the next-root row and its fixture cases
(`scripts/surface_mirror_check_fixture.sh`, lane `surface-mirror-guard`), and checks that the old root
now reads `hand-edited`.

**Step two landed ([zheref/hatsu#151](https://github.com/zheref/hatsu/pull/151), Hatsu 0.66.0).** The Codex root is
`${PLUGIN_ROOT:-${HATSU_PLUGIN_ROOT:-./.codex}}` in `hooks_root_for`, the regenerate workflow, `docs/SURFACES.md` § 3 and
`docs/surfaces/README.md`; `hooks_root_next_for`, its re-check and its fixture cases are gone, and a Codex mirror at the old
root reads `hand-edited: hooks.json` again.

**2026-10-02. The readiness pin and the regenerate cleanup, both steps landed.** Step one
([zheref/hatsu#193](https://github.com/zheref/hatsu/pull/193), Hatsu 0.78.0) taught the validator two
frozen next shapes beside the current ones. Step two flips the live workflows and narrows the
validator to the new shapes alone: `pr-readiness.yml` drops its freshness step and passes
`--exclude-check readiness --require-head "$EVENT_HEAD"` (zheref/hatsu#160), and
`surface-mirror-regenerate.yml` gives its PR step `id: cpr` and adds the failure-only cleanup step
(zheref/hatsu#165). The verdict, Publish and cleanup steps are compared byte for byte.
Every other step of `pr-readiness.yml` is frozen the same way (`READINESS_FROZEN_STEPS`), so no
earlier step can reach the verdict through the environment, the `PATH`, a `shell:` or an action; the
other workflows' job keys, step keys, `uses:`, `shell:` and step env keys are held to exact allowlists.

**Step three, recorded, not done.** Two fixes change a frozen body or the job structure, which `main`'s
trusted copy compares exactly, so each needs a two-step landing of its own: the verdict's first-line
read (`printf '%s\n' "$explain" | head -1`) can die on SIGPIPE under `pipefail` when the explain
outgrows the pipe buffer — it fails closed, Publish posting `readiness undetermined` — and the fix is
`${explain%%$'\n'*}`; and splitting the verdict (read-only token) from Publish (the only step that
needs `checks: write`) into two jobs changes `EXPECTED_JOBS` (hanten on step two, Phinks and Feitan).

