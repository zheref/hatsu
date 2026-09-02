# A/B evidence — `pr-state` (zheref/hatsu#2)

Port of `claude/skills/pr-state/SKILL.md`: the deterministic `CON-32` readiness gate, quoted verbatim,
with its conjunct-by-conjunct breakdown. Old mechanics: `REPO=<owner>/<repo> scripts/pr_ready_gate.sh
--verdict <N>`, plus prose the skill file itself carried to reconstruct the per-conjunct table and the
`unevaluated` classification by hand. New mechanics: `nen pr ready <ref> --explain`.

Run: 2026-09-02T00:25Z (UTC). `nen` `0.1.0` (`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`).
`gh` authenticated as `zheref`. Oracle checkout: `zheref/bankai-core` tag `v0.11.3`
(`2269fe723e355dc69bf535ab40f22556e4fe4081`, working tree clean) — `scripts/pr_ready_gate.sh` extracted
read-only via `git show v0.11.3:scripts/pr_ready_gate.sh` into a scratch file, never written back to
the bankai-core checkout.

---

## 1. Command mapping table

Every deterministic or hand-reconstructed step the old `SKILL.md` carried, and what replaces it.

| # | Old (prose / shell) | New (`nen`) |
|---|---|---|
| 1 | Resolve `<repo_code>` against `schemas/repos.json` → `product_codes` — described in prose as "read from the registry at run time," with no command given; left to the agent to `cat`/grep the file by hand | `nen pr ready <CODE>#<N> --repo <path>` resolves the code itself, against the same file, and refuses an unknown one by name (verified live, § 2.3) |
| 2 | `REPO=<owner>/<repo> scripts/pr_ready_gate.sh --verdict <N>` | `nen pr ready <CODE>#<N> --repo <path> --gates "$CLAUDE_PLUGIN_ROOT/contracts/bankai-core.gates.json"` (or `<N> --gh-repo <owner/repo> --gates …`) — the `$CLAUDE_PLUGIN_ROOT` anchor is load-bearing, not stylistic: a bare `contracts/bankai-core.gates.json` only resolves from this checkout's own root as cwd and `ENOENT`s from any other (verified live, § 2.6) |
| 3 | The 6-row conjunct table in SKILL.md § 3 was **static documentation**, not computed — the agent read a single terse verdict string (e.g. `not-ready: 3 unresolved review thread(s) (CON-32d)`) and matched it BY EYE against a lookup table baked into the skill file, marking every row after the match `—` by hand | `nen pr ready … --explain` (or `--json`'s `conjuncts[]`) renders the same six rows, in the same evaluation order, with `ready`/`FAILED`/`unevaluated` status already assigned per row and the short-circuit already applied — nothing to reconstruct (verified live, § 2.1–2.2) |
| 4 | The "what the gate does NOT decide" caveats (`CON-32c` approximation, the empty-rollup-fails note, `CON-32e` channel-less findings) were static prose the skill instructed the agent to append **from memory** every time | `nen pr ready … --explain`/`--json` prints the identical three caveats automatically, every invocation — no longer something the agent can forget or paraphrase (verified live, § 2.1) |
| 5 | `unevaluated` classification ("exit anything other than 0/1, or no output, is `unevaluated`") was a rule the agent applied by inspecting the shell's exit code and stderr | `nen` emits `unevaluated: <reason>` **as the verdict string itself** — no exit-code table to hold in the agent's head (verified live, § 2.4) |
| 6 | `--copilot-policy` never passed, to keep the settled `bounded` default | `--round-policy` never passed, same default, same rule; flag renamed by `nen`, semantics unchanged |
| 7 | `--exclude-run $GITHUB_RUN_ID`, in-job only | `--exclude-run <id>`, identical carve-out, same flag name |
| 8 | Dynamic reviewer-set enrolment (base `sasuke,tenma,copilot`; `+bisky`/`+bugbot` only when their check is present at head) lived inside the shell script's own bash, invisible to the skill text | Same computation now lives in `nen`'s ported `predicates.ts`, driven by `contracts/bankai-core.gates.json`'s `enrolment_check_pattern` fields — data, not shell, but the skill still never re-derives it by hand |
| 9 | `<repo_code>#<PR_NUMBER>` was parsed by the agent's own prose reading, by hand, every invocation | **Not** `nen parse` — checked `nen parse --help` live: it validates a skill's own custom grammar against a caller-supplied `--grammar` template (or one of three named skills, `futon`/`izanagi`/`izanami`, that carry a built-in one), and `pr-state` publishes no such template. `nen pr ready <ref>` parses its own `<CODE>#<N>` / bare-`<N>` ref internally instead (`src/verbs/pr_ready.ts`'s `CODED_REF` regex) — the ref grammar is the verb's own contract, not a separate `nen parse` invocation this skill would gain anything by adding |

**Count.** Before: 4 steps the agent had to perform **manually, in prose, per invocation** (rows 1, 3,
4, 5 above — resolving the code, reconstructing the table, appending the caveats, classifying
`unevaluated`), on top of remembering to run the oracle at all rather than eyeballing the PR (the whole
reason [BC-IS-#681](https://github.com/zheref/bankai-core/issues/681) exists). After: **0** — all four
are computed and printed by `nen pr ready --explain`/`--json`. What remains is one **required flag
decision** (`--repo`/`--gh-repo`/`--gates`), which is plumbing the verb demands, not something the old
skill left to improvisation.

---

## 2. Live A/B transcript (read-only)

**Citation, not re-proof.** Verdict parity between `nen pr ready` and `pr_ready_gate.sh` across the
live estate is already established by nen's shadow window
(`docs/evidence/shadow-window-p1.md` in `zheref/nen`, most recently **17/17** agreeing on readiness,
after two real disagreements were found and fixed during that project — an empty-vs-unreadable rollup
misclassification, and a check-rollup pagination cap that produced a false green past 100 contexts).
**Reason text is not claimed byte-equal across all 17**: that same evidence file records one declared,
normalized divergence — the oracle's reason string for an empty rollup carries a trailing
`(bankai-core#671)` citation that nen's own taxonomy-purity rule forbids `src/gates/ready.ts` from
emitting, so `reasonAgrees()` strips that one named substring before comparing; every other compared
row (verdicts that are not a bare `ready`, where there is reason text on both sides to compare at all)
matches with zero normalization applied. What follows is this skill's own **spot confirmation**, run
directly against real bankai-core PRs as part of this port, not a re-run of that whole harness.

> **Transcript cwd note.** The `--gates contracts/bankai-core.gates.json` in the transcripts below is
> cwd-relative because every run in this document was executed from the hatsu checkout root, where that
> path resolves — the commands are pasted as they actually ran, and rewriting them would falsify the
> record. The **copy/paste-safe form** for any other cwd is the one the skill mandates:
> `--gates "$CLAUDE_PLUGIN_ROOT/contracts/bankai-core.gates.json"` — § 2.6 demonstrates the `ENOENT`
> you get when the relative form leaves this directory.

### 2.1 — `nen pr ready`, `--explain`, an open PR with a real failure

```
$ export GH_TOKEN=$(gh auth token)
$ nen pr ready 925 --gh-repo zheref/bankai-core --gates contracts/bankai-core.gates.json --explain
```

```
zheref/bankai-core#925: not-ready: required checks reported but are not all green (CON-32a)

  head 702868f12487fa189b7bf0e35fc140391c19fd24 · reviewers sasuke,tenma,copilot · approvers sasuke,tenma
  policy bounded · delivery PR no · identities contracts/bankai-core.gates.json

  The gate is a CONJUNCTION, evaluated in this order, short-circuiting on the
  first failure. Everything after the failing row is genuinely unknown.

  1  ready       CON-42/1          Mergeable
  2  FAILED      CON-32(a)         Every reported check green, on the latest run per check name
        └ not-ready: required checks reported but are not all green (CON-32a)
  3  unevaluated CON-32(b)         No configured reviewer's requested round has stalled
  4  unevaluated CON-32(b)         No configured reviewer's round owed at the current head
  5  unevaluated CON-32(b)/CON-16  Every approving reviewer's latest round is an APPROVE at the current head
  6  unevaluated CON-32(d)         Zero unresolved review threads

  What the gate does NOT decide:
  - CON-32(c): "Addressed" is APPROXIMATED by the approve and zero-unresolved rows. ...
  - CON-32(a): That a BUILD check exists specifically is NOT asserted -- only that at least one check reported and that every reported check is green on its latest run. An EMPTY rollup FAILS, so absence is a finding here and never a pass ...
  - CON-32(e): A reviewer finding with NO thread object ... has nothing for the unresolved-threads row to count. Read the review bodies, not only their threads.
```

**Oracle, same PR, read-only (`--verdict`, posts nothing):**

```
$ export REPO=zheref/bankai-core
$ bash pr_ready_gate.sh --verdict 925
#925: not-ready: required checks reported but are not all green (CON-32a)
```

**Verdict: SAME.** `not-ready: required checks reported but are not all green (CON-32a)`, byte-identical
reason text on both sides.

### 2.2 — two closed PRs, `mergeable=UNKNOWN`

```
$ nen pr ready 934 --gh-repo zheref/bankai-core --gates contracts/bankai-core.gates.json
zheref/bankai-core#934: not-ready: mergeable=UNKNOWN (expected MERGEABLE — CON-42/1's added predicate)

$ nen pr ready 932 --gh-repo zheref/bankai-core --gates contracts/bankai-core.gates.json
zheref/bankai-core#932: not-ready: mergeable=UNKNOWN (expected MERGEABLE — CON-42/1's added predicate)
```

Oracle, both PRs, read-only:

```
$ bash pr_ready_gate.sh --verdict 934
#934: not-ready: mergeable=UNKNOWN (expected MERGEABLE — CON-42/1's added predicate)

$ bash pr_ready_gate.sh --verdict 932
#932: not-ready: mergeable=UNKNOWN (expected MERGEABLE — CON-42/1's added predicate)
```

**Verdict: SAME on both.** (`#934` is `MERGED`, `#932` is `MERGED` — GitHub stops computing
`mergeable` once a PR is no longer open on both transports, so both sides short-circuit on conjunct 1
identically; this is the same degenerate-but-genuine agreement the shadow window's own closed-PR rows
record.)

### 2.3 — a closed, unmerged PR, plus `--json`

```
$ nen pr ready 927 --gh-repo zheref/bankai-core --gates contracts/bankai-core.gates.json --json
{
  "verdict": "not-ready",
  "gateLine": "not-ready: required checks reported but are not all green (CON-32a)",
  "firstFailing": "checks-green",
  "conjuncts": [ ... six rows, orders 1-6, "checks-green" the only "failed", rows 3-6 "unevaluated" ... ],
  "caveats": [ ... the same three, as structured objects ... ],
  ...
}
```

Oracle:

```
$ bash pr_ready_gate.sh --verdict 927
#927: not-ready: required checks reported but are not all green (CON-32a)
```

**Verdict: SAME.** 4/4 PRs checked this run (`#925` open, `#927` closed/unmerged, `#932`/`#934` merged)
agree on both readiness and full reason text — a mix of open and closed, as available (bankai-core had
exactly one open PR, `#925`, at run time; `nen backlog fetch` or `gh pr list --state open` will confirm
this is a live, moving fact rather than a fixed count, same caveat the shadow window itself names).

### 2.4 — refusal / `unevaluated` behavior, verified live

```
$ unset GH_TOKEN
$ nen pr ready 925 --gh-repo zheref/bankai-core --gates contracts/bankai-core.gates.json
zheref/bankai-core#925: unevaluated: no usable token, so GitHub could not be read
nen: this pull request could NOT be evaluated, which is a finding and never a pass. GH_TOKEN is not
set -- this client never picks a token up ambiently the way gh does, so the caller must mint one and
name the variable it lives in
```

```
$ export GH_TOKEN=$(gh auth token)
$ nen pr ready 925 --gh-repo zheref/bankai-core
nen: no reviewer identities. This gate never falls back to a built-in reviewer set: a binary that
guessed the reviewers would judge this repository against another one's and report success. Give it
one of: --gates <path>, a 'schemas/gates.json' in the target repository (looked for at
'<cwd>\schemas\gates.json'), or --reviewers a,b,c.
```

Both confirm the operational truths this port encodes: `GH_TOKEN` is never ambient, and a frozen
bankai-core PR is unjudgeable without `--gates` pointed at `contracts/bankai-core.gates.json`.

### 2.5 — the no-`#` shorthand, a finding (not A/B, a defect against the binary)

```
$ nen pr ready BC9   --repo <bankai-core checkout> --gates contracts/bankai-core.gates.json
zheref/bankai-core#9: not-ready: mergeable=UNKNOWN (expected MERGEABLE — CON-42/1's added predicate)

$ nen pr ready BC925 --repo <bankai-core checkout> --gates contracts/bankai-core.gates.json
nen: 'BC92' is not a product code in the target repository's registry. Known codes: ...
```

`nen pr ready --help` does **not** say the `#` is optional anywhere in its text (checked live, see the
transcript above) — only the CLI's own **refusal text**, thrown when a ref is unparseable outright
(`src/verbs/pr_ready.ts`: `Write <CODE>#<N> (the '#' is optional) or a bare <N> together with
--gh-repo owner/name`), says so. The no-`#` parser only works for a **single-digit** PR number: it
splits the ref by peeling off exactly one trailing digit as the number, so `BC925` is misread as code
`BC92` + number `5`. Reproduced identically for `BC92`, `BC925`, `BC9925` (each fails one digit short
of a real code), while `BC9` and `BC#925` both resolve correctly. **Filed as a finding** (§ 4) — the
ported skill mandates writing `<CODE>#<N>` with the `#` always present, sidestepping the bug entirely
rather than routing around it by hand.

### 2.6 — the cwd-relative `--gates` path, a finding against the SKILL (not the binary), fixed here

```
$ cd <hatsu checkout>
$ nen pr ready BC#925 --repo <bankai-core checkout> --gates contracts/bankai-core.gates.json --explain
zheref/bankai-core#925: not-ready: required checks reported but are not all green (CON-32a)
  ...

$ cd <bankai-core checkout>
$ nen pr ready BC#925 --repo <bankai-core checkout> --gates contracts/bankai-core.gates.json --explain
nen: ENOENT: no such file or directory, open 'contracts/bankai-core.gates.json'

$ nen pr ready BC#925 --repo <bankai-core checkout> --gates <hatsu checkout>/contracts/bankai-core.gates.json --explain
zheref/bankai-core#925: not-ready: required checks reported but are not all green (CON-32a)
  ...
```

The first draft of the ported `SKILL.md` wrote `--gates contracts/bankai-core.gates.json` as a bare
relative path, which only resolves when the caller's cwd happens to be this checkout's own root — it
`ENOENT`s from anywhere else, verified live above. This is a **skill-authoring bug, not a `nen` defect**
(the flag is a plain path argument; `nen` does not owe it any particular resolution base), fixed in
this port by anchoring on `$CLAUDE_PLUGIN_ROOT` — the house convention `claude/skills/hatsu-warmup/
SKILL.md` § 0 already establishes for exactly this — which the last command above stands in for.

---

## 3. Residue

- **The oracle's notification mode has no `nen` counterpart, deliberately.** `pr_ready_gate.sh`'s
  default (non-`--verdict`) mode posts a "ready for decision" GitHub comment once per head. `nen pr
  ready` has no such mode at all — it only ever reports. This is a scope narrowing in `nen`'s favor for
  THIS skill (which was always meant to be read-only), not a missing verb: the notification behavior
  belongs to whatever workflow replaces `copilot-sweeper.yml`'s tick, not to `pr-state`.
- **Judgment kept, per the shared brief's boundary list:** interpreting what an `unevaluated` verdict
  or a caveat implies for the reader, and the binding rule in § 5 (a readiness claim is the verb's
  verdict quoted, or it is not made) — `nen` computes and prints; deciding what a maintainer should do
  about a `not-ready`/`unevaluated` PR stays this skill's.
- **No missing verb.** `nen pr ready` covers every deterministic step `pr-state` needs; the one gap
  found (§ 2.5) is a parser defect in an existing flag's advertised behavior, not an absent verb.
- **`nen pr next-blocker` had its own, separate false-green pagination defect (shadow-window-p1.md
  "Update 5"), now fixed — but it is a DIFFERENT verb (`../pr/blocker.ts`, feeding the future `drive`
  skill), reading review threads through its own `gh api graphql` transport, not `nen pr ready`'s path.
  It does not affect this skill; noted here only so a reader of the shadow-window doc does not conflate
  the two composers.**
- **Disclosed candidly, not a blocker for this port:** nen's own evidence file states its "rollback
  position" as of the same run this doc cites is that `scripts/pr_ready_gate.sh` "remains `CON-32`'s
  sole authority" inside the `nen` project itself — "this shadow window is evidence toward retiring that
  authority, not a transfer of it." That is `nen`'s own internal governance question, separate from
  hatsu#2's mandate (already decided at the orchestrator level, per the shared brief) to port hatsu's
  skills onto `nen`'s verb surface now. Recorded here for completeness, not routed around.
- **The historical incident table (§ 1 of the skill) is bankai-core's own recorded history**
  ([BC-IS-#681](https://github.com/zheref/bankai-core/issues/681) and its antecedents) and is kept
  verbatim as the skill's motivating record. **The old skill's four repo-code examples (`BC`, `BS`,
  `KP`, `KN`) were not carried over** — they are dropped, not kept, in this port; the registry now also
  lists `KW`, `KC` and the taxonomy's own `$comment` (§ 4's third finding), which is exactly why this
  skill's own instruction is to resolve codes from the live file at run time rather than repeat any
  fixed list from memory, this doc's included.

---

## 4. Findings (report separately, do not route around)

1. **`nen pr ready <CODE><N>` (no `#`) misparses any PR number with two or more digits**, splitting off
   only the last digit as the number and misreading the rest — including trailing digits — as the
   product code. **Only the CLI's own refusal message** (thrown on a wholly unparseable ref) asserts
   the `#` is optional — `--help`'s own text does not say this anywhere; verified live it is not
   optional in practice, for any ref this skill will realistically see (real PR numbers are almost
   never single-digit). Reproduced deterministically: `BC9` resolves, `BC92`/`BC925`/`BC9925` all fail
   one digit short of a valid code. The ported skill's binding rule (§ 1, § 6) is to always write the
   `#` explicitly, which is unaffected — but this is a real defect worth filing against `nen` itself
   (likely in the ref-splitting regex `nen pr ready`'s bare-ref path uses).

2. **A PR ref that names an issue instead surfaces as a misleading `unevaluated`, not a clean "that's
   an issue" error.** Verified live: `nen pr ready BC#918 --repo <bankai-core checkout> --gates
   <path>` (`918` is an open issue on `zheref/bankai-core`, not a PR) returns
   `unevaluated: GitHub could not be read (… Could not resolve to a PullRequest with the number of
   918.)`, followed by `nen`'s generic remedy — "Check the token's grants (pull-requests:read AND
   checks:read AND actions:read), that it is not expired, and that the network reached github.com."
   The remedy is **wrong for this cause**: the token used to reproduce this was fully-scoped and
   working (the same invocation against a real PR number succeeds), so the actual fix is "check the
   number names a pull request," not a token-grants audit. The ported skill (§ 1, § 4, § 6) instructs
   relaying the reason and remedy verbatim regardless, and flags the mismatch explicitly rather than
   silently reclassifying it.

3. **The unknown-product-code refusal lists `$comment` as if it were a valid product code.** Verified
   live: `nen pr ready BC92 --repo <bankai-core checkout> --gates <path>` (an unparseable code from the
   no-`#` bug above, finding 1) refuses with `'BC92' is not a product code in the target repository's
   registry. Known codes: $comment, BC, BS, KC, KN, KP, KW.` — `$comment` is `schemas/repos.json`'s own
   documentation key, not a `product_codes` entry, and should not be enumerated alongside the real ones
   in a message whose whole purpose is to name the valid choices.
