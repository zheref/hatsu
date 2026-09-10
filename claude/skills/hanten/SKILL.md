---
name: hanten
description: Have the change read adversarially before it is anybody else's problem — classify the change set by scope, raise one reviewer per scope on the model tier the matrix names, collect every finding in one fixed shape, and settle each one by fixing it or pushing back with a cited reason. Use when the maintainer invokes hatsu:hanten [for <scope>], asks for a review of what is on this branch, or whenever hatsu:mukai reaches its review step before the pull request is composed. A scope with no reviewer is reported as a gap and never quietly dropped; an unsettled finding is a G5 stop through the surface's own option picker. Reviewers never edit non-test source and never cast a review vote.
---

# Hanten — the change, read by someone looking for what is wrong with it

**No fixed mode.** Hanten holds whichever nature the change under review was authored in —
**Enhancer** for product code, **Conjurer** for canon, **Transmuter** for machinery — because every
finding it settles is settled by editing *that* change. Name the mode in play, say when it switches
and why, and never blend two under one header (`claude/agents/kurapika.md`).

> **Have somebody whose job is to find what is wrong with this read it, and settle every single thing
> they found — fixed, or refused with a reason I can check.**

Hanten is [`hatsu:mukai`](../mukai/SKILL.md)'s second step: after
[`hatsu:murasaki`](../murasaki/SKILL.md) has the branch current and before the suites run. It is also
invocable alone. Its position is the whole of its value — **pre-PR is the last moment a finding costs
an edit instead of a review round** (`claude/agents/hisoka.md` § *Where you sit*), and every rule in
this file exists to keep that window from being wasted.

**It is a review, not a gate.** Nothing here blocks, votes or merges. What it produces is a settled
set of findings and a record of how each one was settled — and, where one could not be, a stop.

---

## 1. Invocation

```
hatsu:hanten [for <scope>]
```

```bash
nen parse hanten \
  --grammar "for [<scope:ui|security|architecture|performance|release|all>]" \
  --line "<the invocation, minus the hatsu:hanten prefix>"
```

Verified live at `v0.3.0` (`docs/ab/hanten.md` § 2.1): `for security` → `scope: security`, exit `0`;
`for styling` refuses at exit `2` — *"`<scope>` is one of ui | security | architecture | performance
| release | all (case-insensitively), and 'styling' is none of them. It is resolved, never guessed
at: the closest match is not the answer"* — with the corrected line printed. The clause is anchored
behind a literal for the reason [`hatsu:rikugan`](../rikugan/SKILL.md) § 1 records.

**With no clause the scope is `all`, and `all` does not mean five reviewers** — it means **every scope
the change set actually raises** (§ 2). A `for <scope>` clause **narrows** to one; it never widens
past what the diff supports, and asking for `performance` on a diff that touches no
performance-sensitive path is answered with that fact, not with a review of nothing.

## 2. Classify the change set, then raise one reviewer per scope

```bash
git -C <path> fetch origin <branch.base>
git -C <path> diff --name-only origin/<branch.base>...HEAD
```

> **The range is `origin/<branch.base>...HEAD`, after that fetch — never the bare branch name.**
> `branch.base` in `nen/workflow.json` is a **branch name** (`main`), and nothing in the local plane
> fast-forwards *local* `main` once [`hatsu:breath`](../breath/SKILL.md) has cut the branch from it:
> the local ref sits wherever it was on the day the effort started and falls further behind every
> hour. Measured live, in one run: local `main` was **13**, then **36**, then **50** commits behind
> `origin/main`, and `main...HEAD` named **43** changed files where the branch's own change was
> **8** (`docs/ab/mukai.md`). Read literally, hanten would classify a week of somebody else's work
> and raise reviewers on it — real tokens, real attention, on a diff this branch did not write.
> `git merge-base origin/<branch.base> HEAD` is the same set expressed as a SHA, and it is the form
> to use when the report has to quote one. **The fetch is part of the rule**, not an optimisation:
> `origin/<branch.base>` is only as fresh as the last thing that fetched it.

**Classify every path before raising anyone**, and print the classification. A run that raises the UI
reviewer and then discovers the diff was mostly auth has spent a reviewer on the wrong question.

| Scope | Raised when the change set touches | Reviewer | What they cite |
|---|---|---|---|
| **ui** | a rendered surface — views, components, styles, design tokens, snapshot goldens, copy shown to a user | **[Hisoka](../../agents/hisoka.md)** | `UX-1`…`UX-12`, `UZF-26`, the Design Direction |
| **security** | authentication, credentials and secrets, permissions, network calls, storage and persistence, input trust boundaries, the supply chain | **[Feitan](../../agents/feitan.md)** | the security handbook's rules, by id |
| **architecture** | module boundaries, dependency direction, public API shape, the handbooks' own conformance surface | **[Chrollo](../../agents/chrollo.md)** | the governing rule by its id, never from memory |
| **performance** | a hot path, a render loop, a query, a bundle entry point, anything with a recorded budget | **[Uvogin](../../agents/uvogin.md)** | `QA-11`'s P1–P7 with `QA-15` method blocks |
| **release** | version manifests, tags, changelogs, packaging, deploy configuration, release workflows | **[Phinks](../../agents/phinks.md)** | `QA-1`'s proven-finding discipline, `QA-2`'s eight classes |

