<!--
  spiritual-message.md -- the turn and landing report as Markdown, for a surface whose native report
  is a Markdown artifact (Antigravity). Filled by the same verb, from the SAME data document and the
  SAME reports.sections.<variant>.blocks as templates/spiritual-message.html: one document, two
  renders, so the two cannot disagree on which blocks a variant shows. Block for block it mirrors
  that file, in its order and under its headings; each block opens with a block-marker comment
  the report-markdown-guard lane reads. Structure, escaping and the checked examples:
  docs/PROCESS.md, The Markdown report. NOTHING IN THIS COMMENT SPELLS A SUBSTITUTION TAG.
-->
{{#if sections.masthead}}<!-- hatsu:block masthead -->
# {{title}}

{{turnLabel}} · Hatsu · spiritual-message · {{variant}}

{{repo}} · against {{base}} · {{generatedAtLocal}}

stage {{effortStage}} · {{gate}} · worktree {{worktree}} · branch {{branch}}

{{/if}}{{#if sections.tally}}<!-- hatsu:block tally -->

| need you | blockers | landed | gaps |
|---:|---:|---:|---:|
| {{tallyNeedsYou}} | {{tallyBlockers}} | {{tallyLanded}} | {{tallyGaps}} |

{{/if}}{{#if sections.desk}}<!-- hatsu:block desk -->
## Your desk
{{#if ask}}
<!-- hatsu:ask -->
**{{ask.kind}}** · {{ask.gate}}

### {{ask.question}}

{{ask.whyNow}}

{{#each ask.options}}- **{{letter}}** · {{label}}{{#if star}} ⭐ {{star}}{{/if}}\
  {{consequence}}
  <pre>{{command}}</pre>
{{/each}}
{{#if ask.objects}}Objects:{{#each ask.objects}} [{{label}}](<{{url}}>){{/each}}
{{/if}}{{#each readiness}}
> [!IMPORTANT]
> **{{gate}} readiness, verbatim:** “{{verdict}}”\
> {{reason}}
{{/each}}{{#if ask.blocker}}
<details id="g5-blocker" open>
<summary>Why this is a G5 — the evidence</summary>

> [!CAUTION]
> {{ask.blocker.rule}} · stopped at {{ask.blocker.step}} · after {{ask.blocker.executedAfter}}
>
> {{ask.blocker.why}}
>
> **Next action:** {{ask.blocker.nextAction}}

{{#each ask.blocker.findings}}- {{text}}
{{/each}}
</details>
{{/if}}{{/if}}{{#if deskCleared}}
> [!NOTE]
> **cleared**\
> {{deskCleared}}
{{/if}}

{{/if}}{{#if sections.lastTurn}}<!-- hatsu:block lastTurn -->
## This last turn

{{lastTurnRequest}}

<details>
<summary>The request, in full</summary>

<pre>{{lastTurnRequestFull}}</pre>

</details>

{{#each lastTurnHighlights}}- {{outcome}} · {{text}} — {{why}}
{{/each}}{{#if mukaiLastTurn}}
### Corrections, check fallout and half-run stops

Corrections:

{{#each lastTurnCorrections}}- {{what}} · asked by {{who}} · why: {{whyAsked}} · handled: {{howHandled}}
{{/each}}
Check fallout:

{{#each lastTurnCheckIssues}}- {{check}} · found: {{issue}} · handled: {{howHandled}}
{{/each}}
Half-run stops:

{{#each lastTurnStops}}- {{why}} · autonomy: {{autonomy}} · policy: {{policy}}
{{/each}}{{/if}}

{{/if}}{{#if sections.landed}}<!-- hatsu:block landed -->
## Landed, fought back, not delivered

The whole session against {{base}}, not just this turn.

### Landed

{{#each accomplished}}- {{text}} — {{why}}
{{/each}}
### Fought back

{{#each challenges}}- {{text}} — {{why}}
{{/each}}
### Not delivered

{{#each notDelivered}}- {{text}} — {{why}}
{{/each}}

{{/if}}{{#if sections.delta}}<!-- hatsu:block delta -->
## Architecture delta

{{architectureCaption}}

```mermaid
{{{graphMermaid}}}
```

<details>
<summary>The same delta as text — nodes and edges</summary>

Nodes:

{{#each graphNodes}}- {{label}} · {{kind}} · {{change}}
{{/each}}
Edges:

{{#each graphEdges}}- {{from}} → {{rel}} → {{to}} · {{change}}
{{/each}}
</details>

{{/if}}{{#if sections.evidence}}<!-- hatsu:block evidence -->
## Evidence
{{#if evidenceUnavailable}}
> [!NOTE]
> {{evidenceUnavailable}}
{{/if}}
{{#each captures}}![{{alt}}](<{{src}}>)\
{{role}}

{{/each}}### Tests

{{#each tests}}- {{status}} · {{suite}} — {{name}}
{{/each}}
### Touched-file coverage
{{#if coverage}}
{{coverage.lane}} · {{coverage.path}} · {{coverage.format}} · {{coverage.total.lines.percent}}% overall
{{/if}}
| File | Lines | Band |
|---|---:|---|
{{#each touchedCoverage}}| {{file}} | {{percent}}% | {{band}} |
{{/each}}

{{/if}}{{#if sections.spend}}<!-- hatsu:block spend -->
## Spend

### Where the time went
{{#if hasSpendPhases}}
| Phase | Share | Time | Steps |
|---|---:|---:|---|
{{#each spendPhases}}| {{lane}} | {{percent}}% | {{amount}} | {{steps}} |
{{/each}}{{/if}}{{#if noSpendPhases}}
no phase ledger was recorded for this effort
{{/if}}
### Tokens by model

| Surface | Model | Input | Output | Cache read | Cache write | Minutes | Source |
|---|---|---:|---:|---:|---:|---:|---|
{{#each spendUsage}}| {{surface}} | {{model}} |{{#if notReported}} not reported | | | | | |{{/if}}{{#if reported}} {{input}} | {{output}} | {{cacheRead}} | {{cacheWrite}} | {{minutes}} | {{source}} |{{/if}}
{{/each}}
Actions minutes: {{actionsMinutes}}
{{#if spendNote}}
{{spendNote}}
{{/if}}

{{/if}}{{#if sections.launch}}<!-- hatsu:block launch -->
## How to launch

<pre>{{launch}}</pre>

{{/if}}{{#if sections.decisions}}<!-- hatsu:block decisions -->
## Decisions already made

{{#each decisions}}- {{text}} — {{why}}
{{/each}}

{{/if}}{{#if sections.prBody}}<!-- hatsu:block prBody -->
## The pull request body

<details>
<summary>As it was posted</summary>

{{#each prBody}}<pre>{{markdown}}</pre>

{{/each}}</details>

{{/if}}---

{{turnLabel}} · {{effortStage}} · {{gate}} · {{worktree}} · {{branch}}

{{repo}} · against {{base}} · {{variant}} · {{generatedAtLocal}}

{{footerNote}}
