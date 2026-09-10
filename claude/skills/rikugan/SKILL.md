---
name: rikugan
description: Render one turn of work as a rich HTML report — accomplished, challenges, not delivered, architecture delta, screenshots, the exact launch command, decisions — from the one fixed template, never as a markdown summary. Use when the maintainer invokes hatsu:rikugan [as turn|landing|final], asks to see the report, the turn report or the final report, or whenever hatsu:ren, hatsu:mukai or hatsu:en reaches its reporting step. The landing variant adds the PR body and the readiness verdict; the final variant adds the tests run and the touched-file coverage, and is the only one kept as a dated file under Reports/. Not a gate event — it publishes a page and rings nothing.
---

# Rikugan — the turn, seen

**Nature: Manipulator.** Reporting is the board-facing half of the work, the same half
[`hatsu:backlog-board`](../backlog-board/SKILL.md) claims for the gate register. **The nature of the
work being reported is stated inside the report, never adopted by this skill** — a turn that authored
canon is reported by a Manipulator saying "this turn was Conjurer's", and rikugan does not inherit
that mode by rendering it.

> **Show me the turn: what landed, what fought back, what is missing, and the exact line that starts it.**

Rikugan is [`hatsu:ren`](../ren/SKILL.md)'s fifth step, [`hatsu:mukai`](../mukai/SKILL.md)'s
handover artifact and [`hatsu:en`](../en/SKILL.md)'s first and last. It is one skill with **three
variants of one page**, not three reports: the seven sections below are always the seven sections,
in that order, and a variant only ever **adds**.

**It is never markdown.** A turn summarised into chat scrolls away; a page has an address the
maintainer can come back to, and the screenshot table is the whole point of having one. If the
render cannot happen, say so (§ 7) — do not substitute a prose recap and call it the report.

---

## 1. Invocation

```
hatsu:rikugan [as <turn | landing | final>]
```

The clause is optional and defaults to **`turn`**. It is anchored behind the literal `as`
deliberately, because that is the shape `nen parse` can actually express:

```bash
nen parse rikugan --grammar "as [<variant:turn|landing|final>]" --line "<the invocation, minus the hatsu:rikugan prefix>"
```

> **The bare-bracket form is refused at the template, by design — verified live at `v0.3.0`
> (`docs/ab/rikugan.md` § 2.1).** `--grammar "[<variant:turn|landing|final>]"` exits `2` with
> *"its leading slot `<variant>` is bracketed but nothing introduces it, so an omitted value cannot
> be told apart from a mistyped one. Anchor it behind a literal … or drop the brackets"* — the same
> engine behaviour [`hatsu:tensho`](../tensho/SKILL.md) § 1 records for its own grammar. Tensho's
> answer was to keep its default in prose, because its optional word has no introducing literal to
> anchor to. **Rikugan's answer is the opposite one: give the clause a literal and let the verb own
> the parse.** Verified live: `as landing` → `variant: landing`; a bare `as` parses with the clause
> absent (exit `0`, the default applies); `as interim` is refused at exit `2` naming the three
> values and printing the corrected line. A grammar that can be parsed by a verb is not left to
> prose.

**Which variant a composite asks for is that composite's to say, not this skill's to infer** —
`ren` asks for `turn` every turn, `mukai`/`en` ask for `landing` once the PR body exists, and `en`
asks for `final` after the merge. Invoked bare by the maintainer, it is `turn`.

## 2. The parameters — `nen/workflow.json`, with the defaults stated

Every number and path on this page comes from the target repository's `nen/workflow.json`. Read the
keys; never carry a remembered value.

| Key | Used for | Default when the key (or the file) is absent |
|---|---|---|
| `reports.dir` | where the **final** variant is written | `Reports` |
| `reports.template` | which template renders | `rikugan` → `templates/rikugan.html` |
| `reports.retain` | **which renders are KEPT** — `final-only` means only the final variant gets a dated file of its own | `final-only` |
| `reports.captures` | where screenshot PNGs are read from | `<reports.dir>/captures` |
| `coverage.minimum` / `.recommended` / `.ideal` | the band on each coverage row | `80` / `85` / `90` |
| `branch.base` | the report's `base` field, and the diff's left-hand side | `main` |

> **`retain` governs what is KEPT, not whether a working file exists** (maintainer's ruling,
> 2026-09-09, § 13 of the fold-in report). `final-only` means **only the final variant gets a dated
> file of its own** under `<reports.dir>`. It does **not** forbid the **transient**
> `<reports.dir>/current.html` § 6 writes on a surface that cannot publish an Artifact: that file is
> overwritten by every render, is never dated, is git-ignored, and is a way of *opening* a page
> rather than a copy retained of it. One file that is always the latest render is not a retained
> report — a retained report is one you can still find after the next turn.

