# Codex

**Codex installs Hatsu first-party, as a plugin, from the maintainer's own checkout** (from v0.66.0):
Codex reads the checkout's `.claude-plugin/marketplace.json` as a legacy-compatible marketplace, and the
`.codex-plugin/plugin.json` overlay hands it the canonical `claude/skills/` (listed `hatsu:<name>`, the
spelling the bodies carry) and the generated Codex hooks. The plugin carries no personas, so the warm-up
still places the instruction override and the project-scoped agent files; the skill copies and the hooks
file it used to place are the legacy form, removed in plugin mode (`surface_bootstrap.sh --plugin`).
**Correction, 2026-09-20: Codex has hooks.** The official hooks page documents `Stop` and `SessionStart`
among twelve events.

## 1. Identity and paths

| | |
|---|---|
| how Hatsu arrives | **the Hatsu plugin**: `codex plugin marketplace add <checkout>` then `codex plugin add hatsu@hatsu` (`scripts/hatsu_surface_link.sh --surface codex`); Codex **copies** the whole checkout, ignored worktrees included, into `$CODEX_HOME/plugins/cache/hatsu/hatsu/<version>/` (evidence § 10 F4–F7). Legacy form: a checkout, one bootstrap (`scripts/surface_bootstrap.sh --surface codex --target . --bootstrap`), then `$ten` placing `.agents/skills/` copies |
| skills read from | the plugin: `<cache slot>/claude/skills/<name>/SKILL.md` (`.codex-plugin/plugin.json` → `"skills": "./claude/skills/"`; without it the overlay finds none, evidence § 10 F5). Legacy: `<repo>/.agents/skills/<name>/SKILL.md`, scanned upward; also `$HOME/.agents/skills` and `/etc/codex/skills` |
| personas read from | `<repo>/AGENTS.override.md` as prose (all personas, one `## <name>` section each) and `<repo>/.codex/agents/<persona>.toml` as project-scoped custom agents |
| config read from | `~/.codex/config.toml` (user), `.codex/config.toml` (project, trusted projects only) |
| hooks read from | the plugin's `.codex-plugin/plugin.json` → `"hooks": "./surfaces/codex/hooks.json"`, the generated rows, run with `PLUGIN_ROOT` set; `~/.codex/hooks.json` and `<repo>/.codex/hooks.json` (legacy placement) |
| invocation spelling | `$hatsu:<name>` under the plugin (the documented `$<plugin>:<skill>` form); `$<name>` for a legacy placed copy |
| worktrees | the app's own: "Codex creates worktrees in `$CODEX_HOME/worktrees`." / "To choose another location, open **Settings > Worktrees** and change **Worktree root**." (https://learn.chatgpt.com/docs/environments/git-worktrees, 2026-09-30) — one global root, outside the workspace but inside the tool's home; accepted as it comes, never a sibling. **Hatsu-made** (hanten's second `codex exec`, a lead-session effort): `<core>/.nen/worktrees/codex/<name>`, removed when the effort lands — `docs/WORKFLOW.md` § *Where worktrees live* |
| headless command | `codex exec -C <repo> -s workspace-write --add-dir "$(git -C <repo> rev-parse --path-format=absolute --git-common-dir)" -m "$sol" "<prompt>"`, with `sol` resolved live from `codex debug models`; a G5 is answered with `codex exec resume --last -m "$sol" --skip-git-repo-check -c 'sandbox_workspace_write.writable_roots=[…]' -o <file> "<answer>"`. The full record, including why `--add-dir` is mandatory in a linked worktree and which flags `resume` refuses, is [`evidence/surfaces.md`](evidence/surfaces.md) § 7 F3, F6 and Appendix A |
| pointing at a local checkout | the marketplace **is** the local checkout; after it moves, `codex plugin add hatsu@hatsu` again (Codex does not notice a newer source, evidence § 10 F6), which `scripts/hatsu_plugin_update.sh --codex` does |
| update and activation | `hatsu:bakuryuha`: § 3 installs the plugin where copies were placed, § 4 fast-forwards the marketplace checkout and re-adds the plugin, the new `ten` places personas only (`--plugin`); running sessions refresh skills and hooks after an external plugin upgrade (codex-cli 0.154.0), personas load at the next run, and a changed hook is skipped until trusted in `/hooks` (§ 9, § 10) |
| validated build | `codex-cli 0.149.0` (`codex --version`, read live 2026-09-10); no skills-support floor is documented |

**What the plugin install copies.** `codex plugin add` copies the whole marketplace root, `.git` and every
git-ignored path included (`.claude/settings.local.json`, `.claude/worktrees/`, `.nen/`, `Reports/`), into
`$CODEX_HOME/plugins/cache/hatsu/hatsu/<version>/`, and the next `add` replaces that slot (evidence § 10
F6, F7). Serving a clean tree instead is zheref/hatsu#147. **The plugin's hooks run the source
`hooks/*.sh`** of that slot, which carry no generated marker, so `session-start.sh` takes its reminder
branch on purpose: its mirror-refresh branch would re-place the skill copies the plugin replaces. Trust
in `/hooks` covers a hook's definition; the scripts behind it change with each installed version.

**Copies, not symlinks — the legacy placement.** Codex lists a skill under its frontmatter `name`, namespaced by the plugin
manifest above the directory the path resolves to: a symlink into this checkout (which carries
`.claude-plugin/plugin.json`) is listed as `hatsu:aka`, a `cp -R` of the same directory as bare `aka`,
which is the spelling the mirror bodies carry (evidence § 7 F1). The plugin install makes that
namespacing the rule instead: `hatsu:aka` everywhere, the canonical bodies unchanged.

**`AGENTS.override.md` replaces `AGENTS.md`** rather than joining it, so the warm-up writes the whole
file: the target's own `AGENTS.md` verbatim, re-read every warm-up, then the generated block between its
`BEGIN`/`END hatsu personas` markers. A tracked `AGENTS.md` is never written. The override is untracked
and excluded, and an unexcluded untracked file makes `nen shu warmup` refuse at exit 2, which stops
`breath` and `aka`: those two sentences are one rule.

**A persona on Codex is prose and does not win an identity argument with the host.** A user-level
instruction saying "introduce yourself as X" keeps saying X while the work is done in Kurapika's
discipline (§ 7 F11). The record of who acted is Hatsu's own: `--who` on `nen stop`, the `who` field of
`.nen/last-stop.json`, the `Hatsu-Agent` trailer.

**Untrusted projects skip every `.codex/` layer**, config, hooks and rules included, so a target that
has not been trusted runs with the user's config and none of the pack.

## 2. Skills

| | |
|---|---|
| file | `.agents/skills/<name>/SKILL.md` |
| frontmatter kept by the mirror | `name`, `description` |
| description guidance | "Explain exactly when this skill should and should not trigger." |
| list budget | the skill list is capped at 2% of the model's context window, or 8,000 characters; descriptions are shortened to fit |
| name listed as | bare `name` for a copy; `<plugin>:<name>` through a symlink into a plugin root |

The cut length is not a constant. Measured from `prompt-input` renders (evidence § 7 F7): with 51 skills
visible the longest surviving description was 411 characters; with 87 visible every Hatsu description was
cut to 186 to 190 characters, mid-clause. Hatsu cannot fix this by shortening to fit, because there is
no number to fit inside; the authoring rule is to lead every description with what the skill does, then
its trigger, then its never-clauses, inside the first ~180 characters.

## 3. Personas and model config

| | |
|---|---|
| prose file | `AGENTS.override.md`, one `## <name>` section per persona; `AGENTS.override.md` wins over `AGENTS.md` when present; 32 KiB default cap (`project_doc_max_bytes`) |
| agent file | `.codex/agents/<persona>.toml`, project-scoped; `~/.codex/agents/` for personal ones |
| required keys | `name`, `description`, `developer_instructions` |
| optional keys | `model`, `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, `skills.config` |
| precedence | a `model` or `model_reasoning_effort` in the agent file wins over `[agents]` defaults |
| `[agents]` fragment | `agents.enabled`, `agents.default_subagent_model`, `agents.default_subagent_reasoning_effort`, `agents.max_concurrent_threads_per_session` (`agents.max_threads` legacy), `agents.interrupt_message`; `features.multi_agent` is stable and on by default |
| tier aliases (`nen/workflow.json` → `models.codex`) | frontier `astra`, deep `sol`, fast `terra`, economy `luna` |

The generator writes the `[agents]` fragment from the matrix rows: `default_subagent_model` is the
worker tier's alias, resolved to the id the host serves today only at run time. A versioned id never
lands in a config file; `models.rule` forbids it, and the id moves (evidence § 3.5: `gpt-5.6-sol` today,
no bare `sol`, no `gpt-6-sol`).

In-session delegation is `spawn_agent`. Hanten's isolated reviewer still runs as a second `codex exec`
in a worktree at `<core>/.nen/worktrees/codex/hanten-<persona>` (§ 1), because that reviewer must not
share the author's tree.

## 4. Hooks

| | |
|---|---|
| file | `<repo>/.codex/hooks.json`; `~/.codex/hooks.json`; plugin `hooks/hooks.json` |
| feature key | `hooks` (canonical); `codex_hooks` still works |
| events | `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`, `UserPromptSubmit`, `SubagentStop`, `Stop`, `SessionStart`, `SubagentStart`, `Interrupt`, `SessionEnd` |
| decision shape | `"permissionDecision": "deny"`; `ask` and the legacy `decision: "approve"` are parsed but not supported yet |
| what Hatsu installs | `SessionStart` → `surface_bootstrap.sh --surface codex --target . --install-all` when `HATSU_PLUGIN_ROOT` is set; `Stop` → `hooks/stop-bell.sh`; `PreToolUse` → `hooks/guard-base-branch.sh` (deny on the base branch) |

Because `ask` is not honoured, the guard answers `deny` with a reason and never `ask`. The bell on this
surface rings through the `Stop` hook exactly as on Claude Code; `jutaisho`'s in-session fallback runs
only where `.codex/hooks.json` was not placed.

## 5. Permissions

| | |
|---|---|
| file | `.codex/config.toml` (project, trusted only) |
| keys | `approval_policy` (`on-request`, `never`, `{ granular = { sandbox_approval = bool, … } }`; `untrusted` is retired), `sandbox_mode` (`read-only`, `workspace-write`, `danger-full-access`), `sandbox_workspace_write.writable_roots` |
| scope | a root list, the one surface where the contract's scope is enforced as roots: the checkout, its linked worktrees (`git rev-parse --git-common-dir`), and the associated repositories `nen/repos.json` declares |
| what the pack renders | `approval_policy`, `sandbox_mode = "workspace-write"`, `writable_roots = [...]`; `--add-dir` on the command line is the same widening for one run |

A linked worktree keeps `HEAD`, the index, objects, `refs/` and `info/exclude` under the main
repository's `.git/`, outside a `workspace-write` sandbox, so every git write is refused at exit 128
("Operation not permitted") until the common dir is a writable root. Reproduced both ways on a fixture
(evidence § 7 F3). A skill cannot add the root to a running session: it reports the condition and stops.

## 6. Rules

`AGENTS.md`, or `AGENTS.override.md` when it exists, read as prose up to `project_doc_max_bytes` (32 KiB
by default). Hatsu writes the override only, whole, untracked and excluded; the persona block sits
between markers so a later warm-up can replace it and nothing else. There is no separate rules file.

## 7. The option picker

`request_user_input`: one to three short questions, each with options, blocking. The ChatGPT app can
collect several ticked answers on one question; the CLI TUI selects one option per question. The only
official mention is the app-server protocol's `tool/requestUserInput`, marked experimental; no
user-facing page names the tool, so the checklist row cites the protocol page.

## 8. Generation

```sh
nen surface mirror generate --surface codex \
  --source claude/skills --agents claude/agents --out surfaces/codex \
  --invocation-prefix hatsu: --models nen/workflow.json \
  --permissions contracts/permissions.json --hooks hooks/hooks.json \
  --rules claude/rules/hatsu.md --source-surface claude \
  --hooks-root <root expression> --manifest .claude-plugin/plugin.json --stamp <plugin version>
```

| emits | from |
|---|---|
| `surfaces/codex/<name>/SKILL.md`, 49 files (forty-eight plus `ten`), frontmatter reduced to `name` and `description`, `hatsu:<name>` respelled `$<name>` | `claude/skills/**` |
| `surfaces/codex/AGENTS.md`, the appendix the warm-up copies into `AGENTS.override.md` after the target's own `AGENTS.md`, twelve personas plus the preamble include as sections (`## _review-preamble`) | `claude/agents/**` |
| `surfaces/codex/agents/<persona>.toml`, one per persona, `name`, `description`, `developer_instructions`, `model` from the persona's tier | `claude/agents/**` and `nen/workflow.json` |
| `surfaces/codex/config.toml`, the pack: `approval_policy`, `sandbox_mode`, `writable_roots` | `contracts/permissions.json` |
| `surfaces/codex/config.toml.fragment`: `[agents]` with `default_subagent_model` only, from the matrix row | `nen/workflow.json` |
| `surfaces/codex/hooks.json`: `SessionStart`, `PreToolUse`, `Stop`, rooted at `${PLUGIN_ROOT:-${HATSU_PLUGIN_ROOT:-./.codex}}` — the installed slot Codex hands a plugin hook first, then the export, then the placed copy — so a plugin hook (named by the overlay) never runs a live-checkout or working-directory script (Feitan, CWE-426). The legacy placement is a project-local hook, which Codex never hands a `PLUGIN_ROOT`, so `surface_bootstrap.sh` places it rewritten to `${HATSU_PLUGIN_ROOT:-./.codex}`: a stray `PLUGIN_ROOT` in the user's environment cannot redirect it | `hooks/hooks.json` |

Marker, first markdown line after the frontmatter fence, line 1 in `AGENTS.md` and the TOML files:

```text
<!-- GENERATED by nen surface mirror (surface: codex, stamp: 0.43.0) -- do not edit; edit the source and regenerate -->
```

The check against a WHOLE mirror copy (`--installed` diffs the full layout, so the skills-only copy the
warm-up places under `.agents/skills` reads `missing` under it — zheref/hatsu#106); the warm-up runs
`scripts/surface_mirror_check.sh` on the source and then `surface_bootstrap.sh --install-all` (ten § 5):

```sh
nen surface mirror check --surface codex <same flags> --installed <a whole surfaces/codex copy>
```

## 9. Dated checklist

| fact | value | quoted line | source | fetched |
|---|---|---|---|---|
| user config | `~/.codex/config.toml` | "add project overrides with `.codex/config.toml` files" | https://learn.chatgpt.com/docs/config-file/config-basic | 2026-09-20 |
| project config trust | trusted only | "Untrusted projects skip project-scoped .codex/ layers, including project-local config, hooks, and rules." | https://learn.chatgpt.com/docs/config-file/config-reference | 2026-09-20 |
| model key | string id | "model \| string \| Model to use (e.g., gpt-5.6-sol)." | https://learn.chatgpt.com/docs/config-file/config-reference | 2026-09-20 |
| approval policy | `on-request`, `never`, granular | "approval_policy \| on-request \| never \| { granular = { sandbox_approval = bool, …" | https://learn.chatgpt.com/docs/config-file/config-reference | 2026-09-20 |
| `untrusted` retired | yes | "Migrate from the retired untrusted approval policy" | https://learn.chatgpt.com/docs/config-file/config-reference | 2026-09-20 |
| sandbox modes | three | "sandbox_mode \| read-only \| workspace-write \| danger-full-access" | https://learn.chatgpt.com/docs/config-file/config-reference | 2026-09-20 |
| writable roots | `sandbox_workspace_write.writable_roots` | "Additional writable roots when sandbox_mode = \"workspace-write\"." | https://learn.chatgpt.com/docs/config-file/config-reference | 2026-09-20 |
| subagent default model | `agents.default_subagent_model` | "agents.default_subagent_model \| string \| Default model for spawned agents." | https://learn.chatgpt.com/docs/config-file/config-reference | 2026-09-20 |
| multi-agent feature | stable, on | "Enable multi-agent collaboration tools (spawn_agent, send_input, …) (stable; on by default)." | https://learn.chatgpt.com/docs/config-file/config-reference | 2026-09-20 |
| hooks files | user and repo | "~/.codex/hooks.json … <repo>/.codex/hooks.json" | https://learn.chatgpt.com/docs/hooks | 2026-09-20 |
| hook events | 12 | "PreToolUse, PermissionRequest, PostToolUse, PreCompact, PostCompact, UserPromptSubmit, SubagentStop, Stop" plus `SessionStart`, `SubagentStart`, `Interrupt`, `SessionEnd` | https://learn.chatgpt.com/docs/hooks | 2026-09-20 |
| feature key | `hooks` | "Use hooks as the canonical feature key. codex_hooks still works" | https://learn.chatgpt.com/docs/hooks | 2026-09-20 |
| deny shape | `permissionDecision: deny` | "\"permissionDecision\": \"deny\"" | https://learn.chatgpt.com/docs/hooks | 2026-09-20 |
| ask unsupported | parsed, not honoured | "permissionDecision: \"ask\", legacy decision: \"approve\", … are parsed but not supported yet." | https://learn.chatgpt.com/docs/hooks | 2026-09-20 |
| plugin hooks | `hooks/hooks.json` | "By default, Codex looks for hooks/hooks.json inside the plugin root." | https://learn.chatgpt.com/docs/hooks | 2026-09-20 |
| skills path | `.agents/skills`, upward | "Codex scans .agents/skills in every directory from your current working directory up" | https://learn.chatgpt.com/docs/build-skills | 2026-09-20 |
| description guidance | when and when not | "description: Explain exactly when this skill should and should not trigger." | https://learn.chatgpt.com/docs/build-skills | 2026-09-20 |
| list budget | 2% or 8,000 chars | "at most 2% of the model's context window, or 8,000 characters when" | https://learn.chatgpt.com/docs/build-skills | 2026-09-20 |
| agent file paths | personal and project | "~/.codex/agents/ for personal agents or .codex/agents/ for project-scoped" | https://learn.chatgpt.com/docs/agent-configuration/subagents | 2026-09-20 |
| agent required keys | three | "Every standalone custom agent file must define: name description developer_instructions" | https://learn.chatgpt.com/docs/agent-configuration/subagents | 2026-09-20 |
| agent model precedence | file wins | "If a custom agent file sets model or model_reasoning_effort, the value in the file takes precedence." | https://learn.chatgpt.com/docs/agent-configuration/subagents | 2026-09-20 |
| option picker | `tool/requestUserInput` | "tool/requestUserInput - prompt the user with 1-3 short questions … (experimental)" | https://learn.chatgpt.com/docs/app-server | 2026-09-20 |
| instructions override | `AGENTS.override.md` | "Codex reads AGENTS.override.md if it exists. Otherwise, Codex reads AGENTS.md." | https://learn.chatgpt.com/docs/agent-configuration/agents-md | 2026-09-20 |
| instructions cap | 32 KiB | "limit defined by project_doc_max_bytes (32 KiB by default)" | https://learn.chatgpt.com/docs/agent-configuration/agents-md | 2026-09-20 |
| skill changes | picked up in-session | "Codex detects skill changes automatically. If an update doesn’t appear, restart Codex." | https://learn.chatgpt.com/docs/build-skills | 2026-09-29 |
| config changes | on restart | "Restart Codex after changing ~/.codex/config.toml." | https://learn.chatgpt.com/docs/build-skills | 2026-09-29 |
| when instructions load | once per run or TUI session | "Codex builds an instruction chain when it starts (once per run; in the TUI this usually means once per launched session)." | https://learn.chatgpt.com/docs/agent-configuration/agents-md | 2026-09-29 |
| changed hooks | skipped until re-trusted | "Codex records trust against the hook’s current hash, so new or changed hooks are marked for review and skipped until trusted." | https://learn.chatgpt.com/docs/hooks | 2026-09-29 |
| marketplace from a checkout | `.claude-plugin/marketplace.json` read as is | "a legacy-compatible marketplace at `$REPO_ROOT/.claude-plugin/marketplace.json`" | https://developers.openai.com/plugins/build/plugins | 2026-09-29 |
| Claude-compatible manifests | accepted | "OpenAI also accepts legacy and Claude-compatible manifests, but new packages should use this format." | https://developers.openai.com/plugins/build/plugins | 2026-09-29 |
| overlay hooks | declared in `.codex-plugin/plugin.json` | "Legacy packages can declare `hooks` directly in `.codex-plugin/plugin.json`." | https://developers.openai.com/plugins/build/plugins | 2026-09-29 |
| plugin hook root | `PLUGIN_ROOT` | "`PLUGIN_ROOT` points to the installed plugin root" | https://developers.openai.com/plugins/build/plugins | 2026-09-29 |
| plugin hooks trusted | never automatically | "Installing or enabling a plugin doesn't automatically trust its hooks." | https://developers.openai.com/plugins/build/plugins | 2026-09-29 |
| what loads | the installed copy | "ChatGPT loads the installed copy from that cache path rather than directly from the marketplace entry." | https://developers.openai.com/plugins/build/plugins | 2026-09-29 |
| running sessions after an upgrade | skills and hooks refresh (release notes) | "Existing sessions pick up newly installed plugin tools and refresh skills and hooks after external plugin upgrades or rollbacks." | https://github.com/openai/codex/releases/tag/rust-v0.154.0 | 2026-09-29 |
| the install, live | copies, `hatsu:<name>`, re-add to update | evidence § 10 F4–F7 (codex-cli 0.154.0, an isolated `CODEX_HOME`) | [evidence § 10](evidence/surfaces.md) | 2026-09-29 |

`developers.openai.com/codex/*` redirects to `learn.chatgpt.com/docs/*`; the URLs above are the
destination.

## 10. Known gaps (not documented)

- A user-facing page for `request_user_input`; only the app-server protocol names it.
- A per-skill description cap; the documented budget is for the whole list.
- `.codex/skills` as a skills path; the documented path is `.agents/skills`.
- A minimum CLI build for skills support.
- Whether `Stop` fires on a `codex exec` run's final turn the way it does in the TUI (not exercised).
- Whether a session honours a skill body it already read once the file changes. The pages say only that changes are detected; the pull request that added the detection (https://github.com/openai/codex/pull/10478, fetched 2026-09-29) says "if it has already read the contents of a modified skill, it will not honor the new behavior" and that new skills are not announced to the model. `hatsu:bakuryuha` § 5 therefore reads changed bodies from disk rather than trusting the detection.

## 11. How this guide evolves

`hatsu:great-hiker` re-fetches the nine URLs above, diffs every quoted line, and files one Netero-shaped
issue for this surface when one moved, naming the row, the generator rule it reaches
(`src/surface/rules.ts` in nen), the pack renderer, and the warm-up section. The `ask` row is the one to
watch: the day Codex honours it, the guard may answer `ask` instead of `deny`.
