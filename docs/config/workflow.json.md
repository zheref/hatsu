# `nen/workflow.json` — how the roster works in this repository

> **Lives in** the consumer repository (Hatsu carries its own at [`nen/workflow.json`](../../nen/workflow.json)) · **Written by** `nen scaffold init` (the initial file, from nen's template), the owner (its values are the consumer's once set), [`scripts/config_values.sh fill`](../../scripts/config_values.sh) on `hatsu:tenkai apply` (absent defaults and `$<key>` option annotations) and `config_values.sh set` (one chosen value, after the question); `hatsu:jusshin` writes `runners` on the maintainer's answer · **Validated by** `nen schema check` (row `nen/workflow.json`; a malformed key is a `FAIL` by pointer) · **Authority** [docs/WORKFLOW.md § 2](../WORKFLOW.md#2--nenworkflowjson--every-key)

## What it decides

This is the **policy half** of the two-file model: `nen/contract.json` → `project` says what nen executes, this file says what the workflow decides with. Branch shape, which declared verbs run per iteration, the coverage ladder, where reports go and what is kept, how loud the bell is, which trailers a commit may carry, the readiness monitor's cap, the run profile, the model tiers per surface, review routing, the release unit, the advance-go gate and whether `hatsu:direct` publishes. **Every value here is a policy default, not a fact about the machine.**

Nen validates the whole file and reads a few slices itself: `nen commit format` and `nen wc squash` take `commits.allowedAttributionTrailers`, `nen shu coverage --touched` takes the `coverage` ladder, `nen review scopes` takes `review.scopes`, `nen report render --variant` takes `reports.sections`, `nen release unit-check` and `nen pr merge --release-unit` take `release.unitPaths`, `nen parse futon` takes `futon.advanceGo`, the `nen runner` family takes `runners`. Everything else is read by the skills, which is a read rather than a residue: nen validates the file, it does not hand the values out. In WORKFLOW.md's words, **a wrong `workflow.json` produces a correct command run at the wrong moment, which is silent**; a wrong `project` block fails loudly. Almost every skill depends on some key here, from `hatsu:breath` cutting the branch to `hatsu:mugetsu` reading the advance-go gate.

## Keys

The `$schema` is `nen.workflow/v0.1`. Every `$comment` key is the repository's own prose, preserved verbatim by nen's loader and read by nothing in nen. A `$<key>` sibling (`"$autoEn": "one of: true | false"`) is the option annotation `config_values.sh fill` writes beside a fixed-set value; nen treats every `$`-prefixed key as metadata. The defaults below are the catalogue's canon defaults, which are what a reader applies when the key is absent; Hatsu's own values differ where noted.

### `branch`

The shape of an effort's branch and the trunk it is cut from.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `template` | open | **`{model}/{persona}/{descriptor}`** | How `hatsu:breath` names a branch: `{model}` the model alias the actor runs on (never a version), `{persona}` the roster persona, `{descriptor}` a short kebab noun phrase | `hatsu:breath` (cuts it), `hooks/guard-base-branch.sh` (names it in the refusal) |
| `base` | open | **`main`** | The trunk: breath fast-forwards it, ao catches up from it, shibari opens against it, getsuga cuts from it, kagutsuchi proves freshness against it, and the base-branch hook refuses a commit or a push on it | `hatsu:breath`, `hatsu:ao`, `hatsu:murasaki`, `hatsu:shibari`, `hatsu:getsuga`, `hatsu:kagutsuchi`, `hatsu:ten`, `hooks/guard-base-branch.sh` |

### `iteration`

The declared verbs the loop runs, three times over, for three different questions: `hatsu:breath` on the fresh tip (*was the base sound*), `hatsu:rasengan` as the author's inner loop (*does what I just wrote work*), `hatsu:kokusen` over the finished tree before every commit (*is the tree I am about to record green*). Each entry is the **name of a declared verb**, run as `nen shu <check> --lane <lane>`; a verb the lane seats as unsupported is exit `4` and its seat is quoted, not worked around.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `checks` | open (string[]) | verb names; **`["build"]`**. Hatsu's own is `["lint"]` | The checks every turn proves. `lint` here is `hatsu:gyo`, the linting process on every Ren turn | `hatsu:breath`, `hatsu:rasengan`, `hatsu:kokusen`, `hatsu:gyo`, `hatsu:murasaki` |
| `lane` | string | a key of `project.lanes`; derived from `project.defaultLane` when absent | The lane the checks run on, passed through as `--lane` | the same phases |

### `tests`

The project-wide suites `hatsu:kotoamatsukami` runs at `hatsu:mukai` when the change can affect them. **An empty `required` is a statement, not an omission**: with `required` and `extra` both empty the verdict is `not applicable — no tests configured`, never green and never a G5. `hatsu:tsukuyomi` does not read this block; it runs the explicit scoped lane that covers the changed executable.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `required` | open (string[]) | declared verb names; **`["test"]`**. Hatsu's own is `[]` | The suites that must pass; red is a G5 stop inside mukai | `hatsu:kotoamatsukami` |
| `extra` | open (string[]) | declared verb names; **`[]`** | Further suites (`ui-test`, an integration lane) considered after `required` and reported separately | `hatsu:kotoamatsukami` |

### `coverage`

