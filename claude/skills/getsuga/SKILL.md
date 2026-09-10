---
name: getsuga
description: Cut a release tag locally, end to end — preconditions, one folded release PR, the tag, then the CON-22 fan-out. Use when the maintainer invokes hatsu:getsuga <hash | branch-name | main | last-commit | checkout>, or asks to cut a tag, cut a release, or ship a version. An off-main target is driven to main first. Never merges main, never publishes a release, and never tags a commit unreachable from origin/main.
---

# Getsuga — one command from "cut it" to a tag on `main`

**Nature: Emitter.** The release-tag cut is Kurapika's own duty (`CON-33(b)`/`CON-41`); the merges
and the publish are not.

> **Say this on invocation, before anything else:** what the resolved target is, and — when the
> target is not already on `main` — that **this run will build and ship it, not just tag it**. The
> verb reads narrower than it acts, and a maintainer who typed "cut a tag" should not discover
> forty minutes later that they started a delivery.

---

## 1. Invocation

```
hatsu:getsuga <hash | branch-name | main | last-commit | checkout>
```

| Token | Resolves to |
|---|---|
| `main` | `origin/main`'s tip, re-fetched |
| `last-commit` | the tip of `origin/main` — the same commit, named the way people say it |
| `<hash>` | that commit |
| `<branch-name>` | that branch's tip |
| `checkout` | the current working copy's `HEAD` |

**Resolve, then test reachability — this is the load-bearing check**, and it is one verb now, not
two hand-run `git` commands:

```bash
nen release resolve-target --repo <path to the checkout> --token <token>
```

This re-fetches `origin/main` itself, then runs `git merge-base --is-ancestor <resolved>
origin/main`, and refuses a dirty `checkout` outright (uncommitted work is not in any commit, so
there is nothing to tag). Verified live against the real `<reference-repo>` (`docs/ab/getsuga.md`
§ 2.1): `--token main` and `--token last-commit` both resolve to the freshly re-fetched
`origin/main` tip and report `an ancestor of the trunk -- safe to cut`; a branch token pointing at a
live `integration/*` branch reports `NOT an ancestor of the trunk -- it has to reach the trunk first
before it can be tagged` — exit `1`, never a refusal to run.

- **Exit `0`** → an ancestor. Proceed to § 2.
- **Exit `1`** → not an ancestor. It has to reach `main` first (§ 6). **Do not refuse, and do not
  tag it where it stands.**

**A dirty `checkout` is never the cut point.** Hand it to
[`hatsu:tensho`](../tensho/SKILL.md), which is the verb for that, and resume once its PR lands.

## 2. Preconditions — all of them, before a single write

`nen release preflight` folds the whole table into one call, and reports it **whole**, never the
first failure:

```bash
export GH_TOKEN=$(gh auth token)
nen --repo <path to the checkout> release preflight \
  --repo-slug <owner/name> --tag <vX.Y.Z> --range <vPrev>..<cut-point> \
  --changelog <path to CHANGELOG.md at the cut point> --owner-repo <owner/name> \
  --critical-issues <n,n or ''> --live-chores-from <path>
```

**`--critical-issues` and `--live-chores-from` are gathered by the caller, never invented by the
verb** — `nen` owns the AND-logic and the "not supplied — not checked" honesty; it does not own the
GitHub reads that produce the raw facts:

- **Critical issues**: `gh issue list --repo <owner/name> --label "bankai:severity/critical" --state
  open --json number`. **The label is the full `bankai:severity/critical`, never the bare
  `critical`** — a bare `critical` label does not exist in `nen/labels.json` (legacy
  `schemas/labels.json` until `v0.4.0`) and the query silently returns zero matches rather than erroring, which would defeat this precondition without
  ever surfacing a mistake (regression caught in review; re-verified live with `--state all` that
  the corrected query returns the real historical criticals — `docs/ab/getsuga.md` § 2.2). Pass the
  numbers, or `--critical-issues ''` to assert there are none — never omit the flag, which reports
  the row as **not checked** and fails the table.
