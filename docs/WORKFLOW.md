# The way of working

How a request becomes a merged pull request, and where every parameter of that journey is written down.

This document is the **authority on the two configuration files** and on the phases that read them. The
skills under [`../claude/skills/`](../claude/skills/) are the authority on what each phase *does*;
[`ROSTER.md`](ROSTER.md) is the authority on who exists. Where this document and a configuration file
disagree, **the file wins and this document is the bug** — the same rule
[`../nen/contract.json`](../nen/contract.json) already states for itself.

---

## Phase ownership — ruling of 2026-09-12

A local checkpoint, branch publication and PR completion are separate outcomes. No use of
“session complete” or “done” advances a later phase automatically.

| Phase | Required work | Evidence boundary |
|---|---|---|
| `rasengan` | Author behavior and focused tests; use them and inexpensive iteration checks for feedback | Feedback is not the checkpoint verdict |
| `kokusen` | Run declared iteration checks and applicable declared focused tests on the finished tree; commit locally | Full regression and coverage are not checkpoint gates |
| `amaterasu` | Build the selected platform artifact, install it and launch it from the core checkout on each applicable turn | Report build/install/launch separately; absent and unusable devices remain distinct |
| `aka` | Lint before squash; squash only unpublished history; catch up; recheck changed-tree lint; full required regression | Instrumented raw results are collected here and bound to tree, configuration and command |
| `mukai` / `gyo` | Review and measure/gate touched-file coverage from matching regression artifacts | Extraction must not rerun tests; edits return through focused checkpoint and aka regression before publication |
| `rikugan` | Render the owning phases' evidence and discovery statuses | Reports run no tests/coverage; absent, stale and not-due evidence remain explicit |

The single `iteration.checks` list still serves `breath`, `rasengan`, and `kokusen`. There is no
checkpoint-only routing key. A scoped test runs through an explicitly declared test lane whose
command names the scope; do not invent a test filter or substitute the full suite. If executable
changes lack a supported scoped path, capture the dependency and stop that checkpoint honestly.
Hatsu's prose-only changes retain the lint-only iteration list. Its executable version guard has
the declared `plugin-bump-guard` focused test lane; that lane is due for guard changes and is not
a general regression suite.

Any tracked tree change invalidates prior regression and coverage evidence because the capture
binds the exact tree hash, including sources, tests, snapshots and execution configuration.
Only a complete no-op catch-up may reuse the pre-catch-up lint result. Catch-up and review/coverage remediation return to the aka-owned regression
phase before publishing. Composites reuse that phase under their existing publication authority;
they do not recursively squash published history or acquire first-publish permission. Coverage
instrumentation belongs in that regression run; extraction and threshold decisions belong in
mukai. Existing thresholds and required suites are preserved.

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

## 1 · Two files, and the line between them

There are two execution/policy configuration files, and the split is not stylistic. It is the difference between a
**fact about the machine** and a **decision about the work**.

| | [`nen/contract.json`](../nen/contract.json) → `project` | [`nen/workflow.json`](../nen/workflow.json) |
|---|---|---|
| **Answers** | *How is this repository built, tested, linted, launched and shipped?* | *How do we work in it?* |
| **Content** | lanes, per-verb argv, preconditions, hosts, deploy targets, launch targets, evidence globs, host toolchain | branch shape, which declared verbs run per iteration, the coverage ladder, reports, notifications, commit trailers, monitor caps, the model matrix |
| **Executed by** | `nen shu <verb>` — nen spawns exactly what is declared and nothing else | mostly the reader. Two verbs take a slice: `nen commit format --repo` reads `commits.allowedAttributionTrailers`, `nen shu coverage --touched` reads the `coverage` ladder |
| **Changing it changes** | what runs on this machine | what the roster is willing to do |
| **Validated by** | `nen schema check` (the `nen/contract.json` row) | `nen schema check` (the `nen/workflow.json` row) — **both at nen `0.7.0`, the build every fact in this document was verified against** |

> **The nen DEPENDENCY is the third block of the first file, and its two version values move
> independently.** `dependency.minimum` is `0.7` and `dependency.pinned_ref` is `v0.8.0`: the first is the
> pin this repository declares, the second is the build its bootstrap installs. **The range `minimum`
> stands for is nen's answer, not a document's** — the binary ships `COMPATIBLE_MINOR_FLOOR`, the lowest
> `minimum` pin it satisfies, and `nen shu tools` applies it, prints it as `compat floor:` and carries it
> in `--json`. Per the maintainer's ruling of 2026-09-10 — *exact minor is fine, unless there is a
> breaking change* — `minimum` moves **only** when nen's CHANGELOG carries a real bullet under
> `### Breaking / consumer notes`, while `pinned_ref` may move on its own to a newer release inside the
> range. Wherever this document says *"at the pinned nen `0.7.0`"* it names the build the fact was
> verified against; [`../nen/contract.json`](../nen/contract.json) is the only place either value is
> written down, and the warm-up
> ([`hatsu-warmup`](../claude/skills/hatsu-warmup/SKILL.md) § 1b) reads the verdict rather than computing
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

### `branch`

```json
"branch": { "template": "{model}/{persona}/{descriptor}", "base": "main" }
```

