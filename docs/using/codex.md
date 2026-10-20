# Hatsu on Codex

> **Setup · usage · maintenance** for the Codex surface (CLI, IDE extension and the ChatGPT app). The
> cross-surface requirements, the checkout you keep and the update table are in [the hub](README.md);
> the surface's evolution record is [`../surfaces/codex.md`](../surfaces/codex.md).

| | |
|---|---|
| **How Hatsu arrives** | a clean snapshot of the checkout's committed tip registered as the `hatsu` marketplace, then installed as the `hatsu@hatsu` plugin; Codex copies it per version into its plugin cache |
| **Skills read from** | the plugin's `claude/skills/<name>/` (legacy placement: `<repo>/.agents/skills/<name>/`) |
| **Personas** | `<repo>/AGENTS.override.md`, one **untracked** file the warm-up writes as prose |
| **You type** | `$hatsu:<skill>`; `$<skill>` for a legacy placed copy |
| **Gate questions** | `request_user_input`, the surface's own picker; the bell is the generated `Stop` hook |
| **Update** | `$hatsu:bakuryuha`; running sessions refresh skills and hooks, personas at the next run |

---

## 1 · Requirements

- The host: the `codex` CLI. No minimum is established; the build every record was made on is named in
  [`../surfaces/codex.md` § 1](../surfaces/codex.md#1-identity-and-paths).
- Signing in: `codex login`. `codex login status` answers `Logged in using ChatGPT`.
- The shared three (`nen`, `git` + `gh`, a `nen/contract.json`), plus `python3` on the installed plugin
  path: [the hub's *Requirements*](README.md#requirements). **Put `nen` on the host yourself before a
  sandboxed run**: `codex exec -s workspace-write` cannot write to the cache directory the bootstrap
  installs into ([`../NEN-CONTRACT.md`](../NEN-CONTRACT.md#where-nen-is-installed-and-how-it-is-bound-on-your-host)).
- A checkout, with `HATSU_PLUGIN_ROOT` pointing at it: [the hub's *A checkout you keep*](README.md#a-checkout-you-keep).

## 2 · Setup

**Hatsu is a Codex plugin** (from `v0.66.0`): Codex reads the committed snapshot's `.claude-plugin/marketplace.json`
as a legacy-compatible marketplace, and the `.codex-plugin/plugin.json` overlay hands it the canonical
skills, listed and invoked as `$hatsu:<name>`, plus the generated Codex hooks:

```sh
"$HATSU_PLUGIN_ROOT/scripts/hatsu_surface_link.sh" --surface codex --root "$HATSU_PLUGIN_ROOT"
# = git archive HEAD into $CODEX_HOME/hatsu-marketplace-snapshots/<commit>,
#   codex plugin marketplace add <snapshot> && codex plugin add hatsu@hatsu, read back
```

On Windows, if `codex plugin` reports `failed to resolve CODEX_HOME` in a constrained shell, set
`CODEX_HOME` to the **existing** Codex data directory for that shell before running the installer:

```powershell
$env:CODEX_HOME = Join-Path $env:USERPROFILE '.codex'
codex plugin list  # confirm the same home shows hatsu@hatsu after installation
```

Codex installs a **copy** per version under `~/.codex/plugins/cache/hatsu/hatsu/<version>/`. The
marketplace root is a `git archive` of the served commit, so `.git`, `.nen/`, ignored worktrees and
local settings are absent from both the snapshot and the copied slot. A newer commit gets a new
snapshot directory; the installer removes the old marketplace registration and adds the new one before
installing the plugin. Codex does not notice a newer source by itself, so an update is
`$hatsu:bakuryuha`, or `scripts/hatsu_plugin_update.sh --codex`, which fast-forwards the checkout and
re-adds the plugin; running sessions then refresh skills and hooks. Trust Hatsu's hooks once in `/hooks`
(Codex never trusts a plugin's hooks by itself). The plugin carries no personas: in each repository
`$hatsu:ten` still places `AGENTS.override.md` and the persona files, and removes the skill copies and
hooks file the placement below used to leave (`surface_bootstrap.sh --install-all --plugin`).

**The legacy placement**, still supported where no plugin is installed. From the repository you want to
work in, seed the one skill Codex must discover first:

```sh
"$HATSU_PLUGIN_ROOT/scripts/surface_bootstrap.sh" --surface codex --target . --bootstrap
```

This is intentionally a **non-skill** command: it copies only
`.agents/skills/ten/`, verifies that an existing destination is Hatsu-owned before replacing it,
and records the local installation through Git's `info/exclude`. It never touches `.gitignore` or a tracked
destination. Now restart or open Codex in that repository and invoke the discovered skill:

```
$ten
```

That warm-up refreshes the complete surface every session. What it places in **your** repository:

| | |
|---|---|
| `<repo>/.agents/skills/<name>/` | one `cp -R` per mirrored skill directory — **54**, the fifty-three plus `ten` itself — from `$HATSU_PLUGIN_ROOT/surfaces/codex/`, **re-copied every session** so a target is at most one warm-up behind the plugin |
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
  is replaced; a **tracked** path is always somebody else's, whatever it looks like. Fifty-one ordinary
  words are being claimed at once — `build`, `file`, `en`, `ao`, `ren` — so a collision is not a rare case,
  and the warm-up would rather install fewer and say so than overwrite one file it did not write.
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

**To update a legacy placement**, the warm-up does it: `$ten` / `/ten` runs
[`scripts/hatsu_plugin_update.sh`](../../scripts/hatsu_plugin_update.sh) `--auto` against `$HATSU_PLUGIN_ROOT`
before it refreshes the target. A checkout on `main` fast-forwards; a checkout detached at a `vX.Y.Z` tag
moves to the newest release tag; an authoring branch and a dirty tree are skipped, never discarded.
To do the same by hand:

```sh
"$HATSU_PLUGIN_ROOT/scripts/hatsu_plugin_update.sh" --channel trunk     # origin/main, ff-only
"$HATSU_PLUGIN_ROOT/scripts/hatsu_plugin_update.sh" --channel release   # newest vX.Y.Z tag
```

Then run `$ten` again: the unconditional re-copy is what refreshes the target. A copy is not
self-healing, and the one failure mode it has is a session that never warmed up serving last month's wording
with no error anywhere. If you *changed* a skill, regenerate the mirrors in the same commit —
[`mirrors.md` § 3](mirrors.md#3--regenerating) has the commands and the check. The full per-surface recipe, including how to
point Cursor at this checkout so it does not bind a stale Claude plugin cache, is
[*Updating Hatsu on each surface*](README.md#updating-hatsu-on-each-surface).

## 3 · Usage


```
$hatsu:ten                               # once per session: verify Nen and place this repo's personas
$hatsu:ren Add a "Clear all" action to the notifications list, with a confirmation sheet
$hatsu:aka
$hatsu:mukai
```

Kurapika is the persona here through the untracked `AGENTS.override.md` the warm-up writes; there is no
separate summon. The plugin serves skills and hooks; `ten` places personas in the target repository.
For headless use and the linked-worktree sandbox setting, see [the Codex surface guide](../surfaces/codex.md).


The [Codex surface guide](../surfaces/codex.md) covers plugin read-back, hook trust,
model selection, sandbox roots for linked worktrees, headless runs and the legacy
`$<name>` placement. The legacy form is supported but is not the default install.


**Personas are prose here, and do not win an identity argument with the host.** A user-level instruction
saying "introduce yourself as X" keeps saying X while the work is done in Kurapika's discipline. The
record of who acted is Hatsu's own: `--who` on `nen stop`, the `who` field of `.nen/last-stop.json`, and the
`Hatsu-Agent` trailer. **Untrusted projects skip every `.codex/` layer**, config, hooks and rules included,
so trust the repository first.

**Models.** The tiers this surface's `models.codex` block names, and which one `hatsu:direct` recommends
for a given job, are in [`../DIRECT-MATRIX.md`](../DIRECT-MATRIX.md); the live id is read from
`codex debug models`, never remembered.

## 4 · Maintenance

| What is served | How it updates | Next, to use it |
|---|---|---|
| the Hatsu plugin, a copy of the committed snapshot per version | `scripts/hatsu_plugin_update.sh --codex`: fast-forward the source checkout, create a clean snapshot, move the marketplace registration and re-add the plugin | running sessions refresh skills and hooks; personas at the next run; trust a changed hook in `/hooks` |

`$hatsu:bakuryuha` does all of that and ends with the one thing left to type. By hand:

```sh
"$HATSU_PLUGIN_ROOT/scripts/hatsu_surface_link.sh" --surface codex --root "$HATSU_PLUGIN_ROOT"
# codex plugin list must show hatsu@hatsu installed, enabled at the checkout's version
```

## 5 · Uninstall and rollback

Nothing server-side changed. `codex plugin marketplace remove hatsu` removes the registration and
uninstalls its plugin. After checking `codex plugin list` has no `hatsu@hatsu` row, remove an old,
unused `$CODEX_HOME/hatsu-marketplace-snapshots/<commit>` directory and its adjacent `<commit>.source`
record. Codex may retain an old versioned cache directory under
`$CODEX_HOME/plugins/cache/hatsu/hatsu/`; remove that old slot only after verifying it is not the
installed version. In each repository the warm-up placed into, delete
`AGENTS.override.md` and any `.agents/skills/<name>/` copies; both are recorded in that repository's
`.git/info/exclude`, never in `.gitignore`, so nothing tracked changes.

## 6 · Caveats

- **`AGENTS.override.md` replaces your `AGENTS.md`** in the instruction envelope rather than joining it,
  which is why the warm-up copies yours into it verbatim first and never writes the tracked file.
- **The plugin install copies the whole marketplace root**. `hatsu_surface_link.sh` makes that root a
  committed snapshot first. A manual `codex plugin marketplace add <working-checkout>` bypasses the
  protection and copies `.git` and ignored files into the cache.
- **`$CLAUDE_PLUGIN_ROOT` is not this surface's variable** and may point at another plugin on your host.
  Use `$HATSU_PLUGIN_ROOT`.
- **A legacy placement is copies, not symlinks**, for the namespacing reason § 2 gives; a copy is at most
  one warm-up behind the checkout, and a session that never warmed up serves last month's wording with no
  error anywhere.

## Sources

- [`../surfaces/codex.md`](../surfaces/codex.md), the dated checklist, the headless form, the sandbox and worktree notes
- [`mirrors.md`](mirrors.md), generated versus authored, regenerating, and the check
- [`../../scripts/hatsu_surface_link.sh`](../../scripts/hatsu_surface_link.sh) · [`../../scripts/surface_bootstrap.sh`](../../scripts/surface_bootstrap.sh) · [`../../scripts/hatsu_plugin_update.sh`](../../scripts/hatsu_plugin_update.sh)
