# Contributing to Hatsu

Hatsu is a canon repository: its product *is* the process, so every change here stands at **G4** and
lands through a pull request the maintainer merges. This page collects the rules a change to this
repository must satisfy. The way of working itself is [`docs/WORKFLOW.md`](docs/WORKFLOW.md); the shared
phase conventions are [`docs/PROCESS.md`](docs/PROCESS.md).

## How a change is delivered

Work on this repository runs through Hatsu's own loop, on whichever surface you use:

| Step | Claude Code | Codex | Cursor · Antigravity | What it does |
|---|---|---|---|---|
| warm up and author | `/kurapika <request>` or `/hatsu:ren <request>` | `$hatsu:ten`, then `$hatsu:ren <request>` | `/ten`, then `/ren <request>` | isolated effort worktree, branch off `main`, the change and its focused checks, a local commit |
| publish the branch | `/hatsu:aka` | `$hatsu:aka` | `/aka` | lint, squash, catch up, push. Yours to call |
| review and open the PR | `/hatsu:mukai` | `$hatsu:mukai` | `/mukai` | adversarial review, impacted tests, coverage, evidence, one PR, then `en` drives it to Ready |
| merge | the merge prompt `en` ends at | same | same | **the maintainer's**, in GitHub. No agent merges `main` save `getsuga`'s own release proposal |

Branches read `{model}/{persona}/{descriptor}`. Nothing is pushed until `aka` is called, and no agent
casts a review vote on your credentials.

## A change to a shipped surface needs a version bump


Claude Code keys its plugin cache on `.claude-plugin/plugin.json`'s `version`. Change a plugin-shipped
surface without bumping that field and the change is real in the repository and **invisible on every machine
that already has the plugin installed** — no error, no warning, the fix ships to nobody.

