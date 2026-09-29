# Run state — `hatsu:futon hatsu@bug then getsuga+mugetsu`

Started 2026-09-28. The maintainer's typed invocation, quoted verbatim as the advance go (`mugetsu` § 3):
`hatsu:futon hatsu@bug then getsuga+mugetsu`. `nen parse futon` (v0.15.1): repo `zheref/hatsu` (self),
selector label `bug`, `then` chain `getsuga` → `mugetsu`, both `gate: allowed: true` (kind `process`,
`declared`). Kurapika builds every issue himself; Hatsu holds no CI plane.

**Scope** — 12 open issues carrying `bug`: #118, #107, #106, #105, #103, #101, #99, #98, #74, #72, #67,
#66. Out of scope (no `bug` label, reported, never worked): #119, #113, #111, #108, #104, #102, #100,
#93, #90, #85, #81, #73.

| When | Decision | Why |
|---|---|---|
| 2026-09-28 | No `bankai:severity/*` and no `bankai:stage/*` label applied to any issue | `nen/labels.json` for zheref/hatsu declares neither family; WORKFLOW § *no delivery-stage taxonomy*: never invent one. `nen backlog order` ordered by blocks / affects-consumers / age with every severity `(none)` |
| 2026-09-28 | Twelve issues folded into four sequenced efforts, one PR each, stacked on the previous head | every plugin-shipped change bumps `plugin.json` and regenerates every mirror file under surfaces/ (189 at v0.50.0), so no two efforts can be file-disjoint; the fold follows file locality |
| 2026-09-28 | E1 `fable/kurapika/ten-installed-surface` — #105, #106, #118, #107. Mode: **Transmuter** (scripts) with **Conjurer** for ten § 0/§ 5, hanten § 4 and the preamble | mode derived from the paths (decisions row `mode-unknown` fires only on a tie) |
| 2026-09-28 | E2 `bump-and-link-guards` — #74, #99, #72 · E3 `release-pr-readiness` — #98, #103, #101 · E4 `cursor-trailer-and-bind` — #66, #67 | same rule; each starts when the previous PR is Ready and prompted, retargeted to `main` when its predecessor merges |
| 2026-09-28 | nen 0.14.0 → v0.15.1 bootstrapped (checksum verified, cache hit), bound for the session only; `~/.local/bin/nen` left at 0.14.0 | ten § 2 (b) is the default; (a) is the maintainer's word |
| 2026-09-28 | #106 resolved as "no mirror on Claude Code": nen's `claude-code` row mirrors into a target `.claude/` layout Hatsu never places, and `--installed` diffs a FULL mirror, so a skills-only placed copy or the versioned cache always reads `missing` | measured live: `--installed <cache>/claude` → ok 57, missing `hooks/hooks.json`, `settings.local.json`; `--installed <target>/.agents/skills` → ok 45, missing `AGENTS.md`, `agents/*.toml`, `config.toml`, `hooks/…` |
| 2026-09-28 | #118: `--claude` brings the marketplace's Directory source current first (Claude Code's `known_marketplaces.json`, one JSON shape), and untracked files no longer read as dirty | the maintainer's marketplace source is the core checkout, which always carries an untracked `.claude/`; a fast-forward that would overwrite an untracked file is refused by git itself |

No label applied: the repository carries no delivery-stage taxonomy, so the stage-free path of build § 1
applies and each effort is carried locally to its own PR.

| When | E1 review (hanten, head 412aa7e) | Disposition |
|---|---|---|
| 2026-09-28 | Nobunaga 11 (1 high, 6 medium, 3 low, 1 nit) · Chrollo 8 (1 high, 5 medium, 2 low) · Feitan 3 (1 medium, 2 low) · Phinks 2 (1 medium, 1 low); the high (a git-refused fast-forward escaping the script's exit contract) was found twice | all fixed in the working copy except Phinks's medium — `scripts/hatsu_root.sh` and `scripts/surface_mirror_check.sh` are absent from the bump guard's `PLUGIN_SURFACE_GLOBS` — **deferred** to E2 (`bump-and-link-guards`, #74's fold), his red test carried in the run's scratchpad as `e2-plugin_bump_runtime_scripts_red.sh` |
| 2026-09-28 | Scan rows for Feitan: gitleaks v8.30.1 checksum-verified, clean; dependency audit NOT SCANNED (no `claude-code-plugin` row); `nen stage triage` clean; builder-touching-workflow gate not applicable (role canon) | recorded |
