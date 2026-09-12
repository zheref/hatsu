# Discovery protocol

Use this protocol whenever authorized Hatsu work reveals a concrete, reproducible defect, missing
reusable capability, or durable prose/rule gap. It applies in every phase, composite, reviewer,
and resumed session. It is deliberately a short side path: preserve the original objective and
continue it when safe. A finding does not authorize a new build, canon change, release action, or
closure of another effort.

## Capture and ownership

Capture only sanitized, minimum evidence: observed versus expected behavior, a reproducible
condition or stable source/rule reference, affected paths or rule IDs, and any safe temporary
workaround with its removal condition. Do not place credentials, private logs, personal-device
identifiers, or unrelated consumer data in an issue or pending record.

Identify the owner before filing. Hatsu owns its workflow and skill prose; Nen owns shared
deterministic machinery; canon and consumer defects belong to their actual owners. When a local
workaround exposes an upstream gap, record both the workaround and its upstream removal condition.
Independent Hatsu prose and Nen machinery work remain separate, cross-linked issues.

## Reconcile before every write

Run `nen issue search --target <owner/name> --subject <text>` with every available `--files`,
`--rule-ids`, and `--lane-labels` term. Keep its four-pass report: subject/open,
subject/recently-closed, files-and-rule-IDs, and lane. A skipped pass is a skipped pass; an exit
failure means the search was unavailable, never that it found nothing.

Read the bodies **and existing comments** of promising matches and inspect their associated open PRs.
Titles and similarity are only candidate signals. The comments decide whether proposed evidence is
actually new; do not append the same evidence twice. Choose exactly one result:

| Result | Allowed write | When |
| --- | --- | --- |
| `updated` | Material new evidence or acceptance criterion on the same issue | Same root cause, owner, and scope |
| `folded` | Prepared whole-body edit plus an explanatory comment | Compatible nearby scope that one owner and one deliverable can reasonably carry |
| `created` | One narrow issue with owner, evidence, acceptance criteria, and cross-links | Distinct root cause or ownership |
| `unchanged` | None | Existing issue already carries materially identical evidence and scope |
| `pending` | None | Search, taxonomy, credential, network, or write state is unavailable or uncertain |

Use `nen issue comment` for an additive update and `nen issue edit-body` only with the complete
replacement body. `edit-body` replaces every byte; obtain the current body first, then **read it
again immediately before the write and rebase the prepared addition**. Nen has no compare-and-swap
body edit, so this narrows but cannot remove a concurrent-overwrite race; on a detected change,
do not overwrite it and record `pending` for a fresh reconciliation. Do not close, supersede, or
attach existing work through this protocol.
Those actions retain their dedicated guards and human authority.

## Authority and convergence

Standing filing authority permits the capture, reconciliation, and one narrow `created`,
`updated`, or `folded` write above without asking again. The record must state the owner, four-pass
result, inspected issue/comment/PR candidates, selected result, canonical URL if known, and whether
the original work continued or is blocked. It does not carry a severity change, stage or release
label, merge/review vote, implementation of the new work, canon change, publishing, or closure of
an active effort; each remains separately authorized.

There is no claimed atomic idempotency primitive. An orchestrator designates **one writer for each
known effort**; reviewers and parallel workers return evidence only. Before each write, that writer
re-runs the four passes and re-reads the intended issue body and comments. For a create, search
again after any delay or competing-agent report before retrying. Independent sessions can still
create simultaneously between preflight and write: record that residual race honestly. If a later
search finds the duplicate, select the canonical issue, cross-reference it only when material, and
do not close either issue through this protocol. A timeout or unknown response is `pending`, not
proof that no write happened: search and inspect again before attempting any second create.

## Unavailable prerequisites and durable recovery

Nen filing depends on real target metadata and usable tools. Do not invent a repository slug,
label, CLI flag, or successful result when `nen/repos.json`, `nen/labels.json`, credentials,
network, or a supported verb is unavailable. Make a **Pending filing record** in the durable
evidence/report artifact for the current authorized work, with: timestamp, intended owner,
sanitized evidence, affected paths/rules, four-pass attempts and failures, proposed result,
workaround/removal condition, and exact recovery check. Report that record as `pending`.

On a later authorized run, retry the stated prerequisite and rerun all four passes before writing.
One unavailable filing route is not a reason to file another issue about filing. Prepare a
sanitized pending Nen dependency for the orchestrator only when a missing reusable primitive or
metadata prerequisite is concrete, owned by Nen, and itself passes reconciliation; do not propose a
generic lock system. Otherwise retain the pending record and surface the blocker.

## Scenarios

**Constructed — duplicate:** a reviewer reproduces a documented Hatsu rule ambiguity and finds an
open issue with the same rule, owner, and acceptance criterion. It adds only the new reproducible
evidence if material; a later identical report is `unchanged`.

**Constructed — fold:** two Hatsu documentation omissions concern the same skill, owner, and
single proposed edit. The protocol prepares the entire current body plus one checklist item,
uses `nen issue edit-body`, and posts one explanation. A related Nen resolver defect stays a
separate cross-linked issue.

**Live — upstream example:** `zheref/nen#204` records the shared device-resolution gap identified
during authorized Hatsu work. It illustrates upstream ownership and a removal condition; it does
not authorize Hatsu to implement Nen work.

**Constructed — unavailable or uncertain:** taxonomy lookup fails, or a create request times out.
The session stores a sanitized pending record, reports `pending`, and later reruns discovery before
any retry. It neither asserts a clean search nor creates a recursive issue about the failed filing.


## Tracked concurrency dependency

[Nen #205](https://github.com/zheref/nen/issues/205) tracks conflict-aware whole-body writes.
It was reconciled and filed during #49 implementation. Until that primitive has a supported
backend guarantee, an immediately preceding read is not atomic compare-and-swap: serialize known
writers, prefer additive material comments where appropriate, and keep an unsafe fold pending.
Independent simultaneous issue creates likewise have no atomic uniqueness guarantee. If a race
still creates two issues, record both URLs for owner reconciliation without closing either under
standing capture authority. Do not keep retrying creates to compensate for uncertainty.
