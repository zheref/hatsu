# Hatsu

**A Claude Code plugin for repository-centric agentic delivery, run from your own terminal on your own
credentials.**

One lead persona — **Kurapika**, who names which of six declared work-modes he is holding before he acts —
plus a small roster of focused independents, and **seventeen skills** that take a backlog, a pull request or
a release from where it is to the human gate where a person decides. Every deterministic step is a verb from
the [**Nen**](https://github.com/zheref/nen) CLI: Nen detects, computes, formats and verifies; the skill
supplies only the judgment a binary cannot.

No GitHub App. No bot identity. Nothing here merges `main`, publishes a release, or casts a review vote.

> **`v0.1.0`.** Hatsu is the local plane of the Akatsuki system, and it succeeds the local plane of a
> predecessor system called *bankai-core*, which it also **serves live today** — the seventeen skills were
> ported name-for-name and proven against that system's real backlog before this version was cut. The
> evidence is in [`docs/ab/`](docs/ab/), one file per skill.

---

## Requirements

| | |
|---|---|
| [Claude Code](https://claude.com/claude-code) | the host. The `claude plugin` subcommands below are its own. |
| [`nen`](https://github.com/zheref/nen) **`>= 0.1`** | a **hard** dependency — see [The Nen contract](#the-nen-contract-d10). You do **not** need to install it yourself; the warm-up does it, checksum-verified. |
| `git` + [`gh`](https://cli.github.com), authenticated | the skills read and write GitHub as **you**. |

Nothing here needs `jq`, `yq` or Python. One binary, plus `git` and `gh`.

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
claude plugin list                  # hatsu@hatsu — Version: 0.1.0
claude plugin details hatsu@hatsu   # the full component inventory
```

---

## The Nen contract (D10)

Hatsu's skills do not improvise shell. Every deterministic step is a `nen` verb, and the dependency on that
binary is **hard**, **version-ranged**, and **fail-closed with auto-install**.

**[`nen.contract.json`](nen.contract.json) is the single source of truth.** Every version, ref, URL and
command echoed anywhere else — this README included — is a convenience copy of a value that lives there.
**Where a copy disagrees with the contract, the contract wins and the copy is the bug.** The
[`hatsu-warmup`](claude/skills/hatsu-warmup/) skill executes it at the start of every session, before any
other Nen-owned work.

### The range

*Current pin, echoed for convenience:* **`nen >= 0.1`**.

**While nen's line is `0.x`, that means `>=0.1.0 <0.2.0` — exactly.** A different minor is out of range in
**both** directions: `0.2.0` fails it as surely as `0.0.9` does. At major version zero, SemVer 2.0.0 clause 4
makes the *minor* the breaking-change vehicle, so reading `>= 0.1` as "anything backward-compatible within
major 0" would fail **open** in precisely the range where compatibility is least guaranteed. The familiar
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
carries an `Akatsuki-Agent: <name>` trailer and no run trailer — there is no CI run to name. **The git author
is always the human.**

### Kurapika — the lead persona

Summoned with **`/kurapika`**. He trained all six Nen types, and his canonical trick is not power but
**conditions**: a binding accepted in advance, stated out loud, paid in full. The six types are his
work-modes, and **naming the mode in play is not decoration** — it tells you which authority he believes he
is holding, so you can catch him holding the wrong one *before* he acts on it.

| Mode | Lane | Where its work stops |
|---|---|---|
| **Enhancer** | **Product code** — edit, build and test locally, open the PR. | the merge gate — **yours** |
| **Conjurer** | **Canon & governance authoring** — constitutions, handbooks, schemas, agent definitions, taxonomies, thresholds. Conjured contracts *with conditions*: a clause states what it binds, what it costs, when it lapses, and what happens when it is broken. | the policy gate — **yours** |
| **Transmuter** | **Machinery** — Nen verbs and their tests, scaffolding, hooks, workflows, generators, plugin manifests, contract files. The standing transmutation is *improvised shell → deterministic verb*. | the policy gate — **yours** |
| **Manipulator** | **GitHub-side ops** — drives, wakes, labels, retargets, cascades, thread stewardship. | drives *to* a gate, crosses none |
| **Emitter** | **Release & fan-out** — the tag cut, changelog collation, preflight, the repin fan-out. | prepares a release; **never publishes one** |
| **Specialist** | **Product intake** — a raw thought elicited into a decision-complete brief, filed only on explicit confirmation. | epic approval — **yours** |

### Ratified independents

Four, each with a discipline Kurapika delegates to rather than absorbing.

| Agent | Discipline | Status |
|---|---|---|
| **[Gon](claude/agents/gon.md)** | **Mission-scoped trusted delegate.** He always asks: what is the mission · which gates may I cross · under what conditions · when does the grant expire · where is it logged. | **Ratified as an agent. His delegation grammar is a DRAFT — so he crosses no gate.** See below. |
| **[Hisoka](claude/agents/hisoka.md)** | **UI/UX review and quality measurement, before a PR is ever posted** — the visual-evidence set, and the cheap objective things measured on your own machine: contrast ratios, target sizes, type scale, reduced-motion, artifact delta. | **Ratified** |
| **[Phinks](claude/agents/phinks.md)** | **Adversarial pre-release QA, under the proven-finding discipline** — every hypothesis class gets a recorded disposition, and nothing is filed that is not proven: a committed test failing 3/3 against the candidate, or a measured number with its method block. | **Ratified** |
| **[Uvogin](claude/agents/uvogin.md)** | **Performance testing** — the fixed seven metrics on every pre-release run, with pinned tooling, regression thresholds, in-repo baselines, and a five-field method block per number. | **Ratified** |

> #### ⚠️ Gon's delegation grammar is a DRAFT — until it is ratified, Gon crosses no gate
>
> The clause that would make a gate-crossing grant *valid* — **mission · gates · conditions · expiry ·
> logging** — is drafted here at [`docs/delegation-grammar-DRAFT.md`](docs/delegation-grammar-DRAFT.md) and
> **ratified elsewhere**, with the rewritten constitution. **No grant can be given today, because there is
> no valid form for one to take.** Gon does the work, takes it to the gate, and stops there, exactly as
> every agent does by default. A delegate that acts on a draft has ratified the draft by itself.

### 🔶 OPEN — Illumi and Killua

**These rows are open sub-decisions, and the ruling has not been made.** It is the maintainer's, not this
repository's. What follows is recorded **verbatim as proposals**. Neither has a definition in
`claude/agents/`, and **neither may be acted as**.

| Agent | *Proposed* role | Status |
|---|---|---|
| **Illumi** | *Proposed:* long-running loop engines — `backlog-loop`, `futon`, `senkei`; needle control of many bodies at once. | **OPEN** |
| **Killua** | *Proposed:* delegate-run watchdog paired with Gon — a Gon mission never runs unwatched — plus fast single-object interventions. | **OPEN** |

**Killua's row touches Gon's grammar and must not be collapsed into it.** If ratification adopts the pairing,
`watched` becomes a *mandatory* condition on every Gon grant; if it does not, `watched` stays optional or is
dropped. **Neither is assumed.**

When work arrives that plainly wants one of them: do it in the fitting Kurapika mode and **name the gap**.
Naming it is what eventually gets the ruling made. Standing up the agent instead closes an open question with
nobody deciding it.

### 🔶 BENCH — the Genei Ryodan

**Bench only. No activation here, and none implied.** These are *extensible professional-profile agents,
adopted as needed* — a list of shapes the roster can grow into, not a roster. Which profiles activate, and
when, is open.

| Bench member | Profile | Bench member | Profile |
|---|---|---|---|
| **Chrollo** | Architecture | **Shalnark** | Automation |
| **Feitan** | Security | **Kortopi** | Scaffolding |
| **Machi** | Integration surgery | **Pakunoda** | Repo forensics |
| **Shizuku** | Cleanup | | |

None has a definition in `claude/agents/`, none is listed in `plugin.json`, and **none may be acted as**.
Adopting one is a deliberate act with its own decision, not a consequence of it being written here.

---

## The skills

Seventeen, invoked as `hatsu:<name>`. Longer descriptions in
[`claude/skills/README.md`](claude/skills/README.md).

| Skill | |
|---|---|
| `backlog-state` | The whole backlog as one gate-oriented table — every open issue, its PRs, the gate it sits at, what it needs next. Read-only. |
| `backlog-board` | The identical sweep and computation, painted as an HTML gate board published as an Artifact. Read-only. |
| `backlog-loop` | Drives a repository's backlog to zero open actionable issues, in severity order, as gate-ready PRs. |
| `backlog-synthesis` | Groups open issues sharing a clause, a machinery file or a root cause into one consolidated issue, originals attached as sub-issues. |
| `bankai-handbooks` | Resolves which handbooks govern a repo and scenario, and which rule-ID prefix each one owns, so a citation is never improvised. |
| `bankai-quality` | Resolves the adversarial-test tooling, performance tooling and QA rules for a repo's scenario, before a release is cut. |
| `build` | Takes one issue from wherever it sits to a delivery PR standing ready at its human gate. |
| `drive` | Drives one open PR to readiness at its gate and stops there — first blocking condition, threads, wakes. |
| `file` | Files one well-formed, correctly-labelled, non-duplicate issue — reconciled against the open backlog first. |
| `futon` | Takes one whole severity band from open issues to PRs with an actor behind them, then runs the terminal step you typed. |
| `getsuga` | Cuts a release tag locally, end to end — preconditions, one folded release PR, the tag, the fan-out. Never publishes. |
| `izanagi` | Repeats a task that **acts** until a condition holds, under a **mandatory** iteration cap. No cap, no run. |
| `izanami` | Repeats a **read-only** task until a condition holds. It looks, reports, and stops. |
| `jujisho` | Splits a mixed working copy into up to two stacked branches and PRs, by axis, proving nothing was left behind. |
| `pr-state` | Reports one PR's readiness as the deterministic gate's verdict, quoted, with the conjunct that failed. Read-only. |
| `senkei` | Inventories a consuming product repo's own backlog and states a Ready/not-Ready call for every open PR. |
| `tensho` | Turns a dirty working copy into one PR standing ready at its gate, reviewing every file before staging it. |

Plus [`hatsu-warmup`](claude/skills/hatsu-warmup/) — the Nen contract, executing — and the `/kurapika`
summon command.

### Evidence

Every one of the seventeen ships with its own A/B record in **[`docs/ab/`](docs/ab/)**: the mechanics before
the port, the mechanics after, and a live transcript against a real backlog showing the same verdict reached
with fewer improvised commands — `nen` invocations where the old transcript had raw `gh`. The surface was
proven before this version was cut; it is not an aspiration.

### Rollback

Reinstall the bankai plugin; nothing server-side changed.

---

## The gates

Hatsu drives work **to** a gate and stops. It does not cross one.

| Gate | Delegable? |
|---|---|
| **Epic approval** — the human applies one delivery-mode label | **Never** |
| **Release into build** — applying the building stage label | Only under four exhaustive, named carve-outs |
| **Merge to `main`** | **Never** by these agents. No agent here merges `main`, or its own PR anywhere. |
| **Release go/no-go** | **Never.** Preparing a release is allowed; publishing is not. |
| **Policy / spec change** | **Never** |
| **Anything else human-only** | **Never** — its definition *is* "the decision is yours" |

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
surface is `.claude-plugin/**`, `claude/**`, `nen.contract.json`, `contracts/**` and `docs/ROSTER.md` —
everything an installed copy reads. Bump `version` (patch for wording, minor for behaviour or a new skill,
major for a breaking interface change); or, if a change provably cannot affect the shipped surface, write
`no plugin bump: <reason>` in the PR body. Recorded refuse/pass transcripts:
[`docs/ab/plugin-bump-guard.md`](docs/ab/plugin-bump-guard.md).

### Validate locally

```sh
claude plugin validate . --strict
```

---

## License

**This repository is not yet licensed.** There is no `LICENSE` file, and until one is added no open-source
grant is made — default copyright applies, and you should not assume permission to use, modify or
redistribute this code.

The license is a pending maintainer ruling (the standing proposal is MIT). It is stated here plainly rather
than defaulted quietly: a repository that *looks* open and is not is worse than one that says so.
