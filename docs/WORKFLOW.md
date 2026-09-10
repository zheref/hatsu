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
`tsukuyomi` reports that rather than inventing a runner. A test is never patched to pass.

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
Hatsu's own are both `null`: a plugin is loaded by Claude Code, not launched.

### `reports`

```json
"reports": { "dir": "Reports", "retain": "final-only", "template": "rikugan",
             "captures": "Reports/captures" }
```

| Key | Default | Meaning |
|---|---|---|
| `dir` | `Reports` | **git-ignored.** The only directory a report is ever written to |
| `retain` | `final-only` | **the retention rule** — see below |
| `template` | `rikugan` | `templates/<name>.html` in this repository |
| `captures` | `Reports/captures` | where screenshots land before they are inlined as data URIs |

**The retention rule.** `rikugan` runs at three moments — every turn, at landing, and once after the merge —
and `retain: final-only` means **only the last one is written to disk**. The per-turn and landing reports are
published to the conversation and nowhere else. A directory holding one report per turn is a directory nobody
opens; the final report is the one with tests run, scenarios, touched coverage and the architecture delta, and
it is the one worth finding six months later. `dir` is git-ignored for the same reason a build output is: it
is derived, and a derived file in git is a merge conflict waiting to be resolved by coin toss.

### `notifications`

```json
"notifications": { "rungs": ["push", "os", "sound"], "sound": "Glass" }
```

`jutaisho`'s ladder, innermost first: `push` is the surface's own turn-complete signal, `os` an OS
notification, `sound` a system sound. **A rung absent from the list is not rung.** `sound` names
`/System/Library/Sounds/<sound>.aiff` on macOS. See § 5 for who actually rings rungs 2 and 3.

### `commits`

```json
"commits": { "allowedAttributionTrailers": ["Akatsuki-Agent"],
             "forbiddenTrailers": ["Co-Authored-By", "Claude-Session", "Signed-off-by"] }
```

**The maintainer's ruling of 2026-09-09: no AI attribution trailer is ever recorded.** `Akatsuki-Agent:` is
the single admitted trailer, and it is admitted precisely because it is not AI attribution — it names *the
system's own* provenance, which agent of this roster did the work, rather than a model claiming authorship of
it. A harness that mandates `Co-Authored-By:` is **configured off** (`includeCoAuthoredBy: false` in the
Claude Code settings) **and the commit-msg guard refuses the trailer regardless of what any harness
mandates**. The setting is the convenience; the guard is the rule, and a rule that only holds while a setting
is right is not a rule. This supersedes the earlier clause, in every agent definition, that treated the
harness mandate as binding and left the question to the P3 constitution.

There is **no `Akatsuki-Run:` trailer** anywhere on this plane: Hatsu is local, and there is no CI run to
name. Adding one would forge a machine-plane provenance the local plane does not have.

From nen `0.4.0`, `nen commit format --repo <path>` reads these two lists and refuses a trailer not on the
allow-list; at `0.3.0` the refusal is the skill's and the guard's.

### `monitor`

```json
"monitor": { "maxCycles": 20, "pollSeconds": 300 }
```

`en`'s `izanagi` cap and its poll interval. **The cap is grammar, not a default**: a watch loop invoked
without one does not run, exactly as [`izanagi`](../claude/skills/izanagi/) refuses an invocation with no
`up to <N>`.

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
| `aka` | tests → squash the unpushed commits → `ao` → push | publishing work is a decision, and a squash is destructive |
| `mukai` | `murasaki` → `hanten` review → tests + UI tests → `gyo` → evidence → `shibari` opens the PR → starts `en` | a PR is a request for other people's attention |
| **merge** | **G2** (`CON-5`) | never delegated, by any agent, anywhere |
| `kagutsuchi` | a non-production upload, **per target** | the blast radius leaves this machine |
| `mugetsu` | publication, **per target**, **G3** (`CON-6`) | the blast radius is other people's users |

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

## 5 · The hooks

