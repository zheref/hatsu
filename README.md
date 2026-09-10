# Hatsu

**A plugin for repository-centric agentic delivery, run from your own terminal on your own credentials —
authored for [Claude Code](#on-claude-code), and read on [Codex](#using-hatsu-on-codex) and
[Cursor](#using-hatsu-on-cursor) from generated mirrors of the same files.**

One lead persona — **Kurapika**, who names which of six declared work-modes he is holding before he acts —
plus a small roster of focused independents, and **thirty-eight skills** that take a backlog, a pull request or
a release from where it is to the human gate where a person decides. **Every deterministic step that has a
verb is a verb** from the [**Nen**](https://github.com/zheref/nen) CLI: Nen detects, computes, formats and
verifies; the skill supplies only the judgment a binary cannot. Where no verb exists yet, the residue is
**named per skill** in [`docs/ab/`](docs/ab/) rather than quietly improvised.

No GitHub App. No bot identity. Nothing here merges `main`, publishes a release, or casts a review vote.

> **`v0.8.0`.** Hatsu is the local plane of the Akatsuki system, and it succeeds the local plane of a
> predecessor system — the frozen reference implementation — which it also **serves live today**: the
> original seventeen skills were ported name-for-name and proven against that system's real backlog before
> `v0.1.0` was cut. The evidence is in [`docs/ab/`](docs/ab/), one file per skill — dated records of the port
> against nen `0.1.0`. `v0.3.0` reconciled every skill and persona with nen **`v0.3.0`**, and `v0.7.1` repins to nen **`v0.5.0`**. **`v0.4.0` adds the
> way of working**: ten skills that make the local loop itself explicit, two configuration files that hold
> every parameter of it ([`nen/contract.json`](nen/contract.json) → `project` and
> [`nen/workflow.json`](nen/workflow.json)), and two harness hooks — a stop bell and a refusal to commit on
> the trunk. **`v0.5.0` adds the PR side**: eight more skills — `mukai`, `murasaki`, `hanten`, `gyo`,
> `kotoamatsukami`, `shibari`, `en` and `jujutsu` — the rename of `drive` to **`sharingan`**, and the three
> agent definitions that side needs: **Feitan**, **Chrollo** and **Illumi**. **`v0.6.0` closes the release
> side**: `susanoo` (archive and packaging), `kagutsuchi` (non-production upload, per target) and `mugetsu`
> (publication, per target, **G3**) — so four of the five phases only you may call have a skill; the
> fifth is **the merge**, which has none because no agent performs it.
> **`v0.7.0` adds no skill and adds two surfaces**: the same thirty-eight skills and eight personas,
> generated into Codex and Cursor layouts under [`surfaces/`](surfaces/) — see [*Surfaces*](#surfaces).
> **`v0.8.0` adds no skill either, and splits provenance in two**: `Hatsu-Agent:` is what a local session
> writes, `Akatsuki-Agent:` is the autonomous CI plane's key and nothing here writes it — the maintainer's
> ruling of 2026-09-10. [`docs/WORKFLOW.md`](docs/WORKFLOW.md) is the authority on all of it.

---

## Requirements

**Three of these are the same on every surface**, and then each surface brings its own host program.

| | |
|---|---|
| [`nen`](https://github.com/zheref/nen) **`>= 0.7`** | a **hard** dependency — see [The Nen contract](#the-nen-contract-d10). You do **not** need to install it yourself; the warm-up does it, checksum-verified. **One exception, on Codex** — the box below the surface table. |
| `git` + [`gh`](https://cli.github.com), authenticated | the skills read and write GitHub as **you**. |
| a [`nen/contract.json`](nen/contract.json) in the repository you point Hatsu at | **the only thing Hatsu asks of your project.** It declares what *your* build, test, lint, archive and deploy commands are, so nothing here is bound to a language, a framework, a build system or a product. A repository that declares none gets the git half of every skill and its own documented commands, said plainly rather than guessed at. |

**On the installed plugin path**, nothing here needs `jq`, `yq` or Python: one binary, plus `git` and `gh`.
(The repository's own CI is a separate matter — `scripts/plugin_bump_check.sh` uses `jq`, but nothing an
installed copy runs does.)

### Per surface

| | **Claude Code** | **Codex** | **Cursor** |
|---|---|---|---|
| **the host** | [Claude Code](https://claude.com/claude-code). The `claude plugin` subcommands below are its own | the `codex` CLI. **No minimum is established**; the build every record here was made on is **`codex-cli 0.149.0`** (`codex --version`) | `cursor-agent` — **`2026.01.*` or newer, and this one is a real floor**. See the box below |
| **signing in** | the harness's own | `codex login`. `codex login status` answers `Logged in using ChatGPT` | `cursor-agent login`. `cursor-agent status` answers `✓ Logged in as <you>` |
| **where it reads the skills from** | the installed plugin, in place — nothing is written into your repository | `<repo>/.agents/skills/<name>/`, **placed there by the warm-up** | `<repo>/.cursor/skills/<name>/`, the same |
| **and the personas** | `claude/agents/`, in place | `<repo>/AGENTS.override.md` — one **untracked** file, as prose | `<repo>/.cursor/agents/<persona>.md` — one subagent file each |
| **how it got there** | `claude plugin install` | a checkout on the host, plus `$HATSU_PLUGIN_ROOT` — [*On Codex*](#on-codex) | the same — [*On Cursor*](#on-cursor) |
| **the caveat that bites first** | none | `AGENTS.override.md` **replaces** your `AGENTS.md` in the instruction envelope rather than joining it, so the warm-up copies yours into it verbatim first and never writes the tracked file | the skill name space is **flat and global** — shared with Cursor's own built-ins and with every other plugin on the host |

> ### ⚠️ Below `2026.01`, `cursor-agent` sees **none** of the skills — and answers anyway
>
> A `cursor-agent` that predates skills support takes your prompt, runs your commands and exits `0` with
> not one of the thirty-nine loaded. With the mirror installed exactly as the warm-up mandates,
> `2025.09.18-39624ef` answered a discovery probe with the whole reply **`NO SKILLS VISIBLE`**, seventeen
> bytes — and the control that settles it is that the same build cannot see a plain `cp -R` **copy**
> either: it has no skills mechanism at all, and reached its answer by grepping the working tree.
>
> **The floor is a month, not a build id.** [Cursor's CLI changelog](https://cursor.com/docs/cli/changelog)
> dates *"Skills, rules, and commands in the CLI"* to its **January 2026** entry and groups by month, while
> `cursor-agent -v` prints `YYYY.MM.DD-<sha>` — so there is no exact version string to pin and the
> comparison is the date part. The build every Cursor fact in this README was measured on is
> **`2026.09.08-6caf4ff`**. **The warm-up prints `cursor-agent -v` beside the install count and refuses to
> claim the surface below the minimum**, because an install that succeeded onto a build that cannot read it
> is the exact shape of an unperformed step reported as a passing one.

> **`nen` auto-installs itself on Claude Code and on Cursor. Put it on the host yourself before a sandboxed
> Codex run.** The bootstrap resolves and verifies the binary into `${XDG_CACHE_HOME:-$HOME/.cache}/nen`
> ([`nen/contract.json`](nen/contract.json) → `dependency.bootstrap.flags`), which is **outside** the
> directory `codex exec -s workspace-write` makes writable — so a session under that sandbox has nowhere to
> install to. A Cursor session did run the bootstrap itself, checksum-verified, and put the result on its
> own session `PATH`.

## Install

### On Claude Code

```sh
claude plugin marketplace add zheref/hatsu
claude plugin install hatsu@hatsu
```

Then, in Claude Code:

```
/kurapika
```

To install from a local checkout instead — for development, or to run a branch:

```sh
git clone https://github.com/zheref/hatsu.git
claude plugin marketplace add ./hatsu
claude plugin install hatsu@hatsu
```

Confirm what landed:

```sh
claude plugin list                  # hatsu@hatsu — Version: 0.8.0
claude plugin details hatsu@hatsu   # the full component inventory
```

### Obtaining Hatsu on Codex and Cursor — a checkout, once, by hand

**Neither surface has a plugin loader, so the first install is a human act and it is a `git clone`.** There
is nothing on either surface that would *fetch* Hatsu; what the warm-up automates is the **refresh**, every
session, of a root that already exists. That is a boundary rather than a step somebody forgot to write, and
a warm-up that cannot find the root reports `NOT INSTALLED` and stops.

```sh
git clone https://github.com/zheref/hatsu.git ~/.hatsu                     # the tip
git clone --branch v0.11.0 --depth 1 https://github.com/zheref/hatsu.git ~/.hatsu   # or a release, pinned

export HATSU_PLUGIN_ROOT="$HOME/.hatsu"          # put this in your shell profile
```

**`$HATSU_PLUGIN_ROOT` is the form that works on all three surfaces, and it is the one to prefer.** The
warm-up resolves its root from that variable first, then from a path handed to the invocation
(`$hatsu-warmup <path>`, `/hatsu-warmup <path>`), and only then from `$CLAUDE_PLUGIN_ROOT`.

> **`$CLAUDE_PLUGIN_ROOT` is Claude Code's variable and it is *not* inert on the other two.** On the host
> these records were made on it is exported from `~/.zshrc` and points at a **different plugin**, which
> every Codex and Cursor session on that host inherits. So a candidate root is checked for what it **is** —
> the first `"name"` in its own `.claude-plugin/plugin.json`, compared whole, reading `hatsu`, plus the
> `claude/skills/` directory that manifest points at — and never merely for containing a `surfaces/`
> directory. Shape is not identity: a wrong root that happened to have the right shape would install
> somebody else's skills into your repository with no error anywhere. **Every rejected candidate is named
> by path in the report**, even when a later one succeeded, because a stale variable in a shell profile is
> a thing to fix and this is where it becomes visible.

### On Codex

From the repository you want to work in:

```
$hatsu-warmup
```

That is the whole install, and it runs first in every session anyway. What it places in **your**
repository:

| | |
|---|---|
| `<repo>/.agents/skills/<name>/` | one `cp -R` per mirrored skill directory — **39**, the thirty-eight plus `hatsu-warmup` itself — from `$HATSU_PLUGIN_ROOT/surfaces/codex/`, **re-copied every session** so a target is at most one warm-up behind the plugin |
| `<repo>/AGENTS.override.md` | **untracked**, written whole: your own `AGENTS.md` verbatim first, then the personas between a `BEGIN`/`END hatsu personas` marker pair |

**Copies, not symlinks, and the reason is what Codex advertises.** Codex lists a skill under its
frontmatter `name`, namespaced by the plugin manifest above the directory the path *resolves to* — so a
symlink into this checkout is listed as `hatsu:aka`, while a `cp -R` of the same directory is listed as the
bare `ren`, which is what the mirrors' own `$<name>` spelling needs. A symlink drags a second trap with it:
the mirrored bodies carry relative links, and through a symlink `../../../nen/workflow.json` resolves into
**this plugin's** policy file rather than your repository's. **A link that resolves into the plugin is more
dangerous than one that dangles** — a dangling link is an agent reporting it could not read something; a
resolving one is an agent answering confidently from the wrong file.

**What the warm-up refuses**, and these are hard limits rather than preferences:

- **A destination it did not create is left untouched, and named in the report.** A previous Hatsu install
  is replaced; a **tracked** path is always somebody else's, whatever it looks like. Thirty-nine ordinary
  words are being claimed at once — `build`, `file`, `en`, `ao`, `ren` — so a collision is not a rare case,
  and the warm-up would rather install thirty-seven and say so than overwrite one file it did not write.
- **It never writes your `.gitignore`.** Everything it places is excluded through the repository's own
  `info/exclude`, found with `git rev-parse --git-path info/exclude` — which in a **linked worktree**
  resolves to the *main* repository's file, shared by every checkout of it, and is stated in the report by
  path for exactly that reason. `.gitignore` is a tracked file in somebody else's repository: writing it
  lands in their diff, their review and their history, and imposes this plugin's layout on every other
  contributor.
- **It never writes a tracked `AGENTS.md`** — not appended to, not touched. The personas go to the override
  file, which is the warm-up's own; a human who wants them in their history commits them themselves.

**First-run check**, from the Hatsu checkout — it writes nothing and needs no credential:

```sh
scripts/surface_mirror_check.sh
```

**To update**, pull the checkout (or check out a newer tag) and run `$hatsu-warmup` again: the unconditional
re-copy is what refreshes the target. A copy is not self-healing, and the one failure mode it has is a
session that never warmed up serving last month's wording with no error anywhere. If you *changed* a skill,
regenerate the mirrors in the same commit — [*Surfaces*](#surfaces) has the two commands and the check.

Then read [*Using Hatsu on Codex*](#using-hatsu-on-codex).

### On Cursor

Check the version **first** — below `2026.01` the install succeeds and the surface sees nothing:

```sh
cursor-agent -v          # 2026.09.08-6caf4ff on the host these records were made on
```

Then, from the repository you want to work in:

```
/hatsu-warmup
```

| | |
|---|---|
| `<repo>/.cursor/skills/<name>/` | one **symlink** per mirrored skill directory — **39** — pointing at `$HATSU_PLUGIN_ROOT/surfaces/cursor/<name>` |
| `<repo>/.cursor/agents/<persona>.md` | one markdown subagent file each — **8** — symlinked from `$HATSU_PLUGIN_ROOT/surfaces/cursor/agents/` |

**Symlinks are honest here, and that is measured rather than assumed.** Four controlled probes on
`2026.09.08-6caf4ff` found a skill through a symlink **inside** the workspace and through one pointing
**outside** it, and listed a symlink into this plugin checkout under its **bare** name — so Codex's
namespacing behaviour does **not** reproduce on Cursor and the mirrors' `/<name>` spelling works as
printed.

**The first two refusals apply here too** — a destination the warm-up did not make is left alone and named,
and your `.gitignore` is never written (`info/exclude`, again). There is no third, because there is no
`AGENTS.md` on this surface; what takes its place is that **`.cursor/agents/` is a directory a Cursor user
is *expected* to keep their own subagents in**, which makes it the likeliest collision of all. Before it
installs anything the warm-up **lists every name already standing under `.cursor/skills/`** and reports
what it found by name — and says plainly what that listing cannot see: **a same-named skill from another
plugin elsewhere on the host may shadow the mirror, and is invisible from inside your repository.**

**First-run check**, from the Hatsu checkout:

```sh
scripts/surface_mirror_check.sh
```

**To update**, pull the checkout and run `/hatsu-warmup` again. The links point into the checkout, so
pulling it is most of the update; re-running the warm-up is what repairs a link the target lost and what
re-prints the version and the collision list.

Then read [*Using Hatsu on Cursor*](#using-hatsu-on-cursor).

---

## The Nen contract (D10)

Hatsu's skills do not improvise shell. Every deterministic step is a `nen` verb, and the dependency on that
binary is **hard**, **version-ranged**, and **fail-closed with auto-install**.

**[`nen/contract.json`](nen/contract.json) is the single source of truth.** Every version, ref, URL and
command echoed anywhere else — this README included — is a convenience copy of a value that lives there.
**Where a copy disagrees with the contract, the contract wins and the copy is the bug.** The
[`hatsu-warmup`](claude/skills/hatsu-warmup/) skill executes it at the start of every session, before any
other Nen-owned work.

The file sits where nen itself looks for a repository's dependency declaration — `nen/contract.json`, in
nen's own shape (`dependency.version_probe` as an argv array, `dependency.bootstrap` nested inside
`dependency`) — so that nen validates it rather than merely tolerating it:

```sh
nen schema check --repo <this checkout>
#   ok    nen/contract.json  dependency (nen >= 0.7, pinned v0.7.0), project (1 lane: plugin; 10 verbs; 1 toolchain entry)
#   ok    nen/workflow.json  coverage 80/85/90 (touched), branch '{model}/{persona}/{descriptor}' off 'main', checks: lint
```

(Four taxonomy rows print above those two — three `FAIL` (`nen/labels.json`, `nen/repos.json`,
`nen/colors.yml`) and one `warn` (`nen/gates.json`) — and the command exits `1`: Hatsu ships no taxonomy of
its own, `schema check` requires the three of a repository that carries one, and only warns on the fourth,
which `pr ready` can take by `--gates` instead. The two `ok` rows are the ones this repository owns. **There
is no `schemas/` fallback at this pin** — it was removed in nen `v0.5.0`, so `nen/` is the only directory any
taxonomy-reading verb reads from, and a repository carrying a file only under `schemas/` is refused with the
migration named.) Every
Hatsu-authored key beside nen's own — the zero-major caveat, the two install paths, the halt template, the
no-`jq` rule — is preserved verbatim by nen's loader and read by nothing in nen. There is deliberately no
second copy: it was `nen.contract.json` at the root through `v0.2.0`.

Since `v0.4.0` the same file also carries a **`project`** block — Hatsu's own lane, written by hand because
`nen shu detect --repo .` answers *no lane detected* for a bash-and-markdown repository. `lint` is
`claude plugin validate . --strict`; every other verb of the family is an explicit `unsupported` **seat**
stating in this repository's words why it does not exist, because a seat is exit `4`, a stated fact, while an
omission is exit `2`, a broken declaration. Its policy half, [`nen/workflow.json`](nen/workflow.json), is
**validated by nen at the pinned `0.7.0`** — the second `ok` row above, with a malformed key reported as a
FAIL by pointer — and [`docs/WORKFLOW.md`](docs/WORKFLOW.md) documents both.

### The range

*Current pin, echoed for convenience:* **`nen >= 0.7`**.

**While nen's line is `0.x`, that means `>=0.7.0 <0.8.0` — exactly.** A different minor is out of range in
**both** directions: `0.8.0` fails it as surely as `0.6.0` does. At major version zero, SemVer 2.0.0 clause 4
makes the *minor* the breaking-change vehicle, so reading `>= 0.7` as "anything backward-compatible within
major 0" would fail **open** in precisely the range where compatibility is least guaranteed — and the last
three releases are all the proof. `v0.5.0` **removed** something a consumer could rely on (the `schemas/`
fallback), the first release since `v0.1.0` to do so; `v0.6.0` changed three behaviours **in place**, and
`v0.7.0` changes four more, none of them announced by a new flag — `nen stage triage` gains the
`local-config` and `large` detectors, so a tree that answered exit `0` answers exit `1` on the same bytes;
every relative own-path flag (`--body-file`, `--out`, `--input`, `--efforts`, `--original`, `--table`, and
`canon mirror`'s five) resolves against `--repo`'s root instead of the process's directory; a missing or
malformed `--target` exits `2` rather than `1` across sixteen verbs, and so does an unreadable
caller-named input on `split verify`, `changelog` and `canon mirror check`; and `nen pr ready` **reads**
`nen/gates.json`'s `dependabot_carve_out`, so an unchanged file can turn a `not-ready` into a `ready`. The familiar
"compatible within a major" reading applies from **`1.0` onward**, and the contract is bumped to say so when
nen gets there.

### What happens when the range is not satisfied

Two cases, two paths, chosen by the probe (`nen --version`) and never by preference:

| Probe result | What the warm-up does |
|---|---|
| **nen absent** | Fetches nen's own published `bootstrap/nen.sh` at the pinned ref and runs it. This is the **sole** chicken-and-egg carve-out for shell anywhere on a Hatsu path: `nen bootstrap` is a `nen` subcommand, so it presupposes the binary that is missing. |
| **nen present, out of range** | Re-pins **through the verb**: `nen bootstrap --ref <pinned> --source zheref/nen --script <fetched script>`. `--script` is required — the verb *runs* the bootstrap rather than reimplementing it, so it needs the script on disk. |

Either way:

- **The bootstrap is checksum-verified.** It fetches nen's published `SHA256SUMS` and refuses bytes that do
  not verify. A checksum failure is **never** retried — retrying one is how a fail-closed guard becomes a
  fail-open one by attrition.
- **The script is fetched to a file and then run — never `curl … | bash`.** It reads `${BASH_SOURCE[0]}`
  under `set -u`, so a pipe kills it before it parses its own arguments.
- **The bootstrap is never vendored here.** Hatsu fetches nen's own script at the pinned ref, every time, so
  there is no second, unreviewed copy to drift from the manifest it verifies against.

### Halt — and what it is not

An absent or out-of-range `nen` is **not** a halt; it is an auto-install. The session halts **only when the
bootstrap itself fails**, and then it prints the exact command for you to run yourself, and stops.

**There is no LLM-improvised fallback for a Nen-owned operation, ever.** If nen is unavailable and the
bootstrap failed, the operation does not happen — not with raw `gh`, not with a shell equivalent, not from
memory. Reporting that is the correct outcome; substituting a hand-rolled equivalent is not.

---

## The roster

[`docs/ROSTER.md`](docs/ROSTER.md) is the authority on who exists and what standing they have; the agent
definitions in [`claude/agents/`](claude/agents/) are the authority on what each one does. Every agent
that writes a commit signs it `Hatsu-Agent: <name>`, with no run trailer — there is no CI run to name
(Illumi writes none: he is read-only). `Akatsuki-Agent: <name>` is the **other plane's** key, written by an
Akatsuki roster agent in CI and never by anyone here. **The git author is always the human.**

### Kurapika — the lead persona

Defined at **[`claude/agents/kurapika.md`](claude/agents/kurapika.md)**, summoned with **`/kurapika`**
([`claude/commands/kurapika.md`](claude/commands/kurapika.md)). He trained all six Nen types, and his
canonical trick is not power but **conditions**: a binding accepted in advance, stated out loud, paid in
full. The six types are his
work-modes, and **naming the mode in play is not decoration** — it tells you which authority he believes he
is holding, so you can catch him holding the wrong one *before* he acts on it.

| Mode | Lane | Where its work stops |
|---|---|---|
| **Enhancer** | **Product code** — edit, build and test locally, open the PR. Never merges, never votes, never self-reviews. | the merge gate — **yours** |
| **Conjurer** | **Canon & governance authoring** — constitutions, handbooks, schemas, agent definitions, taxonomies, thresholds. Conjured contracts *with conditions*: a clause states what it binds, what it costs, when it lapses, and what happens when it is broken. | the policy gate — **yours** |
| **Transmuter** | **Machinery** — Nen verbs and their tests, scaffolding, hooks, workflows, generators, plugin manifests, contract files. The standing transmutation is *improvised shell → deterministic verb*. | the policy gate — **yours** |
| **Manipulator** | **GitHub-side ops** — drives, wakes, labels, retargets, cascades, thread stewardship. | drives *to* a gate, crosses none |
| **Emitter** | **Release & fan-out** — the tag cut, changelog collation, preflight, the repin fan-out. | prepares a release; **never publishes one** |
| **Specialist** | **Product intake** — a raw thought elicited into a decision-complete brief, filed only on explicit confirmation. | epic approval — **yours** |

### The independents

**Seven, beside Kurapika: six ratified, and one — Illumi — *provisioned* rather than ratified and marked as
such.** Each has a discipline he delegates to rather than absorbing. The last three landed at `v0.5.0`, with
the PR side that needs them.

| Agent | Discipline | Status |
|---|---|---|
| **[Gon](claude/agents/gon.md)** | **Mission-scoped trusted delegate.** He always asks: what is the mission · which gates may I cross · under what conditions · when does the grant expire · where is it logged. | **Ratified as an agent. His delegation grammar is a DRAFT — so he crosses no gate.** See below. |
| **[Hisoka](claude/agents/hisoka.md)** | **UI/UX review and quality measurement, before a PR is ever posted** — the visual-evidence set, and the cheap objective things measured on your own machine: contrast ratios, target sizes, type scale, reduced-motion, artifact delta. | **Ratified** |
| **[Phinks](claude/agents/phinks.md)** | **Adversarial pre-release QA, under the proven-finding discipline** — every hypothesis class gets a recorded disposition, and nothing is filed that is not proven: a committed test failing 3/3 against the candidate, or a measured number with its method block. **From `v0.5.0` also a pre-PR trigger**, on a release-adjacent change set — a new way to be called, never a new authority, and the 3/3 floor still applies. | **Ratified** |
| **[Uvogin](claude/agents/uvogin.md)** | **Performance testing** — the fixed seven metrics on every pre-release run, with pinned tooling, regression thresholds, in-repo baselines, and a five-field method block per number. | **Ratified** |
| **[Feitan](claude/agents/feitan.md)** | **Security, and security only** — auth flows, secrets and credential handling, network and storage boundaries, data minimisation, the supply chain. He cites the inherited `SEC-{n}` rules **by id, resolved from the handbook set and never from memory**, and never runs an exploit against anything live. | **Ratified** 2026-09-09; definition at `v0.5.0` |
| **[Chrollo](claude/agents/chrollo.md)** | **Architecture and handbook conformance** — the `UZF-{n}` core, **exactly one** resolved stack handbook, and the repository's own architecture notes, each cited by id or by path. He is where a coverage-floor breach or a missing unit test is routed. **He reviews the handbooks; he never authors them.** | **Ratified** 2026-09-09; definition at `v0.5.0` |
| **[Illumi](claude/agents/illumi.md)** | **The long watch** — `en`'s step 6, when a landing watch must outlive the session that started it. Read-only through `nen watch until`, under the mandatory cap; he wakes Kurapika and acts on nothing. His frontmatter carries no `Edit`, `Write` or `MultiEdit`, and `Bash` — which every observation needs — is held to a **stated command allowlist** in his own definition rather than to a construction. | **PROVISIONED, not ratified** — `en`'s watch **only**; see below |

> #### ⚠️ Gon's delegation grammar is a DRAFT — until it is ratified, Gon crosses no gate
>
> The clause that would make a gate-crossing grant *valid* — **mission · gates · conditions · expiry ·
> logging** — is drafted here at [`docs/delegation-grammar-DRAFT.md`](docs/delegation-grammar-DRAFT.md) and
> **ratified elsewhere**: with the rewritten constitution at
> the migration tracker (private), a G4-class review (this is
> **OPEN-2** in [`docs/ROSTER.md`](docs/ROSTER.md)). **No grant can be given today, because there is
> no valid form for one to take.** Gon does the work, takes it to the gate, and stops there, exactly as
> every agent does by default. A delegate that acts on a draft has ratified the draft by itself.

### 🔶 OPEN — Killua, and the rest of Illumi's row

**These rows are open sub-decisions, and the ruling has been made only in part.** It is the maintainer's, not
this repository's. What follows is recorded **verbatim as proposals**. **Killua has no definition and may not
be acted as; Illumi's definition covers the ruled half only**, and refuses the three engines below by name.

| Agent | *Proposed* role | Status |
|---|---|---|
| **Illumi** — the unruled half | *Proposed:* the long-running loop **engines**: `backlog-loop`, `futon`, `senkei` | **Still OPEN.** The 2026-09-09 ruling provisioned him for `en`'s long watch **and nothing else** |
| **Killua** | *Proposed:* delegate-run watchdog paired with Gon — a Gon mission never runs unwatched — plus fast single-object interventions | **OPEN** — no definition, and none implied by Illumi's |

**Killua's row touches Gon's grammar and must not be collapsed into it.** If ratification adopts the pairing,
`watched` becomes a *mandatory* condition on every Gon grant; if it does not, `watched` stays optional or is
dropped. **Neither is assumed.**

When work arrives that plainly wants one of them: do it in the fitting Kurapika mode and **name the gap**.
Naming it is what eventually gets the ruling made. Standing up the agent instead closes an open question with
nobody deciding it.

### 🔶 BENCH — the Genei Ryodan

*Extensible professional-profile agents, adopted as needed* — a list of shapes the roster can grow into.
**Two were activated on 2026-09-09 — Chrollo and Feitan — and their definitions landed at `v0.5.0`, so their
rows now live under *The independents* above.** The five below are bench only, with no activation implied.

| Bench member | Profile | Standing |
|---|---|---|
| **Machi** | Integration surgery | Bench |
| **Shalnark** | Automation | Bench |
| **Kortopi** | Scaffolding | Bench |
| **Pakunoda** | Repo forensics | Bench |
| **Shizuku** | Cleanup | Bench |

**None of these five has a definition in `claude/agents/`, none is listed in `plugin.json`, and none may be
acted as** — activation is a decision about standing, not a licence to improvise the agent, which is why
Chrollo and Feitan could not be acted as between their activation and their definitions landing one release
later. Adopting another remains a deliberate act with its own decision.
[`docs/ROSTER.md`](docs/ROSTER.md) § *Rulings of 2026-09-09* is the authority.

---

## The skills

Thirty-eight, invoked as `hatsu:<name>`. Longer descriptions in
[`claude/skills/README.md`](claude/skills/README.md).

### The seventeen that answer a request

| Skill | |
|---|---|
| `backlog-state` | The whole backlog as one gate-oriented table — every open issue, its PRs, the gate it sits at, what it needs next. Read-only. |
| `backlog-board` | The identical sweep and computation, painted as an HTML gate board published as an Artifact. Read-only. |
| `backlog-loop` | Drives a repository's backlog to zero open actionable issues, in severity order, as gate-ready PRs. **Also cuts the release tag and opens the consumers' repin PRs at declared severity-batch boundaries** — never publishes a release. |
| `backlog-synthesis` | Groups open issues sharing a clause, a machinery file or a root cause into one consolidated issue, attaches the originals as sub-issues **and closes them** — behind a plan you approve first. |
| `bankai-handbooks` | Resolves which handbooks govern a repo and scenario, and which rule-ID prefix each one owns, so a citation is never improvised. |
| `bankai-quality` | Resolves the adversarial-test tooling, performance tooling and QA rules for a repo's scenario, before a release is cut. |
| `build` | Takes one issue from wherever it sits to a delivery PR standing ready at its human gate. |
| `file` | Files one well-formed, correctly-labelled, non-duplicate issue — reconciled against the open backlog first. |
| `futon` | Takes one whole severity band from open issues to PRs with an actor behind them, then **gates** the terminal step you typed — it clears its own gate and hands the cut to `getsuga`; it never cuts a tag itself. |
| `getsuga` | **Cuts** a release tag locally, end to end — preconditions, one folded **release-proposal** PR you merge, the **post-merge** tag, the fan-out and the consumers' repin PRs. The release unit is `susanoo`'s; publication is `mugetsu`'s. Never publishes a release. |
| `izanagi` | Repeats a task that **acts** until a condition holds, under a **mandatory** iteration cap. No cap, no run. |
| `izanami` | Repeats a **read-only** task until a condition holds. It looks, reports, and stops. |
| `jujisho` | Splits a mixed working copy into up to two stacked branches and PRs, by axis, proving nothing was left behind. |
| `pr-state` | Reports one PR's readiness as the deterministic gate's verdict, quoted, with the conjunct that failed. Read-only. |
| `senkei` | Inventories a consuming product repo's own backlog and states a Ready/not-Ready call for every open PR. **It writes as well as reads**: it re-runs failed checks (`nen run rerun-failed`) and fires `bankai:wake/iterate` on a stalled PR. Never merges. |
| `sharingan` | Drives one open PR to readiness at its gate and stops there — first blocking condition, threads, wakes. **Renamed from `drive` at `v0.5.0`**; the behaviour is unchanged and `hatsu:drive` no longer resolves. |
| `tensho` | Turns a dirty working copy into one PR, reviewing every file before staging it, then hands that PR to `sharingan`'s engine to reach its gate. |

### The ten that *are* the way of working — new in `v0.4.0`

Nine atomic, one composite. [`docs/WORKFLOW.md`](docs/WORKFLOW.md) is the authority on the loop, the two
configuration files behind it, and the phases only you can call.

| Skill | | |
|---|---|---|
| `breath` | **atomic** | **Warm-up, once per effort.** On the base branch and clean: fetch, fast-forward, cut `{model}/{persona}/{descriptor}` from the fresh trunk, prove the declared iteration checks. Asks only on a dirty tree; never discards a tree it has not inspected. |
| `rasengan` | **atomic** | **Build, before every commit.** Runs every declared iteration check through the lane's own verb. A red build is fixed, never committed over; an unsupported seat is quoted, never routed around. |
| `kokusen` | **atomic** | **The automatic local commit.** Build green, then staging triage with an **ask on every flagged file** and never a secret, then the formatted message. Commits, and only commits. |
| `amaterasu` | **atomic** | **Launch, every turn.** Builds the configured target and starts it **from your working directory, never a worktree**. A disconnected device is reported by name. |
| `tsukuyomi` | **atomic** | **Tests health.** Runs the required suites, parses the results, fixes and re-runs — or stops at **G5**. It never patches a test to make it pass. |
| `rikugan` | **atomic** | **The rich report** — turn, landing, final — rendered from an HTML template, never markdown. Only the final one is written to the git-ignored `Reports/`. |
| `jutaisho` | **atomic** | **The bell.** Rings the notification ladder you declared, and drops the marker the `Stop` hook reads. |
| `ao` | **atomic** | **Pull from the base.** Rebase if unpushed, merge if not; mechanical conflicts resolved, a **semantic** one raised as a **G5** with both sides shown. Never pushes. |
| `aka` | **atomic** | **Push — yours to call.** Tests → squash the unpushed commits → `ao` → push. No PR, and no agent ever prompts for it. |
| `ren` | **composite** | **The per-request loop**: `breath` → `rasengan` → `kokusen` → `amaterasu` → `rikugan` → `jutaisho`, looping until you call the next phase. **It never pushes.** |

### The eight that are the PR side — new in `v0.5.0`

Five atomic, three composite. `mukai` is yours to call; everything else here is something it runs.
[`docs/WORKFLOW.md`](docs/WORKFLOW.md) § 5 is the authority.

| Skill | | |
|---|---|---|
| `hanten` | **atomic** | **Adversarial review, pre-PR.** Classifies the change set by scope and spawns **one reviewer per scope** — UI → Hisoka, security-bearing → **Feitan**, architecture/handbook → **Chrollo**, performance → Uvogin, release-adjacent → Phinks — each titled `hanten · <persona> · <model alias>`, never on the frontier tier. One fixed finding shape: **rule id · severity · evidence · proposed fix**. Kurapika fixes or pushes back with a reason; an unsettled finding is a **G5**. |
| `gyo` | **atomic** | **The coverage bar.** Touched-file line coverage against the 80/85/90 ladder, reported band by band; adds tests until every touched file clears the `minimum`, and raises a **G5** when one honestly cannot. **It never lowers the bar.** |
| `kotoamatsukami` | **atomic** | **End-to-end / UI tests.** Runs the declared UI suite where a repository declares one; the re-recorded snapshots are what feeds the evidence table. An unsupported seat is quoted, never routed around. |
| `shibari` | **atomic** | **Composes and opens the PR** — why, how, what changes for the consumer, how to verify, a diagram where a flow changed, the evidence table, the checklist, `Closes #N`. One PR, from the last pushed commit; requests reviewers and hands it to `en`. Never labels a gate, never merges. |
| `jujutsu` | **atomic** | **Device pairing.** Walks you through trusting and registering a physical device — iOS: Developer Mode and `devicectl`; Android: USB debugging and `adb` — and lands it as a launch target **through a PR**. It writes the declaration and nothing else. |
| `murasaki` | **composite** | **Pull + push.** `ao` → `rasengan` + `tsukuyomi` → push, **only if the branch is already published**. Never squashes, never force-pushes. |
| `mukai` | **composite** | **The review-and-PR phase — yours to call.** `murasaki` → `hanten` → tests + UI tests → `gyo` → evidence → `shibari`, which opens the PR and starts `en`. **Four of the five G5 stops live inside it.** |
| `en` | **composite** | **The landing watch, capped.** Landing report → `sharingan` → `murasaki` when behind → `sharingan` → `jutaisho` at Ready → watch until merged → the final report. **A watch with no cap does not run**; where one must outlive the session, the watch itself is handed to **Illumi**, read-only. |

### The three that close the release side — new in `v0.6.0`

All three atomic. Two of them are **yours to call, per target** — that is what makes them the last two rows
of the five. [`docs/WORKFLOW.md`](docs/WORKFLOW.md) § 4 is the authority.

| Skill | | |
|---|---|---|
| `susanoo` | **atomic** | **Archive and packaging.** Runs the lane's declared `archive` and produces the distributable **locally**. It uploads nothing and signs nothing — Nen never synthesises signing material — and an unsupported seat is quoted, never routed around. This is the release unit `getsuga` folds into the release PR and the two phases below send. |
| `kagutsuchi` | **atomic** | **Non-production upload — yours to call, per target.** The plan is always printed (`nen shu deploy --target <name>`, no `--run`); `--run` acts only on your own call **naming the target**, and never from a composite. `--target` is required with no default, even where exactly one destination is declared. |
| `mugetsu` | **atomic** | **Publication — yours to call, per target, G3.** Only on your recorded per-target go, with the preflight green and the tag already cut. **One target per call**, and never from `getsuga`, `futon` or `en`. This is the only phase that reaches other people's users. |

> **The boundary was always the governance, not the file.** These three were named phases before they were
> skills, and the loop stopped at them then exactly as it does now.

Plus [`hatsu-warmup`](claude/skills/hatsu-warmup/) — the Nen contract, executing — and the `/kurapika`
summon command.

### The way of working

`v0.4.0` writes the loop down. Two files hold every parameter of it, and the split matters:
[`nen/contract.json`](nen/contract.json) → `project` says what **nen executes** (lanes, per-verb argv,
preconditions, hosts, deploy targets, launch targets), and [`nen/workflow.json`](nen/workflow.json) says what
the **workflow decides** (branch shape, which declared verbs run per iteration, the coverage ladder, reports,
notifications, the commit-trailer allow-list, the model matrix). A wrong `project` block runs the wrong
command, loudly. A wrong `workflow.json` runs the right command at the wrong moment, silently. Keeping them
apart is what keeps the second class of mistake visible.

- **`ren` runs on every request** and never pushes. **Five phases are yours to call, and no agent ever
  prompts for them**: `aka` (push), `mukai` (review and PR), the **merge**, `kagutsuchi` (non-production
  upload) and `mugetsu` (publish, **G3**).
- **`mukai` is the whole PR side, in a fixed order** — `murasaki`, then `hanten`'s scope-routed review, then
  the tests and UI tests, then `gyo`'s coverage bar, then the evidence, then `shibari` opening one PR and
  starting `en`'s capped landing watch. Reviewers advise and never vote; **the merge stays yours**.
- **Only a genuine G5 interrupts you** — red required tests, touched-file coverage under the ladder's
  minimum, a *semantic* merge conflict, an unsettled adversarial finding, a stuck-PR escalation. Five, and
  nothing else. A stop is `nen stop`'s banner, the report link, and the question asked through your surface's
  own native option picker.
- **Branches read `{model}/{persona}/{descriptor}`**, and every subagent is titled
  `<skill> · <persona> · <model alias>` — what ran, as whom, on what. A subagent is **never** given the
  frontier model tier; that tier is where your own conversation lives.
- **[`hooks/hooks.json`](hooks/hooks.json)** ships two harness hooks, and they are discovered automatically at
  that path: a `Stop` bell that notifies and plays a sound when a gate stop is waiting, and a `PreToolUse`
  guard on `Bash` that refuses a `git commit` or `git push` while you are standing on the base branch. The
  guard **parses** the command — quoted spans masked, the line split into segments, git's global options
  walked past — so `echo 'git commit'` is not a write and `git -C <dir> commit` is judged in `<dir>`; it
  fails *closed* only where the branch it can see is not the branch the write would land on. Both are POSIX
  `sh`, use no `jq`, and otherwise no-op rather than block on anything they cannot read.
- **Two provenance trailers, one per plane — and no AI attribution trailer is ever recorded.**
  `Hatsu-Agent: <persona>` is what a local Hatsu session writes; `Akatsuki-Agent: <persona>` belongs to an
  Akatsuki roster agent on the autonomous CI plane, and **nothing here writes it**. Both are admitted by
  `nen/workflow.json` so that one `commit-msg` hook passes a commit from either plane — admitting a key is
  not licence to write it. Each names the system's own provenance, not a model claiming authorship, which
  is why there is no third. **Set `includeCoAuthoredBy: false`** in your
  Claude Code settings so the harness stops adding `Co-Authored-By:`. Enforcement is **three-layered, and at the
  pinned nen `0.7.0` the third layer is the binary's**: (a) `kokusen` and `aka` refuse to **write** such a
  trailer — agent-side, and it is what Hatsu itself carries; (b) the **target repository's `commit-msg`
  hook**, which `nen scaffold init` generates from `commits.allowedAttributionTrailers` (KroApple and
  kro-pwa carry one) — and from nen `v0.6.0` that hook's automated half is **derived from the repository's
  own policy**, requiring the one key `--agent-trailer` resolved to plus the optional `commits.runTrailer`,
  rather than a fixed pair; (c) **`nen commit format --repo`** and **`nen wc squash`** refusing the trailer
  outright at exit `2`, naming the file and the keys it admits. **Layer (b) stays target-dependent** — a
  repository that has not been scaffolded with the hook has (a) and (c) and no hook, and that is said
  plainly rather than promised as mechanical.

### What nen's `shu` family adds to the roster's own procedures

nen's **`shu`** family runs whatever a target repository *declares* in its `nen/contract.json` `project`
block — and nothing else — so `build`, `futon`, Gon, Hisoka, Phinks and Uvogin now start a piece of work with
`nen shu warmup` (`--dry-run` first, then bare: clean → fresh trunk → your branch → the declared build),
check a fresh host with `nen shu tools`, and verify with `nen shu build`/`test`/`lint`/`coverage`, each
with `--dry-run` printing the exact argv first. Kurapika's Transmuter mode stands a repository up with
`nen shu detect` → `nen scaffold init` (or `nen scaffold new` for a tree that does not exist yet) →
`nen schema check` → `nen shu tools`. `nen shu deploy --target <name>` prints a plan and sends nothing;
`--run` is the maintainer's word at **G3** and no skill here adds it. And `nen issue comment` replaces the
raw `gh issue comment` two skills used to carry as residue. A repository that is not one of nen's seven
stacks (this one included: `nen shu detect --repo .` answers *no lane detected*) gets the git half of the
warm-up and its own documented commands, said plainly — the full rules are in
[`claude/agents/kurapika.md`](claude/agents/kurapika.md) § *The `shu` verbs*.

### Evidence

Every skill ships with its own record in **[`docs/ab/`](docs/ab/)**. For each of the original seventeen that
is an A/B: the mechanics before the port, the mechanics after, and a live transcript against a real backlog
showing the same verdict reached with fewer improvised commands — `nen` invocations where the old transcript
had raw `gh`. For each of the ten added at `v0.4.0` it is the same evidence in the same shape, minus the
"before": the verbs exercised live with their exit codes, the residue that has no verb at the pinned nen, and
the findings the exercise filed against the binary. The surface was proven before this version was cut; it is
not an aspiration.

Those transcripts were recorded against repositories that are **not public**, so every private repository
name in this repository is replaced by a stable placeholder. The legend, and what is deliberately left
alone, are in [`docs/PUBLIC-REDACTION.md`](docs/PUBLIC-REDACTION.md).

### Rollback

**For you, as a public reader, rollback is simply uninstalling Hatsu** — `claude plugin uninstall
hatsu@hatsu`. Nothing server-side changed, so there is nothing else to undo.

Reinstalling the predecessor *bankai* plugin is the **maintainer's own** path back, not a public
one: its marketplace is private, and the links to it in this repository resolve only for someone
who already has access.

---

## Surfaces

**Hatsu is authored once and read on three agent surfaces.** On Claude Code it is a plugin and nothing else
is needed. On **Codex** and **Cursor** there is no plugin loader, so the same skills and personas are
*generated* into each surface's own layout and committed here, and the warm-up places them into the
repository you are standing in.

| | **Claude Code** | **Codex** | **Cursor** |
|---|---|---|---|
| you type | `hatsu:rasengan` | `$rasengan` | `/rasengan` |
| skills read from | the installed plugin | `.agents/skills/<name>/` | `.cursor/skills/<name>/` |
| personas read from | `claude/agents/` | `AGENTS.override.md`, as prose — an **untracked** file that *replaces* your `AGENTS.md` in the envelope, so the warm-up copies yours into it verbatim first and never writes the tracked one | `.cursor/agents/<persona>.md` |
| turn-end hook | **yes** | no — the bell rings in-session and says so | no — the same |
| in-session subagent | **yes** | no — a reviewer is a second `codex exec` run in its own worktree | yes |
| reviewer tier `deep` | `opus` | `sol` | `grok` — **Cursor-native only** |
| installing it | [*On Claude Code*](#on-claude-code) | [*On Codex*](#on-codex) | [*On Cursor*](#on-cursor) |
| using it | the rest of this README | [*Using Hatsu on Codex*](#using-hatsu-on-codex) | [*Using Hatsu on Cursor*](#using-hatsu-on-cursor) |

Everything the warm-up puts in your repository is excluded through `.git/info/exclude` — **never your
`.gitignore`**, which is a tracked file of yours and not this plugin's to edit.

The mirrors under [`surfaces/codex/`](surfaces/codex/) and [`surfaces/cursor/`](surfaces/cursor/) are
**generated, not authored** — one command per surface, run from the repository root, every file carrying a
`GENERATED by nen surface mirror` marker:

```sh
nen surface mirror generate --source claude/skills --agents claude/agents \
  --surface codex  --out surfaces/codex  --invocation-prefix "hatsu:"

nen surface mirror generate --source claude/skills --agents claude/agents \
  --surface cursor --out surfaces/cursor --invocation-prefix "hatsu:"
```

`--invocation-prefix` is what rewrites every `hatsu:<name>` in a body — its own `description` included —
into that surface's spelling, so a reader of either mirror is told to type something that actually works
there. **`hatsu:` is caller data**; nen hard-codes no system's vocabulary. Edit
`claude/skills/<name>/SKILL.md`, regenerate, and commit both;
[`scripts/surface_mirror_check.sh`](scripts/surface_mirror_check.sh) fails a mirror that has drifted, and
says *skipped, not passed* on a `nen` too old to carry the verb.

**[`docs/SURFACES.md`](docs/SURFACES.md) is the authority** — what each surface reads, what is generated
versus authored, the regeneration command, the check, and the exact headless invocation for a validation
run on each.

---

## Using Hatsu on Codex

**Everything above about the loop, the gates and the roster is true here.** What changes is the spelling,
where a delegate comes from, who rings the bell, and which aliases the model matrix answers with. Nothing
in this section is product- or stack-specific: it is the same thirty-eight skills reading your repository's
own [`nen/contract.json`](nen/contract.json).

### Invoking a skill

**You type `$<name>`** — `$ren`, `$aka`, `$mukai`, `$hatsu-warmup`. That is the spelling the mirrored bodies
carry, and it is honest **because the warm-up installs by `cp -R`**: Codex lists a skill under its
frontmatter `name`, namespaced by the plugin manifest above the directory the path resolves to, so a copy
is advertised bare (`ren`) while a symlink into this checkout would be advertised as `hatsu:ren`.

### The loop, and the phases only you call

Unchanged, name for name. **`$ren` runs on every request** — `$breath` on the first turn, then `$rasengan`,
`$kokusen`, `$amaterasu`, `$rikugan`, `$jutaisho` — and it never pushes. **Five phases are yours to call,
and no agent ever prompts for them**: `$aka` (push), `$mukai` (review and PR), the **merge**, `$kagutsuchi`
(non-production upload) and `$mugetsu` (publish, **G3**). A genuine **G5** stop is still the banner, the
report link, the lettered options with a star on the report, and the question **asked through this
surface's own option picker** — `AskUserQuestion` is Claude Code's name for that, and what the rule binds
is the *shape*: a stop rendered as a paragraph ending in a question mark is a stop you have to compose an
answer to.

### Personas, and how a reviewer is raised

**A persona on this surface is prose, in `AGENTS.override.md`, and there is no per-persona file.**
`$hanten`'s reviewers are `## <persona>` sections of one generated document.

> **Prose does not win an identity argument with the host.** On a host whose *user-level* instructions say
> "introduce yourself as X", every `codex exec` run opened as X while doing the work as Kurapika, in
> Kurapika's discipline. **So the name in a Codex transcript is neither evidence the persona loaded nor
> evidence it did not.** The record of who acted is the one Hatsu writes: `--who` on `nen stop`, the `who`
> field of `.nen/last-stop.json`, and the `Hatsu-Agent` trailer — all three carry the persona whatever the
> surface calls itself.

**Codex has no in-session subagent**, verified against `codex exec --help` rather than remembered: there is
no spawn-a-delegate flag anywhere in it. So `$hanten` raises a reviewer as **a second `codex exec` process
in its own worktree**, and the isolation the Agent tool gives for free has to be made by hand first:

```sh
git worktree add "$rev" HEAD                # the isolated copy — hanten's own act

# `sol` is the TIER ALIAS; -m wants the host's ID for it. Resolve, never remember.
sol="$(codex debug models | grep -o '"slug":"[^"]*sol"' | cut -d'"' -f4)"
[ -n "$sol" ] || { echo "codex debug models lists no 'sol' slug — G5, the reviewer cannot be raised" >&2; exit 1; }

codex exec -C "$rev" -s workspace-write \
  --add-dir "$(git -C "$rev" rev-parse --path-format=absolute --git-common-dir)" \
  -m "$sol" -o "$rev/finding.json" "<the scope, the base, the paths, and the required finding shape>"
```

`-s workspace-write` is the **narrow** choice and is deliberate: the reviewer may write inside its own
worktree — a test, a note, the finding document — and reaches nothing outside it. A reviewer that needs to
bypass a sandbox to read a diff is not reviewing a diff.

### The bell

**There is no turn-end hook on this surface**, so [`hooks/hooks.json`](hooks/hooks.json) is read by nobody
here and `$jutaisho`'s in-session path is not a fallback — it is the only path there is. The skill writes
the marker itself, runs the two escalation rungs itself, **says so**, and removes its own marker once the
stop has been answered, which on Claude Code the hook would have done.

> **On a headless run both escalation rungs are `not applicable — no seat`, and one of them lies about
> it.** A `codex exec` run has no Notification Center session and no audio device. Measured inside one on
> this host: `osascript -e 'display notification …'` exited **`0`** and delivered **nothing** (stderr:
> *"NSNotificationCenter connection invalid"*), and `afplay` exited `1` with *"AudioQueueStart failed"*.
> **Rung 2's exit code is not evidence it fired** — read stderr, report the rung as having no seat, and
> never substitute another noise-maker. The stop itself still stands: the banner, the link, the options and
> the question were always the real bell.

### The model matrix

Read from **your repository's** `nen/workflow.json` → `models`, never from memory, and the file carries
**aliases only** — *"latest alias only, never a version"*.

| tier | role | Codex alias |
|---|---|---|
| `frontier` | `orchestrator` — your own session, and **never a subagent** | `astra` |
| `deep` | `reviewer` | **`sol`** |
| `fast` | `worker`, `measurer` | `terra` |
| `economy` | | `luna` |

**An alias is a name; the id you type carries a version.** There is no bare `sol` — `codex debug models` on
this host lists `gpt-reserve`, **`gpt-5.6-sol`**, `gpt-5.6-terra`, `gpt-5.6-luna`, `gpt-5.5`,
`gpt-5.3-codex-spark`, `codex-auto-review`. So the id is resolved at the moment of use, in a command
substitution, and a failed resolution is a **G5** rather than a guess: raising a reviewer on some other
model is not a smaller version of raising the right one.

### Headless, for automation

```sh
# the deep tier's id AS THE HOST SPELLS IT TODAY — resolved, never remembered
sol="$(codex debug models | grep -o '"slug":"[^"]*sol"' | cut -d'"' -f4)"     # → gpt-5.6-sol here, today
[ -n "$sol" ] || { echo "codex debug models lists no 'sol' slug" >&2; exit 1; }

codex exec -C <repo> -s workspace-write \
  --add-dir "$(git -C <repo> rev-parse --path-format=absolute --git-common-dir)" \
  -m "$sol" "<prompt>"
```

`-C, --cd <DIR>` is the working root; `-s, --sandbox` takes `read-only`, `workspace-write` or
`danger-full-access`, and **`workspace-write` is the one to use**. Add `-o, --output-last-message <FILE>`
when something downstream must read the answer, and `--json` for JSONL events. The skills must already be
in `<repo>/.agents/skills/` — that is the warm-up, [above](#on-codex).

> ### ⚠️ `--add-dir` is not an optimisation. Without it a **linked worktree** cannot commit at all.
>
> `-s workspace-write` makes the **workspace** writable, and in a linked git worktree essentially all of
> git's own state lives outside it — `HEAD`, the index, `FETCH_HEAD` under `<main>/.git/worktrees/<name>/`,
> and the objects, `refs/`, `config` **and `info/exclude`** under `<main>/.git/`. So `git fetch`, the branch
> cut, `git commit`, `git push` and the local exclude are all refused. Reproduced on a fixture, both ways:
> the same `git add && git commit` died at exit **`128`** — *"Unable to create … `index.lock`: Operation
> not permitted"* — and exited **`0`** with `--add-dir` added and nothing else changed.
>
> **`--git-common-dir`, not `--git-dir`**: the latter answers `<main>/.git/worktrees/<name>`, which covers
> `HEAD` and the index and leaves the objects, `refs/` and `info/exclude` outside.
> `--path-format=absolute` is passed because the bare form answers relatively in a primary checkout.
>
> **The alternative is a standalone clone**, whose `.git` is *inside* the workspace, so `-s
> workspace-write` alone suffices. Prefer the clone where the session is disposable; prefer `--add-dir`
> where the effort must land in your own repository. **Either way `--add-dir` widens the sandbox by exactly
> one directory and it is a git directory** — it is not `--dangerously-bypass-approvals-and-sandbox`, and
> reaching for that *because a git write failed* trades a named hole for an unbounded one.

**Answering a G5 stop is a second invocation, and it takes almost none of the flags above.** A stop is a
designed part of every run, so a headless pass will need one:

```sh
sol="$(codex debug models | grep -o '"slug":"[^"]*sol"' | cut -d'"' -f4)"     # resolved here too

cd <repo> && codex exec resume --last -m "$sol" --skip-git-repo-check \
  -c 'sandbox_workspace_write.writable_roots=["<repo git common dir>"]' \
  -o <file> "<the answer>"
```

`codex exec resume --help` lists neither `-C/--cd`, nor `-s/--sandbox`, nor `--add-dir`. So the two
substitutions are fixed and there is no third: **the working root comes from the shell's own `cd`**, and
**every extra writable root comes from `-c 'sandbox_workspace_write.writable_roots=[…]'`**. A resume that
forgets the second hits the `Operation not permitted` above on the turn *after* the stop was answered,
which reads like a new failure and is the old one. `-m` is resolved on the resume for the same reason it
is on the first call — a remembered id fails at the worse moment.

### What is different from Claude Code — the honest list

1. **Descriptions are truncated, and there is no length that fits.** Codex prints *"Skill descriptions were
   shortened to fit the skills context budget"* at session start, and **the cut is one budget divided
   across every skill the session can see** — it moves with what else is installed. Measured here: with
   **51** skills visible the longest surviving description was **411** characters; with **87** visible every
   Hatsu description was cut to **186–190**, mid-clause, `ren`'s ending at *"Use when "*. The clause naming
   the invocation and the never-clauses is exactly what is lost, and exactly what a model-invocation
   decision is made from.
2. **No in-session subagent.** A reviewer is a second process and its isolation is `git worktree add`,
   run by the skill before the reviewer starts.
3. **No turn-end hook**, and on a headless run no seat for the escalation rungs.
4. **`$CLAUDE_PLUGIN_ROOT` is not this surface's variable** — and it is not inert either: it may be
   exported from your shell profile pointing at some other plugin. Use `$HATSU_PLUGIN_ROOT`.
5. **`nen` must already be on `PATH`** under `-s workspace-write`, because the bootstrap installs outside
   the workspace.
6. **A persona is prose sitting below your own instruction layer**, so the identity in a transcript proves
   nothing either way.
7. **A mirrored body's relative links resolve against your repository**, so a sibling link works and a
   `../../../docs/…` one dangles. That is the price of "the body verbatim", it is deliberate, and it is the
   safe direction: the mirrors are for an agent reading a skill, not for a human browsing a link tree.

---

## Using Hatsu on Cursor

**Same loop, same gates, same roster.** What changes is the spelling, how much of a description survives,
whose `build` you get when two plugins claim the name, who rings the bell, and which aliases the matrix
answers with.

### Invoking a skill

**You type `/<name>`** — `/ren`, `/aka`, `/mukai`, `/hatsu-warmup`. **Cursor lists a mirrored skill under
its bare frontmatter `name`, with no plugin namespace** — even through a symlink into this checkout, which
carries a plugin manifest. Codex's namespacing behaviour does not reproduce here, so the `/name` spelling
the mirrors print is the one that works.

### The loop, and the phases only you call

Unchanged: **`/ren` on every request** — `/breath`, `/rasengan`, `/kokusen`, `/amaterasu`, `/rikugan`,
`/jutaisho` — never pushing. Yours to call: `/aka`, `/mukai`, the **merge**, `/kagutsuchi` and `/mugetsu`
(**G3**). A **G5** stop is the banner, the report link, the lettered options with a star on the report, and
the question asked through this surface's own option picker — the same four parts, and all four or it is
not a stop.

### Personas and reviewers

**Cursor has subagents, so a persona is a file again** — `.cursor/agents/<persona>.md`, one per persona,
placed by the warm-up. `/hanten` classifies the change set by scope and invokes the matching persona as
that surface documents; the reviewer runs at `models.roles.reviewer` = tier `deep`.

> **A persona's `model:` pin does not translate between surfaces, and one of them collides.**
> `nen surface mirror generate` carries `model` through verbatim — correctly, since it mirrors rather than
> translates — so **Hisoka arrives on Cursor carrying `model: sonnet`, a Claude alias in a Cursor-native
> matrix.** The rule is `hanten`'s: **report the pin unresolvable, fall back to the role's tier (`grok`),
> and state the substitution in the title.** Never silently honoured, never silently dropped.

### The bell

**No turn-end hook here either**, so `/jutaisho` writes the marker, rings the rungs in-session, says which
it actually rang, and removes its own marker once the stop is answered. On an ordinary turn only rung 1 is
owed — the surface's own turn-end signal — and **a surface without a hook is not a reason to be louder.**

### The model matrix

| tier | role | Cursor alias |
|---|---|---|
| `frontier` | `orchestrator` — never a subagent | `grok` |
| `deep` | `reviewer` | **`grok`** |
| `fast` | `worker`, `measurer` | `composer` |
| `economy` | | `composer` |

**The Cursor column is Cursor-native only**, and the file says why in its own words:
`"Cursor-native only; provider models there are reserved for Bugbot"`. `cursor-agent models` lists provider
ids too — `claude-opus-5-*`, `gpt-5.6-sol-*`, `gemini-3.7-*` — and `--help`'s own examples *are* provider
models: **the CLI accepts them and this policy does not.** Naming one here is out of policy, not a local
optimisation.

> **`frontier` and `deep` name the same alias on this surface, and the rule survives that.** "Never the
> frontier tier for a subagent" cannot be checked by reading the alias here, so it is enforced on the
> **role**: a reviewer is raised at `models.roles.reviewer`, never as an orchestrator. Say the tier *and*
> the alias — *"tier `deep` → `grok`"* — so a transcript read afterwards is unambiguous.

### Headless, for automation

```sh
# the deep/frontier tier's id AS THE HOST SPELLS IT TODAY — resolved, never remembered
grok="$(cursor-agent models | sed -n 's/^\(cursor-grok-[0-9.]*-high\) - .*$/\1/p' | sort -Vr | head -n 1)"
[ -n "$grok" ] || { echo "cursor-agent models lists no cursor-grok id" >&2; exit 1; }

cd <repo> && cursor-agent -p --output-format text --model "$grok" -f "<prompt>"
```

> **`--model grok` does not exist and nothing runs.** `grok` is the *alias* the policy file carries; the
> command line needs the id the host is serving. `cursor-agent models` prints `<id> - <label>`, one per
> line, and the Cursor-native rows today are `cursor-grok-4.6-{low,medium,high,xhigh}[-fast]`,
> `cursor-grok-4.5-high[-fast]` and `composer-2.5[-fast]`. The id is a **two-axis** choice — version and
> reasoning tier — so the rule is written down rather than left to each caller: **newest version, plain
> `-high`, never `-fast`.** The `sed` / `sort -Vr` above is that rule, executable; it resolves to
> `cursor-grok-4.6-high` on this host today, and `composer` resolves the same way to `composer-2.5`.

- `-p, --print` is the non-interactive form; `--output-format` takes `text`, `json` or `stream-json` and
  **only works with `--print`**.
- **`-f` is `--force`, and it is NOT a file flag.** It *"force allow[s] commands unless explicitly
  denied"*; the line above parses only because `-f` takes no value and the prompt is a **positional**
  argument. The Codex block uses no such adjacency, so a reader copying one line is being invited to
  misread it.
- **The working root is the shell's own `cd`**, and that form works on every build. This build's `--help`
  also lists `--workspace <path-or-name>`, `--add-dir <path>` and `-w, --worktree [name]`.
- **There is no sandbox to widen, and that is a difference rather than an absence.** Codex's whole
  `--add-dir` box exists because `-s workspace-write` cannot perform a single git write in a linked
  worktree. Cursor has no counterpart to that failure: a headless run fetched, cut a branch, rebased and
  first-published **inside a linked worktree** with no permission failure of any kind.
- **Answering a G5 stop is `--resume`, a flag on the same command line** — unlike `codex exec resume`, so a
  stop is answered with the same line plus the id. Fix the id up front with `cursor-agent create-chat`,
  which prints one, rather than relying on `--resume`'s "latest". **The path is unexercised**: no G5 fired
  in the recorded run, so `--resume` has never been used in anger.
- **Give a `-p` run a timeout.** Observed once, on the pre-skills build: the process printed its complete
  answer and then stayed alive at 0% CPU twelve minutes later. There is no `-o/--output-last-message`
  equivalent to read a result from, so a caller waiting on process exit rather than on output hangs. Not
  reproduced on `2026.09.08-6caf4ff`, where every run exited `0`.

### What is different from Claude Code — the honest list

1. **Roughly thirty characters of a description survive, and that is not a shorter Codex.** Asked for the
   length of one, a session answered *"The description text is 30 characters long"* — the description dies
   inside its own first clause, taking the trigger, the invocation spelling and every never-clause with it.
   **Do not shorten a description to fit this**: there is no length that survives, the other two surfaces
   keep the tail, and a thirty-character description would be worse everywhere and no better here. What
   follows instead is that **on Cursor the skill `name` does almost all of the routing work.**
2. **The name space is flat, global and shared.** It is not only your repository's `.cursor/skills/`: on
   this host one listing carried the thirty-nine mirrored skills **plus** Cursor's own built-ins **plus**
   this host's Claude Code plugin skills, `build` and `drive` among them. Hatsu claims thirty-nine ordinary
   words at once — `build`, `file`, `en`, `ao`, `ren`, `breath`. **The shadowing itself is inferred, not
   proven, and is written here as such**: two probes tried to confirm it and could not, because the
   descriptions this surface keeps are far too short to tell two rival `build` entries apart. It is a
   documented hazard, not a documented mechanism — and the warm-up's collision listing cannot see it,
   because it lives outside your repository entirely.
3. **No turn-end hook.**
4. **`$CLAUDE_PLUGIN_ROOT` is not this surface's variable**, and may point at another plugin. Use
   `$HATSU_PLUGIN_ROOT`.
5. **`--model` is Cursor-native only.** The CLI will accept a provider model; the policy will not.
6. **A mirrored persona keeps its `model:` pin verbatim**, which may name a model this surface cannot
   resolve — reported and substituted, never silently either way.
7. **One half is still unverified**: which repository a mirror's relative `../../../nen/workflow.json`
   lands in **through a symlink** was not re-tested here. The rule that carries it is the one the warm-up
   states — **read the file in the repository the session is standing in**, and where it has none, say so
   and use the defaults rather than falling back to this plugin's copy.

---

## The gates

Hatsu drives work **to** a gate and stops there. **One gate is partially delegated, and exactly
one**: `CON-25` names four exhaustive carve-outs under which *release into build* — applying the
building stage label — may be crossed without a per-issue confirmation, inside a named run that
logs every application and lapses when the run ends. **Every other gate in the table below is
yours, without exception.** Clause ids are the inherited constitution's, kept stable across the
rewrite; [`docs/ROSTER.md`](docs/ROSTER.md) carries the same table.

| Gate | Clause | Delegable? |
|---|---|---|
| **G1 — Epic approval** — the human applies one delivery-mode label | `CON-4` | **Never** |
| **G1-M — Release into build** — applying the building stage label | `CON-25` | **The one delegated crossing** — only under `CON-25`'s four exhaustive, named carve-outs |
| **G2 — Merge to `main`** | `CON-5` | **Never** by these agents. No agent here merges `main`, or its own PR anywhere. |
| **G3 — Release go/no-go** | `CON-6` | **Never.** Preparing a release is allowed; publishing is not. |
| **G4 — Policy / spec change** | `CON-7` | **Never** |
| **G5 — Anything else human-only** | `CON-47` | **Never** — its definition *is* "the decision is yours" |

**No agent in this roster casts a `request_changes` review — for any reason, on any PR.** They run on your
credentials, so GitHub records the vote as **yours**, and casting one manufactures your governance vote on a
PR you have not read. The substitutes are a wake label (for findings an automated reviewer already delivered)
and a filed issue (for a substantive finding of the agent's own).

---

## Contributing

### A change to a shipped surface needs a version bump

Claude Code keys its plugin cache on `.claude-plugin/plugin.json`'s `version`. Change a plugin-shipped
surface without bumping that field and the change is real in the repository and **invisible on every machine
that already has the plugin installed** — no error, no warning, the fix ships to nobody.

[`scripts/plugin_bump_check.sh`](scripts/plugin_bump_check.sh), wired as the
[`plugin-bump-check`](.github/workflows/plugin-bump-check.yml) workflow, fails a PR that tries. The guarded
surface is `.claude-plugin/**`, `claude/**`, `nen/**`, `contracts/**`, `docs/ROSTER.md`,
`docs/delegation-grammar-DRAFT.md`, `hooks/**`, `templates/**`, `surfaces/**` and `.mcp.json` — everything an
installed copy reads, the generated Codex and Cursor mirrors included, because the warm-up reads those out of
`$CLAUDE_PLUGIN_ROOT` at run time. Bump
`version` (patch for wording, minor for behaviour or a new skill, major for a breaking interface change —
which the minor carries while Hatsu is on `0.x`, SemVer clause 4, the reading applied to nen's own line);
or, if a change provably cannot affect the shipped surface, write `no plugin bump: <reason>` in the PR
body. Recorded refuse/pass transcripts: [`docs/ab/plugin-bump-guard.md`](docs/ab/plugin-bump-guard.md).

**The check is required on `main`** by the repository ruleset *main: plugin-bump guard required*
(`enforcement: active`), so a failing `plugin-bump-check` blocks the merge. What that ruleset does not do
is protect `.github/**`: GitHub runs a same-repo PR against that PR's *own* workflow definition, so a PR may
still edit the workflow and be judged by the edited version. Closing that is a further repo-settings act —
a human gate, recommended rather than performed here: protect `.github/**` with a ruleset or `CODEOWNERS`.

### Validate locally

```sh
claude plugin validate . --strict
scripts/surface_mirror_check.sh   # the Codex/Cursor mirrors match their source
```

The second writes nothing and needs no credential. **At the pinned `v0.7.0` it runs the real check** —
`codex ok: 40`, `cursor ok: 47`, exit `0`. It exits `2` — saying so, rather than passing — when the `nen` on
your `PATH` has no `surface` verb, which at this pin means the binary is not the pinned one; see
[`docs/SURFACES.md`](docs/SURFACES.md) § 4.

---

## License

**MIT** — see [`LICENSE`](LICENSE).
