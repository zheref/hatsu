---
name: kagutsuchi
description: Send a build to a declared NON-PRODUCTION destination — the internal channel, the testers' track, the preview environment — by running the repository's own `deploy` row through `nen shu deploy --target <name> --run`. Use ONLY when the maintainer invokes /kagutsuchi <target> or asks in their own words to upload this to a named destination. The plan is printed always and sending happens only on that call, naming that target; no composite ever calls it, no agent ever proposes it, and one call sends to one target once. Production and the stores are /mugetsu at G3, never this skill.
---
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->

**Shared policy location:** `docs/DISCOVERY.md`, `docs/WORKFLOW.md`,
`docs/LAUNCH-MIGRATION.md` and `docs/STANDALONE-ENTRY.md` belong to the resolved **Hatsu plugin
root**, not the consuming repository. On an installed surface, use the absolute root printed by
`hatsu-warmup` to read those files (re-resolve through that skill if unavailable). Relative links
below identify source locations; a missing consumer `docs/` copy is not a missing policy and must not
trigger a duplicate filing. Never copy or invent a second policy in the target repository.



# Kagutsuchi — the flame given a shape: one build, one named destination, on your word

**Nature: Emitter.** The moment a build leaves this machine it is a release act, whichever nature
authored the diff. [`/amaterasu`](../amaterasu/SKILL.md) starts an app *here* and is Transmuter
for that reason; this skill sends one *there*, and the difference is the whole reason they are two
skills.

> **Show me exactly what would be sent and where. Then, because I said this target by name, send it —
> once.**

Kagutsuchi is a **human call, per target**. It is not a phase of any loop, it is not offered as a next
step, and it never runs because something upstream finished successfully.

> **The name.** The maintainer has written it *kagutsushi*; the skill is **`kagutsuchi`** — Sasuke's
> Blaze Release: Kagutsuchi, the technique that shapes Amaterasu's black flames into something aimed.
> Said once, here, so the invocation and the roster agree; a misspelling in a message is still an
> invocation of this skill, and the reply spells it correctly rather than correcting the maintainer.

---

## 0. Standalone entry — this skill was ALWAYS standalone

**Kagutsuchi has no wired entry to add one to.** § 1 already says it: *no composite ever calls it, no
agent ever proposes it, and one call sends to one target once*. It is reached exactly one way — the
maintainer typing it, naming the target — so the contract in
[`docs/STANDALONE-ENTRY.md`](../../../docs/STANDALONE-ENTRY.md) applies to it in the narrowest possible
form, and **this section grants nothing**.

**What it adds is two clauses of the preamble, and nothing else.**

**P1 · Warm up.** [`/hatsu-warmup`](../hatsu-warmup/SKILL.md), unconditionally. The send is
`nen shu deploy --target <name> --run`; a phase reached directly has nobody to have satisfied `D10`.

**P2 · Orient before the plan, and put it IN the plan.** § 3 prints the plan always, before anything;
cold, the plan's first block states what is being sent from:

- the **branch**, and whether it is `branch.base`;
- **clean or dirty**, with every uncommitted path — an upload built from a dirty tree ships something
  that exists in no commit, and the destination has no way to tell;
- **ahead of / behind** the fetched `origin/<branch.base>`, and whether the head is **published**;
- the **tag or commit** the artifact will carry.

**That block is orientation, not a gate.** Kagutsuchi does not refuse a dirty tree — the maintainer
may have every reason — it **shows** it, so the call is made with the facts visible. Where the state
is one the maintainer plausibly did not intend, say so in one line and print the plan anyway.

**P4 · Nothing is ever asked.** § 1's rule stands verbatim: *asking again would be theatre — the human
already named the target*. A cold entry does not earn a confirmation prompt, and adding one would
convert a human call into a nudge.

**What does not change — all of it.** One call, one target, once. The plan printed always, the send
only on the call. § 5's refusal order, § 6's credentials asserted and never handled. **Production and
the stores remain [`/mugetsu`](../mugetsu/SKILL.md) at `G3`, never this skill**, and no path
through this section reaches one.

**Hand-back.** *Terminal for this target. Nothing follows a send in the wired run, because there is no
wired run — the next call, if any, is yours.*

---

## 1. Invocation — and who is allowed to say it

```
/kagutsuchi <target>
```

