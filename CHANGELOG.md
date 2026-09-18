# Changelog

## v0.38.0 — the readiness verdict is published where a human can see it

- **New `.github/workflows/pr-readiness.yml`**: a deterministic `pull_request_target` job that runs `nen pr ready --explain` on every event that can change the answer and publishes the verb's own output as the **`readiness` check run**. The computation was never the gap — `nen pr ready` already evaluates `CON-42/1`, `CON-32(a)`, `CON-32(b)`, `CON-32(b)`/`CON-16` and `CON-32(d)` — the gap was that the verdict only ever existed in a session's terminal or a `rikugan` report, so a PR that reached its gate after the session ended told nobody.
- **Not a label, and not a title.** A label needs `pull-requests: write`, which `scripts/workflow_runner_policy_check.rb` refuses — only `checks: write` is admissible on a `pull_request_target` job, and widening that is a `G4` ruling about the CI trust boundary. The title is authored content: `shibari` composes it as a Conventional-Commits subject that becomes the squash-merge subject `nen commit format` validates, so a machine rewriting it corrupts the history the repository derives from it, and it would churn on nearly every event because every push re-owes every reviewer round.
- **The conclusion is always `success`, by construction.** `CON-32(a)` requires every reported check green, so a readiness check that concluded `failure` while a PR was not ready would itself be the red check making `CON-32(a)` unsatisfiable — the signal would make the thing it measures permanently unreachable. The verdict rides in the check's title and summary; `--exclude-run` drops the run's own checks for the same self-reference reason. The check is **advisory** and must not be made required: it is `success` on every PR, so requiring it would assert nothing.
- **The refusals are restated, not relaxed.** `shibari` § 7 gives the reason a gate label was always refused — *"Applying a gate label is a claim about readiness, and readiness is … decided by `nen pr ready`"* — which objects to an **agent** asserting readiness, not to readiness being written down. `shibari` § 7 and `en` § 9 now carry that distinction, and the refusal lines in `en`, `mukai`, `pr-state`, `backlog-state` and `backlog-board` read "itself" / "of its own". `sharingan`, `build` and `backlog-loop` are untouched: their refusals are of `G1` **mode**, **stage** and **severity** labels, which are a different claim.
- **`en` § 9 item 4's named gap is supplied from outside the plane.** Persistence past the session had "no mechanism at all" in this plane; the workflow is not a watch and grants `en` nothing — it never merges, votes, comments or wakes.
- Hardening is inherited from `plugin-bump-check.yml` unchanged: guard code and the nen pin come from the trusted workflow revision, both checkouts set `persist-credentials: false`, the job is same-repository only, the pinned ref reaches the shell through `env` rather than a `${{ }}` expansion inside a `run:` block, and `nen/gates.json` is read from the trusted checkout rather than the PR's copy.
- The workflow is registered in all four of the policy guard's frozen tables. `PORTABLE_HOSTED_WORKFLOWS` doubles as the required-presence list, so deleting the signal now fails the guard.

## v0.36.0 — a tag records a build that landed

> **This was `v0.34.0` until `v0.35.0` merged first.** The bump is `v0.36.0` because `main` is already at `v0.35.0`, and `scripts/plugin_bump_check.sh`'s `version_bumped` asks only whether HEAD's `version` DIFFERS from base's — never whether it is HIGHER — so landing `v0.34.0` on top would have shipped a manifest downgrade past a green check. Copilot caught the ordering hazard on `#76`; this is the re-bump that answer prescribed, carried out rather than assumed. **A guard rejecting a non-increasing bump is still owed** and wants its own issue.

