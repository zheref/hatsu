# `nen/colors.yml` — the colour vocabulary a backlog row's status and severity resolve to

> **Lives in** the consumer repository · **Written by** `hatsu:tenkai` § 4, rendered from [`templates/colors.yml`](../../templates/colors.yml) as a seed, then tuned by the maintainer; nen ships no built-in table and `nen scaffold init` writes none · **Validated by** the `nen/colors.yml` row of `nen schema check --repo .` (`N categories, N values`; absent reads `absent (optional)` from nen `0.11.0`), and `tenkai_adopt.sh diagnose`'s `nen/colors.yml` item (parses, declares a non-empty `categories:` block, is not a symlink) · **Authority** [`claude/skills/backlog-state/SKILL.md`](../../claude/skills/backlog-state/SKILL.md) § 6 for the `status` vocabulary; the `hatsu:futon` and `hatsu:backlog-synthesis` grammars for the `severity` bands; the file's own header for why it is a seed

## What it decides

`nen color status --repo <path> --present <a,b,c> [--category <name>]` applies this file's precedence to the values true of one backlog row and prints the first match plus what it outranked. `hatsu:backlog-state` § 6 calls it per row to colour the status column; `hatsu:backlog-board` § 2 computes the same picture and § 3 renders `resolved.name`, `resolved.emoji` and `resolved.label` into the Rikugan page; `hatsu:futon <repo>@<severity>` and `hatsu:backlog-synthesis <critical|high|medium|low|all>` take the `severity` band names on the command line. Nothing in Hatsu hard-codes a glyph or a tie-break: the skill calls the verb and relays what it resolved.

Without the file, `nen color status` cannot run at all and a status column cannot be coloured; `backlog-state` relays `unresolved` as a finding, never a default. A category the file does not declare is a usage error (exit `2`) naming the ones it does: a typo caught, not a gap to fill. The file declares no label family, deliberately: authoring one inside an adoption run would be a `G4` canon decision made in the wrong place.

## Keys

### Top level

The file is YAML. Comments carry the rationale; `tenkai_adopt.sh` reads the `categories:` block outside them.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `version` | integer | `1` | the colours schema version | `nen schema check` |
| `categories` | map of category name → category | at least one, non-empty; `status` and `severity` in the seed | the colour families this repository resolves | `nen color status`, `nen schema check`, `tenkai_adopt.sh` |

### `categories.<name>`

