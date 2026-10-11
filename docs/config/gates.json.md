# `nen/gates.json` — who reviews, what approves, and which checks are watched

> **Lives in** the consumer repository · **Written by** the maintainer by hand; `hatsu:tenkai` routes the initial file to `nen scaffold init` and writes none of its values, and a ruling that changes what readiness reads lands here through [WORKFLOW § 4](../WORKFLOW.md) step 3 at the repository's own gate · **Validated by** the `nen/gates.json` row of `nen schema check --repo .` for nen's keys, and the `gates/check-exclusions` and `gates/reviewer-fallback` rows of `scripts/tenkai_adopt.sh diagnose` for Hatsu's keys · **Authority** [`docs/GATE-CONFIGURATION.md`](../GATE-CONFIGURATION.md)

## What it decides

`nen pr ready` evaluates five conjuncts and this file supplies the reviewer half of them: which logins count as a review round (`CON-32(b)`), whether an `APPROVED` review is also required (`CON-16`), how many rounds a run may ask for, which reported checks a maintainer has ruled out of the verdict, and which reviewer stands in when another runs out of credits. Every skill that reads readiness reads it through the verb: `hatsu:pr-state` § 2 quotes the verdict, `hatsu:sharingan` § 6 requests the owed rounds inside its bounds, `hatsu:en` holds the PR to Ready, `hatsu:getsuga` § 6 reads its own release-proposal PR the same way, and `hatsu:tenkai` § 3 diagnoses the two Hatsu-owned keys for drift. The adopted readiness workflow passes `--gates "$PWD/.trusted/nen/gates.json"`, the copy on the base branch, so an edit here governs other pull requests only once it is merged (GATE-CONFIGURATION § 5).

When the file is wrong the failure is quiet: a reviewer pattern that never matches owes a round at every head and the gate never closes; a pattern that is too broad lets any comment satisfy a round; a wrong `head_ref_prefixes` classifies every delivery PR as not yours; an empty `default_approvers` without `approval_policy` is refused by the loader; a check excluded in chat rather than here reads red on every verdict. Copying `zheref/hatsu`'s file is the mistake GATE-CONFIGURATION § 1 exists to prevent: the identities in it are Hatsu's.

## Keys

### Top level

The file is one JSON object. Keys whose name starts with `$` are metadata nen preserves and never reads (`$comment`, `$check_exclusions`).

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `version` | integer | `1` · required | the gates schema version | `nen schema check`, `nen pr ready` |

### `reviewers[]`

Who counts as a review round. One entry per identity, bot or human, declared the same way. Names declared here are what `base_reviewers`, `reviewer_fallback.chain` and `round_quorum.any_of` refer to.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `name` | string | a short identity (`copilot`, `bugbot`) · required | the handle the other keys use | `nen pr ready`; `pr-state`, `sharingan`, `en`, `getsuga` through it |
| `login_pattern` | `{pattern, ignoreCase}` | an anchored regex over the bot's exact logins · required | which GitHub login's review is this reviewer's round | `nen pr ready` (`CON-32(b)`) |
| `round_check_pattern` | `{pattern, ignoreCase}` | optional; absent for a reviewer that posts reviews | the check whose `SUCCESS` run is the round, for a bot that reviews as a check | `nen pr ready`; counted by `round_quorum` |
| `bounded_policy_exempt` | boolean | optional | a reviewer nothing re-requests after a push, so only a pending request owes a round | `nen pr ready` under the `bounded` policy |
| `review_check_pattern`, `enrolment_check_pattern`, `approves_when_posted_at_head`, `delivery_holistic_pass` | pattern objects, booleans | optional; present in [`contracts/reference.gates.json`](../../contracts/reference.gates.json) | nen's per-reviewer options for check-shaped reviewers; their semantics are nen's and are not restated here | `nen pr ready` |

> A `round_quorum` member's `login_pattern` and `round_check_pattern` must be anchored (`^…$`) and bot-only: one member's round covers the group, so a broad pattern lets any matching login satisfy the whole quorum (GATE-CONFIGURATION § 3, *round_quorum*).

### `approval_policy`

The key that makes an empty approval set legal, load-bearing in both directions. Catalogue id `gates.approval_policy` ([`contracts/config-catalogue.json`](../../contracts/config-catalogue.json)).

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `approval_policy` | string | `required` \| `review-round-only` · no default: absent with an empty `default_approvers` is refused by pointer | whether readiness needs an `APPROVED` review from `default_approvers`, or only a completed reviewer round | `nen pr ready`; `sharingan`, `en` |

### `default_approvers[]` and `base_reviewers[]`

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `default_approvers` | string[] | logins; non-empty under `required`, deliberately empty and legal under `review-round-only` | whose `APPROVED` review satisfies the approve limb | `nen pr ready` (`CON-16`) |
| `base_reviewers` | string[] | names from `reviewers[]` | the identities a new PR requests | `nen pr request-reviews`; `hatsu:shibari`, `sharingan` § 6 |

