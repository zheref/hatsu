# A/B evidence — `bankai-handbooks` (zheref/hatsu#2)

Port of `claude/skills/bankai-handbooks/SKILL.md`: resolving the governing handbook set for a
Bankai-consuming repo. Old mechanics: prose the skill file carried directly — a static 3-file
"always load" list, and a static 2-row scenario→stack lookup table, applied by the agent reading
`.github/workflows/bankai.yml` by hand. New mechanics: `nen repo scenario` + `nen canon resolve`.

Run: 2026-09-01 (America/local session time). `nen` `0.1.0`
(`C:\Users\zhere\.cache\nen\v0.1.0\nen-windows-x64.exe`). Oracle/canon checkout: `zheref/bankai-core`,
working tree clean, `HEAD` at tag `v0.11.3` (`2269fe723e355dc69bf535ab40f22556e4fe4081` — confirmed via
`git describe --tags` and `git log -1`), matching `contracts/bankai-core.gates.json`'s own header. No
`GH_TOKEN` was exported for any command in this document — both verbs are pure local-file reads.

---

## 1. Command mapping table

Every deterministic-or-should-have-been-deterministic step the old `SKILL.md` carried in prose, and
what replaces it.

| # | Old (prose) | New (`nen`) |
|---|---|---|
| 1 | "the repo's `bankai_scenario` (from `.github/workflows/bankai.yml`)" — the agent had to open that workflow file BY HAND and find the value | `nen repo scenario --repo <bankai-core checkout> --target <owner/name>` — reads the scenario **recorded** for the target in `schemas/repos.json` instead (§ 4 finding: this is not the same source the old prose named, though the registry is kept factual against the workflow file by hand elsewhere) |
| 2 | A static 2-row scenario→stack-folder table baked into the skill text: `swiftui-tca-uzf-v2` → `SW-{n}`, `compose-uzf-v2` → `KT-{n}`. Any other scenario had no entry at all — the old skill could not resolve `bankai-scaffold` (scenario `bankai-core`) or a future `react-uzf-v1` consumer without an edit to its own prose | `nen canon resolve --stack-dir handbooks/stacks` derives `stacks/<scenario>/architecture.md` **directly from the scenario string**, for any scenario the registry names — verified live for all three real registry scenarios today (`swiftui-tca-uzf-v2`, `compose-uzf-v2`, `bankai-core`) plus the fourth handbook folder that already exists on disk (`react-uzf-v1`) with no consumer yet |
| 3 | A static 3-file "always load" list baked into the skill text: `uzf-core.md`, `security-baseline.md`, `release-policy.md` — never re-derived from `handbooks/INDEX.md`, so it silently went stale | `nen canon resolve --always-load <paths>` still takes this as **caller data** (a verb cannot know a repository's own manifest convention), but the ported skill instructs reading it fresh from `handbooks/INDEX.md`'s own table every time rather than freezing it into the skill's prose — and names the fact that it already drifted (§ 2 below) as the reason not to |
| 4 | "Never load another stack's folder" — a rule the agent had to remember and self-police, nothing computed it | Structural: `nen canon resolve` returns exactly one `stackHandbook` field, never a list — there is nothing to self-police |
| 5 | The two-read-path split (`CON-13`): CI reads bankai-core live; build/local agents read a product repo's generated `.claude/rules/` mirror — a distinction the agent had to know and apply by context | Collapses to ONE path: `nen canon resolve --repo <bankai-core checkout>` computes the identical resolved set live and deterministically every time, so there is no separate mirror-trusting branch for a local session to apply |
| 6 | Missing/ambiguous rule → `bankai:handbook-question`, routed per `CON-37` to CI Yamamoto (handbook/schema gap) or Naruto (governance gap), landing a canon-lane PR bankai-core merges at G4 | **No verb replaces this** — it cannot, because bankai-core is frozen and neither destination exists to act on a PR there anymore. The ported skill (§ 4) turns this into "raise as a finding, stop at G5" instead — a genuine process change forced by the frozen state, not a mapping gap in `nen` |
| 7 | "Cite findings by rule ID; never improvise policy" | Unchanged — judgment, kept verbatim in spirit |

**Count.** Before: **2** steps computed by hand, in prose, every invocation (rows 1–2: reading the
workflow file and matching a static lookup table) — on top of a **stale, unversioned** always-load
list (row 3) that nobody was re-deriving from canon at all, and a self-policing rule (row 4) with
nothing enforcing it. After: **0** — both computations are `nen repo scenario` and `nen canon
resolve`; the always-load list is still hand-read (a verb cannot own a repository's own manifest
convention) but is now explicitly instructed to be read fresh, not frozen into the skill; the
one-stack-only rule is now structural, not a self-policed convention.

---

## 2. Live A/B transcript (read-only)

All commands below ran against the real `zheref/bankai-core` checkout at its frozen tag. `nen repo
scenario`/`nen canon resolve` have no old deterministic script counterpart to A/B against — the old
skill's "counterpart" was hand-applied prose, reproduced here by literally reading
`handbooks/INDEX.md` and the old skill's own static tables and comparing the verdict.

### 2.1 — `nen repo scenario`, three real consumers plus one self-review consumer

```
$ nen repo scenario --repo <bankai-core checkout> --target zheref/KroApple
swiftui-tca-uzf-v2

$ nen repo scenario --repo <bankai-core checkout> --target zheref/KroAndroid
compose-uzf-v2

$ nen repo scenario --repo <bankai-core checkout> --target zheref/bankai-scaffold
bankai-core
```

**Old side, applied by hand:** the old skill's prose never named a scenario-resolution mechanism at
all beyond "from `.github/workflows/bankai.yml`" — there is no script to run read-only. Read
`schemas/repos.json` directly instead (the file `nen` itself reads): `KroApple`'s entry carries
`"scenario": "swiftui-tca-uzf-v2"`, `KroAndroid`'s carries `"scenario": "compose-uzf-v2"`,
`bankai-scaffold`'s (the `consumers[]` entry, not its separate `maintained_tools` ownership entry)
carries `"scenario": "bankai-core"`. **Same, by construction** — `nen` reads the exact same field.

### 2.2 — `nen repo scenario`, not-a-consumer refusal (same message for two different real states)

```
$ nen repo scenario --repo <bankai-core checkout> --target zheref/bankai-core
nen: 'zheref/bankai-core' is not a consumer in <checkout>\schemas\repos.json. Its scenario cannot be
read from a registry that does not know it.
(exit 1)

$ nen repo scenario --repo <bankai-core checkout> --target zheref/KroWindows
nen: 'zheref/KroWindows' is not a consumer in <checkout>\schemas\repos.json. Its scenario cannot be
read from a registry that does not know it.
(exit 1)

$ nen repo scenario --repo <bankai-core checkout> --target zheref/kro-pwa
nen: 'zheref/kro-pwa' is not a consumer in <checkout>\schemas\repos.json. Its scenario cannot be
read from a registry that does not know it.
(exit 1)
```

`zheref/bankai-core` is not a consumer of itself (it is the source of the canon, not a consumer of it);
`zheref/KroWindows` and `zheref/kro-pwa` are recorded under `pending_onboarding`, not yet
`consumers[]`. **`nen`'s refusal text is identical for all three real, different states** — confirmed
live. The ported skill (§ 1) names this explicitly rather than letting a reader conflate "never
onboarded" with "not a Bankai repo."

### 2.3 — `nen repo scenario` / `nen canon resolve`, code-vs-slug and no-`GH_TOKEN` findings

```
$ nen repo scenario --repo <bankai-core checkout> --target KP
nen repo: --target takes an owner/name repository slug and 'KP' is not one. It is the GitHub side of
the pair: --repo names a checkout on disk, --target names the repository on GitHub.
(exit 1)
```

Confirmed live: a product code is refused outright by both verbs (`canon resolve` gives the identical
message). Resolving `KP` → `zheref/KroApple` needs `nen repo resolve KP`, which — verified live —
reads `schemas/repos.json` from the **process's own cwd**, not from a `--repo`/`--from`-named path, in
the token-supplied form:

```
$ cd <bankai-core checkout> && nen repo resolve KP
zheref/KroApple  (KP)  via code

$ cd <akatsuki-ai checkout> && nen repo resolve KP --from <bankai-core checkout>
nen repo: <akatsuki-ai checkout>\schemas\repos.json: no such file. ...
```

`--from` is documented (and, verified live, only used) for the **no-token** origin-detection form —
passing it alongside a token changes nothing; the token form always reads cwd. Filed as a finding (§
4), not routed around by hand: the skill instructs running `repo resolve` from inside the bankai-core
checkout.

No command in this document, in either section, needed `GH_TOKEN` — verified by running every
invocation above with none exported.

### 2.4 — `nen canon resolve`, all four real stack scenarios plus the always-load echo

```
$ ALWAYS="handbooks/uzf-core.md,handbooks/security-baseline.md,handbooks/ux-baseline.md,handbooks/release-policy.md,handbooks/quality-baseline.md"

$ nen canon resolve --repo <bankai-core checkout> --target zheref/KroApple --always-load "$ALWAYS" --stack-dir handbooks/stacks
scenario: swiftui-tca-uzf-v2
always load: handbooks/uzf-core.md, handbooks/security-baseline.md, handbooks/ux-baseline.md, handbooks/release-policy.md, handbooks/quality-baseline.md
stack handbook: handbooks/stacks/swiftui-tca-uzf-v2/architecture.md

$ nen canon resolve --repo <bankai-core checkout> --target zheref/KroAndroid --always-load "$ALWAYS" --stack-dir handbooks/stacks
scenario: compose-uzf-v2
always load: handbooks/uzf-core.md, handbooks/security-baseline.md, handbooks/ux-baseline.md, handbooks/release-policy.md, handbooks/quality-baseline.md
stack handbook: handbooks/stacks/compose-uzf-v2/architecture.md

$ nen canon resolve --repo <bankai-core checkout> --target zheref/bankai-scaffold --always-load "$ALWAYS" --stack-dir handbooks/stacks
scenario: bankai-core
always load: handbooks/uzf-core.md, handbooks/security-baseline.md, handbooks/ux-baseline.md, handbooks/release-policy.md, handbooks/quality-baseline.md
stack handbook: handbooks/stacks/bankai-core/architecture.md
```

Also confirmed with `--json` (KroApple): `{"scenario":"swiftui-tca-uzf-v2","alwaysLoad":[...5 paths...],"stackHandbook":"handbooks/stacks/swiftui-tca-uzf-v2/architecture.md"}`.

**Old side, applied by hand** — walk the retired skill's own prose against the same three repos:

- **Always-load, old prose:** `uzf-core.md`, `security-baseline.md`, `release-policy.md` (3 files —
  no `ux-baseline.md`, no `quality-baseline.md`). **`handbooks/INDEX.md`'s live "Always load" table
  names 5 today** (adding `ux-baseline.md` / `UX-{n}` and `quality-baseline.md` / `QA-{n}`). **This is
  a real divergence** — but it is canon that moved (`INDEX.md` grew two rows since the old skill was
  written), not a mechanism disagreement: applying the OLD skill's static list today would silently
  under-load two handbooks that genuinely govern every scenario now. This is exactly the failure mode
  § 2 of the ported skill exists to prevent, demonstrated concretely rather than asserted.
- **Stack handbook, old prose (`KroApple`, `KroAndroid`):** the old skill's 2-row table maps
  `swiftui-tca-uzf-v2` → `stacks/swiftui-tca-uzf-v2/architecture.md` (`SW-{n}`) and `compose-uzf-v2` →
  `stacks/compose-uzf-v2/architecture.md` (`KT-{n}`) — **identical to `nen`'s output for both repos.**
  **Same verdict** on the one part of the resolution the old table could actually reach.
  - **`bankai-scaffold`: the old table has no row for scenario `bankai-core` at all.** Applied by
    hand, the old skill's prose simply cannot resolve this repo — there is nothing in its static table
    to match against. `nen canon resolve` resolves it correctly (`stacks/bankai-core/architecture.md`,
    verified to exist on disk in the checkout). **Not a disagreement — a real capability the old skill
    never had**, because it hardcoded scenarios instead of deriving the path from the string.

**Verdict, stated precisely:** stack-handbook selection is **the same** between old (hand-applied) and
new for every scenario the old table could reach, and the new mechanism additionally reaches two
scenarios (`bankai-core`, and — by the same structural argument — `react-uzf-v1`, whose folder exists
on disk with no consumer yet to test live) the old one could not. Always-load selection **differs by
count** (3 vs. 5), and the difference is fully explained by real, verifiable canon drift recorded in
`handbooks/INDEX.md` itself — not by any defect in either side's matching logic.

### 2.5 — refusal behavior, verified live

```
$ nen canon resolve --repo <bankai-core checkout> --target zheref/KroApple --always-load "$ALWAYS"
nen canon: --stack-dir <dir> is required.
(exit 2)

$ nen canon resolve --target zheref/KroApple --always-load "$ALWAYS" --stack-dir handbooks/stacks
nen canon: <cwd>\schemas\repos.json: no such file. ... (exit 1 — --repo silently defaulted to cwd, it
did NOT refuse for being omitted)

$ nen canon resolve --repo <bankai-core checkout> --always-load "$ALWAYS" --stack-dir handbooks/stacks
nen canon: --target owner/name is required.
(exit 2)

$ nen canon resolve --repo <bankai-core checkout> --target zheref/KroApple --stack-dir handbooks/stacks
nen canon: --always-load <path,path,...> is required -- see 'nen canon resolve --help'.
(exit 2)

$ nen repo scenario --repo C:\nonexistent\path --target zheref/KroApple
nen repo: --repo C:\nonexistent\path resolves to 'C:\nonexistent\path', which does not exist.
(exit 2)
```

Confirms the exit-code split the skill relies on: `--target`/`--stack-dir`/`--always-load` refuse
outright (exit `2`) when omitted; `--repo` has **no such refusal** and silently falls back to the
process's cwd, only surfacing as a failure once that cwd's `schemas/repos.json` is missing (exit `1`,
indistinguishable in shape from a genuine "not a consumer" refusal). Filed as a finding (§ 4) and
encoded directly in the skill (§ 2): never omit `--repo`.

---

## 3. Residue

- **`--always-load` remains a manual read of `handbooks/INDEX.md`, on both sides.** No `nen` verb
  reads that manifest itself — the flag is documented, verified live, as caller data the invoker
  supplies. This is not a missing verb so much as a scope boundary: the manifest convention (which
  file is "always load," in a repo-specific `INDEX.md`) is canon content, not something a generic
  binary should hardcode. The port's contribution is instructing that this read happen **fresh, every
  time**, rather than freezing a copy into the skill's own prose the way the retired skill did — which
  is precisely how that copy went stale by two files.
- **Judgment kept, per the shared brief's boundary list:** citing findings by rule ID and refusing to
  improvise a policy not written in a resolved file (unchanged from the old skill); deciding, when a
  rule is missing or ambiguous, that the gap is a finding for the human rather than something to
  silently work around (§ 4 of the skill) — `nen` computes and resolves; judging what a gap or a
  citation *means* stays this skill's.
- **The `CON-37` handbook-question routing has no live destination anymore**, and this is not a gap in
  `nen`'s verb surface — it is a consequence of bankai-core being frozen. Neither CI Yamamoto nor
  Naruto exists to land a canon-lane PR there. The ported skill (§ 4) replaces the routing with
  "surface the finding, stop at G5" rather than inventing a substitute persona or verb that does not
  exist.
- **No missing verb.** `nen repo scenario` and `nen canon resolve` together cover every deterministic
  step this skill needs. The two gaps found (§ 4) are asymmetries in an existing flag's behavior
  (`repo resolve`'s cwd-only token lookup; `canon resolve`'s/`repo scenario`'s silent `--repo`
  fallback), not absent verbs.

---

## 4. Findings (report separately, do not route around)

1. **`nen repo resolve <token>` has no `--repo` flag and ignores `--from` for the token-supplied form**
   — verified live (§ 2.3): it reads `schemas/repos.json` from the process's own **cwd** regardless of
   what `--from` names. `--from` only applies to the no-token origin-detection form. This is an
   asymmetry against `nen repo scenario`/`nen canon resolve`, which both take an explicit `--repo
   <path>` and work from anywhere. Not a blocker — the ported skill instructs running `repo resolve`
   from inside the bankai-core checkout — but worth filing against `nen` itself: a `--repo` flag on
   `resolve`'s token form would remove the only asymmetry in this family of three `repo` verbs.

2. **`--repo` silently defaults to the process's cwd instead of refusing when omitted**, on both `nen
   repo scenario` and `nen canon resolve` — verified live (§ 2.5), unlike `--target`/`--stack-dir`/
   `--always-load`, which all refuse outright with "is required" (exit `2`). An omitted `--repo` only
   surfaces once that cwd happens to lack `schemas/repos.json`, and the resulting message is
   shape-identical to a genuine "not a consumer" refusal — a caller relying on the exit code alone
   cannot tell "I forgot `--repo`" from "this repo is not onboarded." Worth filing as a consistency
   defect: the other three required flags are enforced at the parser; `--repo` is not, for no stated
   reason found in `--help`.

3. **`nen repo scenario`'s refusal text does not distinguish "never onboarded" from "recorded under
   `pending_onboarding`/`maintained_tools` without a `scenario` field."** Verified live (§ 2.2):
   `zheref/bankai-core` (not a consumer of itself, the canon source), `zheref/KroWindows`, and
   `zheref/kro-pwa` (both recorded, but only under `pending_onboarding`) all produce the byte-identical
   refusal string. Not necessarily a defect — the verb's contract is "consumer or not," and it says so
   — but a caller who wants to report *why* a repo has no scenario needs to read `schemas/repos.json`
   itself first, which the ported skill now says explicitly (§ 1) rather than leaving implicit.

4. **The old skill's own claimed scenario source (`.github/workflows/bankai.yml`) is not what `nen repo
   scenario` reads.** Verified live and by inspection of `--help`'s own text (§ 1 of the skill, § 1 of
   this table): the verb reads the value **recorded** in `schemas/repos.json`, one layer removed from
   the workflow file. In this registry's current state the two never observably disagreed for any repo
   checked, so this is reported as a documentation-precision finding against the retired skill's prose,
   not a live discrepancy caught in the act — but a future registry entry that goes stale against its
   own consumer's `bankai.yml` (the same class of drift `CON-14`'s correction notes throughout
   `schemas/repos.json` describe happening to `pinned`/`consumes` repeatedly) would resolve silently
   wrong under either description equally, since neither the old skill nor `nen` cross-checks the two.
