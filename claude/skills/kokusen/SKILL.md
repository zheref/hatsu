---
name: kokusen
description: Commit the working copy locally, automatically, once the iteration checks are green — triage every path before staging it, ask on each flagged one, format the message through the Conventional-Commits verb, and sign it with `Akatsuki-Agent` and nothing else. Runs as phase three of `ren` after `hatsu:rasengan`; invoke `hatsu:kokusen` by name to commit a checkpoint on demand. It never pushes, never adds an AI attribution trailer, and never commits a flagged file without an explicit yes or a secret at all.
---

# Kokusen — the black flash: one clean local commit, and nothing else

**Nature: Manipulator** carries every run — staging and committing is directing a body that is not
yours under conditions declared in advance, which is this mode's whole shape. Note the difference
from [`hatsu:tensho`](../tensho/SKILL.md), which carries the same nature for the same reason but
reaches GitHub: **kokusen touches no remote at all.** The authorship nature of the diff being
committed belongs to the phase that wrote it, and kokusen never renames it.

> **The checks are green: put exactly what I meant onto this branch, under a message that says what
> changed and why, with no attribution that is not mine.**

Kokusen is **automatic**: phase three of `ren`, run after [`hatsu:rasengan`](../rasengan/SKILL.md)
reports green and before [`hatsu:amaterasu`](../amaterasu/SKILL.md) launches. It is not human-called,
it opens nothing, and **it never pushes** — publishing a branch is `hatsu:aka`'s, and `aka` is the
maintainer's own call.

---

## 1. Invocation

```
hatsu:kokusen [--type <feat|fix|chore|docs|refactor|test|perf|build|ci>] [--scope <scope>]
```

Both flags are hints for § 4's message; with neither, the type and scope are read off the diff and
stated in the report. One commit per coherent step: where a turn did two separable things, it is two
calls, not one message with a bulleted body.

## 2. The parameters, and where they come from

