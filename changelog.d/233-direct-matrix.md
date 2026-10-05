### Added

- **`docs/DIRECT-MATRIX.md` — the model matrix, readable without running `hatsu:direct`.** One page answers which model, surface and effort `direct` will recommend for any work:
  - the ten aliases, each with its provider, family, surface, the name you type and the dated snapshot model;
  - a grid of all 39 jobs × 5 domains naming each winner, with per-language winners inline, fallback routes marked, and the two cells no issue can reach (`parity` in feature and maintenance) shown as `—`;
  - five job × language matrices, one per domain as the registry routes them, each cell giving that pair's winner, runner-up, phase and interactive tool;
  - the domain rules, the fallback sentence and the aggregation rule, quoted from the data; the effort rule with job weights and each surface's dial;
  - seven worked examples with their restart lines. ([#233](https://github.com/zheref/hatsu/pull/233))
  - **Rendered, never hand-written.** `scripts/direct_matrix_doc.sh` builds the page from `contracts/direct.registry.json`, `contracts/classify.taxonomy.json` and `nen/workflow.json` → `models`, the files `nen direct resolve` reads.
    - `--check` fails on a stale or missing page.
    - `--self-test` proves the guard's negative paths on hermetic fixtures, then runs `--check`. It is the argv of the new focused lane `direct-matrix-guard` in `nen/contract.json`.
    - `--verify` asks `nen direct resolve` about **every claim the page prints**: 2,017 at nen `v0.20.0`, all agreeing. A planted renderer bug turns it red with 93 disagreements.
    - The rendering re-implements the verb's rules to work offline, and that re-implementation is named as residue in the script. Running both checks automatically, in CI on data-only edits and at every nen repin, is zheref/hatsu#234.
  - Linked from the README's introduction and from `docs/WORKFLOW.md` § *`direct` — the model, surface and effort*. The WORKFLOW paragraph and the new lane are shipped surfaces, so the plugin is bumped to 0.92.1 (Claude manifest and Codex overlay) and the mirrors are regenerated at that stamp.
