# Plugin-owned registries — the data files a consumer reads but never edits

> **Lives in** this plugin (`zheref/hatsu`), under `contracts/`, `hooks/`, `.claude-plugin/` and `.codex-plugin/` · **Written by** the maintainer of `zheref/hatsu`, on a PR at its `G4` gate; several are rendered into other files by a script or by `nen surface mirror generate` · **Validated by** the guard lanes of `nen/contract.json` (`permissions-pack-guard`, `direct-matrix-guard`, `config-values-guard`, `pr-composition-guard`, `issue-shape`, `criteria`, `surface-mirror-guard`, `plugin-bump-guard`) and `claude plugin validate . --strict` (the `plugin` lane's `lint` seat) · **Authority** each file's own `$comment` or `description`; [`docs/using/mirrors.md`](../using/mirrors.md) § 2 for which files are authored and which generated

## What it decides

A consumer configures Hatsu through two files of its own, `nen/workflow.json` and `nen/gates.json`, beside the taxonomy files `nen/labels.json`, `nen/repos.json` and `nen/colors.yml`. Everything else a skill reads as data ships with the plugin and is resolved from `$hatsu_root` at run time: the permission pack, the classification vocabulary, the model registry, the catalogue of settable values, the security-scan pins, the reviewer-round default, the PR-composition inputs, the frozen reference repository's gate, the three harness hooks and the three manifests. Every skill that reads one cites the file by path so a version, URL or name is never remembered in prose; where a copy disagrees with the file, the file wins and the copy is the bug (`contracts/scans.json`).

When one of these is edited inside a consumer, the edit is invisible: the skills read the plugin's copy at `$hatsu_root`, the generated mirrors read `hand-edited` at the next check, and a consumer-side copy of a hook or a pack is replaced by the next warm-up where it carries Hatsu's marker, or left alone and named where it does not. What a consumer may change is the value its own files declare, listed per file below.

## `contracts/permissions.json`

**Purpose.** The one source of every permission pack (zheref/hatsu#85): the commands Hatsu's skills actually run, scoped to the repository the session stands in, its linked worktrees and the repositories `nen/repos.json` declares as associated. Anything outside that scope is deliberately absent and keeps prompting.

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `contract` | string | `hatsu.permissions/v0.1` | the shape version | `scripts/permissions_pack.sh`, `nen surface mirror generate --permissions` |
| `scope` | object | `repository`, `worktrees`, `associated`, `enforced_by` | what the pack is scoped to, and that only Codex enforces a root (`sandbox_workspace_write.writable_roots`); Claude Code and Cursor allowlists are exe-and-argument patterns | a reader; the generator's Codex branch |
| `allow[]` | `{exe, args, why}` | bounded Nen, GitHub, Git, script and bootstrap rows; no `gh api *` | the commands a session is never asked about | both renderers |
| `deny[]` | `{exe, args, why}` | 22 rows (`git push origin main`, every `--force` spelling, …) | the second line behind `hooks/guard-base-branch.sh` | both renderers |
| `surfaces` | object | `cursor: {allow[], deny[]}`, `codex: {network_access}` | per-surface rows transcribed after the shared list, for that surface only | `nen surface mirror generate` |
| `$comment`, `$comment_removed_gh_auth_token` | string | metadata | the rationale; why `gh auth token` is not allowed (a credential leak an allowlist exists to prevent) | a reader |

**Rendered where.** `scripts/permissions_pack.sh --surface <s> (--render | --install --target <path>)`, run by the warm-up (`hatsu:ten` § 5) and by `hatsu:tenkai` § 2, never by a hook. Per surface: Claude Code `.claude/settings.local.json`, `permissions.allow` / `permissions.deny` as `Bash(<exe> <args>)`, rendered directly and **merged** into the user's own untracked file (never `.claude/settings.json`); Codex `.codex/config.toml` (`approval_policy`, `sandbox_mode`, `writable_roots`, `network_access`) and `.codex/hooks.json`, **copied** from the generated `surfaces/codex/`; Cursor `.cursor/cli.json` (`Shell(<exe> <args>)`, plus the tree-wide `Read(./**)` and `Write(./**)` rows) and `.cursor/hooks.json`, copied from `surfaces/cursor/`; Antigravity none, because no allowlist file exists and a per-persona `commandExecutionPolicy: auto` would approve arbitrary commands, so the pack there is the hooks the mirror places. Only a Hatsu consumer (a target carrying `nen/contract.json` or `nen/workflow.json`) gets a pack; every written path is excluded through `info/exclude`, never `.gitignore`.

**May a consumer override it?** Not the contract. On Claude Code the consumer's own entries in `.claude/settings.local.json` are kept except obsolete API reader grants and the unsafe `Bash(gh api *)` grant, which #326 removes on upgrade. On Codex and Cursor a file without nen's generated marker is the consumer's and is left alone and named; a tracked destination is never touched. A generator that has not run (no `surfaces/<s>/config.toml`) places nothing rather than improvising the text.

### Read-only GitHub API access (#326)

The installed Claude pack grants `node '<exact installed absolute Hatsu root>/scripts/gh_api_read.mts' *`. The caller substitutes the resolved root literally in the Bash command; leaving `$hatsu_root` in command text does not match. Cursor and Codex receive no Node grant from this row. The TypeScript entrypoint accepts named operations only; it builds fixed REST GET endpoints and one fixed GraphQL `query` with variables, then invokes `gh` without a shell. It rejects caller-supplied methods, endpoints, bodies, uploads, options and GraphQL documents before starting `gh`. Raw `gh api` has no pack grant. The separate `gh pr *` row is constrained by its `gh pr merge *` deny; #154's Nen-only delivery merge remains unchanged.

| Runtime read | Entrypoint operation | Why it is in the pack |
|---|---|---|
| `scripts/private_name_check.sh`: private repository list with `visibility=private`, `per_page=100`, pagination and name projection | `private-repos` | The public-text guard must read the complete live private list. |
| `sharingan`: branch rules and protected branch required checks | `branch-rules`, `required-checks` | A missing required check vetoes readiness. |
| `build`: issue's PR marker; `PROCESS`: workflow declaration at a ref | `issue-pr`, `workflow-content` | These are ordinary issue and configuration reads. |
| `spiritual-message`: Actions run timing; `cleanup`: caches and artifacts | `actions-timing`, `actions-caches`, `actions-artifacts` | These are fixed REST GET paths. |
| `file`: issue edit count | `issue-edits` | The only packed GraphQL form is a fixed query with typed variables. |

`release-publish.sh` reads a tag ref through `gh api` internally, under the release command's separate authority; `tag-ref` is available for direct audit reads. `tenkai_adopt.sh`'s repository lookup is also internal to its script. `direct`'s marker lookup, `illumi`'s arbitrary GraphQL read, generic `izanami` observations and any undocumented endpoint still require an explicit surface permission prompt. CI's check-run POST/PATCH and cleanup DELETE run under workflow credentials, outside this pack. The helper does not accept raw GraphQL text, so a `mergePullRequest` mutation cannot be smuggled into its query.

## `contracts/idle-permissions.json`

**Purpose.** The commands an idle batch (HR-5, `--idle`) runs unattended, one exemplar per shape with the skill that runs it (`hatsu.idle-permissions/v0.1`; zheref/hatsu#453). It **grants nothing**: `contracts/permissions.json` above stays the one source of the packs, and a permission setting is the maintainer's alone. `scripts/idle_permissions_check.mts --repo <checkout>` reads the session's Claude Code settings (`.claude/settings.local.json`, `.claude/settings.json`, `~/.claude/settings.json`) against it and lists every exemplar (one per command shape and per nen verb family, never every argv) that no `Bash(...)` allow rule matches, or that a deny or ask rule matches, before an idle run's first claim ([WORKFLOW § *Idle batches*](../WORKFLOW.md#idle-batches)).

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `contract` | string | `hatsu.idle-permissions/v0.1` | the shape | the check (exit 2 otherwise) |
| `needs[].command` | string | a command line; `<...>` stands for one word | what the batch runs | the check |
| `needs[].by` | string | the skill and section | who runs it | the check's report |

**Validated by.** Lane `idle-permissions-guard`. **May a consumer override it?** No; `--needs <file>` reads another list for one run.

## `contracts/classify.taxonomy.json`

**Purpose.** The two classification axes `hatsu:classify` applies: `lang/<key>` (five keys) and `job/<key>` (thirty-nine keys), each key carrying the source document's phases per domain, and the rule that derives the five domains at run time. nen hard-codes none of the names: the file is `--taxonomy` to the whole `nen classify` family. Full key lists are in [`labels.json.md`](labels.json.md).

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `$schema`, `contract` | string | `hatsu.classify-taxonomy/v1`, `hatsu-classify-taxonomy` | the shape | `nen classify labels` (validation) |
| `documentSha256` | string | the source document's digest | provenance; the matrix page prints it | `scripts/direct_matrix_doc.sh` |
| `source` | object | `document`, `rulings`, `readers[]` | where the vocabulary came from and who reads it | a reader |
| `axes.lang` | object | `prefix: lang/`, `color`, `describe`, `keys[] {key, code, title, description}`, `companions[]`, `companionRule` | the language axis; `code: false` marks `prose`; companions are never labelled | `nen classify *`, `nen direct resolve` (counts only code languages) |
| `axes.job` | object | `prefix: job/`, `color`, `describe`, `keys[] {key, title, description, companion?, phases per domain}` | the job axis; the first listed phase is the one `hatsu:direct` routes on | `nen classify *`, `nen direct resolve` |
| `domains` | object | `keys[]`, `tablePrefix`, `firstMatchWins`, `inputs`, `rule[]`, `fallback` | the derivation of `feature`, `maintenance`, `parity`, `aigov`, `library` from repo kind and role, the issue's labels and jobs; never a label | `nen direct resolve`; `hatsu:direct` § 3 |
| `classification` | object | `perAxisMinimum`, `gradedPer`, `undecidable`, `confidence`, `planRow`, `untrusted`, `signals` | the judgement discipline: high and medium applied, low listed, issue text treated as untrusted data | `hatsu:classify` § 3 |

**Read by.** `hatsu:classify`, `hatsu:file` § 5 (every filing), `hatsu:direct`, `hatsu:build` § 2a; `nen classify labels|install|status|apply` and `nen direct resolve` through `--taxonomy "$hatsu_root/contracts/classify.taxonomy.json"`.

**Rendered where.** Into a consumer's `nen/labels.json` by `nen classify install --write` (the declaration), then onto GitHub by `--sync`; into [`docs/DIRECT-MATRIX.md`](../DIRECT-MATRIX.md) by `scripts/direct_matrix_doc.sh`.

**May a consumer override it?** No. A consumer's `nen/labels.json` may carry any other label; a label wearing an axis prefix with a key the taxonomy lacks is `foreign`, listed and never touched. A third axis is refused by nen's contract (exactly `lang` and `job`).

## `contracts/direct.registry.json`

**Purpose.** The model-selection registry `hatsu:direct` resolves through `nen direct resolve --registry <this path>`: stable aliases (`SEMANTIC_FRONTIER`, `EXECUTION_FRONTIER`, `EDITOR_FRONTIER`, …) separated from replaceable versions, one routing cell per (job, domain, language) naming a winner and a runner-up alias, and the rules for effort, aggregation, mismatch and publishing. The rendered view is [`docs/DIRECT-MATRIX.md`](../DIRECT-MATRIX.md).

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `$schema`, `contract` | string | `hatsu.direct-registry/v1`, `hatsu-direct-registry` | the shape | `nen direct registry` (the probe) |
| `source` | object | `document`, `rulings[]`, `taxonomy`, `documentSha256`, `revision`, `readers` | provenance and the 2026-10-05 rebalance record | a reader |
| `snapshot` | object | `asOf`, `aliases` (version, list price, served id), `sources` | the dated fallback when a live read fails; never the primary source of a version | `hatsu:direct` § 4 |
| `aliases` | map | twelve: `{provider, family, line, surface, tier, escalation, selection}` | what each alias resolves to; `line` is the `model/` label vocabulary; `tier` is a key of `nen/workflow.json` → `models` | `nen direct resolve`; `scripts/direct_matrix_doc.sh` |
| `picks` | object | `primary`, `fallback`, `fallbackRule`, `recommended`, `tiers` | the three picks every cell yields and the invariant that the fallback sits on another provider or surface | `hatsu:direct` § 5; the matrix self-test |
| `companions` | object | `role` per companion job (`review`, `delivery-ops`) | jobs that ride the carrying effort | `nen direct resolve` |
| `surfaces` | object | `claude-code`, `codex`, `cursor`, `antigravity` (restart line, interactive twin), `$nonActionable` | Hatsu's four actionable surfaces; placeholders filled only from the consumer's `models` block | `hatsu:direct` § 5 |
| `nativeInteractive` | map by language | the IDE twin per language | the `interactive` equivalent a cell may name | the matrix page |
| `liveLookup` | object | per provider | how the newest version and dial are read live | `hatsu:direct` § 4 |
| `effort`, `aggregation`, `mismatch`, `emptyAxis`, `surfaceRule` | objects, string | levels and the rule; precedence; what a session is compared against; the empty-axis lines | the resolve's rules, stated once | `nen direct resolve`; `hatsu:direct` §§ 3, 6 |
| `publish` | object | `configKey: nen/workflow.json -> direct.publish`, `options: none \| label \| label+comment`, `default: none`, `label{family, keys, value, verb, declaredIn, replace}`, `comment{marker, verb, idempotent}`, `sweep` | the opt-in GitHub write | `hatsu:direct` § 7 |
| `phases`, `routing` | maps | the source document's phase ids; one block per job with `cells` per domain and language | the matrix itself | `nen direct resolve` |

**Read by.** `hatsu:direct` (standalone, `backlog`, under `hatsu:build` § 2b, under `hatsu:file` § 5 on every new filing, and under `hatsu:ren`, where it is report-only), `nen direct resolve|registry`.

**Rendered where.** `docs/DIRECT-MATRIX.md`, by `bash scripts/direct_matrix_doc.sh --write`; `--check` is the `direct-matrix-guard` lane and fails a stale page; `--verify` asks the verb about every printed claim.

**May a consumer override it?** Not a cell, an alias or a rule. A consumer spells its tiers in its own `nen/workflow.json` → `models.<surface>.<tier>` (what the restart line tells you to type) and opts into the GitHub write with `direct.publish`; absent, or anything but the exact strings `label` or `label+comment`, reads `none` and is said.

## `contracts/config-catalogue.json`

**Purpose.** Every value a consumer may set in `nen/workflow.json`, `nen/gates.json` or `nen/contract.json` that a Hatsu skill reads, with the default its readers apply when it is absent (the ruling of 2026-10-01): the configuration files show every optionally settable value at its default, a fixed-set value carries a `$<key>` sibling listing its options, and a skill that needs a value nobody has set guides the maintainer through setting it instead of stopping.

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `$schema` | string | `hatsu.config-catalogue/v1` | the shape | `scripts/config_values.sh` |
| `$comment` | string | the ruling, what is deliberately not listed and why, the row-field legend | the authority on the file | a reader |
| `domains` | map | `development`, `versioning`, `testing`, `review`, `reporting`, `notifications`, `deployment`, `publishing`, `intake`, `port`, `autonomy` | the order Tenkai asks in | `config_values.sh diagnose`; `tenkai` § 6d |
| `values[]` | rows (`workflow.aiReviewers`, enum `required` \| `optional` \| `off`, default `required`, asked at adoption, among them) | `id`, `file`, `path`, `domain`, `kind` (`enum` \| `subset` \| `open` \| `external` \| `secret-env`), `options?`, `default?`, `describe`, `readers[]`, `source`, `question?`, `setup?`, `requiredBy?`, `ask?` (`adoption` \| `on-use`), `when?`, `candidatesFrom?`, `nullIsAnswer?`, `choice?`, `sourceTable?`, `nonProductionTarget?` (`set` refuses a target whose `why` is not non-production or that lacks `nonProduction: true`, which nen requires), `landsByPR?` | one settable value: the `nen/workflow.json` rows, `gates.approval_policy`, `gates.reviewers`, and the `contract.project.*` rows (`defaultLane`, `kind`, `targets`, `launch`) at the pinned build | `config_values.sh diagnose|fill|need|set|check-catalogue` |

**Read by.** `scripts/config_values.sh` is the only reader: `diagnose` reports per row, `fill` writes the defaults and `$<key>` annotations into a declaration that already exists (behaviour-neutral by construction), `need --skill <s>` lists what a phase cannot run without, `set --id <id> --value <JSON>` writes one chosen value after the question was asked, `check-catalogue` holds every default to `docs/WORKFLOW.md`'s key tables. `hatsu:tenkai` § 6d runs it on adoption; `hatsu:ten` § 6 step 5b runs `need` at every phase's warm-up.

**Rendered where.** Into the consumer's own files: `fill` writes the default values and annotations, `set` one value. Not listed, on purpose: values derived at run time, values resolved from a Hatsu canon file only when absent (`round_policy`), values nen also reads whose built-in default may differ, structural blocks whose shape is the repository's own, and the three taxonomy files.

**May a consumer override it?** The catalogue is Hatsu's; the values are the consumer's. Anything `set` or hand-edited in the consumer's file is never rewritten by `fill`; a `secret-env` row takes an environment-variable name, never a secret, and every written string is screened before the write.

## `contracts/scans.json`

**Purpose.** The one source of the deterministic security-scan rows `hatsu:hanten` runs before Feitan reads: an exact gitleaks tag with its checksum manifest and per-host asset names, one dependency-audit row per ecosystem, selected by its `stacks`, the `nen stage triage` secret-shape read, and the builder-touching-workflow gate. A row that cannot run is reported as not scanned, never as clean.

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `contract` | string | `hatsu.scans/v0.2` (v0.2: the node row's keys below and every row's `stacks`) | the shape | `hatsu:hanten` § 2a |
| `$comment`, `authority` | string | the rationale; that Hanten and Feitan never remember a version, resolve `latest`, or run an unverified binary | the reading discipline | `hanten`, Feitan |
| `secretScan` | object | `tool: gitleaks`, `repository`, `version` (an exact tag), `versionSemantics`, `checksumsUrl`, `assetUrlTemplate`, `assets{darwin-arm64, darwin-x64, linux-arm64, linux-x64, win32-x64, win32-arm64}`, `verification`, `run` (`gitleaks detect --no-banner --redact --exit-code 1`), `failure`, `hostWithNoAsset` | the pinned secret scan and how it is verified and fails loud | `hanten` § 2a |
| `dependencyAudit` | object | `$comment`; `stackCatalogue{stacks, unrouted, aliases: string[]}` (a snapshot of nen's stack vocabulary; every stack and alias on exactly one row or unrouted, the resolver fixture's check); `node`, `swift` (OSV `querybatch`, ecosystem `SwiftURL`), `jvm` (`./gradlew dependencyCheckAnalyze`), each with `stacks: string[]` | one row per ecosystem, selected by its `stacks` from `nen repo classify`'s stack; a stack on no row, or a null stack, is not scanned, named | `hanten` § 2a |
| `dependencyAudit.node` | object | required: `stacks` string[], `endpoint` and `vulnEndpoint` https URLs, `ecosystem` string (`npm`), `severityLevels` and `severityFloor` string[] (the floor drawn from the levels), `timeoutSeconds` integer ≥ 1, `registryHosts` host-name string[], `managers{<name>: {lockfiles: string[], format: pnpm-lock\|yarn-lock\|npm-lock\|bun-lock, lockfileMarkers{berry, classic: regex string} (yarn-lock only)}}`; optional, defaulted when absent and refused when malformed: `maxResponseBytes` (33554432), `maxEntries` (500000), `maxDepth` (1000) integers ≥ 1, `unsupportedLockfiles{<file>: manager string}` ({}), `auditConfigKeys{<file>: string[]}` ({}); prose: `run`, `runSemantics`, `resolution`, `failure` strings. Any other non-`$` key exits `2` | what `scripts/dependency_audit_resolve.mts` reads: `packageManager` selects the lockfile, parsed strictly, its registry packages queried against OSV; no package manager runs | `hanten` § 2a, the resolver |
| `secretShapes` | object | `run: nen stage triage` | the secret-shape read over the change set | `hanten` § 2a |
| `builderTouchingWorkflow` | object | `rule`, `waivable: false` | in a consumer repository a diff touching `.github/workflows/**` raises the security scope and requires Feitan's read | `hanten` § 2 |

**Read by.** `hatsu:hanten` § 2a and the Feitan persona ([`claude/agents/feitan.md`](../../claude/agents/feitan.md)). **Rendered where.** Nowhere; read at run time. **May a consumer override it?** No. `waivable` is `false`; a host or stack the table does not cover is reported as not scanned, never substituted.

## `contracts/round_policy.default.json`

**Purpose.** The canon default for the two reviewer-round keys (the ruling of 2026-09-30): `minRounds` and `maxRounds`. They are nen's keys from `v0.21.0` (zheref/nen#240); this file is the skills' default when a target omits one, and nen enforces no ceiling it was not given. `stallMinutes` is nen's and is deliberately absent.

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `minRounds` | non-negative integer | `1` | N: once N rounds stand resolved, no further round is requested | `hatsu:sharingan` § 6; `hatsu:en` |
| `maxRounds` | non-negative integer | `3` | M: the request ceiling | `hatsu:sharingan` § 6; `hatsu:en` |

**May a consumer override it?** Per key, in its own `nen/gates.json` → `round_policy` ([`gates.json.md`](gates.json.md)). A key absent, not a non-negative integer, or leaving N above M takes this file's value, and the run names this file as the source.

## `contracts/pr-composition.json` and `contracts/pr-body.requirements.json`

**Purpose.** The inputs three nen verbs take on every pull request and nen ships none of (zheref/hatsu#171; the declared Nen home remains owed; docs/PROCESS.md records it): the body-check requirements, the gate-derive path sets and the changelog-fragment inputs, declared once so no run retypes them. `pr-body.requirements.json` is the bare `{name, pattern}` array `nen pr body-check --requirements-from` reads, derived from the default process × canon cell in [`contracts/pr-sections.json`](../../contracts/pr-sections.json); `pr-composition.json` holds the rest and says where that array comes from. A catalogue section declaring `content: true` (today `verify`, HR-11) derives a second row, `<id>-content`, carrying `content: true` (nen ignores the key): the heading followed, past blank lines and comments, by something other than the next heading, so an empty section fails both `nen pr body-check` and `scripts/pr_body_sections_check.sh`.

### Keys (`pr-composition.json`)

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `contract` | string | `hatsu.pr-composition/v1` | the shape | `scripts/pr_composition_check.sh` |
| `readers[]` | paths | the declared readers that cite it | every surface that hands the values to a verb, each checked to cite this file | `scripts/pr_composition_check.sh` |
| `bodyRequirements` | object | `file`, `catalogue`, `defaultKind`, `defaultFamily` | default fixture requirements, the section catalogue and fragments, and the cell the fixture derives from; actual runs resolve their own array | `hatsu:shibari` § 4, `hatsu:tensho` § 5 |
| `gateDerive.<owner/name>` | object | `policyPaths[]`, `processPaths[]`; two rows, `zheref/hatsu` and `zheref/nen` | a canon repository's two `nen gate derive` sets, passed comma-joined; `zheref/hatsu`'s process set includes `contracts/` and `templates/` (the maintainer's ruling of 2026-10-13); `zheref/nen`'s row carries its basis in its own `$comment` (zheref/hatsu#334; the maintainer's ruling of 2026-10-20, [`docs/ROSTER.md`](../ROSTER.md) § *Rulings of 2026-10-20 — zheref/nen's gate path sets*); a canon repository with no row has none, and the run asks | [`docs/WORKFLOW.md`](../WORKFLOW.md) § *Gate derivation* |
| `changelogFragment` | object | `specPaths[]`, `fragmentDir` (`changelog.d`), `headChangelog` (`CHANGELOG.md`), `directSection {when, optOut}` | `nen changelog fragment-required`'s inputs, and the one opt-out line, for a pull request whose own diff changes `CHANGELOG.md` | `hatsu:shibari` § 4, `hatsu:tensho` § 5, `hatsu:jujisho` § 6, `docs/PR-SECTIONS.md` |

**Validated by.** The `pr-composition-guard` and `pr-sections-guard` lanes: every catalogue id, cell, template and job ownership, the fixture array against its declared default cell, the Gate derivation section against the declared sets, and no literal copy of a set anywhere in the canon prose.

**May a consumer override it?** No. A consumer is `G2` by role and `nen gate derive` is not run there; a canon repository's sets are a row here, and this file lives only in Hatsu, so the row for another canon repository (zheref/nen, zheref/bankai-handbooks) is written by a Hatsu PR at Hatsu's `G4` — the writer [`WORKFLOW.md`](../WORKFLOW.md) § 4 step 3 names once the run has asked. `zheref/nen`'s row was written that way (zheref/hatsu#334); no row is seeded for any other.

## `contracts/issue-sections.json`

**Purpose.** The shape of an issue Hatsu files (ROSTER HR-4; SDD plan piece P6): the sections each kind carries, which must be present and non-empty, the `AC-`, `SC-`, `AS-` and `OQ-` row shapes, and the vague-adjective and technology-term lists an acceptance row is read against. `templates/issue-body/<kind>.md` is the body each kind starts from. nen reads it from `0.26.0` — `nen issue body-check --requirements-from <this file>` and `nen issue questions --requirements-from <this file>` (zheref/nen#476, zheref/nen#477); the interim `scripts/issue_body_check.mts` is retired (zheref/hatsu#423).

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `contract` | string | `hatsu.issue-sections/v1` | the shape | `nen issue body-check`, `nen issue questions` |
| `sections.<id>` | object | `heading`, optional `rows`, optional `none` | one level-2 heading; `rows` names its row shape; `none` admits a lone `None.`; `requirements` is Akatsuki's acceptance heading, allowed beside Acceptance criteria on an `epic` only (its rows `AC-{epic}-{nnn}`, the Acceptance rows `AC-{n}`, an id repeated across the two a duplicate), optional on `epic` and absent on every other kind | the same; `nen issue criteria` reads `requirements` rows on any body, `body-check` only under `--kind epic` |
| `common[]` | section ids | the eight every kind shares | what a body checked without `--kind` must carry | the same |
| `kinds.<kind>` | object | `template`, `required[]`, `optional[]`; kinds `product`, `defect`, `machinery`, `canon-gap`, `epic` | the template path and the required and optional sections | the same, and the `issue-shape` lane's template check (`scripts/issue_sections_fixture.mts`) |
| `rows.<shape>` | object | `pattern`, `prefix`, and for `success` `measure`, for `question` and `acceptance` `resolvedPattern` | a row's shape, and what makes a list item claim to be one; `acceptance` admits `AC-{n}` and Akatsuki's `AC-{epic}-{nnn} (P{n})`, its resolved form a struck `withdrawn` row (zheref/hatsu#411) | the same |
| `vagueAdjectives[]`, `technologyTerms` | word lists, patterns | as shipped | the words and patterns reported in an acceptance row | the same |

**Read by.** `hatsu:file` § 4, `hatsu:emperor-time` § 6, `hatsu:build` § 2 and `hatsu:futon` § 2 (kazaana through futon), always through the two nen verbs; `nen pr converge` and `nen issue criteria` read its acceptance sections and prefix for the `- AC-{n}:` rows a closing issue carries (Akatsuki's epic-scoped and withdrawn rows read once nen takes them from this file, zheref/nen#519 and zheref/nen#553) (HR-11; shibari § 4, en §§ 4–5, rikugan § 3 pass it to `converge` through `--catalogue`, nen 0.28's name for the flag); no `coverage` block is declared, so nen's defaults apply. **Validated by.** The `issue-shape` lane. **May a consumer override it?** No; the verbs take any caller's catalogue through `--requirements-from`, but Hatsu's skills pass this file.

**The check, as every caller runs it** (the skills cite this paragraph rather than restate it). A filed issue is read by `--ref`; a draft by `--body-file <absolute path>`, with `--kind <kind>` where the kind is known (a body checked with no `--kind` is read against `common`):

```bash
nen issue questions  --ref <CODE>#<N> --target <owner/name> --requirements-from "$hatsu_root/contracts/issue-sections.json" --json
nen issue body-check --ref <CODE>#<N> --target <owner/name> --requirements-from "$hatsu_root/contracts/issue-sections.json" [--kind <kind>] --json
```

`questions` decides the stop: `counts.open` above `0` is the caller's open-question rule (build § 2's G1 `next: clarify`, futon § 2's skip, parked `needs-clarification` with the queue continuing (`R-2026-10-23-02`, WORKFLOW § *Idle batches* rule 9), file § 4's and emperor-time § 6's plan row); its exit `1` is an issue that could not be read, never "no questions" (in a batch, skipped as `g5-shape-unread` and the queue continues). `body-check` lists: exit `0` no miss, exit `1` the `misses[]` it names (each fixed in a draft or listed, never a skip on its own; an exit `1` with no `misses[]` is an unread issue), `advisories[]` reported. Exit `2` on either is wiring — a malformed catalogue or a usage error — and stops the caller's step, never read as a pass; in a batch it stops the queue statement as one named G5, never a skip per issue.

**The nen verb reads this shape (route chosen: nen adapts).** zheref/nen#498 as reviewed at `48e9fc0` parses a different catalogue grammar (`sections` an array of `{id, title, level, content[], rows}`, `kinds` a map of kind to section ids) and has no optional sections, `noneText`, `technologyTerms` or dated `resolvedPattern`. Hatsu keeps its contract as is: nen `0.26.0`'s verb reads `hatsu.issue-sections/v1` through `--requirements-from` — object `sections`, `kinds.<kind>` with `required[]` and `optional[]`, the top-level `rows`, `noneText` and `technologyTerms` (the same misses as the script on HA#415 and HA#131, `docs/ab/futon.md` § 2026-10-22). `scripts/issue_body_check.mts` is retired under zheref/hatsu#423, and the `issue-shape` lane now runs nen's verbs over this file. Where they differ from the retired script: a vague adjective or a technology term on an acceptance row is an advisory (`advisories[]`), never a miss, and an open `OQ-{n}` row is counted by `nen issue questions`, never a body-check miss.

## `contracts/hanten-findings.schema.json`

**Purpose.** The JSON Schema (`$id` `hatsu.hanten.findings/v0.1`) of the findings record `hatsu:hanten` § 5 writes per effort at `<reports.dir>/hanten/<branch-slug>.json` (ROSTER HR-10; SDD plan piece P7): `scopes[]`, `findings[]` and `reports[]`; a finding's six reviewer fields plus `id`, `scope`, `persona` and `disposition`.

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `$defs.disposition.state` | enum | `fixed` · `pushed-back` · `deferred` | how a finding settled (hanten § 6) | `hatsu:hanten` § 6 |
| `$defs.disposition.detail` | string | required and non-empty for `pushed-back` and `deferred` | the cited reason, or what outlives the branch | the same |
| `$defs.disposition.tracked` | `<CODE>#<N>` or `<owner>/<name>#<N>` | required for `deferred` | the tracked item a deferral names | the same |
| `$defs.finding` (rule `CON-{n}`) | conditional | severity `critical`; state `fixed` or `deferred` only | HR-10 as amended by HR-337: critical by shape, never pushed back; an `HR-{n}` rule is critical only on a ruled row, which `hanten` § 6 holds until the status-aware check [zheref/hatsu#466](https://github.com/zheref/hatsu/issues/466) lands | the same |

**Validated by.** The `criteria` lane's fixture holds its structural invariants. Registration with `nen schema check` is owed to nen, which validates only `nen/` declarations at the pin. **May a consumer override it?** No.

## `contracts/reference.gates.json`

**Purpose.** The frozen reference repository (`<reference-repo>`, [`docs/PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md)) ships no gates file of its own and `nen pr ready` never falls back to a built-in reviewer set, so judging a PR there needs `--gates` pointed at a file carrying its identities. This is that file, a copy of nen's own shadow-window-validated fixture taken at nen `v0.1.0`.

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `version` | integer | `1` | the gates schema version | `nen pr ready --gates` |
| `reviewers[]` | reviewer objects | five identities, with nen's optional `review_check_pattern`, `round_check_pattern`, `enrolment_check_pattern`, `bounded_policy_exempt`, `approves_when_posted_at_head`, `delivery_holistic_pass` | the reference repository's reviewer vocabulary | `nen pr ready` |
| `default_approvers`, `base_reviewers`, `delivery` | as in [`gates.json.md`](gates.json.md) | the reference repository's own values | its approval set and delivery shape | `nen pr ready` |

**Read by.** `hatsu:pr-state` § 2, `hatsu:en`, `hatsu:getsuga`, `hatsu:backlog-state`, `hatsu:tensho`, always as the absolute `--gates "$hatsu_root/contracts/reference.gates.json"` (a relative `--gates` resolves against `--repo`), and only for that one repository. A repository that ships its own `nen/gates.json` needs no `--gates` at all. **May a consumer override it?** No, and it is never reused as another repository's reviewer set (`hatsu:senkei`).

## `contracts/skill-shape.json`

**Purpose.** The skill shape [`docs/PROCESS.md`](../PROCESS.md) § *The skill shape* states, as data: the Residue, Authority and Hard limits requirements every touched `SKILL.md` is checked against through `nen pr body-check`, and the reasoned exemption list. Read by `scripts/skill_shape_check.mts` (lane `skill-shape-guard`); never by a consumer. Keys, findings and the coverage checks beside it: [`skill-shape.json.md`](skill-shape.json.md).

## `contracts/prose.lint.json` and `contracts/prose.lint.baseline.json`

**Purpose.** The canon prose lint's rules, `PL-01` … `PL-12`, and the shrink-only baseline of the findings the tree carried when the guard landed ([HR-13](../ROSTER.md#hr-13)). Read by `scripts/prose_ambiguity_check.mts` (lane `canon-lint`); never by a consumer. Keys, the exemptions and who reads it: [`prose.lint.json.md`](prose.lint.json.md).

## `hooks/hooks.json`

**Purpose.** Hatsu's three harness hooks, the two things a skill cannot do (a notification after the model has stopped, a reflex refusal before a push lands) plus the host binding of the pinned nen. Neither is a nen-owned step; every deterministic step the skills take stays a nen verb. The scripts are POSIX sh, use no `jq`, `yq` or `python`, and fail open, the guard excepted.

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `description` | string | the rationale, the guard's parsing rules, the session-start purposes | the authority on the file | a reader |
| `hooks.SessionStart[]` | `{hooks: [{type: command, command, args, timeout: 60, statusMessage}]}` | `${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh` | step 0 binds the contract-pinned nen on the host (`scripts/nen_global.sh`, opt-out `HATSU_NEN_GLOBAL=0`); on the source copy, the warm-up reminder; on a mirrored copy in an adopted consumer, the mirror refresh through `scripts/surface_bootstrap.sh`, logged to `.nen/session-start.log` | the harness |
| `hooks.Stop[]` | the same shape, `timeout: 15` | `${CLAUDE_PLUGIN_ROOT}/hooks/stop-bell.sh` | rings the bell (an OS notification and a sound) once per stop marker `hatsu:jutaisho` drops — every per-gate marker `nen stop list` names (nen 0.27 on), else `.nen/last-stop.json` — and clears each it rang ([WORKFLOW § *The effort's ledgers*](../WORKFLOW.md#the-efforts-ledgers--phases-usage-and-sessions), the homes) | the harness; `jutaisho` § 3 |
| `hooks.PreToolUse[]` | `{matcher: Bash, hooks: [...]}`, `timeout: 10` | `${CLAUDE_PLUGIN_ROOT}/hooks/guard-base-branch.sh` | refuses a `git commit` or `git push` while the directory git targets stands on `branch.base`; parses the command (wrappers, quoting, heredocs, `-C`, `--git-dir`) rather than matching a substring, and fails closed on the five forms it cannot read | the harness; `aka`, `murasaki` cite it as the first line |

**Rendered where.** Per surface by `nen surface mirror generate --hooks hooks/hooks.json --hooks-root <root>`: Claude Code reads this file in place; Codex `surfaces/codex/hooks.json` (`SessionStart`, `Stop`, `PreToolUse` with `permissionDecision: deny`), named by `.codex-plugin/plugin.json` → `hooks`; Cursor `surfaces/cursor/.cursor/hooks.json` (`sessionStart`, `stop`, `beforeShellExecution` with `permission: deny`); Antigravity `surfaces/antigravity/hooks.json` (`PreInvocation`, `Stop`, `PreToolUse` on `run_command` with `decision: deny`). The roots are the ones `scripts/surface_mirror_check.sh` expects; any other reads `hand-edited: hooks.json` ([`docs/using/mirrors.md`](../using/mirrors.md) § 3).

**May a consumer override it?** Not the hooks. What tunes them lives in the consumer's `nen/workflow.json`: `notifications.rungs|sound|turn` for the bell, `branch.base` for the guard; `HATSU_NEN_GLOBAL=0|false|no|off` (or `~/.config/hatsu/nen-global` saying `off`) opts the host binding out. A placed `.codex/hooks.json`, `.cursor/hooks.json` or `.agents/hooks.json` is marker-owned and refreshed by the warm-up; the Codex plugin serves its own, so the pack removes a placement's copy.

## `.claude-plugin/plugin.json`

**Purpose.** The Claude Code plugin manifest: the plugin's name, version and what it points at. Claude Code keys its plugin cache on `version`, which is why `scripts/plugin_bump_check.sh` fails a PR that changes plugin-visible files without bumping it; `scripts/hatsu_root.sh` recognises a Hatsu checkout by this file naming `hatsu`.

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `name`, `displayName` | string | `hatsu`, `Hatsu Agent Team` | the plugin identity | the host; `hatsu_root.sh` |
| `version` | string | semver; the stamp every generated mirror carries | the version the cache is keyed on | the host; `plugin_bump_check.sh`; `nen surface mirror generate --manifest … --stamp` |
| `description`, `author{name,url}`, `repository`, `keywords[]` | strings, object, list | the public description; `zheref` and `https://github.com/zheref/hatsu` | the listing | the host |
| `agents[]` | paths | `./claude/agents/<persona>.md`, twelve at the pinned build | the personas the host loads | the host; `plugin_bump_check.sh` (what counts as plugin-visible) |
| `commands`, `skills` | paths | `./claude/commands/`, `./claude/skills/` | where the host reads commands and skills | the host |

**Rendered where.** The version is stamped into every `surfaces/<s>` file and into Antigravity's generated `plugin.json`. **May a consumer override it?** No.

## `.codex-plugin/plugin.json`

**Purpose.** The Codex plugin overlay: the same skills, the generated Codex hooks file, and the interface block Codex's listing shows. Held at the Claude manifest's `version` by `scripts/plugin_bump_check.sh`.

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `name`, `version`, `description`, `author`, `repository`, `license`, `keywords` | as above; `license: MIT` | the plugin identity on Codex | Codex |
| `skills` | path | `./claude/skills/` | the one source, read in place | Codex |
| `hooks` | path | `./surfaces/codex/hooks.json` | the generated Codex hooks | Codex |
| `interface` | object | `displayName`, `shortDescription`, `developerName`, `category: Productivity`, `websiteURL` | the listing | Codex |

**May a consumer override it?** No. The Codex plugin is installed from the checkout as a marketplace (`codex plugin add hatsu@hatsu`); what the checkout holds is what the surface serves.

## `.claude-plugin/marketplace.json`

**Purpose.** The marketplace both Claude Code and Codex read when the checkout is registered as one: the owner, the long description, and one plugin entry pointing at the repository root.

### Keys

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `name` | string | `hatsu` | the marketplace name (`hatsu@hatsu` is plugin `hatsu` from marketplace `hatsu`) | Claude Code, Codex |
| `owner{name,url}` | object | `zheref`, `https://github.com/zheref` | the owner | the host |
| `metadata.description` | string | the long description, with the skill count and the nen pin as prose | the listing | the host |
| `plugins[]` | `{name, source, description}` | one entry, `source: ./` | the plugin this marketplace serves | the host |

**May a consumer override it?** No. On Claude Code the first-party install retires the shadowing `hatsu@hatsu` cache entry in favour of the in-place `~/.claude/skills/hatsu` link; the marketplace remains what Codex installs from ([`docs/using/README.md`](../using/README.md) § *The four surfaces, compared*).

## Example

Illustrative: how a consumer's own files point at these registries without copying them. Nothing below is a plugin file.

```json
// nen/workflow.json (consumer): the three knobs that tune plugin-owned data
{
  "models": { "claude": { "deep": "opus", "fast": "sonnet" }, "codex": { "deep": "sol", "fast": "terra" },
              "cursor": { "deep": "grok", "fast": "composer" }, "antigravity": { "deep": "pro", "fast": "flash" } },
  "direct": { "publish": "none", "$publish": ["none", "label", "label+comment"] },
  "notifications": { "rungs": ["push", "os", "sound"], "sound": "Glass", "turn": "rung1" }
}
```

```json
// nen/gates.json (consumer): the one plugin default a consumer overrides per key
{ "round_policy": { "stallMinutes": 30, "minRounds": 1, "maxRounds": 3 } }
```

```bash
# Where the skills read the plugin's copies from, on every surface
"$hatsu_root/scripts/permissions_pack.sh" --surface <claude-code|codex|cursor|antigravity> --render
nen classify labels  --taxonomy "$hatsu_root/contracts/classify.taxonomy.json"
nen direct registry  --registry "$hatsu_root/contracts/direct.registry.json"
"$hatsu_root/scripts/config_values.sh" diagnose --repo .
```

## When a skill needs a value that is not set

- **A plugin registry is missing or unreadable at `$hatsu_root`.** The reading skill stops with the path named: `permissions_pack.sh` exits `2` (`no permissions source`), `nen classify labels` and `nen direct registry` are the capability probes `hatsu:classify` § 2 and `hatsu:direct` § 3 run first, `config_values.sh` refuses by name. Nothing improvises the data (`nen/contract.json`, `no_improvised_fallback`).
- **A generated mirror has not been produced.** `permissions_pack.sh` places nothing for Codex or Cursor and says to run `nen surface mirror generate` first; `scripts/surface_mirror_check.sh` reads `missing`.
- **A consumer value the registry defers to is absent.** `direct.publish` absent reads `none`; a `models.<surface>.<tier>` the consumer has not spelled makes the restart line unfillable, which `hatsu:direct` § 5 says rather than guessing; `round_policy` keys take the canon default; the catalogue's `need --skill <s>` lists the rest and `hatsu:ten` § 6 asks through the picker, sets, and resumes.
- **A scan row has no entry for this host or stack.** Not scanned, named, never clean (`scans.json`).
- **A hook's input is unreadable.** The bell and the session-start refresh fail open and stay out of the way; the guard fails closed only where a write token stands beside a command it cannot read.

## Sources

- [`../../contracts/permissions.json`](../../contracts/permissions.json) · [`../../scripts/permissions_pack.sh`](../../scripts/permissions_pack.sh) (header and usage)
- [`../../contracts/classify.taxonomy.json`](../../contracts/classify.taxonomy.json) · [`../../contracts/direct.registry.json`](../../contracts/direct.registry.json) · [`../DIRECT-MATRIX.md`](../DIRECT-MATRIX.md) · [`../../scripts/direct_matrix_doc.sh`](../../scripts/direct_matrix_doc.sh)
- [`../../contracts/config-catalogue.json`](../../contracts/config-catalogue.json) · [`../../scripts/config_values.sh`](../../scripts/config_values.sh)
- [`../../contracts/scans.json`](../../contracts/scans.json) · [`../../contracts/round_policy.default.json`](../../contracts/round_policy.default.json) · [`../../contracts/reference.gates.json`](../../contracts/reference.gates.json)
- [`../../hooks/hooks.json`](../../hooks/hooks.json) · [`../../hooks/session-start.sh`](../../hooks/session-start.sh) · [`../../hooks/stop-bell.sh`](../../hooks/stop-bell.sh) · [`../../hooks/guard-base-branch.sh`](../../hooks/guard-base-branch.sh)
- [`../../.claude-plugin/plugin.json`](../../.claude-plugin/plugin.json) · [`../../.claude-plugin/marketplace.json`](../../.claude-plugin/marketplace.json) · [`../../.codex-plugin/plugin.json`](../../.codex-plugin/plugin.json) · [`../../scripts/plugin_bump_check.sh`](../../scripts/plugin_bump_check.sh)
- [`../using/mirrors.md`](../using/mirrors.md) §§ 1–4 · [`../PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md) · [`../WORKFLOW.md`](../WORKFLOW.md) § 2, § 4
- [`../../claude/skills/hanten/SKILL.md`](../../claude/skills/hanten/SKILL.md) § 2 · [`../../claude/skills/classify/SKILL.md`](../../claude/skills/classify/SKILL.md) § 2 · [`../../claude/skills/direct/SKILL.md`](../../claude/skills/direct/SKILL.md) §§ 3–7 · [`../../claude/skills/sharingan/SKILL.md`](../../claude/skills/sharingan/SKILL.md) § 6 · [`../../claude/skills/pr-state/SKILL.md`](../../claude/skills/pr-state/SKILL.md) § 2 · [`../../claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) §§ 2, 6d · [`../../claude/skills/ten/SKILL.md`](../../claude/skills/ten/SKILL.md) §§ 5–6 · [`../../claude/skills/jutaisho/SKILL.md`](../../claude/skills/jutaisho/SKILL.md) § 3 · [`../../claude/skills/senkei/SKILL.md`](../../claude/skills/senkei/SKILL.md)