| Value | File → key |
|---|---|
| Trailers that may appear | `nen/workflow.json` → `commits.allowedAttributionTrailers` |
| Trailers that may never appear | `nen/workflow.json` → `commits.forbiddenTrailers` |
| The checks that must be green first | `nen/workflow.json` → `iteration.checks`, `iteration.lane` |
| The base this branch is not | `nen/workflow.json` → `branch.base` (§ 3's trunk refusal) |
| What the checks actually run | `nen/contract.json` → `project.verbs.<lane>.<check>` |

**When `nen/workflow.json` is absent, say so in the turn's report, in these words —** *"no
workflow.json: using the built-in defaults from `docs/WORKFLOW.md`"* — and use them:
`allowedAttributionTrailers` = `["Akatsuki-Agent"]`, `forbiddenTrailers` =
`["Co-Authored-By", "Claude-Session", "Signed-off-by"]`, `iteration.checks` = `["build"]`,
`branch.base` = `main`. The defaults are the strict reading, deliberately: a repository that has said
nothing about attribution gets the workflow's rule, not the harness's habit.

## 3. Before anything is staged

1. **The checks are green in this turn.** Run [`hatsu:rasengan`](../rasengan/SKILL.md) — do not trust
   an earlier turn's green. There is no build proof on disk at nen `0.3.0` and no
   `nen commit check --require-proof` to read one (that skill's § 10), so the only proof is a run that
   just happened. **A red build is never committed over**, not even "so the fix is saved."
2. **This is not the trunk.** `nen wc classify --repo <path> --base <branch.base>` reporting
   `must-move` means the work is on the trunk and belongs on a branch first —
   [`hatsu:breath`](../breath/SKILL.md)'s job, not this one's. Kokusen commits on a branch or it does
   not commit.

## 4. Triage — every path is looked at, some are asked about

**Never `git add -A` blind.**

```bash
nen stage triage --repo <path> [--scope <in-scope prefixes>] [--mentions "<the message you are about to write>"]
```

Detects, never decides, and exits `1` whenever anything is flagged. The five detectors, verified live
against a constructed working copy carrying one of each (`docs/ab/kokusen.md` § 2.1):

| Flag | Trigger |
|---|---|
| `secret-shape` | `.env`, `*.pem`, `*.key`, `credentials*`, or a token/key shape in the diff |
| `ignored` | the path is git-ignored and would need `-f` to stage |
| `binary` | the file's content is binary |
| `out-of-scope` | the path falls outside every `--scope` prefix — **omitted entirely** when `--scope` is not passed |
| `unmentioned-deletion` | a tracked path was deleted and its basename does not appear in `--mentions` |

One path can carry several reasons at once. **Present every flagged file together, with the reasons
`nen` printed, and take one answer per file.**

- **`secret-shape` is never askable.** There is no yes; the fix is to rotate or remove it. This is
  § 9's hard limit, and it is not softened by "it is only local, it is not pushed" — a commit is
  permanent the moment it exists, and the push that would publish it is one `hatsu:aka` away.
- **Two shapes have no detector and stay this skill's by eye** (the same residue
  [`hatsu:tensho`](../tensho/SKILL.md) § 3 names): a **local-config** file that is neither ignored nor
  out of scope (`.claude/settings.local.json`, editor state, OS cruft) reports **clean**, and so does
  an **unusually large** plain-text file. Ask about a local-config path by name regardless of what the
  verb reported, and weigh repo weight by eye.
- **Deliberately untracked leftovers stay untracked.** Offer the `.gitignore` line; do not commit
  something to be tidy.

Passing `--mentions` the message you are about to write is what makes `unmentioned-deletion`
meaningful — verified live: the same deleted path is flagged without it and clean with it.

## 5. The message

```bash
nen commit format --type <type> --subject "<short imperative subject>" [--scope <scope>] [--breaking] \
  [--body "<one paragraph>"] --trailer "Akatsuki-Agent=kurapika"
```

Validates **shape** only — a declared type, a non-empty subject under 72 characters, no trailing
punctuation — and exits `2` on a violation naming it (verified live, `docs/ab/kokusen.md` § 2.2). What
changed and why is this skill's to write, never nen's.

**The trailer rule, which is the whole point of this phase:**

- **`Akatsuki-Agent: kurapika` is the one admitted trailer.** It is what
  `commits.allowedAttributionTrailers` lists.
- **No AI attribution trailer, ever: no `Co-Authored-By:`, no `Claude-Session:`, no "Generated with
  …" line, and no model name anywhere in the message.** The git author stays the maintainer.
- **`Akatsuki-Run:` does not exist** for this plane — Hatsu has no CI run to name, and adding one
  would forge a machine-plane provenance the local plane does not have
  (`claude/agents/kurapika.md` § How you work).

> **A declared change from `claude/agents/kurapika.md` § *How you work*, recorded rather than
> smuggled.** That clause reads the maintainer's harness as *mandating* `Co-Authored-By:` and
> `Claude-Session:`, neither adding attribution of its own nor stripping theirs, and says explicitly
> that the final rule is a later constitution's to make. `nen/workflow.json`'s
> `commits.forbiddenTrailers` **is** that ruling, recorded by the maintainer in the repository's own
> policy file: in a repository carrying one, kokusen adds neither trailer. The clause's other half is
> untouched — kokusen **never strips** a trailer a hook or the maintainer's own tooling wrote onto
> their commit. It refuses to *add* one; deleting someone else's provenance metadata is a governance
> decision nobody asked for.

**Check the rendered message before it becomes a commit.** `nen commit format` at `0.3.0` does **not**
enforce this rule — verified live: `--trailer "Akatsuki-Agent=kurapika,Co-Authored-By=Claude
<noreply@anthropic.com>"` renders both trailers happily at exit `0`, and the verb has no `--repo`
flag at all, so it cannot read a `workflow.json` even in principle (`docs/ab/kokusen.md` § 2.3). The
guard is this skill's, applied by reading the rendered output against
`commits.forbiddenTrailers` before § 6 writes anything (§ 7).

## 6. The commit

```bash
nen commit format … > <message file>
git commit --file <message file>          # residue, § 7: no nen verb writes a commit
```

`--file`, never `-m` retyped from memory: the message that was validated is the message that lands.
**Never `--no-verify`** — a commit hook that refuses is the repository speaking, and the answer is to
fix what it named. Stage explicitly, path by path, from § 4's clean list plus every flagged path that
got an explicit yes; `git add -A` is barred (§ 9).

## 7. Residue — what has no verb at nen `0.3.0`

- **The forbidden-trailer refusal.** `nen commit format` renders any `--trailer` it is given and has
  no `--repo` to find a `workflow.json` with (§ 5, verified live). Both halves of the eventual
  mechanism — the verb reading the policy, and a `commit-msg` hook written by `nen scaffold init`
  that refuses a trailer outside `allowedAttributionTrailers` — are later waves. Until then the guard
  is: read the rendered message, compare it against `commits.forbiddenTrailers`, and refuse to commit
  a message that carries one.
- **Writing the commit itself.** `nen commit format` formats; nothing in nen commits. `git commit
  --file` is a named raw call, as is the explicit `git add <path>` for each approved path.
- **Local-config and size detection** in staging (§ 4) — no detector, by the verb's own account.
- **Reading `nen/workflow.json`** — no loader and no `nen schema check` row at this pin
  ([`hatsu:breath`](../breath/SKILL.md) § 2).
- **Whether two changes are one coherent commit** stays judgment; no verb splits an effort.

## 8. Authority

- **Permitted:** stage named paths, write one local commit per coherent step, and say what it
  contains.
- **Not permitted:** **any push** (that is `hatsu:aka`, human-called), any PR, any label, any merge,
  any force, any `--no-verify`, any amend of a commit that is already published, any commit on the
  trunk.
- **Not a gate event.** The per-file ask on a flagged path is an in-session question, not a gate; a
  `secret-shape` is not a question at all.

## 9. Hard limits

- **Never commits a flagged file without an explicit yes**, and **never commits a secret at all** —
  there is no yes for `secret-shape`; rotate or remove it.
- **Never `git add -A`**, and never stages a path it did not name.
- **Never adds an AI attribution trailer** — not `Co-Authored-By:`, not `Claude-Session:`, not a
  "Generated with …" line, not a model name in the subject or body. `Akatsuki-Agent: kurapika` is the
  whole of it.
- **Never strips a trailer the maintainer's own tooling wrote** (§ 5's callout).
- **Never pushes, never force-pushes, never `--no-verify`, never commits on the trunk.**
- **Never commits over a red build**, and never trusts an earlier turn's green.
