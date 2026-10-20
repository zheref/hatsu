<!-- Canonical source: zheref/bankai-handbooks · handbooks/ports/<from>--<to>.md · rendered by hatsu:bankai-rule from templates/ports/pair.md -->
<!-- pair: <from> -> <to> · prefix: <prefix> · numbering: <per pair file | global, ruled with the prefix on the adoption PR> -->

# Port rulings — `<from>` → `<to>`

How a rule or concept of the **`<from>`** stack (`<from-prefix>-{n}`) is realised on the **`<to>`**
stack (`<to-prefix>-{n}`), one ruling per row, each with a stable id the next port reads and a
reviewer cites. Rulings are **technology-level**: they name stacks, rule ids, idioms and the handling;
never a product, a screen, a business rule or an object id. The directed pair is this file; the
reverse direction is its own file. Ids are append-only — a reversal is a new row with `supersedes`,
the old row is never edited.

## Scope

- **From:** `<from>` — `<from-prefix>-{n}`, `handbooks/stacks/<from>/`.
- **To:** `<to>` — `<to-prefix>-{n}`, `handbooks/stacks/<to>/`.
- **Always beside:** the always-load set (`UZF-`, `SEC-`, `UX-`, `REL-`, `QA-`) and the target's
  stack handbook; this file adds the relation between the two, nothing either already says.

## Equivalence — `mirror` and `map`

| id | source | target | handling | rationale | date | supersedes |
|---|---|---|---|---|---|---|

## Drift — `drop with note` and `target-only addition`

| id | source | target | handling | rationale | date | supersedes |
|---|---|---|---|---|---|---|

<!-- The rows are the only counter: an id is reserved by hatsu:bankai-rule § 3 against the tip, the run's
     own branch, every pushed rulings branch and every open pull request, never from a header field. -->
