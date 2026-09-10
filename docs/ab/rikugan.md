# A/B evidence — `rikugan` (new skill, wave 2)

`claude/skills/rikugan/SKILL.md` plus `templates/rikugan.html`: the turn / landing / final report,
rendered as one HTML page from one fixed template and published at one address per branch.

**A new skill, so there is no "old mechanics" column.** What this record establishes instead is
which of rikugan's deterministic steps `nen` owns **at the pinned ref** and which are residue — and
for a skill whose entire P1 verb family does not exist yet, that distinction is the whole document.

Run: 2026-09-09 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
Every mutating verb was exercised against a **constructed throwaway fixture** at
`<worktree>/.nen-fixture` — a `git init`'d repo carrying a hand-written `nen/contract.json`
`project` block, with a bare `<worktree>/.nen-fixture-origin.git` standing in for a remote — created
for this run and deleted before the branch was committed. Read-only verbs were additionally run
against `hatsu`'s own checkout. **No verb was run against any primary checkout in a way that could
write to it, and nothing was pushed to any remote.**

Nothing below is redacted; both repositories are public.

---

## 1. The skill

Rikugan renders one turn of work as a self-contained HTML page — **01 Accomplished · 02 Challenges ·
03 Not delivered · 04 Architecture delta · 05 Screenshots · 06 How to launch · 07 Decisions** — with
two variant additions (**08 PR body + 09 Readiness** for `landing`; **10 Tests run + 11 Touched
coverage** for `final`). It is `hatsu:ren`'s fifth step, `hatsu:mukai`'s handover artifact and
`hatsu:en`'s first and last.

| Step | Owned by | State at `v0.3.0` |
|---|---|---|
| Parse the invocation | `nen parse rikugan --grammar "as [<variant:…>]"` | **verb** (§ 2.1) |
| Read the parameters | `nen/workflow.json` | **read as data** — unvalidated (§ 2.4) |
| Assemble the data | `nen report data` | **absent** → residue (§ 2.2, § 3.1) |
| Evidence rows | `nen shu evidence --base <ref>` | **absent** → residue (§ 2.2, § 3.3) |
| Test rows (final) | `nen shu test-report` | **absent** → residue (§ 2.2, § 3.4) |
| Coverage rows (final) | `nen shu coverage --touched --base <ref>` | **absent** → residue (§ 2.2, § 3.5) |
| Render the page | `nen report render --template` | **absent** → residue (§ 2.2, § 3.2) |
| Publish it | the surface's Artifact tool | **not nen's, ever** (§ 3.7) |
| Object notation in the title | `nen ref format` / `nen repo resolve` | **verb** (cited, not re-run — `docs/ab/tensho.md` § 2.7, § 2.9) |
| Readiness (landing/final) | `nen pr ready … --explain` | **verb** (cited — `docs/ab/pr-state.md` § 2.1) |

**Seven deterministic steps; two are verbs today, five are residue, and every one of the five is a
verb this repository expects at `v0.4.0`** (brief § 4, P1 items 3–6). That ratio is the reason this
skill's `## Residue` section is longer than most.

---

## 2. Verbs exercised live

### 2.1 — `nen parse rikugan`: the bare-bracket refusal, and the anchored form that works

```
$ nen parse rikugan --grammar "[<variant:turn|landing|final>]" --line ""
nen parse: template '[<variant:turn|landing|final>]' is refused: its leading slot <variant> is
bracketed but nothing introduces it, so an omitted value cannot be told apart from a mistyped one.
Anchor it behind a literal ('word [<variant>]') or drop the brackets.
Run 'nen parse --help'.
exit=2
```

```
$ nen parse rikugan --grammar "as [<variant:turn|landing|final>]" --line "as landing"
variant: landing
exit=0

$ nen parse rikugan --grammar "as [<variant:turn|landing|final>]" --line "as"
exit=0                                  # parses, clause absent -- the default applies

$ nen parse rikugan --grammar "as [<variant:turn|landing|final>]" --line "as interim"
nen parse: <variant> is one of turn | landing | final (case-insensitively), and 'interim' is none of
them. It is resolved, never guessed at: the closest match is not the answer.

Corrected line:
  rikugan as <variant: turn | landing | final>
exit=2
```

This reproduces, at `v0.3.0`, exactly the engine behaviour `claude/skills/tensho/SKILL.md` § 1
records as *"refused at the template, by design"*. **Tensho concluded that its own grammar therefore
stays prose** (its optional word has no introducing literal to anchor to). **Rikugan concluded the
opposite** — give the clause a literal (`as`) and let the verb own the parse — which is why § 1 of
the skill file carries a `nen parse` invocation and tensho's does not. Same engine, two different
grammars, two different correct answers.

### 2.2 — The four missing P1 verbs, each refused live

