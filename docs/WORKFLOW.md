# The way of working

How a request becomes a merged pull request, and where every parameter of that journey is written down.

This document is the **authority on the two configuration files** and on the phases that read them. The
skills under [`../claude/skills/`](../claude/skills/) are the authority on what each phase *does*;
[`ROSTER.md`](ROSTER.md) is the authority on who exists. Where this document and a configuration file
disagree, **the file wins and this document is the bug** — the same rule
[`../nen/contract.json`](../nen/contract.json) already states for itself.

---

## 1 · Two files, and the line between them

There are exactly two configuration files, and the split is not stylistic. It is the difference between a
**fact about the machine** and a **decision about the work**.

| | [`nen/contract.json`](../nen/contract.json) → `project` | [`nen/workflow.json`](../nen/workflow.json) |
|---|---|---|
| **Answers** | *How is this repository built, tested, linted, launched and shipped?* | *How do we work in it?* |
| **Content** | lanes, per-verb argv, preconditions, hosts, deploy targets, launch targets, evidence globs, host toolchain | branch shape, which declared verbs run per iteration, the coverage ladder, reports, notifications, commit trailers, monitor caps, the model matrix |
| **Executed by** | `nen shu <verb>` — nen spawns exactly what is declared and nothing else | nobody. It is **read**, and the reader decides |
| **Changing it changes** | what runs on this machine | what the roster is willing to do |
| **Validated by** | `nen schema check` (the `nen/contract.json` row), today | `nen schema check` (a new row), **from nen `0.4.0`** |

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
| `checks` | `["build"]` | `rasengan`, before **every** commit |
| `lane` | `project.defaultLane` | `rasengan`, passed through as `--lane` |

Each entry of `checks` is the **name of a declared verb**, not a command line: `rasengan` runs
`nen shu <check> --lane <lane>` for each, in order. A verb named here that the lane seats as unsupported is
exit `4` and its seat is quoted, not worked around. Hatsu's own `checks` is `["lint"]`, because
`claude plugin validate . --strict` is the only mechanical check a markdown-and-bash plugin has.

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
| `scope` | `touched` | line coverage of the files in `git diff --name-only <base>...HEAD`, **not** the repository total |

Three numbers rather than one, because a single threshold turns into either a gate that blocks honest work or
a number nobody looks at. The ladder reports bands and stops only at the bottom rung. **The bar is never
lowered to clear it** — that is the one move `gyo` will not make, and a repository that cannot honestly reach
`minimum` is a G5, not a smaller number.

`nen shu coverage --threshold <n>` **reports** `met: true|false` and never changes its exit code; nen does not
decide whether a number is good enough. From nen `0.4.0`, `--touched --base <ref>` filters the rows and the
ladder here supplies the default threshold.

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
value settles it. **`turn` is an addition to the `nen.workflow/v0.1` shape** and the schema must admit it
when the loader lands at nen `0.4.0` — recorded in
[`claude/skills/jutaisho/SKILL.md`](../claude/skills/jutaisho/SKILL.md) § Residue.

### `commits`

```json
"commits": { "allowedAttributionTrailers": ["Akatsuki-Agent"],
             "forbiddenTrailers": ["Co-Authored-By", "Claude-Session", "Signed-off-by"] }
```

**The maintainer's ruling of 2026-09-09: no AI attribution trailer is ever recorded.** `Akatsuki-Agent:` is
the single admitted trailer, and it is admitted precisely because it is not AI attribution — it names *the
system's own* provenance, which agent of this roster did the work, rather than a model claiming authorship of
it. This supersedes the earlier clause, in every agent definition, that treated the harness mandate as
binding and left the question to the P3 constitution.

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

**Enforcement is three-layered, and only the first layer ships in this plugin.**

| Layer | What refuses | Where it lives | Live at nen `0.3.0`? |
|---|---|---|---|
| **(a)** the **skills'** own refusal — `kokusen` reads the rendered message before it commits, `aka` before it squashes | agent-side | this repository | **yes**, and it is the layer Hatsu ships |
| **(b)** the target repository's **`commit-msg` hook**, generated from `allowedAttributionTrailers` by `nen scaffold init` | the target repository's `.git/hooks/` | **nen `0.4.0`** — in flight this week in `zheref/nen`; KroApple and kro-pwa already carry one | **target-dependent** |
| **(c)** **`nen commit format --repo`** refusing a trailer not on the allow-list | nen | **nen `0.4.0`** | **no** — `0.3.0` renders any `--trailer` it is given, verified live (`docs/ab/aka.md` § 2.2) |

So **at the pinned `0.3.0` layers (b) and (c) are target-dependent**: a repository scaffolded by a nen that
writes the hook has a mechanical refusal, and one that has not — this repository included — has the
agent-side refusal and nothing under it. A raw `git commit --file` carrying `Co-Authored-By` on a feature
branch is caught by (a) only. Say which layers a given repository actually has; a rule described as
mechanical where it is not is worse than one described honestly.

There is **no `Akatsuki-Run:` trailer** anywhere on this plane: Hatsu is local, and there is no CI run to
name. Adding one would forge a machine-plane provenance the local plane does not have.

From nen `0.4.0`, `nen commit format --repo <path>` reads these two lists and refuses a trailer not on the
allow-list; at `0.3.0` the refusal is the skill's, plus whatever `commit-msg` hook the target repository
happens to carry.

### `monitor`

```json
"monitor": { "maxCycles": 20, "pollSeconds": 300 }
```

`en`'s `izanagi` cap and its poll interval. **The cap is grammar, not a default**: a watch loop invoked
without one does not run, exactly as [`izanagi`](../claude/skills/izanagi/) refuses an invocation with no
`up to <N>`. § 5 is where both keys are actually spent, and where the long watch hands over to Illumi.

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

