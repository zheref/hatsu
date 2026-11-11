# `contracts/skill-shape.json` — the skill shape as data, and the coverage checks beside it

> **Lives in** this plugin, at [`contracts/skill-shape.json`](../../contracts/skill-shape.json); a consumer carries none · **Written by** the maintainer of `zheref/hatsu`, on a PR at its `G4` gate; a reasoned exemption may be added · **Validated by** `scripts/skill_shape_check.mts` itself (exit `2` on a malformed file) and lane `skill-shape-guard` · **Authority** [`docs/PROCESS.md`](../PROCESS.md) § *The skill shape*

## What it decides

Which sections a skill must carry when an effort edits it, as [`PROCESS.md`](../PROCESS.md) § *The skill shape* states: a Residue, an Authority and a Hard limits section. Those are the three `requirements`, each a pattern in the `{name, pattern}` form `nen pr body-check --requirements-from` reads. [`scripts/skill_shape_check.mts`](../../scripts/skill_shape_check.mts) hands each checked `SKILL.md` to that verb, so the heading match is nen's. A requirement matches a level-2 heading whose title is the section's name, or a list of the three names joined by `,`, `and` or `&`. The title may follow an optional `N.` number and may end in ` — ` and a gloss. A heading that only mentions the word, such as `## 1. Invocation and authority`, is not the section.

**Enforced as touched.** The script checks only the skills a change set touches. Under `--base <ref>` those are the skills whose `SKILL.md` differs between the merge base of `<ref>` and the working tree, or is untracked. Under `--base-root <dir>`, they are the skills whose file differs in bytes from a base checkout. `--skills <a,b>` and `--all` name the set outright. A skill no change set touches is never failed, so the skills that predate the check are fixed when an effort next edits them.

## Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `requirements[]` | `{name, pattern}` objects | `residue`, `authority`, `hard-limits` | One required section each; `name` is what a finding and an exemption cite | `scripts/skill_shape_check.mts`, through `nen pr body-check` |
| `exemptions[]` | `{skill, sections, reason}` objects | **`[]`**: no skill is exempt | A skill that may lack the named sections, and why | the same |

**Findings** are exit `1`, one line each:

- a checked skill missing a section it is not exempt from;
- an exemption with no or a blank `reason`, or naming an unknown skill or section;
- an exemption for a section the checked skill in fact carries (stale).

A reasoned exemption may be added in any PR (HA#502/AC-2).

**A refusal** is exit `2`: wrong usage, an unreadable contract, a base git cannot resolve, or nen exiting other than `0` or `1`.

## The coverage checks beside it

[`scripts/canon_coverage_check.mts`](../../scripts/canon_coverage_check.mts) runs in the same lane and checks two things:

- **Decision rows.** Every `nen/decisions.json` row's `citedBy` list must match the skills that cite the row ([`decisions.json.md`](decisions.json.md)).
- **Lanes.** Every `project.lanes` key must be named by a canon file ([`contract.json.md`](contract.json.md) § *Hatsu's own lanes*).

## Who reads it

Lane `skill-shape-guard` runs the hermetic fixture `scripts/skill_shape_check_fixture.mts`, then the **live read** of the checkout: `nen shu test --lane skill-shape-guard --repo <hatsu>`, and in CI `unit-tests.yml` through `scripts/unit_tests_ci.mts`.

- **The base.** The live read judges touched skills from the merge base of `HATSU_BASE_SHA`, the base revision the runner hands every lane. It is fetched into a shallow checkout, with the history unshallowed, when absent. Without `HATSU_BASE_SHA` the read falls back to `origin/main`.
- **Red, every time.** A live finding exits `1`, and the lane is red. A read that could not run is `NOT CHECKED`, exit `2`, and red too. Whether the check is *required* is the branch protection's question, as for `canon-lint` ([`docs/GATE-CONFIGURATION.md`](../GATE-CONFIGURATION.md)).

## Before review

**This list is the one declaration of the guards a change set that edits a `claude/skills/*/SKILL.md` passes in its effort checkout before [`hanten`](../../claude/skills/hanten/SKILL.md) is raised** ([`build`](../../claude/skills/build/SKILL.md) § 4, phase 1; zheref/hatsu#563). Each guard's rules live on the page its row cites; none is restated here.

| Guard | The local run | Its rules |
|---|---|---|
| The skill shape | `nen shu test --lane skill-shape-guard --repo <checkout>` | this page, § *What it decides* |
| The decision coverage | the same lane: `scripts/canon_coverage_check.mts` runs inside it | [`decisions.json.md`](decisions.json.md), key `citedBy[]` |
| The canon prose lint | `nen canon lint --repo <checkout>` | [`prose.lint.json.md`](prose.lint.json.md) |

All three are deterministic and read only the checkout, so a red row is fixed in the effort, never handed to a reviewer. The set is fixed rather than chosen per diff: any `SKILL.md` in the change set selects all three. Selecting lanes from a change set's paths is a Nen verb's job, owed by zheref/nen#500 (`nen shu test --changed`); until it ships, no shell in a skill computes the selection.

## Sources

- zheref/hatsu#502 (SDD plan wave 4; assessment findings B6 and C6).
- zheref/hatsu#563 (the pre-review guard set, § *Before review*).
- [`docs/PROCESS.md`](../PROCESS.md) § *The skill shape*.
