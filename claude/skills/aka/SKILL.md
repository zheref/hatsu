---
name: aka
description: Send the branch out — run the required tests, squash the unpushed commits into one, bring the base underneath it, and push. Use ONLY when the maintainer invokes hatsu:aka or asks in their own words to push this, send it up, or publish the branch. It opens no pull request, carries no AI attribution trailer, stops at G5 on a red required test, and never force-pushes or rewrites a commit that is already on the remote. Agents never propose it: the call is the maintainer's, always.
---

# Aka — the branch goes out

**Nature: Manipulator.** Pushing is git-side operation on shared state by definition, whichever
nature authored the diff.

> **Prove it, fold it into one commit, put the base underneath it, and put it on the remote. No PR.**

Aka is the **first human call** in the local plane. Everything before it —
[`hatsu:ren`](../ren/SKILL.md)'s turns, [`hatsu:kokusen`](../kokusen/SKILL.md)'s commits — happens
without asking, because none of it leaves the machine. Aka is where the work becomes something
another person can fetch, and that boundary is the maintainer's to cross.

**It opens no pull request.** That is [`hatsu:mukai`](../mukai/SKILL.md)'s run, and
[`hatsu:shibari`](../shibari/SKILL.md)'s step inside it. Aka ends with a pushed branch and nothing
else, deliberately: a push and a PR are two decisions, and folding them makes one of them
unaskable.

---

## 1. Invocation — and who is allowed to say it

```
hatsu:aka
```

**No arguments, so there is nothing for `nen parse` to own** — and saying so is the point, not an
omission. `nen parse <skill> --grammar <template> --line <text>` exists for a grammar; a bare verb
has none, and inventing an optional clause so that a parse can be echoed would be ceremony.

**The call is the maintainer's, in their own words or by name.** Two consequences, both binding:

- **No agent ever prompts for it.** Not [`hatsu:jutaisho`](../jutaisho/SKILL.md) at the end of a
  turn, not [`hatsu:rikugan`](../rikugan/SKILL.md) in a report, not a composite offering it as a
  next step, not a lettered option in a stop. A report may say *the branch is ready to go out*; it
  may not say *shall I push it?* An agent that asks for permission it was told to wait for has
  converted a human call into a nudge, and the nudge is what the local plane's push discipline
  exists to prevent.
- **One call, one run.** A `yes` for this push is not authority for the next one. Say the run has
  started and say when it ends.

## 2. The parameters — `nen/workflow.json`, with the defaults stated

| Key | Used for | Default when the key (or the file) is absent |
|---|---|---|
| `tests.required` | which declared verbs § 3 must run green | `["test"]` |
| `tests.extra` | further verbs to run, not gating | `[]` |
| `branch.base` | the base § 4's squash and § 5's catch-up work against | `main` |
| `commits.allowedAttributionTrailers` | the only trailers § 4's commit may carry | `["Akatsuki-Agent"]` |
| `commits.forbiddenTrailers` | trailers that refuse the commit outright | `["Co-Authored-By", "Claude-Session", "Signed-off-by"]` |

`nen schema check` does not validate this file at `v0.3.0` (verified live, `docs/ab/rikugan.md`
§ 2.4); it is read as data, and the defaults above are stated whenever they are what applied.

> **Declared change from `claude/agents/kurapika.md` § *How you work* — named, not slipped in.**
> The agent definition today reads *"No AI attribution beyond the trailers the maintainer's own
> harness mandates — today `Co-Authored-By:` and `Claude-Session:` … you neither add attribution of
> your own nor strip theirs"*, and records that the final rule is a constitutional question left
> open. **`nen/workflow.json` is where the maintainer answers it for a given repository**, and this
> workflow answers it: `Akatsuki-Agent` is the one admitted trailer and the other two are forbidden.
> Where the two disagree, **the repository's own `commits` block wins for that repository**, because
> it is the maintainer's recorded decision rather than an unresolved tension. A repository that
> ships no `commits` block gets the defaults above, and they say the same thing. This is a declared
> process change, disclosed here the way [`hatsu:futon`](../futon/SKILL.md) § *Declared process
> change* discloses its own.

