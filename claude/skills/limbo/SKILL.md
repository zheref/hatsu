---
name: limbo
description: Keep one consumer repository's canon mirror current on every agent surface it declares — read its recorded canon pin, render the canonical handbook rules at that tag into each surface's rules location through nen canon mirror, classify every drift (missing, stale, extra, hand-edited, foreign), and land the regenerated mirror as one PR at that repository's own gate. Use when the maintainer invokes hatsu:limbo [for <path>] [to <tag>] [as check|sync], asks to sync, check or repin a repository's canon mirror, or when a canon release fans out. Never writes canon, renders only declared surfaces, moves a pin only on the typed word, never overwrites a hand-edited file, never merges.
---

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md`,
`docs/LAUNCH-MIGRATION.md`, `docs/STANDALONE-ENTRY.md`, `docs/PROCESS.md` and `docs/SURFACES.md` belong to the resolved **Hatsu plugin
root**, not the consuming repository. On an installed surface, use the absolute root printed by
`ten` to read those files (re-resolve through that skill if unavailable). Relative links
below identify source locations; a missing consumer `docs/` copy is not a missing policy and must not
trigger a duplicate filing. Never copy or invent a second policy in the target repository.

# Limbo — the canon, projected into every surface a consumer declares

**Nature: Transmuter.** Limbo: Border Jail projects shadows of one body into a plane beside this one,
each acting exactly as the original. This projects **one canon** — `zheref/bankai-handbooks` at the
tag a consumer pins — into the rules location of every agent surface that consumer declares, each
mirror exactly the canon (`CON-13`). Machinery, not prose: limbo authors no rule.

> **Read the pin, render the canon at it into each declared surface, say what drifted, and put the
> regenerated mirror in front of the maintainer at that repository's own gate.**

The verbs are nen `v0.16.0`'s (`nen canon --help`); every claim below was verified live against a
fixture consumer, 2026-09-29 ([`docs/ab/limbo.md`](../../../docs/ab/limbo.md)). **The marker is the
ownership claim**: `generate` refuses the whole run at exit `2`, before the first byte on any surface,
when a destination exists without one.

## 0. Standalone entry — when no composite is holding the run

Typed by the maintainer, or reached from a canon release's `CON-22` fan-out — that **is** its wired
position ([`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) § 7b). **Reached from a
composite, skip this section.**

| Step | What limbo does |
|---|---|
| **`P1`** | `hatsu:ten limbo`, unconditionally: `D10`, and `$hatsu_root` |
| **`P1b`** | A **sync** proves the consumer's base through [`breath`](../breath/SKILL.md) (§ 2 step 8) before the mirror is written; declined for `as check`, which writes nothing |
| **`P2`** | `nen repo classify --repo <path> --json` (slug, role, gate) and `nen wc classify`, read out loud before anything is written |
| **`P3`** | **Does not apply.** The subject is the checkout's *current* mirror against the canon at the pin, not a change set; there is no `against <base>` clause |
| **`P4`** | Asks only what disk cannot answer: the surfaces (§ 3), and the pin, **typed** (row `missing-maintainer-choice`) |
| **`P5`** | `standalone entry · <slug> · role <role> → <gate> · pin <source>@<ref> · latest <tag> · surfaces <list> · not running: nothing (not a loop phase)` |

## 1. Invocation

```
hatsu:limbo [for <path>] [to <tag>] [as <check|sync>]
```

```bash
nen parse limbo --grammar "for [<path>] to [<tag>] as [<mode:check|sync>]" --line "<the line, minus the prefix>"
```

Verified live: every clause is optional, the empty line parses with each `(clause absent)`, and
`as verify` is refused naming `check | sync`. `<path>` defaults to the checkout the session stands
in; `<tag>` is a **repin** (§ 4); with no `as` the run diagnoses, then asks through the picker —
⭐ **Sync** · **Report only** · **Stop** — `as sync` supplies that answer, `as check` never asks and
never writes. A missing argument or configuration item is asked and set up inline
(`missing-argument`, `missing-configuration`; [`WORKFLOW.md`](../../../docs/WORKFLOW.md) § 4).

## 2. The run, in order

