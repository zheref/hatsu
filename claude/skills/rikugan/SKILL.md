---
name: rikugan
description: Render one turn of work as a rich HTML page from templates/rikugan.html, never a markdown summary — the desk above the fold, this last turn, what landed, fought back and was not delivered, the architecture delta drawn from a nodes-and-edges graph, evidence, the launch line, decisions. Use when the maintainer invokes hatsu:rikugan [as turn|landing], asks to see the report, or whenever hatsu:ren, hatsu:mukai or hatsu:en reaches its reporting step. Which blocks each variant renders is configuration (reports.sections). The dated final report is now a one-effort Spiritual Message through hatsu:backlog-board. Not a gate event: it publishes a page and rings nothing.
---

**Shared policy** (`docs/*.md`) lives at the Hatsu plugin root `hatsu-warmup` prints; a missing
consumer copy is never a filing.

# Rikugan — the turn, seen

**Nature: Manipulator.** The nature of the work being *reported* is stated inside the page, never
adopted by this skill.

> **What does this turn need from me, and what did the last request actually do?**

Rikugan is [`ren`](../ren/SKILL.md)'s fifth step, [`mukai`](../mukai/SKILL.md)'s handover artifact
and [`en`](../en/SKILL.md)'s first. **The desk comes first, directly under the tally** — the one
thing only the maintainer can do is not the ninth thing they read (audit of 2026-09-19). **It is
never markdown**: a chat summary scrolls away; a page has an address.

## 0. Standalone entry

