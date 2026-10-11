# `.claude/canon-values.yml` — which surfaces a consumer mirrors the canon into, and the values bound into every `{{TOKEN}}`

> **Lives in** the consumer repository, by convention at `.claude/canon-values.yml` (the path is caller data: every nen verb takes it as `--canon-values <path>`, resolved against `--repo`) · **Written by** the maintainer by hand; `nen scaffold init --canon-values-path <path>` writes a template when nothing is there yet; `hatsu:limbo` § 3 writes the `surfaces:` key on the maintainer's one answer · **Validated by** `nen canon mirror check` (exit `2` on a missing `surfaces:` key; the generator fails closed on an undeclared or unbound token); the `nen schema check` row over the bindings is zheref/nen#262, an owned dependency · **Authority** `nen canon --help`; [`claude/skills/limbo/SKILL.md`](../../claude/skills/limbo/SKILL.md); the stack's `rules/placeholders.md` in `zheref/bankai-handbooks` for the token schema

## What it decides

The canon mirror doctrine (`CON-13`) authors every rule once, in `zheref/bankai-handbooks`, and renders it at a pinned tag into the rules location of every agent surface a consumer uses. This file is the consumer's half of that render: it declares **which surfaces** the mirror is written to, and binds **the repo-specific values** the canon's rule files carry as `{{TOKEN}}` placeholders (the product repository, the scheme, the test target, the snapshot device, and the rest). `nen canon mirror generate` substitutes the bindings into the stack's `rules/` and writes one marked file per canon file into Claude Code's `.claude/rules/*.md`, Cursor's `.cursor/rules/*.mdc`, Antigravity's `.agents/rules/*.md`, and one managed block in Codex's `AGENTS.md`; `nen canon mirror check` renders the same mirror in memory and diffs the committed copy. `hatsu:limbo` drives both; the local verification gate (WORKFLOW § *The local verification gate*, step 2) regenerates the mirror on every commit that touches this file.

Without a `surfaces:` key the check exits `2` with nen's own sentence, *Which agent surfaces a repository is used with is that repository's own declaration, never a default*, and nothing is rendered. With a token unbound the generator fails closed. With the file absent `nen repo classify` is still read, but `hatsu:limbo` § 2 step 1 stops with `canon mirror: not applicable`, and `kokusen`'s gate reports the same. The pin is **not** in this file: it is `nen/repos.json` → `maintained_tools[].pinned` ([`repos.json.md`](repos.json.md)), read by `nen canon pin`.

## Keys

### Top level

The file is YAML. Three kinds of key are confirmed; the exact spelling of the token-binding keys is a known gap (below).

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `surfaces` | inline list (`a, b`) or block list (`- a`) | any of `claude-code`, `codex`, `cursor`, `antigravity`; **no default**, the key is required unless `--surfaces` is passed | the agent surfaces this consumer is used with, and so the rules locations the mirror is written to | `nen canon mirror generate|check` (`--surfaces` overrides it); `hatsu:limbo` § 3 |
| `scenario` | string | a stack handbook id (`swiftui-tca-uzf-v2`, `compose-uzf-v2`, `react-uzf-v1`, `bankai-machinery`); optional, `--scenario` overrides it | which stack's `rules/` the tokens belong to; stamped into every generated file's marker | `nen canon mirror generate|check` |
| the token bindings | one value per `{{TOKEN}}` the stack's `placeholders.md` declares | strings; every token a rule file uses must be bound | the repo-specific values substituted into the canon | `nen canon mirror generate|check`; the correctness read in WORKFLOW's local verification gate step 2 (`grep` for a superseded value across `.claude/rules/`) |

### The surfaces, and where each is rendered

Declared here, never defaulted, never all four from a skill's own head (`limbo` § 3). The locations are nen's documented ones per surface and are not declared in this file.

| Surface | Rules location written | Shape |
|---|---|---|
| `claude-code` | `.claude/rules/*.md` | one file per canon file |
| `codex` | `AGENTS.md` | one managed block between a `BEGIN` and an `END` marker; the consumer's own prose outside it is preserved byte for byte |
| `cursor` | `.cursor/rules/*.mdc` | one file per canon file |
| `antigravity` | `.agents/rules/*.md` | one file per canon file |

Every generated file carries a marker naming `--source@--ref`, the scenario and the canon file. The marker is the ownership claim: a destination that exists without one was written by hand, and the whole run is refused at exit `2` before the first byte is written on any surface.

### The token schema, per stack

