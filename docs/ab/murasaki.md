# A/B evidence — `murasaki` (new skill, wave 3)

`claude/skills/murasaki/SKILL.md`: the maintenance composite — [`ao`](../../claude/skills/ao/SKILL.md)
to put the base underneath, [`rasengan`](../../claude/skills/rasengan/SKILL.md) +
[`tsukuyomi`](../../claude/skills/tsukuyomi/SKILL.md) to prove the merged tree, then a plain push **only
if the branch was already published**. Never squashes, never force-pushes, never first-publishes, never
opens a PR.

> **Dated 2026-09-10 — step 2's owner changed after this record was written.** The header line above
> credits `rasengan` with proving the merged tree. The maintainer's ruling of 2026-09-10
> ([`../ROSTER.md`](../ROSTER.md)) makes `rasengan` the **authoring** phase, so murasaki runs the
> declared `iteration.checks` over the merged tree as its own step (`SKILL.md` § 5) and hands a red
> one to `rasengan` to be authored. The verb exercised is the same `nen shu build [--lane]` recorded
> below, at the same exit codes; only the phase that calls it changed.

**A new skill, so there is no "old mechanics" column.** What this record establishes is that the one
`nen` verb that would own murasaki's first and third steps — `nen pr cascade-main` — **fuses them**, and
that the flag which would separate them does not exist at the pinned `0.3.0`. Step 2 has to run *between*
the merge and the push, so a verb that pushes on a clean merge cannot be the engine here; the merge is
`ao`'s named residue and the push is murasaki's own.

Run: 2026-09-10 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
Every `shu`/`wc` transcript below ran against a **constructed throwaway fixture** at
`<worktree>/.nen-fixture` — a hand-written `nen/contract.json` `project` block, a local `git init`, two
commits on a feature branch, **no `origin` remote at all** — created for this run and deleted before the
branch was committed. `nen parse` and `nen pr … --help` are pure. **No mutating verb was run against any
primary checkout, and nothing was pushed to any real remote.**

Nothing below is redacted; both repositories are public.

---

## 1. The skill

| Step | Owned by | State at `v0.3.0` |
|---|---|---|
| The invocation | `nen parse murasaki --grammar "from [<base>]"` | **verb** (§ 2.1) |
| Read the checkout | `nen wc classify --json` | **verb** (§ 2.3) |
| Step 1 — pull the base | [`hatsu:ao`](../../claude/skills/ao/SKILL.md)'s engine | **composed** (`docs/ab/ao.md`) |
| — its merge half | `nen pr cascade-main --no-push` | **absent** → residue (§ 2.2) |
| — its rebase half | — (the cascade *"never rebases"*) | **no verb at any flag** (§ 2.2) |
| Step 2 — build | `nen shu build [--lane]` | **verb** (cited — `docs/ab/rasengan.md`) |
| Step 2 — tests | `nen shu test [--lane]` | **verb** (cited — `docs/ab/aka.md` § 2.1) |
| — parsed results | `nen shu test-report` | **absent** → residue (cited — `docs/ab/tsukuyomi.md` § 2.4) |
| Published or not | — | **no verb** → residue (§ 2.3) |
| Step 3 — push | — | **no verb** → residue (§ 2.2) |

**Ten rows; four are verbs, one is a composed skill, and four are residue — three of which murasaki
inherits from `ao` and `tsukuyomi` rather than adding.** Murasaki's own single addition to the local
plane's blast radius is one line of git, and § 4.2 is why it cannot be a verb yet.

---

## 2. Verbs exercised live

### 2.1 — `nen parse murasaki`: the grammar, and what a bare invocation does

```
$ nen parse murasaki --grammar "from [<base>]" --line "from release/1.4"
base: release/1.4
exit=0
```

```
$ nen parse murasaki --grammar "from [<base>]" --line ""
nen parse: the line must open with the literal 'from' -- it is what introduces <base>.

Corrected line:
  murasaki from
exit=2
```

**The empty line is refused, and that is the correct behaviour rather than a defect** — the grammar
declares a literal that introduces the slot, so a line that opens with something else (or with nothing)
does not parse. The consequence for the skill is stated in its § 1: **the parse runs only when the
maintainer typed a clause.** `hatsu:murasaki` bare has nothing to parse, and the base then comes from
`nen/workflow.json → branch.base` with `main` as the stated default. This is the same reading
`docs/ab/aka.md` § 4.3 records from the other direction — a skill with no arguments makes no parse call
at all.

The bracketed-slot template itself is accepted here because the slot is **anchored behind a literal**,
which is the shape `docs/ab/rikugan.md` § 2.1 established the engine requires.

### 2.2 — `nen pr cascade-main`: it merges **and pushes**, and `--no-push` is not there

The verb's own specification, read at this pin:

```
$ nen pr cascade-main --help
exit=0
...
cascade-main:
  Merges (never rebases) the trunk into the current branch and pushes on a
  clean merge. Reports a conflict rather than resolving it.
```

