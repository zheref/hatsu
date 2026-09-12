# A/B evidence — `aka` (new skill, wave 2)

`claude/skills/aka/SKILL.md`: the human-called push — lint, squash the unpushed commits, `hatsu:ao`
to put the base underneath, then `prepublication-verification` runs full regression and captures
instrumented results on the final tree before push.

**Phase ruling, 2026-09-12.** The load-bearing order is lint → squash → ao → reuse lint only for a
no-op catch-up, otherwise lint the caught-up tree → full regression/instrumented capture → push. The
named verification phase is reusable by composites without squash or first-publish authority. Any
later tree change invalidates it.
The observed handoff fields are saved transiently at `.nen/regression/<lane>.json` under
`hatsu.regression-capture/v0.1`; the skill identifies this as Hatsu residue rather than Nen proof.

**A new skill, so there is no "old mechanics" column.** What this record establishes is that
**two of aka's four safety properties have no enforcement in `nen` at `v0.3.0`** — the squash verb
does not exist, and the trailer guard does not refuse — so both are the skill's own rules plus the
repository's `commit-msg` hook until the P2 verbs land. That is the honest state, verified rather
than assumed.

> **Dated note, 2026-09-10 — the key changed after this record was made; the record did not.** Every
> transcript below is verbatim and stays that way. The maintainer's ruling of 2026-09-10
> ([`docs/ROSTER.md`](../ROSTER.md) § *Rulings of 2026-09-10*, *Two provenance trailers*) split
> provenance in two: a **local** Hatsu session writes **`Hatsu-Agent: <persona>`**, and
> `Akatsuki-Agent:` is the **autonomous CI plane's** key, which nothing on this plane writes. So read
> every `Akatsuki-Agent=…` below as *what was written on the day*, not as what to write now. What the
> runs establish about the verbs is unaffected: both keys sit on
> `commits.allowedAttributionTrailers`, so the accept/refuse behaviour is identical either way.

Run: 2026-09-09 (local clock). `nen 0.3.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64).
`nen shu test --dry-run` ran against a **constructed throwaway fixture** at `<worktree>/.nen-fixture`
carrying a hand-written `nen/contract.json` `project` block, created for this run and deleted before
the branch was committed; `nen commit format` and `nen wc` are pure. **No verb was run against any
primary checkout in a way that could write to it, and nothing was pushed to any real remote.**

Nothing below is redacted; both repositories are public.

---

## 1. The skill

| Step | Owned by | State at `v0.3.0` |
|---|---|---|
| The invocation | — (no arguments, so no grammar) | **n/a** (§ 4.3) |
| Required tests | `nen shu test` — `hatsu:tsukuyomi`'s engine | **verb** (§ 2.1) |
| A red run is G5 | `nen stop --who --gate G5` | **verb** (cited — `docs/ab/jutaisho.md` § 2.2) |
| Refuse a dirty tree before squashing | `nen wc classify --json` | **verb** (cited — `docs/ab/ao.md` § 2.2) |
| Published or not | — | **no verb** → residue (§ 3.3) |
| Squash the unpushed commits | `nen wc squash --onto --message-file` | **absent** → residue (§ 2.3, § 3.1) |
| Shape the one message | `nen commit format` | **verb** (§ 2.2) |
| Refuse a forbidden trailer | `nen commit format` (P2, `--repo`-aware) | **does not refuse** → residue (§ 2.2, § 3.2) |
| Catch up on the base | `hatsu:ao`'s engine | **composed** (`docs/ab/ao.md`) |
| Push | — | **no verb** → residue (§ 2.4, § 3.4) |

**Ten steps; three are verbs, one is a composed skill, four are residue, and two of the four
residue entries are safety properties rather than conveniences.** § 4.1 and § 4.2 are the findings
that follow from that.

---

## 2. Verbs exercised live

### 2.1 — `nen shu test --dry-run`: the tests step's pre-flight

Against the fixture's declaration (`project.verbs.app.test = {exe: "echo", argv: ["fixture-test"],
artifacts: ["reports/junit.xml"]}`):

```
$ nen shu test --repo <fixture> --dry-run
lane:          app  (nextjs)
verb:          test
host:          darwin -- supported (the declaration constrains no platform)
preconditions: (none declared)
would run:     echo fixture-test
cwd:           <fixture>
env:           (none added)
artifacts:     reports/junit.xml (absent)
log:           dry run -- nothing was executed, so there is no output to capture and no tool exit
               code to report.
