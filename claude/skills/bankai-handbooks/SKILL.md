---
name: bankai-handbooks
description: Resolve the right Bankai handbook(s) for a repo/scenario — the always-load set plus exactly one stack handbook, with the rule-ID prefixes each one governs. Use when reviewing or building in a Bankai-consuming repo and you need the governing architecture/security/release rules, or need to cite a rule ID (UZF-/SEC-/UX-/REL-/QA-/SW-/KT-/RC-/BC-).
---

# Bankai handbooks — the resolved set, cited, never improvised

**No fixed mode.** This skill is consulted from whichever mode is doing the work that needs a
citation — most often Enhancer (building in a Bankai-consuming product repo), sometimes Transmuter or
Conjurer. Name that mode when you invoke this; this skill only resolves the set the citation draws
from.

The handbooks in `bankai-core` are the **single canonical source** for Bankai work. Load the *right*
ones and no more — **a rule cited from memory is a rule that has already drifted**, and this is not a
hypothetical: the retired skill's own "always load" list went stale **twice**, by its own repo's
history, not by passive drift. `3a463b4` (2026-08-08) added `ux-baseline.md` to `handbooks/INDEX.md`'s
table without touching the retired skill's hardcoded list; `c711f4e` (2026-08-20) added
`quality-baseline.md` to that same table **and edited the retired skill file itself in the same
diff** — yet still left its "always load" prose at three files, never reconciling it against the
table it grew in the very same commit. Two chances to fix it, in the very act of touching the file,
both missed: the set is five files today (§ 2 below; recorded live in
`docs/ab/bankai-handbooks.md` § 1, verified directly against both commits). This is exactly the
repeated maintenance failure the **read `handbooks/INDEX.md` fresh every time** rule exists to
prevent, not a one-off oversight — resolve fresh, every time; never carry a fixed list forward from a
previous session or from this file's own prose.

> **bankai-core is FROZEN**, at the tag `contracts/bankai-core.gates.json`'s header names (`v0.11.3` as
> of this port — verify the checkout you point at actually sits on that tag with `git -C <checkout>
> describe --tags` before trusting it, since a stale local clone can silently drift off the pin).
> **Never write to it** — no PRs, no branches, no issues, nothing. A handbook gap found while resolving
> is a finding to raise to the human (§ 4), never something this session fixes by opening a bankai-core
> PR.
>
> The two-read-path split `CON-13` describes — CI reads bankai-core **live** from a checkout;
> build/local agents auto-load a product repo's generated, pinned `.claude/rules/` **mirror** of it —
> **collapses to ONE path here.** `nen canon resolve` computes the identical resolved set, live and
> deterministically, straight from a bankai-core checkout: there is no reason left to trust a
> possibly-stale mirror when the live computation is this cheap and this exact. Point `--repo` at
> the checkout, never at a product repo's mirror.

---

## 1. Resolve the scenario

```bash
nen repo scenario --repo <bankai-core checkout> --target <owner/name>
```

Reads the `scenario` value **recorded for `<owner/name>` in that checkout's `schemas/repos.json`** —
verified live against the real registry: `zheref/KroApple` → `swiftui-tca-uzf-v2`, `zheref/KroAndroid`
→ `compose-uzf-v2`, `zheref/bankai-scaffold` → `bankai-core` (the self-review/machinery scenario — no
product code, `BC-{n}` citations only, and this repo is ALSO a genuine registry consumer, distinct from
its separate `maintained_tools` ownership entry).

> **Finding against the retired skill's prose, not the binary.** The old `bankai-handbooks` skill said
> the scenario comes "from `.github/workflows/bankai.yml`". Verified live: `nen repo scenario` never
> reads that file — it reads the value **recorded** for the target in `schemas/repos.json`, which
> Naruto/`CON-14` keeps factual against the live workflow file by hand, one layer removed. The
> distinction matters when the two disagree: resolve from the registry, the way the verb does, never
> by opening `bankai.yml` yourself.