[`../hooks/hooks.json`](../hooks/hooks.json) carries two Claude Code hooks. **Neither is a nen-owned step.**
They are executed by the harness *around* a session rather than by a skill *inside* one, and they exist for
the two things a skill structurally cannot do: a skill only runs when the model calls it, and by the time the
model has stopped talking, or has already typed the push, it is too late.

| Hook | Event | What it does |
|---|---|---|
| [`stop-bell.sh`](../hooks/stop-bell.sh) | `Stop` | rings `notifications` rungs **2 and 3** off the marker at `.nen/last-stop.json`, then consumes it |
| [`guard-base-branch.sh`](../hooks/guard-base-branch.sh) | `PreToolUse`, matcher `Bash` | exits `2` — blocking the tool call — on a `git commit` or `git push` while the branch equals `branch.base` |

**The stop marker** is `hatsu.stop-marker/v0.1`, written by `jutaisho` and read by the hook:

```json
{ "contract": "hatsu.stop-marker/v0.1", "at": "<ISO-8601>", "gate": "G5",
  "title": "<one line>", "repo": "<name>", "report": "<url or path>" }
```

Freshness is taken from the **file's mtime**, not from `at`: comparing a timestamp inside a string needs a
date parser, and the mtime is the same fact without one. A marker older than ten minutes belongs to a stop
already seen, and is removed without ringing. Absence of the marker, a stale marker, a non-macOS host and a
missing `osascript` are each a silent exit `0` — a `Stop` hook runs after **every** turn, and a bell that
rings on a turn that was not a gate stop is a bell nobody hears any more. **Where no hook is installed,
`jutaisho` rings the bell itself and says that it did.**

Both scripts are POSIX `sh` and use **no `jq`, `yq` or Python** — Hatsu's installed path is one binary plus
`git` and `gh` — so they read their JSON with `sed`. Both **fail open** on anything they cannot read; the one
deliberate exception is the guard, which fails *closed* on the single comparison it can actually make.

`--no-verify` does not reach either of them: a harness hook is not a git hook.

**`hooks/hooks.json` is the plugin's default hook location and is discovered automatically — so
`.claude-plugin/plugin.json` must NOT also carry a `hooks` key pointing at it.** Verified live against Claude
Code `2.1.263`: a manifest key that resolves to the already-loaded default file is skipped as a duplicate,
logged as an internal error, and marks that plugin's hook load *failed* — visible only under `--debug`, and
**not caught by `claude plugin validate --strict`**, which passes either way. The manifest key exists for
*additional* hook files, and Hatsu ships none. `${CLAUDE_PLUGIN_ROOT}` in the two `command` fields resolves to
the installed plugin directory, which changes on every update, so it is never written as a literal path.

---

## 6 · What is not here yet

At nen **`0.3.0`**, several deterministic steps in the loop above have **no verb**, and each is named as
**residue** in the skill that carries it rather than quietly improvised: build proof and the stall guard
(`rasengan`), `--target` on `shu dev` (`amaterasu`), all three report verbs (`rikugan`), `--no-push` and
`conflicts[]` on `pr cascade-main` (`ao`), `wc squash` (`aka`), `shu test-report` (`tsukuyomi`),
`shu evidence` (`kotoamatsukami`), `shu coverage --touched` (`gyo`), `pr edit-body` (`shibari`), and the
forbidden-trailer refusal in `commit format` (`kokusen`). **A residue lapses when the pin moves and a verb
arrives for it** — and a missing verb is a finding to file, never a gap to route around.

Skill availability follows the same honesty: `breath`, `rasengan`, `kokusen`, `amaterasu`, `tsukuyomi`,
`rikugan`, `jutaisho`, `ao`, `aka` and `ren` ship at Hatsu **`v0.4.0`**. `mukai`, `murasaki`, `en`, `hanten`,
`gyo`, `shibari`, `jujutsu`, `kotoamatsukami`, `susanoo`, `kagutsuchi`, `mugetsu` and the `drive` →
`sharingan` rename arrive at **`v0.5.0`/`v0.6.0`**. Until a phase exists, **name it and stop there anyway** —
the phase boundary is the governance, and it holds whether or not a skill file has been written for it.