> **`nen schema check` does not validate this file at `v0.3.0` — verified live
> (`docs/ab/rikugan.md` § 2.4).** Run against `hatsu`'s own checkout it reports exactly five rows —
> `nen/labels.json`, `nen/repos.json`, `nen/colors.yml`, `nen/gates.json`, `nen/contract.json` — and
> **no `nen/workflow.json` row**. The workflow schema and its loader are P1 (brief § 4.1) and land
> at `v0.4.0`. Until then this skill reads the file as data itself, exactly the way
> `claude/agents/kurapika.md` § *Session warm-up* has it read `nen/contract.json`: open it, take the
> literal values, substitute them. **No `jq`** — a subprocess to parse JSON for the entity that just
> read it buys a dependency for nothing. A malformed `nen/workflow.json` is reported and the
> defaults above are used, said out loud; it is never silently repaired.

## 3. Assemble the data

```bash
nen report data --repo <path> --base origin/<branch.base> [--tiers <json>] --json
```

`nen report data` is the verb that owns this step and **it does not exist at `v0.3.0`** — verified
live: `nen report data --repo <path>` exits `2` with *"unknown command 'report'"*
(`docs/ab/rikugan.md` § 2.2). It is P1 (brief § 4.3), and until it lands the assembly is **named
residue**, run by hand in this order and reported as by-hand:

| Field | Residue command | Becomes |
|---|---|---|
| `commits[]` | `git -C <path> log --format='%h %s' origin/<base>..HEAD` | the accomplished list's evidence |
| `files[]` | `git -C <path> diff --name-status origin/<base>...HEAD` | **04 Architecture delta**'s rows (`path`, `status`) |
| `tier` per file | the caller's own path→tier map | the tier chip on each of those rows |
| `evidence[]` | `git -C <path> diff --name-only origin/<base>...HEAD` filtered by `project.evidence.globs` | **05 Screenshots**' rows |
| `coverage` | the last coverage artifact on disk, if the lane declares one | the final variant's coverage rows |
| `proof`, `lastStop` | `.nen/proof/<lane>.json`, `.nen/last-stop.json` where they exist | the footer's provenance |

> **Every range is `origin/<base>`, after `git -C <path> fetch origin <base>` — never the bare branch
> name.** `branch.base` is a **branch name** (`main`), and nothing in the local plane fast-forwards
> *local* `main` once [`hatsu:breath`](../breath/SKILL.md) has cut the branch from it. Measured live
> in one run: local `main` was 13, then 36, then 50 commits behind `origin/main`, and `main...HEAD`
> named **43** changed files where the branch's own change was **8** (`docs/ab/mukai.md`). The cost
> here is a page: **04 Architecture delta** would list a week of somebody else's files as this
> effort's. `git merge-base origin/<base> HEAD` is the same set as a SHA and is what to quote.
> **`nen report data --base <ref>` takes a REF, not a branch name** — pass `origin/<base>`, which is
> what the verb's own help means by *"the trunk, or the commit the effort was cut from"*, and note
> that its commits are `<base>..HEAD` while its files are `<base>...HEAD`, the merge-base diff a pull
> request shows. A ref that does not resolve is refused by name at exit `2` rather than answered
> emptily.

**Three companion verbs are missing with it, and each is its own residue** — verified live at
`v0.3.0`, all exit `2` (`docs/ab/rikugan.md` § 2.2):

- **`nen shu evidence --base <ref>`** — not a `shu` subcommand (`--base` is not even a known option
  on the family). The evidence rows come from `git diff --name-only origin/<base>...HEAD` filtered by
  `nen/contract.json` → `project.evidence.globs`, with `project.evidence.scene`'s `{suite}-{scene}`
  template read by eye to split each path into its `suite` and `scene`. **This residue outlives the
  pin**: `nen report data` at `0.4.0` emits `evidence: []` unconditionally — *"empty in this release
  — `nen shu evidence` owns them"* — so the rows are the caller's either way until that verb is
  wired into it.
- **`nen shu test-report`** — not a `shu` subcommand. The **final** variant's test rows come from
  the runner's own summary output, read as the runner printed it and quoted, never re-tabulated
  from memory.
- **`nen shu coverage --touched --base <ref>`** — `--touched` is not a known option. The **final**
  variant's coverage rows come from `nen shu coverage`'s ordinary per-target table, filtered by hand
  to `git diff --name-only origin/<base>...HEAD` — [`gyo`](../gyo/SKILL.md) § 4's touched set, its
  exclusions included — with the band assigned against § 2's ladder. **The banding stays the
  caller's at every pin**: `report data`'s `coverage` object carries the parsed report and no band,
  because a band is policy and the document holds only facts.

