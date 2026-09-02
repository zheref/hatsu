# Public redaction policy

This repository is published under the following redaction policy. Some of the work it records was
done against repositories that are **not** public, and naming them here would leak their existence,
their layout and their issue numbers to readers who cannot open them.

**The rule: no private repository is named anywhere in this repository's content.** Every URL, link,
slug, path and object id that pointed into one has been replaced with a stable placeholder, and every
link into one has been unlinked. The evidence itself is not deleted — a transcript that proved
something still proves it; only the name it was proved against is redacted.

## The legend

| Placeholder | What it stands for |
|---|---|
| `<reference-repo>` | The frozen reference implementation this plugin succeeds — the predecessor system whose local plane Hatsu replaces, and whose backlog the seventeen skills were proven against. Private. |
| `<migration-tracker>`, "the migration tracker (private)" | The repository tracking the Akatsuki migration, where the rewritten constitution and the ratified migration plan are decided. Private. |
| `<product-repo-A>` … `<product-repo-D>` | Consuming product repositories in the same estate, in no meaningful order. Private. |
| `<scaffold-repo>` | The scaffolding repository the estate generates consumers from. Private. |
| `<prefix>` | Stands in for a real repository-name prefix in an example about prefix matching. The example teaches the rule; the prefix itself named a private estate. |
| `RA`, `RB`, `RC`, `RD` | Placeholder **product codes** for `<product-repo-A>` … `<product-repo-D>`, used wherever a registry row, refusal message or command example paired a code with one of those repositories. Their real codes shared a prefix with a public repository's code in the same registry, which reconstructed the family name. |
| `RR-IS-#<n>` / `RR-PR-#<n>`, `RA-IS-#<n>` / `RA-PR-#<n>`, … | Object ids that named a private repository by its product code. |

Placeholders composed with the existing path convention keep that convention: `<reference-repo checkout>`
means "a local checkout of the frozen reference implementation", exactly as `<checkout>`, `<cache>` and
`<scratch>` are used in [`docs/ab/`](ab/).

## The object-id rule, stated once

**Object ids of *any* private repository take the placeholder-letter prefix** — `RR-` for
`<reference-repo>`, `RA-`/`RB-`/`RC-`/`RD-` for `<product-repo-A>` … `<product-repo-D>` — in both
directions, `-IS-` and `-PR-`. The **number is kept**: a bare number identifies nothing on its own,
and the transcripts are evidence that must stay checkable against itself.

**Bare `<code>#<n>` and `<code>@<gate>` forms in transcripts stay as they are.** `BC#918`,
`RA@high`, `BC@G4` are the invocation grammar the skills parse — taxonomy tokens, not object ids —
and a skill that could not show its own grammar could not teach it.

**Tracker issue numbers are dropped, not placeheld.** Where the text pointed at an issue in the
private migration tracker, the pointer becomes "the migration tracker (private)" with no number: the
number identifies nothing publicly, and the tracker cannot be opened to check it. Numbers in the
frozen reference implementation's own transcripts (`<reference-repo>#N`, `RR-PR-#916`) **stay** —
they are the evidence's internal cross-references.

## What is deliberately **not** redacted

- **`bankai:` label namespaces** (`bankai:severity/high`, `bankai:wake/iterate`, …) and product codes
  (`BC`, `BS`, `KC`, and the placeholder codes above). These are taxonomy read out of the target
  repository's own registry at run time, not repository names — a skill that could not say
  `bankai:epic` could not do its job.
- **Clause and rule ids** — `CON-25`, `QA-15`, `UZF-26`, `SW-{n}` and the rest. They are the upstream
  constitution's and handbooks' own vocabulary, cited by id the way a statute is.
- **"Akatsuki"** — the trailer `Akatsuki-Agent:`, the plugin keyword, and every prose mention. It is
  the name of the *system* Hatsu is the local plane of, not the name of a repository; redacting it
  would make the roster and the agent trailers unreadable without hiding anything a reader could open.
- **Stack handbook names** (`swiftui-tca-uzf-v2`, `compose-uzf-v2`, `react-uzf-v1`) and their rule
  prefixes. They are canon names carried in the tooling's own fixtures, not repository names.
- **The plugin name "bankai"** where it means the predecessor plugin a reader may already have installed
  (the rollback line in [`README.md`](../README.md)).
- **Public repositories** — `zheref/nen`, `zheref/kro-pwa`, and this repository — which readers can open.
- **Version tags** (`v0.11.3`), issue and PR *numbers*, dates, and every verdict, count and transcript
  line. Facts stay; names go.

## Where an id was load-bearing

Where an incident id carried the provenance of a rule — "this guard exists because of that incident" —
the **fact** is kept in words and the id is dropped, rather than replacing one opaque token with another.
See the incident record at the head of
[`scripts/plugin_bump_check.sh`](../scripts/plugin_bump_check.sh).

## Scope

Tree content and GitHub issue bodies. The commit messages and pull-request bodies of past changes are
history and are out of scope; git history is what it is.
