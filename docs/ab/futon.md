# A/B evidence — `futon`

> Historical transcript: “How to verify” below is the product verification title. Current kind-specific
> composition is [PR-SECTIONS.md](../PR-SECTIONS.md); recorded command output is preserved.

Run: 2026-09-02T02:37Z (UTC) for the original port session (commit `876efa7`, authored
`2026-09-01T21:37:43-05:00`) — every transcript below except § 5. § 5's `nen loop slots`
transcripts were re-run for the M1 review-finding fix at 2026-09-02T02:50–02:52Z (UTC); see the
correction note in § 5 itself.

Port of `zheref/hatsu#2` for the `futon` skill. Method: the shared port brief this migration
session's orchestrator issued for Stage B (session artifact, not checked in) — a command mapping
table, live read-only transcripts against the real `<reference-repo>` backlog, and residue. `nen` verified: `<cache>\nen\v0.1.0\nen-windows-x64.exe`
(`0.1.0`). No mutating verb was exercised against `<reference-repo>` (frozen, read-only per the
brief); mutating verbs are A/B'd by contract inspection (flag-by-flag against the old skill's
improvised commands) and their own `--help` output.

*Paths sanitized: this machine's local absolute paths appear as `<checkout>` (the parent directory of the repository checkouts), `<cache>` (the nen binary cache) and `<scratch>` (a throwaway scratch directory). Private repository names, and the product codes that identified them, are redacted to placeholders (see [`docs/PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md)); nothing else below is altered -- the transcripts are otherwise verbatim.*

> **Dated note, 2026-09-10 — § 4's `--gates` transcripts below are `<reference-repo>`-specific, and
> `SKILL.md` § 5 now says so.** `contracts/reference.gates.json` carries `<reference-repo>`'s own
> reviewer identities; pointing it at another target's PR reports a confident verdict about the wrong
> people. `claude/skills/futon/SKILL.md` § 5 now cites `claude/skills/sharingan/SKILL.md` § 4's
> identity rule instead of restating it: a target's own `nen/gates.json` wins where one exists;
> `--gates` with this reference file is for `<reference-repo>` alone; any other gates-file-less
> target gets `--reviewers` supplied by hand — from its `CODEOWNERS` or the PR's own requested
> reviewers, never this file — with the approve row's vacuous pass stated on the page. The `BC#940` /
> `BC#925` transcripts below still ran against real `<reference-repo>` PRs, so they stay as recorded.

Verdict parity between `nen pr ready` and `scripts/pr_ready_gate.sh` was already proven across the
live estate by nen's shadow window (`docs/evidence/shadow-window-p1.md` in `zheref/nen`, 16/16 then
17/17 agreement) — not re-proven here; the runs in § 4 are spot confirmation on this port's own two
live objects, not a fresh parity study.

## 0. Command mapping table

| Old skill improvised (quoted / paraphrased) | Replaced by |
|---|---|
| *"Parsing rules, all of them the same rule: resolve or refuse, never guess"* — hand-written `+`/`then`/case-fold logic | `nen parse futon --repo <path> "<line>" [--self <owner/name>]` — a BUILT-IN grammar, not a supplied template |
| *"The repo token resolves from `schemas/repos.json` → `product_codes`"* | Resolved inside the same `nen parse futon` call |
| *"Fetch the repo's open issues whole, with labels, comments, linked PRs and check/review state ... never a cached list"* | `nen backlog fetch --repo-slug <owner/name> [--limit <n>]` |
| *"Order within the band by `backlog-loop` § 2's tie-breakers — blocks another issue, then reaches a consumer ..., then age"* | `nen backlog order --rows-from <path> --severity-order <a,b,c,d> --blocks <ids> --affects-consumers <ids>` |
| Untriaged issue: *"propose a severity ... Apply it ... under the run-scoped delegation"* (a raw `gh issue edit --add-label`) | `nen label apply <ref> --label bankai:severity/<n> --repo-slug <o/n> --reason "<text>" --run` |
| Release: apply `bankai:stage/building` (raw `gh issue edit --add-label`) | `nen label apply <ref> --label bankai:stage/building ... --run` |
| *"`REPO=owner/repo scripts/pr_ready_gate.sh --verdict N` exiting `0`"* (a shell script) | `nen pr ready <ref> --repo <path> --gates <path> --explain` |
| Body requirements (`## How to verify`, changelog fragment) read by eye or folded into the shell script | `nen pr body-check --body-from <path> --requirements-from <path>` |
| *"Work at most TWO issues at a time"* / *"7 concurrent"* — hand-counted concurrency | `nen loop slots --efforts <path> --ci-cap 2 --local-cap 7` |
| The unblock channel, `bankai:wake/iterate` fired alone, with the comment/label race hand-avoided | `nen wake fire --repo-slug <o/n> --ref <ref> --label bankai:wake/iterate --run`; verifying it actually landed: `nen wake verify --repo-slug <o/n> --now <ISO> --author-pattern <regex>` |
| `<CODE>-<IS\|PR>-#<N>` notation, hand-formatted markdown links | `nen ref format --repo <path> --code <C> --kind <IS\|PR> --number <N> [--state <s>]`; `nen ref parse <token> --repo <path>` |
| `scripts/ichigo_prompt.sh` + a hand-built efforts table for the gate stop | `nen stop --who Kurapika --gate <Gn> [--notified] efforts.md` |
| Tag-cut preconditions (open `critical`, `CON-36` live chore, `RELEASE_HOLD`), changelog collation, the tag itself, the `CON-22` fan-out computation — all hand-run shell scripts (`changelog_collate_fragments.sh`, `tag_cut.sh`) and prose checks | **Out of `futon`'s scope entirely** — `hatsu:getsuga`'s own verbs, `nen release preflight` and `nen fanout compute/record` (§ 6). `futon` hands off rather than replacing these itself |

**Count.** The old skill's own prose named at least 13 distinct improvised mechanisms inside its own
scope (parse, repo-resolve, fetch, order, two label applies, readiness, body-check, concurrency
count, wake-fire, wake-verify, ref notation, stop rendering) plus a further 5 the terminal absorbed
(critical-check, chore-check, `RELEASE_HOLD`, changelog collation, the cut/fan-out itself). This
port replaces every one of the first 13 with a named `nen` verb and hands the remaining 5 to
`getsuga` wholesale rather than reimplementing them — `futon` itself improvises **zero** of either
group. What is left genuinely un-mechanizable is listed in § 7 (Residue): severity/mode judgment,
the G5 diagnosis, and the discipline of keeping exactly one `bankai:stage/*` label at a time.

## 1. `nen parse futon` — every band shape, both terminals, live

All run with `--repo` pointed at the real `<reference-repo>` checkout
(`<checkout>\<reference-repo>`, `git describe --tags` = `v0.11.3`). This verb
reads only `schemas/repos.json` on disk — no `GH_TOKEN`, no network call.

### 1.1 Bare band, no terminal

```
$ nen parse futon --repo <reference-repo> "@high"
repo: <reference-repo>
band: high -> high
terminal: (none -- build-only)
```
exit `0`.

### 1.2 `+` expansion, owner/name form

