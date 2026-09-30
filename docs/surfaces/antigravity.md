# Antigravity

Antigravity reads Hatsu either as a global plugin or from `.agents/` inside the repository. From v0.43.0
its mirror comes from the same generator as the other two; the second generator
(`scripts/antigravity_mirror_sync.sh`, with its own marker, its own tier remap and an unanchored
`gsub(/hatsu:/, "/")`) is retired. **Corrections, 2026-09-20:** the workspace paths are `.agents/…`
(`.agent/…` is back-compatibility only); the global plugin path is `~/.gemini/config/plugins/<name>`;
a rules file is limited to 12,000 characters, so the personas cannot ride in one rules document;
workflows are deprecated and retire on 2026-11-01, so nothing here emits a workflow.

## 1. Identity and paths

| | |
|---|---|
| how Hatsu arrives | **the global plugin, first-party and in place**: `~/.gemini/config/plugins/hatsu` is a link to `<checkout>/surfaces/antigravity`, the generated plugin (`scripts/hatsu_surface_link.sh --surface antigravity`); the IDE reads it, and `agy` 1.0.6 installs into the same directory (evidence § 10 F8). `agy plugin install` **copies**, so it is never run over the link. Legacy form: `scripts/surface_bootstrap.sh --surface antigravity --target . --bootstrap`, then `/ten` placing `.agents/` copies |
| plugin layout | `plugin.json` (required), `hooks.json`, `mcp_config.json`, `skills/`, `agents/`, `rules/`; the mirror follows it: `skills/<name>/SKILL.md` plus `agents/`, `rules/hatsu.md`, `hooks.json`, `plugin.json` |
| skills read from | plugin `skills/<name>/SKILL.md` as the plugins page lays it out; workspace `<repo>/.agents/skills/<name>/SKILL.md`; global `~/.gemini/config/skills/` (IDE) or `~/.gemini/antigravity-cli/skills/` (CLI). The mirror is `surfaces/antigravity/skills/<name>/SKILL.md`, the documented layout, and the warm-up copies each `skills/<name>/` into `.agents/skills/` |
| personas read from | plugin `agents/<persona>.md`; workspace `<repo>/.agents/agents/<name>.md` or `.agents/agents/<name>/agent.md`; global `~/.gemini/config/agents/` |
| rules read from | plugin `rules/`; workspace `<repo>/.agents/rules/`; each file at most 12,000 characters |
| hooks read from | plugin `hooks.json`; workspace `<repo>/.agents/hooks.json`; global `~/.gemini/config/hooks.json` |
| invocation spelling | `/<name>` |
| headless command | `agy --model pro "<prompt>"` in the target repository |
| pointing at a local checkout | the global link names the checkout's `surfaces/antigravity`; a commit there is served from the next conversation, no copy to refresh |
| update and activation | `hatsu:bakuryuha`: § 3 makes the link where `.agents/` copies stood, § 4 fast-forwards the checkout the link names, and `agy plugin validate` reads the plugin back; a new conversation lists the updated skills, and the CLI's `/skills reload` (from v1.2.4, typed) reloads them in the running one (§ 9); the IDE documents no reload, so personas, rules and hooks there are claimed on restart only |
| back-compatibility | `.agent/rules` and `.agent/skills` are still read; Hatsu writes only `.agents/` |
| artifacts written to | `<appDataDir>/brain/<conversation-id>/` (supplied in agent context), tool `write_to_file` with `ArtifactMetadata` (`Summary`, `UserFacing`, `RequestFeedback`); markdown (`.md`) format with GFM tables, alerts (`> [!NOTE]`), and Mermaid |
| transcripts log | `<appDataDir>/brain/<conversation-id>/.system_generated/logs/transcript.jsonl` (and `transcript_full.jsonl`) |
| generative UI | `<agent-embed src="file:///<artifact_path>/widget.html"></agent-embed>` inline in conversation, or standalone in side pane |