exit=0
```

`--json` returns `{"contract": "nen.shu.test/v0.1", lane, stack, verb, target, steps[], cwd, env[],
host{platform,supported,declared}, preconditions[], exitCode, durationMs, artifacts[], log{mode:
"dry-run", captured: false, …}}` at exit `0` — the full document is transcribed in
`docs/ab/rikugan.md` § 2.3 and is not repeated here.

**What this pins down for aka:** the dry run prints *the argv that would be spawned, from the same
rendering* — so "the tests that ran" is a quotable fact, and the exit-code table
(`claude/agents/kurapika.md` § *The `shu` verbs*) is what decides whether the run continues. Exit `1`
is the ordinary red run and the G5 stop; exit `4` is a **seat** whose reason is quoted rather than
worked around.

### 2.2 — `nen commit format`: the shape it checks, and the trailer it does not

**The shapes aka uses:**

```
$ nen commit format --type feat --scope ren --subject "carry the turn loop through one request" \
    --trailer "Akatsuki-Agent=kurapika"
feat(ren): carry the turn loop through one request

Akatsuki-Agent: kurapika
exit=0

$ nen commit format --type feat --scope session --subject "add the resume path" \
    --body "Three turns of ren, squashed to one commit before the push." \
    --trailer "Akatsuki-Agent=kurapika"
feat(session): add the resume path

Three turns of ren, squashed to one commit before the push.

Akatsuki-Agent: kurapika
exit=0
```

**The finding — a forbidden trailer renders, at exit `0`:**

```
$ nen commit format --type feat --subject "prove the trailer guard" \
    --trailer "Co-Authored-By=Claude <noreply@anthropic.com>"
feat: prove the trailer guard

Co-Authored-By: Claude <noreply@anthropic.com>
exit=0
```

**And `--repo` is accepted but changes nothing:**

```
$ nen commit format --repo /tmp --type feat --subject "probe the repo flag"
feat: probe the repo flag
exit=0
```

The flag parses; there is no `nen/workflow.json` at `/tmp` and nothing is read from one anywhere —
the `--repo`-aware trailer refusal is P2 (brief § 4). The **shape** checks are real and were
re-confirmed at this pin: a bad type, an empty subject, a header over 72 characters and a
trailing-punctuation subject each refuse at exit `2` with a named reason (transcribed in full at
`docs/ab/tensho.md` § 2.3 — cited, not re-run, since the verb and the pin are unchanged).

### 2.3 — `nen wc squash` does not exist

```
$ nen wc squash --onto main --message-file /tmp/x
nen wc: unknown option '--onto'. Known options here: --base <value>, --help, --json, --repo <value>.
Run 'nen wc --help'.
exit=2
```

```
$ nen wc --help
nen wc classify -- where the current working copy sits, tensho's own table.

usage:
  nen wc classify --repo <path> [--base main]
  ...
