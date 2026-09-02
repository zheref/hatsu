# A/B evidence — `getsuga` (zheref/hatsu#2)

Port of `claude/skills/getsuga/SKILL.md`: cutting a release tag locally, end to end —
preconditions, one folded release PR, the tag, then the `CON-22` fan-out. Old mechanics: raw `git`
(`merge-base --is-ancestor`, `ls-remote --tags`, `ls-tree`), raw `gh` (`variable get`, `issue list`,
`pr list`), and three bash scripts with no shared entry point
(`scripts/tag_cut.sh`, `scripts/changelog_collate_fragments.sh`,
`scripts/changelog_release_completeness_check.sh`). New mechanics: `nen release
preflight|resolve-target|self-check`, `nen changelog collate|completeness`, `nen tag cut`,
`nen fanout compute|record`.

Run: 2026-09-01 (local clock; `nen 0.1.0` at `<cache>\nen\v0.1.0\nen-windows-x64.exe`).
`gh` authenticated as `zheref`, `GH_TOKEN=$(gh auth token)` exported for every call that touches
GitHub. Read-only verbs (`release resolve-target`, `release preflight`, `release self-check`,
`changelog completeness`, `fanout compute`) were run against the **real, live**
`<reference-repo>` — nothing mutating was ever sent to it: no tag, no push, no issue, no comment,
no label. `changelog collate --write` (mutating: rewrites a file, deletes fragments) was run only
against **constructed, disposable fixtures** under `%TEMP%`, never against `<reference-repo>` or
`hatsu`. `tag cut` (mutating: creates and optionally pushes a tag) was run only against a
**disposable scratch repo + scratch bare "origin"** under `%TEMP%`, seeded and discarded for this
run, with its own remote — never `<reference-repo>`, never `hatsu`. `fanout record` (mutating: appends
to a local audit ledger) was A/B'd by contract inspection only, never executed. `nen release
--help`, `nen changelog --help`, `nen tag --help`, `nen fanout --help` were re-run live against the
pinned binary before writing any of this (§ 0) — they match the shared refpack dump byte for byte.

*Paths sanitized: this machine's local absolute paths appear as `<checkout>` (the parent directory of the repository checkouts), `<cache>` (the nen binary cache) and `<scratch>` (a throwaway scratch directory). Private repository names, and the product codes that identified them, are redacted to placeholders (see [`docs/PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md)); nothing else below is altered -- the transcripts are otherwise verbatim.*

---

## 0. Live `--help` re-verification

```
$ nen --version
0.1.0
```

`nen release --help`, `nen changelog --help`, `nen tag --help`, `nen fanout --help` were each run
against the pinned binary and diffed by eye against the port-orchestration session's own
`--help` refpack dump (a session artifact, not checked into this repo)'s equivalent sections —
identical. Not re-pasted here in full; every flag cited below was confirmed against this live run,
not against memory or the refpack alone.

---

## 1. Command mapping table

