# Public redaction policy

This repository is published under the following redaction policy. Some of the work it records was
done against repositories that are **not** public, and naming them here would leak their existence,
their layout and their issue numbers to readers who cannot open them.

**The rule: no private repository is named anywhere in this repository's content.** Every URL, link,
slug, path and object id that pointed into one has been replaced with a stable placeholder, and every
link into one has been unlinked. The evidence itself is not deleted — a transcript that proved
something still proves it; only the name it was proved against is redacted. **One private repository
is named by ruling** — `zheref/akatsuki-ai`, whose code stays private and whose name is public
(§ *Named private repositories*); every other private repository is still placeheld.

## The legend

| Placeholder | What it stands for |
|---|---|
| `<reference-repo>` | The frozen reference implementation this plugin succeeds — the predecessor system whose local plane Hatsu replaces, and whose backlog the seventeen skills were proven against. Private. Its handbooks, constitution and shared agent conventions were migrated on 2026-09-28 into the public `zheref/bankai-handbooks` (see *What is deliberately not redacted*), which is named directly; where `<reference-repo>` survives it means the frozen predecessor — its rulings, its backlog, its gates file, its transcripts — never where canon lives. |
| `<migration-tracker>`, "the migration tracker (private)" | The repository tracking the Akatsuki migration, where the rewritten constitution and the ratified migration plan are decided. Private. |
| `<ci-plane-repo>` | The repository of Akatsuki, the autonomous CI plane — its constitution, agent workflows and CI CLI; ruled a canon repository on 2026-09-19. Private. Named for its role; it is not asserted to be the same repository as `<migration-tracker>`. **Named since 2026-10-19**: it is `zheref/akatsuki-ai`, product code `AK` (§ *Named private repositories*). New text names it; the placeholder's existing uses stand and are not rewritten. |
| `<product-repo-A>` … `<product-repo-E>` | Consuming product repositories in the same estate, in no meaningful order. Private. **One letter per repository, for good**: a letter already in the tree is read off its existing uses before a new repository is given one, and never reassigned. |
| `<scaffold-repo>` | The scaffolding repository the estate generates consumers from. Private. |
| `<prefix>` | Stands in for a real repository-name prefix in an example about prefix matching. The example teaches the rule; the prefix itself named a private estate. |
| `RA` … `RE` | Placeholder **product codes** for `<product-repo-A>` … `<product-repo-E>`, used wherever a registry row, refusal message or command example paired a code with one of those repositories. Their real codes shared a prefix with a public repository's code in the same registry, which reconstructed the family name. |
| `RR-IS-#<n>` / `RR-PR-#<n>`, `RA-IS-#<n>` / `RA-PR-#<n>`, … | Object ids that named a private repository by its product code. |
| `fixture-family`, `fixture-owner/fixture-ios`, `fixture-owner/fixture-android`, `fixture-owner/fixture-web`, `fixture-owner/fixture-spec`; `FI`, `FA`, `FW`, `FS` | A **fictional** product family, slug-shaped so nen's verbs read it, and its codes, in `scripts/fixtures/port-family/` and the evidence `hatsu:kamui` pastes into a Hatsu PR (zheref/hatsu#356). They stand for **no** repository: never map a fixture code onto a placeheld letter (`<product-repo-A>` … `<product-repo-E>`); the fixture's platforms are fiction. **Offline only**: never passed to `gh` or any networked verb (`fixture-owner` is an unclaimed login). |
| `<bundle-id>`, `<simulator-n>`, `<android-serial-n>`, `<udid-n>`, `<name>` | Inside transcripts: the app identifier and simulator names that tie the product family to a placeheld repository, a physical device's hardware serial or UDID, and a third party's name in a device name. Numbered where one transcript tells two devices apart, so it still proves what it proved. The maintainer's own name stays, as it does in every commit's authorship. |

Placeholders composed with the existing path convention keep that convention: `<reference-repo checkout>`
means "a local checkout of the frozen reference implementation", exactly as `<checkout>`, `<cache>` and
`<scratch>` are used in [`docs/ab/`](ab/).

## The object-id rule, stated once

**Object ids of *any* private repository take the placeholder-letter prefix** — `RR-` for
`<reference-repo>`, `RA-` … `RE-` for `<product-repo-A>` … `<product-repo-E>` — in both
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

## Named private repositories — the one exception

**The maintainer's ruling of 2026-10-19** ([`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-19 — the Akatsuki CI repository is named*), typed
in the picker's free field when zheref/hatsu#329 asked how the CI repository should be registered:

> Since akatsuki-ai is a private repository we don't want to avoid people hearing from, this is the
> only exception when avoiding to name private repositories. We can name this one despite staying
> code-private. So, feel free to mention it open.