- **`kagutsuchi` § 4a cuts the tag**, after a `--run` send that returned exit `0`, from `nen/workflow.json` → `tags.deploy.<target>`. One artifact that reached a destination is one tag.
- **`susanoo` § 5a cuts nothing.** It reads `tags.identity` and *names* the identity the coming tag will carry, in one line of its report. Its standing property — *nothing leaves this machine* — is literal again.
- The symmetry, in the maintainer's own terms: **an upload that succeeds becomes a tag, and a release Apple approves becomes a GitHub release.** A build that was never sent has nothing to point at, and a permanent public ref for one was the defect in the first shape of this ruling.
- **ONE name source, shared.** `tags.identity.nameFrom` holds the tag's IDENTITY (`v1.0.0+1217`); susanoo announces it and kagutsuchi cuts `dist/<target>/<identity>` from the SAME file, composing the species prefix from the target it was actually called with. An earlier shape gave each skill its own `nameFrom`, so a repository could announce one name and push another — and in the reference consumer it did.
- **`tags.deploy.<target>` is read before anything is cut**, so a repository declaring only `tags.identity` gets no tag at all and an undeclared target is reported `not declared for this target`. The target itself is data — quoted into a variable, passed as an argument — and the species prefix is *composed* from it rather than pattern-checked.
- **The identity file carries the build commit on line 2, and the tag is cut there, not at `HEAD`.** The announce and the cut are separate invocations with a human decision between them; a tag at `HEAD` would name a commit the archive never saw.
- **Opt-in per consuming repository**, off by default. A repository declaring neither behaves exactly as before.
- **The name is the repository's**, read from a declared `nameFrom` as **data**: never templated into shell source (`$(…)` inside double quotes is command substitution), symlinks refused rather than followed, out-of-tree paths refused, empty first line refused, and validated with `git check-ref-format` before anything is spawned.
- **A species prefix is mandatory** (`dist/<target>/`). The tag shares one namespace on `origin` with `getsuga`'s release tag, and `mugetsu` proves a release tag by its name resolving there — an unprefixed tag could permanently take a version nothing may delete. `mugetsu` § 3 now says in rule that only `getsuga`'s release tag satisfies its precondition.
- **The ancestor rule is stated correctly**: `--at` is refused unless that COMMIT is an ancestor of `origin/<trunk>` — not a rule about branches, since a feature branch at the trunk's tip tags fine. What keeps a tag from attesting the wrong bytes is the **clean-tree** condition. `--trunk` comes from `branch.base`, never defaulted.
- **The non-atomic push has one sanctioned remedy.** A rejected push leaves the name taken locally and absent on `origin`, which the verb then refuses forever; a local tag of that name, at that SHA, verified absent from `origin`, may be deleted and re-cut — the completion of an unfinished cut, not a re-tag.
- Recorded as **Rulings of 2026-09-18, corrected 2026-09-19** in `docs/ROSTER.md`.

## v0.35.0 — a bot reviewer is a different route

> **`v0.34.0` is the tag ruling**, on `opus/kurapika/tag-authority`, still open. This change is independent of it and takes the next version deliberately so the two bumps do not collide. **The order is not free, and an earlier draft of this line said it was.** `scripts/plugin_bump_check.sh`'s `version_bumped` asks only whether HEAD's `version` DIFFERS from base's, never whether it is HIGHER, so it would pass `v0.34.0` landing on a `main` already at `v0.35.0` — shipping a manifest downgrade with a green check. **So: `#75` merges first, or it is re-bumped to `v0.36.0` before it does.** A guard that rejects a non-increasing bump is worth its own issue; until it exists this is coordinated by hand.

- **`sharingan` records how to re-request a Bot reviewer**, and why the obvious attempts fail. Copilot is a `Bot`, not a `User`: `gh pr edit --add-reviewer` silently never resolves one (`zheref/nen#160`), REST `requested_reviewers` answers `422 may only be requested from collaborators` for a login missing its exact `[bot]` suffix, and GraphQL `requestReviews` resolves `userIds` as Users only.
- **`nen pr request-reviews` already routes correctly** — a bare login the PR knows as a Bot goes to the bot mutation, and `--add-bots <node id>` covers one it has never seen. The gap was that nothing said so.
- **Verification is the other half.** REST's `requested_reviewers` lists users and teams only, so a *pending* bot request reads as `[]` — a caller checking there confirms the opposite of the truth. `nen pr ready`'s phrasings are the signal: *no round at head* (a request is owed) versus *review requested, not yet posted* (one is in flight; wait).
- **Requesting an owed round is not an escalation.** Taking it to the maintainer spends § 6's ladder on a step the run can perform itself — which is what prompted this: a session concluded the re-request was impossible on the maintainer's own credentials and handed it back as a gate.