| Key | Default | Read by |
|---|---|---|
| `template` | `{model}/{persona}/{descriptor}` | `breath` (cuts it), `hooks/guard-base-branch.sh` (names it in the refusal) |
| `base` | `main` | `breath` (fast-forwards it), `ao` (pulls from it), `shibari` (opens against it), `hooks/guard-base-branch.sh` (refuses a commit or a push on it) |

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
> ruling of 2026-09-10 ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-09-10*). The same pair of keys is read
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
> | **On the PR** | [`.github/workflows/surface-mirror-check.yml`](../.github/workflows/surface-mirror-check.yml) — **a real check at the pinned `v0.7.0`**, advisory only until the maintainer requires the context. It skipped with a notice while `dependency.pinned_ref` named a nen with no `surface` verb; that branch is now an error. |
>
> The script writes nothing and needs no credential, so running it more often costs nothing but the seconds.

### `tests`

```json
"tests": { "required": ["test"], "extra": [] }
```

| Key | Default | Read by |
|---|---|---|
| `required` | `["test"]` | `tsukuyomi`; red is a **G5** stop inside `aka` |
| `extra` | `[]` | `tsukuyomi`, run after `required` and reported separately |

An **empty `required` is a statement, not an omission**: it says this repository has no automated suite, and
`tsukuyomi` reports that rather than inventing a runner. **With `required` and `extra` both empty the verdict
is `not applicable — no tests configured` — never green.** Nothing ran, so nothing passed, and `aka` reads
that word as *nothing to prove* and says so in the push report rather than converting it into a pass. It is
not a G5 either: an empty required set is not a red suite. A test is never patched to pass.

### `coverage` — the ladder

```json
"coverage": { "minimum": 80, "recommended": 85, "ideal": 90, "scope": "touched" }
```

| Key | Default | Meaning |
|---|---|---|
| `minimum` | `80` | **the stop.** A touched file under it is a **G5**: `gyo` adds tests until it clears, or the maintainer decides |
| `recommended` | `85` | the band `gyo` aims for and reports against |
| `ideal` | `90` | the band worth saying out loud when it is reached |
| `scope` | `touched` | line coverage of the files in `git diff --name-only origin/<base>...HEAD`, **not** the repository total |

Three numbers rather than one, because a single threshold turns into either a gate that blocks honest work or
a number nobody looks at. The ladder reports bands and stops only at the bottom rung. **The bar is never
lowered to clear it** — that is the one move `gyo` will not make, and a repository that cannot honestly reach
`minimum` is a G5, not a smaller number.

`nen shu coverage --threshold <n>` **reports** `met: true|false` and never changes its exit code; nen does not
decide whether a number is good enough. At the pinned nen `0.7.0`, `--touched --base <ref>` filters the rows
to the files the diff names and — with no `--threshold` — reads the ladder here itself, printing a `ladder:`
line and a `band` per row (`under-minimum` / `minimum` / `recommended` / `ideal`). It still never gates.

### `launch`

```json
"launch": { "default": "<target>", "fallback": "<target|null>" }
```

`default` and `fallback` name keys of `project.launch` (§ 3). `amaterasu` starts `default`; when its device
is not connected it reports the device **by name** and falls back to `fallback`, or stops if that is `null`.

**A `null` `default` with no `project.launch` is the no-launch case, and it is an answer.** Hatsu's own are
both `null`, and it declares no `project.launch` at all: a plugin is loaded by Claude Code, not launched. In
that repository `amaterasu` records **`no launch target declared; skipped`** in the turn report and continues
to `rikugan` and `jutaisho` — **it does not ask**. `ren` reaches the phase every turn, so a question there
would be a question per turn about something the configuration already settled. The case that *does* ask is a
repository whose `project.launch` declares targets while `launch.default` is `null`: that is an unanswered
question, not an answered one.

### `reports`

```json
"reports": { "dir": "Reports", "retain": "final-only", "template": "rikugan",
             "captures": "Reports/captures" }
```

| Key | Default | Meaning |
|---|---|---|
| `dir` | `Reports` | **git-ignored.** The only directory a report is ever written to |
| `retain` | `final-only` | **the retention rule — what is KEPT**; see below |
| `template` | `rikugan` | `templates/<name>.html` in this repository |
| `captures` | `Reports/captures` | where screenshots land before they are inlined as data URIs |

**The retention rule — and what it does *not* say.** `rikugan` runs at three moments — every turn, at
landing, and once after the merge — and `retain: final-only` means **only the last one is KEPT**: only the
final report gets a dated file of its own, `<dir>/<YYYY-MM-DD>-<branch-slug>-final.html`. A directory holding
one report per turn is a directory nobody opens; the final report is the one with tests run, scenarios,
touched coverage and the architecture delta, and it is the one worth finding six months later.

**It is a rule about what survives, not about whether a working file exists** (maintainer's ruling,
2026-09-09). Turn and landing reports are published to the conversation as an Artifact; on a surface that
cannot publish one they are opened from the **transient** `<dir>/current.html` — one path, rewritten by every
render, never dated, git-ignored. That file is **admitted** under `final-only`, because a page that is always
the latest render and can never be found again after the next turn is not a retained report. `dir` is
git-ignored for the same reason a build output is: it is derived, and a derived file in git is a merge
conflict waiting to be resolved by coin toss.

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
value settles it. **`turn` is IN the `nen.workflow/v0.1` shape at the pinned nen `0.7.0`** — a closed set of
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

The final section of every PR body is also [`## Agent attribution`](AGENT-ATTRIBUTION.md): a ledger
of each actual participant's canonical Hatsu persona, role/contribution, and evidence. Runtime
alias/display name and model are not recorded and never replace the canonical persona. Commit
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

