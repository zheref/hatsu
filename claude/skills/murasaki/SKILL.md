---
name: murasaki
description: Bring the branch up to date with its base, re-prove it with the declared build and the declared tests, and push the result — but only if the branch was already published. Use when the maintainer invokes hatsu:murasaki [from <base>], asks to catch this branch up and send the update, or whenever hatsu:mukai starts or hatsu:en finds the PR behind. Murasaki composes hatsu:ao, hatsu:rasengan and hatsu:tsukuyomi by name and restates none of their protocol. It never squashes, never force-pushes, never first-publishes a branch, and never opens a pull request.
---

# Murasaki — the branch, current and still true

**Nature: Manipulator.** The last step touches the remote, and an operation that moves shared state is
GitHub-side operation whichever nature authored the diff — the same reading
[`hatsu:aka`](../aka/SKILL.md) and [`hatsu:ao`](../ao/SKILL.md) make of themselves.

> **Put the base underneath me, prove it still builds and still passes, and — only if this branch is
> already out there — put the update on the remote.**

Murasaki is [`hatsu:mukai`](../mukai/SKILL.md)'s first step and the step
[`hatsu:en`](../en/SKILL.md) runs when a PR falls behind its base. It is also invocable alone. It is
the **maintenance** half of publishing, where [`hatsu:aka`](../aka/SKILL.md) is the **decision**
half: aka is the human call that first sends a branch out, and murasaki keeps a branch that has
already gone out honest afterwards.

**This file composes. It does not re-specify.** Each of the three steps is another skill's, named and
linked, and its procedure, its exit-code reactions, its refusals and its residue live there. A rule
in this file that is really ao's or tsukuyomi's is in the wrong file — go read it where it is
authored, because a rule restated in two places drifts in one of them.

---

## 1. Invocation

```
hatsu:murasaki [from <base>]
```

```bash
nen parse murasaki --grammar "from [<base>]" --line "<the invocation, minus the hatsu:murasaki prefix>"
```

Verified live at `v0.3.0` (`docs/ab/murasaki.md` § 2.1): `from release/1.4` → `base: release/1.4`,
exit `0`. The clause is anchored behind a literal for the reason
[`hatsu:rikugan`](../rikugan/SKILL.md) § 1 records, and the shape is deliberately ao's, because the
clause means the same thing in both.

> **A bare invocation is not parsed, and that is the verb's own answer rather than an omission.**
> Verified live: `--line ""` against this grammar refuses at exit `2` — *"the line must open with the
> literal 'from' — it is what introduces `<base>`"*. There is nothing to parse in `hatsu:murasaki`
> with no clause, so the parse runs **only when the maintainer typed one**; with no clause the base
> is `nen/workflow.json` → `branch.base`, default `main`. Name the base out loud either way.

## 2. The parameters — `nen/workflow.json`, with the defaults stated

| Key | Used for | Default when the key (or the file) is absent |
|---|---|---|
| `branch.base` | what § 4 puts underneath the branch | `main` |
| `iteration.checks` | the declared verbs § 5 re-proves the merge with | `["build"]` |
| `iteration.lane` | the lane those verbs run in | `project.defaultLane` |
| `tests.required` | the suites § 5 must see green | `["test"]` |
| `tests.extra` | suites run alongside them, not gating | `[]` |

`nen schema check --repo <path>` VALIDATES this file at the pinned `v0.5.0` — verified live, the row
reads `ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}'
off 'main', checks: lint`. A malformed key is a FAIL **by pointer**, so this skill no longer checks
the shape by eye; it reads the values, and states the defaults whenever they are what applied.

## 3. The three steps, in order

| # | Step | The skill that owns it | Why it is here |
|---|---|---|---|
| 1 | **pull** | [`hatsu:ao`](../ao/SKILL.md) | fetch the base, rebase what is unpublished / merge what is published, classify every conflict, resolve the mechanical ones |
| 2 | **prove** | [`hatsu:rasengan`](../rasengan/SKILL.md) **then** [`hatsu:tsukuyomi`](../tsukuyomi/SKILL.md) | the declared `iteration.checks`, then the declared `tests.required` — on the merged tree, not on the tree before it |
| 3 | **publish the update** | this file, § 6 | `git push origin HEAD` — **only if the branch was already on the remote** |

**The order is load-bearing in three places:**

- **1 before 2.** The point of the build and the suite here is to prove *the merge*, not the branch.
  Running them first would prove the tree nobody is about to push.
- **rasengan before tsukuyomi inside step 2.** A red build makes a test result meaningless: the
  suite either did not compile or ran against yesterday's artifact. Build first, always.
- **2 before 3.** Nothing goes to the remote that has not just been proven on the tree that is
  going. A push that re-runs the checks afterwards is a push that already happened.

