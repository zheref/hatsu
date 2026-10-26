# The shared phase conventions

**The general process specification every Hatsu skill inherits.** A skill's own `SKILL.md` carries
what is specific to it — its purpose, its steps, its verbs and their skill-specific exit reactions, its
parameters and its own hard limits. What every phase shares lives here, once, and a skill points at the
section by name (`PROCESS.md § <Section>`). **Everything here is binding exactly as if it were written
in each skill that points at it**; moving a rule here moved where it is written, never whether it holds.

It sits beside [`WORKFLOW.md`](WORKFLOW.md) (the configuration keys, the phases, the gates and the
decision matrix), [`STANDALONE-ENTRY.md`](STANDALONE-ENTRY.md) (a phase called cold),
[`DISCOVERY.md`](DISCOVERY.md) (gaps found during authorized work) and [`SURFACES.md`](SURFACES.md)
(the surfaces). **Precedence among canon prose and rulings** is one order ([HR-1](ROSTER.md#hr-1)),
owned by the `precedence` key of [`../nen/contract.json`](../nen/contract.json) and restated once, at the
top of [`WORKFLOW.md`](WORKFLOW.md); a configuration file's value still beats any prose copy of it. This
page is **binding wherever the skill is silent**; where it and `WORKFLOW.md` disagree, `WORKFLOW.md` wins and this page is
the bug.
*Assembled 2026-09-22 from the passages the skill diet moved out of the capped skills, so each skill keeps headroom for its own rules.*

## Standalone entry

**Shared policy (`docs/*.md`) lives at the Hatsu plugin root that `ten` prints**, and every
`../../../docs/…` link in a skill resolves there. **A missing consumer copy of a `docs/` file is never a
missing policy and never a filing**: a skill reads the policy it cites from the plugin root, never from
the consuming repository's tree. A phase reached from a composite skips its own `## 0.` and says which
composite holds it ([`STANDALONE-ENTRY.md`](STANDALONE-ENTRY.md) § 4).

## Invocation and parsing

**A skill reads its configuration from the target's own files, never from memory and never through
`jq`.** `nen schema check --repo <path>` validates `nen/workflow.json` and the declaration files it
knows; a malformed key is a FAIL **by pointer**, and the skill quotes that pointer rather than guessing
past it. **Every default that applied is said out loud** — in the turn's line or on the page — so a
reader can tell a configured value from an assumed one.

**A repository with no `nen/workflow.json` runs on the built-in defaults, and says so**, in these
words: *"no workflow.json: using the built-in defaults from `docs/WORKFLOW.md`"*. The defaults are
[`WORKFLOW.md`](WORKFLOW.md) § 2's; each skill names only the consequence specific to it.

**A gap is never the end of a run.** A missing argument or configuration item — and a value no default
covers — is asked for per item and set up inline on the answer ([`WORKFLOW.md`](WORKFLOW.md) § 4 *Ask,
set up, continue*, rows `missing-argument` and `missing-configuration`); the maintainer's own word (a
target, a go, a cap, a device, the request) is **typed, never picked and never derived**
(`missing-maintainer-choice`).

**An optional bracketed clause and an empty line are different inputs to `nen parse`.** An empty
`--line` and a bare anchor parse identically (exit `0`, the clause absent), but a grammar carrying a
**required** slot refuses an empty line at exit `2` — **and that exit is the trigger to ask**, never
the end of the run. An optional clause whose absence the skill defines (a turn bell, a default base) is
not a gap and is never asked about.

## Running a declared verb

**Every declared `nen shu` verb is dry-run before its first bare run, and the command handed back is
the dry run's own.** `--dry-run` prints the exact `would run:` argv, the cwd, the env **names** (never
values) and the declared artifacts, and spawns nothing. **The command pasted into the report and into
chat is that `would run:` argv, copied verbatim** — never re-typed from memory, never a plausible
substitute for the declared one — and what then runs is what was shown.

**A heavy declared verb takes the host's heavy turn before its bare run** ([`WORKFLOW.md`](WORKFLOW.md)
§ *Host workload budget*): a free effort slot or provider quota is not that turn, and a resource stop
is reported as pending evidence, never as a pass.

## Escaping the maintainer's words

**The maintainer's words never enter shell source.** Where a script takes a value the maintainer typed
— a target, a name, a message — it is written, verbatim and alone, to a file with **the surface's own
file-writing tool**, and the script is passed the file's path. **Never `echo`, `printf`, `cat` or a
heredoc** to build that file, and never interpolate the value into a command line: a double-quoted
assignment still runs command substitution, and a quoted heredoc's delimiter is in-band.

## Exit codes and refusals

**A missing or unsatisfied tool is exit `5`, never `1`.** Exit `1` means a run that happened and
failed; a missing or wrong tool is not a failed build, and a caller that retries a `1` retries forever
on a machine nobody set up. Every `nen shu tools` row that is not satisfied reports `5`, and a skill
relaying it keeps the code — and installs the tool where it can (`missing-tool`).