**Enforcement is three-layered, and at the pinned nen `0.7.0` two of the three are mechanical.**

| Layer | What refuses | Where it lives | Live at the pinned nen `0.7.0`? |
|---|---|---|---|
| **(a)** the **skills'** own refusal — `kokusen` reads the rendered message before it commits, `aka` before it squashes | agent-side | this repository | **yes**, and it is the layer Hatsu ships |
| **(b)** the target repository's **`commit-msg` hook**, generated from `allowedAttributionTrailers` by `nen scaffold init` | the target repository's `.git/hooks/` | **target-dependent** — it exists only in a repository `nen scaffold init` has stood up; this week in `zheref/nen`; KroApple and kro-pwa already carry one | **target-dependent** |

> **From nen `v0.6.0` that hook's automated half is DERIVED from the repository's own policy, not a fixed
> pair baked into the generator.** It requires exactly the ONE attribution trailer `--agent-trailer`
> resolved to — optional now, defaulting to `Akatsuki-Agent`, the family's CI-plane key, carried as **data**
> in nen's `templates/workflow.json` rather than as a literal in shipped code — plus, only when the policy
> states one, the key under the new and separate `commits.runTrailer`. A run identifier is never itself an
> attribution claim, so it is not folded into `allowedAttributionTrailers`; absent (`null`) by default, it
> makes the second requirement optional where `--run-trailer` used to be mandatory. **`--marker-env` is the
> only flag `nen scaffold init` still requires unconditionally**, and its missing-flag refusal names it and
> says what the other two default to — verified live at the pinned `0.7.0`, exit `2`
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

So **at the pinned `0.7.0` layer (c) is installed everywhere the invocation carries `--repo`, and only
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
"monitor": { "maxCycles": 20, "pollSeconds": 300 }
```

`en`'s `izanagi` cap and its poll interval. **The cap is grammar, not a default**: a watch loop invoked
without one does not run, exactly as [`izanagi`](../claude/skills/izanagi/) refuses an invocation with no
`up to <N>`. § 5 is where both keys are actually spent, and where the long watch hands over to Illumi.

**From nen `0.7` the cap is ENFORCED by the binary rather than counted in a skill's prose.**
`nen loop iterate --id <id> --line "<task> until <condition> up to <N>"` claims one acting iteration
against the cap its own line states and **refuses the claim past it**, exit `1` — so `maxCycles` is a
number a verb holds a caller to, not one a caller is trusted to remember. The ledger is
`.nen/loop/<id>.json` under `--repo`, in the same dot-prefixed generated tree `nen stop --mark` writes to,
never the committed `nen/`. Two consequences worth stating here rather than only in the skills:

- **The cap cannot be raised by re-typing the invocation.** The `--line` is restated on every claim and a
  claim whose line differs from the running one is refused at exit `2`, naming both. A cap a caller can
  widen by editing its own sentence is a suggestion with extra steps.
- **The cap outlives the session, because the ledger is a file.** `en` keys the id on the pull request, so
  a re-invoked landing resumes the same count rather than restarting at cycle 1 — the watch is per
  session, the cap is per landing. Ending a landing closes the ledger with `--release <why>`, which a cap
  never blocks.

### `models`

```json
"models": {
  "rule": "latest alias only, never a version; subagents never on the frontier tier",
  "claude": { "frontier": "fable", "deep": "opus", "fast": "sonnet", "economy": "haiku" },
  "codex":  { "frontier": "astra", "deep": "sol",  "fast": "terra",  "economy": "luna" },
  "cursor": { "frontier": "grok",  "deep": "grok", "fast": "composer", "economy": "composer" },
  "roles":  { "reviewer": "deep", "worker": "fast", "measurer": "fast", "orchestrator": "frontier" }
}
```

Four **tiers** per surface, and a role maps to a tier rather than to a model. A pinned model version is a pin
that rots; a tier survives every model release, which is the only way a matrix written today is still true in
six months. On Cursor the tiers are Cursor-native only — provider models there are reserved for Bugbot.

**Two rules ride on this matrix, and neither is optional.**

- **A subagent is never given the frontier tier** (`fable`, `astra`). The frontier tier is where the
  maintainer's own conversation lives; a delegate that outranks its caller has inverted the delegation, and
  the cost lands on the maintainer's session rather than on the delegate's.
- **Every subagent is titled `<skill> · <persona> · <model alias>`** — `hanten · hisoka · sonnet`,
  `rasengan · kurapika · opus`. Three facts, in the order you need them when you are reading a transcript
  afterwards: what ran, as whom, on what.

The persona pins that follow from `roles` are frontmatter in the agent definitions themselves: **Gon** and
**Phinks** `model: opus` / `effort: high`; **Hisoka** `model: sonnet` / `effort: high`; **Uvogin**
`model: sonnet` / `effort: medium`. **Kurapika carries neither** — he is the main session and inherits
whatever the maintainer is running.

#### The matrix, per surface — the reviewer tier, and how a delegate is raised

Hatsu runs on three surfaces ([`docs/SURFACES.md`](SURFACES.md)). The matrix is one table with a column per
surface for exactly this reason: **the tier is the policy and the alias is the surface's answer to it.**

| | **Claude Code** | **Codex** | **Cursor** |
|---|---|---|---|
| `frontier` — the orchestrator, the maintainer's own session | `fable` | `astra` | `grok` |
| `deep` — **`models.roles.reviewer`**, so this is the reviewer tier | **`opus`** | **`sol`** | **`grok`** |
| `fast` — `worker`, `measurer` | `sonnet` | `terra` | `composer` |
| `economy` | `haiku` | `luna` | `composer` |
| **how a subagent is raised** | the harness's **Agent tool**, `isolation: "worktree"` | **`codex exec -m <id> -C <dir> -s workspace-write`** — a whole second process; **this surface has no in-session subagent**, verified against `codex exec --help` | a **subagent definition** at `.cursor/agents/<persona>.md`, mirrored there from `claude/agents/` |
| **isolation** | the harness makes the worktree | **`git worktree add` first** — `-C` takes a directory and creates none | the surface's own; the skill states which it got |

**A reviewer runs at the `deep` tier on every surface** — `opus`, `sol`, `grok` — because
`models.roles.reviewer` is `deep` and a role maps to a tier rather than to a product.
[`claude/skills/hanten/SKILL.md`](../claude/skills/hanten/SKILL.md) § 9a is the mechanism, per surface, with
the exact invocation.

**The frontier tier never runs a subagent, on any surface.** Not `fable`, not `astra`, not `grok`. The
frontier tier is where the maintainer's own conversation lives; a delegate that outranks its caller has
inverted the delegation, and the cost lands on the maintainer's session rather than on the delegate's.

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

**An alias is a name, and the id you type may still carry a version.** `models.rule` is *"latest alias only,
never a version"*, and that governs **the file**; a surface's command line may need the concrete id — on
Codex the `sol` tier is spelled `gpt-<version>-sol`, so the id is **read from `codex debug models` at the
moment of use** rather than remembered (`docs/SURFACES.md` § 5). Reading it is what keeps the versionless
alias in the file honest.

**A persona's `model:` pin does not translate between surfaces.** `nen surface mirror generate` carries
`model` through to `.cursor/agents/<persona>.md` verbatim — correctly, since it mirrors rather than
translates — so Hisoka's `sonnet` arrives on Cursor as a Claude alias in a Cursor-native-only matrix. The
rule is `hanten`'s § 9a: **report the pin unresolvable, fall back to the role's tier, and state the
substitution in the title.** Never silently honoured, never silently dropped.

---

## 3 · `project.launch` and `project.evidence`

Two blocks of nen's `project` shape that began as Hatsu extensions. **At the pinned nen `0.7.0` both are
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

`amaterasu` runs `--dry-run` first, pastes that argv into the report and the chat, then runs it bare — **from
the core working directory, never from a worktree**. A worktree exists to produce a diff; an app started from
one runs against a tree nobody has open. Parallel subagent efforts launch nothing at all.

### `project.evidence`

```json
"evidence": { "globs": ["**/__Snapshots__/**/*.png"], "mechanism": "public-mirror",
              "scene": "{suite}-{scene}" }