- **`--repo`** is a path to a checkout, always a bankai-core one — never an `owner/name` slug.
- **`--target`** is an `owner/name` slug — never a product code. `nen repo scenario` refuses a code
  outright, verified live: `--target takes an owner/name repository slug and 'KP' is not one`. If you
  only have a code, resolve it first with `nen repo resolve <CODE>` run **from inside** that same
  bankai-core checkout — `repo resolve`'s token form takes no `--repo` and ignores `--from` for this
  purpose; it reads `schemas/repos.json` from the process's own **cwd** regardless (verified live,
  `docs/ab/bankai-handbooks.md` § 2.3 — filed as a finding, not routed around by hand).
- **No `GH_TOKEN` needed anywhere in this skill.** Both verbs here are pure local-file reads against
  the checkout on disk — verified live with no token exported at all.
- **Exit `1`** → covers **two unrelated failure classes that share the same code** — verified live,
  re-checked against the binary for this port, not carried over from an earlier draft:
  - `<owner/name>` is not a recorded consumer. This itself covers two different real states — never
    onboarded at all, or recorded only under `pending_onboarding`/`maintained_tools` without a
    `scenario` field — and `nen`'s refusal text does **not** distinguish them. Check
    `schemas/repos.json` yourself before reporting which one it is.
  - **An invocation mistake — a missing `--target`, or a `--target` that is not an `owner/name`
    slug — also exits `1`, not `2`.** Do not read exit `1` alone as "not a consumer"; tell the two
    apart **only by the refusal text**, never by the code: a missing `--target` says `--target
    owner/name is required`; a malformed one says `--target takes an owner/name repository slug and
    '<value>' is not one`; a real not-a-consumer refusal names the target and
    `schemas/repos.json` (`'<owner/name>' is not a consumer in <checkout>\schemas\repos.json`).
- **Exit `2`** → only an unusable `--repo` path (a checkout that does not exist on disk). This is the
  **one and only** exit-`2` case for this verb — verified live; a missing or malformed `--target` does
  **not** produce it. Fix the command; never read exit `2` as "no scenario."

> **Finding, filed against `nen` (not routed around by hand):** `nen repo scenario` conflates
> invocation errors with "not a recorded consumer" under a single exit code (`1`). Verified live,
> reproduced for this port: a missing `--target`, a code-shaped `--target`, and a genuine
> not-a-consumer target all exit `1`; only a bad `--repo` path exits `2`. A caller relying on the exit
> code alone cannot tell "I mistyped the command" from "this repo genuinely isn't onboarded" — the
> refusal text is the only reliable signal, and this skill's report step (§ 3) must read it, never
> just the code. Recorded in full, with the live transcript, in `docs/ab/bankai-handbooks.md` §§ 2.2–
> 2.3 and finding 5 of § 4.

## 2. Resolve the handbook set

```bash
nen canon resolve --repo <bankai-core checkout> --target <owner/name> \
  --always-load <paths from handbooks/INDEX.md's "Always load" table, comma-separated> \
  --stack-dir handbooks/stacks \
  --json
```

**`--always-load` is caller data — read fresh from `handbooks/INDEX.md`'s own "Always load" table, at
the same checkout, every time.** It is not looked up by the verb; you supply it. It is also not stable:
the table has already grown twice while the retired skill's own copy of it sat frozen (three files →
four → five, § above). Verified live at the frozen tag, it resolves to:

```
handbooks/uzf-core.md, handbooks/security-baseline.md, handbooks/ux-baseline.md,
handbooks/release-policy.md, handbooks/quality-baseline.md
```

— `UZF-{n}`, `SEC-{n}`, `UX-{n}`, `REL-{n}`, `QA-{n}` respectively. **Read the table yourself before
every resolve rather than pasting this list from memory next session** — that is exactly the drift
this section exists to name.

`--stack-dir handbooks/stacks` is the fixed directory layout, not caller data — it does not change per
scenario and needs no re-reading.

`--always-load` and `--target` both refuse outright (exit `2`, "is required") when omitted. **`--repo`
does not** — leave it off and the verb silently falls back to the process's own cwd rather than
refusing (verified live). Never omit it.

The verb computes, in one call, both halves the old skill's title promised: the always-load set
(echoed back for confirmation) and **exactly one** stack handbook, derived directly from the scenario
`nen repo scenario` returned — never looked up in a table of its own. Today's scenario → stack →
rule-prefix mapping, read from `handbooks/INDEX.md`'s own stack table at resolve time, never memorized:

