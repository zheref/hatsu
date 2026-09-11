# A/B evidence — `pr-state` (zheref/hatsu#2)

Port of `claude/skills/pr-state/SKILL.md`: the deterministic `CON-32` readiness gate, quoted verbatim,
with its conjunct-by-conjunct breakdown. Old mechanics: `REPO=<owner>/<repo> scripts/pr_ready_gate.sh
--verdict <N>`, plus prose the skill file itself carried to reconstruct the per-conjunct table and the
`unevaluated` classification by hand. New mechanics: `nen pr ready <ref> --explain`.

Run: 2026-09-02T00:25Z (UTC). `nen` `0.1.0` (`<cache>\nen\v0.1.0\nen-windows-x64.exe`).
`gh` authenticated as `zheref`. Oracle checkout: `<reference-repo>` tag `v0.11.3`
(`2269fe723e355dc69bf535ab40f22556e4fe4081`, working tree clean) — `scripts/pr_ready_gate.sh` extracted
read-only via `git show v0.11.3:scripts/pr_ready_gate.sh` into a scratch file, never written back to
the `<reference-repo>` checkout.

*Paths sanitized: this machine's local absolute paths appear as `<checkout>` (the parent directory of the repository checkouts), `<cache>` (the nen binary cache) and `<scratch>` (a throwaway scratch directory). Private repository names, and the product codes that identified them, are redacted to placeholders (see [`docs/PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md)); nothing else below is altered -- the transcripts are otherwise verbatim.*

> **Dated note, 2026-09-10 — the `--gates` form below is `<reference-repo>`-specific, and `SKILL.md`
> § 2 now says so rather than reading as the general fallback.** `contracts/reference.gates.json`
> carries `<reference-repo>`'s own reviewer identities; pointing it at any other target's PR produces
> a confident verdict built on an **unverified assumption**, not a reading of that target's own
> configuration — `sasuke`/`tenma`/`copilot` are not reserved to `<reference-repo>` (`docs/ab/senkei.md`
> § 4.1 records `<product-repo-A>` reusing the same `sasuke`/`tenma` workflow names in its own review-pair),
> so a `ready` verdict this way can even land on the RIGHT people by coincidence and still be wrong in
> method: the identities were never derived from the target being judged. `claude/skills/pr-state/SKILL.md`
> § 2 now cites `claude/skills/sharingan/SKILL.md` §
> 4's identity rule instead of restating it: a target's own `nen/gates.json` wins where one exists;
> `--gates` with this reference file is for `<reference-repo>` alone; any other gates-file-less
> target gets `--reviewers` supplied by hand — from its `CODEOWNERS` or the PR's own requested
> reviewers, never this file — with the approve row's vacuous pass (no `--approvers` given) stated on
> the page. The transcripts below still ran against real `<reference-repo>` PRs, so they stay as
> recorded.

---

## 1. Command mapping table

Every deterministic or hand-reconstructed step the old `SKILL.md` carried, and what replaces it.