```

`globs` are the artifacts that count as visual evidence; `scene` is the template that turns a path into a
suite-and-scene pair; `mechanism` is how the images reach a pull-request body. `kotoamatsukami` re-records
them, `rikugan` lays them out as a table with scenes as columns, and `shibari` puts that table in the PR.
Pre-PR, PNGs are embedded as **data URIs** so a report is one self-contained file with no host to go stale.

---

## 4 · The phases, and which of them a human calls

**Per request, the loop is `ren`**, and it runs without being asked:

`breath` (first turn of an effort — and it proves the base tip builds) → `rasengan` (**author the change**)
→ `kokusen` (**verify the finished tree, then commit**) → `amaterasu` (launch) → `rikugan` (the turn's
report) → `jutaisho` (the bell).

It loops. **It never pushes and never opens a pull request.**

**Five phases are the maintainer's to call, and no agent ever prompts for them:**

| Phase | What it does | Why it is the human's |
|---|---|---|
| [`aka`](../claude/skills/aka/) | lint → squash the unpushed commits → `ao` → final-tree regression → push | publishing work is a decision, and a squash is destructive |
| [`mukai`](../claude/skills/mukai/) | `murasaki` → `hanten` review → matching aka regression evidence → `gyo` → publish proven updates → evidence → `shibari` opens the PR → starts `en`. **§ 5 is the full shape** | a PR is a request for other people's attention |
| **merge** | **G2** (`CON-5`) | never delegated, by any agent, anywhere |
| [`kagutsuchi`](../claude/skills/kagutsuchi/) | a non-production upload, **per target**: `nen shu deploy --target <name>` prints the plan always, and `--run` acts only on a call that **names the target** | the blast radius leaves this machine |
| [`mugetsu`](../claude/skills/mugetsu/) | publication, **per target**, **G3** (`CON-6`): only on a recorded per-target go, with the preflight green and the tag already cut — one target per call | the blast radius is other people's users |

**The per-target rule is the whole of the last two rows, and it is not a formality.** A go for one
destination is a go for *that* destination: `--target` is required with no default even where exactly one
is declared, and a second destination is a second call the maintainer makes. Neither phase is ever reached
from a composite — not from [`futon`](../claude/skills/futon/)'s `then` clause, not from
[`getsuga`](../claude/skills/getsuga/), not from [`en`](../claude/skills/en/) — and the release unit both
of them send is built by [`susanoo`](../claude/skills/susanoo/), which uploads nothing itself.

Asking *"shall I push now?"* at the end of a turn is how a human-called phase becomes an agent-called one by
attrition. The loop simply stops and waits.

**The only interruptions are genuine G5 stops. There are five:**

1. **red required tests** — in `aka`, via `tsukuyomi`
2. **touched-file coverage under `coverage.minimum`** — in `gyo`
3. **a semantic conflict** — in `ao`. A *mechanical* conflict is resolved, not escalated
4. **an unsettled adversarial finding** — in `hanten`, after Kurapika has fixed it or pushed back with a reason
5. **a `sharingan` escalation** — a PR that will not reach Ready

**A red *iteration* check is not a sixth condition, and the ruling of 2026-09-10 did not make it one.** It is
fixed where it is found: inside `rasengan`'s inner loop while the change is being written, or by handing the
tree back to `rasengan` when `kokusen`'s gate refuses to commit it. Only a red check the turn cannot honestly clear
escalates, which is the escalation `rasengan` has always carried. **The one stop that is genuinely new in
shape rather than in kind is `breath`'s**: a base tip that does not build stops the effort at step 1, *before*
a line is authored, because a broken trunk is its own effort and folding it into this one buries a trunk
regression inside an unrelated change set. It interrupts nothing that had started.

Nothing else stops the loop. **A stop is `nen stop`'s banner, the report link, the options with ⭐ on the
recommendation, and the question asked through the surface's own native option picker** —
`AskUserQuestion` on Claude Code. A stop typed as prose in the middle of a reply is a stop the maintainer can
scroll past, and one they scroll past is one that did not happen.

---

## 5 · The PR side — `mukai`, and everything it runs

`ren` (§ 4) never opens a pull request. **`mukai` is the phase that does**, and like the other four it is the
maintainer's to call. Its order is fixed, and each step has exactly one job.

### `mukai` — the steps, and the stops

| | Step | What it does | Where it stops |
|---|---|---|---|
| **1** | [`murasaki`](../claude/skills/murasaki/) | catch up through [`ao`](../claude/skills/ao/), verify the changed tree, and enter the aka-owned lint/regression phase before any push, **only if the branch is already published**. A red merged tree goes to [`rasengan`](../claude/skills/rasengan/) to be authored. Never squashes, never force-pushes | **G5** on a *semantic* conflict in `ao` — a mechanical one is resolved |
| **2** | [`hanten`](../claude/skills/hanten/) | the adversarial review: classify the change set by scope, one reviewer subagent per scope | **G5** on an unsettled finding — after Kurapika has fixed it or pushed back with a reason |
| **3** | aka-owned regression phase | Reuse matching evidence, or checkpoint review fixes and execute full required tests and applicable UI suites through aka. Record instrumented artifacts and tree/configuration provenance for steps 4 and 6 | **G5** on red required tests. A seat (exit `4`) is quoted, never routed around |
| **4** | [`gyo`](../claude/skills/gyo/) | extract existing matching regression artifacts and apply the `coverage` ladder of § 2, without rerunning tests | **G5** when a touched file is under `minimum` and cannot honestly clear it |
| **5** | [`kokusen`](../claude/skills/kokusen/) then the push half of `murasaki` | **publishes the final proved tree.** Changes from steps 2–4 repeat the focused checkpoint, aka-owned lint/regression and coverage steps first; The review's fixes and gyo's new tests are edits to the working copy, and neither of those skills may commit or push; step 7 refuses to open a PR while `HEAD` is ahead of `origin/<branch>` | **G5** on a semantic conflict where the base moved again |
| **6** | evidence | the changed visual artifacts, from `project.evidence` (§ 3), grouped **suite → scene** | not a gate event |
| **7** | [`shibari`](../claude/skills/shibari/) | composes and opens **one** PR, requests the reviewers and writes the body back | never labels a gate, never merges |
| **8** | [`rikugan`](../claude/skills/rikugan/) `as landing` | the landing report, rendered **after** the PR exists because its two extra sections — the PR body and the readiness verdict — are step 7's outputs. Then **starts [`en`](../claude/skills/en/)** | not a gate event |

**Four of the five G5 conditions of § 4 live inside this one phase.** That is not an accident of layout: a
pull request is the moment work stops being private, so it is the moment the honest questions are cheapest to
ask and most expensive to skip.

### `hanten` — the routing, and the one finding shape

`hanten` classifies the change set by **scope** and spawns **one reviewer subagent per scope**. The scope
decides the reviewer; nobody picks by feel.

| Scope of the change set | Reviewer | Tier · effort |
|---|---|---|
| a **UI** surface, or a measurable quality claim | **Hisoka** ([`hisoka.md`](../claude/agents/hisoka.md)) | fast · high |
| **security-bearing** — auth flows, secrets and credential handling, network and storage boundaries, data minimisation, the supply chain | **Feitan** ([`feitan.md`](../claude/agents/feitan.md)) | deep · high |
| **architecture / handbook conformance** — layering, state ownership, the resolved stack rules, the repository's own architecture notes | **Chrollo** ([`chrollo.md`](../claude/agents/chrollo.md)) | deep · high |
| **performance** | **Uvogin** ([`uvogin.md`](../claude/agents/uvogin.md)) | fast · medium |
| **release-adjacent** — release machinery, build and packaging, a deploy target, a guard that gates one | **Phinks** ([`phinks.md`](../claude/agents/phinks.md)) | deep · high |

Each subagent is titled **`hanten · <persona> · <model alias>`** — the rule of § 2's `models` — and **never
runs on the frontier tier**. A change set with no matching scope gets no reviewer, said out loud; a change
set matching three gets three.

**The finding shape is fixed, and it has four fields, in this order:**

| Field | What it must be |
|---|---|
| **rule id** | the governing rule, cited by id — `UX-{n}`, `SEC-{n}`, `UZF-{n}`, the one resolved stack prefix, `QA-{n}` — or the repository's own note by path and heading. No un-cited opinions. Where genuinely nothing covers it: `no rule id — handbook-question`, **filed, never legislated** |
| **severity** | `critical` / `high` / `medium` / `low`, on the shared scale |
| **evidence** | file and line, the quoted snippet, and the concrete path from the code as written to the consequence |
| **proposed fix** | one concrete change in the repository's own idiom. The reviewer **proposes**; it does not apply |

**Reviewers advise; Kurapika acts.** They never edit non-test source (a test that demonstrates a finding is
the exception), never cast a review vote, never block, never merge, never label. Kurapika **fixes the finding
or pushes back with a reason** — both are legitimate. What is not legitimate is a finding that is neither
fixed nor answered: that is the G5, and `hanten` raises it, never the reviewer.

**Pre-PR, a finding's home is the working copy, not the tracker.** The whole value of the position is that a
`critical` here is a fix in the next commit rather than an issue with a lifecycle. An issue is filed only
when the finding **outlives the branch**.

### `gyo` — the ladder, spent

`gyo` is where § 2's `coverage` ladder stops being a table and becomes a decision. It reads **touched-file
line coverage** — the files in `git diff --name-only origin/<base>...HEAD`, never the repository total — and reports
each file against the three rungs:

| Band | What `gyo` does |
|---|---|
| below `minimum` (80) | **adds tests** until the file clears it; when it cannot be cleared honestly, **G5** |
| `minimum` … `recommended` (80–85) | reported, and aimed past |
| `recommended` … `ideal` (85–90) | reported as the band it is |
| at or above `ideal` (90) | said out loud, because it is worth saying |

**The bar is never lowered to clear it.** That is the one move `gyo` will not make: a repository that cannot
honestly reach `minimum` is a **G5**, not a smaller number. And `nen shu coverage` **reports** `met` and
never changes its exit code — nen does not decide whether a number is good enough, which is exactly why this
step is a skill and not a flag.

### `shibari` — one PR, and the body it must carry

`shibari` opens the pull request **from the last pushed commit**, against `branch.base`, and it opens
**exactly one**. The body is not a template preference; it is what makes the PR reviewable by someone who was
not in the session:

| Section | What goes in it |
|---|---|
| **why** | the problem, in the reader's terms — effect first, cost stated |
| **how** | the approach, and what was rejected |
| **what changes for the consumer** | the observable delta for whoever depends on this |
| **how to verify** | runnable steps. Where there is no backing issue, this section **is** the acceptance criteria |
| **a mermaid diagram** | where a flow changed — and only then |
| **the evidence table** | one table per top-level screen, states as **columns**, in the stack's own `project.evidence` mechanism (§ 3) |
| **the checklist** | the repository's own |
| **`Closes #N`** | GitHub's native autolink, kept beside the object notation |

