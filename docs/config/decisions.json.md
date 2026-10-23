# `nen/decisions.json` — which conditions stop a run, which ask once, and which resolve by default

> **Lives in** this plugin, as Hatsu's canon matrix at [`nen/decisions.json`](../../nen/decisions.json); a consumer repository may carry its own file, which `hatsu:tenkai`'s declaration table reads as optional (`ok — absent, optional, or defaults apply`) and which can never reclassify a `human-gate` row · **Written by** the maintainer's rulings, authored by hand (`hatsu:great-hiker` is the canon author); no scaffold writes it and `scripts/config_values.sh` never touches it · **Validated by** `nen schema check` (row `nen/decisions.json`, shape `nen.decisions/v0.1`) · **Authority** [docs/WORKFLOW.md § 4](../WORKFLOW.md#4--the-phases-and-which-of-them-a-human-calls), *The conditions that do NOT stop are data* and *Ask, set up, continue*; the rulings themselves live in [docs/ROSTER.md](../ROSTER.md)

## What it decides

One row per condition a running workflow can stop on, and for each the answer to one question: does the run resolve it by default, ask once, or hand it to the maintainer. The file exists because a stop typed as prose in the middle of a reply is a stop the maintainer can scroll past, and one they scroll past is one that did not happen; so the recurring stops have fixed defaults as **data**, every skill states its default in one line citing the row id, and only a genuine gate rings the bell with the banner.

Every skill reads it before it asks: `hatsu:breath` carries a dirty tree (`dirty-tree`), `hatsu:kokusen` hands a red check back to `hatsu:rasengan` (`red-lint`), `hatsu:ao` catches a stale base up and stops only on a semantic conflict (`stale-base`, `semantic-conflict`), `hatsu:en` requests an owed reviewer round inside the configured maximum (`cap-reached`) and ends at the merge prompt (`own-pr-merge`), `hatsu:mugetsu` publishes only on the maintainer's own go (`release-go`). `nen schema set` reads the matching row to compose the stop, and `hatsu:jutaisho` § 3 seeds the picker's lettered options from the row's `preferred[]`. A wrong row here is silent in the way WORKFLOW.md warns about for policy: the right command runs at the wrong moment, a default is applied where a question was owed, or a question is asked where canon already settled the answer.

## Keys

The `$schema` and `contract` are both `nen.decisions/v0.1`. The file is one `rows[]` array; the `$comment` at the top lists which skill cites which row.

### Top level

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `$schema` | string | **`nen.decisions/v0.1`** | The shape nen validates against | `nen schema check` |
| `contract` | string | **`nen.decisions/v0.1`** | The same, as nen's contract name | `nen schema check` |
| `$comment` | string | prose | The maintainer's rationale and the index of citing skills | nothing in nen |
| `rows[]` | object[] | one object per condition | The matrix | `nen schema check` (validates) and `nen schema set` (writes); every skill before it asks (zheref/hatsu#289 item 8: no `nen stop` flag reads it); `nen stop answer --row <id>` (nen 0.26) refuses a row this file does not hold, so every ask-once answer is recorded against one ([`PROCESS.md`](../PROCESS.md) § *Surfaces and pickers*, *Recording the answer*) |

### The three row classes

| `class` | What happens | Who decides | Bell |
|---|---|---|---|
| **`autonomous`** | Resolved by `default` with no question. The skill states the default in one line citing the row id, and the turn page says so | canon, once, in this file | none of its own; the page records the row id |
| **`ask-once-per-run`** | Asked once through the surface's own option picker (Crazy Slots: `AskUserQuestion` on Claude Code, `request_user_input` on Codex, `AskQuestion` on Cursor, `ask_question` on Antigravity), seeded by `preferred[]`, the recommended option starred — **save the rows that star none**: `missing-maintainer-choice`, `publish-offer`, `port-siblings` and `spec-dispatch` (and `spec-clarify` where the answer is a priority, audience, threshold or *intentional*), and `port-drift`, `spec-slice` and `intake-challenger`, whose star is derived per ask (and `kamui` § 7's start picker, no row, which stars only the item on this surface — ROSTER § *Rulings of 2026-10-19/20 — cross-platform porting*); the run resumes on the answer in the same turn | the maintainer, inline | rung 1 and the picker, no banner |
| **`human-gate`** | A gate canon reserves for the maintainer (G1 to G5). The run stops with `nen stop`'s banner, the report link, the lettered options and the question in the picker. **Cannot be reclassified by a consumer's own file** | the maintainer, at the gate | every rung `notifications.rungs` lists |

