---
name: bankai-rule
description: Record one port ruling — what a source stack's rule or concept becomes on a target stack (map · mirror · drop with note · target-only addition) — as a stable-id row in the ports handbook family of zheref/bankai-handbooks, one directed pair file per (from, to), and drive the rulings to a PR there at the G4 merge prompt. Use when the maintainer invokes hatsu:bankai-rule <from-scenario> to <to-scenario> [ruling <text>] (scenarios enumerated from the handbooks' matrix), a bare hatsu:bankai-rule for the ruling the session is discussing, or when a port composite (hiraishin, kamui — zheref/hatsu#357, #356) answers port-drift. Rulings are technology-level; ids are reserved against the tip, the run's branch, sibling branches and open PRs; one PR per port run; never merges.
---

**Shared policy:** [`PROCESS.md`](../../../docs/PROCESS.md) § *Standalone entry*.

# Bankai rule — a port ruling, recorded once

**Nature: Conjurer** — a ruling is canon (`CON-7`, `CON-13`), the maintainer's word, landed at
**G4**; **Manipulator** for the GitHub reads and the PR. Chrollo reviews pair files, never authors
them (ROSTER § *Rulings of 2026-09-09*).

`$hatsu_root` is the path ten § 0 printed, typed. Epic zheref/hatsu#354 (its rulings bind here);
brief zheref/hatsu#355; probes `docs/ab/bankai-rule.md`.

## 0. Standalone entry

Typed, or reached from a port composite at a `port-drift` answer (§ 5) — inside any composite, skip
this. [`STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md): **P1** `hatsu:ten bankai-rule`;
**P1b**, **P3 declined** (a ruling, not a delta); **P2**; **P4** the pair and ruling by § 1; **P5**
declared: no build, no merge, no write to the canon checkout.

## 1. Invocation — the pair enumerated, the ruling split off before the parse

```
hatsu:bankai-rule <from-scenario> to <to-scenario> [ruling <text>]
hatsu:bankai-rule                                     # the bare form
```

```bash
line=$(cat <<'EOF'
<the arguments, verbatim — a quoted heredoc: an apostrophe breaks nothing>
EOF
)
case "$line" in 'ruling '*) head=''; ruling="${line#ruling }" ;; *) head="${line%% ruling *}"; [ "$head" = "$line" ] && ruling='' || ruling="${line#* ruling }" ;; esac   # split at the FIRST whole-word ruling
[ -n "$head" ] && nen parse bankai-rule --grammar "<from:<ids off stack-matrix.md, |-joined>> to <to:<the same ids>>" --line "$head"
```

The scenario ids are read fresh off `handbooks/stack-matrix.md` at the pinned canon checkout
([`bankai-handbooks`](../bankai-handbooks/SKILL.md) §§ 0, 2), never from this file;
**`bankai-machinery` is refused** (not a product stack). Verified at nen `0.22.0` (`docs/ab` § 1): the
pair parses at exit `0`; a scenario outside the set is refused by name, exit `2`. **The split
precedes the parse** because nen anchors `to` and `ruling` on their *last* occurrence: a ruling
saying *maps to*, handed whole, is refused by the enumerated `<to>` — never mis-parsed — so the head
alone goes through `nen parse`; the shell split is residue (zheref/nen#458). **Totality:**

| Line | Then |
|---|---|
| `<from> to <to>` | the ruling the session is discussing, stated back; none → asked |
| `… ruling <text>` | the text stated back as the drafted row — source · target · handling — and confirmed |
| `ruling <text>` alone, or empty | the bare form: the session's pair (candidates asked) with the typed or discussed text |
| no handling, or a fifth | asked (`missing-argument`) with the four |
| a rationale naming a product, screen, business rule or object id | redrafted technology-level, stated back |
| `from` = `to`, or an ungoverned scenario | refused: a pair is directed; `handbook-question` (`CON-37`) |

## 2. What the run reads, and where it writes

`workflow.port.handbooksRepo` (default `zheref/bankai-handbooks`) and `workflow.port.rulingsDir`
(default `handbooks/ports`; `contracts/config-catalogue.json`, domain `port`) are **read at the
consumer's base tip, never its head**, and **bounded**: `handbooksRepo` is the consumer's pinned
`maintained_tools` row (`nen canon pin --source <handbooksRepo>`; none → `missing-configuration`), so
rulings and the matrix come from one home; `rulingsDir` is relative, `[A-Za-z0-9._/-]`, no `..`.

```bash
"$hatsu_root/scripts/config_values.sh" need --repo <consumer checkout> --skill bankai-rule   # ten § 6 step 5b
git -C <consumer checkout> show origin/<branch.base>:nen/workflow.json                       # the values are READ HERE
```

**Two checkouts, never one** (zheref/hatsu#354, *Checkouts*): the **reading** copy is `nen canon
checkout`'s, at the pin, clean, **never written**; the **authoring** clone is a separate clone at
`${XDG_CACHE_HOME:-$HOME/.cache}/hatsu/checkouts/<owner>/<repo>` — the cache path only, never typed —
refused (`missing-configuration`) when its realpath equals or sits under `nen canon checkout
--json`'s. **It must carry `nen/workflow.json`** (zheref/bankai-handbooks#4); absent,
`missing-configuration` naming the adoption. The rulings branch is cut under the clone's own
`.nen/worktrees/<surface>/` ([`breath`](../breath/SKILL.md) § 0), `{model}/{persona}/ports-<from>--<to>[-<run-id>]`,
**one per port run** (a `kamui` run is one across its builds, a `hiraishin` run one, a call one).

## 3. Reserve the id — against every place a row can be

The prefix is asked on the adoption PR (zheref/bankai-handbooks#4, open question 1; `PT-{n}`
proposed), **read from the pair file's `prefix:` header, never from this prose**; per-file or global
numbering is the same ruling: while the template reads `<prefix>` the run stops at **G5**
(`missing-maintainer-choice`).

```bash
"$hatsu_root/scripts/port_rule_reserve.sh" --clone <authoring clone> --target <owner/name> \
  --pair-file <rulingsDir>/<from>--<to>.md --prefix <the pair file's prefix> --json
