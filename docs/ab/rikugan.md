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

---

## 5. The `0.4.0` render, end to end — the wave-3 findings, closed and re-verified

**Added in wave 4**, against the wave-3 validation's findings F10–F14. Everything below was run on
**2026-09-10** with the `0.4.0` binary at `/Users/zheref/Code/WebStorm/Claude/nen/.nen/bin/nen-0.4.0`
(the `PATH` binary is still the pinned `0.3.0`), against the **`zheref/nen`** checkout at
`64c175a` on `opus/kurapika/launch-lane-artifact`. The template under test is this repository's
`templates/rikugan.html` as edited on `opus/kurapika/wave-3-validation-fixes`.

### 5.1 — F12: the template parses now, and the refusals that remain are the honest ones

Wave 3 recorded three refusals in a row, each one a substitution tag the template spelled inside its
own CSS comment. With the comment rewritten to describe the syntax in words, the parse is clean and
the only refusal left is a token the data document genuinely has not got:

```
$ nen-0.4.0 report render --template <hatsu>/templates/rikugan.html \
    --data /tmp/tpl/base6.json --out Reports/dry.html --repo <nen> --dry-run
nen report: <hatsu>/templates/rikugan.html: '{{title}}' names 'title', which the data document has
not got. Every token a template names must be in the data -- a blank renders as a fact, so nen
refuses the whole render rather than publishing a report with a hole in it. … This template names 40
token(s): title, variant, repo, branch, base, generatedAt, accomplished, text, why, challenges,
residue, notDelivered, files, tier, path, status, evidence, suite, scene, src, launch, decisions,
prBody, markdown, readiness, verdict, reason, gate, tests, name, coverage, coverage.path,
coverage.format, coverage.lane, coverage.total.lines.percent, touchedCoverage, file, band, percent,
footerNote.                                                                              exit=2
```

**`title` is an extension key, not a document key** — so this refusal is § 4's merge doing its job,
and it is the last one: no refusal quotes a comment, and none names a token the vocabulary got wrong.

### 5.2 — F13: the merged data file, and the landing variant rendered

```
$ nen-0.4.0 report data --repo <nen> --base HEAD~6 --tiers /tmp/tpl/tiers.json --json > base6.json
   exit=0 — nen.report.data/v0.1, 69 commits, 108 files, evidence [], coverage lcov 94.4%
$ # merge: base6.json ∪ the extension keys (§ 4's merge shape), one evidence row given a src
$ nen-0.4.0 report render --template <hatsu>/templates/rikugan.html \
    --data /tmp/tpl/merged6.json --out Reports/landing.html --repo <nen> --dry-run
tokens: 40 … (dry run) nothing written -- the tokens above are every one this template asks for.
                                                                                         exit=0
$ nen-0.4.0 report render --template <hatsu>/templates/rikugan.html \
    --data /tmp/tpl/merged6.json --out Reports/landing.html --repo <nen>
wrote Reports/landing.html                                                               exit=0
$ wc -c < Reports/landing.html          →  39452
$ grep -c '{{' Reports/landing.html     →  0
```

What the bytes prove, checked one at a time:

| Claim | Evidence in the rendered page |
|---|---|
| the vocabulary lines up | `data-variant="landing"` on the article; **zero** `{{` left |
| **04** is flat and tier-chipped | `<li><span class="chip chip-tier">documentation</span><span class="path">CHANGELOG.md</span><span class="st">M</span></li>` |
| a `null` tier renders an empty chip the CSS hides | `<li><span class="chip chip-tier"></span><span class="path">.gitignore</span>…` |
| **05** reads `evidence[]` | `<td>SettingsSuite</td>` … `<td>row-default</td>`, with the capture's `data:` URI in the `img` |
| **11**'s lead reads the document's own coverage | *"Read from `coverage/lcov.info` (lcov, lane nen); the repository total is 94.4% and is not the verdict."* |
| escaping is on by default | a note containing `<nen>` rendered `&lt;nen&gt;` |
| **F10**'s slot carries the failed resolution | `<span class="footer-note">nen repo resolve … exited 1 (nen/repos.json: no such file), so the title is the repository name plus the branch.</span>` |
| **F11**'s slot carries the by-hand sentence | `<span class="provenance">This page was assembled by …</span>` in **03**'s lead |

### 5.3 — Two engine facts § 4 had backwards, measured

```
$ # {{#if coverage}} against a document whose coverage is a real report
B-if-null:[TOTAL 94.4]
$ # the same template against the same document with coverage forced to null
B-if-null:[]                                             exit=0 — rendered, not refused
$ # {{#each evidence}} over []
C-each-empty:[]                                          exit=0 — the row's tokens are never asked for
```

