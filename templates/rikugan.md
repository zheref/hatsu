<!--
  rikugan.md -- the desk and the register as Markdown, for a surface whose native report is a
  Markdown artifact (Antigravity). Filled by the same verb, from the SAME register document
  (nen report data with a register desk) and the SAME reports.sections.<variant>.blocks as
  templates/rikugan.html: one document, two renders, so the two cannot disagree on which blocks a
  variant shows. Block for block it mirrors that file, in its order and under its headings; each
  block opens with a block-marker comment and each ask with an ask-marker comment, which the
  report-markdown-guard lane reads. Structure, escaping and the checked examples:
  docs/PROCESS.md, The Markdown report. NOTHING IN THIS COMMENT SPELLS A SUBSTITUTION TAG.
-->
{{#if sections.masthead}}<!-- hatsu:block masthead -->
# {{title}}

Hatsu · rikugan · {{variant}}

{{scope}} · {{gate}} · {{generatedAtLocal}}

{{/if}}{{#if sections.tally}}<!-- hatsu:block tally -->

| in scope | need you | blockers | ready | in flight |
|---:|---:|---:|---:|---:|
| {{tallyScope}} | {{tallyNeedsYou}} | {{tallyBlockers}} | {{tallyReady}} | {{tallyInFlight}} |

{{/if}}{{#if sections.desk}}<!-- hatsu:block desk -->
## Your desk
{{#each gates}}
### {{gate}} · {{label}}
{{#each asks}}
<!-- hatsu:ask -->
**{{kind}}** · rank {{rank}}

#### {{title}}

{{why}}

{{#each options}}- **{{letter}}** · {{label}}{{#if star}} ⭐ {{star}}{{/if}}\
  {{consequence}}
{{#if command}}  <pre>{{command}}</pre>
{{/if}}{{/each}}
{{#if objects}}Objects:{{#each objects}} [{{label}}](<{{url}}>){{/each}}
{{/if}}{{#if verdict}}
> [!IMPORTANT]
> **Readiness, verbatim:** “{{verdict}}”
{{/if}}{{/each}}{{#if cleared}}
> [!NOTE]
> **cleared**\
> {{cleared}}
{{/if}}{{/each}}

{{/if}}{{#if sections.register}}<!-- hatsu:block register -->
## The register

One row per issue and pull request in scope. Open a row for its gate, its verdict and what it is waiting on.

{{#each objects}}<details>
<summary>{{notation}} · {{title}} · {{marks}} · {{gate}}</summary>

- State: {{state}} · {{labelsLine}}
- Verdict: {{verdict}}
- Checks: {{checksLine}}
- Threads: {{threadsLine}}
- Linked: {{linkedLine}}
- Needs: {{needs}}
- Driving: {{session}} · lane {{lane}}
- Head: {{head}}
- Thought: {{thought}}
- Link: [{{url}}](<{{url}}>)

</details>

{{/each}}{{#if graphNodes}}### {{architectureCaption}}

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
{{/if}}

{{/if}}{{#if sections.spend}}<!-- hatsu:block spend -->
## Spend
{{#each spendEfforts}}
### {{name}}

#### Where the time went
{{#if hasSpendPhases}}
| Phase | Share | Time | Steps |
|---|---:|---:|---|
{{#each spendPhases}}| {{lane}} | {{percent}}% | {{amount}} | {{steps}} |
{{/each}}{{/if}}{{#if noSpendPhases}}
no phase ledger was recorded for this effort
{{/if}}
#### Tokens by model

| Surface | Model | Input | Output | Cache read | Cache write | Minutes | Source |
|---|---|---:|---:|---:|---:|---:|---|
{{#each spendUsage}}| {{surface}} | {{model}} |{{#if notReported}} not reported | | | | | |{{/if}}{{#if reported}} {{input}} | {{output}} | {{cacheRead}} | {{cacheWrite}} | {{minutes}} | {{source}} |{{/if}}
{{/each}}
Actions minutes: {{actionsMinutes}}
{{#if spendNote}}
{{spendNote}}
{{/if}}{{/each}}

{{/if}}{{#if sections.legend}}<!-- hatsu:block legend -->
## Legend

- ⭐ — the recommended option on an ask: exactly one per ask, and the same one the surface's own picker stars
- Grouped by gate — the desk is ordered by gate, then by how much each answer unblocks. A gate with nothing owed is shown cleared, never hidden
{{#each legendRows}}- {{mark}} — {{meaning}}
{{/each}}

{{/if}}---

{{footerCount}}

{{scope}} · {{variant}} · {{generatedAtLocal}}

{{footerNote}}
