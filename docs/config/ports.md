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
| `caller` | `kamui` \| `hiraishin` | the skill whose `resume` grammar continues it |
| `runId` | string | equal to the file's basename; `^(kamui\|hiraishin)-[a-z]{2,3}-(is\|pr)-[0-9]+-[0-9]{8}$` (`<caller>-<code>-<is\|pr>-<n>-<yyyymmdd>`, lowercase, the source object's `#` dropped) |
| `source` | string | the source object in object notation (`RA-IS-#12`) |
| `family` | string | the family's `name` as the spec repository declares it |
| `specRepo` | string | `owner/name` of the family's spec repository |
| `specPr` | string \| null | the spec PR in object notation, null before it opens |
| `targets[]` | object[] | one per sibling the maintainer picked: `code`, `issue` (object notation or null), `pr` (object notation or null), `state` (`filed` · `amended` · `started` · `stopped` · `delivered`) |
| `next` | string | where the run continues. **kamui**: `setup` · `spec` · `wait` · `siblings` · `start` · `done` · `declined`. hiraishin adds its own with its own skill |
| `at` | string | ISO-8601 UTC of the last write |

**Every `resume <run-id>`**, before reading anything: the argument matches `runId`'s pattern (else refused: the shape is quoted, nothing is read — no path is ever built from an unchecked token); the file parses, its `schema` is the one above and its `runId` equals the argument (else refused naming the path); then **the step is recomputed from live state, never taken from `next` alone** — `siblings` or `start` require `gh pr view` of `specPr` in `specRepo` to read `MERGED` and its body or spec folder to cite `source`, otherwise the run continues at `wait`. A `next` of `done` or `declined` is reported as finished and nothing runs. A missing file is refused naming the path it looked for.

## Sources

- epic zheref/hatsu#354, *Constraints* (checkouts, records and resume) and the round-2 settlements; brief zheref/hatsu#356
- [`../../claude/skills/kamui/SKILL.md`](../../claude/skills/kamui/SKILL.md) §§ 2, 6
- [`repos.json.md`](repos.json.md) § `families[]`
