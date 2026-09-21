# Claude Code

Claude Code is the surface Hatsu is authored for. Nothing is generated for it: the plugin under
`claude/` is the canonical copy, and every other surface is a mirror of it. This guide records what the
harness documents about the files that copy consists of, so that a change to a frontmatter key, a hook
event or a permission rule is made against a quoted line and not a memory.

## 1. Identity and paths

| | |
|---|---|
| how Hatsu arrives | `claude plugin install hatsu@hatsu` after `claude plugin marketplace add <path or repo>`; the loader copies the tree into `~/.claude/plugins/cache/hatsu/hatsu/<plugin.json version>/` |
| manifest | `.claude-plugin/plugin.json` (`skills`, `agents`, `commands`, `hooks` by convention) |
| skills read from | `$CLAUDE_PLUGIN_ROOT/claude/skills/<name>/SKILL.md` (`plugin.json` → `"skills": "./claude/skills/"`) |
| personas read from | `claude/agents/<persona>.md`, listed one by one under `plugin.json` → `agents` |
| hooks read from | `hooks/hooks.json` at the plugin root, active while the plugin is enabled |
| permissions | `.claude/settings.local.json` in the target checkout (the pack), never a plugin file |
| invocation spelling | `hatsu:<name>` |
| headless command | `claude -p "<prompt>"` in the target checkout with the plugin enabled |
| pointing at a local checkout | `claude plugin marketplace add "$HATSU_PLUGIN_ROOT"` then `claude plugin install hatsu@hatsu`; after a version bump, `claude plugin update hatsu@hatsu -y` and a restart. Confirm `claude plugin list` shows this tree's `version` |

The versioned cache is a copy, not a checkout: editing `$HATSU_PLUGIN_ROOT` changes nothing a running
session reads until the plugin is updated. `nen surface mirror check --installed` (below) is how the
warm-up tells the two apart.

## 2. Skills

| | |
|---|---|
| file | `<plugin>/skills/<skill-name>/SKILL.md`, read wherever the plugin is enabled |
| frontmatter documented | `name`, `description`, `when_to_use`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context`, `agent`, `background`, `argument-hint`, `arguments`, `paths`, `shell`, `hooks`, `metadata`, `license`, `compatibility` |
| required | none; `description` is recommended |
| description budget | 1,536 characters for `description` and `when_to_use` combined |
| name listed as | `hatsu:<name>`, namespaced by the plugin manifest |

Hatsu keeps every documented key on the source; the mirrors reduce to what each other surface documents.
The 1,536-character ceiling is the one hard number any surface states for a description, and it is the
reason Hatsu's authoring rule leads with what the skill does, then its trigger, then its never-clauses.

## 3. Personas and model config

| | |
|---|---|
| file | `claude/agents/<persona>.md`, one per persona; `_review-preamble.md` is the shared reviewer protocol and not a persona |
| frontmatter documented | `name`, `description` (required); `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `background`, `omitClaudeMd`, `effort`, `isolation`, `color`, `initialPrompt`, `experimental` |
| model values | `sonnet`, `opus`, `haiku`, `fable`, a full model ID, or `inherit` |
| ignored on a plugin subagent | `hooks`, `mcpServers`, `permissionMode` |
| precedence | the plugin's `agents/` directory is the lowest of five sources, so a same-named project agent wins |
| tier aliases (`nen/workflow.json` → `models.claude`) | frontier `fable`, deep `opus`, fast `sonnet`, economy `haiku` |

A persona's `model` is a tier alias resolved from the matrix, never a versioned id: `models.rule` says
"latest alias only, never a version".

## 4. Hooks

