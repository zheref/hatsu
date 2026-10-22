# Using Hatsu: pick your surface

Hatsu runs **first-party on four agent surfaces**, each served from a checkout you keep on your own
machine, on your own credentials. The skills and personas are authored once and generated into each
surface's own layout, so the loop, the gates and the roster are the same everywhere; what changes is the
spelling you type, where the files land, and how the surface is updated. This page is the hub: the four
compared, the shared requirements, the checkout every surface is served from, the first request, and
how each surface updates. One guide per surface carries the rest, in the same order every time:
**requirements → setup → usage → maintenance → uninstall → caveats**.

| Surface | Guide | How Hatsu arrives | You type | Personas | Update |
|---|---|---|---|---|---|
| **Claude Code** | [`claude-code.md`](claude-code.md) | the checkout linked in place as a skills-directory plugin | `/kurapika <request>`, `/hatsu:<skill>` | the plugin's own agent files | `/hatsu:bakuryuha` |
| **Codex** | [`codex.md`](codex.md) | the checkout registered as a marketplace, installed as the `hatsu` plugin | `$hatsu:<skill>` | `AGENTS.override.md`, placed per repository by the warm-up | `$hatsu:bakuryuha` |
| **Cursor** | [`cursor.md`](cursor.md) | `.cursor/skills/<name>` links into the checkout's generated mirror, placed per repository | `/<skill>` | `.cursor/agents/<persona>.md`, placed per repository | `/bakuryuha` |
| **Antigravity** | [`antigravity.md`](antigravity.md) | the checkout's generated plugin linked as the global plugin | `/<skill>` | the plugin's `agents/` | `/bakuryuha` |

The generated mirrors themselves, how they are regenerated and checked, are [`mirrors.md`](mirrors.md).
Each surface's evolution record, every capability cited to the vendor's own page with the line quoted
and the day it was fetched, is the matching file under [`../surfaces/`](../surfaces/README.md).

---

## Starting a new project

Use [`hatsu:okiro`](okiro.md) in an empty directory: a stack picker read from Nen's packs,
one plan and confirmation, scaffolding and adoption, then one verified initial Hatsu commit.
`--dry-run` writes nothing; existing trees use `hatsu:tenkai`.

## The four surfaces, compared

