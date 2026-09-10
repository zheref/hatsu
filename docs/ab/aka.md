# A/B evidence — `aka` (new skill, wave 2)

`claude/skills/aka/SKILL.md`: the human-called push — tests, squash the unpushed commits into one,
`hatsu:ao` to put the base underneath, then push. No pull request, no AI attribution trailer, G5 on
a red required test, and never a force-push.

**A new skill, so there is no "old mechanics" column.** What this record establishes is that
**two of aka's four safety properties have no enforcement in `nen` at `v0.3.0`** — the squash verb
does not exist, and the trailer guard does not refuse — so both are the skill's own rules plus the
repository's `commit-msg` hook until the P2 verbs land. That is the honest state, verified rather
than assumed.

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
