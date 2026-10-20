# Port runs — the checkouts file and the run record

> **Lives in** the maintainer's own XDG directories, **never in a tree** (epic zheref/hatsu#354, *Constraints*: checkouts and records) · **Written by** `hatsu:kamui` (zheref/hatsu#356), which defines both shapes first; `hiraishin` (zheref/hatsu#357) and `bankai-rule` (zheref/hatsu#355) **cite this page and never redefine it** · **Validated by** the readers' own checks below — nen models neither file (no verb reads them at `0.22.0`).

## What it decides

A port run outlives a session: it waits on a spec PR at **G2**, on setup declaration PRs, on builds in other repositories. Two files carry it across sessions and checkouts. The **checkouts file** says where each repository of a product family is checked out on this machine, so a run in one checkout can author in another. The **run record** says where a run stopped, so `resume <run-id>` continues it from any checkout. Both sit outside every worktree, so `hatsu:cleanup` never removes them, and both hold **pointers, never truth**: every reader re-reads live state before acting.

## The checkouts file

`${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/checkouts` — plain text, one repository per line, **tab-separated** (a path may contain spaces), `#` lines comments:

```
<owner>/<name>	<absolute path to its core checkout>
```

| Rule | What the reader does |
|---|---|
| **Every `<owner>/<name>`, before a path or a command is composed from it** | must match `^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$`, else refused as `missing-configuration` |
| A repository with no line | asked once, typed (`missing-configuration`), written with the surface's file tool; or, the maintainer declining, `gh repo clone <owner>/<name>` into `${XDG_CACHE_HOME:-$HOME/.cache}/hatsu/checkouts/<owner>/<name>` |
| **Every path, from the file or the cache, before any read or write in it** | `git -C <path> remote get-url origin` must resolve to exactly `<owner>/<name>` (SSH or HTTPS form); a mismatch, a missing directory or a malformed line is refused naming the line — `missing-configuration`, never a guess, never a re-clone over it |
| A spec repository's checkout | additionally `gh repo view <owner>/<name> --json visibility` reads `PRIVATE`; otherwise refused (product specification never enters a public tree) |
| Worktrees | always under that checkout's own `.nen/worktrees/<surface>/` ([WORKFLOW](../WORKFLOW.md) § *Where worktrees live*) |
| `zheref/bankai-handbooks` | its **reading** copy is only `nen canon checkout`'s; its **authoring** clone for a rulings PR is the cache path, never the canon checkout (epic, *Constraints*) |

## The run record

`${XDG_STATE_HOME:-$HOME/.local/state}/hatsu/ports/<run-id>.json` — one file per run, written whole with the surface's file tool at every step boundary. **A `--dry-run` writes no record.**

| Field | Type | Meaning |
|---|---|---|
| `schema` | string | exactly `hatsu.port.run/v0.1`; any other value is refused |
| `caller` | `kamui` \| `hiraishin` | the skill whose `resume` grammar continues it; a `resume` by the other skill is refused |
| `runId` | string | equal to the file's basename; `<caller>-<code>-<is\|pr>-<n>-<yyyymmdd>[-<ordinal>]`, lowercase, the source object's `#` dropped — the exact pattern below |
| `source` | string | the source object in object notation (`RA-IS-#12`) |
| `family` | string | the family's `name` as the spec repository declares it |
| `specRepo` | string | `owner/name` of the family's spec repository |
| `specPr` | string \| null | the spec PR in object notation (kamui's own, or an open one it amended), null before it opens and on the no-diff route |
| `specFolder` | string \| null | the feature's folder (`specs/<nnn>-<slug>`); set when the run found it on `origin/<base>` already current and opened no PR |
| `targets[]` | object[] | one per sibling the maintainer picked, plus the source issue once the start picker picks it: `code`, `issue` (object notation or null), `pr` (object notation or null), `state` (`filed` · `amended` · `started` · `stopped` · `delivered`) |
| `next` | string | where the run continues. **kamui**: `setup` · `spec` · `wait` · `siblings` · `start` · `done` · `declined`. hiraishin adds its own with its own skill |
| `at` | string | ISO-8601 UTC of the last write |

The run id's pattern, outside the table so its alternation reads as written (`grep -Ex` and Python `re.fullmatch` both accept `kamui-fi-is-7-20261020` and `kamui-fi-is-7-20261020-2`, and refuse `../planted`):

```
^(kamui|hiraishin)-[a-z]{2,3}-(is|pr)-[0-9]+-[0-9]{8}(-[0-9]+)?$
```

**Every `resume <run-id>`**, before reading anything: the argument matches that pattern (else refused: the shape is quoted, nothing is read — no path is ever built from an unchecked token); the file parses, its `schema` is the one above and its `runId` equals the argument (else refused naming the path); then **the step is recomputed from live state, never taken from `next` alone** — `siblings` or `start` require **either** `gh pr view` of `specPr` in `specRepo` reading `MERGED`, **or** `specFolder` present on `specRepo`'s `origin/<base>` — in both cases the folder's `spec.md` citing `source` — otherwise the run continues at `wait` (or at `spec`, with neither). A `next` of `done` or `declined` is reported as finished and nothing runs. A missing file is refused naming the path it looked for. **A fresh invocation whose `runId` already has a record** (the same source, the same day) never overwrites it: a record not yet `done`/`declined` is offered as `resume <run-id>` (`missing-argument`); a finished one takes the id with an ordinal suffix `-2`, `-3`, ….

## Sources

- epic zheref/hatsu#354, *Constraints* (checkouts, records and resume) and the round-2 settlements; brief zheref/hatsu#356
- [`../../claude/skills/kamui/SKILL.md`](../../claude/skills/kamui/SKILL.md) §§ 2, 6
- [`repos.json.md`](repos.json.md) § `families[]`
