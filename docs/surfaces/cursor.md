# Cursor

Cursor reads Hatsu from symlinks the warm-up places under `<repo>/.cursor/`: one per mirrored skill, one
per persona, plus a rules file, a permissions file and a hooks file rendered from the contract.
**Correction, 2026-09-20: Cursor has hooks.** The hub used to say it had no turn-end hook; the official
hooks page documents `stop` and `sessionStart` among twenty-one events, read from
`<project>/.cursor/hooks.json`, and the permission pack has been emitting a `sessionStart` hook there
since v0.41.0.

## 1. Identity and paths

| | |
|---|---|
| how Hatsu arrives | a checkout on the host, one bootstrap (`scripts/surface_bootstrap.sh --surface cursor --target . --bootstrap`, which links only `hatsu-warmup`), then `/hatsu-warmup` every session |
| skills read from | `<repo>/.cursor/skills/<name>/SKILL.md`; a `.cursor/skills/` or `.agents/skills/` folder anywhere in the repository is picked up |
| personas read from | `<repo>/.cursor/agents/<persona>.md`, one markdown subagent file each |
| rules read from | `<repo>/.cursor/rules/*.mdc` |
| permissions read from | `<project>/.cursor/cli.json`; `~/.cursor/cli-config.json` globally |
| hooks read from | `<project>/.cursor/hooks.json`; a home-directory copy |
| invocation spelling | `/<name>` |
| headless command | `cd <repo> && cursor-agent -p --output-format text --model "$grok" -f "<prompt>"`, with `grok` resolved live from `cursor-agent models` (newest `cursor-grok-*`, plain `-high`, never `-fast`); a G5 is answered with the same line plus `--resume <chatId>`. The full record is [`evidence/surfaces.md`](evidence/surfaces.md) § 8 and Appendix A |
| pointing at a local checkout | `surface_bootstrap.sh --surface cursor --target "$HATSU_PLUGIN_ROOT" --install-all` when authoring Hatsu on Cursor, so `.cursor/skills/` links into this `surfaces/cursor/`; otherwise Cursor discovers Claude's versioned cache and serves last-tag prose |
| minimum build | `cursor-agent 2026.01.*`: the CLI changelog dates skills, rules and commands in the CLI to January 2026, and `2025.09.18-39624ef` saw no skills at all (evidence § 8 F2). The changelog groups by month, so the floor is a month; compare the date part of `cursor-agent -v` |

**Symlinks are honest here.** On `2026.09.08-6caf4ff` a symlink inside the workspace, one pointing
outside it, and a copy are all discovered, and a skill through a symlink into this checkout is listed
under its bare `name` with no plugin namespacing: Codex's F1 does not reproduce on Cursor (evidence
§ 8, § 1.4 P3 to P5). The warm-up prints `cursor-agent -v` beside the install count and refuses to claim
the surface below the minimum.

**There is no sandbox to widen.** `-f/--force` allows commands unless denied, and a headless run
fetched, cut a branch, rebased and first-published inside a linked worktree with no permission failure
(evidence § 8). The working root is the shell's own `cd`; `--workspace` and `--add-dir` exist from
`2026.09.08` and the `cd` form works on both.

## 2. Skills

| | |
|---|---|
| file | `.cursor/skills/<name>/SKILL.md` |
| frontmatter documented | `name` (lowercase letters, numbers and hyphens; must match the folder), `description`, `paths`, `disable-model-invocation`, `icon`, `color`, `metadata` |
| frontmatter kept by the mirror | the same set, minus keys the source does not carry |
| name listed as | bare `name`, in one flat space shared with `~/.cursor/skills-cursor/` built-ins and every Claude Code plugin on the host |
| description budget | not documented; a session self-reported thirty characters surviving (evidence § 8 F13) |

**The name space is flat, global and shared, and a collision silently wins.** One listing carried the
mirrored skills plus Cursor's own `autopilot`, `create-hook`, `loop`, `review-bugbot` plus this host's
Claude Code plugin skills, `build` and `drive` among them (evidence § 8 F4). The shadowing itself is
inferred, not proven: two probes could not tell two rival `build` entries apart because the surviving
descriptions are too short. The warm-up lists every name already standing under `.cursor/skills/`
before it installs anything and says that a host-level collision it cannot see may still win. Hatsu
claims forty-four ordinary words at once, `build`, `file`, `en`, `ao`, `ren`, `breath` among them.

**Do not shorten a description to fit thirty characters.** Asked for the length of `build`'s
description, a session answered "30 characters long"; the description dies inside its first clause, and
the number is a self-report on a host with ~70 skills visible, not a constant. There is no length that
survives here, the other surfaces keep the tail, and on Cursor the skill `name` does almost all of the
routing work, which is the argument for keeping names distinctive.