| | |
|---|---|
| file | `hooks/hooks.json` (plugin); `.claude/settings.json` (project, committable) |
| events | 33, including `SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `SessionEnd`, `UserPromptSubmit`, `PreCompact`, `Notification`, `PermissionRequest`, `WorktreeCreate`, `Setup`, `ConfigChange`, `Elicitation` |
| `PreToolUse` decision | `hookSpecificOutput.permissionDecision`: `allow`, `deny`, `ask` or `defer`, with `permissionDecisionReason` |
| what Hatsu installs | `SessionStart` → `hooks/session-start.sh` (the warm-up reminder; on a mirrored surface the mirror refresh); `Stop` → `hooks/stop-bell.sh` (rungs 2 and 3 off `.nen/last-stop.json`); `PreToolUse` on `Bash` → `hooks/guard-base-branch.sh` (refuses `git commit` and `git push` on the base branch) |
| session start | none installed; the plugin is read in place, so there is nothing to refresh |

Both scripts are POSIX sh, use no jq, yq or python, and fail open except the guard, which fails closed
on the five forms where the branch it can see is not the branch the write would land on. The permission
pack is placed by the warm-up, an install-time step, never by a hook: a hook is plugin-global and fires
in every repository.

## 5. Permissions

| | |
|---|---|
| file | `.claude/settings.local.json` at the root of the git repository (where an interactive "always allow" is saved too) |
| syntax | `"allow": [ "Bash(npm run *)", "Bash(git commit *)" ]`; `Bash(ls:*)` and `Bash(ls *)` match the same commands |
| scope | exe-and-argument patterns; no root syntax. The scope is that the file lives in this checkout's `.claude/` |
| can a plugin ship them | no: a plugin's `settings.json` supports only the `agent` and `subagentStatusLine` keys |
| when they apply | after each teammate trusts the folder |
| what the pack renders | `contracts/permissions.json` → `allow` and `deny` rows as `Bash(<exe> <args>)`, merged into `settings.local.json`, never the tracked `settings.json` |

## 6. Rules

Claude Code reads `CLAUDE.md` and the plugin's own files; Hatsu writes no rules file on this surface.
A persona can opt out of `CLAUDE.md` with `omitClaudeMd`; Hatsu's do not.

## 7. The option picker

`AskUserQuestion`, the harness's own tool, is what `jutaisho` asks a gate question through: lettered
options, a star on the recommended one, several tickable when several can be true. The tool is what the
session exposes; no official page for it was fetched on 2026-09-20, so it stands as an observed fact
rather than a checklist row (see *Known gaps*).

## 8. Generation

Nothing is generated for this surface. The canonical copy is `claude/skills/**` and `claude/agents/**`;
the three mirrors are generated from it (see the other guides). What this surface gets is the check
against its installed copy:

```sh
nen surface mirror check --surface claude-code \
  --source claude/skills --agents claude/agents \
  --installed "$HOME/.claude/plugins/cache/hatsu/hatsu/<version>" \
  --stamp <plugin version>
```

The warm-up runs it after `hatsu_plugin_update.sh --auto --claude`; a drifted cache means the update did
not take and the report says so rather than reading the stale copy as current. There is no marker on
this surface because there is no generated file.

## 9. Dated checklist

| fact | value | quoted line | source | fetched |
|---|---|---|---|---|
| plugin hooks file | `hooks/hooks.json` | "Plugin `hooks/hooks.json` \| When plugin is enabled" | https://code.claude.com/docs/en/hooks | 2026-09-20 |
| project hooks file | `.claude/settings.json` | "`.claude/settings.json` \| Single project \| Yes, can be committed to the repo" | https://code.claude.com/docs/en/hooks | 2026-09-20 |
| hook events | 33, `SessionStart`, `PreToolUse`, `Stop`, `SessionEnd` among them | (event table on the page; 33 rows counted on fetch) | https://code.claude.com/docs/en/hooks | 2026-09-20 |
| PreToolUse decision key | `hookSpecificOutput.permissionDecision` | "`permissionDecision` (allow/deny/ask/defer), `permissionDecisionReason`" | https://code.claude.com/docs/en/hooks | 2026-09-20 |
| deny and ask semantics | deny blocks, ask prompts | "`\"deny\"` prevents the tool call. `\"ask\"` prompts the user to confirm." | https://code.claude.com/docs/en/hooks | 2026-09-20 |
| allow syntax | `Bash(<exe> <args>)` | "`\"allow\": [ \"Bash(npm run *)\", \"Bash(git commit *)\" ]`" | https://code.claude.com/docs/en/permissions | 2026-09-20 |
| where an interactive allow is saved | `.claude/settings.local.json` | "saves the rule to `.claude/settings.local.json` at the root of the git repository" | https://code.claude.com/docs/en/permissions | 2026-09-20 |
| colon and space forms | equivalent | "`Bash(ls:*)` matches the same commands as `Bash(ls *)`" | https://code.claude.com/docs/en/permissions | 2026-09-20 |
| plugin can ship permissions | no | "Only the `agent` and `subagentStatusLine` keys are supported" | https://code.claude.com/docs/en/plugins-reference | 2026-09-20 |
| when allow rules apply | after trust | "`permissions.allow` rules … apply only after each teammate trusts the folder" | https://code.claude.com/docs/en/settings | 2026-09-20 |
| subagent required keys | `name`, `description` | (frontmatter table: both marked required) | https://code.claude.com/docs/en/sub-agents | 2026-09-20 |
| subagent model values | `sonnet`, `opus`, `haiku`, `fable`, id, `inherit` | "`model` … `sonnet`, `opus`, `haiku`, `fable`, a full model ID … or `inherit`" | https://code.claude.com/docs/en/sub-agents | 2026-09-20 |
| plugin agents precedence | lowest | "Plugin's `agents/` directory \| Where plugin is enabled \| 5 (lowest)" | https://code.claude.com/docs/en/sub-agents | 2026-09-20 |
| keys ignored on plugin subagents | `hooks`, `mcpServers`, `permissionMode` | "Ignored for plugin subagents" | https://code.claude.com/docs/en/sub-agents | 2026-09-20 |
| skill required keys | none | "All fields are optional; only `description` is recommended" | https://code.claude.com/docs/en/skills | 2026-09-20 |
| description budget | 1,536 chars with `when_to_use` | "Max 1,536 characters combined with `when_to_use`" | https://code.claude.com/docs/en/skills | 2026-09-20 |
| plugin skill path | `<plugin>/skills/<skill-name>/SKILL.md` | "Plugin \| `<plugin>/skills/<skill-name>/SKILL.md` \| Wherever plugin enabled" | https://code.claude.com/docs/en/skills | 2026-09-20 |
| manifest path | `.claude-plugin/plugin.json` | "Manifest \| `.claude-plugin/plugin.json` \| Plugin metadata and configuration (optional)" | https://code.claude.com/docs/en/plugins-reference | 2026-09-20 |
| manifest keys | `name`, `displayName`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `metadata`, `skills`, `commands`, `agents`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`, `experimental`, `dependencies` | (manifest schema on the page) | https://code.claude.com/docs/en/plugins-reference | 2026-09-20 |
| plugin layout hooks row | `hooks/hooks.json` | "Hooks \| `hooks/hooks.json` \| Hook configuration" | https://code.claude.com/docs/en/plugins-reference | 2026-09-20 |

## 10. Known gaps (not documented)

- A skill `name` length limit. No page states one; Hatsu's longest is `spiritual-message`.
- A page for `AskUserQuestion`. The tool is observed in the session's tool set; no URL was fetched.
- Whether the 1,536-character budget is enforced by truncation or by refusal to load.

## 11. How this guide evolves

`hatsu:great-hiker` re-fetches the six URLs above on each pass, diffs every quoted line, and files one
Netero-shaped issue for this surface when a line moved: which row, the old line, the new line, and what
in `claude/`, `hooks/hooks.json` or `scripts/permissions_pack.sh` the change reaches. A key this surface
stops documenting is removed from the source frontmatter in that issue's PR, never silently.
