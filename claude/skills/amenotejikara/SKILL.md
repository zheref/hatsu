---
name: amenotejikara
description: Swap which worktree the maintainer's core checkout holds, and swap back — list every checkout of the project with its branch, dirt and distance from the base, bring one worktree's committed tree into core so Xcode (or any IDE opened on core) and hatsu:amaterasu build and debug exactly that, and return core to where it started with its own uncommitted work restored. Use when the maintainer invokes hatsu:amenotejikara [list | <worktree|branch> [--take] | return | status], or asks to swap to a worktree, see what a worktree holds, debug a worktree from Xcode, or put core back. Core's work is parked in a pinned commit, never stashed; nothing is discarded, pushed or committed on anyone's behalf.
---

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md`,
`docs/LAUNCH-MIGRATION.md`, `docs/STANDALONE-ENTRY.md`, `docs/PROCESS.md` and `docs/SURFACES.md` belong to the resolved **Hatsu plugin
root**, not the consuming repository. On an installed surface, use the absolute root printed by
`hatsu-warmup` to read those files (re-resolve through that skill if unavailable). Relative links
below identify source locations; a missing consumer `docs/` copy is not a missing policy and must not
trigger a duplicate filing. Never copy or invent a second policy in the target repository.

# Amenotejikara — trade places with a worktree

**Nature: Transmuter.** Sasuke's Rinnegan swaps the places of two things in an instant; this swaps
which tree the **core checkout** holds.

> **Show me every checkout. Put that one's work in front of Xcode. Put mine back when I say so.**

Efforts run in worktrees; the maintainer builds and debugs from the **core** checkout, and
[`amaterasu`](../amaterasu/SKILL.md) § 3 launches from nowhere else — a worktree build races the one
they are looking at over one derived-data directory, bundle id and device, and a fresh worktree lacks
the untracked local config the declaration's preconditions need. **So a worktree is never opened in
the IDE; its tree is brought into core**, where the project path, derived data, signing and local
config already are. Attaching a debugger to a binary built in a worktree is the tempting shortcut and
the wrong one: breakpoints are keyed on source paths, so they bind unreliably and open the wrong copy.

## 0. Standalone entry

[`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) § 7b: this skill inherits no caller
state, so its `## 0.` adds **P1** and orientation only. **P1 · Warm up** through
[`hatsu:hatsu-warmup`](../hatsu-warmup/SKILL.md), unconditionally: every verb here is `nen wc swap` or
`nen wc worktrees`, which exist only from nen `0.14`, so a warm-up that has not proved the pinned
build has not proved this skill can run. A binary older than `0.14` answers the verbs as unknown —
that is the warm-up's re-pin, never a reason to improvise the swap with raw git. **Orientation:** say
which checkout `--repo` named and which core nen resolved from it, and run `status` first, so the
maintainer sees any swap already active before a new one moves core. Not a gate event; nothing is
asked but a missing or ambiguous target (§ 1).

## 1. Invocation

```
hatsu:amenotejikara [list]                         # the default
hatsu:amenotejikara <worktree path | branch | worktree name> [--take]
hatsu:amenotejikara return
hatsu:amenotejikara status
```

