# The shared phase conventions

**The general process specification every Hatsu skill inherits.** A skill's own `SKILL.md` carries
what is specific to it — its purpose, its steps, its verbs and their skill-specific exit reactions, its
parameters and its own hard limits. What every phase shares lives here, once, and a skill points at the
section by name (`PROCESS.md § <Section>`). **Everything here is binding exactly as if it were written
in each skill that points at it**; moving a rule here moved where it is written, never whether it holds.

It sits beside [`WORKFLOW.md`](WORKFLOW.md) (the configuration keys, the phases, the gates and the
decision matrix), [`STANDALONE-ENTRY.md`](STANDALONE-ENTRY.md) (a phase called cold),
[`DISCOVERY.md`](DISCOVERY.md) (gaps found during authorized work) and [`SURFACES.md`](SURFACES.md)
(the surfaces). **Precedence, one order, stated identically in [`WORKFLOW.md`](WORKFLOW.md):** a
skill's own hard limit **>** `WORKFLOW.md` **>** this page. This page is **binding wherever the skill
is silent**; where it and `WORKFLOW.md` disagree, `WORKFLOW.md` wins and this page is the bug.
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

**A refusal that is a gap is a question; a refusal that is a safety rule stays a refusal.** The list
of what is not a gap is authored once, in [`WORKFLOW.md`](WORKFLOW.md) § 4 *What is not a gap*; each
is named, never asked about and never softened into a default.

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
failing check is one the maintainer ruled out (`--exclude-check` is how that ruling reaches the verdict,
not a paraphrase). A requested reviewer round not yet posted at the current head is `not-ready` too
(`nen pr ready` row 4; [`sharingan`](../claude/skills/sharingan/SKILL.md) § 5). Under `getsuga` § 3 the
release proposal's verdict returns to getsuga and § 3a merges: en rings no bell for it.

## Publishing a report

**On an artifact-capable surface, a report is an Artifact:**
- **On Claude Code**, republished to ONE URL per key — the skill names the key (the branch for a turn or landing page, the repository for a gate register); a new URL only for a key that has none yet, and a better title never mints a new one. **Read before you overwrite**: a republish notice, or a listing showing a version this session did not publish, means the page moved — re-read it and re-resolve the data rather than repainting what this session happens to be holding.
- **On Antigravity**, published as a native Markdown artifact into `<appDataDir>/brain/<conversation-id>/<report-name>.md` (e.g. `spiritual-message.md` for turn/landing reports, `backlog-board.md` for gate registers, `black-voice.md` for validation) via `write_to_file` with `ArtifactMetadata` (`{ Summary: "<Variant> report for <effort>", UserFacing: true, RequestFeedback: false }`), formatted with GFM tables, alert callouts (`> [!NOTE]`, `> [!IMPORTANT]`), and Mermaid diagrams (`graphMermaid`), updated on each turn.
- **Elsewhere** (surfaces without native artifact capability, e.g. Cursor, Codex), the page is `<reports.dir>/current.html`, overwritten every render, git-ignored, **transient**. **Say which happened.**

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

```bash
nen pr threads list    --target <owner/name> --pr <n>
nen pr threads reply   --target <owner/name> --pr <n> --thread <id> --body-file <abs path>
nen pr threads resolve --target <owner/name> --pr <n> --thread <id>
```

