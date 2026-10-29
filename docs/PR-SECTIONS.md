# PR sections, resolved before writing

[`contracts/pr-sections.json`](../contracts/pr-sections.json) owns the section ids, titles, glyphs,
template fragments, job families, precedence and default matrix. The composition inputs and gate
path sets remain in [`contracts/pr-composition.json`](../contracts/pr-composition.json). Neither
file is copied into a run's prose. The retired `templates/pr-body.md` has no runtime role.

## Resolve the run

1. Read `nen repo classify --repo <target>` for the repository kind. Collect the distinct `job/`
   labels on every associated issue, stripping the `job/` prefix; no issue defaults to `build`. Most jobs wins; ties use
   `release > fix > build > maintain > verify > canon`. Unknown kind uses library without `compat`.
2. Read the target's `nen/workflow.json → pr.sections`. Its full matrix is filled from the catalogue,
   with `$sections` beside it listing all ids and purposes. An edited cell belongs to that consumer;
   fills and diagnosis preserve it. `$canon` records the originating catalogue contract and sha256.
   `max` defaults to seven and cannot exceed the catalogue cap.
3. Reuse Mukai's facts: `--evidence` only for a product declaring `project.evidence.globs`,
   `--economics` only when Leorio ran or took a delta pass, `--policy-hit` when `nen gate derive`
   matched a policy or process path, `--spec` when a closing issue carries `Spec: specs/<nnn>-<slug>@<sha>`
   (the footer's Spec block and nen's `spec-rows` requirement, [`config/spec-repo.md`](config/spec-repo.md)
   § *The PR Spec section*). The footer row `decisions` is mandatory on every PR whose run took a
   decision for the maintainer (a pre-answered row or a default taken), whatever the kind or family: an idle
   run by [HR-334](ROSTER.md#hr-334), an attended one by zheref/hatsu#474 AC-1. Any positive source includes it:
   `--idle`, because an idle run always pre-answers its rows (WORKFLOW § *Idle batches* rule 8);
   `--decisions-from <nen.run manifest>` whose `idleAnswers` is not empty; or `--decisions`. The manifest
   proves only the pre-answers a run was launched with: nen never updates `idleAnswers` and it is null on an
   attended run, so a null or empty map adds nothing: beside `--decisions` or `--idle` the flag wins, and
   alone it refuses at exit 1. A malformed manifest refuses whatever else is passed. A default taken mid-run
   or attended is `--decisions`, passed by the session that took it. A run that took no decision passes none of the three,
   and the heading is then undeclared. These facts activate conditional ids; they do not create headings.
   The always-on footer then renders the exact `## Adversarial review (hanten)` heading. Every finding
   carries a settled disposition; `deferred` also carries a tracked issue reference. The completion
   checklist records `- [x] Adversarial review settled.` only after those rows are settled.
4. Resolve before drafting, and resolve again when kind, labels, configuration or run facts change:

```bash
"$hatsu_root/scripts/pr_sections_resolve.sh" --repo <target> --kind <kind> --jobs <comma-joined-jobs> \
  [--evidence] [--economics] [--policy-hit] [--spec] [--decisions] [--decisions-from <nen.run manifest>] [--idle] \
  --out <absolute-requirements.json>
```

The resolver prints the ordered ids and writes the per-run `{name, pattern}` requirements array.
Place the always-on Delivery preamble first, then fill the reader fragments from
`templates/pr-body/<id>.md` in resolved order, then Spec (only with `--spec`), Decisions (when admitted),
Hanten, checklist, issues and final attribution.
Never append an undeclared level-2 heading. Delivery is outside the seven-reader cap and does
not change any kind × family cell or consumer-owned override.
The default requirements file is the process × canon fixture, never a substitute for resolving a run.

## Refresh a copied matrix

Run `config_values.sh diagnose --repo <target> --domain publishing --json` to read each cell against
its stamped catalogue: current default, stale default, consumer-owned, missing or retired. A copy
without `$canon` reads unstamped in one line. The packaged `contracts/pr-sections.history.json`
keeps complete prior catalogues keyed by their canonical `documentSha256`, so this works offline in
an installed plugin with no `.git`. Canonical bytes are compact UTF-8 JSON with object keys sorted
recursively and the top-level `documentSha256` excluded; arrays retain their order. The composition
guard checks the digest and requires the current catalogue in history; retain prior entries on
every later catalogue edit.

```bash
"$hatsu_root/scripts/config_values.sh" fill --refresh --repo <target> --json
```

This explicit operation, also used by Tenkai adoption, updates unedited defaults and missing cells,
the option list and stamp. It keeps the chosen cap and every owned cell, naming each retained cell;
`$canon.owned` preserves that ownership through later stamps. Retired ids or cells in an owned cell
refuse at exit 1 with names, before any write. Resolve those cells explicitly before retrying.
Unknown or malformed stamps refuse at exit 2. An unstamped refresh says provenance is unknown,
retains every existing cell as explicitly owned, adds missing cells and stamps the current catalogue.
Those retained cells stay owned on later refreshes. Plain `fill` preserves the bytes of a present matrix.

Tenkai diagnosis adds `pr.sections: stale (<n> stale default cell(s), <m> missing; stamped <sha7>,
catalogue <sha7>)`, with structured cell counts and both full hashes in JSON; a current copy has no
freshness finding. Ten reads that finding in its policy inbox and performs no repair.

## Default matrix

Every cell below is materialized in the consumer, including the unknown-kind cells derived as above.
Conditional ids appear in the matrix but render only with their run fact. Economics appends to any
cell when raised. The release matrix is the maintainer's explicit exception to `improves` on every PR
(clarification 2026-10-20, HA#351); all other families carry all eleven aspects.

| Family | Product | Library | Process |
|---|---|---|---|
| build | changes · why · how · improves · verify · evidence | changes · why · how · compat · improves · verify | changes · why · how · improves · across · verify |
| fix | changes · why · how · improves · verify · evidence | changes · why · how · compat · improves · verify | changes · why · how · improves · across · verify |
| maintain | changes · why · how · improves · verify · rollout | changes · why · how · compat · improves · verify | changes · why · how · improves · across · verify |
| verify | changes · why · how · improves · verify · evidence | changes · why · how · improves · verify | changes · why · how · improves · verify |
| canon | changes · why · how · improves · verify | changes · why · how · improves · verify | changes · why · how · improves · across · verify |
| release | changes · why · release-unit · rollout · verify · evidence | changes · why · release-unit · compat · verify | changes · why · release-unit · across · verify |

## Write for the decision

After Delivery, begin the reader sections with `# ✨ What this changes for you`: a named consumer's Before / After table, a Case for /
Case against table, and what would flip the decision. State effect and cost before mechanism.
`Why` carries Source / What it showed / Why it matters now and the authoring nature. Keep paths and
function names in `How`'s legend, where they explain the structure, rather than in reader prose.
Generate the structure diagram through `nen report mermaid --graph`; its legend is Item / Kind /
Change, using file, function, class, hook, skill, verb, config, template or script. A second flow
diagram appears only when the flow changed, inside `How`; add one rejected-alternative line.

`What this improves` lists Observability, Security, Traceability, End-user experience, Autonomy,
Stability, Performance, Maintainability, Cost, Portability and Accessibility. Mark each ⬆ improves,
➖ unchanged or ⬇ regresses; explain movement in one line, leave unchanged rows unexplained.
Other table glyphs use ✅ proved, ⚠️ a named gap and — not applicable; never use a glyph to hide
missing evidence. The catalogue supplies the heading glyphs; guards tolerate those prefixes. Hanten
declares an empty glyph because its compatibility contract requires the exact `## Adversarial review (hanten)` heading.

| Kind | `verify` title | Reading aid |
|---|---|---|
| product | How to verify | numbered manual steps, the `CON-17` literal |
| library / unknown | How a consumer verifies | Consumer scenario / Call or import / Expected, one row per touched public symbol, plus the command actually run against the published artifact |
| process | What the guards prove | Behavior changed / Lane or verb run / Refuses on / Passes on; name the fixture |

The non-product forms satisfy `CON-17(b)`'s observable proxy; the handbook is not amended.
Every kind's verify section also carries one Criterion / Coverage / Evidence row per AC id of each
closing issue (HR-11): `<CODE>#<N>/AC-<k>`, `<k>` the id as the issue writes it (`{n}`, or Akatsuki's
`{epic}-{nnn}`; the catalogue's acceptance row reads both, zheref/hatsu#411); satisfied · partial · missing · contradicts · unrequested;
a test name, path:line or scenario. `nen pr converge --catalogue contracts/issue-sections.json`
judges the table, its rules nen's (zheref/hatsu#413); an empty verify heading fails `body-check`.
Compatibility carries Symbol / Before / After / Consumer action and a semver verdict. Across
repositories answers what another repository does differently after merge, recording rulings.
Release unit carries Archive / Version / Size / Provenance / Verification and the `CON-22` fan-out. Rollout carries Target /
Flag / Rollback step. Product evidence uses [WORKFLOW's UZF-26 shape](WORKFLOW.md#the-uzf-26-evidence-shape).
Economics keeps Leorio's summary visible and the full report collapsed under `<details>`; demote its
internal headings to level 3 or deeper when embedding, preserving all report content and delta history.

## Check every write

Reader sections are capped at seven; first-heading Delivery, conditional Spec and Decisions, Hanten,
Completion checklist, Associated issues and final Agent attribution are outside that count. The footer's
substance is fixed: Hanten dispositions are settled and deferred rows cite tracked issues, checklist
claims cite evidence, issue closing lines belong under the Associated issues table, and
attribution records only actual participants under [the ledger contract](AGENT-ATTRIBUTION.md).
The prose budget is 150 words per section, excluding tables, fences and diagrams: warn, never refuse.

```bash
"$hatsu_root/scripts/pr_body_sections_check.sh" --body <absolute-body.md> \
  --requirements <absolute-requirements.json> --max <resolved-max>
"$hatsu_root/scripts/pr_body_delivery_check.sh" --body <absolute-body.md> --repo <effort-path> \
  [--base <ref>] --gate-forecast <G2|G4>   # before create: PR unread
"$hatsu_root/scripts/pr_body_delivery_check.sh" --body <absolute-body.md> --repo <effort-path> \
  --pr <n> --target <owner/name> [--base <ref>] --gate-forecast <G2|G4>  # after open/edit
nen pr body-check --body-from <absolute-body.md> --requirements-from <absolute-requirements.json>
"$hatsu_root/scripts/pr_body_evidence_check.sh" --body <absolute-body.md>
"$hatsu_root/scripts/pr_development_link_check.sh" --body <absolute-body.md> --target <owner/name>
```

Run all five before every create or body edit; the two Delivery guard lines are alternatives by PR
state. Its row check compares the actual effort ledgers of `--repo`'s checked-out branch, so `--repo` is the
effort's own worktree on its branch (an explicit `--effort <branch>` refuses a mismatch at exit 2); Drive is compared with the rendered
expectation using the caller's gate forecast and actual PR reference. The public Source cell carries
only ledger locator kind/index, timestamp and optional phase; free-form provenance stays in the private
repo-local `.nen/reports/` data files (directory 0700, files 0600). After either write, read back and run the Development
check with `--pr <owner/name#n> --base <base>`. The section guard refuses undeclared headings,
wrong order, missing sections and an eighth reader section. Keep declaration-derived changelog and
gate checks from `contracts/pr-composition.json` alongside them. The two HA#351 section scripts
remain interim under `BC-11`: Nen v0.24 carries NN#448's resolver verbs, but NN#464's envelope defect
blocks their adoption in Hatsu (HA#370). Existing configuration/path-set Python stays frozen.
No new guard replaces Mukai's review,
regression, coverage or evidence phases.
