# `nen/repos.json` — which repositories this one knows, what each is to it, and the codes it calls them by

> **Lives in** the consumer repository (and in every canon repository: `zheref/hatsu`, `zheref/nen`, `zheref/bankai-handbooks` each carry their own) · **Written by** the maintainer by hand, on a declaration PR at the repository's own gate; `hatsu:tenkai` routes the initial file to `nen scaffold init`; `hatsu:getsuga` § 3 bumps `latest`; `hatsu:limbo` § 4 edits `maintained_tools[].pinned` on a typed repin · **Validated by** the `nen/repos.json` row of `nen schema check --repo .` (`N consumers, N product codes, latest (…), pinned tools: <repo>@<tag>`) · **Authority** [`docs/WORKFLOW.md`](../WORKFLOW.md) § *Repository kinds*, § *Shared discovery protocol* (the registry's purpose), and `nen repo --help`

## What it decides

The registry is the one machine-readable record of the repository's estate: the consumers it fans out to, the tool repositories whose releases it consumes, the canon it pins, and the short codes that make `<CODE>#<N>` and `<CODE>-IS-#<N>` resolvable. `nen repo resolve` resolves every token (a code, a slug, a short name, `all`) against it and nothing else; `nen repo classify` reads the repository's **role** from it (`maintained_tools` is canon, `consumers` and `pending_onboarding` are consumers), which decides the gate a change stands at (`G4` for canon, `G2` otherwise). `nen canon pin` reads the canon tag from `maintained_tools[].pinned`; `nen fanout compute` intersects a release's changed workflows with each consumer's `consumes`.

When it is wrong the estate is misread, quietly: an unregistered repository is reported as such and never rounded to consumer, a `latest` placed inside a `maintained_tools` entry validates and reads `latest (unrecorded)`, a frozen or foreign registry is reported and never written, and a `pinned` that is not tag-shaped makes `nen canon pin` exit `1` and stops `hatsu:limbo` before it renders. A parseable row does not certify a pin: `nen warmup`'s `unpinned` and `stale` verdicts are relayed as nen reports them (tenkai § 6c, step 0).

## Keys

### Top level

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `$comment` | string | optional; metadata nen preserves (and `nen repo resolve all` no longer lists as a row) | what was verified, when, and what the file does not assert | a reader |
| `consumers` | array | `[]` when none | the repositories this one fans out to | `nen repo resolve`, `nen repo classify`, `nen repo scenario`, `nen fanout compute`; `getsuga` § 7, `tenkai`, `backlog-state` § 2 |
| `maintained_tools` | array | the process repositories whose releases this one consumes | the canon side of the role split | `nen repo classify` (role canon), `nen canon pin`, `nen repo resolve`; `tenkai_adopt.sh derive_role` (process) |
| `pending_onboarding` | array | optional | consumers not yet adopted; resolve as consumers | `nen repo resolve`, `nen repo classify` |
| `product_codes` | object `{CODE: owner/name}` | required for the `<CODE>#<N>` grammar | the short code each repository is called by | `nen repo resolve`, `nen ref format`; `pr-state` § 1, `file` § 1, `backlog-state`, `sharingan`, `tensho`, `jusshin` |
| `latest` | string | a **top-level** key; `latest (unrecorded)` when absent | the newest release this repository has cut | `nen schema check`; `getsuga` § 3 step 4 bumps it |
| `families` | array | optional; **never in Hatsu's own file** (§ `families[]`) | the product families this repository belongs to: one spec repository and the sibling members | `hatsu:kamui` §§ 2, 5; tolerated by `nen schema check` (zheref/nen#453) |

### `consumers[]`

One entry per consuming repository. A consumer's own registry records itself here with a `scenario` so `nen repo scenario` and `nen canon resolve` can derive its stack handbook ([`bankai-handbooks`](../../claude/skills/bankai-handbooks/SKILL.md) § 1, answer 2).

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `repo` | string | `owner/name`, required | the consumer's slug | every resolver |
| `scenario` | string | a stack handbook id (`swiftui-tca-uzf-v2`, `compose-uzf-v2`, `react-uzf-v1`, `bankai-machinery`); only a `consumers[]` entry carries one | which handbook set the repository is held to | `nen repo scenario`, `nen canon resolve`; `bankai-handbooks` § 1, `bankai-quality` § 1, `limbo` § 2 step 4 |
| `consumes` | array | workflow basenames | which released workflows reach this consumer | `nen fanout compute`; `getsuga` § 7 (`CON-22`) |