The ladder `hatsu:byakugan` reports against, in percent line coverage of **touched** files. Three numbers rather than one, because a single threshold turns into either a gate that blocks honest work or a number nobody looks at. **The bar is never lowered to clear it**; a repository that cannot honestly reach `minimum` is a G5, not a smaller number. `nen shu coverage --touched --base <ref>` reads the ladder itself when no `--threshold` is given, prints a `ladder:` line and a `band` per row, and never gates.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `minimum` | open (integer) | **`80`** | The stop: a touched file under it is a G5 | `hatsu:byakugan`, `nen shu coverage --touched` |
| `recommended` | open (integer) | **`85`** | The band byakugan aims for and reports against | `hatsu:byakugan`, `nen shu coverage --touched` |
| `ideal` | open (integer) | **`90`** | The band worth saying out loud when it is reached | `hatsu:byakugan`, `nen shu coverage --touched` |
| `scope` | open | **`touched`** (the only scope nen measures today; another is a G4 change plus a nen capability) | Line coverage of the files `git diff --name-only origin/<base>...HEAD` names, not the repository total | `hatsu:byakugan` |

### `launch`

Which `project.launch` target `hatsu:amaterasu` starts at the end of a turn, and which it falls back to when the default's device is absent.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `default` | open | a key of `project.launch`; **`null`**, and null is an answer | The target every turn starts. With no `project.launch` declared, `null` is the no-launch case: amaterasu records `no launch target declared; skipped` and does not ask. With targets declared and `null` here, each turn asks | `hatsu:amaterasu`, `hatsu:ren` |
| `fallback` | open | a key of `project.launch`; **`null`**, and null is an answer | The target amaterasu falls back to when the default's device is not connected (reported by name); `null` means it says so and stops | `hatsu:amaterasu` |

### `deploy`

