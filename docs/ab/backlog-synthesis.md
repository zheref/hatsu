# A/B evidence — `backlog-synthesis` (zheref/hatsu#2)

Port of `claude/skills/backlog-synthesis/SKILL.md`: group a repository's open backlog by rule/
clause, machinery file or root cause, propose a consolidation plan as an iterable Artifact, and on
approval file one consolidated issue, attach the originals as sub-issues, and close them with a
reference. Old mechanics: no dedicated script existed for this skill either (same premise as
`file`'s own A/B doc) — the fetch, the sub-issue attach (`gh api
repos/{owner}/{repo}/issues/{n}/sub_issues`, hand-resolving the child's id first), and the
close-with-comment choreography were **prose rules the agent executed by hand**, with no verb
guarding an open PR before a close. New mechanics: `nen backlog fetch`, `nen issue search`, `nen
issue open-pr-check`, `nen issue file`, `nen issue attach-sub`, `nen issue consolidate-close`, `nen
ref format`, `nen repo resolve`, `nen stop`.

Run: 2026-09-01 (local clock; today's date per session context). `nen` `0.1.0`
(`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`). `gh` authenticated as `zheref`. Target
for every read-only run: the live `zheref/bankai-core` backlog, `--repo` pointed at the local
`bankai-core` checkout (working tree clean, read-only throughout — nothing was written back to
it). **Per this build's explicit constraint (stricter than the shared brief's general one):
`nen issue attach-sub` and `nen issue consolidate-close` were never run against `zheref/bankai-core`
at all, dry-run or not.** Their refusal-before-mutation shape was instead verified against a
repository that does not exist (§ 2.4–2.5) — a target where no call, however shaped, can ever
reach a real write — and their choreography against `--help`'s own contract text. A dry-run probe
against a real repository (`zheref/hatsu`, using its own two open issues) was attempted for
`attach-sub` and refused by the session's own auto-mode classifier before it ran at all (§ 2.6);
recorded as residue, not routed around.

Verdict parity between `nen pr ready` and `pr_ready_gate.sh` was already proven across the live
estate by nen's shadow window (`docs/evidence/shadow-window-p1.md` in zheref/nen); this skill uses
no readiness verb, so that citation is inherited context, not independently re-proven here.

---

## 1. Command mapping table

| # | Old (prose / hand-run `gh`) | New (`nen`) |
|---|---|---|
| 1 | "The repo is `bankai-core`" — hardcoded, no resolution step existed at all | `nen repo resolve <token>` / `nen repo resolve` (no token, cwd origin) — the same mechanism [`hatsu:file`](../../claude/skills/file/SKILL.md) § 1 and [`hatsu:backlog-state`](../../claude/skills/backlog-state/SKILL.md) § 1 already adopt; genuinely NEW here because the old skill never targeted anything but one fixed repo |
| 2 | "Fetch every open issue matching the filter … no silent caps … state the resolved set" — the agent ran `gh issue list --search "label:bankai:severity/high" --json ...` paged by hand, tracking whether a page came back short | `nen backlog fetch --repo-slug <owner/name>` (no `--limit`) — paginated automatically until a short page, `truncated` reported explicitly rather than inferred (verified live, § 2.1: 88 rows, `truncated: false`) |
| 3 | Grouping signals 1–2 ("same clause", "same machinery file") confirmed by re-reading bodies and cross-referencing by eye, one candidate pair at a time | `nen issue search --files <f> --rule-ids <r> --lane-labels <l>` — the same verb `file` § 3 uses for duplicates, turned toward clustering: one call surfaces every open issue sharing a file, clause or lane (verified live, § 2.2 — a 22-row raw pass on `scripts/pr_ready_gate.sh` + `CON-32` narrowed to a real 7-member cluster) |
| 4 | "An issue with an OPEN PR is `link-only`" — checked, per the old skill's own prose, by reading each candidate's timeline by eye for a referencing PR | `nen issue open-pr-check --target <o/n> --issues n,n,n` — one call, every open PR fetched once and matched against every candidate (verified live against a real cluster, § 2.3: flagged exactly the one member — `#877` — that carries an open PR, `#925`) |
| 5 | Sub-issue attach: `gh api repos/{owner}/{repo}/issues/{n}/sub_issues`, one call per child, with the agent responsible for remembering the API takes the child's **id**, not its number, and resolving it first by a separate read | `nen issue attach-sub --target <o/n> --parent <n> --children 1,2` — resolves each child's id internally before writing; the id-vs-number distinction is now the verb's own job (verified live against a repo that cannot resolve at all, § 2.4: it fails at exactly the id-resolution read, before any write is attempted) |
| 6 | Close-with-comment: `gh issue close <n> --comment "<text naming the consolidated issue and which section absorbed it>"`, run once per member, in a hand-maintained order (file, then attach, then close) | `nen issue consolidate-close --target <o/n> --parent <n> --children 1,2 --repo <path> --severity-family <family>` — the whole file→attach→close ordering in one call, re-running the open-PR guard **before the attach**, refusing the entire call (not the first failure) if anything is blocked (§ 2.5; see § 4 finding 1 for what this call does **not** let the caller customize, and § 4 finding 5 for `--severity-family`'s undocumented default) |
| 7 | Label union (severity = highest, lanes = union) — computed by hand, reading every member's labels and taking the max/union manually | `nen issue consolidate-close --severity-family <family>` computes and reports the label union and severity maximum from the children's own current labels as part of the same call (contract-inspected only, § 3 — never observed live) — **`--severity-family` is required in practice despite defaulting silently to `""`, see § 4 finding 5** |
| 8 | Object notation, hand-typed `<CODE>-IS-#<N>` | `nen ref format --code <CODE> --kind IS --number <n> [--state <s>] --repo <path>` (verified live, § 2.6 — including a finding that `--repo` is required and accepted despite not appearing in the printed usage line) |
| 9 | The `G5` stop banner: `scripts/gate_stop.sh --gate G5` | `nen stop --who Kurapika --gate G5 efforts.md` — same renderer family already adopted by `pr-state`'s and `file`'s sibling ports; not separately re-verified here beyond `nen stop --help` |
| 10 | Body/comments/sub-issue-graph fetch for the grouping read — `gh issue view <n> --json body,comments` per issue, by hand | **No `nen` verb replaces this.** `nen backlog fetch`'s row schema is thin by design (same class of gap `backlog-state`'s own doc records for PR-level detail) — residue, § 3 |

**Count.** Before: **7** steps the agent had to perform manually with no verb computing or
checking any of them (rows 1–7: hardcoding a target with no resolution, paging a search by hand,
eyeballing every convergence signal, eyeballing every open-PR risk, hand-resolving a child's id
before attach, hand-ordering file→attach→close with no guard, and computing a label union/severity
max by hand). After: **1** step still fully manual by necessity (row 10, no verb exists for
bulk body/comment fetch) and **1** step (row 7, the label union/severity computation) verified only
by contract rather than by a successful live run, per this build's own stricter no-mutation
constraint against the one real repository large enough to test it meaningfully. Every other
deterministic step (rows 1–6, 8–9) is now one `nen` call whose exit code and printed report is the
whole computation.

---

## 2. Live A/B transcript (read-only)

All against the real `zheref/bankai-core` backlog unless stated otherwise. `GH_TOKEN` exported
before every run.

### 2.1 — `nen backlog fetch`, uncapped, real counts

```
$ nen backlog fetch --repo-slug zheref/bankai-core --json
```

```json
{
  "repo": "zheref/bankai-core",
  "truncated": false,
  "rows": [ /* 88 entries */ ]
}
```

Reshaped by severity label (off each row's own `labels[]`, no verb needed for this one-pass
count): **88 open issues; 7 `high`, 60 `medium`, 14 `low`, 7 untriaged (no `bankai:severity/*`
label), 0 `critical`.** No `--limit` was passed and `truncated` reports `false` — a complete,
uncapped fetch, exactly § 2's own requirement.

### 2.2 — `nen issue search`, a real clustering signal

```
$ nen issue search --repo <bankai-core checkout> --target zheref/bankai-core \
    --subject "pr_ready_gate readiness" --files scripts/pr_ready_gate.sh \
    --rule-ids CON-32 --lane-labels bankai:agent/kisuke
```

```
[subject-open] ... no candidates
[subject-recently-closed] ... query: pr_ready_gate readiness closed:>=2026-06-04
  #880  CLOSED  pr_ready_gate.sh claims to be "the ONE place a CON-32 readiness claim is decided" ...
  #910  CLOSED  A local session measures the stale plugin cache and reports it as `main` ...
  #571  CLOSED  [Definitions] Bind every readiness asker ... to pr_ready_gate.sh --verdict N ...
[files-and-rule-ids] query: "scripts/pr_ready_gate.sh" OR "CON-32"
  #912 #771 #791 #914 #877 #936 #763 #710 #903 #675 #937 #918 #799 #538 #539 #677 #337 #643 #535
       #587 #878 #634  (22 rows total)
[lane] query: label:"bankai:agent/kisuke"
  #939 #938 #935 #933 #929 #922 #921 #920 #918 #917 #915 #914 #878 #877 ...  (43 rows total)
```

**Regression caught in review: the row count printed above the count itself was wrong.** 22 issue
numbers are listed on the `files-and-rule-ids` line, not 23 — a hand-recount confirms 22
(`nen`'s own output has no built-in row-count line; the parenthetical count is added by whoever
transcribes the run, and it was mis-added here by one). Fixed above.

**Re-run live for this fix, and the set has genuinely moved — a point-in-time disclosure, not
another miscount.** Re-running the identical query today returns **24** rows on
`files-and-rule-ids`, not 22: two issues absent from the original capture now match —
`#935` ("[Machinery] Roll provenance-on-stderr + plugin-cache guard out to the rest of the
verification script family") and `#938` ("port pr_ready_gate.sh's plugin-cache guard classification
into cli/src/ports/pr_ready_gate.ts (BC-IS-#733 plane parity)") — both newly filed/labelled against
`scripts/pr_ready_gate.sh`/`CON-32` since the original run, both also present in the `lane` pass.
This does not change the seven-member cluster this section's own analysis is built on (`#912, #877,
#914, #791, #538, #539, #771` are unaffected — still present, still the same seven), but it is
recorded here because a synthesis run against a live backlog should expect exactly this kind of
drift between the plan's fetch and its execution (`SKILL.md` § 5 step 2's re-guard exists for the
same reason, one layer over).

**Real grouping signal, not a fabricated example.** Cross-referencing the `files-and-rule-ids` pass
against the `lane` pass by hand narrows to a genuine same-file/same-clause/same-lane cluster:
`#912, #877, #914, #791, #538, #539, #771` all touch `scripts/pr_ready_gate.sh` and/or cite
`CON-32`, and all six that carry a lane label carry `bankai:agent/kisuke`. This is exactly signal 1
+ signal 2 from § 3 of the ported skill, produced by one call rather than a manual re-read of 88
issue bodies.

### 2.3 — `nen issue open-pr-check`, the same cluster, real open-PR result

```
$ nen issue open-pr-check --repo <bankai-core checkout> --target zheref/bankai-core \
    --issues 912,771,791,914,877,538,539
```

```
open pull requests scanned: 2
  #912: no open PR
  #771: no open PR
  #791: no open PR
  #914: no open PR
  #877: OPEN PR #925 -- closing this orphans work in flight
  #538: no open PR
  #539: no open PR
```
exit code: `1`.

Applied to the ported skill's own § 5 partition: of this seven-member cluster, **six** would go to
`closeSet` and **one** (`#877`) to `linkOnlySet` — exactly the shape § 5's mixed-group handling
exists for. Also confirmed: this call needed **no `--repo`** at all — re-run from the `hatsu`
worktree (`nen issue open-pr-check --target zheref/bankai-core --issues 877,538`, no `--repo`, no
local taxonomy file) produced the identical result. Matches `file`'s own finding for `issue search`
(`docs/ab/file.md` § 2.2): the read-only issue verbs hit the GitHub API directly and never consult
a local `schemas/*.json`.

### 2.4 — `nen issue attach-sub`, refusal shape against a repository that cannot exist

```
$ nen issue attach-sub --target zheref/this-repo-does-not-exist-xyz123 --parent 1 --children 2,3 --json
```

```json
{
  "attached": [],
  "failed": [
    { "child": 2, "reason": "could not read zheref/this-repo-does-not-exist-xyz123#2: gh: Not Found (HTTP 404)" },
    { "child": 3, "reason": "could not read zheref/this-repo-does-not-exist-xyz123#3: gh: Not Found (HTTP 404)" }
  ],
  "fallbackTaskList": null,
  "log": []
}
```
exit code: `1`, identically with and without `--dry-run` (both runs produced byte-identical
output — confirmed by running the call twice, once with `--dry-run` and once without).

**This is the id-not-number resolution behaviour, caught in the act.** The failure text —
`could not read ...#2` — is the verb attempting to **read** child `#2` first, to resolve its
GraphQL node id (the sub-issues API takes an id, not a number), and failing there, **before** any
write to the (nonexistent) sub-issues endpoint is ever attempted. Nothing is written, because
nothing could have been: the repository itself does not exist, so every code path — dry-run or
not — dies at the same read. The `fallbackTaskList: null` field in the JSON confirms the verb's
own schema carries a fallback slot (§ 3, § 4 finding 3 for what remains unverified about it).

### 2.5 — `nen issue consolidate-close`, same refusal class

```
$ nen issue consolidate-close --target zheref/this-repo-does-not-exist-xyz123 --parent 1 \
    --children 2,3 --repo <bankai-core checkout> --dry-run
nen issue: could not read zheref/this-repo-does-not-exist-xyz123#2: gh: Not Found (HTTP 404)
```
exit code: `1`.

Same shape as § 2.4: the read-before-write guard fires before `--repo`'s own `schemas/labels.json`
is ever consulted.

**Regression caught in review: the ordering originally stated here was wrong about where the
open-PR guard sits.** Read from `nen` `v0.1.0`'s own source (`src/issue/command.ts`'s `consolidate`
function): the real order is `--repo`'s taxonomy loaded → every child resolved/read (as part of
`planConsolidation`, which also computes the label union/severity) → **the open-PR guard, which can
refuse the entire call right here** → only then `attachSub` (the sub-issue writes) → only then the
per-child closes. **The guard runs before the attach, not immediately before the close** — stronger
than "attach, then guard, then close": a child still carrying an open PR at this point is refused
before it is ever attached to the consolidated issue's graph, not merely left unclosed after being
attached. (`SKILL.md` § 5 step 3 previously described the weaker ordering; corrected there too.)