So `{{#if <key>}}` **exists** (§ 4 said it would not) and guards a `null` without refusing, and an
empty `{{#each}}` does not demand its row tokens. The engine also nests `{{#each}}` — its own
`--help` says *"nested; `{{.}}` is a scalar item and `{{@index}}` its position"* — which answers
§ 4.1's filed finding **in the affirmative**. The template no longer needs the nesting: `files[]` and
`evidence[]` are flat in the document, so § 4.1 is closed by the data's shape rather than by the
engine's.

### 5.4 — Two refusals worth knowing before you hit them

```
$ nen-0.4.0 report render … --out /tmp/tpl/dry.html --repo <nen>
nen report: --out '/tmp/tpl/dry.html' resolves outside the repository at <nen>. '/tmp/tpl' is a
symlink to '/private/tmp/tpl' … 'report render' writes the report INTO the repository it is
reporting on and nowhere else.                                                           exit=2

$ # a template naming a key the data has not got, anywhere -- including inside an {{#if}}
nen report: … '{{#if}}' names 'notAKey', which the data document has not got.            exit=2
```

The first is why § 4's command writes to `<reports.dir>` and not to a scratchpad. The second is why
§ 4 requires **every extension key on every render**, `""` or `[]` where there is nothing.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| the by-hand assembly (`git log` / `git diff --name-status`) | `nen report data --repo . --base origin/main --json` | `0` |
| the scratch renderer — ~60 lines of substitution, escaping and validation | `nen report render --template templates/rikugan.html --data <merged> --out Reports/current.html` | `0` |
| the same, checked first | the same with `--dry-run` | `0`, 40 tokens listed |
| `nen shu evidence`, `nen shu test-report`, `nen shu coverage --touched` | see those skills' own sections | `0` / `1`(named) / `0` |
| `nen/workflow.json` unvalidated | `nen schema check --repo .` | that row `ok` |

```
$ nen report data --repo . --base origin/main
repo: repin-0.4 on 'opus/kurapika/repin-nen-0.4', base 'origin/main'
generated: 2026-09-10T09:08:30.150Z
commits: 33
  2c692ed5 chore(nen): repin the contract to nen 0.5 (v0.5.0)
  …
coverage: lane 'plugin' declares no artifact nen recognises as a coverage report, so there is none to
read. 'nen shu coverage --repo <path> --lane plugin' names the repair.
exit=0
```

**Every absence is `null` with the reason on stderr**, and the reason is quoted onto the page rather than
invented. `--json` publishes `nen.report.data/v0.1` with `repo` as the checkout's **directory name**,
never its absolute path.

Then the merge and the render, on the real template:

```
$ nen report render --repo . --template templates/rikugan.html --data <merged> \
    --out Reports/current.html --dry-run
tokens: 40
exit=0

$ nen report render --repo . --template templates/rikugan.html --data <merged> --out Reports/current.html
wrote Reports/current.html
exit=0

$ wc -c < Reports/current.html            # 38283
$ grep -c '{{' Reports/current.html       # 0
$ grep -o '&lt;v0.5.0&gt;' Reports/current.html | head -1   # &lt;v0.5.0&gt;
```

**The escaping is the engine's and is proved, not assumed**: an accomplished row whose text carried
`<v0.5.0>` arrived on the page with both brackets as entities. And the merge is not optional — the same
render against the **unmerged** `report data` document refuses at exit `2` naming `title`, which is the
extension doing its job.

**Still residue:** embedding a capture as a `data:` URI and validating `{{src}}`/`{{percent}}` before
they are written (the engine escapes and does not validate), and the Artifact publish itself, which is
the surface's tool rather than a step nen owns.


## Issue #48/#49 integration scenarios — 2026-09-12

The following are constructed protocol acceptance scenarios, not transcripts of a physical-device
run or a full regression. The current source contract is in docs/WORKFLOW.md, docs/DISCOVERY.md
and docs/LAUNCH-MIGRATION.md; historical command transcripts above retain their original dates.

| Scenario | Expected outcome |
|---|---|
| Ordinary turn with authored executable changes | Focused tests and inexpensive checks pass at kokusen; no regression or coverage run is scheduled by the turn/report |
| Hatsu's prose-only change | Declared plugin lint; tests not applicable; no launch target declared |
| Missing scoped test path | Capture an owned pending/linked dependency; no raw runner or substitute full suite |
| Physical target chooses simulator artifact | Report a consumer declaration defect and incomplete launch |
| Compatible build, successful install and launch | Report each actual outcome from Nen's core-checkout invocation |
| Absent versus present-but-unusable device | Only absence may take a declared fallback; unusable remains a readiness refusal |
| Nested repeated device names | Route to Nen #204; retain the consumer normalizer until a compatible release and verification |
| Turn/final report sees stale test or coverage artifact | Mark stale; do not execute tests/coverage merely to render the page |
| Repeated discovery already captured | Unchanged result and no GitHub write; retain canonical link |
| Filing unavailable | Durable sanitized pending record; original work continues where possible |
