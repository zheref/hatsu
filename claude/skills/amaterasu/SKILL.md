---
name: amaterasu
description: Build and start the app for the declared launch target from the maintainer's core working directory — never from a worktree — and hand back the exact command that did it, copied verbatim out of the dry run. Runs as phase four of `ren` on every turn that produced a change worth looking at; invoke `hatsu:amaterasu [<target>]` by name to relaunch or to switch targets. A disconnected device is reported by its declared name and falls back only to the declared simulator; a session working in a worktree reports the command instead of running it.
---

# Amaterasu — the flame that lands where it was aimed: the app, running, on your machine

**Nature: Transmuter** carries every run: amaterasu executes declared machinery — a lane's `dev` row,
a device probe, the install-and-launch steps a declaration names — and starts a long-running local
process. It writes no code and it sends nothing anywhere: a **deploy** reaches other people's users
and lives behind **G3**, and amaterasu is not that (§ 8).

> **Build the thing I am working on and start it on the target I said, from the directory I actually
> work in, and tell me the exact command so I can run it myself.**

Amaterasu is **automatic**: phase four of `ren`, after [`hatsu:kokusen`](../kokusen/SKILL.md) and
before the turn's report. It is not human-called, though the maintainer may name a target when they
invoke it directly. It never pushes and never opens anything.

---

## 1. Invocation

```
hatsu:amaterasu [<target>]        # <target> names a key of nen/contract.json → project.launch
```

