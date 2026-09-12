---
name: aka
description: Send the branch out — lint before rewriting history, squash only unpushed commits, bring the base underneath them, then own the full regression and instrumented-result capture on the final caught-up tree before pushing. The whole skill runs only on the maintainer's publish call; named composites may reuse only prepublication-verification, without squash or first-publish authority.
---

# Aka — the branch goes out

**Nature: Manipulator.** Pushing is git-side operation on shared state by definition, whichever
nature authored the diff.

> **Lint it, fold only unpublished history, put the base underneath it, prove the final tree with the
> full regression, and put that exact tree on the remote. No PR.**

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
| `tests.required` | which declared verbs § 6 must run green | `["test"]` |
| `tests.extra` | further verbs to run, not gating | `[]` |
| `branch.base` | the base § 4's squash and § 5's catch-up work against | `main` |
| `commits.allowedAttributionTrailers` | attribution trailers the commit may carry | `[]` |
| `commits.forbiddenTrailers` | attribution trailers that refuse the commit outright | includes `Hatsu-Agent`, `Akatsuki-Agent`, `Co-Authored-By`, `Claude-Session`, `Signed-off-by` |

`nen schema check --repo <path>` VALIDATES this file at the pinned build — verified live, the row
reads `ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}'
off 'main', checks: lint`. A malformed key is a FAIL **by pointer**, so this skill no longer checks
the shape by eye; it reads the values, and states the defaults whenever they are what applied.

> **Declared change from `claude/agents/kurapika.md` § *How you work* — named, not slipped in.**
> The agent definition today reads *"No AI attribution beyond the trailers the maintainer's own
> harness mandates — today `Co-Authored-By:` and `Claude-Session:` … you neither add attribution of
> your own nor strip theirs"*, and records that the final rule is a constitutional question left
> open. **`nen/workflow.json` is where the maintainer answers it for a given repository**, and this
> workflow answers it: `Hatsu-Agent` and `Akatsuki-Agent` are admitted, one per plane, and the other
> two are forbidden.
> Where the two disagree, **the repository's own `commits` block wins for that repository**, because
> it is the maintainer's recorded decision rather than an unresolved tension. A repository that
> ships no `commits` block gets the defaults above, and they say the same thing. This is a declared
> process change, disclosed here the way [`hatsu:futon`](../futon/SKILL.md) § *Declared process
> change* discloses its own.

## 3. Pre-squash lint gate

Before `nen wc squash` can rewrite even unpublished commits, run the declared lint row for
`iteration.lane`:

```bash
nen shu lint --repo <path> --lane <iteration.lane> --dry-run
nen shu lint --repo <path> --lane <iteration.lane>
```

Dry-run once on an unfamiliar repository. A red lint ends the run before history changes. A seat is
quoted. This gate is deliberately before the squash; it is cheap and prevents aka from replacing
several useful checkpoints with one red commit. It is not the regression phase.

**A red required test in § 6 is a G5 stop, and the run ends there.** Not "pushed with a note", not "pushed
because the failure is unrelated". [`hatsu:jutaisho`](../jutaisho/SKILL.md) § 4 renders it:
`nen stop --who Kurapika --gate G5 <efforts.md>`, the report link, lettered options with a ⭐ on the
report, the question through the surface's own picker.

**An empty configured set is `not applicable`, and aka says so.** Where `tests.required` and
`tests.extra` are both empty, tsukuyomi reports **`not applicable — no tests configured`** rather
than green ([`hatsu:tsukuyomi`](../tsukuyomi/SKILL.md) § 4), and **aka carries that word through
unchanged**: the push report says *"tests: not applicable — no tests configured
(`nen/workflow.json → tests.required` is empty); nothing was proven here."* It is **not** a G5 — an
empty required set is not a red suite — and it is **not** a pass. There is nothing to prove, and the
one thing aka must not do is let *nothing to prove* be read afterwards as *proved*. Hatsu's own
checkout is this case.

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
# 1. the base must be fresh — the merge base is computed against it
git -C <path> fetch origin <base>
# 2. published? ASK THE REMOTE. This is the default form.
git -C <path> ls-remote --heads origin refs/heads/<branch>   # empty output = not published
# 3. PUBLISHED ROW ONLY: ls-remote read the ref and transferred nothing. Make the object local,
#    then prove it is behind HEAD, before it is allowed to be a reset point.
git -C <path> cat-file -e <the SHA ls-remote printed>^{commit} \
  || git -C <path> fetch origin <branch>