**A `5` whose every unsatisfied row is a coverage-only row reads *unmeasured, still testable*.**
A toolchain row whose `why` begins `Coverage only:` (in Hatsu: `ruby`, `bash`, `simplecov`, `bashcov`,
`simplecov-lcov`, zheref/hatsu#148) is needed only to *measure* line coverage: without it every lane
still runs its fixture, uninstrumented, and says so. So breath § 2c, ten § 1, bankai-quality and any
other reader of `nen shu tools` keep the `5`, relay the remedy, and never report the host as unable
to build or test. nen cannot scope a toolchain row to the lanes that need it yet, so the
distinction is read off the row's `why`.

**A refusal that is a gap is a question; a refusal that is a safety rule stays a refusal.** The list
of what is not a gap is authored once, in [`WORKFLOW.md`](WORKFLOW.md) § 4 *What is not a gap*; each
is named, never asked about and never softened into a default.

**A fixture's failed assertion names its check.** Under `set -e`, a command substitution that
may return no match as an expected check outcome uses `|| true`, then an explicit `fail` with the
expected and actual values. Wiring substitutions may still fail directly. Every declared
`nen shu test` seat runs through `scripts/fixture_output_guard.sh`, which reports every fixture
that exits nonzero by name and exit code, including failures after progress output, while preserving its exit code (#243).

## Reporting a phase

**A report rendered because the maintainer asked for it, or at a phase's reporting step, is not a gate
event.** It carries **no `nen stop` banner, no efforts table and no push notification** — the
maintainer is already looking at it, on every repeat of a repeating render. **A real gate coming due
while the page is read fires normally**: rendering never suppresses a stop, and a page that makes the
next act obvious is still not a reason to take it. The bell is
[`jutaisho`](../claude/skills/jutaisho/SKILL.md)'s alone, and **which asks on a page make it a stop is
authored in its § 1**: every ask reaches the picker in the same turn, and only one whose `gate` is
G1–G5 brings the banner.

**A progress turn carries no banner**: a compact status line naming the object, its state and what is
next, and the run keeps going. **Every gate stop is [`jutaisho`](../claude/skills/jutaisho/SKILL.md)
§ 4's full protocol**, all four parts, through `nen stop --who <persona> --gate <Gn> [--notified]
efforts.md`: the banner pasted verbatim, the report link, lettered Crazy Slots options with ⭐ on the
recommendation, and the question through the surface's own picker. A stop that is not a gate is a
**refusal**, never a G5 (ruling of 2026-10-13, ROSTER § *Rulings of 2026-10-13*): it names what is
missing, what was tried and the one act or command that unblocks it, and where the operation resumes —
no banner, no picker ([`WORKFLOW.md`](WORKFLOW.md) § 4 *What is not a gap*). What only the maintainer can do is a G5, an open class, never a refusal (§ 4, ruling of 2026-10-17).
**A phase that acts re-renders the turn report before it stops** —
[`spiritual-message`](../claude/skills/spiritual-message/SKILL.md)'s `turn` variant, the act recorded
in *Accomplished*.

**Say one line in chat and stop** — what was rendered, for what scope, and the link or path — never a
prose summary of the page. **A block that cannot be filled** renders without those rows, shows its
empty-state line and names the gap in *Not delivered*; no page at all is said so. **A markdown recap is
never the fallback** for a page that failed, unless the skill names a declared fallback and says it is
using it.

**Objects are named in `<CODE>-<IS|PR>-#<N>` notation from `nen ref format`, never from memory** — in
a status board, a register row, a ledger line and a final report alike.

**Every pull request a session opens or causes to be opened — a delegated subagent's included, a
release proposal included — reaches the maintainer only through [`hatsu:en`](../claude/skills/en/SKILL.md),
or with `nen pr ready`'s verdict line quoted (with `nen pr body-check`'s, where the PR's body is in scope —
[`pr-state`](../claude/skills/pr-state/SKILL.md)'s rule and [`sharingan`](../claude/skills/sharingan/SKILL.md)
§ 4's conjunction, cited, not re-authored)** (maintainer's incident of 2026-09-22/23, zheref/hatsu#103:
zheref/nen#246 was called "green … ready for you to merge" from `gh pr checks`, and zheref/nen#247 was
relayed "ready (G4)" from a subagent's "macOS, Linux and compile green" while it carried two unresolved
Copilot threads posted after the subagent had stopped). Three consequences, binding on every skill and
every brief: **a subagent brief that opens a PR ends at a quoted `ready` verdict (exit `0`) with zero
unresolved threads, or hands the PR to `en`** — a quoted `not-ready` is reported as not-ready and the PR is
never left unheld, and "checks green" is never a terminus; **the words *ready*, *G2-ready* and *G4-ready*
appear in a report or chat line only beside the quoted verdict line**; and **a `not-ready` verdict on an
excluded or infrastructure row stays `not-ready`, naming the row** — never softened into "ready" because the
failing check is one the maintainer ruled out (a `checks.excluded` entry in `nen/gates.json`, which nen reads
at the pull request's base, is how that ruling reaches the verdict, not a paraphrase). A requested reviewer round not yet posted at the current head is `not-ready` too
(`nen pr ready` row 4; [`sharingan`](../claude/skills/sharingan/SKILL.md) § 5). Under `getsuga` § 3 the
release proposal's verdict returns to getsuga and § 3a merges: en rings no bell for it.

**`ten` § 4's fields and § 4b's line.** Every value of ten's one line is quoted from `nen shu tools`:
the version from `found`, the range from `pinned`, the floor from the `compat floor:` line — else
`floor not reported (nen <version>)` — never inferred from the pin. § 4b's line, carried verbatim by
every surface (zheref/hatsu#67), off Claude Code § 5's too: what was placed (or `mirrors: current` /
`not applicable`), the surface CLI's version (Cursor below its skills minimum **unclaimed**), every
rejected, walked-up or out-versioned root, Cursor's skill names (shadowing), and which `nen` § 2 bound —
the host link or the session bind.

## Publishing a report

**On an artifact-capable surface, a report is an Artifact:**
- **On Claude Code**, republished to ONE URL per key — the skill names the key (the branch for a turn or landing page, the repository for a gate register); a new URL only for a key that has none yet, and a better title never mints a new one. **Read before you overwrite**: a republish notice, or a listing showing a version this session did not publish, means the page moved — re-read it and re-resolve the data rather than repainting what this session happens to be holding.
- **On Antigravity**, published as a native Markdown artifact into `<appDataDir>/brain/<conversation-id>/<report-name>.md` (e.g. `spiritual-message.md` for turn/landing reports, `backlog-board.md` for gate registers, `black-voice.md` for validation) via `write_to_file` with `ArtifactMetadata` (`{ Summary: "<Variant> report for <effort>", UserFacing: true, RequestFeedback: false }`). **Its body is a template's fill, never composed by hand**: § *The Markdown report* below. **One file per report name per conversation**: the path is keyed by `<conversation-id>`, so every render in a conversation writes the same `<report-name>.md`, with `Overwrite: true` whenever it already exists in that conversation's directory, and never a new file per turn; an effort that continues in a new conversation starts its own file there.
- **On Codex**, the page is the ACTIVE worktree's `<reports.dir>/current.html`, overwritten every render, git-ignored, **transient** — and the one chat line names that file by absolute path with the worktree and the branch; a render from another worktree moves the line to its own file, and a tab still showing an older worktree's page is never presented as current (zheref/hatsu#205; `nen report render --out` writes only inside `--repo`, so each worktree holds its own).
- **Elsewhere** (surfaces without native artifact capability, e.g. Cursor), the page is `<reports.dir>/current.html`, overwritten every render, git-ignored, **transient**. **Say which happened.**

**Every object notation on a page is `nen ref format`'s output.** Where it cannot be resolved — no
`nen/repos.json` — the page falls back to `<owner>/<name>#<n>` and the failed resolution goes into
`footerNote`.

## The Markdown report

**One data document, two renders.** Every report variant has a Markdown template beside its HTML one —
[`templates/spiritual-message.md`](../templates/spiritual-message.md) (`turn`, `turn-fast`, `landing`) and
[`templates/rikugan.md`](../templates/rikugan.md) (`final`, `register`) — in `nen report render`'s template
language, filled by the same verb from **the same data document** (spiritual-message § 4; the `--register`
document of backlog-board § 3) and the same `reports.sections.<variant>.blocks`. The surface picks the
extension and nothing else, so the two renders cannot disagree on which blocks a variant shows. The
`report-markdown-guard` lane (`scripts/report_markdown_check.sh`) holds it (zheref/hatsu#215).

**Where a surface's report is a Markdown artifact** (Antigravity; the surface's write call and read-back
command are [`docs/surfaces/antigravity.md`](surfaces/antigravity.md) § 1 *Reports*):

1. **Render** with the HTML render's line, `.md` for `.html`, `--out <reports.dir>/current.md`, and **always
   `--graph`** — an empty graph document where the scope has no shape (`templates/report-examples/final.graph.json`
   is one) — so `graphMermaid` is always nen's serialisation, never a value the data document carried.
   `--out` must resolve inside `--repo`, so the verb cannot write the artifact store itself (§ *Residue and
   owned dependencies*).
2. **The artifact's body is that file's content, verbatim** — never re-read, re-flowed, trimmed or summarised.
3. **Read it back** and compare byte for byte. A difference is written **once** more; a second difference ends
   the publish: the chat line says `artifact differs from render` and the turn yields with the report
   unpublished. A store the shell cannot read is said as `artifact not read back`, never as published.

The dated `final` file stays the HTML render rikugan § 4 keeps.

**Before a Markdown render, the run asserts no newline in any value outside a `<pre>` slot**
(`lastTurnRequestFull`, `launch`, `prBody[].markdown`, an option's `command`): a newline ends the Markdown
line the value sits on, so it could open a forged ask or an unclosed fence. A failing value is dropped and
named in *Not delivered*, like the validations in § *Escaping and validation of report data* — the caller's
interim until nen escapes Markdown.

**Where enforcement is impossible, and what holds instead.** Step 2 is the one path no verb performs — the
copy is the model's own act — so step 3 is its check. A turn where `nen report render` cannot run is **not**
such a path: no page is published and nothing stands in (rikugan § 7, kurapika's Nen-first rule). **The fixed
structure is the template itself**: the blocks are `reports.sections.<variant>.blocks`, in that order, each
opening `<!-- hatsu:block <name> -->` and each ask `<!-- hatsu:ask -->`. The checked example per variant is
`templates/report-examples/<variant>.md`, rendered from `<variant>.data.json` beside it (with
`<variant>.graph.json`, else [`templates/graph.example.json`](../templates/graph.example.json)); the guard holds
each byte for byte to a fresh render, so a reader checks an artifact against it.

## Escaping and validation of report data

These bind every document handed to `nen report render`, for `templates/spiritual-message.html`,
`templates/rikugan.html` and their Markdown twins (§ *The Markdown report*).

**Every key is always present, empty where there is nothing, and every row key is spelled**, because
the template iterates them. A missing token is exit `2` **by design**: a blank cell in a published
report reads as a fact. A list is `[]`, never absent.

**Escaping binds both paths**: every value is repository-controlled, so every value is escaped. In the
HTML the raw form (`{{{token}}}`) is admitted for **one** slot only — the graph document's script tag
(`graphJson`), safe as a renderer property because `serialiseGraph` escapes `<`, `>` and U+2028/9, so
`</script>` cannot occur. The page draws the graph with dagre (cdnjs, integrity-pinned) and keeps the
node and edge list under `<details>` as the text fallback. **Never hand-build SVG or a second
renderer.**

**In the Markdown twins every value is live Markdown, except inside `<pre>` and a fence.** nen escapes
HTML only (`&`, `<`, `>`, `"`, `'`). That neutralises a value as HTML, not as Markdown: a label carrying
`](javascript:…)` is a live link, an image in a question is fetched when the page opens, emphasis and headings
render, and `<code>` does not help (Markdown inside it stays live). GFM shows an entity decoded in text, a
table cell and `<pre>`, and literally in a code span, a fence or an indented code block, so no escaped value
sits in one of those: a command and every multi-line value render in `<pre>` on a line of their own. A `|`
splits a GFM table cell, so a table carries only counts, paths, model names, percentages and fixed words;
free text rides in lists. **Render-time Markdown escaping is owed to nen**, one escaper per output language,
because one data document feeds both renders (§ *Residue and owned dependencies*). Until it lands, link and
image syntax in a third-party title (an issue or PR title, a reviewer's words) is a **named gap**, never
rewritten by the run, and § *The Markdown report*'s newline rule is the caller's interim.

**The Markdown has a second raw slot, `graphMermaid`**, alone inside the `mermaid` fence, and it is safe
**only on the `--graph` path**: nen serialises it from a validated graph document whose `caption`, `label`
and `rel` cannot carry a newline, so no line of it can close the fence. A `graphMermaid` carried in the data
document is the caller's raw text, so a Markdown render always passes `--graph` (which replaces it) and the
guard refuses a sample that carries one.

**Three validations escaping cannot do are the caller's**, run before the document is handed to the
verb:

- a capture source against `^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$`;
- a bar percentage against `^(100|[0-9]{1,2})(\.[0-9]+)?$`;
- **every `url` field** against `^(https?://|mailto:|#|/)` — escaping makes a `javascript:` href
  harmless as text, not as a link.

**A failing value is dropped and named in *Not delivered***, never rendered.

**Options on a spiritual-message ask**: `star` is `"recommended"` on exactly one option and `""` on the rest — the
page draws an inline SVG star, so the value is a label, never the glyph; `starredClass` is `"starred"`
on that option and `""` elsewhere. A maintainer's-word ask stars none.

## The report data document

What `nen report data` already fills, what the caller derives mechanically, what is judgement, and the
desk `--register` reads — stated once here for [`spiritual-message`](../claude/skills/spiritual-message/SKILL.md)
§ 4, [`rikugan`](../claude/skills/rikugan/SKILL.md) § 3 and [`backlog-board`](../claude/skills/backlog-board/SKILL.md)
§ 3 (zheref/hatsu#291; every line verified live against nen `0.22.0`, 2026-10-19).

**Two call rules.** A `--target` read runs as `"$hatsu_root/scripts/gh_token_env.sh" nen report data …`:
without `GH_TOKEN`, every PR row whose readiness nen's own gate must compute (no readable `readiness`
check-run verdict on its head) has `readiness` `null` and, on a `--register` document, its `verdict`
`""`, the reason (*unevaluated … GH_TOKEN is not set*) in the row's `notes` and on stderr. **The desk is
passed by absolute path**: a relative `--register` resolves against `--repo`'s root (`ENOENT` when it is
not there), refused at exit `2`.

**The clock** is [`WORKFLOW.md`](WORKFLOW.md) § `reports`, *Report time*: who fills `generatedAtLocal`,
`generatedDateLocal` and `timeZone` (the plain call, from nen `0.22.0`), and the two documents that call
`scripts/report_time.sh --at` instead — a hand-built one and a `--register` desk. A `final` file name
takes that `generatedDateLocal`.

**The extension's defaults** — spiritual-message § 4's merge. The verb's keys (`repo`, `gate`,
`effortStage`, `stageClass`, `worktree`, `generatedAtLocal`, `turnNumber`) are filled only where they
come back `null`, from the reason on stderr, per *Where the effort is* in [`WORKFLOW.md`](WORKFLOW.md)
§ `reports`. A `null` `repo` is `nen repo resolve --from <path>`'s; that resolve exits `1` in the very
case a `repo` is `null` (a non-hosted origin outside the registry), and then the value is the
`--target` slug when one is known, else it stays `null` — the masthead slot renders blank (verified,
exit `0`) — and `notDelivered[]` and `footerNote` name the missing repo. *New canon*. `--graph`
injects `graphJson`, `graphMermaid`, `graphNodes[]` and `graphEdges[]`, and
`--variant` injects `sections` and `sectionList`; neither is written. Everything below is derived, never
composed; a row marked *new canon* has no live source before this section (only
[`docs/history/v0.42.0-prose-diet.md`](history/v0.42.0-prose-diet.md)) and is the maintainer's to
confirm at G4:

| Key | Default, and how it is derived |
|---|---|
| `variant` | the `--variant` value — the render does not inject it |
| `turnLabel` | from `turnNumber`, per *Where the effort is* (`Turn <n>`; `Landing · after turn <n>`) |
| `architectureCaption` | the graph document's `caption` — the render does not inject it. `turn` and `landing` take `--graph` and refuse without it (exit `2`; spiritual-message §§ 5/6); only `turn-fast`, rendered with no `--graph`, takes `""`. *New canon* |
| `spendPhases[]`, `hasSpendPhases`, `noSpendPhases` | `phases[]`, by spiritual-message § 4's per-phase rule |
| `spendUsage[]`, `actionsMinutes`, `spendNote` | `usage[]`, by the same rule; `spendNote` is `""` unless a muted line is owed |
| `tests[]`, `touchedCoverage[]` | re-mapped from `nen shu test-report` and the saved `nen shu coverage --touched`; `[]` while the owning phase has not run |
| `ask`, `deskCleared` | `null` and the cleared line when the turn owes nothing; `deskCleared` is `""` beside a non-null `ask` |
| `readiness[]`, `prBody[]` | `[]` on `turn` and `turn-fast`; on `landing` one row each — `nen pr ready`'s verdict verbatim, [`shibari`](../claude/skills/shibari/SKILL.md)'s body |
| `mukaiLastTurn`, `lastTurnCorrections[]`, `lastTurnCheckIssues[]`, `lastTurnStops[]` | `false` and `[]` unless the last human request was `mukai` (En's first `landing` included when mukai started En in the same sitting and no newer human request came) — the boolean the [`report-examples`](../templates/report-examples/) carry. *New canon* |
| `captures[]`, `evidenceUnavailable` | `[]` and `""` when no evidence is owed or it is present; the reason when owed evidence is missing |
| `launch` | a `ren` turn: the line [`amaterasu`](../claude/skills/amaterasu/SKILL.md) recorded this turn, verbatim — the command it ran, or its reason line (`no launch target declared; skipped`, § 1; the profile deferral, § 1a; `core launch deferred; explicit maintainer call required`, § 3). A `landing` (launch is never a mukai step), or any turn amaterasu did not run in: the line of the last amaterasu call on this effort; with none, `no launch target declared; skipped` where `project.launch` declares no target, else `no launch in this session`. Never `""`. *New canon*: the landing and no-call cases (`no launch in this session` survives only in [`docs/history/v0.42.0-prose-diet.md`](history/v0.42.0-prose-diet.md)) |
| `footerNote` | `""`; or the failed `nen ref format` resolution (§ *Publishing a report*); or, with `repo` `null`, the missing repo and why (above). *New canon*: the missing-repo clause |

**The remainder is judgement, and is all the caller writes**: `title` ([`WORKFLOW.md`](WORKFLOW.md)
§ *Report titles*), the four tallies, a non-null `ask` with its options and `blocker`,
`lastTurnRequest` and `lastTurnRequestFull` (verbatim), `lastTurnHighlights[]`, `accomplished[]`,
`challenges[]`, `notDelivered[]`, `decisions[]`, the `captures[]` rows, and — when the last request was
`mukai` — `mukaiLastTurn: true` with the rows of `lastTurnCorrections[]`, `lastTurnCheckIssues[]` and
`lastTurnStops[]`. No verb or script derives the defaults above or composes the merge: that is residue
(§ *Residue and owned dependencies*).

**The desk `--register` reads.** Its full shape is `nen report data --help`'s and every refusal reprints
it. Three rules the refusals taught (HA-PR-#278), each refused at exit `2`:

| Rule | A desk that breaks it | nen's refusal |
|---|---|---|
| an ask's `objects[]` are `{label, url}` objects | `"objects": ["https://…/pull/1"]` | `gates[0].asks[0].objects[0] is '…', not a { label, url } object` |
| `cleared` is a string — the line the page shows | `"cleared": true` | `gates[0] has 'cleared' of a boolean, not a string` |
| a gate carries `asks` **or** `cleared`, never both and never neither; `asks` is a list, `[]` on a cleared gate | `"cleared"` beside a non-empty `asks` | `gates[0] has asks AND a 'cleared' line` |

On this desk the starred option is `"star": true`, unlike the spiritual-message ask's `"star": "recommended"`.
A minimal valid desk — one ask, one cleared gate, and the `generatedAtLocal` placeholder a real desk
fills (*The clock*, above), so a copied example never shows a raw UTC instant (exit `0`):

```json
{ "variant": "register", "title": "Gate Register", "scope": "HA#291", "gate": "G4",
  "generatedAtLocal": "<report_time.sh --at <the plain pass's generatedAt>>",
  "gates": [
    { "gate": "G4", "label": "Policy merge", "asks": [
      { "kind": "MERGE", "rank": 1, "title": "Merge HA-PR-#1", "why": "its verdict is ready",
        "options": [{ "letter": "A", "label": "Merge",
                      "command": "gh pr merge 1 --repo zheref/hatsu --merge --match-head-commit <sha>",
                      "consequence": "it lands", "star": true }],
        "objects": [{ "label": "HA-PR-#1", "url": "https://github.com/zheref/hatsu/pull/1" }] } ] },
    { "gate": "G3", "label": "Release", "cleared": "nothing owed at G3", "asks": [] } ] }
```

## Authority every phase shares

**Shared policy is resolved at the Hatsu plugin root, never read from the consumer's working
directory**, as [`ten`](../claude/skills/ten/SKILL.md) § 0 says. **A path into the
plugin is built from `$hatsu_root`, never from `$CLAUDE_PLUGIN_ROOT` alone**, which is empty outside a
skill invocation and unset on the other surfaces ([`WORKFLOW.md`](WORKFLOW.md) § 6).

**The declaration gate is the repository's ROLE, not the file's kind** ([`WORKFLOW.md`](WORKFLOW.md)
§ *Gate derivation*): **G4** in a canon repository, **G2** in a consumer one. A skill that writes or
sends a declaration resolves the target repository first and says which gate it stands at.

**A phase nested inside a composite holds none of that composite's authority**, and the composite
lends none: being a step inside `ren`, `mukai`, `en` or any composite grants no push, commit, PR,
label, merge, tag, deploy or review vote the phase does not hold in its own right. A reporting or
signalling phase carries **no `CON-25`-equivalent delegation**: its authority is exactly its own
*Permitted* list, whatever called it.

**A reading never authorises a push, merge or release path** ([HR-3](ROSTER.md#hr-3)): such a path
cites a ruling-status row, and a path whose only authority is a reading asks once per run (row
`missing-maintainer-choice`).

## Reviewer rounds and review threads

The **policy** — when a round is owed, the cap, never before [`hanten`](../claude/skills/hanten/SKILL.md)
settles — is [`sharingan`](../claude/skills/sharingan/SKILL.md) § 6's. The **mechanics** every phase
that requests a round or answers a thread shares (`shibari`, `sharingan`, `en`) are here.

**A round is complete when every finding has a disposition**, not when a fix commit exists: a fresh
snapshot shows every accepted finding fixed in a pushed commit, every summary-only one given a
PR-level disposition, every thread replied to and resolved, and no earlier request pending — **never
an unfixed finding resolved to clear a counter**.

**Thread hygiene is a verb**: every inline thread gets an on-thread **disposition** (a reply) and is
**resolved only when addressed**.

**A reply that names a commit names one on the pull request's head chain** (zheref/hatsu#139). The
commit is the `sha` this invocation's `nen commit write --json` reported (exit `0`, `sha` not null) —
read **after** kokusen § 5's exit `3` settles (the verb's own read-back, nen `0.19`), so a commit that
exit `3` dropped and re-ran is replaced by the re-run's `sha`; an earlier commit (a delegate's, or one already pushed before a
session died) is read from the commit that carries the fix **in the fetched head's history** — read the head from
`nen pr ready <ref>`'s *judged head* line and `git -C <path> fetch` first, then
`git -C <path> log <head> -- <path of the fix>`, because another checkout may have pushed it and the
local `HEAD` can be stale — never from memory. The check below proves the commit is on the chain, not that it is this fix's — the
`sha`'s origin does that. After the
push, read the PR's head from `nen pr ready <ref>`'s *judged head* line (run inside the checkout with
`GH_TOKEN` set; a `judged head: (unread)` line is a read that could not be made), `git -C <path> fetch`,
and require `git -C <path> merge-base --is-ancestor <sha> <head>` to exit `0` — the head itself, or a
later commit on top of it. Where nothing may have landed after it, `nen pr ready <ref> --require-head
<sha>` pins the exact head; **the test is the *judged head* line naming `<sha>`, never the exit code**:
exit `8` is a mismatch and holds the reply, and exit `0` or `1` counts as pinned only when that line
names `<sha>` (exit `1` also means a matched head that is merely not ready, or an unread head). A `sha`
not yet on the chain right after a push that exited `0` is read once more after the push registers
(a push in flight is judged as its parent) before it is reported as held. Only then is the reply written, naming that `sha`; compose its body
after these reads, never before. **Every other outcome holds the reply** — never posted naming a SHA —
and reports the step, its exit and the SHAs it read: a refused write (a missing message file, a red
proof, a hook refusal: the head unmoved), a write that made no commit (`--dry-run`: exit `0`, no `sha`),
a refused push, a `sha` not on the head chain, or a read that could not be made (the PR read, the fetch).
**A held reply is released** when a later write-and-push reads back clean, or when the held `sha` is
found on the head chain — the resume case, a commit pushed before the session that wrote it died.

```bash
nen pr threads list    --target <owner/name> --pr <n>
nen pr threads reply   --target <owner/name> --pr <n> --thread <id> --body-file <abs path>
nen pr threads resolve --target <owner/name> --pr <n> --thread <id>
```

**Requesting a round.** Through `scripts/gh_token_env.sh` (§ *Residue and owned dependencies*,
#218) — the **maintainer's** user token; a bot token silently no-ops. Humans go through `--add-reviewers <a,b>`. **Copilot is a `Bot`**, which
`gh pr edit --add-reviewer` and `…/requested_reviewers` never resolve, so it goes through
`--add-bots <node id>`, the id **data** read off the target's own reviewer set (`BOT_kgDOCnlnWA` in
`zheref/hatsu`); `--add-bots copilot` cannot resolve it today (zheref/nen#160). A bare login that is
neither collaborator nor bot is exit `2` pointing at `--add-bots`; both flags absent, exit `1`. The
same mutation answers `NOT_FOUND` under one token and succeeds under another, so **report success
from the mutation's own response, never from the ids sent**, and check first whether Copilot already
reviews the repository automatically. **The verb is the only route** — never a raw GraphQL
`requestReviews(botIds:…)`, never `gh api` (zheref/hatsu#102): a request outside the verb is one no
ceiling can count. **An event-driven reviewer lane is never requested** (*Event-driven reviewer lanes*,
below).

```bash
nen pr request-reviews --target <owner/name> --pr <n> [--add-reviewers <a,b>] [--add-bots <id,...>]
```

**Verify with `nen pr ready`, never REST** (REST shows a pending bot as `[]`): *no round at head* is
one owed; *review requested, not yet posted* is one in flight — wait.

**One bot reviewer suffices — the round quorum** (the maintainer's ruling of 2026-09-29, recorded in nen's
`docs/USAGE.md` § *`round_quorum`* — *"at least one round of reviews from both Copilot OR Cursor (or
both)"* — and restated 2026-10-04: [`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-04 — one bot reviewer
suffices*; **stated once, here**, cited by [`GATE-CONFIGURATION.md`](GATE-CONFIGURATION.md) § 3 and that
ROSTER section; since the maintainer's ruling of 2026-10-04, *retire 2, adopt 2*, it is also what replaced
the fallback chain, below). The repository declares
it as **nen's** key `round_quorum` in `nen/gates.json` — `{ "any_of": [<reviewers[] names>], "minimum": <n> }`
— and `nen pr ready` reads it from nen `0.17`: at least `minimum` of `any_of` must **have** a round on the
PR (a posted review or a `SUCCESS` round check, at any earlier head under the `bounded` reading Hatsu runs;
how many rounds Hatsu asks for is `round_policy.minRounds`, `sharingan` § 6). **Once met, the quorum fulfils
the owed round of every `any_of` member that is unavailable** — in nen's own terms: no round-check run at
head; a run that completed without a round (`NEUTRAL`, error, `CANCELLED`, `SKIPPED`, `FAILURE` — an
exhausted reviewer among them); or a member with only a pending review request and no round check,
Copilot's shape — and **never a member whose round-check run at head is still in flight** (`QUEUED`,
`IN_PROGRESS`, `PENDING`, `WAITING`: mid-review, still owed). That is a narrower *in flight* than *review
requested, not yet posted — wait* above: a pending request with no check is excused once the quorum is met
(zheref/nen#361). So where Bugbot is exhausted Copilot's round suffices, and the other way around; a
reviewer not in `any_of` is owed as before, and a stalled request or an unresolved thread fails as before.
An unmet quorum with no member owed (an exempt member in `any_of`, or CI reviewer lanes short of `minimum` —
*Event-driven reviewer lanes*, below; unreachable in Hatsu's own file today, reachable on any consumer with two
or more lanes) reads `round quorum not met` and is one owed round of the first `any_of` member **with no round
yet** that `reviewers[]` can request, under `sharingan` § 6's bounds (this run's reading, listed in ROSTER) —
a member that already has its round adds nothing to a count of distinct members; with no such member (only
lanes are short) nothing is requested, and the PR ends at `cap-reached`'s terminus. The *fulfils* half ships in nen `v0.20.0`,
the pin zheref/hatsu#168 moved; a binary older than it still reads an unavailable member's round
as owed, the verdict is quoted as the verb prints it, and the owed member is handled by `sharingan` § 6's
request bound. Unavailability is observed, never declared; the stop it can lead to is defined once, below.

**Event-driven reviewer lanes** (the maintainer's rulings of 2026-10-19, [`ROSTER.md`](ROSTER.md) § *Rulings
of 2026-10-19 — the CI reviewers tier*; zheref/hatsu#330 — **stated once, here**; `sharingan` § 6, `en` §§ 5–6,
`shibari` § 5, `pr-state` § 2, `nen/decisions.json` rows `reviewer-exhausted` and `ai-reviewers`,
[`GATE-CONFIGURATION.md`](GATE-CONFIGURATION.md) § 3, [`WORKFLOW.md`](WORKFLOW.md) § 2 (`aiReviewers`, `ci`),
`docs/config/{workflow,gates,decisions}.json.md` and that ROSTER section cite this paragraph). A **lane** is
a CI reviewer — an Akatsuki tier lane (`AK`), installed by `kuchiyose` (zheref/hatsu#331) — that
runs on every push to the pull request and posts under its own GitHub App login. **Its round is its formal
review posted under that login.** Under the `bounded` reading Hatsu runs, a review at any earlier head
counts, because no request of the lane is ever pending; and a lane, outside `base_reviewers` with no
`enrolment_check_pattern`, is **never owed on its own** — nen counts it toward `round_quorum` only. **It is
never requested**: never in `base_reviewers`, and `shibari` and `sharingan` never call `nen pr
request-reviews` for a lane; from nen `0.26` the entry declares it, `wake: "event"` (zheref/nen#440, nen USAGE *Event lanes*). **A push re-runs the lane**
(`cancel-in-progress`), and its check, pending at the new head, holds `checks-green` like any running check
until it concludes: that is the current-head wait — never a request, and never a stall by itself. A lane
check `nen pr ready <ref> --json` lists in `meta.runnerAvailability[]` (still waiting for a runner at the
judged head) for longer than `round_policy.stallMinutes` — its entry's `queuedMinutes`, or, where nen
returns that null, `en`'s own first observation of it waiting at this head — is a named impossible
condition for the watch, reported not-ready with the check's state quoted; a lane check `IN_PROGRESS` is
bounded by the lane's own job timeout, and one that concludes `CANCELLED` or `FAILURE` at head is a fault
in the lane, reported the same way, never a code fix to author. Both are a Hatsu reading: nen's runner
diagnosis never moves the verdict. For a `wake: "event"` entry (nen `0.26`), a live run at the judged head
supersedes the lane's earlier review, under `bounded` too, and stays owed while in flight even across a met
quorum; a terminal run without a formal review reads `completed-without-review` and is excused only by a met
quorum (nen USAGE *Event lanes*). **A lane whose check concluded green with no
review is unavailable** (unprovisioned: the lane exits green without running, `AK`'s reviewer-lane issue):
nen counts no round for it, so a met quorum covers it and an unmet one is owed through the quorum clause.
**`round_check_pattern` is declared only for a lane whose check is its round**, and that check's conclusion
when the lane did not review must be `NEUTRAL` or `SKIPPED` — never `SUCCESS`, which nen would count as a
round nobody ran, and never `FAILURE`, which fails `checks-green` (`CON-32(a)`) on every head the lane sits
out; its `NEUTRAL` or `SKIPPED` at head is one of *The sixth stop*'s (c) observations when `roundQuorum`
reports it from `head` (no earlier-head round). nen matches that check **by name alone** — a job of the same
name, one the pull request adds included, counts — so the posted-review shape, bound to the App's login,
is preferred wherever the tier catalogue offers both. A posted-review
lane's `reviewers[]` entry declares `login_pattern` (anchored to the App's exact login) and **no
`round_check_pattern`**; a `review_check_pattern` may name its check, and nen reads that key only for a
`delivery_holistic_pass` reviewer. **The quorum** (ruling *"Join any_of, minimum 2 when 2+ lanes
installed"*): every installed lane joins `round_quorum.any_of` — which keeps (e) below true — and `minimum`
is `2` once two or more lanes are installed, `1` otherwise. **The consequence, accepted with the ruling:**
with `minimum` `2`, a PR on which only one bot has a round while another member is still available (a lane
in flight, or a bot with no round yet that can still be requested) is `rounds-owed` under `sharingan` § 6's bounds —
not-ready at `cap-reached`'s terminus once a bound is reached — and *The sixth stop* is reached only when
every member is unavailable **by (c)'s observations**; a posted-review lane makes none of them (it is never
requested, and declares no round check); nen `0.26` exposes its state as `eventRun.state` (zheref/nen#440), but
reading those states as (c)'s observations is unruled, so until a ruling does, under `required` a PR
whose quorum is unmet with such a lane installed ends at `cap-reached`'s terminus, never the sixth stop.
Under an effective `aiReviewers: optional` or `off` the hanten prompt (below) applies unchanged. **The gates file is
the base's** (zheref/nen#372, in the pinned nen `0.26`): without `--gates`, nen reads `reviewers[]`,
`round_quorum` and every other gate input at the pull request's base, so a PR that changes either key,
`kuchiyose`'s install PR among them, is judged by the declaration it would replace, never its own (SEC-6).
`kuchiyose verify`'s lane-state read passes a copy from outside the checkout instead, which nen uses as given
(`meta.identities.read: gates-flag`) and which is never that PR's readiness.

**The sixth stop — every quorum member unavailable (the canonical predicate).** The maintainer's ruling
of 2026-10-11, *Prompt on hanten* ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-11 — prompt on
hanten*), keeps the 2026-09-29 intent: such a PR goes to `en` § 5's merge prompt on hanten's rounds (`en`
§ 6, the sixth stop). **Stated once, here**; `sharingan` § 6, `en` §§ 5–6, `nen/decisions.json` rows
`reviewer-exhausted` and `own-pr-merge`, `docs/WORKFLOW.md`'s G5 list, `docs/config/decisions.json.md` and
that ROSTER section cite this paragraph and restate nothing. **It applies under `aiReviewers: required`**
(the default; *AI reviewers per consumer*, below, replaces it under `optional` and `off`). It is reached **only when all five hold**,
read from `nen pr ready <ref> --json` at the judged head (`judgedHead`):

- **(a) A quorum is declared.** `nen/gates.json` carries `round_quorum` with a non-empty `any_of`. With no
  block there is no sixth stop.
- **(b) The round row is the only failing row.** `failing` is exactly `["rounds-owed"]` (CON-32(b)). Any
  other failing row — `mergeable` (a conflict or a draft), `checks-green`, `round-stalled`,
  `approvals-at-head`, `unresolved-threads`, or one this list does not name — ends at row `cap-reached`'s
  not-ready terminus, no prompt. And on that row only `any_of` members may be owed: (e).
- **(c) Every `any_of` member is unavailable at this head**, each by one of two observations, never by
  declaration:
  - `nen pr request-reviews` answered **exit `9`** for it, the bot named in `unrecordedBots` — GitHub
    accepted the request and never recorded it (zheref/nen#277). Such a request is never retried and never
    counted as requested. Exit `1` in the same call wins and is relayed as a failure, never read as `9`;
  - a round-check run **at the judged head that completed without a round**, read structurally from the
    `rounds-owed` row's `roundQuorum.members[].roundCheck`: `from` is `head` and `conclusion` is one of
    `NEUTRAL`, `CANCELLED`, `SKIPPED`, `FAILURE` (zheref/nen#361's classification — Cursor Bugbot's
    `NEUTRAL` "usage limit reached" is the case). **No run at head never counts**: right after a push it
    cannot be told from a run not yet created, so it is a wait, or `round-stalled`. Nor does a run still
    **in flight** (`QUEUED`, `IN_PROGRESS`, `PENDING`, `WAITING`), nor a pending request that never came
    back at exit `9`.
- **(d) The observation is bound to the judged head.** Read `headRefOid` immediately before each
  `nen pr request-reviews` call and record it with that call's `--json` output (`unrecordedBots` and
  `message`) **verbatim**. An exit `9` counts only when that head equals the head `en` § 5 check 5 judged;
  otherwise it is stale, and one fresh request at the new head is owed, inside `round_policy.maxRounds`.
- **(e) No reviewer outside `any_of` is owed, read from nen's owed list** ([HR-365](ROSTER.md#hr-365),
  the maintainer's ruling of 2026-10-22; zheref/hatsu#430). nen's `rounds-owed` row also owes configured
  reviewers that are not quorum members, and a met or unmet quorum never excuses them. The pinned nen
  lists the owed rounds on that row as `owedRounds[]`, each entry carrying `reviewer`, `reason`,
  `coveredByQuorum`, and optionally `kind` (where `nen/gates.json` declares one), `state` and
  `waivedByAiPolicy` (`nen pr ready --help`, nen `0.26`); (e) reads only `reviewer`. It holds when the
  row carries `owedRounds[]` and every entry's `reviewer` is a name in the row's `roundQuorum.anyOf`; an
  empty `owedRounds[]` is computed with none owed, so (e) holds. An entry outside `anyOf`, whatever its
  `kind`, ends the PR at `cap-reached`'s not-ready terminus, no prompt. So does a row with no
  `owedRounds[]`: nen omits it when it did not compute the list, and absent is never read as none owed.
  `coveredByQuorum` is not the test, since it marks a member a met quorum excused and at this stop the
  quorum is unmet; the row's `reason` is prose, never parsed. A target whose `reviewers[]` all sit in
  `any_of` (Hatsu's own file today: `copilot` in both) can owe no one outside it. One that enrols a
  reviewer outside `any_of` reaches the stop when that reviewer's round is not owed at the judged head.

At the stop, `nen pr ready`'s **not-ready verdict is quoted verbatim and never called `ready`**, and the one
Hatsu line `en` writes into the PR body through `nen pr edit-body` carries the recorded head and the
verbatim `--json` output of each exit-`9` call — what nen observed, not a paraphrase. The stop outranks
the round ceiling; the merge stays the maintainer's (`en` never merges). Any unmet quorum that misses
one of (a)–(e) stays under `sharingan` § 6's bounds. Nothing in this paragraph is read by a Hatsu script; the verb
reads the key.

### AI reviewers per consumer — `aiReviewers`

(The maintainer's rulings of 2026-10-11,
[`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-11 — AI reviewers per consumer*; zheref/hatsu#245 —
**stated once, here**; `sharingan` § 6, `en` §§ 5–6, `pr-state` § 2, `nen/decisions.json` row
`ai-reviewers`, `docs/WORKFLOW.md` § 2 → `aiReviewers` and `docs/config/workflow.json.md` cite this
paragraph). `nen/workflow.json` → `aiReviewers` is one value for **every automated reviewer** in
`nen/gates.json` → `reviewers[]` (`CON-16`'s *configured automated reviewer*), and it gates both their
**use** — whether `nen pr request-reviews` is called for them — and their **expectation** — whether the
run waits for their round. **Event-driven lanes included** (the ruling of 2026-10-19, *"One value for every
bot"*): a lane is never requested under any value (*Event-driven reviewer lanes*, above), so the value
gates only its expectation, and `off` on a consumer with installed lanes means their rounds are not
expected while the lanes still run and post — a consumer turns a lane off through its own caller workflow,
never through this value.

**Where the value is read — never from the pull request itself (SEC-6).** A pull request must not relax
its own gate, so the **effective value** is read, for every decision below (request and prompt alike), from
`nen/workflow.json` at **two refs**, never from the local checkout (which is the PR head):

```bash
node '<installed Hatsu root>/scripts/gh_api_read.mts' workflow-content <owner/name> <baseRefOid>
node '<installed Hatsu root>/scripts/gh_api_read.mts' workflow-content <owner/name> <default-branch>
```

Replace the root placeholder with the resolved absolute Hatsu plugin root before sending the Bash command; the installed Claude permission rule matches that literal path, not a shell variable.

— the pull request's base commit, and the default branch's tip — and the **stricter** of the two applies:
`required` > `optional` > `off`. A read that fails, a file or key that is absent, a file that does not parse,
or a value outside the three reads **`required`** for that ref. A PR that changes `aiReviewers` itself is
therefore judged by the value already merged; its own change applies after it merges. That is what
"settable by hand or by an agent" means here: `config_values.sh set`, `tenkai` § 6d or a hand edit writes
the value, and it **takes effect through a merged change**, never on the PR that carries it. The same reads
return that ref's `nen/gates.json` for the reviewer criterion below. The Hatsu line names the value and both
sources, e.g. `aiReviewers: optional (base <sha>, default <sha>)`. **nen reads the value too**, from nen
`0.26` (NN-PR-#463): `nen pr ready` and `nen pr merge --release-unit` read it at the same two refs, by the same
stricter-wins and absent-reads-`required` rule, and print it as `aiReviewers <effective>; base <sha>: <value>;
default tip <sha>: <value>`. **For the expectation half nen's printed value governs** ([HR-333](ROSTER.md#hr-333)):
the hanten prompt below is entered on it and the Hatsu line restates it. Hatsu's own reads remain for the
**use** half, because no nen verb decides whether `request-reviews` is called, and for the reviewer criterion
below. Where Hatsu's read and nen's disagree (for example one side's read failed and fell back to `required`, or the default tip moved between the two reads), the
stricter applies and the disagreement is said beside the verdict.

| Value | Use | Expectation | Terminus |
|---|---|---|---|
| **`required`** (absent reads the same — every consumer keeps today's behaviour) | requested within `round_policy`'s caps (`sharingan` § 6) | expected | verified Ready, or *The sixth stop* (a)–(e) above |
| **`optional`** | requested within the caps | never waited for | Ready (a declared bot's round waived by nen, below), or the **hanten prompt** below |
| **`off`** | **never requested** — `sharingan` and `en` skip `request-reviews` for `reviewers[]`; zero spend on requested reviewers (installed CI lanes still run: *Event-driven reviewer lanes*) | never waited for | Ready (a declared bot's round waived by nen, below), or the **hanten prompt** below |

**nen's waiver — a declared bot's round** (zheref/hatsu#428; [HR-333](ROSTER.md#hr-333), ruled 2026-10-22). Under an effective `optional` or `off`, nen waives the owed round of every
reviewer that `nen/gates.json` declares `kind: "bot"` with an **identical declaration at the base and at the
default branch's tip**: the parsed identity is compared (`name`, `kind` and the patterns and options), never
a `$comment`. It reports the waiver as `owedRounds[].waivedByAiPolicy` in `--json`, as a `waived bot round:
<name>` line in the plain output, and as the `aiReviewers quorum waivers: <names>; binding <n>/<m>` line.
The verdict reads **`ready`** when the only owed rounds are waived bots' rounds **and** the round quorum's
unwaived members meet it (`binding <n>/<m>`; with every member a waived bot, `0/0` meets it). `en` § 5's
merge prompt then runs on that verified Ready, with the verdict and its waiver lines quoted and no ruling
cited by hand, **`hanten` having settled every finding for the change set**: a waived round never stands for a
change nobody reviewed. **On a release proposal** HR-333's getsuga limb carries no hanten condition: `getsuga` § 3a
merges a proposal whose only owed round is so waived, which no hanten raises, with its `release.unitPaths` bound and
the verb's five gates still binding. Hatsu declares its one reviewer, Copilot, a bot. These still bind under the waiver:
a reviewer declared `kind: "human"` or with no `kind`, a declaration that differs between the two refs, a
stall, an approval, and every other row. **The declaration is read at the base**, so the PR that adds it, and
any PR whose base predates it, is judged without it. Such a PR, and a declaration that differs between the
refs, is judged by the hanten prompt below.

**The hanten prompt** (under an effective `optional` or `off`, for a round nen did not waive): when `nen pr
ready <ref> --json` at the judged head has `failing` exactly `["rounds-owed"]`, `hanten` has settled every finding for the change set,
and **every reviewer that row can owe is automated** (below), the PR goes to `en` § 5's merge prompt on
hanten's rounds. `nen pr ready`'s **not-ready verdict is quoted verbatim and
never called `ready`**, with one Hatsu line beside it naming the value and its source refs —
`aiReviewers: optional (base <sha>, default <sha>)` —
written into the body's completion checklist through `nen pr edit-body`. **Every reviewer must be
automated — the analogue of *The sixth stop*'s (e).** nen's `rounds-owed` row owes every configured
reviewer whose round it did not waive, and `reviewers[]` may hold a human. nen lists the owed rounds
(`owedRounds[]`, each with its declared `kind`), but it waives only a bot declaration that is consistent at
both refs. So, for a round nen did not waive, the criterion is checked against
`nen/gates.json` at **both refs**, the base and the default branch's tip, and **must pass at both**: **every
`reviewers[]` entry's `name` is listed in `round_quorum.any_of`, its `login_pattern.pattern` is anchored
(begins `^`, ends `$`), and no entry declares `kind: "human"`**. **It is a declaration, not a check that a reviewer is a bot**: `any_of` is the
repository saying a reviewer is one of its interchangeable bot reviewers, and nen does not bind a pattern
to bot logins — an anchored `^(copilot|.+)$` passes `nen schema check` and matches every login. Declaring a
human there is the repository's own misdeclaration, the same as a broad `any_of` pattern
(`docs/GATE-CONFIGURATION.md` § 3, *round_quorum*). Hatsu's own file qualifies (`copilot`, `^(copilot|copilot-pull-request-reviewer(\[bot\])?)$`, in
`any_of`). Where any entry misses it at either ref, the PR ends at `cap-reached`'s not-ready terminus, no prompt.
This rule is the fallback for the transition (the PR that adds a bot declaration, and a PR whose base predates
it) and for a consumer that has not declared its bots. **A bot that does post is settled
first**: its threads are answered and resolved, and an unresolved thread is `unresolved-threads`, its own
failing row, so no prompt until then. **Nothing else is relaxed**: any other failing row — `mergeable`,
`checks-green`, `round-stalled`, `approvals-at-head`, `unresolved-threads` — ends at `cap-reached`'s
not-ready terminus, no prompt; `CON-32(a)`, `(c)` and `(d)` stand as they are. This is coherent with
`CON-16`, under which only enabled reviewers gate and the maintainer has declared these not expected, and
with `CON-32(b)`, because the verdict is still quoted not-ready and never represented as ready; the merge
stays the maintainer's. **Precedence:** under `required`, *The sixth stop* is unchanged; under `optional`
and `off` this rule replaces it, being the wider one. **A value outside the three** is not read as any of
them: it is `missing-configuration`, set through `scripts/config_values.sh set` (which refuses it, naming
the three), and `required` applies meanwhile. **`round_policy.maxRounds: 0` is not an off switch** — it
stops requests, but nen still owes the round, so under `required` the PR stays not-ready with no prompt;
this key is the off switch.

**The fallback chain — retired** (ruling 2026-09-29, retired by the maintainer's ruling of 2026-10-04,
*retire 2, adopt 2*: [`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-04 — retire 2, adopt 2*;
zheref/hatsu#227). Hatsu's `nen/gates.json` → `reviewer_fallback` — a chain of reviewer identities, a
`terminal: hanten`, and dated `exhausted[]` rows that sent a PR to the merge prompt on hanten's review alone
— is deleted, superseded by `round_quorum` and zheref/nen#361: one available bot's round fulfils an
exhausted member's, which is what the chain existed to buy. nen `v0.21.0` refuses the key outright
(zheref/nen#310), so it cannot be declared again. **No exhaustion is declared anywhere now**, and nothing
narrows the verdict past an owed reviewer on Hatsu's side; a request the mutation accepts with no pending
reviewer coming back is reported by the verb at exit `9`, the bot in `unrecordedBots` (zheref/nen#277) —
the observation the paragraph above acts on. The chain's terminus survives in that form, by the ruling of
2026-10-11. The 2026-09-29 record stays in ROSTER
as history; `docs/ab/sharingan.md` § *Dated 2026-09-29 — the reviewer fallback chain* is its evidence.

## Resuming a run

**A composite run is resumable by re-invocation, never by memory.** The same call re-reads live state
and picks up where the objects are. The run writes its decisions, every logged label application and
its progress to `docs/Loop/<run-id>/`, and **that directory is a transcript, never trusted over a
fetch**.

## Surfaces and pickers

**Raising an isolated delegate off Claude Code — the adapter contract.** Where a skill raises a
subagent (a reviewer, a subsession) and the surface is not Claude Code, the mechanism changes and the
contract does not. An adapter supplies:

- an **isolated worker at the declared tier**, never the frontier tier;
- an **isolated copy of the repository the delegate works on**;
- **one returned document in the skill's declared shape**;
- a **title carrying `<skill> · <persona> · <alias>`**.

Where the surface supplies fewer, the skill **says which** ([`SURFACES.md`](SURFACES.md) and
`docs/surfaces/<surface>.md` have the mechanics). **Where a surface offers no delegation at all**, the
work runs in-session as named **sequential** passes, one scope at a time, in the same returned shape,
**saying so** — and an in-session pass is never presented as a raised delegate.

**Every question goes through the surface's own option picker** — `AskUserQuestion` on Claude Code,
`request_user_input` on Codex, `AskQuestion` on Cursor, `ask_question` on Antigravity — never a
paragraph ending in a question mark. **A deferred picker tool is loaded first**, never treated as
absent; only a surface with none prints lettered options in chat, closing with *answer with a letter*,
and says so. **The picker carries the question alone**, the stop's other parts in the chat message
([`jutaisho`](../claude/skills/jutaisho/SKILL.md) § 4 states the shape; ruling of 2026-10-17, zheref/hatsu#294).
**A command the maintainer must run is handed over as a runnable block** ([`WORKFLOW.md`](WORKFLOW.md) § 4
states the rule; zheref/hatsu#295).

**`ten` § 5's rules.** `scripts/surface_mirror_check.sh` exit `0` is `mirrors: current`; `1` is stale
**in the plugin** — said, still placed, regenerated in a PR. **On Claude Code there is no mirror**, so
`mirrors:` is whether the copy Claude Code serves IS the source (zheref/hatsu#122), the permission pack
placed beside it ([`using/mirrors.md`](using/mirrors.md) § 2):

```bash
nen surface status --surface claude-code --plugin hatsu --root "$hatsu_root"
```

The verb (nen 0.21.0, zheref/nen#339; the script `plugin_cache_check` retired by zheref/hatsu#289 item 6) judges every copy Claude Code has recorded for Hatsu (each `hatsu@` installPath and `skills/hatsu`),
and **a copy is never its own evidence**: where the served copy IS `--root` (ten § 0 resolves it from
the served skill directory), it compares against a source named independently — `HATSU_PLUGIN_ROOT`,
a `directory` marketplace, or the Hatsu checkout ten stands in. `0` is `mirrors: current (<the line>)`;
`1` is `mirrors: stale cache` with the differing paths, and § 4b's update is what refreshes it (re-run
it after); `3` is `mirrors: not installed` (no `hatsu@` install record and no `skills/hatsu`); `4` is
`mirrors: not comparable (<the line>)` — the served copy is the only copy (a working directory on a feature branch is no source), or no `jq` read the record;
`5` is `mirrors: broken install (<the line>)` — an entry with no usable installPath, a stale record, a
dangling link; `2` is a wiring stop, quoted. Only `0` reads current. **Ten never
generates a mirror**; `surface_bootstrap.sh` is the pre-skill shell carve-out; Cursor lists
`.cursor/skills` **before installing**; the models are the TARGET's `nen/workflow.json` → `models`.

## PR composition before every write

[PR-SECTIONS.md](PR-SECTIONS.md) is the shared procedure for `shibari`, `tensho`, `jujisho` and
review-driven body edits. Resolve kind × family sections and per-run requirements before drafting;
reuse Mukai's evidence, economics and gate-hit facts. Run the sections, Nen body-check, evidence
and Development guards before every create/edit, and verify Development after reading the write
back. Seven reader sections exclude the compact footer; prose beyond 150 words warns only.
Kind-specific verification is the `CON-17(b)` observable proxy; **How to verify** is the product title.
NN#448 is merged but does not replace the authorized interim scripts until a released pin carries it.

## An unresolved question in prose

[HR-4](ROSTER.md#hr-4) admits one shape for a question canon prose leaves open, and only one:

```text
[NEEDS <row-id>: <question>]
```

- **`<row-id>` is an ask-once-per-run row** of `nen/decisions.json` that `contracts/prose.lint.json` → `markerRows` lists; the guard refuses a contract that lists a row of any other class. Every human-gate row is refused: a gate is a stop, not a question.
- **At most three per skill**, each with a ledger reference in its paragraph: an `OPEN-n` row in [`ROSTER.md`](ROSTER.md) or a `zheref/<repo>#N` issue.
- **No default.** No run, agent or surface resolves a marker by a derived answer; the row's own stop applies until the maintainer rules.
- **It closes in one commit**: the ruling lands in ROSTER citing the `OPEN-n` or the issue, and the marker is deleted in that same commit.
- A to-do word or any other bracket is not a marker; `scripts/prose_ambiguity_check.mts` refuses it (`PL-11`).

## Residue and owned dependencies

**A step no nen verb owns is named as residue in the report, never presented as a verb's output**, and
where a verb should own it, it is an **owned dependency** with an issue, never a silent workaround.

**Residue names ownership, never availability** (zheref/hatsu#481). That no verb owns a step is a fact
about the machinery, not proof that the step cannot run: a native capability the owning skill names (a
host's delegation tool, a surface adapter), ordinary judgment and authoring proceed without a verb, and
only an observed absence, an applicable prohibition, an unmet prerequisite, an observed rejection or an
unresolved required human choice stops one. A native capability never supplies a missing human
authorization, and improvised shell never stands in for a Nen-owned safeguard — that stays refused, the
unmet dependency named. The resolution order and the park evidence are WORKFLOW § *Idle batches* rule 3.

**Every Residue item cites its issue as `zheref/<repo>#N`, or the literal `unfiled`** — a bare `#N`, a
deferral to nen with no issue, or a residue with neither is not one (`PL-02` and `PL-05` in
`contracts/prose.lint.json` fail; the lint reports `PL-10` as advisory, and the contract's severity
is the answer). `unfiled` is an admission, never a resting state: the next discovery
pass files it through `hatsu:file` and replaces the word with the reference.

**Named residue, by skill** — the live list; each skill's `Residue` section points here.

- **The canon prose lint (lane `canon-lint`).** `scripts/prose_ambiguity_check.mts` is an interim
  TypeScript verdict, frozen to fixes: its port is owed to `nen canon lint` (zheref/nen#481) and its
  citation resolver to `nen ref resolve --citation` (zheref/nen#482); both retire at that repin. Its
  pull-request check, `canon-lint` from `.github/workflows/prose-ambiguity-check.yml`, is **advisory**:
  it sits in no ruleset and becomes required only after one tagged release of green runs with a
  shrinking baseline (HR-13), by the maintainer's own ruleset edit
  ([`GATE-CONFIGURATION.md`](GATE-CONFIGURATION.md) § *The new-workflow rule*). Advisory for the
  merge, that is: a red run still reads the pull request not-ready, because `nen pr ready`'s `CON-32(a)`
  row counts every reported check ([`GATE-CONFIGURATION.md`](GATE-CONFIGURATION.md) § 2; the clause text
  at the handbook pin says required checks, a gap for a G4 handbook question), so Hatsu's own readiness
  loop stops on it.
- **`ten`.** Copying a mirror (the drift check is nen's), composing `AGENTS.override.md`,
  writing `info/exclude` and proving it took, the first install on Codex and Cursor, resolving the
  plugin root (and ordering the checkout's manifest version against the bound pin's, zheref/hatsu#67), updating the plugin source and binding the pinned `nen` on the host (`scripts/nen_global.sh`: the
  `~/.local/bin/nen` link and the shell rc's PATH block, around nen's own bootstrap) are done by the warm-up's scripts and by hand: no nen
  verb owns a checkout's local exclude, a host's `PATH` or its shell profile, and where Hatsu is checked out is the host's property. The
  login-shell probe (`scripts/nen_reach_probe.sh --root "$hatsu_root"`, which runs `"$SHELL" -lic 'command -v nen && nen shu tools --repo "$1"' nen-probe <root> </dev/null`, zheref/hatsu#218) and the name-correct host link ten § 2c offers as the fallback by its
  offer predicate (stated once there, verbatim in row `host-nen-link`) are the same kind (zheref/hatsu#164): a shell's `PATH` is the maintainer's, and nen binds no name on a host. § 6's reads —
  `gh auth status`/`gh auth token`, `gh pr list --head <branch> --state all`, `git branch --merged origin/<branch.base>` — are hand-spelt too; an unnamed human-call prerequisite at its step 7 stops,
  named, and the maintainer names the skill it is for by typing `then aka+mukai`.
  Cursor's version check is a string compare on a date part; the host-global half of the skill-name
  collision question has no answer from inside a repository. **§ 5's Claude Code `mirrors:` is
  `nen surface status` (the retired `nen surface status`'s job, zheref/hatsu#289 item 6)**, a byte comparison with six exit codes (five verdicts and a wiring stop) that no verb owns: an
  owned dependency, zheref/nen#339 (a plugin-layout mode of `surface mirror check --installed`, or a
  check under zheref/nen#298's status verb); its fixture is the reference behaviour, and it retires
  when the verb lands — and that verb shipped: zheref/nen#339 closed with NN-PR-#378 (nen 0.21's
  `surface mirror check --surface claude-code --plugin <name> --installed <dir>|auto`), so the script
  is **owed a retirement** (a Hatsu issue, filed by the run that reads this; BC-11's shell clause —
  TypeScript is the default for a verdict — is what binds it, unruled). **BC-11 binds the hanten
  ledger — the maintainer's ruling of 2026-10-03** ([`ROSTER.md`](ROSTER.md) HR-243, HR-244): its owned
  dependency, zheref/nen#346, shipped in nen v0.26.0, and the retirement step ran (zheref/hatsu#216):
  hanten and breath call `nen review ledger`, and the script and its fixture are gone.
- **`hanten` § 2a, the Node dependency audit.** `scripts/dependency_audit_resolve.mts` is an interim
  TypeScript verdict (zheref/hatsu#247, item 1): it selects the manager from the tree's `packageManager`
  field, which duplicates nen's own `{pm}` substitution in its `nextjs` pack, then parses the lockfile and
  queries OSV, executing nothing. The parts **owed to nen** (zheref/nen#508): the lockfile parse for pnpm, yarn
  and npm, the OSV `querybatch` post and the per-id severity read, as a declared audit verb or with `{pm}`
  and the lockfile read exposed; it retires at that repin. The `swift` row's OSV route
  (`contracts/scans.json` → `dependencyAudit.swift`) has no owner at all: no nen verb carries out its
  `$comment`, and it is owed to the same verb.
- **`bankai-rule`.** The invocation's `ruling` tail is split off at its first whole-word `ruling` in shell
  before the head goes through `nen parse` (nen anchors a literal on its last occurrence; a first-anchored
  trailing clause is **owed to nen**, zheref/nen#458); the id reservation's open-PR reads (`gh pr list`,
  `gh api --paginate repos/<t>/pulls/<n>/files`, `gh pr diff`, `gh api search/issues` in `scripts/port_rule_reserve.sh`) are
  **owed to nen**, zheref/nen#456; a ports pair file rides `nen canon resolve --always-load` and reaches no
  mirror until zheref/nen#457; the authoring clone is `git clone` at the cache path (`bankai-handbooks` § 0's
  carve-out); the `--dry-run` strip before that split is the same first-anchored clause (zheref/nen#458); the
  product-term guard (`scripts/product_term_check.mts` behind its shim, BC-11) is a three-way verdict **owed to nen**
  beside the private-name one (unfiled).
- **`kazaana`.** The surface → `model/` line is read from `contracts/direct.registry.json` itself: `nen direct registry
  --json` validates the file but prints no `line` (**owed to nen**, to file); raising a delegate has none (third-hand's
  class), and a Claude Code raise carries no effort dial; the overlap read that decides a stack has none
  ([`WORKFLOW.md`](WORKFLOW.md) § *Stacked pull requests*); a closed-unmerged PR is a `gh pr view` state.
  `nen pr merge --release-unit` reads `aiReviewers` from nen `0.26` (NN-PR-#463) and waives a declared bot's
  round. A proposal whose only owed round is Copilot's therefore merges inside § 3a's bounds, under kazaana or not, once
  its base carries the declaration (zheref/hatsu#428; [HR-333](ROSTER.md#hr-333)). Under `required`, or for a round nen does not waive,
  the proposal still fails § 3's second condition and halts (getsuga § 3a). Nothing is owed to nen for it.
- **`cleanup`.** `git worktree remove|prune`, `git branch -d`, `git push origin --delete <branch>`, `git remote
  prune origin`, `rm <reports.dir>/current.html`, `du -sk` and the `readlink` of the host links have no nen verb:
  **owed to nen** as `nen wc prune` (to file); the raise and the `.nen/cleanup/<slug>.json` marker are Hatsu's,
  as third-hand's are. The worktree-path admission is `scripts/cleanup_path_admit.ts`, interim until
  `nen wc prune` owns it.
- **`spiritual-message` and `rikugan` — the Markdown report** (zheref/hatsu#215). Three owed dependencies
  on `zheref/nen`, not yet filed, named for Netero's harvest. **(a) Render-time Markdown escaping** in
  `nen report render`, per output language, so a value is as inert in the Markdown twin as in the HTML; until
  it lands, the newline rule and the named link and image gap (§ *Escaping and validation of report data*).
  **(b) A render to stdout, or to a named path outside `--repo`**, which retires the copy into the artifact
  store (§ *The Markdown report*, step 2). **(c) Template conformance as a verb**:
  `scripts/report_markdown_check.sh` (lane `report-markdown-guard`) is a python3 heredoc that renders every
  declared variant in both formats and holds block order, the desk rules, escaping placement and the checked
  examples. **Ruled 2026-10-13** ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-13*): BC-11 binds it as
  it binds the ledger — frozen to fixes only, its header saying so, the verb filed as zheref/nen#406 and the script retiring when it lands.
- **`spiritual-message`, `rikugan` and `backlog-board` — the report data document** (zheref/hatsu#291;
  § *The report data document*). Two owed dependencies on `zheref/nen`, **not yet filed**, named for
  Netero's harvest. **(a) A verb that derives the extension's defaults** — the table there, the
  `turnLabel` from `turnNumber` and the `repo` fallback included; until it lands each default is the
  caller's, derived by that table and named as residue on the page. zheref/nen#406 and zheref/nen#220 are
  template-conformance verbs and do not own it. **(b) The `--register` pass's own clock**: a desk's
  `generatedAtLocal` is the plain pass's while the register pass stamps a later `generatedAt` (measured
  +152–168 ms at `0.22.0`, minutes with real composition between the passes); nen should localise the
  register pass's own `generatedAt` under `--register`. **The derived context it already owns** came
  through zheref/nen#258 (closed) and zheref/nen#375: `repo` (the hosted `owner/name`), `worktree`,
  `effortStage`, `gate` and `stageClass` from `v0.20.0`, each `null` with its reason on stderr when a fact
  is missing, and `generatedAtLocal`, `generatedDateLocal`, `timeZone` and `turnNumber` at nen
  `0.22.0` (verified 2026-10-19).
- **`futon` § 5.** The local `git merge --no-ff` of a hanten-settled effort branch into the run's
  integration branch, in a worktree on that branch, has no nen verb (`nen wc catch-up` brings a branch
  up to date with its base; it is not a delivery merge). It is named residue, the verb **not yet filed**
  ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-09-30 — En never merges*, row *Futon merges into its own
  integration branch, locally*). The branch is published with `nen wc publish`, never through `aka`.
- **Host workload admission** ([`WORKFLOW.md`](WORKFLOW.md) § *Host workload budget*, zheref/hatsu#478).
  No nen verb holds a host budget at the pin: admission is owed to zheref/nen#536, bounded test workers
  to zheref/nen#537, owned cancellation to zheref/nen#538, the pressure refusal to zheref/nen#539 and
  the receipts to zheref/nen#540. Until adoption every heavy phase reports the missing guard and runs
  the serialized fallback; the process-group listing a stop claim cites is read-only residue (`ps -A
  -o pid,ppid,pgid,command`). On Codex the rule reaches a session through `agents/kurapika.toml` and the
  kazaana, futon and hanten skill mirrors, read whole; `AGENTS.md` sorts the personas by name, which
  puts Kurapika's copy past `project_doc_max_bytes`' 32 KiB, and placing it under the cap is owed to the
  mirror generator, `nen surface mirror` (unfiled).
- **`tenkai` § 6d and `ten` § 6 step 5b.** Writing a declaration value — `scripts/config_values.sh`
  `fill` and `set`, a JSON span scanner that inserts in place — has no nen verb, and the `$<key>`
  option notes rely on nen reading every `$`-prefixed key as metadata, a convention its loaders follow
  (`src/schema/source.ts`) that no published contract states. Both are an **owned dependency** on
  `zheref/nen` (a value-setting verb and a documented metadata-key guarantee), not yet filed — named
  in tenkai's Residue for Netero's harvest.
- **`shibari`.** The evidence mirror's publish step, the base-ref read (`gh pr view --json
  baseRefName`), the last-pushed-commit comparison and Development linking are named raw calls; the
  PR itself is `nen pr open`. Verifying the links is `scripts/pr_development_link_check.sh`, which
  reads the body's *Associated issues* table and `closingIssuesReferences` /
  `closedByPullRequestsReferences` through `gh`: an **owned dependency** on `zheref/nen`, a
  `nen pr ready` row, not yet filed (origin zheref/hatsu#203). Until it lands, shibari and en quote
  the guard's `0` beside the verdict (BC-11 reads the guard's branching shell as a verb's job, a G4
  question until the verb lands).
- **`contracts/pr-composition.json`, its `gateDerive.zheref/nen` row above all** (zheref/hatsu#171, #334;
  [`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-20 — zheref/nen's gate path sets*). Five items are owed,
  and none is filed yet. **(a) A tree-freshness check at repin**: list nen's tree at the pinned tag
  (`gh api repos/zheref/nen/git/trees/<tag>`) and fail when a top-level entry is in neither of the row's
  sets nor its explicit `G2` list. The repin is the pull request that moves `nen/contract.json` →
  `dependency.pinned_ref`, at the declaration gate (`ten` § 1), opened in Hatsu by `getsuga` § 7's
  fan-out from nen's own release; the check is a lane that pull request's iteration checks run, so the
  repin cannot land past it. When it is filed, the `G2` list (`LICENSE`, `.gitignore`) is declared as
  data on the row — a `g2Paths` array beside `policyPaths` and `processPaths` — so the check reads it
  and never parses prose, and whichever check refuses an unread row key by then (the
  `scripts/pr_composition_check.sh` entry below) admits `g2Paths` in that same pull request. Until it
  exists, a top-level entry nen adds later derives `G2` without warning, so
  [`WORKFLOW.md`](WORKFLOW.md) § *Gate derivation* stops and asks on a path outside the sets and that
  list. **(b) A declared home in nen** for every input this file holds, zheref/nen's sets among them,
  read by `nen gate derive`, `nen pr body-check` and `nen changelog fragment-required` themselves; until
  then Hatsu holds another canon repository's sets. **(c) Two `nen gate derive` refusals**: a `--files`
  entry containing whitespace or a newline (nen 0.22.0 takes a newline-joined value as one path, so a set
  handed over from a one-per-line source under-derives `G2`), and an empty changed-file set (it answers
  `G2` across 0 files). **(d) `--range` passing `--no-renames`**, in `gate derive` and
  `changelog fragment-required` alike: nen 0.22.0's `git diff --name-only <range>` drops a rename's old
  side. Until (c) and (d) land, WORKFLOW § *Gate derivation* hands the set over as `--files-from` and
  never uses `--range`. **(e) `changelog fragment-required` honouring `directSection.optOut` only in the
  body's own prose**, never inside an HTML comment or a code fence; a Hatsu-side raw-body check is owed
  beside it.
- **`scripts/pr_composition_check.sh`** (lane `pr-composition-guard`; zheref/hatsu#171) is a python3
  heredoc inside a shell script, so BC-11 reads it as debt: it takes no new branching, and a check it
  lacks is owed to its TypeScript port or to nen's declared home ((b) above), never grown into the
  heredoc. Two are owed there, not yet filed: **refusing a `gateDerive` row key `nen gate derive` never
  reads** (`policyPath` for `policyPaths`, say), withdrawn from the heredoc in hanten round 2 of
  zheref/hatsu#334 (Chrollo, BC-11), and **refusing a duplicate key in the declaration** (Feitan):
  Python's `json` keeps the last of two equal keys silently, where an `object_pairs_hook` would see both.
- **`sharingan`.** A reply's head-chain check (§ *Reviewer rounds and review threads*) is `git -C <path> fetch` then `git -C <path>
  merge-base --is-ancestor <sha> <head>`, because nen reads a PR's head but not the ancestry of a commit in it.
- **`getsuga`.** The release proposal's base read-back after a retarget (`gh pr view <N> --json
  baseRefName`), because nen exposes no read of a PR's base (zheref/hatsu#98); the retarget itself is
  `nen pr retarget`.
- **`kokusen`.** The explicit per-path `git -C <path> add -- <file>` and the drop of a just-written tip on
  `commit write`'s exit `3` (the undo line nen prints, `git -C <path> reset --soft HEAD~1` for a non-root
  commit; row `injected-attribution-trailer`) are the raw calls; the commit is
  `nen commit write --message-file`, gated on `nen commit format`.
- **`bakuryuha`.** The first-party install is `scripts/hatsu_surface_link.sh` and updating the checkout is
  `scripts/hatsu_plugin_update.sh`, as for `ten`; the served-version read-backs (`claude plugin list
  --json`, `codex plugin list`, `agy plugin validate`, a placed marker stamp) and following a skill body
  from the new path until the surface switches are done by hand. No nen verb owns a host's installed
  plugin: an owned dependency, zheref/nen#298 (BC-11 reads the scripts' branching shell as a verb's
  job, a G4 question until the verb lands).
- **`jusshin`.** The elevated launch on Windows has no verb by design: the session runs `nen runner script --json`'s own `launch` line (`Start-Process -Verb RunAs`) through the harness's own permission prompt — no allow row exists, so that prompt is the maintainer's advance consent — and the UAC consent and the typed service-account password are the maintainer's on-device acts, as `sudo bash <script>` on Linux and the Login Items approval on macOS are. Reading the one-line `register-<ts>.summary` newer than the launch is by hand, and the transcript is never read. The script is rendered outside the runner root; locking the root down, keeping the secrets off `config.cmd`'s argv and writing the summary file are nen's, owned in [zheref/nen#312](https://github.com/zheref/nen/issues/312). The shared `_work/_actions` cache across one host's runners, runner removal, organization runner groups and `--ephemeral` supervisors have no verb yet — owed, unfiled — and are named, never improvised.
- **`rikugan`.** Which objects the last completed workflow touched is read from that run's own record
  and the checkout (`gh pr list --head <branch> --state all`, the PR body's closing lines) — no nen verb
  derives a run's scope; `nen report data --base origin/<branch.base> --prs <n,...> --issues <n,...>`
  then fetches them in one call, merged PRs and closed issues included (`--base` is required, exit 2
  without it; verified nen 0.18.1, 2026-09-30).
- **`direct`.** The latest-version and effort-dial reads (direct § 4) are prose by design — the surface CLIs
  (`codex debug models`, `cursor-agent models`, the in-session model picker) and the provider pages the registry
  cites are read by the session and quoted with their date; nen stores no version and the registry's `snapshot`
  is the stated fallback. Reading the session's own surface, model alias and effort for the compare is the
  harness's fact, hand-read per surface and passed as `unread` where it cannot be. Three reads the verb does not
  make yet are the reader's, from the verb's own document and the registry's stated rules (direct §§ 3, 6;
  zheref/nen#389): the **recommended** pick (`picks.recommended`), the **within-set** compare over the
  recommended and the fallback (`mismatch.within`) and the **aggregate fallback** where the verb's runner-up
  shares the primary's pool; companion jobs are kept out of the deciding call rather than struck. Under
  `direct.publish`, the marker read on an issue's comments is `gh api`, read-only, and `nen label` has no
  `--remove`, so an older `model/` label is named, never removed (zheref/nen#389). `nen direct registry|resolve|answer`
  ship in nen `v0.20.0` (zheref/nen#371, carried to `main` by #380), the pin zheref/hatsu#168 moved; on an older
  binary they are absent, § 2's probe says so, and `build` continues unrouted (row `missing-tool`).
- **`classify`.** The judgement — reading an issue's title, body and paths and deciding its `lang/` and
  `job/` keys (classify § 3) — is prose by design: nen owns operations, not reading an issue. The issue read
  is `nen classify status --with-body`'s. Every other step is the `nen classify` family (`labels`, `install`,
  `status`, `apply`), which ships in nen `v0.20.0` (zheref/nen#370, carried to `main` by #380), the pin
  zheref/hatsu#168 moved; on an older binary those verbs are absent, § 2's probe says so, and the skill
  continues where it can (row `missing-tool`: the judgement shown, nothing labelled by hand, ten § 2's install named).
  The GitHub half of a declaration is `nen classify install --sync`, with `nen labels sync` the whole-file form.
  Under `classify.publish`, the marker read is `gh api`, read-only, and the comment is `nen issue comment`'s,
  unledgered (`contracts/classify.taxonomy.json` → `publish.residue`).
- **`file`.** The private-name check before every write to a public repository
  (`scripts/private_name_check.sh`, zheref/hatsu#149) stays the first guard, run before the plan so the plan
  shows checked text: `file`, `backlog-synthesis`, `mugetsu` and `sharingan` pipe each title, body and
  comment through it. It reads `gh api 'user/repos?visibility=private'` live; nothing caches it. From nen
  `v0.20.0` (zheref/nen#367, closing zheref/nen#329) `nen issue file`, `comment` and `edit-body` refuse too, at exit `4`,
  given the script's ignore file (`file` § 4). What nen does not guard yet — `issue consolidate-close`'s
  close comments and the `pr` writers (zheref/nen#363) — is the script's alone. The committed named
  list (`scripts/private_name_named.txt`, the one name ruled public) reaches nen through `file` § 4's
  joined ignore file, because nen takes one; with it the script is BC-11 debt, frozen to fixes only, and
  it retires when a nen private-name verb also checks a tree (zheref/nen#441).
- **`aka`.** The outgoing range's trailer read-back immediately before the push (§ 7 step 0), the same call over `<the SHA ls-remote printed | origin/<base>>..HEAD`, on `--repo <path>`; and the undo of `wc squash`'s exit `3`, `git -C <path> reset --soft ORIG_HEAD` (§ 4).
- **`kagutsuchi` § 3a.** The freshness gate is `scripts/send_freshness_check.sh` — a `git fetch`,
  `rev-parse`, `rev-list` and `status --porcelain` over the archive's recorded build SHA — and the
  default target is a `nen/workflow.json` key nen validates from `v0.21.0` and never acts on (`deploy.defaultTarget`,
  whose target must carry `project.targets.<name>.nonProduction: true`, zheref/nen#300);
  nen's own `shu deploy` still takes `--target` explicitly, and the skill still passes it.
- **`kagutsuchi` § 3b.** `git fetch`, `git worktree list|add --detach|remove --force`, `git checkout
  --detach`, `git ls-files`, `git check-ignore`, `git status --porcelain`, `mktemp`, `cp -p` and `mv -f`
  inside `scripts/kagutsuchi_worktree.sh`, because **nen has no worktree verb** (`nen wc worktrees` reads,
  never writes); core is resolved the way that verb resolves it (`git rev-parse --git-common-dir`) and
  the report quotes the script's own `core:` line beside the verb's.
- **Every worktree Hatsu makes** (rule 6 of `claude/rules/hatsu.md`, `hanten` § 4, the stash-and-restore
  proof, `docs/surfaces/antigravity.md` § 11.1). `git worktree add <core>/.nen/worktrees/<surface>/<name>`,
  `git worktree remove` and `git worktree prune` are hand-spelt wherever Hatsu creates a worktree, for the
  same reason: nen has no worktree verb that writes. The canonical path is `docs/WORKFLOW.md` § *Where
  worktrees live* (the ruling of 2026-09-30), and the lapse would be a `nen wc worktree add|remove
  --surface <s> <name>` that resolves core and the canonical path itself — the same family as the
  owned dependency below.

**Worktree-isolated sessions: one plain command per call.** The writing rule for a skill's shell
block — one plain command or a shipped `scripts/` entry per call, the refused shapes and their
replacements, `GH_TOKEN` and `PATH` without a refused shape, the chained write gates — is
[`WORKFLOW.md`](WORKFLOW.md) § *Writing a skill block* (ruling of 2026-10-13, zheref/hatsu#218), stated
once there; the record of the guard's refusals, verbatim, is [`docs/ab/worktree-isolation.md`](ab/worktree-isolation.md).
A refusal of a block on neither of its lists is a refusal named as WORKFLOW § 4 *What is not a gap* names
one, the block and the guard's sentence quoted; a throwaway helper script is never the workaround.

**The mirror regeneration** `great-hiker` § 4 and `docs/using/mirrors.md` § 3 run after every
source change is `scripts/surface_mirror_regenerate.sh`, one plain call: the three `nen surface mirror
generate` calls at the manifest's stamp, built from `scripts/surface_mirror_check.sh`'s own constants
and hooks-root table, which it sources (one table, never a copy; lane `mirror-regenerate-guard`). It is
run in the Hatsu checkout being authored, never by an installed copy. **Owned dependencies**, filed
at this run's third-hand harvest after En, their numbers added then: a body-file flag on `nen commit
format`; a title-file flag on `nen issue file` (`file` § 4 types the title literally meanwhile);
`nen shu test` over several lanes in one call with one report — **judged needed**, since hanten § 4 runs
every lane a diff selects; and a nen verb that generates every surface a repository declares, which
would retire the regenerator's branching (BC-11).

**Effort checkout selection precedes every authoring and PR phase's standalone catch-up.**
Read `$hatsu_root/docs/WORKFLOW.md` § *Where worktrees live* and its surface adapter; bind the
absolute effort path before preservation or git mutation, then use it as cwd and every `--repo`.
New, resumed and delegated efforts follow that one policy. Native app creation tools, when
exposed, are used as their schemas declare; manual `git worktree add` remains the named residue
when no native tool is available. Neither Nen's inventory nor `wc swap` provisions isolation.

**Owned dependencies.** A gated-publish verb — `scripts/publish_gate.sh`'s six gates as nen's own
(zheref/hatsu#218 (i), the ruling of 2026-10-13; BC-11 as written by the ruling of 2026-10-17, the script frozen
to fixes only pending its port), filed as zheref/nen#407 item 18. A worktree verb that cuts, reuses, moves and drops one detached worktree at a
fixed path, with the core-to-worktree copy ([zheref/nen#299](https://github.com/zheref/nen/issues/299)),
and `deploy.defaultTarget` validated by pointer with a per-stack default in `nen shu detect`'s reference
pack ([zheref/nen#300](https://github.com/zheref/nen/issues/300)) are nen's to add (zheref/hatsu#146);
until then the two scripts above are the mechanism and are named as such. The canon `precedence` key of
[`../nen/contract.json`](../nen/contract.json) ([HR-1](ROSTER.md#hr-1)) is tolerated, not validated, by
`nen schema check` at the pin: validating it and refusing a drifted restatement in `WORKFLOW.md` are owed to
[zheref/nen#474](https://github.com/zheref/nen/issues/474) (BC-11 keeps the drift case out of
`scripts/canon_contracts_check.sh`, frozen to fixes only); until that repin nothing checks the order.

**RETIRED at nen `0.19`:** `nen commit write` and `nen wc squash` read back the trailers of the commit they wrote, and exit `3` with `injected[]` ([zheref/nen#273](https://github.com/zheref/nen/issues/273), closed by zheref/nen#357). kokusen § 5 and aka § 4 map that exit. aka § 7's step-0 read of the whole outgoing range stays, because a clean catch-up merge is written by `nen wc catch-up`, which reads no trailers back (zheref/nen#357 covers `commit write` and `wc squash` only).

## History

Retired mechanics the skills used to carry, kept so a reader of an old transcript can place them.
None of it is a rule.

- **nen `0.13`** — `nen pr open` began opening the PR (shibari), `nen commit write --message-file`
  began writing the commit (kokusen), and § 0's stash-and-restore became `nen shu warmup --carry`
  (breath). The raw calls still named are § *Residue and owned dependencies*'s, not this list's.
- **nen `0.11.0`** — the stop marker is nen's file (jutaisho): `.nen/last-stop.json` is written by
  `nen stop --mark` as `nen.stop.mark/v0.2`; the hand-written `hatsu.stop-marker/v0.1` shape is still
  **read** by the hook and **never written again**.
- **The retired CI plane** (futon, backlog-loop). The retired skills routed issues to a CI lane agent
  through a routing table of CI lane labels, with Route and Wake rows, and spent their bulk on an App,
  a workflow and a bot identity. Hatsu carries no CI plane: those labels now pick Kurapika's mode
  ([`build`](../claude/skills/build/SKILL.md) § 3), futon carries no Route or Wake row, and
  backlog-loop keeps only concurrency arbitration, ordering and the batch-boundary layer.
  **`CON-46(c-i)`**, the stale-chore-merge carve-out, is never exercised and is not restated as a
  permission.
- **`nen loop slots --local-cap`** lost its inherited default so the concurrency guard is chosen,
  never assumed; omitting it is exit `2` (futon, backlog-loop). `<repo>` in backlog-loop is a
  single-slot grammar, so the parser's bracket-swallowing defect cannot reach it.
- **No by-hand HTML step remains** (backlog-board, spiritual-message): every report page is
  `nen report render` over a fixed template.
- **Recorded elsewhere, dropped from the skills**: breath's stash-and-restore note
  ([`WORKFLOW.md`](WORKFLOW.md) § *The standalone stash-and-restore shape*) and sharingan's GraphQL
  residue note (`CHANGELOG.md`).
