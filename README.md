# Hatsu

**A Claude Code plugin for repository-centric agentic delivery, run from your own terminal on your own
credentials.**

One lead persona — **Kurapika**, who names which of six declared work-modes he is holding before he acts —
plus a small roster of focused independents, and **thirty-eight skills** that take a backlog, a pull request or
a release from where it is to the human gate where a person decides. **Every deterministic step that has a
verb is a verb** from the [**Nen**](https://github.com/zheref/nen) CLI: Nen detects, computes, formats and
verifies; the skill supplies only the judgment a binary cannot. Where no verb exists yet, the residue is
**named per skill** in [`docs/ab/`](docs/ab/) rather than quietly improvised.

No GitHub App. No bot identity. Nothing here merges `main`, publishes a release, or casts a review vote.

> **`v0.8.0`.** Hatsu is the local plane of the Akatsuki system, and it succeeds the local plane of a
> predecessor system — the frozen reference implementation — which it also **serves live today**: the
> original seventeen skills were ported name-for-name and proven against that system's real backlog before
> `v0.1.0` was cut. The evidence is in [`docs/ab/`](docs/ab/), one file per skill — dated records of the port
> against nen `0.1.0`. `v0.3.0` reconciled every skill and persona with nen **`v0.3.0`**, and `v0.7.1` repins to nen **`v0.5.0`**. **`v0.4.0` adds the
> way of working**: ten skills that make the local loop itself explicit, two configuration files that hold
> every parameter of it ([`nen/contract.json`](nen/contract.json) → `project` and
> [`nen/workflow.json`](nen/workflow.json)), and two harness hooks — a stop bell and a refusal to commit on
> the trunk. **`v0.5.0` adds the PR side**: eight more skills — `mukai`, `murasaki`, `hanten`, `gyo`,
> `kotoamatsukami`, `shibari`, `en` and `jujutsu` — the rename of `drive` to **`sharingan`**, and the three
> agent definitions that side needs: **Feitan**, **Chrollo** and **Illumi**. **`v0.6.0` closes the release
> side**: `susanoo` (archive and packaging), `kagutsuchi` (non-production upload, per target) and `mugetsu`
> (publication, per target, **G3**) — so four of the five phases only you may call have a skill; the
> fifth is **the merge**, which has none because no agent performs it.
> **`v0.7.0` adds no skill and adds two surfaces**: the same thirty-eight skills and eight personas,
> generated into Codex and Cursor layouts under [`surfaces/`](surfaces/) — see [*Surfaces*](#surfaces).
> **`v0.8.0` adds no skill either, and splits provenance in two**: `Hatsu-Agent:` is what a local session
> writes, `Akatsuki-Agent:` is the autonomous CI plane's key and nothing here writes it — the maintainer's
> ruling of 2026-09-10. [`docs/WORKFLOW.md`](docs/WORKFLOW.md) is the authority on all of it.

---

## Requirements

| | |
|---|---|
| [Claude Code](https://claude.com/claude-code) | the host. The `claude plugin` subcommands below are its own. |
| [`nen`](https://github.com/zheref/nen) **`>= 0.6`** | a **hard** dependency — see [The Nen contract](#the-nen-contract-d10). You do **not** need to install it yourself; the warm-up does it, checksum-verified. |
| `git` + [`gh`](https://cli.github.com), authenticated | the skills read and write GitHub as **you**. |

**On the installed plugin path**, nothing here needs `jq`, `yq` or Python: one binary, plus `git` and `gh`.
(The repository's own CI is a separate matter — `scripts/plugin_bump_check.sh` uses `jq`, but nothing an
installed copy runs does.)

## Install

```sh
claude plugin marketplace add zheref/hatsu
claude plugin install hatsu@hatsu
```

Then, in Claude Code:

```
/kurapika
```

To install from a local checkout instead — for development, or to run a branch:

```sh
git clone https://github.com/zheref/hatsu.git
claude plugin marketplace add ./hatsu
claude plugin install hatsu@hatsu
```

Confirm what landed:

```sh
claude plugin list                  # hatsu@hatsu — Version: 0.8.0
claude plugin details hatsu@hatsu   # the full component inventory
```

---

## The Nen contract (D10)

Hatsu's skills do not improvise shell. Every deterministic step is a `nen` verb, and the dependency on that
binary is **hard**, **version-ranged**, and **fail-closed with auto-install**.

**[`nen/contract.json`](nen/contract.json) is the single source of truth.** Every version, ref, URL and
command echoed anywhere else — this README included — is a convenience copy of a value that lives there.
**Where a copy disagrees with the contract, the contract wins and the copy is the bug.** The
[`hatsu-warmup`](claude/skills/hatsu-warmup/) skill executes it at the start of every session, before any
other Nen-owned work.

The file sits where nen itself looks for a repository's dependency declaration — `nen/contract.json`, in
nen's own shape (`dependency.version_probe` as an argv array, `dependency.bootstrap` nested inside
`dependency`) — so that nen validates it rather than merely tolerating it:

```sh
nen schema check --repo <this checkout>
#   ok    nen/contract.json  dependency (nen >= 0.6, pinned v0.6.0), project (1 lane: plugin; 10 verbs; 1 toolchain entry)
#   ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}' off 'main', checks: lint
```

(Four taxonomy rows print above those two — three `FAIL` (`nen/labels.json`, `nen/repos.json`,
`nen/colors.yml`) and one `warn` (`nen/gates.json`) — and the command exits `1`: Hatsu ships no taxonomy of
its own, `schema check` requires the three of a repository that carries one, and only warns on the fourth,
which `pr ready` can take by `--gates` instead. The two `ok` rows are the ones this repository owns. **There
is no `schemas/` fallback at this pin** — it was removed in nen `v0.5.0`, so `nen/` is the only directory any
taxonomy-reading verb reads from, and a repository carrying a file only under `schemas/` is refused with the
migration named.) Every
Hatsu-authored key beside nen's own — the zero-major caveat, the two install paths, the halt template, the
no-`jq` rule — is preserved verbatim by nen's loader and read by nothing in nen. There is deliberately no
second copy: it was `nen.contract.json` at the root through `v0.2.0`.

Since `v0.4.0` the same file also carries a **`project`** block — Hatsu's own lane, written by hand because
`nen shu detect --repo .` answers *no lane detected* for a bash-and-markdown repository. `lint` is
`claude plugin validate . --strict`; every other verb of the family is an explicit `unsupported` **seat**
stating in this repository's words why it does not exist, because a seat is exit `4`, a stated fact, while an
omission is exit `2`, a broken declaration. Its policy half, [`nen/workflow.json`](nen/workflow.json), is
**validated by nen at the pinned `0.6.0`** — the second `ok` row above, with a malformed key reported as a
FAIL by pointer — and [`docs/WORKFLOW.md`](docs/WORKFLOW.md) documents both.

### The range

*Current pin, echoed for convenience:* **`nen >= 0.6`**.

**While nen's line is `0.x`, that means `>=0.6.0 <0.7.0` — exactly.** A different minor is out of range in
**both** directions: `0.7.0` fails it as surely as `0.5.0` does. At major version zero, SemVer 2.0.0 clause 4
makes the *minor* the breaking-change vehicle, so reading `>= 0.6` as "anything backward-compatible within
major 0" would fail **open** in precisely the range where compatibility is least guaranteed — and the last
two releases are both the proof. `v0.5.0` **removed** something a consumer could rely on (the `schemas/`
fallback), the first release since `v0.1.0` to do so; `v0.6.0` changes three behaviours **in place**, with
no new flag to notice — `nen stage triage`'s exit code follows the `flagged` bucket alone, `nen wc
classify`'s `state.branch` becomes `string | null`, and `nen pr request-reviews` refuses at exit `2` a
login it can resolve to neither a bot nor a collaborator. The familiar
"compatible within a major" reading applies from **`1.0` onward**, and the contract is bumped to say so when
nen gets there.

### What happens when the range is not satisfied

Two cases, two paths, chosen by the probe (`nen --version`) and never by preference:

| Probe result | What the warm-up does |
|---|---|
| **nen absent** | Fetches nen's own published `bootstrap/nen.sh` at the pinned ref and runs it. This is the **sole** chicken-and-egg carve-out for shell anywhere on a Hatsu path: `nen bootstrap` is a `nen` subcommand, so it presupposes the binary that is missing. |
| **nen present, out of range** | Re-pins **through the verb**: `nen bootstrap --ref <pinned> --source zheref/nen --script <fetched script>`. `--script` is required — the verb *runs* the bootstrap rather than reimplementing it, so it needs the script on disk. |

Either way:

- **The bootstrap is checksum-verified.** It fetches nen's published `SHA256SUMS` and refuses bytes that do
  not verify. A checksum failure is **never** retried — retrying one is how a fail-closed guard becomes a
  fail-open one by attrition.
- **The script is fetched to a file and then run — never `curl … | bash`.** It reads `${BASH_SOURCE[0]}`
  under `set -u`, so a pipe kills it before it parses its own arguments.
- **The bootstrap is never vendored here.** Hatsu fetches nen's own script at the pinned ref, every time, so
  there is no second, unreviewed copy to drift from the manifest it verifies against.

### Halt — and what it is not

An absent or out-of-range `nen` is **not** a halt; it is an auto-install. The session halts **only when the
bootstrap itself fails**, and then it prints the exact command for you to run yourself, and stops.

**There is no LLM-improvised fallback for a Nen-owned operation, ever.** If nen is unavailable and the
bootstrap failed, the operation does not happen — not with raw `gh`, not with a shell equivalent, not from
memory. Reporting that is the correct outcome; substituting a hand-rolled equivalent is not.

---

## The roster

[`docs/ROSTER.md`](docs/ROSTER.md) is the authority on who exists and what standing they have; the agent
definitions in [`claude/agents/`](claude/agents/) are the authority on what each one does. Every agent
that writes a commit signs it `Hatsu-Agent: <name>`, with no run trailer — there is no CI run to name
(Illumi writes none: he is read-only). `Akatsuki-Agent: <name>` is the **other plane's** key, written by an
Akatsuki roster agent in CI and never by anyone here. **The git author is always the human.**

### Kurapika — the lead persona

Defined at **[`claude/agents/kurapika.md`](claude/agents/kurapika.md)**, summoned with **`/kurapika`**
([`claude/commands/kurapika.md`](claude/commands/kurapika.md)). He trained all six Nen types, and his
canonical trick is not power but **conditions**: a binding accepted in advance, stated out loud, paid in
full. The six types are his
work-modes, and **naming the mode in play is not decoration** — it tells you which authority he believes he
is holding, so you can catch him holding the wrong one *before* he acts on it.

| Mode | Lane | Where its work stops |
|---|---|---|
| **Enhancer** | **Product code** — edit, build and test locally, open the PR. Never merges, never votes, never self-reviews. | the merge gate — **yours** |
| **Conjurer** | **Canon & governance authoring** — constitutions, handbooks, schemas, agent definitions, taxonomies, thresholds. Conjured contracts *with conditions*: a clause states what it binds, what it costs, when it lapses, and what happens when it is broken. | the policy gate — **yours** |
| **Transmuter** | **Machinery** — Nen verbs and their tests, scaffolding, hooks, workflows, generators, plugin manifests, contract files. The standing transmutation is *improvised shell → deterministic verb*. | the policy gate — **yours** |
| **Manipulator** | **GitHub-side ops** — drives, wakes, labels, retargets, cascades, thread stewardship. | drives *to* a gate, crosses none |
| **Emitter** | **Release & fan-out** — the tag cut, changelog collation, preflight, the repin fan-out. | prepares a release; **never publishes one** |
| **Specialist** | **Product intake** — a raw thought elicited into a decision-complete brief, filed only on explicit confirmation. | epic approval — **yours** |

### The independents

**Seven, beside Kurapika: six ratified, and one — Illumi — *provisioned* rather than ratified and marked as
such.** Each has a discipline he delegates to rather than absorbing. The last three landed at `v0.5.0`, with
the PR side that needs them.

| Agent | Discipline | Status |
|---|---|---|
| **[Gon](claude/agents/gon.md)** | **Mission-scoped trusted delegate.** He always asks: what is the mission · which gates may I cross · under what conditions · when does the grant expire · where is it logged. | **Ratified as an agent. His delegation grammar is a DRAFT — so he crosses no gate.** See below. |
| **[Hisoka](claude/agents/hisoka.md)** | **UI/UX review and quality measurement, before a PR is ever posted** — the visual-evidence set, and the cheap objective things measured on your own machine: contrast ratios, target sizes, type scale, reduced-motion, artifact delta. | **Ratified** |
| **[Phinks](claude/agents/phinks.md)** | **Adversarial pre-release QA, under the proven-finding discipline** — every hypothesis class gets a recorded disposition, and nothing is filed that is not proven: a committed test failing 3/3 against the candidate, or a measured number with its method block. **From `v0.5.0` also a pre-PR trigger**, on a release-adjacent change set — a new way to be called, never a new authority, and the 3/3 floor still applies. | **Ratified** |
| **[Uvogin](claude/agents/uvogin.md)** | **Performance testing** — the fixed seven metrics on every pre-release run, with pinned tooling, regression thresholds, in-repo baselines, and a five-field method block per number. | **Ratified** |
| **[Feitan](claude/agents/feitan.md)** | **Security, and security only** — auth flows, secrets and credential handling, network and storage boundaries, data minimisation, the supply chain. He cites the inherited `SEC-{n}` rules **by id, resolved from the handbook set and never from memory**, and never runs an exploit against anything live. | **Ratified** 2026-09-09; definition at `v0.5.0` |
| **[Chrollo](claude/agents/chrollo.md)** | **Architecture and handbook conformance** — the `UZF-{n}` core, **exactly one** resolved stack handbook, and the repository's own architecture notes, each cited by id or by path. He is where a coverage-floor breach or a missing unit test is routed. **He reviews the handbooks; he never authors them.** | **Ratified** 2026-09-09; definition at `v0.5.0` |
| **[Illumi](claude/agents/illumi.md)** | **The long watch** — `en`'s step 6, when a landing watch must outlive the session that started it. Read-only through `nen watch until`, under the mandatory cap; he wakes Kurapika and acts on nothing. His frontmatter carries no `Edit`, `Write` or `MultiEdit`, and `Bash` — which every observation needs — is held to a **stated command allowlist** in his own definition rather than to a construction. | **PROVISIONED, not ratified** — `en`'s watch **only**; see below |

> #### ⚠️ Gon's delegation grammar is a DRAFT — until it is ratified, Gon crosses no gate
>
> The clause that would make a gate-crossing grant *valid* — **mission · gates · conditions · expiry ·
> logging** — is drafted here at [`docs/delegation-grammar-DRAFT.md`](docs/delegation-grammar-DRAFT.md) and
> **ratified elsewhere**: with the rewritten constitution at
> the migration tracker (private), a G4-class review (this is
> **OPEN-2** in [`docs/ROSTER.md`](docs/ROSTER.md)). **No grant can be given today, because there is
> no valid form for one to take.** Gon does the work, takes it to the gate, and stops there, exactly as
> every agent does by default. A delegate that acts on a draft has ratified the draft by itself.

### 🔶 OPEN — Killua, and the rest of Illumi's row

**These rows are open sub-decisions, and the ruling has been made only in part.** It is the maintainer's, not
this repository's. What follows is recorded **verbatim as proposals**. **Killua has no definition and may not
be acted as; Illumi's definition covers the ruled half only**, and refuses the three engines below by name.

| Agent | *Proposed* role | Status |
|---|---|---|
| **Illumi** — the unruled half | *Proposed:* the long-running loop **engines**: `backlog-loop`, `futon`, `senkei` | **Still OPEN.** The 2026-09-09 ruling provisioned him for `en`'s long watch **and nothing else** |
| **Killua** | *Proposed:* delegate-run watchdog paired with Gon — a Gon mission never runs unwatched — plus fast single-object interventions | **OPEN** — no definition, and none implied by Illumi's |

**Killua's row touches Gon's grammar and must not be collapsed into it.** If ratification adopts the pairing,
`watched` becomes a *mandatory* condition on every Gon grant; if it does not, `watched` stays optional or is
dropped. **Neither is assumed.**

When work arrives that plainly wants one of them: do it in the fitting Kurapika mode and **name the gap**.
Naming it is what eventually gets the ruling made. Standing up the agent instead closes an open question with
nobody deciding it.

### 🔶 BENCH — the Genei Ryodan

*Extensible professional-profile agents, adopted as needed* — a list of shapes the roster can grow into.
**Two were activated on 2026-09-09 — Chrollo and Feitan — and their definitions landed at `v0.5.0`, so their
rows now live under *The independents* above.** The five below are bench only, with no activation implied.

| Bench member | Profile | Standing |
|---|---|---|
| **Machi** | Integration surgery | Bench |
| **Shalnark** | Automation | Bench |
| **Kortopi** | Scaffolding | Bench |
| **Pakunoda** | Repo forensics | Bench |
| **Shizuku** | Cleanup | Bench |

**None of these five has a definition in `claude/agents/`, none is listed in `plugin.json`, and none may be
acted as** — activation is a decision about standing, not a licence to improvise the agent, which is why
Chrollo and Feitan could not be acted as between their activation and their definitions landing one release
later. Adopting another remains a deliberate act with its own decision.
[`docs/ROSTER.md`](docs/ROSTER.md) § *Rulings of 2026-09-09* is the authority.

---

## The skills

Thirty-eight, invoked as `hatsu:<name>`. Longer descriptions in
[`claude/skills/README.md`](claude/skills/README.md).

### The seventeen that answer a request

| Skill | |
|---|---|
| `backlog-state` | The whole backlog as one gate-oriented table — every open issue, its PRs, the gate it sits at, what it needs next. Read-only. |
| `backlog-board` | The identical sweep and computation, painted as an HTML gate board published as an Artifact. Read-only. |
| `backlog-loop` | Drives a repository's backlog to zero open actionable issues, in severity order, as gate-ready PRs. **Also cuts the release tag and opens the consumers' repin PRs at declared severity-batch boundaries** — never publishes a release. |
| `backlog-synthesis` | Groups open issues sharing a clause, a machinery file or a root cause into one consolidated issue, attaches the originals as sub-issues **and closes them** — behind a plan you approve first. |
| `bankai-handbooks` | Resolves which handbooks govern a repo and scenario, and which rule-ID prefix each one owns, so a citation is never improvised. |
| `bankai-quality` | Resolves the adversarial-test tooling, performance tooling and QA rules for a repo's scenario, before a release is cut. |
| `build` | Takes one issue from wherever it sits to a delivery PR standing ready at its human gate. |
| `file` | Files one well-formed, correctly-labelled, non-duplicate issue — reconciled against the open backlog first. |
| `futon` | Takes one whole severity band from open issues to PRs with an actor behind them, then **gates** the terminal step you typed — it clears its own gate and hands the cut to `getsuga`; it never cuts a tag itself. |
| `getsuga` | **Cuts** a release tag locally, end to end — preconditions, one folded **release-proposal** PR you merge, the **post-merge** tag, the fan-out and the consumers' repin PRs. The release unit is `susanoo`'s; publication is `mugetsu`'s. Never publishes a release. |
| `izanagi` | Repeats a task that **acts** until a condition holds, under a **mandatory** iteration cap. No cap, no run. |
| `izanami` | Repeats a **read-only** task until a condition holds. It looks, reports, and stops. |
| `jujisho` | Splits a mixed working copy into up to two stacked branches and PRs, by axis, proving nothing was left behind. |
| `pr-state` | Reports one PR's readiness as the deterministic gate's verdict, quoted, with the conjunct that failed. Read-only. |
| `senkei` | Inventories a consuming product repo's own backlog and states a Ready/not-Ready call for every open PR. **It writes as well as reads**: it re-runs failed checks (`nen run rerun-failed`) and fires `bankai:wake/iterate` on a stalled PR. Never merges. |
| `sharingan` | Drives one open PR to readiness at its gate and stops there — first blocking condition, threads, wakes. **Renamed from `drive` at `v0.5.0`**; the behaviour is unchanged and `hatsu:drive` no longer resolves. |
| `tensho` | Turns a dirty working copy into one PR, reviewing every file before staging it, then hands that PR to `sharingan`'s engine to reach its gate. |

### The ten that *are* the way of working — new in `v0.4.0`

Nine atomic, one composite. [`docs/WORKFLOW.md`](docs/WORKFLOW.md) is the authority on the loop, the two
configuration files behind it, and the phases only you can call.

| Skill | | |
|---|---|---|
| `breath` | **atomic** | **Warm-up, once per effort.** On the base branch and clean: fetch, fast-forward, cut `{model}/{persona}/{descriptor}` from the fresh trunk, prove the declared iteration checks. Asks only on a dirty tree; never discards a tree it has not inspected. |
| `rasengan` | **atomic** | **Build, before every commit.** Runs every declared iteration check through the lane's own verb. A red build is fixed, never committed over; an unsupported seat is quoted, never routed around. |
| `kokusen` | **atomic** | **The automatic local commit.** Build green, then staging triage with an **ask on every flagged file** and never a secret, then the formatted message. Commits, and only commits. |
| `amaterasu` | **atomic** | **Launch, every turn.** Builds the configured target and starts it **from your working directory, never a worktree**. A disconnected device is reported by name. |
| `tsukuyomi` | **atomic** | **Tests health.** Runs the required suites, parses the results, fixes and re-runs — or stops at **G5**. It never patches a test to make it pass. |
| `rikugan` | **atomic** | **The rich report** — turn, landing, final — rendered from an HTML template, never markdown. Only the final one is written to the git-ignored `Reports/`. |
| `jutaisho` | **atomic** | **The bell.** Rings the notification ladder you declared, and drops the marker the `Stop` hook reads. |
| `ao` | **atomic** | **Pull from the base.** Rebase if unpushed, merge if not; mechanical conflicts resolved, a **semantic** one raised as a **G5** with both sides shown. Never pushes. |
| `aka` | **atomic** | **Push — yours to call.** Tests → squash the unpushed commits → `ao` → push. No PR, and no agent ever prompts for it. |
| `ren` | **composite** | **The per-request loop**: `breath` → `rasengan` → `kokusen` → `amaterasu` → `rikugan` → `jutaisho`, looping until you call the next phase. **It never pushes.** |

### The eight that are the PR side — new in `v0.5.0`

Five atomic, three composite. `mukai` is yours to call; everything else here is something it runs.
[`docs/WORKFLOW.md`](docs/WORKFLOW.md) § 5 is the authority.

| Skill | | |
|---|---|---|
| `hanten` | **atomic** | **Adversarial review, pre-PR.** Classifies the change set by scope and spawns **one reviewer per scope** — UI → Hisoka, security-bearing → **Feitan**, architecture/handbook → **Chrollo**, performance → Uvogin, release-adjacent → Phinks — each titled `hanten · <persona> · <model alias>`, never on the frontier tier. One fixed finding shape: **rule id · severity · evidence · proposed fix**. Kurapika fixes or pushes back with a reason; an unsettled finding is a **G5**. |
| `gyo` | **atomic** | **The coverage bar.** Touched-file line coverage against the 80/85/90 ladder, reported band by band; adds tests until every touched file clears the `minimum`, and raises a **G5** when one honestly cannot. **It never lowers the bar.** |
| `kotoamatsukami` | **atomic** | **End-to-end / UI tests.** Runs the declared UI suite where a repository declares one; the re-recorded snapshots are what feeds the evidence table. An unsupported seat is quoted, never routed around. |
| `shibari` | **atomic** | **Composes and opens the PR** — why, how, what changes for the consumer, how to verify, a diagram where a flow changed, the evidence table, the checklist, `Closes #N`. One PR, from the last pushed commit; requests reviewers and hands it to `en`. Never labels a gate, never merges. |
| `jujutsu` | **atomic** | **Device pairing.** Walks you through trusting and registering a physical device — iOS: Developer Mode and `devicectl`; Android: USB debugging and `adb` — and lands it as a launch target **through a PR**. It writes the declaration and nothing else. |
| `murasaki` | **composite** | **Pull + push.** `ao` → `rasengan` + `tsukuyomi` → push, **only if the branch is already published**. Never squashes, never force-pushes. |
| `mukai` | **composite** | **The review-and-PR phase — yours to call.** `murasaki` → `hanten` → tests + UI tests → `gyo` → evidence → `shibari`, which opens the PR and starts `en`. **Four of the five G5 stops live inside it.** |
| `en` | **composite** | **The landing watch, capped.** Landing report → `sharingan` → `murasaki` when behind → `sharingan` → `jutaisho` at Ready → watch until merged → the final report. **A watch with no cap does not run**; where one must outlive the session, the watch itself is handed to **Illumi**, read-only. |

### The three that close the release side — new in `v0.6.0`

All three atomic. Two of them are **yours to call, per target** — that is what makes them the last two rows
of the five. [`docs/WORKFLOW.md`](docs/WORKFLOW.md) § 4 is the authority.

| Skill | | |
|---|---|---|
| `susanoo` | **atomic** | **Archive and packaging.** Runs the lane's declared `archive` and produces the distributable **locally**. It uploads nothing and signs nothing — Nen never synthesises signing material — and an unsupported seat is quoted, never routed around. This is the release unit `getsuga` folds into the release PR and the two phases below send. |
| `kagutsuchi` | **atomic** | **Non-production upload — yours to call, per target.** The plan is always printed (`nen shu deploy --target <name>`, no `--run`); `--run` acts only on your own call **naming the target**, and never from a composite. `--target` is required with no default, even where exactly one destination is declared. |
| `mugetsu` | **atomic** | **Publication — yours to call, per target, G3.** Only on your recorded per-target go, with the preflight green and the tag already cut. **One target per call**, and never from `getsuga`, `futon` or `en`. This is the only phase that reaches other people's users. |

> **The boundary was always the governance, not the file.** These three were named phases before they were
> skills, and the loop stopped at them then exactly as it does now.

Plus [`hatsu-warmup`](claude/skills/hatsu-warmup/) — the Nen contract, executing — and the `/kurapika`
summon command.

### The way of working

`v0.4.0` writes the loop down. Two files hold every parameter of it, and the split matters:
[`nen/contract.json`](nen/contract.json) → `project` says what **nen executes** (lanes, per-verb argv,
preconditions, hosts, deploy targets, launch targets), and [`nen/workflow.json`](nen/workflow.json) says what
the **workflow decides** (branch shape, which declared verbs run per iteration, the coverage ladder, reports,
notifications, the commit-trailer allow-list, the model matrix). A wrong `project` block runs the wrong
command, loudly. A wrong `workflow.json` runs the right command at the wrong moment, silently. Keeping them
apart is what keeps the second class of mistake visible.

- **`ren` runs on every request** and never pushes. **Five phases are yours to call, and no agent ever
  prompts for them**: `aka` (push), `mukai` (review and PR), the **merge**, `kagutsuchi` (non-production
  upload) and `mugetsu` (publish, **G3**).
- **`mukai` is the whole PR side, in a fixed order** — `murasaki`, then `hanten`'s scope-routed review, then
  the tests and UI tests, then `gyo`'s coverage bar, then the evidence, then `shibari` opening one PR and
  starting `en`'s capped landing watch. Reviewers advise and never vote; **the merge stays yours**.
- **Only a genuine G5 interrupts you** — red required tests, touched-file coverage under the ladder's
  minimum, a *semantic* merge conflict, an unsettled adversarial finding, a stuck-PR escalation. Five, and
  nothing else. A stop is `nen stop`'s banner, the report link, and the question asked through your surface's
  own native option picker.
- **Branches read `{model}/{persona}/{descriptor}`**, and every subagent is titled
  `<skill> · <persona> · <model alias>` — what ran, as whom, on what. A subagent is **never** given the
  frontier model tier; that tier is where your own conversation lives.
- **[`hooks/hooks.json`](hooks/hooks.json)** ships two harness hooks, and they are discovered automatically at
  that path: a `Stop` bell that notifies and plays a sound when a gate stop is waiting, and a `PreToolUse`
  guard on `Bash` that refuses a `git commit` or `git push` while you are standing on the base branch. The
  guard **parses** the command — quoted spans masked, the line split into segments, git's global options
  walked past — so `echo 'git commit'` is not a write and `git -C <dir> commit` is judged in `<dir>`; it
  fails *closed* only where the branch it can see is not the branch the write would land on. Both are POSIX
  `sh`, use no `jq`, and otherwise no-op rather than block on anything they cannot read.
- **Two provenance trailers, one per plane — and no AI attribution trailer is ever recorded.**
  `Hatsu-Agent: <persona>` is what a local Hatsu session writes; `Akatsuki-Agent: <persona>` belongs to an
  Akatsuki roster agent on the autonomous CI plane, and **nothing here writes it**. Both are admitted by
  `nen/workflow.json` so that one `commit-msg` hook passes a commit from either plane — admitting a key is
  not licence to write it. Each names the system's own provenance, not a model claiming authorship, which
  is why there is no third. **Set `includeCoAuthoredBy: false`** in your
  Claude Code settings so the harness stops adding `Co-Authored-By:`. Enforcement is **three-layered, and at the
  pinned nen `0.6.0` the third layer is the binary's**: (a) `kokusen` and `aka` refuse to **write** such a
  trailer — agent-side, and it is what Hatsu itself carries; (b) the **target repository's `commit-msg`
  hook**, which `nen scaffold init` generates from `commits.allowedAttributionTrailers` (KroApple and
  kro-pwa carry one) — and from nen `v0.6.0` that hook's automated half is **derived from the repository's
  own policy**, requiring the one key `--agent-trailer` resolved to plus the optional `commits.runTrailer`,
  rather than a fixed pair; (c) **`nen commit format --repo`** and **`nen wc squash`** refusing the trailer
  outright at exit `2`, naming the file and the keys it admits. **Layer (b) stays target-dependent** — a
  repository that has not been scaffolded with the hook has (a) and (c) and no hook, and that is said
  plainly rather than promised as mechanical.

### What nen's `shu` family adds to the roster's own procedures

nen's **`shu`** family runs whatever a target repository *declares* in its `nen/contract.json` `project`
block — and nothing else — so `build`, `futon`, Gon, Hisoka, Phinks and Uvogin now start a piece of work with
`nen shu warmup` (`--dry-run` first, then bare: clean → fresh trunk → your branch → the declared build),
check a fresh host with `nen shu tools`, and verify with `nen shu build`/`test`/`lint`/`coverage`, each
with `--dry-run` printing the exact argv first. Kurapika's Transmuter mode stands a repository up with
`nen shu detect` → `nen scaffold init` (or `nen scaffold new` for a tree that does not exist yet) →
`nen schema check` → `nen shu tools`. `nen shu deploy --target <name>` prints a plan and sends nothing;
`--run` is the maintainer's word at **G3** and no skill here adds it. And `nen issue comment` replaces the
raw `gh issue comment` two skills used to carry as residue. A repository that is not one of nen's seven
stacks (this one included: `nen shu detect --repo .` answers *no lane detected*) gets the git half of the
warm-up and its own documented commands, said plainly — the full rules are in
[`claude/agents/kurapika.md`](claude/agents/kurapika.md) § *The `shu` verbs*.

### Evidence

Every skill ships with its own record in **[`docs/ab/`](docs/ab/)**. For each of the original seventeen that
is an A/B: the mechanics before the port, the mechanics after, and a live transcript against a real backlog
showing the same verdict reached with fewer improvised commands — `nen` invocations where the old transcript
had raw `gh`. For each of the ten added at `v0.4.0` it is the same evidence in the same shape, minus the
"before": the verbs exercised live with their exit codes, the residue that has no verb at the pinned nen, and
the findings the exercise filed against the binary. The surface was proven before this version was cut; it is
not an aspiration.

Those transcripts were recorded against repositories that are **not public**, so every private repository
name in this repository is replaced by a stable placeholder. The legend, and what is deliberately left
alone, are in [`docs/PUBLIC-REDACTION.md`](docs/PUBLIC-REDACTION.md).

### Rollback

**For you, as a public reader, rollback is simply uninstalling Hatsu** — `claude plugin uninstall
hatsu@hatsu`. Nothing server-side changed, so there is nothing else to undo.

Reinstalling the predecessor *bankai* plugin is the **maintainer's own** path back, not a public
one: its marketplace is private, and the links to it in this repository resolve only for someone
who already has access.

---

## Surfaces

**Hatsu is authored once and read on three agent surfaces.** On Claude Code it is a plugin and nothing else
is needed. On **Codex** and **Cursor** there is no plugin loader, so the same skills and personas are
*generated* into each surface's own layout and committed here, and the warm-up places them into the
repository you are standing in.

| | **Claude Code** | **Codex** | **Cursor** |
|---|---|---|---|
| you type | `hatsu:rasengan` | `$rasengan` | `/rasengan` |
| skills read from | the installed plugin | `.agents/skills/<name>/` | `.cursor/skills/<name>/` |
| personas read from | `claude/agents/` | `AGENTS.override.md`, as prose — an **untracked** file that *replaces* your `AGENTS.md` in the envelope, so the warm-up copies yours into it verbatim first and never writes the tracked one | `.cursor/agents/<persona>.md` |
| turn-end hook | **yes** | no — the bell rings in-session and says so | no — the same |
| in-session subagent | **yes** | no — a reviewer is a second `codex exec` run in its own worktree | yes |
| reviewer tier `deep` | `opus` | `sol` | `grok` — **Cursor-native only** |

Everything the warm-up puts in your repository is excluded through `.git/info/exclude` — **never your
`.gitignore`**, which is a tracked file of yours and not this plugin's to edit.

The mirrors under [`surfaces/codex/`](surfaces/codex/) and [`surfaces/cursor/`](surfaces/cursor/) are
**generated, not authored** — `nen surface mirror generate`, one command per surface, every file carrying a
`GENERATED by nen surface mirror` marker. Edit `claude/skills/<name>/SKILL.md`, regenerate, and commit both;
[`scripts/surface_mirror_check.sh`](scripts/surface_mirror_check.sh) fails a mirror that has drifted, and
says *skipped, not passed* on a `nen` too old to carry the verb.

**[`docs/SURFACES.md`](docs/SURFACES.md) is the authority** — what each surface reads, what is generated
versus authored, the regeneration command, the check, and the exact headless invocation for a validation
run on each.

---

## The gates

Hatsu drives work **to** a gate and stops there. **One gate is partially delegated, and exactly
one**: `CON-25` names four exhaustive carve-outs under which *release into build* — applying the
building stage label — may be crossed without a per-issue confirmation, inside a named run that
logs every application and lapses when the run ends. **Every other gate in the table below is
yours, without exception.** Clause ids are the inherited constitution's, kept stable across the
rewrite; [`docs/ROSTER.md`](docs/ROSTER.md) carries the same table.

| Gate | Clause | Delegable? |
|---|---|---|
| **G1 — Epic approval** — the human applies one delivery-mode label | `CON-4` | **Never** |
| **G1-M — Release into build** — applying the building stage label | `CON-25` | **The one delegated crossing** — only under `CON-25`'s four exhaustive, named carve-outs |
| **G2 — Merge to `main`** | `CON-5` | **Never** by these agents. No agent here merges `main`, or its own PR anywhere. |
| **G3 — Release go/no-go** | `CON-6` | **Never.** Preparing a release is allowed; publishing is not. |
| **G4 — Policy / spec change** | `CON-7` | **Never** |
| **G5 — Anything else human-only** | `CON-47` | **Never** — its definition *is* "the decision is yours" |

**No agent in this roster casts a `request_changes` review — for any reason, on any PR.** They run on your
credentials, so GitHub records the vote as **yours**, and casting one manufactures your governance vote on a
PR you have not read. The substitutes are a wake label (for findings an automated reviewer already delivered)
and a filed issue (for a substantive finding of the agent's own).

---

## Contributing

### A change to a shipped surface needs a version bump

Claude Code keys its plugin cache on `.claude-plugin/plugin.json`'s `version`. Change a plugin-shipped
surface without bumping that field and the change is real in the repository and **invisible on every machine
that already has the plugin installed** — no error, no warning, the fix ships to nobody.

[`scripts/plugin_bump_check.sh`](scripts/plugin_bump_check.sh), wired as the
[`plugin-bump-check`](.github/workflows/plugin-bump-check.yml) workflow, fails a PR that tries. The guarded
surface is `.claude-plugin/**`, `claude/**`, `nen/**`, `contracts/**`, `docs/ROSTER.md`,
`docs/delegation-grammar-DRAFT.md`, `hooks/**`, `templates/**`, `surfaces/**` and `.mcp.json` — everything an
installed copy reads, the generated Codex and Cursor mirrors included, because the warm-up reads those out of
`$CLAUDE_PLUGIN_ROOT` at run time. Bump
`version` (patch for wording, minor for behaviour or a new skill, major for a breaking interface change —
which the minor carries while Hatsu is on `0.x`, SemVer clause 4, the reading applied to nen's own line);
or, if a change provably cannot affect the shipped surface, write `no plugin bump: <reason>` in the PR
body. Recorded refuse/pass transcripts: [`docs/ab/plugin-bump-guard.md`](docs/ab/plugin-bump-guard.md).

**The check is required on `main`** by the repository ruleset *main: plugin-bump guard required*
(`enforcement: active`), so a failing `plugin-bump-check` blocks the merge. What that ruleset does not do
is protect `.github/**`: GitHub runs a same-repo PR against that PR's *own* workflow definition, so a PR may
still edit the workflow and be judged by the edited version. Closing that is a further repo-settings act —
a human gate, recommended rather than performed here: protect `.github/**` with a ruleset or `CODEOWNERS`.

### Validate locally

```sh
claude plugin validate . --strict
scripts/surface_mirror_check.sh   # the Codex/Cursor mirrors match their source
```

The second writes nothing and needs no credential. **At the pinned `v0.6.0` it runs the real check** —
`codex ok: 40`, `cursor ok: 47`, exit `0`. It exits `2` — saying so, rather than passing — when the `nen` on
your `PATH` has no `surface` verb, which at this pin means the binary is not the pinned one; see
[`docs/SURFACES.md`](docs/SURFACES.md) § 4.

---

## License

**MIT** — see [`LICENSE`](LICENSE).