```
$ nen parse futon --repo <reference-repo> "<reference-repo>@high+"
repo: <reference-repo>
band: high+ -> critical, high
terminal: (none -- build-only)
```
exit `0`. Cross-checked on a real consumer code too:
```
$ nen parse futon --repo <reference-repo> "<product-repo-A>@high+"
repo: <product-repo-A> (RA)
band: high+ -> critical, high
terminal: (none -- build-only)
```
exit `0`. `+` never expands past the immediately-higher severities named — `medium+` was not tried
against this registry's own four-value vocabulary since `critical/high/medium/low` is exhaustive,
but the code path is identical to the `high+` case verified here.

### 1.3 `then tag` and `then tag+fanout`, bare form, no `--self` needed

```
$ nen parse futon --repo <reference-repo> "@high+ then tag"
repo: <reference-repo>
band: high+ -> critical, high
terminal: tag
```
```
$ nen parse futon --repo <reference-repo> "@high+ then tag+fanout"
repo: <reference-repo>
band: high+ -> critical, high
terminal: tag+fanout
```
Both exit `0`. Owner/name form gives the identical result:
```
$ nen parse futon --repo <reference-repo> "<reference-repo>@high then tag"
repo: <reference-repo>
band: high -> high
terminal: tag
```

### 1.4 The terminal's scope rule generalizes to "the repo you are standing in," not hardcoded to `<reference-repo>`

```
$ nen parse futon --repo <reference-repo> "RA@high then tag" --self "<product-repo-A>"
repo: <product-repo-A> (RA)
band: high -> high
terminal: tag
```
exit `0`. Same with `tag+fanout`:
```
$ nen parse futon --repo <reference-repo> "<product-repo-A>@high then tag+fanout" --self "<product-repo-A>"
repo: <product-repo-A> (RA)
band: high -> high
terminal: tag+fanout
```
The old skill's own prose read *"a `then` clause is valid on `<reference-repo>` ONLY, and is refused
anywhere else."* The verb's actual rule is *"valid only on the repo you are standing in"* (`--self`,
or `--repo`'s own remote) — a strictly more general rule that happens to collapse to the old one in
every real session, since Kurapika's sessions stand in `<reference-repo>` when they type this. Not
exploited by this port (§ 8 of `SKILL.md` only ever hands `<reference-repo>`'s own release machinery to
`getsuga`), but worth recording as a real behavioural difference from the retired prose.

### 1.5–1.7 The finding: the product-code form cannot resolve the registry's own repo

```
$ nen parse futon --repo <reference-repo> "BC@medium"
nen: 'BC' resolves to '<reference-repo>' in this registry's own product_codes, but no owner is
recorded for it (it names no consumer) and the checkout you are standing in ('<reference-repo>')
is not it. Run this from '<reference-repo>''s own checkout, or name a consumer this registry
actually lists.
exit 2
```
Reproduced identically with a `then` clause, with `+`, and with `--self "<reference-repo>"`
explicitly passed — none of it changes the refusal. The owner/name and short-name forms parse
cleanly against the **same registry, same checkout**:
```
$ nen parse futon --repo <reference-repo> "<reference-repo>@medium"
repo: <reference-repo>
band: medium -> medium
terminal: (none -- build-only)
```
```
$ nen parse futon --repo <reference-repo> "<reference-repo>@medium"
repo: <reference-repo>
band: medium -> medium
terminal: (none -- build-only)
```
The same refusal reproduces for `KC` (`kro-pwa`), which `schemas/repos.json` records under
`pending_onboarding`, not `consumers`:
```
$ nen parse futon --repo <reference-repo> "KC@high"
nen: 'KC' resolves to 'zheref/kro-pwa' in this registry's own product_codes, but no owner is
recorded for it (it names no consumer) ...
exit 2
```
A real **consumer** code (`RA`) resolves without issue (§ 1.2). The pattern: the code-lookup path
appears to check the `consumers[]` array only — never `product_codes` directly for confirmation,
and never `maintained_tools`/`pending_onboarding` — so a code naming the registry's *own* source
repo, or a not-yet-onboarded one, can never resolve, while the identical string typed as an
owner/name or bare short name resolves instantly (§ 1.6–1.7 above; those go through the same code
path as the bare-self default of § 1.1, which also succeeded).

### 1.8 A sibling verb on the same registry does not have this gap

```
$ nen repo resolve BC   # run from inside the <reference-repo> checkout
<reference-repo>  (BC)  via code
```
exit `0`, instant. `hatsu:backlog-state`'s own A/B doc (`docs/ab/backlog-state.md` § finding,
already landed on `origin/main`) records the *same* family of bug in a different verb
(`nen repo resolve`'s no-token/origin-matching form) against the same repo, for what reads as the
same underlying cause: a lookup path that consults `consumers[]` (sometimes `∪
maintained_tools`) but never falls back to the full `product_codes` map when the token names the
registry's own source. Two verbs (`nen parse futon`, `nen repo resolve`'s no-token form) share this
blind spot on the same object; this port adds `nen parse futon`'s **code-token** form as a third,
narrower instance of it. **Corrected invocation for `<reference-repo>` until fixed**: `@<severity>`
(bare, when standing in the checkout) or `<reference-repo>@<severity>` / `<reference-repo>@<severity>`
— never `BC@<severity>`.

### 1.9 Refusals — bad severity, bad terminal, unresolvable token

```
$ nen parse futon --repo <reference-repo> "RA@urgent"
nen: 'urgent' is not a severity. Expected one of critical, high, medium, low, optionally suffixed '+'.
  try: RA@critical
exit 2

$ nen parse futon --repo <reference-repo> "RA@high then release"
nen: 'then release' is not a recognized terminal. Only 'then tag' and 'then tag+fanout' are accepted.
  try: RA@high then tag
exit 2

$ nen parse futon --repo <reference-repo> "ZZ@high"
nen: 'ZZ' does not resolve against this registry's product_codes ($comment, BC, BS, RA, RB, RC, KC)
or its consumers. Resolving it to a near match would point a mutating run at the wrong backlog.
exit 2

$ nen parse futon --repo <reference-repo> "RA@high then tag"
nen: 'then tag' is refused against '<product-repo-A>' -- the terminal is that repository's own
release machinery, and it is not the one you are standing in (<reference-repo>). Try the
corrected build-only line:
  try: RA@high
exit 2
```

### 1.10 Case-insensitivity

```
$ nen parse futon --repo <reference-repo> "kp@HIGH+ then TAG"
nen: 'then tag' is refused against '<product-repo-A>' -- ... (same self-mismatch as 1.9's last row)
  try: kp@high+
exit 2
```
The band and terminal both parsed correctly regardless of case (confirmed by the value echoed in
the refusal, `tag`, and by the corrected line preserving `high+`) — the refusal fires on the same
self-mismatch as § 1.9, not on casing. The corrected line preserves the caller's own casing (`kp`,
not `RA`).

### 1.11 `--json`

```
$ nen parse futon --repo <reference-repo> "RA@high+" --json
{
  "repo": "<product-repo-A>",
  "code": "RA",
  "isSelf": false,
  "band": { "severity": "high", "plus": true, "severities": ["critical", "high"] },
  "terminal": null
}
```
```
$ nen parse futon --repo <reference-repo> "@medium" --json
{
  "repo": "<reference-repo>",
  "code": null,
  "isSelf": true,
  "band": { "severity": "medium", "plus": false, "severities": ["medium"] },
  "terminal": null
}
```

## 2. `nen backlog fetch` / `nen backlog order` — live against the real backlog