| # | Old (prose / raw `git` & `gh` / a bash script) | New (`nen`) |
|---|---|---|
| 1 | `git merge-base --is-ancestor <resolved> origin/main`, run by hand after resolving the invocation token by eye | `nen release resolve-target --repo <path> --token <token>` — re-fetches `origin/main` itself, then runs the same test, and refuses a dirty `checkout` outright (§ 2.1) |
| 2 | `gh variable get RELEASE_HOLD`, read by eye | Folded into `nen release preflight`'s own row — **with a documented behavioural gap**, § 2.2.1 |
| 3 | "Open `critical` issues" — a `bankai:severity/critical` label query, reasoned by hand | `nen release preflight --critical-issues <n,n>` — `nen` owns the pass/fail and the "not supplied" honesty; the caller still gathers the numbers via `gh issue list --label "bankai:severity/critical" --state open` — **the full label, not the bare `critical`, which silently matches nothing** (§ 2.2) |
| 4 | The `CON-36` three-part live-chore test — AND'd by hand across an issue-state read, a branch-existence read, and an open-PR read | `nen release preflight --live-chores-from <path>` — `nen` owns the AND per chore and the "none live" verdict; the caller still gathers the three booleans per chore the same way (§ 2.2) |
| 5 | `ls changelog.d` at the cut point, by hand | Folded into `nen release preflight` (`--fragment-dir`, defaults `changelog.d`) (§ 2.2) |
| 6 | `scripts/changelog_release_completeness_check.sh <vPrev> <cut-point>` | Folded into `nen release preflight`, or standalone `nen changelog completeness --range ... --changelog ... --owner-repo ...` (§ 2.4) |
| 7 | `git ls-remote --tags origin`, read by hand for "does the tag already exist" | Folded into `nen release preflight`, and independently re-checked by `nen tag cut` itself before cutting (§ 2.5) |
| 8 | `scripts/changelog_collate_fragments.sh` | `nen changelog collate --version --theme --changelog --fragment-dir [--write]` — written body verified byte-for-byte identical to the old script (descending, newest-first); **with a documented printed-manifest defect**, § 2.3.1 |
| 9 | `git ls-tree -r <prevTag> -- changelog.d`, read by hand to decide whether a fragment is stranded from the *previous* release | **No `nen` verb owns this decision.** Residue — § 3 |
| 10 | Self-enumeration ("does this release PR list itself?") — reasoned by hand, wrong four times in `<reference-repo>` history | `nen release self-check --repo <path> --pr-merge-sha <sha> --previous-tag <ref> --cut-point <ref>` (§ 2.4b) |
| 11 | Bump `latest` in `schemas/repos.json`, by hand | **No `nen` verb owns this write.** Residue — § 3 |
| 12 | Bump `.claude-plugin/plugin.json`, by hand | **No `nen` verb owns this write.** Residue — § 3 |
| 13 | `scripts/tag_cut.sh <new> <prev> [changelog]` — one script bundling the HOLD read, the reachability check, the completeness re-check, the actual `git tag`, **and an unconditional `git push`** | `nen tag cut --repo <path> --name <vX.Y.Z> --at <sha> [--push]` — deliberately narrower: only the name-uniqueness and `--at`-is-ancestor checks are its own (the rest now live in `release preflight`/`resolve-target`), and the push is an **explicit, separate flag** rather than automatic (§ 2.5) |
| 14 | Computing the `CON-22` affected-consumer set — `git diff --name-only <range> -- .github/workflows/` basenames, intersected against `schemas/repos.json`'s `consumes`, by hand | `nen fanout compute --range <vPrev>..<vNew>` (§ 2.6) |
| 15 | No prior mechanism recorded an audit trail of the fan-out computation itself | `nen fanout record --range ... --ledger <path>` — contract-inspected only, never opens the repin PR itself (§ 3) |
| 16 | The gate-stop banner, rendered by hand or via `scripts/gate_stop.sh` | `nen stop --who kurapika --gate G4 <efforts.md>` (adopted per the shared brief; not separately re-verified in this port — already verified live in `docs/ab/tensho.md` § 2.8) |

**Count.** Before: **13 improvised steps** (rows 1–14 minus the two residues at rows 9/11/12 which
stay improvised either way, and row 16 which another port already verified) — every one a raw
`git`/`gh` call or a bash script invocation, reasoned or read by hand. After: **10 of those 13** are
now a single `nen` invocation each (rows 1–8, 10, 13, 14), with **two load-bearing behavioural
findings** recorded against the binary (rows 2 and 8) rather than silently trusted, and **one**
(row 15) newly available but not yet wired to an action. **3 residues remain fully improvised**
(rows 9, 11, 12) — no `nen` verb exists for any of the three, and none is a gap this skill routes
around quietly; see § 3.

---

## 2. Live transcripts

### 2.1 — `nen release resolve-target` (real `<reference-repo>`)

```
$ export GH_TOKEN=$(gh auth token)
$ nen release resolve-target --repo <reference-repo checkout> --token main
main -> 345c79b2ab316f896e7415fc38734cdd9cd59d0a
an ancestor of the trunk -- safe to cut
exit=0

$ nen release resolve-target --repo <reference-repo checkout> --token last-commit
last-commit -> 345c79b2ab316f896e7415fc38734cdd9cd59d0a
an ancestor of the trunk -- safe to cut
exit=0

$ nen release resolve-target --repo <reference-repo checkout> --token checkout
checkout -> 2269fe723e355dc69bf535ab40f22556e4fe4081
an ancestor of the trunk -- safe to cut
exit=0
```

Both `main` and `last-commit` resolved to the same, freshly re-fetched `origin/main` tip
(`345c79b2`) — **note this is a different, newer commit than the local checkout's own `HEAD`**
(`2269fe72`, the `v0.11.3` tag commit): `<reference-repo>` received at least one more commit today
(2026-09-01) despite being nominally frozen for the Akatsuki migration — consistent with
`<migration-tracker>`'s own ledger disclosure of concurrent `<reference-repo>` activity. This is exactly the
"re-fetching, not the checkout's stale idea of the tip" behaviour § 1 depends on, caught live rather
than assumed.