```
$ nen report data --repo <fixture>
nen: unknown command 'report'.
Run 'nen --help'.
exit=2

$ nen report render --template x.html --data d.json --out o.html
exit=2                                  # same refusal: the family does not exist

$ nen shu evidence --repo <fixture> --base main
nen shu: unknown option '--base'. Known options here: --branch <value>, --discard, --dry-run,
--from <value>, --help, --install, --json, --lane <value>, --only <value>, --repo <value>, --run,
--target <value>, --tests, --threshold <value>, --write.
Run 'nen shu --help'.
exit=2

$ nen shu test-report --repo <fixture>
nen shu: unknown 'shu' subcommand 'test-report'. Known: detect, build, test, ui-test, lint, archive,
release, dev, run, deploy, coverage, tools, warmup.
Run 'nen shu --help'.
exit=2

$ nen shu coverage --repo <fixture> --touched --base main
nen shu: unknown option '--touched'. Known options here: --branch <value>, --discard, --dry-run,
--from <value>, --help, --install, --json, --lane <value>, --only <value>, --repo <value>, --run,
--target <value>, --tests, --threshold <value>, --write.
Run 'nen shu --help'.
exit=2
```

Four refusals, four different shapes — an unknown *command*, an unknown *subcommand*, and twice an
unknown *option* — and each names what does exist. `nen shu --help`'s verb list is quoted in the
`test-report` refusal above and is the authority: `detect build test ui-test lint archive release
dev run deploy coverage tools warmup`. **There is no `evidence`, no `test-report`, and `coverage`
has no `--touched`.**

### 2.3 — `nen shu test --dry-run`: the shape the evidence rows will eventually be parsed from

Against the fixture's declaration (`project.verbs.app.test = {exe: "echo", argv: ["fixture-test"],
artifacts: ["reports/junit.xml"]}`):

```
$ nen shu test --repo <fixture> --dry-run
lane:          app  (nextjs)
verb:          test
host:          darwin -- supported (the declaration constrains no platform)
preconditions: (none declared)
would run:     echo fixture-test
cwd:           <fixture>
env:           (none added)
artifacts:     reports/junit.xml (absent)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit
               code to report.