### `pending_onboarding[]`

Optional. Consumers that are registered but not yet adopted; `nen repo resolve` resolves them and `nen repo classify` reads them as consumers.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `repo` | string | `owner/name`, required | a consumer awaiting adoption; it carries no `scenario` | `nen repo resolve`, `nen repo classify`; `bankai-handbooks` § 1 names it among the states that are *not a consumer* for the scenario read |

### `maintained_tools[]`

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `repo` | string | `owner/name`, required | the tool repository | `nen repo classify` → `role: canon`; `nen repo resolve` |
| `role` | string | prose, free text | what this repository is to the estate | a reader; `tenkai_adopt.sh` reads membership, not the text |
| `pinned` | string | tag-shaped (`v1.2`, `v1.2.3`, `v1.2.3-rc1`); exactly one pinned tool, or `--source` names which | the tag of that repository at which this one reads its canon (`CON-13`); move it tag first | `nen canon pin`, `nen canon mirror generate|check` (default `--source`/`--ref`); `bankai-handbooks` § 0, `bankai-quality` (preamble), `limbo` §§ 2, 4 |

### `product_codes`

The `<CODE>` in `<CODE>#<N>`, `<CODE>-IS-#<N>` and `<CODE>-PR-#<N>`. Matched exactly and case-insensitively, never as a prefix; an unknown code is an error that lists the valid ones. Keys and values both resolve.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `<CODE>` | string → `owner/name` | letters; a code ending in a digit forces the `<CODE>#<N>` form (`pr-state` § 1) | the repository behind the code | `nen repo resolve <CODE>`, `nen ref format --code`; `pr-state`, `file`, `backlog-state`, `backlog-synthesis`, `sharingan`, `en`, `tensho`, `jusshin` |

### `families[]`