## 3. Tests first — [`hatsu:tsukuyomi`](../tsukuyomi/SKILL.md), and G5 if red

**Aka's first step is tsukuyomi's whole engine**, not a substitute for it: run every verb in
`tests.required` (plus `tests.extra`) through the repository's own declaration, parse the results,
fix and re-run, or stop. This skill restates none of that protocol — read it there.

```bash
nen shu test --repo <path> [--lane <lane>] --dry-run     # once, on a repo you have not tested here
nen shu test --repo <path> [--lane <lane>]
```

The `--dry-run` form prints the exact argv, cwd, env names and declared artifacts and spawns
nothing — verified live at `v0.3.0` against a constructed declaration (`docs/ab/aka.md` § 2.1),
exit `0`, `--json` carrying `{contract: "nen.shu.test/v0.1", steps[], artifacts[], log.mode:
"dry-run"}`. Exit codes are `claude/agents/kurapika.md` § *The `shu` verbs*': `1` is the ordinary red
run, `2` a usage or declaration fault, `3` an unsupported host (say which hosts the declaration
allows, and stop), `4` a **seat** whose reason is quoted verbatim, `5` sends you to
`nen shu tools`.

**A red required test is a G5 stop, and the run ends there.** Not "pushed with a note", not "pushed
because the failure is unrelated". [`hatsu:jutaisho`](../jutaisho/SKILL.md) § 4 renders it:
`nen stop --who Kurapika --gate G5 <efforts.md>`, the report link, lettered options with a ⭐ on the
report, the question through the surface's own picker.

**A test is never patched to pass.** That rule is tsukuyomi's and it is repeated here only because
this is the step where the temptation lands: the maintainer has already asked for the push.

## 4. Squash the unpushed commits into one

A branch that leaves the machine leaves as **one commit per effort**, not as the fourteen turns
[`hatsu:ren`](../ren/SKILL.md) produced getting there.

**Which commits are "unpushed" is decided by whether the branch is published, and getting this
wrong is a force-push:**

| Branch state | Squash range | Why |
|---|---|---|
| **Not on origin** — first publish | everything since `git merge-base origin/<base> HEAD` | nothing has been fetched by anyone; all of it is still yours to shape |
| **Already on origin** | only the commits after `origin/<branch>` | anything at or below `origin/<branch>` is somebody else's history now |

```bash
# refresh what origin actually has, FIRST — a missing remote branch is tolerated
git -C <path> fetch origin <base> <branch>
# published?
git -C <path> rev-parse --verify --quiet refs/remotes/origin/<branch>
# the squash point, per the table above
git -C <path> reset --soft <origin/branch | $(git merge-base origin/<base> HEAD)>
```

**The refresh is not optional, and a stale tracking ref must never select the first-publish range.**
`refs/remotes/origin/<branch>` is what this checkout last heard, not what origin has: a branch
pushed from another machine, a worktree cut before the first publish, a `--single-branch` clone all
leave it missing or behind. Read it unrefreshed and an already-published branch takes the
first-publish row — every commit since the merge base is squashed away, history that other people
have already fetched is rewritten locally, and the push then fails non-fast-forward with the damage
already done.

`git fetch origin <base> <branch>` exits non-zero when `<branch>` is not on the remote; **that is
the answer, not an error** — tolerate it, or ask the remote directly and never touch the local ref:

```bash
git -C <path> ls-remote --heads origin refs/heads/<branch>   # empty output = not published
```

Prefer `ls-remote` wherever the fetch's exit code cannot be told apart from a network failure. State
which form was used and what it answered, in the same line that names the squash range.

Then shape the one message with the verb that owns message shape:

```bash
nen commit format --type <feat|fix|chore|docs|refactor|test|perf|build|ci> \
  --scope <scope> --subject "<short imperative subject>" \
  --body "<what changed and why>" --trailer "Akatsuki-Agent=kurapika"
```