exit=0
```

```
$ nen shu test --repo <fixture> --dry-run --json
{
  "contract": "nen.shu.test/v0.1",
  "lane": "app", "stack": "nextjs", "verb": "test", "target": null,
  "steps": [ { "exe": "echo", "argv": ["fixture-test"], "cwd": "<fixture>",
               "exitCode": null, "durationMs": null } ],
  "cwd": "<fixture>", "env": [],
  "host": { "platform": "darwin", "supported": true, "declared": null },
  "preconditions": [],
  "exitCode": 0, "durationMs": 0,
  "artifacts": [ { "kind": "path", "value": "reports/junit.xml", "exists": false } ],
  "log": { "mode": "dry-run", "captured": false, "path": null,
           "why": "dry run -- nothing was executed, so there is no output to capture and no tool
                   exit code to report." }
}
exit=0
```

**What this establishes for rikugan:** the declared `artifacts[]` is where a report file lives and
nen already *reports whether it exists* — but it does **not** parse it. `nen shu test-report`'s
whole job (brief § 4.5: JUnit XML, `.xcresult`, vitest `--reporter=json`, Gradle) is the missing
half, and § 2.2 shows the subcommand is absent. Until it lands, the final variant's rows come off
the runner's own printed summary, quoted (§ 3.4).

### 2.4 — `nen schema check` has no `nen/workflow.json` row

Read-only, against `hatsu`'s own checkout:

```
$ nen schema check --repo /Users/zheref/Code/WebStorm/Claude/hatsu
repository: /Users/zheref/Code/WebStorm/Claude/hatsu
  FAIL  nen/labels.json    ... no such file ...
  FAIL  nen/repos.json     ... no such file ...
  FAIL  nen/colors.yml     ... no such file ...
  warn  nen/gates.json     ... no such file ...
  ok    nen/contract.json  dependency (nen >= 0.3, pinned v0.3.0)
nen: this repository's taxonomy could not be read. Nen has no built-in copy to fall back on -- a
binary that guessed the names would report a taxonomy this repository does not have.
exit=1
```

**Five rows, and none of them is `nen/workflow.json`.** The workflow schema and loader are P1
(brief § 4.1) and arrive with the `v0.4` line. The four `FAIL`/`warn` rows are `hatsu`'s own known
state (it ships a `dependency`-only contract and no taxonomy layer — `nen/contract.json`'s
`$comment` says so) and are not a finding of this run; the row that matters here is the one that is
**not printed**.

### 2.5 — The template, rendered end to end by hand

`templates/rikugan.html` was filled with a complete `final`-variant data document — every list
non-empty, three screenshot states on one screen and two on another, four coverage rows across all
four bands, three test rows across all three statuses — and opened in a browser. **Zero `{{` tokens
survived the substitution**, every section rendered, the screenshot table put states in columns as
specified, and the coverage bars resolved from `style="--pct:{{percent}}"` through
`width: calc(1% * var(--pct))`.

This is the § 3.2 residue performed once, deliberately, as its own proof: **a hand-filled render and
a `nen report render` one must produce the same bytes for the same data**, so the by-hand path was
exercised before it was written down as the interim procedure. The filled sample was rendered into
the scratch directory and the fixture, never into the repository.

---

## 3. Residue

Every entry is a step with no verb at `v0.3.0`, run by hand, named in the skill file where it runs,
and reported as by-hand on the page it produces.

1. **`nen report data --repo --base [--tiers] --json`** (§ 2.2, exit `2`, the whole family absent).
   Assembled from `git log --format='%h %s' <base>...HEAD`, `git diff --name-status <base>...HEAD`
   and `git diff --name-only <base>...HEAD`, plus `.nen/proof/<lane>.json` and
   `.nen/last-stop.json` where they exist. Brief § 4.3 is the shape it will return.
2. **`nen report render --template --data --out`** (§ 2.2). `templates/rikugan.html` is filled by
   hand, same template, same tokens (§ 2.5).
3. **`nen shu evidence --base <ref>`** (§ 2.2). Screenshot rows from `git diff --name-only
   <base>...HEAD` filtered by `nen/contract.json` → `project.evidence.globs`, grouped by
   `project.evidence.scene`'s `{suite}-{scene}` template read by eye.
4. **`nen shu test-report`** (§ 2.2). The final variant's rows are read off the runner's own summary
   and quoted. § 2.3 shows nen already knows *where* the report file is (`artifacts[]`) and only
   the parse is missing.
5. **`nen shu coverage --touched --base <ref>`** (§ 2.2). `nen shu coverage`'s per-target table,
   filtered by hand to `git diff --name-only <base>...HEAD`, banded against `coverage.minimum` /
   `.recommended` / `.ideal` (80 / 85 / 90 by default).
6. **`nen/workflow.json` read as data** (§ 2.4). No schema row at this pin; the skill reads the file
   itself, per `nen/contract.json`'s own `no_jq` rule, and states which defaults applied.
7. **The Artifact publish** — the surface's tool, not a repository operation. Named as a boundary so
   the absence reads as deliberate rather than overlooked; nen shells out to git and gh only.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — The P1 render spec does not say whether `{{#each}}` may nest, and rikugan needs it to

Brief § 4.3 specifies `nen report render` as *"`{{token}}` substitution with `{{#each list}}…
{{/each}}` blocks, no logic beyond that (same spirit as `canon mirror generate`)."* The screenshot
section of `templates/rikugan.html` is **`{{#each screenshots}}` containing two `{{#each states}}`
blocks** — one emitting the header row of state names, one emitting the image row — because "one
table per screen, states as columns" is a two-level shape with no one-level spelling that keeps the
per-screen grouping.

This is a finding filed **before** the verb exists rather than against it: when `nen report render`
lands, either it nests and the template is already correct, or it does not and the fix is nen's.
**Flattening the template is not the fix** — it would lose the grouping the table exists to show.

### 4.2 — `nen shu` reports an artifact's existence but parses nothing

§ 2.3: `artifacts: reports/junit.xml (absent)` / `{"kind": "path", "value": "reports/junit.xml",
"exists": false}`. nen already resolves where a lane's outputs land and whether they arrived; the
gap between that and rikugan's needs is purely the parse (`test-report`) and the filter
(`coverage --touched`). Both are already scoped as P1 (brief § 4.4, § 4.5); noted here as
corroboration that the missing verbs are small extensions of a seam that exists, not new machinery.

### 4.3 — `nen parse`'s optional-clause rule is a design constraint on every new skill's grammar

§ 2.1 confirms the engine refuses a lone bracketed slot *at the template*, with a message that names
the fix. That is good behaviour, not a defect — but it is a **standing constraint on skill
authorship**: any optional clause in a hatsu invocation must be introduced by a literal, or the
grammar cannot be parsed by verb at all. This wave's five skills all comply
(`as <variant>`, `at <gate>`, `from <base>`); recorded here so the next author does not
rediscover it. `docs/ab/tensho.md` § 4.1 filed the original observation against `v0.1.0`; this is
its settled form.

### 4.4 — Not a finding: there is no HTML-rendering verb, and rikugan does not want one

`nen board`'s three verbs (`build`/`render`/`diff`) render **markdown**, and
`docs/ab/backlog-board.md` § 4 records the same absence for the gate board. Rikugan's answer differs
from backlog-board's in one respect worth stating: **backlog-board authors its page fresh every
render**, having no template to fill, whereas rikugan **ships `templates/rikugan.html` and fills
it**. That is deliberate — a report whose shape drifts between turns is not comparable across turns,
which is most of what a per-turn report is for. So the P1 verb rikugan wants is
`nen report render --template <file>`, a substitution engine over a template the repository owns —
**not** a `--html` flag on a renderer that owns the shape.
