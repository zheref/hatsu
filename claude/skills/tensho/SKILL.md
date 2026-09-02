---
name: tensho
description: Turn a dirty working copy into one PR standing ready at its gate. Use when the maintainer invokes hatsu:tensho <target-branch|main>, or asks to branch this off, commit and PR what I have, or open a PR for these changes. Kurapika moves the work off main if needed, reviews every uncommitted file before staging it, commits, opens the PR with the body the template requires, then checks it against its gate. Never merges, never commits a file it flagged without an answer.
---

# Tensho — a dirty working copy becomes a PR at your gate

**Nature: Manipulator** carries every run — branching, staging, committing, opening and requesting
review on a PR is GitHub-side operation by definition, whichever nature authored the diff.
**Which authorship nature the diff itself is: Enhancer** (product code), **Conjurer** (governance/
canon — `CONSTITUTION.md`, `handbooks/`, `schemas/`, `agents/`), or **Transmuter** (machinery —
workflows, scripts, hooks, scaffolding). `nen gate derive` (§ 5) narrows this to G2-or-G4 and names
*which* path set hit; Conjurer-vs-Transmuter inside a G4 hit is judgment this skill states, never
Nen's to decide. Say the pair when a diff genuinely spans both, and which one leads.

> **Take what I have here and turn it into one PR, ready for me.**

Where [`hatsu:jujisho`](../jujisho/SKILL.md) splits a working copy into *several* efforts, tensho
treats it as **one**. If the
changes are plainly two unrelated efforts, say so and offer jujisho rather than filing one PR that
carries two concerns.

---

## 1. Invocation

```
hatsu:tensho <target-branch>          # default: main
```

The argument is the PR's **base**, not the source. `main` is the default and the overwhelming
case; an `integration/<chore>` or `integration/epic-<n>` base is the other real one, and it means
the work is a leg of a chore or epic rather than a standalone change — say so, because it changes
what "done" looks like: the delivery PR is the integration branch's, not this one's.

**The base is also where the branch is cut from.** A branch cut from `main` and opened against
`integration/<chore>` carries every commit on `main` that the chore branch lacks, so the PR's diff
is the whole divergence rather than the change. Cut from the base you are targeting, always, and
re-fetch it first.

> **`nen parse` was considered for this grammar and declined — a finding, not a stylistic choice.**
> Verified live: `nen parse`'s generic `<skill> --grammar <template> --line <invocation>` documents
> `[ ... ]` as "an optional trailing clause," but a single slot wrapped in brackets is **not**
> actually optional in practice — `nen parse tensho --grammar "[<target-branch>]" --line ""`
> refuses with `<target-branch> is required and the line does not supply it`, and
> `--grammar "onto [<target-branch>]" --line "onto"` (nothing after the introducing word)
> misreads the literal `onto` itself as the slot's value rather than reporting it omitted. Tensho's
> own grammar is one optional word with a fixed default, which this engine cannot express safely —
> so the default-to-`main` handling below stays this skill's own rule, in prose, not a `nen parse`
> invocation. Reported as a finding against the binary, not routed around by hand.

## 2. Where the work goes

Read the current checkout before moving anything:

```bash
nen wc classify --repo <path to the checkout> --base <target-branch>
```

Reports exactly one of three cases — never a guard, never a guess:

| `nen wc classify` case | What tensho does |
|---|---|
| `must-move` — on the trunk, dirty | **Must move.** Cut `kurapika/<slug>` **from the target base**, not reflexively from `main`, and take the changes with it. Kurapika never pushes `main` |
| `on-branch-dirty` — on a branch, uncommitted work present | The verb reports the branch's existing commit subjects and the uncommitted paths as **evidence**, and says outright it is not the verb's to decide whether they are the **same effort**. Commit on top and reuse the branch when they are; **say so and cut a fresh branch from the target base** for a genuinely different effort — smuggling a second concern into an open PR is how a reviewer ends up approving something nobody described |
| `on-branch-clean` — nothing uncommitted | Nothing to commit. Open or report the PR and go to § 6 |