```

**One verb in the family, `classify`.** The refusal lands on the *option* rather than the
subcommand, which is worth reading carefully: `--onto` and `--message-file` are unknown to `nen wc`
as a whole, so `squash` is not a subcommand that exists with different flags — it is not there at
all. `wc squash --onto <ref> --message-file <f>`, with its three refusals (dirty tree, a commit
already upstream, a non-ancestor point), is P2 (brief § 4).

### 2.4 — What `nen pr cascade-main` pushes, and why it is not a push verb

Cited from `docs/ab/ao.md` § 2.3, run live in the same session against the same fixture: a clean
`nen pr cascade-main --repo <fixture> --trunk main --json` returns
`{"conflicted": false, "pushed": true, "log": ["fetched origin/main", "merged origin/main cleanly",
"pushed"]}` at exit `0`, and the branch's remote ref moved.

**It pushes, but it is not a push verb**: it pushes only as the tail of a merge it performed itself,
onto the branch it merged into, and there is no invocation of it that pushes without merging (its
own help: *"Merges (never rebases) the trunk into the current branch and pushes on a clean
merge"*). So aka's § 6 is `git push [-u] origin HEAD`, named as residue.

---

## 3. Residue

1. **`nen wc squash --onto <ref> --message-file <f>`** (§ 2.3, exit `2`). Replaced by
   `git reset --soft <computed squash point>` plus one commit whose message came from
   `nen commit format`. The verb's own three refusals — dirty tree, a commit already on the
   upstream, a non-ancestor point — are enforced by the skill first, in that order, plus a fourth
   for the forbidden trailer.
2. **The forbidden-trailer refusal in `nen commit format`** (§ 2.2, a `Co-Authored-By` trailer
   renders at exit `0`). Enforced by the skill's rule and the repository's `commit-msg` hook — the
   one `nen scaffold init` writes from `commits.allowedAttributionTrailers` — until the P2
   `--repo`-aware guard lands. A repository with neither is told so plainly.
3. **The published test** — `git rev-parse --verify --quiet refs/remotes/origin/<branch>`, which
   decides the squash range and therefore whether a plain push can possibly suffice.
   `nen wc classify --json` reports nothing about the remote (`docs/ab/ao.md` § 2.2).
4. **The push** — `git push [-u] origin HEAD` (§ 2.4).
5. **`nen/workflow.json` read as data** — no schema row at `v0.3.0` (`docs/ab/rikugan.md` § 2.4).
   `tests.required` defaults to `["test"]`, `branch.base` to `main`,
   `commits.allowedAttributionTrailers` to `["Akatsuki-Agent"]` and `commits.forbiddenTrailers` to
   `["Co-Authored-By", "Claude-Session", "Signed-off-by"]`, each stated when it applied.

---

## 4. Findings against the binary

*File nothing from this document; this is the list.*

### 4.1 — The trailer policy has no enforcement anywhere in nen at this pin

§ 2.2 is the whole finding: `nen commit format --trailer "Co-Authored-By=…"` renders the trailer and
exits `0`, and `--repo` is accepted without reading anything. So at `v0.3.0` **the only mechanical
enforcement of `commits.forbiddenTrailers` is a git `commit-msg` hook** that `nen scaffold init`
writes *if* three trailer flags were passed when the repository was stood up
(`claude/agents/kurapika.md` § *The `shu` verbs`*: *"the commit-msg hook is written **only** when all
three trailer flags are given"*). A repository scaffolded without them, or stood up by hand, has
**no** enforcement at all — only the skill's rule and the agent's care.

