---
name: backlog-state
description: Render the current backlog as one gate-oriented table — every open issue with its associated PRs, for one repo or all of them, showing the human gate each item sits at, what it needs next, and which session is driving it. Use when the maintainer asks what the state is, what needs them, what is at a gate, or invokes hatsu:backlog-state <repo|all>@<G1|G1-M|G2|G3|G4|G5|all>. Strictly read-only — it never labels, merges, pushes, comments or opens anything.
---

# Backlog state — the whole board, by gate, on demand

**Nature: Manipulator.** GitHub-side ops/reporting over the governance plane. Kurapika says so when
he runs it.

This skill answers exactly one question, and answers it the same way every time:

> **What is at my gate right now, and what does each thing need from me?**

It exists because nothing else answered it. GitHub's issue list reports what is *open*; nothing
says which gate an item sits at, which PR carries it, who is driving it, or what it needs — across
repos, on demand, in one table.

> **Read-only, without exception.** This skill renders state. It never applies a label, merges,
> pushes, opens, closes or comments. If reading the board makes the next action obvious, *say what
> the action is* — do not take it.

The old (bankai-core) version of this skill computed every one of §§2–7, 11 below by improvised
prose: hand-grepping `schemas/repos.json`, eyeballing check pages, reconstructing a colour
precedence table from memory, hand-sorting rows by severity. This port replaces every one of those
steps with a `nen` verb — `nen backlog fetch|order`, `nen gate derive`, `nen color status`,
`nen board build|render`, `nen ref format` — per zheref/hatsu#2. What remains genuinely
un-mechanizable (gate *interpretation*, synthesized titles, the expected-action line, session/lane
attribution, the closing shape) stays this skill's judgment, same as before. See
`docs/ab/backlog-state.md` for the full mapping, the live evidence, and every finding filed against
the binary along the way.

---

## 1. Invocation

```
hatsu:backlog-state <repo name | all>@<G1 | G1-M | G2 | G3 | G4 | G5 | all>
```

| Part | Accepts | Default |
|---|---|---|
| repo | a product code, a short name, `owner/repo`, or **`all`** | **the repo you are standing in** — see below |
| gate | `G1`, `G1-M`, `G2`, `G3`, `G4`, `G5`, or **`all`** | `all` when the `@<gate>` part is omitted entirely |

Parsing rules:

- **Case-insensitive** on both sides. `bc@g4` is `BC@G4`.
- **`@` is optional.** `hatsu:backlog-state all` means `all@all`.
- **`G1-M` is accepted** even though the grammar table lists only `G1…G5` — it is a real gate
  (`CON-25`) and someone will type it. When the filter is `G1`, **include `G1-M` rows** and name
  them `G1-M` in the state cell; they are the same human, the same moment in the lifecycle.

