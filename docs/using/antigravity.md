# Hatsu on Antigravity

> **Setup · usage · maintenance** for the Antigravity surface (the IDE and the `agy` CLI). The
> cross-surface requirements, the checkout you keep and the update table are in [the hub](README.md);
> the surface's evolution record is [`../surfaces/antigravity.md`](../surfaces/antigravity.md).

| | |
|---|---|
| **How Hatsu arrives** | the checkout's generated plugin, `surfaces/antigravity/`, linked in place as the global plugin at `~/.gemini/config/plugins/hatsu`; or, per repository, a workspace bootstrap under `.agents/` |
| **Skills read from** | the plugin's `skills/<name>/SKILL.md`; workspace mode: `<repo>/.agents/skills/<name>/` |
| **Personas** | the plugin's `agents/<persona>.md`; workspace mode: `<repo>/.agents/agents/` |
| **You type** | `/<skill>`: `/ten`, `/ren`, `/aka`, `/mukai` |
| **Gate questions** | `ask_question`, the surface's own picker; the bell is the native `Stop` hook |
| **Update** | `/bakuryuha`; a commit to the checkout is served from the next conversation |

---

## 1 · Requirements

- The host: the Antigravity IDE, or the `agy` CLI.
- Signing in: a Google Account through the Antigravity harness.
- The shared three (`nen`, `git` + `gh`, a `nen/contract.json`), plus `python3` on the installed plugin
  path: [the hub's *Requirements*](README.md#requirements).
- A checkout, with `HATSU_PLUGIN_ROOT` pointing at it: [the hub's *A checkout you keep*](README.md#a-checkout-you-keep).

## 2 · Setup

Antigravity supports two modes. **Global plugin mode is the first-party install**; workspace bootstrap
is the per-repository fallback.

### Global Plugin Mode (Recommended)

Link Hatsu's generated Antigravity plugin into your global plugins directory, in place (a folder there
"activates across all workspaces on your workstation"):

```sh
"$HATSU_PLUGIN_ROOT/scripts/hatsu_surface_link.sh" --surface antigravity --root "$HATSU_PLUGIN_ROOT"
# = ln -s "$HATSU_PLUGIN_ROOT/surfaces/antigravity" ~/.gemini/config/plugins/hatsu, then agy plugin validate
```

**Link, never `agy plugin install`**: install copies into that same directory (evidence § 10 F8), which
would freeze the version and could write through an existing link. A commit to the checkout is served
from the next conversation; `/bakuryuha` fast-forwards it and ends with what to open.

The mirror follows the layout the Antigravity plugins page documents ([`docs/surfaces/antigravity.md`](../surfaces/antigravity.md) § 1; the CLI reader is a named gap in its § 10):
- `plugin.json` — Antigravity plugin manifest
- 59 skills (fifty-eight plus `ten`), each at `skills/<name>/SKILL.md`, invoked as `/<name>`
- `rules/hatsu.md` — the identity rules file, under Antigravity's 12,000-character limit
- `agents/<persona>.md` — every persona — Kurapika, the twelve independents and the four intake examiners — plus the preamble include
- `hooks.json` — native `PreToolUse` (trunk guard), `PreInvocation` (refresh) and `Stop` (bell) lifecycle hooks

In this mode, no files are written into your target repositories. Open any workspace in Antigravity or use the CLI (`agy`), and run `/ten`.

### Workspace Bootstrap Mode

To use Hatsu in a single repository without a global plugin:

```sh
"$HATSU_PLUGIN_ROOT/scripts/surface_bootstrap.sh" --surface antigravity --target . --bootstrap
```

Open Antigravity in that repository and run `/ten`. The warm-up performs `--install-all`, placing:

| | |
|---|---|
| `<repo>/.agents/skills/<name>/` | **59** mirrored skill directories — the fifty-eight plus `ten` itself — copied from `surfaces/antigravity/skills/<name>/` |
| `<repo>/.agents/agents/<persona>.md` | every persona — Kurapika, the twelve independents and the four intake examiners — plus the preamble include, copied from `surfaces/antigravity/agents/` |
| `<repo>/.agents/rules/hatsu.md` | The identity rules file, under the 12,000-character limit a rules file has |
| `<repo>/.agents/hooks.json` | Native `PreToolUse` (trunk guard), `PreInvocation` (refresh) and `Stop` (bell) hooks |
| `<repo>/.agents/hooks/` | Self-contained hook scripts (`guard-base-branch.sh` and `stop-bell.sh`) |

Everything is cleanly excluded through `.git/info/exclude`; `.gitignore` is never modified.

**Native Lifecycle Hooks:**
- **Trunk Protection (`PreToolUse`)**: `hooks/guard-base-branch.sh` intercepts shell commands before execution. It prevents accidental commits, rebases, or edits directly on `main` or other protected trunk branches without an isolated feature branch.
- **Completion Bell (`Stop`)**: `hooks/stop-bell.sh` fires at turn completion to ring the local audio and notification bell when human review or decision is needed.

**In-Session Subagents:**
Every reviewer `hanten` raises (the personas `review.scopes` routes: Nobunaga, Feitan, Chrollo, Hisoka, Uvogin, Phinks, Leorio) runs as an isolated subagent via `invoke_subagent` with `Workspace: "branch"`, at the tier `models.roles.reviewer` names (`pro`; a persona pinned to a fast model keeps its pin). Workers and measurers run on `fast` (`flash`), maximizing throughput and SWE-bench efficiency under Google AI Pro or Ultra subscriptions.

## 3 · Usage

```
/ten                                     # once per session: verify nen, read the plugin back
/ren Add a "Clear all" action to the notifications list, with a confirmation sheet
/aka
/mukai
```

Kurapika is the persona through the plugin's `agents/kurapika.md`; `/ren` runs as him, and reviewers are
raised as isolated subagents (§ 2 above). A gate question is asked through `ask_question`; the bell is the
plugin's `Stop` hook. Every turn that renders a report writes it as a **native artifact** before yielding,
`spiritual-message.md` for a turn or landing report. Its body is `nen report render`'s fill of
`templates/spiritual-message.md` or `templates/rikugan.md`, copied verbatim and never composed by hand
([`PROCESS.md`](../PROCESS.md) § *The Markdown report*), and a chat summary never stands in for it.

**Headless**: `agy --model pro "<prompt>"` in the target repository.

**Models.** A persona's `model:` accepts only `inherit`, `flash` or `pro` on this surface, so the
`models.antigravity` block maps `economy` to `flash`. Which model `hatsu:direct` recommends for a job, and
when this surface is the recommended one, is [`../DIRECT-MATRIX.md`](../DIRECT-MATRIX.md).

## 4 · Maintenance

| What is served | How it updates | Next, to use it |
|---|---|---|
| `~/.gemini/config/plugins/hatsu` → `<checkout>/surfaces/antigravity`, in place | fast-forward the checkout; the link follows | a new conversation; the CLI's `/skills reload` (≥ 1.2.4) |
| workspace bootstrap (legacy): copies under `<repo>/.agents/` | fast-forward, then `/ten` re-copies | a new conversation |

`/bakuryuha` makes the global link where `.agents/` copies stood, fast-forwards the checkout the link
names, validates the plugin with `agy plugin validate`, and ends with what to open. By hand:

```sh
mkdir -p ~/.gemini/config/plugins
ln -sfn "$HATSU_PLUGIN_ROOT/surfaces/antigravity" ~/.gemini/config/plugins/hatsu
```

The linked folder carries the documented plugin layout (`plugin.json`, `skills/`, `agents/`, `rules/`,
`hooks.json`). Authority for the rest of the mechanism: [the hub](README.md) and [`mirrors.md`](mirrors.md).

## 5 · Uninstall and rollback

Nothing server-side changed. Remove the `~/.gemini/config/plugins/hatsu` link for the global plugin. For a
workspace bootstrap, delete `<repo>/.agents/skills/`, `.agents/agents/`, `.agents/rules/hatsu.md`,
`.agents/hooks.json` and `.agents/hooks/` in that repository; all of them are recorded in its
`.git/info/exclude`, never in `.gitignore`. The checkout is yours to keep.

## 6 · Caveats

- **Link, never `agy plugin install`**: install copies into the same directory, which would freeze the
  version and could write through an existing link.
- **Workspace mode needs its native hooks** under `.agents/hooks/` and `.agents/hooks.json`, excluded
  through `.git/info/exclude`; the trunk guard and the bell do not run without them.
- **Rules files are capped at 12,000 characters** on this surface; `rules/hatsu.md` is held under it by
  `scripts/prose_size_check.sh`.
- **The CLI's plugin reader is a named gap** in the evolution record's § 10; what is asserted here was
  read from the IDE's plugins page and the recorded runs.

## Sources

- [`../surfaces/antigravity.md`](../surfaces/antigravity.md), the dated checklist, artifacts, subagent delegation
- [`mirrors.md`](mirrors.md), generated versus authored, regenerating, and the check
- [`../../scripts/hatsu_surface_link.sh`](../../scripts/hatsu_surface_link.sh) · [`../../scripts/surface_bootstrap.sh`](../../scripts/surface_bootstrap.sh)
