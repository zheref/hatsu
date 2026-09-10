---
name: breath
description: Warm the local working copy once per effort — classify where the checkout sits, check the host toolchain, fast-forward the trunk and cut this effort's branch from its fresh tip, then prove the declared iteration checks still pass on it. Runs automatically as the first turn of an effort inside `ren`; invoke `hatsu:breath` by name only to re-warm a checkout that has drifted. It asks on exactly one thing — a dirty working copy — and never discards work it has not shown you, never commits, and never pushes.
---

# Breath — the first breath of an effort, taken before any work

**Nature: Transmuter** carries every run. A warm-up moves git state and probes a host toolchain; it
authors nothing, so it borrows no authorship nature from what follows. Whatever `ren`'s next phase
writes on the branch this skill cut is Enhancer, Conjurer or Transmuter work in its own right, and
that phase names it.

> **Before I write a line, put this checkout in a state where the line can be trusted: a fresh
> trunk, a branch of my own cut from it, a host that can build, and a green build to start from.**

Breath is **automatic**, not human-called: it is phase one of `ren`, taken on the **first turn of an
effort** and once per effort. Re-invoking it on a branch it already cut is not an error — it reports
what it finds and returns, because the branch check refuses a name that already exists rather than
reusing it.

---

## 1. Invocation

```
hatsu:breath [<descriptor>]              # descriptor: the branch's kebab slug; derived from the request when absent
```

No target-repository argument: breath warms **the checkout the session is standing in**, and every
`nen` call below passes it explicitly as `--repo <path>` rather than letting a verb default to the
process's cwd. `nen shu warmup` **requires** `--repo` for exactly that reason — it is the one `shu`
verb that mutates git state, and "wherever this process happens to be" is not an answer.

## 2. The parameters, and where they come from

Two files, read as data. Neither is guessed and neither is edited here.

| Value | File → key | Used for |
|---|---|---|
| Branch template | `nen/workflow.json` → `branch.template` | rendering `--branch` (§ 5) |
| Trunk / PR base | `nen/workflow.json` → `branch.base` | `--base` on `wc classify`, `--from` on `shu warmup` |
| The checks to prove | `nen/workflow.json` → `iteration.checks` | § 6, handed to [`hatsu:rasengan`](../rasengan/SKILL.md) |
| The lane they run in | `nen/workflow.json` → `iteration.lane` | `--lane` on every `shu` call |
| The lanes that exist | `nen/contract.json` → `project.lanes`, `project.defaultLane` | resolving that lane |
| The build itself | `nen/contract.json` → `project.verbs.<lane>.build` | what `shu warmup` runs after the cut |
| The host tools | `nen/contract.json` → `project.toolchain` | § 4 |

**When `nen/workflow.json` is absent, say so in the turn's report, in these words —** *"no
workflow.json: using the built-in defaults from `docs/WORKFLOW.md`"* — and use them:
`branch.template` = `{model}/{persona}/{descriptor}`, `branch.base` = `main`, `iteration.checks` =
`["build"]`, `iteration.lane` = the declaration's own `project.defaultLane`. Never invent a value a
default does not cover, and never write the file to make the message go away — authoring a
`workflow.json` for a repository is a policy change that lands as its own PR at **G4**.

**`nen` does not validate `nen/workflow.json` at the pinned ref.** Verified live: `nen schema check
--repo <path>` reports five rows — the four taxonomy files and `nen/contract.json` — and no
`nen/workflow.json` row at all (`docs/ab/breath.md` § 2.6). The file is read by this skill, by eye,
against the shape in `docs/WORKFLOW.md`; a malformed one is a finding to report, not a schema
failure anything will catch for you. That row arrives with nen `0.4.0`.

## 3. Where the checkout sits — read it, never assume it

```bash
nen wc classify --repo <path> --base <branch.base>
```

Exactly one of three cases, with the evidence printed (`claude/skills/tensho/SKILL.md` § 2 carries
the same table for its own phase):