[`scripts/plugin_bump_check.sh`](scripts/plugin_bump_check.sh), wired as the
[`plugin-bump-check`](.github/workflows/plugin-bump-check.yml) workflow, fails a PR that tries. The guarded
surface is `.claude-plugin/**`, `.codex-plugin/**`, `claude/**`, `nen/**`, `contracts/**`, `hooks/**`, `templates/**`, `surfaces/**`,
`.mcp.json`, the shipped docs (`docs/ROSTER.md`, `docs/delegation-grammar-DRAFT.md`, `docs/WORKFLOW.md`,
`docs/DISCOVERY.md`, `docs/LAUNCH-MIGRATION.md`, `docs/AGENT-ATTRIBUTION.md`, `docs/STANDALONE-ENTRY.md`,
`docs/GATE-CONFIGURATION.md`, `docs/PROCESS.md`, `docs/SURFACES.md`, `docs/using/README.md`, `docs/using/mirrors.md`,
`docs/PUBLIC-REDACTION.md`) and every
runtime script an installed copy executes (`scripts/surface_bootstrap.sh`, `scripts/nen_global.sh`,
`scripts/branch_authorship_check.sh`, `scripts/hatsu_plugin_update.sh`,
`scripts/hatsu_root.sh`, `scripts/surface_mirror_check.sh`, `scripts/permissions_pack.sh`, `scripts/dist_tag.sh`,
`scripts/send_freshness_check.sh`, `scripts/kagutsuchi_worktree.sh`, `scripts/cleanup_path_admit.sh`,
`scripts/cleanup_path_admit.ts`, `scripts/hatsu_surface_link.sh`,
`scripts/surface_link_check.sh`, `scripts/prose_size_check.sh`, `scripts/canon_contracts_check.sh`,
`scripts/publish_gate.sh`, `scripts/private_name_check.sh`,
`scripts/bell_notify.sh`, `scripts/tenkai_adopt.sh`, `scripts/release-publish.sh`,
`scripts/report_time.sh`, `scripts/pr_body_evidence_check.sh`, `scripts/pr_development_link_check.sh`,
`scripts/gh_token_env.sh`, `scripts/nen_reach_probe.sh`,
`scripts/pr_body_delivery_check.sh`, `scripts/pr_delivery.ts`, `scripts/pr_body_sections_check.sh`,
`scripts/pr_sections_resolve.sh`, `scripts/pr_sections.ts`, `scripts/gh_api_read.mts`,
`scripts/config_values.sh`, `scripts/config_values.ts`, `scripts/config_values_legacy.sh`,
`scripts/futon_effort_record.mts`, `scripts/product_term_check.sh`, `scripts/product_term_check.mts`,
`scripts/private_name_named.txt`, `scripts/provider_tag_commit.mts`, `scripts/port_rule_reserve.sh`,
`scripts/dependency_audit_resolve.mts`,
`scripts/shell_coverage.mts`) — the one list is `PLUGIN_SURFACE_GLOBS` in the
script, from which the refusal message is generated; this paragraph is a copy of it — everything an
installed runtime reads, the generated Codex and Cursor mirrors included: the warm-up reads plugin resources
from `$CLAUDE_PLUGIN_ROOT`, while first-run bootstrap and the plugin-source updater read their scripts
from the canonical `$HATSU_PLUGIN_ROOT` checkout. Bump
`version` (patch for wording, minor for behaviour or a new skill, major for a breaking interface change —
which the minor carries while Hatsu is on `0.x`, SemVer clause 4, the reading applied to nen's own line).
**There is no opt-out for a shipped path** (zheref/hatsu#171): a `no plugin bump: <reason>` line in the PR
body is honoured only where no path in `PLUGIN_SURFACE_GLOBS` changed — where the guard does not apply
anyway — and, when the version is not bumped, over a shipped path it is refused by name, the refusal
listing the shipped paths the diff changes, because an installed copy reads every one of them and even
wording there is a patch bump. Beside a bump the line is inert, and the pass line says it was ignored.
**A bump beside mirrors still stamped with the old version fails by name** (zheref/hatsu#99): the guard reads the stamp off each `surfaces/<s>` marker and, when it lags the bumped manifest, prints the old and new stamps and the regeneration command, so the required check names the cause — the bump, fixed by a regeneration — where `surface-mirror-check` reports only the drift; the local catch before a PR opens is mukai's `scripts/surface_mirror_check.sh`. Recorded refuse/pass transcripts: [`docs/ab/plugin-bump-guard.md`](docs/ab/plugin-bump-guard.md).

**The check is required on `main`** by the repository ruleset *main: plugin-bump guard required*
(`enforcement: active`), so a failing `plugin-bump-check` blocks the merge. It runs through
`pull_request_target`: GitHub selects the workflow at the trusted workflow SHA, and the job-level
same-repository guard skips fork PRs before assigning a runner. The PR head is checked out as data with no
persisted credential; executable guards, the workflow policy, and dependency pins come from the trusted
workflow checkout. The offline policy validator pins this workflow's trigger, job id, steps, permissions,
and runner so an edit cannot silently remove the required context or execute a PR-controlled guard.

## Validate locally

```sh
claude plugin validate . --strict
scripts/surface_mirror_check.sh   # the Codex/Cursor mirrors match their source
```

The second writes nothing and needs no credential. **At the pinned build it runs the real check** —
the counts the script prints, `codex ok: 44` and `cursor ok: 55` at `v0.42.0`, exit `0`. It exits `2` — saying so, rather than passing — when the `nen` on
your `PATH` has no `surface` verb, which at this pin means the binary is not the pinned one; see
[`docs/using/mirrors.md`](docs/using/mirrors.md) § 4.

---

The generated mirrors under [`surfaces/`](surfaces/) must be regenerated in the same commit as a change to
their authored inputs; [`docs/using/mirrors.md` § 3](docs/using/mirrors.md#3--regenerating) has the one command per
surface, and `scripts/surface_mirror_check.sh` is the check.

## PR composition

Resolve the body through [docs/PR-SECTIONS.md](docs/PR-SECTIONS.md), using the repository kind,
issue jobs, consumer-owned `pr.sections` cells and Mukai run facts. Seven reader sections exclude
the compact footer. Glyph headings follow the catalogue; 150 prose words per section warn only.
Run sections, Nen body-check, evidence and Development guards before every create or body edit.
Hatsu's process verification title is **What the guards prove**; the product title is **How to verify**.

## Commit attribution

> **Attribution ruling, 2026-09-12:** prospective commits carry the truthful canonical
> `Hatsu-Agent` or `Akatsuki-Agent` persona/plane trailer. They never carry model, surface, runtime, or
> session attribution. The final `## Agent attribution` PR-body section records actual participants with
> canonical persona, contribution, and evidence; [`docs/AGENT-ATTRIBUTION.md`](docs/AGENT-ATTRIBUTION.md)
> is the shape. [`docs/WORKFLOW.md`](docs/WORKFLOW.md) is the authority.

In practice: a commit written by a Hatsu session carries `Hatsu-Agent: <persona>` and nothing else of
the kind. [`nen/workflow.json`](nen/workflow.json) → `commits.allowedAttributionTrailers` admits
`Hatsu-Agent` and `Akatsuki-Agent`; `commits.forbiddenTrailers` refuses `Co-Authored-By`,
`Claude-Session`, `Signed-off-by`, `Generated-by`, `Generated-with` and `Reviewed-by`. Turn off your
harness's own co-author trailer (on Claude Code, `includeCoAuthoredBy: false` in its settings), because
`kokusen` and `aka` refuse to write one and `nen commit format` refuses one at exit `2`.

## Changelog fragments

A change that touches the shipped surface owes a fragment under `changelog.d/`, collated into
[`CHANGELOG.md`](CHANGELOG.md) at release time by `getsuga`. Whether a given diff owes one is the verb's
answer, not a guess, and its inputs are declared once, in
[`contracts/pr-composition.json`](contracts/pr-composition.json) → `changelogFragment` (zheref/hatsu#171):

```sh
nen changelog fragment-required --spec-paths <specPaths, comma-joined> \
  --fragment-dir <fragmentDir> --range origin/main..HEAD --head-changelog <headChangelog>
```

A change that touches none of the declared `specPaths` answers `not-applicable`, which is the verb's
word for a docs-only PR; one that touches them and adds its fragment answers `fragment-present`, with
no opt-out line.

`shibari` runs it before the PR opens and names the fragment in the PR body. Never edit `CHANGELOG.md`
directly for an unreleased change. The one exception is a pull request whose own diff changes
`CHANGELOG.md` (futon's integration PR, which writes its own section — [`docs/ROSTER.md`](docs/ROSTER.md)
§ *Rulings of 2026-09-30 — En never merges*): its body carries the declared `directSection.optOut` line
verbatim, and no other PR carries it. **That condition is unenforced by nen**: the verb honours the
phrase anywhere, over any diff, inside an HTML comment or a code fence too, so a Hatsu-side raw-body
check is owed (zheref/hatsu#171), and so is the nen half, owed to nen and not yet filed
([`docs/PROCESS.md`](docs/PROCESS.md) § *Residue and owned dependencies*).

## Redaction

The transcripts and evidence in this repository were recorded against repositories that are not public,
so every private repository name is replaced by a stable placeholder (`<reference-repo>`,
`<product-repo-A>`, `RR-IS-#<n>`, …). The legend and the deliberate survivors are in
[`docs/PUBLIC-REDACTION.md`](docs/PUBLIC-REDACTION.md); `scripts/private_name_check.sh` is the guard, and
`hanten` runs it on every review.

## Where the rules live

| Rule | Authority |
|---|---|
| the loop, the two configuration files, the phases only a human calls | [`docs/WORKFLOW.md`](docs/WORKFLOW.md) |
| invocation grammar, exit codes, reports, reviewer rounds | [`docs/PROCESS.md`](docs/PROCESS.md) |
| who exists, their standing, the maintainer's rulings | [`docs/ROSTER.md`](docs/ROSTER.md) |
| a skill reached from a cold checkout | [`docs/STANDALONE-ENTRY.md`](docs/STANDALONE-ENTRY.md) |
| the surfaces, their guides and their generated mirrors | [`docs/using/`](docs/using/README.md) · [`docs/using/mirrors.md`](docs/using/mirrors.md) · [`docs/surfaces/`](docs/surfaces/) |
| per-skill evidence of the port | [`docs/ab/`](docs/ab/) |

## License

**MIT**, see [`LICENSE`](LICENSE).