- **Live chores (`CON-36`'s three-part test)**: per candidate `integration/<chore>` branch, gather
  `{ name, issueOpen, integrationBranchExists, openPrTargetsIntegrationOrMain }` — the chore
  issue's state (`gh issue view <n> --json state`), whether the branch exists
  (`git branch -r --list origin/integration/<chore>`), and whether any open PR targets it *or*
  targets `main` from it (`gh pr list --state open --json baseRefName,headRefName`). `nen` computes
  the AND per chore and the "none live" verdict; point the file at `[]` to assert none are live.

Verified live against the real `<reference-repo>` backlog (`docs/ab/getsuga.md` § 2.2 —
zero open `critical` issues, `RELEASE_HOLD` read as `false`, sixteen historical `integration/*`
branches gathered and fed through, one of them — `879-g2-gate-definition` — carrying a genuinely
open chore issue but no PR targeting it or `main`, so the three-part AND still reads **not live**):
every row the table used to check by separate hand-run command now comes back in one report.

> **Finding this port filed against `v0.1.0`, closed by nen `v0.2.0` (#63, closes zheref/nen#23):
> `RELEASE_HOLD` is now parsed for truthiness, not mere presence.** At the port, `<reference-repo>`'s
> `RELEASE_HOLD` Variable — literally the string `"false"`, meaning *not* held under the old
> `scripts/tag_cut.sh` semantics — reported `FAIL  RELEASE_HOLD -- HELD: RELEASE_HOLD = 'false'`, so a
> repo that had ever set the Variable to `false` read permanently HELD (`docs/ab/getsuga.md` § 2.2.1).
> At `v0.3.0` the rule is the old script's own, stated in `nen release --help` (verified): *"Case-
> insensitive `true`/`1`/`yes` reads as a recognized active hold; `false`/`0`/`no` (or an unset
> variable) reads as not held; any OTHER non-empty value (an arbitrary hold message) is not recognized
> and fails closed as an active hold."* So `RELEASE_HOLD=false` no longer holds a release, and the
> "delete the Variable rather than set it false" workaround is retired. **Relay the row exactly as `nen`
> prints it** (per § 2's own instruction to honour a HELD row and say who set it); a HELD row on an
> arbitrary message is the fail-closed branch doing its job, not the old defect. Not re-run live at
> `v0.3.0` (the row is a `gh variable get` read); the `--help` text and the `v0.2.0` changelog are the
> evidence.

> **A second, safer divergence: `nen release preflight`'s `RELEASE_HOLD` read fails CLOSED on an
> unreachable `gh`, where the old `scripts/tag_cut.sh` failed OPEN.** Verified live (`docs/ab/getsuga.md`
> § 2.2.2): with `gh` made unreachable, `nen` reports `FAIL  RELEASE_HOLD -- could not be read:
> Executable not found in $PATH: "gh"` and the whole table exits `1` — a `gh` outage refuses the
> release rather than silently waving it through. The old script's own `hold_value="$(gh variable
> get RELEASE_HOLD 2>/dev/null || true)"` (`scripts/tag_cut.sh`, read at the frozen `v0.11.3`
> snapshot) instead swallows the failure into an empty string, which `hold_active("")` reads as
> *inactive* — a `gh` outage under the old mechanics let a release proceed unheld. Stated for
> awareness, not as a rule to follow: this divergence needs no operational instruction, since the
> safer behavior is also the one that fires automatically.

> **Maintainer-awareness note, not a routed path: the old `scripts/tag_cut.sh --mode marker` escape
> hatch (`CON-7`) has no `nen` equivalent.** No `getsuga` path — this port, or any real cut recorded
> in `docs/ab/getsuga.md` — has ever used it; stated here only so its absence is a known gap, not a
> silent one, should the maintainer ever reach for it.

| Precondition | On failure |
|---|---|
| `RELEASE_HOLD` | **Honour it as printed.** Stop and say who set it. (`false`/`0`/`no`/unset is not held since nen `v0.2.0`; any other non-empty value fails closed as held) |
| Open `critical` issues | **Stop.** A release shipping past an open `critical` is the failure the severity exists to name |
| `CON-36` live chores | **Hold**, unless none has partial scope on `main` — and that reading is a `G5` ask for the maintainer, never your call (§ 5) |
| `changelog.d/` empty at the cut point | Collate — § 3 |
| `CON-33(c)` reconciled | Back-fill — § 3 |
| Tag does not already exist | Stop. Re-tagging is never the fix |

**Check the cut point, not the tip.** `--range`'s second half and `--changelog` must both name the
**cut point**, not `main`'s current tip — `main` moves while a release is assembled (RR-IS-#683 has
run six laps on exactly this), and a precondition verified against a tip that has since moved was
never verified at all.