**A path may raise more than one scope, and then it is reviewed more than once.** An authenticated
settings screen is `ui` **and** `security`, and the two reviewers are asking genuinely different
questions about the same file. Do not pick the "primary" one.

**The scope routing is `docs/ROSTER.md` § 4 and § 6's rulings, not this file's invention** — Feitan is
activated for *"security, and security only"*, Chrollo for *"architecture and handbook conformance"*,
and Phinks *"gains a pre-PR trigger at `v0.5.0`"* as a routing target of this skill. Where this table
and the roster disagree, **the roster wins and this table is the bug.**

> **The path→scope map itself is this skill's, and that is a gap worth naming.** `nen/workflow.json`
> at `nen.workflow/v0.1` carries no `review` block, so there is nowhere for a repository to declare
> *its* idea of which directories are security-bearing. The table above is a **default**, said out
> loud as one every run, and a repository whose layout it reads wrongly gets the classification
> corrected by hand and that correction stated. A `review.scopes` key is the shape that would fix it —
> filed as a finding rather than invented here (`docs/ab/hanten.md` § 4.2).

## 3. A scope with no reviewer is reported as a **gap**

**All five of § 2's reviewer personas are defined in this repository today.** Hisoka, Feitan, Chrollo,
Uvogin and Phinks each have a file under `claude/agents/`: Feitan's and Chrollo's landed at `v0.5.0`
on the ruling of 2026-09-09, which `docs/ROSTER.md` § 4 records — both are now ratified independents
with their rows in § *The independents*. **So on this plugin, at this version, no scope in § 2's
table is a gap.**

**The check stays, and it is not ceremony.** What `docs/ROSTER.md` § 4 actually rules is the rule that
outlives the current roster: **"until a definition exists in `claude/agents/`, neither may be acted
as — an activation is a decision about standing, not a licence to improvise the agent."** That binds
any persona, at any time — a scope a repository routes somewhere this plugin has not provisioned, a
persona activated by a ruling whose definition has not landed yet, a plugin installed at a version
older than the one that added a file. The mechanism is what this section specifies; *which* personas
happen to be missing is a fact about a version, and stating it as a permanent one is how a skill goes
stale.

So, before raising anyone, check — every run, for every persona, including the five that are there
today. **The check is two questions, not one**, because § 2's routing needs both to be true and each
fails on its own:

```bash
# 1. does the definition exist?  (<plugin root> resolved as below — never assumed)
ls <plugin root>/claude/agents/<persona>.md

# 2. will THIS surface raise it? — the surface's own agent registry, never the filesystem
#    Claude Code: the subagent types offered to this session (the Agent tool's `subagent_type`
#    roster, the same list `/agents` shows). Look for the literal id `hatsu:<persona>`.
```

> **`ls` cannot answer question 2, and question 2 is the case § 3's own prose names.** *"A persona
> whose file exists but is not installed here"* — *"a persona the surface will not raise"* — answers
> **PRESENT** to `ls` and is still unraisable. Measured live: `feitan.md` and `chrollo.md` both
> existed in the checkout being read, and **no `hatsu:feitan` or `hatsu:chrollo` subagent type was
> offered to that session**, because the *installed* plugin was an older version than the files being
> read (`docs/ab/mukai.md`). A check that answers `PRESENT` for the exact failure it was written to
> catch is not a check. **The registry is the authority for question 2, and it is a live property of
> the session, not of a directory.**