### 2.6 — `nen ref format`, real objects, and a documentation gap

```
$ nen ref format --code BC --kind IS --number 877 --repo <bankai-core checkout>
📄 BC-IS-#877
$ nen ref format --code BC --kind PR --number 925 --state open --repo <bankai-core checkout>
🔀 BC-PR-#925
```

Both correct against the real objects (`#877`'s open PR is `#925`, per § 2.3). **Finding**:
`nen ref --help`'s own printed usage line (`nen ref format --code <CODE> --kind <IS|PR> --number
<N> [--state <s>] [--url <u>] [--no-glyphs]`) does not list `--repo` at all — yet the call
**requires** it. Reproduced from the `hatsu` worktree, which carries no `schemas/repos.json` of its
own:

```
$ nen ref format --code BC --kind IS --number 877
nen ref: C:\...\hatsu\schemas\repos.json: no such file. Nen reads this repository's taxonomy from
'schemas/repos.json' in the TARGET repo and has no built-in copy to fall back on ... Point it at a
checkout that carries the file with --repo <path>, or add the file.
```
exit code: `1`. Same undocumented-but-required-and-accepted `--repo` pattern `file`'s own A/B doc
found for `nen label apply` (`docs/ab/file.md` § 2.7) — recorded here as a minor documentation gap
against the same family of verbs, not re-filed as a new class of finding.

### 2.7 — attempted dry-run against a real repository: blocked by the session's own classifier

```
$ nen issue attach-sub --target zheref/hatsu --parent 3 --children 1 --dry-run --json
```
Result: refused by the Claude Code auto-mode classifier before the process ran at all —
*"Permission for this action was denied ... Blocked by classifier."* No output was produced; the
call never reached `nen`. This is the same experience `file`'s own A/B doc records for `nen label
apply` targeting `zheref/hatsu` mid-session (`docs/ab/file.md` § 3, "the auto-mode classifier
refused even a no-`--run` dry invocation ... blocked before execution"). Not retried, not routed
around — recorded as residue (§ 3) rather than a finding against the binary, since the binary
itself never ran.

---

## 3. Residue

- **Per-issue body/comment/sub-issue-graph fetch has no `nen` verb.** `nen backlog fetch`'s row
  schema is `{issueNumber, title, labels, prNumbers[], createdAt}` — no body, no comments, no
  sub-issue relationships. § 2's grouping read still needs `gh issue view <n> --json
  body,comments` per candidate, same class of gap `backlog-state`'s own A/B doc records for
  PR-level detail (`docs/ab/backlog-state.md` § 3).
- **`nen issue consolidate-close`'s label-union/severity-max computation was never observed
  live.** Every live attempt against a real, non-fictional target either targeted a repository
  this build must never write to (`bankai-core`, forbidden outright by this build's own
  instructions) or was refused by the session's own auto-mode classifier before it ran
  (§ 2.7, against `zheref/hatsu`). What is verified is the contract text (`nen issue --help`,
  quoted in § 1 row 7 and § 2.5) and the read-before-write ordering that precedes it
  (§ 2.4–2.5). The computation itself — which labels, in what precedence, become the "maximum" —
  is contract-inspection only, per the shared brief's explicit allowance for this exact situation.
  **What was fully verified from source, without a live run**: the computation only works at all
  when `--severity-family` is supplied — omitted, it silently breaks both the union and the
  severity-max (§ 4 finding 5), which is not a live-observation gap but a documented, source-proven
  behaviour.
- **The comment-posting gap `file`'s own A/B doc already found (`docs/ab/file.md` § 3, finding 1)
  reappears here, sharper.** Neither `nen issue attach-sub` nor `nen issue consolidate-close`
  exposes a `--comment`/`--body` flag of any kind (confirmed against the full `--help` text, § 1's
  table). The old skill's own requirement — "close each member with a comment naming the
  consolidated issue **and which section absorbed it**" — has no channel through either
  purpose-built verb. This is not a gap in a *general* comment primitive (as `file`'s finding was)
  but a gap in the *specific* choreography verbs built for exactly this skill's use case — see
  § 4 finding 1.
- **Judgment kept, per the shared brief's boundary list:** what counts as a genuine group vs a
  shelf; severity assessment and its one-line basis; the drafted consolidated title/body; the
  `DECIDE` options and the ⭐ recommendation; whether a cluster crosses authority levels and needs
  a chore instead of one PR.
- **No repo-specific rule ID baked into the skill text.** Like `file`, this port generalises the
  *mechanism* (any target repo's own taxonomy, registry and canon, read at run time) rather than
  hardcoding `bankai-core`'s own `CON-{n}` numbering — the ported skill cites `CON-25`/`CON-9` as
  hatsu's own constitution's rule IDs (the same convention `kurapika.md` and `file`'s port already
  use for hatsu), not as a literal copy of bankai-core's canon.

---

## 4. Findings (report separately, do not route around)

1. **Neither `nen issue attach-sub` nor `nen issue consolidate-close` accepts a caller-supplied
   close/attach comment.** `consolidate-close` posts only a fixed `"Consolidated into #N."`
   (`nen` `v0.1.0` `src/issue/subissue.ts`'s `consolidateClose`, the literal comment text). The old
   skill's § 5 step 4 required naming, per member, "which section absorbed it" — there is no flag
   on either verb to carry that text through. **Compensating step added to `SKILL.md` § 5** (after
   step 3): post one `gh issue comment <child#> --body "<section that absorbed it>"` per closed
   child, immediately after `consolidate-close` returns — this stays a raw `gh` call by necessity,
   the same class of gap `file`'s own A/B doc already found for a general comment primitive, now
   confirmed absent from these two purpose-built verbs specifically. Worth filing against `nen`
   separately: a `--comment`/`--body-template` on `consolidate-close` would retire this last
   hand-authored call in the skill's execution phase.
2. **`nen ref format`'s printed usage line omits a flag it requires.** `--repo <path>` is not in
   `nen ref --help`'s own usage string but is both accepted and necessary (§ 2.6) — a caller
   reading only the printed help would hit the taxonomy-missing refusal on the first real attempt.
   Same class of gap as `nen label apply`'s missing `--repo` in the pre-fix `file` port
   (`docs/ab/file.md` § 2.7), now seen on a second, unrelated verb family — worth a documentation
   pass across `nen ref`, and possibly a wider sweep of other verbs' printed usage lines against
   their actual accepted flags.
3. **`fallbackTaskList` is DETECTED, never PERFORMED — confirmed from source, not merely
   inferred.** `nen` `v0.1.0`'s `src/issue/subissue.ts` header states this outright ("FALLBACK IS
   DETECTED, NOT PERFORMED... it does not rewrite a body on its own"). The JSON schema (§ 2.4)
   carries the field, but every live failure this port could safely trigger was a 404-class "the
   repository does not exist" failure, not the "the repository exists but its sub-issues API is
   unavailable" condition the fallback is for, so the condition itself was never observed live. The
   source is unambiguous regardless: **relaying the field is not enough — `SKILL.md` § 5 step 4 now
   requires the skill itself to perform the fallback write** (`gh issue edit` appending the returned
   task-list lines to the parent's body) and re-verify it landed, whenever `fallbackTaskList` comes
   back non-null. No repository available to this port's safe testing surface (a nonexistent repo,
   or a real repo this build must not mutate) could exercise the condition live; flagged for
   whoever next touches a repository old enough, or configured oddly enough, to lack native
   sub-issues support, to confirm the write-it-yourself instruction against a real firing.
4. **No missing verb found among the read-only half.** `nen backlog fetch`, `nen issue search`,
   `nen issue open-pr-check` and `nen ref format` between them cover every deterministic step this
   skill's planning phase (§§ 2–4) needs, and all four were run live against the real
   `zheref/bankai-core` backlog with real, checkable results (§§ 2.1–2.3, 2.6).
5. **`nen issue consolidate-close`'s `--severity-family` is undocumented, and silently wrong when
   omitted — proven from source, not inferred.** Neither `nen issue consolidate-close --help` nor
   `nen issue --help` mentions `--severity-family` anywhere in their printed text, yet the flag is
   declared and accepted (`nen` `v0.1.0` `src/issue/command.ts`'s `flags.values` list, and its
   `consolidate` function reads `context.args.values["severity-family"] ?? ""` at line 346).
   Omitting it defaults the family to `""`, and `src/issue/subissue.ts`'s `planConsolidation`
   (lines 213–238) then never matches any real severity label's `namespace:family` (e.g.
   `bankai:severity`) against that empty string — so **severity-max never fires** (the consolidated
   issue is filed with no severity) **and every severity label folds into the general label union
   instead of being excluded from it** (the consolidated issue can end up carrying several
   contradictory severities at once). `SKILL.md` § 5 step 3 now states `--severity-family
   bankai:severity` explicitly in the command and documents this failure mode in full; worth filing
   against `nen` separately, both for the missing `--help` text and for whether an empty
   `--severity-family` should instead refuse the call outright rather than silently computing a
   wrong union.