```
$ nen release resolve-target --repo <reference-repo checkout> --token origin/integration/879-g2-gate-definition
origin/integration/879-g2-gate-definition -> 3476c03e4dd8c2e92f9d7eb6b50b3b3bc6c927d3
NOT an ancestor of the trunk -- it has to reach the trunk first before it can be tagged
exit=1
```

A genuinely off-main branch (the one live chore found in § 2.2) correctly reports not-an-ancestor.

**Finding, minor**: a bare local branch token (no `origin/` prefix, e.g.
`integration/879-g2-gate-definition`) fails with a `git rev-parse` error rather than resolving —
this checkout never created a local tracking branch for it, only `origin/`'s remote-tracking ref
exists. Not a defect in `nen` (the same bare name would fail the same way under raw `git
rev-parse`, too) — just a usage note: pass a fully-qualified `origin/<branch>` for a branch never
checked out locally.

### 2.2 — `nen release preflight` (real `<reference-repo>`)

Data gathered live, per § 1's mapping:

**Regression caught in review: the label as first written here, `critical`, is not a real label —
`schemas/labels.json`'s severity family is `bankai:severity/<level>`, so `--label critical` matches
nothing and silently reports "no open criticals" whether or not that is true.** Re-run live, both
the broken form and the corrected one, plus `--state all` to confirm the corrected label genuinely
matches real (historical) data rather than also silently matching nothing:

```
$ gh issue list --repo <reference-repo> --label critical --state open --json number,title
[]

$ gh issue list --repo <reference-repo> --label "bankai:severity/critical" --state open --json number,title
[]

$ gh issue list --repo <reference-repo> --label "bankai:severity/critical" --state all --json number,title,state
[{"number":844,"state":"CLOSED", ...}, {"number":835,"state":"CLOSED", ...}, {"number":831,"state":"CLOSED", ...},
 {"number":656,"state":"CLOSED", ...}, {"number":559,"state":"CLOSED", ...}, {"number":551,"state":"CLOSED", ...},
 {"number":550,"state":"CLOSED", ...}, {"number":545,"state":"CLOSED", ...}, {"number":521,"state":"CLOSED", ...},
 {"number":403,"state":"CLOSED", ...}, {"number":397,"state":"CLOSED", ...}, {"number":390,"state":"CLOSED", ...},
 {"number":379,"state":"CLOSED", ...}, {"number":273,"state":"CLOSED", ...}]
 (14 historical entries, all CLOSED)
```

**Both the broken and the corrected `--state open` query return `[]` — same verdict for this
precondition today, by coincidence (`<reference-repo>` genuinely has zero open criticals right now), not
because the bare `critical` label was ever valid.** The `--state all` run against the corrected
label proves the label itself is real and the query mechanism works — 14 historical criticals, every
one already closed — which the broken label could never have returned regardless of state, since it
never matched any issue in this repository's history. The fix stands regardless of today's verdict:
a query that silently matches nothing is not equivalent to a query that correctly finds nothing.

```
$ gh variable get RELEASE_HOLD --repo <reference-repo>
false

$ for n in 304 306 312 379 388 389 400 416 422 444 488 531 571 698 737 879; do
    gh issue view $n --repo <reference-repo> --json state -q .state
  done
CLOSED (×15), OPEN (879 only)

$ gh pr list --repo <reference-repo> --state open --json number,baseRefName,headRefName
[{"number":940,"baseRefName":"main","headRefName":"ichigo/937-bc11-frozen-line-patch"},
 {"number":925,"baseRefName":"main","headRefName":"kisuke/918-cancelled-build-report"}]
```

Neither open PR's head or base names `integration/879-g2-gate-definition`, so that chore's
three-part test is `issueOpen=true, integrationBranchExists=true,
openPrTargetsIntegrationOrMain=false` — fed into `.ab-fixtures/bc-live-chores.json` (16 entries, one
per historical `integration/*` branch still present on `origin`, all but 879's issue already
closed).

```
$ nen --repo <reference-repo checkout> release preflight \
    --repo-slug <reference-repo> --tag v0.11.4 --range v0.11.3..HEAD \
    --changelog /tmp/bc-changelog-v0.11.3.md --owner-repo <reference-repo> \
    --critical-issues '' --live-chores-from .ab-fixtures/bc-live-chores.json
FAIL  RELEASE_HOLD -- HELD: RELEASE_HOLD = 'false'
ok    open critical issues -- none open
ok    CON-36 live chores -- none live (issue open AND branch exists AND an open PR targets it or main)
ok    changelog.d/ empty at cut point -- empty
ok    CON-33(c) reconciled -- every merged PR has a CHANGELOG entry or fragment
ok    tag does not already exist -- clear
exit=1
```