| # | Step | Owned by |
|---|---|---|
| 1 | Slug, role, gate — **`G2` for a consumer, `G4` for a canon repository**; the role decides (ROSTER § *Rulings of 2026-09-18*). No `.claude/canon-values.yml`: `canon mirror: not applicable`, stop | `nen repo classify --repo <path> --json` |
| 2 | The pin: `source`, `ref` (`nen.canon.pin/v0.1`). Exit `1` — no `maintained_tools[].pinned`, several, or a non-tag — is `missing-configuration`: candidates listed, the tag **typed**, recorded, re-read | `nen canon pin --repo <path> --json` |
| 3 | The canon checkout **at that tag**, re-verified by `describe --exact-match`; then the latest tag, for the *behind* line | [`bankai-handbooks`](../bankai-handbooks/SKILL.md) § 0 (residue 1–2) |
| 4 | `--rules-dir`: the scenario the consumer's own registry records, `--always-load` read fresh off `handbooks/INDEX.md` | `nen canon resolve --repo <path> --target <slug> --always-load <…> --stack-dir "$canon/handbooks/stacks" --leaf rules` |
| 5 | The drift, per surface, per file — `ok / missing / extra / stale / hand-edited / foreign`; `mkdir -p .nen` first (residue 5). Exit `0` is *current*; `1` is drift; `2` is the invocation or the declaration, never *current* | `nen canon mirror check --repo <path> --rules-dir <…> --canon-values .claude/canon-values.yml --not-mirrored README.md,placeholders.md --markdown-out .nen/canon-drift.md --json` |
| 6 | **Report** (§ 5). `as check`, or *current* with no `to`: stop here, hand-back line | — |
| 7 | **Gate on `hand-edited`** — § 3, before any write | row `hand-edited-canon-mirror` |
| 8 | Branch off the fresh trunk, base proven, a dirty tree carried | [`hatsu:breath limbo-<ref>`](../breath/SKILL.md) |
| 9 | Repin — only with `to <tag>` (§ 4) | residue 3, `nen schema check --repo <path>` |
| 10 | `--dry-run`, then bare: `written / unchanged / deleted / foreign` per surface; then step 5 again — **`drift: none`, or a finding about the generator** | `nen canon mirror generate …` (same flags as 5, no `--markdown-out`) |
| 11 | Commit: `chore(canon): mirror <source>@<ref> into <surfaces>`, `Hatsu-Agent: kurapika`; a prose change reports `focused tests: not applicable` | [`hatsu:kokusen --type chore --scope canon`](../kokusen/SKILL.md) |
| 12 | Publish, one PR at the gate step 1 named, the declared reviewer requested, hand off | `nen wc publish --repo <path> --set-upstream` (`--dry-run` first) · `nen pr open --repo <path> --target <slug> --base <branch.base> --title-file … --body-file …` · `nen pr request-reviews` · [`hatsu:en on <CODE>#<N>`](../en/SKILL.md) |

**The PR body**: what changes for the consumer (pin, surfaces, per-surface counts), the
`Surface | File | Issue` table `--markdown-out` wrote, **`## How to verify`** (step 5's command,
expected `drift: none`, exit `0`), `Closes #N` where a repin issue exists. The merge is `en` § 5's at
the PR's terminus (row `own-pr-merge`); **limbo performs none**.

## 3. The drift classes, and the two that stop the run

`missing` is written, `stale` is rewritten at the recorded pin, `extra` (a marked orphan) is deleted
by `generate`, `foreign` (unmarked, no canon source) is the consumer's own — never touched, always
listed. **Two classes stop the run before a byte moves:**

- **`hand-edited`** — marked for this pin, other bytes, *or no marker where a canon file should be*.
  Someone wrote a rule into the mirror instead of the canon; overwriting it loses the rule silently.
  **G5** (row `hand-edited-canon-mirror`), the files named: **A** the edit is canon — file it against
  `zheref/bankai-handbooks` through [`hatsu:file`](../file/SKILL.md) (G4 there, `bankai-handbooks`
  § 4), then regenerate; **B** it is repo-specific — move it to the consumer's own file (a
  subdirectory of the rules dir, `CLAUDE.md`, prose outside the `AGENTS.md` block), then regenerate;
  **C** the file is the **predecessor generator's** — first line `<!-- GENERATED from bankai-core@…`
  (residue 4; `check` reads it as unmarked, verified) — `git rm` that mirror and regenerate: nothing
  is lost, the canon at the pin is the source. C is starred only for a legacy first line.