### The row shape

| Key | Type | Values · default | Represents | Read by |
|---|---|---|---|---|
| `id` | string | kebab-case, unique | The row id every skill cites; kept stable so existing citations resolve even when the row's meaning is re-ruled (`own-pr-merge`) | every skill, `nen schema set` |
| `class` | enum | `autonomous` · `ask-once-per-run` · `human-gate` | Which of the three behaviours above applies | `nen schema set`, `hatsu:jutaisho` § 1 |
| `default` | string | the command or act, with its placeholders (`<checkout>`, `<branch.base>`) | What an `autonomous` row does without asking, or what an `ask-once-per-run` row does on the maintainer's answer. A `human-gate` row carries none; `missing-maintainer-choice` carries none either, because a default is a derivation and the maintainer's word is never derived | the citing skill |
| `why` | string | prose, citing the ruling by date | The maintainer's ruling the row records | nothing in nen; quoted in reports |
| `preferred[]` | object[] | lettered options | The options the picker is seeded with; `hatsu:jutaisho` § 3 composes at least three from them and the session's state, never limited to them | `nen schema set`, `hatsu:jutaisho` § 3 |
| `preferred[].key` | string | `A`, `B`, `C`, `D` | The letter the maintainer answers with | the picker |
| `preferred[].label` | string | one line | What the option does, as the picker shows it | the picker |
| `preferred[].command` | string | the exact command or act | What the run executes on that answer; every option is an executable act, never a mood and never the report | the citing skill |
| `preferred[].consequence` | string | one line | What follows from taking it | the picker |
| `preferred[].recommended` | boolean | `true` on at most one option; absent on the rest | The starred option. A `missing-maintainer-choice` row stars none | the picker |
| `gate` | enum | `G1` · `G2` · `G3` · `G4` · `G5`; `human-gate` rows only | Which human gate the row stands at: G1 the mode label, G2 the delivery merge, G3 publication, G4 the canon merge, G5 a genuine stop | `hatsu:jutaisho at <gate>`, `nen stop --gate` |
| `governs` | string[] | `<skill> <slot>` entries | For `missing-maintainer-choice`: the argument slots whose value is the maintainer's own word, typed and never picked | every skill that takes one of those slots |
| `proposeIssue` | boolean | `true` · `false` | Whether the stop carries a proposed process issue (`nen stop --propose-issue`, Netero's completeness shape) so the next session does not hit the same stop | `nen schema set`, `hatsu:jutaisho` § 3 |
| `refuse[]` | string[] | prose | For `missing-configuration`: what is never written even when asked (a secret-shaped value, a frozen or foreign registry) | `hatsu:tenkai` § 6d, `scripts/config_values.sh set` |

### Every row

The rows at the time of writing, with the class, the default or gate, and the skills whose `SKILL.md` cites the row id. The citations are read from the plugin's skills; the file's own `$comment` carries the maintainer's index of the same.

<details>
<summary>Autonomous rows (resolved by default, no question)</summary>

| Row | Default | Cited by |
|---|---|---|
| `dirty-tree` | `nen shu warmup --repo <checkout> --branch <branch> --carry`: a dirty working copy at breath is carried onto the new branch, nothing discarded, the paths listed | `hatsu:breath` |
| `stale-send` | `scripts/send_freshness_check.sh` reports at exit `2` with both SHAs; kagutsuchi § 3b rebuilds through susanoo in the clean worktree at `origin/<branch.base>`'s tip and sends from there, never from the stale checkout. No `tags.identity` means `freshness: unverified`, never `fresh` | `hatsu:kagutsuchi` |
| `cap-reached` | `nen pr request-reviews --target <owner/name> --pr <n> --add-bots <reviewer>`, while requested rounds are under `round_policy.maxRounds` and resolved rounds under `round_policy.minRounds` (nen's keys from `v0.21.0`; the verb refuses a bot's request past `maxRounds` at exit `2` with a `refused:` line — any other exit `2` is usage, relayed); at the cap the run ends not-ready with the board quoted, never a question | `hatsu:en`, `hatsu:sharingan` |
| `own-pr-merge` | Into `branch.base`: never merge. En § 5's five checks, then the merge prompt with the PR's link and the inline `gh pr merge <n> --repo <owner/name> --merge --match-head-commit <judged head>` line for the maintainer to run (ruling of 2026-09-30, *En never merges*). The one PR an agent merges is getsuga § 3a's own release proposal, through `nen pr merge --release-unit` | `hatsu:en`, `hatsu:limbo` |
| `reviewer-exhausted` | Under `aiReviewers: required` (the default): read `nen pr ready --explain`; no exhaustion is declared (`reviewer_fallback` is retired, ruling 2026-10-04). An exit `9` from `nen pr request-reviews` (`unrecordedBots`) is never retried or counted, and is recorded verbatim with its head. A met `round_quorum` excuses an unavailable member; when the sixth stop's five conditions, (a)–(e), hold ([`PROCESS.md`](../PROCESS.md) § *Reviewer rounds and review threads*, *The sixth stop*) the PR goes to en § 5's merge prompt on hanten's rounds, the not-ready verdict quoted verbatim, never `ready` (ruling 2026-10-11); any other unmet quorum stays inside `sharingan` § 6's bounds. A CI reviewer lane is PROCESS, *Event-driven reviewer lanes*. Outranks `cap-reached` | `hatsu:en` |
| `ai-reviewers` | Read `nen/workflow.json` → `aiReviewers` at the PR's base and the default branch's tip, never the head, the stricter applying (`required` when absent or unreadable); under `optional`/`off` nen waives the round of a reviewer `nen/gates.json` declares `kind: "bot"` identically at both refs, so such a PR reads `ready`, hanten settled (zheref/hatsu#428; [HR-333](../ROSTER.md#hr-333)). For a round nen did not waive, every `reviewers[]` entry must be in `round_quorum.any_of` with an anchored `login_pattern` at both refs, and none may be `kind: "human"` (a declaration, not a bot check). Under `optional` and `off` (`off` never requests a bot), a PR whose `nen pr ready --json` still fails exactly `rounds-owed`, hanten settled, goes to en § 5's merge prompt on hanten's rounds, the not-ready verdict quoted verbatim, never `ready`; any other failing row ends at `cap-reached`. Replaces `reviewer-exhausted`'s sixth stop under those two values ([`PROCESS.md`](../PROCESS.md) § *Reviewer rounds and review threads*, *AI reviewers per consumer*; ruling 2026-10-11). The one value covers CI reviewer lanes too (ruling 2026-10-19; PROCESS, *Event-driven reviewer lanes*) | `hatsu:en`, `hatsu:sharingan` |
| `red-lint` | Hand the tree back to `hatsu:rasengan` with the failing check quoted; the turn continues, never a G5 | `hatsu:kokusen`, `hatsu:gyo`, `hatsu:jusshin`, `hatsu:great-hiker` |
| `injected-attribution-trailer` | `git reset --soft HEAD~1` on the tip the step just wrote (kokusen § 5) or re-squash (aka § 7), then row `harness-attribution-switch`; the unpublished tip is dropped, never amended | `hatsu:kokusen`, `hatsu:aka`, `hatsu:ao` |
| `missing-focused-route` | Hand the tree back to `hatsu:rasengan` to author the focused tests, then `hatsu:tsukuyomi` runs them; never a stop and never the full suite as a substitute | `hatsu:kokusen`, `hatsu:tsukuyomi` |
| `missing-tool` | `nen shu tools --repo <checkout> --install`: installed or resolved through the surface's own catalogue probe, never with elevation; a `verify-only` row that cannot be installed is reported with its remedy line | `hatsu:breath`, `hatsu:build`, `hatsu:classify`, `hatsu:direct`, `hatsu:jusshin`, `hatsu:black-voice`, `hatsu:great-hiker` |
| `stale-base` | `nen wc catch-up --repo <checkout> --base <branch.base>`: rebase when unpublished, merge when published; only a semantic conflict reaches `semantic-conflict` | `hatsu:ao`, `hatsu:sharingan` |
| `release-precondition-red` | `nen changelog collate --write`, then `nen changelog completeness`; reconcile in the same chunk and re-run `nen release preflight`. An active `RELEASE_HOLD` and an open critical issue stay human gates | `hatsu:getsuga` |
| `staging-flag` | Skip ignored, large and out-of-scope paths; mention-or-skip an unmentioned deletion; commit local-config and binary paths only when the request named them. Six of `nen stage triage`'s seven flag kinds; the seventh is `secret-shape` | `hatsu:kokusen` |
| `classify-undecidable` | Leave the axis empty, list the issue as undecidable with the reason; low-confidence keys are listed and never applied (`nen classify apply --include-low` is the maintainer's own hand) | `hatsu:classify`, `hatsu:build` |
| `spec-claim-unverified` | A spec statement with no backing inventory row, an unresolvable citation or an inferred value gets exactly one marker in place of prose — `[NEEDS CLARIFICATION: …]`, `[NEEDS RULING]` or `[UNVERIFIED]` ([`spec-repo.md`](spec-repo.md) § *Citations and markers*); the sentence is kept and counted per folder | `hatsu:dowsing-chain` |

</details>

<details>
<summary>Ask-once-per-run rows (the picker, seeded by preferred[])</summary>

| Row | Default and options | Cited by |
|---|---|---|
| `harness-attribution-switch` | Ask once; the harness's commit-attribution switch is the maintainer's own configuration outside the repository, toggled by their hand. **A** (starred) toggle it off then re-run the step; **B** re-run from a surface whose harness appends nothing; **C** leave the tip dropped and stop | `hatsu:kokusen`, `hatsu:aka`, `hatsu:ao` |
| `host-nen-link` | Ask once, only as the fallback to the session-start binding `scripts/nen_global.sh` performs; offered where the login shell reads *installed, not reachable*. **A** (starred, except on exit `3`) place the name-correct `~/.local/bin/nen` link and the PATH line where missing; **B** leave the host as it is | `hatsu:ten`, `hatsu:bakuryuha`, `hatsu:mugetsu` |
| `missing-consumer-declaration` | `hatsu:tenkai` apply for a Hatsu-owned scaffolding piece. **A** (starred) `scripts/tenkai_adopt.sh apply`; **B** `nen scaffold init --accept-detected --dry-run` then the real run; **C** continue with the refusal quoted, the phase `not measurable here`. Proposes an issue | data-only until a skill cites it (the file's `$comment`); `hatsu:tenkai` is named as its owner |
| `missing-argument` | Derive from the session, the branch, its open PRs and `nen/workflow.json`; one candidate a canon default covers is used and stated for this run only, otherwise ask. **A** (starred) use the derived value; **B** the next candidate; **C** type it. Not for a maintainer's-word value | every skill that takes arguments (one line, WORKFLOW § 4 *Ask, set up, continue*) |
| `missing-configuration` | Ask per item; on the answer write the item through its owner (`nen scaffold init`, `scripts/tenkai_adopt.sh apply`, `hatsu:jujutsu`, the file's own key), `nen schema check`, resume in the same turn. **A** (starred) set it up with the detected value; **B** another value; **C** run once without it. Proposes an issue. `refuse[]`: a secret-shaped value is never written, a frozen or foreign registry is reported, never written | every skill that reads configuration |
| `missing-maintainer-choice` | No default, no star: the value is the maintainer's own word. `governs`: `kagutsuchi <target>`, `mugetsu <target>`, `izanagi <cap>`, `jujutsu <device>`, `ren <request>`, `jusshin <target>`, `jusshin <machine>`, `jusshin <service-identity>`, `jusshin <accept-daily-account>`. **A** type the value; **B** stop here | `hatsu:kagutsuchi`, `hatsu:mugetsu`, `hatsu:izanagi`, `hatsu:jujutsu`, `hatsu:ren`, `hatsu:jusshin`, `hatsu:getsuga`, `hatsu:limbo`, `hatsu:tenkai`, `hatsu:bakuryuha`, `hatsu:great-hiker` |
| `mode-unknown` | The mode is derived from the issue's labels and the diff's paths first; the picker fires only on a genuine tie. **A** (starred) Transmuter; **B** Conjurer; **C** Enhancer | `hatsu:build` |
| `direct-mismatch` | Ask once when the session's surface, model alias or effort is outside the set of `hatsu:direct`'s picks; a session on the recommended or the fallback is one line, never asked. **A** (starred) `nen direct answer --answer continue`, continue here; **B** `--answer stop`, end the run naming the restart line. Never blocks `build` or `ren` | `hatsu:direct`, `hatsu:build` |
| `port-drift` | Ask once per run when a port meets source rows with no target equivalent: every unmapped row batched into **one** picker call, three questions a call (a fourth row opens a second call), each naming the source rule or concept and the target stack. **A** `map to <equivalent>` with its source line, starred **only** when quoted from an existing pair row or an explicit handbook cross-reference; **B** `mirror`; **C** `drop with note`, starred otherwise; **D** `target-only addition`. **The star is set per ask**: no option carries a static `recommended`. The spec's private `## Platform decisions` is read first (a row already answering is cited, never asked), and a concept outside [`ports.md`](ports.md)'s mirror-versus-map list is asked as `unclassifiable`. The pair row keeps `rationale` (the label or the typed words, verbatim, never naming a product, screen, business rule or object id) beside `redraft` (the technology-level restatement, shown before/after); product words go to `## Platform decisions` under a composite with a spec folder, else are refused (`bankai-rule` § 1). The answer binds the port at once and becomes a stable-id row in the ports pair file through `bankai-rule` §§ 3–4 on the run's rulings branch | `hatsu:bankai-rule`, answered for the port composites [`hiraishin`](../../claude/skills/hiraishin/SKILL.md) and [`kamui`](../../claude/skills/kamui/SKILL.md) |
| `port-siblings` | Ask once per `kamui` run, after its spec PR reads `MERGED`: which of the family's configured siblings (`families[].members` but the source repository) receive a port issue. Multi-select, **no option starred** (the maintainer's ruling, zheref/hatsu#354: *"Always ask through a picker which of all the configured siblings the new implementation should be ported to."*), paged in fours, under three items plus *none of them*, a lone sibling still asked; an ungoverned scenario is marked `handbook-question (CON-37)` and refused if picked. **A** port to the siblings picked (`file` §§ 3–5 with its one `direct` run, `nen issue file --assignee`, read back); **B** none of them, the run going to `kamui` § 8. An empty answer reads B; zero siblings is said, never asked. The answer is the G1 for the filings. Bound like `publish-offer`: a consumer's file may not star an option — **advisory**, no guard enforces it yet, as for `publish-offer` | `hatsu:kamui` |
| `wrap-up` | Ask once at a session delivery (a PR at en § 5's merge prompt or merged, a composite's run ending). **A** (starred) `hatsu:cleanup`; **B** `hatsu:cleanup` and `hatsu:third-hand` in parallel; **C** continue iterating, the offer returning at the next delivery. Names no human-called phase; never a merge prompt (ruling 2026-10-13, 5) | `hatsu:cleanup`, `hatsu:en`, `hatsu:build`, `hatsu:futon`, `hatsu:kazaana`, `hatsu:kamui` |
| `cleanup-plan` | Shizuku's plan as one lettered question: **A** (starred) every deterministic row; **B** those plus the proposed rows the maintainer ticks next, in batches of at most three per question where the surface caps options; **C** `none` — keep everything, which wins over every other tick. Named rows (billed resources, the surface's own worktrees, a locked or open-PR worktree) are listed and never an option. Nothing is removed before the answer (ruling 2026-10-13, 6) | `hatsu:cleanup` |
| `publish-offer` | Once kazaana's tag resolves on origin and the target's kind is listed under `futon.advanceGo.mugetsu` as `nen parse futon` reads it (declared, or nen's default): one unstarred publish option per declared destination — the answer is the maintainer's go for `hatsu:mugetsu <target>` on that tag, form (4) of mugetsu § 0, quoted verbatim — plus not now; zero destinations, no offer. **No option starred**: G3 is never recommended; **a consumer's file may not reclassify, default or star it**, as a `human-gate` row (ruling 2026-10-13, 3) | `hatsu:kazaana`, `hatsu:mugetsu` |
| `intake-challenger` | Read `nen/workflow.json` → `intake.challenger` from Hatsu's own checkout and raise every intake examiner whose artifact the brief matches, Satotz for a key missing from the map, with no question; ask once per run, per artifact, only where the block is absent or not an object or a value is outside the cast, the star derived per ask (that artifact's HR-24 examiner), the answer never written. **A** Satotz · **B** Lippo · **C** Buhara · **D** Bisky ([`docs/INTAKE-CHALLENGE.md`](../INTAKE-CHALLENGE.md) § 1) | `hatsu:emperor-time` |
| `spec-capture-scope` | Ask once per capture run after the capability map: **A** (starred) all N capabilities, in waves of `spec.capture.foldersPerPr` · **B** only the typed slugs; a capability already holding a folder routes to recapture | `hatsu:dowsing-chain` |
| `spec-slice` | Ask once per run, three a call, which capability's folder specifies a screen or state two capabilities reach: **A** the first navigation edge's capability · **B** the other · **C** its own folder; the star derived per ask, none when no reading is cited | `hatsu:dowsing-chain` |
| `spec-clarify` | Ask once per run the wave's ranked markers, in one sitting of at most `spec.clarify.maxQuestions`, `maxRounds` counting successive runs, three a call; the answer lands verbatim as a `CL-nnn` entry; the star derived per ask and **none** for a priority, audience, threshold or *intentional*; a declined question stays a marker | `hatsu:dowsing-chain` |
| `spec-dispatch` | Ask once per dispatch run which marker-free gap groups receive an issue — multi-select, **no option starred**, paged in fours; the answer is **not** the filings' G1 (unruled, listed in [`spec-repo.md`](spec-repo.md)): `file` § 4's own confirmation runs per dispatch; the epic's mode label proposed, never applied | `hatsu:dowsing-chain` |
| `spec-converge-filing` | Ask once per recapture or wave run with convergence gaps: **A** (starred) propose them on the desk · **B** file on the pick; answered by `spec.autonomy.convergeFiling` where declared | `hatsu:dowsing-chain` |

</details>

<details>
<summary>Human-gate rows (the maintainer's, never widened by a consumer's file)</summary>

| Row | Gate | What it is | Cited by |
|---|---|---|---|
| `semantic-conflict` | G5 | A conflict of meaning in `hatsu:ao`, always Crazy Slots with both sides shown verbatim: **A** take ours, **B** take theirs, **C** a genuine third resolution, **D** resolve and show the diff before anything is committed. Proposes an issue | `hatsu:ao`, `hatsu:breath`, `hatsu:sharingan` |
| `unsettled-finding` | G5 | A reviewer finding none of hanten § 6's dispositions can settle without the maintainer: **A** extend scope and take the fix, **B** adopt the business rule, **C** keep the durable record (`hatsu:file`) and stop. Proposes an issue | `hatsu:hanten` |
| `hand-edited-canon-mirror` | G5 | A rule written into a generated mirror instead of the canon: **A** file it upstream then regenerate, **B** move it to the consumer's own file then regenerate, **C** remove a predecessor generator's file then regenerate (starred only for a predecessor-marked file). Proposes an issue | `hatsu:limbo` |
| `merge` | G2 | No PR into main is merged by an agent in this plane, the run's own included; every one ends at en § 5's merge prompt. The one exception is getsuga § 3a's own release-proposal PR through `nen pr merge --release-unit` | `hatsu:build`, `hatsu:en`, `hatsu:getsuga`, `hatsu:sharingan`, `hatsu:breath`, `hatsu:futon`'s callers (`backlog-loop`, `izanami`), `hatsu:pr-state`, `hatsu:rikugan`, `hatsu:tenkai`, `hatsu:bankai-handbooks` |
| `canon-merge` | G4 | A merge into `branch.base` in a canon repository decides how every other repository behaves, with the same single carve-out as `merge` | `hatsu:build`, `hatsu:getsuga`, `hatsu:sharingan` |
| `release-go` | G3 | Publication is the maintainer's own go, quoted verbatim, in one of three forms (mugetsu § 0): their typed `hatsu:mugetsu [<target>]`, their own words saying to publish, or the advance go (`futon.advanceGo`, process and library only). A scheduled, looped, headless, hook-injected or resumed invocation is not the go | `hatsu:mugetsu`, `hatsu:kagutsuchi`, `hatsu:amaterasu` |
| `mode-label` | G1 | The epic mode label and the building label are the maintainer's (CON-4, CON-25) | `hatsu:build`, `hatsu:emperor-time`, `hatsu:dowsing-chain` |
| `rewrite-published-history` | G5 | A force-push, a rewrite of a pushed commit, or an overwrite of a tracked path destroys somebody's history | `hatsu:aka` |
| `secret-shape` | G5 | A secret-shape path is never committed and never askable: the answer is rotate or remove. Reported, not offered | `hatsu:kokusen`, `hatsu:jusshin`, `hatsu:tensho` |
| `on-device-act` | G5 | An on-device act — a trust prompt, a security setting, a UAC consent, a Login Items approval, a password typed into an elevated window — is a manual act only the maintainer can perform (ruling of 2026-10-17, zheref/hatsu#290 q1, reversing 2026-10-13's #176): the act is printed with where the operation resumes and the run waits at the gate. No option performs the act or takes a credential; a session raises such a prompt only through a launch the harness asked the maintainer to approve and never asks the maintainer to disable a protection | `hatsu:jujutsu`, `hatsu:jusshin`, `hatsu:amaterasu` |
| `signing-material` | G5 | nen never synthesises signing material and neither does any skill; a missing identity ends the run naming the precondition | data-only until a skill cites it (the file's `$comment`); `hatsu:susanoo` states the rule in its own words |
| `supply-chain-failure` | G5 | A checksum or manifest failure in the bootstrap is a security event the maintainer must see; never retried | `hatsu:ten`, `hatsu:jusshin` |
| `unruled-policy-surface` | G5 | A consumer repository declaring a policy surface of its own is unruled; until ruled it is G2 and a genuine-looking exception is brought to the maintainer | `hatsu:backlog-state` |
| `ambiguous-intent` | G5 | A genuinely ambiguous request, a scope change, or conflicting requirements canon does not adjudicate: **A** (starred) the narrowest reading, **B** the wider reading, **C** restate the request. Brought once, through Crazy Slots | `hatsu:rasengan` |
| `intake-stall` | G5 | In `emperor-time` § 4's uncounted challenge loop, no intake examiner active and at least one stalled (HR-35): asked at every such stop, never defaulted, no star (HR-36). **A** continue, the stalled examiners re-entering · **B** go on to filing with the open questions, the maintainer's at G1 (HR-32) | `hatsu:emperor-time`, `hatsu:dowsing-chain` (§ 6) |
| `spec-coverage` | G5 | A delivery PR on a spec-derived issue whose Spec section leaves an SC neither satisfied nor deferred, or cites an id the issue does not carry: shibari does not open. **A** satisfy it (a test named by the SC id) · **B** defer it with the maintainer's reason and a follow-up · **C** stop the effort; no star. **Owed**: shibari has no Spec section yet, so nothing raises it; the delegate writes the section and reviewers check it ([zheref/hatsu#405](https://github.com/zheref/hatsu/issues/405), zheref/nen#493) | `hatsu:dowsing-chain` |
| `spec-conflict` | G5 | Recapture finds a merged FR the code now contradicts: **A** amend the spec to the code · **B** file the code as a defect · **C** keep both, marked; the answer quoted verbatim, no star | `hatsu:dowsing-chain` |

</details>

> **Precedence worth knowing.** `reviewer-exhausted` outranks `cap-reached`: the sixth stop (PROCESS, *The sixth stop*) is an observed impossibility, not a ceiling, and the board `cap-reached` would have carried goes onto the merge prompt. `secret-shape` is the one `nen stage triage` flag kind with no canon default and is never askable. A `human-gate` row can never be widened by a consumer's own file — and `publish-offer`, an `ask-once-per-run` row whose answer crosses G3, is bound the same way: never reclassified, defaulted or starred by a consumer's file; an unruled condition asks once with a proposed issue, never a silent default.

## Example

Illustrative only: a consumer's own matrix carrying one row per class. A consumer's file adds rows for its own conditions or narrows an `autonomous` default; it cannot reclassify a `human-gate` row, so the third row below is the canon row restated, not a new one.

```json
{
  "$schema": "nen.decisions/v0.1",
  "contract": "nen.decisions/v0.1",
  "rows": [
    {
      "id": "dirty-tree",
      "class": "autonomous",
      "default": "nen shu warmup --repo <checkout> --branch <branch> --carry",
      "why": "A dirty working copy at breath is carried onto the new branch; nothing is discarded and the paths are listed in the report."
    },
    {
      "id": "missing-configuration",
      "class": "ask-once-per-run",
      "default": "ask per item; on the answer, set the item up through its owner, validate it with nen schema check, and resume the operation in the same turn",
      "preferred": [
        { "key": "A", "label": "set it up now with the detected value",
          "command": "write the item through its owner, nen schema check, then resume",
          "consequence": "the configuration exists from now on", "recommended": true },
        { "key": "B", "label": "set it up with another value",
          "command": "the same write with the value the maintainer picks or types",
          "consequence": "the same, on the maintainer's value" },
        { "key": "C", "label": "run once without it",
          "command": "the owning verb's --dry-run, or the phase reported not measurable here",
          "consequence": "nothing is written; the gap is named and asked again next time" }
      ],
      "proposeIssue": true,
      "why": "A missing configuration item is asked for per item, written on the maintainer's behalf once answered, and the operation continues.",
      "refuse": [
        "a value shaped like a secret, credential or signing material is never written",
        "a frozen or foreign registry is reported, never written"
      ]
    },
    {
      "id": "release-go",
      "class": "human-gate",
      "gate": "G3",
      "why": "Publication is the maintainer's own go, quoted verbatim; no composite reaches it on its own authority."
    }
  ]
}
```

## When a skill needs a value that is not set

This file has no catalogue entry: [`contracts/config-catalogue.json`](../../contracts/config-catalogue.json) lists settable values of `nen/workflow.json`, `nen/gates.json` and `nen/contract.json`, and `scripts/config_values.sh` writes only those three files. An absent `nen/decisions.json` is not a gap: `hatsu:tenkai`'s declaration table reads it as `ok — absent, optional, or defaults apply`, and the defaults the skills cite are the rows of Hatsu's own matrix.

The file is instead the **mechanism** behind every other missing value. When `config_values.sh need --repo <path> --skill <s>` exits `1`, the warm-up (`hatsu:ten` § 6 step 5b) asks through row `missing-configuration`: one picker question per item, the detected value starred, written through the item's owner on the answer, validated with `nen schema check`, the operation resumed in the same turn. A missing or unparseable argument is row `missing-argument`, completed inline the same way. What is not a gap is refused, never asked and never softened into a default: a secret, a human gate, a supply-chain failure, a frozen or foreign repository, a safety precondition (WORKFLOW.md § 4, *What is not a gap*).

For the four verbs themselves: `diagnose` reports what is outstanding in the three catalogued files, `fill` writes their absent defaults and `$<key>` annotations behaviour-neutrally, `need --skill <s>` lists what a phase cannot run without, and `set` writes one chosen value after the question; none of them reads or writes this file.

## Sources

- [`nen/decisions.json`](../../nen/decisions.json), Hatsu's own file, its `$comment` and every row's `why`
- [`docs/WORKFLOW.md § 4 · The phases, and which of them a human calls`](../WORKFLOW.md#4--the-phases-and-which-of-them-a-human-calls): *The only interruptions are genuine G5 stops*, *The conditions that do NOT stop are data*, *Ask, set up, continue*, *What is not a gap*, *The maintainer's word is never derived*
- [`docs/WORKFLOW.md § 1`](../WORKFLOW.md#1--two-files-and-the-line-between-them) (the failure modes of the two files)
- [`contracts/config-catalogue.json`](../../contracts/config-catalogue.json), its `$comment` on which files it covers
- [`scripts/config_values.sh`](../../scripts/config_values.sh), header comments and `WRITABLE_FILES`
- [`claude/skills/jutaisho/SKILL.md`](../../claude/skills/jutaisho/SKILL.md) § 1 and § 3 (how a row reaches the bell and the picker)
- [`claude/skills/tenkai/SKILL.md`](../../claude/skills/tenkai/SKILL.md) § 3 (the declaration table reading this file as optional)
- [`claude/skills/ten/SKILL.md`](../../claude/skills/ten/SKILL.md) § 6 step 5b
- every `claude/skills/<name>/SKILL.md` searched for the row ids in the *Cited by* columns
- [`docs/ROSTER.md`](../ROSTER.md), the rulings each `why` cites