```

It fetches, then reads the pair file at **four places**: `origin/<branch.base>`; **this run's own
branch** (HEAD and the working tree, so a batched call's second row never repeats its first); **every
other pushed `ports-*` branch** (an in-flight run has no PR yet); and every open PR whose **file list**
names the file. An id outside
`^[1-9][0-9]{0,8}$` is a named refusal (exit `3`); **exit `1` (an unread PR, a short list) reserves
nothing — stop, never write**. **Residue**: its `gh` reads, owed as zheref/nen#456. A collision found at
catch-up ([`ao`](../ao/SKILL.md)) is renumbered **only in this run's branch**, never after a merge,
**and the citing port PR's `(branch <ref>, unmerged)` citations are rewritten in the same step**. The
`port-rule-guard` lane proves the four reads and the hostile cases.

## 4. Write the ruling — the template, the row, the index

A pair with no file is created from `templates/ports/pair.md` (header, scope, the **equivalence** and
**drift** tables — the rows are the only counter) and added to `<rulingsDir>/INDEX.md` from
`templates/ports/INDEX.md`: file, count, last date. **Each row:**

| Column | What |
|---|---|
| `id` | `<prefix>-<n>` (§ 3); **never renumbered after a merge, never reused** |
| `source` | a rule id (`SW-`/`KT-`/`RC-`/`UX-`/`UZF-`/`SEC-`/`QA-`/`REL-`) or a **named technology concept** |
| `target` | the equivalent id or concept on the `to` stack, or `none` |
| `handling` | `map` · `mirror` · `drop with note` · `target-only addition` — § 5's four, no fifth |
| `rationale` | **technology-level**: stacks, rules, idioms, the reason — **never** a product, screen, business rule, object id or private repository |
| `date` | `YYYY-MM-DD` |
| `supersedes` | `<id>` where this row reverses one; **the old row is never edited** |

`map`/`mirror` rows fill the equivalence table, the other two the drift table. **Before any write**: `bash "$hatsu_root/scripts/private_name_check.sh" --ignore-file <d>/redaction-ignore <pair file>
<INDEX.md>` ([`file`](../file/SKILL.md) § 4's ignore file, from Hatsu's checkout); then `nen shu lint
--repo <authoring clone>` — on `zheref/bankai-handbooks`, `scripts/canon_check.sh all` (redaction,
links, taxonomy), **which exists once its adoption PR has merged**; before that the verb refuses at
exit `2` and the run stops at row `missing-tool` — and [`kokusen`](../kokusen/SKILL.md) on the clone,
`--type feat --scope ports`, trailer `Hatsu-Agent: kurapika`.

## 5. `port-drift` — one picker call per run, three questions a call

When a port composite meets rows with no target equivalent, every unmapped row of the run goes into
**one** picker call (`nen/decisions.json` row `port-drift`, `ask-once-per-run`; jutaisho § 4's shape):
each question names the source rule or concept and the target stack; options in the row's order,
**A** `map to <nearest equivalent, from the target handbook>` ⭐ · **B** `mirror` · **C** `drop with
note` · **D** `target-only addition`; **three questions a call**, a fourth row opens a second call; no
derivable equivalent stars **C** with the reason. A free-text answer is the row's
`rationale`, through § 1's totality rows. Every answer binds the port **the moment it is given**,
before any PR exists, and becomes one row through §§ 3–4.

## 6. The PR — one per port run, opened once, at G4

Rulings accumulate on the branch through the run; **the PR opens once, non-draft, at the run's end**
through [`aka`](../aka/SKILL.md) → [`mukai`](../mukai/SKILL.md) on the authoring clone (ROSTER §
*Rulings of 2026-10-04 — interactive runner pools*: shibari opens no draft) and runs
[`en`](../en/SKILL.md) to the **G4** prompt, Nobunaga raised (Chrollo on `handbooks/**`). Standalone,
one PR per call. **Until it merges the citing port PR writes `<from>--<to> <id> (branch <ref>,
unmerged)`**, and its landing report names the follow-ups: Hatsu's repin (`nen/repos.json` →
`pinned`, tag first, `CON-13`) and **each consumer's `nen canon pin` with a follow-up rewriting its
unmerged citations** to `<from>--<to> <id> @ <tag>`, an owed row on the epic.

**Reading a pair file for review.** `nen canon resolve` (`0.22.0`) returns always-load plus one stack
and **no mirror carries a pair file**: a reviewer reads it live through
[`bankai-handbooks`](../bankai-handbooks/SKILL.md) § 2 — existence checked on the canon checkout, the
path accepted and echoed by `--always-load` — until zheref/nen#457 resolves and mirrors it
([`limbo`](../limbo/SKILL.md) step 4). The preamble's prefix list moves in Hatsu's repin PR.

## 7. Report

```
<from> → <to>  ruling <id>  <handling> · file (created | appended) · INDEX <row added | count moved>
  reserved against: tip <sha> · branch · <n> sibling branches · open PRs <#a | none>
  branch: <ref> on <authoring clone> · PR: <none yet | <owner/name>#<N>> · cite as: <from>--<to> <id> (branch <ref>, unmerged)
```

Under a composite, back to the caller; standalone, § 6's PR and `en`'s prompt. **Readiness is `nen
pr ready`'s verdict.**

## Residue

The `ruling` split (§ 1, zheref/nen#458); the `gh` reads (§ 3, zheref/nen#456); the pair file through
`--always-load` (§ 6, zheref/nen#457); the clone's `git clone` (`bankai-handbooks` § 0's carve-out); the
prefix and numbering scope (zheref/bankai-handbooks#4).

## Authority

- **Permitted:** read the canon checkout at the pin; clone and branch the authoring clone; read open
  PRs and pushed rulings branches; write a pair file and its INDEX row from the maintainer's answers;
  the guard, lint and kokusen on the clone; **one** PR per port run through aka → mukai → en.
- **Not permitted:** merge; write the canon checkout or a mirror; edit or renumber a merged row;
  invent a ruling; a draft PR; a second PR in one run; an improvised `nen` verb.

## Hard limits

- **Never writes a row without the maintainer's answer**, stated back first, nor on an exit-`1` read.
- **Never parses the ruling text through the grammar**; never a scenario the matrix does not list,
  never `bankai-machinery`; never a `handbooksRepo` that is not the pinned row, never the keys from
  a branch head; never a write outside the clone or into the reading copy.
- **Never edits a merged row** (a reversal is a new row with `supersedes`); never reuses an id.
- **Never opens the PR before the run ends, never as a draft, never twice; never merges** (`CON-7`).