The verbs: `nen pr body-check` (the body's completeness), `nen changelog fragment-required` (whether this
change owes a fragment), `nen gate derive` (which gate the PR stands at — **derived, never labelled by
`shibari`**), `nen pr edit-body` to write the body back, and `nen pr request-reviews` to request the
reviewers. **`nen pr edit-body --target <owner/name> --pr <n> --body-file <path>` exists at the pinned
`0.5.0`** and replaces the body outright from the file's bytes, certifying the number before any write and
refusing an issue number at exit `2`. `gh pr edit --body-file` is retired with it (§ 7).

**The evidence mechanism is assumed with confirmation, not guessed**: a stack with a registered
public-assets mirror embeds the images; a stack without one names each scene and points at its committed
snapshot path in **Files changed**. A Files-changed PR that names its scenes is **conformant**, not a
shortfall — and a rule never mixes the two mechanisms.

Then `shibari` hands the PR to `en` and stops. It never applies a gate label and it never merges.

### `en` — the landing watch, its two keys, and the Illumi hand-off

```json
"monitor": { "maxCycles": 20, "pollSeconds": 300 }
```

`en`'s order: [`rikugan`](../claude/skills/rikugan/)¹ (landing — the PR body and the readiness verdict) →
[`sharingan`](../claude/skills/sharingan/)² → [`murasaki`](../claude/skills/murasaki/)³ when the branch is
behind → `sharingan`⁴ → [`jutaisho`](../claude/skills/jutaisho/)⁵ at Ready → **watch⁶ until merged**, still
reacting to new reviews and new conflicts → `rikugan`⁷ final, **the only report written to `Reports/`**.

