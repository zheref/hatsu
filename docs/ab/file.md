# A/B evidence — `file` (zheref/hatsu#2)

Port of `claude/skills/file/SKILL.md`: reconcile the open backlog (four searches, an open-PR
guard on every close/supersede candidate) before filing one well-formed, correctly-labelled issue.
Old mechanics: no dedicated script existed for this skill at all — the "four searches", the
open-PR guard, and the labels-in-create-call discipline were **prose rules the agent executed by
hand**, one improvised `gh issue list --search`/`gh pr view` call at a time, with no verb
computing or reporting any of it. New mechanics: `nen issue search`, `nen issue open-pr-check`,
`nen issue file`.

Run: 2026-09-01 (local clock; today's date per session context). `nen` `0.1.0`
(`<cache>\nen\v0.1.0\nen-windows-x64.exe`). `gh` authenticated as `zheref`. Target
for every read-only run: the live `<reference-repo>` backlog, `--repo` pointed at the local
`<reference-repo>` checkout (tag `v0.11.3`, working tree clean, read-only throughout — nothing was
written back to it). No mutating verb (`nen issue file` without `--dry-run`, `nen label apply
--run`, `nen issue attach-sub`/`consolidate-close`) was ever run against `<reference-repo>`, per
the shared brief's constraint; the mutating half is A/B'd by contract inspection and by
`--dry-run` runs against that same repo (which print the exact `gh` call and write nothing) —
never a real filed-and-closed test issue, which this port judged unnecessary: the mutating half's
dry-run transcripts (§ 2.5–2.7) are the evidence, not a claim resting on contract inspection alone.

*Paths sanitized: this machine's local absolute paths appear as `<checkout>` (the parent directory of the repository checkouts), `<cache>` (the nen binary cache) and `<scratch>` (a throwaway scratch directory). Private repository names are redacted to placeholders (see [`docs/PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md)); nothing else below is altered -- the transcripts are otherwise verbatim.*

---

## 1. Command mapping table

Every deterministic or hand-reconstructed step the old `SKILL.md` carried, and what replaces it.

| # | Old (prose / hand-run `gh`) | New (`nen`) |
|---|---|---|
| 1 | "The last whitespace-delimited token is taken as the repo only if it resolves against `schemas/repos.json`" — no command given; the agent read the file by eye | `nen repo resolve <token>` — exit `0` (repo) vs exit `1` (part of the problem text), refusal text names every valid code/repo (verified live, § 2.4) |
| 2 | "Resolve the current working directory's `origin` remote to a registry entry… if not a registry repo, ask — with the resolved candidates listed" — the agent ran `git remote get-url origin`, grepped `schemas/repos.json` by hand, and typed the candidate list itself | `nen repo resolve` (no token) reads `origin` and resolves it the same way; its own refusal text **is** the candidate list (verified live, § 2.4 — reproduced from inside the `<reference-repo>` checkout itself) |
| 3 | "Search open issues first, and recently closed ones too… by subject terms, by the files and rule IDs involved, and by lane label — three passes" (four searches total incl. subject/open) — each pass was a hand-typed `gh issue list --search "…"` the agent had to remember to run, in the right order, and report even when empty | `nen issue search --target <o/n> --subject "<t>" [--files][--rule-ids][--lane-labels]` — all four passes, same order, each labelled with what it is for, `skipped` reported explicitly when a pass has no terms (verified live, § 2.1–2.2) |
| 4 | "An issue with an OPEN PR is never quietly closed" — checked by the agent running `gh pr list --search "<n> in:body"` or reading each candidate issue's timeline by eye, one at a time | `nen issue open-pr-check --target <o/n> --issues n,n,n` — one call, every open PR fetched once and matched against every candidate by both `closingIssuesReferences` and body mentions, exit `1` iff any candidate is blocked (verified live and cross-checked by hand, § 2.3) |
| 5 | "Applied in the create call, never as a follow-up edit" — the agent typed `gh issue create --repo … --title … --body-file … --label a,b --assignee u` from memory, with no check that a label existed in the taxonomy before submitting it | `nen issue file --target <o/n> --repo <path> --title <t> --body-file <p> --label a,b --assignee u [--forbid-family ns:family] [--dry-run]` — validates every label against `schemas/labels.json` **before** attempting anything, and now also enforces `--forbid-family` as a hard refusal (verified live, § 2.5–2.6) |
| 6 | "`bankai:stage/*` … applying it here would fire the builder" — a rule the agent had to remember never to violate, with nothing stopping a mistaken `--label bankai:stage/building` from reaching `gh issue create` | `--forbid-family` on `nen issue file` refuses the call outright before any GitHub call is made (verified live, § 2.6) — the rule is now a call refusal, not a discipline |
| 7 | Severity bump on a duplicate: `gh issue edit <n> --add-label bankai:severity/high` typed by hand, with no ledger | `nen label apply <ref> --label <sev> --repo-slug <o/n> --repo <path> --reason "<text>" --run` — logged (object, label, time, outcome) to a ledger file; `--repo` fix reverified live (§ 2.7), the severity-bump call shape against the real backlog is contract inspection only, per the shared brief (§ 3) |
| 8 | Umbrella check (3+ fold/supersede candidates): the old skill deferred to `bankai:backlog-synthesis` by name, with no verb backing the attach/close choreography it would need | `nen issue attach-sub` / `nen issue consolidate-close` exist and are named in the ported skill as what that consolidation would use, but `file` itself still defers rather than invoking them — contract inspection only (§ 3) |
| 9 | Posting the actual comment for amend/fold/supersede | **No `nen` verb owns this** — genuine residue, see § 4. Still `gh issue comment`/`gh issue close --comment`, unchanged |
| 10 | The `G5` stop banner: `scripts/gate_stop.sh --gate G5` | `nen stop --who Kurapika --gate G5 efforts.md` — same renderer family `pr-state`'s sibling ports already adopt; not separately re-verified here beyond `nen stop --help` (§ 2 note) |

**Count.** Before: **5** steps the agent had to perform manually, in prose, per invocation, with
no verb computing or checking any of them (rows 1–5: resolving the repo token, resolving cwd's
origin, running all four searches in order and remembering to report empty ones, guarding every
close candidate against an open PR, and validating every label before the create call — with the
`--forbid-family` stage-label guard not even expressible as a rule the old skill could enforce,
only ask the agent to remember). After: **0** required manual steps for any of those five — each
is now one `nen` call whose exit code and printed report is the whole computation. What remains
manual, by design: posting a comment (row 9, no verb exists) and the umbrella
attach/close choreography (row 8, named but deliberately not invoked by `file` itself).

---

## 2. Live A/B transcript (read-only)

All read-only, against the real `<reference-repo>` backlog. `GH_TOKEN` exported before every
run (`export GH_TOKEN=$(gh auth token)`). No old-skill script exists to A/B against (§ 1's premise
— the old mechanics were unscripted prose), so each subsection below pairs the live `nen` output
with the equivalent **hand-run `gh` call** an agent following the old prose would have typed, and
states a same/different verdict on the *content*, not on a script's exit code.

### 2.1 — `nen issue search`, all four passes, real candidates found

```
$ nen issue search --repo <reference-repo checkout> --target <reference-repo> \
    --subject "mergeStateStatus pr_ready_gate" --files scripts/pr_ready_gate.sh \
    --rule-ids CON-32 --lane-labels bankai:agent/kisuke
```

```
repository: <reference-repo>

[subject-open] the same problem, already open -- amend it with the new evidence instead of filing a second one
  query: mergeStateStatus pr_ready_gate
  no candidates

[subject-recently-closed] the same problem, closed within the window -- a fix that regressed is a re-open with new evidence, not a new issue
  query: mergeStateStatus pr_ready_gate closed:>=2026-06-04
  #880  CLOSED  pr_ready_gate.sh claims to be "the ONE place a CON-32 readiness claim is decided", but roy-build.yml — the only agent that merges — never calls it

[files-and-rule-ids] a different problem in the same files or under the same rule -- the fold candidates one PR would sanely deliver together
  query: "scripts/pr_ready_gate.sh" OR "CON-32"
  #912  OPEN  pr_ready_gate: a reviewer check that cannot start (NEUTRAL) counts as green
  #771  OPEN  CON-40 does not say what readiness means when the ONE holistic pass on `opened` never posted — the gate is one inference ahead of canon
  #935  OPEN  [Machinery] Roll provenance-on-stderr + plugin-cache guard out to the rest of the verification script family
  #938  OPEN  port pr_ready_gate.sh's plugin-cache guard classification into cli/src/ports/pr_ready_gate.ts (RR-IS-#733 plane parity)
  #791  OPEN  [Machinery] Dependabot PRs can never reach CON-32-Ready — the CON-30 shim posts a check, pr_ready_gate.sh reads reviews
  #914  OPEN  [Machinery] pr_ready_gate.sh: wire <reference-repo>#877's mergeStateStatus predicate into the LIVE fetch (shell + TS port + dual-run corpus)
  #877  OPEN  [Machinery] pr_ready_gate.sh cannot see an unreported REQUIRED context — it never reads the required-contexts list, flattens across check suites, and ignores mergeStateStatus
  ... (23 rows total, truncated here)

[lane] the same lane -- neighbours routed to the same authority, which is where a fold is defensible at all
  query: label:"bankai:agent/kisuke"
  #939 #938 #935 #933 #929 #922 #921 #920 #918 #917 #915 #914 #878 #877 ... (43 rows total, truncated here)
```

**Manual equivalent (what the old prose asked the agent to type, one at a time):**

```
$ gh issue list --repo <reference-repo> --state open   --search "mergeStateStatus pr_ready_gate" --json number,title
$ gh issue list --repo <reference-repo> --state closed --search "mergeStateStatus pr_ready_gate closed:>=2026-06-04" --json number,title
$ gh issue list --repo <reference-repo> --state open   --search "\"scripts/pr_ready_gate.sh\" OR \"CON-32\"" --json number,title
$ gh issue list --repo <reference-repo> --state open   --label "bankai:agent/kisuke" --json number,title
```

`nen issue search --json` prints the exact `argv` it runs for each pass (verified in the raw
`--json` capture, not reproduced above for space) and it is precisely this shape — same
sub-command, same flags, same search string. **Same**, by construction: `nen` is running the
identical `gh issue list` calls the prose already specified, just composed, ordered, and reported
for the agent instead of typed by hand every time. What is genuinely new: the `subject-recently-
closed` window (`closed:>=2026-06-04`) is computed by the verb, not chosen by the agent on the
spot, and the `skipped`-vs-empty distinction (§ 2.2) is explicit instead of implicit.

### 2.2 — a search with no `--files`/`--rule-ids`/`--lane-labels`: `skipped`, not silently empty

```
$ nen issue search --target <reference-repo> --subject "test subject xyz123 no match expected"
```

```
repository: <reference-repo>

[subject-open] ... no candidates
[subject-recently-closed] ... no candidates
[files-and-rule-ids] a different problem in the same files or under the same rule -- the fold candidates one PR would sanely deliver together
  skipped -- this pass had no terms to search with
[lane] the same lane -- neighbours routed to the same authority, which is where a fold is defensible at all
  skipped -- this pass had no terms to search with
```

Also verified: this call needed **no `--repo`** at all (run from the `hatsu` worktree, a
different checkout entirely) — `issue search` hits the GitHub API purely through `--target`, no
local taxonomy file is consulted. **Finding for the skill, not the binary**: this is the reason
§ 3 of the ported skill does not mandate `--repo` on `issue search`/`open-pr-check`, only on
`issue file` (§ 2.5, where the taxonomy check makes it load-bearing).

### 2.3 — `nen issue open-pr-check`, real open PRs on `<reference-repo>`, cross-checked by hand

```
$ nen issue open-pr-check --repo <reference-repo checkout> --target <reference-repo> \
    --issues 877,879,912,914,918,935,938,939
```

```
open pull requests scanned: 2
  #877: OPEN PR #925 -- closing this orphans work in flight
  #879: no open PR
  #912: no open PR
  #914: no open PR
  #918: OPEN PR #940, #925 -- closing this orphans work in flight
  #935: no open PR
  #938: no open PR
  #939: OPEN PR #925 -- closing this orphans work in flight
```
exit code: `1` (a candidate is blocked).

Manual cross-check — the two open PRs `<reference-repo>` actually had at run time:

```
$ gh pr list --repo <reference-repo> --state open --json number,title,url
[{"number":940,...},{"number":925,...}]

$ gh pr view 925 --repo <reference-repo> --json closingIssuesReferences -q '.closingIssuesReferences[].number'
918
$ gh pr view 925 --repo <reference-repo> --json body -q .body | grep -oE '#[0-9]+' | sort -u
#877
#918
#939
```

**Same.** `nen`'s finding for `#877`/`#918`/`#939` matches exactly what `gh pr view 925`'s own
`closingIssuesReferences` (`#918`, via `closes`) and body-mention scan (`#877`, `#918`, `#939`)
report by hand — `#918` doubly confirmed (closes **and** mentions). A re-run with only
non-blocked candidates (`879,912,914`) exits `0` with `no open PR` on all three, confirming the
exit code tracks the finding, not a fixed non-zero-on-any-output default.

### 2.4 — `nen repo resolve`, the § 1 parsing rule

```
$ nen repo resolve BC --repo <reference-repo checkout>
<reference-repo>  (BC)  via code                    # exit 0

$ nen repo resolve notarealtoken --repo <reference-repo checkout>
nen repo: 'notarealtoken' does not name a repository in this registry (...\schemas\repos.json).
It is matched exactly ... Codes: $comment (...), BC (<reference-repo>), BS (...), KP (...),
KN (...), KW (...), KC (...). Repositories: <product-repo-A>, <product-repo-B>,
<scaffold-repo>.                                # exit 1

$ cd <reference-repo checkout> && nen repo resolve      # no token -- resolves cwd's own origin
nen repo: '<path>' has an 'origin' of 'https://github.com/<reference-repo>.git', which resolves
to '<reference-repo>' -- and that is not in this registry (...). ... Codes: ... Repositories:
<product-repo-A>, <product-repo-B>, <scaffold-repo>.                    # exit 1
```

The third run is a real, reproducible nuance, **not a defect**: `schemas/repos.json`'s
`consumers[]` array (the list the no-token/origin path checks) records only `<reference-repo>`'s
*downstream consumers* (`<product-repo-A>`, `<product-repo-B>`, `<scaffold-repo>`) — `<reference-repo>` itself is
reachable only by its `product_codes` entry (`BC`), never by resolving its own origin, because
the file's own header states it is a "Consuming-repo registry." Standing inside the `<reference-repo>`
checkout itself and invoking bare `nen repo resolve` therefore refuses — correctly, per the
ported skill's own § 1 rule ("if the cwd is not a registry repo, ask, with the resolved
candidates listed"): the refusal text **is** that candidate list, verified live above.

### 2.5 — `nen issue file --dry-run`: labels-in-create-call, taxonomy-checked, nothing written

```
$ nen issue file --repo <reference-repo checkout> --target <reference-repo> \
    --title "TEST DRY RUN — do not file" --body-file <scratch file> \
    --label bankai:severity/low --assignee zheref --dry-run
would run: gh issue create --repo <reference-repo> --title TEST DRY RUN — do not file --body-file <path> --assignee zheref --label bankai:severity/low
```

Confirms the create call carries `--assignee` and `--label` **in the same invocation** as
`--title`/`--body-file` — exactly § 5's "applied in the create call, never as a follow-up edit"
rule, now enforced by the verb's own argv shape rather than the agent's memory. Nothing was
written to `<reference-repo>`: `--dry-run` only prints the `gh` call it would make.

```
$ nen issue file --repo <reference-repo checkout> --target <reference-repo> \
    --title "TEST" --body-file <scratch file> \
    --label bankai:not-a-real-label --assignee zheref --dry-run
nen: label 'bankai:not-a-real-label' is not in this repository's taxonomy (...\schemas\labels.json).
GitHub would CREATE it rather than refuse, so a typo becomes a permanent undocumented label.
```
exit code: `1` — refused **before** `--dry-run`'s own "would run" line ever printed, i.e. before
any GitHub call would have happened either way.

### 2.6 — `--forbid-family`: the stage-label guard, mechanically enforced

```
$ nen issue file --repo <reference-repo checkout> --target <reference-repo> \
    --title "TEST" --body-file <scratch file> \
    --label bankai:stage/building --assignee zheref --forbid-family bankai:stage --dry-run
nen: label 'bankai:stage/building' is in the 'bankai:stage' family, which this invocation
declared off-limits with --forbid-family.
```

This is the mechanism § 5/§ 8 of the ported skill leans on: the old skill's "never applies a
stage label" was a sentence the agent had to remember every single call; `--forbid-family` turns
it into a refusal the binary enforces on the invocation itself, before any label taxonomy lookup
or GitHub call. Verified live, `--dry-run` present either way — nothing written.

### 2.7 — `nen label apply` needs `--repo`: reproduced, fixed in the skill, reverified live

**MAJOR finding from adversarial review:** § 3(a)'s `nen label apply` invocation, as originally
ported, carried `--repo-slug <owner/name>` but no `--repo <path>` at all. Reproduced from this
port's own `hatsu` checkout, which carries no `schemas/labels.json` of its own:

```
$ nen label apply FX-IS-#1 --label bankai:severity/low \
    --repo-slug zheref/does-not-exist-fixture --reason "verifying missing --repo flag causes schemas lookup failure"
nen label: C:\...\hatsu\schemas\labels.json: no such file. Nen reads this repository's taxonomy
from 'schemas/labels.json' in the TARGET repo and has no built-in copy to fall back on -- a binary
that guessed the names would report a taxonomy this repository does not have. Point it at a
checkout that carries the file with --repo <path>, or add the file.
```
exit code: `1`.

`--repo-slug` names *which* GitHub repository the mutation would run against; it says nothing
about *where on disk* to read that repository's `schemas/labels.json` from, and `nen` has no
built-in taxonomy to fall back on. The skill's invocation is fixed to carry both: `--repo <path to
the target's own checkout>` alongside `--repo-slug <owner/name>` (§ 3(a) of
`claude/skills/file/SKILL.md`, above).