Every verb is a nen verb (nen `0.14`, zheref/nen#242), **with `--repo` naming any checkout of the
project** — nen resolves core through `git rev-parse --git-common-dir`, so it works from a worktree
session as well as from core:

| Skill verb | nen |
|---|---|
| `list` | `nen wc worktrees --repo <path> --base <branch.base>` |
| `<target>` / `<target> --take` | `nen wc swap <target> --repo <path> [--take]` |
| `return` | `nen wc swap --return --repo <path>` |
| `status` | `nen wc swap --status --repo <path>` |

`--base` is `nen/workflow.json` → `branch.base` (default `main`), read for `list`'s distance column; a
relative target path resolves against `--repo`. `--json` gives `nen.wc.worktrees/v0.1` and
`nen.wc.swap/v0.1` where a caller needs the rows rather than the prose.
A missing argument or configuration item is asked for and set up inline (`missing-argument`,
`missing-configuration`; [`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 4 *Ask, set up, continue*): an
unknown or ambiguous target is asked with `list`'s rows as the options.

## 2. The verbs

| Verb | What core ends up holding | Who keeps the branch |
|---|---|---|
| `list` | unchanged — one row per checkout: `core` / `in` mark, branch or `(detached)`, uncommitted count, `+ahead/-behind` against `origin/<base>`, HEAD, last commit and its age, path | — |
| `<target>` (view) | the worktree's **HEAD commit, detached** | the worktree: a session working there is undisturbed; swapping again picks up its newer commits |
| `<target> --take` | the worktree's **branch** | core; the worktree is detached on the same commit, so a commit made in Xcode lands on the branch |
| `return` | its **home** — the branch (or detached commit) it held before the first swap — with its parked work restored | the worktree, handed back after a `--take` |
| `status` | unchanged — the recorded swap, or "no swap active" | — |

**Only committed work travels.** A target worktree with uncommitted changes is **refused at exit
`3`** with every path listed: commit them there (a `ren` turn already has — `kokusen` commits every
turn), then swap. A second swap while one is active keeps the **first** home, so `return` always goes
back to where the maintainer started. A dirty core that is *viewing* can be promoted in place with
`<same target> --take`, which keeps the edits and makes them committable onto the branch.

After a swap nen names any `project.pbxproj`, `Package.resolved`, `Podfile.lock` or
`Cartfile.resolved` that changed: Xcode may ask to reload the project or re-resolve packages. Say so.

## 3. Core's own work — parked, never stashed

Core's uncommitted work (untracked files included) is written through a temporary index into a
commit object **pinned at `refs/nen/wc-swap/parked`**, and only then is core cleared for the
checkout. **The stash stack is shared by every worktree and every session**, so it is never used.
**Ignored files — build products, `xcuserdata`, local secrets — are never touched** in either
direction. `return` restores modified, new and deleted paths exactly, nothing staged, and drops the
ref. The swap record is `<common git dir>/nen-wc-swap.json`, where no checkout and no `git clean`
reaches it, and a swap or return holds its advisory lock (`nen-wc-swap.json.lock`), so two sessions
never swap core at once.

## 4. Exit codes

| Code | Meaning | What to do |
|---|---|---|
| `0` | done, or listed | relay the engine's lines |
| `2` | refused before anything moved — unknown or ambiguous target, core itself, no swap to return from, `--take` on a detached worktree, a bad argument, the lock held by another swap, or a stranded `refs/nen/wc-swap/parked` with no swap recorded | relay it; an unknown or ambiguous target is the trigger to ask (§ 1); a held lock is another session mid-swap, so wait and re-run; a stranded park ref is **shown, never overwritten** — it is somebody's only copy of their work |
| `3` | a tree is dirty — the target on swap, core on `return` / re-swap, or a submodule dirty inside core on a first swap — every path listed | **relay the paths and ask**; never commit, discard or stash them on the maintainer's behalf |
| `1` | a git step failed part-way; the message says where | relay it verbatim, then `nen wc swap --status --repo <path>` to read the recorded swap, then `nen wc swap --return --repo <path>` to put core back and restore the parked work; the parked commit stays pinned at `refs/nen/wc-swap/parked` until a return succeeds, so nothing is lost meanwhile. **Never recover with raw `git checkout` or `git stash`** — if `--return` also fails, stop and show both messages and the pinned ref |

## 5. Around the rest of Hatsu

- **[`amaterasu`](../amaterasu/SKILL.md)** launches from core, so after a swap it builds the swapped-in
  tree with no special case; name the swapped-in branch in its report line.
- **Parallel sessions:** a view swap never touches the worktree, so the effort there keeps running.
  A `--take` detaches it — **say so before taking**, because that session's next commit would land on
  no branch until `return`.
- **Core is not an effort's checkout while swapped:** return before running
  [`breath`](../breath/SKILL.md), [`aka`](../aka/SKILL.md) or any Ren turn **in core**.
- **Not a gate event.** No stop, no bell of its own; inside a `ren` turn it is reported in the turn.

## Authority and hard limits

**Permitted:** read every checkout; in core, check out a commit or a branch; detach and re-attach a
worktree's branch on `--take` / `return`; write the parked commit, its ref and the swap record.

- **Never stashes, never discards, never commits, never pushes** — a dirty tree is a question (exit `3`).
- **Never moves a worktree's branch without `--take`**, and never takes one without saying which
  session it detaches.
- **Never touches an ignored file**, and never improvises a swap with raw `git checkout` / `git stash` —
  nen's verb is the only way.
- **Never opens a worktree in the IDE or launches from one** — that is amaterasu § 3's rule, kept.