**A step that refuses ends the run where it refused, and nothing is pushed.** Ao stopping on a
semantic conflict (§ 4), rasengan finding a red build, tsukuyomi finding a red suite — each is that
skill's own handling. Murasaki adds nothing to it except the guarantee that **step 3 does not run**.

## 4. Step 1 — [`hatsu:ao`](../ao/SKILL.md), and the conflict that ends the run

Ao's whole engine, unchanged: the published/unpublished test, rebase-or-merge, the conflict table,
the mechanical resolutions, the re-proved build. **This skill restates none of it.**

**A semantic conflict is ao's G5, not murasaki's**, and murasaki neither retries past it nor
re-renders it. Ao leaves the tree conflicted, shows both sides verbatim, prints the abort line and
stops; this run ends there, having pushed nothing, and says so in one line. The answer resumes it.

**Ao never pushes** — its own hard limit — and being called from inside murasaki does not lend it
one. § 6's push is murasaki's, made after ao has returned and said what it did.

## 5. Step 2 — build, then tests, on the merged tree

[`hatsu:rasengan`](../rasengan/SKILL.md) runs every `iteration.checks` verb through the repository's
own declaration; [`hatsu:tsukuyomi`](../tsukuyomi/SKILL.md) runs every `tests.required` verb (and
`tests.extra`) through it. Their exit-code tables — `1` red, `2` declaration, `3` host, `4` a
**seat** quoted verbatim, `5` `nen shu tools` — are `claude/agents/kurapika.md` § *The `shu` verbs*'
and are handled there, not here.

Two things murasaki asserts on top of them, and only two:

- **`not applicable — no tests configured` is carried through unchanged.** Where `tests.required`
  and `tests.extra` are both empty, tsukuyomi reports that phrase rather than green
  ([`hatsu:tsukuyomi`](../tsukuyomi/SKILL.md) § 4), and murasaki repeats the phrase in the push
  report: *"tests: not applicable — no tests configured; nothing was proven here."* It is **not** a
  reason to stop — an empty required set is not a red suite — and it is **not** a pass. Hatsu's own
  checkout is this case.
- **A red result at step 2 stops the run without a stop banner of its own.** The **G5 on a red
  required suite is [`hatsu:aka`](../aka/SKILL.md)'s**, raised at the moment a push was about to
  happen for the first time. Murasaki is not that moment: the branch is already out there, the fix
  is ordinary work, and the honest report is *"the merge is on disk, it does not pass, nothing was
  pushed"*. Say that, and let the next turn fix it.

## 6. Step 3 — push, and only for a branch that was already published

```bash
git -C <path> push origin HEAD
```

**The published test is the same one ao already ran, and its answer is re-used rather than
re-derived:**

| Ao's answer at § 3 of its own file | What murasaki does |
|---|---|
| **published** — `origin/<branch>` resolves after a refresh; ao **merged** the base in | **push.** The merge is a descendant of `origin/<branch>`, so a plain push is a fast-forward |
| **not published** — nothing on the remote; ao **rebased** | **push nothing.** Say so, and name [`hatsu:aka`](../aka/SKILL.md) as the human call that first publishes a branch |

**Those two rows are one decision seen twice, and that is the structural reason murasaki can never
need a force-push.** Ao merges exactly when something is published and rebases exactly when nothing
is, so the only tree murasaki ever pushes is one that already contains `origin/<branch>` as an
ancestor. A rejected fast-forward here is therefore **a finding to report, never a flag to add**:
something moved the remote branch under this run, and the maintainer needs to know before anything
overwrites it.

**Never `--force`, never `--force-with-lease`, never `+refs/`, never `-u`.** `-u` sets an upstream,
which is a first publish, and a first publish is aka's.

**Never squashes.** Not the turn commits, not "just the ones since the last push", not to tidy the
branch before the PR reads it. The commits below `origin/<branch>` are somebody else's history the
moment they are fetched, and rewriting them is the force-push this skill exists to make
unnecessary. **Squashing is [`hatsu:aka`](../aka/SKILL.md) § 4's, once, before the first publish.**

**Never pushes `branch.base`.** The `PreToolUse` guard in `hooks/hooks.json` refuses a `git push` on
the trunk at the harness level; this skill refuses it at the rule level.

> **RETIRED at nen `0.5`: step 1's merge half runs through the verb, with the push held back.**
> `nen pr cascade-main --repo <path> --trunk <base> --no-push` fetches and merges and then stops —
> verified live at `v0.5.0`, exit `0`, the log reading `fetched origin/main` / `merged origin/main
> cleanly` / `not pushed (--no-push)` (`docs/ab/murasaki.md` § *Retired at nen 0.5*). That is exactly
> the shape murasaki needs: step 2 runs **between** the merge and the push, and nothing publishes a
> tree nothing proved. [`hatsu:ao`](../ao/SKILL.md) § 3 owns the invocation; murasaki calls ao.
>
> **Step 3 is still `git push`, and there is still no push verb.** The cascade pushes only what it
> merged itself, so the ordinary fast-forward publish of an already-published branch stays git's, by
> hand, named here.