### `delivery`

Which pull requests are the repository's own delivery branches, so the gate can tell them from everything else.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `author_pattern` | `{pattern, ignoreCase}` | the maintainer's login, anchored | who authors a delivery PR | `nen pr ready` |
| `head_ref_prefixes` | string[] | the prefixes `branch.template` in `nen/workflow.json` produces | which head refs are delivery branches | `nen pr ready` |
| `labels` | string[] | `[]` when the repository has no delivery label | labels that identify a delivery PR | `nen pr ready` |

### `dependabot_carve_out`

Optional. A dependency-bump PR has its review rounds cleared only once the named check contexts have reported. Omit the block entirely to decline the carve-out: an absent block is a decision, an empty one is a hole.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `author_pattern` | `{pattern, ignoreCase}` | `^dependabot(\[bot\])?$` | the bot author the carve-out applies to | `nen pr ready` |
| `satisfied_by_context` | string[] | non-empty; an empty list is refused by nen | the check contexts whose report clears the rounds | `nen pr ready`; `pr-state` names it beside the verdict |

### `round_policy`

Two owners in one object, per field. `stallMinutes` is nen's; `minRounds` and `maxRounds` are Hatsu's own keys, preserved as raw data by `nen schema check`, with their canon default in [`contracts/round_policy.default.json`](../../contracts/round_policy.default.json).

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `stallMinutes` | integer | nen's built-in default; Hatsu's file says `30` | a pending review request older than this reads `not-ready: reviewer round stalled` | `nen pr ready`; `en` § 6 |
| `minRounds` (N) | non-negative integer | `1` from the canon default | once N rounds stand resolved, no further round is requested | `sharingan` § 6; `en` |
| `maxRounds` (M) | non-negative integer, N ≤ M | `3` from the canon default | the request ceiling; M requested with fewer than N resolved is the reported blocker, quoted from `nen pr ready --explain` | `sharingan` § 6; `en` |

### `check_exclusions[]`

Hatsu's own key (zheref/hatsu#104): the one declared home of a maintainer's ruling that a named check is not watched. An empty array is a decision. Every live row becomes one argv element of `nen pr ready --exclude-check`.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `name` | string | the check exactly as the rollup reports it; letters, digits, spaces and `. _ / ( ) -` only, no comma, quote, shell metacharacter or control byte | the check left out of `CON-32(a)` | `pr-state` § 2 owns the rule; `sharingan`, `en`, `getsuga` through `en` |
| `reason` | string | free text | why | the report |
| `ruled` | `YYYY-MM-DD` | not in the future | when the ruling was made | `tenkai_adopt.sh diagnose` |
| `until` | `YYYY-MM-DD` or `condition: <what lifts it>` | a near-miss date is refused, never read as a condition | when the ruling lapses; a condition row is re-examined every 90 days from `ruled` | `tenkai_adopt.sh diagnose` |

A row that cannot be passed safely is `drift` at the declaration and is never put on the call. An empty rollup after exclusion is not-ready by nen's own rule.

### `reviewer_fallback`

Hatsu's own key (the ruling of 2026-09-29). The row, not the behaviour: the behaviour is [`docs/PROCESS.md`](../PROCESS.md) § *Reviewer rounds and review threads*, *The fallback chain*. nen reads neither this key nor `check_exclusions` (zheref/nen#275).

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `chain` | string[] | reviewer names in fallback order; a step `reviewers[]` does not carry is passed over | who is requested when the one before is exhausted | `sharingan` § 6; `en` § 6; `tenkai` (`gates/reviewer-fallback`) |
| `terminal` | string | `hanten` · the only admissible value | the one non-reviewer at the end: the local `hatsu:hanten` rounds, never requested | `sharingan`, `en`, `tenkai` |
| `exhausted[]` | `{reviewer, reason, ruled, until}` | shaped as `check_exclusions` rows one key over; live only while not lapsed | a reviewer whose round will not arrive | `sharingan`, `en` § 6 (the hold ends, the verdict is quoted with the exhaustion line) |

### `round_quorum`

nen's key (from nen `0.17`; the rulings of 2026-09-29 and 2026-10-04). At least `minimum` of `any_of` must have a round; a met quorum fulfils the owed round of an unavailable member, never one whose round-check run at head is still in flight.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `any_of` | string[] | every name a `reviewers[]` entry; no duplicates | the group one bot round satisfies | `nen pr ready` row 4 |
| `minimum` | integer | `1` to the group's size | how many members must have a round | `nen pr ready` row 4 |

## Example

Illustrative, for a plain product repository with one automated reviewer and a solo maintainer. Replace the login and the branch prefix with the ones your repository actually produces.