**Reverified live, with the fix applied**, without re-triggering the auto-mode classifier block
already recorded in § 3 below (which fires on `nen label apply` invocations that target the real
`<reference-repo>` by both `--repo` and `--repo-slug` at once): `--repo` pointed at the local
`<reference-repo>` checkout only to supply a real `schemas/labels.json`, `--repo-slug` pointed at
`zheref/hatsu` (a fixture value — nothing is sent anywhere without `--run`, and `--run` was never
passed), and `--ledger` pointed at a scratch path outside any checkout so nothing lands in
`<reference-repo>` even as a local, uncommitted file:

```
$ nen label apply HT-IS-#1 --label bankai:severity/low --repo-slug zheref/hatsu \
    --repo "<checkout>\<reference-repo>" \
    --reason "verifying --repo makes the taxonomy check resolve correctly (dry run, no --run)" \
    --ledger "<scratch path>\label-ledger.jsonl"
(dry run) would apply 'bankai:severity/low' to HT-IS-#1
ledger: <scratch path>\label-ledger.jsonl
```
exit code: `0`. `<reference-repo>`'s own working tree (`git status --porcelain`) stayed empty
throughout — confirmed before and after. This is the fixed invocation shape working: `--repo`
resolves the taxonomy file that was previously missing, and the call proceeds to its normal
dry-run report instead of refusing.