In workspace mode the warm-up places `.agents/skills/`, `.agents/agents/`, `.agents/rules/hatsu.md`,
`.agents/hooks.json` and `.agents/hooks/`, all excluded through `info/exclude`. In global plugin mode
nothing is written into a target repository; the plugin's own `hooks.json` resolves its scripts through
`${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu/hooks/`.

Antigravity supports native **Artifacts**: structured deliverables (such as Implementation Plans,
walkthroughs, diagrams, and turn reports) that communicate progress and thinking asynchronously.
Artifacts reside in the session conversation store `<appDataDir>/brain/<conversation-id>/` and are
registered via the `write_to_file` tool by supplying the `ArtifactMetadata` object
(`{ Summary: string, UserFacing: boolean, RequestFeedback: boolean }`). `ArtifactMetadata` is reserved
for managed artifacts and is never passed when writing regular project source files to the workspace.
Native artifacts are authored in GitHub Flavored Markdown (`.md`) with GFM tables, alert callouts
(`> [!NOTE]`, `> [!IMPORTANT]`, `> [!WARNING]`, etc.), and Mermaid diagrams (````mermaid ... ````).
Interactive HTML widgets (Generative UI) can also be created as `.html` artifacts and embedded inline
into chat via `<agent-embed src="file:///<artifact_path>/widget.html"></agent-embed>`. Conversation
transcripts are captured per step in `<appDataDir>/brain/<conversation-id>/.system_generated/logs/transcript.jsonl`.

## 2. Skills

| | |
|---|---|
| file | `skills/<name>/SKILL.md` (plugin) or `.agents/skills/<name>/SKILL.md` (workspace) |
| frontmatter documented | `name` (optional), `description` (required): the triggering criteria |
| frontmatter kept by the mirror | `name`, `description` |
| name listed as | `/<name>` |
| size limit | none documented for a skill; 12,000 characters applies to rules files only |

## 3. Personas and model config

| | |
|---|---|
| file | `agents/<persona>.md` (plugin) or `.agents/agents/<name>.md` (workspace) |
| frontmatter documented | `name`, `description` (required); `tools[]`, `mainAgent`, `subagent`, `model`, `commandExecutionPolicy`, `mcpServers`, `skills`, `plugins` |
| model values | `inherit`, `flash`, `pro` |
| command policy | `commandExecutionPolicy`: `off`, `auto`, `eager`, `sandbox` (default `sandbox`) |
| tier aliases (`nen/workflow.json` → `models.antigravity`) | frontier `ultra`, deep `pro`, fast `flash`, economy `flash` (the key admits no `flash_lite`) |
| what the generator writes | `model` from the persona's own Claude alias read back to its tier (`--source-surface claude`) and mapped to this row's alias (`opus` → `pro`, `sonnet` and `haiku` → `flash`); an alias outside `inherit`, `flash`, `pro` is emitted and named under `undocumentedAliases`; `commandExecutionPolicy` left at the default, because a persona-wide `auto` would approve arbitrary commands rather than the declared set |