git -C <path> merge-base --is-ancestor <the SHA ls-remote printed> HEAD
# 4. the squash point, per the table above
git -C <path> reset --soft <the SHA ls-remote printed | $(git merge-base origin/<base> HEAD)>
```

**`ls-remote` is the stated default, and the fetch of `<branch>` is the fallback.** The two are not
equivalent and the difference is not stylistic:

- **`ls-remote` answers the question that was actually asked.** *Is this branch on origin, and at
  what SHA?* — asked of origin, answered by origin, in one line, touching no local ref. On a first
  publish it exits `0` with empty output, which is a clean answer rather than a failure to interpret.
  And the SHA it prints **is** the squash point for the published row: no
  `refs/remotes/origin/<branch>` is consulted at all, so there is no stale tracking ref left in the
  decision to go wrong.

  > **But `ls-remote` reads the ref advertisement and downloads no objects, so step 3 is not
  > optional.** On a checkout that has never fetched `<branch>` — a `--single-branch` clone, a
  > machine that did not make the push, a branch advanced from somewhere else — the SHA it printed
  > is not in the local object database, and using it directly dies: *`fatal: Could not parse
  > object '<sha>'`*, exit `128`, reproduced live against a `--single-branch` clone over `file://`.
  > `git cat-file -e <sha>^{commit}` is the cheap test and `git fetch origin <branch>` is the cure;
  > **neither consults the tracking ref for the decision**, so the property above survives intact.
  > And a SHA that *is* present but is **not** an ancestor of `HEAD` is the worse case — `reset
  > --soft` would take it and silently drop every commit in between — which is why
  > `git merge-base --is-ancestor` runs before the reset and is § 4's third refusal below.
- **`git fetch origin <base> <branch>` is the fallback**, for a remote or a host where `ls-remote`
  is not available or not permitted. It fetches the base — which step 1 needs anyway — and, when
  `<branch>` is not on the remote, **exits non-zero with `fatal: couldn't find remote ref <branch>`.
  That failure is the answer, not an error**, and it is tolerated. But it is a noisy way to be told
  *no*: the line looks alarming in a transcript, and a network failure and an absent branch reach
  this run as the same non-zero. Where the fallback is what ran, the published test is
  `git rev-parse --verify --quiet refs/remotes/origin/<branch>` **after** that fetch, never before
  it.

**Either way, a stale tracking ref must never select the first-publish range.**
`refs/remotes/origin/<branch>` is what this checkout last heard, not what origin has: a branch
pushed from another machine, a worktree cut before the first publish, a `--single-branch` clone all
leave it missing or behind. Read it unrefreshed and an already-published branch takes the
first-publish row — every commit since the merge base is squashed away, history that other people
have already fetched is rewritten locally, and the push then fails non-fast-forward with the damage
already done. The default form sidesteps that hazard by never reading the ref; the fallback survives
it only by refreshing first.

State which form was used and what it answered, in the same line that names the squash range.

Then shape the one message with the verb that owns message shape:

```bash
nen commit format --type <feat|fix|chore|docs|refactor|test|perf|build|ci> \
  --scope <scope> --subject "<short imperative subject>" \
  --body "<what changed and why>"
```

Verified live at `v0.3.0` (`docs/ab/aka.md` § 2.2): the multi-line form renders subject, body and
trailer at exit `0`; shape violations (a bad type, an empty subject, a header over 72 characters, a
trailing period) each refuse at exit `2` with a named reason — the transcripts
[`hatsu:tensho`](../tensho/SKILL.md) § 4 already records, re-confirmed here at this pin.

> **Then the message file, and the gate on it.** The verb writes the message to **stdout** and its
> refusal to **stderr**, and at exit `2` stdout is **empty** — verified live, `0` bytes out, the
> sentence on stderr; a clean run is the mirror, `0` bytes on stderr. So:
>
> ```bash
> nen commit format … > <message file>     # exit 0 REQUIRED before the next line; NEVER 2>&1
> git -C <path> commit --file <message file>
> ```
>
> **Read the exit code before committing, and never merge the streams into that file.** `2>&1`
> commits the refusal *as the message* — which happened, landing *"nen: header line is 75 characters,
> over the 72-character convention"* as a commit subject (`docs/ab/mukai.md`) — and a plain redirect
> that ignores the code commits an empty file. **Exit `0` → use it. Exit `2` → stop, the message was
> refused and the reason is on stderr; fix the input and re-run. Exit `1` → the trailer policy could
> not be read** (`v0.4.0`+ with `--repo`, a malformed `nen/workflow.json`), **which is a repository
> defect to report and never to commit past.** An empty `<message file>` is the tell for either
> refusal, and it is checked whichever way the code was read. The verb's own behaviour is correct;
> the residue path around it is what needed the gate.
>
> **This matters more in `aka` than anywhere else**, because § 4's commit lands on top of a
> `git reset --soft`: a refusal committed here becomes the *only* message for every squashed commit,
> and the branch is about to be published. It is cheap to catch before § 7's push and expensive
> after.