## 3. The release unit — fold everything that can fold into ONE PR

`CON-33(b)` wants a release PR the maintainer merges before the tag cuts. **One PR carries all of
it:**

1. **Collate** every `changelog.d/` fragment into a dated `### vX.Y.Z — <theme>` section:

   ```bash
   nen changelog collate --version <vX.Y.Z> --theme "<text>" \
     --changelog <path to CHANGELOG.md> --fragment-dir changelog.d [--write]
   ```

   **Without `--write`, this only previews** — the rendered result, with neither `CHANGELOG.md` nor
   `changelog.d/` touched. **With `--write`, it rewrites `CHANGELOG.md` in place and deletes every
   collated fragment** — verified live against a constructed fixture (`docs/ab/getsuga.md` § 2.3):
   never hand-write the section, never leave a fragment behind.

   > **Finding, cosmetic, load-bearing to read correctly: `--write`'s printed manifest disagrees with
   > its own written order — the manifest is the wrong one, not the write.** Re-verified live, twice,
   > with numerically-named fragments, side by side against the real, extracted
   > `changelog_collate_fragments.sh` (`docs/ab/getsuga.md` § 2.3.1): the **written** `CHANGELOG.md`
   > section renders fragments newest-first (highest numeric prefix first) — `CON-33(b)`'s own
   > convention, "placed newest-first, directly below `### Unreleased`" — and this is **exactly** what
   > the old script's own `list_fragment_files` (`sort -k1,1nr`, numeric-descending) and every real
   > shipped `CHANGELOG.md` section (e.g. `<reference-repo>`'s `v0.11.3`: #899, #898, #890…
   > descending) already do — `nen`'s written body matches the old script's written body
   > byte-for-byte on the same fixture. The **printed manifest line**, however, lists the same
   > fragments in plain ascending filesystem-read order (`10-a.md`, `20-b.md`, `30-c.md`) — the
   > reverse of what was actually written. **The defect is the manifest disagreeing with the write,
   > not the write disagreeing with the shipping convention.** `CON-33(c)` — cited here in the earlier
   > draft of this finding — actually governs the *completeness check*'s own ascending numeric
   > comparison (§ 3.3 below), not this body-rendering order; the clause that governs the written
   > section's newest-first placement is `CON-33(b)`, already named above. **Never re-order the
   > written section by eye** — the written order is already correct, and hand-reordering it would
   > corrupt a real changelog into oldest-first. **The operational rule: trust the written order as
   > correct; note the printed manifest's mismatch as a `nen` defect** (a cosmetic report bug, not a
   > data-integrity one) so a reviewer diffing the PR by the manifest alone isn't misled into "fixing"
   > a section that was already right.

2. **Back-fill anything stranded.** A fragment present at the *previous* tag but never collated into
   that tag's section belongs **in the previous section**, not this one — decide it with
   `git ls-tree -r <prevTag> -- changelog.d`, never with file timestamps. **No `nen` verb owns this
   placement decision** — it stays a direct `git` read plus judgment (residue, `docs/ab/getsuga.md`
   § 3).
