# `contracts/skill-shape.json` — the skill shape as data, and the coverage checks beside it

> **Lives in** this plugin, at [`contracts/skill-shape.json`](../../contracts/skill-shape.json); a consumer carries none · **Written by** the maintainer of `zheref/hatsu`, on a PR at its `G4` gate; the exemption list only ever loses entries · **Validated by** `scripts/skill_shape_check.mts` itself (exit `2` on a malformed file) and lane `skill-shape-guard` · **Authority** [`docs/PROCESS.md`](../PROCESS.md) § *The skill shape*

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
- an exemption for a section the checked skill in fact carries (stale);
- under `--base` or `--base-root`, an exempt section the base's list did not carry. The list only shrinks, and a base with no contract file lists nothing.

**A refusal** is exit `2`: wrong usage, an unreadable contract or base contract, a base git cannot resolve, or nen exiting other than `0` or `1`.

## The coverage checks beside it

[`scripts/canon_coverage_check.mts`](../../scripts/canon_coverage_check.mts) runs in the same lane and checks two things:

- **Decision rows.** Every `nen/decisions.json` row's `citedBy` list must match the skills that cite the row ([`decisions.json.md`](decisions.json.md)).
- **Lanes.** Every `project.lanes` key must be named by a canon file ([`contract.json.md`](contract.json.md) § *Hatsu's own lanes*).

## Who reads it

Lane `skill-shape-guard` runs the hermetic fixture `scripts/skill_shape_check_fixture.mts`, then the **live read** of the checkout: `nen shu test --lane skill-shape-guard --repo <hatsu>`, and in CI `unit-tests.yml` through `scripts/unit_tests_ci.mts`.

- **The base.** The live read judges touched skills from the merge base of `HATSU_BASE_SHA`, the base revision the runner hands every lane. It is fetched into a shallow checkout, with the history unshallowed, when absent. Without `HATSU_BASE_SHA` the read falls back to `origin/main`.
- **Red, every time.** A live finding exits `1`, and the lane is red. A read that could not run is `NOT CHECKED`, exit `2`, and red too. Whether the check is *required* is the branch protection's question, as for `canon-lint` ([`docs/GATE-CONFIGURATION.md`](../GATE-CONFIGURATION.md)).

## Sources

- zheref/hatsu#502 (SDD plan wave 4; assessment findings B6 and C6).
- [`docs/PROCESS.md`](../PROCESS.md) § *The skill shape*.
