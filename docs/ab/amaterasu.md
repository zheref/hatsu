# Evidence — `amaterasu` (new skill, Hatsu workflow fold-in)

`claude/skills/amaterasu/SKILL.md`: the launch — build and start the app for the declared target,
**from the core working directory**, and hand back the exact command, copied out of the dry run.

**Not a port, and the skill with the largest residue of the five.** `project.launch` is Hatsu's own
key; nen `0.3.0` preserves it and reads it by nothing, and there is no `--target` on a launch verb at
this pin. § 2 records what nen actually does, § 3 records everything the skill therefore does by hand.

**Run:** 2026-09-09/10 (local clock; the session crossed midnight), `nen 0.3.0` at `/Users/zheref/.local/bin/nen`; host `Darwin 25.4.0 arm64`,
`node v24.16.0`. Hatsu at `origin/main` `e158349`. Verbs were exercised against a **constructed**
throwaway git repository under this worktree's `.nen-fixture/` — one `nextjs` lane with a declared
`dev` row, later given a `project.launch` block with a `sim` and a `mac` target — plus a **git
worktree of that fixture**, created solely to prove § 2.5. Deleted before the commit. No launch was
started for real (`dev` is long-running and would have held the terminal); every run below is a dry
run or a refusal.

*Paths sanitized: this machine's absolute paths appear as `<fixture>` and `<fixture worktree>`.
Nothing is redacted — both repositories are public — and the transcripts are otherwise verbatim.*

---

## 1. The skill

| Step | Mechanism | Owner |
|---|---|---|
| 1 | Read `launch.default`, `launch.fallback` from `nen/workflow.json` | the skill, as data (§ 3) |
| 2 | Read the target row from `nen/contract.json` → `project.launch.<target>` | the skill — nen reads this key by nothing (§ 2.4) |
| 3 | Refuse to launch from a worktree | the skill (§ 2.5, § 3) |
| 4 | Resolve the declared device with its declared `resolve` probe | residue (§ 3) |
| 5 | Pre-flight — `nen shu dev --repo [--lane] --dry-run [--json]` | verb |
| 6 | Start it — `nen shu dev --repo [--lane]` | verb |
| 7 | The `after[]` steps, with `{device.id}` / `{artifact}` substituted | residue (§ 3) |
| 8 | Paste the `--dry-run` argv into the report, verbatim | the skill |

**Count.** Eight steps; **two are verbs**, four are residue and two are the skill's own rules. That
ratio is the honest state of a launch phase at nen `0.3.0`, and the skill says so rather than dressing
hand-run steps as verb output.

## 2. Verbs exercised live

### 2.1 — `nen shu dev --dry-run`: the command that gets pasted

```
$ nen shu dev --repo <fixture> --dry-run
lane:          app  (nextjs)
verb:          dev
host:          darwin -- supported (the declaration constrains no platform)
preconditions: (none declared)
would run:     node -e 'console.log('\''dev server on :3000'\'')'
cwd:           <fixture>
env:           (none added)
artifacts:     (none declared)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit
               code to report.
exit=0
```

The `would run:` line **is** the paste. nen's own guarantee is that this argv is rendered by the same
code path that spawns the real one — *"the thing you approve is the thing that runs"* — which is why
the skill's § 5 forbids re-typing it or converting it back into the package script it came from.

### 2.2 — `--json` on a long-running verb is refused, with the reason

```
$ nen shu dev --repo <fixture> --json
nen shu: 'dev' is long-running: nen inherits this terminal and hands it to the child, so stdout
belongs to that child and a --json report would be one object followed by however much the child then
writes. Pass --dry-run for the same pre-flight as one JSON document (it starts nothing), or drop
--json and read the pre-flight as text. The two long-running verbs are: dev, run.
Run 'nen shu --help'.
exit=2
```

So `--dry-run --json` is the machine-readable pre-flight for a launch, and there is no JSON document
for a launch that actually happened. The skill reports a running app in prose, and says what is
holding the terminal.

### 2.3 — `--target` does not exist on a launch verb

