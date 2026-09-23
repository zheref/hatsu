# The shared phase conventions

**The general process specification every Hatsu skill inherits.** A skill's own `SKILL.md` carries
what is specific to it — its purpose, its steps, its verbs and their skill-specific exit reactions, its
parameters and its own hard limits. What every phase shares lives here, once, and a skill points at the
section by name (`PROCESS.md § <Section>`). **Everything here is binding exactly as if it were written
in each skill that points at it**; moving a rule here moved where it is written, never whether it holds.

It sits beside [`WORKFLOW.md`](WORKFLOW.md) (the configuration keys, the phases, the gates and the
decision matrix), [`STANDALONE-ENTRY.md`](STANDALONE-ENTRY.md) (a phase called cold) and
[`DISCOVERY.md`](DISCOVERY.md) (gaps found during authorized work). Where this page and one of those
disagree, that file wins and this page is the bug. *Assembled 2026-09-22 from the passages the skill
diet moved out of the capped skills, so each skill keeps headroom for its own rules.*

## Standalone entry

**Shared policy (`docs/*.md`) lives at the Hatsu plugin root that `hatsu-warmup` prints**, and every
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
covers — is asked for and set up inline ([`WORKFLOW.md`](WORKFLOW.md) § 4 *Ask, set up, continue*,
rows `missing-argument` and `missing-configuration`); the maintainer's own word (a target, a go, a
cap, a device) is asked and **never derived**.

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

**A refusal that is a gap is a question; a refusal that is a safety rule stays a refusal.** Human
gates, secrets and signing material, on-device acts, a supply-chain failure, a mutating command inside
a read-only loop, and a precondition such as a go with no tag are refusals by design — they are named,
never softened into a default.

## Reporting a phase

**A report rendered because the maintainer asked for it, or at a phase's reporting step, is not a gate
event.** It carries **no `nen stop` banner, no efforts table and no push notification** — the
maintainer is already looking at it, on every repeat of a repeating render. **A real gate coming due
while the page is read fires normally**: rendering never suppresses a stop, and a page that makes the
next act obvious is still not a reason to take it. The bell is
[`jutaisho`](../claude/skills/jutaisho/SKILL.md)'s alone — and **a page carrying a `DECIDE` ask makes
the bell `jutaisho at <ask.gate>`**, so the decision reaches the picker in the same turn
([`WORKFLOW.md`](WORKFLOW.md) § 4).

**A progress turn carries no banner**: a compact status line naming the object, its state and what is
next, and the run keeps going. **Every gate stop is [`jutaisho`](../claude/skills/jutaisho/SKILL.md)
§ 4's full protocol**, all four parts, through `nen stop --who <persona> --gate <Gn> [--notified]
efforts.md`: the banner pasted verbatim, the report link, lettered Crazy Slots options with ⭐ on the
recommendation, and the question through the surface's own picker. A stop that is not a gate is a
**G5** with a `DECIDE` or `DO` ask. **A phase that acts re-renders the turn report before it stops** —
[`spiritual-message`](../claude/skills/spiritual-message/SKILL.md)'s `turn` variant, the act recorded
in *Accomplished*.

**Say one line in chat and stop** — what was rendered, for what scope, and the link or path — never a
prose summary of the page. **A block that cannot be filled** renders without those rows, shows its
empty-state line and names the gap in *Not delivered*; no page at all is said so. **A markdown recap is
never the fallback** for a page that failed, unless the skill names a declared fallback and says it is
using it.

**Objects are named in `<CODE>-<IS|PR>-#<N>` notation from `nen ref format`, never from memory** — in
a status board, a register row, a ledger line and a final report alike.

## Publishing a report

**On Claude Code a report is an Artifact, republished to ONE URL per key** — the skill names the key
(the branch for a turn or landing page, the repository for a gate register); a new URL only for a key
that has none yet, and a better title never mints a new one. **Read before you overwrite**: a republish
notice, or a listing showing a version this session did not publish, means the page moved — re-read it
and re-resolve the data rather than repainting what this session happens to be holding. **Elsewhere**
the page is `<reports.dir>/current.html`, overwritten every render, git-ignored, **transient**. **Say
which happened.**

**Every object notation on a page is `nen ref format`'s output.** Where it cannot be resolved — no
`nen/repos.json` — the page falls back to `<owner>/<name>#<n>` and the failed resolution goes into
`footerNote`.

## Escaping and validation of report data

These bind every document handed to `nen report render`, for both `templates/spiritual-message.html`
and `templates/rikugan.html`.

**Every key is always present, empty where there is nothing, and every row key is spelled**, because
the template iterates them. A missing token is exit `2` **by design**: a blank cell in a published
report reads as a fact. A list is `[]`, never absent.

**Escaping binds both paths**: every value is repository-controlled, so every value is escaped. The raw
form (`{{{token}}}`) is admitted for **one** slot only — the graph document's script tag
(`graphJson`), safe as a renderer property because `serialiseGraph` escapes `<`, `>` and U+2028/9, so
`</script>` cannot occur. The page draws the graph with dagre (cdnjs, integrity-pinned) and keeps the
node and edge list under `<details>` as the text fallback. **Never hand-build SVG or a second
renderer.**

**Three validations escaping cannot do are the caller's**, run before the document is handed to the
verb:

- a capture source against `^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$`;
- a bar percentage against `^(100|[0-9]{1,2})(\.[0-9]+)?$`;
- **every `url` field** against `^(https?://|mailto:|#|/)` — escaping makes a `javascript:` href
  harmless as text, not as a link.

**A failing value is dropped and named in *Not delivered***, never rendered.

**Options on a desk ask**: `star` is `"recommended"` on exactly one option and `""` on the rest — the
page draws an inline SVG star, so the value is a label, never the glyph; `starredClass` is `"starred"`
on that option and `""` elsewhere. A maintainer's-word ask stars none.

## Authority every phase shares

**Shared policy is resolved at the Hatsu plugin root, never read from the consumer's working
directory**, as [`hatsu-warmup`](../claude/skills/hatsu-warmup/SKILL.md) § 0 says. **A path into the
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
and says so.

## Residue and owned dependencies

**A step no nen verb owns is named as residue in the report, never presented as a verb's output**, and
where a verb should own it, it is an **owned dependency** with an issue, never a silent workaround.

**Warm-up residue.** Copying a mirror (the drift check is nen's), composing `AGENTS.override.md`,
writing `info/exclude` and proving it took, the first install on Codex and Cursor, resolving the plugin
root and updating the plugin source are done by the warm-up's scripts and by hand: no nen verb owns a
checkout's local exclude, and where Hatsu is checked out is the host's property. Cursor's version check
is a string compare on a date part; the host-global half of the skill-name collision question has no
answer from inside a repository.

## History

Retired mechanics the skills used to carry, kept so a reader of an old transcript can place them.
None of it is a rule.

- **nen `0.13`** — `nen pr open` opens the PR (shibari); the evidence mirror's publish step, the
  base-ref read, the last-pushed-commit comparison and Development linking remain named raw calls. The
  commit itself is `nen commit write --message-file`, still gated on `nen commit format`, the explicit
  per-path `git add` the one raw call left (kokusen). § 0's stash-and-restore is `nen shu warmup
  --carry` (breath).
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