```
$ export GH_TOKEN=$(gh auth token)
$ nen backlog fetch --repo-slug <reference-repo> --limit 10 --json
```
returned 10 rows (capped, `"truncated": true`), including:
```
{ "issueNumber": 939, "title": "[Machinery] Nothing guards against bash 4 constructs, ...",
  "labels": ["bankai:bug","bankai:severity/medium","bankai:agent/kisuke"],
  "prNumbers": [925], "createdAt": "2026-09-01T23:47:08Z" },
{ "issueNumber": 937, "title": "[Canon] Record the ruling that BC-11 does not bind a patch ...",
  "labels": ["documentation","bankai:severity/high","bankai:agent/yamamoto"],
  "prNumbers": [940], "createdAt": "2026-09-01T22:55:36Z" }
```
This is the live pairing `SKILL.md` § 0/§ 5 cites: issue `#937` (high) links `PR #940`, opened by
the maintainer (`zheref`) — a PR this run's own authorship model matches. Issue `#939` (medium)
links `PR #925`, opened by `app/kisuke-bankai[bot]` **before the freeze** — the § 0 legacy exception,
concretely.

**Full unfiltered severity counts**, fetched via `gh issue list --repo <reference-repo> --state
open --label bankai:severity/<sev> --limit 100 --json number | jq length` for each band, and the
whole-repo total the same way (`--limit 200`, no label filter):

| Severity | Open count |
|---|---|
| `critical` | 0 |
| `high` | 7 |
| `medium` | 60 |
| `low` | 14 |
| (no `bankai:severity/*` label — untriaged) | 7 |
| **Total open issues** | **88** |

Counts sum exactly (`0+7+60+14+7 = 88`); a direct check confirmed no open issue carries more than
one `bankai:severity/*` label. Only 2 PRs are open on the whole repo at the time of this port
(`#925`, `#940` — the same two named above); no issue in the `high` band besides `#937` carries an
open PR.

```
$ nen backlog order --rows-from rows.json --severity-order "critical,high,medium,low" --blocks "" --affects-consumers ""
1. 937  severity=high    2026-09-01T22:55:36Z
2. 938  severity=medium  2026-09-01T23:19:42Z
3. 939  severity=medium  2026-09-01T23:47:08Z
```
`rows.json` was a 3-row slice of the real fetch above (`937`, `938`, `939`); the verb ranked the
`high` row first and tie-broke the two `medium` rows by age (`938` created before `939`) — exactly
`backlog-loop`'s own priority order (severity, then blocks/consumer-impact/age).

## 3. `nen label apply` — contract only (mutating; never exercised against `<reference-repo>`)

```
$ nen label --help
nen label apply <object-ref> --label <name> --repo-slug <owner/name> [--reason <text>] [--ledger <path>] [--run]
```
Flag surface matches `SKILL.md` § 2/§ 4's calls exactly: `<CODE>-IS-#<N>` (or `-PR-#<N>`), `--label`
checked against the target's `schemas/labels.json` before anything is attempted, `--reason` logged
to the ledger (not sent to GitHub), and `--run` required or nothing is written (dry-run records
`outcome:"dry-run"`). Confirmed live that `<reference-repo>` carries the labels this port names
(`schema check`, § below) — never applied.

## 4. `nen pr ready` — live against both of `<reference-repo>`'s real open PRs

```
$ export GH_TOKEN=$(gh auth token)
$ nen pr ready BC#940 --repo <reference-repo> --gates <hatsu>/contracts/reference.gates.json --explain
<reference-repo>#940: ready
  head 8831f0b867dcddda64c3d28315c3d5c746c2ee9b · reviewers sasuke,tenma,copilot · approvers sasuke,tenma
  1  ready  CON-42/1          Mergeable
  2  ready  CON-32(a)         Every reported check green, on the latest run per check name
  3  ready  CON-32(b)         No configured reviewer's requested round has stalled
  4  ready  CON-32(b)         No configured reviewer's round owed at the current head
  5  ready  CON-32(b)/CON-16  Every approving reviewer's latest round is an APPROVE at the current head
  6  ready  CON-32(d)         Zero unresolved review threads
exit 0
```
`BC#940` is opened by the maintainer (`zheref`), matching this run's own authorship model (§ 0).

```
$ nen pr ready BC#925 --repo <reference-repo> --gates <hatsu>/contracts/reference.gates.json --explain
<reference-repo>#925: not-ready: required checks reported but are not all green (CON-32a)
  head 702868f12487fa189b7bf0e35fc140391c19fd24 · reviewers sasuke,tenma,copilot · approvers sasuke,tenma
  1  ready       CON-42/1  Mergeable
  2  FAILED      CON-32(a) Every reported check green, on the latest run per check name
        └ not-ready: required checks reported but are not all green (CON-32a)
  3  unevaluated CON-32(b) ...
exit 1
```
`BC#925` is opened by `app/kisuke-bankai[bot]` — the § 0 legacy exception: a pre-existing
CI-authored PR this port never created and never drives, reported here only because its issue
(`#939`) is in the fetched sample.

## 5. `nen loop slots` — both budgets, live, futon's own caps as defaults

Efforts-file schema, confirmed live (`nen loop slots --help`): a JSON array of `{"id", "plane":
"ci"|"local", "prOpen": bool, "ready": bool, "prompted": bool}`. The verb's own contract, quoted from
that same `--help`: *"A CI slot frees when the PR OPENS ... A LOCAL slot frees only when the PR is
READY and the human has been PROMPTED."* Readiness is irrelevant to the CI plane's own free rule.

```
$ nen loop slots --efforts efforts.json --ci-cap 2 --local-cap 7
ci: 1/2 occupied, 1 free
    RR-IS-950: released, but no PR yet
local: 6/7 occupied, 1 free
    RR-IS-201: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
    RR-IS-203: ready, but the human has not been prompted -- readiness nobody was told about is not a handover
    RR-IS-204: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
    RR-IS-205: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
    RR-IS-206: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
    RR-IS-207: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
freed: RR-IS-939, RR-IS-202
exit 0
```
`efforts.json` carries **one CI-plane row that genuinely models the live `BC#925` fact** —
`RR-IS-939` (`<reference-repo>` issue `#939`'s own number), `prOpen: true, ready: false` — plus **one
clearly-synthetic CI-plane row with no live counterpart**, `RR-IS-950`, `prOpen: false`, to
demonstrate the occupied case; and six clearly-synthetic local-plane rows to demonstrate the cap
boundary. The run itself never fabricated seven real local PRs.

> **Correction (M1, adversarial review).** An earlier version of this section named the
> occupied-CI row `RR-IS-102` and described it as *"modelled on the live `BC#925` fact (open, not
> ready)"* — but `BC#925` **is** open (`PR-#925`, verified live, § 2/§ 4 above), and the verb's own
> contract (quoted above) frees a CI slot the moment the PR opens, regardless of readiness. A row
> claiming to model `BC#925` while sitting at `prOpen: false` was simply inconsistent with itself,
> and the earlier transcript never actually showed what its own prose claimed. Rebuilt above: the
> truthful `BC#925` row (`RR-IS-939`, `prOpen: true`) now shows up in `freed:` where the contract
> puts it, and the occupied-CI example (`RR-IS-950`) is honestly labelled synthetic instead of
> borrowing a live fact it didn't match. The occupied/free counts (`ci: 1/2`, `local: 6/7`) are
> unchanged from the earlier section — only which row is which, and what each is honestly said to
> model, changed. `SKILL.md` § 6's own prose is corrected to match.