**Requesting a round.** `export GH_TOKEN=$(gh auth token)` first — the **maintainer's** user token; a
bot token silently no-ops. Humans go through `--add-reviewers <a,b>`. **Copilot is a `Bot`**, which
`gh pr edit --add-reviewer` and `…/requested_reviewers` never resolve, so it goes through
`--add-bots <node id>`, the id **data** read off the target's own reviewer set (`BOT_kgDOCnlnWA` in
`zheref/hatsu`); `--add-bots copilot` cannot resolve it today (zheref/nen#160). A bare login that is
neither collaborator nor bot is exit `2` pointing at `--add-bots`; both flags absent, exit `1`. The
same mutation answers `NOT_FOUND` under one token and succeeds under another, so **report success
from the mutation's own response, never from the ids sent**, and check first whether Copilot already
reviews the repository automatically. **The verb is the only route** — never a raw GraphQL
`requestReviews(botIds:…)`, never `gh api` (zheref/hatsu#102): a request outside the verb is one no
ceiling can count.

```bash
nen pr request-reviews --target <owner/name> --pr <n> [--add-reviewers <a,b>] [--add-bots <id,...>]
```

**Verify with `nen pr ready`, never REST** (REST shows a pending bot as `[]`): *no round at head* is
one owed; *review requested, not yet posted* is one in flight — wait.

**The fallback chain** (ruling 2026-09-29, `docs/ROSTER.md` § *Rulings of 2026-09-29* — **stated once,
here**; `sharingan` § 6, `en` § 5/§ 6, `pr-state` § 2, `nen/decisions.json` row `reviewer-exhausted` and
`docs/GATE-CONFIGURATION.md` § 3 cite this paragraph and restate nothing). A request the mutation accepts
with no pending reviewer coming back — `(none reported back)`, no `review_requested` event — is not a
request; it is the signal to read `nen/gates.json` → `reviewer_fallback`. **An exhaustion is declared,
dated, never guessed**: a **live** `exhausted[]` row (not past its `until` date, a condition row not
unconfirmed past 90 days from `ruled`, well-formed — `tenkai diagnose` row `gates/reviewer-fallback` names
the rest as drift and a lapsed row is not honoured) naming the configured reviewer moves the request to
the next identity in `chain` that `reviewers[]` carries, through the verb; **a step `reviewers[]` does not
carry is passed over, not asked about** (declaring it is `missing-configuration` only when the maintainer
chooses to — Cursor Bugbot, `cursor[bot]`, is installed and reviews on its own, HA-PR-#127 at
`0e080a49` unrequested on 2026-09-29; declared in `reviewers[]` its round becomes **required on every
PR** until nen reads the chain, so the declaration is the maintainer's call, never the run's); **a fallback request
is a round and counts toward `round_policy.maxRounds` as any other**. With the chain exhausted, `terminal:
hanten` — **hanten's rounds are the review**: no round is requested, no bound is touched, this terminus
outranks `cap-reached`, and the PR is merged by `en` § 5 (§ 6 there, the sixth stop) with **the verb's
verdict quoted verbatim** — today `not-ready: a configured reviewer's round is
still owed at the current head (CON-32b): copilot (no round at head)` — **and one Hatsu line beside it,
never in its place**: `Hatsu: reviewer copilot declared exhausted (nen/gates.json reviewer_fallback, ruled
2026-09-29); nen does not read this — zheref/nen#275`. The same line goes into the PR body's completion
checklist through `nen pr edit-body`, written by `en` before the merge — the one durable record that a
hanten-only review happened. **The merge is the run's**: the ruling's *and merge* means `en` § 5 merges
it (ruling 2026-09-29 (3): *"The merge is not mine. It is yours and it has been."*). No Hatsu-side
narrowing can make the verb read past an exhausted reviewer — `--reviewers ""` is ignored where the
target ships `nen/gates.json`, and a derived gates file with `reviewers: []` is refused by name
(measured at nen 0.15.1, `docs/ab/sharingan.md` § *Dated 2026-09-29 — the reviewer fallback chain*) — so
the read in `pr ready` is nen's to add (zheref/nen#275).

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

**Named residue, by skill** — the live list; each skill's `Residue` section points here.

- **`ten`.** Copying a mirror (the drift check is nen's), composing `AGENTS.override.md`,
  writing `info/exclude` and proving it took, the first install on Codex and Cursor, resolving the
  plugin root (and ordering the checkout's manifest version against the bound pin's, zheref/hatsu#67) and updating the plugin source are done by the warm-up's scripts and by hand: no nen
  verb owns a checkout's local exclude, and where Hatsu is checked out is the host's property. The
  login-shell probe (`"${SHELL:?}" -lic 'command -v nen && nen shu tools --repo "$1"' nen-probe "$hatsu_root" </dev/null`) and the name-correct host link ten § 2c offers on its
  verdict are the same kind (zheref/hatsu#164): a shell's `PATH` is the maintainer's, and nen binds no name on a host.
  Cursor's version check is a string compare on a date part; the host-global half of the skill-name
  collision question has no answer from inside a repository.
- **`shibari`.** The evidence mirror's publish step, the base-ref read (`gh pr view --json
  baseRefName`), the last-pushed-commit comparison and Development linking are named raw calls; the
  PR itself is `nen pr open`.
- **`getsuga`.** The release proposal's base read-back after a retarget (`gh pr view <N> --json
  baseRefName`), because nen exposes no read of a PR's base (zheref/hatsu#98); the retarget itself is
  `nen pr retarget`.
- **`kokusen`.** The explicit per-path `git add`, the tip read-back (`git -C <path> log -1
  --format='%(trailers:only,unfold)'`) and the drop of a just-written tip on an injected attribution key
  (`git -C <path> reset --soft HEAD~1`, row `injected-attribution-trailer`) are the raw calls; the commit is
  `nen commit write --message-file`, gated on `nen commit format`.
- **`bakuryuha`.** The first-party install is `scripts/hatsu_surface_link.sh` and updating the checkout is
  `scripts/hatsu_plugin_update.sh`, as for `ten`; the served-version read-backs (`claude plugin list
  --json`, `codex plugin list`, `agy plugin validate`, a placed marker stamp) and following a skill body
  from the new path until the surface switches are done by hand. No nen verb owns a host's installed
  plugin: an owned dependency, zheref/nen#298 (BC-11 reads the scripts' branching shell as a verb's
  job, a G4 question until the verb lands).
- **`jusshin`.** The elevated launch on Windows has no verb by design: the session runs `nen runner script --json`'s own `launch` line (`Start-Process -Verb RunAs`) through the harness's own permission prompt — no allow row exists, so that prompt is the maintainer's advance consent — and the UAC consent and the typed service-account password are the maintainer's on-device acts, as `sudo bash <script>` on Linux and the Login Items approval on macOS are. Reading the one-line `register-<ts>.summary` newer than the launch is by hand, and the transcript is never read. The script is rendered outside the runner root; locking the root down, keeping the secrets off `config.cmd`'s argv and writing the summary file are nen's, owned in [zheref/nen#312](https://github.com/zheref/nen/issues/312). The shared `_work/_actions` cache across one host's runners, runner removal, organization runner groups and `--ephemeral` supervisors have no verb yet — owed, unfiled — and are named, never improvised.
- **`aka`.** The outgoing range's trailer read-back immediately before the push (§ 7 step 0), the same call over `<the SHA ls-remote printed | origin/<base>>..HEAD`, on `--repo <path>`.
- **`kagutsuchi` § 3a.** The freshness gate is `scripts/send_freshness_check.sh` — a `git fetch`,
  `rev-parse`, `rev-list` and `status --porcelain` over the archive's recorded build SHA — and the
  default target is a `nen/workflow.json` key nen neither validates nor reads (`deploy.defaultTarget`);
  nen's own `shu deploy` still takes `--target` explicitly, and the skill still passes it.
- **`kagutsuchi` § 3b.** `git fetch`, `git worktree list|add --detach|remove --force`, `git checkout
  --detach`, `git ls-files`, `git check-ignore`, `git status --porcelain`, `mktemp`, `cp -p` and `mv -f`
  inside `scripts/kagutsuchi_worktree.sh`, because **nen has no worktree verb** (`nen wc worktrees` reads,
  never writes); core is resolved the way that verb resolves it (`git rev-parse --git-common-dir`) and
  the report quotes the script's own `core:` line beside the verb's.

**Owned dependencies.** A worktree verb that cuts, reuses, moves and drops one detached worktree at a
fixed path, with the core-to-worktree copy ([zheref/nen#299](https://github.com/zheref/nen/issues/299)),
and `deploy.defaultTarget` validated by pointer with a per-stack default in `nen shu detect`'s reference
pack ([zheref/nen#300](https://github.com/zheref/nen/issues/300)) are nen's to add (zheref/hatsu#146);
until then the two scripts above are the mechanism and are named as such.

**Owned dependencies.** `nen commit write` / `nen wc squash` should read back the trailers of the commit they wrote and report an injected key ([zheref/nen#273](https://github.com/zheref/nen/issues/273)); until then the read-back above is prose.

- **`nen report data` derives less than a page needs**
  ([zheref/nen#258](https://github.com/zheref/nen/issues/258)). It does not derive `effortStage`,
  `gate`, `turnLabel`, `worktree` or `generatedAtLocal`, so the caller fills them (the last through
  `scripts/report_time.sh`); and it stamps `repo` from the **worktree directory's** name rather than
  the project's, so the caller overwrites `repo` with the project name
  ([`WORKFLOW.md`](WORKFLOW.md) § `reports`, *Where the effort is*). Each filled value is named as
  residue on the page until the verb derives it.

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