Reached from a composite, skip this. Reached bare, the contract is
[`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md); Rikugan inherits `S1` and `S3`.
Every block is evidence-sourced or **marked unavailable** — with no recoverable turn boundary, the
block reads `this last turn: not recoverable`.

## 1. Invocation

```
hatsu:rikugan [as <turn | landing>] [against <base>]
```

Parse it with `nen parse rikugan --grammar "as [<variant:turn|landing>] against [<base>]"`. The
clause is anchored behind the literal `as` because a bare-bracket leading slot is refused at exit `2`
(`docs/ab/rikugan.md` § 2.1). Default **`turn`**. With no `against` clause the base is
`origin/<branch.base>` after `git fetch origin`, named on the page with its short SHA. **A local
branch name is never the base** — local `main` has measured 72 commits stale on a stopped turn, and
the delta then belongs to somebody else.

## 2. The variants

| Variant | Called by | Publishes |
|---|---|---|
| **`turn`** | `ren` step 5, every turn | what `reports.sections.turn` declares |
| **`turn-fast`** | the same step **under the fast profile** | the desk and the last turn, nothing else |
| **`landing`** | `mukai` step 9 (after `gh pr create` returned) and `en`'s first step | the turn blocks **+ the PR body**, the verdict quoted inside the ask |

**There is no `final` here any more.** The dated final report is a **one-effort Spiritual Message
with a cleared desk**, rendered through [`backlog-board`](../backlog-board/SKILL.md) § 3 as variant
`final` into `<reports.dir>/<YYYY-MM-DD>-<effort>.html` (ruling of 2026-09-19). Hand over and say so.

After [`hatsu:aka`](../aka/SKILL.md) — pushed, no PR — re-render `turn` at the same address with the
push in *Landed*. There is no fourth variant for a pause.

## 3. The parameters

Read them from the target's `nen/workflow.json`; never a remembered value, never `jq`. A file
`nen schema check` FAILs is quoted with its pointer and the defaults used out loud.

| Key | Used for | Default |
|---|---|---|
| `reports.dir` / `.template` / `.captures` | where a kept report goes, which template, where captures are read | `Reports` / `rikugan` / `<dir>/captures` |
| `reports.sections.<variant>.blocks` | **which blocks this variant renders** | none declared → every block |
| `coverage.minimum` / `.recommended` / `.ideal` | the band on a coverage row | `80` / `85` / `90` |
| `branch.base` | the base the delta is measured from | `main` |

**Reporting does not schedule verification.** Use what the owning phase produced (`coverage: not due
until mukai`); reading `coverage.*` configures presentation, never permits running it. Evidence whose
source-tree identity is not the current one is marked **stale**.

## 4. Assemble the data

```bash
nen report data --repo <path> --base origin/<branch.base> [--tiers <json>] [--target <owner/name> --prs <n,...>] --json
```

One `nen.report.data/v0.1` document: `commits[]`, `files[]`, `evidence[]`, `coverage`, `proof`,
`lastStop`, the header fields, plus `objects[]` where a target was named. It never writes; **every
absence is `null` with the reason on stderr**, quoted rather than replaced, and an unresolvable base
is exit `2` rather than an empty branch. Three companions fill what git cannot know:
`nen shu evidence --base <ref>` (each row gaining `src`, the capture as a `data:` URI),
`nen shu test-report --from-artifacts` (`tests[]`), and the **saved** mukai/byakugan
`nen shu coverage --touched` result (`touchedCoverage[]` with nen's band).

**The merge shape — the base document ∪ the extension, every key always present, empty where there
is nothing.** A key the data has not got is exit `2` by design, because a blank cell reads as a fact.

```
<base data> ∪ { variant, title, gate, footerNote,
  tallyNeedsYou, tallyBlockers, tallyLanded, tallyGaps, deskCleared,
  ask: null | { kind: DECIDE|DO|MERGE, gate, question, whyNow, blocker, objects[{label,url}],
                options[{letter,label,command,consequence,star,starredClass}] },
  readiness[{verdict,reason,gate}], lastTurnRequest, lastTurnRequestFull,
  lastTurnHighlights[{text,outcome,outcomeClass,why}], mukaiLastTurn,
  lastTurnCorrections[], lastTurnCheckIssues[], lastTurnStops[],
  accomplished[{text,why}], challenges[], notDelivered[], decisions[],
  architectureCaption, graphJson, graphMermaid, graphNodes[], graphEdges[],
  captures[{role,alt,src}], evidenceUnavailable, tests[], touchedCoverage[],
  phases[{lane,percent,amount}], usage, launch, prBody[{markdown}] }  → <data file>
```

`--variant` injects `sections.<block>` and `sectionList` on top. `star` is `" ⭐"` on exactly one
option and `""` on the rest, `starredClass` `"starred"` there and `""` elsewhere; `usage` is the
string `not reported` when no ledger was read — never an omitted key, never a guessed number.

**The ask is the desk.** One ask per turn at most, opening `DECIDE`, `DO` or `MERGE`, carrying the
Crazy Slots options with one star and **the `nen pr ready` verdict quoted verbatim**. A turn owing
nothing sets `ask: null` and writes `deskCleared`. A G5 puts its evidence **inside the ask**
(`ask.blocker`: `rule`, `step`, `executedAfter`, `why`, `nextAction`, `findings[]`) — a stop the
maintainer cannot understand from the page is defective ([hatsu#56](https://github.com/zheref/hatsu/issues/56)).

## 5. The graph document — the delta as nodes and edges

The delta is **conceptual and session-wide**, never a file list; one-file-one-node is the old defect.
Author it as `nen.report.graph/v0.1` — `{ contract, caption, nodes[{id,label,kind,change}],
edges[{from,to,rel,change}] }`, whose worked shape is
[`templates/graph.example.json`](../../../templates/graph.example.json).

`change` is `added | changed | removed | unchanged` on nodes and edges alike; every edge endpoint
names a declared node. `nen report render --graph <file>` validates it and injects `graphJson`,
`graphMermaid`, `graphNodes[]`, `graphEdges[]`. The page draws it with dagre pinned from cdnjs under
an integrity hash; the `<details>` list under it is the text fallback. **Do not hand-build SVG and do
not write a second renderer.**

## 6. Fill the template

```bash
nen report render --variant <turn|turn-fast|landing> --graph <graph file> \
  --template templates/rikugan.html --data <the § 4 document> --out <reports.dir>/current.html --repo <path>
```

The whole language: `{{token}}` (escaped), `{{{token}}}` (raw), `{{#each list}}…{{/each}}` with
`{{.}}` and `{{@index}}`, `{{#if key}}…{{/if}}`. No helpers, partials or expressions. An unknown
token is exit `2` naming it; `null` renders empty; an object at a value tag is refused. `--dry-run` reads the
file exactly as the render does and proves a template against a document before it ships.

**Escaping binds both paths.** Every value is repository-controlled, so every value is escaped; the
raw form is admitted for **one** slot, the graph document in its JSON script tag. Two checks escaping
cannot do stay the **caller's**: a capture source against
`^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$` and a bar percentage against
`^(100|[0-9]{1,2})(\.[0-9]+)?$`; a failing value is dropped and the gap named in *Not delivered*.
**A template never spells a substitution tag in its own comments** (F12) — the renderer substitutes
over the whole file, comments included.

**The PR body's diagram comes off the same graph** — `nen report mermaid --graph <file>`, which
[`shibari`](../shibari/SKILL.md) § 3 pastes. This skill does not paste it twice.

## 7. Publish it

**On Claude Code the page is an Artifact, republished to ONE URL per branch** — update the branch's
report in place; a new URL only for a branch with none. **Read before you overwrite**: a republish
notice, or a version this session did not publish, means the page moved. On any other surface it is
opened from `<reports.dir>/current.html`, overwritten by every render, git-ignored, **transient
rather than retained**. Say which of the two happened.

The title is the object notation and the branch, from `nen repo resolve` and `nen ref format` —
**never from memory**. Both read the target's `nen/repos.json` (missing registry: exit `2`;
unresolved token: exit `1`); the fallbacks are `<owner>/<name> · <branch>` and `<owner>/<name>#<n>`,
with **the failed resolution in `footerNote`**.

**Say one line in chat and stop** — the variant, the branch, the link or the path. **When a block
cannot be filled**, render without those rows, show its empty-state line and name the gap in *Not
delivered*; if no page can be produced, say so. **A markdown recap is never the fallback.**

## 8. Not a gate event, and the authority it holds

No `nen stop` banner, no efforts table, no push notification — the maintainer is already looking at
it. The bell is [`jutaisho`](../jutaisho/SKILL.md)'s, runs *after* this skill in `ren`'s order, and
takes this page's link. A real stop coming due while the report renders fires normally.

- **Permitted:** read the working copy, its history and `nen/*.json`; publish or republish **this
  branch's** report Artifact; write under `<reports.dir>`.
- **Not permitted:** anything else on disk, any GitHub write, any label, any merge, any push.
- **Carries no `CON-25`-equivalent delegation**; being invoked from a composite lends none.

## Hard limits

- **Never renders the report as markdown**, or lets a chat summary stand in for it.
- **Never writes outside `<reports.dir>`**, and never gives a `turn` or `landing` render a kept file.
- **Never claims readiness by eye** — the verdict is `nen pr ready`'s, quoted, or absent.
- **Never omits the desk**, or `ask` from the data — `null` or the § 4 object.
- **Never fills the session blocks from only the last request**, never puts earlier-turn work into
  *this last turn*, never drops a gap from *Not delivered* to make a session read better.
- **Never renders the delta as a file list**, and never renders `landing` before the PR exists (F6:
  its extras are shibari's, and an empty verdict reads as `not-ready`) or while a review round is owed.
- **Never fires the `nen stop` banner, the efforts table or a push notification** (§ 8), and never
  links a capture a reader off this machine cannot resolve.
- **Never writes an unescaped value into the page**, and never uses the raw form for anything but the
  validated graph document (§ 6).
- **Never renders the dated final report itself** — [`backlog-board`](../backlog-board/SKILL.md) § 3.

*History and retired findings moved to this effort's history file; `docs/ab/rikugan.md` has the
dated live verifications.*
