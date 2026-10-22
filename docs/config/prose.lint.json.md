# `contracts/prose.lint.json` — the canon prose lint's rules, and the baseline that ratchets them

> **Lives in** this plugin, at [`contracts/prose.lint.json`](../../contracts/prose.lint.json) with its baseline [`contracts/prose.lint.baseline.json`](../../contracts/prose.lint.baseline.json); a consumer carries neither · **Written by** the maintainer of `zheref/hatsu`, on a PR at its `G4` gate; the baseline only ever loses rows · **Validated by** `scripts/prose_ambiguity_check.mts` itself, which refuses a malformed contract or baseline at exit `2` (a `nen schema check` row for `nen.prose-lint/v0.1` is owed with `nen canon lint`, zheref/nen#481) · **Authority** [HR-13](../ROSTER.md#hr-13) (the ratchet, two rules empty from day one, the exemptions) and [HR-4](../ROSTER.md#hr-4) (the one marker shape)

## What it decides

Which sentences in Hatsu's own canon prose a pull request may not add: an admitted manual step, a residue deferred to nen with no issue, a stale nen pin, a citation that resolves to nothing, a bare `#N`, a live-verification claim with no date or evidence, a malformed open question, a reading cited as ruled (each rule's `summary` in the file says it exactly). The guard, [`scripts/prose_ambiguity_check.mts`](../../scripts/prose_ambiguity_check.mts) (lane `canon-lint`), reads this file at run time and implements each rule under its fixed id, checking the `class` the contract pairs with it; no skill restates a rule. Its header names the usage and the exits.

The baseline is a ratchet, not a truth: the findings the tree carried when the guard landed, which a later PR may remove and never add. Prose never cites it. A fixed finding leaves a stale row, and so does a row whose file the walk no longer reads (deleted, renamed or out of scope); the guard reads either red until the row goes in the same PR. A row the head's baseline holds over the base revision's copy, summed per key, is growth and red: the pull-request check passes the trusted base copy as `--base-baseline`, and a local `--base <ref>` reads the merge base's. A baseline that repeats a key is refused at exit `2`.

## Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `$schema`, `contract` | string | `nen.prose-lint/v0.1`, `hatsu.prose-lint/v0.1` | the shape | the guard |
| `authority` | string | prose | the rulings the file answers to | a reader |
| `paths.include[]` | glob[] | `claude/skills/*/SKILL.md`, `claude/agents/*.md`, `claude/rules/*.md`, `docs/**/*.md` | what is linted; `surfaces/**` never is | the guard's walk |
| `exemptions` | object | `codeFences: true`, `quotedWords: true` | fenced code and quoted words are exempt from every rule (HR-13) | every rule |
| `records.paths[]`, `records.rules[]` | glob[], id[] | `docs/ab/**`, `docs/history/**`, `docs/Loop/**`, `docs/surfaces/evidence/**`, `docs/ROSTER.md`, `CHANGELOG*`; `PL-03` | dated records where a version literal is what was true when written | `PL-03` |
| `retired.rules[]` | id[] | `PL-02`, `PL-03`, `PL-05`, `PL-10` | the rules a RETIRED block (a `> **RETIRED…` quote, a `**RETIRED` paragraph or list item) is exempt from wherever it sits; a paragraph block ends at a blank line, a heading or a list item at the same or a shallower indent | every rule it names |
| `versionSource` | object | `file: nen/contract.json`, `minimum`, `pinned` (JSON pointers) | the only versions a pin or floor literal is compared with, read at run time | `PL-03` |
| `decisionsFile`, `markerRows[]`, `markerLimit` | string, id[], integer | `nen/decisions.json`; `missing-maintainer-choice`, `missing-argument`, `missing-configuration`; `3` | the ask-once-per-run rows an open-question marker may name, and how many one skill may carry; a listed row of any other class is refused at exit `2`, and a marker naming any human-gate row is a finding ([HR-4](../ROSTER.md#hr-4)) | the contract loader; `PL-11` |
| `emptyBaseline[]` | id[] | `PL-03`, `PL-04` | rules whose baseline must stay empty; a baseline row for one is refused at exit `2` | the baseline loader |
| `rulingsFile` | string | `docs/ROSTER.md` | where an HR row's status is read | `PL-12` |
| `declaredValues[]` | glob[] | `contracts/config-catalogue.json`, `nen/*.json` | the numbers a `nen …` flag value may match | `PL-09` |
| `rules[]` | `{id, class, severity, summary, pattern?, …}` | `PL-01` … `PL-12`; `severity` `fail` or `advisory` | one rule each; a `fail` finding counts against the baseline, an `advisory` one is printed and never counted. **The ids are fixed**: each has one handler in the guard, and a rule whose class is not its handler's, an id with no handler, or a class missing a key its handler reads is refused at exit `2` | the guard |

### `contracts/prose.lint.baseline.json`

| Key | Type | Represents |
|---|---|---|
| `frozenAt` | object | the integration commit the rows were read at, and the command that read them |
| `findings[]` | `{path, rule, text, count}` | one accepted finding, keyed by path, rule and normalised text (never a line number), `count` times; one row per key (a repeated key is refused at exit `2`); never `PL-03` or `PL-04` |

## Who reads it

`scripts/prose_ambiguity_check.mts`, through the `canon-lint` lane (`nen shu test --lane canon-lint`, kokusen's focused route when the guard, its fixture, the contract or the baseline changes) and the advisory pull-request check staged at [`templates/prose-ambiguity-check.yml`](../../templates/prose-ambiguity-check.yml). A prose PR that removes a finding removes its baseline row in the same commit and quotes the before and after counts from `--json`. The port of the verdict is owed to `nen canon lint` (zheref/nen#481) and the citation resolver to `nen ref resolve --citation` (zheref/nen#482); the script retires at that repin.

## Sources

- [`docs/ROSTER.md`](../ROSTER.md) § *Rulings of 2026-10-20 — the SDD assessment sitting*, HR-4 and HR-13.
- [`docs/PROCESS.md`](../PROCESS.md) § *An unresolved question in prose* and § *Residue and owned dependencies*.