**Confirmed `--ci-cap`/`--local-cap` defaults, run with no override flags at all**:
```
$ nen loop slots --efforts efforts.json
ci: 1/2 occupied, 1 free
local: 6/7 occupied, 1 free
```
Identical to the explicit `--ci-cap 2 --local-cap 7` run — **the binary's own defaults already are
`futon`'s stated caps**, unlike `hatsu:build`'s finding for the same verb (its own local-plane
default is `7`, and `build` needs `--local-cap 2` to enforce its stricter own limit). `futon` passes
the flags explicitly anyway, as a stated contract rather than a silent reliance on a default that
happens to match today.

**Both budgets full**, separately reported and both binding:
```
$ nen loop slots --efforts efforts_full.json --ci-cap 2 --local-cap 7
ci: 2/2 occupied, 0 free  <- BINDING
    RR-IS-950: released, but no PR yet
    RR-IS-951: released, but no PR yet
local: 7/7 occupied, 0 free  <- BINDING
    RR-IS-201: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
    RR-IS-203: ready, but the human has not been prompted -- readiness nobody was told about is not a handover
    RR-IS-204: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
    RR-IS-205: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
    RR-IS-206: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
    RR-IS-207: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
    RR-IS-208: PR open but not ready -- nothing else is behind a locally-authored PR, so this run still owns it
exit 1
```
Both CI rows here are clearly-synthetic no-PR-yet rows — a genuinely-open CI PR would just free its
own slot, so filling the CI plane to capacity necessarily means two rows with no live counterpart,
never two facts like `BC#925`.

## 6. `nen release preflight` / `nen fanout` — confirmed as `getsuga`'s own verbs, not `futon`'s

```
$ nen release --help
...
preflight:
  Every precondition of the release preflight table, checked and reported whole -- never the first
  failure (getsuga SKILL.md §2).
...
$ nen fanout --help
compute:
  ... (getsuga SKILL.md §7).
```
Both `--help` blocks cite `getsuga SKILL.md` by name and section, in the binary's own documentation
— not inferred from this port's own reading of the old skill. `futon` never calls either verb; § 8
of `SKILL.md` hands the whole terminal to `hatsu:getsuga` once its own single precondition (no
locally-authored PR in the band short of Ready) is clear.

## 7. Residue — no `nen` verb, or deliberately left to judgment

- **Severity/mode reasoning** (which severity an untriaged issue gets, which mode a label maps to)
  and the **G5 diagnosis** stay judgment — the shared brief's own boundary: `nen` computes and
  verifies, it never decides what only judgment can.
- **Keeping exactly one `bankai:stage/*` label on an object at a time** (`CON-9`) is not enforced
  by `nen label apply`, which only ever applies and logs the one label it is given — same finding
  `hatsu:build` § 11 already recorded for its own identical calls.
- **Sequencing two efforts that would touch the same file** has no verb — this run's own judgment,
  same as `backlog-loop`'s own conflict discipline.
- **The § 1.5–1.8 registry-owner code-resolution gap** is filed against the binary (three verbs
  now share the family), not routed around by hand beyond the documented corrected forms.

## What could not be verified live

- **`nen wake fire` / `nen wake verify`** — contract-inspected against `--help` only; never fired at
  `<reference-repo>` (mutating, forbidden by the shared brief). Not exercised by a real stalled review
  round in this port session, since `futon`'s own PRs' escalation path is `hatsu:drive`'s — `hatsu:sharingan` since `v0.5.0` (itself
  A/B'd on its own branch).
- **`nen release preflight` / `nen fanout compute`** — confirmed by `--help` text only (§ 6); never
  run, since both are `getsuga`'s own verbs and out of this skill's scope entirely.
