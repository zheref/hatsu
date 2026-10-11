# `nen/labels.json` — the label vocabulary every filing and classification is checked against

> **Lives in** the consumer repository · **Written by** `nen classify install --write` for the `lang/` and `job/` families, the maintainer by hand for every other label (the first Hatsu declaration was hand-written, byte-equal to what the verb writes); pushed to GitHub by `nen labels sync` and `nen classify install --sync` · **Validated by** the `nen/labels.json` row of `nen schema check --repo .` (the description length guard runs at schema load) · **Authority** [`contracts/classify.taxonomy.json`](../../contracts/classify.taxonomy.json) for the two classification families; this file for everything else

## What it decides

This file is the one source of truth for the repository's labels: `nen issue file` checks every label of a filing against it, `nen label apply --repo <checkout>` refuses a label it does not declare, and `hatsu:classify` proposes only keys in the taxonomy ∩ this declaration. `hatsu:file` validates its plan against it at every filing; `hatsu:direct` applies its opt-in `model/<line>` verdict only where the five `model/` labels are declared; `hatsu:futon` applies `bankai:stage/building` and a severity on issues in scope through `nen label apply`, which reads the taxonomy here; `hatsu:backlog-loop` and `hatsu:backlog-synthesis` read the severity family from it and nowhere else.

When it is wrong the failures are of two kinds. A label declared here but never created on GitHub returns zero matches, so a severity precondition reports none open because nothing could match (tenkai § 4a: the declaration is the record, the provisioning is the gate). A label applied by hand that this file does not declare is invisible to every verb, and a stage, severity or gate family invented inside a filing is a `G4` canon decision made in the wrong place. The file asserts filing validation only: it never invents a stage, routing or gate taxonomy.

## Keys

### Top level

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `$comment` | string | optional; metadata nen preserves | the maintainer's rationale and the label policy | nobody; a reader |
| `labels` | array of label objects | required; the aggregate `FAIL`s without the file (nen has no built-in copy) | every label the repository recognises | `nen schema check`, `nen issue file`, `nen label apply`, `nen labels sync`, `nen classify *` |

### `labels[]`