```
$ nen shu dev --repo <fixture> --target sim --dry-run
nen shu: --target is not read by 'shu dev'. A flag accepted and ignored is worse than one refused:
the ignored thing is the instruction you gave.
Run 'nen shu --help'.
exit=2
```

Refused before anything renders, and refused **the same way after `project.launch` was added to the
declaration** (§ 2.4) — the key changes nothing about which flags the verb accepts. `--target` at this
pin belongs to `nen shu deploy` and means a **deploy destination**, which is a G3 concern and not a
launch:

```
$ nen shu deploy --repo <fixture> --target sim
nen shu deploy: lane 'app' (nextjs) declares no 'deploy'. It declares: build, dev, lint, test. A verb
this repository has is a verb this repository states ...
exit=4
```

The fixture's `sim` **launch** target and a `deploy` target named `sim` are different things in
different blocks; nen only knows the second kind. Recorded because the flag name invites exactly that
confusion.

### 2.4 — `project.launch` is preserved and read by nothing

With the block added to the fixture's declaration:

```json
"launch": {
  "sim": { "verb": "dev", "device": { "name": "iPhone 17 Pro", "kind": "simulator" } },
  "mac": { "verb": "dev", "args": ["--host", "0.0.0.0"],
           "after": [ { "exe": "echo", "argv": ["opened", "{artifact}"] } ] }
}
```

```
$ nen schema check --repo <fixture>
repository: <fixture>
  FAIL  nen/labels.json    ... no such file ...
  FAIL  nen/repos.json     ... no such file ...
  FAIL  nen/colors.yml     ... no such file ...
  warn  nen/gates.json     ... no such file ...
  ok    nen/contract.json  project (1 lane: app; 4 verbs; 1 toolchain entry)
exit=1
```

```
$ nen shu dev --repo <fixture> --dry-run
lane:          app  (nextjs)
verb:          dev
would run:     node -e 'console.log('\''dev server on :3000'\'')'
...
exit=0
```

The contract row is **`ok`** with the unknown key present — counted as `1 lane: app; 4 verbs; 1
toolchain entry`, with no mention of `launch` — and the `dev` dry run is byte-identical to § 2.1's:
no `args` appended, no device resolved, no `after` step rendered. **Preserved, validated as
harmless, executed by nothing.** (The four `FAIL`/`warn` rows are the fixture's missing taxonomy
files, not the contract; the exit `1` is theirs.)

### 2.5 — nen will launch from a worktree, silently

A `git worktree` of the fixture, handed to the same verb:

```
$ git -C <fixture> worktree add <fixture worktree> -b fixture/wt HEAD
$ nen shu dev --repo <fixture worktree> --dry-run
lane:          app  (nextjs)
verb:          dev
host:          darwin -- supported (the declaration constrains no platform)
preconditions: (none declared)
would run:     node -e 'console.log('\''dev server on :3000'\'')'
cwd:           <fixture worktree>
env:           (none added)
artifacts:     (none declared)
exit=0
```

