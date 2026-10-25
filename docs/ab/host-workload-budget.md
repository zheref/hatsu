# A/B evidence — the host workload budget

[`docs/WORKFLOW.md`](../WORKFLOW.md) § *Host workload budget — heavy local work* (zheref/hatsu#478,
SC-1). The issue requires no stress reproduction, and none was run.

## Dated verification, 2026-10-25 — four scenarios walked through the canon

**Method.** Each scenario is a starting state taken through the section's rules in order, to the
outcome the canon names. This is a desk walk-through of the prose, not an executed run, with one
exception: scenario 2's listing form was exercised once on a small bounded process tree (one `sleep 4`
orphaned from its shell) on the authoring host, macOS with BSD `ps`, nen 0.26.0. Process ids are
replaced by placeholders. Admission, owned cancellation and pressure reads have no nen verb at this pin
(zheref/nen#536, zheref/nen#538, zheref/nen#539), so no scenario measures the host. Each one checks
that the prose has exactly one outcome for its state.

### 1. Overload during an idle run

**State.** A `futon --idle` run has three effort slots open (`--local-cap 7`). Delegate A holds
`Heavy turn: granted, workers 2` and runs `nen shu coverage`. Its subprocess times out twice.

**Walk.** A repeated subprocess timeout is an overload symptom, and overload is host-wide, so the run
launches nothing heavy. A retries nothing, the smaller retry included, and hands back with what it
saw. The idle run parks A as `parked:g5-host-overload`. Efforts B and C keep authoring with light
checks only, and each parks the same way at its first heavy step. The free slots admit nothing,
because a slot is effort capacity, not host room. No unattended read counts as observed recovery
(zheref/nen#539), so the three stay parked until the maintainer resumes the run.

**Outcome.** No heavy launch after the first symptom. Three parked rows name the symptom, and no
heavy lane reads green.

### 2. Orphan uncertainty after a cancelled parent

**State.** An interactive session. The heavy call's shell recorded its process group by echoing
`$$` before the verb. The harness then cancelled the call, and it is not known whether the runner's
workers exited.

**Walk.** A cancelled run with uncertain descendants is an overload symptom. The session raises a
**G5** stop through `nen stop` and the picker. A later call lists the recorded group with
`ps -A -o pid,ppid,pgid,command`, keeping the rows whose `PGID` is the recorded id. The bounded
exercise showed the form working: right after the parent exited, the listing held one row,
`<pid> 1 <pgid> sleep 4`, the orphan reparented to `1` and still carrying the recorded group. Five
seconds later it held no row. A non-empty listing means quiescence is unconfirmed: nothing is killed
by name, and stopping the rows is the maintainer's, handed over as one `bash` block. Had no id been
recorded, quiescence would be unprovable and the effort would park.

**Outcome.** The report says "stopped" only beside an empty listing. Any kill is the maintainer's
own act, by recorded group.

### 3. Same-host CI overlapping local verification

**State.** A delegate's branch targets a repository whose `nen/workflow.json` declares a `runners`
pool on this host, matched by the machine code in its runner names. The orchestrator holds the heavy
turn for `kotoamatsukami` in another effort.

**Walk.** A push to that target starts CI on this host, so the push itself is heavy. The delegate
holds `Heavy turn: withheld`: it authors, runs light checks and commits, and hands back unpublished,
with the push named pending. When the orchestrator's turn ends, it reads `nen runner inventory
--target <owner/name> --repo <checkout>`. A busy runner holds the turn. A refused inventory is
*unknown*, and the effort parks as `parked:g5-host-ci-unknown` with the refusal quoted. A target with
no `runners` pool has no same-host CI, and its push is light.

**Outcome.** No local heavy work runs beside a same-host CI job, and an unknown inventory never reads
as free.

### 4. Healthy serialized recovery

**State.** After scenario 1 the maintainer says in the session that the desktop is responsive again.
A listing of every recorded group shows no row.

**Walk.** Both retry conditions now hold: confirmed quiescence (the empty listings) and observed
recovery (the maintainer's word, the only read that counts at this version). The orchestrator
re-grants the turn in the run's queue order, heavy lanes a handed-back effort still owes before a new
effort's. A gets `Heavy turn: granted, workers 2` again, or the orchestrator runs A's named lanes
itself in A's worktree. Each phase reports `host admission: no guard (zheref/nen#536); serialized
fallback`. B and C follow one at a time.

**Outcome.** The required verification runs in full, one heavy workload at a time. A pending lane is
reported as pending until it runs.