**Four refusals run before the reset, every time** — these are `nen wc squash`'s own refusals
(brief § 4, P2), enforced by this skill until the verb exists:

1. **A dirty tree refuses.** `nen wc classify --repo <path> --base <base> --json` must report
   `on-branch-clean`; `state.uncommittedPaths[]` is printed if it does not.

   > **A detached `HEAD` refuses here too, and it is a different refusal — read it as one.** The verb
   > exits **`1`** with prose on stdout even under `--json` — *"could not determine the current branch …
   > This usually means a detached HEAD"* (verified live on a fixture; `docs/ab/surfaces.md` § 7, F5). That
   > is not a dirty tree and it is not a branch that needs cleaning: it is a checkout with **no branch to
   > publish**, which `aka` cannot invent — `git push -u origin HEAD` from a detached `HEAD` publishes a
   > ref nobody named, and the squash range in the table above has no `<branch>` to ask `origin` about.
   > **Stop, say the checkout is detached, and say the fix is [`hatsu:breath`](../breath/SKILL.md) § 3** —
   > which warms a detached `HEAD` through `nen shu warmup` and cuts the effort's branch from the trunk's
   > fresh tip. This is the ordinary starting shape of a Codex reviewer's worktree, so it is a case rather
   > than a curiosity, and it is **not** a G5: nothing has gone wrong, a step was skipped.
2. **A commit already on the upstream refuses.** The § 4 table's range is computed, never assumed,
   and a range that would include an already-pushed commit is refused outright, not force-pushed
   past.
3. **A non-ancestor squash point refuses** — if the computed point is not an ancestor of `HEAD`, the
   branch has been rewritten under this run and the state is reported instead.
4. **A forbidden trailer refuses.** § 2's `commits.forbiddenTrailers`.

> **RETIRED at nen `0.5`: `nen wc squash` IS the verb, and it enforces all four refusals itself.**

```bash
nen wc squash --repo <path> --onto <ref> --message-file <file> [--dry-run] [--json]
```

> It folds every commit `git merge-base <onto> HEAD` finds into ONE, whose message is held to the
> same shape `nen commit format` enforces — a Conventional Commits header ≤ 72 characters, trailers
> as `Key: value` lines in the final paragraph, and **any attribution trailer this repository's
> `nen/workflow.json` does not admit refused**, in the same words that verb uses. Every refusal runs
> **before a single write**, all at exit `2`: a dirty working tree (every uncommitted and untracked
> path named); an `--onto` that is not an ancestor of `HEAD` (what `git merge-base` found instead,
> quoted); and any commit in the range already reachable from `@{upstream}`, fetched first — *"already
> published; squashing would rewrite pushed history"*. **Fewer than two commits to fold is not a
> refusal**: exit `0`, one line, nothing moves.
>
> Both refusals verified live at `v0.5.0` (`docs/ab/aka.md` § *Retired at nen 0.5*): against a dirty
> fixture, exit `2` naming all five paths; against this branch, exit `2` naming the already-published
> commit by SHA and subject. The mechanism is `git reset --soft <merge-base>` then `git commit -F`,
> both through the seam — so a commit that then fails leaves the originals recoverable from
> `ORIG_HEAD` and the reflog, which the verb's own error names. It never touches a remote beyond the
> read-only fetch, never pushes, and never force-anything.

**Enforcement of the trailer rule is three-layered, and the third layer is now the binary's.** (a)
**This skill refuses to write the trailer** — the rendered message is read and compared against
`commits.forbiddenTrailers` before the commit, agent-side, and it is the layer that is live
everywhere and survives a forgotten flag; (b) the **target repository's `commit-msg` hook**, which
`nen scaffold init` generates from `commits.allowedAttributionTrailers`, and which stays
**target-dependent** — it exists only in a repository that has been scaffolded, and hatsu's own
checkout has not; (c) **`nen commit format --repo` and `nen wc squash`** refusing it outright, both
at the pinned build, verified live. Say which of (b) and (c) the repository in front of you
actually has; never describe a hook as installed where none is.

