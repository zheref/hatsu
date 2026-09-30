---
name: kagutsuchi
description: Send a build to a declared NON-PRODUCTION destination by running the repository's own `deploy` row through `nen shu deploy --target <name> --run`, behind a freshness gate that refuses a dirty tree or an archive not built from the checkout's HEAD at the trunk's tip. Use ONLY when the maintainer invokes hatsu:kagutsuchi [<target>] or asks in their own words to upload this. The target is typed, or nen/workflow.json → deploy.defaultTarget where declared; neither is asked. The plan is printed always; sending happens only on that call — typed, a futon `then` step on the advance go, or hatsu:kamui's last step — never on a composite's own authority, never proposed. Production and the stores are hatsu:mugetsu at G3.
---

# Kagutsuchi — one build, one named destination, on your word

**Nature: Emitter.** A build leaving this machine is a release act.

> **Show me exactly what would be sent and where, prove it is the build of this tip. Then, because I
> called for it, send it — once.**

A **human call, per target** (*kagutsushi* is still an invocation). Plugin root and the
declaration gate by role: [PROCESS.md](../../../docs/PROCESS.md) § *Authority every phase shares*.

## 0. Standalone entry

[`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md), narrowest form (wired only from
[`kamui`](../kamui/SKILL.md) § 4, which says so): **P1**, and **P2**'s block **inside** § 3's plan;
the artifact's commit is § 3a's gate; nothing is asked but a target neither typed nor declared.

## 1. Invocation — and who is allowed to say it

**P1 — this run opens with `hatsu:ten kagutsuchi`** ([`ten`](../ten/SKILL.md) § 6 catches up this phase's
missing prerequisites under its own name; the phases this run calls skip theirs).

```
hatsu:kagutsuchi [<target>]
```

**`<target>` is a key of `nen/contract.json` → `project.targets`, and the call is the
authorization.** Two sources, **and the report says which** (§ 5): **typed** — the maintainer's
word, never a near-match — or, omitted, **`nen/workflow.json` → `deploy.defaultTarget`** (Hatsu's
key, [`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 2 → `deploy`; ruling 2026-09-29, HA#146),
honoured **only where its `why` reads non-production** (§ 2). **Neither typed nor declared is asked
as free text** (`missing-maintainer-choice`; WORKFLOW § 4): the declared keys listed, **none
starred, none a picker option**; an undeclared one is refused, naming the declaration PR. `nen shu
deploy` is unchanged — **`--target` is always passed explicitly**; *nen never chooses where a build
goes* stays true, the choice recorded in configuration the maintainer wrote. **A call is the stop**
— no confirmation, no options — the plan prints (§ 3), the gate runs (§ 3a), the report says (§ 5).

- **No agent prompts for it**, **no composite calls it on its own authority** — a
  [`futon`](../futon/SKILL.md) `then` step reaches it only on the **advance go**
  [`mugetsu`](../mugetsu/SKILL.md) § 3 defines, [`kamui`](../kamui/SKILL.md) § 4 on the maintainer's
  own typed `hatsu:kamui [<target>]`, the target resolving as above — **a recorded delegation is NOT
  the call** (a **DRAFT**, `OPEN-2`) and **a subagent never self-authorises**: without the call it
  prints the plan, says it has none, and stops. **One call, one target, one send, quoted verbatim.**
- **It calls nothing but the verb and its gate** — never [`susanoo`](../susanoo/SKILL.md) (the
  package is built first, by the maintainer or kamui § 3) nor [`mugetsu`](../mugetsu/SKILL.md).

## 2. The parameters, and where they come from

| Value | File → key |
|---|---|
| The destinations: what they append, require, and why | `nen/contract.json` → `project.targets.<name>` → `args`, `requiresEnv` (names, § 5), `why`, `unsupported` |
| What `deploy` runs, and in which lane | `project.verbs.<lane>.deploy`; `project.defaultLane` or `--lane` |
| Whether this host may, and what must be true first | `project.hosts`; `project.preconditions.<lane>` — asserted, never performed |
| Whether to tag what was sent, and with what name | `nen/workflow.json` → `tags.deploy.<target>`, `tags.identity.nameFrom` (§ 4a) |
| The target when none is typed, and the commit the archive was built from | `nen/workflow.json` → `deploy.defaultTarget` (§ 1); `tags.identity.nameFrom` line 2 (§ 3a) |

**Targets are project-level, `deploy` rows per-lane**, and nen never checks the pairing: read the
`target:` line and the composed `would run:`. **Non-production is the `why`'s PROSE, not a typed
field** (§ Residue), read failing closed: a `why` that implies the destination **reaches end users**
is [`mugetsu`](../mugetsu/SKILL.md)'s at **G3** (row `release-go`); **no `why`**, or one not clearly
non-production, is refused.

## 3. The plan — printed always, before anything

```bash
nen shu deploy --repo <path> [--lane <lane>] --target <name> --dry-run
```

Beyond [PROCESS.md](../../../docs/PROCESS.md) § *Running a declared verb*, it carries the `target:`
line with what it appends and requires, the host row and every precondition. **Write `--dry-run`**
though the bare form is read-only. **Paste the plan before sending; what is sent is what was shown.**

### 3a. The freshness gate — before `--run`, every time

**What reaches testers matches a known commit at the trunk's tip** (ruling 2026-09-29, HA#146: a
95-commit-stale archive was one green `--run` from TestFlight). After the plan, before § 4:

```sh
"$hatsu_root/scripts/send_freshness_check.sh" --repo <path>   # [--base <branch>]; default branch.base
```

**Exit `2`** refuses, in order: a dirty tree (*before* the send); a `nameFrom` absent (no archive
ran here), symlinked, out-of-tree or whose line 2 is not a raw commit; a built SHA **not the
checkout's `HEAD`**; after `git fetch origin <base>`, one **not `origin/<base>`'s tip** — both SHAs
named. **Exit `3`**: no `tags.identity` declared — tree proven clean, the send may proceed, § 5 reads
`freshness: unverified`, never `fresh`. **Exit `0`** prints § 5's four lines. A refusal **stops, the
plan printed**: catch up and re-archive — never send around it.

## 4. The send — only on the call, only that target

```bash
nen shu deploy --repo <path> [--lane <lane>] --target <name> --run
```

`--run` is a second, independent flag — **no single-flag path to acting**. Run it **once**; on a
failure read § 5, fix the named fact and re-run under the same call.

### 4a. The distribution tag — OPT-IN, and only after the send succeeded

A repository may ask for what was sent to be tagged (ruling 2026-09-18, corrected 09-19) by
declaring `tags.identity.nameFrom` (**line one the identity, line two the build SHA**, shared with
[`susanoo`](../susanoo/SKILL.md) § 5a) and `tags.deploy.<target>` (**that this target is tagged**,
and whether pushed; no entry, no tag). **The one tag**, cut where a build lands; the default is none.
**Every check and the cut live in [`scripts/dist_tag.sh`](../../../scripts/dist_tag.sh)**, run
**only after a green `--run`**, the target passed as [PROCESS.md](../../../docs/PROCESS.md)
§ *Escaping the maintainer's words* says:

```sh
"$hatsu_root/scripts/dist_tag.sh" --repo <path> --target-file "$target_file" [--dry-run]
```

It reads the opt-in first, composes `dist/<target>/<identity>` **from variables**, refuses a
`nameFrom` that is not a regular file inside the repository, a build SHA that is not a raw commit
(**never tagging HEAD instead**), a dirty tree and an illegal ref name, then runs `nen tag cut …
[--push]`. **Exit `0`** cut (or all checks passed under `--dry-run`); **`3`** not declared, nothing
cut; **`2`** refused, reason on stderr; **`1`** `nen tag cut` refused — **its reason stands** (`--at`
must be an ancestor of `origin/<trunk>`). **`--push` is not atomic**: a rejected push leaves the name
local; delete that tag, **verified absent from `origin`**, and re-cut. **A tag refusal never unsends
anything**: § 5 reports each on its own line.