`ultra` is a matrix alias the persona key does not admit: the orchestrator tier never runs a subagent. In-session delegation is
`invoke_subagent` with `Workspace` `inherit`, `branch` (an isolated worktree, Hanten's reviewers) or
`share`. For `en`'s long watch, `en · illumi` can be raised on the fast tier (`flash`) with `Workspace` `inherit`.

## 4. Hooks

| | |
|---|---|
| file | `hooks.json` (plugin); `<repo>/.agents/hooks.json` (workspace); `~/.gemini/config/hooks.json` (global) |
| events | `PreToolUse`, `PostToolUse`, `PreInvocation`, `PostInvocation`, `Stop`; `PreInvocation`, `PostInvocation` and `Stop` carry the simpler structure |
| session start | there is no `SessionStart`; `PreInvocation` is the earliest event and is what Hatsu uses for the refresh |
| decision shape | top-level `decision`: `allow`, `deny`, `ask`, `force_ask`, `deny_unless_prior_grant`, with `reason` and `permissionOverrides[]`; `ask` respects "Always Allow" |
| what Hatsu installs | `PreInvocation` → `surface_bootstrap.sh --surface antigravity --target . --install-all` when `HATSU_PLUGIN_ROOT` is set and `.agents/` exists; `PreToolUse` on `run_command` → `hooks/guard-base-branch.sh` (`deny` on the base branch); `Stop` → `hooks/stop-bell.sh` |

The hook commands resolve their scripts through one expression, the `--hooks-root` the generator was
given: `${HATSU_PLUGIN_ROOT:-${GEMINI_CONFIG_DIR:-$HOME/.gemini}/config/plugins/hatsu}/hooks/`, so an
explicit `HATSU_PLUGIN_ROOT` wins and the global plugin path is the fallback. That is the TRACKED
mirror and the global-plugin install. A WORKSPACE install is different: `surface_bootstrap.sh` places
the hook scripts at `.agents/hooks/` and rewrites the PLACED `.agents/hooks.json` (never the tracked
mirror) to `${HATSU_PLUGIN_ROOT:-./.agents}/hooks/`, so the workspace copy comes last and only there;
the generator cannot emit that fallback itself because its root expression admits no command
substitution. A `PreInvocation` refresh fires on every invocation, not once per session, which is
why the refresh is idempotent: `surface_bootstrap.sh --install-all` replaces only what it placed and
reports installed/replaced/kept per name (ten § 5; the check-then-copy it once described is retired,
zheref/hatsu#106).

## 5. Permissions

| | |
|---|---|
| file | none per repository; permission is per agent through `commandExecutionPolicy`, and per user through the agent settings' Always Proceed and Deny list |
| scope | a policy, not a list of commands |
| what the pack renders | the hooks only: a persona-wide `auto` would approve arbitrary commands, so the trunk guard's `deny` is the enforcement and the declared allow set is not expressible here |

## 6. Rules

| | |
|---|---|
| file | `rules/<name>.md` (plugin) or `.agents/rules/<name>.md` (workspace) |
| limit | 12,000 characters per file |
| activation | Manual, Always on, Model decision (the model evaluates the rule's natural-language description), Glob |
| what the generator writes | `rules/hatsu.md` (`.agents/rules/hatsu.md` in workspace mode), Always on, under 12,000 characters: the identity block, the spelling, the tier aliases, where the personas and skills are, the gates that stay the maintainer's |

The former `rules/AGENTS.md` held every persona at ~119 KB, ten times the limit, and was read partially
or not at all. From v0.43.0 the personas live only in `agents/*.md` and the rules file points at them.
The Always-on `rules/hatsu.md` enforces that readiness is never claimed without quoting `nen pr ready`
at exit 0, and that pending CI, reviewer rounds, or open review threads strictly forbid premature G2/G4 claims.

## 7. The option picker

`ask_question`: multiple-choice questions, argument `questions` (an array of `question`, `options`,
`is_multi_select`). `jutaisho` sets `is_multi_select: true` when several options may all be true.

## 8. Generation

```sh
nen surface mirror generate --surface antigravity \
  --source claude/skills --agents claude/agents --out surfaces/antigravity \
  --invocation-prefix hatsu: --models nen/workflow.json \
  --permissions contracts/permissions.json --hooks hooks/hooks.json \
  --rules claude/rules/hatsu.md --source-surface claude \
  --hooks-root <root expression> --manifest .claude-plugin/plugin.json --stamp <plugin version>
```

| emits | from |
|---|---|
| `surfaces/antigravity/skills/<name>/SKILL.md`, 48 files (forty-seven plus `ten`), frontmatter reduced to `name` and `description`, `hatsu:<name>` respelled `/<name>` (anchored on the prefix, never a bare `gsub`) | `claude/skills/**` |
| `surfaces/antigravity/agents/<persona>.md`, 13 files (twelve personas plus the preamble include), `model` from the tier where admissible | `claude/agents/**`, `nen/workflow.json` |
| `surfaces/antigravity/rules/hatsu.md`, under 12,000 characters | the surface row and the matrix |
| `surfaces/antigravity/hooks.json`: `PreInvocation`, `PreToolUse` on `run_command`, `Stop` | `hooks/hooks.json` |
| `surfaces/antigravity/plugin.json`: `$schema`, `name`, `description`, `version` = the stamp | `.claude-plugin/plugin.json` |

Marker, first markdown line after the frontmatter fence, line 1 in a file without one, and the
`description` field in the JSON files:

```text
<!-- GENERATED by nen surface mirror (surface: antigravity, stamp: 0.43.0) -- do not edit; edit the source and regenerate -->
```

The check against a WHOLE mirror copy — the global plugin is one; the workspace `.agents/` copy is
skills-only and reads `missing` under `--installed` (zheref/hatsu#106), so the warm-up runs
`scripts/surface_mirror_check.sh` on the source and then `surface_bootstrap.sh --install-all` (ten § 5):

```sh
bash scripts/surface_mirror_check.sh "$HATSU_PLUGIN_ROOT"                                    # the warm-up's check: source vs surfaces/antigravity
nen surface mirror check --surface antigravity <same flags> --installed ~/.gemini/config/plugins/hatsu   # a whole mirror copy, by hand
```

## 9. Dated checklist

| fact | value | quoted line | source | fetched |
|---|---|---|---|---|
| rules path | `.agents/rules`, `.agent/rules` back-compat | "Antigravity defaults to .agents/rules, but still maintains backward compatibility for .agent/rules." | https://antigravity.google/docs/rules-workflows | 2026-09-20 |
| rules limit | 12,000 characters | "Rules files are limited to 12,000 characters each." | https://antigravity.google/docs/rules-workflows | 2026-09-20 |
| rules activation | four modes | "Model decision: the model dynamically evaluates the rule's natural language description" | https://antigravity.google/docs/rules-workflows | 2026-09-20 |
| workflows paths | global and workspace | "Scan both global (~/.gemini/config/workflows/) and workspace-level (.agents/workflows/) directories." | https://antigravity.google/docs/migration/workflows-to-skills/ | 2026-09-20 |
| workflows deprecated | retire 2026-11-01 | "Workflows are deprecated and will be retired on November 1, 2026." | https://antigravity.google/docs/migration/workflows-to-skills/ | 2026-09-20 |
| skills path | `.agents/skills`, `.agent/skills` back-compat | "Antigravity defaults to .agents/skills, but still maintains backward compatibility for .agent/skills." | https://antigravity.google/docs/skills | 2026-09-20 |
| skill frontmatter | name and triggering criteria | "Every SKILL.md file begins with YAML frontmatter defining its name and triggering criteria" | https://antigravity.google/docs/skills | 2026-09-20 |
| workspace hooks | `.agents/hooks.json` | "Workspace level: .agents/hooks.json at your project root." | https://antigravity.google/docs/hooks | 2026-09-20 |
| hook events | five, no SessionStart | "For PreInvocation, PostInvocation, and Stop, the structure is simpler" | https://antigravity.google/docs/hooks | 2026-09-20 |
| ask semantics | respects Always Allow | "\"ask\": Prompts the user, but respects \"Always Allow\" settings." | https://antigravity.google/docs/hooks | 2026-09-20 |
| option picker | `ask_question` | "ask_question: Ask multiple-choice questions." | https://antigravity.google/docs/hooks | 2026-09-20 |
| option picker arguments | questions array | "Arguments: questions (array of questions with question, options, is_multi_select)" | https://antigravity.google/docs/hooks | 2026-09-20 |
| global plugin path | `~/.gemini/config/plugins` | "Global level: place your plugin folder in ~/.gemini/config/plugins." | https://antigravity.google/docs/plugins | 2026-09-20 |
| plugin agents dir | `agents/` | "agents/: markdown files defining custom subagents and persona configurations." | https://antigravity.google/docs/plugins | 2026-09-20 |
| subagent paths | `.agents/agents/` | ".agents/agents/<name>.md or .agents/agents/<name>/agent.md" | https://antigravity.google/docs/subagents | 2026-09-20 |
| subagent model | inherit, flash, pro | "Model tier used when invoked (inherit, flash, or pro)." | https://antigravity.google/docs/subagents | 2026-09-20 |
| command policy | four values | "Auto-execution policy for shell commands (off, auto, eager, sandbox)." | https://antigravity.google/docs/subagents | 2026-09-20 |
| Always Proceed | deny list survives | "Always Proceed: The agent will execute commands without prompting (except those explicitly added to your configurable Deny list)." | https://antigravity.google/docs/agent-settings | 2026-09-20 |
| artifacts definition | structured deliverable across surfaces | "An Artifact is a structured deliverable created by the agent to accomplish its task and communicate its progress and thinking to the human user. Artifacts include rich markdown plans (Implementation Plans), code diffs, architecture diagrams, images, and browser recordings." | https://antigravity.google/docs/artifacts | 2026-09-29 |
| artifacts review | pause and request review | "Depending on your configuration, the agent will pause at intermediate milestones and request review on its plans or code edits before executing them." | https://antigravity.google/docs/artifacts | 2026-09-29 |
| generative UI | rich interactive widgets | "How to render rich interactive HTML widgets inline in the chat or as standalone artifacts." | https://antigravity.google/docs/features | 2026-09-29 |
| transcripts | session logs track execution | "system logs (such as transcript.jsonl) can track artifacts alongside other execution data" | https://antigravity.google/docs/artifacts | 2026-09-29 |
| when skills are listed | per conversation | "Discovery: when a conversation starts, the agent sees a list of available skills with their names and descriptions." | https://antigravity.google/docs/skills | 2026-09-29 |
| CLI skill reload | `/skills reload`, typed | "Added a /skills reload subcommand to asynchronously reload discovered skills and slash commands without restarting the session or blocking user input." (CLI v1.2.4, September 16, 2026) | https://antigravity.google/docs/changelog | 2026-09-29 |
| global plugin folder | activates everywhere | "Global level: place your plugin folder in ~/.gemini/config/plugins/. The plugin activates across all workspaces on your workstation." | https://antigravity.google/docs/plugins | 2026-09-29 |
| the install, live | `agy plugin install` copies; `validate` reads the link | evidence § 10 F8 (`agy` 1.0.6, an isolated `HOME`) | [evidence § 10](evidence/surfaces.md) | 2026-09-29 |

## 10. Known gaps (not documented)

- A `SessionStart` hook event; `PreInvocation` is the substitute and fires per invocation.
- A hooks manifest other than `hooks.json`.
- `/docs/personas` answers 404; personas are the `agents/` directory of the plugins page.
- `.agent/workflows` in the current docs; only `.agents/workflows/` is named, and it is deprecated.
- Any skill-size limit.
- Whether the `agy` CLI reads a global plugin's `skills/` subfolder the way the IDE does; the plugins page documents the layout, not each reader, and no live run on the CLI is recorded.
- Whether the `ultra` tier can be named anywhere but the main session.
- An update or reload action for the IDE or for a global plugin: the plugins page documents `agy plugin` install, uninstall, enable, disable and list, and no update; whether a running IDE conversation sees a changed global plugin is not stated. The CLI's own staging path is documented as `~/.gemini/antigravity-cli/plugins/<name>/` while `agy` 1.0.6 installs into `~/.gemini/config/plugins/` (evidence § 10 F8); Hatsu links only the latter, which the IDE reads and `agy` 1.0.6 installs into; a CLI session loading it was not observed.

## 11. How this guide evolves

`hatsu:great-hiker` re-fetches the ten URLs above, diffs every quoted line, and files one Netero-shaped
issue for this surface when one moved, naming the row, the generator rule (`src/surface/rules.ts` in
nen), the hooks resolver and the warm-up section. The retirement date for workflows is the first dated
row this set carries; the pass after 2026-11-01 removes the workflows rows and the back-compat note
when the page does.