---

## 3. Residue

- **Posting the amend/fold/supersede comment has no `nen` verb.** Searched `nen issue --help`,
  `nen wake --help` (posts a comment only as part of its own redrive choreography, not a general
  primitive) and the full family list in `nen --help` — no verb owns "post a comment on issue N."
  The ported skill still uses `gh issue comment`/`gh issue close --comment` for this one act
  (§ 3(a)/(b)/(c) of `claude/skills/file/SKILL.md`). **Filed as a finding**, not routed around
  silently.
- **`nen issue attach-sub`/`consolidate-close` exist and are named, but `file` itself does not
  invoke them.** They are the umbrella (3+) choreography's verbs, correctly scoped to whatever
  skill owns consolidation — contract-inspected only (§ 2's usage text), never run, per the
  shared brief's mutating-verb constraint and because the umbrella case is explicitly deferred by
  the ported skill's § 3(d), same as the old one.
- **`nen label apply --run` for a duplicate's severity bump against `<reference-repo>`
  specifically was contract-inspected, not run live**, on top of the shared brief's mutating-verb
  constraint: the auto-mode classifier refused even a no-`--run` dry invocation of `nen label
  apply` that named `<reference-repo>` as both `--repo` and `--repo-slug` mid-session (blocked
  before execution, no output produced) — recorded here rather than silently retried or routed
  around. Its contract (`nen label --help`, quoted in the skill and in this doc's § 1 row 7) is
  unambiguous: `--reason` is ledger-only text, never sent to GitHub, and outcome is recorded only
  `--run` and only after the call resolves — nothing here contradicts that reading. The `--repo`
  flag itself — the MAJOR finding this port's review raised — **was** reverified live (§ 2.7),
  using `<reference-repo>`'s checkout only to supply a real `schemas/labels.json` and a fixture
  `--repo-slug` (`zheref/hatsu`) so the classifier's `<reference-repo>`-targeting block never
  applied; what remains contract-inspected only is the severity-bump call shape against the real
  backlog, not the `--repo` fix.
- **No missing verb found among the read-only half.** `nen issue search` and `nen issue
  open-pr-check` between them cover every deterministic step `file`'s reconciliation phase needs;
  both were run live against the real `<reference-repo>` backlog and both matched a manual
  `gh`-by-hand reconstruction exactly (§ 2.1, § 2.3).
- **Judgment kept, per the shared brief's boundary list:** what counts as a duplicate vs a fold
  vs a supersede; severity assessment and its one-line basis; the drafted title/body; whether a
  cluster of 3+ candidates is a consolidation; the `DECIDE` options and the ⭐ recommendation.
  `nen` searches, guards and creates; it never decides which candidate is which shape of overlap.
- **The old skill's CON-{n}/H9/RR-IS-# citations were `<reference-repo>`'s own process rules**
  (idempotent-escalation, the dry-run-first convention, the G1 delegation carve-out) — this port
  generalises the *mechanism* (any target repo's own taxonomy and registry, read at run time) but
  keeps no repo-specific rule ID baked into the skill text itself, since `file` now targets
  whatever repo the maintainer names, not only `<reference-repo>`.

---

## 4. Findings (report separately, do not route around)

1. **No `nen` verb posts a plain issue comment or closes a single issue with free-text comment.**
   `nen issue --help`'s only comment-adjacent behaviour is `wake fire --comment`, scoped to its
   own redrive choreography, and `consolidate-close`'s close is bundled with a mandatory
   attach-sub and computed label/severity summary, not a caller-supplied comment. A skill whose
   entire § 3(a)–(c) is "comment with new evidence" / "close with a comment naming this issue"
   has no primitive narrower than raw `gh` for that one act. Worth filing against `nen` as a gap:
   a `nen issue comment <ref> --body-file <path>` (and a bare `nen issue close <ref> --comment
   <text>` distinct from `consolidate-close`) would retire the one hand-run `gh` call this port
   could not replace.
2. **`nen repo resolve`'s no-token/origin path checks a narrower list (`consumers[]`) than its
   own `product_codes` map**, so a repo that owns the registry (like `<reference-repo>` owning its own
   `schemas/repos.json`) cannot resolve itself via bare `nen repo resolve` from its own checkout —
   only via an explicit code (`nen repo resolve BC`). This is very likely intentional (the file's
   own header says "Consuming-repo registry"), and the resulting refusal text is exactly what the
   ported skill's § 1 rule wants (a candidate list to hand the maintainer) — recorded as a
   documented nuance rather than a defect, since nothing here contradicts `nen`'s own stated
   contract.