## v0.33.0 — standalone entry: every skill reachable from a cold checkout

- New authority `docs/STANDALONE-ENTRY.md`: the cold-start preamble (P1 warm up, P2 orient, P3 establish the delta, P4 elicit, P5 declare), the four inherited-state classes S1–S4, the per-surface option-picker matrix, and the two rules — every skill is reachable alone, and **no skill is ever indefinitely independent**.
- **Twenty skills gain a `## 0. Standalone entry` section**, in two groups. Thirteen derive state cold (S1–S4): `breath`, `kokusen`, `tsukuyomi`, `amaterasu`, `kotoamatsukami`, `byakugan`, `sharingan`, `hanten`, `rikugan`, `kagutsuchi`, `mugetsu`, `third-hand`, `murasaki`. Seven add P1, orientation and expectations only: `gyo`, `ao`, `susanoo`, `aka`, `jutaisho`, `shibari`, `rasengan`. `docs/STANDALONE-ENTRY.md` § 7 is the authority and lists both.
- The delta default is the **fetched `origin/<branch.base>`** — the remote trunk, never the local ref — and it is the union of the committed and uncommitted change sets. `against <base>` overrides it everywhere.
- Breath inverts its new-effort default when typed by hand: work in progress on the current branch **is** the continuation signal, so a cold warm-up over an IDE session no longer cuts past it.
- Tsukuyomi derives `--lane` from the delta instead of refusing, and where no declared focused route covers the change it **offers to have the tests authored** (by `rasengan`) rather than ending the run.
- Hanten **enforces `breath`** when the `.nen/hanten/<branch-slug>.cycle.json` ledger is absent, and asks for the review scope when the delta does not classify cleanly — it never raises the full bench to be safe.
- Sharingan resolves `#<PR>` from the current branch when it is omitted; none / several are stop-or-ask, never a guess.
- `kagutsuchi` and `mugetsu` gain orientation and **no authority**: `G3` is unmoved, the go is still the maintainer's own recorded words, and the invocation is never the go.
- `murasaki` typed alone does its own step 1 and finishes it: fetch, catch the branch up with `origin/<branch.base>` through `ao`, resolve the mechanical conflicts, stop at **G5** on a semantic one, run the shared checks over the caught-up tree. It declines only what was never its — no tests, no coverage, no squash, no force-push, no first-publish, no PR — and does not push where the catch-up invalidated evidence.
- **Maintainer's ruling, 2026-09-18 — the base is the LATEST trunk.** `git fetch origin` runs first and the base is `origin/<branch.base>`; the local ref is used only where that fetch has just proved it equal. A fetch that cannot run is a stop, because *latest* is a claim only the fetch establishes.
- **Maintainer's ruling, 2026-09-18 — `against <base>` is the delta clause, and it is now declared.** `kokusen`, `tsukuyomi`, `kotoamatsukami`, `rikugan` and `hanten` gain it in their own grammars beside `byakugan`, verified live at nen `0.10.0` including the two-clause (`on [<lane>] against [<base>]`) and enum-plus-base (`for [<scope>] against [<base>]`) shapes. `ao` and `murasaki` keep `from <base>`: a delta is read *against* a reference, a catch-up pulls *from* a source, and unifying them would make one inaccurate. No skill documents a clause `nen parse` would refuse.
- **Maintainer's ruling, 2026-09-18 — breath runs at most once per session, and is never skipped when owed.** A second run in one session reports and returns instead of refusing on a branch name that already exists. The guard is the session's own record, not a file: a later session re-enters and reads the checkout.
- **Maintainer's ruling, 2026-09-18 — breath guarantees an outcome, not just a verdict.** However the checkout looked when it was called, a standalone run ends as *a branch off a `main` that was proven green, carrying the maintainer's own commits on that proven tip, with their uncommitted changes still present and still uncommitted*. Four steps: **preserve** (`git stash push --include-untracked`, SHA captured and printed, addressed by SHA and never `stash@{0}`), **prove** (every `iteration.checks` entry against `origin/<branch.base>` in an isolated worktree, holding none of the effort), **place** (the commits replayed onto the proven tip through `ao` — rebase when nothing is published, **merge when something is**, because a published commit is never rewritten), **restore** (the stash reapplied, still uncommitted; never dropped on a failure).
- **The win: a red after the restore is the effort's, mechanically.** The base was proven on a tree that held none of the work, so attribution stops being a judgement call — which retires the cost the earlier § 0c ruling had to accept, that a late red could not be told apart from a pre-existing one. A red base is a G5 taken *before* anything returns, with the stash restored first — breath never leaves the maintainer stashed at a stop.
- Rewriting a commit is confirmed before it happens, with the counts in the question; stash-and-restore is not, because it is reversible and ends at the same tree. A checkout on the trunk has nothing to rewrite and is not asked at all.
- **Hanten § 0a no longer asks its own ledger question** — it routes to breath, breath's only writer, and reports a lost ledger when one is still absent afterwards. Two skills asking the same question in one run is how a maintainer learns to click past both.
- A `git fetch` that fails, an absent `origin`, or an unresolvable `origin/<branch.base>` **stops** and names the condition; `(fetched <sha>)` is never printed for a fetch that did not run.
- `docs/STANDALONE-ENTRY.md` is added to `scripts/plugin_bump_check.sh`'s guarded surface and to the *Shared policy location* preamble, which now ships in every skill that links it — a runtime-read authority that no bump guard covered would have shipped edits to nobody.
- The skip condition is generic on both sides: every phase says *reached from ANY composite, skip this section*, and all ten composites that call one carry the clause — a phase carrying a list of its callers is the list that goes stale.
- `ren`, `mukai` and `en` state that the phases they call skip `## 0` entirely, so a wired run derives nothing twice.
- Every standalone run ends with a **hand-back line** naming its successor, and never offers to run the five phases that are the maintainer's alone.