| Case | What breath does |
|---|---|
| `on-branch-clean` **on the trunk** | The ordinary first turn. Go to § 4 |
| `on-branch-clean` **on a branch** | An effort is already warm. Report the branch and return — do not cut a second one |
| `must-move` — on the trunk, dirty | **The one thing breath asks about.** Show every uncommitted path and ask: carry the work onto the new branch (the ordinary answer — `git stash`, cut, `git stash pop`, each step named as residue in § 8), or stop so the maintainer can deal with it. **Never `--discard`** |
| `on-branch-dirty` | Uncommitted work on an existing branch. Not breath's to judge whether it is this effort: report the commit subjects and paths the verb printed, and hand the turn to [`hatsu:kokusen`](../kokusen/SKILL.md) or the maintainer |

A `--base` that does not resolve, or a detached `HEAD`, is **not** folded into a case: `nen wc
classify` reports it on stderr and exits non-zero, and breath stops there rather than warming
something it could not read.

## 4. The host, before the first build on it

```bash
nen shu tools --repo <path> --dry-run          # prints every probe, spawns nothing
nen shu tools --repo <path>                    # the check; exit 5 names, per tool, the fix
nen shu tools --repo <path> --install          # only what corepack activates; never sudo, never an unpinned version
```

Run the check on a host this repository has not been built on, and on the first turn after a
toolchain pin moves. Exit `5` is **not** a red build — it is a host that is not set up — and its
per-tool `remedy`/`installCommand` lines are relayed verbatim. A `verify-only` row is a human's to
install; say which tool and which pin, and do not install it another way. A repository declaring no
`project.toolchain` has nothing to check here and says so.

## 5. Cutting the branch — dry run, then bare

Render the name from `branch.template`: `{model}` is the model alias in play, `{persona}` the
persona (`kurapika` unless the run says otherwise), `{descriptor}` a short kebab slug from the
request, never from the date. **Rendering is this skill's** — `nen shu warmup --branch` is required
and has no default, because nen never invents a branch name (§ 8).

```bash
nen shu warmup --repo <path> --branch <rendered name> --from <branch.base> --dry-run   # every git command, in order, none run
nen shu warmup --repo <path> --branch <rendered name> --from <branch.base> [--tests]
```

The dry run prints the whole sequence with each step's own refusal condition attached, and the bare
run performs it: `branch --show-current` → the in-progress check → the working-copy check → `remote`
→ the trunk exists → `check-ref-format` → the name is free locally → `fetch origin` → the divergence
test → the fast-forward → the name is free on `origin` → **`switch -c <branch> origin/<branch.base>`**
→ the lane's declared `build`.

> **`--from` is passed every time, with the value read from `nen/workflow.json` → `branch.base`, and
> `origin/main` is never written as a literal.** The flag *defaults* to `main` when that local branch
> exists, and that default is exactly the trap: a repository whose `branch.base` is `develop` would
> warm up silently from the wrong trunk, and every later step — `ao`'s pull, `aka`'s squash range,
> `shibari`'s PR base — would then disagree with the branch it was cut from. **A parameter this skill
> already read is a parameter this skill passes**; leaving it to a default is leaving it to a value
> nobody in the run has looked at. Where `branch.base` names a trunk with no local branch, `--from`
> refuses at `2` naming itself — fetch or create the base and re-run, never fall back to `main`.

**Reactions, by exit code** (`claude/agents/kurapika.md` § *The `shu` verbs* is the authority for
the whole family):

| Exit | What it means here | What breath does |
|---|---|---|
| `0` | warm — the branch is cut from the fetched tip and the declared build passed on it | proceed to § 6 |
| `1` | a git step ran and failed, **or** the delegated build failed, **or** the executor refused the build with a `2` | nothing is rolled back and the trunk has already moved: report `steps[]` verbatim, then hand the red build to [`hatsu:rasengan`](../rasengan/SKILL.md) |
| `2` | a refusal *before* any mutation: a dirty tree (every path listed), a merge/rebase/cherry-pick in progress, a detached `HEAD` carrying unreachable commits, no `origin`, a diverged trunk, a name git will not accept or that already exists locally or on `origin` | fix the named condition and re-run. **Never reach for `--discard`** |
| `3` | the declaration excludes this host | **G5** — name the host the declaration allows; never retry |
| `4` | the lane declares no `build` (a seat) | quote the declaration's own reason, run the repository's documented command, say that you did |
| `5` | the declared program is not on `PATH` | back to § 4 |