That is a fail-open configuration for a policy the workflow states as binding, and it is worth
saying plainly rather than trusting to diligence. The P2 item (brief § 4: *"`commit format` refuses
trailers not allowed by workflow.json (`--repo` to find it)"*) closes it; until then this is the one
place in aka where a mistake would be silent.

### 4.2 — `nen wc squash`'s absence pushes a force-push-shaped decision into prose

§ 2.3: the verb is not there. The decision it would own — *which commits are still yours to
rewrite* — is exactly the decision that, got wrong, produces a force-push. Aka's § 4 computes it in
prose (`origin/<branch>` when published, `git merge-base origin/<base> HEAD` when not) and refuses
rather than forcing when a plain push is rejected. **That is the right conservative answer, but it
is an agent following a rule where a verb should be refusing**, and the difference matters:
`wc squash`'s stated refusal *"refuse if any of the commits are on the upstream"* is a guarantee,
where the same sentence in a SKILL.md is an instruction.

Ranked with § 4.1 and `docs/ab/ao.md` § 4.2, the P1/P2 order this wave's skills would choose is:
**`cascade-main --no-push` first** (it unblocks three residue entries in `ao`), **`commit format`'s
trailer refusal second** (it is the fail-open one), **`wc squash` third**.

### 4.3 — Not a finding: aka has no grammar, and that is the correct shape

`nen parse <skill> --grammar <template> --line <text>` exists to parse a grammar. `hatsu:aka` takes
no arguments, so there is nothing to parse, and adding an optional clause purely so that a parse
could be echoed would be ceremony — the same judgement `claude/skills/tensho/SKILL.md` § 1 makes
about its own default, from the other direction. Recorded so that "no `nen parse` call" is read as a
decision rather than an omission. The three skills in this wave that *do* have optional clauses
(`rikugan as`, `jutaisho at`, `ao from`) all parse by verb, each verified live.

### 4.4 — Not a finding: `nen shu test`'s dry run is exactly the right pre-flight, and its exit codes carry the policy

§ 2.1: the dry run prints the argv, cwd, env names and declared artifacts and spawns nothing, and
the family's exit codes already distinguish *the tool failed* (`1`), *the declaration is wrong*
(`2`), *this host cannot* (`3`), *this lane declares a seat* (`4`) and *the program is not
installed* (`5`). Aka needs no additional verb for its first step: the policy — which of those five
is a G5 and which is a fix — is the skill's, and the facts it decides on are all present. Noted as
the counter-example to §§ 4.1–4.2: where nen owns a step, it owns it completely.

### 4.5 — Against `git`, not the binary: `ls-remote` answers *published*, it does not deliver the object

**Added 2026-09-10, from the review round on `zheref/hatsu#31`
([thread](https://github.com/zheref/hatsu/pull/31#discussion_r3976460551)) — not part of the
2026-09-09 run above, and marked so rather than folded into it.** § 4 of the skill made the SHA that
`git ls-remote` prints the squash point *directly*, on the strength of it never touching a tracking
ref. That property is real; the step it was carrying is not. `ls-remote` reads the remote's ref
advertisement and **transfers no objects**, so a checkout that has never fetched `<branch>` cannot
reset onto it. Reproduced on 2026-09-10 against a `--single-branch` clone taken over `file://` (a
local-path clone shares its object store through alternates and hides the failure, which is why the
transport matters):

```
$ git ls-remote --heads origin refs/heads/feature
53e6991660f0ade488ababc8fcda1669a263b48e	refs/heads/feature

$ git cat-file -e 53e6991660f0ade488ababc8fcda1669a263b48e^{commit}
exit=1                     # the object is not local

$ git reset --soft 53e6991660f0ade488ababc8fcda1669a263b48e
fatal: Could not parse object '53e6991660f0ade488ababc8fcda1669a263b48e'.
exit=128
```

**This is `git` behaving as documented, so nothing is filed against `nen`** — but it lands on `nen wc
squash` when that verb arrives (brief § 4, P2): a squash verb handed a remote SHA owes the same two
checks the skill now runs by hand, `cat-file -e` (fetch when absent) and `merge-base --is-ancestor`.
Recorded here so the P2 verb inherits the requirement rather than rediscovering it. The `ao` and
`murasaki` uses of `ls-remote` are unaffected — both ask it only *is this branch published*, and
neither uses the SHA for anything.


---

## Retired at nen 0.5 — 2026-09-10

Run against the binary built from `zheref/nen` `v0.5.0` (`204b9ee6`), put on `PATH` as `nen`
(`nen --version` → `0.5.0`). This section records what stopped being residue when
`nen/contract.json`'s `pinned_ref` moved from `v0.4.0` to `v0.5.0`, with the exit code each verb
actually returned.

| Residue retired | Verb at the pin | Exit |
|---|---|---|
| `git reset --soft` + a hand-gated `commit format` | `nen wc squash --onto <ref> --message-file <f> --dry-run` | `2`, twice, each refusal the verb's own |
| the forbidden-trailer refusal | `nen commit format --repo . --trailer "Co-Authored-By=someone"` | `2` |

```
$ nen wc squash --repo <dirty fixture> --onto main --message-file <f> --dry-run
nen wc: the working tree is dirty -- 5 uncommitted or untracked path(s): nen/contract.json,
nen/workflow.json, .nen/last-stop.json, .nen/proof/app.json, Reports/lint.txt. Commit or stash them
first; a squash never folds work that was never committed.
exit=2

$ nen wc squash --repo . --onto origin/main --message-file <f> --dry-run
nen wc: commit 3c80607700844193e74668bb3a815c9bdde6a116 ('chore(nen): repin the contract to nen 0.4
(v0.4.0)') is already on the upstream 'origin/opus/kurapika/repin-nen-0.4' -- already published;
squashing would rewrite pushed history. Rebase or cut a fresh branch instead of folding a commit that is
already there.
exit=2
```

**Both refusals are the verb enforcing what § 4 used to enforce by hand**, and both run before a single
write. `nen wc` carried exactly one verb, `classify`, through `v0.4.0` (§ 2.2's reading).

```
$ nen commit format --repo . --type chore --subject "probe" --trailer "Co-Authored-By=someone"
nen: trailer key 'Co-Authored-By' is an attribution trailer this repository refuses.
'…/nen/workflow.json' admits 'Akatsuki-Agent' under commits.allowedAttributionTrailers, and
'Co-Authored-By' is not one of them. Drop the trailer, or add its key to that list
exit=2

$ nen commit format --repo . --type chore --subject "probe" --trailer "Akatsuki-Agent=kurapika"
chore: probe

Akatsuki-Agent: kurapika
exit=0
```

At § 2.2 the same forbidden trailer rendered happily at exit `0`. **`--repo` is what turns the refusal
on** — the policy is opened only when the invocation carries a `--trailer`.

**Still residue:** the push itself. `nen pr cascade-main` pushes only what it merged, and there is no
push verb at this pin either.