**Screenshots are embedded, never linked, before the PR exists.** A capture under
`reports.captures` becomes a `data:image/png;base64,…` URI in `states[].src`. A relative path into a
working copy is dead the moment the page is published, and a link to a branch blob is dead the
moment the branch is deleted.

## 4. Fill the template

```bash
nen report render --template templates/rikugan.html --data <the § 3 document> --out <file>
```

`nen report render` is the verb that owns this step and **it does not exist at `v0.3.0`** — verified
live, exit `2` (`docs/ab/rikugan.md` § 2.2). It is P1 (brief § 4.3): `{{token}}` substitution with
`{{#each list}}…{{/each}}` blocks and no logic beyond that. **Until it lands, this skill fills the
identical template by hand — named residue — and the template is `templates/rikugan.html` either
way.** Never author a second page shape "just for this turn": a hand-filled render and a
verb-rendered one must be the same bytes for the same data, or the verb's arrival is a redesign
instead of a retirement.

> **Say plainly what that residue is: it is a small renderer, not a fill-in-the-blanks.** "Fill the
> template" undersells the work and hides its one real hazard. To produce the same bytes the verb
> would, the residue path has to implement, at minimum: `{{token}}` substitution; `{{#each list}}`
> blocks **including the nested case** the screenshot block needs (the finding below); HTML-escaping
> of every substituted value; and the two extra validations on `{{src}}` and `{{percent}}` (§ 4,
> *Escaping*). That is on the order of sixty lines of real code — a **renderer**, and it should be
> written and named as one rather than improvised token by token, because a per-turn improvisation is
> where an unescaped value gets through.
>
> **Where it may live: the session's scratchpad, and nowhere else.** It is a throwaway for a verb
> that is already written upstream, so it is never a file in the target repository — not a script
> under `scripts/`, not a `tools/` helper, not a committed one-off. Committing it would put a second
> renderer in a repository that is about to get the real one, and it would need reviewing,
> versioning, and eventually deleting. Write it to the scratchpad, run it, say on the page that the
> render was by hand (§ Residue), and let it die with the session.
>
> **From nen `0.4.0` there is no renderer to write, and the path is two verbs with a merge between
> them** — the exact commands are in *The merge* below, and `<reports.dir>` is read from
> `nen/workflow.json` as always, which is `Reports/current.html` on a repository taking § 2's default.
> The merge is not optional and is not glue: the document is the facts, the extension is everything a
> git read cannot know, and the file the renderer reads is both.
>
> **The template documents the syntax in WORDS, and that is a rule rather than a style — finding
> F12.** `nen report render` substitutes over the whole file, comments included: it is a text
> substituter, not an HTML or CSS parser, and it has no idea a `<style>` comment is a comment. The
> template used to spell its own examples — a double-brace token, the triple-brace raw form, an
> `each` block — inside its opening comment, and the `0.4.0` verb refused it **three times over**,
> once per example, every refusal quoting a piece of prose: *"`''` is not a token `'{{{ }}}'` can
> name"*, then *"`'{{token}}'` names `'token'`, which the data document has not got"*, then
> *"`'{{/each}}'` closes a block that was never opened."* Each fix uncovered the next.
>
> **So the syntax is written out here, in this file, and described in words there.** The template's
> comment says *double-brace tags*, *the triple-brace raw form*, *a repeat block*, *a presence
> block* — no braces. **The same rule binds any template this skill renders**: a template that
> documents its own markup inside itself is a template that cannot be rendered, and the check is
> `nen report render --dry-run`, which reads the file exactly as the render does.

> **Both verbs exist on `zheref/nen`'s `main` today** — verified against the source rather than the
> binary, which is still the pinned `0.3.0`: `git -C <nen checkout> log --oneline -3 origin/main --
> src/report` returns `feat(report): add the report family -- data and render`, `docs(report):
> document the report family, its two verbs and the counts`, and `fix(report): exit 1 on a failed git
> read, not 2, in report data`, over the files `src/report/command.ts`, `data.ts`, `render.ts`,
> `template.ts`, their three `*.test.ts` neighbours and `src/report/fixtures/report.html`. **They are
> merged, not released**, which is exactly why § 3 and this section still describe the by-hand path:
> the day the release moves the pin, the residue is deleted rather than migrated, and this skill's
> only change is which of the two paragraphs above it runs.

### The token vocabulary is `nen report data`'s, plus a named extension