Every row now comes back in **one call** — no first-failure truncation, matching § 2's own
"report the whole table" rule exactly (`RELEASE_HOLD` fails but the other five rows still print).

#### 2.2.1 — the `RELEASE_HOLD` finding, isolated

```
$ gh variable get RELEASE_HOLD --repo zheref/hatsu
variable RELEASE_HOLD was not found
$ nen --repo <hatsu checkout> release preflight --repo-slug zheref/hatsu --tag v9.9.9 \
    --range HEAD~3..HEAD --changelog /tmp/hatsu-changelog.md --owner-repo zheref/hatsu \
    --critical-issues '' --live-chores-from /tmp/empty-chores.json
ok    RELEASE_HOLD -- not set
ok    open critical issues -- none open
ok    CON-36 live chores -- none live (issue open AND branch exists AND an open PR targets it or main)
ok    changelog.d/ empty at cut point -- empty
FAIL  CON-33(c) reconciled -- missing: #12, #13, #14
ok    tag does not already exist -- clear
exit=1
```

(The `CON-33(c)` failure here is expected and irrelevant to this probe — `hatsu` ships no
`CHANGELOG.md` yet, so a throwaway one-line stub was used, and it obviously doesn't mention #12–#14.
The point of this run is the `RELEASE_HOLD` row alone.)

**Side by side: identical verb, one repo where the Variable is unset, one where it is set to the
string `"false"` — opposite verdicts on a row meant to mean the same thing (`no active hold`) in
both cases.** The old `scripts/tag_cut.sh`'s `hold_active()` treats only case-insensitive
`true`/`1`/`yes` as an active hold and everything else — unset **or** `"false"` — as inactive.
`nen release preflight` instead appears to treat the Variable's mere **existence** as HELD,
regardless of its value. This is a genuine behavioural contradiction between the binary and the
semantics the old skill (and its underlying script) documented, not a skill-authoring choice — see
`SKILL.md` § 2 for the operational instruction this produces: relay the row exactly as printed, but
name the specific misleading shape (`RELEASE_HOLD = 'false'` read as HELD) to the maintainer, whose
fix is to delete the Variable rather than set it `false`.

#### 2.2.2 — `nen`'s `RELEASE_HOLD` read fails CLOSED on an unreachable `gh`; the old script failed OPEN

`nen release preflight --help` states this outright: "`--hold-var <name>` … A `gh` that cannot be
reached (missing, unauthenticated, no variable-read scope) fails this check rather than reading as
'not set'." Verified live by making `gh` genuinely unreachable (stripped from `$PATH`, rather than
supplying a bad token — a bad `GH_TOKEN` also breaks this checkout's own `git` credential helper,
since `credential.https://github.com.helper` here shells out to `gh auth git-credential`, which
would confound the isolation):

```
$ which gh
which: no gh in (...)   # GitHub CLI's directory removed from PATH for this run only

$ nen --repo <reference-repo checkout> release preflight \
    --repo-slug <reference-repo> --tag v0.11.4 --range v0.11.3..HEAD \
    --changelog /tmp/bc-changelog-v0.11.3.md --owner-repo <reference-repo> \
    --critical-issues '' --live-chores-from /tmp/empty-chores.json
FAIL  RELEASE_HOLD -- could not be read: Executable not found in $PATH: "gh"
ok    open critical issues -- none open
ok    CON-36 live chores -- none live (issue open AND branch exists AND an open PR targets it or main)
ok    changelog.d/ empty at cut point -- empty
ok    CON-33(c) reconciled -- every merged PR has a CHANGELOG entry or fragment
ok    tag does not already exist -- clear
exit=1
```

`nen` refuses the table outright when it cannot read the hold. The old `scripts/tag_cut.sh`, read
at the frozen `v0.11.3` snapshot, does the opposite by construction:

```
$ git show v0.11.3:scripts/tag_cut.sh | grep -n 'hold_value='
264:  hold_value="$(gh variable get RELEASE_HOLD 2>/dev/null || true)"
```

`2>/dev/null || true` swallows any `gh` failure (missing binary, auth failure, network outage) into
an empty string, and `hold_active("")` (case-insensitive `true`/`1`/`yes` only) reads empty as
*inactive* — the old mechanics let a release proceed unheld exactly when the check that was
supposed to gate it could not run. `nen`'s behavior is the safer of the two; recorded here for
awareness, not as an operational rule the skill must add — the safer behavior already fires on its
own.