**`<target>` is required grammar, not a default.** It names a key of
`nen/contract.json → project.targets`. There is no bare form, no "the usual one", and no picker: nen's
own rule for `--target` is *"required and has no default, not even when exactly one target exists —
nen never chooses where a build goes"*, and the skill inherits it for the stronger reason that **the
maintainer typing the target's name is the authorization**. A run whose destination the maintainer
did not type has no authorization to inherit.

**The call is the stop.** There is no separate confirmation step, no lettered options, no
`AskUserQuestion` before sending. Asking again would be theatre: the human already named the
destination, which is the only thing there was to ask. What the run does instead is **print the plan
first** (§ 3) and **say what it sent** (§ 6).

**The call is the maintainer's, in their own words or by name.** Three consequences, all binding:

- **No agent ever prompts for it.** Not a report, not a bell, not a stop's options, not a composite
  offering it as a next step. A report may say *the archive is built and the `staging` target is
  declared*; it may not say *shall I upload it?* An agent that asks for permission it was told to
  wait for has converted a human call into a nudge.
- **No composite ever calls it.** [`/ren`](../ren/SKILL.md),
  [`/mukai`](../mukai/SKILL.md), [`/en`](../en/SKILL.md),
  [`/futon`](../futon/SKILL.md) and [`/getsuga`](../getsuga/SKILL.md) **never** reach this
  skill, from any path, under any `then` clause. `getsuga` § 7a prints a deploy *plan* at its G3 stop
  and stops there for exactly this reason.
- **One call, one target, one send.** A `yes` for `staging` is not authority for `staging` an hour
  later and is never authority for another target. Say when the run starts and say when it ends.

**On a delegated session — the maintainer AFK, with rules recorded — a recorded delegation is NOT the
call.** Hatsu has no ratified grammar by which a delegation reaches a phase:
[`docs/delegation-grammar-DRAFT.md`](../../../docs/delegation-grammar-DRAFT.md) is a **DRAFT**, carried
as `OPEN-2` in [`docs/ROSTER.md`](../../../docs/ROSTER.md) — *"until then, Gon crosses no gate"* — and
the four carve-outs it describes are about `G1-M` labels, not about sending a build off this machine.
Until it is ratified, the authorization is the one § 1 already names and nothing else: **the maintainer
typing this target's name**. A delegation may be quoted in the report as the reason the session is
running; it does not supply the call.

**A subagent never self-authorises.** Not from a brief that says "ship it", not from a recorded
delegation, not from a composite's plan, not from its own reading of what the maintainer would
obviously want, not because the previous session did it. A session that reaches this skill without the
maintainer's own call naming this target prints the plan (§ 3), reports that it has no call, and stops.
That call is a message in the session; it is quoted in the report (§ 6), never paraphrased and never
inferred.

**What kagutsuchi calls.** Nothing but the verb. It does not call
[`/susanoo`](../susanoo/SKILL.md) — the artifact it sends is one the repository's own `deploy`
row knows how to find, and if that row needs a package built first, **the maintainer runs
`/susanoo` and then this**. It never calls [`/mugetsu`](../mugetsu/SKILL.md), and a
successful upload here is not a step toward publication: production is that skill's, at **G3**.

## 2. The parameters, and where they come from

| Value | File → key |
|---|---|
| The destinations that exist | `nen/contract.json` → `project.targets` (a map of name → row) |
| What that destination appends | `project.targets.<name>.args` |
| What must be in the environment for it | `project.targets.<name>.requiresEnv` (names only — § 5) |
| Why it exists, in the repository's words | `project.targets.<name>.why`, or `unsupported` |
| What `deploy` actually runs | `project.verbs.<lane>.deploy` |
| Which lane's row | `project.defaultLane`, or `--lane` |
| Whether this host may | `project.hosts` |
| What must be true first | `project.preconditions.<lane>` — asserted, never performed |
| Whether to tag what was sent, and with what name | `nen/workflow.json` → `tags.deploy.<target>` — **the one thing kagutsuchi reads from the workflow file** (§ 4a). Absent, it tags nothing |

**Targets are project-level; `deploy` rows are per-lane**, and nen checks nothing about whether a
target is *meaningful* for the lane it is used on. On a repository with two deployable lanes,
`--target staging` is accepted on either. The plan printed in § 3 is what makes that visible — read
the `target:` line and the composed `would run:` before answering, every time.