- **A real medium+ / low-band run to completion** — the live `medium` band alone is 60 issues; this
  port verified the mechanics (fetch, order, parse, readiness, concurrency) on samples and on the
  two real open PRs, not a full end-to-end clearance of any band (out of scope for a build-port; the
  skill's own mechanics are what this evidence is for).


## Dated verification, 2026-09-28 — `nen parse futon` at nen 0.15.0 (label, `c++`, chain, gate lines)

Run live in the hatsu checkout (`--repo .`, origin `zheref/hatsu`, `nen repo classify` → `kind: process`),
binary `nen 0.15.0`. Transcripts verbatim.

```text
$ nen parse futon --repo . "hatsu@bug"
repo: zheref/hatsu
label: bug (exact match, no expansion)
terminal: (none -- build-only)
exit=0

$ nen parse futon --repo . "hatsu@c++"
repo: zheref/hatsu
label: c++ (exact match, no expansion)
terminal: (none -- build-only)
exit=0

$ nen parse futon --repo . "hatsu@bug then getsuga+mugetsu"
repo: zheref/hatsu
label: bug (exact match, no expansion)
then: skills getsuga -> mugetsu (existence and authority are the caller's to check)
  gate: getsuga allowed ('process' is an allowed repo kind for 'getsuga')
  gate: mugetsu allowed ('process' is an allowed repo kind for 'mugetsu')
exit=0

$ nen parse futon --repo . "hatsu@high+ then getsuga+kagutsuchi@testflight+mugetsu@github"
repo: zheref/hatsu
band: high+ -> critical, high
then: skills getsuga -> kagutsuchi@testflight -> mugetsu@github (existence and authority are the caller's to check)
  gate: getsuga allowed ('process' is an allowed repo kind for 'getsuga')
  gate: kagutsuchi allowed ('process' is an allowed repo kind for 'kagutsuchi')
  gate: mugetsu allowed ('process' is an allowed repo kind for 'mugetsu')
exit=0

$ nen parse futon --repo . "hatsu@bug then aka+mukai"
repo: zheref/hatsu
label: bug (exact match, no expansion)
then: skills aka -> mukai (existence and authority are the caller's to check)
exit=0

$ nen parse futon --repo . "hatsu@bug then getsuga+getsuga"
repo: zheref/hatsu
label: bug (exact match, no expansion)
then: skills getsuga -> getsuga (existence and authority are the caller's to check)
  gate: getsuga allowed ('process' is an allowed repo kind for 'getsuga')
  gate: getsuga allowed ('process' is an allowed repo kind for 'getsuga')
exit=0

$ nen parse futon --repo . "@bug then tag"
repo: zheref/hatsu
label: bug (exact match, no expansion)
terminal: tag
exit=0
```

`--json` for the two-step chain carries `then: {kind: "skills", steps: [{skill: "getsuga", target: null,
gate: {allowed: true, kind: "process", reason: …}}, {skill: "mugetsu", …}]}`, `band: null`, `label: "bug"`,
`terminal: null`. Read against the skill: `c++` is one label, not `c+` with `+`; `aka` and `mukai` steps
carry no `gate` because `futon.advanceGo` does not list them (§ 8's fail-closed rule applies only to a
listed skill); at 0.15.0 the duplicate `getsuga+getsuga` chain is accepted and the `gate` line carries no
`[declared]` suffix — both are the release after v0.15.0 (the duplicate refused, the source printed).

## Dated verification, 2026-10-13 — the register rendered through `--register` at nen 0.21.0 (zheref/hatsu#221)

The futon run `hatsu@model/claude` (26 issues, no `then`) rendered its board through backlog-board § 3's
two-pass path on this branch, the desk composed by hand and every fact nen's. Observed, in order:

```
$ nen report data --repo . --base origin/main --target zheref/hatsu --issues 108,135,…,242 \
    --register desk.json --json > data.json
# desk.json carrying gates[0].cleared: false
exit=2  nen report: 'desk.json': gates[0] has 'cleared' of a boolean, not a string. The desk is the
        judgement half of the register -- { variant, title, scope, gate, generatedAtLocal?, … }
# desk.json carrying gates[0].cleared: "no" beside gates[0].asks
exit=2  nen report: 'desk.json': gates[0] has asks AND a 'cleared' line; a gate is cleared only when
        nothing on it is owed.
# desk.json with no cleared line (one DECIDE ask), generatedAtLocal from scripts/report_time.sh
exit=0  timeZone: the register desk set generatedAtLocal, so the desk owns the page's clock;
        generatedDateLocal and timeZone reported as null.
        effortStage: origin/fable/kurapika/ha-221-register-verb exists and no PR row matched this
        branch (--issues reads no pull request); effortStage, gate and stageClass reported as null.
        turnNumber: the 'fable/kurapika/ha-221-register-verb' ledger records no 'report' phase;
        reported as null.
$ jq '{tallyScope,tallyNeedsYou,tallyBlockers,tallyReady,tallyInFlight,footerCount}' data.json
{ "tallyScope": 26, "tallyNeedsYou": 1, "tallyBlockers": 0, "tallyReady": 0, "tallyInFlight": 0,
  "footerCount": "26 objects in scope · 1 ask on the desk" }
$ nen report render --variant register --template templates/rikugan.html --data data.json \
    --out "$TMPDIR/trial.html" --repo .
exit=2  nen report: --out '…/trial.html' resolves outside the repository at <checkout>. … 'report
        render' writes the report INTO the repository it is reporting on and nowhere else
$ nen report render … --out Reports/current.html --repo .
exit=0  wrote Reports/current.html            # 46939 bytes; 26 `HA-IS-#n` rows; the one ask present
```

Read against the skill: the five tallies are the verb's (§ 3's list), an issue-only scope counts no
PR into `tallyReady`/`tallyInFlight`/`tallyBlockers`, and the 26 objects each carry `notation`,
`labelsLine` and the empty `verdict` the template quotes verbatim. Two desk shapes the skill does not
spell out are refused by name: a boolean `cleared`, and a `cleared` line on a gate that still holds
asks. `--out` must sit under `--repo` (a scratch path is refused), which is the render-to-stdout
request zheref/hatsu#215 words for nen. The run's final register is the same two calls over its PRs
and issues once the PRs exist.

## Dated verification, 2026-10-22 — the `--idle` dry run over `hatsu@model/gpt` at nen 0.26.0 (HR-5, the SDD plan's P8 acceptance proof)

The wave-2 *batch profile* row (zheref/hatsu#409, merged in HA-PR-#402) delivered the typed `--idle`
profile, the hard floor on the ask-once rows, the run manifest under the git common directory and the
end-state table, and left its acceptance proof unexecuted: *an eight-issue dry overnight run ends with
every PR at its merge prompt or a named stop, and the register lists every pre-answered row*. This
section is that proof, run on 2026-10-22 from this effort's worktree (branch `fable/kurapika/idle-dry-run`, the PR that lands this section) at
origin/main `1555d54f` (plugin 0.136.0, nen pinned `v0.26.0`, the host bound to it by `scripts/nen_global.sh`).

**What a dry run is here.** `hatsu:futon` has no `--dry-run` modifier (§ 1 below, zheref/hatsu#424),
so the dry run is this session's conduct over the typed line `hatsu:futon hatsu@model/gpt --idle`: every
read-only verb of futon §§ 1–2 and § 6 runs for real, the run manifest is opened and parked for real
under the git common directory, and nothing is authored — no label, branch, worktree, pull request,
comment or push. Each claimable issue's end state is **the first stop its read predicts**, never a built
result. The files written: the manifest (`<git common dir>/hatsu/futon/run-<id>.json`, mode 0600), the register page
(`Reports/current.html`, git-ignored) and, under the session's scratch directory, the two `nen report data`
documents (`data-plain.json`, `data.json`), the desk (`desk.json`), the reshaped order rows and the efforts
files the sections below inline. Every command below is reproducible, given the inputs named beside it, from
a checkout of `zheref/hatsu` at or after `1555d54f` with nen `0.26.0` on `PATH` and `gh` authenticated; the
issue numbers and label counts are those of the live backlog on 2026-10-22 and will differ later.

### 1. The typed line at the pin

```
$ nen parse futon --repo . "hatsu@model/gpt --idle" --json
{ "repo": "zheref/hatsu", "code": null, "isSelf": true, "band": null, "label": "model/gpt",
  "terminal": null, "then": null, "idle": true }
exit=0

$ nen parse futon --repo . "hatsu@model/gpt --idle --dry-run" --json
{ "repo": "zheref/hatsu", …, "label": "model/gpt --idle --dry-run", "terminal": null, "then": null, "idle": false }
exit=0

$ nen backlog fetch --repo-slug zheref/hatsu --label 'model/gpt --dry-run'   # the label the record hands on after its own --idle strip
nen backlog: --label refused: 'model/gpt --dry-run' is not declared in <checkout>/nen/labels.json. A filter
on a label nobody declared would match nothing and read as "no such work", so it is refused instead.
exit=2
$ nen backlog fetch --repo-slug zheref/hatsu --label 'model/gpt --idle --dry-run'   # the parse's own label: the same refusal, exit 2
```

Read against the skill: at the pin `nen parse futon` reads `--idle` itself (`idle: true`; the grammar
WORKFLOW § *Idle batches* called owed to zheref/nen#491 is shipped), and `scripts/futon_effort_record.mts
start` still strips the token before its own parse. Before this section's PR the strip and nen disagreed on a
two-modifier line (the record read `idle` and the shorter label `model/gpt --dry-run`; nen read neither), a
reviewer's finding; `start` now refuses any other `--` token before `then`:

```
$ node scripts/futon_effort_record.mts start --repo . --invocation 'hatsu:futon hatsu@model/gpt --idle --dry-run'
futon-effort: --dry-run is not a futon modifier: only --idle is read before the then clause (zheref/hatsu#424)
exit=1
```

A second modifier beside it is not
grammar: `--dry-run` folds **both** tokens into the label and reads `idle: false`, so a typed
`hatsu@model/gpt --idle --dry-run` is an attended run over a label no file declares, refused at the
fetch — whether the fetch takes the parse's label or the shorter one `futon_effort_record.mts start` hands on after
stripping `--idle` (both shown above; a reviewer's reproduction, 3 of 3). **Finding** — the acceptance proof's "dry run" has no typed form; filed as zheref/hatsu#424.

### 2. The queue — the selector's scope, and only that (futon § 2)

No exact label on the live backlog selects eight open issues, and futon never widens or caps a selector
(§ 11), so the run's scope is the kazaana-shaped `model/gpt`: 18 issues, the largest realistic overnight
queue. The proof's shape holds at any count above the local cap of 7 (§ 5).

| Label | Open issues | Label | Open issues |
|---|---:|---|---:|
| `lang/prose` | 23 | `lang/typescript` · `job/schema` · `job/release` | 5 each |
| `enhancement` | 20 | `model/claude` · `job/onboarding` · `job/ci-cd` | 4 each |
| `model/gpt` | 18 | `job/delivery-ops` · `bug` | 3 each |
| `job/machinery` | 15 | `question` · `job/unit-tests` · `job/security` · `job/documentation` | 2 each |
| `job/prose-authoring` | 6 | eight further `job/` keys | 1 each |

```
$ nen backlog fetch --repo-slug zheref/hatsu --label model/gpt --json
  kept 18 of 30 · filter {labels: [model/gpt], severity: null} · truncated false · issueCount 30 · prCount 1
  issues: 416 415 382 381 380 371 370 361 346 341 331 265 247 246 156 154 148 131
```

**Triage orders only** (a label selector). `zheref/hatsu`'s `nen/labels.json` declares no severity
family, so every row's severity is null and `nen backlog order` sorts by creation time; the verb takes
the reshaped array its own refusal describes, which is residue — one object per fetched row,
`{"id": "HA-IS-#<n>", "number": <n>, "severity": <the bankai:severity/* leaf, else null>, "createdAt": <the row's>}`,
here 18 objects with `severity: null`:

```
$ nen backlog order --rows-from <reshaped rows> --severity-order critical,high,medium,low
1. HA-IS-#131 … 2. #148 3. #154 4. #156 5. #246 6. #247 7. #265 8. #331 9. #341 10. #346 11. #361
12. #370 13. #371 14. #380 15. #381 16. #382 17. #415 18. #416   (severity=(none) on every row)
exit=0
```

**Shape (HR-4)** — `node scripts/issue_body_check.mts --ref HA#<n> --repo . --json` per issue, and the
same call through nen at the pin (`nen issue body-check --ref HA#<n> --target zheref/hatsu
--requirements-from contracts/issue-sections.json --repo . --json`, which returned the same misses on
HA#415 — `ok: true` — and HA#131 — 10 misses): **0 open `OQ-{n}` rows on every issue in scope** (and on
all 30 open issues), so nothing is skipped as *blocked, needs-clarification*; every miss is listed,
never a skip. Misses per issue (kind `common`: the issues predate the catalogue): HA#131 10 · HA#148 7 ·
HA#154 6 · HA#156 10 · HA#246 5 · HA#247 8 · HA#265 8 · HA#331 5 · HA#341 5 · HA#346 9 · HA#361 10 · HA#370 5 · HA#371 5 ·
HA#380 5 · HA#381 5 · HA#382 12 · HA#415 0 · HA#416 0.

**Releasing into build (futon § 4)** — on a target with no stage family the label is refused before any
GitHub call, which is the WORKFLOW § *A target repository with no delivery-stage taxonomy* case futon
§ 4 now names:

```
$ nen label apply 'HA-IS-#131' --label bankai:stage/building --repo-slug zheref/hatsu --repo . --reason 'idle dry run: futon § 4'
nen label: 'bankai:stage/building' is not in <checkout>/nen/labels.json. Declared labels: accessibility, bug, …, model/composer.
exit=2
```

`nen stage check --exclusive --target zheref/hatsu --issues 131,148 --repo . --json` answers the same way
(`declares no '<namespace>:stage/<leaf>' label, so there is no stage family to hold an issue to`, exit 2).

### 3. The manifest, and the pre-answered rows (WORKFLOW § *Idle batches* rule 1)

```
$ node scripts/futon_effort_record.mts start --repo . --invocation 'hatsu:futon hatsu@model/gpt --idle'
futon-effort: run efea4da8cdf46add6037ad864d651814 recorded for zheref/hatsu@model/gpt (idle)
futon-effort: idle profile read from origin/main at 1555d54f57ec4ccf33fe32a50e3cb9f0e50039b8
futon-effort: pre-answered harness-attribution-switch → hold
futon-effort: pre-answered host-nen-link → hold
futon-effort: pre-answered missing-consumer-declaration → default
futon-effort: pre-answered missing-argument → default
futon-effort: pre-answered missing-configuration → default
futon-effort: pre-answered missing-maintainer-choice → hold
futon-effort: pre-answered mode-unknown → default
futon-effort: pre-answered direct-mismatch → default
futon-effort: pre-answered port-drift → hold
futon-effort: pre-answered intake-challenger → hold
futon-effort: pre-answered port-siblings → hold
futon-effort: pre-answered wrap-up → default
futon-effort: pre-answered cleanup-plan → hold
futon-effort: pre-answered publish-offer → refuse
futon-effort: pre-answered spec-capture-scope → hold
futon-effort: pre-answered spec-slice → hold
futon-effort: pre-answered spec-clarify → hold
futon-effort: pre-answered spec-dispatch → hold
futon-effort: pre-answered spec-converge-filing → hold
exit=0
```

**The register of pre-answered rows** — all 19 `ask-once-per-run` rows of `nen/decisions.json`, one
resolution each, read from the committed `nen/workflow.json` of `origin/main` at `1555d54f` (never the
working tree), with the floor holding: `publish-offer` **refuse**; `host-nen-link`,
`harness-attribution-switch` and `missing-maintainer-choice` **hold** (at most); `default` on the six
rows the committed map defaults, each starring an option (`missing-consumer-declaration`, `missing-argument`,
`missing-configuration`, `mode-unknown`, `direct-mismatch`, `wrap-up`), and `hold` on the twelve others —
five of them starred rows the map withholds on purpose (`harness-attribution-switch`, `host-nen-link`,
`cleanup-plan`, `spec-capture-scope`, `spec-converge-filing`; WORKFLOW § 2 `idle`). Resolution counts: hold 12 ·
default 6 · refuse 1 (two reviewers' count of the printed list; the first draft said 13 · 5). The floor itself is enforced by `start`
(`FLOOR` in `scripts/futon_effort_record.mts`; the `futon-effort-guard` fixture's six refusal rows), so a
`publish-offer: default` or a `host-nen-link: default` on the committed file would have ended this
section at `start` with exit 1.

**Where it lives, and its shape.** `/Users/<user>/Code/Agents/hatsu/.git/hatsu/futon/run-efea4da8cdf46add6037ad864d651814.json`
— the git common directory of the repository, shared by every worktree and kept by `hatsu:cleanup` § 4.
Contract `hatsu.futon.run/v0.2`; keys `contract`, `id`, `repo`, `invocation`, `selector`, `startedAt`,
`idle` (`decisions[]{row, resolution}`, `localSlotFrees: "merged"`, `terminal:
"ready-at-prompt-or-integration"`, `budget: {minutes: 480, tokens: 4000000}`, `source: {ref:
"origin/main", commit: "1555d54f…"}`), `prs: []`, `parked: []`. 2,122 bytes at `start`.

**nen's own manifest at the pin, unadopted.** `nen run --help` at 0.26.0 lists `start|append|park|verify|budget`
(contract `nen.run/v0.1`, `<git common dir>/.nen/runs/<run-id>.json`); a `--dry-run` start prints the
document it would write (`idleAnswers`, `prs: []`, `parked: []`) and writes nothing. No Hatsu skill opens
it, so the two records are two files:

```
$ nen loop slots --from-run efea4da8cdf46add6037ad864d651814 --target zheref/hatsu --local-cap 7 --repo . --json
nen: no run 'efea4da8cdf46add6037ad864d651814' at <git common dir>/.nen/runs/efea4da8cdf46add6037ad864d651814.json
-- nothing to count from. A run nobody started is not a run with every slot free.
exit=2
```

**Finding** — WORKFLOW § *Idle batches* rules 4 and 6, § 2 `monitor`, `docs/config/workflow.json.md`
and the catalogue said these verbs were unreleased at the pin; the wording moved with this section, and
the adoption (futon reading nen's manifest, `nen loop slots --from-run`, `nen issue body-check`, no
second `--idle` strip) is zheref/hatsu#423.

### 4. Per issue — how each ended

Per issue the dry read ran futon § 2's shape check, build § 2's mode table, `nen classify status` and
`nen direct resolve` (`--kind process --role canon`, this session's `--surface claude-code --model fable
--effort high`), then read the body for the first row or gate a build would meet. Every `model/gpt`
issue resolves to primary **Sol on Codex (deep)** with the fallback on Claude Code, so every claimable
effort meets `direct-mismatch` on surface and model (and effort on 13 of 18) — pre-answered **default**,
option A *continue here*, recorded, no picker. Two issues (HA#247, HA#381) carry no `lang/` label, so a build
would run `hatsu:classify` § 3 on the missing axis first (a GitHub write a dry run does not make).

| # | Mode (build § 2) | First stop the read predicts | End state |
|---|---|---|---|
| 131 | Transmuter | none; a two-step trusted-guard landing (registration PR, then the workflow PR) | **dry-run merge prompt** · slot 1/7 |
| 148 | Transmuter | `kcov`/`bashcov` absent on the host → row `missing-tool` (autonomous): remedy reported, run continues; AC1 unprovable here | **dry-run merge prompt** · slot 2/7 |
| 154 | Transmuter (`mode-unknown` → default A) | none; AC4's live classifier proof needs a later Ready stack, recorded *unverified live* | **dry-run merge prompt** · slot 3/7 |
| 156 | Transmuter (`mode-unknown` → default A) | none; the live proof deferred by its 2026-10-19 ruling | **dry-run merge prompt** · slot 4/7 |
| 246 | Transmuter | none; item 4 is briefed in a comment, item 5 a comment through the ignore file | **dry-run merge prompt** · slot 5/7 |
| 247 | — (`question`) | a handbook question: briefed, never guessed (futon § 2) | **parked:g5:decide** |
| 265 | — (`question`) | a policy call: which side moves, the check or the ROSTER row | **parked:g5:decide** |
| 331 | Transmuter | the Akatsuki tier catalogue at a pinned tag is not released (no release, no `schemas/tiers.json`) | **parked:g5:dependency** |
| 341 | Transmuter | none | **dry-run merge prompt** · slot 6/7 |
| 346 | Transmuter | none | **dry-run merge prompt** · slot 7/7 |
| 361 | Transmuter | reading (a) or (b) is the maintainer's, asked once on the issue | **parked:g5:decide** |
| 370 | Transmuter | none (HA-PR-#364 merged 2026-10-20) | **waits** → `parked:budget` at 480 min |
| 371 | Conjurer | the cut point: "the maintainer picks" | **parked:g5:decide** |
| 380 | Conjurer | none; AC1 already met by HA-PR-#422 (pin `v0.26.0` ≥ `v0.25.0`), the two prose clauses remain | **waits** → `parked:budget` at 480 min |
| 381 | Transmuter | none; a two-step landing (frozen `pull_request_target` step) | **waits** → `parked:budget` at 480 min |
| 382 | Transmuter | a nen verb (or En's guard extended) must exist first | **parked:g5:dependency** |
| 415 | Transmuter | none | **waits** → `parked:budget` at 480 min |
| 416 | Transmuter | none | **waits** → `parked:budget` at 480 min |

Totals: 18 in scope · 6 parked at the read (4 `g5:decide`, 2 `g5:dependency`; no slot taken) · 12
claimable · 7 claimed (the local plane) · 5 waiting. **Every issue ends at a dry-run merge prompt or a
named stop; no pull request exists, so no verdict exists** (futon § 11: readiness is `nen pr ready`'s
word, never the eye's). The six parks are in the manifest:

```
$ node scripts/futon_effort_record.mts park --repo . --run efea4da8cdf46add6037ad864d651814 --issue 247 --row g5:decide
futon-effort: issue #247 parked:g5:decide
…  (265 g5:decide · 331 g5:dependency · 361 g5:decide · 371 g5:decide · 382 g5:dependency)
```

The five waiting efforts are **not** parked in the manifest: `parked:budget` is written when
`idle.budget.minutes` elapses, and this section ended before it (§ 6); the table projects the row.

### 5. Slots — the local plane at the pin (futon § 6, WORKFLOW § *Idle batches* rule 4)

`nen loop slots` at 0.26.0 reads `monitor.localSlotFrees` (`idle.localSlotFrees` first under a declared
idle profile, else `monitor`'s; the two disagreeing is refused) when `--repo` is passed, prints the rule
and its source, and knows a third value, `stacked-open`. Hatsu's `start` accepts `merged` alone (HR-257).

```
$ nen loop slots --efforts <abs efforts.json> --ci-cap 2 --local-cap 7 --repo . --json
  # efforts.json: one object per claimed effort, HA-IS-#131 #148 #154 #156 #246 #341 #346 —
  # {"id": "HA-IS-#131", "plane": "local", "prOpen": true, "ready": true, "prompted": true, "merged": false, "stacked": false}
  # ("stacked": true on the six above the bottom of the stack)
  local: cap 7 · occupied 7 · free 0 · binding true
  holding[*].why: "PR open, not merged -- this repository frees a local slot only on merge (monitor.localSlotFrees: merged)"
  localSlotFrees: { rule: "merged", source: "<checkout>/nen/workflow.json: monitor.localSlotFrees" }
exit=1

$ nen loop slots --efforts <the same seven with "merged": true> --ci-cap 2 --local-cap 7 --repo . --json
  local: cap 7 · occupied 0 · free 7 · binding false · done: HA-IS-#131 #148 #154 #156 #246 #341 #346
exit=0

$ nen loop slots --efforts <the first file> --ci-cap 2 --local-cap 7 --repo <a scratch copy of the checkout whose nen/workflow.json reads monitor.localSlotFrees: stacked-open> --json
  local: occupied 0 · free 7 · done: the seven · localSlotFrees: { rule: "stacked-open", … }     # illustration only; Hatsu's start refuses the value
exit=0
```

Read against the canon: under `merged` an unattended per-PR or stacked run **holds seven efforts at their
merge prompts until the maintainer merges** — nobody merges overnight — so the rest wait (back-pressure,
futon § 6) and park as `parked:budget` when `idle.budget.minutes` elapses; an integration-branch run
(futon § 5) frees a slot at each local merge instead. This is the proof's eighth-issue shape, and here it is
the eighth to twelfth.

**A reviewer's reproduction, and the fix it forced.** futon § 6's own command passed no `--repo`, and nen
reads `localSlotFrees` from `--repo`'s `nen/workflow.json`, else the cwd's: run from a directory with no
`nen/workflow.json`, the same efforts file read `localSlotFrees: {rule: "ready+prompted", source: "default
(neither idle.localSlotFrees nor monitor.localSlotFrees declared)"}` and freed every slot (`done: [...]`,
exit 0) — the early free HR-257 forbids, reachable the moment this section's PR dropped the old interim hold.
futon § 6 now passes `--repo <target checkout>` and keeps `ready`/`prompted` false whenever the printed rule is
not `merged`; `start` refuses a declared `idle.localSlotFrees` other than `merged` (nen reads that key first). WORKFLOW § *Stacked pull requests* rule 4 (ruling 4 of
2026-10-13) counts a stacked effort's slot freed at PR-open on its stacked base, which would author
all twelve in one night and is what nen's `stacked-open` encodes. The two rulings disagree and the
`start` floor sides with HR-257. **Finding** — filed as zheref/hatsu#425, a G4 reading; this section
rules nothing. The 2026-09-02 § 5 transcript above (nen 0.1.0: *frees only when the PR is READY and the
human has been PROMPTED*) is the `ready+prompted` default nen still names first in its help.

Overlap: every plugin-shipped effort bumps the two manifests and regenerates the mirrors (WORKFLOW
§ *Stacked pull requests* rule 1), so the seven would form one stack in queue order; `nen wc overlap
--efforts <a,b,…> --repo .` computes it once branches exist (none do in a dry run) and reads
`alwaysOverlaps` from `nen/workflow.json`, which Hatsu does not declare — residue until HA#423.

### 6. `status`, and the wall-clock budget line

```
$ node scripts/futon_effort_record.mts status --repo . --run efea4da8cdf46add6037ad864d651814
{ "contract": "hatsu.futon.run/v0.2", "id": "efea4da8cdf46add6037ad864d651814", "repo": "zheref/hatsu",
  "invocation": "hatsu:futon hatsu@model/gpt --idle", "selector": "model/gpt",
  "startedAt": "2026-10-23T00:59:12.868Z",
  "idle": { "decisions": [ …19 rows… ], "localSlotFrees": "merged", "terminal": "ready-at-prompt-or-integration",
            "budget": { "minutes": 480, "tokens": 4000000 }, "source": { "ref": "origin/main", "commit": "1555d54f…" } },
  "prs": [], "parked": [ {issue 247, g5:decide}, {265, g5:decide}, {331, g5:dependency}, {361, g5:decide}, {371, g5:decide}, {382, g5:dependency} ],
  "manifest": "present", "elapsedMinutes": 7, "overBudget": false }
exit=0
```

**Budget line**: run `efea4da8…` started `2026-10-23T00:59:12Z` (UTC; 19:59 America/Bogota on
2026-10-22); `status` at +7 minutes read `overBudget: false` against `idle.budget.minutes: 480` — one
meaning, wall-clock run age; the five waiting efforts park as `parked:budget` at
`2026-10-23T08:59:12Z`. `idle.budget.tokens` was not summed: `nen run budget` reads the usage ledgers
against nen's own manifest, which this run did not open (HA#423).

### 7. The register (futon § 9, backlog-board § 3)

```
$ "$hatsu_root/scripts/gh_token_env.sh" nen report data --repo . --base origin/main --target zheref/hatsu \
    --issues 131,148,154,156,246,247,265,331,341,346,361,370,371,380,381,382,415,416 --json > data-plain.json   # generatedAt 2026-10-23T01:08:26Z
$ "$hatsu_root/scripts/report_time.sh" --at 2026-10-23T01:08:26.202Z
generatedAtLocal=Thu 22 Oct 2026 · 20:08 America/Bogota (UTC-05:00)
$ "$hatsu_root/scripts/gh_token_env.sh" nen report data --repo . --base origin/main --target zheref/hatsu --issues <the 18> --register <abs desk.json> --json > data.json
  tallyScope 18 · tallyNeedsYou 6 · tallyBlockers 0 · tallyReady 0 · tallyInFlight 0 · footerCount "18 objects in scope · 6 asks on the desk"
$ nen report render --variant register --template templates/rikugan.html --data data.json --out Reports/current.html --repo .
wrote Reports/current.html   # 52,886 bytes
```

The desk (the judgement half) carries the six `DECIDE` asks on G5 (one per parked issue, one star each),
G4 cleared (*a dry run opens no PR; 7 of 12 claimable efforts would stand at their merge prompts*), G3
cleared (*never reached under `--idle` | publish-offer → refuse*), G1 cleared, one `rows` entry per issue
with its end state as the `thought`, and **`legendRows` listing all 19 pre-answered rows** (`<row> →
<resolution>` with the reason) plus the four end-state marks. Every fact on the page is nen's. Published
as the surface's artifact: https://claude.ai/artifact/VxNANH2JL5CUyEzxRLst7j (private to the maintainer).

### 8. Findings, and what moved with this section

| # | Behaviour against the canon | Disposition |
|---|---|---|
| F1 | `--dry-run` is not futon grammar; beside `--idle` it folds both into the label and reads `idle: false` | zheref/hatsu#424 |
| F2 | WORKFLOW § *Idle batches* (intro, rules 4, 6), § 2 `monitor`, § *Recorded Futon delivery ownership*, `docs/config/workflow.json.md`, the catalogue rows, `nen/workflow.json`'s `$localSlotFrees` and the record's comments called zheref/nen#486 through zheref/nen#491's verbs unreleased; nen 0.26.0 ships them | wording moved here; the adoption is zheref/hatsu#423 |
| F3 | futon § 4 applied `bankai:stage/building` unconditionally; a target with no stage family refuses it before any GitHub call | futon § 4 names WORKFLOW's exception |
| F4 | HR-257 `merged` (every run, the `start` floor) vs WORKFLOW § *Stacked pull requests* rule 4 (a stacked slot frees at PR-open); nen offers `stacked-open` | zheref/hatsu#425 (G4) |
| F5 | no exact label selects eight open issues | not a defect; the scope is 18, stated in § 2 |
| F6 | `nen backlog order` takes a reshaped array and a `--severity-order` on a repository with no severity family | residue (the verb names the reshape); not a defect |
| F7 | futon § 6's slot command passed no `--repo`, so with the interim hold dropped a run from another cwd freed slots at `ready+prompted` (two reviewers, live) | fixed: `--repo <target checkout>` and the hold whenever the printed rule is not `merged`; `start` holds `idle.localSlotFrees` to the floor too |
| F8 | the record's `--idle` strip read a two-modifier line as idle with a shorter label while nen read neither | fixed: `start` refuses any other `--` token before `then` (exit 1) |
| F9 | clauses the first pass missed: WORKFLOW's `budget` row, § *Stacked pull requests* rule 4, the `v0.24.0` repin paragraph, `docs/config/plugin-registries.md`, `emperor-time` § 6 | fixed in the same PR |
| F10 | futon § 4's new conditional named no detecting read and no fall-through; § 1's trim had dropped the empty-selector branch | fixed: `nen stage check` exit 2 detects, an absent or unloadable `nen/labels.json` is a G5; the branch restored |

**Review.** hanten on the first commit (Opus, deep): Nobunaga 11 · Feitan 0 · Chrollo 4 (with the totality
pass) · Phinks 1 — 16 findings, every one fixed in the settlement commit, none pushed back or deferred;
Feitan's gitleaks and dependency-audit rows stayed not scanned (no host gitleaks; no `claude-code-plugin` row).

**Not exercised live**: an actual overnight run (nothing was authored, so no `nen pr ready`
verdict and no En loop exist); `parked:budget` written by the clock (the budget had not elapsed); the
`stacked-open` rule on Hatsu's own file (refused by the floor; shown on a scratch copy only); any GitHub
write of a real run (the stage label, classify on HA#247 and HA#381, the briefing comments on HA#246).