### 2.3 — `nen changelog collate`, without and with `--write` (constructed fixture)

Constructed under `%TEMP%\getsuga-collate-fixture`, two fragments, a `CHANGELOG.md` carrying an
`### Unreleased` anchor:

```
$ nen changelog collate --version v0.2.0 --theme "widget factory hardening" \
    --changelog CHANGELOG.md --fragment-dir changelog.d
(no --write) would collate 2 fragment(s) into .../CHANGELOG.md ### v0.2.0 — widget factory hardening
  42-widget-factory-perf.md
  47-fix-widget-leak.md
exit=0
```

`CHANGELOG.md` and the two fragment files were both **untouched** after the preview (`ls
changelog.d` still shows both; `cat CHANGELOG.md` unchanged) — verified, matching the `--help`
contract ("without `--write`, reports the rendered result without touching disk or deleting
fragments").

```
$ nen changelog collate --version v0.2.0 --theme "widget factory hardening" \
    --changelog CHANGELOG.md --fragment-dir changelog.d --write
collated 2 fragment(s) into .../CHANGELOG.md ### v0.2.0 — widget factory hardening
  42-widget-factory-perf.md
  47-fix-widget-leak.md
exit=0
$ ls changelog.d
(empty)
$ cat CHANGELOG.md
# Changelog

### Unreleased
_(nothing awaiting release.)_

### v0.2.0 — widget factory hardening
**What changed**: fixed a handle leak in the widget factory teardown path.
...
**What changed**: the widget factory now caches its templates.
...
### v0.1.0 — initial cut
- Added the widget factory (#1).
```

`--write` deleted both fragments and rewrote `CHANGELOG.md` — matching the contract. **Note the
body order**: the manifest above (and printed by `nen` itself) lists `42-...` then `47-...`; the
written section renders `47`'s content first, `42`'s second — reversed **from the manifest**.
Isolated, reproduced twice, and — per review correction — checked against the real old script's own
behaviour on the identical fixture below, rather than assumed to be a regression against it.

#### 2.3.1 — the write-order finding, isolated, reproduced twice, and checked against the real old script

**Regression caught in review: this finding was originally recorded backwards.** The written body
is not the defect — it is descending (newest-first) and matches `CON-33(b)`'s own convention
("placed newest-first, directly below `### Unreleased`") and the real, shipped
`<reference-repo>` `v0.11.3` `CHANGELOG.md` section (`#899, #898, #890…`, descending). The actual
defect is narrower: the **printed manifest** disagrees with what was written. Re-verified live, with
the real `changelog_collate_fragments.sh` (extracted read-only from `<reference-repo>` at `v0.11.3`) run
side by side against `nen changelog collate --write` on the identical fixture:

```
$ mkdir changelog.d && printf '**What changed**: FRAG-10.\n' > changelog.d/10-a.md
$ printf '**What changed**: FRAG-20.\n' > changelog.d/20-b.md
$ printf '**What changed**: FRAG-30.\n' > changelog.d/30-c.md

$ bash changelog_collate_fragments.sh v0.2.0 "order probe" CHANGELOG.md changelog.d
CON-33(b): collated 3 fragment(s) from 'changelog.d' into 'CHANGELOG.md' ### v0.2.0 — order probe, and removed the collated files.
  changelog.d/30-c.md
  changelog.d/20-b.md
  changelog.d/10-a.md
$ cat CHANGELOG.md
# Changelog

### Unreleased
_(nothing awaiting release.)_

### v0.2.0 — order probe
**What changed**: FRAG-30.
**What changed**: FRAG-20.
**What changed**: FRAG-10.
### v0.1.0 — initial cut
- Added the widget factory (#1).
```

```
$ nen --repo . changelog collate --version v0.2.0 --theme "order probe" \
    --changelog CHANGELOG.md --fragment-dir changelog.d --write
collated 3 fragment(s) into CHANGELOG.md ### v0.2.0 — order probe
  10-a.md
  20-b.md
  30-c.md
$ cat CHANGELOG.md
# Changelog

### Unreleased
_(nothing awaiting release.)_

### v0.2.0 — order probe
**What changed**: FRAG-30.
**What changed**: FRAG-20.
**What changed**: FRAG-10.
### v0.1.0 — initial cut
- Added the widget factory (#1).
```

**The written `CHANGELOG.md` is byte-for-byte identical between the old script and `nen`** —
`FRAG-30, FRAG-20, FRAG-10`, descending, on the same fixture. **The old script's own printed
manifest is also descending** (`30-c.md, 20-b.md, 10-a.md`), because it prints the same
already-sorted array it collated from. `nen`'s printed manifest is the outlier: it prints the
fragment names in plain ascending filesystem-`readdir` order (`10-a.md, 20-b.md, 30-c.md`) — a
different, unsorted list from the one `sortFragments` actually built and wrote
(`src/changelog/collate.ts`/`command.ts` at the pinned `v0.1.0` tag: `collateCmd` renders from
`sortFragments(fragments)` but prints from the original unsorted `names`). **This is a manifest/log
defect in `nen`, not a body-rendering defect** — `CON-33(c)` (`SKILL.md` § 3.3) governs the
*completeness check*'s own ascending numeric comparison, a different mechanism entirely; the clause
governing this body's newest-first order is `CON-33(b)`. The corrected operational rule: **trust the
written section as correct (it already matches the old script and the convention); note the printed
manifest as unreliable** — never re-order the written section by eye, which would corrupt a real,
correctly-descending changelog into oldest-first.

### 2.4 — `nen changelog completeness`, real range, vs. the old script read-only

```
$ git show v0.11.3:CHANGELOG.md > /tmp/bc-changelog-v0.11.3.md
$ nen changelog completeness --range v0.11.2..v0.11.3 \
    --changelog /tmp/bc-changelog-v0.11.3.md --owner-repo <reference-repo>
every PR merged in v0.11.2..v0.11.3 has a CHANGELOG entry or fragment.
exit=0
```

Old script, extracted read-only via `git show v0.11.3:scripts/changelog_release_completeness_check.sh`
to a temp file and run against the **exact same** range and changelog file, from inside the real
`<reference-repo>` checkout (a pure `git log --merges` read plus two file reads — no write, no push, no
API call):

```
$ bash /tmp/old-completeness-check.sh v0.11.2 v0.11.3 /tmp/bc-changelog-v0.11.3.md changelog.d
CON-33(c): every PR merged in v0.11.2..v0.11.3 has a CHANGELOG.md entry or changelog.d/ fragment.
exit=0
```

**Same verdict, same exit code.** This is the "same verdicts" bar the shared brief asks for,
confirmed on the real repository the fragment-aware completeness check was written for.

#### 2.4b — `nen release self-check`, real release PR

```
$ gh pr view 916 --repo <reference-repo> --json mergeCommit,mergedAt,title
{"mergeCommit":{"oid":"2269fe723e355dc69bf535ab40f22556e4fe4081"}, ...
 "title":"chore(release): collate 34 fragments into v0.11.3 — the final v0.11.x tag before the Akatsuki freeze"}

$ nen release self-check --repo <reference-repo checkout> \
    --pr-merge-sha 2269fe723e355dc69bf535ab40f22556e4fe4081 \
    --previous-tag v0.11.2 --cut-point v0.11.3
#2269fe723e355dc69bf535ab40f22556e4fe4081 should list ITSELF -- it falls inside <v0.11.2>..<v0.11.3>
exit=0

$ nen release self-check --repo <reference-repo checkout> \
    --pr-merge-sha 2269fe723e355dc69bf535ab40f22556e4fe4081 \
    --previous-tag v0.11.3 --cut-point v0.11.3
#2269fe723e355dc69bf535ab40f22556e4fe4081 should NOT list itself -- it is outside <v0.11.3>..<v0.11.3>
exit=0
```

Both correct: `RR-PR-#916` **is** `v0.11.3`'s own release PR and correctly self-lists against
`v0.11.2..v0.11.3`; the second call moves the "previous tag" goalpost to `v0.11.3` itself (as if
querying the *next* release) and correctly flips to "should NOT list itself," since the commit is
already reachable from that tag.

### 2.5 — `nen tag cut`, scratch repo only (never `<reference-repo>`, never `hatsu`)

Disposable bare "origin" + a clone, both under `%TEMP%`, discarded after this run:

```
$ git init --bare /tmp/getsuga-scratch-origin.git
$ git clone /tmp/getsuga-scratch-origin.git /tmp/getsuga-scratch-repo
$ cd /tmp/getsuga-scratch-repo && git commit -m "chore: seed" ... && git push -u origin main
$ git commit -m "chore: local only, not pushed"   # a second, UNPUSHED commit on top
```

```
$ nen release resolve-target --repo . --token checkout
checkout -> b8fcafe0e0002610342fdec6d719637c4fe9d270
NOT an ancestor of the trunk -- it has to reach the trunk first before it can be tagged
exit=1
```

Confirms § 1/§ 6's shape live: a commit genuinely ahead of the pushed trunk is refused as a cut
point, in a scratch repo built specifically to be off-main.

```
$ nen tag cut --repo . --name v1.0.0 --at b70f639           # the PUSHED, reachable commit
'v1.0.0' does not exist locally or on origin
'b70f639' is an ancestor of origin/main
created local tag 'v1.0.0' at b70f639
NOT pushed -- pass --push to push this tag; it is never automatic
exit=0
$ git ls-remote --tags origin
(empty)   # confirmed: nothing pushed
```

```
$ nen tag cut --repo . --name v1.1.0 --at b8fcafe            # the UNPUSHED, unreachable commit
nen: 'b8fcafe' is not an ancestor of origin/main -- a tag is a promise the code is on the trunk,
and this commit is not on it. Use 'nen release resolve-target' first.
exit=1
```

```
$ nen tag cut --repo . --name v1.0.0 --at b70f639             # re-cutting the SAME name
nen: tag 'v1.0.0' already exists locally -- never re-tagged
exit=1
```

```
$ git tag -d v1.0.0
$ nen tag cut --repo . --name v1.0.0 --at b70f639 --push --message "scratch v1.0.0"
'v1.0.0' does not exist locally or on origin
'b70f639' is an ancestor of origin/main
created local tag 'v1.0.0' at b70f639
pushed 'v1.0.0' to origin
exit=0
$ git ls-remote --tags origin
d1af049... refs/tags/v1.0.0
b70f639... refs/tags/v1.0.0^{}
```

Every property `SKILL.md` § 4 claims is now verified live, in scratch: **never defaults to `HEAD`**
(`--at` is mandatory), **refuses an off-trunk commit**, **refuses re-tagging an existing name**,
**never auto-pushes without `--push`**, **pushes only when explicitly told to**, **always
annotated** (`git tag -v`/`show --no-patch` confirms a real annotated tag object, tagger and
message present). Nothing was ever pushed anywhere but this scratch bare repo.

### 2.6 — `nen fanout compute`, real range, vs. the real historical registry determination

```
$ nen --repo <reference-repo checkout> fanout compute --range v0.11.2..v0.11.3
changed workflows in v0.11.2..v0.11.3: bankai.yml, build-cli.yml, cascade-ancestry-guard.yml,
changelog-guard.yml, clause-id-guard.yml, clause-leaf-guard.yml, cli-release-assets.yml,
closes-collision-guard.yml, consumer-tag-precondition-guard.yml, db-migrate.yml,
handbook-question-dedupe.yml, kisuke-build.yml, labels-length-guard.yml, plugin-bump-guard.yml,
registry-drift-guard.yml, release-refusal-guard.yml, repo-health-guard.yml, roy-build.yml,
sync-canon.yml, tag-precondition-guard.yml, unit-tests.yml
AFFECTED  <product-repo-A> (RA)  -- consumes cascade-ancestry-guard.yml, db-migrate.yml,
  handbook-question-dedupe.yml, roy-build.yml, sync-canon.yml, which changed in this range
AFFECTED  <product-repo-B> (RB)  -- consumes roy-build.yml, sync-canon.yml,
  cascade-ancestry-guard.yml, handbook-question-dedupe.yml, which changed in this range
AFFECTED  <scaffold-repo> (BS)  -- consumes kisuke-build.yml, which changed in this range
exit=0
```

`schemas/repos.json`'s own `v0.11.3` consumer notes (written by hand at `RR-PR-#916` when the tag
was actually cut) record: `<product-repo-A>` affected via **five** files — `cascade-ancestry-guard.yml,
db-migrate.yml, handbook-question-dedupe.yml, roy-build.yml, sync-canon.yml`; `<product-repo-B>` via
**four** — `cascade-ancestry-guard.yml, handbook-question-dedupe.yml, roy-build.yml, sync-canon.yml`;
`<scaffold-repo>` via **one** — `kisuke-build.yml`. **`nen fanout compute`'s live output matches every
one of these three consumers and every one of their matched files, exactly**, computed fresh against
the same range rather than read from the old notes. This is the strongest possible same-verdict
confirmation available for this verb: it reproduces a real, already-recorded, hand-computed
historical determination byte-for-byte on the actual data it was computed from.