> **Layer (c) is live at this pin, and any wording that still calls it residue is stale.**
> Re-verified on 2026-09-10 from this repository's checkout: `nen commit format --repo . --trailer
> "Co-Authored-By=someone"` is refused at exit `2`, naming the policy file and the two admitted keys.
> **The reason this needs saying** is that a headless Cursor run against nen `0.3.0` found `--repo`
> *accepted and silently ignored* there, so the guard never fired and the flag read as though it had
> (`docs/ab/surfaces.md` § 8, F12). That was the old pin. **Do not present the trailer guard as
> something no verb enforces** — layer (a) stays because it survives a forgotten flag, not because
> (c) is missing.

**One commit with configured author/committer metadata and no attribution trailer.** No `Hatsu-Agent`,
`Akatsuki-Agent`, `Co-Authored-By`, `Claude-Session`, `Signed-off-by`, "Generated with" line,
agent alias, or model name belongs in the message. The final PR body's `## Agent attribution`
section is the sole participant ledger. **Never `--no-verify`** — where the repository does carry
a `commit-msg` hook it is layer (b), and skipping it is skipping the rule.

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

## 6. `prepublication-verification` — full regression on the final tree

This named phase is the stable phase-ownership anchor for composites. A composite may reuse it after
a review fix, coverage remediation, or catch-up without re-entering aka's human-call boundary and
without acquiring aka's squash or first-publish authority.

1. Reuse § 3's lint only when catch-up was a complete no-op. Any changed tree path — source, test,
   snapshot, execution configuration, metadata, or otherwise — reruns the declared lint row on the
   caught-up tree.
2. Run [`hatsu:tsukuyomi`](../tsukuyomi/SKILL.md) in **full-regression mode** over every
   `tests.required` row and configured extra.
3. Where the full regression produces coverage instrumentation, preserve that result and record its
   provenance: final tree hash, lane, verb, exact argv, artifact path, and run time. Aka collects
   instrumented execution data; it does not measure or gate coverage.
4. When the full-regression list includes `ui-test`, tsukuyomi invokes that declared suite exactly
   once and [`hatsu:kotoamatsukami`](../kotoamatsukami/SKILL.md) supplies its UI-specific result and
   snapshot handling. Do not invoke the suite a second time. A re-recorded snapshot changes the tree
   and therefore invalidates this run.

The regression must follow the final catch-up. Any later tree change — including a review fix,
snapshot acceptance, test added by gyo, execution-configuration edit, conflict resolution, metadata
edit, or another catch-up — invalidates the lint/regression evidence and returns here before
publication. A red required suite is G5. An empty configured set remains
`not applicable — no tests configured`, neither green nor a stop.

Nen can run declared suites and parse their artifacts, but the pinned interface does not emit one
durable regression-plus-coverage provenance envelope. Save those observed fields as transient JSON
at `.nen/regression/<lane>.json`, with contract `hatsu.regression-capture/v0.1`; this is Hatsu residue,
not Nen output, and must never claim fields the invocation and git tree did not prove. A consumer
whose `coverage` row reruns tests must split collection from extraction before
mukai can honor the boundary; mukai may not hide a second full-suite run inside coverage.

## 7. Push — or first-publish

```bash
git -C <path> push origin HEAD                # already published
git -C <path> push -u origin HEAD             # first publish: also sets upstream
```

