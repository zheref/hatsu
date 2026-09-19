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
> the honest shape — the round is real and the merge stays yours. Setting `"required"` and listing
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
