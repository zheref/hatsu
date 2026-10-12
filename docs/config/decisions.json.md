# `nen/decisions.json` — which conditions stop a run, which ask once, and which resolve by default

> **Lives in** this plugin, as Hatsu's canon matrix at [`nen/decisions.json`](../../nen/decisions.json); a consumer repository may carry its own file, which `hatsu:tenkai`'s declaration table reads as optional (`ok — absent, optional, or defaults apply`) and which can never reclassify a `human-gate` row · **Written by** the maintainer's rulings, authored by hand (`hatsu:great-hiker` is the canon author); no scaffold writes it and `scripts/config_values.sh` never touches it · **Validated by** `nen schema check` (row `nen/decisions.json`, shape `nen.decisions/v0.1`) · **Authority** [docs/WORKFLOW.md § 4](../WORKFLOW.md#4--the-phases-and-which-of-them-a-human-calls), *The conditions that do NOT stop are data* and *Ask, set up, continue*; the rulings themselves live in [docs/ROSTER.md](../ROSTER.md)

## What it decides

One row per condition a running workflow can stop on, and for each the answer to one question: does the run resolve it by default, ask once, or hand it to the maintainer. The file exists because a stop typed as prose in the middle of a reply is a stop the maintainer can scroll past, and one they scroll past is one that did not happen; so the recurring stops have fixed defaults as **data**, every skill states its default in one line citing the row id, and only a genuine gate rings the bell with the banner.

Every skill reads it before it asks: `hatsu:breath` carries a dirty tree (`dirty-tree`), `hatsu:kokusen` hands a red check back to `hatsu:rasengan` (`red-lint`), `hatsu:ao` catches a stale base up and stops only on a semantic conflict (`stale-base`, `semantic-conflict`), `hatsu:en` requests an owed reviewer round inside the configured maximum (`cap-reached`) and ends at the merge prompt (`own-pr-merge`), `hatsu:mugetsu` publishes only on the maintainer's own go (`release-go`). `nen stop --options` reads the matching row to compose the stop, and `hatsu:jutaisho` § 3 seeds the picker's lettered options from the row's `preferred[]`. A wrong row here is silent in the way WORKFLOW.md warns about for policy: the right command runs at the wrong moment, a default is applied where a question was owed, or a question is asked where canon already settled the answer.

## Keys

The `$schema` and `contract` are both `nen.decisions/v0.1`. The file is one `rows[]` array; the `$comment` at the top lists which skill cites which row.

### Top level

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `$schema` | string | **`nen.decisions/v0.1`** | The shape nen validates against | `nen schema check` |
| `contract` | string | **`nen.decisions/v0.1`** | The same, as nen's contract name | `nen schema check` |
| `$comment` | string | prose | The maintainer's rationale and the index of citing skills | nothing in nen |
| `rows[]` | object[] | one object per condition | The matrix | `nen schema check`, `nen stop --options`, every skill before it asks |

### The three row classes

| `class` | What happens | Who decides | Bell |
|---|---|---|---|
| **`autonomous`** | Resolved by `default` with no question. The skill states the default in one line citing the row id, and the turn page says so | canon, once, in this file | none of its own; the page records the row id |
| **`ask-once-per-run`** | Asked once through the surface's own option picker (Crazy Slots: `AskUserQuestion` on Claude Code, `request_user_input` on Codex, `AskQuestion` on Cursor, `ask_question` on Antigravity), seeded by `preferred[]`, the recommended option starred; the run resumes on the answer in the same turn | the maintainer, inline | rung 1 and the picker, no banner |
| **`human-gate`** | A gate canon reserves for the maintainer (G1 to G5). The run stops with `nen stop`'s banner, the report link, the lettered options and the question in the picker. **Cannot be reclassified by a consumer's own file** | the maintainer, at the gate | every rung `notifications.rungs` lists |