One family. The seed declares `status` (one backlog row's state) and `severity` (the band an item sits in). A repository with families of its own edits the values and the precedence here and re-runs `nen schema check`.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `scope` | string (folded) | prose | what one value of this category describes, and the column header rule | a reader |
| `precedence` | list of value names | every entry a key of `values`; first wins | which value is reported when several are true of the same row | `nen color status` (prints the chain beside every call) |
| `values` | map of value name → value | at least one | the vocabulary | `nen color status`; `backlog-state` § 6, `backlog-board` § 3 |

### `categories.<name>.values.<value>`

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `emoji` | string | one glyph (`🔵 🔴 🟢 🟡 🟠`) | what the status cell shows | `backlog-state` § 7 (the resolved glyph is passed to `nen board build`), `backlog-board` § 3 |
| `hex` | string | `#rrggbb` | the colour a rendered page uses | `backlog-board` § 3 |
| `label` | string | short | the human label beside the glyph | `backlog-board` § 3 (`resolved.label`) |
| `means` | string | one sentence | what the value tells the maintainer to do | the legend of a rendered board |

### The `status` category, as the seed declares it

Precedence `on_hold > blocked > ready_g2_g4 > ready_g1 > in_progress`: the thing a human must act on outranks the thing that is merely finished. Transcribed from `backlog-state` § 6, live-verified against a consumer's own file at the port.

| Value | Emoji | Hex | Label | Means |
|---|---|---|---|---|
| `on_hold` | 🔵 | `#1f6feb` | On hold | Deliberately parked; name what it waits on |
| `blocked` | 🔴 | `#d73a4a` | Blocked | A `G5` decision or action is required |
| `ready_g2_g4` | 🟢 | `#2da44e` | G2/G4-ready | `nen pr ready` says Ready and mergeable |
| `ready_g1` | 🟡 | `#d4a72c` | Ready to start | Ready to be started, or to have its spec iterated: `G1` or `G1-M` |
| `in_progress` | 🟠 | `#e36209` | In progress | Work is moving; nobody is waiting on the human |

### The `severity` category, as the seed declares it

Precedence `critical > high > medium > low`. The same circles as `status`, by canon, disambiguated only by the column header: head a column `Status` or `Severity`, never the two combined (`backlog-state` § 6).

| Value | Emoji | Hex | Label | Means |
|---|---|---|---|---|
| `critical` | 🔴 | `#d73a4a` | Critical | Work stops until this is settled |
| `high` | 🟠 | `#e36209` | High | Taken before the next band is started |
| `medium` | 🟡 | `#d4a72c` | Medium | Scheduled into a band of its own |
| `low` | 🟢 | `#2da44e` | Low | Taken when the bands above it are clear |

### Who reads it

| Reader | What it reads |
|---|---|
| `hatsu:backlog-state` § 6 | `nen color status --repo <path> --present <values>` per row; `unresolved` (exit `1`) is a finding, a missing category (exit `2`) a usage error |
| `hatsu:backlog-board` § 2, § 3 | the same computation, then `resolved.name`, `resolved.emoji`, `resolved.label` on the rendered board |
| `hatsu:futon` § 1 | the four `severity` band names as its selector grammar (`<repo>@<severity>[+]`); any other token is a label |
| `hatsu:backlog-synthesis` § 1 | the same four names plus `all` as its required filter |
| `hatsu:tenkai` § 4 | present, parseable, a non-empty `categories:` block; never compared byte for byte against the template |
| `nen schema check` | the row `ok nen/colors.yml N categories, N values`, or `absent (optional)` |

### How Tenkai renders it

`scripts/tenkai_adopt.sh apply` writes `templates/colors.yml` to `nen/colors.yml` only when the file is missing (`REPAIRED: rendered from templates/colors.yml, tune the values, they are a seed`). A present file that parses and declares a `categories:` block is `satisfied` whatever its values; a file with no `categories:` outside its comments, or an empty one, is `drift` with the repair *re-render from templates/colors.yml*; a symlink is refused and never followed. nen cannot scaffold this file because a binary that guessed the names would report a taxonomy the repository does not have, and `nen scaffold init` therefore does not write one either.

## Example

Illustrative, for a plain product repository that keeps the seed's two categories as rendered. The comments of the real template are omitted.

```yaml
version: 1

categories:
  status:
    scope: >-
      One backlog row's state. The precedence decides when several are true of
      the same row at once.
    precedence: [on_hold, blocked, ready_g2_g4, ready_g1, in_progress]
    values:
      on_hold:      { emoji: "🔵", hex: "#1f6feb", label: "On hold",        means: "Deliberately parked; name what it waits on." }
      blocked:      { emoji: "🔴", hex: "#d73a4a", label: "Blocked",        means: "A G5 decision or action is required." }
      ready_g2_g4:  { emoji: "🟢", hex: "#2da44e", label: "G2/G4-ready",    means: "nen pr ready says Ready and mergeable." }
      ready_g1:     { emoji: "🟡", hex: "#d4a72c", label: "Ready to start", means: "Ready to be started, or to have its spec iterated." }
      in_progress:  { emoji: "🟠", hex: "#e36209", label: "In progress",    means: "Work is moving; nobody is waiting on the human." }

  severity:
    scope: >-
      The band a backlog item sits in. Head the column Status or Severity,
      never the two combined.
    precedence: [critical, high, medium, low]
    values:
      critical: { emoji: "🔴", hex: "#d73a4a", label: "Critical", means: "Work stops until this is settled." }
      high:     { emoji: "🟠", hex: "#e36209", label: "High",     means: "Taken before the next band is started." }
      medium:   { emoji: "🟡", hex: "#d4a72c", label: "Medium",   means: "Scheduled into a band of its own." }
      low:      { emoji: "🟢", hex: "#2da44e", label: "Low",      means: "Taken when the bands above it are clear." }
```

Then:

```bash
nen schema check --repo .                                   # ok nen/colors.yml 2 categories, 9 values
nen color status --repo . --present ready_g2_g4,blocked     # 🔴 blocked, outranked: ready_g2_g4
nen color status --repo . --category severity --present high,low
```

## When a skill needs a value that is not set

- **The file is absent.** `nen schema check` reads `absent (optional)` and the aggregate stays green; `nen color status` refuses by name. `hatsu:tenkai` § 3 owns the item: `diagnose` reports `MISSING`, `apply` renders the seed. `backlog-state` § 6 relays the refusal and never reconstructs a colour from memory.
- **A category is not declared.** `nen color status` exits `2` naming the categories the file does declare; the skill reports the usage error, never widens the taxonomy on the consumer's behalf (tenkai § 4).
- **Nothing present resolves.** `unresolved` (exit `1`): a finding in the report, never a default glyph.
- **`categories:` is present but empty.** `tenkai_adopt.sh diagnose` reads `drift`: nen will refuse the file; re-render from the template or declare a family.
- **A consumer tuned its families.** Nothing asks: the file is a seed, Tenkai never compares it to the template, and `backlog-state` relays whatever the verb resolves.

## Sources

- [`../../nen/colors.yml`](../../nen/colors.yml): Hatsu's own file and its header on what is declared and what deliberately is not (zheref/hatsu#79)
- [`../../templates/colors.yml`](../../templates/colors.yml): the seed Tenkai renders, and why it is a template rather than a scaffold
- [`../../claude/skills/backlog-state/SKILL.md`](../../claude/skills/backlog-state/SKILL.md) §§ 6–7 · [`../../claude/skills/backlog-board/SKILL.md`](../../claude/skills/backlog-board/SKILL.md) §§ 2–3 · [`../../claude/skills/futon/SKILL.md`](../../claude/skills/futon/SKILL.md) § 1 · [`../../claude/skills/backlog-synthesis/SKILL.md`](../../claude/skills/backlog-synthesis/SKILL.md) § 1 · [`../../claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) §§ 3–4
- [`../../scripts/tenkai_adopt.sh`](../../scripts/tenkai_adopt.sh): the `nen/colors.yml` item (detect, apply)
- `nen color status --help`, `nen schema check --help` as read at the pinned build