> **Not mechanized by `nen parse`, and that is a finding, not an oversight.** `nen parse <skill>
> --grammar <template>` is the verb built for exactly this (a skill's own custom grammar) — checked
> live against `<repo>[@<gate:G1|G1-M|G2|G3|G4|G5|all>]`, a template written the documented way,
> using the `[ ... ]` optional-clause syntax `nen parse --help` itself describes. **It does not
> work**: with only one named slot ahead of the bracketed clause, everything after the slot —
> including an out-of-enum value like `G9` — is swallowed silently into that one slot's captured
> value, reported `"ok": true`, rather than split or refused. Reproduced with the enum present, with
> a bare unconstrained slot, and with a plain literal trailing clause carrying no slot at all — all
> three collapse the same way. `futon`/`izanagi`/`izanami` carry their own hand-written grammars
> (per `nen parse --help`'s own text) rather than going through this generic path, which is
> presumably why the gap was never hit before. Filed as a finding (`docs/ab/backlog-state.md` § 4);
> this skill keeps splitting `<repo>@<gate>` by hand, the same prose rule the old skill used, rather
> than trusting a verb verified not to enforce it.

**With no repo token, the subject is the repo you are standing in.** Resolve the working
directory's `origin` remote against the target registry:

```
nen repo resolve --repo <path> --from <cwd>
```

> **A verified gap when the standing repo is the registry's own source, not a listed consumer.**
> `nen repo resolve` (no-token form) matches the resolved origin against the registry's `consumers`
> **∪** `maintained_tools` arrays only — **not** the full `product_codes` map. Verified live,
> standing in `bankai-core` itself: `nen repo resolve --repo <bankai-core path> --from <same path>`
> refuses with *"'zheref/bankai-core' ... is not in this registry"*, even though the **same
> refusal's own printed code list** shows `BC (zheref/bankai-core)` right there in
> `product_codes`. `nen repo resolve BC --repo <path>` (the explicit-code form) resolves it
> instantly — the map has the entry, only the origin-matching path refuses to consult it. This
> reproduces for exactly the shape this skill hits constantly (backlog-state is asked from inside
> the source repo itself, not only from a consumer): **when the no-token form refuses this way,
> reuse the code its own refusal text just printed for that origin — never re-derive or guess one
> by hand-reading the registry file.** Filed as a finding, not routed around
> (`docs/ab/backlog-state.md` § 4).
>
> An `origin` that resolves to nothing in the registry at all is a genuine error — say which remote
> failed and list `product_codes`. It is never a fallback to `all`.

**An unknown repo is an error, never a guess.** Say which token failed and list the codes `nen repo
resolve`'s own refusal names. Resolving `Kro` to `KroApple` because it is the only prefix match is
exactly the kind of helpfulness that reports the wrong repo's backlog.

## 2. Resolving the repo set

```
nen repo resolve all --repo <path>
```

`all` enumerates the registry's `consumers` ∪ `maintained_tools` entries. **Whether the standing
repo also appears in that set is registry-content-dependent, not a fixed rule** — verified live
against bankai-core's own registry (`docs/ab/backlog-state.md` § 2.2): `bankai-core` (`BC`) *does*
show up in `all`'s own output here, because bankai-core's registry happens to list itself among the
enumerated entries even though it is the source, not a consumer, of that registry. A different
registry that omits the source repo from both arrays would produce the gap the old skill's prose
named and worked around by hand. **Check the returned rows by code before doing anything else**:

- **If the standing repo's code is already among the rows** `all` returned, use the set as-is —
  adding it again would duplicate the row.
- **If it is missing**, add it explicitly — resolve it via its own product code (`nen repo resolve
  BC --repo <path>`) and fold it into the swept set alongside whatever `all` returned.

Either way, **state the resolved set before the table**, so a reader can see what was actually
swept: *"6 repos: bankai-core, bankai-scaffold, KroApple, KroAndroid, KroWindows, kro-pwa."* A
reader who cannot see what was swept cannot tell an empty band from an unswept one.

> **A second, sharper finding in the same output.** `nen repo resolve all`'s row set also includes
> a spurious entry: `schemas/repos.json`'s own `$comment` documentation key, printed as if it were
> a resolvable repository (`Object-reference notation (...) ($comment) via all`) alongside the real
> ones. This is the same schema-loader defect pr-state's own A/B doc records against the
> unknown-code refusal path (`docs/ab/pr-state.md` § 4 finding 3) — here it surfaces inside a
> *successful* sweep result instead of only an error message, which is worse: a caller counting rows
> off `all`'s output silently gets one extra, non-repository row. **Never silently drop it** — name
> it in the resolved-set line (*"`all` returned N rows; one, `$comment`, is the registry's own
> documentation key, not a repository, and is excluded from the sweep"*) rather than quietly
> filtering it with no trace. **Never hard-code N** — count whatever the live call actually
> returned; it varies with the registry's own content. Filed as a finding, `docs/ab/backlog-state.md`
> § 4.

## 3. Fetching

```
nen backlog fetch --repo-slug <owner/name> [--limit <n>]
```

Fetches open issues and open PRs fresh over the GitHub API — **never cached**, and **paginated**:
it follows `?page=N` until a short page comes back rather than stopping at GitHub's 100-row clamp.
Returns one row per **issue**, carrying its `prNumbers[]` — the assembly of "an issue plus the PRs
that reference it" that used to be hand-reasoned is now the verb's own output shape.

- **Omit `--limit`** to fetch every open row, uncapped. **`truncated: true` in the JSON (or the
  printed `TRUNCATED at --limit N` line) means exactly that** — never render a capped fetch as
  complete.
- **The row schema is thin by design**: `{issueNumber, title, labels, prNumbers[], createdAt}` —
  no severity field, no PR-level detail (no head SHA, no check rollup, no review state, no base
  ref). Severity is read off `labels` (the `bankai:severity/*` entry) before feeding rows to
  `nen backlog order` (§ 11); PR-level detail is `nen pr ready`'s job (§ 5), not this verb's.
- **A lone PR that references no open issue** is not visible in this fetch's shape (it enumerates
  by **issue**, with each issue's `prNumbers[]` attached) — cross-check `gh pr list --repo
  <owner/name> --state open --json number,title` for PRs whose issue link, if any, is already
  closed, and give that PR its own row. This is the one shape `nen backlog fetch` does not carry;
  no `nen` verb replaces this specific cross-check today (residue, `docs/ab/backlog-state.md` § 3).
- **An issue and the PRs that serve it are ONE row.** The unit is the *effort*, not the object. An
  umbrella issue whose children each have PRs is one row that names them.

## 4. Assigning the gate

Work per row. The **PR governs when one exists**:

```
Has an open PR?
├─ YES → does the PR's base branch start "integration/"?
│        ├─ YES → NOT a maintainer gate at all — Roy's cascade/epic-merge lane (CON-5), UNLESS the
│        │        PR carries `bankai:observation-fix` (CON-34), which IS a maintainer integration
│        │        merge and must be worded as one, never as "G2"
│        └─ NO  → is it CON-32-Ready?  (nen pr ready — § 5)
│                 ├─ YES → does the diff touch CONSTITUTION.md, handbooks/, agents/, or schemas/,
│        │                 or the process surface (.github/workflows/, claude/, scripts/, tests/,
│        │                 docs/)?  →  nen gate derive (below)
│        │                 │        ├─ YES → G4   (CON-7 — policy/spec, or process-as-product)
│        │                 │        └─ NO  → G2   (CON-5 — product code)
│        │                 └─ NO  → NO GATE. In progress, owned by its author. See § 6.
└─ NO  → is a release proposed / is the tag precondition met?      → G3  (CON-6)
         is the issue at bankai:stage/researched?                  → G1  (CON-4)
         is it routed (bankai:agent/*) without bankai:stage/building? → G1-M (CON-25)
         can it move at all without a human decision or action?
                 ├─ NO  → G5
                 └─ YES → NO GATE. It is unstarted or in progress.
```

**The base-ref branch is new in this port and is load-bearing** — carried in from a **live, open**
finding against the source this skill ports (`BC-IS-#929`, discovered while running this port's own
A/B pass): the old tree derived a gate from the diff alone, so a product-code sub-PR based on
`integration/epic-*` fell through to G2 and issued a `MERGE` ask the maintainer does not own — that
merge is Roy's (`CON-5`), and reporting it as the maintainer's hands them a merge that skips
de-dup/base-sync/sibling-propagation. **`nen gate derive` does not read base ref at all** — it
computes only from the changed-file set against two path sets, by design (`nen gate --help`: "This
derives the DIFF's half only"). Base-ref awareness stays squarely this skill's own judgment, and
there is currently no working `nen` path to a PR's `baseRefName` either — see the `nen pr fetch`
finding under § 5. Until one exists, resolve the base branch by reading it directly off the PR
(e.g. `gh pr view <n> --json baseRefName -q .baseRefName`) rather than skipping the check; a row
whose base could not be determined is reported `unresolved`, never defaulted to `main`.

**Deriving the diff half, mechanically:**

```
nen gate derive --policy-paths "CONSTITUTION.md,handbooks/,agents/,schemas/" \
                --process-paths ".github/workflows/,claude/,scripts/,tests/,docs/" \
                --files <comma-separated changed paths>
```

Verified live against two real bankai-core PRs: `BC-PR-#925` (touches
`.github/workflows/*.yml`, `scripts/`, `tests/`) derived `G4` — *"the diff touches the process
surface ... in a repository whose product is its process, that is a policy change"*; `BC-PR-#916`
(touches `schemas/repos.json`) derived `G4` — *"the diff touches policy/spec (schemas/), which only
the human merges."* Both match the tree above exactly, computed rather than eyeballed.

**No `nen` verb fetches a remote PR's changed-file set** — `--files`/`--files-from` are caller
data, and `--range` shells `git diff` against a **local** checkout, which a PR you have not
branch-fetched locally does not give you. `gh pr diff <n> --repo <owner/name> --name-only` remains
a necessary raw call feeding `--files` (residue, not an improvised replacement for anything `nen`
owns — nothing owns this fetch yet).

**`nen gate derive --asserted <G2|G4>`** reports a mismatch rather than silently preferring either
side: *"the invocation asserted G4; the diff derives G2, and the derived gate stands"* — the gate
is a property of the diff, not of a prior belief.

**In bankai-core almost every PR is G4** — it is a governance and machinery repo, so its process
surface *is* its product. In a consumer repo (KroApple, KroAndroid) product code is the norm and
G2 dominates. Do not carry one repo's ratio into the other; decide per diff.

### G5 is not the default bucket — this is the rule this skill exists to enforce

> *"G5 is any human decision gate not covered by the other gates, yet that shouldn't mean PRs are
> not meant to be driven by authors or local monitors until reaching either G2/G4 readiness."*

| Situation | Gate | Why |
|---|---|---|
| Checks queued or running | **none** — in progress | Nobody is asking the human for anything |
| Review rounds outstanding | **none** — in progress | The author drives them (`CON-32`) |
| Author iterating, threads open | **none** — in progress | Owned by its author until Ready |
| Ready, mergeable, zero threads | **G2 / G4** | *Now* it is the human's |
| Needs a secret, a setting, a ruleset (`CON-2`) | **G5** | Only the human can |
| An option to pick, a policy shape to rule on | **G5** | Only the human can |
| A conflict to escalate | **G5** | Only the human can |
| Sub-PR on an `integration/*` base | **NOT a gate row here** | Roy's lane, unless `bankai:observation-fix` (`CON-34`) |

**G5 means the human is the only actor who can move it.** When unsure, the answer is **not G5**: an
item wrongly left in-progress gets picked up by its author next cycle, while one wrongly marked G5
sits in the human's queue until they read it and discover it was never theirs.

## 5. Readiness is decided by the verb, never by eye

A row is G2/G4-ready **iff `nen pr ready` says the PR is `CON-32`-Ready** — and the way to ask it,
with the discipline of quoting rather than paraphrasing, is
[`hatsu:pr-state`](../pr-state/SKILL.md):

```bash
export GH_TOKEN=$(gh auth token)
nen pr ready <CODE>#<N> --repo <path> \
  --gates "$CLAUDE_PLUGIN_ROOT/contracts/bankai-core.gates.json" --explain
```

(or `<N> --gh-repo <owner/repo> --gates ...` for a bare number.) **Always the
`$CLAUDE_PLUGIN_ROOT`-anchored gates path** — a bare relative one only resolves from this
checkout's own cwd (`pr-state`'s own A/B doc § 2.6 proves the `ENOENT` live). A repo that ships its
own `schemas/gates.json` needs no `--gates` flag at all.

Two things follow, unchanged from the old skill:

- **Do not re-derive readiness from the check rollup yourself.** The current-head rule (`CON-16`) —
  an approval that predates the latest push does not count — is exactly what a glance at the
  checks page misses.
- **Honour what the gate does NOT decide** (`nen pr ready --explain`'s own printed caveats: `CON-32`
  (c) and (e) are approximated, not asserted — see `pr-state/SKILL.md` § 3). If you believe a row
  is ready and the verb disagrees, the row is **not** green — say what it objected to.

> **`nen pr fetch` is broken against every real PR tested, and this port never routes around it.**
> `nen pr fetch --target <owner/name> --pr <n>` is documented to return "one typed snapshot: head
> SHA, mergeability, the check rollup, reviews PER COMMIT, review threads ..." — verified live, it
> crashes on **every** PR tried, in **two different repositories** (`zheref/bankai-core#925`,
> `#927`, `#916`, `#932`; `zheref/hatsu#5`), plain and `--json` output printing the identical error:
> `nen pr: could not fetch <owner/repo>#<n> reviews: gh: Unprocessable Entity (HTTP 422)`.
> GitHub's reviews sub-fetch itself is failing inside the verb, on every repo
> this port tried it against, not a bankai-core-specific quirk. **This skill does not use `nen pr
> fetch` for anything** as a result — readiness comes from `nen pr ready` (a different code path,
> confirmed working), and nothing else in this skill needs `pr fetch`'s remaining fields (base ref
> excepted — § 4's own caveat). Filed as a finding, `docs/ab/backlog-state.md` § 4; not a gap this
> skill improvises around with a raw `gh api` equivalent presented as if a verb produced it.

## 6. Status colour — mechanized, never reconstructed from memory

```
nen color status --repo <path> --present <a,b,c>
```

Resolves the target repository's own `schemas/colors.yml` precedence for whatever category values
are true of one row, and prints the first match plus what it outranked. Verified live against
bankai-core's own file:

| Test | Result |
|---|---|
| `--present ready_g2_g4` | 🟢 `ready_g2_g4` — G2/G4-ready |
| `--present ready_g2_g4,blocked` | 🔴 `blocked` — outranked: `ready_g2_g4` |
| `--present blocked,on_hold` | 🔵 `on_hold` — outranked: `blocked` |
| `--present in_progress` | 🟠 `in_progress` |
| `--present ""` (nothing true) | `unresolved: nothing was reported present` |

Precedence printed alongside every call: `on_hold > blocked > ready_g2_g4 > ready_g1 > in_progress`
— byte-identical to the old skill's hand-maintained table, now read from the file rather than
carried in the skill's own memory. **Never hard-code a glyph or a tie-break** — call the verb per
row and relay what it resolved (or `unresolved`, which is itself a finding to report, never a
default).

| Colour | Means |
|---|---|
| 🔵 on_hold | Deliberately parked — **name what it waits on** |
| 🔴 blocked | A **G5** decision or action is required |
| 🟢 ready_g2_g4 | `nen pr ready` says Ready and mergeable |
| 🟡 ready_g1 | Ready to be started, or to have its spec iterated — **G1** or **G1-M** |
| 🟠 in_progress | Work is moving; nobody is waiting on the human |

> **The same circles are also severity colours (a separate `--category severity`) — that reuse is
> canon**, disambiguated only by the column header. Always head the column `Status`, never `Status
> / Severity` combined.

## 7. The table

```
nen board build --repo-slug <owner/name> --rows-from <path>   # rows: {id,title,refs,gate,status,needs}
nen board render --board-from <path>
```

`board build` assembles a `Board` from rows this skill has already computed (gate from § 4, colour
from § 6, `refs` formatted with `nen ref format`); `board render` prints it as the padded-markdown
table this repository's own `ichigo_board.sh` established. Verified live end to end: feeding two
rows (one G4/in-progress, one G1-M/ready-to-start) through `build` then `render` produces

```
| Effort                                                | Refs                   | Status (gate)    | Needs                            |
```

with each row's `status` cell holding whatever string was passed — pass the **resolved glyph** from
§ 6 (`🟠`, not the bare word `in_progress`), verified live: the render layer does not itself look up
`colors.yml`, it prints the cell verbatim.

**Two columns the old skill's table carried have no slot in `nen`'s `BoardRow` schema** —
`{id, title, refs, gate, status, needs}` has no field for the conditional **Repo** column (only
present when sweeping `all`) or **Session · Lane** (§ 10). This is a genuine schema gap, not an
oversight to route around silently:

- **Repo**, when the argument is `all`: prefix the `title` with the resolved product code in
  brackets — `"[BC] Cancelled build leaves bankai:stage/building set"` — rather than adding a column
  `nen` cannot render.
- **Session · Lane** (§ 10): fold it into `needs`, clearly delimited — `"<action> — session:
  <name>, lane: <lane>"` — never silently dropped, and never smuggled into `refs` or `title` where
  it would be misread as part of the effort itself.

Lead with a one-line summary before the table: the repo set swept, the gate filter, the row count,
the count needing the human. **Never render an empty table silently** — *"`@G3`: no rows. No
release is proposed."*

## 8. Synthesized titles

Unchanged — this stays judgment, `nen` has no verb for it and none is wanted. Write **4–10 words**
saying what the item is about, in plain terms:

| Raw | Synthesized |
|---|---|
| `[Machinery] probe_hosted_health.sh cannot detect a billing block — it checks run…` | Billing blocks go undetected |
| `CON-22 fan-out: five reusable workflows changed by BC-PR-#603` | Fan-out owed for five reusables |

Synthesize; never truncate. Never editorialise a title into a claim the issue does not make.

## 9. Expected action or decision

One line, naming **the action and its actor** — judgment, unchanged:

| Bad | Good |
|---|---|
| "Needs attention" | "Merge — `BC-PR-#588`, ready since 14:02" |
| "Blocked" | "Create the `integration/*` ruleset — only you can (`CON-2`)" |
| "In review" | "Kisuke addresses 4 Copilot threads" |

If the actor is the maintainer, say what the decision *is*, not that a decision exists.

## 10. Session · Lane — derived from evidence, never assumed

Unchanged from the old skill; folded into the `needs` cell per § 7's schema-gap note.

**Lane** — the authority driving the work:

| Evidence | Lane |
|---|---|
| A machine stamp: `<!-- bankai agent={name} run={run_id} ... -->` | **CI agent** — name it |
| Local commit attribution / a Kurapika mode header | **Kurapika authority** — name the mode (`Enhancer`, `Conjurer`, `Transmuter`, `Manipulator`, `Emitter`, `Specialist`) |
| A `bankai:agent/<name>` label but no stamp and no PR | **Routed, not started** |
| None of the above | **No set profile** |

**Session** — where it runs: the workflow run for CI (link the run), the named local session for
local work, or **`unresolved`** — never a guessed session name.

## 11. Ordering

**Rows the human must act on first**, then the rest:

```
🟢 G2/G4-ready   →  🔴 blocked (G5)  →  🟡 G1-ready  →  🔵 on hold  →  🟠 in progress
```

**`nen backlog order` does not know about status bands** — it implements backlog-loop's own §2
priority order (severity → blocks-another → affects-consumers → age → issue number) over a
pre-fetched row set, nothing about gate colour. So the composition is: **bucket rows into the five
bands above first (§ 6's own output), then run `nen backlog order` inside each band**:

```
nen backlog order --rows-from <path> --severity-order critical,high,medium,low \
                  [--blocks <n,n>] [--affects-consumers <n,n>]
```

Verified live: severity is the primary key (`high` rows sort before `medium`, both before an
unrecognised severity string, which ranks last rather than erroring); `--blocks`/`--affects-
consumers` only break ties **within** one severity, exactly as documented. Feed `nen backlog
fetch --json`'s rows reshaped to `{id, severity, createdAt, number}` (severity read off the
`bankai:severity/*` label) — the reshape itself is expected caller work, per the verb's own
`--help` example.

## 12. Close with the shape, not just the rows

Unchanged — judgment. End with two or three lines of shape: what collapses, what shares one root
cause, what is one merge away. Derive it from the rows just rendered; never assert a collapse not
computed from them.

## 13. What this skill must never do

- Apply, remove or suggest applying any label as a side effect.
- Merge, push, open, close, comment, or re-request review.
- Report a gate it inferred from a title rather than from labels, diff (`nen gate derive`) and base
  ref (§ 4).
- Report readiness it did not get from `nen pr ready`.
- Fabricate a session name, a run link, or a colour whose precedence it did not get from `nen color
  status`.
- Render a truncated fetch (`nen backlog fetch`'s own `truncated` field) as if it were complete.
- Silently drop `nen repo resolve all`'s spurious `$comment` row, or silently add the source repo
  to a sweep without saying so (§ 2).
- Route around `nen pr fetch`'s live crash, or `nen parse`'s live grammar gap, with a hand-rolled
  equivalent presented as if a verb produced it — both are filed findings
  (`docs/ab/backlog-state.md` § 4), not gaps this skill papers over.