Verified live at `v0.3.0` (`docs/ab/aka.md` § 2.2): the multi-line form renders subject, body and
trailer at exit `0`; shape violations (a bad type, an empty subject, a header over 72 characters, a
trailing period) each refuse at exit `2` with a named reason — the transcripts
[`hatsu:tensho`](../tensho/SKILL.md) § 4 already records, re-confirmed here at this pin.

**Four refusals run before the reset, every time** — these are `nen wc squash`'s own refusals
(brief § 4, P2), enforced by this skill until the verb exists:

1. **A dirty tree refuses.** `nen wc classify --repo <path> --base <base> --json` must report
   `on-branch-clean`; `state.uncommittedPaths[]` is printed if it does not.
2. **A commit already on the upstream refuses.** The § 4 table's range is computed, never assumed,
   and a range that would include an already-pushed commit is refused outright, not force-pushed
   past.
3. **A non-ancestor squash point refuses** — if the computed point is not an ancestor of `HEAD`, the
   branch has been rewritten under this run and the state is reported instead.
4. **A forbidden trailer refuses.** § 2's `commits.forbiddenTrailers`.

> **`nen wc squash` does not exist at `v0.3.0`; nor does the trailer guard — both verified live,
> and both are residue.** `nen wc` carries exactly one verb, `classify` (its own `--help`). And
> **`nen commit format` renders a forbidden trailer without complaint**: verified live,
> `--trailer "Co-Authored-By=Claude <noreply@anthropic.com>"` prints
> `Co-Authored-By: Claude <noreply@anthropic.com>` and exits **`0`** (`docs/ab/aka.md` § 2.2). The
> `--repo`-aware refusal is P2 (brief § 4).

**Enforcement is three-layered, and only the first layer is this skill's.** (a) **This skill refuses
to write the trailer** — the rendered message is read and compared against
`commits.forbiddenTrailers` before the commit, agent-side, and it is the layer that is live
everywhere; (b) the **target repository's `commit-msg` hook**, which `nen scaffold init` generates
from `commits.allowedAttributionTrailers` at **nen `0.4.0`** (in flight; KroApple and kro-pwa
already carry one); (c) **`nen commit format --repo`** refusing it, also at `0.4.0`. **At the pinned
`0.3.0`, (b) and (c) are target-dependent**: say which of them the repository in front of you
actually has, and where it has neither, say that the refusal is the agent's alone — never describe
it as mechanical where no hook is installed.

**One commit, the maintainer as git author, `Akatsuki-Agent: kurapika` and nothing else.** No
`Co-Authored-By`, no `Claude-Session`, no `Signed-off-by`, no "Generated with" line, no model name
anywhere in the message. **Never `--no-verify`** — where the repository does carry a `commit-msg`
hook it is layer (b), and skipping it is skipping the rule.

## 5. Then [`hatsu:ao`](../ao/SKILL.md) — the base underneath it

Aka's third step is ao's whole engine: fetch the base, rebase if nothing is published and merge if
something is, classify every conflict, resolve the mechanical ones, stop at G5 on a semantic one.
**This skill restates none of it.**

Two things aka relies on and does not re-derive:

- **Ao never pushes** (its own hard limit). The push below is aka's, and it happens after ao has
  returned and said what it did.
- **A semantic conflict inside ao ends this run.** The push does not happen; the branch is left
  where ao left it, said out loud.

**Order matters: squash, then catch up.** Squashing after a merge would fold the base's merge commit
into the effort's commit and lose the ancestry that makes the merge legible.

## 6. Push — or first-publish

```bash
git -C <path> push origin HEAD                # already published
git -C <path> push -u origin HEAD             # first publish: also sets upstream
```

