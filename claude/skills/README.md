# Hatsu skills

This directory is the plugin's skill surface (`plugin.json` → `"skills": "./claude/skills/"`). The summon
surface lives beside it at `claude/commands/` (`"commands": "./claude/commands/"`); both are listed together
under *Skills* by `claude plugin details`, which is why they are described together here.

**Thirty-eight skills at `v0.6.0`**: the **seventeen ported skills** ([zheref/hatsu#2][2]) that made the
surface complete at `v0.1.0` — one of them, `drive`, **renamed to [`sharingan`](sharingan/) at `v0.5.0`** —
the **ten workflow skills** added at `v0.4.0`, the **eight added at `v0.5.0`** that carry the PR side, the
**three added at `v0.6.0`** that close the release side, and the **two roster-machinery residents** that
arrived with the skeleton ([zheref/hatsu#1][1]) and are counted separately. Nothing here is reserved, and
nothing here is a placeholder.

Each skill is a directory holding a `SKILL.md` with `name` and `description` frontmatter. Invoke one as
`hatsu:<name>`.

> **Redaction notice — applies to every file under `claude/`.** These skills and agents quote real tool
> output in which the names, slugs and object ids of repositories that are not public are replaced by
> stable placeholders (`<reference-repo>`, `<product-repo-A>`, `RR-IS-#<n>`, `RA-PR-#<n>`, …). The
> transcripts are otherwise verbatim. The legend and the deliberate survivors are documented once, in
> [`docs/PUBLIC-REDACTION.md`](../../docs/PUBLIC-REDACTION.md).

---

## The seventeen ported skills

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
| [`build`](build/) | Takes one issue from wherever it sits to a delivery PR standing ready at its human gate. Never applies a mode label. |
| [`file`](file/) | Files one well-formed, correctly-labelled, non-duplicate issue — reconciled against the open backlog first, on one explicit confirmation. |
| [`futon`](futon/) | Takes one whole severity band from open issues to PRs with an actor behind them, then **gates** the terminal step you typed (`then tag`, `then tag+fanout`): it holds the cut until no PR this run authored is short of Ready, and hands the cut itself to [`getsuga`](getsuga/). It cuts no tag and runs no fan-out of its own. |
| [`getsuga`](getsuga/) | **Cuts** a release tag locally, end to end — preconditions, one folded **release-proposal** PR the maintainer merges at **G4**, the **post-merge** tag, the `CON-22` fan-out and the consumers' repin PRs. The release unit it folds in is [`susanoo`](susanoo/)'s; publication is [`mugetsu`](mugetsu/)'s, at **G3**. Prepares a release; never publishes one. |
| [`izanagi`](izanagi/) | Repeats a task that **acts** until a condition holds, under a **mandatory** iteration cap — an invocation without `up to <N>` is refused. |
| [`izanami`](izanami/) | Repeats a **read-only** task until a condition holds. It looks, reports and stops; it never writes. |
| [`jujisho`](jujisho/) | Splits a mixed working copy into up to two stacked branches and PRs, by axis, proving the union of the splits equals the original diff. |
| [`pr-state`](pr-state/) | Reports one PR's readiness as the deterministic gate's verdict, quoted verbatim, with the conjunct-by-conjunct reason. Read-only. |
| [`senkei`](senkei/) | Inventories a consuming product repo's own backlog — epics, integration branches, open PRs — classifies every effort and states a Ready/not-Ready call for each PR. **Not read-only**: it re-runs a dead reviewer job (`nen run rerun-failed`) and fires `bankai:wake/iterate`, alone, on a stalled PR. It applies no routing or stage label without per-action confirmation, and never merges. |
| [`sharingan`](sharingan/) | Drives one open PR to readiness at its gate and stops there — first blocking condition, thread stewardship, wakes. Never merges, never votes. **Renamed from `drive` at `v0.5.0`** — same behaviour, and `hatsu:drive` no longer resolves. |
| [`tensho`](tensho/) | Turns a dirty working copy into one PR, reviewing every uncommitted file before staging it, then hands that PR to [`sharingan`](sharingan/)'s engine to reach its gate. |

---

## The way of working

The seventeen above each answer a request. The twenty-one below are the **loop that carries every request** —
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

### The twenty-one workflow skills — seventeen atomic, four composite

**Atomic** — one phase each. The first nine shipped at `v0.4.0`; the five after them at `v0.5.0`; the last
three at `v0.6.0`:

| Skill | What it does |
|---|---|
| [`breath`](breath/) | **Warm-up, once per effort.** On the base branch and clean: fetch, fast-forward, cut `{model}/{persona}/{descriptor}` from the fresh trunk, prove the declared iteration checks. Asks only on a dirty tree, and never discards a tree it has not inspected. |
| [`rasengan`](rasengan/) | **Build, before every commit.** Runs every `workflow.json → iteration.checks` entry through the lane's declared verb, dry-run first on a repository it has not built. A red build is fixed, never committed over; a seat (exit `4`) is quoted, never routed around. |
| [`kokusen`](kokusen/) | **The automatic local commit.** `rasengan` green first, then `nen stage triage` with an **ask on every flagged file** and never a secret, then `nen commit format`. Commits, and only commits — it never pushes. |
| [`amaterasu`](amaterasu/) | **Launch, every turn.** Builds the configured target and starts it **from the core working directory, never a worktree**; the dry-run argv goes into the report and the chat. A disconnected device is reported by name. Parallel subagent efforts launch nothing. |
| [`tsukuyomi`](tsukuyomi/) | **Tests health.** Runs `workflow.json → tests.required`, parses the results, fixes and re-runs — or stops at **G5**. It never patches a test to make it pass. |
| [`rikugan`](rikugan/) | **The rich report** — turn, landing and final — rendered from `templates/rikugan.html`, **never markdown**: accomplished, challenges, not delivered, architecture delta, screenshots, how to launch, decisions. Only the final one is written to `Reports/`. |
| [`jutaisho`](jutaisho/) | **The bell.** Rings `workflow.json → notifications` and drops the marker that [`../../hooks/stop-bell.sh`](../../hooks/stop-bell.sh) reads; where no hook is installed it rings the notifier itself **and says that it did**. |
| [`ao`](ao/) | **Pull from the base.** Fetch, then rebase if the branch is unpushed and merge if it is not; mechanical conflicts are resolved, a **semantic** one is a **G5** with both sides shown. It never pushes. |
| [`aka`](aka/) | **Push — human-called.** `tsukuyomi` (G5 if red) → squash the unpushed commits → `ao` → push. No pull request, no AI attribution trailer, and **no agent ever prompts for it**. |
| [`hanten`](hanten/) | **Adversarial review, pre-PR.** Classifies the change set by scope and spawns **one reviewer subagent per scope** — UI → Hisoka, security-bearing → **Feitan**, architecture/handbook → **Chrollo**, performance → Uvogin, release-adjacent → Phinks — each titled `hanten · <persona> · <model alias>` and never on the frontier tier. Findings come back in one fixed shape (**rule id · severity · evidence · proposed fix**); Kurapika fixes or pushes back with a reason, and an unsettled finding is a **G5**. Reviewers never edit non-test source, never vote, never block. |
| [`gyo`](gyo/) | **The coverage bar.** Touched-file line coverage against the 80/85/90 ladder, reported band by band; it adds tests until every touched file clears the `minimum`, and raises a **G5** when one cannot honestly clear it. **It never lowers the bar.** |
| [`kotoamatsukami`](kotoamatsukami/) | **End-to-end / UI tests.** Runs the declared `ui-test` where a repository declares one; the re-recorded snapshots are what feeds the evidence table. An unsupported seat (exit `4`) is a fact, quoted — never routed around. |
| [`shibari`](shibari/) | **Composes and opens the PR** — why, how, what changes for the consumer, how to verify, a mermaid diagram where a flow changed, the evidence table, the checklist, `Closes #N`. **One** PR, opened from the last pushed commit; it writes the body back, requests the reviewers and hands the PR to [`en`](en/). It never labels a gate and never merges. |
| [`jujutsu`](jujutsu/) | **Device pairing.** Walks the maintainer through pairing a physical device — iOS: trust, Developer Mode, `devicectl list devices`; Android: USB debugging, the RSA prompt, `adb devices` — and registers it as a launch target **through a repository PR**. It writes the declaration and nothing else. |
| [`susanoo`](susanoo/) | **Archive and packaging.** Runs the lane's declared `archive` through `nen shu archive` and produces the distributable **locally**: it uploads nothing, and nen never synthesises signing material. A seat (exit `4`) is quoted with the declaration's own reason, never routed around. This is the release unit [`getsuga`](getsuga/) folds into the release PR and the two phases below send. |
| [`kagutsuchi`](kagutsuchi/) | **Non-production deploy or upload — human-called, per target.** The plan is printed always (`nen shu deploy --target <name>`, no `--run`), every precondition and `requiresEnv` variable asserted rather than read; `--run` acts **only** on the maintainer's own call naming the target, and **never from a composite**. `--target` is required with no default, even where exactly one destination is declared. The call is the stop. |
| [`mugetsu`](mugetsu/) | **Publication — human-called, per target, G3.** Only on the maintainer's recorded per-target go, with `nen release preflight` green and the tag already cut: `nen shu release`, or `nen shu deploy --target production --run`. **One target per call**, and never reached from [`getsuga`](getsuga/), [`futon`](futon/) or [`en`](en/). It is the one phase that reaches other people's users. |

**Composite** — an order, not a new capability. `ren` shipped at `v0.4.0`; the three after it at `v0.5.0`:

| Skill | Order inside |
|---|---|
| [`ren`](ren/) | **The per-request loop.** `breath`¹ (first turn only) → `rasengan`² → `kokusen`³ → `amaterasu`⁴ → `rikugan`⁵ → `jutaisho`⁶. It loops until the maintainer calls the next phase, and **it never pushes**. |
| [`murasaki`](murasaki/) | **Pull + push.** [`ao`](ao/)¹ → [`rasengan`](rasengan/)² + [`tsukuyomi`](tsukuyomi/)² → push³, and **only if the branch is already published**. It never squashes and never force-pushes. |
| [`mukai`](mukai/) | **The review-and-PR phase — human-called.** `murasaki`¹ → [`hanten`](hanten/)² → `tsukuyomi`³ + [`kotoamatsukami`](kotoamatsukami/)³ → [`gyo`](gyo/)⁴ → evidence⁵ → [`shibari`](shibari/)⁶, which opens the PR and **starts [`en`](en/)**. Four of the five G5 stops live inside it. |
| [`en`](en/) | **The landing watch, `izanagi`-capped** by `nen/workflow.json` → `monitor`. [`rikugan`](rikugan/)¹ (landing) → [`sharingan`](sharingan/)² → `murasaki`³ when the branch is behind → `sharingan`⁴ → [`jutaisho`](jutaisho/)⁵ at Ready → watch⁶ until merged → `rikugan`⁷ final. **A watch with no cap does not run**; where one must outlive the session, step 6 is handed to **Illumi**, read-only, who wakes Kurapika and acts on nothing. |

> **The release side closed at `v0.6.0`.** [`susanoo`](susanoo/), [`kagutsuchi`](kagutsuchi/) and
> [`mugetsu`](mugetsu/) are the last three rows of the atomic table above, so **every phase the lattice
> names now has a file** — and with `kagutsuchi` and `mugetsu` written down, the five phases the maintainer
> calls (`aka`, `mukai`, the merge, `kagutsuchi`, `mugetsu`) are complete as skills as well as as rules.
> The rule that carried them while they were only names is unchanged and was never contingent on the file:
> **name the phase and stop there anyway** — the boundary is the governance.

---

## The two roster-machinery residents

Neither is one of the thirty-eight. They landed with the skeleton because the plugin does not function
without them, and they are recorded here rather than folded silently into the count.

| Resident | Why it exists |
|---|---|
| [`hatsu-warmup/SKILL.md`](hatsu-warmup/SKILL.md) | The **D10 dependency contract executing**. It probes `nen --version` against the range declared in [`../../nen/contract.json`](../../nen/contract.json) — kept at nen's own location and in nen's own shape, so `nen schema check --repo <this checkout>` validates the `dependency` block it reads (at `0.x`, `minimum: "0.3"` means `>=0.3.0 <0.4.0` — a different minor is out of range in *both* directions); when nen is **absent** it runs nen's own checksum-verified bootstrap directly, and when nen is **present but out of range** it re-pins through `nen bootstrap --script`. It halts with the exact command **only** if that bootstrap itself fails. It must run before any other Nen-owned work, including every skill above. |
| [`../commands/kurapika.md`](../commands/kurapika.md) | The `/kurapika` summon surface both manifests advertise. An agent definition alone creates no invocable command, so without this the manifests would describe a surface that does not exist. |

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