```json
{
  "version": 1,
  "reviewers": [
    {
      "name": "copilot",
      "login_pattern": { "pattern": "^(copilot|copilot-pull-request-reviewer(\\[bot\\])?)$", "ignoreCase": true }
    }
  ],
  "approval_policy": "review-round-only",
  "default_approvers": [],
  "base_reviewers": ["copilot"],
  "delivery": {
    "author_pattern": { "pattern": "^<your-login>$", "ignoreCase": true },
    "head_ref_prefixes": ["<your-branch-prefix>/"],
    "labels": []
  },
  "round_policy": { "stallMinutes": 30, "minRounds": 1, "maxRounds": 3 },
  "check_exclusions": [],
  "reviewer_fallback": { "chain": ["copilot"], "terminal": "hanten", "exhausted": [] },
  "round_quorum": { "any_of": ["copilot"], "minimum": 1 }
}
```

Validate it, then read it against a real pull request:

```bash
nen schema check --repo .
nen pr ready <n> --gh-repo <owner/name> --explain
```

Every refusal names the pointer (`at approval_policy`, `at default_approvers`); exit `1` on `pr ready` is not-ready, the common case, not an error.

## When a skill needs a value that is not set

- **The file is absent.** `nen schema check` reports `warn`, and `nen pr ready` cannot judge the repository: without `--gates` or `--reviewers` it refuses with `no reviewer identities`, naming the locations it looked in. `hatsu:tenkai` § 3 routes the file to `nen scaffold init` behind its § 1 confirmation and copies nothing from Hatsu; the content is the maintainer's (GATE-CONFIGURATION § 6). Only the frozen reference repository is read with `--gates "$hatsu_root/contracts/reference.gates.json"` (`pr-state` § 2).
- **A reviewer identity, an approval policy or a check ruling is missing.** `missing-configuration` under [WORKFLOW § 4](../WORKFLOW.md) *Ask, set up, continue*: asked through the surface's picker, written into this file at the repository's gate, re-read by the verb, never carried in prose or a subagent brief (zheref/hatsu#104). The catalogue rows `gates.reviewers` (external: install the reviewer, confirm its login on a test PR) and `gates.approval_policy` (enum) carry the question Tenkai § 6d asks.
- **`round_policy.minRounds` or `.maxRounds` is absent, not a non-negative integer, or N > M.** Per key, `sharingan` § 6 takes the value in `contracts/round_policy.default.json` and names that file as the source; the run never raises a number in-session. `stallMinutes` absent takes nen's own built-in default.
- **`check_exclusions` is absent or `[]`.** Nothing is excluded; `tenkai_adopt.sh diagnose` reads `satisfied`. A lapsed, malformed or unpassable row is `drift`, left off the call, and the maintainer removes or re-rules it.
- **`reviewer_fallback` is absent.** `tenkai` reads `satisfied`, nothing declared; `sharingan` § 6 requests only `base_reviewers`. A chain step with no `reviewers[]` entry is `routed`: declare it once the app is installed.
- **`round_quorum` is absent.** The verdict is nen's without the quorum clause; every declared reviewer's round is owed on its own.
- **`dependabot_carve_out` is absent.** No carve-out; a dependency bump owes the same rounds as any PR.

## Sources

- [`../GATE-CONFIGURATION.md`](../GATE-CONFIGURATION.md): the authority, §§ 1–6
- [`../../nen/gates.json`](../../nen/gates.json): Hatsu's own file and its `$comment` rationale
- [`../../contracts/round_policy.default.json`](../../contracts/round_policy.default.json): the canon default for N and M
- [`../../contracts/reference.gates.json`](../../contracts/reference.gates.json): the frozen reference repository's identity file, with nen's optional per-reviewer keys
- [`../../contracts/config-catalogue.json`](../../contracts/config-catalogue.json): rows `gates.approval_policy`, `gates.reviewers`
- [`../WORKFLOW.md`](../WORKFLOW.md) § 4 *Ask, set up, continue*
- [`../PROCESS.md`](../PROCESS.md) § *Reviewer rounds and review threads*
- [`../../claude/skills/pr-state/SKILL.md`](../../claude/skills/pr-state/SKILL.md) § 2 · [`../../claude/skills/sharingan/SKILL.md`](../../claude/skills/sharingan/SKILL.md) § 6 · [`../../claude/skills/en/SKILL.md`](../../claude/skills/en/SKILL.md) §§ 5–6 · [`../../claude/skills/getsuga/SKILL.md`](../../claude/skills/getsuga/SKILL.md) §§ 3, 6 · [`../../claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) §§ 3, 4a, 6d
- [`../../scripts/tenkai_adopt.sh`](../../scripts/tenkai_adopt.sh): the `gates/check-exclusions` and `gates/reviewer-fallback` items
- [`../../templates/pr-readiness.yml`](../../templates/pr-readiness.yml): the trusted `--gates` path
- `nen schema check --help`, `nen pr ready` as read at the pinned build
