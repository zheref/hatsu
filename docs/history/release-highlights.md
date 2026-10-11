# Release highlights, as the README recorded them

This file preserves the dated release notes that opened the repository README until 2026-10-11, moved
here verbatim when the README became a cheatsheet. Each paragraph stays true of the release it names;
none of them describes the current release. **[`CHANGELOG.md`](../../CHANGELOG.md) is the authority on
what each version changed**, and the current version is whatever
[`.claude-plugin/plugin.json`](../../.claude-plugin/plugin.json) says.

The entries below are in the order the README carried them, which is roughly newest first after the
opening paragraph, with the oldest releases (`v0.1.0` to `v0.7.0`) folded into that paragraph.

---

> **The current release is whatever [`.claude-plugin/plugin.json`](../../.claude-plugin/plugin.json)'s `version`
> says, and this line names no number on purpose** — a version repeated in prose is a version that drifts,
> and this one sat four bumps behind before anybody read it. The releases named below are history, and each
> stays true of the release it names. Hatsu is the local plane of the Akatsuki system, and it succeeds the local plane of a
> predecessor system — the frozen reference implementation — which it also **serves live today**: the
> original seventeen skills were ported name-for-name and proven against that system's real backlog before
> `v0.1.0` was cut. The evidence is in [`docs/ab/`](../ab/), one file per skill — dated records of the port
> against nen `0.1.0`. `v0.3.0` reconciled every skill and persona with nen **`v0.3.0`**, and every repin
> since lives in [`nen/contract.json`](../../nen/contract.json), which is the only place the pinned nen is
> written down. **`v0.4.0` adds the
> way of working**: ten skills that make the local loop itself explicit, two configuration files that hold
> every parameter of it ([`nen/contract.json`](../../nen/contract.json) → `project` and
> [`nen/workflow.json`](../../nen/workflow.json)), and three harness hooks — a session-start reminder, a stop bell and a refusal to commit on
> the trunk. **`v0.5.0` adds the PR side**: eight more skills — `mukai`, `murasaki`, `hanten`, `gyo`,
> `kotoamatsukami`, `shibari`, `en` and `jujutsu` — the rename of `drive` to **`sharingan`**, and the three
> agent definitions that side needs: **Feitan**, **Chrollo** and **Illumi**. **`v0.6.0` closes the release
> side**: `susanoo` (archive and packaging), `kagutsuchi` (non-production upload, per target) and `mugetsu`
> (publication, per target, **G3**) — so four of the five phases only you may call have a skill; the
> fifth is **the merge**, which has none because no agent performs it.
> **`v0.7.0` adds no skill and adds two surfaces**: the same thirty-eight skills and eight personas,
> generated into Codex and Cursor layouts under [`surfaces/`](../../surfaces/) — see [*Surfaces*](../SURFACES.md).
> **`v0.24.0` adds `byakugan`**: coverage capture and measurement, independent of tests; kotoamatsukami is unit, UI and integration suites only; gyo remains lint. The live skill surface is **thirty-nine**.
> **`v0.27.0` adds `third-hand`**: wrap-up harvest after En. **`v0.28.0`**: it is a separate phase that starts once En has completed, not En step 8. Codex uses `request_user_input` and in-session spawn; Antigravity uses `ask_question` and `invoke_subagent` with `Workspace: inherit`. **`v0.29.0`**: Illumi's En watch uses Codex spawn; generated inventories are 41 skill files and 9 personas. **`v0.30.0`**: Hanten's cycle ledger is fail-closed — Breath `init`s it after the cut; `decide`/`record` refuse a missing file; load-mutate-save is locked. The merge remains G2 with no skill. The live skill surface is **forty**.
> **`v0.73.0` — `rikugan` is a callable skill again, every session binds the pinned `nen` on your host, and every worktree lives under `.nen/worktrees/<surface>`.** `hatsu:rikugan [for <CODE>#<N>[,…] | <owner/name>] [as final|register]` renders the final state of a just-completed workflow — every issue and PR it touched, each PR's `nen pr ready` verdict quoted verbatim — through `backlog-board` § 3's render path: a delivered one-effort scope as the dated, kept `final` Rikugan with its desk cleared; a workflow that stopped with asks still open, or a wider scope, as the transient `register` page carrying those asks: typed, as a `futon` `then rikugan` step, or as the closing step of `en`, `futon` and `backlog-loop`. And `ten` § 2's host default is now the rule: `scripts/nen_global.sh`, run first by the `SessionStart` hook, verifies the pinned binary's SHA256, links `~/.local/bin/nen` to it and adds a marked PATH block to your shell rc, so your own terminal and the agent run the same `nen` (`HATSU_NEN_GLOBAL=0` or a `~/.config/hatsu/nen-global` file reading `off` opts out). And every worktree Hatsu creates now lives at `<core>/.nen/worktrees/<surface>/<name>` — git-ignored, inside the core checkout, never a sibling folder — on all four surfaces, with each harness's own isolation named as the one exception (`docs/WORKFLOW.md` § *Where worktrees live*). The live skill surface is **forty-eight**.
> **`v0.68.0` — `jusshin` raises a consumer's self-hosted runners.** `hatsu:jusshin [for <owner/repo>] [pool <id>] [x <count>] [on <machine-code>]` plans the runner names from the consumer's `nen/workflow.json` → `runners` declaration, renders one host script outside the runner root that you consent to (the harness's prompt on the launch line, then the UAC prompt and the service-account password on Windows; `sudo` on Linux; Login Items on macOS), verifies the runners online, proves the pool with a preflight job that runs as the service does, and only then switches the pool's jobs on — every deterministic step a `nen runner` verb. The live skill surface is **forty-seven**.
> **`v0.66.0` — every surface serves Hatsu first-party from your own checkout, and `bakuryuha` switches it.** Claude Code loads the checkout in place as `hatsu@skills-dir`, Codex installs it as its own `hatsu` plugin through `.codex-plugin/plugin.json`, and Antigravity links its global plugin directory to `surfaces/antigravity`. `hatsu:bakuryuha` makes or confirms that install, updates the checkout, re-proves with the new `ten`, reads back what the surface serves, and ends every run with the one thing left to type or open. The live skill surface is **forty-six**.
> **`v0.64.0` — the send is gated on freshness, and a stale archive is rebuilt before it goes.** `kagutsuchi` runs a freshness gate before every `--run`; a dirty tree, a missing archive, or one not built from `HEAD` at the trunk's tip is never sent — `kagutsuchi` runs `susanoo` for a fresh build first, in one idempotent clean worktree at `origin/<branch.base>` with your gitignored files copied from core (`project.fromCore`), and only then. The target comes from your invocation or from `nen/workflow.json` → `deploy.defaultTarget`. No new skill: the surface stays **forty-five**, and `kamui` is reserved.
> **`v0.42.0` — the reports and the reviewers carry their weight.** Spiritual Message is rebuilt with the desk above the fold and the delta drawn from a nodes-and-edges document; **Rikugan** (`templates/rikugan.html`) is the desk-and-register page `backlog-board`, `futon`, `backlog-loop` and the dated final report render through `nen report render --variant`; **Nobunaga** joins as the default code reviewer and **Shalnark** as the optional post-merge UI validation automator behind the new `hatsu:black-voice`; every reviewer reads one shared preamble and fits under 6 KB; the ten largest skills fit under 12 KB. The live skill surface is **forty-two**.
> **`v0.40.0` — the release row is real.** A repository whose product is the process must declare a real `release` row, not a seat: `hatsu:mugetsu` exists to run that row at `G3`, and a seat meant it had nothing to run while releases were published by hand. `templates/release-publish.sh` is the engine, Hatsu dogfoods it, and Tenkai derives a repository's role from `nen/repos.json` rather than classifying one for itself.
> **`v0.39.0` — a repository becomes a consumer, deterministically.** `hatsu:tenkai` adopts a repository new or existing, diagnosing before it writes and repairing **drift** — the workflow rendered for another slug that is skipped on every event, looking installed and doing nothing. Idempotent by construction; `scripts/tenkai_adopt.sh` proves it against fixtures. Runner selection derived per repository; the two-PR ordering staged rather than hit; `nen/colors.yml` declared at last, so `nen schema check` is green here for the first time.
> **`v0.38.0` — the readiness verdict is published where a human can see it.** `.github/workflows/pr-readiness.yml` runs `nen pr ready --explain` on every event that can change the answer and publishes the verb's own verdict as the `readiness` check run — deterministic, agent-free, and persisting past the session that opened the PR. Not a label (only `checks: write` is admissible on a `pull_request_target` job) and not the title (authored content that becomes the squash-merge subject). The conclusion is always `success` by construction: `CON-32(a)` requires every reported check green, so a red readiness check would make the gate it reports on permanently unsatisfiable.
> **`v0.36.0` — a tag records a build that landed.** `kagutsuchi` cuts one tag after a successful upload; `susanoo` only names the tag that is coming and still pushes nothing. Opt-in per repository, with the name the repository writes and a mandatory species prefix.
> **`v0.35.0` — a bot reviewer is a different route.** `sharingan` records how to re-request Copilot, why `gh pr edit` fails silently on a Bot while REST answers a misleading `422 may only be requested from collaborators`, and why REST's `requested_reviewers` is the wrong place to verify.
>
> **`v0.33.0` — standalone entry.** Every skill is reachable from a cold checkout, in any state.
> [`docs/STANDALONE-ENTRY.md`](../STANDALONE-ENTRY.md) is the authority: a five-step preamble (warm
> up, orient, establish the delta, elicit, declare), the four state classes a phase used to inherit
> from its caller, and the per-surface option-picker matrix. Twenty skills carry a `## 0. Standalone
> entry` section — thirteen that derive state cold, seven that add the warm-up and expectations only.
> The delta default everywhere is the **fetched `origin/<branch.base>`**, committed and uncommitted
> together; the base is stated always and overridable only where the skill's grammar declares a
> clause, and a fetch that cannot run is a stop rather than a silent fall-back to the local ref. **No skill is ever indefinitely
> independent**: a standalone run absorbs no later phase, creates no standing authority, crosses no
> gate the wired run would not cross, and ends by naming its successor. `G3` is unmoved.
