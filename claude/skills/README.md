# Hatsu skills

This directory is the plugin's skill surface (`plugin.json` → `"skills": "./claude/skills/"`). The summon
surface lives beside it at `claude/commands/` (`"commands": "./claude/commands/"`); both are listed together
under *Skills* by `claude plugin details`, which is why they are described together here.

**As of `v0.1.0` the surface is complete**: the **seventeen ported skills** ([zheref/hatsu#2][2]) plus the
**two roster-machinery residents** that arrived with the skeleton ([zheref/hatsu#1][1]). Nothing here is
reserved any more, and nothing here is a placeholder.

Each skill is a directory holding a `SKILL.md` with `name` and `description` frontmatter. Invoke one as
`hatsu:<name>`.

---

## The seventeen ported skills

Ported from bankai-core **under their existing names** — only the mechanics changed: every deterministic
step that used to be improvised shell (`gh`, `git`, hand-rolled API calls) is now a
[Nen](https://github.com/zheref/nen) verb. What stayed with the skill is deliberate — severity reasoning,
synthesized titles, root-cause grouping, the adversarial confirmation pass, and the *ask* on every flagged
staging file. Nen detects, computes, formats and verifies; it never decides what only judgment can.

**Each one carries its own A/B evidence** in [`../../docs/ab/`](../../docs/ab/): the old mechanics, the new
mechanics, and a live transcript showing the same verdict from fewer improvised commands.

| Skill | What it does |
|---|---|
| [`backlog-state`](backlog-state/) | The whole backlog as one gate-oriented table — every open issue, its PRs, the human gate it sits at, what it needs next. Read-only. |
| [`backlog-board`](backlog-board/) | The identical sweep and computation as `backlog-state`, painted as an HTML gate board published as an Artifact, optionally re-rendering on every turn or state change. Read-only. |
| [`backlog-loop`](backlog-loop/) | Drives a repository's backlog to zero open actionable issues, in severity order, as gate-ready PRs. Never merges `main`. |
| [`backlog-synthesis`](backlog-synthesis/) | Reconciles a long backlog into a short one — groups issues sharing a clause, machinery file or root cause, then files one consolidated issue and attaches the originals as sub-issues. |
| [`bankai-handbooks`](bankai-handbooks/) | Resolves which handbooks govern a repo and scenario, and which rule-ID prefix each one owns, so a citation is never improvised. |
| [`bankai-quality`](bankai-quality/) | Resolves the adversarial-test tooling, performance-measurement tooling and `QA-{n}` rules for a repo's scenario — what Phinks and Uvogin read before they measure anything. |
| [`build`](build/) | Takes one issue from wherever it sits to a delivery PR standing ready at its human gate. Never applies a mode label. |
| [`drive`](drive/) | Drives one open PR to readiness at its gate and stops there — first blocking condition, thread stewardship, wakes. Never merges, never votes. |
| [`file`](file/) | Files one well-formed, correctly-labelled, non-duplicate issue — reconciled against the open backlog first, on one explicit confirmation. |
| [`futon`](futon/) | Takes one whole severity band from open issues to PRs with an actor behind them, then runs the terminal step you typed (`then tag`, `then tag+fanout`). |
| [`getsuga`](getsuga/) | Cuts a release tag locally, end to end — preconditions, one folded release PR, the tag, the fan-out. Prepares a release; never publishes one. |
| [`izanagi`](izanagi/) | Repeats a task that **acts** until a condition holds, under a **mandatory** iteration cap — an invocation without `up to <N>` is refused. |
| [`izanami`](izanami/) | Repeats a **read-only** task until a condition holds. It looks, reports and stops; it never writes. |
| [`jujisho`](jujisho/) | Splits a mixed working copy into up to two stacked branches and PRs, by axis, proving the union of the splits equals the original diff. |
| [`pr-state`](pr-state/) | Reports one PR's readiness as the deterministic gate's verdict, quoted verbatim, with the conjunct-by-conjunct reason. Read-only. |
| [`senkei`](senkei/) | Inventories a consuming product repo's own backlog — epics, integration branches, open PRs — classifies every effort and states a Ready/not-Ready call for each PR. |
| [`tensho`](tensho/) | Turns a dirty working copy into one PR standing ready at its gate, reviewing every uncommitted file before staging it. |

---

## The two roster-machinery residents

Neither is one of the seventeen. They landed with the skeleton because the plugin does not function without
them, and they are recorded here rather than folded silently into the count.

| Resident | Why it exists |
|---|---|
| [`hatsu-warmup/SKILL.md`](hatsu-warmup/SKILL.md) | The **D10 dependency contract executing**. It probes `nen --version` against the range declared in [`../../nen.contract.json`](../../nen.contract.json) (at `0.x`, `minimum: "0.1"` means `>=0.1.0 <0.2.0` — a different minor is out of range in *both* directions); when nen is **absent** it runs nen's own checksum-verified bootstrap directly, and when nen is **present but out of range** it re-pins through `nen bootstrap --script`. It halts with the exact command **only** if that bootstrap itself fails. It must run before any other Nen-owned work, including every skill above. |
| [`../commands/kurapika.md`](../commands/kurapika.md) | The `/kurapika` summon surface both manifests advertise. An agent definition alone creates no invocable command, so without this the manifests would describe a surface that does not exist. |

---

## A change here needs a version bump

Everything in this directory is plugin-shipped, and Claude Code keys its plugin cache on
`.claude-plugin/plugin.json`'s `version`. Edit a `SKILL.md` without bumping that field and the edit reaches
no installed copy — silently, with no error anywhere.
[`scripts/plugin_bump_check.sh`](../../scripts/plugin_bump_check.sh), wired as the `plugin-bump-check`
workflow, fails a PR that tries.

[1]: https://github.com/zheref/hatsu/issues/1
[2]: https://github.com/zheref/hatsu/issues/2