**Non-production is the declaration's word, not this skill's — and it is PROSE, not a typed field.**
**Nothing in nen marks a target as production or not, at the pinned build either — genuinely still
residue:** `project.targets.<name>` carries `args`,
`requiresEnv`, `why` and `unsupported`, and none of them says which side of **G3** a destination is on
(§ *Residue* 1; `docs/ab/kagutsuchi.md` § 4.1 files it as the finding worth acting on). So the test is
a **read of a sentence**, and it is written to fail closed in all three directions:

- **A `why` that says or implies the destination reaches end users** — production, live, a store, a
  public channel — is [`/mugetsu`](../mugetsu/SKILL.md)'s at **G3**, and this skill refuses it by
  name whatever the maintainer typed.
- **A target with no `why` at all** is refused, because *"this destination is not production"* is a
  claim, and an unstated claim is not one anybody made.
- **A `why` that does not clearly say the destination is non-production** is refused the same way —
  *not* waved through for lacking the word *customers*. Ambiguity is the absent case wearing a
  sentence. The refusal quotes the `why` and asks the maintainer to say which side it is on; the
  durable fix is a word in the declaration, not a judgement call here.

**What this cannot catch is a `why` that is untrue**, and no reading of prose can. A declaration that
describes a production destination as an internal channel is a defect in the declaration — repaired
there, in the repository's own file, through its own review — and until a target row can *state* its
side of the gate, that residue is named rather than papered over.

## 3. The plan — printed always, before anything

```bash
nen shu deploy --repo <path> [--lane <lane>] --target <name> --dry-run
```

Verified live at nen `0.3.0` (`docs/ab/kagutsuchi.md` § 2.1): exit `0`, and the report carries the
`target:` line with what it appends and what it requires, the host row, every precondition asserted,
the fully composed `would run:` argv, the cwd and the env **names** — and **spawns nothing**.

**The bare form prints the same report.** `nen shu deploy --target <name>` with no `--run` is
read-only by construction — *"without `--run` it is read-only, because nen spawns nothing whatever
the declaration says — a property of nen rather than a claim about somebody else's argv"* — and it
adds one line on stderr, quoted here because it is the sentence to relay:

```
nothing was sent: 'deploy' acts only with --run. The plan above is fully resolved -- the destination
substituted into the argv, every precondition asserted -- and no process was started. Re-run the same
line with --run to send it.
```

Both forms are exit `0` and byte-identical above that line (verified, `docs/ab/kagutsuchi.md` § 2.2).
**Write `--dry-run` anyway.** It is the explicit spelling, it is the one form a reader of the
transcript cannot misread, and it is the form that survives being copied into a report where nobody
can see whether `--run` was on the next line.

**Paste the plan into the reply before sending, every time.** It is the only thing a maintainer who
was not watching the session can audit afterwards. What is sent must be what was shown.

## 4. The send — only on the call, only that target

```bash
nen shu deploy --repo <path> [--lane <lane>] --target <name> --run
```

Verified live against the fixture: exit `0`, the composed argv spawned exactly as the plan rendered
it, and nothing else (`docs/ab/kagutsuchi.md` § 2.6). `--run` is a second, independent flag: **there
is no single-flag path to acting**, and `--run` with `--dry-run` together is refused at exit `2` with
the reason — *"Nen will not pick one of two contradicting instructions on the one verb whose blast
radius is other people's users"* (verified, § 2.3).

Run it **once**. If it fails, read § 5, fix the named fact, and re-run — a re-run is the same
authorization only while it is the same target under the same call; anything else is a new call.

### 4a. The distribution tag — OPT-IN, and only after the send succeeded

**A repository may ask for what was just sent to be marked with a tag** (maintainer's ruling of
2026-09-18). It records *distribution*, which is a different fact from
[`/susanoo`](../susanoo/SKILL.md) § 5a's build tag recording *construction*: one says this
binary exists, the other says this binary went to that destination. A repository may declare either,
both, or — the default — **neither**, and one with no `tags.deploy` block behaves exactly as it did
before this section existed.

The declaration is `nen/workflow.json` → `tags.deploy`, per target:

```json
"tags": {
  "deploy": { "testflight": { "nameFrom": ".nen/export/testflight-tag", "push": true } }
}
```

**Keyed by target name, because a send to `staging` and a send to `beta` are not the same event** and
must not collide on one tag name. A target with no entry is not tagged, even where another target has
one.

The order is the same as susanoo's and is not negotiable:

1. **`--run` was passed and the deploy came back exit `0`.** A plan-only run tags nothing — nothing
   was sent, so there is nothing to record. A failed or partial send tags nothing either.