Optional; **declared only in a product family's own private trees** — each member's `nen/repos.json` and the spec repository's — on each one's own declaration PR, and read from each default branch ([`hatsu:kamui`](../../claude/skills/kamui/SKILL.md) § 2; epic zheref/hatsu#354). **Never in Hatsu's own registry, nor in any public tree**: the family is product-level and private ([PUBLIC-REDACTION](../PUBLIC-REDACTION.md)). nen `0.22.0` **tolerates** the key — `nen schema check` reads `ok` and validates none of it — and models neither the key nor the role: zheref/nen#453 is owed (validation, `nen repo classify` → `role: spec · gate: G2`, member resolution). Until it lands kamui reads the JSON itself and says so.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `name` | string | required, non-empty | the family's name, as the maintainer types it | `hatsu:kamui` |
| `spec.repo` | string | `owner/name`, required; its code in `product_codes` | the **spec repository**: the product's specification as a `github/spec-kit` set (WORKFLOW § 2 → `port`), one folder per feature | `hatsu:kamui` §§ 2–4 |
| `spec.role` | string | exactly **`spec`** | a fourth role beside `canon`, `consumer`, `unregistered` (ruled for this epic): product specification, not governance canon | `hatsu:kamui`; `nen repo classify` once zheref/nen#453 lands |
| `spec.gate` | string | exactly **`G2`** | the spec PR's merge gate — the maintainer's, like any product merge, never G4 | `hatsu:kamui` § 3 (the merge prompt, row `merge`) |
| `members[]` | object[] | one per sibling platform repository | the family's platform repositories | `hatsu:kamui` § 5 (row `port-siblings`) |
| `members[].code` | string | a key of `product_codes` | the member, resolved through `nen repo resolve` | `hatsu:kamui` |
| `members[].platform` | string | free text (`ios`, `android`, `web`, …) | what the member ships on; shown on each sibling-picker item. The member's stack stays on its own `consumers[]` entry's `scenario` (`nen repo scenario`) | `hatsu:kamui` § 5 |

The redacted fixtures [`scripts/fixtures/port-family/`](../../scripts/fixtures/port-family/) carry one member's registry **with** a family (`with-family/`, reading `ok … 1 consumers, 6 product codes`) and **without** (`without-family/`), every name a fixture placeholder that stands for no repository; `config_values.sh need --repo <fixture> --skill kamui` reads *every value it needs is set* on both.

### How `nen repo classify` reads kind and role

`nen repo classify [--target <owner/name>] [--repo <path>] [--json]` gives one verdict per repository, every fact naming its source:

| Fact | Values | Source |
|---|---|---|
| `role` | `canon` \| `consumer` \| `unregistered` | this file: `maintained_tools` is canon, `consumers` and `pending_onboarding` are consumers; unregistered is reported with a note, never rounded |
| `kind` | `product` \| `process` \| `library` \| `unknown` | `nen/contract.json`: a declared `project.kind` wins (the only way to read `library`), else the lanes' stacks; read only when `--target` is this checkout, otherwise `unknown` with a note |
| `stack`, `lanes` | the default lane's stack, the lane names | `nen/contract.json` |
| `gate` | `G4` \| `G2` | the role, by the ruling of 2026-09-18: the gate is the repository's role, not the file's kind |
| `role: spec` | **owed** (zheref/nen#453) | a family's spec repository, gate **G2**; at nen `0.22.0` it reads `unregistered` (or `consumer`), so `hatsu:kamui` reads `families[].spec.gate` instead and says so |

`scripts/tenkai_adopt.sh` reads the same split as `process` (`maintained_tools`) against `product` (`consumers`) to decide whether the repository's `release` row must be real; the kinds themselves are canon in [WORKFLOW § *Repository kinds*](../WORKFLOW.md): `process` is plugins and machinery (CLIs are process), `product` is an application or service a release deploys or uploads, `library` is declared only, `unknown` is the fallback and never a verdict. What the kind decides: the reviewer tier, and whether `hatsu:mugetsu` § 3's advance go may name the repository (`process` and `library` may; `product` and `unknown` may not).

### Who reads it

| Reader | What it reads |
|---|---|
| `hatsu:tenkai` §§ 3, 6a, 6c | present and parseable (the row routes to `nen scaffold init`); the role, for the `release` row and the readiness workflow's trusted guard; `nen warmup`'s pin verdicts |
| `hatsu:getsuga` § 3, § 7 | `latest` on the release proposal; `role: canon` for the gate; `consumers[].consumes` through `nen fanout compute` for the `CON-22` fan-out, one repin PR per affected consumer |
| `hatsu:bankai-handbooks` §§ 0–1, `hatsu:bankai-quality` § 1 | `maintained_tools[].pinned` for `zheref/bankai-handbooks`, read off the file and never remembered; `consumers[].scenario` through `nen repo scenario` |
| `hatsu:limbo` §§ 2, 4 | the pin through `nen canon pin`; the repin edit on `to <tag>` |
| `hatsu:backlog-state` § 2, `hatsu:backlog-board` § 1 | the repository set through `nen repo resolve --from <cwd>` and `nen repo resolve all`; a missing entry is set up in the registry's own checkout on its own declaration PR |
| `hatsu:file` § 1 | the target through `nen repo resolve <token>` |
| `hatsu:pr-state` § 1 and every `<CODE>#<N>` grammar | `product_codes` |
| `hatsu:kamui` §§ 2, 5 | `families[]` from each member's and the spec repository's default branch; `product_codes` for the members |

## Example

Illustrative, for a plain product repository that consumes the three public tool repositories and records itself as a consumer with a scenario.

```json
{
  "consumers": [
    { "repo": "<owner>/<product-repo>", "scenario": "swiftui-tca-uzf-v2" }
  ],
  "maintained_tools": [
    { "repo": "zheref/hatsu", "role": "Hatsu workflow and skill prose" },
    { "repo": "zheref/nen", "role": "Shared deterministic machinery" },
    { "repo": "zheref/bankai-handbooks", "role": "Canonical handbooks, constitution and shared agent conventions (CON-13)", "pinned": "<tag>" }
  ],
  "product_codes": {
    "PX": "<owner>/<product-repo>",
    "HA": "zheref/hatsu",
    "NN": "zheref/nen",
    "BH": "zheref/bankai-handbooks"
  }
}
```

`nen schema check --repo .` then reads `1 consumers, 4 product codes, latest (unrecorded), pinned tools: zheref/bankai-handbooks@<tag>`; `nen repo classify --repo .` reads `role consumer · gate G2` with `kind` from the contract's lanes.

## When a skill needs a value that is not set

- **The file is absent.** `nen schema check` reports `FAIL`; `nen repo resolve` refuses at exit `2` (no registry to resolve against, a different refusal from an unknown token). `hatsu:tenkai` § 3 routes the file to `nen scaffold init` behind its § 1 confirmation; in a repository with no code lane it is hand-authored, modelled on a sibling (tenkai § 4a).
- **The target is not recorded.** `missing-configuration` under [WORKFLOW § 4](../WORKFLOW.md): the verb's own sentence is relayed, the entry is set up in the registry's own checkout on its own declaration PR, never guessed, and never written into a frozen or foreign registry (`backlog-state` § 2, `bankai-handbooks` § 1). An unknown `<CODE>` is asked for with the valid codes as the picker's options (`pr-state` § 1).
- **No `pinned` on the canon entry.** `nen canon pin` exits `1` naming the field; `hatsu:limbo` § 2 step 2 and `bankai-handbooks` § 0 treat it as `missing-configuration`: candidates listed, the tag typed, recorded, re-read. A non-tag (`main`) is refused: cut the tag first, then repin (`CON-13`).
- **No `scenario` on the consumer's entry.** `nen repo scenario` refuses with *only a consumers[] entry carries a 'scenario' field*; the scenario is offered in the picker and landed on that repository's own PR (`bankai-handbooks` § 1). A repository recorded only under `maintained_tools` has no scenario by construction: its handbook set is `bankai-machinery`, read from the canon's `handbooks/INDEX.md`.
- **`latest` is absent.** `nen schema check` reads `latest (unrecorded)`; `hatsu:getsuga` § 3 writes it on the release proposal. Placed inside a `maintained_tools` entry it still validates and still reads unrecorded (tenkai § 4a): read the row, not the file.
- **`consumers` is `[]`.** `nen fanout compute` returns an empty affected set, a real and common result `getsuga` § 7 states with its basis rather than hunting for a repin.

## Sources

- [`../../nen/repos.json`](../../nen/repos.json): Hatsu's own registry and its `$comment`
- [`../WORKFLOW.md`](../WORKFLOW.md) § *Repository kinds*, § 4 *Ask, set up, continue*, § *A target repository with no delivery-stage taxonomy*
- [`../PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md): placeholder codes `RA`…`RE` and why a private consumer is never named in a public registry
- [`../../claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) §§ 3, 4a, 6a, 6c · [`../../claude/skills/getsuga/SKILL.md`](../../claude/skills/getsuga/SKILL.md) §§ 3, 7 · [`../../claude/skills/bankai-handbooks/SKILL.md`](../../claude/skills/bankai-handbooks/SKILL.md) §§ 0–1 · [`../../claude/skills/bankai-quality/SKILL.md`](../../claude/skills/bankai-quality/SKILL.md) § 1 · [`../../claude/skills/limbo/SKILL.md`](../../claude/skills/limbo/SKILL.md) §§ 2, 4 · [`../../claude/skills/backlog-state/SKILL.md`](../../claude/skills/backlog-state/SKILL.md) § 2 · [`../../claude/skills/file/SKILL.md`](../../claude/skills/file/SKILL.md) § 1 · [`../../claude/skills/pr-state/SKILL.md`](../../claude/skills/pr-state/SKILL.md) § 1
- [`../../scripts/tenkai_adopt.sh`](../../scripts/tenkai_adopt.sh): `NEN_DECLARATIONS`, `derive_role`
- [`../ab/limbo.md`](../ab/limbo.md): the fixture registry and `nen canon pin`'s two answers
- `nen repo --help`, `nen canon --help`, `nen schema check --help` as read at the pinned build