One entry per label. The order is the file's; `nen classify install --write` appends absent taxonomy labels in taxonomy order and updates drifted ones in place, keeping every other entry and key.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `name` | string | required; exact, case kept | the label as GitHub spells it | every reader |
| `color` | string | six hex digits, no `#` | the GitHub label colour | `nen labels sync`, `nen classify install` (a colour that differs from the taxonomy's is `drift`) |
| `description` | string | at most 100 characters, enforced at schema load | the one-line meaning GitHub shows | `nen labels sync`, `nen classify install` |

### The GitHub default set

The labels GitHub seeds on a new repository, kept as data so a filing may use them: `bug`, `documentation`, `duplicate`, `enhancement`, `good first issue`, `help wanted`, `invalid`, `question`, `wontfix`. Hatsu's own file adds `accessibility`. A consumer with its own kind or severity family (`bankai:severity/*`, `bankai:stage/*` in the frozen reference convention) declares it here; Hatsu's file declares none, deliberately.

### The classification families: `lang/<key>` and `job/<key>`

The two axes of [`contracts/classify.taxonomy.json`](../../contracts/classify.taxonomy.json), applied by `hatsu:classify` (the rulings of 2026-10-04). Labels are `<prefix><key>` with no namespace; nen reads each axis structurally through its prefix and hard-codes none of the names. A label wearing an axis prefix whose key the taxonomy lacks is `foreign`: listed, never touched.

**`lang/`** (colour `1d76db`): the programming language the work needs; `prose` when it needs none. Companion formats (YAML, JSON, shell, Markdown and the rest) are never labelled; they ride the language whose toolchain the change exercises.

| Key | Meaning |
|---|---|
| `swift` | Needs Swift: SwiftUI, TCA, UIKit/AppKit, SwiftPM, the Apple toolchain |
| `kotlin` | Needs Kotlin: Compose, UDF, Gradle, the Android toolchain |
| `typescript` | Needs TypeScript: React, Redux, Node and Bun CLIs, the web toolchain |
| `csharp` | Needs C#: WinUI, UDF, .NET, MSBuild and NuGet, the Windows toolchain |
| `prose` | Needs no code language: canon, governance, documentation, agentic prose, specifications |

**`job/`** (colour `5319e7`): the development or maintenance job the scoped work is around; several when it spans jobs. Thirty-nine keys. `review` and `delivery-ops` are companion jobs that never stand alone on an issue.

<details>
<summary>The 39 job keys</summary>

| Key | Meaning |
|---|---|
| `discovery` | Framing the problem, the user, the evidence, the non-goals and what success measures |
| `requirements` | Observable requirements, acceptance criteria, activation and divergence contracts |
| `analysis` | Impact mapping, archaeology, ownership, debt and test-gap analysis before a change |
| `backlog` | Filing with reconciliation, classification, consolidation, epic waves, delivery planning |
| `orchestration` | Non-overlapping ownership, bounded parallelism, handoff schemas, fan-in verification |
| `architecture` | Responsibilities, interfaces, dependency direction, state and effect design, large refactors |
| `api-design` | A library's public contract: names, types, errors, lifecycle, supported platforms and runtimes |
| `ux` | Normal, loading, empty, offline, error and recovery journeys with no dead ends |
| `ui` | Hierarchy, layout, interaction, responsiveness, theming and every specified state |
| `implementation` | Idiomatic code conforming to architecture and requirements, with passing builds and checks |
| `integration` | Schemas, timeouts, retries, idempotency, serialization, platform-service substitution |
| `security` | Data classes, permissions, secrets, supply chain, abuse and injection; remediation verified |
| `accessibility` | Semantics, focus, scaling, contrast, assistive technologies, pluralization, string expansion |
| `unit-tests` | Deterministic tests protecting pure logic, transitions, effects, cancellation and errors |
| `integration-tests` | Modules and external boundaries proven together; shared fixtures; cross-version matrices |
| `ui-automation` | Critical journeys on representative devices with stable selectors and visual evidence |
| `performance` | Startup, responsiveness, memory, CPU, network, battery and throughput against budgets |
| `review` | Challenging correctness, security, compatibility and tests; every finding disposed |
| `release` | Versioning, packaging, signing, provenance, rollout, hotfix branches and backports |
| `ci-cd` | Reproducibility, least privilege, cache correctness, gates, retries, idempotent deployment |
| `observability` | Privacy-safe events, metrics, alerts, dashboards; production results against baselines |
| `triage` | Impact, severity, affected versions, timeline, containment, owner and priority |
| `bug-fix` | The smallest reliable reproduction, the first violated invariant, the smallest correct change |
| `refactor` | Structure improved behind stable public contracts, with characterization evidence |
| `upgrades` | Transitive changes, compatibility, deprecations, licenses, vulnerabilities, locks, rollback |
| `machinery` | Deterministic compiler, project, generator, linter, bootstrap and policy-enforcement behaviour |
| `documentation` | Setup, architecture, operations, troubleshooting and examples aligned with released behaviour |
| `migration` | Ordered, resumable, idempotent migrations with validation, rollback and consumer codemods |
| `deprecation` | Consumer inventory, warnings, migration paths, removal criteria, archival and provenance |
| `mechanical-edit` | Deterministic transformations with no semantic drift, validated by build, tests and checks |
| `prose-authoring` | Skills, personas, rules and canon: invariants, decision rules, outputs, failures, verification |
| `schema` | Versioned machine-readable contracts with validation, defaults, unknown fields, migrations |
| `adapters` | Canonical semantics compiled into each surface; generated files marked and reproducible |
| `evals` | Rubrics, fixtures, trajectories, grades and costs; a real failure added before prose changes |
| `drift-review` | Generated adapters and observed behaviour compared against canon; unexplained divergence blocked |
| `parity` | Porting a behaviour across platforms; in a product repo it sets the parity domain for every job |
| `onboarding` | `nen/contract.json`, `nen/workflow.json`, labels, permission packs and surface placement |
| `provisioning` | Self-hosted runners, nen binding, device trust, signing identities and host toolchains |
| `delivery-ops` | Commits, PR preparation, reviewer rounds, thread settlement, catch-up, CI redrive, release PRs |

</details>

### The verdict family: `model/<line>`

`hatsu:direct`'s opt-in verdict label (colour `0e8a16`), one per model line of [`contracts/direct.registry.json`](../../contracts/direct.registry.json) → `publish.label`. The value is the primary pick's line only, never a tier, version, surface or effort. Applied through `nen label apply`, never `nen classify` (whose contract carries exactly `lang` and `job`), and only where `nen/workflow.json` → `direct.publish` is `label` or `label+comment`.

| Key | Meaning |
|---|---|
| `claude` | the primary pick is on the Claude line (Anthropic) |
| `gpt` | the primary pick is on the GPT line (OpenAI) |
| `gemini` | the primary pick is on the Gemini line (Google) |
| `grok` | the primary pick is on the Grok line (xAI, served by Cursor) |
| `composer` | the primary pick is on Cursor's Composer line |

### Who writes it, and in which order

| Step | Verb | What moves |
|---|---|---|
| 1 | `nen classify install --taxonomy "$hatsu_root/contracts/classify.taxonomy.json" --repo <checkout>` | report only: present, `drift`, absent, `foreign`; exit `1` while anything is absent or stale |
| 2 | the same with `--write` | rewrites this file so every taxonomy label is present; uncommitted, it lands through the consumer's own declaration PR |
| 3 | `nen classify install … --sync --target <owner/name>` | creates or updates the taxonomy's labels on GitHub, and only those; refused at exit `1` while step 2 has not landed |
| 4 | `nen labels sync --target <owner/name> --repo <checkout> [--dry-run]` | create-or-update every label here, including the `model/` family and the repository's own; one rejected description never aborts the run |
| any | `nen labels rename --target <o/n> --map from=to` | renames in place, preserving every issue association |

`--write` and `--sync` together are a usage error. A GitHub sync before the declaration lands is what `hatsu:classify` § *Hard limits* forbids.

### Who reads it

| Reader | What it reads |
|---|---|
| `hatsu:file` § 5 | every label of the plan, through `nen issue file --repo <checkout carrying nen/labels.json>`; a label the file lacks is a refusal naming both locations |
| `hatsu:classify` § 3 | the taxonomy ∩ this file: only declared keys are proposed; `declared` is one of its states |
| `hatsu:direct` § 7 | whether `model/<line>` is declared before `nen label apply`; an undeclared label is the verb's refusal, said |
| `hatsu:futon` §§ 1, 7 | the selector token is an exact label matched on the live issues; the labels it may apply (`bankai:stage/building`, a severity) are checked here by `nen label apply` |
| `hatsu:backlog-loop` § 4, `hatsu:backlog-synthesis` § 5 | the severity family, passed as `--severity-family` and read from the target's file and nowhere else |
| `hatsu:backlog-state`, `hatsu:backlog-board` | severity off the live labels of each row; the family these verbs recognise is the one declared here |

## Example

Illustrative, for a plain product repository: the GitHub defaults, a severity family of the repository's own, and the three Hatsu families (the `job/` list is cut to two rows here; `nen classify install --write` fills all thirty-nine).

```json
{
  "labels": [
    { "name": "bug", "color": "d73a4a", "description": "Something isn't working" },
    { "name": "enhancement", "color": "a2eeef", "description": "New feature or request" },
    { "name": "documentation", "color": "0075ca", "description": "Improvements or additions to documentation" },
    { "name": "severity/critical", "color": "b60205", "description": "Work stops until this is settled" },
    { "name": "severity/high", "color": "d93f0b", "description": "Taken before the next band is started" },
    { "name": "lang/swift", "color": "1d76db", "description": "Needs Swift: SwiftUI, TCA, UIKit/AppKit, SwiftPM, the Apple toolchain" },
    { "name": "lang/prose", "color": "1d76db", "description": "Needs no code language: canon, governance, documentation, agentic prose, specifications" },
    { "name": "job/bug-fix", "color": "5319e7", "description": "The smallest reliable reproduction, the first violated invariant, the smallest correct change" },
    { "name": "job/implementation", "color": "5319e7", "description": "Idiomatic code conforming to architecture and requirements, with passing builds and checks" },
    { "name": "model/claude", "color": "0e8a16", "description": "hatsu:direct's primary pick is on the Claude line (Anthropic)" }
  ]
}
```

## When a skill needs a value that is not set

- **The file is absent.** `nen schema check` reports `FAIL` and every label-reading verb refuses by name (`nen/labels.json: no such file`). `hatsu:tenkai` § 3 routes the file to `nen scaffold init`; in a repository with no code lane that routing has no destination and the taxonomy is hand-authored, modelled on a sibling, never invented (tenkai § 4a).
- **The `lang/` and `job/` families are not declared.** `hatsu:classify` reports the state and asks once; on the answer `--write` edits the file and the change lands through the consumer's own PR before any `--sync` or `apply`. Nothing is labelled by hand (classify § 4, *Hard limits*).
- **A `model/` label is undeclared.** `hatsu:direct` § 7 reports the verb's refusal and publishes nothing for that label; under `label+comment` the comment still posts and names the refusal.
- **A severity family is absent.** `nen issue consolidate-close` without `--severity-family` refuses (backlog-synthesis § 5); `hatsu:futon` and `hatsu:backlog-loop` triage nothing they cannot label. Authoring a family is a `G4` canon decision for the maintainer, never a filing's side effect.
- **A label is declared but not on GitHub.** `nen labels sync --dry-run`, then `nen labels sync`; adoption creates the labels on the repository, not only in the file.

## Sources

- [`../../nen/labels.json`](../../nen/labels.json): Hatsu's own declaration and its `$comment`
- [`../../contracts/classify.taxonomy.json`](../../contracts/classify.taxonomy.json): the two axes, their colours and every key's description
- [`../../contracts/direct.registry.json`](../../contracts/direct.registry.json) → `publish.label`: the `model/` family
- [`../../claude/skills/classify/SKILL.md`](../../claude/skills/classify/SKILL.md) §§ 3–4 · [`../../claude/skills/file/SKILL.md`](../../claude/skills/file/SKILL.md) § 5 · [`../../claude/skills/direct/SKILL.md`](../../claude/skills/direct/SKILL.md) § 7 · [`../../claude/skills/futon/SKILL.md`](../../claude/skills/futon/SKILL.md) §§ 1, 7 · [`../../claude/skills/backlog-loop/SKILL.md`](../../claude/skills/backlog-loop/SKILL.md) § 4 · [`../../claude/skills/backlog-synthesis/SKILL.md`](../../claude/skills/backlog-synthesis/SKILL.md) § 5 · [`../../claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) §§ 3, 4a
- [`../WORKFLOW.md`](../WORKFLOW.md) § *A target repository with no delivery-stage taxonomy*
- [`../../nen/colors.yml`](../../nen/colors.yml): the note that no label family is declared in Hatsu's own repository
- `nen classify --help`, `nen labels --help`, `nen label apply --help` as read at the pinned build