**"Same effort" is a judgement, so show the evidence rather than asserting it**: the branch's
existing commit subjects and the uncommitted paths the verb prints, plus one line on why they are
or are not one thing. If it is genuinely ambiguous, ask — one round-trip is cheaper than a
mis-scoped PR.

A git command that genuinely fails — a detached `HEAD`, a `--base` that does not resolve — is
never folded into one of the three cases as an empty reading; `nen wc classify` reports it as an
error on stderr and exits non-zero instead (verified live, `docs/ab/tensho.md` § 2.1).

Branch naming is `kurapika/<slug>`, `<slug>` from the change, not from the date — the local plane's
own convention, not a `CON-{n}` rule.

**Resolving the product code** — needed for object notation (§ 5) and, where GitHub calls are
involved, for `--repo`/`--gh-repo` — is `nen repo resolve`'s job:

```bash
nen repo resolve --repo <path> --from <path>       # matches the checkout's own 'origin'
nen repo resolve <CODE> --repo <path>               # matches an explicit code instead
```

> **Finding: `nen repo resolve`'s no-token form cannot resolve the registry-owning repo to its own
> code.** Verified live standing inside a `<reference-repo>` checkout: `nen repo resolve --repo <path>
> --from <path>` (no token) matches the working copy's `origin` remote only against
> `schemas/repos.json`'s **`consumers[]`** entries — repos that consume `<reference-repo>` — and refuses
> with `that is not in this registry`, even though `BC` is a valid, listed code (the refusal's own
> text enumerates it). `<reference-repo>` is the registry's owner, not one of its own consumers, so it
> is never a `consumers[]` row to match an origin against. **Working inside the repo whose own
> registry this is, pass the code explicitly** (`nen repo resolve BC --repo <path>`, which resolves
> fine) rather than relying on the no-token origin match. This does not affect tensho run from
> inside any *consumer* repo (`<product-repo-A>`, `<product-repo-B>`, `<scaffold-repo>`, hatsu itself once it
> ships its own registry) — only from inside the repo that ships the registry.

## 3. Staging — every file is looked at, and some are asked about

**Never `git add -A` blind.**

```bash
nen stage triage --repo <path> [--scope <in-scope prefixes>] [--mentions "<commit/PR draft text>"]
```

Detects, never decides, and exits `1` whenever anything is flagged — verified live against a
constructed working copy carrying one of each (`docs/ab/tensho.md` § 2.2):

| Flag `nen stage triage` reports | Trigger, verified live |
|---|---|
| `secret-shape` | `.env`, `*.pem`, `*.key`, `credentials*`, or a token/key shape in the diff |
| `ignored` | The path is git-ignored and would need `-f` to stage |
| `binary` | The file's content is binary |
| `out-of-scope` | The path falls outside every `--scope` prefix given — **omitted entirely** when `--scope` is not passed at all (no scope declared, nothing to compare against) |
| `unmentioned-deletion` | A tracked path was deleted in the working copy and its basename does not appear in `--mentions`'s text |

One path can carry more than one reason at once (verified: a deleted, out-of-scope file reports
both `out-of-scope` **and** `unmentioned-deletion` in the same row).

**Present every flagged file at once, with the reason(s) `nen` printed, and take one answer per
file. A flagged file is never committed without an explicit yes** — not "it was probably fine,"
not "it was in the diff already." That yes is never the verb's to give (its own `--help` says so
verbatim), and it stays this skill's. **`secret-shape` is the one flag category that is never
askable** — the per-file ask above applies to the other flag categories only. There is no yes for
`secret-shape`; the answer is always no, and the fix is to rotate or remove the secret, never to
stage it. § 8's hard limit is authoritative here: a secret is never committed, full stop.

**Two of the old flag categories have no detector in `nen stage triage` at all — residue, not
routed around by hand, still asked about by eye:**

- **A local-config file** (`.claude/settings.local.json`, editor state, OS cruft) that happens to
  be **neither git-ignored nor out of the declared `--scope`** is reported **clean**, verified
  live — the verb names five detectors and a local-config shape is not one of them. It is only
  caught incidentally, when it happens to also be ignored or out-of-scope. Ask about any
  local-config path by name regardless of what the verb reports.