- **What is named:** `zheref/akatsuki-ai` — Akatsuki's CI plane, the repository the legend calls
  `<ci-plane-repo>` — its slug, its short name, its product code `AK`, its links, and its object ids as
  `AK-IS-#<n>` / `AK-PR-#<n>` (the object-id rule's placeholder prefix does not apply to it). It may
  stand in this tree, in a public issue or PR body, and in `nen/repos.json`.
- **What is not:** its contents. The repository stays private, and the ruling makes its *name* public.
  It does not make its files, prose or transcripts public — this run's reading, the maintainer's to correct.
- **Where the exception lives:** [`scripts/private_name_named.txt`](../scripts/private_name_named.txt),
  one exact `owner/name` per line. The guard reads it by default and drops exactly that repository
  from the private list, so a same-named private repository under another owner is still a hit. A bare
  name there is a refusal. Only a recorded ruling adds a line, and the `redaction-guard` fixture pins
  the entry set, so an unruled line turns that lane red. Committing it publishes nothing the
  ruling did not, which is why it may live in this tree when the ignore file may not.
- **What it settles:** `AK` is a registered product code (`nen/repos.json` → `maintained_tools`,
  `product_codes`), so `nen repo resolve AK` answers `via code` from a Hatsu checkout and `nen repo
  classify --target zheref/akatsuki-ai` answers role canon (gate G4). `hatsu:file`, `classify`, `direct` and
  `build` resolve `AK#<n>` here as they resolve `HA#<n>`. A text bound for `AK` itself is still a
  private target, and the guard skips it. zheref/hatsu#329's two other shapes, a git-ignored overlay
  and a committed placeholder row, are not built: for this repository the ruling removes the problem.
- **Every other private repository is unchanged:** placeheld, never registered here. A second named
  repository needs a second ruling and a second line.

## What is deliberately **not** redacted

- **The named private repository** — `zheref/akatsuki-ai` and its code `AK` (§ *Named private
  repositories*), by the ruling of 2026-10-19, and no other.

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
- **A template token under `templates/`** — `{{name}}`, `{{{name}}}`, `{{#each name}}`, `{{#if name}}`,
  `{{#unless name}}`, `{{/name}}`, the braces touching the name, in a `.md` or `.html` file — is one of
  `nen report render`'s data-document keys, which this repository does not choose (the maintainer's ruling
  of 2026-10-13, [`ROSTER.md`](ROSTER.md) § *Rulings of 2026-10-13*, small ruling 1). It is exempt in that
  shape only, on the line as written: the same name as prose, in a comment or a tag, split by markup or an
  entity, or anywhere outside `templates/`, is a hit.
- **Stack handbook names** (`swiftui-tca-uzf-v2`, `compose-uzf-v2`, `react-uzf-v1`, `bankai-machinery`) and
  their rule prefixes. They are canon names carried in the tooling's own fixtures, not repository names;
  `bankai-machinery` replaced, at handbook set v0.6, a scenario id that *was* the frozen repository's own
  name, and its `BC-` prefix is kept so existing citations stay valid.
- **The plugin name "bankai"** where it means the predecessor plugin a reader may already have installed
  (the rollback paragraph in [`docs/using/claude-code.md`](using/claude-code.md) § 5).
