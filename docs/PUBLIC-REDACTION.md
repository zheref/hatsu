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
| `<reference-repo>` | The frozen reference implementation this plugin succeeds — the predecessor system whose local plane Hatsu replaces, and whose backlog the seventeen skills were proven against. Private. Its handbooks, constitution and shared agent conventions were migrated on 2026-09-28 into the public `zheref/bankai-handbooks` (see *What is deliberately not redacted*), which is named directly; where `<reference-repo>` survives it means the frozen predecessor — its rulings, its backlog, its gates file, its transcripts — never where canon lives. |
| `<migration-tracker>`, "the migration tracker (private)" | The repository tracking the Akatsuki migration, where the rewritten constitution and the ratified migration plan are decided. Private. |
| `<ci-plane-repo>` | The repository of Akatsuki, the autonomous CI plane — its constitution, agent workflows and CI CLI; ruled a canon repository on 2026-09-19. Private. Named for its role; it is not asserted to be the same repository as `<migration-tracker>`. |
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
- **"Akatsuki"** — the CI plane's trailer `Akatsuki-Agent:`, the plugin keyword, and every prose
  mention. It is the name of the *system* Hatsu is the local plane of, not the name of a repository;
  redacting it would make the roster and the two provenance trailers unreadable without hiding anything a
  reader could open. Hatsu's own trailer, `Hatsu-Agent:`, is named for the same reason.
- **Stack handbook names** (`swiftui-tca-uzf-v2`, `compose-uzf-v2`, `react-uzf-v1`, `bankai-machinery`) and
  their rule prefixes. They are canon names carried in the tooling's own fixtures, not repository names;
  `bankai-machinery` replaced, at handbook set v0.6, a scenario id that *was* the frozen repository's own
  name, and its `BC-` prefix is kept so existing citations stay valid.
- **The plugin name "bankai"** where it means the predecessor plugin a reader may already have installed
  (the rollback line in [`README.md`](../README.md)).
- **Public repositories** — `zheref/nen`, `zheref/kro-pwa`, this repository, and **`zheref/bankai-handbooks`**,
  the canon repository (public, MIT): the Bankai handbooks, `CONSTITUTION.md` (`CON-{n}`) and the shared
  agent conventions live there since 2026-09-28 (`CON-13`), it is named directly and never placeheld, and
  the tag Hatsu reads is pinned in `nen/repos.json` (`maintained_tools` → `pinned`). Readers can open every
  one of these.
- **Product names and app identifiers** — the `Kro` product, its bundle id `io.zheref.kro`, and
  simulator names in transcripts. The product is public through `zheref/kro-pwa`, and this policy
  redacts *repositories*: the private repositories behind the product are placeheld
  (`<product-repo-A>`, `<product-repo-B>`), the product they ship is not.
- **The predecessor generator's marker**, `<!-- GENERATED from bankai-core@`, where `hatsu:limbo` and
  [`docs/ab/limbo.md`](ab/limbo.md) quote it. It is the literal first line of files a consumer
  still carries, matched byte for byte: a placeholder there would match nothing, and limbo would miss
  the one file it exists to catch. Everywhere else the predecessor is `<reference-repo>`.
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