- **"Unusually large"** is not a detector either — a large plain-text file (a 2.6&nbsp;MB
  constructed fixture, verified live) reports clean, same reason: size is not one of the five
  shapes `nen` looks for. Weigh repo weight by eye.

**Deliberately untracked leftovers stay untracked.** If something should be ignored rather than
committed, say so and offer the `.gitignore` line; do not commit it to be tidy.

## 4. The commits

```bash
nen commit format --type <feat|fix|chore|docs|refactor|test|perf|build|ci> \
  --subject "<short imperative subject>" [--scope <scope>] [--breaking] \
  [--body "<paragraph>"] [--trailer "Akatsuki-Agent=kurapika"]
```

Conventional Commits, one commit per coherent step where the work has steps. Validates **shape**
only (a declared type, a non-empty subject under 72 characters, no trailing punctuation) — what
changed and why stays this skill's to write, never `nen`'s. Verified live: a bad type, an empty
subject, a >72-char header and a trailing-punctuation subject all refuse with a named reason at
exit `2` (`docs/ab/tensho.md` § 2.3); `--trailer` accepts comma-separated `key=value` pairs, so
`Akatsuki-Agent=kurapika` and a harness trailer can both ride in one call.

**No AI attribution beyond the trailers the maintainer's own harness mandates** (today
`Co-Authored-By:` and `Claude-Session:`) **plus `Akatsuki-Agent: kurapika`** — git author stays the
**maintainer**. Never `--no-verify`. Never force-push. Never push `main`.

## 5. The PR

Body follows the target repository's own PR template (e.g. `schemas/templates/pr.md`), and two
parts are checked, never eyeballed:

```bash
nen pr body-check --body-from <path to the drafted body> --requirements-from <path>
```

`--requirements-from` is a JSON array of `{name, pattern}` — this repository's own template
convention, never a literal `nen` ships:

```json
[
  {"name": "What this changes for you", "pattern": "^# What this changes for you"},
  {"name": "How to verify", "pattern": "^## How to verify"}
]
```

Verified live: every requirement is checked and reported, never stopped at the first miss
(`docs/ab/tensho.md` § 2.4) — `# What this changes for you` (effect before mechanism, for a
reviewer who has not followed the work; **state what it costs**, not only what it gives) and
`## How to verify` (per-scenario steps someone can actually run — with no backing issue, this *is*
the acceptance criteria).

**The `changelog.d/` fragment** is a separate, diff-shaped check — `nen pr body-check` never looks
at changed paths:

```bash
nen changelog fragment-required --spec-paths "CONSTITUTION.md,handbooks/,schemas/,agents/,.github/workflows/" \
  --fragment-dir changelog.d --files <the changed paths> --head-changelog <path to CHANGELOG.md> \
  [--body-from <path to the drafted PR body>]
```

Verified live (`docs/ab/tensho.md` § 2.5): reports `not-applicable` when the diff touches none of
`--spec-paths`; `required` when it does and no fragment is among the **changed files** (a fragment
sitting in the directory from an earlier PR does not satisfy it — it must be part of *this* diff);
`fragment-present` once the fragment path is included in `--files`; `opt-out` when `--body-from`
carries a `no CHANGELOG entry: <reason>` line. A direct `### Unreleased` edit still fails the guard
this verb reports against — it was never a satisfying diff shape.

**The target gate is derived, never asserted:**

```bash
nen gate derive --policy-paths "CONSTITUTION.md,handbooks/,agents/,schemas/" \
  --process-paths ".github/workflows/,claude/,scripts/,tests/,docs/" \
  --files <the changed paths> [--asserted G2|G4]
```

These are `<reference-repo>`'s own two-tier split, verbatim from `hatsu`'s own `drive.SKILL.md`
prose: `CONSTITUTION.md`/`handbooks/`/`agents/`/`schemas/` derive G4 as classic policy/spec
(`CON-7`); `.github/workflows/`/`claude/`/`scripts/`/`tests/`/`docs/` derive G4 too, for the
different reason that in a repository whose product is its process, a process change *is* a policy
change. A **different repository's own path sets are its own canon** — these are `nen`'s own
words, verified live: "There are no built-in path sets." Verified live against constructed file
lists: a diff touching neither set reports `G2`; one touching `handbooks/` reports `G4` with the
reason named; passing `--asserted G2` against a diff that actually hits `handbooks/` reports the
disagreement and **the derived gate stands** (`docs/ab/tensho.md` § 2.6).