**Where the plugin root comes from** (question 1's path): it is `$hatsu_root` — the Hatsu checkout
as [`hatsu-warmup`](../hatsu-warmup/SKILL.md) § 5's prelude resolves it, on every surface:
`$HATSU_PLUGIN_ROOT` first, else the path whoever raised this run handed it, else
`$CLAUDE_PLUGIN_ROOT`, each accepted only if it is a Hatsu checkout. `$CLAUDE_PLUGIN_ROOT` alone is
Claude Code's: that harness exports it **only inside a skill invocation**, it is **empty in an
ordinary tool-call shell and inside a subagent** — verified live — and on Codex and Cursor it is
usually unset or names a different plugin. The prelude reads those three candidates and no fourth,
canonicalises the winner to an absolute path, and holds it in a shell variable that is not exported
— so it runs in the shell that runs the `ls`, and a run with none of the three reports the root
unresolved. On Claude Code alone, the caller can obtain the path it HANDS IN — the second candidate
— from the surface's own plugin registry:

```bash
claude plugin list --json    # → [{ "id": "hatsu@hatsu", "installPath": "<the plugin root>", … }]
```

— verified live (the `--json` flag exists and `installPath` is the root). That is a way to produce
the handed path, not a step the prelude takes, and neither other surface has a registry to ask.
**Never guess it, and never fall back to a bare relative path**: a relative
`claude/agents/<persona>.md` resolves against whatever cwd the caller happened to have, which on a
review run is the repository *under review* rather than the plugin.

| Question 1 — the definition | Question 2 — the surface | What hanten does |
|---|---|---|
| **present** | **raises it** | raise the reviewer (§ 4) |
| **present** | **will not raise it** | **§ 9's adapter contract, disclosed as weaker.** The definition is read into a generic worker at the same tier, the four things § 9 lists are supplied by hand, and the report says the reviewer was *adapted*, not raised. It is **not** recorded as a raised persona reviewer |
| **absent** | either | **report the scope as a gap.** Name the scope, name the persona the roster activated for it, name the paths that raised it, and say that **this scope was not reviewed** |

**The middle row is not a gap and not a pass.** It is a third state, and collapsing it into either
neighbour loses something true: calling it a gap hides a review that did happen, and calling it a
raised reviewer overstates it. `scopes[].reviewed` stays `true` and the row carries
`"adapted": "no hatsu:<persona> subagent type on this surface; § 9 adapter"` beside it.

**A gap is never a pass, and never a silent omission.** It goes in the report, in the pull request
body, and in the findings record as a scope with `reviewed: false` — the same discipline
`claude/agents/hisoka.md` states for his own `unread` marker: *"an undeclared skip is how a check
quietly stops happening."*

**And it is never improvised past.** Reading a scope's diff "as `<persona>` would" because
`<persona>` has no file is exactly the improvisation the roster's ruling forbids, and it produces
findings with no citable rule behind them. The honest output is *"the `<scope>` scope was raised by
these four paths and was not reviewed; `<persona>` has no definition at
`claude/agents/<persona>.md`"* — which tells the maintainer something true and actionable, where a
manufactured review would not. The question is always *is the definition in front of me*, never *do I
remember this persona*.

**Which is exactly why the middle row is not improvisation.** There the definition **is** in front of
us — the file is on disk and is read into the adapted worker verbatim — and what is missing is only
the surface's mechanism for raising it under that name. The roster's ruling bars acting *as* a
persona whose standing has no definition; it does not bar reading a definition that exists into a
worker the surface can actually start. The line between the two is the file, and § 9's contract is
what keeps the weaker path honest about being weaker.

## 4. Raising a reviewer — the model, the title, the isolation

**On Claude Code the reviewer is a subagent, raised with the harness's own Agent tool**, one per
scope, in parallel where more than one applies:

| Parameter | Value |
|---|---|
| `subagent_type` | the persona — `hatsu:hisoka`, `hatsu:uvogin`, `hatsu:phinks`, … (§ 3, question 2) |
| `description` | the title: **`hanten · <persona> · <model alias>`** |
| `model` | § 4's resolution below — **never the frontier tier** |
| `isolation` | **omitted** — see below; the isolated checkout is cut by hand, of the repository under review |
| `prompt` | the **absolute path of the isolated checkout**, the scope, the base as `origin/<branch.base>`, the paths that raised it, § 5's required output shape, and *"do not request a worktree"* |

**The model alias comes from `nen/workflow.json` → `models`, and never from memory.**
`models.roles.reviewer` names the **tier** — `deep` — and `models.claude.deep` names the alias for
this surface. Two rules ride on it, and neither is optional (`docs/ROSTER.md` § 3):

- **A subagent is never given the frontier tier** (`fable` on Claude, `astra` on Codex). That tier is
  where the maintainer's own conversation lives, and a delegate that outranks its caller has inverted
  the delegation.
- **Every subagent is titled `<skill> · <persona> · <model alias>`** — what ran, as whom, on what.
  `hanten · hisoka · sonnet`, `hanten · phinks · opus`.

> **Where a persona's own definition pins a model, that pin is what runs, and hanten does not pass
> `model` at all.** `docs/ROSTER.md` § 3 records the pins as frontmatter — **Phinks** `model: opus`,
> **Hisoka** `model: sonnet` / `effort: high`, **Uvogin** `model: sonnet` / `effort: medium` — and the
> harness's `model` parameter **takes precedence over the definition's frontmatter**. Passing the
> role-derived `deep` alias for Hisoka would therefore silently overrule the maintainer's recorded
> decision about Hisoka, which is the opposite of reading policy from the file. So: **pass `model`
> only for a persona whose definition pins none**, and put whichever alias actually results into the
> title. Both paths read the matrix's aliases and neither can reach the frontier tier. **This
> reconciliation is disclosed, not slipped in** — it is a real tension between two true sentences in
> `docs/ROSTER.md` § 3, and it is filed as such (`docs/ab/hanten.md` § 4.1) rather than resolved
> quietly in prose.

**An isolated checkout is not a convenience.** It is what turns *"a reviewer never edits non-test
source"* from a rule the reviewer must remember into a property of where it is standing: nothing it
writes reaches the tree the maintainer is working in. **Never raise a reviewer into the working copy
under review.**

> **`isolation: "worktree"` isolates the *plugin's* repository, not the one under review — so hanten
> does not pass it.** The harness's worktree isolation cuts a branch in **the session's own
> repository**, which when hanten runs from a skill is the checkout the skill was loaded from. A
> review of `zheref/nen` driven from a hatsu checkout would therefore have branched *hatsu* and
> handed the reviewer an isolated copy of the wrong repository — and the reviewer, having no copy of
> what it was asked to read, would read the maintainer's live tree instead. Confirmed live
> (`docs/ab/mukai.md`): three detached worktrees of the target had to be cut by hand.

**So the isolated checkout is cut here, of the target, before the reviewer is raised** — one per
reviewer, so two reviewers cannot collide on one tree:

```bash
git -C <target repo> worktree add --detach <target repo>/.claude/worktrees/hanten-<persona> HEAD
```

`.claude/` is git-ignored in the repositories this plane runs in, so the checkout never reaches the
tree under review. **Its absolute path goes in the prompt**, and the prompt says the reviewer is to
work there and **must not request a worktree of its own** — a reviewer that asks for one gets the
plugin's repository, which is the failure this paragraph exists to prevent. Remove the worktree when
the review returns (`git -C <target repo> worktree remove --force <path>`).

**This is § 9's adapter contract applied to Claude Code, not an exception to it.** § 9 item 2 asks an
adapter for *"an isolated copy of the tree"* and does not say which tree, because there is only one
right answer: **the repository under review**. Where hanten runs against the same repository the
session is in, `isolation: "worktree"` would happen to name the right one — and the by-hand form is
still what runs, because a rule that is correct only when two paths coincide is a rule that breaks
silently the first time they do not.

**Say what was raised, in one line, before the reviews come back**: the scopes, the personas, the
aliases, the isolated checkout each was given, and the gaps.

**On Codex and on Cursor the mechanism is different and the rules are the same — § 9a is the table**:
`deep` resolves to `sol` on Codex and to `grok` on Cursor, a Codex reviewer is a whole second
`codex exec` run in a worktree because that surface has no in-session subagent, a Cursor reviewer is a
definition under `.cursor/agents/`, and the frontier tier runs no subagent on any of the three.

## 5. One fixed finding shape

**Every reviewer returns findings in one shape, and hanten refuses to record anything else:**

```json
{ "rule": "UX-3", "severity": "critical",
  "path": "Sources/Views/SettingsRow.swift", "line": 88,
  "evidence": "Tap target measures 32×32pt; HIG minimum is 44×44pt. Measured in the layout's own units at the default Dynamic Type size.",
  "proposedFix": "Raise the row's minimum height to 44pt and give the icon an 8pt margin." }
```

| Field | What it must carry |
|---|---|
| `rule` | **a rule id** — `UX-3`, `SEC-…`, `QA-11`, a `WCAG` SC, an Apple HIG / Material reference. Never a bare preference |
| `severity` | `critical` \| `high` \| `medium` \| `low` \| `nit` — [Hisoka's ladder](../../agents/hisoka.md) § *Severity*, used by every reviewer so the set is sortable |
| `path`, `line` | where, exactly. A finding with no location is a note |
| `evidence` | **what was observed or measured**, with the method where it is a number. Not a restatement of the rule |
| `proposedFix` | what would settle it. A reviewer proposes; it does not apply (§ 8) |

**A "finding" missing `rule` or `evidence` is a note, not a finding**, and is reported as one —
`claude/agents/hisoka.md` states it for UX (*"an un-cited preference is not a finding; it is taste
wearing a finding's clothes"*) and `claude/agents/phinks.md` for QA (*"files nothing he cannot
prove"*). Hanten holds every scope to it, including the ones whose reviewer does not exist yet.

**The record is one document, git-ignored:**

```
<reports.dir>/hanten/<branch-slug>.json      →  Reports/hanten/opus-kurapika-skills-turn-3.json
```

`reports.dir` is `nen/workflow.json` → `reports.dir`, default `Reports`, **and it is git-ignored** —
the same reason a build output is (`docs/WORKFLOW.md` § 2). `<branch-slug>` is the branch with `/`
replaced by `-`, the shape [`hatsu:rikugan`](../rikugan/SKILL.md) § 6 already uses for its final
report's filename.

```json
{ "contract": "hatsu.hanten.findings/v0.1",
  "branch": "<branch>", "base": "<branch.base>", "at": "<ISO-8601 UTC>",
  "scopes": [ { "scope": "ui", "persona": "hisoka", "model": "sonnet", "reviewed": true },
              { "scope": "security", "persona": "feitan", "model": "opus", "reviewed": true },
              { "scope": "architecture", "persona": "chrollo", "model": "opus", "reviewed": true,
                "adapted": "no hatsu:chrollo subagent type on this surface; § 9 adapter" },
              { "scope": "<scope>", "persona": "<an unprovisioned persona>", "model": null, "reviewed": false,
                "gap": "no definition at claude/agents/<persona>.md; ROSTER.md § 4" } ],
  "findings": [ { "id": "F1", "scope": "ui", "persona": "hisoka",
                  "rule": "…", "severity": "…", "path": "…", "line": 88,
                  "evidence": "…", "proposedFix": "…",
                  "disposition": { "state": "fixed", "detail": "…" } } ] }
```

**The six fields are the reviewer's; `id`, `scope`, `persona` and `disposition` are hanten's**, added
as it records. A reviewer never writes this file.

**The third row is § 3's middle state — reviewed, but adapted rather than raised — and it is a real
shape, not a hypothetical: it is what a run against an older installed plugin produces.** The fourth
row is the gap shape, written as a hypothetical on purpose. At `v0.5.0` every
persona § 2 routes to has a definition (§ 3), so a real record from this plugin carries no gap row at
all — the row is here because the shape must be documented before the day something needs it, and
filling it with a persona that *is* defined would teach the shape by way of a false example.

## 6. Settle every finding — fixed, or pushed back with a reason

**Kurapika disposes of each finding himself**, in the working copy, in severity order. There are
exactly three dispositions and every finding gets one:

| `state` | When | What `detail` must carry |
|---|---|---|
| **`fixed`** | the change was made | what was changed, and where |
| **`pushed-back`** | the finding does not hold | **a cited reason** — the rule the reviewer misread, the constraint they could not see, the measurement that contradicts theirs. Never "disagree", never "out of scope" alone |
| **`deferred`** | it holds, it outlives this branch | the **tracked item** it became — an issue, a `handbook-question`, a `UZF-23` IOU. An untracked deferral is not one, and is `unsettled` |

**A push-back is an argument, not a veto.** The reviewer found something with a rule id and evidence
behind it; refusing it needs the same standard. *"The measured contrast is 4.7:1 at the token's actual
value; the reviewer measured against the disabled state's token"* is a push-back. *"I don't think
that's a problem"* is an **unsettled** finding, and § 7 is what happens to it.

**Every disposition is recorded, including the push-backs**, and the whole set goes into the pull
request body through [`hatsu:shibari`](../shibari/SKILL.md). A review whose disagreements are not
written down is a review that gets had again.

**Fixes are proved before the run ends.** A `fixed` disposition that has not been through
[`hatsu:rasengan`](../rasengan/SKILL.md) is a claim; [`hatsu:mukai`](../mukai/SKILL.md) runs the
suites at its next step, and a fix that broke one is that step's finding.

## 7. An unsettled finding is a **G5**

**A finding that is neither fixed, nor pushed back with a cited reason, nor tracked, is a stop.** Not
a line in the PR body, not "noted for follow-up", not a `low` re-graded down until it stops mattering.

The stop is [`hatsu:jutaisho`](../jutaisho/SKILL.md)'s shape, in full — the `nen stop` banner and
efforts table (`nen stop --who Kurapika --gate G5 <efforts.md>`; `nen stop --template` emits the blank
table, verified live, `docs/ab/hanten.md` § 2.4), the [`hatsu:rikugan`](../rikugan/SKILL.md) report's
link, lettered options with a ⭐ on the report, and **the question through the surface's own native
option picker** (`AskUserQuestion` on Claude Code).

**What hanten puts in it:** the finding verbatim — all six fields — the reviewer who raised it, what
was already tried, and options that are the actual resolutions: *"A — take the proposed fix", "B —
push back on this ground (…)", "C — file it and land without it"*. **Never an option that re-grades
the severity**, and never one that removes the finding from the record.

**The run ends there.** A G5 is not a thing to retry past; the answer resumes it.

## 8. What a reviewer never does

Each reviewer's own definition is the authority and this is a summary of what they already say
(`claude/agents/hisoka.md` § *The refusals*, `claude/agents/phinks.md`, `claude/agents/uvogin.md`):

- **Never edits non-test source.** Fixing your own finding is reviewing your own work by another
  route. § 4's isolated checkout **of the repository under review** makes it structural.
- **Never casts a review vote** — not `approve`, not `request_changes`. They run on the maintainer's
  credentials, so GitHub would record the vote as **theirs**, and pre-PR there is usually no PR to
  vote on anyway.
- **Never merges, never pushes, never labels, never blocks.** Advisory, always.
- **Never emits `Verdict:` or `Quality-Gate:` outside its own definition's rules** — those markers
  belong to lanes that parse them.
- **Never reports a scope as clean that it could not check.** An unread check is named, with the
  missing capability.

## 9. On a surface that is not Claude Code

**§ 4's mechanism is Claude Code's. The contract is not.** An adapter on another surface must supply
four things, and where it supplies fewer, hanten says which:

1. **An isolated worker at a named model tier** — resolved from `nen/workflow.json → models` for that
   surface (`codex`, `cursor`), on the tier `models.roles.reviewer` names, **never the frontier tier**.
2. **An isolated copy of the tree — of the repository under review.** A worktree, a fresh checkout,
   or a read-only mount, cut from the target and named to the reviewer by absolute path. *Which*
   repository is the load-bearing half: an isolation mechanism that branches the session's own
   repository isolates the wrong thing and leaves the reviewer reading the live tree (§ 4). Without
   it, *"never edits non-test source"* falls back to being a rule the reviewer must obey rather than
   a place it cannot reach, and that is stated in the report.
3. **One returned document in § 5's shape.** A surface that can only return prose gets that prose
   read into the shape by hand, by hanten, with any finding missing `rule` or `evidence` recorded as a
   **note** rather than promoted.
4. **A title carrying `<skill> · <persona> · <model alias>`**, so a transcript read afterwards says
   what ran, as whom, on what.

**Where a surface offers no delegation at all**, hanten runs the review **in-session as a named pass**
— one scope at a time, each announced, each producing § 5's shape — and **says that it did**. That is
a weaker review and the report says so: the reader must be able to tell a finding raised by a separate
reviewer from one Kurapika raised against his own diff. It is never presented as the former.

### 9a · The two surfaces Hatsu ships a mirror for

[`docs/SURFACES.md`](../../../docs/SURFACES.md) is the authority on how the personas get onto each
surface; this is what hanten does with them once they are there.

| | **Claude Code** | **Codex** (`$hanten`) | **Cursor** (`/hanten`) |
|---|---|---|---|
| reviewer **tier** (`models.roles.reviewer`) | `deep` | `deep` | `deep` |
| the alias that tier resolves to | **`opus`** | **`sol`** | **`grok`** — Cursor-native only |
| how the reviewer is raised | the harness's **Agent tool**, `isolation: "worktree"` | **`codex exec -m "$sol" -C <dir>`** — a *separate process*, in its own directory; `$sol` is the alias **resolved to the host's id** below, never the alias itself | a **subagent definition** under `.cursor/agents/<persona>.md`, invoked as that surface documents |
| where the persona definition lives on that surface | `claude/agents/<persona>.md` | a `## <persona>` section of the generated `AGENTS.md` | `.cursor/agents/<persona>.md` |
| isolation | a worktree the harness makes | **the directory you pass to `-C`** — make it a `git worktree` first | whatever the surface gives a subagent; **state which** |

**Codex has no in-session subagent, and that is the fact the row above is built on** — verified against
the CLI on this host rather than remembered (`docs/ab/surfaces.md` § 3.4). `codex exec --help` documents
`-m, --model`, `-C, --cd <DIR>`, `-s, --sandbox <read-only|workspace-write|danger-full-access>` and
`-o, --output-last-message <FILE>`; there is no spawn-a-delegate flag anywhere in it. So on Codex a
reviewer is **a second Codex run**, and the isolation § 4 gets from `isolation: "worktree"` has to be made
by hand before the run:

```sh
git worktree add "$rev" HEAD                      # the isolated copy — hanten's own act

# `sol` is the TIER ALIAS; -m wants the host's ID for it. Resolve, never remember.
sol="$(codex debug models | grep -o '"slug":"[^"]*sol"' | cut -d'"' -f4)"
[ -n "$sol" ] || { echo "codex debug models lists no 'sol' slug — G5, the reviewer cannot be raised" >&2; exit 1; }

codex exec -C "$rev" -s workspace-write \
  --add-dir "$(git -C "$rev" rev-parse --path-format=absolute --git-common-dir)" \
  -m "$sol" -o "$rev/finding.json" "<the scope, the base, the paths, and § 5's required shape>"
```

> **`-m sol` does not start a reviewer, and this line used to say it did.** `codex debug models` on this
> host lists `gpt-reserve`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`, `gpt-5.5`,
> `gpt-5.3-codex-spark`, `codex-auto-review` — **there is no bare `sol`** (`docs/ab/surfaces.md` § 3.5,
> F1; Copilot review thread `PRRT_kwDOUKPjxM6hAjL9`). `sol` is the *alias*
> `nen/workflow.json` → `models.codex.deep` carries, and `models.rule` — *"latest alias only, never a
> version"* — is exactly why the file carries the alias and not the id. The id is a live property of the
> host, so it is resolved at the moment of use and a failed resolution is a **G5**, not a guess: raising
> a reviewer on some other model is not a smaller version of raising the right one.

> **`--add-dir` is not optional here, and this is the one place in the repository where the omission
> bites.** `git worktree add` makes a **linked** worktree, whose `.git` is a *file* pointing at
> `<main repo>/.git/worktrees/<name>/` — so `HEAD`, the index, `FETCH_HEAD`, the objects, `refs/` and
> `info/exclude` all sit **outside** the directory `-C` makes writable, and `-s workspace-write` refuses
> every git write in it: no `git add`, no `git commit`, no `git fetch`, no local exclude. Reproduced on a
> fixture on this host — the same `git add && git commit` died at exit **`128`**, *"fatal: Unable to
> create `…/.git/worktrees/wt/index.lock`: Operation not permitted"*, and exited **`0`** with
> `--add-dir "$(git rev-parse --path-format=absolute --git-common-dir)"` added and nothing else changed
> (`docs/ab/surfaces.md` § 7, F3; the full account is `docs/SURFACES.md` § 5).
> **`--git-common-dir`, not `--git-dir`:** the latter answers `<main>/.git/worktrees/<name>` and leaves
> the objects and `refs/` outside. A reviewer that only reads a diff never notices; one that writes a test
> to prove a finding — which § 5's evidence rule asks for — notices immediately, and reads the refusal as
> the repository being broken.
>
> **The alternative is a standalone clone** (`git clone <repo> "$rev"`), whose `.git` is inside the
> workspace and needs no extra root. Take it where the review needs no shared object store; take the
> worktree plus `--add-dir` where it must see the branch as the maintainer's repository has it.

`-s workspace-write` is deliberate and is the **narrow** choice: the reviewer may write inside its own
worktree — a test, a note, the finding document — and reaches nothing outside it. **`--add-dir` widens
that by exactly one directory, and it is a git directory.** Never
`--dangerously-bypass-approvals-and-sandbox` for a review; a reviewer that needs to bypass a sandbox to
read a diff is not reviewing a diff, and reaching for it *because a git write was refused* trades a named
hole for an unbounded one.

**On Cursor the reviewer is a subagent definition, so the model is named where the definition is**, not on
a command line — `model:` frontmatter in `.cursor/agents/<persona>.md`, mirrored there from
`claude/agents/` by `nen surface mirror generate` (`model` is one of the five keys that row keeps). The
per-persona pin § 4 protects survives the mirror: **Hisoka arrives on Cursor carrying `model: sonnet`,
which is a Claude alias and is not Cursor-native.** That is a real collision, it is named rather than
papered over, and the rule is § 4's own — a pin that cannot resolve on the surface it landed on is
**reported as unresolvable and the role's tier is used instead** (`grok`), with the substitution stated in
the title and in the report. It is never silently honoured and never silently dropped.

**The frontier tier never runs a subagent, on any surface** — `fable`, `astra`, `grok`. On **Cursor the
frontier and deep tiers name the same alias** (`grok`), so on that one surface the rule cannot be checked
by reading the alias: it is enforced on the **role**. A reviewer is raised at `models.roles.reviewer`, which
is `deep`, and is never raised as an orchestrator; that the resulting string happens to equal the frontier
tier's is a property of Cursor's line-up, not permission to treat a reviewer as one. Say the tier and the
alias both — *"tier `deep` → `grok` (Cursor-native; `frontier` names the same alias here)"* — so a reader
of the transcript can tell the two apart.

**The title rule does not change on any surface.** `hanten · <persona> · <model alias>` —
`hanten · feitan · sol`, `hanten · hisoka · grok (pin sonnet unresolvable on cursor)`. On Codex, where the
"title" is whatever the transcript records, it goes in the prompt's first line and in the report.

## Residue

**Boundaries and gaps, and no missing verb.**

1. **Raising a subagent has no nen verb and is not expected to get one.** nen owns operations, not
   conversations — the identical boundary [`hatsu:rikugan`](../rikugan/SKILL.md) § Residue 7 names for
   the Artifact publish and [`hatsu:ren`](../ren/SKILL.md) § 4 names for the turn loop, verified there
   rather than assumed. § 4's mechanism is the surface's tool, § 9 is what an adapter must provide, and
   neither is a gap to file against the binary.
2. **The reviewers' isolated checkouts** (§ 4) — `git worktree add --detach` against the repository
   under review, one per reviewer, removed when the review returns. The harness's own
   `isolation: "worktree"` isolates the session's repository and cannot be used here (verified live,
   `docs/ab/mukai.md`), and nen owns no worktree verb.
3. **§ 3's two-part check** — `ls` for the definition, and the surface's own agent-type roster for
   whether it can be raised. Neither is a nen question: one is a file on disk and the other is a
   live property of the session. The plugin root behind the first is `$hatsu_root`, resolved as
   `hatsu-warmup` § 5's prelude does — `$HATSU_PLUGIN_ROOT`, else the handed path, else
   `$CLAUDE_PLUGIN_ROOT`, each identity-checked, the winner canonicalised, the variable local to the
   shell that ran the prelude — with `claude plugin list --json` → `installPath` (verified live) as
   the way a Claude Code caller produces the handed path when it has none.
4. **No verb classifies a change set by scope.** `nen gate derive --policy-paths --process-paths
   --files` is the nearest thing and answers a **different question** — which human *gate* a diff
   derives, `G2` or `G4`. Verified live at this pin (`docs/ab/hanten.md` § 2.3): a two-file
   documentation-and-skill diff derives `G4` *"the diff touches the process surface"*, which is true and
   says nothing about whether the change is security-bearing. So § 2's classification is read off
   `git diff --name-only` against the default map, in the open, and reported as by-hand.
5. **`nen/workflow.json` carries no `review` block at `nen.workflow/v0.1`**, so § 2's path→scope map
   cannot be declared per repository. Read as this skill's default, stated every run, corrected by hand
   where a repository's layout defeats it — and filed (`docs/ab/hanten.md` § 4.2).
6. **RETIRED at nen `0.5`: `nen/workflow.json` is validated.** `nen schema check --repo <path>` carries
   an `ok  nen/workflow.json` row at the pinned `v0.6.0` (`docs/ab/rikugan.md` § *Retired at nen 0.5*).
   `models` is an OPEN map nen preserves and validates nothing inside, so the matrix stays this skill's
   own read — which is a read, not a residue.
5. **The worktree a Codex reviewer runs in is hanten's own `git worktree add`** (§ 9a). `codex exec -C`
   takes a directory and makes none, and no nen verb makes one either — `nen` owns operations, not
   checkouts. Named residue, on that surface only; on Claude Code `isolation: "worktree"` still does it.
   **Computing the extra writable root is residue with it** — `git rev-parse --path-format=absolute
   --git-common-dir`, read by hand and passed to `--add-dir`. No verb answers "which directories must a
   sandbox open for this checkout to be writable", and that is a property of one surface's sandbox rather
   than of the repository, so none should.
6. **A persona's `model:` pin does not survive a surface change, and nothing resolves it.**
   `nen surface mirror generate` carries `model` through to `.cursor/agents/<persona>.md` verbatim —
   correctly, since it mirrors and does not translate — so Hisoka's `sonnet` arrives on Cursor as a
   Claude alias in a Cursor-native-only matrix. § 9a's rule (report it unresolvable, fall back to the
   role's tier, state the substitution) is this skill's, by hand, and it is a **candidate for
   `nen/workflow.json`** rather than a defect in the mirror.
7. **Resolving a tier alias to the surface's model id has no verb** (§ 9a). `nen/workflow.json` carries
   the alias and nothing else — `models.rule` forbids a version in the file — while `codex exec -m` and
   `cursor-agent --model` want an id the host is serving today. The bridge is
   `codex debug models | grep -o '"slug":"[^"]*sol"' | cut -d'"' -f4`, run by hand, and a resolution that
   comes back empty is a **G5** rather than a substituted model. `nen model resolve --surface <s> --tier
   <t>`, running the surface's own catalogue probe, would close it; filed as `docs/ab/surfaces.md` § 7 F1.

## Authority

- **Permitted:** read the working copy and its git history; raise reviewer subagents under § 4's
  constraints; **write the findings record** under `<reports.dir>/hanten/`; **edit the working copy**
  to settle a finding, in the nature the change was authored in; render the stop.
- **Not permitted:** push, commit, PR, label, merge, tag, deploy, or any review vote. Hanten is a step
  inside [`hatsu:mukai`](../mukai/SKILL.md)'s run and holds none of that run's authority.
- **A reviewer's delegation is one review wide and ends when that review returns.** It is not standing
  authority to look at the branch again later, and it never includes anything in § 8.
- **Carries no delegation of its own**, and being invoked inside `mukai` does not lend it one.

## Hard limits

- **Never reports a scope as reviewed when its reviewer has no definition** (§ 3) — it is a **gap**,
  named, in the report and in the record.
- **Never improvises an activated-but-undefined persona.** `docs/ROSTER.md` § 4's ruling is explicit,
  and a manufactured review produces findings with no citable rule behind them.
- **Never raises a subagent on the frontier tier**, and never omits the `<skill> · <persona> · <model
  alias>` title (§ 4).
- **Never overrides a persona's own model pin** by passing `model` for a persona whose definition
  carries one (§ 4) — and never *silently honours* one that cannot resolve on the surface it landed on
  (§ 9a): say it is unresolvable, use the role's tier, and put the substitution in the title.
- **Never raises a Codex reviewer outside an isolated directory**, and never with
  `--dangerously-bypass-approvals-and-sandbox`. `git worktree add` first, then `codex exec -C <that dir>
  -s workspace-write` (§ 9a).
- **Never raises a reviewer into the working copy under review** — an isolated checkout **of the
  target**, or the report says the isolation was missing (§ 4, § 9).
- **Never passes `isolation: "worktree"`** from a skill invocation: it isolates the plugin's own
  repository, not the one under review (§ 4).
- **Never answers § 3's question 2 with `ls`**, and never reports a persona as raised when the
  surface's agent registry does not carry `hatsu:<persona>` (§ 3).
- **Never reads `$CLAUDE_PLUGIN_ROOT` without resolving `$hatsu_root` first** — it is empty outside a
  skill invocation, it is not Hatsu's on the two mirrored surfaces, and a bare relative path resolves
  against the repository under review (§ 3).
- **Never records a finding missing `rule` or `evidence` as a finding** — it is a note (§ 5).
- **Never leaves a finding without a disposition**, and never re-grades a severity to make one go away
  (§ 6, § 7).
- **Never accepts an uncited push-back** — an unsettled finding is a G5 (§ 7).
- **Never lets a reviewer edit non-test source, vote, merge, push or block** (§ 8).
- **Never presents an in-session pass as a raised reviewer** (§ 9).
- **Never presents by-hand classification as a verb's output** — § Residue is named where it runs.