## 5. The refusals, credentials, and the report

Codes per `claude/agents/kurapika.md` § *The `shu` verbs*; **a seat deliberately beats a mistyped
target**.

| Exit | Fact | Reaction |
|---|---|---|
| `1` | the deploy tool ran and **failed** | relay its output, the failing step, and **the destination's state — or that you do not know it** |
| `2` | `--target` naming no declared destination | **the trigger to ask** (§ 1), the declared list verbatim — **never pick one**, never a near-match |
| `2` | `--run` with `--dry-run`; an unsatisfied precondition or `requiresEnv` variable | fix the wiring; the plan **still prints with the failing rows `FAIL`**, relayed whole |
| `3` | **unsupported host** | **G5.** Name the hosts the declaration allows and stop — never retry |
| `4` | **a seat**, or the target declares `unsupported` | quote it verbatim and stop |
| `5` | the program could not be started | `nen shu tools --repo <path>`; relay the remedy |

**Credentials are asserted, never handled**: nen checks each `requiresEnv` **variable** is set without
reading it; this skill never reads, prints, exports or asks for one. An unset one is exit `2` with
its **name**, and the run ends there, for the maintainer to set in their own shell.

**Then one block, and stop**: the target, **its source** (`typed`, or `workflow.json →
deploy.defaultTarget`) and its `why` quoted, the lane, the argv copied out of the `--dry-run` report,
**§ 3a's four lines** (built SHA, `HEAD`, `origin/<base>`'s tip, `fresh` | `unverified`), whether
`--run` was passed, each exit code, and **the maintainer's call quoted verbatim**.
**One tag line**: *cut and pushed*, *cut locally*, *refused with nen's reason*, or *not declared for
the target* — malformed is read-and-rejected, not absent. **Re-render the turn report**, the upload
in **01 Accomplished** ([PROCESS.md](../../../docs/PROCESS.md) § *Reporting a phase*), and **say
nothing about what is next.**

## Residue

**Nothing marks a target as production** (§ 2 reads the `why`), **nothing checks a target belongs to
its lane** (read the plan), **exit `1` says nothing about the far end**, **nothing records the
authorisation** (quoted by hand; no per-run log, zheref/nen#91), and **§ 3a and the default target
are Hatsu's** — a script and a key nen validates but does not read; a per-stack default in `nen shu
detect`'s pack is nen's to add.

## Authority and hard limits

- **Permitted, only on the maintainer's own call:** the plan for any declared target; § 3a's gate;
  `nen shu deploy --target <that target> --run` **once**, to a destination whose `why` says
  non-production; where `tags.deploy.<target>` is declared, that one tag through `scripts/dist_tag.sh`
  after a green `--run`.
- **Not permitted:** `--run` for production or a store (`mugetsu` at **G3**); `nen shu release`; a
  GitHub Release; a merge, PR or label; an edit to a declaration to make a line work; **any push or
  tag other than § 4a's**.
- **The call is one send wide, ends with the run, and is never authority for another target.** Not a
  gate event of its own; exit `3` is the one **G5** it raises.
- **Never runs unasked, prompts for itself, runs from a composite on its authority** (a futon `then`
  step on the advance go, mugetsu § 3, and kamui's typed call are the maintainer's), **or treats a
  delegation as the call**; **never picks a target** — typed, or the declared `deploy.defaultTarget`
  (§ 1), never a near-match, never a default whose `why` is not non-production.
- **Never sends past § 3a**: a dirty tree, an archive not built from `HEAD`, or one not at
  `origin/<base>`'s tip is refused before `--run`, never sent and tagged later.
- **Never sends to production or a store, or what it did not show**; **never reads, prints, exports
  or asks for a credential.**
- **Never retries an exit `3`**, routes around a seat, sends twice on one call, or **claims a send
  succeeded** on an exit code it did not read.
- **Never tags an undeclared target**, composes a tag name, tags after a plan-only run or a failed
  send, re-tags, or **routes around a tag refusal**. **A tag refusal is not a failed send, a green
  send is not a cut tag**: **G3** still needs its own recorded go.
