# Surfaces

**Hatsu is authored once, for Claude Code, and mirrored onto three other agent surfaces: Codex, Cursor, and Antigravity.** This file is the
authority on what that means: which surface reads what, how a skill is spelled on each, which files in this
repository are *written* and which are *generated*, the commands that regenerate them, the check that
fails a pull request when they drift, and the exact headless invocation that runs Hatsu on each surface for
a validation pass.

Nothing here is a port. The mirrors are the same skill bodies, byte for byte, with the frontmatter reduced
to the keys each surface documents and the invocation respelled — produced by
[`nen surface mirror generate`](https://github.com/zheref/nen) and `scripts/antigravity_mirror_sync.sh`.

---

## 1 · The four surfaces

| | **Claude Code** | **Codex** | **Cursor** | **Antigravity** |
|---|---|---|---|---|
| how Hatsu arrives | **installed as a plugin** — `claude plugin install hatsu@hatsu` | the bootstrap first copies `hatsu-warmup`; the discovered warm-up refreshes the target every session | the bootstrap first links `hatsu-warmup`; the discovered warm-up refreshes the target every session | **dual modality** — installed as a plugin (`~/.gemini/config/plugins/hatsu`), or bootstrapped into `.agents/` |
| skills read from | `$CLAUDE_PLUGIN_ROOT/claude/skills/<name>/SKILL.md` (`plugin.json` → `skills`) | `<repo>/.agents/skills/<name>/SKILL.md` | `<repo>/.cursor/skills/<name>/SKILL.md` | `~/.gemini/config/plugins/hatsu/<name>/SKILL.md` or `<repo>/.agents/skills/<name>/SKILL.md` |
| personas read from | `claude/agents/<persona>.md` (`plugin.json` → `agents`) | `<repo>/AGENTS.override.md`, **as prose** — an **untracked** file that *replaces* the target's own `AGENTS.md` in the envelope, so the target's `AGENTS.md` is copied into it verbatim first. No per-persona file exists on this surface | `<repo>/.cursor/agents/<persona>.md` — one markdown subagent file each | `~/.gemini/config/plugins/hatsu/rules/AGENTS.md` & `agents/` (plugin) or `<repo>/.agents/rules/AGENTS.md` (bootstrap) |
| invocation spelling | **`hatsu:<name>`** | **`$<name>`** — and see *What Codex advertises* below: the install mechanism decides whether the name it lists is bare or namespaced | **`/<name>`** | **`/<name>`** (slash commands) |
| frontmatter kept on a skill | everything Claude Code documents | `name`, `description` — the page documents no other key | `name`, `description`, `paths`, `globs`, `disable-model-invocation`, `icon`, `color`, `metadata` | `name`, `description` |
| turn-end hook | **yes** — `Stop`, `hooks/hooks.json` | **no** | **no** | **yes** — `Stop`, `hooks.json` or `.agents/hooks.json` calling `./hooks/stop-bell.sh` |
| in-session subagent | **yes** — the Agent tool | **yes** — `spawn_agent` / skill-requested delegation (ChatGPT app, CLI, IDE). Hanten's isolated reviewer still uses a second `codex exec` in a worktree because that reviewer must not share the author's tree | **yes** — `.cursor/agents/` | **yes** — `invoke_subagent`; `Workspace` is `inherit`, `branch`, or `share` |
| native option picker | **`AskUserQuestion`** | **`request_user_input`** — ChatGPT app can collect multiple answers on one question; CLI TUI is exclusive per question | **`AskQuestion`**, `allow_multiple` | **`ask_question`**, `is_multi_select` |
| reviewer tier → alias (`models.roles.reviewer` = `deep`) | `opus` | `sol` | `grok` — **Cursor-native only** | **`pro`** (Gemini Pro) |
| minimum CLI build | n/a — the plugin loader is the harness | **not established** — no skills-support floor is known for this surface. The build every record here was made on is **`codex-cli 0.149.0`** (`codex --version`, read live on 2026-09-10), and it is a *validated* build rather than a minimum | **`2026.01.*`** — below it the surface sees NO skills (below) | Antigravity IDE / 2.0 / `agy` CLI |
| signing in | the harness's own | `codex login`; `codex login status` answers `Logged in using ChatGPT` (read live on 2026-09-10) | `cursor-agent login`; `cursor-agent status` answers `✓ Logged in as <account>` | Google AI login (`agy login` / Google Cloud ADC; Pro or Ultra subscription) |

The two consequences that are not cosmetic have their own homes:
[`claude/skills/jutaisho/SKILL.md`](../claude/skills/jutaisho/SKILL.md) § 6 for the missing `Stop` hook on Codex and Cursor, and
[`claude/skills/hanten/SKILL.md`](../claude/skills/hanten/SKILL.md) § 9a for how a reviewer is isolated on each surface. Codex **does** spawn in-session subagents (`spawn_agent`); Hanten still uses a second `codex exec` when the reviewer must not share the author's tree.

### First-run discovery is a bootstrap, not an environment variable

`HATSU_PLUGIN_ROOT` names an already-obtained checkout. It cannot make an undiscovered skill callable, so
Codex and Cursor need one explicit command before their first `$hatsu-warmup` or `/hatsu-warmup`:

```sh
# Run from the target Git repository after cloning Hatsu and exporting HATSU_PLUGIN_ROOT.
surface='<codex or cursor — the host you are opening>'
"$HATSU_PLUGIN_ROOT/scripts/surface_bootstrap.sh" --surface "$surface" --target . --bootstrap
```

The command seeds **only** `hatsu-warmup` in the host's discovery directory: Codex receives a copy at
`.agents/skills/hatsu-warmup/`; Cursor receives a symlink at `.cursor/skills/hatsu-warmup/`. Restart or
open the host in the target repository, then invoke that now-discoverable skill. Its every-session refresh
calls the same bootstrap with `--install-all` to place the complete generated surface.

Both modes preserve the warm-up's existing rules: a tracked destination or one not made by Hatsu is left
untouched; paths Hatsu creates are recorded only in Git's `info/exclude`; `.gitignore` is never edited.
The executable fixture check starts two empty Git repositories, proves the seed is at each discovery path,
then performs the full refresh, idempotence pass, collision check and tracked-file check:

```sh
scripts/surface_bootstrap_fixture_check.sh
```

> **A persona on Codex is prose, and prose does not win an identity argument with the host.** On Claude
> Code a persona is a distinct agent object with its own file; on Codex it is one block inside an
> instruction document that sits **beside — and below — the user's own instruction layer**, so a host whose
> user-level instructions say *"introduce yourself as X"* keeps saying X. Observed live on this host: every
> `codex exec` run opened *"Happy here…"* while doing the work as Kurapika, in Kurapika's discipline
> (`docs/ab/surfaces.md` § 7, F11). **So the name in a Codex transcript is not evidence the persona
> loaded, and it is not evidence it did not.** The record of who acted is the one Hatsu writes: `--who` on
> `nen stop`, the `who` field of `.nen/last-stop.json`, and the `Hatsu-Agent` trailer — all three carry
> the persona regardless of what the surface calls itself.

### The invocation spelling is the mirror's, not yours to type into a source file

Every `hatsu:<name>` mention in a skill body — including the one in its own `description` — is rewritten by
the generator into that surface's spelling, because `--invocation-prefix hatsu:` tells it what this
repository's namespace looks like. **`hatsu:` is caller data**, passed on the command line; nen hard-codes
no system's vocabulary. So `hatsu:rasengan` in the source reads `$rasengan` on Codex and `/rasengan` on
Cursor, and a reader of either mirror is told to type something that actually works there.

### What Codex advertises, and why the install mechanism decides it

**Codex lists a skill under its frontmatter `name`, namespaced by the plugin manifest above the directory
the path RESOLVES to.** Verified on this host with three controlled `codex debug prompt-input` renders in a
throwaway repository — no model called (`docs/ab/surfaces.md` § 7, F1):

| how `<repo>/.agents/skills/<name>` was made | Codex lists it as |
|---|---|
| `cp -R` of a mirror directory | **`ren`** — bare |
| symlink to a directory under no plugin root | **`breath`** — bare |
| symlink into this checkout, which carries `.claude-plugin/plugin.json` (`"name": "hatsu"`) | **`hatsu:aka`** |

So a symlink install is namespaced by the *plugin* it points into, exactly the way an installed plugin's
skills are (`bankai:build`), and the `$<name>` spelling the mirror bodies carry is then not what the
surface shows. **That is why the Codex install is `cp -R` and not a symlink** — see
[`claude/skills/hatsu-warmup/SKILL.md`](../claude/skills/hatsu-warmup/SKILL.md) § 5a, which re-copies every
session so the copy is refreshed rather than left to rot.

### Codex shortens the descriptions, and the budget is shared

Codex prints, at session start:

```text
warning: Skill descriptions were shortened to fit the skills context budget. Codex can still see every
skill, but some descriptions are shorter. Disable unused skills or plugins to leave more room.
```

**The cut length is not a constant — it is one budget divided across every skill the session can see**, so
it moves with what else is installed. Measured on this host from the `prompt-input` renders
(`docs/ab/surfaces.md` § 7, F7): with **51** skills visible the longest surviving description was **411**
characters; with **87** visible (39 mirrored Hatsu skills plus this host's other plugins) every Hatsu
description was cut to **186–190** characters, mid-clause — `hatsu:ren`'s ended at *"Use when "*.

**Hatsu cannot fix this by shortening a description to fit, because there is no number to fit inside.** The
rule is an authoring one, in [`docs/`](../README.md)'s own convention: **lead every `description` with what
the skill does, then its trigger, then its never-clauses, inside the first ~180 characters** — everything
after that is what this surface throws away, and the clause naming the invocation and the refusals is
exactly the part a model-invocation decision is made from. A long tail is still worth writing for the two
surfaces that keep it; it is not worth *relying* on here.

### Cursor has a MINIMUM `cursor-agent` version, and below it every Hatsu skill is silently absent

**A `cursor-agent` that predates skills support answers your prompt, runs your commands, exits `0` —
and has not loaded one of the forty-two.** With the mirror installed exactly as
[`hatsu-warmup`](../claude/skills/hatsu-warmup/SKILL.md) § 5b mandates, `2025.09.18-39624ef` answered
a discovery probe with the whole reply **`NO SKILLS VISIBLE`**, seventeen bytes. The controlled
fixture that followed is what settles it: the same build cannot see a **`cp -R` copy** either, and it
reached its answer by `Searched files (**/*zzcopyprobe*)` — it was grepping the working tree, having
no skills mechanism at all (`docs/ab/surfaces.md` § 8, F2).

**That nearly became a false finding against the symlink row.** The natural reading of the first
probe was *"Cursor does not follow symlinks"*, which is wrong: on `2026.09.08-6caf4ff` a symlink
inside the workspace, a symlink pointing **outside** it, and a copy are all discovered
(`docs/ab/surfaces.md` § 8, § 1.4 P3–P5). The variable was the **binary**, not the install.

| | |
|---|---|
| **the minimum** | **`2026.01.*`** — [Cursor's CLI changelog](https://cursor.com/docs/cli/changelog) dates *"Skills, rules, and commands in the CLI"* to its **January 2026** entry |
| **how exact it is** | the changelog groups by **month**, not by build id, and `cursor-agent -v` prints `YYYY.MM.DD-<sha>` — so the floor is a month and there is no exact version string to pin. Compare the date part |
| **the build that demonstrably SAW the mirror** | `2026.09.08-6caf4ff` — all 39 listed, bare |
| **the build that demonstrably saw NOTHING** | `2025.09.18-39624ef` — *pre-skills*. Where `docs/ab/surfaces.md` § 3.3 records it, that is what it is: **not** a reference build |
| **later, and worth having** | `.cursor/skills` in subdirectories (May 2026); skills discovered through symlinks, stated by Cursor (June 2026) |

**So the warm-up prints `cursor-agent -v` beside the install count and refuses to claim the surface
below the minimum** ([`hatsu-warmup`](../claude/skills/hatsu-warmup/SKILL.md) § 5b). *A surface whose
skills are invisible must be reported, not inferred* — an install that succeeded onto a build that
cannot read it is the exact shape of an unperformed step reported as a passing one.

### Cursor's skill name space is FLAT, GLOBAL and shared — and a collision silently wins

**Cursor lists a mirrored skill under its bare frontmatter `name`** — no plugin namespacing, even
through a symlink into this checkout, which carries `.claude-plugin/plugin.json` (`"name": "hatsu"`).
That is good news and it answers half of § 5b's open question: **Codex's F1 does not reproduce on
Cursor**, and the mirrors' `/aka` spelling is honest here (`docs/ab/surfaces.md` § 8, § 1.4 P4).

**The cost of bare names is that there is no namespace left to disambiguate with**, and the space a
Cursor session sees is not just the repository's `.cursor/skills/`. On this host one listing carried
the 39 mirrored skills **plus** Cursor's own built-ins from `~/.cursor/skills-cursor/` (`autopilot`,
`create-hook`, `loop`, `review-bugbot`, …) **plus this host's Claude Code plugin skills** — the
`adobe-*` family, `ui-ux-pro-max`, `slides`, and decisively **`build`** and **`drive`**, both of which
sit at `~/.claude/plugins/marketplaces/bankai/claude/skills/`. `drive` is not a Hatsu skill at all; it
was renamed to `sharingan` at v0.5.0 and `surfaces/cursor/drive` does not exist.

**On Claude Code this cannot happen** — `hatsu:build` and `bankai:build` are distinct names, which the
Codex-half record called *"luck rather than design"*. **On Cursor the luck runs out.** The names Hatsu
claims that are ordinary enough to collide with somebody: **`build`, `file`, `en`, `ao`, `ren`,
`breath`**, and forty-two are claimed at once.

> **The shadowing itself is INFERRED, not proven, and it is written here as such.** The evidence is
> one listing's grouping and one alphabetical gap — `build` appeared once, outside the Hatsu block's
> otherwise unbroken run (`…, breath, en, file, …`), grouped with the bankai/adobe cluster. **Two
> probes tried to confirm it and could not**, because the descriptions the surface keeps are far too
> short to tell the two rival `build` entries apart (below). Confirming it needs a different method:
> the mirror installed on a host with **no** bankai plugin, or the surface asked to *run* `/build` and
> watched for whose procedure it follows. **Until then this is a documented hazard and not a
> documented mechanism** — but the flat name space is real, measured, and the reason the skill `name`
> is doing nearly all the routing work here.
>
> [`hatsu-warmup`](../claude/skills/hatsu-warmup/SKILL.md) § 5c's `ours` guard **cannot help with
> this**: it inspects the target repository, and this collision is entirely outside it. What the
> warm-up can do, and now does, is **list every name already standing under `.cursor/skills/` before
> it installs anything** — and say plainly that a host-level collision it cannot see may still win.

### Cursor keeps roughly THIRTY characters of a description — and that is not a shorter Codex

`docs/ab/surfaces.md` measured Codex cutting descriptions to 186–190 characters and this file draws
an authoring rule from it (below). **On Cursor the surviving text appears to be an order of magnitude
shorter.** Three probes with the full 39-skill mirror installed (`docs/ab/surfaces.md` § 8, F13):
asked for the first fifteen words of `/ren`'s description, the session returned **six** and
volunteered that the text was truncated; asked whether `build`'s description mentions Ichigo or
Kurapika — the two names that sit near character 190 in the rival copies — **neither**; asked for the
length, **"The description text is 30 characters long; its final 10 characters are `whereve…`"**.

Thirty characters is `Take one issue from whereve…`. **The description dies inside its own first
clause**: the trigger, the invocation spelling and every never-clause are gone. Codex at least keeps
the opening sentence.

**Two caveats, and they are why no number is being written into the authoring rule.** It is the
model's self-report — Cursor has no `codex debug prompt-input` equivalent, so there is no way to see
what it was actually handed — and if the budget is *shared* across visible skills the way Codex's is,
~30 characters is a symptom of ~70 skills being visible on this host rather than a constant. It needs
measuring against a varying skill count before it is a number.

**So: do not shorten a description to fit this.** There is no length that survives here, the two other
surfaces keep the tail, and a description trimmed to thirty characters would be worse everywhere and
no better on Cursor. What follows from it instead is that **on Cursor the skill `name` is doing almost
all of the routing work** — an argument for keeping the names distinctive, and the second reason the
flat name space above matters.

### One honest limitation of a verbatim mirror

The bodies carry **relative links written for this repository's layout** — `../rikugan/SKILL.md`,
`../../../docs/SURFACES.md`. Inside a target repository's `.agents/skills/` (a `cp -R`) a sibling link like
`../rikugan/SKILL.md` still resolves — to the sibling copy — while `../../../docs/SURFACES.md` resolves to
`<target>/docs/SURFACES.md` and dangles. That is the price of "the body verbatim", it is deliberate, and it
is stated rather than papered over: the mirrors are for an agent reading a skill, not for a human browsing
a link tree.

> **A link that RESOLVES into the plugin is more dangerous than one that dangles, and this is the second
> reason the Codex install is a copy.** Through a symlink, `../../../nen/workflow.json` resolved to
> **`<plugin checkout>/nen/workflow.json`** — Hatsu's own policy file — so an agent told to read the model
> matrix "from `nen/workflow.json` and never from memory" read the wrong repository's policy with no error
> anywhere. Through the copy the same path resolves to `<target>/nen/workflow.json`, which is the file that
> was meant. Both resolutions verified live (`docs/ab/surfaces.md` § 7, F10). A dangling link is an agent
> that reports it could not read something; a link into the plugin is an agent that answers confidently
> from the wrong file.

---

## 2 · Generated versus authored

| Path | |
|---|---|
| `claude/skills/<name>/SKILL.md` | **authored.** The one source. |
| `claude/agents/<persona>.md` | **authored.** The one source. |
| `surfaces/codex/<name>/SKILL.md` | **generated** — 43 files (the counted forty-two plus `hatsu-warmup`) |
| `surfaces/codex/AGENTS.md` | **generated** — every persona as a `## <name>` section, 1 file |
| `surfaces/cursor/<name>/SKILL.md` | **generated** — 43 files (the counted forty-two plus `hatsu-warmup`) |
| `surfaces/cursor/agents/<persona>.md` | **generated** — 9 files |
| `surfaces/antigravity/<name>/SKILL.md` | **generated** — 43 files (the counted forty-two plus `hatsu-warmup`) |
| `surfaces/antigravity/rules/AGENTS.md` | **generated** — all personas in unified rules document |
| `surfaces/antigravity/agents/<persona>.md` | **generated** — 9 subagent definitions |
| `surfaces/antigravity/plugin.json` | **generated** — Antigravity plugin manifest |
| `surfaces/antigravity/hooks.json` | **generated** — lifecycle hooks (`PreToolUse` and `Stop`) |

**Every generated file carries a marker, and it is the first *markdown* line rather than the first line of
the file:**

```text
<!-- GENERATED by nen surface mirror (surface: codex) -- do not edit; edit the source and regenerate -->
<!-- GENERATED for surface: antigravity -- do not edit; edit the source and regenerate -->
```

It sits immediately after the closing frontmatter fence, because all surfaces identify a skill by
YAML frontmatter **at the start of the file** — a banner above the fence would buy a "do not edit" notice at
the price of the document loading at all. In `AGENTS.md`, which has no frontmatter, it is line 1.

**Edit the source, never the mirror.** A hand edit to a generated file is not merely overwritten on the next
run; it is *reported* by the check below, by name, as `hand-edited`.

### What the warm-up PLACES in a target repository, per surface

Moved here on 2026-09-20 (zheref/hatsu#89) from `hatsu:hatsu-warmup` § 5, which duplicated it; the
skill now keeps one line per surface pointing at this table.

| Surface | What is placed | By which script | Excluded how |
|---|---|---|---|
| **Claude Code** | the permission pack only — the plugin is read in place from `$CLAUDE_PLUGIN_ROOT` | `scripts/permissions_pack.sh --surface claude-code --install --target <t>` | `info/exclude` |
| **Antigravity, global plugin** | **nothing**; the plugin is read from `${GEMINI_CONFIG_DIR:-~/.gemini}/config/plugins/hatsu` | — | — |
| **Codex** | `.agents/skills/<name>/` by **`cp -R`** per directory, `AGENTS.override.md`, the pack | `scripts/surface_bootstrap.sh --surface codex --target <t> --install-all`, then the pack | `info/exclude` |
| **Cursor** | `.cursor/skills/<name>/` and `.cursor/agents/<persona>.md` by **symlink**, the pack | the same, `--surface cursor` | `info/exclude` |
| **Antigravity, workspace mode** | `.agents/skills/`, `.agents/rules/AGENTS.md`, `.agents/hooks.json`, `.agents/hooks/`, the pack | the same, `--surface antigravity` | `info/exclude` |

**The permission pack is placed on every surface, Claude Code included** (rulings of 2026-09-19),
rendering `contracts/permissions.json` — the commands the skills actually run, scoped to this
repository, its worktrees and its declared associated repositories — into
`.claude/settings.local.json` (merged, **never** the tracked `.claude/settings.json`),
`.codex/config.toml` + `.codex/hooks.json`, `.cursor/cli.json` + `.cursor/hooks.json`; on Antigravity
it is the generated hooks only, because a persona-wide `commandExecutionPolicy: auto` would approve
arbitrary commands rather than the declared set. **A file the script did not write is left alone and
named**, and the warm-up's report says what was placed or left alone — never "nothing installed" on a
run where the pack wrote.

**Ownership at each destination.** An exclude governs **untracked** paths only, so a target that
tracks a destination keeps it tracked and an `ln -sfn` or `rm -rf` over it destroys a file in
somebody's history. Nothing there → create it. **A previous Hatsu install** — a symlink into
`<hatsu root>/surfaces/`, or a directory whose `SKILL.md` carries the `GENERATED` marker above → replace
it. **Anything else, and a TRACKED path is always anything else** → leave it untouched, install
nothing under that name, and name it in the report. **A skipped name is reported, never swallowed,
and this takes precedence over the refresh**: the warm-up would rather install thirty-eight of forty
and say so than overwrite one file it did not write.

```sh
# ours DEST — true only for a destination the warm-up made. Tracked is NEVER ours: a repository's own
# history outranks a marker comment.
ours() {
  git -C "$target" ls-files --error-unmatch -- "$1" >/dev/null 2>&1 && return 1
  [ -L "$1" ] && case "$(readlink "$1")" in "$hatsu_root"/surfaces/*) return 0 ;; esac
  grep -qsE 'GENERATED (by nen surface mirror|for surface: antigravity)' "$1/SKILL.md" "$1" 2>/dev/null
}
if { [ -e "$dest" ] || [ -L "$dest" ]; } && ! ours "$dest"; then kept="$kept $name"; continue; fi

exclude="$(git -C "$target" rev-parse --git-path info/exclude)"   # NEVER "$(rev-parse --git-dir)/info/exclude"
for line in '.agents/skills/' 'AGENTS.override.md' '.cursor/skills/' '.cursor/agents/'; do
  grep -qxF "$line" "$exclude" 2>/dev/null || printf '%s\n' "$line" >> "$exclude"
done
git -C "$target" status --porcelain      # must print nothing for these paths
```

**On Codex, the sandbox must be able to write git BEFORE a warm-up reports clear.** A linked worktree
keeps `HEAD`, the index, the objects, `refs/` **and `info/exclude`** under the main repository's
`.git/`, outside a `workspace-write` sandbox, so every git write the placement above needs — and every
one [`breath`](../claude/skills/breath/SKILL.md) and [`aka`](../claude/skills/aka/SKILL.md) need after
it — is refused with *"Operation not permitted"* at exit `128`. The session must have been launched
with `--add-dir "$(git -C <repo> rev-parse --path-format=absolute --git-common-dir)"`, or against a
standalone clone whose `.git` is inside the workspace. **A skill cannot add the flag to a session
already running: it reports the condition and stops**, naming the flag, rather than writing half an
install into a checkout that cannot commit it.

**`--git-path`, never `--git-dir`** — in a linked worktree the latter names a file git never reads for
excludes — and that file is **per-repository**, shared by every worktree and the primary checkout, so
the report names it by path rather than describing it as local to one directory. Prove it took with
`git status --porcelain`, and `git check-ignore -v <one path>` when it did not come back clean.
**Never write a target repository's `.gitignore`**: it is a tracked file that lands in their diff,
their review and their history, and imposes this plugin's layout on every contributor — a hard limit,
not a preference. And **`AGENTS.override.md` is excluded while a tracked `AGENTS.md` is never written:
those two sentences are one rule**, because an unexcluded untracked file makes `nen shu warmup` refuse
at exit `2` on a path it did not put there, which stops `breath` and `aka`.

**`AGENTS.override.md` REPLACES the target's `AGENTS.md` rather than joining it**, so the warm-up
writes the *whole* document: the target's own `AGENTS.md` **verbatim, re-read every warm-up and never
cached**, then the generated block between its two markers (a target with none gets the block alone).
**A tracked `AGENTS.md` is never written, appended to or touched**, and nothing outside the markers is
the warm-up's to write. **The Codex re-copy is unconditional** — `rm -rf` then `cp -R`, every session —
and **never diff-and-skip**: a hand-edited copy inside the target is drift to overwrite. **`.nen/` is
never a mirror destination**: proof files, En loop ledgers, the stop marker and Hanten's cycle ledger
live there and must survive a warm-up, or reviewer budgets and En caps reset.

---

---

## 3 · Regenerating

Commands run from the repository root:

```sh
nen surface mirror generate --source claude/skills --agents claude/agents \
  --surface codex  --out surfaces/codex  --invocation-prefix "hatsu:"

nen surface mirror generate --source claude/skills --agents claude/agents \
  --surface cursor --out surfaces/cursor --invocation-prefix "hatsu:"

bash scripts/antigravity_mirror_sync.sh
```

Each writes only the files whose bytes actually changed, deletes an orphan whose source is gone, and
**refuses at exit 2 to overwrite any file that does not already carry the marker** — which is what keeps a
hand-written file safe from an `--out` pointed one directory too high.

**Run this whenever a `SKILL.md` or an agent definition changes**, in the same commit. That is the whole
discipline; the check exists because "in the same commit" is a thing people forget.

> **RETIRED at nen `0.5`: `nen surface` IS in the pinned binary.** It answered *"nen: unknown command
> 'surface'"* at exit `2` through `v0.4.0` (transcript: [`docs/ab/surfaces.md`](ab/surfaces.md) § 2.3); at the
> pinned build both `mirror generate` and `mirror check` run, and the mirrors committed here were last
> regenerated with `v0.8.0`. **Using them still needs nothing** — they are files in this repository — and
> regenerating them now needs only the pinned nen.

---

## 4 · The check

[`scripts/surface_mirror_check.sh`](../scripts/surface_mirror_check.sh) runs `nen surface mirror check` for
both surfaces with whichever `nen` is on `PATH` and writes nothing at all:

```sh
scripts/surface_mirror_check.sh
```

| Exit | Meaning |
|---|---|
| `0` | both mirrors are byte-identical to a fresh generation |
| `1` | **drift** — the offending files are listed, per surface, in nen's four classes: `missing`, `extra`, `stale` (generated for the *other* surface), `hand-edited` |
| `2` | the `nen` on `PATH` **has no `surface` verb** — said in those words, with the pinned ref that would supply it. Never silently passed |
| `3` | there is no `nen` on `PATH` at all |

Exit `2` matters more than it looks. A check that treated a missing verb as "nothing to check" would report
a clean mirror on every machine running the pinned nen — the exact shape of an unperformed check reported as
a passing one, which is the failure `nen/contract.json` § `no_improvised_fallback` and the plugin-bump guard
both exist to prevent.

**It is a documented step of the loop, not a second lint.** [`nen/contract.json`](../nen/contract.json)'s
`plugin` lane keeps exactly one `lint` seat — `claude plugin validate . --strict` — and
[`nen/workflow.json`](../nen/workflow.json)'s `iteration.checks` keeps exactly that one entry.
[`docs/WORKFLOW.md`](WORKFLOW.md) § 2 → `iteration` says where this check runs instead: beside the
regeneration, in `mukai`, before `shibari` opens the PR.

### In CI

[`.github/workflows/surface-mirror-check.yml`](../.github/workflows/surface-mirror-check.yml) bootstraps nen
**at the ref `nen/contract.json` pins**, then runs the script. **At the pinned build that is a real
check**: the pinned nen carries the verb, so the job regenerates in memory and fails on drift.

Through `v0.4.0` it **skipped with a `::notice::` and passed**, naming the pin and what would change — a job
that failed every PR until an unrelated repin merged would have been turned off within a week. The skip was
decided by the script's own exit `2` precisely so that it would disappear with no edit to the workflow, and
that is what happened. **That branch is now an error rather than a skip**: at a pin that carries the verb,
exit `2` means the pin or the bootstrap is wrong, which is a thing to report and never to pass through.

The job is **advisory** until the maintainer lists the `surface-mirror-check` context in a repository
ruleset. Renaming the job silently un-requires it.

---

## 5 · A validation run, headless, on each surface

These are the commands, and both `--help`s were read on this host before they were written down
([`docs/ab/surfaces.md`](ab/surfaces.md) § 3.4, § 3.5).

### Codex

```sh
# the deep tier's id AS THE HOST SPELLS IT TODAY — resolved, never remembered (see below)
sol="$(codex debug models | grep -o '"slug":"[^"]*sol"' | cut -d'"' -f4)"
[ -n "$sol" ] || { echo "codex debug models lists no 'sol' slug" >&2; exit 1; }

codex exec -C <repo> -s workspace-write \
  --add-dir "$(git -C <repo> rev-parse --path-format=absolute --git-common-dir)" \
  -m "$sol" "<prompt>"
```

Codex native picker is **`request_user_input`** (`questions` 1–3, `isBlocking`). The ChatGPT app
collects multiple ticked answers on one question; the CLI TUI selects one option per question.
In-session delegates are **`spawn_agent`** (skill-requested delegation is a documented trigger).
Hanten still uses the `codex exec` form above, in a worktree, when the reviewer must not share the
author's tree.

> ### ⚠️ `--add-dir` is not an optimisation. Without it a LINKED WORKTREE cannot commit at all.
>
> `-s workspace-write` makes the **workspace** writable, and in a linked git worktree essentially all of
> git's own state lives outside the workspace:
>
> | what | where it lives | inside `-C <worktree>`? |
> |---|---|---|
> | `HEAD`, `index`, `FETCH_HEAD`, `ORIG_HEAD` | `<main repo>/.git/worktrees/<name>/` | **no** |
> | objects, `refs/`, `packed-refs`, `config` | `<main repo>/.git/` | **no** |
> | `info/exclude` | `<main repo>/.git/info/` | **no** |
>
> So `git fetch`, the branch cut, `git commit`, `git push` and the local exclude are all refused.
> **Reproduced on a constructed fixture on this host, both ways** (`docs/ab/surfaces.md` § 7, F3): the
> command `printf 'y\n' >> a.txt && git add a.txt && git commit -m …`, run by Codex inside a linked
> worktree under `-s workspace-write`, died at exit **`128`** —
> *"fatal: Unable to create `…/.git/worktrees/wt/index.lock`: Operation not permitted"* — and the same
> command with `--add-dir "$(git rev-parse --path-format=absolute --git-common-dir)"` added exited **`0`**
> and produced the commit. Nothing else changed between the two runs.
>
> `--git-common-dir` is the right ref to pass and `--git-dir` is not: in a linked worktree `--git-dir`
> answers `<main>/.git/worktrees/<name>`, which covers `HEAD` and the index and leaves objects, `refs/`
> and `info/exclude` outside. `--path-format=absolute` is passed because the bare form answers relatively
> in a primary checkout (`.git`), and `--add-dir` wants a real path.
>
> **The alternative, and it is a real one: give the Codex session a standalone clone.** A clone's `.git`
> is *inside* the workspace, so `-s workspace-write` alone is enough and no extra root is opened. Prefer
> the clone where the session is disposable; prefer `--add-dir` where the effort must land in the
> maintainer's own repository — which is what [`hanten`](../claude/skills/hanten/SKILL.md) § 9a's reviewer
> worktree is, and § 9a carries this same sentence.
>
> **Whichever is used, `--add-dir` widens the sandbox by exactly one directory and it is a git directory.**
> It is not `--dangerously-bypass-approvals-and-sandbox`, and reaching for that instead — because a git
> write failed — is trading a named, auditable hole for an unbounded one.

- `-C, --cd <DIR>` — the working root. `-s, --sandbox` takes `read-only`, `workspace-write` or
  `danger-full-access`; **`workspace-write` is the one to use** — the session may write inside the
  repository and nothing outside it. `--add-dir <DIR>` adds one more writable root, per the block above.
- `-m, --model` takes a **model id**, and the id is versioned even though the matrix's alias is not.
  `sol` is the tier alias in [`nen/workflow.json`](../nen/workflow.json) → `models.codex.deep`; the id is
  that alias with this surface's current version in front of it.

> **Read the id, never remember it — and the block above resolves it rather than saying so and then
> printing one.** `codex debug models` prints the catalogue as JSON; on this host, today, the whole slug
> list is `gpt-reserve`, **`gpt-5.6-sol`**, `gpt-5.6-terra`, `gpt-5.6-luna`, `gpt-5.5`,
> `gpt-5.3-codex-spark`, `codex-auto-review` (`docs/ab/surfaces.md` § 3.5). **There is no bare `sol` and
> no `gpt-6-sol`** — this section used to carry `-m gpt-6-sol` as the runnable command and the correction
> only in this paragraph, so a reader who copied the block got a failure and a reader who read on got a
> contradiction (Copilot review thread `PRRT_kwDOUKPjxM6hAjNK`). `sol` is the tier alias in
> [`nen/workflow.json`](../nen/workflow.json) → `models.codex.deep`, and the *alias* is all a
> configuration file may carry: `models.rule` is *"latest alias only, never a version"*. The **id** is
> that alias at whatever version the host is serving, which is a live fact and belongs in a command
> substitution — `codex debug models | grep -o '"slug":"[^"]*sol"' | cut -d'"' -f4`, exactly as the block
> does. A command line carrying a remembered id fails on the day the version moves, and it will.
- Add `-o, --output-last-message <FILE>` when something downstream has to read the answer, and `--json` for
  JSONL events.
- The skills must already be in `<repo>/.agents/skills/` — that is the warm-up's § 5a.

#### Answering a G5 stop — `codex exec resume`, which takes almost none of the flags above

A G5 stop is a designed part of every Hatsu run, so a headless validation pass **will** need to answer one.
That is a second invocation, and it is a different command line:

```sh
sol="$(codex debug models | grep -o '"slug":"[^"]*sol"' | cut -d'"' -f4)"   # resolved here too

cd <repo> && codex exec resume --last -m "$sol" --skip-git-repo-check \
  -c 'sandbox_workspace_write.writable_roots=["<extra root>", "<repo git common dir>"]' \
  -o <file> "<the answer>"
```

**`-m` is resolved on the resume exactly as it is on the first invocation.** `resume` is a *new process*
and takes the model on its own command line, so a remembered id fails here for the same reason and at the
worse moment — the run has already stopped at a G5 and the answer is what will not start
(Copilot review thread `PRRT_kwDOUKPjxM6hAjNv`).

**`resume` accepts neither `-C/--cd`, nor `-s/--sandbox`, nor `--add-dir`** — verified on this host, each
refused with *"error: unexpected argument … found"* at exit `2` (`docs/ab/surfaces.md` § 7, F6). Its own
options are `-c`, `--last`, `--all`, `--enable/--disable`, `-i`, `-m`, `--strict-config`,
`--skip-git-repo-check`, `--ephemeral`, `--ignore-user-config`, `--ignore-rules`, `--output-schema`,
`--json` and `-o`. So the two substitutions are fixed and there is no third: **the working root comes from
the shell's own `cd`**, and **every extra writable root — the git common dir above included — comes from
`-c 'sandbox_workspace_write.writable_roots=[…]'`**. A resume that forgets the second one hits F3's
`Operation not permitted` on the turn *after* the stop was answered, which reads like a new failure and is
the old one.

### Cursor

```sh
# the deep/frontier tier's id AS THE HOST SPELLS IT TODAY — resolved, never remembered (see below)
grok="$(cursor-agent models | sed -n 's/^\(cursor-grok-[0-9.]*-high\) - .*$/\1/p' | sort -Vr | head -n 1)"
[ -n "$grok" ] || { echo "cursor-agent models lists no cursor-grok id" >&2; exit 1; }

cd <repo> && cursor-agent -p --output-format text --model "$grok" -f "<prompt>"
```

> ### ⚠️ `--model grok` does not exist. `cursor-agent` refuses it and nothing runs.
>
> This block used to read `--model <cursor-native-alias>`, and `grok` is what a reader substituted.
> Run verbatim on this host (`docs/ab/surfaces.md` § 8, F1):
>
> ```
> $ cursor-agent -p --output-format text --model grok -f "<prompt>"
> Cannot use this model: grok. Available models: auto, gpt-5.3-codex-low, … cursor-grok-4.6-high,
> composer-2.5, …
> ```
>
> **`grok` is the tier ALIAS in [`nen/workflow.json`](../nen/workflow.json) → `models.cursor.deep` /
> `.frontier`, and an alias is all a configuration file may carry** — `models.rule` is *"latest alias
> only, never a version"*. A command line needs the **id** the host is serving today, which is a live
> fact and belongs in a command substitution. This is the same defect this file already corrected for
> Codex, where `-m gpt-6-sol` became a substitution off `codex debug models`; the Cursor block had
> never had the same treatment.
>
> **The catalogue is `cursor-agent models` (equivalently `--list-models`), read live on 2026-09-10 at
> build `2026.09.08-6caf4ff`, exit `0`** — it prints `<id> - <label>`, one per line. The Cursor-native
> rows there today: `cursor-grok-4.6-{low,medium,high,xhigh}[-fast]`, `cursor-grok-4.5-high[-fast]`,
> `composer-2.5[-fast]`. **The alias resolves to the newest `cursor-grok`'s plain `-high`, which the
> catalogue labels with no qualifier at all** — `cursor-grok-4.6-high - Cursor Grok 4.6`, beside
> `-xhigh - Cursor Grok 4.6 Extra High` and `-high-fast - Cursor Grok 4.6 Fast`. The id is a
> **two-axis** choice, version and reasoning tier, so the rule is written down rather than left to
> each caller: **newest version, plain `-high`, never `-fast`**. The `sed` / `sort -Vr` above is that
> rule, executable. `composer` resolves the same way —
> `composer="$(cursor-agent models | sed -n 's/^\(composer-[0-9.]*\) - .*$/\1/p' | sort -Vr | head -n 1)"`
> → `composer-2.5`.
>
> **On the build this file used to record there was no catalogue to read.** `2025.09.18-39624ef`'s
> `--help` listed `-v --api-key -p --output-format -b --resume --model -f` and nothing else — no
> `models` subcommand, no `--list-models` — and the only enumeration available was the refusal message
> itself (`cursor-agent -p --model __resolve__ -f x 2>&1`, which is what the wave-5 run used). That is
> not a second supported way to read the catalogue; it is what a build below the minimum leaves you
> with. **Read § 1's minimum version first.**

- `-p, --print` is the non-interactive form; `--output-format` takes `text`, `json` or `stream-json` and
  **only works with `--print`**. `-f, --force` allows commands unless explicitly denied.
- **`-f` is `--force`, and it is NOT a file flag.** The block reads `-f "<prompt>"` and parses
  correctly only because `-f` takes no value and the prompt is a **positional** argument. The Codex
  block above uses no such adjacency, and a reader copying one line is being invited to misread it —
  so it is said here rather than left to the options list.
- **The working root.** On `2025.09.18-39624ef` there was no working-directory flag at all: the root
  was **the shell's own `cd`**, which is why the block above leads with one. On `2026.09.08-6caf4ff`
  there is `--workspace <path-or-name>` and `--add-dir <path>` (and `-w, --worktree [name]`), read
  live from `--help` on 2026-09-10. **The `cd` form works on both**, and it is what this block keeps.
- **There is no sandbox to widen, and that is a difference rather than an absence.** Codex's whole
  `--add-dir` box above exists because `-s workspace-write` cannot perform a single git write in a
  linked worktree. Cursor has no counterpart to that failure — `-f/--force` allows commands unless
  denied — and a headless run fetched, cut a branch, rebased and first-published inside a **linked
  worktree** with no permission failure of any kind (`docs/ab/surfaces.md` § 8). No `--add-dir`, no
  standalone clone, no workaround.
- **Answering a G5 stop is `--resume`, and it is a FLAG on the same command line.** Unlike
  `codex exec resume` — which accepts almost none of the first invocation's options — `--resume
  [chatId]` sits beside `-p`, `--output-format`, `--model` and `-f`, so a stop is answered with the
  same line plus the id. Fix the id up front with `cursor-agent create-chat`, which prints one (the
  wave-5 run used `dc796003-a2c1-46e3-b867-70dc0a59bf3e`), rather than relying on `--resume`'s
  "latest"; `ls` and `resume` reach the latest when you have not. **The path is unexercised**: no G5
  fired in that run, so `--resume` was never used in anger.
- **Give a `-p` run a timeout.** Observed once, on `2025.09.18-39624ef`: the process printed its
  complete answer and then stayed alive at 0% CPU, still running twelve minutes later. There is no
  `-o/--output-last-message` equivalent to read a result from, so a caller waiting on process exit
  rather than on output hangs. Not reproduced on `2026.09.08-6caf4ff`, where every run exited `0`.
- `--model` is **Cursor-native only** — the `cursor-grok` and `composer` families, per the matrix's own
  note. `cursor-agent models` lists provider ids too (`claude-opus-5-*`, `gpt-5.3-codex-*`,
  `gemini-3.7-*`) and `--help`'s own examples are provider models: the CLI accepts them and **this
  policy does not**. A provider model named here is out of policy, not merely unusual, and the reason
  is in the file — *"provider models there are reserved for Bugbot"*.

> **`cursor-agent` IS logged in on this host, and the first logged-in run has happened.** This block
> used to carry a box saying the opposite. `cursor-agent status` → *"Logged in"*, and a headless
> `/ren` + `/aka` run against a linked worktree of `zheref/nen` completed with no G5 stop, publishing
> a branch and touching neither the primary checkout nor a pull request (`docs/ab/surfaces.md` § 8).
> **What that run verified, corrected and left open** is § 8 of the evidence file; the three facts
> that changed this page are F1 above, § 1's minimum version, and § 1's flat name space.

### Antigravity

Antigravity executes both interactively and headlessly via the `agy` CLI or inside the Antigravity IDE:

```sh
# A headless validation run at the deep tier
agy --model pro "<prompt>"
```

- When running against a repository, Antigravity loads either from the global plugin (`~/.gemini/config/plugins/hatsu`)
  or from `.agents/` inside the repository.
- Lifecycle hooks (`PreToolUse` on `run_command` via `hooks/guard-base-branch.sh`, `Stop` via `hooks/stop-bell.sh`)
  are active natively in both interactive and headless CLI runs.
- Subagents raised via `invoke_subagent` choose a workspace: **`inherit`** (same checkout as the parent — Third-Hand's Netero), **`branch`** (isolated git worktree — Hanten reviewers), or **`share`**.
- They run concurrently in the background without polling.
- Native picker is **`ask_question`**, with `is_multi_select: true` when several options may all be true.

---

## 6 · Updating the plugin source

§ 5 installs whatever `$HATSU_PLUGIN_ROOT` (or Claude's versioned cache) already holds. **Updating that
source is a different question**, and from v0.31.0 it has a checked command rather than a remembered
`git pull`.

```sh
# consumer clone on the trunk (origin/<branch.base>, ff-only)
"$HATSU_PLUGIN_ROOT/scripts/hatsu_plugin_update.sh" --root "$HATSU_PLUGIN_ROOT" --channel trunk

# consumer clone pinned to a release tag — move to the newest vX.Y.Z
"$HATSU_PLUGIN_ROOT/scripts/hatsu_plugin_update.sh" --root "$HATSU_PLUGIN_ROOT" --channel release

# warm-up form: skip (exit 0) when the tree is dirty, on a feature branch, or cannot fetch
"$HATSU_PLUGIN_ROOT/scripts/hatsu_plugin_update.sh" --root "$HATSU_PLUGIN_ROOT" --auto

# Claude Code versioned cache (not a git checkout)
claude plugin marketplace update
claude plugin update hatsu@hatsu -y   # restart required
```

[`hatsu-warmup`](../claude/skills/hatsu-warmup/SKILL.md) § 4b runs `--auto` on every surface, and
`--auto --claude` on Claude Code, **before** § 5 copies or links. `--auto` never discards, never
force-updates a diverged history, and never touches an authoring branch.

The fixture (two throwaway clones, tags, a fake cache, no credential):

```sh
scripts/hatsu_plugin_update_fixture_check.sh
```

README § *Updating Hatsu on each surface* is the per-surface table a human follows after a release.

---


### The warm-up form, and its hard limits

Moved here on 2026-09-20 (zheref/hatsu#89) from `hatsu-warmup` § 4b, which now keeps one paragraph
pointing at this section. The warm-up runs
`scripts/hatsu_plugin_update.sh --root "$hatsu_root" --auto [--claude]` on **every** surface, Claude
Code included, **before** the placement of § 2 reads the source — a checkout that has not moved
installs last month's canon with no error anywhere.

- **`--claude` is added on Claude Code**, so a versioned plugin cache is refreshed through the
  surface's own loader rather than treated as a git checkout it is not.
- **`--auto` is load-bearing.** Without it the script refuses a dirty tree, an authoring branch, a
  missing `origin`, a diverged trunk and a Claude cache; a warm-up must not halt the session for any
  of those, so it **quotes the skip and continues with the checkout it has**. The same command
  *without* `--auto` is how a human asks for a refusal instead of a skip.
- **A skip is reported as skipped, never rendered as updated**, and the script's one-line report is
  quoted verbatim into the warm-up's own line.
- **Hard limits, the same `nen shu warmup` uses on a target repository:** never `--discard`,
  `reset --hard` or a non-fast-forward merge — a diverged consumer checkout is a skip, not a repair;
  never update an authoring branch, a session writing Hatsu not being one consuming it; never treat a
  Claude versioned cache as a git checkout, its refresh being `claude plugin update hatsu@hatsu -y`
  plus a restart; and **a fetch failure under `--auto` is a skip, not a halt.**
- **The first checkout is still a human act** (§ 1's bootstrap); this step only keeps an existing one
  current.

## 7 · Targeting a local checkout

`$HATSU_PLUGIN_ROOT` is the form that works on all four surfaces. Claude Code adds a second hop: it
**copies** that tree into `~/.claude/plugins/cache/hatsu/hatsu/<plugin.json version>/`, so a local
marketplace still needs `claude plugin update hatsu@hatsu` after a version bump. Codex and Cursor do
not copy: they read `$HATSU_PLUGIN_ROOT/surfaces/<surface>/` through the warm-up's copies or
symlinks.

| Goal | Command |
|---|---|
| Claude Code, this clone | `claude plugin marketplace add "$HATSU_PLUGIN_ROOT"` then `claude plugin install hatsu@hatsu`. Confirm `claude plugin list` shows **this tree's** `version`. |
| Codex / Cursor / Antigravity workspace, any product repo | `surface_bootstrap.sh --surface <surface> --target <repo> --bootstrap`, then the surface's warm-up |
| Authoring Hatsu **on Cursor** | `surface_bootstrap.sh --surface cursor --target "$HATSU_PLUGIN_ROOT" --install-all` so `.cursor/skills/` links into **this** `surfaces/cursor/`. Without it, Cursor discovers Claude's versioned cache and serves last-tag prose while you edit current canon. |
| Antigravity global | `ln -sfn "$HATSU_PLUGIN_ROOT/surfaces/antigravity" ~/.gemini/config/plugins/hatsu` |

**The resolver still reads three candidates and no fourth** (`$HATSU_PLUGIN_ROOT`, a handed path,
`$CLAUDE_PLUGIN_ROOT`). Targeting a local tree means putting that tree in `$HATSU_PLUGIN_ROOT` (or
handing it to `/hatsu-warmup <path>`), not adding a fourth probe. A stale `CLAUDE_PLUGIN_ROOT` in a
shell profile is still named when it is rejected.

---

## 8 · Where the pieces live

| | |
|---|---|
| the mirrors | [`surfaces/codex/`](../surfaces/codex/), [`surfaces/cursor/`](../surfaces/cursor/), [`surfaces/antigravity/`](../surfaces/antigravity/) |
| placing them into a target repository | [`claude/skills/hatsu-warmup/SKILL.md`](../claude/skills/hatsu-warmup/SKILL.md) § 5 |
| keeping `$HATSU_PLUGIN_ROOT` / the Claude cache current | [`scripts/hatsu_plugin_update.sh`](../scripts/hatsu_plugin_update.sh); warm-up § 4b |
| pointing a surface at a local checkout | this file, § *Targeting a local checkout* |
| the bell, where there is no hook | [`claude/skills/jutaisho/SKILL.md`](../claude/skills/jutaisho/SKILL.md) § 6 |
| raising a reviewer per surface | [`claude/skills/hanten/SKILL.md`](../claude/skills/hanten/SKILL.md) § 9a |
| the model matrix | [`nen/workflow.json`](../nen/workflow.json) → `models`; [`docs/WORKFLOW.md`](WORKFLOW.md) § 2 → `models` |
| the recorded transcripts | [`docs/ab/surfaces.md`](ab/surfaces.md) |

## 9 · The turn-end bell, per surface

Moved here 2026-09-20 out of [`jutaisho`](../claude/skills/jutaisho/SKILL.md) §§ 5–6, which remains
the bell's only caller; what belongs to a surface is recorded with the other surface facts.

| Surface | Who fires rungs 2–3 | What jutaisho does |
|---|---|---|
| **Claude Code** | `hooks/stop-bell.sh`, off the `.nen/last-stop.json` marker | writes the marker, and stops |
| **Antigravity** (`/jutaisho`) | the same, via the native `Stop` hook | writes the marker, and stops |
| **Codex** (`$jutaisho`) | **the skill itself, in-session** | writes the marker, runs the two commands below, says so, and removes the marker |
| **Cursor** (`/jutaisho`) | the same | the same |

Neither Codex nor Cursor reads hooks or documents a turn-end hook, so the in-session fallback there is
**the only path there is**. **The order is marker first, then the rungs, and the marker is still
written**: it is the record that this stop happened, at what instant, at which gate, and whether rung
1 had fired. **On a surface with no hook nothing else removes it, so the skill does** —
`rm -f .nen/last-stop.json` or `nen stop clear` — once the stop has been answered; on Claude Code it
does **not**, because the hook consumes the marker and removing it first removes the bell. **The
report says which surface rang and how**, naming each rung's outcome and the marker's path and
removal, because a bell the harness rang, a bell the model rang and **a bell nobody rang** must be
tellable apart. **Rung 1 is the surface's own and is never faked**, and **a surface without a hook is
not a reason to be louder**.

### The in-session fallback, said out loud

**Only where rungs 2–3 are owed at all** — a gate, or `notifications.turn: "all"`. With no
`hooks/hooks.json` installed the skill runs the notifier itself and **says which rungs it fired that
way**:

```sh
osascript -e 'display notification "<body>" with title "<title>"' 2>&1
afplay /System/Library/Sounds/<notifications.sound>.aiff 2>&1
```

**Every value is sanitised exactly as [`hooks/stop-bell.sh`](../hooks/stop-bell.sh) sanitises it** —
titles and bodies are repository-controlled and land in two nested quoting contexts, where a stray
`'`, `"` or `\` ends the argument and hands the rest to the shell. Strip `"`, `\` and every newline
from `<title>` and `<body>` and pass the result as **one argument**, never interpolating a raw value
into the `-e` string; reduce `<notifications.sound>` to `[A-Za-z0-9_-]`, falling back to `Glass`; and
**a value that cannot be sanitised is not rung with** — fall back to the generic line and say the
title was dropped.

**Read stderr, not the exit code.** `osascript` exits `0` with nothing delivered where the session has
no Notification Center seat, saying so only on stderr, and `afplay` exits `1` with `AudioQueueStart
failed`; either means the rung **did not fire**, and it is reported **`not applicable — no seat`**, by
name, per rung — not "fired", not "failed". **Never retry them and never substitute another
noise-maker**: a rung is what `notifications.rungs` declares. An absent `osascript` unfires rung 2 and
leaves rung 3 to fire on its own, **an unfired rung is never rendered as fired**, the fallback is
**announced every time**, and **the stop still stands** — jutaisho § 4's four parts are the real bell.