Exit `0`, `cwd:` pointing at the worktree, **no warning of any kind**. This is the whole basis for the
skill's § 3: the "core working directory, never a worktree" rule cannot be delegated to a verb,
because no verb has an opinion about it. It is the skill's to keep, and the check
(`git rev-parse --git-common-dir` against the session's own checkout) is residue.

### 2.6 — `nen shu tools`, for the exit `5` reaction

```
$ nen shu tools --repo <fixture>
lane:          app  (nextjs)
mode:          check
  ok       node  24.16.0  pinned >=18.0.0  (tested minimum 20.19.0)
exit=0
```

The remedy path a launch's exit `5` points at. Exit `5` itself was not reachable on this host without
removing the fixture's only declared tool; said, rather than claimed.

## 3. Residue

1. **The whole of `project.launch`.** No `--target` on `shu dev`/`shu run` (§ 2.3), and the key is
   read by nothing (§ 2.4). So the skill, by hand and stating it: picks the target from
   `workflow.json → launch.default` or the invocation; runs the declared `device.resolve` probe and
   matches `device.name` in its output; appends the target's `args`; and runs each `after[]` step as
   declared.
2. **`{device.id}` and `{artifact}` substitution.** nen substitutes placeholders only inside rows it
   executes itself. `{artifact}` is the first entry of the verb row's declared `artifacts`;
   `{device.id}` comes from the probe. Both are the skill's string work.
3. **The core-working-directory check** (§ 2.5). No verb knows what a "core" checkout is.
4. **The disconnected-device fallback.** `workflow.json → launch.fallback` is read as data; the
   fallback is taken by re-entering § 5 with the other target, and it is *said* — the absent device is
   named, the probe's list is quoted, and the fallback target is named.
5. **Stopping the app.** Nothing in nen stops a long-running child.
6. **Reading `nen/workflow.json`** — no loader and no schema row (`docs/ab/breath.md` § 2.6).

## 4. Findings against the binary

1. **`--target` means two different things one flag name apart** (§ 2.3). On `shu deploy` it is a
   G3-gated destination; on `shu dev` it is refused outright. Hatsu's `project.launch` wants a
   *launch* target, and the natural spelling for it is a flag that already exists on a sibling verb
   with an entirely different blast radius. Whoever lands `shu dev --target` should decide
   deliberately whether it shares the name — the refusal message at this pin is the right behaviour
   either way (*"a flag accepted and ignored is worse than one refused"*).
2. **`project.launch` validates as `ok` while being executed by nothing** (§ 2.4). Correct for an
   unknown key at `0.3.0` — the contract explicitly preserves what it does not read — but the
   `schema check` row (`project (1 lane: app; 4 verbs; 1 toolchain entry)`) reads as a complete
   inventory of the block and is not one. A repository could declare a malformed `launch` and be told
   its contract is `ok`; the skill therefore treats the block as unvalidated input and says so.
3. **Nothing distinguishes a worktree from the checkout it was cut from** (§ 2.5). For every other
   `shu` verb that is right — building in a worktree is the point of worktrees. For a *launch* it is
   the one place it is wrong, and nen has no way to know which it is being asked for. Recorded as the
   reason the rule lives in the skill and is stated twice (§ 3 and § 9).
4. **No JSON document for a launch that ran** (§ 2.2). Correct and well-argued in the refusal itself;
   noted because a caller wanting structured evidence of a launch has only the dry run, which is
   evidence of a plan.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| `--target` on a launch verb | `nen shu dev --repo <fixture> --target sim --dry-run` | `0` |
| appending `project.launch.<t>.args` by hand | the same call | `0` |
| `{device.id}` / `{artifact}` substitution by hand | the same call's `substitutes:` line | `0` |

```
$ nen shu dev --repo <fixture> --target sim --dry-run
lane:          app  (generic)
verb:          dev
target:        sim  (appends no argument)  -- on lane 'app', which this target declares
device:        iPhone 17 Pro (simulator)  -- id not resolved (nothing was probed)
preconditions:
  ok    port 59321 (expect free)
would run:     sh -c 'echo dev'
would run:     sh -c 'echo install {artifact} on {device.id}'
substitutes:   {device.id} <- 'iPhone 17 Pro' itself -- a simulated device is addressed by its name, so
               nothing is probed; {artifact} <- Reports/app.bin  (project.launch.sim.artifact, not the
               verb's own)
exit=0
```

Three things this transcript settles at once. **The after-step is nen's**, so § 6 no longer reports one
as by-hand. **`project.launch.sim.lane` is read before anything is rendered** — the `target:` line says
whose decision the lane was. And **`project.launch.sim.artifact` overrides the verb's first `artifacts`
entry**, which the `substitutes:` line states explicitly rather than leaving to be inferred; the
`artifacts:` line keeps reporting what the *verb* declares, because the two answer different questions.

Through `v0.4.0` the same invocation answered *"--target is not read by 'shu dev'"* at exit `2` (§ 2.4).
Note also the `port` precondition row above: a new precondition kind at this release, asserted by
connecting to `127.0.0.1:<port>` and destroying the socket, with `expect` **required** out of a closed
two-member set.