### The row shape

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `id` | string | kebab-case, unique | The row id every skill cites; kept stable so existing citations resolve even when the row's meaning is re-ruled (`own-pr-merge`) | every skill, `nen stop --options` |
| `class` | enum | `autonomous` · `ask-once-per-run` · `human-gate` | Which of the three behaviours above applies | `nen stop --options`, `hatsu:jutaisho` § 1 |
| `default` | string | the command or act, with its placeholders (`<checkout>`, `<branch.base>`) | What an `autonomous` row does without asking, or what an `ask-once-per-run` row does on the maintainer's answer. A `human-gate` row carries none; `missing-maintainer-choice` carries none either, because a default is a derivation and the maintainer's word is never derived | the citing skill |
| `why` | string | prose, citing the ruling by date | The maintainer's ruling the row records | nothing in nen; quoted in reports |
| `preferred[]` | object[] | lettered options | The options the picker is seeded with; `hatsu:jutaisho` § 3 composes at least three from them and the session's state, never limited to them | `nen stop --options`, `hatsu:jutaisho` § 3 |
| `preferred[].key` | string | `A`, `B`, `C`, `D` | The letter the maintainer answers with | the picker |
| `preferred[].label` | string | one line | What the option does, as the picker shows it | the picker |
| `preferred[].command` | string | the exact command or act | What the run executes on that answer; every option is an executable act, never a mood and never the report | the citing skill |
| `preferred[].consequence` | string | one line | What follows from taking it | the picker |
| `preferred[].recommended` | boolean | `true` on at most one option; absent on the rest | The starred option. A `missing-maintainer-choice` row stars none | the picker |
| `gate` | enum | `G1` · `G2` · `G3` · `G4` · `G5`; `human-gate` rows only | Which human gate the row stands at: G1 the mode label, G2 the delivery merge, G3 publication, G4 the canon merge, G5 a genuine stop | `hatsu:jutaisho at <gate>`, `nen stop --gate` |
| `governs` | string[] | `<skill> <slot>` entries | For `missing-maintainer-choice`: the argument slots whose value is the maintainer's own word, typed and never picked | every skill that takes one of those slots |
| `proposeIssue` | boolean | `true` · `false` | Whether the stop carries a proposed process issue (`nen stop --propose-issue`, Netero's completeness shape) so the next session does not hit the same stop | `nen stop --options`, `hatsu:jutaisho` § 3 |
| `refuse[]` | string[] | prose | For `missing-configuration`: what is never written even when asked (a secret-shaped value, a frozen or foreign registry) | `hatsu:tenkai` § 6d, `scripts/config_values.sh set` |

### Every row

The rows at the time of writing, with the class, the default or gate, and the skills whose `SKILL.md` cites the row id. The citations are read from the plugin's skills; the file's own `$comment` carries the maintainer's index of the same.

<details>
<summary>Autonomous rows (resolved by default, no question)</summary>

| Row | Default | Cited by |
|---|---|---|
| `dirty-tree` | `nen shu warmup --repo <checkout> --branch <branch> --carry`: a dirty working copy at breath is carried onto the new branch, nothing discarded, the paths listed | `hatsu:breath` |
| `stale-send` | `scripts/send_freshness_check.sh` reports at exit `2` with both SHAs; kagutsuchi § 3b rebuilds through susanoo in the clean worktree at `origin/<branch.base>`'s tip and sends from there, never from the stale checkout. No `tags.identity` means `freshness: unverified`, never `fresh` | `hatsu:kagutsuchi` |
| `cap-reached` | `nen pr request-reviews --target <owner/name> --pr <n> --add-bots <reviewer>`, while requested rounds are under `round_policy.maxRounds` and resolved rounds under `round_policy.minRounds` (nen's keys from `v0.21.0`; the verb refuses a bot's request past `maxRounds` at exit `2` with a `refused:` line — any other exit `2` is usage, relayed); at the cap the run ends not-ready with the board quoted, never a question | `hatsu:en`, `hatsu:sharingan` |
| `own-pr-merge` | Into `branch.base`: never merge. En § 5's five checks, then the merge prompt with the PR's link and the inline `gh pr merge <n> --repo <owner/name> --merge --match-head-commit <judged head>` line for the maintainer to run (ruling of 2026-09-30, *En never merges*). The one PR an agent merges is getsuga § 3a's own release proposal, through `nen pr merge --release-unit` | `hatsu:en`, `hatsu:limbo` |
| `reviewer-exhausted` | Read `nen pr ready --explain`; no exhaustion is declared (`reviewer_fallback` is retired, ruling 2026-10-04). A member is unavailable when `nen pr request-reviews` answers exit `9` for it (`unrecordedBots`), never retried or counted. A met `round_quorum` excuses it; an unmet quorum is one owed round of the next `any_of` member, inside `sharingan` § 6's bounds; **every member at exit `9`** puts the PR at en § 5's merge prompt on hanten's rounds, the not-ready verdict quoted verbatim, never `ready` (ruling 2026-10-11). Outranks `cap-reached` | `hatsu:en` |
| `red-lint` | Hand the tree back to `hatsu:rasengan` with the failing check quoted; the turn continues, never a G5 | `hatsu:kokusen`, `hatsu:gyo`, `hatsu:jusshin`, `hatsu:great-hiker` |
| `injected-attribution-trailer` | `git reset --soft HEAD~1` on the tip the step just wrote (kokusen § 5) or re-squash (aka § 7), then row `harness-attribution-switch`; the unpublished tip is dropped, never amended | `hatsu:kokusen`, `hatsu:aka`, `hatsu:ao` |
| `missing-focused-route` | Hand the tree back to `hatsu:rasengan` to author the focused tests, then `hatsu:tsukuyomi` runs them; never a stop and never the full suite as a substitute | `hatsu:kokusen`, `hatsu:tsukuyomi` |
| `missing-tool` | `nen shu tools --repo <checkout> --install`: installed or resolved through the surface's own catalogue probe, never with elevation; a `verify-only` row that cannot be installed is reported with its remedy line | `hatsu:breath`, `hatsu:build`, `hatsu:classify`, `hatsu:direct`, `hatsu:jusshin`, `hatsu:black-voice`, `hatsu:great-hiker` |
| `stale-base` | `nen wc catch-up --repo <checkout> --base <branch.base>`: rebase when unpublished, merge when published; only a semantic conflict reaches `semantic-conflict` | `hatsu:ao`, `hatsu:sharingan` |
| `release-precondition-red` | `nen changelog collate --write`, then `nen changelog completeness`; reconcile in the same chunk and re-run `nen release preflight`. An active `RELEASE_HOLD` and an open critical issue stay human gates | `hatsu:getsuga` |
| `staging-flag` | Skip ignored, large and out-of-scope paths; mention-or-skip an unmentioned deletion; commit local-config and binary paths only when the request named them. Six of `nen stage triage`'s seven flag kinds; the seventh is `secret-shape` | `hatsu:kokusen` |
| `classify-undecidable` | Leave the axis empty, list the issue as undecidable with the reason; low-confidence keys are listed and never applied (`nen classify apply --include-low` is the maintainer's own hand) | `hatsu:classify`, `hatsu:build` |

</details>

<details>
<summary>Ask-once-per-run rows (the picker, seeded by preferred[])</summary>

| Row | Default and options | Cited by |
|---|---|---|
| `harness-attribution-switch` | Ask once; the harness's commit-attribution switch is the maintainer's own configuration outside the repository, toggled by their hand. **A** (starred) toggle it off then re-run the step; **B** re-run from a surface whose harness appends nothing; **C** leave the tip dropped and stop | `hatsu:kokusen`, `hatsu:aka`, `hatsu:ao` |
| `host-nen-link` | Ask once, only as the fallback to the session-start binding `scripts/nen_global.sh` performs; offered where the login shell reads *installed, not reachable*. **A** (starred, except on exit `3`) place the name-correct `~/.local/bin/nen` link and the PATH line where missing; **B** leave the host as it is | `hatsu:ten`, `hatsu:bakuryuha`, `hatsu:mugetsu` |
| `missing-consumer-declaration` | `hatsu:tenkai` apply for a Hatsu-owned scaffolding piece. **A** (starred) `scripts/tenkai_adopt.sh apply`; **B** `nen scaffold init --accept-detected --dry-run` then the real run; **C** continue with the refusal quoted, the phase `not measurable here`. Proposes an issue | data-only until a skill cites it (the file's `$comment`); `hatsu:tenkai` is named as its owner |
| `missing-argument` | Derive from the session, the branch, its open PRs and `nen/workflow.json`; one candidate a canon default covers is used and stated for this run only, otherwise ask. **A** (starred) use the derived value; **B** the next candidate; **C** type it. Not for a maintainer's-word value | every skill that takes arguments (one line, WORKFLOW § 4 *Ask, set up, continue*) |
| `missing-configuration` | Ask per item; on the answer write the item through its owner (`nen scaffold init`, `scripts/tenkai_adopt.sh apply`, `hatsu:jujutsu`, the file's own key), `nen schema check`, resume in the same turn. **A** (starred) set it up with the detected value; **B** another value; **C** run once without it. Proposes an issue. `refuse[]`: a secret-shaped value is never written, a frozen or foreign registry is reported, never written | every skill that reads configuration |
| `missing-maintainer-choice` | No default, no star: the value is the maintainer's own word. `governs`: `kagutsuchi <target>`, `mugetsu <target>`, `izanagi <cap>`, `jujutsu <device>`, `ren <request>`, `jusshin <target>`, `jusshin <machine>`, `jusshin <service-identity>`, `jusshin <accept-daily-account>`, `jusshin <desktop-overlap>`. **A** type the value; **B** stop here | `hatsu:kagutsuchi`, `hatsu:mugetsu`, `hatsu:izanagi`, `hatsu:jujutsu`, `hatsu:ren`, `hatsu:jusshin`, `hatsu:getsuga`, `hatsu:limbo`, `hatsu:tenkai`, `hatsu:bakuryuha`, `hatsu:great-hiker` |
| `mode-unknown` | The mode is derived from the issue's labels and the diff's paths first; the picker fires only on a genuine tie. **A** (starred) Transmuter; **B** Conjurer; **C** Enhancer | `hatsu:build` |
| `direct-mismatch` | Ask once when the session's surface, model alias or effort is outside the set of `hatsu:direct`'s picks; a session on the recommended or the fallback is one line, never asked. **A** (starred) `nen direct answer --answer continue`, continue here; **B** `--answer stop`, end the run naming the restart line. Never blocks `build` or `ren` | `hatsu:direct`, `hatsu:build` |

</details>

<details>
<summary>Human-gate rows (the maintainer's, never widened by a consumer's file)</summary>

| Row | Gate | What it is | Cited by |
|---|---|---|---|
| `semantic-conflict` | G5 | A conflict of meaning in `hatsu:ao`, always Crazy Slots with both sides shown verbatim: **A** take ours, **B** take theirs, **C** a genuine third resolution, **D** resolve and show the diff before anything is committed. Proposes an issue | `hatsu:ao`, `hatsu:breath`, `hatsu:sharingan` |
| `unsettled-finding` | G5 | A reviewer finding none of hanten § 6's dispositions can settle without the maintainer: **A** extend scope and take the fix, **B** adopt the business rule, **C** keep the durable record (`hatsu:file`) and stop. Proposes an issue | `hatsu:hanten` |
| `hand-edited-canon-mirror` | G5 | A rule written into a generated mirror instead of the canon: **A** file it upstream then regenerate, **B** move it to the consumer's own file then regenerate, **C** remove a predecessor generator's file then regenerate (starred only for a predecessor-marked file). Proposes an issue | `hatsu:limbo` |
| `merge` | G2 | No PR into main is merged by an agent in this plane, the run's own included; every one ends at en § 5's merge prompt. The one exception is getsuga § 3a's own release-proposal PR through `nen pr merge --release-unit` | `hatsu:build`, `hatsu:en`, `hatsu:getsuga`, `hatsu:sharingan`, `hatsu:breath`, `hatsu:futon`'s callers (`backlog-loop`, `izanami`), `hatsu:pr-state`, `hatsu:rikugan`, `hatsu:tenkai`, `hatsu:bankai-handbooks` |
| `canon-merge` | G4 | A merge into `branch.base` in a canon repository decides how every other repository behaves, with the same single carve-out as `merge` | `hatsu:build`, `hatsu:getsuga`, `hatsu:sharingan` |
| `release-go` | G3 | Publication is the maintainer's own go, quoted verbatim, in one of three forms (mugetsu § 0): their typed `hatsu:mugetsu [<target>]`, their own words saying to publish, or the advance go (`futon.advanceGo`, process and library only). A scheduled, looped, headless, hook-injected or resumed invocation is not the go | `hatsu:mugetsu`, `hatsu:kagutsuchi`, `hatsu:amaterasu` |
| `mode-label` | G1 | The epic mode label and the building label are the maintainer's (CON-4, CON-25) | `hatsu:build` |
| `rewrite-published-history` | G5 | A force-push, a rewrite of a pushed commit, or an overwrite of a tracked path destroys somebody's history | `hatsu:aka` |
| `secret-shape` | G5 | A secret-shape path is never committed and never askable: the answer is rotate or remove. Reported, not offered | `hatsu:kokusen`, `hatsu:jusshin`, `hatsu:tensho` |
| `signing-material` | G5 | nen never synthesises signing material and neither does any skill; a missing identity ends the run naming the precondition | data-only until a skill cites it (the file's `$comment`); `hatsu:susanoo` states the rule in its own words |
| `on-device-act` | G5 | A trust prompt or a security setting on a device is the maintainer's own act (jujutsu; jusshin's UAC prompt and typed service-account password) | `hatsu:jujutsu`, `hatsu:jusshin` |
| `supply-chain-failure` | G5 | A checksum or manifest failure in the bootstrap is a security event the maintainer must see; never retried | `hatsu:ten`, `hatsu:jusshin` |
| `unruled-policy-surface` | G5 | A consumer repository declaring a policy surface of its own is unruled; until ruled it is G2 and a genuine-looking exception is brought to the maintainer | `hatsu:backlog-state` |
| `ambiguous-intent` | G5 | A genuinely ambiguous request, a scope change, or conflicting requirements canon does not adjudicate: **A** (starred) the narrowest reading, **B** the wider reading, **C** restate the request. Brought once, through Crazy Slots | `hatsu:rasengan` |

</details>

> **Precedence worth knowing.** `reviewer-exhausted` outranks `cap-reached`: every quorum member at exit `9` is an observed impossibility, not a ceiling, and the board `cap-reached` would have carried goes onto the merge prompt. `secret-shape` is the one `nen stage triage` flag kind with no canon default and is never askable. A `human-gate` row can never be widened by a consumer's own file; an unruled condition asks once with a proposed issue, never a silent default.

## Example

Illustrative only: a consumer's own matrix carrying one row per class. A consumer's file adds rows for its own conditions or narrows an `autonomous` default; it cannot reclassify a `human-gate` row, so the third row below is the canon row restated, not a new one.

```json
{
  "$schema": "nen.decisions/v0.1",
  "contract": "nen.decisions/v0.1",
  "rows": [
    {
      "id": "dirty-tree",
      "class": "autonomous",
      "default": "nen shu warmup --repo <checkout> --branch <branch> --carry",
      "why": "A dirty working copy at breath is carried onto the new branch; nothing is discarded and the paths are listed in the report."
    },
    {
      "id": "missing-configuration",
      "class": "ask-once-per-run",
      "default": "ask per item; on the answer, set the item up through its owner, validate it with nen schema check, and resume the operation in the same turn",
      "preferred": [
        { "key": "A", "label": "set it up now with the detected value",
          "command": "write the item through its owner, nen schema check, then resume",
          "consequence": "the configuration exists from now on", "recommended": true },
        { "key": "B", "label": "set it up with another value",
          "command": "the same write with the value the maintainer picks or types",
          "consequence": "the same, on the maintainer's value" },
        { "key": "C", "label": "run once without it",
          "command": "the owning verb's --dry-run, or the phase reported not measurable here",
          "consequence": "nothing is written; the gap is named and asked again next time" }
      ],
      "proposeIssue": true,
      "why": "A missing configuration item is asked for per item, written on the maintainer's behalf once answered, and the operation continues.",
      "refuse": [
        "a value shaped like a secret, credential or signing material is never written",
        "a frozen or foreign registry is reported, never written"
      ]
    },
    {
      "id": "release-go",
      "class": "human-gate",
      "gate": "G3",
      "why": "Publication is the maintainer's own go, quoted verbatim; no composite reaches it on its own authority."
    }
  ]
}
```

## When a skill needs a value that is not set

This file has no catalogue entry: [`contracts/config-catalogue.json`](../../contracts/config-catalogue.json) lists settable values of `nen/workflow.json`, `nen/gates.json` and `nen/contract.json`, and `scripts/config_values.sh` writes only those three files. An absent `nen/decisions.json` is not a gap: `hatsu:tenkai`'s declaration table reads it as `ok — absent, optional, or defaults apply`, and the defaults the skills cite are the rows of Hatsu's own matrix.

The file is instead the **mechanism** behind every other missing value. When `config_values.sh need --repo <path> --skill <s>` exits `1`, the warm-up (`hatsu:ten` § 6 step 5b) asks through row `missing-configuration`: one picker question per item, the detected value starred, written through the item's owner on the answer, validated with `nen schema check`, the operation resumed in the same turn. A missing or unparseable argument is row `missing-argument`, completed inline the same way. A value that is the maintainer's own word is row `missing-maintainer-choice`, typed and never picked. What is not a gap is refused, never asked and never softened into a default: a secret, an on-device act, a human gate, a supply-chain failure, a frozen or foreign repository, a safety precondition (WORKFLOW.md § 4, *What is not a gap*).

For the four verbs themselves: `diagnose` reports what is outstanding in the three catalogued files, `fill` writes their absent defaults and `$<key>` annotations behaviour-neutrally, `need --skill <s>` lists what a phase cannot run without, and `set` writes one chosen value after the question; none of them reads or writes this file.

## Sources

- [`nen/decisions.json`](../../nen/decisions.json), Hatsu's own file, its `$comment` and every row's `why`
- [`docs/WORKFLOW.md § 4 · The phases, and which of them a human calls`](../WORKFLOW.md#4--the-phases-and-which-of-them-a-human-calls): *The only interruptions are genuine G5 stops*, *The conditions that do NOT stop are data*, *Ask, set up, continue*, *What is not a gap*, *The maintainer's word is never derived*
- [`docs/WORKFLOW.md § 1`](../WORKFLOW.md#1--two-files-and-the-line-between-them) (the failure modes of the two files)
- [`contracts/config-catalogue.json`](../../contracts/config-catalogue.json), its `$comment` on which files it covers
- [`scripts/config_values.sh`](../../scripts/config_values.sh), header comments and `WRITABLE_FILES`
- [`claude/skills/jutaisho/SKILL.md`](../../claude/skills/jutaisho/SKILL.md) § 1 and § 3 (how a row reaches the bell and the picker)
- [`claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) § 3 (the declaration table reading this file as optional)
- [`claude/skills/ten/SKILL.md`](../../claude/skills/ten/SKILL.md) § 6 step 5b
- every `claude/skills/<name>/SKILL.md` searched for the row ids in the *Cited by* columns
- [`docs/ROSTER.md`](../ROSTER.md), the rulings each `why` cites