| | **Claude Code** | **Codex** | **Cursor** | **Antigravity** |
|---|---|---|---|---|
| how Hatsu arrives | **in place**: `~/.claude/skills/hatsu` → the checkout (`hatsu@skills-dir`) | **the Hatsu plugin**: a clean snapshot of the committed checkout as a marketplace, `codex plugin add hatsu@hatsu` (a copy per version) | bootstrap seeds `ten`; the warm-up links `surfaces/cursor/` | **global plugin**: `~/.gemini/config/plugins/hatsu` → `<checkout>/surfaces/antigravity` |
| skills read from | `$CLAUDE_PLUGIN_ROOT/claude/skills/<name>/SKILL.md`, the checkout's own | the plugin's `claude/skills/<name>/SKILL.md` (the overlay's `skills`) | `<repo>/.cursor/skills/<name>/SKILL.md` (symlinks) | plugin `skills/<name>/SKILL.md` |
| personas read from | `claude/agents/<persona>.md` | `AGENTS.override.md` as prose, plus `.codex/agents/<persona>.toml` | `.cursor/agents/<persona>.md` | plugin `agents/<persona>.md` or `.agents/agents/<persona>.md` |
| rules file | none | `AGENTS.override.md` (32 KiB cap) | `.cursor/rules/hatsu.mdc` | `rules/hatsu.md`, 12,000 characters max |
| invocation spelling | `hatsu:<name>` | `$hatsu:<name>` (plugin); `$<name>` (legacy copy) | `/<name>` | `/<name>` |
| turn-end hook | **yes**, `Stop` in `hooks/hooks.json` | **yes**, `Stop` in `surfaces/codex/hooks.json`, named by the plugin overlay (legacy: `.codex/hooks.json`) | **yes**, `stop` in `.cursor/hooks.json` | **yes**, `Stop` in the plugin's `hooks.json` |
| session-start hook | `SessionStart`, `hooks/session-start.sh` (binds the pinned `nen` on the host first — `scripts/nen_global.sh`: `~/.local/bin/nen` and the rc PATH block, opt-out `HATSU_NEN_GLOBAL=0` — then a reminder; the plugin is read in place) | `SessionStart` (the nen binding, then the mirror refresh, adopted repositories only) | `sessionStart` (the same) | `PreInvocation` (no `SessionStart` exists; the same) |
| trunk guard | `PreToolUse` on `Bash`, `permissionDecision: deny` | `PreToolUse`, `permissionDecision: deny` (`ask` not honoured yet) | `beforeShellExecution`, `permission: deny` | `PreToolUse` on `run_command`, `decision: deny` |
| permissions | `.claude/settings.local.json`, `Bash(<exe> <args>)` | `.codex/config.toml`: `sandbox_mode`, `writable_roots` (the one root-scoped surface) | `.cursor/cli.json`, `Shell(<exe> <args>)` | per-agent `commandExecutionPolicy`; the guard is the enforcement |
| in-session subagent | the Agent tool | `spawn_agent` | `.cursor/agents/` | `invoke_subagent`, `Workspace` `inherit`, `branch` or `share` |
| native option picker | `AskUserQuestion` | `request_user_input` | the ask question tool (`cursor/ask_question`) | `ask_question`, `is_multi_select` |
| persona model key | `model`: tier alias | `model` in the TOML; `[agents]` fragment from the rows | `model: inherit` (Cursor-native only) | `model`: `inherit`, `flash`, `pro` |
| reviewer tier (`models.roles.reviewer` = `deep`) | `opus` | `sol` | `grok` | `pro` |
| update and switch (`hatsu:bakuryuha`) | the checkout moves; **type `/reload-plugins`**, or a new session; the model cannot run it | the checkout moves and the plugin is re-added; running sessions refresh skills and hooks (0.154.0); personas at the next run; a changed hook waits for `/hooks` trust | a new chat (forum-sourced), or **Developer: Reload Window** | a new conversation; the CLI's `/skills reload` (≥ 1.2.4), typed |
| minimum build | n/a | none documented; validated on `codex-cli 0.149.0` | `cursor-agent 2026.01.*`, below it no skill is seen | Antigravity IDE / `agy` CLI |

Each surface's rows are cited, dated 2026-09-20 (the update-and-switch row 2026-09-29), in its guide's checklist. Two corrections made there
on that date: Codex and Cursor **do** have hooks (the hub used to say otherwise), and Antigravity's
workspace paths are `.agents/…` with `.agent/…` as back-compatibility only.

**The session-start hook refreshes a consumer's mirrors only where Hatsu is already adopted**: the
checkout carries `nen/workflow.json` or `nen/contract.json` and a placed marker, the hook refreshes only
the surface its own generated marker names, and it writes its report to `.nen/session-start.log`. The
plugin source copy under Claude Code only prints the warm-up reminder; adoption is `tenkai`'s, never a
hook's.

**The first-party install is one command per surface, run from the checkout** (the maintainer's core
working directory): `"$HATSU_PLUGIN_ROOT/scripts/hatsu_surface_link.sh" --surface
<claude-code|codex|antigravity> --root "$HATSU_PLUGIN_ROOT"`. It links (Claude Code's `skills/hatsu`,
Antigravity's global plugin) or registers and installs (the Codex plugin), refuses a destination it did
not make, retires the shadowing `hatsu@hatsu` on Claude Code together with the marketplace and enable
declarations settings keep of it, and reads the result back; `--status` is
read-only. `hatsu:bakuryuha` runs it when a surface is still on its legacy form. Whatever the checkout
holds is what every surface serves, so it stays on its trunk. Fixture:
`scripts/hatsu_surface_link_fixture_check.sh`; the live record is evidence § 10.

**First-run discovery on Cursor, and in the legacy placements, is a bootstrap, not an environment variable.** `HATSU_PLUGIN_ROOT` names a
checkout; it cannot make an undiscovered skill callable. Codex, Cursor and Antigravity workspace mode
need one command before their first warm-up:
`"$HATSU_PLUGIN_ROOT/scripts/surface_bootstrap.sh" --surface <codex|cursor|antigravity> --target . --bootstrap`,
which seeds only `ten`; that skill's every-session refresh calls the same script with
`--install-all`. Fixture: `scripts/surface_bootstrap_fixture_check.sh`.


---

## Requirements

**Three of these are the same on every surface**, and then each surface brings its own host program.

| | |
|---|---|
| [`nen`](https://github.com/zheref/nen) at [`nen/contract.json`](../../nen/contract.json)'s `dependency.minimum` | a **hard** dependency — see [The Nen contract](../NEN-CONTRACT.md). The installed binary's compatibility floor and `nen shu tools` decide the range. The warm-up installs it checksum-verified when the host allows it. **One exception, on Codex** — the box below the surface table. |
| `git` + [`gh`](https://cli.github.com), authenticated | the skills read and write GitHub as **you**. |
| a [`nen/contract.json`](../../nen/contract.json) in the repository you point Hatsu at | **the only thing Hatsu asks of your project.** It declares what *your* build, test, lint, archive and deploy commands are, so nothing here is bound to a language, a framework, a build system or a product. A repository that declares none gets the git half of every skill and its own documented commands, said plainly rather than guessed at. |

**On the installed plugin path** you need one binary, plus `git`, `gh` and **`python3`, a
prerequisite you install yourself where the host lacks it** — a minimal Linux image, or a macOS host
without the Command Line Tools, has none: several skill scripts run Python (`tenkai`'s adoption,
`kagutsuchi`'s worktree among them), and without it those steps stop. `jq` is optional there: the warm-up's checks use it when present and
say what they could not read without it (`ten` § 5 reports Claude Code's install record unread, never a
stop). `yq` is never needed. (The repository's own CI is a separate matter — `scripts/plugin_bump_check.sh`
requires `jq`.)


### Per surface

| | **Claude Code** | **Codex** | **Cursor** | **Antigravity** |
|---|---|---|---|---|
| **the host** | [Claude Code](https://claude.com/claude-code). The `claude plugin` subcommands below are its own | the `codex` CLI. **No minimum is established**; the build every record here was made on is **`codex-cli 0.149.0`** (`codex --version`) | `cursor-agent` — **`2026.01.*` or newer, and this one is a real floor**. see [Cursor](cursor.md) | Antigravity IDE / `agy` CLI |
| **signing in** | the harness's own | `codex login`. `codex login status` answers `Logged in using ChatGPT` | `cursor-agent login`. `cursor-agent status` answers `✓ Logged in as <you>` | Google Account / Antigravity harness |
| **where it reads the skills from** | the installed plugin, in place — nothing is written into your repository | the `hatsu@hatsu` plugin's `claude/skills/<name>/` (legacy: `<repo>/.agents/skills/<name>/`) | `<repo>/.cursor/skills/<name>/` | Global plugin (`~/.gemini/config/plugins/hatsu`) or `<repo>/.agents/skills/<name>/` |
| **and the personas** | `claude/agents/`, in place | `<repo>/AGENTS.override.md` — one **untracked** file, as prose | `<repo>/.cursor/agents/<persona>.md` — one subagent file each | Global plugin agents or `<repo>/.agents/rules/AGENTS.md` |
| **how it got there** | `hatsu_surface_link.sh --surface claude-code` | a checkout registered as a marketplace, then `codex plugin add hatsu@hatsu` — [*Codex*](codex.md) | a checkout, one-time bootstrap, then the warm-up — [*Cursor*](cursor.md) | Global plugin symlink or bootstrap — [*Antigravity*](antigravity.md) |
| **the caveat that bites first** | none | `AGENTS.override.md` **replaces** your `AGENTS.md` in the instruction envelope rather than joining it, so the warm-up copies yours into it verbatim first and never writes the tracked file | the skill name space is **flat and global** — shared with Cursor's own built-ins and with every other plugin on the host | Workspace mode requires native hooks in `.agents/hooks/` and `.agents/hooks.json` excluded via `.git/info/exclude` |


> **`nen` installs and binds itself on every surface but one.** The warm-up installs the pinned binary,
> checksum-verified, and the session-start hook links it at `~/.local/bin/nen` so your own terminal and the
> agent run the same build. A sandboxed Codex run cannot write there, so put `nen` on the host yourself
> first. The whole mechanism, its opt-outs and the fallback offer are in
> [`../NEN-CONTRACT.md` § *Where nen is installed*](../NEN-CONTRACT.md#where-nen-is-installed-and-how-it-is-bound-on-your-host).

---

## A checkout you keep

Every surface is served from one git checkout of this repository. Claude Code links it in place,
Antigravity links its generated plugin, Codex copies it per version through its plugin install, and
Cursor links each skill into it. **Start with the checkout**; the per-surface install is one command on
top of it.

**Start with a checkout you keep.** Codex registers it as the `hatsu` marketplace and installs the plugin;
Cursor uses the one-time skill bootstrap below. After that checkout exists, the warm-up can fast-forward it.
A warm-up that cannot find the root reports `NOT INSTALLED` and stops.

**One of these two**, not both — the second refuses on a destination that already exists:

```sh
# the tip
git clone https://github.com/zheref/hatsu.git ~/.hatsu

# — OR — pinned to a release (the tags are at https://github.com/zheref/hatsu/tags)
git clone --branch <tag> --depth 1 https://github.com/zheref/hatsu.git ~/.hatsu
```

Then, once:

```sh
export HATSU_PLUGIN_ROOT="$HOME/.hatsu"          # put this in your shell profile
```

**`$HATSU_PLUGIN_ROOT` locates the checkout; it does not install a plugin or register a skill.** On Codex,
run the plugin install under [*Codex*](codex.md); on Cursor, run its one-time bootstrap. The warm-up
resolves this variable first, then a path handed to the invocation, and only then `$CLAUDE_PLUGIN_ROOT`.

> **`$CLAUDE_PLUGIN_ROOT` is Claude Code's variable and it is *not* inert on the other two.** On the host
> these records were made on it is exported from `~/.zshrc` and points at a **different plugin**, which
> every Codex and Cursor session on that host inherits. So a candidate root is checked for what it **is** —
> the **top-level** `"name"` of its own `.claude-plugin/plugin.json`, compared whole, reading `hatsu`, plus one
> second, independent fact about the same directory: that `claude/skills/` is there. (Those two, and no
> more — the check does not parse the manifest's `skills` value.) *Top-level* is structural, not "the first
> one": the manifest is read as the one shape Claude Code's tooling writes — `JSON.stringify(x, null, 2)`:
> line one `{`, every inner line indented at least two spaces, the last line `}` — and a key at two spaces
> is top-level unless a two-space line opened a nested block above it. So a `name` nested anywhere never
> matches whatever the key order, two top-level matches fail, and **any other shape is refused** rather than
> parsed — minified, tab- or four-space-indented, keys at column zero, a nested block laid out at two spaces:
> not what the tooling writes, and refusal is the safe direction. The captured path must
> also be the same directory as the candidate, must contain no newline (the root is handed to later shells
> as one quoted line), and `cd` runs with `CDPATH` cleared so nothing but the path is captured. It is never
> merely checked for containing a `surfaces/` directory. Shape is not identity: a wrong root that happened
> to have the right shape would install somebody else's skills into your repository with no error anywhere.
> **Every rejected candidate is named by path in the report**, even when a later one succeeded, because a
> stale variable in a shell profile is a thing to fix and this is where it becomes visible.

---

## One request, end to end

The loop is the same on every surface: **open the session once, hand it the request, let `ren` run the
turn, then call the two phases that are yours.** The request goes **on the invocation line** — `ren` refuses
a turn with no request and never infers one from what the session was last doing — and every later request
is simply the next message in the same thread: in a repository whose `nen/workflow.json` describes this loop,
an ordinary request *is* a `ren` turn.

What the first turn does before any of your change is authored: `breath` fetches, fast-forwards the trunk,
cuts `{model}/{persona}/{descriptor}` from its fresh tip and proves the declared checks on it. Then
`rasengan` authors the change and focused tests, `kokusen` runs focused tests plus iteration checks and commits locally, `amaterasu` builds, installs and launches the declared
target, `spiritual-message` publishes the turn report and `jutaisho` rings the bell. Nothing is pushed until you say so.


The same four calls, in each surface's spelling:

| | Claude Code | Codex | Cursor | Antigravity |
|---|---|---|---|---|
| **open the session** | `/kurapika <request>` runs the warm-up and the first turn | `$hatsu:ten` | `/ten` | `/ten` |
| **a request** | the next message, or `/hatsu:ren <request>` | `$hatsu:ren <request>` | `/ren <request>` | `/ren <request>` |
| **push, when you decide** | `/hatsu:aka` | `$hatsu:aka` | `/aka` | `/aka` |
| **review, tests, coverage, one PR** | `/hatsu:mukai` | `$hatsu:mukai` | `/mukai` | `/mukai` |

`en` then watches the PR to verified Ready and stops at your merge prompt. The merge is yours, in
GitHub. Each guide's *Usage* section has the surface's own detail: how personas are placed, how the
bell rings, how a gate question reaches the surface's option picker, and the headless form.

---

## Updating Hatsu on each surface

**One command, every surface: `hatsu:bakuryuha`** (spelled `$hatsu:bakuryuha` on Codex, `/bakuryuha` on
Cursor and Antigravity). It makes the first-party install where a legacy form still stands, fast-forwards
your checkout, re-proves the warm-up from the new files, reads back what the surface serves, and **always
ends with a Next block**: the one thing to type or open to finish. From `v0.66.0` every surface's source
is **your checkout**; only Codex copies it.

| Surface | What is served | How it updates | Next, to use it |
|---|---|---|---|
| **Claude Code** | the checkout, in place, through `~/.claude/skills/hatsu` (`hatsu@skills-dir`) | `scripts/hatsu_plugin_update.sh --claude`: fast-forward the linked checkout; no `claude plugin update` | **type `/reload-plugins`**, or open a new session: no app restart |
| **Claude Code**, legacy cache install | `~/.claude/plugins/cache/hatsu/hatsu/<version>/`, a copy | `hatsu:bakuryuha` retargets it onto the link (`scripts/hatsu_surface_link.sh --surface claude-code`) | as above |
| **Codex** | the Hatsu plugin, a copy of the checkout per version | `--codex`: fast-forward the marketplace checkout, then `codex plugin add hatsu@hatsu` again | running sessions refresh skills and hooks; personas at the next run; trust a changed hook in `/hooks` |
| **Cursor** | `.cursor/skills/<name>` links into `<checkout>/surfaces/cursor/` | fast-forward the checkout (`--auto` in the warm-up); `/ten` repairs links | a new chat, or **Developer: Reload Window** |
| **Antigravity** | `~/.gemini/config/plugins/hatsu` → `<checkout>/surfaces/antigravity`, in place | fast-forward the checkout; the link follows | a new conversation; the CLI's `/skills reload` (≥ 1.2.4) |
| **Antigravity**, workspace bootstrap (legacy) | copies under `<repo>/.agents/` | fast-forward, then `/ten` re-copies | a new conversation |

**`--auto` never discards and never updates an authoring branch.** A session standing in this repository
on `grok/kurapika/…` is writing Hatsu; the skip is the correct outcome. Explicit `--channel trunk` or
`--channel release` without `--auto` refuses those cases instead of skipping.

Prove the updater against throwaway clones (no credential, no this checkout):

```sh
scripts/hatsu_plugin_update_fixture_check.sh
```

---

## Targeting a local checkout

Use a local tree when you want the unreleased tip, a branch, or to author Hatsu itself.
`$HATSU_PLUGIN_ROOT` tells the warm-up which checkout to use; each surface still needs its own install.

**Claude Code**

```sh
git clone https://github.com/zheref/hatsu.git ~/Code/Agents/hatsu   # or your existing clone
export HATSU_PLUGIN_ROOT="$HOME/Code/Agents/hatsu"                 # shell profile
"$HATSU_PLUGIN_ROOT/scripts/hatsu_surface_link.sh" --surface claude-code --root "$HATSU_PLUGIN_ROOT"
```

`claude plugin list --json` must show `hatsu@skills-dir` enabled at that checkout.
After the checkout moves, type `/reload-plugins` or open a new session.

**Codex**

```sh
"$HATSU_PLUGIN_ROOT/scripts/hatsu_surface_link.sh" --surface codex --root "$HATSU_PLUGIN_ROOT"
# codex plugin list must show hatsu@hatsu installed, enabled at the checkout's version
```

**Cursor workspace**

```sh
export HATSU_PLUGIN_ROOT="$HOME/Code/Agents/hatsu"
"$HATSU_PLUGIN_ROOT/scripts/surface_bootstrap.sh" --surface cursor --target /path/to/product-repo --bootstrap
# then open that product repo and run /ten
```

**Antigravity** uses `hatsu_surface_link.sh --surface antigravity` for its global plugin;
see [*Antigravity*](antigravity.md) for the workspace fallback.

**Authoring this repository on Cursor** — so the session does not bind Claude's versioned cache (on this
host that cache has sat at `0.14.0` while `plugin.json` on the tree already read `0.30.0`):

```sh
export HATSU_PLUGIN_ROOT="$HOME/Code/Agents/hatsu"   # this checkout
"$HATSU_PLUGIN_ROOT/scripts/surface_bootstrap.sh" --surface cursor --target "$HATSU_PLUGIN_ROOT" --install-all
```

That writes `.cursor/skills/<name>` → `surfaces/cursor/<name>` of **this tree**, excluded through
`info/exclude`, and that workspace path is what Cursor lists ahead of `~/.claude/plugins/cache/hatsu/…`.
`$HATSU_PLUGIN_ROOT` already belongs in the shell profile; without the bootstrap, Cursor still discovers
the Claude cache and serves last-tag prose while you edit current canon. `--auto` will skip this tree
while you are on a feature branch — correctly — and § 5 still installs the branch's own mirrors.

**Antigravity global**

```sh
mkdir -p ~/.gemini/config/plugins
ln -sfn "$HATSU_PLUGIN_ROOT/surfaces/antigravity" ~/.gemini/config/plugins/hatsu
```

The linked folder carries the documented plugin layout (`plugin.json`, `skills/`, `agents/`, `rules/`,
`hooks.json`). Authority for the rest of the mechanism: [`mirrors.md`](mirrors.md).

**Authoring the plugin: the tree is named, never trusted by itself** (zheref/hatsu#67). When the working
tree is a Hatsu checkout — its `.claude-plugin/plugin.json` names `hatsu` — and its manifest version is
newer than the resolved candidate's, [`scripts/hatsu_root.sh`](../../scripts/hatsu_root.sh) **keeps the
candidate** (a directory's claim about itself never picks the root later steps run scripts from) and says
on stderr which pin this session bound, that the skill bodies already inlined are that pin's, where to
read the tree's protocol (`<checkout>/claude/skills/<name>/SKILL.md`) and the quoted
`export HATSU_PLUGIN_ROOT='<checkout>'` — candidate 1, the maintainer's word — that binds the tree from
the next session. The effective order is unchanged: `$HATSU_PLUGIN_ROOT`, the handed path,
`$CLAUDE_PLUGIN_ROOT`; the tree is a fourth only in the sense that it is named. Three limits, stated:
the line exists from the first installed pin whose resolver carries it (0.53.0 or later — `ten` § 0
runs the bound pin's own resolver, so an older pin says nothing and the export is the only form); on
Claude Code the slash-skill bodies are always the installed pin's (no mirror, § 2), so binding the tree
there is a plugin-install question, not this script's; on Cursor, whether the linked `.cursor/skills/`
outranks the Claude cache is unverified ([`cursor.md`](../surfaces/cursor.md) § 10). Fixture: the
tree-is-named cases of `scripts/hatsu_root_fixture_check.sh`.

**The invocation spelling is the mirror's.** Every `hatsu:<name>` in a skill body is rewritten by the
generator because `--invocation-prefix hatsu:` tells it the source's namespace; `hatsu:` is caller data
and nen hard-codes no system's vocabulary.

---

## Generated and authored

Hatsu's canonical skills live in `claude/skills/` and its personas in `claude/agents/`; the files under
[`surfaces/`](../../surfaces/) are generated from them, one layout per surface, each stamped with the
plugin version, and a hand edit there is reported by name. [`mirrors.md`](mirrors.md) has the full table of
what is authored and what is generated, what the warm-up places in a target repository, the one
regeneration command and the check that runs in `mukai` and in CI.

---

## Where the rest lives

| | |
|---|---|
| per-surface setup, usage, maintenance, uninstall | [`claude-code.md`](claude-code.md) · [`codex.md`](codex.md) · [`cursor.md`](cursor.md) · [`antigravity.md`](antigravity.md) |
| generated versus authored, regenerating, the check | [`mirrors.md`](mirrors.md) |
| per-surface paths, keys, hooks, permissions, rules, picker, generation, dated checklist | [`../surfaces/<surface>.md`](../surfaces/README.md) |
| the skeleton every evolution guide follows, the shared placement rules | [`../surfaces/README.md`](../surfaces/README.md) |
| headless validation commands and their transcripts | [`../surfaces/evidence/surfaces.md`](../surfaces/evidence/surfaces.md), Appendix A |
| every configuration file, key by key | [`../config/`](../config/README.md) |
| placing the mirrors into a target | [`../../claude/skills/ten/SKILL.md`](../../claude/skills/ten/SKILL.md) § 5 |
| the bell and the picker at a gate | [`../../claude/skills/jutaisho/SKILL.md`](../../claude/skills/jutaisho/SKILL.md) |
| raising a reviewer per surface | [`../../claude/skills/hanten/SKILL.md`](../../claude/skills/hanten/SKILL.md) § 4 and § 7 |
| the model matrix | [`../../nen/workflow.json`](../../nen/workflow.json) → `models`; [`../DIRECT-MATRIX.md`](../DIRECT-MATRIX.md) |
| keeping the evolution guides current | `hatsu:great-hiker evolve`, one Netero-shaped issue per surface whose checklist moved |