---

## 3. Residue

Left fully to hand, no `nen` verb ports them (findings against the binary, not gaps routed around
quietly):

1. **Stranded-fragment back-fill** (`SKILL.md` § 3.2) — deciding whether a fragment present at the
   previous tag but never collated belongs in the *previous* dated section is still a direct
   `git ls-tree -r <prevTag> -- changelog.d` read plus judgment. No `nen changelog` verb takes a
   "previous tag" argument to decide this.
2. **Bumping `latest` in `schemas/repos.json`** (§ 3.4) and **bumping
   `.claude-plugin/plugin.json`** (§ 3.5) — both direct file edits. No `nen` verb in the `repo`,
   `schema`, or any other family writes either field; `nen repo resolve/inventory/scenario` are all
   read-only.
3. **Opening the `CON-22` repin PR itself, per affected consumer** (§ 7) — `nen fanout
   compute`/`record` name the affected set and its basis; neither opens anything, by design
   (`record`'s own `--help`: "this verb never opens a repin PR itself; it records the decision a
   caller then acts on"). Each repin PR targets a *different* repository, which nothing in this
   skill's own checkout touches.
4. **The `CON-36` clause-4 `G5` disagreement** (§ 5) and **contradiction reconciliation inside a
   collated section** (§ 3, "Collation manufactures contradictions") — deliberately left to
   judgment per the shared brief's boundary list; `nen` hands over the mechanical AND / the fresh
   collated text, never a ruling on what it means.

Left to judgment **by design**, per the shared brief's boundary list (not residue, not a gap):
severity reasoning for what counts as blocking, the `G5` ask's own framing and recommendation, and
recognising a contradiction's *net effect* in prose.

**Two mutating verbs A/B'd by contract inspection only, never exercised against a live repository**
(per the ground rules — mutating verbs are never run against `<reference-repo>`, and `hatsu` itself has
no release yet to fan out from):

- `nen fanout record` — its `--help` contract (appends one line per consumer to `--ledger`, never
  opens a PR) was read and matched against the old skill's complete silence on any audit trail for
  this step; there is no old counterpart to compare against, only a new capability.
- The repin-PR-opening prose itself (§ 7) has no verb at all (residue item 3 above), so there is
  nothing to contract-inspect beyond confirming `fanout compute`'s own output names a basis for
  every consumer, which § 2.6 already confirms live.

---

## 4. What this port could not verify

- **`RELEASE_HOLD`'s exact parsing rule** (§ 2.2.1) — confirmed the *symptom* (a set-but-falsy value
  reads HELD; an unset one reads not-set) against two real repositories, but the binary is closed
  source at this pin; the precise rule (e.g. "any non-empty string" vs. some other test) is inferred
  from two data points, not read from source. Reported as a finding regardless — the operational
  consequence (never trust a bare `false` string to mean "not held" through this verb) holds either
  way.