```
$ nen pr cascade-main --repo <fixture> --no-push
nen pr: unknown option '--no-push'. Known options here: --add-reviewers <value>, --approvers <value>,
--base <value>, --body-from <value>, --delivery-pr, --exclude-run <value>, --explain, --gates <value>,
--gh-repo <value>, --help, --idle-minutes <value>, --json, --last-activity <value>,
--min-verified-wakes <value>, --now <value>, --policy <value>, --pr <value>, --ready, --repo <value>,
--requirements-from <value>, --reviewers <value>, --round-policy <value>, --target <value>,
--token-env <value>, --trunk <value>, --wakes-from <value>.
Run 'nen pr --help'.
exit=2
```

Two facts, and murasaki turns on the first:

1. **`--no-push` does not exist** (exit `2`, the whole option surface of the `pr` family listed). This
   re-confirms `docs/ab/ao.md` § 2.3 at the same pin, from a different worktree.
2. **The verb's own sentence is the disqualifier, not the missing flag.** *"Merges … and pushes on a
   clean merge"* describes a single operation whose two halves murasaki must have something **between**:
   the declared build and the declared suite run on the merged tree, and only their green result
   authorises the push. A cascade that pushes on a clean merge has already published a tree that nothing
   proved. So even with `--no-push`, the cascade would be `ao`'s step-1 engine and never murasaki's
   whole run.

### 2.3 — `nen wc classify --json` says nothing about the remote

Against the fixture, on a feature branch with two commits and a clean tree:

```
$ nen wc classify --repo <fixture> --base main --json
{
  "state": {
    "branch": "opus/kurapika/fixture-effort",
    "isTrunk": false,
    "dirty": false,
    "aheadOfBase": 1,
    "existingCommitSubjects": [ "feat(fixture): touch two files" ],
    "uncommittedPaths": []
  },
  "result": {
    "case": "on-branch-clean",
    "evidence": [ "on 'opus/kurapika/fixture-effort' with nothing uncommitted -- open or report the existing PR" ]
  }
}
exit=0
```

**The fixture has no `origin` remote at all, and the document is identical to what a published branch
would produce.** Every key here is about the local checkout: the branch, its dirt, its distance from the
base, its subjects, its uncommitted paths. Nothing in it answers *"is this branch on the remote?"*, which
is the single question § 6 of the skill turns on — and nothing in `nen` refreshes `origin/<branch>` for
that decision either. That is why the published test is residue in `ao`, in `aka` and here, and why all
three run the identical two-command form.

The `evidence` line's advice (*"open or report the existing PR"*) is `tensho`'s framing of the same case;
murasaki reads only `state.dirty` and `state.branch` from this document and takes the rest from git.

### 2.4 — The two proof verbs, cited rather than re-run

`nen shu build --dry-run` and `nen shu test --dry-run` were exercised live at this pin against a
constructed declaration in `docs/ab/rasengan.md` and `docs/ab/aka.md` § 2.1 — the argv, cwd, env names
and declared artifacts printed, nothing spawned, exit `0`, `--json` carrying
`{contract, lane, stack, verb, steps[], …, exitCode}`. The verb and the pin are unchanged, so they are
cited, not repeated.

What *was* re-confirmed here, because murasaki's § 5 depends on it, is the shape of a **red** run and of
a **seat** — both transcribed in `docs/ab/kotoamatsukami.md` § 2.3 and § 2.2 on the sibling verb
`nen shu ui-test`: the runner's own code lands in `steps[0].exitCode` with nen's own top-level `exitCode`
at `1`, and a seat is exit `4` with the declaration's sentence quoted and **no `--json` document at all**.

---

## 3. Residue

1. **The push** — `git push origin HEAD` (§ 2.2). There is no push verb at `v0.3.0`; `nen pr
   cascade-main` pushes only as the tail of a merge it performed itself.
2. **`nen pr cascade-main --no-push`** — absent, exit `2` (§ 2.2). Step 1's merge half runs as `ao`'s
   named `git fetch` + `git merge --no-edit origin/<base>`.
3. **The rebase half of step 1** — no verb at any flag: the cascade *"merges (never rebases)"* by its own
   `--help` (§ 2.2).
4. **The published/unpublished test** — `git fetch origin <base> <branch>` (a missing remote branch
   tolerated) then `git rev-parse --verify --quiet refs/remotes/origin/<branch>`, or `git ls-remote
   --heads origin refs/heads/<branch>`. `nen wc classify --json` reports nothing about the remote
   (§ 2.3).
5. **`nen shu test-report`** — absent at this pin (`docs/ab/tsukuyomi.md` § 2.4). The suite's verdict is
   the runner's own summary, quoted.
6. **`nen/workflow.json` read as data** — no schema row at `v0.3.0` (`docs/ab/rikugan.md` § 2.4).
   `branch.base` defaults to `main`, `iteration.checks` to `["build"]`, `tests.required` to `["test"]`,
   each stated when it applied.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — `nen pr cascade-main --help` exits **`0`**, not `2` — a correction to a recorded claim