| Scenario | Stack handbook | Rule-ID prefix | Recorded consumer today |
| --- | --- | --- | --- |
| `swiftui-tca-uzf-v2` | `handbooks/stacks/swiftui-tca-uzf-v2/architecture.md` | `SW-{n}` | `zheref/KroApple` |
| `compose-uzf-v2` | `handbooks/stacks/compose-uzf-v2/architecture.md` | `KT-{n}` | `zheref/KroAndroid` |
| `react-uzf-v1` | `handbooks/stacks/react-uzf-v1/architecture.md` | `RC-{n}` | none yet (`zheref/kro-pwa` is pending onboarding onto it) |
| `bankai-core` | `handbooks/stacks/bankai-core/architecture.md` | `BC-{n}` | `zheref/bankai-scaffold` (self-review, no product code) |

> **`react-uzf-v1` and `bankai-core` are not in the retired skill's table.** It listed only
> `swiftui-tca-uzf-v2`/`SW-{n}` and `compose-uzf-v2`/`KT-{n}`. Both of the others are real, live
> scenarios today — resolve from `handbooks/INDEX.md`, never from this table once it, too, is a
> session old.

**Never load another stack's folder.** The verb enforces this structurally — it returns exactly one
`stackHandbook` path, never a list — so there is nothing to improvise here even under pressure to check
"just one more."

## 3. Report

Quote the resolved set; do not summarize it:

```
<owner/name>  (scenario: <scenario>)
  always load: <alwaysLoad, joined>
  stack handbook: <stackHandbook>
```

Then cite findings **by rule ID**, drawn only from the files just resolved: `UZF-{n}`, `SEC-{n}`,
`UX-{n}`, `REL-{n}`, `QA-{n}` from the always-load set; `SW-{n}` / `KT-{n}` / `RC-{n}` / `BC-{n}` from
whichever ONE stack file resolved for this repo. Never improvise a policy that is not written in one of
these files, and never cite a rule ID belonging to a stack folder other than the one that just
resolved.

## 4. When a rule is missing or ambiguous

The retired skill routed this to CI Yamamoto (a handbook/schema gap) or Naruto (a governance gap) per
`CON-37`, both landing a canon-lane PR bankai-core merged at **G4**. **bankai-core is frozen — neither
exists to act on it, and no PR can land there anymore.** Surface the gap as a finding instead: name the
file, the scenario, and what is missing or contradictory, then stop at **G5** for the human to decide
where it actually gets resolved — a Hatsu-side documentation note, or an Akatsuki canon decision once
that repo exists. Never draft a fix that reads as though the question were already settled: an OPEN
gap stays OPEN (`claude/agents/kurapika.md` § Conjurer, "An OPEN item stays OPEN").

## 5. What this skill must never do

- **Hardcode the always-load set or the scenario/stack table across sessions.** Both drifted **twice**
  already, by the same repeated maintenance failure of an edit not reconciling a table it grew in the
  same diff (§§ 1–2 above); re-read `handbooks/INDEX.md` at the pinned checkout every time, never from
  this file's own prose.
- **Read `nen repo scenario`'s exit code alone as the diagnosis.** Exit `1` covers both "not a
  recorded consumer" and an invocation mistake (missing/malformed `--target`); read the refusal text
  to tell them apart (§ 1).
- **Load more than one stack folder**, or guess a scenario when `nen repo scenario` refuses one.
- **Improvise a policy** that is not written in one of the resolved files, or cite a rule ID from a
  file that did not resolve for this repo.
- **Treat "not a consumer" as "not a Bankai repo."** Check `pending_onboarding` / `maintained_tools`
  in `schemas/repos.json` before reporting which one it actually is.
- **Open, edit, comment on, or otherwise write to bankai-core** to fix a handbook gap. It is frozen;
  file the finding and stop at `G5` instead (§ 4).
- **Fall back to a product repo's `.claude/rules/` mirror** when a live bankai-core checkout is
  available. Resolve from the checkout — the mirror is no longer this skill's source now that the verb
  exists to compute the same thing live.
- **Pass a product code to `--target`.** Resolve it to `owner/name` first, from inside the bankai-core
  checkout (§ 1).