`Closes #N` only if the PR completes an issue; `Part of #N` otherwise (`nen ref format`/`nen ref
parse` render and read the `<CODE>-<IS|PR>-#<N>` notation itself — verified live, `docs/ab/tensho.md`
§ 2.7). Request Copilot on open:

```bash
export GH_TOKEN=$(gh auth token)
nen pr request-reviews --target <owner/name> --pr <n> --add-reviewers copilot
```

On the maintainer's **user** token it registers, where a bot token silently no-ops — `nen`'s own
`--help` states this and that it cannot enforce which credential ran it, only warn. This is a
mutating GitHub call; per this port's ground rules it is A/B'd by contract inspection only
(`docs/ab/tensho.md` § 3), never exercised live against `<reference-repo>`.

## 6. Then drive it to its gate

**Tensho's drive phase is [`hatsu:drive`](../drive/SKILL.md)'s engine** — the whole of it, not a
substitute. Once the PR is open, hand it over as `hatsu:drive <CODE>#<N> to <G2|G4>` against the
gate § 5's `nen gate derive` named, and let that skill do what it owns: the first-blocking-condition
diagnosis, thread stewardship, the wake channel fired alone, the adversarial confirmation pass, and
the stop at the gate. Tensho does not restate or reimplement any of it, and it does not stop at a
bare readiness reading when the PR can actually be driven.

*Fallback only, when `drive` cannot run at all* (an unresolvable code, no network for the checks it
needs): the readiness **check** by itself is [`hatsu:pr-state`](../pr-state/SKILL.md)'s verb —

```bash
export GH_TOKEN=$(gh auth token)
nen pr ready <CODE>#<N> --repo <path> --gates "$CLAUDE_PLUGIN_ROOT/contracts/reference.gates.json" --explain
```

Quote the verdict verbatim, render the conjunct table `--explain` prints, and apply
`hatsu:pr-state`'s own binding rule unchanged: a readiness claim is that verdict, quoted, or it is
not made — never a paraphrase, never `ready` for a PR that came back `unevaluated`. Say plainly
that this was a check and not a drive: it reports where the PR stands and moves nothing.

Render the stop with `nen stop --who kurapika --gate <G2|G4> <efforts.md>` (verified live,
`docs/ab/tensho.md` § 2.8) and say the handover out loud: *"PR open at RR-PR-#N; `<verdict>`
against G4."*

## 7. Authority

- **Permitted:** branch, commit, push a **non-`main`** branch, open/update a PR, request reviewers,
  and hand the PR to [`hatsu:drive`](../drive/SKILL.md) (or, in the § 6 fallback, read its
  readiness via `hatsu:pr-state`'s own verb).
- **Not permitted:** `bankai:agent/*`, `bankai:stage/*`, any G1 mode label, any merge, any review
  vote — `request_changes` above all, since Kurapika acts on the maintainer's own credentials and
  the vote would be recorded as theirs. tensho creates work and hands it off; it does not route or
  release it.

## 8. Hard limits

- **Never commits a flagged file without an explicit yes**, and never a secret at all —
  `secret-shape` is not one of the categories that ask is for; rotate or remove it instead.
- **Never pushes `main`, never force-pushes, never `--no-verify`.**
- **Never puts two unrelated efforts in one PR** — that is jujisho's job, offered not assumed.
- **Never opens a PR without `# What this changes for you`, `## How to verify`, and the
  `changelog.d/` fragment where one is owed** — all three checked by verb, none by eye.
- **Never claims readiness by eye** — the verdict § 6 reports is `nen pr ready`'s (whether it
  arrives through `drive` or through the fallback check), quoted, or it is not made.
- **Never merges** — G2 and G4 are the maintainer's.