- ~~`changelog collate --write`'s exact ordering rule~~ — **resolved, not merely inferred**: `nen`'s
  source at the pinned `v0.1.0` tag (`src/changelog/collate.ts`, `src/changelog/command.ts`) was read
  directly. `collateCmd` renders the written section from `sortFragments(fragments)` (numeric-
  descending by leading `<n>-` prefix, matching `CON-33(b)`'s newest-first convention and the old
  `changelog_collate_fragments.sh`'s own `sort -k1,1nr`), but prints its manifest line from the
  original unsorted `names` array (plain `readdirSync` order) — two different orderings of the same
  fragment set, by construction, not a fixture-size-dependent coincidence. The rule holds for any
  fragment count, not just the 2- and 3-fragment fixtures exercised live (§ 2.3.1).
- **A live `CON-36` clause-4 `G5` disagreement** — `<reference-repo>`'s one open chore
  (`879-g2-gate-definition`) resolved cleanly to "not live" (no PR targets it or `main`), so no
  genuine mechanical-vs-partial-scope tension was available to exercise live; `SKILL.md` § 5's
  handling is carried over from the old skill's prose, unverified against a real disagreement.
- **`nen release preflight`'s row when `--critical-issues`/`--live-chores-from` are omitted
  entirely** ("not supplied — not checked") — read from `--help`, not separately reproduced live in
  this port (the shape is already verified for an analogous flag in `nen warmup`'s own
  `--questions-from`, per the shared brief's operational truths).
- **The old `scripts/tag_cut.sh --mode marker` escape hatch (`CON-7`)** — a maintainer-awareness gap,
  not a routed-around one: no `nen tag cut` flag corresponds to it, and no `getsuga` path, this port
  included, has ever exercised it live (no real cut in this history used `--mode marker`). Recorded
  in `SKILL.md` § 2 so its absence is stated, not silently dropped.