1a. **The working tree is clean at `--at`.** § 0's P2 already computes it and already warns that a
   dirty tree ships *"something that exists in no commit"*. A tag makes that mismatch permanent and
   public, so here the orientation becomes a condition: a dirty tree is a reported tag refusal, and
   the send still stands.
2. **Then** the tag is cut, through the verb and never around it:

```bash
# nameFrom is DATA, never a command fragment -- AND NEITHER IS ITS PATH.
# Read the value out of the JSON into a shell VARIABLE; never template it into
# shell source. Inside double quotes `$(...)` is still command substitution, so
# a declared path of `$(touch /tmp/pwned)` executes even though it "looks
# quoted" -- the name being validated later does not help, because the damage is
# done while the path is being built.
wf="$(git -C <path> rev-parse --show-toplevel)/nen/workflow.json"
nameFrom="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))['tags']['deploy']['<target>']['nameFrom'])' "$wf")"

root="$(git -C <path> rev-parse --show-toplevel)"
file="$root/$nameFrom"

# A SYMLINK IS REFUSED, not followed. Canonicalising the parent directory is not
# enough: an in-tree symlink AT the file can point anywhere, and `head` would
# read an external file and publish its first line as a tag.
[ -L "$file" ] && { echo "nameFrom is a symlink -- refused"; exit 2; }
[ -f "$file" ] || { echo "nameFrom is not a regular file -- refused"; exit 2; }
case "$(cd -P -- "$(dirname -- "$file")" && pwd -P)/" in
  "$root"/*) : ;;
  *) echo "nameFrom resolves outside the repository -- refused"; exit 2 ;;
esac

name="$(head -n1 -- "$file" | tr -d '\r')"
[ -n "$name" ] || { echo "nameFrom's first line is empty -- refused"; exit 2; }
git -C <path> check-ref-format "refs/tags/$name" \
  || { echo "the declared tag name is not a legal git ref -- refused"; exit 2; }
case "$name" in
  dist/*/*) : ;;
  *) echo "the declared tag name does not carry its species prefix -- refused"; exit 2 ;;
esac
nen tag cut --repo <path> --name "$name" --at <HEAD sha> --trunk <branch.base> [--push]
```

**The name is the repository's**, read from `nameFrom`'s first line — kagutsuchi composes none, and a
file that is missing, empty or holds a name `git check-ref-format` rejects is reported, never
replaced with one invented so that there is something to cut.

**The ancestor rule is about the COMMIT, not the branch.** `--at` is refused unless that commit is an
ancestor of `origin/<trunk>`: a feature branch sitting at the trunk's tip tags fine, one carrying its
own unpushed work does not. The honest sentence is *a commit not yet on `origin/<trunk>` cannot be
tagged* — and stating it as a branch rule is wrong in the reassuring direction, because it implies
the branch is itself the protection. **What protects the tag from attesting the wrong bytes is a
clean working tree at `--at`, which is a condition of the order above.** `--trunk` is passed from
`nen/workflow.json` → `branch.base` rather than defaulted, or a repository whose trunk is `master`
fails against a non-existent `origin/main`.

**The name must carry its species prefix** — `dist/<target>/` here, `build/` in
[`/susanoo`](../susanoo/SKILL.md) § 5a — and a first line that does not is a reported refusal.
A distribution tag sharing `getsuga`'s release namespace can take a version name permanently:
`mugetsu` proves a release tag by its name resolving on `origin`, and forbids deleting one to
recover.

**`--push` is not atomic** — the tag is created locally, then pushed — so a rejected push leaves the
name taken locally and absent on `origin`, which the verb then refuses forever. The single sanctioned
remedy: a local tag of that name, at that SHA, **verified absent from `origin`**, may be deleted and
re-cut, because nothing was ever published. That is the completion of an unfinished cut, not a
re-tag.

That refusal is reported with nen's own reason and is **never routed around** — and it never
retroactively unsends anything. **The send already happened**: § 7's block reports it as sent, and the
tag is reported as its own separate line with its own verdict. A run that uploaded cleanly and could
not tag says both, in that order, and neither reads as the other.

A cut tag here is **not** a promotion and **not** authorization for anything further:
[`/mugetsu`](../mugetsu/SKILL.md) is still **G3** and still needs its own recorded per-target go.

## 5. The refusals, in the order nen makes them

`claude/agents/kurapika.md` § *The `shu` verbs* is the authority for the codes; this is what
kagutsuchi does with each, and **the order matters** because it decides which refusal a mistyped line
gets.