## v0.32.0 — plugin updater isolation, focused lane, and refuse paths

- `scripts/hatsu_plugin_update.sh` unsets `GIT_DIR` / `GIT_WORK_TREE` (and related git redirectors) after the filesystem identity check, so `git -C --root` cannot mutate a different checkout.
- A nested Hatsu tree without its own `.git` is not treated as the enclosing repository: `rev-parse --show-toplevel` must match `--root`.
- Stable tags are strict `vX.Y.Z` (digits and dots only); `--auto` will not treat `v1.2.3.4` as a release consumer.
- `--channel release` with no stable `vX.Y.Z` tags refuses instead of silent exit 1; a missing origin and unreadable `.git` are named skip/refuse paths.
- Warm-up cites `$hatsu_root` for updater fixture and SURFACES paths so nested Antigravity mirrors do not get a broken `../../../` link.
- Focused `plugin-update` lane declares the updater fixture; `plugin-bump-guard` asserts the updater glob.
- Landed as ([#68](https://github.com/zheref/hatsu/pull/68)).

CON-33(c) PRs merged since `v0.14.0` that were not yet numbered in this file, numeric order. Net: [#68](https://github.com/zheref/hatsu/pull/68) is numbered by the landing bullet above; it is omitted here so it is not listed twice.

- ([#58](https://github.com/zheref/hatsu/pull/58)) keep Mukai active through PR readiness
- ([#59](https://github.com/zheref/hatsu/pull/59)) run portable checks on hosted Linux
- ([#61](https://github.com/zheref/hatsu/pull/61)) Antigravity surface support, hooks, and model policy
- ([#62](https://github.com/zheref/hatsu/pull/62)) split tests, coverage and lint across mukai and ren
- ([#64](https://github.com/zheref/hatsu/pull/64)) Netero, Hanten cycle caps, and Third-Hand after En
- ([#70](https://github.com/zheref/hatsu/pull/70)) this release PR (CON-33(c) numbering for the v0.32.0 tag)

## v0.31.0 — plugin source auto-update across surfaces

- Warm-up keeps a consumer plugin checkout current before it refreshes a target: `scripts/hatsu_plugin_update.sh --auto` fast-forwards trunk or the newest `vX.Y.Z` tag, skips dirty and authoring trees, and never discards.
- Claude Code's versioned cache is not a git checkout; the same script names `claude plugin update hatsu@hatsu`, and warm-up passes `--claude` there.
- Documented per-surface update recipes and how to point each surface at a local checkout so Cursor does not bind a stale Claude plugin cache while authoring this tree.

## v0.30.0 — Hanten cycle ledger fail-closed

- Cycle ledger `init` is Breath's after the branch cut. `decide` / `record` / `show` refuse a missing file instead of treating absence as a new cycle.
- Load-mutate-save is serialized with an exclusive lock and a unique temp path.
- `skipped-exhausted` is refused while `used < max`.
- G5 blocker owner list includes kokusen; first finding separator is sibling-based; blocker captures use the same data-URI rule as evidence.

## v0.29.0 — Illumi Codex spawn; generated inventory

- Illumi's En observation hand-off uses Codex in-session spawn; Hanten's reviewer isolation stays a second `codex exec`.
- Generated surface inventories: 41 skill files (forty plus warmup) and 9 personas.

## v0.28.0 — Third-Hand is a phase after En; Codex and Antigravity pickers

- **Third-Hand** is a separate phase that starts once En has completed. En ends at the gate and does not harvest.
- Codex asks through `request_user_input` (never lettered options) and raises Netero in-session (`spawn_agent`). Antigravity asks through `ask_question` (`is_multi_select: true`) and raises Netero with `invoke_subagent` `Workspace: "inherit"`.

## v0.27.0 — Third-Hand closes the sitting with Netero's harvest

- Added **third-hand**: after En's retained final report, Netero runs in parallel, folds this sitting's process friction into 0–3 issues, the maintainer picks which to file through the surface picker, those are filed, then the session is over. He never implements the filed work. The merge stays a human G2 act with no skill.

## v0.26.0 — cap Hanten reviewer reruns per effort

- **Hanten** records each reviewer invocation in `.nen/hanten/<branch-slug>.cycle.json` for the whole effort. Applicability and remaining budget are separate questions; an exhausted reviewer is skipped, not invoked. Maxima: Feitan 1, Chrollo 1, Phinks 1, Hisoka 2, Uvogin 3. Remediation, a resumed session, and a later Ren or Mukai re-entry reuse the same counts. Only Breath cutting a new branch resets them ([#63](https://github.com/zheref/hatsu/issues/63)).

## v0.25.0 — Netero; Breath cuts a new branch; G5 reports explain the stop

- Ratified **Netero** as process chairman: he observes Hunter execution and files complete, labelled issues when constitution, canon, or machinery need enhancement, with cross-references for deployment, fan-out and provisioning (roster ruling 2026-09-14).
- **Breath** and **Ren** treat a new request as a new effort: fetch the configured base and cut a freshly rendered branch even from a clean unrelated feature branch. An existing branch is reused only for an explicit continuation ([#60](https://github.com/zheref/hatsu/issues/60)).
- **G5 stop reports** carry a `blocker` payload on the Rikugan `turn` page — step, rule, expected versus actual, this-run visual evidence — and Jutaisho verifies that content before the stop handoff links it ([#56](https://github.com/zheref/hatsu/issues/56)).

## v0.24.0 — byakugan owns coverage; kotoamatsukami owns tests

- Added **byakugan** for coverage capture and measurement at mukai, independent of unit, UI and integration testing. Grammar `against [<base>]`. Never runs `test` or `ui-test`.
- Restored **kotoamatsukami** to tests only (plus UI evidence). Mukai still runs tests then coverage, as two skills.
- Left **gyo** as linting on every Ren turn.

## v0.23.0 — gyo is linting; kotoamatsukami owns coverage

- Renamed **gyo** to the linting process (`nen shu lint`) on every Ren turn: breath on the tip, rasengan may, kokusen must, aka before squash and after catch-up.
- Folded coverage capture, extraction, banding and the under-minimum G5 onto **kotoamatsukami**, still at mukai, still after the impacted suites. Behaviors did not move; the names did.

## v0.22.0 — rikugan session archive vs last-turn board

- Kept **00 This last turn** as the last human request only.
- Required **01–07** (accomplished, challenges, not delivered, architecture, screenshots, launch, decisions) to cover the whole session against the base, on every process or product effort. A later turn that rewrites those lists from only the latest request is a defective page.

## v0.21.0 — rikugan last-turn highlights and structural architecture delta

- Opened every Rikugan page with **00 This last turn**: highlights against the last human request (`done` / `not-done` / `partial`). A mukai-triggered page also names what was corrected (who asked, why, handled or pushed back), local checks that brought work back, and any half-run stop with the policy and how later iterations can go further unattended.
- Made **04 Architecture delta** a change-highlighted board of conceptual nodes and relations. `files[]` remains a supporting path inventory, not the glance target.

## v0.20.0 — focused tests at ren, impacted regression at mukai

- Moved project-wide regression off aka. Aka now lints, squashes unpublished history, catches up, re-lints if that moved the tree, and pushes.
- Made tsukuyomi the focused-test executor on every ren turn; kokusen still owns the checkpoint.
- Made kotoamatsukami the sole owner of pre-mukai project-wide tests, selecting only declared suites the change can affect, immediately before gyo extracts coverage.

## v0.18.0 — complete local workflow and explicit review policy

- Documented the one-request entry path across Claude Code, Codex, and Cursor ([#45](https://github.com/zheref/hatsu/pull/45)).
- Made first-run surface bootstrap transactional and safe around user-owned files, closing [#46](https://github.com/zheref/hatsu/issues/46) in [#47](https://github.com/zheref/hatsu/pull/47).
- Aligned authoring, verification, launch, discovery, regression, coverage, and UI evidence phases; adopted Nen 0.9 device extraction and closed [#48](https://github.com/zheref/hatsu/issues/48) and [#49](https://github.com/zheref/hatsu/issues/49) in [#50](https://github.com/zheref/hatsu/pull/50).
- Preserved canonical Hatsu/Akatsuki agent provenance while excluding model, runtime, surface, and session credits, authored for [#51](https://github.com/zheref/hatsu/issues/51) in stacked [#52](https://github.com/zheref/hatsu/pull/52) and landed on main by [#55](https://github.com/zheref/hatsu/pull/55).
- Moved Hatsu CI to trusted self-hosted macOS runners and denied fork PR runner allocation, closing [#53](https://github.com/zheref/hatsu/issues/53) in [#54](https://github.com/zheref/hatsu/pull/54).
- Adopted published Nen 0.10 and its explicit Copilot-only `review-round-only` readiness policy while retaining the maintainer's separate human merge decision ([#55](https://github.com/zheref/hatsu/pull/55)).

Version history: main advanced through plugin cache versions 0.15.0 (#47) and 0.16.0 (#50). Attribution PR #52 introduced 0.17.0 but merged into the old #50 branch, not main. Release PR #55 preserves that merge and lands its attribution changes on main together with 0.18.0. No 0.15–0.17 official tags were cut; this consolidated release follows v0.14.0.

Nen 0.10 release: [zheref/nen v0.10.0](https://github.com/zheref/nen/releases/tag/v0.10.0).