- **Public repositories** — `zheref/nen`, `zheref/kro-pwa`, this repository, and **`zheref/bankai-handbooks`**,
  the canon repository (public, MIT): the Bankai handbooks, `CONSTITUTION.md` (`CON-{n}`) and the shared
  agent conventions live there since 2026-09-28 (`CON-13`), it is named directly and never placeheld, and
  the tag Hatsu reads is pinned in `nen/repos.json` (`maintained_tools` → `pinned`). Readers can open every
  one of these. A public name that contains a private one is written as its own name and never
  composed with a placeholder, which would tie that placeholder to the public name for anyone listing the
  public repositories (Feitan, HA-PR-#305).
- **The predecessor generator's marker** where it is quoted as a marker — `hatsu:limbo`, its mirrors
  and [`docs/ab/limbo.md`](ab/limbo.md). It is the literal first line of files a consumer
  still carries, and limbo matches it byte for byte: a placeholder there would match nothing, and limbo
  would miss the one file it exists to catch. **The marker names the predecessor's repository, so it
  makes `<reference-repo>` identifiable**; nothing here relies on that placeholder for secrecy, and
  prose that means the predecessor says so in words or writes `<reference-repo>`.
- **Version tags** (`v0.11.3`), issue and PR *numbers*, dates, and every verdict, count and transcript
  line. Facts stay; names go.

## Where an id was load-bearing

Where an incident id carried the provenance of a rule — "this guard exists because of that incident" —
the **fact** is kept in words and the id is dropped, rather than replacing one opaque token with another.
See the incident record at the head of
[`scripts/plugin_bump_check.sh`](../scripts/plugin_bump_check.sh).

## How it is guarded

[`scripts/private_name_check.sh`](../scripts/private_name_check.sh) compares text against the **live**
private list — every private repository the maintainer's own credentials can see, whoever owns it
(`gh api 'user/repos?visibility=private'`, paginated) — by bare name, case-insensitive, whole-word
(`_` and `.` bound a word, so markdown emphasis is a hit), `owner/name` slugs and URLs included. A
line that could hide a name is also read normalised — URL encoding, HTML entities, inline tags,
backslash escapes, NFKC, invisible format characters and dashes — and then with HTML comments, `*`
and backticks removed, so intraword emphasis, a code span or a comment splitting a name is still a
hit. Those transformations are the whole claim: an intraword `_` is not removed, because CommonMark
never renders it as emphasis. A list that reads empty, or one the ignore file or the named list empties, is a refusal,
never a pass. The list is never committed here and never cached in the
tree; a CI form needs it as a secret (`--names-file`). A hit, a path and a label are printed with an
index into that list, never the name; a path or label that names a repository only once normalised is
withheld whole. Of the exemptions above two can hold a repository name, and both pass by shape alone:
the predecessor generator's marker, only as the exact `<!-- GENERATED from <name>@` shape and only for
the name `hatsu:limbo`'s own marker line carries; and a template token in the four report templates `nen report render` fills, only as written
(never once normalised; § *What is deliberately not redacted*). Names the maintainer rules too generic to police (a
repository called after an ordinary word) go in an ignore file on their own machine, never in this
tree, and only the maintainer writes it. The one name ruled public (§ *Named private repositories*)
is the opposite case: the guard reads it from the committed named list, as an exact `owner/name`.

- **Issue text:** [`hatsu:file`](../claude/skills/file/SKILL.md) § 4 runs it on every drafted title,
  body and comment before the plan, so the plan shows checked text; § 8 forbids writing to a public
  repository anything it has not passed. [`hatsu:backlog-synthesis`](../claude/skills/backlog-synthesis/SKILL.md),
  [`hatsu:mugetsu`](../claude/skills/mugetsu/SKILL.md) § 7 and
  [`hatsu:sharingan`](../claude/skills/sharingan/SKILL.md) § 7 run it before their own `nen issue`
  writes. A private target is skipped. From nen `v0.20.0` (zheref/nen#367, closing zheref/nen#329) `nen issue file`,
  `comment` and `edit-body` refuse a private name bound for a public target at exit `4`, reading the
  ignore file they are passed; the flag takes one file, so `file` § 4's ignore file joins the named list
  and the maintainer's ignore file, and every skill that writes through nen passes that one (until zheref/nen#441); a raw `gh` write, `issue consolidate-close`'s close comments and
  the `pr` writers (zheref/nen#363) remain unguarded outside these skills. **Rewriting a public issue
  is not the end of it:** GitHub keeps every earlier revision in the issue's public edit history, so the
  maintainer deletes each pre-rewrite revision ("Delete revision from history") and re-reads
  `userContentEdits` until none is left, and a title change leaves a rename event no edit removes (a
  GitHub Support request; never retitle it again) — the #149 sitting of 2026-10-14 found both.
- **Tree content:** `bash scripts/private_name_check.sh --tree .`, run by the maintainer, reads every
  tracked and untracked-not-ignored file's contents, its path and a symlink's target, and counts what
  it skips. **The tree reads clean on 2026-10-18 but for ordinary-word names** (HA-PR-#305, zheref/hatsu#289 item 10): three entries on the live list are English words used as words (`docs/DISCOVERY.md`, `docs/WORKFLOW.md`, the skills), and the ignore file carries them — the maintainer's, one `name` or `owner/name` per line, written by `bash scripts/private_name_check.sh --resolve <k>` read at a terminal, never by a session. The tree check is the `redaction-tree` lane (`nen shu test --lane redaction-tree --repo <hatsu>`), run on the maintainer's credentials with that ignore file: issue #149's criterion 2(b), landed. It is still not a CI step, because CI holds no private list. **Without the ignore file the lane is red by design**, and the guard says so — `no ignore file, so nothing ignored`, never `0 ignored` — so a session reports the refusal's mention count and its distinct-index count and hands the red lane to the maintainer — to run with the ignore file, or to resolve the indices at a terminal; a session never judges a refusal to be no leak, and never writes the file to turn the lane green.

## Scope

Tree content and GitHub issue bodies. The commit messages and pull-request bodies of past changes are
history and are out of scope; git history is what it is.