| Exit | Fact | Reaction |
|---|---|---|
| `0` | the plan rendered (no `--run`), or the deploy ran (with it) | § 6 |
| `1` | the deploy tool ran and **failed** — its own code is in `steps[].exitCode` | relay its output, name the failing step. **Say what state the destination is in**, or that you do not know; a half-completed upload is the one failure that is not local |
| `2` | `--target` **absent** → *"there is no default … nen never chooses where a build goes"*, naming every declared target in byte order | ask the maintainer for the target. Never pick one |
| `2` | `--target` **names no declared destination** → the declared ones are listed | relay the list verbatim. Never send to a near-match, and never add the target to the declaration to make the line work |
| `2` | `--run` **with** `--dry-run` | a wiring error in the invocation; fix it and re-run |
| `2` | an **unsatisfied precondition** — the lane's own, or a variable the target's `requiresEnv` names | **the plan still prints, with the failing rows marked `FAIL`.** Relay it whole. Satisfy the fact yourself and say which one it was |
| `3` | **unsupported host** — this machine is not on `project.hosts` | **G5.** Name the hosts the declaration allows and stop. Never retry, never re-route |
| `4` | **a seat** — the lane declares no `deploy`, in its own words | quote it verbatim and stop. This repository does not deploy |
| `4` | **the target declares `unsupported`** — a destination with no command line at all | quote it verbatim and stop. The field shape behind it is real: *"the push to main IS the deploy, through the host's own integration"* |
| `5` | the declared program could not be started | `nen shu tools --repo <path>` and relay the remedy — and read [`/susanoo`](../susanoo/SKILL.md) § 7 first: a green `tools` is not evidence about a program the toolchain block never declared |

**A seat beats a mistyped target**, and that is deliberate: verified live, `--lane docs --target beta`
against a lane whose `deploy` is seated answers with the **seat** at exit `4`, not with "no such
target" (`docs/ab/kagutsuchi.md` § 2.5). A refusal that sends someone to write a `targets` block that
could not have helped is worse than one that costs a retype.

## 6. Credentials — asserted, never handled

A target names environment **variables**, and **nen asserts each is set without ever reading its
value**. No value appears in the text report, in `--json`, in a refusal or in a log line — verified
live: with the fixture's `FIXTURE_DEPLOY_TOKEN` unset, the row reads
`FAIL  env  FIXTURE_DEPLOY_TOKEN -- not set in this environment` and `--json` carries
`target.requiresEnv: ["FIXTURE_DEPLOY_TOKEN"]` and no value anywhere
(`docs/ab/kagutsuchi.md` § 2.4).

**This skill handles no credential either.** It does not read one, print one, export one into a
command line, write one into a file, or ask the maintainer to paste one into the conversation. An
unset variable is exit `2` with the variable's **name**, and the maintainer sets it in their own
environment. Where a credential is genuinely missing, that is where the run ends.

## 7. Report, and stop

One block, then stop: the target and its `why` quoted from the declaration, the lane, the plan's
composed argv (copied out of the `--dry-run` report, not re-typed), whether `--run` was passed, each
step's own exit code and nen's, and the maintainer's call **quoted verbatim** — the message that
named this target. There is no second source for that line; a delegation recorded elsewhere in the
session is reported as context beside it, never in its place (§ 1).

**One line for the tag** (§ 4a): *cut and pushed*, *cut locally*, *refused with nen's reason*, or
*not declared for this target* — and a declaration present but malformed is reported as read-and-
rejected, never as absent. nen validates nothing in that block, so "off" and "broken" are otherwise
the same silence.

**Re-render the turn report before stopping.** The last render was truthful when it was written and is
stale one step later. [`/rikugan`](../rikugan/SKILL.md) § 5 owns this: the `turn` variant,
re-rendered at the same address, with the upload written into **01 Accomplished**. There is no fourth
variant and this skill does not invent one.

**Then say nothing about what is available next.** Not `/mugetsu`, not another target, not "shall
I promote it". The next call is the maintainer's and they know they have it.

## Residue

1. **Nothing marks a target as production.** `project.targets.<name>` carries `args`,
   `requiresEnv`, `why` and `unsupported`, and no field says which side of **G3** a destination is on
   — verified against the declaration `nen shu deploy`'s own refusals enumerate
   (`docs/ab/kagutsuchi.md` § 4.1). § 2's production test is therefore this skill's, read out of the
   `why` prose by hand, and a target with no `why` is refused rather than assumed safe.
