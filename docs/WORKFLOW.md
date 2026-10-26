# The way of working

How a request becomes a merged pull request, and where every parameter of that journey is written down.

This document is the **authority on the two configuration files** and on the phases that read them. The
skills under [`../claude/skills/`](../claude/skills/) are the authority on what each phase *does*;
[`ROSTER.md`](ROSTER.md) is the authority on who exists. Where this document and a configuration file
disagree, **the file wins and this document is the bug** — the same rule
[`../nen/contract.json`](../nen/contract.json) already states for itself.

**Precedence among canon prose and rulings, one order ([HR-1](ROSTER.md#hr-1)), owned by the
`precedence` key of [`../nen/contract.json`](../nen/contract.json), which wins over this copy:**
`skill.hardLimit` **>** `roster.ruling` **>** `nen/decisions.json` **>** `docs/WORKFLOW.md` **>**
`docs/PROCESS.md` **>** `akatsuki.CON` **>** `handbooks`. The key's `$precedence` comment names each
entry. The order ranks canon texts only: a configuration file's value still beats any prose copy of it,
the rule above. A text outside the list yields to every listed entry and the conflict is filed
([HR-339](ROSTER.md#hr-339)). This is the order's one restatement;
[`PROCESS.md`](PROCESS.md) points here, and is binding wherever the skill is silent. From nen `0.28`
([zheref/nen#474](https://github.com/zheref/nen/issues/474), the HA#449 repin) `nen schema check` holds this copy to
the key through `precedenceRestatedIn` in `nen/contract.json` and fails a drifted run by file and line.

---

## Phase ownership — ruling of 2026-09-12

A local checkpoint, branch publication and PR completion are separate outcomes. No use of
“session complete” or “done” advances a later phase automatically.

| Phase | Required work | Evidence boundary |
|---|---|---|
| `rasengan` | Author behavior and focused tests; use them and inexpensive iteration checks for feedback | Feedback is not the checkpoint verdict |
| `kokusen` | Run declared iteration checks and applicable declared focused tests on the finished tree; commit locally | Full regression and coverage are not checkpoint gates |
| `amaterasu` | Handle launch after the checkpoint; isolated turns report a command and defer core launch to an explicit maintainer call | Report build/install/launch or deferral separately; core swap never transfers authoring |
| `aka` | Lint (`gyo`) before squash; squash only unpublished history; catch up; recheck changed-tree lint; push | No project-wide tests. Regression and coverage wait for mukai |
| `mukai` / `kotoamatsukami` | Review, then run only the declared unit, UI and integration suites the change can affect | Selection is fail-closed; edits return through focused checkpoint and kotoamatsukami before publication |
| `byakugan` | Capture and measure touched-file coverage independently of those suites | Extraction must not rerun tests; the G5 under `coverage.minimum` is this skill's |
| `gyo` | Declared `lint` verb on every Ren turn (breath tip, rasengan may, kokusen must) and at aka | Not coverage. A seat is quoted; red at kokusen refuses the commit |
| `spiritual-message` | Render the owning phases' evidence and discovery statuses; **00** is last-turn only; **01–07** are the session; **04** is a structural diagram | Reports run no tests/coverage; absent, stale and not-due evidence remain explicit; file lists are inventory, not architecture |

The single `iteration.checks` list still serves `breath`, `rasengan`, and `kokusen`. There is no
checkpoint-only routing key. A scoped test runs through an explicitly declared test lane whose
command names the scope; do not invent a test filter or substitute the full suite. If executable
changes lack a supported scoped path, capture the dependency and stop that checkpoint honestly.
Hatsu's prose-only changes retain the lint-only iteration list. Its executable version guard has
the declared `plugin-bump-guard` focused test lane; that lane is due for guard changes and is not
a general regression suite.

Any tracked tree change invalidates prior regression and coverage evidence because the capture
binds the exact tree hash, including sources, tests, snapshots and execution configuration.
Only a complete no-op catch-up may reuse the pre-catch-up lint result. Catch-up and review/coverage remediation return to
kotoamatsukami's impacted-test phase and byakugan's coverage phase before publishing. Aka does not run those phases.
Coverage instrumentation capture, extraction and threshold decisions belong in
byakugan's mukai run. Gyo is linting. Existing thresholds and required suites are preserved. A declared suite is skipped only with
a named proof that the change cannot affect its assertions and cannot cover any touched measurable
file; an ambiguous mapping runs.

## Discoveries during authorized work

[DISCOVERY.md](DISCOVERY.md) is the common capture/reconciliation protocol for every phase,
composite, reviewer and resumed run. It grants standing authority to file or fold concrete gaps
without another filing prompt, after Nen reconciliation and inspection of candidate issues and
open PRs. Unchanged evidence produces no write. New ownership is linked, not silently implemented.
Reports distinguish created, updated, folded, unchanged and pending; a real blocker is still a
blocker, but a discovery does not replace the original task.

The tool repositories now carry `nen/repos.json` for verified repository identity and
`nen/labels.json` for their existing GitHub labels. These are issue-routing/filing metadata, in
addition to the two execution/policy configuration files below. They do not assert consumer pins
or invent a stage taxonomy. `nen issue file` validates the target's labels; optional unrelated
color/gate schema failures are not reported as failed issue creation. Consumer metadata remains
owned and validated in its own checkout. See [LAUNCH-MIGRATION.md](LAUNCH-MIGRATION.md) for the
Nen #204 dependency, temporary workaround removal and the release hold covering Hatsu #49.

---

## Which gate a change stands at — ruling of 2026-09-18

**This document defines the *phases*; [`ROSTER.md`](ROSTER.md) defines the *gates*.**
[`ROSTER.md`](ROSTER.md) § *Rulings of 2026-09-18 — G4 is the repository's role, not the file's kind*
is the authority and carries the ruling, the incident behind it and the measured invocations. **This
section states only the consequence for the two configuration files § 1 is about, and deliberately
does not restate the rule or the path sets** — a second copy of either is the drift this document's
own precedence note exists to prevent.

**The consequence:** `nen/workflow.json` and `nen/contract.json` are **this** repository's canon, so
editing them here is **G4**. **The same two files in a consumer repository are that repository's own
setup, and editing them there is G2** — the file name is not the gate. The same goes for a consumer's
`nen/gates.json`, its CI workflow and its `scripts/` entries.

---

## 1 · Two files, and the line between them

There are two execution/policy configuration files, and the split is not stylistic. It is the difference between a
**fact about the machine** and a **decision about the work**.

| | [`nen/contract.json`](../nen/contract.json) → `project` | [`nen/workflow.json`](../nen/workflow.json) |
|---|---|---|
| **Answers** | *How is this repository built, tested, linted, launched and shipped?* | *How do we work in it?* |
| **Content** | lanes, per-verb argv, preconditions, hosts, deploy targets, launch targets, evidence globs, host toolchain | branch shape, which declared verbs run per iteration, the coverage ladder, reports, notifications, commit trailers, monitor caps, the model matrix |
| **Executed by** | `nen shu <verb>` — nen spawns exactly what is declared and nothing else | mostly the reader. Two verbs take a slice: `nen commit format --repo` reads `commits.allowedAttributionTrailers`, `nen shu coverage --touched` reads the `coverage` ladder |
| **Changing it changes** | what runs on this machine | what the roster is willing to do |
| **Validated by** | `nen schema check` (the `nen/contract.json` row) | `nen schema check` (the `nen/workflow.json` row) — both at the build `nen/contract.json` pins; dated evidence retains the version it actually exercised |

> **The nen DEPENDENCY is the third block of the first file, and its two version values move
> independently.** At the v0.24.0 repin `dependency.minimum` read `0.24` and `dependency.pinned_ref` read
> `v0.24.0` (`0.26` / `v0.26.0` since HA-PR-#422, `0.28` / `v0.28.0` since the HA#449 repin): the first is the capability minimum, the second is the build its
> bootstrap installs. That repin adopted NN#437's
> phase/usage dials, session ledger and report data `sessions[]`; older Nen cannot supply them. **The range `minimum`
> stands for is nen's answer, not a document's** — the binary ships `COMPATIBLE_MINOR_FLOOR`, the lowest
> `minimum` pin it satisfies, and `nen shu tools` applies it, prints it as `compat floor:` and carries it
> in `--json`. Per the maintainer's ruling of 2026-09-10 — *exact minor is fine, unless there is a
> breaking change* — `minimum` moves for a breaking compatibility floor or an adopted feature unavailable
> in earlier releases, while `pinned_ref` may move on its own to a newer release inside the
> range. Every PR that changes `dependency.pinned_ref` runs `bash scripts/direct_matrix_doc.sh --verify`
> with that newly pinned nen and quotes the complete `N printed claims agree ... <version>` output line
> in its PR body; this proves the readable routing matrix still agrees with the verb after a repin.
> Wherever this document says *"at nen `0.7.0`"* it names the build the fact was
> verified against, never the pin; [`../nen/contract.json`](../nen/contract.json) is the only place either value is
> written down, and the warm-up
> ([`ten`](../claude/skills/ten/SKILL.md) § 1) reads the verdict rather than computing
> it.

The reason to keep them apart is that they fail differently. A wrong `project` block produces a wrong
command — loud, immediate, exit `1` or `5`. A wrong `workflow.json` produces a *correct command run at the
wrong moment*, which is silent. Mixing them would hide the second class of mistake inside the first.

**Nen carries no build system and knows no tool's name.** Every verb of the `shu` family runs what the target
repository declares and refuses when it declares nothing. That is why a verb a repository does not have is an
explicit `{"unsupported": "<why>"}` **seat** rather than an omission: a seat is exit `4`, a stated fact in the
repository's own words; an omission is exit `2`, which reads as a broken declaration.

---

## 2 · `nen/workflow.json` — every key

The `$schema` is `nen.workflow/v0.1`. Every `$comment` key is Hatsu's own prose, preserved verbatim by nen's
loader and read by nothing in nen. **Hatsu's own copy** of this file is
[`../nen/workflow.json`](../nen/workflow.json); the values below are the shape and the defaults a repository
gets when it declares nothing.

### `pr.sections`

| Key | Default | Read by |
|---|---|---|
| `max` | `7` | resolver and sections guard; reader count only, never the compact footer |
| `variants` | every kind × family cell from `contracts/pr-sections.json` | `shibari`, `tensho`, `jujisho` before each body write |
| `$sections` | every available id and purpose, beside `sections` under `pr` | author and consumer configuration review |

`config_values.sh --fill` materializes the **full** default matrix and the `$sections` annotation;
it never overwrites an edited cell. That cell becomes consumer-owned, not a canon-following default.
[PR-SECTIONS.md](PR-SECTIONS.md) owns family folding, conditional run facts, the seven-section cap,
the kind-specific verification aids and the warning-only 150-word prose budget. `max` is configurable
up to seven; a smaller cap requires a fitting cell, never silent section truncation.

### `branch`

```json
"branch": { "template": "{model}/{persona}/{descriptor}", "base": "main" }
```

| Key | Default | Read by |
|---|---|---|
| `template` | `{model}/{persona}/{descriptor}` | `breath` (cuts it), `hooks/guard-base-branch.sh` (names it in the refusal) |
| `base` | `main` | `breath` (fetches it; never moves core's checked-out trunk), `ao` (pulls from it), `shibari` (opens against it), `getsuga` (its default cut point and `--trunk`), `ten` (its orient line and catch-up), `hooks/guard-base-branch.sh` (refuses a commit or a push on it) |

`{model}` is the **model alias** the actor is running on — `opus`, `sonnet`, `haiku`, `fable` — never a
version. `{persona}` is the roster persona it acts as. `{descriptor}` is a short kebab noun phrase for the
effort. So: `opus/kurapika/machinery-wave-1`. The template exists so that a glance at `git branch` says *who*
did the work and *on what*, which is the one thing a branch name is uniquely placed to carry.

### `iteration`

```json
"iteration": { "checks": ["build"], "lane": "<lane>" }
```

| Key | Default | Read by |
|---|---|---|
| `checks` | `["build"]` | **three phases, three questions** — `breath` on the fresh tip (*was the base sound*), `rasengan` as the author's inner loop (*does what I just wrote work*), `kokusen` over the finished tree before **every** commit (*is the tree I am about to record green*) |
| `lane` | `project.defaultLane` | all three, passed through as `--lane` |

Each entry of `checks` is the **name of a declared verb**, not a command line: each of those phases runs
`nen shu <check> --lane <lane>` for each entry, in order.

> **The compile-before-commit is `kokusen`'s, and `rasengan` is the AUTHORING phase** — the maintainer's
> ruling of 2026-09-10 ([`ROSTER.md`](ROSTER.md) HR-55, HR-56). The same pair of keys is read
> three times on purpose: a tree moves with every line written after the last check, so the only run a
> commit can rest on is the one taken by the phase holding the index. A verb named here that the lane seats as unsupported is
exit `4` and its seat is quoted, not worked around. Hatsu's own `checks` is `["lint"]`, because
`claude plugin validate . --strict` is the only mechanical check a markdown-and-bash plugin has.

> **The surface-mirror check is a step of the loop, and deliberately NOT a second entry here.** Hatsu ships
> generated Codex and Cursor mirrors of every skill and persona under `surfaces/`
> ([`docs/SURFACES.md`](SURFACES.md)), and [`scripts/surface_mirror_check.sh`](../scripts/surface_mirror_check.sh)
> fails when the committed mirror is not what the source generates. It is **not** a `lint`: the `plugin`
> lane's `lint` seat is `claude plugin validate . --strict` and stays exactly that — one seat, one meaning,
> and a second thing wearing the same name is how a declaration stops describing the repository. Nor is it a
> new declared verb, because nothing in `nen/contract.json` should name a script that only this repository
> has.
>
> **Where it runs, then:**
>
> | When | What |
> |---|---|
> | **Immediately after a `claude/skills/**` or `claude/agents/**` edit** | regenerate both surfaces (`docs/SURFACES.md` § 3) and commit the result **in the same commit** as the source change |
> | **Inside `mukai`, before `shibari` opens the PR** | `scripts/surface_mirror_check.sh` — exit `0` to proceed, exit `1` regenerate and amend, exit `2` **stop**: the nen on PATH is not the pinned one, since `v0.5.0` carries the verb |
> | **On the PR** | [`.github/workflows/surface-mirror-check.yml`](../.github/workflows/surface-mirror-check.yml) — **a real check at `nen/contract.json`'s pinned build**, advisory only until the maintainer requires the context. It skipped with a notice while `dependency.pinned_ref` named a nen with no `surface` verb; that branch is now an error. |
>
> The script writes nothing and needs no credential, so running it more often costs nothing but the seconds.

### `tests`

```json
"tests": { "required": ["test"], "extra": [] }
```

| Key | Default | Read by |
|---|---|---|
| `required` | `["test"]` | `kotoamatsukami` at mukai; red is a **G5** stop inside `mukai` |
| `extra` | `[]` | `kotoamatsukami`, considered after `required` and reported separately |

An **empty `required` is a statement, not an omission**: it says this repository has no automated suite, and
`kotoamatsukami` reports that rather than inventing a runner. **With `required` and `extra` both empty the verdict
is `not applicable — no tests configured` — never green.** Nothing ran, so nothing passed, and `mukai` reads
that word as *nothing to prove* and says so rather than converting it into a pass. It is
not a G5 either: an empty required set is not a red suite. A test is never patched to pass.
`tsukuyomi` does not read these keys; it runs one explicit scoped lane on every ren turn that
changed executable behavior.

### `coverage` — the ladder

```json
"coverage": { "minimum": 80, "recommended": 85, "ideal": 90, "scope": "touched" }
```

| Key | Default | Meaning |
|---|---|---|
| `minimum` | `80` | **the stop.** A touched file under it is a **G5**: `byakugan` adds tests until it clears, or the maintainer decides |
| `recommended` | `85` | the band `byakugan` aims for and reports against |
| `ideal` | `90` | the band worth saying out loud when it is reached |
| `scope` | `touched` | line coverage of the files in `git diff --name-only origin/<base>...HEAD`, **not** the repository total |

Three numbers rather than one, because a single threshold turns into either a gate that blocks honest work or
a number nobody looks at. The ladder reports bands and stops only at the bottom rung. **The bar is never
lowered to clear it** — that is the one move `byakugan` will not make, and a repository that cannot honestly reach
`minimum` is a G5, not a smaller number.

`nen shu coverage --threshold <n>` **reports** `met: true|false` and never changes its exit code; nen does not
decide whether a number is good enough. At nen `0.7.0`, `--touched --base <ref>` filters the rows
to the files the diff names and — with no `--threshold` — reads the ladder here itself, printing a `ladder:`
line and a `band` per row (`under-minimum` / `minimum` / `recommended` / `ideal`). It still never gates.

**Hatsu's own shell guards are measured on their focused lanes** (zheref/hatsu#148, UZF-19). A measured lane
runs its `scripts/*.sh` fixture through `scripts/shell_coverage.mts`: with the pinned Bashcov, a Bash 5+
and the three pinned gems (Bashcov, SimpleCov, simplecov-lcov) that `nen/contract.json` → `project.toolchain` declares (`nen shu tools --repo .
--install` puts the gems in the user gem home), its `test` row writes `coverage/<lane>/lcov.info` and nen
records the capture; `nen shu coverage --lane <lane> --repo . --touched --base origin/<base>
--from-capture` then reads that capture and runs no fixture, and byakugan passes `--from-capture` on these
lanes. The `coverage` row is extraction only, and it refuses a report whose `provenance.json` (the
sha256 of the report and of every file it names) no longer matches the tree. The gems are pinned by
version, not by checksum, in nen: its `gem-user` installer carries no digest, so each row's `gemSha256`
(the rubygems.org SHA256 of the `.gem`) is checked by the helper against the installed cache before
anything runs under it: a mismatch refuses, and an absent cache runs the lane uninstrumented. SimpleCov is activated at its pin before Bashcov. The
gems install into the shared user gem home, where a plain `require` in another project also finds them;
remove one with `gem uninstall --user-install <gem> -v <version>`. No dependency-audit row covers them
(`contracts/scans.json` selects rows by stack, and a host toolchain is none): they are **not scanned**.
A `nen shu tools` exit `5` on these rows alone is *unmeasured, still testable* (PROCESS § *Exit codes
and refusals*). Without
Bashcov the fixture still runs, once and uninstrumented, and says so, and `--from-capture` refuses for want
of a capture: unmeasured, never a clean zero. A POSIX `sh` fixture runs under `sh` first, then
instrumented. Only scripts the fixture executed in place are reported, so a script a fixture copies to a
temporary root, or one another lane exercises, is `unmatched` here. A trace Bashcov cannot parse
captures nothing; a run that also exited non-zero is re-run plain, and that run's exit decides. A lane
whose fixture Bashcov cannot measure yet (its trace leaks into the output the fixture asserts on, or
cannot be parsed) seats its
`coverage` row with that reason instead. `HATSU_SHELL_COVERAGE=0` skips the
instrumentation and `require` refuses without it. The TypeScript guards have no line-coverage tool
declared yet (the `plugin` lane's `coverage` seat). The ladder above is unchanged.

### `launch`

```json
"launch": { "default": "<target>", "fallback": "<target|null>" }
```

`default` and `fallback` name keys of `project.launch` (§ 3). `amaterasu` starts `default`; when its device
is not connected it reports the device **by name** and falls back to `fallback`, or stops if that is `null`.

**A `null` `default` with no `project.launch` is the no-launch case, and it is an answer.** Hatsu's own are
both `null`, and it declares no `project.launch` at all: a plugin is loaded by Claude Code, not launched. In
that repository `amaterasu` records **`no launch target declared; skipped`** in the turn report and continues
to `spiritual-message` and `jutaisho` — **it does not ask**. `ren` reaches the phase every turn, so a question there
would be a question per turn about something the configuration already settled. The case that *does* ask is a
repository whose `project.launch` declares targets while `launch.default` is `null`: that is an unanswered
question, not an answered one.

### `deploy`

```json
"deploy": { "defaultTarget": "<a key of project.targets, or null>" }
```

**Read by [`kagutsuchi`](../claude/skills/kagutsuchi/) § 1; validated, never acted on, by nen from `v0.21.0`** (zheref/nen#300: `nen schema check`
FAILs a `defaultTarget` naming an undeclared target or one not marked `project.targets.<name>.nonProduction: true`,
so a default target carries that flag as well as a non-production `why`; zheref/hatsu#146; the maintainer's
ruling of 2026-09-29: *"rely on a default value from one of our configuration files … so that it
doesn't always require destination and it can be easily chained with other skills like futon"*).
`defaultTarget` names the destination a `hatsu:kagutsuchi` invocation typed with **no target** sends to — **a typed target always overrides it, the report says which source the target came
from** (`typed` or `workflow.json → deploy.defaultTarget`), and it is honoured **only for a target whose
`why` reads non-production**: a default naming a store or the live environment is refused, and **G3**
(`mugetsu`) is unchanged. `nen shu deploy` is unchanged too — the skill always passes `--target`
explicitly, so *nen never chooses where a build goes* stays true of nen; the choice lives here, in
configuration the maintainer wrote. **`null`, or the key absent, is the ask**: an omitted target is
typed as free text (`missing-maintainer-choice`), exactly as before. Hatsu's own is `null` — a plugin
declares no deploy target. A per-stack default in `nen shu detect`'s reference pack, and validation of this key by pointer, are nen's to
add ([zheref/nen#300](https://github.com/zheref/nen/issues/300)).

### `reports`

```json
"reports": { "dir": "Reports", "retain": "final-only", "template": "spiritual-message",
             "captures": "Reports/captures" }
```

| Key | Default | Meaning |
|---|---|---|
| `dir` | `Reports` | **git-ignored.** The only directory a report is ever written to |
| `retain` | `final-only` | **the retention rule — what is KEPT**; see below |
| `template` | `spiritual-message` | `templates/<name>.html` in this repository |
| `captures` | `Reports/captures` | where screenshots land before they are inlined as data URIs |
| `sections.<variant>.template` | — | which of `templates/*.html` this variant renders: `spiritual-message` for `turn`, `turn-fast` and `landing`, `rikugan` for `final` and `register` |
| `sections.<variant>.blocks` | — | the block names this variant renders, injected as `sections.<block>` presence flags by `nen report render --variant`. **Required and non-empty**: a variant with no `blocks`, an empty one, or no `template` makes nen refuse the whole file (exit `1`); an undeclared variant, or a file with no `sections` at all, is exit `2` — nothing renders. **The adoption sentence, stated once here** (zheref/hatsu#108): a repository that has never declared `sections` sets up the five-variant block [`docs/config/workflow.json.md`](config/workflow.json.md) § `reports` documents as `missing-configuration` (§ 4) at the first phase that will render, the write landing as § 4 step 3 says — on the effort's branch or its own PR; the rendering skills cite this line and name no default |
| `timeZone` | the host's zone | the IANA zone every report's clock is said in (`America/Bogota`); see *Report time* below |

**The template language `nen report render` fills these with.** `{{token}}` (escaped),
`{{{token}}}` (raw), `{{#each list}}…{{/each}}` with `{{.}}` and `{{@index}}`, and
`{{#if key}}…{{/if}}`. No helpers, no partials, no expressions. An unknown token is exit `2` naming
it; `null` renders empty; an object at a value tag is refused. `--dry-run` reads the file exactly as
the render does, so a template is proved against a document before it ships. **A template never
spells a substitution tag in its own comments**: the renderer substitutes over the whole file,
comments included.

**Which blocks a report renders is configuration, and so is who renders it** (maintainer's ruling,
2026-09-19). Five variants are declared: [`spiritual-message`](../claude/skills/spiritual-message/SKILL.md) renders
**`turn`** every Ren turn, **`turn-fast`** at the same step under the fast profile (desk and last
turn only) and **`landing`** at `mukai` step 9 and `en` step 1;
[`backlog-board`](../claude/skills/backlog-board/SKILL.md) § 3 renders **`register`** for its own
board and for `futon` and `backlog-loop`, and **`final`** — the dated report — through the same verb.
Every value inside a block is the model's; only the presence flags come from this file.

**Report time — the reader's clock, the document's instant** (maintainer's request, 2026-09-22).
`generatedAt` stays what `nen report data` and `nen board build` stamp — an absolute ISO-8601 UTC
instant, the document's truth — and the page shows it through `<time datetime="{{generatedAt}}">`
with **`generatedAtLocal`** as the visible text. Both templates require that token, so a render
missing it is exit `2`, never a UTC clock read as local. **The plain `nen report data` fills it** from
nen `0.22.0`, with `generatedDateLocal` and `timeZone` (pass `--tz <reports.timeZone>` when it is set).
**Two documents take it from one call at the plugin root** (`ten` § 0) instead: a hand-built one, and a
`--register` desk — nen keeps the desk's `generatedAtLocal`, writes the raw UTC `generatedAt` into it
when the desk carries none, and returns `timeZone` and `generatedDateLocal` `null` when it does. Their
`<generatedAt>` is the `generatedAt` that effort's `nen report data` stamped (for a desk, the plain
pass's):

```bash
"$hatsu_root/scripts/report_time.sh" --at <generatedAt> [--tz <reports.timeZone>]
```

`--tz` is passed when `reports.timeZone` is set; absent, the script reads `$TZ`, then the host's
`/etc/localtime`, then `UTC`, and it **refuses** a name outside the zoneinfo database rather than let
`date(1)` answer UTC silently. It prints `generatedAtLocal` (`Tue 22 Sep 2026 · 14:05
America/Bogota (UTC-05:00)`), `timeZone`, and **`generatedDateLocal` — the `<YYYY-MM-DD>` of the
dated report's file name**, so a report finished late in the evening is filed under the day it was
finished where it was read, not under tomorrow's UTC date. Without `--at` it prints nothing on stdout
and exits `2`.

**Privacy: the zone name is printed on every page.** `America/Bogota` in a masthead tells every
reader of a published report roughly where its maintainer sits. Where that is more than a repository
should say, set `reports.timeZone` to a fixed-offset zone — `Etc/GMT+5` keeps the same clock as
Bogota without the city (POSIX sign: `Etc/GMT+5` is UTC−05:00) — and note that a fixed offset does not
follow daylight saving.

#### Report titles — a headline, never the branch

(Maintainer's request, 2026-09-22.) The `title`
token is the page's `<h1>`, its `<title>` and so the Artifact's name, and a branch name repeated
there says nothing the masthead's meta line does not already say. For `turn`, `turn-fast`,
`landing` and `final` it is **one synthesized headline, at most 60 characters, naming what the
effort delivers** — session-wide, not this turn alone (*Report times in the reader's zone*, never
*opus/kurapika/localized-report-dates* or *Turn 3*): written from the requests and *Landed*, with a
landing or final report taking the PR's own title where one exists. Before anything has landed it is
the request's own phrase. It carries **no branch, ref, notation or turn number** — those are the
meta line's (`repo`, `branch`, `base`) and the last-turn block's — and it **stays put across turns**
unless what the effort delivers has changed. `register` keeps its fixed *Gate Register*. The
Artifact address is keyed on the branch, never on the title, so a better headline never mints a new
URL. A notation cited anywhere on the page is still `nen ref format`'s, never memory.

#### Where the effort is — said every turn, in two places

(Maintainer's request, 2026-09-22.) Every
Ren turn ends with the effort's **stage** and **gate** visible without scrolling: at the top of the
turn's chat line ([`ren`](../claude/skills/ren/SKILL.md) § 6) and on the report page, whose masthead
carries a turn badge on the eyebrow, the title, a meta line (repo, base, local time) and **a second,
separate status line** — stage, gate, worktree, branch — repeated in the footer. The values are
derived, never recalled:

| Stage (`effortStage`) | When | `gate` | `stageClass` |
|---|---|---|---|
| `authoring` | commits on the branch, not on `origin` | `none — local` | `info` |
| `published` | on `origin`, no pull request | `none — pushed` | `info` |
| `in review` | PR open, `nen pr ready` not ready | `G2` / `G4` (`nen gate derive`), `pending` | `warn` |
| `ready` | PR open, `nen pr ready` ready | `G2` / `G4` — yours | `red` |
| `blocked` | a G5 stop open this turn | `G5` — yours | `red` |
| `landed` | PR merged | `none — landed` | `ok` |

Pushed or not is `git rev-parse --verify --quiet origin/<branch>` after the fetch; the PR and its
verdict are `nen report data --target … --prs <n>`'s row and `nen pr ready`'s line. **`turnLabel`**
is `Turn <n>`, `n` being `nen report data`'s `turnNumber` (from `0.22.0`: the `report` entries of the
ledger whose effort id is the branch's name, the open one included; a `null` `turnNumber`, with no
ledger, counts the turns this session has reported); a `landing` reads `Landing · after turn <n>`. **`worktree`** is the checkout's directory name when `git rev-parse --git-dir` and
`--git-common-dir` differ, else `core`. Red stays reserved for needs-you: only `ready` and `blocked`
are red. **`repo`** is `nen report data`'s hosted `owner/name` from nen `0.20` (zheref/nen#375), `null`
for a local-path or `file://` origin, which the caller fills from `nen repo resolve --from <path>`; before
`0.20` it was the checkout's directory name, the worktree's in a worktree.

#### Retention — what `retain` keeps

**The retention rule — and what it does *not* say.** A report is published at three moments — every
turn, at landing, and once current-head readiness is verified — and `retain: final-only` means **only
the last one is KEPT**: the **`final`** variant, a one-effort Rikugan with a cleared desk —
[`hatsu:rikugan`](../claude/skills/rikugan/SKILL.md), callable on any completed workflow or named scope
(ruling 2026-09-30), rendered through [`backlog-board`](../claude/skills/backlog-board/SKILL.md) § 3 to
`<reports.dir>/<YYYY-MM-DD>-<effort>.html`. A directory holding one report per turn is a directory
nobody opens; the final one is the one with the register, the tests run and the touched coverage on
it, and it is the one worth finding six months later.

**It is a rule about what survives, not about whether a working file exists** (maintainer's ruling,
2026-09-09). Turn and landing reports are published to the conversation as an Artifact; on a surface that
cannot publish one they are opened from the **transient** `<dir>/current.html` — one path, rewritten by every
render, never dated, git-ignored. That file is **admitted** under `final-only`, because a page that is always
the latest render and can never be found again after the next turn is not a retained report. `dir` is
git-ignored for the same reason a build output is: it is derived, and a derived file in git is a merge
conflict waiting to be resolved by coin toss.

### `mukai`

```json
"mukai": { "autoEn": false }
```

| Key | Default | Read by |
|---|---|---|
| `autoEn` | `false` | `mukai` only. **Only JSON `true` starts `en` immediately** once the PR is open and the landing report rendered; `false`, absent or any other value makes mukai ring the turn bell and ask through the surface's native picker whether to start `hatsu:en on <CODE>#<N>` now (rulings 8 and 9 R4). `nen schema check` tolerates the block (it does not validate it) |

### `classify`

```json
"classify": { "publish": "label" }
```

| Key | Default | Read by |
|---|---|---|
| `publish` | `label` | `classify` only, standalone, under `build`, and under `file` (and the filers composing it) once the issue is created — never under `ren` or for an inline effort; read at the default branch's tip, never the checkout. **`label`** (absent or any other value reads the same) applies the `lang/` and `job/` labels only; **`label+comment`** adds one marker-keyed criteria comment per classified issue — every decided key with its confidence, status and signal category, unapplied keys marked *not applied* with their reason, never issue text ([`classify`](../claude/skills/classify/) § 5b; `contracts/classify.taxonomy.json` → `publish`). The maintainer's request of 2026-10-20; `nen schema check` tolerates the block |

### `direct`

```json
"direct": { "publish": "none" }
```

| Key | Default | Read by |
|---|---|---|
| `publish` | `none` | `direct` only, under `build`, under `file` once the issue is created (file § 5), or standalone on an issue — never under `ren`, which cannot leave the machine (ren § 3). **`none`** (absent reads the same) keeps the verdict in the report and the local ledger `.nen/direct/<effort>.json`; **`label`** applies the primary pick's model **line** as one `model/<line>` label (`claude`, `gpt`, `gemini`, `grok`, `composer`) through `nen label apply`, a label the consumer's `nen/labels.json` has not declared being the verb's refusal; **`label+comment`** adds one marker-keyed issue comment carrying the primary, fallback and recommended picks with tier, surface, effort dial and the live-read version ([`direct`](../claude/skills/direct/) § 7; `contracts/direct.registry.json` → `publish`). The maintainer's ruling of 2026-10-05; `nen schema check` tolerates the block |

### `port`

```json
"port": { "handbooksRepo": "zheref/bankai-handbooks", "rulingsDir": "handbooks/ports" }
```

| Key | Default | Read by |
|---|---|---|
| `handbooksRepo` | `zheref/bankai-handbooks` | [`bankai-rule`](../claude/skills/bankai-rule/) § 2 (and the port composites `hiraishin`, `kamui` — zheref/hatsu#357, #356, not yet shipped): the canon handbooks repository a port ruling lands in — read at the consumer's pinned tag (`nen/repos.json` → `pinned`), authored in a separate clone at the cache path, never the canon checkout (zheref/hatsu#354, *Checkouts*). The estate's canonical home (`CON-13`); the value must be the consumer's own pinned `maintained_tools` row (`nen canon pin --source`), read at the base tip, so rulings and the matrix come from one home — a value with no pinned row is `missing-configuration` |
| `rulingsDir` | `handbooks/ports` | the same skills, [`limbo`](../claude/skills/limbo/) step 4 and [`bankai-handbooks`](../claude/skills/bankai-handbooks/) § 2: the directory holding the ports family — one directed pair file `<from>--<to>.md` per scenario pair, rendered from `templates/ports/pair.md`, and its `INDEX.md`. A pair file is passed to `nen canon resolve --always-load` beside the always-load set until zheref/nen#457 resolves it as a port handbook. `nen schema check` tolerates the block; the domain is the catalogue's ninth, `port` (zheref/hatsu#354 criterion 4) |

### `aiReviewers`

```json
"aiReviewers": "required"
```

| Key | Default | Read by |
|---|---|---|
| `aiReviewers` | `required` | `sharingan` § 6 and `en` §§ 5–6; `nen pr ready` and `nen pr merge --release-unit` (nen 0.26). One value for **every automated reviewer** in `nen/gates.json` → `reviewers[]`, gating both their **use** (whether a round is requested) and their **expectation** (whether readiness waits for it). **`required`** (absent reads the same) — requested within `round_policy`'s caps and expected; **`optional`** — requested within the caps, never waited for; **`off`** — never requested, zero spend on requested reviewers (installed CI lanes still run). Under `optional` and `off`, nen waives the round of a reviewer `nen/gates.json` declares `kind: "bot"` identically at both refs, so such a PR reads `ready`, hanten settled ([HR-333](ROSTER.md#hr-333)). A PR whose `nen pr ready` still fails only on `rounds-owed` goes to the merge prompt on hanten's rounds, the not-ready verdict quoted verbatim. The rule is [`PROCESS.md`](PROCESS.md) § *Reviewer rounds and review threads*, *AI reviewers per consumer*; the maintainer's rulings of 2026-10-11 (zheref/hatsu#245). Read at the PR's **base** and the **default branch's tip**, the stricter applying, never the PR head, so a change takes effect once merged; for the hanten prompt under `optional`/`off`, every `reviewers[]` entry must also be in `round_quorum.any_of` with an anchored `login_pattern` at both refs, and none may be `kind: "human"`. Hatsu's own value is `optional`, and its Copilot entry is `kind: "bot"`. `nen schema check` tolerates the key; `round_policy.maxRounds: 0` is **not** an off switch (nen still owes the round), this key is. **CI reviewer lanes included** (ruling 2026-10-19, *"One value for every bot"*): a lane is never requested under any value, so for a lane the value gates only the expectation — PROCESS, *Event-driven reviewer lanes* |

### `port`

```json
"port": { "specKit": { "pin": "v1.2.2", "layout": "specs/{nnn}-{slug}" } }
```

Read in a product family's **spec repository** (role `spec`, [`config/repos.json.md`](config/repos.json.md) § `families[]`); `nen schema check` tolerates the block. Both catalogue rows apply only where a `port` block exists (`when`), so `fill` never writes them into an unrelated repository. The epic's `handbooksRepo` and `rulingsDir` land with `bankai-rule` (zheref/hatsu#355).

| Key | Default | Read by |
|---|---|---|
| `specKit` → `pin` | `v1.2.2` | `kamui` §§ 2–3 and `dowsing-chain` §§ 3–4: the `github/spec-kit` release whose file set and paths the spec step writes (`specs/<nnn>-<slug>/`'s seven entries plus `checklists/requirements.md`, and `.specify/memory/constitution.md` once, citing `CON-{n}`, never overriding it). Read live on 2026-10-20 as the latest release; moved by the spec repository's own declaration PR |
| `specKit` → `layout` | `specs/{nnn}-{slug}` | `kamui` §§ 2–3 and `dowsing-chain` § 4: where one feature's folder is written; `{nnn}` is the next free three-digit number (spec-kit's `sequential` numbering), `{slug}` a kebab phrase from the source's title. The source object is cited in `spec.md`'s header and searched for before a new folder opens |

### `intake`

```json
"intake": { "challenger": { "brief": "satotz", "spec": "lippo", "platform": "buhara", "rendered": "bisky" } }
```

Hatsu's own block (ROSTER HR-21, HR-24, HR-38), read from **Hatsu's checkout only**, never a consumer's; `nen schema check` tolerates it. The four catalogue rows apply only where the block exists (`when: nen/workflow.json#intake`), so `fill` writes nothing into a consumer. Full description: [`config/workflow.json.md`](config/workflow.json.md) § `intake.challenger` and [`INTAKE-CHALLENGE.md`](INTAKE-CHALLENGE.md) § 1.

| Key | Default | Read by |
|---|---|---|
| `challenger` → `brief` · `spec` · `platform` · `rendered` | `satotz` · `lippo` · `buhara` · `bisky` | `emperor-time` § 4: every examiner whose artifact a brief matches challenges it (HR-25); a key missing from the map goes to `satotz` (HR-26); the map routes challenges only — Bisky drafts the Design Direction and Satotz challenges it by name |

### `ci`

```json
"ci": { "provider": "AK", "pinned": "v1.0.0", "tiers": ["reviewers"],
        "rulings": { "hidan": "off", "claudeAuth": "claude_code_oauth_token" } }
```

**Hatsu's own block, written by [`kuchiyose`](../claude/skills/kuchiyose/SKILL.md) at install** (zheref/hatsu#331) through
`scripts/config_values.sh set`, one key per answer — never a hand-typed guess. It records which CI tier a
consumer installed and the answers it was installed with; **absent means no tier is installed**. It is read
today by `kuchiyose`; `pinned` is also read by nen's warmup pin sweep (`nen warmup --ci-registry`, from nen `0.26`, zheref/nen#440);
`tenkai`'s caller drift row is owed with the provider's tier catalogue. `nen schema check` tolerates the block (it does not validate it; checked
against nen `0.26.0` on 2026-10-23).

| Key | Default | What it carries |
|---|---|---|
| `provider` | — | the CI provider, by its **product code** (`AK`, the Akatsuki CI repository), resolved through `nen/repos.json` (zheref/hatsu#329's ruling of 2026-10-19), so a consumer's `nen/workflow.json` carries no slug |
| `pinned` | — | the provider's **release tag** the consumer's caller workflows reference (`uses: …@<tag>`) and the tier catalogue is read at — never a branch; `nen warmup --ci-registry` sweeps it against the provider registry's `latest` (nen `0.26`, zheref/nen#440) |
| `tiers[]` | `[]` | the installed tiers, by catalogue key — `reviewers` today, the lanes Sasuke, Kakuzu, Konan and Hidan; a later tier appears in the catalogue with no skill change |
| `rulings{}` | `{}` | the per-consumer answers the catalogue's `rulings[]` lists, each asked at install through the picker: `hidan` (`on` \| `off` — *"Per consumer at install"*) and `claudeAuth` (`claude_code_oauth_token`, starred, \| `anthropic_api_key` — *"Ask at install, OAuth starred"*; the credential **type**, never its value, which lives only in the consumer's Actions secret store); the maintainer's rulings of 2026-10-19, [`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-19 — the CI reviewers tier* |

The lanes' `nen/gates.json` entries and the quorum `kuchiyose` writes beside this block are
[`PROCESS.md`](PROCESS.md) § *Reviewer rounds and review threads*, *Event-driven reviewer lanes*, with the
two entry shapes in [`GATE-CONFIGURATION.md`](GATE-CONFIGURATION.md) § 3. Hatsu itself declares no `ci`
block until it installs the tier through `kuchiyose` like any consumer.

### `review`

```json
"review": { "scopes": { "code": { "persona": "nobunaga", "tier": "deep", "budget": 2,
                                  "paths": ["**"] }, … } }
```

**The path-to-reviewer map [`hanten`](../claude/skills/hanten/SKILL.md) classifies a change set
with**, read by `nen review scopes --base <ref> --repo <path> --json` and never by a hand table.
One row per scope:

| Row key | What it carries |
|---|---|
| `persona` | the agent file raised for this scope — `claude/agents/<persona>.md`. A scope whose persona has no definition is a **gap**, never improvised past |
| `tier` | `models.<surface>.<tier>` of the `models` block below, read at use, **never the frontier tier** |
| `budget` | reviews of this scope **per effort** — a branch plus its PR — counted in `.nen/hanten/<branch-slug>[-pr<N>].cycle.json` by `nen review ledger`, which reads this value; never per session or repository, and a new PR number starts full. Remediation does not reset it (ruling 2026-09-28, ROSTER ruling 9 R2) |
| `paths` | prefixes or globs in `nen report data`'s tier-table grammar. **One path may raise several scopes**, and a path no row claims is reported as `unclaimed` |

**`code`'s `paths` is `**`, deliberately: it claims every path**, so Nobunaga is the default reviewer
on every change set and no diff is reviewed by nobody. The other seven are raised by their own paths —
`security` (Feitan), `architecture` (Chrollo), `ui` (Hisoka), `performance` (Uvogin), `surfaces` (Phinks),
`release` (Phinks) and `economics` (Leorio, **by path or by content** — [`ECONOMICS.md`](ECONOMICS.md) § 1
is the one home of both predicates — and never on every diff).

**One tier is swapped rather than read.** `nen repo classify` answers `kind`; a **`process`** or
**`library`** repository takes the declared `review.scopes.code.tier` (`deep`), and a **`product`** one
swaps Nobunaga to **`fast`**. Hanten says which ran. No other row's tier moves, and the declaration is
never edited to get a different one for one run.

### Repository kinds — what `nen repo classify` answers

**Maintainer's ruling of 2026-09-26** ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-09-26/27/28*). `nen repo classify --target <owner/name> --json` reports one
`kind`, and this is the one place hatsu canon defines the three; every skill that reads it cites this
section and restates nothing:

| `kind` | What it is | How it is read |
|---|---|---|
| **`process`** | Plugins and machinery — the repositories whose product is the way of working, `zheref/hatsu` (`claude-code-plugin`) and `zheref/nen` (`bun-cli`) among them; CLIs are process | derived from the lanes' stacks, or declared |
| **`product`** | An application or service that a release deploys to an environment or uploads to a store | derived from the lanes' stacks, or declared |
| **`library`** | Reusable code, on any stack, maintained to be shared across repositories — products, and other process or library repositories | **declared only**: `nen/contract.json` → `project.kind: "library"`; nothing derives it |
| `unknown` | Nothing in the lanes says, and nothing is declared | the fallback, never a verdict |

A declared `project.kind` (`product`, `process` or `library`) is the repository's own word and wins
over the derivation; `sources.kind` in the `--json` names what the lanes alone would have read. The
declaration is a `nen/contract.json` change and **lands through that repository's own declaration
gate** (HR-76, HR-77: G4 in a canon repository, G2 in a consumer one) before anything
reads it. What the kind decides: the reviewer tier above, and whether [`mugetsu`](../claude/skills/mugetsu/)
§ 3's advance go may name it — `process` and `library` may, `product` and `unknown` may not.

### `notifications`

```json
"notifications": { "rungs": ["push", "os", "sound"], "sound": "Glass", "turn": "rung1" }
```

`jutaisho`'s ladder, innermost first: `push` is the surface's own turn-complete signal, `os` an OS
notification, `sound` a system sound. **A rung absent from the list is not rung.** `sound` names
`/System/Library/Sounds/<sound>.aiff` on macOS. See § 6 for who actually rings rungs 2 and 3.

`turn` decides **how loud an ordinary turn is** — the one with no gate: `"rung1"` (the default, and the
value when the key is absent) rings the surface's own line and nothing else; `"all"` rings every rung
`rungs` lists, every turn. A gate always rings everything `rungs` lists, whatever `turn` says, and `turn`
can never conjure a rung `rungs` withheld. It exists because the two readings of "does a plain turn ring?"
were both supportable in `jutaisho`'s text and disagreed about every turn of every effort; one declared
value settles it. **`turn` is IN the `nen.workflow/v0.1` shape at nen `0.7.0`** — a closed set of
`"rung1"` and `"all"`, refused by pointer on anything else, and written into every policy file
`nen scaffold init` generates. It began as a Hatsu addition; the retirement is recorded in
[`claude/skills/jutaisho/SKILL.md`](../claude/skills/jutaisho/SKILL.md) § Residue.

### `commits`

```json
"commits": { "allowedAttributionTrailers": ["Hatsu-Agent", "Akatsuki-Agent"],
             "forbiddenTrailers": ["Co-Authored-By", "Claude-Session", "Signed-off-by", "Generated-by", "Generated-with", "Reviewed-by"] }
```

**Maintainer ruling, 2026-09-12: canonical persona attribution stays on commits.** A prospective commit
carries the truthful `Hatsu-Agent` or `Akatsuki-Agent` trailer for its responsible persona or autonomous
plane. Model, surface, runtime, session, and generated-credit attribution are forbidden. Do not infer a
persona from a runtime alias or stamp a default persona blindly. Existing commits and dated transcripts
are historical and are not rewritten.

The first heading of every PR body is `## Delivery`, reporting surface, recorded model and alias,
effort dial and session from the effort's ledgers. This reverses only the PR-body half of the
2026-09-12 ruling (maintainer ruling 2026-10-19); `CON-51(c)` and commit messages stay as above.
The final heading is [`## Agent attribution`](AGENT-ATTRIBUTION.md): a ledger
of each actual participant's canonical Hatsu persona, role/contribution, and evidence. Runtime
alias/display name and model are not recorded in that final section and never replace the canonical persona. Commit
messages may still carry ordinary non-attribution trailers such as `Closes` where appropriate.

[`hatsu:shibari`](../claude/skills/shibari/SKILL.md) owns the PR-body ledger. [`hatsu:kokusen`](../claude/skills/kokusen/SKILL.md)
and [`hatsu:aka`](../claude/skills/aka/SKILL.md) enforce canonical-only commit attribution.

**Turning the harness's own mandate off is a required setup step, not a configured fact — check it.**
Claude Code can add `Co-Authored-By: Claude …` to commits it writes, and the setting that stops it is
`includeCoAuthoredBy: false` in `~/.claude/settings.json` (or the project's `.claude/settings.json`).
**It is not set on this machine**: verified 2026-09-10, `~/.claude/settings.json` carries no
`includeCoAuthoredBy` key at all. So read this paragraph as an instruction with a check attached, not as a
statement about how the machine is:

```bash
grep -n includeCoAuthoredBy ~/.claude/settings.json        # no output = not set
```

No output means the harness default applies and layer (a) below is the only thing standing between a
harness-written trailer and a commit. Add `"includeCoAuthoredBy": false` to that file, on every machine
that drives this workflow. **Saying it is configured off when nobody has configured it makes the
three-layer table read one layer stronger than it is**, which is the failure mode the table exists to
prevent.

**Cursor has its own mandate, and `includeCoAuthoredBy` does not reach it** (zheref/hatsu#66). Cursor
appends `Co-authored-by: Cursor <cursoragent@cursor.com>` at `git commit` time, at the tooling layer and
before hooks run — observed on the raw `git commit --file` residue path (HA-PR-#64's `4ee8ce3`,
`c202034`, `516ed5f`, `75c8ce8`, `2025e84`, `06b45cf` carry it beside `Hatsu-Agent`). **From nen
`0.19` the two verbs catch it themselves** (zheref/nen#357): `nen commit write` and `nen wc squash` read
the commit they just wrote back through git's own trailer parser and exit `3`, with the refused keys
in `injected[]`, when a hook added one. The commit exists at exit `3`, and nen prints the undo that
applies. The off-switch is Cursor's: **Cursor Settings → Git & Pull
Requests → *Commit Attribution* off** (and *PR Attribution*), or for the CLI
`"attribution": { "attributeCommitsToAgent": false }` in `~/.cursor/cli-config.json` — Cursor's own
forum answer of 2026-08-21 ([`docs/surfaces/cursor.md`](surfaces/cursor.md) § 9 quotes it, § 10 the
executor path reported to ignore it and the second `Made-with: Cursor` trailer); **forum-sourced and not
verified live on this host, which runs no Cursor**. The switch is per machine, harness-owned and
unverified, so two readings stand together: the verbs' own exit `3` (`kokusen` § 5 and `aka` § 4 map it),
and `aka` § 7, which reads **every outgoing commit** immediately before `nen wc publish`, because a
clean catch-up merge is written by `nen wc catch-up`, which reads no trailers back (`git -C <path> log
<the SHA ls-remote printed | origin/<base>>..HEAD`, after § 5's catch-up and § 6's re-lint — ao may add a merge
above the squash, so the tip alone would miss the squash parent the push also sends). **What they classify is an
attribution key, and this is the one rule for it:** a trailer key that ends in `-by` or `-with`
(case-insensitive — `Co-authored-by`, `Signed-off-by`, `Reviewed-by`, `Generated-by`, `Made-with`) or
that `commits.forbiddenTrailers` lists is an attribution key; every other key — `Closes`, `Fixes`,
`Refs`, `See-also` — is an ordinary trailer, permitted above, and never compared. An attribution key
outside `allowedAttributionTrailers` (keys compared case-insensitively, as nen's layer (c) compares) is
a stop with the default `nen/decisions.json` row `injected-attribution-trailer` states — the
just-written commit is dropped or re-squashed; the switch is row `harness-attribution-switch`, an ask
the maintainer answers by toggling the harness (no skill writes that file); a published commit is never
rewritten and is disclosed by `shibari` in the PR body's checklist. Layer (b), where a repository carries it, is the only mechanical refusal in that path; this
repository does not carry it.

```bash
grep -n '"attributeCommitsToAgent": *false' ~/.cursor/cli-config.json   # no output = Cursor's default applies; the IDE toggle has no file check here
```

**Enforcement is three-layered, and at nen `0.7.0` two of the three are mechanical.**

| Layer | What refuses | Where it lives | Live at nen `0.7.0`? |
|---|---|---|---|
| **(a)** the **skills'** own refusal — `kokusen` reads the rendered message before it commits and the written tip after (§ 5), `aka` the message before it squashes and every outgoing commit immediately before it pushes (§ 7) | agent-side | this repository | **yes**, and it is the layer Hatsu ships |
| **(b)** the target repository's **`commit-msg` hook**, generated from `allowedAttributionTrailers` by `nen scaffold init` | the target repository's `.git/hooks/` | **target-dependent** — it exists only in a repository `nen scaffold init` has stood up; this week in `zheref/nen`; `<product-repo-A>` and kro-pwa already carry one | **target-dependent** |

> **From nen `v0.6.0` that hook's automated half is DERIVED from the repository's own policy, not a fixed
> pair baked into the generator.** It requires exactly the ONE attribution trailer `--agent-trailer`
> resolved to — optional now, defaulting to `Akatsuki-Agent`, the family's CI-plane key, carried as **data**
> in nen's `templates/workflow.json` rather than as a literal in shipped code — plus, only when the policy
> states one, the key under the new and separate `commits.runTrailer`. A run identifier is never itself an
> attribution claim, so it is not folded into `allowedAttributionTrailers`; absent (`null`) by default, it
> makes the second requirement optional where `--run-trailer` used to be mandatory. **`--marker-env` is the
> only flag `nen scaffold init` still requires unconditionally**, and its missing-flag refusal names it and
> says what the other two default to — verified live at nen `0.7.0`, exit `2`
> (`docs/ab/kokusen.md` § *Retired at nen 0.6*).
>
> **A policy whose `allowedAttributionTrailers` does not admit the resolved key generates a hook whose
> automated half refuses every automated commit outright, naming the missing policy** — because there is no
> message such a repository could ever write that would satisfy a check for a trailer it does not admit, and
> a hook that pretended to check for one would be a guard that cannot fire. Regenerating a hook from an
> unchanged policy is byte-stable. **Hatsu's own policy admits both keys**, so a hook generated here would
> require whichever one `--agent-trailer` named; this repository carries no such hook, and layers (a) and
> (c) are what it actually has.
| **(c)** **`nen commit format --repo`** and **`nen wc squash`** refusing a trailer not on the allow-list | nen | **YES** — exit `2` naming the file and the keys it admits, verified live against this checkout (`docs/ab/aka.md` § *Retired at nen 0.5*.2) |

So **at nen `0.7.0` layer (c) is installed everywhere the invocation carries `--repo`, and only
layer (b) stays target-dependent**: a repository scaffolded with the hook has a refusal that fires on
*every* commit however it was made, and one that has not — this repository included — has (a) and (c).
**A raw `git commit --file` carrying `Co-Authored-By` on a feature branch is still caught by (a) only**,
because neither (b) nor (c) is in that path. Say which layers a given repository actually has; a rule
described as mechanical where it is not is worse than one described honestly.

**`--repo` is what turns (c) on.** The policy is opened only when the invocation carries a `--trailer`, and
without `--repo` there is no policy file to open and nothing is refused. Every skill here passes it.

There is **no `Akatsuki-Run:` trailer** anywhere on this plane: Hatsu is local, and there is no CI run to
name. Adding one would forge a machine-plane provenance the local plane does not have.

`nen commit format --repo <path>` reads these two lists and refuses a trailer not on the allow-list, and
`nen wc squash` holds a squash message to the same rule through the shared `attributionRefusalMessages`
wording — so the two verbs cannot disagree about what is admitted. On top of that sits whatever
`commit-msg` hook the target repository happens to carry.

### `monitor`

```json
"monitor": { "maxCycles": 20, "pollSeconds": 300, "localSlotFrees": "ready+prompted" }
```

`en`'s `izanagi` cap and its poll interval. The block also holds futon's local-slot release (`localSlotFrees`, zheref/hatsu#425, [HR-353](ROSTER.md#hr-353), record `R-2026-10-23-20`). **The cap is grammar, not a default**: a watch loop invoked
without one does not run, exactly as [`izanagi`](../claude/skills/izanagi/) refuses an invocation with no
`up to <N>`. § 5 is where both of en's keys are actually spent, and where the long watch hands over to Illumi.

**From nen `0.7` the cap is ENFORCED by the binary rather than counted in a skill's prose.**
`nen loop iterate --id <id> --line "<task> until <condition> up to <N>"` claims one acting iteration
against the cap its own line states and **refuses the claim past it**, exit `1` — so `maxCycles` is a
number a verb holds a caller to, not one a caller is trusted to remember. From nen 0.26 the ledger is
`<git-common-dir>/.nen/loop/<id>.json` of `--repo` (`.nen/loop/<id>.json` under `--repo` only outside a git
repository), never the committed `nen/`. **`en` passes the git common directory as `--repo`**
(`git rev-parse --path-format=absolute --git-common-dir`), so the ledger outlives the effort worktree
and `cleanup` never removes it (`docs/ab/en.md` § *The cap outlives the worktree*). Two consequences
worth stating here rather than only in the skills:

- **The cap cannot be raised by re-typing the invocation.** The `--line` is restated on every claim and a
  claim whose line differs from the running one is refused at exit `2`, naming both. A cap a caller can
  widen by editing its own sentence is a suggestion with extra steps.
- **The cap outlives the session, because the ledger is a file.** `en` keys the id on the pull request, so
  a re-invoked landing resumes the same count rather than restarting at cycle 1 — the watch is per
  session, the cap is per landing. Ending a landing closes the ledger with `--release <why>`, which a cap
  never blocks.

| Key | Default | Read by |
|---|---|---|
| `localSlotFrees` | `ready+prompted` | `futon` § 6, every futon run, attended or `--idle`, stacked or not: **fixed** at `ready+prompted` by the maintainer's pick on zheref/hatsu#425 ([HR-353](ROSTER.md#hr-353), record `R-2026-10-23-20`), which amends HR-257's *frees at its local merge* (ROSTER § *Rulings of 2026-09-30*, *Slots and stops*) and reconciles the 2026-10-13 stacked-slot rule (§ *Stacked pull requests* rule 4) to the same value — an effort's local slot frees once its PR is **Ready** and its **merge prompt** (or, for a stacked PR, its Ready stop) **was shown**. A claimed effort with no PR holds its slot until then, or, on futon § 5's integration shape where no sub-PR opens, until its local merge into the integration branch. The one key that says so. Read by `nen loop slots --repo <checkout>` from nen `0.26.0`: `idle.localSlotFrees` first under a declared idle profile, else this key, the two disagreeing refused; it prints the rule and its source. futon § 6 counts with `--from-run <run id> --target <owner/name> --repo <target checkout>` — every field read from the run's manifest and the live PRs (`ready` from `nen pr ready`, `prompted` from the stop marker in the effort's worktree), none typed (zheref/hatsu#423) — summed with the claimed efforts that have no delivery PR (§ *Idle batches* rule 4). A printed rule other than `ready+prompted` (the key undeclared on another checkout, `merged`, `stacked-open`) is not this repository's: futon counts every unmerged delivery PR in `nen run verify --json` as holding a slot, failing closed. `start` (`futon_effort_record.mts`) refuses any other value here or under `idle.localSlotFrees` |

### `idle`

```json
"idle": { "decisions": { "<ask-once row>": "default" },
          "terminal": "ready-at-prompt-or-integration", "budget": { "minutes": 480, "tokens": 4000000 } }
```

The **idle profile** (HR-5): read only by a `futon` or `kazaana` run whose typed line carries
`--idle`, never by an attended one. The rows apply where the block is declared
(`contracts/config-catalogue.json`, `when: nen/workflow.json#idle`); an absent key is its catalogue
default. § *Idle batches* is the protocol.

**The maintainer's ruling of 2026-10-23** is [HR-334](ROSTER.md#hr-334) (typed, record `R-2026-10-23-01`; its words are the row's, not restated here).

Applied: every ask-once row resolves `default` where it stars an option; `publish-offer` stays `refuse` (a
published release cannot be taken back); a row that stars no option has no derived default and `hold`s
(`missing-maintainer-choice` by HR-4's never-derived rule, and the rows whose answer is a pick among
named things); `cleanup-plan` `default` is its starred *apply the deterministic rows*, read as this
session's deterministic rows only; a merge into `main` is never a row — it is a hard limit — and an idle
run always takes futon § 5's integration-branch shape; every decision taken on the maintainer's behalf is
listed (§ *Idle batches* rule 8). `idle.budget.minutes` is wall-clock run age and tokens are advisory
(confirmed the same day).

| Key | Default | Read by |
|---|---|---|
| `decisions` | one entry per `ask-once-per-run` row of `nen/decisions.json`: `default` where the row stars an option, `hold` where it stars none (`missing-maintainer-choice`, `port-drift`, `intake-challenger`, `port-siblings`, `spec-slice`, `spec-clarify`, `spec-dispatch`), `publish-offer` `refuse` — the ruling of 2026-10-23 above, which lifts the holds of 2026-10-22 on `harness-attribution-switch`, `host-nen-link`, `cleanup-plan` and the starred `spec-*` rows | `futon` § 12, `kazaana` § 1. `default` takes the row's starred option and records it; `hold` parks the effort as `parked:<row>`; `refuse` ends that step unrun and parks it. A row the map does not name takes the same resolution (starred → `default`, else `hold`; `publish-offer` `refuse`). **A floor no file lifts**, enforced by `start` at exit 1: `publish-offer` is always `refuse`; `missing-maintainer-choice` is at most `hold` (the 2026-09-23 ruling: that choice is never derived); `default` is refused on any row whose `preferred` stars no option. An act a `default` leads to that the harness refuses parks as `g5-harness-denied`, never retried another way. Read from the **committed** `nen/workflow.json` of the remote default branch only (`origin/HEAD`, else `gh repo view`'s `defaultBranchRef`; SEC-15), never `HEAD` or a ref `HEAD`'s commit names, never the working tree; a default branch with no `nen/workflow.json` refuses `start` (exit 1, reason printed); the commit is recorded as the ownership record's `idle.source`, the resolutions as nen's manifest's `idleAnswers`, which `start` refuses unless nen stored exactly the map it sent |
| `terminal` | `ready-at-prompt-or-integration` | `futon` § 12: under the ruling of 2026-10-23 every effort is merged into the run's **non-main integration branch** (futon § 5's shape, always, never a picker) and the integration PR stands Ready at the maintainer's merge prompt; `ready-at-prompt` stops short of the integration merge. **Never `main`** (only the maintainer merges there), never `getsuga` or `mugetsu` |
| `budget` → `minutes` · `tokens` | `480` · `4000000` | `futon` § 12 before each claim, through `nen run budget --id <run id> --max-minutes <m> --max-tokens <t> --repo <checkout> --json` (the two values `start` prints from the committed profile; nen's own default reads `--repo`'s working tree, which SEC-15 forbids here): minutes are **wall-clock run age** since the manifest's `startedAt`, one meaning, never summed effort minutes (`effortMinutes` is information) — the **enforced** bound: at `remaining.minutes` `0` no effort is claimed and the rest park as `budget`. **The exit rows**: `0` → read `remaining.minutes`; `1` with a readable report whose `verdict` is `unevaluated` → still read `remaining.minutes`, the tokens reported advisory; `1` with no readable report (the run or `nen/workflow.json` unread) → **hold every claim**, a G5 named `g5-budget-unread`; `2` → wiring, the step stops and is reported. `tokens` is the usage ledgers' sum; nen reads `.nen/usage/<effort>.json` under the one `--repo`, while each effort's ledger lives in its own worktree (§ *The effort's ledgers*), so a multi-worktree run reads `tokensUnread` and the token bound stays **advisory**, reported, never summed by hand — and `--claim`, which refuses on an unread token sum, is not passed (zheref/hatsu#423's finding) |

### `models`

```json
"models": {
  "rule": "latest alias only, never a version; subagents never on the frontier tier, save great-hiker's prose subsession (docs/ROSTER.md HR-336, HR-362)",
  "claude": { "frontier": "fable", "deep": "opus", "fast": "sonnet", "economy": "haiku" },
  "codex":  { "frontier": "astra", "deep": "sol",  "fast": "terra",  "economy": "luna" },
  "cursor": { "frontier": "grok",  "deep": "grok", "fast": "composer", "economy": "composer" },
  "antigravity": { "frontier": "ultra", "deep": "pro", "fast": "flash", "economy": "flash" },
  "roles":  { "reviewer": "deep", "worker": "fast", "measurer": "fast", "orchestrator": "frontier",
              "watcher": "economy", "formatter": "economy" }
}
```

Four **tiers** per surface, and a role maps to a tier rather than to a model. A pinned model version is a pin
that rots; a tier survives every model release, which is the only way a matrix written today is still true in
six months. On Cursor the tiers are Cursor-native only — provider models there are reserved for Bugbot.

**Two rules ride on this matrix, and neither is optional.**

- **A subagent is never given the frontier tier** (`fable`, `astra`), save one exception: `great-hiker`'s
  prose subsession ([HR-336](ROSTER.md#hr-336), scoped by [HR-362](ROSTER.md#hr-362)), the only subagent ever on it. The frontier tier is where the
  maintainer's own conversation lives, and its cost lands on the maintainer's session rather than on the
  delegate's. **A subagent's tier is its scope's or role's, never its caller's** (ruling of 2026-10-13,
  zheref/hatsu#222, stated here once): `hanten` raises each reviewer at its scope's declared tier
  (`review.scopes.<scope>.tier`, which is `models.roles.reviewer`'s `deep` unless the scope says
  otherwise — `ui` and `performance` declare `fast`) whatever tier `direct` sent the maintainer's own
  session to; a `fast`-tier effort is still read adversarially at the tier its scope declares, because the
  review's worth is the reading, not the symmetry with the author. A reviewer may therefore outrank a
  `fast`-tier caller by design; it never reaches the frontier tier. `hanten` § 4 and `direct` § 5 cite this.
- **Every subagent is titled `<skill> · <persona> · <model alias>`** — `hanten · hisoka · sonnet`,
  `rasengan · kurapika · opus`. Three facts, in the order you need them when you are reading a transcript
  afterwards: what ran, as whom, on what.

The persona pins that follow from `roles` are frontmatter in the agent definitions themselves: **Gon** and
**Phinks** `model: opus` / `effort: high`; **Leorio** `model: opus` / `effort: high` (ruling of 2026-09-30);
**Hisoka** `model: sonnet` / `effort: high`; **Uvogin** and
**Netero** `model: sonnet` / `effort: medium`; **Illumi** `model: haiku`. **Kurapika carries neither** — he
is the main session and inherits whatever the maintainer is running.

**Two roles ride on the `economy` tier from zheref/hatsu#93, so the tier is no longer declared and unused.**
`watcher` is the long watch: Illumi, and every `hatsu:izanami` poll, since an observation that reads and
compares needs no reasoning budget. `formatter` is a formatting pass with no judgement in it: gyo's
auto-fix, a prose reflow. Neither role authors, reviews or files; a task that does is `worker` or
`reviewer`, whatever it is called.

#### The matrix, per surface — the reviewer tier, and how a delegate is raised

Hatsu runs on four surfaces ([`docs/SURFACES.md`](SURFACES.md)). The matrix is one table with a column per
surface for exactly this reason: **the tier is the policy and the alias is the surface's answer to it.**

| | **Claude Code** | **Codex** | **Cursor** | **Antigravity** |
|---|---|---|---|---|
| `frontier` — the orchestrator, the maintainer's own session | `fable` | `astra` | `grok` | `ultra` |
| `deep` — **`models.roles.reviewer`**, so this is the reviewer tier | **`opus`** | **`sol`** | **`grok`** | **`pro`** |
| `fast` — `worker`, `measurer` | `sonnet` | `terra` | `composer` | `flash` |
| `economy` — `watcher`, `formatter` | `haiku` | `luna` | `composer` | `flash` |
| **how a subagent is raised** | the harness's **Agent tool**; Hanten **omits** `isolation` — `isolation: "worktree"` would isolate the *plugin's* repository, not the target | **in-session `spawn_agent`** (ChatGPT app, CLI, IDE). Hanten's isolated reviewer is still a second **`codex exec -m <id> -C <dir> -s workspace-write`** because that reviewer must not share the author's tree | a **subagent definition** at `.cursor/agents/<persona>.md`, mirrored there from `claude/agents/` | the harness's **`invoke_subagent` tool**, `Workspace: "branch"` (reviewers and all builder efforts) or `"inherit"` (Third-Hand's Netero, En's Illumi), `Model: "pro"` |
| **isolation** | lead/delegated authors bind separate target worktrees via the Claude guide's adapter; Hanten's reviewer: **`<core>` resolved first — `nen wc worktrees --repo <target> --json` → `core` — then `git -C <target> worktree add --detach <core>/.nen/worktrees/claude-code/hanten-<persona> HEAD`**, the path in the prompt with *"do not request a worktree"*, removed when the review returns ([`hanten`](../claude/skills/hanten/SKILL.md) § 4); **only on an OBSERVED refusal of that `worktree add`** by the harness's isolation guard (never pre-empted), the reviewer reads the effort checkout read-only at the printed HEAD, disclosed ([`PROCESS.md`](PROCESS.md) § *Residue and owned dependencies*, row (a), #218) | app authoring uses its exposed worktree tools and returned workspace path (Codex guide § *Authoring checkout adapter*); in-session spawn **shares the parent**, so delegated authors need independently provisioned paths; Hanten's reviewer is still **`git worktree add` first**, at `<core>/.nen/worktrees/codex/hanten-<persona>` — `-C` takes a directory and creates none | native Worktree mode or the Cursor guide's explicit fallback; a branch alone is insufficient — a worktree Hatsu makes is `<core>/.nen/worktrees/cursor/<name>` | **`Workspace: "branch"`** by default for all builder efforts and Hanten reviewers; **`"inherit"`** for Third-Hand's Netero (`share` only when it is the same checkout); the lead's own `git worktree add` goes to `.nen/worktrees/antigravity/<name>`. Core remains untouched unless the ORIGINAL effort prompt explicitly authorizes core authoring |

Every worktree Hatsu makes, on every surface, lives under `<core>/.nen/worktrees/<surface>/` — § *Where
worktrees live*, the ruling of 2026-09-30.

`nen/workflow.json` → `models` is the source and this table a convenience copy of it; where the two
disagree the file wins and the table is the bug.

**A reviewer runs at its scope's declared tier on every surface** — `models.roles.reviewer`'s `deep`
(`opus`, `sol`, `grok`, `pro`) unless `review.scopes.<scope>.tier` says otherwise — because a role maps to a
tier rather than to a product.
[`claude/skills/hanten/SKILL.md`](../claude/skills/hanten/SKILL.md) § 4 and § 7 are the mechanism, per surface, with
the exact invocation.

**The frontier tier never runs a subagent, on any surface**, save the one exception above. Not `fable`, not `astra`, not `grok`, not `ultra`. The
frontier tier is where the maintainer's own conversation lives, and the cost lands on the maintainer's
session rather than on the delegate's; below it, the first rule above holds (a subagent's tier is its
scope's or role's, never its caller's).

> **Antigravity Performance vs. Cost & Subscription Tiers (Google AI Pro & Ultra)**:
> In market benchmarks (such as DeepSWE and SWE-bench Verified), Gemini 2.5 Pro demonstrates reasoning
> on par with or exceeding Opus and o1 on difficult architectural, refactoring, and code review tasks,
> making it the designated `deep` reviewer tier. For `worker` and `measurer` tasks, Gemini 2.5 Flash
> provides exceptional cost efficiency (10-20x cheaper per token while retaining >80% resolution accuracy).
> Under Google AI Pro and Ultra subscriptions, maintainers operate the lead Kurapika session interactively
> on the frontier tier (`ultra` on Ultra, `pro` on Pro), while every spawned subagent but `great-hiker`'s prose subsession (§ `models`'s one
> exception) stays strictly at `pro` (`deep`) and `flash` (`fast`), ensuring rate limit stability and billing efficiency.

> **On Cursor the `frontier` and `deep` tiers name the same alias, and the rule survives that.** `grok` is
> both, so on Cursor "never the frontier tier" cannot be checked by reading the alias — it is enforced on
> the **role**: a reviewer is raised at `models.roles.reviewer`, never as an orchestrator, and a string
> collision between two tiers is a fact about that line-up rather than permission to promote a delegate.
> Say the tier *and* the alias — *"tier `deep` → `grok`"* — so a transcript read afterwards is unambiguous.

**The Cursor row is Cursor-native only**, and the file says why in its own words:

> `"note": "Cursor-native only; provider models there are reserved for Bugbot"`

So a role on Cursor resolves to `grok` or `composer` and to nothing else — even though `cursor-agent
--model` will happily accept a provider model, and its own `--help` gives provider models as the examples.
Accepting one is out of policy, not a local optimisation.

### `profile`

```json
"profile": { "default": "standard", "allowed": ["fast", "standard", "thorough"] }
```

The run profile [`ren`](../claude/skills/ren/) § 2a reads (zheref/hatsu#93). `default` applies to every turn
that names none; a turn names one with `hatsu:ren <request> --profile <p>` or the words "fast turn" /
"thorough turn", and a value outside `allowed` is refused with the list quoted. An absent key reads as
`standard`, said out loud.

| Profile | Per turn | Deferred to `mukai` | Report |
|---|---|---|---|
| `fast` | steps 1 to 3 as ren § 2 states them; step 4 skipped, launch line `deferred by profile fast; isolation still requires an explicit maintainer core-launch call` | coverage and the full page; launch skipped, not moved | `turn-fast` |
| `standard` | today's turn: every step of ren § 2 | nothing | `turn` |
| `thorough` | `standard` plus the impacted suites (`kotoamatsukami`) after step 3 | nothing | `turn` |

**A landing always runs thorough**, whatever the turns before it named: a profile lowers a turn, never
the phase that publishes. Deferred to mukai means kotoamatsukami's impacted suites and byakugan's
coverage at the landing; mukai has no launch step. An isolated effort's core launch remains deferred
under every profile until `hatsu:amaterasu` is explicitly called by the maintainer. Every ren step is a
ledger entry regardless of profile (§ *The effort's ledgers* below).
`nen schema check` validates the key from `v0.13.0`; the `v0.12.0` pin preserves it as raw data and
reports nothing about it (verified on 0.12.0, 2026-09-20).

**An alias is a name, and the id you type may still carry a version.** `models.rule` is *"latest alias only,
never a version"*, and that governs **the file**; a surface's command line may need the concrete id — on
Codex the `sol` tier is spelled `gpt-<version>-sol`, so the id is **read from `codex debug models` at the
moment of use** rather than remembered (`docs/SURFACES.md` § 5). Reading it is what keeps the versionless
alias in the file honest.

**A persona's `model:` pin does not translate between surfaces.** `nen surface mirror generate` carries
`model` through to `.cursor/agents/<persona>.md` verbatim — correctly, since it mirrors rather than
translates — so Hisoka's `sonnet` arrives on Cursor as a Claude alias in a Cursor-native-only matrix. The
rule is `hanten`'s § 7: **report the pin unresolvable, fall back to the role's tier, and state the
substitution in the title.** Never silently honoured, never silently dropped.

---

### The effort's ledgers — phases, usage and sessions

**Stated once, here; the skills cite it and add only what is theirs** (zheref/hatsu#93, #100, #321).
Three ledgers per effort, generated under `.nen/` and keyed by the **branch** — `--effort <branch>`,
never the PR-keyed hanten cycle ledger — carry phases, usage and reported session identities:

```bash
nen phase begin --effort <branch> --phase <step-name> --surface <s> [--model <reported-model>] --dial <level>   # before a step
nen phase end   --effort <branch> --phase <step-name> --exit <code>                      # after it
nen shu <verb> --repo <path> --effort <branch>          # a step inside an open phase lands under it
nen usage record --effort <branch> --surface <s> [--model <reported-model>] --dial <level> \
  --input/--output/--cache-read/--cache-write <n> [--minutes <n>] --source "<call site: readout>"
nen usage record --effort <branch> --surface <s> --dial <level> --not-reported           # no readout
nen session record --effort <branch> --surface <s> [--model <reported-model>] --dial <level> \
  [--title <reported-title>] [--id <reported-id>] --source "<harness readout>"          # first phase, when exposed
```

`.nen/phases/<effort>.json` holds one timed entry per phase, a refused step included; `.nen/usage/<effort>.json`
one entry per reading, `source` naming the call site and the readout (Claude Code's `/cost`, the Agent
tool's result totals for a subagent, Codex's session log; `--not-reported` on a surface exposing none).
`--dial` is the actual surface effort level, recorded at each begin and usage write, not carried in
`--note`. At the effort's first phase, record a session title plus id where the Claude desktop
exposes both; on CLI, Codex, Cursor and Antigravity record the id if exposed. `session record`
requires a real title or id: if neither is exposed, leave `sessions[]` empty and render
`unread — <surface> exposes none`. Never invent a value or transcribe it at PR composition.
The model field records the harness's reported token, or the registry alias when no token is
reported. Classify an exact served ID in the same ledger entry: `model-kind=served` or
`exact served model from <provenance>` in `phase.note`, `usage.source` or `session.source`.
`registry alias <token>` may accompany it. A bare model token, even one resembling a versioned ID,
is unclassified and renders exact ID `unread`; an alias or direct snapshot cannot prove what ran.
For a reviewer, an alias comes only from its actual row or an explicit `registry alias <token>`
marker, else it is `unread`; the configured reviewer tier does not prove which alias ran.
`phase.note` may carry model provenance, never a dial or session value.
**Every skill that runs a phase wraps its own phases, and every skill that spends records at the moment
it spends** — never a transcription at the end of a sitting. Who writes what: `ren` § 2 (every step; usage
at step 5), `build` § 4 (its own steps; usage at every § 7 report), `hanten` § 4 (one usage entry per
reviewer, as each returns), `spiritual-message` § 4 and `backlog-board` § 3 (usage before a render).
`nen report data` merges them as `phases[]`, `usage[]` and `sessions[]` for Delivery rendering.
Public Source cells contain only `kind[index]`, ledger timestamp and phase where present;
free-form `phase.note`, `usage.source` and `session.source` stay local as classification evidence.
Keep report data, normalized data and rendered fragment under the private repo-local
`.nen/reports/` directory (mode 0700, files 0600).

## 3 · `project.launch` and `project.evidence`

Two blocks of nen's `project` shape that began as Hatsu extensions. **At nen `0.7.0` both are
PARSED and EXECUTED**: `launch` by `nen shu dev|run --target <name>`, `evidence` by
`nen shu evidence --base <ref>`. They are no longer preserved-and-unread, and that changes what a typo
costs.

**Each block key is guarded against a near-miss, by pointer.** `launches`/`Launch`/`launc` and
`evidences`/`Evidence`/`evidenc` are refused naming the key they meant and which kind of misspelling it is
— one letter out, the same word in a different case, or that key with an English plural on it. Preserved,
such a key would be read by nobody while the verb that needs it refused about a file that plainly declares
the block. The older optional blocks (`targets`, `hosts`, `toolchain`, `profiles`) are still deliberately
unswept at the *block* level, because a declaration written against `0.3.0` may already park a near-miss
key there.

**`project.launch.<name>` also admits `lane` and `artifact` at this pin** — which lane the target's verb,
`args` and after-steps are read from, and the repo-relative path `{artifact}` is substituted with instead of
the verb's first `artifacts` entry. Both are optional and absent means exactly what it meant before. One
thing that was accepted through `v0.4.0` and is not now: `{device.id}` or `{artifact}` written into
`project.launch.<name>.args` is exit `2` naming the token, because substitution reaches the target's `after`
steps and nowhere else.

**And `project.launch.<name>.device` admits `readyWhen` from nen `v0.6.0`. A device that is PRESENT is not a
device that is READY**, and until this key existed nen read the first and reported it as the second: the row
carrying the device's name also carries its *state* — attached is not paired, paired is not unlocked,
present is not finished booting — so a launch matched the name, resolved an id off an unusable row, printed
the probe green, and every command after it failed one at a time. The rule is
`{ "field": <n>, "in": [ … ] }` against a probe that prints **lines** — `field` counts whitespace-separated
tokens on the device's own row with the row's **first** token as field 1 — or `{ "path": "<dotted key>",
"in": [ … ] }` against one that prints **JSON**, read off the object whose `name` matched or an enclosing
object up to two levels out. Validated **at load, by pointer**: exactly one of `field`/`path`, `in`
non-empty, `field` a whole number ≥ 1, and refused outright on a device with no `resolve` probe. A row
present but not ready is **exit `5` naming the device, the state seen and the states accepted**, listing
what the probe offered, answered *before* the missing-id refusal. `--dry-run` prints it as a `readiness:`
line with nothing connected. **Absent, behaviour is unchanged in every particular** — which is why
[`jujutsu`](../claude/skills/jujutsu/SKILL.md) § 6 writes one on every device it registers rather than
treating it as optional polish.

**`{artifact}` is substituted as the AFTER-STEP'S own directory sees it, also from `v0.6.0`.** Two roots
exist and they are not the same: `artifacts` and `project.launch.<name>.artifact` are stated against the
repository root, like every declared path, while an after-step is spawned with its cwd set to
`project.lanes.<lane>.cwd`. On a lane whose cwd is not `.` the installer used to be handed a path resolved
against the wrong root. The `substitutes:` line now says both strings when they differ, while `artifacts:`
keeps reporting the repository-relative one — the two answer different questions, and collapsing them would
hide the rebasing rather than show it; `--json`'s `target` gains `artifactAs`. **A lane at the repository
root gets back the identical string**, which is every lane in this repository.

### `project.launch`

```json
"launch": {
  "iphone": {
    "verb": "dev",
    "device": { "name": "<the device's own name>",
                "resolve": { "exe": "xcrun",
                             "argv": ["devicectl", "list", "devices", "--json-output", "-"] } },
    "after": [
      { "exe": "xcrun", "argv": ["devicectl","device","install","app","--device","{device.id}","{artifact}"] },
      { "exe": "xcrun", "argv": ["devicectl","device","process","launch","--device","{device.id}","<bundle id>"] }
    ]
  },
  "mac": { "verb": "dev", "args": ["-scheme","<scheme>"], "after": [ { "exe": "open", "argv": ["{artifact}"] } ] },
  "sim": { "verb": "dev", "device": { "name": "iPhone 17 Pro", "kind": "simulator" } },
  "pixel": {
    "verb": "dev",
    "device": { "name": "<the serial adb printed>",
                "resolve": { "exe": "adb", "argv": ["devices", "-l"] },
                "readyWhen": { "field": 2, "in": ["device"] } },
    "after": [
      { "exe": "adb", "argv": ["-s","{device.id}","install","-r","{artifact}"] },
      { "exe": "adb", "argv": ["-s","{device.id}","shell","am","start","-n","<pkg>/<activity>"] }
    ]
  }
}
```

The `pixel` row is the readiness rule in its commonest shape: `adb devices -l` prints the serial as the
row's **first** token and the state as its second, so `field: 2` with `in: ["device"]` is the whole of it —
`unauthorized`, `offline`, `no permissions` and every other state the daemon reports are then a refusal at
exit `5` rather than an id nothing can use.

Each key is a **named target**. `verb` is the lane verb to run; `args` are appended to its argv; `device`
declares how to find the device and how it is named; `after` is the steps that install and start what the
verb built. Two placeholders substitute: `{device.id}` from the `resolve` probe's output matched on
`device.name`, and `{artifact}` from the first entry of the verb's `artifacts`.

Three properties are the point of declaring it rather than typing it:

- **No toolchain name lives in nen.** `xcrun`, `adb` and `open` appear here, in the target repository's own
  file, and never in nen's execution modules — nen's `purity.test.ts` enforces exactly that.
- **`--target` is required, with no default, ever.** A launch with no named target does not happen.
- **A device is refused by name.** When the `resolve` probe does not see `device.name`, the refusal *lists
  what the probe did see*, which is the difference between a useful error and a shrug. **And it is refused
  by STATE where `readyWhen` says which states count** (above), with the same discipline: the refusal names
  the state it saw, the states it accepts, and everything the probe offered.

### Containment — every declared path is resolved against the repository's REAL root

**Every path a declaration states is repo-root-relative, and nen refuses one that leaves the tree `--repo`
points at** — at exit `2`, before anything is spawned, read or written, naming the pointer that stated it.
From nen `v0.6.0` the test is against the path **the kernel would actually reach**, `realpath`-resolved,
rather than against its spelling: `build/payload` reads as plainly inside the repository and is refused
just the same when `build/` is a symlink to somewhere else, and the refusal names the link and where it
points. A symlink that stays inside the tree is ordinary and allowed — the question is where the path
*lands*, never whether a link was involved. It holds for `project.lanes.<lane>.cwd`, a `path` precondition,
every `artifacts[i]`, a `project.launch.<name>.artifact`, a step's `stdoutTo`, and the coverage and
test reports `shu coverage` and `shu test-report` read back.

**`nen schema check` does NOT answer it, deliberately**: the loader has no filesystem, so a `cwd` of
`../../../../etc` reads as a well-formed declaration and is refused at the moment of use instead.
**Pointers are checked at load; paths at use** — so a clean `schema check` is not a containment verdict,
and a skill must never report it as one.

`amaterasu` runs `--dry-run` first and distinguishes its plan from an actual launch result. An
isolated Ren effort, serial or parallel, reports the command and defers automatic core launch
without asking; an explicit maintainer call authorizes the core launch, a separate explicit
`amenotejikara` call authorizes a swap. Neither transfers authoring or PR delivery into core.

### `project.evidence`

```json
"evidence": { "globs": ["**/__Snapshots__/**/*.png"], "mechanism": "public-mirror",
              "scene": "{suite}-{scene}" }
```

`globs` are the artifacts that count as visual evidence; `scene` is the template that turns a path into a
suite-and-scene pair; `mechanism` is how the images reach a pull-request body. `kotoamatsukami` re-records
them, `spiritual-message` lays them out as a table with scenes as columns, and `shibari` puts that table in the PR.
Pre-PR, PNGs are embedded as **data URIs** so a report is one self-contained file with no host to go stale.

### `project.fromCore`

```json
"fromCore": [ { "path": "<product-repo-C>/Config.xcconfig", "why": "<why it lives only in the maintainer's checkout>" } ]
```

**Hatsu's own block, beside `project.preconditions`, read by [`kagutsuchi`](../claude/skills/kagutsuchi/)
§ 3b through `scripts/kagutsuchi_worktree.sh` and by nothing in nen** — nen's loader preserves it (verified at
`0.16.0`: `nen schema check` and the `shu` executor both accept a contract carrying it), and **nen still
asserts the precondition in the worktree exactly as before**; this block only says where the file
comes from. The maintainer's ruling of 2026-09-29 (zheref/hatsu#146): *"Let's have the composite ALWAYS
copy own file from core checkout."* Each entry names a **repo-relative, gitignored, untracked** path
that exists in the core checkout and nowhere in git — the base configuration carrying credentials, a
local signing note — and kagutsuchi § 3b copies it **from core into its worktree, before the fresh
archive it runs only when the freshness gate found the last one stale**, listing each copied path. The script refuses, before anything moves, an entry that is tracked (it
is in every worktree already), not gitignored (the copy would dirty the worktree and refuse the next
run), absent in core (the maintainer's own machine is where it comes from — **nothing is synthesised**,
the same rule `project.preconditions` states), a symlink, or a path that leaves the tree — and, at the
trunk's tip, a destination that is tracked, unignored or a symlink (a trunk commit never decides where a
credential lands). **No block
copies nothing and says so.** A precondition that FAILs in the worktree on a path that exists gitignored
in core is the `missing-configuration` ask for a row here — proposed with its `why`, landed through
that repository's declaration PR at its gate, never written unasked.

---

## 4 · The phases, and which of them a human calls

**Per request, the loop is `ren`**, and it runs without being asked:

`breath` (first turn of an effort — and it proves the base tip builds) → `rasengan` (**author the change**)
→ `kokusen` (**verify the finished tree, then commit**) → `amaterasu` (launch handling) → `spiritual-message` (the turn's
report) → `jutaisho` (the bell).

It loops. **It never pushes and never opens a pull request.**

**Five phases are the maintainer's to call, and no agent ever prompts for them** (the merge prompt at
`en` § 5 presents a PR's link and merge line; its picker never carries the merge act; the maintainer merges outside the session — [`ROSTER.md`](ROSTER.md) § *Rulings of
2026-09-30 — En never merges*):

| Phase | What it does | Why it is the human's |
|---|---|---|
| [`aka`](../claude/skills/aka/) | lint → squash the unpushed commits → `ao` → re-lint if catch-up moved the tree → push | publishing work is a decision, and a squash is destructive |
| [`mukai`](../claude/skills/mukai/) | `murasaki` → `hanten` review → kokusen checkpoint → `kotoamatsukami` impacted tests → `byakugan` coverage → publish proven updates → evidence → `shibari` opens the PR → landing report → ring, **offer** `en` through the picker and end Mukai. **§ 5 is the full shape** | En runs on the maintainer's answer (or at once under `mukai.autoEn`); pending is En's in-progress state |
| **merge** | **G2** (`merge`) and **G4** (`canon-merge`) | **every PR into `main` is the maintainer's** — [`en`](../claude/skills/en/) § 5 ends it at the merge prompt, its link and an inline `gh pr merge` line, at either row ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-09-30 — En never merges*); [`getsuga`](../claude/skills/getsuga/) § 3a merges **its own release-proposal PR** through `nen pr merge --release-unit`; [`futon`](../claude/skills/futon/) § 5 merges effort branches locally (`git merge --no-ff`) into its own integration branch — no sub-PR, no `gh pr merge` |
| [`kagutsuchi`](../claude/skills/kagutsuchi/) | a non-production upload, **per target**: `nen shu deploy --target <name>` prints the plan always; § 3a's freshness gate reads the archive's build SHA against `HEAD` and `origin/<branch.base>`'s tip on a clean tree, and **only when it is not the tip's build** § 3b runs `susanoo` first in one idempotent clean worktree under core's `.nen/` (the maintainer's gitignored files copied from core, `project.fromCore`, § 3) and sends from there; `--run` acts only on a call — the target **typed, or the declared `deploy.defaultTarget`** (§ 2) | the blast radius leaves this machine |
| [`mugetsu`](../claude/skills/mugetsu/) | publication, **per target**, **G3**: only on the maintainer's own go (mugetsu § 0), with the preflight green and the tag already cut — one target per call; with no target typed, the single declared destination and the latest cut tag with no published release (ruling of 2026-09-28) | the blast radius is other people's users |

The generated release publisher and its adjacent TypeScript helper compose notes from the changelog's own release headings, at
Markdown levels 2–6. The `Unreleased` heading sets the level when present; otherwise the first
`v*` section does. A target tag absent at that level, or a changelog with no recognisable
release heading, is a refusal before publication. A previous tag at a different level also refuses before publication. Process consumers need Node 22.18+ for the helper. `nen changelog collate`'s `###` sections and
existing `##` sections both follow this rule.

En may also merge a **recorded Futon-owned stacked delivery PR** into a non-main base when Nen
Ready, live body, current-head ownership and `nen pr merge --delivery` all pass. This narrow
non-main path is [`en`](../claude/skills/en/SKILL.md) § 5 and
[`ROSTER.md`](ROSTER.md) § *Ruling of 2026-10-19 — recorded Futon delivery merges*;
the table's main-bound merge gate is unchanged.

### Recorded Futon delivery ownership

At the start of a typed Futon run, before any PR opens, Futon records the original invocation
and retains the returned run ID in its effort record. After it opens each stacked delivery PR
and after each update to its head, it binds that run ID, selected issue, live PR, non-main base,
head branch and full GitHub head SHA. The plugin-root TypeScript helper parses the invocation,
checks the selected issue and live PR, requires the run to predate the PR, and requires its body
to cite the selected issue. It stores the claim in the repository's Git common directory,
outside the PR-controlled tree. The same effort may refresh its head; another run, issue,
selector, base or branch cannot take over the record. Verify immediately after binding.
No ownership record is made for an integration PR or a PR into `branch.base`.

**The run manifest is nen's** (HR-5, `nen.run/v0.1`, `<git common dir>/.nen/runs/<run id>.json`; zheref/hatsu#423).
`start` parses the invocation, resolves the idle profile, opens the manifest through `nen run start --id <run id>
--target <owner/name> --repo <checkout> [--idle-answers <json>]` and only then writes its own ownership record
(`hatsu.futon.run/v0.3`: id, repo, invocation, selector, `startedAt` copied from nen's manifest — one owner —,
`dry`, the idle profile's `terminal`, `budget` and `source`, and a dry run's `predictions[]` — no PRs, no parks,
no answers). A refused or non-`started` nen start, or a manifest storing other `idleAnswers` than the map sent,
refuses `start` (exit 1), so no record names a run nen never opened; a record that cannot be written names
nen's manifest path as the orphan. `bind` refuses a dry run and an idle one, and `verify` refuses a claim on either (§ *Batch delivery* rule 4). After **every** PR the run opens — delivery, integration or release,
**whatever its base**, `main` included — `nen run append --id <run id> --pr <N> --kind delivery|integration|release
[--issue <CODE>#<N>] [--effort <branch>] --repo <checkout>` records it from the live PR (a re-append refreshes base
and head; a PR opened before the run, or under another kind or issue, is refused). `nen run park --id <run id>
--issue <CODE>#<N> --row <row>` records a parked effort; `nen run verify --id <run id> --target <owner/name>
--repo <checkout> [--json]` reads every recorded PR live and prints the parked rows: futon § 8's `then` gate,
kazaana § 5 and the register read every PR this run authored from it, never from memory. A v0.1 or v0.2 run
(opened before this change) has no nen manifest: `verify` exits non-zero and the gate is **held**, never met by an
empty set; `profile` prints its record with `manifest: absent`. The record's `append`, `park` and `status` are
retired and refuse by name.

```bash
node "$hatsu_root/scripts/futon_effort_record.mts" start --repo <effort-worktree> --invocation '<original full hatsu:futon invocation>'
node "$hatsu_root/scripts/futon_effort_record.mts" resume --repo <checkout> [--run <id>] --invocation '<the same line, re-typed>'
node "$hatsu_root/scripts/futon_effort_record.mts" integrate --repo <checkout> --run <id> --branch <the run's integration branch>
node "$hatsu_root/scripts/futon_effort_record.mts" end --repo <checkout> --run <id>   # futon § 10
node "$hatsu_root/scripts/futon_effort_record.mts" bind --repo <effort-worktree> --pr <N> --run <id printed by start> --issue <issue-N> --base <live non-main base> --head <live head branch> --sha <full live head SHA>
node "$hatsu_root/scripts/futon_effort_record.mts" verify --repo <effort-worktree> --pr <N>
node "$hatsu_root/scripts/futon_effort_record.mts" profile --repo <checkout> --run <id>
node "$hatsu_root/scripts/futon_effort_record.mts" predict --repo <checkout> --run <dry id> --issue <CODE>#<N> --row <row>
nen run append --id <id> --pr <N> --kind delivery|integration|release [--issue <CODE>#<N>] [--effort <branch>] --repo <checkout>
nen run park   --id <id> --issue <CODE>#<N> --row <row | budget | needs-clarification | residue-<skill> | g5-<class>> --repo <checkout>
nen run verify --id <id> --target <owner/name> --repo <checkout> --json
```

A missing, mismatched or stale record leaves En at the maintainer handoff; it never infers
ownership from the branch name, PR title or session memory. En verifies again against the
same head immediately before its bounded merge ([`en`](../claude/skills/en/SKILL.md) § 5).
The local record supplies **procedural provenance**, not cryptographic proof of who typed the
invocation; only Futon may run `start`, `resume`, `integrate` and `end`, and En only runs `verify`. A host running this `.mts`
helper requires Node ≥22.18, declared in `nen/contract.json` and checked by `nen shu tools`.

**Two offers are not prompts for those five** ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-13*, 3 and 5).
The **wrap-up picker** at every session delivery — a PR at `en` § 5's merge prompt or merged, a composite's run
ending — asks once (row `wrap-up`): ⭐ [`cleanup`](../claude/skills/cleanup/) · `cleanup` and
[`third-hand`](../claude/skills/third-hand/) in parallel · continue iterating; `cleanup` is **required after a
completed session**, `third-hand` optional, and neither is a phase of the five. And [`kazaana`](../claude/skills/kazaana/)
§ 6 asks once, after the tag it cut resolves on origin, whether `mugetsu` should publish it (row `publish-offer`,
no option starred): the affirmative answer is the maintainer's own go, form (4) of `mugetsu` § 0, quoted verbatim;
neither offer ever names `aka`, `mukai`, the merge or `kagutsuchi`.

**The per-target rule is the whole of the last two rows, and it is not a formality.** A go for one
destination is a go for *that* destination: `kagutsuchi`'s target is **typed, or the one the maintainer
declared as `deploy.defaultTarget`** (§ 2; ruling 2026-09-29, zheref/hatsu#146 — before it, required
grammar with no default) and is still passed to `nen shu deploy --target` explicitly, still
non-production only; `mugetsu` resolves the single declared one and asks, as free text, only where
several are declared and none named. A second destination is a second call the maintainer makes.
Neither phase is ever reached from a composite on the composite's authority — not from
[`getsuga`](../claude/skills/getsuga/), not from [`en`](../claude/skills/en/);
[`futon`](../claude/skills/futon/)'s `then` chain reaches either **only on the advance go**, defined
once in [`mugetsu`](../claude/skills/mugetsu/) § 3 and gated by `nen parse futon` on
`futon.advanceGo` — and the release unit both of them send is built by
[`susanoo`](../claude/skills/susanoo/), which uploads nothing itself and cuts no tag — where the
repository declares `tags.identity` it names the identity `kagutsuchi`'s tag will carry, and the commit
`kagutsuchi` § 3a proves fresh before the send, rebuilding through `susanoo` in a clean worktree when it
is not (§ 3b, the maintainer's ruling of 2026-09-29: only when the latest build is not up to date with
the target branch).

**A port ruling's PR is a canon PR** ([`bankai-rule`](../claude/skills/bankai-rule/) § 6, zheref/hatsu#354): it opens once per port run on the handbooks repository and ends at `en` § 5's prompt as **G4**, the maintainer's merge, like every PR into a canon repository.

**More things only the maintainer calls — and none is one of the five.**

| Phase | What it does | Why it is the human's |
|---|---|---|
| [`black-voice`](../claude/skills/black-voice/) | **post-merge UI validation.** Resolves the merged PR and the acceptance criteria of the issues it closed, raises **Shalnark** once to drive every criterion through ephemeral automated UI tests, and publishes pass / fail / not-testable per criterion | it runs *after* the gate, on work already merged, and guessing which PR was meant wastes the whole run |
| [`hiraishin`](../claude/skills/hiraishin/) | **a merged PR, ported to one sibling.** Refuses a source not merged into its base, runs `kamui`'s spec step and waits at its **G2** merge where the family declares a spec repository, writes the port brief, asks every unmapped row in one batched `port-drift` call, files the port issue — the typed call is its **G1** — and builds it to the target's merge prompt | it runs *after* the gate, on work already merged, and every port starts on the maintainer's typed call: an automatic port on merge is out of the epic's scope (zheref/hatsu#354) |

**`black-voice` sits outside the five deliberately.** It crosses no gate, decides nothing and blocks nothing —
it is an optional look back at a delivery, so nothing schedules it: not `ren`, `mukai`, `en`, `futon`
or `backlog-loop`, and no agent proposes it. **Never automatic and never from a composite**, and the
skill refuses mechanically rather than on manners — see its § 1. **`hiraishin` is outside the five for
the same reason it is typed only**: it runs after the gate, on work already merged; it crosses no gate but
the G1 its own typed call carries for the port issue, ends at the target's **G2**, and is never started
from a composite or on a merge (zheref/hatsu#354). **`kamui` is typed only for the same reason**: it writes
a product's spec (the spec repository's **G2**), fans port issues out on the sibling picker's answer (its
ruled G1) and starts the picked builds; nothing schedules it and no composite calls it — `hiraishin` calls
its §§ 2–4 by name, never the whole. **`dowsing-chain` is typed only for the same reason**: it writes a whole
product family's spec from its members' code (each spec PR the spec repository's **G2**), files issues only on
its dispatch picker plus `file` § 4's own confirmation, and builds only on the typed `wave` call; no composite
calls it ([`config/spec-repo.md`](config/spec-repo.md)).

Asking *"shall I push now?"* at the end of a turn is how a human-called phase becomes an agent-called one by
attrition. The loop simply stops and waits.

**The only interruptions are genuine G5 stops** — anything only the maintainer can do that no earlier gate
covers (ruling of 2026-10-17, zheref/hatsu#290 q4: an **open class**; a kind not recorded here is still a G5, never
refused for being unlisted). The recorded set is `nen/decisions.json`'s `human-gate` rows; **the kinds a running
phase stops on:**

1. **red required tests** — in `mukai`, via `kotoamatsukami`
2. **touched-file coverage under `coverage.minimum`** — in `byakugan`
3. **a semantic conflict** — in `ao`. A *mechanical* conflict is resolved, not escalated
4. **an unsettled adversarial finding** — in `hanten`, after Kurapika has fixed it or pushed back with a reason
5. **a `sharingan` escalation** — a PR that will not reach Ready. **An exhausted reviewer is not one**: a met round quorum fulfils its round, and at the sixth stop — every quorum member unavailable, its predicate stated once in `docs/PROCESS.md` § *Reviewer rounds and review threads*, *The sixth stop* — the PR goes to `en` § 5's merge prompt on hanten's rounds, the not-ready verdict quoted verbatim (ruling 2026-10-11, *prompt on hanten*), and under `aiReviewers: optional | off` whenever `rounds-owed` is the only failing row — `nen/decisions.json` rows `reviewer-exhausted` and `ai-reviewers`, `docs/PROCESS.md` § *Reviewer rounds and review threads*
6. **an on-device act** — a trust prompt, a security setting, a UAC consent, a Login Items approval, a password
   typed into an elevated window (row `on-device-act`; ruling of 2026-10-17, zheref/hatsu#290 q1, reversing
   2026-10-13's #176): the act is printed with where the operation resumes, and the run stops at the gate until the
   maintainer has done it. A skill *raises* such a prompt only through a launch the harness itself asks the
   maintainer to approve — that permission prompt, showing the exact string, is the advance consent, and the
   launch is itself raised at this stop, naming it ([`jusshin`](../claude/skills/jusshin/SKILL.md) § 5's
   Windows path). It never taps, confirms or bypasses one, never enters a passcode, PIN, password or
   credential (one typed into the picker or chat is never used and is rotated), and never asks the
   maintainer to disable a protection — that request stays a refusal ([`jujutsu`](../claude/skills/jujutsu/SKILL.md)).
   The bell's `osascript` allow row, which pre-approves more than a notification, is replaced by a fixed
   script (zheref/hatsu#289 item 9, ruled 2026-10-17)
7. **a secret-shaped staged path** — in `kokusen`, row `secret-shape`: never committed, never askable; rotate or
   remove is the maintainer's act (ruling of 2026-10-17, zheref/hatsu#290 q2)

**A red *iteration* check is not a G5 of its own, and the ruling of 2026-09-10 did not make it one.** It is
fixed where it is found: inside `rasengan`'s inner loop while the change is being written, or by handing the
tree back to `rasengan` when `kokusen`'s gate refuses to commit it. Only a red check the turn cannot honestly clear
escalates, which is the escalation `rasengan` has always carried. **The one stop that is genuinely new in
shape rather than in kind is `breath`'s**: a base tip that does not build stops the effort at step 1, *before*
a line is authored, because a broken trunk is its own effort and folding it into this one buries a trunk
regression inside an unrelated change set. It interrupts nothing that had started.

Nothing else stops the loop. **A stop is `nen stop`'s banner, the report link, the options with ⭐ on the
recommended decision — never on the report, which is linked and never an option — a proposed process
issue, and the question asked through the surface's own native option picker** (Crazy Slots;
`AskUserQuestion` on Claude Code, `request_user_input` on Codex, `AskQuestion` on Cursor,
`ask_question` on Antigravity). **The picker carries the question alone**; the banner, the verdict, the link
and every command are the chat message's, and a free-text answer typed into the picker is the maintainer's
word — [`jutaisho`](../claude/skills/jutaisho/SKILL.md) § 4 states the shape once (ruling of 2026-10-17,
zheref/hatsu#294).

**Every picker answer is recorded — `nen stop answer`, stated once here** (zheref/hatsu#443; nen
`0.26.0`). When a picker for an `ask-once-per-run` or `human-gate` row of `nen/decisions.json` is answered,
and before the run acts on the answer, the skill that asked writes one record; a skill cites this
paragraph, never restates it:

```bash
nen stop answer --record <effort> --row <row-id> --who kurapika --question-file <question.md> --option "<key>=<label>::<consequence>" --pick <key>
```

- **`<effort>`** is the effort's branch, the key of § 2 *The effort's ledgers*; before a branch exists (an
  intake, a filing) it is `inline-<ISO date-time>`. The record lives under `<git common dir>/.nen/stops/`,
  so a worktree removal keeps it, and nen prints its id `R-YYYY-MM-DD-nn`, never reused **within that
  clone** (another clone counts its own; zheref/hatsu#443). An R-id is evidence, never a ruling id.
- **What was shown, as shown**: the question file holds the question as asked; one `--option` per option
  in the picker, its label as shown and its description line as the consequence. A reference in either is
  written coded at ask time (`<owner>/<name>#N`, `HA#N`), as PL-05 reads it; the renderer's coding of a
  `<repository> #N` ([`ROSTER.md`](ROSTER.md) § *The ruling template*, step 3) is the safety net for older records. A `human-gate` row adds
  `--gate <its gate>`; an `ask-once-per-run` row names `--row` alone.
- **The answer**: `--pick <key>` for a picked option; `--typed-file <file>` holding the maintainer's own
  words byte for byte for a free-text answer. **"Verbatim" is reserved for typed text**; a typed text that
  is word for word one label, nen records as that pick.
- **A free-text answer is the maintainer's word** (HR-173) and the run acts on it. **Only a reply that does
  not answer is asked once more** — a question back (answered first), or a reply that fits neither an option
  nor the row's typed form — a new call, its answer a second record; a second reply of the same kind is
  acted on as the maintainer's typed words. The maintainer kept HR-173 over re-asking every unmatched
  typed reply (2026-10-23, [HR-341](ROSTER.md#hr-341), record `R-2026-10-23-08` under effort `HA-IS-#450`; zheref/hatsu#443 AC-2).
- **Rows typed by design** — `missing-maintainer-choice`, `missing-argument`, `missing-configuration`,
  `port-drift` — are never re-asked for being typed. `missing-maintainer-choice` has no options (its
  candidates, none starred, go in the question file): record it with the one reference option
  `--option "ref=typed by design (no option)::the typed words are the answer"` and `--typed-file`, so
  nen never reads a typed value as a pick; the row renders `none: typed by design`, capture class typed.
- **`direct-mismatch`'s record is `nen direct answer`** (direct § 6); `nen stop answer` records every
  other row.
- **An idle pre-answer** (§ *Idle batches*, step 1) is recorded the same way and shows no picker:
  `node "$hatsu_root/scripts/ruling_record.mts" preanswer --effort <branch> --row <row-id> --source "<idle.source>" --repo <checkout>`
  picks the row's starred option and names the source in the question; `hold` and `refuse` park, they answer nothing.
  A pre-answer renders `pre-answered (<source>)`, never as a maintainer's pick, and settles no ruling.
- **A record that could not be written** (exit `1` or `2`) is said on the turn page as *answer unrecorded*,
  the reason quoted; it is never retyped into a file by hand.
- **A recorded answer that settles a ruling** becomes its ROSTER row by rendering, never by retyping:
  [`ROSTER.md`](ROSTER.md) § *The ruling template*, step 3.

**A command the maintainer must run is handed over as a runnable block** (ruling of 2026-10-17,
zheref/hatsu#295), on every surface and at every hand-over — a `DO` ask, en § 5's merge line, a host
relink, an ignore-file line, a repository setting (CON-33(b): the human gets the exact command): **complete**
(absolute paths, never a `cd … &&` chain — § *Writing a skill block*'s one command per block holds here too),
**one command per fenced `bash` block**, no `$` prompt, no interleaved output, and the message says
**where** to run it. It runs in the maintainer's own terminal, outside the harness guard, on their own
`gh` session — never a token pasted or printed. On the Claude desktop app's Code tab a `bash`-tagged fence
carries a Run button and *is* the hand-over; everywhere else — the Claude Code CLI, Codex, Cursor,
Antigravity — the fence is the copy source and the message says *paste into a terminal*
(`docs/surfaces/<surface>.md` § 7 names each mechanism, § 10 its evidence). A register `DO` ask carries the
same block in its `command` field, never in `why` alone. Prose that points at the register, a file or "the
command above" is not a hand-over.

**A question on the page is a question in the picker — always, in the same turn** (maintainer's
report, 2026-09-22: G5 options appeared on the report and nowhere else). Which asks make the bell a
stop and which only reach the picker is authored once, in [`jutaisho`](../claude/skills/jutaisho/SKILL.md)
§ 1, and cited here: an ask whose `gate` is G1–G5 makes step 6 `jutaisho at <gate>` — one of the five
above, or a G1–G4 genuinely due, never a sixth kind — and any other ask reaches the picker with rung 1
and no banner. The converse holds too: a condition not worth interrupting for is not an ask — its
default is applied and the page says so with the `decisions.json` row id. A picker tool the surface
lists as **deferred is loaded first** (Claude Code's tool search) and never treated as absent; only a
surface with no picker at all prints the lettered options in chat, closing with *answer with a
letter*, and says the picker was unavailable.

**The conditions that do NOT stop are data, from v0.41.0: [`nen/decisions.json`](../nen/decisions.json)**
(`nen.decisions/v0.1`, validated by `nen schema check`). By the maintainer's rulings of 2026-09-19 the
recurring stops have fixed defaults and every skill states its default in one line citing the row id: a
dirty tree at breath is carried (`dirty-tree`); an owed reviewer round inside the configured maximum is
requested on the maintainer's behalf (`cap-reached`); a red lint returns to rasengan (`red-lint`); a
missing focused route is authored by rasengan (`missing-focused-route`); a missing tool or model id is
installed or resolved (`missing-tool`); a red release precondition is reconciled in the same chunk
(`release-precondition-red`); a missing consumer declaration is repaired by tenkai or set up through an
assisted flow (`missing-consumer-declaration`, an ask-once row); and a semantic conflict is always
Crazy Slots with ours, theirs, a genuine third, and resolve-and-show-the-diff (`semantic-conflict`). A
`human-gate` row can never be widened by a consumer's own file; an unruled condition asks once with a
proposed issue, never a silent default. A stop typed as prose in the middle of a reply is a stop the maintainer can
scroll past, and one they scroll past is one that did not happen.

**Ask, set up, continue — a gap is never an abort** (maintainer's ruling, 2026-09-22). A skill that
finds a required argument missing or unparseable, or a configuration item absent — a `nen/workflow.json`
key, a lane or verb in `nen/contract.json`, a `nen/repos.json` entry, a launch target, a Hatsu-owned
scaffolding piece — **does not end the operation**. In order:

1. **Derive.** The session, the branch, its open PRs, `nen/workflow.json`, the detectors (`nen shu
   detect`, `nen repo resolve`, `nen shu tools`, the host's zone, the device list). One candidate that
   a canon default covers is **used and stated for this run only**, never asked about — the
   maintainer's standing preference for autonomy. A derived value is never written to a tracked file
   on that basis: writing is step 3's, and step 3 needs step 2's answer.
2. **Ask per item, inline**, through the surface's picker (Crazy Slots) with the candidates as options,
   the best one starred and the picker's free-text answer standing in for "type it" — rows
   `missing-argument` and `missing-configuration`. **One question per missing item**, never one
   bundled question for the whole run, and never a paragraph ending in a question mark. **The
   question budget, stated here once** (ruling of 2026-10-13, zheref/hatsu#175): **per run there is
   no cap** — one question per missing item, however many are missing; **per picker call, at most
   three questions** (the Codex picker's own cap, [`surfaces/codex.md`](surfaces/codex.md) § 7); a typed item
   (`missing-maintainer-choice`) counts like any other; and more than three missing items means
   **more calls, never a bundle** and never a refusal on the count alone. The one that unblocks the
   most is asked first, since its answer may derive the rest.
   [`STANDALONE-ENTRY.md`](STANDALONE-ENTRY.md) § 3 P4 cites this paragraph.
3. **Set it up on the maintainer's behalf, on that answer**, through the item's owner — `nen scaffold
   init` for a nen declaration, `scripts/tenkai_adopt.sh apply` for a Hatsu-owned piece,
   [`jujutsu`](../claude/skills/jujutsu/SKILL.md) for a device, the file's own key otherwise — validate
   with `nen schema check`, and say which file changed. **Any write to a tracked file needs the step-2
   answer; nothing is written unasked** — Tenkai's `fill` included, whose answer is Tenkai § 1's
   Apply, naming the values it writes. A tracked file rides this effort's branch, or its own
   declaration PR at that repository's gate when the effort is elsewhere. **A new lane, a verb `argv`
   or a `project.targets` entry lands through its declaration PR at that repository's gate before it
   runs** — never executed from an unmerged edit. **A value that looks like a secret is never
   written**: a `requiresEnv`-style key takes environment-variable NAMES only, and `nen stage triage`
   runs on the written file before the operation resumes (the `missing-configuration` row's `refuse`
   list, citing `secret-shape` and `signing-material`). **A frozen or foreign registry** — a reference
   repository such as `<reference-repo>`, another owner's `nen/repos.json` — **is reported, never
   written.** **A maintainer ruling that changes what readiness reads** — a check not to watch, a
   reviewer identity, an approval policy — **is `missing-configuration` too** (zheref/hatsu#104): it is
   written into `nen/gates.json` (`checks.excluded[]`, nen's own key, `reviewers`, `approval_policy`) at
   that repository's gate and the verb re-read, never carried in prose or a subagent's brief.
4. **Resume the original operation in the same turn**, with the completed line re-parsed.

**What counts as "required" is data, not each skill's memory** (the maintainer's ruling of
2026-10-01, [`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-01*): [`contracts/config-catalogue.json`](../contracts/config-catalogue.json)
names each settable value, its default and the skills that cannot run without it. Every phase's
warm-up asks for that phase's missing ones ([`ten`](../claude/skills/ten/SKILL.md) § 6, step 5b) as
step-2 questions here; the mechanics are [`tenkai`](../claude/skills/tenkai/SKILL.md) § 6d's.

**Every skill routes a missing repository declaration through Tenkai's diagnosis and guided
readiness pass**, then resumes its own verb after validation. The caller remains responsible for
its operation; Tenkai owns detection and the setup conversation. An effort artifact is different:
the `.nen/hanten/` review ledger is local audit state, created by Breath when it cuts the branch, or
by Hanten § 1's `ensure` for a branch Breath did not cut when no trace of an earlier ledger survives
(`nen review ledger`, zheref/nen#346). Its roster and maxima are the target's `review.scopes` alone: nen
has no fallback persona or budget, so a missing or malformed policy is exit `2` and configured, and an
unstamped ledger missing a declared reviewer's row is exit `2` and restored by hand (the table below). Recovery is for a **lost** one — `ensure`'s exit `4`: a trace says a
ledger was opened under the key before. A branch name reused after its branch was merged and deleted
reads lost too, by design: its marker never expires, so it is settled here, never silently re-opened. Tenkai diagnoses it, but its `apply` cannot create review
history. Hanten inspects prior review evidence; after the maintainer confirms this is the first
cycle under the key, Hanten runs `nen review ledger recover-first
--confirmed-first-cycle`, recording the recovery in the file. Otherwise it restores the original
used counts. Unreconstructable prior review history is a **safety precondition**, not a missing
configuration value; it stops at G5 rather than issuing a fresh budget.

**The review ledger's exits.** They route every `nen review ledger` call
hanten and breath make (`ensure`, `init`, `decide`, `record`, `show`, `recover-first`), read with `--json`; the refusal's
text, not the exit alone, picks the row (zheref/hatsu#216):

| Exit | The verb says | Route |
|---|---|---|
| `0` | `opened`, `present`, a new cycle, the document | say which, continue; relay a `durable marker` warning to the maintainer: lost-ledger detection for this key is weakened |
| `1` | a lock timeout or an I/O failure | stop naming the ledger path; re-run once the lock clears; never a recovery, never an `init` |
| `2` | the ledger already exists (`init`) | report it, never reset; hanten § 1's `ensure` owns a branch breath did not open |
| `2` | `review.scopes` is missing or malformed | `missing-configuration`: Tenkai configures `review.scopes`, then the same call re-runs |
| `2` | `unknown option` or `unknown subcommand` | read `nen --version`: below 0.26, bind the pinned nen (ten § 2) and re-run; at or above it, a wiring stop, quoted |
| `2` | `recover-first` refused (no `--confirmed-first-cycle`, or a ledger already there) | stop; never retried without the maintainer's confirmation, never over an existing ledger |
| `2` | missing, corrupt or ambiguous history (an unstamped ledger missing a declared reviewer's row) | restore the original counts; unreconstructable is G5, never a fresh budget |
| `2` | any other refusal (a bad argument, a budget misused) | a wiring stop, quoted |
| `3` | `ensure` refused: its `reason` names the trunk, `HEAD`, an empty branch or a `refs/*` name | stop: no effort ledger on that ref |
| `4` | `ensure: lost`, with `traces[]` | the recovery above |
| any other | nen absent (`127`), killed or crashed | stop and quote it; never a recovery, an `init` or a fresh budget |

**Switching writers.** nen's mutex (`<ledger>.lock`) does not exclude the retired script's OS lock
(`.cycle.lock`). A Hatsu below 0.136.0 still runs `scripts/hanten_cycle_ledger.sh` from its own
`$hatsu_root`; an installed copy whose root still holds that file is stale. Finish or stop every hanten
and breath session on such a copy, and refresh it (`hatsu:bakuryuha`, or ten § 4b's `hatsu_plugin_update.sh --auto`), before a
0.136.0 session writes the same `.nen/hanten/` ledger.

**What is not a gap — refused, never asked, never softened into a default.** Authored here once;
[`PROCESS.md`](PROCESS.md) § *Exit codes and refusals* and `claude/rules/hatsu.md` cite this list:

- **no tool or permission can supply it** — an actual rejection after the surface's supported
  recovery route, or that route unavailable or forbidden. An unreviewed sandbox failure first follows
  the surface adapter, including during an idle run; it is not yet this refusal. Where the act needs
  the maintainer's own hands — an install that needs
  `sudo`, an elevated window — it is not this item but kind 6 above, a G5;
- **a secret, credential or signing material** — never asked for and never typed into chat; the
  maintainer supplies it through their own tool, and one typed into chat or a picker is never used
  and is rotated. **This item outranks the open class**: a secret stays a refusal even though only the
  maintainer can supply it. (A secret-shaped path already staged is the G5 row `secret-shape`, kind 7,
  ruling of 2026-10-17, zheref/hatsu#290 q2.) An on-device act is not this list's either: it is kind 6;
- **a human gate** — G1–G5;
- **a supply-chain failure** — a checksum or manifest mismatch, never retried;
- **a mutating command inside a read-only loop**;
- **a safety precondition** — a go with no tag, a tag unreachable from the trunk;
- **a frozen or foreign repository** — reported, never written.

Such a refusal names what is missing, what was tried, the one command or act that unblocks it, and
where the operation resumes. **"Never invent a value" still holds** — an answered question is not an
invention — and **"never write the file unasked to silence a message"** holds with it: a message is
silenced by the maintainer's answer, never by a write nobody asked for.

**The maintainer's word is never derived.** Where a skill requires a value to be the maintainer's own
choice — a deploy or release target (`kagutsuchi`, `mugetsu`), an iteration cap
(`izanagi`), a device to trust (`jujutsu`), the request itself (`ren`), a runner pool's target,
machine code and service identity (`jusshin`, ROSTER § *Rulings of 2026-09-30 — jusshin*), and for an
interactive pool the `--accept-daily-account` word
(ROSTER § *Rulings of 2026-10-04 — interactive runner pools*) — it is
**typed, never picked** (row `missing-maintainer-choice`, whose `governs` list names those keys, with no `default`
and no recommended option). Step 1 never substitutes a candidate, even a single one; the ask takes the
maintainer's free-text answer; the declared candidates may be listed for reference, **none starred**,
and **never as a picker option that performs the act**. An undeclared target is refused, naming the
declaration PR that would add it. Asking replaces the refusal; it never replaces the choice, and a
skill may narrow it further (`mugetsu` asks only on the maintainer's own same-turn call).

**How a skill cites this.** One line where its invocation or configuration is read, in this form, and
nothing restated:

> *A missing argument or configuration item is asked for and set up inline (`missing-argument`,
> `missing-configuration`; [`WORKFLOW.md`](WORKFLOW.md) § 4 *Ask, set up, continue*).*

— or, where the value is the maintainer's word, *"typed, never picked (`missing-maintainer-choice`)"*,
and naming the owner that sets up a skill-specific item (a lane, a target, a registry entry) when it
is not the file's own key.

### Batch delivery — every delivery Ready, or held and named

**The maintainer's instruction of 2026-10-25** (zheref/hatsu#488): every Futon-based work batch drives all
of its work to Ready, and an unattended batch consolidates it into one integration-to-main delivery PR, or
the fewest justified. It binds **every Futon-based batch** — [`futon`](../claude/skills/futon/SKILL.md) and
each composite that runs it ([`kazaana`](../claude/skills/kazaana/SKILL.md), `dowsing-chain`'s `wave`, a
`then` chain) — attended or `--idle`, fresh or resumed; [`backlog-loop`](../claude/skills/backlog-loop/SKILL.md)
§ 10 ends its own run on the same states (it opens no manifest, so its held rows live on the register). A `--dry-run` rehearsal has predictions, not deliveries (§ *Idle
batches* rule 7), and stands outside rules 1–3. **A PR opened, green checks alone or a checkpoint report is not
delivery.** *Complete* (rule 3) ends the readiness obligation; *done* stays the merge (futon § 5), and the human
merge, the `then` gate (futon § 8), release authority and cleanup's own eligibility (zheref/hatsu#480) are unchanged.

1. **An actor behind every delivery until Ready.** Each delivery the batch opens — a PR into
   `branch.base`, a stacked PR, the integration PR — has [`en`](../claude/skills/en/SKILL.md) started on it
   in this session, never only offered. While any delivery is not Ready and the session is authorized and
   able to act — checks pending (en § 6's observation hold), a review round owed (`sharingan`), findings or
   threads unsettled (en § 4), a base to catch up (`murasaki`) — the batch does that work and observes its
   outcome. **Ready** is `nen pr ready --require-head <current head>` exiting `0`, quoted verbatim.
2. **Every delivery stands in exactly one state.** A prerequisite is never fabricated, waived or worked
   around to move a delivery out of `held` (`CON-32`; HR-5's human-gate rows).

   | State | When | Recorded |
   |---|---|---|
   | `driving` | `en` is acting or observing: rule 1's work remains | nothing ends while one is `driving` |
   | `ready` | rule 1's verdict at the current head, and the merge prompt shown — a stacked PR is Ready on its stacked base and shows none (§ *Stacked pull requests* rule 4) | the register row, the verdict quoted |
   | `merged` | merged into its base — by the maintainer, or by en § 5's bounded delivery exception | nen's manifest (`nen run verify`) |
   | `closed` | closed unmerged by the maintainer: not delivered, its issue left open | nen's manifest |
   | `held-<cause>` | short of Ready, and the session cannot move it | `nen run park --id <run id> --issue <CODE>#<N> --row held-<cause>`, plus three facts on the register row and in the closing report |

   The causes: `held-approval` (a review or approval only a person can give); `held-gate` (a G1, G2 or G4
   decision, en § 5's prompt at the sixth stop or the hanten prompt included, its verdict not Ready);
   `held-credential` (a credential, App or provisioning step); `held-cap` (en's acting-cycle cap, or the round
   ceiling, en § 6); `held-handback` (en § 6's observation errors, a draft or a retarget, en § 5's ownership or
   gate refusal); `held-stranded` (the child of a closed stacked PR, waiting on the maintainer to retarget or
   close it, § *Stacked pull requests* rule 5 — and a child GitHub itself closed when its base branch was
   deleted, the PR timeline's `base_ref_deleted` then `closed`, read raw, is `held-stranded`, never `closed`).
   A session that actually ended mid-run (en § 7) holds nothing: the resume (rule 5) finds each delivery
   `driving` again. nen `0.28`'s parks are append-only, so **a later state wins over a park**: a delivery
   `nen run verify` reads `merged` or `closed` after its `held-*` park is that state, never held. Under `--idle`, an effort's park (§ *Idle batches* rules
   1–4: a `hold` or `refuse` row, `g5-<class>` with `g5-harness-denied`, `residue-<skill>`, `budget`) **is** its
   held record. The **three facts**: the exact prerequisite or bound; the last `nen pr ready` verdict with its
   judged head (`no PR` for an effort parked before one); the resume action (`hatsu:en on <CODE>#<N>`, or rule
   5). A held delivery is never counted Ready, and the rest of the authorized work continues around it.
3. **Complete, or incomplete and said.** An issue with no delivery is **skipped**, said: out of scope,
   briefed (a handbook question or design call, futon § 2), § *Idle batches* rule 9's skips
   (`needs-clarification`, `g5-shape-unread`), or a legacy-CI PR owned by its own CI actor (futon § 9); the
   shape check's exit `2` instead stops the queue as one G5, and the batch ends incomplete on it. A batch is
   **complete** when every delivery is `ready` or `merged` and every other selected issue is skipped or
   `closed` — under `--idle` an included issue's delivery is the integration PR (rule 6); with any `held-*`, it is **incomplete**: the closing report and the Rikugan `register` list each
   held delivery with its three facts, and `final` is never rendered over it. **When the run ends is futon
   § 10's**: an attended run stays open while a delivery stands `ready` at its prompt and ends once none is
   `driving` and every delivery is `merged`, `closed` or held; an idle run ends at `idle.terminal`. The wrap-up
   picker is asked only after the run ends, never while a delivery is `driving`, and an incomplete end says so
   in the question.
4. **Unattended means integration.** One Futon run reads one repository and one base, so it has exactly **one
   integration branch** — recorded at its cut by `futon_effort_record.mts integrate --run <id> --branch
   <branch>`, which refuses a second branch and the default branch — and **one integration-to-main PR**
   carrying every effort merged into it. An effort that cannot join — its catch-up onto the integration branch
   stops at a semantic conflict (`ao`'s G5, row `semantic-conflict`) — parks `g5-semantic-conflict` and is
   listed as not included (rule 6); no second branch is cut for it. Separate integration deliveries come only
   from separate runs — one repository and selector each (a `dowsing-chain` wave runs one futon per member
   repository) — named in the closing report. Under `--idle` **no per-effort PR is opened and nothing is
   stacked**: each delegate and `mukai` stop at hanten's settlement, the effort is merged locally (futon § 5),
   and `en` runs on the integration PR alone; `futon_effort_record.mts bind` and `verify` refuse an idle run
   (§ *Recorded Futon delivery ownership*), while nen `0.28`'s `nen run append` does not refuse a `delivery`
   kind on an idle manifest (owed to nen, zheref/nen#544). Under the `ready-at-prompt` terminal no integration PR is opened, so
   each effort ends `held-gate` on the maintainer's go to open it — a reading of the § 2 `idle` row, named as
   one until it is ruled.
5. **A resume keeps the shape.** Futon never resumes itself: the maintainer re-types the line. Before `start`,
   futon runs `futon_effort_record.mts resume --repo <checkout> --invocation '<the line>'`: with no `--run` it
   continues the newest real run **that has not ended** whose line nen parses alike — repository, selector,
   terminal, `then` clause, `--idle`, `--dry-run`; never the spelling, so `--idle` may sit anywhere nen reads it.
   futon § 10 records the end with `futon_effort_record.mts end --run <id>`, so the same line typed after a
   finished night is a new run; a record written before end tracking carries no end mark and resumes by an
   explicit `--run` alone.
   **Exit `3`** means no open run: `start` opens one and names any earlier run typed as the same line. **Exit
   `1`** is a refusal — stop and report it, **never `start`**, which would split the delivery. A resume proves
   the run's identity and never re-derives its policy: nen's manifest must already be on disk (with none it
   refuses **before** calling nen, which would write an empty one that `nen run verify` reads as an open gate),
   the answers resent are the ones nen stored — re-checked against § 2 `idle`'s floor, which nen does not apply
   — and the recorded `idle.terminal` and integration branch hold; a committed profile that moved since launch is
   reported, never obeyed. It refuses a line nen parses otherwise, an ended run, a dry run, a v0.1/v0.2 record, a manifest
   started at another time, a record whose id differs from `--run` or from its filename, and another
   repository. The budget clock is the manifest's `startedAt` (§ 2 `idle`), so a resumed idle run whose minutes
   are spent claims nothing new and drives what it already opened. Reading nen's manifest file directly, and
   refusing one still at its legacy spelling, is named residue owed to nen (zheref/nen#545). `kazaana` passes the
   futon line it composed (kazaana § 1). The resumed run keeps the same integration branch and PR and the same
   readiness obligation for every included delivery, reading what was already opened through `nen run verify
   --id <id>`.
6. **A consolidated PR accounts for everything it carries.** The integration PR closes and links every
   included issue (one `Closes #<N>` and Development link each) and its criteria section answers every
   acceptance criterion of every included issue, by issue. An issue whose effort did not merge into the
   integration branch is listed as **not included**, with its held or parked state — never covered by the
   PR's Ready.

### Idle batches

**HR-5's idle profile, activated only by a typed `--idle`** on a `futon` line (and on `kazaana`, which
composes it): `hatsu:futon <repo>@<selector> --idle [--dry-run] [then …]`. `nen parse futon` reads `--idle`
itself (`idle: true`, nen `0.26.0`, the first or last token before `then`) and nothing in Hatsu strips it.
`--dry-run` (zheref/hatsu#424) is no nen grammar at the pin: the record's `start` lifts that one token off
before the parse (and futon § 1's echo parses the line with it lifted, saying so), and refuses it without `--idle`, typed twice or after `then`; it refuses **any other `--`
token before `then`** and a doubled `--idle` (exit 1, the token named), which nen would fold into the label.
The keys are § 2's `idle`; the manifest is nen's (§ *Recorded Futon delivery ownership*).

1. **Pre-answers.** `start` resolves `idle.decisions` for every `ask-once-per-run` row of
   `nen/decisions.json`, read from the **committed** `nen/workflow.json` of the remote default branch only
   (`origin/HEAD`, else `gh repo view`'s `defaultBranchRef`; SEC-15), never `HEAD` or a ref `HEAD`'s commit
   names, never the working tree; a default branch with no `nen/workflow.json` refuses `start` (exit 1, reason
   printed); § 2's floor fails `start` at exit 1. The resolutions are the manifest's `idleAnswers`, fixed at
   `nen run start` (a re-start with other answers is refused), and `start` prints them back from the manifest
   nen wrote with the commit read (`idle.source`). The register lists them every cycle. Where a skill would ask
   a row: `default` takes its starred option, says so and records it (§ 4 *Every picker
   answer is recorded*); `hold` or `refuse` asks nothing and **parks the effort** (`nen run park … --row <row>`), and the run moves to the next one. **No picker is shown in an idle run.**
2. **Stops park, they do not end the run.** A G5 parks the effort as `parked:g5-<class>`; a harness
   permission denial is a G5 **after the surface's supported recovery route has answered**. On Codex,
   apply [authorized write recovery](surfaces/codex.md#authorized-worktree-write-recovery) to an
   unreviewed sandbox failure first, including checkout creation and Git metadata writes before a
   manifest exists. A supported review request is part of recovery, not retrying past a rejection;
   `--idle` does not suppress it. A real rejection stops that action; an unavailable review route
   reports its capability limitation. If the manifest cannot be created, report `startup blocked;
   park not persisted`, never a recorded park or an empty successful run. A human-gate row is never
   pre-answered: the effort stands at that gate.
   (Park rows are `[a-z0-9-]+`, the spelling nen refuses otherwise; the colon forms of 0.136.0 are retired.)
3. **Residue parks.** In the batch, a step a skill marks *by hand* or *no verb* is never improvised as
   shell: the effort parks as `parked:residue-<skill>`.
4. **Bounds.** Before each claim, `nen run budget` (§ 2 `idle` → `budget`, its four exit rows) gives the
   wall-clock minutes against the ceiling `start` printed; at `remaining.minutes` `0` nothing new is claimed
   and the rest park as `parked:budget`. The token bound is advisory where the ledgers are unread (§ 2).
   **Slots are counted from two sources and summed** (futon § 6, § 2 `monitor`, [HR-353](ROSTER.md#hr-353), record `R-2026-10-23-20`: a slot is held from
   the claim until `ready+prompted`): `nen loop slots --from-run <run id>` counts the run's delivery PRs, and
   `nen loop slots --efforts <abs path>` counts the run's claimed efforts that have no delivery PR — every
   effort worktree of this run (`nen wc worktrees`) whose branch no `nen run verify` row names, one object
   `{"id": "<CODE>#<N>", "plane": "local", "prOpen": false, "ready": false, "prompted": false, "merged":
   <its branch is an ancestor of the integration branch>}`; the run claims only while the two `local.occupied`
   sum below `--local-cap 7`. (nen's `--from-run` counts appended PRs only and refuses `--efforts` beside it:
   a claimed-efforts count in the manifest is owed to nen.) A slot frees at `ready+prompted` ([HR-353](ROSTER.md#hr-353), record `R-2026-10-23-20`): the effort's PR Ready and
   its prompt shown, or, with no sub-PR, its local merge into the integration branch; till then the rest **wait**
   (back-pressure) and park as `parked:budget` only when the minutes elapse. **The merge no longer caps the night at seven**:
   each effort frees its slot at its own Ready prompt, so at most seven build at once and the night authors
   as many claimable efforts as `idle.budget.minutes` allows. How many that is was not measured: the
   2026-10-23 dry run authored nothing and recorded no per-effort minutes, only 13 claimable efforts and the
   cap applied in queue order (`docs/ab/futon.md` § 2026-10-23).
   Overlap is `nen wc overlap --efforts <branches> --repo <checkout>` once branches exist (before that it is
   judged from the paths each effort would touch), its verdict cited in the stacking decision (attended; an idle run never stacks, § *Batch delivery* rule 4); `nen stage
   check --exclusive` holds an issue to one stage label where the target declares a stage family. En's cap is
   the git common dir's (en § 2).
5. **Terminal — integration branches only** (the ruling of 2026-10-23, § 2 `idle`; fixed at `start` and kept
   by a resume, § *Batch delivery* rules 4–5). An idle run always cuts
   futon § 5's integration branch and merges each hanten-settled effort into it locally; `idle.terminal` is the
   integration PR Ready at the maintainer's merge prompt (or, under `ready-at-prompt`, short of opening it:
   each effort `held-gate`, § *Batch delivery* rule 4's reading). **Never a merge into `main`** — the maintainer alone merges there — **never `getsuga`,
   `mugetsu` or `kagutsuchi`**: a `then` step past the terminal is held, named, unrun. A host scheduler may
   re-invoke the build, never a release. The steady-state schedule is [`config/schedule.md`](config/schedule.md)'s; its
   tasks are registered only by the maintainer. `cleanup` runs its deterministic rows for this session only
   (`cleanup-plan` → `default`); a proposed row is never applied unattended.
6. **One manifest, one gate.** Every run `start` opens has one nen manifest, and futon § 8's `then` gate,
   kazaana § 5 and the register read it through `nen run verify` — every opened PR and every parked effort.
   Hatsu's ownership record beside it carries no PR set and no park (§ *Recorded Futon delivery ownership*).
   The manifest is written at nen's default file mode (0644 under a 022 umask), not owner-only as the record
   is: it holds no credential, but a consumer's private repository name can appear in it (owed to nen).
7. **`--dry-run` — the rehearsal** (zheref/hatsu#424, the SDD plan's P8 proof). The record says `dry: true`
   (`profile`); nen's manifest carries no dry flag at the pin, so the register reads it from the record and
   says the run was dry. Every read-only verb of futon §§ 1–2 and § 6 runs for real; **nothing is authored or
   written outside the two local records** — no label, branch, worktree, pull request, comment, push or
   release: futon §§ 4–7's acts are held, `nen run append` and `nen run park` are never called, `bind`
   refuses a dry run, and no `then` step runs. Each selected effort's **dry end state is the first stop its
   read predicts**, never a built result, recorded on the ownership record by `futon_effort_record.mts predict
   --run <id> --issue <CODE>#<N> --row <row>` — never in nen's `parked[]`, HR-5's real park state: a
   pre-answered `hold`/`refuse` row, `g5-<class>` (a decide, a dependency), a human-gate row, `missing-tool`,
   `residue-<skill>`; a claimable effort inside `--local-cap` in queue order is `dry-prompt` (it would stand
   at its prompt, which frees its slot under `ready+prompted`), and the remainder `dry-waiting-slot`. The register states
   the `dry-prompt` count as the efforts one night can author, every pre-answered row with its resolution, and
   every prediction `profile` prints (`docs/ab/futon.md` § 2026-10-23).
8. **Every decision taken for the maintainer is listed** (the ruling of 2026-10-23). A decision is every
   pre-answered row `start` printed and every `default` actually taken during the run (row, option, object,
   time). The list goes in three places: the shibari PR body's **Decisions taken on your behalf** section
   (`contracts/pr-sections.json` footer row `decisions`, resolved by the `decisions` run fact as that row
   records it (zheref/hatsu#474), mandatory on every PR an idle run opens), the run's final delivery brief (futon § 10's closing report), and the Rikugan register's
   `legendRows` (`backlog-board` § 3), one row per decision.

9. **Nothing blocks a batch; an open question is skipped and brought to the final briefing** — [HR-335](ROSTER.md#hr-335)
   (typed, record `R-2026-10-23-02`; its words are the row's, not restated here).

   Applied, attended or `--idle`: futon § 2's shape check (`docs/config/plugin-registries.md`, *The check*)
   **skips** an issue whose `nen issue questions` reads `counts.open` above `0` — parked in the run record by
   `nen run park --id <run id> --issue <CODE>#<N> --row needs-clarification` (a dry run: `predict`, rule 7) —
   and the queue continues with the next issue. `needs-clarification` is a **named park class**, not a G5 and
   not a `nen/decisions.json` row (the park grammar of § *Recorded Futon delivery ownership*). An issue whose
   questions could not be read (`nen issue questions` exit `1` with **no document on stdout**; from nen `0.28` an
   exit `1` whose document is still printed is an open `OQ-{n}` row, read, and parks `needs-clarification` as above)
   is skipped as `g5-shape-unread`, never addressed unread; exit `2` is **wiring** (a malformed catalogue or a usage error) and stops the queue statement as one
   named G5, never N skips; a body-shape miss is reported and never skips; nothing else in the shape check stops
   the queue. The **final briefing** (futon § 10's closing report) and the **Rikugan
   register** (backlog-board § 3) list every skipped issue with its open `OQ-{n}` rows (id, gate, question), and
   the briefing **ends by offering, never starting**, the **open-question flow**: one line, asked through the
   surface's native picker in jutaisho § 4's shape (`AskUserQuestion` on Claude Code). Started on the
   maintainer's answer, the flow raises **one picker per open `OQ-{n}` row** across the skipped issues of the
   original queue, in queue order; records each answer with `nen stop answer --record <effort> --gate
   <the row's gate> --who maintainer …` (its `R-` id; `--row` takes only a `nen/decisions.json` row); and strikes the row into the issue as
   `- ~~OQ-{n}~~ → A: <answer> (<YYYY-MM-DD>, <R-id>)` through `nen issue edit-body --expect-body-sha256 <the
   read body's sha> --current-body-out <path>`, then reads it back with `nen issue questions` (the row must
   count resolved). No nen verb rewrites one row, so the struck body is composed for `edit-body` as named residue (a verb owed to nen).
   An issue whose rows are all struck re-enters the next run's queue.

### `classify` — the two label axes, and the one place their vocabulary lives

The maintainer's rulings of 2026-10-04 ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-04 — classify and
direct*) are recorded there and executed by [`classify`](../claude/skills/classify/); this section states only
the **configuration consequence**. The two label families (`lang/<key>`, `job/<key>`) are read structurally
through their prefixes, and their vocabulary — every key, prefix and colour — is written in **one** place,
[`contracts/classify.taxonomy.json`](../contracts/classify.taxonomy.json), plugin canon read through
`$hatsu_root`. A **consumer's `nen/labels.json` stays the one source of truth for that repository's labels**:
`nen classify install --write` populates it from the taxonomy, the change **lands through its own declaration
PR at that repository's gate**, and GitHub is synced only after (`nen classify install --sync`,
which refuses an unlanded declaration — the family ships from the `v0.20.0` pin). The domains are
derived at run time by the taxonomy's `domains.rule`, never labelled. `classify.publish` (`label`, the default, or
`label+comment`, § 2) decides whether the resolved criteria are also written to the issue as one marker-keyed
comment (classify § 5b; catalogue id `workflow.classify.publish`). Nothing else about classification is
authored here.

### `direct` — the model, surface and effort, as a configuration consequence

The same rulings, and the rebalance of 2026-10-05 (ROSTER § *Rulings of 2026-10-05 — the registry rebalance*);
[`direct`](../claude/skills/direct/) is the home of the procedure, this the consequence for the two files.
[`contracts/direct.registry.json`](../contracts/direct.registry.json) is plugin canon: stable aliases map onto a
provider, a model **line** (`claude`, `gpt`, `gemini`, `grok`, `composer`), a model **family**, their Hatsu
surface, a **tier** of this file's `models` block and an **escalation** — never a model version — so the `models`
matrix is the only per-surface fact a consumer declares and a model release moves nothing in either file. **The
primaries live on the deep and fast tiers** (`opus`, `sol`, `grok`, `pro`; `sonnet`, `terra`, `composer`,
`flash`) and the frontier aliases (`SEMANTIC_MAX`, `EXECUTION_MAX`) are reached only as the **recommended**
pick, for the maintainer's own session; a subagent is still never raised on them. **Every cell yields three
picks**: the primary (the cell's winner, the cost-aligned best), the fallback (its runner-up, on another
provider or surface in every cell, so the work can move when one pool's funds run out — at the aggregate of
several pairs the reader names the other-pool alias where the verb's runner-up shares the primary's pool,
zheref/nen#389) and the recommended (the primary's escalation on a weight-4 job or a `max` effort, else the
primary). **Companion jobs** (`review`, `delivery-ops`, flagged in the taxonomy) are kept out of the verb call
that decides and reported from a second call: that work runs on the **session's** surface — the surface the
effort runs on, where hanten raises its reviewers (§ *The matrix, per surface*) — at `models.roles.<role>`: the
role's tier, never the session's (§ `models`). The verdict persists in `.nen/direct/<effort>.json`, and on GitHub only where `direct.publish` (§ 2) opts in — per issue under `build`, under `file` once the issue is created (file § 5), or standalone, or over a whole backlog through `hatsu:direct backlog [<repo>]` (direct § 8: one table, one confirmation, then label and comment per issue). The one question those rulings returned to the maintainer — whether `models.roles.reviewer` stays
`deep` when direct's verdict for the session is a lower tier (zheref/hatsu#222) — was answered on
2026-10-13: it does (ROSTER § *Rulings of 2026-10-13*). **The readable
mirror** is [`DIRECT-MATRIX.md`](DIRECT-MATRIX.md): every job × domain × language cell, the alias table with
list prices and served ids, the three picks, the effort rule and worked examples. `scripts/direct_matrix_doc.sh`
renders its tables and rule text from the registry, the taxonomy and Hatsu's own `models` block; only its
opening walkthrough is hand-written. The registry stays canon and the page is never edited by hand. Lane
`direct-matrix-guard` runs the generator's `--self-test` — the registry's own invariants over every cell among
them — and fails on a stale page. `--verify` asks `nen direct resolve` about every claim the page prints.
The trusted `surface-mirror-check.yml` PR check runs `--check` on every PR, including data-only edits,
and the repin procedure above requires `--verify` with the new nen. Its TypeScript adapter requires
Node 22.18 or newer (native type stripping); the declared `ubuntu-latest` runner currently supplies
Node 22. Recheck that floor when GitHub updates the runner image. The focused lane remains useful
locally on the same Node floor.

---

## 5 · The PR side — `mukai`, and everything it runs

`ren` (§ 4) never opens a pull request. **`mukai` is the phase that does**, and like the other four it is the
maintainer's to call. Its order is fixed, and each step has exactly one job.

### `mukai` — the steps, and the stops

| | Step | What it does | Where it stops |
|---|---|---|---|
| **1** | [`murasaki`](../claude/skills/murasaki/) | catch up through [`ao`](../claude/skills/ao/), verify the changed tree with `iteration.checks`, **only if the branch is already published**. A red merged tree goes to [`rasengan`](../claude/skills/rasengan/) to be authored. Never squashes, never force-pushes, never runs project-wide tests | **G5** on a *semantic* conflict in `ao` — a mechanical one is resolved |
| **2** | [`hanten`](../claude/skills/hanten/) | the adversarial review: classify the change set by scope, one reviewer subagent per scope | **G5** on an unsettled finding — after Kurapika has fixed it or pushed back with a reason |
| **3** | [`kokusen`](../claude/skills/kokusen/) | checkpoint review/snapshot edits with focused tests | **G5** on a red focused run or a missing scoped route |
| **4** | [`kotoamatsukami`](../claude/skills/kotoamatsukami/) | the sole project-wide test run: only declared unit, UI and integration suites this change can affect. No coverage capture. Aka did not run this | **G5** on red required tests. A seat (exit `4`) is quoted, never routed around |
| **5** | [`byakugan`](../claude/skills/byakugan/) | capture and measure independently of those suites; apply the `coverage` ladder of § 2, without rerunning tests | **G5** when a touched file is under `minimum` and cannot honestly clear it |
| **6** | the push half of [`murasaki`](../claude/skills/murasaki/) | **publishes the final proved tree**, and only when this catch-up is a no-op. If it changes any tree path, return to steps 3–5 (kokusen, kotoamatsukami, byakugan) before pushing. Review fixes and byakugan's new tests are working-copy edits; neither of those skills may commit or push; step 8 refuses to open a PR while `HEAD` is ahead of `origin/<branch>` | **G5** on a semantic conflict where the base moved again |
| **7** | evidence | the changed visual artifacts, from `project.evidence` (§ 3), grouped **suite → scene**, from kotoamatsukami's existing artifacts | not a gate event |
| **8** | [`shibari`](../claude/skills/shibari/) | composes and opens **one** PR, requests the reviewers and writes the body back | never labels a gate, never merges |
| **9** | [`spiritual-message`](../claude/skills/spiritual-message/) `as landing` | the landing report, rendered **after** the PR exists because its two extra sections — the PR body and the readiness verdict — are step 8's outputs. Mukai then rings, offers [`en`](../claude/skills/en/) through the picker and ends (starting it only under `mukai.autoEn`) | not a gate event; En owns current-head readiness once started, and the user turn remains active under En while CI/review is pending |

**Most of § 4's G5 kinds live inside this one phase.** That is not an accident of layout: a
pull request is the moment work stops being private, so it is the moment the honest questions are cheapest to
ask and most expensive to skip.

### `hanten` — where the routing and the finding shape are written

**Neither lives here.** The routing is data — `nen/workflow.json` → `review.scopes`, read by
`nen review scopes` — and the protocol is
[`claude/skills/hanten/SKILL.md`](../claude/skills/hanten/SKILL.md) § 5 with
[`claude/agents/_review-preamble.md`](../claude/agents/_review-preamble.md) § 4. A table copied here
is a second source that drifts the moment a scope is added, which is what happened: this section
carried five reviewers and a four-field shape long after there were six of each.

**What is worth saying once, in prose: there are eight scopes, and one of them claims every path.**
`code` is **Nobunaga's** and its `paths` is `**`, so he is the default reviewer on every change set;
`security` is **Feitan's**, `architecture` **Chrollo's**, `ui` **Hisoka's**, `performance`
**Uvogin's**, `surfaces` and `release` **Phinks'**, each raised only by the paths its own row declares;
`economics` is **Leorio's**, raised by its paths *or* by content ([`ECONOMICS.md`](ECONOMICS.md) § 1) and
never on every diff — and his return is a **report** the maintainer weighs, not a verdict: a cost is never
a finding, and hanten writes the report keyed per effort, `<reports.dir>/hanten/<branch-slug>[-pr<N>].economics.md`
([`ECONOMICS.md`](ECONOMICS.md) § 5). Every row
carries its `persona`, its `tier` (`models.<surface>.<tier>` of § 2, never the frontier one) and its
`budget` — the reviews that scope gets per effort (a branch plus its PR; never per session), counted in
`.nen/hanten/<branch-slug>[-pr<N>].cycle.json` and never in prose. **Reviewers advise; Kurapika acts** — he
fixes the finding or pushes back with a cited reason, and a finding that is neither is the **G5** of
§ 4, raised by `hanten` and never by the reviewer. **Pre-PR, a finding's home is the working copy,
not the tracker**: an issue is filed only when the finding outlives the branch.

### `byakugan` — the ladder, spent

Byakugan is where § 2's `coverage` ladder stops being a table and becomes a decision, after
kotoamatsukami has already run the impacted suites. It captures the instrumented result independently
of those suites, then reads **touched-file
line coverage** — the files in `git diff --name-only origin/<base>...HEAD`, never the repository total — and reports
each file against the three rungs:

| Band | What byakugan does |
|---|---|
| below `minimum` (80) | **adds tests** (then kotoamatsukami re-runs the suites) until the file clears it; when it cannot be cleared honestly, **G5** |
| `minimum` … `recommended` (80–85) | reported, and aimed past |
| `recommended` … `ideal` (85–90) | reported as the band it is |
| at or above `ideal` (90) | said out loud, because it is worth saying |

**The bar is never lowered to clear it.** That is the one move byakugan will not make: a repository that cannot
honestly reach `minimum` is a **G5**, not a smaller number. And `nen shu coverage` **reports** `met` and
never changes its exit code — nen does not decide whether a number is good enough, which is exactly why this
step is a skill and not a flag.

### `gyo` — linting, every Ren turn

Gyo is the named process for the declared `lint` verb. It is not the coverage bar. Breath proves
it on the fresh tip, rasengan may run it as authoring feedback, kokusen must run it before every
local commit, and aka runs it before squash and after catch-up if the tree moved.

### `shibari` — one PR, and the body it must carry

`shibari` opens the pull request **from the last pushed commit**, against `branch.base`, and it opens
**exactly one**. The body is not a template preference; it is what makes the PR reviewable by someone who was
not in the session:

The body follows [PR-SECTIONS.md](PR-SECTIONS.md), resolving the catalogue's kind × family cell
from the repository classification, issue jobs, consumer `pr.sections` and Mukai's run facts. It
opens with the ledger-rendered Delivery preamble, then consumer effect and cost in **What this changes for you**; tables and diagrams carry
the decision. Non-release rows carry the eleven-aspect improves ladder; release rows follow the
written matrix, per the clarification of 2026-10-20. The one `verify` id uses product **How to verify**,
library **How a consumer verifies**, or process **What the guards prove**; the latter two are the
`CON-17(b)` observable proxy, without a handbook amendment. There are at most seven reader sections;
Delivery is outside the reader cap; checklist, associated issues and final attribution are compact footer blocks.
The sections and Delivery guards and Nen's per-run requirements check join evidence and Development checks before
**every** create or edit. No undeclared heading may grow a second composition contract.

The verbs: `nen pr open` (the one PR, from the pushed head, at nen `0.13`: exit `2` when the head is not
on the remote, exit `1` naming an open PR for the branch; from nen `0.26`, exit `0` with `existing: true`
adopting the PR already open at this base and head commit), `nen pr body-check` (the body's completeness),
`nen changelog fragment-required` (whether this change owes a fragment), `nen gate derive` (which gate
the PR stands at — **derived, never labelled by `shibari`**), `nen pr edit-body` to write the body back,
and `nen pr request-reviews` to request the reviewers. **`nen pr edit-body --target <owner/name> --pr <n> --body-file <path>` exists from nen
`0.5.0`** and replaces the body outright from the file's bytes, certifying the number before any write and
refusing an issue number at exit `2`. `gh pr edit --body-file` is retired with it (§ 7).

**The evidence mechanism is assumed with confirmation, not guessed**: a stack with a registered
public-assets mirror embeds the images; a stack without one names each scene and points at its committed
snapshot path in **Files changed**. A Files-changed PR that names its scenes is **conformant**, not a
shortfall — and a rule never mixes the two mechanisms.

Then `shibari` hands the PR to `en` and stops. It never applies a gate label and it never merges.

### `en` — the readiness watch, its two keys, and the Illumi hand-off

```json
"monitor": { "maxCycles": 20, "pollSeconds": 300 }
```

`en`'s order: [`spiritual-message`](../claude/skills/spiritual-message/)¹ (landing — the PR body and the readiness verdict) →
[`sharingan`](../claude/skills/sharingan/)² → [`murasaki`](../claude/skills/murasaki/)³ when the branch is
behind → `sharingan`⁴ → **observe⁵ while required CI or the current-head reviewer round is pending**, still
reacting to new comments, threads, reviews and conflicts → [`jutaisho`](../claude/skills/jutaisho/)⁶ once
at Ready → the dated **final** report, [`rikugan`](../claude/skills/rikugan/)'s one-effort Rikugan rendered through `nen report render --variant final` (`backlog-board` § 3's path), **the only report written to `Reports/`**, then stop at the human gate.

**Who starts en:** [`mukai`](../claude/skills/mukai/) (its offer, or `mukai.autoEn`), [`futon`](../claude/skills/futon/)'s
per-issue chain, the maintainer by name — and [`getsuga`](../claude/skills/getsuga/) § 3 for the release
proposal it opens, where en runs ¹–⁵ and **returns the quoted verdict to getsuga instead of ringing ⁶**:
§ 3a is that proposal's merge (ROSTER § *Rulings of 2026-09-26/27/28*, ruling 4; zheref/hatsu#103).

| Key | What it bounds |
|---|---|
| `maxCycles` | the `izanagi` cap on **acting reactions**. **Grammar, not a default** — an en run invoked without one does not run, and `nen loop iterate` refuses the claim that would exceed it. Quiet observations claim nothing |
| `pollSeconds` | the interval between observations. Never shortened because something looks close |

**An exhausted cap is reported as exhausted.** It is never extended in place, never continued by a second
watch started to finish the first, and never rendered as "still watching". Raising the cap is the
maintainer's word, in a new invocation — and from nen `0.7` it is also the binary's answer: the claim past
the cap is refused, and the refusal says so in nen's own words rather than in a skill's.

**When the pre-Ready observation hold is expected to be long, step 5 is handed to Illumi** —
[`illumi.md`](../claude/agents/illumi.md), titled `en · illumi · <model alias>`, on the **fast** tier at
effort `medium`. He is **provisioned, not ratified** (`OPEN-1`, partially closed 2026-09-09) for this watch
**and no other loop**: not `backlog-loop`, not `futon`, not `senkei`.

He is **read-only by discipline, and the definition says which** — his frontmatter carries no `Edit`, `Write`
or `MultiEdit`, but it does carry `Bash`, because every observation is a program and `Bash` can push, commit
and merge as easily as it can read. What holds is the **command allowlist** in
[`illumi.md`](../claude/agents/illumi.md) § *The allowlist*; anything off it is a wake, not a command. He acts
on nothing. Each observation he records five facts (the readiness verdict *quoted*, the checks, review activity,
base drift, terminal state), compares them against the previous observation, and **wakes Kurapika** when one of
seven conditions fires: Ready, a new review or thread, a check gone red, the branch behind or conflicted,
merged, closed-or-drafted, or an act is refused at the cap. Quiet observations never consume that cap. The hand-off names **what changed, since when, the PR's
current state, and the act it needs** — *names* the act; never performs it. **A watch that acts is not a
watch**, and the merge/vote stays human-gated.

### `drive` is now `sharingan`

The skill that drives one open PR to readiness at its gate was `drive`; from **`v0.5.0` it is
[`sharingan`](../claude/skills/sharingan/)**. **Nothing about its behaviour changed** — first blocking
condition, thread stewardship, wakes, the deterministic readiness verdict quoted rather than eyeballed, no
merge and no vote. What changed is the name, and it changed for one reason: `drive` was the only skill in the
loop named after what it does rather than out of the shared naming, and a name that stands outside the scheme
is a name that reads as a different kind of thing.

Concretely: the directory is `claude/skills/sharingan/`, the invocation is **`hatsu:sharingan`**, the
evidence record is `docs/ab/sharingan.md`, and every reference in the other skills and in this documentation
moves with it. **`hatsu:drive` no longer resolves** — an installed copy that still answers it is a stale
cache, which is what the version bump in `.claude-plugin/plugin.json` exists to prevent.

---

## 6 · The hooks

[`../hooks/hooks.json`](../hooks/hooks.json) carries three Claude Code hooks: `SessionStart` (`hooks/session-start.sh`: first the pinned `nen` bound on the host through `scripts/nen_global.sh` — `~/.local/bin/nen` and the shell rc's PATH block, opt-out `HATSU_NEN_GLOBAL=0|false|no|off` or `${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/nen-global` reading `off`, ruling 2026-09-30 — then a warm-up reminder on Claude Code and, on a mirrored surface, a mirror refresh in a repository that already adopted Hatsu, fail-open; [`docs/using/README.md`](using/README.md) § *The four surfaces, compared*), `Stop` and `PreToolUse`. **None is a nen-owned step** — the binding runs nen's own bootstrap and links what it verified.
They are executed by the harness *around* a session rather than by a skill *inside* one, and they exist for
the three things a skill structurally cannot do: a skill only runs when the model calls it, by the time the
model has stopped talking, or has already typed the push, it is too late — and **binding the host's `nen`
before any skill runs** (the hooks' third purpose, ruling of 2026-09-30). That step 0 runs on the source
copy always, and on a mirrored copy only once its plugin root (`HATSU_PLUGIN_ROOT`, Codex's `PLUGIN_ROOT`)
is verified; a watchdog bounds it at about 50 s even where no `timeout` exists.

| Hook | Event | What it does |
|---|---|---|
| [`stop-bell.sh`](../hooks/stop-bell.sh) | `Stop` | rings `notifications` rungs **2 and 3** off the marker at `.nen/last-stop.json`, then consumes it |
| [`guard-base-branch.sh`](../hooks/guard-base-branch.sh) | `PreToolUse`, matcher `Bash` | exits `2` — blocking the tool call — on a raw `git` commit or push while the branch equals `branch.base`; the skills commit and push through `nen commit write` and `nen wc publish`, and the latter refuses the trunk itself at exit `2` |

**Every surface has all three hooks once its hook file was placed.** `hooks/hooks.json` is Claude Code's
manifest, discovered at the plugin's own `hooks/` path; `nen surface mirror generate --hooks` renders the
same three rows into the hook file each other surface documents (Codex `.codex/hooks.json` with `Stop`,
Cursor `.cursor/hooks.json` with `stop`, Antigravity `.agents/hooks.json` or the global plugin's
`hooks.json` with `Stop`; [`docs/using/README.md`](using/README.md) § *The four surfaces, compared*), and the warm-up places that file. So
the bell's in-session fallback in [`jutaisho`](../claude/skills/jutaisho/SKILL.md) § 5 keys on one fact,
**was a hook file placed here**, never on a surface list: where none was placed the skill rings rungs 2
and 3 itself, says so, and removes `.nen/last-stop.json` once the stop is answered; where one was placed
the hook fires and consumes the marker, and the skill leaves it alone. The trunk guard keys on the same
fact: with no hook file placed, the refusal to commit on `branch.base` is the skills' own rule, not a
reflex the harness enforces. **Say which of the two you are relying on.**

**The guard parses the command; it does not match a substring.** A shell wrapper is unwrapped first — `sh -c
'<script>'` *runs* `<script>`, so the payload is recovered and parsed as its own segment. Quoted spans are then
masked to one token, the line is split into segments on `;` `|` `&` `(` `)` and the backtick, and a segment
counts only when its **first** token is `git` and the token after git's own global options — `-C <dir>`,
`-c <k=v>`, `--no-pager`, `--git-dir`, `--work-tree`, `--namespace` and the rest, in both the separate-argument
and the `--key=value` form — is `commit` or `push`. So `echo 'git commit'` and `git commit-tree` are not
writes, while `git --no-pager commit` is.

**The directory git targets is the directory judged — never the session's own.** Every `-C` the segment
carries is applied *cumulatively*, in argv order, exactly as git applies it (`git -C a -C b` runs in `a/b`);
`--git-dir` and `--work-tree` are then resolved against the directory that chain arrived at. Only a segment
carrying none of them is judged in the working directory, and a `cd` earlier in the same line moves *that*,
because judging `cwd` after a `cd` is judging the wrong repository. So a session standing on `main` may drive
a worktree that stands on a feature branch — `git -C <worktree> push` is **allowed** — and a session standing
on a feature branch may not drive a checkout that stands on `main`, which is **refused**. Reading the session's
own branch answers both of those wrongly, and a worktree effort types the first shape all day.

It **fails closed** on the five forms where the branch it can see is not the branch the write would land on: a
line that both changes branch (`switch`, `checkout`, `branch -f|-m|-M`) and writes; a repository-selecting path
quoted in a form it cannot recover, *including two DIFFERENT quoted paths for one flag anywhere on the line*,
whether both on one segment or one on each of two, because recovery is line-global and cannot tell whose span is
whose; a `git` segment carrying a
`commit`/`push` token alongside a **global option the guard does not know** — an unknown `-…` may or may not
swallow the token after it, so it is named in the refusal rather than walked past; a `git` segment whose
subcommand the option walk could not establish for any other reason; and a shell wrapper whose payload cannot
be read on a line that carries a write token. The policy it compares against comes from the checkout the branch
came from — for a bare `--git-dir` aimed at a linked worktree, that worktree's own `nen/workflow.json`, not the
primary checkout's. The script's own header carries the fifty-seven cases this was
verified against, and [`ab/guard-base-branch.md`](ab/guard-base-branch.md) carries the transcripts.

**The stop marker** is `hatsu.stop-marker/v0.1`, written by `jutaisho` and read by the hook:

```json
{ "contract": "hatsu.stop-marker/v0.1", "at": "<ISO-8601>", "gate": "G5",
  "who": "kurapika", "title": "<one line>", "body": "<one line>",
  "reportUrl": "<url or path>", "sound": "<notifications.sound>", "rungs": ["os", "sound"] }
```

The hook reads **`gate` and `title` only**; every other key is jutaisho's own record (the shape its
SKILL.md § 3 states) and a future `nen stop --mark` may write a subset — `who`, `gate`, `notified`,
`at` — which the hook reads the same way.

Freshness is taken from the **file's mtime**, not from `at`: comparing a timestamp inside a string needs a
date parser, and the mtime is the same fact without one. A marker older than ten minutes belongs to a stop
already seen, and is removed without ringing. Absence of the marker and a stale marker are each a silent exit
`0` — a `Stop` hook runs after **every** turn, and a bell that rings on a turn that was not a gate stop is a
bell nobody hears any more. **Where no hook is installed, `jutaisho` rings the bell itself and says that it
did.**

**Each rung fails open on its own, and the marker is always consumed.** A missing tool disables one rung, not
the hook: a host that is not macOS, or a macOS host without `osascript`, skips rung 2 and still plays rung 3
if `afplay` is there; a host with neither rings nothing and **still removes the marker**, because a marker
left behind would ring that same stop on a later turn, on a machine that by then can. Nothing in the hook
exits before marker cleanup.

**No declaration and an empty declaration are different facts.** No `workflow.json`, or a `workflow.json` with
no `notifications.rungs` key, rings **both** rungs — the useful default for a repository that has not opted in
to the ladder. **`"rungs": []` is the opposite policy and rings nothing**: it says this repository wants the
bell off, and the hook tracks the key's absence separately from the list's emptiness so that a repository
which switched the bell off stays off.

Both scripts are POSIX `sh` and use **no `jq`, `yq` or Python** — Hatsu's installed path is one binary plus
`git` and `gh` — so they read their JSON with `sed`. Both **fail open** on anything they cannot read; the
deliberate exception is the guard's two closed forms above.

`--no-verify` does not reach either of them: a harness hook is not a git hook.

**`hooks/hooks.json` is the plugin's default hook location and is discovered automatically — so
`.claude-plugin/plugin.json` must NOT also carry a `hooks` key pointing at it.** Verified live against Claude
Code `2.1.263`: a manifest key that resolves to the already-loaded default file is skipped as a duplicate,
logged as an internal error, and marks that plugin's hook load *failed* — visible only under `--debug`, and
**not caught by `claude plugin validate --strict`**, which passes either way. The manifest key exists for
*additional* hook files, and Hatsu ships none. `${CLAUDE_PLUGIN_ROOT}` in the two `command` fields resolves to
the installed plugin directory, which changes on every update, so it is never written as a literal path.

### `$CLAUDE_PLUGIN_ROOT` is set inside a skill invocation, and nowhere else

Several skills build an absolute path from the plugin root — `pr-state`, `sharingan`, `backlog-state`,
`futon`, `tensho` and `getsuga` for `nen pr ready --gates`, `ten` for `nen/contract.json`, `hanten`
for a persona's definition under `claude/agents/`, and `en`, `shibari`, `sharingan`, `spiritual-message`,
`backlog-board`, `black-voice` and `templates/pr-body/` for the report clock and the PR-body evidence
check (`"$hatsu_root/scripts/report_time.sh"`, `"$hatsu_root/scripts/pr_body_evidence_check.sh"`). (A
report's *template* is not on this list: it is the target repository's own `templates/<name>.html`,
named by that repository's `nen/workflow.json`.) **The name they
spell it with is `$hatsu_root`, never `$CLAUDE_PLUGIN_ROOT` on its own**, because a skill body is mirrored
verbatim onto Codex and Cursor ([`docs/SURFACES.md`](SURFACES.md)) and `$CLAUDE_PLUGIN_ROOT` is Claude
Code's alone: **the harness exports it while a skill is running, and it is EMPTY in an ordinary tool-call
shell and inside a subagent** — verified live — and on the two other surfaces it is usually unset or, exported
from a shell profile, names a different plugin (`docs/surfaces/evidence/surfaces.md` § 8, F3). `$hatsu_root` is the
resolution [`ten`](../claude/skills/ten/SKILL.md) § 0 runs on every surface,
each candidate accepted only if it is a Hatsu checkout, the winner canonicalised to an absolute path and
held in a shell variable that is not exported. **So a code block that uses `$hatsu_root` sets it in that
block** — `ten` § 0's resolver verbatim (`futon`; `pr-state` and `tensho` read `$HATSU_PLUGIN_ROOT` or the line § 0 printed and re-resolve through the warm-up when neither is in hand, from 0.43.0), or the one-line explicit
input `hatsu_root='<the absolute path § 0 printed>'` (the warm-up's own later blocks, `hanten` § 3, and the
prose fallbacks in `backlog-state` and `getsuga`). **The path is never embedded raw in source text**: § 0
prints a label line, then the root alone on the next line as a single-quoted shell literal with every `'`
written `'\''`, and a consumer pastes that one line verbatim, quotes included and nothing else — into the
explicit-input line or the resolver's single-quoted handed slot —
so `$`, backticks, backslashes and spaces reach the shell as themselves; a root containing a newline is
refused, because the handoff is one line. Nothing is inherited from the warm-up's shell, and the value it
prints is what every later block takes:

| `$hatsu_root` comes from | when |
|---|---|
| **`$HATSU_PLUGIN_ROOT`** | the environment the session was started with — the form that works on all three surfaces, and the one to prefer |
| the path the run was handed | `$ten <path>` on Codex, `/ten <path>` on Cursor (`docs/SURFACES.md` § 1's invocation row), or whoever raised the run |
| **`$CLAUDE_PLUGIN_ROOT`**, when set | Claude Code's own — the installed plugin directory, which changes on every update and is never a literal. Inside a Hatsu skill invocation on Claude Code it passes the identity check on the first comparison |
| **none of the three** | the root is reported unresolved, never guessed — `NOT INSTALLED` in the warm-up, `--reviewers` by hand in `sharingan` § 4. The prelude reads three candidates and no fourth. On Claude Code alone, a caller can obtain the path it hands in (row 2) from the surface's own registry: `claude plugin list --json` → the entry whose `id` is `hatsu@hatsu`, field **`installPath`** (verified live: the `--json` flag exists and `installPath` is the plugin root); neither other surface has one |

**Never substitute a bare relative path.** `--gates` in particular resolves a relative path against
`--repo`'s root since nen `v0.2.0`, never the cwd, so `contracts/reference.gates.json` looks for a file
inside the repository under judgement and `ENOENT`s — and a `--gates` that cannot be resolved is answered by
passing `--reviewers` instead (`sharingan` § 4), not by guessing a path. This is wave-3 finding F18.

---

## 7 · What is not here yet

**Every residue this section used to list was retired when the pin moved to nen `0.5.0`.** Build proof and
the stall guard (`rasengan`), `--target` on `shu dev` with `lane`/`artifact` (`amaterasu`, `jujutsu`), both
report verbs (`spiritual-message`), `--no-push` and `conflicts[]` on `pr cascade-main` (`ao`, `murasaki`),
`wc squash` (`aka`), `shu test-report` (`tsukuyomi`), `shu evidence` (`kotoamatsukami`, `shibari`),
`shu coverage --touched` with the ladder (`byakugan`), `pr edit-body` (`shibari`), the forbidden-trailer refusal
in `commit format` (`kokusen`), `nen/workflow.json` validation and `notifications.turn` (`breath`,
`jutaisho`), `stop --mark`, `surface mirror generate|check`, step `stdoutTo`, precondition `port` and
`repo resolve`'s exit-`2` no-registry refusal — all of them are verbs in the pinned binary, each verified
live and recorded in the matching `docs/ab/<skill>.md` under *Retired at nen 0.5*.

**What is still residue, and why:**

| Residue | Where | Why it is still residue |
|---|---|---|
| **RETIRED at nen `0.13`**: the push (`wc publish`), the rebase and the merge (`wc catch-up`), the commit (`commit write`), the PR (`pr open`), the stash-and-restore (`shu warmup --carry`) and both sides of a conflict (`catch-up`'s `conflicted[]`) | `aka`, `murasaki`, `ao`, `kokusen`, `shibari`, `breath` | each is a verb in `0.13`; only a `:1:` base stage is still `git show` |
| the marker's SHAPE — `hatsu.stop-marker/v0.1` | `jutaisho` | `nen stop --mark` writes a poorer document with no `title`, `sound` or `rungs`, and **replaces** the file; adopting it would ring the generic line on every gate. Kept deliberately |
| removing the marker on a hookless surface | `jutaisho` | `--mark` writes and never removes |
| a coverage tool's own exclusions | `byakugan` | `--touched` narrows the rows nen parsed; it cannot know what was never instrumented |
| embedding a capture as a `data:` URI | `spiritual-message` | no verb turns a PNG into one |
| the Artifact publish | `spiritual-message` | the surface's tool, not a deterministic step nen owns |
| a `.xcresult` with no declared extraction step, and a Playwright HTML report | `tsukuyomi`, `kotoamatsukami` | `test-report` reads a **declared** summary; nen opens no result bundle itself |
| placing a surface mirror into a target repository, and `info/exclude` | `ten` | `--out` is a path, not a deployment; an exclude file is one working copy's property |
| an artifact's size, freshness and checksum | `susanoo` | nen reports a declared artifact's existence and nothing more |
| the trunk guard hook (`guard-base-branch.sh`) | `hooks/` | a harness hook, not a nen-owned step |

**A residue lapses when the pin moves and a verb arrives for it** — and a missing verb is a finding to
file, never a gap to route around.

Skill availability follows the same honesty: `breath`, `rasengan`, `kokusen`, `amaterasu`, `tsukuyomi`,
`spiritual-message`, `jutaisho`, `ao`, `aka` and `ren` shipped at Hatsu **`v0.4.0`**. **`v0.5.0` adds the PR side of
§ 5** — `mukai`, `murasaki`, `hanten`, `gyo`, `kotoamatsukami`, `shibari`, `en` and `jujutsu`, plus the
`drive` → `sharingan` rename — and the three agent definitions it needs: Feitan, Chrollo and Illumi.
**`v0.24.0` adds `byakugan`** (coverage capture and measurement, independent of kotoamatsukami's tests).
**`v0.6.0` closes the release side**: `susanoo` (archive and packaging), `kagutsuchi` (non-production
upload, per target) and `mugetsu` (publication, per target, **G3**) are skills now, so **four of § 4's
five human-called phases have files** — `aka`, `mukai`, `kagutsuchi`, `mugetsu`. The fifth is **the
merge**, and it stays a rule with no file: **G2** is an action no agent performs, so there is no
procedure to write down. The rule that held while the other four had no file still holds and always did:
**a phase boundary is the governance, not the file** — name the phase and stop there whether or not
something has been written for it.
**`v0.133.0` adds `dowsing-chain`**: a product family's sibling repositories captured into one private, living `github/spec-kit` canon in the family's spec repository — the constitution merged first, one folder per capability in waves at **G2**, every statement cited to code at a sha or marked, one clarify sitting per run, the intake examiners' uncounted challenge; `dispatch` files only what its never-starred picker names (each filing through `file` § 4's confirmation), `wave` builds filed marker-free issues on the typed call, `recapture` appends a convergence diff; resumable from `${XDG_STATE_HOME:-$HOME/.local/state}/hatsu/specs/<run-id>.json` ([`config/spec-repo.md`](config/spec-repo.md); HR-12, HR-16; the nen spec verbs, zheref/nen#493, need a nen past `0.26.0`).
**`v0.126.0` adds `hiraishin`**: one PR merged into its source's base ported to one sibling — the precondition read and its refusals, `kamui` §§ 2–4 (its setup, spec step and **G2** wait) where a spec repository is declared, a port brief with one row per concept, one batched `port-drift` call per run through `bankai-rule`, the port issue filed on the typed call (its G1) and built, an all-drop brief stopping at *nothing to port*; resumable from its own record in `ports.md`'s schema (zheref/hatsu#357, epic #354).
**`v0.125.0` adds `kamui`**: one issue or shipped PR written once as a product family's `github/spec-kit` set (pinned `v1.2.2`, § 2 → `port`) in its spec repository at **G2**, nothing built before that merge, a never-starred sibling picker (row `port-siblings`) whose answer is the G1 for one port issue per pick, and a start picker running the picks as `build` one after another; resumable from `${XDG_STATE_HOME:-$HOME/.local/state}/hatsu/ports/<run-id>.json` ([`config/ports.md`](config/ports.md)) (zheref/hatsu#356, epic #354).
**`v0.116.0` adds `emperor-time`**: the Specialist's product-intake ceremony with its own entry — `direct` on the idea, interview rounds to a decision-complete brief (Hisoka for a Design Direction), adversarial challenge rounds by a raised persona (ROSTER **OPEN-4**, asked once per run until ruled, never the frontier tier), `file` § 3's reconciliation, `nen idea file` on one confirmation, `build` offered and never started. **`v0.108.0` adds `kazaana` and `cleanup`** (ruling 2026-10-13): kazaana is `futon <repo>@model/<line> then getsuga` with
parallel delegates on `direct`'s primary pick, a release proposal never the maintainer's to merge, and the
publish offer; cleanup is Shizuku's sweep, required after a completed session, offered beside an optional
`third-hand` at the wrap-up picker. **`v0.27.0` adds `third-hand`**: a wrap-up harvest after En. **`v0.28.0` states it is a separate
phase that starts once En has completed**, not En step 8. Netero proposes 0–3 folded process
issues; the maintainer picks which to file; the sitting is then over. **It is not the merge.** G2
still has no file. Codex asks through `request_user_input` and raises Netero in-session;
Antigravity uses `ask_question` (`is_multi_select`) and `invoke_subagent` with `Workspace: "inherit"`.

**`v0.7.0` adds no skill and adds two surfaces.** The same thirty-eight skills and eight personas are now
also generated into Codex and Cursor layouts under `surfaces/`, placed into a target repository by the
warm-up, checked for drift by [`scripts/surface_mirror_check.sh`](../scripts/surface_mirror_check.sh), and
documented in [`docs/SURFACES.md`](SURFACES.md). **Two things a surface does not have were named rather than
assumed at `v0.7.0`**: Codex and Cursor had no documented turn-end hook then (both have one now, placed with
their hook file, § 6), and the 2026-09-10 CLI record said Codex had no in-session subagent. **From `v0.28.0` Codex does spawn in-session subagents**; Hanten's isolated
reviewer remains a second `codex exec` because that reviewer must not share the author's tree. **RETIRED at nen `0.5`: the mirror's own generator is in the pinned binary.**
`nen surface mirror generate|check` runs at `v0.5.0` — `scripts/surface_mirror_check.sh` exits `0` with
the counts it prints, `codex ok: 44` and `cursor ok: 55` at `v0.42.0` — so the CI job runs a real check instead of skipping with a notice. The
mirrors stay committed, for the original reason: the warm-up installs what is on disk rather than
regenerating anything in a target repository.


## Consumer adoption — how another repository becomes a Hatsu consumer

**The authority is [`hatsu:tenkai`](../claude/skills/tenkai/SKILL.md), and the engine is
`scripts/tenkai_adopt.sh`.** This section states only what the loop needs to know about it.

Until `v0.39.0` there was no deterministic way to make a repository a working Hatsu consumer at all,
and the gap was not a missing file. `nen scaffold init` ships *the stack's* CI workflow and knows
nothing of the readiness workflow — correctly, because **nen stays agnostic to the process** and the
readiness workflow is a Hatsu artifact. `templates/` held one file. There was a greenfield story and
no path for an existing repository.

```bash
scripts/tenkai_adopt.sh diagnose --repo <path>    # read-only; 0 = current, 1 = work remains
scripts/tenkai_adopt.sh apply    --repo <path>
```

**Three properties the loop can rely on:**

- **It diagnoses before it writes**, on every run including `apply`, and reports every item — the
  satisfied ones included, so a checked item is distinguishable from an unchecked one.
- **It is idempotent.** A repository that adopted three versions ago and never re-ran it is the
  normal case, not the exception. A second run writes nothing and says so.
- **It repairs DRIFT, which is the state that matters.** *Present and quietly wrong* — a workflow
  rendered for another repository's slug, a hook from an older template, a runner label that no
  longer matches what the repository derives — looks installed. `missing` and `drift` are therefore
  always reported as different things.

**Adoption includes executable readiness, not just installed files.** Tenkai's guided pass
(`hatsu:tenkai` § 6c) joins the consumer's iteration checks, selected test suites, toolchain,
machine-readable test results, coverage ladder, visual evidence, CI, launch targets and each
distribution destination. The engine reports the structural joins; `nen schema check`, the
relevant `nen shu <verb> --dry-run`, and a host-supported local run test whether a declared
command actually works. A structurally present artifact is not proof that `nen shu test-report`
can parse it, and a `dev` command is not proof of a production `run`. Tenkai carries prior owner
choices forward and uses the native picker only for decisions that remain open. Its final report
names each unsupported seat and missing external prerequisite, rather than counting either as
configured.

The policy inbox is part of that pass: `nen warmup` checks consumer pins against the **installed,
released** Hatsu version. An unpublished authoring branch is not a consumer pin. An `unpinned`
consumer, a stale pin, or an unswept handbook-question source stays visible until resolved.

**What the engine will not do.** `scripts/tenkai_adopt.sh` writes no `nen/*.json`: an initial
declaration is routed to `nen scaffold init`. The guided pass may edit an existing consumer's
declaration after the owner chooses its behavior, then validates that edit at the consumer's G2
gate (§ 6c). The engine does not copy this repository's `nen/gates.json` into
yours — the reviewer identities in it are Hatsu's, and
[`GATE-CONFIGURATION.md`](GATE-CONFIGURATION.md) is the page for tuning your own. It does not merge,
push, or open a pull request.

**Two-PR ordering.** A repository carrying `scripts/workflow_runner_policy_check.rb` cannot register
a workflow and add it in the same pull request: the guard that judges a pull request is the trusted
copy from the base branch, so a PR adding both is judged by a guard that cannot know the file.
Tenkai **detects which half has landed** and stages the workflow until the registration is in — so a
consumer inherits the ordering as a sequenced plan rather than as a red check to diagnose.

**Runner selection is derived per repository** — maintainer's ruling, 2026-09-19 — from visibility
and registered self-hosted runners, always terminating on a runner that exists. `hatsu:tenkai` § 5b
is the table; `scripts/tenkai_adopt.sh runner-policy` is the single encoding. **Provisioning is
[`jusshin`](../claude/skills/jusshin/SKILL.md)'s**: it registers the pools a consumer declares in
`nen/workflow.json` → `runners`, proves each with a preflight job and only then switches its jobs on —
it never changes what this derivation selects.

**Warm-up verifies adoption; it never performs it.** `ten` § 0a is the split: the `nen`
dependency gate is per-session, adoption is once. An outstanding adoption item is reported and is
never a halt — § 3's halt is for a failed bootstrap and nothing else.

**A CI tier is the step after adoption.** [`kuchiyose`](../claude/skills/kuchiyose/SKILL.md) installs one
tier of the Akatsuki roster (the reviewers today) on an adopted repository: `tenkai_adopt.sh diagnose`
must read clean first, the tier catalogue is read at the provider's pinned tag, the caller, the lanes'
`nen/gates.json` entries and the `ci` block (§ 2) land as one PR at the consumer's gate, and the App,
secret and ruleset steps are printed for the maintainer, never performed ([`docs/using/kuchiyose.md`](using/kuchiyose.md)).


## Focused selection adoption and reviewer identities

[Nen #207](https://github.com/zheref/nen/issues/207) tracks a reusable declared test-selection
mapping. Nen 0.8.0 has no selector passthrough. A static focused lane with real runner identifiers
and separate artifacts is the current supported path; `<product-repo-A>`'s apple-device Python tests do not
cover Swift behavior, and its whole-suite apple row cannot substitute for scoped execution.
Do not proliferate permanent lanes per ad hoc selection or copied consumer scripts. The shared
capability and its consumer adoption remain explicitly pending.

The maintainer named Copilot as the sole automated reviewer for Hatsu and Nen on 2026-09-12.
Their `nen/gates.json` files require Copilot's completed round and explicitly select
`approval_policy: review-round-only` with no separate approving-review requirement. The maintainer's
human merge decision remains a separate gate outside Nen's automated readiness verdict. Local
subagent review is evidence, not a GitHub vote.

For a target with no `nen/gates.json`, the caller supplies both halves of that repository's policy.
At Nen 0.10.0, omitted `--approvers` defaults to the supplied `--reviewers`; omission is not a
vacuous approve row. Pass explicit approver identities when the target declares them, or explicit
`--approvers ""` only when an authoritative target policy says completed review rounds require no
approving vote. A bot's observed `COMMENTED` state does not itself establish that policy.


### Review-round completion — maintainer ruling, 2026-09-12

One completed review round normally suffices; a second is for substantive reassessment, not a
routine fresh-head request. The coordinating agent verifies pushed fixes, appropriate checks,
on-thread dispositions and resolutions, plus review-body/suppressed findings, against live GitHub
state before requesting another round. A delegate's “fixed” report is insufficient. No duplicate
request while one is pending; requests count across resumed sessions; a third requires a human
decision. A current-head readiness refusal is reported honestly rather than triggering review churn.
The authoritative procedure is sharingan § 5; en/build inherit it. This changes review orchestration,
not Nen's deterministic approval rules or the human merge gate.


### Build accountability and issue associations — 2026-09-12

Build's coordinator verifies delegated output against the pushed code and live GitHub state.
Implementation, passing checks, completed review handling and formal readiness are distinct
claims. Every inline and summary finding needs a disposition before a review round is complete;
thread replies/resolutions are verified directly, not inferred from a worker's report.

Every PR author lists every addressed issue in the body, including all issues in a combined PR, and
verifies the Development association of exactly the issues the PR closes, no more and no fewer
(amended by zheref/hatsu#203: Development is GitHub's closing association, so a partial or cited
issue there would be closed on merge). Scope changes trigger reconciliation of that full set.
Dependencies are listed separately. Closing clauses reflect completed issue scope; partial work
must not be silently closed merely to obtain a sidebar link. Shibari owns the procedure and the
GitHub auto-close caveat; build, sharingan and en enforce it at handover through
`scripts/pr_development_link_check.sh` (zheref/hatsu#203).

**The Development guard at readiness, stated once** (zheref/hatsu#203; en § 4–6, sharingan § 3–4 and
shibari § 4 cite this paragraph):

The three cases below are mutually exclusive and total, and **the PR's own base decides first**
(zheref/hatsu#213): (1) is every PR into the default branch, whatever `branch.base` declares; (2) and
(3) split the rest on `branch.base`.

- **(1) the PR's base is the default branch**, whatever `branch.base` declares: closing keywords and
  Development links act on it, so the guard verifies fully and readiness is `nen pr ready` + `nen pr
  body-check` **and** the guard's `0` (`--pr <owner/name#N> --base <branch.base>`). A `--base` naming
  another branch prints an informational note and bypasses nothing. Any other guard line vetoes
  Ready; its channel is the body through `nen pr edit-body`, or a sidebar link surfaced to the
  maintainer. A PR on `branch.base` gets en § 5's merge prompt; one off it, the off-base report.
- **(2) the PR's base is not the default branch and `branch.base` is** (stacked on another delivery
  branch): readiness is `nen pr ready` + `nen pr body-check` alone. The guard's `retarget-pending` line
  is quoted beside them, **neither a pass nor a veto**, and the PR goes to en § 5's off-base report: it
  never gets a prompt.
- **(3) `branch.base` is not the default branch and neither is the PR's base**: the guard prints
  `not-applicable (branch.base 'X' is not the default branch 'Y', and neither is the PR's base 'Z')`
  and exits `1`, because nothing it verifies can act there. Readiness is `nen pr ready` + `nen pr
  body-check`, and a PR on `branch.base` gets en § 5's **merge prompt** with that line quoted in place
  of the guard's `0`: the merge is the maintainer's either way. It is the G2/G4 merge stop, **not a
  G5** (§ 4's G5 class is what only the maintainer can do; a merge they chose to keep is a gate they already hold). A PR off `branch.base` still gets the off-base
  report. Hatsu never reaches this case (its `branch.base` is its default branch); canon states it so
  a consumer's is total.
- **Every `nen pr edit-body` and every retarget read-back is followed by the guard**, its line quoted.
- The reading that keywords and links act only on the default branch is GitHub's documented
  behaviour (*Linking a pull request to an issue*); treating it as never-a-pass-never-a-veto, and
  case (3) as the merge prompt rather than a stop of its own, is the run's G4 interpretation, recorded in [`ROSTER.md`](ROSTER.md) § *Rulings of 2026-09-30 — En never
  merges* and the maintainer's to correct.

---

## Gate derivation

**The protocol `hatsu:sharingan` and `hatsu:shibari` both need, stated once.** Moved here on
2026-09-20 (zheref/hatsu#89) from `sharingan` § 2 and `shibari` § 7(c), which carried duplicate
copies; both now point here. [`ROSTER.md`](ROSTER.md) HR-76 and HR-77 remain the authority
on the ruling itself.

**1 · The repository's ROLE decides the gate, before any path is looked at.** **G4 is a canon
repository**, whose product *is* the process; **everything else on that axis is G2**, a consumer's own
`nen/*.json`, CI workflow and `scripts/` entries included. A consumer repository declaring a policy
surface of its own — its *product's* spec, not its copy of this system's setup — **is unruled**: it is
**G2**, and a repository that looks like a genuine exception is a **G5** for the maintainer
(`nen/decisions.json` row `unruled-policy-surface`). **Do not improvise a path set for it.**

**2 · A canon target derives by path; for a consumer the verb is not run**, because the role already
settled it.

```bash
nen gate derive --policy-paths <policyPaths> --process-paths <processPaths> \
                --files-from <an absolute file, one changed path per line> [--asserted <G2|G4>]
```

- **The path sets are the target repository's own canon**, not a universal set; nen ships none, and a
  binary carrying one repository's sets would derive that repository's gates everywhere it was
  pointed. **They are declared once, per canon repository, in
  [`contracts/pr-composition.json`](../contracts/pr-composition.json) → `gateDerive.<owner/name>`**,
  each passed comma-joined; this section carries no copy (zheref/hatsu#171), and
  `scripts/pr_composition_check.sh` (lane `pr-composition-guard`) fails on one. A canon repository
  with no row there has no declared sets: the run says so and asks (§ 4 *Ask, set up, continue*),
  never improvising one, and the row is written by a Hatsu PR at Hatsu's `G4`.
- **`zheref/hatsu`'s process set carries `contracts/` and `templates/`**, so a diff of the
  declaration, `contracts/pr-body.requirements.json` or the PR-section fragments derives `G4`, as it
  did while this section held the sets — **confirmed by the maintainer's ruling of 2026-10-13**
  ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-13 — the handbook questions, answered through
  the picker*, small ruling 2; zheref/hatsu#171).
- **`zheref/nen` has its own row** (zheref/hatsu#334): its sets, and why each member is in them,
  are the row's and its `$comment`'s, never restated here; the representative changes and the gate
  each derives are `pr-composition-guard`'s cases, decided by `nen gate derive` itself — **the
  maintainer's ruling of 2026-10-20** ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-20 —
  zheref/nen's gate path sets*). Every other canon repository still has no row until one is
  written, and no row stands in for all of them.
- **`--files` is caller data** — the verb fetches nothing — and must carry **both sides of every
  rename**. **The hand-off is a file**: write the source to an absolute temp file and pass
  `--files-from <file>`. On a PR the source is
  `gh api repos/<owner>/<name>/pulls/<n>/files --paginate --jq '.[] | .filename, (.previous_filename // empty)'`;
  locally it is `git diff --name-only --no-renames <base>...<head>`. Both print one path per line
  and `--files` is comma-separated: nen 0.22.0 reads a newline-joined `--files` value as **one**
  path, so a real PR under-derives `G2`. **The source must exit `0` and the file must hold at least
  one path before the verb runs** — nen answers `G2` for an empty set, so a failed fetch or an empty
  set never derives; the run stops and says which. **Never `--range`**: nen 0.22.0 computes it with a
  rename-blind `git diff --name-only`, which drops a rename's old side, and `gh pr diff --name-only`
  lists only a rename's new name too, so moving and rewriting a process file out of its set derived
  `G2` (zheref/hatsu#334). **Until the tree-freshness check exists** ([`PROCESS.md`](PROCESS.md)
  § *Residue and owned dependencies*), a `zheref/nen` path whose top-level part is in neither of its
  row's sets nor its explicit G2 list (LICENSE and .gitignore) **stops and asks** (fail closed)
  rather than deriving `G2`. A wrong file set gives the verb, and `nen changelog fragment-required`
  beside it, a confident wrong answer.
- **The declaration keeps both `nen/` and `schemas/`**: a prefix is taken literally and nen's own
  taxonomy resolution never sees it, so an un-migrated target still edits a real `schemas/*.json` and
  that edit is still policy. **Listing both under-derives nothing; dropping `schemas/` would.**
- **Only the both-empty invocation is refused** (exit 1); one empty set and one that matches nothing
  is accepted and answers `G2`.
- **The verb reports; it does not gate**, and **a derived gate stands over an asserted one** —
  `--asserted` prints the mismatch itself, and the run says it in one line, drives to the derived
  gate, and carries the correction into its stop.

**The same matched-path fact selects `across`.** For a process repository, carry the fresh
`nen gate derive` policy/process hit into the section resolver as `--policy-hit`; a repository's
role alone does not activate it. The ordered cell must also contain `across`. Reuse the declared
sets above, never copy them into the section catalogue or prose.

**3 · It is the diff's half of the derivation only.** A pull request that is not ready **has no
gate** — it is in progress and owned by its author — so a body names the gate the PR **will** stand at
when it is ready, **as a forecast and never as a status**. The verb also does not know the base
branch: read it with `gh pr view <n> --repo <owner/name> --json baseRefName -q .baseRefName`, report a
base that could not be determined as `unresolved` rather than assuming `main`, and treat a sub-PR
based on an `integration/*` branch as no maintainer gate row at all.

**4 · Deriving is not labelling.** Applying a gate label is a claim about readiness, and readiness is
`nen pr ready`'s verdict inside [`hatsu:en`](../claude/skills/en/SKILL.md), after the composing run
has ended.

---

## The UZF-26 evidence shape

The catalogue's `evidence` section is product-only and conditional on declared `project.evidence.globs`;
[PR-SECTIONS.md](PR-SECTIONS.md) selects it. Glyph-prefixed Evidence headings keep this exact shape.
When absent, state the no-evidence fact in the checklist rather than creating an undeclared heading.

Moved here on 2026-09-20 (zheref/hatsu#89) from `shibari` § 5, which owned it alone;
[`spiritual-message`](../claude/skills/spiritual-message/SKILL.md) § 3 fills its own `evidence[]` from the same rows.

- **The recorded test images are the screenshots** — never separately-staged captures, so the evidence
  cannot drift from what the tests assert.
- **One table per top-level user-facing screen**, titled with the issue(s) that composed it, with the
  **changed states as columns** — typical / empty / loading / failure / not-editable / overflow — and
  one row of cells per screen. Horizontal, never a tall stack of images.
- **One entry per state the branch actually adds or re-records**, mirroring that set 1:1, never an
  inventory of the screen's total states. **A logic-only change is exempt, and the body says so.**
- **Two mechanisms, and a stack uses exactly one**, named by `nen/contract.json` →
  `project.evidence.mechanism`: **`public-mirror`** embeds the image, hosted by the stack's own
  registered public-assets mirror; **absent, or any other value**, names **each scene** and points the
  reviewer at its **committed snapshot path** in the PR's *Files changed* tab. **A Files-changed body
  that names its scenes is conformant, not a shortfall, and the two are never mixed in one body.**
- **On `public-mirror` the images reach a public host through the target repository's own declared
  publish step**, authorized by the same human call that asked for the PR and **said in the handover
  line**. Nothing that call did not cover is assumed — not an unregistered mirror, not a host the
  stack does not name, not a scene that is not one of the branch's own re-recorded artifacts.
- **Canon admits exactly two incompletenesses, and both are *tracked*** — a timed deferral where there
  is no snapshot-capable runner yet, and a demonstrated capture-tooling gap for a named scene. **An
  untracked gap is the arbitrary waiver canon refuses**, and the answer to "I can't record baselines"
  is a snapshot-capable runner, never a missing table. Where the IOU or the skip does not exist yet,
  say so; filing it is [`hatsu:file`](../claude/skills/file/SKILL.md)'s.
- **`project.evidence.globs` absent is the no-evidence case**, stated in the body; `.scene` defaults to
  `{suite}-{scene}`. `nen shu evidence --repo <path> --base <ref>` reads the block, but the rows come
  from `mukai` step 7's evidence pass and are **re-used rather than re-derived** — two derivations of
  one set is how a report and a PR body come to disagree.

**The table, exactly** (maintainer's request, 2026-09-22: screenshots were landing one per line). Every
screenshot a PR body carries sits in a **cell** of this shape, on the first write and on every update:

```markdown
### Settings — HA#12
| | Typical | Empty | Failure |
|---|---|---|---|
| **iPhone · light** | <img src="…" width="180" alt="Typical, iPhone, light"> | <img src="…" width="180" alt="Empty, iPhone, light"> | — |
| **iPhone · dark** | <img src="…" width="180" alt="Typical, iPhone, dark"> | <img src="…" width="180" alt="Empty, iPhone, dark"> | <img src="…" width="180" alt="Failure, iPhone, dark"> |
```

- **Columns are the states, named in words** (typical, empty, loading, failure, not-editable,
  overflow, in that order), only the ones the branch adds or re-records.
- **Rows are the variants, labelled in bold in the first column** (device, theme, locale, text size).
  A re-recorded state pairs a **`before`** and an **`after`** row for the same variant.
- **Every cell is one image at one fixed width** — `180` for a phone, `320` for a wide screen — so a row
  lines up, with alt text naming *state, variant*. A state that does not apply to a variant is `—`.
- **More than four state columns split** into a second table headed *(continued)* under the same screen
  heading, never a table wider than a laptop screen.
- **The Files-changed mechanism uses the same table**, each cell the scene name and its committed
  snapshot path in code, instead of an image.
- **An update after a review re-renders the whole *Evidence* section** from the current rows: a
  re-recorded shot replaces its cell, a new state becomes a column, and one line under the table names
  what changed and the review it answers. **Images are never appended below the table.**
- **Checked before every body write** — `"$hatsu_root/scripts/pr_body_evidence_check.sh" --body <file>` (plugin
  root, lane `pr-body-guard`) refuses any image outside a table and any image without alt text, each
  by line number. A refusal is fixed in the body file and re-checked; it never reaches the PR.

## Where worktrees live — ruling of 2026-09-30

### Select the effort checkout before any mutation

**This is the shared worktree-selection policy for every surface and phase.** All authoring,
feature work, parity implementation and PR delivery runs in an independent git worktree by
default, for the lead and for each delegated authoring effort. It applies to a new effort, a
resumed effort and every later turn or delivery phase; a branch name or a session's cwd alone
does not establish isolation. Read-only observers may share a checkout; Hanten's reviewers retain
their separate-checkout protocol, save one exception: on an **observed** refusal of the reviewer's
`git worktree add` by the harness's isolation guard — never pre-empted — the reviewer reads the
effort checkout read-only and discloses it ([`hanten`](../claude/skills/hanten/SKILL.md) § 4;
§ *Writing a skill block*, row (a), #218; ROSTER § *Rulings of 2026-10-13*, the #218 (ii) row).

**The sole core-authoring waiver is the maintainer's explicit instruction in the ORIGINAL effort
prompt to work in core.** Quote that instruction with the bound path in the effort report. A
later convenience suggestion, a parent agent's instruction, an existing core feature branch,
missing tools or an unavailable worktree API is no waiver. The waiver covers that effort only,
expires when it ends, and grants no additional gate, launch or permission authority.

**Valid original-prompt waiver → bind the named core checkout for that effort only**, record the
quoted instruction, then run the ordinary scoped Breath/Rasengan/Kokusen protocol there. Do not
adopt unrelated dirty files; show their ownership/disposition when the effort depends on them.
The default worktree-provisioning steps below apply when no valid waiver is held.

Before Ten's catch-up, Breath's standalone preservation or any authoring/PR mutation:

1. Read `nen wc worktrees --repo <starting absolute path> --json`; resolve `core`, the registered
   checkouts and the branch/base. Preserve the core checkout's current branch, index and human
   changes. Do not stash, carry, switch, fast-forward, stage or clean core to prepare isolation.
2. Reuse a registered **effort-owned** worktree when the request explicitly continues that effort,
   or the session's recorded binding identifies it. Re-verify its absolute path, branch and
   ownership on every entry. An unrelated worktree is not adopted because its branch looks useful;
   Breath's overlap read still applies. A continuation found in core without the original waiver
   provisions a separate worktree at the effort's committed ref; any uncommitted core work stays
   there. Report the unavailable paths; ask for ownership/disposition only when migration depends
   on them, while independent new work continues in isolation.
3. Otherwise provision a worktree through the surface adapter in `docs/surfaces/<surface>.md`
   (§ *Authoring checkout adapter*, Antigravity § 11.1), using the locations below. For Hatsu's
   manual fallback, `git worktree add --detach <absolute effort path> <resolved base-ref>` creates
   the checkout before Breath fetches and cuts the new effort branch there. For a resumed branch,
   use its committed ref. If its branch is held in core, report the branch-binding blocker and
   preserve both checkouts; do not run new-effort warmup over resumed commits or silently change
   an existing PR's head branch. Independent new work can still proceed in its own checkout.
   Name the choices: the maintainer releases the held branch explicitly, or chooses a new
   independent effort; neither choice is performed by an agent as automatic cleanup.
   Never force-release another checkout's branch.
4. Bind that **absolute effort path** in the handoff and report, then use it for every command cwd,
   `nen --repo`, script argument, edit, check, parity generation, staging, commit and PR phase.
   A delegate receives its own path and the original waiver status, never an ambiguous `.` or a
   request to invent isolation. Native creation returning a path does not change the current
   session's cwd: use the returned checkout explicitly. Before running warmup, inspect its dry run;
   if it would move core's checked-out trunk or work, report the blocker and do not run it.

**Plugin-source refresh is included, before Ten's target placement.** Bind the effort target before
any refresh that could move core. Dependency installation and host setup remain separate. Ordinary
authoring never fast-forwards or otherwise refreshes core or a shared plugin checkout: use a
verified effort-owned isolated Hatsu source when available, or report `refresh skipped: protected
core/shared source` and continue reading the loaded source. A target-authoring waiver is not a
source-refresh grant. The source must be a validated Hatsu checkout, not a consumer with copied
skills. Rebind the eligible source's absolute root for refresh/placement; preserve the bound target.
Authoring uses the plain updater without `--claude`/`--codex`, since those flags can update shared
links/marketplaces independently of `--root`. Quote its own skip on an authoring branch; do not
switch that branch to make it refreshable. Read-only/no-phase entry inspects without worktree
provisioning; it skips protected core/shared refresh and all project-local placement (`--install-all`,
permission-pack installation). Report those skips instead of describing a mutation as a read.
Dedicated plugin update or target setup requires its own explicit invocation; Ten does not infer it.

An unavailable creation tool or a harness write/trust refusal is reported with the path and exact
failed operation; use an already-authorized adapter alternative when available. **Never change
permissions, silently fall back to core, or widen authorization to finish.**
On Codex, follow [the adapter's authorized write recovery](surfaces/codex.md#authorized-worktree-write-recovery)
before ledgers or authoring: an unreviewed sandbox error is not a rejected approval. Existing task
authority may use an exposed host review route for the bound checkout; actual rejection retains
its reason and stops that action. This does not change persistent permissions or any human gate.
`amenotejikara` / `nen wc swap` moves a committed tree into core and **cannot create isolation**.
Core launch and swap remain explicit maintainer calls; authoring and delivery keep their effort
path after either call. An isolated Ren turn reports the launch command and defers automatic core
launch without asking for approval (Amaterasu § 3).

Core parked on the trunk is the intended clean starting state, **never permission to put it
there**. An unrelated dirty core does not block an independent worktree effort. Creation may
register the worktree in shared Git metadata; it may not move core's checkout, index or files.

**The maintainer's request, verbatim** (2026-09-30): *"Noticed under some circumstances and for more
than one surface, since worktrees are encouraged by default, worktrees are being created and worked one
used inconsistent practices for each. ... I saw worktrees being generated as sibling folders of the
core checkout directory. I don't like this approach and as possible we should generate a git-ignored
folder (maybe for each surface) where surfaces can install the worktrees and safely work within a
contaned environment without creating bad hygiene outside the actual workspaces. ... it would be great
to make it canon and clear on all surfaces."* **The ruling**: *"go with .nen/worktrees/<surface> as
canon"*.

**Every worktree Hatsu creates lives at `<core>/.nen/worktrees/<surface>/<name>`.** `<core>` is the
core checkout — `nen wc worktrees --json`'s `core`, the parent of `git rev-parse --git-common-dir`;
`<surface>` is the slug `ten` § 5 passes as `surface=`: `claude-code`, `codex`, `cursor`, `antigravity`.
**Never a sibling of the checkout (`../<name>`), never `/tmp`, never anywhere outside the core
checkout.** `.nen/` is already ignored — Hatsu's own `.gitignore`, and in a consumer tenkai's
`dirs/nen-state` row — so the directory needs no new ignore rule. The names in use: `hanten-<persona>`
([`hanten`](../claude/skills/hanten/SKILL.md) § 4's reviewer), `prove-<n>` (the stash-and-restore
shape's proof, below), the effort's branch slug for a lead-session effort (rule 6 of
[`claude/rules/hatsu.md`](../claude/rules/hatsu.md)), and kagutsuchi's fixed `.nen/worktrees/kagutsuchi`
(§ 3b, `scripts/kagutsuchi_worktree.sh`) — the one purpose-named path with no surface segment, kept
because the script's idempotence is built on the path being fixed.

### Per surface — the harness's own worktrees, and what Hatsu does

| Surface | The harness's own worktrees (quoted, fetched 2026-09-30) | What Hatsu does |
|---|---|---|
| **Claude Code** | "By default, the worktree is created under `.claude/worktrees/<name>/` at your repository root, on a new branch named `worktree-<name>`" ([worktrees](https://code.claude.com/docs/en/worktrees)). A `WorktreeCreate` hook may relocate it, but a hook-created directory inside a git repository is refused — the page says to "have the hook create its directories outside any repository"; the `worktree.*` settings (`baseRef`, `bgIsolation`, `sparsePaths`, `symlinkDirectories`; [settings reference](https://code.claude.com/docs/en/settings-reference)) set no location | **Hatsu-made**: `git worktree add .nen/worktrees/claude-code/<name>`, then `EnterWorktree` by `path` — a path outside `.claude/worktrees/` asks the maintainer's approval once; it is answered, not routed around. **The harness's own isolation** — `claude --worktree`, the Agent tool's `isolation: "worktree"`, a background session — stays at `.claude/worktrees/`: **the one documented exception**, git-ignored (Hatsu's `.gitignore`; tenkai's `dirs/claude-worktrees` row in a consumer), never relocated |
| **Codex** | "Codex creates worktrees in `$CODEX_HOME/worktrees`." / "To choose another location, open **Settings > Worktrees** and change **Worktree root**." ([git worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees)) — one global root, not per repository | The app's own worktree is accepted where it is: outside the workspace but contained in the tool's home, never a sibling. **Hatsu-made** (hanten's second `codex exec`, a lead-session effort): `.nen/worktrees/codex/<name>` |
| **Cursor** | native worktrees live in a machine worktree root — "Cursor 3.5 keeps a modified time checkpoint for the machine worktree root" ([worktrees](https://cursor.com/docs/configuration/worktrees)); the location is not documented as configurable, and `.cursor/worktrees.json` configures setup, not location | The native worktree is accepted where it is. **Hatsu-made** (hanten's `.cursor/agents/` reviewer, a lead-session effort): `.nen/worktrees/cursor/<name>` |
| **Antigravity** | "New worktree mode: The agent operates in an isolated Git worktree." ([getting started](https://antigravity.google/docs/getting-started)); the location is undocumented | `invoke_subagent` with `Workspace: "branch"` is accepted where the IDE puts it. **Hatsu-made** (the lead's direct work, [`docs/surfaces/antigravity.md`](surfaces/antigravity.md) § 11.1): `git worktree add .nen/worktrees/antigravity/<name> -b <branch>` |

### Integrity

- **A nested worktree survives `git clean -fdx`** (verified locally, 2026-09-30): a linked worktree at
  an ignored `.nen/worktrees/claude-code/wt1` — the verified probe — holding an uncommitted file
  stayed — git prints *Skipping repository .nen/worktrees/claude-code/wt1* — because `clean` does not
  enter a nested repository on one `-f`. **`git clean -ffdx` removes `.nen/` wholesale**, every worktree's uncommitted work with it. So
  **`git clean -ff…` is never run in a core checkout that holds worktrees**; the sweep is `git worktree
  remove <path>` per worktree, then `git worktree prune`.
- **Containment is both ways.** Deleting the core checkout deletes its worktrees, and a worktree's
  `.git` file points only into core's `.git/worktrees/<name>`: nothing outside the checkout references
  it, and nothing of it is left behind.
- **Remove on landing.** A worktree is removed when its effort lands or is abandoned — `git worktree
  remove <path>` (`--force` only on a tree the report has shown dirty and the maintainer has released),
  then `git worktree prune`. hanten § 4 removes the reviewer's when the review returns; the proof below
  removes its own on every path.

### Performance

- Tools that honour `.gitignore` — git, `rg`, most language servers — never see `.nen/worktrees/`.
  Tools that do not — an IDE indexer, a jest or Metro watcher, a `tsc` `include` glob, a bare `find` —
  may scan every nested copy; the dot-prefixed `.nen/` is skipped by most of them by default, and
  where one still bites, that tool's own exclude names `.nen/` once.
- **Codex copies ignored paths.** `codex plugin add` copies the whole marketplace checkout, ignored
  worktrees included ([`docs/surfaces/codex.md`](surfaces/codex.md) § 1), so a stale worktree in the
  Hatsu checkout costs Codex install time and cache space on every `add`: on Hatsu's own checkout the
  remove-on-landing rule has no exception.

**What this does not rule.** The native modes' own locations (Codex's *Worktree root*, Cursor's machine
root, Antigravity's root) are the tool's and are not reconfigured by Hatsu; and nen carries no verb that
creates or removes a worktree at the canonical path — `nen wc worktrees` reads, `nen wc swap` swaps —
so every `git worktree add` above is hand-spelt residue ([`docs/PROCESS.md`](PROCESS.md) § *Residue*;
[zheref/nen#299](https://github.com/zheref/nen/issues/299) is the kagutsuchi-shaped verb).

## The standalone stash-and-restore shape

Moved here 2026-09-20 out of [`breath`](../claude/skills/breath/SKILL.md) § 0, which is its only
caller today; a second skill that ever has to preserve a maintainer's uncommitted tree across a trunk
move reads it here rather than restating it.

**The guaranteed outcome** (ruling 2026-09-18): *a branch off a `main` proven green, carrying the
maintainer's own commits on that tip, with their uncommitted changes still uncommitted.*

- **Preserve.** `nen shu warmup --carry` (nen `0.13`) stashes the tree, untracked paths included,
  addressed **by SHA, never by `stash@{0}`**, warms, and restores by `stash apply <sha>` with a
  checked drop; a conflicting restore leaves the stash in place and stops as `nen/decisions.json`
  row `semantic-conflict`. **Never `--discard`, `git checkout -- .` or `reset --hard`.**
- **Prove.** An isolated `git worktree add --detach <core>/.nen/worktrees/<surface>/prove-<n>
  origin/<base>` (§ *Where worktrees live*; never `/tmp`, never a sibling) is preferred and removed on
  every path; fall back to the maintainer's working directory only where a lane cannot run outside
  it, **saying which**. A red base is a **G5**; a seat (exit `4`) is not red.
- **Place.** Unpublished commits are replayed onto the proven tip through
  [`ao`](../claude/skills/ao/SKILL.md), keeping the branch name; **published commits are merged
  instead, not negotiable**; a detached `HEAD` is classified, its commits reported and their landing
  asked. **Name the operation** in the report. Conflict discipline is ao's, and **a semantic conflict
  is a G5 with both sides shown** (`nen/decisions.json` row `semantic-conflict`).
- **Restore.** **Every stop restores the stash first and prints its SHA**, the red base and the
  semantic conflict alike. **On a restore failure the stash is NOT dropped**: the report carries its
  SHA and the exact recovery command. The run is finished when the changes are back **and still
  uncommitted**.
- **Report.** The starting state; the stash SHA and carried-path count, or *clean*; the base SHA with
  each check's result; worktree or in place; which placement ran; conflicts classified; the restore.
  **The claim that must be earned is *the base was green***, said only for checks that ran to
  completion on that tip; a check that could not run leaves the base **UNPROVEN**, and the run stops.
  **A red taken after the restore is the effort's own, not the base's.**
- **Confirm through the surface's own picker only when the run will rewrite a commit the maintainer
  wrote**, counts included.

## The local verification gate

Moved here 2026-09-20 out of [`kokusen`](../claude/skills/kokusen/SKILL.md) § 3, which is the phase
that holds the index and so the only caller; the gate is stated once, and the skill carries its own
refusals. It is run **on the tree in front of you, now** — never remembered from the author's inner
loop, never inherited from the warm-up, never skipped because the last run was green.

1. **Every declared `iteration.checks` entry, in order, for `iteration.lane`** —
   `nen shu <check> --repo <path> --lane <iteration.lane>`, one call per entry. **`<check>` is
   whatever the file lists and nothing else**, never a `build` added because a gate ought to have one;
   where the entry is `lint` the check is [`gyo`](../claude/skills/gyo/SKILL.md). The exit table is
   [`rasengan`](../claude/skills/rasengan/SKILL.md) § 6's, differing in one place: **here a `1` ends
   the commit** — quote the failing check verbatim, commit nothing, hand the turn back to `rasengan`
   and re-run the gate. **A red check is never a G5** (`nen/decisions.json` row `red-lint`): it
   returns to rasengan as often as the turn honestly needs, and a red still standing at the end of the
   turn is the next turn's first job, **never a commit "so the fix is saved" and never a narrowed
   check**. **A seat (exit `4`) is not red**: quote the declaration's reason and move on.
2. **A consumer's canon mirror, where the delta touches `.claude/canon-values.yml`**
   (zheref/hatsu#111). Regenerate `.claude/rules/` with `nen/workflow.json` →
   `iteration.canonMirror.command` — an argv array, Hatsu's own key, preserved by `nen schema check`
   (the README or `iteration.$comment` only while zheref/nen#262 is open and the key is absent, which
   `tenkai` names as the routed gap) — run locally, never the weekly cron and never a `workflow_dispatch`
   that can carry the branch into a PR against trunk — and read
   `git status --porcelain .claude/rules` after it. **A non-zero exit from the command is red** (row
   `red-lint`). **A non-empty read is the stale mirror caught, not red**: this gate runs before
   anything is staged, so the regenerated files are what `kokusen` § 4's triage now stages — **they
   ride this commit, or nothing does**; red is a commit that carries `.claude/canon-values.yml`
   without them, and a read still non-empty after a second run of the command (a generator that is not
   idempotent — a finding, reported). Then the correctness
   read drift cannot give: `grep -rn '<the superseded value>' .claude/rules/` — a hit is a finding
   (a placeholder column the generator left hardcoded), reported, never passed. The deterministic half —
   a `nen schema check` row over the bindings — is zheref/nen#262, an owned dependency; until it lands
   the two reads above are the gate. A consumer with no `.claude/canon-values.yml` reports `canon
   mirror: not applicable`.
3. **The focused tests for changed executable behaviour, through
   [`tsukuyomi`](../claude/skills/tsukuyomi/SKILL.md)** — mandatory even where the author already ran
   them for feedback. Map every changed behaviour to its declared scoped lane and run **every
   applicable lane, once each** (`nen shu test --repo <path> --lane <explicit-scoped-lane>`),
   recording the mapping and each result; one lane suffices only where its declared argv covers all
   changed behaviour. `--lane` is Nen's supported routing mechanism — **there is no `--scope` flag and
   no separate checkpoint checks key** — and scope is never inferred from a lane name. A red focused
   run returns to rasengan and the gate repeats. **Where behaviour changed and no unambiguous scoped
   lane exists, hand the tree back to rasengan to author the tests and register the lane** (row
   `missing-focused-route`) — never a stop, never an undeclared runner, never the full suite as a
   substitute. Prose-only, data-only or other non-executable changes report `focused tests: not
   applicable — <reason>`.
4. **Read the build proof back — ONLY where step 1 ran a green `build` on this lane**, that condition
   read off the policy file **before** running `nen commit check --repo <path> --require-proof
   <iteration.lane>`. `.nen/proof/<lane>.json` is written by `nen shu build` and nothing else, so
   **skip the step** where `build` is not in `iteration.checks` (step 1's own green run is the gate)
   or where the lane **seats** `build` (quote the seat); a red build never reaches it. Running it
   unconditionally is a loop — the lane passes its declared check, writes no proof because nothing
   asked for one, answers `1`, and is sent back to step 1 forever. The check compares the proof's
   `treeHash` against **this working copy's**, so exit `0` is *this tree is the proved one*; exit `1`,
   reached only where the condition held, reads as **the tree has moved since step 1's build** and is
   never reported as a red build; exit `2` (a missing flag, a lane escaping the tree, an unreadable
   proof) **stops** and is never folded into "absent". It blocks nothing, so the refusal is the
   skill's. **Never report a missing proof on a seated lane as a red build.**
5. **This is not the trunk.** `nen wc classify --repo <path> --base <branch.base>` reporting
   `must-move` means the work belongs on a branch first — [`breath`](../claude/skills/breath/SKILL.md)'s
   job. The commit phase commits on a branch or it does not commit.

## Writing a skill block — one plain command or a shipped script (ruling of 2026-10-13)

**Stated here once** (zheref/hatsu#218 (iii), the maintainer's ruling of 2026-10-13 — ROSTER § *Rulings
of 2026-10-13*); [`PROCESS.md`](PROCESS.md) § *Residue and owned dependencies* and
`claude/rules/hatsu.md` cite it. A skill's shell block is written for the most restrictive surface it
runs on: in a worktree-isolated Claude Code session the harness refuses compound shell, so **every block
is one plain command per call, or a shipped `scripts/` entry**, each exit read before the next call.

**The guard, and what it refuses.** In a Claude Code
session isolated with `EnterWorktree`, the harness's guard refuses compound shell (a pipe, `$(…)`, a
loop, `export VAR=$(…)`, a `;`, `&&` or `||` chain, `cd … &&`) with sentences such as *"names git in a
form too complex to verify … Split it into plain, separate commands"*, and its write guard refuses a
path under `<core>` outside the session's own worktree, `<core>/.nen/worktrees/` included. The guard
is Claude Code's, not Hatsu's (an upstream report is the maintainer's); the record, refusal text
verbatim, is [`docs/ab/worktree-isolation.md`](ab/worktree-isolation.md). The Hatsu side, and
only as far as it is true: **the blocks the table below names** are plain single commands or a
shipped `scripts/` entry, each exit read before the next call, and `$hatsu_root` in any block is ten
§ 0's printed path, typed in its place (`ten` § 0). The blocks still carrying a refused shape are
listed under *Not yet converted*, below the table. **A refusal of any block on neither list is a
refusal, named** (§ 4 *What is not a gap*, item 1: a permission the harness withholds), the block and
the guard's sentence quoted; **a throwaway helper script is never the
workaround**: it puts unreviewed shell on the run's own authority, and where it re-creates a verb it
is determinism drift.

**A write gated by a check stays chained to it with `&&`**: `branch_authorship_check.sh … && nen wc
squash|publish` in `aka` §§ 4, 7 (zheref/hatsu#170; the publish half held by `scripts/publish_gate_check.sh`,
#188, the squash half by the prose) and `private_name_check.sh … && nen issue comment` (`mugetsu` § 7,
`sharingan` § 7; `file` § 4 runs the guard before the plan as separate calls and lets nen's own refusal
at write time gate the comment). Split,
the gate would rest on an agent reading an exit, the failure #188 was filed after. Never pipe
`branch_authorship_check.sh`: a pipeline can return a downstream command's success after the guard
fails. Its own exit is the gate. Whether the guard
accepts a bare `a && b` is not on record (shape 8's refused chains also carried `cd` and `;`); where
it refuses one, the write is a named stop. **#188's own required chain is not bare**: `murasaki` § 6's
gated push carried `$(mktemp -d)` and `$(git rev-parse …)`, shapes on record as refused. **Ruled
2026-10-13** (ROSTER § *Rulings of 2026-10-13*, zheref/hatsu#218 (i)): the chain ships as
`scripts/publish_gate.sh`, every link in its stated order, the skill block one plain call; lane
`publish-gate-guard` proves each gate refuses the push.

**`GH_TOKEN` and `PATH`, set without a refused shape.** `nen` reads its token from `GH_TOKEN` only and
never picks one up ambiently; a block hands it one as `"$hatsu_root/scripts/gh_token_env.sh" nen …`,
the token `gh auth token` prints, in that one command's environment, never printed (lane
`gh-token-guard`). A session-bound `nen` (ten § 2's `<d>/bin`) reaches a call through the wrapper's
`--path <d>/bin`, the form on record; a `PATH=<d>/bin:$PATH` prefix on a plain call is **unproven**
against the guard (the record's session saw no Bash refusal at all). The host link (`~/.local/bin`,
ten § 2) needs neither once the login profile carries it.

| # | Refused shape | Owning block | Replacement |
|---|---|---|---|
| 1 | `d="$(mktemp -d)"; curl …; out="$(bash <file> --ref <pin>)"` | `ten` § 2, the session bind; `mugetsu` § 7, the host re-pin after a publish of nen itself | one call per line: `mktemp -d`; `curl -fsSL <url> -o <d>/nen-bootstrap.sh`; `bash <d>/nen-bootstrap.sh --ref <pin>` (or `nen bootstrap … --script <d>/nen-bootstrap.sh`); `test -x <verified>`; `mkdir -p <d>/bin`; `ln -sfn <verified> <d>/bin/nen`, each exit read before the next; `<verified>` only from a bootstrap that exited `0` |
| 2 | `nen commit format … --body "$(cat <file>)" > <msg>` | [`WORKFLOW.md`](WORKFLOW.md) § *Writing a commit* (`aka` § 4, `kokusen` § 5, `ao`, `tensho` § 4) | the literal `--body "<paragraphs>"`, one quoted argument; a body-file flag is nen's to add |
| 3 | `export GH_TOKEN=$(gh auth token); nen …` | `en` § 6; `getsuga` §§ 2, 3a; `mugetsu` § 4; `pr-state` § 2; `sharingan` § 4; `file` § 3; `classify` § 2; `direct` § 2; `senkei` §§ 2, 4; `backlog-state` § 5; `backlog-synthesis` § 2; `tensho` §§ 5, 6; `ten` § 6 step 4; [`PROCESS.md`](PROCESS.md) § *Reviewer rounds and review threads*, *Requesting a round* | `"$hatsu_root/scripts/gh_token_env.sh" nen …` |
| 4 | `for p in …; do git worktree add --detach …; done` | `hanten` § 4 | one `git -C <repo> worktree add --detach <core>/.nen/worktrees/<surface>/hanten-<persona> HEAD` per persona |
| 5 | `for l in …; do s=$(date +%s); nen shu test --lane $l …; done` | `kotoamatsukami` § 7 | one `nen shu test --repo <path> --lane <lane>` per selected row; a duration is `--json`'s `durationMs` |
| 6 | `git show origin/main:<f> \| grep …`; `git show <ref>:<f> > a; git diff --no-index a b` | improvised `ao`/`getsuga` reads; `getsuga` § 1's `git rev-parse … \|\| <refuse>` | `git -C <path> show <ref>:<f>`, read whole; `git -C <path> diff <ref-a> <ref-b> -- <f>`; `git rev-parse --verify -q '<token>^{commit}'` alone, its exit read |
| 7 | `for n in …; do gh pr view $n -q …; done` | an improvised PR sweep | one `gh pr list --repo <owner/name> --state all --json <fields> --jq <filter>`, or `nen report data --prs <n,…>` |
| 8 | `cd <dir> && git init … && git worktree add …`; `CHG=… sh <script>; nen wc publish …; nen pr edit-body …` | an improvised git probe and chain; `aka` § 4's `cat-file … \|\| fetch` and `$(git merge-base …)` | `git -C <dir> …`, one command per call, each exit read before the next; a SHA is read, then typed; a gated write keeps its `&&` (above) |
| a | any command inside `<core>/.nen/worktrees/claude-code/hanten-<persona>` | `hanten` § 4 | on an **observed** refusal of that `git worktree add` (never pre-empted): no reviewer worktree; the reviewer reads the effort checkout (ratified 2026-10-13 as an exception to the worktree ruling of 2026-09-30, beside the harness-native ones that ruling names — ROSTER § *Rulings of 2026-10-13*, zheref/hatsu#218 (ii)) read-only at the printed HEAD, disclosed; the author's tree is held by § 4's ref and authorship checks and an unchanged `git -C <path> status --porcelain` ([`WORKFLOW.md`](WORKFLOW.md) § *Where worktrees live*) |
| b | `nen watch until --command "<string>"` | `en` § 6 | `gh_token_env.sh nen watch until --pr <ref> --until ready` (zheref/nen#264). A `--command` observation no `--pr` predicate expresses (`izanami`, Illumi) keeps its form; refused, the one workaround is the same line in the maintainer's own terminal, reported as handed over |
| c | `"${SHELL}" -lic '…'`, the login-shell probe | `ten` § 2c | `"$hatsu_root/scripts/nen_reach_probe.sh" --root "$hatsu_root"` (lane `reach-probe-guard`) |
| d | `rm -rf <scratch>` | an improvised cleanup | a run's scratch lives under the session's temp directory and is left there; a named file goes with a plain `rm <file>`; only a shipped fixture's own `trap` removes its own `mktemp -d` |

The same shapes outside those blocks went the same way: `ten` § 0's resolver loop and `$(…)`, `ten`
§ 5's `cd … ||` and `[ … ] ||` lines, the `hatsu_root=…; [ … ] || …` resolution in `pr-state` § 2
and `tensho` § 6 (its two root checks kept, one `test` each), `file` § 4's `cat … |` into the
private-name guard, and [`docs/using/mirrors.md`](using/mirrors.md) § 3's regeneration loop are plain
calls.

**Not yet converted** — still carrying a refused shape, each a named stop where the guard refuses it:

| Block | Shape | Why it stays, for now |
|---|---|---|
| `susanoo` § 5a, the announced tag | `$(git rev-parse --show-toplevel)`, an inline `python3` read, `case "$(cd … && pwd -P)"`, `$(sed … \| tr …)` | an inline script; its shipped form (beside `scripts/dist_tag.sh`'s) is owed, not written here |
| `izanagi`, the v0.3.0 transcript | `export GH_TOKEN=$(gh auth token)` | a dated record of what ran, never a block to run |
| `illumi.md`, the long watch; `izanami` § 2 | `nen watch until --command "<string>"` | row (b)'s workaround; no `--pr` predicate expresses it |
| `bankai-handbooks` § 2, the canon checkout | `[ -d … ] \|\| git clone …` | a plain `git clone` into a path that does not exist, else nothing; the `\|\|` stays until the block is split |
| [`docs/using/cursor.md`](using/cursor.md) § *The model matrix*, the grok selection | an inline `$(…)` read | an improvised read, never a skill block; a named stop where refused |


## Writing a commit — the message and the two streams

Moved here 2026-09-20 out of [`kokusen`](../claude/skills/kokusen/SKILL.md) §§ 5–6, beside the
`commits` policy it enforces; [`aka`](../claude/skills/aka/SKILL.md) reads the same rules when it
squashes.

```bash
nen commit format --repo <path> --type <type> --subject "<short imperative subject>" [--scope <scope>] \
  [--breaking] [--body "<one paragraph>"] --trailer "Hatsu-Agent=<responsible-persona>"
nen commit format … > <message file>      # exit 0 REQUIRED before the next line; NEVER 2>&1
nen commit write --repo <path> --message-file <message file> [--trailer "<Key: value>"]... \
  [--require-proof <lane>] [--dry-run] [--json]   # nen 0.13: validates again, commits, -> {sha, subject, trailers}
```

`nen commit format` validates **shape** only — a declared type, a non-empty subject under 72
characters, no trailing punctuation — plus the trailer policy when `--repo` is passed. What changed
and why is the skill's to write, never nen's. **Always pass `--repo`**: the verb finding a policy from
the working directory is a courtesy of where the command ran, not a contract. **The body is the literal
`--body` value**, a multi-paragraph body one quoted argument with blank lines inside it, **never
`--body "$(cat <file>)"`** (shape (2) of [PROCESS.md](PROCESS.md) § *Residue and owned dependencies*,
#218); nen takes no body file yet.

**Attribution** follows § `commits` above: pass exactly the truthful canonical trailer —
`Hatsu-Agent=<responsible-persona>` for Hatsu work, `Akatsuki-Agent=<responsible-persona>` only for
autonomous Akatsuki work — and **never infer or default the persona**. **Prospective tooling is not an
exception**: disable or reconfigure any authorized injection that adds a forbidden attribution, and
where it still adds one, **stop and report the required correction** rather than certifying the commit
as compliant. **Existing history is not rewritten.** Reading the rendered output against
`commits.forbiddenTrailers` before the commit is written is the layer that survives a missing flag.

**The `commit write` line is gated on the format verb's exit code, and the two streams are kept
apart.** The refusal goes to **stderr** with nothing on stdout, so both obvious spellings are wrong:
`2>&1 > <file>` **hands the refusal over as the message**, and a plain redirect that ignores the exit
code **hands over an empty file**. `commit write` validates the file as `commit format` does and
refuses a red proof under `--require-proof` and an empty index, so it catches both; it is still not
the layer to lean on.

| Exit | Meaning | What the phase does |
|---|---|---|
| `0` | the message is on stdout | **use it** — `nen commit write --message-file` |
| `2` | **refused** — a shape violation, or an attribution trailer `nen/workflow.json` does not admit | **stop**, quote the stderr sentence, fix the input, re-run. Never commit the file: it is empty |
| `1` | the trailer policy could not be read — `nen/workflow.json` present and **malformed** | **stop.** Report it as a repository defect and point at `nen schema check` |

**An empty `<message file>` is the tell for either refusal**, checked before `commit write` whichever
way the exit code was read. `--message-file`, never a message retyped from memory. **Never `--no-verify`** — a
commit hook that refuses is the repository speaking. Stage explicitly, path by path.

## Verified delivery — the coordinator's four claims

Moved here 2026-09-20 out of [`build`](../claude/skills/build/SKILL.md) § 7; it governs every
coordinator that hands work to a delegate — `build`, [`mukai`](../claude/skills/mukai/SKILL.md) and
[`en`](../claude/skills/en/SKILL.md) alike.

**The coordinator owns verified delivery, including delegated work.** *Implemented*, *review findings
fixed*, *review round completed* and *Ready* are **four separate claims**: a delegate may establish
the first two with a pushed SHA and appropriate checks, and the coordinator **must personally verify
the latter two against the live PR** before reporting completion. Delegation transfers a bounded task,
never responsibility for the final claim. Before a handover:

1. Read the current head, the checks, **every review body including suppressed findings**, and every
   thread.
2. Verify the fix **at the pushed SHA** — a green test run, a pushed commit or a delegate's "done" is
   not that evidence.
3. Post each on-thread disposition through `nen pr threads reply`, resolving a thread only when it is
   addressed. A reply naming a delegate's commit names one on the PR's head chain
   ([PROCESS.md](PROCESS.md) § *Reviewer rounds and review threads*, zheref/hatsu#139).
4. Confirm a **fresh** snapshot carries no unresolved prior-round threads.
5. Reconcile the associated-issue set under [`shibari`](../claude/skills/shibari/SKILL.md)'s linkage
   contract — every issue in the body **and** in Development, completion or partial stated,
   dependencies and incidental references named separately, re-checked after every scope change.
6. Report code/checks complete, review handling complete, formal readiness and the human
   merge/release decision **as four distinct claims**, naming absent evidence as remaining work or the
   precise gate blocker — **never ending a run as delivered solely because a PR was opened**.

## Delegate briefs — how a delegate waits (zheref/hatsu#473)

Every brief that raises a builder delegate — [`kazaana`](../claude/skills/kazaana/SKILL.md) § 3's and
[`futon`](../claude/skills/futon/SKILL.md) § 4's — carries the lines between the two markers below **word
for word**. **Illumi's long watch is not one**: it is `en`'s observation hold, governed by
[`en`](../claude/skills/en/SKILL.md) §§ 6–7 and [`illumi.md`](../claude/agents/illumi.md), and measured in
hours. The orchestrating session owns the clock; a wait the
delegate owns is one it cannot see. Three hand-backs were lost that way in the 2026-10-23/24 delivery run
(epic zheref/hatsu#454): a delegate left on a `gh pr checks --watch` or a `sleep` loop, the orchestrator
reading the pull request itself hours later.

<!-- delegate-wait:begin -->
- Never wait on `gh pr checks --watch`, an open `sleep` or poll loop, or a background job left running.
- A wait is one `nen watch until … --max-iterations <n> --interval-ms <ms>`, both flags passed, the two multiplied within this brief's ceiling: 9 minutes unless this brief names another.
- The host call that runs the wait sets its own timeout above the wait's (e.g. Bash timeout 600000 for a wait of 9 minutes or less).
- At the bound, settled or not, hand back: the head SHA, each check and review round as read, and what is still pending.
<!-- delegate-wait:end -->

**Why both flags:** without `--max-iterations` the wait takes `monitor.maxCycles`, and without
`--interval-ms` it paces at `monitor.pollSeconds` (§ 2 `monitor`) — 20 × 300 s on this repository, 100
minutes, over ten times the ceiling. The ceiling sits under Claude Code's 600000 ms Bash maximum (its
default is 120000 ms), so a host call that times out first never cuts a wait off before its hand-back. A brief naming another ceiling says so on a line of its own, the canon
line staying as written, and **a named ceiling stays under the host call's maximum timeout** (600000 ms
for Claude Code's Bash), since the host-timeout line cannot hold above it. A longer wait is several
bounded waits, each with its own hand-back. The hand-back is the delegate's whole report on the wait; whether to wait again is
the orchestrator's, and *Verified delivery*'s four claims stay its own.

`node scripts/delegate_brief_check.mts <brief>` reads the block from this file (`--print` prints it to
copy) and refuses a brief that drops, rewords or paraphrases a line — exit `1`, each line named; a
brief path holding a comma, colon or line break, a canon path holding a line break, a missing brief, an unreadable canon or a block whose markers are missing or doubled is exit `2`. Its lane
is `delegate-brief-guard`, run in CI by `scripts/unit_tests_ci.mts`. Out of scope: a new nen wait verb,
changing a harness's own timeouts, and the orchestrator's own watches.

## Building an issue with no CI plane

Moved here 2026-09-20 out of [`build`](../claude/skills/build/SKILL.md) §§ 4–4a; it is the plane's
fact, not one skill's, and [`backlog-loop`](../claude/skills/backlog-loop/SKILL.md) drives the same
objects.

**Hatsu holds no CI plane** — no App, no workflow, no bot identity — so a released issue has nothing
to be routed *to*: Kurapika builds it himself, in session, in the confirmed mode. **Where the work is
something a local session structurally cannot do at all** — a credential only a retired CI identity
held, a decision only that nonexistent plane could make — the run **stops at G5** and names the gap,
rather than pretending a wake occurred; local authorship is the default, so there is no escape hatch.

### Releasing an issue into `building`

```bash
nen label apply <CODE>-IS-#<N> --label <the building label> --repo-slug <owner/name> \
  --repo <the target checkout> --reason "<why, for the ledger>" --run
```

The stage label is the G1-M go-signal (`CON-25`) and real bookkeeping that `backlog-state` and
`backlog-board` read. `--repo` names the checkout whose `nen/labels.json` validates the label. Inside
a run holding the `CON-25` carve-out it may be applied without a further prompt, **for the named issue
and for children created beneath it**, every application logged: object, label, time. **Exactly one
stage label at a time, and zero before release** (`CON-9`) — no verb enforces the exclusivity, so it
stays the run's own discipline.

### Advancing an epic's waves

```bash
gh issue view <epic-N> --repo <owner/name> --json body -q .body > epic-body.md
nen epic next-wave --body-file epic-body.md --citation <the clause the progress footer cites> \
  [--completed <n>] [--inflight <a,b>] --cap 2 --out epic-body-out.md --json
nen issue edit-body --target <owner/name> --issue <epic-N> --body-file epic-body-out.md
```

The child-line grammar, the `blocked by`/`blocks` edges, the `unparsed` row and the refusals are the
verb's own. What the caller owes: **`--body-file` and `--out` resolve against `--repo`'s root**, not
the cwd; **`--out` only rewrites the local file**, posting it back being `nen issue edit-body`, whose
whole-body write is not conditional; and **a table-shaped epic is invisible to the verb**
(`{"total":0,"done":0}`), so **an epic a Hatsu skill decomposes writes its children as checkbox lines
carrying a resolvable issue reference**, stated to the decomposer explicitly.

**The delivery PR is the terminus — computed, never inferred:**

```bash
nen issue terminus --target <owner/name> --issue <N> --chain-labels "<the caller's role map>" \
  --integration-prefix "integration/" --trunk main
```

An issue with no epic/chore label answers `own-pr`; a closed one `run-already-ended`. For a team-mode
epic the terminus is the single `integration/* → main` PR the maintainer merges at G2; for direct mode
each child's own PR; for a `CON-36` chore the `integration/<chore> → main` delivery PR. **A sub-PR
merged onto a chore or integration branch is not the gate** and never ends a run.

### The local build, and the concurrency cap

```bash
nen loop slots --efforts <absolute path>/efforts.json --local-cap 2 --json
nen shu warmup --repo <the target checkout> --branch kurapika/<slug> [--dry-run]
nen shu tools  --repo <the target checkout> [--install]
nen shu <iteration-check> --repo <the target checkout> --lane <iteration-lane> [--dry-run]
nen shu test   --repo <the target checkout> --lane <declared-focused-lane>
```

**Never drive more than two efforts concurrently**, mechanized rather than eyeballed. **Every local
effort is `"plane":"local"`**, so a slot never frees on "the PR opened": it frees only once a PR is
both `"ready":true` **and** `"prompted":true` — the maintainer has actually been shown the `MERGE`
ask. **`--local-cap` is required** (the old default of `7` was removed) and `--efforts` resolves
against the process cwd, so pass an absolute path; say which effort is waiting when the cap binds.
**Never let two children touch the same file at once** — sequence them, as a stack (§ *Stacked pull requests*) or futon § 5's integration branch, and say so; no verb governs it.

**Verification runs through the phase owners** — [`rasengan`](../claude/skills/rasengan/SKILL.md) for
authoring feedback, [`kokusen`](../claude/skills/kokusen/SKILL.md) for the finished-tree checkpoint;
full regression belongs to `kotoamatsukami` at `mukai` and coverage to `byakugan`, and **a composite
confers no exception to those boundaries**. **The focused row must actually scope the authored
behaviour and no runner or filter is invented.** A red iteration check kokusen cannot clear returns to
rasengan (row `red-lint`), and a changed executable with no declared scoped lane gets its tests
authored (row `missing-focused-route`) — neither is a stop.

**Never `--discard` a tree you have not inspected**: `nen shu warmup` refuses a dirty tree at exit `2`
listing every path, refuses a name that already exists locally or on `origin`, requires `--repo`, and
has **no `--tests` on the initial warm-up**. **`nen shu tools` exit `5` names the fix per tool**:
install or resolve through the surface's own catalogue probe (row `missing-tool`), never with
elevation and never at an unpinned version. **Exit codes are `claude/agents/kurapika.md` § *The `shu`
verbs*'**; **`4`** is a seat whose reason is quoted, after which the repository's own documented
command is run and said so, a declaration change landing as its own PR at the declaration gate (**G4**
in a canon repository, **G2** in a consumer one, ruling 2026-09-18); **`3`** is a **G5** naming the
host that can, never a retry. **A repository with no `project` block** refuses every `shu` verb but
`warmup` at exit `2` naming the missing file — a different fact from `nen shu detect` exiting `1` —
and either way its own documented commands are run, **saying plainly that no declaration exists and
which case it was**.

### Stacked pull requests — overlapping efforts are delivered in order, never raced (ruling of 2026-10-12)

**The failure this prevents.** Several PRs opened in parallel against the trunk, each touching the same
files — the top of `CHANGELOG.md`, the plugin manifests' `version`, the generated mirrors, one shared
skill — merge one at a time and break every sibling's base as they land: the second needs a catch-up
merge, the third a conflict pass, and the human gate turns into a conflict-resolver loop
(zheref/hatsu#219, <product-repo-C>#242's three PRs). **Overlap is sequenced, not raced**, and the sequence is a
**stack**: one PR per issue, each branch cut from the previous effort's tip, each PR based on the
previous effort's branch, merged **bottom-up** by the maintainer.

**The rules, stated once here** (futon § 5 and breath § 3 cite them):

1. **When to stack — the default on overlap.** Two efforts in one run whose diffs would touch a common
   path — read from the files each touches; the manifests' `version` and the regenerated mirrors count
   as touched by every plugin-shipped change, while `changelog.d/` fragments do not collide — go in one
   stack. That is the default when the maintainer gives no word in an attended run (an idle run never stacks, § *Batch delivery* rule 4); futon § 5's integration branch is the
   other shape, typed. Efforts with disjoint paths may run as independent PRs against `branch.base`; an
   effort found to overlap after it was cut is caught up onto the stack's tip (`nen wc catch-up --base
   <the previous effort's branch> --strategy rebase` while unpublished, `merge` once published) rather
   than left to race.
2. **Cutting.** The first effort is cut from `origin/<branch.base>` with `nen shu warmup`; every later
   one from the previous effort's **published** branch — `nen shu warmup --repo <wt> --branch <next>
   --from <previous branch>`, which needs a local branch of that name (`git branch <prev> origin/<prev>`
   where only origin has it) and, in a linked worktree, cuts from `origin/<previous branch>`,
   `--no-track`. A delegate authoring beside another effort on overlapping files cuts from the stack's
   tip, never from the trunk.
3. **One mechanical commit per PR at stack time.** The bump (monotonic along the stack: patch for
   wording, minor for behaviour — CONTRIBUTING § *A change to a shipped surface needs a version bump*),
   the `changelog.d/` fragment (CONTRIBUTING § *Changelog fragments*) and the stamp-only mirror churn
   land on each branch after its content; a mirrored skill's own body change regenerates in the same
   commit as its source (README). A catch-up over the previous PR's mechanical commit conflicts on the
   manifests and the stamps — Hatsu declares no `mechanical` block — and is resolved by keeping the
   branch's own manifests and regenerating the mirrors at its stamp, said.
4. **The PRs.** Each PR's base is the previous effort's branch; only the bottom PR targets
   `branch.base`. Every PR is reviewed on its own (hanten per effort, its own budgets), carries its own
   `Closes #<N>` and Development link, and reads its guards against its stacked base. **A stacked PR is
   presented nowhere as mergeable** (ruling 2 of 2026-09-29, kept by the 2026-09-30 amendment): the
   merge prompt exists only for the PR whose base reads `branch.base` at that moment. A stacked effort's
   local slot frees as every effort's does, at `ready+prompted`: its PR Ready and its Ready stop shown
   (zheref/hatsu#425, [HR-353](ROSTER.md#hr-353), record `R-2026-10-23-20`, which reconciles small ruling 4 of 2026-10-13 — *freed at PR-open on its
   stacked base, hanten settled* — and HR-257 to that one value; nen's `stacked-open` is not used).
5. **Merging, bottom-up, one at a time, with `--merge`, never a squash** (a squash would re-carry the
   lower PR's commits into the next diff). After each merge the run — or `hatsu:en <next>` — **retargets
   the next PR to `branch.base` first** (`nen pr retarget --base <branch.base>`, en § 5 check 1) **and only
   then deletes the merged head branch**: deleting it first closes the dependent PR (observed on HA-PR-#250
   and #253, 2026-10-13: each timeline shows `base_ref_deleted` then `closed` within a second, against GitHub's
   *Deleting and restoring branches in a pull request* page, which promises a retarget). A dependent PR above a
   change to a frozen workflow step reads red on CON-32(a) until that change is on `main`: the
   guard workflows run the TRUSTED validator at `main`'s head, not the PR's base; the push after the
   retarget runs it again at the new head (a close-and-reopen is the fallback where no push follows;
   `gh run rerun` reuses the stale trusted revision). Then en § 5's remaining checks run at the
   new base (the readiness check re-runs on a push or a re-run, since `pr-readiness.yml` does not fire
   on `edited`), and only then the one `MERGE` ask. A PR whose base is neither is stranded (en § 6).
   **Nothing in a stack is merged out of order.**
6. **Said in the report.** The desk carries the stack as one plan line (order, each PR's base and
   version) and one `MERGE` ask — for the PR whose base reads `branch.base` — and every PR body's
   *Associated issues* note reads `stacked on #<prev>`, so the reader never has to derive the order.

The integration branch of futon § 5 is the other sequencing shape — one local merge per effort, one PR
at the end — typed by the maintainer (2026-10-12: *"I'd like all PRs delivered by next time I visit the
session (not by batches). Feel free to use stacked PRs and make sure the final report comes with a clear,
step-by-step review/merge instructions …"*).

### A target repository with no delivery-stage taxonomy

Registry and labels are separate prerequisites, so a verified `nen/repos.json` and `nen/labels.json`
enable identity resolution and issue filing even where the GitHub labels declare **no delivery
stages**. **Never manufacture a `--chain-labels` map and never apply a nonexistent stage label.** For
an explicitly authorized standalone local issue there, inspect the live issue state, body and
associated PRs, state that `nen issue chain-position` has no usable role map, and carry the effort
through authoring to its own PR — **a raw GitHub issue read is named residue for this path, never a
computed chain verdict**. A PR goes to [`sharingan`](../claude/skills/sharingan/SKILL.md), a closed
issue is reported and the run ends, and an unresolvable epic/integration relationship stays a real
blocker. **The exception creates no G1 or label authority**, every gap goes through
[the discovery protocol](DISCOVERY.md), and a missing metadata declaration is repaired only when
authorized, or recorded pending — never guessed.