The tokens are declared once per stack in `handbooks/stacks/<scenario>/rules/placeholders.md` of `zheref/bankai-handbooks`: token, meaning, an illustrative example for a fictional product. That file is the schema, not the value store; the real values live only in each consumer's own binding, and `zheref/bankai-handbooks` holds no bindings. For `swiftui-tca-uzf-v2` the declared tokens include `{{PRODUCT_REPO}}`, `{{PROJECT_NAME}}`, `{{GH_PROJECT}}`, `{{MAINTAINER}}`, `{{APP_TARGET_IOS}}`, `{{APP_TARGET_MACOS}}`, `{{PREVIEW_HOST_TARGET}}`, `{{CORE_FRAMEWORK}}`, `{{UI_MODULE}}`, `{{TEST_TARGET}}`, `{{APP_SOURCE_ROOT}}`, `{{XCODEPROJ}}`, `{{SCHEME}}`, `{{SNAPSHOT_DEVICE}}`, `{{SNAPSHOT_OS}}`, `{{SNAPSHOT_DEVICE_CONFIG}}`, `{{SNAPSHOT_TZ}}`, `{{SNAPSHOT_PATH}}`, `{{ASSETS_REPO}}`, `{{ASSETS_LAYOUT}}`, `{{SCREENSHOTS_SCRIPT}}`, `{{LINT_SCRIPT}}`, `{{LINT_WORKFLOW}}`, `{{CI_TEST_WORKFLOW}}`, `{{BANKAI_WORKFLOW}}`, `{{DBMIGRATE_WORKFLOW}}`, `{{BUILD_LOG}}`, `{{ARCH_DECISIONS_DIR}}`, `{{DOCS_ROOT}}`, `{{FLAG_ENUM}}`, `{{COPILOT_REVIEWER}}`, `{{PRODUCT_ACCENT_TOKEN}}` and `{{EXTERNAL_STYLE_SDK}}`, as read at the canon's default branch; `compose-uzf-v2` and `react-uzf-v1` carry their own tables. Adding or renaming a token is a `G4` change in the canon and a binding change in every consumer of that stack before its next repin.

### What sits beside it, and is not in it

