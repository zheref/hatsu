# `nen/contract.json` — which nen this repository runs, and what nen executes here

> **Lives in** the consumer repository (Hatsu carries its own at [`nen/contract.json`](../../nen/contract.json)) · **Written by** `nen scaffold init` for a detected stack (the `dependency` block and a detected `project` block), by hand when `nen shu detect` answers *no lane detected*, and by [`scripts/config_values.sh set`](../../scripts/config_values.sh) for the two catalogued values (`project.defaultLane`, `project.kind`); a new lane, verb `argv` or `project.targets` entry lands through its declaration PR at the repository's gate before anything runs it · **Validated by** `nen schema check` (row `nen/contract.json`) · **Authority** [docs/WORKFLOW.md § 1](../WORKFLOW.md#1--two-files-and-the-line-between-them) and [§ 3](../WORKFLOW.md#3--projectlaunch-and-projectevidence) for the `project` half, [docs/NEN-CONTRACT.md](../NEN-CONTRACT.md) for the `dependency` half

## What it decides

This file answers two questions that nen refuses to guess. The **`dependency`** block says which nen binary the repository depends on, as a `minimum` pin and a `pinned_ref` the checksum-verified bootstrap installs; `hatsu:ten` executes it at the start of every session, before any other Nen-owned work, and the file's own `authority` clause makes it the single source of truth for every version, ref, URL and command echoed anywhere else. The **`project`** block says what `nen shu <verb>` spawns for this repository: lanes, per-verb `argv`, preconditions, hosts, deploy targets, launch targets, evidence globs and the host toolchain. Nen carries no build system and knows no tool's name, so every verb of the `shu` family runs exactly what is declared here and refuses when nothing is declared.

Every phase that runs a declared verb depends on it: `hatsu:breath`, `hatsu:rasengan` and `hatsu:kokusen` through `iteration.checks`, `hatsu:kotoamatsukami` through `test`, `hatsu:byakugan` through `coverage`, `hatsu:susanoo` through `archive`, `hatsu:kagutsuchi` and `hatsu:mugetsu` through `deploy` and `release`, `hatsu:amaterasu` through `dev` or `run`. In WORKFLOW.md's words, **a wrong `project` block produces a wrong command, loud and immediate, exit `1` or `5`**; a wrong `nen/workflow.json` produces a correct command run at the wrong moment, which is silent. That difference is why the two files are kept apart.

## Keys

### Top level

The `$schema` is `nen.contract/v0.1`. Beside nen's two blocks, Hatsu's own file carries prose keys that nen's loader preserves verbatim and reads nothing from; they are listed so a reader knows which keys are nen's shape and which are Hatsu's rationale.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `$schema` | string | **`nen.contract/v0.1`** | The shape nen validates the file against | `nen schema check` |
| `dependency` | object | see below | The Nen CLI this repository depends on | `hatsu:ten`, `nen shu tools`, `nen bootstrap`, `scripts/nen_global.sh`, `hooks/session-start.sh` |
| `project` | object | see below | What nen executes for this repository | every `nen shu` verb, `nen repo classify`, the skills named per key below |
| `contract`, `contract_version`, `decision`, `authority`, `summary` | string, integer, string, string, string | Hatsu's own values | The contract's name (`hatsu-nen-dependency`), its revision, the decision it records (`D10`), the single-source-of-truth clause and the one-paragraph summary | nothing in nen; `hatsu:ten` quotes `authority` |
| `install_paths` | object | `nen_absent`, `nen_present_out_of_range` | The two install paths, chosen by the probe and never by preference, each with its exact `commands` | `hatsu:ten` § 2 |
| `halt` | object | `when`, `message_template`, `after_halt` | The one halt: the bootstrap itself failing. An absent or out-of-range nen is an auto-install, not a halt | `hatsu:ten` § 3 |
| `no_improvised_fallback`, `no_jq` | object | `rule`, `scope`, `consequence` / `rule`, `why`, `how_instead` | No Nen-owned operation is ever improvised in prose; nothing shells out to `jq`, `yq` or python to read this file | every skill |

