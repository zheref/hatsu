# Configuration files, one page each

Hatsu reads a small set of declaration files and invents nothing beyond them: what a repository builds
with, how its roster works in it, who counts as a reviewer, which labels exist, what colour a state is,
and which decisions a run may take on its own. This directory documents **every expected configuration
file, key by key**: the type of each value, the values it may take, the default a reader applies when it
is absent, what the value represents, and which workflows (skills) read it.

> **The files win.** Every value on these pages is a copy of one that lives in the file it describes or
> in the authority document linked from it. Where a page disagrees with the file, the file is right and
> the page is the bug. Validation is `nen schema check --repo <path>`, one row per file.

## The files

| File | Lives in | Decides | Page |
|---|---|---|---|
| `nen/contract.json` | every repository Hatsu works in | **what nen executes**: the pinned Nen dependency, lanes, per-verb argv, preconditions, hosts, deploy targets, launch targets, evidence, the repository's kind | [`contract.json.md`](contract.json.md) |
| `nen/workflow.json` | every repository Hatsu works in | **what the workflow decides with**: branch shape, iteration checks, tests, the coverage ladder, launch and deploy defaults, reports, notifications, commit trailers, the monitor cap, run profiles, the model matrix, review scopes, `mukai.autoEn`, the release unit, the advance-go gate, `direct.publish`, runners | [`workflow.json.md`](workflow.json.md) |
| `nen/gates.json` | every repository with a readiness gate | **who counts as a review round** and when a PR reads ready: reviewer identities, the approval policy, round caps, check exclusions, the round quorum | [`gates.json.md`](gates.json.md) |
| `nen/labels.json` | every repository issues are filed in | **the label vocabulary** a filing is validated against, including the `lang/`, `job/` and `model/` families | [`labels.json.md`](labels.json.md) |
| `nen/repos.json` | every repository | **the registry**: consumers, maintained tools, the canon pin, the `<CODE>` product codes, the role `nen repo classify` derives | [`repos.json.md`](repos.json.md) |
| `nen/colors.yml` | every repository a board is rendered for | **the colour vocabulary** of a backlog row's status and an issue's severity | [`colors.yml.md`](colors.yml.md) |
| `nen/decisions.json` | this plugin (read in every run) | **the decision matrix**: which stops a run resolves on its own, which it asks once, which are the maintainer's gates | [`decisions.json.md`](decisions.json.md) |
| `~/.config/hatsu/checkouts`, `~/.local/state/hatsu/ports/<run-id>.json` | the maintainer's machine, never a tree | **a port run's checkouts and its resumable record** (`kamui`, `hiraishin`) | [`ports.md`](ports.md) |
| `.claude/canon-values.yml` | a consumer that mirrors the canonical handbooks | **the canon mirror declaration** `hatsu:limbo` keeps current | [`canon-values.yml.md`](canon-values.yml.md) |
| `contracts/*`, `hooks/hooks.json`, the plugin manifests | this plugin | **plugin-owned registries** a consumer reads but does not edit: permissions, the classification taxonomy, the model registry, the config catalogue, scan rows, round-policy defaults, the hooks | [`plugin-registries.md`](plugin-registries.md) |

## The two files, and the line between them

The first two files split along one line, and the split is not stylistic: `nen/contract.json` → `project`
states a **fact about the machine** (how this repository is built, tested, linted, launched and shipped),
and `nen/workflow.json` states a **decision about the work** (how the roster works in it). A wrong
`project` block runs the wrong command, loudly, at exit `1` or `5`. A wrong `workflow.json` runs the right
command at the wrong moment, silently. Keeping them apart keeps the second class of mistake visible.
[`../WORKFLOW.md` § 1](../WORKFLOW.md#1--two-files-and-the-line-between-them) is the authority.

## Every settable value, at its default, with its options

[`../../contracts/config-catalogue.json`](../../contracts/config-catalogue.json) catalogues every value a
consumer may set in `nen/workflow.json`, `nen/gates.json` or `nen/contract.json` that a skill reads: its
`kind` (`open`, `enum`, `subset`, `external`), its canon default, its options, who reads it and what a
skill asks when it is needed and unset. The maintainer's ruling of 2026-10-01 makes it a rule that the
configuration files **show every optionally settable value at its default**, that a fixed-set value
carries a `$<key>` sibling listing its options, and that a skill needing a value nobody set guides the
owner through setting it instead of stopping. One script reads the catalogue:

```sh
scripts/config_values.sh diagnose --repo <path>          # what is set, what is defaulted, what is needed
scripts/config_values.sh fill     --repo <path>          # write every default and its $<key> options (behaviour-neutral)
scripts/config_values.sh need     --repo <path> --skill <s>   # what <s> cannot run without
scripts/config_values.sh set      --repo <path> <id> <value>   # set one catalogued value
```

`hatsu:tenkai` runs `fill` when it adopts a repository and routes every `need` to the owner's answer.

## Where a value's semantics are owned

| Topic | Authority |
|---|---|
| every `workflow.json` key, `project.launch`, `project.evidence`, `project.fromCore`, repository kinds | [`../WORKFLOW.md`](../WORKFLOW.md) § 2, § 3 |
| the Nen dependency block and the version range | [`../NEN-CONTRACT.md`](../NEN-CONTRACT.md) |
| `gates.json` and what each key costs you if it is wrong | [`../GATE-CONFIGURATION.md`](../GATE-CONFIGURATION.md) |
| the decision rows, as cited by each skill | [`../WORKFLOW.md` § 4](../WORKFLOW.md#4--the-phases-and-which-of-them-a-human-calls) and the skills under [`../../claude/skills/`](../../claude/skills/) |
| the model registry and the matrix it renders | [`../DIRECT-MATRIX.md`](../DIRECT-MATRIX.md) |
| how a repository becomes a consumer, file by file | [`../../claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) |