**Residue, and still residue at the pinned build: there is no push verb.** `nen pr cascade-main`
pushes, but only as the tail of a merge it performed itself, and only to the branch it just merged
into — it is a cascade, not a push (its own `--help`: *"Merges (never rebases) the trunk into the
current branch and pushes on a clean merge"*), and its new `--no-push` moves in the other direction
entirely. So the push is git's, by hand, named here.

- **Never `--force`, never `--force-with-lease`, never `+refs/`.** § 4's range computation exists so
  that a plain push always suffices; if a plain push is rejected as non-fast-forward, that is a
  **finding to report**, not a flag to add — something moved the remote branch and the maintainer
  needs to know before anything overwrites it.
- **Never pushes `main`**, or any `branch.base`. The `PreToolUse` guard in `hooks/hooks.json` refuses
  a `git push` on the trunk at the harness level; this skill refuses it at the rule level, and both
  are the answer to the same question.
- **Never opens, edits or comments on a PR.** Not even to say the branch moved.

## 8. Report, and stop

One line, then stop: the branch, whether it was a first publish, the one commit's subject, the base
and how it got underneath (rebase or merge), the required tests that ran green, and the pushed SHA.

**Re-render the turn report before stopping.** The last render was truthful when it was written and
is stale one step later — it says nothing was pushed about a branch that is now on `origin`.
[`hatsu:rikugan`](../rikugan/SKILL.md) § 5 owns this: the `turn` variant, re-rendered at the same
address, with the push written into **01 Accomplished**. There is no fourth variant and aka does not
invent one.

**Then say what is available next, without asking for it**: `hatsu:mukai` opens the PR.
[`hatsu:ren`](../ren/SKILL.md)'s loop is over for this effort — its own rule is that it ends only on
`aka` or [`hatsu:tensho`](../tensho/SKILL.md), and this was `aka`.

## Residue

1. **RETIRED at nen `0.5`: `nen wc squash --onto <ref> --message-file <f>`** — the verb folds the
   range and enforces all four refusals itself, before a single write (§ 4, both refusals verified
   live at exit `2`). `git reset --soft` plus a hand-gated `nen commit format` is no longer the path,
   and **the by-hand precondition checks go with it**: the verb runs the ancestry and upstream tests.
   Making an `--onto` that names an object this checkout has not got usable is still the caller's —
   `git fetch origin <branch>` first, since `ls-remote` transfers no objects.
2. **RETIRED at nen `0.5`: the forbidden-trailer refusal in `nen commit format --repo`** — verified
   live at the pin, exit `2` naming the file and the admitted key. The refusal is now (a) this
   skill's rule, (c) the verb's, and (b) a `commit-msg` hook **only in a repository that has been
   scaffolded with one** — which hatsu's own checkout still has not.
3. **The published/unpublished test** — `git ls-remote --heads origin refs/heads/<branch>`, asked of
   the remote directly, which is the default form; `git fetch origin <base> <branch>` (a missing
   remote branch tolerated) **then** `git rev-parse --verify --quiet refs/remotes/origin/<branch>` is
   the fallback (§ 4). `nen wc classify --json` reports the branch and its distance from the base,
   never the remote, and nothing in nen refreshes the branch's tracking ref for this decision.
4. **The push itself** — `git push [-u] origin HEAD`. `nen pr cascade-main` pushes only as the tail
   of its own merge and is not a push verb. **Genuinely still residue at the pinned build.**
5. **RETIRED at nen `0.5`: `nen/workflow.json` is validated.** `nen schema check --repo <path>` carries
   an `ok  nen/workflow.json` row at the pinned build (verified live, exit `1` on Hatsu's own
   taxonomy-less checkout with that row `ok`), and a malformed policy file is a FAIL **by pointer**
   rather than something this skill notices by eye. § 2's keys are still read here — reading a file is
   not residue; nothing in nen hands the policy out except `shu coverage`'s ladder and
   `commit format`'s trailer list.

## Authority

- **Permitted on the maintainer's own aka call:** run the declared tests; reset and re-commit
  **unpushed** commits; invoke [`hatsu:ao`](../ao/SKILL.md); push a **non-base** branch, including a
  first publish that sets upstream.
- **Permitted when a named composite calls § 6:** only the lint/regression/UI execution and capture
  in `prepublication-verification`. This helper authority includes no squash, rewrite, push, first
  publish, PR action, or other aka step.
- **Not permitted:** opening or touching a PR; any label; any merge of the base; any force-push;
  any rewrite of a commit that exists on the remote; `--no-verify`; pushing `branch.base`.
- **The delegation is one run wide and ends when this run ends.** It is not standing authority to
  push this branch again later.

## Hard limits

- **The whole aka run never runs unasked**, and **never prompts for itself** — no agent, skill,
  report or stop option proposes `hatsu:aka` (§ 1). A named composite may invoke only § 6 under the
  helper authority stated above; that is not an aka publish run.
- **Never pushes over a red required test** — G5, and the run ends (§ 6).
- **Never force-pushes, and never rewrites a commit that is already on the remote** — a rejected
  fast-forward is reported, never flagged past (§ 4, § 6).
- **Never decides the squash range from a stale tracking ref** — the remote is asked with
  `ls-remote` (the default), or `origin/<branch>` is refreshed by the fallback's fetch, before the
  range is chosen (§ 4). A ref this checkout last heard about is not evidence about origin.
- **Never carries attribution** — no `Hatsu-Agent`, `Akatsuki-Agent`, `Co-Authored-By`,
  `Claude-Session`, `Signed-off-by`, "Generated with" line, agent alias, or model name in the message.
- **Never runs `git commit --file` on a message file `nen commit format` did not exit `0` for**,
  and never merges the verb's two streams into that file (§ 4). On top of a `reset --soft`, a
  refusal committed as the message is the whole effort's message.
- **Never `--no-verify`**, and never pushes `main` or any configured base.
- **Never opens a pull request** — that is `hatsu:mukai`'s, and the split is deliberate.
- **Never patches a test to pass** — tsukuyomi's rule, binding here because this is where it is
  tempting.
- **Never presents by-hand git as a verb's output** — every step in § Residue is named where it runs.