**`--discard` is never breath's flag.** It runs `git reset --hard` then `git clean -fd`, and the
brief this skill is written to is explicit: nothing is discarded unseen. If a dirty tree must go, the
maintainer says so, in this session, after reading the list the refusal printed.

**A repository with no declaration still warms.** Verified live against the `zheref/nen` checkout,
which carries no `project` block: the git half prints in full and the run ends with *"no declaration
-- build/test verification skipped … That is not a failure … this exits 0"*, `lane: (none)`
(`docs/ab/breath.md` § 2.3). Say plainly that no declaration exists, that the warm-up was the git
half only, and treat writing a `project` block as a **G4** change to propose — not a blocker, and
not something to paper over with a remembered command line.

## 6. Proving the iteration checks

`shu warmup` proves the lane's `build` (and, with `--tests`, its `test`) on the branch it just cut,
re-reading the declaration **on that branch**. That covers `iteration.checks` when the list is the
default `["build"]`. When `workflow.json` declares more than `build`, breath does not re-implement
the loop: it hands the turn to [`hatsu:rasengan`](../rasengan/SKILL.md), which runs every declared
check in order and owns the whole exit table for them.

Pass `--tests` only when `iteration.checks` actually contains `test`. A test suite is the slow half
and a warm-up is the fast one; running it by reflex makes every first turn cost what a full
verification costs.

## 7. What the turn reports

One line, and it is not a gate event: the case `wc classify` reported, the branch cut and the tip it
was cut from, the toolchain verdict, the build's exit code, and — where it applies — the
`no workflow.json` sentence from § 2. A warm-up that did not run is reported as **not run**, never
rendered as clear.

## 8. Residue — what has no verb at nen `0.3.0`

- **Rendering `branch.template`.** `nen shu warmup --branch` is required with no default; the
  substitution of `{model}`/`{persona}`/`{descriptor}` is this skill's, from `workflow.json`. No verb
  formats a branch name, and `nen parse` is a grammar engine for invocations, not a templater.
- **Reading `nen/workflow.json` at all.** No loader, no `schema check` row at `0.3.0` (§ 2, verified
  live). Read it as data, state the defaults when it is absent, and report a malformed one as a
  finding.
- **Carrying a dirty trunk onto the new branch** (§ 3's `must-move` answer) is `git stash` → the
  warm-up → `git stash pop`, run by hand and named. `nen shu warmup` offers exactly two doors — refuse,
  or `--discard` — and neither of them preserves work.
- **Deciding whether an existing dirty branch is this effort** stays judgment. `nen wc classify`
  hands over the commit subjects and the paths and says outright the call is not the module's.

## 9. Authority

- **Permitted:** classify the working copy, probe and (through `corepack` only) install a declared
  host tool, fetch, fast-forward the trunk, cut a **non-trunk** branch, run the lane's declared
  `build`/`test`.
- **Not permitted:** any push, any commit, any PR or label, any `--discard`, any deploy. Breath is
  the phase before authorship, and it produces no object anyone else can see.
- **Not a gate event.** The only stop breath raises is a **G5** for an unsupported host (exit `3`)
  or a genuinely unreadable checkout; the dirty-tree question is an in-session ask, not a gate.

## 10. Hard limits

- **Never `--discard` a tree it has not shown the maintainer**, and never discard one on its own
  account at all.
- **Never commits, never pushes, never touches `origin` except to `fetch`** and to check whether a
  branch name is free.
- **Never cuts a branch from a stale trunk** — the cut is `origin/<base>`'s freshly fetched tip, which
  is `shu warmup`'s own sequence, not a `git checkout -b` typed by hand.
- **Never cuts from a literal `origin/main`.** The trunk is `origin/<branch.base>`, passed as
  `--from <branch.base>` on every invocation, read from the file rather than assumed (§ 5). A
  repository on `develop` warmed up from `main` is an effort based on the wrong trunk from its first
  commit.
- **Never reports a warm-up it did not run as clear**, and never reports a repository with no
  declaration as verified.
- **Never invents a `workflow.json` value.** Absent file → the stated defaults, said out loud; absent
  key → the default for that key; neither → stop and ask.
- **Never runs twice on one effort.** A second cut is a second branch, and an effort with two branches
  is two efforts nobody scoped.