## 7. What murasaki never does

**No pull request, no label, no merge, no comment, no tag, no deploy.** Composing three skills does
not widen what any of them may do, and murasaki adds one operation of its own — an ordinary
fast-forward push of a branch that is already published. That is the whole of its blast radius.

**It never proposes [`hatsu:aka`](../aka/SKILL.md) or [`hatsu:mukai`](../mukai/SKILL.md)** as a next
step it is waiting on. Both are human calls, and a composite that ends by asking for one has
converted a human call into a nudge — the inversion [`hatsu:ren`](../ren/SKILL.md) § 4 and aka § 1
both refuse.

## 8. Report, and stop

One line: the base and its resolved SHA, rebase-or-merge and why, the conflicts by kind and how the
mechanical ones were resolved, the `iteration.checks` that ran green, the tests' verdict in
tsukuyomi's own words, and either the pushed SHA or **`not published — nothing pushed`**.

Invoked inside [`hatsu:mukai`](../mukai/SKILL.md) or [`hatsu:en`](../en/SKILL.md), that line is what
the caller continues from; invoked alone, it is the end of the run.

## Residue

1. **The push itself** — `git push origin HEAD` (§ 6). **Genuinely still residue at the pinned
   `0.5.0`**: `nen pr cascade-main` pushes only as the tail of a merge it performed itself and is not
   a push verb (verified live,
   `docs/ab/murasaki.md` § 2.2; the same reading `docs/ab/aka.md` § 2.4 records).
2. **RETIRED at nen `0.5`: `nen pr cascade-main --no-push`** (§ 6, verified live, exit `0`). Step 1's
   merge half runs through the verb inside ao; **its rebase half still has no verb at any flag**, and
   is ao's named `git rebase origin/<base>`.
3. **The published/unpublished test** — ao § 3's, re-used here rather than re-run: `git fetch origin
   <base> <branch>` (a missing remote branch tolerated) then `git rev-parse --verify --quiet
   refs/remotes/origin/<branch>`, or `git ls-remote --heads origin refs/heads/<branch>` asked of the
   remote directly. `nen wc classify --json` reports the branch, its dirt and its distance from the
   base, and nothing about the remote (verified live, `docs/ab/murasaki.md` § 2.3).
4. **RETIRED at nen `0.5`: `nen shu test-report`** (tsukuyomi § 6). The suite's verdict is the
   parsed `{tests[], passed, failed, skipped}` document, and the counts are read off it rather than
   restated from memory.
5. **RETIRED at nen `0.5`: `nen/workflow.json` is validated.** `nen schema check --repo <path>` carries
   an `ok  nen/workflow.json` row at the pinned `v0.5.0`. § 2's keys are still read here; reading a file
   is not residue.

Each is run in the open and reported as by-hand, per the Nen-first rule's second half
(`claude/agents/kurapika.md`): a missing verb is a finding, not a gap to route around silently.

## Authority

- **Permitted:** everything [`hatsu:ao`](../ao/SKILL.md),
  [`hatsu:rasengan`](../rasengan/SKILL.md) and [`hatsu:tsukuyomi`](../tsukuyomi/SKILL.md) are each
  permitted, under their own authority, one at a time, in § 3's order — plus **one** operation of
  murasaki's own: a plain, non-force push of a **non-base** branch that is **already on the remote**.
- **Not permitted:** a first publish; any squash or rewrite of any commit; any force-push; opening,
  editing or commenting on a pull request; any label, merge, tag or deploy; `--no-verify`; pushing
  `branch.base`.
- **Grants no delegation of its own.** Composing a skill does not widen what that skill may do, and
  a run-scoped delegation granted inside a step expires with that step.

## Hard limits

- **Never pushes a branch that is not already on the remote** (§ 6). A first publish is
  [`hatsu:aka`](../aka/SKILL.md)'s, on the maintainer's own call, and reaching a first publish
  through murasaki would make a human call reachable by a composite.
- **Never squashes, and never rewrites any commit** (§ 6). Not the turn commits, not to tidy the
  branch, not because the PR would read better.
- **Never force-pushes** — a rejected fast-forward is reported, never flagged past (§ 6).
- **Never pushes before step 2 has run green on the merged tree** (§ 3).
- **Never pushes past a semantic conflict** — ao's G5 ends this run with nothing on the remote (§ 4).
- **Never opens a pull request** — that is [`hatsu:shibari`](../shibari/SKILL.md)'s step inside
  [`hatsu:mukai`](../mukai/SKILL.md).
- **Never proposes a human call as its next step** (§ 7).
- **Never restates another skill's protocol.** If murasaki and a composed skill disagree, the
  composed skill is right and this file is the bug.
- **Never presents by-hand git as a verb's output** — every step in § Residue is named where it runs.
