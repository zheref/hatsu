# Public redaction policy

This repository is public. Some of the work it records was done against repositories that are **not**
public, and naming them here would leak their existence, their layout and their issue numbers to readers
who cannot open them.

**The rule: no private repository is named anywhere in this repository's content.** Every URL, link, slug,
path and object id that pointed into one has been replaced with a stable placeholder, and every link into
one has been unlinked. The evidence itself is not deleted — a transcript that proved something still proves
it; only the name it was proved against is redacted.

## The legend

| Placeholder | What it stands for |
|---|---|
| `<reference-repo>` | The frozen reference implementation this plugin succeeds — the predecessor system whose local plane Hatsu replaces, and whose backlog the seventeen skills were proven against. Private. |
| `<migration-tracker>`, "the migration tracker (private)" | The repository tracking the Akatsuki migration, where the rewritten constitution and the ratified migration plan are decided. Private. |
| `<product-repo-A>` … `<product-repo-D>` | Consuming product repositories in the same estate, in no meaningful order. Private. |
| `<scaffold-repo>` | The scaffolding repository the estate generates consumers from. Private. |
| `RR-IS-#<n>` / `RR-PR-#<n>` | Object ids that named the reference implementation by its product code. The code is replaced; the number is kept, because a bare number identifies nothing on its own. |

Placeholders composed with the existing path convention keep that convention: `<reference-repo checkout>`
means "a local checkout of the frozen reference implementation", exactly as `<checkout>`, `<cache>` and
`<scratch>` are used in [`docs/ab/`](ab/).

## What is deliberately **not** redacted

- **`bankai:` label namespaces** (`bankai:severity/high`, `bankai:wake/iterate`, …) and product codes
  (`BC`, `KP`, `KN`, …). These are taxonomy read out of the target repository's own registry at run time,
  not repository names — a skill that could not say `bankai:epic` could not do its job.
- **Clause and rule ids** — `CON-25`, `QA-15`, `UZF-26`, `SW-{n}` and the rest. They are the upstream
  constitution's and handbooks' own vocabulary, cited by id the way a statute is.
- **The plugin name "bankai"** where it means the predecessor plugin a reader may already have installed
  (the rollback line in [`README.md`](../README.md)).
- **Public repositories** — `zheref/nen`, `zheref/hatsu`, `zheref/kro-pwa` — which readers can open.
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