**Every slot whose value the document carries is spelled the way the document spells it.** The two
verbs are documented as the two halves of one pipeline — `nen report data … > <data file>`, then
`nen report render --data <data file>` — and at `0.4.0` **a token the data document has not got is
refused at exit `2`, naming it**. So a template speaking a different vocabulary from the document
does not degrade; it does not render at all. That is the right behaviour (*"a blank renders as a
fact"*) and it makes the vocabularies one question, not two.

**Half the template used to speak its own** — `generated` against the document's `generatedAt`,
`architecture` against `files`, `screenshots` against `evidence`, a list called `coverage` against an
**object** called `coverage` — four of fourteen lining up (finding F13). They are aligned now:

| Token | Where the value comes from | Shape |
|---|---|---|
| `{{repo}}` | **the document** | the repository **directory's name**, never its path — the document is deliberate about this, because a report gets pasted into a pull request |
| `{{branch}}`, `{{base}}` | **the document** | the branch (`null` on a detached HEAD) and the `--base` ref as passed |
| `{{generatedAt}}` | **the document** | absolute ISO-8601 UTC, the document's own instant — never a relative string |
| `{{#each files}}` | **the document** | `{path, status, tier}` per row — `status` is git's own token (`M`, `A`, `R100`), `tier` is `--tiers`' answer or `null` |
| `{{#each evidence}}` | **the document's shape**, filled by the caller | `{suite, scene, path, status}` + **`src`**, the extension field (below) |
| `{{#if coverage}}` · `{{coverage.path}}` · `{{coverage.format}}` · `{{coverage.lane}}` · `{{coverage.total.lines.percent}}` | **the document** | the parsed report's provenance and the **repository total**, which is never the verdict |
| `{{variant}}` | extension | `turn` \| `landing` \| `final` — written onto the root element; **§ 5's gating reads it** |
| `{{title}}` | extension | the object notation and the branch, e.g. `HA-PR-#31 · opus/kurapika/skills-turn-2` (§ 6) — or § 6's stated fallback |
| `{{residue}}` | extension | § Residue's sentence, in **03 Not delivered**'s lead |
| `{{footerNote}}` | extension | § 6's failed-resolution note, in the footer beside the branch and base |
| `{{launch}}` | extension | the exact command, verbatim, in the `<pre>` |
| `{{#each accomplished}}` · `challenges` · `notDelivered` · `decisions` | extension | `{text, why}` per row |
| `{{#each prBody}}` | extension | `{markdown}`, zero or one row — landing and final |
| `{{#each readiness}}` | extension | `{verdict, reason, gate}`, zero or one row — landing and final |
| `{{#each tests}}` | extension | `{name, suite, status}` — final; from `nen shu test-report`, a **different** document |
| `{{#each touchedCoverage}}` | extension | `{file, percent, band}` — final; **renamed** so it cannot collide with the document's `coverage` object |

**The extension is not a second vocabulary — it is the half no git read can produce.** Four narrative
lists are judgement; a launch line is what [`amaterasu`](../amaterasu/SKILL.md) ran; a PR body is
[`shibari`](../shibari/SKILL.md)'s; a readiness verdict is `nen pr ready`'s; test rows are
`nen shu test-report`'s; a *band* is `nen/workflow.json`'s ladder applied to a number, which is
policy and not a fact. A document that carried any of them would be a document making decisions.

### The merge — one data file, and every key always present

**The skill writes ONE data file: `nen report data`'s document with the extension keys added at the
top level.** No key of the document is renamed, dropped or rewritten; the extension only adds. Two
rows are the exception worth naming: `evidence[]` is **enriched** — each row keeps its four document
fields and gains `src`, the capture as a `data:` URI, because no git read turns a PNG into one — and
at `0.4.0` `report data` emits `evidence: []` unconditionally (*"empty in this release — `nen shu
evidence` owns them"*), so in practice the rows are the caller's whole own.

```bash
nen report data --repo <path> --base origin/<branch.base> [--tiers <file>] --json > <base data>
# merge: <base data> ∪ { variant, title, residue, footerNote, launch, accomplished[], challenges[],
#                        notDelivered[], decisions[], prBody[], readiness[], tests[],
#                        touchedCoverage[], evidence[] (each row + src) }   → <data file>
nen report render --template templates/rikugan.html --data <data file> \
  --out <reports.dir>/current.html --repo <path> [--dry-run]
```

**Every extension key is written on every render, empty where there is nothing** — `""` for a
scalar, `[]` for a list. An omitted key is exit `2`, so "there was no readiness verdict" is
`readiness: []` and never a missing `readiness`. That is the same discipline **03 Not delivered**
states in prose: absence is written down, not left out.

**Two flags of `render` are load-bearing.** `--dry-run` prints every token the template names and
writes nothing — run it first on a template you have edited, because it is the cheapest way to see a
vocabulary drift. `--out` must resolve **inside `--repo`** (symlinks resolved) or it is refused at
exit `2` naming the resolved path, so `<reports.dir>` is where the page goes and `/tmp` is not a
place this verb will write.

> **Verified end to end, live, on the `0.4.0` binary against `zheref/nen`** — the transcript is in
> `docs/ab/rikugan.md` § 5. `--dry-run` lists **40** tokens and exits `0`; the real render writes a
> 39 452-byte landing page with **zero** `{{` left in it; a value carrying `<nen>` arrives as
> `&lt;nen&gt;`; `{{#if coverage}}` renders its body against a real report and renders **nothing**
> against `coverage: null` rather than refusing; and an empty `{{#each}}` renders nothing without
> asking for its row tokens. The same run against the **unmerged** document refuses at exit `2`
> naming `title` — which is the extension doing its job, not a defect.

> **Two facts about the engine, checked rather than assumed, that this section used to have
> backwards.** It **does** nest `{{#each}}` (*"nested; `{{.}}` is a scalar item and `{{@index}}` its
> position"*), which answers the finding this section filed against the P1 spec — in the
> affirmative, and the template no longer needs it: **04** and **05** are flat lists in the document,
> and the substituter has no group-by, so grouping would have to be done by the caller composing a
> *different* list, which is the vocabulary split all over again. **And it does have `{{#if <key>}}`**,
> where this section used to say *"there is no conditional in the engine … do not add a `{{#if}}` the
> renderer will not have."* It is used in exactly one place — guarding **11**'s lead against a
> `coverage` that is `null` — and nowhere else: **the variant's extra sections are still always
> emitted and hidden by CSS off `data-variant` (§ 5)**, because a page whose shape changes with its
> variant is three pages. `{{#if}}` guards a **null**; it does not choose a layout.
>
> **The residue path owes both constructs too.** A hand-written renderer at the pin implements
> `{{token}}`, `{{{token}}}`, `{{#each}}` (nested) and `{{#if}}`, or it is not producing the same
> bytes the verb would.

### Escaping — the contract, and it binds the residue path too

**Every value on this page is repository-controlled**: a commit subject, a PR body, a file path, a
scene name. A subject carrying `<script>` or a `"` is not exotic — it is a Tuesday — and this page
gets published as an Artifact.

- **Every `{{token}}` is HTML-escaped by the renderer.** `nen report render` escapes by default —
  `&`, `<`, `>`, `"`, `'` become entities — in text content and inside an attribute alike. No token
  on this page opts out. **That verb does not exist at `v0.3.0`** (§ 4's opening), so this rule is
  two things at once: the **contract `nen report render` must meet** when it lands at `v0.4.0`, and
  — today, on the only path there is — **the residue's own job**. Check it the day the verb lands,
  alongside the nested-`{{#each}}` finding above; if the verb ships without escaping by default, the
  fix is nen's, not a template full of pre-escaped values.
- **`{{{ }}}` is the raw form, and `templates/rikugan.html` uses it nowhere.** The only slot it
  would ever be admitted for is a **pre-escaped data-URI `src`**, which must first match
  `^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$`. Even that slot is written `{{ }}`, because
  HTML-escaping a base64 data URI changes none of its bytes. **Anything that is not a data URI is
  `{{ }}`.**
- **Two values are validated as well as escaped**, because escaping alone answers the wrong
  question for them: `{{src}}` against the regex above (escaping stops the attribute closing; it
  does not stop the URL being a scheme nobody asked for), and `{{percent}}` in
  `style="--pct:{{percent}}"` against `^(100|[0-9]{1,2})(\.[0-9]+)?$` (escaping stops the attribute
  closing; it does not stop `1;background:url(…)` adding a declaration). **A value that fails its
  check is not rendered** — drop the row and name the gap in **03 Not delivered**, the same way § 7
  handles a capture that will not embed.
- **Hand-filling is held to the identical rule.** Until `nen report render` lands this skill writes
  the tokens itself, and it **escapes `& < > " '` in every value it writes and runs the same two
  validations** before it writes them. The residue path is the one that has no engine underneath it,
  which makes it the path where this is the skill's own job rather than a default it inherits.

## 5. The three variants

| Variant | Called by | Sections | **Kept** on disk? |
|---|---|---|---|
| **`turn`** | [`hatsu:ren`](../ren/SKILL.md) § step 5, every turn | 01–07 | **No** — an Artifact, or the transient `current.html` (§ 6) |
| **`landing`** | [`hatsu:mukai`](../mukai/SKILL.md) § 2 **step 8**, and [`hatsu:en`](../en/SKILL.md)'s first step | 01–07 **+ 08 PR body + 09 Readiness** | **No** — the same two |
| **`final`** | [`hatsu:en`](../en/SKILL.md)'s last step, after the merge | 01–09 **+ 10 Tests run + 11 Touched coverage** | **Yes** — the only one with a file of its own |

> **`landing` is rendered AFTER the PR is opened, and that is the whole of when it may be rendered —
> finding F6.** Its two extra sections are **08 PR body** and **09 Readiness**, and both are
> [`shibari`](../shibari/SKILL.md)'s outputs: the body shibari composed and wrote, and a `nen pr ready`
> verdict that needs a PR number to answer about. Rendered before shibari — which is where
> [`mukai`](../mukai/SKILL.md) § 2 used to run it — the variant necessarily carries **two empty
> sections**, which is the one thing this page must not do: an empty **09** is indistinguishable from
> a `not-ready` verdict, and § 5's own rule is that a readiness claim is that verdict or it is not
> made. **So mukai renders it once, at step 8, after step 7's `gh pr create` returned.** Not rendered
> early and re-rendered later: a page a maintainer opened between the two renders would have shown
> them the empty one, and the second render is not free.
>
> **`en` § 3's first step re-renders it, and that is a different render of the same variant**, not a
> second half of this one — by then the watch has a readiness verdict of its own and the body may
> have been edited. It republishes to the same address (§ 6), so there is one page per branch either
> way.

**"Kept" is the column, and it is not "touched the filesystem."** `retain: final-only` decides which
render survives the next one: only `final` gets its own dated file. A `turn` or `landing` render on a
surface with no Artifact still has to be *opened* from somewhere, and § 6's `current.html` — one
path, overwritten every render, git-ignored — is that somewhere.

> **After [`hatsu:aka`](../aka/SKILL.md), rikugan re-renders `turn`. There is no fourth variant.**
> `aka` leaves the effort in a state the three-row table does not obviously name: pushed, but with no
> pull request — so the last `turn` render, truthful when it was written, now says *"nothing pushed,
> no PR"* about a branch that is on `origin`. **`landing` is not the answer**: it adds **08 PR body**
> and **09 Readiness**, and at this point there is no PR body to carry and no `nen pr ready` verdict
> to quote, and § 5's own rule is that a readiness claim is that verdict or it is not made. `final`
> is post-merge. **So the state is carried by the `turn` variant, re-rendered**, with the push
> written into **01 Accomplished** as the plain fact it is — the branch, the pushed SHA, and that no
> PR was opened because opening one is [`hatsu:mukai`](../mukai/SKILL.md)'s and the maintainer's.
> This is deliberate rather than a gap: a fourth variant would exist to describe a *pause*, and a
> variant per pause is how three sections become nine. **Re-render `turn` at the same address**
> (§ 6's republish rule holds), so the page a maintainer left open stops being stale about the push.

The seven fixed sections, in this order, always: **01 Accomplished · 02 Challenges · 03 Not
delivered · 04 Architecture delta · 05 Screenshots · 06 How to launch · 07 Decisions.**

- **03 Not delivered is never omitted for being empty.** A turn that delivered everything says so on
  the page; a turn that did not names each gap and why. Silence there reads as completeness.
- **05 Screenshots is one row per scene, not one table per screen.** `nen report data`'s `evidence[]`
  is a **flat** list — `{suite, scene, path, status}` — and the substituter has no group-by, so the
  suite is a column rather than a heading over a block. Nothing is lost: every scene is still named
  with its suite, its git status (`A` added, `M` re-recorded, `D` removed) and its capture. Grouping
  would mean composing a second, differently-shaped list, which is the vocabulary split § 4 exists to
  close.
- **06 How to launch is the *exact* command** [`hatsu:amaterasu`](../amaterasu/SKILL.md) ran — the
  `--dry-run` argv pasted verbatim, target name and all, not a reconstruction and not a tidied-up
  version. It goes in chat too; the page is the copy that survives.
- **09 Readiness is `nen pr ready`'s verdict, quoted** — [`hatsu:pr-state`](../pr-state/SKILL.md)'s
  binding rule holds here unchanged. A readiness claim is that verdict or it is not made, and
  `unevaluated` is never rendered as `ready`.

## 6. Publish it

**On Claude Code, the report is an Artifact, republished to ONE URL per branch.** This is
[`hatsu:backlog-board`](../backlog-board/SKILL.md) § 5's rule applied to a different page, and it is
inherited rather than restated: find the branch's existing report artifact and update it in place,
so every turn of an effort lands at the same durable address; publish a new URL only for a branch
that has none yet. **Read before you overwrite** — a republish notice, or a listing showing a
version this session did not publish, means the page moved and is re-read first.

The title is the object notation and the branch (§ 4's `{{title}}`), stable for the life of the
branch. Resolve the code with `nen repo resolve` and render the ref with `nen ref format` — object
notation is never typed from memory (`claude/agents/kurapika.md` § *How you work*).

> **When the resolution fails, the title falls back — it is never typed from memory instead.** The
> taxonomy lives in the **target** repository, and plenty of repositories do not carry it: verified
> live at `0.3.0`, neither `zheref/hatsu` nor `zheref/nen` has a `nen/repos.json` (nor the legacy
> `schemas/repos.json`), so `nen repo resolve --repo <path> --target <owner/name>` refuses in both —
> *"`<path>/nen/repos.json`: no such file. Nen reads this repository's taxonomy from … and has no
> built-in copy to fall back on"*, exit `1`. That refusal is correct and is **not** a reason to
> supply the code from memory, which is exactly what § *How you work* forbids and exactly what a
> plausible-looking wrong code costs.
>
> **The fallback title is the repository name plus the branch** — `zheref/nen ·
> opus/kurapika/launch-lane-artifact` — both of which are facts about the checkout in front of you
> rather than facts about a taxonomy nobody could read. **And the failed resolution is named on the
> page**, in the footer beside the branch and base: which verb was run, against which target, and
> the one-line reason it refused. A page whose title silently degraded is a page that will be read as
> if the code had been resolved.
>
> **`{{footerNote}}` is that slot, and it exists now (finding F10).** The requirement was here and
> the template's footer was four spans with nowhere to put it, so a skill obeying this paragraph
> could not — and the run that hit it wrote the sentence into **03 Not delivered** instead, which is
> a workaround nothing named. The token is an ordinary escaped value, it hides itself when empty, and
> it is written on **every** render: `""` when everything resolved, the sentence when something did
> not. Where two resolutions failed — the title's and a reference's — both go in it, in one line.
>
> **`nen ref format` needs the taxonomy too — this section used to say it did not, and that was
> wrong (finding F14).** Measured, on the same checkout that has no `nen/repos.json`:
>
> ```
> $ nen ref format --code NE --kind PR --number 158
> nen ref: <repo>/nen/repos.json: no such file. …                          exit=1
> ```
>
> The verb's own `--help` says so: *"`--code <CODE>` … **checked against the target repository's
> `nen/repos.json`** — a code the registry does not carry is refused, not emitted."* Which is right:
> a formatter that emitted `NE-PR-#158` for a code no registry carries would be inventing an object
> notation, which is exactly what *never typed from memory* forbids. **So the reference gets the same
> stated fallback the title has** — the `owner/name` slug and the number, `zheref/nen#158`, both facts
> about the checkout in front of you — and the failed resolution goes in `{{footerNote}}` with the
> title's. [`shibari`](../shibari/SKILL.md) § 3's `Closes #N` rests on the same verb and takes the
> same fallback.

**On any other surface, the page is opened from `<reports.dir>/current.html`** — one path, written
fresh by every render, overwritten by the next, git-ignored. It is **transient**, not retained: it
is how a surface with no Artifact opens the page at all, and it is admitted under `final-only` by
the maintainer's ruling of 2026-09-09 (§ 2). Say which of the two happened; never let a reader guess
whether they are looking at a link or a file.

**Only the `final` variant gets a file of its own**, at
`<reports.dir>/<YYYY-MM-DD>-<branch-slug>-final.html`, and **that is what `retain: final-only`
governs** — what survives the next render. Turn and landing renders live at their address, and on a
non-Artifact surface at `current.html` until the following turn replaces them; a directory of forty
dated turn reports is the thing the retention rule exists to prevent, and one always-latest working
file is not that. `Reports/` and `.nen/` are git-ignored; **rikugan writes under `<reports.dir>` and
nowhere else in the tree.**

**Say one line in chat and stop**: the variant, the branch, the link or the path. Not a prose
summary of the page underneath it — that is the thing the page exists to replace.

## 7. When the render cannot happen

Relay it in one line and say what is missing — a `reports.captures` directory that does not exist, a
capture too large to embed, a template that will not resolve. **Then render the page without that
section's rows**, with the section's own empty-state line showing, and name the gap in **03 Not
delivered**. A report that quietly drops its screenshot table is worse than one that says the
captures were not found.

**What is never the fallback: a markdown recap presented as the report.** If no page can be produced
at all, say that no report was produced. The one thing this skill must not do is let a chat message
stand in for the artifact, because nobody downstream can tell the two apart afterwards.

## 8. This is NOT a gate event — no banner

A report rendered because a turn ended, or because the maintainer asked for one, carries **no
`nen stop` banner, no efforts table and no push notification** — the identical carve-out
[`hatsu:backlog-board`](../backlog-board/SKILL.md) § 6 states, for the identical reason: he is
already looking at it. **The bell is [`hatsu:jutaisho`](../jutaisho/SKILL.md)'s**, it runs *after*
this skill in [`hatsu:ren`](../ren/SKILL.md)'s order, and it rings only when something is genuinely
his. Rikugan hands jutaisho the report's link and rings nothing itself.

**A real stop that comes due while the report renders fires normally, with its banner.** Rendering a
report never suppresses one.

## Residue

Everything here is named, and every entry is a verb this repository expects at `v0.4.0`:

1. **`nen report data`** — the whole family is absent at `v0.3.0` (exit `2`, *"unknown command
   'report'"*). § 3's table is the by-hand assembly, run as `git log` / `git diff --name-status` /
   `git diff --name-only` and reported as by-hand.
2. **`nen report render --template`** — absent with it. § 4 fills `templates/rikugan.html` by hand,
   same template, same tokens, same bytes for the same data — **and the escaping the verb would do
   by default is this skill's own job on that path**: escape `& < > " '` in every value written,
   validate `{{src}}` against the data-URI regex and `{{percent}}` as a bare `0`–`100`
   (§ 4, *Escaping*).
3. **`nen shu evidence --base <ref>`** — not a `shu` subcommand at `v0.3.0`. Screenshot rows come
   from `git diff --name-only` filtered by `project.evidence.globs`.
4. **`nen shu test-report`** — not a `shu` subcommand. The final variant's test rows are read off
   the runner's own summary and quoted.
5. **`nen shu coverage --touched --base <ref>`** — `--touched` is not a known option. Coverage rows
   are `nen shu coverage`'s per-target table filtered by `git diff --name-only`, banded against
   § 2's ladder.
6. **`nen/workflow.json` is unvalidated** — no row in `nen schema check` at `v0.3.0`. This skill
   reads it as data and states the defaults it fell back to.
7. **The Artifact publish itself has no verb and never will** — it is the surface's tool, not a
   deterministic step nen owns. Named here so that the absence is a boundary rather than a silence.

**None of these is routed around.** Each is run by hand, in the open, with the sentence *"this was
assembled by hand; `nen report data` does not exist at the pinned ref"* attached to the report that
carries it — so that the day the verbs land, the retirement is visible.

**`{{residue}}` is where that sentence goes, and it exists now (finding F11).** It renders in **03
Not delivered**'s lead, which is the section whose whole job is naming what is not there. The
requirement used to have no slot at all, so the run that hit it wrote the sentence into 03's *rows*
by hand — the right section, reached the wrong way, and nothing in this file said so. Like
`{{footerNote}}` it is written on every render and is `""` when there is nothing to disclose: on the
day the pin moves, the page stops carrying the sentence because the sentence stops being true, and
no template change is needed to stop it.

## Authority

- **Permitted:** read the working copy and its git history; read `nen/workflow.json` and
  `nen/contract.json`; publish or republish **this branch's** report Artifact; write under
  `<reports.dir>`.
- **Not permitted:** anything else on disk, any GitHub write, any label, any merge, any push. Rikugan
  is a rendering step inside somebody else's run and holds none of that run's authority.
- **Carries no `CON-25`-equivalent delegation**, and being invoked from inside
  [`hatsu:ren`](../ren/SKILL.md), `mukai` or `en` does not lend it one.

## Hard limits

- **Never renders the report as markdown**, or lets a chat summary stand in for the page (§ 7).
- **Never writes outside `<reports.dir>`**, and never gives a `turn` or `landing` render a **kept**
  file — no dated name, no second path. The one transient `current.html` is the whole of what those
  variants may touch, and only on a surface that cannot publish an Artifact (§ 6).
- **Never publishes a second URL for a branch that already has a report** — republish, having read
  first (§ 6).
- **Never claims readiness by eye** — § 5's row 09 is `nen pr ready`'s verdict, quoted, or absent.
- **Never omits 03 Not delivered**, and never leaves a gap out of it to make a turn read better.
- **Never fires the `nen stop` banner, the efforts table or a push notification** (§ 8) — the bell is
  [`hatsu:jutaisho`](../jutaisho/SKILL.md)'s, and it rings after this, not inside it.
- **Never presents by-hand assembly as a verb's output** — § 3 and § 4 are residue and say so on the
  page they produce, through `{{residue}}` rather than in prose somebody has to notice.
- **Never omits an extension key from the data file** — `""` or `[]`, never absent; a missing key is
  exit `2` and no page at all (§ 4).
- **Never spells a substitution tag inside a template's own comments** — the renderer parses them
  (§ 4, F12). Describe the syntax in words there and write it out here.
- **Never lets the template and `nen report data` drift apart** — a slot whose value the document
  carries is spelled the document's way, and `--dry-run` is what proves it before a render (§ 4).
- **Never renders `landing` before the PR exists** — its two extra sections are shibari's outputs,
  and an empty **09** reads as a verdict (§ 5).
- **Never links a screenshot that a reader outside this machine cannot resolve** — embedded as a
  data URI, or named as missing.
- **Never writes an unescaped value into the page, by verb or by hand**, and never a `{{{ }}}` for
  anything but a data URI that has already matched its regex (§ 4, *Escaping*). A repository-
  controlled string reaching an Artifact unescaped is the report attacking its own reader.
