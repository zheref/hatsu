# Changelog

## v0.43.0 — surfaces, spend and speed (zheref/hatsu#93)

Release unit for `v0.42.0..v0.43.0`: [#94](https://github.com/zheref/hatsu/pull/94) (the delivery).

> Pinned to nen **v0.13.0** (`minimum` `0.13`, zheref/nen#227): the `antigravity` and `claude-code` surface rows with `--models`, `--permissions`, `--hooks`, `--rules` and `--stamp`, `nen surface mirror check --installed`, `nen usage record`, `nen shu` step durations under the open phase, `phases[]` and `usage[]` in `nen report data`, the two-gate stall rule, `nen wc catch-up`, `nen wc publish`, `nen commit write`, `nen pr open`, and the `profile` key. **The warm-up reads `WRONG` until v0.13.0 is tagged and its release assets are published.**

- **One generator.** `scripts/antigravity_mirror_sync.sh` is retired; `scripts/surface_mirror_check.sh` runs one `nen surface mirror check` per surface (codex, cursor, antigravity) with the shared flags and the plugin version stamped into every marker, and takes `--installed <path>` for a host's plugin cache. The Antigravity mirror is flat like the other two, with `agents/`, `rules/hatsu.md` (from `claude/rules/hatsu.md`, under the 12,000-character limit), `hooks.json` and `plugin.json`; the nested `skills/` copy is gone. `.github/workflows/surface-mirror-regenerate.yml` opens a PR on drift; `surface-mirror-check` is to be required on `main` (the ruleset act is the maintainer's).
- **`docs/surfaces/`.** A shared skeleton and one evolution guide per surface with a dated checklist (fetched 2026-09-20) quoting the official line per row; `docs/ab/surfaces.md` moved to `docs/surfaces/evidence/surfaces.md`; `docs/SURFACES.md` is a short hub. Corrected: Codex and Cursor do have hooks (`.codex/hooks.json`, `.cursor/hooks.json`); Antigravity's workspace paths are `.agents/…` and its global plugin path `~/.gemini/config/plugins/<name>`; the skill counts read forty-three plus `hatsu-warmup`.
- **Great Hiker** (`hatsu:great-hiker`): authors canon prose and machinery and propagates it to every surface; prose as a Fable subsession at low, medium or high effort by skills touched, machinery on the fast tier; the evolution duty diffs each guide against its cited docs and files one Netero-shaped issue per surface.
- **Tiers and roles.** `models.roles.watcher` and `formatter` on `economy`; Illumi runs as watcher (`haiku`), Netero on the fast tier (`sonnet`, medium effort); the Codex `[agents]` fragment and Cursor `model: inherit` come from the generator rows.
- **Run profiles.** `profile` (`fast`, `standard`, `thorough`; default `standard`) in `nen/workflow.json`; `ren` § 2a reads it, wraps every step in `nen phase begin|end`, records usage at the report step, and under `fast` publishes `turn-fast` and defers build, launch, the full page and coverage to `mukai`; a landing always runs thorough.
- **`en`** runs `nen wake verify` on every observation and before any re-request, and states the no-op sync guard once.
- **The spend block** in both templates: phase durations as bars with their `nen shu` steps, tokens by surface and model, Actions minutes, `not reported` per surface; `spiritual-message` and `backlog-board` build it from `phases[]` and `usage[]` and record usage through `nen usage record` before rendering.
- **CI hardening, landing in two steps (zheref/hatsu#94).** `timeout-minutes` on every job and `concurrency` with cancel-in-progress on the three PR guards land live this release. `ready_for_review` and a draft skip on the guards do **not** land live yet: `scripts/workflow_runner_policy_check.rb` now *accepts* both the old trigger/guard shape and the hardened one (main's own trusted copy of the validator still judges every PR by the old shape, so the live workflow and the validator that accepts its successor cannot change in the same PR — see `docs/GATE-CONFIGURATION.md`'s dated note), and a **follow-up PR** flips the three live `.github/workflows/*.yml` files to the hardened shape once this validator is itself the one `main` trusts. `templates/pr-readiness.yml` (the consumer scaffold, which carries no trusted-validator step of its own) ships the hardened shape today — timeouts, concurrency, `ready_for_review`, the draft skip, deliberately no `paths` filter, since a readiness verdict reads the whole PR state and the check is required. The mirror check's `paths` filter was dropped for the same reason: a required context must always report. The auto-regenerator that closes the mirror-drift loop ships as [`templates/surface-mirror-regenerate.yml`](templates/surface-mirror-regenerate.yml) — not yet installed under `.github/workflows/` — until that same follow-up PR installs it live. `scripts/plugin_bump_check.sh` refuses a non-increasing version (a downgrade or an equal version, the way v0.40.0 went untagged), with fixture cases.
- **No hand-rolled git.** breath, ao, kokusen, shibari, aka, mukai, murasaki and izanami use `nen shu warmup --carry`, `nen wc catch-up`, `nen commit write`, `nen wc squash`, `nen wc publish` and `nen pr open`; pr-state and tensho read the warm-up's resolved plugin root instead of the awk manifest reader.
- **Warm-up.** `nen surface mirror check --installed` runs first and the mirrors are copied only on drift (also the answer to #90's post-cut host re-pin); `tenkai` places the surface packs through the generator.
- **A third harness hook.** `SessionStart` → `hooks/session-start.sh`: a warm-up reminder on Claude Code, a mirror refresh on a mirrored surface (Codex `SessionStart`, Cursor `sessionStart`, Antigravity `PreInvocation`), fail-open; the hook manifests on every surface now come from `hooks/hooks.json` through the generator, and the Codex one uses the documented `{"hooks": {...}}` wrapper.
- Counts: forty-three skills plus `hatsu-warmup`, ten independents beside Kurapika plus the reviewer preamble; the plugin manifest at 0.43.0.

## v0.42.0 — the reports and the reviewers carry their weight (zheref/hatsu#89)

Release unit for `v0.41.0..v0.42.0`: [#91](https://github.com/zheref/hatsu/pull/91) (the delivery) and the reconciling [#92](https://github.com/zheref/hatsu/pull/92).

> Pinned to nen **v0.12.0** (`minimum` `0.12`): `objects[]` in `nen report data`, `nen review scopes`, `nen pr threads list|reply|resolve`, `nen report render --variant --graph` and `nen report mermaid` arrive with that release (zheref/nen#220, PRs #221 and #222). **The warm-up reads `WRONG` until v0.12.0 is tagged and its release assets are published**, and re-pins through the bootstrap once it is — the same sequencing as v0.41.0.

- **Names swapped (maintainer's ruling, 2026-09-20).** The per-turn and landing report and its skill, named `rikugan` through v0.41.0, are **Spiritual Message** (`hatsu:spiritual-message`, `templates/spiritual-message.html`); the desk-and-register page introduced this release is **Rikugan** (`templates/rikugan.html`, the `register` and `final` variants). Older sections and docs/history keep the names they were written under.
- **Two templates on one token sheet.** [`templates/spiritual-message.html`](templates/spiritual-message.html) is rebuilt in the Ichigo board's language (ground, surface, ink, indigo, shu for needs-you only, ok, warn; IBM Plex Sans and Mono with Newsreader headings and system fallbacks; a light / system / dark switch persisted per viewer): masthead and tally, then **the desk** — the one ask, its kind (`DECIDE` / `DO` / `MERGE`), the Crazy Slots lettered options with one star, the object links and the readiness verdict **quoted verbatim, above the fold** — then this last turn, landed / fought back / not delivered, the **architecture delta drawn client-side** from a nodes-and-edges document (dagre 0.8.5 pinned from cdnjs with its SRI hash, one inline renderer shared by both templates, nodes coloured by change kind, removed items struck, the block list under `<details>` as the fallback when the script cannot load), evidence with phase durations as bars and usage or *not reported*, the launch line, the decisions ledger and the PR body. [`templates/rikugan.html`](templates/rikugan.html) is new — Hatsu's counterpart of the Ichigo gate register: masthead and tally, **your desk** grouped by gate and ranked by unblocking power with cleared gates shown cleared, **the register** with one collapsible row per issue and pull request (object notation, state marks, gate, the CON-32 verdict or the `readiness` check, needs, driving session and lane, thought flow), spend, legend. Every block wraps in a presence flag.
- **Which blocks render is configuration.** `nen/workflow.json` → `reports.sections` declares five variants — `turn`, `turn-fast` (the per-turn publish under the fast profile: desk and last turn only), `landing` (Spiritual Message), `final` and `register` (Rikugan) — validated by `nen schema check` and injected by `nen report render --variant`. The graph document is the model's, validated by `--graph`, and the same document yields the PR body's mermaid through `nen report mermaid`. `spiritual-message` keeps the turn and landing variants; **the dated final report is a one-effort Rikugan with a cleared desk**, and `backlog-board`, `futon` and `backlog-loop` render the `register` variant through the same verb — no more hand-authored board HTML. `objects[]` (from `nen report data --target … --backlog|--prs`) is the register's data.
- **Nobunaga activates — the default reviewer everywhere.** [`claude/agents/nobunaga.md`](claude/agents/nobunaga.md), Sasuke's local counterpart, for code practices, scope completeness and adversarial reading: acceptance criteria met against the issue, tests present for changed behaviour, error handling and exit-code discipline, shell quoting and portability, docs and counts current, mirrored copies regenerated, nothing improvised that a Nen verb owns, one holistic pass on a delivery PR, live re-verification before a `high`. **Two reviews per session and repository; deep tier in a process repository, fast in a product one** (`nen repo classify`'s `kind`). Recorded in `docs/ROSTER.md` § *Rulings of 2026-09-19 — Nobunaga, Shalnark, the review preamble*.
- **Hanten classifies through `nen review scopes`.** `nen/workflow.json` → `review.scopes` is the path-to-scope map (code → Nobunaga on every path, security → Feitan, architecture → Chrollo, ui → Hisoka, performance → Uvogin, release → Phinks, each with its tier and budget); the hand table in hanten is retired. A spent reviewer meeting a new head gets one **bounded delta pass**. **Feitan gains deterministic scan rows** before he reads: checksum-verified gitleaks that fails loud, the per-stack dependency audit, `nen stage triage` secret shapes, and a builder-touching-workflow gate in a consumer repository — **and the tools are DATA**, in the new [`contracts/scans.json`](contracts/scans.json) (`hatsu.scans/v0.1`): the pinned gitleaks release with its `checksums.txt` and per-host asset names, the OSV `querybatch` endpoint at ecosystem `SwiftURL` for SwiftPM, `npm audit --audit-level=high`, `dependencyCheckAnalyze`. *The pinned release* was never a pin; this file is.
- **One reviewer preamble, every reviewer under 6 KB.** [`claude/agents/_review-preamble.md`](claude/agents/_review-preamble.md) carries the protocol once — `nen repo classify` first, the handbook set through `hatsu:bankai-handbooks`, the fixed finding shape, the refusals, the budget and delta rule — and Chrollo, Feitan, Hisoka, Phinks, Uvogin, Gon, Illumi and Netero carry only their checklist and closing line (from 16–23 KB each). The mirror generator treats the preamble as a persona; it carries a frontmatter saying it is not one until zheref/nen#223 lands.
- **Shalnark activates from the bench, behind `hatsu:black-voice`.** [`claude/agents/shalnark.md`](claude/agents/shalnark.md) is the optional post-merge UI validation automator: ephemeral automated UI tests against the delivered feature's acceptance criteria (persistent only when the repository declares it), pass / fail / not-testable with evidence, files findings and fixes nothing. Reachable **only** through the new skill [`black-voice`](claude/skills/black-voice/SKILL.md) — `hatsu:black-voice [<CODE>#<PR>]`, defaulting to the latest merged PR in the session — never automatic, never from a composite. The bench is four: Machi, Kortopi, Pakunoda, Shizuku.
- **The Copilot policy, written once.** In `sharingan` § *Reviewer rounds*, carried by `en`, `senkei` and `build`: one Copilot round after hanten settles, never before; arrivals remediated up to `nen/gates.json` → `round_policy.maxRounds`; an owed round inside the max re-requested on the maintainer's behalf without asking (`cap-reached`); **never re-request after a push that changed nothing reviewable** (count commits ahead and the diff since the last reviewed head first). Thread hygiene runs through `nen pr threads list|reply|resolve`, and **the Copilot request is the verb too** — `nen pr request-reviews --target <owner/name> --pr <n> --add-bots BOT_kgDOCnlnWA`, the node id passing straight through (verified at `v0.12.0`, exit `0`, `BOT_kgDOCnlnWA -> bot [add-bots]`). **No GraphQL residue is left**: zheref/nen#160 is about resolving the bot by *login*, not by id.
- **The diet.** The ten largest skills — `hatsu-warmup`, `sharingan`, `breath`, `shibari`, `jutaisho`, `build`, `kokusen`, `kagutsuchi`, `amaterasu`, `jujutsu` — are under **12 KB** each (from 36–91 KB), as are `spiritual-message`, `hanten`, `backlog-board`, `futon` and `backlog-loop`; the plugin description is two sentences. A rule survived as one sentence; shared protocol moved to the document that owns it (`docs/WORKFLOW.md` gains the gate derivation, the UZF-26 evidence shape, the standalone stash-and-restore shape, the local verification gate, the commit message and its two streams, verified delivery's four claims, and building an issue with no CI plane; `docs/SURFACES.md` gains § 9, the turn-end bell per surface; `docs/LAUNCH-MIGRATION.md` gains the launch declaration rules); shared bash moved to scripts (`scripts/hatsu_root.sh` resolves the plugin root and prints it alone; `scripts/dist_tag.sh` is kagutsuchi's distribution-tag block with a `--dry-run` **and a hermetic `--self-test`, seated on its own `dist-tag-guard` lane** beside the other executable guards); shibari's body is `templates/pr-body.md`. **The ceilings are now measured rather than remembered**: [`scripts/prose_size_check.sh`](scripts/prose_size_check.sh) holds every `claude/agents/*.md` except `kurapika.md` at **6,144 bytes** and the sixteen dieted skills at **12,288**, exiting `1` and naming each offender — a limit nothing measures is a limit already exceeded. History moved out of the prose is summarised below and archived verbatim in [`docs/history/v0.42.0-prose-diet.md`](docs/history/v0.42.0-prose-diet.md).
- Counts: forty-two skills, ten independents beside Kurapika; README, `docs/SURFACES.md`, `docs/WORKFLOW.md` and the antigravity generator say so. Run state in `docs/Loop/hatsu-89-nen-220/`.

### History moved out of skill prose
Session 2 of the 2026-09-19 hardening audit (zheref/hatsu#89), the **diet**: the ten largest skills
were rewritten to carry rules only. Everything below was **recorded history** — a decision already
taken, a finding already filed, an incident already corrected, or a verified-live transcript — and is
folded here so the skills stop paying for it on every load. Nothing here is a rule; every rule the
prose carried stayed in its skill.

#### hatsu-warmup

- **§ 0 (`$CLAUDE_PLUGIN_ROOT`)** — the section once opened with `cat "$CLAUDE_PLUGIN_ROOT/nen/contract.json"`
  before any resolution. On this host the variable is exported from `~/.zshrc` pointing at
  **bankai 0.10.0**, so every Codex and Cursor session would have read *another plugin's* dependency
  contract, silently (`docs/surfaces/evidence/surfaces.md` § 8, F3). Resolving first is now the rule; the incident is
  here.
- **§ 0 (`nen schema check`)** — this checkout's aggregate used to exit `1` on every run, five rows
  `ok` and `nen/colors.yml` FAIL, because that file had never existed on any branch while six runtime
  surfaces named it (zheref/hatsu#79). All six rows pass since it was declared and seeded through
  `hatsu:tenkai` § 4. The durable cost recorded there: *a permanently-red check stops being read.*
- **§ 0 (retired at nen 0.5)** — the `schemas/` fallback announced at v0.3.0 and held open at v0.4.0
  was removed in v0.5.0; `--json`'s `location`, `shadow` and `shadowed` went with it and a boolean
  `legacy` replaced them.
- **§ 0a** — the adoption split was `zheref/hatsu#81`: *the same shape shows up every session:
  `hatsu-warmup` re-does per-session work that should have been settled once, at adoption.*
- **§ 1b / § 1c** — the two live `nen shu tools` transcripts (nen `0.7.0` printing no floor line,
  nen `0.8.0` printing `compat floor: 0.7` and widening the same pin's ceiling from `<0.8.0` to
  `<0.9.0`), and the retired defect they close: this section used to compute the range itself and
  claimed *"`0.8.0` fails it exactly as `0.6.0` does"* — true through v0.7.0 and false the moment the
  floor shipped. Left standing, every warm-up on a host carrying `0.8.0` would have rebound
  `~/.local/bin/nen` **down** to v0.7.0, making the floor inert for every consumer.
- **§ 1c** — why the floor sat at `0.7`: v0.5.0 removed the `schemas/` fallback, v0.6.0 changed three
  behaviours in place, and v0.7.0 changed four more with no new flag (`stage triage` gained
  `local-config` and `large`; relative own-path flags resolve against `--repo`; a missing or malformed
  `--target` moved from `1` to `2` across sixteen verbs; `pr ready` began reading
  `dependabot_carve_out`).
- **§ 2b (retired at nen 0.7)** — the cache slot is keyed on source **and** ref
  (`<cache-root>/<source>/<ref>/<artifact>`, zheref/nen#6); keyed on the ref alone, two `--source`
  values at one tag collided in one slot, detected by the checksum gate rather than executed, costing
  a fork or mirror a permanent cache miss. `--source a/..` used to pass the shape check and be
  neutralised downstream; it is exit `2` at the flag now.
- **§ 2b** — the live `v0.7.0` transcript showing `~/.cache/nen/zheref_nen/v0.7.0/nen-darwin-arm64`
  with nothing in it called `nen`, and the observed failure it explains: `~/.local/bin/nen` still
  pointed at the old target after an exit-`0` bootstrap (`docs/surfaces/evidence/surfaces.md` § 8, F5). The same run
  is where a headless Cursor session chose the session-scoped binding unprompted and was right.
- **§ 2 (exit codes, retired at nen 0.7)** — `nen bootstrap --help` publishes the whole table itself
  now, including `7`; at v0.6.0 its `--help` named no exit code at all
  (`docs/ab/hatsu-warmup.md` § *Retired at nen 0.7*).
- **§ 5 prelude** — the unresolved-root glob incident: with the variable empty,
  `for d in "$CLAUDE_PLUGIN_ROOT"/surfaces/codex/*/` ran its body once on the unexpanded pattern, so
  `name` became `*`, the `rm -rf` fired on a literal `*` path and the copy failed on a source that was
  never there (Copilot review thread `PRRT_kwDOUKPjxM6hAjLJ`). Also recorded: a `[ -d
  "$root/surfaces/$surface" ]` guard checks shape, not identity — on this host it happened to fail
  because bankai carries no `surfaces/`, which was the safe failure for the wrong reason.
- **§ 5a (Codex)** — three controlled `codex debug prompt-input` renders, no model called, showing a
  symlinked mirror listed as `hatsu:aka` and a `cp -R` of the same directory listed as the bare `ren`
  (`docs/surfaces/evidence/surfaces.md` § 7, F1); and F10, where a symlinked mirror's relative
  `../../../nen/workflow.json` resolved into the *plugin's* policy file rather than the target's.
- **§ 5a (`AGENTS.override.md`)** — verified live with both files present, only the override reached
  the instruction envelope: the project's `AGENTS.md` was **superseded**, not merged
  (`docs/surfaces/evidence/surfaces.md` § 7, F9).
- **§ 5b (Cursor)** — the row once carried a box saying link-following was unverified because
  `cursor-agent status` reported *Not logged in*; four controlled probes on `2026.09.08-6caf4ff`
  resolved it (a skill found through a symlink inside the workspace and through one pointing outside
  it, listed under its **bare** name — Codex's F1 does not reproduce there). The link-resolution half
  of `nen/workflow.json` was not re-tested and stays a caveat in the skill.
- **§ 5b · i** — the measured failure the version check exists for: with the mirror installed exactly
  as mandated, `2025.09.18-39624ef` answered a discovery probe with the whole reply `NO SKILLS
  VISIBLE`, seventeen bytes, then answered the next question by grepping the working tree. It nearly
  became a false finding against the symlink row; the control probe (the same build cannot see a
  `cp -R` copy either) showed the variable was the binary (`docs/surfaces/evidence/surfaces.md` § 8, F2).
- **§ 5b · ii** — on this host `.cursor/skills/` also carried Cursor's own built-ins and this host's
  **Claude Code plugin skills**, `build` and `drive` among them (`docs/surfaces/evidence/surfaces.md` § 8, F4).
- **§ 5d (`info/exclude`)** — verified live on a fixture: writing the exclude to the `--git-dir`
  answer in a linked worktree left `git status --porcelain` printing `?? .agents/` and
  `git check-ignore -v` at exit `1`; the `--git-path` answer silenced the status and made
  `check-ignore` exit `0`, naming `<main>/.git/info/exclude:7` (`docs/surfaces/evidence/surfaces.md` § 7, F2).
- **§ 5d (`AGENTS.md`)** — the section used to say `AGENTS.md` *"is the exception and is not
  excluded"*. On a target tracking none — `zheref/nen` does not — that left `?? AGENTS.md` standing
  forever, `nen shu warmup` refused at exit `2` on an untracked path it did not put there, and a whole
  headless run stopped on it (`docs/surfaces/evidence/surfaces.md` § 7, F9). Also recorded: the `.gitignore` refusal
  one directory over, Copilot review thread `PRRT_kwDOUKPjxM6hAjLf`.
- **§ 5e (retired at nen 0.5)** — `nen surface mirror generate|check` exists at the pin (it answered
  *"nen: unknown command 'surface'"* at exit `2` through v0.4.0); `bash scripts/surface_mirror_check.sh`
  exits `0` with `codex ok: 40`, `cursor ok: 47`, so the mirror-check workflow runs a real check rather
  than skipping with a notice.
- **§ 5e** — `manifest_name` has been awk rather than grep since the tenth review round of #38.

#### sharingan

- **The rename.** The skill was `drive` until Hatsu v0.4.0; the rename (wave 3, v0.5.0) changed the
  name only. The A/B evidence stays at `docs/ab/drive.md` under the original name.
- **`nen pr fetch` and `nen pr next-blocker`, filed at v0.1.0.** Both were reproduced broken against
  real reference-repository PRs: `#925` crashed *"could not fetch … reviews: gh: Unprocessable Entity
  (HTTP 422)"*, `#940` crashed differently — `$.reviews -- expected an array, got object` (a lone
  `PENDING` review returned unwrapped). `next-blocker`'s missing `--gates` half was **closed** by nen
  v0.2.0 (#60, closes zheref/nen#20); the crash half was never re-verified, and the skill stopped
  calling either verb for a verdict. Reproductions: `docs/ab/drive.md` § 2.
- **Finding F17, measured live.** `contracts/reference.gates.json` pointed at `zheref/nen` returned
  *"reviewers sasuke,tenma,copilot"* with row 4 FAILED — two identities that will never review that
  repository, **permanently owed**, so the gate could never answer `ready` there at all. The rule that
  survives is in § 4; the measurement is here.
- **The `zheref/zheref.io` gate incident.** A résumé PR in a consumer repository touching
  `nen/contract.json`, `nen/gates.json`, `.github/workflows/pr.yml`, `scripts/` and `docs/` derived
  **G4** from the canon path sets and was reported as G4 in the PR body, a landing report and two
  `nen stop` banners. It is G2. Dropping `nen/` from the policy set does not fix it — the path set was
  never the dial; the repository's role is (ruling 2026-09-18).
- **`RR-IS-#929`** — `nen gate derive` reads the diff's half only and cannot tell that a sub-PR based
  on an `integration/*` branch is not a maintainer gate row at all.
- **`RR-IS-#554`** — applying the wake label in the same breath as a comment: both dispatches land in
  the same concurrency group seconds apart and the second cancels the first's `probe`, so `build`
  never starts and the wake dies silently.
- **`RR-IS-#798`** — a `CONFLICTING` PR dispatches no `pull_request`-family event, including the
  `labeled` event the wake needs, and the wake is edge-triggered, so a label already present must be
  removed and re-applied before it can even be tried — and on a still-conflicted PR that still will
  not help. `copilot-sweeper.yml`'s `conflict_guard` redrives only a `kisuke-bankai[bot]`-authored PR.
- **The Copilot-as-Bot cycle.** A session burned several cycles concluding the re-request *"cannot be
  done on the maintainer's credentials"* and handed a routine step back as though it were a gate. The
  four dead ends are recorded: `gh pr edit --add-reviewer` goes through `requestReviewsByLogin` and
  never resolves a Bot (zheref/nen#160); `gh api …/requested_reviewers` with a bare login answers
  **422 `Reviews may only be requested from collaborators`**, which reads like a permissions wall and
  is not one; GraphQL `requestReviews(userIds: [BOT_…])` answers `NOT_FOUND`; and REST's
  `requested_reviewers` lists users and teams only, so a pending bot request shows as `[]`.
- **The old two-round cap.** The maintainer's ruling of 2026-09-12 replaced the inherited five-round
  retry cap with *one completed round normally suffices, a second only for substantive reassessment*.
  That number is now `nen/gates.json` → `round_policy.maxRounds`, and the prose cap is gone.
- **PR 38 ran sixteen Copilot rounds before the 2026-09-12 ruling; PR 75 ran six after it**, because
  Copilot auto-reviews every push and the cap governs requests, not arrivals (audit, *Reviewers*).
- **§ 5's GraphQL thread residue is replaced.** The paginated `reviewThreads` read and the by-hand
  reply/resolve mutations were the only way to do thread hygiene; `nen pr threads list|reply|resolve`
  (nen v0.12.0, closes zheref/nen#215) owns it now.
- **Live stop transcript.** The `RR-PR-#940` banner row (*"A fifth shell clause for a frozen-line
  patch, expiring with the freeze … 🟢 (G4) … Merge — maintainer only"*) is kept here rather than in
  the skill.

#### breath

- **Retired at nen 0.6: a detached `HEAD` is classified, not refused.** Through v0.5.0
  `nen wc classify` exited **`1`** on one — the code the family reserves for *the tree is not clean* —
  with `--json` printing prose rather than a document, so a caller could neither tell the refusals
  apart nor parse the answer. At the pin the branch is a **field** (`state.branch: string | null`,
  `state.detachedAt`), every case exits `0`, and one refusal remains: a `HEAD` that names no branch
  *and* resolves to no commit. The shape mattered because `git worktree add --detach` is what
  `hanten` § 9a makes for every Codex reviewer, and it stopped a whole headless run
  (`docs/surfaces/evidence/surfaces.md` § 7, F4).
- **Retired at nen 0.6: cutting by hand when another worktree holds the trunk.** A primary checkout on
  `main` with every effort in its own worktree meant git refused to force-move the trunk — *fatal:
  cannot force update the branch 'main' used by worktree at '…'* — and through v0.5.0 that landed
  mid-run, after the fetch. At the pin `git worktree list --porcelain` is read first, matching the
  **full** ref so `feat/main` is never mistaken for the trunk, and `--dry-run`'s guarantee changed
  from *runs nothing* to *mutates nothing* plus that one read-only command, with a new `dryRun`
  boolean because `steps[].exitCode` can no longer tell the two forms apart.
- **Retired at nen 0.5: validating `nen/workflow.json`.** `nen schema check --repo <path>` carries the
  row (`ok nen/workflow.json coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}' off
  'main', checks: lint`).
- **zheref/hatsu#60** — the incident behind § 3a: an unrelated effort landed on last week's
  prize-recollection branch because a clean non-trunk checkout was read as "already warm".
- **The `info/exclude` findings** — F2 (a linked worktree's `--git-dir` names a file git never reads)
  and F9 (the surface mirror the warm-up had just installed was the untracked tree that stopped a
  headless run), both `docs/surfaces/evidence/surfaces.md` § 7.
- **The no-declaration transcript** — verified against the `zheref/nen` checkout, which carries no
  `project` block: the git half prints in full and the run ends *"no declaration -- build/test
  verification skipped … That is not a failure … this exits 0"*, `lane: (none)`
  (`docs/ab/breath.md` § 2.3).
- **The `nen shu warmup` detached-HEAD fixture transcript** (*"HEAD is DETACHED and reaches no commit
  of its own -- reported, not an error"*), and the live `nen shu lint --repo . --lane plugin` exit `0`
  that is the whole of this repository's base-tip proof.
- **zheref/hatsu#63** — there is no Nen verb for per-effort Hatsu reviewer budgets, which is why the
  cycle ledger is a script.
- **The 2026-09-18 ruling's rationale** — § 0's earlier shape verified the base *underneath* work
  already written, so a red check arrived late and ambiguous; the previous ruling accepted that cost
  explicitly, and proving the tip on a tree holding none of the effort removes the ambiguity rather
  than documenting it.

#### shibari

- **The stale-base measurement** — local `main` measured at 13, then 36, then 50 commits behind in a
  single run, where `main...HEAD` named **43** changed files against the branch's own **8**
  (`docs/ab/mukai.md`). The rule (fetch, then `origin/<base>...HEAD`) stayed; the numbers are here.
- **Finding F6** — the landing report used to be rendered *before* this step, so `spiritual-message`'s `landing`
  variant carried two empty sections and an empty **09** was indistinguishable from `not-ready`.
- **Retired at nen 0.5: `nen shu evidence --repo <path> --base <ref>`** reads `project.evidence`
  (exit `0`, rows grouped suite → scene), and **`nen pr edit-body`** replaced `gh pr edit --body-file`
  — verified live against this repository's own PR 30, with the number certified before any write and
  `nen issue edit-body --issue 30` refusing the same number at exit `2`.
- **Retired at nen 0.6: requesting Copilot** — `nen pr request-reviews --add-bots BOT_kgDOCnlnWA`
  routes to the `requestReviews` mutation's `botIds`, verified live against `zheref/hatsu#36` at exit
  `0` with the `zheref -> user` / `BOT_kgDOCnlnWA -> bot` dry-run rendering. `--add-reviewers copilot`
  against the same PR is exit `2` naming the login.
- **The `--body-file` root change** — from nen 0.7 a relative `--body-file` resolves against
  `--repo`'s root (zheref/nen#100), and the **resolved** path travels onward to `gh`. Through v0.6.0,
  `--repo <the worktree> --body-file body.md` read `body.md` beside the *process*: on a machine
  carrying the same file in both trees that is a wrong PR body posted at exit `0`.
- **The two `fragment-required` findings**, both recorded rather than routed around
  (`docs/ab/shibari.md` § 4): `--head-changelog` must exist or the verb refuses at exit `2` (*"A verb
  that fell back to an empty input here would report a clean verdict for a check it never ran"*), and
  `fragment-present` needs the fragment on disk at head as well as in `--files`.
- **The `zheref/zheref.io` G4 incident** — the same one recorded under *sharingan*; shibari carried a
  second copy of it.
- **The `body-check` transcripts** — `3/3 requirement(s) satisfied` at exit `0`, `2/3` with a
  `MISSING  How to verify` row at exit `1` (`docs/ab/shibari.md` § 2.1), and the three `gate derive`
  renders at § 2.3.
- **The KroApple mirror script** — `ci_scripts/pr_screenshots.sh -y` was named in the skill as the
  concrete `public-mirror` publish step; the rule (the target's own declared step, authorized by the
  `mukai` call) stayed, the example is here.

#### jutaisho

- **Finding F8** — § 1 read *"rungs fire per § 2"* for every turn while the hard limits read *"never
  rings for a turn that needs nothing"*, and nothing defined what "needing something" was short of a
  gate, so both readings were supportable and disagreed about every ordinary turn of every effort.
  The table that resolves it is now the rule.
- **Retired at nen 0.6: an ordinary turn may be spelled `--line ""`.** Through v0.5.0 the empty line
  was exit `2` (*"the line must open with the literal 'at'"*) while a bare `at` was exit `0`, so the
  ordinary invocation of the most-invoked step in the loop was the one a caller had to be told about.
  A headless Cursor run found it by trying both (`docs/surfaces/evidence/surfaces.md` § 8, F11).
- **Retired at nen 0.5: `notifications.turn` is in `nen.workflow/v0.1`** — a closed two-value set,
  verified live both ways (`"turn": "loud"` FAILs naming the set, `"all"` validates `ok`), and written
  into every scaffolded policy file.
- **Retired at nen 0.11: the marker was this skill's hand-written residue.** Through v0.10.0
  `nen stop --mark` wrote a five-field `nen.stop.mark/v0.1` document that nothing read, and this skill
  wrote its own richer shape beside it, deliberately, because the nen shape carried no `title` and
  every bell it rang said *"A decision is waiting."* with the report link dropped. `--mark --title
  --body --report-url --options --propose-issue` now writes `nen.stop.mark/v0.2`, which the hook
  reads. The v0.1 kept-residue rationale, the `§ 6` by-hand write block and residue entries 1, 6 and 8
  all lapse with it. (Copilot review thread `PRRT_kwDOUKPjxM6hAjMh` is where the by-hand write was
  spelled out rather than the verb.)
- **The headless-seat measurement** (`docs/surfaces/evidence/surfaces.md` § 7, F8): inside `codex exec -s
  workspace-write` on this host, `osascript -e 'display notification …'` exited **`0`** having
  delivered nothing, with stderr *"NSNotificationCenter connection invalid"* /
  *"ServerConnectionFailure: 1"*, while `afplay …/Glass.aiff` exited `1` with *"AudioQueueStart failed
  (-66680)"*. The rule that survives is *read stderr, not the exit code*.
- **F13** — after a headless run that ended successfully with the branch pushed,
  `.nen/last-stop.json` still read `gate: "G5"` with a blocker answered three passes earlier, because
  nothing on a hookless surface removes the marker.
- **The live `nen stop` output** quoted in § 2: *"rungs 2-3 (OS notification, audible cue): not fired
  by nen — only git/gh subprocesses are ever shelled out to"*, and the `--notified` line flipping from
  *"NOT fired — the caller's to have sent"* to *"reported sent by the caller."*
- **`nen parse izanami`'s classifications** — `osascript` and `afplay` both `[unknown]`, refused at
  exit `1`; `nen stop` itself `[read-only]`, exit `0`.

#### build

- **The declared process change.** The retired skill released a routed issue to a CI builder
  (`bankai:stage/building` woke Kisuke, Sasuke, Naruto or Yamamoto's workflow) and spent a whole
  section verifying the wake fired. Hatsu has no CI plane at all, and Gon is ratified as an agent but
  **unratified for the delegation grammar**, so there is nothing to route to. The port follows the
  precedent `bankai-handbooks` set for the identical structural gap under `CON-37`.
- **§ 10, Findings against the binary, filed at v0.1.0 and reconciled at v0.3.0** — all four rows:
  (1) **closed**, `nen issue chain-position`/`terminus` now refuse a pull-request number (nen v0.2.0
  #71, closes zheref/nen#25) where both answered `routable`/`own-pr` for a real PR with no signal, and
  the manual `gh api … --jq '.pull_request'` read retired with it; (2) **unchanged**, an incomplete
  `--chain-labels` map is `undecidable` and an unknown role name is exit `2`; (3) **closed**,
  `nen epic next-wave`'s checklist parser widened in v0.2.0 (#65) and v0.3.0 (#103) from `- [ ] #<N>`
  only to four spellings anywhere on a checkbox line, with `blocked by`/`blocks` refs treated as edges
  and unresolvable checkboxes reported `unparsed`; (4) **closed**, `nen loop slots` no longer defaults
  the local plane to `7` (v0.2.0 #69, closes zheref/nen#52), so a forgotten `--local-cap` used to
  silently triple this skill's concurrency limit.
- **Retired at nen 0.7: supplying a placeholder for a role this repository does not have.** Through
  v0.6.0 the refusal named roles without saying which mattered, so callers reasonably supplied the
  full eight-role map including a placeholder for a role their taxonomy genuinely lacked — the one
  thing a taxonomy check exists to prevent (zheref/nen#55).
- **The reference repository's live state at the port** — no open issue carried
  `bankai:stage/idea`, `researched`, `ready-for-bankai` or `ready-for-shikai`; `bankai:epic` had zero
  open issues; the taxonomy carries no `chore` label at all. The `idea`, `epic-awaiting-approval` and
  `epic-approved` rows were contract-verified plus one live run against a constructed role map
  (`docs/ab/build.md` § 2.7a), never against an issue natively carrying those labels.
- **Table-shaped epics** — both real epics checked at the port (`#733`, `#568`, both closed) wrote
  their phases as a markdown table or as linked bullets, and `nen epic next-wave` reads
  `{"total":0,"done":0}` against a table-shaped epic. That is a finding about those epics' shape, not
  about the verb; the rule (write children as checkbox lines carrying a resolvable reference) stayed.
- **The `nen loop slots` transcript** — two efforts with neither ready nor prompted report
  `local: 2/2 occupied, 0 free <- BINDING` at exit `1`; flipping one to `ready:true, prompted:true`
  frees it at exit `0` (`docs/ab/build.md` § 2.10).
- **The `shu build` seat transcript** on a freshly scaffolded `nextjs` tree (*"lane 'nextjs' (nextjs)
  declares no 'build'. It declares: archive, deploy, release, ui-test."*), the thirteen-step
  `shu warmup --dry-run` render, and the `nen stop` banner render at § 2.11.
- **The `--efforts` cwd note** — it resolves against the process cwd rather than `--repo`, unlike the
  flags nen 0.7 moved; the rule (pass an absolute path) stayed.

#### kokusen

- **Retired at nen 0.6: partitioning the ignored rows out of `flagged`.** `nen stage triage` reports
  them in its own bucket with its own `ignored: <n> file(s), not listed` count, and the exit code
  follows `flagged` alone — through v0.5.0 a tree whose only dirty rows were ignored was exit `1`.
  The rule was carried because the alternative was unusable: a full `ren` run against the `zheref/nen`
  checkout flagged **5905** paths on one turn and 5907 on the next, all but one `[ignored,
  out-of-scope]` — *a per-file ask at that width is not a procedure anybody executes.*
- **Retired at nen 0.7: local-config and size detection.** Both were carried as residue because this
  skill and `tensho` § 3 were independently compensating for the same gap. The same constructed tree
  that answered exit `0` with three clean rows at v0.6.0 answers exit `1` with `.env.local
  [secret-shape, local-config]`, `big.txt [large]` and `settings.local.json [local-config]` — one of
  the four silent changes `zero_major_caveat.why` names: the same bytes, the opposite exit code.
- **The `node_modules/bottleneck/.env` row** — the real run that produced the ignored-tree
  `secret-shape` rule: read literally, the categorical rule would have had a commit phase rotate or
  delete a third-party package's fixture file.
- **The `nen commit check` transcripts** — `verdict: OK -- this working copy is the one the build
  proved green` at exit `0`, and this repository's own `NOT PROVED -- there is no build proof for lane
  'plugin'` at exit `1`, which is exactly what the skipped-case condition predicts.
- **The `plugin` lane's seat transcript** — `nen shu build --repo .` at exit `4` quoting *"Hatsu
  compiles nothing. The plugin IS its source …"*, beside `nen shu lint --repo .` at exit `0` in 916ms.
- **Retired at nen 0.5: the forbidden-trailer refusal.** `nen commit format --repo <path>` refuses an
  unadmitted attribution trailer at exit `2` naming the file; the enforcement layer that used to be
  absent is now the binary's. A headless Cursor run against nen 0.3.0 found `--repo` **accepted and
  silently ignored** — *"a flag that is accepted and ignored is worse than one that is rejected: it
  reads like the guard ran"* (`docs/surfaces/evidence/surfaces.md` § 8, F12) — which is why the skill once called it
  residue.
- **The merged-streams incident** — a merge landed carrying *"nen: header line is 75 characters, over
  the 72-character convention"* as its subject, repairable only because `origin` had not seen it yet
  (`docs/ab/mukai.md`). The verb's behaviour was correct; the residue path around it was missing its
  gate, which is now the rule.
- **Retired at nen 0.5: `nen/workflow.json` is validated** — `nen schema check` carries the row.

#### kagutsuchi

- **The name.** The maintainer has written it *kagutsushi*; the skill is `kagutsuchi` — Sasuke's Blaze
  Release, the technique that shapes Amaterasu's black flames into something aimed. Said once so the
  invocation and the roster agree.
- **The § 4a script's incident comments.** Each refusal in the tag block was written against a real
  defect found in review: the target was interpolated into shell source while the prose claimed it was
  not (a filled-in `$(touch /tmp/pwned)` would run during the assignment); a quoted heredoc was
  considered and rejected because its delimiter is still in-band; `tags.deploy` compared with `in`
  against a **string** would opt `testflight` in from a value of `"testflight-someday"`; `.get()`
  returning `None` for both absent and `null` reported a present-but-malformed declaration as *not
  declared* and exited `0`; testing only that `push` existed let `{"push": false}` and `{"push":
  true}` take the same path; a silent empty `nameFrom` made every later refusal report a misleading
  reason; `cat-file -e` resolves `HEAD`, `origin/main` and `HEAD~1`, defeating the never-HEAD rule it
  was checking; and the clean-tree condition was asserted in prose and checked nowhere. The checks
  stayed; the narratives are here.
- **The live transcripts** — `nen shu deploy --dry-run` at exit `0` with the target line, host row,
  preconditions and composed argv (§ 2.1); the bare form byte-identical above its one stderr line
  (§ 2.2); `--run` with `--dry-run` refused at exit `2` (§ 2.3); the unset `FIXTURE_DEPLOY_TOKEN` row
  with no value anywhere in text or `--json` (§ 2.4); `--lane docs --target beta` answering with the
  **seat** rather than "no such target" (§ 2.5); and the fixture send at exit `0` (§ 2.6).
- **`docs/ab/kagutsuchi.md` § 4.1** files the finding worth acting on: no field in
  `project.targets.<name>` says which side of G3 a destination is on.
- **zheref/nen#91** — a per-run `.nen/logs/` transcript is not in this release.

#### amaterasu

- **Retired at nen 0.5: `--target` on a launch verb.** `nen shu dev --target sim --dry-run` renders
  the target, the device, the appended `args`, the after-steps and both substitutions at exit `0`
  (`docs/ab/amaterasu.md` § *Retired at nen 0.5*), so resolving the target, the probe and its exact
  name match, appending `args` and running the after-steps are all nen's. Through v0.4.0 a
  `{device.id}` or `{artifact}` in `args` was accepted and simply unfilled, reaching the child process
  as itself; it is exit `2` now.
- **Retired at nen 0.6: reading the resolved device's state, where `readyWhen` is declared**, and
  **re-reading the target's verb behind a seat**. The trap the second closes, observed on 2026-09-10
  against `zheref/KroAndroid` at the then-pinned 0.5.0: `nen shu run --target galaxy` answered exit
  `4` — *"'run' is unsupported on lane 'android' … a release install to a device is a deploy, not a
  local run"* — a correct exit `4` and the wrong sentence to act on, with the declaration's answer
  (`dev --target galaxy`) one line away.
- **The `unauthorized` launch** — the same run resolved `R52X603Q9BA unauthorized usb:33-3.2`,
  printed `device: R52X603Q9BA  id usb:33-3.2` as *resolved*, and every `adb -s usb:33-3.2 …` after it
  answered `adb: device unauthorized`.
- **The worktree facts, both observed on 2026-09-10 in a linked worktree of `zheref/KroAndroid`:**
  (a) a fresh worktree fails the declaration's own preconditions — `local.properties` is gitignored
  and `bankai/` is a submodule, so `nen shu dev --target galaxy` refused at exit `2` naming both — *a
  worktree is not a launch-capable checkout, it is a checkout of the tracked files only*; and (b)
  launching writes to a **shared** device, so worktree isolation buys nothing on the axis that
  matters. Also recorded: `nen shu dev --repo <a worktree> --dry-run` renders with `cwd:` set to the
  worktree and **no warning of any kind** (`docs/ab/amaterasu.md` § 2.5).
- **The `{artifact}` two-roots fix at nen 0.6** — on a lane whose cwd is not `.` the installer used to
  be handed a path resolved against the wrong root and answered *"no such file"* about a file sitting
  right there; `substitutes:` now prints both strings when they differ and `--json` gains
  `artifactAs`. A lane at the root passes exactly the bytes it always did.
- **Retired at nen 0.5: validating `nen/workflow.json`.**

#### jujutsu

- **The live probe transcripts** — `xcrun devicectl list devices` and `xcrun simctl list devices
  available` (`docs/ab/jujutsu.md` § 2.2), and the Android one that is the case this skill exists for:
  `List of devices attached` / `R52X603Q9BA	unauthorized` (§ 2.3).
- **The name's bytes** — the device this machine sees is `Sergio’s iPhone Pro`, whose apostrophe is
  U+2019 (`342 200 231` octal, three bytes), rendered `Sergio?s iPhone Pro` in a table that cannot
  show the codepoint. The rule stayed; the measurement is here.
- **`nen parse izanami "adb devices until …"`** classifies `adb devices` as `[unknown]` and refuses
  the whole run at exit `1`; `xcrun devicectl list devices` gets the identical answer
  (`docs/ab/jujutsu.md` § 2.4).
- **The `readyWhen` observation** — the same `zheref/KroAndroid` run recorded under *amaterasu*, which
  is why the declaration now carries the state column.
- **The `installDebug` divergence, observed 2026-09-10** — the target's verb was `./gradlew
  installDebug`, an install inside the verb with no way to name a device; with two phones attached nen
  resolved and reported `usb:33-3.2` and Gradle installed to `R5CY213GAST`. Nothing in the transcript
  flagged it, because from nen's side nothing went wrong.
- **The AnteikuTV `-scheme` finding** — a row already carrying `-scheme X` plus `args: ["-scheme",
  "Y"]` puts two `-scheme` flags on one `xcodebuild` command line and the tool errors rather than
  letting the later one win.
- **Retired at nen 0.5: `nen shu dev --target <name>`** renders the whole plan at exit `0`
  (`docs/ab/jujutsu.md` § *Retired at nen 0.5*), and **`nen schema check`** reports
  `ok nen/contract.json project (…)` for a declaration carrying `project.launch`.
- **The `field`-form `readyWhen` is exercised live** in `docs/ab/jujutsu.md` § *Retired at nen 0.6*;
  the iOS `path` form was read off nen's documented two-level walk and devicectl's nesting and **has
  not been run against a physical device**.
- **The old contradiction** — a hard limit read *"never reports `nen schema check`'s `ok` as evidence
  that the target works — at this pin the block is preserved and read by nothing"* while § 6 said nen
  **parses** the block. The limit stayed and its reason was corrected: `ok` proves the block parses,
  not that anything resolves.

---

#### Second pass — 2026-09-20

**`scripts/hatsu_root.sh` is new, and it is where the plugin-root prelude now lives.** `manifest_name`
(the awk stack machine over the one manifest shape the tooling writes), `is_hatsu` (the manifest's own
top-level name compared WHOLE, plus a `claude/skills/` directory checked as a directory), and the
three-candidate loop with its three capture guards moved out of `hatsu-warmup` § 5 verbatim. The
script prints the resolved root **alone on stdout**, names every passed-over candidate on stderr even
on success, and exits `1` with the `NOT INSTALLED` reason when none resolves; `--quoted` adds the
label line and the single-quoted literal a caller pastes. `hatsu-warmup` § 0 is now two lines pointing
at it, and every skill that carried a copy of the prelude — sharingan, breath, shibari, jutaisho,
build, kokusen, kagutsuchi, amaterasu, jujutsu — says *resolve the plugin root as `hatsu-warmup` § 0
says* instead.

**What else moved out of skill prose in this pass** (all of it rationale, none of it rule):

- **hatsu-warmup** — the `$CLAUDE_PLUGIN_ROOT`-names-another-plugin incident and the unresolved-root
  glob failure now live here rather than in § 0 and § 5; the per-surface *why* (Codex's namespacing,
  Cursor's minimum and flat name space, first-run discovery, the plugin-source report forms) is a
  one-line pointer at `docs/SURFACES.md` §§ 1, 2 and 6.
- **sharingan** — the CI-agent wake channel and the escalation ladder were merged into one
  subsection, since both serve a CI plane Hatsu does not have; the gate-derivation *reasoning* is a
  pointer at `docs/ROSTER.md` § *Rulings of 2026-09-18*, and the readiness identity table a pointer at
  `pr-state` § 2.
- **shibari** — § 7(c) no longer restates the gate derivation and points at `sharingan` § 2; § 9 no
  longer restates the reviewer-round policy and points at `sharingan` § 6.
- **jutaisho** — the rung ladder and the per-surface picker are tables; `notifications.turn`'s
  two-value validation and the marker's v0.2 shape are stated once.
- **build** — the CI-plane-removal narrative is three sentences; the `shu` verb sequence is four
  command lines with the exit rows that differ from `kurapika.md`'s table.
- **kokusen** — § 3's three gate steps and § 4's seven triage kinds are single-sentence rules; the
  `nen stage triage` kind list is prose rather than a table with a *trigger* column.
- **kagutsuchi** — § 4a's tag script keeps every refusal and one-line reasons; the multi-paragraph
  incident comments (the interpolated target, the heredoc delimiter, the `in`-against-a-string
  fail-open, absent-versus-null, `push` as a value, the silent empty `nameFrom`, `cat-file -e`
  resolving symbolic revisions, the unchecked clean tree) are recorded in the first pass above.
- **amaterasu** and **jujutsu** — the device-state and after-step rules are tables and one-sentence
  bullets; every remaining "verified live" line is gone.

#### Third pass — 2026-09-20 (the widened paths, and the last four skills)

**New files.**

- `scripts/dist_tag.sh` — `kagutsuchi` § 4a's tag block, verbatim, as an executable taking
  `--repo <path> --target-file <file> [--dry-run]`; exits `0` cut / dry-run ok, `2` refused,
  `3` not declared, `1` `nen tag cut` failed. Kept: the target never enters shell source, the
  three-way `tags.deploy` read, the four-way `push` read, `nameFrom`'s symlink/regular-file/
  inside-repo checks, the raw-40-hex SHA check, the clean-tree check, `check-ref-format`, and
  `branch.base` read as data. The skill keeps one paragraph naming the script and its exits.
- `templates/pr-body.md` — `shibari`'s nine-part body, with the three mechanical checks
  (`nen pr body-check`, `nen changelog fragment-required`, gate derivation) as comments at the top.
  Shibari keeps the invocation, the parameter files, the linkage contract and the gate.
- `scripts/hatsu_root.sh` — recorded in the second-pass section above.

**Moved into `docs/WORKFLOW.md`** (each section names its origin and its date in the file itself):

- `## Gate derivation` and `## The UZF-26 evidence shape` — as briefed.
- `## The standalone stash-and-restore shape` — out of `breath` § 0: the guaranteed outcome
  (ruling 2026-09-18), stash-by-SHA, `--include-untracked`, the never-`--discard`/`checkout -- .`/
  `reset --hard` rule, the isolated worktree preference, ao placement (replay unpublished, merge
  published, classify a detached `HEAD`), restore-before-every-stop, the never-drop-on-failure rule
  and the report's contents including *the base was green* / UNPROVEN. Breath keeps the six command
  lines, the once-per-session rule and the pointer. WHY-clauses dropped here rather than restated.
- `## The local verification gate` — out of `kokusen` § 3: the four steps in full (iteration checks
  in order; focused tests through tsukuyomi with the no-`--scope` rule and `missing-focused-route`;
  the build-proof read-back with its skip conditions and exit semantics; `wc classify` proving this
  is not the trunk). Kokusen keeps the four-step summary plus its own refusals.
- `## Writing a commit — the message and the two streams` — out of `kokusen` §§ 5–6, beside the
  `commits` policy it enforces (the coordinator's "point at WORKFLOW's commit section if one
  exists"): `nen commit format`'s shape validation, always-`--repo`, the canonical-trailer rule, the
  prospective-tooling rule, history-is-not-rewritten, the exit-code gate, the two-stream discipline
  and the three-row exit table. Kokusen keeps the staging sentence.
- `## Verified delivery — the coordinator's four claims` — out of `build` § 7: the four separate
  claims and the six-step pre-handover checklist. It governs mukai and en as well as build.
- `## Building an issue with no CI plane` (with `### Releasing an issue into `building``,
  `### Advancing an epic's waves`, `### The local build, and the concurrency cap` and
  `### A target repository with no delivery-stage taxonomy`) — out of `build` §§ 1, 4 and 4a: the
  no-CI-plane fact and its G5, `nen epic next-wave` (child-line grammar left to the verb's own help,
  per technique 3) with the checkbox-children rule and the `--body-file`/`--out` resolution, `nen
  issue terminus` and which PR is the gate, `nen loop slots --local-cap 2` with the local-plane slot
  rule, the `nen shu` sequence with its phase owners, the never-`--discard` rule and the `4`/`3`/no-
  `project`-block exit semantics, the label-application discipline (`CON-9`), and the stage-free
  taxonomy path. Build keeps the six numbered steps, the authority table and the gate table.

**Moved into `docs/SURFACES.md`.**

- § 2's placement table and the permission-pack paragraph (second pass), plus the Codex sandbox rule
  and `### The warm-up form, and its hard limits` under § 6.
- New `## 9 · The turn-end bell, per surface` — out of `jutaisho` §§ 5–6: the who-fires-rungs-2–3
  table, the marker-first ordering, the hookless-surface removal rule, the report's contents, and the
  in-session fallback with its sanitising rules and the read-stderr-not-the-exit-code rule. Jutaisho
  keeps a six-line § 5 carrying the three rules that are its own; its hard limits now cite
  SURFACES § 9 where they cited §§ 5–6.

**Moved into `docs/LAUNCH-MIGRATION.md`**: `## Launch declaration rules` (second pass), read by
`amaterasu` and `jujutsu`.

**Breath's `info/exclude` mechanics** now point at `docs/SURFACES.md` § 2 (`rev-parse --git-path`,
never `--git-dir`, never `.gitignore`, the sandbox `--add-dir`); breath keeps which paths qualify,
the show-before-writing rule, the re-classify expectation and the refusal stop.

**A defect found and fixed in this pass**: an earlier section-swap in `breath` matched to the next
`##`/`###` heading and so deleted § 2c (the host probe) along with § 2b, since § 2c is a bold
paragraph rather than a heading. Restored, tightened, and every later swap bounded explicitly.

**Bytes after this pass** (`wc -c`, ceiling 12,288): hatsu-warmup 12,284 · sharingan 12,279 ·
breath 12,262 · shibari 12,284 · jutaisho 12,126 · build 12,284 · kokusen 11,255 · kagutsuchi
12,279 · amaterasu 12,281 · jujutsu 12,263. **All ten under the 12,288-byte ceiling.**

Re-verified 2026-09-20: `claude plugin validate . --strict` passes; `grep -rn "open the report"` over
sharingan/en/senkei returns nothing; `maxRounds`/`cap-reached` appear in sharingan, en, senkei and
build; `sh scripts/dist_tag.sh --dry-run` prints the usage line and exits `2` with no arguments, and
with `--repo . --target-file <a file holding "testflight">` reads the target from the file and exits
`3` (`no tags.deploy entry ... not declared for this target`).

## v0.41.0 — fixed defaults, Crazy Slots, permission packs (zheref/hatsu#85)

> Pinned to nen **v0.11.0** (`minimum` `0.11`): `nen/decisions.json`, `nen stop --options --propose-issue --title --body --report-url` and `nen stop clear`, `nen shu warmup --carry`, `nen repo classify`, `nen surface capabilities`, `nen phase begin|end|show`, the bounded reviewer round policy and `--exclude-check` in `nen pr ready`, an optional `nen/colors.yml`, `nen <bogus> --help` at exit 2, and `watch until` pacing itself by `monitor.*` all arrive with that release (zheref/nen#216). **The warm-up reads `WRONG` until v0.11.0 is tagged**, and re-pins through the bootstrap once it is.

- **Maintainer's rulings of 2026-09-19, recorded in `docs/ROSTER.md` § *Rulings of 2026-09-19*.** The recurring stops have fixed defaults, as data in [`nen/decisions.json`](nen/decisions.json) (8 autonomous rows, 2 ask-once rows, 13 human-gate rows) and as one prose line per skill citing the row id: a dirty tree at breath is **carried** (`dirty-tree`, `nen shu warmup --carry`); an owed reviewer round inside the configured maximum is **requested on the maintainer's behalf** (`cap-reached`), in `en`, `sharingan`, `senkei` and `build`, and a third round is never a G5; a red lint **returns to rasengan** (`red-lint`, in `kokusen` and `gyo`); a missing focused route is **authored by rasengan** (`missing-focused-route`, in `kokusen` and `tsukuyomi`); a missing tool or model id is **installed or resolved** (`missing-tool`, in `hanten`'s Codex reviewer); a red release precondition is **reconciled in the same chunk** (`release-precondition-red`, in `getsuga`); a missing consumer declaration is repaired by `hatsu:tenkai` or set up through an assisted flow (`missing-consumer-declaration`, the one ask-once row); a semantic conflict in `ao` is always the picker with **ours, theirs, a genuine third, and resolve-and-show-the-diff** (`semantic-conflict`). A `human-gate` row cannot be widened by a consumer.
- **Crazy Slots — `jutaisho` § 4 is the decision-picker specification.** The report is always rendered and linked (banner, chat, marker `reportUrl`, OS notification) and **never an option**; the star sits on the **recommended decision**; at least three executable options, model-composed from the session and seeded by the row's `preferred[]`, each with its command line and consequence; a **proposed process issue on every real stop** (`nen stop --propose-issue`, written to `.nen/proposed/` for the third-hand harvest); `DO` and `MERGE` asks take no picker. The "⭐ on the report" wording is gone from `hanten`, `mukai`, `ao`, `en`, `mugetsu`, the README and the docs.
- **The marker is nen's.** `nen stop --mark` with the new flags writes `nen.stop.mark/v0.2`; `hooks/stop-bell.sh` reads `title`, `body` and `reportUrl` and carries the ask and the link into the notification (osascript values passed as argv, never spliced), honours **`HATSU_ATTENTION=off`**, and gains the **Linux** (`notify-send`, `paplay`) and **Windows** (BurntToast, NotifyIcon, `[console]::beep`) rungs ported from bankai-core's `attention_signal.sh` — marked untested until a host runs them. The hand-written `hatsu.stop-marker/v0.1` is still read, never written.
- **Permission packs.** [`contracts/permissions.json`](contracts/permissions.json) is the one source of the commands the skills run, scoped to the repository, its worktrees and its declared associated repositories; `scripts/permissions_pack.sh` renders it into `.claude/settings.local.json` (merged, never the tracked settings), `.codex/config.toml` + `.codex/hooks.json` (SessionStart install, Stop bell, PreToolUse guard), `.cursor/cli.json` + `.cursor/hooks.json`, and on Antigravity the pack is the generated hooks plus a `PreInvocation` install hook — a persona-wide `commandExecutionPolicy: auto` is deliberately not emitted, since it would approve arbitrary commands rather than the declared set. The warm-up places the pack on every surface (Claude Code included — the one write it now makes in a target) and `hatsu:tenkai` runs it after `apply`; a target that carries no `nen/contract.json` or `nen/workflow.json` is skipped, so a pack never lands in a repository that did not adopt Hatsu. It is deliberately NOT a plugin hook: a hook is plugin-global and must stay POSIX sh, and the merge uses python3. Every written path is excluded through `info/exclude`; a file the script did not write is left alone and named.
- **One key for the reviewer round cap**: `nen/gates.json` → `round_policy.maxRounds` (beside nen's `stallMinutes`), read by `sharingan`, `senkei`, `en` and `build`; `nen/workflow.json` → `monitor.maxCycles` stays en's acting-cycle cap. The deny rows cover `--force-with-lease` and `+` refspecs, `curl` to nen's bootstrap is allowed, and the Cursor pack keeps the full exe-plus-args form with reads and writes scoped to the workspace.
- `docs/WORKFLOW.md` § *The only interruptions are genuine G5 stops* now names the matrix; `docs/STANDALONE-ENTRY.md` says an autonomous row resolves the same way cold; the README's two stop sentences carry the ruling.
- **Release unit (CON-33(c) since v0.39.0).** Delivered by [#87](https://github.com/zheref/hatsu/pull/87) and numbered by [#88](https://github.com/zheref/hatsu/pull/88); the v0.40.0 section below shipped on `main` through [#86](https://github.com/zheref/hatsu/pull/86) without a tag of its own, so `v0.41.0` is the first tag since `v0.39.0` and covers both sections.

## v0.40.0 — the release row is real, and the role decides who owes one

- **Maintainer's ruling, 2026-09-19: a repository whose product is the process must declare a REAL `release` row, not a seat.** `hatsu:mugetsu`'s entire job is to execute the lane's declared `release` row at **`G3`** — so a seat there means it has **nothing to execute**, and publication happens by hand, outside the machinery, or not at all. `zheref/hatsu` lived in exactly that state: its seat read *"there is no publish step to run … nothing in this repository publishes one"* while a GitHub Release was published by hand at `v0.39.0`. **A declaration that disagrees with the practice is a bug in the declaration.** The seat is retired and the row now runs `scripts/release-publish.sh`.
- **`templates/release-publish.sh` is the engine; `scripts/release-publish.sh` is Hatsu's own rendering of it**, byte-identical and asserted so, which means a consumer receives exactly what this repository dogfoods. The `plugin` lane's `release` row runs it, and the new **`release-guard`** lane runs its **twelve fixtures** — the fifth focused lane, following the one-lane-per-executable-guard pattern the `test` seat names in its own words.
- **What it publishes, and what it refuses to guess.** ONE GitHub Release for a tag that **already resolves on the remote**. It cuts no tag (that is `nen tag cut`, `hatsu:getsuga` § 4), pushes nothing, builds nothing, and attaches only artifacts it is **handed** — so one engine serves a `claude-code-plugin`, where the tag **IS** the distribution and there is no artifact, and a stack that does build one, **without knowing either stack's name**. Notes and title come from the repository's own `CHANGELOG.md`; **it never writes them**.
- **`--tag` is optional, and that is what makes the declared row runnable at all.** `nen shu release` runs the argv with **no arguments of its own**, so a row whose script *required* a tag could never be executed by the verb that exists to execute it. Omitted, the tag is the newest `v*` by version sort, named `(DERIVED)` in every output so nobody infers which tag was chosen.
- **Every refusal fires before anything is sent**, because publication is not idempotent in any way a caller can rely on — a release notifies watchers the moment it exists. An absent tag; a tag missing from the **remote** (a release must not point at a ref nobody can fetch); a tag that **already has a release** (*one go publishes one target once*); a missing `--asset`; a changelog with no section for the tag. **Proved against live data**: run against the existing `v0.39.0` release it refused at exit `1` and left the release untouched.
- **A tag closing a multi-version gap carries every section in it.** `v0.39.0` spans six changelog sections; shipping only the newest would misreport what the tag contains, and there is a fixture for exactly that case.
- **Tenkai derives a repository's ROLE from `nen/repos.json`, and refuses to invent one.** `maintained_tools` is **process/system**, `consumers` is **product**, and a registry naming **neither** reports `blocked` — *"Tenkai does not classify a repository for itself."* The 2026-09-18 ruling already split repositories by role; the registry is that split in machine-readable form, so reading it costs the preamble no third question and avoids scraping the canon list out of `ROSTER.md` prose.
- **For a process repository, Tenkai renders the publisher and ROUTES the row** — with the **exact row offered**, composed from **that repository's own default lane and declared stack** rather than a template's guess. It never hand-writes `nen/contract.json`, which is the rule the `commit-msg` hook taught this skill the hard way one version ago, and **it never overwrites a publisher it did not render**. **A product repository is asserted about in neither direction.**
- Self-test: **118 assertions**, up from 98, including both roles, the unrecorded-role block, the offered row naming the real lane and stack, the foreign-publisher refusal, and template/rendering parity.
- Delivered by [#86](https://github.com/zheref/hatsu/pull/86).

## v0.39.0 — a repository becomes a consumer, deterministically

- **`hatsu:tenkai` — the skill surface is forty-two.** Until now there was **no deterministic way to make a repository a working Hatsu consumer at all**, and the gap was not a missing file. `nen scaffold init` ships *the stack's* CI workflow and knows nothing of `pr-readiness.yml` — correctly, because **nen stays agnostic to the process** and the readiness workflow is a Hatsu artifact. `templates/` held exactly one file (`rikugan.html`). There was a greenfield story and **no path for an existing repository**. Tenkai takes a repository — new or existing, consumer or not — and brings it up to the current system's requirements, **diagnosing before it writes** and reporting per item what was already satisfied, what was missing, what had quietly drifted and what it changed.
- **Idempotence and drift repair are the requirements, not extras.** A repository that adopted at `v0.30.0` and never re-ran Tenkai is the **normal case**. A second `apply` writes nothing and says so; a third is identical to the second. And the state that matters is not *absent* but **`drift` — present and quietly wrong**: a workflow rendered for another repository's slug, a `runs-on` that no longer matches what the repository derives, a trigger set that is missing an event the verdict depends on. Those look installed. `missing` and `drift` are reported as different things, always, because *"it is there"* is not the claim *"it works"*.
- **`scripts/tenkai_adopt.sh` is the engine, in `scripts/hanten_cycle_ledger.sh`'s house shape** — a thin bash wrapper over one embedded `python3` program with a `--self-test` that builds real git fixtures and proves **both directions**: the runner derivation at every input, greenfield adoption, idempotence across three runs, each drift direction detected *and* repaired, `diagnose`'s read-only guarantee, a malformed declaration reported `blocked` rather than silently rewritten, and the two-PR ordering staged rather than hit. **State is written by a script with fixtures, never counted in prose.** Exit `1` means *work remains* and is not a crash; `2` is the invocation defect.
- **Ownership is explicit and never improvised around.** The five `nen/*.json` declarations **and the `commit-msg` hook** are **routed** to `nen scaffold init` with the exact command named — Tenkai asserts only *present and parseable* and never hand-writes one, because a Nen-owned operation is not improvised in a script any more than in prose. `nen/colors.yml`, `Reports/`, `.nen/` and the rendered readiness workflow are Hatsu's to repair. **A workflow Tenkai did not render is reported as drift and left exactly where it is.**
- **The readiness workflow is parameterised, and the failure it prevents is the silent one.** `.github/workflows/pr-readiness.yml` was hard-gated `if: github.repository == 'zheref/hatsu'`. **Copied to any other repository that predicate is false on every event, so the job is skipped — green tick, no job, no signal, forever.** It looks installed and does nothing, and there is no error anywhere to read. `templates/pr-readiness.yml` substitutes the slug at adoption instead, keeping the gate's two-limb shape (this repository **and** a head that is not a fork) so the `pull_request_target` trust boundary is untouched. Every later run re-reads the rendered predicate and reports a foreign slug as drift **naming the consequence** — so a repository that was renamed or transferred is caught by a diagnosis rather than by a signal that quietly stopped arriving. Three further drifts are checked **on the live YAML and never on the comments**: a stale `runs-on`, a **dropped `--gates`** (nen falls back to `<cwd>/nen/gates.json`, and the cwd there is the PR head checkout, so losing the flag hands the pull request the gate that judges it), and any surviving `@@TOKEN@@`.
- **Adversarial review found twenty-one findings across two reviewers, and six were `high`.** `hanten` raised **Feitan** (security) and **Chrollo** (architecture) at the `deep` tier; both returned **divergent ❌** and both were right. Every finding was reproduced on a fixture before it was settled, and the two most serious were defects this change set introduced while claiming to prevent exactly them.
- **The `commit-msg` hook was NEVER Hatsu's to write, and the template is withdrawn.** [`docs/ROSTER.md`](docs/ROSTER.md) § 2 assigns layer (b) of the three-layer attribution enforcement to *"a target repository's `commit-msg` hook, **generated by `nen scaffold init`** from `allowedAttributionTrailers`"* — and `nen scaffold init` installs exactly that, at exactly that path, from exactly that policy file. Shipping a second writer **collided destructively in both orderings**, measured: Tenkai first and `nen scaffold init` refuses (*"a different commit-msg hook already exists … refusing to overwrite it"*); nen first and Tenkai reported the generated hook as foreign drift and advised **deleting** it, so the item could never reach `satisfied` and `apply` could never exit `0`. The item is now **routed**, like every other nen-owned item — which is what the skill's own central rule always said. Removing the template removed three further defects **by deletion rather than by patch**: a write that escaped `--repo` through the git common dir, a followed symlink that created an arbitrary 0755 file, and `core.hooksPath` being ignored so the hook read *"installed and current"* in a directory git never opens.
- **A hostile repository slug could turn the workflow's guard into a constant `true`.** The slug is substituted into a single-quoted GitHub expression, and an `origin` of `https://github.com/acme/widget' || true || '.git` rendered **valid YAML** whose predicate reduces to `A || true || ('' && B)` — because `&&` binds tighter than `||`. **Both limbs die at once**: the same-repository limb *and* the fork limb, on a `pull_request_target` job holding `checks: write` and a token. The template's claim that a wrong slug *"fails CLOSED"* was true of a *wrong* slug and false of a *hostile* one. Slugs are now validated against GitHub's own `owner/name` grammar at one gate covering the derived path, `--slug`, and the `gh api repos/<slug>` call.
- **Drift detection checked five things and none of the security invariants the template says it inherits.** A rendered workflow was mutated with the trust boundary inverted, `persist-credentials` dropped, write scopes added, a PR-controlled `${{ }}` placed inside a `run:` body and `--gates` downgraded to a relative path — and `diagnose` answered `ok`. In a consumer with no policy guard of its own, **this detector is the entire safety net**. All five are now asserted, scoped to the step block that owns them rather than to a character window, with `--gates` matched as a **whole argument** because the repository's own Ruby guard already documents why a substring is not enough.
- **`apply` destroyed a hand-written `pr-readiness.yml`, and rendered `github.repository == 'UNKNOWN'` when no slug resolved.** The first violated the skill's own *"somebody else's hook is somebody else's"* rule, which only one item implemented; the second reintroduced the precise silent-skip failure § 5 exists to prevent — a predicate false on every event, forever — and the `@@TOKEN@@` guard could not see it, because the token *was* substituted, with a guaranteed-false value. Both now refuse before writing.
- **Guard registration was comment-strength, not grep-strength.** A whole-file substring meant `# TODO: someday register pr-readiness.yml` scored as registered — and **this repository's own guard names the file in a comment on line 13**. It now parses `EXPECTED_JOBS`, `EXPECTED_TYPES` and `EXPECTED_STEPS` with comments stripped, and requires all three; `PORTABLE_HOSTED_WORKFLOWS` deliberately does not count, because the routed action tells the maintainer not to add it there yet.
- **An unreadable probe is no longer treated as a changed fact.** The ruling *"unreadable → hosted"* governs **rendering a new file**; reused as the drift **expectation** it meant an offline `apply` reported a correct `self-hosted` as drift and then silently reverted it. When `gh` cannot answer, the runner limb is reported **unchecked** and left alone.
- **A bare `self-hosted` is never rendered.** It is the broadest selector there is — any runner registered to the repository *or its organisation*, non-ephemeral by default, on a job that checks PR-controlled content into its workspace — and this repository's own guard admits only **labelled sets**. The labels are the consumer's data, which Tenkai does not invent: the derivation refuses and names `--runner-labels`.
- **Idempotence failed in the exact "new repository" case the skill advertises.** `git check-ignore` cannot answer in a directory that is not a repository yet, and reading that as *"not ignored"* made `repair` append unconditionally — three `apply` runs produced three copies of `Reports/` and `.nen/`. *Cannot be asked* is now distinct from *not ignored*, and reports `blocked`.
- **`"on":` is accepted.** Bare `on` is the YAML 1.1 boolean `true`, so many repositories quote it deliberately; matching only the bare form reported a correct workflow as declaring **no** triggers — with the consequence sentence asserted confidently about a file that did not have the defect. The child indent is derived rather than assumed, and an `on:` block that cannot be parsed is `blocked` rather than silently read as empty.
- **The read-only proof filtered out the one directory a write could land in.** It compared *names*, and excluded `.git/` — where the hook item wrote. It now compares **content hashes over the whole fixture including `.git/hooks`**, so an in-place rewrite is visible too.
- **Three claimed properties had no fixture, which is the combination that rots quietly** — the tuned-`colors.yml` promise, the guard-comment case, and the non-git and no-slug repositories that are the *"new repository"* half of the skill's own description. All now have one, as do the hostile slug, the foreign workflow, the unread probe, `core.hooksPath`, and the parity of `templates/colors.yml` with this repository's own `nen/colors.yml`. **76 assertions, up from 50.**
- **`scripts/tenkai_adopt.sh` had no focused lane, which the repository's own `test` seat names as the pattern** — *"Executable guards have their own focused lanes"*. The engine's assertions ran only when somebody typed the command: `tsukuyomi` had nothing to route to and no CI job covered it, which is precisely the *"unperformed check read as a clean one"* that seat refuses. **`tenkai-guard` is declared**, the plugin lane's seat now names all three guards, and `nen/workflow.json`'s iteration comment follows. Found while gathering the step 4/5/7 determinations, not by a reviewer.
- **Writes go through a temp file and `os.replace`**, the way `scripts/hanten_cycle_ledger.sh` already writes: a direct write that dies mid-call leaves a **truncated** workflow behind rather than the previous one. Fixtures are removed on every path including a failing assertion, and `self_test` returns an int instead of raising.
- **Tenkai names what a consumer does NOT inherit.** It installs a privileged, credentialed job and installs no policy guard — so a new observation row names every other privileged workflow (`pull_request_target`, `workflow_run`, `issue_comment`, `workflow_call`) and states the enforcement gap. It writes nothing; installing the guard into a consumer is a separate, maintainer-owned change.
- **`## 0` was missing `P5` entirely**, claimed *one* elicitation question where § 1 asks two, and argued its skip condition from *"no composite owns adoption"* instead of carrying the generic clause every other phase carries. All three corrected. The engine is addressed through `$hatsu_root` in both this skill and `hatsu-warmup` § 0a — on an installed surface the working directory is the **consumer**, so a bare `scripts/tenkai_adopt.sh` resolves to nothing, or to a same-named script the target happens to carry — and the read-only verb has one name, `diagnose`, not two.
- **Both reviewers disclosed a capability they could not exercise rather than rendering it clean:** `nen repo scenario` refuses for `zheref/hatsu`, so **no `SEC-{n}` or `UZF-{n}` id was resolvable**, and Feitan found three unpinned security-baseline copies on this host with **two disagreeing by checksum**. Every finding therefore cites this repository's own canon by path, or says *"no pinned id resolvable"* — the same posture #78's reviewers took.
- **Two admitted triggers, required and closed — maintainer's ruling, 2026-09-19, as corrected the same day.** The rendered workflow declares `pull_request_target` (`opened, synchronize, reopened, review_requested, review_request_removed` — the last two are `CON-32(b)` inputs in their own right, since `nen pr ready` distinguishes a round *in flight* from one that is *owed*; no `edited`, because the verdict never reads the body or title) and `pull_request_review` (`submitted, edited, dismissed`). **A missing trigger is a bug and not a simplification**: with `pull_request_target` alone the verdict is computed at **push time, while the checks are still pending, and is never recomputed**, so the `ready` transition — the one moment worth publishing — would essentially never be published. A consumer provisioned with the single-trigger form inherits exactly that, so the engine reports an absent trigger as drift **naming the consequence**.
- **`pull_request_review_thread` was admitted briefly and REMOVED, and this release shipped the error before correcting it.** It exists as a **webhook** event but is **not a supported Actions trigger**, so **a workflow naming it cannot register at all**. An earlier revision of `scripts/tenkai_adopt.sh` *required* it — which meant `apply` would have reported a correct workflow as drift and then rendered one that does not run: **the adoption tool actively breaking the repository it was adopting**. Caught when the branch caught up with `main` and `zheref/hatsu#82` landed. It is now refused as firmly as any other non-admitted event, with a fixture whose only job is to stop it being re-adopted. **`CON-32(d)` therefore has no trigger available at all** — a named limitation, not an oversight — and a check *completing* fires nothing either; the normal push → checks → review flow is covered because the review event is the last input.
- **The engine parses the `on:` block rather than matching a list of known event names.** The first fix intersected the keys it found against a hand-kept allowlist, so an **unrecognised** trigger was silently dropped instead of flagged — the one case worth refusing was the one case it could not see, and the self-test caught it on `pull_request_review_thread` itself. There is no list to fall out of date now.
- **The set is closed in one place** (`ALLOWED_TRIGGERS`) and widening it is a ruling, not a template variation: both admitted events carry `github.event.pull_request`, so one job condition and one `github.event.pull_request.number` work unchanged under a **single** byte-compared same-repository guard even though Tenkai parameterises its slug. **`check_suite` is refused for its own separate reason** — its payload carries only `check_suite.pull_requests[]`, needing a second and weaker guard, and it fires for forks.
- **The two-PR ordering is HANDLED, never hit.** A workflow cannot be registered in the policy guard and added in one pull request: the guard judging a pull request is the **trusted** copy from the base branch, and the PR's own copy never executes, so a PR adding both is judged by a guard that cannot know the file ([#80](https://github.com/zheref/hatsu/pull/80)). Tenkai does not edit Ruby it did not ship — it **detects which half has landed** and stages the workflow until the registration is in, so a consumer inherits the ordering as a sequenced plan. The routed action carries the thing that looks like an oversight and is not: `PORTABLE_HOSTED_WORKFLOWS` must **not** name a file that does not exist yet, because that constant doubles as the required-**presence** list.
- **Runner selection — maintainer's ruling, 2026-09-19 — is derived per repository, never assumed.** The self-hosted preference is right where minutes are genuinely billed and the security calculus differs, and wrong everywhere else. **Public → hosted**: standard runners are free and unlimited there, so there is no bill to avoid, and GitHub advises against self-hosted runners on public repositories because a fork PR can execute code on them. **Private with zero registered runners → hosted**: a preference would queue the job against a runner that never appears, and *a check that never completes is strictly worse than a bill that is currently zero* — if it is ever made required it blocks every merge, permanently. **Private with a runner registered → self-hosted.** **Unreadable visibility → hosted**, because the derivation never guesses toward a runner that might not exist. **Every derivation names a fallback**, so a job can never hang on an absent runner. Measured on `zheref/hatsu` itself — `visibility=public`, `actions/runners` → `total_count: 0` — **both limbs derive hosted, so the ruling changes nothing here today.**
- **`nen/colors.yml` exists at last** ([#79](https://github.com/zheref/hatsu/issues/79)). It had **never existed on any branch** — `git log --all -- nen/colors.yml` returned nothing — while six plugin-shipped surfaces named it at run time. So `nen schema check --repo .` exited `1` on every run (five rows `ok`, one `FAIL`), `nen color status` could not run against this repository at all, and `backlog-state` § 6 and `backlog-board` could not resolve a status colour when the target was this repository. **The aggregate now exits `0` and all six rows pass.** The durable cost this closes is the one #79 named: *a permanently-red check stops being read*, and the next genuine taxonomy failure lands in a row nobody looks at. **Nothing is invented** — every value, glyph, meaning and precedence rank is transcribed from the skill prose that already resolves it, and all five of `backlog-state` § 6's documented rows reproduce byte-identically, tie-breaks and the `unresolved` exit `1` included.
- **`templates/colors.yml` ships the same vocabulary as a consumer seed**, because **nen carries no built-in colour table and no fallback** — deliberately, since a binary that guessed the names would report a taxonomy the repository does not have — so `nen scaffold init` cannot write one either and nothing else can scaffold it. It is a **seed, not a canon file**: once the file parses and declares a `categories` block the item is satisfied, and the engine **never compares it byte-for-byte against the template**, so a repository that tuned its own families keeps them across every re-run.
- **`hatsu-warmup` § 0a — adoption is settled once; the warm-up VERIFIES.** The split is by **question**, not by file: *is `nen` present and does this build satisfy the pin* is per-session and stays fail-closed; *does this repository carry what the skills read* is Tenkai's, once. An outstanding adoption item is **reported and is never a halt** — § 3's halt is for a failed bootstrap and nothing else, because a repository missing `Reports/` can still be worked in and a session that refused to start over it would have converted a finding into an outage. Neither skill gains an authority; the warm-up gives up work it should never have carried per session.
- **`docs/GATE-CONFIGURATION.md` — the consumer-facing gate page.** The mechanism was always good: `nen/gates.json` is JSON, validated by `nen schema check`, failing **by pointer**, and the readiness workflow passes only `--gates`, so a consumer tunes one file and the workflow follows with no workflow edit. **What was missing was the page** — `approval_policy` appeared only as a record of the 2026-09-12 ruling *for Hatsu and Nen*, and `dependabot_carve_out` only in an `ab/` transcript and a `$comment`. The usual outcome was that the file was copied from here and **`zheref/hatsu`'s ruling about its own reviewers silently became somebody else's policy**. The page covers every key, what it costs when it is wrong, and why the workflow's `--gates` points at the **trusted** copy — so a gate edit takes effect once **merged**, not while it sits in the pull request proposing it.
- **`hatsu-warmup`'s contract-row quotation was stale and is corrected** — it quoted `2 lanes … 11 verbs` against a repository that reports `3 lanes … 12 verbs`. Pre-existing, and fixed under that section's own stated rule: *a drift between them and this file's prose is a bug in the prose.*
- **Two things deliberately NOT done here, and named rather than smuggled in.** `scripts/workflow_runner_policy_check.rb` is **untouched**: both [#78](https://github.com/zheref/hatsu/pull/78) and [#80](https://github.com/zheref/hatsu/pull/80) are open against that exact file, and generalising its frozen `HOSTED_RUNNER` mandate to consume the new derivation is a separate change that must land after #80. And `docs/WORKFLOW.md`'s *"remain explicitly pending"* line is **left as it stands** — read in context it is about [Nen #207](https://github.com/zheref/nen/issues/207)'s test-selection capability, which is still pending, not about consumer adoption; a new *Consumer adoption* section is added rather than that sentence rewritten to mean something it never said.
CON-33(c) PRs merged since `v0.32.0` that were not yet numbered in this file, numeric order. Each already has its prose above or in its own version section; this block supplies the numbering `nen changelog completeness` reconciles against, and nothing is restated or superseded.

- ([#71](https://github.com/zheref/hatsu/pull/71)) standalone entry — every skill reachable from a cold checkout (`v0.33.0`)
- ([#75](https://github.com/zheref/hatsu/pull/75)) a tag records a build that landed (`v0.36.0`)
- ([#76](https://github.com/zheref/hatsu/pull/76)) how to re-request a bot reviewer (`v0.35.0`)
- ([#82](https://github.com/zheref/hatsu/pull/82)) correct the admitted trigger set and trusted refs — machinery only, no plugin surface, so it carried no version of its own
- ([#83](https://github.com/zheref/hatsu/pull/83)) make a repository a Hatsu consumer, idempotently (`v0.39.0`)
- ([#84](https://github.com/zheref/hatsu/pull/84)) this release PR (CON-33(c) numbering for the `v0.39.0` tag)

## v0.38.0 — the readiness verdict is published where a human can see it

> **`v0.37.0` was taken by [#77](https://github.com/zheref/hatsu/pull/77), now merged** — the two branches were in flight together and could not claim one bump. As `v0.36.0`'s note records, `scripts/plugin_bump_check.sh`'s `version_bumped` asks only whether HEAD's `version` DIFFERS from base's, never whether it is HIGHER, so ordering is still coordinated by hand and **a guard rejecting a non-increasing bump is still owed**.

- **New `.github/workflows/pr-readiness.yml`**: a deterministic `pull_request_target` job that runs `nen pr ready --explain` on every event that can change the answer and publishes the verb's own output as the **`readiness` check run**. The computation was never the gap — `nen pr ready` already evaluates `CON-42/1`, `CON-32(a)`, `CON-32(b)`, `CON-32(b)`/`CON-16` and `CON-32(d)` — the gap was that the verdict only ever existed in a session's terminal or a `rikugan` report, so a PR that reached its gate after the session ended told nobody. **`zheref/hatsu` only**: the job is gated to this repository and is scaffolded to no consumer.
- **It supplies persistence, not notification.** The verdict can be read on the pull request without a session. Nobody is pushed anything — the conclusion is always `success` and Actions notifications fire on failure — so *being told* remains unsupplied and is named rather than claimed.
- **Not a label, and not a title.** A label needs `pull-requests: write`, and `scripts/workflow_runner_policy_check.rb` refuses any write grant other than `checks: write` — widening that is a `G4` ruling about the CI trust boundary. The title is authored content: `shibari` composes it as a Conventional-Commits subject that becomes the squash-merge subject `nen commit format` validates, so a machine rewriting it corrupts the history the repository derives from it, and every push re-owes every reviewer round, so it would churn constantly.
- **The conclusion is always `success`, and the check is created already green.** The operative rule is `nen pr ready`'s `CON-32(a)` conjunct **as implemented** — every *reported* check green on its latest run per name — not `CONSTITUTION.md`'s `CON-32(a)` text, which says every *required* check. That divergence predates this change and is a `G4` ruling this change does not settle; it is cited here as what actually runs. A `failure` conclusion would make the gate permanently unsatisfiable, and an `in_progress` check would do the same: `conclusion: null` is outside nen's accepted set. **`--exclude-run` alone is not sufficient** — verified live on `#75`, an API-created check run is attached to an arbitrary `github-actions` suite for the SHA, so the exclusion can miss this job's own check. Creating it `completed`/`success` removes the window; `--exclude-run` stays as defence in depth.
- **The refusals are unchanged.** `shibari` § 7 gives the reason a gate label was always refused — *"Applying a gate label is a claim about readiness, and readiness is … decided by `nen pr ready`"* — which names an **oracle**, not a silence. `shibari` § 7 and `en` § 9 record that reasoning. **No refusal line was reweakened**: an earlier draft qualified five of them with "itself" / "of its own" and that was reverted, because the workflow applies no label at all, so no refusal was ever in tension with it — and inside `en`'s *Not permitted* enumeration, which grants it everything its composed skills may do, the qualifier would have permitted a gate label applied by `sharingan` inside `en`.
- **The policy guard gains two assertions, both with negative fixtures.** The trusted-pin check is generalised from one hardcoded basename and a positional index to the step's declared name, so every workflow that bootstraps an executable is held to sourcing its pin from trusted data; and `pr-readiness.yml`'s `--gates "$PWD/.trusted/nen/gates.json"` is asserted, because nen falls back to `<cwd>/nen/gates.json` and the cwd is the PR head checkout — a dropped flag would hand the PR the gate that judges it.
- Hardening inherited from `plugin-bump-check.yml` unchanged: guard code and the nen pin come from the trusted workflow revision, both checkouts set `persist-credentials: false`, same-repository only, and the pinned ref reaches the shell through `env` rather than a `${{ }}` expansion inside a `run:` block. The `$GITHUB_OUTPUT` heredoc uses a **random per-run delimiter** and the verb's output is bracketed by `::stop-commands::` with a nonce, because nen interpolates PR-derived strings — reported check names, reviewer logins — into its failure lines.
- **Two triggers, and the third was withdrawn.** `pull_request_target` alone computes the verdict at push time — while checks are still pending — and never recomputes it, so the `ready` transition is essentially never published. The workflow also runs on `pull_request_review` (submitted, edited, dismissed), and `pull_request_target` gains `review_requested` / `review_request_removed`, which are `CON-32(b)` inputs in their own right since the gate distinguishes a round *in flight* from one *owed*. **`pull_request_review_thread` was tried and removed**: it is a webhook event, not an Actions trigger, so a workflow naming it cannot register — confirmed against GitHub's event reference. **`CON-32(d)` therefore has no trigger available at all**, and its staleness is a named limitation rather than an oversight. The set stays closed and frozen per workflow; widening `ALLOWED_TRIGGERS` again is a ruling, not an edit.
- **The trusted checkout is the base SHA, not `github.sha`** — and the guard now decides that from the trigger set. On `pull_request_target`, `github.sha` is the last commit on the default branch; on `pull_request_review` it is the last **merge commit on the PR branch**, which is PR-controlled. Checking that out would have loaded the policy guard, the dependency pin and the gates file *from the pull request* and then run them with `GH_TOKEN` — the trust boundary exactly inverted. A workflow subscribing to a review event may now only check out `github.event.pull_request.base.sha`.
- **`actions: read` is required, not defensive.** `nen pr ready` follows the rollup's own `checkSuite.workflowRun` sub-field and `checks:read` does not reach it; without the grant the verb answers `unevaluated: the check rollup could not be read`, which this job would publish as a green-but-undetermined check.
- **A verdict is confirmed against the head it describes before it is published.** `nen pr ready` takes a PR number and reads the *live* head, while the check run is created against the event's head SHA. Cancellation is not atomic, so an in-flight older run could publish a verdict about a newer tree onto the older SHA's check. The run now re-reads the live head and publishes `superseded` instead.
- **The check is created AFTER the verdict, not before it** — and that ordering is a soundness fix, not tidiness. Creating it already-green was the answer to a *self-block*; but a green check is a **reported** green check, and `CON-32(a)` passes on a non-empty all-green rollup while **failing** on an empty one. On a pull request with no other checks, the gate would have read `ready` *because of this check's own existence* — a false READY, the worst failure this signal has. Latent here, where two other checks always report; **not** latent for a consumer that has none. `CHECK_CREATION` declares the ordering per workflow, and the final step still runs under `always()` so a failed earlier step publishes an honest `undetermined`.
- **Known limitation, stated rather than discovered later: a *prior* run's check is still a reported check.** Creating the check after the verdict removes *this* run's self-reference, but on a later event the previous `readiness` entry is in the rollup and `--exclude-run` drops only the current run. Where `readiness` is the only check that ever reports, the second and later events would read `ready` on its own prior verdict — a false READY. **Not reachable in `zheref/hatsu`**, where two required checks always report; reachable in a consumer that has none. `nen pr ready` has no name-based exclusion, so the fix is a nen dependency tracked in #81, and **the workflow must not be scaffolded into a repository whose only reporting check would be this one** until it exists.
- **A required argument must ride on the invocation**, not merely appear in the step. `echo --gates "$PWD/.trusted/nen/gates.json"` satisfied a substring test while the real call omitted the flag — and nen then falls back to `<cwd>/nen/gates.json`, the PR's own copy. Continuation lines are joined into logical commands first, and diagnostics cannot count as the invocation.
- **A step may not change the working directory.** Every trusted-path assertion is lexical and relative, so a `cd` into a PR-controlled directory — or a fabricated `.trusted/` — would satisfy all of them while reading PR-supplied data. None of these workflows needs `cd`, so it is refused outright rather than modelled.
- **The check is advisory; the file is not.** It is in no ruleset and must not be made required. But `PORTABLE_HOSTED_WORKFLOWS` doubles as the required-presence list and that guard runs inside a required check, so deleting or reshaping the file fails a required check even though the check it publishes never can.

## v0.37.0 — G4 is the repository's role, not the file's kind

- **Maintainer's ruling, 2026-09-18 — `G4` (`CON-7`) is *authoring or maintaining a canon repository*.** The canon is `zheref/hatsu`, `zheref/nen`, `zheref/bankai-core`, `zheref/akatsuki-ai` and `zheref/bankai-scaffold`: repositories whose product *is* the process — a mix of prose, scripts and deterministic jobs — so a merge there decides how every other repository behaves. **Everything else is `G2` (`CON-5`)**, including a consumer repository declaring its own `nen/contract.json`, `nen/workflow.json`, `nen/gates.json`, adding a CI workflow or a `scripts/` entry: that is *configuration of how the system is set up there*, and it governs nothing but that repository. The test is one question — **would merging this change what a DIFFERENT repository does?**
- **The incident, recorded rather than only corrected.** In `zheref/zheref.io`, a consumer repository, `hatsu:mukai` ran on a résumé PR whose diff touched `nen/contract.json`, `nen/gates.json`, `.github/workflows/pr.yml`, `scripts/` and `docs/`. It derived **`G4`** and reported it in the PR body, a landing report and two `nen stop` banners; the maintainer corrected it to **`G2`** (fixed there at `a2bce25` and in [zheref/zheref.io#22](https://github.com/zheref/zheref.io/pull/22)). The misreading was defensible, which is why the text moved: the gate table's `G4` row said *"Policy / spec change"* and named no repository, and the Transmuter row listed *"workflows, generators, plugin manifests, contract files"* and named none either. Read literally, a consumer's own `pr.yml` is a workflow and its `nen/contract.json` is a contract file.
- **`docs/ROSTER.md` § *Rulings of 2026-09-18 — G4 is the repository's role, not the file's kind* is the record** — the ruling in the maintainer's own words, the incident, the three canon repositories, the measured invocations, and what changed in the skills. The gate table's `G4` row, the **Conjurer** row and the **Transmuter** row now carry the repository-role qualifier and point at it; `README.md`'s gate table and `docs/STANDALONE-ENTRY.md` § *the gates* carry it too, and `docs/WORKFLOW.md` gains *Which gate a change stands at* so the document that defines the phases reconciles with the one that defines the gates.
- **The defect was in the callers, never in `nen gate derive`.** The verb already states the ruling in its own `--help`: `--process-paths` derives `G4` *"in a repository whose product is its process"*, and *"There are no built-in path sets. They are the target repository's canon, and a binary carrying one repository's sets would derive that repository's gates everywhere it was pointed."* The skills passed `zheref/hatsu`'s own canon-shaped sets to every repository as a literal.
- **Four callers now select the path set by repository role first** — `sharingan`, `backlog-state`, `shibari` and `tensho` — with `backlog-board` and `hanten` carrying the same note where each reaches for a path set. **In a consumer repository the gate is not derived by path at all: it is `G2` by role and the verb is not called.** Measured at nen `0.10.0`: the `zheref.io` set derives `G4` through `nen/`; dropping `nen/` still derives `G4` through `.github/workflows/`, `docs/` and `scripts/`; and `--policy-paths "" --process-paths ""` is **refused at exit 1** — *"no path sets were given, so every diff would derive G2 — including a policy change … state them explicitly"*. That refusal is the answer: the verb splits a canon repository's own surface, and a consumer has none to split.
- **The DECLARATION-PR gate moves with repository role too, and that is a second class of edit.** Writing a `project` block, a `project.launch` target, a `tags.deploy` block or a `nen/workflow.json` for a repository lands at **G4** in a canon repository and **G2** in a consumer one. Eleven skills carried the unqualified reading: four passed the canon path set to `nen gate derive` (`sharingan`, `backlog-state`, `shibari`, `tensho`, with `backlog-board` and `hanten` noting it), and **seven more asserted `G4` for a declaration change in whatever repository they were pointed at** — `rasengan`, `breath`, `byakugan`, `kotoamatsukami`, `susanoo`, `mugetsu`, `kagutsuchi` — which run against consumer checkouts by design. `claude/commands/kurapika.md`, `claude/agents/gon.md`, `claude/skills/build` and `claude/skills/jujutsu` carry it as well.
- **`zheref/bankai-core`, not `zheref/bankai`.** The ruling was spoken as *bankai*; `zheref/bankai` resolves on GitHub to **`zheref/Bankai`, a public Swift PRODUCT repository** (a consumer), while the Bankai canon — `CONSTITUTION.md`, `agents/`, `claude/` — is the private **`zheref/bankai-core`**. One keystroke apart, and the gate now turns on which was named, so the long name is written out everywhere.
- **Maintainer's ruling, 2026-09-19 — the canon is FIVE repositories, not three.** `zheref/akatsuki-ai` and `zheref/bankai-scaffold` join `zheref/hatsu`, `zheref/nen` and `zheref/bankai-core`. The first draft of the ruling named three and recorded that the one-question test answered *yes* for the CI plane while the enumeration answered *no*; the maintainer resolved that by ruling **the test right and the list short**. `zheref/akatsuki-ai` is the autonomous CI plane — `CONSTITUTION.md`, `agents/`, `canon/`, `bootstrap/`, and workflows that run against other repositories. **The trailer rule is untouched**: `Akatsuki-Agent:` is still written only by an Akatsuki roster agent and a Hatsu persona still refuses it — being canon decides which gate a change to it stands at, not who may sign a commit.
- **`zheref/bankai-scaffold` sharpens the rule rather than just extending it.** It carries **no constitution prose at all** — it is a TypeScript package (`source/`, `scripts/`, `package.json`) — and it is canon because **a scaffolder writes the setup into every repository it touches**, so merging a change there changes what other repositories do. That is the test answered by what the code *does*, not by what kind of files the repository holds, and the ruling's own words already allowed for it: *"a mix of prose, scripts, and deterministic work jobs."* **So canon is not "the repositories that carry a constitution"** — it is the repositories whose product is the process, however they express it.
- **One thing this ruling does NOT decide, recorded as open rather than answered.** A consumer repository that declares a policy surface of its **own** (its product's spec, not its copy of this system's setup) is unruled — until it is, the gate is `G2` and a genuine-looking exception is a `G5`. (The other open item — `zheref/akatsuki-ai`'s absence from the list — was **closed on 2026-09-19** by the ruling above.)
- **No change is owed by `zheref/nen`**, and none by `zheref/bankai-core`: a `--repo-role canon|consumer` flag would be exactly the built-in path set nen's help text refuses to carry, and bankai's `CON-7` is already scoped to its own `CONSTITUTION.md`/`handbooks/`/`agents/`/`schemas/`.
- **`hanten` was listed as a `gate derive` caller and is not one** — it explains that no verb classifies a change set by scope and reads its own map off `git diff --name-only`. Its residue § 4 now says that the `G4` it measured holds *because the target was a canon repository*, so a reader who does reach for those sets does not carry them into a repository they do not govern.
- Six dated A/B records — `docs/ab/{tensho,shibari,backlog-state,drive,hanten,backlog-board}.md` — keep every transcript verbatim and gain a note reading their `G4`s as *the reference repository answering about itself*, per the records' own dated-note convention.
- **`nen/gates.json` audited and left FUNCTIONALLY unchanged — only its `$comment` gains the measurement — because the file is valid.** The reported defect does not reproduce at nen `0.10.0`: `nen schema check --repo .` reports `ok`, and `nen pr ready 76 --gh-repo zheref/hatsu` evaluates normally. The empty `default_approvers` is **deliberate and legal**, and `approval_policy: "review-round-only"` is the key that makes it so — **not inert**. Delete that key and the loader refuses with the quoted *"An empty approval set makes the approve limb of the readiness gate VACUOUSLY TRUE"*; set it to anything else and it refuses by enum. A `grep` finding no consumer for `review-round-only` means the `zheref/nen` checkout searched predates the feature — it landed in nen `0.10.0` (nen #209, PR #210), which is why `nen/contract.json` raises `minimum` to `0.10`. The file's `$comment` now carries that measurement so the question is not re-opened.

## v0.36.0 — a tag records a build that landed

> **This was `v0.34.0` until `v0.35.0` merged first.** The bump is `v0.36.0` because `main` is already at `v0.35.0`, and `scripts/plugin_bump_check.sh`'s `version_bumped` asks only whether HEAD's `version` DIFFERS from base's — never whether it is HIGHER — so landing `v0.34.0` on top would have shipped a manifest downgrade past a green check. Copilot caught the ordering hazard on `#76`; this is the re-bump that answer prescribed, carried out rather than assumed. **A guard rejecting a non-increasing bump is still owed** and wants its own issue.

- **`kagutsuchi` § 4a cuts the tag**, after a `--run` send that returned exit `0`, from `nen/workflow.json` → `tags.deploy.<target>`. One artifact that reached a destination is one tag.
- **`susanoo` § 5a cuts nothing.** It reads `tags.identity` and *names* the identity the coming tag will carry, in one line of its report. Its standing property — *nothing leaves this machine* — is literal again.
- The symmetry, in the maintainer's own terms: **an upload that succeeds becomes a tag, and a release Apple approves becomes a GitHub release.** A build that was never sent has nothing to point at, and a permanent public ref for one was the defect in the first shape of this ruling.
- **ONE name source, shared.** `tags.identity.nameFrom` holds the tag's IDENTITY (`v1.0.0+1217`); susanoo announces it and kagutsuchi cuts `dist/<target>/<identity>` from the SAME file, composing the species prefix from the target it was actually called with. An earlier shape gave each skill its own `nameFrom`, so a repository could announce one name and push another — and in the reference consumer it did.
- **`tags.deploy.<target>` is read before anything is cut**, so a repository declaring only `tags.identity` gets no tag at all and an undeclared target is reported `not declared for this target`. The target itself is data — quoted into a variable, passed as an argument — and the species prefix is *composed* from it rather than pattern-checked.
- **The identity file carries the build commit on line 2, and the tag is cut there, not at `HEAD`.** The announce and the cut are separate invocations with a human decision between them; a tag at `HEAD` would name a commit the archive never saw.
- **Opt-in per consuming repository**, off by default. A repository declaring neither behaves exactly as before.
- **The name is the repository's**, read from a declared `nameFrom` as **data**: never templated into shell source (`$(…)` inside double quotes is command substitution), symlinks refused rather than followed, out-of-tree paths refused, empty first line refused, and validated with `git check-ref-format` before anything is spawned.
- **A species prefix is mandatory** (`dist/<target>/`). The tag shares one namespace on `origin` with `getsuga`'s release tag, and `mugetsu` proves a release tag by its name resolving there — an unprefixed tag could permanently take a version nothing may delete. `mugetsu` § 3 now says in rule that only `getsuga`'s release tag satisfies its precondition.
- **The ancestor rule is stated correctly**: `--at` is refused unless that COMMIT is an ancestor of `origin/<trunk>` — not a rule about branches, since a feature branch at the trunk's tip tags fine. What keeps a tag from attesting the wrong bytes is the **clean-tree** condition. `--trunk` comes from `branch.base`, never defaulted.
- **The non-atomic push has one sanctioned remedy.** A rejected push leaves the name taken locally and absent on `origin`, which the verb then refuses forever; a local tag of that name, at that SHA, verified absent from `origin`, may be deleted and re-cut — the completion of an unfinished cut, not a re-tag.
- Recorded as **Rulings of 2026-09-18, corrected 2026-09-19** in `docs/ROSTER.md`.

## v0.35.0 — a bot reviewer is a different route

> **`v0.34.0` is the tag ruling**, on `opus/kurapika/tag-authority`, still open. This change is independent of it and takes the next version deliberately so the two bumps do not collide. **The order is not free, and an earlier draft of this line said it was.** `scripts/plugin_bump_check.sh`'s `version_bumped` asks only whether HEAD's `version` DIFFERS from base's, never whether it is HIGHER, so it would pass `v0.34.0` landing on a `main` already at `v0.35.0` — shipping a manifest downgrade with a green check. **So: `#75` merges first, or it is re-bumped to `v0.36.0` before it does.** A guard that rejects a non-increasing bump is worth its own issue; until it exists this is coordinated by hand.

- **`sharingan` records how to re-request a Bot reviewer**, and why the obvious attempts fail. Copilot is a `Bot`, not a `User`: `gh pr edit --add-reviewer` silently never resolves one (`zheref/nen#160`), REST `requested_reviewers` answers `422 may only be requested from collaborators` for a login missing its exact `[bot]` suffix, and GraphQL `requestReviews` resolves `userIds` as Users only.
- **`nen pr request-reviews` already routes correctly** — a bare login the PR knows as a Bot goes to the bot mutation, and `--add-bots <node id>` covers one it has never seen. The gap was that nothing said so.
- **Verification is the other half.** REST's `requested_reviewers` lists users and teams only, so a *pending* bot request reads as `[]` — a caller checking there confirms the opposite of the truth. `nen pr ready`'s phrasings are the signal: *no round at head* (a request is owed) versus *review requested, not yet posted* (one is in flight; wait).
- **Requesting an owed round is not an escalation.** Taking it to the maintainer spends § 6's ladder on a step the run can perform itself — which is what prompted this: a session concluded the re-request was impossible on the maintainer's own credentials and handed it back as a gate.


## v0.33.0 — standalone entry: every skill reachable from a cold checkout

- New authority `docs/STANDALONE-ENTRY.md`: the cold-start preamble (P1 warm up, P2 orient, P3 establish the delta, P4 elicit, P5 declare), the four inherited-state classes S1–S4, the per-surface option-picker matrix, and the two rules — every skill is reachable alone, and **no skill is ever indefinitely independent**.
- **Twenty skills gain a `## 0. Standalone entry` section**, in two groups. Thirteen derive state cold (S1–S4): `breath`, `kokusen`, `tsukuyomi`, `amaterasu`, `kotoamatsukami`, `byakugan`, `sharingan`, `hanten`, `rikugan`, `kagutsuchi`, `mugetsu`, `third-hand`, `murasaki`. Seven add P1, orientation and expectations only: `gyo`, `ao`, `susanoo`, `aka`, `jutaisho`, `shibari`, `rasengan`. `docs/STANDALONE-ENTRY.md` § 7 is the authority and lists both.
- The delta default is the **fetched `origin/<branch.base>`** — the remote trunk, never the local ref — and it is the union of the committed and uncommitted change sets. `against <base>` overrides it everywhere.
- Breath inverts its new-effort default when typed by hand: work in progress on the current branch **is** the continuation signal, so a cold warm-up over an IDE session no longer cuts past it.
- Tsukuyomi derives `--lane` from the delta instead of refusing, and where no declared focused route covers the change it **offers to have the tests authored** (by `rasengan`) rather than ending the run.
- Hanten **enforces `breath`** when the `.nen/hanten/<branch-slug>.cycle.json` ledger is absent, and asks for the review scope when the delta does not classify cleanly — it never raises the full bench to be safe.
- Sharingan resolves `#<PR>` from the current branch when it is omitted; none / several are stop-or-ask, never a guess.
- `kagutsuchi` and `mugetsu` gain orientation and **no authority**: `G3` is unmoved, the go is still the maintainer's own recorded words, and the invocation is never the go.
- `murasaki` typed alone does its own step 1 and finishes it: fetch, catch the branch up with `origin/<branch.base>` through `ao`, resolve the mechanical conflicts, stop at **G5** on a semantic one, run the shared checks over the caught-up tree. It declines only what was never its — no tests, no coverage, no squash, no force-push, no first-publish, no PR — and does not push where the catch-up invalidated evidence.
- **Maintainer's ruling, 2026-09-18 — the base is the LATEST trunk.** `git fetch origin` runs first and the base is `origin/<branch.base>`; the local ref is used only where that fetch has just proved it equal. A fetch that cannot run is a stop, because *latest* is a claim only the fetch establishes.
- **Maintainer's ruling, 2026-09-18 — `against <base>` is the delta clause, and it is now declared.** `kokusen`, `tsukuyomi`, `kotoamatsukami`, `rikugan` and `hanten` gain it in their own grammars beside `byakugan`, verified live at nen `0.10.0` including the two-clause (`on [<lane>] against [<base>]`) and enum-plus-base (`for [<scope>] against [<base>]`) shapes. `ao` and `murasaki` keep `from <base>`: a delta is read *against* a reference, a catch-up pulls *from* a source, and unifying them would make one inaccurate. No skill documents a clause `nen parse` would refuse.
- **Maintainer's ruling, 2026-09-18 — breath runs at most once per session, and is never skipped when owed.** A second run in one session reports and returns instead of refusing on a branch name that already exists. The guard is the session's own record, not a file: a later session re-enters and reads the checkout.
- **Maintainer's ruling, 2026-09-18 — breath guarantees an outcome, not just a verdict.** However the checkout looked when it was called, a standalone run ends as *a branch off a `main` that was proven green, carrying the maintainer's own commits on that proven tip, with their uncommitted changes still present and still uncommitted*. Four steps: **preserve** (`git stash push --include-untracked`, SHA captured and printed, addressed by SHA and never `stash@{0}`), **prove** (every `iteration.checks` entry against `origin/<branch.base>` in an isolated worktree, holding none of the effort), **place** (the commits replayed onto the proven tip through `ao` — rebase when nothing is published, **merge when something is**, because a published commit is never rewritten), **restore** (the stash reapplied, still uncommitted; never dropped on a failure).
- **The win: a red after the restore is the effort's, mechanically.** The base was proven on a tree that held none of the work, so attribution stops being a judgement call — which retires the cost the earlier § 0c ruling had to accept, that a late red could not be told apart from a pre-existing one. A red base is a G5 taken *before* anything returns, with the stash restored first — breath never leaves the maintainer stashed at a stop.
- Rewriting a commit is confirmed before it happens, with the counts in the question; stash-and-restore is not, because it is reversible and ends at the same tree. A checkout on the trunk has nothing to rewrite and is not asked at all.
- **Hanten § 0a no longer asks its own ledger question** — it routes to breath, breath's only writer, and reports a lost ledger when one is still absent afterwards. Two skills asking the same question in one run is how a maintainer learns to click past both.
- A `git fetch` that fails, an absent `origin`, or an unresolvable `origin/<branch.base>` **stops** and names the condition; `(fetched <sha>)` is never printed for a fetch that did not run.
- `docs/STANDALONE-ENTRY.md` is added to `scripts/plugin_bump_check.sh`'s guarded surface and to the *Shared policy location* preamble, which now ships in every skill that links it — a runtime-read authority that no bump guard covered would have shipped edits to nobody.
- The skip condition is generic on both sides: every phase says *reached from ANY composite, skip this section*, and all ten composites that call one carry the clause — a phase carrying a list of its callers is the list that goes stale.
- `ren`, `mukai` and `en` state that the phases they call skip `## 0` entirely, so a wired run derives nothing twice.
- Every standalone run ends with a **hand-back line** naming its successor, and never offers to run the five phases that are the maintainer's alone.

## v0.32.0 — plugin updater isolation, focused lane, and refuse paths

- `scripts/hatsu_plugin_update.sh` unsets `GIT_DIR` / `GIT_WORK_TREE` (and related git redirectors) after the filesystem identity check, so `git -C --root` cannot mutate a different checkout.
- A nested Hatsu tree without its own `.git` is not treated as the enclosing repository: `rev-parse --show-toplevel` must match `--root`.
- Stable tags are strict `vX.Y.Z` (digits and dots only); `--auto` will not treat `v1.2.3.4` as a release consumer.
- `--channel release` with no stable `vX.Y.Z` tags refuses instead of silent exit 1; a missing origin and unreadable `.git` are named skip/refuse paths.
- Warm-up cites `$hatsu_root` for updater fixture and SURFACES paths so nested Antigravity mirrors do not get a broken `../../../` link.
- Focused `plugin-update` lane declares the updater fixture; `plugin-bump-guard` asserts the updater glob.
- Landed as ([#68](https://github.com/zheref/hatsu/pull/68)).

CON-33(c) PRs merged since `v0.14.0` that were not yet numbered in this file, numeric order. Net: [#68](https://github.com/zheref/hatsu/pull/68) is numbered by the landing bullet above; it is omitted here so it is not listed twice.

- ([#58](https://github.com/zheref/hatsu/pull/58)) keep Mukai active through PR readiness
- ([#59](https://github.com/zheref/hatsu/pull/59)) run portable checks on hosted Linux
- ([#61](https://github.com/zheref/hatsu/pull/61)) Antigravity surface support, hooks, and model policy
- ([#62](https://github.com/zheref/hatsu/pull/62)) split tests, coverage and lint across mukai and ren
- ([#64](https://github.com/zheref/hatsu/pull/64)) Netero, Hanten cycle caps, and Third-Hand after En
- ([#70](https://github.com/zheref/hatsu/pull/70)) this release PR (CON-33(c) numbering for the v0.32.0 tag)

## v0.31.0 — plugin source auto-update across surfaces

- Warm-up keeps a consumer plugin checkout current before it refreshes a target: `scripts/hatsu_plugin_update.sh --auto` fast-forwards trunk or the newest `vX.Y.Z` tag, skips dirty and authoring trees, and never discards.
- Claude Code's versioned cache is not a git checkout; the same script names `claude plugin update hatsu@hatsu`, and warm-up passes `--claude` there.
- Documented per-surface update recipes and how to point each surface at a local checkout so Cursor does not bind a stale Claude plugin cache while authoring this tree.

## v0.30.0 — Hanten cycle ledger fail-closed

- Cycle ledger `init` is Breath's after the branch cut. `decide` / `record` / `show` refuse a missing file instead of treating absence as a new cycle.
- Load-mutate-save is serialized with an exclusive lock and a unique temp path.
- `skipped-exhausted` is refused while `used < max`.
- G5 blocker owner list includes kokusen; first finding separator is sibling-based; blocker captures use the same data-URI rule as evidence.

## v0.29.0 — Illumi Codex spawn; generated inventory

- Illumi's En observation hand-off uses Codex in-session spawn; Hanten's reviewer isolation stays a second `codex exec`.
- Generated surface inventories: 41 skill files (forty plus warmup) and 9 personas.

## v0.28.0 — Third-Hand is a phase after En; Codex and Antigravity pickers

- **Third-Hand** is a separate phase that starts once En has completed. En ends at the gate and does not harvest.
- Codex asks through `request_user_input` (never lettered options) and raises Netero in-session (`spawn_agent`). Antigravity asks through `ask_question` (`is_multi_select: true`) and raises Netero with `invoke_subagent` `Workspace: "inherit"`.

## v0.27.0 — Third-Hand closes the sitting with Netero's harvest

- Added **third-hand**: after En's retained final report, Netero runs in parallel, folds this sitting's process friction into 0–3 issues, the maintainer picks which to file through the surface picker, those are filed, then the session is over. He never implements the filed work. The merge stays a human G2 act with no skill.

## v0.26.0 — cap Hanten reviewer reruns per effort

- **Hanten** records each reviewer invocation in `.nen/hanten/<branch-slug>.cycle.json` for the whole effort. Applicability and remaining budget are separate questions; an exhausted reviewer is skipped, not invoked. Maxima: Feitan 1, Chrollo 1, Phinks 1, Hisoka 2, Uvogin 3. Remediation, a resumed session, and a later Ren or Mukai re-entry reuse the same counts. Only Breath cutting a new branch resets them ([#63](https://github.com/zheref/hatsu/issues/63)).

## v0.25.0 — Netero; Breath cuts a new branch; G5 reports explain the stop

- Ratified **Netero** as process chairman: he observes Hunter execution and files complete, labelled issues when constitution, canon, or machinery need enhancement, with cross-references for deployment, fan-out and provisioning (roster ruling 2026-09-14).
- **Breath** and **Ren** treat a new request as a new effort: fetch the configured base and cut a freshly rendered branch even from a clean unrelated feature branch. An existing branch is reused only for an explicit continuation ([#60](https://github.com/zheref/hatsu/issues/60)).
- **G5 stop reports** carry a `blocker` payload on the Rikugan `turn` page — step, rule, expected versus actual, this-run visual evidence — and Jutaisho verifies that content before the stop handoff links it ([#56](https://github.com/zheref/hatsu/issues/56)).

## v0.24.0 — byakugan owns coverage; kotoamatsukami owns tests

- Added **byakugan** for coverage capture and measurement at mukai, independent of unit, UI and integration testing. Grammar `against [<base>]`. Never runs `test` or `ui-test`.
- Restored **kotoamatsukami** to tests only (plus UI evidence). Mukai still runs tests then coverage, as two skills.
- Left **gyo** as linting on every Ren turn.

## v0.23.0 — gyo is linting; kotoamatsukami owns coverage

- Renamed **gyo** to the linting process (`nen shu lint`) on every Ren turn: breath on the tip, rasengan may, kokusen must, aka before squash and after catch-up.
- Folded coverage capture, extraction, banding and the under-minimum G5 onto **kotoamatsukami**, still at mukai, still after the impacted suites. Behaviors did not move; the names did.

## v0.22.0 — rikugan session archive vs last-turn board

- Kept **00 This last turn** as the last human request only.
- Required **01–07** (accomplished, challenges, not delivered, architecture, screenshots, launch, decisions) to cover the whole session against the base, on every process or product effort. A later turn that rewrites those lists from only the latest request is a defective page.

## v0.21.0 — rikugan last-turn highlights and structural architecture delta

- Opened every Rikugan page with **00 This last turn**: highlights against the last human request (`done` / `not-done` / `partial`). A mukai-triggered page also names what was corrected (who asked, why, handled or pushed back), local checks that brought work back, and any half-run stop with the policy and how later iterations can go further unattended.
- Made **04 Architecture delta** a change-highlighted board of conceptual nodes and relations. `files[]` remains a supporting path inventory, not the glance target.

## v0.20.0 — focused tests at ren, impacted regression at mukai

- Moved project-wide regression off aka. Aka now lints, squashes unpublished history, catches up, re-lints if that moved the tree, and pushes.
- Made tsukuyomi the focused-test executor on every ren turn; kokusen still owns the checkpoint.
- Made kotoamatsukami the sole owner of pre-mukai project-wide tests, selecting only declared suites the change can affect, immediately before gyo extracts coverage.

## v0.18.0 — complete local workflow and explicit review policy

- Documented the one-request entry path across Claude Code, Codex, and Cursor ([#45](https://github.com/zheref/hatsu/pull/45)).
- Made first-run surface bootstrap transactional and safe around user-owned files, closing [#46](https://github.com/zheref/hatsu/issues/46) in [#47](https://github.com/zheref/hatsu/pull/47).
- Aligned authoring, verification, launch, discovery, regression, coverage, and UI evidence phases; adopted Nen 0.9 device extraction and closed [#48](https://github.com/zheref/hatsu/issues/48) and [#49](https://github.com/zheref/hatsu/issues/49) in [#50](https://github.com/zheref/hatsu/pull/50).
- Preserved canonical Hatsu/Akatsuki agent provenance while excluding model, runtime, surface, and session credits, authored for [#51](https://github.com/zheref/hatsu/issues/51) in stacked [#52](https://github.com/zheref/hatsu/pull/52) and landed on main by [#55](https://github.com/zheref/hatsu/pull/55).
- Moved Hatsu CI to trusted self-hosted macOS runners and denied fork PR runner allocation, closing [#53](https://github.com/zheref/hatsu/issues/53) in [#54](https://github.com/zheref/hatsu/pull/54).
- Adopted published Nen 0.10 and its explicit Copilot-only `review-round-only` readiness policy while retaining the maintainer's separate human merge decision ([#55](https://github.com/zheref/hatsu/pull/55)).

Version history: main advanced through plugin cache versions 0.15.0 (#47) and 0.16.0 (#50). Attribution PR #52 introduced 0.17.0 but merged into the old #50 branch, not main. Release PR #55 preserves that merge and lands its attribution changes on main together with 0.18.0. No 0.15–0.17 official tags were cut; this consolidated release follows v0.14.0.

Nen 0.10 release: [zheref/nen v0.10.0](https://github.com/zheref/nen/releases/tag/v0.10.0).