| # | Old (prose / shell) | New (`nen`) |
|---|---|---|
| 1 | Resolve `<repo_code>` against `schemas/repos.json` → `product_codes` — described in prose as "read from the registry at run time," with no command given; left to the agent to `cat`/grep the file by hand | `nen pr ready <CODE>#<N> --repo <path>` resolves the code itself, against the same file, and refuses an unknown one by name (verified live, § 2.3) |
| 2 | `REPO=<owner>/<repo> scripts/pr_ready_gate.sh --verdict <N>` | `nen pr ready <CODE>#<N> --repo <path> --gates "$CLAUDE_PLUGIN_ROOT/contracts/reference.gates.json"` (or `<N> --gh-repo <owner/repo> --gates …`) — the anchor is load-bearing, not stylistic (`$CLAUDE_PLUGIN_ROOT` was the anchor at this port and is historical; the skill mandates the same-shell `$hatsu_root` form today — § 2.6's dated note): a bare `contracts/reference.gates.json` only resolves from this checkout's own root as cwd and `ENOENT`s from any other (verified live, § 2.6) |
| 3 | The 6-row conjunct table in SKILL.md § 3 was **static documentation**, not computed — the agent read a single terse verdict string (e.g. `not-ready: 3 unresolved review thread(s) (CON-32d)`) and matched it BY EYE against a lookup table baked into the skill file, marking every row after the match `—` by hand | `nen pr ready … --explain` (or `--json`'s `conjuncts[]`) renders the same six rows, in the same evaluation order, with `ready`/`FAILED`/`unevaluated` status already assigned per row and the short-circuit already applied — nothing to reconstruct (verified live, § 2.1–2.2) |
| 4 | The "what the gate does NOT decide" caveats (`CON-32c` approximation, the empty-rollup-fails note, `CON-32e` channel-less findings) were static prose the skill instructed the agent to append **from memory** every time | `nen pr ready … --explain`/`--json` prints the identical three caveats automatically, every invocation — no longer something the agent can forget or paraphrase (verified live, § 2.1) |
| 5 | `unevaluated` classification ("exit anything other than 0/1, or no output, is `unevaluated`") was a rule the agent applied by inspecting the shell's exit code and stderr | `nen` emits `unevaluated: <reason>` **as the verdict string itself** — no exit-code table to hold in the agent's head (verified live, § 2.4) |
| 6 | `--copilot-policy` never passed, to keep the settled `bounded` default | `--round-policy` never passed, same default, same rule; flag renamed by `nen`, semantics unchanged |
| 7 | `--exclude-run $GITHUB_RUN_ID`, in-job only | `--exclude-run <id>`, identical carve-out, same flag name |
| 8 | Dynamic reviewer-set enrolment (base `sasuke,tenma,copilot`; `+bisky`/`+bugbot` only when their check is present at head) lived inside the shell script's own bash, invisible to the skill text | Same computation now lives in `nen`'s ported `predicates.ts`, driven by `contracts/reference.gates.json`'s `enrolment_check_pattern` fields — data, not shell, but the skill still never re-derives it by hand |
| 9 | `<repo_code>#<PR_NUMBER>` was parsed by the agent's own prose reading, by hand, every invocation | **Not** `nen parse` — checked `nen parse --help` live: it validates a skill's own custom grammar against a caller-supplied `--grammar` template (or one of three named skills, `futon`/`izanagi`/`izanami`, that carry a built-in one), and `pr-state` publishes no such template. `nen pr ready <ref>` parses its own `<CODE>#<N>` / bare-`<N>` ref internally instead (`src/verbs/pr_ready.ts`'s `CODED_REF` regex) — the ref grammar is the verb's own contract, not a separate `nen parse` invocation this skill would gain anything by adding |

**Count.** Before: 4 steps the agent had to perform **manually, in prose, per invocation** (rows 1, 3,
4, 5 above — resolving the code, reconstructing the table, appending the caveats, classifying
`unevaluated`), on top of remembering to run the oracle at all rather than eyeballing the PR (the whole
reason RR-IS-#681 exists). After: **0** — all four
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
`(<reference-repo>#671)` citation that nen's own taxonomy-purity rule forbids `src/gates/ready.ts` from
emitting, so `reasonAgrees()` strips that one named substring before comparing; every other compared
row (verdicts that are not a bare `ready`, where there is reason text on both sides to compare at all)
matches with zero normalization applied. What follows is this skill's own **spot confirmation**, run
directly against real `<reference-repo>` PRs as part of this port, not a re-run of that whole harness.

> **Transcript cwd note.** The `--gates contracts/reference.gates.json` in the transcripts below is
> cwd-relative because every run in this document was executed from the hatsu checkout root, where that
> path resolves — the commands are pasted as they actually ran, and rewriting them would falsify the
> record. The **copy/paste-safe form** for any other cwd is the one the skill mandates *today*:
> `--gates "$hatsu_root/contracts/reference.gates.json"`, with `$hatsu_root` set in that same shell by the
> resolver `pr-state` § 2 carries (the § 2.6 dated note below says how the anchor got there). It was
> `$CLAUDE_PLUGIN_ROOT` when these transcripts were recorded, which is Claude Code's alone and is unset or
> wrong on Codex and Cursor — historical, not guidance. § 2.6 demonstrates the `ENOENT` you get when the
> relative form leaves this directory.

### 2.1 — `nen pr ready`, `--explain`, an open PR with a real failure

```
$ export GH_TOKEN=$(gh auth token)
$ nen pr ready 925 --gh-repo <reference-repo> --gates contracts/reference.gates.json --explain
```

```
<reference-repo>#925: not-ready: required checks reported but are not all green (CON-32a)

  head 702868f12487fa189b7bf0e35fc140391c19fd24 · reviewers sasuke,tenma,copilot · approvers sasuke,tenma
  policy bounded · delivery PR no · identities contracts/reference.gates.json

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
$ export REPO=<reference-repo>
$ bash pr_ready_gate.sh --verdict 925
#925: not-ready: required checks reported but are not all green (CON-32a)
```

**Verdict: SAME.** `not-ready: required checks reported but are not all green (CON-32a)`, byte-identical
reason text on both sides.

### 2.2 — two closed PRs, `mergeable=UNKNOWN`

```
$ nen pr ready 934 --gh-repo <reference-repo> --gates contracts/reference.gates.json
<reference-repo>#934: not-ready: mergeable=UNKNOWN (expected MERGEABLE — CON-42/1's added predicate)

$ nen pr ready 932 --gh-repo <reference-repo> --gates contracts/reference.gates.json
<reference-repo>#932: not-ready: mergeable=UNKNOWN (expected MERGEABLE — CON-42/1's added predicate)
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
$ nen pr ready 927 --gh-repo <reference-repo> --gates contracts/reference.gates.json --json
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
agree on both readiness and full reason text — a mix of open and closed, as available (`<reference-repo>` had
exactly one open PR, `#925`, at run time; `nen backlog fetch` or `gh pr list --state open` will confirm
this is a live, moving fact rather than a fixed count, same caveat the shadow window itself names).

### 2.4 — refusal / `unevaluated` behavior, verified live

```
$ unset GH_TOKEN
$ nen pr ready 925 --gh-repo <reference-repo> --gates contracts/reference.gates.json
<reference-repo>#925: unevaluated: no usable token, so GitHub could not be read
nen: this pull request could NOT be evaluated, which is a finding and never a pass. GH_TOKEN is not
set -- this client never picks a token up ambiently the way gh does, so the caller must mint one and
name the variable it lives in
```

```
$ export GH_TOKEN=$(gh auth token)
$ nen pr ready 925 --gh-repo <reference-repo>
nen: no reviewer identities. This gate never falls back to a built-in reviewer set: a binary that
guessed the reviewers would judge this repository against another one's and report success. Give it
one of: --gates <path>, a 'schemas/gates.json' in the target repository (looked for at
'<cwd>\schemas\gates.json'), or --reviewers a,b,c.
```

Both confirm the operational truths this port encodes: `GH_TOKEN` is never ambient, and a frozen
`<reference-repo>` PR is unjudgeable without `--gates` pointed at `contracts/reference.gates.json`.

### 2.5 — the no-`#` shorthand, a finding (not A/B, a defect against the binary)

```
$ nen pr ready BC9   --repo <reference-repo checkout> --gates contracts/reference.gates.json
<reference-repo>#9: not-ready: mergeable=UNKNOWN (expected MERGEABLE — CON-42/1's added predicate)

$ nen pr ready BC925 --repo <reference-repo checkout> --gates contracts/reference.gates.json
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
$ nen pr ready BC#925 --repo <reference-repo checkout> --gates contracts/reference.gates.json --explain
<reference-repo>#925: not-ready: required checks reported but are not all green (CON-32a)
  ...

$ cd <reference-repo checkout>
$ nen pr ready BC#925 --repo <reference-repo checkout> --gates contracts/reference.gates.json --explain
nen: ENOENT: no such file or directory, open 'contracts/reference.gates.json'

$ nen pr ready BC#925 --repo <reference-repo checkout> --gates <hatsu checkout>/contracts/reference.gates.json --explain
<reference-repo>#925: not-ready: required checks reported but are not all green (CON-32a)
  ...
```

The first draft of the ported `SKILL.md` wrote `--gates contracts/reference.gates.json` as a bare
relative path, which only resolves when the caller's cwd happens to be this checkout's own root — it
`ENOENT`s from anywhere else, verified live above. This is a **skill-authoring bug, not a `nen` defect**
(the flag is a plain path argument; `nen` does not owe it any particular resolution base), fixed in
this port by anchoring on `$CLAUDE_PLUGIN_ROOT` — the house convention of the time, and historical now:
the skill mandates the same-shell `$hatsu_root` form, the dated note below says how — which the last
command above stands in for.

> **Dated note, 2026-09-10 — the anchor is now `$hatsu_root`, and the transcript above stands.** Copilot's
> review of PR #36 (`surfaces/codex/pr-state/SKILL.md` and `surfaces/cursor/pr-state/SKILL.md`, line 101)
> pointed out that the mirrored body carried `$CLAUDE_PLUGIN_ROOT` onto two surfaces where that variable
> is normally unset — or, exported from a shell profile, names a different plugin (`docs/ab/surfaces.md`
> § 8, F3). The finding is older than PR #36: the line existed before that PR touched it, and the same
> anchor sat in `futon`, `backlog-state`, `getsuga`, `tensho`, `sharingan`, `hanten` and the Kurapika
> definition. The fix is in the SOURCE, not in nen's generator: `nen surface mirror generate` copies a
> body verbatim and rewrites only what a surface documents an explicit spelling for (the invocation
> prefix, caller data), and neither Codex nor Cursor documents a plugin-root variable, because neither
> has a plugin loader. So every skill now anchors on `$hatsu_root` — the Hatsu checkout as
> `hatsu-warmup` § 5's prelude resolves it, `$HATSU_PLUGIN_ROOT`, else the handed path, else
> `$CLAUDE_PLUGIN_ROOT`, each identity-checked, the winner canonicalised with `pwd -P`, and resolved in
> the shell that runs the call because the variable is not exported — which is the same absolute path on
> Claude Code and a real one on the other two. The reason recorded in § 2.6 is unchanged, and the three commands above
> ran as shown.

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
  "Update 5"), now fixed — but it is a DIFFERENT verb (`../pr/blocker.ts`, feeding the future `drive` — `sharingan` since `v0.5.0`
  skill), reading review threads through its own `gh api graphql` transport, not `nen pr ready`'s path.
  It does not affect this skill; noted here only so a reader of the shadow-window doc does not conflate
  the two composers.**
- **Disclosed candidly, not a blocker for this port:** nen's own evidence file states its "rollback
  position" as of the same run this doc cites is that `scripts/pr_ready_gate.sh` "remains `CON-32`'s
  sole authority" inside the `nen` project itself — "this shadow window is evidence toward retiring that
  authority, not a transfer of it." That is `nen`'s own internal governance question, separate from
  hatsu#2's mandate (already decided at the orchestrator level, per the shared brief) to port hatsu's
  skills onto `nen`'s verb surface now. Recorded here for completeness, not routed around.
- **The historical incident table (§ 1 of the skill) is `<reference-repo>`'s own recorded history**
  (RR-IS-#681 and its antecedents) and is kept
  verbatim as the skill's motivating record. **The old skill's four repo-code examples (`BC`, `BS`,
  `RA`, `RB`) were not carried over** — they are dropped, not kept, in this port; the registry now also
  lists `RC`, `KC` and the taxonomy's own `$comment` (§ 4's third finding), which is exactly why this
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
   an issue" error.** Verified live: `nen pr ready BC#918 --repo <reference-repo checkout> --gates
   <path>` (`918` is an open issue on `<reference-repo>`, not a PR) returns
   `unevaluated: GitHub could not be read (… Could not resolve to a PullRequest with the number of
   918.)`, followed by `nen`'s generic remedy — "Check the token's grants (pull-requests:read AND
   checks:read AND actions:read), that it is not expired, and that the network reached github.com."
   The remedy is **wrong for this cause**: the token used to reproduce this was fully-scoped and
   working (the same invocation against a real PR number succeeds), so the actual fix is "check the
   number names a pull request," not a token-grants audit. The ported skill (§ 1, § 4, § 6) instructs
   relaying the reason and remedy verbatim regardless, and flags the mismatch explicitly rather than
   silently reclassifying it.

3. **The unknown-product-code refusal lists `$comment` as if it were a valid product code.** Verified
   live: `nen pr ready BC92 --repo <reference-repo checkout> --gates <path>` (an unparseable code from the
   no-`#` bug above, finding 1) refuses with `'BC92' is not a product code in the target repository's
   registry. Known codes: $comment, BC, BS, KC, RA, RB, RC.` — `$comment` is `schemas/repos.json`'s own
   documentation key, not a `product_codes` entry, and should not be enumerated alongside the real ones
   in a message whose whole purpose is to name the valid choices.

---

## Retired at nen 0.7 — 2026-09-10

Run against the released `zheref/nen` `v0.7.0` binary (`nen-darwin-arm64`, sha256
`a0545d02…e7b6c323`, fetched and checksum-verified by `bootstrap/nen.sh --ref v0.7.0`, on `PATH` as
`nen`; `nen --version` → `0.7.0`), with `GH_TOKEN=$(gh auth token)`.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| a verdict that could not say which binary decided it | `nen pr ready … --explain` | `1`, with a `decided by nen …` header line |
| — the machine form | `… --json` | `1`, `meta.generator.executable` |
| CON-30's carve-out declared as data and read by nothing | `nen pr ready … --gates <file declaring it>` | `1`, `meta.dependabotCarveOut: false` |
| — a carve-out that would fire on no evidence | `… --gates <file with an empty satisfied_by_context>` | **`2`**, refused at load |

### The provenance line

```text
v0.6.0  $ nen pr ready 41 --gh-repo zheref/hatsu --reviewers copilot --token-env NEN_UNSET --explain
        zheref/hatsu#41: unevaluated: no usable token, so GitHub could not be read

          head (unread) · reviewers copilot · approvers copilot
          policy bounded · delivery PR unknown · identities from --reviewers (reduced: …)
                                                        # ← two header lines, and no third

0.7.0   $ nen pr ready 38 --gh-repo zheref/hatsu --gates <abs>/contracts/reference.gates.json --explain
        zheref/hatsu#38: not-ready: a configured reviewer's round is still owed at the current head
        (CON-32b): sasuke (no round at head);tenma (no round at head)

          head 86af98af2996f72a589d794f32b42fe6c963c748 · reviewers sasuke,tenma,copilot · approvers sasuke,tenma
          policy bounded · delivery PR no · identities <abs>/contracts/reference.gates.json
          decided by nen 0.7.0 (/Users/<you>/.cache/nen/zheref_nen/v0.7.0/nen-darwin-arm64) at 2026-09-10T21:07:18Z
```

`--json`'s `meta.generator` gains `executable` beside the `program` and `version` it has carried
since `v0.1`:

```json
"generator": { "program": "nen", "version": "0.7.0",
               "executable": "/Users/<you>/.cache/nen/zheref_nen/v0.7.0/nen-darwin-arm64" }
```

**It is the version and the PATH, not a checkout SHA.** `nen --version` says which nen a caller
*believes* it has; `executable` says which file actually answered — a checksum-verified binary under
the bootstrap cache, a locally built one, or `bun src/index.ts` out of a working tree, all three able
to carry the same version string and different behaviour. A compiled binary has no checkout at
evaluation time, and its bytes are verifiable against the release's published `SHA256SUMS` instead.
The line is deliberately **not** printed on stderr on every invocation the way the shell oracle
printed it: nen has a structured report and `pr ready` is not privileged among thirty-odd verbs.

The field is **additive**, so `nen.pr.ready/v0.1` does not bump — that contract's own stated rule.
`conjuncts[]` rows now read `{ id, clause, title, order, status, reason, note }`, `note` being the
new one.

### CON-30's dependency-author carve-out, read rather than ignored

`nen/gates.json` may declare it; `contracts/reference.gates.json` **does not**, so every verdict this
skill produces for the frozen reference repository carries `dependabotCarveOut: false`. Verified
three ways at this pin:

```text
unevaluated report (no token)          meta.dependabotCarveOut = null
ordinary evaluation, no block declared meta.dependabotCarveOut = false
block declared, author is not a match  meta.dependabotCarveOut = false
```

**`null` on an unevaluated report is the load-bearing one**: the gate never ran far enough to ask,
and `false` there would read as "asked, and no" — a claim about evidence nobody looked at.

A carve-out that could fire on nothing is refused at LOAD rather than at evaluation:

```text
$ nen pr ready 38 --gh-repo zheref/hatsu --gates <fx>/gates-carve-empty.json                # exit 2
nen: <fx>/gates-carve-empty.json: at dependabot_carve_out.satisfied_by_context, is empty. A carve-out
satisfied by no context is satisfied by nothing, so it would clear the review rounds for every pull
request that author opens on no evidence at all. Name the check contexts the review shim reports, or
delete the block.
```

Same shape and reasoning as the empty-approver-set refusal beside it. **Not exercised live: a
carve-out actually FIRING.** No repository in bounds carries a `dependabot`-authored pull request
with the named shim contexts green at head, so the `true` case is read from `docs/USAGE.md` and the
`v0.7.0` CHANGELOG rather than observed — the three readings above are what this pin proves.

### What did not change

The six conjuncts, their order, the short-circuit, and the three "what the gate does NOT decide"
caveats are byte-identical to `v0.6.0`'s `--explain` output. The carve-out clears **three rows**
(the stall bound, the owed round, the approve limb) and no others: CON-32(a) runs first, so a
dependency PR is never exempted from having checks or from their being green, and CON-32(d) runs
after, so an unresolved thread still fails.