| Key | What it bounds |
|---|---|
| `maxCycles` | the `izanagi` cap on the watch. **Grammar, not a default** — a watch invoked without one does not run, and from nen `0.7` `nen loop iterate` refuses the claim that would exceed it (§ `monitor`) |
| `pollSeconds` | the interval between observation cycles. Never shortened because something looks close, never lengthened to stretch the cap |

**An exhausted cap is reported as exhausted.** It is never extended in place, never continued by a second
watch started to finish the first, and never rendered as "still watching". Raising the cap is the
maintainer's word, in a new invocation — and from nen `0.7` it is also the binary's answer: the claim past
the cap is refused, and the refusal says so in nen's own words rather than in a skill's.

**When the watch must outlive the session that started it, step 6 is handed to Illumi** —
[`illumi.md`](../claude/agents/illumi.md), titled `en · illumi · <model alias>`, on the **fast** tier at
effort `medium`. He is **provisioned, not ratified** (`OPEN-1`, partially closed 2026-09-09) for this watch
**and no other loop**: not `backlog-loop`, not `futon`, not `senkei`.

He is **read-only by discipline, and the definition says which** — his frontmatter carries no `Edit`, `Write`
or `MultiEdit`, but it does carry `Bash`, because every observation is a program and `Bash` can push, commit
and merge as easily as it can read. What holds is the **command allowlist** in
[`illumi.md`](../claude/agents/illumi.md) § *Your tools*; anything off it is a wake, not a command. He acts
on nothing. Each cycle he records five facts (the readiness verdict *quoted*, the checks, review activity,
base drift, terminal state), compares them against the previous cycle, and **wakes Kurapika** when one of
seven conditions fires: Ready, a new review or thread, a check gone red, the branch behind or conflicted,
merged, closed-or-drafted, or the cap exhausted. The hand-off names **what changed, since when, the PR's
current state, and the act it needs** — *names* the act; never performs it. **A watch that acts is not a
watch**, and the merge stays **G2**.

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

