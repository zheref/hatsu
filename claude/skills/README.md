# Hatsu skills

This directory is the plugin's skill surface (`plugin.json` → `"skills": "./claude/skills/"`). The summon
surface lives beside it at `claude/commands/` (`"commands": "./claude/commands/"`); both are listed together
under *Skills* by `claude plugin details`, which is why they are described together here.

**Forty-four skills at `v0.45.0`** (forty-three at `v0.43.0`, forty at `v0.30.0`, forty-five directories per surface with `hatsu-warmup`): the **seventeen ported skills** ([zheref/hatsu#2][2]) that made the
surface complete at `v0.1.0` — one of them, `drive`, **renamed to [`sharingan`](sharingan/) at `v0.5.0`** —
the **ten workflow skills** added at `v0.4.0`, the **eight added at `v0.5.0`** that carry the PR side,
**[`byakugan`](byakugan/) at `v0.24.0`**, the
**three added at `v0.6.0`** that close the release side,
**[`third-hand`](third-hand/) at `v0.27.0`** (a separate phase after En from `v0.28.0`), **[`great-hiker`](great-hiker/) at `v0.43.0`** (the canon-authoring skill, in its own section), and the **two roster-machinery residents** that
arrived with the skeleton ([zheref/hatsu#1][1]) and are counted separately. Nothing here is reserved, and
nothing here is a placeholder.

Each skill is a directory holding a `SKILL.md` with `name` and `description` frontmatter. Invoke one as
`hatsu:<name>`. **`v0.7.0` adds no skill**: the count is unchanged, and what it adds is two *generated*
mirrors of this same directory for Codex and Cursor — see [*Surfaces*](#surfaces--this-directory-is-the-one-authored-copy)
below.

> **Redaction notice — applies to every file under `claude/`.** These skills and agents quote real tool
> output in which the names, slugs and object ids of repositories that are not public are replaced by
> stable placeholders (`<reference-repo>`, `<product-repo-A>`, `RR-IS-#<n>`, `RA-PR-#<n>`, …). The
> transcripts are otherwise verbatim. The legend and the deliberate survivors are documented once, in
> [`docs/PUBLIC-REDACTION.md`](../../docs/PUBLIC-REDACTION.md).

---

## The nineteen ported skills

Ported from the frozen reference implementation **under their existing names** — only the mechanics changed: **every deterministic
step that has a verb** is a [Nen](https://github.com/zheref/nen) verb, where it used to be improvised shell
(`gh`, `git`, hand-rolled API calls). What stayed with the skill is deliberate — severity reasoning,
synthesized titles, root-cause grouping, the adversarial confirmation pass, and the *ask* on every flagged
staging file. Nen detects, computes, formats and verifies; it never decides what only judgment can.

**Some deterministic steps still have no verb**, and those are not silently improvised either: the leftover
is **named per skill**, as a residue section, in that skill's own file under [`../../docs/ab/`](../../docs/ab/).
A residue lapses when the pin moves and a verb arrives for it — `nen issue comment` (`v0.2.0`) retired the
raw `gh issue comment` that `file` and `backlog-synthesis` carried, and the `nen shu` family (`v0.3.0`)
gave `build`, `futon` and the roster's builders a declared build, test, lint, coverage and warm-up to run
instead of a remembered command line. The A/B files record the mechanics *at port time*; each `SKILL.md`
is reconciled to the contract's pinned ref and is what runs.

**Each one carries its own A/B evidence** in [`../../docs/ab/`](../../docs/ab/): the old mechanics, the new
mechanics, and a live transcript showing the same verdict from fewer improvised commands.

| Skill | What it does |
|---|---|
| [`backlog-state`](backlog-state/) | The whole backlog as one gate-oriented table — every open issue, its PRs, the human gate it sits at, what it needs next. Read-only. |
| [`backlog-board`](backlog-board/) | The identical sweep and computation as `backlog-state`, painted as an HTML gate board published as an Artifact, optionally re-rendering on every turn or state change. Read-only. |
| [`backlog-loop`](backlog-loop/) | Drives a repository's backlog to zero open actionable issues, in severity order, as gate-ready PRs. **At a declared severity-batch boundary it also cuts the release tag and opens each affected consumer's repin PR** (§ 8) — it never publishes a release, and never merges `main`. |
| [`backlog-synthesis`](backlog-synthesis/) | Reconciles a long backlog into a short one — groups issues sharing a clause, machinery file or root cause, then files one consolidated issue, attaches the originals as sub-issues **and closes them with a reference**. Every write happens behind a plan the maintainer approves first. |
| [`bankai-handbooks`](bankai-handbooks/) | Resolves which handbooks govern a repo and scenario, and which rule-ID prefix each one owns, so a citation is never improvised. |
| [`bankai-quality`](bankai-quality/) | Resolves the adversarial-test tooling, performance-measurement tooling and `QA-{n}` rules for a repo's scenario — what Phinks and Uvogin read before they measure anything. |
| [`black-voice`](black-voice/) | **Post-merge UI validation, on the maintainer's call only.** Resolves the merged PR, the issues it closed and their acceptance criteria, raises **Shalnark** once to drive every criterion through ephemeral automated UI tests in the repository's pinned tooling, and publishes pass / fail / not-testable per criterion as a Rikugan page. Never automatic, never called from a composite; it fixes nothing and files a failure only on the maintainer's pick. |
| [`build`](build/) | Takes one issue from wherever it sits to a delivery PR standing ready at its human gate. Never applies a mode label. |
| [`file`](file/) | Files one well-formed, correctly-labelled, non-duplicate issue — reconciled against the open backlog first, on one explicit confirmation. |
| [`futon`](futon/) | Takes one whole severity band from open issues to PRs with an actor behind them, then **gates** the terminal step you typed (`then tag`, `then tag+fanout`): it holds the cut until no PR this run authored is short of Ready, and hands the cut itself to [`getsuga`](getsuga/). It cuts no tag and runs no fan-out of its own. |
| [`getsuga`](getsuga/) | **Cuts** a release tag locally, end to end — preconditions, one folded **release-proposal** PR the maintainer merges at **G4** in a canon repository (**G2** in a consumer one), the **post-merge** tag, the `CON-22` fan-out and the consumers' repin PRs. The release unit it folds in is [`susanoo`](susanoo/)'s; publication is [`mugetsu`](mugetsu/)'s, at **G3**. Prepares a release; never publishes one. |
| [`izanagi`](izanagi/) | Repeats a task that **acts** until a condition holds, under a **mandatory** iteration cap — an invocation without `up to <N>` is refused. |
| [`izanami`](izanami/) | Repeats a **read-only** task until a condition holds. It looks, reports and stops; it never writes. |
| [`jujisho`](jujisho/) | Splits a mixed working copy into up to two stacked branches and PRs, by axis, proving the union of the splits equals the original diff. |
| [`pr-state`](pr-state/) | Reports one PR's readiness as the deterministic gate's verdict, quoted verbatim, with the conjunct-by-conjunct reason. Read-only. |
| [`senkei`](senkei/) | Inventories a consuming product repo's own backlog — epics, integration branches, open PRs — classifies every effort and states a Ready/not-Ready call for each PR. **Not read-only**: it re-runs a dead reviewer job (`nen run rerun-failed`) and fires `bankai:wake/iterate`, alone, on a stalled PR. It applies no routing or stage label without per-action confirmation, and never merges. |
| [`sharingan`](sharingan/) | Drives one open PR to readiness at its gate and stops there — first blocking condition, thread stewardship, wakes. Never merges, never votes. **Renamed from `drive` at `v0.5.0`** — same behaviour, and `hatsu:drive` no longer resolves. |
| [`tenkai`](tenkai/) | **Consumer adoption.** Turns another repository into a Hatsu consumer through [`scripts/tenkai_adopt.sh`](../../scripts/tenkai_adopt.sh): the declarations it is missing, the `readiness` workflow, the permission pack and the surface mirrors, each staged as its own PR at that repository's own gate. Idempotent, and read-only until the maintainer says apply. |
| [`tensho`](tensho/) | Turns a dirty working copy into one PR, reviewing every uncommitted file before staging it, then hands that PR to [`sharingan`](sharingan/)'s engine to reach its gate. |

---

## The canon-authoring skill

One skill is neither ported nor a phase of `ren`: it was authored at `v0.43.0` for this plugin's own
canon (zheref/hatsu#93), and it runs on the maintainer's call, outside the turn loop.

| Skill | What it does |
|---|---|
| [`great-hiker`](great-hiker/) | **Canon authoring for every surface.** Authors canon prose and machinery under `claude/` and `contracts/`, runs `nen surface mirror generate` for every surface with hooks, allowlists, rules files and model config, checks the mirrors and the installed copies, and opens one PR at G4 with a per-surface delta table. `evolve [<surface>]` diffs each surface guide against its cited official docs and files one Netero-shaped issue per drifted surface. Never edits `surfaces/` by hand, never claims a capability without the fetched line, never merges. |

---

## The way of working

The nineteen ported skills and `great-hiker` each answer a request. The twenty-three below are the **loop that carries every request** —
warm up, build, commit, launch, report, ring; pull, test, push — and the phases the maintainer calls by
hand. [`../../docs/WORKFLOW.md`](../../docs/WORKFLOW.md) is the authority on all of it: the two configuration
files ([`nen/contract.json`](../../nen/contract.json) → `project`, what nen **executes**;
[`nen/workflow.json`](../../nen/workflow.json), what the workflow **decides**), every key of the second one,
the coverage ladder, the human-called phases, the five G5 stops, and the two harness hooks in
[`../../hooks/`](../../hooks/).

Two rules govern every one of them. **Five phases are the maintainer's to call and no agent ever prompts for
them** — `aka`, `mukai`, the merge, `kagutsuchi`, `mugetsu`. And **only a genuine G5 stops the loop**: red
required tests, coverage under the ladder's minimum, a semantic conflict, an unsettled adversarial finding, a
`sharingan` escalation. A stop is `nen stop`'s banner plus the question asked through the surface's own
native option picker.

### The twenty-four workflow skills — twenty atomic, four composite

**Atomic** — one phase each. The first nine shipped at `v0.4.0`; the five after them at `v0.5.0`; the last
three at `v0.6.0`; `byakugan` at `v0.24.0`; `third-hand` at `v0.27.0` (phase split `v0.28.0`); `amenotejikara` at `v0.45.0`:

| Skill | What it does |
|---|---|
| [`breath`](breath/) | **Warm-up, once per effort.** A new effort always fetches, fast-forwards, and cuts `{model}/{persona}/{descriptor}` from the fresh trunk — even from a clean unrelated feature branch. An existing branch is reused only for an explicit continuation. Then prove the declared iteration checks **on that fresh tip** — a base that does not build is a **G5** stop taken before any of the change is authored. Asks on a dirty tree, and never discards a tree it has not inspected. |
| [`rasengan`](rasengan/) | **The change itself — the authoring phase.** Writes the change and focused tests, runs the shared inexpensive `iteration.checks`, and may execute an explicit declared scoped-test lane for feedback. It runs no full regression or coverage and commits nothing. |
| [`kokusen`](kokusen/) | **Verify, focused-test, then commit — locally, automatically.** Runs the shared `iteration.checks` and, for changed executable behavior, a declared scoped `test` lane. A missing scoped route stops before checkpoint; a prose-only change reports not applicable. It never runs full regression, coverage, or push. |
| [`amaterasu`](amaterasu/) | **Launch, every turn.** Builds the configured target and starts it **from the core working directory, never a worktree**; the dry-run argv goes into the report and the chat. A disconnected device is reported by name. Parallel subagent efforts launch nothing. |
| [`tsukuyomi`](tsukuyomi/) | **Focused tests.** The scoped lane for the behavior this turn changed — rasengan may run it for feedback, kokusen must run it at every local checkpoint. It never walks `tests.required` and never measures coverage. |
| [`spiritual-message`](spiritual-message/) | **The rich report** — `turn`, `turn-fast` and `landing` — rendered from `templates/spiritual-message.html`, **never markdown**: the desk, this last turn, then session-wide accomplished, challenges, not delivered, the architecture delta as a graph, screenshots, how to launch, decisions. **The dated `final` report is not this skill's**: it is a one-effort Rikugan rendered through [`backlog-board`](backlog-board/) § 3 to `<reports.dir>/<YYYY-MM-DD>-<effort>.html`, the only report written to `Reports/`. |
| [`jutaisho`](jutaisho/) | **The bell.** Rings `workflow.json → notifications` and drops the marker that [`../../hooks/stop-bell.sh`](../../hooks/stop-bell.sh) reads; where no hook is installed it rings the notifier itself **and says that it did**. |
| [`ao`](ao/) | **Pull from the base.** Fetch, then rebase if the branch is unpushed and merge if it is not; mechanical conflicts are resolved, a **semantic** one is a **G5** with both sides shown. It never pushes. |
| [`aka`](aka/) | **Push — human-called.** Lint → squash only unpushed commits → `ao` → re-lint if catch-up changed the tree → push. No project-wide tests. Regression and coverage wait for mukai. |
| [`hanten`](hanten/) | **Adversarial review, pre-PR.** Classifies the change set by scope and spawns **one reviewer subagent per applicable scope that still has cycle budget** — UI → Hisoka (max 2), security-bearing → **Feitan** (max 1), architecture/handbook → **Chrollo** (max 1), performance → Uvogin (max 3), release-adjacent → Phinks (max 1) — each titled `hanten · <persona> · <model alias>` and never on the frontier tier. Used counts live in `.nen/hanten/<branch-slug>.cycle.json` for the whole effort; remediation does not reset them. Findings come back in one fixed shape (**rule id · severity · evidence · proposed fix**); Kurapika fixes or pushes back with a reason, and an unsettled finding is a **G5**. Reviewers never edit non-test source, never vote, never block. |
| [`gyo`](gyo/) | **Linting, every Ren turn.** The named process for the declared `lint` verb. Breath proves it on the tip, rasengan may, kokusen must, aka before squash and after catch-up. It never measures coverage. |
| [`kotoamatsukami`](kotoamatsukami/) | **Impacted project-wide unit, UI and integration tests at mukai.** Selects and runs only the declared suites the change can affect, and handles UI evidence. Aka never calls it. Coverage is byakugan's. A skip needs a named proof. |
| [`byakugan`](byakugan/) | **Coverage capture and measurement at mukai.** Independently of those suites: writes the capture file, extracts, bands touched files, and raises the G5 under `coverage.minimum`. Never runs `test` or `ui-test`. |
| [`shibari`](shibari/) | **Composes and opens the PR** — why, how, what changes for the consumer, how to verify, a mermaid diagram where a flow changed, the evidence table, the checklist, `Closes #N`. **One** PR, opened from the last pushed commit; it writes the body back, requests the reviewers and hands the PR to [`en`](en/). It never labels a gate and never merges. |
| [`amenotejikara`](amenotejikara/) | **Swap which worktree core holds — human-called.** Lists every checkout (branch, dirt, distance from the base, last commit) through `nen wc worktrees`; brings one worktree's committed tree into the **core** checkout so Xcode and `amaterasu` build and debug exactly that — detached by default, the branch itself with `--take` — and `return`s core home with its uncommitted work restored. Core's work is parked in a pinned commit, **never stashed**; ignored files are never touched; nothing is discarded, committed or pushed. |
| [`jujutsu`](jujutsu/) | **Device pairing.** Walks the maintainer through pairing a physical device — iOS: trust, Developer Mode, `devicectl list devices`; Android: USB debugging, the RSA prompt, `adb devices` — and registers it as a launch target **through a repository PR**. It writes the declaration and nothing else. |
| [`susanoo`](susanoo/) | **Archive and packaging.** Runs the lane's declared `archive` through `nen shu archive` and produces the distributable **locally**: it uploads nothing, and nen never synthesises signing material. A seat (exit `4`) is quoted with the declaration's own reason, never routed around. Where the repository declares `tags.identity`, it also NAMES the identity the tag `kagutsuchi` cuts on a successful upload will carry — it cuts none itself. This is the release unit [`getsuga`](getsuga/) folds into the release PR and the two phases below send. |
| [`kagutsuchi`](kagutsuchi/) | **Non-production deploy or upload — human-called, per target.** The plan is printed always (`nen shu deploy --target <name>`, no `--run`), every precondition and `requiresEnv` variable asserted rather than read; `--run` acts **only** on the maintainer's own call naming the target, and **never from a composite**. `--target` is required with no default, even where exactly one destination is declared. The call is the stop. |
| [`mugetsu`](mugetsu/) | **Publication — human-called, per target, G3.** Only on the maintainer's recorded per-target go, with `nen release preflight` green and the tag already cut: `nen shu release`, or `nen shu deploy --target production --run`. **One target per call**, and never reached from [`getsuga`](getsuga/), [`futon`](futon/) or [`en`](en/). It is the one phase that reaches other people's users. |
| [`third-hand`](third-hand/) | **Session harvest — Netero's last look, after En.** A separate phase that starts once En has completed. Raise Netero in parallel, fold this sitting's process friction into **0–3** issues, file only what the maintainer picks through the surface picker, then the sitting is over. Never merges, never implements. Not a step of En. |

**Composite** — an order, not a new capability. `ren` shipped at `v0.4.0`; the three after it at `v0.5.0`:

| Skill | Order inside |
|---|---|
| [`ren`](ren/) | **The per-request loop.** `breath`¹ (first turn only, and it proves the base) → `rasengan`² (author the change) → `kokusen`³ (verify the tree, then commit) → `amaterasu`⁴ → `spiritual-message`⁵ → `jutaisho`⁶. It loops until the maintainer calls the next phase, and **it never pushes**. |
| [`murasaki`](murasaki/) | **Pull + update push.** `ao` → shared iteration checks → if catch-up changed the tree, return to the caller so kotoamatsukami can refresh tests and byakugan can recapture coverage → push only an already-published branch. Never squashes, first-publishes, or runs tests or coverage itself. |
| [`mukai`](mukai/) | **The review-and-publication phase — human-called.** `murasaki`¹ → `hanten`² → kokusen checkpoint³ → `kotoamatsukami` impacted tests⁴ → `byakugan` coverage⁵ → final unchanged catch-up and update push⁶ → existing UI evidence⁷ → `shibari` PR⁸ → landing report⁹ → start `en` and end Mukai. The same user turn continues under En through current-head readiness. |
| [`en`](en/) | **The readiness watch, `izanagi`-capped** by `nen/workflow.json` → `monitor`. [`spiritual-message`](spiritual-message/)¹ (landing) → [`sharingan`](sharingan/)² → `murasaki`³ when the branch is behind → `sharingan`⁴ → observe⁵ required CI/current-head review → [`jutaisho`](jutaisho/)⁶ at Ready → the dated final report (a one-effort Rikugan, [`backlog-board`](backlog-board/) § 3) and stop at the human gate. **A run with no acting cap does not run; quiet observations spend none**. A long hold may be handed to **Illumi**, read-only. When En has completed, the next phase is [`third-hand`](third-hand/). |

> **The release side closed at `v0.6.0`.** [`susanoo`](susanoo/), [`kagutsuchi`](kagutsuchi/) and
> [`mugetsu`](mugetsu/) are the last three rows of the atomic table above, so **every phase a skill can
> carry now has one** — and of the five the maintainer calls (`aka`, `mukai`, **the merge**,
> `kagutsuchi`, `mugetsu`), **four are skill-backed**. The fifth is the merge, and it has no file because
> there is nothing for one to describe: **G2** (`CON-5`) is an action no agent in this plane performs.
> The rule that carried the other four while they were only names is unchanged and was never contingent
> on the file: **name the phase and stop there anyway** — the boundary is the governance.

---

## The two roster-machinery residents

Neither is one of the forty-four. They landed with the skeleton because the plugin does not function
without them, and they are recorded here rather than folded silently into the count.

| Resident | Why it exists |
|---|---|
| [`hatsu-warmup/SKILL.md`](hatsu-warmup/SKILL.md) | The **D10 dependency contract executing**. It probes `nen --version` against the range declared in [`../../nen/contract.json`](../../nen/contract.json) — kept at nen's own location and in nen's own shape, so `nen schema check --repo <this checkout>` validates the `dependency` block it reads (at `0.x`, `minimum: "0.3"` means `>=0.3.0 <0.4.0` — a different minor is out of range in *both* directions); when nen is **absent** it runs nen's own checksum-verified bootstrap directly, and when nen is **present but out of range** it re-pins through `nen bootstrap --script`. It halts with the exact command **only** if that bootstrap itself fails. It must run before any other Nen-owned work, including every skill above. |
| [`../commands/kurapika.md`](../commands/kurapika.md) | The `/kurapika` summon surface both manifests advertise. An agent definition alone creates no invocable command, so without this the manifests would describe a surface that does not exist. |

---

## Surfaces — this directory is the one authored copy

**The count above does not change on any surface.** At `v0.7.0` the same skills (and the two
residents) are also *generated* into Codex and Cursor layouts under [`../../surfaces/`](../../surfaces/) —
`surfaces/codex/<name>/SKILL.md` and `surfaces/cursor/<name>/SKILL.md`, one apiece, plus each surface's own
persona shape. **Nothing is added, renamed or withheld per surface**; only the frontmatter is reduced to the
keys each surface documents, and the invocation is respelled.

| | invocation | skills read from |
|---|---|---|
| Claude Code | `hatsu:<name>` | this directory, through the plugin |
| Codex | `$<name>` | `<repo>/.agents/skills/<name>/` |
| Cursor | `/<name>` | `<repo>/.cursor/skills/<name>/` |

**Edit here; never edit a mirror.** `nen surface mirror generate` rewrites `surfaces/` from this directory
and `../agents/`, every generated file carries a `GENERATED by nen surface mirror` marker, and
[`../../scripts/surface_mirror_check.sh`](../../scripts/surface_mirror_check.sh) reports a hand-edited mirror
by name. The regeneration belongs in the **same commit** as the `SKILL.md` change that caused it.
[`../../docs/SURFACES.md`](../../docs/SURFACES.md) is the authority.

---

## A change here needs a version bump

Everything in this directory is plugin-shipped, and Claude Code keys its plugin cache on
`.claude-plugin/plugin.json`'s `version`. Edit a `SKILL.md` without bumping that field and the edit reaches
no installed copy — silently, with no error anywhere.
[`scripts/plugin_bump_check.sh`](../../scripts/plugin_bump_check.sh), wired as the `plugin-bump-check`
workflow, fails a PR that tries — **advisorily**, until the maintainer requires the check by branch
protection or a ruleset (see the README's *Contributing* section).

[1]: https://github.com/zheref/hatsu/issues/1
[2]: https://github.com/zheref/hatsu/issues/2