2. **Nothing checks that a target belongs to the lane it is used on.** Targets are project-level by
   design; `targets.<name>.lanes` is named in nen's own docs as the follow-up if the shape turns out
   to be common. Until then the guard is reading the plan (§ 3), by hand.
3. **What state a failed deploy left the destination in.** An exit `1` reports the tool's own code
   and nothing about the far end; nen never queries a destination. Saying *"I do not know what state
   the destination is in"* is the honest report, and it is by hand.
4. **A record of the go.** Nothing in nen records that a maintainer authorised a target.
   `nen stop --notified` writes `.nen/last-stop.json` for the bell and is not that record. The call
   is quoted verbatim in the report (§ 7), by hand — the same discipline
   [`/mugetsu`](../mugetsu/SKILL.md) § 3 states for the publication go.
5. **A per-run log file.** `A .nen/logs/ transcript is not in this release (zheref/nen#91)` — the
   report is the only record of what a send printed.

## Authority

- **Permitted, and only on the maintainer's own call naming the target:** print the plan for any
  declared target; run `nen shu deploy --target <that target> --run` **once**, for a destination the
  declaration's own `why` says is not production.
- **Also permitted, and only where the consuming repository declares `tags.deploy.<target>`:** cut
  that one tag through `nen tag cut` after a green `--run`, pushing it when the declaration says
  `push` (§ 4a).
- **Not permitted:** `--run` for a production or store destination (that is
  [`/mugetsu`](../mugetsu/SKILL.md), at **G3**); `nen shu release` in any form; a GitHub
  Release; a merge; a PR; a label; an edit to `project.targets` to make a line work. **Any push or
  tag other than the single declared one of § 4a** — that block is the whole of the permission, it is
  opt-in and per-target, and a repository that does not declare it gets exactly the old behaviour.
  Adding a `tags.deploy` block so that a tag will be cut is itself a **G4** declaration change, never
  something done here to make a run tag.
- **The call is one send wide and ends when this run ends.** It is not standing authority to send to
  this target again later, it is authority for no other target, and no delegation supplies it (§ 1).
- **Not a gate event of its own** — the maintainer's call already crossed the boundary. Exit `3`
  (unsupported host) is the one **G5** this skill raises.

## Hard limits

- **Never runs unasked, and never prompts for itself** — no agent, skill, report, bell or stop option
  proposes `/kagutsuchi` (§ 1).
- **Never runs from a composite.** `ren`, `mukai`, `en`, `futon` and `getsuga` never call it, under
  any `then` clause, on any path.
- **Never treats a delegation as the call.** Without the maintainer's own call naming this target —
  and a recorded delegation is not one — the plan is printed and the run stops (§ 1).
- **Never chooses a target**, never defaults one, never sends to a near-match of a mistyped one, and
  never adds a target to the declaration so that a line will run.
- **Never sends to production or a store.** That is `/mugetsu` at **G3**. The test is a read of
  the declaration's `why` prose, because nen has no field for it at this pin, so it is written to refuse
  three cases and not one: a `why` that reaches end users, a target with no `why`, and a `why` that
  does not clearly say the destination is non-production (§ 2). A `why` that is simply **untrue** is
  outside what any reading can catch, and is a defect in the declaration rather than a route through
  this skill (§ *Residue* 1).
- **Never sends what it did not show.** The plan is printed first, and what runs is that plan
  (§ 3, § 4).
- **Never reads, prints, exports or asks for a credential** — nen asserts a variable is set and never
  reads it, and neither does this skill (§ 6).
- **Never retries an exit `3`**, and never treats an exit `4` seat as a failure to route around.
- **Never sends twice on one call**, and never treats one target's go as another's.
- **Never claims a send succeeded** on the strength of a plan, or on an exit code it did not read.
- **Never tags a target the repository did not declare under `tags.deploy`**, never composes a tag
  name of its own, and never tags after a plan-only run or a failed send (§ 4a).
- **Never re-tags, and never routes around a tag refusal** — not by tagging another commit, not by
  pushing a branch to make `--at` an ancestor, not by dropping `--push` so a local tag stands in for
  one that resolves on `origin`.
- **Never lets a tag refusal read as a failed send, or a green send read as a cut tag.** The send
  already happened; two verdicts, reported separately, every time (§ 4a).
- **Never treats a cut tag as a promotion.** It records where a build went; it authorises nothing,
  and **G3** still needs its own recorded go.