3. **The `CON-33(c)` release unit** — every PR merged in `<vPrev>..<cut-point>`, numeric order:

   ```bash
   nen changelog completeness --range <vPrev>..<cut-point> \
     --changelog <path to CHANGELOG.md> --owner-repo <owner/name> [--fragment-dir changelog.d]
   ```

   Verified live against the real `<reference-repo>` range `v0.11.2..v0.11.3`
   (`docs/ab/getsuga.md` § 2.4): **same verdict** as the old
   `scripts/changelog_release_completeness_check.sh v0.11.2 v0.11.3` run read-only side by side —
   both report every merged PR reconciled, exit `0`. Since nen `v0.2.0` (#83) `--fragment-dir` defaults
   to `changelog.d` here **and** in `release preflight` — the two verbs reconcile the same range and
   can no longer disagree about where fragments live — and an **empty** value, or a path that is not a
   directory, is refused; a directory that does not exist contributes no fragments. Omit the flag or
   pass a real directory; never `""`.
4. **Bump `latest`** in the registry — `nen/repos.json`, or, until `v0.4.0`, a `schemas/repos.json`
   the target has not migrated. No `nen` verb owns this write — residue, a direct edit — **so make
   sure it lands in the file nen reads**: `nen schema check --repo <path>` prints the row at the path
   it was actually read from (`ok nen/repos.json …`, or `warn schemas/repos.json … ^ legacy
   location`), and a copy present in **both** places with different bytes is a *shadowed leftover*
   that fails the check, because `nen/` wins the read and the edit you just made is the one nen
   ignores. Edit the file the row names; if both exist, migrate first (`git rm` the `schemas/` copy
   once the bytes agree).
5. **Bump `.claude-plugin/plugin.json`** — same reasoning as the old skill: a cached plugin would
   report consumers current while they sit a tag behind. No `nen` verb owns this write either —
   residue, a direct edit; prefer the bump to a `no plugin bump:` opt-out.

**What cannot fold: the `CON-22` repin PRs.** They target *other repositories*. One PR per affected
consumer, after the tag, § 7.

> **Self-enumeration is a fact to check, not a habit.**

```bash
nen release self-check --repo <path> --pr-merge-sha <sha> --previous-tag <vPrev> --cut-point <vNew>
```

True iff the release PR's own merge commit is reachable from `--cut-point` and **not already**
reachable from `--previous-tag` — a git-mechanical fact, never a judgement. Verified live against
the real `v0.11.3` release PR (RR-PR-#916): `nen` reports it **should list ITSELF** against
`v0.11.2..v0.11.3` (correct — that PR's merge is the cut point), and **should NOT list itself**
against `v0.11.3..v0.11.3` (correct — already reachable from its own tag). Four laps got this wrong
by hand in `<reference-repo>` (RR-PR-#651, RR-PR-#679, RR-PR-#682, RR-PR-#691) before this existed.

> **Collation manufactures contradictions — look for them.** Two fragments written weeks apart are
> each true when written and become **simultaneous claims** in one dated section. Before opening the
> PR, read the assembled section for entries that contradict each other. **Reconcile in place; never
> delete the superseded entry.** State the **net effect** so nobody has to reconcile two entries
> themselves. This stays judgment — no verb reads intent.

Then **stop at G4** with the banner and the board:

```bash
nen stop --who kurapika --gate G4 <efforts.md>
```

The maintainer merges; Kurapika never merges `main` (`CON-5`/`CON-7`).

## 4. The cut

After the release PR merges, re-fetch and cut with `nen tag cut`, which enforces reachability
itself:

```bash
nen tag cut --repo <path> --name <vX.Y.Z> --at <the release PR's merge SHA> \
  [--message "<text>"] --push
```

> ⚠️ **Pin the commit explicitly — never `HEAD`.** `--at` is required and never defaulted;
> `nen tag cut --help` states this outright. "Cut from `main`" is not an instruction the verb can
> follow: if `main` advanced between the merge and the cut, `HEAD` is a *later* commit, and the tag
> then covers PRs whose fragments are still uncollated. **Check out the release PR's merge SHA and
> cut there**, after re-verifying § 2 at that SHA — exactly how the `v0.10.0` window kept re-filling
> (RR-IS-#683).

- **Cut the reconciled commit, not necessarily the tip.** Verify § 2 again at that exact SHA before
  cutting; if either the `changelog.d/` or `CON-33(c)` row fails there, the cut needs another
  collation lap.
- **`--at` not an ancestor of `origin/main` → refused, never tagged off-trunk.** **The tag name
  already existing, locally or on origin → refused, never re-tagged.** Both verified live in a
  disposable scratch repo, never against `<reference-repo>` or `hatsu` (`docs/ab/getsuga.md` § 2.5):
  cutting at an unreachable commit refuses with `is not an ancestor of origin/main ... Use 'nen
  release resolve-target' first`; re-cutting an existing name refuses with `already exists locally
  -- never re-tagged`.
- **The tag is created LOCALLY ONLY unless `--push` is passed — verified live**: without `--push`,
  `git ls-remote --tags origin` on the scratch remote stayed empty after the cut; with `--push`, the
  annotated tag reached origin and nothing else did. **A tag getsuga cuts is meant to resolve for
  consumers — pass `--push`**, the same effective outcome the old `scripts/tag_cut.sh` always
  produced by pushing unconditionally; the verb just makes the push an explicit, visible step rather
  than an implicit one (`docs/ab/getsuga.md` § 2.5, § 3).
- **If the tag capability is refused, HALT and hand the maintainer the exact command.** Never
  improvise, never switch mechanisms — a REST tag-ref create is a bypass, not a workaround — and
  **never write `latest` or a dated CHANGELOG section for a tag that does not resolve** (`CON-14`).
- **Never re-tag, never move a tag, never force a tag** — `nen tag cut` itself refuses all three;
  there is no flag that overrides it.

## 5. The one judgement this skill must not make alone

`CON-36` clause 4 says a tag proceeds "only when no such branch is live **for the change being
released**", and also that liveness is "detected **mechanically** (no judgement call)". When
`nen release preflight`'s mechanical three-part test reports live chores but none has partial scope
on `main`, those two halves disagree. **That is a `G5` ask, put through the harness's question
interface, with the chores named, what each carries, and a recommendation** — never a call getsuga
makes on its own and mentions afterwards. Record the ruling in the release PR body.

## 6. An off-main target — build it, then tag it

The maintainer's ruling: an unreachable target is **driven to `main` first**, not refused.

1. **Say what is about to happen** — this is now a delivery, and it stops at their gate partway.
2. **Get it onto a PR.** An existing open PR for that branch is used as-is. A branch with **no** PR
   needs one — check that branch out first, then hand it to
   [`hatsu:tensho`](../tensho/SKILL.md), which works on **the current checkout**, not on a branch
   named as an argument. Its § 2 (`nen wc classify`) then sees "on a branch, clean" and opens the PR.
3. **Drive it to `CON-32` readiness.** Hand it to [`hatsu:sharingan`](../sharingan/SKILL.md) — its full
   engine, not a substitute for one: the first-blocking-condition diagnosis, thread stewardship,
   the wake channel, the adversarial confirmation pass and the escalation ladder are all that
   skill's, and getsuga does not restate or reimplement any of them. Invoke it as
   `hatsu:sharingan <CODE>#<N> to <G2|G4>` against the gate `nen gate derive` named, and take its
   stop-at-the-gate report as the readiness call.
   *Fallback only if `sharingan` cannot run at all* (an unresolvable code, say): the readiness call by
   itself is [`hatsu:pr-state`](../pr-state/SKILL.md)'s verb — `nen pr ready <ref> --explain`, with
   `GH_TOKEN` exported and, where the target ships its own `nen/gates.json` (or a legacy
   `schemas/gates.json`), no `--gates` at all — or `--gates
   "$CLAUDE_PLUGIN_ROOT/contracts/reference.gates.json"` (absolute) where the target is frozen
   `<reference-repo>` — quoted verbatim. That is a **check**, not a drive: it reports where the PR stands
   and nothing moves it.
4. **Stop at G2/G4.** The maintainer merges.
5. **Re-resolve the target** — it is now a commit on `main`, and a *different* commit than the
   branch tip was (a merge commit). Tag that. Then § 2 from the top, because every precondition must
   hold at the **new** cut point.

## 7. Fan-out (`CON-22`), after the tag

Compute the affected set with one verb:

```bash
nen --repo <path> fanout compute --range <vPrev>..<newTag>
```

`changed-workflows(vPrev..newTag)` intersected against each registered consumer's `consumes` from
`nen/repos.json` (legacy `schemas/repos.json` until `v0.4.0`) — every consumer comes back `AFFECTED`
with the workflow basenames that hit it, or an implicit N/A. Verified live against the real range `v0.11.2..v0.11.3`
(`docs/ab/getsuga.md` § 2.6): `nen`'s output reproduces the historical `CON-22` determination
recorded by hand at that release's own registry entry (RR-PR-#916) **exactly** — `<product-repo-A>`
affected via the same five files, `<product-repo-B>` via the same four, `<scaffold-repo>` via the
same one. **Record every unaffected consumer as an explicit N/A with its basis** — an
unstated N/A is indistinguishable from an unswept repo.

**An empty affected set is a real and common result.** Say so with the basis; do not go looking for
something to repin.

`nen fanout record --range <vPrev>..<newTag> [--ledger <path>]` appends the same computation to an
audit ledger — it **never opens a repin PR itself**, per its own `--help`; this is a mutating write
(a local ledger file, not GitHub) and was A/B'd by contract inspection only, never exercised against
a live repo (`docs/ab/getsuga.md` § 3). **Opening the repin PR in each affected consumer remains
this skill's own action** — it targets *other repositories*, which no `nen` verb here does.

## 7a. A deploy — the plan is printed at G3; the run is the maintainer's

A tag is not a release, and a release is not a deploy. Where the repository being cut **declares** a
`deploy` verb and a named destination in its `nen/contract.json` (`project.verbs.<lane>.deploy` plus a
key of `project.targets` — nen `v0.3.0`), the G3 stop carries the plan beside the preflight table:

```bash
nen shu deploy --repo <path> --lane <lane> --target <name>      # the plan: exit 0, nothing sent
```

Without `--run` the verb prints the fully resolved plan — the destination's `args` substituted into the
lane's own argv, every precondition and `requiresEnv` variable **asserted** (never read or printed),
each step as `would run:` — and spawns **nothing**, at exit `0`; `--target` is required with no default,
even for a single declared destination, and `--run --dry-run` together is exit `2`. Exit `0` is the plan
on a host that could send it: an unsatisfied precondition — the lane's own, or a variable the target's
`requiresEnv` names that is not set here — is exit `2` **with the report** (the plan still prints, the
failing rows marked `FAIL`, and the last line says how many preconditions are unmet; verified live at
`v0.3.0`: *"1 precondition on lane 'site' is not satisfied. nen ASSERTS a precondition and never performs
it"*), and a `--target` naming no declared destination is exit `2` listing the declared ones. A G3 stop
carries whichever of those the host produced, never a plan rewritten to look sendable. **`--run` is the
maintainer's word at G3 (`CON-6`), per target, recorded in the release PR body — never this skill's.** A
lane whose `deploy` is a seat answers exit `4` with the declaration's own reason whatever `--target`
says (verified live at `v0.3.0` on a scaffolded `nextjs` tree: *"'deploy' is unsupported on lane
'nextjs' … The declaration's own reason: PROPOSED SEAT — replace it …"*), and that is the whole report
for such a repository: it declares no deploy. A repository with no declaration at all is not deployed
through nen and this section does not apply. `<reference-repo>` is machinery and declares none.

## 8. Authority

- **Permitted:** the tag cut (`CON-33(b)`/`CON-41` — Kurapika's own duty, **not** a `CON-25`
  delegation), the release PR, the repin PRs, and printing a declared deploy's **plan** (§ 7a).
- **No routing and no release delegation — none, including while driving.** Driving an off-`main`
  target runs entirely through [`hatsu:tensho`](../tensho/SKILL.md) and
  [`hatsu:sharingan`](../sharingan/SKILL.md), and **neither of those releases anything** (`CON-25`, fourth
  carve-out). If a target genuinely needs an issue routed or released to reach `main`, that is
  [`hatsu:build`](../build/SKILL.md)'s job and its own invocation — **say so and stop**, rather
  than borrowing its authority from inside this run.
- **Never:** merge `main`; publish a GitHub Release or authorize a release (**G3 is the
  maintainer's**, `CON-6`); run `nen shu deploy --run`, in any spelling; move or delete a tag; write
  `latest` for a tag that does not resolve; apply a G1 mode label.

## 9. Hard limits

- **Never tags a commit unreachable from `origin/main`** — `nen release resolve-target` and
  `nen tag cut`'s own `--at` check both enforce this; verified live in scratch, never against
  `<reference-repo>` or `hatsu`.
- **Never tags past an open `critical`, an active `RELEASE_HOLD`, or an unreconciled `CON-33(c)`** —
  and read the `RELEASE_HOLD` row exactly as printed: since nen `v0.2.0` `true`/`1`/`yes` is held,
  `false`/`0`/`no`/unset is not, and any other non-empty value fails closed as held (§ 2).
- **Never deploys.** § 7a's plan is the most this skill prints; `--run` is the maintainer's at G3.
- **Never rules on `CON-36` clause 4 itself** — that is `G5`.
- **Never deletes a superseded CHANGELOG entry** to resolve a contradiction.
- **Never publishes the release.** Preparing it is the job; G3 is not.
- **Never routes around a refused capability.**
- **Never re-orders `nen changelog collate --write`'s written section by eye.** The written body is
  already correct (newest-first, `CON-33(b)`) — verified live against the old script's own written
  output, byte-for-byte. Only the **printed manifest** disagrees with the write; note that mismatch
  as a `nen` defect, never "fix" the section itself (§ 3).
