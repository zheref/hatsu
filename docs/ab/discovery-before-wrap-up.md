# A/B evidence — a blocker captured before any wrap-up

[`docs/DISCOVERY.md`](../DISCOVERY.md) § *A blocker found while executing — captured before any
wrap-up* (zheref/hatsu#508, AC-8 and SC-1/SC-2), with [`docs/WORKFLOW.md`](../WORKFLOW.md) § *Host
workload budget*, *Confirmed quiescence*.

## Dated verification, 2026-11-03 — eight bounded scenarios walked through the canon

**Method.** Each scenario is a starting state taken through the section's five steps in order, to the
one outcome the canon names. This is a desk walk-through of the prose, not an executed run: no heavy
workload was launched, and no host was measured (admission, cancellation and receipts stay owed to
zheref/nen#536, zheref/nen#538 and zheref/nen#540). Scenarios 1, 2 and 5 restate the 2026-10-26/27
records on zheref/hatsu#508 and its comments, sanitized; the rest are constructed. The **class** column
is the distinction AC-8 asks for.

| # | Class | State | Walk | Outcome |
|---|---|---|---|---|
| 1 | interpretation error | A delegate's process-group read before a dependency install returns `operation not permitted`; the install runs anyway, exit `0`. Later reads succeed. | Step 1: the failed read stops the launch; the install should not have run. The later reads are no evidence for it. Step 4: ownership of that install is uncertain; no id is invented. | The coordinator does **not** end the run as complete: light work and the capture continue; the run is held on the blocker (step 5), not wrapped up. |
| 2 | recoverable sandbox failure | The same read fails as an **unreviewed** sandbox failure, before any launch; the host exposes a review route the task already covers. | Step 1: retried once through that route; admitted, the read returns the shell's group equal to `$$`. | The workload starts with its recorded id. No issue is owed: recovery cleared it. |
| 3 | actual review rejection | The supported review route returns a rejection with a stated reason. | Step 1: the rejection and reason are quoted; no other route is tried. Step 2: the blocker is reconciled and captured. | The workload never starts; the run continues independent work and reports the capture's result before any wrap-up. |
| 4 | unresolved process ownership | A heavy lane ran; its parent was cancelled and the descendants are uncertain. | WORKFLOW's overload rule: no new heavy launch; step 4: safeguards hold, no id invented. Step 2: the ownership gap is captured against its machinery owner (zheref/nen#538), `updated` with new evidence only if material. | Held, the listing or its absence named; cleanup is not offered as the next step. |
| 5 | filing failure | A provider quota exhausts the REST bucket mid-reconciliation (HTTP 403, reset time known). | Step 3: a pending filing record names the failed pass, owner candidates, evidence and the reset check; no draft is called filed. After the reset, all four passes rerun. | `pending`, then `updated` on the existing owner; no duplicate; the batch objective kept throughout. |
| 6 | existing duplicate | A blocker's root cause and owner match an open issue whose comments already carry the same evidence. | Step 2: four passes, bodies and comments read; materially identical. | `unchanged` — no write; the canonical URL is named in the held report. |
| 7 | successful recovery | A worktree write fails unreviewed; the review route admits it; the effort completes. | Step 1 clears it; steps 2–5 do not apply. | No capture, no hold; the run ends normally and the wrap-up picker is asked under its own prerequisites. |
| 8 | premature cleanup | A run ends with one effort parked on an uncaptured blocker; the coordinator is about to ask the wrap-up picker. | Step 5: the picker waits on the capture; step 2 runs first and reaches `created` with its classification and routing rows. | The wrap-up picker comes only after the blocker's URL (or its pending record) is in the report. |

**SC-1.** Eight scenarios; none offers cleanup before an actionable blocker is captured or its pending
record written (scenarios 1, 3, 4, 5 and 8 each hold the picker; 2 and 7 owe no capture; 6 names the
existing URL). **SC-2.** The one newly created blocker (scenario 8) carries both classification axes
and its `model/<line>` routing per DISCOVERY § *Authority and convergence*; scenario 5's pending
record names its publication prerequisite (the reset) instead.