- **No `surfaces:` key** — `check` exits `2`: *"Which agent surfaces a repository is used with is that
  repository's own declaration, never a default"*. `missing-configuration`: derive the recommendation
  from disk (`.claude/` → `claude-code`, `AGENTS.md` or `.codex/` → `codex`, `.cursor/` → `cursor`,
  `.agents/` → `antigravity`), ask once, write the key into `.claude/canon-values.yml`, re-run step 5.
  **Never `--surfaces` from limbo's own head, never all four.**

## 4. The pin — read, reported, moved only on the typed word

`nen canon pin` reads; **nothing in nen writes a pin.** A pin behind the canon's latest tag is reported
— `pin v0.6.0 · latest v0.7.0 · behind` — with the exact line to type, `hatsu:limbo for <path> to
v0.7.0`, and **is never moved on limbo's own authority**: which canon governs a repository decides
which rules its reviewers cite, so it is the owner's decision, made visibly in one PR — the reason nen
refuses a floating `--ref` at all. With `to <tag>`: the tag must resolve on the canon
(`refs/tags/<tag>`, residue 3), `maintained_tools[].pinned` is edited, `nen schema check` re-reads it
(`pinned tools: …@<tag>` on the `nen/repos.json` row), the checkout moves (step 3), and every surface
regenerates with the new marker in the same commit — **a repin without the regenerate is what
`check` reports as `stale` on every surface**, verified. A tag below the recorded pin is a downgrade,
said. `generate --ref` is never used to render past the registry.

## 5. Report

One block, quoted from the verbs: the P5 line; per surface the six class counts, then `written /
unchanged / deleted`; the second check's `drift:`; the commit, the push, the PR as `<CODE>-PR-#<N>`
and its gate. **`as check` ends**: *Next in the wired run: `hatsu:limbo for <path> as sync` — this
run wrote nothing.*

## Residue

1. **The canon checkout** — nen *"fetches nothing and checks nothing out"*; `bankai-handbooks` § 0's
   block does it, `describe --exact-match` the gate.
2. **The latest tag** — `git -C "$canon" tag --sort=-v:refname | head -1` after `fetch --tags`.
3. **Writing the pin** — one key in the consumer's `nen/repos.json`, then `nen schema check`; a
   `nen canon pin --write <tag>` is a nen request, filed.
4. **The predecessor marker** — `head -1` against `<!-- GENERATED from bankai-core@`; nen knows its own
   marker only, by design.
5. **`mkdir -p .nen`** — `--markdown-out` does not create the parent (verified: exit `1`, `ENOENT` on
   stderr, no file).
6. **`iteration.canonMirror.command`** (WORKFLOW § *The local verification gate*, step 2) cannot carry
   a machine-local `--rules-dir` as a literal argv, so a canon-values edit's regenerate is this
   skill, by hand, until nen resolves the checkout itself — filed.

## Authority

- **Permitted:** every read above; the canon fetched into the cache slot; `generate` into the declared
  surfaces; the `surfaces:` key and the pin on the maintainer's answer; the branch, the commit, a
  non-trunk push, one PR, the reviewer request, the hand-off to `en`.
- **Not permitted:** any write to `zheref/bankai-handbooks`; a merge, a vote, a gate label; a
  surface set or a pin of its own choosing.

## Hard limits

- **Never `generate` before `check` is read, never over `hand-edited`, never a surface the consumer
  did not declare, never `--ref` past the registry.**
- **Never moves a pin without the typed `to <tag>`**, never to a ref that is not a tag of the canon.
- **Never edits a mirror file, never carries a rule from a mirror into canon** — that is `hatsu:file`.
- **Never reports *current* for a check that did not run**: exit `2` is not exit `0`.
- **Never merges, never writes `Akatsuki-Agent`, never improvises a Nen-owned operation** — a missing
  verb is residue.
