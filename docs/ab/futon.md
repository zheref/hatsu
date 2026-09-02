# A/B evidence — `futon`

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

*Paths sanitized: this machine's local absolute paths appear as `<checkout>` (the parent directory of the repository checkouts), `<cache>` (the nen binary cache) and `<scratch>` (a throwaway scratch directory). Private repository names are redacted to placeholders (see [`docs/PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md)); nothing else below is altered -- the transcripts are otherwise verbatim.*

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
repo: <product-repo-A> (KP)
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
$ nen parse futon --repo <reference-repo> "KP@high then tag" --self "<product-repo-A>"
repo: <product-repo-A> (KP)
band: high -> high
terminal: tag
```
exit `0`. Same with `tag+fanout`:
```
$ nen parse futon --repo <reference-repo> "<product-repo-A>@high then tag+fanout" --self "<product-repo-A>"
repo: <product-repo-A> (KP)
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
A real **consumer** code (`KP`) resolves without issue (§ 1.2). The pattern: the code-lookup path
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
$ nen parse futon --repo <reference-repo> "KP@urgent"
nen: 'urgent' is not a severity. Expected one of critical, high, medium, low, optionally suffixed '+'.
  try: KP@critical
exit 2

$ nen parse futon --repo <reference-repo> "KP@high then release"
nen: 'then release' is not a recognized terminal. Only 'then tag' and 'then tag+fanout' are accepted.
  try: KP@high then tag
exit 2

$ nen parse futon --repo <reference-repo> "ZZ@high"
nen: 'ZZ' does not resolve against this registry's product_codes ($comment, BC, BS, KP, KN, KW, KC)
or its consumers. Resolving it to a near match would point a mutating run at the wrong backlog.
exit 2

$ nen parse futon --repo <reference-repo> "KP@high then tag"
nen: 'then tag' is refused against '<product-repo-A>' -- the terminal is that repository's own
release machinery, and it is not the one you are standing in (<reference-repo>). Try the
corrected build-only line:
  try: KP@high
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
not `KP`).

### 1.11 `--json`

```
$ nen parse futon --repo <reference-repo> "KP@high+" --json
{
  "repo": "<product-repo-A>",
  "code": "KP",
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
  round in this port session, since `futon`'s own PRs' escalation path is `hatsu:drive`'s (itself
  A/B'd on its own branch).
- **`nen release preflight` / `nen fanout compute`** — confirmed by `--help` text only (§ 6); never
  run, since both are `getsuga`'s own verbs and out of this skill's scope entirely.
- **A real medium+ / low-band run to completion** — the live `medium` band alone is 60 issues; this
  port verified the mechanics (fetch, order, parse, readiness, concurrency) on samples and on the
  two real open PRs, not a full end-to-end clearance of any band (out of scope for a build-port; the
  skill's own mechanics are what this evidence is for).