| Declaration | Where | Read by |
|---|---|---|
| the canon pin (`source`, `ref`) | `nen/repos.json` → `maintained_tools[].pinned`; exactly one pinned tool, or `--source` names which | `nen canon pin`; `limbo` § 2 step 2, § 4 |
| the scenario of record | `nen/repos.json` → `consumers[].scenario` (this file's `scenario:` key may restate it) | `nen repo scenario`, `nen canon resolve --leaf rules` → the `--rules-dir`; `limbo` § 2 step 4 |
| the regenerate argv | `nen/workflow.json` → `iteration.canonMirror.command` (Hatsu's own key, preserved by `nen schema check`) | WORKFLOW's local verification gate step 2; `kokusen` § 3; `tenkai` § 6c (a consumer with bindings and no key is a routed gap) |
| the files never mirrored | `--not-mirrored README.md,placeholders.md` on the call | `limbo` § 2 steps 5, 10 |

### Who reads it

| Reader | What it reads |
|---|---|
| `nen canon mirror generate` | `surfaces:` (unless `--surfaces`), `scenario:` (unless `--scenario`), every token binding; refuses an unmarked destination, an unresolved merge conflict, a non-tag `--ref` |
| `nen canon mirror check` | the same, writing nothing but the `--markdown-out` table; `ok / missing / extra / stale / hand-edited / foreign` per surface |
| `hatsu:limbo` §§ 2–4 | passes `--canon-values .claude/canon-values.yml` on every check and generate; writes `surfaces:` once on the maintainer's answer; never a surface the consumer did not declare |
| `hatsu:kokusen` § 3, WORKFLOW's local verification gate step 2 | where the delta touches this file, runs `iteration.canonMirror.command` and stages the regenerated `.claude/rules/` with the commit, or the commit is red |
| `hatsu:tenkai` § 6c | whether a consumer carrying this file also declares `iteration.canonMirror.command` |

## Example

Illustrative, for a plain product repository on the `swiftui-tca-uzf-v2` stack that is used with all four surfaces. The binding keys follow the token names of the stack's `placeholders.md`; their exact spelling in this file is a known gap (below), so treat the lower block as the shape of the data, not a verified key list.

```yaml
# Which agent surfaces this repository is used with. Never defaulted by nen or by limbo.
surfaces:
  - claude-code
  - codex
  - cursor
  - antigravity

scenario: swiftui-tca-uzf-v2

# One value per {{TOKEN}} the stack declares in rules/placeholders.md.
PRODUCT_REPO: <owner>/<product-repo>
PROJECT_NAME: Acme
MAINTAINER: <your-login>
APP_TARGET_IOS: Acme
TEST_TARGET: AcmeTests
XCODEPROJ: Acme.xcodeproj
SCHEME: Acme
SNAPSHOT_DEVICE: iPhone 17 Pro
```

Then, from the consumer's root with the canon checked out at the pinned tag:

```bash
nen canon pin --repo . --json
nen canon mirror check --repo . --rules-dir <canon>/handbooks/stacks/swiftui-tca-uzf-v2/rules \
  --canon-values .claude/canon-values.yml --not-mirrored README.md,placeholders.md \
  --markdown-out .nen/canon-drift.md --json
```

Exit `0` is current, `1` is drift, `2` is the invocation or the declaration, never current.

## When a skill needs a value that is not set

- **The file is absent.** `hatsu:limbo` § 2 step 1: `canon mirror: not applicable`, stop. The gate's step 2 reports the same. Nothing creates the file unasked; `nen scaffold init --canon-values-path <path>` writes a template on the maintainer's call.
- **No `surfaces:` key.** `check` exits `2` with the sentence above. `limbo` § 3 treats it as `missing-configuration` ([WORKFLOW § 4](../WORKFLOW.md)): recommends from what is on disk (`.claude/`, `AGENTS.md` or `.codex/`, `.cursor/`, `.agents/`), asks once through the picker, writes the key, re-runs the check. Never `--surfaces` from its own head, never all four.
- **A token is unbound.** The generator fails closed (`zheref/bankai-handbooks`, `.claude/rules/03-tokens.md`); the missing binding is the consumer's to add, never a value guessed from the illustrative example.
- **No pin, or a non-tag pin.** `nen canon pin` exits `1`; `limbo` § 2 step 2 asks for the tag, typed, and records it in `nen/repos.json`; a floating `--ref` is refused by nen.
- **No `iteration.canonMirror.command`.** `tenkai` § 6c names the routed gap; until it is set the regenerate is `hatsu:limbo`, by hand (`limbo` § *Residue* 6).
- **A destination is hand-edited.** `G5` before any write: `nen/decisions.json` row `hand-edited-canon-mirror` carries the three remedies (file the rule upstream, move it to a file the mirror does not own, or `git rm` a predecessor generator's mirror).

## Known gaps

What could not be confirmed from the sources available in this checkout and the public canon, listed rather than guessed:

1. **The exact YAML shape of the token bindings.** `nen canon --help` says every `{{TOKEN}}` is *bound from --canon-values* and `zheref/bankai-handbooks` describes the file as *the `{{TOKEN}}` → value binding*, but neither names the key spelling (bare `TOKEN:` at the top level, a `values:` or `tokens:` map, braces kept or stripped, case sensitivity). The example above uses bare top-level keys as an illustration only.
2. **The template `nen scaffold init --canon-values-path` writes.** Its contents were not read in this run.
3. **Whether `scenario:` is required in the file** when `nen/repos.json` → `consumers[].scenario` already records it, or whether the two must agree. `nen canon --help` confirms only that `--scenario` overrides the key.
4. **Whether an unbound token is a refusal at `check` as well as at `generate`.** The canon's `03-tokens.md` says the generator fails closed; the check's behaviour on an unbound token was not exercised in [`docs/ab/limbo.md`](../ab/limbo.md).
5. **A per-surface override inside the file** (a surface-specific value or an excluded canon file). Nothing read suggests one exists; `--not-mirrored` is a flag, not a key.
6. **The brief's phrasing *the rules locations*.** The locations are fixed per surface by nen (`nen canon --help`) and are not declared in this file; what the file declares is the surface list.

## Sources

- `nen canon --help` at the pinned build: `pin`, `resolve`, `mirror generate`, `mirror check`
- `nen scaffold --help` at the pinned build: `--canon-values-path`, `--scenario`
- [`../../claude/skills/limbo/SKILL.md`](../../claude/skills/limbo/SKILL.md) §§ 2–4, *Residue*
- [`../ab/limbo.md`](../ab/limbo.md): the fixture consumer's file (`surfaces: claude-code, codex, cursor, antigravity` plus the stack's bindings) and the twenty-one verified runs
- [`../WORKFLOW.md`](../WORKFLOW.md) § *The local verification gate*, step 2 (zheref/hatsu#111)
- [`../../claude/skills/kokusen/SKILL.md`](../../claude/skills/kokusen/SKILL.md) § 3 · [`../../claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) § 6c · [`../../claude/skills/bankai-handbooks/SKILL.md`](../../claude/skills/bankai-handbooks/SKILL.md) §§ 0–1
- [`../../nen/decisions.json`](../../nen/decisions.json) → `hand-edited-canon-mirror`
- `zheref/bankai-handbooks` (public): `handbooks/README.md` § *Canon mirror*, `.claude/rules/03-tokens.md`, `CONSTITUTION.md` (`CON-13`), `MIGRATION.md`, `handbooks/stacks/swiftui-tca-uzf-v2/rules/placeholders.md`, read through the GitHub API at the default branch; no local checkout exists under `/Users/zheref/Code/Agents/`
- [`repos.json.md`](repos.json.md): the pin and the scenario of record
