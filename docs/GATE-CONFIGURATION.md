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
`minRounds` (**N**) and `maxRounds` (**M**) were Hatsu's own keys (zheref/hatsu#102) and are **nen's from
`v0.21.0`** (zheref/nen#240), adopted under the same names by the maintainer's ruling of 2026-10-04
(*retire 2, adopt 2*). nen validates both by pointer (non-negative integers, N ≤ M) and reads them two
ways, **neither a readiness conjunct**: `nen pr request-reviews` **refuses a bot's request past M at exit
`2`**, reading M at the pull request's base and at the default branch's tip and applying the lower, and
`nen pr ready --explain` prints each reviewer's requested and posted counts against both
(`meta.roundCounts`). **The two counts differ on purpose**: nen counts N against **posted** rounds, while
the skills count it against **resolved** ones — every finding fixed, replied to and its thread resolved.
**Neither key is ever unbounded in the skills:** a
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

### `checks.excluded` — a ruling that a check is not watched, with an expiry

```json
"checks": {
  "excluded": [
    { "name": "windows-build", "reason": "no self-hosted Windows runner is registered",
      "ruled": "2026-09-22", "until": { "condition": "the runner is enabled" } }
  ]
}
```

**nen's key** (from `v0.20.0`, zheref/nen#249): the declared home of a maintainer's check-exclusion
ruling, which otherwise lives only in chat and makes every verdict permanently red on `CON-32(a)` — and a
red verdict is how readiness falls back to reading CI by eye. It replaces Hatsu's own `check_exclusions`
(zheref/hatsu#104), **retired** by the maintainer's ruling of 2026-10-04, *retire 2, adopt 2*
(zheref/hatsu#227). **The shape**: `name` is the check's rollup label, compared whole — a comma, a bracket
or a quote is simply part of it, so a matrix check such as `check (Windows, windows-latest)` can be named;
`match` is `exact` (the default) or `glob`, required when `name` carries a `*`, and a glob needs at least
3 literal characters before its first `*`; `reason` is quoted beside every check it drops; `ruled` is a
strict `YYYY-MM-DD`, not yet in force when after today (UTC); `until` is a strict `YYYY-MM-DD`, honoured
through that UTC day and reported expired from the next, **or** `{ "condition": "<what lifts it>" }`,
honoured until the file is edited and warned on at every evaluation. **What nen refuses**, by pointer: a
missing or blank field, surrounding whitespace, a near-miss date (`2026/10/01`, `2026-10-1`, a timestamp —
never read as a condition), an `until` before `ruled`, an unknown `match`, a short glob and the same name
twice. **How it is read**: `nen pr ready` and `pr next-blocker` read the block **at the pull request's
base**, never its head, so a PR cannot add an exclusion for its own red check — on a PR into the default
branch that base is the reviewed trunk, but a stacked or integration base's file may not have passed the
trunk's gate, so an entry there binds only as far as that branch's protection (SEC-6); they drop each honoured
entry's checks from `CON-32(a)` and name each beside its reason. **The skills pass no `--exclude-check`
for it** ([`pr-state`](../claude/skills/pr-state/SKILL.md) § 2 owns the rule) and quote the verdict as the
verb prints it. **Matching is by label only**, with no origin pinning: any check reporting under a
matching name is dropped, which is why an exact name is the safer form; and a runner pool's labels now end
in its own `pool-<id>` (nen `v0.21.0`), which a matrix check carries in its name, so re-key a name-matched
entry when a pool is relabelled. An empty list is a decision: nothing is excluded.

### `reviewer_fallback` — retired

Hatsu's own key of the ruling of 2026-09-29 — a chain of reviewer identities, a `terminal: hanten` and dated
`exhausted[]` rows — is **deleted** by the maintainer's ruling of 2026-10-04, *retire 2, adopt 2*, and
superseded by `round_quorum` (below) with zheref/nen#361: one available bot's round fulfils an exhausted
member's. nen `v0.21.0` refuses the key; `scripts/tenkai_adopt.sh diagnose` names it on
`gates/retired-keys` with the fix (delete it). [`docs/PROCESS.md`](PROCESS.md) § *Reviewer rounds and
review threads* records what replaced the chain's terminus.

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
every member's `login_pattern`, and any `round_check_pattern` it declares (optional: Copilot posts reviews
and has none), must be **anchored and bot-only** (`^…$` over the bot's exact logins and check name, as nen's
own file spells them) — one member's round now covers the
others, so a broad member pattern lets any login or check containing the word satisfy the whole group; and
the `reviewers[]` entry `any_of` requires is owed on every PR once its check enrols it, which only the
*fulfils* half of zheref/nen#361 excuses — Hatsu's own file names Copilot alone until Cursor Bugbot
(`bugbot` here) is enrolled on the repository (the v0.20.0 release carries the
*fulfils* half). The behaviour — what counts as a round, which unavailable member a met quorum fulfils, the one in
flight it never does, the route under the pin — is [`docs/PROCESS.md`](PROCESS.md) § *Reviewer rounds and
review threads*, *One bot reviewer suffices*, stated once.

### No Hatsu-owned keys in `nen/gates.json` — the convention, retired

Hatsu used to keep three keys of its own here — `round_policy.minRounds`/`.maxRounds`, `check_exclusions[]`
and `reviewer_fallback` — preserved and never read by nen. **From nen `v0.21.0` the file may carry only keys
the running nen reads** (zheref/nen#310, with no consumer carve-out); only a `$`-prefixed key is exempt, so
a `$comment` inside an object or a `$<key>` sibling is still how a ruling is recorded beside its value. The
maintainer's ruling of 2026-10-04, *retire 2, adopt 2*, settled the three: the round caps became nen's,
`check_exclusions` moved into `checks.excluded`, and `reviewer_fallback` was deleted. **A new gate a
repository wants to declare is a nen issue first**, never a Hatsu key in this file: a key nen does not read
fails `nen pr ready` at exit `2` on every pull request.

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

**The trusted revision is `main`'s head, not the pull request's base** (observed on the 2026-10-13 stack; the rule is WORKFLOW § *Stacked pull requests* rule 5, cited here): a stacked PR above a frozen-step change reads red until that change merges; the next push after its retarget runs the validator at the new head, a close-and-reopen is the fallback where no push follows, and `gh run rerun` reuses the stale trusted revision. **Drift step (2026-10-17, #289 item 2):** `DRIFT_FROZEN_GUARD` holds the *Surface-mirror drift check* body and the live step is held to it — one landing, since the workflow itself did not change. **Digest step's `--version` echo (#289 item 3, a two-step landing):** step one admits the step's next form — the closing echo made fatal — beside the current one (the constants `NEN_DIGEST_FATAL` and `REGENERATE_NEN_DIGEST_FATAL` carried the next form and were retired at step two; `require_frozen_step` keeps its list branch, tested, for the next landing); step two (HA-PR-#303) flipped the three workflows' echo lines and narrowed the admission back to one form: the frozen digest body ends with the fatal echo and the old echo is refused as a shape change. The validator also refuses an empty workflow file with a policy line and refuses the PR-root script spellings its self-test names, the original pattern kept whole.

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
`surface-mirror-regenerate.yml`, the one in [`docs/using/mirrors.md`](using/mirrors.md) § 3 and the root paragraph in
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

**2026-10-13. Every builder step is frozen, and no run carries an expression
([zheref/hatsu#190](https://github.com/zheref/hatsu/issues/190)).** `surface-mirror-regenerate.yml`
holds `contents: write`, and its only push guard was lexical: `git -C . push origin
HEAD:refs/tags/v9.9.9`, or a `gh api -X DELETE` of another branch, added to a run step passed `main`'s
validator. Each step but the pull-request step is now admitted only in its exact form
(`REGENERATE_FROZEN_STEPS`, the run compared byte for byte), and a `${{ }}` expression in any
workflow's run is refused, because Actions substitutes it into the shell source. The pull-request step
is held short of that (`REGENERATE_PR_WITH`): its pinned action, `id`, `if`, its exact keys and `with`
inputs, and every input's value but `body`, which is free prose; no `with` value reaches a shell, since
create-pull-request takes each as data. When a frozen builder step must change (a generate flag, a hooks
root), the maintainer lands it in two pull requests: the first teaches the validator on `main` the next
form beside the current one, the second changes the workflow and drops the old form. The freeze binds
what is merged on `main`; the `v*` tag ruleset below, the maintainer's repository setting, is what stops
a workflow token from writing a release tag at all.

**The `v*` tag ruleset, the maintainer's step (zheref/hatsu#190).** No pull request can apply a
repository setting. The body to send:

```json
{
  "name": "tags: v* release tags",
  "target": "tag",
  "enforcement": "active",
  "bypass_actors": [{ "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }],
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "rules": [
    { "type": "creation" },
    { "type": "update", "parameters": { "update_allows_fetch_and_merge": false } },
    { "type": "deletion" }
  ]
}
```

`gh api --method POST repos/zheref/hatsu/rulesets --input <file>` creates it. Actor `5` is the
repository's admin role, so a tag cut on the maintainer's own credentials still lands, while a workflow
token cannot create, move or delete a `v*` tag. A ruleset changes through `PUT
/repos/zheref/hatsu/rulesets/<id>`, which replaces it whole: send every field above with the complete
`rules` array, never only the rule that changes, and a required status check that names its app
carries `"integration_id": 15368` (GitHub Actions).

**2026-10-13. CI checks the bootstrapped nen against the contract's digest
([zheref/hatsu#230](https://github.com/zheref/hatsu/issues/230)), both steps landed.** The bootstrap
script verifies the binary against `SHA256SUMS` from the same release, so a moved tag or replaced
assets verify against themselves. `surface-mirror-check.yml`, `pr-readiness.yml` and
`surface-mirror-regenerate.yml` now hash the binary right after bootstrapping it and compare it with
the trusted checkout's `dependency.bootstrap.sha256["linux-x64"]` (the builder's own checkout of
`main`), failing closed with both digests named. Nothing runs the binary before that: the bootstrap
step prints only its path (nen's script verifies and places the binary, never runs it), and
`nen --version` runs last in the check, after the match; a bootstrap that still prints the version
beside the check is refused as the old order. Step one taught the validator the step and the
bootstrap's next form beside the current shapes; step two added both to the live files and narrowed
Hatsu's own forms to carrying them, frozen (`NEN_DIGEST_FROZEN`, `NEN_BOOTSTRAP_NEXT`). Where the root
holds `templates/pr-readiness.yml`, tenkai's rendered readiness form is refused, so no pull request here
can trade the checked bootstrap for the consumer's. **A repin moves the linux-x64 digest with
`dependency.pinned_ref`, in the same pull request**: that pull request is still judged by `main`'s old
pin and digest, but once it merges a digest that does not match the new release fails every pull
request closed, the one that fixes it included, until an administrator merges past the ruleset.
`scripts/nen_global_fixture_check.sh` (case 21c, lane `nen-global-guard`) holds every digest to the
current pin's own record, and that record to `pinned_ref`. **Tenkai's rendered readiness form carries
no such step**: a product repository's contract need not record nen's digest, since its pin can fall
back to the ref tenkai renders. Two follow-ups are owed, filed by the run's harvest: tenkai rendering a
digest beside that ref, and recording the bootstrap script's own sha256 and checking it before the
script runs, since the script runs before any check here can. **Ruled 2026-10-13** (ROSTER §
*Rulings of 2026-10-13*): this check — shell in a workflow step that
hashes a fetched binary and reads one contract key with `jq` — is workflow glue under BC-11's bootstrap
allowance, not a predicate owed to a nen verb; it stays in the three workflows, and tenkai's rendered
digest is the harvest's nen request. **Re-ruled 2026-10-17** (ROSTER § *Rulings of 2026-10-17*, q3: BC-11 as
written): the compare is a verdict, frozen to fixes only pending nen's own digest check (zheref/nen#407
item 8); it stays in the three workflows until that lands and the step becomes glue.

**2026-10-13. The prose-diet guard is a pull request check
([zheref/hatsu#135](https://github.com/zheref/hatsu/issues/135)), both steps landed.**
`scripts/prose_size_check.sh` ran only by hand and in its focused lane, so a file over its ceiling
reached `main` with #129. `prose-size-check.yml` runs the trusted revision's guard against every pull
request's checkout and fails the `prose-size-check` check on any offender, the guard's own `OVER` row
naming the file, its size and its ceiling. It is a check of its own because `pr-readiness.yml`
concludes `success` by construction. Its guard step is frozen (`PROSE_FROZEN_GUARD`) and refuses to
measure without a fresh fence token, and the exact-head check every guard workflow creates and
finishes is frozen at both ends, so no conclusion mapping can be edited into a green. Making the check
required is a ruleset edit, the maintainer's, sent as the whole ruleset (the `PUT` shape above); until
then it is advisory, and a red run still reads the pull request not-ready under CON-32(a).

**2026-10-13. The canon data contracts are guarded by nen's own validators
([zheref/hatsu#223](https://github.com/zheref/hatsu/issues/223)), both steps landed.**
`contracts/direct.registry.json`, `contracts/classify.taxonomy.json` and `nen/labels.json` held their
invariants only by the review's one-off checks. `scripts/canon_contracts_check.sh` now runs the three nen
reads (`nen direct registry`, `nen classify labels`, `nen classify install --dry-run` for labels parity)
and re-implements none; lane `canon-contracts-guard` seats its fixture. In CI the guard runs as a new
`Canon data contracts check` step of `surface-mirror-check.yml`, after the drift step, on the trusted
checkout's bootstrapped nen and trusted script over the pull request's data. Step one
taught the validator the step beside the current shape (`ALLOWED_STEP_SHAPES`, `CANON_CONTRACTS_STEP`)
and froze its one form (`CANON_CONTRACTS_FROZEN`: the trusted script, `NEN` the bootstrapped binary's
absolute path, `--root "$PWD"`, the output fenced between `::stop-commands::` and its token, no token in
its env; the self-test holds on both trees the landing produces and also runs the body with stand-ins
for the guard, the binary and openssl, so the exit mapping, the error lines and the fence hold at
runtime), so the pull request that installs it is judged by a validator already holding the body; step
two added the step to the workflow and narrowed `EXPECTED_STEPS` to it, one shape admitted again. A
canon-contract failure reads as a red `surface-mirror-check`, and a run red at the drift step never
reaches it (a check of its own would be the #135 route).

**The new-workflow rule.** A new pull-request workflow lands in two pull requests, the #80 order. The
first registers it in `PENDING_HOSTED_WORKFLOWS` (known, judged wherever it sits, not yet required) and
stages its file at `templates/<name>`, where the self-test judges it as if installed; the second
installs it under `.github/workflows/` and moves it to `PORTABLE_HOSTED_WORKFLOWS`, which makes its
absence a refusal. `PENDING_HOSTED_WORKFLOWS` stays in the validator, empty when nothing is pending, and
every per-workflow table is checked at load to cover exactly the workflows it should.