---

## 3 · `project.launch` and `project.evidence`

Two extensions to nen's `project` block. **At nen `0.3.0` both are preserved verbatim by the loader and read
by nothing in nen** — the same treatment every Hatsu-authored key in `nen/contract.json` already gets — so
declaring them today is safe and `nen schema check` stays `ok`. **From nen `0.4.0` they are executed**:
`launch` by `nen shu dev|run --target <name>`, `evidence` by `nen shu evidence --base <ref>`.

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
  "sim": { "verb": "dev", "device": { "name": "iPhone 17 Pro", "kind": "simulator" } }
}
```

Each key is a **named target**. `verb` is the lane verb to run; `args` are appended to its argv; `device`
declares how to find the device and how it is named; `after` is the steps that install and start what the
verb built. Two placeholders substitute: `{device.id}` from the `resolve` probe's output matched on
`device.name`, and `{artifact}` from the first entry of the verb's `artifacts`.

Three properties are the point of declaring it rather than typing it:

- **No toolchain name lives in nen.** `xcrun`, `adb` and `open` appear here, in the target repository's own
  file, and never in nen's execution modules — nen's `purity.test.ts` enforces exactly that.
- **`--target` is required, with no default, ever.** A launch with no named target does not happen.
- **A device is refused by name.** When the `resolve` probe does not see `device.name`, the refusal *lists
  what the probe did see*, which is the difference between a useful error and a shrug.

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

`breath` (first turn of an effort) → `rasengan` (build) → `kokusen` (commit) → `amaterasu` (launch) →
`rikugan` (the turn's report) → `jutaisho` (the bell).

It loops. **It never pushes and never opens a pull request.**

**Five phases are the maintainer's to call, and no agent ever prompts for them:**

| Phase | What it does | Why it is the human's |
|---|---|---|
| [`aka`](../claude/skills/aka/) | tests → squash the unpushed commits → `ao` → push | publishing work is a decision, and a squash is destructive |
| [`mukai`](../claude/skills/mukai/) | `murasaki` → `hanten` review → tests + UI tests → `gyo` → evidence → `shibari` opens the PR → starts `en`. **§ 5 is the full shape** | a PR is a request for other people's attention |
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
| **1** | [`murasaki`](../claude/skills/murasaki/) | pull + push: [`ao`](../claude/skills/ao/) → [`rasengan`](../claude/skills/rasengan/) + [`tsukuyomi`](../claude/skills/tsukuyomi/) → push, **only if the branch is already published**. Never squashes, never force-pushes | **G5** on a *semantic* conflict in `ao` — a mechanical one is resolved |
| **2** | [`hanten`](../claude/skills/hanten/) | the adversarial review: classify the change set by scope, one reviewer subagent per scope | **G5** on an unsettled finding — after Kurapika has fixed it or pushed back with a reason |
| **3** | `tsukuyomi` + [`kotoamatsukami`](../claude/skills/kotoamatsukami/) | `tests.required` (+ `extra`), and the declared `ui-test` where a repository declares one. Re-recorded snapshots feed step 6 | **G5** on red required tests. A seat (exit `4`) is quoted, never routed around |
| **4** | [`gyo`](../claude/skills/gyo/) | the coverage bar, against the `coverage` ladder of § 2 | **G5** when a touched file is under `minimum` and cannot honestly clear it |
| **5** | [`kokusen`](../claude/skills/kokusen/) then the push half of `murasaki` | **publishes what steps 2–4 changed.** The review's fixes and gyo's new tests are edits to the working copy, and neither of those skills may commit or push; step 7 refuses to open a PR while `HEAD` is ahead of `origin/<branch>` | **G5** on a semantic conflict where the base moved again |
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
line coverage** — the files in `git diff --name-only <base>...HEAD`, never the repository total — and reports
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
reviewers. **`nen pr edit-body` does not exist at the pinned `0.3.0`** — the residue is `gh pr edit
--body-file`, named as residue in the skill rather than improvised (§ 7).

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
| `maxCycles` | the `izanagi` cap on the watch. **Grammar, not a default** — a watch invoked without one does not run |
| `pollSeconds` | the interval between observation cycles. Never shortened because something looks close, never lengthened to stretch the cap |

**An exhausted cap is reported as exhausted.** It is never extended in place, never continued by a second
watch started to finish the first, and never rendered as "still watching". Raising the cap is the
maintainer's word, in a new invocation.

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
quoted in a form it cannot recover, *including a second quoted `-C` on one segment*; a `git` segment carrying a
`commit`/`push` token alongside a **global option the guard does not know** — an unknown `-…` may or may not
swallow the token after it, so it is named in the refusal rather than walked past; a `git` segment whose
subcommand the option walk could not establish for any other reason; and a shell wrapper whose payload cannot
be read on a line that carries a write token. The script's own header carries the fifty-one cases this was
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

---

## 7 · What is not here yet

At nen **`0.3.0`**, several deterministic steps in the loop above have **no verb**, and each is named as
**residue** in the skill that carries it rather than quietly improvised: build proof and the stall guard
(`rasengan`), `--target` on `shu dev` (`amaterasu`), all three report verbs (`rikugan`), `--no-push` and
`conflicts[]` on `pr cascade-main` (`ao`), `wc squash` (`aka`), `shu test-report` (`tsukuyomi`),
`shu evidence` (`kotoamatsukami`), `shu coverage --touched` (`gyo`), `pr edit-body` (`shibari`), and the
forbidden-trailer refusal in `commit format` (`kokusen`). **A residue lapses when the pin moves and a verb
arrives for it** — and a missing verb is a finding to file, never a gap to route around.

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