Read by `hatsu:kagutsuchi` § 1 (the maintainer's ruling of 2026-09-29, zheref/hatsu#146); from nen `v0.21.0` nen knows the key too and `nen schema check` FAILs a `defaultTarget` naming an undeclared target or one not marked `project.targets.<name>.nonProduction: true` (zheref/nen#300), so a default target carries that flag as well as a non-production `why`. `nen shu deploy` is unchanged: the skill always passes `--target` explicitly, so *nen never chooses where a build goes* stays true of nen; the choice lives here.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `defaultTarget` | open | a key of `project.targets` whose `why` reads non-production; **`null`**, and null is an answer | The destination an untargeted `hatsu:kagutsuchi` sends to. A typed target always overrides it and the report says which source the target came from (`typed` or `workflow.json → deploy.defaultTarget`). A default naming a store or the live environment is refused by `config_values.sh set` and by kagutsuchi; G3 (`hatsu:mugetsu`) is unchanged. `null` means the target is typed on each call (`missing-maintainer-choice`) | `hatsu:kagutsuchi` |

### `reports`

Where reports are written and what is kept. `dir` is git-ignored for the same reason a build output is. **`retain: final-only` governs what is KEPT, not whether a working file exists** (the maintainer's ruling of 2026-09-09): only the final current-head readiness report at the G2/G4 human gate gets a dated file under `dir`; per-turn and landing reports are published to the conversation as an artifact or, on a surface that cannot publish one, opened from the transient `<dir>/current.html`, which every render overwrites.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `dir` | open | **`Reports`** | The only directory a report is ever written to; `hatsu:tenkai` git-ignores it | `hatsu:spiritual-message`, `hatsu:en`, `hatsu:backlog-board`, `hatsu:rikugan` |
| `retain` | open | **`final-only`** | The retention rule: the `final` variant alone gets a dated file, `<dir>/<YYYY-MM-DD>-<effort>.html` | `hatsu:spiritual-message`, `hatsu:rikugan` |
| `template` | enum | `spiritual-message` · `rikugan`; **`spiritual-message`** | `templates/<name>.html` in the Hatsu plugin the turn report renders with | `hatsu:spiritual-message` |
| `captures` | open | **`Reports/captures`** | Where visual evidence captures land before they are inlined as data URIs | `hatsu:spiritual-message`, `hatsu:kotoamatsukami` |
| `timeZone` | string | an IANA zone (`Etc/GMT+5` keeps a clock without naming a city); absent means the host's zone, derived at run time and never written by `fill` | The zone every report's clock is said in; `scripts/report_time.sh --tz` takes it. The zone name is printed on every page, so a fixed-offset zone is the privacy option | `hatsu:spiritual-message`, `hatsu:black-voice`, `scripts/report_time.sh` |
| `sections.<variant>.template` | string | `spiritual-message` for `turn`, `turn-fast`, `landing`; `rikugan` for `final`, `register` | Which template this variant renders | `nen report render --variant` |
| `sections.<variant>.blocks` | string[] | block names, required and non-empty — nen refuses the whole file otherwise (WORKFLOW § 2 → `reports`) | The blocks this variant renders, injected as `sections.<block>` presence flags for the template. Every value inside a block is model-written; only the flags come from here | `nen report render --variant`, `hatsu:spiritual-message`, `hatsu:backlog-board` § 3, `hatsu:rikugan` |

The five variants Hatsu declares, and who renders them (the maintainer's ruling of 2026-09-19, zheref/hatsu#89):

| Variant | Template | Blocks in Hatsu's file | Rendered by |
|---|---|---|---|
| `turn` | `spiritual-message` | `masthead`, `tally`, `desk`, `lastTurn`, `landed`, `delta`, `evidence`, `launch`, `decisions` | `hatsu:spiritual-message`, every Ren turn |
| `turn-fast` | `spiritual-message` | `masthead`, `tally`, `desk`, `lastTurn` | `hatsu:spiritual-message`, the same step under profile `fast` |
| `landing` | `spiritual-message` | the `turn` blocks plus `spend` and `prBody` | `hatsu:spiritual-message`, at `hatsu:mukai`'s landing and `hatsu:en`'s first step |
| `final` | `rikugan` | `masthead`, `tally`, `desk`, `register`, `spend`, `legend` | `hatsu:rikugan`, through `hatsu:backlog-board` § 3; the one dated report |
| `register` | `rikugan` | the same six | `hatsu:backlog-board`, `hatsu:futon`, `hatsu:backlog-loop`, `hatsu:rikugan as register` |

### `notifications`

`hatsu:jutaisho`'s ladder, innermost first. **A rung absent from the list is not rung.** A gate always rings everything `rungs` lists whatever `turn` says; `turn` can only withhold an escalation `rungs` already grants, never conjure one it withholds. `hooks/stop-bell.sh` rings rungs 2 and 3 off `.nen/last-stop.json`; nen validates the keys and fires nothing itself.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `rungs` | subset | any of `push`, `os`, `sound`; **`["push", "os", "sound"]`** | Which escalation rungs may fire: `push` the surface's own turn-complete signal, `os` an OS notification, `sound` a system sound | `hatsu:jutaisho`, `hatsu:en`, `hooks/stop-bell.sh` |
| `sound` | open | a system sound name; **`Glass`** | `/System/Library/Sounds/<sound>.aiff` on macOS, played through `afplay` | `hatsu:jutaisho`, `hooks/stop-bell.sh` |
| `turn` | enum | `rung1` · `all`; **`rung1`** (what an absent key reads as) | How loud an ordinary turn is, one with no gate: `rung1` rings only the first rung `rungs` lists, `all` rings every rung it lists. In the `nen.workflow/v0.1` shape, refused by pointer on anything else | `hatsu:jutaisho`, `nen schema check` |

### `commits`

Which attribution trailers a prospective commit may carry. The maintainer's ruling of 2026-09-12: a commit carries exactly the canonical persona or plane key that truthfully identifies the responsible actor; model, surface, runtime, session and generated-credit attribution are forbidden. An **attribution key** is a trailer key ending in `-by` or `-with` (case-insensitive) or one `forbiddenTrailers` lists; `Closes`, `Fixes`, `Refs` are ordinary trailers and never compared. An attribution key outside the allow-list on a commit a Hatsu step just wrote is a harness injection, row `injected-attribution-trailer`.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `allowedAttributionTrailers` | string[] | Hatsu's own: `["Hatsu-Agent", "Akatsuki-Agent"]`; nen's built-in default may differ, so the catalogue lists no default | The only attribution keys a commit may carry | `nen commit format --repo`, `nen commit write`, `nen wc squash` (exit `2` on a key outside it; exit `3` when a hook injected one after the write), `hatsu:kokusen` § 5, `hatsu:aka` § 4 and § 7, `nen scaffold init` (generates the `commit-msg` hook from it) |
| `forbiddenTrailers` | string[] | Hatsu's own: `Co-Authored-By`, `Claude-Session`, `Signed-off-by`, `Generated-by`, `Generated-with`, `Reviewed-by` | Keys named as attribution keys beyond the `-by`/`-with` rule | the same verbs and skills |
| `runTrailer` | string or null | **`null`**; nen's key | A separate run-identifier trailer the scaffolded hook may additionally require; a run identifier is never itself an attribution claim, so it is not folded into the allow-list | `nen scaffold init` |

### `monitor`

`hatsu:en`'s acting-cycle cap and its poll interval. **The cap is grammar, not a default**: a watch loop with no cap does not run, and from nen `0.7` `nen loop iterate --line "<task> until <condition> up to <N>"` holds the caller to the cap its own line states, refusing a claim past it. The ledger is `.nen/loop/<id>.json`, keyed on the pull request, so a re-invoked landing resumes the same count. Quiet polls spend no cycle.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `maxCycles` | open (integer) | **`20`** | En's acting-cycle cap on one PR. A different number from `nen/gates.json` → `round_policy.maxRounds`, the reviewer-round cap | `hatsu:en`, `hatsu:senkei`, `hatsu:izanagi` (through `nen loop iterate`) |
| `pollSeconds` | open (integer) | **`300`** | Seconds between En's quiet observations of a pending PR | `hatsu:en`, `hatsu:sharingan` |

### `profile`

The run profile `hatsu:ren` § 2a reads (zheref/hatsu#93). A turn names one with `--profile <p>` or the words *fast turn* / *thorough turn*; a value outside `allowed` is refused with the list quoted. **A landing always runs thorough**, whatever the turns before it named. Validated by `nen schema check` from nen `v0.13.0`.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `default` | enum | `fast` · `standard` · `thorough`; absent, nen derives it from `allowed` (`standard` when allowed lists it), so `fill` annotates it and never writes a default | The profile a turn runs under when none is typed: `fast` is steps 1 to 3, a `turn-fast` page, launch skipped and coverage deferred to mukai; `standard` is today's turn; `thorough` adds the impacted suites every turn | `hatsu:ren`, `hatsu:amaterasu` |
| `allowed` | subset | any of `fast`, `standard`, `thorough`; **all three** | Which profiles a typed one may name | `hatsu:ren` |

### `models`

Four **tiers** per surface, and a role maps to a tier rather than to a model. A pinned model version is a pin that rots; a tier survives every model release. Hatsu runs first-party on four surfaces and the matrix has one column per surface because **the tier is the policy and the alias is the surface's answer to it**. Two rules ride on it: a subagent is never raised on the `frontier` tier (that is where the maintainer's own conversation lives), and every subagent is titled `<skill> · <persona> · <model alias>`. This block is structural, the repository's own shape, so the catalogue lists no default for it.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `rule` | string | Hatsu's own: *latest alias only, never a version; subagents never on the frontier tier* | The rule the block is read under | prose; `hatsu:hanten`, `hatsu:direct` cite it |
| `claude.<tier>` | string | Hatsu's own: `frontier: fable`, `deep: opus`, `fast: sonnet`, `economy: haiku` | The alias each tier resolves to on Claude Code | `hatsu:hanten` § 4 (reviewer tier), `hatsu:direct`, `nen direct resolve`, `scripts/direct_matrix_doc.sh` |
| `codex.<tier>` | string | Hatsu's own: `frontier: astra`, `deep: sol`, `fast: terra`, `economy: luna` | The same on Codex; the concrete id is read from `codex debug models` at the moment of use | the same |
| `cursor.<tier>` | string | Hatsu's own: `frontier: grok`, `deep: grok`, `fast: composer`, `economy: composer` | The same on Cursor, **Cursor-native only**: provider models there are reserved for Bugbot. `frontier` and `deep` name the same alias, so *never the frontier tier* is enforced on the role, not the string | the same |
| `antigravity.<tier>` | string | Hatsu's own: `frontier: ultra`, `deep: pro`, `fast: flash`, `economy: flash` | The same on Antigravity; a persona's model accepts only `inherit`, `flash` or `pro`, so `economy` maps to `flash` | the same |
| `<surface>.note` | string | prose | The surface's own caveat, kept beside its row | nothing in nen |
| `roles.<role>` | string | a tier name. Hatsu's own: `reviewer: deep`, `worker: fast`, `measurer: fast`, `orchestrator: frontier`, `watcher: economy`, `formatter: economy` | Which tier a role runs on. `watcher` is Illumi and every `hatsu:izanami` poll; `formatter` is gyo's auto-fix and a prose reflow; `orchestrator` is the main session's and no subagent ever takes it | `hatsu:hanten` (a reviewer is raised at `roles.reviewer`), `hatsu:en` (Illumi at `roles.watcher`), `hatsu:direct` (companion jobs at `roles.<role>`) |

`nen/workflow.json` → `models` is the source; the per-surface table in [WORKFLOW.md § 2 models](../WORKFLOW.md#2--nenworkflowjson--every-key) and [docs/DIRECT-MATRIX.md](../DIRECT-MATRIX.md) are convenience copies, and where they disagree the file wins.

### `review.scopes`

The path-to-reviewer map `hatsu:hanten` classifies a change set with, read by `nen review scopes --base <ref> --repo <path> --json` and never by a hand table. One row per scope; a path may raise several scopes, and a path no row claims is reported `unclaimed`. **`code`'s `paths` is `**` deliberately**, so Nobunaga is the default reviewer on every change set. Budgets are per **effort** (one branch, one PR), counted in `.nen/hanten/<branch-slug>[-pr<N>].cycle.json` by `scripts/hanten_cycle_ledger.sh`; a new PR number starts every scope full. One tier is swapped rather than read: a `product` repository swaps Nobunaga to `fast`.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `scopes` | open (object) | no default; **required** by `hatsu:hanten` and `hatsu:mukai`. Hatsu's own rows: `code`, `security`, `architecture`, `ui`, `performance`, `surfaces`, `economics`, `release` | The routing. Without it no change set can be classified and no reviewer raised | `nen review scopes`, `hatsu:hanten` § 1, `hatsu:mukai` |
| `scopes.<scope>.persona` | string | an agent name (`nobunaga`, `feitan`, `chrollo`, `hisoka`, `uvogin`, `phinks`, `leorio`) | The agent file raised for this scope, `claude/agents/<persona>.md` and its mirror on each surface. A scope whose persona has no definition is a gap, never improvised past | `hatsu:hanten` § 4 |
| `scopes.<scope>.tier` | string | a tier of `models` (`deep`, `fast`), **never `frontier`** | The tier the reviewer runs at, resolved through `models.<surface>.<tier>` at use | `hatsu:hanten` § 4 and § 7 |
| `scopes.<scope>.budget` | integer | reviews per effort | How many times this scope may be reviewed on one branch plus its PR; remediation does not reset it | `scripts/hanten_cycle_ledger.sh`, `hatsu:hanten` |
| `scopes.<scope>.paths` | string[] | prefixes or globs in `nen report data`'s tier-table grammar | What raises the scope. Matching is case-sensitive and a bare `*name*` matches the last path segment only, so Hatsu's `economics` row lists both cases and the directory forms. The `economics` scope is also raised **by content**, with [docs/ECONOMICS.md § 1](../ECONOMICS.md) the one home of those predicates | `nen review scopes` |

### `mukai`

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `autoEn` | enum | `true` · `false`; **`false`** (absent reads false). Hatsu's own is `true`, on the maintainer's request of 2026-10-01 | Whether `hatsu:mukai` starts `hatsu:en` on the PR it opened in the same turn. **Only JSON `true` starts En immediately**; `false`, absent or any other value makes mukai ring the turn bell and offer `hatsu:en on <CODE>#<N>` through the surface's picker, never starting it silently (ruling 8 of 2026-09-28). `nen schema check` tolerates the block | `hatsu:mukai` only |

### `release.unitPaths`

The **release unit**: exactly the paths `hatsu:getsuga` § 3 writes when it folds a release. `nen release unit-check --pr <n>` compares a PR's changed files to this list, and `nen pr merge --release-unit` refuses to merge a release-proposal PR that touches anything outside it, which is what bounds getsuga's own merge (the maintainer's rulings of 2026-09-26 and 2026-09-28).

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `unitPaths` | open (array) | path globs in `review.scopes`' grammar, or from nen `v0.15.1` `{"path": "<exact json file>", "keys": [...]}` to bound a JSON file to named leaf keys; no default. Hatsu's own: `CHANGELOG.md`, `changelog.d/**` | What a release-proposal PR may touch: the collated changelog section and the fragments it deletes, the version manifest where the release PR bumps it (in Hatsu the delivery PR carries the bump), and an archive-written identity file where `tags.identity` is declared | `nen release unit-check`, `nen pr merge --release-unit`, `hatsu:getsuga` § 3a |

### `futon.advanceGo`

The **advance-go gate**: which repository kinds a typed `hatsu:futon ... then <skill>` step may carry the maintainer's advance go for. `nen parse futon` annotates every skill-chain step whose skill is listed here with `gate: {allowed, kind, reason}`, the kind being `nen repo classify`'s own verdict (`unknown` fails closed); a skill not listed gets no gate, and futon § 8 refuses a listed skill's step that carries none. From nen `v0.15.1` an absent key falls back to nen's built-in default policy (`gate.source "default"`) and a declared one replaces it wholesale (`gate.source "declared"`), which is why the catalogue lists no default. **The policy lives here and nowhere in prose.**

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `advanceGo.mugetsu` | string[] | kinds of `product`, `process`, `library`. Hatsu's own: `["process", "library"]`, never a product that deploys or uploads to a store | Whether a `then mugetsu` step may publish on the advance go | `nen parse futon`, `hatsu:mugetsu` § 3, `hatsu:futon` § 8 |
| `advanceGo.getsuga` | string[] | the same set. Hatsu's own: all three | Whether a `then getsuga` step may cut on the advance go | the same |
| `advanceGo.kagutsuchi` | string[] | the same set. Hatsu's own: all three | Whether a `then kagutsuchi` step may send on the advance go | the same |

### `classify.publish`

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `publish` | enum | `label` · `label+comment`; **`label`** (absent reads the same; any other value reads `label`, said). Hatsu's own is `label+comment`, on the maintainer's request of 2026-10-20 | Whether `hatsu:classify` writes its resolved criteria to the issue beyond the `lang/` and `job/` labels. `label` applies the labels through `nen classify apply` and keeps the rest in the report and the ledger; `label+comment` adds one marker-keyed (`<!-- hatsu:classify -->`) comment per labelled issue carrying the applied keys with confidence and cited signals, the low keys and any undecidable axis. Acts standalone, under `build`, or under `hatsu:file` once the issue is created; never under `ren` or for an inline effort | `hatsu:classify` § 5b, `hatsu:build`, `hatsu:file` § 5 |

### `direct.publish`

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `publish` | enum | `none` · `label` · `label+comment`; **`none`** (absent reads the same; any other value reads `none`, said). Hatsu's own is `label+comment`, on the maintainer's request of 2026-10-11 | Whether `hatsu:direct` writes its verdict to the issue on GitHub. `none` keeps it in the report and the local ledger `.nen/direct/<effort>.json`; `label` applies the primary pick's model **line** as one `model/<line>` label (`claude`, `gpt`, `gemini`, `grok`, `composer`) through `nen label apply`, a label the consumer's `nen/labels.json` has not declared being the verb's refusal; `label+comment` adds one marker-keyed issue comment carrying the primary, fallback and recommended picks with tier, surface, effort dial and the live-read version. Acts under `build`, under `hatsu:file` once the issue is created (file § 5), or standalone, never under `ren`, which cannot leave the machine (the maintainer's ruling of 2026-10-05) | `hatsu:direct` § 7, `hatsu:build`, `hatsu:file` § 5 |

### `port`

The porting keys (`zheref/hatsu#354`): `handbooksRepo`, the canon handbooks repository a port ruling lands in (default `zheref/bankai-handbooks`), and `rulingsDir`, the directory of its ports family (default `handbooks/ports`, one directed pair file per scenario pair plus `INDEX.md`). Read by `bankai-rule`, `limbo` and `bankai-handbooks` (and the port composites `hiraishin` and `kamui`, zheref/hatsu#357 and #356, not yet shipped); both have defaults, so an unset consumer reads them through `config_values.sh need --skill bankai-rule`. Domain `port` in the catalogue.

### `aiReviewers`

A top-level key, Hatsu's own (the maintainer's rulings of 2026-10-11, zheref/hatsu#245). One value for every automated reviewer in `nen/gates.json` → `reviewers[]`, gating both their **use** and their **expectation**. The rule is [`docs/PROCESS.md`](../PROCESS.md) § *Reviewer rounds and review threads*, *AI reviewers per consumer*, stated once. Catalogue id `workflow.aiReviewers`, asked at adoption (`hatsu:tenkai` § 6d) and settable by hand or through `config_values.sh set` — **effective once merged**: the skills read it at the PR's base and the default branch's tip and apply the stricter (`required` > `optional` > `off`), never the PR's own head, and an unreadable value reads `required`.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `aiReviewers` | enum | `required` · `optional` · `off`; **`required`** (absent reads the same, so every consumer keeps today's behaviour; a value outside the three is `missing-configuration`, `required` applying meanwhile). Hatsu's own is `optional`, on the maintainer's ruling | `required`: bots requested within `round_policy`'s caps and expected. `optional`: requested within the caps, never waited for. `off`: never requested — zero spend on requested reviewers; installed CI lanes still run, turned off through the consumer's caller workflow. Under `optional` and `off` a PR whose `nen pr ready` fails only on `rounds-owed`, hanten settled, goes to en § 5's merge prompt on hanten's rounds with the not-ready verdict quoted verbatim; nothing else is relaxed. `round_policy.maxRounds: 0` is not an off switch; this key is. CI reviewer lanes are covered too and never requested under any value (ruling 2026-10-19; PROCESS, *Event-driven reviewer lanes*) | `hatsu:sharingan` § 6, `hatsu:en` §§ 5–6, `hatsu:pr-state` § 2 |

### `ci`

A top-level block, Hatsu's own, written by `hatsu:kuchiyose` at install (zheref/hatsu#331, to land; the maintainer's rulings of 2026-10-19). Absent means no CI tier is installed. `nen schema check` tolerates it. The full description is [`docs/WORKFLOW.md`](../WORKFLOW.md) § 2 → `ci`.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `provider` | string | a product code (`AK`) · none | the CI provider, by code, never by slug | `hatsu:kuchiyose` |
| `pinned` | string | a release tag · none | the tag the caller workflows reference and the tier catalogue is read at | `hatsu:kuchiyose`; nen's warmup pin sweep (zheref/nen#440) and `tenkai`'s drift row (zheref/hatsu#331) once they land |
| `tiers` | string[] | catalogue keys (`reviewers`) · `[]` | the installed tiers | `hatsu:kuchiyose` |
| `rulings` | object | `hidan`: `on` · `off`; `claudeAuth`: `claude_code_oauth_token` (starred) · `anthropic_api_key` · `{}` | the per-consumer answers asked at install | `hatsu:kuchiyose` |

### `runners`

Self-hosted GitHub Actions runner naming and pools, provisioned by `hatsu:jusshin` through nen's `runner` family (`inventory`, `plan`, `script`, `verify`, `workflow`, `preflight`, `enable`; nen `v0.18.0`, the interactive mode from `v0.19.0`). One preflight workflow is rendered per pool. The catalogue kind is `external`, asked on use: no `runners` block makes a verb exit `2` naming the key, and jusshin asks per field (`missing-configuration`), writes the answer into the target's file, runs `nen schema check` and `nen stage triage` on it, and lands it through its declaration PR before a verb reads it live. `hatsu:tenkai` § 5b derives which runner a readiness workflow targets; jusshin never changes that derivation.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `naming` | object | the repository's own scheme; no default | How runners are named; `nen runner plan` renders `runners[].name` from it with the typed machine code | `nen runner plan`, `hatsu:jusshin` |
| `pools[]` | object[] | one object per pool; no default | The pools the repository declares, one preflight workflow each | `nen runner plan\|script\|workflow\|preflight\|enable`, `hatsu:jusshin` § 2 |
| `pools[].mode` | enum | `service` · `interactive`; absent means `service` on Windows and Linux and `interactive` on macOS, whose runner is always a LaunchAgent | A service runs in session 0, which has no desktop; an interactive pool's runners are logon tasks in one dedicated account's signed-in desktop session, online only while it is signed in. Declaring one, the mode is asked with that cost said, never assumed | `nen runner plan` (contract `nen.runner.plan/v0.2`), `nen runner script`, `nen runner workflow` (the `MODE` placeholder), `hatsu:jusshin` § 3 |
| `pools[].labels` | string[] | Declare `self-hosted`, OS, arch, and optionally the final `pool-<id>`; an interactive Windows pool also declares `desktop` before that final label | Nen 0.21 accepts either spelling and always normalizes to a set ending in `pool-<id>`. Jobs select the complete set, so a same-arch runner in another pool does not join by default | `nen runner plan`, `templates/runner-preflight.yml`'s `runs-on`, `hatsu:tenkai` § 5b |
| `pools[].root.<os>` | string | a directory per OS; absent means nen's default | The runner root on a host of that OS | `nen runner plan`, `hatsu:jusshin` |

### `port.specKit`

Read in a product family's **spec repository** (role `spec`, [`repos.json.md`](repos.json.md) § `families[]`) by `hatsu:kamui` § 2 (zheref/hatsu#356); the epic's other `port.*` keys land with `bankai-rule` (zheref/hatsu#355). Both keys apply their default when absent, so neither blocks a run; both catalogue rows carry `when: nen/workflow.json#port`, so `fill` writes nothing into a repository without the block; `nen schema check` tolerates it.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `pin` | string | a `github/spec-kit` release tag; **`v1.2.2`** (the latest release when kamui landed, read 2026-10-20) | The spec-kit release whose file set and paths kamui writes: `specs/<nnn>-<slug>/` with `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/`, `tasks.md`, `checklists/requirements.md`, and `.specify/memory/constitution.md` once | `hatsu:kamui` §§ 2–3 |
| `layout` | string | a path template; **`specs/{nnn}-{slug}`** — `{nnn}` the next free three-digit number (spec-kit's `sequential` numbering), `{slug}` a kebab phrase from the source's title | Where one feature's folder is written | `hatsu:kamui` §§ 2–3 |

### Keys a consuming repository may add

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `tags.identity.nameFrom` | string | a repo-relative path written by the repository's own `archive` row; absent reads `no tag declared` | Line 1 is the tag's identity (`v1.0.0+1217`, no prefix), line 2 the commit SHA the archive was built from. `hatsu:susanoo` § 5a announces it as an eligibility; `hatsu:kagutsuchi` § 4a cuts `dist/<target>/<identity>` at the recorded SHA only after a green send; `scripts/send_freshness_check.sh` reads the SHA for the freshness gate | `hatsu:susanoo`, `hatsu:kagutsuchi`, `scripts/dist_tag.sh`, `scripts/send_freshness_check.sh` |
| `tags.deploy.<target>` | object | per target, opt-in; absent means no tag for that target (exit `3` from `scripts/dist_tag.sh`) | Whether what was sent to this target is tagged, and whether the tag is pushed (`push: false` drops `--push`) | `hatsu:kagutsuchi` § 4a, `scripts/dist_tag.sh` |

Hatsu's own file declares neither: a plugin distributed by git ref has no archive to tag.

## Example

Illustrative only: a plain product repository on the default lane `app`, with a declared test suite, one review scope beyond `code`, and the catalogue's defaults written out. The `$<key>` annotations are the ones `config_values.sh fill` writes.

```json
{
  "$schema": "nen.workflow/v0.1",
  "branch": { "template": "{model}/{persona}/{descriptor}", "base": "main" },
  "iteration": { "checks": ["build"], "lane": "app" },
  "tests": { "required": ["test"], "extra": ["ui-test"] },
  "coverage": { "minimum": 80, "recommended": 85, "ideal": 90, "scope": "touched" },
  "launch": { "default": "sim", "fallback": null },
  "deploy": { "defaultTarget": "testflight" },
  "reports": {
    "dir": "Reports", "retain": "final-only", "template": "spiritual-message",
    "$template": "one of: spiritual-message | rikugan",
    "captures": "Reports/captures", "timeZone": "Etc/GMT+5"
  },
  "notifications": {
    "rungs": ["push", "os", "sound"], "$rungs": "any of: push | os | sound",
    "sound": "Glass", "turn": "rung1", "$turn": "one of: rung1 | all"
  },
  "commits": {
    "allowedAttributionTrailers": ["Hatsu-Agent", "Akatsuki-Agent"],
    "forbiddenTrailers": ["Co-Authored-By", "Claude-Session", "Signed-off-by",
                          "Generated-by", "Generated-with", "Reviewed-by"]
  },
  "monitor": { "maxCycles": 20, "pollSeconds": 300 },
  "profile": { "allowed": ["fast", "standard", "thorough"],
               "$allowed": "any of: fast | standard | thorough",
               "$default": "one of: fast | standard | thorough" },
  "models": {
    "rule": "latest alias only, never a version; subagents never on the frontier tier",
    "claude":      { "frontier": "fable", "deep": "opus", "fast": "sonnet",   "economy": "haiku" },
    "codex":       { "frontier": "astra", "deep": "sol",  "fast": "terra",    "economy": "luna" },
    "cursor":      { "frontier": "grok",  "deep": "grok", "fast": "composer", "economy": "composer" },
    "antigravity": { "frontier": "ultra", "deep": "pro",  "fast": "flash",    "economy": "flash" },
    "roles": { "reviewer": "deep", "worker": "fast", "measurer": "fast",
               "orchestrator": "frontier", "watcher": "economy", "formatter": "economy" }
  },
  "review": {
    "scopes": {
      "code":     { "persona": "nobunaga", "tier": "deep", "budget": 2, "paths": ["**"] },
      "security": { "persona": "feitan",   "tier": "deep", "budget": 1,
                    "paths": [".github/workflows/**", "**/*auth*", "**/*secret*", "**/*token*"] },
      "ui":       { "persona": "hisoka",   "tier": "fast", "budget": 2,
                    "paths": ["**/Views/**", "**/__Snapshots__/**"] }
    }
  },
  "mukai": { "autoEn": false, "$autoEn": "one of: true | false" },
  "release": { "unitPaths": ["CHANGELOG.md", "changelog.d/**", "App/Info.plist"] },
  "direct": { "publish": "none", "$publish": "one of: none | label | label+comment" }
}
```

## When a skill needs a value that is not set

Most keys here carry a canon default a reader applies when the key is absent, so `fill` can write them out without changing behaviour. Three values have no default and a skill cannot run without them.

| Catalogue id | Kind | `requiredBy` | The question the skill asks | Setup |
|---|---|---|---|---|
| `workflow.review.scopes` | open | `hatsu:hanten`, `hatsu:mukai` | *Which review scopes should pre-PR review route to?* Recommended: start from Hatsu's own `review.scopes` (`code`, `security`, `architecture`, `ui`, `performance`, `surfaces`, `economics`, `release`) and drop the ones this repository never touches | none; written through `config_values.sh set` |
| `workflow.release.unitPaths` | open | none `requiredBy`, but `hatsu:getsuga` merges its own release PR only when its diff is exactly this unit | *Which files make up a release unit here (version manifests, CHANGELOG.md)?* | none |
| `workflow.runners` | external, asked on use | `hatsu:jusshin` | *How should self-hosted runners be named and pooled (naming, pools[] with their root per OS)?* | repository or organisation admin rights on GitHub (Settings → Actions → Runners); a host machine for each pool, with the OS service account jusshin will run it under |

Three more are asked, not defaulted, because `null` is an answer: `launch.default` (*Which launch target should every turn start by default?*, candidates from `project.launch`, asked only while that block exists), `launch.fallback` (the same candidates), and `deploy.defaultTarget` (*Should an untargeted hatsu:kagutsuchi send to a standing non-production target?*, typed and never picked, candidates from `project.targets`). `profile.default` is asked for its options and never given a default, because nen derives it from `allowed`.

**`scripts/config_values.sh`** is the one engine. `diagnose --repo <path> [--domain <d>]` reports every catalogued value of this file (and of `nen/gates.json` and `nen/contract.json`) as `ok`, `DFLT` (default unwritten), `NOTE` (annotation owed), `BAD` (outside its options), `ASK` (required, missing), `LATR` (asked on use), `OPT` or `n/a`, exit `1` while work remains; `fill --repo <path>` writes only an absent key at its catalogue default and the `$<key>` annotation beside a fixed-set value, behaviour-neutral by construction, never creating the file and never rewriting a set value; `need --repo <path> --skill <s>` lists what that skill cannot run without, which every phase's warm-up runs (`hatsu:ten` § 6 step 5b) and answers through the picker (`missing-configuration`); `set --repo <path> --id <catalogue id> --value <JSON literal>` writes one chosen value after the question, refusing a value outside its options (`aiReviewers` other than `required`, `optional` or `off`, naming the three), a production target or one without `nonProduction: true` as `deploy.defaultTarget`, and anything shaped like a credential. `nen schema check` stays the authority on validity after every write.

## Sources

- [`nen/workflow.json`](../../nen/workflow.json), Hatsu's own file, every `$comment`
- [`docs/WORKFLOW.md § 1 · Two files, and the line between them`](../WORKFLOW.md#1--two-files-and-the-line-between-them)
- [`docs/WORKFLOW.md § 2 · nen/workflow.json, every key`](../WORKFLOW.md#2--nenworkflowjson--every-key), including *Repository kinds*, *The matrix, per surface* and *Report time*
- [`docs/WORKFLOW.md § 4 · Ask, set up, continue`](../WORKFLOW.md#4--the-phases-and-which-of-them-a-human-calls)
- [`docs/WORKFLOW.md § Consumer adoption`](../WORKFLOW.md#consumer-adoption--how-another-repository-becomes-a-hatsu-consumer) (who writes the file, runner derivation)
- [`contracts/config-catalogue.json`](../../contracts/config-catalogue.json), rows `workflow.*`
- [`scripts/config_values.sh`](../../scripts/config_values.sh), header comments
- [`claude/skills/jusshin/SKILL.md`](../../claude/skills/jusshin/SKILL.md) § 2 and § 3 (`runners`)
- [`claude/skills/susanoo/SKILL.md`](../../claude/skills/susanoo/SKILL.md) § 5a and [`claude/skills/kagutsuchi/SKILL.md`](../../claude/skills/kagutsuchi/SKILL.md) § 4a (`tags`)
- [`claude/skills/classify/SKILL.md`](../../claude/skills/classify/SKILL.md) (`classify.publish`)
- [`claude/skills/direct/SKILL.md`](../../claude/skills/direct/SKILL.md) (`models`, `direct.publish`)
- [`claude/skills/jutaisho/SKILL.md`](../../claude/skills/jutaisho/SKILL.md) § 1 (`notifications`)
- [`claude/skills/spiritual-message/SKILL.md`](../../claude/skills/spiritual-message/SKILL.md) (`reports`, `reports.timeZone`)
- [`claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) § 3 and § 6d
- [`hooks/guard-base-branch.sh`](../../hooks/guard-base-branch.sh), header (`branch.base`)