### `dependency`

The pin and the build move independently: `minimum` is the `MAJOR.MINOR` capability pin this repository declares, `pinned_ref` is the release tag its bootstrap installs. **The range `minimum` stands for is nen's answer, not a document's**: the binary ships its compatibility floor, `nen shu tools` applies it and prints it as `compat floor:`, and `hatsu:ten` § 1 reads that verdict rather than computing it. At the time of writing, `dependency.pinned_ref` reads `v0.22.0` and `dependency.minimum` reads `0.22` in Hatsu's own file; neither is a fact to remember, and the deep treatment is [docs/NEN-CONTRACT.md](../NEN-CONTRACT.md).

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `name` | string | **`nen`** | The binary's name on PATH | `hatsu:ten` |
| `source` | string | **`zheref/nen`** | The `owner/name` release assets are fetched from; the bootstrap's `--source` | `hatsu:ten`, `nen bootstrap` |
| `repository` | string | the repository URL | The dependency's home | prose only |
| `minimum` | string | `MAJOR.MINOR`, no patch | The capability pin: the oldest release carrying every verb the plugin executes. Moves to the newest adoption and never back; also moves when nen raises its compatibility floor | `nen shu tools` (the `nen` row's verdict), `hatsu:ten` § 1 |
| `minimum_semantics` | string | prose | The minimum rule in one sentence; the adoption-by-adoption history is [`docs/history/nen-repins.md`](../history/nen-repins.md) | nothing in nen |
| `zero_major_caveat` | object | `applies_while`, `rule`, `why`, `on_a_higher_minor`, `from_1_0_onward` | How a `0.x` pin is read: for pin `0.A`, build `0.B.z` and floor `0.F`, accepted when `A <= B` and `A >= F`, bounded by the build's own minor; from `1.0` the ordinary within-major reading applies | `hatsu:ten` (quotes it); the verdict itself is `nen shu tools`'s |
| `pinned_ref` | string | a release tag, `v`-prefixed | The build the bootstrap installs. May move on its own to a newer release inside the range; never `latest`, never an unpublished ref | the bootstrap's `--ref`, `hatsu:ten` § 2, `scripts/nen_global.sh`, the three workflows that bootstrap nen (`.github/workflows/surface-mirror-check.yml`, `pr-readiness.yml`, `surface-mirror-regenerate.yml`) |
| `pinned_ref_semantics` | string | prose | The release record for every pin the file has carried, with each platform's sha256 | `scripts/nen_global_fixture_check.sh` (holds the digests to `bootstrap.sha256`, and its first record to `pinned_ref`) |
| `pinned_ref_bootstrap_caveat` | string | prose | *A tag is not a release*: a tag with no published release exits `6`, a tag that does not exist fails at `curl` with `22` or `56` and never reaches the script | `hatsu:ten` § 3 |
| `version_probe` | string[] | **`["nen", "--version"]`** | An argv array, never a string: nen's loader refuses the string form | `hatsu:ten` § 1, `nen shu tools` |
| `version_probe_semantics`, `version_probe_output` | string | prose | Why it is an array; what it prints (a bare semver on stdout) | nothing in nen |
| `bootstrap.vendored` | boolean | **`false`** | Hatsu never carries a copy of the bootstrap script | `hatsu:ten` |
| `bootstrap.vendoring_forbidden` | string | prose | A vendored copy would be a second, unreviewed supply chain | nothing in nen |
| `bootstrap.script_path_in_source` | string | **`bootstrap/nen.sh`** | Where the script lives in nen's tree | `hatsu:ten` |
| `bootstrap.scriptSha256` | string | 64 lowercase hex digits | Independently reviewed SHA256 of the exact pinned `bootstrap/nen.sh` bytes; checked before Bash executes them | Hatsu host binder and Cursor Cloud Build; prepared readiness form after a separate activation PR; Nen preserves this raw key but does not type, produce or enforce it |
| `bootstrap.scriptSha256Provenance` | object | `ref`, `commit`, `path`, `sha256` | Review provenance for the script digest. A repin must update it with the script digest and binary platform digests; the fixture rejects mismatched metadata; typed renderer extraction is deferred | Hatsu offline integrity fixture; not a Nen schema guarantee or active renderer policy |
| `bootstrap.sha256` | object | `darwin-arm64`, `linux-x64`, `windows-x64` → hex digest | The release digests of the pinned binary, by platform. A platform with no key is never linked unverified. A repin moves `linux-x64` together with `pinned_ref`, in the same PR, or every later PR fails closed in CI | `scripts/nen_global.sh` (refuses a binary whose digest differs), `hooks/session-start.sh` step 0, and the three workflows that bootstrap nen, through their digest step (`NEN_DIGEST_FROZEN` in `scripts/workflow_runner_policy_check.rb`: `linux-x64`, read from `main`'s copy) |
| `bootstrap.url`, `bootstrap.fetch` | string | the raw URL at `pinned_ref`; the `curl -fsSL <url> -o <local-file>` line | Where the script is fetched from and how | `hatsu:ten` § 2, `hatsu:bakuryuha` |
| `bootstrap.fetch_must_be_two_step` | object | `rule`, `why`, `wrong`, `right` | Always fetch to a file, then run that file; never pipe into `bash` | `hatsu:ten` |
| `bootstrap.flags` | object | `--ref` (required), `--source`, `--cache-dir` | The script's flags and their defaults | `hatsu:ten` |
| `bootstrap.stdout` | string | prose | On success, the verified binary path and nothing else | `hatsu:ten`, `scripts/nen_global.sh` |
| `bootstrap.exit_codes` | object | `0`, `2`, `3`, `4`, `5`, `6`, `7`, `curl 22 / 56` | What each code means; `7` is `nen bootstrap`'s own (no script on disk) | `hatsu:ten` § 3, `hatsu:bakuryuha` |
| `bootstrap.retry_policy` | string | prose | `4` may be retried once; `5` and `6` never; `3` will not change on this host; `2` and `7` are invocation errors to fix and re-run | `hatsu:ten` |
| `bootstrap.published_binaries`, `bootstrap.manifest_asset` | string[], string | the three asset names; **`SHA256SUMS`** | What the release attaches and what the script verifies against | `scripts/nen_global.sh` |

**The range, in one table** (the rule the maintainer stated on 2026-09-10, *exact minor is fine, unless there is a breaking change*):

| the pin | the build | floor | verdict |
|---|---|---|---|
| `0.A` | `0.A.z` | `0.A` or lower | **ok**: a pin's own minor always satisfies it |
| `0.A` | `0.B.z`, `B > A` | at or below `0.A` | **ok**: the newer release declared no breaking notes, so no repin |
| `0.A` | `0.B.z` | above `0.A` | **below the floor**: no build of that line satisfies it; repin |
| `0.A` | `0.B.z`, `B < A` | any | **older than the pin**: install `pinned_ref` |
| `X.Y`, `X >= 1` | any | not consulted | `>=X.Y.0 <(X+1).0.0` |

The verdict is the `nen` row of `nen shu tools --repo <checkout>`; from nen `0.20` the row also reads `BEHIND` (exit `7`) when the host satisfies `minimum` but sits below `pinned_ref`.

### `project`: lanes and the default lane

A **lane** is one buildable unit of the repository: its stack id and the directory its verbs run in. Hatsu's file carries one repository lane plus one focused lane per executable guard; a product repository usually carries one lane per package or app target.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `lanes.<lane>.stack` | string | a stack id (`nen shu detect` answers one of nen's reference stacks; a hand-written lane may use the repository's own word) | What kind of unit this is. Nen validates the id against nothing | `nen shu detect`, `nen repo classify` (derives `kind` from the stacks) |
| `lanes.<lane>.cwd` | string | a repo-relative directory, **`.`** | Where every verb of the lane and every `after` step is spawned. Resolved against the repository's real root; a `cwd` that leaves the tree is exit `2` at use | every `nen shu` verb |
| `defaultLane` | open | a key of `lanes` | The lane a verb runs on when none is named; without it every lane-taking verb needs `--lane` | `nen shu`, `hatsu:susanoo`, `hatsu:kagutsuchi`, `hatsu:gyo`, `hatsu:rasengan`, `hatsu:tenkai`; `iteration.lane` derives from it |

### `project.verbs`

One row per lane, one entry per verb. A verb the lane has is `{exe, argv}`; a verb it does not have is an explicit **seat**, `{"unsupported": "<why>"}`. **A seat is exit `4`, a stated fact in the repository's own words; an omission is exit `2`, which reads as a broken declaration.** The verb names are nen's family: `lint`, `build`, `test`, `ui-test`, `coverage`, `archive`, `release`, `dev`, `run`, `deploy`.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `verbs.<lane>.<verb>.exe` | string | an executable name | The program nen spawns, with no shell in between | `nen shu <verb>` |
| `verbs.<lane>.<verb>.argv` | string[] | the arguments, one element each | Exactly what is passed; a `--target`'s `args` and a launch target's `args` are appended | `nen shu <verb>` |
| `verbs.<lane>.<verb>.artifacts` | string[] | repo-relative paths | What the verb produces; `{artifact}` in a launch target substitutes its first entry | `nen shu dev\|run --target`, `hatsu:susanoo` (reports each by path and size) |
| `verbs.<lane>.<verb>.unsupported` | string | the reason, in the repository's words | The seat: this verb does not exist here, and why | `nen shu <verb>` (exit `4`, the reason quoted), every skill that would have run it |
| `verbs.<lane>.lint` | row or seat | | The cheap mechanical check; `iteration.checks: ["lint"]` makes it `hatsu:gyo` | `hatsu:breath`, `hatsu:rasengan`, `hatsu:kokusen`, `hatsu:gyo` |
| `verbs.<lane>.build` | row or seat | | The compile; the catalogue's default `iteration.checks` entry | the same three phases |
| `verbs.<lane>.test`, `ui-test` | row or seat | | The suites `tests.required` and `tests.extra` may name; a focused lane's `test` is what `hatsu:tsukuyomi` routes to | `hatsu:kotoamatsukami`, `hatsu:tsukuyomi`, `hatsu:kokusen` |
| `verbs.<lane>.coverage` | row or seat | | The capture `nen shu coverage --touched` measures against the ladder; a seat makes `hatsu:byakugan` report `not measurable here` | `hatsu:byakugan` |
| `verbs.<lane>.archive` | row or seat | | The distributable; a lane that seats it has its reason quoted | `hatsu:susanoo`, `hatsu:getsuga`, `hatsu:kagutsuchi` § 3b |
| `verbs.<lane>.release` | row or seat | | What publishes one release to production; G3 holds the go, this row is what `hatsu:mugetsu` runs | `hatsu:mugetsu` through `nen shu release` |
| `verbs.<lane>.dev`, `run` | row or seat | | The debug and production starts a launch target names in `verb` | `hatsu:amaterasu` through `nen shu dev\|run --target` |
| `verbs.<lane>.deploy` | row or seat | | The send; always with `--target <name>`, nen never chooses where a build goes | `hatsu:kagutsuchi`, `hatsu:mugetsu` through `nen shu deploy --target` |

### `project.preconditions`

Facts nen asserts before it spawns a lane's verb, so a missing file fails as *the precondition is unmet* rather than as a confusing tool error. Nothing is synthesised to satisfy one.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `preconditions.<lane>[]` | object[] | one object per fact | The lane's preconditions, asserted in order | `nen shu <verb>` (the plan prints each row, `FAIL` on an unmet one) |
| `preconditions.<lane>[].kind` | string | `path` (the one kind Hatsu's file and the sources show) | What is being asserted | `nen shu` |
| `preconditions.<lane>[].value` | string | a repo-relative path | The thing that must exist. Resolved against the real root; a path that leaves the tree is exit `2` | `nen shu`, `scripts/kagutsuchi_worktree.sh` (re-asserted in the clean worktree) |
| `preconditions.<lane>[].why` | string | prose | Why the verb cannot run without it | the plan's output |

### `project.hosts`

Which host platforms may run which verbs. `*` is the default for every verb; a verb named as a key narrows it.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `hosts.*` | string[] | any of `darwin`, `linux`, `win32` | The platforms every verb runs on unless a verb says otherwise | `nen shu <verb>` |
| `hosts.<verb>` | string[] | the same set | A narrower allowlist for one verb (Hatsu's focused `test` fixtures are verified on Darwin and Linux only) | `nen shu <verb>`; `hatsu:susanoo` reads an unsupported host as exit `3`, a G5 |

### `project.targets`

Where builds are sent. One named destination per key; `why` states whether it is production or non-production, and `hatsu:kagutsuchi` reads it failing closed for every send; from nen `v0.21.0` the typed `nonProduction: true` is also required on a target named by `deploy.defaultTarget` (zheref/nen#300). Credentials are asserted, never handled: `requiresEnv` carries environment-variable **names** only, and nen checks each is set without reading it.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `targets` | external | `{}` when the repository sends nothing (Hatsu's own value, empty deliberately) | The declared destinations | `nen shu deploy --target`, `hatsu:kagutsuchi`, `hatsu:mugetsu`, `hatsu:getsuga` |
| `targets.<name>.args` | string[] | appended to the `deploy` row's `argv` | What distinguishes this destination on the command line | `nen shu deploy` |
| `targets.<name>.requiresEnv` | string[] | environment-variable **names** | The credentials the send needs set in the environment; a literal here is refused by `config_values.sh set` and flagged by `nen stage triage` | `nen shu deploy` (asserts each is set), `hatsu:kagutsuchi` § 5 |
| `targets.<name>.why` | string | prose reading production or non-production | What the destination is and which gate reaches it (G3 for production) | `hatsu:kagutsuchi` § 1, `hatsu:mugetsu`, `config_values.sh set` (refuses a production target as `deploy.defaultTarget`) |
| `targets.<name>.nonProduction` | boolean | optional; `true` marks the destination non-production; a non-boolean is refused by pointer | nen's typed mark; required on the target `deploy.defaultTarget` names (`nen schema check` FAILs it otherwise, nen `v0.21.0`) | `nen schema check`, `nen shu detect` (proposes `testflight` only so marked), `config_values.sh set` |
| `targets.<name>.unsupported` | string | the reason | A destination the repository names but cannot send to from here | `hatsu:kagutsuchi` (quotes it) |

### `project.launch`

How the app is started after a turn. Each key is a named target; `hatsu:amaterasu` starts the one `nen/workflow.json` → `launch.default` names and falls back to `launch.fallback`. `--target` is required, with no default, ever. The toolchain names (`xcrun`, `adb`, `open`) live here, in the repository's own file, never in nen.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `launch.<name>.verb` | string | `dev` or `run` | The lane verb that builds what is launched | `nen shu dev\|run --target <name>`, `hatsu:amaterasu` |
| `launch.<name>.args` | string[] | appended to the verb's `argv` | Target-specific arguments (a scheme, a destination). `{device.id}` or `{artifact}` here is exit `2`: substitution reaches `after` steps only | `nen shu` |
| `launch.<name>.lane` | string | a key of `lanes`; absent means the default | Which lane the verb, `args` and `after` steps are read from | `nen shu` |
| `launch.<name>.artifact` | string | a repo-relative path; absent means the verb's first `artifacts` entry | What `{artifact}` substitutes | `nen shu` |
| `launch.<name>.device.name` | string | the device's own name as its probe prints it | The device the target runs on; refused **by name** when the probe does not see it, listing what it did see | `nen shu`, `hatsu:amaterasu` (reports a disconnected device by name) |
| `launch.<name>.device.kind` | string | `simulator` where the sources show it | The device's kind | `nen shu` |
| `launch.<name>.device.resolve` | object | `{exe, argv}` | The probe that lists devices; `{device.id}` is read off the row whose name matched | `nen shu` |
| `launch.<name>.device.readyWhen` | object | `{field: n, in: [...]}` against line output, or `{path: "<dotted key>", in: [...]}` against JSON; exactly one of `field`/`path`, `in` non-empty | A present device is not a ready device: which states count. A row present but not ready is exit `5` naming the state seen and the states accepted | `nen shu` (validated at load, by pointer), `hatsu:jujutsu` § 6 (writes one on every device it registers) |
| `launch.<name>.after[]` | object[] | `{exe, argv}` steps | What installs and starts what the verb built, with `{device.id}` and `{artifact}` substituted as the step's own cwd sees them | `nen shu`, `hatsu:amaterasu` |

### `project.evidence`

Which artifacts count as visual evidence and how they reach a pull-request body. Executed by `nen shu evidence --base <ref>`.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `evidence.globs` | string[] | path globs (`**/__Snapshots__/**/*.png`) | The files that count as visual evidence; with none declared `hatsu:kotoamatsukami`'s evidence table is empty and says so | `nen shu evidence`, `hatsu:kotoamatsukami` |
| `evidence.scene` | string | a template, **`{suite}-{scene}`** | How a path becomes a suite-and-scene pair | `hatsu:kotoamatsukami`, `hatsu:spiritual-message` (scenes as columns) |
| `evidence.mechanism` | string | `public-mirror` where the sources show it | How the images reach the PR body; pre-PR they are inlined as data URIs | `hatsu:kotoamatsukami`, `hatsu:shibari` |

### `project.toolchain`

The host tools nen verifies before it runs, so a missing tool is found at warm-up rather than mid-verb. `nen shu tools --repo <checkout>` prints one row per entry; `--install` resolves the ones its `installer` allows.

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `toolchain.<tool>.version` | string | a semver range (`>=2.0.0`) | What satisfies the row | `nen shu tools` |
| `toolchain.<tool>.probe` | string[] | an argv array | How the installed version is read | `nen shu tools` |
| `toolchain.<tool>.versionFrom` | string | `first-semver-on-stdout` where the sources show it | How the version is parsed out of the probe's output | `nen shu tools` |
| `toolchain.<tool>.installer` | string | `verify-only` where the sources show it | Whether nen may install the tool. A `verify-only` row that is unmet is reported with its remedy line and left to a human, named with its pin (row `missing-tool`) | `nen shu tools --install`, `hatsu:breath`, `hatsu:ten` |
| `toolchain.<tool>.why` | string | prose | Why the tool is needed here | the plan's output |

### `project.fromCore`

Hatsu's own block, beside `preconditions`, read by `hatsu:kagutsuchi` § 3b through `scripts/kagutsuchi_worktree.sh` and by nothing in nen; nen's loader preserves it. Each entry names a repo-relative, gitignored, untracked file that exists only in the maintainer's core checkout, and the clean worktree kagutsuchi rebuilds in gets it copied from core before the fresh archive. The script refuses an entry that is tracked, not gitignored, absent in core, a symlink, or a path that leaves the tree. **No block copies nothing and says so.**

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `fromCore[].path` | string | a repo-relative, gitignored, untracked path | The file copied from core into the rebuild worktree | `scripts/kagutsuchi_worktree.sh` |
| `fromCore[].why` | string | prose | Why it lives only in the maintainer's checkout | the report |

### `project.kind`

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `kind` | enum | `product` · `process` · `library`; absent means derived from the lanes' stacks (`unknown` when nothing says) | The repository's own word on its kind. `product` and `process` are otherwise derived; `library` is **declared only**. It decides the advance-go policy (`futon.advanceGo`) and Nobunaga's review tier (`deep` on a process or library repository, `fast` on a product) | `nen repo classify`, `nen parse futon`, `hatsu:mugetsu`, `hatsu:futon`, `hatsu:hanten` |

The three kinds are defined once, in [WORKFLOW.md § Repository kinds](../WORKFLOW.md#repository-kinds--what-nen-repo-classify-answers); a declaration lands through the repository's own declaration gate before anything reads it.

> **Containment.** Every path a declaration states is repo-root-relative, and nen refuses one that leaves the tree `--repo` points at, at exit `2`, before anything is spawned, tested against the path the kernel would actually reach. `nen schema check` does **not** answer it: pointers are checked at load, paths at use, so a clean schema check is never a containment verdict ([WORKFLOW.md § 3 Containment](../WORKFLOW.md#containment--every-declared-path-is-resolved-against-the-repositorys-real-root)).

## Example

Illustrative only: a plain product repository with one lane, a focused test verb, a beta destination and a simulator launch target. The `dependency` block is copied from a scaffold at the pinned build and never edited by hand except at a repin; the stack id is whatever `nen shu detect` answered. Credentials appear as environment-variable names, never values.

```json
{
  "$schema": "nen.contract/v0.1",
  "dependency": {
    "name": "nen",
    "source": "zheref/nen",
    "minimum": "<MAJOR.MINOR the scaffold wrote>",
    "pinned_ref": "<vMAJOR.MINOR.PATCH the scaffold wrote>",
    "version_probe": ["nen", "--version"],
    "bootstrap": {
      "vendored": false,
      "script_path_in_source": "bootstrap/nen.sh",
      "url": "https://raw.githubusercontent.com/zheref/nen/<pinned_ref>/bootstrap/nen.sh",
      "manifest_asset": "SHA256SUMS"
    }
  },
  "project": {
    "kind": "product",
    "lanes": {
      "app": { "stack": "<the stack id nen shu detect answered>", "cwd": "." }
    },
    "defaultLane": "app",
    "verbs": {
      "app": {
        "build":    { "exe": "swift", "argv": ["build"] },
        "test":     { "exe": "swift", "argv": ["test"] },
        "lint":     { "exe": "swiftlint", "argv": ["lint", "--strict"] },
        "coverage": { "exe": "swift", "argv": ["test", "--enable-code-coverage"] },
        "archive":  { "exe": "xcodebuild", "argv": ["archive", "-scheme", "App"],
                      "artifacts": ["build/App.xcarchive"] },
        "deploy":   { "exe": "xcrun", "argv": ["altool", "--upload-app"] },
        "dev":      { "exe": "xcodebuild", "argv": ["-scheme", "App", "-configuration", "Debug"],
                      "artifacts": ["build/Debug-iphonesimulator/App.app"] },
        "ui-test":  { "unsupported": "No UI test target exists yet; the snapshot suite is part of `test`." },
        "release":  { "unsupported": "Publication is the store's review; nothing here publishes." },
        "run":      { "unsupported": "There is no production start outside the store build." }
      }
    },
    "preconditions": {
      "app": [
        { "kind": "path", "value": "Config/Local.xcconfig",
          "why": "The build reads the local signing team from it; it is gitignored and never synthesised." }
      ]
    },
    "hosts": { "*": ["darwin"] },
    "targets": {
      "testflight": {
        "args": ["--type", "ios"],
        "requiresEnv": ["APP_STORE_CONNECT_API_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID"],
        "why": "Non-production: the beta channel testers install from."
      }
    },
    "launch": {
      "sim": { "verb": "dev", "device": { "name": "iPhone 17 Pro", "kind": "simulator" } }
    },
    "evidence": { "globs": ["**/__Snapshots__/**/*.png"], "mechanism": "public-mirror",
                  "scene": "{suite}-{scene}" },
    "toolchain": {
      "xcodebuild": { "version": ">=16.0.0", "probe": ["xcodebuild", "-version"],
                      "versionFrom": "first-semver-on-stdout", "installer": "verify-only",
                      "why": "Xcode is the user's own install; nen never installs a host toolchain." }
    },
    "fromCore": [
      { "path": "Config/Local.xcconfig", "why": "Carries the maintainer's signing team; lives only in core." }
    ]
  }
}
```

## When a skill needs a value that is not set

The catalogue ([`contracts/config-catalogue.json`](../../contracts/config-catalogue.json)) lists four values of this file. Only one is `requiredBy` a skill; the others are asked on use or at adoption.

| Catalogue id | Kind | `requiredBy` | The question the skill asks | Setup |
|---|---|---|---|---|
| `contract.project.defaultLane` | open | none (every lane-taking verb needs `--lane` without it) | *Which lane is this repository's default?* Candidates come from `project.lanes` | none; `config_values.sh set` writes it |
| `contract.project.kind` | enum (`product`, `process`, `library`) | none | *Is this repository a product, a process repository, or a library shared across repositories?* | none; the declaration lands through the repository's declaration gate before anything reads it |
| `contract.project.targets` | external, asked on use | `hatsu:kagutsuchi` | *Where should builds go — a beta channel (TestFlight, Play internal, a staging URL) and the production store or environment?* | create the destination on its platform and note its id; create its upload credential there and export it under an environment-variable **name**, only the name is written; a new target lands through its declaration PR at the repository's gate before it runs |
| `contract.project.launch` | external | none (`launch.default` asks per turn while targets exist and none is chosen) | *How should a turn launch the app — which simulator, device or local command?* | for a physical device, pair and trust it once through `hatsu:jujutsu` |

A lane or a verb `argv` has no catalogue row: a missing declaration is `missing-consumer-declaration` (repaired by `hatsu:tenkai` for a Hatsu-owned piece, set up through `nen scaffold init --accept-detected` for a nen one) and a missing key inside an existing declaration is `missing-configuration`, asked per item and written through its owner. A seat (`unsupported`) is never a gap: the phase quotes the reason and reports `not measurable here`.

**`scripts/config_values.sh`** is the one engine behind those asks. `diagnose --repo <path>` reports every catalogued value as set, default-unwritten, unannotated, invalid, required-missing, asked-on-use or optional, exit `1` while work remains; `fill --repo <path>` writes only an absent key at its catalogue default and the `$<key>` annotation listing a fixed-set value's options, behaviour-neutral by construction, into a declaration that already exists; `need --repo <path> --skill <s>` lists what that skill cannot run without, which every phase's warm-up runs (`hatsu:ten` § 6 step 5b) and `hatsu:tenkai` § 6d answers; `set --repo <path> --id <catalogue id> --value <JSON literal>` writes one chosen value after the question was asked, refusing a value outside its options, a `requiresEnv` entry that is not an environment-variable name and anything shaped like a credential.

## Sources

- [`nen/contract.json`](../../nen/contract.json), Hatsu's own file, every `$comment` and prose key
- [`docs/WORKFLOW.md § 1 · Two files, and the line between them`](../WORKFLOW.md#1--two-files-and-the-line-between-them)
- [`docs/WORKFLOW.md § 3 · project.launch and project.evidence`](../WORKFLOW.md#3--projectlaunch-and-projectevidence), including *Containment* and `project.fromCore`
- [`docs/WORKFLOW.md § 2 · Repository kinds`](../WORKFLOW.md#repository-kinds--what-nen-repo-classify-answers)
- [`docs/WORKFLOW.md § 4 · Ask, set up, continue`](../WORKFLOW.md#4--the-phases-and-which-of-them-a-human-calls)
- [`docs/NEN-CONTRACT.md`](../NEN-CONTRACT.md), the dependency block's range semantics (moved there from the README)
- [`contracts/config-catalogue.json`](../../contracts/config-catalogue.json), rows `contract.project.*`
- [`scripts/config_values.sh`](../../scripts/config_values.sh), header comments
- [`claude/skills/kagutsuchi/SKILL.md`](../../claude/skills/kagutsuchi/SKILL.md) § 1, § 2 and § 3b (targets, `requiresEnv`, `fromCore`)
- [`claude/skills/susanoo/SKILL.md`](../../claude/skills/susanoo/SKILL.md) (`archive`, `project.hosts`, `artifacts`)
- [`claude/skills/kotoamatsukami/SKILL.md`](../../claude/skills/kotoamatsukami/SKILL.md) (`project.evidence`)
- [`claude/skills/breath/SKILL.md`](../../claude/skills/breath/SKILL.md) (`verify-only` toolchain rows)
- [`claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) § 3 and § 6d (who writes which file)
