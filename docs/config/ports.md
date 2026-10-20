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
| `family` | string \| null | the family's `name` as the spec repository declares it; **null on hiraishin's *spec step: none configured* route** |
| `specRepo` | string \| null | `owner/name` of the family's spec repository; null with `family` |
| `specPr` | string \| null | the spec PR in object notation (kamui's own, or an open one it amended), null before it opens, on the no-diff route and with no spec repository |
| `specFolder` | string \| null | the feature's folder (`specs/<nnn>-<slug>`); set when the run found it on `origin/<base>` already current and opened no PR |
| `targets[]` | object[] | one per sibling the maintainer picked, plus the source issue once the start picker picks it: `code`, `issue` (object notation or null), `pr` (object notation or null), `state` (`filed` · `amended` · `started` · `stopped` · `delivered`) |
| `next` | string | where the run continues. **kamui**: `setup` · `spec` · `wait` · `siblings` · `start` · `done` · `declined`. hiraishin adds its own with its own skill |
| `at` | string | ISO-8601 UTC of the last write |

The run id's pattern, outside the table so its alternation reads as written (`grep -Ex` and Python `re.fullmatch` both accept `kamui-fi-is-7-20261020` and `kamui-fi-is-7-20261020-2`, and refuse `../planted`):

```
^(kamui|hiraishin)-[a-z]{2,3}-(is|pr)-[0-9]+-[0-9]{8}(-[0-9]+)?$
```

**Every `resume <run-id>`**, before reading anything: the argument matches that pattern (else refused: the shape is quoted, nothing is read — no path is ever built from an unchecked token); the file parses, its `schema` is the one above and its `runId` equals the argument (else refused naming the path); **its `caller` equals the resuming skill**, else refused naming the other skill's resume line (`hatsu:kamui resume <run-id>` / `hatsu:hiraishin resume <run-id>`); then **the step is recomputed from live state, never taken from `next` alone**, per caller: **kamui** — `siblings` or `start` require **either** `gh pr view` of `specPr` in `specRepo` reading `MERGED`, **or** `specFolder` present on `specRepo`'s `origin/<base>` — in both cases the folder's `spec.md` citing `source` — otherwise the run continues at `wait` (or at `spec`, with neither); **hiraishin** — the same two readings admit `start`, and so does `specRepo` null (*spec step: none configured*); its `setup` is § 2's unported-prerequisite stop (kamui's `setup` is a declaration PR), each resumed at its own section. **Ordinals**: a fresh invocation whose `runId` already has a record not yet `done`/`declined` is offered as `resume <run-id>` — except a hiraishin run for the same source and a **different `targets[0].code`**, which takes the next free `-<ordinal>` (one record per target); a finished record always yields the next ordinal.

**Modes and retention.** `hatsu/ports/` is created `0700` and every record and the checkouts file are written `0600` (they hold private repository slugs, local paths and object ids, never a token); a record is never removed by a port run — `hatsu:cleanup` offers `done`/`declined` records older than 30 days as proposed rows, naming each. A slug that is exactly `.` or `..` is refused with the pattern. No `fixture-owner/` slug (`PUBLIC-REDACTION.md`'s legend) ever reaches a networked command: the fixtures are offline inputs to `nen parse`, `nen schema check` and `config_values.sh` only.

## Shared conventions — stated once, cited by both skills

| Convention | Rule |
|---|---|
| **Port issue title** | `port: <source title> (from <CODE>-<IS\|PR>-#<N>)`, the source in object notation; kamui § 5 and hiraishin § 7 file with it, and hiraishin § 2's port-of-port, prerequisite and already-ported reads search `(from <CODE>-<IS\|PR>-#<N>)` as a fixed string. A `nen issue search` exit `1` is a refusal with the verb's line quoted, never *no port* |
| **A PR as the source** | `gh pr view <N> --repo <source> --json state,mergedAt,baseRefName`: only `mergedAt` set **and** `baseRefName` equal to the source's `branch.base` (absent, `main`) proceeds — the ruling *Merged into base only*; refused naming the state (*open*; *closed, not merged*; *merged into `<base>`*). Both skills, before any write |
| **Until zheref/hatsu#355 lands** | `file` § 4's own confirmation stands before each port-issue filing (kamui § 5 per pick, hiraishin § 7), and a behaviour with no target idiom stops that run or build at *port-drift not landed*; the clause and the row land with `bankai-rule` |
| **Visibility, re-read before every write** | `gh repo view <owner/name> --json visibility` on the target right before a filing or a build start: anything but `PRIVATE` drops that sibling, said; a private source ported to a public target is **refused** (SEC-8) — no placeholder route |
| **Slug, number and layout** | `{slug}` matches `^[a-z0-9]+(-[a-z0-9]+)*$`, `{nnn}` `^[0-9]{3}$`; a `layout` containing `..`, starting with `/` or resolving outside its first path segment is refused; the folder search runs under that first segment, never a hard-coded `specs/` |
| **Source text in a spec** | verbatim issue or PR text enters `spec.md`/`tasks.md` only inside fenced blocks labelled *source data*, never as imperative task lines (SEC-15); the spec PR's reviewers check it |
| **The watch read-back** | after `nen watch until` exits `0`, `gh pr view … --json state`: `MERGED` continues, `CLOSED` ends the run *spec declined*; anything else returns to `wait`; a `gh` failure is reported, never read as a state |
| **The two multi-select pickers on Codex** | `request_user_input` takes at most three single-select questions a call, so on the Codex CLI `port-siblings` and the start picker ask **one yes/no question per item, pages of three**; Claude Code (`multiSelect`), Cursor (`allow_multiple`) and Antigravity (`is_multi_select`) take the multi-select form paged in fours (jutaisho § 4) |
| **`run_id` validation** | whole-string, newline-refusing: Python `re.fullmatch` or an equivalent that refuses any whitespace inside the token; `grep -Ex` alone accepts a newline-spanning token and is not the validator |
| **A dangling `to`** | `nen parse` drops a trailing `to` with no code at exit `0` (zheref/nen#366): the skill refuses when the target slot is absent while the raw line's last token (before `--dry-run`) is `to` |
| **A build's end** | kamui § 7 and hiraishin § 8 hold `build`'s phase 6 (the wrap-up), while en § 8's `rikugan` renders as usual; a G5 stops the chain; any other end (`direct-mismatch` **B**, an existing PR handed to `en`) is recorded `stopped` and the chain continues; an off-surface pick answers build § 2b's `direct-mismatch` *continue* from that decision | A `next` of `done` or `declined` is reported as finished and nothing runs. A missing file is refused naming the path it looked for. **A fresh invocation whose `runId` already has a record** (the same source, the same day) never overwrites it: a record not yet `done`/`declined` is offered as `resume <run-id>` (`missing-argument`); a finished one takes the id with an ordinal suffix `-2`, `-3`, ….

## Sources

- epic zheref/hatsu#354, *Constraints* (checkouts, records and resume) and the round-2 settlements; brief zheref/hatsu#356
- [`../../claude/skills/kamui/SKILL.md`](../../claude/skills/kamui/SKILL.md) §§ 2, 6; [`hiraishin/SKILL.md`](../../claude/skills/hiraishin/SKILL.md) §§ 2–4; the integration review of 2026-10-20 (hanten on `integration/ha-354-porting`), which moved the shared conventions here
- [`repos.json.md`](repos.json.md) § `families[]`
