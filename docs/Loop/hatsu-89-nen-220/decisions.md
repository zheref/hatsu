# Run state — hatsu:build zheref/nen#220 then zheref/hatsu#89 (Session 2 of the hardening audit)

Started 2026-09-20. Mode: **Transmuter** (machinery: templates, nen verbs) with **Conjurer** for the canon prose (agents, roster, skills). Kurapika builds both halves himself; Hatsu holds no CI plane.

| When | Decision | Why |
|---|---|---|
| 2026-09-20 | Filed zheref/nen#220 and zheref/hatsu#89 from the audit's Session 2 prompt | the build verb takes an issue |
| 2026-09-20 | nen branch `fable/kurapika/reports-reviewers` in a worktree beside the main checkout, cut from `origin/main` at v0.11.0 | the v0.11.0 tag is being cut in a parallel session; the main checkout stays untouched |
| 2026-09-20 | hatsu branch `fable/kurapika/reports-reviewers` from `origin/main` (ea358af, v0.41.0) | release metadata for v0.41.0 is another session's |
| 2026-09-20 | `reports.sections` variants: `turn`, `turn-fast`, `landing` (spiritual-message), `final`, `register` (rikugan); `review.scopes`: code (Nobunaga, every path), security, architecture, ui, performance, release | ruled 2026-09-19: sections beside `reports.template`; the final report is a one-effort Rikugan |
| 2026-09-20 | Graph document contract `nen.report.graph/v0.1` (nodes: id, label, kind, change; edges: from, to, rel, change); mermaid emitted from the same document for the PR body | ruled 2026-09-19: client-side layout from JSON, dagre from cdnjs |
| 2026-09-20 | Pin moved to nen `0.12` / `v0.12.0` before the tag exists | same sequencing as Session 1: the warm-up reads WRONG until the nen release PR merges and the tag is cut; the PR body says so |
| 2026-09-20 | Copilot rounds requested by hand through GraphQL `requestReviews(botIds:["BOT_kgDOCnlnWA"])` | `nen pr request-reviews --add-bots copilot` cannot resolve the bot (zheref/nen#160) |
| 2026-09-20 (**reversed, same day**) | Copilot rounds requested through the verb: `nen pr request-reviews --add-bots BOT_kgDOCnlnWA` | the row above was wrong. `--add-bots` takes the **node id** and always routed it; zheref/nen#160 is resolution by *login*. Verified at `v0.12.0`, exit `0`, `BOT_kgDOCnlnWA -> bot [add-bots]` |

No label applied: neither repository carries a delivery-stage taxonomy (`nen issue chain-position` has no role map here), so the stage-free path of build § 1 applies and the effort is carried locally to its own PR.