**Residue: there is no push verb at `v0.3.0`.** `nen pr cascade-main` pushes, but only as the tail of
a merge it performed itself, and only to the branch it just merged into — it is a cascade, not a
push (its own `--help`: *"Merges (never rebases) the trunk into the current branch and pushes on a
clean merge"*), and `docs/ab/ao.md` § 2.3 records it doing exactly that live. So the push is git's,
by hand, named here.

- **Never `--force`, never `--force-with-lease`, never `+refs/`.** § 4's range computation exists so
  that a plain push always suffices; if a plain push is rejected as non-fast-forward, that is a
  **finding to report**, not a flag to add — something moved the remote branch and the maintainer
  needs to know before anything overwrites it.
- **Never pushes `main`**, or any `branch.base`. The `PreToolUse` guard in `hooks/hooks.json` refuses
  a `git push` on the trunk at the harness level; this skill refuses it at the rule level, and both
  are the answer to the same question.
- **Never opens, edits or comments on a PR.** Not even to say the branch moved.

## 7. Report, and stop

One line, then stop: the branch, whether it was a first publish, the one commit's subject, the base
and how it got underneath (rebase or merge), the required tests that ran green, and the pushed SHA.

**Then say what is available next, without asking for it**: `hatsu:mukai` opens the PR.
[`hatsu:ren`](../ren/SKILL.md)'s loop is over for this effort — its own rule is that it ends only on
`aka` or [`hatsu:tensho`](../tensho/SKILL.md), and this was `aka`.

## Residue

1. **`nen wc squash --onto <ref> --message-file <f>`** — absent at `v0.3.0` (`nen wc` has one verb,
   `classify`). § 4 runs `git reset --soft <computed point>` plus one `nen commit format`-shaped
   commit, and enforces the verb's four refusals by hand first.
2. **The forbidden-trailer refusal in `nen commit format`** — verified live to be absent: a
   `Co-Authored-By` trailer renders at exit `0`. Until the P2 `--repo`-aware guard lands, the
   refusal is **this skill's rule** (always), plus a `commit-msg` hook **only in a repository that
   has been scaffolded with one** — which hatsu's own checkout has not.
3. **The published/unpublished test** — `git fetch origin <base> <branch>` (a missing remote branch
   tolerated) **then** `git rev-parse --verify --quiet refs/remotes/origin/<branch>`, or
   `git ls-remote --heads origin refs/heads/<branch>` asked of the remote directly. `nen wc classify
   --json` reports the branch and its distance from the base, never the remote, and nothing in nen
   refreshes the branch's tracking ref for this decision.
4. **The push itself** — `git push [-u] origin HEAD`. `nen pr cascade-main` pushes only as the tail
   of its own merge and is not a push verb.
5. **`nen/workflow.json` is unvalidated at `v0.3.0`** — no row in `nen schema check` (verified live).
   § 2's keys are read as data with the defaults stated.

## Authority

- **Permitted, and only on the maintainer's own call:** run the declared tests; reset and re-commit
  **unpushed** commits; invoke [`hatsu:ao`](../ao/SKILL.md); push a **non-base** branch, including a
  first publish that sets upstream.
- **Not permitted:** opening or touching a PR; any label; any merge of the base; any force-push;
  any rewrite of a commit that exists on the remote; `--no-verify`; pushing `branch.base`.
- **The delegation is one run wide and ends when this run ends.** It is not standing authority to
  push this branch again later.

## Hard limits

- **Never runs unasked**, and **never prompts for itself** — no agent, skill, report or stop option
  proposes `hatsu:aka` (§ 1).
- **Never pushes over a red required test** — G5, and the run ends (§ 3).
- **Never force-pushes, and never rewrites a commit that is already on the remote** — a rejected
  fast-forward is reported, never flagged past (§ 4, § 6).
- **Never decides the squash range from a stale tracking ref** — `origin/<branch>` is refreshed, or
  the remote asked with `ls-remote`, before the range is chosen (§ 4). A ref this checkout last
  heard about is not evidence about origin.
- **Never carries an AI attribution trailer** — `Akatsuki-Agent` alone, per § 2's `commits` block;
  never `Co-Authored-By`, `Claude-Session`, `Signed-off-by`, a "Generated with" line, or a model
  name in the message.
- **Never `--no-verify`**, and never pushes `main` or any configured base.
- **Never opens a pull request** — that is `hatsu:mukai`'s, and the split is deliberate.
- **Never patches a test to pass** — tsukuyomi's rule, binding here because this is where it is
  tempting.
- **Never presents by-hand git as a verb's output** — every step in § Residue is named where it runs.