With no argument the target is `nen/workflow.json → launch.default`. **There is no built-in default
target and none is ever guessed** — the same rule nen states for its own `--target` (*"required and
has no default, not even when exactly one exists"*), for the same reason: launching the wrong build
onto the wrong device is not undone by launching it again.

### The no-launch case — a repository that is not an application

**`project.launch` absent, or `launch.default` `null`, is a declaration, not a gap.** Some
repositories have nothing to start: Hatsu itself is a plugin read by Claude Code, and its
`nen/workflow.json` says `"launch": { "default": null, "fallback": null }` for exactly that reason.
`ren` still reaches this phase every turn, and **the phase does not ask the maintainer anything**:

> Record **`no launch target declared; skipped`** in the turn's report — the phase, the fact, the
> file that says so — and **continue to [`hatsu:rikugan`](../rikugan/SKILL.md) and
> [`hatsu:jutaisho`](../jutaisho/SKILL.md)**. No question, no stop, no bell.

Concretely, in order:

| What the declaration says | What amaterasu does |
|---|---|
| `project.launch` **absent** (no launch block at all) | record `no launch target declared; skipped`, name `nen/contract.json` as the file that carries no `project.launch`, continue |
| `project.launch` present but **empty** | the same — an empty map declares no targets |
| `launch.default` **`null`** and no argument | record `no launch target declared; skipped`, name `nen/workflow.json → launch.default` as the null, continue |
| `launch.default` **`null`** but `project.launch` **has targets**, and no argument | **this** is the case that asks: list what `project.launch` declares and ask which one. A repository with targets and no default has an unanswered question, not an answered one |
| an argument naming a target that `project.launch` does not declare | refuse by name, list what is declared, continue — never launch a near-match |

**Asking on the no-launch case is the defect.** A question every single turn, in a repository whose
configuration already answered it, trains the maintainer to dismiss the one phase that would
otherwise be worth reading — and `ren` is automatic, so the cost is per turn, not per effort.

## 2. The parameters, and where they come from

| Value | File → key |
|---|---|
| The default target | `nen/workflow.json` → `launch.default` |
| Where a disconnected device falls back to | `nen/workflow.json` → `launch.fallback` (a target name, or `null`) |
| The targets that exist | `nen/contract.json` → `project.launch` (a map of target name → row) |
| Which verb the target runs | `project.launch.<target>.verb` (`dev`, ordinarily) |
| Extra argv for that verb | `project.launch.<target>.args` |
| The device to resolve | `project.launch.<target>.device` — `name`, `kind` (`simulator` marks one), and `resolve` (`{exe, argv}`, the probe) |
| What happens after the build | `project.launch.<target>.after[]` — steps carrying `{device.id}` and `{artifact}` |
| The verb's real command line | `nen/contract.json` → `project.verbs.<lane>.<verb>` |
| Where it runs, and what it produces | `project.lanes.<lane>.cwd`, the row's `artifacts` (`{artifact}` is the **first** entry) |

**When `nen/workflow.json` is absent, say so in the turn's report, in these words —** *"no
workflow.json: using the built-in defaults from `docs/WORKFLOW.md`"* — and note what that costs
here: the defaults carry **no** `launch.default` and **no** `launch.fallback`, because neither has a
safe built-in value. With no workflow file but a `project.launch` that declares targets, name them
and ask which one; **with no `project.launch` either, this is § 1's no-launch case** — record
`no launch target declared; skipped` and continue, and where the lane does declare a plain `dev`
row, run § 5's dry run and paste the command as the thing the maintainer could start by hand.

**`project.launch` is Hatsu's key, not nen's, at this pin.** nen `0.3.0` preserves it and reads it by
nothing — verified live: with a `launch` block present, `nen schema check` still reports
`ok nen/contract.json project (1 lane: app; 4 verbs; 1 toolchain entry)` and every `shu` verb behaves
exactly as before (`docs/ab/amaterasu.md` § 2.4). So every part of the block below that nen does not
execute is executed by this skill, by hand, and named as residue (§ 7).

## 3. The core working directory, never a worktree

**A launch runs from the maintainer's own checkout — the directory they have open — and from nowhere
else.** Not a `git worktree`, not a subagent's isolated copy, not a temporary clone.

The reason is not tidiness. A launch is the one phase whose output is a thing on the maintainer's
desk: a simulator with an app in it, a dev server on a port, a window they are about to click. Built
from a worktree it is a *different* build of a *different* tree racing the one they are looking at —
same port, same derived-data directory, same bundle id installed onto the same device — and the app
they end up testing is not the one anybody reasoned about.

**nen will not stop you.** Verified live: `nen shu dev --repo <a worktree of the fixture> --dry-run`
renders the declared row with `cwd:` set to the worktree and no warning of any kind
(`docs/ab/amaterasu.md` § 2.5). The rule is therefore this skill's to keep, and it is kept two ways:

- **Resolve the core working directory explicitly** and pass it as `--repo`. It is the checkout the
  maintainer's session is standing in; a path under `.claude/worktrees/` (or any path `git rev-parse
  --git-common-dir` shows belongs to another checkout) is **not** it — that check is residue, § 7.
- **A parallel subagent effort never launches.** A subagent working in its own worktree reports the
  command amaterasu *would* run — the § 5 dry-run argv, verbatim — and stops. One running app per
  machine, owned by the session the maintainer is talking to.

## 4. Resolving the device

Where the target declares a `device`, run its `resolve` probe **as declared** and match
`device.name` in what the probe printed:

```bash
# exactly project.launch.<target>.device.resolve.{exe,argv} -- e.g. a declared
# xcrun devicectl / adb devices / simctl list invocation. Never a command line typed from memory.
```

| Outcome | What amaterasu does |
|---|---|
| The named device is present | take its id, substitute `{device.id}` into the `after` steps (§ 6) |
| The named device is **absent** | **Report it by name** — "`<device.name>` is not connected; the probe saw: `<what it listed>`" — then fall back to `workflow.json → launch.fallback`, which is a target whose `device.kind` is `simulator`. Say the fallback was taken and which target it was |
| Absent, and `launch.fallback` is `null` | say so and stop. Not a gate: a device nobody plugged in is a fact, and picking a different one is a guess |
| The target declares no `device` at all | nothing to resolve — a desktop or web lane, § 5 straight through |

**Never refuse-by-shape and never match loosely.** The declared name is the whole test: a probe
listing three devices none of which is the declared one is an absent device, not "close enough."
Pairing a device that has never been set up is `hatsu:jujutsu`'s work, not this skill's.

## 5. The dry run, and the command you paste

**This section runs only when a target was resolved.** On § 1's no-launch case there is nothing to
dry-run: record `no launch target declared; skipped` and go to rikugan.

```bash
nen shu <verb> --repo <core working directory> [--lane <lane>] --dry-run          # the pre-flight, as text
nen shu <verb> --repo <core working directory> [--lane <lane>] --dry-run --json   # the same, as one document
```

The dry run prints the exact argv, the cwd, the env **names** and the declared artifacts and spawns
nothing. **The command amaterasu pastes into the turn's report and into chat is that `would run:`
argv, verbatim** — copied, not re-typed, not prettified, not turned back into the package script it
came from. That is the whole contract of the paste: what the maintainer runs by hand must be
byte-identical to what this skill ran, and the dry run is the only rendering that guarantees it
(*"the argv printed is the argv that would be spawned, from the same rendering"*).

Then start it:

```bash
nen shu <verb> --repo <core working directory> [--lane <lane>]
```

`dev` and `run` are **long-running**: nen inherits the terminal and hands it to the child. So
`--json` without `--dry-run` is refused at exit `2` — verified live, with the reason (*"a --json report
would be one object followed by however much the child then writes"*) — and `--dry-run --json` is the
machine-readable pre-flight (`docs/ab/amaterasu.md` §§ 2.2–2.3). Do not background the launch to get
the terminal back; say the app is running and what is holding the terminal.

**Reactions, by exit code** (`claude/agents/kurapika.md` § *The `shu` verbs*): `1` is a failed build —
hand it to [`hatsu:rasengan`](../rasengan/SKILL.md), do not relaunch; `2` is usage or an unsatisfied
precondition, named; `3` is a host the declaration excludes — **G5**, never a retry; `4` is a seat
(the lane declares no `dev`) — quote the declaration's own words and run the repository's documented
command, saying that you did; `5` is the program not on `PATH` — `nen shu tools --repo <path>` and
relay the per-tool remedy.

## 6. The after-steps

A declared `after[]` — install the artifact onto the device, launch the bundle id, open the `.app` —
runs **after** the verb, in order, with `{device.id}` from § 4 and `{artifact}` from the verb row's
first `artifacts` entry substituted. At nen `0.3.0` **nen does not run these**: `--target` is not a
flag `shu dev` accepts, so there is no verb that reads `project.launch` at all (§ 7). Run each step
exactly as the declaration writes it — `exe` plus `argv`, no shell, no expansion, no improvised
extra argument — print each one, and say plainly that these ran by hand rather than through a verb.

## 7. Residue — what has no verb at nen `0.3.0`

- **`--target` on a launch verb does not exist.** Verified live: `nen shu dev --target sim --dry-run`
  refuses at exit `2` — *"--target is not read by 'shu dev'. A flag accepted and ignored is worse than
  one refused: the ignored thing is the instruction you gave"* — and `--target` on `shu deploy` is a
  different thing entirely (a G3 destination). So the whole of `project.launch` is executed by this
  skill: resolving the target, the device probe and its name match, appending `args`, and the `after`
  steps with their substitutions. Each one is stated in the report as run by hand.
- **`{device.id}` / `{artifact}` substitution** is this skill's string work, from the probe's output
  and the verb row's declared `artifacts` — nen substitutes placeholders only inside the rows it
  itself executes.
- **The core-working-directory check** (§ 3). No verb knows what a "core" checkout is; `nen shu dev`
  runs wherever `--repo` points, worktree included, verified live. The check is
  `git rev-parse --git-common-dir` against the session's own checkout, by hand, named here.
- **Reading `nen/workflow.json`** — no loader and no `nen schema check` row at this pin
  ([`hatsu:breath`](../breath/SKILL.md) § 2). `launch.default` and `launch.fallback` are read as data.
- **Stopping the app.** Nothing in nen stops a long-running child; the terminal is the control.

## 8. Authority

- **Permitted:** run the lane's declared build/`dev` row from the core working directory, run a
  declared device probe, run the declared `after` steps, and hand back the exact command.
- **Not permitted:** `nen shu deploy --run` in any form — a deploy's blast radius is other people's
  users and it stays behind **G3** on the maintainer's explicit, per-target word. Also: no push, no
  commit, no PR, no label, no release, and no launch from a worktree or a subagent effort (§ 3).
- **Not a gate event.** A disconnected device with no declared fallback is a stop-and-say, not a gate;
  an unsupported host (exit `3`) is the one **G5** this skill raises.

## 9. Hard limits

- **Never launches from anything but the core working directory** — never a worktree, never a
  subagent's copy, never a clone made for the occasion.
- **Never launches from a parallel effort.** A subagent reports the command; it does not run it.
- **Never invents a target.** No `launch.default` and no argument, but `project.launch` declares
  targets → name what exists and ask.
- **Never asks when the declaration already answered.** `project.launch` absent or empty, or
  `launch.default` `null` with no targets declared, is `no launch target declared; skipped` in the
  turn report and straight on to rikugan — every turn, without a question (§ 1). `ren` is automatic,
  so a question here is a question per turn.
- **Never substitutes a plausible command for a declared one**, and never re-types the pasted command
  from memory — it is the `--dry-run` argv, verbatim, or it is not pasted.
- **Never falls back to an undeclared device**, and never silently: the disconnected device is named,
  and so is the fallback taken.
- **Never runs a deploy**, with or without `--run`. That is G3 and it is not this phase.
- **Never claims the app is running** on the strength of a dry run, or on an exit code it did not read.