`claude/skills/ao/SKILL.md` § 3's closing note states that *"a subcommand-level `--help` on the `pr`
family exits `2` and prints the whole family's usage"*. **Half of that is right and half is not, at this
pin.** It does print the whole family's usage — there is no per-subcommand help page, and
`cascade-main`'s specification is the three lines under the `cascade-main:` heading of the family sheet.
But the exit code is **`0`**, verified live (§ 2.2, run with output redirected to a file so the code read
is `nen`'s and not a pipeline's).

The distinction is not cosmetic. `--help` at exit `2` would mean *"you asked wrongly, here is the usage"*
— the shape every refusal in this CLI takes. `--help` at exit `0` means *"here is the documentation you
asked for"*, which is what a caller scripting a capability probe needs it to be: exit `0` is not evidence
that a subcommand exists, and a probe that reads it as such would conclude `nen pr no-such-verb --help`
succeeded too. **The way to ask whether a flag exists is to pass it** (§ 2.2's exit `2`), never to read a
help page's exit code.

Worth a one-line correction to `ao`'s § 3 the next time that file is opened by whoever owns it. It is not
this wave's file to edit, and the claim it makes about *content* — that the family help is the spec —
stands.

### 4.2 — The cascade verb's fusion of merge-and-push is the real gap, and `--no-push` only half closes it

Brief § 4.7 promises `nen pr cascade-main --no-push`: *"merge and stop"*. That closes `ao`'s residue,
which is the right first target (`docs/ab/aka.md` § 4.2 ranks it first for the same reason). **It does
not give murasaki a verb**, and this is worth stating before the flag lands so that its arrival is not
mistaken for one.

Murasaki is `merge → prove → push`, and the proof is not optional decoration: it is the entire reason the
push is safe. A verb that owns the first and third steps but cannot host the second is a verb this skill
calls twice with its own work in between — which is exactly three named operations, two of which are
`ao`'s and one of which is a bare `git push`. **The shape nen would need to own this is not `--no-push`
but a push verb** — something like `nen wc publish --repo <path>`, refusing a first publish, refusing a
non-fast-forward, refusing a base branch, refusing `--force` by not having one. That verb does not exist
and is not on the P1/P2 list.

Ranked against `docs/ab/aka.md` § 4.2's ordering, this sits **after** `cascade-main --no-push` and the
`commit format` trailer refusal, and roughly level with `wc squash`: all three are places where a rule
written in a SKILL.md would be a guarantee if it were written in the binary. The consolation is that
murasaki's rule is the one that is **structurally self-enforcing** — see § 4.3.

### 4.3 — Not a finding: murasaki can never need a force-push, and that is a property rather than a promise

`ao` § 3 chooses **rebase when nothing is published** and **merge when something is**. Murasaki pushes
**only in the published case**. Composing those two facts: the only tree murasaki ever pushes is one
produced by merging `origin/<base>` into a branch that already contains `origin/<branch>` as an ancestor
— which is a fast-forward by construction.

So the hard limit *"never force-pushes"* is not a discipline murasaki has to maintain against temptation;
there is no reachable state in which a force-push would be the thing that works. A rejected fast-forward
means the remote branch moved under the run, and the honest answer is to stop and say so.

Recorded because the same sentence in `aka` § 6 **is** a discipline — aka squashes, so it has a range to
compute and a way to get it wrong (`docs/ab/aka.md` § 4.2) — and the two skills' identical wording hides
that they are load-bearing to very different degrees.

### 4.4 — Not a finding: `not applicable — no tests configured` survives the composite

`tsukuyomi` § 4 refuses to render an empty `tests.required` as green, and `aka` § 3 carries that phrase
through to its push report. Murasaki § 5 does the same, and the reason it must is worth naming: **it is
the composite where the phrase is most likely to be lost**, because murasaki pushes without a gate event
and a one-line report is under pressure to be short. Hatsu's own checkout is exactly this case
(`nen/workflow.json → tests.required` is `[]`), so any murasaki run in this repository exercises it.

Noted as a conformance point for whoever writes `mukai` and `en`: the phrase is carried, not
re-summarised, at every level of the composition.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| step 1's merge half, run as `git fetch` + `git merge` | `nen pr cascade-main --repo . --no-push` | `0` |
| `nen shu test-report` absent | see `docs/ab/tsukuyomi.md` § *Retired at nen 0.5* | `1`, the report absent and named |

```
$ nen pr cascade-main --repo . --no-push
fetched origin/main
merged origin/main cleanly
not pushed (--no-push)
exit=0
```

That is precisely the shape murasaki needs: the merge lands, **nothing is published**, and step 2's
build and tests run between the merge and the push. Through `v0.4.0` the flag did not exist and the verb
pushed on a clean merge, which is why step 1 and step 3 could not be run by the same call (§ 2.2).

**Still residue:** step 3's `git push origin HEAD`.