## 3. Personas and model config

| | |
|---|---|
| file | `.cursor/agents/<persona>.md`, YAML frontmatter then the body |
| frontmatter documented | `name`, `description`, `model`, `readonly`, `is_background` |
| model values | `inherit` or a specific model ID; `inherit` uses the parent's model and is the default |
| what the generator writes | `model: inherit` on every persona, from the matrix row: Cursor is Cursor-native only, and the id a tier resolves to is a live fact the file must not carry |
| tier aliases (`nen/workflow.json` → `models.cursor`) | frontier `grok`, deep `grok`, fast `composer`, economy `composer`; provider models are reserved for Bugbot |

`--model grok` does not exist: `cursor-agent` refuses an alias and lists the catalogue. The id is read
from `cursor-agent models` (`cursor-grok-4.6-high` on 2026-09-10, evidence § 8 F1). Hanten's isolated
reviewer is a `.cursor/agents/` subagent in a worktree.

## 4. Hooks

| | |
|---|---|
| file | `<project>/.cursor/hooks.json`; shape `{ "version": 1, "hooks": { "<event>": [{ "command": "..." }] } }` |
| events | `sessionStart`, `sessionEnd`, `preToolUse`, `postToolUse`, `postToolUseFailure`, `subagentStart`, `subagentStop`, `beforeShellExecution`, `afterShellExecution`, `beforeMCPExecution`, `afterMCPExecution`, `beforeReadFile`, `afterFileEdit`, `beforeSubmitPrompt`, `preCompact`, `stop`, `afterAgentResponse`, `afterAgentThought`, `beforeTabFileRead`, `afterTabFileEdit`, `workspaceOpen` |
| decision shape | `{"permission": "allow" \| "deny" \| "ask", "user_message", "agent_message"}`; any deny wins over ask, ask wins over allow, regardless of source; exit code 2 blocks |
| what Hatsu installs | `sessionStart` → `surface_bootstrap.sh --surface cursor --target . --install-all` when `HATSU_PLUGIN_ROOT` is set; `stop` → `hooks/stop-bell.sh`; `beforeShellExecution` → `hooks/guard-base-branch.sh` (deny on the base branch) |

The trunk guard hooks `beforeShellExecution` rather than `preToolUse` because that is the event the page
names for controlling shell commands. The bell rings through `stop`; `jutaisho`'s in-session fallback
runs only where `.cursor/hooks.json` was not placed.

## 5. Permissions

| | |
|---|---|
| file | `<project>/.cursor/cli.json`; `~/.cursor/cli-config.json` globally |
| syntax | `{ "permissions": { "allow": [ "Shell(ls)", "Shell(git)", "Read(src/**/*.ts)", … ], "deny": [ … ] } }` |
| scope | exe-and-argument patterns plus `Read`/`Write` globs; no root syntax. The scope is that the file lives in this checkout's `.cursor/` |
| what the pack renders | every contract row as `Shell(<exe> <args>)`, plus `Read(./**)` and `Write(./**)`; a bare `Shell(git)` that would admit a force-push is never written |

## 6. Rules

| | |
|---|---|
| file | `.cursor/rules/<name>.mdc`; the `.mdc` extension is required |
| frontmatter | `description`, `globs`, `alwaysApply` |
| size | keep a rule under 500 lines |
| what the generator writes | `.cursor/rules/hatsu.mdc`, `alwaysApply: true`: the surface's identity block (the spelling, the tier aliases, where the skills and personas are, the gates that stay the maintainer's) |

## 7. The option picker

The ask question tool, invoked by instructing the agent to "use the ask question tool"; over ACP it is
`cursor/ask_question`, a blocking method the agent waits on. It takes options and `allow_multiple` for
several tickable answers. The tool is never named `AskQuestion` on any official page; Hatsu's prose
says "the ask question tool".

## 8. Generation

```sh
nen surface mirror generate --surface cursor \
  --source claude/skills --agents claude/agents --out surfaces/cursor \
  --invocation-prefix hatsu: --models nen/workflow.json \
  --permissions contracts/permissions.json --hooks hooks/hooks.json \
  --rules claude/rules/hatsu.md --source-surface claude \
  --hooks-root <root expression> --manifest .claude-plugin/plugin.json --stamp <plugin version>
```

| emits | from |
|---|---|
| `surfaces/cursor/<name>/SKILL.md`, 44 files (forty-three plus `hatsu-warmup`), frontmatter reduced to the documented keys, `hatsu:<name>` respelled `/<name>` | `claude/skills/**` |
| `surfaces/cursor/agents/<persona>.md`, 12 files (11 personas plus the preamble), `model: inherit` | `claude/agents/**`, `nen/workflow.json` |
| `surfaces/cursor/.cursor/rules/hatsu.mdc` | the surface row and the matrix |
| `surfaces/cursor/.cursor/cli.json` | `contracts/permissions.json` |
| `surfaces/cursor/.cursor/hooks.json`: `sessionStart`, `beforeShellExecution`, `stop` | `hooks/hooks.json` |