[`../hooks/hooks.json`](../hooks/hooks.json) carries two Claude Code hooks. **Neither is a nen-owned step.**
They are executed by the harness *around* a session rather than by a skill *inside* one, and they exist for
the two things a skill structurally cannot do: a skill only runs when the model calls it, and by the time the
model has stopped talking, or has already typed the push, it is too late.

| Hook | Event | What it does |
|---|---|---|
| [`stop-bell.sh`](../hooks/stop-bell.sh) | `Stop` | rings `notifications` rungs **2 and 3** off the marker at `.nen/last-stop.json`, then consumes it |
| [`guard-base-branch.sh`](../hooks/guard-base-branch.sh) | `PreToolUse`, matcher `Bash` | exits `2` — blocking the tool call — on a `git commit` or `git push` while the branch equals `branch.base` |

**Both are Claude Code's, and only Claude Code's.** `hooks/hooks.json` is that host's manifest, discovered
at the plugin's own `hooks/` path; **neither Codex nor Cursor reads it, and neither documents a turn-end
hook of its own** ([`docs/SURFACES.md`](SURFACES.md) § 1). So on those two surfaces the bell has no hook to
fire it and [`jutaisho`](../claude/skills/jutaisho/SKILL.md) § 6 runs rungs 2–3 in-session and says so, and
the trunk guard has nothing behind it at all — the refusal to commit on `branch.base` is the skills' own
rule there, not a reflex the harness enforces. **Say which of the two you are relying on.**

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
`futon`, `tensho` and `getsuga` for `nen pr ready --gates`, `hatsu-warmup` for `nen/contract.json`, `hanten`
for a persona's definition under `claude/agents/`. (`rikugan` is not on this list: its template is the target
repository's own `templates/<name>.html`, named by that repository's `nen/workflow.json`.) **The name they
spell it with is `$hatsu_root`, never `$CLAUDE_PLUGIN_ROOT` on its own**, because a skill body is mirrored
verbatim onto Codex and Cursor ([`docs/SURFACES.md`](SURFACES.md)) and `$CLAUDE_PLUGIN_ROOT` is Claude
Code's alone: **the harness exports it while a skill is running, and it is EMPTY in an ordinary tool-call
shell and inside a subagent** — verified live — and on the two other surfaces it is usually unset or, exported
from a shell profile, names a different plugin (`docs/ab/surfaces.md` § 8, F3). `$hatsu_root` is the
resolution [`hatsu-warmup`](../claude/skills/hatsu-warmup/SKILL.md) § 5's prelude runs on every surface,
each candidate accepted only if it is a Hatsu checkout, the winner canonicalised to an absolute path and
held in a shell variable that is not exported. **So a code block that uses `$hatsu_root` sets it in that
block** — `hatsu-warmup` § 0's resolver verbatim (`pr-state`, `futon`, `tensho`), or the one-line explicit
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
| the path the run was handed | `$hatsu-warmup <path>` on Codex, `/hatsu-warmup <path>` on Cursor (`docs/SURFACES.md` § 1's invocation row), or whoever raised the run |
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
report verbs (`rikugan`), `--no-push` and `conflicts[]` on `pr cascade-main` (`ao`, `murasaki`),
`wc squash` (`aka`), `shu test-report` (`tsukuyomi`), `shu evidence` (`kotoamatsukami`, `shibari`),
`shu coverage --touched` with the ladder (`gyo`), `pr edit-body` (`shibari`), the forbidden-trailer refusal
in `commit format` (`kokusen`), `nen/workflow.json` validation and `notifications.turn` (`breath`,
`jutaisho`), `stop --mark`, `surface mirror generate|check`, step `stdoutTo`, precondition `port` and
`repo resolve`'s exit-`2` no-registry refusal — all of them are verbs in the pinned binary, each verified
live and recorded in the matching `docs/ab/<skill>.md` under *Retired at nen 0.5*.

**What is still residue, and why:**

| Residue | Where | Why it is still residue |
|---|---|---|
| the push itself — `git push [-u] origin HEAD` | `aka`, `murasaki` | `pr cascade-main` pushes only what it merged itself; there is no push verb |
| `git rebase origin/<base>` | `ao` | the cascade verb *"merges (never rebases)"* by its own `--help` |
| the merge/rebase commit — `git commit --file`, `git rebase --continue` | `ao`, `kokusen` | `commit format` formats; nothing in nen commits |
| `gh pr create` | `shibari` | `nen pr` carries nine subcommands and `create` is not one |
| showing both sides of a conflict — `git show :1:|:2:|:3:` | `ao` | `conflicts[]` names the commits, not the content |
| the marker's SHAPE — `hatsu.stop-marker/v0.1` | `jutaisho` | `nen stop --mark` writes a poorer document with no `title`, `sound` or `rungs`, and **replaces** the file; adopting it would ring the generic line on every gate. Kept deliberately |
| removing the marker on a hookless surface | `jutaisho` | `--mark` writes and never removes |
| a coverage tool's own exclusions | `gyo` | `--touched` narrows the rows nen parsed; it cannot know what was never instrumented |
| embedding a capture as a `data:` URI | `rikugan` | no verb turns a PNG into one |
| the Artifact publish | `rikugan` | the surface's tool, not a deterministic step nen owns |
| a `.xcresult` with no declared extraction step, and a Playwright HTML report | `tsukuyomi`, `kotoamatsukami` | `test-report` reads a **declared** summary; nen opens no result bundle itself |
| placing a surface mirror into a target repository, and `info/exclude` | `hatsu-warmup` | `--out` is a path, not a deployment; an exclude file is one working copy's property |
| an artifact's size, freshness and checksum | `susanoo` | nen reports a declared artifact's existence and nothing more |
| `git push`/`git commit` guards on the trunk | `hooks/` | harness hooks, not nen-owned steps |

**A residue lapses when the pin moves and a verb arrives for it** — and a missing verb is a finding to
file, never a gap to route around.

Skill availability follows the same honesty: `breath`, `rasengan`, `kokusen`, `amaterasu`, `tsukuyomi`,
`rikugan`, `jutaisho`, `ao`, `aka` and `ren` shipped at Hatsu **`v0.4.0`**. **`v0.5.0` adds the PR side of
§ 5** — `mukai`, `murasaki`, `hanten`, `gyo`, `kotoamatsukami`, `shibari`, `en` and `jujutsu`, plus the
`drive` → `sharingan` rename — and the three agent definitions it needs: Feitan, Chrollo and Illumi.
**`v0.6.0` closes the release side**: `susanoo` (archive and packaging), `kagutsuchi` (non-production
upload, per target) and `mugetsu` (publication, per target, **G3**) are skills now, so **four of § 4's
five human-called phases have files** — `aka`, `mukai`, `kagutsuchi`, `mugetsu`. The fifth is **the
merge**, and it stays a rule with no file: **G2** is an action no agent performs, so there is no
procedure to write down. The rule that held while the other four had no file still holds and always did:
**a phase boundary is the governance, not the file** — name the phase and stop there whether or not
something has been written for it.

**`v0.7.0` adds no skill and adds two surfaces.** The same thirty-eight skills and eight personas are now
also generated into Codex and Cursor layouts under `surfaces/`, placed into a target repository by the
warm-up, checked for drift by [`scripts/surface_mirror_check.sh`](../scripts/surface_mirror_check.sh), and
documented in [`docs/SURFACES.md`](SURFACES.md). **Two things a surface does not have are named rather than
assumed**: Codex and Cursor have no turn-end hook (§ 6), and Codex has no in-session subagent (§ 2 →
`models`). **RETIRED at nen `0.5`: the mirror's own generator is in the pinned binary.**
`nen surface mirror generate|check` runs at `v0.5.0` — `scripts/surface_mirror_check.sh` exits `0` with
`codex ok: 40` and `cursor ok: 47` — so the CI job runs a real check instead of skipping with a notice. The
mirrors stay committed, for the original reason: the warm-up installs what is on disk rather than
regenerating anything in a target repository.


## Focused selection adoption and reviewer identities

[Nen #207](https://github.com/zheref/nen/issues/207) tracks a reusable declared test-selection
mapping. Nen 0.8.0 has no selector passthrough. A static focused lane with real runner identifiers
and separate artifacts is the current supported path; KroApple's apple-device Python tests do not
cover Swift behavior, and its all-KroTests apple row cannot substitute for scoped execution.
Do not proliferate permanent lanes per ad hoc selection or copied consumer scripts. The shared
capability and its consumer adoption remain explicitly pending.

The maintainer named Copilot and `zheref` as the only expected reviewers for Hatsu and Nen on
2026-09-12. Their `nen/gates.json` files record those identities and reserve approval for `zheref`.
No third-party reference gate applies. A maintainer-authored PR cannot be given a synthetic
self-approval by an agent: if GitHub cannot supply the required human review, report that predicate
unmet and leave the merge decision with the maintainer. Local subagent review is evidence, not a
GitHub vote.


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

Every PR author lists every addressed issue in the body and verifies each Development association,
including all issues in a combined PR. Scope changes trigger reconciliation of that full set.
Dependencies are listed separately. Closing clauses reflect completed issue scope; partial work
must not be silently closed merely to obtain a sidebar link. Shibari owns the procedure and the
GitHub auto-close caveat; build and sharingan enforce it at handover.
