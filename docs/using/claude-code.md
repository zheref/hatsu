# Hatsu on Claude Code

> **Setup · usage · maintenance** for the Claude Code surface. The cross-surface requirements, the
> checkout you keep and the update table are in [the hub](README.md); the surface's evolution record,
> every capability cited to the vendor's page, is [`../surfaces/claude-code.md`](../surfaces/claude-code.md).

| | |
|---|---|
| **How Hatsu arrives** | the checkout linked in place at `~/.claude/skills/hatsu`, a skills-directory plugin (`hatsu@skills-dir`) that "loads in place and is never copied" |
| **Skills read from** | the plugin, in place; nothing is written into your repository |
| **Personas** | the plugin's agent files, in place; one `/kurapika` summon command |
| **You type** | `/kurapika <request>` to open a session, `/hatsu:<skill>` for any skill |
| **Gate questions** | the surface's native option picker; the bell is the plugin's `Stop` hook |
| **Update** | `/hatsu:bakuryuha`, then `/reload-plugins` |

---

## 1 · Requirements

- The host: [Claude Code](https://claude.com/claude-code). The `claude plugin` subcommands on this page are its own.
- Signing in: the harness's own.
- The shared three: `nen` (installed and bound by the warm-up), `git` and `gh` authenticated as you, and a
  `nen/contract.json` in the repository you point Hatsu at. `python3` is a prerequisite on the installed
  plugin path. Details in [the hub's *Requirements*](README.md#requirements).

## 2 · Setup

Hatsu is served **in place from a checkout you keep**, never from Claude Code's plugin cache (from
`v0.66.0`): a link under `~/.claude/skills/` makes it a skills-directory plugin, `hatsu@skills-dir`,
which "loads in place and is never copied".

```sh
git clone https://github.com/zheref/hatsu.git ~/Code/Agents/hatsu     # or wherever you keep it
~/Code/Agents/hatsu/scripts/hatsu_surface_link.sh --surface claude-code --root ~/Code/Agents/hatsu
```

The script links `~/.claude/skills/hatsu` to the checkout, and if an older `hatsu@hatsu` marketplace
install is present (it would shadow the link) it disables and uninstalls it and removes that
marketplace, including the declaration your `~/.claude/settings.json` keeps of it (left there, a reload
clones it back and reinstalls the copy), then reads the result back. Then open a new session, or type `/reload-plugins` in one that is running:

```
/kurapika
```

Confirm what loads:

```sh
claude plugin list --json    # hatsu@skills-dir · installPath ~/.claude/skills/hatsu · the checkout's version
```

`/kurapika` runs the warm-up (`/hatsu:ten`) before beginning the loop; discovery happens before the first
invocation, without writing into the target repository. **Keep the checkout on `main`**: whatever it
holds is what every session serves.

The marketplace route (`claude plugin marketplace add zheref/hatsu`, `claude plugin install
hatsu@hatsu`) still works for someone who does not keep a checkout, but it installs a **copy** into the
cache, even from a local directory ([`docs/surfaces/evidence/surfaces.md`](../surfaces/evidence/surfaces.md)
§ 10), and it is the form `/hatsu:bakuryuha` migrates.

## 3 · Usage


```
/kurapika Add a "Clear all" action to the notifications list, with a confirmation sheet
```

`/kurapika` is the session opener: it runs the Nen dependency warm-up (the contract, the binary, the floor)
and then takes the request as the first `ren` turn, with Kurapika as the persona for the whole thread. From
there:

```
<the next request, as a plain message>   # another ren turn on the same branch
/hatsu:aka                               # lint, squash, catch up, push — when YOU decide the branch goes up
/hatsu:mukai                             # catch-up, review, impacted tests, coverage bar, evidence, one PR, then the offer of en
```

`/hatsu:ren <request>` invokes the loop directly and is the right call in a session that is already warmed
up; on a cold session prefer `/kurapika`, which runs the warm-up first. `en` watches until the PR is
verified Ready, reports that human gate, and stops; the merge remains yours, later, in GitHub.


**What the plugin adds around a session.** [`../../hooks/hooks.json`](../../hooks/hooks.json) ships three
harness hooks, discovered automatically at that path: a `SessionStart` hook that first binds the pinned
`nen` on the host (`scripts/nen_global.sh`, fail-open, `HATSU_NEN_GLOBAL=0` opts out) and prints the
warm-up reminder; a `Stop` bell that notifies and plays a sound when a gate stop is waiting; and a
`PreToolUse` guard on `Bash` that refuses a `git commit` or `git push` while you stand on the base branch.
All three are POSIX `sh`, use no `jq`, and otherwise no-op rather than block on anything they cannot read.
The permission pack for this surface is rendered from
[`../../contracts/permissions.json`](../../contracts/permissions.json) by the warm-up.

**Subagents and models.** Reviewers and workers are raised as subagents titled
`<skill> · <persona> · <model alias>`, on the tier `nen/workflow.json` → `models.roles` names for the
role, never on the frontier tier where your own conversation lives. Which model `hatsu:direct`
recommends for a piece of work, on which surface and at what effort, is
[`../DIRECT-MATRIX.md`](../DIRECT-MATRIX.md).

## 4 · Maintenance

**To update**, type `/hatsu:bakuryuha` in any session: it fast-forwards the checkout, re-proves the
warm-up from the new files, reads back what is served, and ends with the one line left to type. By hand:

```sh
~/Code/Agents/hatsu/scripts/hatsu_plugin_update.sh --root ~/Code/Agents/hatsu --channel trunk --claude
```

Then type `/reload-plugins` in the running session, or open a new one: no app restart and no
`claude plugin update` ([`docs/surfaces/claude-code.md`](../surfaces/claude-code.md) § 9).
`/hatsu:ten` runs the same update with `--auto --claude` at every warm-up.

| What is served | How it updates | Next, to use it |
|---|---|---|
| the checkout, in place, through `~/.claude/skills/hatsu` (`hatsu@skills-dir`) | `scripts/hatsu_plugin_update.sh --claude`: fast-forward the linked checkout; no `claude plugin update` | **type `/reload-plugins`**, or open a new session: no app restart |
| a legacy cache install, `~/.claude/plugins/cache/hatsu/hatsu/<version>/` | `hatsu:bakuryuha` retargets it onto the link (`scripts/hatsu_surface_link.sh --surface claude-code`) | as above |

### Targeting a local checkout

```sh
git clone https://github.com/zheref/hatsu.git ~/Code/Agents/hatsu   # or your existing clone
export HATSU_PLUGIN_ROOT="$HOME/Code/Agents/hatsu"                 # shell profile
"$HATSU_PLUGIN_ROOT/scripts/hatsu_surface_link.sh" --surface claude-code --root "$HATSU_PLUGIN_ROOT"
```

`claude plugin list --json` must show `hatsu@skills-dir` enabled at that checkout.
After the checkout moves, type `/reload-plugins` or open a new session.

## 5 · Uninstall and rollback

Nothing server-side changed, so rollback is removing the install:

- **Skills-directory install**: remove the `~/.claude/skills/hatsu` link, then `/reload-plugins` or a new
  session. The checkout itself is yours to keep or delete.
- **Marketplace install**: `claude plugin uninstall hatsu@hatsu`, and remove the `hatsu` marketplace
  declaration from your `~/.claude/settings.json` if you do not want a reload to clone it back.

`scripts/hatsu_surface_link.sh --surface claude-code --status` reads back what the surface serves without
changing anything.

## 6 · Caveats

- **Keep the checkout on `main`.** Whatever it holds is what every session serves; an authoring branch
  checked out there is what `/hatsu:ten` will load. `--auto` updates skip an authoring branch on purpose.
- **`$CLAUDE_PLUGIN_ROOT` is this surface's variable**, set inside a skill invocation and nowhere else. It
  is exported by some shells onto other surfaces, which is why the warm-up resolves `$HATSU_PLUGIN_ROOT`
  first ([the hub](README.md#a-checkout-you-keep)).
- **Set `includeCoAuthoredBy: false`** in your settings so the harness stops adding `Co-Authored-By:`;
  `kokusen` and `aka` refuse to write that trailer ([`../../CONTRIBUTING.md`](../../CONTRIBUTING.md)).

## Sources

- [`../surfaces/claude-code.md`](../surfaces/claude-code.md), the dated checklist and known gaps
- [`mirrors.md`](mirrors.md), generated versus authored, regenerating, and the check
- [`../../scripts/hatsu_surface_link.sh`](../../scripts/hatsu_surface_link.sh) · [`../../scripts/hatsu_plugin_update.sh`](../../scripts/hatsu_plugin_update.sh)
- [`../../hooks/hooks.json`](../../hooks/hooks.json), the three hooks and their rationale