Marker, first markdown line after the frontmatter fence, line 1 in a file without one:

```text
<!-- GENERATED by nen surface mirror (surface: cursor, stamp: 0.43.0) -- do not edit; edit the source and regenerate -->
```

The check against a host's installed copy, run by the warm-up before it links:

```sh
nen surface mirror check --surface cursor <same flags> --installed <repo>/.cursor
```

## 9. Dated checklist

| fact | value | quoted line | source | fetched |
|---|---|---|---|---|
| hooks file | `<project>/.cursor/hooks.json` | "create it at the project level (<project>/.cursor/hooks.json) or in your home directory" | https://cursor.com/docs/agent/hooks | 2026-09-20 |
| hooks shape | `version: 1`, `hooks: { event: [ { command } ] }` | "`{ \"version\": 1, \"hooks\": { \"afterFileEdit\": [{ \"command\": \"./hooks/format.sh\" }] }}`" | https://cursor.com/docs/agent/hooks | 2026-09-20 |
| shell events | before and after | "beforeShellExecution / afterShellExecution - Control shell commands" | https://cursor.com/docs/agent/hooks | 2026-09-20 |
| decision precedence | deny > ask > allow | "any deny wins over ask, and ask wins over allow, regardless of source" | https://cursor.com/docs/agent/hooks | 2026-09-20 |
| permissions file | `.cursor/cli.json` | "Permissions are set in ~/.cursor/cli-config.json (global) or <project>/.cursor/cli.json" | https://cursor.com/docs/cli/reference/permissions | 2026-09-20 |
| permissions syntax | `Shell(...)`, `Read(...)` | "`{ \"permissions\": { \"allow\": [ \"Shell(ls)\", \"Shell(git)\", \"Read(src/**/*.ts)\", …`" | https://cursor.com/docs/cli/reference/permissions | 2026-09-20 |
| rules extension | `.mdc` | "Project rules must use the .mdc extension." | https://cursor.com/docs/context/rules | 2026-09-20 |
| rules frontmatter | three keys | "description, globs, and alwaysApply" | https://cursor.com/docs/context/rules | 2026-09-20 |
| rules size | 500 lines | "Keep rules under 500 lines" | https://cursor.com/docs/context/rules | 2026-09-20 |
| subagent file | `.cursor/agents/<name>.md` | "Create a subagent file at .cursor/agents/verifier.md with YAML frontmatter" | https://cursor.com/docs/agent/subagents | 2026-09-20 |
| subagent model | inherit or id | "Model to use: inherit or a specific model ID." | https://cursor.com/docs/agent/subagents | 2026-09-20 |
| inherit default | yes | "inherit \| Uses the same model as the parent agent. This is the default." | https://cursor.com/docs/agent/subagents | 2026-09-20 |
| skills path | `.cursor/skills/` or `.agents/skills/` | "A .cursor/skills/ (or .agents/skills/) folder anywhere inside your repository is picked up" | https://cursor.com/docs/context/skills | 2026-09-20 |
| skill name rule | lowercase, matches folder | "Lowercase letters, numbers, and hyphens only. Must match the parent folder name." | https://cursor.com/docs/context/skills | 2026-09-20 |
| option picker | the ask question tool | "instructing them to \"use the ask question tool.\"" | https://cursor.com/changelog/2-4 | 2026-09-20 |
| option picker over ACP | `cursor/ask_question`, blocking | "Blocking methods (cursor/ask_question, cursor/create_plan): The agent waits for a response" | https://cursor.com/docs/cli/acp | 2026-09-20 |
| skills in the CLI | January 2026 | "Skills, rules, and commands in the CLI" (January 2026 entry) | https://cursor.com/docs/cli/changelog | 2026-09-20 |

## 10. Known gaps (not documented)

- Any description truncation limit; the thirty-character figure is a model self-report.
- The tool is never named `AskQuestion`; only "the ask question tool" and `cursor/ask_question`.
- Whether `stop` fires at the end of a `-p` run; a `-p` process was once observed staying alive after
  its answer (evidence § 8), so give a headless run a timeout.
- The `--resume` path in anger: no G5 fired in the recorded run.

## 11. How this guide evolves

`hatsu:great-hiker` re-fetches the seven URLs above, diffs every quoted line, and files one Netero-shaped
issue for this surface when one moved, naming the row, the generator rule (`src/surface/rules.ts` in
nen), the pack renderer and the warm-up section. The description-budget gap is the one to close first:
a measurement against a varying skill count on a host with no other plugins.
